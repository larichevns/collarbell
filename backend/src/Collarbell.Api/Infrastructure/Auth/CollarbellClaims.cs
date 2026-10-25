using System.Security.Claims;

namespace Collarbell.Api.Infrastructure.Auth;

/// <summary>Claim names as Firebase issues them (inbound claim mapping is off).</summary>
public static class CollarbellClaims
{
    public const string Subject = "sub";
    public const string Email = "email";

    /// <summary>When the person last typed their password (seconds since 1970): signing in or confirming it again.</summary>
    public const string AuthTime = "auth_time";

    public static string? GetSubject(this ClaimsPrincipal principal) => principal.FindFirst(Subject)?.Value;

    public static string? GetEmail(this ClaimsPrincipal principal) => principal.FindFirst(Email)?.Value;

    /// <summary>When the person last proved who they are (<see cref="AuthTime"/>); null when the token doesn't say.</summary>
    public static DateTimeOffset? GetAuthTime(this ClaimsPrincipal principal) =>
        long.TryParse(principal.FindFirst(AuthTime)?.Value, out var seconds) ? DateTimeOffset.FromUnixTimeSeconds(seconds) : null;
}
