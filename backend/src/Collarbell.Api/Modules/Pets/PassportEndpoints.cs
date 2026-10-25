using System.Text.RegularExpressions;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Pets;

public sealed record PassportContactDto(string? Name, string? Address, string? Phone, string? Email);

/// <summary>Replaces the passport header. Contacts with no filled field are dropped.</summary>
public sealed record PassportRequest(
    PassportModel? Model,
    string? PassportNumber,
    string? IssuingCountry,
    DateOnly? IssuedOn,
    PassportContactDto? Issuer,
    List<PassportContactDto>? Owners,
    string? Notes);

/// <summary>The passport header; <see cref="UpdatedAt"/> is null until it is saved for the first time.</summary>
public sealed record PassportResponse(
    Guid PetId,
    PassportModel? Model,
    string? PassportNumber,
    string? IssuingCountry,
    DateOnly? IssuedOn,
    PassportContactDto? Issuer,
    List<PassportContactDto> Owners,
    string? Notes,
    DateTimeOffset? UpdatedAt);

public static partial class PassportEndpoints
{
    private const int MaxOwners = 2;

    public static RouteGroupBuilder MapPassportEndpoints(this RouteGroupBuilder api)
    {
        var passport = api.MapGroup("/pets/{id:guid}/passport").WithTags("Passport").ReportsChanges(LiveTopics.Passport);

        passport.MapGet("", GetPassport)
            .WithName("GetPetPassport")
            .WithSummary("The header of the pet's digital passport copy (empty until saved).");

        passport.MapPut("", UpdatePassport)
            .WithName("UpdatePetPassport")
            .WithSummary("Save the passport header: model, number, country, issue date, issuing vet, owners.");

        return api;
    }

    private static async Task<Results<Ok<PassportResponse>, NotFound>> GetPassport(
        Guid id, CurrentUserAccessor current, AppDbContext db, PetDirectory pets, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, id, ct))
        {
            return TypedResults.NotFound();
        }

        var passport = await db.PetPassports.AsNoTracking().SingleOrDefaultAsync(p => p.PetId == id, ct);
        return TypedResults.Ok(passport is null
            ? new PassportResponse(id, null, null, null, null, null, [], null, null)
            : ToResponse(passport));
    }

    private static async Task<Results<Ok<PassportResponse>, NotFound, ValidationProblem>> UpdatePassport(
        Guid id,
        PassportRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, id, ct))
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var passport = await db.PetPassports.SingleOrDefaultAsync(p => p.PetId == id, ct);
        if (passport is null)
        {
            passport = new PetPassport(id);
            db.PetPassports.Add(passport);
        }

        passport.Model = request.Model;
        passport.PassportNumber = NormalizeNumber(request.PassportNumber);
        passport.IssuingCountry = Input.Clean(request.IssuingCountry)?.ToUpperInvariant();
        passport.IssuedOn = request.IssuedOn;
        passport.Issuer = ToContact(request.Issuer);
        passport.Owners = (request.Owners ?? []).Select(ToContact).OfType<PassportContact>().ToList();
        passport.Notes = Input.Clean(request.Notes);
        passport.UpdatedAt = clock.GetUtcNow();

        await db.SaveChangesAsync(ct);
        return TypedResults.Ok(ToResponse(passport));
    }

    private static ValidationErrors Validate(PassportRequest request, TimeProvider clock)
    {
        var errors = new ValidationErrors();
        if (request.Model is { } model && !Enum.IsDefined(model))
        {
            errors.Add("model", "Unknown passport model.");
        }

        if (NormalizeNumber(request.PassportNumber) is { } number && !PassportNumber().IsMatch(number))
        {
            errors.Add("passportNumber", "Use up to 30 letters, digits, hyphens and slashes.");
        }

        if (Input.Clean(request.IssuingCountry) is { } country && !CountryCode().IsMatch(country))
        {
            errors.Add("issuingCountry", "Use the two-letter country code, such as DE or FR.");
        }

        errors.NotInFuture("issuedOn", request.IssuedOn, Input.LatestToday(clock));
        errors.MaxLength("notes", Input.Clean(request.Notes), 2000);
        ValidateContact(errors, "issuer", request.Issuer);

        var owners = request.Owners ?? [];
        if (owners.Count > MaxOwners)
        {
            errors.Add("owners", $"A passport lists up to {MaxOwners} owners.");
        }

        for (var i = 0; i < owners.Count; i++)
        {
            ValidateContact(errors, $"owners[{i}]", owners[i]);
        }

        return errors;
    }

    private static void ValidateContact(ValidationErrors errors, string field, PassportContactDto? contact)
    {
        if (contact is null)
        {
            return;
        }

        errors.MaxLength($"{field}.name", Input.Clean(contact.Name), 100);
        errors.MaxLength($"{field}.address", Input.Clean(contact.Address), 300);
        errors.MaxLength($"{field}.phone", Input.Clean(contact.Phone), 40);
        errors.MaxLength($"{field}.email", Input.Clean(contact.Email), 320);
        if (Input.Clean(contact.Email) is { } email && !email.Contains('@', StringComparison.Ordinal))
        {
            errors.Add($"{field}.email", "Enter an email address.");
        }
    }

    internal static string? NormalizeNumber(string? number) =>
        Input.Clean(number) is { } text ? string.Concat(text.Where(c => !char.IsWhiteSpace(c))).ToUpperInvariant() : null;

    private static PassportContact? ToContact(PassportContactDto? dto)
    {
        var contact = new PassportContact
        {
            Name = Input.Clean(dto?.Name),
            Address = Input.Clean(dto?.Address),
            Phone = Input.Clean(dto?.Phone),
            Email = Input.Clean(dto?.Email),
        };
        return contact is { Name: null, Address: null, Phone: null, Email: null } ? null : contact;
    }

    private static PassportContactDto ToDto(PassportContact contact) =>
        new(contact.Name, contact.Address, contact.Phone, contact.Email);

    private static PassportResponse ToResponse(PetPassport passport) => new(
        passport.PetId,
        passport.Model,
        passport.PassportNumber,
        passport.IssuingCountry,
        passport.IssuedOn,
        passport.Issuer is null ? null : ToDto(passport.Issuer),
        passport.Owners.Select(ToDto).ToList(),
        passport.Notes,
        passport.UpdatedAt);

    [GeneratedRegex("^[A-Z0-9/-]{1,30}$")]
    internal static partial Regex PassportNumber();

    [GeneratedRegex("^[A-Za-z]{2}$")]
    internal static partial Regex CountryCode();
}
