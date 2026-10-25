// The scans and notes waiting for someone, where they belong (the phone app's scan_entry.dart): on the Passport tab
// the photo scans (being read, ready to check, or failed) and, when the server has AI, "Scan passport pages"; on the
// Health tab the notes, where they are written. A card opens the scan; a failed one says why, with "Try again" (its
// photos or text read anew, in its place) and "Dismiss" (a note after asking: its text goes with it). Only for those
// who change things: helpers don't scan. The cards are a shortcut: when the list can't load they are left out, and
// the scans wait on the server.
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { errorMessage, isNotFound } from '../../api/errors';
import { cacheScan, refreshImports, useAiStatus, usePetImports } from '../../api/queries';
import type { AiImport, Pet } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { Icon } from '../../components/Icon';
import { useToast } from '../../components/Toasts';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { canReadAgain, isNote, scanAgainPath, scanErrorMessage, scanStatusLabel } from './labels';
import { momentLabel } from './ScanParts';

/** The scans the person still has to deal with: ready to check, being read, or failed. */
function waiting(scans: readonly AiImport[], notes: boolean): AiImport[] {
  return scans.filter(
    (scan) =>
      isNote(scan) === notes &&
      (scan.status === 'Ready' || scan.status === 'Queued' || scan.status === 'Processing' || scan.status === 'Failed'),
  );
}

