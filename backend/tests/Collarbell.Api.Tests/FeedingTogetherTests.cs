using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Routines;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Feeding in a household of two (spec 2, "Семья"): a second reminder when nobody fed, and who fed whom.</summary>
[Collection(ApiCollection.Name)]
public sealed class FeedingTogetherTests(ApiFactory api)
{
    /// <summary>Anna's household with Boris in it; both have a phone; Murka is fed at a time two hours from now.</summary>
    private async Task<(HttpClient Anna, HttpClient Boris, string AnnasPhone, string BorisPhone, Guid Household, RoutineResponse Routine, DateOnly Today, TimeOnly At)> TwoOfUsAsync()
    {
        var anna = api.ClientFor($"anna-{Guid.NewGuid():N}");
        var household = (await anna.MeAsync()).Household.Id;
        var zone = ZoneWhereItIsAbout(12);
        await anna.SetTimeZoneAsync(zone);
        var (today, now) = LocalTimes.LocalAt(DateTimeOffset.UtcNow, zone);
        var at = new TimeOnly(now.Hour + 2, now.Minute);

        var invite = await (await anna.PostAsJsonAsync("/api/v1/households/current/invites",
            new CreateInviteRequest(HouseholdRole.Member), Json, Ct)).Content.ReadFromJsonAsync<HouseholdInviteResponse>(Json, Ct);
        var borisUid = $"boris-{Guid.NewGuid():N}";
        await api.ClientFor(borisUid).PostAsJsonAsync("/api/v1/invites/accept", new InviteCodeRequest(invite!.Code), Json, Ct);
        var boris = api.ClientFor(borisUid);
        boris.DefaultRequestHeaders.Add(CurrentUserAccessor.HouseholdHeader, household.ToString());
        await boris.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Boris", null, null), Json, Ct);

        var pet = await anna.CreatePetAsync("Murka");
        var routine = await anna.CreateRoutineAsync(pet.Id, Feeding(at));
        return (anna, boris, await anna.RegisterPhoneAsync(), await boris.RegisterPhoneAsync(), household, routine, today, at);
    }

    private async Task<Reminder> FirstReminderAsync(Guid household) =>
        (await api.RemindersOfAsync(household)).First(r => !r.Key.EndsWith(FeedingReminders.FollowUpSuffix, StringComparison.Ordinal));

    [Fact]
    public async Task Nobody_fed_in_half_an_hour_reminds_everyone_again()
    {
        var (_, _, annasPhone, borisPhone, household, _, _, at) = await TwoOfUsAsync();
        var first = await FirstReminderAsync(household);

        await api.SendRemindersAsync(first.FireAt.AddSeconds(20));
        await api.SendRemindersAsync(first.FireAt + FeedingReminders.FollowUpAfter + TimeSpan.FromSeconds(20));

        foreach (var phone in new[] { annasPhone, borisPhone })
        {
            var pushes = api.Push.To(phone);
            Assert.Equal([$"Feeding at {at:HH:mm}", $"Still not fed · {at:HH:mm}"], pushes.Select(p => p.Title));
            Assert.Equal(pushes[0].Tag, pushes[1].Tag); // the second replaces the first
        }
    }

    [Fact]
    public async Task A_mark_turns_the_reminder_into_who_fed_on_the_others_phones()
    {
        var (_, boris, annasPhone, borisPhone, household, routine, today, at) = await TwoOfUsAsync();
        var first = await FirstReminderAsync(household);
        await api.SendRemindersAsync(first.FireAt.AddSeconds(20));
        var reminder = Assert.Single(api.Push.To(annasPhone));

        var fed = await boris.PostAsJsonAsync($"/api/v1/routines/{routine.Id}/completions",
            new CompleteRoutineRequest(today, at, null), Json, Ct);
        Assert.Equal(HttpStatusCode.Created, fed.StatusCode);

        // Anna's phone: quietly, in place of the reminder. Boris marked it himself: nothing new for him.
        var update = api.Push.To(annasPhone)[1];
        Assert.Equal(FeedingMarkPush.Channel, update.Channel);
        Assert.Equal(reminder.Tag, update.Tag);
        Assert.Equal($"All fed · {at:HH:mm}", update.Title);
        Assert.StartsWith("Murka — Boris, ", update.Body, StringComparison.Ordinal);
        Assert.Equal(household.ToString(), update.Data["householdId"]);
        Assert.Single(api.Push.To(borisPhone));

        // Fed: no "still not fed" half an hour later.
        await api.SendRemindersAsync(first.FireAt + FeedingReminders.FollowUpAfter + TimeSpan.FromSeconds(20));
        Assert.Equal(2, api.Push.To(annasPhone).Count);
    }

    [Fact]
    public async Task A_mark_before_the_reminder_went_out_sends_nothing()
    {
        var (_, boris, annasPhone, _, household, routine, today, at) = await TwoOfUsAsync();

        await boris.PostAsJsonAsync($"/api/v1/routines/{routine.Id}/completions", new CompleteRoutineRequest(today, at, null), Json, Ct);
        var first = await FirstReminderAsync(household);
        await api.SendRemindersAsync(first.FireAt.AddSeconds(20));

        Assert.Empty(api.Push.To(annasPhone));
    }
}
