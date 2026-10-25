using System.Security.Cryptography;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Live;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Collarbell.Api.Modules.Identity;

/// <summary>A household the user is in, with their role there.</summary>
public sealed record HouseholdSummary(Guid Id, string Name, HouseholdRole Role, string TimeZone, int MemberCount);

/// <param name="Email">Null for helpers looking at others: a sitter sees the names only.</param>
public sealed record HouseholdMemberResponse(
    Guid UserId, string? DisplayName, string? Email, HouseholdRole Role, DateTimeOffset JoinedAt, bool IsMe);

/// <param name="Code">As the app shows it, with a hyphen: <c>ABCD-2345</c>.</param>
public sealed record HouseholdInviteResponse(Guid Id, string Code, HouseholdRole Role, DateTimeOffset CreatedAt, DateTimeOffset ExpiresAt);

/// <param name="Role">The user's own role here.</param>
/// <param name="TimeZoneSetByHand">An owner set the time zone here; otherwise a household of one follows its owner's phone.</param>
/// <param name="Invites">The invites nobody has used yet; only owners see them.</param>
public sealed record HouseholdDetails(
    Guid Id,
    string Name,
    string TimeZone,
    bool TimeZoneSetByHand,
    HouseholdRole Role,
    List<HouseholdMemberResponse> Members,
    List<HouseholdInviteResponse> Invites);

public sealed record CreateHouseholdRequest(string? Name);

/// <summary>Only the fields that are sent change.</summary>
public sealed record UpdateHouseholdRequest(string? Name, string? TimeZone);

public sealed record ChangeMemberRoleRequest(HouseholdRole Role);

public sealed record CreateInviteRequest(HouseholdRole Role);

/// <summary>A code as the person typed or pasted it: any case, with or without the hyphen.</summary>
public sealed record InviteCodeRequest(string? Code);

/// <summary>What the person who got a code is about to join.</summary>
/// <param name="InvitedBy">The inviter's display name; null when they have none (an e-mail isn't shown: it isn't verified).</param>
/// <param name="AlreadyMember">The user is in this household already: there is nothing to join.</param>
public sealed record InvitePreview(string HouseholdName, string? InvitedBy, HouseholdRole Role, DateTimeOffset ExpiresAt, bool AlreadyMember);

/// <summary>
/// Households and their people (spec, "Семья"): several households per person ("Home", "Office"), the members and
/// their roles, and one-time invite codes. The household of a request is <see cref="CurrentUserAccessor"/>'s.
/// </summary>
public static class HouseholdsEndpoints
{
    public const int MaxNameLength = 100;

    /// <summary>How many households one person may be in: enough for real life, not for a script.</summary>
    public const int MaxHouseholdsPerUser = 20;

    /// <summary>Open invites per household at a time.</summary>
    public const int MaxOpenInvites = 20;

    /// <summary>The rate limit of looking codes up and accepting them, against guessing (Program.cs).</summary>
    public const string InviteRateLimit = "invites";

    public static RouteGroupBuilder MapHouseholdsEndpoints(this RouteGroupBuilder api)
    {
        var households = api.MapGroup("/households").WithTags("Households");

        households.MapGet("", List)
            .Personal()
            .WithName("ListHouseholds")
            .WithSummary("The households the user is in, with their role in each. The app names the one it shows in the X-Household header of every request; without it, the first one.");

        households.MapPost("", Create)
            .Personal()
            .WithName("CreateHouseholdGroup")
            .WithSummary("A new household with the user as its owner, e.g. \"Office\". 409 household-limit.")
            .ProducesProblem(StatusCodes.Status409Conflict);

        households.MapGet("/current", GetCurrent)
            .WithName("GetCurrentHousehold")
            .WithSummary("The household of this request: its people and their roles; for owners also the open invites.");

        households.MapPut("/current", UpdateCurrent)
            .OwnersOnly()
            .ReportsChanges(LiveTopics.Household)
            .WithName("UpdateCurrentHousehold")
            .WithSummary("Rename the household or set its time zone (feeding times and reminders are in it). Owners only.");

        households.MapDelete("/current", DeleteCurrent)
            .OwnersOnly()
            .WithName("DeleteCurrentHousehold")
            .WithSummary("Delete a household made by mistake: only an empty one (no pets, supplies or files) of one person. 409 household-not-empty. Owners only.")
            .ProducesProblem(StatusCodes.Status409Conflict);

        households.MapPut("/current/members/{userId:guid}", ChangeRole)
            .OwnersOnly()
            .ReportsChanges(LiveTopics.Household)
            .WithName("ChangeHouseholdMemberRole")
            .WithSummary("Give someone another role. Owners only; 409 last-owner when the household would be left without one.")
            .ProducesProblem(StatusCodes.Status409Conflict);

        households.MapDelete("/current/members/{userId:guid}", RemoveMember)
            .AllowHelpers()
            .ReportsChanges(LiveTopics.Household)
            .WithName("RemoveHouseholdMember")
            .WithSummary("Leave the household (your own id), or, as an owner, remove someone. 409 last-owner for the last owner.")
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status409Conflict);

