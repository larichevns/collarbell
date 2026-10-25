using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Supplies;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Collarbell.Api.Modules.Routines;

/// <summary>
/// Create or replace a feeding schedule. <see cref="Times"/> are the household's local times. Without
/// <see cref="Days"/> it is every day. On update a missing <see cref="Active"/> keeps its value. <see cref="RequestId"/>
/// (creating only): a new id per schedule the app creates, the same on retries. <see cref="SupplyItemId"/> links a food
/// in supplies: the portion then counts towards its daily use and must be in its unit, and <see cref="Food"/> becomes
/// its name.
/// </summary>
public sealed record RoutineRequest(
    RoutineKind? Kind,
    List<TimeOnly> Times,
    List<DayOfWeek>? Days,
    string? Food,
    decimal? Amount,
    PortionUnit? Unit,
    string? Notes,
    bool? Active,
    Guid? RequestId,
    Guid? SupplyItemId = null);

public sealed record RoutineResponse(
    Guid Id,
    Guid PetId,
    RoutineKind Kind,
    List<TimeOnly> Times,
    List<DayOfWeek> Days,
    string? Food,
    decimal? Amount,
    PortionUnit? Unit,
    string? Notes,
    bool Active,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    Guid? SupplyItemId);

/// <summary>Mark one occurrence: <see cref="Date"/> and <see cref="Time"/> name it, as the schedule says them.</summary>
public sealed record CompleteRoutineRequest(DateOnly Date, TimeOnly Time, CompletionStatus? Status);

/// <summary>A marked occurrence. <see cref="ByName"/> is how the person who marked it is called; <see cref="ByMe"/> is true for the caller.</summary>
public sealed record RoutineCompletionResponse(
    Guid Id,
    Guid RoutineId,
    DateOnly Date,
    TimeOnly Time,
    CompletionStatus Status,
    DateTimeOffset DoneAt,
    string? ByName,
    bool ByMe);

public static class RoutinesEndpoints
{
    /// <summary>How many days back a feeding can still be marked.</summary>
    public const int MarkDaysBack = 7;

    public static RouteGroupBuilder MapRoutinesEndpoints(this RouteGroupBuilder api)
    {
        var petRoutines = api.MapGroup("/pets/{petId:guid}/routines").WithTags("Feeding").ReportsChanges(LiveTopics.Feeding);

        petRoutines.MapGet("", ListForPet)
            .WithName("ListPetRoutines")
            .WithSummary("The pet's feeding schedules, active ones first.");

        // A schedule gives the food's daily use, so the supplies' estimates change with it; a mark doesn't.
        petRoutines.MapPost("", Create)
            .ReportsChanges(LiveTopics.Feeding, LiveTopics.Supplies)
            .WithName("CreateRoutine")
            .WithSummary("Add a feeding schedule: times of day, days of the week, food and portion.");

        var routines = api.MapGroup("/routines").WithTags("Feeding").ReportsChanges(LiveTopics.Feeding);

        routines.MapGet("/{id:guid}", Get)
            .WithName("GetRoutine")
            .WithSummary("One feeding schedule.");

        routines.MapPut("/{id:guid}", Update)
            .ReportsChanges(LiveTopics.Feeding, LiveTopics.Supplies)
            .WithName("UpdateRoutine")
            .WithSummary("Change a feeding schedule; its reminders follow.");

        routines.MapDelete("/{id:guid}", Delete)
            .ReportsChanges(LiveTopics.Feeding, LiveTopics.Supplies)
            .WithName("DeleteRoutine")
            .WithSummary("Delete a feeding schedule and its marks.");

        routines.MapPost("/{id:guid}/completions", Complete)
            .AllowHelpers()
            .WithName("CompleteRoutine")
            .WithSummary("\"Fed\" (or \"skipped\") for one feeding. 409 with who did it when someone else marked it first.");

        routines.MapDelete("/{id:guid}/completions/{completionId:guid}", Undo)
            .AllowHelpers()
            .WithName("UndoRoutineCompletion")
            .WithSummary("Take a mark back, e.g. the wrong pet was tapped.");

        return api;
    }

