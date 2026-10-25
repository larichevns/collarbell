using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Live;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;

namespace Collarbell.Api.Modules.Identity;

/// <param name="Household">The household of this request (the X-Household header, else the first one).</param>
/// <param name="Households">Every household the user is in, the first-joined first.</param>
public sealed record MeResponse(
    Guid Id,
    string? Email,
    string? DisplayName,
    string Locale,
    string TimeZone,
    HouseholdResponse Household,
    List<HouseholdSummary> Households);

/// <param name="Role">The user's role in this household.</param>
public sealed record HouseholdResponse(Guid Id, string Name, string TimeZone, HouseholdRole Role);

/// <summary>Only the fields that are sent change.</summary>
public sealed record UpdateMeRequest(string? DisplayName, string? Locale, string? TimeZone);

public static class MeEndpoints
{
    private const int MaxDisplayNameLength = 100;

    public static RouteGroupBuilder MapMeEndpoints(this RouteGroupBuilder api)
    {
        var me = api.MapGroup("/me").WithTags("Me");

        me.MapGet("", GetMe)
            .Personal()
            .WithName("GetMe")
            .WithSummary("The signed-in user, the household of this request and all their households. The first call creates the user and a household.");

        me.MapPut("", UpdateMe)
            .Personal()
            .WithName("UpdateMe")
            .WithSummary("Change the display name, language or time zone.");

        me.MapGet("/deletion", GetDeletion)
            .Personal()
            .WithName("GetAccountDeletion")
            .WithSummary("What deleting the account would do to each household: deleted with everything in it, kept by the others, or handed over to a member.");

        // Signals the households it leaves by itself (LiveChanges.LeftAsync): the one of the request may be gone.
        me.MapDelete("", DeleteMe)
            .Personal()
            .WithName("DeleteMe")
            .WithSummary("Delete the account, its sign-in and the households nobody else would keep, if the households' fates are still the plan from GET /me/deletion (else 409 deletion-plan-changed). Needs a sign-in in the last 5 minutes: 403 recent-sign-in-required.");

        me.MapGet("/export", Export)
            .Personal()
            .RequireRateLimiting(AccountExport.RateLimit)
            .WithName("ExportMe")
            .WithSummary("Everything of the user's as a ZIP: account.json, and each household's household.json with its photos and scans.")
            // A ZIP described in place: a named schema would become a "Stream" type in the app's generated client.
            .AddOpenApiOperationTransformer((operation, _, _) =>
            {
                operation.Responses ??= [];
                operation.Responses["200"] = new OpenApiResponse
                {
                    Description = "The ZIP archive.",
                    Content = new Dictionary<string, OpenApiMediaType>
                    {
                        ["application/zip"] = new() { Schema = new OpenApiSchema { Type = JsonSchemaType.String, Format = "binary" } },
                    },
                };
                return Task.CompletedTask;
            });

        return api;
    }

    private static async Task<Ok<AccountDeletionPreview>> GetDeletion(
        CurrentUserAccessor current, AccountDeletion deletion, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        return TypedResults.Ok(await deletion.PreviewAsync(me.UserId, ct));
    }

    /// <summary>
    /// Asks for a fresh sign-in, as Firebase does before deleting its own account: someone holding an unlocked phone
    /// can't delete the account without its password.
    /// </summary>
    /// <param name="plan">The <see cref="AccountDeletionPreview.Plan"/> the person was shown.</param>
    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteMe(
        [FromQuery] string plan, CurrentUserAccessor current, AccountDeletion deletion, HttpContext http, TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (http.User.GetAuthTime() is not { } signedInAt || clock.GetUtcNow() - signedInAt > AccountDeletion.RecentSignIn)
        {
            return TypedResults.Problem(statusCode: StatusCodes.Status403Forbidden,
                title: "Type your password again to delete the account.", type: AccountProblems.RecentSignInRequired);
        }

        var (result, _) = await deletion.DeleteAsync(me.UserId, plan, ct);
        if (result == DeletionResult.PlanChanged)
        {
            return TypedResults.Problem(statusCode: StatusCodes.Status409Conflict,
                title: "Your households changed: look again at what happens to them.", type: AccountProblems.PlanChanged);
        }

        current.Forget();
        return TypedResults.NoContent();
    }

