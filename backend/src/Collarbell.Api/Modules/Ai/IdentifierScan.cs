using System.ComponentModel;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Pets;

namespace Collarbell.Api.Modules.Ai;

// What the model must return for photos of a microchip sticker or a passport page with the number. One entry is the
// same ScannedIdentifier a passport scan returns. The [Description] texts go into the JSON schema that is sent with
// the request, so they are instructions for the model, not documentation for us.

public sealed record IdentifierScan(
    [property: Description("Every microchip and tattoo number on the photos. Empty if there is none.")]
    List<ScannedIdentifier> Identifiers);

/// <summary>
/// A microchip or tattoo number read from photos: <see cref="Code"/> normalized, <see cref="RawCode"/> as written.
/// <see cref="Problem"/> is what saving it in the pet form would refuse (the app says it in the user's language by
/// the same rules), null when the number fits its type. <see cref="AppliedOn"/> and <see cref="Location"/> only when
/// they are written and the form would take them.
/// </summary>
public sealed record IdentifierReading(
    IdentifierType Type,
    string Code,
    string RawCode,
    DateOnly? AppliedOn,
    string? Location,
    string? Problem);

public static class IdentifierReadings
{
    /// <summary>
    /// The numbers the model read, checked like the pet form checks them. A number saving would refuse stays, with
    /// its <see cref="IdentifierReading.Problem"/>: the user sees it and fixes a digit. Left out: entries without a
    /// number, and a number read twice (on the sticker and written by hand): one entry stays, the one saving would
    /// take, with the place and date of either. Dropped, for the user to fill in from the paper: a date whose day
    /// and month could be swapped (03.04.2021), a date in the future, a place longer than the form takes.
    /// </summary>
    public static List<IdentifierReading> From(IdentifierScan scan, DateOnly latestToday)
    {
        var readings = new List<IdentifierReading>();
        foreach (var item in scan.Identifiers ?? [])
        {
            if (item is null || Input.Clean(item.Code) is not { } raw)
            {
                continue;
            }

            // A type the schema doesn't have (a number instead of a name) counts as the common kind; the check
            // below then says if the number doesn't fit it.
            var type = Enum.IsDefined(item.Type) ? item.Type : IdentifierType.IsoChip;

            // The passport import's rule (ImportDrafts.IsAmbiguous): a date that reads either way round isn't filled in.
            DateOnly? appliedOn = item.AppliedOn is { Iso: { } iso } written
                && DateOnly.TryParseExact(iso.Trim(), "yyyy-MM-dd", out var date)
                && (written.Order == DateOrder.YearMonthDay || !ImportDrafts.IsAmbiguous(written.Raw))
                ? date
                : null;
            var location = Input.Clean(item.Location);

            // The pet form's checks: the number's format, the date, the length of the location.
            var errors = new ValidationErrors();
            PetsEndpoints.ValidateIdentifiers(
                [new PetIdentifierRequest(type, raw, appliedOn, ReadOn: null, location)], "item", latestToday, errors);
            var problems = errors.ToDictionary();
            string? Problem(string field) => problems.TryGetValue($"item[0].{field}", out var messages) ? messages[0] : null;

            var reading = new IdentifierReading(
                type,
                IdentifierRules.Normalize(raw),
                raw,
                Problem("appliedOn") is null ? appliedOn : null,
                Problem("location") is null ? location : null,
                Problem("code"));
            var same = readings.FindIndex(r => r.Code == reading.Code);
            if (same < 0)
            {
                readings.Add(reading);
                continue;
            }

            // Read twice, once as the wrong kind (15 digits as a non-ISO chip): the reading that fits stays.
            var (kept, other) = readings[same].Problem is not null && reading.Problem is null
                ? (reading, readings[same])
                : (readings[same], reading);
            readings[same] = kept with
            {
                AppliedOn = kept.AppliedOn ?? other.AppliedOn,
                Location = kept.Location ?? other.Location,
            };
        }

        return readings;
    }
}

public static class IdentifierScanPrompt
{
    /// <summary>Changes with every wording change, so answers can be compared before and after.</summary>
    public const string Version = "identifier-1";

    public const string Text = """
        The photos show a page of a pet's passport, or the sticker with a pet's microchip number (usually a barcode
        with the digits printed under it). Read every microchip and tattoo number on them and return them in the
        given JSON format.

        Rules:
        - Copy each number exactly as written, digit for digit. Never guess, add, drop or correct a digit. If a
          number can't be read with certainty, leave it out.
        - The digits printed under a barcode count as the number. The same number on a sticker and written by hand
          is one entry.
        - The type: IsoChip for 15 digits; LegacyChip for an older chip of 10 characters 0-9 and A-F, or of 9 digits;
          Tattoo for a tattoo code.
        - "location" is where on the body the chip or tattoo is, as written, e.g. "left side of the neck".
        - "appliedOn" is the date the chip was implanted or the tattoo applied, if written: the exact text, the ISO
          date and the order you assumed. EU passports write the day first.
        - Other numbers on the page aren't microchips: the passport's own number, a vaccine batch, a phone number.
        - "evidence" is the label and the number as written; "page" is the number of the photo, starting at 1.
        - Return only what is written, null for what isn't. No number at all: an empty list.
        """;
}
