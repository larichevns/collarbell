// The theme: the system's, or light or dark whatever the system says. Picked in Settings and remembered in this
// browser (the phone app has its own). The colours are the design tokens' (styles/tokens.css: light, and dark under
// prefers-color-scheme); styles/theme.css repeats each set under data-theme on <html>, which a pick sets. The page's
// start (index.html) sets it before the first paint too, so a dark pick doesn't flash white.
import { useSyncExternalStore } from 'react';

export type Theme = 'system' | 'light' | 'dark';

export const THEMES: readonly Theme[] = ['system', 'light', 'dark'];

/** Where the pick is kept; index.html reads the same key. */
const STORAGE_KEY = 'collarbell.theme';

/** The theme picked in this browser: "system" when none was (or storage is switched off). */
export function storedTheme(): Theme {
  try {
    const value = window.localStorage.getItem(STORAGE_KEY);
    return value === 'light' || value === 'dark' ? value : 'system';
  } catch {
    return 'system';
  }
}

/** Shows a theme: data-theme on <html> for a pick, none for the system's. The browser's own bar follows the page. */
export function applyTheme(theme: Theme): void {
  const root = document.documentElement;
  if (theme === 'system') delete root.dataset.theme;
  else root.dataset.theme = theme;
  const paper = getComputedStyle(root).getPropertyValue('--paper').trim();
  for (const meta of document.querySelectorAll<HTMLMetaElement>('meta[name="theme-color"]')) {
    // Each tag says the colour for the system's light or dark (its media); a pick says the same in both.
    meta.dataset.system ??= meta.content;
    meta.content = theme !== 'system' && paper ? paper : meta.dataset.system;
  }
}

const listeners = new Set<() => void>();

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  // Picked in another tab of this browser: this one follows.
  const changed = (event: StorageEvent) => {
    if (event.key !== STORAGE_KEY && event.key !== null) return;
    applyTheme(storedTheme());
    listener();
  };
  window.addEventListener('storage', changed);
  return () => {
    listeners.delete(listener);
    window.removeEventListener('storage', changed);
  };
}

/** A pick that couldn't be kept (storage switched off): it still shows until the page closes. */
let picked: Theme | null = null;

/** Picks a theme: kept in this browser (the system's is kept as no pick) and shown at once. */
export function chooseTheme(theme: Theme): void {
  try {
    if (theme === 'system') window.localStorage.removeItem(STORAGE_KEY);
    else window.localStorage.setItem(STORAGE_KEY, theme);
    picked = null;
  } catch {
    picked = theme;
  }
  applyTheme(theme);
  listeners.forEach((listener) => listener());
}

function current(): Theme {
  return picked ?? storedTheme();
}

/** The theme picked here, and how to pick another. */
export function useTheme(): [Theme, (theme: Theme) => void] {
  return [useSyncExternalStore(subscribe, current), chooseTheme];
}
