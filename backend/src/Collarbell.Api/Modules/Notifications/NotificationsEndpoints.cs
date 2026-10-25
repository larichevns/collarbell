using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Infrastructure.Validation;
using Collarbell.Api.Modules.Identity;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Collarbell.Api.Modules.Notifications;

/// <summary>The phone's Firebase address (token), sent on every app start and whenever Firebase changes it.</summary>
public sealed record RegisterDeviceRequest(DevicePlatform Platform, string Token, string? AppVersion);

public sealed record DeviceResponse(Guid Id, DevicePlatform Platform, string? AppVersion, DateTimeOffset LastSeenAt);

public sealed record NotificationCategorySetting(NotificationCategory Category, bool Enabled);

/// <summary>
/// The notification settings of the signed-in person. <see cref="PushReady"/> is false when the server can't send
/// pushes (no Firebase key); <see cref="Devices"/> are their phones that get pushes.
/// </summary>
public sealed record NotificationSettingsResponse(
    bool PushReady,
    List<NotificationCategorySetting> Categories,
    List<DeviceResponse> Devices);

/// <summary>Kinds left out keep their setting.</summary>
public sealed record UpdateNotificationSettingsRequest(List<NotificationCategorySetting> Categories);

/// <summary>A reminder of the household: planned, or sent (or not) lately.</summary>
public sealed record ReminderResponse(
    Guid Id,
    NotificationCategory Category,
    ReminderSource Source,
    Guid SourceId,
    string Subject,
    DateTimeOffset FireAt,
    ReminderStatus Status,
    ReminderReason? Reason,
    DateTimeOffset? SentAt);

/// <summary>
/// <see cref="Upcoming"/>: what will be reminded in the next <see cref="NotificationsEndpoints.UpcomingDays"/> days,
/// soonest first (feeding is planned two days ahead). <see cref="Recent"/>: what came due in the last
/// <see cref="NotificationsEndpoints.RecentDays"/> days and what happened to it, newest first.
/// </summary>
public sealed record RemindersResponse(List<ReminderResponse> Upcoming, List<ReminderResponse> Recent);

/// <summary>Why the test push didn't arrive anywhere, for the app to explain in the user's language.</summary>
[System.Text.Json.Serialization.JsonConverter(typeof(System.Text.Json.Serialization.JsonStringEnumConverter<TestPushProblem>))]
public enum TestPushProblem
{
    /// <summary>The server has no Firebase key.</summary>
    NotConfigured,

    /// <summary>None of the person's phones is registered for pushes.</summary>
    NoDevices,

    /// <summary>Firebase didn't deliver to any of them.</summary>
    Failed,
}

public sealed record TestPushResponse(int Devices, int Delivered, TestPushProblem? Problem);

public static class Devices
{
    /// <summary>Firebase tokens are about 160 characters; a database index holds up to about 2700 bytes.</summary>
    public const int MaxTokenLength = 1024;
}

public static class NotificationsEndpoints
{
    public const int UpcomingDays = 7;
    public const int RecentDays = 7;
    private const int ListLimit = 100;

    public static RouteGroupBuilder MapNotificationsEndpoints(this RouteGroupBuilder api)
    {
        var devices = api.MapGroup("/devices").WithTags("Notifications");

        devices.MapPut("/{id:guid}", RegisterDevice)
            .Personal()
            .WithName("RegisterDevice")
            .WithSummary("Register this phone for pushes (its id is chosen by the app once); call again when its token changes.");

        devices.MapDelete("/{id:guid}", ForgetDevice)
            .Personal()
            .WithName("ForgetDevice")
            .WithSummary("Stop pushes to this phone, e.g. on sign-out.");

        var notifications = api.MapGroup("/notifications").WithTags("Notifications");

        notifications.MapGet("/settings", GetSettings)
            .Personal()
            .WithName("GetNotificationSettings")
            .WithSummary("Which kinds of reminders the signed-in person gets, and on which phones.");

        notifications.MapPut("/settings", UpdateSettings)
            .Personal()
            .WithName("UpdateNotificationSettings")
            .WithSummary("Turn kinds of reminders on or off.");

        notifications.MapGet("/reminders", ListReminders)
            .WithName("ListReminders")
            .WithSummary($"The household's reminders: the next {UpcomingDays} days, and what happened in the last {RecentDays}.");

        notifications.MapPost("/test", SendTest)
            .Personal()
            .WithName("SendTestNotification")
            .WithSummary("Send a test push to the signed-in person's phones now.");

        return api;
    }

