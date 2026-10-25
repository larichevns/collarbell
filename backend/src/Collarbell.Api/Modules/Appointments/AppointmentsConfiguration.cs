using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Appointments;

internal static class AppointmentsSchema
{
    public const string Name = "appointments";
}

internal sealed class AppointmentConfiguration : IEntityTypeConfiguration<Appointment>
{
    public void Configure(EntityTypeBuilder<Appointment> b)
    {
        b.ToTable("appointments", AppointmentsSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.HouseholdId, x.Status, x.StartsAt });
        b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();

        b.Property(x => x.Type).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Title).HasMaxLength(100);
        b.Property(x => x.Location).HasMaxLength(200);
        b.Property(x => x.Notes).HasMaxLength(2000);
        // "Done" twice at once (a double tap, two phones) must not make the records twice: the second save fails.
        b.Property(x => x.Status).HasConversion<string>().HasMaxLength(16).IsConcurrencyToken();
        b.PrimitiveCollection(x => x.RemindOffsetsMinutes);
        b.PrimitiveCollection(x => x.RecordIds);

        b.HasMany(x => x.Pets).WithOne().HasForeignKey(p => p.AppointmentId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class AppointmentPetConfiguration : IEntityTypeConfiguration<AppointmentPet>
{
    public void Configure(EntityTypeBuilder<AppointmentPet> b)
    {
        b.ToTable("appointment_pets", AppointmentsSchema.Name);
        b.HasKey(x => new { x.AppointmentId, x.PetId });
        // Deleting a pet takes it off its visits; the visits stay.
        b.HasOne<Pet>().WithMany().HasForeignKey(x => x.PetId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.PetId);
    }
}
