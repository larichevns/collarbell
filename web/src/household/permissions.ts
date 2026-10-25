// What the person's role in the household on screen lets them do: the one place for these rules, so pages ask "may I
// edit?" instead of checking roles (the phone app's HouseholdPermissions). The server checks the same rules; the app
// hides what it would refuse. Helpers (a sitter, a colleague) see everything and only mark: fed, "Done", the visit
// took place, bought.
import type { HouseholdRole } from '../api/types';

export interface Permissions {
  /** Add, change and delete pets, visits and photos; choose a plan's next date. */
  canEdit: boolean;
  /** Take a feeding mark back: helpers only their own. */
  canTakeBack: (byMe: boolean) => boolean;
  /** Invite people, change their roles, remove them: owners only. */
  canManagePeople: boolean;
}

export function permissionsOf(role: HouseholdRole): Permissions {
  const canEdit = role !== 'Helper';
  return { canEdit, canTakeBack: (byMe) => canEdit || byMe, canManagePeople: role === 'Owner' };
}
