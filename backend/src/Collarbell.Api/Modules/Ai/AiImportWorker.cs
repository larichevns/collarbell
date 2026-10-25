using System.Text.Json;
using System.Threading.Channels;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.AI;

namespace Collarbell.Api.Modules.Ai;

/// <summary>Tells the worker an import is waiting, so it starts at once instead of on its next look.</summary>
public sealed class AiImportQueue
{
    private readonly Channel<Guid> _waiting = Channel.CreateUnbounded<Guid>();

    public void Enqueue(Guid importId) => _waiting.Writer.TryWrite(importId);

    public ChannelReader<Guid> Reader => _waiting.Reader;
}

/// <summary>Reads one import's photos (or note) with AI and keeps the model's answer for the draft.</summary>
public sealed class AiImportProcessor(
    AppDbContext db,
    AiRunner runner,
    Files files,
    Plans plans,
    PetDirectory pets,
    HouseholdCalendar calendar,
    LiveChanges live,
    TimeProvider clock,
    ILogger<AiImportProcessor> log)
{
    public async Task ProcessAsync(Guid importId, CancellationToken ct)
    {
        // Claim the import, so that it is processed once even if two workers see it.
        var claimed = await db.AiImports
            .Where(i => i.Id == importId && i.Status == AiImportStatus.Queued)
            .ExecuteUpdateAsync(s => s
                .SetProperty(i => i.Status, AiImportStatus.Processing)
                .SetProperty(i => i.StartedAt, clock.GetUtcNow()), ct);
        if (claimed == 0)
        {
            return;
        }

        var import = await db.AiImports.AsNoTracking().SingleAsync(i => i.Id == importId, ct);
        string? scanJson = null;
        AiModelRef? model = null;
        AiImportError? error = null;
        try
        {
            var locale = await db.Users.Where(u => u.Id == import.CreatedBy).Select(u => u.Locale).SingleOrDefaultAsync(ct) ?? "en";
            var (message, feature) = import.Source == AiImportSource.Text
                ? (await NoteAsync(import, locale, ct), Plans.NoteFeature)
                : (await PhotosAsync(import, locale, ct), "passport-scan");
            if (message is null)
            {
                // A photo gone from storage (or a note thrown away meanwhile, whose draft nobody waits for).
                error = AiImportError.PhotosMissing;
            }
            else
            {
                var scan = await runner.RunAsync<PassportScan>(AiOptions.Extraction, feature, import.HouseholdId, [message], ct);
                scanJson = JsonSerializer.Serialize(scan.Value, AiRunner.Json);
                model = scan.Model;
            }
        }
        catch (AiUnavailableException e)
        {
            log.LogWarning(e, "AI import {ImportId}: no model could answer.", importId);
            error = e.NotConfigured ? AiImportError.NotConfigured : AiImportError.Busy;
        }
        catch (AiRejectedException e)
        {
            log.LogError(e, "AI import {ImportId}: the provider refused the request.", importId);
            error = AiImportError.Rejected;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // The app is stopping: back in the queue, to be read again after the restart.
            await db.AiImports
                .Where(i => i.Id == importId && i.Status == AiImportStatus.Processing)
                .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, AiImportStatus.Queued), CancellationToken.None);
            throw;
        }
        catch (Exception e)
        {
            log.LogError(e, "AI import {ImportId} failed.", importId);
            error = AiImportError.Unexpected;
        }

        // Only an import still being read gets the result: one the user threw away meanwhile stays thrown away.
        var status = error is null ? AiImportStatus.Ready : AiImportStatus.Failed;
        var provider = model?.Provider;
        var modelName = model?.Model;
        await db.AiImports
            .Where(i => i.Id == importId && i.Status == AiImportStatus.Processing)
            .ExecuteUpdateAsync(s => s
                .SetProperty(i => i.Status, status)
                .SetProperty(i => i.ScanJson, scanJson)
                .SetProperty(i => i.Error, error)
                .SetProperty(i => i.Provider, provider)
                .SetProperty(i => i.Model, modelName)
                .SetProperty(i => i.PromptVersion,
                    import.Source == AiImportSource.Text ? TextEntryPrompt.Version : PassportScanPrompt.Version)
                .SetProperty(i => i.CompletedAt, clock.GetUtcNow()), CancellationToken.None);

        // The photos held when the scan started: spent if AI answered (also when the scan was thrown away meanwhile),
        // given back if not.
        await plans.SettleImportAsync(importId, answered: error is null, CancellationToken.None);

        // The scan is ready to check (or failed): the pet's passport shows it on every phone of the household.
        await live.ChangedAsync(import.HouseholdId, [LiveTopics.Imports]);
    }

    /// <summary>The prompt and the photos; null when a photo is gone from storage.</summary>
    private async Task<ChatMessage?> PhotosAsync(AiImport import, string locale, CancellationToken ct)
    {
        var photos = await files.ReadAsync(import.HouseholdId, import.FileIds, ct);
        return photos.Count < import.FileIds.Count
            ? null
            : new ChatMessage(ChatRole.User,
            [
                new TextContent(PassportScanPrompt.For(locale, import.Source)),
                .. photos.Select(p => (AIContent)new DataContent(p.Content, p.File.ContentType)),
            ]);
    }

    /// <summary>
    /// The note with what the model needs to read it: the pet's name and species, and the household's date of the day
    /// the note was written, which "yesterday" is counted from (a note read after midnight, or tried again the next day,
    /// still means the day before it was written). Null when the note was thrown away meanwhile: nothing to read.
    /// </summary>
    private async Task<ChatMessage?> NoteAsync(AiImport import, string locale, CancellationToken ct)
    {
        if (import.Text is not { } text)
        {
            return null;
        }

        var pet = (await pets.CardsAsync(import.HouseholdId, ct)).Single(p => p.Id == import.PetId);
        var writtenOn = await calendar.DateAtAsync(import.HouseholdId, import.CreatedAt, ct);
        return new ChatMessage(ChatRole.User, TextEntryPrompt.For(locale, writtenOn, pet.Name, pet.Species, text));
    }
}

