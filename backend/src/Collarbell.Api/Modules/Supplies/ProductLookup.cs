using System.Globalization;
using System.Net;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Collarbell.Api.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Collarbell.Api.Modules.Supplies;

/// <summary>GTIN barcodes of products: EAN-13, UPC-A, EAN-8 and GTIN-14.</summary>
public static class Gtin
{
    /// <summary>
    /// The digits of a valid GTIN in their usual form: a UPC-A (12 digits) and a GTIN-14 starting with 0 become the
    /// EAN-13 they stand for, and an EAN-8 padded with zeros becomes the EAN-8, so one product has one code. Null when it
    /// isn't a GTIN or its check digit is wrong.
    /// </summary>
    public static string? Normalize(string? raw)
    {
        var digits = raw?.Trim();
        if (string.IsNullOrEmpty(digits) || !digits.All(char.IsAsciiDigit))
        {
            return null;
        }

        if (digits.Length == 12)
        {
            digits = "0" + digits;
        }
        else if (digits.Length == 14 && digits[0] == '0')
        {
            digits = digits[1..];
        }

        // An EAN-8 written in 13 digits (as a medicine's DataMatrix does): the EAN-8 itself, so both scans match.
        if (digits.Length == 13 && digits.StartsWith("00000", StringComparison.Ordinal))
        {
            digits = digits[5..];
        }

        return digits.Length is 8 or 13 or 14 && CheckDigitIsRight(digits) ? digits : null;
    }

    /// <summary>From the right, without the check digit, the digits are weighted 3, 1, 3, 1…</summary>
    private static bool CheckDigitIsRight(string digits)
    {
        var sum = 0;
        for (int i = digits.Length - 2, weight = 3; i >= 0; i--, weight = 4 - weight)
        {
            sum += (digits[i] - '0') * weight;
        }

        return (10 - (sum % 10)) % 10 == digits[^1] - '0';
    }
}

/// <summary>What a scanned code says: the product's GTIN, and for a medicine pack also its batch and expiry date.</summary>
public sealed record ScannedCode(string Gtin, string? Batch, DateOnly? ExpiresOn);

/// <summary>
/// Reads what a phone scanned: a plain barcode (EAN, UPC) or a GS1 DataMatrix as on medicine packs, which holds the GTIN
/// (01), the batch (10) and the expiry date (17) without any lookup (spec 5.5).
/// </summary>
public static partial class ProductCodes
{
    private const char GroupSeparator = '\u001d';

    /// <summary>Fixed-length GS1 fields found on medicine packs; the others end at a group separator.</summary>
    private static readonly Dictionary<string, int> FixedLength = new()
    {
        ["00"] = 18, ["01"] = 14, ["02"] = 14, ["11"] = 6, ["12"] = 6, ["13"] = 6, ["15"] = 6, ["16"] = 6, ["17"] = 6, ["20"] = 2,
    };

    private static readonly HashSet<string> VariableLength = ["10", "21", "22", "240", "241", "710", "711", "712", "713", "714"];

    public static ScannedCode? Parse(string? raw)
    {
        var text = raw?.Trim();
        if (string.IsNullOrEmpty(text) || text.Length > 200)
        {
            return null;
        }

        if (Gtin.Normalize(text) is { } plain)
        {
            return new ScannedCode(plain, null, null);
        }

        // Symbology identifiers some scanners put first: ]d2 GS1 DataMatrix, ]C1 GS1-128, ]Q3 GS1 QR, ]e0 GS1 DataBar.
        foreach (var prefix in (string[])["]d2", "]C1", "]Q3", "]e0"])
        {
            if (text.StartsWith(prefix, StringComparison.Ordinal))
            {
                text = text[prefix.Length..];
                break;
            }
        }

        text = text.TrimStart(GroupSeparator);
        var fields = text.StartsWith('(') ? Bracketed(text) : Plain(text);
        if (fields is null || !fields.TryGetValue("01", out var gtin14) || Gtin.Normalize(gtin14) is not { } gtin)
        {
            return null;
        }

        var batch = fields.GetValueOrDefault("10");
        return new ScannedCode(gtin, string.IsNullOrWhiteSpace(batch) ? null : batch, Expiry(fields.GetValueOrDefault("17")));
    }

