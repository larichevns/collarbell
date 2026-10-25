using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Pets;

namespace Collarbell.Api.Modules.Ai;

/// <summary>Why a draft value needs a look before saving. The app highlights the field.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<DraftIssue>))]
public enum DraftIssue
{
    /// <summary>The model couldn't read it; it must be filled in by hand to save the entry.</summary>
    Unreadable,

    /// <summary>Day and month could be either way round (03/04/2025): check against the paper.</summary>
    Ambiguous,

    InFuture,

    /// <summary>"Valid until" isn't after the date it was given.</summary>
    EndsBeforeStart,

    /// <summary>Saving would refuse it as it is: a wrong microchip number or country code, a date before 1990, too long.</summary>
    InvalidFormat,

    /// <summary>The same entry is already saved.</summary>
    AlreadySaved,

    /// <summary>The same entry is on two photos (two shots of one page).</summary>
    Repeated,

    /// <summary>Differs from what the passport header already says.</summary>
    DiffersFromSaved,
}

public sealed record DraftWarning(string Field, DraftIssue Issue);

/// <summary>
/// A care record the scan found. <see cref="Title"/> is null when the model gave none: the app then names it in the
/// user's language. <see cref="Selected"/> is the app's default for "save this". <see cref="PlanId"/>: the plan it is
/// a "Done" of, when saving it would move that plan on.
/// </summary>
public sealed record DraftRecord(
    int Key,
    CareKind Kind,
    string? Title,
    DateOnly? PerformedOn,
    TimeOnly? PerformedTime,
    string? Product,
    string? Manufacturer,
    string? BatchNumber,
    DateOnly? ValidFrom,
    DateOnly? ValidUntil,
    List<VaccineTarget> Targets,
    string? Veterinarian,
    string? Clinic,
    decimal? WeightKg,
    string? Evidence,
    int Page,
    List<DraftWarning> Warnings,
    Guid? DuplicateOf,
    Guid? PlanId,
    bool Selected);

public sealed record DraftIdentifier(
    int Key,
    IdentifierType Type,
    string? Code,
    DateOnly? AppliedOn,
    string? Location,
    string? Evidence,
    int Page,
    List<DraftWarning> Warnings,
    bool Selected);

public sealed record DraftPassport(
    string? PassportNumber,
    string? IssuingCountry,
    DateOnly? IssuedOn,
    string? Evidence,
    int Page,
    List<DraftWarning> Warnings,
    bool Selected);

/// <summary>
/// A weight the scan or the note gave without an examination: saved as a weighing of the pet's weight log.
/// <see cref="DuplicateOf"/>: the weight of the log with the same day and weight (a weighing or a vet's).
/// </summary>
public sealed record DraftWeight(
    int Key,
    DateOnly? MeasuredOn,
    decimal? WeightKg,
    string? Evidence,
    int Page,
    List<DraftWarning> Warnings,
    Guid? DuplicateOf,
    bool Selected);

/// <summary>What a scan proposes. Nothing is saved until the user applies it (spec 5.5: AI never writes data itself).</summary>
public sealed record ImportDraft(
    List<DraftRecord> Records, List<DraftIdentifier> Identifiers, DraftPassport? Passport, List<DraftWeight> Weights);

public sealed record SavedRecord(Guid Id, CareKind Kind, DateOnly PerformedOn, string? Product);

/// <summary>What is already saved for the pet, to spot entries that would be saved twice.</summary>
public sealed record SavedPetData(
    List<SavedRecord> Records,
    IReadOnlySet<string> IdentifierCodes,
    string? PassportNumber,
    string? IssuingCountry,
    DateOnly? IssuedOn)
{
    /// <summary>The pet's active plans: a scanned entry can be a "Done" of one.</summary>
    public IReadOnlyList<PlanSummary> Plans { get; init; } = [];

    /// <summary>The pet's weight log (weighings and a vet's weights), to spot a weight saved already.</summary>
    public IReadOnlyList<SavedWeight> Weights { get; init; } = [];

    /// <summary>The pet's birth date when it is exact: a weighing can't be before it.</summary>
    public DateOnly? ExactBirthDate { get; init; }
}

