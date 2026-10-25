using System.Text.Json.Serialization;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Collarbell.Api.Modules.Pets;

/// <summary>
/// A weighing. The weight is kept to the gram (more decimals are rounded). <see cref="Bcs"/> and <see cref="BcsScale"/>
/// come together or not at all. <see cref="RequestId"/> (creating only): a new id per weighing the app adds, the same
/// on retries, so a retry after a lost response doesn't add it twice.
/// </summary>
public sealed record WeightRequest(
    DateOnly MeasuredOn,
    decimal WeightKg,
    int? Bcs,
    int? BcsScale,
    string? Note,
    Guid? RequestId);

/// <summary>Where a weight in the log comes from.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<WeightSource>))]
public enum WeightSource
{
    /// <summary>A weighing of the log itself: changed and deleted at <c>/weights/{id}</c>.</summary>
    Weighing,

    /// <summary>The weight a care record notes (a vet's check-up): changed in that record, whose id this is.</summary>
    CareRecord,
}

/// <summary>
/// One weight of the pet's log. For a <see cref="WeightSource.CareRecord"/> the id is the record's, the note is its
/// title, and there is no body condition score.
/// </summary>
public sealed record WeightResponse(
    Guid Id,
    Guid PetId,
    WeightSource Source,
    DateOnly MeasuredOn,
    decimal WeightKg,
    int? Bcs,
    int? BcsScale,
    string? Note,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public static class WeightsEndpoints
{
    /// <summary>The heaviest weight taken: a giant breed is about 100 kg; more is a typo (grams typed as kilograms).</summary>
    public const decimal MaxWeightKg = 200;

    private const int MaxNoteLength = 500;

    /// <summary>No weighing is older than this; the same earliest date as care records.</summary>
    private static readonly DateOnly EarliestDate = new(1990, 1, 1);

    public static RouteGroupBuilder MapWeightsEndpoints(this RouteGroupBuilder api)
    {
        var petWeights = api.MapGroup("/pets/{petId:guid}/weights").WithTags("Weight").ReportsChanges(LiveTopics.Weight);

        petWeights.MapGet("", ListForPet)
            .WithName("ListPetWeights")
            .WithSummary("The pet's weight log, newest first: its weighings and the weights noted in its care records.");

        petWeights.MapPost("", Create)
            .WithName("CreateWeight")
            .WithSummary("Add a weighing.");

        var weights = api.MapGroup("/weights").WithTags("Weight").ReportsChanges(LiveTopics.Weight);

        weights.MapGet("/{id:guid}", Get)
            .WithName("GetWeight")
            .WithSummary("One weighing.");

        weights.MapPut("/{id:guid}", Update)
            .WithName("UpdateWeight")
            .WithSummary("Change a weighing.");

        weights.MapDelete("/{id:guid}", Delete)
            .WithName("DeleteWeight")
            .WithSummary("Delete a weighing.");

        return api;
    }

    private static async Task<Results<Ok<List<WeightResponse>>, NotFound>> ListForPet(
        Guid petId, CurrentUserAccessor current, AppDbContext db, PetWeights weights, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await db.Pets.AnyAsync(p => p.Id == petId && p.HouseholdId == me.HouseholdId, ct))
        {
            return TypedResults.NotFound();
        }

        return TypedResults.Ok(await weights.LogAsync(me.HouseholdId, petId, ct));
    }

    private static async Task<Results<Ok<WeightResponse>, NotFound>> Get(
        Guid id, CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var entry = await FindAsync(db, me, id, ct);
        return entry is null ? TypedResults.NotFound() : TypedResults.Ok(ToResponse(entry));
    }

    private static async Task<Results<Created<WeightResponse>, NotFound, ValidationProblem, ProblemHttpResult>> Create(
        Guid petId,
        WeightRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var birth = await BirthAsync(db, me.HouseholdId, petId, ct);
        if (birth is null)
        {
            return TypedResults.NotFound();
        }

        // A retry of a create that already went through gets the first answer, whatever changed since (a birth date).
        if (request.RequestId is { } requestId
            && await db.WeightEntries.SingleOrDefaultAsync(w => w.HouseholdId == me.HouseholdId && w.ClientRequestId == requestId, ct)
                is { } earlier)
        {
            return earlier.PetId == petId ? CreatedResponse(earlier) : RequestIdUsed();
        }

        var errors = Validate(request, birth.ExactDate, Input.LatestToday(clock));
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var entry = new WeightEntry(me.HouseholdId, petId, request.MeasuredOn, Rounded(request.WeightKg), me.UserId, clock.GetUtcNow())
        {
            ClientRequestId = request.RequestId,
        };
        Apply(request, entry);
        db.WeightEntries.Add(entry);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (request.RequestId is not null
            && e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // The same create twice at once: the other one made it.
            db.ChangeTracker.Clear();
            entry = await db.WeightEntries.SingleAsync(w => w.HouseholdId == me.HouseholdId && w.ClientRequestId == request.RequestId, ct);
            return entry.PetId == petId ? CreatedResponse(entry) : RequestIdUsed();
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException
            { SqlState: PostgresErrorCodes.ForeignKeyViolation, ConstraintName: var constraint })
        {
            // What the weighing belongs to went while it was on its way: the person's account (deleted on their other
            // phone), the household (deleted with its last owner's account) or the pet (deleted on another phone).
            if (constraint == ForeignKeys.User)
            {
                return AccountProblems.AccountDeleted();
            }

            if (constraint == ForeignKeys.Household)
            {
                return TypedResults.Problem(statusCode: StatusCodes.Status403Forbidden, title: "You aren't in this household.",
                    type: HouseholdProblems.NotAMember);
            }

            return TypedResults.NotFound();
        }

        return CreatedResponse(entry);
    }

    private static async Task<Results<Ok<WeightResponse>, NotFound, ValidationProblem>> Update(
        Guid id,
        WeightRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var entry = await FindAsync(db, me, id, ct);
        if (entry is null)
        {
            return TypedResults.NotFound();
        }

        // The birth date only checks a new date: a weighing from before the birth date was set stays changeable.
        var birth = request.MeasuredOn == entry.MeasuredOn ? null : await BirthAsync(db, me.HouseholdId, entry.PetId, ct);
        var errors = Validate(request, birth?.ExactDate, Input.LatestToday(clock));
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        entry.MeasuredOn = request.MeasuredOn;
        entry.WeightKg = Rounded(request.WeightKg);
        Apply(request, entry);
        entry.UpdatedAt = clock.GetUtcNow();
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Deleted meanwhile, on another phone or with its pet.
            return TypedResults.NotFound();
        }

        return TypedResults.Ok(ToResponse(entry));
    }

    private static async Task<Results<NoContent, NotFound>> Delete(
        Guid id, CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var entry = await FindAsync(db, me, id, ct);
        if (entry is null)
        {
            return TypedResults.NotFound();
        }

        db.WeightEntries.Remove(entry);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Deleted meanwhile (a double tap, another phone): what was asked for is done.
        }

        return TypedResults.NoContent();
    }

    private static Created<WeightResponse> CreatedResponse(WeightEntry entry) =>
        TypedResults.Created($"/api/v1/weights/{entry.Id}", ToResponse(entry));

    /// <summary>The app makes a new request id for every weighing; the same one for another pet is a mistake.</summary>
    private static ValidationProblem RequestIdUsed() =>
        TypedResults.ValidationProblem(new Dictionary<string, string[]>
        {
            ["requestId"] = ["This request id was used for something else."],
        });

    /// <summary>The foreign keys of <c>pets.weight_entries</c>, as the migration names them.</summary>
    private static class ForeignKeys
    {
        public const string User = "fk_weight_entries_users_created_by";
        public const string Household = "fk_weight_entries_households_household_id";
    }

    /// <summary>Only weighings of the caller's household are found; someone else's is "not found".</summary>
    private static Task<WeightEntry?> FindAsync(AppDbContext db, CurrentUser me, Guid id, CancellationToken ct) =>
        db.WeightEntries.SingleOrDefaultAsync(w => w.Id == id && w.HouseholdId == me.HouseholdId, ct);

    /// <summary>When the pet was born, as far as the weighing's date is concerned; null when it isn't the household's pet.</summary>
    private static Task<PetBirth?> BirthAsync(AppDbContext db, Guid householdId, Guid petId, CancellationToken ct) =>
        db.Pets
            .Where(p => p.Id == petId && p.HouseholdId == householdId)
            .Select(p => new PetBirth(p.BirthDateApproximate ? null : p.BirthDate))
            .SingleOrDefaultAsync(ct);

    /// <summary>An exact birth date: no weighing comes before it. An approximate one says nothing for sure.</summary>
    private sealed record PetBirth(DateOnly? ExactDate);

    /// <summary>Fields that create and update set the same way.</summary>
    private static void Apply(WeightRequest request, WeightEntry entry)
    {
        entry.Bcs = request.Bcs;
        entry.BcsScale = request.BcsScale;
        entry.Note = Input.Clean(request.Note);
    }

    /// <summary>To the gram, as the column keeps it.</summary>
    internal static decimal Rounded(decimal weightKg) => decimal.Round(weightKg, 3, MidpointRounding.AwayFromZero);

    /// <summary>
    /// The checks of a weighing; <paramref name="exactBirthDate"/> is the pet's birth date when it is exact (null: none to
    /// check), <paramref name="latestToday"/> the latest "today" anywhere on Earth.
    /// </summary>
    internal static ValidationErrors Validate(WeightRequest request, DateOnly? exactBirthDate, DateOnly latestToday)
    {
        var errors = new ValidationErrors();
        if (request.MeasuredOn < EarliestDate)
        {
            errors.Add("measuredOn", "Use a date after 1990.");
        }
        else if (request.MeasuredOn < exactBirthDate)
        {
            errors.Add("measuredOn", "A weighing can't be before the pet was born.");
        }

        errors.NotInFuture("measuredOn", request.MeasuredOn, latestToday);

        if (Rounded(request.WeightKg) is <= 0 or > MaxWeightKg)
        {
            errors.Add("weightKg", $"Use a weight above 0 and up to {MaxWeightKg:0} kg.");
        }

        switch (request.Bcs, request.BcsScale)
        {
            case (null, null):
                break;
            case (null, _):
                errors.Add("bcs", "Give the score together with its scale.");
                break;
            case (_, null):
                errors.Add("bcsScale", "Give the scale together with the score.");
                break;
            case (_, not (5 or 9)):
                errors.Add("bcsScale", "Use the 9-point or the 5-point scale.");
                break;
            case ({ } score, { } scale) when score < 1 || score > scale:
                errors.Add("bcs", $"Use a score from 1 to {scale}.");
                break;
        }

        errors.MaxLength("note", Input.Clean(request.Note), MaxNoteLength);
        return errors;
    }

    internal static WeightResponse ToResponse(WeightEntry entry) => new(
        entry.Id,
        entry.PetId,
        WeightSource.Weighing,
        entry.MeasuredOn,
        entry.WeightKg,
        entry.Bcs,
        entry.BcsScale,
        entry.Note,
        entry.CreatedAt,
        entry.UpdatedAt);
}

