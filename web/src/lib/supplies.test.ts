// Supplies' rules: the list's groups, the units the form types in, a daily use by hand, the stock dialogs' sums, the
// barcode's check digit, and the words for an item's stock; and the pretend server's estimate (the server's way).
import { describe, expect, it } from 'vitest';
import type { Supply, SupplyForecast } from '../api/types';
import { en } from '../i18n/en';
import { formatDate, formatNumber } from '../i18n/format';
import type { I18n } from '../i18n/i18n';
import { ru } from '../i18n/ru';
import { nb } from '../test/nb';
import { forecastOf, stockEntry, supply } from '../test/server';
import { stockEntryLabel, supplyAmountLabel, supplyPackagesLabel, supplyStatusLine, supplyStatusTone } from './labels';
import {
  countStart,
  groupSupplies,
  gtinKey,
  inputFactor,
  inputUnitFor,
  isValidGtin,
  manualDaily,
  manualUsageOf,
  needsBuying,
  roundAmount,
  stockQuantity,
  storedUnit,
  supplyHolds,
  supplyRequestOf,
} from './supplies';

const english = {
  lang: 'en',
  t: en,
  date: (iso: string, style?: Parameters<typeof formatDate>[2]) => formatDate('en', iso, style),
  number: (value: number, digits?: number) => formatNumber('en', value, digits),
} as unknown as I18n;
const russian = {
  lang: 'ru',
  t: ru,
  date: (iso: string, style?: Parameters<typeof formatDate>[2]) => formatDate('ru', iso, style),
  number: (value: number, digits?: number) => formatNumber('ru', value, digits),
} as unknown as I18n;

const forecast = (change: Partial<SupplyForecast>): SupplyForecast => ({
  remaining: null,
  usagePerDay: null,
  daysLeft: null,
  runsOutOn: null,
  buyBy: null,
  status: 'NoStock',
  countedFrom: null,
  ...change,
});

const item = (id: string, change: Partial<Supply>) => supply(id, { name: id, ...change });

describe('the supplies list', () => {
  it('groups as the phone does: to buy, running out soon, in stock, no longer bought; in the server order', () => {
    const list = [
      item('ran-out', { forecast: forecast({ status: 'OutOfStock', remaining: 0 }) }),
      item('buy-now', { forecast: forecast({ status: 'BuyNow', daysLeft: 2.5 }) }),
      item('soon', { forecast: forecast({ status: 'Soon', daysLeft: 9 }) }),
      item('no-stock', {}),
      item('no-usage', { forecast: forecast({ status: 'NoUsage', remaining: 300 }) }),
      item('enough', { forecast: forecast({ status: 'Enough', daysLeft: 40 }) }),
      // No longer bought: even "to buy" isn't to buy.
      item('old', { active: false, forecast: forecast({ status: 'BuyNow', daysLeft: 1 }) }),
    ];
    expect(groupSupplies(list).map(([group, items]) => [group, items.map((each) => each.id)])).toEqual([
      ['toBuy', ['ran-out', 'buy-now']],
      ['soon', ['soon']],
      ['inStock', ['no-stock', 'no-usage', 'enough']],
      ['notBought', ['old']],
    ]);
    expect(needsBuying(list[6]!)).toBe(false);
    expect(groupSupplies([item('enough', { forecast: forecast({ status: 'Enough', daysLeft: 40 }) })])).toHaveLength(1);
  });

  it("says each one's estimate, as the phone does", () => {
    const line = (change: Partial<Supply>) => supplyStatusLine(english, item('x', change));
    expect(line({ forecast: forecast({ status: 'OutOfStock', remaining: 0 }) })).toBe('Ran out');
    expect(line({ forecast: forecast({ status: 'BuyNow', daysLeft: 2.5 }) })).toBe(
      'Time to buy · enough for about 2 days',
    );
    expect(line({ forecast: forecast({ status: 'BuyNow', daysLeft: 0.4 }) })).toBe(
      'Time to buy · enough for less than a day',
    );
    expect(line({ forecast: forecast({ status: 'Soon', daysLeft: 6.2, buyBy: '2026-10-09' }) })).toBe(
      'Buy by Oct 9 · enough for about 6 days',
    );
    expect(line({ forecast: forecast({ status: 'Enough', daysLeft: 1 }) })).toBe('Enough for about 1 day');
    expect(line({ unit: 'Gram', forecast: forecast({ status: 'NoUsage', remaining: 1500 }) })).toBe(
      '1.5 kg left · daily use not set',
    );
    expect(line({ forecast: forecast({ status: 'NoStock' }) })).toBe('Stock not entered');
    expect(line({ active: false, forecast: forecast({ status: 'Enough', daysLeft: 9 }) })).toBe('No longer bought');
    expect(
      supplyStatusLine(
        russian,
        item('x', { forecast: forecast({ status: 'Soon', daysLeft: 22, buyBy: '2026-10-09' }) }),
      ),
    ).toBe(nb('Купить до~9~окт. · хватит примерно на~22~дня'));
    // Red only when it ran out, yellow when it's time to buy.
    expect(supplyStatusTone(item('x', { forecast: forecast({ status: 'OutOfStock' }) }))).toBe('danger');
    expect(supplyStatusTone(item('x', { forecast: forecast({ status: 'BuyNow' }) }))).toBe('warning');
    expect(supplyStatusTone(item('x', { forecast: forecast({ status: 'Soon' }) }))).toBe('muted');
  });

  it('writes amounts in kilograms and litres from a thousand up', () => {
    expect(supplyAmountLabel(english, 'Gram', 2000)).toBe('2 kg');
    expect(supplyAmountLabel(english, 'Gram', 400)).toBe('400 g');
    expect(supplyAmountLabel(english, 'Gram', 1234.5678)).toBe('1.23 kg');
    expect(supplyAmountLabel(english, 'Milliliter', 1500)).toBe('1.5 l');
    expect(supplyAmountLabel(english, 'Piece', 12)).toBe('12 pcs');
    expect(supplyAmountLabel(english, 'Dose', 3)).toBe('3 doses');
    expect(supplyAmountLabel(english, 'Dose', 0.044444)).toBe('0.044 doses');
    expect(supplyAmountLabel(russian, 'Gram', 2500)).toBe(nb('2,5~кг'));
    expect(supplyAmountLabel(russian, 'Dose', 2)).toBe(nb('2~дозы'));
    expect(supplyPackagesLabel(english, 0.1)).toBe('≈ 0.1 pkg');
    expect(stockEntryLabel(english, 'Gram', { kind: 'Purchase', quantity: 4000 })).toBe('Bought +4 kg');
    expect(stockEntryLabel(english, 'Gram', { kind: 'Adjustment', quantity: 150 })).toBe('Left: 150 g');
    expect(roundAmount(0.004167)).toBe(0.0042);
    expect(roundAmount(123.456)).toBe(123.5);
  });
});

