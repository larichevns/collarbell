using System.ComponentModel;
using System.Text.Json.Serialization;
using Collarbell.Api.Modules.Care;

namespace Collarbell.Api.Modules.Supplies;

// What the model must return for photos of a product package. The [Description] texts go into the JSON schema that is
// sent with the request, so they are instructions for the model, not documentation for us.

[JsonConverter(typeof(JsonStringEnumConverter<PackageUnit>))]
public enum PackageUnit
{
    Gram,
    Kilogram,
    Milliliter,
    Liter,
    Piece,
    Dose,
}

[JsonConverter(typeof(JsonStringEnumConverter<EnergyUnit>))]
public enum EnergyUnit
{
    KcalPerKg,
    KcalPer100g,
    KjPer100g,
    MjPerKg,
}

[JsonConverter(typeof(JsonStringEnumConverter<ProductSpecies>))]
public enum ProductSpecies
{
    Cat,
    Dog,
    CatAndDog,
    Other,
}

[JsonConverter(typeof(JsonStringEnumConverter<TreatmentKind>))]
public enum TreatmentKind
{
    FleaTick,
    Deworming,
    Heartworm,
    Other,
}

public sealed record ProductScan(
    [property: Description("Whether the photos show a product for pets: food, treats, litter or a medicine. False for anything else.")]
    bool IsPetProduct,
    [property: Description("The product name as printed, without the brand, e.g. \"Sterilised 37\". Null if not readable.")]
    string? Name,
    [property: Description("The brand as printed, e.g. \"Royal Canin\".")]
    string? Brand,
    [property: Description("What kind of product it is. Flea, tick and worm treatments are Medication.")]
    SupplyCategory? Category,
    [property: Description("How much one package holds, the number only: 2 for \"2 kg\", 85 for \"85 g\", 12 for a box of 12 pouches, 3 for 3 pipettes.")]
    decimal? PackageAmount,
    [property: Description("The unit of the package amount. A box of several pouches or cans is Piece; tablets and pipettes are Dose.")]
    PackageUnit? PackageUnit,
    [property: Description("The energy content as printed (metabolizable energy), the number only.")]
    decimal? EnergyValue,
    EnergyUnit? EnergyUnit,
    [property: Description("The digits printed under the barcode, if they are visible.")]
    string? Barcode,
    [property: Description("Which animals the product is for.")]
    ProductSpecies? Species,
    [property: Description("For medicines: what it treats.")]
    TreatmentKind? Treatment,
    [property: Description("For medicines: how many weeks one dose protects, if printed, e.g. 12 for \"protection for 12 weeks\", 4 for \"monthly\".")]
    int? ProtectionWeeks,
    [property: Description("For medicines: how many doses (tablets, pipettes) the package holds.")]
    int? DosesInPackage,
    [property: Description("The main text you read on the package (name, size, energy), to show the user where the details came from.")]
    string? Evidence);

