using System.Text.Json;
using Collarbell.Api.Modules.Supplies;

namespace Collarbell.Api.Tests;

/// <summary>Scanned codes, package sizes, and the answers of the product databases.</summary>
public sealed class ProductCodesTests
{
    [Theory]
    [InlineData("4006381333931", "4006381333931")]
    // A UPC-A is the EAN-13 with a leading zero.
    [InlineData("036000291452", "0036000291452")]
    // A GTIN-14 starting with 0 is the EAN-13 inside it.
    [InlineData("04006381333931", "4006381333931")]
    [InlineData("96385074", "96385074")]
    // An EAN-8 padded with zeros, as a DataMatrix writes it.
    [InlineData("00000096385074", "96385074")]
    [InlineData(" 4006381333931 ", "4006381333931")]
    public void Barcodes_are_normalized(string raw, string gtin) => Assert.Equal(gtin, Gtin.Normalize(raw));

    [Theory]
    // Wrong check digit.
    [InlineData("4006381333932")]
    [InlineData("400638133393")]
    [InlineData("https://example.com/4006381333931")]
    [InlineData("")]
    [InlineData(null)]
    public void Not_a_barcode_is_refused(string? raw) => Assert.Null(Gtin.Normalize(raw));

    [Fact]
    public void A_medicine_datamatrix_gives_gtin_batch_and_expiry()
    {
        // GS1 DataMatrix as phones read it: fields one after another, the batch ended by a group separator.
        var code = ProductCodes.Parse("]d2010400638133393117271200\u001d10AB123\u001d21XYZ");

        Assert.Equal(new ScannedCode("4006381333931", "AB123", new DateOnly(2027, 12, 31)), code);
    }

    [Fact]
    public void The_bracketed_form_is_read_too()
    {
        var code = ProductCodes.Parse("(01)04006381333931(17)270615(10)L-2209");

        Assert.Equal(new ScannedCode("4006381333931", "L-2209", new DateOnly(2027, 6, 15)), code);
    }

    [Fact]
    public void A_plain_barcode_has_no_batch()
    {
        Assert.Equal(new ScannedCode("4006381333931", null, null), ProductCodes.Parse("4006381333931"));
        Assert.Null(ProductCodes.Parse("WIFI:S:home;T:WPA;P:secret;;"));
        Assert.Null(ProductCodes.Parse("0104006381333932"));
    }

    [Theory]
    [InlineData("2 kg", SupplyUnit.Gram, 2000)]
    [InlineData("400g", SupplyUnit.Gram, 400)]
    [InlineData("1,5 кг", SupplyUnit.Gram, 1500)]
    [InlineData("12 x 85 g", SupplyUnit.Gram, 1020)]
    [InlineData("500 ml", SupplyUnit.Milliliter, 500)]
    [InlineData("0.5 l", SupplyUnit.Milliliter, 500)]
    public void Package_sizes_are_read_as_printed(string text, SupplyUnit unit, decimal amount) =>
        Assert.Equal((unit, amount), PackageQuantity.Parse(text));

    [Fact]
    public void Open_pet_food_facts_answers_are_read()
    {
        using var json = JsonDocument.Parse("""
            {
              "code": "4006381333931",
              "status": 1,
              "product": {
                "product_name": "Sterilised 37",
                "product_name_ru": "Стерилайзд 37",
                "brands": "Royal Canin, Mars",
                "product_quantity": "2000",
                "product_quantity_unit": "g",
                "categories_tags": ["en:pet-food", "en:cat-food", "en:dry-cat-food"],
                "nutriments": { "energy-kcal_100g": 386 }
              }
            }
            """);

        var ru = OpenPetFoodFactsDatabase.Parse(json.RootElement, "ru");
        var en = OpenPetFoodFactsDatabase.Parse(json.RootElement, "en");

        Assert.Equal(new ProductDetails("Стерилайзд 37", "Royal Canin", SupplyCategory.DryFood, SupplyUnit.Gram, 2000, 3860), ru);
        Assert.Equal("Sterilised 37", en!.Name);
    }

    [Fact]
    public void An_open_pet_food_facts_miss_is_no_product()
    {
        using var missing = JsonDocument.Parse("""{ "code": "4006381333931", "status": 0, "status_verbose": "product not found" }""");
        using var nameless = JsonDocument.Parse("""{ "status": 1, "product": { "brands": "Acme", "quantity": "12 x 85 g" } }""");

        Assert.Null(OpenPetFoodFactsDatabase.Parse(missing.RootElement, "en"));
        Assert.Null(OpenPetFoodFactsDatabase.Parse(nameless.RootElement, "en"));
    }

    [Fact]
    public void Upcitemdb_gives_name_and_brand()
    {
        using var json = JsonDocument.Parse("""
            { "code": "OK", "total": 1, "items": [ { "ean": "4006381333931", "title": "Cat Litter Clumping 10 L", "brand": "Catsan" } ] }
            """);
        using var none = JsonDocument.Parse("""{ "code": "OK", "total": 0, "items": [] }""");

        Assert.Equal(new ProductDetails("Cat Litter Clumping 10 L", "Catsan", null, null, null, null),
            UpcItemDbDatabase.Parse(json.RootElement));
        Assert.Null(UpcItemDbDatabase.Parse(none.RootElement));
    }
}
