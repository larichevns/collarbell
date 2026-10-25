using System.ComponentModel;
using System.Text.Json.Serialization;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Pets;

namespace Collarbell.Api.Modules.Ai;

// What the model must return for photos of a pet passport. The [Description] texts go into the JSON schema
// that is sent with the request, so they are instructions for the model, not documentation for us.

[JsonConverter(typeof(JsonStringEnumConverter<DateOrder>))]
public enum DateOrder
{
    DayMonthYear,
    MonthDayYear,
    YearMonthDay,
    Unknown,
}

public sealed record ScannedDate(
    [property: Description("The date exactly as written on the page, e.g. \"03.04.2025\" or \"3 Apr 2025\".")]
    string? Raw,
    [property: Description("The same date as YYYY-MM-DD, or null if it can't be read with certainty.")]
    string? Iso,
    [property: Description("Which order of day and month you assumed when converting.")]
    DateOrder Order);

public sealed record ScannedRecord(
    [property: Description("The kind of entry. Rabies vaccinations (passport section V) and other vaccinations are Vaccination; " +
        "section VI is RabiesTiter; section VII is Echinococcus; section VIII treatments are Deworming, FleaTick or Heartworm; " +
        "section X is VetExam.")]
    CareKind Kind,
    [property: Description("A short name of what was done, in the requested language, e.g. \"Rabies vaccination\".")]
    string? Title,
    [property: Description("When it was done.")]
    ScannedDate? PerformedOn,
    [property: Description("The time it was done as HH:MM, if written (it is for echinococcus treatments).")]
    string? PerformedTime,
    [property: Description("The product name from the sticker or the text, e.g. \"Nobivac Rabies\".")]
    string? Product,
    string? Manufacturer,
    [property: Description("The batch (lot) number.")]
    string? BatchNumber,
    [property: Description("For vaccinations: valid from.")]
    ScannedDate? ValidFrom,
    [property: Description("For vaccinations: valid until.")]
    ScannedDate? ValidUntil,
    [property: Description("For vaccinations: what the vaccine protects against.")]
    List<VaccineTarget> Targets,
    [property: Description("The vet's name, if readable.")]
    string? Veterinarian,
    [property: Description("The clinic, if readable.")]
    string? Clinic,
    [property: Description("For VetExam entries: the pet's weight in kilograms, if written. Convert pounds or grams to kilograms.")]
    decimal? WeightKg,
    [property: Description("The text of this entry as it is written on the page, to show the user where it came from.")]
    string? Evidence,
    [property: Description("Which photo the entry is on: 1 for the first photo, 2 for the second, and so on.")]
    int Page);

public sealed record ScannedIdentifier(
    IdentifierType Type,
    [property: Description("The microchip or tattoo number exactly as written.")]
    string? Code,
    ScannedDate? AppliedOn,
    [property: Description("Where on the body, if written.")]
    string? Location,
    string? Evidence,
    int Page);

public sealed record ScannedPassport(
    string? PassportNumber,
    [property: Description("Two-letter ISO country code of the issuing country, if you can tell.")]
    string? IssuingCountry,
    ScannedDate? IssuedOn,
    string? Evidence,
    int Page);

public sealed record ScannedWeight(
    [property: Description("When the pet was weighed.")]
    ScannedDate? MeasuredOn,
    [property: Description("The weight in kilograms. Convert pounds or grams to kilograms.")]
    decimal? WeightKg,
    [property: Description("The weight as it is written, to show the user where it came from.")]
    string? Evidence,
    [property: Description("Which photo the weight is on: 1 for the first photo, 2 for the second, and so on; 1 for a note.")]
    int Page);

