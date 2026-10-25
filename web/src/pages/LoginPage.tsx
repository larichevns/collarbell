// "Sign in": the e-mail and password of a Collarbell account (Firebase), the same as in the phone app. Accounts are
// made in the phone app, so the page has no sign-up: it says where to start and links to the landing. "Forgot
// password?" has Firebase send a letter with a link to set a new one, in the page's language.
import { useState, type FormEvent } from 'react';
import { looksLikeEmail, signInErrorKey, type AuthService } from '../auth/auth';
import { TextField } from '../components/fields';
import { Icon } from '../components/Icon';
import { Notice, Spinner, useDocumentTitle } from '../components/ui';
import { useI18n } from '../i18n/i18n';
import { AuthFrame } from './GatePages';

/** Why the sign-in page shows again, when it wasn't "Sign out". */
export type SignInNotice = 'session-expired' | 'account-deleted';

export function LoginPage({
  auth,
  notice,
  demo = false,
}: {
  auth: AuthService;
  notice: SignInNotice | null;
  /** The demo: any e-mail and password sign in. */
  demo?: boolean;
}) {
  const { t, lang } = useI18n();
  useDocumentTitle(t.signInTitle);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [checked, setChecked] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [reset, setReset] = useState<{ sentTo: string } | 'needs-email' | null>(null);

  const emailError = !checked ? null : !email.trim() ? t.emailRequired : !looksLikeEmail(email) ? t.emailInvalid : null;
  const passwordError = checked && !password ? t.passwordRequired : null;

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setChecked(true);
    setReset(null);
    setFailure(null);
    if (!looksLikeEmail(email) || !password) return;
    setBusy(true);
    try {
      await auth.signIn(email, password);
      // Signed in: the session takes over from here (this page goes).
    } catch (error) {
      setFailure(t[signInErrorKey(error)]);
      setBusy(false);
    }
  }

  async function sendReset() {
    if (busy) return;
    setFailure(null);
    if (!looksLikeEmail(email)) {
      setReset('needs-email');
      return;
    }
    setBusy(true);
    try {
      await auth.sendPasswordReset(email, lang);
      setReset({ sentTo: email.trim() });
    } catch (error) {
      setFailure(t[signInErrorKey(error)]);
    } finally {
      setBusy(false);
    }
  }

  return (
    <AuthFrame>
      <form className="auth-form" noValidate onSubmit={submit}>
        <div>
          <h1 className="auth-title">{t.signInTitle}</h1>
          <p className="muted">{t.signInTagline}</p>
        </div>
        {demo && <Notice>{t.demoSignInHint}</Notice>}
        {notice && (
          <Notice tone="warning">{notice === 'account-deleted' ? t.accountDeletedNotice : t.errorUnauthorized}</Notice>
        )}
        <TextField
          label={t.emailLabel}
          type="email"
          autoComplete="username"
          value={email}
          onChange={setEmail}
          error={emailError}
        />
        <TextField
          label={t.passwordLabel}
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={setPassword}
          error={passwordError}
        />
        {failure && (
          <p className="form-error" role="alert">
            <Icon name="error" size={18} />
            {failure}
          </p>
        )}
        <button type="submit" className="button button--primary button--wide" disabled={busy}>
          {busy && <Spinner />}
          {busy ? t.signingIn : t.signInButton}
        </button>
        <button type="button" className="button button--ghost button--wide" onClick={sendReset} disabled={busy}>
          {t.forgotPassword}
        </button>
        {reset === 'needs-email' && <Notice tone="warning">{t.passwordResetNeedsEmail}</Notice>}
        {reset && reset !== 'needs-email' && <Notice tone="ok">{t.passwordResetSent(reset.sentTo)}</Notice>}
        <div className="auth-hint">
          <p>{t.signInNoAccount}</p>
          <a href={lang === 'ru' ? '/ru/' : '/'}>{t.signInAboutApp}</a>
        </div>
      </form>
    </AuthFrame>
  );
}
