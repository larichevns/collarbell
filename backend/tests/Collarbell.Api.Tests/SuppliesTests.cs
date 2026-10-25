using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Collarbell.Api.Modules.Supplies;
using Collarbell.Api.Modules.Today;
using Microsoft.EntityFrameworkCore;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Supplies: items, purchases and counts, the estimate from feeding, "time to buy", and barcode lookups.</summary>
[Collection(ApiCollection.Name)]
public sealed class SuppliesTests(ApiFactory api)
{
    /// <summary>A household where it is about noon now, so whole days ahead keep their dates.</summary>
    private static async Task<(string Zone, DateOnly Today)> NoonAsync(HttpClient client)
    {
        var zone = ZoneWhereItIsAbout(12);
        await client.SetTimeZoneAsync(zone);
        return (zone, LocalTimes.DateAt(DateTimeOffset.UtcNow, zone));
    }

    /// <summary>A UPC-A barcode no other test uses: 11 random digits and their check digit. Saved as its EAN-13, "0" + it.</summary>
    private static string NewBarcode()
    {
        var digits = string.Concat(Enumerable.Range(0, 11).Select(_ => (char)('0' + Random.Shared.Next(10))));
        var sum = 0;
        for (int i = digits.Length - 1, weight = 3; i >= 0; i--, weight = 4 - weight)
        {
            sum += (digits[i] - '0') * weight;
        }

        return digits + ((10 - (sum % 10)) % 10);
    }

    private static Task<HttpResponseMessage> LookupAsync(HttpClient client, string code) =>
        client.GetAsync($"/api/v1/products/lookup?code={Uri.EscapeDataString(code)}", Ct);

