// Pages large: a document's photos, a record's, the passport's. One page at a time, as big as the screen allows, with
// "Previous" and "Next" and the arrow keys; "Page 2 of 5" is the title. Those who may change the pages can delete the
// one on screen, after a question. PDFs aren't here: they open in the browser's own viewer, in a new tab.
import { useEffect, useEffectEvent, useState } from 'react';
import { errorMessage } from '../api/errors';
import type { FileLink } from '../api/types';
import { useI18n } from '../i18n/i18n';
import { ConfirmDialog, Dialog, DialogBody, DialogFoot } from './Dialog';
import { FileImage } from './Files';
import { Icon } from './Icon';
import { Notice } from './ui';

export function PageViewer({
  pages,
  startAt,
  onClose,
  onDelete,
  deleteBody,
}: {
  /** Photos only, in order. The list may change while open (a page deleted): the viewer stays on its page. */
  pages: readonly FileLink[];
  /** The id of the page to start with. */
  startAt: string;
  onClose: () => void;
  /** Deletes the page on screen; null for those who only look. */
  onDelete?: ((page: FileLink) => Promise<void>) | null;
  /** What deleting the page on screen does ("The document will be deleted too" for its last page). */
  deleteBody?: (page: FileLink) => string;
}) {
  const { t } = useI18n();
  const [currentId, setCurrentId] = useState(startAt);
  const [asking, setAsking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);

  // The page on screen, or the nearest one when it went away; none left (deleted elsewhere): the viewer closes.
  const found = pages.findIndex((page) => page.id === currentId);
  const index = found >= 0 ? found : 0;
  const page = pages[index];
  const close = useEffectEvent(onClose);
  const empty = !page;
  useEffect(() => {
    if (empty) close();
  }, [empty]);
  if (!page) return null;
  const go = (step: number) => {
    const next = pages[index + step];
    if (next) setCurrentId(next.id);
  };

  async function remove(target: FileLink) {
    if (!onDelete) return;
    setBusy(true);
    setFailure(null);
    try {
      // The page after it takes its place; after the last one, the page before.
      const neighbour = pages[index + 1] ?? pages[index - 1];
      await onDelete(target);
      setAsking(false);
      if (neighbour) setCurrentId(neighbour.id);
      else onClose();
    } catch (error) {
      setFailure(error);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      title={t.pageOf(index + 1, pages.length)}
      onClose={onClose}
      wide
      onKeyDown={(event) => {
        // Arrows turn the pages, unless a button inside wants them (it doesn't) or a question is open.
        if (asking) return;
        if (event.key === 'ArrowRight') {
          event.preventDefault();
          go(1);
        } else if (event.key === 'ArrowLeft') {
          event.preventDefault();
          go(-1);
        }
      }}
    >
      <DialogBody>
        <div className="viewer">
          <FileImage
            key={page.id}
            file={page}
            thumbnail={false}
            alt={t.pageNumber(index + 1)}
            className="viewer-image"
          />
        </div>
        {pages.length > 1 && <p className="field-hint viewer-hint">{t.pageViewerHint}</p>}
      </DialogBody>
      <DialogFoot>
        {onDelete && (
          <button
            type="button"
            className="button button--ghost button--danger-text viewer-delete"
            onClick={() => setAsking(true)}
            disabled={busy}
          >
            <Icon name="delete" />
            {t.pageDelete}
          </button>
        )}
        <button type="button" className="button button--secondary" onClick={() => go(-1)} disabled={index === 0}>
          <Icon name="chevron_left" />
          {t.pagePrevious}
        </button>
        <button
          type="button"
          className="button button--secondary"
          onClick={() => go(1)}
          disabled={index === pages.length - 1}
        >
          {t.pageNext}
          <Icon name="chevron_right" />
        </button>
      </DialogFoot>
      {asking && (
        <ConfirmDialog
          title={t.pageDeleteTitle}
          body={deleteBody ? deleteBody(page) : t.pageDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={busy}
          error={failure ? <Notice tone="danger">{errorMessage(t, failure)}</Notice> : null}
          onConfirm={() => void remove(page)}
          onCancel={() => {
            setAsking(false);
            setFailure(null);
          }}
        />
      )}
    </Dialog>
  );
}
