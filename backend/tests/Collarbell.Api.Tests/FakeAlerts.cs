using System.Collections.Concurrent;
using Collarbell.Api.Modules.Observe;

namespace Collarbell.Api.Tests;

/// <summary>Telegram for the tests: keeps the alerts that would have been sent.</summary>
public sealed class FakeAlerts : IAlertSender
{
    private readonly ConcurrentQueue<string> _sent = new();

    public IReadOnlyList<string> Sent => [.. _sent];

    public Task SendAsync(string text, CancellationToken ct)
    {
        _sent.Enqueue(text);
        return Task.CompletedTask;
    }
}
