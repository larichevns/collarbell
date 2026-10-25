using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Documents;

[JsonConverter(typeof(JsonStringEnumConverter<DocumentType>))]
public enum DocumentType
{
    /// <summary>Photos of the pet passport's pages.</summary>
    PassportPage,
    VaccinationCertificate,
    LabResult,
    Prescription,
    Invoice,
    Insurance,
    Other,
}

/// <summary>A document of a pet: one or more pages, each page an image or a PDF.</summary>
public sealed class Document
{
    private Document()
    {
    }

    public Document(Guid householdId, Guid petId, Guid createdBy, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        PetId = petId;
        CreatedBy = createdBy;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    /// <summary>Null is reserved for household documents (insurance and the like), not used yet.</summary>
    public Guid? PetId { get; private set; }

    public DocumentType Type { get; set; }

    /// <summary>Optional: without a title the app shows the type's name.</summary>
    public string? Title { get; set; }

    public DateOnly? DocumentDate { get; set; }

    public string? Notes { get; set; }

    public Guid CreatedBy { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public List<DocumentPage> Pages { get; private set; } = [];
}

/// <summary>One page of a document. The page is identified by its file: a file is a page of one document only.</summary>
public sealed class DocumentPage
{
    private DocumentPage()
    {
    }

    public DocumentPage(Guid fileId, int pageNo)
    {
        FileId = fileId;
        PageNo = pageNo;
    }

    public Guid FileId { get; private set; }

    public Guid DocumentId { get; private set; }

    /// <summary>1, 2, 3… in the order the pages are shown.</summary>
    public int PageNo { get; set; }
}
