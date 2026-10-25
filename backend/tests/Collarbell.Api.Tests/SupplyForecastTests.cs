using Collarbell.Api.Modules.Supplies;

namespace Collarbell.Api.Tests;

/// <summary>The stock estimate (spec 5.3) on its own: counts, purchases, daily use, and the days to buy.</summary>
public sealed class SupplyForecastTests
{
    private const string Zone = "Europe/Berlin";

    /// <summary>Noon in Berlin, so whole days from now stay on the same local time.</summary>
    private static readonly DateTimeOffset Now = new(2026, 10, 2, 10, 0, 0, TimeSpan.Zero);

    private static readonly DateOnly Today = new(2026, 10, 2);

    private static StockEvent Count(decimal left, double daysAgo) =>
        new(Guid.Empty, Guid.Empty, StockEventKind.Adjustment, left, Guid.Empty, Now.AddDays(-daysAgo));

    private static StockEvent Bought(decimal amount, double daysAgo) =>
        new(Guid.Empty, Guid.Empty, StockEventKind.Purchase, amount, Guid.Empty, Now.AddDays(-daysAgo));

    private static SupplyForecast Forecast(IEnumerable<StockEvent> events, decimal? perDay, int leadTimeDays = 5) =>
        SupplyForecasts.Compute(events, perDay, leadTimeDays, Now, Zone);

    [Fact]
    public void Nothing_entered_yet_has_no_estimate()
    {
        var forecast = Forecast([], 80);

        Assert.Equal(SupplyStatus.NoStock, forecast.Status);
        Assert.Null(forecast.Remaining);
        Assert.Equal(80, forecast.UsagePerDay);
    }

    [Fact]
    public void A_count_is_used_up_day_by_day()
    {
        // 2 kg counted 5 days ago, 80 g a day: 1600 g left, 20 days; runs out on 22 October, buy by the 17th.
        var forecast = Forecast([Count(2000, 5)], 80);

        Assert.Equal(1600, forecast.Remaining);
        Assert.Equal(20, forecast.DaysLeft);
        Assert.Equal(Today.AddDays(20), forecast.RunsOutOn);
        Assert.Equal(Today.AddDays(15), forecast.BuyBy);
        Assert.Equal(SupplyStatus.Enough, forecast.Status);
        Assert.Equal(Now.AddDays(-5), forecast.CountedFrom);
    }

    [Fact]
    public void Purchases_after_the_count_are_added()
    {
        var forecast = Forecast([Count(500, 10), Bought(2000, 4)], 100);

        // 500 g ran out after 5 days; the bag bought 4 days ago is 400 g down since.
        Assert.Equal(1600, forecast.Remaining);
        Assert.Equal(Today.AddDays(16), forecast.RunsOutOn);
    }

    [Fact]
    public void A_bag_bought_after_the_old_one_ran_out_starts_full()
    {
        // Without stopping at empty, the 10 days without food would be taken from the new bag.
        var forecast = Forecast([Count(100, 12), Bought(1000, 1)], 100);

        Assert.Equal(900, forecast.Remaining);
    }

    [Fact]
    public void The_last_count_is_the_new_starting_point()
    {
        var forecast = Forecast([Bought(2000, 30), Bought(2000, 20), Count(1000, 2)], 100);

        Assert.Equal(800, forecast.Remaining);
        Assert.Equal(Now.AddDays(-2), forecast.CountedFrom);
    }

    [Fact]
    public void Without_any_count_the_first_purchase_is_the_start()
    {
        var forecast = Forecast([Bought(1000, 3), Bought(1000, 1)], 100);

        Assert.Equal(1700, forecast.Remaining);
        Assert.Equal(Now.AddDays(-3), forecast.CountedFrom);
    }

    [Theory]
    [InlineData(40, SupplyStatus.Enough)]
    // Buy within a week.
    [InlineData(10, SupplyStatus.Soon)]
    // Runs out within the 5 delivery days.
    [InlineData(4, SupplyStatus.BuyNow)]
    [InlineData(0, SupplyStatus.OutOfStock)]
    public void The_status_follows_the_day_to_buy(int daysLeft, SupplyStatus status)
    {
        var forecast = Forecast([Count(daysLeft * 100, 0)], 100);

        Assert.Equal(status, forecast.Status);
    }

    [Fact]
    public void Used_up_means_out_of_stock_since_the_day_it_ran_out()
    {
        var forecast = Forecast([Count(300, 5)], 100);

        Assert.Equal(0, forecast.Remaining);
        Assert.Equal(SupplyStatus.OutOfStock, forecast.Status);
        Assert.Equal(Today.AddDays(-2), forecast.RunsOutOn);
    }

    [Fact]
    public void Without_a_daily_use_only_the_stock_is_known()
    {
        var forecast = Forecast([Count(1000, 3)], null);

        Assert.Equal((1000m, SupplyStatus.NoUsage), (forecast.Remaining!.Value, forecast.Status));
        Assert.Null(forecast.RunsOutOn);
    }

    [Fact]
    public void A_tiny_daily_use_gives_no_dates()
    {
        var forecast = Forecast([Count(1000, 0)], 0.01m);

        Assert.Equal(SupplyStatus.Enough, forecast.Status);
        Assert.Null(forecast.RunsOutOn);
        Assert.Equal(SupplyForecasts.MaxDays, forecast.DaysLeft);
    }

    [Fact]
    public void The_dates_dont_move_as_time_passes()
    {
        var events = new[] { Count(2000, 0) };
        var now = SupplyForecasts.Compute(events, 80, 5, Now, Zone);
        var later = SupplyForecasts.Compute(events, 80, 5, Now.AddDays(3).AddHours(5), Zone);

        Assert.Equal(now.RunsOutOn, later.RunsOutOn);
        Assert.Equal(now.BuyBy, later.BuyBy);
    }
}
