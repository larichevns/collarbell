using System.Text.Json.Serialization;

namespace Collarbell.Api.Modules.Notifications;

[JsonConverter(typeof(JsonStringEnumConverter<DevicePlatform>))]
public enum DevicePlatform
{
    Android,
    Ios,
}

/// <summary>
/// A phone that receives pushes. <see cref="Id"/> is chosen by the app once per installation; <see cref="Token"/> is
/// Firebase's address of the phone, which Firebase changes from time to time (the app then registers again).
/// A phone belongs to whoever registered it last: when another person signs in on it, the pushes follow them.
/// </summary>
public sealed class Device
{
    private Device()
    {
    }

    public Device(Guid id, Guid userId, DevicePlatform platform, string token, DateTimeOffset now)
    {
        Id = id;
        UserId = userId;
        Platform = platform;
        Token = token;
        CreatedAt = now;
        LastSeenAt = now;
    }

    public Guid Id { get; private set; }

    public Guid UserId { get; private set; }

    public DevicePlatform Platform { get; private set; }

    public string Token { get; private set; } = null!;

    public string? AppVersion { get; set; }

    public DateTimeOffset CreatedAt { get; private set; }

    /// <summary>The last time the app registered the phone (it does on every start).</summary>
    public DateTimeOffset LastSeenAt { get; set; }

    /// <summary>The app registered the phone again: maybe with a new token, maybe for another person.</summary>
    public void Register(Guid userId, DevicePlatform platform, string token, DateTimeOffset now)
    {
        UserId = userId;
        Platform = platform;
        Token = token;
        LastSeenAt = now;
    }
}

/// <summary>A kind of reminder a person turned off or on again. Without a row the kind is on.</summary>
public sealed class NotificationPreference
{
    private NotificationPreference()
    {
    }

    public NotificationPreference(Guid userId, NotificationCategory category, bool enabled)
    {
        UserId = userId;
        Category = category;
        Enabled = enabled;
    }

    public Guid UserId { get; private set; }

    public NotificationCategory Category { get; private set; }

    public bool Enabled { get; set; }
}
