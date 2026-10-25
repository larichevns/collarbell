using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Pets;

namespace Collarbell.Api.Tests;

/// <summary>How the model's answer becomes a draft: the checks the user relies on, without any AI.</summary>
public sealed class ImportDraftTests
{
    private static readonly DateOnly Today = new(2026, 10, 1);
    private static readonly SavedPetData Nothing = new([], new HashSet<string>(), null, null, null);

    [Theory]
    [InlineData("03/04/2025", true)]            // 3 April or 4 March?
    [InlineData("03.04.2025 г.", true)]         // the same with words around it
    [InlineData("Date: 03/04/2025", true)]
    [InlineData("03/04/2025 (Nobivac)", true)]
    [InlineData("3.4.25", true)]
    [InlineData("13/04/2025", false)]           // 13 can only be a day
    [InlineData("04/04/2025", false)]           // the same either way
    [InlineData("3 Apr 2025", false)]           // the month is a word
    [InlineData("2025-04-03", false)]           // year first: unambiguous
    public void Day_and_month_that_could_swap_are_flagged(string raw, bool ambiguous)
    {
        Assert.Equal(ambiguous, ImportDrafts.IsAmbiguous(raw));
    }

    [Fact]
    public void A_clean_entry_is_selected_and_doubtful_ones_are_not()
    {
        var scan = Scan(
            Vaccine("12/03/2025", "2025-03-12", validUntil: ("11/03/2028", "2028-03-11")),
            Vaccine("03/04/2025", "2025-04-03"),                             // ambiguous: still selected, just flagged
            Vaccine("12/03/2027", "2027-03-12"),                             // in the future
            Vaccine(null, null),                                             // date unreadable
            Vaccine("12/03/2025", "2025-03-12", validUntil: ("01/01/2025", "2025-01-01"))); // ends before it starts

        var draft = ImportDrafts.Build(scan, Nothing, Today);

        Assert.Equal(new[] { true, true, false, false, false }, draft.Records.Select(r => r.Selected));
        Assert.Contains(new DraftWarning("performedOn", DraftIssue.Ambiguous), draft.Records[1].Warnings);
        Assert.Contains(new DraftWarning("performedOn", DraftIssue.InFuture), draft.Records[2].Warnings);
        Assert.Contains(new DraftWarning("performedOn", DraftIssue.Unreadable), draft.Records[3].Warnings);
        Assert.Contains(new DraftWarning("validUntil", DraftIssue.EndsBeforeStart), draft.Records[4].Warnings);
        Assert.Equal(new DateOnly(2028, 3, 11), draft.Records[0].ValidUntil);
    }

    [Fact]
    public void Entries_already_saved_or_on_two_photos_are_unchecked()
    {
        var existing = Guid.NewGuid();
        var saved = new SavedPetData(
            [new SavedRecord(existing, CareKind.Vaccination, new DateOnly(2025, 3, 12), "nobivac rabies")],
            new HashSet<string>(), null, null, null);
        var scan = Scan(
            Vaccine("12/03/2025", "2025-03-12"),   // saved before (product differs only in case)
            Vaccine("01/02/2026", "2026-02-01"),
            Vaccine("01/02/2026", "2026-02-01"));  // the same page photographed twice

        var draft = ImportDrafts.Build(scan, saved, Today);

        Assert.Equal(existing, draft.Records[0].DuplicateOf);
        Assert.Equal(new[] { false, true, false }, draft.Records.Select(r => r.Selected));
        Assert.Contains(new DraftWarning("performedOn", DraftIssue.Repeated), draft.Records[2].Warnings);
    }