    private static async Task<Results<Ok<List<RoutineResponse>>, NotFound>> ListForPet(
        Guid petId, CurrentUserAccessor current, AppDbContext db, PetDirectory pets, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        var routines = await db.Routines.AsNoTracking()
            .Where(r => r.HouseholdId == me.HouseholdId && r.PetId == petId)
            .ToListAsync(ct);
        return TypedResults.Ok(routines
            .OrderBy(r => !r.Active)
            .ThenBy(r => r.Times.Min())
            .ThenBy(r => r.CreatedAt)
            .Select(ToResponse)
            .ToList());
    }

    private static async Task<Results<Ok<RoutineResponse>, NotFound>> Get(
        Guid id, CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var routine = await FindAsync(db, me, id, ct);
        return routine is null ? TypedResults.NotFound() : TypedResults.Ok(ToResponse(routine));
    }

    private static async Task<Results<Created<RoutineResponse>, NotFound, ValidationProblem>> Create(
        Guid petId,
        RoutineRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        SupplyDirectory supplies,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request);
        var supply = await LinkAsync(request, me, supplies, errors, ct);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        if (request.RequestId is { } requestId
            && await db.Routines.SingleOrDefaultAsync(r => r.HouseholdId == me.HouseholdId && r.ClientRequestId == requestId, ct)
                is { } earlier)
        {
            // A retry of a create that already went through: answer as the first time.
            return TypedResults.Created($"/api/v1/routines/{earlier.Id}", ToResponse(earlier));
        }

