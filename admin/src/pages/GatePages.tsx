// The screens before the admin itself: loading, "no access", "couldn't check access". The sign-in form: LoginPage.
import type { ReactNode } from 'react';
import { Icon, Spinner } from '../components/ui';

/** A centred card with the logo, for everything before the admin. */
export function AuthFrame({ children }: { children: ReactNode }) {
  return (
    <main className="auth">
      <div className="auth-card card">
        <div className="auth-brand">
          <img src={`${import.meta.env.BASE_URL}favicon.svg`} alt="" width={40} height={40} />
          <span className="brand-name">Collarbell</span>
          <span className="brand-tag">админка</span>
        </div>
        {children}
      </div>
    </main>
  );
}

export function SplashPage({ text }: { text: string }) {
  return (
    <main className="splash" role="status">
      <Spinner />
      {text}
    </main>
  );
}

export function NoAccessPage({ email, onSignOut }: { email: string | null; onSignOut: () => void }) {
  return (
    <AuthFrame>
      <div className="auth-message">
        <span className="auth-icon auth-icon--danger">
          <Icon name="lock" size={28} />
        </span>
        <h1 className="auth-title">Нет доступа: этот аккаунт не админ</h1>
        {email && (
          <p className="muted">
            Вы вошли как <strong>{email}</strong>. Войдите аккаунтом владельца.
          </p>
        )}
        <button type="button" className="button button--primary button--wide" onClick={onSignOut}>
          <Icon name="logout" />
          Выйти
        </button>
      </div>
    </AuthFrame>
  );
}

export function GateErrorPage({ error, onRetry, onSignOut }: { error: string; onRetry: () => void; onSignOut: () => void }) {
  return (
    <AuthFrame>
      <div className="auth-message">
        <span className="auth-icon auth-icon--danger">
          <Icon name="error" size={28} />
        </span>
        <h1 className="auth-title">Не удалось проверить доступ</h1>
        <p className="muted">{error}</p>
        <div className="auth-actions">
          <button type="button" className="button button--primary" onClick={onRetry}>
            <Icon name="refresh" />
            Повторить
          </button>
          <button type="button" className="button button--secondary" onClick={onSignOut}>
            Выйти
          </button>
        </div>
      </div>
    </AuthFrame>
  );
}