    /// <summary><c>010950600013435217271231␝10ABC123</c>: fields one after another, variable ones ended by ␝.</summary>
    private static Dictionary<string, string>? Plain(string text)
    {
        var fields = new Dictionary<string, string>();
        var i = 0;
        while (i < text.Length)
        {
            if (text[i] == GroupSeparator)
            {
                i++;
                continue;
            }

            if (i + 2 > text.Length || !char.IsAsciiDigit(text[i]) || !char.IsAsciiDigit(text[i + 1]))
            {
                return null;
            }

            var ai = text.Substring(i, 2);
            if (FixedLength.TryGetValue(ai, out var length))
            {
                if (i + 2 + length > text.Length)
                {
                    return null;
                }

                fields[ai] = text.Substring(i + 2, length);
                i += 2 + length;
                continue;
            }

            var key = VariableLength.Contains(ai) ? ai
                : i + 3 <= text.Length && VariableLength.Contains(text.Substring(i, 3)) ? text.Substring(i, 3)
                : null;
            if (key is null)
            {
                // A field this reader doesn't know: what came before it is still good.
                return fields.Count > 0 ? fields : null;
            }

            var start = i + key.Length;
            var end = text.IndexOf(GroupSeparator, start);
            end = end < 0 ? text.Length : end;
            fields[key] = text[start..end];
            i = end;
        }

        return fields;
    }

    /// <summary><c>(01)09506000134352(17)271231(10)ABC123</c>: the human-readable form.</summary>
    private static Dictionary<string, string>? Bracketed(string text)
    {
        var fields = new Dictionary<string, string>();
        foreach (Match match in BracketedField().Matches(text))
        {
            fields[match.Groups[1].Value] = match.Groups[2].Value.Trim().Trim(GroupSeparator);
        }

        return fields.Count > 0 ? fields : null;
    }

    /// <summary>YYMMDD; day 00 means the last day of the month.</summary>
    private static DateOnly? Expiry(string? value)
    {
        if (value is not { Length: 6 } || !value.All(char.IsAsciiDigit))
        {
            return null;
        }

        var year = 2000 + int.Parse(value[..2], CultureInfo.InvariantCulture);
        var month = int.Parse(value[2..4], CultureInfo.InvariantCulture);
        var day = int.Parse(value[4..], CultureInfo.InvariantCulture);
        if (month is < 1 or > 12 || day > DateTime.DaysInMonth(year, month))
        {
            return null;
        }

        return new DateOnly(year, month, day == 0 ? DateTime.DaysInMonth(year, month) : day);
    }

    [GeneratedRegex(@"\((\d{2,4})\)([^(]*)")]
    private static partial Regex BracketedField();
}

/// <summary>Where a lookup found the product.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<ProductLookupSource>))]
public enum ProductLookupSource
{
    /// <summary>Our catalog of products users confirmed.</summary>
    Catalog,

    /// <summary>Open Pet Food Facts: shown with its attribution, the data is under the ODbL.</summary>
    OpenPetFoodFacts,

    /// <summary>UPCitemdb: a general product database, name and brand only.</summary>
    UpcItemDb,
}

/// <summary>What a product database knows about a product; any of it may be missing except the name.</summary>
public sealed record ProductDetails(
    string Name,
    string? Brand,
    SupplyCategory? Category,
    SupplyUnit? Unit,
    decimal? PackageSize,
    int? KcalPerKg);

/// <summary>An outside product database, looked up by GTIN.</summary>
public interface IProductDatabase
{
    ProductLookupSource Source { get; }

    /// <summary>The product, or null when the database doesn't know it. Throws when the database can't be reached.</summary>
    Task<ProductDetails?> FindAsync(string gtin, string locale, CancellationToken ct);
}

public sealed class ProductsOptions
{
    public bool OpenPetFoodFacts { get; set; } = true;

    public Uri OpenPetFoodFactsUrl { get; set; } = new("https://world.openpetfoodfacts.org/");

    /// <summary>The free trial API: 100 lookups a day, no key.</summary>
    public bool UpcItemDb { get; set; } = true;

    public Uri UpcItemDbUrl { get; set; } = new("https://api.upcitemdb.com/");

    /// <summary>Open Food Facts asks every app to name itself and a contact.</summary>
    public string UserAgent { get; set; } = "Collarbell/0.1 (+https://github.com/larichevns/collarbell)";

