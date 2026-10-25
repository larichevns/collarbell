// The weight log's rules: the chart's periods and where its points go (the lowest and the highest weight, one weight,
// equal weights, crowded dots), the change between weights, and the checks of a typed weight.
import { describe, expect, it } from 'vitest';
import { en } from '../i18n/en';
import { ru } from '../i18n/ru';
import { nb } from '../test/nb';
import { weightProblemLabel } from './labels';
import { decimalText, parseDecimal, typedDecimals } from './numbers';
import {
  chartLayout,
  changeAt,
  defaultPeriod,
  firstWeighingDate,
  monthsBefore,
  weightPeriods,
  weightsIn,
  weightTextProblem,
} from './weight';

const today = '2026-10-07';
const box = { width: 400, height: 160, pad: 10 };

describe('the periods of the chart', () => {
  it('offers a period only when the log is longer than it, and all time with them', () => {
    expect(weightPeriods('2026-08-01', today)).toEqual([]);
    expect(weightPeriods('2026-07-07', today)).toEqual([]);
    expect(weightPeriods('2026-07-06', today)).toEqual(['threeMonths', 'all']);
    expect(weightPeriods('2025-10-07', today)).toEqual(['threeMonths', 'all']);
    expect(weightPeriods('2025-10-06', today)).toEqual(['threeMonths', 'year', 'all']);
  });

  it('opens a long log on its last year, when that year has two weights', () => {
    const periods = weightPeriods('2024-01-01', today);
    const log = [{ measuredOn: '2026-09-01' }, { measuredOn: '2026-03-01' }, { measuredOn: '2024-01-01' }];
    expect(defaultPeriod(periods, log, today)).toBe('year');
    expect(defaultPeriod(periods, [log[0]!, log[2]!], today)).toBe('all');
    expect(defaultPeriod(weightPeriods('2026-01-01', today), log, today)).toBe('all');
    expect(weightsIn(log, 'threeMonths', today)).toEqual([log[0]]);
    expect(weightsIn(log, 'all', today)).toEqual(log);
  });

  it("counts months back on the calendar: 31 May minus three months is February's last day", () => {
    expect(monthsBefore('2026-05-31', 3)).toBe('2026-02-28');
    expect(monthsBefore('2028-05-31', 3)).toBe('2028-02-29');
    expect(monthsBefore('2026-10-07', 12)).toBe('2025-10-07');
  });
});

describe('the chart', () => {
  it('spreads the days in proportion and puts the lowest weight at the bottom, the highest at the top', () => {
    const layout = chartLayout(
      [
        { measuredOn: '2026-01-01', weightKg: 4, vet: false },
        { measuredOn: '2026-01-11', weightKg: 4.5, vet: true },
        { measuredOn: '2026-01-31', weightKg: 4.25, vet: false },
      ],
      box,
    );
    expect(layout.lowest).toBe(4000);
    expect(layout.highest).toBe(4500);
    expect(layout.points.map((point) => point.x)).toEqual([10, 10 + (380 * 10) / 30, 390]);
    expect(layout.points.map((point) => point.y)).toEqual([150, 10, 80]);
    expect(layout.highY).toBe(10);
    expect(layout.lowY).toBe(150);
    expect(layout.points.map((point) => point.vet)).toEqual([false, true, false]);
    expect(layout.points.every((point) => point.marked)).toBe(true);
    expect([layout.first, layout.last]).toEqual(['2026-01-01', '2026-01-31']);
  });

  it('puts one weight in the middle', () => {
    const layout = chartLayout([{ measuredOn: '2026-01-01', weightKg: 4.2, vet: false }], box);
    expect(layout.points).toEqual([{ x: 200, y: 80, vet: false, marked: true }]);
    expect(layout.lowest).toBe(layout.highest);
    expect(layout.first).toBe(layout.last);
  });

  it('draws equal weights as one level in the middle', () => {
    const layout = chartLayout(
      [
        { measuredOn: '2026-01-01', weightKg: 4.2, vet: false },
        { measuredOn: '2026-03-01', weightKg: 4.2, vet: false },
      ],
      box,
    );
    expect(layout.points.map((point) => point.y)).toEqual([80, 80]);
    expect(layout.highY).toBe(layout.lowY);
  });

  it('weighs in whole grams: 4.3 and 4.1 are 200 g apart, not 199.999…', () => {
    const layout = chartLayout(
      [
        { measuredOn: '2026-01-01', weightKg: 4.1, vet: false },
        { measuredOn: '2026-02-01', weightKg: 4.3, vet: false },
      ],
      box,
    );
    expect(layout.highest - layout.lowest).toBe(200);
  });

  it('keeps only the last dot when the dots would crowd into a band; a vet weight is always marked', () => {
    const many = Array.from({ length: 60 }, (_, day) => ({
      measuredOn: `2026-01-${String((day % 28) + 1).padStart(2, '0')}`,
      weightKg: 4 + day / 100,
      vet: day === 30,
    })).sort((a, b) => a.measuredOn.localeCompare(b.measuredOn));
    const layout = chartLayout(many, box);
    const marked = layout.points.filter((point) => point.marked);
    expect(marked.length).toBe(2);
    expect(layout.points.at(-1)!.marked).toBe(true);
    expect(marked.some((point) => point.vet)).toBe(true);
  });
});

