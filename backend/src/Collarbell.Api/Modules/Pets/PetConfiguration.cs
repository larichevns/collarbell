using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Pets;

internal static class PetsSchema
{
    public const string Name = "pets";
}

internal sealed class PetConfiguration : IEntityTypeConfiguration<Pet>
{
    public void Configure(EntityTypeBuilder<Pet> b)
    {
        b.ToTable("pets", PetsSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.HouseholdId);

        b.Property(x => x.Name).HasMaxLength(60);
        b.Property(x => x.Species).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Breed).HasMaxLength(100);
        b.Property(x => x.Sex).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Color).HasMaxLength(60);
        b.Property(x => x.Markings).HasMaxLength(300);
        b.Property(x => x.Coat).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Allergies).HasMaxLength(500);
        b.Property(x => x.Notes).HasMaxLength(2000);
        b.Property(x => x.Status).HasConversion<string>().HasMaxLength(16);

        // If the photo's file is deleted, the pet simply has no photo. A photo belongs to one pet.
        b.HasOne<StoredFile>().WithMany().HasForeignKey(x => x.PhotoFileId).OnDelete(DeleteBehavior.SetNull);
        b.HasIndex(x => x.PhotoFileId).IsUnique();

        b.HasMany(x => x.Identifiers).WithOne().HasForeignKey(i => i.PetId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class PetIdentifierConfiguration : IEntityTypeConfiguration<PetIdentifier>
{
    public void Configure(EntityTypeBuilder<PetIdentifier> b)
    {
        b.ToTable("pet_identifiers", PetsSchema.Name);
        b.HasKey(x => x.Id);
        // The id is made in code (UUID v7). Telling EF so makes an identifier added to a saved pet's list an
        // insert; otherwise EF takes a set id for an existing row and tries to update it.
        b.Property(x => x.Id).ValueGeneratedNever();
        b.HasIndex(x => x.PetId);

        b.Property(x => x.Type).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Code).HasMaxLength(IdentifierRules.MaxRawLength);
        b.Property(x => x.RawCode).HasMaxLength(IdentifierRules.MaxRawLength);
        b.Property(x => x.Location).HasMaxLength(60);
    }
}

internal sealed class WeightEntryConfiguration : IEntityTypeConfiguration<WeightEntry>
{
    public void Configure(EntityTypeBuilder<WeightEntry> b)
    {
        b.ToTable("weight_entries", PetsSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Pet>().WithMany().HasForeignKey(x => x.PetId).OnDelete(DeleteBehavior.Cascade);
        // A deleted account leaves its weighings to the pet, without the name of who added them.
        b.HasOne<User>().WithMany().HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.SetNull);
        b.HasIndex(x => new { x.PetId, x.MeasuredOn });
        b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();

        b.Property(x => x.WeightKg).HasPrecision(6, 3);
        b.Property(x => x.Note).HasMaxLength(500);
    }
}

internal sealed class PetPassportConfiguration : IEntityTypeConfiguration<PetPassport>
{
    public void Configure(EntityTypeBuilder<PetPassport> b)
    {
        b.ToTable("pet_passports", PetsSchema.Name);
        b.HasKey(x => x.PetId);
        b.HasOne<Pet>().WithOne().HasForeignKey<PetPassport>(x => x.PetId).OnDelete(DeleteBehavior.Cascade);

        b.Property(x => x.Model).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.PassportNumber).HasMaxLength(30);
        b.Property(x => x.IssuingCountry).HasMaxLength(2);
        b.Property(x => x.Notes).HasMaxLength(2000);

        // Contacts are small and always read with the passport, so they live in jsonb columns.
        b.OwnsOne(x => x.Issuer, o => o.ToJson());
        b.OwnsMany(x => x.Owners, o => o.ToJson());
    }
}
