// Whether the server answers. A call that got no answer makes it "not reachable"; any answer makes it reachable again.
// While it isn't, the banner (components/OfflineBanner.tsx) asks the server's /health now and then, the way the phone
// app's strip does.
import type { Api } from './client';

export interface Reachability {
  reachable(): boolean;
  /** Calls back on every change. Returns "stop". */
  subscribe(listener: () => void): () => void;
  /** Asks /health whether the server is back; true when it answered. */
  check(): Promise<boolean>;
}

export function createReachability(
  api: Api,
  fetch: typeof window.fetch,
  baseUrl = window.location.origin,
): Reachability {
  let reachable = true;
  const listeners = new Set<() => void>();
  const set = (value: boolean) => {
    if (value === reachable) return;
    reachable = value;
    listeners.forEach((listener) => listener());
  };

  api.listen((event) => {
    if (event.kind === 'answer') set(true);
    else if (event.error.status === 0) set(false);
  });

  return {
    reachable: () => reachable,
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    async check() {
      try {
        const response = await fetch(`${baseUrl}/health`, { cache: 'no-store' });
        set(response.ok);
      } catch {
        set(false);
      }
      return reachable;
    },
  };
}
