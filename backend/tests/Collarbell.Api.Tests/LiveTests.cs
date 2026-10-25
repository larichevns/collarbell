using System.Net;
using System.Net.Http.Json;
using System.Threading.Channels;
using Collarbell.Api.Infrastructure.Auth;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Admin;
using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Appointments;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Live;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Live updates (system-design 3.4): the open screens of a household hear what someone in it changed.</summary>
[Collection(ApiCollection.Name)]
public sealed class LiveTests(ApiFactory api)
{
    private static readonly TimeSpan Wait = TimeSpan.FromSeconds(5);

    /// <summary>A phone with the app in front, connected to the hub like the app: WebSockets only, no negotiate.</summary>
    private sealed class Phone : IAsyncDisposable
    {
        private readonly Channel<LiveChange> _heard = Channel.CreateUnbounded<LiveChange>();
        private readonly TaskCompletionSource<Exception?> _closed = new(TaskCreationOptions.RunContinuationsAsynchronously);

        /// <param name="query">The address's query, as a browser opens the hub: <c>?access_token=…&amp;household=…</c>.</param>
        public Phone(ApiFactory api, string? uid, Guid? household, string query = "")
        {
            var server = api.Server;
            Hub = new HubConnectionBuilder()
                .WithUrl(new Uri(server.BaseAddress, HouseholdHub.Path + query), o =>
                {
                    o.Transports = HttpTransportType.WebSockets;
                    o.SkipNegotiation = true;
                    if (uid is not null)
                    {
                        o.Headers[DevUserAuthenticationHandler.UserHeader] = uid;
                    }

                    if (household is { } id)
                    {
                        o.Headers[CurrentUserAccessor.HouseholdHeader] = id.ToString();
                    }

                    o.WebSocketFactory = async (context, ct) =>
                    {
                        var client = server.CreateWebSocketClient();
                        client.ConfigureRequest = request =>
                        {
                            foreach (var (name, value) in context.Options.Headers)
                            {
                                request.Headers[name] = value;
                            }
                        };
                        return await client.ConnectAsync(context.Uri, ct);
                    };
                })
                .Build();
            Hub.On<LiveChange>(nameof(IHouseholdClient.Changed), change => _heard.Writer.TryWrite(change));
            Hub.Closed += error =>
            {
                _closed.TrySetResult(error);
                return Task.CompletedTask;
            };
        }

        public HubConnection Hub { get; }

        /// <summary>The next change it hears; fails after a few seconds of silence.</summary>
        public async Task<LiveChange> NextAsync()
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(Ct);
            timeout.CancelAfter(Wait);
            return await _heard.Reader.ReadAsync(timeout.Token);
        }

        /// <summary>Hears nothing more for a moment.</summary>
        public async Task HearsNothingAsync()
        {
            await Task.Delay(TimeSpan.FromMilliseconds(300), Ct);
            Assert.False(_heard.Reader.TryRead(out var change), $"Heard {string.Join(", ", change?.Topics ?? [])}");
        }

        /// <summary>The server closed the connection: the error it gave.</summary>
        public async Task<Exception?> ClosedAsync() => await _closed.Task.WaitAsync(Wait, Ct);

