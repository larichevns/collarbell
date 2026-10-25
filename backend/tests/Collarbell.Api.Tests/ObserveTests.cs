using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Observe;
using Microsoft.EntityFrameworkCore;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>The admin's "визор" and the server's self-checks: the request log, the app's events, alerts.</summary>
[Collection(ApiCollection.Name)]
public sealed class ObserveTests(ApiFactory api)
{
    private static AppEventRequest Event(AppEventKind kind, string name, string? detail = null, DateTimeOffset? at = null) =>
        new((at ?? DateTimeOffset.UtcNow).ToUnixTimeMilliseconds(), kind, name, detail);

    [Fact]
    public async Task Requests_are_noted_with_the_user_household_status_and_launch()
    {
        var client = api.ClientFor($"observe-{Guid.NewGuid():N}");
        var session = Guid.NewGuid();
        client.DefaultRequestHeaders.Add(RequestLogMiddleware.SessionHeader, session.ToString());
        client.DefaultRequestHeaders.Add(RequestLogMiddleware.AppVersionHeader, "0.2.0");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var missing = await client.GetAsync($"/api/v1/pets/{Guid.NewGuid()}?secret=word", Ct);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);

        await api.FlushRequestLogAsync();

        List<RequestRecord> noted = [];
        await api.ChangeDatabaseAsync(async db => noted = await db.Requests.AsNoTracking()
            .Where(r => r.UserId == me.Id).OrderBy(r => r.At).ToListAsync(Ct));
        Assert.Contains(noted, r => r is { Method: "POST", Path: "/api/v1/pets", Status: 201 });
        var notFound = Assert.Single(noted, r => r.Status == 404);
        Assert.DoesNotContain("secret", notFound.Path, StringComparison.Ordinal);
        Assert.All(noted, r =>
        {
            Assert.Equal(me.Household.Id, r.HouseholdId);
            Assert.Equal(session, r.Session);
            Assert.Equal("0.2.0", r.AppVersion);
        });
        Assert.Contains(noted, r => r.Path == $"/api/v1/pets" && r.Method == "POST");
        _ = pet;
    }

    [Fact]
    public async Task The_apps_events_are_kept_within_limits()
    {
        var client = api.ClientFor($"events-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var session = Guid.NewGuid();

        // A phone in Tbilisi, two hours ago in whole seconds: a fixed date would fall out of the 7 days events are kept.
        var at = DateTimeOffset.FromUnixTimeSeconds(DateTimeOffset.UtcNow.AddHours(-2).ToUnixTimeSeconds()).ToOffset(TimeSpan.FromHours(4));
        var sent = await client.PostAsJsonAsync("/api/v1/events", new AppEventsRequest(session, "0.2.0",
        [
            Event(AppEventKind.Screen, "/pets/:id/health", null, at),
            Event(AppEventKind.Error, "network\u0000", "timeout\n", at.AddSeconds(1)),
        ]), Json, Ct);
        Assert.Equal(HttpStatusCode.NoContent, sent.StatusCode);

        List<AppEvent> kept = [];
        await api.ChangeDatabaseAsync(async db => kept = await db.AppEvents.AsNoTracking().Where(e => e.UserId == me.Id).OrderBy(e => e.At).ToListAsync(Ct));
        Assert.Equal(2, kept.Count);
        Assert.All(kept, e => Assert.Equal((session, me.Household.Id, "0.2.0"), (e.Session, e.HouseholdId, e.AppVersion)));
        Assert.Equal(at, kept[0].At); // the moment itself, whatever the phone's time zone
        Assert.Equal(("network", "timeout"), (kept[1].Name, kept[1].Detail)); // control characters dropped

        // A phone's clock a year ahead: the batch moves back as a whole, in its order.
        var ahead = DateTimeOffset.UtcNow.AddYears(1);
        var otherSession = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/v1/events", new AppEventsRequest(otherSession, null,
            [Event(AppEventKind.Screen, "/today", null, ahead), Event(AppEventKind.Screen, "/pets", null, ahead.AddSeconds(3))]), Json, Ct);
        List<AppEvent> moved = [];
        await api.ChangeDatabaseAsync(async db => moved = await db.AppEvents.AsNoTracking().Where(e => e.Session == otherSession).OrderBy(e => e.At).ToListAsync(Ct));
        Assert.Equal(["/today", "/pets"], moved.Select(e => e.Name));
        Assert.True(moved[1].At <= DateTimeOffset.UtcNow.AddMinutes(5));
        Assert.Equal(TimeSpan.FromSeconds(3), moved[1].At - moved[0].At);

        var tooMany = await client.PostAsJsonAsync("/api/v1/events", new AppEventsRequest(session, null,
            [.. Enumerable.Range(0, AppEventsEndpoints.MaxEvents + 1).Select(i => Event(AppEventKind.Action, $"tap {i}"))]), Json, Ct);
        Assert.Equal(HttpStatusCode.BadRequest, tooMany.StatusCode);
        var unnamed = await client.PostAsJsonAsync("/api/v1/events", new AppEventsRequest(session, null, [Event(AppEventKind.Action, " ")]), Json, Ct);
        Assert.Equal(HttpStatusCode.BadRequest, unnamed.StatusCode);
        var noSession = await client.PostAsJsonAsync("/api/v1/events", new AppEventsRequest(Guid.Empty, null, [Event(AppEventKind.Action, "fed")]), Json, Ct);
        Assert.Equal(HttpStatusCode.BadRequest, noSession.StatusCode);
    }

    [Fact]
    public async Task A_strangers_made_up_request_isnt_noted_and_doesnt_spoil_the_others()
    {
        var client = api.ClientFor($"junk-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        using var junk = new HttpRequestMessage(new HttpMethod("PROPPATCH"), "/api/v1/nowhere/\U0001F431");
        await api.CreateClient().SendAsync(junk, Ct);

        await api.FlushRequestLogAsync();

        await api.ChangeDatabaseAsync(async db =>
        {
            Assert.False(await db.Requests.AnyAsync(r => r.Path.StartsWith("/api/v1/nowhere"), Ct));
            Assert.True(await db.Requests.AnyAsync(r => r.UserId == me.Id && r.Path == "/api/v1/me", Ct));
        });
    }

    [Fact]
    public async Task What_is_older_than_a_week_goes()
    {
        var client = api.ClientFor($"old-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var now = DateTimeOffset.UtcNow;
        await api.ChangeDatabaseAsync(async db =>
        {
            db.Requests.Add(new RequestRecord(now.AddDays(-8), me.Id, null, "GET", "/api/v1/today", 200, 5, null, null));
            db.Requests.Add(new RequestRecord(now.AddDays(-6), me.Id, null, "GET", "/api/v1/today", 200, 5, null, null));
            db.AppEvents.Add(new AppEvent(me.Id, null, Guid.NewGuid(), now.AddDays(-8), AppEventKind.Screen, "/old", null, null, now.AddDays(-8)));
            db.AppEvents.Add(new AppEvent(me.Id, null, Guid.NewGuid(), now.AddDays(-6), AppEventKind.Screen, "/recent", null, null, now.AddDays(-6)));
            await db.SaveChangesAsync(Ct);
        });

        await api.RunObserveRetentionAsync(now);

        await api.ChangeDatabaseAsync(async db =>
        {
            Assert.Single(await db.Requests.AsNoTracking().Where(r => r.UserId == me.Id && r.At < now.AddDays(-1)).ToListAsync(Ct));
            Assert.Equal(["/recent"], await db.AppEvents.AsNoTracking().Where(e => e.UserId == me.Id).Select(e => e.Name).ToListAsync(Ct));
        });
    }

    [Fact]
    public async Task Trouble_goes_to_telegram_once_a_while_per_kind()
    {
        // Far in the future, so the requests of the other tests are out of the 15 minutes looked at.
        var at = new DateTimeOffset(2031, 1, 1, 12, 0, 0, TimeSpan.Zero);
        await api.ChangeDatabaseAsync(async db =>
        {
            for (var i = 0; i < 5; i++)
            {
                db.Requests.Add(new RequestRecord(at.AddMinutes(-i), null, null, "GET", "/api/v1/today", 500, 10, null, null));
            }

            await db.SaveChangesAsync(Ct);
        });

        var found = await api.RunAlertChecksAsync(at.AddMinutes(1));
        Assert.Contains("server-errors", found);
        Assert.Single(api.Alerts.Sent, s => s.Contains("Ошибок сервера за 15 минут: 5", StringComparison.Ordinal));

        // Found again a minute later, but told once until a while has passed.
        Assert.Contains("server-errors", await api.RunAlertChecksAsync(at.AddMinutes(2)));
        Assert.Single(api.Alerts.Sent, s => s.Contains("Ошибок сервера", StringComparison.Ordinal));

        // The future this test made doesn't stay for the others.
        await api.ChangeDatabaseAsync(async db =>
        {
            await db.Requests.Where(r => r.At > at.AddDays(-1)).ExecuteDeleteAsync(Ct);
            await db.Alerts.Where(a => a.SentAt > at.AddDays(-1)).ExecuteDeleteAsync(Ct);
        });
    }

    [Fact]
    public void Backups_are_told_about_when_unreadable_a_night_late_or_missing_once_there_is_older_data()
    {
        var now = DateTimeOffset.UtcNow;
        string? KindOf(BackupState? backup, bool dataOlderThanANight = true) =>
            AlertChecks.BackupTrouble(backup, now, dataOlderThanANight)?.Kind;

        Assert.Null(KindOf(null)); // no backup folder: locally
        Assert.Equal("backup-unreadable", KindOf(new BackupState(null, null, Unreadable: true)));
        Assert.Null(KindOf(new BackupState(now.AddHours(-20), 1000, false)));
        Assert.Equal("backup-old", KindOf(new BackupState(now.AddHours(-30), 1000, false)));
        Assert.Equal("backup-missing", KindOf(new BackupState(null, null, false)));
        Assert.Null(KindOf(new BackupState(null, null, false), dataOlderThanANight: false)); // a new server, before its first night
    }
}
