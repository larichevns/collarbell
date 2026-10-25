// A pet's weight log and its chart (the phone app's weight.dart and weight_chart.dart): the server's limits, the
// change between weights, the chart's periods and where its points go. Weights are compared in whole grams: as
// doubles, 4.3 − 4.1 is 0.19999… kg.
import type { Pet } from '../api/types';
import { parseDecimal, typedDecimals } from './numbers';

/** The heaviest weight the server takes: a giant breed is about 100 kg, so more is a typo (grams typed as kg). */
export const MAX_KG = 200;
/** A weighing is kept to the gram; a check-up record keeps its weight to 10 g. */
export const WEIGHING_DECIMALS = 3;
export const RECORD_DECIMALS = 2;
export const MAX_WEIGHT_NOTE = 500;
/** No weighing is older than this, as for care records. */
export const EARLIEST_WEIGHT_DATE = '1990-01-01';

/** The body condition scales: 9 points (WSAVA, the usual one) or 5. */
export const BCS_SCALES = [9, 5] as const;
export type BcsScale = (typeof BCS_SCALES)[number];

/** The ideal scores on a scale: "4–5" of 9, "3" of 5. */
export function bcsIdeal(scale: number): string {
  return scale === 5 ? '3' : '4–5';
}

/** A weight in whole grams. */
export function grams(kg: number): number {
  return Math.round(kg * 1000);
}

/** The first date a weighing of the pet can have: its birth date when that is exact, else 1990; never after today. */
export function firstWeighingDate(pet: Pick<Pet, 'birthDate' | 'birthDateApproximate'>, today: string): string {
  const birth = pet.birthDateApproximate ? null : pet.birthDate;
  const first = birth && birth > EARLIEST_WEIGHT_DATE ? birth : EARLIEST_WEIGHT_DATE;
  return first > today ? today : first;
}

/** The change of the weight at `index` of a log (newest first) from the one before it, in grams; null for the oldest. */
export function changeAt(log: readonly { weightKg: number }[], index: number): number | null {
  const weight = log[index];
  const before = log[index + 1];
  return weight && before ? grams(weight.weightKg) - grams(before.weightKg) : null;
}

export type WeightProblem = 'required' | 'invalid' | 'tooPrecise';

/**
 * What is wrong with a weight typed in kilograms: null when it is above 0 and up to 200 kg with at most `decimals`
 * decimals, or empty and not `required`.
 */
export function weightTextProblem(text: string, decimals: number, required: boolean): WeightProblem | null {
  if (!text.trim()) return required ? 'required' : null;
  const kg = parseDecimal(text);
  if (kg === null || kg <= 0 || kg > MAX_KG) return 'invalid';
  return typedDecimals(text) > decimals ? 'tooPrecise' : null;
}

// --- Periods ------------------------------------------------------------------------------------------------------

/** How far back the chart looks, up to today. */
export type WeightPeriod = 'threeMonths' | 'year' | 'all';
const PERIOD_MONTHS: Record<WeightPeriod, number | null> = { threeMonths: 3, year: 12, all: null };

/** The same day some months before, or that month's last day: 31 May minus three months is 28 (or 29) February. */
export function monthsBefore(date: string, months: number): string {
  const [year, month, day] = date.split('-').map(Number);
  const first = new Date(Date.UTC(year!, month! - 1 - months, 1));
  const lastDay = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate();
  return new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth(), Math.min(day!, lastDay)))
    .toISOString()
    .slice(0, 10);
}

/** The first day of a period that ends today; null for the whole log. */
export function periodStart(period: WeightPeriod, today: string): string | null {
  const months = PERIOD_MONTHS[period];
  return months === null ? null : monthsBefore(today, months);
}

/**
 * The periods to choose from for a log whose oldest weight is from `oldest`. A period that would show the same as a
 * longer one is left out, so a log of the last three months has nothing to choose (empty).
 */
export function weightPeriods(oldest: string, today: string): WeightPeriod[] {
  const shorter = (['threeMonths', 'year'] as const).filter((period) => oldest < periodStart(period, today)!);
  return shorter.length ? [...shorter, 'all'] : [];
}

/** The weights of a log in a period up to today, in the log's order. */
export function weightsIn<T extends { measuredOn: string }>(
  log: readonly T[],
  period: WeightPeriod,
  today: string,
): T[] {
  const start = periodStart(period, today);
  return start === null ? [...log] : log.filter((entry) => entry.measuredOn >= start);
}

/** The period the chart starts with: the last year when the log is longer and that year has two weights, else all. */
export function defaultPeriod(
  periods: readonly WeightPeriod[],
  log: readonly { measuredOn: string }[],
  today: string,
): WeightPeriod {
  return periods.includes('year') && weightsIn(log, 'year', today).length >= 2 ? 'year' : 'all';
}

// --- The chart ----------------------------------------------------------------------------------------------------

/** A weight on the chart: its day, its weight and whether a vet noted it. Oldest first. */
export interface ChartInput {
  measuredOn: string;
  weightKg: number;
  vet: boolean;
}

export interface ChartPoint {
  x: number;
  y: number;
  vet: boolean;
  /** Drawn with its marker: every vet's weight, and the weighings while they don't crowd into a band. */
  marked: boolean;
}

export interface ChartLayout {
  points: ChartPoint[];
  /** The lowest and the highest weight, in grams; equal when every weight is the same. */
  lowest: number;
  highest: number;
  /** Where the highest and the lowest weight are drawn; one level, in the middle, when they are equal. */
  highY: number;
  lowY: number;
  /** The first and the last day of the chart. */
  first: string;
  last: string;
}

/** The radius of a weighing's dot: dots closer than two of their widths would merge into a band. */
export const DOT_RADIUS = 4;

/**
 * Where the weights go in a box of `width` × `height` with `pad` around the plot (the markers need it): days left to
 * right in proportion, from the first weight to the last; weights bottom to top between the lowest and the highest.
 * One weight, or one day, sits in the middle; equal weights make one level in the middle.
 */
export function chartLayout(
  input: readonly ChartInput[],
  { width, height, pad }: { width: number; height: number; pad: number },
): ChartLayout {
  const weights = input.map((entry) => grams(entry.weightKg));
  const lowest = Math.min(...weights);
  const highest = Math.max(...weights);
  const flat = lowest === highest;
  const left = pad;
  const right = width - pad;
  const top = pad;
  const bottom = height - pad;
  const firstDay = input[0]?.measuredOn ?? '';
  const lastDay = input.at(-1)?.measuredOn ?? '';
  const span = days(firstDay, lastDay);
  const y = (value: number) =>
    flat ? (top + bottom) / 2 : bottom - ((bottom - top) * (value - lowest)) / (highest - lowest);
  const x = (date: string) => (span === 0 ? (left + right) / 2 : left + ((right - left) * days(firstDay, date)) / span);
  const dense = input.length > 1 && (right - left) / (input.length - 1) < 4 * DOT_RADIUS;
  return {
    points: input.map((entry, index) => ({
      x: x(entry.measuredOn),
      y: y(weights[index]!),
      vet: entry.vet,
      marked: entry.vet || !dense || index === input.length - 1,
    })),
    lowest,
    highest,
    highY: y(highest),
    lowY: y(lowest),
    first: firstDay,
    last: lastDay,
  };
}

/** Calendar days between two dates of the API. */
function days(from: string, to: string): number {
  if (!from || !to) return 0;
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}
