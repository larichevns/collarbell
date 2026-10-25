// A scan or a note started before (/pets/:id/scans/:scanId; the phone app's scan_screen.dart once started): while AI
// reads it, the wait (asked about every two seconds, sooner when the live updates say it changed), with its photos or
// its text; then the draft to check (ScanReview); or why it failed, with "Try again" (its photos or text read anew) and
// "Dismiss"; or that it was saved (what it saved) or discarded. The waiting cards on the Passport tab (scans) and the
// Health tab (notes) open it.
//
// The review opens only from the scan as read since the page opened: a copy kept from before may be a scan saved or
// thrown away since (here, before going Back to it; on another device while live updates were off), and saving a
// saved scan again saves nothing (the server answers with the first result). Saved or thrown away elsewhere while
// it is checked here, the page shows it so.
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { isNotFound } from '../../api/errors';
import { isReading, useAiImport, useCarePlans, usePassport, usePet } from '../../api/queries';
import type { AiImport, Pet } from '../../api/types';
import { Icon } from '../../components/Icon';
import { ErrorNotice, Loading, Notice, PageHead, Spinner } from '../../components/ui';
import { useI18n } from '../../i18n/i18n';
import { petTabPath } from '../pets/PetPage';
import {
  canReadAgain,
  isNote,
  scanAgainPath,
  scanErrorMessage,
  scanResultSummary,
  scanStatusLabel,
  scanTitle,
} from './labels';
import { NoteQuote, StoredPages } from './ScanParts';
import { ScanReview, type ScanSaved } from './ScanReview';

/** After a minute and a half of reading, the page says that it takes longer than usual. */
const SLOW_AFTER_MS = 90_000;

