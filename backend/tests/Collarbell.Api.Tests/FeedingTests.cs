using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Collarbell.Api.Modules.Today;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Feeding schedules, "fed" marks, the feeding part of Today, and feeding reminders.</summary>
[Collection(ApiCollection.Name)]
public sealed class FeedingTests(ApiFactory api)
{
    /// <summary>
    /// A household where it is about noon now, and a feeding time two hours from now (still today there, whatever
    /// time the tests run).
    /// </summary>
    private static async Task<(string Zone, DateOnly Today, TimeOnly Soon)> NoonAsync(HttpClient client)
    {
        var zone = ZoneWhereItIsAbout(12);
        await client.SetTimeZoneAsync(zone);
        var (today, now) = LocalTimes.LocalAt(DateTimeOffset.UtcNow, zone);
        return (zone, today, new TimeOnly(now.Hour + 2, now.Minute));
    }

    private static Task<HttpResponseMessage> MarkAsync(HttpClient client, Guid routineId, DateOnly date, TimeOnly time,
        CompletionStatus? status = null) =>
        client.PostAsJsonAsync($"/api/v1/routines/{routineId}/completions", new CompleteRoutineRequest(date, time, status), Ct);

    [Fact]
    public async Task A_feeding_schedule_is_saved_with_its_times_in_order()
    {
        var client = api.ClientFor($"feeding-crud-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        var routine = await client.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(20, 0), new(8, 0)) with
        {
            Food = "  Royal Canin  ",
            Amount = 40,
            Unit = PortionUnit.Gram,
        });

        Assert.Equal([new TimeOnly(8, 0), new TimeOnly(20, 0)], routine.Times);
        Assert.Equal(7, routine.Days.Count);
        Assert.Equal(("Royal Canin", 40m, PortionUnit.Gram, true), (routine.Food, routine.Amount, routine.Unit, routine.Active));

        var updated = await client.PutAsJsonAsync($"/api/v1/routines/{routine.Id}",
            Feeding(new TimeOnly(9, 0)) with { Days = [DayOfWeek.Saturday, DayOfWeek.Sunday], Active = false }, Json, Ct);
        var saved = (await updated.Content.ReadFromJsonAsync<RoutineResponse>(Json, Ct))!;
        Assert.Equal([new TimeOnly(9, 0)], saved.Times);
        Assert.False(saved.Active);
        Assert.Equal([DayOfWeek.Sunday, DayOfWeek.Saturday], saved.Days);
        Assert.Null(saved.Food);

        var list = await client.GetFromJsonAsync<List<RoutineResponse>>($"/api/v1/pets/{pet.Id}/routines", Json, Ct);
        Assert.Equal(routine.Id, Assert.Single(list!).Id);

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/v1/routines/{routine.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/routines/{routine.Id}", Ct)).StatusCode);
    }

    [Fact]
    public async Task A_schedule_needs_sensible_times_and_a_unit_for_its_amount()
    {
        var client = api.ClientFor($"feeding-invalid-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        foreach (var (request, field) in new (RoutineRequest, string)[]
        {
            (Feeding(), "times"),
            (Feeding(new TimeOnly(8, 0), new(8, 0)), "times"),
            (Feeding(new TimeOnly(8, 0, 30)), "times"),
            (Feeding(new TimeOnly(8, 0)) with { Amount = 40 }, "unit"),
            (Feeding(new TimeOnly(8, 0)) with { Amount = -1, Unit = PortionUnit.Gram }, "amount"),
            (Feeding(new TimeOnly(8, 0)) with { Days = [DayOfWeek.Monday, DayOfWeek.Monday] }, "days"),
        })
        {
            var response = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/routines", request, Json, Ct);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Contains($"\"{field}\"", await response.Content.ReadAsStringAsync(Ct), StringComparison.Ordinal);
        }
    }

    [Fact]
    public async Task A_feeding_is_marked_once_and_the_second_person_learns_who_did_it()
    {
        var anna = api.ClientFor($"feeding-anna-{Guid.NewGuid():N}");
        var boris = api.ClientFor($"feeding-boris-{Guid.NewGuid():N}");
        var household = (await anna.MeAsync()).Household.Id;
        var borisId = (await boris.MeAsync()).Id;
        await api.ChangeDatabaseAsync(db =>
        {
            db.HouseholdMembers.Add(new HouseholdMember(household, borisId, HouseholdRole.Member, DateTimeOffset.UnixEpoch));
            return db.SaveChangesAsync();
        });
        await anna.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Anna", null, null), Ct);
        var (_, today, soon) = await NoonAsync(anna);
        var pet = await anna.CreatePetAsync("Murka");
        var routine = await anna.CreateRoutineAsync(pet.Id, Feeding(soon));

        var first = await MarkAsync(anna, routine.Id, today, soon);
        var again = await MarkAsync(anna, routine.Id, today, soon);
        var second = await MarkAsync(boris, routine.Id, today, soon);

        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        var mark = (await first.Content.ReadFromJsonAsync<RoutineCompletionResponse>(Ct))!;
        Assert.Equal((CompletionStatus.Done, "Anna", true), (mark.Status, mark.ByName, mark.ByMe));
        // A double tap gets the same mark back; someone else gets 409 with who and when.
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Equal(mark.Id, (await again.Content.ReadFromJsonAsync<RoutineCompletionResponse>(Ct))!.Id);
        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
        var theirs = (await second.Content.ReadFromJsonAsync<RoutineCompletionResponse>(Ct))!;
        Assert.Equal((mark.Id, "Anna", false), (theirs.Id, theirs.ByName, theirs.ByMe));
    }

