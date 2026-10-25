using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Identity;

internal static class IdentitySchema
{
    public const string Name = "identity";
}

internal sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> b)
    {
        b.ToTable("users", IdentitySchema.Name);
        b.HasKey(x => x.Id);
        b.Property(x => x.AuthSubject).HasMaxLength(200);
        b.HasIndex(x => x.AuthSubject).IsUnique();
        b.Property(x => x.Email).HasMaxLength(320);
        b.Property(x => x.DisplayName).HasMaxLength(100);
        b.Property(x => x.Locale).HasMaxLength(10);
        b.Property(x => x.TimeZone).HasMaxLength(64);
    }
}

internal sealed class HouseholdConfiguration : IEntityTypeConfiguration<Household>
{
    public void Configure(EntityTypeBuilder<Household> b)
    {
        b.ToTable("households", IdentitySchema.Name);
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.TimeZone).HasMaxLength(64);
    }
}

internal sealed class HouseholdMemberConfiguration : IEntityTypeConfiguration<HouseholdMember>
{
    public void Configure(EntityTypeBuilder<HouseholdMember> b)
    {
        b.ToTable("household_members", IdentitySchema.Name);
        b.HasKey(x => new { x.HouseholdId, x.UserId });
        b.Property(x => x.Role).HasConversion<string>().HasMaxLength(16);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.UserId);
    }
}

internal sealed class HouseholdInviteConfiguration : IEntityTypeConfiguration<HouseholdInvite>
{
    public void Configure(EntityTypeBuilder<HouseholdInvite> b)
    {
        b.ToTable("household_invites", IdentitySchema.Name);
        b.HasKey(x => x.Id);
        b.Property(x => x.Code).HasMaxLength(16);
        b.HasIndex(x => x.Code).IsUnique();
        b.Property(x => x.Role).HasConversion<string>().HasMaxLength(16);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.AcceptedBy).OnDelete(DeleteBehavior.SetNull);
        b.HasIndex(x => x.HouseholdId);
    }
}

internal sealed class DeletedAccountConfiguration : IEntityTypeConfiguration<DeletedAccount>
{
    public void Configure(EntityTypeBuilder<DeletedAccount> b)
    {
        b.ToTable("deleted_accounts", IdentitySchema.Name);
        b.HasKey(x => x.AuthSubject);
        b.Property(x => x.AuthSubject).HasMaxLength(200);
    }
}
