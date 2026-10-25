// Signing in, as the rest of the app sees it. The real implementation is Firebase (auth/firebase.ts); the tests use a
// pretend one (src/test/auth.ts).

export interface SignedInUser {
  /** Firebase's id of the person: tells "the same person again" from "someone else". */
  uid: string;
  email: string | null;
}

export interface AuthService {
  /** Calls back with who is signed in (null: nobody) once known, and after every change. Returns "stop". */
  subscribe(listener: (user: SignedInUser | null) => void): () => void;
  /** Rejects with Firebase's error: its code says why (signInErrorKey). */
  signIn(email: string, password: string): Promise<void>;
  signOut(): Promise<void>;
  /**
   * Firebase sends a letter with a link to set a new password, in `lang`. An address without an account gets the
   * same answer as one with an account: whether someone has an account is nobody's business.
   */
  sendPasswordReset(email: string, lang: string): Promise<void>;
  /**
   * The ID token for the API, renewed by Firebase when it is about to expire; null when nobody is signed in. Rejects
   * with TokenError when it can't be had.
   */
  idToken(): Promise<string | null>;
  /**
   * The signed-in person's password again (Firebase's reauthenticateWithCredential with their e-mail): the ID tokens
   * from now on carry a fresh sign-in time, which the server wants before it deletes the account. Rejects with
   * Firebase's error: its code says why (reauthErrorKey).
   */
  reauthenticate(password: string): Promise<void>;
}

/**
 * Why there is no ID token: no internet to renew it ("offline"), Firebase no longer knows the account, which was
 * deleted ("gone"), the sign-in is no longer valid otherwise ("expired"), or Firebase failed for a moment ("failed":
 * an internal error, too many requests, a quota) while the sign-in itself still holds.
 */
export type TokenFailure = 'offline' | 'gone' | 'expired' | 'failed';

export class TokenError extends Error {
  readonly reason: TokenFailure;

  constructor(reason: TokenFailure, cause?: unknown) {
    super(`No ID token: ${reason}`, { cause });
    this.name = 'TokenError';
    this.reason = reason;
  }
}

/** The text of a failed sign-in (a key of the messages), by Firebase's error code. */
export function signInErrorKey(
  error: unknown,
):
  | 'authErrorInvalidCredentials'
  | 'authErrorInvalidEmail'
  | 'authErrorUserDisabled'
  | 'authErrorTooManyRequests'
  | 'authErrorNetwork'
  | 'authErrorNotAllowed'
  | 'authErrorUnknown' {
  const code = error && typeof error === 'object' && 'code' in error ? String(error.code) : '';
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/invalid-login-credentials':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return 'authErrorInvalidCredentials';
    case 'auth/invalid-email':
      return 'authErrorInvalidEmail';
    case 'auth/user-disabled':
      return 'authErrorUserDisabled';
    case 'auth/too-many-requests':
      return 'authErrorTooManyRequests';
    case 'auth/network-request-failed':
      return 'authErrorNetwork';
    case 'auth/operation-not-allowed':
      return 'authErrorNotAllowed';
    default:
      return 'authErrorUnknown';
  }
}

/** Why the password typed again before deleting the account wasn't taken (a key of the messages). */
export function reauthErrorKey(
  error: unknown,
):
  | 'deleteAccountWrongPassword'
  | 'authErrorTooManyRequests'
  | 'authErrorNetwork'
  | 'authErrorUserDisabled'
  | 'deleteAccountPasswordCheckFailed' {
  const code = error && typeof error === 'object' && 'code' in error ? String(error.code) : '';
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/invalid-login-credentials':
    case 'auth/wrong-password':
    case 'auth/missing-password':
      return 'deleteAccountWrongPassword';
    case 'auth/too-many-requests':
      return 'authErrorTooManyRequests';
    case 'auth/network-request-failed':
      return 'authErrorNetwork';
    case 'auth/user-disabled':
      return 'authErrorUserDisabled';
    default:
      return 'deleteAccountPasswordCheckFailed';
  }
}

/** Whether `text` looks like an e-mail address, before Firebase is asked. */
export function looksLikeEmail(text: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(text.trim());
}
