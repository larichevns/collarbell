namespace Collarbell.Api.Modules.Identity;

/// <summary>
/// Hears that something the household's reminders depend on changed outside their own modules: a pet was paused,
/// renamed or deleted, or the household's time zone changed. Notifications plans the reminders again. Like
/// <c>IPetDeletionHandler</c>: Identity and Pets don't know the modules that listen.
/// </summary>
public interface IHouseholdChangeHandler
{
    /// <summary>Called after the change is saved.</summary>
    Task HouseholdChangedAsync(Guid householdId, CancellationToken ct);
}
