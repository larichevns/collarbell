// The real sign-in: Firebase Authentication of project collarbell-3e2b9 (the same accounts as the app), e-mail and
// password. Only the Auth part of the Firebase SDK is used. The person stays signed in on this browser (IndexedDB)
// until "Выйти".
import { initializeApp } from 'firebase/app';
import {
  browserLocalPersistence,
  indexedDBLocalPersistence,
  initializeAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import type { AuthService } from './auth';

/**
 * The web app of Firebase project collarbell-3e2b9 (firebase apps:sdkconfig WEB 1:237266630419:web:afd8921f6879f4815c4ce6).
 * Public identifiers, not secrets, like mobile/lib/firebase_options.dart: what an account may do is decided by the
 * server (only admins get past /api/admin).
 */
export const FIREBASE_CONFIG = {
  apiKey: 'AIzaSyCVCRKnfTqMXZE1UzV2cadkZ9RN2Xf86pA',
  authDomain: 'collarbell-3e2b9.firebaseapp.com',
  projectId: 'collarbell-3e2b9',
  appId: '1:237266630419:web:afd8921f6879f4815c4ce6',
  messagingSenderId: '237266630419',
};

export function createFirebaseAuth(): AuthService {
  const app = initializeApp(FIREBASE_CONFIG);
  // initializeAuth without the pop-up and redirect code: e-mail and password need neither.
  const auth = initializeAuth(app, { persistence: [indexedDBLocalPersistence, browserLocalPersistence] });
  auth.languageCode = 'ru';

  return {
    subscribe: (listener) =>
      onAuthStateChanged(auth, (user) => listener(user ? { uid: user.uid, email: user.email } : null)),
    signIn: async (email, password) => {
      await signInWithEmailAndPassword(auth, email.trim(), password);
    },
    signOut: () => signOut(auth),
    idToken: async () => (auth.currentUser ? auth.currentUser.getIdToken() : null),
  };
}
