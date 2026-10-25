// The real sign-in: Firebase Authentication of project collarbell-3e2b9, the same accounts as the phone app, e-mail
// and password (the admin signs in the same way: admin/src/auth/firebase.ts). Only the Auth part of the Firebase SDK
// is used. The person stays signed in on this browser (IndexedDB) until "Sign out".
import { initializeApp } from 'firebase/app';
import {
  browserLocalPersistence,
  EmailAuthProvider,
  indexedDBLocalPersistence,
  initializeAuth,
  onAuthStateChanged,
  reauthenticateWithCredential,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { TokenError, type AuthService } from './auth';

/**
 * The web app of Firebase project collarbell-3e2b9, the admin's too (firebase apps:sdkconfig WEB
 * 1:237266630419:web:afd8921f6879f4815c4ce6). Public identifiers, not secrets, like mobile/lib/firebase_options.dart:
 * what an account may do is decided by the server.
 */
const FIREBASE_CONFIG = {
  apiKey: 'AIzaSyCVCRKnfTqMXZE1UzV2cadkZ9RN2Xf86pA',
  authDomain: 'collarbell-3e2b9.firebaseapp.com',
  projectId: 'collarbell-3e2b9',
  appId: '1:237266630419:web:afd8921f6879f4815c4ce6',
  messagingSenderId: '237266630419',
};

/**
 * The token errors that mean the sign-in is over (signed out elsewhere, the account switched off): the person has to
 * sign in again. Firebase signs out on these two itself. Any other error fails that request only.
 */
const SIGN_IN_GONE = ['auth/user-token-expired', 'auth/user-disabled'];

function codeOf(error: unknown): string {
  return error && typeof error === 'object' && 'code' in error ? String(error.code) : '';
}

export function createFirebaseAuth(): AuthService {
  const app = initializeApp(FIREBASE_CONFIG);
  // initializeAuth without the pop-up and redirect code: e-mail and password need neither.
  const auth = initializeAuth(app, { persistence: [indexedDBLocalPersistence, browserLocalPersistence] });

  return {
    subscribe: (listener) =>
      onAuthStateChanged(auth, (user) => listener(user ? { uid: user.uid, email: user.email } : null)),
    signIn: async (email, password) => {
      await signInWithEmailAndPassword(auth, email.trim(), password);
    },
    signOut: () => signOut(auth),
    sendPasswordReset: async (email, lang) => {
      auth.languageCode = lang;
      try {
        await sendPasswordResetEmail(auth, email.trim());
      } catch (error) {
        // Projects without e-mail enumeration protection still say this; the person hears the same either way.
        if (codeOf(error) !== 'auth/user-not-found') throw error;
      }
    },
    reauthenticate: async (password) => {
      const user = auth.currentUser;
      // Nobody signed in, or an account without an e-mail: there is no password to check.
      if (!user?.email) throw Object.assign(new Error('No e-mail sign-in.'), { code: 'auth/no-current-user' });
      // The user's tokens are renewed with the answer: the next ID token has this moment as its auth_time.
      await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, password));
    },
    idToken: async () => {
      const user = auth.currentUser;
      if (!user) return null;
      try {
        // Cached by the SDK and renewed shortly before it expires.
        return await user.getIdToken();
      } catch (error) {
        const code = codeOf(error);
        if (code === 'auth/network-request-failed') throw new TokenError('offline', error);
        // Firebase doesn't know the account any more: it was deleted, an hour or more ago.
        if (code === 'auth/user-not-found') throw new TokenError('gone', error);
        // The sign-in itself is over: signed out elsewhere, the account switched off.
        if (SIGN_IN_GONE.includes(code)) throw new TokenError('expired', error);
        // A passing hiccup (an internal error, too many requests, a quota): this request fails, the sign-in stays.
        throw new TokenError('failed', error);
      }
    },
  };
}
