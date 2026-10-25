// What the admin talks to: the sign-in and the network. Real ones normally; with npm run dev:mock (Vite's mode
// "mock") a pretend sign-in and test data instead (src/mock/), so the screens work without the server or Firebase.
// In a normal build the mock branch is dropped: its code isn't even in dist/.
import { createFirebaseAuth } from './auth/firebase';
import type { AuthService } from './auth/auth';

export interface Services {
  auth: AuthService;
  fetch: typeof fetch;
  /** Test data: the header says so, and the sign-in form explains the pretend accounts. */
  mock: boolean;
}

export async function createServices(): Promise<Services> {
  if (import.meta.env.MODE === 'mock') {
    const { createMockServices } = await import('./mock/services');
    return createMockServices({ search: window.location.search });
  }
  return { auth: createFirebaseAuth(), fetch: (input, init) => window.fetch(input, init), mock: false };
}
