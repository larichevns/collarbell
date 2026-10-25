using System.Text.Json;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Collarbell.Api.Modules.Ai;

/// <summary>
/// Read uploaded photos with AI, or a note (<see cref="AiImportSource.Text"/>: <see cref="Text"/> and no photos).
/// <see cref="RequestId"/>: a new id per scan the app starts, the same on retries. <see cref="RetryOf"/>: the failed
/// scan or note this reads again ("Try again"): it gives way to the new one, whoever started it, and a note read again
/// keeps the day it was written, which its "yesterday" is counted from.
/// </summary>
public sealed record CreateAiImportRequest(
    Guid PetId, AiImportSource Source, List<Guid> FileIds, Guid? RequestId, string? Text = null, Guid? RetryOf = null);

/// <summary>A scan: its status, the photos, and the draft once it is ready (or what went wrong).</summary>
public sealed record AiImportResponse(
    Guid Id,
    Guid PetId,
    AiImportSource Source,
    AiImportStatus Status,
    List<FileLink> Pages,
    ImportDraft? Draft,
    AiImportError? Error,
    string? Model,
    DateTimeOffset CreatedAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? AppliedAt,
    ApplyImportResponse? Result,
    string? Text);

/// <summary>
/// What the user checked and kept: records as they would be added by hand, identifiers, passport header fields.
/// <see cref="KeepPhotos"/> keeps the photos as passport scans (or a document), even if the reading was wrong.
/// </summary>
public sealed record ApplyImportRequest(
    List<ImportedRecordRequest> Records,
    List<PetIdentifierRequest>? Identifiers,
    ApplyPassportRequest? Passport,
    bool KeepPhotos,
    List<ImportedWeightRequest>? Weights = null);

/// <summary>A weight to save as a weighing of the pet's log, checked like one added by hand.</summary>
public sealed record ImportedWeightRequest(DateOnly MeasuredOn, decimal WeightKg);

/// <summary>
/// One record to save. With <see cref="PlanId"/> it counts as a "Done" of that plan: the plan moves on when the
/// record is its newest news (see the draft's plan suggestion).
/// </summary>
public sealed record ImportedRecordRequest(CareRecordRequest Record, Guid? PlanId);

public sealed record ApplyPassportRequest(string? PassportNumber, string? IssuingCountry, DateOnly? IssuedOn);

public sealed record ApplyImportResponse(
    List<Guid> RecordIds, int PlansMoved, int IdentifiersAdded, bool PassportUpdated, Guid? DocumentId, int WeightsAdded = 0);

public static class AiImportsEndpoints
{
    private const int MaxPhotos = 10;
    private const int MaxRecords = 100;

    /// <summary>A note is a few sentences; a long text is pasted from somewhere else, and a scan suits it better.</summary>
    public const int MaxTextLength = 1000;

    /// <summary>429 with this type: the person had AI read <see cref="AiOptions.TextEntriesPerDay"/> notes in a day.</summary>
    public const string TextLimitProblemType = "urn:collarbell:problem:text-limit";

    public static RouteGroupBuilder MapAiImportsEndpoints(this RouteGroupBuilder api)
    {
        // A pet's scans waiting for someone show on its passport for everyone in the household.
        var imports = api.MapGroup("/ai-imports").WithTags("AI").ReportsChanges(LiveTopics.Imports);

        imports.MapPost("", Create)
            .RequireRateLimiting(AiEndpoints.RateLimit)
            .WithName("CreateAiImport")
            .WithSummary("Start reading uploaded photos of the passport (or a vet document), or a note, with AI. Poll the import until it is Ready. 409 urn:collarbell:problem:ai-limit: not enough AI photos left this month; 409 without a type: AI isn't set up; 429: too many AI requests in a minute, or with urn:collarbell:problem:text-limit too many notes today.")
            .ProducesProblem(StatusCodes.Status409Conflict)
            .ProducesProblem(StatusCodes.Status429TooManyRequests);

        imports.MapGet("/{id:guid}", Get)
            .WithName("GetAiImport")
            .WithSummary("The scan's status, photos and draft.");

        imports.MapPost("/{id:guid}/apply", Apply)
            .ReportsChanges(
                LiveTopics.Imports, LiveTopics.Care, LiveTopics.Passport, LiveTopics.Documents, LiveTopics.Pets, LiveTopics.Weight)
            .WithName("ApplyAiImport")
            .WithSummary("Save what the user checked: records, weighings, identifiers, passport fields, and the photos as scans.")
            .ProducesProblem(StatusCodes.Status409Conflict);

        imports.MapDelete("/{id:guid}", Discard)
            .WithName("DiscardAiImport")
            .WithSummary("Throw the scan away; its photos are deleted with other unused uploads after a day. A saved scan can't be thrown away (409): what it saved stays.")
            .ProducesProblem(StatusCodes.Status409Conflict);

        api.MapGet("/pets/{petId:guid}/ai-imports", ListForPet)
            .WithTags("AI")
            .WithName("ListPetAiImports")
            .WithSummary("The pet's scans still waiting for the user (being read, ready to check, or failed), newest first, to pick one up again. notes=true: notes only; notes=false: photo scans only; each kind has its own newest 20.");

        return api;
    }

