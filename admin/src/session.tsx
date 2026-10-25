// Who may see the admin. The steps: wait for Firebase to remember (or not) who was signed in on this browser →
// nobody: the sign-in form → someone: ask the server GET /api/admin/me → 200: the admin; 403: "Нет доступа: этот
// аккаунт не админ" with "Выйти"; no answer: "Повторить". Later, any 401 from the API signs out (the form says why),
// any 403 shows "Нет доступа". The pages get the session (who, the API, "Выйти") from useSession().
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { ApiError, createAdminApi, errorText, type AdminApi } from './api/client';
import type { AdminMe } from './api/types';
import type { SignedInUser } from './auth/auth';
import { GateErrorPage, NoAccessPage, SplashPage } from './pages/GatePages';
import { LoginPage } from './pages/LoginPage';
import type { Services } from './services';

export interface Session {
  me: AdminMe;
  api: AdminApi;
  /** Test data (npm run dev:mock). */
  mock: boolean;
  signOut: () => void;
}

const SessionContext = createContext<Session | null>(null);

export function useSession(): Session {
  const session = useContext(SessionContext);
  if (!session) throw new Error('useSession() is only for pages inside <SessionGate>');
  return session;
}

type Gate =
  | { state: 'starting' }
  | { state: 'signed-out' }
  | { state: 'checking' }
  | { state: 'admin'; me: AdminMe }
  | { state: 'not-admin' }
  | { state: 'failed'; error: string };

const SESSION_ENDED = 'Вход больше не действует. Войдите снова.';

export function SessionGate({ services, children }: { services: Services; children: ReactNode }) {
  const { auth } = services;
  // undefined: Firebase hasn't said yet; null: nobody is signed in.
  const [user, setUser] = useState<SignedInUser | null | undefined>(undefined);
  const [gate, setGate] = useState<Gate>({ state: 'starting' });
  // Why the sign-in form is shown again, if not by "Выйти".
  const [notice, setNotice] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(
    () =>
      auth.subscribe((next) =>
        // The same person again (Firebase repeats itself) changes nothing: no second check, no flicker.
        setUser((previous) => (previous && next && previous.uid === next.uid ? previous : next)),
      ),
    [auth],
  );

  const signOut = useCallback(
    (reason: string | null = null) => {
      setNotice(reason);
      void auth.signOut();
    },
    [auth],
  );

  const api = useMemo(
    () =>
      createAdminApi({
        fetch: services.fetch,
        token: () => auth.idToken(),
        onAuthError: (status) => {
          if (status === 401) signOut(SESSION_ENDED);
          else setGate((current) => (current.state === 'admin' ? { state: 'not-admin' } : current));
        },
      }),
    [services.fetch, auth, signOut],
  );

  useEffect(() => {
    if (user === undefined) return;
    if (user === null) {
      setGate({ state: 'signed-out' });
      return;
    }
    const controller = new AbortController();
    setGate({ state: 'checking' });
    api.me(controller.signal).then(
      (me) => {
        if (controller.signal.aborted) return;
        setNotice(null);
        setGate({ state: 'admin', me });
      },
      (error: unknown) => {
        if (controller.signal.aborted) return;
        if (error instanceof ApiError && error.status === 403) setGate({ state: 'not-admin' });
        // 401: onAuthError has already signed out, and the form will say why.
        else if (!(error instanceof ApiError && error.status === 401)) setGate({ state: 'failed', error: errorText(error) });
      },
    );
    return () => controller.abort();
  }, [user, api, attempt]);

  const session = useMemo<Session | null>(
    () => (gate.state === 'admin' ? { me: gate.me, api, mock: services.mock, signOut: () => signOut() } : null),
    [gate, api, services.mock, signOut],
  );

  switch (gate.state) {
    case 'starting':
      return <SplashPage text="Загрузка…" />;
    case 'checking':
      return <SplashPage text="Проверяем доступ…" />;
    case 'signed-out':
      return <LoginPage auth={auth} notice={notice} mock={services.mock} />;
    case 'not-admin':
      return <NoAccessPage email={user?.email ?? null} onSignOut={() => signOut()} />;
    case 'failed':
      return (
        <GateErrorPage error={gate.error} onRetry={() => setAttempt((value) => value + 1)} onSignOut={() => signOut()} />
      );
    case 'admin':
      return <SessionContext.Provider value={session}>{children}</SessionContext.Provider>;
  }
}
