// Short messages at the bottom of the screen after something happened ("Purchase saved", "Already marked: Anna,
// 08:02"), like the phone app's snackbars: a dark strip, read out by screen readers, gone after a few seconds or on
// "Close". At most three at a time.
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useI18n } from '../i18n/i18n';
import { Icon } from './Icon';

const SHOWN_MS = 6000;
const MAX_SHOWN = 3;

type Show = (text: string) => void;

const ToastContext = createContext<{ show: Show; clear: () => void } | null>(null);

export function useToast(): Show {
  const toasts = useContext(ToastContext);
  if (!toasts) throw new Error('useToast() is only for components inside <ToastProvider>');
  return toasts.show;
}

/** Takes every message away: a sign-out leaves nothing of the person on screen. */
export function useClearToasts(): () => void {
  const toasts = useContext(ToastContext);
  if (!toasts) throw new Error('useClearToasts() is only for components inside <ToastProvider>');
  return toasts.clear;
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const [toasts, setToasts] = useState<{ id: number; text: string }[]>([]);
  const next = useRef(0);
  const timers = useRef(new Set<number>());

  const dismiss = useCallback((id: number) => setToasts((list) => list.filter((toast) => toast.id !== id)), []);

  const show = useCallback<Show>(
    (text) => {
      const id = (next.current += 1);
      setToasts((list) => [...list.slice(1 - MAX_SHOWN), { id, text }]);
      const timer = window.setTimeout(() => {
        timers.current.delete(timer);
        dismiss(id);
      }, SHOWN_MS);
      timers.current.add(timer);
    },
    [dismiss],
  );

  const clear = useCallback(() => {
    timers.current.forEach((timer) => window.clearTimeout(timer));
    timers.current.clear();
    setToasts([]);
  }, []);

  useEffect(() => {
    const pending = timers.current;
    return () => pending.forEach((timer) => window.clearTimeout(timer));
  }, []);

  const value = useMemo(() => ({ show, clear }), [show, clear]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {toasts.map((toast) => (
          <div key={toast.id} className="toast">
            <span>{toast.text}</span>
            <button type="button" className="toast-close" aria-label={t.commonClose} onClick={() => dismiss(toast.id)}>
              <Icon name="close" size={18} />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}