        households.MapPost("/current/invites", CreateInvite)
            .OwnersOnly()
            .ReportsChanges(LiveTopics.Household)
            .WithName("CreateHouseholdInvite")
            .WithSummary("A one-time code to join this household as a member or a helper, valid for 7 days. Owners only. 409 invite-limit.")
            .ProducesProblem(StatusCodes.Status409Conflict);

        households.MapDelete("/current/invites/{id:guid}", RevokeInvite)
            .OwnersOnly()
            .ReportsChanges(LiveTopics.Household)
            .WithName("RevokeHouseholdInvite")
            .WithSummary("Take an invite back before someone uses it. Owners only.");

        // The code goes in the body, not the address: addresses end up in the servers' request logs.
        var invites = api.MapGroup("/invites").WithTags("Households");

        invites.MapPost("/preview", Preview)
            .Personal()
            .RequireRateLimiting(InviteRateLimit)
            .WithName("PreviewHouseholdInvite")
            .WithSummary("What a code invites to: the household, who invites and the role. 404 when it's wrong, used, taken back or expired.");

        invites.MapPost("/accept", Accept)
            .Personal()
            .RequireRateLimiting(InviteRateLimit)
            .WithName("AcceptHouseholdInvite")
            .WithSummary("Join the household of the code with its role. 404 when the code is wrong, used, taken back or expired; 409 already-a-member or household-limit. Safe to repeat.")
            .ProducesProblem(StatusCodes.Status409Conflict);

