using System.Globalization;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Notifications;

namespace Collarbell.Api.Modules.Supplies;

/// <summary>
/// "Time to buy" reminders (spec 5.3, system-design 3.3 flow 4): on the day to buy the item, which is its delivery time
/// before it runs out, and once more on the day it runs out, at <see cref="At"/> household time. A purchase or a count
/// moves the day it runs out, so the reminders of the old day are no longer needed. When the day to buy has passed
/// while the item still lasts (another pet eats it now, the delivery time grew), the reminder comes at the next
/// <see cref="At"/>.
/// </summary>
public sealed class SupplyReminders(SupplyStock stock) : IReminderSource
{
    /// <summary>The time of day supply reminders arrive, like care reminders.</summary>
    public static readonly TimeOnly At = new(10, 0);

    public ReminderSource Source => ReminderSource.Supply;

    public NotificationCategory Category => NotificationCategory.Supplies;

    public async Task<IReadOnlyList<PlannedReminder>> PlanAsync(Guid householdId, string timeZone, DateTimeOffset now, CancellationToken ct)
    {
        var planned = new List<PlannedReminder>();
        foreach (var state in await stock.StatesAsync(householdId, timeZone, now, ct))
        {
            if (!state.Item.Active || state.Forecast is not { RunsOutOn: { } runsOutOn, BuyBy: { } buyBy })
            {
                continue;
            }

            foreach (var (fireAt, key) in Moments(runsOutOn, buyBy, state.Forecast.Status, now, timeZone))
            {
                // The last day's ones only move reminders still waiting (see IReminderSource.PlanAsync).
                if (fireAt > now - TimeSpan.FromDays(1))
                {
                    planned.Add(new PlannedReminder(state.Item.Id, key, fireAt, state.Item.Name));
                }
            }
        }

        return planned;
    }

    public async Task<IReadOnlyDictionary<Guid, ReminderContent>> ComposeAsync(
        IReadOnlyList<DueReminder> due, DateTimeOffset now, CancellationToken ct)
    {
        var contents = new Dictionary<Guid, ReminderContent>();
        foreach (var household in due.GroupBy(r => (r.HouseholdId, r.TimeZone)))
        {
            var (householdId, timeZone) = household.Key;
            var states = (await stock.StatesAsync(householdId, timeZone, now, ct)).ToDictionary(s => s.Item.Id);
            var today = LocalTimes.DateAt(now, timeZone);
            foreach (var reminder in household)
            {
                // Still needed: the item is there and bought, and it still runs out on the day the reminder was planned
                // for (a purchase or a count moves that day).
                if (states.TryGetValue(reminder.SourceId, out var state)
                    && state.Item.Active
                    && state.Forecast is { RunsOutOn: { } runsOutOn, Status: SupplyStatus.BuyNow or SupplyStatus.OutOfStock }
                    && runsOutOn == RunsOutOn(reminder.Key))
                {
                    contents[reminder.Id] = new SupplyDue(state.Item.Id, state.Item.Name, runsOutOn,
                        runsOutOn.DayNumber - today.DayNumber, reminder.Key.EndsWith("/out", StringComparison.Ordinal));
                }
            }
        }

        return contents;
    }

    /// <summary>
    /// The moments to remind at, with their keys: <c>2026-10-14/buy/2026-10-09</c> on the day to buy (9 October) an
    /// item that runs out on 14 October, <c>2026-10-14/out</c> on that day itself. A day to buy that passed while the
    /// item still lasts moves to the next <see cref="At"/>; one that would come with the "runs out" reminder or after
    /// it is left out (that one says it all).
    /// </summary>
    internal static IEnumerable<(DateTimeOffset At, string Key)> Moments(
        DateOnly runsOutOn, DateOnly buyBy, SupplyStatus status, DateTimeOffset now, string timeZone)
    {
        var date = runsOutOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var outAt = LocalTimes.Moment(runsOutOn, At, timeZone);
        var buyAt = LocalTimes.Moment(buyBy, At, timeZone);
        if (buyAt <= now && status == SupplyStatus.BuyNow)
        {
            var today = LocalTimes.DateAt(now, timeZone);
            buyAt = LocalTimes.Moment(today, At, timeZone) is var todayAt && todayAt > now
                ? todayAt
                : LocalTimes.Moment(today.AddDays(1), At, timeZone);
        }

        if (buyAt < outAt)
        {
            yield return (buyAt, $"{date}/buy/{buyBy.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)}");
        }

        yield return (outAt, $"{date}/out");
    }

    private static DateOnly RunsOutOn(string key) =>
        DateOnly.ParseExact(key[..10], "yyyy-MM-dd", CultureInfo.InvariantCulture);
}
