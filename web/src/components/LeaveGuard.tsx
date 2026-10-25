// "Leave without saving?" before typed input is left: a link, Back, another household (it opens the section's first
// page, which may be the very page on screen), or closing the tab (the browser's own question). While a save (or an
// upload) is on its way, a move waits for it without a question: it goes on once the save is done (a form that saved
// moves on to what it saved instead), or asks when the save failed and typed input is still there. A forced move (the
// household on screen is gone) never asks. After a save the form leaves freely.
//
// React Router consults one blocker only, so there is one, in the frame (LeaveGuardProvider, in Layout): every form,
// dialog and upload registers what it holds with useLeaveGuard(changed, busy), and the frame asks when any of them
// would lose something.
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { useBlocker, type BlockerFunction } from 'react-router';
import { useHousehold } from '../household/household';
import { useI18n } from '../i18n/i18n';
import { ConfirmDialog } from './Dialog';

/**
 * The state of a move that must not ask: the household on screen is gone, nothing is left to save the form to. The
 * frame takes the mark off once the move has landed, so Back to that page later asks as any move does.
 */
export const FORCED_MOVE = { forced: true };

interface Guard {
  /** Typed input that leaving would lose. */
  changed: boolean;
  /** A save on its way: leaving waits for it. */
  busy: boolean;
  /** Saved (or deleted): leaving loses nothing any more. */
  allowed: boolean;
  /** What leaving loses, in words of the page ("The scan stays on the Passport tab"); else the usual words. */
  message?: string;
}

interface Leave {
  register: (guard: { current: Guard }) => () => void;
  /** A guard's typed input or save changed: a move held back may go on, or ask. */
  notify: () => void;
}

const LeaveContext = createContext<Leave | null>(null);

/** The frame's one blocker, and its question. */
export function LeaveGuardProvider({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const guards = useRef(new Set<{ current: Guard }>());
  const [changes, setChanges] = useState(0);
  const holding = () => [...guards.current].some((guard) => !guard.current.allowed && guard.current.busy);
  const losing = () => [...guards.current].some((guard) => !guard.current.allowed && guard.current.changed);
  const message = () =>
    [...guards.current].find((guard) => !guard.current.allowed && guard.current.changed)?.current.message;

  const shouldBlock = useCallback<BlockerFunction>(({ currentLocation, nextLocation }) => {
    const state = nextLocation.state as (Partial<typeof FORCED_MOVE> & { household?: string }) | null;
    const moving = currentLocation.pathname !== nextLocation.pathname || !!state?.household;
    return moving && !state?.forced && (holding() || losing());
  }, []);
  const blocker = useBlocker(shouldBlock);

  // A move held back while a save was on its way goes on once nothing would be lost; typed input left asks below.
  useEffect(() => {
    if (blocker.state === 'blocked' && !holding() && !losing()) blocker.proceed();
  }, [blocker, changes]);

  const notify = useCallback(() => setChanges((value) => value + 1), []);
  const register = useCallback<Leave['register']>(
    (guard) => {
      guards.current.add(guard);
      return () => {
        guards.current.delete(guard);
        notify();
      };
    },
    [notify],
  );
  const leave = useMemo(() => ({ register, notify }), [register, notify]);

  return (
    <LeaveContext.Provider value={leave}>
      {children}
      {blocker.state === 'blocked' && !holding() && losing() && (
        <ConfirmDialog
          title={t.leaveTitle}
          body={message() ?? t.leaveBody}
          confirmLabel={t.leaveConfirm}
          danger
          onConfirm={() => blocker.proceed()}
          onCancel={() => blocker.reset()}
        />
      )}
    </LeaveContext.Provider>
  );
}

/**
 * What a form, a dialog or an upload holds: typed input (`changed`), a save on its way (`busy`). `allowLeave` after
 * a save: the move that follows asks nothing. `message`: what leaving loses, when the usual words say too little.
 */
export function useLeaveGuard(changed: boolean, busy = false, message?: string): { allowLeave: () => void } {
  const leave = useContext(LeaveContext);
  const guard = useRef<Guard>({ changed, busy, allowed: false, message });
  useLayoutEffect(() => {
    const held = guard.current;
    held.message = message;
    if (held.changed === changed && held.busy === busy) return;
    held.changed = changed;
    held.busy = busy;
    leave?.notify();
  });
  useEffect(() => leave?.register(guard), [leave]);

  useEffect(() => {
    if (!changed && !busy) return;
    const ask = (event: BeforeUnloadEvent) => {
      if (!guard.current.allowed) event.preventDefault();
    };
    window.addEventListener('beforeunload', ask);
    return () => window.removeEventListener('beforeunload', ask);
  }, [changed, busy]);

  const allowLeave = useCallback(() => {
    guard.current.allowed = true;
  }, []);
  return { allowLeave };
}

/**
 * Whether a page that saved is still the one on screen, in the household it was opened in: only then does it move on
 * to what it saved. Leaving waits for a save, but a household can still go away meanwhile (the person was removed).
 */
export function useStillHere(household: string): () => boolean {
  const { current } = useHousehold();
  const state = useRef({ mounted: true, household: current.id });
  useLayoutEffect(() => {
    state.current.household = current.id;
  });
  useEffect(() => {
    state.current.mounted = true;
    return () => {
      state.current.mounted = false;
    };
  }, []);
  return useCallback(() => state.current.mounted && state.current.household === household, [household]);
}