    [Fact]
    public void Microchips_are_checked_like_typed_ones()
    {
        var saved = new SavedPetData([], new HashSet<string> { "276098100123456" }, null, null, null);
        var scan = new PassportScan(
            [],
            [
                new ScannedIdentifier(IdentifierType.IsoChip, "276 0981 0012 3456", null, null, null, 1), // already on the pet
                new ScannedIdentifier(IdentifierType.IsoChip, "250 2690 0000 1111", null, null, null, 1), // new
                new ScannedIdentifier(IdentifierType.IsoChip, "12345", null, null, null, 1),              // not 15 digits
            ],
            null);

        var draft = ImportDrafts.Build(scan, saved, Today);

        Assert.Equal(new[] { false, true, false }, draft.Identifiers.Select(i => i.Selected));
        Assert.Equal("250269000001111", draft.Identifiers[1].Code);
        Assert.Contains(new DraftWarning("code", DraftIssue.InvalidFormat), draft.Identifiers[2].Warnings);
    }

    [Fact]
    public void Passport_fields_fill_gaps_but_never_overwrite_quietly()
    {
        var empty = ImportDrafts.Build(PassportOnly("de 0123 4567", "de"), Nothing, Today).Passport!;
        var differs = ImportDrafts.Build(
            PassportOnly("FR999", "FR"), Nothing with { PassportNumber = "DE01234567", IssuingCountry = "DE" }, Today).Passport!;

        Assert.True(empty.Selected);
        Assert.Equal(("DE01234567", "DE"), (empty.PassportNumber, empty.IssuingCountry));
        Assert.False(differs.Selected);
        Assert.Contains(new DraftWarning("passportNumber", DraftIssue.DiffersFromSaved), differs.Warnings);
    }

    [Fact]
    public void Each_entry_is_matched_to_the_plan_it_is_a_done_of()
    {
        var rabies = PlanMadeLongAgo(CareKind.Vaccination, [VaccineTarget.Rabies]);
        var dhppi = PlanMadeLongAgo(CareKind.Vaccination, [VaccineTarget.Cdv, VaccineTarget.Cav2, VaccineTarget.Cpv2, VaccineTarget.Cpiv]);
        var deworming = PlanMadeLongAgo(CareKind.Deworming, []);
        var saved = Nothing with { Plans = [rabies, dhppi, deworming] };
        var scan = Scan(
            Vaccine("12/03/2025", "2025-03-12"),                                                    // rabies
            Vaccine("12/03/2025", "2025-03-12") with { Targets = [VaccineTarget.Cdv, VaccineTarget.Cpv2], Product = "Nobivac DHP" },
            Vaccine("12/03/2025", "2025-03-12") with { Kind = CareKind.Deworming, Targets = [], Product = "Milbemax" },
            Vaccine("12/03/2025", "2025-03-12") with { Kind = CareKind.FleaTick, Targets = [], Product = "Bravecto" }); // no plan

        var draft = ImportDrafts.Build(scan, saved, Today);

        Assert.Equal(new Guid?[] { rabies.Id, dhppi.Id, deworming.Id, null }, draft.Records.Select(r => r.PlanId));
    }

    [Fact]
    public void Only_the_newest_entry_of_a_plan_is_its_done()
    {
        var rabies = PlanMadeLongAgo(CareKind.Vaccination, [VaccineTarget.Rabies]);
        var scan = Scan(
            Vaccine("12/03/2022", "2022-03-12"),
            Vaccine("12/03/2025", "2025-03-12"),
            Vaccine("12/03/2023", "2023-03-12"));

        var draft = ImportDrafts.Build(scan, Nothing with { Plans = [rabies] }, Today);

        Assert.Equal(new Guid?[] { null, rabies.Id, null }, draft.Records.Select(r => r.PlanId));
    }

