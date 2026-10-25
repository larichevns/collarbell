using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Care plan reminders and what every reminder goes through: planning, sending, skipping, expiring.</summary>
[Collection(ApiCollection.Name)]
public sealed class RemindersTests(ApiFactory api)
{
    private static string Day(DateOnly date) => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    [Fact]
    public async Task A_plan_is_reminded_before_it_is_due_at_ten_in_the_morning_and_again_when_overdue()
    {
        var client = api.ClientFor($"remind-plan-{Guid.NewGuid():N}");
        await client.SetTimeZoneAsync("Europe/Berlin");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var due = Today.AddDays(20);
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Rabies", due, 1, IntervalUnit.Year, CareKind.Vaccination));

        var reminders = await api.RemindersOfAsync(me.Household.Id);

        var d = Day(due);
        Assert.Equal(
            [$"{d}/-7", $"{d}/-1", $"{d}/0", $"{d}/+3", $"{d}/+6", $"{d}/+9", $"{d}/+12", $"{d}/+15"],
            reminders.Select(r => r.Key));
        Assert.All(reminders, r =>
        {
            Assert.Equal((ReminderSource.CarePlan, plan.Id, ReminderStatus.Pending), (r.Source, r.SourceId, r.Status));
            Assert.Equal(NotificationCategory.Care, r.Category);
            Assert.Equal("Murka: Rabies", r.Subject);
            // 10:00 in Berlin, in summer and in winter alike.
            Assert.Equal(new TimeOnly(10, 0), LocalTimes.LocalAt(r.FireAt, "Europe/Berlin").Time);
        });
        Assert.Equal(due.AddDays(-7), LocalTimes.LocalAt(reminders[0].FireAt, "Europe/Berlin").Date);
        Assert.Equal(due.AddDays(15), LocalTimes.LocalAt(reminders[^1].FireAt, "Europe/Berlin").Date);
    }

