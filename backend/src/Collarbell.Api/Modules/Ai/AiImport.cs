using System.Text.Json.Serialization;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Ai;

[JsonConverter(typeof(JsonStringEnumConverter<AiImportSource>))]
public enum AiImportSource
{
    /// <summary>Pages of the pet passport, stickers included. The photos are kept as passport scans.</summary>
    PassportPages,

    /// <summary>A vaccination certificate, an invoice or another vet paper. The photos are kept as a document.</summary>
    VetDocument,

    /// <summary>A note the user typed or dictated ("yesterday the rabies shot, 4.2 kg"): <see cref="AiImport.Text"/>, no photos.</summary>
    Text,
}

[JsonConverter(typeof(JsonStringEnumConverter<AiImportStatus>))]
public enum AiImportStatus
{
    Queued,
    Processing,

    /// <summary>The draft is ready for the user to check.</summary>
    Ready,

    /// <summary>The user saved (part of) the draft.</summary>
    Applied,

    Failed,

    /// <summary>The user threw the draft away.</summary>
    Discarded,
}

[JsonConverter(typeof(JsonStringEnumConverter<AiImportError>))]
public enum AiImportError
{
    /// <summary>No AI model is set up on the server.</summary>
    NotConfigured,

    /// <summary>All models are busy or out of free quota right now: try again later.</summary>
    Busy,

    /// <summary>The provider refused the request (for example the key is wrong).</summary>
    Rejected,

    /// <summary>The photos are gone from storage.</summary>
    PhotosMissing,

    Unexpected,
}

/// <summary>
/// One "scan": photos the user took (or a note they wrote), what the AI read and what the user saved. Photos stay
/// unattached until the draft is applied; <see cref="AiImportUploads"/> keeps them meanwhile.
/// </summary>
public sealed class AiImport
{
    private AiImport()
    {
    }

    public AiImport(Guid householdId, Guid petId, AiImportSource source, List<Guid> fileIds, Guid createdBy, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        PetId = petId;
        Source = source;
        FileIds = fileIds;
        CreatedBy = createdBy;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public Guid PetId { get; private set; }

    public AiImportSource Source { get; private set; }

    /// <summary>The photos, in page order; none for a note.</summary>
    public List<Guid> FileIds { get; private set; } = [];

    /// <summary>The note of a <see cref="AiImportSource.Text"/> import. Goes with the draft when it is thrown away.</summary>
    public string? Text { get; set; }

    public AiImportStatus Status { get; set; } = AiImportStatus.Queued;

    /// <summary>
    /// The model's answer (<see cref="PassportScan"/>) as JSON, once read. The draft is built from it on every read,
    /// against what is saved by then, so "already saved" and plan links are never stale.
    /// </summary>
    public string? ScanJson { get; set; }

    public AiImportError? Error { get; set; }

    public AiProvider? Provider { get; set; }

    public string? Model { get; set; }

    public string PromptVersion { get; set; } = PassportScanPrompt.Version;

    /// <summary>What applying created, as JSON: a repeated apply answers with it instead of saving twice.</summary>
    public string? ResultJson { get; set; }

    /// <summary>The id the app gave the create request; a retry with the same id returns this import.</summary>
    public Guid? ClientRequestId { get; set; }

    public Guid CreatedBy { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset? StartedAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public DateTimeOffset? AppliedAt { get; set; }
}

internal static class AiSchema
{
    public const string Name = "ai";
}

internal sealed class AiImportConfiguration : IEntityTypeConfiguration<AiImport>
{
    public void Configure(EntityTypeBuilder<AiImport> b)
    {
        b.ToTable("imports", AiSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Pet>().WithMany().HasForeignKey(x => x.PetId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.PetId, x.CreatedAt });
        // The worker looks for queued imports.
        b.HasIndex(x => x.Status).HasFilter("status IN ('Queued', 'Processing')");
        b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();

        b.Property(x => x.Source).HasConversion<string>().HasMaxLength(24);
        b.Property(x => x.Status).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Error).HasConversion<string>().HasMaxLength(24);
        b.Property(x => x.Provider).HasConversion<string>().HasMaxLength(24);
        b.Property(x => x.Model).HasMaxLength(100);
        b.Property(x => x.PromptVersion).HasMaxLength(40);
        b.Property(x => x.Text).HasMaxLength(AiImportsEndpoints.MaxTextLength);
        b.Property(x => x.ScanJson).HasColumnType("jsonb");
        b.Property(x => x.ResultJson).HasColumnType("jsonb");
        b.PrimitiveCollection(x => x.FileIds);
    }
}

/// <summary>
/// Keeps the photos of scans that are being read, waiting to be checked, or failed (to be tried again), for up to
/// <see cref="KeptFor"/>: the storage cleanup would otherwise delete them a day after the upload.
/// </summary>
public sealed class AiImportUploads(AppDbContext db, TimeProvider clock) : IUploadKeeper
{
    public static readonly TimeSpan KeptFor = TimeSpan.FromDays(30);

    public async Task<IReadOnlyCollection<Guid>> NeededUploadsAsync(CancellationToken ct)
    {
        var since = clock.GetUtcNow() - KeptFor;
        var photos = await db.AiImports
            .Where(i => i.CreatedAt > since
                && (i.Status == AiImportStatus.Queued || i.Status == AiImportStatus.Processing
                    || i.Status == AiImportStatus.Ready || i.Status == AiImportStatus.Failed))
            .Select(i => i.FileIds)
            .ToListAsync(ct);
        return [.. photos.SelectMany(ids => ids).Distinct()];
    }
}

internal sealed class AiUsageConfiguration : IEntityTypeConfiguration<AiUsage>
{
    public void Configure(EntityTypeBuilder<AiUsage> b)
    {
        b.ToTable("usage", AiSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.HouseholdId, x.CreatedAt });

        b.Property(x => x.Feature).HasMaxLength(40);
        b.Property(x => x.Provider).HasConversion<string>().HasMaxLength(24);
        b.Property(x => x.Model).HasMaxLength(100);
    }
}
