// Adding a visit, or editing one: where (the kind of visit), what for, the date and time in the household's time zone,
// the pets, the place, the reminders (a day and two hours before by default) and notes. No title typed: the kind of
// visit says what it is. One id per new visit makes a retry after a lost answer safe (no visit twice).
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type FormEvent } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { usePets, useVisit } from '../../api/queries';
import type { Pet, Visit, VisitRequest, VisitType } from '../../api/types';
import { ChoiceGroup, DateField, MultiChoice, TextField, TimeField, useFocusFirstError } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { VISIT_TYPE_ICONS } from '../../components/kindIcons';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, PageHead, Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { addDays, apiTime, timeInputValue } from '../../lib/dates';
import { visitReminderLabel } from '../../lib/labels';

// The server's limits.
const MAX = { title: 100, location: 200, notes: 2000 };

const TYPES: readonly VisitType[] = ['Vet', 'Grooming', 'Training', 'Other'];

/** The reminders offered, in minutes before the visit: a week, a day, two hours, an hour. */
const REMINDERS = [10080, 1440, 120, 60];

/** A new visit's reminders: a day and two hours before. */
const DEFAULT_REMINDERS = [1440, 120];

const FIELDS = ['type', 'title', 'date', 'time', 'location', 'notes', 'petIds', 'remindOffsetsMinutes'];

export function NewVisitPage() {
  const { t } = useI18n();
  const [search] = useSearchParams();
  const pets = usePets();
  if (pets.data) return <VisitForm visit={null} pets={pets.data} forPet={search.get('pet')} />;
  return <Waiting title={t.visitAddTitle} back="/visits" error={pets.error} onRetry={() => void pets.refetch()} />;
}

export function EditVisitPage() {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const pets = usePets();
  const visit = useVisit(id);
  // A visit deleted meanwhile (here, or on another phone) is not edited from an old copy.
  if (pets.data && visit.data && !isNotFound(visit.error)) {
    return <VisitForm visit={visit.data} pets={pets.data} forPet={null} />;
  }
  return (
    <Waiting
      title={t.visitEditTitle}
      back={`/visits/${id}`}
      error={pets.error ?? visit.error}
      onRetry={() => {
        void pets.refetch();
        void visit.refetch();
      }}
    />
  );
}

/** The form's page until what it needs has come: the pets (and the visit), or why not. */
function Waiting({
  title,
  back,
  error,
  onRetry,
}: {
  title: string;
  back: string;
  error: unknown;
  onRetry: () => void;
}) {
  const { t } = useI18n();
  return (
    <>
      <PageHead back={{ to: back, label: t.visitsTitle }} title={title} />
      {error ? <ErrorNotice error={error} onRetry={onRetry} /> : <Loading />}
    </>
  );
}

