// The household on screen. A person can be in several ("My home", "Office"), each with its own pets, records and
// role; GET /households lists them, and every request names the one on screen (X-Household, through useApi()). The
// choice is remembered per account on this browser. Pages ask useHousehold() for it and for what the role may do.
//
// The server may say the person isn't in the household any more (403 not-a-household-member: they left it on the
// phone, or an owner removed them) or that their role can't do something (403 role-forbidden: an owner may have
// changed it). Either way the list is read again: a household no longer in it gives way to the first one, with a word
// why, and a changed role shows at once.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { createContext, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { data, ProblemTypes, type ApiClient } from '../api/client';
import { keys } from '../api/keys';
import type { HouseholdSummary, Me } from '../api/types';
import { useToast } from '../components/Toasts';
import { useI18n } from '../i18n/i18n';
import { householdName } from '../lib/labels';
import { useSession } from '../session';
import { permissionsOf, type Permissions } from './permissions';
import { rememberHousehold } from './remembered';

export interface HouseholdState {
  current: HouseholdSummary;
  /** Every household the person is in, the first-joined first. */
  households: HouseholdSummary[];
  permissions: Permissions;
  switchTo: (id: string) => void;
  /**
   * The person left (or deleted) this household themselves, here: the move away from it needs no "You're no longer
   * in it" (the page that did it says what happened).
   */
  leftHere: (id: string) => void;
}

const HouseholdContext = createContext<HouseholdState | null>(null);

export function useHousehold(): HouseholdState {
  const household = useContext(HouseholdContext);
  if (!household) throw new Error('useHousehold() is only for pages inside <HouseholdProvider>');
  return household;
}

/** The API client of the household on screen. */
export function useApi(): ApiClient {
  const { api } = useSession();
  return api.forHousehold(useHousehold().current.id);
}

export function HouseholdProvider({ children }: { children: ReactNode }) {
  const { user, me, api } = useSession();
  const { t } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [currentId, setCurrentId] = useState(me.household.id);

  const { data: households } = useQuery({
    queryKey: keys.households(user.uid),
    // A list of the person's own: it doesn't depend on the household named.
    queryFn: ({ signal }) => data(api.forHousehold(null).GET('/api/v1/households', { signal })),
    // /me has just brought it.
    initialData: me.households,
    staleTime: 60_000,
  });

  const current =
    households.find((household) => household.id === currentId) ?? households[0] ?? toSummary(me.household);
  const shown = useRef(current);
  // The households the person left here: gone from the list without a word from here.
  const left = useRef(new Set<string>());

  useEffect(() => {
    if (households.some((household) => household.id === currentId)) {
      shown.current = households.find((household) => household.id === currentId)!;
      return;
    }
    // Not in it any more: the first household from now on, and a word why (unless the person left it here).
    const gone = shown.current;
    const next = households[0];
    if (!next) return;
    setCurrentId(next.id);
    if (!left.current.has(gone.id)) toast(t.householdLeftNotice(householdName(t, gone.name, gone.role)));
  }, [households, currentId, t, toast]);

  useEffect(() => {
    rememberHousehold(user.uid, current);
  }, [user.uid, current]);

  useEffect(
    () =>
      api.listen((event) => {
        if (event.kind !== 'failure' || event.error.status !== 403) return;
        const { type } = event.error;
        if (type === ProblemTypes.notAHouseholdMember || type === ProblemTypes.roleForbidden) {
          void queryClient.invalidateQueries({ queryKey: keys.households(user.uid) });
        }
      }),
    [api, queryClient, user.uid],
  );

  const state = useMemo<HouseholdState>(
    () => ({
      current,
      households,
      permissions: permissionsOf(current.role),
      switchTo: setCurrentId,
      leftHere: (id) => left.current.add(id),
    }),
    [current, households],
  );

  return <HouseholdContext.Provider value={state}>{children}</HouseholdContext.Provider>;
}

/** The household /me answered for, in the list's shape: on screen if the list ever comes back empty. */
function toSummary({ id, name, role, timeZone }: Me['household']): HouseholdSummary {
  return { id, name, role, timeZone, memberCount: 1 };
}
