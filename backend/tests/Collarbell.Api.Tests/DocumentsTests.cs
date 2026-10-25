using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Pets;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class DocumentsTests(ApiFactory api)
{
    [Fact]
    public async Task Pages_are_added_and_removed_one_at_a_time()
    {
        var client = api.ClientFor($"docs-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page1 = await client.UploadPhotoAsync();
        var page2 = await client.UploadPhotoAsync();

        var created = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.PassportPage, null, null, null, [page1.Id, page2.Id]), Ct);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var document = (await created.Content.ReadFromJsonAsync<DocumentResponse>(Ct))!;
        Assert.Equal(new[] { page1.Id, page2.Id }, document.Pages.Select(p => p.Id));

        // Two phones add a page each, both working from the same old list: both pages stay.
        var page3 = await client.UploadPhotoAsync();
        var page4 = await client.UploadPhotoAsync();
        await client.PostAsJsonAsync($"/api/v1/documents/{document.Id}/pages", new AddPagesRequest([page3.Id]), Ct);
        var added = await client.PostAsJsonAsync($"/api/v1/documents/{document.Id}/pages", new AddPagesRequest([page4.Id]), Ct);
        Assert.Equal(new[] { page1.Id, page2.Id, page3.Id, page4.Id },
            (await added.Content.ReadFromJsonAsync<DocumentResponse>(Ct))!.Pages.Select(p => p.Id));

        // Changing the details doesn't touch the pages.
        var renamed = await client.PutAsJsonAsync($"/api/v1/documents/{document.Id}",
            new DocumentDetailsRequest(DocumentType.PassportPage, "Passport", new DateOnly(2024, 3, 1), "Issued in Berlin"), Ct);
        var details = (await renamed.Content.ReadFromJsonAsync<DocumentResponse>(Ct))!;
        Assert.Equal("Passport", details.Title);
        Assert.Equal(4, details.Pages.Count);

        // Removing a page deletes its file; the others stay.
        var removed = await client.DeleteAsync($"/api/v1/documents/{document.Id}/pages/{page1.Id}", Ct);
        Assert.Equal(HttpStatusCode.NoContent, removed.StatusCode);
        await api.RunStorageCleanupAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(page1.Url, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await api.Storage.GetAsync(page2.Url, Ct)).StatusCode);
        var remaining = await client.GetFromJsonAsync<DocumentResponse>($"/api/v1/documents/{document.Id}", Ct);
        Assert.Equal(new[] { page2.Id, page3.Id, page4.Id }, remaining!.Pages.Select(p => p.Id));

        // Removing the last page removes the document.
        foreach (var page in new[] { page2, page3, page4 })
        {
            await client.DeleteAsync($"/api/v1/documents/{document.Id}/pages/{page.Id}", Ct);
        }

        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/documents/{document.Id}", Ct)).StatusCode);
    }

    [Fact]
    public async Task A_whole_document_can_be_deleted_with_its_files()
    {
        var client = api.ClientFor($"docdel-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        var document = await CreateAsync(client, pet.Id, DocumentType.LabResult, null, page);

        var deleted = await client.DeleteAsync($"/api/v1/documents/{document.Id}", Ct);
        await api.RunStorageCleanupAsync();

        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/documents/{document.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(page.Url, Ct)).StatusCode);
    }

    [Fact]
    public async Task Documents_are_listed_newest_first_and_can_be_filtered_by_type()
    {
        var client = api.ClientFor($"list-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Rex", Species.Dog);
        await CreateAsync(client, pet.Id, DocumentType.LabResult, new DateOnly(2023, 1, 5));
        await CreateAsync(client, pet.Id, DocumentType.PassportPage, null);
        await CreateAsync(client, pet.Id, DocumentType.Invoice, new DateOnly(2025, 6, 1));

        var all = await client.GetFromJsonAsync<List<DocumentResponse>>($"/api/v1/pets/{pet.Id}/documents", Ct);
        var passport = await client.GetFromJsonAsync<List<DocumentResponse>>($"/api/v1/pets/{pet.Id}/documents?type=PassportPage", Ct);

        // Without its own date a document counts as dated the day it was added (today).
        Assert.Equal(new[] { DocumentType.PassportPage, DocumentType.Invoice, DocumentType.LabResult }, all!.Select(d => d.Type));
        Assert.Equal(DocumentType.PassportPage, Assert.Single(passport!).Type);
    }

    [Fact]
    public async Task A_file_is_a_page_of_one_document_only()
    {
        var client = api.ClientFor($"once-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var page = await client.UploadPhotoAsync();
        await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.Other, null, null, null, [page.Id]), Ct);

        var again = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.Other, null, null, null, [page.Id]), Ct);
        var twice = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.Other, null, null, null, [Guid.NewGuid(), Guid.NewGuid()]), Ct);
        var empty = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/documents",
            new DocumentRequest(DocumentType.Other, null, null, null, []), Ct);
        var document = await CreateAsync(client, pet.Id, DocumentType.Other, null);
        var addUsed = await client.PostAsJsonAsync($"/api/v1/documents/{document.Id}/pages", new AddPagesRequest([page.Id]), Ct);
        var addAgain = await client.PostAsJsonAsync($"/api/v1/documents/{document.Id}/pages",
            new AddPagesRequest([document.Pages[0].Id]), Ct); // a retry of a page already there just succeeds
        var addNothing = await client.PostAsJsonAsync($"/api/v1/documents/{document.Id}/pages", new AddPagesRequest([]), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, again.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, twice.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, addUsed.StatusCode);
        Assert.Equal(HttpStatusCode.OK, addAgain.StatusCode);
        Assert.Single((await addAgain.Content.ReadFromJsonAsync<DocumentResponse>(Ct))!.Pages);
        Assert.Equal(HttpStatusCode.BadRequest, addNothing.StatusCode);
    }

    [Fact]
    public async Task Deleting_a_pet_deletes_its_documents_and_files()
    {
        var client = api.ClientFor($"petdel-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var photo = await client.UploadPhotoAsync();
        var page = await client.UploadFileAsync(Pdf());
        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/photo", new SetPetPhotoRequest(photo.Id), Ct);
        var document = await CreateAsync(client, pet.Id, DocumentType.VaccinationCertificate, null, page);

        await client.DeleteAsync($"/api/v1/pets/{pet.Id}", Ct);
        await api.RunStorageCleanupAsync();

        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/documents/{document.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/files/{page.Id}/url", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(photo.Url, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(page.Url, Ct)).StatusCode);
    }

    [Fact]
    public async Task Another_household_cannot_see_or_change_documents()
    {
        var anna = api.ClientFor($"anna-{Guid.NewGuid():N}");
        var oleg = api.ClientFor($"oleg-{Guid.NewGuid():N}");
        var murka = await anna.CreatePetAsync("Murka");
        var document = await CreateAsync(anna, murka.Id, DocumentType.PassportPage, null);
        var annasUpload = await anna.UploadPhotoAsync();
        var rex = await oleg.CreatePetAsync("Rex", Species.Dog);
        var olegsUpload = await oleg.UploadPhotoAsync();
        var request = new DocumentRequest(DocumentType.Other, null, null, null, [olegsUpload.Id]);
        var details = new DocumentDetailsRequest(DocumentType.Other, "Mine", null, null);
        var pageId = document.Pages[0].Id;

        Assert.Equal(HttpStatusCode.NotFound, (await oleg.GetAsync($"/api/v1/pets/{murka.Id}/documents", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.PostAsJsonAsync($"/api/v1/pets/{murka.Id}/documents", request, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.GetAsync($"/api/v1/documents/{document.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.PutAsJsonAsync($"/api/v1/documents/{document.Id}", details, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.PostAsJsonAsync($"/api/v1/documents/{document.Id}/pages",
            new AddPagesRequest([olegsUpload.Id]), Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.DeleteAsync($"/api/v1/documents/{document.Id}/pages/{pageId}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await oleg.DeleteAsync($"/api/v1/documents/{document.Id}", Ct)).StatusCode);
        // Oleg can't attach Anna's upload to his own pet.
        Assert.Equal(HttpStatusCode.BadRequest, (await oleg.PostAsJsonAsync($"/api/v1/pets/{rex.Id}/documents",
            new DocumentRequest(DocumentType.Other, null, null, null, [annasUpload.Id]), Ct)).StatusCode);

        Assert.Single((await anna.GetFromJsonAsync<List<DocumentResponse>>($"/api/v1/pets/{murka.Id}/documents", Ct))!);
    }

    private static async Task<DocumentResponse> CreateAsync(
        HttpClient client, Guid petId, DocumentType type, DateOnly? date, FileLink? page = null)
    {
        page ??= await client.UploadPhotoAsync();
        var response = await client.PostAsJsonAsync($"/api/v1/pets/{petId}/documents",
            new DocumentRequest(type, null, date, null, [page.Id]), Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<DocumentResponse>(Ct))!;
    }
}
