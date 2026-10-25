using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.Extensions.AI;

namespace Collarbell.Api.Modules.Ai;

/// <summary>
/// Read photos of a passport page or a microchip sticker with AI (1 to <see cref="IdentifierScanEndpoints.MaxPhotos"/>),
/// for the pet form: the app sends them when the phone found no barcode in the photo.
/// </summary>
public sealed record IdentifierScanRequest(List<Guid> FileIds);

/// <summary>The numbers read, in the order the model gave them; empty when there is none. <see cref="Model"/> is the one that answered.</summary>
public sealed record IdentifierScanResponse(List<IdentifierReading> Identifiers, string Model);

public static class IdentifierScanEndpoints
{
    public const int MaxPhotos = 3;

    public static RouteGroupBuilder MapIdentifierScanEndpoints(this RouteGroupBuilder api)
    {
        api.MapPost("/pets/identifiers/scan", Scan)
            .RequireRateLimiting(AiEndpoints.RateLimit)
            .ReportsChanges(LiveTopics.Plan)
            .WithTags("Pets")
            .WithName("ScanPetIdentifiers")
            .WithSummary("Read the microchip and tattoo numbers on photos of a passport page or a chip sticker with AI, to fill in the pet form; nothing is saved. Waits for the answer (up to a few minutes). 409 urn:collarbell:problem:ai-limit: not enough AI photos left this month; 409 without a type: AI isn't set up; 429: too many AI requests in a minute; 503: all models are busy.")
            .ProducesProblem(StatusCodes.Status409Conflict)
            .ProducesProblem(StatusCodes.Status429TooManyRequests)
            .ProducesProblem(StatusCodes.Status502BadGateway)
            .ProducesProblem(StatusCodes.Status503ServiceUnavailable);

        return api;
    }

    /// <summary>
    /// Reads at once, like photos of a package (<c>POST /products/scan</c>): one page, a few seconds, and nothing to
    /// lose when it fails, the user takes the photo again or types the number. The photos aren't kept: unattached
    /// uploads are deleted after a day.
    /// </summary>
    private static async Task<Results<Ok<IdentifierScanResponse>, ValidationProblem, ProblemHttpResult>> Scan(
        IdentifierScanRequest request,
        CurrentUserAccessor current,
        Files files,
        AiRunner runner,
        Plans plans,
        TimeProvider clock,
        ILoggerFactory loggers,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!runner.IsConfigured(AiOptions.Extraction))
        {
            return TypedResults.Problem(statusCode: StatusCodes.Status409Conflict, title: "AI isn't set up.",
                detail: "Add an AI model on the server (Ai settings) to read photos.");
        }

        var errors = new ValidationErrors();
        if (request.FileIds is null || request.FileIds.Count is 0 or > MaxPhotos)
        {
            errors.Add("fileIds", $"Add 1 to {MaxPhotos} photos.");
        }
        else if (await files.CheckFreeAsync(me.HouseholdId, request.FileIds, photosOnly: true, ct) is { } problem)
        {
            errors.Add("fileIds", problem);
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        // The month's AI photos are held before AI reads them: charged if it answers, given back if not (Billing/Plans).
        var (hold, refusal) = await plans.HoldAsync(me.HouseholdId, me.UserId, request.FileIds!.Count, "identifier-scan", ct);
        if (hold is not { } holdId)
        {
            return refusal!;
        }

        var log = loggers.CreateLogger("Collarbell.Api.Modules.Ai.IdentifierScan");
        var answered = false;
        try
        {
            var photos = await files.ReadAsync(me.HouseholdId, request.FileIds!, ct);
            if (photos.Count < request.FileIds!.Count)
            {
                return TypedResults.ValidationProblem(new Dictionary<string, string[]> { ["fileIds"] = ["The photos are gone; take them again."] });
            }

            var message = new ChatMessage(ChatRole.User,
            [
                new TextContent(IdentifierScanPrompt.Text),
                .. photos.Select(p => (AIContent)new DataContent(p.Content, p.File.ContentType)),
            ]);
            var scan = await runner.RunAsync<IdentifierScan>(AiOptions.Extraction, "identifier-scan", me.HouseholdId, [message], ct);
            answered = true;
            return TypedResults.Ok(new IdentifierScanResponse(
                IdentifierReadings.From(scan.Value, Input.LatestToday(clock)), scan.Model.Model));
        }
        catch (AiUnavailableException e) when (e.NotConfigured)
        {
            return TypedResults.Problem(statusCode: StatusCodes.Status409Conflict, title: "AI isn't set up.");
        }
        catch (AiUnavailableException e)
        {
            // The provider's words stay in the log: they may name the project or internal addresses.
            log.LogWarning(e, "Identifier scan: no AI model could answer.");
            return TypedResults.Problem(statusCode: StatusCodes.Status503ServiceUnavailable, title: "All AI models are busy; try again later.");
        }
        catch (AiRejectedException e)
        {
            log.LogError(e, "Identifier scan: the AI provider refused the request.");
            return TypedResults.Problem(statusCode: StatusCodes.Status502BadGateway, title: "The AI provider refused the request.");
        }
        finally
        {
            await plans.SettleAsync(holdId, answered, CancellationToken.None);
        }
    }
}
