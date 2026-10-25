// A feeding schedule's form (the phone app's feeding_form_screen.dart): its times (added and removed, up to eight;
// a time typed but not added yet is added on "Save"), the days of the week, the food (typed, or picked from the
// household's supplies: then its portions count towards the food's daily use, in the food's unit), the portion and
// its unit, notes; for a schedule that exists, "Active" (off pauses it) and "Delete schedule". One id per new schedule
// makes a retry after a lost answer safe, and a correction typed between the lost answer and the retry follows it.
import { useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState, type FormEvent } from 'react';
import { useNavigate, useParams } from 'react-router';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { usePet, useRoutine, useSupplies } from '../../api/queries';
import type { DayOfWeek, Pet, PortionUnit, Routine, RoutineRequest } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import {
  CheckboxField,
  ChoiceGroup,
  MultiChoice,
  SelectField,
  TextField,
  useFocusFirstError,
} from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { useKeepFocus } from '../../components/useKeepFocus';
import { ErrorNotice, Loading, Notice, PageHead, Spinner } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { apiTime, timeInputValue } from '../../lib/dates';
import {
  amountOk,
  choosableSupplies,
  FEEDING_MAX,
  orderedDays,
  orderedTimes,
  portionUnitFor,
  WEEK,
  weekdayShort,
} from '../../lib/feeding';
import { decimalText, parseDecimal } from '../../lib/numbers';
import { petTabPath } from '../pets/PetPage';

const UNITS: readonly PortionUnit[] = ['Gram', 'Milliliter', 'Piece'];

/** The server's field names this form shows under a field; anything else is said over "Save". */
const FIELDS = ['times', 'days', 'food', 'amount', 'unit', 'notes', 'supplyItemId'];

export function NewFeedingPage() {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  if (pet.data && !isNotFound(pet.error)) return <FeedingForm pet={pet.data} routine={null} />;
  return <Waiting petId={id} title={t.feedingAddTitle} error={pet.error} onRetry={() => void pet.refetch()} />;
}