describe('a typed weight', () => {
  it('takes a point or a comma, to the gram, above 0 and up to 200 kg', () => {
    expect(weightTextProblem('4,2', 3, true)).toBeNull();
    expect(weightTextProblem('4.235', 3, true)).toBeNull();
    expect(weightTextProblem(',5', 3, true)).toBeNull();
    // Zeros at the end say nothing more: 4.2500 is 4.25.
    expect(weightTextProblem('4.2500', 3, true)).toBeNull();
    expect(weightTextProblem('4.2355', 3, true)).toBe('tooPrecise');
    expect(weightTextProblem('4.235', 2, false)).toBe('tooPrecise');
    expect(weightTextProblem('', 3, true)).toBe('required');
    expect(weightTextProblem('  ', 3, false)).toBeNull();
    expect(weightTextProblem('0', 3, true)).toBe('invalid');
    expect(weightTextProblem('200.001', 3, true)).toBe('invalid');
    expect(weightTextProblem('1e2', 3, true)).toBe('invalid');
    expect(weightTextProblem('4,2,1', 3, true)).toBe('invalid');
    expect(weightProblemLabel(en, 'tooPrecise', 3)).toBe('Use 3 decimals at most');
    expect(weightProblemLabel(ru, 'tooPrecise', 2)).toBe(nb('Не~больше 2~знаков после запятой'));
  });

  it('reads and writes numbers as people type them', () => {
    expect(parseDecimal('4,25')).toBe(4.25);
    expect(parseDecimal(' 4.25 ')).toBe(4.25);
    expect(parseDecimal('4,')).toBe(4);
    expect(parseDecimal('abc')).toBeNull();
    expect(typedDecimals('4,250')).toBe(2);
    expect(decimalText('ru', 4.25)).toBe('4,25');
    expect(decimalText('en', 4.25)).toBe('4.25');
  });
});

describe('the log', () => {
  it('says the change from the weight before, in grams', () => {
    const log = [{ weightKg: 4.3 }, { weightKg: 4.1 }, { weightKg: 4.1 }];
    expect(changeAt(log, 0)).toBe(200);
    expect(changeAt(log, 1)).toBe(0);
    expect(changeAt(log, 2)).toBeNull();
  });

  it('starts at an exact birth date; an approximate one says nothing for sure', () => {
    expect(firstWeighingDate({ birthDate: '2024-03-01', birthDateApproximate: false }, today)).toBe('2024-03-01');
    expect(firstWeighingDate({ birthDate: '2024-03-01', birthDateApproximate: true }, today)).toBe('1990-01-01');
    expect(firstWeighingDate({ birthDate: null, birthDateApproximate: false }, today)).toBe('1990-01-01');
    expect(firstWeighingDate({ birthDate: '2026-12-01', birthDateApproximate: false }, today)).toBe(today);
  });
});
