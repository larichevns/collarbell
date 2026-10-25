namespace Collarbell.Api.Modules.Documents;

/// <summary>
/// An uploaded file: a pet photo, a document page or a PDF. The bytes live in object storage under
/// <see cref="StorageKey"/>; photos also have a small copy under <see cref="ThumbnailKey"/>.
/// </summary>
public sealed class StoredFile
{
    private StoredFile()
    {
    }

    public StoredFile(
        Guid householdId,
        Guid createdBy,
        string contentType,
        long sizeBytes,
        string sha256,
        int? width,
        int? height,
        bool hasThumbnail,
        DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        StorageKey = $"{householdId}/{Id}";
        ThumbnailKey = hasThumbnail ? $"{StorageKey}-thumb" : null;
        ContentType = contentType;
        SizeBytes = sizeBytes;
        Sha256 = sha256;
        Width = width;
        Height = height;
        CreatedBy = createdBy;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public string StorageKey { get; private set; } = null!;

    public string? ThumbnailKey { get; private set; }

    public string ContentType { get; private set; } = null!;

    public long SizeBytes { get; private set; }

    public string Sha256 { get; private set; } = null!;

    public int? Width { get; private set; }

    public int? Height { get; private set; }

    public Guid CreatedBy { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    /// <summary>
    /// When the file became a pet photo or a document page. A file is used in one place only;
    /// files that are never attached are deleted after a day (<see cref="StorageCleanup"/>).
    /// </summary>
    public DateTimeOffset? AttachedAt { get; set; }

    public bool IsImage => ContentType.StartsWith("image/", StringComparison.Ordinal);
}

/// <summary>
/// A storage object waiting to be deleted. Removing a file queues its objects here in the same
/// transaction, and <see cref="StorageCleanup"/> deletes them later, so a storage outage loses nothing.
/// </summary>
public sealed class StorageDeletion
{
    private StorageDeletion()
    {
    }

    public StorageDeletion(string key, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        Key = key;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    public string Key { get; private set; } = null!;

    public DateTimeOffset CreatedAt { get; private set; }

    public int Attempts { get; set; }
}
