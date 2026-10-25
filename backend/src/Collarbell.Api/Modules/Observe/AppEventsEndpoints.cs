using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Identity;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Observe;

/// <param name="AtUnixMs">When it happened by the phone's clock, in milliseconds since 1970 (UTC): one number, whatever the time zone.</param>
/// <param name="Name">A screen's route (<c>/pets/:id/health</c>), an action (<c>fed</c>), an error's kind: never what the person typed.</param>
/// <param name="Detail">A little more: an error's status and trace id, a crash's type and top frames.</param>
public sealed record AppEventRequest(long AtUnixMs, AppEventKind Kind, string? Name, string? Detail);

/// <param name="Session">One launch of the app: a new random id each time it starts.</param>
public sealed record AppEventsRequest(Guid Session, string? AppVersion, List<AppEventRequest>? Events);

/// <summary>The app's reports about itself for the admin's "визор": screens, actions, errors, kept for a week.</summary>
public static class AppEventsEndpoints
{
    public const string Path = "/api/v1/events";
    public const int MaxEvents = 50;
    public const int MaxNameLength = 100;
    public const int MaxDetailLength = 500;

    /// <summary>One person's events a day: far above a real day in the app, far below filling the server's disk.</summary>
    public const int MaxEventsPerDay = 2000;

    /// <summary>How many reports one person's app may send a minute (Program.cs).</summary>
    public const string RateLimit = "app-events";

    public static RouteGroupBuilder MapAppEventsEndpoints(this RouteGroupBuilder api)
    {
        api.MapPost("/events", Report)
            .Personal()
            .RequireRateLimiting(RateLimit)
            .WithTags("Events")
            .WithName("ReportAppEvents")
            .WithSummary($"What the app did and saw (screens, actions, errors), up to {MaxEvents} at a time; kept for a week for support.");
        return api;
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> Report(
        AppEventsRequest request, CurrentUserAccessor current, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var errors = new ValidationErrors();
        if (request.Session == Guid.Empty)
        {
            errors.Add("session", "Send the id of this launch of the app.");
        }

        if (request.Events is null || request.Events.Count is 0 or > MaxEvents)
        {
            errors.Add("events", $"Send 1 to {MaxEvents} events.");
        }

        errors.MaxLength("appVersion", request.AppVersion, 32);
        for (var i = 0; i < (request.Events?.Count ?? 0); i++)
        {
            var e = request.Events![i];
            if (!Enum.IsDefined(e.Kind))
            {
                errors.Add($"events[{i}].kind", "Unknown kind.");
            }

            if (Text(e.Name) is null)
            {
                errors.Add($"events[{i}].name", "Name the event.");
            }

            errors.MaxLength($"events[{i}].name", e.Name, MaxNameLength);
            errors.MaxLength($"events[{i}].detail", e.Detail, MaxDetailLength);
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var me = await current.GetAsync(ct);
        var now = clock.GetUtcNow();

        // The person's row is held while the batch goes in: an account deletion at this moment either waits for it (and
        // then deletes these events too) or has finished, and then nothing is written.
        async Task<bool> WriteOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var present = await db.Database
                .SqlQuery<Guid>($"SELECT id AS \"Value\" FROM identity.users WHERE id = {me.UserId} FOR KEY SHARE")
                .ToListAsync(ct);
            if (present.Count == 0)
            {
                return false;
            }

            // Over a day's worth: the rest is dropped quietly, the app has nothing to do about it.
            var today = await db.AppEvents.CountAsync(e => e.UserId == me.UserId && e.ReceivedAt > now - TimeSpan.FromDays(1), ct);
            var room = Math.Max(0, MaxEventsPerDay - today);

            // A phone whose clock runs ahead: the whole batch moves back by the difference, so the order stays.
            var times = request.Events!.Select(e => DateTimeOffset.FromUnixTimeMilliseconds(Math.Clamp(e.AtUnixMs, 0, 253402300799999))).ToList();
            var ahead = times.Max() - now;
            var shift = ahead > TimeSpan.FromMinutes(5) ? ahead : TimeSpan.Zero;
            foreach (var (e, at) in request.Events!.Zip(times).Take(room))
            {
                var when = at - shift;
                db.AppEvents.Add(new AppEvent(me.UserId, me.HouseholdId, request.Session,
                    when < now - ObserveLimits.Retention ? now - ObserveLimits.Retention : when,
                    e.Kind, Text(e.Name)!, Text(e.Detail), Text(request.AppVersion), now));
            }

            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return true;
        }

        return await db.Database.CreateExecutionStrategy().ExecuteAsync(WriteOnce)
            ? TypedResults.NoContent()
            : AccountProblems.AccountDeleted();
    }

    /// <summary>Trimmed, without control characters (a NUL would make the database refuse the batch); null when empty.</summary>
    internal static string? Text(string? value) =>
        Input.Clean(value is null ? null : string.Concat(value.Where(c => !char.IsControl(c))));
}
