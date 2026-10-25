// The app's building blocks: notices, loading and empty states, page and section heads, badges, status tags. Styles:
// src/styles/app.css. Colours follow Collarbell's rules: green for "done" and the chosen thing, a yellow tag for
// "soon", red only for real trouble, and a colour never speaks alone: always with an icon and a word.
import { useEffect, useId, type ReactNode } from 'react';
import { Link } from 'react-router';
import { ApiError } from '../api/client';
import { errorMessage, isNotFound } from '../api/errors';
import { useI18n } from '../i18n/i18n';
import { Icon } from './Icon';
import type { IconName } from './icons';

type Tone = 'neutral' | 'ok' | 'warning' | 'danger';

export function Spinner() {
  return <span className="spinner" aria-hidden="true" />;
}

export function Loading() {
  const { t } = useI18n();
  return (
    <div className="loading" role="status">
      <Spinner />
      {t.commonLoading}
    </div>
  );
}

const NOTICE_ICONS: Record<Tone, IconName> = { neutral: 'info', ok: 'check_circle', warning: 'warning', danger: 'error' };

export function Notice({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  const icon = NOTICE_ICONS[tone];
  return (
    <div className={`notice notice--${tone}`} role={tone === 'danger' ? 'alert' : undefined}>
      <Icon name={icon} />
      <div className="notice-body">{children}</div>
    </div>
  );
}

/** A failed request in words, with the server's error id for support and "Try again". */
export function ErrorNotice({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  const { t } = useI18n();
  const traceId = error instanceof ApiError ? error.traceId : null;
  return (
    <Notice tone="danger">
      <p>{errorMessage(t, error)}</p>
      {traceId && <p className="small muted">{t.errorReference(traceId)}</p>}
      {onRetry && (
        <button type="button" className="button button--secondary" onClick={onRetry}>
          <Icon name="refresh" size={18} />
          {t.commonTryAgain}
        </button>
      )}
    </Notice>
  );
}

/** Nothing here yet: what will show, and the first step. */
export function EmptyState({
  icon,
  title,
  children,
  actions,
}: {
  icon: IconName;
  title: string;
  children?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div className="empty">
      <span className="empty-icon">
        <Icon name={icon} size={28} />
      </span>
      <h2 className="empty-title">{title}</h2>
      {children && <p className="muted">{children}</p>}
      {actions && <div className="empty-actions">{actions}</div>}
    </div>
  );
}

/** A quiet word next to a name: "Archived". */
export function Badge({ children }: { children: ReactNode }) {
  return <span className="badge">{children}</span>;
}

/**
 * A status that asks for action, as a pill with an icon: "soon", "time to buy", "check this" on the yellow accent
 * (yellow text on white can't be read, so the words sit on the yellow), overdue and ran out on the red. Calm states
 * are plain muted text, not a tag.
 */
export function StatusTag({
  tone,
  icon,
  children,
}: {
  tone: 'warning' | 'danger';
  icon: IconName;
  children: ReactNode;
}) {
  return (
    <span className={`tag tag--${tone}`}>
      <Icon name={icon} size={16} />
      <span>{children}</span>
    </span>
  );
}

/** The title of a page, a line above it (a date, a way back) and buttons on the right. */
export function PageHead({
  title,
  back,
  caption,
  actions,
}: {
  title: ReactNode;
  back?: { to: string; label: string };
  caption?: ReactNode;
  actions?: ReactNode;
}) {
  useDocumentTitle(typeof title === 'string' ? title : null);
  return (
    <div className="page-head">
      {back && (
        <Link to={back.to} className="back-link">
          <Icon name="arrow_back" size={18} />
          {back.label}
        </Link>
      )}
      {caption && <p className="page-caption">{caption}</p>}
      <div className="page-head-row">
        <h1 className="page-title">{title}</h1>
        {actions && <div className="page-actions">{actions}</div>}
      </div>
    </div>
  );
}

/** A titled part of a page: "Feeding", "Visits", "Details"; a region named by its title. */
export function Section({
  title,
  action,
  className,
  children,
}: {
  title: string;
  action?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  const id = useId();
  return (
    <section className={`section${className ? ` ${className}` : ''}`} aria-labelledby={id}>
      <div className="section-head">
        <h2 className="section-title" id={id}>
          {title}
        </h2>
        {action && <div className="section-action">{action}</div>}
      </div>
      {children}
    </section>
  );
}

/**
 * What a part of a page shows of a query: its data, the reason it can't (with "Try again"), or that it is loading.
 * Something gone (404) is said instead of an old copy. Another failed reload keeps the data on screen under the
 * reason, so what is open (a dialog) stays; a reload that got no answer keeps it silently (the offline strip says why).
 */
export function Loaded<T>({
  query,
  children,
}: {
  query: { data: T | undefined; error: unknown; refetch: () => unknown };
  children: (data: T) => ReactNode;
}) {
  const { data, error } = query;
  const retry = () => void query.refetch();
  if (error && (data === undefined || isNotFound(error))) return <ErrorNotice error={error} onRetry={retry} />;
  if (data === undefined) return <Loading />;
  const offline = error instanceof ApiError && error.status === 0;
  return (
    <>
      {error && !offline ? <ErrorNotice error={error} onRetry={retry} /> : null}
      {children(data)}
    </>
  );
}

/** The browser tab's title: the page's, then the app's name. */
export function useDocumentTitle(title: string | null | undefined) {
  const { t } = useI18n();
  useEffect(() => {
    if (title) document.title = `${title} · ${t.appName}`;
  }, [title, t.appName]);
}