/// <summary>A weight of the pet's log; <see cref="FromCheckUp"/>: a vet's, kept to 10 g.</summary>
public sealed record SavedWeight(Guid Id, DateOnly MeasuredOn, decimal WeightKg, bool FromCheckUp = false);

/// <summary>
/// Turns the model's answer into a draft, against what is saved for the pet right now: dates checked, doubtful
/// values flagged, whatever saving would refuse or save twice unchecked, entries matched to plans.
/// </summary>
public static partial class ImportDrafts
{
    public static ImportDraft Build(PassportScan scan, SavedPetData saved, DateOnly latestToday)
    {
        var records = Records(scan.Records ?? [], saved, latestToday);
        return new ImportDraft(
            records,
            Identifiers(scan.Identifiers ?? [], saved, latestToday),
            scan.Passport is { } passport ? Passport(passport, saved, latestToday) : null,
            Weights(scan.Weights ?? [], records, saved, latestToday));
    }

    private static List<DraftRecord> Records(List<ScannedRecord> scanned, SavedPetData saved, DateOnly latestToday)
    {
        var seen = new HashSet<string>();
        var records = new List<DraftRecord>();
        foreach (var (item, index) in scanned.Select((r, i) => (r, i)))
        {
            if (item is null)
            {
                continue;
            }

            var warnings = new List<DraftWarning>();
            var performedOn = ToDate(item.PerformedOn, "performedOn", warnings, required: true);
            var validFrom = ToDate(item.ValidFrom, "validFrom", warnings, required: false);
            var validUntil = ToDate(item.ValidUntil, "validUntil", warnings, required: false);
            if (performedOn > latestToday)
            {
                warnings.Add(new("performedOn", DraftIssue.InFuture));
            }

            if (validUntil is not null && performedOn is not null && validUntil <= performedOn)
            {
                warnings.Add(new("validUntil", DraftIssue.EndsBeforeStart));
            }

            List<VaccineTarget> targets = item.Kind == CareKind.Vaccination ? [.. (item.Targets ?? []).Distinct()] : [];
            var record = new DraftRecord(
                Key: index,
                Kind: item.Kind,
                Title: Clean(item.Title),
                PerformedOn: performedOn,
                PerformedTime: TimeOnly.TryParse(item.PerformedTime, out var time) ? time : null,
                Product: Clean(item.Product),
                Manufacturer: Clean(item.Manufacturer),
                BatchNumber: Clean(item.BatchNumber),
                ValidFrom: validFrom,
                ValidUntil: validUntil,
                Targets: targets,
                Veterinarian: Clean(item.Veterinarian),
                Clinic: Clean(item.Clinic),
                // Kept to 10 g, like the record keeps it; only a check-up notes a weight.
                WeightKg: item.Kind == CareKind.VetExam && item.WeightKg is { } kg ? CareRecordsEndpoints.RoundedWeight(kg) : null,
                Evidence: Clean(item.Evidence),
                Page: Math.Max(1, item.Page),
                Warnings: warnings,
                DuplicateOf: null,
                PlanId: null,
                Selected: false);

            // Whatever saving would refuse (a date before 1990, "valid from" before the shot, a very long name).
            if (record.PerformedOn is { } date)
            {
                var request = new CareRecordRequest(
                    record.Kind, record.Title ?? record.Kind.ToString(), date, record.PerformedTime, record.Product, record.Manufacturer,
                    record.BatchNumber, record.ValidFrom, record.ValidUntil, record.Targets, record.Clinic,
                    record.Veterinarian, record.WeightKg, Details: null, Notes: null, RequestId: null);
                Flag(warnings, CareRecordsEndpoints.Validate(request, latestToday), prefix: "");
            }
            else if (record.WeightKg is { } weight && weight is <= 0 or > WeightsEndpoints.MaxWeightKg)
            {
                // Without a date the record isn't checked as a whole yet; a weight saving would refuse shows already.
                warnings.Add(new("weightKg", DraftIssue.InvalidFormat));
            }

            var duplicate = performedOn is { } day
                ? saved.Records.FirstOrDefault(r => r.Kind == item.Kind && r.PerformedOn == day && SameProduct(r.Product, record.Product))
                : null;
            if (duplicate is not null)
            {
                warnings.Add(new("performedOn", DraftIssue.AlreadySaved));
            }

            if (!seen.Add($"{item.Kind}|{performedOn}|{record.Product?.ToUpperInvariant()}"))
            {
                warnings.Add(new("performedOn", DraftIssue.Repeated));
            }

            records.Add(record with { DuplicateOf = duplicate?.Id, Selected = OnlyNotes(warnings) });
        }

        SuggestPlans(records, saved.Plans);
        return records;
    }