    private static async Task<Results<Accepted<AiImportResponse>, NotFound, ValidationProblem, ProblemHttpResult>> Create(
        CreateAiImportRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        Files files,
        AiRunner runner,
        AiImportQueue queue,
        AiDrafts drafts,
        Plans plans,
        IOptions<AiOptions> options,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, request.PetId, ct))
        {
            return TypedResults.NotFound();
        }

        if (!runner.IsConfigured(AiOptions.Extraction))
        {
            return TypedResults.Problem(
                statusCode: StatusCodes.Status409Conflict,
                title: "AI isn't set up.",
                detail: "Add an AI model on the server (Ai settings) to read photos.");
        }

        if (request.RequestId is { } requestId && await FindByRequestAsync(db, me.HouseholdId, requestId, ct) is { } earlier)
        {
            return SameRequest(earlier, request) ? Accepted(await drafts.ToResponseAsync(earlier, ct)) : RequestIdUsed();
        }

        var errors = new ValidationErrors();
        if (!Enum.IsDefined(request.Source))
        {
            errors.Add("source", "Unknown kind of scan.");
        }

        var text = Input.Clean(request.Text);
        if (request.Source == AiImportSource.Text)
        {
            // Something to read: invisible characters alone would only spend a request.
            if (text is null || !text.Any(char.IsLetterOrDigit))
            {
                errors.Add("text", "Write what was done.");
            }

            errors.MaxLength("text", text, MaxTextLength);
            if (request.FileIds is { Count: > 0 })
            {
                errors.Add("fileIds", "A note has no photos.");
            }
        }
        // Photos only: the model reads images, and a PDF of many pages would be too big to send.
        else if (request.FileIds is null || request.FileIds.Count is 0 or > MaxPhotos)
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

        if (request.Source == AiImportSource.Text)
        {
            return await StartNoteAsync(request, text!, me, db, queue, drafts, plans, options.Value, clock, ct);
        }

        // The scan is made together with a hold on the month's AI photos, under the counting lock: scans started at
        // once are counted one after another. Its worker charges or releases the hold when the reading ends.
        async Task<(AiImport? Started, AiImport? Earlier, ProblemHttpResult? Refusal)> StartOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            await plans.LockCountingAsync(ct);

            // A retry that waited here for the first request answers with it.
            if (request.RequestId is { } sameRequest && await FindByRequestAsync(db, me.HouseholdId, sameRequest, ct) is { } first)
            {
                return (null, first, null);
            }

            var started = new AiImport(me.HouseholdId, request.PetId, request.Source, [.. request.FileIds!], me.UserId, clock.GetUtcNow())
            {
                ClientRequestId = request.RequestId,
            };
            var (hold, refusal) = await plans.TryHoldAsync(me.HouseholdId, me.UserId, started.FileIds.Count, "passport-scan", started.Id, ct);
            if (hold is null)
            {
                return (null, null, refusal);
            }

            db.AiImports.Add(started);
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return (started, null, null);
        }

        AiImport import;
        try
        {
            var (started, earlierOne, refused) = await db.Database.CreateExecutionStrategy().ExecuteAsync(StartOnce);
            if (refused is not null)
            {
                return refused;
            }

            if (earlierOne is not null)
            {
                return SameRequest(earlierOne, request) ? Accepted(await drafts.ToResponseAsync(earlierOne, ct)) : RequestIdUsed();
            }

            import = started!;
        }
        catch (DbUpdateException e) when (
            request.RequestId is { } sameRequest && e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // The same scan started twice at once by another way in (the lock above makes this rare): answer with the first.
            db.ChangeTracker.Clear();
            return Accepted(await drafts.ToResponseAsync((await FindByRequestAsync(db, me.HouseholdId, sameRequest, ct))!, ct));
        }

        // "Try again" after a failure is a new scan of the same photos: the failed one gives way to it.
        var photos = import.FileIds;
        await db.AiImports
            .Where(i => i.HouseholdId == me.HouseholdId && i.Id != import.Id && i.Status == AiImportStatus.Failed
                && (i.FileIds.Any(f => photos.Contains(f)) || i.Id == request.RetryOf))
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, AiImportStatus.Discarded).SetProperty(i => i.Text, (string?)null), ct);

        queue.Enqueue(import.Id);
        return Accepted(await drafts.ToResponseAsync(import, ct));
    }

    /// <summary>
    /// A note: no photos, so nothing of the month's count; a hold of no photos counts it among the
    /// <see cref="AiOptions.TextEntriesPerDay"/> notes a person may have read a day (<see cref="Plans.TryHoldNoteAsync"/>).
    /// </summary>
    private static async Task<Results<Accepted<AiImportResponse>, NotFound, ValidationProblem, ProblemHttpResult>> StartNoteAsync(
        CreateAiImportRequest request,
        string text,
        CurrentUser me,
        AppDbContext db,
        AiImportQueue queue,
        AiDrafts drafts,
        Plans plans,
        AiOptions options,
        TimeProvider clock,
        CancellationToken ct)
    {
        // Counted and held under the counting lock, in one transaction with the note: notes sent at once are counted
        // one after another, and a retry that waited here finds the first one.
        async Task<(AiImport? Started, AiImport? Earlier, bool OverTheLimit)> StartOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            await plans.LockCountingAsync(ct);
            if (request.RequestId is { } sameRequest && await FindByRequestAsync(db, me.HouseholdId, sameRequest, ct) is { } first)
            {
                return (null, first, false);
            }

            // Read again unchanged, the note is still the one written that day: "yesterday" means the day before it was
            // written. A note changed before it is read again is written now.
            var writtenAt = request.RetryOf is { } failedId
                ? await db.AiImports
                    .Where(i => i.Id == failedId && i.HouseholdId == me.HouseholdId && i.PetId == request.PetId
                        && i.Source == AiImportSource.Text && i.Status == AiImportStatus.Failed && i.Text == text)
                    .Select(i => (DateTimeOffset?)i.CreatedAt)
                    .SingleOrDefaultAsync(ct)
                : null;
            var started = new AiImport(me.HouseholdId, request.PetId, AiImportSource.Text, [], me.UserId, writtenAt ?? clock.GetUtcNow())
            {
                Text = text,
                PromptVersion = TextEntryPrompt.Version,
                ClientRequestId = request.RequestId,
            };
            if (await plans.TryHoldNoteAsync(me.HouseholdId, me.UserId, started.Id, options.TextEntriesPerDay, ct) is null)
            {
                return (null, null, true);
            }

            db.AiImports.Add(started);
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return (started, null, false);
        }

        AiImport import;
        try
        {
            var (started, earlier, overTheLimit) = await db.Database.CreateExecutionStrategy().ExecuteAsync(StartOnce);
            if (overTheLimit)
            {
                return TypedResults.Problem(
                    statusCode: StatusCodes.Status429TooManyRequests,
                    title: "AI has read enough of your notes for today.",
                    detail: $"Up to {options.TextEntriesPerDay} notes a day.",
                    type: TextLimitProblemType,
                    extensions: new Dictionary<string, object?> { ["limit"] = options.TextEntriesPerDay });
            }

            if (earlier is not null)
            {
                return SameRequest(earlier, request) ? Accepted(await drafts.ToResponseAsync(earlier, ct)) : RequestIdUsed();
            }

            import = started!;
        }
        catch (DbUpdateException e) when (
            request.RequestId is { } sameRequest && e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // The same note sent twice at once by another way in (the lock above makes this rare): answer with the first.
            db.ChangeTracker.Clear();
            return Accepted(await drafts.ToResponseAsync((await FindByRequestAsync(db, me.HouseholdId, sameRequest, ct))!, ct));
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException
            { SqlState: PostgresErrorCodes.ForeignKeyViolation, ConstraintName: var constraint })
        {
            // The household (deleted with its last owner's account) or the pet went while the note was on its way.
            return constraint == "fk_imports_households_household_id"
                ? TypedResults.Problem(statusCode: StatusCodes.Status403Forbidden, title: "You aren't in this household.",
                    type: HouseholdProblems.NotAMember)
                : TypedResults.NotFound();
        }

        // "Try again" after a failure is a new reading of the same note: the failed one gives way to it (the one named,
        // whoever wrote it, or the person's own with the same words) and forgets its text like any note thrown away.
        await db.AiImports
            .Where(i => i.HouseholdId == me.HouseholdId && i.PetId == import.PetId && i.Id != import.Id
                && i.Status == AiImportStatus.Failed && i.Source == AiImportSource.Text
                && (i.Id == request.RetryOf || (i.CreatedBy == me.UserId && i.Text == text)))
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, AiImportStatus.Discarded).SetProperty(i => i.Text, (string?)null), ct);

        queue.Enqueue(import.Id);
        return Accepted(await drafts.ToResponseAsync(import, ct));
    }

    private static async Task<Results<Ok<AiImportResponse>, NotFound>> Get(
        Guid id, CurrentUserAccessor current, AppDbContext db, AiDrafts drafts, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var import = await db.AiImports.AsNoTracking().SingleOrDefaultAsync(i => i.Id == id && i.HouseholdId == me.HouseholdId, ct);
        return import is null ? TypedResults.NotFound() : TypedResults.Ok(await drafts.ToResponseAsync(import, ct));
    }

    private static async Task<Results<Ok<List<AiImportResponse>>, NotFound>> ListForPet(
        Guid petId, bool? notes, CurrentUserAccessor current, AppDbContext db, PetDirectory pets, AiDrafts drafts, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        // Notes wait on the Health tab, scans on the Passport tab: many of one kind never push the other out of sight.
        var imports = await db.AiImports.AsNoTracking()
            .Where(i => i.HouseholdId == me.HouseholdId && i.PetId == petId && WaitingStatuses.Contains(i.Status))
            .Where(i => notes == null || (i.Source == AiImportSource.Text) == notes)
            .OrderByDescending(i => i.CreatedAt)
            .Take(20)
            .ToListAsync(ct);
        return TypedResults.Ok(await drafts.ToResponsesAsync(petId, imports, ct));
    }

    private static async Task<Results<Ok<ApplyImportResponse>, NotFound, ValidationProblem, ProblemHttpResult>> Apply(
        Guid id,
        ApplyImportRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        CareRecordsWriter care,
        PetIdentityWriter identity,
        PetWeights petWeights,
        PetDocuments documents,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);

        // One apply at a time per import: a double tap or a retry waits for the first one to finish and gets its
        // answer, so nothing is saved twice. If the connection drops, the strategy repeats the whole unit.
        async Task<Results<Ok<ApplyImportResponse>, NotFound, ValidationProblem, ProblemHttpResult>> ApplyOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var import = (await db.AiImports
                .FromSql($"SELECT * FROM ai.imports WHERE id = {id} AND household_id = {me.HouseholdId} FOR UPDATE")
                .ToListAsync(ct)).SingleOrDefault();
            if (import is null)
            {
                return TypedResults.NotFound();
            }

            // Applied already (a retry after a lost response): answer as the first time, save nothing.
            if (import.Status == AiImportStatus.Applied && import.ResultJson is { } earlier)
            {
                return TypedResults.Ok(JsonSerializer.Deserialize<ApplyImportResponse>(earlier, AiRunner.Json)!);
            }

            if (import.Status != AiImportStatus.Ready)
            {
                return TypedResults.Problem(statusCode: StatusCodes.Status409Conflict, title: "The draft isn't ready.");
            }

            var records = request.Records ?? [];
            var identifiers = request.Identifiers ?? [];
            var weights = request.Weights ?? [];
            var errors = new ValidationErrors();
            if (records.Count > MaxRecords)
            {
                errors.Add("records", $"Save {MaxRecords} records or fewer at once.");
            }

            if (weights.Count > MaxRecords)
            {
                errors.Add("weights", $"Save {MaxRecords} weights or fewer at once.");
            }

            var birth = weights.Count > 0 ? await petWeights.ExactBirthDateAsync(import.PetId, ct) : null;
            for (var i = 0; i < weights.Count; i++)
            {
                if (weights[i] is not { } weight)
                {
                    errors.Add($"weights[{i}]", "Add the weight.");
                    continue;
                }

                petWeights.Validate(weight.MeasuredOn, weight.WeightKg, birth, $"weights[{i}].", errors);
            }

            var links = new List<(string Field, CareRecordRequest Record, Guid PlanId)>();
            for (var i = 0; i < records.Count; i++)
            {
                if (records[i]?.Record is not { } record)
                {
                    errors.Add($"records[{i}].record", "Add the record.");
                    continue;
                }

                care.Validate(record, $"records[{i}].record.", errors);
                if (records[i].PlanId is { } planId)
                {
                    links.Add(($"records[{i}].planId", record, planId));
                }
            }

            await care.ValidatePlanLinksAsync(import.PetId, links, errors, ct);
            identity.Validate(identifiers, "identifiers", errors);
            if (request.Passport is { } passport)
            {
                PetIdentityWriter.ValidatePassport(passport.PassportNumber, passport.IssuingCountry, "passport", errors);
                errors.NotInFuture("passport.issuedOn", passport.IssuedOn, Input.LatestToday(clock));
            }

            if (errors.HasErrors)
            {
                return TypedResults.ValidationProblem(errors.ToDictionary());
            }

            var created = records
                .Select(r => care.Add(me.HouseholdId, import.PetId, me.UserId, r.Record, RecordSource.AiScan, r.PlanId))
                .ToList();
            foreach (var weight in weights)
            {
                petWeights.Add(me.HouseholdId, import.PetId, me.UserId, weight.MeasuredOn, weight.WeightKg);
            }

            var plansMoved = (await care.MovePlansAsync(created, ct)).Count;
            var identifiersAdded = identifiers.Count > 0
                ? await identity.AddIdentifiersAsync(me.HouseholdId, import.PetId, identifiers, ct)
                : 0;
            var passportUpdated = request.Passport is { } fields
                && await identity.FillPassportAsync(import.PetId, fields.PassportNumber, fields.IssuingCountry, fields.IssuedOn, ct);
            // A note has no photos to keep.
            var documentId = request.KeepPhotos && import.FileIds.Count > 0
                ? await documents.AddScannedPagesAsync(
                    me.HouseholdId,
                    import.PetId,
                    me.UserId,
                    import.Source == AiImportSource.PassportPages ? DocumentType.PassportPage : DocumentType.Other,
                    import.FileIds,
                    ct)
                : null;

            var result = new ApplyImportResponse(
                [.. created.Select(r => r.Id)], plansMoved, identifiersAdded, passportUpdated, documentId, weights.Count);
            import.Status = AiImportStatus.Applied;
            import.AppliedAt = clock.GetUtcNow();
            import.ResultJson = JsonSerializer.Serialize(result, AiRunner.Json);
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return TypedResults.Ok(result);
        }

        var answer = await db.Database.CreateExecutionStrategy().ExecuteAsync(ApplyOnce);
        // Plans the scan moved are due later now: their reminders follow.
        if (answer.Result is Ok<ApplyImportResponse> { Value.PlansMoved: > 0 })
        {
            await reminders.RefreshAsync(me.HouseholdId, ct);
        }

        return answer;
    }

    private static async Task<Results<NoContent, NotFound, ProblemHttpResult>> Discard(
        Guid id, CurrentUserAccessor current, AppDbContext db, Plans plans, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await db.AiImports.AnyAsync(i => i.Id == id && i.HouseholdId == me.HouseholdId, ct))
        {
            return TypedResults.NotFound();
        }

        // Still waiting in the queue: it will never be read, so its photos go back to the month's count. One being read
        // keeps them until its worker knows whether AI answered.
        var unread = await db.AiImports
            .Where(i => i.Id == id && i.HouseholdId == me.HouseholdId && i.Status == AiImportStatus.Queued)
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, AiImportStatus.Discarded).SetProperty(i => i.Text, (string?)null), ct);
        if (unread == 1)
        {
            await plans.SettleImportAsync(id, answered: false, ct);
            return TypedResults.NoContent();
        }

        // In one statement, so a draft being saved right now stays saved. What the model read (microchip and
        // passport numbers) goes with the draft, and so does the note.
        var discarded = await db.AiImports
            .Where(i => i.Id == id && i.HouseholdId == me.HouseholdId && i.Status != AiImportStatus.Applied)
            .ExecuteUpdateAsync(s => s
                .SetProperty(i => i.Status, AiImportStatus.Discarded)
                .SetProperty(i => i.ScanJson, (string?)null)
                .SetProperty(i => i.Text, (string?)null), ct);

        // Saved already (say the answer to "Save" got lost): telling the user it was thrown away would be a lie.
        return discarded == 0
            ? TypedResults.Problem(statusCode: StatusCodes.Status409Conflict, title: "This scan is saved already.")
            : TypedResults.NoContent();
    }

    /// <summary>Scans the user still has something to do with.</summary>
    private static readonly AiImportStatus[] WaitingStatuses =
        [AiImportStatus.Queued, AiImportStatus.Processing, AiImportStatus.Ready, AiImportStatus.Failed];

    /// <summary>Whether <paramref name="earlier"/> is what the request asks for again: the same pet and kind.</summary>
    private static bool SameRequest(AiImport earlier, CreateAiImportRequest request) =>
        earlier.PetId == request.PetId && earlier.Source == request.Source;

    /// <summary>The app makes a new request id for every scan and note; the same one for another is a mistake.</summary>
    private static ValidationProblem RequestIdUsed() =>
        TypedResults.ValidationProblem(new Dictionary<string, string[]>
        {
            ["requestId"] = ["This request id was used for something else."],
        });

    private static Task<AiImport?> FindByRequestAsync(AppDbContext db, Guid householdId, Guid requestId, CancellationToken ct) =>
        db.AiImports.AsNoTracking().SingleOrDefaultAsync(i => i.HouseholdId == householdId && i.ClientRequestId == requestId, ct);

    private static Accepted<AiImportResponse> Accepted(AiImportResponse import) =>
        TypedResults.Accepted($"/api/v1/ai-imports/{import.Id}", import);
}

