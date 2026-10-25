using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Observe;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Collarbell.Api.Modules.Admin;

public sealed record AdminMe(string? Email, string? DisplayName);

public sealed record AdminPeople(
    int Users, int Households, int SharedHouseholds, int PremiumHouseholds, int Pets, int ActiveToday, int ActiveWeek, int NewWeek);

public sealed record AdminReminders(int Sent24h, int Failed24h, int Skipped24h, int Expired24h, int Pending, int OldestOverdueMinutes);

public sealed record AdminAppVersion(string Version, int Devices);

public sealed record AdminDevices(int Android, int Ios, List<AdminAppVersion> AppVersions);

public sealed record AdminModel(string Model, int Calls, int Failed);

public sealed record AdminAi(int Calls24h, int Failed24h, int Calls30d, int Failed30d, long InputTokens30d, long OutputTokens30d, List<AdminModel> Models30d);

public sealed record AdminApi(int Requests24h, int ServerErrors24h, int AppErrors24h, int Crashes24h);

public sealed record AdminServer(long DiskTotalBytes, long DiskFreeBytes, DateTimeOffset? LastBackupAt, long? LastBackupBytes);

public sealed record AdminAlert(string Kind, string Text, DateTimeOffset SentAt);

public sealed record AdminAlerts(bool TelegramConfigured, List<AdminAlert> Recent);

public sealed record AdminOverview(
    DateTimeOffset GeneratedAt,
    AdminPeople People,
    AdminReminders Reminders,
    AdminDevices Devices,
    AdminAi Ai,
    AdminApi Api,
    AdminServer Server,
    AdminAlerts Alerts);

public sealed record AdminUserRow(
    Guid Id, string? Email, string? DisplayName, DateTimeOffset CreatedAt, DateTimeOffset? LastSeenAt, int Households, int Devices, int AiCalls30d);

public sealed record AdminUserHousehold(Guid Id, string Name, HouseholdRole Role, int MemberCount, int Pets, PlanKind Plan);

public sealed record AdminDevice(DevicePlatform Platform, string? AppVersion, DateTimeOffset LastSeenAt);

public sealed record AdminUserAi(int Calls30d, int Failed30d, long InputTokens30d, long OutputTokens30d);

public sealed record AdminUser(
    Guid Id,
    string? Email,
    string? DisplayName,
    string Locale,
    string TimeZone,
    DateTimeOffset CreatedAt,
    DateTimeOffset? LastSeenAt,
    List<AdminUserHousehold> Households,
    List<AdminDevice> Devices,
    AdminUserAi Ai);

/// <param name="Kind">request, screen, action, error or crash.</param>
public sealed record AdminTimelineItem(
    DateTimeOffset At, string Kind, string Text, int? Status, int? DurationMs, Guid? Session, Guid? HouseholdId, string? AppVersion);

public sealed record AdminHouseholdMember(Guid UserId, string? Email, string? DisplayName, HouseholdRole Role, DateTimeOffset JoinedAt);

/// <summary>The household's plan: what works now, the last change, and this month's AI photos.</summary>
/// <param name="Plan">What works now: a Premium past its end is Free.</param>
/// <param name="Source">Who made the last change (Manual: an admin); null when nobody did, the household was always Free.</param>
/// <param name="ExpiresAt">The given Premium's end, also when it has passed; null: no end.</param>
/// <param name="ChangedBy">The admin's e-mail.</param>
public sealed record AdminPlan(
    PlanKind Plan,
    PlanSource? Source,
    DateTimeOffset? ExpiresAt,
    string? Note,
    DateTimeOffset? ChangedAt,
    string? ChangedBy,
    int AiPhotosUsed,
    int AiPhotosPerMonth);

/// <summary>Give Premium (until <see cref="ExpiresAt"/>, or with no end) or take it back (Free).</summary>
/// <param name="Plan">Required: a request without it must not take Premium away by accident.</param>
/// <param name="ExpiresAt">Premium's last moment, any offset (kept in UTC); null: no end.</param>
public sealed record AdminPlanRequest(PlanKind? Plan, DateTimeOffset? ExpiresAt, string? Note);

public sealed record AdminHousehold(
    Guid Id,
    string Name,
    string TimeZone,
    DateTimeOffset CreatedAt,
    List<AdminHouseholdMember> Members,
    int Pets,
    int Routines,
    int CarePlans,
    int Supplies,
    int OpenInvites,
    AdminPlan Plan);

