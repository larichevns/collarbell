using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Live;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Modules.Identity;

/// <summary>What happens to a household when someone in it deletes their account.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<HouseholdFate>))]
public enum HouseholdFate
{
    /// <summary>
    /// Nobody would be left to look after it (the person was alone there, or only helpers remain): deleted with its pets,
    /// records and files. Helpers lose it.
    /// </summary>
    Deleted,

    /// <summary>The others keep it as it is: the person wasn't its last owner.</summary>
    Kept,

    /// <summary>The others keep it, and the member who joined first becomes its owner: a household always has one.</summary>
    HandedOver,
}

/// <param name="Role">The person's role there.</param>
/// <param name="Pets">The household's pets: what goes for <see cref="HouseholdFate.Deleted"/>.</param>
/// <param name="Others">The other people in it: who keeps it, or (deleted) the helpers who lose it.</param>
/// <param name="NewOwner">Who becomes the owner (<see cref="HouseholdFate.HandedOver"/>): their name, else their e-mail.</param>
public sealed record HouseholdDeletionOutcome(
    Guid Id, string Name, HouseholdRole Role, HouseholdFate Fate, int Pets, int Others, string? NewOwner);

/// <summary>What deleting the account would do, household by household, the first-joined first.</summary>
/// <param name="Plan">
/// A fingerprint of these fates. <c>DELETE /me?plan=…</c> sends it back, and the account is deleted only if the fates
/// are still these: the person agrees to what they were shown, not to what changed meanwhile.
/// </param>
public sealed record AccountDeletionPreview(List<HouseholdDeletionOutcome> Households, string Plan);

/// <summary>What <see cref="AccountDeletion.DeleteAsync"/> did.</summary>
public enum DeletionResult
{
    Deleted,

    /// <summary>There was no such account any more: deleted a moment ago (a double tap, a retry, the other phone).</summary>
    AlreadyDeleted,

    /// <summary>Nothing was deleted: a household's fate isn't the one the person was shown.</summary>
    PlanChanged,
}

/// <summary>
/// A module that keeps something of a household the database can't delete by itself, such as the storage objects of its
/// files: before a household is deleted, it removes them (like <c>IPetDeletionHandler</c>). Identity doesn't know them.
/// </summary>
public interface IHouseholdDeletionHandler
{
    /// <summary>Called inside the deletion's transaction; the caller saves.</summary>
    Task BeforeHouseholdDeletedAsync(Guid householdId, CancellationToken ct);
}

/// <summary>A module that keeps something of a person without a foreign key to them, e.g. the request log.</summary>
public interface IAccountDeletionHandler
{
    /// <summary>Called inside the deletion's transaction, before the user's row goes.</summary>
    Task BeforeAccountDeletedAsync(Guid userId, CancellationToken ct);
}

/// <summary>The request carries the token of an account that has been deleted: the app signs out.</summary>
public sealed class AccountDeletedException() : Exception("This account has been deleted.");

public static class AccountProblems
{
    /// <summary>A request from an account deleted a moment ago (its token still works for up to an hour).</summary>
    public const string Deleted = "urn:collarbell:problem:account-deleted";

    /// <summary>Deleting the account asks for the password again: the last sign-in is older than <see cref="AccountDeletion.RecentSignIn"/>.</summary>
    public const string RecentSignInRequired = "urn:collarbell:problem:recent-sign-in-required";

    /// <summary>A household's fate changed since the person was shown it (someone joined, left or became an owner).</summary>
    public const string PlanChanged = "urn:collarbell:problem:deletion-plan-changed";

    public static ProblemHttpResult AccountDeleted() =>
        TypedResults.Problem(statusCode: StatusCodes.Status401Unauthorized, title: "This account has been deleted.", type: Deleted);
}

