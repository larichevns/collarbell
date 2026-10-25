// Words for what the server sends as values: due dates, intervals, reminders, ages, portions, weights. The same choices
// as the phone app's *_labels.dart files, so both say the same.
import type {
  CarePlan,
  CarePreset,
  CareRecord,
  DayOfWeek,
  HouseholdMember,
  HouseholdRole,
  IntervalUnit,
  PortionUnit,
  StockEvent,
  Supply,
  SupplyUnit,
} from '../api/types';
import type { Messages } from '../i18n/en';
import type { I18n } from '../i18n/i18n';
import { ageOn, daysBetween } from './dates';
import { orderedDays, WEEK, weekdayShort } from './feeding';
import type { IdentifierProblem } from './identifiers';
import { MAX_RAW_LENGTH, MAX_TATTOO_LENGTH } from './identifiers';
import { roundAmount } from './supplies';
import { grams, type WeightProblem } from './weight';

/** The name the server gives a person's first household (CurrentUserAccessor.DefaultHouseholdName). */
const DEFAULT_HOUSEHOLD_NAME = 'Home';

/** A household's name as shown: the server's "Home" is "My home" to its owner, "Home" to anyone else. */
export function householdName(t: Messages, name: string, role: HouseholdRole): string {
  if (name !== DEFAULT_HOUSEHOLD_NAME) return name;
  return role === 'Owner' ? t.householdDefaultName : t.householdDefaultNameOther;
}

/** How far a due date is: "Today", "Tomorrow", "In 5 days", "In 3 months", "3 days overdue". */
export function dueLabel(t: Messages, daysLeft: number): string {
  if (daysLeft < 0) return t.dueOverdueDays(-daysLeft);
  if (daysLeft === 0) return t.dueToday;
  if (daysLeft === 1) return t.dueTomorrow;
  // Far dates read better in months: "In 11 months", not "In 334 days".
  if (daysLeft < 60) return t.dueInDays(daysLeft);
  return t.dueInMonths(Math.floor(daysLeft / 30));
}

/** "Every 3 months", or "One-off" for a plan without an interval. */
export function intervalLabel(t: Messages, value: number | null, unit: IntervalUnit | null): string {
  return value && unit ? t.intervalEvery(value, unit) : t.intervalOneOff;
}

/** "A day before", "2 hours before"; reminders set elsewhere in any number of minutes too. */
export function visitReminderLabel(t: Messages, minutes: number): string {
  if (minutes === 0) return t.visitRemindAtStart;
  if (minutes === 10080) return t.visitRemindWeek;
  if (minutes === 1440) return t.visitRemindDay;
  if (minutes === 60) return t.visitRemindHour;
  if (minutes % 10080 === 0) return t.visitRemindWeeks(minutes / 10080);
  if (minutes % 1440 === 0) return t.visitRemindDays(minutes / 1440);
  if (minutes % 60 === 0) return t.visitRemindHours(minutes / 60);
  return t.visitRemindMinutes(minutes);
}

/** When a visit is, counted from the household's today: "Today at 10:30", "Fri, Oct 10 at 10:30". */
export function visitWhen(i18n: I18n, date: string, time: string, today: string): string {
  const { t } = i18n;
  const at = i18n.time(time);
  switch (daysBetween(today, date)) {
    case 0:
      return t.visitToday(at);
    case 1:
      return t.visitTomorrow(at);
    case -1:
      return t.visitYesterday(at);
    default:
      return t.visitOnDate(i18n.date(date, 'weekdayShort'), at);
  }
}

/** How long a supply lasts: "about 20 days", "less than a day". */
export function supplyDaysLabel(t: Messages, days: number): string {
  return days < 1 ? t.supplyLastsLessThanDay : t.supplyLastsDays(Math.floor(days));
}

