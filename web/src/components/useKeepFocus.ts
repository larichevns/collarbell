// Keyboard focus that would drop to the page's start when what had it goes: "Fed" turns into a spinner and then the
// mark, a bought supply or a plan marked done leaves its list, a removed file leaves its grid. Inside the container,
// the focus moves to the same place in the list (the next row, or the last), to the same kind of control (a button
// for a button: the next row's "Bought", not its name's link), else its first button or link; once there is one again
// (a spinner has none); with no row left, to `fallback` (the button that adds one) when there is one. Only when the
// element that had the focus is gone: a click elsewhere is left alone. A dialog opened from a row (the focus went into
// it) gives the focus back to that row when it closes, or, when the row went with it, here to its neighbour.
import { useEffect, useLayoutEffect, useRef, type RefObject } from 'react';

const FOCUSABLE = 'button:not([disabled]), a[href], input:not([disabled]), select:not([disabled])';

export interface KeepFocusOptions {
  /** What makes up the list: its rows ("li"), or the cards of a form ("fieldset.identifier"). */
  item?: string;
  /** With no row left: what takes the focus (the button that adds one). */
  fallback?: () => HTMLElement | null | undefined;
}

export function useKeepFocus(
  container: RefObject<HTMLElement | null>,
  { item: ITEM = 'li', fallback }: KeepFocusOptions = {},
): void {
  // What had the focus in the container, its item, and the item's place among the items.
  const last = useRef<{ element: HTMLElement; item: Element; index: number } | null>(null);

  // Heard on the document: the container may come later (once its list has loaded).
  useEffect(() => {
    const remember = (event: FocusEvent) => {
      const element = container.current;
      const target = event.target as HTMLElement;
      const item = target.closest?.(ITEM);
      if (!element || !item || !element.contains(item)) return;
      last.current = { element: target, item, index: Array.from(element.querySelectorAll(ITEM)).indexOf(item) };
    };
    const forget = (event: FocusEvent) => {
      // The focus went somewhere else (not just away with what had it, nor into a dialog that gives it back).
      const element = container.current;
      const next = event.relatedTarget as Element | null;
      if (!element || !next || element.contains(next) || !element.contains(event.target as Node)) return;
      if (next.closest?.('dialog')) return;
      last.current = null;
    };
    document.addEventListener('focusin', remember);
    document.addEventListener('focusout', forget);
    return () => {
      document.removeEventListener('focusin', remember);
      document.removeEventListener('focusout', forget);
    };
  }, [container, ITEM]);

  // After every change on screen: what had the focus is gone, and nothing else took it.
  useLayoutEffect(() => {
    const had = last.current;
    if (!had || had.element.isConnected) return;
    const active = document.activeElement;
    if (active && active !== document.body && active.isConnected) {
      last.current = null;
      return;
    }
    const items = Array.from(container.current?.querySelectorAll(ITEM) ?? []);
    const item = items[Math.min(had.index, items.length - 1)];
    const kind = had.element.tagName.toLowerCase();
    const same = FOCUSABLE.split(', ').find((selector) => selector.startsWith(kind));
    let target = same ? item?.querySelector<HTMLElement>(same) : null;
    // The same row still there (a button turned into a spinner) waits for its control to come back; another row
    // takes its first one; no row left, the fallback.
    if (!target && item !== had.item) target = item?.querySelector<HTMLElement>(FOCUSABLE);
    if (!target && items.length === 0) target = fallback?.() ?? null;
    // Nothing to take it yet (a spinner): the next change tries again.
    target?.focus();
  });
}
