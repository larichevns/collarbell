// Live updates in the app: one LiveUpdates (live.ts) per session, told who is signed in, the household on screen and
// whether the tab is shown; what it hears is read again through React Query (topics.ts). Pages ask useLiveStatus()
// whether the tab is connected: Today stops reading itself every 30 seconds while it is. The sidebar shows the status
// (LiveStatusBadge). Without Services.live (the tests, unless they ask) nothing connects and the status stays "off".
import { useQueryClient } from '@tanstack/react-query';
import {
  createContext,
  useContext,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from 'react';
import { data } from '../api/client';
import { useHousehold } from '../household/household';
import { useI18n } from '../i18n/i18n';
import { useSession } from '../session';
import { LiveUpdates, type LiveStatus } from './live';
import { readEverything, readTopics } from './topics';

const LiveContext = createContext<LiveStatus>('off');

/** Where live updates stand for this tab. */
export function useLiveStatus(): LiveStatus {
  return useContext(LiveContext);
}

/** The hub's address for a household, at this page's origin (nginx passes /hubs/ on to the API). */
export function hubUrl(household: string, origin = window.location.origin): string {
  return `${origin}/hubs/household?household=${encodeURIComponent(household)}`;
}

function subscribeVisibility(onChange: () => void): () => void {
  document.addEventListener('visibilitychange', onChange);
  return () => document.removeEventListener('visibilitychange', onChange);
}

/** The tab is shown: not in the background, not minimized. */
function useTabVisible(): boolean {
  return useSyncExternalStore(subscribeVisibility, () => document.visibilityState !== 'hidden');
}

export function LiveProvider({ children }: { children: ReactNode }) {
  const { user, api, live, clientId } = useSession();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  const visible = useTabVisible();
  const [status, setStatus] = useState<LiveStatus>('off');
  const controller = useRef<LiveUpdates | null>(null);
  // Where the tab is, for a controller made after it changed.
  const state = useRef({ user: user.uid as string | null, household: current.id as string | null, visible });
  useLayoutEffect(() => {
    state.current = { user: user.uid, household: current.id, visible };
  });

  useEffect(() => {
    if (!live) return;
    const uid = user.uid;
    const updates = new LiveUpdates({
      newClient: live,
      // A ticket is the person's, whatever household is on screen.
      ticket: async () => (await data(api.forHousehold(null).POST('/api/v1/live/tickets'))).ticket,
      url: (household) => hubUrl(household),
      clientId,
      onChanged: (household, topics) => readTopics(queryClient, household, uid, topics),
      onReconnected: (household) => readEverything(queryClient, household, uid),
      onStatus: setStatus,
    });
    controller.current = updates;
    updates.update(state.current);
    return () => {
      updates.dispose();
      controller.current = null;
      setStatus('off');
    };
  }, [live, api, clientId, queryClient, user.uid]);

  useEffect(() => {
    controller.current?.update({ user: user.uid, household: current.id, visible });
  }, [user.uid, current.id, visible]);

  return <LiveContext.Provider value={status}>{children}</LiveContext.Provider>;
}

/** "Live" or "Reconnecting…" in the sidebar; nothing while live updates are off or refused. */
export function LiveStatusBadge() {
  const { t } = useI18n();
  const status = useLiveStatus();
  const shown = status === 'live' || status === 'connecting' || status === 'reconnecting';
  return (
    <p className="live-status" aria-live="polite">
      {shown && (
        <span className={`live-status-${status}`} title={status === 'live' ? t.liveOnHint : t.liveOffHint}>
          <span className="live-dot" aria-hidden="true" />
          {status === 'live' ? t.liveOn : status === 'connecting' ? t.liveConnecting : t.liveReconnecting}
        </span>
      )}
    </p>
  );
}
