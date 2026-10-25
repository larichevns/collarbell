using System.Globalization;
using Collarbell.Api.Modules.Identity;

namespace Collarbell.Api.Modules.Notifications;

/// <summary>What a due reminder is about, filled in by its module just before sending.</summary>
public abstract record ReminderContent;

/// <summary>A care plan due on <see cref="DueOn"/>; <see cref="DaysLeft"/> is negative when it is overdue.</summary>
public sealed record CareDue(Guid PlanId, Guid PetId, string PetName, string Title, DateOnly DueOn, int DaysLeft) : ReminderContent;

/// <summary>Feeding time: the pets not fed yet at <see cref="Time"/> on <see cref="Date"/> (household time).</summary>
/// <param name="FollowUp">The second reminder: nobody has marked these pets yet.</param>
public sealed record FeedingDue(DateOnly Date, TimeOnly Time, IReadOnlyList<FeedingPortion> Pets, bool FollowUp = false) : ReminderContent;

/// <param name="Unit">"g", "ml" or "pcs".</param>
public sealed record FeedingPortion(string PetName, string? Food, decimal? Amount, string? Unit);

/// <summary>
/// A visit at <see cref="Time"/> on <see cref="Date"/> (household time), <see cref="DaysAway"/> days from today.
/// </summary>
public sealed record VisitSoon(
    Guid AppointmentId,
    string Title,
    DateOnly Date,
    TimeOnly Time,
    int DaysAway,
    DateTimeOffset StartsAt,
    string? Location,
    IReadOnlyList<string> PetNames) : ReminderContent;

/// <summary>
/// A supply runs out on <see cref="RunsOutOn"/>, <see cref="DaysLeft"/> days from today: time to buy it.
/// <see cref="RunsOutToday"/> is the second reminder, on the day itself.
/// </summary>
public sealed record SupplyDue(Guid SupplyId, string Name, DateOnly RunsOutOn, int DaysLeft, bool RunsOutToday) : ReminderContent;

/// <summary>
/// The words of every push, in English and Russian. Names of pets, plans and visits are the user's own and stay as
/// typed. Several reminders of one kind due at the same moment make one push (two cats fed at 8:00, three plans due
/// the same day).
/// </summary>
public static class ReminderTexts
{
    private static readonly CultureInfo Ru = CultureInfo.GetCultureInfo("ru-RU");

    public static PushMessage Compose(IReadOnlyList<ReminderContent> contents, string locale, DateTimeOffset now)
    {
        var ru = locale == Locales.Russian;
        return contents[0] switch
        {
            FeedingDue => Feeding([.. contents.Cast<FeedingDue>()], ru),
            CareDue when contents.Count == 1 => Care((CareDue)contents[0], ru),
            CareDue => CareGroup([.. contents.Cast<CareDue>()], ru),
            VisitSoon => Visit((VisitSoon)contents[0], ru, now),
            SupplyDue when contents.Count == 1 => Supply((SupplyDue)contents[0], ru),
            SupplyDue => SupplyGroup([.. contents.Cast<SupplyDue>()], ru),
            _ => throw new ArgumentOutOfRangeException(nameof(contents), contents[0], "Unknown reminder."),
        };
    }

    /// <summary>
    /// Marks a push with its household. The app opens that household when the push is tapped, and the tag carries it,
    /// so two households' pushes (both feeding at 08:00) don't replace each other on a phone that is in both.
    /// </summary>
    public static PushMessage InHousehold(PushMessage message, Guid householdId) => message with
    {
        Tag = $"{householdId:N}-{message.Tag}",
        Data = new Dictionary<string, string>(message.Data) { ["householdId"] = householdId.ToString() },
    };

    /// <summary>The push of the "Test notifications" button.</summary>
    public static PushMessage Test(string locale) => locale == Locales.Russian
        ? new PushMessage("Проверка уведомлений", "Уведомления Collarbell приходят на этот телефон.", "general", "test",
            TimeSpan.FromHours(1), new Dictionary<string, string> { ["kind"] = "test" })
        : new PushMessage("Test notification", "Collarbell notifications reach this phone.", "general", "test",
            TimeSpan.FromHours(1), new Dictionary<string, string> { ["kind"] = "test" });

