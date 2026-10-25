using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Notifications;

/// <summary>A reminder a module wants: which occasion of which of its things, when, and what it is about.</summary>
public sealed record PlannedReminder(Guid SourceId, string Key, DateTimeOffset FireAt, string Subject);

/// <summary>A due reminder, as its module sees it when the push is about to go.</summary>
public sealed record DueReminder(Guid Id, Guid HouseholdId, string TimeZone, Guid SourceId, string Key, DateTimeOffset FireAt);

/// <summary>
/// A module with things to remind about: Care (plans), Appointments (visits), Routines (feeding). Notifications
/// doesn't know plans or visits, it asks the sources, the way Pets asks <c>IPetDeletionHandler</c>.
/// </summary>
public interface IReminderSource
{
    ReminderSource Source { get; }

    NotificationCategory Category { get; }

    /// <summary>
    /// The reminders the household should get, local times in the household's <paramref name="timeZone"/>: the coming
    /// ones, and those of the last day. Past ones never become new reminders; they only move a reminder still waiting
    /// (a new time zone put its occasion an hour ago: it goes out now, late, instead of not at all).
    /// </summary>
    Task<IReadOnlyList<PlannedReminder>> PlanAsync(Guid householdId, string timeZone, DateTimeOffset now, CancellationToken ct);

    /// <summary>
    /// Just before sending: what each due reminder says. A reminder left out of the answer is no longer needed
    /// (done, cancelled, moved to another date, paused, deleted) and is skipped.
    /// </summary>
    Task<IReadOnlyDictionary<Guid, ReminderContent>> ComposeAsync(IReadOnlyList<DueReminder> due, DateTimeOffset now, CancellationToken ct);
}

