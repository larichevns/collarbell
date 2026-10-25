using System.Globalization;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Infrastructure.Auth;

/// <summary>Signs in a local developer from headers. Registered only in Development and Testing.</summary>
public sealed partial class DevUserAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string UserHeader = "X-Dev-User";
    public const string EmailHeader = "X-Dev-Email";

    /// <summary>When the dev user "typed their password" (seconds since 1970); without it, just now.</summary>
    public const string AuthTimeHeader = "X-Dev-Auth-Time";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var uid = Request.Headers[UserHeader].ToString();
        if (string.IsNullOrWhiteSpace(uid))
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        if (!ValidUid().IsMatch(uid))
        {
            return Task.FromResult(AuthenticateResult.Fail($"{UserHeader} must be 1–64 characters: letters, digits, '.', '_' or '-'."));
        }

        // Prefixed so a dev subject can never collide with a real Firebase uid.
        var claims = new List<Claim> { new(CollarbellClaims.Subject, $"dev:{uid}") };
        var email = Request.Headers[EmailHeader].ToString();
        if (!string.IsNullOrWhiteSpace(email))
        {
            claims.Add(new Claim(CollarbellClaims.Email, email.Trim()));
        }

        // A dev user has no password to confirm: they signed in "just now", unless a test says otherwise.
        var authTime = Request.Headers[AuthTimeHeader].ToString();
        claims.Add(new Claim(CollarbellClaims.AuthTime, long.TryParse(authTime, out var seconds)
            ? seconds.ToString(CultureInfo.InvariantCulture)
            : TimeProvider.GetUtcNow().ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)));

        var identity = new ClaimsIdentity(claims, Scheme.Name, CollarbellClaims.Subject, "role");
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }

    [GeneratedRegex("^[A-Za-z0-9._-]{1,64}$")]
    private static partial Regex ValidUid();
}
