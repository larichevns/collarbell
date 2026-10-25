// Calendar dates the way the API writes them ("2026-10-07") and counts them: in the household's time zone, on the
// calendar rather than in hours (a day with a clock change has 23 or 25 hours), and months the server's way
// (31 January + 1 month is the last day of February).
import type { IntervalUnit } from '../api/types';

const DAY_MS = 86_400_000;

function utc(iso: string): number {
  const [year, month, day] = iso.split('-').map(Number);
  return Date.UTC(year!, month! - 1, day!);
}

function iso(time: number): string {
  return new Date(time).toISOString().slice(0, 10);
}

/** Today in a time zone (the household's): "2026-10-07". */
export function todayIn(timeZone: string, now: Date = new Date()): string {
  let format: Intl.DateTimeFormat;
  try {
    format = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' });
  } catch {
    // A zone this browser doesn't know: its own calendar is the next best thing.
    format = new Intl.DateTimeFormat('en-CA', { year: 'numeric', month: '2-digit', day: '2-digit' });
  }
  const parts = format.formatToParts(now);
  const part = (type: string) => parts.find((item) => item.type === type)?.value ?? '';
  return `${part('year')}-${part('month')}-${part('day')}`;
}

/** Calendar days from one date to another: "2026-10-07" → "2026-10-09" is 2, back is -2. */
export function daysBetween(from: string, to: string): number {
  return Math.round((utc(to) - utc(from)) / DAY_MS);
}

export function addDays(date: string, days: number): string {
  return iso(utc(date) + days * DAY_MS);
}

/** Months later, keeping the day where the month has it: 2026-01-31 + 1 month = 2026-02-28. */
export function addMonths(date: string, months: number): string {
  const [year, month, day] = date.split('-').map(Number);
  const first = new Date(Date.UTC(year!, month! - 1 + months, 1));
  const lastDay = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate();
  return iso(Date.UTC(first.getUTCFullYear(), first.getUTCMonth(), Math.min(day!, lastDay)));
}

/** One interval of a plan later (the server's Intervals.Add). */
export function addInterval(date: string, value: number, unit: IntervalUnit): string {
  switch (unit) {
    case 'Day':
      return addDays(date, value);
    case 'Week':
      return addDays(date, 7 * value);
    case 'Month':
      return addMonths(date, value);
    case 'Year':
      return addMonths(date, 12 * value);
  }
}

/** Whole years and months from a date of birth to today; null for a date after today. */
export function ageOn(birthDate: string, today: string): { years: number; months: number } | null {
  if (daysBetween(birthDate, today) < 0) return null;
  const [birthYear, birthMonth, birthDay] = birthDate.split('-').map(Number);
  const [year, month, day] = today.split('-').map(Number);
  let months = (year! - birthYear!) * 12 + (month! - birthMonth!);
  if (day! < birthDay!) months -= 1;
  return { years: Math.floor(months / 12), months: months % 12 };
}

/** A time of the API ("08:00:00") as <input type="time"> holds it ("08:00"). */
export function timeInputValue(time: string | null | undefined): string {
  return time ? time.slice(0, 5) : '';
}

/** <input type="time">'s "08:00" as the API takes times: "08:00:00". */
export function apiTime(value: string): string {
  return `${value.slice(0, 5)}:00`;
}

/**
 * The calendar date of a moment ("2026-11-01T00:00:00Z") on this browser's clock, as the API writes dates: for what
 * belongs to no household's day, such as when an invite stops working or the month's AI photos start again.
 */
export function localDateOf(moment: string): string {
  const at = new Date(moment);
  if (Number.isNaN(at.getTime())) return moment;
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${at.getFullYear()}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}`;
}
