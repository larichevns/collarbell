using System.Collections.Concurrent;
using Collarbell.Api.Modules.Notifications;

namespace Collarbell.Api.Tests;

/// <summary>
/// Stands in for Firebase in tests: remembers every push it "delivered", and a test can make a phone's address dead
/// or Firebase busy for it. Tests use their own phone tokens, so pushes to other tests' phones don't get in the way.
/// </summary>
public sealed class FakePush : IPushSender
{
    private readonly ConcurrentQueue<(PushMessage Message, string Token)> _delivered = new();

    public bool IsConfigured { get; set; } = true;

    /// <summary>What Firebase answers for a token; delivered when not set.</summary>
    public ConcurrentDictionary<string, PushResult> Results { get; } = new();

    public Task<IReadOnlyList<PushResult>> SendAsync(PushMessage message, IReadOnlyList<string> tokens, CancellationToken ct)
    {
        var results = tokens.Select(t => Results.GetValueOrDefault(t, PushResult.Delivered)).ToList();
        for (var i = 0; i < tokens.Count; i++)
        {
            if (results[i] == PushResult.Delivered)
            {
                _delivered.Enqueue((message, tokens[i]));
            }
        }

        return Task.FromResult<IReadOnlyList<PushResult>>(results);
    }

    /// <summary>The pushes delivered to this phone, oldest first.</summary>
    public List<PushMessage> To(string token) => [.. _delivered.Where(d => d.Token == token).Select(d => d.Message)];
}
