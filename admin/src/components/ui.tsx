// The admin's building blocks: icons, badges, cards, number tiles, notices, filters. Styles: src/styles/app.css.
// Colours follow Collarbell's rules: green for "fine", yellow for "have a look" (as a fill under dark text, never as
// the colour of text), red only for real trouble, and a colour never speaks alone: always with an icon and a word.
import type { ReactNode } from 'react';
import { Link } from 'react-router';
import { errorText } from '../api/client';
import { formatFull, formatNumber, formatRelative } from '../lib/format';
import type { Tone } from '../lib/labels';
import { ICONS, type IconName } from './icons';

export function Icon({ name, size = 20, className }: { name: IconName; size?: number; className?: string }) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 -960 960 960"
      fill="currentColor"
      aria-hidden="true"
      focusable="false"
    >
      <path d={ICONS[name]} />
    </svg>
  );
}

export function Badge({
  tone = 'neutral',
  icon,
  title,
  children,
}: {
  tone?: Tone;
  icon?: IconName;
  title?: string;
  children: ReactNode;
}) {
  return (
    <span className={`badge badge--${tone}`} title={title}>
      {icon && <Icon name={icon} size={14} />}
      {children}
    </span>
  );
}

export function Spinner() {
  return <span className="spinner" aria-hidden="true" />;
}

export function Loading({ text = 'Загрузка…' }: { text?: string }) {
  return (
    <div className="loading" role="status">
      <Spinner />
      {text}
    </div>
  );
}

export function Notice({
  tone = 'neutral',
  icon,
  children,
}: {
  tone?: Tone;
  icon?: IconName;
  children: ReactNode;
}) {
  const shown = icon ?? (tone === 'danger' ? 'error' : tone === 'warning' ? 'warning' : tone === 'ok' ? 'check_circle' : 'schedule');
  return (
    <div className={`notice notice--${tone}`} role={tone === 'danger' ? 'alert' : undefined}>
      <Icon name={shown} />
      <div className="notice-body">{children}</div>
    </div>
  );
}

/** A failed request, in words, with "Повторить". */
export function ErrorNotice({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  return (
    <Notice tone="danger">
      <p>{errorText(error)}</p>
      {onRetry && (
        <button type="button" className="button button--secondary" onClick={onRetry}>
          Повторить
        </button>
      )}
    </Notice>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="empty">{children}</p>;
}

/** «5 мин назад», with the exact moment on hover. */
export function RelativeTime({ value, now }: { value: string; now: Date }) {
  return (
    <time dateTime={value} title={formatFull(value)}>
      {formatRelative(value, now)}
    </time>
  );
}

export function Card({
  title,
  icon,
  actions,
  className,
  children,
}: {
  title?: ReactNode;
  icon?: IconName;
  actions?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  return (
    <section className={`card${className ? ` ${className}` : ''}`}>
      {(title || actions) && (
        <header className="card-head">
          {icon && <Icon name={icon} className="card-icon" />}
          {title && <h2 className="card-title">{title}</h2>}
          {actions && <div className="card-actions">{actions}</div>}
        </header>
      )}
      {children}
    </section>
  );
}

/** A heading for a group of tiles on the overview. */
export function Section({ title, icon, note, children }: { title: string; icon: IconName; note?: string; children: ReactNode }) {
  return (
    <section className="section">
      <h2 className="section-title">
        <Icon name={icon} />
        {title}
        {note && <span className="section-note">{note}</span>}
      </h2>
      {children}
    </section>
  );
}

export interface StatProps {
  label: string;
  value: ReactNode;
  /** A short line under the value: context, or for a problem what is wrong (the word next to the colour). */
  hint?: ReactNode;
  tone?: 'warning' | 'danger';
  /** The tile is a link: where to look closer. */
  to?: string;
  /** The exact value on hover, when the tile shows it rounded. */
  title?: string;
  children?: ReactNode;
}

/** A number tile: label, value, a line of context; yellow or red with an icon when something is wrong. */
export function Stat({ label, value, hint, tone, to, title, children }: StatProps) {
  const body = (
    <>
      <span className="stat-label">{label}</span>
      <span className="stat-value" title={title}>
        {value}
      </span>
      {children}
      {hint && (
        <span className="stat-hint">
          {tone && <Icon name={tone === 'danger' ? 'error' : 'warning'} size={16} />}
          <span>{hint}</span>
        </span>
      )}
    </>
  );
  const className = `stat${tone ? ` stat--${tone}` : ''}`;
  return to ? (
    <Link to={to} className={`${className} stat--link`}>
      {body}
    </Link>
  ) : (
    <div className={className}>{body}</div>
  );
}

/** A filled share, e.g. the used disk. The track is a lighter step of the fill's colour. */
export function Meter({ value, tone = 'ok', label }: { value: number; tone?: 'ok' | 'warning' | 'danger'; label: string }) {
  const percent = Math.round(Math.max(0, Math.min(1, value)) * 100);
  return (
    <span
      className={`meter meter--${tone}`}
      role="meter"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={percent}
    >
      <span className="meter-fill" style={{ width: `${percent}%` }} />
    </span>
  );
}

/** Rows with a thin bar each, one colour: shares of one whole (app versions). The numbers stay in words too. */
export function BarList({ rows, caption }: { rows: { key: string; label: ReactNode; value: number }[]; caption: string }) {
  const max = Math.max(1, ...rows.map((row) => row.value));
  return (
    <table className="bars">
      <caption className="visually-hidden">{caption}</caption>
      <tbody>
        {rows.map((row) => (
          <tr key={row.key}>
            <th scope="row">{row.label}</th>
            <td className="bars-track">
              <span className="bars-bar" style={{ width: `${(row.value / max) * 100}%` }} />
            </td>
            <td className="num">{formatNumber(row.value)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

/** A filter you turn on and off (the визор's kinds). */
export function Chip({
  pressed,
  onClick,
  count,
  children,
}: {
  pressed: boolean;
  onClick: () => void;
  count?: number;
  children: ReactNode;
}) {
  return (
    <button type="button" className="chip" aria-pressed={pressed} onClick={onClick}>
      {pressed && <Icon name="check" size={16} />}
      {children}
      {count !== undefined && <span className="chip-count">{formatNumber(count)}</span>}
    </button>
  );
}

/** One choice of a few (the period, the kind of problem). */
export function Segmented<T extends string | number>({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: T;
  options: readonly { value: T; label: string; count?: number }[];
  onChange: (value: T) => void;
}) {
  return (
    <div className="segmented" role="radiogroup" aria-label={label}>
      {options.map((option) => (
        <button
          key={String(option.value)}
          type="button"
          role="radio"
          aria-checked={option.value === value}
          className="segmented-option"
          onClick={() => onChange(option.value)}
        >
          {option.label}
          {option.count !== undefined && <span className="chip-count">{formatNumber(option.count)}</span>}
        </button>
      ))}
    </div>
  );
}

/** The title of a page, with a way back and buttons on the right. */
export function PageHead({
  title,
  back,
  meta,
  children,
}: {
  title: ReactNode;
  back?: { to: string; label: string };
  meta?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <div className="page-head">
      {back && (
        <Link to={back.to} className="back-link">
          <Icon name="arrow_back" size={18} />
          {back.label}
        </Link>
      )}
      <div className="page-head-row">
        <h1 className="page-title">{title}</h1>
        {children && <div className="page-actions">{children}</div>}
      </div>
      {meta && <div className="page-meta">{meta}</div>}
    </div>
  );
}
