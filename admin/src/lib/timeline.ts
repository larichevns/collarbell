// The визор's logic, apart from how it looks: which filter shows which kind, adding the next page, and grouping the
// lines by day and by session (one session = one launch of the app). Lines come newest first and stay so.
import type { TimelineEvent } from '../api/types';
import { dayKey } from './format';

export type KindFilter = 'requests' | 'screens' | 'actions' | 'errors';

export const KIND_FILTERS: readonly { id: KindFilter; label: string }[] = [
  { id: 'requests', label: 'Запросы' },
  { id: 'screens', label: 'Экраны' },
  { id: 'actions', label: 'Действия' },
  { id: 'errors', label: 'Ошибки' },
];

export const ALL_FILTERS: readonly KindFilter[] = KIND_FILTERS.map((filter) => filter.id);

/** The filter a kind belongs to; null for a kind this admin doesn't know yet (always shown). */
export function filterOf(kind: string): KindFilter | null {
  switch (kind) {
    case 'request':
      return 'requests';
    case 'screen':
      return 'screens';
    case 'action':
      return 'actions';
    case 'error':
    case 'crash':
      return 'errors';
    default:
      return null;
  }
}

export function isShown(event: TimelineEvent, shown: ReadonlySet<KindFilter>): boolean {
  const filter = filterOf(event.kind);
  return filter === null || shown.has(filter);
}

/** The filters as the address keeps them: "?show=requests,errors"; missing or empty: all. */
export function parseFilters(value: string | null): Set<KindFilter> {
  const chosen = (value ?? '').split(',').filter((id): id is KindFilter => (ALL_FILTERS as string[]).includes(id));
  return new Set(chosen.length ? chosen : ALL_FILTERS);
}

/** The opposite of parseFilters; null when everything is shown (the address stays clean). */
export function formatFilters(shown: ReadonlySet<KindFilter>): string | null {
  const chosen = ALL_FILTERS.filter((id) => shown.has(id));
  return chosen.length === ALL_FILTERS.length || chosen.length === 0 ? null : chosen.join(',');
}

export function countByFilter(events: readonly TimelineEvent[]): Record<KindFilter, number> {
  const counts: Record<KindFilter, number> = { requests: 0, screens: 0, actions: 0, errors: 0 };
  for (const event of events) {
    const filter = filterOf(event.kind);
    if (filter) counts[filter] += 1;
  }
  return counts;
}

function lineKey(event: TimelineEvent): string {
  return `${event.at}|${event.kind}|${event.text}|${event.session ?? ''}`;
}

/** The next (older) page after the loaded lines; a line that is already there isn't added twice. */
export function appendPage(loaded: readonly TimelineEvent[], page: readonly TimelineEvent[]): TimelineEvent[] {
  const seen = new Set(loaded.map(lineKey));
  return [...loaded, ...page.filter((event) => !seen.has(lineKey(event)))];
}

/** Lines in a row from one session (or, with session null, in a row without one), newest first. */
export interface SessionBlock {
  key: string;
  session: string | null;
  events: TimelineEvent[];
  /** The newest and the oldest moment of the block. */
  last: string;
  first: string;
  appVersion: string | null;
}

export interface DayBlock {
  key: string;
  /** A moment of that day, for its heading. */
  date: string;
  sessions: SessionBlock[];
}

/**
 * Groups lines (newest first) by the calendar day in the browser's time zone, then by session. A new block starts when
 * the session changes, so a session interrupted by lines of another one shows as two blocks: the order of time wins.
 */
export function groupTimeline(events: readonly TimelineEvent[]): DayBlock[] {
  const days: DayBlock[] = [];
  let day: DayBlock | undefined;
  let block: SessionBlock | undefined;
  for (const event of events) {
    const key = dayKey(event.at);
    if (!day || day.key !== key) {
      day = { key, date: event.at, sessions: [] };
      days.push(day);
      block = undefined;
    }
    if (!block || block.session !== event.session) {
      block = {
        key: `${key}|${event.session ?? 'none'}|${event.at}`,
        session: event.session,
        events: [],
        last: event.at,
        first: event.at,
        appVersion: null,
      };
      day.sessions.push(block);
    }
    block.events.push(event);
    block.first = event.at;
    block.appVersion ??= event.appVersion;
  }
  return days;
}

/** The numbers in a session's heading. */
export function sessionSummary(events: readonly TimelineEvent[]): { lines: number; problems: number } {
  let problems = 0;
  for (const event of events) {
    if (event.kind === 'error' || event.kind === 'crash' || (event.status !== null && event.status >= 500)) problems += 1;
  }
  return { lines: events.length, problems };
}

/** How far after a problem the визор starts when opened "around" it, so the moments after it show too. */
export const AROUND_MARGIN_MS = 10 * 60_000;

/** The `before` for opening the визор around a moment. */
export function beforeForAround(around: string): string {
  return new Date(Date.parse(around) + AROUND_MARGIN_MS).toISOString();
}

/** The line closest in time to a moment (the problem that was clicked); null when nothing is loaded. */
export function closestLine(events: readonly TimelineEvent[], moment: string): TimelineEvent | null {
  const target = Date.parse(moment);
  let best: TimelineEvent | null = null;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (const event of events) {
    const distance = Math.abs(Date.parse(event.at) - target);
    if (distance < bestDistance) {
      best = event;
      bestDistance = distance;
    }
  }
  return best;
}