describe('the item form', () => {
  it('keeps kilograms and litres in grams and millilitres, and shows a size in the unit it reads best in', () => {
    expect([storedUnit('kilogram'), inputFactor('kilogram')]).toEqual(['Gram', 1000]);
    expect([storedUnit('liter'), inputFactor('liter')]).toEqual(['Milliliter', 1000]);
    expect([storedUnit('dose'), inputFactor('dose')]).toEqual(['Dose', 1]);
    expect(inputUnitFor('Gram', 2000)).toBe('kilogram');
    expect(inputUnitFor('Gram', 1250)).toBe('gram');
    expect(inputUnitFor('Gram', 400)).toBe('gram');
    expect(inputUnitFor('Milliliter', 1500)).toBe('liter');
    expect(inputUnitFor('Piece', 2000)).toBe('piece');
  });

  it('turns "a package lasts N days" into a daily use and back, whole days within the server\'s rounding', () => {
    expect(manualDaily('packageLasts', 30, 10_000)).toBeCloseTo(333.3333, 3);
    expect(manualDaily('perDay', 50, 10_000)).toBe(50);
    // The server keeps six decimals: 504 days is 0.001984 a day.
    expect(manualUsageOf(1, 0.001984)).toEqual({ mode: 'packageLasts', value: 504 });
    expect(manualUsageOf(10_000, 333.333333)).toEqual({ mode: 'packageLasts', value: 30 });
    expect(manualUsageOf(2000, 45)).toEqual({ mode: 'perDay', value: 45 });
    expect(manualUsageOf(2000, null)).toEqual({ mode: 'packageLasts', value: null });
  });

  it('checks a barcode by its check digit', () => {
    expect(isValidGtin('4600699503415')).toBe(true);
    expect(isValidGtin('4600699503410')).toBe(false);
    expect(isValidGtin('036000291452')).toBe(true);
    expect(isValidGtin('96385074')).toBe(true);
    expect(isValidGtin('12345')).toBe(false);
    expect(isValidGtin('46006995034150')).toBe(false);
  });

  it('keeps a barcode as the server does: a UPC-A, a GTIN-14 and an EAN-8 in 13 digits as their EAN', () => {
    expect(gtinKey('036000291452')).toBe('0036000291452');
    expect(gtinKey('04600699503415')).toBe('4600699503415');
    expect(gtinKey('0000096385074')).toBe('96385074');
    expect(gtinKey(' 4600699503415 ')).toBe('4600699503415');
  });

  it("tells whether the item a retry got says what was sent, within the server's rounding", () => {
    const saved = item('a', {
      name: 'Purina One',
      barcode: '0036000291452',
      packageSize: 333.333,
      usageMode: 'Manual',
      manualDailyUsage: 47.619048,
    });
    const sent = {
      ...supplyRequestOf(saved),
      barcode: '036000291452',
      packageSize: 333.3333,
      manualDailyUsage: 1000 / 21,
    };
    expect(supplyHolds(saved, sent)).toBe(true);
    expect(supplyHolds(saved, { ...sent, name: 'Purina Pro' })).toBe(false);
    expect(supplyHolds(saved, { ...sent, packageSize: 333.5 })).toBe(false);
    expect(supplyHolds(saved, { ...sent, leadTimeDays: 7 })).toBe(false);
    expect(supplyHolds(saved, { ...sent, barcode: null })).toBe(false);
  });
});

