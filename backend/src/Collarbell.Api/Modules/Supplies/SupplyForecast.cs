using System.Text.Json.Serialization;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Routines;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Supplies;

/// <summary>How an item's stock looks, most urgent last.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<SupplyStatus>))]
public enum SupplyStatus
{
    /// <summary>No purchase or count entered yet: there is nothing to count from.</summary>
    NoStock,

    /// <summary>The stock is known, the daily use isn't (no feeding gives it, no use set by hand).</summary>
    NoUsage,

    Enough,

    /// <summary>The day to buy it comes within <see cref="SupplyForecasts.SoonDays"/> days.</summary>
    Soon,

    /// <summary>The day to buy it has come: it runs out within the delivery time.</summary>
    BuyNow,

    OutOfStock,
}

/// <summary>
/// The estimate (spec 5.3). <see cref="Remaining"/> and <see cref="UsagePerDay"/> are in the item's unit.
/// <see cref="RunsOutOn"/> and <see cref="BuyBy"/> are household dates; <see cref="BuyBy"/> is
/// <see cref="SupplyItem.LeadTimeDays"/> days before it runs out. <see cref="CountedFrom"/> is the purchase or count the
/// estimate starts from.
/// </summary>
public sealed record SupplyForecast(
    decimal? Remaining,
    decimal? UsagePerDay,
    decimal? DaysLeft,
    DateOnly? RunsOutOn,
    DateOnly? BuyBy,
    SupplyStatus Status,
    DateTimeOffset? CountedFrom);

public static class SupplyForecasts
{
    /// <summary>"Buy soon": the day to buy comes within a week.</summary>
    public const int SoonDays = 7;

    /// <summary>Beyond ten years a forecast says nothing useful (a tiny daily use), so it has no dates.</summary>
    public const int MaxDays = 3650;

    /// <summary>
    /// The stock at <paramref name="now"/>: from the last count (or the first purchase when nothing was ever counted),
    /// the daily use is taken away and later purchases are added. Use stops at empty: a bag bought after the old one
    /// ran out starts full.
    /// </summary>
    public static SupplyForecast Compute(
        IEnumerable<StockEvent> events, decimal? usagePerDay, int leadTimeDays, DateTimeOffset now, string timeZone)
    {
        var ordered = events.OrderBy(e => e.At).ThenBy(e => e.Id).ToList();
        var usage = usagePerDay is > 0 ? usagePerDay : null;
        var start = ordered.FindLastIndex(e => e.Kind == StockEventKind.Adjustment);
        if (start < 0)
        {
            start = ordered.FindIndex(e => e.Kind == StockEventKind.Purchase);
        }

        if (start < 0)
        {
            return new SupplyForecast(null, Round(usage, 3), null, null, null, SupplyStatus.NoStock, null);
        }

        var level = ordered[start].Quantity;
        var since = ordered[start].At;
        // After the last count there are only purchases.
        foreach (var purchase in ordered.Skip(start + 1))
        {
            level = Math.Max(0, level - Used(usage, since, purchase.At)) + purchase.Quantity;
            since = purchase.At;
        }

        var remaining = Math.Max(0, level - Used(usage, since, now));
        if (usage is not { } perDay)
        {
            return new SupplyForecast(Round(remaining, 3), null, null, null, null, SupplyStatus.NoUsage, ordered[start].At);
        }

        var daysLeft = remaining / perDay;
        if (level / perDay > MaxDays)
        {
            return new SupplyForecast(Round(remaining, 3), Round(perDay, 3), Math.Min(Round(daysLeft, 1), MaxDays), null, null,
                SupplyStatus.Enough, ordered[start].At);
        }

        // The moment it runs out doesn't move as time passes, so neither do the dates (and the reminders on them).
        var runsOutAt = since.AddDays((double)(level / perDay));
        var runsOutOn = LocalTimes.DateAt(runsOutAt, timeZone);
        var buyBy = runsOutOn.AddDays(-leadTimeDays);
        var today = LocalTimes.DateAt(now, timeZone);
        var status = remaining <= 0 ? SupplyStatus.OutOfStock
            : buyBy <= today ? SupplyStatus.BuyNow
            : buyBy <= today.AddDays(SoonDays) ? SupplyStatus.Soon
            : SupplyStatus.Enough;
        return new SupplyForecast(Round(remaining, 3), Round(perDay, 3), Round(daysLeft, 1), runsOutOn, buyBy, status, ordered[start].At);
    }

