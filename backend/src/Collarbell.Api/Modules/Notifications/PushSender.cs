using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Options;

namespace Collarbell.Api.Modules.Notifications;

/// <summary>
/// The <c>Notifications</c> settings section. The Firebase key is never in the repo: it comes from the AppHost's
/// secret parameter <c>firebase-service-account</c> (user secrets on the developer's Mac, a secret on the server).
/// </summary>
public sealed class NotificationsOptions
{
    /// <summary>
    /// The Firebase project's service account key (JSON, from Project settings → Service accounts). Without it the
    /// server plans reminders but can't send them.
    /// </summary>
    public string? FirebaseCredentials { get; set; }

    /// <summary>How often the dispatcher looks for due reminders. Zero turns it off (the tests run it themselves).</summary>
    public TimeSpan DispatchInterval { get; set; } = TimeSpan.FromSeconds(15);

    /// <summary>How often every household's reminders are planned again. Zero turns it off.</summary>
    public TimeSpan PlanInterval { get; set; } = TimeSpan.FromMinutes(10);
}

/// <summary>A push as phones show it.</summary>
/// <param name="Channel">The Android notification channel; the app creates one per <see cref="NotificationCategory"/>.</param>
/// <param name="Tag">A newer push with the same tag replaces the older one on the phone instead of piling up.</param>
/// <param name="TimeToLive">How long Firebase keeps trying to deliver to a phone that is off; later it drops it.</param>
/// <param name="Data">What the app needs to open the right screen when the push is tapped.</param>
public sealed record PushMessage(
    string Title,
    string Body,
    string Channel,
    string Tag,
    TimeSpan TimeToLive,
    IReadOnlyDictionary<string, string> Data);

/// <summary>What happened to a push for one phone.</summary>
public enum PushResult
{
    Delivered,

    /// <summary>The phone's address is no longer valid (the app was removed): the phone is forgotten.</summary>
    InvalidToken,

    /// <summary>Firebase is busy or unreachable: try again later.</summary>
    TryAgain,

    /// <summary>Refused for another reason; trying again won't help.</summary>
    Failed,
}

/// <summary>Sends pushes. Firebase Cloud Messaging in the app, a fake in the tests.</summary>
public interface IPushSender
{
    /// <summary>Whether the server has what it needs to send (the Firebase key).</summary>
    bool IsConfigured { get; }

    /// <summary>Sends one push to the phones with these addresses; one result per address, in the same order.</summary>
    Task<IReadOnlyList<PushResult>> SendAsync(PushMessage message, IReadOnlyList<string> tokens, CancellationToken ct);
}

/// <summary>Pushes through Firebase Cloud Messaging (HTTP v1), to Android phones for now (iPhones need Apple's key).</summary>
public sealed class FcmPushSender : IPushSender
{
    private readonly FirebaseMessaging? _messaging;
    private readonly ILogger<FcmPushSender> _log;

    /// <param name="configuration">
    /// <c>Firebase:ProjectId</c>: the app's Firebase project. A key of another project is refused: Firebase would answer
    /// every phone with "wrong sender", and that must not look like phones that are gone.
    /// </param>
    public FcmPushSender(IOptions<NotificationsOptions> options, IConfiguration configuration, ILogger<FcmPushSender> log)
    {
        _log = log;
        var json = options.Value.FirebaseCredentials;
        if (string.IsNullOrWhiteSpace(json))
        {
            return;
        }

        try
        {
            // Only a service account key is accepted, not any credential JSON.
            var account = CredentialFactory.FromJson<ServiceAccountCredential>(json);
            var projectId = configuration["Firebase:ProjectId"];
            if (!string.IsNullOrWhiteSpace(projectId) && account.ProjectId != projectId)
            {
                log.LogError("The Firebase key is for project {KeyProject}, the app uses {AppProject}: pushes are off.",
                    account.ProjectId, projectId);
                return;
            }

            const string appName = "collarbell-push";
            var app = FirebaseApp.GetInstance(appName) ?? FirebaseApp.Create(
                new AppOptions { Credential = account.ToGoogleCredential(), ProjectId = account.ProjectId }, appName);
            _messaging = FirebaseMessaging.GetMessaging(app);
        }
        catch (Exception e)
        {
            log.LogError(e, "The Firebase key in Notifications:FirebaseCredentials isn't a valid service account key: pushes are off.");
        }
    }

    public bool IsConfigured => _messaging is not null;

    public async Task<IReadOnlyList<PushResult>> SendAsync(PushMessage message, IReadOnlyList<string> tokens, CancellationToken ct)
    {
        if (_messaging is null || tokens.Count == 0)
        {
            return [.. tokens.Select(_ => PushResult.Failed)];
        }

        var multicast = new MulticastMessage
        {
            // Firebase is moving from registration tokens to installation ids (FIDs) and the Admin SDK 3.6 marked
            // Tokens obsolete, but FCM accepts both and the Flutter plugin (firebase_messaging 16.7) still hands out
            // registration tokens. Switch to Fids when the plugin does.
#pragma warning disable CS0618
            Tokens = [.. tokens],
#pragma warning restore CS0618
            Notification = new Notification { Title = message.Title, Body = message.Body },
            Data = message.Data,
            Android = new AndroidConfig
            {
                // High priority wakes a sleeping phone: a reminder must arrive on time.
                Priority = Priority.High,
                TimeToLive = message.TimeToLive,
                Notification = new AndroidNotification { ChannelId = message.Channel, Tag = message.Tag },
            },
        };

        try
        {
            var response = await _messaging.SendEachForMulticastAsync(multicast, ct);
            return [.. response.Responses.Select(r => r.IsSuccess ? PushResult.Delivered : Log(r.Exception))];
        }
        catch (Exception e) when (!ct.IsCancellationRequested)
        {
            // Also a timeout: it arrives as a cancellation that nobody asked for.
            _log.LogWarning(e, "Firebase couldn't be reached; the push will be tried again.");
            return [.. tokens.Select(_ => PushResult.TryAgain)];
        }
    }

    private PushResult Log(FirebaseMessagingException? e)
    {
        var result = Classify(e?.MessagingErrorCode, e?.ErrorCode);
        if (result is PushResult.Failed or PushResult.TryAgain)
        {
            _log.LogWarning(e, "Firebase didn't take a push ({Code}, {ErrorCode}).", e?.MessagingErrorCode, e?.ErrorCode);
        }

        return result;
    }

    /// <summary>
    /// What a phone's error means. Only "unregistered" means the phone is gone. Busy or unreachable Firebase (also a
    /// network failure, which comes without a messaging code) is worth another try. Anything else, such as a wrong
    /// sender (a key of another project), fails without touching the phones.
    /// </summary>
    internal static PushResult Classify(MessagingErrorCode? messagingCode, ErrorCode? code) => messagingCode switch
    {
        MessagingErrorCode.Unregistered => PushResult.InvalidToken,
        MessagingErrorCode.Unavailable or MessagingErrorCode.Internal or MessagingErrorCode.QuotaExceeded => PushResult.TryAgain,
        null when code is ErrorCode.Unavailable or ErrorCode.Internal or ErrorCode.DeadlineExceeded or ErrorCode.Unknown
            or ErrorCode.ResourceExhausted => PushResult.TryAgain,
        _ => PushResult.Failed,
    };
}
