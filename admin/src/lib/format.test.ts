import { describe, expect, it } from 'vitest';
import {
  dateInputValue,
  dayKey,
  daysUntil,
  endOfDayIso,
  formatAge,
  formatBytes,
  formatCompact,
  formatCount,
  formatDate,
  formatDateNumeric,
  formatDateTime,
  formatDayHeading,
  formatDurationMs,
  formatMinutes,
  formatNumber,
  formatPercent,
  formatRelative,
  formatTime,
  formatTimeWithSeconds,
  plural,
  shortenIds,
} from './format';

// The tests run in Europe/Moscow (UTC+3 all year, vite.config.ts). No-break spaces are compared as plain ones on both
// sides: the code joins a number and its word with one, tools/typograph.py puts them after short words in this file
// too (not always in the same places), and a newer ICU may pick another space.
const plain = (text: string) => text.replace(/[  ]/g, ' ');
const expectText = (actual: string) => ({ toBe: (expected: string) => expect(plain(actual)).toBe(plain(expected)) });
const NOW = new Date('2026-10-05T15:00:00Z'); // Monday, 18:00 in Moscow
const ago = (ms: number) => new Date(NOW.getTime() - ms).toISOString();
const MINUTE = 60_000;
const GIB = 1024 ** 3;

describe('numbers', () => {
  it('groups thousands with spaces', () => {
    expectText(formatNumber(12345)).toBe('12 345');
    expectText(formatNumber(1234567)).toBe('1 234 567');
    expect(formatNumber(7)).toBe('7');
  });

  it('shortens big counts only', () => {
    expectText(formatCompact(9999)).toBe('9 999');
    expectText(formatCompact(211_806)).toBe('212 тыс.');
    expectText(formatCompact(1_284_512)).toBe('1,28 млн');
  });

  it('picks the Russian plural', () => {
    expect(plural(1, 'событие', 'события', 'событий')).toBe('событие');
    expect(plural(3, 'событие', 'события', 'событий')).toBe('события');
    expect(plural(5, 'событие', 'события', 'событий')).toBe('событий');
    expect(plural(11, 'событие', 'события', 'событий')).toBe('событий');
    expect(plural(21, 'событие', 'события', 'событий')).toBe('событие');
    expectText(formatCount(1234, 'событие', 'события', 'событий')).toBe('1 234 события');
  });

  it('shows sizes in Б, КБ, МБ, ГБ', () => {
    expectText(formatBytes(980)).toBe('980 Б');
    expectText(formatBytes(1536)).toBe('1,5 КБ');
    expectText(formatBytes(512 * 1024 ** 2)).toBe('512 МБ');
    expectText(formatBytes(6.9 * GIB)).toBe('6,9 ГБ');
    expectText(formatBytes(80 * GIB)).toBe('80 ГБ');
  });

  it('shows shares as percent', () => {
    expectText(formatPercent(0.0862)).toBe('8,6 %');
    expectText(formatPercent(0.5)).toBe('50 %');
    expectText(formatPercent(0)).toBe('0 %');
  });

  it('shows durations', () => {
    expectText(formatDurationMs(850)).toBe('850 мс');
    expectText(formatDurationMs(1234)).toBe('1,2 с');
    expectText(formatDurationMs(45_000)).toBe('45 с');
    expectText(formatDurationMs(125_000)).toBe('2 мин 05 с');
    expect(formatMinutes(0.5)).toBe('меньше минуты');
    expectText(formatMinutes(14)).toBe('14 мин');
    expectText(formatMinutes(120)).toBe('2 ч');
    expectText(formatMinutes(125)).toBe('2 ч 05 мин');
    expectText(formatMinutes(3 * 1440 + 4 * 60)).toBe('3 дн. 4 ч');
  });
});

