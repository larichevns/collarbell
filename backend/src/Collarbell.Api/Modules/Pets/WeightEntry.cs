namespace Collarbell.Api.Modules.Pets;

/// <summary>
/// One weighing of a pet: at home, at the groomer's, wherever. A weight a vet noted at a check-up lives in that care
/// record instead and joins the pet's weight log from there (<see cref="IPetWeightSource"/>): nothing is stored twice.
/// </summary>
public sealed class WeightEntry
{
    private WeightEntry()
    {
    }

    public WeightEntry(Guid householdId, Guid petId, DateOnly measuredOn, decimal weightKg, Guid createdBy, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        PetId = petId;
        MeasuredOn = measuredOn;
        WeightKg = weightKg;
        CreatedBy = createdBy;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }

    public Guid HouseholdId { get; private set; }

    public Guid PetId { get; private set; }

    public DateOnly MeasuredOn { get; set; }

    /// <summary>To the gram: a kitten gains a few grams a day.</summary>
    public decimal WeightKg { get; set; }

    /// <summary>Body condition score, if someone judged it: 1 to <see cref="BcsScale"/>.</summary>
    public int? Bcs { get; set; }

    /// <summary>The scale of <see cref="Bcs"/>: 9 (ideal 4–5) or 5 (ideal 3). Set together with it.</summary>
    public int? BcsScale { get; set; }

    public string? Note { get; set; }

    /// <summary>Who added it; null once their account is deleted (the weighing stays with the pet).</summary>
    public Guid? CreatedBy { get; private set; }

    /// <summary>The app's id for the create request, so a retry after a lost response doesn't add it twice.</summary>
    public Guid? ClientRequestId { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; set; }
}
