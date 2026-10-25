using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Appointments;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Collarbell.Api.Modules.Supplies;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Collarbell.Api.Modules.Today;

/// <summary>
/// The main screen for all active pets: today's feedings with their marks, planned visits, care that is due, and what
/// to buy. <see cref="Date"/> is "today" in the household's time zone unless the request names a date; what to buy is
/// always as of now.
/// </summary>
public sealed record TodayResponse(
    DateOnly Date,
    List<TodayFeedingItem> Feedings,
    List<TodayAppointmentItem> Appointments,
    List<TodayCareItem> Care,
    List<TodaySupplyItem> Shopping);

/// <summary>A supply to buy now: it runs out within its delivery time, or has run out.</summary>
public sealed record TodaySupplyItem(
    Guid Id,
    string Name,
    string? Brand,
    SupplyCategory Category,
    SupplyUnit Unit,
    decimal PackageSize,
    SupplyStatus Status,
    decimal? Remaining,
    decimal? DaysLeft,
    DateOnly? RunsOutOn);

/// <summary>A plan that is overdue or due within <see cref="TodayEndpoints.WindowDays"/> days.</summary>
public sealed record TodayCareItem(
    Guid PlanId,
    Guid PetId,
    string PetName,
    Coat PetCoat,
    FileLink? PetPhoto,
    CareKind Kind,
    string Title,
    DateOnly NextDueOn,
    CareStatus Status,
    int DaysLeft);

/// <summary>One feeding of the day: a pet at a time, with its mark when someone marked it.</summary>
public sealed record TodayFeedingItem(
    Guid RoutineId,
    Guid PetId,
    string PetName,
    Coat PetCoat,
    FileLink? PetPhoto,
    TimeOnly Time,
    string? Food,
    decimal? Amount,
    PortionUnit? Unit,
    RoutineCompletionResponse? Mark);

public sealed record TodayPet(Guid Id, string Name, Coat Coat, FileLink? Photo);

/// <summary>
/// A planned visit from <see cref="TodayEndpoints.PastVisitDays"/> days ago (one that took place but wasn't marked
/// done yet) to <see cref="TodayEndpoints.WindowDays"/> days ahead. Date and time are the household's.
/// <see cref="DaysAway"/> is negative for a past one.
/// </summary>
public sealed record TodayAppointmentItem(
    Guid Id,
    AppointmentType Type,
    string Title,
    DateOnly Date,
    TimeOnly Time,
    DateTimeOffset StartsAt,
    int DaysAway,
    string? Location,
    List<TodayPet> Pets);

public static class TodayEndpoints
{
    /// <summary>How far ahead the main screen looks.</summary>
    public const int WindowDays = 30;

    /// <summary>How long a past visit waits on the main screen to be marked done.</summary>
    public const int PastVisitDays = 7;

    public static RouteGroupBuilder MapTodayEndpoints(this RouteGroupBuilder api)
    {
        api.MapGet("/today", GetToday)
            .WithTags("Today")
            .WithName("GetToday")
            .WithSummary($"Today's feedings, planned visits, care overdue or due within {WindowDays} days for all active pets, and what to buy.");
        return api;
    }

