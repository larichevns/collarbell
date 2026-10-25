// What the app talks to: the sign-in, the network and the live updates. Firebase, the server and its hub normally; in
// the demo (npm run dev:mock, Vite's mode "mock") a pretend sign-in, server and hub with made-up data instead
// (src/mock/), so every screen works without an account or a server. In a normal build the demo's branch is dropped:
// its code isn't in dist/.
import { createFirebaseAuth } from './auth/firebase';
import type { RealtimeClient } from './live/realtime';
import type { Services } from './session';

export async function createServices(): Promise<Services> {
  if (import.meta.env.MODE === 'mock') {
    const { createDemoServices } = await import('./mock/services');
    return createDemoServices(window.location.search);
  }
  return { auth: createFirebaseAuth(), fetch: (input, init) => window.fetch(input, init), live: lazySignalR };
}

/**
 * A live connection whose SignalR client loads with its first connection: the first page needn't wait for it, and
 * the browser keeps it from then on.
 */
function lazySignalR(): RealtimeClient {
  let inner: RealtimeClient | null = null;
  let closed = false;
  const client: RealtimeClient = {
    onChange: null,
    onClose: null,
    get connected() {
      return inner?.connected ?? false;
    },
    async connect(url, ticket) {
      const { createSignalRClient } = await import('./live/signalr');
      if (closed) throw new Error('Closed while the client loaded.');
      inner = createSignalRClient();
      inner.onChange = (change) => client.onChange?.(change);
      inner.onClose = () => client.onClose?.();
      await inner.connect(url, ticket);
    },
    async close() {
      closed = true;
      await inner?.close();
    },
  };
  return client;
}