describe('dates and times, in the browser time zone', () => {
  it('formats times and dates', () => {
    expect(formatTime('2026-10-05T15:04:05Z')).toBe('18:04');
    expect(formatTimeWithSeconds('2026-10-05T15:04:05Z')).toBe('18:04:05');
    expectText(formatDate('2026-09-12T09:00:00Z', NOW)).toBe('12 сент.');
    expectText(formatDate('2025-12-31T10:00:00Z', NOW)).toBe('31 дек. 2025 г.');
    expectText(formatDateTime('2026-09-12T09:00:00Z', NOW)).toBe('12 сент., 12:00');
  });

  it('accepts the server offset "+00:00" as well as "Z"', () => {
    expect(formatTime('2026-10-05T15:04:05.123456+00:00')).toBe('18:04');
  });

  it('says how long ago', () => {
    expect(formatRelative(ago(30_000), NOW)).toBe('только что');
    expectText(formatRelative(ago(5 * MINUTE), NOW)).toBe('5 мин назад');
    expectText(formatRelative(ago(3 * 60 * MINUTE), NOW)).toBe('3 ч назад');
    expect(formatRelative('2026-10-05T05:10:00Z', NOW)).toBe('сегодня в 08:10');
    expect(formatRelative('2026-10-04T11:05:00Z', NOW)).toBe('вчера в 14:05');
    expectText(formatRelative('2026-10-02T09:00:00Z', NOW)).toBe('3 дня назад');
    expectText(formatRelative('2026-09-12T09:00:00Z', NOW)).toBe('12 сент.');
  });

  it('counts calendar days in Moscow, not in UTC', () => {
    // 22:30 UTC on 4 October is already 01:30 on 5 October in Moscow: today, not yesterday.
    expect(formatRelative('2026-10-04T22:30:00Z', NOW)).toBe('сегодня в 01:30');
    expect(dayKey('2026-10-04T22:30:00Z')).toBe(dayKey(NOW));
  });

  it('says how old, short', () => {
    expectText(formatAge(ago(40 * MINUTE), NOW)).toBe('40 мин');
    expectText(formatAge(ago(31 * 60 * MINUTE), NOW)).toBe('31 ч');
    expectText(formatAge(ago(3 * 24 * 60 * MINUTE), NOW)).toBe('3 дн.');
  });

  it('names the days of the визор', () => {
    expect(formatDayHeading(ago(MINUTE), NOW)).toBe('Сегодня');
    expect(formatDayHeading('2026-10-04T09:00:00Z', NOW)).toBe('Вчера');
    expect(formatDayHeading('2026-10-02T09:00:00Z', NOW)).toBe('Пятница, 2 октября');
  });
});

describe('the end of a plan', () => {
  it('writes the day as numbers', () => {
    expect(formatDateNumeric('2026-12-31T20:59:59.999Z')).toBe('31.12.2026');
    expect(formatDateNumeric('2026-10-01T10:00:00Z')).toBe('01.10.2026');
  });

  it('turns a picked day into its last moment in the browser time zone, and back', () => {
    // 23:59:59.999 in Moscow is 20:59:59.999 UTC.
    expect(endOfDayIso('2026-12-31')).toBe('2026-12-31T20:59:59.999Z');
    expect(dateInputValue(endOfDayIso('2026-12-31')!)).toBe('2026-12-31');
    expect(dateInputValue('2026-10-04T22:30:00Z')).toBe('2026-10-05');
    expect(endOfDayIso('')).toBeNull();
    expect(endOfDayIso('2026-02-31')).toBeNull();
    expect(endOfDayIso('31.12.2026')).toBeNull();
  });

  it('counts the days left', () => {
    expect(daysUntil('2026-10-05T20:00:00Z', NOW)).toBe(0);
    expect(daysUntil('2026-10-06T08:00:00Z', NOW)).toBe(1);
    expect(daysUntil('2026-12-31T20:59:59.999Z', NOW)).toBe(87);
  });
});

describe('shortenIds', () => {
  it('cuts long ids to their start', () => {
    expect(shortenIds('PUT /api/v1/pets/4a1f0c2e-1b2c-4d3e-8f90-123456789abc/photo')).toBe('PUT /api/v1/pets/4a1f…/photo');
    expect(shortenIds('GET /api/v1/today')).toBe('GET /api/v1/today');
  });
});
