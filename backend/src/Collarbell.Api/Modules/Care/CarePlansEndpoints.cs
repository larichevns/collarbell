using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Care;

public sealed record CarePresetResponse(
    string Code,
    Species? Species,
    CareKind Kind,
    string Title,
    int? IntervalValue,
    IntervalUnit? IntervalUnit,
    List<VaccineTarget> Targets,
    bool DogOnly,
    string? Note);

/// <summary>
/// Create or replace a plan. Leave <see cref="IntervalValue"/> and <see cref="IntervalUnit"/> empty for a one-off.
/// On update a missing <see cref="Active"/> keeps its value. <see cref="RequestId"/> (creating only): a new id per
/// plan the app creates, the same on retries, so a retry after a lost response doesn't add the plan twice.
/// </summary>
public sealed record CarePlanRequest(
    CareKind Kind,
    string Title,
    int? IntervalValue,
    IntervalUnit? IntervalUnit,
    DateOnly NextDueOn,
    List<int>? RemindOffsetsDays,
    string? DefaultProduct,
    List<VaccineTarget>? Targets,
    string? PresetCode,
    string? Notes,
    bool? Active,
    Guid? RequestId);

/// <summary>A plan with its status on the household's today; <see cref="DaysLeft"/> is negative when overdue.</summary>
public sealed record CarePlanResponse(
    Guid Id,
    Guid PetId,
    CareKind Kind,
    string Title,
    int? IntervalValue,
    IntervalUnit? IntervalUnit,
    DateOnly NextDueOn,
    CareStatus Status,
    int DaysLeft,
    DateOnly? LastDoneOn,
    List<int> RemindOffsetsDays,
    string? DefaultProduct,
    List<VaccineTarget> Targets,
    string? PresetCode,
    string? Notes,
    bool Active,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

/// <summary>
/// "Done": the details go into a new record. <see cref="NextDueOn"/> replaces the computed next date
/// (the vet may have set another one). Photos are added to the record afterwards.
/// <see cref="RequestId"/> is a new id per "Done" the app makes, the same on retries: a retry after a lost
/// response then gets the first result back instead of marking the plan done twice.
/// </summary>
public sealed record CompleteCarePlanRequest(
    DateOnly PerformedOn,
    TimeOnly? PerformedTime,
    string? Product,
    string? Manufacturer,
    string? BatchNumber,
    DateOnly? ValidFrom,
    DateOnly? ValidUntil,
    string? Clinic,
    string? Veterinarian,
    string? Notes,
    DateOnly? NextDueOn,
    Guid? RequestId);

public sealed record CompleteCarePlanResponse(CarePlanResponse Plan, CareRecordResponse Record);

public static class CarePlansEndpoints
{
    public static RouteGroupBuilder MapCarePlansEndpoints(this RouteGroupBuilder api)
    {
        api.MapGet("/care-plan-presets", ListPresets)
            .WithTags("Care")
            .WithName("ListCarePlanPresets")
            .WithSummary("Ready-made plans with default intervals; with species, only the ones that suit it.");

        var petPlans = api.MapGroup("/pets/{petId:guid}/care-plans").WithTags("Care").ReportsChanges(LiveTopics.Care);

        petPlans.MapGet("", ListForPet)
            .WithName("ListPetCarePlans")
            .WithSummary("The pet's plans with their status: active first, soonest due first.");

        petPlans.MapPost("", Create)
            .WithName("CreateCarePlan")
            .WithSummary("Add a plan, from a preset or your own.");

        var plans = api.MapGroup("/care-plans").WithTags("Care").ReportsChanges(LiveTopics.Care);

        plans.MapGet("/{id:guid}", Get)
            .WithName("GetCarePlan")
            .WithSummary("One plan.");

        plans.MapPut("/{id:guid}", Update)
            .WithName("UpdateCarePlan")
            .WithSummary("Change a plan, including its next date.");

        plans.MapDelete("/{id:guid}", Delete)
            .WithName("DeleteCarePlan")
            .WithSummary("Delete a plan. The records it created stay in the history.");

        plans.MapPost("/{id:guid}/complete", Complete)
            .AllowHelpers()
            .WithName("CompleteCarePlan")
            .WithSummary("\"Done\": add a record and move the plan to its next date (a one-off plan finishes).");

        return api;
    }

    private static Ok<List<CarePresetResponse>> ListPresets(Species? species) =>
        TypedResults.Ok((species is { } s ? CarePresets.For(s) : CarePresets.All)
            .Select(p => new CarePresetResponse(
                p.Code, p.Species, p.Kind, p.Title, p.IntervalValue, p.IntervalUnit, p.Targets, p.DogOnly, p.Note))
            .ToList());

    private static async Task<Results<Ok<List<CarePlanResponse>>, NotFound>> ListForPet(
        Guid petId,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        HouseholdCalendar calendar,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        var today = await calendar.TodayAsync(me.HouseholdId, ct);
        var plans = await db.CarePlans.AsNoTracking()
            .Where(p => p.HouseholdId == me.HouseholdId && p.PetId == petId)
            .ToListAsync(ct);
        var lastDone = await LastDoneAsync(db, plans.Select(p => p.Id), ct);
        return TypedResults.Ok(plans
            .OrderBy(p => !p.Active)
            .ThenBy(p => p.NextDueOn)
            .Select(p => ToResponse(p, today, lastDone))
            .ToList());
    }

    private static async Task<Results<Ok<CarePlanResponse>, NotFound>> Get(
        Guid id, CurrentUserAccessor current, AppDbContext db, HouseholdCalendar calendar, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var plan = await FindAsync(db, me, id, ct);
        if (plan is null)
        {
            return TypedResults.NotFound();
        }

        var today = await calendar.TodayAsync(me.HouseholdId, ct);
        return TypedResults.Ok(ToResponse(plan, today, await LastDoneAsync(db, [plan.Id], ct)));
    }

    private static async Task<Results<Created<CarePlanResponse>, NotFound, ValidationProblem>> Create(
        Guid petId,
        CarePlanRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        HouseholdCalendar calendar,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (await pets.SpeciesAsync(me.HouseholdId, petId, ct) is not { } species)
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request, species, currentPresetCode: null, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var today = await calendar.TodayAsync(me.HouseholdId, ct);
        if (request.RequestId is { } requestId
            && await db.CarePlans.SingleOrDefaultAsync(p => p.HouseholdId == me.HouseholdId && p.ClientRequestId == requestId, ct)
                is { } earlier)
        {
            // A retry of a create that already went through: answer as the first time.
            return TypedResults.Created(
                $"/api/v1/care-plans/{earlier.Id}", ToResponse(earlier, today, await LastDoneAsync(db, [earlier.Id], ct)));
        }

        var plan = new CarePlan(me.HouseholdId, petId, request.Kind, request.Title.Trim(), request.NextDueOn, clock.GetUtcNow())
        {
            ClientRequestId = request.RequestId,
        };
        Apply(request, plan);
        plan.Active = request.Active ?? true;
        db.CarePlans.Add(plan);
        await db.SaveChangesAsync(ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Created($"/api/v1/care-plans/{plan.Id}", ToResponse(plan, today, new Dictionary<Guid, DateOnly>()));
    }

    private static async Task<Results<Ok<CarePlanResponse>, NotFound, ValidationProblem>> Update(
        Guid id,
        CarePlanRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        HouseholdCalendar calendar,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var plan = await FindAsync(db, me, id, ct);
        if (plan is null || await pets.SpeciesAsync(me.HouseholdId, plan.PetId, ct) is not { } species)
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request, species, plan.PresetCode, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        plan.Kind = request.Kind;
        plan.Title = request.Title.Trim();
        plan.NextDueOn = request.NextDueOn;
        plan.Active = request.Active ?? plan.Active;
        Apply(request, plan);
        plan.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);

        var today = await calendar.TodayAsync(me.HouseholdId, ct);
        return TypedResults.Ok(ToResponse(plan, today, await LastDoneAsync(db, [plan.Id], ct)));
    }

    private static async Task<Results<NoContent, NotFound>> Delete(
        Guid id, CurrentUserAccessor current, AppDbContext db, ReminderSchedule reminders, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var plan = await FindAsync(db, me, id, ct);
        if (plan is null)
        {
            return TypedResults.NotFound();
        }

        db.CarePlans.Remove(plan);
        await db.SaveChangesAsync(ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<CompleteCarePlanResponse>, NotFound, ValidationProblem>> Complete(
        Guid id,
        CompleteCarePlanRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        HouseholdCalendar calendar,
        Files files,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var plan = await FindAsync(db, me, id, ct);
        if (plan is null)
        {
            return TypedResults.NotFound();
        }

        var errors = ValidateCompletion(request, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var today = await calendar.TodayAsync(me.HouseholdId, ct);
        var earlier = request.RequestId is { } requestId
            ? await db.CareRecords.Include(r => r.Files)
                .SingleOrDefaultAsync(r => r.HouseholdId == me.HouseholdId && r.ClientRequestId == requestId, ct)
            : null;
        if (earlier is not null && earlier.PlanId != plan.Id)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["requestId"] = ["This request id was used for something else."],
            });
        }

        // A plan is done once per day: the same "Done" sent again (a retry, a second phone, a second tap after an
        // error) gets the first result back and moves nothing.
        earlier ??= await db.CareRecords.Include(r => r.Files)
            .FirstOrDefaultAsync(r => r.PlanId == plan.Id && r.PerformedOn == request.PerformedOn, ct);
        if (earlier is not null)
        {
            return TypedResults.Ok(new CompleteCarePlanResponse(
                ToResponse(plan, today, await LastDoneAsync(db, [plan.Id], ct)),
                await CareRecordsEndpoints.ToResponseAsync(earlier, files, ct)));
        }

        var now = clock.GetUtcNow();
        // The app fills in the plan's usual product; an empty product here means none was given.
        var record = new CareRecord(me.HouseholdId, plan.PetId, plan.Kind, plan.Title, request.PerformedOn, me.UserId, now)
        {
            PlanId = plan.Id,
            PerformedTime = request.PerformedTime,
            Product = Input.Clean(request.Product),
            Manufacturer = Input.Clean(request.Manufacturer),
            BatchNumber = Input.Clean(request.BatchNumber),
            ValidFrom = request.ValidFrom,
            ValidUntil = request.ValidUntil,
            Targets = [.. plan.Targets],
            Clinic = Input.Clean(request.Clinic),
            Veterinarian = Input.Clean(request.Veterinarian),
            Notes = Input.Clean(request.Notes),
            ClientRequestId = request.RequestId,
        };
        db.CareRecords.Add(record);
        // A helper's "Done" moves the plan by its own interval: the next date is the owners' and members' to change.
        plan.MarkDone(request.PerformedOn, request.ValidUntil, me.Role == HouseholdRole.Helper ? null : request.NextDueOn, now);
        await db.SaveChangesAsync(ct);
        // The plan is due on its next date now: the reminders of the old one go, the new date gets its own.
        await reminders.RefreshAsync(me.HouseholdId, ct);

        return TypedResults.Ok(new CompleteCarePlanResponse(
            ToResponse(plan, today, await LastDoneAsync(db, [plan.Id], ct)),
            await CareRecordsEndpoints.ToResponseAsync(record, files, ct)));
    }

    /// <summary>Only plans of the caller's household are found; someone else's is "not found".</summary>
    private static Task<CarePlan?> FindAsync(AppDbContext db, CurrentUser me, Guid id, CancellationToken ct) =>
        db.CarePlans.SingleOrDefaultAsync(p => p.Id == id && p.HouseholdId == me.HouseholdId, ct);

    /// <summary>Fields that create and update set the same way.</summary>
    private static void Apply(CarePlanRequest request, CarePlan plan)
    {
        plan.IntervalValue = request.IntervalValue;
        plan.IntervalUnit = request.IntervalUnit;
        plan.RemindOffsetsDays = (request.RemindOffsetsDays ?? [7, 1, 0]).OrderByDescending(d => d).ToList();
        plan.DefaultProduct = Input.Clean(request.DefaultProduct);
        plan.Targets = request.Kind == CareKind.Vaccination ? [.. request.Targets ?? []] : [];
        plan.PresetCode = request.PresetCode;
        plan.Notes = Input.Clean(request.Notes);
    }

    /// <summary>The last "Done" date of each plan.</summary>
    internal static async Task<Dictionary<Guid, DateOnly>> LastDoneAsync(AppDbContext db, IEnumerable<Guid> planIds, CancellationToken ct)
    {
        var ids = planIds.ToList();
        return await db.CareRecords
            .Where(r => r.PlanId != null && ids.Contains(r.PlanId.Value))
            .GroupBy(r => r.PlanId!.Value)
            .Select(g => new { PlanId = g.Key, Last = g.Max(r => r.PerformedOn) })
            .ToDictionaryAsync(x => x.PlanId, x => x.Last, ct);
    }

    private static CarePlanResponse ToResponse(CarePlan plan, DateOnly today, IReadOnlyDictionary<Guid, DateOnly> lastDone) => new(
        plan.Id,
        plan.PetId,
        plan.Kind,
        plan.Title,
        plan.IntervalValue,
        plan.IntervalUnit,
        plan.NextDueOn,
        plan.StatusOn(today),
        plan.NextDueOn.DayNumber - today.DayNumber,
        lastDone.TryGetValue(plan.Id, out var last) ? last : null,
        plan.RemindOffsetsDays,
        plan.DefaultProduct,
        plan.Targets,
        plan.PresetCode,
        plan.Notes,
        plan.Active,
        plan.CreatedAt,
        plan.UpdatedAt);

    /// <summary>
    /// <paramref name="currentPresetCode"/> is the plan's preset before an update: an unchanged preset isn't checked
    /// again, so a plan stays editable after the pet's species is corrected.
    /// </summary>
    private static ValidationErrors Validate(CarePlanRequest request, Species species, string? currentPresetCode, TimeProvider clock)
    {
        var errors = new ValidationErrors();
        if (!Enum.IsDefined(request.Kind))
        {
            errors.Add("kind", "Unknown kind of care.");
        }

        var title = Input.Clean(request.Title);
        if (title is null)
        {
            errors.Add("title", "Enter what needs to be done.");
        }

        errors.MaxLength("title", title, 100);

        if (request.IntervalValue is null != request.IntervalUnit is null)
        {
            errors.Add("intervalValue", "Give both the number and the unit, or neither for a one-off plan.");
        }
        else if (request.IntervalUnit is { } unit)
        {
            if (!Enum.IsDefined(unit))
            {
                errors.Add("intervalUnit", "Unknown unit.");
            }
            else if (request.IntervalValue < 1 || request.IntervalValue > Intervals.MaxValue(unit))
            {
                errors.Add("intervalValue", "Use an interval from 1 day up to 10 years.");
            }
        }

        var latestToday = Input.LatestToday(clock);
        if (request.NextDueOn < CareRules.EarliestDate || request.NextDueOn > latestToday.AddYears(10))
        {
            errors.Add("nextDueOn", "Use a date within the next 10 years.");
        }

        var offsets = request.RemindOffsetsDays ?? [];
        if (offsets.Count > 5 || offsets.Any(d => d is < 0 or > 365) || offsets.Distinct().Count() != offsets.Count)
        {
            errors.Add("remindOffsetsDays", "Use up to 5 different numbers of days from 0 to 365.");
        }

        errors.MaxLength("defaultProduct", Input.Clean(request.DefaultProduct), 100);
        errors.MaxLength("notes", Input.Clean(request.Notes), 2000);
        CareRules.ValidateTargets(errors, request.Kind, request.Targets);

        if (request.PresetCode is { } code && code != currentPresetCode)
        {
            var preset = CarePresets.Find(code);
            if (preset is null)
            {
                errors.Add("presetCode", "Unknown preset.");
            }
            else if (preset.DogOnly && species != Species.Dog)
            {
                // Spec 5.1: a dog-only product must never be planned for a cat by accident.
                errors.Add("presetCode", "This product is for dogs only: it contains permethrin, which is toxic to cats.");
            }
            else if (preset.Species is { } presetSpecies && presetSpecies != species)
            {
                errors.Add("presetCode", "This preset is for another species.");
            }
        }

        return errors;
    }

    private static ValidationErrors ValidateCompletion(CompleteCarePlanRequest request, TimeProvider clock)
    {
        var errors = new ValidationErrors();
        CareRules.ValidatePerformedOn(errors, request.PerformedOn, clock);
        errors.MaxLength("product", Input.Clean(request.Product), 100);
        errors.MaxLength("manufacturer", Input.Clean(request.Manufacturer), 100);
        errors.MaxLength("batchNumber", Input.Clean(request.BatchNumber), 50);
        errors.MaxLength("clinic", Input.Clean(request.Clinic), 200);
        errors.MaxLength("veterinarian", Input.Clean(request.Veterinarian), 100);
        errors.MaxLength("notes", Input.Clean(request.Notes), 2000);
        if (request.ValidFrom is { } from && from < request.PerformedOn)
        {
            errors.Add("validFrom", "Protection can't start before the day it was given.");
        }

        if (request.ValidUntil is { } until && (until <= request.PerformedOn || until < request.ValidFrom))
        {
            errors.Add("validUntil", "Protection ends after it starts.");
        }

        if (request.NextDueOn is { } next && next < request.PerformedOn)
        {
            errors.Add("nextDueOn", "The next date can't be before this one.");
        }

        var latestToday = Input.LatestToday(clock);
        if (request.NextDueOn > latestToday.AddYears(10))
        {
            errors.Add("nextDueOn", "Use a date within the next 10 years.");
        }

        CareRules.ValidateValidity(errors, request.ValidFrom, request.ValidUntil, latestToday);

        return errors;
    }
}

/// <summary>
/// A plan as other modules see it, with what decides whether an entry from a scanned passport counts as its "Done".
/// </summary>
public sealed record PlanSummary(
    Guid Id,
    CareKind Kind,
    List<VaccineTarget> Targets,
    int? IntervalValue,
    IntervalUnit? IntervalUnit,
    DateOnly NextDueOn,
    DateOnly CreatedOn,
    DateOnly? LastDoneOn)
{
    public static PlanSummary Of(CarePlan plan, DateOnly? lastDoneOn) => new(
        plan.Id, plan.Kind, [.. plan.Targets], plan.IntervalValue, plan.IntervalUnit, plan.NextDueOn,
        DateOnly.FromDateTime(plan.CreatedAt.UtcDateTime), lastDoneOn);

    /// <summary>
    /// Whether an entry from a scanned passport, done on <paramref name="performedOn"/>, moves the plan on as "Done"
    /// would:
    /// <list type="bullet">
    /// <item>not when the plan was done that day or later already;</item>
    /// <item>yes when it was done after the plan was made: that is news the plan doesn't know;</item>
    /// <item>an entry older than the plan only pushes the date later and never closes a one-off plan: the date the
    /// user chose when making the plan may know better (a treatment given at home isn't in the passport).</item>
    /// </list>
    /// </summary>
    public bool MovedBy(DateOnly performedOn, DateOnly? validUntil)
    {
        if (LastDoneOn is { } last && performedOn <= last)
        {
            return false;
        }

        if (performedOn >= CreatedOn)
        {
            return true;
        }

        return IntervalValue is { } every && IntervalUnit is { } unit
            && (validUntil ?? Intervals.Add(performedOn, every, unit)) > NextDueOn;
    }
}

/// <summary>Plans of the household for other modules (the Today screen, AI imports).</summary>
public sealed class CarePlanDirectory(AppDbContext db)
{
    /// <summary>The pet's active plans, to match scanned entries to them.</summary>
    public async Task<List<PlanSummary>> ActiveForPetAsync(Guid petId, CancellationToken ct)
    {
        var plans = await db.CarePlans.AsNoTracking().Where(p => p.PetId == petId && p.Active).ToListAsync(ct);
        var lastDone = await CarePlansEndpoints.LastDoneAsync(db, plans.Select(p => p.Id), ct);
        return [.. plans.Select(p => PlanSummary.Of(p, lastDone.TryGetValue(p.Id, out var last) ? last : null))];
    }

    /// <summary>Active plans due on or before <paramref name="until"/>, overdue ones included.</summary>
    public Task<List<CarePlan>> DueByAsync(Guid householdId, DateOnly until, CancellationToken ct) =>
        db.CarePlans.AsNoTracking()
            .Where(p => p.HouseholdId == householdId && p.Active && p.NextDueOn <= until)
            .OrderBy(p => p.NextDueOn)
            .ToListAsync(ct);
}