    private static async Task<Results<Ok<TodayResponse>, ValidationProblem>> GetToday(
        DateOnly? date,
        CurrentUserAccessor current,
        HouseholdCalendar calendar,
        CarePlanDirectory plans,
        FeedingDirectory feeding,
        AppointmentDirectory appointments,
        PetDirectory pets,
        SupplyStock supplies,
        Files files,
        TimeProvider clock,
        CancellationToken ct)
    {
        if (date is { } asked && (asked < CareRules.EarliestDate || asked > new DateOnly(2100, 1, 1)))
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["date"] = ["Use a date from 1990 to 2100."],
            });
        }

        var me = await current.GetAsync(ct);
        var zone = await calendar.TimeZoneAsync(me.HouseholdId, ct);
        var today = date ?? calendar.Today(zone);

        var allPets = (await pets.CardsAsync(me.HouseholdId, ct)).ToDictionary(p => p.Id);
        var activePets = allPets.Values.Where(p => p.Status == PetStatus.Active).ToDictionary(p => p.Id);

        var due = (await plans.DueByAsync(me.HouseholdId, today.AddDays(WindowDays), ct))
            .Where(p => activePets.ContainsKey(p.PetId))
            .ToList();
        var feedings = (await feeding.OnAsync(me.HouseholdId, me.UserId, today, ct))
            .Where(f => activePets.ContainsKey(f.Routine.PetId))
            .ToList();
        var visits = await appointments.PlannedBetweenAsync(me.HouseholdId,
            LocalTimes.Moment(today.AddDays(-PastVisitDays), TimeOnly.MinValue, zone),
            LocalTimes.Moment(today.AddDays(WindowDays + 1), TimeOnly.MinValue, zone),
            ct);

        var photoIds = due.Select(p => p.PetId)
            .Concat(feedings.Select(f => f.Routine.PetId))
            .Concat(visits.SelectMany(v => v.Pets.Select(p => p.PetId)))
            .Distinct()
            .Select(id => allPets.GetValueOrDefault(id)?.PhotoFileId)
            .OfType<Guid>();
        var photos = await files.LinksAsync(photoIds, ct);
        FileLink? PhotoOf(PetCard pet) => pet.PhotoFileId is { } photoId ? photos.GetValueOrDefault(photoId) : null;

        var care = due
            .Select(plan =>
            {
                var pet = activePets[plan.PetId];
                return new TodayCareItem(
                    plan.Id,
                    pet.Id,
                    pet.Name,
                    pet.Coat,
                    PhotoOf(pet),
                    plan.Kind,
                    plan.Title,
                    plan.NextDueOn,
                    plan.StatusOn(today),
                    plan.NextDueOn.DayNumber - today.DayNumber);
            })
            .OrderBy(i => i.NextDueOn)
            .ThenBy(i => i.PetName, StringComparer.CurrentCulture)
            .ToList();

        var feedingItems = feedings
            .Select(f =>
            {
                var pet = activePets[f.Routine.PetId];
                return new TodayFeedingItem(f.Routine.Id, pet.Id, pet.Name, pet.Coat, PhotoOf(pet), f.Time,
                    f.Routine.Food, f.Routine.Amount, f.Routine.Unit, f.Mark);
            })
            .OrderBy(i => i.Time)
            .ThenBy(i => i.PetName, StringComparer.CurrentCulture)
            .ToList();

        var visitItems = visits
            .Select(v =>
            {
                var (visitDate, visitTime) = LocalTimes.LocalAt(v.StartsAt, zone);
                return new TodayAppointmentItem(v.Id, v.Type, v.Title, visitDate, visitTime, v.StartsAt,
                    visitDate.DayNumber - today.DayNumber, v.Location,
                    [.. v.Pets
                        .Select(p => allPets.GetValueOrDefault(p.PetId))
                        .OfType<PetCard>()
                        .OrderBy(p => p.Name, StringComparer.CurrentCulture)
                        .Select(p => new TodayPet(p.Id, p.Name, p.Coat, PhotoOf(p)))]);
            })
            .ToList();

        var shopping = (await supplies.StatesAsync(me.HouseholdId, zone, clock.GetUtcNow(), ct))
            .Where(s => s.Item.Active && s.Forecast.Status is SupplyStatus.BuyNow or SupplyStatus.OutOfStock)
            .OrderBy(s => s.Forecast.RunsOutOn)
            .ThenBy(s => s.Item.Name, StringComparer.CurrentCultureIgnoreCase)
            .Select(s => new TodaySupplyItem(s.Item.Id, s.Item.Name, s.Item.Brand, s.Item.Category, s.Item.Unit, s.Item.PackageSize,
                s.Forecast.Status, s.Forecast.Remaining, s.Forecast.DaysLeft, s.Forecast.RunsOutOn))
            .ToList();

        return TypedResults.Ok(new TodayResponse(today, feedingItems, visitItems, care, shopping));
    }
}