    [Fact]
    public async Task Only_a_scheduled_feeding_of_the_last_days_can_be_marked()
    {
        var client = api.ClientFor($"feeding-occurrence-{Guid.NewGuid():N}");
        var (_, today, soon) = await NoonAsync(client);
        var pet = await client.CreatePetAsync("Murka");
        var routine = await client.CreateRoutineAsync(pet.Id, Feeding(soon));

        Assert.Equal(HttpStatusCode.BadRequest, (await MarkAsync(client, routine.Id, today, soon.AddMinutes(1))).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await MarkAsync(client, routine.Id, today.AddDays(1), soon)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await MarkAsync(client, routine.Id, today.AddDays(-8), soon)).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await MarkAsync(client, routine.Id, today.AddDays(-1), soon)).StatusCode);
    }

    [Fact]
    public async Task A_mark_can_be_taken_back()
    {
        var client = api.ClientFor($"feeding-undo-{Guid.NewGuid():N}");
        var (_, today, soon) = await NoonAsync(client);
        var pet = await client.CreatePetAsync("Murka");
        var routine = await client.CreateRoutineAsync(pet.Id, Feeding(soon));
        var mark = (await (await MarkAsync(client, routine.Id, today, soon)).Content.ReadFromJsonAsync<RoutineCompletionResponse>(Ct))!;

        var undo = await client.DeleteAsync($"/api/v1/routines/{routine.Id}/completions/{mark.Id}", Ct);

        Assert.Equal(HttpStatusCode.NoContent, undo.StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await MarkAsync(client, routine.Id, today, soon)).StatusCode);
    }

    [Fact]
    public async Task Today_lists_the_days_feedings_of_active_pets_with_their_marks()
    {
        var client = api.ClientFor($"feeding-today-{Guid.NewGuid():N}");
        var (_, today, soon) = await NoonAsync(client);
        var murka = await client.CreatePetAsync("Murka");
        var barsik = await client.CreatePetAsync("Barsik");
        var away = await client.CreatePetAsync("Away");
        await client.PutAsJsonAsync($"/api/v1/pets/{away.Id}", Pet("Away") with { Status = PetStatus.Archived }, Ct);
        var murkaFeeding = await client.CreateRoutineAsync(murka.Id, Feeding(new TimeOnly(8, 0), soon) with { Food = "Royal Canin", Amount = 40, Unit = PortionUnit.Gram });
        await client.CreateRoutineAsync(barsik.Id, Feeding(soon));
        await client.CreateRoutineAsync(away.Id, Feeding(soon));
        var otherDays = Enum.GetValues<DayOfWeek>().Where(d => d != today.DayOfWeek).ToList();
        await client.CreateRoutineAsync(barsik.Id, Feeding(new TimeOnly(7, 0)) with { Days = otherDays });
        await MarkAsync(client, murkaFeeding.Id, today, new(8, 0));

        var feedings = (await client.GetFromJsonAsync<TodayResponse>("/api/v1/today", Ct))!.Feedings;

        Assert.Equal(
            [("Murka", new TimeOnly(8, 0), true), ("Barsik", soon, false), ("Murka", soon, false)],
            feedings.Select(f => (f.PetName, f.Time, f.Mark is not null)));
        Assert.Equal(("Royal Canin", 40m, PortionUnit.Gram), (feedings[0].Food, feedings[0].Amount, feedings[0].Unit));
    }

    [Fact]
    public async Task Feeding_is_reminded_once_per_time_for_the_pets_not_fed_yet()
    {
        var client = api.ClientFor($"feeding-remind-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var (zone, today, soon) = await NoonAsync(client);
        var murka = await client.CreatePetAsync("Murka");
        var barsik = await client.CreatePetAsync("Barsik");
        var murkaFeeding = await client.CreateRoutineAsync(murka.Id, Feeding(soon) with { Food = "Royal Canin", Amount = 40, Unit = PortionUnit.Gram });
        await client.CreateRoutineAsync(barsik.Id, Feeding(soon));

        var reminder = (await api.RemindersOfAsync(me.Household.Id)).First();
        Assert.Equal((ReminderSource.Feeding, me.Household.Id, NotificationCategory.Feeding), (reminder.Source, reminder.SourceId, reminder.Category));
        Assert.Equal(LocalTimes.Moment(today, soon, zone), reminder.FireAt);
        Assert.Equal("Barsik, Murka", reminder.Subject);

        // Murka was fed early: only Barsik is left in the reminder.
        await MarkAsync(client, murkaFeeding.Id, today, soon);
        await api.SendRemindersAsync(reminder.FireAt.AddSeconds(20));

        var push = Assert.Single(api.Push.To(token));
        Assert.Equal($"Feeding at {soon:HH:mm}", push.Title);
        Assert.Equal("Barsik", push.Body);
        Assert.Equal(("feeding", "feeding"), (push.Channel, push.Data["kind"]));
    }

    [Fact]
    public async Task A_feeding_reminder_is_skipped_when_all_are_fed_and_expires_when_late()
    {
        var client = api.ClientFor($"feeding-skip-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var (_, today, soon) = await NoonAsync(client);
        var pet = await client.CreatePetAsync("Murka");
        var later = soon.AddMinutes(30);
        var routine = await client.CreateRoutineAsync(pet.Id, Feeding(soon, later));
        var reminders = (await api.RemindersOfAsync(me.Household.Id))
            .Where(r => !r.Key.EndsWith(FeedingReminders.FollowUpSuffix, StringComparison.Ordinal)).Take(2).ToList();
        await MarkAsync(client, routine.Id, today, soon);

        await api.SendRemindersAsync(reminders[0].FireAt.AddSeconds(20));
        // The server was off for 31 minutes past the second feeding: "time to feed" is stale by now, but its
        // follow-up is due, and nobody has fed Murka then.
        await api.SendRemindersAsync(reminders[1].FireAt.AddMinutes(31));

        var push = Assert.Single(api.Push.To(token));
        Assert.StartsWith("Still not fed", push.Title, StringComparison.Ordinal);
        var after = (await api.RemindersOfAsync(me.Household.Id)).ToDictionary(r => r.Id);
        Assert.Equal((ReminderStatus.Skipped, ReminderReason.NotNeeded), (after[reminders[0].Id].Status, after[reminders[0].Id].Reason));
        Assert.Equal(ReminderStatus.Expired, after[reminders[1].Id].Status);
    }

    [Fact]
    public async Task Many_pets_fed_at_once_make_a_short_subject()
    {
        var client = api.ClientFor($"feeding-many-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        for (var i = 1; i <= 7; i++)
        {
            var pet = await client.CreatePetAsync($"Cat number {i} with a name long enough to fill the line");
            await client.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0)));
        }

        var reminders = await api.RemindersOfAsync(me.Household.Id);

        Assert.NotEmpty(reminders);
        Assert.All(reminders, r => Assert.EndsWith(" +2", r.Subject, StringComparison.Ordinal));
    }

    [Fact]
    public async Task A_time_must_be_whole_minutes()
    {
        var client = api.ClientFor($"feeding-ticks-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");

        var response = await client.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/routines",
            Feeding(new TimeOnly(8, 0).Add(TimeSpan.FromTicks(1))), Json, Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Feeding_reminders_are_planned_two_days_ahead()
    {
        var client = api.ClientFor($"feeding-ahead-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        await client.CreateRoutineAsync(pet.Id, Feeding(new TimeOnly(8, 0), new(20, 0)));

        var reminders = await api.RemindersOfAsync(me.Household.Id);

        // Two times a day for 48 hours: four reminders and their four follow-ups, whatever the time now.
        Assert.Equal(8, reminders.Count);
        Assert.Equal(4, reminders.Count(r => r.Key.EndsWith(FeedingReminders.FollowUpSuffix, StringComparison.Ordinal)));
        Assert.All(reminders, r => Assert.InRange(r.FireAt, DateTimeOffset.UtcNow.AddMinutes(-1), DateTimeOffset.UtcNow.AddHours(48)));
    }

    [Fact]
    public async Task Someone_elses_feeding_is_not_found()
    {
        var owner = api.ClientFor($"feeding-owner-{Guid.NewGuid():N}");
        var stranger = api.ClientFor($"feeding-stranger-{Guid.NewGuid():N}");
        var (_, today, soon) = await NoonAsync(owner);
        var pet = await owner.CreatePetAsync("Murka");
        var routine = await owner.CreateRoutineAsync(pet.Id, Feeding(soon));

        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/v1/routines/{routine.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/v1/pets/{pet.Id}/routines", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await MarkAsync(stranger, routine.Id, today, soon)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await stranger.PostAsJsonAsync($"/api/v1/pets/{pet.Id}/routines", Feeding(soon), Json, Ct)).StatusCode);
    }
}
