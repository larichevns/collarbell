using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Pets;

/// <summary>
/// Create or replace a pet. On create, a missing <see cref="Coat"/> picks the colour that is least used
/// in the household; on update, missing <see cref="Coat"/> and <see cref="Status"/> keep their values.
/// <see cref="Identifiers"/> replace the pet's identifiers.
/// </summary>
public sealed record PetRequest(
    string Name,
    Species Species,
    string? Breed,
    Sex Sex,
    DateOnly? BirthDate,
    bool BirthDateApproximate,
    bool? Neutered,
    DateOnly? NeuteredOn,
    string? Color,
    string? Markings,
    Coat? Coat,
    string? Allergies,
    string? Notes,
    PetStatus? Status,
    List<PetIdentifierRequest>? Identifiers);

public sealed record PetIdentifierRequest(
    IdentifierType Type,
    string Code,
    DateOnly? AppliedOn,
    DateOnly? ReadOn,
    string? Location);

public sealed record PetResponse(
    Guid Id,
    string Name,
    Species Species,
    string? Breed,
    Sex Sex,
    DateOnly? BirthDate,
    bool BirthDateApproximate,
    bool? Neutered,
    DateOnly? NeuteredOn,
    string? Color,
    string? Markings,
    Coat Coat,
    string? Allergies,
    string? Notes,
    PetStatus Status,
    FileLink? Photo,
    List<PetIdentifierResponse> Identifiers,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record PetIdentifierResponse(
    Guid Id,
    IdentifierType Type,
    string Code,
    string RawCode,
    DateOnly? AppliedOn,
    DateOnly? ReadOn,
    string? Location);

public sealed record SetPetPhotoRequest(Guid FileId);

public static class PetsEndpoints
{
    private const int MaxNameLength = 60;
    private const int MaxIdentifiers = 5;

    public static RouteGroupBuilder MapPetsEndpoints(this RouteGroupBuilder api)
    {
        // A pet added, changed or deleted: everything shown about it may have changed.
        var pets = api.MapGroup("/pets").WithTags("Pets").ReportsChanges(LiveTopics.Pets);

        pets.MapGet("", ListPets)
            .WithName("ListPets")
            .WithSummary("Pets of the signed-in user's household: active first, then by when they were added.");

        pets.MapPost("", CreatePet)
            .WithName("CreatePet")
            .WithSummary("Add a pet.");

        pets.MapGet("/{id:guid}", GetPet)
            .WithName("GetPet")
            .WithSummary("One pet.");

        pets.MapPut("/{id:guid}", UpdatePet)
            .WithName("UpdatePet")
            .WithSummary("Replace the pet's details and identifiers.");

        pets.MapDelete("/{id:guid}", DeletePet)
            .WithName("DeletePet")
            .WithSummary("Delete the pet with its passport, documents and files. This can't be undone.");

        pets.MapPut("/{id:guid}/photo", SetPhoto)
            .WithName("SetPetPhoto")
            .WithSummary("Use an uploaded photo as the pet's photo; the previous photo is deleted.");

        pets.MapDelete("/{id:guid}/photo", RemovePhoto)
            .WithName("RemovePetPhoto")
            .WithSummary("Delete the pet's photo.");

        return api;
    }

    private static async Task<Ok<List<PetResponse>>> ListPets(
        CurrentUserAccessor current, AppDbContext db, Files files, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var pets = await db.Pets.AsNoTracking()
            .Include(p => p.Identifiers)
            .Where(p => p.HouseholdId == me.HouseholdId)
            .OrderBy(p => p.Status != PetStatus.Active)
            .ThenBy(p => p.CreatedAt)
            .ToListAsync(ct);

        var photos = await files.LinksAsync(pets.Where(p => p.PhotoFileId is not null).Select(p => p.PhotoFileId!.Value), ct);
        return TypedResults.Ok(pets.Select(p => ToResponse(p, photos)).ToList());
    }

    private static async Task<Results<Ok<PetResponse>, NotFound>> GetPet(
        Guid id, CurrentUserAccessor current, AppDbContext db, Files files, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var pet = await FindAsync(db, me, id, ct);
        return pet is null ? TypedResults.NotFound() : TypedResults.Ok(await ToResponseAsync(pet, files, ct));
    }

    private static async Task<Results<Created<PetResponse>, ValidationProblem>> CreatePet(
        PetRequest request, CurrentUserAccessor current, AppDbContext db, Files files, TimeProvider clock, CancellationToken ct)
    {
        var errors = Validate(request, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var me = await current.GetAsync(ct);
        var pet = new Pet(me.HouseholdId, request.Name.Trim(), request.Species, clock.GetUtcNow())
        {
            Coat = request.Coat ?? await LeastUsedCoatAsync(db, me.HouseholdId, ct),
            Status = request.Status ?? PetStatus.Active,
        };
        Apply(request, pet);

        db.Pets.Add(pet);
        await db.SaveChangesAsync(ct);
        return TypedResults.Created($"/api/v1/pets/{pet.Id}", await ToResponseAsync(pet, files, ct));
    }

    private static async Task<Results<Ok<PetResponse>, NotFound, ValidationProblem>> UpdatePet(
        Guid id,
        PetRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        Files files,
        IEnumerable<IHouseholdChangeHandler> listeners,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var pet = await FindAsync(db, me, id, ct);
        if (pet is null)
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        pet.Name = request.Name.Trim();
        pet.Species = request.Species;
        pet.Coat = request.Coat ?? pet.Coat;
        pet.Status = request.Status ?? pet.Status;
        Apply(request, pet);
        pet.UpdatedAt = clock.GetUtcNow();

        await db.SaveChangesAsync(ct);
        // A paused pet gets no reminders, a renamed one gets them under its new name.
        foreach (var listener in listeners)
        {
            await listener.HouseholdChangedAsync(me.HouseholdId, ct);
        }

        return TypedResults.Ok(await ToResponseAsync(pet, files, ct));
    }

    private static async Task<Results<NoContent, NotFound>> DeletePet(
        Guid id,
        CurrentUserAccessor current,
        AppDbContext db,
        Files files,
        IEnumerable<IPetDeletionHandler> otherModules,
        IEnumerable<IHouseholdChangeHandler> listeners,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var pet = await FindAsync(db, me, id, ct);
        if (pet is null)
        {
            return TypedResults.NotFound();
        }

        // The database deletes everything that belongs to the pet together with it. Files are removed explicitly,
        // so that their storage objects get deleted too: other modules (documents, care records) remove theirs here.
        foreach (var module in otherModules)
        {
            await module.BeforePetDeletedAsync(pet.Id, ct);
        }

        if (pet.PhotoFileId is { } photoId)
        {
            await files.RemoveAsync([photoId], ct);
        }

        db.Pets.Remove(pet);
        await db.SaveChangesAsync(ct);
        foreach (var listener in listeners)
        {
            await listener.HouseholdChangedAsync(me.HouseholdId, ct);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<PetResponse>, NotFound, ValidationProblem>> SetPhoto(
        Guid id, SetPetPhotoRequest request, CurrentUserAccessor current, AppDbContext db, Files files, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var pet = await FindAsync(db, me, id, ct);
        if (pet is null)
        {
            return TypedResults.NotFound();
        }

        if (pet.PhotoFileId == request.FileId)
        {
            return TypedResults.Ok(await ToResponseAsync(pet, files, ct));
        }

        var error = await files.AttachAsync(me.HouseholdId, [request.FileId], photosOnly: true, ct);
        if (error is not null)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]> { ["fileId"] = [error] });
        }

        if (pet.PhotoFileId is { } previous)
        {
            await files.RemoveAsync([previous], ct);
        }

        pet.PhotoFileId = request.FileId;
        pet.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return TypedResults.Ok(await ToResponseAsync(pet, files, ct));
    }

    private static async Task<Results<NoContent, NotFound>> RemovePhoto(
        Guid id, CurrentUserAccessor current, AppDbContext db, Files files, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var pet = await FindAsync(db, me, id, ct);
        if (pet is null)
        {
            return TypedResults.NotFound();
        }

        if (pet.PhotoFileId is { } photoId)
        {
            await files.RemoveAsync([photoId], ct);
            pet.PhotoFileId = null;
            pet.UpdatedAt = clock.GetUtcNow();
            await db.SaveChangesAsync(ct);
        }

        return TypedResults.NoContent();
    }

    /// <summary>Only pets of the caller's household are found: someone else's pet is "not found", never "forbidden".</summary>
    private static Task<Pet?> FindAsync(AppDbContext db, CurrentUser me, Guid id, CancellationToken ct) =>
        db.Pets
            .Include(p => p.Identifiers)
            .SingleOrDefaultAsync(p => p.Id == id && p.HouseholdId == me.HouseholdId, ct);

    /// <summary>Fields that create and update set the same way.</summary>
    private static void Apply(PetRequest request, Pet pet)
    {
        pet.Breed = Input.Clean(request.Breed);
        pet.Sex = request.Sex;
        pet.BirthDate = request.BirthDate;
        pet.BirthDateApproximate = request.BirthDate is not null && request.BirthDateApproximate;
        pet.NeuteredOn = request.NeuteredOn;
        pet.Neutered = request.NeuteredOn is not null ? true : request.Neutered;
        pet.Color = Input.Clean(request.Color);
        pet.Markings = Input.Clean(request.Markings);
        pet.Allergies = Input.Clean(request.Allergies);
        pet.Notes = Input.Clean(request.Notes);

        pet.Identifiers.Clear();
        foreach (var item in request.Identifiers ?? [])
        {
            pet.Identifiers.Add(new PetIdentifier(item.Type, IdentifierRules.Normalize(item.Code), item.Code.Trim())
            {
                AppliedOn = item.AppliedOn,
                ReadOn = item.ReadOn,
                Location = Input.Clean(item.Location),
            });
        }
    }

    /// <summary>New pets get a colour no other pet of the household has, while there are free ones.</summary>
    private static async Task<Coat> LeastUsedCoatAsync(AppDbContext db, Guid householdId, CancellationToken ct)
    {
        var used = await db.Pets
            .Where(p => p.HouseholdId == householdId)
            .GroupBy(p => p.Coat)
            .Select(g => new { Coat = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Coat, x => x.Count, ct);
        return Enum.GetValues<Coat>().MinBy(c => used.GetValueOrDefault(c));
    }

    private static ValidationErrors Validate(PetRequest request, TimeProvider clock)
    {
        var errors = new ValidationErrors();
        var latestToday = Input.LatestToday(clock);

        var name = Input.Clean(request.Name);
        if (name is null)
        {
            errors.Add("name", "Enter the pet's name.");
        }

        errors.MaxLength("name", name, MaxNameLength);
        errors.MaxLength("breed", Input.Clean(request.Breed), 100);
        errors.MaxLength("color", Input.Clean(request.Color), 60);
        errors.MaxLength("markings", Input.Clean(request.Markings), 300);
        errors.MaxLength("allergies", Input.Clean(request.Allergies), 500);
        errors.MaxLength("notes", Input.Clean(request.Notes), 2000);
        errors.NotInFuture("birthDate", request.BirthDate, latestToday);
        errors.NotInFuture("neuteredOn", request.NeuteredOn, latestToday);

        if (!Enum.IsDefined(request.Species))
        {
            errors.Add("species", "Unknown species.");
        }

        if (!Enum.IsDefined(request.Sex))
        {
            errors.Add("sex", "Unknown sex.");
        }

        if (request.Coat is { } coat && !Enum.IsDefined(coat))
        {
            errors.Add("coat", "Unknown colour.");
        }

        if (request.Status is { } status && !Enum.IsDefined(status))
        {
            errors.Add("status", "Unknown status.");
        }

        if (request.BirthDate is { } born && request.NeuteredOn < born)
        {
            errors.Add("neuteredOn", "Neutering can't be before birth.");
        }

        ValidateIdentifiers(request.Identifiers ?? [], "identifiers", latestToday, errors);
        return errors;
    }

    /// <summary>The identifier rules of the pet form, shared with AI imports; field names start with <paramref name="prefix"/>.</summary>
    internal static void ValidateIdentifiers(
        IReadOnlyList<PetIdentifierRequest?> identifiers, string prefix, DateOnly latestToday, ValidationErrors errors)
    {
        if (identifiers.Count > MaxIdentifiers)
        {
            errors.Add(prefix, $"Use {MaxIdentifiers} identifiers or fewer.");
        }

        var codes = new HashSet<string>();
        for (var i = 0; i < identifiers.Count; i++)
        {
            var field = $"{prefix}[{i}]";
            if (identifiers[i] is not { } item)
            {
                errors.Add(field, "Add the identifier.");
                continue;
            }

            if (!Enum.IsDefined(item.Type))
            {
                errors.Add($"{field}.type", "Unknown identifier type.");
                continue;
            }

            if (item.Code is null || item.Code.Trim().Length > IdentifierRules.MaxRawLength)
            {
                errors.Add($"{field}.code", $"Enter the code, up to {IdentifierRules.MaxRawLength} characters.");
                continue;
            }

            var code = IdentifierRules.Normalize(item.Code);
            if (IdentifierRules.Validate(item.Type, code) is { } problem)
            {
                errors.Add($"{field}.code", problem);
            }
            else if (!codes.Add(code))
            {
                errors.Add($"{field}.code", "This code is already in the list.");
            }

            errors.NotInFuture($"{field}.appliedOn", item.AppliedOn, latestToday);
            errors.NotInFuture($"{field}.readOn", item.ReadOn, latestToday);
            errors.MaxLength($"{field}.location", Input.Clean(item.Location), 60);
        }
    }

    private static async Task<PetResponse> ToResponseAsync(Pet pet, Files files, CancellationToken ct)
    {
        var photos = pet.PhotoFileId is { } photoId ? await files.LinksAsync([photoId], ct) : [];
        return ToResponse(pet, photos);
    }

    private static PetResponse ToResponse(Pet pet, IReadOnlyDictionary<Guid, FileLink> photos) => new(
        pet.Id,
        pet.Name,
        pet.Species,
        pet.Breed,
        pet.Sex,
        pet.BirthDate,
        pet.BirthDateApproximate,
        pet.Neutered,
        pet.NeuteredOn,
        pet.Color,
        pet.Markings,
        pet.Coat,
        pet.Allergies,
        pet.Notes,
        pet.Status,
        pet.PhotoFileId is { } photoId ? photos.GetValueOrDefault(photoId) : null,
        pet.Identifiers
            .OrderBy(i => i.Type)
            .ThenBy(i => i.Code, StringComparer.Ordinal)
            .Select(i => new PetIdentifierResponse(i.Id, i.Type, i.Code, i.RawCode, i.AppliedOn, i.ReadOn, i.Location))
            .ToList(),
        pet.CreatedAt,
        pet.UpdatedAt);
}

/// <summary>The Pets module's public API for other modules.</summary>
public sealed class PetDirectory(AppDbContext db)
{
    public Task<bool> ExistsAsync(Guid householdId, Guid petId, CancellationToken ct) =>
        db.Pets.AnyAsync(p => p.Id == petId && p.HouseholdId == householdId, ct);

    /// <summary>The pet's species, or null when the pet isn't in the household.</summary>
    public Task<Species?> SpeciesAsync(Guid householdId, Guid petId, CancellationToken ct) =>
        db.Pets
            .Where(p => p.Id == petId && p.HouseholdId == householdId)
            .Select(p => (Species?)p.Species)
            .SingleOrDefaultAsync(ct);

    /// <summary>Name, colour and photo of the household's pets, for screens that list things of several pets.</summary>
    public Task<List<PetCard>> CardsAsync(Guid householdId, CancellationToken ct) =>
        db.Pets.AsNoTracking()
            .Where(p => p.HouseholdId == householdId)
            .Select(p => new PetCard(p.Id, p.Name, p.Species, p.Coat, p.Status, p.PhotoFileId))
            .ToListAsync(ct);
}

public sealed record PetCard(Guid Id, string Name, Species Species, Coat Coat, PetStatus Status, Guid? PhotoFileId);

/// <summary>What a pet's passport header and identifiers already say.</summary>
public sealed record PetIdentity(IReadOnlySet<string> IdentifierCodes, string? PassportNumber, string? IssuingCountry, DateOnly? IssuedOn);

/// <summary>The Pets module's public API for AI imports: adding what a scan found to the pet.</summary>
public sealed class PetIdentityWriter(AppDbContext db, TimeProvider clock)
{
    public async Task<PetIdentity> ReadAsync(Guid petId, CancellationToken ct)
    {
        var codes = await db.Pets.Where(p => p.Id == petId).SelectMany(p => p.Identifiers).Select(i => i.Code).ToListAsync(ct);
        var passport = await db.PetPassports.AsNoTracking().SingleOrDefaultAsync(p => p.PetId == petId, ct);
        return new PetIdentity(codes.ToHashSet(), passport?.PassportNumber, passport?.IssuingCountry, passport?.IssuedOn);
    }

    /// <summary>Checks identifiers like the pet form does; field names start with <paramref name="prefix"/>.</summary>
    public void Validate(IReadOnlyList<PetIdentifierRequest?> items, string prefix, ValidationErrors errors) =>
        PetsEndpoints.ValidateIdentifiers(items, prefix, Input.LatestToday(clock), errors);

    /// <summary>Adds identifiers the pet doesn't have yet (up to five in all). Saved with the caller's SaveChanges.</summary>
    public async Task<int> AddIdentifiersAsync(Guid householdId, Guid petId, IReadOnlyList<PetIdentifierRequest> items, CancellationToken ct)
    {
        var pet = await db.Pets.Include(p => p.Identifiers).SingleAsync(p => p.Id == petId && p.HouseholdId == householdId, ct);
        var added = 0;
        foreach (var item in items)
        {
            var code = IdentifierRules.Normalize(item.Code);
            if (pet.Identifiers.Count >= 5 || pet.Identifiers.Exists(i => i.Code == code))
            {
                continue;
            }

            pet.Identifiers.Add(new PetIdentifier(item.Type, code, item.Code.Trim())
            {
                AppliedOn = item.AppliedOn,
                ReadOn = item.ReadOn,
                Location = Input.Clean(item.Location),
            });
            added++;
        }

        if (added > 0)
        {
            pet.UpdatedAt = clock.GetUtcNow();
        }

        return added;
    }

    /// <summary>Checks a passport number and country like the passport form does.</summary>
    public static void ValidatePassport(string? number, string? country, string prefix, ValidationErrors errors)
    {
        if (PassportEndpoints.NormalizeNumber(number) is { } normalized && !PassportEndpoints.PassportNumber().IsMatch(normalized))
        {
            errors.Add($"{prefix}.passportNumber", "Use up to 30 letters, digits, hyphens and slashes.");
        }

        if (Input.Clean(country) is { } code && !PassportEndpoints.CountryCode().IsMatch(code))
        {
            errors.Add($"{prefix}.issuingCountry", "Use the two-letter country code, such as DE or FR.");
        }
    }

    /// <summary>Sets the given passport header fields; the others stay. Saved with the caller's SaveChanges.</summary>
    public async Task<bool> FillPassportAsync(Guid petId, string? number, string? country, DateOnly? issuedOn, CancellationToken ct)
    {
        var normalized = PassportEndpoints.NormalizeNumber(number);
        var code = Input.Clean(country)?.ToUpperInvariant();
        if (normalized is null && code is null && issuedOn is null)
        {
            return false;
        }

        var passport = await db.PetPassports.SingleOrDefaultAsync(p => p.PetId == petId, ct);
        if (passport is null)
        {
            passport = new PetPassport(petId);
            db.PetPassports.Add(passport);
        }

        passport.PassportNumber = normalized ?? passport.PassportNumber;
        passport.IssuingCountry = code ?? passport.IssuingCountry;
        passport.IssuedOn = issuedOn ?? passport.IssuedOn;
        passport.UpdatedAt = clock.GetUtcNow();
        return true;
    }
}

/// <summary>
/// Other modules hook into pet deletion here: before a pet is deleted, each one removes what the database cascade
/// can't, such as the storage objects of its files. The Pets module only knows this interface, not the modules.
/// </summary>
public interface IPetDeletionHandler
{
    Task BeforePetDeletedAsync(Guid petId, CancellationToken ct);
}

/// <summary>The household's pets with their chips, their passport details and weighings, for "Download my data".</summary>
public sealed class PetsExport(AppDbContext db) : IHouseholdExportSource
{
    public async Task ExportAsync(HouseholdExport export, CancellationToken ct)
    {
        var pets = await db.Pets.AsNoTracking()
            .Include(p => p.Identifiers)
            .Where(p => p.HouseholdId == export.HouseholdId)
            .OrderBy(p => p.CreatedAt)
            .ToListAsync(ct);
        var ids = pets.Select(p => p.Id).ToList();
        export.Add("pets", pets);
        export.Add("passports", await db.PetPassports.AsNoTracking().Where(p => ids.Contains(p.PetId)).ToListAsync(ct));
        // A vet's weights are in their care records (careRecords).
        export.Add("weights", await db.WeightEntries.AsNoTracking()
            .Where(w => w.HouseholdId == export.HouseholdId)
            .OrderBy(w => w.PetId)
            .ThenBy(w => w.MeasuredOn)
            .ThenBy(w => w.CreatedAt)
            .ToListAsync(ct));
    }
}
