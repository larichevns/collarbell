using Collarbell.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Notifications;

internal static class NotificationsSchema
{
    public const string Name = "notifications";
}

internal sealed class ReminderConfiguration : IEntityTypeConfiguration<Reminder>
{
    public void Configure(EntityTypeBuilder<Reminder> b)
    {
        b.ToTable("reminders", NotificationsSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        // One occasion, one reminder: planning it again never sends it twice.
        b.HasIndex(x => new { x.Source, x.SourceId, x.Key }).IsUnique();
        // The dispatcher's question: what is due now?
        b.HasIndex(x => x.DueAt).HasFilter("status = 'Pending'");
        b.HasIndex(x => new { x.HouseholdId, x.FireAt });

        b.Property(x => x.Source).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Key).HasMaxLength(40);
        b.Property(x => x.Category).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Subject).HasMaxLength(ReminderSchedule.MaxSubjectLength);
        // Planning and sending can touch the same reminder at once; a change made over a status that changed
        // meanwhile fails instead of undoing it.
        b.Property(x => x.Status).HasConversion<string>().HasMaxLength(16).IsConcurrencyToken();
        b.Property(x => x.Reason).HasConversion<string>().HasMaxLength(24);
    }
}

internal sealed class DeviceConfiguration : IEntityTypeConfiguration<Device>
{
    public void Configure(EntityTypeBuilder<Device> b)
    {
        b.ToTable("devices", NotificationsSchema.Name);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).ValueGeneratedNever();
        b.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.UserId);
        b.HasIndex(x => x.Token).IsUnique();

        b.Property(x => x.Platform).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Token).HasMaxLength(Devices.MaxTokenLength);
        b.Property(x => x.AppVersion).HasMaxLength(32);
    }
}

internal sealed class NotificationPreferenceConfiguration : IEntityTypeConfiguration<NotificationPreference>
{
    public void Configure(EntityTypeBuilder<NotificationPreference> b)
    {
        b.ToTable("preferences", NotificationsSchema.Name);
        b.HasKey(x => new { x.UserId, x.Category });
        b.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Property(x => x.Category).HasConversion<string>().HasMaxLength(16);
    }
}