/** The top of the Passport tab: the photo scans waiting, and "Scan passport pages" when the server has AI. */
export function ScanEntry({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const status = useAiStatus();
  const scans = usePetImports(pet.id, 'scans');
  const configured = status.data?.configured ?? false;
  const open = waiting(scans.data ?? [], false);
  if (!configured && open.length === 0) return null;
  return (
    <div className="scan-entry">
      {open.map((scan) =>
        scan.status === 'Failed' ? (
          <FailedCard key={scan.id} pet={pet} scan={scan} />
        ) : (
          <ResumeCard key={scan.id} pet={pet} scan={scan} />
        ),
      )}
      {configured && (
        <div className="card scan-card">
          <span className="kind-icon" aria-hidden="true">
            <Icon name="document_scanner" />
          </span>
          <div className="scan-card-text">
            <h3 className="row-title">{t.scanCardTitle}</h3>
            <p className="row-sub">{t.scanCardBody}</p>
          </div>
          <Link to={`/pets/${pet.id}/scan?from=passport`} className="button button--secondary">
            <Icon name="document_scanner" size={18} />
            {t.scanCardButton}
          </Link>
        </div>
      )}
    </div>
  );
}

/** The notes waiting on the Health tab, where they were written; nothing when there are none. */
export function NoteEntry({ pet }: { pet: Pet }) {
  const notes = usePetImports(pet.id, 'notes');
  const open = waiting(notes.data ?? [], true);
  if (!open.length) return null;
  return (
    <div className="scan-entry">
      {open.map((note) =>
        note.status === 'Failed' ? (
          <FailedCard key={note.id} pet={pet} scan={note} />
        ) : (
          <ResumeCard key={note.id} pet={pet} scan={note} />
        ),
      )}
    </div>
  );
}

/** The start of a note on its card, quoted on two lines at most, to tell notes apart. */
function NoteLine({ scan }: { scan: AiImport }) {
  const { t } = useI18n();
  if (!isNote(scan) || !scan.text) return null;
  return <span className="row-sub note-line">{t.scanEvidence(scan.text)}</span>;
}

/** A scan (or a note) to pick up again: ready to check, or still being read. */
function ResumeCard({ pet, scan }: { pet: Pet; scan: AiImport }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { current } = useHousehold();
  const when = momentLabel(i18n, scan.createdAt, current.timeZone);
  const ready = scan.status === 'Ready';
  const note = isNote(scan);
  const title = note
    ? ready
      ? t.noteResumeReady(when)
      : t.noteResumeOpen(when)
    : ready
      ? t.scanResumeReady(when)
      : t.scanResumeOpen(when);
  return (
    <div className="card card--list">
      <div className="row">
        <span className={`kind-icon${ready ? '' : ' kind-icon--muted'}`} aria-hidden="true">
          <Icon name={ready ? 'check_circle' : 'schedule'} />
        </span>
        <div className="row-main">
          <span className={`row-sub${ready ? ' ok-text' : ''}`}>{scanStatusLabel(t, scan.status, note)}</span>
          <Link to={`/pets/${pet.id}/scans/${scan.id}`} className="row-title row-link">
            {title}
          </Link>
          <NoteLine scan={scan} />
        </div>
        <Icon name="chevron_right" className="row-arrow" />
      </div>
    </div>
  );
}

/**
 * A scan (or a note) that couldn't be read, with why. "Try again" reads its photos (or text) anew: a new scan that
 * names this one, which the server then throws away. "Dismiss" throws it away (a note after asking).
 */
function FailedCard({ pet, scan }: { pet: Pet; scan: AiImport }) {
  const i18n = useI18n();
  const { t } = i18n;
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const [asking, setAsking] = useState(false);
  const when = momentLabel(i18n, scan.createdAt, current.timeZone);
  const note = isNote(scan);
  const photosGone = !note && (scan.error === 'PhotosMissing' || scan.pages.length === 0);
  const tab = note ? 'health' : 'passport';

  async function dismiss() {
    setBusy(true);
    try {
      await api.DELETE('/api/v1/ai-imports/{id}', { params: { path: { id: scan.id } } });
      cacheScan(queryClient, current.id, scan.id, { status: 'Discarded', text: null });
    } catch (error) {
      // Gone already: what was wanted.
      if (!isNotFound(error)) toast(errorMessage(t, error));
    } finally {
      setBusy(false);
      setAsking(false);
      // Gone from the list, or as it is now on the server.
      refreshImports(queryClient, current.id);
    }
  }

  return (
    <div className="card failed-scan">
      <div className="failed-scan-head">
        <span className="kind-icon kind-icon--danger" aria-hidden="true">
          <Icon name="error" />
        </span>
        <div className="row-main">
          <span className="row-sub danger-text">{scanStatusLabel(t, scan.status)}</span>
          <span className="row-title">{note ? t.noteResumeOpen(when) : t.scanResumeOpen(when)}</span>
          <NoteLine scan={scan} />
          <span className="row-sub">{photosGone ? t.scanErrorPhotosMissing : scanErrorMessage(t, scan.error, note)}</span>
        </div>
      </div>
      <div className="failed-scan-actions">
        <button
          type="button"
          className="button button--ghost"
          disabled={busy}
          // The note's text is deleted for good: asked first, like "Discard note".
          onClick={() => (note ? setAsking(true) : void dismiss())}
        >
          {t.scanDismiss}
        </button>
        {canReadAgain(scan) ? (
          <Link
            to={`/pets/${pet.id}/${note ? 'note' : 'scan'}?again=${scan.id}&from=${tab}`}
            className="button button--secondary"
          >
            <Icon name="refresh" size={18} />
            {t.commonTryAgain}
          </Link>
        ) : (
          !note && (
            <Link to={scanAgainPath(pet.id, scan, 'passport')} className="button button--secondary">
              {t.scanStartOver}
            </Link>
          )
        )}
      </div>
      {asking && (
        <ConfirmDialog
          title={t.noteDiscardTitle}
          body={t.noteDiscardBody}
          confirmLabel={t.scanDiscardConfirm}
          danger
          busy={busy}
          onConfirm={() => void dismiss()}
          onCancel={() => setAsking(false)}
        />
      )}
    </div>
  );
}

/** The buttons of the Health tab's history that read records from a vet document or a note, when AI is set up. */
export function AiHistoryActions({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const status = useAiStatus();
  if (!status.data?.configured) return null;
  return (
    <>
      <Link to={`/pets/${pet.id}/scan?source=document&from=health`} className="button button--secondary">
        <Icon name="document_scanner" size={18} />
        {t.scanVetDocument}
      </Link>
      <Link to={`/pets/${pet.id}/note?from=health`} className="button button--secondary">
        <Icon name="edit_note" size={18} />
        {t.noteTitle}
      </Link>
    </>
  );
}
