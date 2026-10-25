using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Admin;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Observe;
using Microsoft.EntityFrameworkCore;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>The owner's admin (/api/admin): only for admins; numbers, people, households, the "визор", problems.</summary>
[Collection(ApiCollection.Name)]
public sealed class AdminTests(ApiFactory api)
{
    /// <summary>A signed-in admin: a user like any other, marked in the database as make-admin does.</summary>
    private async Task<HttpClient> AdminAsync()
    {
        var client = api.ClientFor($"admin-{Guid.NewGuid():N}", $"admin-{Guid.NewGuid():N}@example.com");
        var me = await client.MeAsync();
        await api.ChangeDatabaseAsync(db => db.Users.Where(u => u.Id == me.Id).ExecuteUpdateAsync(s => s.SetProperty(u => u.IsAdmin, true), Ct));
        return client;
    }

    [Fact]
    public async Task Only_admins_get_in()
    {
        var someone = api.ClientFor($"someone-{Guid.NewGuid():N}");
        foreach (var path in new[] { "/api/admin/me", "/api/admin/overview", "/api/admin/users", "/api/admin/problems" })
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await someone.GetAsync(path, Ct)).StatusCode);
        }

        Assert.Equal(HttpStatusCode.Unauthorized, (await api.CreateClient().GetAsync("/api/admin/me", Ct)).StatusCode);

        var admin = await AdminAsync();
        var me = await admin.GetFromJsonAsync<AdminMe>("/api/admin/me", Json, Ct);
        Assert.EndsWith("@example.com", me!.Email, StringComparison.Ordinal);
    }

    [Fact]
    public async Task The_overview_counts_people_reminders_and_the_server()
    {
        var admin = await AdminAsync();
        await api.ClientFor($"counted-{Guid.NewGuid():N}").CreatePetAsync("Murka");

        var overview = await admin.GetFromJsonAsync<AdminOverview>("/api/admin/overview", Json, Ct);

        Assert.True(overview!.People.Users >= 2);
        Assert.True(overview.People.Pets >= 1);
        Assert.True(overview.People.NewWeek >= 2);
        Assert.True(overview.Server.DiskTotalBytes > 0);
        Assert.False(overview.Alerts.TelegramConfigured);
        Assert.Null(overview.Server.LastBackupAt); // no backups in the tests
    }

    [Fact]
    public async Task A_person_found_by_email_with_households_and_their_week_in_the_visor()
    {
        var admin = await AdminAsync();
        var tag = Guid.NewGuid().ToString("N");
        var person = api.ClientFor($"person-{tag}", $"person-{tag}@example.com");
        var session = Guid.NewGuid();
        person.DefaultRequestHeaders.Add(RequestLogMiddleware.SessionHeader, session.ToString());
        var me = await person.MeAsync();
        await person.CreatePetAsync("Barsik");
        await person.PostAsJsonAsync("/api/v1/events", new AppEventsRequest(session, "0.2.0",
            [new AppEventRequest(DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(), AppEventKind.Screen, "/pets", null)]), Json, Ct);
        await api.FlushRequestLogAsync();

        var found = await admin.GetFromJsonAsync<List<AdminUserRow>>($"/api/admin/users?query={tag}", Json, Ct);
        var row = Assert.Single(found!);
        Assert.Equal(me.Id, row.Id);
        Assert.Equal(1, row.Households);
        Assert.NotNull(row.LastSeenAt);

        var details = await admin.GetFromJsonAsync<AdminUser>($"/api/admin/users/{me.Id}", Json, Ct);
        var household = Assert.Single(details!.Households);
        Assert.Equal((HouseholdRole.Owner, 1, 1), (household.Role, household.MemberCount, household.Pets));

        var timeline = (await admin.GetFromJsonAsync<List<AdminTimelineItem>>($"/api/admin/users/{me.Id}/timeline", Json, Ct))!;
        Assert.Contains(timeline, i => i is { Kind: "request", Text: "POST /api/v1/pets", Status: 201 });
        Assert.Contains(timeline, i => i is { Kind: "screen", Text: "/pets" });
        Assert.Equal(timeline.OrderByDescending(i => i.At).Select(i => i.At), timeline.Select(i => i.At));

        // A page of one, then the next one from where it stopped.
        var first = Assert.Single((await admin.GetFromJsonAsync<List<AdminTimelineItem>>($"/api/admin/users/{me.Id}/timeline?limit=1", Json, Ct))!);
        var next = await admin.GetFromJsonAsync<List<AdminTimelineItem>>(
            $"/api/admin/users/{me.Id}/timeline?limit=1&before={Uri.EscapeDataString(first.At.ToString("O"))}", Json, Ct);
        Assert.True(Assert.Single(next!).At < first.At);

        var group = await admin.GetFromJsonAsync<AdminHousehold>($"/api/admin/households/{household.Id}", Json, Ct);
        Assert.Equal((1, me.Id), (group!.Pets, Assert.Single(group.Members).UserId));
        Assert.Equal(HttpStatusCode.NotFound, (await admin.GetAsync($"/api/admin/users/{Guid.NewGuid()}", Ct)).StatusCode);
    }

    [Fact]
    public async Task Problems_list_server_errors_and_what_the_app_saw()
    {
        var admin = await AdminAsync();
        var person = api.ClientFor($"trouble-{Guid.NewGuid():N}");
        var me = await person.MeAsync();
        var now = DateTimeOffset.UtcNow;
        await api.ChangeDatabaseAsync(async db =>
        {
            db.Requests.Add(new RequestRecord(now, me.Id, me.Household.Id, "POST", "/api/v1/ai-imports", 500, 30, null, null));
            await db.SaveChangesAsync(Ct);
        });
        await person.PostAsJsonAsync("/api/v1/events", new AppEventsRequest(Guid.NewGuid(), "0.2.0",
            [new AppEventRequest(now.ToUnixTimeMilliseconds(), AppEventKind.Crash, "StateError", "today_screen.dart:120")]), Json, Ct);

        var problems = await admin.GetFromJsonAsync<List<AdminProblem>>("/api/admin/problems?hours=1", Json, Ct);

        Assert.Contains(problems!, p => p is { Kind: "server", Status: 500, Path: "/api/v1/ai-imports" } && p.UserId == me.Id);
        Assert.Contains(problems!, p => p.Kind == "crash" && p.UserId == me.Id && p.Text.StartsWith("StateError", StringComparison.Ordinal));
    }
}
