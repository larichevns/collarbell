// Feeding schedules (the phone app's feeding.dart and feeding_labels.dart): the days of the week Monday first, the
// times in order, the server's limits, and which supplies a feeding can give.
import type { DayOfWeek, PortionUnit, Supply, SupplyCategory, SupplyUnit, TodayFeeding } from '../api/types';
import type { Lang } from '../i18n/lang';

/** The server's limits. */
export const FEEDING_MAX = { times: 8, food: 100, notes: 500, amount: 10_000 } as const;

/** The week as the app shows it: Monday first. */
export const WEEK: readonly DayOfWeek[] = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/** Days in the week's order, whatever order they came in. */
export function orderedDays(days: readonly DayOfWeek[]): DayOfWeek[] {
  return WEEK.filter((day) => days.includes(day));
}

/** "Mon" («пн») in the app's language. 2024-01-01 was a Monday. */
export function weekdayShort(lang: Lang, day: DayOfWeek): string {
  const date = new Date(Date.UTC(2024, 0, 1 + WEEK.indexOf(day)));
  return new Intl.DateTimeFormat(lang, { weekday: 'short', timeZone: 'UTC' }).format(date);
}

/** Times of the API ("08:00:00") earliest first, each once. */
export function orderedTimes(times: readonly string[]): string[] {
  return [...new Set(times)].sort();
}

/** Up to 5 digits and 2 decimals, with a point or a comma. */
const AMOUNT = /^\d{1,5}([.,]\d{1,2})?$/;

/** Whether a portion typed in the form is one the server takes: above 0, up to 10 000, at most 2 decimals. */
export function amountOk(text: string): boolean {
  const trimmed = text.trim();
  if (!AMOUNT.test(trimmed)) return false;
  const amount = Number(trimmed.replace(',', '.'));
  return amount > 0 && amount <= FEEDING_MAX.amount;
}

/** Food is what a feeding gives: dry and wet food and treats. */
export function isFood(category: SupplyCategory): boolean {
  return category === 'DryFood' || category === 'WetFood' || category === 'Treats';
}

/** The unit of a portion that counts towards a supply counted in `unit`; null for doses. */
export function portionUnitFor(unit: SupplyUnit): PortionUnit | null {
  return unit === 'Dose' ? null : unit;
}

/** The supplies a feeding can give: food the household still buys, in a unit a portion can have; and `linked`. */
export function choosableSupplies(supplies: readonly Supply[], linked: string | null): Supply[] {
  return supplies.filter(
    (supply) =>
      (supply.active && isFood(supply.category) && portionUnitFor(supply.unit) !== null) || supply.id === linked,
  );
}

/** Today's feedings by time of day ("08:00:00"), earliest first; within a time, the server's order. */
export function feedingSlots(feedings: readonly TodayFeeding[]): Map<string, TodayFeeding[]> {
  const slots = new Map<string, TodayFeeding[]>();
  for (const item of [...feedings].sort((a, b) => a.time.localeCompare(b.time))) {
    slots.set(item.time, [...(slots.get(item.time) ?? []), item]);
  }
  return slots;
}

/**
 * The next feeding (Home's "Right now"): the earliest time of today with a pet not fed, and not skipped, yet; null
 * when every feeding of today is marked.
 */
export function nextFeedingTime(feedings: readonly TodayFeeding[]): string | null {
  for (const [time, items] of feedingSlots(feedings)) {
    if (items.some((item) => !item.mark)) return time;
  }
  return null;
}
