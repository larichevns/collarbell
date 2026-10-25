using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Identity;

public sealed class User
{
    private User()
    {
    }

    public User(string authSubject, string? email, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        AuthSubject = authSubject;
        Email = email;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    /// <summary>Firebase uid, or <c>dev:&lt;uid&gt;</c> for local dev users.</summary>
    public string AuthSubject { get; private set; } = null!;

    public string? Email { get; set; }

    public string? DisplayName { get; set; }

    public string Locale { get; set; } = Locales.English;

    /// <summary>IANA time zone, e.g. <c>Europe/Berlin</c>.</summary>
    public string TimeZone { get; set; } = "UTC";

    public DateTimeOffset CreatedAt { get; private set; }

    /// <summary>May open the admin (/admin): set on the server with <c>dotnet Collarbell.Api.dll make-admin &lt;e-mail&gt;</c>.</summary>
    public bool IsAdmin { get; set; }
}

/// <summary>The access boundary: all pet data belongs to a household, even a household of one.</summary>
public sealed class Household
{
    private Household()
    {
    }

    public Household(string name, string timeZone, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        Name = name;
        TimeZone = timeZone;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    public string Name { get; set; } = null!;

    /// <summary>Feeding times and reminders are computed in this IANA time zone.</summary>
    public string TimeZone { get; set; } = "UTC";

    /// <summary>
    /// An owner set the time zone in the household's settings. Until then a household of one follows the time zone of
    /// its owner's phone; a set one, or a shared one, stays where it is when someone travels.
    /// </summary>
    public bool TimeZoneSetByHand { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }
}

/// <summary>What a person may do in a household (spec, "Семья"). <see cref="HouseholdAccess"/> enforces it.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<HouseholdRole>))]
public enum HouseholdRole
{
    /// <summary>Everything, and the people: invites, roles, removing someone, the household's settings.</summary>
    Owner,

    /// <summary>Everything with the pets and their records, but not the people.</summary>
    Member,

    /// <summary>A sitter or a colleague: sees everything and marks feedings, "Done", visits and purchases.</summary>
    Helper,
}

public sealed class HouseholdMember
{
    private HouseholdMember()
    {
    }

    public HouseholdMember(Guid householdId, Guid userId, HouseholdRole role, DateTimeOffset now)
    {
        HouseholdId = householdId;
        UserId = userId;
        Role = role;
        JoinedAt = now;
    }

    public Guid HouseholdId { get; private set; }

    public Guid UserId { get; private set; }

    public HouseholdRole Role { get; private set; }

    public DateTimeOffset JoinedAt { get; private set; }

    public void ChangeRole(HouseholdRole role) => Role = role;
}

/// <summary>
/// A one-time code that lets someone join a household with a role (spec, "Семья"): random, valid for
/// <see cref="Lifetime"/>, used up by the first person who accepts it. The owner can take it back before that.
/// </summary>
public sealed class HouseholdInvite
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromDays(7);

    private HouseholdInvite()
    {
    }

    public HouseholdInvite(Guid householdId, string code, HouseholdRole role, Guid createdBy, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        Code = code;
        Role = role;
        CreatedBy = createdBy;
        CreatedAt = now;
        ExpiresAt = now + Lifetime;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    /// <summary>Eight characters without the ones easy to mix up (0/O, 1/I), stored without the hyphen.</summary>
    public string Code { get; private set; } = null!;

    /// <summary>The role the person gets: <see cref="HouseholdRole.Member"/> or <see cref="HouseholdRole.Helper"/>.</summary>
    public HouseholdRole Role { get; private set; }

    public Guid CreatedBy { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset ExpiresAt { get; private set; }

    public Guid? AcceptedBy { get; private set; }

    public DateTimeOffset? AcceptedAt { get; private set; }

    public DateTimeOffset? RevokedAt { get; private set; }

    public bool IsOpen(DateTimeOffset now) => AcceptedAt is null && RevokedAt is null && now < ExpiresAt;

    public void Accept(Guid userId, DateTimeOffset now)
    {
        AcceptedBy = userId;
        AcceptedAt = now;
    }

    public void Revoke(DateTimeOffset now) => RevokedAt = now;
}

/// <summary>
/// An account deleted a moment ago (spec, "Удаление аккаунта"). Its sign-in may still hold a token that works for up to an
/// hour, and a request with it would quietly start a new, empty account: such requests are refused instead. Kept until the
/// sign-in account (Firebase) is deleted too and <see cref="AccountCleanup.RefuseFor"/> has passed; until then
/// <see cref="AccountCleanup"/> keeps trying to delete it. Nothing else about the person is kept.
/// </summary>
public sealed class DeletedAccount
{
    private DeletedAccount()
    {
    }

    public DeletedAccount(string authSubject, DateTimeOffset now)
    {
        AuthSubject = authSubject;
        DeletedAt = now;
    }

    /// <summary>The Firebase uid, or <c>dev:&lt;uid&gt;</c>.</summary>
    public string AuthSubject { get; private set; } = null!;

    public DateTimeOffset DeletedAt { get; private set; }

    /// <summary>When the sign-in account was deleted as well; null while the server still has to.</summary>
    public DateTimeOffset? SignInDeletedAt { get; set; }

    /// <summary>Failed tries to delete the sign-in account.</summary>
    public int Attempts { get; set; }
}

public static class Locales
{
    public const string English = "en";
    public const string Russian = "ru";

    public static readonly IReadOnlySet<string> Supported = new HashSet<string> { English, Russian };
}
