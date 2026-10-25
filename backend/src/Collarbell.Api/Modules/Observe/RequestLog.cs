using System.Diagnostics;
using System.Threading.Channels;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Modules.Observe;

public sealed class ObserveOptions
{
    /// <summary>How often the request log is written to the database; zero turns the writer off (the tests write themselves).</summary>
    public TimeSpan FlushInterval { get; set; } = TimeSpan.FromSeconds(2);

    /// <summary>How often records older than <see cref="ObserveLimits.Retention"/> are deleted; zero turns it off.</summary>
    public TimeSpan CleanupInterval { get; set; } = TimeSpan.FromHours(1);

    /// <summary>Where the nightly backups are (deploy/backup.sh), to tell their age; none locally.</summary>
    public string? BackupDir { get; set; }
}

/// <summary>
/// The requests waiting to be written: the request doesn't wait for the database, and when the database is slow the
/// oldest records go first (the log is for looking back, not for anything that must not be lost).
/// </summary>
public sealed class RequestLogQueue
{
    private readonly Channel<RequestRecord> _channel = Channel.CreateBounded<RequestRecord>(
        new BoundedChannelOptions(10_000) { FullMode = BoundedChannelFullMode.DropOldest, SingleReader = true });

    public void Add(RequestRecord record) => _channel.Writer.TryWrite(record);

    /// <summary>Writes what is waiting, in batches. Returns how many were written.</summary>
    public async Task<int> DrainAsync(AppDbContext db, CancellationToken ct)
    {
        var written = 0;
        var batch = new List<RequestRecord>();
        while (_channel.Reader.TryRead(out var record))
        {
            batch.Add(record);
            if (batch.Count == 500)
            {
                written += await WriteAsync(db, batch, ct);
            }
        }

        return written + await WriteAsync(db, batch, ct);
    }

    internal ValueTask<bool> WaitAsync(CancellationToken ct) => _channel.Reader.WaitToReadAsync(ct);

    private static async Task<int> WriteAsync(AppDbContext db, List<RequestRecord> batch, CancellationToken ct)
    {
        if (batch.Count == 0)
        {
            return 0;
        }

        // A deleted account leaves nothing in the log: the records of someone who is gone are kept without them. Their rows
        // are held while the batch goes in, so an account deletion at this moment either waits for the batch (and then
        // deletes its records too) or has finished (and the person is gone).
        async Task<int> WriteOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var people = batch.Select(r => r.UserId).OfType<Guid>().Distinct().ToList();
            var present = people.Count == 0
                ? []
                : await db.Database
                    .SqlQuery<Guid>($"SELECT id AS \"Value\" FROM identity.users WHERE id = ANY({people}) FOR KEY SHARE")
                    .ToListAsync(ct);
            foreach (var record in batch.Where(r => r.UserId is { } id && !present.Contains(id)))
            {
                record.Forget();
            }

            var written = batch.Count;
            try
            {
                db.Requests.AddRange(batch);
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                // One bad record must not take the others with it: one by one, and the bad one is dropped. Each save rolls
                // back to its own savepoint, so the transaction goes on.
                db.ChangeTracker.Clear();
                written = 0;
                foreach (var record in batch)
                {
                    try
                    {
                        db.Requests.Add(record);
                        await db.SaveChangesAsync(ct);
                        written++;
                    }
                    catch (DbUpdateException)
                    {
                        db.ChangeTracker.Clear();
                    }
                }
            }

            await transaction.CommitAsync(ct);
            return written;
        }

        var result = await db.Database.CreateExecutionStrategy().ExecuteAsync(WriteOnce);
        db.ChangeTracker.Clear();
        batch.Clear();
        return result;
    }
}

/// <summary>
/// Notes every <c>/api/v1</c> request for the admin's "визор": method, path, status, time, and the user and household
/// the request was about (from <see cref="CurrentUserAccessor"/>, which the endpoint filter already asked). The app's
/// own reports and the health check aren't noted.
/// </summary>
public sealed class RequestLogMiddleware(RequestDelegate next, RequestLogQueue queue, TimeProvider clock)
{
    public const string SessionHeader = "X-App-Session";
    public const string AppVersionHeader = "X-App-Version";

    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path.Value ?? "";
        if (!path.StartsWith("/api/v1/", StringComparison.Ordinal) || path.StartsWith(AppEventsEndpoints.Path, StringComparison.Ordinal))
        {
            await next(context);
            return;
        }

