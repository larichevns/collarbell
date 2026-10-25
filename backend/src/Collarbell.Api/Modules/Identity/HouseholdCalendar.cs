using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Time;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Identity;

/// <summary>
/// The date "today" for a household. Due dates are calendar dates, so "overdue" and "due soon" depend on
/// the household's time zone, not on the server's: at 23:30 in Berlin it is already tomorrow in Tbilisi.
/// </summary>
public sealed class HouseholdCalendar(AppDbContext db, TimeProvider clock)
{
    public async Task<DateOnly> TodayAsync(Guid householdId, CancellationToken ct) =>
        Today(await TimeZoneAsync(householdId, ct));

    /// <summary>The household's date at <paramref name="moment"/>, e.g. the day a note was written.</summary>
    public async Task<DateOnly> DateAtAsync(Guid householdId, DateTimeOffset moment, CancellationToken ct) =>
        LocalTimes.DateAt(moment, await TimeZoneAsync(householdId, ct));

    /// <summary>The household's IANA time zone, e.g. <c>Europe/Berlin</c>.</summary>
    public Task<string> TimeZoneAsync(Guid householdId, CancellationToken ct) =>
        db.Households
            .Where(h => h.Id == householdId)
            .Select(h => h.TimeZone)
            .SingleAsync(ct);

    public DateOnly Today(string timeZoneId) => LocalTimes.DateAt(clock.GetUtcNow(), timeZoneId);
}