/// <param name="Kind">server (a 5xx answer), app-error (an error the person saw) or crash.</param>
public sealed record AdminProblem(DateTimeOffset At, string Kind, Guid? UserId, string? Email, string Text, string? Path, int? Status);

/// <summary>
/// The owner's admin (the web app at /admin): numbers about the service, people and their households, and the "визор"
/// (a person's last week: their requests and what their app reported). Only users marked as admins
/// (<c>dotnet Collarbell.Api.dll make-admin &lt;e-mail&gt;</c> on the server); not part of the app's API contract.
/// </summary>
public static class AdminEndpoints
{
    public static RouteGroupBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var admin = app.MapGroup("/api/admin")
            .RequireAuthorization()
            .AddEndpointFilter<AdminOnlyFilter>()
            .ExcludeFromDescription();

        admin.MapGet("/me", Me);
        admin.MapGet("/overview", Overview);
        admin.MapGet("/users", Users);
        admin.MapGet("/users/{id:guid}", UserDetails);
        admin.MapGet("/users/{id:guid}/timeline", Timeline);
        admin.MapGet("/households/{id:guid}", HouseholdDetails);
        admin.MapPut("/households/{id:guid}/plan", SetPlan);
        admin.MapGet("/problems", Problems);
        return admin;
    }

    private static async Task<Ok<AdminMe>> Me(CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == me.UserId, ct);
        return TypedResults.Ok(new AdminMe(user.Email, user.DisplayName));
    }

    private static async Task<Ok<AdminOverview>> Overview(
        AppDbContext db, TimeProvider clock, IOptions<AlertsOptions> alerts, IOptions<ObserveOptions> observe, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var day = now - TimeSpan.FromDays(1);
        var week = now - TimeSpan.FromDays(7);
        var month = now - TimeSpan.FromDays(30);

        var people = new AdminPeople(
            await db.Users.CountAsync(ct),
            await db.Households.CountAsync(ct),
            await db.HouseholdMembers.GroupBy(m => m.HouseholdId).Where(g => g.Count() > 1).CountAsync(ct),
            await db.HouseholdPlans.CountAsync(p => p.Plan == PlanKind.Premium && (p.ExpiresAt == null || p.ExpiresAt > now), ct),
            await db.Pets.CountAsync(ct),
            await db.Requests.Where(r => r.At > day && r.UserId != null).Select(r => r.UserId).Distinct().CountAsync(ct),
            await db.Requests.Where(r => r.At > week && r.UserId != null).Select(r => r.UserId).Distinct().CountAsync(ct),
            await db.Users.CountAsync(u => u.CreatedAt > week, ct));

        var byStatus = await db.Reminders.Where(r => r.FireAt > day && r.FireAt <= now)
            .GroupBy(r => r.Status)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count, ct);
        var oldestDue = await db.Reminders.Where(r => r.Status == ReminderStatus.Pending && r.FireAt <= now)
            .OrderBy(r => r.FireAt).Select(r => (DateTimeOffset?)r.FireAt).FirstOrDefaultAsync(ct);
        var reminders = new AdminReminders(
            byStatus.GetValueOrDefault(ReminderStatus.Sent),
            byStatus.GetValueOrDefault(ReminderStatus.Failed),
            byStatus.GetValueOrDefault(ReminderStatus.Skipped),
            byStatus.GetValueOrDefault(ReminderStatus.Expired),
            await db.Reminders.CountAsync(r => r.Status == ReminderStatus.Pending, ct),
            oldestDue is { } due ? Math.Max(0, (int)(now - due).TotalMinutes) : 0);

        var platforms = await db.Devices.GroupBy(d => d.Platform).Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count, ct);
        var versions = await db.Devices.GroupBy(d => d.AppVersion ?? "?")
            .Select(g => new AdminAppVersion(g.Key, g.Count()))
            .ToListAsync(ct);
        var devices = new AdminDevices(platforms.GetValueOrDefault(DevicePlatform.Android), platforms.GetValueOrDefault(DevicePlatform.Ios),
            [.. versions.OrderByDescending(v => v.Devices)]);

        var usage = db.AiUsage.Where(u => u.CreatedAt > month);
        var models = await usage.GroupBy(u => u.Model)
            .Select(g => new AdminModel(g.Key, g.Count(), g.Count(u => !u.Success)))
            .ToListAsync(ct);
        var ai = new AdminAi(
            await db.AiUsage.CountAsync(u => u.CreatedAt > day, ct),
            await db.AiUsage.CountAsync(u => u.CreatedAt > day && !u.Success, ct),
            models.Sum(m => m.Calls),
            models.Sum(m => m.Failed),
            await usage.SumAsync(u => u.InputTokens ?? 0, ct),
            await usage.SumAsync(u => u.OutputTokens ?? 0, ct),
            [.. models.OrderByDescending(m => m.Calls)]);

        var api = new AdminApi(
            await db.Requests.CountAsync(r => r.At > day, ct),
            await db.Requests.CountAsync(r => r.At > day && r.Status >= 500, ct),
            await db.AppEvents.CountAsync(e => e.At > day && e.Kind == AppEventKind.Error, ct),
            await db.AppEvents.CountAsync(e => e.At > day && e.Kind == AppEventKind.Crash, ct));

        var disk = ServerState.Disk();
        var backup = ServerState.LastBackup(observe.Value.BackupDir);
        var server = new AdminServer(disk.TotalBytes, disk.FreeBytes, backup?.At, backup?.Bytes);

        var recent = await db.Alerts.AsNoTracking().OrderByDescending(a => a.SentAt).Take(10)
            .Select(a => new AdminAlert(a.Kind, a.Text, a.SentAt)).ToListAsync(ct);

        return TypedResults.Ok(new AdminOverview(now, people, reminders, devices, ai, api, server,
            new AdminAlerts(alerts.Value.TelegramConfigured, recent)));
    }

    private static async Task<Ok<List<AdminUserRow>>> Users(string? query, int? limit, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var month = clock.GetUtcNow() - TimeSpan.FromDays(30);
        var users = db.Users.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(query))
        {
            var pattern = $"%{query.Trim()}%";
            users = users.Where(u => EF.Functions.ILike(u.Email ?? "", pattern) || EF.Functions.ILike(u.DisplayName ?? "", pattern));
        }

        var rows = await users
            .OrderByDescending(u => u.CreatedAt)
            .Take(Math.Clamp(limit ?? 50, 1, 200))
            .Select(u => new AdminUserRow(
                u.Id,
                u.Email,
                u.DisplayName,
                u.CreatedAt,
                db.Requests.Where(r => r.UserId == u.Id).Max(r => (DateTimeOffset?)r.At)
                    ?? db.Devices.Where(d => d.UserId == u.Id).Max(d => (DateTimeOffset?)d.LastSeenAt),
                db.HouseholdMembers.Count(m => m.UserId == u.Id),
                db.Devices.Count(d => d.UserId == u.Id),
                db.AiUsage.Count(a => a.CreatedAt > month && db.HouseholdMembers.Any(m => m.UserId == u.Id && m.HouseholdId == a.HouseholdId))))
            .ToListAsync(ct);
        return TypedResults.Ok(rows);
    }

    private static async Task<Results<Ok<AdminUser>, NotFound>> UserDetails(Guid id, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(u => u.Id == id, ct);
        if (user is null)
        {
            return TypedResults.NotFound();
        }

        var now = clock.GetUtcNow();
        var month = now - TimeSpan.FromDays(30);
        var households = await (from m in db.HouseholdMembers
                                where m.UserId == id
                                join h in db.Households on m.HouseholdId equals h.Id
                                orderby m.JoinedAt
                                select new AdminUserHousehold(h.Id, h.Name, m.Role,
                                    db.HouseholdMembers.Count(x => x.HouseholdId == h.Id),
                                    db.Pets.Count(p => p.HouseholdId == h.Id),
                                    db.HouseholdPlans.Any(p => p.HouseholdId == h.Id && p.Plan == PlanKind.Premium
                                        && (p.ExpiresAt == null || p.ExpiresAt > now))
                                        ? PlanKind.Premium
                                        : PlanKind.Free))
            .ToListAsync(ct);
        var devices = await db.Devices.AsNoTracking().Where(d => d.UserId == id).OrderByDescending(d => d.LastSeenAt)
            .Select(d => new AdminDevice(d.Platform, d.AppVersion, d.LastSeenAt)).ToListAsync(ct);
        var householdIds = households.Select(h => h.Id).ToList();
        var usage = db.AiUsage.Where(a => a.CreatedAt > month && householdIds.Contains(a.HouseholdId));
        var ai = new AdminUserAi(
            await usage.CountAsync(ct),
            await usage.CountAsync(a => !a.Success, ct),
            await usage.SumAsync(a => a.InputTokens ?? 0, ct),
            await usage.SumAsync(a => a.OutputTokens ?? 0, ct));
        var lastSeen = await db.Requests.Where(r => r.UserId == id).MaxAsync(r => (DateTimeOffset?)r.At, ct)
            ?? devices.Select(d => (DateTimeOffset?)d.LastSeenAt).FirstOrDefault();

        return TypedResults.Ok(new AdminUser(user.Id, user.Email, user.DisplayName, user.Locale, user.TimeZone, user.CreatedAt, lastSeen,
            households, devices, ai));
    }

    /// <summary>The "визор": the person's requests and app events, newest first, merged by time.</summary>
    private static async Task<Ok<List<AdminTimelineItem>>> Timeline(
        Guid id, DateTimeOffset? before, int? limit, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var take = Math.Clamp(limit ?? 200, 1, 500);
        var until = before ?? clock.GetUtcNow() + TimeSpan.FromMinutes(5);
        var requests = await db.Requests.AsNoTracking()
            .Where(r => r.UserId == id && r.At < until)
            .OrderByDescending(r => r.At).Take(take)
            .Select(r => new AdminTimelineItem(r.At, "request", r.Method + " " + r.Path, r.Status, r.DurationMs, r.Session, r.HouseholdId,
                r.AppVersion))
            .ToListAsync(ct);
        var events = await db.AppEvents.AsNoTracking()
            .Where(e => e.UserId == id && e.At < until)
            .OrderByDescending(e => e.At).Take(take)
            .Select(e => new { e.At, e.Kind, e.Name, e.Detail, e.Session, e.HouseholdId, e.AppVersion })
            .ToListAsync(ct);
        var items = requests.Concat(events.Select(e => new AdminTimelineItem(e.At, e.Kind.ToString().ToLowerInvariant(),
                e.Detail is null ? e.Name : $"{e.Name} · {e.Detail}", null, null, e.Session, e.HouseholdId, e.AppVersion)))
            .OrderByDescending(i => i.At)
            .Take(take)
            .ToList();
        return TypedResults.Ok(items);
    }

    private static async Task<Results<Ok<AdminHousehold>, NotFound>> HouseholdDetails(
        Guid id, AppDbContext db, Plans plans, TimeProvider clock, CancellationToken ct)
    {
        var household = await db.Households.AsNoTracking().SingleOrDefaultAsync(h => h.Id == id, ct);
        if (household is null)
        {
            return TypedResults.NotFound();
        }

        var now = clock.GetUtcNow();
        var members = await (from m in db.HouseholdMembers
                             where m.HouseholdId == id
                             join u in db.Users on m.UserId equals u.Id
                             orderby m.JoinedAt
                             select new AdminHouseholdMember(u.Id, u.Email, u.DisplayName, m.Role, m.JoinedAt))
            .ToListAsync(ct);
        return TypedResults.Ok(new AdminHousehold(household.Id, household.Name, household.TimeZone, household.CreatedAt, members,
            await db.Pets.CountAsync(p => p.HouseholdId == id, ct),
            await db.Routines.CountAsync(r => r.HouseholdId == id, ct),
            await db.CarePlans.CountAsync(p => p.HouseholdId == id, ct),
            await db.SupplyItems.CountAsync(s => s.HouseholdId == id, ct),
            await db.HouseholdInvites.CountAsync(i => i.HouseholdId == id && i.AcceptedAt == null && i.RevokedAt == null && i.ExpiresAt > now, ct),
            await PlanOfAsync(id, db, plans, ct)));
    }

    /// <summary>
    /// Gives Premium or takes it back, by hand (testers, friends, support) until payments come. Premium may end on a
    /// date; then the household is Free again by itself.
    /// </summary>
    private static async Task<Results<Ok<AdminPlan>, NotFound, ValidationProblem>> SetPlan(
        Guid id,
        AdminPlanRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        Plans plans,
        LiveChanges live,
        TimeProvider clock,
        ILogger<Plans> log,
        CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var now = clock.GetUtcNow();
        var note = Input.Clean(request.Note);
        // The database keeps moments in UTC and refuses others.
        var expiresAt = request.ExpiresAt?.ToUniversalTime();
        var errors = new ValidationErrors();
        if (request.Plan is not { } plan || !Enum.IsDefined(plan))
        {
            errors.Add("plan", "Free or Premium.");
        }
        else if (plan == PlanKind.Premium && expiresAt <= now)
        {
            errors.Add("expiresAt", "Premium can only end in the future.");
        }

        if (note?.Length > HouseholdPlan.MaxNoteLength)
        {
            errors.Add("note", $"At most {HouseholdPlan.MaxNoteLength} characters.");
        }

        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        if (!await db.Households.AnyAsync(h => h.Id == id, ct))
        {
            return TypedResults.NotFound();
        }

        var newPlan = request.Plan!.Value;
        async Task SetOnce()
        {
            var row = await db.HouseholdPlans.SingleOrDefaultAsync(p => p.HouseholdId == id, ct);
            if (row is null)
            {
                row = new HouseholdPlan(id);
                db.HouseholdPlans.Add(row);
            }

            row.Set(newPlan, PlanSource.Manual, expiresAt, note, me.UserId, now);
            await db.SaveChangesAsync(ct);
        }

        try
        {
            await SetOnce();
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // Another admin's first change of this household came a moment earlier: change that one.
            db.ChangeTracker.Clear();
            await SetOnce();
        }

        log.LogInformation("Admin {AdminId} set household {HouseholdId} to {Plan} until {ExpiresAt}.",
            me.UserId, id, newPlan, newPlan == PlanKind.Premium ? expiresAt : null);
        await live.ChangedAsync(id, [LiveTopics.Plan]);
        return TypedResults.Ok(await PlanOfAsync(id, db, plans, ct));
    }

    private static async Task<AdminPlan> PlanOfAsync(Guid householdId, AppDbContext db, Plans plans, CancellationToken ct)
    {
        var row = await db.HouseholdPlans.AsNoTracking().SingleOrDefaultAsync(p => p.HouseholdId == householdId, ct);
        var changedBy = row?.ChangedBy is { } adminId
            ? await db.Users.Where(u => u.Id == adminId).Select(u => u.Email).SingleOrDefaultAsync(ct)
            : null;
        var plan = plans.Effective(row);
        return new AdminPlan(plan.Plan, row?.Source, row?.ExpiresAt, row?.Note, row?.ChangedAt, changedBy,
            await plans.AiPhotosUsedAsync(householdId, ct), plan.AiPhotosPerMonth);
    }

    private static async Task<Ok<List<AdminProblem>>> Problems(int? hours, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var since = clock.GetUtcNow() - TimeSpan.FromHours(Math.Clamp(hours ?? 24, 1, 24 * 7));
        var server = await (from r in db.Requests
                            where r.At > since && r.Status >= 500
                            join u in db.Users on r.UserId equals (Guid?)u.Id into users
                            from u in users.DefaultIfEmpty()
                            orderby r.At descending
                            select new AdminProblem(r.At, "server", r.UserId, u.Email, r.Method + " " + r.Path + " → " + r.Status.ToString(), r.Path, r.Status))
            .Take(300).ToListAsync(ct);
        var app = await (from e in db.AppEvents
                         where e.At > since && (e.Kind == AppEventKind.Error || e.Kind == AppEventKind.Crash)
                         join u in db.Users on e.UserId equals u.Id
                         orderby e.At descending
                         select new { e.At, e.Kind, e.UserId, u.Email, e.Name, e.Detail })
            .Take(300).ToListAsync(ct);
        return TypedResults.Ok(server
            .Concat(app.Select(e => new AdminProblem(e.At, e.Kind == AppEventKind.Crash ? "crash" : "app-error", e.UserId, e.Email,
                e.Detail is null ? e.Name : $"{e.Name} · {e.Detail}", null, null)))
            .OrderByDescending(p => p.At)
            .Take(300)
            .ToList());
    }
}

/// <summary>Only users marked as admins get past; others get 403 (the app's own API doesn't change for them).</summary>
public sealed class AdminOnlyFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        var accessor = http.RequestServices.GetRequiredService<CurrentUserAccessor>();
        accessor.AnyHouseholdWillDo = true;
        CurrentUser me;
        try
        {
            me = await accessor.GetAsync(http.RequestAborted);
        }
        catch (AccountDeletedException)
        {
            return AccountProblems.AccountDeleted();
        }

        var db = http.RequestServices.GetRequiredService<AppDbContext>();
        var isAdmin = await db.Users.Where(u => u.Id == me.UserId).Select(u => u.IsAdmin).SingleAsync(http.RequestAborted);
        return isAdmin
            ? await next(context)
            : TypedResults.Problem(statusCode: StatusCodes.Status403Forbidden, title: "Admins only.");
    }
}
