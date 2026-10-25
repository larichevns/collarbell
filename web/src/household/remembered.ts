// What this browser remembers per account. The household a person had on screen last time: the app opens it again
// after the next sign-in, with its name and the role, so "You're no longer in “Office”" can still name it when the
// person isn't in it any more. And whether the onboarding ("Getting to know the app") had its turn
// (takeOnboardingTurn).
// Every access is wrapped: storage switched off (a private window, blocked site data) must not break the app.
import type { HouseholdRole } from '../api/types';

export interface RememberedHousehold {
  id: string;
  name: string;
  role: HouseholdRole;
}

const keyOf = (uid: string) => `collarbell.household.${uid}`;
const onboardingKeyOf = (uid: string) => `collarbell.onboarding.${uid}`;

export function rememberedHousehold(uid: string): RememberedHousehold | null {
  try {
    const value: unknown = JSON.parse(window.localStorage.getItem(keyOf(uid)) ?? 'null');
    if (!value || typeof value !== 'object') return null;
    const { id, name, role } = value as Partial<RememberedHousehold>;
    const known = role === 'Owner' || role === 'Member' || role === 'Helper';
    return typeof id === 'string' && typeof name === 'string' && known ? { id, name, role } : null;
  } catch {
    // Storage switched off, or something else written there: nothing remembered.
    return null;
  }
}

export function rememberHousehold(uid: string, household: RememberedHousehold): void {
  try {
    const { id, name, role } = household;
    window.localStorage.setItem(keyOf(uid), JSON.stringify({ id, name, role }));
  } catch {
    // Storage switched off: the next sign-in starts in the first household.
  }
}

/**
 * Whether the onboarding opens by itself now, for the account `uid` on this browser (the phone app's OnboardingTurn):
 * once, for a new account: someone who can add pets, in one household only (the one made for them at their first
 * sign-in), with no pets in it at all. Anyone else gets their turn marked as taken without it showing: someone whose
 * household has pets, even only archived ones (they used the app before); a family member who joined another household
 * (their own empty one may be on screen in a new browser, and "Who lives with you?" there would add the cat a second
 * time, in the wrong household); a helper. The turn is taken at once, so it opens once, whatever reloads or household
 * switches follow. Settings → "Getting to know the app" opens it any time. Storage switched off: never by itself,
 * rather than at every visit.
 */
export function takeOnboardingTurn(
  uid: string,
  { canEdit, hasPets, households }: { canEdit: boolean; hasPets: boolean; households: number },
): boolean {
  try {
    const key = onboardingKeyOf(uid);
    if (window.localStorage.getItem(key)) return false;
    window.localStorage.setItem(key, '1');
    return canEdit && !hasPets && households === 1;
  } catch {
    return false;
  }
}

/** The onboarding was seen (opened from Settings, say): it won't open by itself after it. */
export function markOnboardingSeen(uid: string): void {
  try {
    window.localStorage.setItem(onboardingKeyOf(uid), '1');
  } catch {
    // Storage switched off: it never opens by itself anyway.
  }
}

/** Forgets what is remembered for `uid`: its account is deleted, nobody opens its household again. */
export function forgetHousehold(uid: string): void {
  try {
    window.localStorage.removeItem(keyOf(uid));
    window.localStorage.removeItem(onboardingKeyOf(uid));
  } catch {
    // Storage switched off: nothing is remembered anyway.
  }
}

/**
 * Forgets what is remembered for every account but `uid` (a sign-out on a browser others used too): their households
 * and their onboarding's turn.
 */
export function forgetOtherAccounts(uid: string): void {
  try {
    const own = [keyOf(uid), onboardingKeyOf(uid)];
    const prefixes = [keyOf(''), onboardingKeyOf('')];
    const others: string[] = [];
    for (let index = 0; index < window.localStorage.length; index += 1) {
      const key = window.localStorage.key(index);
      if (key && prefixes.some((prefix) => key.startsWith(prefix)) && !own.includes(key)) others.push(key);
    }
    for (const key of others) window.localStorage.removeItem(key);
  } catch {
    // Storage switched off: nothing is remembered anyway.
  }
}
