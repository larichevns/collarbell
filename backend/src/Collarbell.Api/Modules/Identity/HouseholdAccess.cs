namespace Collarbell.Api.Modules.Identity;

/// <summary>
/// Who in the household may call an endpoint (spec, "Семья"). Without a mark: everyone may read (GET), and only owners
/// and members may change things, so a new endpoint is closed to helpers until it says otherwise.
/// </summary>
public enum HouseholdAccessRule
{
    /// <summary>Helpers too: their marks (fed, "Done", a visit took place, bought).</summary>
    Helpers,

    /// <summary>Owners only: the people of the household and its settings.</summary>
    Owners,

    /// <summary>
    /// The user's own things, whatever the household: their profile, phone, notification settings, households and
    /// invites. Everyone may call it, and a household they're no longer in doesn't stop it: it answers from the first
    /// household, so the app can see where it is and move there.
    /// </summary>
    Personal,
}

public sealed record HouseholdAccess(HouseholdAccessRule Rule)
{
    /// <summary>Whether <paramref name="role"/> may call an endpoint with this mark (null: none) by <paramref name="method"/>.</summary>
    public static bool Allows(HouseholdAccess? access, HouseholdRole role, string method) => access?.Rule switch
    {
        HouseholdAccessRule.Owners => role == HouseholdRole.Owner,
        HouseholdAccessRule.Helpers or HouseholdAccessRule.Personal => true,
        _ => HttpMethods.IsGet(method) || HttpMethods.IsHead(method) || role != HouseholdRole.Helper,
    };
}

public static class HouseholdAccessExtensions
{
    /// <summary>Helpers may call it too (see <see cref="HouseholdAccessRule.Helpers"/>).</summary>
    public static TBuilder AllowHelpers<TBuilder>(this TBuilder builder) where TBuilder : IEndpointConventionBuilder =>
        builder.WithMetadata(new HouseholdAccess(HouseholdAccessRule.Helpers));

    /// <summary>Only the household's owners may call it.</summary>
    public static TBuilder OwnersOnly<TBuilder>(this TBuilder builder) where TBuilder : IEndpointConventionBuilder =>
        builder.WithMetadata(new HouseholdAccess(HouseholdAccessRule.Owners));

    /// <summary>The user's own things (see <see cref="HouseholdAccessRule.Personal"/>).</summary>
    public static TBuilder Personal<TBuilder>(this TBuilder builder) where TBuilder : IEndpointConventionBuilder =>
        builder.WithMetadata(new HouseholdAccess(HouseholdAccessRule.Personal));
}

/// <summary>
/// The <c>type</c> of the household endpoints' problems: the app tells them apart by it and says them in its own
/// words, in the user's language.
/// </summary>
public static class HouseholdProblems
{
    /// <summary>The request names a household the user isn't in (they left or were removed): the app moves to another.</summary>
    public const string NotAMember = "urn:collarbell:problem:not-a-household-member";

    /// <summary>The user's role in the household can't do this (a helper changing a pet, a member inviting).</summary>
    public const string RoleForbidden = "urn:collarbell:problem:role-forbidden";

    public const string AlreadyMember = "urn:collarbell:problem:already-a-member";

    /// <summary>In the most households one person can be in.</summary>
    public const string HouseholdLimit = "urn:collarbell:problem:household-limit";

    /// <summary>The most open invites of one household.</summary>
    public const string InviteLimit = "urn:collarbell:problem:invite-limit";

    /// <summary>The household would be left without an owner.</summary>
    public const string LastOwner = "urn:collarbell:problem:last-owner";

    /// <summary>Only an empty household of one can be deleted.</summary>
    public const string NotEmpty = "urn:collarbell:problem:household-not-empty";

    public static IResult RoleCantDoThis() =>
        TypedResults.Problem(statusCode: StatusCodes.Status403Forbidden, title: "Your role in this household can't do this.",
            type: RoleForbidden);
}

/// <summary>
/// Runs before every <c>/api/v1</c> endpoint: finds the user's household for the request and checks their role there.
/// 403 when the request names a household they aren't in, or when their role may not do this; 401 for the token of a
/// deleted account.
/// </summary>
public sealed class HouseholdAccessFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        var access = http.GetEndpoint()?.Metadata.GetMetadata<HouseholdAccess>();
        var accessor = http.RequestServices.GetRequiredService<CurrentUserAccessor>();
        accessor.AnyHouseholdWillDo = access?.Rule == HouseholdAccessRule.Personal;

        CurrentUser me;
        try
        {
            me = await accessor.GetAsync(http.RequestAborted);
        }
        catch (NotAHouseholdMemberException)
        {
            return TypedResults.Problem(statusCode: StatusCodes.Status403Forbidden, title: "You aren't in this household.",
                type: HouseholdProblems.NotAMember);
        }
        catch (AccountDeletedException)
        {
            return AccountProblems.AccountDeleted();
        }

        return HouseholdAccess.Allows(access, me.Role, http.Request.Method)
            ? await next(context)
            : HouseholdProblems.RoleCantDoThis();
    }
}