    [Fact]
    public async Task Done_moves_the_reminders_to_the_next_date()
    {
        var client = api.ClientFor($"remind-done-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today.AddDays(5), 3, IntervalUnit.Month, CareKind.Deworming));

        var response = await client.PostAsJsonAsync($"/api/v1/care-plans/{plan.Id}/complete", Done(Today), Ct);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var reminders = await api.RemindersOfAsync(me.Household.Id);
        var next = Day(Today.AddMonths(3));
        Assert.NotEmpty(reminders);
        Assert.All(reminders, r => Assert.StartsWith(next, r.Key, StringComparison.Ordinal));
    }

    [Fact]
    public async Task A_due_reminder_is_pushed_once_to_the_household_phones()
    {
        var client = api.ClientFor($"remind-push-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        var due = Today.AddDays(20);
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Rabies", due, 1, IntervalUnit.Year, CareKind.Vaccination));
        var weekBefore = (await api.RemindersOfAsync(me.Household.Id)).First(r => r.Key.EndsWith("/-7", StringComparison.Ordinal));

        await api.SendRemindersAsync(weekBefore.FireAt.AddSeconds(20));
        await api.SendRemindersAsync(weekBefore.FireAt.AddMinutes(1));

        var push = Assert.Single(api.Push.To(token));
        Assert.Equal("Murka: Rabies", push.Title);
        Assert.Equal($"In 7 days, {due.ToString("MMMM d", CultureInfo.InvariantCulture)}", push.Body);
        Assert.Equal(("care", "care"), (push.Channel, push.Data["kind"]));
        Assert.Equal(plan.Id.ToString(), push.Data["planId"]);
        var sent = (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.Id == weekBefore.Id);
        Assert.Equal(ReminderStatus.Sent, sent.Status);
        Assert.NotNull(sent.SentAt);
    }

    [Fact]
    public async Task A_reminder_no_longer_needed_is_skipped()
    {
        var client = api.ClientFor($"remind-stale-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        var weekBefore = (await api.RemindersOfAsync(me.Household.Id)).First();
        // The plan moved without the reminders being planned again (say, the server stopped in between).
        await api.ChangeDatabaseAsync(db => db.CarePlans.Where(p => p.Id == plan.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.NextDueOn, Today.AddDays(40))));

        await api.SendRemindersAsync(weekBefore.FireAt.AddSeconds(20));

        Assert.Empty(api.Push.To(token));
        var skipped = (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.Id == weekBefore.Id);
        Assert.Equal((ReminderStatus.Skipped, ReminderReason.NotNeeded), (skipped.Status, skipped.Reason));
    }

    [Fact]
    public async Task A_care_reminder_still_goes_hours_late_but_expires_after_a_day()
    {
        var client = api.ClientFor($"remind-late-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        var reminders = await api.RemindersOfAsync(me.Household.Id);
        var (weekBefore, dayBefore, dueDay) = (reminders[0], reminders[1], reminders[2]);

        // The server was off: the week-before one comes five hours late; later the server is off for more than a
        // day, so the day-before one is a day and an hour late and the due-day one an hour late.
        await api.SendRemindersAsync(weekBefore.FireAt.AddHours(5));
        await api.SendRemindersAsync(dayBefore.FireAt.AddHours(25));

        Assert.Equal(["In 7 days", "Today"], api.Push.To(token).Select(p => p.Body.Split(',')[0]));
        var after = (await api.RemindersOfAsync(me.Household.Id)).ToDictionary(r => r.Id);
        Assert.Equal(ReminderStatus.Sent, after[weekBefore.Id].Status);
        Assert.Equal(ReminderStatus.Expired, after[dayBefore.Id].Status);
        Assert.Equal(ReminderStatus.Sent, after[dueDay.Id].Status);
    }

    [Fact]
    public async Task Care_reminders_due_together_make_one_push()
    {
        var client = api.ClientFor($"remind-group-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var murka = await client.CreatePetAsync("Murka");
        var rex = await client.CreatePetAsync("Rex", Species.Dog);
        var due = Today.AddDays(20);
        await client.CreatePlanAsync(murka.Id, Plan("Rabies", due, 1, IntervalUnit.Year));
        await client.CreatePlanAsync(rex.Id, Plan("Bravecto", due, 12, IntervalUnit.Week));
        var weekBefore = (await api.RemindersOfAsync(me.Household.Id)).First();

        await api.SendRemindersAsync(weekBefore.FireAt.AddSeconds(20));

        var push = Assert.Single(api.Push.To(token));
        Assert.Equal("Care: 2 reminders", push.Title);
        Assert.Contains("Murka: Rabies (in 7 days)", push.Body, StringComparison.Ordinal);
        Assert.Contains("Rex: Bravecto (in 7 days)", push.Body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Each_person_gets_reminders_in_their_language_and_only_the_kinds_they_want()
    {
        var anna = api.ClientFor($"remind-anna-{Guid.NewGuid():N}");
        var boris = api.ClientFor($"remind-boris-{Guid.NewGuid():N}");
        var household = (await anna.MeAsync()).Household.Id;
        var borisId = (await boris.MeAsync()).Id;
        // Boris joins Anna's household (invitations come in 0.2).
        await api.ChangeDatabaseAsync(db =>
        {
            db.HouseholdMembers.Add(new HouseholdMember(household, borisId, HouseholdRole.Member, DateTimeOffset.UnixEpoch));
            return db.SaveChangesAsync();
        });
        Assert.Equal(household, (await boris.MeAsync()).Household.Id);
        await anna.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest(null, "ru", null), Ct);
        var annaPhone = await anna.RegisterPhoneAsync();
        var borisPhone = await boris.RegisterPhoneAsync();
        await boris.PutAsJsonAsync("/api/v1/notifications/settings",
            new UpdateNotificationSettingsRequest([new NotificationCategorySetting(NotificationCategory.Care, false)]), Ct);

        var pet = await anna.CreatePetAsync("Мурка");
        await anna.CreatePlanAsync(pet.Id, Plan("Бешенство", Today.AddDays(20), 1, IntervalUnit.Year));
        var weekBefore = (await api.RemindersOfAsync(household)).First();
        await api.SendRemindersAsync(weekBefore.FireAt.AddSeconds(20));

        var push = Assert.Single(api.Push.To(annaPhone));
        Assert.Equal("Мурка: Бешенство", push.Title);
        Assert.StartsWith("Через 7 дней, ", push.Body, StringComparison.Ordinal);
        Assert.Empty(api.Push.To(borisPhone));
    }

    [Fact]
    public async Task Busy_firebase_is_tried_again_and_then_given_up()
    {
        var client = api.ClientFor($"remind-busy-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        api.Push.Results[token] = PushResult.TryAgain;
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        var reminder = (await api.RemindersOfAsync(me.Household.Id)).First();
        async Task<Reminder> Current() => (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.Id == reminder.Id);

        var at = reminder.FireAt.AddSeconds(20);
        await api.SendRemindersAsync(at);
        Assert.Equal((ReminderStatus.Pending, 1, at.AddMinutes(1)), ((await Current()).Status, (await Current()).Attempts, (await Current()).DueAt));

        foreach (var wait in ReminderDispatcher.RetryDelays)
        {
            at += wait;
            await api.SendRemindersAsync(at);
        }

        var failed = await Current();
        Assert.Equal((ReminderStatus.Failed, ReminderReason.SendFailed, 4), (failed.Status, failed.Reason, failed.Attempts));
    }

    [Fact]
    public async Task A_phone_firebase_no_longer_knows_is_forgotten()
    {
        var client = api.ClientFor($"remind-gone-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        api.Push.Results[token] = PushResult.InvalidToken;
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        var reminder = (await api.RemindersOfAsync(me.Household.Id)).First();

        await api.SendRemindersAsync(reminder.FireAt.AddSeconds(20));

        var skipped = (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.Id == reminder.Id);
        Assert.Equal((ReminderStatus.Skipped, ReminderReason.NoRecipients), (skipped.Status, skipped.Reason));
        var settings = await client.GetFromJsonAsync<NotificationSettingsResponse>("/api/v1/notifications/settings", Ct);
        Assert.Empty(settings!.Devices);
    }

    [Fact]
    public async Task Without_a_firebase_key_reminders_are_skipped_with_the_reason()
    {
        var client = api.ClientFor($"remind-nokey-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        var reminder = (await api.RemindersOfAsync(me.Household.Id)).First();

        api.Push.IsConfigured = false;
        try
        {
            await api.SendRemindersAsync(reminder.FireAt.AddSeconds(20));
        }
        finally
        {
            api.Push.IsConfigured = true;
        }

        var skipped = (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.Id == reminder.Id);
        Assert.Equal((ReminderStatus.Skipped, ReminderReason.PushNotConfigured), (skipped.Status, skipped.Reason));
    }

    [Fact]
    public async Task Without_a_phone_a_reminder_is_skipped_with_the_reason()
    {
        var client = api.ClientFor($"remind-nophone-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        var reminder = (await api.RemindersOfAsync(me.Household.Id)).First();

        await api.SendRemindersAsync(reminder.FireAt.AddSeconds(20));

        var skipped = (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.Id == reminder.Id);
        Assert.Equal((ReminderStatus.Skipped, ReminderReason.NoRecipients), (skipped.Status, skipped.Reason));
    }

    [Fact]
    public async Task An_occasion_is_never_reminded_twice()
    {
        var client = api.ClientFor($"remind-twice-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        var weekBefore = (await api.RemindersOfAsync(me.Household.Id)).First();
        await api.SendRemindersAsync(weekBefore.FireAt.AddSeconds(20));

        // Planned again after a change and by the background run: the sent one stays sent and isn't added again.
        await client.PutAsJsonAsync($"/api/v1/care-plans/{plan.Id}", Plan("Rabies (Nobivac)", Today.AddDays(20), 1, IntervalUnit.Year), Ct);
        await api.PlanAllRemindersAsync(DateTimeOffset.UtcNow);
        await api.SendRemindersAsync(weekBefore.FireAt.AddMinutes(5));

        Assert.Single(api.Push.To(token));
        var reminders = await api.RemindersOfAsync(me.Household.Id);
        Assert.Single(reminders, r => r.Key == weekBefore.Key);
        Assert.Equal("Murka: Rabies (Nobivac)", reminders.Last().Subject);
    }

    [Fact]
    public async Task A_new_time_zone_moves_the_waiting_reminders()
    {
        var client = api.ClientFor($"remind-zone-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));

        await client.SetTimeZoneAsync("Asia/Tbilisi");

        var reminders = await api.RemindersOfAsync(me.Household.Id);
        Assert.Equal(8, reminders.Count);
        Assert.All(reminders, r => Assert.Equal(new TimeOnly(10, 0), LocalTimes.LocalAt(r.FireAt, "Asia/Tbilisi").Time));
        Assert.All(reminders, r => Assert.Equal(r.FireAt, r.DueAt));
    }

    [Fact]
    public async Task A_paused_pet_gets_no_reminders()
    {
        var client = api.ClientFor($"remind-paused-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        Assert.NotEmpty(await api.RemindersOfAsync(me.Household.Id));

        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}", Pet("Murka") with { Status = PetStatus.Archived }, Ct);
        Assert.Empty(await api.RemindersOfAsync(me.Household.Id));

        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}", Pet("Murka") with { Status = PetStatus.Active }, Ct);
        Assert.Equal(8, (await api.RemindersOfAsync(me.Household.Id)).Count);
    }

    [Fact]
    public async Task The_list_shows_the_households_coming_and_recent_reminders_only()
    {
        var client = api.ClientFor($"remind-list-{Guid.NewGuid():N}");
        var stranger = api.ClientFor($"remind-list-stranger-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today.AddDays(5), 3, IntervalUnit.Month));

        var mine = await client.GetFromJsonAsync<RemindersResponse>("/api/v1/notifications/reminders", Ct);
        var theirs = await stranger.GetFromJsonAsync<RemindersResponse>("/api/v1/notifications/reminders", Ct);

        // Due in 5 days: the reminders of the day before and of the day itself are within the next week; the one a
        // week before has passed, the first overdue one is further away.
        Assert.Equal(2, mine!.Upcoming.Count);
        Assert.All(mine.Upcoming, r => Assert.Equal(("Murka: Deworming", ReminderStatus.Pending), (r.Subject, r.Status)));
        Assert.True(mine.Upcoming[0].FireAt < mine.Upcoming[1].FireAt);
        Assert.Empty(theirs!.Upcoming);
    }

    [Fact]
    public async Task A_plan_without_reminder_days_is_not_reminded_at_all()
    {
        var client = api.ClientFor($"remind-none-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");

        await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year) with { RemindOffsetsDays = [] });

        Assert.Empty(await api.RemindersOfAsync(me.Household.Id));
    }

    [Fact]
    public async Task Moving_east_keeps_a_reminder_whose_new_time_has_just_passed()
    {
        // At about 09:00 local the plan is due today: its reminder is at 10:00. Two hours east it is about 11:00, so
        // 10:00 has passed there: the reminder goes out late instead of being dropped.
        var client = api.ClientFor($"remind-east-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var west = OffsetWhereItIsAbout(9);
        await client.SetTimeZoneAsync(EtcZone(west));
        var token = await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        var today = LocalTimes.DateAt(DateTimeOffset.UtcNow, EtcZone(west));
        await client.CreatePlanAsync(pet.Id, Plan("Rabies", today, 1, IntervalUnit.Year) with { RemindOffsetsDays = [0] });
        var reminder = Assert.Single(await api.RemindersOfAsync(me.Household.Id), r => r.Key.EndsWith("/0", StringComparison.Ordinal));

        await client.SetTimeZoneAsync(EtcZone(west + 2));

        var moved = (await api.RemindersOfAsync(me.Household.Id)).Single(r => r.Id == reminder.Id);
        Assert.Equal(ReminderStatus.Pending, moved.Status);
        Assert.Equal(LocalTimes.Moment(today, new TimeOnly(10, 0), EtcZone(west + 2)), moved.FireAt);
        Assert.True(moved.FireAt < DateTimeOffset.UtcNow);
        await api.SendRemindersAsync(DateTimeOffset.UtcNow);
        Assert.Single(api.Push.To(token));
    }

    [Fact]
    public async Task Bad_data_of_one_module_doesnt_stop_the_others_reminders()
    {
        var client = api.ClientFor($"remind-isolated-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var plan = await client.CreatePlanAsync(pet.Id, Plan("Rabies", Today.AddDays(20), 1, IntervalUnit.Year));
        var planned = await api.RemindersOfAsync(me.Household.Id);
        // A date at the end of the calendar: its overdue reminders can't even be worked out.
        await api.ChangeDatabaseAsync(db => db.CarePlans.Where(p => p.Id == plan.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.NextDueOn, new DateOnly(9999, 12, 28))));

        var visit = await client.CreateVisitAsync(Visit("Vet", Today.AddDays(5), new TimeOnly(10, 30), pet.Id));

        var reminders = await api.RemindersOfAsync(me.Household.Id);
        Assert.Equal(2, reminders.Count(r => r.SourceId == visit.Id));
        // The plan's reminders stay as they were until its data can be planned again.
        Assert.Equal(planned.Select(r => r.Id).Order(), reminders.Where(r => r.SourceId == plan.Id).Select(r => r.Id).Order());
    }

    [Fact]
    public void Firebase_errors_mean_gone_try_again_or_failed()
    {
        Assert.Equal(PushResult.InvalidToken, FcmPushSender.Classify(MessagingErrorCode.Unregistered, ErrorCode.NotFound));
        Assert.Equal(PushResult.TryAgain, FcmPushSender.Classify(MessagingErrorCode.Unavailable, ErrorCode.Unavailable));
        Assert.Equal(PushResult.TryAgain, FcmPushSender.Classify(MessagingErrorCode.QuotaExceeded, ErrorCode.ResourceExhausted));
        // No connection: no messaging code, only the general one.
        Assert.Equal(PushResult.TryAgain, FcmPushSender.Classify(null, ErrorCode.Unknown));
        Assert.Equal(PushResult.TryAgain, FcmPushSender.Classify(null, ErrorCode.DeadlineExceeded));
        // A key of another project: every phone says "wrong sender". The phones are fine, they stay.
        Assert.Equal(PushResult.Failed, FcmPushSender.Classify(MessagingErrorCode.SenderIdMismatch, ErrorCode.PermissionDenied));
        Assert.Equal(PushResult.Failed, FcmPushSender.Classify(MessagingErrorCode.InvalidArgument, ErrorCode.InvalidArgument));
    }

    [Fact]
    public void A_firebase_key_of_another_project_turns_pushes_off()
    {
        var options = Options.Create(new NotificationsOptions { FirebaseCredentials = ServiceAccountJson("someone-elses-project") });
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Firebase:ProjectId"] = "collarbell-3e2b9" })
            .Build();

        var sender = new FcmPushSender(options, configuration, NullLogger<FcmPushSender>.Instance);

        Assert.False(sender.IsConfigured);
    }

    /// <summary>A service account key as the Firebase console gives it, with a fresh private key.</summary>
    private static string ServiceAccountJson(string projectId)
    {
        using var rsa = System.Security.Cryptography.RSA.Create(2048);
        return System.Text.Json.JsonSerializer.Serialize(new Dictionary<string, string>
        {
            ["type"] = "service_account",
            ["project_id"] = projectId,
            ["private_key_id"] = "test",
            ["private_key"] = rsa.ExportPkcs8PrivateKeyPem(),
            ["client_email"] = $"push@{projectId}.iam.gserviceaccount.com",
            ["client_id"] = "1",
            ["token_uri"] = "https://oauth2.googleapis.com/token",
        });
    }

    /// <summary>The whole-hour offset from UTC of a place where it is about <paramref name="hour"/> o'clock now.</summary>
    private static int OffsetWhereItIsAbout(int hour)
    {
        var offset = hour - DateTime.UtcNow.Hour;
        return offset < -12 ? offset + 24 : offset;
    }

    /// <summary>The Etc/GMT zone with this offset (its sign is the other way round).</summary>
    private static string EtcZone(int offset) => offset switch
    {
        0 => "Etc/GMT",
        > 0 => $"Etc/GMT-{offset}",
        _ => $"Etc/GMT+{-offset}",
    };

    [Fact]
    public void Local_times_survive_daylight_saving_changes()
    {
        // Berlin, 28 March 2027: clocks jump from 02:00 to 03:00, so 02:30 doesn't exist and rings at 03:30 (01:30 UTC).
        Assert.Equal(new DateTimeOffset(2027, 3, 28, 1, 30, 0, TimeSpan.Zero),
            LocalTimes.Moment(new DateOnly(2027, 3, 28), new TimeOnly(2, 30), "Europe/Berlin"));
        // 25 October 2026: 02:30 happens twice; the first time counts (still summer time, 00:30 UTC).
        Assert.Equal(new DateTimeOffset(2026, 10, 25, 0, 30, 0, TimeSpan.Zero),
            LocalTimes.Moment(new DateOnly(2026, 10, 25), new TimeOnly(2, 30), "Europe/Berlin"));
        // 08:00 stays 08:00 on both sides of the change.
        Assert.Equal(new DateTimeOffset(2026, 10, 24, 6, 0, 0, TimeSpan.Zero),
            LocalTimes.Moment(new DateOnly(2026, 10, 24), new TimeOnly(8, 0), "Europe/Berlin"));
        Assert.Equal(new DateTimeOffset(2026, 10, 26, 7, 0, 0, TimeSpan.Zero),
            LocalTimes.Moment(new DateOnly(2026, 10, 26), new TimeOnly(8, 0), "Europe/Berlin"));
    }
}
