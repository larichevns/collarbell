using Collarbell.Api.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Modules.Notifications;

/// <summary>A person who may get a household's pushes: their language, the kinds they turned off, their phones.</summary>
public sealed record PushRecipient(Guid UserId, string Locale, IReadOnlySet<NotificationCategory> Off, List<string> Tokens);

/// <summary>Who gets a household's pushes: every member, on every phone they registered.</summary>
public static class PushRecipients
{
    public static async Task<Dictionary<Guid, List<PushRecipient>>> OfAsync(
        AppDbContext db, IReadOnlyCollection<Guid> householdIds, CancellationToken ct)
    {
        var members = await db.HouseholdMembers
            .Where(m => householdIds.Contains(m.HouseholdId))
            .Join(db.Users, m => m.UserId, u => u.Id, (m, u) => new { m.HouseholdId, UserId = u.Id, u.Locale })
            .ToListAsync(ct);
        var userIds = members.Select(m => m.UserId).Distinct().ToList();
        var tokens = await db.Devices
            .Where(d => userIds.Contains(d.UserId))
            .GroupBy(d => d.UserId)
            .ToDictionaryAsync(g => g.Key, g => g.Select(d => d.Token).ToList(), ct);
        var off = await db.NotificationPreferences
            .Where(p => userIds.Contains(p.UserId) && !p.Enabled)
            .GroupBy(p => p.UserId)
            .ToDictionaryAsync(g => g.Key, g => g.Select(p => p.Category).ToHashSet(), ct);

        return members
            .GroupBy(m => m.HouseholdId)
            .ToDictionary(g => g.Key, g => g
                .Select(m => new PushRecipient(
                    m.UserId,
                    m.Locale,
                    off.TryGetValue(m.UserId, out var categories) ? categories : [],
                    tokens.GetValueOrDefault(m.UserId, [])))
                .ToList());
    }
}
