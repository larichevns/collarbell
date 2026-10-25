using System.Globalization;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Routines;

/// <summary>
/// Feeding reminders: one per household and feeding time, for all pets fed then ("Feeding at 08:00: Murka, Barsik").
/// Planned <see cref="Horizon"/> ahead; the background planner keeps adding the next ones (spec 5.4). A pet already
/// marked as fed is left out when the reminder goes; when all are, it isn't sent. <see cref="FollowUpAfter"/> later a
/// second one goes for the pets nobody has marked yet ("Still not fed"), replacing the first on the phones.
/// </summary>
public sealed class FeedingReminders(AppDbContext db, PetDirectory pets) : IReminderSource
{
    public static readonly TimeSpan Horizon = TimeSpan.FromHours(48);

    /// <summary>When nobody has marked a feeding by then, everyone is reminded again (spec 2, "Семья").</summary>
    public static readonly TimeSpan FollowUpAfter = TimeSpan.FromMinutes(30);

    /// <summary>The key of the second reminder of a feeding time: <c>2026-10-02T08:00/again</c>.</summary>
    public const string FollowUpSuffix = "/again";

    public ReminderSource Source => ReminderSource.Feeding;

    public NotificationCategory Category => NotificationCategory.Feeding;

    public async Task<IReadOnlyList<PlannedReminder>> PlanAsync(Guid householdId, string timeZone, DateTimeOffset now, CancellationToken ct)
    {
        var feeding = await FeedingOfActivePetsAsync(householdId, ct);
        var today = LocalTimes.DateAt(now, timeZone);
        var planned = new List<PlannedReminder>();
        // From yesterday (the last day's ones only move reminders still waiting) to the end of the next 48 hours.
        for (var date = today.AddDays(-1); date <= today.AddDays(2); date = date.AddDays(1))
        {
            var slots = feeding
                .Where(f => f.Routine.OccursOn(date))
                .SelectMany(f => f.Routine.Times.Select(time => (Time: time, f.PetName)))
                .GroupBy(s => s.Time);
            foreach (var slot in slots)
            {
                var fireAt = LocalTimes.Moment(date, slot.Key, timeZone);
                var subject = Subject([.. slot.Select(s => s.PetName).Distinct().Order(StringComparer.CurrentCulture)]);
                if (fireAt > now - TimeSpan.FromDays(1) && fireAt <= now + Horizon)
                {
                    planned.Add(new PlannedReminder(householdId, Key(date, slot.Key), fireAt, subject));
                }

                var again = fireAt + FollowUpAfter;
                if (again > now - TimeSpan.FromDays(1) && again <= now + Horizon)
                {
                    planned.Add(new PlannedReminder(householdId, Key(date, slot.Key) + FollowUpSuffix, again, subject));
                }
            }
        }

        return planned;
    }

    public async Task<IReadOnlyDictionary<Guid, ReminderContent>> ComposeAsync(
        IReadOnlyList<DueReminder> due, DateTimeOffset now, CancellationToken ct)
    {
        var contents = new Dictionary<Guid, ReminderContent>();
        foreach (var household in due.GroupBy(r => r.HouseholdId))
        {
            var feeding = await FeedingOfActivePetsAsync(household.Key, ct);
            var slots = household.Select(r => (Reminder: r, Slot: ParseKey(r.Key))).ToList();
            var dates = slots.Select(s => s.Slot.Date).Distinct().ToList();
            var routineIds = feeding.Select(f => f.Routine.Id).ToList();
            var marked = (await db.RoutineCompletions.AsNoTracking()
                    .Where(c => routineIds.Contains(c.RoutineId) && dates.Contains(c.Date))
                    .Select(c => new { c.RoutineId, c.Date, c.Time })
                    .ToListAsync(ct))
                .Select(c => (c.RoutineId, c.Date, c.Time))
                .ToHashSet();

            foreach (var (reminder, (date, time, followUp)) in slots)
            {
                var hungry = feeding
                    .Where(f => f.Routine.OccursAt(date, time) && !marked.Contains((f.Routine.Id, date, time)))
                    .OrderBy(f => f.PetName, StringComparer.CurrentCulture)
                    .Select(f => new FeedingPortion(f.PetName, f.Routine.Food, f.Routine.Amount, UnitCode(f.Routine.Unit)))
                    .ToList();
                if (hungry.Count > 0)
                {
                    contents[reminder.Id] = new FeedingDue(date, time, hungry, followUp);
                }
            }
        }

        return contents;
    }

