using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Time;
using Collarbell.Api.Modules.Appointments;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Today;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

/// <summary>Visits: their reminders, "the visit took place", and the visits on Today.</summary>
[Collection(ApiCollection.Name)]
public sealed class AppointmentsTests(ApiFactory api)
{
    private static readonly TimeOnly HalfPastTen = new(10, 30);

    [Fact]
    public async Task A_visit_is_kept_in_household_time_and_reminded_a_day_and_two_hours_before()
    {
        var client = api.ClientFor($"visit-remind-{Guid.NewGuid():N}");
        await client.SetTimeZoneAsync("Europe/Berlin");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var day = Today.AddDays(10);

        var visit = await client.CreateVisitAsync(Visit("Vaccination", day, HalfPastTen, pet.Id) with { Location = "Clinic Kurz" });

        Assert.Equal((day, HalfPastTen), (visit.Date, visit.Time));
        Assert.Equal(LocalTimes.Moment(day, HalfPastTen, "Europe/Berlin"), visit.StartsAt);
        Assert.Equal([1440, 120], visit.RemindOffsetsMinutes);
        var reminders = await api.RemindersOfAsync(me.Household.Id);
        Assert.Equal([visit.StartsAt.AddDays(-1), visit.StartsAt.AddHours(-2)], reminders.Select(r => r.FireAt));
        Assert.All(reminders, r =>
            Assert.Equal((ReminderSource.Appointment, visit.Id, NotificationCategory.Appointments, "Vaccination"),
                (r.Source, r.SourceId, r.Category, r.Subject)));
    }

