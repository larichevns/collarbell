using System.Globalization;
using System.Text.Json.Serialization;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Identity;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Modules.Billing;

// A household's plan (spec 8.7): Free or Premium, and the AI photos a month each allows. No payments yet: Premium is
// given by hand in the admin; the website (Paddle) and the App Store will set it later, through RevenueCat
// Store and payment rules: docs/mvp-spec.md, section 8.7.

[JsonConverter(typeof(JsonStringEnumConverter<PlanKind>))]
public enum PlanKind
{
    Free,
    Premium,
}

/// <summary>Who set the household's plan.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<PlanSource>))]
public enum PlanSource
{
    /// <summary>The admin, by hand: testers, friends, support.</summary>
    Manual,

    /// <summary>A purchase on the website (Paddle through RevenueCat): later.</summary>
    Paddle,

    /// <summary>A purchase in the App Store (through RevenueCat): later.</summary>
    AppStore,
}

/// <summary>
/// The household's plan as last set; no row means Free. A Premium past <see cref="ExpiresAt"/> is Free again by itself,
/// the row stays to show what it was.
/// </summary>
public sealed class HouseholdPlan
{
    public const int MaxNoteLength = 200;

    private HouseholdPlan()
    {
    }

    public HouseholdPlan(Guid householdId)
    {
        HouseholdId = householdId;
    }

    public Guid HouseholdId { get; private set; }

    public PlanKind Plan { get; private set; }

    public PlanSource Source { get; private set; }

    /// <summary>Premium's last moment; null: no end (or Free).</summary>
    public DateTimeOffset? ExpiresAt { get; private set; }

    /// <summary>Why, in a few words: "tester", "friend".</summary>
    public string? Note { get; private set; }

    /// <summary>The admin who set it (null for a purchase, or when their account is deleted).</summary>
    public Guid? ChangedBy { get; private set; }

    public DateTimeOffset ChangedAt { get; private set; }

    public void Set(PlanKind plan, PlanSource source, DateTimeOffset? expiresAt, string? note, Guid? changedBy, DateTimeOffset now)
    {
        Plan = plan;
        Source = source;
        ExpiresAt = plan == PlanKind.Premium ? expiresAt : null;
        Note = note;
        ChangedBy = changedBy;
        ChangedAt = now;
    }

    public bool IsPremiumAt(DateTimeOffset now) => Plan == PlanKind.Premium && (ExpiresAt is null || ExpiresAt > now);
}

[JsonConverter(typeof(JsonStringEnumConverter<AiChargeState>))]
public enum AiChargeState
{
    /// <summary>Taken before AI reads the photos: counts while the reading goes on.</summary>
    Held,

    /// <summary>AI answered: the photos are spent.</summary>
    Charged,

    /// <summary>The reading failed or was never made: the photos are back.</summary>
    Released,
}

/// <summary>
/// The AI photos of one request, like a booking: held before AI reads them, then charged (it answered) or released (it
/// failed). This is what the plans' monthly limits count. Kept when the household or the account is deleted, so that
/// deleting a household doesn't give its photos back.
/// </summary>
public sealed class AiPhotoCharge
{
    private AiPhotoCharge()
    {
    }

    public AiPhotoCharge(Guid householdId, Guid userId, PlanKind plan, int photos, string feature, Guid? importId, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7();
        HouseholdId = householdId;
        UserId = userId;
        Plan = plan;
        Photos = photos;
        Feature = feature;
        ImportId = importId;
        State = AiChargeState.Held;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }

    /// <summary>Null once the household is deleted.</summary>
    public Guid? HouseholdId { get; private set; }

    /// <summary>Who asked; null once their account is deleted.</summary>
    public Guid? UserId { get; private set; }

    /// <summary>The household's plan when asked: each plan's limit counts the photos taken under it.</summary>
    public PlanKind Plan { get; private set; }

    public int Photos { get; private set; }

    /// <summary>What read them: passport-scan, identifier-scan, product-scan, connection-test.</summary>
    public string Feature { get; private set; } = null!;

    /// <summary>The passport scan the photos are for: its worker settles the charge when the reading ends.</summary>
    public Guid? ImportId { get; private set; }

    public AiChargeState State { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset? SettledAt { get; private set; }

    public void Settle(bool answered, DateTimeOffset now)
    {
        State = answered ? AiChargeState.Charged : AiChargeState.Released;
        SettledAt = now;
    }
}

public sealed class PlanLimits
{
    /// <summary>
    /// Photos AI may read for the household in a calendar month (UTC): passport pages, chip stickers, packages, and the
    /// AI screen's test picture. On Free it is also what one person may use across all their Free households.
    /// </summary>
    public int AiPhotosPerMonth { get; set; }
}

/// <summary>What each plan allows ("Plans" settings; the spec, 8.7 and "Тарифы", says why these numbers).</summary>
public sealed class PlansOptions
{
    public PlanLimits Free { get; set; } = new() { AiPhotosPerMonth = 20 };

