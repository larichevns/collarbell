using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Pets;

namespace Collarbell.Api.Tests;

/// <summary>How the model's answer to a chip photo becomes numbers for the pet form, without any AI.</summary>
public sealed class IdentifierReadingsTests
{
    private static readonly DateOnly Today = new(2026, 10, 5);

    private static ScannedIdentifier Chip(IdentifierType type, string code, ScannedDate? appliedOn = null, string? location = null) =>
        new(type, code, appliedOn, location, Evidence: null, Page: 1);

    [Fact]
    public void The_same_number_twice_keeps_the_reading_saving_would_take()
    {
        // The sticker read as a non-ISO chip, the handwriting as an ISO one; the place is only in the first.
        var scan = new IdentifierScan(
        [
            Chip(IdentifierType.LegacyChip, "643094100000001", location: "Between shoulder blades"),
            Chip(IdentifierType.IsoChip, "643 094 100 000 001"),
        ]);

        var read = IdentifierReadings.From(scan, Today);

        Assert.Equal(
            new IdentifierReading(IdentifierType.IsoChip, "643094100000001", "643 094 100 000 001", null, "Between shoulder blades", null),
            Assert.Single(read));
    }

    [Theory]
    [InlineData("03.04.2021", "2021-04-03", DateOrder.DayMonthYear, false)]   // 3 April or 4 March: left for the user
    [InlineData("Implanted 03/04/2021", "2021-04-03", DateOrder.DayMonthYear, false)]
    [InlineData("14.08.2021", "2021-08-14", DateOrder.DayMonthYear, true)]    // 14 can only be a day
    [InlineData("3 Apr 2021", "2021-04-03", DateOrder.DayMonthYear, true)]    // the month is a word
    [InlineData("2021-04-03", "2021-04-03", DateOrder.YearMonthDay, true)]
    public void A_date_whose_day_and_month_could_swap_is_left_for_the_user(string raw, string iso, DateOrder order, bool filled)
    {
        var scan = new IdentifierScan([Chip(IdentifierType.IsoChip, "643094100000001", new ScannedDate(raw, iso, order))]);

        var reading = Assert.Single(IdentifierReadings.From(scan, Today));

        DateOnly? expected = filled ? DateOnly.ParseExact(iso, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture) : null;
        Assert.Equal(expected, reading.AppliedOn);
    }
}
