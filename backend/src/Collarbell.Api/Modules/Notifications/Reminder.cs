using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Notifications;

/// <summary>What a reminder is about; each kind has its <see cref="IReminderSource"/> in its own module.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<ReminderSource>))]
public enum ReminderSource
{
    /// <summary>A care plan comes due (Care module).</summary>
    CarePlan,

    /// <summary>A visit to the vet or groomer is coming (Appointments module).</summary>
    Appointment,

    /// <summary>Feeding time of the household: one reminder for all pets fed at that time (Routines module).</summary>
    Feeding,

    /// <summary>A food, litter or medication runs out soon: time to buy it (Supplies module).</summary>
    Supply,
}

/// <summary>Groups of reminders a person can turn off; on Android each is also a notification channel.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<NotificationCategory>))]
public enum NotificationCategory
{
    Feeding,
    Care,
    Appointments,
    Supplies,
}

[JsonConverter(typeof(JsonStringEnumConverter<ReminderStatus>))]
public enum ReminderStatus
{
    /// <summary>Waiting for its time (or for another try after a failed send).</summary>
    Pending,

    /// <summary>Handed to Firebase for at least one phone.</summary>
    Sent,

    /// <summary>Not sent, see <see cref="Reminder.Reason"/>.</summary>
    Skipped,

    /// <summary>
    /// Too late to send: the server was off when it was due. A reminder to feed is useless an hour later, so it
    /// isn't sent at all (catch-up windows: <see cref="ReminderDispatcher.CatchUpWindow"/>).
    /// </summary>
    Expired,

    /// <summary>Firebase didn't take it, also after the retries.</summary>
    Failed,
}

/// <summary>Why a reminder was skipped or failed.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<ReminderReason>))]
public enum ReminderReason
{
    /// <summary>Already done, cancelled, moved to another date, paused or deleted.</summary>
    NotNeeded,

    /// <summary>Nobody in the household has a phone registered with this kind of reminder turned on.</summary>
    NoRecipients,

    /// <summary>The server has no Firebase credentials, so it can't send pushes.</summary>
    PushNotConfigured,

    /// <summary>Firebase refused or couldn't be reached, also after the retries.</summary>
    SendFailed,
}

/// <summary>
/// One reminder to send at <see cref="FireAt"/> (spec 5.4). Modules plan them ahead from their data
/// (<see cref="ReminderSchedule"/>), the dispatcher sends them when they are due (<see cref="ReminderDispatcher"/>).
/// <see cref="Source"/>, <see cref="SourceId"/> and <see cref="Key"/> name the occasion, e.g. "plan X, due on 10 October,
/// 7 days before": one occasion is never reminded twice.
/// </summary>
public sealed class Reminder
{
    private Reminder()
    {
    }

    public Reminder(Guid householdId, ReminderSource source, Guid sourceId, string key, NotificationCategory category,
        DateTimeOffset fireAt, string subject, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        Source = source;
        SourceId = sourceId;
        Key = key;
        Category = category;
        FireAt = fireAt;
        DueAt = fireAt;
        Subject = subject;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public ReminderSource Source { get; private set; }

    /// <summary>The plan, the visit, or for feeding the household itself.</summary>
    public Guid SourceId { get; private set; }

    /// <summary>Which occasion of the source, e.g. <c>2026-10-10/-7</c> or <c>2026-10-02T08:00</c>.</summary>
    public string Key { get; private set; } = null!;

    public NotificationCategory Category { get; set; }

    /// <summary>When the reminder is meant to arrive.</summary>
    public DateTimeOffset FireAt { get; set; }

    /// <summary>When the dispatcher looks at it next: <see cref="FireAt"/>, later after a failed send.</summary>
    public DateTimeOffset DueAt { get; set; }

    /// <summary>What it is about in the user's own words ("Murka: Rabies"), for the list of recent reminders.</summary>
    public string Subject { get; set; } = null!;

    public ReminderStatus Status { get; set; } = ReminderStatus.Pending;

    public ReminderReason? Reason { get; set; }

    /// <summary>Failed sends so far.</summary>
    public int Attempts { get; set; }

    public DateTimeOffset? SentAt { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }
}
