using System.Net.Http.Json;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Today;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class TodayTests(ApiFactory api)
{
    [Fact]
    public async Task Today_lists_overdue_and_coming_care_of_active_pets()
    {
        var client = api.ClientFor($"today-{Guid.NewGuid():N}");
        var day = new DateOnly(2026, 6, 15);
        var murka = await client.CreatePetAsync("Murka");
        var rex = await client.CreatePetAsync("Rex", Species.Dog);
        var oldCat = await client.CreatePetAsync("Old cat");
        await client.PutAsJsonAsync($"/api/v1/pets/{oldCat.Id}", Pet("Old cat") with { Status = PetStatus.Archived }, Ct);

        await client.CreatePlanAsync(murka.Id, Plan("Deworming", day.AddDays(-3), 3, IntervalUnit.Month, CareKind.Deworming));
        await client.CreatePlanAsync(rex.Id, Plan("Bravecto", day.AddDays(5), 12, IntervalUnit.Week, CareKind.FleaTick));
        await client.CreatePlanAsync(rex.Id, Plan("Rabies", day.AddDays(45), 1, IntervalUnit.Year, CareKind.Vaccination));
        await client.CreatePlanAsync(oldCat.Id, Plan("Archived pet", day, 1, IntervalUnit.Month));
        await client.CreatePlanAsync(murka.Id, Plan("Paused", day, 1, IntervalUnit.Month) with { Active = false });

        var today = await client.GetFromJsonAsync<TodayResponse>("/api/v1/today?date=2026-06-15", Ct);

        Assert.Equal(day, today!.Date);
        Assert.Collection(today.Care,
            item =>
            {
                Assert.Equal(("Murka", "Deworming", CareStatus.Overdue, -3), (item.PetName, item.Title, item.Status, item.DaysLeft));
                Assert.Equal(murka.Coat, item.PetCoat);
            },
            item => Assert.Equal(("Rex", "Bravecto", CareStatus.DueSoon, 5), (item.PetName, item.Title, item.Status, item.DaysLeft)));
    }

    [Fact]
    public async Task Today_is_the_date_in_the_household_time_zone()
    {
        var client = api.ClientFor($"timezone-{Guid.NewGuid():N}");
        // UTC+14: the first place where a new day starts.
        await client.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest(null, null, "Pacific/Kiritimati"), Ct);

        var today = await client.GetFromJsonAsync<TodayResponse>("/api/v1/today", Ct);

        Assert.Equal(DateOnly.FromDateTime(DateTime.UtcNow.AddHours(14)), today!.Date);
        Assert.Empty(today.Care);
    }
}
