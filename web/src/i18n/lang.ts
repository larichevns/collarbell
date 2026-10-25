// The app's two languages, and how a count picks its word in each: Intl.PluralRules says which form a number takes.
// English has "one" (1) and "other"; Russian "one" (1, 21, 31…), "few" (2–4, 22–24…), "many" (0, 5–20, 25–30…) and
// "other" (fractions).

export type Lang = 'en' | 'ru';

export const LANGS: readonly Lang[] = ['en', 'ru'];

/** The language of a locale such as "ru-RU" or "en"; anything not Russian is English. */
export function langOf(locale: string | null | undefined): Lang {
  return locale?.toLowerCase().startsWith('ru') ? 'ru' : 'en';
}

export interface PluralForms {
  one: string;
  few?: string;
  many?: string;
  other: string;
}

const rules: Record<Lang, Intl.PluralRules> = {
  en: new Intl.PluralRules('en'),
  ru: new Intl.PluralRules('ru'),
};

/** The form of a word for `count`: plural('ru', 3, { one: 'день', few: 'дня', many: 'дней', other: 'дня' }) → «дня». */
export function plural(lang: Lang, count: number, forms: PluralForms): string {
  const form = rules[lang].select(count);
  return (form === 'one' || form === 'few' || form === 'many' ? forms[form] : undefined) ?? forms.other;
}
