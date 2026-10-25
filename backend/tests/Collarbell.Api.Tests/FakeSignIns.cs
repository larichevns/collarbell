using System.Collections.Concurrent;
using Collarbell.Api.Infrastructure.Auth;

namespace Collarbell.Api.Tests;

/// <summary>
/// Stands in for Firebase Authentication: remembers whose sign-in accounts were deleted, and a test can make Firebase
/// refuse for a subject. Tests use their own users, so other tests' deletions don't get in the way.
/// </summary>
public sealed class FakeSignIns : ISignInAccounts
{
    public ConcurrentBag<string> Deleted { get; } = [];

    /// <summary>Subjects Firebase can't delete right now.</summary>
    public ConcurrentDictionary<string, bool> Refusing { get; } = new();

    public Task<bool> DeleteAsync(string subject, CancellationToken ct)
    {
        if (Refusing.ContainsKey(subject))
        {
            return Task.FromResult(false);
        }

        Deleted.Add(subject);
        return Task.FromResult(true);
    }
}