    /// <summary>"Feeding at 08:00" — "Murka: Royal Canin, 40 g · Barsik: 50 g".</summary>
    private static PushMessage Feeding(IReadOnlyList<FeedingDue> slots, bool ru)
    {
        var first = slots[0];
        var pets = slots.SelectMany(s => s.Pets).ToList();
        var time = first.Time.ToString("HH:mm", CultureInfo.InvariantCulture);
        var portions = pets.Select(p => Portion(p, ru)).ToList();
        var body = portions.All(p => p is null)
            ? string.Join(", ", pets.Select(p => p.PetName))
            : string.Join(" · ", pets.Select((p, i) => portions[i] is { } portion ? $"{p.PetName}: {portion}" : p.PetName));
        var date = first.Date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var title = (first.FollowUp, ru) switch
        {
            (true, true) => $"Ещё не покормили · {time}",
            (true, false) => $"Still not fed · {time}",
            (false, true) => $"Кормление в {time}",
            (false, false) => $"Feeding at {time}",
        };
        return new PushMessage(
            title,
            body,
            "feeding",
            $"feeding-{date}T{time}",
            // An hour later the reminder is stale: the pets were fed or the moment has passed.
            TimeSpan.FromHours(1),
            new Dictionary<string, string> { ["kind"] = "feeding", ["date"] = date, ["time"] = time });
    }

    /// <summary>"Royal Canin, 40 g", or null when the schedule says neither.</summary>
    private static string? Portion(FeedingPortion pet, bool ru)
    {
        var amount = pet.Amount is { } value
            ? $"{value.ToString("0.##", ru ? Ru : CultureInfo.InvariantCulture)} {Unit(pet.Unit, ru)}".TrimEnd()
            : null;
        return (pet.Food, amount) switch
        {
            (null, null) => null,
            (null, _) => amount,
            (_, null) => pet.Food,
            _ => $"{pet.Food}, {amount}",
        };
    }

    private static string Unit(string? unit, bool ru) => (unit, ru) switch
    {
        ("g", true) => "г",
        ("ml", true) => "мл",
        ("pcs", true) => "шт.",
        ("pcs", false) => "pcs",
        (null, _) => "",
        _ => unit,
    };

    /// <summary>"Murka: Rabies" — "In 7 days, October 12".</summary>
    private static PushMessage Care(CareDue due, bool ru) => new(
        $"{due.PetName}: {due.Title}",
        When(due, ru, sentence: true),
        "care",
        $"care-{due.PlanId}",
        TimeSpan.FromDays(1),
        new Dictionary<string, string>
        {
            ["kind"] = "care",
            ["petId"] = due.PetId.ToString(),
            ["planId"] = due.PlanId.ToString(),
        });

    /// <summary>"Care: 3 reminders" — "Murka: Rabies (in 7 days) · Barsik: Deworming (today)".</summary>
    private static PushMessage CareGroup(IReadOnlyList<CareDue> dues, bool ru)
    {
        var title = ru
            ? $"Уход: {dues.Count} {Plural(dues.Count, "напоминание", "напоминания", "напоминаний")}"
            : $"Care: {dues.Count} reminders";
        var body = string.Join(" · ", dues.Select(d => $"{d.PetName}: {d.Title} ({When(d, ru, sentence: false)})"));
        return new PushMessage(title, body, "care", $"care-{dues.Min(d => d.PlanId)}", TimeSpan.FromDays(1),
            new Dictionary<string, string> { ["kind"] = "care" });
    }

    /// <summary>
    /// When a plan is due. As a sentence: "In 7 days, October 12", "Overdue by 3 days, since October 2"; inside a
    /// list: "in 7 days", "3 days overdue".
    /// </summary>
    private static string When(CareDue due, bool ru, bool sentence)
    {
        var date = ru ? due.DueOn.ToString("d MMMM", Ru) : due.DueOn.ToString("MMMM d", CultureInfo.InvariantCulture);
        var n = Math.Abs(due.DaysLeft);
        var days = ru ? Plural(n, "день", "дня", "дней") : n == 1 ? "day" : "days";
        var text = (due.DaysLeft, ru) switch
        {
            (0, true) => "сегодня",
            (0, false) => "today",
            (1, true) => "завтра",
            (1, false) => "tomorrow",
            ( > 1, true) => $"через {n} {days}",
            ( > 1, false) => $"in {n} {days}",
            (_, true) => $"просрочено на {n} {days}",
            (_, false) => sentence ? $"overdue by {n} {days}" : $"{n} {days} overdue",
        };
        if (!sentence)
        {
            return text;
        }

        var since = due.DaysLeft < 0 ? (ru ? $", с {date}" : $", since {date}") : $", {date}";
        return char.ToUpper(text[0], ru ? Ru : CultureInfo.InvariantCulture) + text[1..] + since;
    }

