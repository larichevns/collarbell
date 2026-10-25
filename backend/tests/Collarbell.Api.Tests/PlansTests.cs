using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Collarbell.Api.Modules.Admin;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Supplies;
using Microsoft.EntityFrameworkCore;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Plans: Free or Premium per household, and the AI photos a month each allows (Billing/Plans).</summary>
[Collection(ApiCollection.Name)]
public sealed class PlansTests : IDisposable
{
    private const string PackageAnswer = """
        {
          "isPetProduct": true, "name": "Sterilised 37", "brand": "Royal Canin", "category": "DryFood",
          "packageAmount": 2, "packageUnit": "Kilogram", "energyValue": null, "energyUnit": null,
          "barcode": null, "species": "Cat", "treatment": null, "protectionWeeks": null, "dosesInPackage": null,
          "evidence": "ROYAL CANIN Sterilised 37 · 2 kg"
        }
        """;

    private readonly ApiFactory _api;

    public PlansTests(ApiFactory api)
    {
        _api = api;
        _api.Ai.Reset();
        _api.Ai.Answer = _ => PackageAnswer;
    }

    public void Dispose() => _api.Ai.Reset();

    [Fact]
    public async Task A_household_starts_free_and_counts_the_photos_AI_read_this_month()
    {
        var client = _api.ClientFor($"plan-free-{Guid.NewGuid():N}");

        var plan = await PlanAsync(client);
        Assert.Equal((PlanKind.Free, (PlanSource?)null, (DateTimeOffset?)null, 0), (plan.Plan, plan.Source, plan.ExpiresAt, plan.AiPhotosUsed));
        Assert.True(plan.AiPhotosPerMonth < plan.PremiumAiPhotosPerMonth);
        var now = DateTimeOffset.UtcNow;
        Assert.Equal(new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero).AddMonths(1), plan.ResetsAt);