/** "2 kg", "400 g", "1.5 l", "12 pcs", "3 doses": an amount in an item's unit, in kilograms and litres from 1000 up. */
export function supplyAmountLabel(i18n: I18n, unit: SupplyUnit, amount: number): string {
  const { t } = i18n;
  // Rounded first; small amounts keep their two significant digits (0.0042 g a day).
  const number = (value: number) => i18n.number(roundAmount(value), 6);
  switch (unit) {
    case 'Gram':
      return amount >= 1000 ? t.supplyKg(number(amount / 1000)) : t.portion.Gram(number(amount));
    case 'Milliliter':
      return amount >= 1000 ? t.supplyLiters(number(amount / 1000)) : t.portion.Milliliter(number(amount));
    case 'Piece':
      return t.portion.Piece(number(amount));
    case 'Dose': {
      // The word follows the number shown: 4.998 doses read as 5, and "5 doses" («5 доз»), not «5 дозы».
      const shown = roundAmount(amount);
      return Number.isInteger(shown) ? t.supplyDoses(shown) : t.supplyDosesFraction(number(amount));
    }
  }
}

/** "≈ 1.5 pkg": an amount counted in packages, to a tenth. */
export function supplyPackagesLabel(i18n: I18n, packages: number): string {
  return i18n.t.supplyPackages(i18n.number(Math.round(packages * 10) / 10, 1));
}

/** What the list says about an item's stock: "Buy by Oct 9 · enough for about 10 days", "Ran out". */
export function supplyStatusLine(i18n: I18n, supply: Supply): string {
  const { t } = i18n;
  const { status, daysLeft, remaining, buyBy } = supply.forecast;
  if (!supply.active) return t.supplyInactive;
  switch (status) {
    case 'OutOfStock':
      return t.supplyOutOfStock;
    case 'BuyNow':
      if (daysLeft !== null) return t.supplyBuyNowLeft(supplyDaysLabel(t, daysLeft));
      break;
    case 'Soon':
      if (daysLeft !== null && buyBy)
        return t.supplySoonLeft(i18n.date(buyBy, 'dayMonth'), supplyDaysLabel(t, daysLeft));
      break;
    case 'Enough':
      if (daysLeft !== null) return t.supplyEnoughFor(supplyDaysLabel(t, daysLeft));
      break;
    case 'NoUsage':
      if (remaining !== null) return t.supplyLeftNoUsage(supplyAmountLabel(i18n, supply.unit, remaining));
      break;
    case 'NoStock':
      break;
  }
  return t.supplyNoStock;
}

/** The tag of an item's stock: red when it ran out, yellow when it's time to buy (as care due soon), else calm text. */
export function supplyStatusTone(supply: Pick<Supply, 'active' | 'forecast'>): 'danger' | 'warning' | 'muted' {
  if (!supply.active) return 'muted';
  if (supply.forecast.status === 'OutOfStock') return 'danger';
  return supply.forecast.status === 'BuyNow' ? 'warning' : 'muted';
}

/** A purchase or a count as the history says it: "Bought +2 kg", "Left: 1.5 kg". */
export function stockEntryLabel(i18n: I18n, unit: SupplyUnit, entry: Pick<StockEvent, 'kind' | 'quantity'>): string {
  const amount = supplyAmountLabel(i18n, unit, entry.quantity);
  return entry.kind === 'Purchase' ? i18n.t.supplyEntryPurchase(amount) : i18n.t.supplyEntryCount(amount);
}

/** A person as a group's list shows them: the name, else the e-mail. */
export function memberName(t: Messages, member: Pick<HouseholdMember, 'displayName' | 'email'>): string {
  return member.displayName?.trim() || member.email || t.householdNoName;
}

/** What a feeding gives: "Royal Canin, 40 g", or one of the two; null when the schedule says neither. */
export function feedingWhat(
  i18n: I18n,
  food: string | null,
  amount: number | null,
  unit: PortionUnit | null,
): string | null {
  const portion = amount !== null && unit ? i18n.t.portion[unit](i18n.number(amount)) : null;
  const parts = [food, portion].filter((part): part is string => !!part);
  return parts.length ? parts.join(', ') : null;
}