        public ValueTask DisposeAsync() => Hub.DisposeAsync();
    }

    /// <summary>A phone that hears the household, as the app connects: open the connection, then ask Ready.</summary>
    private async Task<Phone> ConnectAsync(string? uid, Guid? household = null)
    {
        var phone = new Phone(api, uid, household);
        try
        {
            await phone.Hub.StartAsync(Ct);
            await phone.Hub.InvokeAsync(nameof(HouseholdHub.Ready), Ct);
            return phone;
        }
        catch
        {
            await phone.DisposeAsync();
            throw;
        }
    }

    /// <summary>A phone the server lets in only to close it at once: why it closed.</summary>
    private async Task<string?> RefusedAsync(string uid, Guid household)
    {
        await using var phone = new Phone(api, uid, household);
        await phone.Hub.StartAsync(Ct);
        return (await phone.ClosedAsync())?.Message;
    }

    /// <summary>Anna's household with Boris in it as a member: their clients and ids.</summary>
    private async Task<(HttpClient Anna, string BorisUid, HttpClient Boris, Guid BorisId, Guid Household)> TwoOfUsAsync()
    {
        var anna = api.ClientFor($"anna-{Guid.NewGuid():N}");
        var household = (await anna.MeAsync()).Household.Id;
        var invite = await (await anna.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Member), Json, Ct)).Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct);
        var borisUid = $"boris-{Guid.NewGuid():N}";
        var accepted = await api.ClientFor(borisUid).PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(invite!.Code), Json, Ct);
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        var boris = api.ClientFor(borisUid);
        boris.DefaultRequestHeaders.Add(CurrentUserAccessor.HouseholdHeader, household.ToString());
        return (anna, borisUid, boris, (await boris.MeAsync()).Id, household);
    }

    [Fact]
    public async Task A_mark_reaches_everyone_in_the_household_and_nobody_else()
    {
        var (anna, borisUid, boris, _, household) = await TwoOfUsAsync();
        var pet = await anna.CreatePetAsync("Murka");
        var routine = await anna.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0)));
        var carlUid = $"carl-{Guid.NewGuid():N}";
        var carl = api.ClientFor(carlUid);
        await carl.MeAsync();

        await using var annasPhone = await ConnectAsync(UidOf(anna), household);
        await using var borisPhone = await ConnectAsync(borisUid, household);
        await using var carlsPhone = await ConnectAsync(carlUid);

        using var mark = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/routines/{routine.Id}/completions")
        {
            Content = JsonContent.Create(new CompleteRoutineRequest(Today, new TimeOnly(8, 0), null), options: Json),
        };
        mark.Headers.Add(LiveChanges.ClientHeader, "boris-phone-1");
        Assert.Equal(HttpStatusCode.Created, (await boris.SendAsync(mark, Ct)).StatusCode);

        var heard = await annasPhone.NextAsync();
        Assert.Equal([LiveTopics.Feeding], heard.Topics);
        // Only Boris's own phones get the id of the phone he did it on: that one skips it, it shows the mark already.
        // Nobody else learns the ids of his phones, so nobody can pass a change off as his phone's.
        Assert.Null(heard.Origin);
        Assert.Equal("boris-phone-1", (await borisPhone.NextAsync()).Origin);

        // Carl's household hears its own change, and only that.
        await carl.CreatePetAsync("Rex");
        Assert.Equal([LiveTopics.Pets], (await carlsPhone.NextAsync()).Topics);
        await carlsPhone.HearsNothingAsync();
        await annasPhone.HearsNothingAsync();
    }

    [Fact]
    public async Task Reading_and_failing_tell_nobody()
    {
        var uid = $"dana-{Guid.NewGuid():N}";
        var dana = api.ClientFor(uid);
        await using var phone = await ConnectAsync(uid, (await dana.MeAsync()).Household.Id);

        await dana.GetAsync("/api/v1/pets", Ct);
        var failed = await dana.PostAsJsonAsync("/api/v1/pets", Pet(""), Ct);
        Assert.Equal(HttpStatusCode.BadRequest, failed.StatusCode);

        // A change after them is the first thing heard; an id that doesn't look like the app's isn't passed on.
        using var create = new HttpRequestMessage(HttpMethod.Post, "/api/v1/pets") { Content = JsonContent.Create(Pet("Murka")) };
        create.Headers.Add(LiveChanges.ClientHeader, "<script>");
        Assert.Equal(HttpStatusCode.Created, (await dana.SendAsync(create, Ct)).StatusCode);
        var heard = await phone.NextAsync();
        Assert.Equal([LiveTopics.Pets], heard.Topics);
        Assert.Null(heard.Origin);
        await phone.HearsNothingAsync();
    }

    [Fact]
    public async Task A_visit_that_took_place_tells_about_the_care_it_wrote_too()
    {
        var uid = $"vera-{Guid.NewGuid():N}";
        var vera = api.ClientFor(uid);
        var pet = await vera.CreatePetAsync("Murka");
        var visit = await vera.CreateVisitAsync(Visit("Check-up", Today.AddDays(-1), new TimeOnly(10, 30), pet.Id));
        await using var phone = await ConnectAsync(uid, (await vera.MeAsync()).Household.Id);

        var done = await vera.PostAsJsonAsync($"/api/v1/appointments/{visit.Id}/complete",
            new CompleteAppointmentRequest(CareKind.VetExam, null, null), Ct);
        Assert.Equal(HttpStatusCode.OK, done.StatusCode);

        Assert.Equal([LiveTopics.Visits, LiveTopics.Care], (await phone.NextAsync()).Topics);
    }

    [Fact]
    public async Task A_weighing_is_heard_as_weight()
    {
        var uid = $"wanda-{Guid.NewGuid():N}";
        var wanda = api.ClientFor(uid);
        var pet = await wanda.CreatePetAsync("Murka");
        await using var phone = await ConnectAsync(uid, (await wanda.MeAsync()).Household.Id);

        var added = await wanda.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/weights",
            new WeightRequest(Today, 4.2m, Bcs: null, BcsScale: null, Note: null, RequestId: null), Ct);
        Assert.Equal(HttpStatusCode.Created, added.StatusCode);

        Assert.Equal([LiveTopics.Weight], (await phone.NextAsync()).Topics);
    }

    [Fact]
    public async Task Joining_tells_the_household_joined()
    {
        var annaUid = $"anna-{Guid.NewGuid():N}";
        var anna = api.ClientFor(annaUid);
        await using var annasPhone = await ConnectAsync(annaUid, (await anna.MeAsync()).Household.Id);
        var invite = await (await anna.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Helper), Json, Ct)).Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct);
        Assert.Equal([LiveTopics.Household], (await annasPhone.NextAsync()).Topics); // the invite, for the owners

        var sitter = api.ClientFor($"sitter-{Guid.NewGuid():N}");
        await sitter.MeAsync();
        var accepted = await sitter.PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(invite!.Code), Json, Ct);
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);

        Assert.Equal([LiveTopics.Household], (await annasPhone.NextAsync()).Topics);
    }

    [Fact]
    public async Task A_removed_member_hears_it_once_and_nothing_after()
    {
        var (anna, borisUid, _, borisId, household) = await TwoOfUsAsync();
        await using var annasPhone = await ConnectAsync(UidOf(anna), household);
        await using var borisPhone = await ConnectAsync(borisUid, household);

        var removed = await anna.DeleteAsync($"/api/v1/households/current/members/{borisId}", Ct);
        Assert.Equal(HttpStatusCode.NoContent, removed.StatusCode);
        Assert.Equal([LiveTopics.Household], (await borisPhone.NextAsync()).Topics);
        Assert.Equal([LiveTopics.Household], (await annasPhone.NextAsync()).Topics);

        await anna.CreatePetAsync("Murka");
        Assert.Equal([LiveTopics.Pets], (await annasPhone.NextAsync()).Topics);
        await borisPhone.HearsNothingAsync();

        // Connecting again to the household he was in isn't possible either.
        Assert.Contains(HouseholdHub.NotAMember, await RefusedAsync(borisUid, household), StringComparison.Ordinal);
    }

    [Fact]
    public async Task A_deleted_account_leaves_every_household_it_was_in()
    {
        var (anna, borisUid, boris, _, household) = await TwoOfUsAsync();
        var borisOwn = (await api.ClientFor(borisUid).MeAsync()).Households.Single(h => h.Id != household).Id;
        await using var annasPhone = await ConnectAsync(UidOf(anna), household);
        await using var borisPhone = await ConnectAsync(borisUid, household);
        await using var borisOtherPhone = await ConnectAsync(borisUid, borisOwn);

        Assert.Equal(HttpStatusCode.NoContent, (await boris.DeleteAccountAsync()).StatusCode);

        // Anna's members list changes; Boris's phones hear it once and nothing after.
        Assert.Equal([LiveTopics.Household], (await annasPhone.NextAsync()).Topics);
        Assert.Equal([LiveTopics.Household], (await borisPhone.NextAsync()).Topics);
        Assert.Equal([LiveTopics.Household], (await borisOtherPhone.NextAsync()).Topics);
        await anna.CreatePetAsync("Murka");
        Assert.Equal([LiveTopics.Pets], (await annasPhone.NextAsync()).Topics);
        await borisPhone.HearsNothingAsync();
        await borisOtherPhone.HearsNothingAsync();
    }

    private static async Task<string> TicketAsync(HttpClient client)
    {
        var response = await client.PostAsync("/api/v1/live/tickets", content: null, Ct);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<LiveTicketResponse>(Ct))!.Ticket;
    }

    [Fact]
    public async Task A_browser_opens_the_hub_with_a_ticket_good_once()
    {
        var uid = $"browser-{Guid.NewGuid():N}";
        var client = api.ClientFor(uid);
        var household = (await client.MeAsync()).Household.Id;
        var ticket = await TicketAsync(client);
        var query = $"?{LiveTicketAuthenticationHandler.QueryKey}={ticket}&{HouseholdHub.HouseholdQuery}={household}";

        // No headers: a browser's WebSocket can't send them. The ticket signs it in, the address names the household.
        await using var browser = new Phone(api, uid: null, household: null, query);
        await browser.Hub.StartAsync(Ct);
        await browser.Hub.InvokeAsync(nameof(HouseholdHub.Ready), Ct);
        await client.CreatePetAsync("Murka");
        Assert.Equal([LiveTopics.Pets], (await browser.NextAsync()).Topics);

        // Used: the same address opens nothing again (nor would it from the server's logs).
        await using var again = new Phone(api, uid: null, household: null, query);
        await Assert.ThrowsAnyAsync<Exception>(() => again.Hub.StartAsync(Ct));
        await using var made = new Phone(api, uid: null, household: null, $"?{LiveTicketAuthenticationHandler.QueryKey}=made-up");
        await Assert.ThrowsAnyAsync<Exception>(() => made.Hub.StartAsync(Ct));
    }

    [Fact]
    public async Task A_ticket_opens_only_the_persons_own_households_and_tickets_are_few()
    {
        var (_, _, _, _, household) = await TwoOfUsAsync();
        var carlUid = $"carl-{Guid.NewGuid():N}";
        var carl = api.ClientFor(carlUid);
        await carl.MeAsync();

        await using var carlsBrowser = new Phone(api, uid: null, household: null,
            $"?{LiveTicketAuthenticationHandler.QueryKey}={await TicketAsync(carl)}&{HouseholdHub.HouseholdQuery}={household}");
        await carlsBrowser.Hub.StartAsync(Ct);
        Assert.Contains(HouseholdHub.NotAMember, (await carlsBrowser.ClosedAsync())?.Message, StringComparison.Ordinal);

        // Ten unused at most (the one above is used): a browser needs one per connection, a script asking for more gets none.
        for (var i = 0; i < LiveTickets.MaxPerPerson; i++)
        {
            await TicketAsync(carl);
        }

        Assert.Equal(HttpStatusCode.TooManyRequests, (await carl.PostAsync("/api/v1/live/tickets", content: null, Ct)).StatusCode);
    }

    [Fact]
    public async Task Only_its_people_hear_a_household()
    {
        var (anna, _, _, _, household) = await TwoOfUsAsync();
        var carlUid = $"carl-{Guid.NewGuid():N}";
        await api.ClientFor(carlUid).MeAsync();

        // Naming a household that isn't theirs: closed at once, and told not to try again.
        await using var carlsPhone = new Phone(api, carlUid, household);
        await carlsPhone.Hub.StartAsync(Ct);
        Assert.Contains(HouseholdHub.NotAMember, (await carlsPhone.ClosedAsync())?.Message, StringComparison.Ordinal);
        await anna.CreatePetAsync("Murka");
        await carlsPhone.HearsNothingAsync();

        // Not signed in: no connection at all.
        await Assert.ThrowsAnyAsync<Exception>(() => ConnectAsync(uid: null));
    }

    [Fact]
    public async Task One_person_keeps_a_few_connections_at_most()
    {
        var uid = $"erik-{Guid.NewGuid():N}";
        var household = (await api.ClientFor(uid).MeAsync()).Household.Id;
        var phones = new List<Phone>();
        try
        {
            for (var i = 0; i < LiveChanges.MaxConnectionsPerUser; i++)
            {
                phones.Add(await ConnectAsync(uid, household));
            }

            Assert.Contains(LiveChanges.TooManyConnections, await RefusedAsync(uid, household), StringComparison.Ordinal);

            // A phone that goes frees its place (once the server sees it gone).
            await phones[0].DisposeAsync();
            phones.RemoveAt(0);
            await Task.Delay(TimeSpan.FromMilliseconds(300), Ct);
            phones.Add(await ConnectAsync(uid, household));
            await api.ClientFor(uid).CreatePetAsync("Murka");
            Assert.Equal([LiveTopics.Pets], (await phones[^1].NextAsync()).Topics);
        }
        finally
        {
            foreach (var phone in phones)
            {
                await phone.DisposeAsync();
            }
        }
    }

    [Fact]
    public async Task A_stranger_never_hears_a_household_even_while_being_checked()
    {
        var household = (await api.ClientFor($"anna-{Guid.NewGuid():N}").MeAsync()).Household.Id;
        var carlUid = $"carl-{Guid.NewGuid():N}";
        await api.ClientFor(carlUid).MeAsync();

        await using var carlsPhone = new Phone(api, carlUid, household);
        await using (await LockMembersAsync())
        {
            // Carl's check waits for the table; Anna's household changes meanwhile.
            await carlsPhone.Hub.StartAsync(Ct);
            await Task.Delay(300, Ct);
            await api.Services.GetRequiredService<LiveChanges>().ChangedAsync(household, [LiveTopics.Imports]);
        }

        Assert.Contains(HouseholdHub.NotAMember, (await carlsPhone.ClosedAsync())?.Message, StringComparison.Ordinal);
        await carlsPhone.HearsNothingAsync();
    }

    [Fact]
    public async Task Phones_gone_during_the_check_keep_no_place()
    {
        var uid = $"erik-{Guid.NewGuid():N}";
        var household = (await api.ClientFor(uid).MeAsync()).Household.Id;

        // More phones than the limit go away while the server checks them (to the background, a timeout).
        for (var i = 0; i <= LiveChanges.MaxConnectionsPerUser; i++)
        {
            await using (await LockMembersAsync())
            {
                var phone = new Phone(api, uid, household);
                await phone.Hub.StartAsync(Ct);
                await Task.Delay(200, Ct);
                await phone.DisposeAsync();
            }
        }

        await using var next = await ConnectAsync(uid, household);
        await api.ClientFor(uid).CreatePetAsync("Murka");
        Assert.Equal([LiveTopics.Pets], (await next.NextAsync()).Topics);
    }

    [Fact]
    public async Task Leaving_on_one_phone_tells_the_others_and_not_that_one()
    {
        var (anna, borisUid, boris, borisId, household) = await TwoOfUsAsync();
        await using var annasPhone = await ConnectAsync(UidOf(anna), household);
        await using var borisPhone = await ConnectAsync(borisUid, household);
        await using var borisTablet = await ConnectAsync(borisUid, household);

        using var leave = new HttpRequestMessage(HttpMethod.Delete, $"/api/v1/households/current/members/{borisId}");
        leave.Headers.Add(LiveChanges.ClientHeader, "boris-phone-1");
        Assert.Equal(HttpStatusCode.NoContent, (await boris.SendAsync(leave, Ct)).StatusCode);

        Assert.Equal("boris-phone-1", (await borisPhone.NextAsync()).Origin);
        Assert.Equal("boris-phone-1", (await borisTablet.NextAsync()).Origin);
        var heard = await annasPhone.NextAsync();
        Assert.Equal([LiveTopics.Household], heard.Topics);
        Assert.Null(heard.Origin);
    }

    [Fact]
    public async Task A_new_name_is_heard_where_the_person_is_and_the_same_one_is_not()
    {
        var (anna, borisUid, boris, _, household) = await TwoOfUsAsync();
        await using var annasPhone = await ConnectAsync(UidOf(anna), household);

        // The app sends the profile on every start: the same name again is no news.
        Assert.Equal(HttpStatusCode.OK, (await boris.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Boris", null, null), Json, Ct)).StatusCode);
        Assert.Equal([LiveTopics.Household], (await annasPhone.NextAsync()).Topics);
        Assert.Equal(HttpStatusCode.OK, (await boris.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Boris", "ru", null), Json, Ct)).StatusCode);
        await annasPhone.HearsNothingAsync();
    }

    [Fact]
    public async Task What_the_server_changes_by_itself_is_heard_too()
    {
        api.Ai.Reset();
        var uid = $"vera-{Guid.NewGuid():N}";
        var vera = api.ClientFor(uid);
        var me = await vera.MeAsync();
        var pet = await vera.CreatePetAsync("Murka");
        var photo = await vera.UploadPhotoAsync();
        await using var phone = await ConnectAsync(uid, me.Household.Id);

        // A scan: the request, then the background reading when it's over.
        var started = await vera.PostAsJsonAsync("/api/v1/ai-imports",
            new CreateAiImportRequest(pet.Id, AiImportSource.PassportPages, [photo.Id], null), Json, Ct);
        Assert.Equal(HttpStatusCode.Accepted, started.StatusCode);
        Assert.Equal([LiveTopics.Imports], (await phone.NextAsync()).Topics);
        Assert.Equal([LiveTopics.Imports], (await phone.NextAsync()).Topics);

        // Premium given in the admin.
        var admin = api.ClientFor($"admin-{Guid.NewGuid():N}");
        var adminId = (await admin.MeAsync()).Id;
        await api.ChangeDatabaseAsync(db => db.Users.Where(u => u.Id == adminId).ExecuteUpdateAsync(s => s.SetProperty(u => u.IsAdmin, true), Ct));
        var given = await admin.PutAsJsonAsync($"/api/admin/households/{me.Household.Id}/plan",
            new AdminPlanRequest(PlanKind.Premium, null, null), Json, Ct);
        Assert.Equal(HttpStatusCode.OK, given.StatusCode);
        Assert.Equal([LiveTopics.Plan], (await phone.NextAsync()).Topics);
    }

    [Fact]
    public async Task Every_change_is_heard_or_left_out_on_purpose()
    {
        // Endpoints that change something and don't report it through their mark, and why.
        string[] leftOut =
        [
            "UpdateMe",                     // reports a new name by itself (the profile comes on every start)
            "DeleteMe",                     // tells every household it leaves by itself
            "CreateHouseholdGroup",         // a new household of one
            "DeleteCurrentHousehold",       // only an empty household of one
            "PreviewHouseholdInvite",       // changes nothing
            "AcceptHouseholdInvite",        // reports to the household joined, by itself
            "UploadFile",                   // nobody sees an upload until something uses it
            "RegisterDevice",               // one's own phone and settings
            "ForgetDevice",
            "UpdateNotificationSettings",
            "SendTestNotification",
            "ReportAppEvents",              // the admin's visor
            "IssueLiveTicket",              // a browser's way into the hub: changes nothing
        ];
        var unmarked = api.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(e => e.RoutePattern.RawText?.StartsWith("/api/v1/", StringComparison.Ordinal) == true)
            .Where(e => e.Metadata.GetMetadata<HttpMethodMetadata>()?.HttpMethods.Any(m => m is not ("GET" or "HEAD")) == true)
            .Where(e => e.Metadata.GetMetadata<LiveTopicsMetadata>() is null)
            .Select(e => e.Metadata.GetMetadata<EndpointNameMetadata>()?.EndpointName ?? e.DisplayName)
            .Order()
            .ToList();
        Assert.Equal(leftOut.Order(), unmarked);
    }

    /// <summary>Keeps household_members locked, so the hub's membership check waits until this is disposed.</summary>
    private async Task<IAsyncDisposable> LockMembersAsync()
    {
        string connectionString;
        await using (var scope = api.Services.CreateAsyncScope())
        {
            connectionString = scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.GetConnectionString()!;
        }

        var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(Ct);
        var transaction = await connection.BeginTransactionAsync(Ct);
        await using var command = new NpgsqlCommand("LOCK TABLE identity.household_members IN ACCESS EXCLUSIVE MODE", connection, transaction);
        await command.ExecuteNonQueryAsync(Ct);
        return new TableLock(connection, transaction);
    }

    private sealed class TableLock(NpgsqlConnection connection, NpgsqlTransaction transaction) : IAsyncDisposable
    {
        public async ValueTask DisposeAsync()
        {
            await transaction.RollbackAsync();
            await connection.DisposeAsync();
        }
    }

    /// <summary>The dev uid a client signs in with.</summary>
    private static string UidOf(HttpClient client) =>
        client.DefaultRequestHeaders.GetValues(DevUserAuthenticationHandler.UserHeader).Single();
}
