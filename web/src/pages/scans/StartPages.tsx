// Starting a scan (photos of passport pages or a vet document) or a note (the phone app's scan_screen.dart, before
// AI reads): what will happen to it, the free tier's warning before anything is sent, then the photos picked or
// dropped (up to 10, in page order) or the note written (up to 1000 characters, with words in it). They upload and
// the server starts reading; the page of the scan opens, where it waits for AI and then shows the draft to check.
//
// "Try again" on a failed scan or note opens here with ?again=<its id>: the same photos (or text) are read anew at
// once, as a new scan that names the failed one; read again already (the page reloaded after its start, another tab),
// the scan that took its place opens instead. Leaving while the photos upload or the scan starts waits for it;
// photos picked, being prepared (an iPhone's HEIC made a JPEG) or a note typed and not sent ask first.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { refreshImports, useAiImport, useAiStatus, usePet, usePetImports } from '../../api/queries';
import type { AiImport, AiImportSource, Pet } from '../../api/types';
import { ChoiceGroup, TextField } from '../../components/fields';
import { FileDrop } from '../../components/Files';
import { Icon } from '../../components/Icon';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, Notice, PageHead, Section, Spinner } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { petTabPath, type PetTab } from '../pets/PetPage';
import {
  canReadAgain,
  isNote,
  MAX_NOTE_LENGTH,
  MAX_SCAN_PHOTOS,
  noteHasWords,
  noteLength,
  scanTitle,
  successorOf,
} from './labels';
import { AI_PHOTO_ACCEPT, preparePhotos } from './photos';
import { PickedPages, StartingStatus, StoredPages } from './ScanParts';
import { newStart, startFailure, startImport, type Start, type StartFailure } from './start';

/** A photo picked on this computer, with the address of its picture shown from memory. */
interface Photo {
  file: File;
  preview: string;
}

/** The pet the page is about, once known; a pet gone (or not loading) says so. */
function useScanPet(): { petId: string; pet: Pet | null; waiting: ReactNode } {
  const { id: petId = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(petId);
  if (pet.data && !isNotFound(pet.error)) return { petId, pet: pet.data, waiting: null };
  return {
    petId,
    pet: null,
    waiting: (
      <>
        <PageHead back={{ to: '/pets', label: t.petsTitle }} title={t.petsTitle} />
        {pet.error ? <ErrorNotice error={pet.error} onRetry={() => void pet.refetch()} /> : <Loading />}
      </>
    ),
  };
}

/** Where the page came from: the Health tab (a vet document, a note) or the Passport tab. */
function useBack(pet: Pet, fallback: PetTab): { to: string; label: string; tab: PetTab } {
  const [search] = useSearchParams();
  const tab: PetTab = search.get('from') === 'health' ? 'health' : search.get('from') === 'passport' ? 'passport' : fallback;
  return { to: petTabPath(pet.id, tab), label: pet.name, tab };
}

export function NewScanPage() {
  const { pet, waiting } = useScanPet();
  const [search] = useSearchParams();
  if (!pet) return waiting;
  return (
    <ScanStarter
      key={search.get('again') ?? 'new'}
      pet={pet}
      initialSource={search.get('source') === 'document' ? 'VetDocument' : 'PassportPages'}
      again={search.get('again')}
    />
  );
}

export function NewNotePage() {
  const { pet, waiting } = useScanPet();
  const [search] = useSearchParams();
  if (!pet) return waiting;
  return <NoteStarter key={search.get('again') ?? 'new'} pet={pet} again={search.get('again')} />;
}

/**
 * The failed scan or note `?again=` names, when it isn't failed any more: read again already, or thrown away. The
 * one that took its place (among the pet's waiting ones) opens instead; `looking` while that is being found out.
 */
function useReadAgainAlready(pet: Pet, failed: AiImport | undefined): { done: boolean; looking: boolean } {
  const navigate = useNavigate();
  const done = !!failed && failed.status !== 'Failed';
  const waiting = usePetImports(pet.id, failed && isNote(failed) ? 'notes' : 'scans', done);
  const next = done && failed && waiting.data ? successorOf(failed, waiting.data) : null;
  const nextId = next?.id ?? null;
  useEffect(() => {
    if (nextId) void navigate(`/pets/${pet.id}/scans/${nextId}`, { replace: true });
  }, [nextId, navigate, pet.id]);
  return { done, looking: done && (waiting.isPending || nextId !== null) };
}

/** What starting a scan or note needs of the page: the household it opened in, and what happens once started. */
function useStarting(pet: Pet) {
  const i18n = useI18n();
  const { current } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const stillHere = useStillHere(household);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null);
  const [failure, setFailure] = useState<StartFailure | null>(null);

  /** Starts it; true when it started (the scan's page opens). */
  async function run(start: Start, allowLeave: () => void): Promise<boolean> {
    if (busy) return false;
    setBusy(true);
    setFailure(null);
    setProgress(null);
    try {
      const scan = await startImport(api, pet.id, start, (done, total) => setProgress({ done, total }));
      refreshImports(queryClient, household);
      // The one read again gives way to it.
      if (start.retryOf) void queryClient.invalidateQueries({ queryKey: keys.aiImport(household, start.retryOf) });
      allowLeave();
      if (stillHere()) void navigate(`/pets/${pet.id}/scans/${scan.id}`, { replace: true });
      return true;
    } catch (error) {
      if (isNotFound(error)) {
        // The pet was deleted elsewhere: there is nothing to scan for.
        toast(i18n.t.careGonePet);
        allowLeave();
        if (stillHere()) void navigate('/pets');
        return false;
      }
      const failed = startFailure(i18n, error, start);
      // AI was turned off on the server meanwhile: the buttons go too.
      if (failed.notSetUp) void queryClient.invalidateQueries({ queryKey: keys.aiStatus(household) });
      setFailure(failed);
      return false;
    } finally {
      setProgress(null);
      setBusy(false);
    }
  }

  return { api, busy, progress, failure, setFailure, run };
}

