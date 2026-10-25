using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Identity;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Billing;

/// <summary>
/// The household's plan, for the "Тариф" screen: Free or Premium (and until when), this month's AI photos against the
/// plan's limit, the day the count starts again, and how many Premium allows, to tell about it.
/// </summary>
/// <param name="Source">Who gave the Premium; null for Free.</param>
/// <param name="ExpiresAt">Premium's end; null: no end (or Free).</param>
/// <param name="AiPhotosUsed">The household's photos this month under its plan: read, and being read right now.</param>
/// <param name="ResetsAt">When the count starts again: the next month's first moment in UTC (show its local date).</param>
public sealed record PlanResponse(
    PlanKind Plan,
    PlanSource? Source,
    DateTimeOffset? ExpiresAt,
    int AiPhotosPerMonth,
    int AiPhotosUsed,
    DateTimeOffset ResetsAt,
    int PremiumAiPhotosPerMonth);

public static class PlanEndpoints
{
    public static RouteGroupBuilder MapPlanEndpoints(this RouteGroupBuilder api)
    {
        api.MapGet("/plan", Get)
            .WithTags("Plan")
            .WithName("GetPlan")
            .WithSummary("The household's plan (Free or Premium), this month's AI photos and the limit. Premium is given by hand for now; there are no payments yet.");

        return api;
    }

    private static async Task<Ok<PlanResponse>> Get(CurrentUserAccessor current, Plans plans, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var plan = await plans.OfAsync(me.HouseholdId, ct);
        return TypedResults.Ok(new PlanResponse(
            plan.Plan,
            plan.Source,
            plan.ExpiresAt,
            plan.AiPhotosPerMonth,
            await plans.AiPhotosUsedAsync(me.HouseholdId, ct),
            plans.Month().ResetsAt,
            plans.PremiumAiPhotosPerMonth));
    }
}

/// <summary>The household's plan, for "Download my data".</summary>
public sealed class PlanExport(Plans plans) : IHouseholdExportSource
{
    public async Task ExportAsync(HouseholdExport export, CancellationToken ct)
    {
        var plan = await plans.OfAsync(export.HouseholdId, ct);
        export.Add("plan", new { plan.Plan, plan.ExpiresAt, plan.AiPhotosPerMonth });
    }
}

/// <summary>The AI photos the person used, in every household, for "Download my data".</summary>
public sealed class AiPhotosExport(AppDbContext db) : IPersonalExportSource
{
    public async Task ExportAsync(PersonalExport export, CancellationToken ct) =>
        export.Add("aiPhotos", await db.AiPhotoCharges.AsNoTracking()
            .Where(c => c.UserId == export.UserId)
            .OrderBy(c => c.CreatedAt)
            .Select(c => new { c.CreatedAt, c.Feature, c.Photos, c.Plan, c.State, c.SettledAt, Household = c.HouseholdId })
            .ToListAsync(ct));
}