    /// <summary>
    /// Links an entry to the plan it is a "Done" of: for each plan only its newest entry the user is likely to keep,
    /// and only when saving it would really move the plan (<see cref="PlanSummary.MovedBy"/>).
    /// </summary>
    private static void SuggestPlans(List<DraftRecord> records, IReadOnlyList<PlanSummary> plans)
    {
        var newest = new Dictionary<Guid, (PlanSummary Plan, int Index)>();
        for (var i = 0; i < records.Count; i++)
        {
            if (records[i] is { Selected: true, PerformedOn: { } date } record
                && MatchPlan(record.Kind, record.Targets, plans) is { } plan
                && (!newest.TryGetValue(plan.Id, out var found) || records[found.Index].PerformedOn < date))
            {
                newest[plan.Id] = (plan, i);
            }
        }

        foreach (var (plan, i) in newest.Values)
        {
            if (plan.MovedBy(records[i].PerformedOn!.Value, records[i].ValidUntil))
            {
                records[i] = records[i] with { PlanId = plan.Id };
            }
        }
    }

    /// <summary>
    /// The plan an entry could be a "Done" of: the pet's only active plan of that kind or, for a vaccination, the
    /// plan sharing most of its diseases. None when it's a toss-up: the user picks.
    /// </summary>
    private static PlanSummary? MatchPlan(CareKind kind, List<VaccineTarget> targets, IReadOnlyList<PlanSummary> plans)
    {
        var sameKind = plans.Where(p => p.Kind == kind).ToList();
        if (kind != CareKind.Vaccination)
        {
            return sameKind.Count == 1 ? sameKind[0] : null;
        }

        var best = sameKind
            .Select(p => (Plan: p, Shared: p.Targets.Intersect(targets).Count()))
            .Where(p => p.Shared > 0)
            .OrderByDescending(p => p.Shared)
            .ToList();
        return best.Count == 1 || (best.Count > 1 && best[0].Shared > best[1].Shared) ? best[0].Plan : null;
    }

