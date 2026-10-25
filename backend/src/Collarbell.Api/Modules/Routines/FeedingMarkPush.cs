using System.Globalization;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Routines;

/// <summary>
/// After a feeding is marked, the others learn it on their phones (spec 2, "Семья": "остальные видят, кто и когда"):
/// the reminder of that feeding time, already there, is replaced quietly (Android channel <see cref="Channel"/>, the
/// reminder's tag) by who fed whom and who is still waiting. Only when the reminder went out, so nothing appears out of
/// the blue; the one who marked gets nothing. A failed push never fails the mark.
/// </summary>
public sealed class FeedingMarkPush(AppDbContext db, PetDirectory pets, IPushSender push, ILogger<FeedingMarkPush> log)
{
    /// <summary>The app's quiet channel for these updates: no sound, no pop-up.</summary>
    public const string Channel = "feeding-updates";

    public async Task SendAsync(Guid householdId, DateOnly date, TimeOnly time, Guid markedBy, CancellationToken ct)
    {
        try
        {
            if (!push.IsConfigured || !await ReminderWentOutAsync(householdId, date, time, ct))
            {
                return;
            }

            var recipients = (await PushRecipients.OfAsync(db, [householdId], ct)).GetValueOrDefault(householdId, [])
                .Where(r => r.UserId != markedBy && !r.Off.Contains(NotificationCategory.Feeding) && r.Tokens.Count > 0)
                .ToList();
            if (recipients.Count == 0)
            {
                return;
            }

            var slot = await SlotAsync(householdId, date, time, ct);
            foreach (var recipient in recipients)
            {
                var message = ReminderTexts.InHousehold(Compose(slot, date, time, recipient.Locale == Locales.Russian), householdId);
                await push.SendAsync(message, recipient.Tokens, ct);
            }
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            log.LogWarning(e, "The 'who fed' push for {Date} {Time} wasn't sent.", date, time);
        }
    }

    private Task<bool> ReminderWentOutAsync(Guid householdId, DateOnly date, TimeOnly time, CancellationToken ct)
    {
        var key = FeedingReminders.Key(date, time);
        var followUp = key + FeedingReminders.FollowUpSuffix;
        return db.Reminders.AnyAsync(r => r.HouseholdId == householdId && r.Source == ReminderSource.Feeding
            && (r.Key == key || r.Key == followUp) && r.Status == ReminderStatus.Sent, ct);
    }

    /// <summary>The feeding time as it is now: each pet with its mark (who, when, fed or skipped) or none yet.</summary>
    private async Task<List<(string Pet, CompletionStatus? Status, string? By, TimeOnly? At)>> SlotAsync(
        Guid householdId, DateOnly date, TimeOnly time, CancellationToken ct)
    {
        var active = (await pets.CardsAsync(householdId, ct))
            .Where(p => p.Status == PetStatus.Active)
            .ToDictionary(p => p.Id, p => p.Name);
        var routines = (await db.Routines.AsNoTracking()
                .Where(r => r.HouseholdId == householdId && r.Active && r.Kind == RoutineKind.Feeding)
                .ToListAsync(ct))
            .Where(r => active.ContainsKey(r.PetId) && r.OccursAt(date, time))
            .ToList();
        var ids = routines.Select(r => r.Id).ToList();
        var marks = await db.RoutineCompletions.AsNoTracking()
            .Where(c => ids.Contains(c.RoutineId) && c.Date == date && c.Time == time)
            .ToDictionaryAsync(c => c.RoutineId, ct);

        // Display names only: a helper doesn't see the others' e-mails.
        var people = marks.Values.Select(m => m.DoneBy).OfType<Guid>().Distinct().ToList();
        var names = await db.Users.AsNoTracking()
            .Where(u => people.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.DisplayName, ct);
        var timeZone = await db.Households.AsNoTracking().Where(h => h.Id == householdId).Select(h => h.TimeZone).SingleAsync(ct);

        return [.. routines
            .Select(r => marks.TryGetValue(r.Id, out var mark)
                ? (active[r.PetId], (CompletionStatus?)mark.Status, mark.DoneBy is { } by ? names.GetValueOrDefault(by) : null,
                    (TimeOnly?)LocalTimes.LocalAt(mark.DoneAt, timeZone).Time)
                : (active[r.PetId], null, null, null))
            .OrderBy(p => p.Item1, StringComparer.CurrentCulture)];
    }

    /// <summary>"All fed · 08:00" — "Murka — Anna, 08:02 · Barsik — 08:05"; or what is still waiting.</summary>
    private static PushMessage Compose(
        List<(string Pet, CompletionStatus? Status, string? By, TimeOnly? At)> slot, DateOnly date, TimeOnly time, bool ru)
    {
        var at = time.ToString("HH:mm", CultureInfo.InvariantCulture);
        string Mark((string Pet, CompletionStatus? Status, string? By, TimeOnly? At) p)
        {
            var who = string.Join(", ", new[] { p.By, p.At?.ToString("HH:mm", CultureInfo.InvariantCulture) }.Where(s => s is not null));
            var skipped = p.Status == CompletionStatus.Skipped ? (ru ? "пропущено" : "skipped") : null;
            return $"{p.Pet} — {string.Join(", ", new[] { skipped, who }.Where(s => !string.IsNullOrEmpty(s)))}";
        }

        var marked = slot.Where(p => p.Status is not null).Select(Mark).ToList();
        var waiting = slot.Where(p => p.Status is null).Select(p => p.Pet).ToList();
        var title = waiting.Count == 0
            ? ru ? $"Все накормлены · {at}" : $"All fed · {at}"
            : ru ? $"Кормление в {at}" : $"Feeding at {at}";
        var body = string.Join(" · ", marked);
        if (waiting.Count > 0)
        {
            body += (body.Length > 0 ? ". " : "") + (ru ? "Ещё ждут: " : "Still waiting: ") + string.Join(", ", waiting);
        }

        var day = date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        return new PushMessage(title, body, Channel, $"feeding-{day}T{at}", TimeSpan.FromHours(1),
            new Dictionary<string, string> { ["kind"] = "feeding", ["date"] = day, ["time"] = at, ["update"] = "1" });
    }
}