/// <summary>
/// A product read from photos, checked and converted to what the supply form takes: grams and millilitres instead of
/// kilograms and litres, kcal per kg, the barcode as a GTIN. What isn't plausible is left out for the user to fill in.
/// <see cref="Treatment"/>, <see cref="ProtectionWeeks"/> and <see cref="DosesInPackage"/> describe a medicine, for
/// a treatment plan.
/// </summary>
public sealed record ProductDraft(
    bool IsPetProduct,
    string? Name,
    string? Brand,
    SupplyCategory? Category,
    SupplyUnit? Unit,
    decimal? PackageSize,
    int? KcalPerKg,
    string? Barcode,
    ProductSpecies? Species,
    CareKind? Treatment,
    int? ProtectionWeeks,
    int? DosesInPackage,
    string? Evidence)
{
    public static ProductDraft From(ProductScan scan, string? barcode)
    {
        var treatment = scan.Treatment switch
        {
            TreatmentKind.FleaTick => CareKind.FleaTick,
            TreatmentKind.Deworming => CareKind.Deworming,
            TreatmentKind.Heartworm => CareKind.Heartworm,
            _ => (CareKind?)null,
        };
        var category = scan.Category is { } c && Enum.IsDefined(c) ? c
            : treatment is not null ? SupplyCategory.Medication
            : (SupplyCategory?)null;
        var doses = scan.DosesInPackage is >= 1 and <= 1000 ? scan.DosesInPackage : null;
        var (unit, size) = Size(scan.PackageAmount, scan.PackageUnit);
        if (unit is null && category == SupplyCategory.Medication && doses is { } count)
        {
            (unit, size) = (SupplyUnit.Dose, count);
        }

        return new ProductDraft(
            scan.IsPetProduct,
            Clip(scan.Name, 100),
            Clip(scan.Brand, 100),
            category,
            unit,
            size,
            Kcal(scan.EnergyValue, scan.EnergyUnit),
            // The scanned code wins: digits read on a photo may be swapped, or be another pack's (a pouch in a box).
            Gtin.Normalize(barcode) ?? Gtin.Normalize(scan.Barcode?.Replace(" ", "", StringComparison.Ordinal)),
            scan.Species is { } species && Enum.IsDefined(species) ? species : null,
            treatment,
            scan.ProtectionWeeks is >= 1 and <= 104 ? scan.ProtectionWeeks : null,
            doses,
            Clip(scan.Evidence, 500));
    }

    private static (SupplyUnit? Unit, decimal? Size) Size(decimal? amount, PackageUnit? unit)
    {
        if (amount is not > 0)
        {
            return (null, null);
        }

        (SupplyUnit Unit, decimal Size)? size = unit switch
        {
            PackageUnit.Gram => (SupplyUnit.Gram, amount.Value),
            PackageUnit.Kilogram => (SupplyUnit.Gram, amount.Value * 1000),
            PackageUnit.Milliliter => (SupplyUnit.Milliliter, amount.Value),
            PackageUnit.Liter => (SupplyUnit.Milliliter, amount.Value * 1000),
            PackageUnit.Piece => (SupplyUnit.Piece, amount.Value),
            PackageUnit.Dose => (SupplyUnit.Dose, amount.Value),
            _ => null,
        };
        return size is { Size: <= 1_000_000 } plausible ? (plausible.Unit, Math.Round(plausible.Size, 3)) : (null, null);
    }

    /// <summary>kcal per kg: ×10 from per 100 g, kJ ÷ 4.184, MJ × 239 (spec A.6).</summary>
    private static int? Kcal(decimal? value, EnergyUnit? unit)
    {
        var perKg = (value, unit) switch
        {
            ( > 0, EnergyUnit.KcalPerKg) => value,
            ( > 0, EnergyUnit.KcalPer100g) => value * 10,
            ( > 0, EnergyUnit.KjPer100g) => value / 4.184m * 10,
            ( > 0, EnergyUnit.MjPerKg) => value * 239,
            _ => null,
        };
        return perKg is >= 1 and <= 10_000 ? (int)Math.Round(perKg.Value) : null;
    }

    private static string? Clip(string? text, int max)
    {
        var clean = text?.Trim();
        return string.IsNullOrEmpty(clean) ? null : clean.Length <= max ? clean : clean[..max].TrimEnd();
    }
}

public static class ProductScanPrompt
{
    /// <summary>Changes with every wording change, so answers can be compared before and after.</summary>
    public const string Version = "product-1";

    public const string Text = """
        The photos show the package of a product, usually for a cat or a dog: food, treats, litter, or a medicine
        against fleas, ticks or worms. Read what is printed and return it in the given JSON format.

        Rules:
        - Return only what is printed. If a value can't be read with certainty, return null. Never guess.
        - Keep the name and the brand as printed, in their language.
        - The package amount is what one package holds, not a feeding portion.
        - For the energy, take the metabolizable energy of the product as printed, with its unit.
        - For medicines, give what it treats, how long one dose protects and how many doses the package holds.
        """;
}