export function ScanPage() {
  const { id: petId = '', scanId = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(petId);
  const scan = useAiImport(scanId);
  // The ready scan the review opened with: it stays while the person checks it, whatever reads of it, still ready,
  // come meanwhile.
  const [reviewing, setReviewing] = useState<AiImport | null>(null);
  const [saved, setSaved] = useState<ScanSaved | null>(null);
  // When this page started waiting: a note read again keeps the day it was written, which says nothing of the wait.
  const [waitingSince] = useState(() => Date.now());
  const shown = scan.data;
  // The scan as the server answered since the page opened, and no read of it under way or failed since.
  const fresh = scan.isFetchedAfterMount && !scan.isFetching && !scan.isError;
  if (fresh && shown && !saved) {
    if (shown.status === 'Ready' && !reviewing) setReviewing(shown);
    // Saved or thrown away elsewhere while it was checked here: nothing more can be saved from it.
    else if (shown.status !== 'Ready' && reviewing) setReviewing(null);
  }

  if (!pet.data || isNotFound(pet.error)) {
    return (
      <>
        <PageHead back={{ to: '/pets', label: t.petsTitle }} title={t.petsTitle} />
        {pet.error ? <ErrorNotice error={pet.error} onRetry={() => void pet.refetch()} /> : <Loading />}
      </>
    );
  }
  const owner = pet.data;
  if (saved && shown) return <Saved pet={owner} scan={shown} saved={saved} />;
  if (reviewing) {
    return (
      <ReviewLoader
        pet={owner}
        scan={reviewing}
        onSaved={setSaved}
        onReload={async () => {
          const fresh = await scan.refetch();
          if (fresh.error) throw fresh.error;
          if (fresh.data?.status === 'Ready') return true;
          // Saved or discarded elsewhere: what it is now.
          setReviewing(null);
          return false;
        }}
      />
    );
  }
  if (isNotFound(scan.error)) return <Gone pet={owner} note={!!shown && isNote(shown)} />;
  // Not read yet, or ready only in a copy from before: what it is now comes first.
  if (!shown || shown.status === 'Ready') {
    const note = !!shown && isNote(shown);
    return (
      <>
        <PageHead
          back={{ to: petTabPath(owner.id, note ? 'health' : 'passport'), label: owner.name }}
          title={shown ? scanTitle(t, shown.source) : t.scanTitlePassport}
        />
        {scan.error && !scan.isFetching ? (
          <ErrorNotice error={scan.error} onRetry={() => void scan.refetch()} />
        ) : (
          <Loading />
        )}
      </>
    );
  }
  return <ScanStatus pet={owner} scan={shown} offline={!!scan.error} waitingSince={waitingSince} />;
}

/** The pet, its plans and its passport, read afresh for the review; then the review. */
function ReviewLoader({
  pet,
  scan,
  onSaved,
  onReload,
}: {
  pet: Pet;
  scan: AiImport;
  onSaved: (saved: ScanSaved) => void;
  onReload: () => Promise<boolean>;
}) {
  const { t } = useI18n();
  // Fetched afresh for the review: the pet's species decides the vaccine targets offered, its plans which "Done" a
  // record can be, its passport header what the scanned details would change, its birth date a weighing's first day.
  const fresh = usePet(pet.id);
  const plans = useCarePlans(pet.id);
  const passport = usePassport(pet.id);
  const queries = [fresh, plans, passport];
  // A read that failed counts as fetched too: what failed shows (with "Try again") until it is read again.
  const error = queries.find((query) => query.isError && !query.isFetching)?.error;
  const ready = queries.every((query) => query.isSuccess && query.isFetchedAfterMount);
  const note = isNote(scan);
  if (ready && fresh.data && plans.data && passport.data) {
    return (
      <ScanReview
        scan={scan}
        pet={fresh.data}
        plans={plans.data}
        passport={passport.data}
        onSaved={onSaved}
        onReload={onReload}
      />
    );
  }
  return (
    <>
      <PageHead
        back={{ to: petTabPath(pet.id, note ? 'health' : 'passport'), label: pet.name }}
        title={note ? t.noteReviewTitle : t.scanReviewTitle}
      />
      {error ? (
        <ErrorNotice
          error={error}
          onRetry={() => queries.forEach((query) => void query.refetch())}
        />
      ) : (
        <Loading />
      )}
    </>
  );
}

/** A scan being read, failed, saved or discarded; `waitingSince`: when this page started waiting for it. */
function ScanStatus({
  pet,
  scan,
  offline,
  waitingSince,
}: {
  pet: Pet;
  scan: AiImport;
  offline: boolean;
  waitingSince: number;
}) {
  const { t } = useI18n();
  const note = isNote(scan);
  const tab = note ? 'health' : 'passport';
  const back = { to: petTabPath(pet.id, tab), label: pet.name };
  const head = <PageHead back={back} caption={pet.name} title={scanTitle(t, scan.source)} />;
  const toTab = (
    <Link to={back.to} className="button button--secondary">
      {note ? t.scanToHealth : t.scanToPassport}
    </Link>
  );
  const source = note ? scan.text && <NoteQuote text={scan.text} /> : <StoredPages pages={scan.pages} />;

  if (isReading(scan)) {
    return (
      <>
        {head}
        <div className="scan-status" aria-live="polite">
          <p className="scan-status-title with-icon">
            <Spinner />
            {/* Waiting in the queue usually takes a moment: both read as "Reading the pages…". */}
            {scanStatusLabel(t, 'Processing', note)}
          </p>
          <p className="muted">{note ? t.noteReadingBody : t.scanReadingBody}</p>
          {offline ? (
            <Notice tone="warning">{t.scanReadingOffline}</Notice>
          ) : (
            // Asked every two seconds: each answer draws this again. Counted from when this page started waiting,
            // never from before the scan was made.
            Date.now() - Math.max(waitingSince, Date.parse(scan.createdAt) || 0) >= SLOW_AFTER_MS && (
              <Notice tone="warning">{t.scanReadingSlow}</Notice>
            )
          )}
          <Notice>{note ? t.noteReadingLeave : t.scanReadingLeave}</Notice>
          {source}
        </div>
      </>
    );
  }
  if (scan.status === 'Failed') {
    const photosGone = !note && (scan.error === 'PhotosMissing' || scan.pages.length === 0);
    const again = `/pets/${pet.id}/${note ? 'note' : 'scan'}?again=${scan.id}&from=${tab}`;
    return (
      <>
        {head}
        <div className="scan-status">
          <p className="scan-status-title with-icon danger-text">
            <Icon name="error" />
            {scanStatusLabel(t, scan.status)}
          </p>
          <p>{photosGone ? t.scanErrorPhotosMissing : scanErrorMessage(t, scan.error, note)}</p>
          <div className="scan-status-actions">
            {canReadAgain(scan) ? (
              <Link to={again} className="button button--primary">
                <Icon name="refresh" />
                {t.commonTryAgain}
              </Link>
            ) : (
              photosGone && (
                <Link to={scanAgainPath(pet.id, scan, tab)} className="button button--primary">
                  {t.scanStartOver}
                </Link>
              )
            )}
            {toTab}
          </div>
          {source}
        </div>
      </>
    );
  }
  // Saved (here, on another device, or before), or discarded.
  const applied = scan.status === 'Applied';
  return (
    <>
      {head}
      <div className="scan-status">
        <p className="scan-status-title with-icon">
          <Icon name={applied ? 'check_circle' : 'delete'} className={applied ? 'ok-icon' : undefined} />
          {scanStatusLabel(t, scan.status)}
        </p>
        <p>
          {applied
            ? scanResultSummary(t, scan.result ?? emptyResult(), scan.source)
            : note
              ? t.noteDiscardedBody
              : t.scanDiscardedBody}
        </p>
        <div className="scan-status-actions">
          {applied && scan.result?.documentId && (
            <Link to={`/pets/${pet.id}/documents/${scan.result.documentId}`} className="button button--secondary">
              {t.scanOpenDocument}
            </Link>
          )}
          {toTab}
        </div>
      </div>
    </>
  );
}

/** What saving did, said on the page the review was on. */
function Saved({ pet, scan, saved }: { pet: Pet; scan: AiImport; saved: ScanSaved }) {
  const { t } = useI18n();
  const note = isNote(scan);
  return (
    <>
      <PageHead
        back={{ to: petTabPath(pet.id, note ? 'health' : 'passport'), label: pet.name }}
        caption={pet.name}
        title={scanTitle(t, scan.source)}
      />
      <div className="scan-status" role="status">
        <p className="scan-status-title with-icon">
          <Icon name="check_circle" className="ok-icon" />
          {t.scanStatus.Applied}
        </p>
        <p>{saved.summary}</p>
        <div className="scan-status-actions">
          <Link to={petTabPath(pet.id, 'health')} className="button button--secondary">
            {t.scanToHealth}
          </Link>
          <Link to={petTabPath(pet.id, 'passport')} className="button button--secondary">
            {t.scanToPassport}
          </Link>
          {saved.documentId && (
            <Link to={`/pets/${pet.id}/documents/${saved.documentId}`} className="button button--secondary">
              {t.scanOpenDocument}
            </Link>
          )}
        </div>
      </div>
    </>
  );
}

function Gone({ pet, note }: { pet: Pet; note: boolean }) {
  const { t } = useI18n();
  const tab = petTabPath(pet.id, note ? 'health' : 'passport');
  return (
    <>
      <PageHead back={{ to: tab, label: pet.name }} title={note ? t.noteTitle : t.scanTitlePassport} />
      <Notice tone="warning">
        <p>{note ? t.noteGone : t.scanGone}</p>
        <Link to={tab} className="button button--secondary">
          {note ? t.scanToHealth : t.scanToPassport}
        </Link>
      </Notice>
    </>
  );
}

function emptyResult() {
  return { recordIds: [], plansMoved: 0, identifiersAdded: 0, passportUpdated: false, documentId: null, weightsAdded: 0 };
}
