using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Pets;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class PassportTests(ApiFactory api)
{
    [Fact]
    public async Task The_passport_is_empty_until_saved()
    {
        var client = api.ClientFor($"empty-passport-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        var passport = await client.GetFromJsonAsync<PassportResponse>($"/api/v1/pets/{pet.Id}/passport", Ct);

        Assert.Equal(pet.Id, passport!.PetId);
        Assert.Null(passport.PassportNumber);
        Assert.Empty(passport.Owners);
        Assert.Null(passport.UpdatedAt);
    }

    [Fact]
    public async Task The_passport_header_is_saved_cleaned_up()
    {
        var client = api.ClientFor($"passport-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var request = new PassportRequest(
            PassportModel.Eu2014,
            " de 01 234567 ",
            "de",
            new DateOnly(2021, 9, 1),
            new PassportContactDto("Dr. Weber", "Hauptstr. 1, Berlin", "+49 30 123", "praxis@example.com"),
            [new PassportContactDto("Anna", null, null, null), new PassportContactDto(" ", "", null, null)],
            null);

        var response = await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/passport", request, Ct);
        var saved = await client.GetFromJsonAsync<PassportResponse>($"/api/v1/pets/{pet.Id}/passport", Ct);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(PassportModel.Eu2014, saved!.Model);
        Assert.Equal("DE01234567", saved.PassportNumber);
        Assert.Equal("DE", saved.IssuingCountry);
        Assert.Equal("Dr. Weber", saved.Issuer?.Name);
        Assert.Equal("Anna", Assert.Single(saved.Owners).Name); // the empty owner is dropped
        Assert.NotNull(saved.UpdatedAt);
    }

    [Fact]
    public async Task Passport_fields_are_validated()
    {
        var client = api.ClientFor($"bad-passport-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var owner = new PassportContactDto("Owner", null, null, "not-an-email");

        var response = await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/passport",
            new PassportRequest(null, "№ 123", "DEU", DateOnly.FromDateTime(DateTime.UtcNow.AddDays(3)), null, [owner, owner, owner], null), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync(Ct);
        foreach (var field in new[] { "passportNumber", "issuingCountry", "issuedOn", "owners", "owners[0].email" })
        {
            Assert.Contains($"\"{field}\"", body, StringComparison.Ordinal);
        }
    }

    [Fact]
    public async Task Another_household_cannot_read_or_change_the_passport()
    {
        var anna = api.ClientFor($"anna-{Guid.NewGuid():N}");
        var oleg = api.ClientFor($"oleg-{Guid.NewGuid():N}");
        var pet = await anna.CreatePetAsync("Murka");
        var request = new PassportRequest(null, "X1", null, null, null, null, null);

        Assert.Equal(HttpStatusCode.NotFound, (await oleg.GetAsync($"/api/v1/pets/{pet.Id}/passport", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/passport", request, Ct)).StatusCode);
    }
}
