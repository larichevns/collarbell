using Collarbell.Api.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Modules.Notifications;

/// <summary>
/// Sends the reminders that are due (spec 5.4, system-design 3.3 flow 1). For each one it asks its module whether it
/// is still needed and what it says, then pushes it to the phones of everyone in the household who wants that kind.
/// </summary>
public sealed class ReminderDispatcher(
    AppDbContext db,
    IEnumerable<IReminderSource> sources,
    IPushSender push,
    ILogger<ReminderDispatcher> log)
{
    public const int BatchSize = 100;

    /// <summary>Waits before the next tries when Firebase was busy or unreachable; after the last one, the reminder failed.</summary>
    public static readonly TimeSpan[] RetryDelays = [TimeSpan.FromMinutes(1), TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(15)];

    /// <summary>
    /// How late a reminder may still go out, e.g. after the server was off (system-design 3.5). "Time to feed" an hour
    /// late is useless, a vaccination reminder a few hours late is still worth it. Later ones expire unsent.
    /// </summary>
    public static TimeSpan CatchUpWindow(NotificationCategory category) => category switch
    {
        NotificationCategory.Feeding => TimeSpan.FromMinutes(30),
        _ => TimeSpan.FromDays(1),
    };

    /// <summary>Handles everything due at <paramref name="now"/>, a batch at a time. Returns how many reminders it handled.</summary>
    public async Task<int> RunOnceAsync(DateTimeOffset now, CancellationToken ct)
    {
        now = now.ToUniversalTime();
        var handled = 0;
        while (true)
        {
            // The batch is retried as a whole when the database connection fails; a push sent twice shows once,
            // because the second one has the same tag and replaces the first on the phone.
            var count = await db.Database.CreateExecutionStrategy().ExecuteAsync(token => SendBatchAsync(now, token), ct);
            handled += count;
            if (count < BatchSize)
            {
                return handled;
            }
        }
    }

    private async Task<int> SendBatchAsync(DateTimeOffset now, CancellationToken ct)
    {
        db.ChangeTracker.Clear();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        // The rows stay locked until the end, so two servers never send the same reminder; SKIP LOCKED makes the
        // second one take other reminders instead of waiting.
        // Reminders of one household and moment side by side, so a batch rarely splits what makes one push.
        var due = await db.Reminders
            .FromSql($"""
                SELECT * FROM notifications.reminders
                WHERE status = 'Pending' AND due_at <= {now}
                ORDER BY due_at, household_id, category, fire_at
                LIMIT {BatchSize}
                FOR UPDATE SKIP LOCKED
                """)
            .ToListAsync(ct);
        if (due.Count == 0)
        {
            return 0;
        }

        await HandleAsync(due, transaction, now, ct);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return due.Count;
    }

    private async Task HandleAsync(List<Reminder> due, IDbContextTransaction transaction, DateTimeOffset now, CancellationToken ct)
    {
        // 1. What each reminder says now. The module leaves out what is no longer needed: fed already, done, cancelled.
        var (contents, deferred) = await ComposeAsync(due, transaction, now, ct);

        var toSend = new List<(Reminder Reminder, ReminderContent Content)>();
        foreach (var reminder in due)
        {
            if (deferred.Contains(reminder.Id))
            {
                continue;
            }

            if (!contents.TryGetValue(reminder.Id, out var content))
            {
                Finish(reminder, ReminderStatus.Skipped, ReminderReason.NotNeeded, now);
            }
            else if (now - reminder.FireAt > CatchUpWindow(reminder.Category))
            {
                Finish(reminder, ReminderStatus.Expired, reason: null, now);
            }
            else if (!push.IsConfigured)
            {
                Finish(reminder, ReminderStatus.Skipped, ReminderReason.PushNotConfigured, now);
            }
            else
            {
                toSend.Add((reminder, content));
            }
        }

        if (toSend.Count == 0)
        {
            return;
        }

        // 2. One push per household, kind and moment: two cats fed at 8:00, or three plans due the same day, make one.
        // Visits don't merge: each has its own time and place to say.
        var recipients = await PushRecipients.OfAsync(db, [.. toSend.Select(x => x.Reminder.HouseholdId).Distinct()], ct);
        var invalidTokens = new HashSet<string>();
        foreach (var group in toSend.GroupBy(x => (
            x.Reminder.HouseholdId,
            x.Reminder.Category,
            x.Reminder.FireAt,
            Visit: x.Reminder.Category == NotificationCategory.Appointments ? x.Reminder.SourceId : Guid.Empty,
            // One feeding time is one reminder already; a follow-up of 08:00 and the 08:30 feeding stay two pushes.
            Feeding: x.Reminder.Category == NotificationCategory.Feeding ? x.Reminder.Key : null)))
        {
            var reminders = group.Select(x => x.Reminder).ToList();
            var people = recipients.GetValueOrDefault(group.Key.HouseholdId, [])
                .Where(p => !p.Off.Contains(group.Key.Category) && p.Tokens.Count > 0)
                .ToList();
            if (people.Count == 0)
            {
                reminders.ForEach(r => Finish(r, ReminderStatus.Skipped, ReminderReason.NoRecipients, now));
                continue;
            }

            var results = new List<PushResult>();
            foreach (var person in people)
            {
                var message = ReminderTexts.InHousehold(
                    ReminderTexts.Compose([.. group.Select(x => x.Content)], person.Locale, now), group.Key.HouseholdId);
                var sent = await push.SendAsync(message, person.Tokens, ct);
                results.AddRange(sent);
                invalidTokens.UnionWith(person.Tokens.Where((_, i) => sent[i] == PushResult.InvalidToken));
            }

            // 3. Sent if at least one phone got it; another try later if Firebase was only busy.
            foreach (var reminder in reminders)
            {
                if (results.Contains(PushResult.Delivered))
                {
                    Finish(reminder, ReminderStatus.Sent, reason: null, now);
                }
                else if (results.All(r => r == PushResult.InvalidToken))
                {
                    Finish(reminder, ReminderStatus.Skipped, ReminderReason.NoRecipients, now);
                }
                else
                {
                    TryLater(reminder, canRetry: results.Contains(PushResult.TryAgain), now);
                }
            }
        }

        // 4. Phones whose app was removed: Firebase won't deliver to them again. Deleted by token, so a phone that
        // registered again a moment ago (or was forgotten already) can't make the batch fail.
        if (invalidTokens.Count > 0)
        {
            var gone = await db.Devices.Where(d => invalidTokens.Contains(d.Token)).ExecuteDeleteAsync(ct);
            log.LogInformation("Forgot {Count} phone(s) that Firebase no longer knows.", gone);
        }
    }

    /// <summary>
    /// Asks each module what its due reminders say. A module that fails puts its reminders off for another try
    /// (<c>Deferred</c>); a savepoint undoes what its failure did to the transaction, so the others still go out.
    /// </summary>
    private async Task<(Dictionary<Guid, ReminderContent> Contents, HashSet<Guid> Deferred)> ComposeAsync(
        List<Reminder> due, IDbContextTransaction transaction, DateTimeOffset now, CancellationToken ct)
    {
        var householdIds = due.Select(r => r.HouseholdId).Distinct().ToList();
        var zones = await db.Households
            .Where(h => householdIds.Contains(h.Id))
            .ToDictionaryAsync(h => h.Id, h => h.TimeZone, ct);

        var contents = new Dictionary<Guid, ReminderContent>();
        var deferred = new HashSet<Guid>();
        foreach (var group in due.GroupBy(r => r.Source))
        {
            var source = sources.Single(s => s.Source == group.Key);
            var asked = group
                .Select(r => new DueReminder(r.Id, r.HouseholdId, zones.GetValueOrDefault(r.HouseholdId, "UTC"), r.SourceId, r.Key, r.FireAt))
                .ToList();
            await transaction.CreateSavepointAsync("compose", ct);
            try
            {
                foreach (var (id, content) in await source.ComposeAsync(asked, now, ct))
                {
                    contents[id] = content;
                }
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                await transaction.RollbackToSavepointAsync("compose", ct);
                log.LogError(e, "{Source} reminders couldn't be composed; they are tried again later.", group.Key);
                foreach (var reminder in group)
                {
                    TryLater(reminder, canRetry: true, now);
                    deferred.Add(reminder.Id);
                }
            }
        }

        return (contents, deferred);
    }

    private static void Finish(Reminder reminder, ReminderStatus status, ReminderReason? reason, DateTimeOffset now)
    {
        reminder.Status = status;
        reminder.Reason = reason;
        if (status == ReminderStatus.Sent)
        {
            reminder.SentAt = now;
        }
    }

    private static void TryLater(Reminder reminder, bool canRetry, DateTimeOffset now)
    {
        reminder.Attempts++;
        if (canRetry && reminder.Attempts <= RetryDelays.Length)
        {
            reminder.DueAt = now + RetryDelays[reminder.Attempts - 1];
        }
        else
        {
            Finish(reminder, ReminderStatus.Failed, ReminderReason.SendFailed, now);
        }
    }
}