/// <summary>
/// Deletes a person's account and everything that is theirs alone (spec, "Удаление аккаунта"), in one transaction:
/// <list type="bullet">
/// <item>households where nobody would be left to look after the pets go with everything in them, files included;</item>
/// <item>in the others the person's records and marks stay, without their name; a household that would have no owner
/// gets the member who joined first as its owner;</item>
/// <item>their profile, phones, settings and request log go; their sign-in token is refused from then on.</item>
/// </list>
/// Then the sign-in account (Firebase) is deleted, at once or, if Firebase can't be reached, by <see cref="AccountCleanup"/>.
/// </summary>
public sealed class AccountDeletion(
    AppDbContext db,
    IEnumerable<IHouseholdDeletionHandler> householdModules,
    IEnumerable<IAccountDeletionHandler> accountModules,
    ISignInAccounts signIns,
    LiveChanges live,
    TimeProvider clock,
    ILogger<AccountDeletion> log)
{
    /// <summary>
    /// How recently the person must have typed their password to delete the account: a phone left unlocked on a table
    /// isn't enough. The same five minutes Firebase asks for before its own account deletion.
    /// </summary>
    public static readonly TimeSpan RecentSignIn = TimeSpan.FromMinutes(5);

    /// <summary>A household's fate, with the member who would become its owner.</summary>
    private sealed record Plan(HouseholdDeletionOutcome Outcome, Guid? Heir);

    public async Task<AccountDeletionPreview> PreviewAsync(Guid userId, CancellationToken ct)
    {
        var plans = await PlanAsync(userId, ct);
        return new([.. plans.Select(p => p.Outcome)], Fingerprint(plans));
    }

    /// <summary>
    /// Deletes the account, if <paramref name="confirmedPlan"/> (from <see cref="PreviewAsync"/>; null: whatever the fates)
    /// still holds; what happened to each household.
    /// </summary>
    public async Task<(DeletionResult Result, List<HouseholdDeletionOutcome> Households)> DeleteAsync(
        Guid userId, string? confirmedPlan, CancellationToken ct)
    {
        string? subject = null;
        List<Plan> plans = [];
        var result = DeletionResult.Deleted;

        // If the connection drops, the strategy repeats the whole unit.
        async Task DeleteOnce()
        {
            db.ChangeTracker.Clear();
            plans = [];
            await using var transaction = await db.Database.BeginTransactionAsync(ct);

            // The person's row first: a household they create or join at this very moment waits, and then finds no one.
            // No row: deleted a moment ago, by a request this one waited for here.
            subject = await db.Database
                .SqlQuery<string>($"SELECT auth_subject AS \"Value\" FROM identity.users WHERE id = {userId} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            if (subject is null)
            {
                result = DeletionResult.AlreadyDeleted;
                return;
            }

            // Their households, in one order, held until the end. FOR UPDATE also holds what refers to them: someone
            // joining by invite, a photo uploaded on another phone, a new pet wait, and then find the household gone. Owners
            // leaving or stepping down wait too. So the fates below stay true, and nothing appears that isn't deleted.
            var households = await db.HouseholdMembers.Where(m => m.UserId == userId).Select(m => m.HouseholdId).ToListAsync(ct);
            foreach (var householdId in households.Order())
            {
                await db.Database.ExecuteSqlAsync(
                    $"SELECT id FROM identity.households WHERE id = {householdId} FOR UPDATE", ct);
            }

            plans = await PlanAsync(userId, ct);
            if (confirmedPlan is not null && confirmedPlan != Fingerprint(plans))
            {
                result = DeletionResult.PlanChanged;
                return;
            }

            result = DeletionResult.Deleted;
            foreach (var plan in plans)
            {
                switch (plan.Outcome.Fate)
                {
                    case HouseholdFate.Deleted:
                        // The modules queue what the cascade can't reach (the files' storage objects); then the database
                        // deletes the household with everything in it.
                        foreach (var module in householdModules)
                        {
                            await module.BeforeHouseholdDeletedAsync(plan.Outcome.Id, ct);
                        }

                        await db.SaveChangesAsync(ct);
                        await db.Households.Where(h => h.Id == plan.Outcome.Id).ExecuteDeleteAsync(ct);
                        break;

                    case HouseholdFate.HandedOver:
                        await db.HouseholdMembers
                            .Where(m => m.HouseholdId == plan.Outcome.Id && m.UserId == plan.Heir)
                            .ExecuteUpdateAsync(s => s.SetProperty(m => m.Role, HouseholdRole.Owner), ct);
                        break;
                }
            }

            foreach (var module in accountModules)
            {
                await module.BeforeAccountDeletedAsync(userId, ct);
            }

            // The rest goes with the row: memberships, phones, settings and the invites they made. Their marks,
            // purchases and the photos they used keep their place without them (SET NULL).
            await db.Users.Where(u => u.Id == userId).ExecuteDeleteAsync(ct);
            await db.DeletedAccounts.Where(d => d.AuthSubject == subject).ExecuteDeleteAsync(ct);
            db.DeletedAccounts.Add(new DeletedAccount(subject, clock.GetUtcNow()));
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
        }

        await db.Database.CreateExecutionStrategy().ExecuteAsync(DeleteOnce);
        if (result != DeletionResult.Deleted)
        {
            return (result, []);
        }

        log.LogInformation("Account {UserId} deleted: {Households}.", userId,
            string.Join(", ", plans.Select(p => $"{p.Outcome.Id} {p.Outcome.Fate}")));

        // The person's other phones hear that they are out; everyone else re-reads who is in the household (or finds it
        // gone). Nothing here may undo the deletion, so it no longer listens to the request.
        foreach (var plan in plans)
        {
            await live.LeftAsync(plan.Outcome.Id, userId);
            await live.ChangedAsync(plan.Outcome.Id, [LiveTopics.Household]);
        }

        await DeleteSignInAsync(db, signIns, subject!, clock, CancellationToken.None);
        return (result, [.. plans.Select(p => p.Outcome)]);
    }

    /// <summary>The fates in short (household, fate, new owner), as a fingerprint the app can send back.</summary>
    private static string Fingerprint(IEnumerable<Plan> plans)
    {
        var fates = string.Join(";", plans.OrderBy(p => p.Outcome.Id).Select(p => $"{p.Outcome.Id:N}:{p.Outcome.Fate}:{p.Heir:N}"));
        return Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(fates)))[..32];
    }

    /// <summary>Deletes the sign-in account and notes it; a failure leaves it for <see cref="AccountCleanup"/>.</summary>
    internal static async Task DeleteSignInAsync(
        AppDbContext db, ISignInAccounts signIns, string subject, TimeProvider clock, CancellationToken ct)
    {
        var waiting = db.DeletedAccounts.Where(d => d.AuthSubject == subject && d.SignInDeletedAt == null);
        if (await signIns.DeleteAsync(subject, ct))
        {
            await waiting.ExecuteUpdateAsync(s => s.SetProperty(d => d.SignInDeletedAt, clock.GetUtcNow()), ct);
        }
        else
        {
            await waiting.ExecuteUpdateAsync(s => s.SetProperty(d => d.Attempts, d => d.Attempts + 1), ct);
        }
    }

    /// <summary>Each household of the person, the first-joined first, with what deleting the account does to it.</summary>
    private async Task<List<Plan>> PlanAsync(Guid userId, CancellationToken ct)
    {
        var mine = await (from m in db.HouseholdMembers
                          where m.UserId == userId
                          join h in db.Households on m.HouseholdId equals h.Id
                          orderby m.JoinedAt
                          select new { h.Id, h.Name, m.Role })
            .ToListAsync(ct);
        var ids = mine.Select(h => h.Id).ToList();
        var others = await (from m in db.HouseholdMembers
                            where ids.Contains(m.HouseholdId) && m.UserId != userId
                            join u in db.Users on m.UserId equals u.Id
                            orderby m.JoinedAt
                            select new { m.HouseholdId, m.UserId, m.Role, Name = u.DisplayName ?? u.Email })
            .ToListAsync(ct);
        var pets = await db.Pets
            .Where(p => ids.Contains(p.HouseholdId))
            .GroupBy(p => p.HouseholdId)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Key, g => g.Count, ct);

        return [.. mine.Select(h =>
        {
            var theirs = others.Where(o => o.HouseholdId == h.Id).ToList();
            var heir = theirs.FirstOrDefault(o => o.Role == HouseholdRole.Member);
            var (fate, newOwner) =
                theirs.Count == 0 ? (HouseholdFate.Deleted, null)
                : h.Role != HouseholdRole.Owner || theirs.Any(o => o.Role == HouseholdRole.Owner) ? (HouseholdFate.Kept, null)
                // Only a member takes over: helpers (a sitter, a colleague) were let in to help, not to keep the pets'
                // records. With nobody else, the household goes.
                : heir is not null ? (HouseholdFate.HandedOver, heir)
                : (HouseholdFate.Deleted, null);
            return new Plan(
                new HouseholdDeletionOutcome(h.Id, h.Name, h.Role, fate, pets.GetValueOrDefault(h.Id), theirs.Count, newOwner?.Name),
                newOwner?.UserId);
        })];
    }
}

