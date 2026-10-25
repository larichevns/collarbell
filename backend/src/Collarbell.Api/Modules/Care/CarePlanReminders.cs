using System.Globalization;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Care;

/// <summary>
/// Reminders of care plans (spec 5.4, system-design 3.3 flow 2): on the days in the plan's
/// <see cref="CarePlan.RemindOffsetsDays"/> before it is due (7, 1 and 0 by default), at <see cref="At"/> household time.
/// A plan still not done is reminded again every <see cref="OverdueEveryDays"/> days, <see cref="OverdueTimes"/> times.
/// "Done" moves the plan to its next date, so the reminders of the old date are no longer needed.
/// </summary>
public sealed class CarePlanReminders(AppDbContext db, PetDirectory pets) : IReminderSource
{
    /// <summary>The time of day care reminders arrive.</summary>
    public static readonly TimeOnly At = new(10, 0);

    public const int OverdueEveryDays = 3;
    public const int OverdueTimes = 5;

    public ReminderSource Source => ReminderSource.CarePlan;

    public NotificationCategory Category => NotificationCategory.Care;

    public async Task<IReadOnlyList<PlannedReminder>> PlanAsync(Guid householdId, string timeZone, DateTimeOffset now, CancellationToken ct)
    {
        var activePets = await ActivePetsAsync(householdId, ct);
        var plans = await db.CarePlans.AsNoTracking()
            .Where(p => p.HouseholdId == householdId && p.Active)
            .ToListAsync(ct);

        var planned = new List<PlannedReminder>();
        foreach (var plan in plans.Where(p => activePets.ContainsKey(p.PetId)))
        {
            var subject = $"{activePets[plan.PetId]}: {plan.Title}";
            foreach (var (day, key) in Days(plan))
            {
                var fireAt = LocalTimes.Moment(day, At, timeZone);
                // The last day's ones only move reminders still waiting (see IReminderSource.PlanAsync).
                if (fireAt > now - TimeSpan.FromDays(1))
                {
                    planned.Add(new PlannedReminder(plan.Id, key, fireAt, subject));
                }
            }
        }

        return planned;
    }

    public async Task<IReadOnlyDictionary<Guid, ReminderContent>> ComposeAsync(
        IReadOnlyList<DueReminder> due, DateTimeOffset now, CancellationToken ct)
    {
        var ids = due.Select(r => r.SourceId).Distinct().ToList();
        var plans = await db.CarePlans.AsNoTracking().Where(p => ids.Contains(p.Id)).ToDictionaryAsync(p => p.Id, ct);
        var contents = new Dictionary<Guid, ReminderContent>();
        foreach (var household in due.GroupBy(r => r.HouseholdId))
        {
            var activePets = await ActivePetsAsync(household.Key, ct);
            foreach (var reminder in household)
            {
                // Still needed: the plan exists, is on, its pet is active, and it is still due on the date the
                // reminder was planned for (after "Done" it is due later).
                if (plans.TryGetValue(reminder.SourceId, out var plan)
                    && plan.HouseholdId == reminder.HouseholdId
                    && plan.Active
                    && activePets.TryGetValue(plan.PetId, out var petName)
                    && plan.NextDueOn == DueOn(reminder.Key))
                {
                    var today = LocalTimes.DateAt(now, reminder.TimeZone);
                    contents[reminder.Id] = new CareDue(plan.Id, plan.PetId, petName, plan.Title, plan.NextDueOn,
                        plan.NextDueOn.DayNumber - today.DayNumber);
                }
            }
        }

        return contents;
    }

    /// <summary>
    /// The days to remind on, with their keys: <c>2026-10-10/-7</c> is 7 days before the plan is due on 10 October,
    /// <c>2026-10-10/+3</c> the first reminder after it, when it wasn't done. A plan with no reminder days set isn't
    /// reminded at all, not even when overdue.
    /// </summary>
    internal static IEnumerable<(DateOnly Day, string Key)> Days(CarePlan plan)
    {
        if (plan.RemindOffsetsDays.Count == 0)
        {
            yield break;
        }

        var due = plan.NextDueOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        foreach (var before in plan.RemindOffsetsDays.Distinct())
        {
            yield return (plan.NextDueOn.AddDays(-before), before == 0 ? $"{due}/0" : $"{due}/-{before}");
        }

        for (var time = 1; time <= OverdueTimes; time++)
        {
            var after = time * OverdueEveryDays;
            yield return (plan.NextDueOn.AddDays(after), $"{due}/+{after}");
        }
    }

    private static DateOnly DueOn(string key) =>
        DateOnly.ParseExact(key[..10], "yyyy-MM-dd", CultureInfo.InvariantCulture);

    private async Task<Dictionary<Guid, string>> ActivePetsAsync(Guid householdId, CancellationToken ct) =>
        (await pets.CardsAsync(householdId, ct))
            .Where(p => p.Status == PetStatus.Active)
            .ToDictionary(p => p.Id, p => p.Name);
}
