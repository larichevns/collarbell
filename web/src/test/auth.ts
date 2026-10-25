// A pretend Firebase for the tests: any e-mail signs in, the password "wrong" doesn't; the ID token names the person.
// It remembers the reset letters it was asked to send, and can be told to fail renewing the token. The password typed
// again (reauthenticate) makes the tokens of the next five minutes say so (";recent"), as a real token's auth_time
// tells the server that the password was typed a moment ago.
import { TokenError, type AuthService, type SignedInUser } from '../auth/auth';

export interface TestAuth extends AuthService {
  /** The letters "Forgot password?" asked for. */
  resets: { email: string; lang: string }[];
  /** The passwords typed again, in order. */
  reauthentications: string[];
  /** From now on the token can't be had, for this reason. */
  failToken(reason: TokenError['reason']): void;
}

/** How long a password typed again counts as recent (the server's AccountDeletion.RecentSignIn). */
const RECENT_MS = 5 * 60_000;

export function createTestAuth(email: string | null): TestAuth {
  let user: SignedInUser | null = email ? { uid: `uid-${email}`, email } : null;
  let tokenFailure: TokenError['reason'] | null = null;
  let passwordTypedAt: number | null = null;
  const listeners = new Set<(user: SignedInUser | null) => void>();
  const tell = () => listeners.forEach((listener) => listener(user));
  const resets: TestAuth['resets'] = [];
  const reauthentications: string[] = [];

  return {
    resets,
    reauthentications,
    failToken(reason) {
      tokenFailure = reason;
    },
    subscribe(listener) {
      listeners.add(listener);
      // Like Firebase: the first answer comes a moment later, not during the call.
      const timer = setTimeout(() => listener(user), 0);
      return () => {
        clearTimeout(timer);
        listeners.delete(listener);
      };
    },
    async signIn(address, password) {
      if (password === 'wrong') throw Object.assign(new Error('Wrong password'), { code: 'auth/invalid-credential' });
      user = { uid: `uid-${address.trim()}`, email: address.trim() };
      // Only the password typed again counts as recent here, so the tokens of an ordinary sign-in stay as they were.
      passwordTypedAt = null;
      tell();
    },
    async signOut() {
      user = null;
      passwordTypedAt = null;
      tell();
    },
    async reauthenticate(password) {
      reauthentications.push(password);
      if (!user) throw Object.assign(new Error('Nobody signed in'), { code: 'auth/no-current-user' });
      if (password === 'wrong') throw Object.assign(new Error('Wrong password'), { code: 'auth/invalid-credential' });
      passwordTypedAt = Date.now();
    },
    async sendPasswordReset(address, lang) {
      resets.push({ email: address, lang });
    },
    async idToken() {
      if (tokenFailure) throw new TokenError(tokenFailure);
      if (!user) return null;
      const recent = passwordTypedAt !== null && Date.now() - passwordTypedAt < RECENT_MS;
      return `token:${user.email}${recent ? ';recent' : ''}`;
    },
  };
}