/// <summary>
/// The Pets module's public API for the weight log: the whole log as the Weight tab shows it, and weighings added from
/// elsewhere (what AI read from a note or a vet's paper), checked like those added by hand.
/// </summary>
public sealed class PetWeights(AppDbContext db, IEnumerable<IPetWeightSource> otherModules, TimeProvider clock)
{
    /// <summary>The pet's weighings and the weights other modules keep (a vet's check-ups), newest first.</summary>
    public async Task<List<WeightResponse>> LogAsync(Guid householdId, Guid petId, CancellationToken ct)
    {
        var weights = (await db.WeightEntries.AsNoTracking()
                .Where(w => w.HouseholdId == householdId && w.PetId == petId)
                .ToListAsync(ct))
            .Select(WeightsEndpoints.ToResponse)
            .ToList();
        foreach (var module in otherModules)
        {
            weights.AddRange(await module.WeightsAsync(householdId, petId, ct));
        }

        return weights
            .OrderByDescending(w => w.MeasuredOn)
            .ThenByDescending(w => w.CreatedAt)
            .ToList();
    }

    /// <summary>The pet's birth date when it is exact: no weighing comes before it.</summary>
    public Task<DateOnly?> ExactBirthDateAsync(Guid petId, CancellationToken ct) =>
        db.Pets
            .Where(p => p.Id == petId)
            .Select(p => p.BirthDateApproximate ? null : p.BirthDate)
            .SingleOrDefaultAsync(ct);

