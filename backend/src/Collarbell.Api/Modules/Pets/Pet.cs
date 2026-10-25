using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Pets;

[JsonConverter(typeof(JsonStringEnumConverter<Species>))]
public enum Species
{
    Cat,
    Dog,
    Other,
}

[JsonConverter(typeof(JsonStringEnumConverter<Sex>))]
public enum Sex
{
    Unknown,
    Male,
    Female,
}

/// <summary>The pet's identity colour in the app (avatar, calendar dot), named after coat colours.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<Coat>))]
public enum Coat
{
    Smoke,
    Ginger,
    Fawn,
    Cocoa,
    Lilac,
    Ink,
}

[JsonConverter(typeof(JsonStringEnumConverter<PetStatus>))]
public enum PetStatus
{
    Active,
    Archived,
    Deceased,
}

public sealed class Pet
{
    private Pet()
    {
    }

    public Pet(Guid householdId, string name, Species species, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        Name = name;
        Species = species;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public string Name { get; set; } = null!;

    public Species Species { get; set; }

    public string? Breed { get; set; }

    public Sex Sex { get; set; } = Sex.Unknown;

    public DateOnly? BirthDate { get; set; }

    public bool BirthDateApproximate { get; set; }

    public bool? Neutered { get; set; }

    public DateOnly? NeuteredOn { get; set; }

    public string? Color { get; set; }

    public string? Markings { get; set; }

    public Coat Coat { get; set; } = Coat.Smoke;

    public string? Allergies { get; set; }

    public string? Notes { get; set; }

    public PetStatus Status { get; set; } = PetStatus.Active;

    /// <summary>The photo (a file of the Documents module).</summary>
    public Guid? PhotoFileId { get; set; }

    /// <summary>Microchips and tattoos; a pet can have several.</summary>
    public List<PetIdentifier> Identifiers { get; private set; } = [];

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }
}