    /// <summary>How long one database may take: the user is waiting with the scanner open.</summary>
    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(6);
}

/// <summary>
/// Finds a product by barcode (spec 5.5): our catalog first, then Open Pet Food Facts, then UPCitemdb. A database that
/// is down or slow is skipped: the user can still take photos of the package or type the details.
/// </summary>
public sealed class ProductLookup(
    AppDbContext db,
    IEnumerable<IProductDatabase> databases,
    IOptions<ProductsOptions> options,
    TimeProvider clock,
    ILogger<ProductLookup> log)
{
    public async Task<(ProductDetails? Product, ProductLookupSource? Source)> FindAsync(string gtin, string locale, CancellationToken ct)
    {
        var known = await db.Products.AsNoTracking().SingleOrDefaultAsync(p => p.Barcode == gtin, ct);
        if (known is not null)
        {
            return (new ProductDetails(known.Name, known.Brand, known.Category, known.Unit, known.PackageSize, known.KcalPerKg),
                ProductLookupSource.Catalog);
        }

        foreach (var database in databases)
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(options.Value.Timeout);
            try
            {
                if (await database.FindAsync(gtin, locale, timeout.Token) is { } found)
                {
                    return (found, database.Source);
                }
            }
            catch (Exception e) when (!ct.IsCancellationRequested)
            {
                log.LogWarning(e, "Looking up {Gtin} in {Database} failed; trying the next one.", gtin, database.Source);
            }
        }

        return (null, null);
    }

    /// <summary>
    /// Adds the product of a saved item to the catalog, or counts one more confirmation of it. The first confirmed
    /// details stay: another household's item never overwrites them (its name may be its own words). Details from Open
    /// Pet Food Facts stay there (see <see cref="Product"/>). A failure only means the catalog misses this product.
    /// </summary>
    public async Task ConfirmAsync(SupplyItem item, SupplyDataSource source, CancellationToken ct)
    {
        if (item.Barcode is not { } barcode || source == SupplyDataSource.OpenPetFoodFacts)
        {
            return;
        }

        var now = clock.GetUtcNow();
        if (await CountAsync(barcode, now, ct))
        {
            return;
        }

        var product = new Product(barcode, now)
        {
            Name = item.Name,
            Brand = item.Brand,
            Category = item.Category,
            Unit = item.Unit,
            PackageSize = item.PackageSize,
            KcalPerKg = item.KcalPerKg,
            Source = source switch
            {
                SupplyDataSource.Ai => ProductSource.Ai,
                SupplyDataSource.UpcItemDb => ProductSource.UpcItemDb,
                _ => ProductSource.User,
            },
            ConfirmedCount = 1,
            UpdatedAt = now,
        };
        db.Products.Add(product);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // Another household saved the same product at the same moment: it is in the catalog, count this one.
            db.Entry(product).State = EntityState.Detached;
            await CountAsync(barcode, now, ct);
        }
    }

    /// <summary>One more confirmation of a product in the catalog, in one statement; false when it isn't there.</summary>
    private async Task<bool> CountAsync(string barcode, DateTimeOffset now, CancellationToken ct) =>
        await db.Products
            .Where(p => p.Barcode == barcode)
            .ExecuteUpdateAsync(s => s
                .SetProperty(p => p.ConfirmedCount, p => p.ConfirmedCount + 1)
                .SetProperty(p => p.UpdatedAt, now), ct) > 0;
}

/// <summary>Where the details of an item the user saves came from, for the catalog.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<SupplyDataSource>))]
public enum SupplyDataSource
{
    /// <summary>Typed by the user.</summary>
    Manual,

    Catalog,
    OpenPetFoodFacts,
    UpcItemDb,

    /// <summary>Read from photos of the package.</summary>
    Ai,
}

/// <summary>
/// Open Pet Food Facts (https://world.openpetfoodfacts.org), the open database of pet food. Free, no key; it asks for
/// an app name in the User-Agent. Its data is under the Open Database License, so the app shows where it came from.
/// </summary>
public sealed class OpenPetFoodFactsDatabase(HttpClient http) : IProductDatabase
{
    public ProductLookupSource Source => ProductLookupSource.OpenPetFoodFacts;

