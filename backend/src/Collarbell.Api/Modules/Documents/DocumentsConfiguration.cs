using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Documents;

internal static class DocumentsSchema
{
    public const string Name = "documents";
}

internal sealed class StoredFileConfiguration : IEntityTypeConfiguration<StoredFile>
{
    public void Configure(EntityTypeBuilder<StoredFile> b)
    {
        b.ToTable("stored_files", DocumentsSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.HouseholdId);
        // Finds uploads that were never attached (see StorageCleanup).
        b.HasIndex(x => x.CreatedAt).HasFilter("attached_at IS NULL");

        b.Property(x => x.StorageKey).HasMaxLength(200);
        b.Property(x => x.ThumbnailKey).HasMaxLength(200);
        b.Property(x => x.ContentType).HasMaxLength(100);
        b.Property(x => x.Sha256).HasMaxLength(64);
        b.Ignore(x => x.IsImage);
    }
}

internal sealed class DocumentConfiguration : IEntityTypeConfiguration<Document>
{
    public void Configure(EntityTypeBuilder<Document> b)
    {
        b.ToTable("documents", DocumentsSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        // Deleting a pet deletes its documents; the pet's code queues their files for deletion first.
        b.HasOne<Pet>().WithMany().HasForeignKey(x => x.PetId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.HouseholdId, x.PetId });

        b.Property(x => x.Type).HasConversion<string>().HasMaxLength(32);
        b.Property(x => x.Title).HasMaxLength(200);
        b.Property(x => x.Notes).HasMaxLength(2000);

        b.HasMany(x => x.Pages).WithOne().HasForeignKey(p => p.DocumentId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class DocumentPageConfiguration : IEntityTypeConfiguration<DocumentPage>
{
    public void Configure(EntityTypeBuilder<DocumentPage> b)
    {
        b.ToTable("document_pages", DocumentsSchema.Name);
        b.HasKey(x => x.FileId);
        // Deleting the file deletes the page.
        b.HasOne<StoredFile>().WithOne().HasForeignKey<DocumentPage>(x => x.FileId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.DocumentId);
    }
}

internal sealed class StorageDeletionConfiguration : IEntityTypeConfiguration<StorageDeletion>
{
    public void Configure(EntityTypeBuilder<StorageDeletion> b)
    {
        b.ToTable("storage_deletions", DocumentsSchema.Name);
        b.HasKey(x => x.Id);
        b.Property(x => x.Key).HasMaxLength(200);
    }
}
