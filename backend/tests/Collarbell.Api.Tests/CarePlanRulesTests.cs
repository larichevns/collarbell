using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Pets;

namespace Collarbell.Api.Tests;

/// <summary>Plan rules without the API or a database: fast, and they read like the spec.</summary>
public sealed class CarePlanRulesTests
{
    private static readonly DateOnly Today = new(2026, 10, 1);
    private static readonly DateTimeOffset Now = new(2026, 10, 1, 9, 0, 0, TimeSpan.Zero);

    [Theory]
    [InlineData(-1, CareStatus.Overdue)]
    [InlineData(0, CareStatus.DueSoon)] // due today is not late yet
    [InlineData(14, CareStatus.DueSoon)]
    [InlineData(15, CareStatus.Upcoming)]
    public void Status_follows_the_due_date(int daysFromToday, CareStatus expected)
    {
        var plan = Plan(Today.AddDays(daysFromToday));

        Assert.Equal(expected, plan.StatusOn(Today));
    }

    [Fact]
    public void An_inactive_plan_is_inactive_whatever_its_date()
    {
        var plan = Plan(Today.AddDays(-30));
        plan.Active = false;

        Assert.Equal(CareStatus.Inactive, plan.StatusOn(Today));
    }

    [Fact]
    public void Done_moves_a_monthly_plan_to_the_last_day_of_a_shorter_month()
    {
        var plan = Plan(new DateOnly(2027, 1, 31), every: 1, IntervalUnit.Month);

        plan.MarkDone(performedOn: new DateOnly(2027, 1, 31), validUntil: null, chosenNextDueOn: null, Now);

        Assert.Equal(new DateOnly(2027, 2, 28), plan.NextDueOn);
    }

    [Fact]
    public void Done_prefers_the_chosen_date_then_valid_until_then_the_interval()
    {
        var done = new DateOnly(2026, 9, 20);

        var byInterval = Plan(Today, every: 1, IntervalUnit.Year);
        byInterval.MarkDone(done, validUntil: null, chosenNextDueOn: null, Now);
        var byValidity = Plan(Today, every: 1, IntervalUnit.Year);
        byValidity.MarkDone(done, validUntil: new DateOnly(2029, 9, 19), chosenNextDueOn: null, Now);
        var byChoice = Plan(Today, every: 1, IntervalUnit.Year);
        byChoice.MarkDone(done, validUntil: new DateOnly(2029, 9, 19), chosenNextDueOn: new DateOnly(2027, 3, 1), Now);

        Assert.Equal(new DateOnly(2027, 9, 20), byInterval.NextDueOn);
        Assert.Equal(new DateOnly(2029, 9, 19), byValidity.NextDueOn);
        Assert.Equal(new DateOnly(2027, 3, 1), byChoice.NextDueOn);
    }

    [Fact]
    public void A_one_off_plan_finishes_when_done()
    {
        var plan = Plan(Today);

        plan.MarkDone(Today, validUntil: null, chosenNextDueOn: null, Now);

        Assert.False(plan.Active);
        Assert.Equal(CareStatus.Inactive, plan.StatusOn(Today));
    }

    [Fact]
    public void Cats_never_get_dog_only_presets()
    {
        Assert.DoesNotContain(CarePresets.For(Species.Cat), p => p.DogOnly || p.Species == Species.Dog);
        Assert.Contains(CarePresets.For(Species.Dog), p => p.Code == "dog-advantix" && p.DogOnly);
    }

    [Fact]
    public void Preset_codes_are_unique_and_vaccinations_name_their_targets()
    {
        Assert.Equal(CarePresets.All.Count, CarePresets.All.Select(p => p.Code).Distinct().Count());
        Assert.All(CarePresets.All.Where(p => p.Kind == CareKind.Vaccination), p => Assert.NotEmpty(p.Targets));
        Assert.All(CarePresets.All.Where(p => p.Kind != CareKind.Vaccination), p => Assert.Empty(p.Targets));
    }

    private static CarePlan Plan(DateOnly nextDueOn, int? every = null, IntervalUnit? unit = null) =>
        new(Guid.NewGuid(), Guid.NewGuid(), CareKind.Other, "Test", nextDueOn, Now)
        {
            IntervalValue = every,
            IntervalUnit = unit,
        };
}