    [Theory]
    // made 2026-09-01, next 2026-12-01, every 3 months; no "Done" yet
    [InlineData("2026-09-20", null, null, true)]           // done after the plan was made: news, like "Done"
    [InlineData("2025-04-03", null, null, false)]          // older than the plan, would move it back: no
    [InlineData("2026-08-20", null, null, false)]          // older than the plan: 2026-11-20 is earlier than planned
    [InlineData("2026-08-20", "2027-08-19", null, true)]   // older, but valid longer than planned: pushes it later
    [InlineData("2026-09-20", null, "2026-09-25", false)]  // the plan was done later than this already
    public void A_scanned_entry_moves_a_plan_only_with_news(string performedOn, string? validUntil, string? lastDone, bool moves)
    {
        var plan = new PlanSummary(Guid.NewGuid(), CareKind.Deworming, [], 3, IntervalUnit.Month,
            NextDueOn: new DateOnly(2026, 12, 1), CreatedOn: new DateOnly(2026, 9, 1),
            LastDoneOn: lastDone is null ? null : DateOnly.Parse(lastDone));

        Assert.Equal(moves, plan.MovedBy(DateOnly.Parse(performedOn), validUntil is null ? null : DateOnly.Parse(validUntil)));
    }

    [Fact]
    public void An_old_entry_never_closes_a_one_off_plan()
    {
        var trip = new PlanSummary(Guid.NewGuid(), CareKind.Deworming, [], null, null,
            NextDueOn: Today.AddDays(20), CreatedOn: Today.AddDays(-10), LastDoneOn: null);

        Assert.False(trip.MovedBy(new DateOnly(2025, 4, 3), null));
        Assert.True(trip.MovedBy(Today.AddDays(-2), null)); // done after it was planned: it's done
    }

    [Fact]
    public void Whatever_saving_would_refuse_is_flagged_and_unchecked()
    {
        var scan = Scan(
            Vaccine("12/03/1985", "1985-03-12"),                                                  // before 1990
            Vaccine("12/03/2025", "2025-03-12") with { ValidFrom = new ScannedDate("01/03/2025", "2025-03-01", DateOrder.DayMonthYear) },
            Vaccine("12/03/2025", "2025-03-12") with { Product = new string('x', 150) });         // too long

        var draft = ImportDrafts.Build(scan, Nothing, Today);

        Assert.All(draft.Records, r => Assert.False(r.Selected));
        Assert.Contains(new DraftWarning("performedOn", DraftIssue.InvalidFormat), draft.Records[0].Warnings);
        Assert.Contains(new DraftWarning("validFrom", DraftIssue.InvalidFormat), draft.Records[1].Warnings);
        Assert.Contains(new DraftWarning("product", DraftIssue.InvalidFormat), draft.Records[2].Warnings);
    }

    [Fact]
    public void A_saved_country_is_never_overwritten_quietly()
    {
        var saved = Nothing with { IssuingCountry = "DE" };

        var passport = ImportDrafts.Build(PassportOnly("DE0123456", "FR"), saved, Today).Passport!;

        Assert.False(passport.Selected);
        Assert.Contains(new DraftWarning("issuingCountry", DraftIssue.DiffersFromSaved), passport.Warnings);
    }

    [Fact]
    public void A_passport_number_saving_would_refuse_is_flagged()
    {
        var passport = ImportDrafts.Build(PassportOnly("DE 0123 *** 4567", "DE"), Nothing, Today).Passport!;

        Assert.False(passport.Selected);
        Assert.Contains(new DraftWarning("passportNumber", DraftIssue.InvalidFormat), passport.Warnings);
    }

    [Fact]
    public void A_chip_with_an_ambiguous_date_stays_checked()
    {
        var scan = new PassportScan([],
            [new ScannedIdentifier(IdentifierType.IsoChip, "250269000001111",
                new ScannedDate("03/04/2021", "2021-04-03", DateOrder.DayMonthYear), null, null, 1)],
            null);

        var chip = Assert.Single(ImportDrafts.Build(scan, Nothing, Today).Identifiers);

        Assert.True(chip.Selected);
        Assert.Contains(new DraftWarning("appliedOn", DraftIssue.Ambiguous), chip.Warnings);
    }

