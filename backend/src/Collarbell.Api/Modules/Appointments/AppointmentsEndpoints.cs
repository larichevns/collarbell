using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Collarbell.Api.Modules.Appointments;

/// <summary>
/// Create or replace a visit. <see cref="Date"/> and <see cref="Time"/> are the household's local date and time.
/// <see cref="Status"/> (update only) can cancel a visit or plan it again; "done" has its own request.
/// <see cref="RequestId"/> (creating only): a new id per visit the app creates, the same on retries.
/// </summary>
public sealed record AppointmentRequest(
    AppointmentType Type,
    string Title,
    DateOnly Date,
    TimeOnly Time,
    int? DurationMinutes,
    string? Location,
    string? Notes,
    List<Guid> PetIds,
    List<int>? RemindOffsetsMinutes,
    AppointmentStatus? Status,
    Guid? RequestId);

/// <summary>A visit; <see cref="Date"/> and <see cref="Time"/> are in the household's time zone.</summary>
public sealed record AppointmentResponse(
    Guid Id,
    AppointmentType Type,
    string Title,
    DateOnly Date,
    TimeOnly Time,
    DateTimeOffset StartsAt,
    int? DurationMinutes,
    string? Location,
    string? Notes,
    List<Guid> PetIds,
    List<int> RemindOffsetsMinutes,
    AppointmentStatus Status,
    List<Guid> RecordIds,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

/// <summary>
/// "The visit took place". With <see cref="RecordKind"/> every pet of the visit gets a care record of that kind (an
/// exam after the vet, grooming after the groomer). <see cref="PlanIds"/>: plans of these pets the visit counts as
/// "Done" for, at most one per pet, of the same kind (e.g. the yearly check-up).
/// </summary>
public sealed record CompleteAppointmentRequest(CareKind? RecordKind, List<Guid>? PlanIds, string? Notes);

public sealed record CompleteAppointmentResponse(AppointmentResponse Appointment, List<Guid> MovedPlanIds);

public static class AppointmentsEndpoints
{
    public const int MaxPets = 10;

    /// <summary>The longest time ahead a visit can be reminded of: two weeks.</summary>
    public const int MaxRemindMinutes = 14 * 24 * 60;

    /// <summary>Kinds of care record a visit can become.</summary>
    public static readonly IReadOnlySet<CareKind> RecordKinds = new HashSet<CareKind>
    {
        CareKind.VetExam, CareKind.Dental, CareKind.Grooming, CareKind.Procedure, CareKind.Other,
    };

    private const int ListLimit = 200;

    public static RouteGroupBuilder MapAppointmentsEndpoints(this RouteGroupBuilder api)
    {
        var appointments = api.MapGroup("/appointments").WithTags("Appointments").ReportsChanges(LiveTopics.Visits);

        appointments.MapGet("", List)
            .WithName("ListAppointments")
            .WithSummary("Visits, optionally of one pet: planned ones first (soonest first), then past and cancelled (newest first).");

        appointments.MapPost("", Create)
            .WithName("CreateAppointment")
            .WithSummary("Add a visit; reminders come a day and two hours before by default.");

        appointments.MapGet("/{id:guid}", Get)
            .WithName("GetAppointment")
            .WithSummary("One visit.");

        appointments.MapPut("/{id:guid}", Update)
            .WithName("UpdateAppointment")
            .WithSummary("Change a visit, cancel it or plan it again.");

        appointments.MapDelete("/{id:guid}", Delete)
            .WithName("DeleteAppointment")
            .WithSummary("Delete a visit. Records made from it stay.");

        // It also writes care records and marks plans "Done".
        appointments.MapPost("/{id:guid}/complete", Complete)
            .AllowHelpers()
            .ReportsChanges(LiveTopics.Visits, LiveTopics.Care)
            .WithName("CompleteAppointment")
            .WithSummary("\"The visit took place\": optionally a care record for each pet and \"Done\" for their plans.");

        return api;
    }

    private static async Task<Ok<List<AppointmentResponse>>> List(
        Guid? petId, CurrentUserAccessor current, AppDbContext db, HouseholdCalendar calendar, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var query = db.Appointments.AsNoTracking().Include(a => a.Pets).Where(a => a.HouseholdId == me.HouseholdId);
        if (petId is { } pet)
        {
            query = query.Where(a => a.Pets.Any(p => p.PetId == pet));
        }

        var planned = await query.Where(a => a.Status == AppointmentStatus.Planned)
            .OrderBy(a => a.StartsAt).Take(ListLimit).ToListAsync(ct);
        var others = await query.Where(a => a.Status != AppointmentStatus.Planned)
            .OrderByDescending(a => a.StartsAt).Take(ListLimit).ToListAsync(ct);
        var zone = await calendar.TimeZoneAsync(me.HouseholdId, ct);
        return TypedResults.Ok(planned.Concat(others).Select(a => ToResponse(a, zone)).ToList());
    }

    private static async Task<Results<Ok<AppointmentResponse>, NotFound>> Get(
        Guid id, CurrentUserAccessor current, AppDbContext db, HouseholdCalendar calendar, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var appointment = await FindAsync(db, me, id, ct);
        return appointment is null
            ? TypedResults.NotFound()
            : TypedResults.Ok(ToResponse(appointment, await calendar.TimeZoneAsync(me.HouseholdId, ct)));
    }

    private static async Task<Results<Created<AppointmentResponse>, ValidationProblem>> Create(
        AppointmentRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        HouseholdCalendar calendar,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var zone = await calendar.TimeZoneAsync(me.HouseholdId, ct);
        var errors = await ValidateAsync(request, me, pets, calendar.Today(zone), ct);
        if (request.Status is { } status && status != AppointmentStatus.Planned)
        {
            errors.Add("status", "A new visit is planned.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        if (request.RequestId is { } requestId
            && await db.Appointments.Include(a => a.Pets)
                    .SingleOrDefaultAsync(a => a.HouseholdId == me.HouseholdId && a.ClientRequestId == requestId, ct)
                is { } earlier)
        {
            // A retry of a create that already went through: answer as the first time.
            return TypedResults.Created($"/api/v1/appointments/{earlier.Id}", ToResponse(earlier, zone));
        }

        var appointment = new Appointment(me.HouseholdId, request.Type, request.Title.Trim(),
            LocalTimes.Moment(request.Date, request.Time, zone), me.UserId, clock.GetUtcNow())
        {
            ClientRequestId = request.RequestId,
        };
        Apply(request, appointment, zone);
        db.Appointments.Add(appointment);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (request.RequestId is not null
            && e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // The same create twice at once: the other one made it.
            db.ChangeTracker.Clear();
            appointment = await db.Appointments.Include(a => a.Pets)
                .SingleAsync(a => a.HouseholdId == me.HouseholdId && a.ClientRequestId == request.RequestId, ct);
        }

        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Created($"/api/v1/appointments/{appointment.Id}", ToResponse(appointment, zone));
    }

    private static async Task<Results<Ok<AppointmentResponse>, NotFound, ValidationProblem>> Update(
        Guid id,
        AppointmentRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        HouseholdCalendar calendar,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var appointment = await FindAsync(db, me, id, ct);
        if (appointment is null)
        {
            return TypedResults.NotFound();
        }

        var zone = await calendar.TimeZoneAsync(me.HouseholdId, ct);
        var errors = await ValidateAsync(request, me, pets, calendar.Today(zone), ct);
        if (request.Status is { } status && status != appointment.Status)
        {
            if (appointment.Status == AppointmentStatus.Done)
            {
                errors.Add("status", "A visit that took place stays done.");
            }
            else if (status == AppointmentStatus.Done)
            {
                errors.Add("status", "Mark a visit done with its own request, so that its records are made.");
            }
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        appointment.Type = request.Type;
        appointment.Title = request.Title.Trim();
        appointment.Status = request.Status ?? appointment.Status;
        Apply(request, appointment, zone);
        appointment.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Ok(ToResponse(appointment, zone));
    }

    private static async Task<Results<NoContent, NotFound>> Delete(
        Guid id, CurrentUserAccessor current, AppDbContext db, ReminderSchedule reminders, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var appointment = await FindAsync(db, me, id, ct);
        if (appointment is null)
        {
            return TypedResults.NotFound();
        }

        db.Appointments.Remove(appointment);
        await db.SaveChangesAsync(ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.NoContent();
    }

    /// <summary>
    /// Marks the visit done, makes the records and moves the chosen plans, all in one save. Done again (a retry, a
    /// second phone) changes nothing and answers with the visit as it is.
    /// </summary>
    private static async Task<Results<Ok<CompleteAppointmentResponse>, NotFound, ValidationProblem>> Complete(
        Guid id,
        CompleteAppointmentRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        HouseholdCalendar calendar,
        CarePlanDirectory plans,
        CareRecordsWriter careRecords,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var appointment = await FindAsync(db, me, id, ct);
        if (appointment is null)
        {
            return TypedResults.NotFound();
        }

        var zone = await calendar.TimeZoneAsync(me.HouseholdId, ct);
        if (appointment.Status == AppointmentStatus.Done)
        {
            return TypedResults.Ok(new CompleteAppointmentResponse(ToResponse(appointment, zone), []));
        }

        var (date, _) = LocalTimes.LocalAt(appointment.StartsAt, zone);
        var errors = new ValidationErrors();
        if (appointment.Status == AppointmentStatus.Cancelled)
        {
            errors.Add("status", "This visit was cancelled; plan it again first.");
        }
        else if (date > calendar.Today(zone))
        {
            errors.Add("status", "The visit hasn't happened yet.");
        }

        var petIds = appointment.Pets.Select(p => p.PetId).ToList();
        var records = new List<(Guid PetId, CareRecordRequest Request, Guid? PlanId)>();
        if (request.RecordKind is { } kind)
        {
            if (!RecordKinds.Contains(kind))
            {
                errors.Add("recordKind", "Use an exam, dental care, grooming, a procedure or other care.");
            }

            var linked = await LinkPlansAsync(request.PlanIds ?? [], kind, petIds, plans, errors, ct);
            foreach (var petId in petIds)
            {
                var record = new CareRecordRequest(kind, appointment.Title, date, PerformedTime: null, Product: null,
                    Manufacturer: null, BatchNumber: null, ValidFrom: null, ValidUntil: null, Targets: null,
                    Clinic: kind == CareKind.VetExam ? appointment.Location : null, Veterinarian: null, WeightKg: null,
                    Details: null, Notes: Input.Clean(request.Notes) ?? appointment.Notes, RequestId: null);
                careRecords.Validate(record, "records.", errors);
                records.Add((petId, record, linked.TryGetValue(petId, out var planId) ? planId : null));
            }
        }
        else if (request.PlanIds is { Count: > 0 })
        {
            errors.Add("planIds", "Choose the kind of record to mark plans done with.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var added = records
            .Select(r => careRecords.Add(me.HouseholdId, r.PetId, me.UserId, r.Request, RecordSource.Manual, r.PlanId))
            .ToList();
        // The plans the user chose count the visit as "Done", like the plan's own "Done" button.
        var moved = await careRecords.MovePlansAsync(added, ct, chosenByUser: true);
        var now = clock.GetUtcNow();
        appointment.Status = AppointmentStatus.Done;
        appointment.RecordIds = [.. added.Select(r => r.Id)];
        appointment.CompletedAt = now;
        appointment.UpdatedAt = now;
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Someone marked it done (or cancelled it) a moment earlier: nothing of this request is saved.
            db.ChangeTracker.Clear();
            var latest = await FindAsync(db, me, id, ct);
            if (latest is null)
            {
                return TypedResults.NotFound();
            }

            return latest.Status == AppointmentStatus.Done
                ? TypedResults.Ok(new CompleteAppointmentResponse(ToResponse(latest, zone), []))
                : TypedResults.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["status"] = ["This visit was cancelled meanwhile."],
                });
        }

        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Ok(new CompleteAppointmentResponse(ToResponse(appointment, zone), moved));
    }

    /// <summary>The plans to count the visit as "Done" for, by pet: active plans of the visit's pets, of the record's kind.</summary>
    private static async Task<Dictionary<Guid, Guid>> LinkPlansAsync(
        List<Guid> planIds, CareKind kind, List<Guid> petIds, CarePlanDirectory plans, ValidationErrors errors, CancellationToken ct)
    {
        var linked = new Dictionary<Guid, Guid>();
        if (planIds.Count == 0)
        {
            return linked;
        }

        var petOfPlan = new Dictionary<Guid, Guid>();
        foreach (var petId in petIds)
        {
            foreach (var plan in await plans.ActiveForPetAsync(petId, ct))
            {
                if (plan.Kind == kind)
                {
                    petOfPlan[plan.Id] = petId;
                }
            }
        }

        foreach (var planId in planIds.Distinct())
        {
            if (!petOfPlan.TryGetValue(planId, out var petId))
            {
                errors.Add("planIds", "Choose active plans of this visit's pets, of the same kind as the record.");
            }
            else if (!linked.TryAdd(petId, planId))
            {
                errors.Add("planIds", "Choose at most one plan per pet.");
            }
        }

        return linked;
    }

    /// <summary>Only visits of the caller's household are found; someone else's is "not found".</summary>
    private static Task<Appointment?> FindAsync(AppDbContext db, CurrentUser me, Guid id, CancellationToken ct) =>
        db.Appointments.Include(a => a.Pets).SingleOrDefaultAsync(a => a.Id == id && a.HouseholdId == me.HouseholdId, ct);

    /// <summary>Fields that create and update set the same way.</summary>
    private static void Apply(AppointmentRequest request, Appointment appointment, string zone)
    {
        appointment.StartsAt = LocalTimes.Moment(request.Date, request.Time, zone);
        appointment.DurationMinutes = request.DurationMinutes;
        appointment.Location = Input.Clean(request.Location);
        appointment.Notes = Input.Clean(request.Notes);
        appointment.RemindOffsetsMinutes = [.. (request.RemindOffsetsMinutes ?? [1440, 120]).Distinct().OrderDescending()];

        var petIds = request.PetIds.Distinct().ToList();
        appointment.Pets.RemoveAll(p => !petIds.Contains(p.PetId));
        foreach (var petId in petIds.Where(petId => appointment.Pets.TrueForAll(p => p.PetId != petId)))
        {
            appointment.Pets.Add(new AppointmentPet(petId));
        }
    }

    private static async Task<ValidationErrors> ValidateAsync(
        AppointmentRequest request, CurrentUser me, PetDirectory pets, DateOnly today, CancellationToken ct)
    {
        var errors = new ValidationErrors();
        if (!Enum.IsDefined(request.Type))
        {
            errors.Add("type", "Unknown kind of visit.");
        }

        var title = Input.Clean(request.Title);
        if (title is null)
        {
            errors.Add("title", "Enter what the visit is for.");
        }

        errors.MaxLength("title", title, 100);

        if (request.Date < today.AddYears(-1) || request.Date > today.AddYears(5))
        {
            errors.Add("date", "Use a date from a year ago up to five years ahead.");
        }

        if (request.Time.Ticks % TimeSpan.TicksPerMinute != 0)
        {
            errors.Add("time", "Use whole minutes, e.g. 10:30.");
        }

        if (request.DurationMinutes is { } duration && duration is < 1 or > 1440)
        {
            errors.Add("durationMinutes", "Use 1 minute to 24 hours.");
        }

        errors.MaxLength("location", Input.Clean(request.Location), 200);
        errors.MaxLength("notes", Input.Clean(request.Notes), 2000);

        var petIds = request.PetIds ?? [];
        if (petIds.Count is 0 or > MaxPets || petIds.Distinct().Count() != petIds.Count)
        {
            errors.Add("petIds", $"Choose 1 to {MaxPets} pets.");
        }
        else
        {
            var known = (await pets.CardsAsync(me.HouseholdId, ct)).Select(p => p.Id).ToHashSet();
            if (!petIds.All(known.Contains))
            {
                errors.Add("petIds", "Choose your own pets.");
            }
        }

        var offsets = request.RemindOffsetsMinutes ?? [];
        if (offsets.Count > 5 || offsets.Any(m => m is < 0 or > MaxRemindMinutes) || offsets.Distinct().Count() != offsets.Count)
        {
            errors.Add("remindOffsetsMinutes", "Use up to 5 different reminders, from 0 minutes to 2 weeks before.");
        }

        if (request.Status is { } status && !Enum.IsDefined(status))
        {
            errors.Add("status", "Unknown status.");
        }

        return errors;
    }

    internal static AppointmentResponse ToResponse(Appointment appointment, string zone)
    {
        var (date, time) = LocalTimes.LocalAt(appointment.StartsAt, zone);
        return new AppointmentResponse(
            appointment.Id,
            appointment.Type,
            appointment.Title,
            date,
            time,
            appointment.StartsAt,
            appointment.DurationMinutes,
            appointment.Location,
            appointment.Notes,
            [.. appointment.Pets.Select(p => p.PetId)],
            appointment.RemindOffsetsMinutes,
            appointment.Status,
            appointment.RecordIds,
            appointment.CreatedAt,
            appointment.UpdatedAt);
    }
}

/// <summary>The household's vet visits and other appointments, for "Download my data".</summary>
public sealed class AppointmentsExport(AppDbContext db) : IHouseholdExportSource
{
    public async Task ExportAsync(HouseholdExport export, CancellationToken ct) =>
        export.Add("visits", await db.Appointments.AsNoTracking()
            .Include(a => a.Pets)
            .Where(a => a.HouseholdId == export.HouseholdId)
            .OrderBy(a => a.StartsAt)
            .ToListAsync(ct));
}