function VisitForm({ visit, pets, forPet }: { visit: Visit | null; pets: Pet[]; forPet: string | null }) {
  const { t } = useI18n();
  const { current } = useHousehold();
  // The household the form opened in: its save goes there, whichever household is on screen meanwhile.
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const today = useHouseholdDate();
  const form = useRef<HTMLFormElement>(null);
  const [requestId] = useState(() => crypto.randomUUID());

  // The pets a visit can be for: the active ones, and any the visit already has.
  const choosable = pets.filter((pet) => pet.status === 'Active' || visit?.petIds.includes(pet.id));
  const [values, setValues] = useState(() => {
    const active = pets.filter((pet) => pet.status === 'Active');
    return {
      type: visit?.type ?? ('Vet' as VisitType),
      title: visit?.title ?? '',
      date: visit?.date ?? '',
      time: timeInputValue(visit?.time),
      // The pet the form was opened for, or the only one.
      petIds: visit?.petIds ?? (forPet ? [forPet] : active.length === 1 ? [active[0]!.id] : []),
      location: visit?.location ?? '',
      reminders: visit?.remindOffsetsMinutes ?? DEFAULT_REMINDERS,
      notes: visit?.notes ?? '',
    };
  });
  const [opened] = useState(() => JSON.stringify(values));
  const [submitted, setSubmitted] = useState(0);
  const [busy, setBusy] = useState(false);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  // Leaving waits while the visit saves: its page opens next, in the household it was saved to.
  const { allowLeave } = useLeaveGuard(JSON.stringify(values) !== opened, busy);
  const stillHere = useStillHere(household);
  useFocusFirstError(form, submitted);

  const set = <K extends keyof typeof values>(field: K, value: (typeof values)[K]) =>
    setValues((old) => ({ ...old, [field]: value }));

  /** The form's own checks (`required`: after a first "Save"), and the server's word on fields it refused. */
  function problems(required: boolean, refused: Record<string, string[]>) {
    const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
    const tooLong = (field: keyof typeof MAX) =>
      values[field].trim().length > MAX[field] ? t.formTooLong(MAX[field]) : server(field);
    return {
      type: server('type'),
      title: tooLong('title'),
      date: required && !values.date ? t.dateRequired : server('date'),
      time: required && !values.time ? t.visitTimeRequired : server('time'),
      petIds: required && values.petIds.length === 0 ? t.visitPetsRequired : server('petIds'),
      location: tooLong('location'),
      reminders: server('remindOffsetsMinutes'),
      notes: tooLong('notes'),
    };
  }
  const errors = problems(submitted > 0, serverFields);

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(problems(true, {})).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }
    const clean = (value: string) => value.trim() || null;
    const body: VisitRequest = {
      type: values.type,
      title: clean(values.title) ?? t.visitType[values.type],
      date: values.date,
      time: apiTime(values.time),
      // Not edited on the web; sent back as it was, so it isn't lost.
      durationMinutes: visit?.durationMinutes ?? null,
      location: clean(values.location),
      notes: clean(values.notes),
      // In the order of the pets list, whatever order they were picked in.
      petIds: pets.filter((pet) => values.petIds.includes(pet.id)).map((pet) => pet.id),
      remindOffsetsMinutes: [...values.reminders].sort((a, b) => b - a),
      // Only cancelling and planning again change the status (the visit's page).
      status: null,
      requestId: visit ? null : requestId,
    };
    setBusy(true);
    try {
      const saved = await data(
        visit
          ? api.PUT('/api/v1/appointments/{id}', { params: { path: { id: visit.id } }, body })
          : api.POST('/api/v1/appointments', { body }),
      );
      void queryClient.invalidateQueries({ queryKey: keys.visits(household) });
      void queryClient.invalidateQueries({ queryKey: keys.todayAll(household) });
      allowLeave();
      // Gone meanwhile (the household on screen went away): nothing opens in another household.
      if (stillHere()) void navigate(`/visits/${saved.id}`, { replace: !visit });
    } catch (error) {
      void queryClient.invalidateQueries({ queryKey: keys.visits(household) });
      if (visit && isNotFound(error)) {
        // Deleted on another device: there is nothing left to save.
        toast(t.visitGone);
        allowLeave();
        if (stillHere()) void navigate('/visits');
        return;
      }
      const fields = fieldErrorsOf(error);
      const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => FIELDS.includes(field));
      setServerFields(placed ? fields : {});
      setFailure(placed ? t.formCheckFields : errorMessage(t, error));
      if (placed) setSubmitted((value) => value + 1);
      setBusy(false);
    }
  }

  // Reminders set elsewhere (on the phone) stay choosable.
  const reminderChoices = [...new Set([...REMINDERS, ...values.reminders])].sort((a, b) => b - a);
  const back = visit ? `/visits/${visit.id}` : '/visits';

  return (
    <>
      <PageHead back={{ to: back, label: t.visitsTitle }} title={visit ? t.visitEditTitle : t.visitAddTitle} />
      <form ref={form} className="form" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
        <fieldset className="form-stack" disabled={busy}>
          <ChoiceGroup
            label={t.visitTypeLabel}
            value={values.type}
            options={TYPES.map((type) => ({
              value: type,
              label: t.visitType[type],
              icon: <Icon name={VISIT_TYPE_ICONS[type]} size={18} />,
            }))}
            onChange={(type) => set('type', type)}
            error={errors.type}
          />
          <TextField
            label={t.visitTitleLabel}
            placeholder={t.visitTitleHint}
            value={values.title}
            onChange={(value) => set('title', value)}
            error={errors.title}
          />
          <div className="form-row">
            <DateField
              label={t.visitDateLabel}
              value={values.date}
              min={addDays(today, -365)}
              max={addDays(today, 5 * 365)}
              onChange={(value) => set('date', value)}
              error={errors.date}
            />
            <TimeField
              label={t.visitTimeLabel}
              value={values.time}
              onChange={(value) => set('time', value)}
              error={errors.time}
            />
          </div>
          <MultiChoice
            label={t.visitPetsLabel}
            values={values.petIds}
            options={choosable.map((pet) => ({ value: pet.id, label: pet.name }))}
            onChange={(petIds) => set('petIds', petIds)}
            error={errors.petIds}
          />
          <TextField
            label={t.visitLocationLabel}
            placeholder={t.visitLocationHint}
            value={values.location}
            onChange={(value) => set('location', value)}
            error={errors.location}
          />
          <MultiChoice
            label={t.visitRemindersLabel}
            values={values.reminders}
            options={reminderChoices.map((minutes) => ({ value: minutes, label: visitReminderLabel(t, minutes) }))}
            onChange={(reminders) => set('reminders', reminders)}
            hint={values.reminders.length === 0 ? t.visitRemindersNone : null}
            error={errors.reminders}
          />
          <TextField
            label={t.visitNotesLabel}
            value={values.notes}
            onChange={(value) => set('notes', value)}
            rows={4}
            error={errors.notes}
          />
        </fieldset>
        <div className="form-foot">
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {busy ? t.commonSaving : t.commonSave}
          </button>
          <button type="button" className="button button--ghost" onClick={() => void navigate(back)} disabled={busy}>
            {t.commonCancel}
          </button>
        </div>
      </form>
    </>
  );
}