    public PlanLimits Premium { get; set; } = new() { AiPhotosPerMonth = 300 };
}

/// <summary>The plan that works now: a Premium past its end is Free.</summary>
/// <param name="Source">Who gave the Premium; null for Free.</param>
public sealed record PlanState(PlanKind Plan, PlanSource? Source, DateTimeOffset? ExpiresAt, int AiPhotosPerMonth);

/// <summary>A household's plan, and the AI photos it may still use this month.</summary>
public sealed class Plans(AppDbContext db, IOptions<PlansOptions> options, TimeProvider clock)
{
    /// <summary>409 with this type: not enough AI photos left this month (plan, limit, used, requested, resetsAt, scope).</summary>
    public const string AiLimitProblemType = "urn:collarbell:problem:ai-limit";

    /// <summary>
    /// A hold not settled within this time was cut off (the API restarted in the middle of a reading): it stops
    /// counting. A reading takes a few minutes at most, a passport scan in the queue a little longer.
    /// </summary>
    public static readonly TimeSpan HoldLifetime = TimeSpan.FromHours(1);

    /// <summary>The PostgreSQL advisory lock taken while counting and holding: one request at a time.</summary>
    private const long CountingLock = 0x436F6C6C_41490001;

    public int PremiumAiPhotosPerMonth => options.Value.Premium.AiPhotosPerMonth;

    public async Task<PlanState> OfAsync(Guid householdId, CancellationToken ct) =>
        Effective(await db.HouseholdPlans.AsNoTracking().SingleOrDefaultAsync(p => p.HouseholdId == householdId, ct));

    public PlanState Effective(HouseholdPlan? row) =>
        row is not null && row.IsPremiumAt(clock.GetUtcNow())
            ? new PlanState(PlanKind.Premium, row.Source, row.ExpiresAt, options.Value.Premium.AiPhotosPerMonth)
            : new PlanState(PlanKind.Free, null, null, options.Value.Free.AiPhotosPerMonth);

    /// <summary>The calendar month (UTC) the limits count in: its first moment, and the moment the count starts again.</summary>
    public (DateTimeOffset Start, DateTimeOffset ResetsAt) Month()
    {
        var now = clock.GetUtcNow();
        var start = new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero);
        return (start, start.AddMonths(1));
    }

    /// <summary>The household's photos this month under the plan that works now: charged, and held right now.</summary>
    public async Task<int> AiPhotosUsedAsync(Guid householdId, CancellationToken ct)
    {
        var plan = await OfAsync(householdId, ct);
        return await Counted().Where(c => c.HouseholdId == householdId && c.Plan == plan.Plan).SumAsync(c => c.Photos, ct);
    }

    /// <summary>
    /// Holds <paramref name="photos"/> for AI to read in its own short transaction (chip and package scans, the
    /// connection test). Null and a 409 problem when they don't fit (<see cref="TryHoldAsync"/>).
    /// </summary>
    public Task<(Guid? HoldId, ProblemHttpResult? Refusal)> HoldAsync(
        Guid householdId, Guid userId, int photos, string feature, CancellationToken ct)
    {
        async Task<(Guid?, ProblemHttpResult?)> HoldOnce()
        {
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var (hold, refusal) = await TryHoldAsync(householdId, userId, photos, feature, importId: null, ct);
            if (hold is null)
            {
                return (null, refusal);
            }

            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return (hold.Id, null);
        }

        return db.Database.CreateExecutionStrategy().ExecuteAsync(HoldOnce);
    }

    /// <summary>
    /// Inside the caller's transaction: waits for the counting lock (held till the transaction ends, so requests sent
    /// at once are counted one after another), then adds a hold if the photos fit. They must fit the household's
    /// limit for its plan and, on Free, the person's limit across all their Free households (so making more
    /// households gives no more photos). The caller saves the hold with its own changes.
    /// </summary>
    public async Task<(AiPhotoCharge? Hold, ProblemHttpResult? Refusal)> TryHoldAsync(
        Guid householdId, Guid userId, int photos, string feature, Guid? importId, CancellationToken ct)
    {
        await LockCountingAsync(ct);
        var plan = await OfAsync(householdId, ct);
        var householdUsed = await Counted().Where(c => c.HouseholdId == householdId && c.Plan == plan.Plan).SumAsync(c => c.Photos, ct);
        if (householdUsed + photos > plan.AiPhotosPerMonth)
        {
            return (null, Refusal(plan, householdUsed, photos, scope: "household"));
        }

        if (plan.Plan == PlanKind.Free)
        {
            var personUsed = await Counted().Where(c => c.UserId == userId && c.Plan == PlanKind.Free).SumAsync(c => c.Photos, ct);
            if (personUsed + photos > plan.AiPhotosPerMonth)
            {
                return (null, Refusal(plan, personUsed, photos, scope: "person"));
            }
        }

        var hold = new AiPhotoCharge(householdId, userId, plan.Plan, photos, feature, importId, clock.GetUtcNow());
        db.AiPhotoCharges.Add(hold);
        return (hold, null);
    }