/// <summary>Runs the dispatcher every <see cref="NotificationsOptions.DispatchInterval"/>.</summary>
internal sealed class ReminderDispatcherWorker(
    IServiceScopeFactory scopes,
    IOptions<NotificationsOptions> options,
    TimeProvider clock,
    ILogger<ReminderDispatcherWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = options.Value.DispatchInterval;
        if (interval <= TimeSpan.Zero)
        {
            return;
        }

        // The first run is at once: what came due while the server was off goes out (or expires) right away.
        using var timer = new PeriodicTimer(interval);
        do
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<ReminderDispatcher>().RunOnceAsync(clock.GetUtcNow(), stoppingToken);
            }
            catch (Exception e) when (!stoppingToken.IsCancellationRequested)
            {
                log.LogError(e, "Sending reminders failed; it runs again on the next tick.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}

/// <summary>Plans every household's reminders every <see cref="NotificationsOptions.PlanInterval"/> (and at start).</summary>
internal sealed class ReminderPlanner(
    IServiceScopeFactory scopes,
    IOptions<NotificationsOptions> options,
    TimeProvider clock,
    ILogger<ReminderPlanner> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = options.Value.PlanInterval;
        if (interval <= TimeSpan.Zero)
        {
            return;
        }

        using var timer = new PeriodicTimer(interval);
        do
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<ReminderSchedule>().PlanAllAsync(clock.GetUtcNow(), stoppingToken);
            }
            catch (Exception e) when (!stoppingToken.IsCancellationRequested)
            {
                log.LogError(e, "Planning reminders failed; it runs again on the next tick.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
