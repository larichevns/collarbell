namespace Collarbell.Api.Infrastructure.Validation;

/// <summary>Collects field errors for a 400 ValidationProblem. Field names are the JSON names the client sent.</summary>
public sealed class ValidationErrors
{
    private readonly Dictionary<string, List<string>> _errors = [];

    public bool HasErrors => _errors.Count > 0;

    public void Add(string field, string message)
    {
        if (!_errors.TryGetValue(field, out var messages))
        {
            _errors[field] = messages = [];
        }

        messages.Add(message);
    }

    /// <summary>Copies another set of errors, with field names under <paramref name="prefix"/> (e.g. "records[2].").</summary>
    public void AddAll(string prefix, ValidationErrors other)
    {
        foreach (var (field, messages) in other._errors)
        {
            foreach (var message in messages)
            {
                Add(prefix + field, message);
            }
        }
    }

    public void MaxLength(string field, string? value, int max)
    {
        if (value is not null && value.Length > max)
        {
            Add(field, $"Use {max} characters or fewer.");
        }
    }

    public void NotInFuture(string field, DateOnly? date, DateOnly latest)
    {
        if (date > latest)
        {
            Add(field, "The date can't be in the future.");
        }
    }

    public Dictionary<string, string[]> ToDictionary() =>
        _errors.ToDictionary(e => e.Key, e => e.Value.ToArray());
}

public static class Input
{
    /// <summary>Trims the text; an empty string becomes null. NUL characters go: the database refuses text with them.</summary>
    public static string? Clean(string? text)
    {
        var withoutNul = text?.Replace("\0", "", StringComparison.Ordinal);
        return string.IsNullOrWhiteSpace(withoutNul) ? null : withoutNul.Trim();
    }

    /// <summary>
    /// The latest date that is "today" somewhere on Earth (UTC+14). Dates after it are in the future
    /// for everyone, whatever the household's time zone.
    /// </summary>
    public static DateOnly LatestToday(TimeProvider clock) =>
        DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime.AddHours(14));
}
