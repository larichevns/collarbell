using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Collarbell.Api.Modules.Appointments;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Collarbell.Api.Modules.Supplies;
using SkiaSharp;

namespace Collarbell.Api.Tests;

/// <summary>Files and requests the tests share.</summary>
internal static class TestData
{
    public static CancellationToken Ct => TestContext.Current.CancellationToken;

    /// <summary>
    /// JSON as the API writes it, with enums as names. Our enums say so themselves; days of the week
    /// (<see cref="DayOfWeek"/>) come from .NET and need it said.
    /// </summary>
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { Converters = { new JsonStringEnumConverter() } };

    /// <summary>Today in a new household: dev users' households start in UTC.</summary>
    public static DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow);

    public static CarePlanRequest Plan(string title, DateOnly nextDueOn, int? every = null, IntervalUnit? unit = null,
        CareKind kind = CareKind.Other) =>
        new(kind, title, every, unit, nextDueOn, RemindOffsetsDays: null, DefaultProduct: null, Targets: null,
            PresetCode: null, Notes: null, Active: null, RequestId: null);

    public static CareRecordRequest Record(string title, CareKind kind, DateOnly performedOn) =>
        new(kind, title, performedOn, PerformedTime: null, Product: null, Manufacturer: null, BatchNumber: null,
            ValidFrom: null, ValidUntil: null, Targets: null, Clinic: null, Veterinarian: null, WeightKg: null,
            Details: null, Notes: null, RequestId: null);

    public static CompleteCarePlanRequest Done(DateOnly performedOn) =>
        new(performedOn, PerformedTime: null, Product: null, Manufacturer: null, BatchNumber: null, ValidFrom: null,
            ValidUntil: null, Clinic: null, Veterinarian: null, Notes: null, NextDueOn: null, RequestId: null);

    public static async Task<CarePlanResponse> CreatePlanAsync(this HttpClient client, Guid petId, CarePlanRequest request)
    {
        var response = await client.PostAsJsonAsync($"/api/v1/pets/{petId}/care-plans", request, Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<CarePlanResponse>(Ct))!;
    }

    public static async Task<CareRecordResponse> CreateRecordAsync(this HttpClient client, Guid petId, CareRecordRequest request)
    {
        var response = await client.PostAsJsonAsync($"/api/v1/pets/{petId}/care-records", request, Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<CareRecordResponse>(Ct))!;
    }

    public static RoutineRequest Feeding(params TimeOnly[] times) =>
        new(Kind: null, [.. times], Days: null, Food: null, Amount: null, Unit: null, Notes: null, Active: null, RequestId: null);

    public static async Task<RoutineResponse> CreateRoutineAsync(this HttpClient client, Guid petId, RoutineRequest request)
    {
        var response = await client.PostAsJsonAsync($"/api/v1/pets/{petId}/routines", request, Json, Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<RoutineResponse>(Json, Ct))!;
    }

    /// <summary>A 2 kg bag of dry food, counted from the feedings, with <paramref name="stock"/> grams there now.</summary>
    public static SupplyRequest Supply(string name, decimal packageSize = 2000, decimal? stock = null,
        SupplyCategory category = SupplyCategory.DryFood, SupplyUnit unit = SupplyUnit.Gram) =>
        new(name, Brand: null, Barcode: null, category, unit, packageSize, KcalPerKg: null, UsageMode: null,
            ManualDailyUsage: null, LeadTimeDays: null, StoreUrl: null, Notes: null, Active: null, InitialStock: stock,
            DataSource: null, RequestId: null);

    public static async Task<SupplyResponse> CreateSupplyAsync(this HttpClient client, SupplyRequest request)
    {
        var response = await client.PostAsJsonAsync("/api/v1/supplies", request, Json, Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<SupplyResponse>(Json, Ct))!;
    }

    public static async Task<SupplyResponse> GetSupplyAsync(this HttpClient client, Guid id) =>
        (await client.GetFromJsonAsync<SupplyResponse>($"/api/v1/supplies/{id}", Json, Ct))!;

    /// <summary>A purchase or a count; returns the item's new estimate.</summary>
    public static async Task<SupplyResponse> AddStockAsync(this HttpClient client, Guid supplyId, StockEventKind kind, decimal quantity)
    {
        var response = await client.PostAsJsonAsync($"/api/v1/supplies/{supplyId}/stock-events",
            new StockEventRequest(kind, quantity, RequestId: null), Json, Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<StockChangeResponse>(Json, Ct))!.Supply;
    }

    public static AppointmentRequest Visit(string title, DateOnly date, TimeOnly time, params Guid[] petIds) =>
        new(AppointmentType.Vet, title, date, time, DurationMinutes: null, Location: null, Notes: null, [.. petIds],
            RemindOffsetsMinutes: null, Status: null, RequestId: null);

    public static async Task<AppointmentResponse> CreateVisitAsync(this HttpClient client, AppointmentRequest request)
    {
        var response = await client.PostAsJsonAsync("/api/v1/appointments", request, Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<AppointmentResponse>(Ct))!;
    }

    /// <summary>Deletes the account as the app does: it looks at what would happen, then confirms that plan.</summary>
    public static async Task<HttpResponseMessage> DeleteAccountAsync(this HttpClient client)
    {
        var preview = await client.GetFromJsonAsync<AccountDeletionPreview>("/api/v1/me/deletion", Json, Ct);
        return await client.DeleteAsync($"/api/v1/me?plan={preview!.Plan}", Ct);
    }

    public static async Task<MeResponse> MeAsync(this HttpClient client) =>
        (await client.GetFromJsonAsync<MeResponse>("/api/v1/me", Ct))!;

    public static async Task SetTimeZoneAsync(this HttpClient client, string timeZone)
    {
        var response = await client.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest(null, null, timeZone), Ct);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    /// <summary>
    /// A time zone where it is about <paramref name="hour"/> o'clock now: tests of today's feeding need hours left
    /// in the day, whatever time the tests run.
    /// </summary>
    public static string ZoneWhereItIsAbout(int hour)
    {
        var offset = hour - DateTime.UtcNow.Hour;
        offset = offset > 14 ? offset - 24 : offset < -12 ? offset + 24 : offset;
        // Etc/GMT zones have the sign the other way round: Etc/GMT-3 is three hours ahead of UTC.
        return offset switch
        {
            0 => "Etc/GMT",
            > 0 => $"Etc/GMT-{offset}",
            _ => $"Etc/GMT+{-offset}",
        };
    }

    /// <summary>Registers a phone for pushes and returns its (new, unique) Firebase token.</summary>
    public static async Task<string> RegisterPhoneAsync(this HttpClient client)
    {
        var token = $"token-{Guid.NewGuid():N}";
        var response = await client.PutAsJsonAsync($"/api/v1/devices/{Guid.NewGuid()}",
            new RegisterDeviceRequest(DevicePlatform.Android, token, "1.0.0"), Ct);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return token;
    }

    public static PetRequest Pet(string name, Species species = Species.Cat) =>
        new(name, species, Breed: null, Sex.Unknown, BirthDate: null, BirthDateApproximate: false, Neutered: null,
            NeuteredOn: null, Color: null, Markings: null, Coat: null, Allergies: null, Notes: null, Status: null,
            Identifiers: null);

    public static async Task<PetResponse> CreatePetAsync(this HttpClient client, string name, Species species = Species.Cat)
    {
        var response = await client.PostAsJsonAsync("/api/v1/pets", Pet(name, species), Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<PetResponse>(Ct))!;
    }

    public static async Task<HttpResponseMessage> UploadAsync(this HttpClient client, byte[] content, string fileName = "upload.bin")
    {
        using var form = new MultipartFormDataContent();
        var file = new ByteArrayContent(content);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream"); // the API decides the type itself
        form.Add(file, "file", fileName);
        return await client.PostAsync("/api/v1/files", form, Ct);
    }

    public static async Task<FileLink> UploadFileAsync(this HttpClient client, byte[] content)
    {
        var response = await client.UploadAsync(content);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<FileLink>(Ct))!;
    }

    public static Task<FileLink> UploadPhotoAsync(this HttpClient client) => client.UploadFileAsync(Jpeg(640, 480));

    public static byte[] Jpeg(int width, int height, bool withExif = false)
    {
        var jpeg = Encode(width, height, SKEncodedImageFormat.Jpeg);
        return withExif ? InsertExif(jpeg) : jpeg;
    }

    public static byte[] Png(int width, int height) => Encode(width, height, SKEncodedImageFormat.Png);

    public static byte[] Pdf() => "%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n"u8.ToArray();

    public static bool HasExif(byte[] jpeg) => jpeg.AsSpan().IndexOf("Exif\0\0"u8) >= 0;

    private static byte[] Encode(int width, int height, SKEncodedImageFormat format)
    {
        using var bitmap = new SKBitmap(width, height);
        using (var canvas = new SKCanvas(bitmap))
        {
            canvas.Clear(SKColors.SeaGreen);
            using var paint = new SKPaint { Color = SKColors.Orange };
            canvas.DrawRect(0, 0, width / 2f, height / 2f, paint);
        }

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(format, 90);
        return data.ToArray();
    }

    /// <summary>Puts an EXIF block (with an empty TIFF directory) right after the JPEG start marker.</summary>
    private static byte[] InsertExif(byte[] jpeg)
    {
        byte[] tiff = [0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        var payload = "Exif\0\0"u8.ToArray().Concat(tiff).ToArray();
        var length = payload.Length + 2;
        byte[] segment = [0xFF, 0xE1, (byte)(length >> 8), (byte)length, .. payload];
        return [.. jpeg[..2], .. segment, .. jpeg[2..]];
    }
}
