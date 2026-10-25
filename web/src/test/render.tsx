// The whole app on the pretend server and sign-in, in a memory router: what a test clicks is what a person clicks.
import { QueryClient } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { createMemoryRouter } from 'react-router';
import { App } from '../App';
import type { RealtimeClientFactory } from '../live/realtime';
import { routes } from '../routes';
import { createTestAuth } from './auth';
import { ANNA, createTestServer, type TestServer } from './server';

interface Options {
  /** Who is signed in on this browser; null: nobody. */
  user?: string | null;
  server?: TestServer;
  /** Live updates' connections (src/test/hub.ts); without them, nothing connects. */
  live?: RealtimeClientFactory;
  /** This tab's id (X-Client). */
  clientId?: string;
}

export function renderApp(path = '/', { user = ANNA, server = createTestServer(), live, clientId }: Options = {}) {
  const auth = createTestAuth(user);
  const router = createMemoryRouter(routes, { initialEntries: [path] });
  // No second tries: a failure shows at once.
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const fetch: typeof window.fetch = (input, init) => server.fetch(input, init);
  render(<App services={{ auth, fetch, live, clientId }} router={router} queryClient={queryClient} />);
  return { auth, router, server, queryClient };
}

/** The page once the account is open: the sidebar's sections are there. */
export async function opened() {
  return screen.findByRole('navigation', { name: 'Sections' });
}
