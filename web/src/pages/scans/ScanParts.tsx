// Pieces the scan pages share: when a scan or note was made, a note quoted as it was written, a scan's photos as tiles
// that open large, and the uploads and start of a scan with what went wrong.
import { Link } from 'react-router';
import { useState } from 'react';
import { isPdf } from '../../api/files';
import type { FileLink } from '../../api/types';
import { FileTile, LocalFileTile, UploadProgress } from '../../components/Files';
import { Icon } from '../../components/Icon';
import { PageViewer } from '../../components/PageViewer';
import { Notice, Spinner } from '../../components/ui';
import { useHousehold } from '../../household/household';
import { useI18n, type I18n } from '../../i18n/i18n';
import { todayIn } from '../../lib/dates';
import type { StartFailure } from './start';

/** When something happened, in the household's time zone: "Oct 6, 2026, 2:05 PM". */
export function momentLabel(i18n: I18n, moment: string, timeZone: string): string {
  const at = new Date(moment);
  if (Number.isNaN(at.getTime())) return moment;
  return i18n.t.dateWithTime(i18n.date(todayIn(timeZone, at)), i18n.momentTime(moment, timeZone));
}

/**
 * A note as the person wrote it, quoted where a scan shows its photos: while AI reads it, when it failed, and on the
 * review, to check the entries against. With when it was written: what its "yesterday" means.
 */
export function NoteQuote({ text, writtenAt }: { text: string; writtenAt?: string | null }) {
  const i18n = useI18n();
  const { current } = useHousehold();
  return (
    <figure className="note-quote">
      {writtenAt && (
        <figcaption className="small muted">
          {i18n.t.noteWrittenAt(momentLabel(i18n, writtenAt, current.timeZone))}
        </figcaption>
      )}
      <blockquote className="pre-line">{i18n.t.scanEvidence(text)}</blockquote>
    </figure>
  );
}

/** A scan's photos on the server, as tiles; a photo opens large, with the others. */
export function StoredPages({ pages }: { pages: readonly FileLink[] }) {
  const { t } = useI18n();
  const [viewing, setViewing] = useState<string | null>(null);
  if (!pages.length) return null;
  return (
    <>
      <ul className="file-grid">
        {pages.map((page, index) => (
          <FileTile key={page.id} file={page} label={t.pageNumber(index + 1)} onOpen={() => setViewing(page.id)} />
        ))}
      </ul>
      {viewing && (
        <PageViewer pages={pages.filter((page) => !isPdf(page))} startAt={viewing} onClose={() => setViewing(null)} />
      )}
    </>
  );
}

/** Photos picked on this computer, in page order, each with its preview; removable until they are sent. */
export function PickedPages({
  photos,
  onRemove,
}: {
  photos: readonly { file: File; preview: string }[];
  onRemove?: (index: number) => void;
}) {
  const { t } = useI18n();
  if (!photos.length) return null;
  return (
    <ul className="file-grid">
      {photos.map((photo, index) => (
        <LocalFileTile
          key={photo.preview}
          file={photo.file}
          preview={photo.preview}
          label={t.pageNumber(index + 1)}
          onRemove={onRemove ? () => onRemove(index) : undefined}
          removeLabel={t.scanPageRemove(index + 1)}
        />
      ))}
    </ul>
  );
}

/**
 * The uploads and the start of a scan or note: "Uploading 2 of 5…", then "Sending the pages to AI…"; or why it
 * failed, with "Try again" when that can help, the plan when the month's AI photos are the reason, and a way back.
 */
export function StartingStatus({
  busy,
  progress,
  sending,
  failure,
  onRetry,
  back,
}: {
  busy: boolean;
  progress: { done: number; total: number } | null;
  /** "Sending the pages to AI…" or "Sending the note to AI…". */
  sending: string;
  failure: StartFailure | null;
  onRetry: () => void;
  /** "Change the photos" or the like: back to choosing. */
  back?: { label: string; onClick: () => void };
}) {
  const { t } = useI18n();
  if (busy) {
    return progress && progress.done < progress.total ? (
      <UploadProgress done={progress.done} total={progress.total} />
    ) : (
      <p className="loading-inline" role="status">
        <Spinner />
        {sending}
      </p>
    );
  }
  if (!failure) return null;
  return (
    <Notice tone="danger">
      <p>{failure.message}</p>
      {failure.aiLimit && <Link to="/settings">{t.aiSeePlan}</Link>}
      <div className="notice-actions">
        {!failure.dead && (
          <button type="button" className="button button--secondary" onClick={onRetry}>
            <Icon name="refresh" size={18} />
            {t.commonTryAgain}
          </button>
        )}
        {back && (
          <button type="button" className="button button--ghost" onClick={back.onClick}>
            {back.label}
          </button>
        )}
      </div>
    </Notice>
  );
}