describe('purchases and counts', () => {
  it('starts a count from the estimate, by whole packages and tenths of the open one', () => {
    expect(countStart(200, 2000)).toEqual({ packages: 0, openTenths: 1 });
    expect(countStart(2000, 2000)).toEqual({ packages: 1, openTenths: 0 });
    expect(countStart(5300, 2000)).toEqual({ packages: 2, openTenths: 7 });
    expect(countStart(null, 2000)).toEqual({ packages: 0, openTenths: 0 });
    expect(stockQuantity(2000, 1, 5)).toBe(3000);
    expect(stockQuantity(60, 2)).toBe(120);
    expect(stockQuantity(250, 0, 3)).toBe(75);
  });

  it('estimates as the server does: from the last count, purchases added, never below empty', () => {
    const now = new Date('2026-10-07T09:00:00Z');
    const at = (daysAgo: number) => new Date(now.getTime() - daysAgo * 86_400_000).toISOString();
    const entry = (kind: 'Purchase' | 'Adjustment', quantity: number, daysAgo: number) => ({
      ...stockEntry('x', kind, quantity),
      at: at(daysAgo),
    });
    // 2 kg counted 10 days ago at 100 g a day, 1 kg bought 5 days ago: 1 kg + 1 kg left, 20 days.
    const counted = forecastOf([entry('Adjustment', 2000, 10), entry('Purchase', 1000, 5)], 100, 5, now, 'UTC');
    expect(counted).toMatchObject({ remaining: 2000, daysLeft: 20, runsOutOn: '2026-10-27', buyBy: '2026-10-22' });
    expect(counted.status).toBe('Enough');
    // A bag bought after the old one ran out starts full.
    const refilled = forecastOf([entry('Purchase', 500, 20), entry('Purchase', 2000, 1)], 100, 5, now, 'UTC');
    expect(refilled).toMatchObject({ remaining: 1900, status: 'Enough' });
    expect(forecastOf([entry('Purchase', 600, 1)], 100, 5, now, 'UTC').status).toBe('BuyNow');
    expect(forecastOf([entry('Purchase', 1100, 0)], 100, 5, now, 'UTC').status).toBe('Soon');
    expect(forecastOf([entry('Purchase', 100, 2)], 100, 5, now, 'UTC').status).toBe('OutOfStock');
    expect(forecastOf([entry('Purchase', 100, 2)], null, 5, now, 'UTC')).toMatchObject({
      status: 'NoUsage',
      remaining: 100,
    });
    expect(forecastOf([], 100, 5, now, 'UTC').status).toBe('NoStock');
  });
});

describe("amounts after part 3's review", () => {
  it('says doses that round to a whole number as whole doses', () => {
    // The server keeps 3 decimals: 1.004 doses, 4.998 doses.
    expect(supplyAmountLabel(english, 'Dose', 1.004)).toBe('1 dose');
    expect(supplyAmountLabel(russian, 'Dose', 4.998)).toBe(nb('5~доз'));
    expect(supplyAmountLabel(english, 'Dose', 2.5)).toBe('2.5 doses');
  });

  it('starts a count from the estimate and sums packages to 3 decimals', () => {
    expect(countStart(2250, 1500)).toEqual({ packages: 1, openTenths: 5 });
    expect(stockQuantity(0.125, 1, 5)).toBe(0.188);
    expect(stockQuantity(2000, 2)).toBe(4000);
  });
});