        // Two photos read: two counted. A reading that failed gives its photos back.
        Assert.Equal(HttpStatusCode.OK, (await ScanPackageAsync(client, photos: 2)).StatusCode);
        _api.Ai.Answer = _ => "not an answer";
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await ScanPackageAsync(client, photos: 1)).StatusCode);

        Assert.Equal(2, (await PlanAsync(client)).AiPhotosUsed);
    }

    [Fact]
    public async Task Reading_stops_at_the_months_limit_with_a_problem_the_app_can_explain()
    {
        var client = _api.ClientFor($"plan-limit-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var plan = await PlanAsync(client);
        await UseAsync(me.Household.Id, me.Id, plan.AiPhotosPerMonth - 1);
        await UseAsync(me.Household.Id, me.Id, 50, DateTimeOffset.UtcNow.AddMonths(-1)); // last month's don't count

        var tooMany = await ScanPackageAsync(client, photos: 2);
        var problem = await LimitProblemAsync(tooMany);
        Assert.Equal("Not enough AI photos left this month.", problem.GetProperty("title").GetString());
        Assert.Equal(("Free", plan.AiPhotosPerMonth, plan.AiPhotosPerMonth - 1, 2, "household"),
            (problem.GetProperty("plan").GetString(), problem.GetProperty("limit").GetInt32(), problem.GetProperty("used").GetInt32(),
                problem.GetProperty("requested").GetInt32(), problem.GetProperty("scope").GetString()));
        Assert.Equal(plan.ResetsAt, problem.GetProperty("resetsAt").GetDateTimeOffset());

        // One more fits; then every way of reading photos stops.
        Assert.Equal(HttpStatusCode.OK, (await ScanPackageAsync(client, photos: 1)).StatusCode);
        Assert.Equal(plan.AiPhotosPerMonth, (await PlanAsync(client)).AiPhotosUsed);

        var photo = await client.UploadPhotoAsync();
        var pet = await client.CreatePetAsync("Murka");
        await LimitProblemAsync(await client.PostAsJsonAsync("/api/v1/pets/identifiers/scan", new IdentifierScanRequest([photo.Id]), Json, Ct));
        await LimitProblemAsync(await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, [photo.Id], null), Json, Ct));
        var test = await LimitProblemAsync(await client.PostAsync("/api/v1/ai/test", null, Ct));
        Assert.Equal("This month's AI photos are used up.", test.GetProperty("title").GetString());
        Assert.Equal(plan.AiPhotosPerMonth, (await PlanAsync(client)).AiPhotosUsed);
    }

    [Fact]
    public async Task Requests_sent_at_once_are_counted_one_after_another()
    {
        var client = _api.ClientFor($"plan-burst-at-once-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var limit = (await PlanAsync(client)).AiPhotosPerMonth;
        await UseAsync(me.Household.Id, me.Id, limit - 7);
        var photos = new List<Guid>();
        for (var i = 0; i < 9; i++)
        {
            photos.Add((await client.UploadPhotoAsync()).Id);
        }

        // Room for 7: three package photos and two passport scans of two pages fit; the rest is refused.
        var answers = await Task.WhenAll(
            [
                .. photos[..5].Select(p => client.PostAsJsonAsync("/api/v1/products/scan", new ProductScanRequest([p], null), Json, Ct)),
                client.PostAsJsonAsync("/api/v1/ai-imports", new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, photos[5..7], null), Json, Ct),
                client.PostAsJsonAsync("/api/v1/ai-imports", new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, photos[7..9], null), Json, Ct),
            ]);

        var accepted = answers[..5].Count(a => a.StatusCode == HttpStatusCode.OK) + 2 * answers[5..].Count(a => a.StatusCode == HttpStatusCode.Accepted);
        Assert.All(answers, a => Assert.Contains(a.StatusCode, new[] { HttpStatusCode.OK, HttpStatusCode.Accepted, HttpStatusCode.Conflict }));
        Assert.True(accepted <= 7, $"{accepted} photos got through, room was 7");
        Assert.True(accepted >= 6, $"only {accepted} photos got through, room was 7"); // at most one photo wasted by the order
        Assert.True((await PlanAsync(client)).AiPhotosUsed <= limit);
        await WaitForScansAsync(client, answers[5..]);
    }

    [Fact]
    public async Task A_passport_scan_holds_its_photos_from_the_start_and_gives_them_back_if_reading_fails()
    {
        var client = _api.ClientFor($"plan-queue-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var limit = (await PlanAsync(client)).AiPhotosPerMonth;
        await UseAsync(me.Household.Id, me.Id, limit - 2);

        // AI can't read it: held while it waits, given back when it fails.
        _api.Ai.Answer = _ => "not an answer";
        var failing = await StartScanAsync(client, pet.Id, photos: 2);
        Assert.Equal(AiImportStatus.Failed, (await WaitForScanAsync(client, failing)).Status);
        Assert.Equal(limit - 2, (await PlanAsync(client)).AiPhotosUsed);

        // Read: charged.
        _api.Ai.Answer = _ => FakeAi.EmptyScan;
        var read = await StartScanAsync(client, pet.Id, photos: 2);
        Assert.Equal(AiImportStatus.Ready, (await WaitForScanAsync(client, read)).Status);
        Assert.Equal(limit, (await PlanAsync(client)).AiPhotosUsed);
        await LimitProblemAsync(await ScanPackageAsync(client, photos: 1));
    }

    [Fact]
    public async Task On_free_a_person_gets_the_photos_once_across_their_households_even_deleted_ones()
    {
        var uid = $"plan-person-{Guid.NewGuid():N}";
        var client = _api.ClientFor(uid);
        var me = await client.MeAsync();
        var limit = (await PlanAsync(client)).AiPhotosPerMonth;

        // A second household of their own uses up the person's Free photos, then is deleted.
        var spare = (await (await client.PostAsJsonAsync("/api/v1/households", new CreateHouseholdRequest("Spare"), Json, Ct))
            .Content.ReadFromJsonAsync<HouseholdSummary>(Json, Ct))!;
        await UseAsync(spare.Id, me.Id, limit);
        var inSpare = _api.ClientFor(uid);
        inSpare.DefaultRequestHeaders.Add(CurrentUserAccessor.HouseholdHeader, spare.Id.ToString());
        Assert.Equal(HttpStatusCode.NoContent, (await inSpare.DeleteAsync("/api/v1/households/current", Ct)).StatusCode);

        // The first household has used nothing, yet this person has no Free photos left this month.
        Assert.Equal(0, (await PlanAsync(client)).AiPhotosUsed);
        var problem = await LimitProblemAsync(await ScanPackageAsync(client, photos: 1));
        Assert.Equal(("person", limit), (problem.GetProperty("scope").GetString(), problem.GetProperty("used").GetInt32()));

        // Someone else in the same household still can: the household's own count is low.
        var owner = await AdminAsync();
        Assert.Equal(HttpStatusCode.OK,
            (await SetPlanAsync(owner, me.Household.Id, new AdminPlanRequest(PlanKind.Premium, null, null))).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await ScanPackageAsync(client, photos: 1)).StatusCode); // Premium: the household's photos
    }

    [Fact]
    public async Task Premium_given_in_the_admin_counts_its_own_photos_until_it_ends()
    {
        var admin = await AdminAsync();
        var client = _api.ClientFor($"plan-premium-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var free = await PlanAsync(client);
        await UseAsync(me.Household.Id, me.Id, free.AiPhotosPerMonth);
        await LimitProblemAsync(await ScanPackageAsync(client, photos: 1));

        var until = DateTimeOffset.UtcNow.AddMonths(2);
        var given = await SetPlanAsync(admin, me.Household.Id, new AdminPlanRequest(PlanKind.Premium, until, "  tester "));
        Assert.Equal(HttpStatusCode.OK, given.StatusCode);
        var shown = (await given.Content.ReadFromJsonAsync<AdminPlan>(Json, Ct))!;
        Assert.Equal((PlanKind.Premium, PlanSource.Manual, "tester", 0, free.PremiumAiPhotosPerMonth),
            (shown.Plan, shown.Source, shown.Note, shown.AiPhotosUsed, shown.AiPhotosPerMonth));
        Assert.EndsWith("@example.com", shown.ChangedBy, StringComparison.Ordinal);

        // Premium counts the photos taken under it: the Free ones don't eat into it.
        var premium = await PlanAsync(client);
        Assert.Equal((PlanKind.Premium, PlanSource.Manual, free.PremiumAiPhotosPerMonth, 0),
            (premium.Plan, premium.Source, premium.AiPhotosPerMonth, premium.AiPhotosUsed));
        Assert.True(Math.Abs((premium.ExpiresAt!.Value - until).TotalMilliseconds) < 1);
        Assert.Equal(HttpStatusCode.OK, (await ScanPackageAsync(client, photos: 1)).StatusCode);
        Assert.Equal(1, (await PlanAsync(client)).AiPhotosUsed);
        Assert.True((await admin.GetFromJsonAsync<AdminOverview>("/api/admin/overview", Json, Ct))!.People.PremiumHouseholds >= 1);
        var person = await admin.GetFromJsonAsync<AdminUser>($"/api/admin/users/{me.Id}", Json, Ct);
        Assert.Equal(PlanKind.Premium, Assert.Single(person!.Households).Plan);

        // Its end passes: Free again by itself, with the Free photos used up. The admin still sees when it ended.
        await _api.ChangeDatabaseAsync(db => db.HouseholdPlans.Where(p => p.HouseholdId == me.Household.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.ExpiresAt, DateTimeOffset.UtcNow.AddMinutes(-1)), Ct));
        Assert.Equal((PlanKind.Free, free.AiPhotosPerMonth), ((await PlanAsync(client)).Plan, (await PlanAsync(client)).AiPhotosUsed));
        await LimitProblemAsync(await ScanPackageAsync(client, photos: 1));
        var household = await admin.GetFromJsonAsync<AdminHousehold>($"/api/admin/households/{me.Household.Id}", Json, Ct);
        Assert.Equal(PlanKind.Free, household!.Plan.Plan);
        Assert.NotNull(household.Plan.ExpiresAt);

        // Given with no end, then taken back.
        Assert.Equal(HttpStatusCode.OK, (await SetPlanAsync(admin, me.Household.Id, new AdminPlanRequest(PlanKind.Premium, null, null))).StatusCode);
        var forever = await PlanAsync(client);
        Assert.Equal((PlanKind.Premium, (DateTimeOffset?)null), (forever.Plan, forever.ExpiresAt));
        Assert.Equal(HttpStatusCode.OK, (await SetPlanAsync(admin, me.Household.Id, new AdminPlanRequest(PlanKind.Free, until, null))).StatusCode);
        var back = await PlanAsync(client);
        Assert.Equal((PlanKind.Free, (DateTimeOffset?)null), (back.Plan, back.ExpiresAt));
    }

    [Fact]
    public async Task Only_admins_set_plans_with_a_plan_named_and_an_end_to_come()
    {
        var admin = await AdminAsync();
        var someone = _api.ClientFor($"plan-someone-{Guid.NewGuid():N}");
        var household = (await someone.MeAsync()).Household.Id;

        Assert.Equal(HttpStatusCode.Forbidden,
            (await SetPlanAsync(someone, household, new AdminPlanRequest(PlanKind.Premium, null, null))).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await SetPlanAsync(admin, household, new AdminPlanRequest(PlanKind.Premium, DateTimeOffset.UtcNow.AddDays(-1), null))).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await SetPlanAsync(admin, household, new AdminPlanRequest(PlanKind.Premium, null, new string('x', HouseholdPlan.MaxNoteLength + 1)))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await SetPlanAsync(admin, Guid.NewGuid(), new AdminPlanRequest(PlanKind.Premium, null, null))).StatusCode);
        // No plan named: refused, not taken as Free.
        Assert.Equal(HttpStatusCode.BadRequest, (await admin.PutAsJsonAsync($"/api/admin/households/{household}/plan",
            new { note = "oops" }, Json, Ct)).StatusCode);
        Assert.Equal(PlanKind.Free, (await PlanAsync(someone)).Plan);

        // An end with any offset is the same moment, kept in UTC.
        var fourHoursAhead = new DateTimeOffset(DateTime.UtcNow.Year + 1, 1, 1, 0, 0, 0, TimeSpan.FromHours(4));
        var dated = await SetPlanAsync(admin, household, new AdminPlanRequest(PlanKind.Premium, fourHoursAhead, null));
        Assert.Equal(HttpStatusCode.OK, dated.StatusCode);
        Assert.Equal(fourHoursAhead, (await PlanAsync(someone)).ExpiresAt);

        // The first change made twice at once: both are taken.
        var other = (await _api.ClientFor($"plan-race-{Guid.NewGuid():N}").MeAsync()).Household.Id;
        var both = await Task.WhenAll(Enumerable.Range(0, 4).Select(_ =>
            SetPlanAsync(admin, other, new AdminPlanRequest(PlanKind.Premium, null, "race"))));
        Assert.All(both, r => Assert.Equal(HttpStatusCode.OK, r.StatusCode));
    }

    [Fact]
    public async Task Reading_photos_is_held_to_ten_requests_a_minute()
    {
        var client = _api.ClientFor($"plan-burst-{Guid.NewGuid():N}");
        _api.Ai.Answer = _ => """{ "colour": "green" }""";

        var answers = new List<HttpStatusCode>();
        for (var i = 0; i < 11; i++)
        {
            answers.Add((await client.PostAsync("/api/v1/ai/test", null, Ct)).StatusCode);
        }

        Assert.Equal([.. Enumerable.Repeat(HttpStatusCode.OK, 10), HttpStatusCode.TooManyRequests], answers);
        Assert.Equal(10, (await PlanAsync(client)).AiPhotosUsed); // the test's picture counts like any photo
    }

    private static async Task<PlanResponse> PlanAsync(HttpClient client) =>
        (await client.GetFromJsonAsync<PlanResponse>("/api/v1/plan", Json, Ct))!;

    /// <summary>A 409 of type ai-limit; its body.</summary>
    private static async Task<JsonElement> LimitProblemAsync(HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>(Ct);
        Assert.Equal(Plans.AiLimitProblemType, problem.GetProperty("type").GetString());
        return problem;
    }

    private static async Task<HttpResponseMessage> ScanPackageAsync(HttpClient client, int photos)
    {
        var uploaded = new List<Guid>();
        for (var i = 0; i < photos; i++)
        {
            uploaded.Add((await client.UploadPhotoAsync()).Id);
        }

        return await client.PostAsJsonAsync("/api/v1/products/scan", new ProductScanRequest(uploaded, null), Json, Ct);
    }

    private static async Task<Guid> StartScanAsync(HttpClient client, Guid petId, int photos)
    {
        var pages = new List<Guid>();
        for (var i = 0; i < photos; i++)
        {
            pages.Add((await client.UploadPhotoAsync()).Id);
        }

        var started = await client.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(petId, AiImportSource.PassportPages, pages, null), Json, Ct);
        Assert.Equal(HttpStatusCode.Accepted, started.StatusCode);
        return (await started.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id;
    }

    private static async Task<AiImportResponse> WaitForScanAsync(HttpClient client, Guid importId)
    {
        for (var i = 0; i < 200; i++)
        {
            var import = (await client.GetFromJsonAsync<AiImportResponse>($"/api/v1/ai-imports/{importId}", Json, Ct))!;
            if (import.Status is not (AiImportStatus.Queued or AiImportStatus.Processing))
            {
                return import;
            }

            await Task.Delay(50, Ct);
        }

        throw new TimeoutException($"Scan {importId} is still being read.");
    }

    /// <summary>Lets the scans that were started finish here, so they don't answer for the next test.</summary>
    private static async Task WaitForScansAsync(HttpClient client, IEnumerable<HttpResponseMessage> answers)
    {
        foreach (var answer in answers.Where(a => a.StatusCode == HttpStatusCode.Accepted))
        {
            await WaitForScanAsync(client, (await answer.Content.ReadFromJsonAsync<AiImportResponse>(Json, Ct))!.Id);
        }
    }

    private static Task<HttpResponseMessage> SetPlanAsync(HttpClient admin, Guid householdId, AdminPlanRequest request) =>
        admin.PutAsJsonAsync($"/api/admin/households/{householdId}/plan", request, Json, Ct);

    /// <summary>Photos AI read for the person in the household on its Free plan: now, or at <paramref name="at"/>.</summary>
    private Task UseAsync(Guid householdId, Guid userId, int photos, DateTimeOffset? at = null) =>
        _api.ChangeDatabaseAsync(async db =>
        {
            var when = at ?? DateTimeOffset.UtcNow;
            var charge = new AiPhotoCharge(householdId, userId, PlanKind.Free, photos, "product-scan", null, when);
            charge.Settle(answered: true, when);
            db.AiPhotoCharges.Add(charge);
            await db.SaveChangesAsync(Ct);
        });

    /// <summary>A signed-in admin: a user like any other, marked in the database as make-admin does.</summary>
    private async Task<HttpClient> AdminAsync()
    {
        var client = _api.ClientFor($"admin-{Guid.NewGuid():N}", $"admin-{Guid.NewGuid():N}@example.com");
        var me = await client.MeAsync();
        await _api.ChangeDatabaseAsync(db => db.Users.Where(u => u.Id == me.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsAdmin, true), Ct));
        return client;
    }
}