    /// <summary>"Barsik, Murka", or with many pets "Barsik, Murka, Rex, Tom, Bella +3".</summary>
    private static string Subject(IReadOnlyList<string> petNames) =>
        petNames.Count <= 5
            ? string.Join(", ", petNames)
            : $"{string.Join(", ", petNames.Take(5))} +{petNames.Count - 5}";

    /// <summary><c>2026-10-02T08:00</c>: the date and time of the feeding in the household's time zone.</summary>
    public static string Key(DateOnly date, TimeOnly time) =>
        $"{date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)}T{time.ToString("HH:mm", CultureInfo.InvariantCulture)}";

    private static (DateOnly Date, TimeOnly Time, bool FollowUp) ParseKey(string key) => (
        DateOnly.ParseExact(key[..10], "yyyy-MM-dd", CultureInfo.InvariantCulture),
        TimeOnly.ParseExact(key[11..16], "HH:mm", CultureInfo.InvariantCulture),
        key.EndsWith(FollowUpSuffix, StringComparison.Ordinal));

    private static string? UnitCode(PortionUnit? unit) => unit switch
    {
        PortionUnit.Gram => "g",
        PortionUnit.Milliliter => "ml",
        PortionUnit.Piece => "pcs",
        _ => null,
    };

    private async Task<List<(Routine Routine, string PetName)>> FeedingOfActivePetsAsync(Guid householdId, CancellationToken ct)
    {
        var activePets = (await pets.CardsAsync(householdId, ct))
            .Where(p => p.Status == PetStatus.Active)
            .ToDictionary(p => p.Id, p => p.Name);
        var routines = await db.Routines.AsNoTracking()
            .Where(r => r.HouseholdId == householdId && r.Active && r.Kind == RoutineKind.Feeding)
            .ToListAsync(ct);
        return [.. routines.Where(r => activePets.ContainsKey(r.PetId)).Select(r => (r, activePets[r.PetId]))];
    }
}

/// <summary>A feeding of the day with its mark, if any, for the Today screen.</summary>
public sealed record FeedingOccurrence(Routine Routine, TimeOnly Time, RoutineCompletionResponse? Mark);

/// <summary>Feeding for other modules: the Today screen.</summary>
public sealed class FeedingDirectory(AppDbContext db)
{
    /// <summary>Every feeding of active schedules on <paramref name="date"/>, with its mark; pets aren't filtered here.</summary>
    public async Task<List<FeedingOccurrence>> OnAsync(Guid householdId, Guid me, DateOnly date, CancellationToken ct)
    {
        var routines = (await db.Routines.AsNoTracking()
                .Where(r => r.HouseholdId == householdId && r.Active && r.Kind == RoutineKind.Feeding)
                .ToListAsync(ct))
            .Where(r => r.OccursOn(date))
            .ToList();
        var ids = routines.Select(r => r.Id).ToList();
        var marks = await db.RoutineCompletions.AsNoTracking()
            .Where(c => ids.Contains(c.RoutineId) && c.Date == date)
            .ToListAsync(ct);
        var names = await NamesAsync(db, marks.Select(m => m.DoneBy).OfType<Guid>(), ct);
        var byOccurrence = marks.ToDictionary(m => (m.RoutineId, m.Time));

        return [.. routines.SelectMany(r => r.Times.Select(time => new FeedingOccurrence(
            r,
            time,
            byOccurrence.TryGetValue((r.Id, time), out var mark) ? RoutinesEndpoints.ToResponse(mark, names, me) : null)))];
    }

    /// <summary>How people who marked feedings are called: their name, or their email when they have none.</summary>
    internal static async Task<Dictionary<Guid, string?>> NamesAsync(AppDbContext db, IEnumerable<Guid> userIds, CancellationToken ct)
    {
        var ids = userIds.Distinct().ToList();
        return await db.Users.AsNoTracking()
            .Where(u => ids.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.DisplayName ?? u.Email, ct);
    }
}
