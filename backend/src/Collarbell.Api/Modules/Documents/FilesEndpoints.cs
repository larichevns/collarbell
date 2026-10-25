using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Storage;
using Collarbell.Api.Modules.Identity;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Collarbell.Api.Modules.Documents;

public static class FilesEndpoints
{
    public static RouteGroupBuilder MapFilesEndpoints(this RouteGroupBuilder api)
    {
        var files = api.MapGroup("/files").WithTags("Files");

        files.MapPost("", Upload)
            .WithName("UploadFile")
            .WithSummary("Upload a photo (JPEG, PNG, WebP) or a PDF, up to 15 MB.")
            .WithDescription(
                "Photos are stored as JPEG without metadata, at most 2048 px on the long side, with a thumbnail. " +
                "Attach the file to a pet or a document next; files that are never attached are deleted after a day.")
            .DisableAntiforgery() // the API is called with bearer tokens, not cookies
            .WithMetadata(new RequestSizeLimitAttribute(FilePreparation.MaxUploadBytes + (1024 * 1024)))
            .ProducesProblem(StatusCodes.Status413PayloadTooLarge)
            .ProducesProblem(StatusCodes.Status415UnsupportedMediaType);

        files.MapGet("/{id:guid}/url", GetLink)
            .WithName("GetFileLink")
            .WithSummary("Fresh download links for a file of the household.");

        return api;
    }

    private static async Task<Results<Created<FileLink>, ValidationProblem, ProblemHttpResult>> Upload(
        IFormFile? file,
        CurrentUserAccessor current,
        AppDbContext db,
        ObjectStorage storage,
        Files files,
        TimeProvider clock,
        ILogger<Files> log,
        CancellationToken ct)
    {
        if (file is null || file.Length == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["file"] = ["Send the file in the form field \"file\"."],
            });
        }

        if (file.Length > FilePreparation.MaxUploadBytes)
        {
            return TypedResults.Problem(
                statusCode: StatusCodes.Status413PayloadTooLarge,
                title: "The file is too large.",
                detail: "Upload files up to 15 MB.");
        }

        var upload = new byte[file.Length];
        await using (var stream = file.OpenReadStream())
        {
            await stream.ReadExactlyAsync(upload, ct);
        }

        var prepared = FilePreparation.Prepare(upload);
        if (prepared is null)
        {
            return TypedResults.Problem(
                statusCode: StatusCodes.Status415UnsupportedMediaType,
                title: "Unsupported file.",
                detail: "Upload a JPEG, PNG or WebP photo, or a PDF.");
        }

        var me = await current.GetAsync(ct);
        var stored = new StoredFile(
            me.HouseholdId, me.UserId, prepared.ContentType, prepared.Content.LongLength, prepared.Sha256,
            prepared.Width, prepared.Height, hasThumbnail: prepared.Thumbnail is not null, clock.GetUtcNow());

        // Objects first, then the row: a row never points at nothing. If the row can't be saved, the objects go again.
        await storage.PutAsync(stored.StorageKey, prepared.Content, prepared.ContentType, ct);
        if (prepared.Thumbnail is not null)
        {
            await storage.PutAsync(stored.ThumbnailKey!, prepared.Thumbnail, "image/jpeg", ct);
        }

        db.StoredFiles.Add(stored);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (Exception e)
        {
            await ForgetObjectsAsync(storage, stored, log);

            // The household went while the photo was on its way (its last owner deleted the account): nothing to add it to.
            if (e is DbUpdateException { InnerException: PostgresException { SqlState: PostgresErrorCodes.ForeignKeyViolation } })
            {
                return TypedResults.Problem(statusCode: StatusCodes.Status403Forbidden, title: "You aren't in this household.",
                    type: HouseholdProblems.NotAMember);
            }

            throw;
        }

        return TypedResults.Created($"/api/v1/files/{stored.Id}/url", files.Link(stored));
    }

    /// <summary>Deletes the objects of an upload whose row wasn't saved; nothing else knows about them.</summary>
    private static async Task ForgetObjectsAsync(ObjectStorage storage, StoredFile stored, ILogger log)
    {
        foreach (var key in new[] { stored.StorageKey, stored.ThumbnailKey }.OfType<string>())
        {
            try
            {
                await storage.DeleteAsync(key, CancellationToken.None);
            }
            catch (Exception e)
            {
                log.LogWarning(e, "An unsaved upload's object {Key} stays in storage.", key);
            }
        }
    }

    private static async Task<Results<Ok<FileLink>, NotFound>> GetLink(
        Guid id, CurrentUserAccessor current, AppDbContext db, Files files, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var file = await db.StoredFiles.AsNoTracking()
            .SingleOrDefaultAsync(f => f.Id == id && f.HouseholdId == me.HouseholdId, ct);
        return file is null ? TypedResults.NotFound() : TypedResults.Ok(files.Link(file));
    }
}
