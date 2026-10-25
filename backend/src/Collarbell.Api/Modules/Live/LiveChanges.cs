using Collarbell.Api.Modules.Identity;
using Microsoft.AspNetCore.SignalR;

namespace Collarbell.Api.Modules.Live;

/// <summary>
/// Tells a household's open screens that something changed (<see cref="HouseholdHub"/>). Most changes go out by
/// themselves: an endpoint marked with <see cref="LiveChangesExtensions.ReportsChanges{TBuilder}"/> reports to the
/// household of its request once it succeeds (<see cref="LiveChangesFilter"/>). Sending never fails a request: an app
/// that missed a signal reads everything again when it connects again.
/// </summary>
public sealed class LiveChanges(IHubContext<HouseholdHub, IHouseholdClient> hub, ILogger<LiveChanges> log)
{
    /// <summary>
    /// The app's id for this launch, on its requests: a change it makes comes back to it as
    /// <see cref="LiveChange.Origin"/>, so it doesn't read again what it shows already.
    /// </summary>
    public const string ClientHeader = "X-Client";

    /// <summary>Open connections per person: a phone or two, a tablet, with room for ones not yet timed out.</summary>
    public const int MaxConnectionsPerUser = 10;

    /// <summary>Why a connection over <see cref="MaxConnectionsPerUser"/> is refused.</summary>
    public const string TooManyConnections = "Too many open connections.";

    /// <summary>An open connection: whose it is, which household it hears, and a token that fires once it is gone.</summary>
    private sealed record Connection(Guid UserId, Guid HouseholdId, CancellationToken Gone);

    /// <summary>The open connections by id; read and changed under <see cref="_lock"/>.</summary>
    private readonly Dictionary<string, Connection> _connections = [];
    private readonly Lock _lock = new();

    private static string Group(Guid householdId) => $"household:{householdId}";

    /// <summary>The app's id from <see cref="ClientHeader"/>, if it looks like one.</summary>
    public static string? Origin(string? header) =>
        header is { Length: > 0 and <= 64 } && header.All(c => char.IsAsciiLetterOrDigit(c) || c == '-') ? header : null;

    /// <summary>
    /// Adds a member's connection to their household's group. <paramref name="gone"/> fires when the connection is
    /// gone; such a connection stops counting even if nothing forgot it.
    /// </summary>
    internal async Task JoinAsync(string connectionId, Guid userId, Guid householdId, CancellationToken gone)
    {
        lock (_lock)
        {
            // Counted and added in one step: connections opened at the same moment can't pass the limit together.
            // A script opening connection after connection would hold the server's memory; an app has one at a time.
            foreach (var closed in _connections.Where(c => c.Value.Gone.IsCancellationRequested).Select(c => c.Key).ToList())
            {
                _connections.Remove(closed);
            }

            if (_connections.Values.Count(c => c.UserId == userId) >= MaxConnectionsPerUser)
            {
                throw new HubException(TooManyConnections);
            }

            _connections[connectionId] = new Connection(userId, householdId, gone);
        }

        try
        {
            await hub.Groups.AddToGroupAsync(connectionId, Group(householdId));
        }
        catch
        {
            Forget(connectionId);
            throw;
        }
    }

    internal async Task LeaveAsync(string connectionId, Guid householdId)
    {
        Forget(connectionId);
        await hub.Groups.RemoveFromGroupAsync(connectionId, Group(householdId));
    }

    internal void Forget(string connectionId)
    {
        lock (_lock)
        {
            _connections.Remove(connectionId);
        }
    }

    /// <summary>The open connections of <paramref name="userId"/> that hear <paramref name="householdId"/>.</summary>
    private List<string> ConnectionsOf(Guid householdId, Guid userId)
    {
        lock (_lock)
        {
            return [.. _connections.Where(c => c.Value.HouseholdId == householdId && c.Value.UserId == userId).Select(c => c.Key)];
        }
    }

    /// <summary>
    /// The household's open screens hear that <paramref name="topics"/> changed. When a person made the change
    /// (<paramref name="byUser"/>), only their own connections get <paramref name="origin"/>: the phone that made it
    /// skips it, and nobody learns the ids of other people's phones (or could pass one off as theirs).
    /// </summary>
    public async Task ChangedAsync(Guid householdId, IReadOnlyList<string> topics, Guid? byUser = null, string? origin = null)
    {
        try
        {
            var theirs = byUser is { } userId && origin is not null ? ConnectionsOf(householdId, userId) : [];
            if (theirs.Count == 0)
            {
                await hub.Clients.Group(Group(householdId)).Changed(new LiveChange(topics, null));
                return;
            }

            await hub.Clients.GroupExcept(Group(householdId), theirs).Changed(new LiveChange(topics, null));
            await hub.Clients.Clients(theirs).Changed(new LiveChange(topics, origin));
        }
        catch (Exception e)
        {
            log.LogWarning(e, "Telling household {HouseholdId} about a change failed.", householdId);
        }
    }

    /// <summary>
    /// <paramref name="userId"/> left the household or was removed: their open screens hear it once (their next
    /// request finds out they aren't in it and moves to another household), and nothing of it after that. When they
    /// left by themselves, <paramref name="origin"/> is the phone they did it on: that one shows it already.
    /// </summary>
    public async Task LeftAsync(Guid householdId, Guid userId, string? origin = null)
    {
        foreach (var connectionId in ConnectionsOf(householdId, userId))
        {
            try
            {
                await LeaveAsync(connectionId, householdId);
                await hub.Clients.Client(connectionId).Changed(new LiveChange([LiveTopics.Household], origin));
            }
            catch (Exception e)
            {
                log.LogWarning(e, "Taking a connection out of household {HouseholdId} failed.", householdId);
            }
        }
    }
}

/// <summary>An endpoint whose successful changes the household's open screens hear, and what they are about.</summary>
public sealed record LiveTopicsMetadata(IReadOnlyList<string> Topics);

public static class LiveChangesExtensions
{
    /// <summary>
    /// When a request to this endpoint (or group) changes something and succeeds, the household of the request hears
    /// that <paramref name="topics"/> changed. Reading (GET) never reports.
    /// </summary>
    public static TBuilder ReportsChanges<TBuilder>(this TBuilder builder, params string[] topics)
        where TBuilder : IEndpointConventionBuilder =>
        builder.WithMetadata(new LiveTopicsMetadata(topics));
}

/// <summary>
/// Runs for every <c>/api/v1</c> endpoint, inside <see cref="HouseholdAccessFilter"/>: a request to an endpoint marked
/// with <see cref="LiveTopicsMetadata"/> that isn't a read is reported to its household once the answer has gone out,
/// and only if it succeeded (2xx). By then the change is saved, so nobody hears of a change that isn't there.
/// </summary>
public sealed class LiveChangesFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var result = await next(context);

        var http = context.HttpContext;
        var marked = http.GetEndpoint()?.Metadata.GetMetadata<LiveTopicsMetadata>();
        if (marked is null || HttpMethods.IsGet(http.Request.Method) || HttpMethods.IsHead(http.Request.Method)
            || http.RequestServices.GetRequiredService<CurrentUserAccessor>().Known is not { } me)
        {
            return result;
        }

        var live = http.RequestServices.GetRequiredService<LiveChanges>();
        var origin = LiveChanges.Origin(http.Request.Headers[LiveChanges.ClientHeader]);
        http.Response.OnCompleted(() => http.Response.StatusCode is >= 200 and < 300
            ? live.ChangedAsync(me.HouseholdId, marked.Topics, me.UserId, origin)
            : Task.CompletedTask);
        return result;
    }
}
