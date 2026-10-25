using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Appointments;

[JsonConverter(typeof(JsonStringEnumConverter<AppointmentType>))]
public enum AppointmentType
{
    Vet,
    Grooming,
    Training,
    Other,
}

[JsonConverter(typeof(JsonStringEnumConverter<AppointmentStatus>))]
public enum AppointmentStatus
{
    Planned,

    /// <summary>It took place; its results may be in care records (<see cref="Appointment.RecordIds"/>).</summary>
    Done,

    Cancelled,
}

/// <summary>
/// A visit to the vet, the groomer and so on (spec 2, 4): a moment, a place, the pets. Reminders come a day and two
/// hours before (<see cref="RemindOffsetsMinutes"/>). After the visit, "Done" can turn it into care records.
/// </summary>
public sealed class Appointment
{
    private Appointment()
    {
    }

    public Appointment(Guid householdId, AppointmentType type, string title, DateTimeOffset startsAt, Guid createdBy, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        Type = type;
        Title = title;
        StartsAt = startsAt;
        CreatedBy = createdBy;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public AppointmentType Type { get; set; }

    public string Title { get; set; } = null!;

    /// <summary>The moment it begins, in UTC. The app enters and shows it in the household's time zone.</summary>
    public DateTimeOffset StartsAt { get; set; }

    public int? DurationMinutes { get; set; }

    /// <summary>The clinic or the address.</summary>
    public string? Location { get; set; }

    public string? Notes { get; set; }

    /// <summary>Remind this many minutes before; a day and two hours by default.</summary>
    public List<int> RemindOffsetsMinutes { get; set; } = [1440, 120];

    public AppointmentStatus Status { get; set; } = AppointmentStatus.Planned;

    /// <summary>The pets it is for (one visit can be for several).</summary>
    public List<AppointmentPet> Pets { get; private set; } = [];

    /// <summary>The care records made when it was marked done.</summary>
    public List<Guid> RecordIds { get; set; } = [];

    /// <summary>The id the app gave the create request; a retry with the same id returns this visit.</summary>
    public Guid? ClientRequestId { get; set; }

    public Guid CreatedBy { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }
}

public sealed class AppointmentPet
{
    private AppointmentPet()
    {
    }

    public AppointmentPet(Guid petId)
    {
        PetId = petId;
    }

    public Guid AppointmentId { get; private set; }

    public Guid PetId { get; private set; }
}
