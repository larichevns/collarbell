import { describe, expect, it } from 'vitest';
import type { TimelineEvent } from '../api/types';
import {
  ALL_FILTERS,
  appendPage,
  beforeForAround,
  closestLine,
  countByFilter,
  filterOf,
  formatFilters,
  groupTimeline,
  isShown,
  parseFilters,
  sessionSummary,
} from './timeline';

function line(at: string, kind: TimelineEvent['kind'], extra: Partial<TimelineEvent> = {}): TimelineEvent {
  return { at, kind, text: `${kind} at ${at}`, status: null, durationMs: null, session: 's1', householdId: null, appVersion: '1.4.0', ...extra };
}

// Newest first, as the server sends them. Moscow time (UTC+3): 5 October 18:05 … 4 October 21:50.
const EVENTS: TimelineEvent[] = [
  line('2026-10-05T15:05:00Z', 'request', { status: 500, durationMs: 1200 }),
  line('2026-10-05T15:04:00Z', 'error'),
  line('2026-10-05T15:03:00Z', 'screen'),
  line('2026-10-05T12:00:00Z', 'request', { session: null, status: 204, appVersion: null }),
  line('2026-10-05T09:10:00Z', 'action', { session: 's2', appVersion: '1.3.2' }),
  line('2026-10-05T09:00:00Z', 'screen', { session: 's2', appVersion: '1.3.2' }),
  line('2026-10-04T18:50:00Z', 'crash', { session: 's3' }),
];

describe('filters', () => {
  it('puts each kind under its filter; errors and crashes together', () => {
    expect(filterOf('request')).toBe('requests');
    expect(filterOf('screen')).toBe('screens');
    expect(filterOf('action')).toBe('actions');
    expect(filterOf('error')).toBe('errors');
    expect(filterOf('crash')).toBe('errors');
    expect(filterOf('something-new')).toBeNull();
  });

  it('reads and writes the address', () => {
    expect([...parseFilters(null)]).toEqual([...ALL_FILTERS]);
    expect([...parseFilters('errors,requests,bogus')].sort()).toEqual(['errors', 'requests']);
    expect(formatFilters(new Set(ALL_FILTERS))).toBeNull();
    expect(formatFilters(new Set(['errors', 'screens'] as const))).toBe('screens,errors');
  });

  it('always shows a kind it does not know', () => {
    const unknown = { ...line('2026-10-05T15:00:00Z', 'screen'), kind: 'push' } as unknown as TimelineEvent;
    expect(isShown(unknown, new Set(['errors']))).toBe(true);
    expect(isShown(EVENTS[2]!, new Set(['errors']))).toBe(false);
  });

  it('counts the loaded lines per filter', () => {
    expect(countByFilter(EVENTS)).toEqual({ requests: 2, screens: 2, actions: 1, errors: 2 });
  });
});

describe('groupTimeline', () => {
  it('groups by day (in Moscow) and by session, newest first', () => {
    const days = groupTimeline(EVENTS);
    expect(days).toHaveLength(2);
    const [today, yesterday] = days;
    expect(today!.sessions.map((block) => block.session)).toEqual(['s1', null, 's2']);
    expect(today!.sessions[0]!.events).toHaveLength(3);
    expect(today!.sessions[0]!.last).toBe('2026-10-05T15:05:00Z');
    expect(today!.sessions[0]!.first).toBe('2026-10-05T15:03:00Z');
    expect(today!.sessions[2]!.appVersion).toBe('1.3.2');
    expect(yesterday!.sessions.map((block) => block.session)).toEqual(['s3']);
  });

  it('starts a new block when a session comes back after another one', () => {
    const events = [line('2026-10-05T15:05:00Z', 'screen'), line('2026-10-05T15:04:00Z', 'screen', { session: 's2' }), line('2026-10-05T15:03:00Z', 'screen')];
    const [day] = groupTimeline(events);
    expect(day!.sessions.map((block) => block.session)).toEqual(['s1', 's2', 's1']);
    expect(new Set(day!.sessions.map((block) => block.key)).size).toBe(3);
  });

  it('counts a session problems: errors, crashes and 5xx answers', () => {
    expect(sessionSummary(EVENTS.slice(0, 3))).toEqual({ lines: 3, problems: 2 });
  });
});

describe('paging and the moment of a problem', () => {
  it('adds the next page without repeating a line', () => {
    const merged = appendPage(EVENTS.slice(0, 4), EVENTS.slice(3));
    expect(merged).toEqual(EVENTS);
  });

  it('opens 10 minutes after the moment', () => {
    expect(beforeForAround('2026-10-05T15:04:00Z')).toBe('2026-10-05T15:14:00.000Z');
    expect(beforeForAround('2026-10-05T15:04:00.123456+00:00')).toBe('2026-10-05T15:14:00.123Z');
  });

  it('finds the line closest to the moment', () => {
    expect(closestLine(EVENTS, '2026-10-05T15:04:00Z')).toBe(EVENTS[1]);
    expect(closestLine(EVENTS, '2026-10-05T15:04:00.000+00:00')).toBe(EVENTS[1]);
    expect(closestLine(EVENTS, '2026-10-05T11:00:00Z')).toBe(EVENTS[3]);
    expect(closestLine([], '2026-10-05T11:00:00Z')).toBeNull();
  });
});
