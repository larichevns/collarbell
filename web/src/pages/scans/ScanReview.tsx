// Checking a scan or a note before anything is saved (spec 5.5; the phone app's scan_review_screen.dart): every entry
// AI read, with what it doubts highlighted, beside the photos it was read from (on a wide screen; under them on a
// narrow one), or beside the note quoted with when it was written. The person ticks what to save, fixes values, links
// records to the pet's plans, keeps the photos (as passport pages, or a document) or not, and saves; or discards the
// scan. AI never saves anything itself.
//
// The review is made once, from the draft and the pet as they are when it opens (pet, plans, passport, read afresh):
// a live update or a reload keeps the person's changes. Saving sends the ticked entries (POST /ai-imports/{id}/apply),
// safe to repeat: a scan saved before answers with the first result. A save whose answer got lost asks the server
// before it tries again; the server's field errors go back on the entries they name. Leaving with changes asks first;
// while it saves, leaving waits.
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { aiErrorMessage } from '../../api/aiErrors';
import { ApiError, data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { isPdf } from '../../api/files';
import { cacheScan, refreshAfterScan, refreshImports } from '../../api/queries';
import type { AiImport, ApplyImportResponse, CarePlan, Passport, Pet } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { CheckboxField } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { PageViewer } from '../../components/PageViewer';
import { useToast } from '../../components/Toasts';
import { Notice, PageHead, Section, Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { normalizeCode } from '../../lib/identifiers';
import { firstWeighingDate } from '../../lib/weight';
import { petTabPath } from '../pets/PetPage';
import { IdentifierCard, PassportCard, RecordCard, WeightCard } from './DraftCards';
import { isNote, scanDefaultTitle, scanResultSummary } from './labels';
import { IdentifierEditor, PassportEditor, PlanPicker, RecordEditor, WeightEditor } from './ScanEditors';
import { NoteQuote, StoredPages } from './ScanParts';
import {
  afterEdit,
  clearServerErrors,
  codesBefore,
  identifierProblems,
  isEmpty,
  overLimit,
  passportProblems,
  placeServerErrors,
  planChoices,
  recordProblems,
  replaceEntry,
  reviewFromDraft,
  selectedCount,
  sending,
  weightProblems,
  withPlan,
  type Review,
  type ReviewEntry,
  type ReviewIdentifier,
  type ReviewPassport,
  type ReviewRecord,
  type ReviewWeight,
} from './review';

/** What saving did, for the page that shows it next. */
export interface ScanSaved {
  summary: string;
  documentId: string | null;
}

const EMPTY_DRAFT = { records: [], identifiers: [], passport: null, weights: [] };

/** An error after which the save may have gone through with only its answer lost: no answer, or a server error. */
function mayHaveGoneThrough(error: unknown): boolean {
  return !(error instanceof ApiError) || error.status === 0 || error.status >= 500;
}

export function ScanReview({
  scan,
  pet,
  plans,
  passport,
  onSaved,
  onReload,
}: {
  /** A scan whose draft is ready. */
  scan: AiImport;
  /** The pet, its plans and its passport header, read afresh when the review opened (plans follow later reads). */
  pet: Pet;
  plans: readonly CarePlan[];
  passport: Passport;
  onSaved: (saved: ScanSaved) => void;
  /** Reads the scan again after the server said it can't be saved any more; resolves with whether it still is ready. */
  onReload: () => Promise<boolean>;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const { current } = useHousehold();
  // The household the review opened in: its save goes there, whichever household is on screen meanwhile.
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const today = useHouseholdDate();
  const note = isNote(scan);
  const tab = petTabPath(pet.id, note ? 'health' : 'passport');
  const [review, setReview] = useState<Review>(() =>
    reviewFromDraft(scan.draft ?? EMPTY_DRAFT, {
      planIds: new Set(plans.map((plan) => plan.id)),
      savedPassport: passport,
      savedCodes: pet.identifiers.map((identifier) => normalizeCode(identifier.code)),
    }),
  );
  // A note has no photos to keep.
  const [keepPhotos, setKeepPhotos] = useState(!note);
  // Something was changed here: leaving asks first.
  const [dirty, setDirty] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [busy, setBusy] = useState<'saving' | 'discarding' | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  // The last save may have gone through with its answer lost: the next one asks the server first.
  const unconfirmed = useRef(false);
  const [editing, setEditing] = useState<ReviewEntry | null>(null);
  const [choosingPlan, setChoosingPlan] = useState<ReviewRecord | null>(null);
  const [discarding, setDiscarding] = useState(false);
  const [viewing, setViewing] = useState<string | null>(null);
  const draftRef = useRef<HTMLDivElement>(null);
  const { allowLeave } = useLeaveGuard(dirty, busy !== null, note ? t.noteLeaveBody : t.scanLeaveBody);
  const stillHere = useStillHere(household);
  const first = firstWeighingDate(pet, today);
  const photos = scan.pages.filter((page) => !isPdf(page));

  /** A change of the person's: the review is redrawn, and leaving asks first from now on. */
  function change(next: (old: Review) => Review) {
    setReview(next);
    setDirty(true);
  }

  const problemsOf = (entry: ReviewEntry, of: Review = review): Record<string, string> => {
    switch (entry.entry) {
      case 'record':
        return recordProblems(t, entry, today);
      case 'identifier':
        return identifierProblems(t, entry, today, codesBefore(of, entry), overLimit(of, entry));
      case 'passport':
        return passportProblems(t, entry, today);
      case 'weight':
        return weightProblems(t, entry, today, first);
    }
  };

  /** Opens the photo of page `page` (counted from 1); null when it is gone, and for a note. */
  const openPage = (page: number): (() => void) | null => {
    const file = scan.pages[page - 1];
    return !note && file && !isPdf(file) ? () => setViewing(file.id) : null;
  };

  /** The first ticked entry with a problem takes the focus, which scrolls it into view. */
  function revealFirstProblem() {
    requestAnimationFrame(() => {
      const card = draftRef.current?.querySelector<HTMLElement>('.draft-card.is-invalid');
      card?.querySelector<HTMLElement>('input, button')?.focus();
    });
  }

  /** The scan as it is now on the server, for its page: opened again (Back), it isn't this review from before. */
  const cache = (change: Partial<AiImport>) => cacheScan(queryClient, household, scan.id, change);

  function closeAsSaved(saved: AiImport, why: string) {
    refreshAfterScan(queryClient, household, pet.id);
    allowLeave();
    const summary = scanResultSummary(t, saved.result ?? emptyResult(), saved.source);
    onSaved({ summary: `${summary} (${why})`, documentId: saved.result?.documentId ?? null });
    cache(saved);
  }

  function closeAsDiscarded() {
    refreshImports(queryClient, household);
    allowLeave();
    toast(note ? t.noteDiscarded : t.scanDiscarded);
    if (stillHere()) void navigate(tab);
    cache({ status: 'Discarded', text: null });
  }

  async function reload() {
    try {
      // Still ready after all: saving can be tried again.
      if (await onReload()) setFailure(t.errorUnknown);
    } catch (error) {
      setFailure(errorMessage(t, error));
    }
  }

  async function save() {
    if (busy) return;
    const cleared = clearServerErrors(review);
    setReview(cleared);
    setSubmitted(true);
    setFailure(null);
    const entries: ReviewEntry[] = [
      ...cleared.records,
      ...cleared.weights,
      ...cleared.identifiers,
      ...(cleared.passport ? [cleared.passport] : []),
    ];
    if (entries.some((entry) => entry.selected && Object.keys(problemsOf(entry, cleared)).length)) {
      setFailure(t.formCheckFields);
      revealFirstProblem();
      return;
    }
    // A record without a title of its own goes under its kind's name, in the language the person has now.
    const sent = sending(cleared, { keepPhotos, defaultTitle: (kind, targets) => scanDefaultTitle(t, kind, targets) });
    setBusy('saving');
    try {
      if (unconfirmed.current) {
        const now = await data(api.GET('/api/v1/ai-imports/{id}', { params: { path: { id: scan.id } } }));
        if (now.status === 'Applied') {
          closeAsSaved(now, t.scanSavedBeforeDrop);
          return;
        }
        unconfirmed.current = false;
      }
      const result = await data(
        api.POST('/api/v1/ai-imports/{id}/apply', { params: { path: { id: scan.id } }, body: sent.input }),
      );
      refreshAfterScan(queryClient, household, pet.id);
      allowLeave();
      onSaved({
        summary: scanResultSummary(t, result, scan.source, {
          passportFields: sent.passportFields,
          identifiersSent: sent.input.identifiers?.length ?? 0,
        }),
        documentId: result.documentId,
      });
      cache({ status: 'Applied', result });
    } catch (error) {
      // Part of it may have gone through: the lists read again anyway.
      refreshAfterScan(queryClient, household, pet.id);
      if (isNotFound(error)) {
        toast(note ? t.noteGone : t.scanGone);
        allowLeave();
        if (stillHere()) void navigate(tab);
        return;
      }
      if (error instanceof ApiError && error.status === 409) {
        // Not ready any more: saved or discarded elsewhere. The page shows what it is now.
        await reload();
        return;
      }
      if (mayHaveGoneThrough(error)) {
        // The save may be done with only its answer lost: the server is asked.
        let now: AiImport | null = null;
        try {
          now = await data(api.GET('/api/v1/ai-imports/{id}', { params: { path: { id: scan.id } } }));
        } catch {
          // Still no answer: the next save asks first.
        }
        if (now?.status === 'Applied') {
          closeAsSaved(now, t.scanSavedBeforeDrop);
          return;
        }
        if (now && now.status !== 'Ready') {
          await reload();
          return;
        }
        unconfirmed.current = now === null;
        setFailure(now === null ? t.scanSaveUnconfirmed : errorMessage(t, error));
        return;
      }
      const fields = fieldErrorsOf(error);
      if (Object.keys(fields).length) {
        const placed = placeServerErrors(cleared, fields, sent);
        setReview(placed.review);
        if (placed.placedAll) {
          setFailure(t.formCheckFields);
          revealFirstProblem();
          return;
        }
      }
      setFailure(aiErrorMessage(i18n, error));
    } finally {
      setBusy(null);
    }
  }

  async function discard() {
    setBusy('discarding');
    setFailure(null);
    try {
      await api.DELETE('/api/v1/ai-imports/{id}', { params: { path: { id: scan.id } } });
      closeAsDiscarded();
    } catch (error) {
      // Gone already: what was wanted.
      if (isNotFound(error)) {
        closeAsDiscarded();
        return;
      }
      // Saved meanwhile (409, perhaps by a save whose answer was lost), or the answer itself lost: the server is asked.
      let now: AiImport | null = null;
      try {
        now = await data(api.GET('/api/v1/ai-imports/{id}', { params: { path: { id: scan.id } } }));
      } catch {
        // Still no answer: said below.
      }
      if (now?.status === 'Applied') closeAsSaved(now, note ? t.noteSavedNoDiscard : t.scanSavedNoDiscard);
      else if (now?.status === 'Discarded') closeAsDiscarded();
      else setFailure(errorMessage(t, error));
    } finally {
      setBusy(null);
      setDiscarding(false);
    }
  }

  /** The editor's result in the place of the entry it was made from: ticked or unticked as it can now be saved. */
  function edited(before: ReviewEntry, after: ReviewEntry) {
    setEditing(null);
    change((old) => {
      const next = afterEdit(before, after);
      // A plan of another kind (or against other diseases) can't take this record's "Done" any more.
      if (next.entry === 'record' && next.planId !== null) {
        const planId = next.planId;
        if (!planChoices(next, plans).some((plan) => plan.id === planId)) return replaceEntry(old, withPlan(next, null));
      }
      return replaceEntry(old, next);
    });
  }

  const count = selectedCount(review);
  const photosOnly = count === 0 && keepPhotos;
  const card = {
    showProblems: submitted,
    fromNote: note,
    today,
    onChange: (entry: ReviewEntry) => change((old) => replaceEntry(old, entry)),
  };

  return (
    <>
      <PageHead
        back={{ to: tab, label: pet.name }}
        caption={pet.name}
        title={note ? t.noteReviewTitle : t.scanReviewTitle}
      />
      <Notice>
        <p>{note ? t.noteReviewIntro : t.scanReviewIntro}</p>
      </Notice>
      <div className="scan-review" aria-busy={busy !== null || undefined}>
        <div className="scan-review-draft" ref={draftRef} inert={busy !== null}>
          {isEmpty(review) && <p className="muted">{note ? t.noteNothingFound : t.scanNothingFound}</p>}
          {review.records.length > 0 && (
            <Section title={t.scanRecordsTitle}>
              <div className="draft-list">
                {review.records.map((entry) => (
                  <RecordCard
                    key={entry.draft.key}
                    {...card}
                    entry={entry}
                    plans={plans}
                    problems={problemsOf(entry)}
                    onChange={(next: ReviewRecord) => change((old) => replaceEntry(old, next))}
                    onEdit={() => setEditing(entry)}
                    onChoosePlan={() => setChoosingPlan(entry)}
                    onOpenPage={openPage(entry.draft.page)}
                  />
                ))}
              </div>
            </Section>
          )}
          {/* Right under the records: a weight repeated by a check-up is "the same as an entry above". */}
          {review.weights.length > 0 && (
            <Section title={t.scanWeightsTitle}>
              <div className="draft-list">
                {review.weights.map((entry) => (
                  <WeightCard
                    key={entry.draft.key}
                    {...card}
                    entry={entry}
                    problems={problemsOf(entry)}
                    onChange={(next: ReviewWeight) => change((old) => replaceEntry(old, next))}
                    onEdit={() => setEditing(entry)}
                    onOpenPage={openPage(entry.draft.page)}
                  />
                ))}
              </div>
            </Section>
          )}
          {review.identifiers.length > 0 && (
            <Section title={t.identifiersTitle}>
              <div className="draft-list">
                {review.identifiers.map((entry) => (
                  <IdentifierCard
                    key={entry.draft.key}
                    {...card}
                    entry={entry}
                    problems={problemsOf(entry)}
                    onChange={(next: ReviewIdentifier) => change((old) => replaceEntry(old, next))}
                    onEdit={() => setEditing(entry)}
                    onOpenPage={openPage(entry.draft.page)}
                  />
                ))}
              </div>
            </Section>
          )}
          {review.passport && (
            <Section title={t.passportTitle}>
              <PassportCard
                {...card}
                entry={review.passport}
                problems={problemsOf(review.passport)}
                onChange={(next: ReviewPassport) => change((old) => replaceEntry(old, next))}
                onEdit={() => review.passport && setEditing(review.passport)}
                onOpenPage={openPage(review.passport.draft.page)}
              />
            </Section>
          )}
        </div>
        <aside className="scan-review-source">
          {/* A note is quoted where a scan's photos are, to check the entries against what the person wrote. */}
          {note ? (
            <Section title={t.noteSectionTitle}>
              <NoteQuote text={scan.text ?? ''} writtenAt={scan.createdAt} />
            </Section>
          ) : (
            <Section title={t.scanPhotosTitle}>
              <StoredPages pages={scan.pages} />
              <CheckboxField
                label={scan.source === 'PassportPages' ? t.scanKeepPhotosPassport : t.scanKeepPhotosDocument}
                hint={
                  scan.source === 'PassportPages' ? t.scanKeepPhotosPassportHelper : t.scanKeepPhotosDocumentHelper
                }
                checked={keepPhotos}
                onChange={(keep) => {
                  setKeepPhotos(keep);
                  setDirty(true);
                }}
              />
            </Section>
          )}
        </aside>
      </div>
      <div className="form-foot">
        {failure && (
          <p className="form-error" role="alert">
            <Icon name="error" size={18} />
            {failure}
          </p>
        )}
        <button
          type="button"
          className="button button--primary"
          // Nothing ticked and no photos kept (a note has none): nothing to save.
          disabled={busy !== null || (count === 0 && !keepPhotos)}
          onClick={() => void save()}
        >
          {busy === 'saving' && <Spinner />}
          {busy === 'saving' ? t.commonSaving : photosOnly ? t.scanSavePhotosOnly : t.scanSaveSelected(count)}
        </button>
        <button
          type="button"
          className="button button--ghost"
          disabled={busy !== null}
          onClick={() => setDiscarding(true)}
        >
          {note ? t.noteDiscard : t.scanDiscard}
        </button>
      </div>
      {editing?.entry === 'record' && (
        <RecordEditor
          entry={editing}
          pet={pet}
          today={today}
          fromNote={note}
          onOpenPage={openPage(editing.draft.page)}
          onDone={(after) => edited(editing, after)}
          onClose={() => setEditing(null)}
        />
      )}
      {editing?.entry === 'identifier' && (
        <IdentifierEditor
          entry={editing}
          otherCodes={codesBefore(review, editing)}
          today={today}
          fromNote={note}
          onOpenPage={openPage(editing.draft.page)}
          onDone={(after) => edited(editing, after)}
          onClose={() => setEditing(null)}
        />
      )}
      {editing?.entry === 'passport' && (
        <PassportEditor
          entry={editing}
          today={today}
          fromNote={note}
          onOpenPage={openPage(editing.draft.page)}
          onDone={(after) => edited(editing, after)}
          onClose={() => setEditing(null)}
        />
      )}
      {editing?.entry === 'weight' && (
        <WeightEditor
          entry={editing}
          pet={pet}
          today={today}
          fromNote={note}
          onOpenPage={openPage(editing.draft.page)}
          onDone={(after) => edited(editing, after)}
          onClose={() => setEditing(null)}
        />
      )}
      {choosingPlan && (
        <PlanPicker
          plans={planChoices(choosingPlan, plans)}
          current={choosingPlan.planId}
          onPick={(planId) => {
            const record = review.records.find((each) => each.draft.key === choosingPlan.draft.key) ?? choosingPlan;
            change((old) => replaceEntry(old, withPlan(record, planId)));
            setChoosingPlan(null);
          }}
          onClose={() => setChoosingPlan(null)}
        />
      )}
      {discarding && (
        <ConfirmDialog
          title={note ? t.noteDiscardTitle : t.scanDiscardTitle}
          body={note ? t.noteDiscardBody : t.scanDiscardBody}
          confirmLabel={t.scanDiscardConfirm}
          danger
          busy={busy === 'discarding'}
          onConfirm={() => void discard()}
          onCancel={() => setDiscarding(false)}
        />
      )}
      {viewing && <PageViewer pages={photos} startAt={viewing} onClose={() => setViewing(null)} />}
    </>
  );
}

function emptyResult(): ApplyImportResponse {
  return { recordIds: [], plansMoved: 0, identifiersAdded: 0, passportUpdated: false, documentId: null, weightsAdded: 0 };
}
