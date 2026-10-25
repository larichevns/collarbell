// Dates, times and numbers in the app's language, with Intl. The API writes calendar dates as "2026-10-07" and times
// of day as "08:00:00", both in the household's time zone; they are shown as they are, never moved to the browser's
// zone. Moments ("2026-10-07T05:02:11Z", when a feeding was marked) are shown in the household's zone, like the
// feeding times next to them.
import type { Lang } from './lang';

export type DateStyle =
  /** Oct 7, 2026 · 7 окт. 2026 г. */
  | 'medium'
  /** Wednesday, October 7 · среда, 7 октября */
  | 'weekday'
  /** Wed, Oct 7 · ср, 7 окт. */
  | 'weekdayShort'
  /** Oct 7 · 7 окт. */
  | 'dayMonth'
  /** October 7 · 7 октября */
  | 'dayMonthLong';

const DATE_OPTIONS: Record<DateStyle, Intl.DateTimeFormatOptions> = {
  medium: { day: 'numeric', month: 'short', year: 'numeric' },
  weekday: { weekday: 'long', day: 'numeric', month: 'long' },
  weekdayShort: { weekday: 'short', day: 'numeric', month: 'short' },
  dayMonth: { day: 'numeric', month: 'short' },
  dayMonthLong: { day: 'numeric', month: 'long' },
};

const cache = new Map<string, Intl.DateTimeFormat | Intl.NumberFormat>();

function dateFormat(lang: Lang, key: string, options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  const id = `${lang}:${key}`;
  let format = cache.get(id) as Intl.DateTimeFormat | undefined;
  if (!format) {
    format = new Intl.DateTimeFormat(lang, options);
    cache.set(id, format);
  }
  return format;
}

const DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const TIME = /^(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$/;

/** A time of day as the language writes it: "8:00 AM" in English, «08:00» in Russian. */
function timeOptions(lang: Lang): Intl.DateTimeFormatOptions {
  return { hour: lang === 'ru' ? '2-digit' : 'numeric', minute: '2-digit' };
}

/** "2026-10-07" as midnight UTC: formatted in UTC, a calendar date never slips to the day before. */
function calendarDate(iso: string): Date | null {
  const match = DATE.exec(iso);
  return match ? new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]))) : null;
}

/**
 * A number and the Russian word after it ("7 окт.", "2026 г.") held together by a no-break space, as the texts of
 * ru.ts have them (tools/typograph.py): a line never ends between them.
 */
const NUMBER_THEN_WORD = /(\d) (?=[а-яё])/gi;

/** A calendar date of the API. Anything else is shown as it came. */
export function formatDate(lang: Lang, iso: string, style: DateStyle = 'medium'): string {
  const date = calendarDate(iso);
  if (!date) return iso;
  const text = dateFormat(lang, `date:${style}`, { ...DATE_OPTIONS[style], timeZone: 'UTC' }).format(date);
  return lang === 'ru' ? text.replace(NUMBER_THEN_WORD, '$1\u00a0') : text;
}

/** A time of day of the API ("08:00:00") the way the language writes it: "8:00 AM", «08:00». */
export function formatTime(lang: Lang, time: string): string {
  const match = TIME.exec(time);
  if (!match) return time;
  const at = new Date(Date.UTC(2000, 0, 1, Number(match[1]), Number(match[2])));
  return dateFormat(lang, 'time', { ...timeOptions(lang), timeZone: 'UTC' }).format(at);
}

/** The time of a moment in a time zone (the household's): "8:02 AM", «08:02». */
export function formatMomentTime(lang: Lang, moment: string, timeZone: string): string {
  const at = new Date(moment);
  if (Number.isNaN(at.getTime())) return moment;
  try {
    return dateFormat(lang, `moment:${timeZone}`, { ...timeOptions(lang), timeZone }).format(at);
  } catch {
    // A zone this browser doesn't know: its own clock is the next best thing.
    return dateFormat(lang, 'moment:local', timeOptions(lang)).format(at);
  }
}

/** 40 → "40", 2.5 → "2.5" · «2,5», 1234.5 → "1,234.5" · «1 234,5». */
export function formatNumber(lang: Lang, value: number, maximumFractionDigits = 2): string {
  const id = `${lang}:number:${maximumFractionDigits}`;
  let format = cache.get(id) as Intl.NumberFormat | undefined;
  if (!format) {
    format = new Intl.NumberFormat(lang, { maximumFractionDigits });
    cache.set(id, format);
  }
  return format.format(value);
}
