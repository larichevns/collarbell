using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>A pet's weight log (spec, "Вес"): weighings, and the weights vets noted in care records.</summary>
[Collection(ApiCollection.Name)]
public sealed class WeightTests(ApiFactory api)
{
    private static WeightRequest Weighing(DateOnly on, decimal kg) => new(on, kg, Bcs: null, BcsScale: null, Note: null, RequestId: null);

    private static async Task<WeightResponse> AddAsync(HttpClient client, Guid petId, WeightRequest request)
    {
        var response = await client.PostAsJsonAsync($"/api/v1/pets/{petId}/weights", request, Json, Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<WeightResponse>(Json, Ct))!;
    }

    private static async Task<List<WeightResponse>> LogAsync(HttpClient client, Guid petId) =>
        (await client.GetFromJsonAsync<List<WeightResponse>>($"/api/v1/pets/{petId}/weights", Json, Ct))!;

    private static async Task<IEnumerable<string>> ErrorFieldsAsync(HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<ValidationProblemDetails>(Json, Ct))!.Errors.Keys;
    }

    /// <summary><paramref name="uid"/> joins the owner's household with <paramref name="role"/>; the client works there.</summary>
    private async Task<HttpClient> JoinAsync(HttpClient owner, string uid, HouseholdRole role)
    {
        var householdId = (await owner.MeAsync()).Household.Id;
        var invite = await (await owner.PostAsJsonAsync("/api/v1/households/current/invites", new CreateInviteRequest(role), Json, Ct))
            .Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct);
        var person = api.ClientFor(uid, $"{uid}@example.com");
        Assert.Equal(HttpStatusCode.OK,
            (await person.PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(invite!.Code), Json, Ct)).StatusCode);
        person.DefaultRequestHeaders.Add(CurrentUserAccessor.HouseholdHeader, householdId.ToString());
        return person;
    }

    [Fact]
    public async Task A_weighing_is_added_changed_and_deleted()
    {
        var client = api.ClientFor($"weight-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        var added = await AddAsync(client, pet.Id, Weighing(Today.AddDays(-1), 4.2345m) with
        {
            Bcs = 5,
            BcsScale = 9,
            Note = "  after breakfast  ",
        });

        Assert.Equal(WeightSource.Weighing, added.Source);
        Assert.Equal(4.235m, added.WeightKg); // to the gram
        Assert.Equal(5, added.Bcs);
        Assert.Equal(9, added.BcsScale);
        Assert.Equal("after breakfast", added.Note);
        Assert.Equal(added.Id, Assert.Single(await LogAsync(client, pet.Id)).Id);

        var changed = await client.PutAsJsonAsync($"/api/v1/weights/{added.Id}", Weighing(Today, 4.3m), Json, Ct);

        Assert.Equal(HttpStatusCode.OK, changed.StatusCode);
        var weighing = (await client.GetFromJsonAsync<WeightResponse>($"/api/v1/weights/{added.Id}", Json, Ct))!;
        Assert.Equal((Today, 4.3m), (weighing.MeasuredOn, weighing.WeightKg));
        Assert.Null(weighing.Bcs);
        Assert.Null(weighing.Note);

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/v1/weights/{added.Id}", Ct)).StatusCode);
        Assert.Empty(await LogAsync(client, pet.Id));
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/weights/{added.Id}", Ct)).StatusCode);
    }

    [Fact]
    public async Task The_log_has_the_weights_vets_noted_newest_first()
    {
        var client = api.ClientFor($"weight-vet-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var older = await AddAsync(client, pet.Id, Weighing(Today.AddDays(-20), 4.1m));
        var newer = await AddAsync(client, pet.Id, Weighing(Today.AddDays(-3), 4.4m));
        var checkUp = await client.CreateRecordAsync(pet.Id, Record("Annual check-up", CareKind.VetExam, Today.AddDays(-10)) with
        {
            WeightKg = 4.25m,
        });
        // Only a check-up notes a weight: another kind of record keeps none, so none of them sits in the log unchangeable.
        var vaccination = await client.CreateRecordAsync(pet.Id, Record("Rabies", CareKind.Vaccination, Today.AddDays(-10)) with
        {
            WeightKg = 4.3m,
        });

        var log = await LogAsync(client, pet.Id);

        Assert.Null(vaccination.WeightKg);
        Assert.Equal([newer.Id, checkUp.Id, older.Id], log.Select(w => w.Id));
        var fromVet = log[1];
        Assert.Equal((WeightSource.CareRecord, 4.25m, "Annual check-up"), (fromVet.Source, fromVet.WeightKg, fromVet.Note));
        Assert.Equal(Today.AddDays(-10), fromVet.MeasuredOn);
        // It is changed in its record, not here.
        Assert.Equal(HttpStatusCode.NotFound, (await client.DeleteAsync($"/api/v1/weights/{checkUp.Id}", Ct)).StatusCode);

        // The record without its weight leaves the log.
        Assert.Equal(HttpStatusCode.OK, (await client.PutAsJsonAsync($"/api/v1/care-records/{checkUp.Id}",
            Record("Annual check-up", CareKind.VetExam, Today.AddDays(-10)), Json, Ct)).StatusCode);
        Assert.Equal([newer.Id, older.Id], (await LogAsync(client, pet.Id)).Select(w => w.Id));
    }

    [Fact]
    public async Task A_weighing_is_checked()
    {
        var client = api.ClientFor($"weight-check-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var url = $"/api/v1/pets/{pet.Id}/weights";

        async Task<IEnumerable<string>> RefusedAsync(WeightRequest request) =>
            await ErrorFieldsAsync(await client.PostAsJsonAsync(url, request, Json, Ct));

        Assert.Equal(["weightKg"], await RefusedAsync(Weighing(Today, 0)));
        Assert.Equal(["weightKg"], await RefusedAsync(Weighing(Today, 0.0004m))); // nothing left once kept to the gram
        Assert.Equal(["weightKg"], await RefusedAsync(Weighing(Today, 200.001m)));
        Assert.Equal(["measuredOn"], await RefusedAsync(Weighing(Today.AddDays(2), 4)));
        Assert.Equal(["measuredOn"], await RefusedAsync(Weighing(new DateOnly(1989, 12, 31), 4)));
        Assert.Equal(["bcsScale"], await RefusedAsync(Weighing(Today, 4) with { Bcs = 5 }));
        Assert.Equal(["bcs"], await RefusedAsync(Weighing(Today, 4) with { BcsScale = 9 }));
        Assert.Equal(["bcsScale"], await RefusedAsync(Weighing(Today, 4) with { Bcs = 5, BcsScale = 7 }));
        Assert.Equal(["bcs"], await RefusedAsync(Weighing(Today, 4) with { Bcs = 6, BcsScale = 5 }));
        Assert.Equal(["bcs"], await RefusedAsync(Weighing(Today, 4) with { Bcs = 0, BcsScale = 9 }));
        Assert.Equal(["note"], await RefusedAsync(Weighing(Today, 4) with { Note = new string('a', 501) }));
        Assert.Empty(await LogAsync(client, pet.Id));

        await AddAsync(client, pet.Id, Weighing(Today, 200));
        await AddAsync(client, pet.Id, Weighing(Today, 0.001m) with { Bcs = 3, BcsScale = 5 });
    }

    [Fact]
    public async Task A_weighing_cant_be_before_an_exact_birth_date()
    {
        var client = api.ClientFor($"weight-born-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var born = Today.AddMonths(-2);
        Assert.Equal(HttpStatusCode.OK, (await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}",
            Pet("Murka") with { BirthDate = born }, Ct)).StatusCode);

        var before = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/weights", Weighing(born.AddDays(-1), 0.1m), Json, Ct);

        Assert.Equal(["measuredOn"], await ErrorFieldsAsync(before));
        var weighing = await AddAsync(client, pet.Id, Weighing(born, 0.1m));
        Assert.Equal(["measuredOn"], await ErrorFieldsAsync(await client.PutAsJsonAsync($"/api/v1/weights/{weighing.Id}",
            Weighing(born.AddDays(-1), 0.1m), Json, Ct)));

        // "About two months old" says nothing for sure.
        Assert.Equal(HttpStatusCode.OK, (await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}",
            Pet("Murka") with { BirthDate = born, BirthDateApproximate = true }, Ct)).StatusCode);
        await AddAsync(client, pet.Id, Weighing(born.AddDays(-10), 0.1m));
    }

    [Fact]
    public async Task Another_households_pet_and_weighings_are_not_found()
    {
        var anna = api.ClientFor($"weight-anna-{Guid.NewGuid():N}");
        var boris = api.ClientFor($"weight-boris-{Guid.NewGuid():N}");
        var annasCat = await anna.CreatePetAsync("Murka");
        var weighing = await AddAsync(anna, annasCat.Id, Weighing(Today, 4));

        Assert.Equal(HttpStatusCode.NotFound, (await boris.GetAsync($"/api/v1/pets/{annasCat.Id}/weights", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await boris.PostAsJsonAsync($"/api/v1/pets/{annasCat.Id}/weights", Weighing(Today, 4), Json, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await boris.GetAsync($"/api/v1/weights/{weighing.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await boris.PutAsJsonAsync($"/api/v1/weights/{weighing.Id}", Weighing(Today, 5), Json, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await boris.DeleteAsync($"/api/v1/weights/{weighing.Id}", Ct)).StatusCode);
        Assert.Equal(4m, Assert.Single(await LogAsync(anna, annasCat.Id)).WeightKg);
    }

    [Fact]
    public async Task Helpers_see_the_log_but_dont_change_it()
    {
        var owner = api.ClientFor($"weight-owner-{Guid.NewGuid():N}");
        var pet = await owner.CreatePetAsync("Murka");
        var weighing = await AddAsync(owner, pet.Id, Weighing(Today, 4));
        var sitter = await JoinAsync(owner, $"weight-sitter-{Guid.NewGuid():N}", HouseholdRole.Helper);
        var member = await JoinAsync(owner, $"weight-member-{Guid.NewGuid():N}", HouseholdRole.Member);

        Assert.Single(await LogAsync(sitter, pet.Id));
        Assert.Equal(HttpStatusCode.Forbidden,
            (await sitter.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/weights", Weighing(Today, 4.1m), Json, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await sitter.PutAsJsonAsync($"/api/v1/weights/{weighing.Id}", Weighing(Today, 4.1m), Json, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await sitter.DeleteAsync($"/api/v1/weights/{weighing.Id}", Ct)).StatusCode);
        await AddAsync(member, pet.Id, Weighing(Today, 4.1m));
        Assert.Equal(2, (await LogAsync(owner, pet.Id)).Count);
    }

    [Fact]
    public async Task A_retried_weighing_is_added_once()
    {
        var client = api.ClientFor($"weight-retry-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var request = Weighing(Today, 4) with { RequestId = Guid.NewGuid() };

        var first = await AddAsync(client, pet.Id, request);
        var again = await AddAsync(client, pet.Id, request);
        var atOnce = await Task.WhenAll(
            Enumerable.Range(0, 3).Select(_ => AddAsync(client, pet.Id, request with { RequestId = Guid.NewGuid() })));
        var sameTwiceAtOnce = Weighing(Today, 5) with { RequestId = Guid.NewGuid() };
        var twins = await Task.WhenAll(AddAsync(client, pet.Id, sameTwiceAtOnce), AddAsync(client, pet.Id, sameTwiceAtOnce));

        Assert.Equal(first.Id, again.Id);
        Assert.Equal(3, atOnce.Select(w => w.Id).Distinct().Count());
        Assert.Equal(twins[0].Id, twins[1].Id);
        Assert.Equal(5, (await LogAsync(client, pet.Id)).Count);
    }

    [Fact]
    public async Task A_request_id_used_for_another_pet_is_refused()
    {
        var client = api.ClientFor($"weight-reuse-{Guid.NewGuid():N}");
        var murka = await client.CreatePetAsync("Murka");
        var rex = await client.CreatePetAsync("Rex", Species.Dog);
        var requestId = Guid.NewGuid();
        await AddAsync(client, murka.Id, Weighing(Today, 4.2m) with { RequestId = requestId });

        var forRex = await client.PostAsJsonAsync($"/api/v1/pets/{rex.Id}/weights",
            Weighing(Today, 31) with { RequestId = requestId }, Json, Ct);

        Assert.Equal(["requestId"], await ErrorFieldsAsync(forRex));
        Assert.Empty(await LogAsync(client, rex.Id));
    }

    [Fact]
    public async Task A_retry_gets_its_weighing_back_even_after_the_birth_date_changed()
    {
        var client = api.ClientFor($"weight-retry-born-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var request = Weighing(Today.AddDays(-20), 0.5m) with { RequestId = Guid.NewGuid() };
        var first = await AddAsync(client, pet.Id, request);
        // The kitten turns out to be ten days old: the old weighing can still be retried and changed without a new date.
        Assert.Equal(HttpStatusCode.OK, (await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}",
            Pet("Murka") with { BirthDate = Today.AddDays(-10) }, Ct)).StatusCode);

        Assert.Equal(first.Id, (await AddAsync(client, pet.Id, request)).Id);
        var noteFixed = await client.PutAsJsonAsync($"/api/v1/weights/{first.Id}",
            Weighing(first.MeasuredOn, 0.5m) with { Note = "before the vet" }, Json, Ct);
        Assert.Equal(HttpStatusCode.OK, noteFixed.StatusCode);
        // A new date is checked against it.
        Assert.Equal(["measuredOn"], await ErrorFieldsAsync(await client.PutAsJsonAsync($"/api/v1/weights/{first.Id}",
            Weighing(Today.AddDays(-15), 0.5m), Json, Ct)));
    }

    [Fact]
    public async Task Two_phones_deleting_or_changing_one_weighing_at_once_get_no_server_error()
    {
        var client = api.ClientFor($"weight-twice-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var answers = new List<HttpStatusCode>();
        for (var round = 0; round < 5; round++)
        {
            var weighing = await AddAsync(client, pet.Id, Weighing(Today, 4 + round));
            answers.AddRange((await Task.WhenAll(
                    client.DeleteAsync($"/api/v1/weights/{weighing.Id}", Ct),
                    client.DeleteAsync($"/api/v1/weights/{weighing.Id}", Ct),
                    client.PutAsJsonAsync($"/api/v1/weights/{weighing.Id}", Weighing(Today, 5), Json, Ct)))
                .Select(a => a.StatusCode));
        }

        Assert.All(answers, status => Assert.Contains(status, new[] { HttpStatusCode.NoContent, HttpStatusCode.OK, HttpStatusCode.NotFound }));
        Assert.Empty(await LogAsync(client, pet.Id));
    }

    [Fact]
    public async Task A_weighing_added_while_another_phone_deletes_the_pet_is_not_found()
    {
        var client = api.ClientFor($"weight-pet-gone-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        string connectionString = null!;
        await api.ChangeDatabaseAsync(db =>
        {
            connectionString = db.Database.GetConnectionString()!;
            return Task.CompletedTask;
        });
        // The other phone's deletion holds the pet's row until it commits.
        await using var otherPhone = new NpgsqlConnection(connectionString);
        await otherPhone.OpenAsync(Ct);
        await using var deletion = await otherPhone.BeginTransactionAsync(Ct);
        await using (var delete = new NpgsqlCommand("DELETE FROM pets.pets WHERE id = @id", otherPhone, deletion))
        {
            delete.Parameters.AddWithValue("id", pet.Id);
            Assert.Equal(1, await delete.ExecuteNonQueryAsync(Ct));
        }

        var adding = client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/weights", Weighing(Today, 4), Json, Ct);
        await Task.Delay(TimeSpan.FromSeconds(1), Ct); // it found the pet, and its insert waits on the pet's row
        await deletion.CommitAsync(Ct);

        Assert.Equal(HttpStatusCode.NotFound, (await adding).StatusCode);
    }

    [Fact]
    public async Task A_note_with_a_nul_character_is_kept_without_it()
    {
        var client = api.ClientFor($"weight-nul-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        var weighing = await AddAsync(client, pet.Id, Weighing(Today, 4.2m) with { Note = "after\u0000 breakfast" });
        var record = await client.CreateRecordAsync(pet.Id, Record("Check-up", CareKind.VetExam, Today) with { Notes = "a\u0000b" });

        Assert.Equal("after breakfast", weighing.Note);
        Assert.Equal("ab", record.Notes);
    }

    [Fact]
    public async Task A_vets_weight_is_kept_to_10_g_and_only_on_a_check_up()
    {
        var client = api.ClientFor($"weight-vet-round-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");

        var tooLight = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/care-records",
            Record("Check-up", CareKind.VetExam, Today) with { WeightKg = 0.004m }, Ct);
        var checkUp = await client.CreateRecordAsync(pet.Id, Record("Check-up", CareKind.VetExam, Today) with { WeightKg = 4.236m });
        // A weight left on a vaccination by an older version stays out of the log: nobody could change it there.
        await api.ChangeDatabaseAsync(async db =>
        {
            db.CareRecords.Add(new CareRecord(me.Household.Id, pet.Id, CareKind.Vaccination, "Rabies", Today.AddDays(-30), me.Id,
                DateTimeOffset.UtcNow) { WeightKg = 4.3m });
            await db.SaveChangesAsync(Ct);
        });

        Assert.Equal(HttpStatusCode.BadRequest, tooLight.StatusCode);
        Assert.Equal(4.24m, checkUp.WeightKg);
        Assert.Equal(4.24m, Assert.Single(await LogAsync(client, pet.Id)).WeightKg);
    }

    [Fact]
    public async Task Deleting_the_pet_deletes_its_weighings_and_a_deleted_account_leaves_them()
    {
        var owner = api.ClientFor($"weight-family-{Guid.NewGuid():N}");
        var murka = await owner.CreatePetAsync("Murka");
        var barsik = await owner.CreatePetAsync("Barsik");
        var memberUid = $"weight-leaver-{Guid.NewGuid():N}";
        var member = await JoinAsync(owner, memberUid, HouseholdRole.Member);
        var byMember = await AddAsync(member, murka.Id, Weighing(Today, 4));
        var gone = await AddAsync(owner, barsik.Id, Weighing(Today, 6));

        Assert.Equal(HttpStatusCode.NoContent, (await member.DeleteAccountAsync()).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await owner.DeleteAsync($"/api/v1/pets/{barsik.Id}", Ct)).StatusCode);

        Assert.Equal(byMember.Id, Assert.Single(await LogAsync(owner, murka.Id)).Id);
        await using var scope = api.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Null((await db.WeightEntries.SingleAsync(w => w.Id == byMember.Id, Ct)).CreatedBy);
        Assert.False(await db.WeightEntries.AnyAsync(w => w.Id == gone.Id, Ct));
    }
}