    /// <summary>
    /// Weights to save as weighings, checked like a weighing added by hand. One already in the log (the same day and
    /// weight), given twice, or the same as a check-up of this draft carries, is unchecked.
    /// </summary>
    private static List<DraftWeight> Weights(
        List<ScannedWeight> scanned, List<DraftRecord> records, SavedPetData saved, DateOnly latestToday)
    {
        // A check-up keeps its weight to 10 g: the same weight on its own ("835 g" against 0.84) is compared that way.
        var checkUps = records
            .Where(r => r is { WeightKg: not null, PerformedOn: not null })
            .Select(r => (r.PerformedOn!.Value, CareRecordsEndpoints.RoundedWeight(r.WeightKg!.Value)))
            .ToHashSet();
        var seen = new HashSet<(DateOnly, decimal)>();
        var weights = new List<DraftWeight>();
        foreach (var (item, index) in scanned.Select((w, i) => (w, i)))
        {
            if (item is null)
            {
                continue;
            }

            var warnings = new List<DraftWarning>();
            var measuredOn = ToDate(item.MeasuredOn, "measuredOn", warnings, required: true);
            decimal? weightKg = item.WeightKg is { } kg ? WeightsEndpoints.Rounded(kg) : null;
            if (weightKg is null)
            {
                warnings.Add(new("weightKg", DraftIssue.Unreadable));
            }

            if (measuredOn > latestToday)
            {
                warnings.Add(new("measuredOn", DraftIssue.InFuture));
            }

            // Whatever saving would refuse: a date before 1990 or the pet's birth, a weight over 200 kg or of nothing.
            Flag(warnings, WeightsEndpoints.Validate(
                new WeightRequest(measuredOn ?? latestToday, weightKg ?? 1, Bcs: null, BcsScale: null, Note: null, RequestId: null),
                saved.ExactBirthDate,
                latestToday), prefix: "");

            Guid? duplicate = null;
            if (measuredOn is { } day && weightKg is { } weight)
            {
                var toTenGrams = CareRecordsEndpoints.RoundedWeight(weight);
                duplicate = saved.Weights.FirstOrDefault(w => w.MeasuredOn == day
                    && w.WeightKg == (w.FromCheckUp ? toTenGrams : weight))?.Id;
                if (duplicate is not null)
                {
                    warnings.Add(new("measuredOn", DraftIssue.AlreadySaved));
                }
                else if (checkUps.Contains((day, toTenGrams)) || !seen.Add((day, weight)))
                {
                    warnings.Add(new("measuredOn", DraftIssue.Repeated));
                }
            }

            weights.Add(new DraftWeight(
                index, measuredOn, weightKg, Clean(item.Evidence), Math.Max(1, item.Page), warnings, duplicate,
                Selected: OnlyNotes(warnings)));
        }

        return weights;
    }

    private static List<DraftIdentifier> Identifiers(List<ScannedIdentifier> scanned, SavedPetData saved, DateOnly latestToday)
    {
        var codes = new HashSet<string>();
        var identifiers = new List<DraftIdentifier>();
        foreach (var (item, index) in scanned.Select((r, i) => (r, i)))
        {
            if (item is null)
            {
                continue;
            }

            var warnings = new List<DraftWarning>();
            var raw = Clean(item.Code);
            var code = raw is null ? null : IdentifierRules.Normalize(raw);
            var appliedOn = ToDate(item.AppliedOn, "appliedOn", warnings, required: false);
            var location = Clean(item.Location);
            if (raw is null)
            {
                warnings.Add(new("code", DraftIssue.Unreadable));
            }
            else
            {
                // The pet form's checks: the number's format, the date, the length of the location.
                var errors = new ValidationErrors();
                PetsEndpoints.ValidateIdentifiers(
                    [new PetIdentifierRequest(item.Type, raw, appliedOn, ReadOn: null, location)], "item", latestToday, errors);
                Flag(warnings, errors, prefix: "item[0].");
                if (warnings.All(w => w.Field != "code") && saved.IdentifierCodes.Contains(code!))
                {
                    warnings.Add(new("code", DraftIssue.AlreadySaved));
                }
                else if (warnings.All(w => w.Field != "code") && !codes.Add(code!))
                {
                    warnings.Add(new("code", DraftIssue.Repeated));
                }
            }

            identifiers.Add(new DraftIdentifier(
                index, item.Type, code, appliedOn, location, Clean(item.Evidence), Math.Max(1, item.Page), warnings,
                Selected: OnlyNotes(warnings)));
        }

        return identifiers;
    }

