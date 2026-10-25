// Russian formatting: numbers with spaces («12 345»), sizes in КБ/МБ/ГБ, dates and times in the browser's time zone,
// relative times («5 мин назад», «вчера в 14:05»), durations and plurals. A number and its unit are joined with a
// no-break space, so «12 ГБ» never breaks across lines.

const LOCALE = 'ru-RU';
const NBSP = ' ';

const integer = new Intl.NumberFormat(LOCALE, { maximumFractionDigits: 0 });
const oneDecimal = new Intl.NumberFormat(LOCALE, { maximumFractionDigits: 1 });
const compact = new Intl.NumberFormat(LOCALE, { notation: 'compact', maximumSignificantDigits: 3 });
const pluralRules = new Intl.PluralRules(LOCALE);

const timeFormat = new Intl.DateTimeFormat(LOCALE, { hour: '2-digit', minute: '2-digit' });
const timeWithSecondsFormat = new Intl.DateTimeFormat(LOCALE, { hour: '2-digit', minute: '2-digit', second: '2-digit' });
const dayMonthFormat = new Intl.DateTimeFormat(LOCALE, { day: 'numeric', month: 'short' });
const dayMonthYearFormat = new Intl.DateTimeFormat(LOCALE, { day: 'numeric', month: 'short', year: 'numeric' });
const numericDateFormat = new Intl.DateTimeFormat(LOCALE, { day: '2-digit', month: '2-digit', year: 'numeric' });
const weekdayFormat = new Intl.DateTimeFormat(LOCALE, { weekday: 'long', day: 'numeric', month: 'long' });
const fullFormat = new Intl.DateTimeFormat(LOCALE, { dateStyle: 'long', timeStyle: 'medium' });

/** «12 345» (the group separator is a no-break space). */
export function formatNumber(value: number): string {
  return integer.format(value);
}

/** Big counts, short: «1,28 млн», «212 тыс.»; below 10 000 the whole number. */
export function formatCompact(value: number): string {
  return Math.abs(value) < 10_000 ? formatNumber(value) : compact.format(value);
}

/** The Russian word for a count: plural(3, 'событие', 'события', 'событий') → «события». */
export function plural(count: number, one: string, few: string, many: string): string {
  switch (pluralRules.select(count)) {
    case 'one':
      return one;
    case 'few':
      return few;
    default:
      return many;
  }
}

/** «3 события», «1 событие», «12 345 событий». */
export function formatCount(count: number, one: string, few: string, many: string): string {
  return `${formatNumber(count)}${NBSP}${plural(count, one, few, many)}`;
}

