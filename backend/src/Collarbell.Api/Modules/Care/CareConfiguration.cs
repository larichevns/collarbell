using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Care;

internal static class CareSchema
{
    public const string Name = "care";
}

internal sealed class CarePlanConfiguration : IEntityTypeConfiguration<CarePlan>
{
    public void Configure(EntityTypeBuilder<CarePlan> b)
    {
        b.ToTable("care_plans", CareSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Pet>().WithMany().HasForeignKey(x => x.PetId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.PetId);
        // The Today screen asks for the household's active plans due before a date.
        b.HasIndex(x => new { x.HouseholdId, x.Active, x.NextDueOn });
        b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();

        b.Property(x => x.Kind).HasConversion<string>().HasMaxLength(24);
        b.Property(x => x.Title).HasMaxLength(100);
        b.Property(x => x.IntervalUnit).HasConversion<string>().HasMaxLength(8);
        b.Property(x => x.DefaultProduct).HasMaxLength(100);
        b.Property(x => x.PresetCode).HasMaxLength(40);
        b.Property(x => x.Notes).HasMaxLength(2000);
        b.PrimitiveCollection(x => x.RemindOffsetsDays);
        b.PrimitiveCollection(x => x.Targets).ElementType(e => e.HasConversion<string>());
        b.Ignore(x => x.IsRecurring);
    }
}

internal sealed class CareRecordConfiguration : IEntityTypeConfiguration<CareRecord>
{
    public void Configure(EntityTypeBuilder<CareRecord> b)
    {
        b.ToTable("care_records", CareSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Pet>().WithMany().HasForeignKey(x => x.PetId).OnDelete(DeleteBehavior.Cascade);
        // Deleting a plan keeps its history: the records just lose the link.
        b.HasOne<CarePlan>().WithMany().HasForeignKey(x => x.PlanId).OnDelete(DeleteBehavior.SetNull);
        b.HasIndex(x => new { x.PetId, x.PerformedOn });
        b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();

        b.Property(x => x.Kind).HasConversion<string>().HasMaxLength(24);
        b.Property(x => x.Title).HasMaxLength(100);
        b.Property(x => x.Product).HasMaxLength(100);
        b.Property(x => x.Manufacturer).HasMaxLength(100);
        b.Property(x => x.BatchNumber).HasMaxLength(50);
        b.Property(x => x.Clinic).HasMaxLength(200);
        b.Property(x => x.Veterinarian).HasMaxLength(100);
        b.Property(x => x.WeightKg).HasPrecision(6, 2);
        b.Property(x => x.Notes).HasMaxLength(2000);
        b.Property(x => x.Source).HasConversion<string>().HasMaxLength(16);
        b.PrimitiveCollection(x => x.Targets).ElementType(e => e.HasConversion<string>());
        b.OwnsOne(x => x.Details, o => o.ToJson());

        b.HasMany(x => x.Files).WithOne().HasForeignKey(f => f.CareRecordId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class CareRecordFileConfiguration : IEntityTypeConfiguration<CareRecordFile>
{
    public void Configure(EntityTypeBuilder<CareRecordFile> b)
    {
        b.ToTable("care_record_files", CareSchema.Name);
        b.HasKey(x => x.FileId);
        // Deleting the file deletes the attachment.
        b.HasOne<StoredFile>().WithOne().HasForeignKey<CareRecordFile>(x => x.FileId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.CareRecordId);
    }
}
