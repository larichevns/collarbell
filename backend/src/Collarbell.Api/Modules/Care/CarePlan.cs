namespace Collarbell.Api.Modules.Care;

/// <summary>
/// "What to do and when": a repeating plan (rabies once a year, deworming every 3 months) or a one-off
/// (a treatment before a trip). <see cref="NextDueOn"/> is the date it is due next.
/// </summary>
public sealed class CarePlan
{
    /// <summary>A plan due within this many days counts as "due soon".</summary>
    public const int DueSoonDays = 14;

    private CarePlan()
    {
    }

    public CarePlan(Guid householdId, Guid petId, CareKind kind, string title, DateOnly nextDueOn, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        PetId = petId;
        Kind = kind;
        Title = title;
        NextDueOn = nextDueOn;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public Guid PetId { get; private set; }

    public CareKind Kind { get; set; }

    public string Title { get; set; } = null!;

    /// <summary>Null (together with <see cref="IntervalUnit"/>) for a one-off plan.</summary>
    public int? IntervalValue { get; set; }

    public IntervalUnit? IntervalUnit { get; set; }

    public DateOnly NextDueOn { get; set; }

    /// <summary>Remind this many days before the due date (used by reminders in M4).</summary>
    public List<int> RemindOffsetsDays { get; set; } = [7, 1, 0];

    /// <summary>The product usually given, offered when marking the plan done.</summary>
    public string? DefaultProduct { get; set; }

    /// <summary>For vaccinations: what the vaccine protects against. Copied to the records.</summary>
    public List<VaccineTarget> Targets { get; set; } = [];

    /// <summary>The preset the plan was created from, if any (see <see cref="CarePresets"/>).</summary>
    public string? PresetCode { get; set; }

    public string? Notes { get; set; }

    public bool Active { get; set; } = true;

    /// <summary>The id the app gave the create request; a retry with the same id returns this plan.</summary>
    public Guid? ClientRequestId { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public bool IsRecurring => IntervalValue is not null && IntervalUnit is not null;

    public CareStatus StatusOn(DateOnly today) =>
        !Active ? CareStatus.Inactive
        : NextDueOn < today ? CareStatus.Overdue
        : NextDueOn <= today.AddDays(DueSoonDays) ? CareStatus.DueSoon
        : CareStatus.Upcoming;

    /// <summary>
    /// "Done" on <paramref name="performedOn"/>. The next date is, in this order: the date the user chose,
    /// the day the done thing stops protecting (a vaccine's "valid until"), or one interval later.
    /// A one-off plan is finished unless the user chose a next date.
    /// </summary>
    public void MarkDone(DateOnly performedOn, DateOnly? validUntil, DateOnly? chosenNextDueOn, DateTimeOffset now)
    {
        if (chosenNextDueOn is { } chosen)
        {
            NextDueOn = chosen;
        }
        else if (validUntil is { } until)
        {
            NextDueOn = until;
        }
        else if (IsRecurring)
        {
            NextDueOn = Intervals.Add(performedOn, IntervalValue!.Value, IntervalUnit!.Value);
        }

        if (!IsRecurring && chosenNextDueOn is null)
        {
            Active = false;
        }

        UpdatedAt = now;
    }
}