/// <summary>Settings of the deleted accounts' cleanup.</summary>
public sealed class AccountCleanupOptions
{
    /// <summary>How often sign-in accounts that couldn't be deleted are tried again; zero turns it off (the tests run it).</summary>
    public TimeSpan Interval { get; set; } = TimeSpan.FromMinutes(10);
}

/// <summary>
/// Finishes account deletions: deletes the sign-in accounts Firebase didn't take at once, and forgets a deleted account
/// once its tokens can't work any more.
/// </summary>
public sealed class AccountCleanup(AppDbContext db, ISignInAccounts signIns, TimeProvider clock)
{
    /// <summary>
    /// How long a deleted account's token is refused after its sign-in account is gone. A Firebase token lives an hour and
    /// can't be renewed without the account, so a day is plenty.
    /// </summary>
    public static readonly TimeSpan RefuseFor = TimeSpan.FromDays(1);

    private const int BatchSize = 50;

    public async Task RunOnceAsync(CancellationToken ct)
    {
        var waiting = await db.DeletedAccounts.AsNoTracking()
            .Where(d => d.SignInDeletedAt == null)
            .OrderBy(d => d.DeletedAt)
            .Take(BatchSize)
            .Select(d => d.AuthSubject)
            .ToListAsync(ct);
        foreach (var subject in waiting)
        {
            await AccountDeletion.DeleteSignInAsync(db, signIns, subject, clock, ct);
        }

        var forgetBefore = clock.GetUtcNow() - RefuseFor;
        await db.DeletedAccounts.Where(d => d.SignInDeletedAt < forgetBefore).ExecuteDeleteAsync(ct);
    }
}

/// <summary>Runs <see cref="AccountCleanup"/> every <see cref="AccountCleanupOptions.Interval"/>.</summary>
internal sealed class AccountCleanupWorker(
    IServiceScopeFactory scopes,
    IOptions<AccountCleanupOptions> options,
    ILogger<AccountCleanupWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = options.Value.Interval;
        if (interval <= TimeSpan.Zero)
        {
            return;
        }

        using var timer = new PeriodicTimer(interval);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<AccountCleanup>().RunOnceAsync(stoppingToken);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "Account cleanup failed; it runs again on the next tick.");
            }
        }
    }
}