    [Fact]
    public async Task A_visit_reminder_says_when_where_and_for_whom()
    {
        var client = api.ClientFor($"visit-push-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var murka = await client.CreatePetAsync("Murka");
        var barsik = await client.CreatePetAsync("Barsik");
        await client.CreateVisitAsync(Visit("Vaccination", Today.AddDays(10), HalfPastTen, murka.Id, barsik.Id) with { Location = "Clinic Kurz" });
        var reminders = await api.RemindersOfAsync(me.Household.Id);
        var (dayBefore, twoHoursBefore) = (reminders[0], reminders[1]);

        await api.SendRemindersAsync(dayBefore.FireAt.AddSeconds(20));
        await api.SendRemindersAsync(twoHoursBefore.FireAt.AddSeconds(20));

        var pushes = api.Push.To(token);
        Assert.Equal(["Vaccination", "Vaccination"], pushes.Select(p => p.Title));
        Assert.Equal("Tomorrow at 10:30 · Barsik, Murka · Clinic Kurz", pushes[0].Body);
        Assert.Equal("Today at 10:30 · Barsik, Murka · Clinic Kurz", pushes[1].Body);
        Assert.Equal(("appointments", "appointment"), (pushes[0].Channel, pushes[0].Data["kind"]));
        // The second reminder replaces the first on the phone and isn't kept after the visit begins.
        Assert.Equal(pushes[0].Tag, pushes[1].Tag);
        Assert.Equal(TimeSpan.FromHours(2), pushes[1].TimeToLive.Add(TimeSpan.FromSeconds(20)));
    }

    [Fact]
    public async Task Two_visits_reminded_at_the_same_moment_get_a_push_each()
    {
        var client = api.ClientFor($"visit-two-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        // Grooming at 12:00 reminds two hours before; the vet the next day at 10:00 a day before: both at 10:00.
        await client.CreateVisitAsync(Visit("Bath", Today.AddDays(5), new TimeOnly(12, 0), pet.Id) with { Type = AppointmentType.Grooming });
        await client.CreateVisitAsync(Visit("Vaccination", Today.AddDays(6), new TimeOnly(10, 0), pet.Id));
        var together = (await api.RemindersOfAsync(me.Household.Id)).GroupBy(r => r.FireAt).Single(g => g.Count() == 2);
        // What comes earlier (the day before the bath) goes first.
        await api.SendRemindersAsync(together.Key.AddSeconds(-1));
        var before = api.Push.To(token).Count;

        await api.SendRemindersAsync(together.Key.AddSeconds(20));

        Assert.Equal(["Bath", "Vaccination"], api.Push.To(token).Skip(before).Select(p => p.Title).Order());
    }

    [Fact]
    public async Task A_reminder_at_the_start_of_a_visit_goes_out()
    {
        var client = api.ClientFor($"visit-start-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var token = await client.RegisterPhoneAsync();
        var pet = await client.CreatePetAsync("Murka");
        var visit = await client.CreateVisitAsync(Visit("Vet", Today.AddDays(5), HalfPastTen, pet.Id) with { RemindOffsetsMinutes = [0] });

        await api.SendRemindersAsync(visit.StartsAt.AddSeconds(20));

        Assert.Equal("Vet", Assert.Single(api.Push.To(token)).Title);
    }

    [Fact]
    public async Task A_visit_of_archived_pets_isnt_reminded()
    {
        var client = api.ClientFor($"visit-archived-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        await client.CreateVisitAsync(Visit("Vet", Today.AddDays(5), HalfPastTen, pet.Id));
        Assert.NotEmpty(await api.RemindersOfAsync(me.Household.Id));

        await client.PutAsJsonAsync($"/api/v1/pets/{pet.Id}", Pet("Murka") with { Status = PetStatus.Archived }, Ct);

        Assert.Empty(await api.RemindersOfAsync(me.Household.Id));
    }

    [Fact]
    public async Task A_plan_chosen_for_a_visit_is_done_even_if_it_is_newer_than_the_visit()
    {
        var client = api.ClientFor($"visit-oneoff-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        // Made today, for the check-up the user had yesterday.
        var check = await client.CreatePlanAsync(pet.Id, Plan("Check before the trip", Today.AddDays(3), kind: CareKind.VetExam));
        var visit = await client.CreateVisitAsync(Visit("Check-up", Today.AddDays(-1), HalfPastTen, pet.Id));

        var response = await client.PostAsJsonAsync($"/api/v1/appointments/{visit.Id}/complete",
            new CompleteAppointmentRequest(CareKind.VetExam, [check.Id], null), Ct);

        Assert.Equal([check.Id], (await response.Content.ReadFromJsonAsync<CompleteAppointmentResponse>(Ct))!.MovedPlanIds);
        var plan = await client.GetFromJsonAsync<CarePlanResponse>($"/api/v1/care-plans/{check.Id}", Ct);
        Assert.False(plan!.Active);
    }

    [Fact]
    public async Task Moving_a_visit_moves_its_reminders_and_cancelling_drops_them()
    {
        var client = api.ClientFor($"visit-move-{Guid.NewGuid():N}");
        var me = await client.MeAsync();
        var pet = await client.CreatePetAsync("Murka");
        var visit = await client.CreateVisitAsync(Visit("Grooming", Today.AddDays(10), HalfPastTen, pet.Id));

        var moved = await client.PutAsJsonAsync($"/api/v1/appointments/{visit.Id}",
            Visit("Grooming", Today.AddDays(12), new(9, 0), pet.Id) with { RemindOffsetsMinutes = [60] }, Ct);
        Assert.Equal(HttpStatusCode.OK, moved.StatusCode);
        var startsAt = (await moved.Content.ReadFromJsonAsync<AppointmentResponse>(Ct))!.StartsAt;
        Assert.Equal([startsAt.AddHours(-1)], (await api.RemindersOfAsync(me.Household.Id)).Select(r => r.FireAt));

        var cancelled = await client.PutAsJsonAsync($"/api/v1/appointments/{visit.Id}",
            Visit("Grooming", Today.AddDays(12), new(9, 0), pet.Id) with { Status = AppointmentStatus.Cancelled }, Ct);
        Assert.Equal(HttpStatusCode.OK, cancelled.StatusCode);
        Assert.Empty(await api.RemindersOfAsync(me.Household.Id));
    }

    [Fact]
    public async Task A_past_visit_becomes_records_and_counts_as_done_for_the_chosen_plan()
    {
        var client = api.ClientFor($"visit-done-{Guid.NewGuid():N}");
        var murka = await client.CreatePetAsync("Murka");
        var barsik = await client.CreatePetAsync("Barsik");
        var checkUp = await client.CreatePlanAsync(murka.Id, Plan("Check-up", Today.AddDays(5), 1, IntervalUnit.Year, CareKind.VetExam));
        var day = Today.AddDays(-1);
        var visit = await client.CreateVisitAsync(Visit("Yearly check-up", day, HalfPastTen, murka.Id, barsik.Id) with
        {
            Location = "Clinic Kurz",
            Notes = "Healthy",
        });

        var response = await client.PostAsJsonAsync($"/api/v1/appointments/{visit.Id}/complete",
            new CompleteAppointmentRequest(CareKind.VetExam, [checkUp.Id], null), Ct);
        var again = await client.PostAsJsonAsync($"/api/v1/appointments/{visit.Id}/complete",
            new CompleteAppointmentRequest(CareKind.VetExam, [checkUp.Id], null), Ct);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var done = (await response.Content.ReadFromJsonAsync<CompleteAppointmentResponse>(Ct))!;
        Assert.Equal(AppointmentStatus.Done, done.Appointment.Status);
        Assert.Equal(2, done.Appointment.RecordIds.Count);
        Assert.Equal([checkUp.Id], done.MovedPlanIds);
        var murkaRecords = await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{murka.Id}/care-records", Ct);
        var record = Assert.Single(murkaRecords!);
        Assert.Equal((CareKind.VetExam, "Yearly check-up", day, "Clinic Kurz", "Healthy", checkUp.Id),
            (record.Kind, record.Title, record.PerformedOn, record.Clinic, record.Notes, record.PlanId));
        Assert.Single((await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{barsik.Id}/care-records", Ct))!);
        var plan = await client.GetFromJsonAsync<CarePlanResponse>($"/api/v1/care-plans/{checkUp.Id}", Ct);
        Assert.Equal(day.AddYears(1), plan!.NextDueOn);

        // Done again (a retry) changes nothing.
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Empty((await again.Content.ReadFromJsonAsync<CompleteAppointmentResponse>(Ct))!.MovedPlanIds);
        Assert.Single((await client.GetFromJsonAsync<List<CareRecordResponse>>($"/api/v1/pets/{murka.Id}/care-records", Ct))!);
    }

    [Fact]
    public async Task Only_a_visit_that_took_place_can_be_done_and_then_it_stays_done()
    {
        var client = api.ClientFor($"visit-future-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var future = await client.CreateVisitAsync(Visit("Vaccination", Today.AddDays(3), HalfPastTen, pet.Id));
        var past = await client.CreateVisitAsync(Visit("Vaccination", Today.AddDays(-3), HalfPastTen, pet.Id));
        var otherPlan = await client.CreatePlanAsync(pet.Id, Plan("Deworming", Today.AddDays(5), 3, IntervalUnit.Month, CareKind.Deworming));

        var tooEarly = await client.PostAsJsonAsync($"/api/v1/appointments/{future.Id}/complete", new CompleteAppointmentRequest(null, null, null), Ct);
        var wrongPlan = await client.PostAsJsonAsync($"/api/v1/appointments/{past.Id}/complete",
            new CompleteAppointmentRequest(CareKind.VetExam, [otherPlan.Id], null), Ct);
        var noRecord = await client.PostAsJsonAsync($"/api/v1/appointments/{past.Id}/complete", new CompleteAppointmentRequest(null, null, null), Ct);
        var reopen = await client.PutAsJsonAsync($"/api/v1/appointments/{past.Id}",
            Visit("Vaccination", Today.AddDays(-3), HalfPastTen, pet.Id) with { Status = AppointmentStatus.Planned }, Ct);

        Assert.Equal(HttpStatusCode.BadRequest, tooEarly.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, wrongPlan.StatusCode);
        Assert.Equal(HttpStatusCode.OK, noRecord.StatusCode);
        Assert.Empty((await noRecord.Content.ReadFromJsonAsync<CompleteAppointmentResponse>(Ct))!.Appointment.RecordIds);
        Assert.Equal(HttpStatusCode.BadRequest, reopen.StatusCode);
    }

    [Fact]
    public async Task A_visit_needs_a_title_and_the_households_own_pets()
    {
        var client = api.ClientFor($"visit-invalid-{Guid.NewGuid():N}");
        var stranger = api.ClientFor($"visit-invalid-stranger-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        var theirPet = await stranger.CreatePetAsync("Rex");

        foreach (var (request, field) in new (AppointmentRequest, string)[]
        {
            (Visit(" ", Today, HalfPastTen, pet.Id), "title"),
            (Visit("Vet", Today, HalfPastTen), "petIds"),
            (Visit("Vet", Today, HalfPastTen, theirPet.Id), "petIds"),
            (Visit("Vet", Today.AddYears(6), HalfPastTen, pet.Id), "date"),
            (Visit("Vet", Today, HalfPastTen, pet.Id) with { RemindOffsetsMinutes = [60, 60] }, "remindOffsetsMinutes"),
            (Visit("Vet", Today, HalfPastTen, pet.Id) with { Status = AppointmentStatus.Done }, "status"),
        })
        {
            var response = await client.PostAsJsonAsync("/api/v1/appointments", request, Ct);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Contains($"\"{field}\"", await response.Content.ReadAsStringAsync(Ct), StringComparison.Ordinal);
        }
    }

    [Fact]
    public async Task Someone_elses_visit_is_not_found()
    {
        var owner = api.ClientFor($"visit-owner-{Guid.NewGuid():N}");
        var stranger = api.ClientFor($"visit-stranger-{Guid.NewGuid():N}");
        var pet = await owner.CreatePetAsync("Murka");
        var visit = await owner.CreateVisitAsync(Visit("Vet", Today.AddDays(-1), HalfPastTen, pet.Id));

        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/v1/appointments/{visit.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.DeleteAsync($"/api/v1/appointments/{visit.Id}", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.PostAsJsonAsync($"/api/v1/appointments/{visit.Id}/complete",
            new CompleteAppointmentRequest(null, null, null), Ct)).StatusCode);
        Assert.Empty((await stranger.GetFromJsonAsync<List<AppointmentResponse>>("/api/v1/appointments", Ct))!);
    }

    [Fact]
    public async Task Today_shows_planned_visits_and_past_ones_waiting_to_be_marked()
    {
        var client = api.ClientFor($"visit-today-{Guid.NewGuid():N}");
        var pet = await client.CreatePetAsync("Murka");
        await client.CreateVisitAsync(Visit("Past, not marked", Today.AddDays(-2), HalfPastTen, pet.Id));
        await client.CreateVisitAsync(Visit("Coming", Today.AddDays(3), HalfPastTen, pet.Id));
        await client.CreateVisitAsync(Visit("Far away", Today.AddDays(40), HalfPastTen, pet.Id));
        var cancelled = await client.CreateVisitAsync(Visit("Cancelled", Today.AddDays(1), HalfPastTen, pet.Id));
        await client.PutAsJsonAsync($"/api/v1/appointments/{cancelled.Id}",
            Visit("Cancelled", Today.AddDays(1), HalfPastTen, pet.Id) with { Status = AppointmentStatus.Cancelled }, Ct);

        var visits = (await client.GetFromJsonAsync<TodayResponse>("/api/v1/today", Ct))!.Appointments;

        Assert.Equal([("Past, not marked", -2), ("Coming", 3)], visits.Select(v => (v.Title, v.DaysAway)));
        Assert.Equal("Murka", Assert.Single(visits[1].Pets).Name);
    }
}
