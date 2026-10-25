using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Supplies;

[JsonConverter(typeof(JsonStringEnumConverter<SupplyCategory>))]
public enum SupplyCategory
{
    DryFood,
    WetFood,
    Treats,
    Litter,

    /// <summary>Flea and tick drops, dewormers and the like.</summary>
    Medication,

    Other,
}

/// <summary>What the package size and the stock are counted in.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<SupplyUnit>))]
public enum SupplyUnit
{
    Gram,
    Milliliter,
    Piece,

    /// <summary>A tablet, a pipette: one treatment.</summary>
    Dose,
}

/// <summary>Where the daily use comes from.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<SupplyUsageMode>))]
public enum SupplyUsageMode
{
    /// <summary>The portions of the feeding schedules that give this food (spec 5.3).</summary>
    Feeding,

    /// <summary>A daily use the user sets, e.g. "a bag of litter lasts 30 days".</summary>
    Manual,
}

[JsonConverter(typeof(JsonStringEnumConverter<StockEventKind>))]
public enum StockEventKind
{
    /// <summary>Bought: the quantity is added to what is left.</summary>
    Purchase,

    /// <summary>"About half a bag left": the quantity is what is left now, the new starting point.</summary>
    Adjustment,
}

/// <summary>
/// A food, litter or medication the household keeps in stock (spec 4, 5.3). Nobody weighs every portion, so the
/// stock is estimated: from the last count (<see cref="StockEvent"/>), the purchases since, and the daily use.
/// </summary>
public sealed class SupplyItem
{
    public const int DefaultLeadTimeDays = 5;

    private SupplyItem()
    {
    }

    public SupplyItem(Guid householdId, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public string Name { get; set; } = null!;

    public string? Brand { get; set; }

    /// <summary>The product's GTIN (EAN-13, UPC-A, EAN-8), digits only; one item per barcode in a household.</summary>
    public string? Barcode { get; set; }

    public SupplyCategory Category { get; set; }

    public SupplyUnit Unit { get; set; }

    /// <summary>How much one package holds, in <see cref="Unit"/>: 2000 for a 2 kg bag, 12 for a box of 12 pouches.</summary>
    public decimal PackageSize { get; set; }

    public int? KcalPerKg { get; set; }

    public SupplyUsageMode UsageMode { get; set; }

    /// <summary>The daily use in <see cref="Unit"/> when <see cref="UsageMode"/> is <see cref="SupplyUsageMode.Manual"/>.</summary>
    public decimal? ManualDailyUsage { get; set; }

    /// <summary>How many days before it runs out to remind to buy it: the time an order takes to arrive.</summary>
    public int LeadTimeDays { get; set; } = DefaultLeadTimeDays;

    /// <summary>Where it is bought, e.g. the product page of a shop.</summary>
    public string? StoreUrl { get; set; }

    public string? Notes { get; set; }

    /// <summary>An item no longer bought: kept with its history, without forecast reminders.</summary>
    public bool Active { get; set; } = true;

    /// <summary>The id the app gave the create request; a retry with the same id returns this item.</summary>
    public Guid? ClientRequestId { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>A purchase or a count of what is left (spec 4: "+2 bags", "about half a bag left").</summary>
public sealed class StockEvent
{
    private StockEvent()
    {
    }

    public StockEvent(Guid householdId, Guid supplyItemId, StockEventKind kind, decimal quantity, Guid createdBy, DateTimeOffset at)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        SupplyItemId = supplyItemId;
        Kind = kind;
        Quantity = quantity;
        CreatedBy = createdBy;
        At = at;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public Guid SupplyItemId { get; private set; }

    public StockEventKind Kind { get; private set; }

    /// <summary>In the item's unit: added for a purchase, what is left for an adjustment.</summary>
    public decimal Quantity { get; private set; }

    public DateTimeOffset At { get; private set; }

    /// <summary>Who entered it; null once their account is gone (the entry stays: the stock is the household's).</summary>
    public Guid? CreatedBy { get; private set; }

    /// <summary>The id the app gave the request; a retry with the same id doesn't count the purchase twice.</summary>
    public Guid? ClientRequestId { get; set; }
}

/// <summary>Where a catalog product's details came from.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<ProductSource>))]
public enum ProductSource
{
    /// <summary>Typed or corrected by a user.</summary>
    User,

    /// <summary>Found by barcode in UPCitemdb (name and brand only).</summary>
    UpcItemDb,

    /// <summary>Read from photos of the package by AI and checked by a user.</summary>
    Ai,
}

/// <summary>
/// The shared catalog of products users confirmed (spec 4): the next scan of the same barcode finds the product here,
/// without AI. Not personal data and not tied to a household. Open Pet Food Facts products aren't copied here: they are
/// looked up there every time and shown with its attribution (ODbL).
/// </summary>
public sealed class Product
{
    private Product()
    {
    }

    public Product(string barcode, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        Barcode = barcode;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    public string Barcode { get; private set; } = null!;

    public string Name { get; set; } = null!;

    public string? Brand { get; set; }

    public SupplyCategory Category { get; set; }

    public SupplyUnit Unit { get; set; }

    public decimal PackageSize { get; set; }

    public int? KcalPerKg { get; set; }

    public ProductSource Source { get; set; }

    /// <summary>How many times users saved an item with this product.</summary>
    public int ConfirmedCount { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }
}
