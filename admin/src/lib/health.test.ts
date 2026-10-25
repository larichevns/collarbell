import { describe, expect, it } from 'vitest';
import type { Overview } from '../api/types';
import { overviewIssues, toneOf } from './health';

// The texts are compared with no-break spaces as plain ones: the code and tools/typograph.py don't always put them in
// the same places.
const plain = (text: string) => text.replace(/\u00a0/g, ' ');

const NOW = new Date('2026-10-05T15:00:00Z');
const GIB = 1024 ** 3;
const hoursAgo = (hours: number) => new Date(NOW.getTime() - hours * 3_600_000).toISOString();

/** A service with nothing wrong; each test breaks one thing. */
function calm(): Overview {
  return {
    generatedAt: NOW.toISOString(),
    people: { users: 10, households: 8, sharedHouseholds: 2, premiumHouseholds: 1, pets: 12, activeToday: 4, activeWeek: 8, newWeek: 1 },
    reminders: { sent24h: 50, failed24h: 0, skipped24h: 3, expired24h: 0, pending: 9, oldestOverdueMinutes: 0 },
    devices: { android: 6, ios: 4, appVersions: [{ version: '1.4.0', devices: 10 }] },
    ai: { calls24h: 5, failed24h: 0, calls30d: 40, failed30d: 1, inputTokens30d: 1000, outputTokens30d: 200, models30d: [] },
    api: { requests24h: 900, serverErrors24h: 0, appErrors24h: 2, crashes24h: 0 },
    server: { diskTotalBytes: 80 * GIB, diskFreeBytes: 40 * GIB, lastBackupAt: hoursAgo(13), lastBackupBytes: GIB },
    alerts: { telegramConfigured: true, recent: [] },
  };
}

const ids = (overview: Overview) => overviewIssues(overview, NOW).map((issue) => issue.id);

describe('overviewIssues', () => {
  it('finds nothing on a calm service (app errors alone are not a problem)', () => {
    expect(overviewIssues(calm(), NOW)).toEqual([]);
  });

  it('flags failed reminders and a wait over 10 minutes', () => {
    const overview = calm();
    overview.reminders.failed24h = 1;
    overview.reminders.oldestOverdueMinutes = 10;
    expect(ids(overview)).toEqual(['reminders-failed']);
    overview.reminders.oldestOverdueMinutes = 11;
    expect(ids(overview)).toEqual(['reminders-failed', 'reminders-late']);
    overview.reminders.oldestOverdueMinutes = null;
    expect(ids(overview)).toEqual(['reminders-failed']);
  });

  it('flags server errors with a link to them', () => {
    const overview = calm();
    overview.api.serverErrors24h = 3;
    const [issue] = overviewIssues(overview, NOW);
    expect(issue).toMatchObject({ id: 'server-errors', tone: 'danger', to: '/problems?kind=server' });
  });

  it('flags a disk with less than 10 % free, but not an unknown one', () => {
    const overview = calm();
    overview.server.diskFreeBytes = 8 * GIB;
    expect(ids(overview)).toEqual([]);
    overview.server.diskFreeBytes = 7.9 * GIB;
    expect(ids(overview)).toEqual(['disk-low']);
    overview.server.diskTotalBytes = 0;
    overview.server.diskFreeBytes = 0;
    expect(ids(overview)).toEqual([]);
  });

  it('flags a backup older than 26 hours, or none', () => {
    const overview = calm();
    overview.server.lastBackupAt = hoursAgo(25.9);
    expect(ids(overview)).toEqual([]);
    overview.server.lastBackupAt = hoursAgo(26.1);
    expect(ids(overview)).toEqual(['backup-old']);
    overview.server.lastBackupAt = null;
    expect(ids(overview)).toEqual(['backup-missing']);
  });

  it('lists red before yellow', () => {
    const overview = calm();
    overview.api.crashes24h = 1;
    overview.alerts.telegramConfigured = false;
    overview.ai.failed24h = 2;
    overview.reminders.expired24h = 1;
    overview.reminders.failed24h = 2;
    const issues = overviewIssues(overview, NOW);
    expect(issues.map((issue) => issue.tone)).toEqual(['danger', 'warning', 'warning', 'warning', 'warning']);
    expect(issues.map((issue) => issue.id)).toEqual(['reminders-failed', 'reminders-expired', 'crashes', 'ai-failed', 'telegram-off']);
  });

  it('writes Russian with the right forms', () => {
    const overview = calm();
    overview.reminders.failed24h = 2;
    overview.reminders.expired24h = 1;
    overview.api.serverErrors24h = 5;
    const texts = overviewIssues(overview, NOW).map((issue) => plain(issue.text));
    expect(texts).toContain(plain('Не ушло 2 напоминания за 24 ч'));
    expect(texts).toContain(plain('5 ошибок сервера (5xx) за 24 ч'));
    expect(texts).toContain(plain('1 напоминание опоздало и не ушло за 24 ч'));
  });
});

describe('toneOf', () => {
  it('takes the loudest issue of a tile', () => {
    const overview = calm();
    overview.server.lastBackupAt = null;
    overview.api.crashes24h = 1;
    const issues = overviewIssues(overview, NOW);
    expect(toneOf(issues, 'backup-old', 'backup-missing')).toBe('danger');
    expect(toneOf(issues, 'crashes')).toBe('warning');
    expect(toneOf(issues, 'disk-low')).toBeUndefined();
  });
});
