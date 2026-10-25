using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Observe;
using Collarbell.Api.Modules.Pets;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Lets a test act in the middle of an account deletion, inside its transaction.</summary>
public sealed class DeletionHooks
{
    /// <summary>Called for each household being deleted, after the real modules queued its files.</summary>
    public Func<Guid, Task>? DuringHouseholdDeletion { get; set; }

    /// <summary>Called before the user's row goes, after the real modules.</summary>
    public Func<Guid, Task>? DuringAccountDeletion { get; set; }
}

internal sealed class HookedHouseholdDeletion(DeletionHooks hooks) : IHouseholdDeletionHandler
{
    public Task BeforeHouseholdDeletedAsync(Guid householdId, CancellationToken ct) =>
        hooks.DuringHouseholdDeletion?.Invoke(householdId) ?? Task.CompletedTask;
}

internal sealed class HookedAccountDeletion(DeletionHooks hooks) : IAccountDeletionHandler
{
    public Task BeforeAccountDeletedAsync(Guid userId, CancellationToken ct) =>
        hooks.DuringAccountDeletion?.Invoke(userId) ?? Task.CompletedTask;
}

/// <summary>
/// Another phone at the very moment an account is deleted (found by the review of the deletion): the same API and
/// containers, plus hooks after the real deletion handlers. A hook starts the other request while the deletion holds its
/// locks, gives it a moment to reach them, and lets the deletion go on; the test then looks at both answers.
/// </summary>
[Collection(ApiCollection.Name)]
public sealed class AccountDeletionRaceTests : IAsyncDisposable
{
    private readonly ApiFactory _api;
    private readonly DeletionHooks _hooks = new();
    private readonly WebApplicationFactory<Program> _factory;

    public AccountDeletionRaceTests(ApiFactory api)
    {
        _api = api;
        _factory = api.WithWebHostBuilder(b => b.ConfigureServices(services =>
        {
            services.AddSingleton(_hooks);
            services.AddScoped<IHouseholdDeletionHandler, HookedHouseholdDeletion>();
            services.AddScoped<IAccountDeletionHandler, HookedAccountDeletion>();
        }));
    }

    public async ValueTask DisposeAsync() => await _factory.DisposeAsync();

    private static string Uid(string name) => $"{name}-{Guid.NewGuid():N}";

    private HttpClient ClientFor(string uid, string? email = null)
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add(DevUserAuthenticationHandler.UserHeader, uid);
        if (email is not null)
        {
            client.DefaultRequestHeaders.Add(DevUserAuthenticationHandler.EmailHeader, email);
        }

