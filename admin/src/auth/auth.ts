// Signing in, as the rest of the admin sees it. Two implementations: Firebase (auth/firebase.ts, the real one) and a
// pretend one with test data (mock/services.ts, for npm run dev:mock and the tests).

export interface SignedInUser {
  /** Firebase's id of the person; tells "the same person again" from "someone else". */
  uid: string;
  email: string | null;
}

export interface AuthService {
  /** Calls back with who is signed in (null: nobody) once known, and after every change. Returns "stop". */
  subscribe(listener: (user: SignedInUser | null) => void): () => void;
  /** Rejects with Firebase's error (its code says why; signInErrorText turns it into words). */
  signIn(email: string, password: string): Promise<void>;
  signOut(): Promise<void>;
  /** The ID token for the API, renewed by Firebase when it's about to expire; null when nobody is signed in. */
  idToken(): Promise<string | null>;
}

/** Why signing in failed, for the sign-in form. */
export function signInErrorText(error: unknown): string {
  const code = error && typeof error === 'object' && 'code' in error ? String(error.code) : '';
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/invalid-login-credentials':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return 'Неверный e-mail или пароль.';
    case 'auth/invalid-email':
      return 'Это не похоже на e-mail.';
    case 'auth/missing-password':
      return 'Введите пароль.';
    case 'auth/user-disabled':
      return 'Этот аккаунт отключён.';
    case 'auth/too-many-requests':
      return 'Слишком много попыток. Подождите несколько минут и попробуйте снова.';
    case 'auth/network-request-failed':
      return 'Нет связи. Проверьте интернет и попробуйте снова.';
    case 'auth/operation-not-allowed':
      return 'Вход по e-mail и паролю выключен в настройках Firebase.';
    default:
      return code ? `Не удалось войти (${code}).` : 'Не удалось войти. Попробуйте ещё раз.';
  }
}
