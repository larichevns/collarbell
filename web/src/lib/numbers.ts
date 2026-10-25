// Numbers as people type them: with a point or a comma ("4.2", «4,2»), which may start or end them while typing
// ("4,", ",5"). Checked on the text, not on the parsed number: as a double, 2.2 × 1000 isn't exactly 2200.
import type { Lang } from '../i18n/lang';

const TYPED = /^(?:\d+(?:[.,](\d*))?|[.,](\d+))$/;

/** "4,25" or "4.25" → 4.25; null when the text isn't a number ("1e2", "NaN" and "4,2,1" aren't). */
export function parseDecimal(text: string): number | null {
  const trimmed = text.trim();
  if (!TYPED.test(trimmed)) return null;
  const value = Number(trimmed.replace(',', '.'));
  return Number.isFinite(value) ? value : null;
}

/** How many decimals were typed, zeros at the end not counted: "4,250" has 2 (it is 4.25). */
export function typedDecimals(text: string): number {
  const match = TYPED.exec(text.trim());
  if (!match) return 0;
  return (match[1] ?? match[2] ?? '').replace(/0+$/, '').length;
}

/** A number for a text field, with the language's separator and no grouping: 4.25 → «4,25», 1234.5 → "1234.5". */
export function decimalText(lang: Lang, value: number): string {
  const text = String(value);
  return lang === 'ru' ? text.replace('.', ',') : text;
}