        return client;
    }

    /// <summary>Starts <paramref name="request"/> now and gives it a second to get as far as it can.</summary>
    private static async Task<Task<HttpResponseMessage>> StartAsync(Func<Task<HttpResponseMessage>> request)
    {
        var started = request();
        await Task.Delay(TimeSpan.FromSeconds(1), Ct);
        return started;
    }

    [Fact]
    public async Task Someone_who_accepts_an_invite_during_the_deletion_isnt_told_he_joined()
    {
        var anna = ClientFor(Uid("anna"));
        var householdId = (await anna.MeAsync()).Household.Id;
        await anna.CreatePetAsync("Murka");
        var invite = (await (await anna.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Member), Json, Ct)).Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct))!;
        var borisUid = Uid("boris");
        var boris = ClientFor(borisUid, $"{borisUid}@example.com");
        await boris.MeAsync();

        Task<HttpResponseMessage>? accept = null;
        _hooks.DuringHouseholdDeletion = async id =>
        {
            if (id == householdId)
            {
                accept = await StartAsync(() => boris.PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(invite.Code), Json, Ct));
            }
        };

        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);

        // He waited for the household and found it gone with its codes, as if he had come a moment later.
        Assert.Equal(HttpStatusCode.NotFound, (await accept!).StatusCode);
        var his = (await boris.GetFromJsonAsync<List<HouseholdSummary>>("/api/v1/households", Json, Ct))!;
        Assert.DoesNotContain(his, h => h.Id == householdId);
    }

    [Fact]
    public async Task A_photo_uploaded_during_the_deletion_leaves_nothing_in_storage()
    {
        var annaUid = Uid("anna");
        var anna = ClientFor(annaUid);
        var householdId = (await anna.MeAsync()).Household.Id;
        var annasTablet = ClientFor(annaUid);

        Task<HttpResponseMessage>? upload = null;
        _hooks.DuringHouseholdDeletion = async id =>
        {
            if (id == householdId)
            {
                upload = await StartAsync(() => annasTablet.UploadAsync(Jpeg(640, 480), "photo.jpg"));
            }
        };

        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);

        // The photo reached storage before the household went; its row couldn't follow, and the photo went again.
        Assert.Equal(HttpStatusCode.Forbidden, (await upload!).StatusCode);
        await _api.RunStorageCleanupAsync();
        Assert.Empty(await _api.StorageKeysAsync($"{householdId}/"));
    }

    [Fact]
    public async Task A_photo_removed_on_another_phone_during_the_deletion_doesnt_stop_it()
    {
        var annaUid = Uid("anna");
        var anna = ClientFor(annaUid);
        var householdId = (await anna.MeAsync()).Household.Id;
        var pet = await anna.CreatePetAsync("Murka");
        var photo = await anna.UploadPhotoAsync();
        await anna.PutAsJsonAsync($"/api/v1/pets/{pet.Id}/photo", new SetPetPhotoRequest(photo.Id), Ct);
        var annasTablet = ClientFor(annaUid);

        Task<HttpResponseMessage>? removal = null;
        _hooks.DuringHouseholdDeletion = async id =>
        {
            if (id == householdId)
            {
                removal = await StartAsync(() => annasTablet.DeleteAsync($"/api/v1/pets/{pet.Id}/photo", Ct));
            }
        };

        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await removal!).StatusCode);
        await _api.RunStorageCleanupAsync();
        Assert.Empty(await _api.StorageKeysAsync($"{householdId}/"));
    }

    [Fact]
    public async Task App_events_sent_during_the_deletion_go_with_the_account()
    {
        var annaUid = Uid("anna");
        var anna = ClientFor(annaUid);
        var annaId = (await anna.MeAsync()).Id;
        var annasTablet = ClientFor(annaUid);

        Task<HttpResponseMessage>? sent = null;
        _hooks.DuringAccountDeletion = async userId =>
        {
            if (userId == annaId)
            {
                sent = await StartAsync(() => annasTablet.PostAsJsonAsync("/api/v1/events", new AppEventsRequest(Guid.NewGuid(), "1.0.0",
                    [new AppEventRequest(DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(), AppEventKind.Screen, "/pets", null)]), Json, Ct));
            }
        };

        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);

        Assert.Equal(HttpStatusCode.Unauthorized, (await sent!).StatusCode);
        var left = -1;
        await _api.ChangeDatabaseAsync(async db => left = await db.AppEvents.CountAsync(e => e.UserId == annaId, Ct));
        Assert.Equal(0, left);
    }

    [Fact]
    public async Task A_weighing_added_while_the_account_goes_is_refused_not_a_500()
    {
        // Boris owns the household; Anna is a member, so it stays. Her tablet weighs his cat while her phone deletes her account.
        var boris = ClientFor(Uid("boris"));
        var householdId = (await boris.MeAsync()).Household.Id;
        var cat = await boris.CreatePetAsync("Murka");
        var invite = (await (await boris.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Member), Json, Ct)).Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct))!;
        var annaUid = Uid("anna");
        var anna = ClientFor(annaUid, $"{annaUid}@example.com");
        Assert.Equal(HttpStatusCode.OK,
            (await anna.PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(invite.Code), Json, Ct)).StatusCode);
        var annaId = (await anna.MeAsync()).Id;
        var annasTablet = ClientFor(annaUid, $"{annaUid}@example.com");
        annasTablet.DefaultRequestHeaders.Add(CurrentUserAccessor.HouseholdHeader, householdId.ToString());

        Task<HttpResponseMessage>? added = null;
        _hooks.DuringAccountDeletion = async userId =>
        {
            if (userId == annaId)
            {
                added = await StartAsync(() => annasTablet.PostAsJsonAsync($"/api/v1/pets/{cat.Id}/weights",
                    new WeightRequest(Today, 4.2m, Bcs: null, BcsScale: null, Note: null, RequestId: Guid.NewGuid()), Json, Ct));
            }
        };

        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);

        // It waited for her row and found her account gone: the tablet signs out, as with any other request now.
        Assert.Equal(HttpStatusCode.Unauthorized, (await added!).StatusCode);
        Assert.Empty((await boris.GetFromJsonAsync<List<WeightResponse>>($"/api/v1/pets/{cat.Id}/weights", Json, Ct))!);
    }

    [Fact]
    public async Task A_weighing_added_while_the_household_goes_is_refused_not_a_500()
    {
        var annaUid = Uid("anna");
        var anna = ClientFor(annaUid);
        var householdId = (await anna.MeAsync()).Household.Id;
        var cat = await anna.CreatePetAsync("Murka");
        var annasTablet = ClientFor(annaUid);

        Task<HttpResponseMessage>? added = null;
        _hooks.DuringHouseholdDeletion = async id =>
        {
            if (id == householdId)
            {
                added = await StartAsync(() => annasTablet.PostAsJsonAsync($"/api/v1/pets/{cat.Id}/weights",
                    new WeightRequest(Today, 4.2m, Bcs: null, BcsScale: null, Note: null, RequestId: Guid.NewGuid()), Json, Ct));
            }
        };

        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);

        // The household went with her account: "not in this household" or "account deleted", never a server error.
        Assert.Contains((await added!).StatusCode, new[] { HttpStatusCode.Forbidden, HttpStatusCode.Unauthorized });
    }

    [Fact]
    public async Task A_second_deletion_at_the_same_moment_is_no_error()
    {
        var annaUid = Uid("anna");
        var anna = ClientFor(annaUid);
        var annaId = (await anna.MeAsync()).Id;
        var annasTablet = ClientFor(annaUid);

        Task<HttpResponseMessage>? second = null;
        _hooks.DuringAccountDeletion = async userId =>
        {
            if (userId == annaId && second is null)
            {
                second = await StartAsync(annasTablet.DeleteAccountAsync);
            }
        };

        Assert.Equal(HttpStatusCode.NoContent, (await anna.DeleteAccountAsync()).StatusCode);
        Assert.Contains((await second!).StatusCode, new[] { HttpStatusCode.NoContent, HttpStatusCode.Unauthorized });
    }
}
