using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Routines;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.AI;
using Npgsql;

namespace Collarbell.Api.Modules.Supplies;

/// <summary>
/// Create or replace a supply item. Amounts are in <see cref="Unit"/>: <see cref="PackageSize"/> 2000 for a 2 kg bag.
/// Without <see cref="UsageMode"/>, food is counted from the feeding schedules that give it and anything else by
/// <see cref="ManualDailyUsage"/>. <see cref="InitialStock"/> (creating only) is what is there now.
/// <see cref="DataSource"/> says where prefilled details came from (for the shared catalog). <see cref="RequestId"/>
/// (creating only): a new id per item the app creates, the same on retries.
/// </summary>
public sealed record SupplyRequest(
    string Name,
    string? Brand,
    string? Barcode,
    SupplyCategory Category,
    SupplyUnit Unit,
    decimal PackageSize,
    int? KcalPerKg,
    SupplyUsageMode? UsageMode,
    decimal? ManualDailyUsage,
    int? LeadTimeDays,
    string? StoreUrl,
    string? Notes,
    bool? Active,
    decimal? InitialStock,
    SupplyDataSource? DataSource,
    Guid? RequestId);

/// <summary>A feeding that gives this food; <see cref="Counted"/> is false when its portion can't count (no amount, another unit).</summary>
public sealed record SupplyFeedingResponse(
    Guid RoutineId,
    Guid PetId,
    string PetName,
    decimal? Amount,
    PortionUnit? Unit,
    decimal TimesPerDay,
    bool Counted);