    /// <summary>What a note's hold is called: it holds no photos, it counts the notes a person has AI read.</summary>
    public const string NoteFeature = "text-entry";

    /// <summary>
    /// Inside the caller's transaction, under the counting lock: adds a hold for a note (no photos) unless the person
    /// had <paramref name="perDay"/> notes read in the last 24 hours; null when they had. Counted like photos: read
    /// (charged) or being read (held), not the ones AI never read (released). Holds outlive the pet and the household,
    /// so deleting them gives no notes back.
    /// </summary>
    public async Task<AiPhotoCharge?> TryHoldNoteAsync(
        Guid householdId, Guid userId, Guid importId, int perDay, CancellationToken ct)
    {
        await LockCountingAsync(ct);
        var now = clock.GetUtcNow();
        var since = now.AddDays(-1);
        var heldSince = now - HoldLifetime;
        var notes = await db.AiPhotoCharges.CountAsync(c => c.UserId == userId && c.Feature == NoteFeature && c.CreatedAt > since
            && (c.State == AiChargeState.Charged || (c.State == AiChargeState.Held && c.CreatedAt > heldSince)), ct);
        if (notes >= perDay)
        {
            return null;
        }

        var hold = new AiPhotoCharge(householdId, userId, (await OfAsync(householdId, ct)).Plan, photos: 0, NoteFeature, importId, now);
        db.AiPhotoCharges.Add(hold);
        return hold;
    }

    /// <summary>
    /// The counting lock, for a caller that must look at something else under it first (a retried passport scan
    /// finds the first one). Taking it again in the same transaction is free.
    /// </summary>
    public Task LockCountingAsync(CancellationToken ct) =>
        db.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock({CountingLock})", ct);

    /// <summary>Charges the hold if AI answered, releases it if not. Once: a settled hold stays as it is.</summary>
    public Task SettleAsync(Guid holdId, bool answered, CancellationToken ct) =>
        Settle(db.AiPhotoCharges.Where(c => c.Id == holdId), answered, ct);

    /// <summary>The same for a passport scan's hold, by the scan.</summary>
    public Task SettleImportAsync(Guid importId, bool answered, CancellationToken ct) =>
        Settle(db.AiPhotoCharges.Where(c => c.ImportId == importId), answered, ct);

    private Task Settle(IQueryable<AiPhotoCharge> charges, bool answered, CancellationToken ct)
    {
        var state = answered ? AiChargeState.Charged : AiChargeState.Released;
        var now = clock.GetUtcNow();
        return charges.Where(c => c.State == AiChargeState.Held)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.State, state).SetProperty(c => c.SettledAt, now), ct);
    }

    /// <summary>This month's photos that count: charged, or held and not cut off.</summary>
    private IQueryable<AiPhotoCharge> Counted()
    {
        var (start, _) = Month();
        var heldSince = clock.GetUtcNow() - HoldLifetime;
        return db.AiPhotoCharges.Where(c => c.CreatedAt >= start
            && (c.State == AiChargeState.Charged || (c.State == AiChargeState.Held && c.CreatedAt > heldSince)));
    }

    /// <param name="scope">household: the household's limit for its plan; person: on Free, the person's own across their Free households.</param>
    private ProblemHttpResult Refusal(PlanState plan, int used, int requested, string scope) =>
        TypedResults.Problem(
            statusCode: StatusCodes.Status409Conflict,
            title: used >= plan.AiPhotosPerMonth ? "This month's AI photos are used up." : "Not enough AI photos left this month.",
            type: AiLimitProblemType,
            extensions: new Dictionary<string, object?>
            {
                ["plan"] = plan.Plan.ToString(),
                ["limit"] = plan.AiPhotosPerMonth,
                ["used"] = used,
                ["requested"] = requested,
                ["resetsAt"] = Month().ResetsAt.ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture),
                ["scope"] = scope,
            });
}

internal static class BillingSchema
{
    public const string Name = "billing";
}

internal sealed class HouseholdPlanConfiguration : IEntityTypeConfiguration<HouseholdPlan>
{
    public void Configure(EntityTypeBuilder<HouseholdPlan> b)
    {
        b.ToTable("plans", BillingSchema.Name);
        b.HasKey(x => x.HouseholdId);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.ChangedBy).OnDelete(DeleteBehavior.SetNull);

        b.Property(x => x.Plan).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Source).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Note).HasMaxLength(HouseholdPlan.MaxNoteLength);
    }
}

internal sealed class AiPhotoChargeConfiguration : IEntityTypeConfiguration<AiPhotoCharge>
{
    public void Configure(EntityTypeBuilder<AiPhotoCharge> b)
    {
        b.ToTable("ai_charges", BillingSchema.Name);
        b.HasKey(x => x.Id);
        b.HasOne<Household>().WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.SetNull);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.SetNull);
        b.HasIndex(x => new { x.HouseholdId, x.CreatedAt });
        b.HasIndex(x => new { x.UserId, x.CreatedAt });
        b.HasIndex(x => x.ImportId);

        b.Property(x => x.Plan).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.State).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Feature).HasMaxLength(40);
    }
}
