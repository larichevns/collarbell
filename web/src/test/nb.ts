// The Russian texts keep a short word or a number with the word after it by a no-break space (U+00A0, put there by
// tools/typograph.py), so a line never ends with "в" or "2". Tests write that space as "~", as TeX does:
// nb('Через~2~дня') is «Через 2 дня» with both spaces unbreakable.
export const nb = (text: string): string => text.replaceAll('~', ' ');