/// <summary>
/// Keeps a household's waiting reminders in step with its plans, visits and feeding times (spec 5.4). Modules call
/// <see cref="RefreshAsync"/> after saving a change. A background run refreshes every household every few minutes as
/// well (<see cref="ReminderPlanner"/>): it plans feeding times 48 hours ahead and heals a refresh that didn't happen.
/// </summary>
public sealed class ReminderSchedule(
    AppDbContext db,
    IEnumerable<IReminderSource> sources,
    TimeProvider clock,
    ILogger<ReminderSchedule> log) : IHouseholdChangeHandler
{
    /// <summary>
    /// Plans the household's reminders again. The change that called it is already saved, so a failure here doesn't
    /// undo it: it is logged and the next background run plans the reminders instead.
    /// </summary>
    public async Task RefreshAsync(Guid householdId, CancellationToken ct)
    {
        try
        {
            await PlanAsync(householdId, clock.GetUtcNow(), ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            log.LogWarning(e, "Reminders of household {HouseholdId} weren't planned; the background run will.", householdId);
            foreach (var entry in db.ChangeTracker.Entries<Reminder>().ToList())
            {
                entry.State = EntityState.Detached;
            }
        }
    }

    /// <summary>A pet was paused, renamed or deleted, or the time zone changed: plan the reminders again.</summary>
    public Task HouseholdChangedAsync(Guid householdId, CancellationToken ct) => RefreshAsync(householdId, ct);

    /// <summary>
    /// Makes the household's waiting reminders exactly the ones its modules want:
    /// <list type="bullet">
    /// <item>a wanted reminder that doesn't exist yet is added, if its time is still to come;</item>
    /// <item>a waiting one gets the time and subject wanted now (a plan moved, the time zone changed);</item>
    /// <item>a waiting one nobody wants any more goes (a plan done, a visit cancelled);</item>
    /// <item>one already sent or skipped stays as it was: an occasion is never reminded twice.</item>
    /// </list>
    /// Reminders that are due but not yet sent are left to the dispatcher, which checks them itself. A module whose
    /// planning fails keeps its waiting reminders and doesn't stop the other modules' ones.
    /// </summary>
    internal async Task PlanAsync(Guid householdId, DateTimeOffset now, CancellationToken ct)
    {
        var timeZone = await db.Households.Where(h => h.Id == householdId).Select(h => h.TimeZone).SingleOrDefaultAsync(ct);
        if (timeZone is null)
        {
            return;
        }

        var wanted = new Dictionary<(ReminderSource, Guid, string), (NotificationCategory Category, PlannedReminder Plan)>();
        var failed = new HashSet<ReminderSource>();
        foreach (var source in sources)
        {
            IReadOnlyList<PlannedReminder> plans;
            try
            {
                plans = await source.PlanAsync(householdId, timeZone, now, ct);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "{Source} reminders of household {HouseholdId} couldn't be planned.", source.Source, householdId);
                failed.Add(source.Source);
                continue;
            }

            foreach (var plan in plans)
            {
                wanted.TryAdd((source.Source, plan.SourceId, plan.Key), (source.Category, plan with { Subject = Fit(plan.Subject) }));
            }
        }

        // Everything still waiting, and what went out lately: a new time zone can move an occasion that was
        // already reminded into the future again, and it must not be reminded twice.
        var lately = now - TimeSpan.FromDays(2);
        var existing = await db.Reminders
            .Where(r => r.HouseholdId == householdId && (r.Status == ReminderStatus.Pending || r.FireAt > lately))
            .ToDictionaryAsync(r => (r.Source, r.SourceId, r.Key), ct);

        // A wanted occasion handled longer ago, whose time moved into the future again (e.g. a supply's delivery time
        // changed): it was reminded already, and adding it again would break the unique key and with it the whole
        // household's planning.
        var unknownIds = wanted.Keys.Where(k => !existing.ContainsKey(k)).Select(k => k.Item2).Distinct().ToList();
        if (unknownIds.Count > 0)
        {
            var older = await db.Reminders
                .Where(r => r.HouseholdId == householdId && unknownIds.Contains(r.SourceId))
                .ToListAsync(ct);
            foreach (var reminder in older)
            {
                existing.TryAdd((reminder.Source, reminder.SourceId, reminder.Key), reminder);
            }
        }

        foreach (var (key, reminder) in existing)
        {
            if (reminder.Status == ReminderStatus.Pending && reminder.FireAt > now && !wanted.ContainsKey(key)
                && !failed.Contains(reminder.Source))
            {
                db.Reminders.Remove(reminder);
            }
        }

        foreach (var (key, (category, plan)) in wanted)
        {
            if (!existing.TryGetValue(key, out var reminder))
            {
                if (plan.FireAt > now)
                {
                    db.Reminders.Add(new Reminder(householdId, key.Item1, plan.SourceId, plan.Key, category, plan.FireAt, plan.Subject, now));
                }

                continue;
            }

            if (reminder.Status != ReminderStatus.Pending)
            {
                continue;
            }

            if (reminder.FireAt != plan.FireAt)
            {
                reminder.FireAt = plan.FireAt;
                reminder.DueAt = plan.FireAt;
                reminder.Attempts = 0;
            }

            reminder.Subject = plan.Subject;
            reminder.Category = category;
        }

        await db.SaveChangesAsync(ct);
    }

    /// <summary>
    /// The background run: plans every household's reminders and forgets ones that went out (or didn't) more than
    /// <see cref="HistoryDays"/> days ago.
    /// </summary>
    internal async Task PlanAllAsync(DateTimeOffset now, CancellationToken ct)
    {
        var households = await db.Households.Select(h => h.Id).ToListAsync(ct);
        foreach (var householdId in households)
        {
            try
            {
                await PlanAsync(householdId, now, ct);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "Reminders of household {HouseholdId} couldn't be planned.", householdId);
            }

            // A fresh start for the next household, also after a failure.
            db.ChangeTracker.Clear();
        }

        var forgetBefore = now - TimeSpan.FromDays(HistoryDays);
        await db.Reminders
            .Where(r => r.Status != ReminderStatus.Pending && r.FireAt < forgetBefore)
            .ExecuteDeleteAsync(ct);
    }

    /// <summary>How long sent, skipped and expired reminders stay for the list of recent reminders.</summary>
    public const int HistoryDays = 30;

    /// <summary>The longest subject kept (the column's length); a longer one is cut with "…".</summary>
    public const int MaxSubjectLength = 300;

    private static string Fit(string subject) =>
        subject.Length <= MaxSubjectLength ? subject : subject[..(MaxSubjectLength - 1)] + "…";
}
