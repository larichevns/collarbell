using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Pets;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Routines;

/// <summary>
/// A feeding schedule that gives a food in supplies: <see cref="Amount"/> in <see cref="Unit"/>,
/// <see cref="TimesPerDay"/> on average (twice a day on weekends only is 4/7).
/// </summary>
public sealed record SupplyFeeding(
    Guid SupplyItemId,
    Guid RoutineId,
    Guid PetId,
    string PetName,
    decimal? Amount,
    PortionUnit? Unit,
    decimal TimesPerDay);

/// <summary>The Routines module's public API for supplies: which feedings use a food, and how much a day.</summary>
public sealed class FeedingSupplies(AppDbContext db, PetDirectory pets)
{
    /// <summary>Active feeding schedules of active pets that give a food in supplies.</summary>
    public async Task<List<SupplyFeeding>> OfAsync(Guid householdId, CancellationToken ct)
    {
        var activePets = (await pets.CardsAsync(householdId, ct))
            .Where(p => p.Status == PetStatus.Active)
            .ToDictionary(p => p.Id, p => p.Name);
        var routines = await db.Routines.AsNoTracking()
            .Where(r => r.HouseholdId == householdId && r.Active && r.Kind == RoutineKind.Feeding && r.SupplyItemId != null)
            .ToListAsync(ct);
        return
        [
            .. routines
                .Where(r => activePets.ContainsKey(r.PetId))
                .Select(r => new SupplyFeeding(r.SupplyItemId!.Value, r.Id, r.PetId, activePets[r.PetId], r.Amount, r.Unit,
                    r.Times.Count * r.Days.Count / 7m)),
        ];
    }

    /// <summary>Keeps the food name of the feedings in step when the item is renamed.</summary>
    public Task RenameFoodAsync(Guid householdId, Guid supplyItemId, string name, CancellationToken ct) =>
        db.Routines
            .Where(r => r.HouseholdId == householdId && r.SupplyItemId == supplyItemId && r.Food != name)
            .ExecuteUpdateAsync(s => s.SetProperty(r => r.Food, name), ct);
}
