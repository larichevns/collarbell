// A strip over the page while the server can't be reached (no internet, or the server restarting during a deploy).
// It asks the server again every 20 seconds and on "Try again"; once it answers, every page loads again with fresh
// data and the strip goes. Any answer of an ordinary request takes it away too.
import { useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useState, useSyncExternalStore } from 'react';
import { useI18n } from '../i18n/i18n';
import { useSession } from '../session';
import { Icon } from './Icon';
import { Spinner } from './ui';

const CHECK_EVERY_MS = 20_000;

export function OfflineBanner() {
  const { t } = useI18n();
  const { reachability } = useSession();
  const queryClient = useQueryClient();
  const reachable = useSyncExternalStore(reachability.subscribe, reachability.reachable);
  const [checking, setChecking] = useState(false);

  const check = useCallback(async () => {
    setChecking(true);
    const back = await reachability.check();
    setChecking(false);
    if (back) void queryClient.invalidateQueries();
  }, [reachability, queryClient]);

  useEffect(() => {
    if (reachable) return;
    const timer = window.setInterval(() => void check(), CHECK_EVERY_MS);
    return () => window.clearInterval(timer);
  }, [reachable, check]);

  if (reachable) return null;
  return (
    <div className="offline" role="status">
      <Icon name="cloud_off" />
      <span className="offline-text">{t.offlineBanner}</span>
      <button
        type="button"
        className="button button--inverse"
        onClick={() => void check()}
        disabled={checking}
      >
        {checking && <Spinner />}
        {t.commonTryAgain}
      </button>
    </div>
  );
}