    public async Task<ProductDetails?> FindAsync(string gtin, string locale, CancellationToken ct)
    {
        using var response = await http.GetAsync(
            $"api/v2/product/{gtin}?fields=product_name,product_name_{locale},brands,quantity,product_quantity,product_quantity_unit,categories_tags,nutriments",
            ct);
        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }

        response.EnsureSuccessStatusCode();
        using var json = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
        return Parse(json.RootElement, locale);
    }

    /// <summary>The product of an API v2 answer, or null when it has none or no name.</summary>
    public static ProductDetails? Parse(JsonElement root, string locale)
    {
        if (!root.TryGetProperty("product", out var product) || product.ValueKind != JsonValueKind.Object
            || (root.TryGetProperty("status", out var status) && status.ValueKind == JsonValueKind.Number && status.GetInt32() != 1))
        {
            return null;
        }

        var name = Text(product, $"product_name_{locale}") ?? Text(product, "product_name");
        if (name is null)
        {
            return null;
        }

        var brand = Text(product, "brands")?.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
        var size = Quantity(product);
        return new ProductDetails(Clip(name, 100)!, Clip(brand, 100), Category(product), size?.Unit, size?.Amount, Kcal(product));
    }

    private static (SupplyUnit Unit, decimal Amount)? Quantity(JsonElement product)
    {
        // product_quantity is the total in grams or millilitres; quantity is the text on the pack ("2 kg", "12 x 85 g").
        if (Number(product, "product_quantity") is { } total and > 0)
        {
            var unit = Text(product, "product_quantity_unit")?.ToLowerInvariant();
            return unit is "ml" ? (SupplyUnit.Milliliter, total) : (SupplyUnit.Gram, total);
        }

        return PackageQuantity.Parse(Text(product, "quantity"));
    }

    private static SupplyCategory? Category(JsonElement product)
    {
        if (!product.TryGetProperty("categories_tags", out var tags) || tags.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var all = string.Join(' ', tags.EnumerateArray().Where(t => t.ValueKind == JsonValueKind.String).Select(t => t.GetString()));
        return all.Contains("litter", StringComparison.Ordinal) ? SupplyCategory.Litter
            : all.Contains("treat", StringComparison.Ordinal) || all.Contains("snack", StringComparison.Ordinal) ? SupplyCategory.Treats
            : all.Contains("wet", StringComparison.Ordinal) || all.Contains("canned", StringComparison.Ordinal) || all.Contains("pouch", StringComparison.Ordinal) ? SupplyCategory.WetFood
            : all.Contains("dry", StringComparison.Ordinal) || all.Contains("kibble", StringComparison.Ordinal) ? SupplyCategory.DryFood
            : null;
    }

    /// <summary>kcal per kg from "energy-kcal_100g", or from kJ per 100 g.</summary>
    private static int? Kcal(JsonElement product)
    {
        if (!product.TryGetProperty("nutriments", out var nutriments) || nutriments.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        var per100 = Number(nutriments, "energy-kcal_100g") ?? (Number(nutriments, "energy-kj_100g") ?? Number(nutriments, "energy_100g")) / 4.184m;
        return per100 is > 0 and < 1000 ? (int)Math.Round(per100.Value * 10) : null;
    }

    private static string? Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(value.GetString())
            ? value.GetString()!.Trim()
            : null;

    private static decimal? Number(JsonElement element, string name) =>
        !element.TryGetProperty(name, out var value) ? null
        : value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number) ? number
        : value.ValueKind == JsonValueKind.String && decimal.TryParse(value.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed) ? parsed
        : null;

    private static string? Clip(string? text, int max) => text is null ? null : text.Length <= max ? text : text[..max].TrimEnd();
}

/// <summary>
/// UPCitemdb (https://www.upcitemdb.com), a general database of retail products. The free trial API needs no key and
/// allows 100 lookups a day; it gives the name and brand, rarely a reliable size.
/// </summary>
public sealed class UpcItemDbDatabase(HttpClient http) : IProductDatabase
{
    public ProductLookupSource Source => ProductLookupSource.UpcItemDb;

    public async Task<ProductDetails?> FindAsync(string gtin, string locale, CancellationToken ct)
    {
        using var response = await http.GetAsync($"prod/trial/lookup?upc={gtin}", ct);
        if (response.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.BadRequest)
        {
            return null;
        }

        response.EnsureSuccessStatusCode();
        using var json = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
        return Parse(json.RootElement);
    }

