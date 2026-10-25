using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Supplies;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Photos of a package read by AI into a draft of a supply item (FakeAi plays the model).</summary>
[Collection(ApiCollection.Name)]
public sealed class ProductScanTests : IDisposable
{
    private const string FoodAnswer = """
        {
          "isPetProduct": true, "name": " Sterilised 37 ", "brand": "Royal Canin", "category": "DryFood",
          "packageAmount": 2, "packageUnit": "Kilogram", "energyValue": 386, "energyUnit": "KcalPer100g",
          "barcode": null, "species": "Cat", "treatment": null, "protectionWeeks": null, "dosesInPackage": null,
          "evidence": "ROYAL CANIN Sterilised 37 · 2 kg · 386 kcal/100 g"
        }
        """;

    private const string MedicineAnswer = """
        {
          "isPetProduct": true, "name": "Bravecto Spot-On", "brand": "MSD", "category": null,
          "packageAmount": null, "packageUnit": null, "energyValue": null, "energyUnit": null,
          "barcode": "4006381333931", "species": "Cat", "treatment": "FleaTick", "protectionWeeks": 12, "dosesInPackage": 1,
          "evidence": "Bravecto Spot-On for cats, protection 12 weeks, 1 pipette"
        }
        """;

    private readonly ApiFactory _api;

    public ProductScanTests(ApiFactory api)
    {
        _api = api;
        _api.Ai.Reset();
    }

    public void Dispose() => _api.Ai.Reset();

    private static Task<HttpResponseMessage> ScanAsync(HttpClient client, List<Guid> photos, string? barcode = null) =>
        client.PostAsJsonAsync("/api/v1/products/scan", new ProductScanRequest(photos, barcode), Json, Ct);

    private static async Task<ProductDraft> DraftOf(HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<ProductScanResponse>(Json, Ct))!.Product;
    }

    [Fact]
    public async Task A_bag_of_food_becomes_a_draft_in_grams_and_kcal_per_kg()
    {
        var client = _api.ClientFor($"product-scan-food-{Guid.NewGuid():N}");
        var front = await client.UploadPhotoAsync();
        var back = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => FoodAnswer;

        var draft = await DraftOf(await ScanAsync(client, [front.Id, back.Id], barcode: "036000291452"));

        Assert.Equal(new ProductDraft(true, "Sterilised 37", "Royal Canin", SupplyCategory.DryFood, SupplyUnit.Gram, 2000, 3860,
            "0036000291452", ProductSpecies.Cat, null, null, null, "ROYAL CANIN Sterilised 37 · 2 kg · 386 kcal/100 g"), draft);
    }

    [Fact]
    public async Task A_medicine_says_what_it_treats_and_how_long_it_protects()
    {
        var client = _api.ClientFor($"product-scan-medicine-{Guid.NewGuid():N}");
        var photo = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => MedicineAnswer;

        var draft = await DraftOf(await ScanAsync(client, [photo.Id]));

        Assert.Equal((SupplyCategory.Medication, SupplyUnit.Dose, 1m, "4006381333931"),
            (draft.Category!.Value, draft.Unit!.Value, draft.PackageSize!.Value, draft.Barcode));
        Assert.Equal((CareKind.FleaTick, 12, 1), (draft.Treatment!.Value, draft.ProtectionWeeks!.Value, draft.DosesInPackage!.Value));
    }

    [Fact]
    public async Task The_scanned_barcode_wins_over_digits_read_on_a_photo()
    {
        var client = _api.ClientFor($"product-scan-barcode-{Guid.NewGuid():N}");
        var photo = await client.UploadPhotoAsync();
        // The photo shows another code (a pouch inside the box, or two digits swapped).
        _api.Ai.Answer = _ => MedicineAnswer;

        var draft = await DraftOf(await ScanAsync(client, [photo.Id], barcode: "036000291452"));

        Assert.Equal("0036000291452", draft.Barcode);
    }

    [Fact]
    public async Task A_scan_needs_ai_and_one_to_three_photos()
    {
        var client = _api.ClientFor($"product-scan-invalid-{Guid.NewGuid():N}");
        var photos = new List<Guid>();
        for (var i = 0; i < 4; i++)
        {
            photos.Add((await client.UploadPhotoAsync()).Id);
        }

        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(client, [])).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(client, photos)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(client, [photos[0]], barcode: "not a barcode")).StatusCode);
        // Someone else's photo is not free to use.
        var stranger = _api.ClientFor($"product-scan-stranger-{Guid.NewGuid():N}");
        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(stranger, [photos[0]])).StatusCode);

        _api.Ai.Configured = false;
        Assert.Equal(HttpStatusCode.Conflict, (await ScanAsync(client, [photos[0]])).StatusCode);
    }

    [Fact]
    public async Task Busy_models_are_a_503_without_the_providers_words()
    {
        var client = _api.ClientFor($"product-scan-busy-{Guid.NewGuid():N}");
        var photo = await client.UploadPhotoAsync();
        // Every model answers something that isn't the JSON asked for.
        _api.Ai.Answer = _ => "I can't help with that.";

        var response = await ScanAsync(client, [photo.Id]);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(["fake-a", "fake-b", "fake-c"], _api.Ai.Asked);
        Assert.DoesNotContain("can't help", await response.Content.ReadAsStringAsync(Ct));
    }
}
