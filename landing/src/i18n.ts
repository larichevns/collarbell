// Languages, page addresses and the words every page shares (header, footer, contact block).
// Page texts live in the pages themselves: src/pages/*.astro (English) and src/pages/ru/*.astro (Russian);
// the home page's texts are in src/components/Home.astro.
import { getAbsoluteLocaleUrl, getRelativeLocaleUrl } from 'astro:i18n';

export const LANGS = ['en', 'ru'] as const;
export type Lang = (typeof LANGS)[number];

/** Each page and its path after the language prefix: English at /privacy/, Russian at /ru/privacy/. */
export const PAGES = {
  home: '',
  privacy: 'privacy',
  terms: 'terms',
  deleteAccount: 'delete-account',
  support: 'support',
} as const;
export type PageKey = keyof typeof PAGES;

/** The page's address in a language, e.g. /ru/privacy/. */
export function pageHref(lang: Lang, page: PageKey): string {
  return getRelativeLocaleUrl(lang, PAGES[page]);
}

/** The page's full address, for canonical and hreflang links. */
export function pageUrl(lang: Lang, page: PageKey): string {
  return getAbsoluteLocaleUrl(lang, PAGES[page]);
}

export function otherLang(lang: Lang): Lang {
  return lang === 'en' ? 'ru' : 'en';
}

/** Each language's name in itself, for the language switch. */
export const LANG_NAMES: Record<Lang, string> = { en: 'English', ru: 'Русский' };

/** Open Graph locale codes. */
export const OG_LOCALES: Record<Lang, string> = { en: 'en_US', ru: 'ru_RU' };

/** When the privacy policy and the terms of use take effect. Change it with every new version of them. */
export const LEGAL_EFFECTIVE: Record<Lang, string> = {
  en: 'Effective date: 6 October 2026',
  ru: 'Действует с 6 октября 2026 года',
};

export const UI = {
  en: {
    skipLink: 'Skip to content',
    mainNav: 'Main',
    footerNav: 'Site pages',
    support: 'Support',
    webVersion: 'Web version',
    privacy: 'Privacy policy',
    terms: 'Terms of use',
    deleteAccount: 'Delete your account',
    tagline: 'A care tracker for cats and dogs. In early testing.',
    contactLabel: 'E-mail',
    contactSoon: 'A contact address will appear here soon.',
  },
  ru: {
    skipLink: 'К содержанию',
    mainNav: 'Основное меню',
    footerNav: 'Страницы сайта',
    support: 'Поддержка',
    webVersion: 'Веб-версия',
    privacy: 'Политика конфиденциальности',
    terms: 'Условия использования',
    deleteAccount: 'Удаление аккаунта',
    tagline: 'Забота о кошках и собаках по расписанию. Сейчас на раннем тестировании.',
    contactLabel: 'Почта',
    contactSoon: 'Адрес для связи появится здесь в ближайшее время.',
  },
} as const satisfies Record<Lang, Record<string, string>>;
