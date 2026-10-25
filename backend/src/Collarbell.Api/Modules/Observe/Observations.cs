using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Collarbell.Api.Modules.Observe;

// What the admin's "визор" shows of a person's last week: the API requests their phone made and what the app told
// the server about itself (screens, actions, errors). Kept for Retention, then deleted (spec, privacy policy).

internal static class ObserveSchema
{
    public const string Name = "observe";
}

public static class ObserveLimits
{
    /// <summary>How long requests and app events are kept.</summary>
    public static readonly TimeSpan Retention = TimeSpan.FromDays(7);
}

/// <summary>One API request: who, in which household, what, and what the server answered. No bodies, no query.</summary>
public sealed class RequestRecord
{
    private RequestRecord()
    {
    }

    public RequestRecord(DateTimeOffset at, Guid? userId, Guid? householdId, string method, string path, int status, int durationMs,
        Guid? session, string? appVersion)
    {
        At = at;
        UserId = userId;
        HouseholdId = householdId;
        Method = method;
        Path = path;
        Status = status;
        DurationMs = durationMs;
        Session = session;
        AppVersion = appVersion;
    }

    public long Id { get; private set; }

    public DateTimeOffset At { get; private set; }

    /// <summary>Null when the request had no signed-in user (a 401) or never got to know them.</summary>
    public Guid? UserId { get; private set; }

    public Guid? HouseholdId { get; private set; }

    public string Method { get; private set; } = null!;

    /// <summary>The path without the query: ids are there, the person's words aren't.</summary>
    public string Path { get; private set; } = null!;

    public int Status { get; private set; }

    public int DurationMs { get; private set; }

    /// <summary>The app's launch it came from (X-App-Session), to group a visit together.</summary>
    public Guid? Session { get; private set; }

    public string? AppVersion { get; private set; }

    /// <summary>The person's account is gone: the record stays, without who, where and from which launch.</summary>
    public void Forget()
    {
        UserId = null;
        HouseholdId = null;
        Session = null;
    }
}

[JsonConverter(typeof(JsonStringEnumConverter<AppEventKind>))]
public enum AppEventKind
{
    /// <summary>A screen opened: its route, e.g. <c>/pets/:id/health</c>.</summary>
    Screen,

    /// <summary>Something done: "fed", "saved a plan".</summary>
    Action,

    /// <summary>An error the person saw: its kind and status, never their data.</summary>
    Error,

    /// <summary>The app failed: the exception's type and where.</summary>
    Crash,
}

/// <summary>Something the app reported about itself (POST /api/v1/events).</summary>
public sealed class AppEvent
{
    private AppEvent()
    {
    }

    public AppEvent(Guid userId, Guid? householdId, Guid session, DateTimeOffset at, AppEventKind kind, string name, string? detail,
        string? appVersion, DateTimeOffset receivedAt)
    {
        UserId = userId;
        HouseholdId = householdId;
        Session = session;
        At = at;
        Kind = kind;
        Name = name;
        Detail = detail;
        AppVersion = appVersion;
        ReceivedAt = receivedAt;
    }

    public long Id { get; private set; }

    public Guid UserId { get; private set; }

    public Guid? HouseholdId { get; private set; }

    public Guid Session { get; private set; }

    /// <summary>When it happened by the phone's clock (kept within a week before and five minutes after receiving).</summary>
    public DateTimeOffset At { get; private set; }

    public AppEventKind Kind { get; private set; }

    public string Name { get; private set; } = null!;

    public string? Detail { get; private set; }

    public string? AppVersion { get; private set; }

    public DateTimeOffset ReceivedAt { get; private set; }
}

/// <summary>The last time an alert of a kind went out (one per kind every few hours), for the admin's list too.</summary>
public sealed class AlertRecord
{
    private AlertRecord()
    {
    }

    public AlertRecord(string kind, string text, DateTimeOffset sentAt)
    {
        Kind = kind;
        Text = text;
        SentAt = sentAt;
    }

    public string Kind { get; private set; } = null!;

    public string Text { get; set; } = null!;

    public DateTimeOffset SentAt { get; set; }
}

internal sealed class RequestRecordConfiguration : IEntityTypeConfiguration<RequestRecord>
{
    public void Configure(EntityTypeBuilder<RequestRecord> b)
    {
        b.ToTable("requests", ObserveSchema.Name);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).UseIdentityAlwaysColumn();
        b.Property(x => x.Method).HasMaxLength(8);
        b.Property(x => x.Path).HasMaxLength(300);
        b.Property(x => x.AppVersion).HasMaxLength(32);
        b.HasIndex(x => x.At);
        b.HasIndex(x => new { x.UserId, x.At });
        b.HasIndex(x => new { x.Status, x.At });
    }
}

internal sealed class AppEventConfiguration : IEntityTypeConfiguration<AppEvent>
{
    public void Configure(EntityTypeBuilder<AppEvent> b)
    {
        b.ToTable("app_events", ObserveSchema.Name);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).UseIdentityAlwaysColumn();
        b.Property(x => x.Kind).HasConversion<string>().HasMaxLength(16);
        b.Property(x => x.Name).HasMaxLength(AppEventsEndpoints.MaxNameLength);
        b.Property(x => x.Detail).HasMaxLength(AppEventsEndpoints.MaxDetailLength);
        b.Property(x => x.AppVersion).HasMaxLength(32);
        b.HasIndex(x => x.ReceivedAt);
        b.HasIndex(x => new { x.UserId, x.At });
        b.HasIndex(x => new { x.UserId, x.ReceivedAt });
        b.HasIndex(x => new { x.Kind, x.At });
    }
}

internal sealed class AlertRecordConfiguration : IEntityTypeConfiguration<AlertRecord>
{
    public void Configure(EntityTypeBuilder<AlertRecord> b)
    {
        b.ToTable("alerts", ObserveSchema.Name);
        b.HasKey(x => x.Kind);
        b.Property(x => x.Kind).HasMaxLength(40);
        b.Property(x => x.Text).HasMaxLength(500);
    }
}