/** «980 Б», «512 КБ», «1,5 ГБ», «240 ГБ» (1 ГБ = 1024 МБ, as a disk shows it). */
export function formatBytes(bytes: number): string {
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  let value = bytes;
  let unit = 0;
  while (Math.abs(value) >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  const digits = unit > 0 && Math.abs(value) < 10 ? oneDecimal : integer;
  return `${digits.format(value)}${NBSP}${units[unit]}`;
}

/** A share: «7 %», «0,4 %», «100 %». */
export function formatPercent(ratio: number): string {
  const percent = ratio * 100;
  const digits = percent !== 0 && Math.abs(percent) < 10 ? oneDecimal : integer;
  return `${digits.format(percent)}${NBSP}%`;
}

/** «850 мс», «1,2 с», «45 с», «2 мин 05 с». */
export function formatDurationMs(ms: number): string {
  if (ms < 1000) return `${formatNumber(Math.round(ms))}${NBSP}мс`;
  const seconds = ms / 1000;
  if (seconds < 10) return `${oneDecimal.format(seconds)}${NBSP}с`;
  if (seconds < 60) return `${integer.format(Math.floor(seconds))}${NBSP}с`;
  const whole = Math.floor(seconds);
  return `${Math.floor(whole / 60)}${NBSP}мин ${String(whole % 60).padStart(2, '0')}${NBSP}с`;
}

/** «меньше минуты», «14 мин», «2 ч», «2 ч 05 мин», «3 дн. 4 ч». */
export function formatMinutes(minutes: number): string {
  const whole = Math.floor(minutes);
  if (whole < 1) return 'меньше минуты';
  if (whole < 60) return `${whole}${NBSP}мин`;
  if (whole < 24 * 60) {
    const hours = Math.floor(whole / 60);
    const rest = whole % 60;
    return rest ? `${hours}${NBSP}ч ${String(rest).padStart(2, '0')}${NBSP}мин` : `${hours}${NBSP}ч`;
  }
  const days = Math.floor(whole / (24 * 60));
  const hours = Math.floor((whole % (24 * 60)) / 60);
  return hours ? `${days}${NBSP}дн. ${hours}${NBSP}ч` : `${days}${NBSP}дн.`;
}

function toDate(value: string | Date): Date {
  return value instanceof Date ? value : new Date(value);
}

/** A day's number joined to its month with a no-break space, as in the rest of the Russian texts: «12\u00a0сент.». */
function bindDayToMonth(text: string): string {
  return text.replace(/(\d) (?=[а-яё])/gi, `$1${NBSP}`);
}

/** The calendar day in the browser's time zone, as a key: "2026-9-5" (months from 0). */
export function dayKey(value: string | Date): string {
  const date = toDate(value);
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}

/** Whole calendar days from `value` to `now` in the browser's time zone (0: the same day, 1: yesterday). */
function calendarDaysBetween(value: Date, now: Date): number {
  const from = new Date(value.getFullYear(), value.getMonth(), value.getDate());
  const to = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.round((to.getTime() - from.getTime()) / 86_400_000);
}

/** «14:05». */
export function formatTime(value: string | Date): string {
  return timeFormat.format(toDate(value));
}

/** «14:05:09». */
export function formatTimeWithSeconds(value: string | Date): string {
  return timeWithSecondsFormat.format(toDate(value));
}

/** «5 окт.», with the year only when it isn't this year: «5 окт. 2025 г.». */
export function formatDate(value: string | Date, now: Date = new Date()): string {
  const date = toDate(value);
  return bindDayToMonth((date.getFullYear() === now.getFullYear() ? dayMonthFormat : dayMonthYearFormat).format(date));
}

/** «31.12.2026», for a plan's end. */
export function formatDateNumeric(value: string | Date): string {
  return numericDateFormat.format(toDate(value));
}

/** The value of <input type="date"> for a moment's calendar day in the browser's time zone: «2026-12-31». */
export function dateInputValue(value: string | Date): string {
  const date = toDate(value);
  const pad = (part: number) => String(part).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/**
 * The last moment of a day picked in <input type="date"> («2026-12-31»), in the browser's time zone, as ISO:
 * "until 31 December" means through that day. null for anything that isn't such a day.
 */
export function endOfDayIso(day: string): string | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(day);
  if (!match) return null;
  const [year, month, date] = [Number(match[1]), Number(match[2]) - 1, Number(match[3])];
  const end = new Date(year, month, date, 23, 59, 59, 999);
  // 2026-02-31 would roll over to March: not a real day.
  if (end.getFullYear() !== year || end.getMonth() !== month || end.getDate() !== date) return null;
  return end.toISOString();
}

/** Whole calendar days from `now` to a later moment, in the browser's time zone (0: today). */
export function daysUntil(value: string | Date, now: Date = new Date()): number {
  return calendarDaysBetween(now, toDate(value));
}

/** «5 окт., 14:05». */
export function formatDateTime(value: string | Date, now: Date = new Date()): string {
  return `${formatDate(value, now)}, ${formatTime(value)}`;
}

/** Everything, for a tooltip: «5 октября 2026 г. в 14:05:09». */
export function formatFull(value: string | Date): string {
  return fullFormat.format(toDate(value));
}

/** «только что», «5 мин назад», «3 ч назад», «сегодня в 08:10», «вчера в 14:05», «3 дня назад», «12 сент.». */
export function formatRelative(value: string | Date, now: Date = new Date()): string {
  const date = toDate(value);
  const ms = now.getTime() - date.getTime();
  if (ms < 60_000) return 'только что';
  const minutes = Math.floor(ms / 60_000);
  if (minutes < 60) return `${minutes}${NBSP}мин назад`;
  const hours = Math.floor(minutes / 60);
  if (hours < 6) return `${hours}${NBSP}ч назад`;
  const days = calendarDaysBetween(date, now);
  if (days === 0) return `сегодня в ${formatTime(date)}`;
  if (days === 1) return `вчера в ${formatTime(date)}`;
  if (days < 7) return `${days}${NBSP}${plural(days, 'день', 'дня', 'дней')} назад`;
  return formatDate(date, now);
}

/** The heading of a day in the визор: «Сегодня», «Вчера», «Пятница, 3 октября». */
export function formatDayHeading(value: string | Date, now: Date = new Date()): string {
  const date = toDate(value);
  const days = calendarDaysBetween(date, now);
  if (days === 0) return 'Сегодня';
  if (days === 1) return 'Вчера';
  const text = bindDayToMonth(weekdayFormat.format(date));
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** How old something is, short: «40 мин», «31 ч», «3 дн.» (up to 2 days in hours: the backup is "31 h" old). */
export function formatAge(value: string | Date, now: Date = new Date()): string {
  const minutes = Math.max(0, Math.floor((now.getTime() - toDate(value).getTime()) / 60_000));
  if (minutes < 60) return `${minutes}${NBSP}мин`;
  const hours = Math.floor(minutes / 60);
  if (hours < 48) return `${hours}${NBSP}ч`;
  return `${Math.floor(hours / 24)}${NBSP}дн.`;
}

/** Hours since a moment (for "the backup is 31 h old"). */
export function hoursSince(value: string | Date, now: Date = new Date()): number {
  return (now.getTime() - toDate(value).getTime()) / 3_600_000;
}

const GUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;

/** Long ids cut to their start, for reading: «PUT /api/v1/pets/4a1f0c2e-…» → «PUT /api/v1/pets/4a1f…». */
export function shortenIds(text: string): string {
  return text.replace(GUID, (id) => `${id.slice(0, 4)}…`);
}
