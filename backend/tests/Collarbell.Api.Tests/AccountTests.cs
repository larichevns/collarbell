using System.IO.Compression;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Infrastructure.Storage;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Collarbell.Api.Modules.Supplies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Deleting an account and "Download my data" (spec, "Удаление аккаунта и выгрузка данных").</summary>
[Collection(ApiCollection.Name)]
public sealed class AccountTests(ApiFactory api)
{
    private static string Uid(string name) => $"{name}-{Guid.NewGuid():N}";

    private static async Task AssertProblemAsync(HttpResponseMessage response, HttpStatusCode status, string type)
    {
        Assert.Equal(status, response.StatusCode);
        Assert.Equal(type, (await response.Content.ReadFromJsonAsync<ProblemDetails>(Json, Ct))!.Type);
    }

    /// <summary>A client of <paramref name="uid"/> that works in <paramref name="householdId"/>.</summary>
    private HttpClient ClientIn(string uid, Guid householdId)
    {
        var client = api.ClientFor(uid);
        client.DefaultRequestHeaders.Add(CurrentUserAccessor.HouseholdHeader, householdId.ToString());
        return client;
    }

    /// <summary><paramref name="uid"/> joins the owner's household with <paramref name="role"/>, named <paramref name="name"/>.</summary>
    private async Task<HttpClient> JoinAsync(HttpClient owner, Guid householdId, string uid, HouseholdRole role, string? name = null)
    {
        var invite = await (await owner.PostAsJsonAsync("/api/v1/households/current/invites", new CreateInviteRequest(role), Json, Ct))
            .Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct);
        var person = api.ClientFor(uid, $"{uid}@example.com");
        if (name is not null)
        {
            await person.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest(name, null, null), Json, Ct);
        }

        Assert.Equal(HttpStatusCode.OK,
            (await person.PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(invite!.Code), Json, Ct)).StatusCode);
        return ClientIn(uid, householdId);
    }

    private static async Task<AccountDeletionPreview> PreviewAsync(HttpClient client) =>
        (await client.GetFromJsonAsync<AccountDeletionPreview>("/api/v1/me/deletion", Json, Ct))!;

    private static async Task<HouseholdDetails> DetailsAsync(HttpClient client) =>
        (await client.GetFromJsonAsync<HouseholdDetails>("/api/v1/households/current", Json, Ct))!;

    private static Task<HttpResponseMessage> MarkFedAsync(HttpClient client, Guid routineId, TimeOnly time) =>
        client.PostAsJsonAsync($"/api/v1/routines/{routineId}/completions",
            new CompleteRoutineRequest(Today, time, CompletionStatus.Done), Json, Ct);

    [Fact]
    public async Task Deleting_an_account_alone_deletes_its_household_and_files()
    {
        var uid = Uid("alone");
        var client = api.ClientFor(uid, $"{uid}@example.com");
        var householdId = (await client.MeAsync()).Household.Id;
        var pet = await client.CreatePetAsync("Murka");
        var photo = await client.UploadPhotoAsync();
        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/photo", new SetPetPhotoRequest(photo.Id), Ct);
        var page = await client.UploadFileAsync(Pdf());
        Assert.Equal(HttpStatusCode.Created, (await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.VaccinationCertificate, null, null, null, [page.Id]), Ct)).StatusCode);
        var routine = await client.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0)));
        await MarkFedAsync(client, routine.Id, new TimeOnly(8, 0));
        var supply = await client.CreateSupplyAsync(Supply("Kibble"));
        await client.AddStockAsync(supply.Id, StockEventKind.Purchase, 2000);

        var preview = await PreviewAsync(client);
        var deleted = await client.DeleteAccountAsync();

        var only = Assert.Single(preview.Households);
        Assert.Equal((householdId, HouseholdFate.Deleted, 1, 0), (only.Id, only.Fate, only.Pets, only.Others));
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
        await api.ChangeDatabaseAsync(async db =>
        {
            Assert.False(await db.Users.AnyAsync(u => u.AuthSubject == $"dev:{uid}", Ct));
            Assert.False(await db.Households.AnyAsync(h => h.Id == householdId, Ct));
            Assert.False(await db.Pets.AnyAsync(p => p.HouseholdId == householdId, Ct));
            Assert.False(await db.StoredFiles.AnyAsync(f => f.HouseholdId == householdId, Ct));
            Assert.False(await db.SupplyItems.AnyAsync(s => s.HouseholdId == householdId, Ct));
            Assert.False(await db.RoutineCompletions.AnyAsync(c => c.HouseholdId == householdId, Ct));
            var account = await db.DeletedAccounts.SingleAsync(d => d.AuthSubject == $"dev:{uid}", Ct);
            Assert.NotNull(account.SignInDeletedAt);
        });
        Assert.Contains($"dev:{uid}", api.SignIns.Deleted);

        // The photo, its small copy and the page leave storage with the next cleanup: nothing of the household is left.
        Assert.NotEmpty(await api.StorageKeysAsync($"{householdId}/"));
        await api.RunStorageCleanupAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(photo.Url, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(photo.ThumbnailUrl!, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(page.Url, Ct)).StatusCode);
        Assert.Empty(await api.StorageKeysAsync($"{householdId}/"));
    }

    [Fact]
    public async Task The_token_of_a_deleted_account_starts_no_new_account()
    {
        var uid = Uid("gone");
        var client = api.ClientFor(uid);
        await client.MeAsync();
        await client.DeleteAccountAsync();

        // Another phone still holds a token that works for up to an hour.
        await AssertProblemAsync(await api.ClientFor(uid).GetAsync("/api/v1/me", Ct), HttpStatusCode.Unauthorized,
            AccountProblems.Deleted);
        await AssertProblemAsync(await api.ClientFor(uid).GetAsync("/api/v1/pets", Ct), HttpStatusCode.Unauthorized,
            AccountProblems.Deleted);
        await api.ChangeDatabaseAsync(async db => Assert.False(await db.Users.AnyAsync(u => u.AuthSubject == $"dev:{uid}", Ct)));
    }

    [Fact]
    public async Task Deleting_needs_a_fresh_sign_in()
    {
        var uid = Uid("stale");
        var client = api.ClientFor(uid);
        await client.MeAsync();
        client.DefaultRequestHeaders.Add(DevUserAuthenticationHandler.AuthTimeHeader,
            DateTimeOffset.UtcNow.AddMinutes(-6).ToUnixTimeSeconds().ToString());

        await AssertProblemAsync(await client.DeleteAccountAsync(), HttpStatusCode.Forbidden,
            AccountProblems.RecentSignInRequired);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/me", Ct)).StatusCode);
    }

    [Fact]
    public async Task In_a_shared_household_the_others_keep_everything_and_the_marks_lose_only_the_name()
    {
        var annaUid = Uid("anna");
        var anna = api.ClientFor(annaUid, $"{annaUid}@example.com");
        var householdId = (await anna.MeAsync()).Household.Id;
        var pet = await anna.CreatePetAsync("Murka");
        var routine = await anna.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0), new TimeOnly(20, 0)));
        var supply = await anna.CreateSupplyAsync(Supply("Kibble"));
        var borisUid = Uid("boris");
        var boris = await JoinAsync(anna, householdId, borisUid, HouseholdRole.Member, "Boris");
        await MarkFedAsync(boris, routine.Id, new TimeOnly(8, 0));
        await boris.AddStockAsync(supply.Id, StockEventKind.Purchase, 2000);
        var record = await boris.CreateRecordAsync(pet.Id, Record("Deworming", CareKind.Deworming, Today));

        var preview = await PreviewAsync(boris);
        Assert.Equal(HttpStatusCode.NoContent, (await boris.DeleteAccountAsync()).StatusCode);

        // Boris was a member: the household stays as it was, with Anna its owner.
        var mine = Assert.Single(preview.Households, h => h.Id == householdId);
        Assert.Equal((HouseholdFate.Kept, 1, 1), (mine.Fate, mine.Pets, mine.Others));
        var details = await DetailsAsync(anna);
        Assert.Equal(annaUid, Assert.Single(details.Members).Email!.Split('@')[0]);

        // The cat was fed: the mark stays (nobody feeds it twice), without a name. So do his purchase and his record.
        var today = await anna.GetStringAsync($"/api/v1/today?date={Today:yyyy-MM-dd}", Ct);
        Assert.Contains("\"byName\":null", today, StringComparison.Ordinal);
        await api.ChangeDatabaseAsync(async db =>
        {
            var mark = await db.RoutineCompletions.SingleAsync(c => c.RoutineId == routine.Id, Ct);
            Assert.Null(mark.DoneBy);
            Assert.Null((await db.StockEvents.SingleAsync(e => e.SupplyItemId == supply.Id, Ct)).CreatedBy);
            Assert.True(await db.CareRecords.AnyAsync(r => r.Id == record.Id, Ct));
        });
        Assert.Equal(HttpStatusCode.Conflict, (await MarkFedAsync(anna, routine.Id, new TimeOnly(8, 0))).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await MarkFedAsync(anna, routine.Id, new TimeOnly(20, 0))).StatusCode);
    }

    [Fact]
    public async Task The_last_owner_hands_the_household_to_the_member_who_joined_first()
    {
        var annaUid = Uid("anna");
        var anna = api.ClientFor(annaUid);
        var householdId = (await anna.MeAsync()).Household.Id;
        await anna.CreatePetAsync("Murka");
        var sitterUid = Uid("sitter");
        await JoinAsync(anna, householdId, sitterUid, HouseholdRole.Helper, "Sitter");
        var borisUid = Uid("boris");
        await JoinAsync(anna, householdId, borisUid, HouseholdRole.Member, "Boris");
        var carlUid = Uid("carl");
        await JoinAsync(anna, householdId, carlUid, HouseholdRole.Member, "Carl");

        var preview = await PreviewAsync(anna);
        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);

        var home = Assert.Single(preview.Households);
        Assert.Equal((HouseholdFate.HandedOver, "Boris", 3), (home.Fate, home.NewOwner, home.Others));
        var details = await DetailsAsync(ClientIn(borisUid, householdId));
        Assert.Equal(HouseholdRole.Owner, details.Role);
        Assert.Equal([("Sitter", HouseholdRole.Helper), ("Boris", HouseholdRole.Owner), ("Carl", HouseholdRole.Member)],
            details.Members.Select(m => (m.DisplayName, m.Role)));
        Assert.Single(await ClientIn(borisUid, householdId).GetFromJsonAsync<List<PetResponse>>("/api/v1/pets", Json, Ct) ?? []);
    }

    [Fact]
    public async Task A_household_with_only_helpers_left_goes_with_its_owner()
    {
        var annaUid = Uid("anna");
        var anna = api.ClientFor(annaUid);
        var householdId = (await anna.MeAsync()).Household.Id;
        await anna.CreatePetAsync("Murka");
        var sitterUid = Uid("sitter");
        var sitter = await JoinAsync(anna, householdId, sitterUid, HouseholdRole.Helper);

        var preview = await PreviewAsync(anna);
        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);

        var home = Assert.Single(preview.Households);
        Assert.Equal((HouseholdFate.Deleted, 1, 1), (home.Fate, home.Pets, home.Others));
        await AssertProblemAsync(await sitter.GetAsync("/api/v1/pets", Ct), HttpStatusCode.Forbidden, HouseholdProblems.NotAMember);
        // The sitter has a household of their own again.
        var me = await api.ClientFor(sitterUid).MeAsync();
        Assert.NotEqual(householdId, me.Household.Id);
        Assert.Equal(HouseholdRole.Owner, me.Household.Role);
    }

    [Fact]
    public async Task Another_owner_keeps_the_household_as_it_is()
    {
        var annaUid = Uid("anna");
        var anna = api.ClientFor(annaUid);
        var householdId = (await anna.MeAsync()).Household.Id;
        var borisUid = Uid("boris");
        await JoinAsync(anna, householdId, borisUid, HouseholdRole.Member);
        var borisId = (await DetailsAsync(anna)).Members.Single(m => !m.IsMe).UserId;
        await anna.PutAsJsonAsync($"/api/v1/households/current/members/{borisId}",
            new ChangeMemberRoleRequest(HouseholdRole.Owner), Json, Ct);
        var dacha = (await (await anna.PostAsJsonAsync("/api/v1/households", new CreateHouseholdRequest("Dacha"), Json, Ct))
            .Content.ReadFromJsonAsync<HouseholdSummary>(Json, Ct))!;

        var preview = await PreviewAsync(anna);
        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);

        // The first-joined first: home, then the one she made later.
        Assert.Equal([(householdId, HouseholdFate.Kept), (dacha.Id, HouseholdFate.Deleted)],
            preview.Households.Select(h => (h.Id, h.Fate)));
        var details = await DetailsAsync(ClientIn(borisUid, householdId));
        Assert.Equal((borisId, HouseholdRole.Owner), (Assert.Single(details.Members).UserId, details.Role));
    }

    [Fact]
    public async Task A_sign_in_account_Firebase_refuses_is_deleted_later_and_then_forgotten()
    {
        var uid = Uid("later");
        var client = api.ClientFor(uid);
        await client.MeAsync();
        api.SignIns.Refusing[$"dev:{uid}"] = true;

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAccountAsync()).StatusCode);
        await api.RunAccountCleanupAsync();
        DeletedAccount? waiting = null;
        await api.ChangeDatabaseAsync(async db => waiting = await db.DeletedAccounts.AsNoTracking().SingleAsync(d => d.AuthSubject == $"dev:{uid}", Ct));
        Assert.Null(waiting!.SignInDeletedAt);
        Assert.Equal(2, waiting.Attempts);

        api.SignIns.Refusing.TryRemove($"dev:{uid}", out _);
        await api.RunAccountCleanupAsync();
        Assert.Contains($"dev:{uid}", api.SignIns.Deleted);

        // A day after the sign-in account went, no token of it can work: the account is forgotten.
        await api.ChangeDatabaseAsync(db => db.DeletedAccounts.Where(d => d.AuthSubject == $"dev:{uid}")
            .ExecuteUpdateAsync(s => s.SetProperty(d => d.SignInDeletedAt, DateTimeOffset.UtcNow - AccountCleanup.RefuseFor - TimeSpan.FromMinutes(1)), Ct));
        await api.RunAccountCleanupAsync();
        await api.ChangeDatabaseAsync(async db => Assert.False(await db.DeletedAccounts.AnyAsync(d => d.AuthSubject == $"dev:{uid}", Ct)));
    }

    [Fact]
    public async Task A_sign_in_account_that_stays_in_Firebase_is_told_to_the_admin()
    {
        var uid = Uid("stuck");
        var client = api.ClientFor(uid);
        await client.MeAsync();
        api.SignIns.Refusing[$"dev:{uid}"] = true;
        await client.DeleteAccountAsync();

        Assert.DoesNotContain("sign-in-deletion", await api.RunAlertChecksAsync(DateTimeOffset.UtcNow));
        Assert.Contains("sign-in-deletion", await api.RunAlertChecksAsync(DateTimeOffset.UtcNow.AddHours(2)));

        // Firebase lets go: nothing left for the other tests' checks to find.
        api.SignIns.Refusing.TryRemove($"dev:{uid}", out _);
        await api.RunAccountCleanupAsync();
        await api.ChangeDatabaseAsync(db => db.Alerts.Where(a => a.Kind == "sign-in-deletion").ExecuteDeleteAsync(Ct));
    }

    [Fact]
    public async Task The_export_has_the_account_and_each_household_with_its_files()
    {
        var uid = Uid("export");
        var client = api.ClientFor(uid, $"{uid}@example.com");
        await client.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Анна", null, null), Json, Ct);
        await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Мурка");
        var photo = await client.UploadPhotoAsync();
        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/photo", new SetPetPhotoRequest(photo.Id), Ct);
        var page = await client.UploadFileAsync(Pdf());
        await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.VaccinationCertificate, "Rabies", null, null, [page.Id]), Ct);
        var routine = await client.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0)));
        await MarkFedAsync(client, routine.Id, new TimeOnly(8, 0));
        await client.CreateRecordAsync(pet.Id, Record("Rabies", CareKind.Vaccination, Today));
        var notYetUsed = await client.UploadPhotoAsync();

        var response = await client.GetAsync("/api/v1/me/export", Ct);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/zip", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal($"collarbell-export-{DateTime.UtcNow:yyyy-MM-dd}.zip", response.Content.Headers.ContentDisposition?.FileNameStar);
        await using var zip = new ZipArchive(new MemoryStream(await response.Content.ReadAsByteArrayAsync(Ct)));
        var names = zip.Entries.Select(e => e.FullName).ToList();
        Assert.Equal(["README.txt", "account.json", "households/1-Home/household.json"], names.Take(3));

        using var account = JsonDocument.Parse(await ReadAsync(zip, "account.json"));
        Assert.Equal($"{uid}@example.com", account.RootElement.GetProperty("account").GetProperty("email").GetString());
        Assert.Equal("Анна", account.RootElement.GetProperty("account").GetProperty("displayName").GetString());
        Assert.Equal("households/1-Home", account.RootElement.GetProperty("households")[0].GetProperty("folder").GetString());
        Assert.Equal(1, account.RootElement.GetProperty("phones").GetArrayLength());
        Assert.True(account.RootElement.GetProperty("activity").GetProperty("requests").ValueKind == JsonValueKind.Array);

        var householdJson = await ReadAsync(zip, "households/1-Home/household.json");
        using var household = JsonDocument.Parse(householdJson);
        var root = household.RootElement;
        Assert.Equal("Мурка", root.GetProperty("pets")[0].GetProperty("name").GetString());
        Assert.Contains("\"Мурка\"", householdJson, StringComparison.Ordinal);
        Assert.Equal(photo.Id, root.GetProperty("pets")[0].GetProperty("photoFileId").GetGuid());
        Assert.Equal("Rabies", root.GetProperty("documents")[0].GetProperty("title").GetString());
        Assert.Equal(page.Id, root.GetProperty("documents")[0].GetProperty("pages")[0].GetProperty("fileId").GetGuid());
        Assert.Equal(1, root.GetProperty("careRecords").GetArrayLength());
        Assert.Equal("Done", root.GetProperty("routineMarks")[0].GetProperty("status").GetString());
        Assert.Equal(root.GetProperty("people")[0].GetProperty("id").GetGuid(),
            root.GetProperty("routineMarks")[0].GetProperty("doneBy").GetGuid());
        Assert.Equal("Free", root.GetProperty("plan").GetProperty("plan").GetString());

        // Every file the server keeps for the household, by the paths household.json gives; one used nowhere yet says so.
        var listed = root.GetProperty("files").EnumerateArray().ToList();
        var files = listed.ToDictionary(f => f.GetProperty("id").GetGuid(), f => f.GetProperty("path").GetString()!);
        Assert.Equal([photo.Id, page.Id, notYetUsed.Id], files.Keys.Order());
        Assert.Equal(JsonValueKind.Null,
            listed.Single(f => f.GetProperty("id").GetGuid() == notYetUsed.Id).GetProperty("attachedAt").ValueKind);
        Assert.NotNull(zip.GetEntry($"households/1-Home/{files[notYetUsed.Id]}"));
        Assert.Equal(Pdf(), await ReadBytesAsync(zip, $"households/1-Home/{files[page.Id]}"));
        Assert.Equal(await api.Storage.GetByteArrayAsync(photo.Url, Ct), await ReadBytesAsync(zip, $"households/1-Home/{files[photo.Id]}"));
        Assert.EndsWith(".pdf", files[page.Id], StringComparison.Ordinal);

        // Nothing of the server's insides: storage paths, push addresses, retry keys.
        foreach (var json in new[] { await ReadAsync(zip, "account.json"), householdJson })
        {
            Assert.DoesNotContain("storageKey", json, StringComparison.Ordinal);
            Assert.DoesNotContain("\"token\"", json, StringComparison.Ordinal);
            Assert.DoesNotContain("clientRequestId", json, StringComparison.Ordinal);
            Assert.DoesNotContain("householdId", json, StringComparison.Ordinal);
        }
    }

    [Fact]
    public async Task A_helpers_export_names_the_others_without_their_e_mails()
    {
        var annaUid = Uid("anna");
        var anna = api.ClientFor(annaUid, $"{annaUid}@example.com");
        var householdId = (await anna.MeAsync()).Household.Id;
        await anna.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Anna", null, null), Json, Ct);
        var sitterUid = Uid("sitter");
        var sitter = await JoinAsync(anna, householdId, sitterUid, HouseholdRole.Helper);

        var response = await api.ClientFor(sitterUid, $"{sitterUid}@example.com").GetAsync("/api/v1/me/export", Ct);
        await using var zip = new ZipArchive(new MemoryStream(await response.Content.ReadAsByteArrayAsync(Ct)));

        // Their own household first, then Anna's.
        using var household = JsonDocument.Parse(await ReadAsync(zip, "households/2-Home/household.json"));
        var people = household.RootElement.GetProperty("people").EnumerateArray().ToList();
        Assert.Equal(["Anna", null], people.Select(p => p.GetProperty("name").GetString()));
        Assert.Equal([null, $"{sitterUid}@example.com"], people.Select(p => p.GetProperty("email").GetString()));
        Assert.Equal("Helper", household.RootElement.GetProperty("household").GetProperty("yourRole").GetString());
    }

    [Fact]
    public async Task The_deletion_does_what_the_person_was_shown_or_nothing()
    {
        var annaUid = Uid("anna");
        var anna = api.ClientFor(annaUid);
        var householdId = (await anna.MeAsync()).Household.Id;
        await anna.CreatePetAsync("Murka");
        var invite = (await (await anna.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Member), Json, Ct)).Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct))!;
        var shown = await PreviewAsync(anna);
        Assert.Equal(HouseholdFate.Deleted, Assert.Single(shown.Households).Fate);

        // While Anna types her password again, someone she gave the code to last week uses it.
        var borisUid = Uid("boris");
        Assert.Equal(HttpStatusCode.OK, (await api.ClientFor(borisUid, $"{borisUid}@example.com")
            .PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(invite.Code), Json, Ct)).StatusCode);

        // She agreed to "deleted with everything in it", not to "Boris gets it": nothing happens, she looks again.
        await AssertProblemAsync(await anna.DeleteAsync($"/api/v1/me?plan={shown.Plan}", Ct), HttpStatusCode.Conflict,
            AccountProblems.PlanChanged);
        Assert.Equal(HttpStatusCode.OK, (await anna.GetAsync("/api/v1/me", Ct)).StatusCode);
        var now = await PreviewAsync(anna);
        Assert.Equal(HouseholdFate.HandedOver, Assert.Single(now.Households).Fate);
        Assert.NotEqual(shown.Plan, now.Plan);

        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAsync($"/api/v1/me?plan={now.Plan}", Ct)).StatusCode);
        Assert.Equal(HouseholdRole.Owner, (await DetailsAsync(ClientIn(borisUid, householdId))).Role);
    }

    [Fact]
    public async Task The_request_log_keeps_nothing_of_a_deleted_account()
    {
        var client = api.ClientFor(Uid("log"));
        var me = await client.MeAsync();
        await api.FlushRequestLogAsync();
        await client.GetAsync("/api/v1/pets", Ct); // still waiting to be written when the account goes

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAccountAsync()).StatusCode);
        await api.FlushRequestLogAsync();

        // The requests stay for the server's own checks (errors, timings), without whose they were.
        List<string> theirs = [];
        await api.ChangeDatabaseAsync(async db => theirs = await db.Requests.AsNoTracking()
            .Where(r => r.UserId == me.Id || r.HouseholdId == me.Household.Id)
            .Select(r => r.Method + " " + r.Path)
            .ToListAsync(Ct));
        Assert.Empty(theirs);
    }

    [Fact]
    public async Task The_admin_tells_a_deleted_admins_token_the_account_is_gone()
    {
        var client = api.ClientFor(Uid("admin"));
        var me = await client.MeAsync();
        await api.ChangeDatabaseAsync(db => db.Users.Where(u => u.Id == me.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsAdmin, true), Ct));
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/admin/me", Ct)).StatusCode);

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAccountAsync()).StatusCode);

        await AssertProblemAsync(await client.GetAsync("/api/admin/me", Ct), HttpStatusCode.Unauthorized, AccountProblems.Deleted);
    }

    [Fact]
    public async Task An_export_with_every_kind_of_record_is_one_whole_zip()
    {
        var uid = Uid("everything");
        var client = api.ClientFor(uid, $"{uid}@example.com");
        var pet = await client.CreatePetAsync("Murka");
        Assert.Equal(HttpStatusCode.OK, (await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}",
            Pet("Murka") with { Identifiers = [new PetIdentifierRequest(IdentifierType.IsoChip, "276098100123456", Today, null, "neck")] },
            Json, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/passport",
            new PassportRequest(PassportModel.Eu2014, "DE 0123", "de", Today,
                new PassportContactDto("Dr. Vet", "Street 1", "+49 1", "vet@example.com"),
                [new PassportContactDto("Anna", "Home 2", "+49 2", "anna@example.com")], "notes"), Json, Ct)).StatusCode);
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today, 1, IntervalUnit.Year, CareKind.Vaccination) with
        {
            Targets = [VaccineTarget.Rabies],
        });
        var record = await client.CreateRecordAsync(pet.Id, Record("Titer", CareKind.RabiesTiter, Today) with
        {
            PerformedTime = new TimeOnly(9, 30),
            Details = new CareRecordDetailsDto("Lab", "R-1", 0.75m, true),
        });
        await client.CreateRecordAsync(pet.Id, Record("Check-up", CareKind.VetExam, Today) with { WeightKg = 4.25m });
        Assert.Equal(HttpStatusCode.Created, (await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/weights",
            new WeightRequest(Today, 4.2m, Bcs: 5, BcsScale: 9, Note: "home scale", RequestId: Guid.NewGuid()), Json, Ct)).StatusCode);
        var scan = await client.UploadPhotoAsync();
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync($"/api/v1/care-records/{record.Id}/files",
            new AddRecordFilesRequest([scan.Id]), Json, Ct)).StatusCode);
        await client.CreateVisitAsync(Visit("Check-up", Today.AddDays(3), new TimeOnly(10, 0), pet.Id));
        var routine = await client.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0), new TimeOnly(19, 0)));
        await MarkFedAsync(client, routine.Id, new TimeOnly(8, 0));
        var supply = await client.CreateSupplyAsync(Supply("Kibble"));
        await client.AddStockAsync(supply.Id, StockEventKind.Purchase, 2000);
        var photo = await client.UploadPhotoAsync();
        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/photo", new SetPetPhotoRequest(photo.Id), Ct);
        var page = await client.UploadFileAsync(Pdf());
        Assert.Equal(HttpStatusCode.Created, (await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.VaccinationCertificate, "Rabies", null, null, [page.Id]), Ct)).StatusCode);
        await client.PostAsJsonAsync("/api/v1/households/current/invites", new CreateInviteRequest(HouseholdRole.Helper), Json, Ct);

        var response = await client.GetAsync("/api/v1/me/export", Ct);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        await using var zip = new ZipArchive(new MemoryStream(await response.Content.ReadAsByteArrayAsync(Ct)));
        var householdJson = await ReadAsync(zip, "households/1-Home/household.json");
        using var json = JsonDocument.Parse(householdJson);
        foreach (var section in new[] { "invites", "pets", "passports", "weights", "carePlans", "careRecords", "visits",
                     "routines", "routineMarks", "supplies", "stockEvents", "documents", "files" })
        {
            Assert.True(json.RootElement.GetProperty(section).GetArrayLength() > 0, section);
        }

        Assert.Equal(3, zip.Entries.Count(e => e.FullName.StartsWith("households/1-Home/files/", StringComparison.Ordinal)));
        // An open invite's code still lets anyone in: it stays out of a file that is easily passed on.
        Assert.False(json.RootElement.GetProperty("invites")[0].TryGetProperty("code", out _));
        var weighing = json.RootElement.GetProperty("weights")[0];
        Assert.Equal(4.2m, weighing.GetProperty("weightKg").GetDecimal());
        Assert.Equal("home scale", weighing.GetProperty("note").GetString());
        Assert.False(weighing.TryGetProperty("clientRequestId", out _));
    }

    [Fact]
    public async Task A_file_storage_cant_give_doesnt_cut_the_export_short()
    {
        var client = api.ClientFor(Uid("missing"));
        var householdId = (await client.MeAsync()).Household.Id;
        var pet = await client.CreatePetAsync("Murka");
        var photo = await client.UploadPhotoAsync();
        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/photo", new SetPetPhotoRequest(photo.Id), Ct);
        var page = await client.UploadFileAsync(Pdf());
        await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.VaccinationCertificate, null, null, null, [page.Id]), Ct);
        await api.Services.GetRequiredService<ObjectStorage>().DeleteAsync($"{householdId}/{photo.Id}", Ct);

        var response = await client.GetAsync("/api/v1/me/export", Ct);
        await using var zip = new ZipArchive(new MemoryStream(await response.Content.ReadAsByteArrayAsync(Ct)));

        Assert.Equal(Pdf(), await ReadBytesAsync(zip, $"households/1-Home/files/{page.Id}.pdf"));
        Assert.Null(zip.GetEntry($"households/1-Home/files/{photo.Id}.jpg"));
        Assert.Equal($"files/{photo.Id}.jpg\n", await ReadAsync(zip, "households/1-Home/files-missing.txt"));
    }

    [Fact]
    public async Task Exports_are_limited_to_a_few_an_hour()
    {
        var client = api.ClientFor(Uid("often"));
        for (var i = 0; i < 5; i++)
        {
            Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/me/export", Ct)).StatusCode);
        }

        Assert.Equal(HttpStatusCode.TooManyRequests, (await client.GetAsync("/api/v1/me/export", Ct)).StatusCode);
    }

    [Theory]
    [InlineData("Home", "Home")]
    [InlineData("Мой дом", "Мой-дом")]
    [InlineData("  Office / 3rd floor!  ", "Office-3rd-floor")]
    [InlineData("🐈", "household")]
    public void A_household_name_becomes_a_folder_name(string name, string folder) =>
        Assert.Equal(folder, AccountExport.FolderName(name));

    private static async Task<string> ReadAsync(ZipArchive zip, string path)
    {
        using var reader = new StreamReader(zip.GetEntry(path)!.Open());
        return await reader.ReadToEndAsync(Ct);
    }

    private static async Task<byte[]> ReadBytesAsync(ZipArchive zip, string path)
    {
        await using var stream = zip.GetEntry(path)!.Open();
        using var copy = new MemoryStream();
        await stream.CopyToAsync(copy, Ct);
        return copy.ToArray();
    }
}
