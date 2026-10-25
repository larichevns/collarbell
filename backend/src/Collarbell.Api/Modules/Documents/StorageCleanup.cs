using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Modules.Documents;

/// <summary>
/// A module that still needs some uploads that aren't attached anywhere, e.g. the photos of a scan the user hasn't
/// saved yet. The cleanup leaves them alone. Like <c>IPetDeletionHandler</c>: Documents doesn't know the others.
/// </summary>
public interface IUploadKeeper
{
    Task<IReadOnlyCollection<Guid>> NeededUploadsAsync(CancellationToken ct);
}

/// <summary>
/// Keeps storage in step with the database: removes uploads that were never attached and deletes
/// the storage objects of removed files (the <see cref="StorageDeletion"/> queue).
/// </summary>
public sealed class StorageCleanup(
    AppDbContext db,
    ObjectStorage storage,
    Files files,
    IEnumerable<IUploadKeeper> keepers,
    TimeProvider clock,
    ILogger<StorageCleanup> log)
{
    public static readonly TimeSpan UnattachedFileLifetime = TimeSpan.FromDays(1);

    private const int BatchSize = 100;

    public async Task RunOnceAsync(CancellationToken ct)
    {
        // 1. Uploads that never became a photo or a page (the user gave up halfway) and no module still needs.
        var cutoff = clock.GetUtcNow() - UnattachedFileLifetime;
        var needed = new List<Guid>();
        foreach (var keeper in keepers)
        {
            needed.AddRange(await keeper.NeededUploadsAsync(ct));
        }

        var abandoned = await db.StoredFiles
            .Where(f => f.AttachedAt == null && f.CreatedAt < cutoff && !needed.Contains(f.Id))
            .OrderBy(f => f.CreatedAt)
            .Take(BatchSize)
            .ToListAsync(ct);
        if (abandoned.Count > 0)
        {
            files.Remove(abandoned);
            await db.SaveChangesAsync(ct);
        }

        // 2. Storage objects of removed files. A failure keeps the item for the next run.
        var queue = await db.StorageDeletions.OrderBy(d => d.CreatedAt).Take(BatchSize).ToListAsync(ct);
        foreach (var item in queue)
        {
            try
            {
                await storage.DeleteAsync(item.Key, ct);
                db.StorageDeletions.Remove(item);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                item.Attempts++;
                log.LogWarning(e, "Could not delete storage object {Key} (attempt {Attempts}).", item.Key, item.Attempts);
            }
        }

        await db.SaveChangesAsync(ct);
    }
}

/// <summary>Runs <see cref="StorageCleanup"/> every <see cref="StorageOptions.CleanupInterval"/>.</summary>
internal sealed class StorageCleanupWorker(
    IServiceScopeFactory scopes,
    IOptions<StorageOptions> options,
    ILogger<StorageCleanupWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = options.Value.CleanupInterval;
        if (interval <= TimeSpan.Zero)
        {
            return;
        }

        using var timer = new PeriodicTimer(interval);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<StorageCleanup>().RunOnceAsync(stoppingToken);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "Storage cleanup failed; it runs again on the next tick.");
            }
        }
    }
}