function ScanStarter({ pet, initialSource, again }: { pet: Pet; initialSource: AiImportSource; again: string | null }) {
  const { t } = useI18n();
  const back = useBack(pet, initialSource === 'VetDocument' ? 'health' : 'passport');
  const status = useAiStatus();
  const failed = useAiImport(again);
  const [source, setSource] = useState<AiImportSource>(initialSource);
  const [picked, setPicked] = useState<Photo[]>([]);
  // The photos as they are now, for photos that come in before the page draws again (a HEIC made a JPEG meanwhile).
  const pickedNow = useRef<Photo[]>([]);
  // Photos dropped or picked are being prepared: the drop zone waits, and leaving asks first.
  const [preparing, setPreparing] = useState(false);
  const [tooMany, setTooMany] = useState(false);
  // The scan being started: it stays while starting fails, so "Try again" sends the same photos and request id.
  const [start, setStart] = useState<Start | null>(null);
  const starting = useStarting(pet);
  const { allowLeave } = useLeaveGuard(picked.length > 0 || preparing, starting.busy);
  const freeTier = status.data?.freeTier ?? false;

  // The pictures picked are shown from memory; their addresses go with the page (or with the photo removed).
  const previews = useRef<string[]>([]);
  useEffect(() => () => previews.current.forEach((url) => URL.revokeObjectURL(url)), []);

  // "Try again": the failed scan's photos, read anew at once, as a new scan that names it.
  const retried = useRef(false);
  const failedScan = again ? failed.data : undefined;
  const already = useReadAgainAlready(pet, failedScan);
  useEffect(() => {
    if (!failedScan || retried.current) return;
    retried.current = true;
    if (!canReadAgain(failedScan) || failedScan.source === 'Text') return;
    const retry = newStart({ source: failedScan.source, stored: failedScan.pages, retryOf: failedScan.id });
    setSource(failedScan.source);
    setStart(retry);
    void starting.run(retry, allowLeave);
  }, [failedScan, starting, allowLeave]);

  function show(photos: Photo[]) {
    pickedNow.current = photos;
    setPicked(photos);
  }

  function add(files: File[]) {
    const old = pickedNow.current;
    const room = Math.max(0, MAX_SCAN_PHOTOS - old.length);
    setTooMany(files.length > room);
    const taken = files.slice(0, room).map((file) => {
      const preview = URL.createObjectURL(file);
      previews.current.push(preview);
      return { file, preview };
    });
    show([...old, ...taken]);
  }

  function remove(index: number) {
    const old = pickedNow.current;
    const gone = old[index];
    if (gone) {
      URL.revokeObjectURL(gone.preview);
      previews.current = previews.current.filter((url) => url !== gone.preview);
    }
    setTooMany(false);
    show(old.filter((_, at) => at !== index));
  }

  function read() {
    // Never more than a scan takes, whatever came in meanwhile.
    const photos = pickedNow.current.slice(0, MAX_SCAN_PHOTOS);
    if (!photos.length || preparing) return;
    const fresh = newStart({ source, files: photos.map((photo) => photo.file) });
    setStart(fresh);
    void starting.run(fresh, allowLeave);
  }

  const title = scanTitle(t, source);
  const head = <PageHead back={back} caption={pet.name} title={title} />;
  if ((again && !failed.data) || already.looking) {
    return (
      <>
        {head}
        {failed.error ? <ErrorNotice error={failed.error} onRetry={() => void failed.refetch()} /> : <Loading />}
      </>
    );
  }
  // A scan on its way, or one that failed to start: its pages and how it goes.
  if (start) {
    return (
      <>
        {head}
        <div className="scan-start">
          <StartingStatus
            busy={starting.busy}
            progress={starting.progress}
            sending={t.scanStarting}
            failure={starting.failure}
            onRetry={() => void starting.run(start, allowLeave)}
            back={{
              label: t.scanChangePhotos,
              onClick: () => {
                setStart(null);
                starting.setFailure(null);
              },
            }}
          />
          {start.stored.length ? (
            <StoredPages pages={start.stored} />
          ) : (
            <PickedPages photos={picked.filter((photo) => start.files.includes(photo.file))} />
          )}
        </div>
      </>
    );
  }
  const gone = failedScan && failedScan.status === 'Failed' && !canReadAgain(failedScan);
  return (
    <>
      {head}
      <div className="form scan-start">
        {gone && <Notice tone="warning">{t.scanErrorPhotosMissing}</Notice>}
        {already.done && <Notice tone="warning">{t.scanReadAgainAlready}</Notice>}
        <ChoiceGroup
          label={t.scanSourceLabel}
          value={source}
          options={[
            { value: 'PassportPages' as const, label: t.scanSourcePassport },
            { value: 'VetDocument' as const, label: t.scanSourceDocument },
          ]}
          onChange={setSource}
        />
        <p>
          {source === 'PassportPages'
            ? t.scanStartPassportBody(MAX_SCAN_PHOTOS)
            : t.scanStartDocumentBody(MAX_SCAN_PHOTOS)}
        </p>
        <Notice>{t.scanStartDraftNote}</Notice>
        {freeTier && <Notice tone="warning">{t.aiFreeTierWarning}</Notice>}
        <Section title={t.scanPagesTitle}>
          <FileDrop
            buttonLabel={t.scanPhotosAdd}
            hint={t.scanPhotosDrop}
            accept={AI_PHOTO_ACCEPT}
            prepare={(files) => preparePhotos(t, files)}
            onPreparing={setPreparing}
            disabled={picked.length >= MAX_SCAN_PHOTOS}
            onFiles={add}
          >
            <PickedPages photos={picked} onRemove={remove} />
          </FileDrop>
          {tooMany && <p className="field-hint">{t.scanTooManyPages(MAX_SCAN_PHOTOS)}</p>}
        </Section>
        <div className="form-foot">
          <button
            type="button"
            className="button button--primary"
            disabled={!picked.length || preparing}
            onClick={read}
          >
            <Icon name="document_scanner" />
            {t.scanRead}
          </button>
        </div>
      </div>
    </>
  );
}

