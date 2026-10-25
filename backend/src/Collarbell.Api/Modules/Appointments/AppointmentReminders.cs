using System.Globalization;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Appointments;

/// <summary>
/// Reminders of planned visits: <see cref="Appointment.RemindOffsetsMinutes"/> before they begin (a day and two hours
/// by default). A visit moved to another time gets new reminders; a cancelled one gets none, nor does a visit whose
/// pets are all archived. A reminder can come up to <see cref="Grace"/> after the visit began (the one "at the start").
/// </summary>
public sealed class AppointmentReminders(AppDbContext db, PetDirectory pets) : IReminderSource
{
    public static readonly TimeSpan Grace = TimeSpan.FromMinutes(15);

    public ReminderSource Source => ReminderSource.Appointment;

    public NotificationCategory Category => NotificationCategory.Appointments;

    public async Task<IReadOnlyList<PlannedReminder>> PlanAsync(Guid householdId, string timeZone, DateTimeOffset now, CancellationToken ct)
    {
        var activePets = await ActivePetsAsync(householdId, ct);
        var since = now - TimeSpan.FromDays(1);
        var appointments = await db.Appointments.AsNoTracking()
            .Include(a => a.Pets)
            .Where(a => a.HouseholdId == householdId && a.Status == AppointmentStatus.Planned && a.StartsAt > since)
            .ToListAsync(ct);
        return [.. appointments
            .Where(a => ForActivePets(a, activePets))
            .SelectMany(a => a.RemindOffsetsMinutes
                .Select(minutes => new PlannedReminder(a.Id, Key(a.StartsAt, minutes), a.StartsAt.AddMinutes(-minutes), a.Title))
                .Where(r => r.FireAt > since))];
    }

    /// <summary>A visit is for active pets when at least one of its pets is active (or it names no pet).</summary>
    private static bool ForActivePets(Appointment visit, IReadOnlySet<Guid> activePets) =>
        visit.Pets.Count == 0 || visit.Pets.Exists(p => activePets.Contains(p.PetId));

    private async Task<HashSet<Guid>> ActivePetsAsync(Guid householdId, CancellationToken ct) =>
        [.. (await pets.CardsAsync(householdId, ct)).Where(p => p.Status == PetStatus.Active).Select(p => p.Id)];

    public async Task<IReadOnlyDictionary<Guid, ReminderContent>> ComposeAsync(
        IReadOnlyList<DueReminder> due, DateTimeOffset now, CancellationToken ct)
    {
        var ids = due.Select(r => r.SourceId).Distinct().ToList();
        var appointments = await db.Appointments.AsNoTracking()
            .Include(a => a.Pets)
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, ct);
        var contents = new Dictionary<Guid, ReminderContent>();
        foreach (var household in due.GroupBy(r => r.HouseholdId))
        {
            var cards = await pets.CardsAsync(household.Key, ct);
            var names = cards.ToDictionary(p => p.Id, p => p.Name);
            var activePets = cards.Where(p => p.Status == PetStatus.Active).Select(p => p.Id).ToHashSet();
            foreach (var reminder in household)
            {
                // Still needed: planned, at the time the reminder was planned for, for active pets, and not begun
                // longer than the grace ago.
                if (appointments.TryGetValue(reminder.SourceId, out var visit)
                    && visit.HouseholdId == reminder.HouseholdId
                    && visit.Status == AppointmentStatus.Planned
                    && reminder.Key.StartsWith(StartKey(visit.StartsAt), StringComparison.Ordinal)
                    && ForActivePets(visit, activePets)
                    && visit.StartsAt + Grace > now)
                {
                    var (date, time) = LocalTimes.LocalAt(visit.StartsAt, reminder.TimeZone);
                    var today = LocalTimes.DateAt(now, reminder.TimeZone);
                    contents[reminder.Id] = new VisitSoon(visit.Id, visit.Title, date, time, date.DayNumber - today.DayNumber,
                        visit.StartsAt, visit.Location,
                        [.. visit.Pets.Select(p => names.GetValueOrDefault(p.PetId)).OfType<string>().Order(StringComparer.CurrentCulture)]);
                }
            }
        }

        return contents;
    }

    /// <summary><c>20261005T0730Z/120</c>: two hours before the visit that begins at 07:30 UTC on 5 October.</summary>
    private static string Key(DateTimeOffset startsAt, int minutesBefore) =>
        $"{StartKey(startsAt)}{minutesBefore.ToString(CultureInfo.InvariantCulture)}";

    private static string StartKey(DateTimeOffset startsAt) =>
        startsAt.UtcDateTime.ToString("yyyyMMdd'T'HHmm'Z/'", CultureInfo.InvariantCulture);
}

/// <summary>Visits for other modules: the Today screen.</summary>
public sealed class AppointmentDirectory(AppDbContext db)
{
    /// <summary>Planned visits that begin from <paramref name="from"/> until <paramref name="until"/>, soonest first.</summary>
    public Task<List<Appointment>> PlannedBetweenAsync(Guid householdId, DateTimeOffset from, DateTimeOffset until, CancellationToken ct) =>
        db.Appointments.AsNoTracking()
            .Include(a => a.Pets)
            .Where(a => a.HouseholdId == householdId && a.Status == AppointmentStatus.Planned
                && a.StartsAt >= from && a.StartsAt < until)
            .OrderBy(a => a.StartsAt)
            .ToListAsync(ct);
}