public sealed record SupplyResponse(
    Guid Id,
    string Name,
    string? Brand,
    string? Barcode,
    SupplyCategory Category,
    SupplyUnit Unit,
    decimal PackageSize,
    int? KcalPerKg,
    SupplyUsageMode UsageMode,
    decimal? ManualDailyUsage,
    int LeadTimeDays,
    string? StoreUrl,
    string? Notes,
    bool Active,
    SupplyForecast Forecast,
    List<SupplyFeedingResponse> Feedings,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

/// <summary>
/// A purchase (<see cref="Quantity"/> added, e.g. two 2 kg bags: 4000) or a count (<see cref="Quantity"/> is what is
/// left now). <see cref="RequestId"/>: a new id per entry, the same on retries, so a purchase isn't counted twice.
/// </summary>
public sealed record StockEventRequest(StockEventKind Kind, decimal Quantity, Guid? RequestId);

public sealed record StockEventResponse(Guid Id, StockEventKind Kind, decimal Quantity, DateTimeOffset At, string? ByName, bool ByMe);

/// <summary>The entry and the item's new estimate.</summary>
public sealed record StockChangeResponse(StockEventResponse Event, SupplyResponse Supply);

/// <summary>The household's own item with this barcode.</summary>
public sealed record ExistingSupply(Guid Id, string Name, bool Active);

/// <summary>
/// What a scanned code is: <see cref="Code"/> the product's GTIN, <see cref="Batch"/> and <see cref="ExpiresOn"/> from a
/// medicine's DataMatrix. <see cref="Existing"/> is the household's item with this barcode, if any; <see cref="Product"/>
/// what a product database knows, and <see cref="Source"/> which one.
/// </summary>
public sealed record ProductLookupResponse(
    string Code,
    string? Batch,
    DateOnly? ExpiresOn,
    ExistingSupply? Existing,
    ProductDetails? Product,
    ProductLookupSource? Source);

/// <summary>
/// Read photos of a product's package with AI (1 to <see cref="SuppliesEndpoints.MaxScanPhotos"/>: the front, the
/// back with the size and energy). <see cref="Barcode"/>: the scanned code, kept when the photos don't show it.
/// </summary>
public sealed record ProductScanRequest(List<Guid> FileIds, string? Barcode);

/// <summary>What the model read, checked; <see cref="Model"/> is the one that answered.</summary>
public sealed record ProductScanResponse(ProductDraft Product, string Model);

/// <summary>A supply item as other modules see it.</summary>
public sealed record SupplyLink(Guid Id, string Name, SupplyUnit Unit);

/// <summary>The Supplies module's public API for feeding schedules: the food a schedule links to.</summary>
public sealed class SupplyDirectory(AppDbContext db)
{
    public Task<SupplyLink?> FindAsync(Guid householdId, Guid id, CancellationToken ct) =>
        db.SupplyItems.AsNoTracking()
            .Where(i => i.Id == id && i.HouseholdId == householdId)
            .Select(i => new SupplyLink(i.Id, i.Name, i.Unit))
            .SingleOrDefaultAsync(ct);
}

public static class SuppliesEndpoints
{
    public const int MaxScanPhotos = 3;

    private const decimal MaxPackageSize = 1_000_000;
    private const int MaxLeadTimeDays = 60;
    private const int EventsShown = 50;

    public static RouteGroupBuilder MapSuppliesEndpoints(this RouteGroupBuilder api)
    {
        var supplies = api.MapGroup("/supplies").WithTags("Supplies").ReportsChanges(LiveTopics.Supplies);

        supplies.MapGet("", List)
            .WithName("ListSupplies")
            .WithSummary("The household's supplies with their estimates: what runs out first comes first, items no longer bought last.");

        supplies.MapPost("", Create)
            .WithName("CreateSupply")
            .WithSummary("Add a food, litter or medication to supplies, with what is there now.");

        supplies.MapGet("/{id:guid}", Get)
            .WithName("GetSupply")
            .WithSummary("One supply item with its estimate and the feedings that use it.");

        supplies.MapPut("/{id:guid}", Update)
            .WithName("UpdateSupply")
            .WithSummary("Change a supply item; the stock stays as entered.");

        supplies.MapDelete("/{id:guid}", Delete)
            .WithName("DeleteSupply")
            .WithSummary("Delete a supply item and its purchases; feedings keep the food's name.");

        supplies.MapGet("/{id:guid}/stock-events", ListEvents)
            .WithName("ListStockEvents")
            .WithSummary($"The item's purchases and counts, newest first (the last {EventsShown}).");

        supplies.MapPost("/{id:guid}/stock-events", AddEvent)
            .AllowHelpers()
            .WithName("AddStockEvent")
            .WithSummary("\"Bought two bags\" or \"about half a bag left\"; answers with the new estimate. A purchase of an item no longer bought makes it bought again.");

        supplies.MapDelete("/{id:guid}/stock-events/{eventId:guid}", DeleteEvent)
            .AllowHelpers()
            .WithName("DeleteStockEvent")
            .WithSummary("Take back a purchase or a count entered by mistake.");

        api.MapGet("/products/lookup", Lookup)
            .WithTags("Supplies")
            .WithName("LookupProduct")
            .WithSummary("What a scanned barcode is: the household's item with it, or the product from the catalog, Open Pet Food Facts or UPCitemdb.");

        // Nothing is saved, but the photos count towards the month's AI photos (the plan screen).
        api.MapPost("/products/scan", Scan)
            .RequireRateLimiting(AiEndpoints.RateLimit)
            .ReportsChanges(LiveTopics.Plan)
            .WithTags("Supplies")
            .WithName("ScanProduct")
            .WithSummary("Read photos of a package with AI: name, brand, size, energy, and for a medicine how long a dose protects. Waits for the answer (up to a few minutes). 409 urn:collarbell:problem:ai-limit: not enough AI photos left this month; 409 without a type: AI isn't set up; 429: too many AI requests in a minute; 503: all models are busy.")
            .ProducesProblem(StatusCodes.Status409Conflict)
            .ProducesProblem(StatusCodes.Status429TooManyRequests)
            .ProducesProblem(StatusCodes.Status502BadGateway)
            .ProducesProblem(StatusCodes.Status503ServiceUnavailable);

        return api;
    }

    private static async Task<Ok<List<SupplyResponse>>> List(
        CurrentUserAccessor current, HouseholdCalendar calendar, SupplyStock stock, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var zone = await calendar.TimeZoneAsync(me.HouseholdId, ct);
        var states = await stock.StatesAsync(me.HouseholdId, zone, clock.GetUtcNow(), ct);
        return TypedResults.Ok(states
            .OrderBy(s => !s.Item.Active)
            .ThenBy(s => Urgency(s.Forecast.Status))
            .ThenBy(s => s.Forecast.RunsOutOn ?? DateOnly.MaxValue)
            .ThenBy(s => s.Item.Name, StringComparer.CurrentCultureIgnoreCase)
            .Select(ToResponse)
            .ToList());
    }

    private static async Task<Results<Ok<SupplyResponse>, NotFound>> Get(
        Guid id, CurrentUserAccessor current, HouseholdCalendar calendar, SupplyStock stock, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var state = await StateAsync(me, id, calendar, stock, clock, ct);
        return state is null ? TypedResults.NotFound() : TypedResults.Ok(ToResponse(state));
    }

    private static async Task<Results<Created<SupplyResponse>, ValidationProblem>> Create(
        SupplyRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        HouseholdCalendar calendar,
        SupplyStock stock,
        ProductLookup products,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var errors = Validate(request);
        // Checked against a valid package size only: a huge one would overflow the limit.
        if (request.InitialStock is { } initial && ValidPackageSize(request.PackageSize)
            && (initial < 0 || initial > MaxStock(request.PackageSize)))
        {
            errors.Add("initialStock", "Use an amount from 0 up to a thousand packages.");
        }

        var barcode = Gtin.Normalize(request.Barcode);
        if (barcode is not null && await db.SupplyItems.AnyAsync(i => i.HouseholdId == me.HouseholdId && i.Barcode == barcode, ct))
        {
            errors.Add("barcode", "Another item in supplies has this barcode.");
        }

        if (request.RequestId is { } requestId
            && await db.SupplyItems.AsNoTracking().SingleOrDefaultAsync(i => i.HouseholdId == me.HouseholdId && i.ClientRequestId == requestId, ct)
                is { } earlier)
        {
            // A retry of a create that already went through: answer as the first time.
            return TypedResults.Created($"/api/v1/supplies/{earlier.Id}",
                ToResponse((await StateAsync(me, earlier.Id, calendar, stock, clock, ct))!));
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var now = clock.GetUtcNow();
        var item = new SupplyItem(me.HouseholdId, now) { ClientRequestId = request.RequestId };
        Apply(request, item);
        db.SupplyItems.Add(item);
        if (request.InitialStock is { } stockNow)
        {
            db.StockEvents.Add(new StockEvent(me.HouseholdId, item.Id, StockEventKind.Adjustment, Math.Round(stockNow, 3), me.UserId, now));
        }

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            db.ChangeTracker.Clear();
            if (request.RequestId is { } retried
                && await db.SupplyItems.AsNoTracking().SingleOrDefaultAsync(i => i.HouseholdId == me.HouseholdId && i.ClientRequestId == retried, ct)
                    is { } other)
            {
                // The same create twice at once: the other one made it.
                return TypedResults.Created($"/api/v1/supplies/{other.Id}",
                    ToResponse((await StateAsync(me, other.Id, calendar, stock, clock, ct))!));
            }

            // The same barcode saved from two phones at once.
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["barcode"] = ["Another item in supplies has this barcode."],
            });
        }

        await products.ConfirmAsync(item, request.DataSource ?? SupplyDataSource.Manual, ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Created($"/api/v1/supplies/{item.Id}", ToResponse((await StateAsync(me, item.Id, calendar, stock, clock, ct))!));
    }

    private static async Task<Results<Ok<SupplyResponse>, NotFound, ValidationProblem>> Update(
        Guid id,
        SupplyRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        HouseholdCalendar calendar,
        SupplyStock stock,
        FeedingSupplies feeding,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var item = await db.SupplyItems.SingleOrDefaultAsync(i => i.Id == id && i.HouseholdId == me.HouseholdId, ct);
        if (item is null)
        {
            return TypedResults.NotFound();
        }

        var errors = Validate(request);
        var barcode = Gtin.Normalize(request.Barcode);
        if (barcode is not null && barcode != item.Barcode
            && await db.SupplyItems.AnyAsync(i => i.HouseholdId == me.HouseholdId && i.Barcode == barcode && i.Id != id, ct))
        {
            errors.Add("barcode", "Another item in supplies has this barcode.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        Apply(request, item);
        item.UpdatedAt = clock.GetUtcNow();
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["barcode"] = ["Another item in supplies has this barcode."],
            });
        }

        // Feedings show the food's name; a renamed item renames it there too.
        await feeding.RenameFoodAsync(me.HouseholdId, item.Id, item.Name, ct);
        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Ok(ToResponse((await StateAsync(me, item.Id, calendar, stock, clock, ct))!));
    }

    private static async Task<Results<NoContent, NotFound>> Delete(
        Guid id, CurrentUserAccessor current, AppDbContext db, ReminderSchedule reminders, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var deleted = await db.SupplyItems.Where(i => i.Id == id && i.HouseholdId == me.HouseholdId).ExecuteDeleteAsync(ct);
        if (deleted == 0)
        {
            return TypedResults.NotFound();
        }

        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<List<StockEventResponse>>, NotFound>> ListEvents(
        Guid id, CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        if (!await db.SupplyItems.AnyAsync(i => i.Id == id && i.HouseholdId == me.HouseholdId, ct))
        {
            return TypedResults.NotFound();
        }

        var events = await db.StockEvents.AsNoTracking()
            .Where(e => e.SupplyItemId == id)
            .OrderByDescending(e => e.At)
            .ThenByDescending(e => e.Id)
            .Take(EventsShown)
            .ToListAsync(ct);
        var names = await NamesAsync(db, events.Select(e => e.CreatedBy).OfType<Guid>(), ct);
        return TypedResults.Ok(events.Select(e => ToResponse(e, names, me.UserId)).ToList());
    }

    private static async Task<Results<Created<StockChangeResponse>, Ok<StockChangeResponse>, NotFound, ValidationProblem>> AddEvent(
        Guid id,
        StockEventRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        HouseholdCalendar calendar,
        SupplyStock stock,
        ReminderSchedule reminders,
        TimeProvider clock,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var item = await db.SupplyItems.SingleOrDefaultAsync(i => i.Id == id && i.HouseholdId == me.HouseholdId, ct);
        if (item is null)
        {
            return TypedResults.NotFound();
        }

        if (request.RequestId is { } requestId
            && await db.StockEvents.AsNoTracking().SingleOrDefaultAsync(e => e.HouseholdId == me.HouseholdId && e.ClientRequestId == requestId, ct)
                is { } earlier)
        {
            // A retry of an entry that already went through: the purchase isn't counted twice.
            return TypedResults.Ok(await ChangeAsync(db, earlier, me, calendar, stock, clock, ct));
        }

        var errors = new ValidationErrors();
        if (!Enum.IsDefined(request.Kind))
        {
            errors.Add("kind", "Say whether it is a purchase or a count of what is left.");
        }
        else if (request.Quantity < 0 || (request.Kind == StockEventKind.Purchase && Math.Round(request.Quantity, 3) <= 0)
            || request.Quantity > MaxStock(item.PackageSize))
        {
            errors.Add("quantity", request.Kind == StockEventKind.Purchase
                ? "Use an amount above 0, up to a thousand packages."
                : "Use an amount from 0 up to a thousand packages.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var entry = new StockEvent(me.HouseholdId, item.Id, request.Kind, Math.Round(request.Quantity, 3), me.UserId, clock.GetUtcNow())
        {
            ClientRequestId = request.RequestId,
        };
        db.StockEvents.Add(entry);
        if (request.Kind == StockEventKind.Purchase && !item.Active)
        {
            // Bought again: it is bought, with its estimate and reminders back.
            item.Active = true;
            item.UpdatedAt = entry.At;
        }

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (request.RequestId is not null
            && e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // The same entry twice at once: the other one made it.
            db.ChangeTracker.Clear();
            var other = await db.StockEvents.AsNoTracking()
                .SingleAsync(x => x.HouseholdId == me.HouseholdId && x.ClientRequestId == request.RequestId, ct);
            return TypedResults.Ok(await ChangeAsync(db, other, me, calendar, stock, clock, ct));
        }

        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.Created($"/api/v1/supplies/{item.Id}/stock-events/{entry.Id}",
            await ChangeAsync(db, entry, me, calendar, stock, clock, ct));
    }

    /// <summary>A helper takes back only their own purchase or count.</summary>
    private static async Task<Results<NoContent, NotFound, ProblemHttpResult>> DeleteEvent(
        Guid id, Guid eventId, CurrentUserAccessor current, AppDbContext db, ReminderSchedule reminders, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var entries = db.StockEvents
            .Where(e => e.Id == eventId && e.SupplyItemId == id && e.HouseholdId == me.HouseholdId);
        if (me.Role == HouseholdRole.Helper && await entries.AnyAsync(e => e.CreatedBy != me.UserId, ct))
        {
            return (ProblemHttpResult)HouseholdProblems.RoleCantDoThis();
        }

        var deleted = await entries.ExecuteDeleteAsync(ct);
        if (deleted == 0)
        {
            return TypedResults.NotFound();
        }

        await reminders.RefreshAsync(me.HouseholdId, ct);
        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<ProductLookupResponse>, ValidationProblem>> Lookup(
        string? code, CurrentUserAccessor current, AppDbContext db, ProductLookup products, CancellationToken ct)
    {
        if (ProductCodes.Parse(code) is not { } scanned)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["code"] = ["Not a product barcode (EAN, UPC or a GS1 DataMatrix)."],
            });
        }

        var me = await current.GetAsync(ct);
        var existing = await db.SupplyItems.AsNoTracking()
            .Where(i => i.HouseholdId == me.HouseholdId && i.Barcode == scanned.Gtin)
            .Select(i => new ExistingSupply(i.Id, i.Name, i.Active))
            .SingleOrDefaultAsync(ct);
        if (existing is not null)
        {
            return TypedResults.Ok(new ProductLookupResponse(scanned.Gtin, scanned.Batch, scanned.ExpiresOn, existing, null, null));
        }

        var locale = await db.Users.Where(u => u.Id == me.UserId).Select(u => u.Locale).SingleOrDefaultAsync(ct);
        var (product, source) = await products.FindAsync(scanned.Gtin, locale ?? Locales.English, ct);
        return TypedResults.Ok(new ProductLookupResponse(scanned.Gtin, scanned.Batch, scanned.ExpiresOn, null, product, source));
    }

    /// <summary>
    /// Reads the package at once rather than through a queue like passport scans: one package, a few seconds, and
    /// nothing to lose when it fails, the user just takes the photos again. The photos aren't kept: unattached
    /// uploads are deleted after a day.
    /// </summary>
    private static async Task<Results<Ok<ProductScanResponse>, ValidationProblem, ProblemHttpResult>> Scan(
        ProductScanRequest request,
        CurrentUserAccessor current,
        Files files,
        AiRunner runner,
        Plans plans,
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
        if (request.FileIds is null || request.FileIds.Count is 0 or > MaxScanPhotos)
        {
            errors.Add("fileIds", $"Add 1 to {MaxScanPhotos} photos.");
        }
        else if (await files.CheckFreeAsync(me.HouseholdId, request.FileIds, photosOnly: true, ct) is { } problem)
        {
            errors.Add("fileIds", problem);
        }

        if (Input.Clean(request.Barcode) is not null && ProductCodes.Parse(request.Barcode) is null)
        {
            errors.Add("barcode", "Not a product barcode.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        // The month's AI photos are held before AI reads them: charged if it answers, given back if not (Billing/Plans).
        var (hold, refusal) = await plans.HoldAsync(me.HouseholdId, me.UserId, request.FileIds!.Count, "product-scan", ct);
        if (hold is not { } holdId)
        {
            return refusal!;
        }

        var log = loggers.CreateLogger("Collarbell.Api.Modules.Supplies.ProductScan");
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
                new TextContent(ProductScanPrompt.Text),
                .. photos.Select(p => (AIContent)new DataContent(p.Content, p.File.ContentType)),
            ]);
            var scan = await runner.RunAsync<ProductScan>(AiOptions.Extraction, "product-scan", me.HouseholdId, [message], ct);
            answered = true;
            return TypedResults.Ok(new ProductScanResponse(
                ProductDraft.From(scan.Value, ProductCodes.Parse(request.Barcode)?.Gtin), scan.Model.Model));
        }
        catch (AiUnavailableException e) when (e.NotConfigured)
        {
            return TypedResults.Problem(statusCode: StatusCodes.Status409Conflict, title: "AI isn't set up.");
        }
        catch (AiUnavailableException e)
        {
            // The provider's words stay in the log: they may name the project or internal addresses.
            log.LogWarning(e, "Product scan: no AI model could answer.");
            return TypedResults.Problem(statusCode: StatusCodes.Status503ServiceUnavailable, title: "All AI models are busy; try again later.");
        }
        catch (AiRejectedException e)
        {
            log.LogError(e, "Product scan: the AI provider refused the request.");
            return TypedResults.Problem(statusCode: StatusCodes.Status502BadGateway, title: "The AI provider refused the request.");
        }
        finally
        {
            await plans.SettleAsync(holdId, answered, CancellationToken.None);
        }
    }

    // --- Helpers ------------------------------------------------------------

    private static async Task<SupplyState?> StateAsync(
        CurrentUser me, Guid id, HouseholdCalendar calendar, SupplyStock stock, TimeProvider clock, CancellationToken ct)
    {
        var zone = await calendar.TimeZoneAsync(me.HouseholdId, ct);
        return (await stock.StatesAsync(me.HouseholdId, zone, clock.GetUtcNow(), ct, only: id)).SingleOrDefault();
    }

    private static async Task<StockChangeResponse> ChangeAsync(
        AppDbContext db, StockEvent entry, CurrentUser me, HouseholdCalendar calendar, SupplyStock stock, TimeProvider clock,
        CancellationToken ct)
    {
        var names = await NamesAsync(db, entry.CreatedBy is { } by ? [by] : [], ct);
        var state = (await StateAsync(me, entry.SupplyItemId, calendar, stock, clock, ct))!;
        return new StockChangeResponse(ToResponse(entry, names, me.UserId), ToResponse(state));
    }

    /// <summary>Above 0 as stored (three decimals), up to a million units.</summary>
    private static bool ValidPackageSize(decimal size) => size <= MaxPackageSize && Math.Round(size, 3) > 0;

    /// <summary>Up to a thousand packages, at least a million units (a thousand 1 kg bags).</summary>
    private static decimal MaxStock(decimal packageSize) => Math.Max(packageSize, 1000) * 1000;

    /// <summary>The order on the list: out of stock and "buy now" first, items with no estimate before plenty.</summary>
    private static int Urgency(SupplyStatus status) => status switch
    {
        SupplyStatus.OutOfStock => 0,
        SupplyStatus.BuyNow => 1,
        SupplyStatus.Soon => 2,
        SupplyStatus.NoStock => 3,
        SupplyStatus.NoUsage => 4,
        _ => 5,
    };

    private static void Apply(SupplyRequest request, SupplyItem item)
    {
        item.Name = Input.Clean(request.Name)!;
        item.Brand = Input.Clean(request.Brand);
        item.Barcode = Gtin.Normalize(request.Barcode);
        item.Category = request.Category;
        item.Unit = request.Unit;
        item.PackageSize = Math.Round(request.PackageSize, 3);
        item.KcalPerKg = request.KcalPerKg;
        item.UsageMode = request.UsageMode ?? DefaultUsage(request.Category);
        item.ManualDailyUsage = request.ManualDailyUsage is { } usage ? Math.Round(usage, 6) : null;
        item.LeadTimeDays = request.LeadTimeDays ?? item.LeadTimeDays;
        item.StoreUrl = Input.Clean(request.StoreUrl);
        item.Notes = Input.Clean(request.Notes);
        item.Active = request.Active ?? item.Active;
    }

    /// <summary>Food is counted from the feeding schedules; litter, medication and the rest by hand.</summary>
    public static SupplyUsageMode DefaultUsage(SupplyCategory category) => category switch
    {
        SupplyCategory.DryFood or SupplyCategory.WetFood => SupplyUsageMode.Feeding,
        _ => SupplyUsageMode.Manual,
    };

    private static ValidationErrors Validate(SupplyRequest request)
    {
        var errors = new ValidationErrors();
        var name = Input.Clean(request.Name);
        if (name is null)
        {
            errors.Add("name", "Give the item a name.");
        }

        errors.MaxLength("name", name, 100);
        errors.MaxLength("brand", Input.Clean(request.Brand), 100);
        if (Input.Clean(request.Barcode) is not null && Gtin.Normalize(request.Barcode) is null)
        {
            errors.Add("barcode", "Use the digits of an EAN, UPC or GTIN barcode.");
        }

        if (!Enum.IsDefined(request.Category))
        {
            errors.Add("category", "Unknown category.");
        }

        if (!Enum.IsDefined(request.Unit))
        {
            errors.Add("unit", "Say whether it is counted in grams, millilitres, pieces or doses.");
        }

        if (!ValidPackageSize(request.PackageSize))
        {
            errors.Add("packageSize", "Use a package size above 0.");
        }

        if (request.KcalPerKg is { } kcal && kcal is <= 0 or > 10_000)
        {
            errors.Add("kcalPerKg", "Use 1 to 10 000 kcal per kg.");
        }

        if (request.UsageMode is { } mode && !Enum.IsDefined(mode))
        {
            errors.Add("usageMode", "Unknown way of counting the use.");
        }

        // Checked as stored: 0.0000004 a day would be kept as 0.
        if (request.ManualDailyUsage is { } daily && (Math.Round(daily, 6) <= 0 || daily > MaxPackageSize))
        {
            errors.Add("manualDailyUsage", "Use a daily amount above 0.");
        }

        if (request.LeadTimeDays is { } lead && lead is < 0 or > MaxLeadTimeDays)
        {
            errors.Add("leadTimeDays", $"Use 0 to {MaxLeadTimeDays} days.");
        }

        var url = Input.Clean(request.StoreUrl);
        errors.MaxLength("storeUrl", url, 500);
        if (url is not null && (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme is not ("http" or "https")))
        {
            errors.Add("storeUrl", "Use a web address starting with https://.");
        }

        errors.MaxLength("notes", Input.Clean(request.Notes), 500);
        if (request.DataSource is { } source && !Enum.IsDefined(source))
        {
            errors.Add("dataSource", "Unknown source.");
        }

        return errors;
    }

    private static SupplyResponse ToResponse(SupplyState state)
    {
        var item = state.Item;
        return new SupplyResponse(
            item.Id,
            item.Name,
            item.Brand,
            item.Barcode,
            item.Category,
            item.Unit,
            item.PackageSize,
            item.KcalPerKg,
            item.UsageMode,
            item.ManualDailyUsage,
            item.LeadTimeDays,
            item.StoreUrl,
            item.Notes,
            item.Active,
            state.Forecast,
            [.. state.Feedings
                .OrderBy(f => f.PetName, StringComparer.CurrentCulture)
                .Select(f => new SupplyFeedingResponse(f.RoutineId, f.PetId, f.PetName, f.Amount, f.Unit, Math.Round(f.TimesPerDay, 3),
                    item.UsageMode == SupplyUsageMode.Feeding && SupplyForecasts.Counts(item, f)))],
            item.CreatedAt,
            item.UpdatedAt);
    }

    private static StockEventResponse ToResponse(StockEvent entry, IReadOnlyDictionary<Guid, string?> names, Guid me) =>
        new(entry.Id, entry.Kind, entry.Quantity, entry.At,
            entry.CreatedBy is { } by ? names.GetValueOrDefault(by) : null, entry.CreatedBy == me);

    /// <summary>How people are called: their name, or their email when they have none.</summary>
    private static async Task<Dictionary<Guid, string?>> NamesAsync(AppDbContext db, IEnumerable<Guid> userIds, CancellationToken ct)
    {
        var ids = userIds.Distinct().ToList();
        return await db.Users.AsNoTracking()
            .Where(u => ids.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.DisplayName ?? u.Email, ct);
    }
}

/// <summary>The household's supplies and their purchases and counts, for "Download my data".</summary>
public sealed class SuppliesExport(AppDbContext db) : IHouseholdExportSource
{
    public async Task ExportAsync(HouseholdExport export, CancellationToken ct)
    {
        export.Add("supplies", await db.SupplyItems.AsNoTracking()
            .Where(s => s.HouseholdId == export.HouseholdId)
            .OrderBy(s => s.CreatedAt)
            .ToListAsync(ct));
        export.Add("stockEvents", await db.StockEvents.AsNoTracking()
            .Where(e => e.HouseholdId == export.HouseholdId)
            .OrderBy(e => e.At)
            .ToListAsync(ct));
    }
}
