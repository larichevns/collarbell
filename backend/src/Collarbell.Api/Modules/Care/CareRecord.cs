namespace Collarbell.Api.Modules.Care;

/// <summary>
/// "What was done": a vaccination, a treatment, a check-up. These records are also the health sections of
/// the digital passport copy (see <see cref="PassportSections"/>); nothing is stored twice.
/// </summary>
public sealed class CareRecord
{
    private CareRecord()
    {
    }

    public CareRecord(
        Guid householdId,
        Guid petId,
        CareKind kind,
        string title,
        DateOnly performedOn,
        Guid createdBy,
        DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        PetId = petId;
        Kind = kind;
        Title = title;
        PerformedOn = performedOn;
        CreatedBy = createdBy;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public Guid PetId { get; private set; }

    /// <summary>The plan this record completed, if it was made with "Done". Kept when the plan is deleted (set to null).</summary>
    public Guid? PlanId { get; set; }

    public CareKind Kind { get; set; }

    public DateOnly PerformedOn { get; set; }

    /// <summary>For the echinococcus treatment the hour matters: entry is allowed 24–120 hours after it.</summary>
    public TimeOnly? PerformedTime { get; set; }

    public string Title { get; set; } = null!;

    public string? Product { get; set; }

    public string? Manufacturer { get; set; }

    public string? BatchNumber { get; set; }

    public DateOnly? ValidFrom { get; set; }

    public DateOnly? ValidUntil { get; set; }

    public List<VaccineTarget> Targets { get; set; } = [];

    public string? Clinic { get; set; }

    public string? Veterinarian { get; set; }

    public decimal? WeightKg { get; set; }

    /// <summary>Extra fields of some kinds: titer results, "fit to travel" after an exam. Stored as JSON.</summary>
    public CareRecordDetails? Details { get; set; }

    public string? Notes { get; set; }

    public RecordSource Source { get; set; } = RecordSource.Manual;

    /// <summary>
    /// The id the app gave this request. A retry with the same id (the first response got lost) returns this
    /// record instead of creating a second one or marking a plan done twice.
    /// </summary>
    public Guid? ClientRequestId { get; set; }

    public Guid CreatedBy { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }

    /// <summary>Photos of the vaccine sticker, the vet's conclusion and the like.</summary>
    public List<CareRecordFile> Files { get; private set; } = [];
}

public sealed class CareRecordDetails
{
    /// <summary>Rabies titer: the laboratory that ran the test.</summary>
    public string? Laboratory { get; set; }

    /// <summary>Rabies titer: the laboratory's report number.</summary>
    public string? ReportNumber { get; set; }

    /// <summary>Rabies titer result in IU/ml (travel to the EU needs at least 0.5).</summary>
    public decimal? TiterIuPerMl { get; set; }

    /// <summary>Clinical exam: the vet confirmed the pet is fit to travel.</summary>
    public bool? FitForTravel { get; set; }
}

/// <summary>A file attached to a record; the file is identified by its id, and belongs to one record only.</summary>
public sealed class CareRecordFile
{
    private CareRecordFile()
    {
    }

    public CareRecordFile(Guid fileId, int position)
    {
        FileId = fileId;
        Position = position;
    }

    public Guid FileId { get; private set; }

    public Guid CareRecordId { get; private set; }

    public int Position { get; set; }
}
