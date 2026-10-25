// Who is signed in, and the account the app shows. The steps: wait for Firebase to remember (or not) who was signed in
// on this browser → nobody: the sign-in page → someone: GET /api/v1/me, the first request after signing in (the server
// creates a new person and their first household on it, as with the phone app's profile sync), naming the household
// the person had on screen last time on this browser → the app. /me answers for the person's first household when
// they are no longer in that one, and the app says so. No answer: "Couldn't open your account" with "Try again".
//
// Later, any 401 signs out, and the sign-in page says why: the session expired, or the account was deleted (on the
// phone, or here: then this browser forgets the household it remembered for it); a 401 of a request that started
// under an earlier sign-in says nothing of this one. Another person (or the
// same one again) starts from nothing: the cache of the server's data is emptied whenever the account changes, and the
// account opens on its own /me. The pages get the session from useSession(), and the household on screen from
// household/household.tsx.
import { useQueryClient } from '@tanstack/react-query';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useEffectEvent,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { ApiError, createApi, data, ProblemTypes, type Api } from './api/client';
import { keys } from './api/keys';
import { createReachability, type Reachability } from './api/reachability';
import type { Me } from './api/types';
import type { AuthService, SignedInUser } from './auth/auth';
import { useClearToasts, useToast } from './components/Toasts';
import { HouseholdProvider } from './household/household';
import {
  forgetHousehold,
  forgetOtherAccounts,
  rememberedHousehold,
  type RememberedHousehold,
} from './household/remembered';
import { useI18n } from './i18n/i18n';
import { householdName } from './lib/labels';
import { LiveProvider } from './live/LiveProvider';
import { TAB_ID, type RealtimeClientFactory } from './live/realtime';
import { GateErrorPage, SplashPage } from './pages/GatePages';
import { LoginPage, type SignInNotice } from './pages/LoginPage';

/** What the app talks to: the sign-in and the network (window.fetch; the pretend server in the tests and the demo). */
export interface Services {
  auth: AuthService;
  fetch: typeof fetch;
  /**
   * The live updates' connections (live/signalr.ts; a pretend hub in the demo). Without it the tab hears nothing of
   * others' changes and reads Today every 30 seconds, as the tests do unless they ask for live updates.
   */
  live?: RealtimeClientFactory;
  /** This tab's id (X-Client); by default a new one per page load. */
  clientId?: string;
  /** The demo (npm run dev:mock): made-up data, no server. The app says so. */
  demo?: boolean;
}

export interface Session {
  user: SignedInUser;
  /** GET /me as it answered when the app opened. */
  me: Me;
  api: Api;
  reachability: Reachability;
  /** Signs out; with a reason, the sign-in page says it (the account was deleted). */
  signOut: (reason?: SignInNotice) => void;
  /** Asks for the password again (Firebase), before deleting the account. */
  reauthenticate: (password: string) => Promise<void>;
  /** The live updates' connections, if any (Services.live). */
  live: RealtimeClientFactory | null;
  /** This tab's id, sent as X-Client: a change the tab made comes back from the live updates with it. */
  clientId: string;
  /** The demo's made-up data (npm run dev:mock). */
  demo: boolean;
}

const SessionContext = createContext<Session | null>(null);

export function useSession(): Session {
  const session = useContext(SessionContext);
  if (!session) throw new Error('useSession() is only for pages inside <SessionGate>');
  return session;
}

/** The account of the person signed in (uid): being opened, open, or not opened for want of an answer. */
type Gate =
  | { state: 'opening' }
  | { state: 'ready'; uid: string; me: Me }
  | { state: 'failed'; error: unknown };

