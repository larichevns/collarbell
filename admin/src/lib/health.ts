// What on the overview needs the owner's attention, and how loudly. The same rules colour the tiles and fill the list
// at the top. Red (danger): reminders fail or wait more than 10 minutes, the server answers 5xx, less than 10 % of
// the disk is free, no backup or one older than 26 hours (the server's own alerts use the same limits:
// backend Modules/Observe/Alerts.cs). Yellow (warning): worth a look, nothing is broken for everyone.
import type { Overview } from '../api/types';
import { formatBytes, formatCount, formatMinutes, formatPercent, formatRelative, hoursSince } from './format';

export const LATE_REMINDER_MINUTES = 10;
export const DISK_FREE_MIN_SHARE = 0.1;
export const BACKUP_MAX_AGE_HOURS = 26;

export type IssueTone = 'warning' | 'danger';

export interface Issue {
  id: IssueId;
  tone: IssueTone;
  text: string;
  /** Where to look closer, a path in the admin. */
  to?: string;
}

export type IssueId =
  | 'reminders-failed'
  | 'reminders-late'
  | 'reminders-expired'
  | 'server-errors'
  | 'crashes'
  | 'ai-failed'
  | 'disk-low'
  | 'backup-missing'
  | 'backup-old'
  | 'telegram-off';

/** The share of the disk that is free; null when the server couldn't tell. */
export function diskFreeShare(overview: Overview): number | null {
  const { diskTotalBytes, diskFreeBytes } = overview.server;
  return diskTotalBytes > 0 ? diskFreeBytes / diskTotalBytes : null;
}

/** Everything that needs attention, the red ones first. */
export function overviewIssues(overview: Overview, now: Date = new Date()): Issue[] {
  const { reminders, api, ai, server, alerts } = overview;
  const issues: Issue[] = [];

  if (reminders.failed24h > 0) {
    issues.push({
      id: 'reminders-failed',
      tone: 'danger',
      text: `Не ушло ${formatCount(reminders.failed24h, 'напоминание', 'напоминания', 'напоминаний')} за 24 ч`,
    });
  }
  const late = reminders.oldestOverdueMinutes ?? 0;
  if (late > LATE_REMINDER_MINUTES) {
    issues.push({
      id: 'reminders-late',
      tone: 'danger',
      text: `Напоминания задерживаются: самое старое ждёт ${formatMinutes(late)}`,
    });
  }
  if (api.serverErrors24h > 0) {
    issues.push({
      id: 'server-errors',
      tone: 'danger',
      text: `${formatCount(api.serverErrors24h, 'ошибка', 'ошибки', 'ошибок')} сервера (5xx) за 24 ч`,
      to: '/problems?kind=server',
    });
  }
  const free = diskFreeShare(overview);
  if (free !== null && free < DISK_FREE_MIN_SHARE) {
    issues.push({
      id: 'disk-low',
      tone: 'danger',
      text: `Мало места на диске: свободно ${formatBytes(server.diskFreeBytes)} из ${formatBytes(server.diskTotalBytes)} (${formatPercent(free)})`,
    });
  }
  if (server.lastBackupAt === null) {
    issues.push({ id: 'backup-missing', tone: 'danger', text: 'Копий базы нет' });
  } else {
    if (hoursSince(server.lastBackupAt, now) > BACKUP_MAX_AGE_HOURS) {
      issues.push({
        id: 'backup-old',
        tone: 'danger',
        text: `Ночной копии базы нет: последняя сделана ${formatRelative(server.lastBackupAt, now)}`,
      });
    }
  }

  if (reminders.expired24h > 0) {
    issues.push({
      id: 'reminders-expired',
      tone: 'warning',
      text: `${formatCount(
        reminders.expired24h,
        'напоминание опоздало и не ушло',
        'напоминания опоздали и не ушли',
        'напоминаний опоздали и не ушли',
      )} за 24 ч`,
    });
  }
  if (api.crashes24h > 0) {
    issues.push({
      id: 'crashes',
      tone: 'warning',
      text: `${formatCount(api.crashes24h, 'сбой', 'сбоя', 'сбоев')} приложения за 24 ч`,
      to: '/problems?kind=crash',
    });
  }
  if (ai.failed24h > 0) {
    issues.push({
      id: 'ai-failed',
      tone: 'warning',
      text: `AI: ${formatCount(ai.failed24h, 'ошибка', 'ошибки', 'ошибок')} из ${formatCount(ai.calls24h, 'вызова', 'вызовов', 'вызовов')} за 24 ч`,
    });
  }
  if (!alerts.telegramConfigured) {
    issues.push({ id: 'telegram-off', tone: 'warning', text: 'Оповещения в Telegram не настроены' });
  }

  return issues;
}

/** The tone of a tile: the loudest issue among those it shows. */
export function toneOf(issues: Issue[], ...ids: IssueId[]): IssueTone | undefined {
  const mine = issues.filter((issue) => ids.includes(issue.id));
  if (mine.some((issue) => issue.tone === 'danger')) return 'danger';
  return mine.length ? 'warning' : undefined;
}
