using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Collarbell.Api.Modules.Identity;

/// <summary>Who makes the request, in which household, and with which role there.</summary>
public sealed record CurrentUser(Guid UserId, Guid HouseholdId, HouseholdRole Role);

/// <summary>The request names a household (<see cref="CurrentUserAccessor.HouseholdHeader"/>) the user isn't in.</summary>
public sealed class NotAHouseholdMemberException() : Exception("The signed-in user isn't a member of the requested household.");

/// <summary>
/// Resolves the signed-in user and their household for this request. The first request of a new
/// user creates the user, a household and the owner membership in one transaction; a deleted account's
/// token gets <see cref="AccountDeletedException"/> instead.
/// A person can be in several households ("Home", "Office"): the app names the one it shows in the
/// <see cref="HouseholdHeader"/> header; without it, the one they joined first.
/// </summary>
public sealed class CurrentUserAccessor(AppDbContext db, IHttpContextAccessor http, TimeProvider clock)
{
    public const string DefaultHouseholdName = "Home";

    /// <summary>The household the request is about, by id.</summary>
    public const string HouseholdHeader = "X-Household";

    private CurrentUser? _current;

    /// <summary>The request's user and household, if something already asked (the request log reads it at the end).</summary>
    public CurrentUser? Known => _current;

    /// <summary>The request's user, known even when the household they asked for wasn't theirs (a 403).</summary>
    public Guid? KnownUserId { get; private set; }

    /// <summary>
    /// A household the user isn't in (an old header) means their first one instead of a 403: for the endpoints of the
    /// user's own things (HouseholdAccessRule.Personal). Set before the first <see cref="GetAsync"/>.
    /// </summary>
    public bool AnyHouseholdWillDo { get; set; }

    /// <summary>
    /// The user's account was deleted by this request: the request log notes it without them, so nothing of theirs is
    /// left in the log.
    /// </summary>
    public void Forget()
    {
        _current = null;
        KnownUserId = null;
    }

    public async Task<CurrentUser> GetAsync(CancellationToken ct)
    {
        if (_current is not null)
        {
            return _current;
        }

        var context = http.HttpContext ?? throw new InvalidOperationException("No HTTP context.");
        var principal = context.User;
        var subject = principal.GetSubject() ?? throw new InvalidOperationException("The signed-in user has no subject claim.");
        var email = principal.GetEmail();

        var user = await db.Users.SingleOrDefaultAsync(u => u.AuthSubject == subject, ct);
        if (user is null)
        {
            // A token of an account deleted a moment ago still works for up to an hour: it must not start a new account.
            if (await db.DeletedAccounts.AnyAsync(d => d.AuthSubject == subject, ct))
            {
                throw new AccountDeletedException();
            }

            user = await CreateAsync(subject, email, ct);
        }

        KnownUserId = user.Id;

        if (email is not null && user.Email != email)
        {
            user.Email = email;
            await db.SaveChangesAsync(ct);
        }

        var memberships = await db.HouseholdMembers
            .Where(m => m.UserId == user.Id)
            .OrderBy(m => m.JoinedAt)
            .Select(m => new { m.HouseholdId, m.Role })
            .ToListAsync(ct);

        // Removed from every household (or left them): a household of their own again, as on the first sign-in. A
        // request that still names the old one is told it isn't theirs, so the app moves to the new one.
        if (memberships.Count == 0)
        {
            memberships = [new { HouseholdId = await OwnHouseholdAsync(user, ct), Role = HouseholdRole.Owner }];
        }

        var requested = context.Request.Headers[HouseholdHeader].ToString();
        if (requested.Length == 0)
        {
            return _current = new CurrentUser(user.Id, memberships[0].HouseholdId, memberships[0].Role);
        }

        var membership = Guid.TryParse(requested, out var householdId)
            ? memberships.Find(m => m.HouseholdId == householdId)
            : null;
        if (membership is null && AnyHouseholdWillDo)
        {
            membership = memberships[0];
        }

        return membership is null
            ? throw new NotAHouseholdMemberException()
            : _current = new CurrentUser(user.Id, membership.HouseholdId, membership.Role);
    }

    private async Task<User> CreateAsync(string subject, string? email, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var user = new User(subject, email, now);
        var household = new Household(DefaultHouseholdName, user.TimeZone, now);
        db.Users.Add(user);
        db.Households.Add(household);
        db.HouseholdMembers.Add(new HouseholdMember(household.Id, user.Id, HouseholdRole.Owner, now));

        try
        {
            await db.SaveChangesAsync(ct);
            return user;
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // A parallel first request of the same user created it a moment earlier.
            db.ChangeTracker.Clear();
            return await db.Users.SingleAsync(u => u.AuthSubject == subject, ct);
        }
    }

    /// <summary>
    /// A new household of the user's own, once: parallel requests (screens refreshing at once) wait for the first one
    /// on the user's row and find what it made.
    /// </summary>
    private async Task<Guid> OwnHouseholdAsync(User user, CancellationToken ct)
    {
        async Task<Guid> CreateOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            await db.Database.ExecuteSqlAsync($"SELECT id FROM identity.users WHERE id = {user.Id} FOR NO KEY UPDATE", ct);
            var existing = await db.HouseholdMembers
                .Where(m => m.UserId == user.Id)
                .OrderBy(m => m.JoinedAt)
                .Select(m => (Guid?)m.HouseholdId)
                .FirstOrDefaultAsync(ct);
            if (existing is { } id)
            {
                return id;
            }

            var now = clock.GetUtcNow();
            var household = new Household(DefaultHouseholdName, user.TimeZone, now);
            db.Households.Add(household);
            db.HouseholdMembers.Add(new HouseholdMember(household.Id, user.Id, HouseholdRole.Owner, now));
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return household.Id;
        }

        return await db.Database.CreateExecutionStrategy().ExecuteAsync(CreateOnce);
    }
}