    [Fact]
    public void An_answer_with_lists_left_out_still_makes_a_draft()
    {
        var scan = new PassportScan(null!, null!, null);
        var noTargets = new PassportScan([Vaccine("12/03/2025", "2025-03-12") with { Targets = null! }], [], null);

        Assert.Empty(ImportDrafts.Build(scan, Nothing, Today).Records);
        Assert.Empty(Assert.Single(ImportDrafts.Build(noTargets, Nothing, Today).Records).Targets);
    }

    [Fact]
    public void An_entry_without_a_title_is_left_for_the_app_to_name()
    {
        var draft = ImportDrafts.Build(Scan(Vaccine("12/03/2025", "2025-03-12") with { Title = null }), Nothing, Today);

        var record = Assert.Single(draft.Records);
        Assert.Null(record.Title);
        Assert.True(record.Selected);
    }

    [Fact]
    public void A_check_up_keeps_the_weight_it_noted_and_other_entries_none()
    {
        var checkUp = Vaccine("12/03/2025", "2025-03-12") with { Kind = CareKind.VetExam, Targets = [], WeightKg = 4.236m };
        var scan = Scan(
            checkUp,
            Vaccine("12/03/2025", "2025-03-12") with { WeightKg = 4.2m },              // a vaccination has no weight
            checkUp with { PerformedOn = new ScannedDate("01/05/2025", "2025-05-01", DateOrder.DayMonthYear), WeightKg = 4200 }); // grams read as kilograms

        var draft = ImportDrafts.Build(scan, Nothing, Today);

        Assert.Equal(new decimal?[] { 4.24m, null, 4200 }, draft.Records.Select(r => r.WeightKg));
        Assert.Equal(new[] { true, true, false }, draft.Records.Select(r => r.Selected));
        Assert.Contains(new DraftWarning("weightKg", DraftIssue.InvalidFormat), draft.Records[2].Warnings);
    }

    [Fact]
    public void A_wrong_weight_is_flagged_even_when_the_date_is_unreadable()
    {
        var scan = Scan(Vaccine(null, null) with
        {
            Kind = CareKind.VetExam,
            Targets = [],
            PerformedOn = new ScannedDate("1?/0?/2025", null, DateOrder.DayMonthYear),
            WeightKg = 4200,
        });

        var draft = ImportDrafts.Build(scan, Nothing, Today);

        Assert.Contains(new DraftWarning("weightKg", DraftIssue.InvalidFormat), draft.Records[0].Warnings);
    }

    [Fact]
    public void Weights_become_weighings_unless_saved_given_twice_or_refused()
    {
        var saved = new SavedPetData([], new HashSet<string>(), null, null, null)
        {
            Weights = [new SavedWeight(Guid.NewGuid(), new DateOnly(2026, 9, 30), 4.2m)],
            ExactBirthDate = new DateOnly(2024, 3, 1),
        };
        ScannedWeight Weight(string? iso, decimal? kg) => new(iso is null ? null : new ScannedDate(iso, iso, DateOrder.YearMonthDay), kg, "4,2", 1);
        var checkUp = Vaccine("12/09/2026", "2026-09-12") with { Kind = CareKind.VetExam, Targets = [], WeightKg = 4.15m };
        var scan = Scan(checkUp) with
        {
            Weights =
            [
                Weight("2026-09-25", 4.1234m),  // a new one, kept to the gram
                Weight("2026-09-30", 4.2m),     // in the log already
                Weight("2026-09-25", 4.123m),   // the same as the first
                Weight("2026-09-12", 4.15m),    // the check-up's own weight
                Weight("2024-02-01", 0.5m),     // before the kitten was born
                Weight("2026-09-26", 4200),     // grams read as kilograms
                Weight(null, 4.3m),             // no date
                Weight("2026-10-05", 4.3m),     // in the future
            ],
        };

        var draft = ImportDrafts.Build(scan, saved, Today);

        Assert.Equal(4.123m, draft.Weights[0].WeightKg);
        Assert.Equal(new[] { true, false, false, false, false, false, false, false }, draft.Weights.Select(w => w.Selected));
        Assert.Contains(new DraftWarning("measuredOn", DraftIssue.AlreadySaved), draft.Weights[1].Warnings);
        Assert.Equal(saved.Weights[0].Id, draft.Weights[1].DuplicateOf);
        Assert.Contains(new DraftWarning("measuredOn", DraftIssue.Repeated), draft.Weights[2].Warnings);
        Assert.Contains(new DraftWarning("measuredOn", DraftIssue.Repeated), draft.Weights[3].Warnings);
        Assert.Contains(new DraftWarning("measuredOn", DraftIssue.InvalidFormat), draft.Weights[4].Warnings);
        Assert.Contains(new DraftWarning("weightKg", DraftIssue.InvalidFormat), draft.Weights[5].Warnings);
        Assert.Contains(new DraftWarning("measuredOn", DraftIssue.Unreadable), draft.Weights[6].Warnings);
        Assert.Contains(new DraftWarning("measuredOn", DraftIssue.InFuture), draft.Weights[7].Warnings);
    }

