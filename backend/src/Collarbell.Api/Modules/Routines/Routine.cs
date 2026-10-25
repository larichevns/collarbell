using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Routines;

/// <summary>What a routine is. Only feeding for now; medication courses come later (spec 4).</summary>
[JsonConverter(typeof(JsonStringEnumConverter<RoutineKind>))]
public enum RoutineKind
{
    Feeding,
}

[JsonConverter(typeof(JsonStringEnumConverter<PortionUnit>))]
public enum PortionUnit
{
    Gram,
    Milliliter,
    Piece,
}

/// <summary>How an occurrence was marked: fed, or skipped on purpose (e.g. no food before surgery).</summary>
[JsonConverter(typeof(JsonStringEnumConverter<CompletionStatus>))]
public enum CompletionStatus
{
    Done,
    Skipped,
}

/// <summary>
/// Care by the time of day (spec 4, 5.2): "feed Murka at 08:00 and 20:00, 40 g of Royal Canin". Times are the
/// household's local time. An occurrence is a date and one of the times; marking it is a <see cref="RoutineCompletion"/>.
/// </summary>
public sealed class Routine
{
    public const int MaxTimes = 8;

    private Routine()
    {
    }

    public Routine(Guid householdId, Guid petId, RoutineKind kind, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        PetId = petId;
        Kind = kind;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public Guid PetId { get; private set; }

    public RoutineKind Kind { get; private set; }

    /// <summary>Times of day, earliest first.</summary>
    public List<TimeOnly> Times { get; set; } = [];

    /// <summary>Days of the week it happens on; all seven for every day.</summary>
    public List<DayOfWeek> Days { get; set; } = [.. Enum.GetValues<DayOfWeek>()];

    /// <summary>What is given, in the user's words, or the name of <see cref="SupplyItemId"/>.</summary>
    public string? Food { get; set; }

    /// <summary>The food in supplies this feeding gives: its portions make the food's daily use (spec 5.3).</summary>
    public Guid? SupplyItemId { get; set; }

    public decimal? Amount { get; set; }

    public PortionUnit? Unit { get; set; }

    public string? Notes { get; set; }

    /// <summary>A paused routine has no occurrences and no reminders.</summary>
    public bool Active { get; set; } = true;

    /// <summary>The id the app gave the create request; a retry with the same id returns this routine.</summary>
    public Guid? ClientRequestId { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public bool OccursOn(DateOnly date) => Active && Days.Contains(date.DayOfWeek);

    /// <summary>Whether <paramref name="time"/> on <paramref name="date"/> is one of its occurrences.</summary>
    public bool OccursAt(DateOnly date, TimeOnly time) => OccursOn(date) && Times.Contains(time);
}

/// <summary>
/// One occurrence marked: "Anna fed Murka at 08:02 for the 08:00 feeding". Unique per routine, date and time, so two
/// phones can't mark the same feeding twice: the second gets 409 with who did it (spec 5.2).
/// </summary>
public sealed class RoutineCompletion
{
    private RoutineCompletion()
    {
    }

    public RoutineCompletion(Guid householdId, Guid routineId, DateOnly date, TimeOnly time, CompletionStatus status,
        Guid doneBy, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        RoutineId = routineId;
        Date = date;
        Time = time;
        Status = status;
        DoneBy = doneBy;
        DoneAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public Guid RoutineId { get; private set; }

    /// <summary>The occurrence: its date and time in the household's time zone.</summary>
    public DateOnly Date { get; private set; }

    public TimeOnly Time { get; private set; }

    public CompletionStatus Status { get; private set; }

    /// <summary>The person who marked it; null once their account is gone (the mark stays: the cat was fed).</summary>
    public Guid? DoneBy { get; private set; }

    public DateTimeOffset DoneAt { get; private set; }
}