        var routine = new Routine(me.HouseholdId, petId, request.Kind ?? RoutineKind.Feeding, clock.GetUtcNow())
        {
            ClientRequestId = request.RequestId,
            Active = request.Active ?? true,
        };
        Apply(request, routine, supply);
        db.Routines.Add(routine);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (request.RequestId is not null
            && e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // The same create twice at once: the other one made it.
            db.ChangeTracker.Clear();
            routine = await db.Routines.SingleAsync(r => r.HouseholdId == me.HouseholdId && r.ClientRequestId == request.RequestId, ct);
        }

        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Created($"/api/v1/routines/{routine.Id}", ToResponse(routine));
    }

    private static async Task<Results<Ok<RoutineResponse>, NotFound, ValidationProblem>> Update(
        Guid id,
        RoutineRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        SupplyDirectory supplies,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var routine = await FindAsync(db, me, id, ct);
        if (routine is null)
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request);
        var supply = await LinkAsync(request, me, supplies, errors, ct);
        if (request.Kind is { } kind && kind != routine.Kind)
        {
            errors.Add("kind", "A schedule keeps its kind.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        Apply(request, routine, supply);
        routine.Active = request.Active ?? routine.Active;
        routine.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Ok(ToResponse(routine));
    }

    private static async Task<Results<NoContent, NotFound>> Delete(
        Guid id, CurrentUserAccessor current, AppDbContext db, ReminderSchedule reminders, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var routine = await FindAsync(db, me, id, ct);
        if (routine is null)
        {
            return TypedResults.NotFound();
        }

        db.Routines.Remove(routine);
        await db.SaveChangesAsync(ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.NoContent();
    }

    /// <summary>
    /// Marks an occurrence. Marking what the same person already marked is fine (a double tap, a retry after a lost
    /// answer): they get the first mark back. Someone else's mark is a 409 with who and when, so the app can say
    /// "Anna fed her at 08:02". The reminder of that feeding checks the marks before it goes out.
    /// </summary>
    private static async Task<Results<Created<RoutineCompletionResponse>, Ok<RoutineCompletionResponse>, Conflict<RoutineCompletionResponse>, NotFound, ValidationProblem>> Complete(
        Guid id,
        CompleteRoutineRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        HouseholdCalendar calendar,
        FeedingMarkPush markPush,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var routine = await FindAsync(db, me, id, ct);
        if (routine is null)
        {
            return TypedResults.NotFound();
        }

        var today = await calendar.TodayAsync(me.HouseholdId, ct);
        var errors = new ValidationErrors();
        if (request.Date > today || request.Date < today.AddDays(-MarkDaysBack))
        {
            errors.Add("date", $"Mark feedings of today or the last {MarkDaysBack} days.");
        }
        else if (!routine.OccursAt(request.Date, request.Time))
        {
            errors.Add("time", "There is no feeding at this time on this day.");
        }

        if (request.Status is { } status && !Enum.IsDefined(status))
        {
            errors.Add("status", "Unknown status.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var mark = new RoutineCompletion(me.HouseholdId, routine.Id, request.Date, request.Time,
            request.Status ?? CompletionStatus.Done, me.UserId, clock.GetUtcNow());
        db.RoutineCompletions.Add(mark);
        try
        {
            await db.SaveChangesAsync(ct);
            var created = await ToResponseAsync(db, mark, me, ct);

            // The others' phones: the reminder of this feeding turns into who fed whom.
            if (routine.Kind == RoutineKind.Feeding)
            {
                await markPush.SendAsync(me.HouseholdId, request.Date, request.Time, me.UserId, ct);
            }

            return TypedResults.Created($"/api/v1/routines/{routine.Id}/completions/{mark.Id}", created);
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // Marked already, maybe a moment ago from another phone.
            db.ChangeTracker.Clear();
            var first = await db.RoutineCompletions.AsNoTracking()
                .SingleAsync(c => c.RoutineId == routine.Id && c.Date == request.Date && c.Time == request.Time, ct);
            var response = await ToResponseAsync(db, first, me, ct);
            return first.DoneBy == me.UserId ? TypedResults.Ok(response) : TypedResults.Conflict(response);
        }
    }

    /// <summary>A helper takes back only their own marks: who fed the cat stays as it was.</summary>
    private static async Task<Results<NoContent, NotFound, ProblemHttpResult>> Undo(
        Guid id, Guid completionId, CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var marks = db.RoutineCompletions
            .Where(c => c.Id == completionId && c.RoutineId == id && c.HouseholdId == me.HouseholdId);
        if (me.Role == HouseholdRole.Helper && await marks.AnyAsync(c => c.DoneBy != me.UserId, ct))
        {
            return (ProblemHttpResult)HouseholdProblems.RoleCantDoThis();
        }

        var deleted = await marks.ExecuteDeleteAsync(ct);
        return deleted > 0 ? TypedResults.NoContent() : TypedResults.NotFound();
    }

    /// <summary>Only routines of the caller's household are found; someone else's is "not found".</summary>
    private static Task<Routine?> FindAsync(AppDbContext db, CurrentUser me, Guid id, CancellationToken ct) =>
        db.Routines.SingleOrDefaultAsync(r => r.Id == id && r.HouseholdId == me.HouseholdId, ct);

    private static void Apply(RoutineRequest request, Routine routine, SupplyLink? supply)
    {
        routine.Times = [.. request.Times.Distinct().Order()];
        routine.Days = request.Days is { Count: > 0 } days ? [.. days.Distinct().Order()] : [.. Enum.GetValues<DayOfWeek>()];
        routine.SupplyItemId = supply?.Id;
        routine.Food = supply?.Name ?? Input.Clean(request.Food);
        routine.Amount = request.Amount;
        routine.Unit = request.Amount is null ? null : request.Unit;
        routine.Notes = Input.Clean(request.Notes);
    }

    /// <summary>
    /// The supply item the feeding gives, when the request links one: it must be the household's, and the portion must
    /// be in its unit, or it couldn't count towards the item's daily use.
    /// </summary>
    private static async Task<SupplyLink?> LinkAsync(
        RoutineRequest request, CurrentUser me, SupplyDirectory supplies, ValidationErrors errors, CancellationToken ct)
    {
        if (request.SupplyItemId is not { } supplyId)
        {
            return null;
        }

        var supply = await supplies.FindAsync(me.HouseholdId, supplyId, ct);
        if (supply is null)
        {
            errors.Add("supplyItemId", "There is no such item in supplies.");
        }
        else if (request.Unit is { } unit && Enum.IsDefined(unit) && request.Amount is not null && !SupplyForecasts.SameUnit(unit, supply.Unit))
        {
            errors.Add("unit", $"This food is counted in {supply.Unit.ToString().ToLowerInvariant()}s: give the portion in them.");
        }

        return supply;
    }

    private static ValidationErrors Validate(RoutineRequest request)
    {
        var errors = new ValidationErrors();
        if (request.Kind is { } kind && !Enum.IsDefined(kind))
        {
            errors.Add("kind", "Unknown kind of routine.");
        }

        var times = request.Times ?? [];
        if (times.Count is 0 or > Routine.MaxTimes || times.Distinct().Count() != times.Count)
        {
            errors.Add("times", $"Use 1 to {Routine.MaxTimes} different times of day.");
        }
        else if (times.Any(t => t.Ticks % TimeSpan.TicksPerMinute != 0))
        {
            errors.Add("times", "Use whole minutes, e.g. 08:00.");
        }

        if (request.Days is { } days && (days.Any(d => !Enum.IsDefined(d)) || days.Distinct().Count() != days.Count))
        {
            errors.Add("days", "Use each day of the week once.");
        }

        errors.MaxLength("food", Input.Clean(request.Food), 100);
        if (request.Amount is { } amount)
        {
            if (amount <= 0 || amount > 10_000 || decimal.Round(amount, 2) != amount)
            {
                errors.Add("amount", "Use an amount above 0 and up to 10 000, with at most 2 decimals.");
            }

            if (request.Unit is not { } unit || !Enum.IsDefined(unit))
            {
                errors.Add("unit", "Say whether the amount is in grams, millilitres or pieces.");
            }
        }

        errors.MaxLength("notes", Input.Clean(request.Notes), 500);
        return errors;
    }

    private static RoutineResponse ToResponse(Routine routine) => new(
        routine.Id,
        routine.PetId,
        routine.Kind,
        routine.Times,
        routine.Days,
        routine.Food,
        routine.Amount,
        routine.Unit,
        routine.Notes,
        routine.Active,
        routine.CreatedAt,
        routine.UpdatedAt,
        routine.SupplyItemId);

    private static async Task<RoutineCompletionResponse> ToResponseAsync(
        AppDbContext db, RoutineCompletion mark, CurrentUser me, CancellationToken ct)
    {
        var names = await FeedingDirectory.NamesAsync(db, mark.DoneBy is { } by ? [by] : [], ct);
        return ToResponse(mark, names, me.UserId);
    }

    internal static RoutineCompletionResponse ToResponse(RoutineCompletion mark, IReadOnlyDictionary<Guid, string?> names, Guid me) => new(
        mark.Id,
        mark.RoutineId,
        mark.Date,
        mark.Time,
        mark.Status,
        mark.DoneAt,
        mark.DoneBy is { } by ? names.GetValueOrDefault(by) : null,
        mark.DoneBy == me);
}

/// <summary>The household's feeding schedules and every mark on them, for "Download my data".</summary>
public sealed class RoutinesExport(AppDbContext db) : IHouseholdExportSource
{
    public async Task ExportAsync(HouseholdExport export, CancellationToken ct)
    {
        export.Add("routines", await db.Routines.AsNoTracking()
            .Where(r => r.HouseholdId == export.HouseholdId)
            .OrderBy(r => r.CreatedAt)
            .ToListAsync(ct));
        export.Add("routineMarks", await db.RoutineCompletions.AsNoTracking()
            .Where(c => c.HouseholdId == export.HouseholdId)
            .OrderBy(c => c.Date)
            .ThenBy(c => c.Time)
            .ToListAsync(ct));
    }
}