/// <summary>
/// Processes queued imports one at a time: at once when told through <see cref="AiImportQueue"/>, and every
/// half minute it also looks for imports nobody announced (left over from before a restart).
/// </summary>
internal sealed class AiImportWorker(
    IServiceScopeFactory scopes,
    AiImportQueue queue,
    TimeProvider clock,
    ILogger<AiImportWorker> log) : BackgroundService
{
    private static readonly TimeSpan LookAgainAfter = TimeSpan.FromSeconds(30);

    /// <summary>A model answers within a few minutes; an import "processing" longer was cut off.</summary>
    private static readonly TimeSpan StuckAfter = TimeSpan.FromMinutes(10);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // The first look is at once: imports cut off by a restart are read again right away.
        var justStarted = true;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var work = justStarted ? await LeftoversAsync(justStarted: true, stoppingToken) : await WaitForWorkAsync(stoppingToken);
                justStarted = false;
                foreach (var importId in work)
                {
                    await using var scope = scopes.CreateAsyncScope();
                    await scope.ServiceProvider.GetRequiredService<AiImportProcessor>().ProcessAsync(importId, stoppingToken);
                }
            }
            catch (Exception e) when (!stoppingToken.IsCancellationRequested)
            {
                log.LogError(e, "AI import worker failed; it carries on.");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }

    private async Task<List<Guid>> WaitForWorkAsync(CancellationToken stoppingToken)
    {
        using var wait = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
        wait.CancelAfter(LookAgainAfter);
        try
        {
            return [await queue.Reader.ReadAsync(wait.Token)];
        }
        catch (OperationCanceledException) when (!stoppingToken.IsCancellationRequested)
        {
            return await LeftoversAsync(justStarted: false, stoppingToken);
        }
    }

    /// <summary>Queued imports nobody announced, oldest first, after putting cut-off ones back in the queue.</summary>
    private async Task<List<Guid>> LeftoversAsync(bool justStarted, CancellationToken ct)
    {
        await using var scope = scopes.CreateAsyncScope();
        return await RequeueAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), justStarted, clock.GetUtcNow(), ct);
    }

    /// <summary>
    /// Right after a start nothing is being read yet, so every import marked "processing" was cut off by the restart
    /// (the API runs as one instance). Later only one "processing" for longer than <see cref="StuckAfter"/> is.
    /// </summary>
    internal static async Task<List<Guid>> RequeueAsync(AppDbContext db, bool justStarted, DateTimeOffset now, CancellationToken ct)
    {
        var stuckSince = now - StuckAfter;
        await db.AiImports
            .Where(i => i.Status == AiImportStatus.Processing && (justStarted || i.StartedAt < stuckSince))
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, AiImportStatus.Queued), ct);
        return await db.AiImports
            .Where(i => i.Status == AiImportStatus.Queued)
            .OrderBy(i => i.CreatedAt)
            .Select(i => i.Id)
            .ToListAsync(ct);
    }
}
