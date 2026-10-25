using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Pets;

[JsonConverter(typeof(JsonStringEnumConverter<PassportModel>))]
public enum PassportModel
{
    /// <summary>EU pet passport, Regulation 577/2013 (issued from 29.12.2014).</summary>
    Eu2014,

    /// <summary>EU pet passport, Implementing Regulation 2026/705 (issued from 22.04.2026).</summary>
    Eu2026,

    /// <summary>Any other passport, e.g. an international veterinary passport.</summary>
    Other,
}

/// <summary>
/// The header of the pet's digital passport copy: the data of the paper passport that isn't stored
/// elsewhere. Sections II–III come from the pet and its identifiers; the health sections will come
/// from care records (M2). The copy is for information only: the paper passport stays the official document.
/// </summary>
public sealed class PetPassport
{
    private PetPassport()
    {
    }

    public PetPassport(Guid petId)
    {
        PetId = petId;
    }

    public Guid PetId { get; private set; }

    public PassportModel? Model { get; set; }

    /// <summary>Normalized: upper case, no spaces.</summary>
    public string? PassportNumber { get; set; }

    /// <summary>ISO 3166-1 alpha-2, e.g. DE.</summary>
    public string? IssuingCountry { get; set; }

    public DateOnly? IssuedOn { get; set; }

    /// <summary>The vet who issued the passport (section IV).</summary>
    public PassportContact? Issuer { get; set; }

    /// <summary>Up to two owners, as in section I.</summary>
    public List<PassportContact> Owners { get; set; } = [];

    public string? Notes { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>A person or clinic in the passport. Stored as JSON inside the passport row.</summary>
public sealed class PassportContact
{
    public string? Name { get; set; }

    public string? Address { get; set; }

    public string? Phone { get; set; }

    public string? Email { get; set; }
}
