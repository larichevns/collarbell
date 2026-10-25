// Dialogs: the browser's own <dialog>, opened with showModal(), so the page behind is out of reach, Esc closes it and
// focus starts inside. Shown while mounted: a page renders {open && <Dialog …/>}. When it goes, focus goes back to
// what opened it. A click outside doesn't close it: what was typed in it would be lost. Inside: DialogBody, and
// DialogFoot for the buttons; DialogForm around both makes Enter in a field submit.
//
// A dialog with typed input (`changed`) asks "Leave without saving?" before Esc, "Close" or a "Cancel" inside
// (useDialogClose) throw it away, and before a link or Back leaves the page; while it saves that input, a link or Back
// waits for the answer instead (and goes on once the dialog has closed). While it saves (`busy`) it stays: should the
// browser close it all the same (a second Esc can't always be stopped), it opens again, so the answer is seen.
import {
  createContext,
  useCallback,
  useContext,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type KeyboardEvent,
  type ReactNode,
} from 'react';
import { useI18n } from '../i18n/i18n';
import { Icon } from './Icon';
import { useLeaveGuard } from './LeaveGuard';
import { Spinner } from './ui';

/** Closes the dialog around: after asking first when it has typed input. For the "Cancel" buttons inside. */
const DialogCloseContext = createContext<(() => void) | null>(null);

export function useDialogClose(): () => void {
  const close = useContext(DialogCloseContext);
  if (!close) throw new Error('useDialogClose() is only for content inside <Dialog>');
  return close;
}

export function Dialog({
  title,
  onClose,
  busy = false,
  changed = false,
  wide = false,
  onKeyDown,
  children,
}: {
  title: ReactNode;
  onClose: () => void;
  /** While saving, Esc and "Close" don't close it: the answer is still to come. */
  busy?: boolean;
  /** Something was typed: closing asks first. */
  changed?: boolean;
  /** For a form with many fields, or pages to look at: as wide as the screen allows. */
  wide?: boolean;
  onKeyDown?: (event: KeyboardEvent<HTMLDialogElement>) => void;
  children: ReactNode;
}) {
  const { t } = useI18n();
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const [asking, setAsking] = useState(false);
  // A link or Back while it is open: the frame asks first (typed input), or waits while that input is being saved. A
  // dialog without typed input holds nothing back: a page moves on once its question was answered (deleting a pet goes
  // on to the list).
  useLeaveGuard(changed, busy && changed);

  // The latest props, for the browser's events.
  const latest = useRef({ busy, onClose });
  useLayoutEffect(() => {
    latest.current = { busy, onClose };
  });

  useLayoutEffect(() => {
    const dialog = ref.current!;
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    let leaving = false;
    // The browser closed it on its own: open it again while it saves, else it is closed for good.
    const closed = () => {
      // Open again by now: the event is an earlier close's (React's development mode mounts twice, and the browser
      // fires "close" a moment after close()), not the browser's.
      if (leaving || dialog.open) return;
      if (latest.current.busy) dialog.showModal();
      else latest.current.onClose();
    };
    dialog.addEventListener('close', closed);
    dialog.showModal();
    return () => {
      leaving = true;
      dialog.removeEventListener('close', closed);
      dialog.close();
      opener?.focus();
    };
  }, []);

  const close = useCallback(() => {
    if (busy) return;
    if (changed) setAsking(true);
    else onClose();
  }, [busy, changed, onClose]);

  return (
    <dialog
      ref={ref}
      className={`dialog${wide ? ' dialog--wide' : ''}`}
      aria-labelledby={titleId}
      onKeyDown={onKeyDown}
      onCancel={(event) => {
        // Esc: the page decides, so a dialog that is saving stays, and one with typed input asks first.
        event.preventDefault();
        if (event.target === event.currentTarget) close();
      }}
    >
      <div className="dialog-head">
        <h2 className="dialog-title" id={titleId}>
          {title}
        </h2>
        <button type="button" className="icon-button" aria-label={t.commonClose} onClick={close} disabled={busy}>
          <Icon name="close" />
        </button>
      </div>
      <DialogCloseContext.Provider value={close}>{children}</DialogCloseContext.Provider>
      {asking && (
        <ConfirmDialog
          title={t.leaveTitle}
          body={t.leaveBody}
          confirmLabel={t.leaveConfirm}
          danger
          onConfirm={() => {
            setAsking(false);
            onClose();
          }}
          onCancel={() => setAsking(false)}
        />
      )}
    </dialog>
  );
}

export function DialogBody({ children }: { children: ReactNode }) {
  return <div className="dialog-body">{children}</div>;
}

export function DialogFoot({ children }: { children: ReactNode }) {
  return <div className="dialog-foot">{children}</div>;
}

export function DialogForm({ onSubmit, busy, children }: { onSubmit: () => void; busy: boolean; children: ReactNode }) {
  return (
    <form
      className="dialog-form"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        if (!busy) onSubmit();
      }}
    >
      {children}
    </form>
  );
}

/** "Cancel" in a dialog's foot: closes it, after asking when something was typed. */
export function DialogCancel({ disabled = false }: { disabled?: boolean }) {
  const { t } = useI18n();
  const close = useDialogClose();
  return (
    <button type="button" className="button button--ghost" onClick={close} disabled={disabled}>
      {t.commonCancel}
    </button>
  );
}

/** "Delete Murka?" with the consequence, "Cancel", and the action in its own words. */
export function ConfirmDialog({
  title,
  body,
  confirmLabel,
  danger = false,
  busy = false,
  error,
  onConfirm,
  onCancel,
}: {
  title: string;
  body?: string;
  confirmLabel: string;
  danger?: boolean;
  busy?: boolean;
  /** Why the action failed, under the text. */
  error?: ReactNode;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const { t } = useI18n();
  return (
    <Dialog title={title} onClose={onCancel} busy={busy}>
      {(body || error) && (
        <DialogBody>
          {body && <p>{body}</p>}
          {error}
        </DialogBody>
      )}
      <DialogFoot>
        <button type="button" className="button button--ghost" onClick={onCancel} disabled={busy}>
          {t.commonCancel}
        </button>
        <button
          type="button"
          className={`button ${danger ? 'button--danger' : 'button--primary'}`}
          onClick={onConfirm}
          disabled={busy}
        >
          {busy && <Spinner />}
          {confirmLabel}
        </button>
      </DialogFoot>
    </Dialog>
  );
}
