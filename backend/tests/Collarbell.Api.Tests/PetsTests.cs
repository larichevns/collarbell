using System.Net;
using System.Net.Http.Json;
using System.Text;
using Collarbell.Api.Modules.Pets;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class PetsTests(ApiFactory api)
{
    [Fact]
    public async Task New_household_has_no_pets()
    {
        var client = api.ClientFor($"empty-{Guid.NewGuid():N}");

        var pets = await client.GetFromJsonAsync<List<PetResponse>>("/api/v1/pets", Ct);

        Assert.NotNull(pets);
        Assert.Empty(pets);
    }

    [Fact]
    public async Task A_pet_can_be_added_changed_and_deleted()
    {
        var client = api.ClientFor($"crud-{Guid.NewGuid():N}");
        var request = Pet("  Murka ") with
        {
            Breed = "British Shorthair",
            Sex = Sex.Female,
            BirthDate = new DateOnly(2021, 5, 1),
            BirthDateApproximate = true,
            NeuteredOn = new DateOnly(2022, 1, 10),
            Coat = Coat.Lilac,
            Identifiers = [new PetIdentifierRequest(IdentifierType.IsoChip, "276 0981-0012 3456", new DateOnly(2021, 8, 1), null, "Left side of the neck")],
        };

        var created = await client.PostAsJsonAsync("/api/v1/pets", request, Ct);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var murka = (await created.Content.ReadFromJsonAsync<PetResponse>(Ct))!;
        Assert.Equal("Murka", murka.Name);
        Assert.Equal(Coat.Lilac, murka.Coat);
        Assert.True(murka.Neutered); // a neutering date means neutered
        Assert.True(murka.BirthDateApproximate);
        var chip = Assert.Single(murka.Identifiers);
        Assert.Equal("276098100123456", chip.Code);
        Assert.Equal("276 0981-0012 3456", chip.RawCode);
        Assert.Equal($"/api/v1/pets/{murka.Id}", created.Headers.Location?.ToString());

        var changed = await client.PutAsJsonAsync($"/api/v1/pets/{murka.Id}", request with
        {
            Name = "Murka II",
            Coat = null, // keeps the colour
            Status = PetStatus.Archived,
            Identifiers = [],
        }, Ct);
        var updated = (await changed.Content.ReadFromJsonAsync<PetResponse>(Ct))!;
        Assert.Equal("Murka II", updated.Name);
        Assert.Equal(Coat.Lilac, updated.Coat);
        Assert.Equal(PetStatus.Archived, updated.Status);
        Assert.Empty(updated.Identifiers);

        var fetched = await client.GetFromJsonAsync<PetResponse>($"/api/v1/pets/{murka.Id}", Ct);
        Assert.Equal("Murka II", fetched!.Name);

        var deleted = await client.DeleteAsync($"/api/v1/pets/{murka.Id}", Ct);
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/pets/{murka.Id}", Ct)).StatusCode);
    }

    [Fact]
    public async Task A_microchip_can_be_added_to_a_saved_pet()
    {
        var client = api.ClientFor($"addchip-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        var response = await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}", Pet("Murka") with
        {
            Identifiers = [new PetIdentifierRequest(IdentifierType.IsoChip, "276098100123456", null, null, null)],
        }, Ct);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("276098100123456",
            Assert.Single((await client.GetFromJsonAsync<PetResponse>($"/api/v1/pets/{pet.Id}", Ct))!.Identifiers).Code);
    }

    [Fact]
    public async Task New_pets_get_colours_no_other_pet_has()
    {
        var client = api.ClientFor($"coats-{Guid.NewGuid():N}");

        var coats = new List<Coat>();
        foreach (var name in new[] { "One", "Two", "Three" })
        {
            coats.Add((await client.CreatePetAsync(name)).Coat);
        }

        Assert.Equal(3, coats.Distinct().Count());
    }

    [Fact]
    public async Task Active_pets_come_first()
    {
        var client = api.ClientFor($"order-{Guid.NewGuid():N}");
        var first = await client.CreatePetAsync("First");
        await client.CreatePetAsync("Second");
        await client.PutAsJsonAsync($"/api/v1/pets/{first.Id}", Pet("First") with { Status = PetStatus.Archived }, Ct);

        var pets = await client.GetFromJsonAsync<List<PetResponse>>("/api/v1/pets", Ct);

        Assert.Equal(new[] { "Second", "First" }, pets!.Select(p => p.Name));
    }

    [Theory]
    [InlineData(IdentifierType.IsoChip, "27609810012345", "15 digits")]
    [InlineData(IdentifierType.IsoChip, "999000000001234", "test chips")]
    [InlineData(IdentifierType.LegacyChip, "12345", "AVID")]
    [InlineData(IdentifierType.Tattoo, "  ", "letters and digits")]
    public async Task Invalid_identifiers_are_rejected(IdentifierType type, string code, string message)
    {
        var client = api.ClientFor($"chips-{Guid.NewGuid():N}");

        var response = await client.PostAsJsonAsync("/api/v1/pets",
            Pet("Rex") with { Identifiers = [new PetIdentifierRequest(type, code, null, null, null)] }, Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync(Ct);
        Assert.Contains("identifiers[0].code", body, StringComparison.Ordinal);
        Assert.Contains(message, body, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(IdentifierType.LegacyChip, "0a1b2c3d4e", "0A1B2C3D4E")]
    [InlineData(IdentifierType.LegacyChip, "123-456-789", "123456789")]
    [InlineData(IdentifierType.Tattoo, "abc 123", "ABC123")]
    public async Task Valid_identifiers_are_normalized(IdentifierType type, string code, string normalized)
    {
        var client = api.ClientFor($"norm-{Guid.NewGuid():N}");

        var response = await client.PostAsJsonAsync("/api/v1/pets",
            Pet("Rex") with { Identifiers = [new PetIdentifierRequest(type, code, null, null, null)] }, Ct);

        var pet = (await response.Content.ReadFromJsonAsync<PetResponse>(Ct))!;
        Assert.Equal(normalized, Assert.Single(pet.Identifiers).Code);
    }

    [Fact]
    public async Task Pet_fields_are_validated()
    {
        var client = api.ClientFor($"invalid-{Guid.NewGuid():N}");
        var future = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(3));

        var response = await client.PostAsJsonAsync("/api/v1/pets", Pet(" ") with
        {
            BirthDate = future,
            Breed = new string('x', 101),
            Identifiers =
            [
                new PetIdentifierRequest(IdentifierType.IsoChip, "276098100123456", null, null, null),
                new PetIdentifierRequest(IdentifierType.IsoChip, "276 098 100 123 456", null, null, null),
            ],
        }, Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync(Ct);
        Assert.Contains("\"name\"", body, StringComparison.Ordinal);
        Assert.Contains("\"birthDate\"", body, StringComparison.Ordinal);
        Assert.Contains("\"breed\"", body, StringComparison.Ordinal);
        Assert.Contains("already in the list", body, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("""{"name":"X","species":"Cat","sex":"Unknown","birthDate":"2021-05-01T00:00:00Z","birthDateApproximate":false}""")]
    [InlineData("""{"name":"X","species":"Fish","sex":"Unknown","birthDateApproximate":false}""")]
    [InlineData("""{"name":""")]
    public async Task Unreadable_requests_get_400_not_500(string json)
    {
        var client = api.ClientFor($"unreadable-{Guid.NewGuid():N}");

        var response = await client.PostAsync("/api/v1/pets", new StringContent(json, Encoding.UTF8, "application/json"), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Enums_are_serialized_as_strings()
    {
        var client = api.ClientFor($"json-{Guid.NewGuid():N}");
        await client.PostAsJsonAsync("/api/v1/pets", Pet("Max", Species.Dog) with { Coat = Coat.Cocoa }, Ct);

        var json = await client.GetStringAsync("/api/v1/pets", Ct);

        Assert.Contains("\"species\":\"Dog\"", json, StringComparison.Ordinal);
        Assert.Contains("\"coat\":\"Cocoa\"", json, StringComparison.Ordinal);
        Assert.Contains("\"status\":\"Active\"", json, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Photo_can_be_set_replaced_and_removed()
    {
        var client = api.ClientFor($"photo-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Barsik");
        var first = await client.UploadPhotoAsync();

        var withPhoto = await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/photo", new SetPetPhotoRequest(first.Id), Ct);
        var photo = (await withPhoto.Content.ReadFromJsonAsync<PetResponse>(Ct))!.Photo;
        Assert.Equal(first.Id, photo?.Id);
        Assert.Equal(HttpStatusCode.OK, (await api.Storage.GetAsync(photo!.ThumbnailUrl, Ct)).StatusCode);

        var second = await client.UploadPhotoAsync();
        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/photo", new SetPetPhotoRequest(second.Id), Ct);
        await api.RunStorageCleanupAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(first.Url, Ct)).StatusCode); // the old photo is gone

        var removed = await client.DeleteAsync($"/api/v1/pets/{pet.Id}/photo", Ct);
        Assert.Equal(HttpStatusCode.NoContent, removed.StatusCode);
        Assert.Null((await client.GetFromJsonAsync<PetResponse>($"/api/v1/pets/{pet.Id}", Ct))!.Photo);
    }

    [Fact]
    public async Task A_pdf_or_a_used_file_is_not_a_photo()
    {
        var client = api.ClientFor($"notphoto-{Guid.NewGuid():N}");
        var murka = await client.CreatePetAsync("Murka");
        var barsik = await client.CreatePetAsync("Barsik");
        var pdf = await client.UploadFileAsync(Pdf());
        var photo = await client.UploadPhotoAsync();
        await client.PutAsJsonAsync($"/api/v1/pets/{murka.Id}/photo", new SetPetPhotoRequest(photo.Id), Ct);

        var pdfResponse = await client.PutAsJsonAsync($"/api/v1/pets/{barsik.Id}/photo", new SetPetPhotoRequest(pdf.Id), Ct);
        var usedResponse = await client.PutAsJsonAsync($"/api/v1/pets/{barsik.Id}/photo", new SetPetPhotoRequest(photo.Id), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, pdfResponse.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, usedResponse.StatusCode);
    }

    [Fact]
    public async Task Another_household_cannot_see_or_change_a_pet()
    {
        var anna = api.ClientFor($"anna-{Guid.NewGuid():N}");
        var oleg = api.ClientFor($"oleg-{Guid.NewGuid():N}");
        var murka = await anna.CreatePetAsync("Murka");
        var olegsPhoto = await oleg.UploadPhotoAsync();
        var annasPhoto = await anna.UploadPhotoAsync();
        var olegsPet = await oleg.CreatePetAsync("Rex", Species.Dog);

        Assert.DoesNotContain((await oleg.GetFromJsonAsync<List<PetResponse>>("/api/v1/pets", Ct))!, p => p.Id == murka.Id);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.GetAsync($"/api/v1/pets/{murka.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.PutAsJsonAsync($"/api/v1/pets/{murka.Id}", Pet("Mine"), Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.DeleteAsync($"/api/v1/pets/{murka.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await oleg.PutAsJsonAsync($"/api/v1/pets/{murka.Id}/photo", new SetPetPhotoRequest(olegsPhoto.Id), Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.DeleteAsync($"/api/v1/pets/{murka.Id}/photo", Ct)).StatusCode);
        // Oleg can't use Anna's upload either.
        Assert.Equal(HttpStatusCode.BadRequest,
            (await oleg.PutAsJsonAsync($"/api/v1/pets/{olegsPet.Id}/photo", new SetPetPhotoRequest(annasPhoto.Id), Ct)).StatusCode);

        Assert.Equal("Murka", (await anna.GetFromJsonAsync<PetResponse>($"/api/v1/pets/{murka.Id}", Ct))!.Name);
    }
}
