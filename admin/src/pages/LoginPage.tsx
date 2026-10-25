// "Вход": e-mail and password of a Collarbell account (Firebase). Who may go further is decided by the server.
import { useState, type FormEvent } from 'react';
import { signInErrorText, type AuthService } from '../auth/auth';
import { Icon, Notice, Spinner } from '../components/ui';
import { AuthFrame } from './GatePages';

export function LoginPage({ auth, notice, mock }: { auth: AuthService; notice: string | null; mock: boolean }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await auth.signIn(email, password);
      // Signed in: the session takes over from here (the form disappears).
    } catch (failure) {
      setError(signInErrorText(failure));
      setBusy(false);
    }
  }

  return (
    <AuthFrame>
      <form className="auth-form" onSubmit={submit}>
        <h1 className="auth-title">Вход</h1>
        <p className="muted">Админка Collarbell — только для владельца сервиса.</p>
        {notice && <Notice tone="warning">{notice}</Notice>}
        <label className="field">
          <span className="field-label">E-mail</span>
          <input
            className="input"
            type="email"
            name="email"
            autoComplete="username"
            required
            autoFocus
            value={email}
            onChange={(event) => setEmail(event.target.value)}
          />
        </label>
        <label className="field">
          <span className="field-label">Пароль</span>
          <input
            className="input"
            type="password"
            name="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
        </label>
        {error && (
          <p className="form-error" role="alert">
            <Icon name="error" size={18} />
            {error}
          </p>
        )}
        <button type="submit" className="button button--primary button--wide" disabled={busy}>
          {busy && <Spinner />}
          {busy ? 'Входим…' : 'Войти'}
        </button>
        {mock && (
          <p className="auth-hint">
            Тестовые данные: подойдут любой e-mail и пароль. Пароль «wrong» — ошибка входа, e-mail со словом «stranger» —
            аккаунт не админ.
          </p>
        )}
      </form>
    </AuthFrame>
  );
}