/// <summary>
/// Turns stored imports into responses. A ready import's draft is built from the model's answer against what is
/// saved for the pet right now: entries saved meanwhile (another scan, typed by hand) show as "already saved".
/// </summary>
public sealed class AiDrafts(
    Files files,
    CareRecordsWriter care,
    CarePlanDirectory plans,
    PetIdentityWriter identity,
    PetWeights weights,
    TimeProvider clock)
{
    public async Task<AiImportResponse> ToResponseAsync(AiImport import, CancellationToken ct) =>
        (await ToResponsesAsync(import.PetId, [import], ct))[0];

    /// <summary>Responses for imports of one pet.</summary>
    public async Task<List<AiImportResponse>> ToResponsesAsync(Guid petId, IReadOnlyList<AiImport> imports, CancellationToken ct)
    {
        var ready = imports.FirstOrDefault(i => i is { Status: AiImportStatus.Ready, ScanJson: not null });
        var saved = ready is not null ? await SavedAsync(ready.HouseholdId, petId, ct) : null;
        var links = await files.LinksAsync([.. imports.SelectMany(i => i.FileIds).Distinct()], ct);
        return [.. imports.Select(import => new AiImportResponse(
            import.Id,
            import.PetId,
            import.Source,
            import.Status,
            [.. import.FileIds.Where(links.ContainsKey).Select(f => links[f])],
            import is { Status: AiImportStatus.Ready, ScanJson: { } scan }
                ? ImportDrafts.Build(JsonSerializer.Deserialize<PassportScan>(scan, AiRunner.Json)!, saved!, Input.LatestToday(clock))
                : null,
            import.Error,
            import.Model,
            import.CreatedAt,
            import.CompletedAt,
            import.AppliedAt,
            import.ResultJson is { } result ? JsonSerializer.Deserialize<ApplyImportResponse>(result, AiRunner.Json) : null,
            import.Text))];
    }

    private async Task<SavedPetData> SavedAsync(Guid householdId, Guid petId, CancellationToken ct)
    {
        var pet = await identity.ReadAsync(petId, ct);
        var records = await care.SummariesAsync(petId, ct);
        return new SavedPetData(
            [.. records.Select(r => new SavedRecord(r.Id, r.Kind, r.PerformedOn, r.Product))],
            pet.IdentifierCodes, pet.PassportNumber, pet.IssuingCountry, pet.IssuedOn)
        {
            Plans = await plans.ActiveForPetAsync(petId, ct),
            Weights = [.. (await weights.LogAsync(householdId, petId, ct))
                .Select(w => new SavedWeight(w.Id, w.MeasuredOn, w.WeightKg, FromCheckUp: w.Source == WeightSource.CareRecord))],
            ExactBirthDate = await weights.ExactBirthDateAsync(petId, ct),
        };
    }
}

/// <summary>
/// The household's AI scans, for "Download my data": what was sent (the photos are under "files" by id), what the AI read
/// (<c>scanJson</c>) and what was saved from it (<c>resultJson</c>).
/// </summary>
public sealed class AiImportsExport(AppDbContext db) : IHouseholdExportSource
{
    public async Task ExportAsync(HouseholdExport export, CancellationToken ct) =>
        export.Add("aiScans", await db.AiImports.AsNoTracking()
            .Where(i => i.HouseholdId == export.HouseholdId)
            .OrderBy(i => i.CreatedAt)
            .ToListAsync(ct));
}
