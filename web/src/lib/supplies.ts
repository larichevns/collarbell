// Supplies (the phone app's supply.dart, supply_labels.dart and supply_form_screen.dart): the groups of the list, the
// units the form takes amounts in, how a daily use typed by hand is given, the stock dialogs' arithmetic, a barcode's
// check digit, and the server's limits. The estimate itself (what is left, when it runs out) is the server's (spec 5.3).
import type { Supply, SupplyCategory, SupplyRequest, SupplyUnit, SupplyUsageMode } from '../api/types';

/** The server's limits; the form checks them before saving. */
export const SUPPLY_MAX = {
  name: 100,
  brand: 100,
  notes: 500,
  url: 500,
  leadTimeDays: 60,
  /** Packages in one purchase or count, as the stock dialogs take them. */
  packages: 99,
  /** A package's size and a daily use: up to a million of the unit. */
  amount: 1_000_000,
  kcal: 10_000,
  /** "A package lasts N days": up to ten years. */
  packageLastsDays: 3650,
} as const;

/** A new item's days for delivery, as on the server. */
export const DEFAULT_LEAD_TIME_DAYS = 5;

export const SUPPLY_CATEGORIES: readonly SupplyCategory[] = [
  'DryFood',
  'WetFood',
  'Treats',
  'Litter',
  'Medication',
  'Other',
];

/** To buy now: it ran out, or it runs out within the delivery time. */
export function needsBuying(supply: Supply): boolean {
  return supply.active && (supply.forecast.status === 'BuyNow' || supply.forecast.status === 'OutOfStock');
}

export type SupplyGroup = 'toBuy' | 'soon' | 'inStock' | 'notBought';

/**
 * The list's groups, as on the phone: what to buy now, what runs out soon (to buy within a week), the rest, then the
 * items no longer bought. Each keeps the server's order (what runs out first comes first); empty ones are left out.
 */
export function groupSupplies(supplies: readonly Supply[]): [SupplyGroup, Supply[]][] {
  const soon = (supply: Supply) => supply.active && supply.forecast.status === 'Soon';
  const groups: [SupplyGroup, Supply[]][] = [
    ['toBuy', supplies.filter(needsBuying)],
    ['soon', supplies.filter(soon)],
    ['inStock', supplies.filter((supply) => supply.active && !needsBuying(supply) && !soon(supply))],
    ['notBought', supplies.filter((supply) => !supply.active)],
  ];
  return groups.filter(([, items]) => items.length > 0);
}

// --- Units ----------------------------------------------------------------------------------------------------------

/** The unit an amount is typed in: grams and kilograms, millilitres and litres are one unit to the server. */
export type InputUnit = 'gram' | 'kilogram' | 'milliliter' | 'liter' | 'piece' | 'dose';

export const INPUT_UNITS: readonly InputUnit[] = ['gram', 'kilogram', 'milliliter', 'liter', 'piece', 'dose'];

/** The unit the server counts in. */
export function storedUnit(unit: InputUnit): SupplyUnit {
  switch (unit) {
    case 'gram':
    case 'kilogram':
      return 'Gram';
    case 'milliliter':
    case 'liter':
      return 'Milliliter';
    case 'piece':
      return 'Piece';
    case 'dose':
      return 'Dose';
  }
}

/** How many of the stored unit one input unit is: a kilogram is 1000 grams. */
export function inputFactor(unit: InputUnit): number {
  return unit === 'kilogram' || unit === 'liter' ? 1000 : 1;
}

/** The input unit an amount reads best in: 2000 g as 2 kg; 400 g and 1250 g as grams. */
export function inputUnitFor(unit: SupplyUnit, amount: number): InputUnit {
  const big = amount >= 1000 && amount % 100 === 0;
  switch (unit) {
    case 'Gram':
      return big ? 'kilogram' : 'gram';
    case 'Milliliter':
      return big ? 'liter' : 'milliliter';
    case 'Piece':
      return 'piece';
    case 'Dose':
      return 'dose';
  }
}

/** The stored unit as typed: a daily use is typed in grams, not kilograms. */
export function baseInputUnit(unit: SupplyUnit): InputUnit {
  return inputUnitFor(unit, 0);
}

/** What a package of a kind is usually counted in: a bag of dry food in kilograms, a box of pouches in pieces, tablets in doses. */
export function defaultInputUnit(category: SupplyCategory): InputUnit {
  switch (category) {
    case 'DryFood':
    case 'Litter':
      return 'kilogram';
    case 'Treats':
      return 'gram';
    case 'Medication':
      return 'dose';
    case 'WetFood':
    case 'Other':
      return 'piece';
  }
}

/** Food is counted from the feedings that give it; litter, medicine and the rest by hand (the server's default too). */
export function defaultUsage(category: SupplyCategory): SupplyUsageMode {
  return category === 'DryFood' || category === 'WetFood' ? 'Feeding' : 'Manual';
}

// --- A daily use typed by hand --------------------------------------------------------------------------------------

/** How a daily use is given by hand: "a package lasts N days" (litter), or "so much a day". */
export type ManualUsage = 'packageLasts' | 'perDay';

/**
 * How a saved daily use reads best: the whole days a package lasts, when it is that, else the amount a day (four
 * significant digits). The server keeps six decimals (a package lasting 504 days is 0.001984 a day), so whole days
 * are compared with a relative tolerance.
 */
