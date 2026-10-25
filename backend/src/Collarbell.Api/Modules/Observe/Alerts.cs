using System.Globalization;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Notifications;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Modules.Observe;

public sealed class AlertsOptions
{
    /// <summary>The Telegram bot's token (from @BotFather); without it alerts only go to the log.</summary>
    public string? TelegramBotToken { get; set; }

    /// <summary>The chat the bot writes to: the owner's private chat with it.</summary>
    public string? TelegramChatId { get; set; }

    /// <summary>How often the server looks at itself; zero turns the checks off (the tests run them).</summary>
    public TimeSpan CheckInterval { get; set; } = TimeSpan.FromMinutes(5);

    /// <summary>The same kind of trouble is told again only after this long.</summary>
    public TimeSpan RepeatAfter { get; set; } = TimeSpan.FromHours(6);

    public bool TelegramConfigured => !string.IsNullOrWhiteSpace(TelegramBotToken) && !string.IsNullOrWhiteSpace(TelegramChatId);
}

/// <summary>Where alerts go: the owner's Telegram, or the log when it isn't set up. A fake in the tests.</summary>
public interface IAlertSender
{
    Task SendAsync(string text, CancellationToken ct);
}

public sealed class TelegramAlertSender(HttpClient http, IOptions<AlertsOptions> options, ILogger<TelegramAlertSender> log) : IAlertSender
{
    public async Task SendAsync(string text, CancellationToken ct)
    {
        var o = options.Value;
        if (!o.TelegramConfigured)
        {
            log.LogWarning("Alert (Telegram isn't set up): {Text}", text);
            return;
        }

        // The address holds the token: this client logs nothing (Program.cs), and errors say only the status.
        using var response = await http.PostAsJsonAsync($"https://api.telegram.org/bot{o.TelegramBotToken}/sendMessage",
            new { chat_id = o.TelegramChatId, text, disable_web_page_preview = true }, ct);
        if (!response.IsSuccessStatusCode)
        {
            // Not sent: the alert isn't marked as told and goes again on the next check.
            throw new InvalidOperationException($"Telegram refused the alert: {(int)response.StatusCode}.");
        }
    }
}

