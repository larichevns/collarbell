using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Supplies;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Routines;

internal static class RoutinesSchema
{
    public const string Name = "routines";
}

internal sealed class RoutineConfiguration : IEntityTypeConfiguration<Routine>
{
    public void Configure(EntityTypeBuilder<Routine> b)
    {
        b.ToTable("routines", RoutinesSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Pet>().WithMany().HasForeignKey(x => x.PetId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.PetId);
        b.HasIndex(x => new { x.HouseholdId, x.Active });
        b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();
        // A deleted supply item leaves the feeding with its food name, without the link.
        b.HasOne<SupplyItem>().WithMany().HasForeignKey(x => x.SupplyItemId).OnDelete(DeleteBehavior.SetNull);
        b.HasIndex(x => x.SupplyItemId);

        b.Property(x => x.Kind).HasConversion<string>().HasMaxLength(16);
        b.PrimitiveCollection(x => x.Times);
        b.PrimitiveCollection(x => x.Days);
        b.Property(x => x.Food).HasMaxLength(100);
        b.Property(x => x.Amount).HasPrecision(8, 2);
        b.Property(x => x.Unit).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Notes).HasMaxLength(500);
    }
}

internal sealed class RoutineCompletionConfiguration : IEntityTypeConfiguration<RoutineCompletion>
{
    public void Configure(EntityTypeBuilder<RoutineCompletion> b)
    {
        b.ToTable("completions", RoutinesSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Routine>().WithMany().HasForeignKey(x => x.RoutineId).OnDelete(DeleteBehavior.Cascade);
        // One mark per occurrence: the database refuses a second one, even from two phones at the same moment.
        b.HasIndex(x => new { x.RoutineId, x.Date, x.Time }).IsUnique();
        b.HasIndex(x => new { x.HouseholdId, x.Date });

        b.Property(x => x.Status).HasConversion<string>().HasMaxLength(16);
        // Deleting a person's account keeps their marks: the others still see that the cat was fed (and don't feed it
        // again), only without the name.
        b.HasOne<User>().WithMany().HasForeignKey(x => x.DoneBy).OnDelete(DeleteBehavior.SetNull);
    }
}