    public static ProductDetails? Parse(JsonElement root)
    {
        if (!root.TryGetProperty("items", out var items) || items.ValueKind != JsonValueKind.Array || items.GetArrayLength() == 0)
        {
            return null;
        }

        var item = items[0];
        var title = item.TryGetProperty("title", out var t) && t.ValueKind == JsonValueKind.String ? t.GetString()?.Trim() : null;
        if (string.IsNullOrEmpty(title))
        {
            return null;
        }

        var brand = item.TryGetProperty("brand", out var b) && b.ValueKind == JsonValueKind.String ? b.GetString()?.Trim() : null;
        return new ProductDetails(title.Length <= 100 ? title : title[..100].TrimEnd(),
            string.IsNullOrEmpty(brand) ? null : brand.Length <= 100 ? brand : brand[..100], null, null, null, null);
    }
}

/// <summary>Package sizes as printed: "2 kg", "400g", "1,5 kg", "12 x 85 g", "500 ml", "0.5 l".</summary>
public static partial class PackageQuantity
{
    public static (SupplyUnit Unit, decimal Amount)? Parse(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return null;
        }

        var match = Size().Match(text.ToLowerInvariant());
        if (!match.Success
            || !decimal.TryParse(match.Groups["amount"].Value.Replace(',', '.'), NumberStyles.Number, CultureInfo.InvariantCulture, out var amount)
            || amount <= 0)
        {
            return null;
        }

        var count = match.Groups["count"].Success && int.TryParse(match.Groups["count"].Value, CultureInfo.InvariantCulture, out var n) && n > 0 ? n : 1;
        var (unit, factor) = match.Groups["unit"].Value switch
        {
            "kg" or "кг" => (SupplyUnit.Gram, 1000m),
            "g" or "gr" or "г" => (SupplyUnit.Gram, 1m),
            "l" or "л" => (SupplyUnit.Milliliter, 1000m),
            "cl" => (SupplyUnit.Milliliter, 10m),
            _ => (SupplyUnit.Milliliter, 1m),
        };
        return (unit, count * amount * factor);
    }

    [GeneratedRegex(@"(?:(?<count>\d+)\s*[x×х]\s*)?(?<amount>\d+(?:[.,]\d+)?)\s*(?<unit>kg|кг|gr|g|г|ml|мл|cl|l|л)\b")]
    private static partial Regex Size();
}

public static class ProductDatabasesSetup
{
    /// <summary>
    /// Open Pet Food Facts, then UPCitemdb, each with its own short timeout. Without the standard retries: the user is
    /// waiting, and a database that is down is simply skipped.
    /// </summary>
    public static IServiceCollection AddProductDatabases(this IServiceCollection services, IConfiguration configuration)
    {
        var section = configuration.GetSection("Products");
        services.Configure<ProductsOptions>(section);
        var options = section.Get<ProductsOptions>() ?? new ProductsOptions();
        // RemoveAllResilienceHandlers drops the retries ServiceDefaults adds to every client. It is still marked
        // "for evaluation" (EXTEXP0001); without it a 429 from UPCitemdb would be retried while the user waits.
#pragma warning disable EXTEXP0001
        if (options.OpenPetFoodFacts)
        {
            services.AddHttpClient<OpenPetFoodFactsDatabase>(http => Setup(http, options.OpenPetFoodFactsUrl, options))
                .RemoveAllResilienceHandlers();
            services.AddTransient<IProductDatabase>(sp => sp.GetRequiredService<OpenPetFoodFactsDatabase>());
        }

        if (options.UpcItemDb)
        {
            services.AddHttpClient<UpcItemDbDatabase>(http => Setup(http, options.UpcItemDbUrl, options))
                .RemoveAllResilienceHandlers();
            services.AddTransient<IProductDatabase>(sp => sp.GetRequiredService<UpcItemDbDatabase>());
        }
#pragma warning restore EXTEXP0001

        return services;
    }

    private static void Setup(HttpClient http, Uri baseAddress, ProductsOptions options)
    {
        http.BaseAddress = baseAddress;
        http.Timeout = options.Timeout;
        http.DefaultRequestHeaders.UserAgent.ParseAdd(options.UserAgent);
        http.DefaultRequestHeaders.Accept.ParseAdd("application/json");
    }
}