function NoteStarter({ pet, again }: { pet: Pet; again: string | null }) {
  const { t } = useI18n();
  const back = useBack(pet, 'health');
  const status = useAiStatus();
  const failed = useAiImport(again);
  const [text, setText] = useState('');
  const [submitted, setSubmitted] = useState(false);
  // The server refused the note's text (empty or too long after all).
  const [refused, setRefused] = useState(false);
  // Each text sent from this page, with its start: sending a text again (after a failure, or after trying another)
  // keeps its request id, so the server never reads the same note twice.
  const starts = useRef(new Map<string, Start>());
  // The failed note this page reads again: what is sent from here takes its place.
  const [retryOf, setRetryOf] = useState<string | null>(null);
  // The text sent last: a refusal for good (the day's notes used up, AI not set up) keeps "Read" off for that text
  // only, until another is written, or AI is set up again.
  const [sent, setSent] = useState<string | null>(null);
  const starting = useStarting(pet);
  // A failed note read again unchanged is on the server already: leaving loses nothing.
  const atRisk = text.trim() !== '' && text.trim() !== (failed.data?.text ?? '').trim();
  const { allowLeave } = useLeaveGuard(atRisk, starting.busy);
  const freeTier = status.data?.freeTier ?? false;
  const length = noteLength(text);
  const problem = !noteHasWords(text)
    ? t.noteRequired
    : length > MAX_NOTE_LENGTH
      ? t.formTooLong(MAX_NOTE_LENGTH)
      : refused
        ? t.formServerFieldError
        : null;

  function send(note: string, retry: string | null) {
    setSent(note);
    let start = starts.current.get(note);
    if (!start) {
      start = newStart({ source: 'Text', text: note, retryOf: retry });
      starts.current.set(note, start);
    }
    void starting.run(start, allowLeave);
  }

  // "Try again": the failed note's text, read anew at once, as a new note in its place.
  const retried = useRef(false);
  const failedNote = again ? failed.data : undefined;
  const already = useReadAgainAlready(pet, failedNote);
  useEffect(() => {
    if (!failedNote || retried.current) return;
    retried.current = true;
    const old = failedNote.text?.trim();
    if (failedNote.source !== 'Text' || !old || !canReadAgain(failedNote)) return;
    setText(old);
    setRetryOf(failedNote.id);
    send(old, failedNote.id);
    // Once, when the failed note has loaded.
  }, [failedNote]);

  // The server's word on the text: shown on the field until it changes.
  const failure = starting.failure;
  const stuck =
    !!failure?.dead && sent === text.trim() && !(failure.notSetUp && status.data?.configured === true);
  useEffect(() => {
    if (failure?.textRefused) {
      setRefused(true);
      setSubmitted(true);
    }
  }, [failure]);

  function read() {
    if (starting.busy) return;
    setSubmitted(true);
    setRefused(false);
    starting.setFailure(null);
    if (!noteHasWords(text) || length > MAX_NOTE_LENGTH) return;
    send(text.trim(), retryOf);
  }

  return (
    <>
      <PageHead back={back} caption={pet.name} title={t.noteTitle} />
      {(again && !failed.data) || already.looking ? (
        failed.error ? (
          <ErrorNotice error={failed.error} onRetry={() => void failed.refetch()} />
        ) : (
          <Loading />
        )
      ) : (
        <form
          className="form scan-start"
          noValidate
          aria-busy={starting.busy || undefined}
          onSubmit={(event) => {
            event.preventDefault();
            read();
          }}
        >
          {already.done && <Notice tone="warning">{t.noteReadAgainAlready}</Notice>}
          <p>{t.noteIntro}</p>
          <fieldset className="form-stack" disabled={starting.busy}>
            <div className="note-field">
              <TextField
                label={t.noteLabel}
                placeholder={t.noteHint}
                value={text}
                rows={7}
                onChange={(value) => {
                  setText(value);
                  setRefused(false);
                }}
                error={submitted ? problem : null}
              />
              {/* Said politely as it changes: "250 of 1000 characters". */}
              <p className={`field-hint note-count${length > MAX_NOTE_LENGTH ? ' danger-text' : ''}`} aria-live="polite">
                <span aria-hidden="true">{t.noteCount(length, MAX_NOTE_LENGTH)}</span>
                <span className="visually-hidden">{t.noteCountSpoken(length, MAX_NOTE_LENGTH)}</span>
              </p>
            </div>
          </fieldset>
          <Notice>{t.scanStartDraftNote}</Notice>
          {freeTier && <Notice tone="warning">{t.noteFreeTierWarning}</Notice>}
          <StartingStatus
            busy={starting.busy}
            progress={null}
            sending={t.noteStarting}
            failure={failure && !failure.textRefused ? failure : null}
            onRetry={read}
          />
          <div className="form-foot">
            {failure?.textRefused && (
              <p className="form-error" role="alert">
                <Icon name="error" size={18} />
                {failure.message}
              </p>
            )}
            <button type="submit" className="button button--primary" disabled={starting.busy || stuck}>
              {starting.busy && <Spinner />}
              <Icon name="edit_note" />
              {t.noteRead}
            </button>
          </div>
        </form>
      )}
    </>
  );
}