        var at = clock.GetUtcNow();
        var started = Stopwatch.GetTimestamp();
        int? failed = null;
        try
        {
            await next(context);
        }
        catch
        {
            // Normally the exception handler inside answers; this is what escaped it. 499: the client went away.
            failed = context.RequestAborted.IsCancellationRequested ? 499 : StatusCodes.Status500InternalServerError;
            throw;
        }
        finally
        {
            var accessor = context.RequestServices.GetService<CurrentUserAccessor>();

            // Only real API addresses, or requests of a known user: a stranger's made-up paths and methods are noise.
            if (context.GetEndpoint() is not null || accessor?.KnownUserId is not null)
            {
                var session = Guid.TryParse(context.Request.Headers[SessionHeader].ToString(), out var id) ? id : (Guid?)null;
                var version = AppEventsEndpoints.Text(context.Request.Headers[AppVersionHeader].ToString());
                queue.Add(new RequestRecord(
                    at,
                    accessor?.KnownUserId,
                    accessor?.Known?.HouseholdId,
                    Method(context.Request.Method),
                    Shorten(AppEventsEndpoints.Text(path) ?? "/", 300),
                    failed ?? (context.RequestAborted.IsCancellationRequested ? 499 : context.Response.StatusCode),
                    (int)Stopwatch.GetElapsedTime(started).TotalMilliseconds,
                    session,
                    version is { Length: <= 32 } ? version : null));
            }
        }
    }

    private static string Method(string method) =>
        method is "GET" or "POST" or "PUT" or "DELETE" or "PATCH" or "HEAD" or "OPTIONS" ? method : "OTHER";

    /// <summary>At most <paramref name="max"/> characters, never cutting a character made of two (an emoji) in half.</summary>
    private static string Shorten(string text, int max) =>
        text.Length <= max ? text : text[..(char.IsHighSurrogate(text[max - 1]) ? max - 1 : max)];
}

/// <summary>Writes the request log every few seconds, and once more when the API stops.</summary>
public sealed class RequestLogWriter(RequestLogQueue queue, IServiceScopeFactory scopes, IOptions<ObserveOptions> options,
    ILogger<RequestLogWriter> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = options.Value.FlushInterval;
        if (interval <= TimeSpan.Zero)
        {
            return;
        }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(interval, stoppingToken);
                await queue.WaitAsync(stoppingToken);
                await FlushAsync(CancellationToken.None);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception e)
            {
                log.LogWarning(e, "The request log wasn't written; trying again.");
            }
        }

        await FlushAsync(CancellationToken.None);
    }

    private async Task FlushAsync(CancellationToken ct)
    {
        await using var scope = scopes.CreateAsyncScope();
        await queue.DrainAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), ct);
    }
}

/// <summary>Deletes requests, app events and old alerts after <see cref="ObserveLimits.Retention"/>.</summary>
public sealed class ObserveRetention(AppDbContext db)
{
    public async Task<int> RunOnceAsync(DateTimeOffset now, CancellationToken ct)
    {
        var before = now - ObserveLimits.Retention;
        var requests = await db.Requests.Where(r => r.At < before).ExecuteDeleteAsync(ct);
        var events = await db.AppEvents.Where(e => e.ReceivedAt < before).ExecuteDeleteAsync(ct);
        return requests + events;
    }
}

/// <summary>A deleted account's week in the log goes with it, not a week later.</summary>
public sealed class ObserveAccountDeletion(AppDbContext db) : IAccountDeletionHandler
{
    public async Task BeforeAccountDeletedAsync(Guid userId, CancellationToken ct)
    {
        await db.Requests.Where(r => r.UserId == userId).ExecuteDeleteAsync(ct);
        await db.AppEvents.Where(e => e.UserId == userId).ExecuteDeleteAsync(ct);
    }
}

public sealed class ObserveRetentionWorker(IServiceScopeFactory scopes, IOptions<ObserveOptions> options, TimeProvider clock,
    ILogger<ObserveRetentionWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = options.Value.CleanupInterval;
        if (interval <= TimeSpan.Zero)
        {
            return;
        }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                var deleted = await scope.ServiceProvider.GetRequiredService<ObserveRetention>().RunOnceAsync(clock.GetUtcNow(), stoppingToken);
                if (deleted > 0)
                {
                    log.LogInformation("Deleted {Count} requests and app events older than a week.", deleted);
                }

                await Task.Delay(interval, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception e)
            {
                log.LogWarning(e, "Deleting old requests and app events failed; trying again later.");
                await Task.Delay(interval, stoppingToken);
            }
        }
    }
}

/// <summary>The person's week in the log (what the admin's "визор" shows of them), for "Download my data".</summary>
public sealed class ObserveExport(AppDbContext db) : IPersonalExportSource
{
    public async Task ExportAsync(PersonalExport export, CancellationToken ct)
    {
        var requests = await db.Requests.AsNoTracking()
            .Where(r => r.UserId == export.UserId)
            .OrderBy(r => r.At)
            .Select(r => new { r.At, r.Method, r.Path, r.Status, r.DurationMs, r.AppVersion })
            .ToListAsync(ct);
        var events = await db.AppEvents.AsNoTracking()
            .Where(e => e.UserId == export.UserId)
            .OrderBy(e => e.At)
            .Select(e => new { e.At, e.Kind, e.Name, e.Detail, e.AppVersion })
            .ToListAsync(ct);
        export.Add("activity", new { Requests = requests, AppEvents = events });
    }
}