export function EditFeedingPage() {
  const { id = '', routineId = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  const routine = useRoutine(routineId);
  if (pet.data && routine.data && !routine.isPlaceholderData && !isNotFound(routine.error)) {
    return <FeedingForm pet={pet.data} routine={routine.data} />;
  }
  return (
    <Waiting
      petId={id}
      title={t.feedingEditTitle}
      error={pet.error ?? routine.error}
      onRetry={() => {
        void pet.refetch();
        void routine.refetch();
      }}
    />
  );
}

function Waiting({
  petId,
  title,
  error,
  onRetry,
}: {
  petId: string;
  title: string;
  error: unknown;
  onRetry: () => void;
}) {
  const { t } = useI18n();
  return (
    <>
      <PageHead back={{ to: petTabPath(petId, 'feeding'), label: t.petTabFeeding }} title={title} />
      {error ? <ErrorNotice error={error} onRetry={onRetry} /> : <Loading />}
    </>
  );
}

interface Values {
  /** "08:00", earliest first. */
  times: string[];
  days: DayOfWeek[];
  /** The food in supplies it gives ('' for none): then the food is its name and the portion is in its unit. */
  supplyId: string;
  food: string;
  amount: string;
  unit: PortionUnit;
  notes: string;
  active: boolean;
}

const snapshot = (values: Values) => JSON.stringify({ ...values, days: orderedDays(values.days) });

/** Whether the schedule the server answered with says what was sent (the onboarding's feeding step asks it too). */
export function routineHolds(saved: Routine, sent: RoutineRequest): boolean {
  return (
    orderedTimes(saved.times).join() === orderedTimes(sent.times).join() &&
    orderedDays(saved.days).join() === orderedDays(sent.days ?? []).join() &&
    saved.food === sent.food &&
    saved.amount === sent.amount &&
    saved.unit === sent.unit &&
    saved.notes === sent.notes &&
    saved.supplyItemId === sent.supplyItemId
  );
}

/** The time a new one starts at: 8:00 for the first, else twelve hours after the last. */
function suggestedTime(times: readonly string[]): string {
  const last = times.at(-1);
  if (!last) return '08:00';
  const hour = (Number(last.slice(0, 2)) + 12) % 24;
  return `${String(hour).padStart(2, '0')}:00`;
}

function FeedingForm({ pet, routine }: { pet: Pet; routine: Routine | null }) {
  const i18n = useI18n();
  const { t, lang } = i18n;
  const { current } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const supplies = useSupplies();
  const form = useRef<HTMLFormElement>(null);
  const newTimeId = useId();
  const [requestId] = useState(() => crypto.randomUUID());

  const [values, setValues] = useState<Values>(() => ({
    times: orderedTimes(routine?.times ?? []).map(timeInputValue),
    days: routine?.days.length ? [...routine.days] : [...WEEK],
    supplyId: routine?.supplyItemId ?? '',
    food: routine?.food ?? '',
    amount: routine?.amount != null ? decimalText(lang, routine.amount) : '',
    unit: routine?.unit ?? 'Gram',
    notes: routine?.notes ?? '',
    active: routine?.active ?? true,
  }));
  const [newTime, setNewTime] = useState(() => suggestedTime(values.times));
  // A time typed in the new-time field and not added yet: "Save" adds it, and leaving would lose it.
  const [timeTyped, setTimeTyped] = useState(false);
  const [opened] = useState(() => snapshot(values));
  // "Active" as the form opened: only a change of the person's own is sent, whatever the schedule's answer says since.
  const [openedActive] = useState(() => values.active);
  // Tries of a new schedule sent so far: a retry may get the one an earlier try made, before a correction since.
  const tries = useRef(0);
  const [submitted, setSubmitted] = useState(0);
  const [busy, setBusy] = useState(false);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  const { allowLeave } = useLeaveGuard(snapshot(values) !== opened || timeTyped, busy);
  const stillHere = useStillHere(household);
  useFocusFirstError(form, submitted);
  const feedingPath = petTabPath(pet.id, 'feeding');
  // A time removed: the focus goes to the time now in its place, or to the new-time field when none is left.
  const timesBox = useRef<HTMLFieldSetElement>(null);
  const newTimeField = useRef<HTMLInputElement>(null);
  useKeepFocus(timesBox, { fallback: () => newTimeField.current });

  // The supplies a feeding can give; without them (or while they load) there is just the food's name.
  const choosable = choosableSupplies(supplies.data ?? [], routine?.supplyItemId ?? null);
  const linked = choosable.find((supply) => supply.id === values.supplyId) ?? null;
  const linkedUnit = linked ? portionUnitFor(linked.unit) : null;

  const set = <K extends keyof Values>(field: K, value: Values[K]) => setValues((old) => ({ ...old, [field]: value }));

  /** The times with the one typed in the new-time field, when it is a new one and there is room. */
  function withTyped(times: string[]): string[] {
    const time = newTime.slice(0, 5);
    if (!time || times.includes(time) || times.length >= FEEDING_MAX.times) return times;
    return orderedTimes([...times, time]);
  }

  function addTime() {
    const times = withTyped(values.times);
    setTimeTyped(false);
    if (times === values.times) return;
    set('times', times);
    setNewTime(suggestedTime(times));
  }

  function problems(required: boolean, refused: Record<string, string[]>, from: Values = values) {
    const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
    const amount = from.amount.trim();
    return {
      times:
        required && from.times.length === 0
          ? t.feedingTimesRequired
          : from.times.length > FEEDING_MAX.times
            ? t.feedingTimesTooMany(FEEDING_MAX.times)
            : server('times'),
      days: values.days.length === 0 ? t.feedingDaysRequired : server('days'),
      supplyItemId: server('supplyItemId'),
      food: !linked && values.food.trim().length > FEEDING_MAX.food ? t.formTooLong(FEEDING_MAX.food) : server('food'),
      amount: amount && !amountOk(amount) ? t.feedingAmountInvalid : (server('amount') ?? server('unit')),
      notes: values.notes.trim().length > FEEDING_MAX.notes ? t.formTooLong(FEEDING_MAX.notes) : server('notes'),
    };
  }
  const errors = problems(submitted > 0, serverFields);

  function request(from: Values): RoutineRequest {
    const clean = (value: string) => value.trim() || null;
    const amount = from.amount.trim() ? parseDecimal(from.amount) : null;
    return {
      kind: 'Feeding',
      times: from.times.map(apiTime),
      days: orderedDays(from.days),
      food: linked ? linked.name : clean(from.food),
      amount,
      unit: amount === null ? null : (linkedUnit ?? from.unit),
      notes: clean(from.notes),
      // Sent only when changed here: null keeps it as it is, even if another phone changed it meanwhile.
      active: routine && from.active !== openedActive ? from.active : null,
      requestId: routine ? null : requestId,
      supplyItemId: from.supplyId || null,
    };
  }

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: keys.routines(household, pet.id) });
    if (routine) void queryClient.invalidateQueries({ queryKey: keys.routine(household, routine.id) });
    void queryClient.invalidateQueries({ queryKey: keys.todayAll(household) });
    // A food's daily use comes from the feedings that give it.
    void queryClient.invalidateQueries({ queryKey: keys.supplies(household) });
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    // A time typed and not added is meant: it is added first.
    const saving = timeTyped ? { ...values, times: withTyped(values.times) } : values;
    if (saving !== values) {
      setValues(saving);
      setTimeTyped(false);
      setNewTime(suggestedTime(saving.times));
    }
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(problems(true, {}, saving)).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }
    setBusy(true);
    const sent = request(saving);
    try {
      if (routine) {
        await api.PUT('/api/v1/routines/{id}', { params: { path: { id: routine.id } }, body: sent });
      } else {
        const retry = tries.current > 0;
        tries.current += 1;
        const added = await data(
          api.POST('/api/v1/pets/{petId}/routines', { params: { path: { petId: pet.id } }, body: sent }),
        );
        // A retry after a lost answer gets the schedule as the first try made it: a correction since then follows.
        if (retry && !routineHolds(added, sent)) {
          await api.PUT('/api/v1/routines/{id}', {
            params: { path: { id: added.id } },
            body: { ...sent, requestId: null },
          });
        }
      }
      refresh();
      allowLeave();
      if (stillHere()) void navigate(feedingPath, { replace: !routine });
    } catch (error) {
      refresh();
      if (isNotFound(error)) {
        toast(routine ? t.feedingGone : t.careGonePet);
        allowLeave();
        if (stillHere()) void navigate(routine ? feedingPath : '/pets');
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

  async function remove(target: Routine) {
    setBusy(true);
    try {
      await api.DELETE('/api/v1/routines/{id}', { params: { path: { id: target.id } } });
    } catch (error) {
      // Deleted already, on another device: that is what was wanted.
      if (!isNotFound(error)) {
        toast(errorMessage(t, error));
        setBusy(false);
        setDeleting(false);
        return;
      }
    }
    queryClient.removeQueries({ queryKey: keys.routine(household, target.id) });
    refresh();
    allowLeave();
    if (stillHere()) void navigate(feedingPath);
  }

  return (
    <>
      <PageHead
        back={{ to: feedingPath, label: pet.name }}
        title={routine ? t.feedingEditTitle : t.feedingAddTitle}
        actions={
          routine && (
            <button
              type="button"
              className="button button--ghost button--danger-text"
              onClick={() => setDeleting(true)}
              disabled={busy}
            >
              <Icon name="delete" />
              {t.feedingDelete}
            </button>
          )
        }
      />
      <form ref={form} className="form" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
        <fieldset className="form-stack" disabled={busy}>
          <fieldset
            ref={timesBox}
            className="choice-group"
            data-invalid={errors.times ? true : undefined}
            aria-describedby={errors.times ? `${newTimeId}-error` : undefined}
          >
            <legend className="field-label">{t.feedingTimesLabel}</legend>
            {values.times.length > 0 && (
              <ul className="choices plain-list">
                {values.times.map((time) => (
                  <li key={time}>
                    <button
                      type="button"
                      className="choice-pill time-chip"
                      aria-label={t.feedingTimeRemove(i18n.time(time))}
                      onClick={() =>
                        set(
                          'times',
                          values.times.filter((each) => each !== time),
                        )
                      }
                    >
                      {i18n.time(time)}
                      <Icon name="close" size={16} />
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {values.times.length < FEEDING_MAX.times && (
              <div className="time-add">
                <label className="visually-hidden" htmlFor={newTimeId}>
                  {t.feedingTimeNew}
                </label>
                <input
                  ref={newTimeField}
                  id={newTimeId}
                  className="input input--time"
                  type="time"
                  value={newTime}
                  onChange={(event) => {
                    setNewTime(event.target.value);
                    setTimeTyped(true);
                  }}
                  onKeyDown={(event) => {
                    // Enter here adds the time, rather than saving the form.
                    if (event.key === 'Enter') {
                      event.preventDefault();
                      addTime();
                    }
                  }}
                />
                <button type="button" className="button button--secondary" onClick={addTime}>
                  <Icon name="add" size={18} />
                  {t.feedingTimeAdd}
                </button>
              </div>
            )}
            {errors.times && (
              <p className="field-error" id={`${newTimeId}-error`}>
                <Icon name="error" size={16} />
                {errors.times}
              </p>
            )}
          </fieldset>
          <MultiChoice
            label={t.feedingDaysLabel}
            values={values.days}
            options={WEEK.map((day) => ({ value: day, label: weekdayShort(lang, day) }))}
            onChange={(days) => set('days', days)}
            error={errors.days}
          />
          {choosable.length > 0 && (
            <SelectField
              label={t.feedingSupplyLabel}
              hint={t.feedingSupplyHelper}
              value={values.supplyId}
              options={[
                { value: '', label: t.feedingSupplyNone },
                ...choosable.map((supply) => ({ value: supply.id, label: supply.name })),
              ]}
              onChange={(supplyId) => {
                const supply = choosable.find((each) => each.id === supplyId);
                const unit = supply ? portionUnitFor(supply.unit) : null;
                // A food in supplies is counted in its unit: the portion is in it too.
                setValues((old) => ({ ...old, supplyId, unit: unit ?? old.unit }));
              }}
              error={errors.supplyItemId}
            />
          )}
          {!linked && (
            <TextField
              label={t.feedingFoodLabel}
              placeholder={t.feedingFoodHint}
              value={values.food}
              onChange={(food) => set('food', food)}
              error={errors.food}
            />
          )}
          <div className="form-row">
            <TextField
              label={t.feedingPortionLabel}
              placeholder={t.feedingAmountHint}
              value={values.amount}
              inputMode="decimal"
              onChange={(amount) => set('amount', amount)}
              error={errors.amount}
            />
            <ChoiceGroup
              label={t.feedingUnitLabel}
              value={linkedUnit ?? values.unit}
              options={UNITS.map((unit) => ({
                value: unit,
                label: t.portionUnit[unit],
                disabled: linkedUnit !== null && unit !== linkedUnit,
              }))}
              onChange={(unit) => set('unit', unit)}
            />
          </div>
          <TextField
            label={t.careNotesLabel}
            value={values.notes}
            rows={3}
            onChange={(notes) => set('notes', notes)}
            error={errors.notes}
          />
          {routine && (
            <CheckboxField
              label={t.feedingActiveLabel}
              hint={t.feedingActiveHelper}
              checked={values.active}
              onChange={(active) => set('active', active)}
            />
          )}
          <Notice>
            <p>{t.feedingRemindersNote}</p>
          </Notice>
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
          <button
            type="button"
            className="button button--ghost"
            onClick={() => void navigate(feedingPath)}
            disabled={busy}
          >
            {t.commonCancel}
          </button>
        </div>
      </form>
      {deleting && routine && (
        <ConfirmDialog
          title={t.feedingDeleteTitle}
          body={t.feedingDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={busy}
          onConfirm={() => void remove(routine)}
          onCancel={() => setDeleting(false)}
        />
      )}
    </>
  );
}