/// <summary>
/// What the server watches about itself, every few minutes (admin and Telegram): reminders that are late or fail, server
/// errors, the AI failing, the nightly backup, the disk. Each kind is told at most every <see cref="AlertsOptions.RepeatAfter"/>.
/// </summary>
public sealed class AlertChecks(AppDbContext db, IAlertSender sender, IOptions<AlertsOptions> alerts, IOptions<ObserveOptions> observe,
    ILogger<AlertChecks> log)
{
    /// <summary>The nightly copy runs at 02:00 UTC; older than this, a night was missed.</summary>
    private static readonly TimeSpan BackupMaxAge = TimeSpan.FromHours(26);

    public async Task<List<(string Kind, string Text)>> RunOnceAsync(DateTimeOffset now, CancellationToken ct)
    {
        var found = new List<(string Kind, string Text)>();

        var oldestLate = await db.Reminders
            .Where(r => r.Status == ReminderStatus.Pending && r.FireAt < now - TimeSpan.FromMinutes(10))
            .OrderBy(r => r.FireAt)
            .Select(r => (DateTimeOffset?)r.FireAt)
            .FirstOrDefaultAsync(ct);
        if (oldestLate is { } late)
        {
            found.Add(("reminders-late", $"Напоминания задерживаются: самое старое ждёт {(int)(now - late).TotalMinutes} мин."));
        }

        var failedReminders = await db.Reminders.CountAsync(r => r.Status == ReminderStatus.Failed && r.FireAt > now - TimeSpan.FromHours(1), ct);
        if (failedReminders >= 3)
        {
            found.Add(("reminders-failed", $"За час не ушло напоминаний: {failedReminders}."));
        }

        var serverErrors = await db.Requests.CountAsync(r => r.Status >= 500 && r.At > now - TimeSpan.FromMinutes(15), ct);
        if (serverErrors >= 5)
        {
            found.Add(("server-errors", $"Ошибок сервера за 15 минут: {serverErrors}."));
        }

        var aiCalls = await db.AiUsage.Where(u => u.CreatedAt > now - TimeSpan.FromHours(1))
            .GroupBy(_ => 1)
            .Select(g => new { Failed = g.Count(u => !u.Success), Answered = g.Count(u => u.Success) })
            .SingleOrDefaultAsync(ct);
        if (aiCalls is { Failed: >= 5, Answered: 0 })
        {
            found.Add(("ai-failing", $"AI не отвечает: ошибок за час — {aiCalls.Failed}, ответов нет."));
        }

        // Deleted accounts whose Firebase sign-in is still there after an hour of tries: the key may have lost its rights.
        var stuckSignIns = await db.DeletedAccounts.CountAsync(d => d.SignInDeletedAt == null && d.DeletedAt < now - TimeSpan.FromHours(1), ct);
        if (stuckSignIns > 0)
        {
            found.Add(("sign-in-deletion",
                $"Не удаётся удалить вход в Firebase у удалённых аккаунтов: {stuckSignIns}. Проверьте ключ Firebase на сервере."));
        }

        var backup = ServerState.LastBackup(observe.Value.BackupDir);
        var dataOlderThanANight = backup is { At: null, Unreadable: false }
            && await db.Users.AnyAsync(u => u.CreatedAt < now - BackupMaxAge, ct);
        if (BackupTrouble(backup, now, dataOlderThanANight) is { } trouble)
        {
            found.Add(trouble);
        }

        var disk = ServerState.Disk();
        if (disk.TotalBytes > 0 && disk.FreeBytes < disk.TotalBytes / 10)
        {
            found.Add(("disk-low", $"Мало места на диске: свободно {ServerState.Gb(disk.FreeBytes)} из {ServerState.Gb(disk.TotalBytes)}."));
        }

        var known = await db.Alerts.ToDictionaryAsync(a => a.Kind, ct);
        foreach (var (kind, text) in found)
        {
            if (known.TryGetValue(kind, out var last) && now - last.SentAt < alerts.Value.RepeatAfter)
            {
                continue;
            }

            try
            {
                await sender.SendAsync($"Collarbell: {text}", ct);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "The alert '{Kind}' wasn't sent.", kind);
                continue;
            }

            if (last is null)
            {
                db.Alerts.Add(new AlertRecord(kind, text, now));
            }
            else
            {
                last.Text = text;
                last.SentAt = now;
            }
        }

        await db.SaveChangesAsync(ct);
        return found;
    }

    /// <summary>
    /// What is wrong with the backups, if anything: the folder can't be read, the newest copy missed a night, or there
    /// is none at all while there is data older than a night (a new server waits for its first 02:00). Null without a
    /// backup folder (locally).
    /// </summary>
    internal static (string Kind, string Text)? BackupTrouble(BackupState? backup, DateTimeOffset now, bool dataOlderThanANight) =>
        backup switch
        {
            { Unreadable: true } => ("backup-unreadable", "Не вижу папку бэкапов: проверьте, что она подключена к API и открыта на чтение."),
            { At: { } at } when now - at > BackupMaxAge => ("backup-old", $"Бэкап базы не обновлялся {(int)(now - at).TotalHours} ч."),
            { At: null } when dataOlderThanANight => ("backup-missing", "Бэкапов базы нет ни одного: проверьте контейнер backup."),
            _ => null,
        };
}

public sealed class AlertWorker(IServiceScopeFactory scopes, IOptions<AlertsOptions> options, TimeProvider clock, ILogger<AlertWorker> log)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = options.Value.CheckInterval;
        if (interval <= TimeSpan.Zero)
        {
            return;
        }

        // Let the API settle after a start before judging it.
        await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<AlertChecks>().RunOnceAsync(clock.GetUtcNow(), stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception e)
            {
                log.LogWarning(e, "The server's self-check failed; trying again later.");
            }

            await Task.Delay(interval, stoppingToken);
        }
    }
}

public sealed record BackupState(DateTimeOffset? At, long? Bytes, bool Unreadable);

/// <summary>The server's disk and backups, as the admin and the alerts see them.</summary>
public static class ServerState
{
    public static (long TotalBytes, long FreeBytes) Disk()
    {
        try
        {
            var root = new DriveInfo("/");
            return (root.TotalSize, root.AvailableFreeSpace);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            return (0, 0);
        }
    }

    /// <summary>
    /// The newest database copy (db-YYYY-MM-DD.dump, deploy/backup.sh): its time and size; <c>At</c> null before the first
    /// night; <c>Unreadable</c> when the folder is set but missing or closed to the API's user. Null without a folder (locally).
    /// </summary>
    public static BackupState? LastBackup(string? dir)
    {
        if (string.IsNullOrWhiteSpace(dir))
        {
            return null;
        }

        try
        {
            var newest = new DirectoryInfo(dir).GetFiles("db-*.dump").MaxBy(f => f.LastWriteTimeUtc);
            return newest is null
                ? new BackupState(null, null, false)
                : new BackupState(new DateTimeOffset(newest.LastWriteTimeUtc, TimeSpan.Zero), newest.Length, false);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            return new BackupState(null, null, true);
        }
    }

    public static string Gb(long bytes) => $"{(bytes / 1024d / 1024 / 1024).ToString("0.#", CultureInfo.GetCultureInfo("ru-RU"))} ГБ";
}