export function manualUsageOf(packageSize: number, daily: number | null): { mode: ManualUsage; value: number | null } {
  if (daily === null || !(daily > 0)) return { mode: 'packageLasts', value: null };
  const days = Math.round(packageSize / daily);
  if (days >= 1 && Math.abs(packageSize / days - daily) <= daily * 1e-3) return { mode: 'packageLasts', value: days };
  return { mode: 'perDay', value: Number(daily.toPrecision(4)) };
}

/** The daily use the server keeps: a package's size over the days it lasts, or the amount a day as typed. */
export function manualDaily(mode: ManualUsage, value: number, packageSize: number): number {
  return mode === 'packageLasts' ? packageSize / value : value;
}

// --- Purchases and counts -------------------------------------------------------------------------------------------

/**
 * Where "Correct the stock" starts: the estimate, in whole packages and tenths of an open one. A bag just bought is
 * "1 unopened", not "0, the open one at 100 %".
 */
export function countStart(remaining: number | null, packageSize: number): { packages: number; openTenths: number } {
  const tenths = Math.max(0, Math.round(((remaining ?? 0) / packageSize) * 10));
  return { packages: Math.min(Math.floor(tenths / 10), SUPPLY_MAX.packages), openTenths: tenths % 10 };
}

/** Some packages and tenths of an open one, in the item's unit (three decimals, as the server keeps it). */
export function stockQuantity(packageSize: number, packages: number, openTenths = 0): number {
  return Math.round((packageSize * (packages * 10 + openTenths) * 1000) / 10) / 1000;
}

// --- Checks ---------------------------------------------------------------------------------------------------------

/**
 * Whether the digits are a GTIN (EAN-8, UPC-A, EAN-13, GTIN-14) with a right check digit: from the right, without
 * it, the digits weigh 3, 1, 3, 1…
 */
export function isValidGtin(digits: string): boolean {
  if (!/^(?:\d{8}|\d{12,14})$/.test(digits)) return false;
  let sum = 0;
  let weight = 3;
  for (let index = digits.length - 2; index >= 0; index -= 1) {
    sum += Number(digits[index]) * weight;
    weight = 4 - weight;
  }
  return (10 - (sum % 10)) % 10 === Number(digits[digits.length - 1]);
}

/**
 * A barcode as the server keeps it (Gtin.Normalize): a UPC-A or a GTIN-14 with a 0 ahead is the EAN-13 it stands for,
 * and an EAN-8 written in 13 digits is the EAN-8.
 */
export function gtinKey(code: string): string {
  let digits = code.trim();
  if (digits.length === 12) digits = `0${digits}`;
  else if (digits.length === 14 && digits.startsWith('0')) digits = digits.slice(1);
  return digits.length === 13 && digits.startsWith('00000') ? digits.slice(5) : digits;
}

/**
 * Whether the item the server answered with says what was sent. A retry after a lost answer gets the item as the
 * first try made it: a correction typed since then goes after it (PUT).
 */
export function supplyHolds(saved: Supply, sent: SupplyRequest): boolean {
  // The server keeps a package size to 3 decimals and a daily use to 6.
  const same = (a: number | null, b: number | null, digits: number) =>
    a === null || b === null ? a === b : Math.abs(a - b) <= 0.5 / 10 ** digits + 1e-9;
  return (
    saved.name === sent.name &&
    saved.brand === sent.brand &&
    saved.barcode === (sent.barcode ? gtinKey(sent.barcode) : null) &&
    saved.category === sent.category &&
    saved.unit === sent.unit &&
    same(saved.packageSize, sent.packageSize, 3) &&
    saved.kcalPerKg === sent.kcalPerKg &&
    saved.usageMode === sent.usageMode &&
    same(saved.manualDailyUsage, sent.manualDailyUsage, 6) &&
    saved.leadTimeDays === sent.leadTimeDays &&
    saved.storeUrl === sent.storeUrl &&
    saved.notes === sent.notes
  );
}

/** A shop's address: http or https, with a host. */
export function isWebAddress(text: string): boolean {
  try {
    const url = new URL(text);
    return (url.protocol === 'http:' || url.protocol === 'https:') && url.hostname.length > 0;
  } catch {
    return false;
  }
}

/**
 * An amount as people read it: two decimals at most, fewer for big amounts (1234.5678 g is 1234.6 g), two
 * significant digits for small ones (a collar's 0.004167 a day is 0.0042, not 0).
 */
export function roundAmount(value: number): number {
  if (value >= 100) return Math.round(value * 10) / 10;
  if (value >= 1 || value === 0) return Math.round(value * 100) / 100;
  return Number(value.toPrecision(2));
}

/** An item as the server has it, to send back whole with a change (a PUT replaces the item). */
export function supplyRequestOf(supply: Supply): SupplyRequest {
  return {
    name: supply.name,
    brand: supply.brand,
    barcode: supply.barcode,
    category: supply.category,
    unit: supply.unit,
    packageSize: supply.packageSize,
    kcalPerKg: supply.kcalPerKg,
    usageMode: supply.usageMode,
    manualDailyUsage: supply.manualDailyUsage,
    leadTimeDays: supply.leadTimeDays,
    storeUrl: supply.storeUrl,
    notes: supply.notes,
    active: supply.active,
    initialStock: null,
    dataSource: null,
    requestId: null,
  };
}