    [Fact]
    public async Task An_item_is_saved_with_what_is_there_now()
    {
        var client = api.ClientFor($"supplies-crud-{Guid.NewGuid():N}");

        var item = await client.CreateSupplyAsync(Supply("  Royal Canin Sterilised  ", stock: 1500) with
        {
            Brand = "Royal Canin",
            KcalPerKg = 3860,
            StoreUrl = "https://shop.example/royal-canin",
            LeadTimeDays = 3,
        });

        Assert.Equal(("Royal Canin Sterilised", SupplyUsageMode.Feeding, 3, true), (item.Name, item.UsageMode, item.LeadTimeDays, item.Active));
        // Food counts from the feedings; none uses it yet.
        Assert.Equal((1500m, SupplyStatus.NoUsage), (item.Forecast.Remaining!.Value, item.Forecast.Status));

        var litter = await client.CreateSupplyAsync(Supply("Litter", 10_000, category: SupplyCategory.Litter));
        Assert.Equal((SupplyUsageMode.Manual, SupplyStatus.NoStock), (litter.UsageMode, litter.Forecast.Status));

        var list = await client.GetFromJsonAsync<List<SupplyResponse>>("/api/v1/supplies", Json, Ct);
        Assert.Equal([item.Id, litter.Id], list!.Select(s => s.Id).Order());

        var updated = await client.PutAsJsonAsync($"/api/v1/supplies/{item.Id}",
            Supply("Royal Canin Sterilised 37") with { Active = false }, Json, Ct);
        var saved = (await updated.Content.ReadFromJsonAsync<SupplyResponse>(Json, Ct))!;
        // Left out, the delivery time stays.
        Assert.Equal(("Royal Canin Sterilised 37", false, 3), (saved.Name, saved.Active, saved.LeadTimeDays));
        // The stock stays as entered.
        Assert.Equal(1500m, saved.Forecast.Remaining);

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/v1/supplies/{item.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/supplies/{item.Id}", Ct)).StatusCode);
    }

    [Fact]
    public async Task An_item_needs_a_name_a_size_and_sensible_details()
    {
        var client = api.ClientFor($"supplies-invalid-{Guid.NewGuid():N}");

        foreach (var (request, field) in new (SupplyRequest, string)[]
        {
            (Supply("  "), "name"),
            (Supply("Food", packageSize: 0), "packageSize"),
            (Supply("Food") with { Barcode = "4006381333932" }, "barcode"),
            (Supply("Food") with { StoreUrl = "javascript:alert(1)" }, "storeUrl"),
            (Supply("Food") with { LeadTimeDays = 61 }, "leadTimeDays"),
            (Supply("Food") with { KcalPerKg = 0 }, "kcalPerKg"),
            (Supply("Food") with { ManualDailyUsage = -1 }, "manualDailyUsage"),
            (Supply("Food", stock: -1), "initialStock"),
            // Too big to check the stock against: refused, not a 500.
            (Supply("Food", packageSize: 1e26m, stock: 1), "packageSize"),
            // Kept as 0 with the decimals stored.
            (Supply("Food", packageSize: 0.0004m), "packageSize"),
            (Supply("Food") with { ManualDailyUsage = 0.0000004m }, "manualDailyUsage"),
            (Supply("Food") with { Category = (SupplyCategory)99 }, "category"),
        })
        {
            var response = await client.PostAsJsonAsync("/api/v1/supplies", request, Json, Ct);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Contains($"\"{field}\"", await response.Content.ReadAsStringAsync(Ct));
        }
    }

    [Fact]
    public async Task One_item_per_barcode_in_a_household()
    {
        var client = api.ClientFor($"supplies-barcode-{Guid.NewGuid():N}");
        var barcode = NewBarcode();

        var first = await client.CreateSupplyAsync(Supply("Food") with { Barcode = barcode });
        Assert.Equal("0" + barcode, first.Barcode);

        var second = await client.PostAsJsonAsync("/api/v1/supplies", Supply("Same food") with { Barcode = "0" + barcode }, Json, Ct);
        Assert.Equal(HttpStatusCode.BadRequest, second.StatusCode);
        Assert.Contains("\"barcode\"", await second.Content.ReadAsStringAsync(Ct));

        // Another household may have the same product.
        var other = api.ClientFor($"supplies-barcode-other-{Guid.NewGuid():N}");
        await other.CreateSupplyAsync(Supply("Food") with { Barcode = barcode });
    }

    [Fact]
    public async Task A_retried_create_makes_one_item()
    {
        var client = api.ClientFor($"supplies-retry-{Guid.NewGuid():N}");
        var request = Supply("Food", stock: 2000) with { RequestId = Guid.NewGuid() };

        var first = await client.CreateSupplyAsync(request);
        var again = await client.CreateSupplyAsync(request);

        Assert.Equal(first.Id, again.Id);
        Assert.Single((await client.GetFromJsonAsync<List<SupplyResponse>>("/api/v1/supplies", Json, Ct))!);
    }

    [Fact]
    public async Task The_daily_use_of_food_comes_from_the_feedings()
    {
        var client = api.ClientFor($"supplies-feeding-{Guid.NewGuid():N}");
        var (zone, _) = await NoonAsync(client);
        var murka = await client.CreatePetAsync("Murka");
        var barsik = await client.CreatePetAsync("Barsik");
        var food = await client.CreateSupplyAsync(Supply("Royal Canin", stock: 2000));

        // Murka 40 g twice a day, Barsik 30 g on weekends only: 80 + 2 × 30 × 2/7 a day.
        var murkaFeeding = await client.CreateRoutineAsync(murka.Id, Feeding(new TimeOnly(8, 0), new(20, 0)) with
        {
            Food = "ignored",
            Amount = 40,
            Unit = PortionUnit.Gram,
            SupplyItemId = food.Id,
        });
        await client.CreateRoutineAsync(barsik.Id, Feeding(new TimeOnly(9, 0), new(21, 0)) with
        {
            Days = [DayOfWeek.Saturday, DayOfWeek.Sunday],
            Amount = 30,
            Unit = PortionUnit.Gram,
            SupplyItemId = food.Id,
        });
        Assert.Equal(("Royal Canin", food.Id), (murkaFeeding.Food, murkaFeeding.SupplyItemId));

        var withFeeding = await client.GetSupplyAsync(food.Id);
        Assert.Equal(Math.Round(80 + (60 * 2 / 7m), 3), withFeeding.Forecast.UsagePerDay);
        Assert.Equal(["Barsik", "Murka"], withFeeding.Feedings.Select(f => f.PetName));
        Assert.All(withFeeding.Feedings, f => Assert.True(f.Counted));
        Assert.Equal(SupplyStatus.Enough, withFeeding.Forecast.Status);
        Assert.Equal(LocalTimes.DateAt(withFeeding.Forecast.CountedFrom!.Value.AddDays((double)(2000 / (80 + (120 / 7m)))), zone),
            withFeeding.Forecast.RunsOutOn);

        // An archived pet eats no more.
        var archive = await client.PutAsJsonAsync($"/api/v1/pets/{barsik.Id}", Pet("Barsik") with { Status = PetStatus.Archived }, Ct);
        Assert.Equal(HttpStatusCode.OK, archive.StatusCode);
        Assert.Equal(80m, (await client.GetSupplyAsync(food.Id)).Forecast.UsagePerDay);

        // Renaming the item renames the food of its feedings.
        await client.PutAsJsonAsync($"/api/v1/supplies/{food.Id}", Supply("Royal Canin 37"), Json, Ct);
        var routine = await client.GetFromJsonAsync<RoutineResponse>($"/api/v1/routines/{murkaFeeding.Id}", Json, Ct);
        Assert.Equal("Royal Canin 37", routine!.Food);

        // Counted in pieces now, the portions in grams don't count: no daily use.
        await client.PutAsJsonAsync($"/api/v1/supplies/{food.Id}", Supply("Royal Canin 37", 12, unit: SupplyUnit.Piece), Json, Ct);
        var pieces = await client.GetSupplyAsync(food.Id);
        Assert.Equal(SupplyStatus.NoUsage, pieces.Forecast.Status);
        Assert.False(Assert.Single(pieces.Feedings).Counted);

        // Deleting the item leaves the feeding with the name, without the link.
        await client.DeleteAsync($"/api/v1/supplies/{food.Id}", Ct);
        routine = await client.GetFromJsonAsync<RoutineResponse>($"/api/v1/routines/{murkaFeeding.Id}", Json, Ct);
        Assert.Equal(("Royal Canin 37", (Guid?)null), (routine!.Food, routine.SupplyItemId));
    }

    [Fact]
    public async Task A_feeding_links_only_to_a_food_of_the_household_in_its_unit()
    {
        var client = api.ClientFor($"supplies-link-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var pouches = await client.CreateSupplyAsync(Supply("Pouches", 12, category: SupplyCategory.WetFood, unit: SupplyUnit.Piece));
        var foreign = await api.ClientFor($"supplies-link-other-{Guid.NewGuid():N}").CreateSupplyAsync(Supply("Their food"));

        var grams = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/routines",
            Feeding(new TimeOnly(8, 0)) with { Amount = 85, Unit = PortionUnit.Gram, SupplyItemId = pouches.Id }, Json, Ct);
        Assert.Equal(HttpStatusCode.BadRequest, grams.StatusCode);
        Assert.Contains("\"unit\"", await grams.Content.ReadAsStringAsync(Ct));

        var theirs = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/routines",
            Feeding(new TimeOnly(8, 0)) with { SupplyItemId = foreign.Id }, Json, Ct);
        Assert.Equal(HttpStatusCode.BadRequest, theirs.StatusCode);
        Assert.Contains("\"supplyItemId\"", await theirs.Content.ReadAsStringAsync(Ct));

        await client.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0)) with { Amount = 1, Unit = PortionUnit.Piece, SupplyItemId = pouches.Id });
        Assert.Equal(1m, (await client.GetSupplyAsync(pouches.Id)).Forecast.UsagePerDay);
    }

    [Fact]
    public async Task Purchases_and_counts_change_the_estimate()
    {
        var client = api.ClientFor($"supplies-stock-{Guid.NewGuid():N}");
        var litter = await client.CreateSupplyAsync(Supply("Litter", 10_000, category: SupplyCategory.Litter) with
        {
            ManualDailyUsage = 10_000 / 30m,
        });
        Assert.Equal(SupplyStatus.NoStock, litter.Forecast.Status);

        // A third of a kilo a day is used while the test runs: a gram at most.
        var bought = await client.AddStockAsync(litter.Id, StockEventKind.Purchase, 20_000);
        Assert.InRange(bought.Forecast.Remaining!.Value, 19_999, 20_000);
        Assert.Equal(60m, bought.Forecast.DaysLeft);

        var counted = await client.AddStockAsync(litter.Id, StockEventKind.Adjustment, 5_000);
        Assert.InRange(counted.Forecast.Remaining!.Value, 4_999, 5_000);

        var events = (await client.GetFromJsonAsync<List<StockEventResponse>>($"/api/v1/supplies/{litter.Id}/stock-events", Json, Ct))!;
        Assert.Equal([StockEventKind.Adjustment, StockEventKind.Purchase], events.Select(e => e.Kind));
        Assert.True(events[0].ByMe);

        // Taking the count back: the purchase is what counts again.
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.DeleteAsync($"/api/v1/supplies/{litter.Id}/stock-events/{events[0].Id}", Ct)).StatusCode);
        Assert.InRange((await client.GetSupplyAsync(litter.Id)).Forecast.Remaining!.Value, 19_999, 20_000);

        foreach (var nothing in new[] { 0m, 0.0004m })
        {
            var response = await client.PostAsJsonAsync($"/api/v1/supplies/{litter.Id}/stock-events",
                new StockEventRequest(StockEventKind.Purchase, nothing, null), Json, Ct);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }
        // "Nothing left" is a count.
        Assert.Equal(SupplyStatus.OutOfStock, (await client.AddStockAsync(litter.Id, StockEventKind.Adjustment, 0)).Forecast.Status);
    }

    [Fact]
    public async Task Buying_an_item_no_longer_bought_makes_it_bought_again()
    {
        var client = api.ClientFor($"supplies-reactivate-{Guid.NewGuid():N}");
        var food = await client.CreateSupplyAsync(Supply("Food", stock: 0) with { Active = false });

        var counted = await client.AddStockAsync(food.Id, StockEventKind.Adjustment, 500);
        Assert.False(counted.Active);
        var bought = await client.AddStockAsync(food.Id, StockEventKind.Purchase, 2000);

        Assert.True(bought.Active);
    }

    [Fact]
    public async Task A_retried_purchase_counts_once()
    {
        var client = api.ClientFor($"supplies-purchase-retry-{Guid.NewGuid():N}");
        var food = await client.CreateSupplyAsync(Supply("Food", stock: 0));
        var request = new StockEventRequest(StockEventKind.Purchase, 4000, Guid.NewGuid());

        var first = await client.PostAsJsonAsync($"/api/v1/supplies/{food.Id}/stock-events", request, Json, Ct);
        var again = await client.PostAsJsonAsync($"/api/v1/supplies/{food.Id}/stock-events", request, Json, Ct);

        Assert.Equal((HttpStatusCode.Created, HttpStatusCode.OK), (first.StatusCode, again.StatusCode));
        Assert.Equal(4000m, (await client.GetSupplyAsync(food.Id)).Forecast.Remaining);
    }

    [Fact]
    public async Task What_runs_out_soon_is_on_today_and_first_on_the_list()
    {
        var client = api.ClientFor($"supplies-today-{Guid.NewGuid():N}");
        var (_, today) = await NoonAsync(client);
        var plenty = await client.CreateSupplyAsync(Supply("Plenty", category: SupplyCategory.Treats, stock: 1000) with { ManualDailyUsage = 10 });
        var low = await client.CreateSupplyAsync(Supply("Low", category: SupplyCategory.Treats, stock: 300) with { ManualDailyUsage = 100 });
        var gone = await client.CreateSupplyAsync(Supply("Gone", category: SupplyCategory.Treats, stock: 0) with { ManualDailyUsage = 100 });
        await client.CreateSupplyAsync(Supply("Paused", category: SupplyCategory.Treats, stock: 0) with { ManualDailyUsage = 100, Active = false });

        var list = (await client.GetFromJsonAsync<List<SupplyResponse>>("/api/v1/supplies", Json, Ct))!;
        Assert.Equal(["Gone", "Low", "Plenty", "Paused"], list.Select(s => s.Name));
        Assert.Equal(SupplyStatus.BuyNow, list[1].Forecast.Status);
        Assert.Equal(today.AddDays(3), list[1].Forecast.RunsOutOn);

        var shopping = (await client.GetFromJsonAsync<TodayResponse>("/api/v1/today", Json, Ct))!.Shopping;
        Assert.Equal([(gone.Id, SupplyStatus.OutOfStock), (low.Id, SupplyStatus.BuyNow)], shopping.Select(s => (s.Id, s.Status)));
        Assert.DoesNotContain(shopping, s => s.Id == plenty.Id);
    }

    [Fact]
    public async Task Time_to_buy_is_reminded_on_the_day_to_buy_and_the_day_it_runs_out()
    {
        var client = api.ClientFor($"supplies-remind-{Guid.NewGuid():N}");
        var (zone, today) = await NoonAsync(client);
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        // 10 days left, 3 days for delivery: buy in 7 days, runs out in 10.
        var food = await client.CreateSupplyAsync(Supply("Royal Canin", category: SupplyCategory.Treats, stock: 1000) with
        {
            ManualDailyUsage = 100,
            LeadTimeDays = 3,
        });

        var reminders = (await api.RemindersOfAsync(me.Household.Id)).Where(r => r.SourceId == food.Id).ToList();
        var runsOut = today.AddDays(10).ToString("yyyy-MM-dd");
        Assert.Equal([$"{runsOut}/buy/{today.AddDays(7):yyyy-MM-dd}", $"{runsOut}/out"], reminders.Select(r => r.Key));
        Assert.Equal(LocalTimes.Moment(today.AddDays(7), SupplyReminders.At, zone), reminders[0].FireAt);
        Assert.All(reminders, r => Assert.Equal(NotificationCategory.Supplies, r.Category));

        await api.SendRemindersAsync(reminders[0].FireAt);
        var push = Assert.Single(api.Push.To(token));
        Assert.Equal(("Time to buy: Royal Canin", "Enough for about 3 days, until " + today.AddDays(10).ToString("MMMM d", System.Globalization.CultureInfo.InvariantCulture)),
            (push.Title, push.Body));
        Assert.Equal(("supplies", "supply", food.Id.ToString()), (push.Channel, push.Data["kind"], push.Data["supplyId"]));

        // Bought meanwhile, without the reminders being planned again (as if the refresh failed): the second one is
        // no longer needed.
        await api.ChangeDatabaseAsync(async db =>
        {
            db.StockEvents.Add(new StockEvent(me.Household.Id, food.Id, StockEventKind.Purchase, 2000, me.Id, DateTimeOffset.UtcNow));
            await db.SaveChangesAsync(Ct);
        });
        await api.SendRemindersAsync(reminders[1].FireAt);
        Assert.Single(api.Push.To(token));
        var second = (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.Id == reminders[1].Id);
        Assert.Equal((ReminderStatus.Skipped, ReminderReason.NotNeeded), (second.Status, second.Reason));
    }

    [Fact]
    public async Task A_purchase_moves_the_reminders()
    {
        var client = api.ClientFor($"supplies-remind-move-{Guid.NewGuid():N}");
        var (_, today) = await NoonAsync(client);
        var me = await client.MeAsync();
        var food = await client.CreateSupplyAsync(Supply("Food", category: SupplyCategory.Treats, stock: 1000) with { ManualDailyUsage = 100 });

        await client.AddStockAsync(food.Id, StockEventKind.Purchase, 1000);

        var keys = (await api.RemindersOfAsync(me.Household.Id))
            .Where(r => r.SourceId == food.Id && r.Status == ReminderStatus.Pending)
            .Select(r => r.Key);
        var runsOut = today.AddDays(20).ToString("yyyy-MM-dd");
        Assert.Equal([$"{runsOut}/buy/{today.AddDays(15):yyyy-MM-dd}", $"{runsOut}/out"], keys);
    }

    [Fact]
    public async Task A_day_to_buy_that_passed_while_it_lasts_is_reminded_the_next_morning()
    {
        var client = api.ClientFor($"supplies-remind-late-{Guid.NewGuid():N}");
        var (zone, today) = await NoonAsync(client);
        var me = await client.MeAsync();
        // 3 days left, 5 days for delivery: the day to buy was two days ago.
        var food = await client.CreateSupplyAsync(Supply("Food", category: SupplyCategory.Treats, stock: 300) with { ManualDailyUsage = 100 });

        var reminders = (await api.RemindersOfAsync(me.Household.Id)).Where(r => r.SourceId == food.Id).ToList();

        var runsOut = today.AddDays(3).ToString("yyyy-MM-dd");
        Assert.Equal([$"{runsOut}/buy/{today.AddDays(-2):yyyy-MM-dd}", $"{runsOut}/out"], reminders.Select(r => r.Key));
        // It is about noon there: tomorrow's 10:00.
        Assert.Equal(LocalTimes.Moment(today.AddDays(1), SupplyReminders.At, zone), reminders[0].FireAt);
    }

    [Fact]
    public async Task Without_delivery_time_only_the_day_it_runs_out_is_reminded()
    {
        var client = api.ClientFor($"supplies-remind-no-lead-{Guid.NewGuid():N}");
        var (_, today) = await NoonAsync(client);
        var me = await client.MeAsync();
        var food = await client.CreateSupplyAsync(Supply("Food", category: SupplyCategory.Treats, stock: 1000) with
        {
            ManualDailyUsage = 100,
            LeadTimeDays = 0,
        });

        var keys = (await api.RemindersOfAsync(me.Household.Id)).Where(r => r.SourceId == food.Id).Select(r => r.Key);

        Assert.Equal([$"{today.AddDays(10):yyyy-MM-dd}/out"], keys);
    }

    [Fact]
    public async Task An_occasion_reminded_long_ago_doesnt_stop_the_households_reminders()
    {
        var client = api.ClientFor($"supplies-remind-old-{Guid.NewGuid():N}");
        await NoonAsync(client);
        var me = await client.MeAsync();
        var food = await client.CreateSupplyAsync(Supply("Food", category: SupplyCategory.Treats, stock: 1000) with { ManualDailyUsage = 100 });
        // The "runs out" reminder went out long ago (as if its occasion came back into the future since).
        var outKey = (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.SourceId == food.Id && r.Key.EndsWith("/out")).Key;
        await api.ChangeDatabaseAsync(db => db.Reminders
            .Where(r => r.SourceId == food.Id && r.Key == outKey)
            .ExecuteUpdateAsync(s => s
                .SetProperty(r => r.Status, ReminderStatus.Sent)
                .SetProperty(r => r.FireAt, DateTimeOffset.UtcNow.AddDays(-5)), Ct));

        // Planned again: the old one isn't added twice, and the rest of the household is still planned.
        var pet = await client.CreatePetAsync("Murka");
        await client.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(9, 0)));

        var reminders = await api.RemindersOfAsync(me.Household.Id);
        Assert.Equal(ReminderStatus.Sent, reminders.Single(r => r.Key == outKey).Status);
        Assert.Contains(reminders, r => r.Source == ReminderSource.Feeding);
    }

    [Fact]
    public async Task A_new_delivery_time_is_a_new_day_to_buy()
    {
        var client = api.ClientFor($"supplies-remind-lead-{Guid.NewGuid():N}");
        var (_, today) = await NoonAsync(client);
        var me = await client.MeAsync();
        var request = Supply("Food", category: SupplyCategory.Treats, stock: 1000) with { ManualDailyUsage = 100, LeadTimeDays = 3 };
        var food = await client.CreateSupplyAsync(request);
        // The first day to buy was reminded already.
        await api.ChangeDatabaseAsync(db => db.Reminders
            .Where(r => r.SourceId == food.Id && r.Key.Contains("/buy/"))
            .ExecuteUpdateAsync(s => s.SetProperty(r => r.Status, ReminderStatus.Sent), Ct));

        var updated = await client.PutAsJsonAsync($"/api/v1/supplies/{food.Id}", request with { LeadTimeDays = 5 }, Json, Ct);
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);

        var buys = (await api.RemindersOfAsync(me.Household.Id))
            .Where(r => r.SourceId == food.Id && r.Key.Contains("/buy/"))
            .Select(r => (r.Key[^10..], r.Status))
            .OrderBy(r => r.Item1);
        Assert.Equal([
            ($"{today.AddDays(5):yyyy-MM-dd}", ReminderStatus.Pending),
            ($"{today.AddDays(7):yyyy-MM-dd}", ReminderStatus.Sent),
        ], buys);
    }

    [Fact]
    public async Task Supplies_are_a_kind_of_notification_that_can_be_turned_off()
    {
        var client = api.ClientFor($"supplies-settings-{Guid.NewGuid():N}");

        var settings = await client.GetFromJsonAsync<NotificationSettingsResponse>("/api/v1/notifications/settings", Json, Ct);

        Assert.Contains(settings!.Categories, c => c.Category == NotificationCategory.Supplies && c.Enabled);
    }

    [Fact]
    public async Task A_barcode_is_looked_up_in_the_household_the_catalog_and_the_databases()
    {
        var client = api.ClientFor($"supplies-lookup-{Guid.NewGuid():N}", "lookup@example.com");
        var (fromCatalog, fromOpen, fromUpc, unknown) = (NewBarcode(), NewBarcode(), NewBarcode(), NewBarcode());
        api.OpenPetFoodFacts.Products["0" + fromOpen] = new ProductDetails("Sterilised 37", "Royal Canin", SupplyCategory.DryFood,
            SupplyUnit.Gram, 2000, 3860);
        api.UpcItemDb.Products["0" + fromUpc] = new ProductDetails("Catsan Hygiene", "Catsan", null, null, null, null);
        // Open Pet Food Facts is down for this one: UPCitemdb is asked instead.
        api.OpenPetFoodFacts.Down["0" + fromUpc] = true;

        // Saved by another household as typed: it is in the catalog now.
        await api.ClientFor($"supplies-lookup-other-{Guid.NewGuid():N}").CreateSupplyAsync(
            Supply("Brit Care", 400, category: SupplyCategory.WetFood) with { Barcode = fromCatalog, KcalPerKg = 900 });

        async Task<ProductLookupResponse> Look(string code)
        {
            var response = await LookupAsync(client, code);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return (await response.Content.ReadFromJsonAsync<ProductLookupResponse>(Json, Ct))!;
        }

        var catalog = await Look(fromCatalog);
        Assert.Equal((ProductLookupSource.Catalog, "Brit Care", 400m, 900), (catalog.Source!.Value, catalog.Product!.Name, catalog.Product.PackageSize!.Value, catalog.Product.KcalPerKg!.Value));
        Assert.DoesNotContain("0" + fromCatalog, api.OpenPetFoodFacts.Asked);

        var open = await Look(fromOpen);
        Assert.Equal((ProductLookupSource.OpenPetFoodFacts, "Sterilised 37"), (open.Source!.Value, open.Product!.Name));

        var upc = await Look(fromUpc);
        Assert.Equal((ProductLookupSource.UpcItemDb, "Catsan Hygiene"), (upc.Source!.Value, upc.Product!.Name));

        var none = await Look(unknown);
        Assert.Equal(("0" + unknown, (ProductDetails?)null, (ProductLookupSource?)null), (none.Code, none.Product, none.Source));

        // Already in supplies: the item, not the product.
        var mine = await client.CreateSupplyAsync(Supply("My food") with { Barcode = unknown });
        var existing = await Look(unknown);
        Assert.Equal(mine.Id, existing.Existing!.Id);

        // A medicine's DataMatrix: the product, its batch and expiry date.
        var datamatrix = await Look($"01{"0" + "0" + fromOpen}17271231\u001d10LOT42");
        Assert.Equal(("0" + fromOpen, "LOT42", new DateOnly(2027, 12, 31)), (datamatrix.Code, datamatrix.Batch, datamatrix.ExpiresOn!.Value));

        Assert.Equal(HttpStatusCode.BadRequest, (await LookupAsync(client, "https://example.com")).StatusCode);
    }

    [Fact]
    public async Task The_first_confirmed_product_stays_in_the_catalog()
    {
        var barcode = NewBarcode();
        await api.ClientFor($"supplies-catalog-first-{Guid.NewGuid():N}").CreateSupplyAsync(
            Supply("Whiskas pouches", 12, category: SupplyCategory.WetFood, unit: SupplyUnit.Piece) with { Barcode = barcode });

        // Another household's own words don't replace it.
        await api.ClientFor($"supplies-catalog-second-{Guid.NewGuid():N}").CreateSupplyAsync(
            Supply("Murka's kidney diet", 1020, category: SupplyCategory.WetFood) with { Barcode = barcode });

        await api.ChangeDatabaseAsync(async db =>
        {
            var product = await db.Products.SingleAsync(p => p.Barcode == "0" + barcode, Ct);
            Assert.Equal(("Whiskas pouches", SupplyUnit.Piece, 12m, 2), (product.Name, product.Unit, product.PackageSize, product.ConfirmedCount));
        });
    }

    [Fact]
    public async Task Products_from_open_pet_food_facts_stay_out_of_the_catalog()
    {
        var client = api.ClientFor($"supplies-catalog-{Guid.NewGuid():N}");
        var barcode = NewBarcode();

        await client.CreateSupplyAsync(Supply("Sterilised 37") with { Barcode = barcode, DataSource = SupplyDataSource.OpenPetFoodFacts });

        await api.ChangeDatabaseAsync(async db =>
            Assert.False(await db.Products.AnyAsync(p => p.Barcode == "0" + barcode, Ct)));
    }

    [Fact]
    public async Task Someone_elses_supplies_are_not_found()
    {
        var owner = api.ClientFor($"supplies-idor-owner-{Guid.NewGuid():N}");
        var stranger = api.ClientFor($"supplies-idor-stranger-{Guid.NewGuid():N}");
        var item = await owner.CreateSupplyAsync(Supply("Food", stock: 1000));
        var change = await owner.PostAsJsonAsync($"/api/v1/supplies/{item.Id}/stock-events",
            new StockEventRequest(StockEventKind.Purchase, 1000, null), Json, Ct);
        var entry = (await change.Content.ReadFromJsonAsync<StockChangeResponse>(Json, Ct))!.Event;

        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/v1/supplies/{item.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.PutAsJsonAsync($"/api/v1/supplies/{item.Id}", Supply("Mine"), Json, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/v1/supplies/{item.Id}/stock-events", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.PostAsJsonAsync($"/api/v1/supplies/{item.Id}/stock-events",
            new StockEventRequest(StockEventKind.Purchase, 1000, null), Json, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.DeleteAsync($"/api/v1/supplies/{item.Id}/stock-events/{entry.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.DeleteAsync($"/api/v1/supplies/{item.Id}", Ct)).StatusCode);
        Assert.Empty((await stranger.GetFromJsonAsync<List<SupplyResponse>>("/api/v1/supplies", Json, Ct))!);
        Assert.Equal(2000m, (await owner.GetSupplyAsync(item.Id)).Forecast.Remaining);
    }
}