    private static async Task<Results<Ok<DeviceResponse>, ValidationProblem>> RegisterDevice(
        Guid id,
        RegisterDeviceRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        TimeProvider clock,
        CancellationToken ct)
    {
        var errors = new ValidationErrors();
        if (id == Guid.Empty)
        {
            errors.Add("id", "Use a new random id for the phone.");
        }

        if (!Enum.IsDefined(request.Platform))
        {
            errors.Add("platform", "Unknown platform.");
        }

        var token = Input.Clean(request.Token);
        if (token is null)
        {
            errors.Add("token", "Send the phone's push token.");
        }

        errors.MaxLength("token", token, Devices.MaxTokenLength);
        errors.MaxLength("appVersion", Input.Clean(request.AppVersion), 32);
        if (errors.HasErrors)
        {
            return TypedResults.ValidationProblem(errors.ToDictionary());
        }

        var me = await current.GetAsync(ct);
        // Two registrations of the same phone at once: the second one finds the first one's row and updates it.
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                return TypedResults.Ok(await SaveDeviceAsync(db, id, me.UserId, request.Platform, token!, Input.Clean(request.AppVersion), clock.GetUtcNow(), ct));
            }
            catch (DbUpdateException e) when (attempt == 1 && e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
            {
                db.ChangeTracker.Clear();
            }
        }
    }

    /// <summary>
    /// The newest registration wins: the same token under another id is an old installation of the app, and a phone
    /// registered by another person changes hands (they signed out without telling the server).
    /// </summary>
    private static async Task<DeviceResponse> SaveDeviceAsync(
        AppDbContext db, Guid id, Guid userId, DevicePlatform platform, string token, string? appVersion, DateTimeOffset now, CancellationToken ct)
    {
        await db.Devices.Where(d => d.Token == token && d.Id != id).ExecuteDeleteAsync(ct);
        var device = await db.Devices.SingleOrDefaultAsync(d => d.Id == id, ct);
        if (device is null)
        {
            device = new Device(id, userId, platform, token, now);
            db.Devices.Add(device);
        }
        else
        {
            device.Register(userId, platform, token, now);
        }

        device.AppVersion = appVersion;
        await db.SaveChangesAsync(ct);
        return ToResponse(device);
    }

    private static async Task<Results<NoContent, NotFound>> ForgetDevice(
        Guid id, CurrentUserAccessor current, AppDbContext db, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var deleted = await db.Devices.Where(d => d.Id == id && d.UserId == me.UserId).ExecuteDeleteAsync(ct);
        return deleted > 0 ? TypedResults.NoContent() : TypedResults.NotFound();
    }

    private static async Task<Ok<NotificationSettingsResponse>> GetSettings(
        CurrentUserAccessor current, AppDbContext db, IPushSender push, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        return TypedResults.Ok(await LoadSettingsAsync(db, push, me.UserId, ct));
    }

    private static async Task<Results<Ok<NotificationSettingsResponse>, ValidationProblem>> UpdateSettings(
        UpdateNotificationSettingsRequest request,
        CurrentUserAccessor current,
        AppDbContext db,
        IPushSender push,
        CancellationToken ct)
    {
        var categories = request.Categories ?? [];
        if (categories.Any(c => !Enum.IsDefined(c.Category)) || categories.DistinctBy(c => c.Category).Count() != categories.Count)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["categories"] = ["Use each known kind of reminder once."],
            });
        }

        var me = await current.GetAsync(ct);
        var saved = await db.NotificationPreferences.Where(p => p.UserId == me.UserId).ToDictionaryAsync(p => p.Category, ct);
        foreach (var setting in categories)
        {
            if (saved.TryGetValue(setting.Category, out var preference))
            {
                preference.Enabled = setting.Enabled;
            }
            else
            {
                db.NotificationPreferences.Add(new NotificationPreference(me.UserId, setting.Category, setting.Enabled));
            }
        }

        await db.SaveChangesAsync(ct);
        return TypedResults.Ok(await LoadSettingsAsync(db, push, me.UserId, ct));
    }

    private static async Task<NotificationSettingsResponse> LoadSettingsAsync(AppDbContext db, IPushSender push, Guid userId, CancellationToken ct)
    {
        var off = await db.NotificationPreferences
            .Where(p => p.UserId == userId && !p.Enabled)
            .Select(p => p.Category)
            .ToListAsync(ct);
        var devices = await db.Devices.AsNoTracking()
            .Where(d => d.UserId == userId)
            .OrderByDescending(d => d.LastSeenAt)
            .ToListAsync(ct);
        return new NotificationSettingsResponse(
            push.IsConfigured,
            [.. Enum.GetValues<NotificationCategory>().Select(c => new NotificationCategorySetting(c, !off.Contains(c)))],
            [.. devices.Select(ToResponse)]);
    }

    private static async Task<Ok<RemindersResponse>> ListReminders(
        CurrentUserAccessor current, AppDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var now = clock.GetUtcNow();
        var upcomingUntil = now + TimeSpan.FromDays(UpcomingDays);
        var recentFrom = now - TimeSpan.FromDays(RecentDays);

        var upcoming = await db.Reminders.AsNoTracking()
            .Where(r => r.HouseholdId == me.HouseholdId && r.Status == ReminderStatus.Pending && r.FireAt > now && r.FireAt <= upcomingUntil)
            .OrderBy(r => r.FireAt)
            .Take(ListLimit)
            .ToListAsync(ct);
        // Due ones still waiting (the dispatcher is about to send them, or Firebase was busy) are already "recent".
        var recent = await db.Reminders.AsNoTracking()
            .Where(r => r.HouseholdId == me.HouseholdId && r.FireAt <= now && r.FireAt > recentFrom)
            .OrderByDescending(r => r.FireAt)
            .Take(ListLimit)
            .ToListAsync(ct);
        return TypedResults.Ok(new RemindersResponse([.. upcoming.Select(ToResponse)], [.. recent.Select(ToResponse)]));
    }

    private static async Task<Ok<TestPushResponse>> SendTest(
        CurrentUserAccessor current, AppDbContext db, IPushSender push, CancellationToken ct)
    {
        var me = await current.GetAsync(ct);
        var devices = await db.Devices.AsNoTracking().Where(d => d.UserId == me.UserId).ToListAsync(ct);
        if (!push.IsConfigured)
        {
            return TypedResults.Ok(new TestPushResponse(devices.Count, 0, TestPushProblem.NotConfigured));
        }

        if (devices.Count == 0)
        {
            return TypedResults.Ok(new TestPushResponse(0, 0, TestPushProblem.NoDevices));
        }

        var locale = await db.Users.Where(u => u.Id == me.UserId).Select(u => u.Locale).SingleAsync(ct);
        var results = await push.SendAsync(ReminderTexts.Test(locale), [.. devices.Select(d => d.Token)], ct);

        // Phones Firebase no longer knows are forgotten, as when a reminder is sent.
        var dead = devices.Where((_, i) => results[i] == PushResult.InvalidToken).Select(d => d.Token).ToList();
        if (dead.Count > 0)
        {
            await db.Devices.Where(d => dead.Contains(d.Token)).ExecuteDeleteAsync(ct);
        }

        var delivered = results.Count(r => r == PushResult.Delivered);
        return TypedResults.Ok(new TestPushResponse(devices.Count, delivered, delivered > 0 ? null : TestPushProblem.Failed));
    }

    private static DeviceResponse ToResponse(Device device) =>
        new(device.Id, device.Platform, device.AppVersion, device.LastSeenAt);

    private static ReminderResponse ToResponse(Reminder reminder) => new(
        reminder.Id,
        reminder.Category,
        reminder.Source,
        reminder.SourceId,
        reminder.Subject,
        reminder.FireAt,
        reminder.Status,
        reminder.Reason,
        reminder.SentAt);
}

/// <summary>The person's notification settings and phones, for "Download my data".</summary>
public sealed class NotificationsExport(AppDbContext db) : IPersonalExportSource
{
    public async Task ExportAsync(PersonalExport export, CancellationToken ct)
    {
        export.Add("notificationSettings", await db.NotificationPreferences.AsNoTracking()
            .Where(p => p.UserId == export.UserId)
            .Select(p => new { p.Category, p.Enabled })
            .ToListAsync(ct));
        // Without the push address: it is a key to the phone, not something about the person.
        export.Add("phones", await db.Devices.AsNoTracking()
            .Where(d => d.UserId == export.UserId)
            .OrderBy(d => d.CreatedAt)
            .Select(d => new { d.Platform, d.AppVersion, d.CreatedAt, d.LastSeenAt })
            .ToListAsync(ct));
    }
}
