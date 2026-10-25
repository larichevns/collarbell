using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Microchip numbers read by AI from a photo of a passport page or a chip sticker, for the pet form (FakeAi plays the model).</summary>
[Collection(ApiCollection.Name)]
public sealed class IdentifierScanTests : IDisposable
{
    /// <summary>The "PET IDENTITY" page of a passport: a Code 128 sticker with the digits under it, the place written by hand.</summary>
    private const string StickerAnswer = """
        {
          "identifiers": [
            {
              "type": "IsoChip", "code": "643 094 100 000 001", "appliedOn": null, "location": " BETWEEN SHOULDER BLADE ",
              "evidence": "Microchip No. 643094100000001", "page": 1
            }
          ]
        }
        """;

    private readonly ApiFactory _api;

    public IdentifierScanTests(ApiFactory api)
    {
        _api = api;
        _api.Ai.Reset();
    }

    public void Dispose() => _api.Ai.Reset();

    private static Task<HttpResponseMessage> ScanAsync(HttpClient client, List<Guid> photos) =>
        client.PostAsJsonAsync("/api/v1/pets/identifiers/scan", new IdentifierScanRequest(photos), Json, Ct);

    private static async Task<IdentifierScanResponse> ReadOf(HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<IdentifierScanResponse>(Json, Ct))!;
    }

    [Fact]
    public async Task A_sticker_gives_the_iso_number_and_where_the_chip_is()
    {
        var client = _api.ClientFor($"chip-scan-sticker-{Guid.NewGuid():N}");
        var photo = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => StickerAnswer;

        var read = await ReadOf(await ScanAsync(client, [photo.Id]));

        Assert.Equal(
            new IdentifierReading(IdentifierType.IsoChip, "643094100000001", "643 094 100 000 001", null, "BETWEEN SHOULDER BLADE", null),
            Assert.Single(read.Identifiers));
        Assert.Equal("fake-a", read.Model);
        // Counted in the month's AI use under its own name.
        var household = (await client.MeAsync()).Household.Id;
        await _api.ChangeDatabaseAsync(async db => Assert.Equal(
            ["identifier-scan"], await db.AiUsage.Where(u => u.HouseholdId == household).Select(u => u.Feature).ToListAsync(Ct)));
        // Nothing is saved, and the photo isn't used up: it is deleted with other unused uploads after a day.
        Assert.Equal(HttpStatusCode.OK, (await ScanAsync(client, [photo.Id])).StatusCode);
    }

    [Fact]
    public async Task Several_numbers_come_back_with_what_saving_would_refuse()
    {
        var client = _api.ClientFor($"chip-scan-several-{Guid.NewGuid():N}");
        var page = await client.UploadPhotoAsync();
        var future = Today.AddDays(2).ToString("yyyy-MM-dd");
        _api.Ai.Answer = _ => $$"""
            {
              "identifiers": [
                {
                  "type": "IsoChip", "code": "276098100123456", "page": 1, "evidence": null,
                  "appliedOn": {"raw": "14.08.2021", "iso": "2021-08-14", "order": "DayMonthYear"}, "location": null
                },
                {
                  "type": "LegacyChip", "code": "0a1b2c3d4e", "page": 1, "evidence": null, "location": "{{new string('x', 61)}}",
                  "appliedOn": {"raw": "{{future}}", "iso": "{{future}}", "order": "YearMonthDay"}
                },
                { "type": "IsoChip", "code": "27609810012345", "page": 1, "evidence": null, "appliedOn": null, "location": null },
                { "type": "Tattoo", "code": "ABC 123", "page": 1, "evidence": null, "appliedOn": null, "location": "Right ear" },
                { "type": "IsoChip", "code": "276-098-100-123-456", "page": 1, "evidence": null, "appliedOn": null, "location": "Left side of the neck" },
                { "type": "IsoChip", "code": null, "page": 1, "evidence": "smudged", "appliedOn": null, "location": null }
              ]
            }
            """;

        var read = await ReadOf(await ScanAsync(client, [page.Id]));

        Assert.Equal(
        [
            // Read twice (the sticker and the handwriting): one entry, with the place from the second.
            new IdentifierReading(IdentifierType.IsoChip, "276098100123456", "276098100123456", new DateOnly(2021, 8, 14), "Left side of the neck", null),
            // A date in the future and a place longer than the form takes are left out.
            new IdentifierReading(IdentifierType.LegacyChip, "0A1B2C3D4E", "0a1b2c3d4e", null, null, null),
            // A digit short: kept, with the pet form's words for it.
            new IdentifierReading(IdentifierType.IsoChip, "27609810012345", "27609810012345", null, null, "An ISO microchip number has 15 digits."),
            new IdentifierReading(IdentifierType.Tattoo, "ABC123", "ABC 123", null, "Right ear", null),
        ], read.Identifiers);
    }

    [Fact]
    public async Task No_number_on_the_photo_is_an_empty_list()
    {
        var client = _api.ClientFor($"chip-scan-none-{Guid.NewGuid():N}");
        var photo = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => """{"identifiers": []}""";

        var read = await ReadOf(await ScanAsync(client, [photo.Id]));

        Assert.Empty(read.Identifiers);
    }

    [Fact]
    public async Task A_scan_needs_ai_and_one_to_three_photos_of_ones_own()
    {
        var client = _api.ClientFor($"chip-scan-invalid-{Guid.NewGuid():N}");
        var photos = new List<Guid>();
        for (var i = 0; i < 4; i++)
        {
            photos.Add((await client.UploadPhotoAsync()).Id);
        }

        var pdf = await client.UploadFileAsync(Pdf());

        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(client, [])).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(client, photos)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(client, [Guid.NewGuid()])).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(client, [pdf.Id])).StatusCode);
        // Someone else's photo is not free to use.
        var stranger = _api.ClientFor($"chip-scan-stranger-{Guid.NewGuid():N}");
        Assert.Equal(HttpStatusCode.BadRequest, (await ScanAsync(stranger, [photos[0]])).StatusCode);
        Assert.Empty(_api.Ai.Asked);

        _api.Ai.Configured = false;
        Assert.Equal(HttpStatusCode.Conflict, (await ScanAsync(client, [photos[0]])).StatusCode);
    }

    [Fact]
    public async Task Busy_models_are_a_503_without_the_providers_words()
    {
        var client = _api.ClientFor($"chip-scan-busy-{Guid.NewGuid():N}");
        var photo = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => throw new HttpRequestException("high demand at 10.0.0.5:8080", null, HttpStatusCode.ServiceUnavailable);

        var response = await ScanAsync(client, [photo.Id]);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(["fake-a", "fake-b", "fake-c"], _api.Ai.Asked);
        Assert.DoesNotContain("10.0.0.5", await response.Content.ReadAsStringAsync(Ct), StringComparison.Ordinal);
    }

    [Fact]
    public async Task A_refused_request_is_a_502_without_trying_other_models()
    {
        var client = _api.ClientFor($"chip-scan-refused-{Guid.NewGuid():N}");
        var photo = await client.UploadPhotoAsync();
        _api.Ai.Answer = _ => throw new HttpRequestException("API key not valid for project collarbell-dev", null, HttpStatusCode.Forbidden);

        var response = await ScanAsync(client, [photo.Id]);

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        Assert.Equal(["fake-a"], _api.Ai.Asked);
        Assert.DoesNotContain("collarbell-dev", await response.Content.ReadAsStringAsync(Ct), StringComparison.Ordinal);
    }
}
