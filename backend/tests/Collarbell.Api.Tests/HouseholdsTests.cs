using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Households shared by several people (spec, "Семья"): invites, roles, and which household a request is in.</summary>
[Collection(ApiCollection.Name)]
public sealed class HouseholdsTests(ApiFactory api)
{
    private static string Uid(string name) => $"{name}-{Guid.NewGuid():N}";

    /// <summary>A client of <paramref name="uid"/> that works in the household <paramref name="householdId"/>.</summary>
    private HttpClient ClientIn(string uid, Guid householdId)
    {
        var client = api.ClientFor(uid);
        client.DefaultRequestHeaders.Add(CurrentUserAccessor.HouseholdHeader, householdId.ToString());
        return client;
    }

    private static async Task<HouseholdInviteResponse> InviteAsync(HttpClient owner, HouseholdRole role)
    {
        var response = await owner.PostAsJsonAsync("/api/v1/households/current/invites", new CreateInviteRequest(role), Json, Ct);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct))!;
    }

    private static Task<HttpResponseMessage> AcceptAsync(HttpClient client, string code) =>
        client.PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(code), Json, Ct);

    private static Task<HttpResponseMessage> PreviewAsync(HttpClient client, string code) =>
        client.PostAsJsonAsync("/api/v1/invites/preview", new InviteCodeRequest(code), Json, Ct);

    private static async Task AssertProblemAsync(HttpResponseMessage response, HttpStatusCode status, string type)
    {
        Assert.Equal(status, response.StatusCode);
        Assert.Equal(type, (await response.Content.ReadFromJsonAsync<ProblemDetails>(Json, Ct))!.Type);
    }

    /// <summary>The owner's household with <paramref name="role"/> joined by a new person; their uid and the household.</summary>
    private async Task<(HttpClient Owner, string Uid, Guid HouseholdId)> JoinedAsync(HouseholdRole role, string ownerUid)
    {
        var owner = api.ClientFor(ownerUid, $"{ownerUid}@example.com");
        var householdId = (await owner.MeAsync()).Household.Id;
        var invite = await InviteAsync(owner, role);
        var uid = Uid("joined");
        var accepted = await AcceptAsync(api.ClientFor(uid, $"{uid}@example.com"), invite.Code);
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        return (owner, uid, householdId);
    }

    [Fact]
    public async Task An_invite_shares_the_household_and_the_header_picks_it()
    {
        var owner = api.ClientFor(Uid("owner"), "anna@example.com");
        await owner.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Anna", null, null), Json, Ct);
        var household = (await owner.MeAsync()).Household;
        var pet = await owner.CreatePetAsync("Murka");
        var invite = await InviteAsync(owner, HouseholdRole.Member);
        Assert.Matches("^[A-Z2-9]{4}-[A-Z2-9]{4}$", invite.Code);

        var uid = Uid("boris");
        var boris = api.ClientFor(uid, "boris@example.com");
        var preview = await (await PreviewAsync(boris, invite.Code)).Content.ReadFromJsonAsync<InvitePreview>(Json, Ct);
        Assert.Equal(CurrentUserAccessor.DefaultHouseholdName, preview!.HouseholdName);
        Assert.Equal("Anna", preview.InvitedBy);
        Assert.Equal(HouseholdRole.Member, preview.Role);
        Assert.False(preview.AlreadyMember);

        // Typed in lower case and without the hyphen, it still works; a second tap answers the same.
        var accepted = await AcceptAsync(boris, invite.Code.Replace("-", "").ToLowerInvariant());
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        var joined = await accepted.Content.ReadFromJsonAsync<HouseholdSummary>(Json, Ct);
        Assert.Equal(household.Id, joined!.Id);
        Assert.Equal(HouseholdRole.Member, joined.Role);
        Assert.Equal(2, joined.MemberCount);
        Assert.Equal(HttpStatusCode.OK, (await AcceptAsync(boris, invite.Code)).StatusCode);
        Assert.True((await (await PreviewAsync(boris, (await InviteAsync(owner, HouseholdRole.Helper)).Code))
            .Content.ReadFromJsonAsync<InvitePreview>(Json, Ct))!.AlreadyMember);

        // Boris keeps his own household: without the header he is in it, with it in Anna's.
        var me = await boris.MeAsync();
        Assert.Equal(2, me.Households.Count);
        Assert.NotEqual(household.Id, me.Household.Id);
        Assert.Empty((await boris.GetFromJsonAsync<List<PetResponse>>("/api/v1/pets", Json, Ct))!);

        var inAnnas = ClientIn(uid, household.Id);
        var pets = await inAnnas.GetFromJsonAsync<List<PetResponse>>("/api/v1/pets", Json, Ct);
        Assert.Equal(pet.Id, Assert.Single(pets!).Id);
        Assert.Equal(HouseholdRole.Member, (await inAnnas.MeAsync()).Household.Role);

        var details = await inAnnas.GetFromJsonAsync<HouseholdDetails>("/api/v1/households/current", Json, Ct);
        Assert.Equal(["anna@example.com", "boris@example.com"], details!.Members.Select(m => m.Email));
        Assert.True(details.Members[1].IsMe);
        Assert.Empty(details.Invites); // only owners see them
    }

    [Fact]
    public async Task A_household_the_user_isnt_in_is_403_except_for_their_own_things()
    {
        var anna = api.ClientFor(Uid("anna"));
        var annas = (await anna.MeAsync()).Household.Id;
        var pet = await anna.CreatePetAsync("Murka");

        var strangerUid = Uid("stranger");
        foreach (var header in new[] { annas.ToString(), Guid.NewGuid().ToString(), "not-a-guid" })
        {
            var stranger = api.ClientFor(strangerUid);
            stranger.DefaultRequestHeaders.Add(CurrentUserAccessor.HouseholdHeader, header);
            await AssertProblemAsync(await stranger.GetAsync("/api/v1/pets", Ct), HttpStatusCode.Forbidden, HouseholdProblems.NotAMember);
            await AssertProblemAsync(await stranger.GetAsync($"/api/v1/pets/{pet.Id}", Ct), HttpStatusCode.Forbidden, HouseholdProblems.NotAMember);

            // Their own things answer from their first household: the app sees where it is and moves there.
            var me = await stranger.MeAsync();
            Assert.NotEqual(annas, me.Household.Id);
            Assert.Equal(HttpStatusCode.OK, (await stranger.GetAsync("/api/v1/households", Ct)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await stranger.GetAsync("/api/v1/notifications/settings", Ct)).StatusCode);
        }

        // A pet of another household asked for by id under one's own household isn't there.
        Assert.Equal(HttpStatusCode.NotFound, (await api.ClientFor(strangerUid).GetAsync($"/api/v1/pets/{pet.Id}", Ct)).StatusCode);
    }

    [Fact]
    public async Task Helpers_see_everything_and_mark_but_change_nothing()
    {
        var (owner, uid, householdId) = await JoinedAsync(HouseholdRole.Helper, Uid("owner"));
        var pet = await owner.CreatePetAsync("Murka");
        var routine = await owner.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0), new TimeOnly(20, 0)));
        var plan = await owner.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(3), 1, IntervalUnit.Year, CareKind.Vaccination));
        var helper = ClientIn(uid, householdId);

        // Reads.
        Assert.Equal(HttpStatusCode.OK, (await helper.GetAsync("/api/v1/pets", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await helper.GetAsync($"/api/v1/pets/{pet.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await helper.GetAsync("/api/v1/today", Ct)).StatusCode);

        // Marks: their own can be taken back, the owner's can't.
        var fed = await helper.PostAsJsonAsync($"/api/v1/routines/{routine.Id}/completions",
            new CompleteRoutineRequest(Today.AddDays(-1), new TimeOnly(8, 0), null), Json, Ct);
        Assert.True(fed.IsSuccessStatusCode, await fed.Content.ReadAsStringAsync(Ct));
        var helpersMark = await fed.Content.ReadFromJsonAsync<RoutineCompletionResponse>(Json, Ct);
        var ownersMark = await (await owner.PostAsJsonAsync($"/api/v1/routines/{routine.Id}/completions",
            new CompleteRoutineRequest(Today.AddDays(-1), new TimeOnly(20, 0), null), Json, Ct))
            .Content.ReadFromJsonAsync<RoutineCompletionResponse>(Json, Ct);
        await AssertProblemAsync(await helper.DeleteAsync($"/api/v1/routines/{routine.Id}/completions/{ownersMark!.Id}", Ct),
            HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);
        Assert.Equal(HttpStatusCode.NoContent,
            (await helper.DeleteAsync($"/api/v1/routines/{routine.Id}/completions/{helpersMark!.Id}", Ct)).StatusCode);

        // "Done" moves the plan by its interval, whatever next date a helper sends.
        var done = await helper.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete",
            Done(Today) with { NextDueOn = Today.AddYears(10) }, Json, Ct);
        Assert.True(done.IsSuccessStatusCode, await done.Content.ReadAsStringAsync(Ct));
        var moved = await owner.GetFromJsonAsync<CarePlanResponse>($"/api/v1/care-plans/{plan.Id}", Json, Ct);
        Assert.Equal(Today.AddYears(1), moved!.NextDueOn);

        // Changes.
        await AssertProblemAsync(await helper.DeleteAsync($"/api/v1/pets/{pet.Id}", Ct), HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);
        await AssertProblemAsync(await helper.PostAsJsonAsync("/api/v1/pets", Pet("Barsik"), Json, Ct),
            HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);
        await AssertProblemAsync(await helper.DeleteAsync($"/api/v1/care-plans/{plan.Id}", Ct), HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);
        await AssertProblemAsync(await helper.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Helper), Json, Ct), HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);

        // Their own settings are theirs; the others' e-mails aren't shown to them.
        var renamed = await helper.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Kolya", null, null), Json, Ct);
        Assert.Equal(HttpStatusCode.OK, renamed.StatusCode);
        var details = await helper.GetFromJsonAsync<HouseholdDetails>("/api/v1/households/current", Json, Ct);
        Assert.Null(details!.Members.Single(m => !m.IsMe).Email);
        Assert.Equal($"{uid}@example.com", details.Members.Single(m => m.IsMe).Email);
        await api.ChangeDatabaseAsync(async db => Assert.True(await db.Pets.AnyAsync(p => p.Id == pet.Id, Ct)));
    }

    [Fact]
    public async Task Members_change_pets_but_not_people()
    {
        var (owner, uid, householdId) = await JoinedAsync(HouseholdRole.Member, Uid("owner"));
        var pet = await owner.CreatePetAsync("Murka");
        var member = ClientIn(uid, householdId);
        var ownerId = (await owner.MeAsync()).Id;

        Assert.Equal(HttpStatusCode.NoContent, (await member.DeleteAsync($"/api/v1/pets/{pet.Id}", Ct)).StatusCode);
        await AssertProblemAsync(await member.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Member), Json, Ct), HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);
        await AssertProblemAsync(await member.PutAsJsonAsync($"/api/v1/households/current/members/{ownerId}",
            new ChangeMemberRoleRequest(HouseholdRole.Helper), Json, Ct), HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);
        await AssertProblemAsync(await member.DeleteAsync($"/api/v1/households/current/members/{ownerId}", Ct),
            HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);
        await AssertProblemAsync(await member.PutAsJsonAsync("/api/v1/households/current",
            new UpdateHouseholdRequest("Ours", null), Json, Ct), HttpStatusCode.Forbidden, HouseholdProblems.RoleForbidden);

        // Leaving is their own business.
        var memberId = (await member.MeAsync()).Id;
        Assert.Equal(HttpStatusCode.NoContent, (await member.DeleteAsync($"/api/v1/households/current/members/{memberId}", Ct)).StatusCode);
        await AssertProblemAsync(await member.GetAsync("/api/v1/pets", Ct), HttpStatusCode.Forbidden, HouseholdProblems.NotAMember);
        Assert.Single((await api.ClientFor(uid).MeAsync()).Households);
    }

    [Fact]
    public async Task Owners_manage_people_and_a_household_always_keeps_an_owner()
    {
        var ownerUid = Uid("owner");
        var (owner, uid, householdId) = await JoinedAsync(HouseholdRole.Helper, ownerUid);
        var ownerId = (await owner.MeAsync()).Id;
        var joinedId = (await ClientIn(uid, householdId).MeAsync()).Id;

        // The only owner can't step down or leave.
        await AssertProblemAsync(await owner.PutAsJsonAsync($"/api/v1/households/current/members/{ownerId}",
            new ChangeMemberRoleRequest(HouseholdRole.Member), Json, Ct), HttpStatusCode.Conflict, HouseholdProblems.LastOwner);
        await AssertProblemAsync(await owner.DeleteAsync($"/api/v1/households/current/members/{ownerId}", Ct),
            HttpStatusCode.Conflict, HouseholdProblems.LastOwner);

        // With a second owner both work; stepping down shows the household as a member sees it.
        var promoted = await owner.PutAsJsonAsync($"/api/v1/households/current/members/{joinedId}",
            new ChangeMemberRoleRequest(HouseholdRole.Owner), Json, Ct);
        Assert.Equal(HttpStatusCode.OK, promoted.StatusCode);
        Assert.All((await promoted.Content.ReadFromJsonAsync<HouseholdDetails>(Json, Ct))!.Members, m => Assert.Equal(HouseholdRole.Owner, m.Role));
        await InviteAsync(owner, HouseholdRole.Member);
        var steppedDown = await owner.PutAsJsonAsync($"/api/v1/households/current/members/{ownerId}",
            new ChangeMemberRoleRequest(HouseholdRole.Member), Json, Ct);
        var asMember = await steppedDown.Content.ReadFromJsonAsync<HouseholdDetails>(Json, Ct);
        Assert.Equal(HouseholdRole.Member, asMember!.Role);
        Assert.Empty(asMember.Invites);

        // The codes they handed out as an owner stopped working.
        var newOwner = ClientIn(uid, householdId);
        Assert.Empty((await newOwner.GetFromJsonAsync<HouseholdDetails>("/api/v1/households/current", Json, Ct))!.Invites);

        Assert.Equal(HttpStatusCode.NoContent, (await owner.DeleteAsync($"/api/v1/households/current/members/{ownerId}", Ct)).StatusCode);
        await AssertProblemAsync(await ClientIn(ownerUid, householdId).GetAsync("/api/v1/pets", Ct), HttpStatusCode.Forbidden, HouseholdProblems.NotAMember);
        var renamed = await newOwner.PutAsJsonAsync("/api/v1/households/current", new UpdateHouseholdRequest("Office", "Europe/Berlin"), Json, Ct);
        Assert.Equal(HttpStatusCode.OK, renamed.StatusCode);
        Assert.Equal("Office", (await renamed.Content.ReadFromJsonAsync<HouseholdDetails>(Json, Ct))!.Name);
    }

    [Fact]
    public async Task An_owner_removes_someone_and_their_access_ends()
    {
        var (owner, uid, householdId) = await JoinedAsync(HouseholdRole.Member, Uid("owner"));
        var member = ClientIn(uid, householdId);
        var memberId = (await member.MeAsync()).Id;

        Assert.Equal(HttpStatusCode.NoContent, (await owner.DeleteAsync($"/api/v1/households/current/members/{memberId}", Ct)).StatusCode);
        await AssertProblemAsync(await member.GetAsync("/api/v1/today", Ct), HttpStatusCode.Forbidden, HouseholdProblems.NotAMember);
        Assert.Equal(HttpStatusCode.NotFound, (await owner.DeleteAsync($"/api/v1/households/current/members/{memberId}", Ct)).StatusCode);
    }

    [Fact]
    public async Task Codes_are_one_time_expire_and_can_be_taken_back()
    {
        var owner = api.ClientFor(Uid("owner"));
        var invite = await InviteAsync(owner, HouseholdRole.Member);

        // The owner is in already.
        await AssertProblemAsync(await AcceptAsync(owner, invite.Code), HttpStatusCode.Conflict, HouseholdProblems.AlreadyMember);

        // One person per code.
        Assert.Equal(HttpStatusCode.OK, (await AcceptAsync(api.ClientFor(Uid("first")), invite.Code)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await AcceptAsync(api.ClientFor(Uid("second")), invite.Code)).StatusCode);

        // Taken back.
        var revoked = await InviteAsync(owner, HouseholdRole.Helper);
        Assert.Single((await owner.GetFromJsonAsync<HouseholdDetails>("/api/v1/households/current", Json, Ct))!.Invites);
        Assert.Equal(HttpStatusCode.NoContent, (await owner.DeleteAsync($"/api/v1/households/current/invites/{revoked.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await PreviewAsync(api.ClientFor(Uid("late")), revoked.Code)).StatusCode);
        Assert.Empty((await owner.GetFromJsonAsync<HouseholdDetails>("/api/v1/households/current", Json, Ct))!.Invites);

        // Expired.
        var old = await InviteAsync(owner, HouseholdRole.Member);
        await api.ChangeDatabaseAsync(db => db.Database.ExecuteSqlAsync(
            $"UPDATE identity.household_invites SET expires_at = now() - interval '1 minute' WHERE id = {old.Id}", Ct));
        Assert.Equal(HttpStatusCode.NotFound, (await AcceptAsync(api.ClientFor(Uid("late")), old.Code)).StatusCode);

        // Owners can't be invited, and a made-up code is just not found.
        Assert.Equal(HttpStatusCode.BadRequest, (await owner.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Owner), Json, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await AcceptAsync(api.ClientFor(Uid("guess")), "AAAA-AAAA")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await AcceptAsync(api.ClientFor(Uid("guess")), "0000-1111")).StatusCode);
    }

    [Fact]
    public async Task Guessing_codes_stops_after_ten_tries()
    {
        var guesser = api.ClientFor(Uid("guesser"));
        for (var i = 0; i < 10; i++)
        {
            Assert.Equal(HttpStatusCode.NotFound, (await PreviewAsync(guesser, "AAAA-AAAA")).StatusCode);
        }

        var stopped = await AcceptAsync(guesser, "AAAA-AAAA");
        Assert.Equal(HttpStatusCode.TooManyRequests, stopped.StatusCode);
        Assert.NotNull(stopped.Headers.RetryAfter);
    }

    [Fact]
    public async Task A_new_household_of_ones_own_deleted_while_empty_and_back_to_one_after_losing_all()
    {
        var uid = Uid("solo");
        var solo = api.ClientFor(uid);
        var home = (await solo.MeAsync()).Household.Id;

        var created = await solo.PostAsJsonAsync("/api/v1/households", new CreateHouseholdRequest("  Office  "), Json, Ct);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var office = await created.Content.ReadFromJsonAsync<HouseholdSummary>(Json, Ct);
        Assert.Equal("Office", office!.Name);
        Assert.Equal(HouseholdRole.Owner, office.Role);
        Assert.Equal([home, office.Id], (await solo.MeAsync()).Households.Select(h => h.Id));
        Assert.Equal(HttpStatusCode.BadRequest,
            (await solo.PostAsJsonAsync("/api/v1/households", new CreateHouseholdRequest(" "), Json, Ct)).StatusCode);

        // Made by mistake: an empty household goes; one with a pet doesn't.
        var inOffice = ClientIn(uid, office.Id);
        await inOffice.CreatePetAsync("Office cat");
        await AssertProblemAsync(await inOffice.DeleteAsync("/api/v1/households/current", Ct), HttpStatusCode.Conflict, HouseholdProblems.NotEmpty);
        var spare = await (await solo.PostAsJsonAsync("/api/v1/households", new CreateHouseholdRequest("Spare"), Json, Ct))
            .Content.ReadFromJsonAsync<HouseholdSummary>(Json, Ct);
        Assert.Equal(HttpStatusCode.NoContent, (await ClientIn(uid, spare!.Id).DeleteAsync("/api/v1/households/current", Ct)).StatusCode);
        Assert.Equal([home, office.Id], (await solo.MeAsync()).Households.Select(h => h.Id));

        // Out of every household (here by the database: the API keeps an owner in each), the next request makes a new one.
        await api.ChangeDatabaseAsync(db => db.Database.ExecuteSqlAsync(
            $"DELETE FROM identity.household_members WHERE user_id = (SELECT id FROM identity.users WHERE auth_subject = {"dev:" + uid})", Ct));
        var me = await solo.MeAsync();
        var only = Assert.Single(me.Households);
        Assert.NotEqual(home, only.Id);
        Assert.Equal(HouseholdRole.Owner, only.Role);
    }

    [Fact]
    public async Task A_shared_or_set_time_zone_stays_when_the_owner_travels()
    {
        var alone = api.ClientFor(Uid("alone"));
        await alone.SetTimeZoneAsync("Asia/Tokyo");
        Assert.Equal("Asia/Tokyo", (await alone.MeAsync()).Household.TimeZone);

        // Set by hand, it stays.
        await alone.PutAsJsonAsync("/api/v1/households/current", new UpdateHouseholdRequest(null, "Europe/Berlin"), Json, Ct);
        await alone.SetTimeZoneAsync("America/New_York");
        Assert.Equal("Europe/Berlin", (await alone.MeAsync()).Household.TimeZone);

        // Shared, it stays too.
        var (owner, _, _) = await JoinedAsync(HouseholdRole.Member, Uid("owner"));
        await owner.SetTimeZoneAsync("Asia/Tokyo");
        var before = (await owner.MeAsync()).Household.TimeZone;
        await owner.SetTimeZoneAsync("America/New_York");
        Assert.Equal(before, (await owner.MeAsync()).Household.TimeZone);
    }

    [Fact]
    public async Task Pushes_say_which_household_they_are_from()
    {
        var client = api.ClientFor(Uid("pushes"));
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year, CareKind.Vaccination));
        var weekBefore = (await api.RemindersOfAsync(me.Household.Id)).First(r => r.Key.EndsWith("/-7", StringComparison.Ordinal));

        await api.SendRemindersAsync(weekBefore.FireAt.AddSeconds(20));

        var push = Assert.Single(api.Push.To(token));
        Assert.Equal(me.Household.Id.ToString(), push.Data["householdId"]);
        Assert.StartsWith($"{me.Household.Id:N}-care-", push.Tag, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Me_lists_the_households_with_the_role_in_each()
    {
        var (owner, uid, householdId) = await JoinedAsync(HouseholdRole.Helper, Uid("owner"));
        var me = await api.ClientFor(uid).MeAsync();

        Assert.Equal(2, me.Households.Count);
        Assert.Equal(HouseholdRole.Owner, me.Households[0].Role);
        var shared = me.Households.Single(h => h.Id == householdId);
        Assert.Equal(HouseholdRole.Helper, shared.Role);
        Assert.Equal(2, shared.MemberCount);
        Assert.Equal(HouseholdRole.Owner, (await owner.MeAsync()).Household.Role);
    }

    /// <summary>
    /// Closed by default: every endpoint helpers may change something through, or that only owners may call, is on
    /// this list on purpose. A new endpoint with such a mark makes this test fail until it's added here.
    /// </summary>
    [Fact]
    public void The_endpoints_open_to_helpers_and_owners_only_are_the_approved_ones()
    {
        var marked = api.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Select(e => (Endpoint: e, Access: e.Metadata.GetMetadata<HouseholdAccess>()))
            .Where(x => x.Access is not null)
            .Select(x => $"{x.Access!.Rule} {string.Join(",", x.Endpoint.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods)} {x.Endpoint.RoutePattern.RawText!.TrimEnd('/')}")
            .Order(StringComparer.Ordinal)
            .ToList();

        string[] approved =
        [
            "Helpers DELETE /api/v1/households/current/members/{userId:guid}",
            "Helpers DELETE /api/v1/routines/{id:guid}/completions/{completionId:guid}",
            "Helpers DELETE /api/v1/supplies/{id:guid}/stock-events/{eventId:guid}",
            "Helpers POST /api/v1/appointments/{id:guid}/complete",
            "Helpers POST /api/v1/care-plans/{id:guid}/complete",
            "Helpers POST /api/v1/routines/{id:guid}/completions",
            "Helpers POST /api/v1/supplies/{id:guid}/stock-events",
            "Owners DELETE /api/v1/households/current",
            "Owners DELETE /api/v1/households/current/invites/{id:guid}",
            "Owners POST /api/v1/households/current/invites",
            "Owners PUT /api/v1/households/current",
            "Owners PUT /api/v1/households/current/members/{userId:guid}",
            "Personal DELETE /api/v1/devices/{id:guid}",
            "Personal DELETE /api/v1/me",
            "Personal GET /api/v1/households",
            "Personal GET /api/v1/me",
            "Personal GET /api/v1/me/deletion",
            "Personal GET /api/v1/me/export",
            "Personal GET /api/v1/notifications/settings",
            "Personal POST /api/v1/events",
            "Personal POST /api/v1/households",
            "Personal POST /api/v1/invites/accept",
            "Personal POST /api/v1/invites/preview",
            "Personal POST /api/v1/live/tickets",
            "Personal POST /api/v1/notifications/test",
            "Personal PUT /api/v1/devices/{id:guid}",
            "Personal PUT /api/v1/me",
            "Personal PUT /api/v1/notifications/settings",
        ];
        Assert.Equal(approved.Order(StringComparer.Ordinal), marked);
    }
}
