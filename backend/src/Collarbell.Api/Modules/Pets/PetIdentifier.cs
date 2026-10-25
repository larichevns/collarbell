using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Collarbell.Api.Modules.Pets;

[JsonConverter(typeof(JsonStringEnumConverter<IdentifierType>))]
public enum IdentifierType
{
    /// <summary>ISO 11784/11785 microchip: 15 digits. The standard in the EU and most countries.</summary>
    IsoChip,

    /// <summary>Older US chips (10 hex characters or 9-digit AVID): not ISO, take your own scanner when travelling.</summary>
    LegacyChip,

    Tattoo,
}

/// <summary>A microchip or tattoo, as written in section III of the EU passport.</summary>
public sealed class PetIdentifier
{
    private PetIdentifier()
    {
    }

    public PetIdentifier(IdentifierType type, string code, string rawCode)
    {
        Id = Guid.CreateVersion7();
        Type = type;
        Code = code;
        RawCode = rawCode;
    }

    public Guid Id { get; private set; }

    public Guid PetId { get; private set; }

    public IdentifierType Type { get; private set; }

    /// <summary>Normalized: upper case, no spaces, hyphens, dots or asterisks.</summary>
    public string Code { get; private set; } = null!;

    /// <summary>As the user typed it.</summary>
    public string RawCode { get; private set; } = null!;

    public DateOnly? AppliedOn { get; set; }

    public DateOnly? ReadOn { get; set; }

    /// <summary>Where it is, e.g. "left side of the neck".</summary>
    public string? Location { get; set; }
}

/// <summary>Input rules for microchip and tattoo codes (spec, appendix A.7).</summary>
public static partial class IdentifierRules
{
    public const int MaxRawLength = 40;
    public const int MaxTattooLength = 20;

    public static string Normalize(string raw) =>
        string.Concat(raw.Where(c => !char.IsWhiteSpace(c) && c is not '-' and not '.' and not '*')).ToUpperInvariant();

    /// <summary>An error message for the client, or null when the code fits its type.</summary>
    public static string? Validate(IdentifierType type, string code) => type switch
    {
        IdentifierType.IsoChip when !IsoChip().IsMatch(code) => "An ISO microchip number has 15 digits.",
        IdentifierType.IsoChip when code.StartsWith("999", StringComparison.Ordinal) => "Numbers starting with 999 belong to test chips.",
        IdentifierType.LegacyChip when !LegacyChip().IsMatch(code) => "Use 10 characters 0–9 and A–F, or 9 digits (AVID).",
        IdentifierType.Tattoo when code.Length is 0 or > MaxTattooLength => $"Use 1 to {MaxTattooLength} letters and digits.",
        _ => null,
    };

    [GeneratedRegex("^[0-9]{15}$")]
    private static partial Regex IsoChip();

    [GeneratedRegex("^(?:[0-9A-F]{10}|[0-9]{9})$")]
    private static partial Regex LegacyChip();
}
