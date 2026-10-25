using System.Diagnostics;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Options;
using SkiaSharp;

namespace Collarbell.Api.Modules.Ai;

public sealed record AiModelInfo(AiProvider Provider, string Model, bool Ready);

public sealed record AiUsageSummary(int Requests, long InputTokens, long OutputTokens);

/// <summary>
/// The AI screen: which models read the photos, whether they are set up, this month's use, and whether the
/// free tier is used (then Google may use what is sent to improve its products).
/// </summary>
public sealed record AiStatusResponse(bool Configured, List<AiModelInfo> Models, bool FreeTier, AiUsageSummary ThisMonth);

/// <summary>Why the connection test failed, for the app to explain in the user's language.</summary>
[System.Text.Json.Serialization.JsonConverter(typeof(System.Text.Json.Serialization.JsonStringEnumConverter<AiTestProblem>))]
public enum AiTestProblem
{
    /// <summary>No AI model is set up on the server.</summary>
    NotConfigured,

    /// <summary>All models are busy or out of free quota right now.</summary>
    Busy,

    /// <summary>The provider refused the request (for example the key is wrong).</summary>
    Rejected,

    /// <summary>A model answered but didn't see the picture.</summary>
    WrongAnswer,
}

/// <summary>The connection test's result. Provider messages stay in the server log: they can show internal details.</summary>
public sealed record AiTestResponse(bool Ok, string? Model, int LatencyMs, AiTestProblem? Problem);

/// <summary>The answer to the connection test: the colour of a square on a small picture.</summary>
public sealed record ColourCheck(string? Colour);

public static class AiEndpoints
{
    /// <summary>
    /// Every request that reads photos with AI (here, /ai-imports, /pets/identifiers/scan, /products/scan): 10 a minute
    /// per person, to spare the server's AI key. The month's limit is counted apart, by the plan (Billing/Plans).
    /// </summary>
    public const string RateLimit = "ai";

    public static RouteGroupBuilder MapAiEndpoints(this RouteGroupBuilder api)
    {
        var ai = api.MapGroup("/ai").WithTags("AI");

        ai.MapGet("/status", GetStatus)
            .WithName("GetAiStatus")
            .WithSummary("Which AI models read photos, whether they are set up, and this month's use by the household.");

        ai.MapPost("/test", Test)
            .RequireRateLimiting(RateLimit)
            .ReportsChanges(LiveTopics.Plan)
            .WithName("TestAi")
            .WithSummary("Check that a model answers and can see a picture. The picture counts as one of the month's AI photos; 409 urn:collarbell:problem:ai-limit: none left; 429: too many AI requests in a minute.")
            .ProducesProblem(StatusCodes.Status409Conflict)
            .ProducesProblem(StatusCodes.Status429TooManyRequests);

        return api;
    }

    private static async Task<Ok<AiStatusResponse>> GetStatus(
        CurrentUserAccessor current,
        AppDbContext db,
        AiRunner runner,
        IAiChatClientFactory clients,
        IOptions<AiOptions> options,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var models = runner.Models(AiOptions.Extraction)
            .Select(m => new AiModelInfo(m.Provider, m.Model, clients.IsConfigured(m)))
            .ToList();

        var now = clock.GetUtcNow();
        var monthStart = new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero);
        var month = await db.AiUsage.AsNoTracking()
            .Where(u => u.HouseholdId == me.HouseholdId && u.CreatedAt >= monthStart)
            .GroupBy(_ => 1)
            .Select(g => new AiUsageSummary(g.Count(), g.Sum(u => u.InputTokens ?? 0), g.Sum(u => u.OutputTokens ?? 0)))
            .SingleOrDefaultAsync(ct);

        return TypedResults.Ok(new AiStatusResponse(
            models.Any(m => m.Ready),
            models,
            options.Value.Gemini.FreeTier && models.Any(m => m.Ready && m.Provider == AiProvider.Gemini),
            month ?? new AiUsageSummary(0, 0, 0)));
    }

    private static async Task<Results<Ok<AiTestResponse>, ProblemHttpResult>> Test(
        CurrentUserAccessor current, AiRunner runner, Plans plans, ILogger<AiRunner> log, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        // Its picture is one of the month's AI photos: held now, charged if a model answers (Billing/Plans).
        var (hold, refusal) = await plans.HoldAsync(me.HouseholdId, me.UserId, 1, "connection-test", ct);
        if (hold is not { } holdId)
        {
            return refusal!;
        }

        var answered = false;
        var watch = Stopwatch.StartNew();
        try
        {
            var message = new ChatMessage(ChatRole.User,
            [
                new TextContent("What colour is the square in the picture? Answer with one English word."),
                new DataContent(GreenSquare(), "image/png"),
            ]);
            var answer = await runner.RunAsync<ColourCheck>(AiOptions.Extraction, "connection-test", me.HouseholdId, [message], ct);
            answered = true;
            var sawIt = answer.Value.Colour?.Contains("green", StringComparison.OrdinalIgnoreCase) == true;
            return TypedResults.Ok(new AiTestResponse(
                sawIt, answer.Model.Model, (int)watch.ElapsedMilliseconds, sawIt ? null : AiTestProblem.WrongAnswer));
        }
        catch (Exception e) when (e is AiUnavailableException or AiRejectedException)
        {
            log.LogWarning(e, "AI connection test failed.");
            var problem = e is AiUnavailableException { NotConfigured: true } ? AiTestProblem.NotConfigured
                : e is AiUnavailableException ? AiTestProblem.Busy
                : AiTestProblem.Rejected;
            return TypedResults.Ok(new AiTestResponse(false, null, (int)watch.ElapsedMilliseconds, problem));
        }
        finally
        {
            await plans.SettleAsync(holdId, answered, CancellationToken.None);
        }
    }

    private static byte[] GreenSquare()
    {
        using var bitmap = new SKBitmap(64, 64);
        using (var canvas = new SKCanvas(bitmap))
        {
            canvas.Clear(SKColors.White);
            using var paint = new SKPaint { Color = SKColors.Green };
            canvas.DrawRect(12, 12, 40, 40, paint);
        }

        using var image = SKImage.FromBitmap(bitmap);
        using var png = image.Encode(SKEncodedImageFormat.Png, 100);
        return png.ToArray();
    }
}
