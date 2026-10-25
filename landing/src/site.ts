// Site-wide settings. Every page reads them from here; change a value and rebuild.
import type { Lang } from './i18n';

/** The public address of the site, without a trailing slash. Canonical and hreflang links use it. */
export const SITE_URL = 'https://collarbell.example.com';

/**
 * The contact address for support, privacy requests and account deletion.
 * While it is empty, every place that would show it says that an address will appear soon.
 */
export const SUPPORT_EMAIL = '';

/**
 * May search engines index the site? False while it lives on the temporary hostname: every page
 * then says `noindex` and robots.txt disallows everything. Turn it on with the real domain.
 */
export const INDEXABLE = false;

/** The web app for pet owners, on this same address (built from web/, served under /app/ by deploy/nginx.conf). */
export const WEB_APP_PATH = '/app/';

/**
 * The web app, opened in the page's language: it takes it as its own unless a language was picked in it before on
 * that browser (web/src/i18n/i18n.tsx).
 */
export function webAppHref(lang: Lang): string {
  return `${WEB_APP_PATH}?lang=${lang}`;
}
