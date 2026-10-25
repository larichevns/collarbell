// The screens before the app itself: loading, and "Couldn't open your account". The sign-in page: LoginPage.
import type { ReactNode } from 'react';
import { ErrorNotice, Spinner, useDocumentTitle } from '../components/ui';
import { useI18n } from '../i18n/i18n';
import { LANGS } from '../i18n/lang';
import { Icon } from '../components/Icon';

/** A centred card with the logo and the language, for everything before the app. */
export function AuthFrame({ children }: { children: ReactNode }) {
  const { t, lang, choose } = useI18n();
  return (
    <main className="auth">
      <div className="auth-card">
        <div className="auth-top">
          <div className="auth-brand">
            <img src={`${import.meta.env.BASE_URL}favicon.svg`} alt="" width={40} height={40} />
            <span className="brand-name">{t.appName}</span>
          </div>
          <div className="segmented segmented--compact" role="group" aria-label={t.languageLabel}>
            {LANGS.map((option) => (
              <button
                key={option}
                type="button"
                className="segmented-option"
                lang={option}
                aria-pressed={lang === option}
                onClick={() => choose(option)}
              >
                {t.languageNames[option]}
              </button>
            ))}
          </div>
        </div>
        {children}
      </div>
    </main>
  );
}

export function SplashPage() {
  const { t } = useI18n();
  return (
    <main className="splash" role="status">
      <Spinner />
      {t.commonLoading}
    </main>
  );
}

export function GateErrorPage({
  error,
  onRetry,
  onSignOut,
}: {
  error: unknown;
  onRetry: () => void;
  onSignOut: () => void;
}) {
  const { t } = useI18n();
  useDocumentTitle(t.gateErrorTitle);
  return (
    <AuthFrame>
      <div className="auth-message">
        <h1 className="auth-title">{t.gateErrorTitle}</h1>
        <ErrorNotice error={error} />
        <div className="auth-actions">
          <button type="button" className="button button--primary" onClick={onRetry}>
            <Icon name="refresh" />
            {t.commonTryAgain}
          </button>
          <button type="button" className="button button--secondary" onClick={onSignOut}>
            {t.signOut}
          </button>
        </div>
      </div>
    </AuthFrame>
  );
}