export function SessionGate({ services, children }: { services: Services; children: ReactNode }) {
  const { auth } = services;
  const { t, adopt } = useI18n();
  const toast = useToast();
  const clearToasts = useClearToasts();
  const queryClient = useQueryClient();
  // undefined: Firebase hasn't said yet; null: nobody is signed in.
  const [user, setUser] = useState<SignedInUser | null | undefined>(undefined);
  const [gate, setGate] = useState<Gate>({ state: 'opening' });
  // Why the sign-in page shows again, if not by "Sign out".
  const [notice, setNotice] = useState<SignInNotice | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(
    () =>
      auth.subscribe((next) =>
        // The same person again (Firebase repeats itself) changes nothing: no second /me, no flicker.
        setUser((previous) => (previous && next && previous.uid === next.uid ? previous : next)),
      ),
    [auth],
  );

  // The sign-in a request starts under: it grows with every change of the person signed in (or of nobody).
  const epoch = useRef(0);
  const shownUid = useRef<string | null | undefined>(undefined);

  const signOut = useCallback(
    (reason: SignInNotice | null = null) => {
      // The account is gone (deleted here, on a phone, or by a deletion whose answer got lost): nobody opens its
      // household on this browser again.
      if (reason === 'account-deleted' && shownUid.current) forgetHousehold(shownUid.current);
      setNotice(reason);
      clearToasts();
      void auth.signOut();
    },
    [auth, clearToasts],
  );

  const clientId = services.clientId ?? TAB_ID;
  const api = useMemo(
    () =>
      createApi({ fetch: services.fetch, token: () => auth.idToken(), epoch: () => epoch.current, clientId }),
    [services.fetch, auth, clientId],
  );
  const reachability = useMemo(() => createReachability(api, services.fetch), [api, services.fetch]);

  useEffect(
    () =>
      api.listen((event) => {
        // A 401 of a request that started under an earlier sign-in says nothing of this one.
        if (event.kind === 'failure' && event.error.status === 401 && event.error.epoch === epoch.current) {
          signOut(event.error.type === ProblemTypes.accountDeleted ? 'account-deleted' : 'session-expired');
        }
      }),
    [api, signOut],
  );

  // The account is open: the profile's language (unless one was picked here), and a word when the household of last
  // time isn't the person's any more. An effect event: a new language must not open the account again.
  const opened = useEffectEvent((uid: string, me: Me, remembered: RememberedHousehold | null) => {
    adopt(me.locale);
    // The households /me answered with now, not a list of an earlier sign-in.
    queryClient.setQueryData(keys.households(uid), me.households);
    if (remembered && remembered.id !== me.household.id) {
      toast(t.householdLeftNotice(householdName(t, remembered.name, remembered.role)));
    }
    setNotice(null);
    setGate({ state: 'ready', uid, me });
  });

  useEffect(() => {
    if (user === undefined) return;
    if ((user?.uid ?? null) !== shownUid.current) {
      // Another person, or nobody: the next one starts with nothing of this one's on screen, and nothing that
      // started under this sign-in speaks for the next.
      epoch.current += 1;
      const previous = shownUid.current;
      if (previous !== undefined) queryClient.clear();
      // Signed out: this browser forgets what it remembers of other accounts that used it (their households, their
      // onboarding's turn); this one's stays, for its next sign-in.
      if (user === null && previous) forgetOtherAccounts(previous);
      shownUid.current = user?.uid ?? null;
    }
    if (user === null) {
      // The same person signing in again opens the account anew: its /me first.
      setGate({ state: 'opening' });
      return;
    }
    const controller = new AbortController();
    const remembered = rememberedHousehold(user.uid);
    setGate({ state: 'opening' });
    data(api.forHousehold(remembered?.id ?? null).GET('/api/v1/me', { signal: controller.signal })).then(
      (me) => {
        if (!controller.signal.aborted) opened(user.uid, me, remembered);
      },
      (error: unknown) => {
        if (controller.signal.aborted) return;
        // A 401 has signed out already (the listener above), and the sign-in page will say why.
        if (!(error instanceof ApiError && error.status === 401)) setGate({ state: 'failed', error });
      },
    );
    return () => controller.abort();
  }, [user, api, attempt, queryClient]);

  // Open only for the person it was opened for: right after a sign-out or another sign-in, the old account is gone.
  const live = services.live ?? null;
  const session = useMemo<Session | null>(
    () =>
      gate.state === 'ready' && user && gate.uid === user.uid
        ? {
            user,
            me: gate.me,
            api,
            reachability,
            signOut: (reason) => signOut(reason ?? null),
            reauthenticate: (password) => auth.reauthenticate(password),
            live,
            clientId,
            demo: !!services.demo,
          }
        : null,
    [gate, user, api, reachability, signOut, auth, live, clientId, services.demo],
  );

  if (user === null) return <LoginPage auth={auth} notice={notice} demo={!!services.demo} />;
  if (session) {
    return (
      <SessionContext.Provider value={session}>
        <HouseholdProvider>
          <LiveProvider>{children}</LiveProvider>
        </HouseholdProvider>
      </SessionContext.Provider>
    );
  }
  if (gate.state === 'failed') {
    return (
      <GateErrorPage error={gate.error} onRetry={() => setAttempt((value) => value + 1)} onSignOut={() => signOut()} />
    );
  }
  return <SplashPage />;
}