    private static DraftPassport Passport(ScannedPassport scanned, SavedPetData saved, DateOnly latestToday)
    {
        var warnings = new List<DraftWarning>();
        var number = PassportEndpoints.NormalizeNumber(scanned.PassportNumber);
        var country = Clean(scanned.IssuingCountry)?.ToUpperInvariant();
        var issuedOn = ToDate(scanned.IssuedOn, "issuedOn", warnings, required: false);

        // The passport form's checks.
        var errors = new ValidationErrors();
        PetIdentityWriter.ValidatePassport(number, country, "passport", errors);
        errors.NotInFuture("passport.issuedOn", issuedOn, latestToday);
        Flag(warnings, errors, prefix: "passport.");

        // Never overwrite quietly: what differs from the saved header is shown and left unchecked.
        if (number is not null && saved.PassportNumber is not null && number != saved.PassportNumber)
        {
            warnings.Add(new("passportNumber", DraftIssue.DiffersFromSaved));
        }

        if (country is not null && saved.IssuingCountry is not null && country != saved.IssuingCountry)
        {
            warnings.Add(new("issuingCountry", DraftIssue.DiffersFromSaved));
        }

        if (issuedOn is not null && saved.IssuedOn is not null && issuedOn != saved.IssuedOn)
        {
            warnings.Add(new("issuedOn", DraftIssue.DiffersFromSaved));
        }

        // Worth saving when it fills in something the passport header doesn't have yet.
        var addsSomething = (number is not null && saved.PassportNumber is null)
            || (country is not null && saved.IssuingCountry is null)
            || (issuedOn is not null && saved.IssuedOn is null);
        return new DraftPassport(number, country, issuedOn, Clean(scanned.Evidence), Math.Max(1, scanned.Page), warnings,
            Selected: addsSomething && OnlyNotes(warnings));
    }

    /// <summary>Adds an "invalid" warning for each field the validation refused, unless the field is flagged already.</summary>
    private static void Flag(List<DraftWarning> warnings, ValidationErrors errors, string prefix)
    {
        foreach (var key in errors.ToDictionary().Keys)
        {
            var field = key.StartsWith(prefix, StringComparison.Ordinal) ? key[prefix.Length..] : key;
            if (!warnings.Any(w => w.Field == field && w.Issue != DraftIssue.Ambiguous))
            {
                warnings.Add(new(field, DraftIssue.InvalidFormat));
            }
        }
    }

    /// <summary>An entry is checked by default unless something needs fixing first; "check day and month" is only a note.</summary>
    private static bool OnlyNotes(List<DraftWarning> warnings) => warnings.All(w => w.Issue == DraftIssue.Ambiguous);

    /// <summary>The ISO date the model gave, with a warning when it's unreadable or day and month could be swapped.</summary>
    private static DateOnly? ToDate(ScannedDate? scanned, string field, List<DraftWarning> warnings, bool required)
    {
        if (scanned?.Iso is not { } iso || !DateOnly.TryParseExact(iso.Trim(), "yyyy-MM-dd", out var date))
        {
            if (required || scanned?.Raw is not null)
            {
                warnings.Add(new(field, DraftIssue.Unreadable));
            }

            return null;
        }

        if (scanned.Order != DateOrder.YearMonthDay && IsAmbiguous(scanned.Raw))
        {
            warnings.Add(new(field, DraftIssue.Ambiguous));
        }

        return date;
    }

    /// <summary>
    /// Whether day and month could be swapped: "03/04/2025" is ambiguous, also inside other text ("Date: 03.04.2025 г.");
    /// "13/04/2025", "04/04/2025", "3 Apr 2025" and "2025-04-03" are not.
    /// </summary>
    public static bool IsAmbiguous(string? raw)
    {
        if (raw is null || NumericDate().Match(raw) is not { Success: true } date)
        {
            return false;
        }

        var first = int.Parse(date.Groups[1].Value);
        var second = int.Parse(date.Groups[2].Value);
        return first is >= 1 and <= 12 && second is >= 1 and <= 12 && first != second;
    }

    private static bool SameProduct(string? saved, string? scanned) =>
        saved is null || scanned is null || string.Equals(saved.Trim(), scanned.Trim(), StringComparison.OrdinalIgnoreCase);

    private static string? Clean(string? text) => string.IsNullOrWhiteSpace(text) ? null : text.Trim();

    /// <summary>A day, a month and a year written with digits: 03/04/2025, 3.4.25, 03-04-2025.</summary>
    [GeneratedRegex(@"(?<!\d)(\d{1,2})\s*[./-]\s*(\d{1,2})\s*[./-]\s*(\d{4}|\d{2})(?!\d)")]
    private static partial Regex NumericDate();
}