    /// <summary>"Vaccination at the vet" — "Tomorrow at 10:30 · Murka, Barsik · 5 Main St".</summary>
    private static PushMessage Visit(VisitSoon visit, bool ru, DateTimeOffset now)
    {
        var time = visit.Time.ToString("HH:mm", CultureInfo.InvariantCulture);
        var day = (visit.DaysAway, ru) switch
        {
            (0, true) => "Сегодня",
            (0, false) => "Today",
            (1, true) => "Завтра",
            (1, false) => "Tomorrow",
            (_, true) => visit.Date.ToString("d MMMM", Ru),
            (_, false) => visit.Date.ToString("MMMM d", CultureInfo.InvariantCulture),
        };
        var parts = new List<string> { ru ? $"{day} в {time}" : $"{day} at {time}" };
        if (visit.PetNames.Count > 0)
        {
            parts.Add(string.Join(", ", visit.PetNames));
        }

        if (visit.Location is { } location)
        {
            parts.Add(location);
        }

        // Kept until the visit begins, at least a minute.
        var untilStart = visit.StartsAt - now;
        var ttl = untilStart < TimeSpan.FromMinutes(1) ? TimeSpan.FromMinutes(1)
            : untilStart > TimeSpan.FromDays(1) ? TimeSpan.FromDays(1)
            : untilStart;
        return new PushMessage(visit.Title, string.Join(" · ", parts), "appointments", $"appointment-{visit.AppointmentId}", ttl,
            new Dictionary<string, string> { ["kind"] = "appointment", ["appointmentId"] = visit.AppointmentId.ToString() });
    }

    /// <summary>"Time to buy: Royal Canin" — "Enough for about 5 days, until October 14".</summary>
    private static PushMessage Supply(SupplyDue due, bool ru)
    {
        string title, body;
        if (due.RunsOutToday)
        {
            title = ru ? $"{due.Name}: заканчивается" : $"{due.Name} is running out";
            body = ru
                ? "По прогнозу сегодня последний день. Купили — отметьте покупку."
                : "By the forecast, today is the last day. Bought it? Mark the purchase.";
        }
        else
        {
            title = ru ? $"Пора купить: {due.Name}" : $"Time to buy: {due.Name}";
            body = Left(due, ru, sentence: true);
        }

        return new PushMessage(title, body, "supplies", $"supply-{due.SupplyId}", TimeSpan.FromDays(1),
            new Dictionary<string, string> { ["kind"] = "supply", ["supplyId"] = due.SupplyId.ToString() });
    }

    /// <summary>"Supplies: 3 to buy" — "Royal Canin (5 days) · Litter (today)".</summary>
    private static PushMessage SupplyGroup(IReadOnlyList<SupplyDue> dues, bool ru)
    {
        var title = ru
            ? $"Запасы: пора купить {dues.Count} {Plural(dues.Count, "товар", "товара", "товаров")}"
            : $"Supplies: {dues.Count} to buy";
        var body = string.Join(" · ", dues.Select(d => $"{d.Name} ({Left(d, ru, sentence: false)})"));
        return new PushMessage(title, body, "supplies", "supplies", TimeSpan.FromDays(1),
            new Dictionary<string, string> { ["kind"] = "supplies" });
    }

    /// <summary>
    /// How long a supply lasts. As a sentence: "Enough for about 5 days, until October 14", "Runs out tomorrow"; inside
    /// a list: "5 days", "tomorrow".
    /// </summary>
    private static string Left(SupplyDue due, bool ru, bool sentence)
    {
        var date = ru ? due.RunsOutOn.ToString("d MMMM", Ru) : due.RunsOutOn.ToString("MMMM d", CultureInfo.InvariantCulture);
        var n = due.DaysLeft;
        var days = ru ? Plural(n, "день", "дня", "дней") : n == 1 ? "day" : "days";
        return (n, ru, sentence) switch
        {
            ( <= 0, true, true) => "Заканчивается сегодня",
            ( <= 0, false, true) => "Runs out today",
            ( <= 0, true, false) => "сегодня",
            ( <= 0, false, false) => "today",
            (1, true, true) => "Закончится завтра",
            (1, false, true) => "Runs out tomorrow",
            (1, true, false) => "завтра",
            (1, false, false) => "tomorrow",
            (_, true, true) => $"Хватит примерно на {n} {days}, до {date}",
            (_, false, true) => $"Enough for about {n} {days}, until {date}",
            (_, _, false) => $"{n} {days}",
        };
    }

    /// <summary>Russian plural: 1 день, 2 дня, 5 дней, 21 день.</summary>
    private static string Plural(int n, string one, string few, string many) =>
        (n % 100) is >= 11 and <= 14 ? many
        : (n % 10) switch
        {
            1 => one,
            >= 2 and <= 4 => few,
            _ => many,
        };
}