    [Fact]
    public void A_weight_in_grams_a_check_up_carries_is_not_offered_again()
    {
        var day = new ScannedDate("2026-09-12", "2026-09-12", DateOrder.YearMonthDay);
        var checkUp = Vaccine("12/09/2026", "2026-09-12") with { Kind = CareKind.VetExam, Targets = [], WeightKg = 0.835m };
        var withTheCheckUp = Scan(checkUp) with { Weights = [new ScannedWeight(day, 0.835m, "835 г", 1)] };
        var saved = new SavedPetData([], new HashSet<string>(), null, null, null)
        {
            Weights = [new SavedWeight(Guid.NewGuid(), new DateOnly(2026, 9, 12), 0.84m, FromCheckUp: true)],
        };
        var alone = Scan() with { Weights = [new ScannedWeight(day, 0.835m, "835 г", 1)] };

        // The check-up keeps it as 0.84: the weighing of 0.835 is the same weight.
        Assert.Contains(new DraftWarning("measuredOn", DraftIssue.Repeated), ImportDrafts.Build(withTheCheckUp, Nothing, Today).Weights[0].Warnings);
        var draft = ImportDrafts.Build(alone, saved, Today);
        Assert.Equal(saved.Weights[0].Id, draft.Weights[0].DuplicateOf);
        Assert.False(draft.Weights[0].Selected);
    }

    [Fact]
    public void An_answer_kept_from_before_weights_has_none()
    {
        var scan = System.Text.Json.JsonSerializer.Deserialize<PassportScan>(
            """{"records":[],"identifiers":[],"passport":null}""", AiRunner.Json)!;

        Assert.Empty(ImportDrafts.Build(scan, Nothing, Today).Weights);
    }

    private static PlanSummary PlanMadeLongAgo(CareKind kind, List<VaccineTarget> targets) =>
        new(Guid.NewGuid(), kind, targets, 1, IntervalUnit.Year, NextDueOn: Today, CreatedOn: new DateOnly(2020, 1, 1), LastDoneOn: null);

    private static PassportScan Scan(params ScannedRecord[] records) => new([.. records], [], null);

    private static PassportScan PassportOnly(string number, string country) =>
        new([], [], new ScannedPassport(number, country, null, null, 1));

    private static ScannedRecord Vaccine(string? raw, string? iso, (string Raw, string Iso)? validUntil = null) =>
        new(CareKind.Vaccination, "Rabies vaccination",
            raw is null && iso is null ? null : new ScannedDate(raw, iso, DateOrder.DayMonthYear),
            null, "Nobivac Rabies", "MSD", "A123", null,
            validUntil is { } until ? new ScannedDate(until.Raw, until.Iso, DateOrder.DayMonthYear) : null,
            [VaccineTarget.Rabies], null, null, WeightKg: null, raw, Page: 1);
}