/// <summary>
/// What the model returns, for photos and for a note alike. <see cref="Weights"/> came later: answers stored before it
/// have none.
/// </summary>
public sealed record PassportScan(
    [property: Description("Every vaccination, treatment, titer test and examination entry on the photos.")]
    List<ScannedRecord> Records,
    [property: Description("Microchips and tattoos (passport section III).")]
    List<ScannedIdentifier> Identifiers,
    [property: Description("The passport's own number, issuing country and date, if visible.")]
    ScannedPassport? Passport,
    [property: Description("The pet's weights that weren't taken at an examination, each with its date.")]
    List<ScannedWeight>? Weights = null);

public static class PassportScanPrompt
{
    /// <summary>Changes with every wording change, so drafts can be compared before and after (regression set).</summary>
    public const string Version = "scan-5";

    public static string For(string locale, AiImportSource source) => $"""
        {(source == AiImportSource.PassportPages
            ? "The photos show pages of a pet's passport (usually an EU pet passport, possibly another country's)\n" +
              "and vaccine stickers glued into it. Read every entry and return them in the given JSON format."
            : "The photos show a veterinary document about a pet: a vaccination certificate, a vet's report or an\n" +
              "invoice. Read every vaccination, treatment, test and examination it records, and the microchip if\n" +
              "it is written, and return them in the given JSON format. \"passport\" stays null.")}

        Rules:
        - Return only what is written. If a value can't be read with certainty, return null. Never guess.
        - One record per vaccination or treatment entry. Combined vaccines are one record with several targets.
        - Dates: give the exact text, the ISO date and the order you assumed. EU passports write the day first.
        - The pet's weight written for an examination goes into "weightKg" of that VetExam entry; any other
          weight goes into "weights" with its date. Each weight once. Never add an entry just for a weight.
        - Copy the entry's text as written into "evidence".
        - "page" is the number of the photo the entry is on, starting at 1.
        - Write titles in this language: {(locale == "ru" ? "Russian" : "English")}. Keep product names as written.
        """;
}

/// <summary>
/// What the model is told for a note the user typed or dictated about one pet ("yesterday the rabies shot, Nobivac,
/// 4.2 kg"). The answer has the same shape as a scan's, so the same draft and the same "Save" follow.
/// </summary>
public static class TextEntryPrompt
{
    /// <summary>Changes with every wording change, like <see cref="PassportScanPrompt.Version"/>.</summary>
    public const string Version = "text-1";

    /// <summary>
    /// <paramref name="today"/> is the household's today: "yesterday" and "on Friday" are counted back from it.
    /// </summary>
    public static string For(string locale, DateOnly today, string petName, Species species, string text) => $"""
        The user wrote or dictated a note about their {SpeciesWord(species)} named "{petName}". Turn what it says was done
        into entries of the given JSON format:
        - care that was done (vaccinations, treatments against worms, fleas, ticks or heartworm, a check-up at the vet,
          dental care, grooming, another procedure) goes into "records";
        - the pet's weight goes into "weights", or into "weightKg" of a VetExam entry when it was taken at that
          check-up. Each weight once; kilograms (convert pounds or grams);
        - a microchip number goes into "identifiers". "passport" stays null.

        Rules:
        - Only what the note says has happened. Plans, wishes and questions are no entries.
        - Today is {today:yyyy-MM-dd}, a {today.DayOfWeek}. Count "yesterday", "on Friday", "two weeks ago" back from
          today. A date without a year is the latest such date that isn't after today. With no date at all, the entry
          is from today.
        - Dates: "raw" is the date as the user wrote it (null when they wrote none), "iso" is YYYY-MM-DD, "order" is
          YearMonthDay when you worked the date out yourself.
        - Never guess what the note doesn't say (a product, a batch number, the vet): leave it null.
        - Only about "{petName}": leave out what concerns other animals.
        - "evidence" is the part of the note the entry comes from; "page" is 1.
        - Write titles in this language: {(locale == "ru" ? "Russian" : "English")}. Keep product names as written.

        The note:
        <<<
        {text}
        >>>
        """;

    private static string SpeciesWord(Species species) => species switch
    {
        Species.Cat => "cat",
        Species.Dog => "dog",
        _ => "pet",
    };
}