    /// <summary>The checks of a weighing added by hand; field names get <paramref name="prefix"/>.</summary>
    public void Validate(DateOnly measuredOn, decimal weightKg, DateOnly? exactBirthDate, string prefix, ValidationErrors errors) =>
        errors.AddAll(prefix, WeightsEndpoints.Validate(
            new WeightRequest(measuredOn, weightKg, Bcs: null, BcsScale: null, Note: null, RequestId: null),
            exactBirthDate,
            Input.LatestToday(clock)));

    /// <summary>Adds a weighing, kept to the gram; saved with the caller's SaveChanges.</summary>
    public WeightEntry Add(Guid householdId, Guid petId, Guid userId, DateOnly measuredOn, decimal weightKg)
    {
        var entry = new WeightEntry(householdId, petId, measuredOn, WeightsEndpoints.Rounded(weightKg), userId, clock.GetUtcNow());
        db.WeightEntries.Add(entry);
        return entry;
    }
}

/// <summary>
/// A module that keeps weights of its own, such as the one a vet notes at a check-up (Care): they join the pet's weight
/// log, and are changed where they are kept. The Pets module only knows this interface, not the modules.
/// </summary>
public interface IPetWeightSource
{
    /// <summary>The pet's weights, as <see cref="WeightSource.CareRecord"/> (or another source) entries of the log.</summary>
    Task<List<WeightResponse>> WeightsAsync(Guid householdId, Guid petId, CancellationToken ct);
}
