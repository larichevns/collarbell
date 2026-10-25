using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Notifications;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Phones registered for pushes, notification settings, and the test push.</summary>
[Collection(ApiCollection.Name)]
public sealed class NotificationsTests(ApiFactory api)
{
    private static Task<HttpResponseMessage> RegisterAsync(HttpClient client, Guid deviceId, string token) =>
        client.PutAsJsonAsync($"/api/v1/devices/{deviceId}", new RegisterDeviceRequest(DevicePlatform.Android, token, "1.0.0"), Ct);

    private static async Task<NotificationSettingsResponse> SettingsAsync(HttpClient client) =>
        (await client.GetFromJsonAsync<NotificationSettingsResponse>("/api/v1/notifications/settings", Ct))!;

    [Fact]
    public async Task A_phone_registered_again_keeps_one_entry_with_its_newest_token()
    {
        var client = api.ClientFor($"devices-again-{Guid.NewGuid():N}");
        var phone = Guid.NewGuid();
        var newToken = $"token-{Guid.NewGuid():N}";

        await RegisterAsync(client, phone, $"token-{Guid.NewGuid():N}");
        var response = await RegisterAsync(client, phone, newToken);
        await client.PostAsync("/api/v1/notifications/test", null, Ct);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(phone, Assert.Single((await SettingsAsync(client)).Devices).Id);
        Assert.Single(api.Push.To(newToken));
    }

    [Fact]
    public async Task A_token_belongs_to_whoever_registered_it_last()
    {
        var anna = api.ClientFor($"devices-anna-{Guid.NewGuid():N}");
        var boris = api.ClientFor($"devices-boris-{Guid.NewGuid():N}");
        var token = $"token-{Guid.NewGuid():N}";

        // Anna signed out without telling the server; Boris signs in on the same phone after reinstalling the app.
        await RegisterAsync(anna, Guid.NewGuid(), token);
        await RegisterAsync(boris, Guid.NewGuid(), token);

        Assert.Empty((await SettingsAsync(anna)).Devices);
        Assert.Single((await SettingsAsync(boris)).Devices);
    }

    [Fact]
    public async Task Only_its_owner_can_forget_a_phone()
    {
        var owner = api.ClientFor($"devices-owner-{Guid.NewGuid():N}");
        var stranger = api.ClientFor($"devices-stranger-{Guid.NewGuid():N}");
        var phone = Guid.NewGuid();
        await RegisterAsync(owner, phone, $"token-{Guid.NewGuid():N}");

        Assert.Equal(HttpStatusCode.NotFound, (await stranger.DeleteAsync($"/api/v1/devices/{phone}", Ct)).StatusCode);
        Assert.Single((await SettingsAsync(owner)).Devices);
        Assert.Equal(HttpStatusCode.NoContent, (await owner.DeleteAsync($"/api/v1/devices/{phone}", Ct)).StatusCode);
        Assert.Empty((await SettingsAsync(owner)).Devices);
    }

    [Fact]
    public async Task A_phone_needs_a_token()
    {
        var client = api.ClientFor($"devices-invalid-{Guid.NewGuid():N}");

        Assert.Equal(HttpStatusCode.BadRequest, (await RegisterAsync(client, Guid.NewGuid(), " ")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await RegisterAsync(client, Guid.Empty, "token")).StatusCode);
    }

    [Fact]
    public async Task Today_refuses_a_date_out_of_range()
    {
        var client = api.ClientFor($"today-range-{Guid.NewGuid():N}");

        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/v1/today?date=0001-01-01", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/v1/today?date=9999-12-31", Ct)).StatusCode);
    }

    [Fact]
    public async Task Done_with_a_next_date_at_the_end_of_the_calendar_is_refused()
    {
        var client = api.ClientFor($"done-far-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today, 1, IntervalUnit.Year));

        var farNext = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete",
            Done(Today) with { NextDueOn = new DateOnly(9999, 12, 31) }, Ct);
        var farValid = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete",
            Done(Today) with { ValidUntil = new DateOnly(9999, 12, 31) }, Ct);

        Assert.Equal(HttpStatusCode.BadRequest, farNext.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, farValid.StatusCode);
    }

    [Fact]
    public async Task Kinds_of_reminders_are_on_until_turned_off()
    {
        var client = api.ClientFor($"settings-{Guid.NewGuid():N}");

        var before = await SettingsAsync(client);
        var response = await client.PutAsJsonAsync("/api/v1/notifications/settings",
            new UpdateNotificationSettingsRequest([new NotificationCategorySetting(NotificationCategory.Feeding, false)]), Ct);
        var duplicate = await client.PutAsJsonAsync("/api/v1/notifications/settings", new UpdateNotificationSettingsRequest(
        [
            new NotificationCategorySetting(NotificationCategory.Care, false),
            new NotificationCategorySetting(NotificationCategory.Care, true),
        ]), Ct);

        Assert.True(before.PushReady);
        Assert.All(before.Categories, c => Assert.True(c.Enabled));
        var after = (await response.Content.ReadFromJsonAsync<NotificationSettingsResponse>(Ct))!;
        Assert.Equal(
            [
                (NotificationCategory.Feeding, false), (NotificationCategory.Care, true), (NotificationCategory.Appointments, true),
                (NotificationCategory.Supplies, true),
            ],
            after.Categories.Select(c => (c.Category, c.Enabled)));
        Assert.Equal(HttpStatusCode.BadRequest, duplicate.StatusCode);
    }

    [Fact]
    public async Task The_test_push_reaches_the_phones_and_forgets_dead_ones()
    {
        var client = api.ClientFor($"test-push-{Guid.NewGuid():N}");
        var alive = await client.RegisterPhoneAsync();
        var dead = await client.RegisterPhoneAsync();
        api.Push.Results[dead] = PushResult.InvalidToken;

        var result = await client.PostAsync("/api/v1/notifications/test", null, Ct);

        var answer = (await result.Content.ReadFromJsonAsync<TestPushResponse>(Ct))!;
        Assert.Equal((2, 1, (TestPushProblem?)null), (answer.Devices, answer.Delivered, answer.Problem));
        Assert.Equal("Test notification", Assert.Single(api.Push.To(alive)).Title);
        Assert.Single((await SettingsAsync(client)).Devices);
    }

    [Fact]
    public async Task The_test_push_says_why_it_went_nowhere()
    {
        var client = api.ClientFor($"test-push-none-{Guid.NewGuid():N}");

        var noPhones = await (await client.PostAsync("/api/v1/notifications/test", null, Ct))
            .Content.ReadFromJsonAsync<TestPushResponse>(Ct);
        await client.RegisterPhoneAsync();
        api.Push.IsConfigured = false;
        TestPushResponse? noKey;
        try
        {
            noKey = await (await client.PostAsync("/api/v1/notifications/test", null, Ct))
                .Content.ReadFromJsonAsync<TestPushResponse>(Ct);
        }
        finally
        {
            api.Push.IsConfigured = true;
        }

        Assert.Equal(TestPushProblem.NoDevices, noPhones!.Problem);
        Assert.Equal(TestPushProblem.NotConfigured, noKey!.Problem);
    }
}
