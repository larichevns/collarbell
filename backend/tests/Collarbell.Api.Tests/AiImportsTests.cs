using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Storage;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class AiImportsTests : IDisposable
{
    private const string PassportPageAnswer = """
        {
          "records": [
            { "kind": "Vaccination", "title": "Rabies vaccination",
              "performedOn": { "raw": "12/03/2025", "iso": "2025-03-12", "order": "DayMonthYear" },
              "performedTime": null, "product": "Nobivac Rabies", "manufacturer": "MSD", "batchNumber": "A123B45",
              "validFrom": { "raw": "02/04/2025", "iso": "2025-04-02", "order": "DayMonthYear" },
              "validUntil": { "raw": "11/03/2028", "iso": "2028-03-11", "order": "DayMonthYear" },
              "targets": ["Rabies"], "veterinarian": "Dr. K. Weber", "clinic": null,
              "evidence": "Nobivac Rabies A123B45 12/03/2025", "page": 1 },
            { "kind": "Deworming", "title": "Deworming",
              "performedOn": { "raw": "03/04/2025", "iso": "2025-04-03", "order": "DayMonthYear" },
              "performedTime": null, "product": "Milbemax", "manufacturer": null, "batchNumber": null,
              "validFrom": null, "validUntil": null, "targets": [], "veterinarian": null, "clinic": null,
              "evidence": "Milbemax 03/04/2025", "page": 2 }
          ],
          "identifiers": [
            { "type": "IsoChip", "code": "276 0981 0012 3456", "appliedOn": null, "location": "Left side of neck",
              "evidence": "276098100123456", "page": 1 }
          ],
          "passport": { "passportNumber": "DE 0123 4567", "issuingCountry": "DE", "issuedOn": null, "evidence": "DE01234567", "page": 1 }
        }
        """;

    private readonly ApiFactory _api;

    public AiImportsTests(ApiFactory api)
    {
        _api = api;
        _api.Ai.Reset();
    }

    public void Dispose() => _api.Ai.Reset();

    [Fact]
    public async Task A_passport_page_becomes_a_draft_and_the_checked_entries_are_saved()
    {
        var client = _api.ClientFor($"scan-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var rabiesPlan = await client.CreatePlanAsync(pet.Id,
            Plan("Rabies", Today, 1, IntervalUnit.Year, CareKind.Vaccination) with { Targets = [VaccineTarget.Rabies] });
        var page1 = await client.UploadPhotoAsync();
        var page2 = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => PassportPageAnswer;

        var import = await StartAsync(client, pet.Id, [page1.Id, page2.Id]);
        var ready = await WaitUntilDoneAsync(client, import.Id);

        Assert.Equal(AiImportStatus.Ready, ready.Status);
        Assert.Equal("fake-a", ready.Model);
        Assert.Equal(new[] { page1.Id, page2.Id }, ready.Pages.Select(p => p.Id));
        var draft = ready.Draft!;
        Assert.Equal(new DateOnly(2025, 3, 12), draft.Records[0].PerformedOn);
        Assert.Contains(new DraftWarning("performedOn", DraftIssue.Ambiguous), draft.Records[1].Warnings); // 03/04
        Assert.Equal(rabiesPlan.Id, draft.Records[0].PlanId); // the rabies shot is a "Done" of the rabies plan
        Assert.Null(draft.Records[1].PlanId);                 // no deworming plan
        Assert.Equal("276098100123456", Assert.Single(draft.Identifiers).Code);
        Assert.Equal("DE01234567", draft.Passport!.PassportNumber);

        // The user keeps the rabies record (as is) and the chip, and fills in the passport number.
        var rabies = draft.Records[0];
        var apply = new ApplyImportRequest(
            [new ImportedRecordRequest(Record(rabies.Title!, rabies.Kind, rabies.PerformedOn!.Value) with
            {
                Product = rabies.Product, BatchNumber = rabies.BatchNumber, ValidFrom = rabies.ValidFrom,
                ValidUntil = rabies.ValidUntil, Targets = rabies.Targets,
            }, rabies.PlanId)],
            [new PetIdentifierRequest(IdentifierType.IsoChip, "276098100123456", null, null, "Left side of neck")],
            new ApplyPassportRequest("DE01234567", "DE", null),
            KeepPhotos: true);
        var applied = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", apply, Ct);
        Assert.Equal(HttpStatusCode.OK, applied.StatusCode);
        var result = (await applied.Content.ReadFromJsonAsync<ApplyImportResponse>(Ct))!;

        var records = await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct);
        var saved = Assert.Single(records!);
        Assert.Equal(RecordSource.AiScan, saved.Source);
        Assert.Equal("A123B45", saved.BatchNumber);
        Assert.Equal(rabiesPlan.Id, saved.PlanId);
        Assert.Equal(1, result.PlansMoved);
        var planNow = await client.GetFromJsonAsync<CarePlanResponse>($"/api/v1/care-plans/{rabiesPlan.Id}", Ct);
        Assert.Equal(new DateOnly(2028, 3, 11), planNow!.NextDueOn); // valid until, as "Done" would set it
        Assert.Equal(1, result.IdentifiersAdded);
        Assert.True(result.PassportUpdated);
        var petNow = await client.GetFromJsonAsync<PetResponse>($"/api/v1/pets/{pet.Id}", Ct);
        Assert.Equal("276098100123456", Assert.Single(petNow!.Identifiers).Code);
        var scans = await client.GetFromJsonAsync<List<DocumentResponse>>($"/api/v1/pets/{pet.Id}/documents?type=PassportPage", Ct);
        Assert.Equal(new[] { page1.Id, page2.Id }, Assert.Single(scans!).Pages.Select(p => p.Id));

        // Applying again (the first response got lost) saves nothing twice.
        var again = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", apply, Ct);
        Assert.Equal(result.RecordIds, (await again.Content.ReadFromJsonAsync<ApplyImportResponse>(Ct))!.RecordIds);
        Assert.Single((await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct))!);
    }

    [Fact]
    public async Task A_busy_model_hands_over_to_the_next_one()
    {
        var client = _api.ClientFor($"busy-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        _api.Ai.Answer = model => model == "fake-a"
            ? throw new HttpRequestException("high demand", null, HttpStatusCode.ServiceUnavailable)
            : PassportPageAnswer;

        var import = await StartAsync(client, pet.Id, [page.Id]);
        var ready = await WaitUntilDoneAsync(client, import.Id);

        Assert.Equal(AiImportStatus.Ready, ready.Status);
        Assert.Equal("fake-b", ready.Model);
        Assert.Equal(new[] { "fake-a", "fake-b" }, _api.Ai.Asked);
        var status = await client.GetFromJsonAsync<AiStatusResponse>("/api/v1/ai/status", Ct);
        Assert.Equal(2, status!.ThisMonth.Requests); // the failed attempt counts too
    }

    [Fact]
    public async Task A_model_that_hangs_is_given_up_on()
    {
        var client = _api.ClientFor($"hangs-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        _api.Ai.Hangs = model => model == "fake-a";
        _api.Ai.Answer = _ => PassportPageAnswer;

        var import = await StartAsync(client, pet.Id, [page.Id]);
        var ready = await WaitUntilDoneAsync(client, import.Id);

        Assert.Equal(AiImportStatus.Ready, ready.Status);
        Assert.Equal("fake-b", ready.Model);
    }

    [Fact]
    public async Task Saving_checks_every_entry_like_typing_it_in()
    {
        var client = _api.ClientFor($"applycheck-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => PassportPageAnswer;
        var import = await StartAsync(client, pet.Id, [page.Id]);
        await WaitUntilDoneAsync(client, import.Id);
        var ok = Record("Rabies vaccination", CareKind.Vaccination, new DateOnly(2025, 3, 12));
        var stranger = _api.ClientFor($"stranger-{Guid.NewGuid():N}");
        var strangersPet = await stranger.CreatePetAsync("Rex", Species.Dog);
        var strangersPlan = await stranger.CreatePlanAsync(strangersPet.Id, Plan("Rabies", Today));

        var response = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", new ApplyImportRequest(
            [
                new ImportedRecordRequest(ok, strangersPlan.Id),
                new ImportedRecordRequest(ok with { Title = " " }, null),
                new ImportedRecordRequest(ok with { PerformedOn = Today.AddDays(5) }, null),
            ],
            [new PetIdentifierRequest(IdentifierType.IsoChip, "12345", null, null, null)],
            null,
            KeepPhotos: true), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<HttpValidationProblemDetails>(Ct);
        Assert.Equal(
            new[] { "identifiers[0].code", "records[0].planId", "records[1].record.title", "records[2].record.performedOn" },
            problem!.Errors.Keys.Order());
        Assert.Empty((await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct))!);
    }

    [Fact]
    public async Task An_old_entry_from_the_passport_doesnt_move_a_plan_back()
    {
        var client = _api.ClientFor($"oldentry-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today, 3, IntervalUnit.Month, CareKind.Deworming));
        (await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", Done(Today), Ct)).EnsureSuccessStatusCode();
        var page = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => PassportPageAnswer;
        var import = await StartAsync(client, pet.Id, [page.Id]);
        var deworming = (await WaitUntilDoneAsync(client, import.Id)).Draft!.Records[1]; // 03/04/2025
        Assert.Null(deworming.PlanId); // older than the last "Done": not suggested

        // Linked by hand anyway: kept as the plan's history, the plan stays as it is.
        var applied = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", new ApplyImportRequest(
            [new ImportedRecordRequest(Record(deworming.Title!, deworming.Kind, deworming.PerformedOn!.Value), plan.Id)],
            null, null, KeepPhotos: false), Ct);

        Assert.Equal(0, (await applied.Content.ReadFromJsonAsync<ApplyImportResponse>(Ct))!.PlansMoved);
        var planNow = await client.GetFromJsonAsync<CarePlanResponse>($"/api/v1/care-plans/{plan.Id}", Ct);
        Assert.Equal(Today.AddMonths(3), planNow!.NextDueOn); // still from today's "Done"
        Assert.Equal(Today, planNow.LastDoneOn);
    }

    [Fact]
    public async Task An_old_entry_neither_closes_nor_pulls_back_a_plan_never_done()
    {
        // A one-off treatment before a trip, and a deworming every 3 months: both made today, next ones ahead.
        var client = _api.ClientFor($"neverdone-{Guid.NewGuid():N}");
        var murka = await client.CreatePetAsync("Murka");
        var rex = await client.CreatePetAsync("Rex", Species.Dog);
        var trip = await client.CreatePlanAsync(murka.Id, Plan("Before the trip", Today.AddDays(20), kind: CareKind.Deworming));
        var regular = await client.CreatePlanAsync(rex.Id, Plan("Deworming", Today.AddDays(30), 3, IntervalUnit.Month, CareKind.Deworming));
        _api.Ai.Answer = _ => PassportPageAnswer; // a deworming on 03/04/2025

        foreach (var (pet, plan) in new[] { (murka, trip), (rex, regular) })
        {
            var import = await StartAsync(client, pet.Id, [(await client.UploadPhotoAsync()).Id]);
            var deworming = (await WaitUntilDoneAsync(client, import.Id)).Draft!.Records[1];
            Assert.Null(deworming.PlanId);

            var applied = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", new ApplyImportRequest(
                [new ImportedRecordRequest(Record(deworming.Title!, deworming.Kind, deworming.PerformedOn!.Value), plan.Id)],
                null, null, KeepPhotos: false), Ct);

            Assert.Equal(0, (await applied.Content.ReadFromJsonAsync<ApplyImportResponse>(Ct))!.PlansMoved);
            var planNow = (await client.GetFromJsonAsync<CarePlanResponse>($"/api/v1/care-plans/{plan.Id}", Ct))!;
            Assert.Equal(plan.NextDueOn, planNow.NextDueOn);
            Assert.NotEqual(CareStatus.Inactive, planNow.Status);
        }
    }

    [Fact]
    public async Task A_record_can_only_be_a_done_of_a_plan_of_its_kind()
    {
        var client = _api.ClientFor($"wrongplan-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var rabies = await client.CreatePlanAsync(pet.Id,
            Plan("Rabies", Today.AddDays(100), 1, IntervalUnit.Year, CareKind.Vaccination) with { Targets = [VaccineTarget.Rabies] });
        var import = await ReadyImportAsync(client, pet.Id);
        var grooming = Record("Grooming", CareKind.Grooming, Today);
        var otherVaccine = Record("Distemper", CareKind.Vaccination, Today) with { Targets = [VaccineTarget.Cdv] };

        var response = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", new ApplyImportRequest(
            [new ImportedRecordRequest(grooming, rabies.Id), new ImportedRecordRequest(otherVaccine, rabies.Id)],
            null, null, KeepPhotos: false), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<HttpValidationProblemDetails>(Ct);
        Assert.Equal(new[] { "records[0].planId", "records[1].planId" }, problem!.Errors.Keys.Order());
        Assert.Equal(Today.AddDays(100), (await client.GetFromJsonAsync<CarePlanResponse>($"/api/v1/care-plans/{rabies.Id}", Ct))!.NextDueOn);
    }

    [Fact]
    public async Task Saving_twice_at_once_saves_once()
    {
        var client = _api.ClientFor($"doubletap-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var import = await ReadyImportAsync(client, pet.Id);
        var apply = new ApplyImportRequest(
            [new ImportedRecordRequest(Record("Rabies vaccination", CareKind.Vaccination, new DateOnly(2025, 3, 12)), null)],
            [new PetIdentifierRequest(IdentifierType.IsoChip, "276098100123456", null, null, null)],
            null, KeepPhotos: true);

        var responses = await Task.WhenAll(Enumerable.Range(0, 6)
            .Select(_ => client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", apply, Ct)));

        Assert.All(responses, r => Assert.Equal(HttpStatusCode.OK, r.StatusCode));
        var results = await Task.WhenAll(responses.Select(r => r.Content.ReadFromJsonAsync<ApplyImportResponse>(Ct)));
        Assert.Single(results.Select(r => r!.RecordIds.Single()).Distinct());
        Assert.Single((await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{pet.Id}/care-records", Ct))!);
        Assert.Single((await client.GetFromJsonAsync<PetResponse>($"/api/v1/pets/{pet.Id}", Ct))!.Identifiers);
        Assert.Single((await client.GetFromJsonAsync<List<DocumentResponse>>($"/api/v1/pets/{pet.Id}/documents?type=PassportPage", Ct))!);
    }

    [Fact]
    public async Task Starting_the_same_scan_twice_at_once_starts_it_once()
    {
        var client = _api.ClientFor($"doublestart-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        var request = new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, [page.Id], Guid.NewGuid());

        var responses = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => client.PostAsJsonAsync("/api/v1/ai-imports", request, Ct)));

        Assert.All(responses, r => Assert.Equal(HttpStatusCode.Accepted, r.StatusCode));
        var ids = (await Task.WhenAll(responses.Select(r => r.Content.ReadFromJsonAsync<AiImportResponse>(Ct)))).Select(i => i!.Id).Distinct();
        await WaitUntilDoneAsync(client, Assert.Single(ids));
    }

    [Fact]
    public async Task A_scan_thrown_away_while_being_read_stays_thrown_away()
    {
        var client = _api.ClientFor($"discardbusy-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        _api.Ai.Hangs = model => model == "fake-a"; // two seconds before fake-b answers
        _api.Ai.Answer = _ => PassportPageAnswer;
        var import = await StartAsync(client, pet.Id, [(await client.UploadPhotoAsync()).Id]);
        while ((await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{import.Id}", Ct))!.Status == AiImportStatus.Queued)
        {
            await Task.Delay(50, Ct);
        }

        await client.DeleteAsync($"/api/v1/ai-imports/{import.Id}", Ct);
        await Task.Delay(TimeSpan.FromSeconds(3), Ct);

        Assert.Equal(AiImportStatus.Discarded, (await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{import.Id}", Ct))!.Status);
        Assert.Empty((await client.GetFromJsonAsync<List<AiImportResponse>>($"/api/v1/pets/{pet.Id}/ai-imports", Ct))!);
    }

    [Fact]
    public async Task Photos_gone_from_storage_fail_the_scan_as_missing_photos()
    {
        var client = _api.ClientFor($"gone-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        await using (var scope = _api.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var key = await db.StoredFiles.Where(f => f.Id == page.Id).Select(f => f.StorageKey).SingleAsync(Ct);
            await scope.ServiceProvider.GetRequiredService<ObjectStorage>().DeleteAsync(key, Ct);
        }

        var done = await WaitUntilDoneAsync(client, (await StartAsync(client, pet.Id, [page.Id])).Id);

        Assert.Equal(AiImportStatus.Failed, done.Status);
        Assert.Equal(AiImportError.PhotosMissing, done.Error);
        Assert.Empty(_api.Ai.Asked);
    }

    [Fact]
    public async Task Photos_of_a_scan_waiting_to_be_checked_outlive_the_one_day_cleanup()
    {
        var client = _api.ClientFor($"keep-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var waiting = await ReadyImportAsync(client, pet.Id);
        var thrownAway = await ReadyImportAsync(client, pet.Id);
        await client.DeleteAsync($"/api/v1/ai-imports/{thrownAway.Id}", Ct);
        await MakeUploadsOldAsync([.. waiting.Pages.Select(p => p.Id), .. thrownAway.Pages.Select(p => p.Id)]);

        await _api.RunStorageCleanupAsync();

        Assert.Equal(HttpStatusCode.OK, (await _api.Storage.GetAsync(waiting.Pages[0].Url, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _api.Storage.GetAsync(thrownAway.Pages[0].Url, Ct)).StatusCode);
        var applied = await client.PostAsJsonAsync($"/api/v1/ai-imports/{waiting.Id}/apply",
            new ApplyImportRequest([], null, null, KeepPhotos: true), Ct);
        Assert.NotNull((await applied.Content.ReadFromJsonAsync<ApplyImportResponse>(Ct))!.DocumentId);
    }

    [Fact]
    public async Task Records_are_saved_even_when_the_photos_are_gone()
    {
        var client = _api.ClientFor($"nophotos-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var import = await ReadyImportAsync(client, pet.Id);
        await using (var scope = _api.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var pages = import.Pages.Select(p => p.Id).ToList();
            scope.ServiceProvider.GetRequiredService<Files>().Remove(await db.StoredFiles.Where(f => pages.Contains(f.Id)).ToListAsync(Ct));
            await db.SaveChangesAsync(Ct);
        }

        var applied = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", new ApplyImportRequest(
            [new ImportedRecordRequest(Record("Rabies vaccination", CareKind.Vaccination, new DateOnly(2025, 3, 12)), null)],
            null, null, KeepPhotos: true), Ct);

        var result = (await applied.Content.ReadFromJsonAsync<ApplyImportResponse>(Ct))!;
        Assert.Single(result.RecordIds);
        Assert.Null(result.DocumentId);
    }

    [Fact]
    public async Task Passport_pages_go_to_one_scan_and_each_vet_paper_to_its_own_document()
    {
        var client = _api.ClientFor($"papers-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var pdf = await client.UploadFileAsync(Pdf());
        var refused = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(pet.Id, AiImportSource.VetDocument, [pdf.Id], null), Ct);
        Assert.Equal(HttpStatusCode.BadRequest, refused.StatusCode); // the model reads photos

        var keep = new ApplyImportRequest([], null, null, KeepPhotos: true);
        foreach (var source in new[] { AiImportSource.PassportPages, AiImportSource.PassportPages, AiImportSource.VetDocument, AiImportSource.VetDocument })
        {
            var import = await ReadyImportAsync(client, pet.Id, source);
            (await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", keep, Ct)).EnsureSuccessStatusCode();
        }

        var passport = Assert.Single((await client.GetFromJsonAsync<List<DocumentResponse>>($"/api/v1/pets/{pet.Id}/documents?type=PassportPage", Ct))!);
        Assert.Equal(2, passport.Pages.Count); // the second scan went on after the first
        Assert.Equal(2, (await client.GetFromJsonAsync<List<DocumentResponse>>($"/api/v1/pets/{pet.Id}/documents?type=Other", Ct))!.Count);
    }

    [Fact]
    public async Task A_draft_shows_what_was_saved_after_it_was_read()
    {
        var client = _api.ClientFor($"fresh-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var first = await ReadyImportAsync(client, pet.Id);
        var second = await ReadyImportAsync(client, pet.Id); // the same page scanned again
        var rabies = first.Draft!.Records[0];
        (await client.PostAsJsonAsync($"/api/v1/ai-imports/{first.Id}/apply", new ApplyImportRequest(
            [new ImportedRecordRequest(Record(rabies.Title!, rabies.Kind, rabies.PerformedOn!.Value) with { Product = rabies.Product }, null)],
            null, null, KeepPhotos: false), Ct)).EnsureSuccessStatusCode();

        var again = (await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{second.Id}", Ct))!.Draft!.Records[0];

        Assert.False(again.Selected);
        Assert.Contains(new DraftWarning("performedOn", DraftIssue.AlreadySaved), again.Warnings);
    }

    [Fact]
    public async Task Identifiers_to_save_are_checked_like_the_pet_form()
    {
        var client = _api.ClientFor($"chipcheck-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var import = await ReadyImportAsync(client, pet.Id);
        const string body = """
            {"records":[],"keepPhotos":false,"identifiers":[
              null,
              {"type":7,"code":"276098100123456"},
              {"type":"IsoChip","code":"250269000001111","location":"LOCATION-THAT-IS-FAR-TOO-LONG-FOR-THE-SIXTY-CHARACTER-COLUMN-AT-ALL"}
            ]}
            """;

        var response = await client.PostAsync($"/api/v1/ai-imports/{import.Id}/apply",
            new StringContent(body, System.Text.Encoding.UTF8, "application/json"), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<HttpValidationProblemDetails>(Ct);
        Assert.Equal(new[] { "identifiers[0]", "identifiers[1].type", "identifiers[2].location" }, problem!.Errors.Keys.Order());
    }

    [Fact]
    public async Task A_saved_scan_cant_be_thrown_away()
    {
        var client = _api.ClientFor($"savedscan-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var import = await ReadyImportAsync(client, pet.Id);
        (await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply",
            new ApplyImportRequest([], null, null, KeepPhotos: true), Ct)).EnsureSuccessStatusCode();

        var discard = await client.DeleteAsync($"/api/v1/ai-imports/{import.Id}", Ct);

        Assert.Equal(HttpStatusCode.Conflict, discard.StatusCode);
        Assert.Equal(AiImportStatus.Applied, (await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{import.Id}", Ct))!.Status);
        Assert.Empty((await client.GetFromJsonAsync<List<AiImportResponse>>($"/api/v1/pets/{pet.Id}/ai-imports", Ct))!);
    }

    [Fact]
    public async Task A_failed_scan_waits_with_its_photos_until_it_is_tried_again()
    {
        var client = _api.ClientFor($"retryfailed-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => throw new HttpRequestException("busy", null, HttpStatusCode.ServiceUnavailable);
        var failed = await WaitUntilDoneAsync(client, (await StartAsync(client, pet.Id, [page.Id])).Id);
        Assert.Equal(AiImportError.Busy, failed.Error);
        await MakeUploadsOldAsync([page.Id]);
        await _api.RunStorageCleanupAsync();

        var waiting = (await client.GetFromJsonAsync<List<AiImportResponse>>($"/api/v1/pets/{pet.Id}/ai-imports", Ct))!;
        Assert.Equal(failed.Id, Assert.Single(waiting).Id); // shown, with its photos still there
        _api.Ai.Answer = _ => PassportPageAnswer;
        var again = await WaitUntilDoneAsync(client, (await StartAsync(client, pet.Id, [page.Id])).Id);

        Assert.Equal(AiImportStatus.Ready, again.Status);
        var now = (await client.GetFromJsonAsync<List<AiImportResponse>>($"/api/v1/pets/{pet.Id}/ai-imports", Ct))!;
        Assert.Equal(again.Id, Assert.Single(now).Id); // the failed one gave way
    }

    [Fact]
    public async Task Each_household_sees_its_own_ai_use()
    {
        var busy = _api.ClientFor($"user-{Guid.NewGuid():N}");
        var quiet = _api.ClientFor($"quiet-{Guid.NewGuid():N}");
        await ReadyImportAsync(busy, (await busy.CreatePetAsync("Murka")).Id);

        Assert.Equal(1, (await busy.GetFromJsonAsync<AiStatusResponse>("/api/v1/ai/status", Ct))!.ThisMonth.Requests);
        Assert.Equal(0, (await quiet.GetFromJsonAsync<AiStatusResponse>("/api/v1/ai/status", Ct))!.ThisMonth.Requests);
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized, AiTestProblem.Rejected)]
    [InlineData(HttpStatusCode.ServiceUnavailable, AiTestProblem.Busy)]
    public async Task A_failed_connection_test_says_why_without_the_providers_words(HttpStatusCode status, AiTestProblem problem)
    {
        var client = _api.ClientFor($"aitestfail-{Guid.NewGuid():N}");
        _api.Ai.Answer = _ => throw new HttpRequestException("secret project 123456 at 10.0.0.5:8080", null, status);

        var response = await client.PostAsync("/api/v1/ai/test", null, Ct);
        var body = await response.Content.ReadAsStringAsync(Ct);

        Assert.Equal(problem, (await response.Content.ReadFromJsonAsync<AiTestResponse>(Ct))!.Problem);
        Assert.DoesNotContain("10.0.0.5", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Scans_cut_off_by_a_restart_are_read_again()
    {
        var client = _api.ClientFor($"restart-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var import = await ReadyImportAsync(client, pet.Id);
        await using var scope = _api.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.AiImports.Where(i => i.Id == import.Id).ExecuteUpdateAsync(s => s
            .SetProperty(i => i.Status, AiImportStatus.Processing)
            .SetProperty(i => i.StartedAt, DateTimeOffset.UtcNow), Ct);

        Assert.DoesNotContain(import.Id, await AiImportWorker.RequeueAsync(db, justStarted: false, DateTimeOffset.UtcNow, Ct));
        Assert.Contains(import.Id, await AiImportWorker.RequeueAsync(db, justStarted: true, DateTimeOffset.UtcNow, Ct));
        await db.AiImports.Where(i => i.Id == import.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, AiImportStatus.Discarded), Ct); // leave the worker nothing to do
    }

    [Fact]
    public async Task A_draft_that_isnt_ready_cannot_be_saved()
    {
        var client = _api.ClientFor($"notready-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => throw new HttpRequestException("API key not valid", null, HttpStatusCode.Forbidden);
        var import = await StartAsync(client, pet.Id, [page.Id]);
        await WaitUntilDoneAsync(client, import.Id);

        var response = await client.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply",
            new ApplyImportRequest([], null, null, KeepPhotos: true), Ct);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task A_refused_request_fails_without_trying_other_models()
    {
        var client = _api.ClientFor($"refused-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => throw new HttpRequestException("API key not valid", null, HttpStatusCode.Unauthorized);

        var import = await StartAsync(client, pet.Id, [page.Id]);
        var done = await WaitUntilDoneAsync(client, import.Id);

        Assert.Equal(AiImportStatus.Failed, done.Status);
        Assert.Equal(AiImportError.Rejected, done.Error);
        Assert.Equal(new[] { "fake-a" }, _api.Ai.Asked);
    }

    [Fact]
    public async Task Without_an_ai_model_scanning_is_refused_up_front()
    {
        var client = _api.ClientFor($"noai-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        _api.Ai.Configured = false;

        var response = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, [page.Id], null), Ct);
        var status = await client.GetFromJsonAsync<AiStatusResponse>("/api/v1/ai/status", Ct);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.False(status!.Configured);
    }

    [Fact]
    public async Task Photos_are_checked_before_a_scan_starts()
    {
        var client = _api.ClientFor($"photos-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var pdf = await client.UploadFileAsync(Pdf());

        var none = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, [], null), Ct);
        var notPhoto = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, [pdf.Id], null), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, none.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, notPhoto.StatusCode);
    }

    [Fact]
    public async Task Retrying_a_start_with_the_same_request_id_starts_one_scan()
    {
        var client = _api.ClientFor($"retryscan-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        var request = new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, [page.Id], Guid.NewGuid());

        var first = await client.PostAsJsonAsync("/api/v1/ai-imports", request, Ct);
        var retry = await client.PostAsJsonAsync("/api/v1/ai-imports", request, Ct);

        var import = (await first.Content.ReadFromJsonAsync<AiImportResponse>(Ct))!;
        Assert.Equal(import.Id, (await retry.Content.ReadFromJsonAsync<AiImportResponse>(Ct))!.Id);
        // Let the worker finish, so it doesn't ask the fake model during the next test.
        await WaitUntilDoneAsync(client, import.Id);
    }

    [Fact]
    public async Task A_discarded_scan_leaves_the_list()
    {
        var client = _api.ClientFor($"discard-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        var import = await StartAsync(client, pet.Id, [page.Id]);
        await WaitUntilDoneAsync(client, import.Id);

        var discarded = await client.DeleteAsync($"/api/v1/ai-imports/{import.Id}", Ct);
        var list = await client.GetFromJsonAsync<List<AiImportResponse>>($"/api/v1/pets/{pet.Id}/ai-imports", Ct);

        Assert.Equal(HttpStatusCode.NoContent, discarded.StatusCode);
        Assert.Empty(list!);
    }

    [Fact]
    public async Task The_connection_test_asks_the_model_about_a_picture()
    {
        var client = _api.ClientFor($"aitest-{Guid.NewGuid():N}");
        _api.Ai.Answer = _ => """{"colour":"Green"}""";

        var test = await client.PostAsync("/api/v1/ai/test", null, Ct);
        var result = (await test.Content.ReadFromJsonAsync<AiTestResponse>(Ct))!;

        Assert.True(result.Ok);
        Assert.Equal("fake-a", result.Model);
    }

    [Fact]
    public async Task Another_household_cannot_see_or_use_a_scan()
    {
        var anna = _api.ClientFor($"anna-{Guid.NewGuid():N}");
        var oleg = _api.ClientFor($"oleg-{Guid.NewGuid():N}");
        var murka = await anna.CreatePetAsync("Murka");
        var annasPage = await anna.UploadPhotoAsync();
        var import = await StartAsync(anna, murka.Id, [annasPage.Id]);
        await WaitUntilDoneAsync(anna, import.Id);
        var rex = await oleg.CreatePetAsync("Rex", Species.Dog);
        var apply = new ApplyImportRequest([], null, null, KeepPhotos: true);

        foreach (var response in new[]
        {
            await oleg.GetAsync($"/api/v1/ai-imports/{import.Id}", Ct),
            await oleg.PostAsJsonAsync($"/api/v1/ai-imports/{import.Id}/apply", apply, Ct),
            await oleg.DeleteAsync($"/api/v1/ai-imports/{import.Id}", Ct),
            await oleg.GetAsync($"/api/v1/pets/{murka.Id}/ai-imports", Ct),
            await oleg.PostAsJsonAsync("/api/v1/ai-imports",
                new CreateAiImportRequest(murka.Id, AiImportSource.PassportPages, [annasPage.Id], null), Ct),
        })
        {
            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }

        // Oleg can't scan Anna's photos for his own pet either.
        var stolen = await oleg.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(rex.Id, AiImportSource.PassportPages, [annasPage.Id], null), Ct);
        Assert.Equal(HttpStatusCode.BadRequest, stolen.StatusCode);
    }

    /// <summary>A scan of one uploaded photo, read by the fake model as <see cref="PassportPageAnswer"/>.</summary>
    private async Task<AiImportResponse> ReadyImportAsync(HttpClient client, Guid petId, AiImportSource source = AiImportSource.PassportPages)
    {
        _api.Ai.Answer = _ => PassportPageAnswer;
        var import = await StartAsync(client, petId, [(await client.UploadPhotoAsync()).Id], source);
        var ready = await WaitUntilDoneAsync(client, import.Id);
        Assert.Equal(AiImportStatus.Ready, ready.Status);
        return ready;
    }

    private async Task MakeUploadsOldAsync(List<Guid> fileIds)
    {
        await using var scope = _api.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<AppDbContext>().StoredFiles
            .Where(f => fileIds.Contains(f.Id))
            .ExecuteUpdateAsync(s => s.SetProperty(f => f.CreatedAt, DateTimeOffset.UtcNow.AddDays(-2)), Ct);
    }

    private static async Task<AiImportResponse> StartAsync(
        HttpClient client, Guid petId, List<Guid> fileIds, AiImportSource source = AiImportSource.PassportPages)
    {
        var response = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(petId, source, fileIds, null), Ct);
        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<AiImportResponse>(Ct))!;
    }

    /// <summary>Polls like the app does, until the background worker has finished.</summary>
    private static async Task<AiImportResponse> WaitUntilDoneAsync(HttpClient client, Guid importId)
    {
        for (var i = 0; i < 100; i++)
        {
            var import = (await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{importId}", Ct))!;
            if (import.Status is not (AiImportStatus.Queued or AiImportStatus.Processing))
            {
                return import;
            }

            await Task.Delay(100, Ct);
        }

        throw new TimeoutException("The import didn't finish.");
    }
}
