using NodaTime;

namespace Collarbell.Api.Infrastructure.Time;

/// <summary>
/// A household's local dates and times and moments in UTC, also across daylight saving time changes. The IANA
/// time zone database comes with NodaTime, so a server (or a container) without one of its own works the same.
/// </summary>
public static class LocalTimes
{
    /// <summary>The time zone with this IANA id, e.g. <c>Europe/Berlin</c>; UTC when the id is unknown.</summary>
    public static DateTimeZone Zone(string? id) =>
        (id is null ? null : DateTimeZoneProviders.Tzdb.GetZoneOrNull(id)) ?? DateTimeZone.Utc;

    public static bool IsKnownZone(string id) => DateTimeZoneProviders.Tzdb.GetZoneOrNull(id) is not null;

    /// <summary>The date on the calendar of <paramref name="zoneId"/> at <paramref name="moment"/>.</summary>
    public static DateOnly DateAt(DateTimeOffset moment, string? zoneId) =>
        Instant.FromDateTimeOffset(moment).InZone(Zone(zoneId)).Date.ToDateOnly();

    /// <summary>The local date and time in <paramref name="zoneId"/> at <paramref name="moment"/>.</summary>
    public static (DateOnly Date, TimeOnly Time) LocalAt(DateTimeOffset moment, string? zoneId)
    {
        var local = Instant.FromDateTimeOffset(moment).InZone(Zone(zoneId)).LocalDateTime;
        return (local.Date.ToDateOnly(), local.TimeOfDay.ToTimeOnly());
    }

    /// <summary>
    /// The moment a local date and time happen in <paramref name="zoneId"/>. A time the clocks skip in spring (02:30
    /// when they jump from 02:00 to 03:00) happens as much later as they jumped (03:30); a time that happens twice in
    /// autumn counts the first time.
    /// </summary>
    public static DateTimeOffset Moment(DateOnly date, TimeOnly time, string? zoneId) =>
        Zone(zoneId)
            .AtLeniently(LocalDate.FromDateOnly(date).At(LocalTime.FromTimeOnly(time)))
            .ToInstant()
            .ToDateTimeOffset();
}
