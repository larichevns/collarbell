using Collarbell.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Supplies;

internal static class SuppliesSchema
{
    public const string Name = "supplies";
}

internal sealed class SupplyItemConfiguration : IEntityTypeConfiguration<SupplyItem>
{
    public void Configure(EntityTypeBuilder<SupplyItem> b)
    {
        b.ToTable("items", SuppliesSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.HouseholdId, x.Active });
        b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();
        // One item per product in a household: a second scan of the same bag finds the first item.
        b.HasIndex(x => new { x.HouseholdId, x.Barcode }).IsUnique();

        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.Brand).HasMaxLength(100);
        b.Property(x => x.Barcode).HasMaxLength(14);
        b.Property(x => x.Category).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Unit).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.PackageSize).HasPrecision(12, 3);
        b.Property(x => x.UsageMode).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.ManualDailyUsage).HasPrecision(16, 6);
        b.Property(x => x.StoreUrl).HasMaxLength(500);
        b.Property(x => x.Notes).HasMaxLength(500);
    }
}

internal sealed class StockEventConfiguration : IEntityTypeConfiguration<StockEvent>
{
    public void Configure(EntityTypeBuilder<StockEvent> b)
    {
        b.ToTable("stock_events", SuppliesSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<SupplyItem>().WithMany().HasForeignKey(x => x.SupplyItemId).OnDelete(DeleteBehavior.Cascade);
        // Deleting a person's account keeps their purchases and counts: the stock is the household's, and the estimate
        // (and its reminders) would change without them.
        b.HasOne<User>().WithMany().HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.SetNull);
        b.HasIndex(x => new { x.SupplyItemId, x.At });
        b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();

        b.Property(x => x.Kind).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Quantity).HasPrecision(14, 3);
    }
}

internal sealed class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> b)
    {
        b.ToTable("products", SuppliesSchema.Name);
        b.HasKey(x => x.Id);
        b.HasIndex(x => x.Barcode).IsUnique();

        b.Property(x => x.Barcode).HasMaxLength(14);
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.Brand).HasMaxLength(100);
        b.Property(x => x.Category).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Unit).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.PackageSize).HasPrecision(12, 3);
        b.Property(x => x.Source).HasConversion<string>().HasMaxLength(16);
    }
}
