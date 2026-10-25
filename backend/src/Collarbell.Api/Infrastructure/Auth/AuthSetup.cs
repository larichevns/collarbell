using Microsoft.AspNetCore.Authentication;
using Microsoft.IdentityModel.Tokens;

namespace Collarbell.Api.Infrastructure.Auth;

public static class AuthSetup
{
    public const string FirebaseScheme = "Firebase";
    public const string DevUserScheme = "DevUser";
    public const string LiveTicketScheme = "LiveTicket";
    private const string SelectorScheme = "FirebaseOrDevUser";

    /// <summary>Where the hubs are: only there a ticket in the address signs a connection in (<see cref="LiveTickets"/>).</summary>
    private const string HubsPath = "/hubs";

    /// <summary>
    /// Firebase ID tokens (JWT) in every environment. In Development and Testing, when
    /// <c>Auth:DevUsers:Enabled</c> is true, an <c>X-Dev-User</c> header signs in a local dev user
    /// so the app can run before a Firebase project exists. That scheme is never registered elsewhere.
    /// </summary>
    public static IServiceCollection AddCollarbellAuth(this IServiceCollection services, IConfiguration config, IHostEnvironment env)
    {
        var projectId = config["Firebase:ProjectId"];
        var devUsersEnabled = config.GetValue<bool>("Auth:DevUsers:Enabled")
            && (env.IsDevelopment() || env.IsEnvironment("Testing"));

        var auth = services
            .AddAuthentication(SelectorScheme)
            .AddPolicyScheme(SelectorScheme, "Firebase, a live ticket or a dev user", o =>
                o.ForwardDefaultSelector = ctx =>
                    devUsersEnabled && ctx.Request.Headers.ContainsKey(DevUserAuthenticationHandler.UserHeader)
                        ? DevUserScheme
                        : ctx.Request.Path.StartsWithSegments(HubsPath) && ctx.Request.Query.ContainsKey(LiveTicketAuthenticationHandler.QueryKey)
                            ? LiveTicketScheme
                            : FirebaseScheme)
            .AddScheme<AuthenticationSchemeOptions, LiveTicketAuthenticationHandler>(LiveTicketScheme, null)
            .AddJwtBearer(FirebaseScheme, o =>
            {
                o.MapInboundClaims = false;
                if (string.IsNullOrWhiteSpace(projectId))
                {
                    // No Firebase project configured: no signing keys, so every bearer token is rejected.
                    return;
                }

                o.Authority = $"https://securetoken.google.com/{projectId}";
                o.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = $"https://securetoken.google.com/{projectId}",
                    ValidateAudience = true,
                    ValidAudience = projectId,
                    ValidateLifetime = true,
                };
            });

        if (devUsersEnabled)
        {
            auth.AddScheme<AuthenticationSchemeOptions, DevUserAuthenticationHandler>(DevUserScheme, null);
        }

        services.AddSingleton<LiveTickets>();
        services.AddAuthorization();
        return services;
    }
}
