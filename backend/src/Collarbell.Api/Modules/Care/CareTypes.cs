using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Care;

/// <summary>What kind of care: it decides which section of the passport a record goes to.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<CareKind>))]
public enum CareKind
{
    Vaccination,
    RabiesTiter,
    Deworming,

    /// <summary>Tapeworm treatment before travel (passport section VII); the time matters, not just the date.</summary>
    Echinococcus,

    FleaTick,
    Heartworm,
    VetExam,
    Dental,
    Grooming,
    Procedure,
    Other,
}

[JsonConverter(typeof(JsonStringEnumConverter<IntervalUnit>))]
public enum IntervalUnit
{
    Day,
    Week,
    Month,
    Year,
}

/// <summary>What a vaccine protects against; the paper passport lists these for every shot.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<VaccineTarget>))]
public enum VaccineTarget
{
    Rabies,

    /// <summary>Feline panleukopenia.</summary>
    Fpv,

    /// <summary>Feline herpesvirus (rhinotracheitis).</summary>
    Fhv1,

    /// <summary>Feline calicivirus.</summary>
    Fcv,

    /// <summary>Feline leukaemia.</summary>
    Felv,

    Chlamydia,

    /// <summary>Canine distemper.</summary>
    Cdv,

    /// <summary>Canine adenovirus (hepatitis).</summary>
    Cav2,

    /// <summary>Canine parvovirus.</summary>
    Cpv2,

    /// <summary>Canine parainfluenza.</summary>
    Cpiv,

    /// <summary>Leptospirosis.</summary>
    Lepto,

    /// <summary>Kennel cough (Bordetella bronchiseptica).</summary>
    Bordetella,

    /// <summary>Lyme disease (borreliosis).</summary>
    Lyme,

    CanineInfluenza,
    Leishmania,
}

/// <summary>Where a plan stands on a given day.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<CareStatus>))]
public enum CareStatus
{
    /// <summary>The due date has passed.</summary>
    Overdue,

    /// <summary>Due within <see cref="CarePlan.DueSoonDays"/> days.</summary>
    DueSoon,

    Upcoming,

    /// <summary>Finished (a one-off plan that is done) or paused.</summary>
    Inactive,
}

/// <summary>Where a record came from: typed in, or read from a photo by AI (M3).</summary>
[JsonConverter(typeof(JsonStringEnumConverter<RecordSource>))]
public enum RecordSource
{
    Manual,
    AiScan,
}

public static class Intervals
{
    /// <summary>The date one interval later. Months and years keep the day where they can: 31 Jan + 1 month = 28/29 Feb.</summary>
    public static DateOnly Add(DateOnly date, int value, IntervalUnit unit) => unit switch
    {
        IntervalUnit.Day => date.AddDays(value),
        IntervalUnit.Week => date.AddDays(7 * value),
        IntervalUnit.Month => date.AddMonths(value),
        IntervalUnit.Year => date.AddYears(value),
        _ => throw new ArgumentOutOfRangeException(nameof(unit), unit, "Unknown interval unit."),
    };

    /// <summary>The longest allowed interval per unit: ten years.</summary>
    public static int MaxValue(IntervalUnit unit) => unit switch
    {
        IntervalUnit.Day => 3650,
        IntervalUnit.Week => 520,
        IntervalUnit.Month => 120,
        _ => 10,
    };
}
