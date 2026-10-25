using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Storage;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Documents;

/// <summary>A new document with its pages; the order of <see cref="FileIds"/> is the order of the pages.</summary>
public sealed record DocumentRequest(
    DocumentType Type,
    string? Title,
    DateOnly? DocumentDate,
    string? Notes,
    List<Guid> FileIds);

/// <summary>The details of a document. Pages change only through the page endpoints.</summary>
public sealed record DocumentDetailsRequest(
    DocumentType Type,
    string? Title,
    DateOnly? DocumentDate,
    string? Notes);

/// <summary>Uploaded files to add as pages at the end, in this order.</summary>
public sealed record AddPagesRequest(List<Guid> FileIds);

public sealed record DocumentResponse(
    Guid Id,
    Guid? PetId,
    DocumentType Type,
    string? Title,
    DateOnly? DocumentDate,
    string? Notes,
    List<FileLink> Pages,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public static class DocumentsEndpoints
{
    internal const int MaxPages = 50;
    private const int MaxTitleLength = 200;
    private const int MaxNotesLength = 2000;

    public static RouteGroupBuilder MapDocumentsEndpoints(this RouteGroupBuilder api)
    {
        var petDocuments = api.MapGroup("/pets/{petId:guid}/documents").WithTags("Documents").ReportsChanges(LiveTopics.Documents);

        petDocuments.MapGet("", ListForPet)
            .WithName("ListPetDocuments")
            .WithSummary("The pet's documents, newest first; optionally only one type, such as PassportPage.");

        petDocuments.MapPost("", Create)
            .WithName("CreatePetDocument")
            .WithSummary("Create a document from uploaded files; the order of fileIds is the page order.");

        var documents = api.MapGroup("/documents").WithTags("Documents").ReportsChanges(LiveTopics.Documents);

        documents.MapGet("/{id:guid}", Get)
            .WithName("GetDocument")
            .WithSummary("One document with links to its pages.");

        documents.MapPut("/{id:guid}", Update)
            .WithName("UpdateDocument")
            .WithSummary("Change the document's type, title, date and notes. The pages stay as they are.");

        documents.MapDelete("/{id:guid}", Delete)
            .WithName("DeleteDocument")
            .WithSummary("Delete the document and its files.");

        // Pages are added and removed one change at a time, never by sending the whole list: a list loaded
        // earlier may already be out of date, and replacing pages with it would delete the newer ones.
        documents.MapPost("/{id:guid}/pages", AddPages)
            .WithName("AddDocumentPages")
            .WithSummary("Add uploaded files as pages at the end of the document.");

        documents.MapDelete("/{id:guid}/pages/{fileId:guid}", RemovePage)
            .WithName("RemoveDocumentPage")
            .WithSummary("Delete one page and its file. Deleting the last page deletes the document.");

        return api;
    }

    private static async Task<Results<Ok<List<DocumentResponse>>, NotFound>> ListForPet(
        Guid petId,
        DocumentType? type,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        Files files,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        var query = db.Documents.AsNoTracking()
            .Include(d => d.Pages)
            .Where(d => d.HouseholdId == me.HouseholdId && d.PetId == petId);
        if (type is not null)
        {
            query = query.Where(d => d.Type == type);
        }

        // Newest first: by the document's own date when it has one, otherwise by when it was added.
        var found = await query.ToListAsync(ct);
        var ordered = found
            .OrderByDescending(d => d.DocumentDate ?? DateOnly.FromDateTime(d.CreatedAt.UtcDateTime))
            .ThenByDescending(d => d.CreatedAt)
            .ToList();
        return TypedResults.Ok(await ToResponsesAsync(ordered, files, ct));
    }

    private static async Task<Results<Ok<DocumentResponse>, NotFound>> Get(
        Guid id, CurrentUserAccessor current, AppDbContext db, Files files, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var document = await db.Documents.AsNoTracking()
            .Include(d => d.Pages)
            .SingleOrDefaultAsync(d => d.Id == id && d.HouseholdId == me.HouseholdId, ct);
        return document is null ? TypedResults.NotFound() : TypedResults.Ok(await ToResponseAsync(document, files, ct));
    }

    private static async Task<Results<Created<DocumentResponse>, NotFound, ValidationProblem>> Create(
        Guid petId,
        DocumentRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        PetDirectory pets,
        Files files,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await pets.ExistsAsync(me.HouseholdId, petId, ct))
        {
            return TypedResults.NotFound();
        }

        var errors = ValidateDetails(request.Type, request.Title, request.DocumentDate, request.Notes, clock);
        ValidateFileIds(errors, request.FileIds, existingPages: 0);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var attachError = await files.AttachAsync(me.HouseholdId, request.FileIds, photosOnly: false, ct);
        if (attachError is not null)
        {
            return FileIdsProblem(attachError);
        }

        var document = new Document(me.HouseholdId, petId, me.UserId, clock.GetUtcNow());
        ApplyDetails(document, request.Type, request.Title, request.DocumentDate, request.Notes);
        for (var i = 0; i < request.FileIds.Count; i++)
        {
            document.Pages.Add(new DocumentPage(request.FileIds[i], pageNo: i + 1));
        }

        db.Documents.Add(document);
        await db.SaveChangesAsync(ct);
        return TypedResults.Created($"/api/v1/documents/{document.Id}", await ToResponseAsync(document, files, ct));
    }

    private static async Task<Results<Ok<DocumentResponse>, NotFound, ValidationProblem>> Update(
        Guid id,
        DocumentDetailsRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        Files files,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var document = await FindAsync(db, me, id, ct);
        if (document is null)
        {
            return TypedResults.NotFound();
        }

        var errors = ValidateDetails(request.Type, request.Title, request.DocumentDate, request.Notes, clock);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        ApplyDetails(document, request.Type, request.Title, request.DocumentDate, request.Notes);
        document.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return TypedResults.Ok(await ToResponseAsync(document, files, ct));
    }

    private static async Task<Results<Ok<DocumentResponse>, NotFound, ValidationProblem>> AddPages(
        Guid id,
        AddPagesRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        Files files,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var document = await FindAsync(db, me, id, ct);
        if (document is null)
        {
            return TypedResults.NotFound();
        }

        // Pages already in this document are skipped, so a retry after a lost response just succeeds.
        var newIds = (request.FileIds ?? []).Where(id => document.Pages.TrueForAll(p => p.FileId != id)).ToList();
        var errors = new ValidationErrors();
        if (request.FileIds is { Count: > 0 } && newIds.Count == 0)
        {
            return TypedResults.Ok(await ToResponseAsync(document, files, ct));
        }

        ValidateFileIds(errors, newIds, existingPages: document.Pages.Count);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var attachError = await files.AttachAsync(me.HouseholdId, newIds, photosOnly: false, ct);
        if (attachError is not null)
        {
            return FileIdsProblem(attachError);
        }

        var lastPage = document.Pages.Count == 0 ? 0 : document.Pages.Max(p => p.PageNo);
        for (var i = 0; i < newIds.Count; i++)
        {
            document.Pages.Add(new DocumentPage(newIds[i], pageNo: lastPage + i + 1));
        }

        document.UpdatedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return TypedResults.Ok(await ToResponseAsync(document, files, ct));
    }

    private static async Task<Results<NoContent, NotFound>> RemovePage(
        Guid id, Guid fileId, CurrentUserAccessor current, AppDbContext db, Files files, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var document = await FindAsync(db, me, id, ct);
        var page = document?.Pages.Find(p => p.FileId == fileId);
        if (document is null || page is null)
        {
            return TypedResults.NotFound();
        }

        document.Pages.Remove(page);
        await files.RemoveAsync([fileId], ct);
        if (document.Pages.Count == 0)
        {
            db.Documents.Remove(document); // a document without pages has nothing left to show
        }
        else
        {
            document.UpdatedAt = clock.GetUtcNow();
        }

        await db.SaveChangesAsync(ct);
        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, NotFound>> Delete(
        Guid id, CurrentUserAccessor current, AppDbContext db, Files files, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var document = await FindAsync(db, me, id, ct);
        if (document is null)
        {
            return TypedResults.NotFound();
        }

        await files.RemoveAsync(document.Pages.Select(p => p.FileId).ToList(), ct);
        db.Documents.Remove(document);
        await db.SaveChangesAsync(ct);
        return TypedResults.NoContent();
    }

    /// <summary>Only documents of the caller's household are found; someone else's is "not found".</summary>
    private static Task<Document?> FindAsync(AppDbContext db, CurrentUser me, Guid id, CancellationToken ct) =>
        db.Documents
            .Include(d => d.Pages)
            .SingleOrDefaultAsync(d => d.Id == id && d.HouseholdId == me.HouseholdId, ct);

    private static ValidationErrors ValidateDetails(
        DocumentType type, string? title, DateOnly? documentDate, string? notes, TimeProvider clock)
    {
        var errors = new ValidationErrors();
        if (!Enum.IsDefined(type))
        {
            errors.Add("type", "Unknown document type.");
        }

        errors.MaxLength("title", Input.Clean(title), MaxTitleLength);
        errors.MaxLength("notes", Input.Clean(notes), MaxNotesLength);
        errors.NotInFuture("documentDate", documentDate, Input.LatestToday(clock));
        return errors;
    }

    private static void ValidateFileIds(ValidationErrors errors, List<Guid>? fileIds, int existingPages)
    {
        if (fileIds is null || fileIds.Count == 0)
        {
            errors.Add("fileIds", "Add at least one page.");
        }
        else if (existingPages + fileIds.Count > MaxPages)
        {
            errors.Add("fileIds", $"A document has {MaxPages} pages or fewer.");
        }
        else if (fileIds.Distinct().Count() != fileIds.Count)
        {
            errors.Add("fileIds", "Each file can be used once.");
        }
    }

    private static void ApplyDetails(Document document, DocumentType type, string? title, DateOnly? documentDate, string? notes)
    {
        document.Type = type;
        document.Title = Input.Clean(title);
        document.DocumentDate = documentDate;
        document.Notes = Input.Clean(notes);
    }

    private static ValidationProblem FileIdsProblem(string message) =>
        TypedResults.ValidationProblem(new Dictionary<string, string[]> { ["fileIds"] = [message] });

    private static async Task<DocumentResponse> ToResponseAsync(Document document, Files files, CancellationToken ct) =>
        (await ToResponsesAsync([document], files, ct))[0];

    private static async Task<List<DocumentResponse>> ToResponsesAsync(List<Document> documents, Files files, CancellationToken ct)
    {
        var links = await files.LinksAsync(documents.SelectMany(d => d.Pages).Select(p => p.FileId), ct);
        return documents
            .Select(d => new DocumentResponse(
                d.Id,
                d.PetId,
                d.Type,
                d.Title,
                d.DocumentDate,
                d.Notes,
                d.Pages.OrderBy(p => p.PageNo).Select(p => links[p.FileId]).ToList(),
                d.CreatedAt,
                d.UpdatedAt))
            .ToList();
    }
}

/// <summary>The Documents module's public API for other modules (pet deletion, AI imports).</summary>
public sealed class PetDocuments(AppDbContext db, Files files, TimeProvider clock) : IPetDeletionHandler
{
    /// <summary>
    /// Keeps scanned photos as pages. Passport pages go at the end of the pet's newest passport scan (there is one
    /// passport; a full scan gets a continuation); any other paper becomes a document of its own. Files that are
    /// gone or already used are skipped. Returns the document, or null when nothing was kept. Saved with the
    /// caller's SaveChanges.
    /// </summary>
    public async Task<Guid?> AddScannedPagesAsync(
        Guid householdId, Guid petId, Guid userId, DocumentType type, IReadOnlyList<Guid> fileIds, CancellationToken ct)
    {
        var free = await db.StoredFiles.AsNoTracking()
            .Where(f => fileIds.Contains(f.Id) && f.HouseholdId == householdId && f.AttachedAt == null)
            .Select(f => f.Id)
            .ToListAsync(ct);
        var keep = fileIds.Where(free.Contains).ToList();
        if (keep.Count == 0 || await files.AttachAsync(householdId, keep, photosOnly: false, ct) is not null)
        {
            return null;
        }

        var document = type == DocumentType.PassportPage
            ? await db.Documents
                .Include(d => d.Pages)
                .Where(d => d.HouseholdId == householdId && d.PetId == petId && d.Type == type)
                .OrderByDescending(d => d.CreatedAt)
                .FirstOrDefaultAsync(ct)
            : null;
        if (document is null || document.Pages.Count + keep.Count > DocumentsEndpoints.MaxPages)
        {
            document = new Document(householdId, petId, userId, clock.GetUtcNow()) { Type = type };
            db.Documents.Add(document);
        }

        var last = document.Pages.Count == 0 ? 0 : document.Pages.Max(p => p.PageNo);
        for (var i = 0; i < keep.Count; i++)
        {
            document.Pages.Add(new DocumentPage(keep[i], pageNo: last + i + 1));
        }

        document.UpdatedAt = clock.GetUtcNow();
        return document.Id;
    }

    /// <summary>The documents and their pages are deleted by the database together with the pet.</summary>
    public async Task BeforePetDeletedAsync(Guid petId, CancellationToken ct)
    {
        var fileIds = await db.Documents
            .Where(d => d.PetId == petId)
            .SelectMany(d => d.Pages)
            .Select(p => p.FileId)
            .ToListAsync(ct);
        await files.RemoveAsync(fileIds, ct);
    }
}

/// <summary>
/// The household's documents and every file of it (pet photos, document pages, files of records, photos of scans), for
/// "Download my data": the files go into the archive next to household.json.
/// </summary>
public sealed class DocumentsExport(AppDbContext db, ObjectStorage storage) : IHouseholdExportSource
{
    public async Task ExportAsync(HouseholdExport export, CancellationToken ct)
    {
        export.Add("documents", await db.Documents.AsNoTracking()
            .Include(d => d.Pages)
            .Where(d => d.HouseholdId == export.HouseholdId)
            .OrderBy(d => d.CreatedAt)
            .ToListAsync(ct));

        // Every file the server keeps for the household. One used nowhere yet (attachedAt null) is a scan waiting to be
        // saved, or an upload given up halfway: deleted after a day, a scan's photos after its 30 days.
        var files = await db.StoredFiles.AsNoTracking()
            .Where(f => f.HouseholdId == export.HouseholdId)
            .OrderBy(f => f.CreatedAt)
            .ToListAsync(ct);
        export.Add("files", files
            .Select(f => new { f.Id, Path = PathOf(f), f.ContentType, f.SizeBytes, f.Width, f.Height, f.CreatedAt, f.AttachedAt })
            .ToList());
        foreach (var file in files)
        {
            export.AddFile(PathOf(file), c => storage.TryGetAsync(file.StorageKey, c));
        }
    }

    /// <summary>Where the file is in the household's folder: <c>files/&lt;id&gt;.jpg</c>.</summary>
    private static string PathOf(StoredFile file) => $"files/{file.Id}{file.ContentType switch
    {
        "image/jpeg" => ".jpg",
        "image/png" => ".png",
        "image/webp" => ".webp",
        "application/pdf" => ".pdf",
        _ => "",
    }}";
}