    /// <summary>The daily use of an item: set by hand, or the portions of the feedings that give it.</summary>
    public static decimal? UsagePerDay(SupplyItem item, IEnumerable<SupplyFeeding> feedings)
    {
        if (item.UsageMode == SupplyUsageMode.Manual)
        {
            return item.ManualDailyUsage;
        }

        var sum = feedings.Where(f => Counts(item, f)).Sum(f => f.Amount!.Value * f.TimesPerDay);
        return sum > 0 ? sum : null;
    }

    /// <summary>
    /// Whether a feeding's portion counts towards the item's use: it has an amount, in the item's unit (grams of a food
    /// counted in grams). A portion in pieces of a food counted in grams can't be converted.
    /// </summary>
    public static bool Counts(SupplyItem item, SupplyFeeding feeding) =>
        feeding.Amount is > 0 && feeding.Unit is { } unit && SameUnit(unit, item.Unit);

    /// <summary>Whether a portion in <paramref name="unit"/> can be counted against an item counted in <paramref name="itemUnit"/>.</summary>
    public static bool SameUnit(PortionUnit unit, SupplyUnit itemUnit) => (unit, itemUnit) switch
    {
        (PortionUnit.Gram, SupplyUnit.Gram) or (PortionUnit.Milliliter, SupplyUnit.Milliliter) or (PortionUnit.Piece, SupplyUnit.Piece) => true,
        _ => false,
    };

    private static decimal Used(decimal? usage, DateTimeOffset from, DateTimeOffset to) =>
        usage is { } perDay && to > from ? perDay * (decimal)(to - from).TotalDays : 0;

    private static decimal? Round(decimal? value, int decimals) => value is { } v ? Math.Round(v, decimals) : null;

    private static decimal Round(decimal value, int decimals) => Math.Round(value, decimals);
}

/// <summary>An item with its estimate and the feedings that use it.</summary>
public sealed record SupplyState(SupplyItem Item, SupplyForecast Forecast, IReadOnlyList<SupplyFeeding> Feedings);

/// <summary>
/// The Supplies module's public API: the household's items with their estimates, for the supplies screens, the Today
/// screen and the "time to buy" reminders.
/// </summary>
public sealed class SupplyStock(AppDbContext db, FeedingSupplies feeding)
{
    public async Task<List<SupplyState>> StatesAsync(
        Guid householdId, string timeZone, DateTimeOffset now, CancellationToken ct, Guid? only = null)
    {
        var items = await db.SupplyItems.AsNoTracking()
            .Where(i => i.HouseholdId == householdId && (only == null || i.Id == only))
            .ToListAsync(ct);
        if (items.Count == 0)
        {
            return [];
        }

        var ids = items.Select(i => i.Id).ToList();
        var events = (await db.StockEvents.AsNoTracking()
                .Where(e => ids.Contains(e.SupplyItemId))
                .ToListAsync(ct))
            .ToLookup(e => e.SupplyItemId);
        var feedings = (await feeding.OfAsync(householdId, ct)).ToLookup(f => f.SupplyItemId);
        return
        [
            .. items.Select(item =>
            {
                var uses = feedings[item.Id].ToList();
                var forecast = SupplyForecasts.Compute(events[item.Id], SupplyForecasts.UsagePerDay(item, uses),
                    item.LeadTimeDays, now, timeZone);
                return new SupplyState(item, forecast, uses);
            }),
        ];
    }
}
