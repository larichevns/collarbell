// The app's language and its texts. English or Russian: the language picked in this browser (the switch in the
// header, kept in localStorage), else the profile's (GET /me, after sign-in), else the browser's. A link from the
// landing names the language of its page (/app/?lang=ru): with none picked here yet, it counts as picked. Pages take
// their texts and formats from useI18n(); <html lang> follows, so screen readers read Russian as Russian.
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { en, type Messages } from './en';
import { formatDate, formatMomentTime, formatNumber, formatTime, type DateStyle } from './format';
import { langOf, LANGS, type Lang } from './lang';
import { ru } from './ru';

const MESSAGES: Record<Lang, Messages> = { en, ru };

const STORAGE_KEY = 'collarbell.language';

export interface I18n {
  lang: Lang;
  t: Messages;
  /** The person picked a language: it stays in this browser, over the profile's. */
  choose: (lang: Lang) => void;
  /** The profile's language (GET /me), unless one was picked in this browser. */
  adopt: (locale: string) => void;
  /** A calendar date of the API ("2026-10-07"). */
  date: (iso: string, style?: DateStyle) => string;
  /** A time of day of the API ("08:00:00"). */
  time: (time: string) => string;
  /** The time of a moment in the household's time zone. */
  momentTime: (moment: string, timeZone: string) => string;
  number: (value: number, maximumFractionDigits?: number) => string;
}

function picked(): Lang | null {
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    return LANGS.find((lang) => lang === stored) ?? null;
  } catch {
    // Storage switched off: nothing was picked.
    return null;
  }
}

function keep(lang: Lang) {
  try {
    window.localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    // Storage switched off: the choice lasts until the page closes.
  }
}

/** The language the address asks for (?lang=ru, the landing's link from its Russian pages); null when none. */
function asked(): Lang | null {
  try {
    const wanted = new URLSearchParams(window.location.search).get('lang');
    return LANGS.find((lang) => lang === wanted) ?? null;
  } catch {
    return null;
  }
}

/** The language to start with: picked here before, else the one the link asked for (kept as picked), else none. */
export function startingLanguage(): Lang | null {
  const chosen = picked();
  if (chosen) return chosen;
  const fromLink = asked();
  if (fromLink) keep(fromLink);
  return fromLink;
}

const I18nContext = createContext<I18n | null>(null);

export function useI18n(): I18n {
  const i18n = useContext(I18nContext);
  if (!i18n) throw new Error('useI18n() is only for components inside <I18nProvider>');
  return i18n;
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLang] = useState<Lang>(() => startingLanguage() ?? langOf(window.navigator.language));

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const choose = useCallback((next: Lang) => {
    keep(next);
    setLang(next);
  }, []);

  const adopt = useCallback((locale: string) => {
    if (!picked()) setLang(langOf(locale));
  }, []);

  const i18n = useMemo<I18n>(
    () => ({
      lang,
      t: MESSAGES[lang],
      choose,
      adopt,
      date: (iso, style) => formatDate(lang, iso, style),
      time: (time) => formatTime(lang, time),
      momentTime: (moment, timeZone) => formatMomentTime(lang, moment, timeZone),
      number: (value, digits) => formatNumber(lang, value, digits),
    }),
    [lang, choose, adopt],
  );

  return <I18nContext.Provider value={i18n}>{children}</I18nContext.Provider>;
}
