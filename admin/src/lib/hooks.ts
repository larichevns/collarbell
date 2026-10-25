// Small React helpers: loading data from the API, the current time for "5 мин назад", and a delayed value for search.
import { useCallback, useEffect, useState, type DependencyList } from 'react';

export interface Resource<T> {
  /** The last answer; kept while a newer one loads (no flashing on refresh). */
  data: T | undefined;
  /** The last error; cleared by the next answer. */
  error: unknown;
  loading: boolean;
  /** Ask again (the "Обновить" button, the overview's timer). */
  reload: () => void;
  /** Change the data in place, from a change's own answer (the plan card), without asking again. */
  update: (change: (data: T) => T) => void;
}

/**
 * Loads data and loads it again when `deps` change or on reload(). A request that is no longer needed (the page was
 * closed, the search changed) is cancelled, and its answer is ignored.
 */
export function useResource<T>(load: (signal: AbortSignal) => Promise<T>, deps: DependencyList): Resource<T> {
  const [state, setState] = useState<{ data: T | undefined; error: unknown; loading: boolean }>({
    data: undefined,
    error: undefined,
    loading: true,
  });
  const [version, setVersion] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setState((previous) => (previous.loading ? previous : { ...previous, loading: true }));
    load(controller.signal).then(
      (data) => {
        if (!controller.signal.aborted) setState({ data, error: undefined, loading: false });
      },
      (error: unknown) => {
        if (!controller.signal.aborted) setState((previous) => ({ data: previous.data, error, loading: false }));
      },
    );
    return () => controller.abort();
    // The caller lists what `load` depends on, as with useEffect.
  }, [...deps, version]);

  const reload = useCallback(() => setVersion((value) => value + 1), []);
  const update = useCallback(
    (change: (data: T) => T) =>
      setState((previous) => (previous.data === undefined ? previous : { ...previous, data: change(previous.data) })),
    [],
  );
  return { ...state, reload, update };
}

/** The current time, renewed every `everyMs`, so relative times («5 мин назад») stay true on an open page. */
export function useNow(everyMs = 30_000): Date {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), everyMs);
    return () => window.clearInterval(timer);
  }, [everyMs]);
  return now;
}

/** A value that follows another one after a pause (the search box asks the server after typing stops). */
export function useDebounced<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timer);
  }, [value, delayMs]);
  return debounced;
}