        return api;
    }

    private static async Task<Ok<List<HouseholdSummary>>> List(CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        return TypedResults.Ok(await SummariesAsync(db, me.UserId, ct));
    }

    private static async Task<Results<Created<HouseholdSummary>, ValidationProblem, ProblemHttpResult>> Create(
        CreateHouseholdRequest request, CurrentUserAccessor current, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var name = Input.Clean(request.Name);
        var errors = new ValidationErrors();
        if (name is null)
        {
            errors.Add("name", "Give the household a name.");
        }

        errors.MaxLength("name", name, MaxNameLength);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var me = await current.GetAsync(ct);
        if (await db.HouseholdMembers.CountAsync(m => m.UserId == me.UserId, ct) >= MaxHouseholdsPerUser)
        {
            return HouseholdLimit();
        }

        var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == me.UserId, ct);
        var now = clock.GetUtcNow();
        var household = new Household(name!, user.TimeZone, now);
        db.Households.Add(household);
        db.HouseholdMembers.Add(new HouseholdMember(household.Id, me.UserId, HouseholdRole.Owner, now));
        await db.SaveChangesAsync(ct);
        return TypedResults.Created((string?)null,
            new HouseholdSummary(household.Id, household.Name, HouseholdRole.Owner, household.TimeZone, 1));
    }

    private static async Task<Ok<HouseholdDetails>> GetCurrent(
        CurrentUserAccessor current, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        return TypedResults.Ok(await DetailsAsync(db, me, clock.GetUtcNow(), ct));
    }

    private static async Task<Results<Ok<HouseholdDetails>, ValidationProblem>> UpdateCurrent(
        UpdateHouseholdRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        TimeProvider clock,
        IEnumerable<IHouseholdChangeHandler> listeners,
        CancellationToken ct)
    {
        var errors = new ValidationErrors();
        var name = request.Name is null ? null : Input.Clean(request.Name);
        if (request.Name is not null && name is null)
        {
            errors.Add("name", "Give the household a name.");
        }

        errors.MaxLength("name", name, MaxNameLength);
        if (request.TimeZone is not null && !MeEndpoints.IsIanaTimeZone(request.TimeZone))
        {
            errors.Add("timeZone", "Use an IANA time zone such as Europe/Berlin.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var me = await current.GetAsync(ct);
        var household = await db.Households.SingleAsync(h => h.Id == me.HouseholdId, ct);
        if (name is not null)
        {
            household.Name = name;
        }

        var timeZoneChanged = false;
        if (request.TimeZone is not null)
        {
            // From now on the household keeps this time zone when its owner travels.
            household.TimeZoneSetByHand = true;
            timeZoneChanged = household.TimeZone != request.TimeZone;
            household.TimeZone = request.TimeZone;
        }

        await db.SaveChangesAsync(ct);

        // Feeding at 08:00 is 08:00 in the new time zone: the reminders move with it.
        if (timeZoneChanged)
        {
            foreach (var listener in listeners)
            {
                await listener.HouseholdChangedAsync(me.HouseholdId, ct);
            }
        }

        return TypedResults.Ok(await DetailsAsync(db, me, clock.GetUtcNow(), ct));
    }

    /// <summary>
    /// Only a household made by mistake: one person, no pets, supplies or files. Deleting one with data needs the
    /// files removed from storage too; that comes with deleting an account (spec, M6).
    /// </summary>
    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteCurrent(
        CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);

        async Task<Results<NoContent, ProblemHttpResult>> DeleteOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            await LockAsync(db, me.HouseholdId, ct);
            var id = me.HouseholdId;
            var empty = await db.HouseholdMembers.CountAsync(m => m.HouseholdId == id, ct) == 1
                && !await db.Pets.AnyAsync(p => p.HouseholdId == id, ct)
                && !await db.SupplyItems.AnyAsync(s => s.HouseholdId == id, ct)
                && !await db.StoredFiles.AnyAsync(f => f.HouseholdId == id, ct);
            if (!empty)
            {
                return TypedResults.Problem(statusCode: StatusCodes.Status409Conflict,
                    title: "Only an empty household of one person can be deleted.", type: HouseholdProblems.NotEmpty);
            }

            // Its invites, reminders and AI usage go with it (cascade). The AI photos it used stay counted for the people
            // who used them (billing.ai_charges keeps them), so a new household doesn't give them back.
            await db.Households.Where(h => h.Id == id).ExecuteDeleteAsync(ct);
            await transaction.CommitAsync(ct);
            return TypedResults.NoContent();
        }

        return await db.Database.CreateExecutionStrategy().ExecuteAsync(DeleteOnce);
    }

    private static async Task<Results<Ok<HouseholdDetails>, NotFound, ValidationProblem, ProblemHttpResult>> ChangeRole(
        Guid userId, ChangeMemberRoleRequest request, CurrentUserAccessor current, AppDbContext db, TimeProvider clock,
        CancellationToken ct)
    {
        if (!Enum.IsDefined(request.Role))
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]> { ["role"] = ["Use Owner, Member or Helper."] });
        }

        var me = await current.GetAsync(ct);

        // If the connection drops, the strategy repeats the whole unit.
        async Task<Results<Ok<HouseholdDetails>, NotFound, ValidationProblem, ProblemHttpResult>> ChangeOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            await LockAsync(db, me.HouseholdId, ct);

            // The caller's own role again, under the lock: another owner may have changed it a moment ago.
            if (!await IsOwnerAsync(db, me, ct))
            {
                return (ProblemHttpResult)HouseholdProblems.RoleCantDoThis();
            }

            var member = await db.HouseholdMembers.SingleOrDefaultAsync(m => m.HouseholdId == me.HouseholdId && m.UserId == userId, ct);
            if (member is null)
            {
                return TypedResults.NotFound();
            }

            if (member.Role == HouseholdRole.Owner && request.Role != HouseholdRole.Owner && await IsLastOwnerAsync(db, member, ct))
            {
                return LastOwner();
            }

            member.ChangeRole(request.Role);

            // An owner no more: the codes they handed out stop working.
            if (request.Role != HouseholdRole.Owner)
            {
                await RevokeInvitesOfAsync(db, me.HouseholdId, userId, clock.GetUtcNow(), ct);
            }

            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return TypedResults.Ok(await DetailsAsync(db, userId == me.UserId ? me with { Role = request.Role } : me, clock.GetUtcNow(), ct));
        }

        return await db.Database.CreateExecutionStrategy().ExecuteAsync(ChangeOnce);
    }

    /// <summary>
    /// Leaving takes nothing away from the household: the pets and records stay, marks keep who made them. A person
    /// who was in no other household gets a new one of their own on the next request.
    /// </summary>
    private static async Task<Results<NoContent, NotFound, ProblemHttpResult>> RemoveMember(
        Guid userId, CurrentUserAccessor current, AppDbContext db, LiveChanges live, TimeProvider clock, HttpRequest http,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var leaving = userId == me.UserId;
        if (!leaving && me.Role != HouseholdRole.Owner)
        {
            return (ProblemHttpResult)HouseholdProblems.RoleCantDoThis();
        }

        async Task<Results<NoContent, NotFound, ProblemHttpResult>> RemoveOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            await LockAsync(db, me.HouseholdId, ct);

            if (!leaving && !await IsOwnerAsync(db, me, ct))
            {
                return (ProblemHttpResult)HouseholdProblems.RoleCantDoThis();
            }

            var member = await db.HouseholdMembers.SingleOrDefaultAsync(m => m.HouseholdId == me.HouseholdId && m.UserId == userId, ct);
            if (member is null)
            {
                // Leaving twice (a retry after the first one went through) is still leaving.
                return leaving ? TypedResults.NoContent() : TypedResults.NotFound();
            }

            if (member.Role == HouseholdRole.Owner && await IsLastOwnerAsync(db, member, ct))
            {
                return LastOwner();
            }

            db.HouseholdMembers.Remove(member);

            // Their codes nobody has used yet stop working with them.
            await RevokeInvitesOfAsync(db, me.HouseholdId, userId, clock.GetUtcNow(), ct);

            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return TypedResults.NoContent();
        }

        var removed = await db.Database.CreateExecutionStrategy().ExecuteAsync(RemoveOnce);
        if (removed.Result is NoContent)
        {
            // Their phones hear it once and nothing of this household after that; the others hear it as any change.
            // Leaving by themselves, the phone they did it on shows it already.
            await live.LeftAsync(me.HouseholdId, userId, leaving ? LiveChanges.Origin(http.Headers[LiveChanges.ClientHeader]) : null);
        }

        return removed;
    }

    private static async Task<Results<Created<HouseholdInviteResponse>, ValidationProblem, ProblemHttpResult>> CreateInvite(
        CreateInviteRequest request, CurrentUserAccessor current, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        if (request.Role is not (HouseholdRole.Member or HouseholdRole.Helper))
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["role"] = ["Invite as a member or a helper; make someone an owner once they have joined."],
            });
        }

        var me = await current.GetAsync(ct);
        var now = clock.GetUtcNow();
        var open = await db.HouseholdInvites.CountAsync(
            i => i.HouseholdId == me.HouseholdId && i.AcceptedAt == null && i.RevokedAt == null && i.ExpiresAt > now, ct);
        if (open >= MaxOpenInvites)
        {
            return TypedResults.Problem(statusCode: StatusCodes.Status409Conflict,
                title: $"Up to {MaxOpenInvites} open invites; take some back first.", type: HouseholdProblems.InviteLimit);
        }

        // A clash of two random codes is very unlikely; try again if it happens.
        for (var attempt = 1; ; attempt++)
        {
            var invite = new HouseholdInvite(me.HouseholdId, InviteCodes.New(), request.Role, me.UserId, now);
            db.HouseholdInvites.Add(invite);
            try
            {
                await db.SaveChangesAsync(ct);
                return TypedResults.Created((string?)null, Response(invite));
            }
            catch (DbUpdateException e) when (attempt < 3 && e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
            {
                db.Entry(invite).State = EntityState.Detached;
            }
        }
    }

    private static async Task<Results<NoContent, NotFound>> RevokeInvite(
        Guid id, CurrentUserAccessor current, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var now = clock.GetUtcNow();
        var invite = await db.HouseholdInvites.SingleOrDefaultAsync(i => i.Id == id && i.HouseholdId == me.HouseholdId, ct);
        if (invite is null || !invite.IsOpen(now))
        {
            return TypedResults.NotFound();
        }

        invite.Revoke(now);
        await db.SaveChangesAsync(ct);
        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<InvitePreview>, NotFound>> Preview(
        InviteCodeRequest request, CurrentUserAccessor current, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var normalized = InviteCodes.Normalize(request.Code);
        var now = clock.GetUtcNow();
        var found = normalized is null
            ? null
            : await (from i in db.HouseholdInvites
                     where i.Code == normalized && i.AcceptedAt == null && i.RevokedAt == null && i.ExpiresAt > now
                     join h in db.Households on i.HouseholdId equals h.Id
                     join u in db.Users on i.CreatedBy equals u.Id
                     select new { i.HouseholdId, h.Name, u.DisplayName, i.Role, i.ExpiresAt })
                .SingleOrDefaultAsync(ct);
        if (found is null)
        {
            return TypedResults.NotFound();
        }

        var alreadyMember = await db.HouseholdMembers.AnyAsync(m => m.HouseholdId == found.HouseholdId && m.UserId == me.UserId, ct);
        return TypedResults.Ok(new InvitePreview(found.Name, found.DisplayName, found.Role, found.ExpiresAt, alreadyMember));
    }

    private static async Task<Results<Ok<HouseholdSummary>, NotFound, ProblemHttpResult>> Accept(
        InviteCodeRequest request, CurrentUserAccessor current, AppDbContext db, LiveChanges live, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var normalized = InviteCodes.Normalize(request.Code);
        if (normalized is null)
        {
            return TypedResults.NotFound();
        }

        var now = clock.GetUtcNow();

        // One person per code, even when two accept it at the same moment: the row stays locked until the commit.
        // The answer is the household joined, a problem, or neither: no such open code.
        async Task<(Guid? Joined, ProblemHttpResult? Problem)> AcceptOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);

            // The household first, then the code, in the order an account deletion takes them: a household being deleted
            // at this moment is waited for, and then it is gone, with its codes. Nobody is told they joined a household
            // that goes a moment later, or joins it after its fate was decided.
            var householdId = await db.HouseholdInvites.Where(i => i.Code == normalized).Select(i => (Guid?)i.HouseholdId)
                .SingleOrDefaultAsync(ct);
            if (householdId is null)
            {
                return (null, null);
            }

            await LockAsync(db, householdId.Value, ct);
            var invite = (await db.HouseholdInvites
                .FromSql($"SELECT * FROM identity.household_invites WHERE code = {normalized} FOR UPDATE")
                .ToListAsync(ct)).SingleOrDefault();

            // A double tap, or a retry after the first one went through: this person used the code, so it worked.
            if (invite?.AcceptedBy == me.UserId)
            {
                return (invite.HouseholdId, null);
            }

            if (invite is null || !invite.IsOpen(now))
            {
                return (null, null);
            }

            if (await db.HouseholdMembers.AnyAsync(m => m.HouseholdId == invite.HouseholdId && m.UserId == me.UserId, ct))
            {
                return (null, AlreadyMember());
            }

            if (await db.HouseholdMembers.CountAsync(m => m.UserId == me.UserId, ct) >= MaxHouseholdsPerUser)
            {
                return (null, HouseholdLimit());
            }

            db.HouseholdMembers.Add(new HouseholdMember(invite.HouseholdId, me.UserId, invite.Role, now));
            invite.Accept(me.UserId, now);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
            {
                // Joined the same household a moment ago with another of its codes.
                return (null, AlreadyMember());
            }

            await transaction.CommitAsync(ct);
            return (invite.HouseholdId, null);
        }

        var (joined, problem) = await db.Database.CreateExecutionStrategy().ExecuteAsync(AcceptOnce);
        if (problem is not null)
        {
            return problem;
        }

        if (joined is not { } householdId)
        {
            return TypedResults.NotFound();
        }

        // The household joined sees the new person at once; the request itself is about the household the app shows.
        await live.ChangedAsync(householdId, [LiveTopics.Household]);
        return TypedResults.Ok((await SummariesAsync(db, me.UserId, ct)).Single(h => h.Id == householdId));
    }

    internal static async Task<List<HouseholdSummary>> SummariesAsync(AppDbContext db, Guid userId, CancellationToken ct) =>
        await (from m in db.HouseholdMembers
               where m.UserId == userId
               join h in db.Households on m.HouseholdId equals h.Id
               orderby m.JoinedAt
               select new HouseholdSummary(h.Id, h.Name, m.Role, h.TimeZone, db.HouseholdMembers.Count(x => x.HouseholdId == h.Id)))
            .ToListAsync(ct);

    private static async Task<HouseholdDetails> DetailsAsync(AppDbContext db, CurrentUser me, DateTimeOffset now, CancellationToken ct)
    {
        var household = await db.Households.AsNoTracking().SingleAsync(h => h.Id == me.HouseholdId, ct);
        var members = await (from m in db.HouseholdMembers
                             where m.HouseholdId == me.HouseholdId
                             join u in db.Users on m.UserId equals u.Id
                             orderby m.JoinedAt
                             select new HouseholdMemberResponse(u.Id, u.DisplayName, u.Email, m.Role, m.JoinedAt, u.Id == me.UserId))
            .ToListAsync(ct);

        // A sitter sees who is who by name, not everyone's e-mail.
        if (me.Role == HouseholdRole.Helper)
        {
            members = [.. members.Select(m => m.IsMe ? m : m with { Email = null })];
        }

        var invites = me.Role != HouseholdRole.Owner
            ? []
            : (await db.HouseholdInvites.AsNoTracking()
                .Where(i => i.HouseholdId == me.HouseholdId && i.AcceptedAt == null && i.RevokedAt == null && i.ExpiresAt > now)
                .OrderBy(i => i.CreatedAt)
                .ToListAsync(ct))
            .Select(Response)
            .ToList();
        return new HouseholdDetails(household.Id, household.Name, household.TimeZone, household.TimeZoneSetByHand, me.Role,
            members, invites);
    }

    private static HouseholdInviteResponse Response(HouseholdInvite invite) =>
        new(invite.Id, InviteCodes.Display(invite.Code), invite.Role, invite.CreatedAt, invite.ExpiresAt);

    /// <summary>
    /// Holds the household until the transaction ends, so two owners leaving or stepping down at the same moment
    /// can't leave it without an owner. NO KEY UPDATE: new pets and marks of the household don't wait for it.
    /// </summary>
    private static Task LockAsync(AppDbContext db, Guid householdId, CancellationToken ct) =>
        db.Database.ExecuteSqlAsync($"SELECT id FROM identity.households WHERE id = {householdId} FOR NO KEY UPDATE", ct);

    private static Task<bool> IsOwnerAsync(AppDbContext db, CurrentUser me, CancellationToken ct) =>
        db.HouseholdMembers.AnyAsync(m => m.HouseholdId == me.HouseholdId && m.UserId == me.UserId && m.Role == HouseholdRole.Owner, ct);

    private static async Task<bool> IsLastOwnerAsync(AppDbContext db, HouseholdMember owner, CancellationToken ct) =>
        !await db.HouseholdMembers.AnyAsync(
            m => m.HouseholdId == owner.HouseholdId && m.Role == HouseholdRole.Owner && m.UserId != owner.UserId, ct);

    private static async Task RevokeInvitesOfAsync(AppDbContext db, Guid householdId, Guid userId, DateTimeOffset now, CancellationToken ct)
    {
        var invites = await db.HouseholdInvites
            .Where(i => i.HouseholdId == householdId && i.CreatedBy == userId && i.AcceptedAt == null && i.RevokedAt == null)
            .ToListAsync(ct);
        invites.ForEach(i => i.Revoke(now));
    }

    private static ProblemHttpResult LastOwner() =>
        TypedResults.Problem(statusCode: StatusCodes.Status409Conflict,
            title: "A household needs an owner: make someone else an owner first.", type: HouseholdProblems.LastOwner);

    private static ProblemHttpResult AlreadyMember() =>
        TypedResults.Problem(statusCode: StatusCodes.Status409Conflict, title: "You're already in this household.",
            type: HouseholdProblems.AlreadyMember);

    private static ProblemHttpResult HouseholdLimit() =>
        TypedResults.Problem(statusCode: StatusCodes.Status409Conflict,
            title: $"You can be in up to {MaxHouseholdsPerUser} households.", type: HouseholdProblems.HouseholdLimit);
}

/// <summary>Invite codes: eight characters a person can read out and type, without 0/O and 1/I.</summary>
public static class InviteCodes
{
    public const int Length = 8;

    private const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    public static string New() =>
        string.Create(Length, 0, static (chars, _) =>
        {
            for (var i = 0; i < chars.Length; i++)
            {
                chars[i] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
            }
        });

    /// <summary>The stored form of a typed code (any case, with or without the hyphen or spaces); null when it can't be one.</summary>
    public static string? Normalize(string? typed)
    {
        var code = string.Concat((typed ?? "").Where(char.IsLetterOrDigit)).ToUpperInvariant();
        return code.Length == Length && code.All(Alphabet.Contains) ? code : null;
    }

    /// <summary><c>ABCD2345</c> → <c>ABCD-2345</c>.</summary>
    public static string Display(string code) => $"{code[..4]}-{code[4..]}";
}