    private static async Task<IResult> Export(
        CurrentUserAccessor current, AccountExport export, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        return Results.Stream(body => export.WriteAsync(me.UserId, body, ct), "application/zip",
            AccountExport.FileName(clock.GetUtcNow()));
    }

    private static async Task<Ok<MeResponse>> GetMe(CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        return TypedResults.Ok(await LoadAsync(db, me, ct));
    }

    private static async Task<Results<Ok<MeResponse>, ValidationProblem>> UpdateMe(
        UpdateMeRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        IEnumerable<IHouseholdChangeHandler> listeners,
        LiveChanges live,
        HttpRequest http,
        CancellationToken ct)
    {
        var errors = Validate(request);
        if (errors.Count > 0)
        {
            return TypedResults.ValidationProblem(errors);
        }

        var me = await current.GetAsync(ct);
        var user = await db.Users.SingleAsync(u => u.Id == me.UserId, ct);
        var nameBefore = user.DisplayName;

        if (request.DisplayName is not null)
        {
            var name = request.DisplayName.Trim();
            user.DisplayName = name.Length > 0 ? name : null;
        }

        if (request.Locale is not null)
        {
            user.Locale = request.Locale;
        }

        var householdTimeZoneChanged = false;
        if (request.TimeZone is not null)
        {
            user.TimeZone = request.TimeZone;

            // A household of one follows the time zone of its owner's phone. One whose time zone an owner set in its
            // settings (PUT /households/current), or that others share, stays where it is when someone travels.
            if (me.Role == HouseholdRole.Owner)
            {
                var household = await db.Households.SingleAsync(h => h.Id == me.HouseholdId, ct);
                var alone = await db.HouseholdMembers.CountAsync(m => m.HouseholdId == me.HouseholdId, ct) == 1;
                if (alone && !household.TimeZoneSetByHand)
                {
                    householdTimeZoneChanged = household.TimeZone != request.TimeZone;
                    household.TimeZone = request.TimeZone;
                }
            }
        }

        await db.SaveChangesAsync(ct);

        // Feeding at 08:00 is 08:00 in the new time zone: the reminders move with it.
        if (householdTimeZoneChanged)
        {
            foreach (var listener in listeners)
            {
                await listener.HouseholdChangedAsync(me.HouseholdId, ct);
            }
        }

        // The app sends its profile on every start: only a new name is news, for the members lists and the marks of
        // every household the user is in.
        if (user.DisplayName != nameBefore)
        {
            var households = await db.HouseholdMembers.Where(m => m.UserId == me.UserId).Select(m => m.HouseholdId).ToListAsync(ct);
            var origin = LiveChanges.Origin(http.Headers[LiveChanges.ClientHeader]);
            foreach (var householdId in households)
            {
                await live.ChangedAsync(householdId, [LiveTopics.Household], me.UserId, origin);
            }
        }

        return TypedResults.Ok(await LoadAsync(db, me, ct));
    }

    private static async Task<MeResponse> LoadAsync(AppDbContext db, CurrentUser me, CancellationToken ct)
    {
        var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == me.UserId, ct);
        var household = await db.Households.AsNoTracking().SingleAsync(h => h.Id == me.HouseholdId, ct);
        return new MeResponse(user.Id, user.Email, user.DisplayName, user.Locale, user.TimeZone,
            new HouseholdResponse(household.Id, household.Name, household.TimeZone, me.Role),
            await HouseholdsEndpoints.SummariesAsync(db, me.UserId, ct));
    }

    private static Dictionary<string, string[]> Validate(UpdateMeRequest request)
    {
        var errors = new Dictionary<string, string[]>();

        if (request.DisplayName is { Length: > MaxDisplayNameLength })
        {
            errors["displayName"] = [$"Use {MaxDisplayNameLength} characters or fewer."];
        }

        if (request.Locale is not null && !Locales.Supported.Contains(request.Locale))
        {
            errors["locale"] = [$"Use one of: {string.Join(", ", Locales.Supported)}."];
        }

        if (request.TimeZone is not null && !IsIanaTimeZone(request.TimeZone))
        {
            errors["timeZone"] = ["Use an IANA time zone such as Europe/Berlin."];
        }

        return errors;
    }

    internal static bool IsIanaTimeZone(string id) =>
        id.Length <= 64
        && (id == "UTC" || id.Contains('/'))
        && LocalTimes.IsKnownZone(id);
}
