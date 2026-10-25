using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Storage;
using Collarbell.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Documents;

/// <summary>A file as the client sees it: what it is and links to download it, valid until <see cref="ExpiresAt"/>.</summary>
public sealed record FileLink(
    Guid Id,
    string ContentType,
    long SizeBytes,
    int? Width,
    int? Height,
    string Url,
    string? ThumbnailUrl,
    DateTimeOffset ExpiresAt);

/// <summary>
/// The files part of the Documents module's public API. Other modules (Pets) attach, show and remove
/// files only through this class; they don't touch the files table themselves.
/// </summary>
public sealed class Files(AppDbContext db, ObjectStorage storage, TimeProvider clock)
{
    public FileLink Link(StoredFile file)
    {
        var (url, expiresAt) = storage.GetDownloadLink(file.StorageKey);
        var thumbnailUrl = file.ThumbnailKey is null ? null : storage.GetDownloadLink(file.ThumbnailKey).Url;
        return new FileLink(file.Id, file.ContentType, file.SizeBytes, file.Width, file.Height, url, thumbnailUrl, expiresAt);
    }

    public async Task<Dictionary<Guid, FileLink>> LinksAsync(IEnumerable<Guid> fileIds, CancellationToken ct)
    {
        var ids = fileIds.Distinct().ToList();
        if (ids.Count == 0)
        {
            return [];
        }

        var files = await db.StoredFiles.AsNoTracking().Where(f => ids.Contains(f.Id)).ToListAsync(ct);
        return files.ToDictionary(f => f.Id, Link);
    }

    /// <summary>
    /// Checks that the files could be attached (household, not used yet, photos when required) without
    /// attaching them. Returns a message for the client when something is wrong.
    /// </summary>
    public async Task<string?> CheckFreeAsync(Guid householdId, IReadOnlyCollection<Guid> fileIds, bool photosOnly, CancellationToken ct)
    {
        var ids = fileIds.ToList();
        if (ids.Distinct().Count() != ids.Count)
        {
            return "Each file can be used once.";
        }

        var files = await db.StoredFiles.AsNoTracking()
            .Where(f => ids.Contains(f.Id) && f.HouseholdId == householdId)
            .ToListAsync(ct);
        return files.Count != ids.Count ? "Unknown file: upload it first."
            : files.Any(f => f.AttachedAt is not null) ? "This file is already used; upload it again."
            : photosOnly && files.Any(f => !f.IsImage) ? "Use a photo: JPEG, PNG or WebP."
            : null;
    }

    /// <summary>
    /// The files' bytes in the order of <paramref name="fileIds"/>. Files that are gone (deleted, or missing from
    /// storage) are skipped.
    /// </summary>
    public async Task<List<(StoredFile File, byte[] Content)>> ReadAsync(
        Guid householdId, IReadOnlyList<Guid> fileIds, CancellationToken ct)
    {
        var files = await db.StoredFiles.AsNoTracking()
            .Where(f => fileIds.Contains(f.Id) && f.HouseholdId == householdId)
            .ToDictionaryAsync(f => f.Id, ct);
        var result = new List<(StoredFile, byte[])>();
        foreach (var id in fileIds)
        {
            if (files.TryGetValue(id, out var file) && await storage.TryGetAsync(file.StorageKey, ct) is { } content)
            {
                result.Add((file, content));
            }
        }

        return result;
    }

    /// <summary>
    /// Marks uploaded files as used. They must belong to the household, not be used anywhere yet and,
    /// when <paramref name="photosOnly"/> is set, be photos. Returns a message for the client when
    /// something is wrong. The change is saved by the caller's SaveChanges, together with the caller's data.
    /// </summary>
    public async Task<string?> AttachAsync(Guid householdId, IReadOnlyCollection<Guid> fileIds, bool photosOnly, CancellationToken ct)
    {
        var ids = fileIds.ToList();
        if (ids.Distinct().Count() != ids.Count)
        {
            return "Each file can be used once.";
        }

        var files = await db.StoredFiles.Where(f => ids.Contains(f.Id) && f.HouseholdId == householdId).ToListAsync(ct);
        if (files.Count != ids.Count)
        {
            return "Unknown file: upload it first.";
        }

        if (files.Any(f => f.AttachedAt is not null))
        {
            return "This file is already used; upload it again.";
        }

        if (photosOnly && files.Any(f => !f.IsImage))
        {
            return "Use a photo: JPEG, PNG or WebP.";
        }

        var now = clock.GetUtcNow();
        foreach (var file in files)
        {
            file.AttachedAt = now;
        }

        return null;
    }

    /// <summary>
    /// Removes files: the rows go with the caller's SaveChanges, and the storage objects are queued for
    /// deletion in the same transaction (see <see cref="StorageCleanup"/>).
    /// </summary>
    public async Task RemoveAsync(IReadOnlyCollection<Guid> fileIds, CancellationToken ct)
    {
        if (fileIds.Count == 0)
        {
            return;
        }

        var ids = fileIds.ToList();
        Remove(await db.StoredFiles.Where(f => ids.Contains(f.Id)).ToListAsync(ct));
    }

    internal void Remove(IEnumerable<StoredFile> files)
    {
        var now = clock.GetUtcNow();
        foreach (var file in files)
        {
            db.StoredFiles.Remove(file);
            db.StorageDeletions.Add(new StorageDeletion(file.StorageKey, now));
            if (file.ThumbnailKey is not null)
            {
                db.StorageDeletions.Add(new StorageDeletion(file.ThumbnailKey, now));
            }
        }
    }
}

/// <summary>
/// A household deleted with an account (<see cref="AccountDeletion"/>): every file of it, attached or not, leaves storage
/// through the deletion queue. One statement queues them all and the database deletes the rows with the household: a file
/// another phone removes at this moment (queued by itself) changes nothing here. No new file can appear meanwhile: the
/// deletion holds the household.
/// </summary>
public sealed class HouseholdFiles(AppDbContext db, TimeProvider clock) : IHouseholdDeletionHandler
{
    public async Task BeforeHouseholdDeletedAsync(Guid householdId, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await db.Database.ExecuteSqlAsync($"""
            INSERT INTO documents.storage_deletions (id, key, created_at, attempts)
            SELECT gen_random_uuid(), key, {now}, 0
            FROM documents.stored_files f, LATERAL (VALUES (f.storage_key), (f.thumbnail_key)) AS k(key)
            WHERE f.household_id = {householdId} AND key IS NOT NULL
            """, ct);
    }
}
