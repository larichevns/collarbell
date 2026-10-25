// The server's rules for microchip and tattoo codes (spec, appendix A.7), as the phone app repeats them
// (mobile/lib/features/pets/identifier_rules.dart): the pet form explains a mistake before saving, and the server
// checks the same rules.
import type { IdentifierType } from '../api/types';

export const MAX_IDENTIFIERS = 5;
export const MAX_RAW_LENGTH = 40;
export const MAX_TATTOO_LENGTH = 20;
export const MAX_LOCATION_LENGTH = 60;

export type IdentifierProblem =
  | 'empty'
  /** Longer than MAX_RAW_LENGTH as typed. */
  | 'tooLong'
  /** An ISO chip without exactly 15 digits. */
  | 'isoLength'
  /** An ISO number starting with 999: those belong to test chips. */
  | 'isoTestChip'
  /** Neither 10 characters 0–9/A–F nor 9 digits (AVID). */
  | 'legacyFormat'
  /** No letters and digits, or more than MAX_TATTOO_LENGTH. */
  | 'tattooLength'
  /** The same code is already in the list. */
  | 'duplicate';

const SEPARATORS = /[\s\-.*]/g;
const ISO_CHIP = /^[0-9]{15}$/;
const LEGACY_CHIP = /^(?:[0-9A-F]{10}|[0-9]{9})$/;

/** Upper case without spaces, hyphens, dots and asterisks: "276 098-100.123*456" → "276098100123456". */
export function normalizeCode(raw: string): string {
  return raw.replace(SEPARATORS, '').toUpperCase();
}

/** What is wrong with `raw` for `type`, or null when it fits. `otherCodes`: the normalized codes above it. */
export function identifierProblem(
  type: IdentifierType,
  raw: string,
  otherCodes: readonly string[] = [],
): IdentifierProblem | null {
  const trimmed = raw.trim();
  if (!trimmed) return 'empty';
  if (trimmed.length > MAX_RAW_LENGTH) return 'tooLong';
  const code = normalizeCode(trimmed);
  if (type === 'IsoChip' && !ISO_CHIP.test(code)) return 'isoLength';
  if (type === 'IsoChip' && code.startsWith('999')) return 'isoTestChip';
  if (type === 'LegacyChip' && !LEGACY_CHIP.test(code)) return 'legacyFormat';
  if (type === 'Tattoo' && (!code || code.length > MAX_TATTOO_LENGTH)) return 'tattooLength';
  return otherCodes.includes(code) ? 'duplicate' : null;
}

/** An ISO number in groups of three, as passports print it: "276 098 100 123 456". Other codes stay as they are. */
export function displayCode(type: IdentifierType, code: string): string {
  if (type !== 'IsoChip' || !ISO_CHIP.test(code)) return code;
  return code.replace(/(\d{3})(?=\d)/g, '$1 ');
}