/** "3 years", "5 months", "Under a month"; "≈ 3 years" for an approximate date of birth. Null after today. */
export function ageLabel(t: Messages, birthDate: string, approximate: boolean, today: string): string | null {
  const age = ageOn(birthDate, today);
  if (!age) return null;
  const text = age.years > 0 ? t.ageYears(age.years) : age.months > 0 ? t.ageMonths(age.months) : t.ageUnderMonth;
  return approximate ? t.ageApproximate(text) : text;
}

export function identifierProblemLabel(t: Messages, problem: IdentifierProblem): string {
  switch (problem) {
    case 'empty':
      return t.identifierCodeRequired;
    case 'tooLong':
      return t.formTooLong(MAX_RAW_LENGTH);
    case 'isoLength':
      return t.identifierIsoLength;
    case 'isoTestChip':
      return t.identifierIsoTestChip;
    case 'legacyFormat':
      return t.identifierLegacyFormat;
    case 'tattooLength':
      return t.identifierTattooLength(MAX_TATTOO_LENGTH);
    case 'duplicate':
      return t.identifierDuplicate;
  }
}

/** "Overdue", "Due soon", "Upcoming"; an inactive plan is "Finished" (a one-off plan that was done) or "Paused". */
export function planStatusLabel(t: Messages, plan: Pick<CarePlan, 'status' | 'intervalValue' | 'lastDoneOn'>): string {
  switch (plan.status) {
    case 'Overdue':
      return t.careStatusOverdue;
    case 'DueSoon':
      return t.careStatusDueSoon;
    case 'Upcoming':
      return t.careStatusUpcoming;
    case 'Inactive':
      return plan.intervalValue === null && plan.lastDoneOn ? t.careStatusFinished : t.careStatusPaused;
  }
}

/** A ready-made plan's title in the person's language, by its code; the server's English title for a code not known. */
export function presetTitle(t: Messages, preset: Pick<CarePreset, 'code' | 'title'>): string {
  return t.presetTitles[preset.code] ?? preset.title;
}

/** A ready-made plan's note in the person's language, or none; the server's English note for a code not known. */
export function presetNote(t: Messages, preset: Pick<CarePreset, 'code' | 'note'>): string | null {
  if (preset.code in t.presetTitles) return t.presetNotes[preset.code] ?? null;
  return preset.note;
}

/** A record's date, with the time when it has one: "Jun 1, 2026, 2:30 PM". */
export function recordDateLabel(i18n: I18n, record: Pick<CareRecord, 'performedOn' | 'performedTime'>): string {
  const date = i18n.date(record.performedOn);
  return record.performedTime ? i18n.t.dateWithTime(date, i18n.time(record.performedTime)) : date;
}

/** "Every day", or the days in short, Monday first: "Mon, Wed, Fri" («пн, ср, пт»). */
export function feedingDaysLabel(i18n: I18n, days: readonly DayOfWeek[]): string {
  const shown = orderedDays(days);
  if (shown.length === 0 || shown.length === WEEK.length) return i18n.t.feedingEveryDay;
  return shown.map((day) => weekdayShort(i18n.lang, day)).join(', ');
}

/** A weight to the gram, without its unit: "4.235", «4,2». */
export function weightNumberLabel(i18n: I18n, kg: number): string {
  return i18n.number(grams(kg) / 1000, 3);
}

/** A weight as people read it: "4.235 kg", «4,2 кг». */
export function weightValueLabel(i18n: I18n, kg: number): string {
  return i18n.t.weightValue(weightNumberLabel(i18n, kg));
}

/** A change of some grams: "+0.2 kg", "−0.15 kg" (a true minus, as wide as the plus), or "no change". */
export function weightChangeLabel(i18n: I18n, change: number): string {
  if (change === 0) return i18n.t.weightNoChange;
  const sign = change > 0 ? '+' : '−';
  return i18n.t.weightValue(`${sign}${i18n.number(Math.abs(change) / 1000, 3)}`);
}

export function weightProblemLabel(t: Messages, problem: WeightProblem, decimals: number): string {
  switch (problem) {
    case 'required':
      return t.weightRequired;
    case 'invalid':
      return t.weightInvalid;
    case 'tooPrecise':
      return t.weightTooPrecise(decimals);
  }
}
