using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Care;

public sealed record CareRecordDetailsDto(string? Laboratory, string? ReportNumber, decimal? TiterIuPerMl, bool? FitForTravel);

/// <summary>
/// A record typed in by hand, e.g. history from the paper passport. Photos are added afterwards with
/// <c>POST /care-records/{id}/files</c>. Records typed in don't move plans: "Done" on a plan does (and so does a
/// scanned entry the user links to a plan, see <see cref="CareRecordsWriter.MovePlansAsync"/>).
/// <see cref="RequestId"/> (creating only): a new id per record the app creates, the same on retries,
/// so a retry after a lost response doesn't add the record twice.
/// </summary>
public sealed record CareRecordRequest(
    CareKind Kind,
    string Title,
    DateOnly PerformedOn,
    TimeOnly? PerformedTime,
    string? Product,
    string? Manufacturer,
    string? BatchNumber,
    DateOnly? ValidFrom,
    DateOnly? ValidUntil,
    List<VaccineTarget>? Targets,
    string? Clinic,
    string? Veterinarian,
    decimal? WeightKg,
    CareRecordDetailsDto? Details,
    string? Notes,
    Guid? RequestId);

public sealed record CareRecordResponse(
    Guid Id,
    Guid PetId,
    Guid? PlanId,
    CareKind Kind,
    string Title,
    DateOnly PerformedOn,
    TimeOnly? PerformedTime,
    string? Product,
    string? Manufacturer,
    string? BatchNumber,
    DateOnly? ValidFrom,
    DateOnly? ValidUntil,
    List<VaccineTarget> Targets,
    string? Clinic,
    string? Veterinarian,
    decimal? WeightKg,
    CareRecordDetailsDto? Details,
    string? Notes,
    RecordSource Source,
    List<FileLink> Files,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

/// <summary>Uploaded files to attach to a record, in this order.</summary>
public sealed record AddRecordFilesRequest(List<Guid> FileIds);

/// <summary>
/// The health sections of the EU pet passport (Implementing Regulation 2026/705, same as 577/2013), oldest
/// first like in the paper passport. Dental, grooming and similar records aren't part of the passport.
/// </summary>
public sealed record PassportRecordsResponse(
    List<CareRecordResponse> Rabies,
    List<CareRecordResponse> RabiesTiters,
    List<CareRecordResponse> Echinococcus,
    List<CareRecordResponse> Treatments,
    List<CareRecordResponse> OtherVaccinations,
    List<CareRecordResponse> Examinations);

public static class CareRecordsEndpoints
{
    private const int MaxFiles = 10;

    public static RouteGroupBuilder MapCareRecordsEndpoints(this RouteGroupBuilder api)
    {
        var petRecords = api.MapGroup("/pets/{petId:guid}/care-records").WithTags("Care").ReportsChanges(LiveTopics.Care);

        petRecords.MapGet("", ListForPet)
            .WithName("ListPetCareRecords")
            .WithSummary("The pet's care history, newest first; optionally one kind only.");

        petRecords.MapPost("", Create)
            .WithName("CreateCareRecord")
            .WithSummary("Add a record by hand, for example from the paper passport.");

        api.MapGet("/pets/{petId:guid}/passport/records", PassportRecords)
            .WithTags("Passport")
            .WithName("GetPetPassportRecords")
            .WithSummary("The health sections of the digital passport copy (V–X), built from the care records.");

        var records = api.MapGroup("/care-records").WithTags("Care").ReportsChanges(LiveTopics.Care);

        records.MapGet("/{id:guid}", Get)
            .WithName("GetCareRecord")
            .WithSummary("One record.");

        records.MapPut("/{id:guid}", Update)
            .WithName("UpdateCareRecord")
            .WithSummary("Change a record. Its photos stay as they are.");

        records.MapDelete("/{id:guid}", Delete)
            .WithName("DeleteCareRecord")
            .WithSummary("Delete a record and its photos. A plan it completed keeps its date.");

        records.MapPost("/{id:guid}/files", AddFiles)
            .WithName("AddCareRecordFiles")
            .WithSummary("Attach uploaded files (the vaccine sticker, the vet's conclusion).");

        records.MapDelete("/{id:guid}/files/{fileId:guid}", RemoveFile)
            .WithName("RemoveCareRecordFile")
            .WithSummary("Delete one attached file.");

        return api;
    }

    private static async Task<Results<Ok<List<CareRecordResponse>>, NotFound>> ListForPet(
        Guid petId,
        CareKind? kind,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        Files files,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        var query = db.CareRecords.AsNoTracking()
            .Include(r => r.Files)
            .Where(r => r.HouseholdId == me.HouseholdId && r.PetId == petId);
        if (kind is not null)
        {
            query = query.Where(r => r.Kind == kind);
        }

        var found = await query
            .OrderByDescending(r => r.PerformedOn)
            .ThenByDescending(r => r.PerformedTime)
            .ThenByDescending(r => r.CreatedAt)
            .ToListAsync(ct);
        return TypedResults.Ok(await ToResponsesAsync(found, files, ct));
    }

    private static async Task<Results<Ok<PassportRecordsResponse>, NotFound>> PassportRecords(
        Guid petId, CurrentUserAccessor current, AppDbContext db, PetDirectory pets, Files files, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        var records = await db.CareRecords.AsNoTracking()
            .Include(r => r.Files)
            .Where(r => r.HouseholdId == me.HouseholdId && r.PetId == petId)
            .OrderBy(r => r.PerformedOn)
            .ThenBy(r => r.PerformedTime)
            .ToListAsync(ct);
        var all = (await ToResponsesAsync(records, files, ct)).ToDictionary(r => r.Id);
        List<CareRecordResponse> Section(Func<CareRecord, bool> belongs) =>
            records.Where(belongs).Select(r => all[r.Id]).ToList();

        return TypedResults.Ok(new PassportRecordsResponse(
            Rabies: Section(PassportSections.IsRabies),
            RabiesTiters: Section(r => r.Kind == CareKind.RabiesTiter),
            Echinococcus: Section(r => r.Kind == CareKind.Echinococcus),
            Treatments: Section(r => r.Kind is CareKind.Deworming or CareKind.FleaTick or CareKind.Heartworm),
            OtherVaccinations: Section(r => r.Kind == CareKind.Vaccination && !PassportSections.IsRabies(r)),
            Examinations: Section(r => r.Kind == CareKind.VetExam)));
    }

    private static async Task<Results<Ok<CareRecordResponse>, NotFound>> Get(
        Guid id, CurrentUserAccessor current, AppDbContext db, Files files, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var record = await FindAsync(db, me, id, ct);
        return record is null ? TypedResults.NotFound() : TypedResults.Ok(await ToResponseAsync(record, files, ct));
    }

    private static async Task<Results<Created<CareRecordResponse>, NotFound, ValidationProblem>> Create(
        Guid petId,
        CareRecordRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        Files files,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        if (request.RequestId is { } requestId
            && await db.CareRecords.Include(r => r.Files)
                .SingleOrDefaultAsync(r => r.HouseholdId == me.HouseholdId && r.ClientRequestId == requestId, ct) is { } earlier)
        {
            // A retry of a create that already went through: answer as the first time.
            return TypedResults.Created($"/api/v1/care-records/{earlier.Id}", await ToResponseAsync(earlier, files, ct));
        }

        var record = new CareRecord(
            me.HouseholdId, petId, request.Kind, request.Title.Trim(), request.PerformedOn, me.UserId, clock.GetUtcNow())
        {
            ClientRequestId = request.RequestId,
        };
        Apply(request, record);
        db.CareRecords.Add(record);
        await db.SaveChangesAsync(ct);
        return TypedResults.Created($"/api/v1/care-records/{record.Id}", await ToResponseAsync(record, files, ct));
    }

    private static async Task<Results<Ok<CareRecordResponse>, NotFound, ValidationProblem>> Update(
        Guid id,
        CareRecordRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        Files files,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var record = await FindAsync(db, me, id, ct);
        if (record is null)
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        record.Kind = request.Kind;
        record.Title = request.Title.Trim();
        record.PerformedOn = request.PerformedOn;
        Apply(request, record);
        record.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return TypedResults.Ok(await ToResponseAsync(record, files, ct));
    }

    private static async Task<Results<NoContent, NotFound>> Delete(
        Guid id, CurrentUserAccessor current, AppDbContext db, Files files, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var record = await FindAsync(db, me, id, ct);
        if (record is null)
        {
            return TypedResults.NotFound();
        }

        await files.RemoveAsync(record.Files.Select(f => f.FileId).ToList(), ct);
        db.CareRecords.Remove(record);
        await db.SaveChangesAsync(ct);
        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<CareRecordResponse>, NotFound, ValidationProblem>> AddFiles(
        Guid id,
        AddRecordFilesRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        Files files,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var record = await FindAsync(db, me, id, ct);
        if (record is null)
        {
            return TypedResults.NotFound();
        }

        if (request.FileIds is null || request.FileIds.Count == 0)
        {
            return FileIdsProblem("Attach at least one file.");
        }

        // Files already on this record are skipped, so a retry after a lost response just succeeds.
        var newIds = request.FileIds.Distinct().Where(id => record.Files.TrueForAll(f => f.FileId != id)).ToList();
        if (record.Files.Count + newIds.Count > MaxFiles)
        {
            return FileIdsProblem($"A record has {MaxFiles} files or fewer.");
        }

        if (newIds.Count > 0 && await files.AttachAsync(me.HouseholdId, newIds, photosOnly: false, ct) is { } error)
        {
            return FileIdsProblem(error);
        }

        var last = record.Files.Count == 0 ? 0 : record.Files.Max(f => f.Position);
        for (var i = 0; i < newIds.Count; i++)
        {
            record.Files.Add(new CareRecordFile(newIds[i], position: last + i + 1));
        }

        record.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return TypedResults.Ok(await ToResponseAsync(record, files, ct));
    }

    private static async Task<Results<NoContent, NotFound>> RemoveFile(
        Guid id, Guid fileId, CurrentUserAccessor current, AppDbContext db, Files files, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var record = await FindAsync(db, me, id, ct);
        var attached = record?.Files.Find(f => f.FileId == fileId);
        if (record is null || attached is null)
        {
            return TypedResults.NotFound();
        }

        record.Files.Remove(attached);
        await files.RemoveAsync([fileId], ct);
        record.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return TypedResults.NoContent();
    }

    /// <summary>Only records of the caller's household are found; someone else's is "not found".</summary>
    private static Task<CareRecord?> FindAsync(AppDbContext db, CurrentUser me, Guid id, CancellationToken ct) =>
        db.CareRecords
            .Include(r => r.Files)
            .SingleOrDefaultAsync(r => r.Id == id && r.HouseholdId == me.HouseholdId, ct);

    /// <summary>Fields that create and update set the same way.</summary>
    internal static void Apply(CareRecordRequest request, CareRecord record)
    {
        record.PerformedTime = request.PerformedTime;
        record.Product = Input.Clean(request.Product);
        record.Manufacturer = Input.Clean(request.Manufacturer);
        record.BatchNumber = Input.Clean(request.BatchNumber);
        record.ValidFrom = request.ValidFrom;
        record.ValidUntil = request.ValidUntil;
        record.Targets = request.Kind == CareKind.Vaccination ? [.. request.Targets ?? []] : [];
        record.Clinic = Input.Clean(request.Clinic);
        record.Veterinarian = Input.Clean(request.Veterinarian);
        // A weight is noted at a check-up, and the app sends one only for a check-up: on another kind it would sit in the
        // pet's weight log where nobody could change it. Kept to 10 g, as the column keeps it.
        record.WeightKg = request.Kind == CareKind.VetExam && request.WeightKg is { } kg ? RoundedWeight(kg) : null;
        record.Details = ToDetails(request.Details);
        record.Notes = Input.Clean(request.Notes);
    }

    private static CareRecordDetails? ToDetails(CareRecordDetailsDto? dto)
    {
        var details = new CareRecordDetails
        {
            Laboratory = Input.Clean(dto?.Laboratory),
            ReportNumber = Input.Clean(dto?.ReportNumber),
            TiterIuPerMl = dto?.TiterIuPerMl,
            FitForTravel = dto?.FitForTravel,
        };
        return details is { Laboratory: null, ReportNumber: null, TiterIuPerMl: null, FitForTravel: null } ? null : details;
    }

    internal static ValidationErrors Validate(CareRecordRequest request, TimeProvider clock) =>
        Validate(request, Input.LatestToday(clock));

    /// <summary>The checks for a record; <paramref name="latestToday"/> is the latest "today" anywhere on Earth.</summary>
    internal static ValidationErrors Validate(CareRecordRequest request, DateOnly latestToday)
    {
        var errors = new ValidationErrors();
        if (!Enum.IsDefined(request.Kind))
        {
            errors.Add("kind", "Unknown kind of care.");
        }

        var title = Input.Clean(request.Title);
        if (title is null)
        {
            errors.Add("title", "Enter what was done.");
        }

        errors.MaxLength("title", title, 100);
        CareRules.ValidatePerformedOn(errors, request.PerformedOn, latestToday);
        errors.MaxLength("product", Input.Clean(request.Product), 100);
        errors.MaxLength("manufacturer", Input.Clean(request.Manufacturer), 100);
        errors.MaxLength("batchNumber", Input.Clean(request.BatchNumber), 50);
        errors.MaxLength("clinic", Input.Clean(request.Clinic), 200);
        errors.MaxLength("veterinarian", Input.Clean(request.Veterinarian), 100);
        errors.MaxLength("notes", Input.Clean(request.Notes), 2000);
        CareRules.ValidateTargets(errors, request.Kind, request.Targets);

        if (request.ValidFrom is { } from && from < request.PerformedOn)
        {
            errors.Add("validFrom", "Protection can't start before the day it was given.");
        }

        if (request.ValidUntil is { } until && (until <= request.PerformedOn || until < request.ValidFrom))
        {
            errors.Add("validUntil", "Protection ends after it starts.");
        }

        CareRules.ValidateValidity(errors, request.ValidFrom, request.ValidUntil, latestToday);

        if (request.WeightKg is { } weight && RoundedWeight(weight) is <= 0 or > 200)
        {
            errors.Add("weightKg", "Use a weight above 0 and up to 200 kg.");
        }

        if (request.Details is { } details)
        {
            errors.MaxLength("details.laboratory", Input.Clean(details.Laboratory), 200);
            errors.MaxLength("details.reportNumber", Input.Clean(details.ReportNumber), 50);
            if (details.TiterIuPerMl is { } titer && titer is < 0 or > 1000)
            {
                errors.Add("details.titerIuPerMl", "Use a result from 0 to 1000 IU/ml.");
            }
        }

        return errors;
    }

    /// <summary>A weight to 10 g, as the record keeps it: 0.004 kg would be stored as 0.</summary>
    internal static decimal RoundedWeight(decimal kg) => decimal.Round(kg, 2, MidpointRounding.AwayFromZero);

    private static ValidationProblem FileIdsProblem(string message) =>
        TypedResults.ValidationProblem(new Dictionary<string, string[]> { ["fileIds"] = [message] });

    internal static async Task<CareRecordResponse> ToResponseAsync(CareRecord record, Files files, CancellationToken ct) =>
        (await ToResponsesAsync([record], files, ct))[0];

    private static async Task<List<CareRecordResponse>> ToResponsesAsync(List<CareRecord> records, Files files, CancellationToken ct)
    {
        var links = await files.LinksAsync(records.SelectMany(r => r.Files).Select(f => f.FileId), ct);
        return records
            .Select(r => new CareRecordResponse(
                r.Id,
                r.PetId,
                r.PlanId,
                r.Kind,
                r.Title,
                r.PerformedOn,
                r.PerformedTime,
                r.Product,
                r.Manufacturer,
                r.BatchNumber,
                r.ValidFrom,
                r.ValidUntil,
                r.Targets,
                r.Clinic,
                r.Veterinarian,
                r.WeightKg,
                r.Details is { } d ? new CareRecordDetailsDto(d.Laboratory, d.ReportNumber, d.TiterIuPerMl, d.FitForTravel) : null,
                r.Notes,
                r.Source,
                r.Files.OrderBy(f => f.Position).Select(f => links[f.FileId]).ToList(),
                r.CreatedAt,
                r.UpdatedAt))
            .ToList();
    }
}

public sealed record RecordSummary(Guid Id, CareKind Kind, DateOnly PerformedOn, string? Product);

/// <summary>The Care module's public API for adding records from elsewhere (AI imports).</summary>
public sealed class CareRecordsWriter(AppDbContext db, TimeProvider clock)
{
    /// <summary>The same checks as a record added by hand; field names get <paramref name="prefix"/>.</summary>
    public void Validate(CareRecordRequest request, string prefix, ValidationErrors errors) =>
        errors.AddAll(prefix, CareRecordsEndpoints.Validate(request, clock));

    /// <summary>Adds a record; saved with the caller's SaveChanges. With a plan, it counts as a "Done" of it.</summary>
    public CareRecord Add(Guid householdId, Guid petId, Guid userId, CareRecordRequest request, RecordSource source, Guid? planId)
    {
        var record = new CareRecord(householdId, petId, request.Kind, request.Title.Trim(), request.PerformedOn, userId, clock.GetUtcNow())
        {
            Source = source,
            PlanId = planId,
        };
        CareRecordsEndpoints.Apply(request, record);
        db.CareRecords.Add(record);
        return record;
    }

    /// <summary>
    /// Checks records linked to plans: the plan must be one of the pet's, of the same kind and, for a vaccination,
    /// against at least one of the same diseases (when both say which).
    /// </summary>
    public async Task ValidatePlanLinksAsync(
        Guid petId,
        IReadOnlyList<(string Field, CareRecordRequest Record, Guid PlanId)> links,
        ValidationErrors errors,
        CancellationToken ct)
    {
        if (links.Count == 0)
        {
            return;
        }

        var ids = links.Select(l => l.PlanId).Distinct().ToList();
        var plans = await db.CarePlans.AsNoTracking().Where(p => p.PetId == petId && ids.Contains(p.Id)).ToDictionaryAsync(p => p.Id, ct);
        foreach (var (field, record, planId) in links)
        {
            if (!plans.TryGetValue(planId, out var plan))
            {
                errors.Add(field, "Choose one of the pet's plans.");
            }
            else if (plan.Kind != record.Kind)
            {
                errors.Add(field, "Choose a plan of the same kind.");
            }
            else if (plan.Targets.Count > 0 && record.Targets is { Count: > 0 } targets && !plan.Targets.Intersect(targets).Any())
            {
                errors.Add(field, "Choose a plan against the same diseases.");
            }
        }
    }

    /// <summary>
    /// Moves the plans that new records belong to, as "Done" does, by the newest record of each plan and only when
    /// <see cref="PlanSummary.MovedBy"/> says so: an old entry from the passport never moves a plan back or closes
    /// it. With <paramref name="chosenByUser"/> (a visit that just took place, linked to its plans by the user) the
    /// record is the plan's "Done" unless the plan was done that day or later already. Call it before saving the
    /// records. Returns the plans that moved.
    /// </summary>
    public async Task<List<Guid>> MovePlansAsync(IReadOnlyList<CareRecord> added, CancellationToken ct, bool chosenByUser = false)
    {
        var newest = added
            .Where(r => r.PlanId is not null)
            .GroupBy(r => r.PlanId!.Value)
            .ToDictionary(g => g.Key, g => g.MaxBy(r => r.PerformedOn)!);
        if (newest.Count == 0)
        {
            return [];
        }

        var ids = newest.Keys.ToList();
        var plans = await db.CarePlans.Where(p => ids.Contains(p.Id)).ToListAsync(ct);
        var lastDone = await CarePlansEndpoints.LastDoneAsync(db, ids, ct);

        var moved = new List<Guid>();
        foreach (var plan in plans)
        {
            var record = newest[plan.Id];
            DateOnly? last = lastDone.TryGetValue(plan.Id, out var done) ? done : null;
            if (chosenByUser
                    ? last is null || record.PerformedOn > last
                    : PlanSummary.Of(plan, last).MovedBy(record.PerformedOn, record.ValidUntil))
            {
                plan.MarkDone(record.PerformedOn, record.ValidUntil, chosenNextDueOn: null, clock.GetUtcNow());
                moved.Add(plan.Id);
            }
        }

        return moved;
    }

    /// <summary>Kind, date and product of every record of the pet, to spot entries that would be saved twice.</summary>
    public Task<List<RecordSummary>> SummariesAsync(Guid petId, CancellationToken ct) =>
        db.CareRecords.AsNoTracking()
            .Where(r => r.PetId == petId)
            .Select(r => new RecordSummary(r.Id, r.Kind, r.PerformedOn, r.Product))
            .ToListAsync(ct);
}

/// <summary>Which records make which passport section (spec, section 4).</summary>
public static class PassportSections
{
    /// <summary>Section V: vaccinations against rabies, even when combined with other targets.</summary>
    public static bool IsRabies(CareRecord record) =>
        record.Kind == CareKind.Vaccination && record.Targets.Contains(VaccineTarget.Rabies);
}

/// <summary>Validation rules that plans and records share.</summary>
public static class CareRules
{
    /// <summary>No care record or due date is older than this.</summary>
    public static readonly DateOnly EarliestDate = new(1990, 1, 1);

    public static void ValidatePerformedOn(ValidationErrors errors, DateOnly performedOn, TimeProvider clock) =>
        ValidatePerformedOn(errors, performedOn, Input.LatestToday(clock));

    public static void ValidatePerformedOn(ValidationErrors errors, DateOnly performedOn, DateOnly latestToday)
    {
        if (performedOn < EarliestDate)
        {
            errors.Add("performedOn", "Use a date after 1990.");
        }

        errors.NotInFuture("performedOn", performedOn, latestToday);
    }

    /// <summary>
    /// "Valid from" and "valid until" no later than ten years ahead: a plan's next date follows them, and dates near
    /// the end of the calendar can't be reminded of.
    /// </summary>
    public static void ValidateValidity(ValidationErrors errors, DateOnly? validFrom, DateOnly? validUntil, DateOnly latestToday)
    {
        var latest = latestToday.AddYears(10);
        if (validFrom > latest)
        {
            errors.Add("validFrom", "Use a date within the next 10 years.");
        }

        if (validUntil > latest)
        {
            errors.Add("validUntil", "Use a date within the next 10 years.");
        }
    }

    public static void ValidateTargets(ValidationErrors errors, CareKind kind, List<VaccineTarget>? targets)
    {
        if (targets is null || targets.Count == 0)
        {
            return;
        }

        if (kind != CareKind.Vaccination)
        {
            errors.Add("targets", "Only vaccinations have targets.");
        }
        else if (targets.Any(t => !Enum.IsDefined(t)) || targets.Distinct().Count() != targets.Count)
        {
            errors.Add("targets", "Use each known target once.");
        }
    }
}

/// <summary>Before a pet is deleted: removes the files attached to its care records.</summary>
public sealed class CareRecordFiles(AppDbContext db, Files files) : IPetDeletionHandler
{
    /// <summary>The plans and records themselves are deleted by the database together with the pet.</summary>
    public async Task BeforePetDeletedAsync(Guid petId, CancellationToken ct)
    {
        var fileIds = await db.CareRecords
            .Where(r => r.PetId == petId)
            .SelectMany(r => r.Files)
            .Select(f => f.FileId)
            .ToListAsync(ct);
        await files.RemoveAsync(fileIds, ct);
    }
}

/// <summary>The weights noted at check-ups, for the pet's weight log (changed in their records).</summary>
public sealed class CareRecordWeights(AppDbContext db) : IPetWeightSource
{
    public async Task<List<WeightResponse>> WeightsAsync(Guid householdId, Guid petId, CancellationToken ct) =>
        (await db.CareRecords.AsNoTracking()
            .Where(r => r.HouseholdId == householdId && r.PetId == petId && r.Kind == CareKind.VetExam && r.WeightKg != null)
            .Select(r => new { r.Id, r.PerformedOn, WeightKg = r.WeightKg!.Value, r.Title, r.CreatedAt, r.UpdatedAt })
            .ToListAsync(ct))
        .Select(r => new WeightResponse(
            r.Id, petId, WeightSource.CareRecord, r.PerformedOn, r.WeightKg, Bcs: null, BcsScale: null, Note: r.Title,
            r.CreatedAt, r.UpdatedAt))
        .ToList();
}

/// <summary>The household's care plans and records (with their files' ids), for "Download my data".</summary>
public sealed class CareExport(AppDbContext db) : IHouseholdExportSource
{
    public async Task ExportAsync(HouseholdExport export, CancellationToken ct)
    {
        export.Add("carePlans", await db.CarePlans.AsNoTracking()
            .Where(p => p.HouseholdId == export.HouseholdId)
            .OrderBy(p => p.CreatedAt)
            .ToListAsync(ct));
        export.Add("careRecords", await db.CareRecords.AsNoTracking()
            .Include(r => r.Files)
            .Where(r => r.HouseholdId == export.HouseholdId)
            .OrderBy(r => r.PerformedOn)
            .ThenBy(r => r.CreatedAt)
            .ToListAsync(ct));
    }
}
