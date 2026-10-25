using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Identity;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Live;

/// <summary>What the open screens of a household hear (<see cref="HouseholdHub"/>).</summary>
public interface IHouseholdClient
{
    /// <summary>Something of the household changed: the screens that show it read it again.</summary>
    Task Changed(LiveChange change);
}

/// <summary>
/// A short signal "this changed, read it again". It carries no data, so nobody learns more from it than their next
/// request would show them.
/// </summary>
/// <param name="Topics">What changed (<see cref="LiveTopics"/>): the app knows which of its screens show it.</param>
/// <param name="Origin">
/// The <see cref="LiveChanges.ClientHeader"/> of the request that made the change: the app that sent it already shows
/// the change and skips it. Null when the server changed something by itself.
/// </param>
public sealed record LiveChange(IReadOnlyList<string> Topics, string? Origin);

/// <summary>The kinds of things a household's screens show. An app that doesn't know a topic reads everything again.</summary>
public static class LiveTopics
{
    /// <summary>The pets: added, changed, paused, deleted, their photos.</summary>
    public const string Pets = "pets";

    /// <summary>The fields of a pet's digital passport.</summary>
    public const string Passport = "passport";

    /// <summary>Care plans and records: vaccinations, treatments, check-ups (and the weight a vet noted).</summary>
    public const string Care = "care";

    /// <summary>A pet's weighings. The weights of care records are reported as <see cref="Care"/>.</summary>
    public const string Weight = "weight";

    /// <summary>Feeding routines and their marks.</summary>
    public const string Feeding = "feeding";

    /// <summary>Vet visits.</summary>
    public const string Visits = "visits";

    /// <summary>Supplies and their stock.</summary>
    public const string Supplies = "supplies";

    /// <summary>A pet's documents.</summary>
    public const string Documents = "documents";

    /// <summary>AI scans of a passport: being read, ready to check, saved or thrown away.</summary>
    public const string Imports = "imports";

    /// <summary>The household itself: its name and time zone, its people and their roles, the invites.</summary>
    public const string Household = "household";

    /// <summary>The household's plan: Free or Premium.</summary>
    public const string Plan = "plan";
}

/// <summary>
/// Live updates for the open screens (system-design 3.4). An app in front connects here over a WebSocket, signed in
/// like its requests and with the same <c>X-Household</c> header, and hears <see cref="IHouseholdClient.Changed"/>
/// whenever someone in that household changes something. The app only asks <see cref="Ready"/>. A phone in the
/// background isn't connected: pushes are for that.
/// </summary>
public sealed class HouseholdHub(AppDbContext db, LiveChanges live) : Hub<IHouseholdClient>
{
    public const string Path = "/hubs/household";

    /// <summary>
    /// The household in the address, for the web app: a browser's WebSocket can't send the <c>X-Household</c> header.
    /// </summary>
    public const string HouseholdQuery = "household";

    /// <summary>Why a connection is refused: the household it names isn't the user's (they left, or were removed).</summary>
    public const string NotAMember = "You aren't in this household.";

    public override async Task OnConnectedAsync()
    {
        var ct = Context.ConnectionAborted;
        var subject = Context.User?.GetSubject() ?? throw new HubException("Sign in first.");
        // The app's first request creates the user; it connects only after that.
        var userId = await db.Users.Where(u => u.AuthSubject == subject).Select(u => (Guid?)u.Id).SingleOrDefaultAsync(ct)
            ?? throw new HubException("Unknown user: sign in to the app first.");

        // The household the app shows, as its requests name it (the web app names it in the address); without it, the
        // one the user joined first.
        var request = Context.GetHttpContext()?.Request;
        var requested = request?.Headers[CurrentUserAccessor.HouseholdHeader].ToString() is { Length: > 0 } header
            ? header
            : request?.Query[HouseholdQuery].ToString();
        var householdId = string.IsNullOrEmpty(requested)
            ? await db.HouseholdMembers
                .Where(m => m.UserId == userId)
                .OrderBy(m => m.JoinedAt)
                .Select(m => (Guid?)m.HouseholdId)
                .FirstOrDefaultAsync(ct)
            : Guid.TryParse(requested, out var named) ? named : null;
        // Members only: a stranger never joins the group, not even for the moment of a check.
        if (householdId is not { } id || !await IsMemberAsync(id, userId, ct))
        {
            // The app connects again when it moves to another household.
            throw new HubException(NotAMember);
        }

        // Checked again once in: a removal that commits in between still finds this connection (LiveChanges.LeftAsync).
        // Whatever fails after joining takes the connection out again, since the framework doesn't call
        // OnDisconnectedAsync for a connection whose OnConnectedAsync failed; the check finishes even if the phone has
        // gone meanwhile.
        await live.JoinAsync(Context.ConnectionId, userId, id, ct);
        try
        {
            if (!await IsMemberAsync(id, userId, CancellationToken.None))
            {
                throw new HubException(NotAMember);
            }
        }
        catch
        {
            await live.LeaveAsync(Context.ConnectionId, id);
            throw;
        }
    }

    private Task<bool> IsMemberAsync(Guid householdId, Guid userId, CancellationToken ct) =>
        db.HouseholdMembers.AnyAsync(m => m.HouseholdId == householdId && m.UserId == userId, ct);

    /// <summary>
    /// Answers once this connection hears its household (a connection is open before the household is checked). The
    /// app asks right after connecting and reads its screens again after the answer, so it misses no change made in
    /// between.
    /// </summary>
    public Task Ready() => Task.CompletedTask;

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        live.Forget(Context.ConnectionId);
        return Task.CompletedTask;
    }
}

/// <summary>A ticket into the hub for the web app (<see cref="LiveTickets"/>): good once, until <see cref="ExpiresAt"/>.</summary>
public sealed record LiveTicketResponse(string Ticket, DateTimeOffset ExpiresAt);

public static class LiveTicketsEndpoints
{
    public static RouteGroupBuilder MapLiveTicketsEndpoints(this RouteGroupBuilder api)
    {
        api.MapPost("/live/tickets", Issue)
            .Personal()
            .WithTags("Live")
            .WithName("IssueLiveTicket")
            .WithSummary($"A one-time ticket to open the live updates' hub from a browser: {HouseholdHub.Path}?access_token=<ticket>&household=<id>. Good once, for a minute; 429 with ten unused.")
            .ProducesProblem(StatusCodes.Status429TooManyRequests);
        return api;
    }

    private static async Task<Results<Ok<LiveTicketResponse>, ProblemHttpResult>> Issue(
        HttpContext http, CurrentUserAccessor current, LiveTickets tickets, CancellationToken ct)
    {
        // Known (and not deleted) before a ticket is given: the hub finds the user by the same subject.
        await current.GetAsync(ct);
        return tickets.Issue(http.User.GetSubject()!) is { } issued
            ? TypedResults.Ok(new LiveTicketResponse(issued.Ticket, issued.ExpiresAt))
            : TypedResults.Problem(statusCode: StatusCodes.Status429TooManyRequests, title: "Too many unused tickets.");
    }
}
