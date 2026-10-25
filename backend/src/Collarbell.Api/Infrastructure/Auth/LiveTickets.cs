using System.Buffers.Text;
using System.Collections.Concurrent;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Infrastructure.Auth;

/// <summary>
/// One-time tickets into the live updates' hub for the web app. A browser's WebSocket can't send the Authorization header
/// the phone sends, so the web app asks for a ticket first, signed in as usual, and opens the hub with it in the address.
/// A sign-in token there would stay in the servers' access logs for the hour it is valid; a ticket works once, within a
/// minute. The API runs as one instance, so the tickets live in its memory.
/// </summary>
public sealed class LiveTickets(TimeProvider clock)
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(1);

    /// <summary>A browser needs one per connection it opens; more waiting at once are a script's.</summary>
    public const int MaxPerPerson = 10;

    private readonly ConcurrentDictionary<string, (string Subject, DateTimeOffset ExpiresAt)> _tickets = new();
    private readonly Lock _lock = new();

    /// <summary>A new ticket for the person with this sign-in subject; null while they have <see cref="MaxPerPerson"/> unused.</summary>
    public (string Ticket, DateTimeOffset ExpiresAt)? Issue(string subject)
    {
        var now = clock.GetUtcNow();
        lock (_lock)
        {
            foreach (var (key, old) in _tickets)
            {
                if (old.ExpiresAt <= now)
                {
                    _tickets.TryRemove(key, out _);
                }
            }

            if (_tickets.Values.Count(t => t.Subject == subject) >= MaxPerPerson)
            {
                return null;
            }

            var ticket = Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(32));
            var expiresAt = now + Lifetime;
            _tickets[ticket] = (subject, expiresAt);
            return (ticket, expiresAt);
        }
    }

    /// <summary>The sign-in subject the ticket was given to; null when it is unknown, used or expired. Works once.</summary>
    public string? Redeem(string ticket) =>
        _tickets.TryRemove(ticket, out var issued) && issued.ExpiresAt > clock.GetUtcNow() ? issued.Subject : null;
}

/// <summary>Signs in a hub connection with a <see cref="LiveTickets"/> ticket, given as <c>access_token</c> in its address.</summary>
public sealed class LiveTicketAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    LiveTickets tickets) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    /// <summary>Where SignalR's browser client puts what its access token factory gives: the ticket.</summary>
    public const string QueryKey = "access_token";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var ticket = Request.Query[QueryKey].ToString();
        if (string.IsNullOrEmpty(ticket))
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        if (tickets.Redeem(ticket) is not { } subject)
        {
            return Task.FromResult(AuthenticateResult.Fail("The ticket is unknown, used or expired."));
        }

        var identity = new ClaimsIdentity([new Claim(CollarbellClaims.Subject, subject)], Scheme.Name, CollarbellClaims.Subject, "role");
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name)));
    }
}
