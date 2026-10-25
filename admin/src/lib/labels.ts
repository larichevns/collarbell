// Russian names for what the server sends as codes: roles, platforms, визор kinds, problem kinds, alert kinds.
// An unknown code is shown as it is.
import type { IconName } from '../components/icons';

/** The same words as the app (mobile/lib/l10n/app_ru.arb: householdRole…). */
const ROLES: Record<string, string> = { owner: 'Владелец', member: 'Участник', helper: 'Помощник' };

export function roleLabel(role: string): string {
  return ROLES[role.toLowerCase()] ?? role;
}

const PLATFORMS: Record<string, string> = { android: 'Android', ios: 'iOS' };

export function platformLabel(platform: string): string {
  return PLATFORMS[platform.toLowerCase()] ?? platform;
}

export interface KindInfo {
  label: string;
  icon: IconName;
}

const TIMELINE_KINDS: Record<string, KindInfo> = {
  request: { label: 'Запрос', icon: 'sync_alt' },
  screen: { label: 'Экран', icon: 'smartphone' },
  action: { label: 'Действие', icon: 'touch_app' },
  error: { label: 'Ошибка', icon: 'error' },
  crash: { label: 'Сбой', icon: 'bug_report' },
};

export function timelineKind(kind: string): KindInfo {
  return TIMELINE_KINDS[kind] ?? { label: kind, icon: 'schedule' };
}

const PROBLEM_KINDS: Record<string, string> = {
  server: 'Ошибка сервера',
  'app-error': 'Ошибка в приложении',
  crash: 'Сбой приложения',
};

export function problemKindLabel(kind: string): string {
  return PROBLEM_KINDS[kind] ?? kind;
}

/** The same, for a filter of many: «Ошибки сервера». */
const PROBLEM_KINDS_PLURAL: Record<string, string> = {
  server: 'Ошибки сервера',
  'app-error': 'Ошибки в приложении',
  crash: 'Сбои приложения',
};

export function problemKindPlural(kind: string): string {
  return PROBLEM_KINDS_PLURAL[kind] ?? kind;
}

/** The alerts the server sends to Telegram (backend: Modules/Observe/Alerts.cs). */
const ALERT_KINDS: Record<string, string> = {
  'reminders-late': 'Напоминания задерживаются',
  'reminders-failed': 'Напоминания не уходят',
  'server-errors': 'Ошибки сервера',
  'ai-failing': 'AI не отвечает',
  'backup-old': 'Старый бэкап',
  'backup-missing': 'Бэкапов нет',
  'disk-low': 'Мало места на диске',
  'sign-in-deletion': 'Вход удалённого аккаунта не удаляется',
};

export function alertKindLabel(kind: string): string {
  return ALERT_KINDS[kind] ?? kind;
}

export type Tone = 'neutral' | 'ok' | 'warning' | 'danger';

/** The colour of an HTTP status: 2xx fine, 3xx neutral, 4xx yellow (the person's mistake or a conflict), 5xx red. */
export function statusTone(status: number | null): Tone {
  if (status === null) return 'neutral';
  if (status >= 500) return 'danger';
  if (status >= 400) return 'warning';
  if (status >= 200 && status < 300) return 'ok';
  return 'neutral';
}

/** The name to show for a person: their name, else their e-mail. */
export function personName(person: { displayName: string | null; email: string | null }): string {
  return person.displayName?.trim() || person.email || 'Без имени';
}
