// Mock mode (npm run dev:mock): the test data instead of the server and a pretend sign-in instead of Firebase.
// Switches in the address of the first page:
//   ?mockUser=none        start signed out (the sign-in form)
//   ?mockUser=stranger    start signed in as a non-admin ("Нет доступа")
//   ?mockOverview=calm    the overview with nothing wrong
//   ?mockLatency=0        answer at once (default: 250 ms)
// On the sign-in form any e-mail and password work; the password "wrong" fails, an e-mail with "stranger" isn't an admin.
import type { AuthService, SignedInUser } from '../auth/auth';
import type { Services } from '../services';
import { createMockBackend, mockToken, OWNER_EMAIL } from './backend';

export function createMockAuth(initial: string | null, latencyMs = 250): AuthService {
  let user: SignedInUser | null = initial ? { uid: initial, email: initial } : null;
  const listeners = new Set<(user: SignedInUser | null) => void>();
  const tell = () => listeners.forEach((listener) => listener(user));

  return {
    subscribe(listener) {
      listeners.add(listener);
      // Like Firebase: the first answer comes a moment later, not during the call.
      const timer = setTimeout(() => listener(user), 0);
      return () => {
        clearTimeout(timer);
        listeners.delete(listener);
      };
    },
    async signIn(email, password) {
      await new Promise((resolve) => setTimeout(resolve, latencyMs));
      const address = email.trim().toLowerCase();
      if (!address.includes('@')) throw Object.assign(new Error('Not an e-mail'), { code: 'auth/invalid-email' });
      if (password === 'wrong') throw Object.assign(new Error('Wrong password'), { code: 'auth/invalid-credential' });
      user = { uid: address, email: address };
      tell();
    },
    async signOut() {
      user = null;
      tell();
    },
    async idToken() {
      return user?.email ? mockToken(user.email) : null;
    },
  };
}

export function createMockServices({ search }: { search: string }): Services {
  const params = new URLSearchParams(search);
  const who = params.get('mockUser');
  const latencyMs = Number(params.get('mockLatency') ?? 250);
  const backend = createMockBackend({ latencyMs, calm: params.get('mockOverview') === 'calm' });
  const initial = who === 'none' ? null : who === 'stranger' ? 'stranger@example.com' : OWNER_EMAIL;
  return { auth: createMockAuth(initial, latencyMs), fetch: backend.fetch, mock: true };
}
