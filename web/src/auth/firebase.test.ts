// Renewing the ID token (review of part 1, P12): only the errors that mean the sign-in is gone sign the person out
// (a 401 to the app); a passing hiccup of Firebase fails that one request, as the phone app's authHeaders() does.
import { describe, expect, it, vi } from 'vitest';

const getIdToken = vi.fn();

vi.mock('firebase/app', () => ({ initializeApp: () => ({}) }));
const reauthenticateWithCredential = vi.fn();

vi.mock('firebase/auth', () => ({
  browserLocalPersistence: {},
  EmailAuthProvider: { credential: (email: string, password: string) => ({ email, password }) },
  indexedDBLocalPersistence: {},
  initializeAuth: () => ({ currentUser: { uid: 'u1', email: 'a@example.com', getIdToken } }),
  onAuthStateChanged: () => () => {},
  reauthenticateWithCredential,
  sendPasswordResetEmail: async () => {},
  signInWithEmailAndPassword: async () => {},
  signOut: async () => {},
}));

const { createFirebaseAuth } = await import('./firebase');
const { reauthErrorKey } = await import('./auth');
const { createApi, ApiError, NOT_SENT } = await import('../api/client');

/** What the app hears of a request whose token renewal fails with `code`. */
async function statusesFor(code: string) {
  getIdToken.mockRejectedValueOnce(Object.assign(new Error(code), { code }));
  const auth = createFirebaseAuth();
  const api = createApi({ fetch: vi.fn(), token: () => auth.idToken(), baseUrl: 'http://localhost' });
  const statuses: number[] = [];
  api.listen((event) => {
    if (event.kind === 'failure') statuses.push(event.error.status);
  });
  const error = await api
    .forHousehold('h1')
    .GET('/api/v1/pets')
    .catch((caught: unknown) => caught);
  expect(error).toBeInstanceOf(ApiError);
  return statuses;
}

describe('token renewal errors', () => {
  it.each(['auth/internal-error', 'auth/too-many-requests', 'auth/quota-exceeded', 'auth/invalid-user-token'])(
    '%s fails the request, not the sign-in',
    async (code) => {
      // Not a 401 (which signs out), and not "no answer" (which says the server is down): not sent.
      expect(await statusesFor(code)).toEqual([NOT_SENT]);
    },
  );

  it.each(['auth/user-token-expired', 'auth/user-disabled', 'auth/user-not-found'])(
    '%s means the sign-in is gone',
    async (code) => {
      expect(await statusesFor(code)).toEqual([401]);
    },
  );

  it('no internet to renew it is no answer', async () => {
    expect(await statusesFor('auth/network-request-failed')).toEqual([0]);
  });
});

describe('the password again, before deleting the account', () => {
  it("checks it with the person's e-mail (Firebase renews the tokens with the answer)", async () => {
    reauthenticateWithCredential.mockResolvedValueOnce({});
    await createFirebaseAuth().reauthenticate('secret');
    expect(reauthenticateWithCredential).toHaveBeenCalledWith(expect.objectContaining({ uid: 'u1' }), {
      email: 'a@example.com',
      password: 'secret',
    });
  });

  it.each([
    ['auth/invalid-credential', 'deleteAccountWrongPassword'],
    ['auth/wrong-password', 'deleteAccountWrongPassword'],
    ['auth/too-many-requests', 'authErrorTooManyRequests'],
    ['auth/network-request-failed', 'authErrorNetwork'],
    ['auth/user-disabled', 'authErrorUserDisabled'],
    ['auth/internal-error', 'deleteAccountPasswordCheckFailed'],
  ])('%s is said as %s', async (code, key) => {
    reauthenticateWithCredential.mockRejectedValueOnce(Object.assign(new Error(code), { code }));
    const error = await createFirebaseAuth()
      .reauthenticate('secret')
      .catch((caught: unknown) => caught);
    expect(reauthErrorKey(error)).toBe(key);
  });
});
