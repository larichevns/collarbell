using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Pets;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class CareTests(ApiFactory api)
{
    [Fact]
    public async Task Presets_suit_the_species()
    {
        var client = api.ClientFor($"presets-{Guid.NewGuid():N}");

        var forCats = await client.GetFromJsonAsync<List<CarePresetResponse>>("/api/v1/care-plan-presets?species=Cat", Ct);
        var forDogs = await client.GetFromJsonAsync<List<CarePresetResponse>>("/api/v1/care-plan-presets?species=Dog", Ct);

        Assert.Contains(forCats!, p => p.Code == "cat-rabies");
        Assert.DoesNotContain(forCats!, p => p.DogOnly || p.Species == Species.Dog);
        Assert.Contains(forDogs!, p => p.Code == "dog-advantix" && p.DogOnly);
    }

    [Fact]
    public async Task A_dog_only_product_cannot_be_planned_for_a_cat()
    {
        var client = api.ClientFor($"permethrin-{Guid.NewGuid():N}");
        var cat = await client.CreatePetAsync("Murka");

        var response = await client.PostAsJsonAsync($"/api/v1/pets/{cat.Id}/care-plans",
            Plan("K9 Advantix", Today, 1, IntervalUnit.Month, CareKind.FleaTick) with { PresetCode = "dog-advantix" }, Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("permethrin", await response.Content.ReadAsStringAsync(Ct), StringComparison.Ordinal);
    }

    [Fact]
    public async Task Plans_come_with_their_status_soonest_first()
    {
        var client = api.ClientFor($"status-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Later", Today.AddDays(30), 1, IntervalUnit.Year));
        await client.CreatePlanAsync(pet.Id, Plan("Late", Today.AddDays(-1), 3, IntervalUnit.Month));
        await client.CreatePlanAsync(pet.Id, Plan("Soon", Today.AddDays(10), 1, IntervalUnit.Month));

        var plans = await client.GetFromJsonAsync<List<CarePlanResponse>>($"/api/v1/pets/{pet.Id}/care-plans", Ct);

        Assert.Equal(new[] { "Late", "Soon", "Later" }, plans!.Select(p => p.Title));
        Assert.Equal(new[] { CareStatus.Overdue, CareStatus.DueSoon, CareStatus.Upcoming }, plans!.Select(p => p.Status));
        Assert.Equal(new[] { -1, 10, 30 }, plans!.Select(p => p.DaysLeft));
    }

    [Fact]
    public async Task Done_writes_a_record_and_moves_the_plan()
    {
        var client = api.ClientFor($"done-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today, 1, IntervalUnit.Year, CareKind.Vaccination) with
        {
            Targets = [VaccineTarget.Rabies],
            DefaultProduct = "Nobivac Rabies",
        });
        var givenOn = Today.AddDays(-2);

        var response = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete",
            Done(givenOn) with { Product = "Nobivac Rabies", BatchNumber = "A123", ValidFrom = givenOn.AddDays(21) }, Ct);
        var done = (await response.Content.ReadFromJsonAsync<CompleteCarePlanResponse>(Ct))!;

        Assert.Equal(givenOn.AddYears(1), done.Plan.NextDueOn);
        Assert.Equal(givenOn, done.Plan.LastDoneOn);
        Assert.Equal(CareStatus.Upcoming, done.Plan.Status);
        Assert.Equal(plan.Id, done.Record.PlanId);
        Assert.Equal(CareKind.Vaccination, done.Record.Kind);
        Assert.Equal("Nobivac Rabies", done.Record.Product);
        Assert.Equal("A123", done.Record.BatchNumber);
        Assert.Equal(givenOn.AddDays(21), done.Record.ValidFrom);
        Assert.Equal(new[] { VaccineTarget.Rabies }, done.Record.Targets);
    }

    [Fact]
    public async Task A_cleared_product_stays_empty()
    {
        var client = api.ClientFor($"noproduct-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming) with
        {
            DefaultProduct = "Milbemax",
        });

        var response = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", Done(Today), Ct);

        Assert.Null((await response.Content.ReadFromJsonAsync<CompleteCarePlanResponse>(Ct))!.Record.Product);
    }

    [Fact]
    public async Task Retrying_done_with_the_same_request_id_marks_it_done_once()
    {
        var client = api.ClientFor($"retry-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming));
        var request = Done(Today) with { RequestId = Guid.NewGuid() };

        var first = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", request, Ct);
        var retry = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", request, Ct);
        var firstDone = (await first.Content.ReadFromJsonAsync<CompleteCarePlanResponse>(Ct))!;
        var retryDone = (await retry.Content.ReadFromJsonAsync<CompleteCarePlanResponse>(Ct))!;
        var records = await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct);

        Assert.Equal(HttpStatusCode.OK, retry.StatusCode);
        Assert.Equal(firstDone.Record.Id, retryDone.Record.Id);
        Assert.Equal(Today.AddMonths(3), retryDone.Plan.NextDueOn); // moved once, not twice
        Assert.Single(records!);
    }

    [Fact]
    public async Task A_plan_is_done_once_per_day_even_from_a_second_screen()
    {
        var client = api.ClientFor($"twice-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming));

        // Two different request ids: a second tap after an error opens a new screen with a new id.
        await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", Done(Today) with { RequestId = Guid.NewGuid() }, Ct);
        var again = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", Done(Today) with { RequestId = Guid.NewGuid() }, Ct);

        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Equal(Today.AddMonths(3), (await again.Content.ReadFromJsonAsync<CompleteCarePlanResponse>(Ct))!.Plan.NextDueOn);
        Assert.Single((await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct))!);
    }

    [Fact]
    public async Task Retrying_a_new_plan_with_the_same_request_id_adds_it_once()
    {
        var client = api.ClientFor($"retryplan-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var request = Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming) with { RequestId = Guid.NewGuid() };

        var first = await client.CreatePlanAsync(pet.Id, request);
        var retry = await client.CreatePlanAsync(pet.Id, request);

        Assert.Equal(first.Id, retry.Id);
        Assert.Single((await client.GetFromJsonAsync<List<CarePlanResponse>>($"/api/v1/pets/{pet.Id}/care-plans", Ct))!);
    }

    [Fact]
    public async Task A_preset_plan_stays_editable_after_the_species_is_corrected()
    {
        var client = api.ClientFor($"species-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka", Species.Dog); // added as a dog by mistake
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming) with
        {
            PresetCode = "dog-deworm",
        });
        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}", Pet("Murka", Species.Cat), Ct);

        var paused = await client.PutAsJsonAsync($"/api/v1/care-plans/{plan.Id}",
            Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming) with { PresetCode = "dog-deworm", Active = false }, Ct);
        var switched = await client.PutAsJsonAsync($"/api/v1/care-plans/{plan.Id}",
            Plan("Advantix", Today, 1, IntervalUnit.Month, CareKind.FleaTick) with { PresetCode = "dog-advantix" }, Ct);

        Assert.Equal(HttpStatusCode.OK, paused.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, switched.StatusCode); // a new dog-only preset is still refused
    }

    [Fact]
    public async Task Retrying_a_new_record_with_the_same_request_id_adds_it_once()
    {
        var client = api.ClientFor($"retryrec-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var request = Record("Rabies", CareKind.Vaccination, Today) with { RequestId = Guid.NewGuid() };

        var first = await client.CreateRecordAsync(pet.Id, request);
        var retry = await client.CreateRecordAsync(pet.Id, request);

        Assert.Equal(first.Id, retry.Id);
        Assert.Single((await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct))!);
    }

    [Fact]
    public async Task Attaching_the_same_file_again_just_succeeds()
    {
        var client = api.ClientFor($"reattach-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var record = await client.CreateRecordAsync(pet.Id, Record("Rabies", CareKind.Vaccination, Today));
        var sticker = await client.UploadPhotoAsync();
        var request = new AddRecordFilesRequest([sticker.Id]);

        await client.PostAsJsonAsync($"/api/v1/care-records/{record.Id}/files", request, Ct);
        var retry = await client.PostAsJsonAsync($"/api/v1/care-records/{record.Id}/files", request, Ct);

        Assert.Equal(HttpStatusCode.OK, retry.StatusCode);
        Assert.Single((await retry.Content.ReadFromJsonAsync<CareRecordResponse>(Ct))!.Files);
    }

    [Fact]
    public async Task A_vaccine_valid_for_three_years_sets_the_next_date()
    {
        var client = api.ClientFor($"valid-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Rex", Species.Dog);
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today, 1, IntervalUnit.Year, CareKind.Vaccination));
        var validUntil = Today.AddYears(3).AddDays(-1);

        var response = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete",
            Done(Today) with { ValidUntil = validUntil }, Ct);

        Assert.Equal(validUntil, (await response.Content.ReadFromJsonAsync<CompleteCarePlanResponse>(Ct))!.Plan.NextDueOn);
    }

    [Fact]
    public async Task A_one_off_plan_finishes_and_goes_last()
    {
        var client = api.ClientFor($"oneoff-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Rex", Species.Dog);
        var trip = await client.CreatePlanAsync(pet.Id, Plan("Tapeworm before Finland", Today, kind: CareKind.Echinococcus));
        await client.CreatePlanAsync(pet.Id, Plan("Check-up", Today.AddDays(200), 1, IntervalUnit.Year, CareKind.VetExam));

        await client.PostAsJsonAsync($"/api/v1/care-plans/{trip.Id}/complete",
            Done(Today) with { PerformedTime = new TimeOnly(9, 30) }, Ct);
        var plans = await client.GetFromJsonAsync<List<CarePlanResponse>>($"/api/v1/pets/{pet.Id}/care-plans", Ct);
        var records = await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct);

        Assert.Equal(new[] { "Check-up", "Tapeworm before Finland" }, plans!.Select(p => p.Title));
        Assert.Equal(CareStatus.Inactive, plans![1].Status);
        Assert.Equal(new TimeOnly(9, 30), Assert.Single(records!).PerformedTime);
    }

    [Theory]
    [InlineData(3, null, "intervalValue")]
    [InlineData(0, IntervalUnit.Day, "intervalValue")]
    [InlineData(11, IntervalUnit.Year, "intervalValue")]
    public async Task Plan_intervals_are_checked(int? every, IntervalUnit? unit, string field)
    {
        var client = api.ClientFor($"interval-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        var response = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/care-plans", Plan("Plan", Today, every, unit), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains($"\"{field}\"", await response.Content.ReadAsStringAsync(Ct), StringComparison.Ordinal);
    }

    [Fact]
    public async Task Plan_and_record_fields_are_checked()
    {
        var client = api.ClientFor($"fields-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        var plan = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/care-plans", Plan(" ", Today, 1, IntervalUnit.Month, CareKind.Deworming) with
        {
            Targets = [VaccineTarget.Rabies],
            RemindOffsetsDays = [1, 1],
        }, Ct);
        var record = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/care-records", Record("Shot", CareKind.Vaccination, Today.AddDays(3)) with
        {
            ValidUntil = Today.AddDays(1),
            WeightKg = 0,
        }, Ct);

        var planBody = await plan.Content.ReadAsStringAsync(Ct);
        var recordBody = await record.Content.ReadAsStringAsync(Ct);
        foreach (var field in new[] { "title", "targets", "remindOffsetsDays" })
        {
            Assert.Contains($"\"{field}\"", planBody, StringComparison.Ordinal);
        }

        foreach (var field in new[] { "performedOn", "validUntil", "weightKg" })
        {
            Assert.Contains($"\"{field}\"", recordBody, StringComparison.Ordinal);
        }
    }

    [Fact]
    public async Task Deleting_a_plan_keeps_its_history()
    {
        var client = api.ClientFor($"history-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming));
        await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", Done(Today), Ct);

        var deleted = await client.DeleteAsync($"/api/v1/care-plans/{plan.Id}", Ct);
        var records = await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct);

        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
        Assert.Null(Assert.Single(records!).PlanId);
    }

    [Fact]
    public async Task Records_fill_the_passport_sections_oldest_first()
    {
        var client = api.ClientFor($"sections-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Rex", Species.Dog);
        await client.CreateRecordAsync(pet.Id, Record("Rabies + DHPP", CareKind.Vaccination, Today.AddYears(-1)) with
        {
            Targets = [VaccineTarget.Rabies, VaccineTarget.Cdv],
        });
        await client.CreateRecordAsync(pet.Id, Record("Rabies", CareKind.Vaccination, Today.AddYears(-2)) with
        {
            Targets = [VaccineTarget.Rabies],
        });
        await client.CreateRecordAsync(pet.Id, Record("DHPP", CareKind.Vaccination, Today.AddMonths(-3)) with
        {
            Targets = [VaccineTarget.Cdv, VaccineTarget.Cpv2],
        });
        await client.CreateRecordAsync(pet.Id, Record("Milbemax", CareKind.Deworming, Today.AddMonths(-1)));
        await client.CreateRecordAsync(pet.Id, Record("Titer", CareKind.RabiesTiter, Today.AddMonths(-6)) with
        {
            Details = new CareRecordDetailsDto("Friedrich-Loeffler-Institut", "R-42", 1.2m, null),
        });
        await client.CreateRecordAsync(pet.Id, Record("Check-up", CareKind.VetExam, Today.AddDays(-5)) with
        {
            Details = new CareRecordDetailsDto(null, null, null, FitForTravel: true),
        });
        await client.CreateRecordAsync(pet.Id, Record("Teeth cleaning", CareKind.Dental, Today.AddDays(-4)));

        var passport = await client.GetFromJsonAsync<PassportRecordsResponse>($"/api/v1/pets/{pet.Id}/passport/records", Ct);

        Assert.Equal(new[] { "Rabies", "Rabies + DHPP" }, passport!.Rabies.Select(r => r.Title));
        Assert.Equal(new[] { "DHPP" }, passport.OtherVaccinations.Select(r => r.Title));
        Assert.Equal(new[] { "Milbemax" }, passport.Treatments.Select(r => r.Title));
        Assert.Equal(1.2m, Assert.Single(passport.RabiesTiters).Details?.TiterIuPerMl);
        Assert.True(Assert.Single(passport.Examinations).Details?.FitForTravel);
        Assert.Empty(passport.Echinococcus);
        Assert.DoesNotContain("Teeth cleaning", new[] { passport.Rabies, passport.RabiesTiters, passport.Echinococcus,
            passport.Treatments, passport.OtherVaccinations, passport.Examinations }.SelectMany(s => s).Select(r => r.Title));
    }

    [Fact]
    public async Task Record_photos_are_added_and_removed_one_at_a_time()
    {
        var client = api.ClientFor($"stickers-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var record = await client.CreateRecordAsync(pet.Id, Record("Rabies", CareKind.Vaccination, Today));
        var sticker = await client.UploadPhotoAsync();
        var conclusion = await client.UploadFileAsync(Pdf());

        await client.PostAsJsonAsync($"/api/v1/care-records/{record.Id}/files", new AddRecordFilesRequest([sticker.Id]), Ct);
        var added = await client.PostAsJsonAsync($"/api/v1/care-records/{record.Id}/files", new AddRecordFilesRequest([conclusion.Id]), Ct);
        Assert.Equal(new[] { sticker.Id, conclusion.Id },
            (await added.Content.ReadFromJsonAsync<CareRecordResponse>(Ct))!.Files.Select(f => f.Id));

        await client.DeleteAsync($"/api/v1/care-records/{record.Id}/files/{sticker.Id}", Ct);
        await api.RunStorageCleanupAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(sticker.Url, Ct)).StatusCode);
        var remaining = await client.GetFromJsonAsync<CareRecordResponse>($"/api/v1/care-records/{record.Id}", Ct);
        Assert.Equal(conclusion.Id, Assert.Single(remaining!.Files).Id);

        await client.DeleteAsync($"/api/v1/care-records/{record.Id}", Ct);
        await api.RunStorageCleanupAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(conclusion.Url, Ct)).StatusCode);
    }

    [Fact]
    public async Task Deleting_a_pet_deletes_its_care_and_record_files()
    {
        var client = api.ClientFor($"petcare-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming));
        var record = await client.CreateRecordAsync(pet.Id, Record("Rabies", CareKind.Vaccination, Today));
        var sticker = await client.UploadPhotoAsync();
        await client.PostAsJsonAsync($"/api/v1/care-records/{record.Id}/files", new AddRecordFilesRequest([sticker.Id]), Ct);

        await client.DeleteAsync($"/api/v1/pets/{pet.Id}", Ct);
        await api.RunStorageCleanupAsync();

        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/care-plans/{plan.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/care-records/{record.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(sticker.Url, Ct)).StatusCode);
    }

    [Fact]
    public async Task Another_household_cannot_see_or_change_care()
    {
        var anna = api.ClientFor($"anna-{Guid.NewGuid():N}");
        var oleg = api.ClientFor($"oleg-{Guid.NewGuid():N}");
        var murka = await anna.CreatePetAsync("Murka");
        var plan = await anna.CreatePlanAsync(murka.Id, Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming));
        var record = await anna.CreateRecordAsync(murka.Id, Record("Rabies", CareKind.Vaccination, Today));
        var olegsUpload = await oleg.UploadPhotoAsync();
        var planRequest = Plan("Mine", Today, 1, IntervalUnit.Month);
        var recordRequest = Record("Mine", CareKind.Other, Today);

        foreach (var response in new[]
        {
            await oleg.GetAsync($"/api/v1/pets/{murka.Id}/care-plans", Ct),
            await oleg.PostAsJsonAsync($"/api/v1/pets/{murka.Id}/care-plans", planRequest, Ct),
            await oleg.GetAsync($"/api/v1/care-plans/{plan.Id}", Ct),
            await oleg.PutAsJsonAsync($"/api/v1/care-plans/{plan.Id}", planRequest, Ct),
            await oleg.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", Done(Today), Ct),
            await oleg.DeleteAsync($"/api/v1/care-plans/{plan.Id}", Ct),
            await oleg.GetAsync($"/api/v1/pets/{murka.Id}/care-records", Ct),
            await oleg.PostAsJsonAsync($"/api/v1/pets/{murka.Id}/care-records", recordRequest, Ct),
            await oleg.GetAsync($"/api/v1/care-records/{record.Id}", Ct),
            await oleg.PutAsJsonAsync($"/api/v1/care-records/{record.Id}", recordRequest, Ct),
            await oleg.PostAsJsonAsync($"/api/v1/care-records/{record.Id}/files", new AddRecordFilesRequest([olegsUpload.Id]), Ct),
            await oleg.DeleteAsync($"/api/v1/care-records/{record.Id}", Ct),
            await oleg.GetAsync($"/api/v1/pets/{murka.Id}/passport/records", Ct),
        })
        {
            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }

        Assert.Single((await anna.GetFromJsonAsync<List<CarePlanResponse>>($"/api/v1/pets/{murka.Id}/care-plans", Ct))!);
        Assert.Single((await anna.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{murka.Id}/care-records", Ct))!);
    }
}
