// The passport header's rules (the phone app's passport.dart), checked in the form so mistakes show before saving;
// the server checks the same.
import type { PassportModel } from '../api/types';

export const PASSPORT_MODELS: readonly PassportModel[] = ['Eu2014', 'Eu2026', 'Other'];

/** Up to two owners, as in section I of the paper passport. */
export const MAX_OWNERS = 2;

/** The server's limits. */
export const PASSPORT_MAX = { notes: 2000, name: 100, address: 300, phone: 40, email: 320 } as const;

/** Letters, digits, hyphens and slashes, up to 30, after normalizePassportNumber. */
const NUMBER = /^[A-Z0-9/-]{1,30}$/;
/** A two-letter country code (ISO 3166-1), e.g. DE. */
const COUNTRY = /^[A-Za-z]{2}$/;

/** Spaces don't count and letters are compared in upper case, as on the server: "de 123" is saved as "DE123". */
export function normalizePassportNumber(value: string): string {
  return value.replace(/\s/g, '').toUpperCase();
}

export function passportNumberOk(value: string): boolean {
  const number = normalizePassportNumber(value);
  return !number || NUMBER.test(number);
}

export function countryOk(value: string): boolean {
  const country = value.trim();
  return !country || COUNTRY.test(country);
}
