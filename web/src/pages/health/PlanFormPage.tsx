// A plan's form (the phone app's plan_form_screen.dart): what to do, its kind, how often (or once), when it was last
// done (a new plan's next date is counted from it), the next date, the usual product, what a vaccine protects against,
// notes; and for a plan that exists, "Active" (off pauses it: it leaves Today) and "Delete plan". A new plan starts
// from a ready-made one (its note on top; a product toxic to cats in red) or by hand. One id per new plan makes a
// retry after a lost answer safe. The server refuses a dog-only product for a cat: the form says so in words.
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type FormEvent } from 'react';
import { useNavigate, useParams } from 'react-router';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { refreshCare, useCarePlan, useCarePresets, usePet } from '../../api/queries';
import type {
  CareKind,
  CarePlan,
  CarePlanRequest,
  CarePreset,
  IntervalUnit,
  Pet,
  VaccineTarget,
} from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import {
  CheckboxField,
  ChoiceGroup,
  DateField,
  MultiChoice,
  SelectField,
  TextField,
  useFocusFirstError,
} from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, Notice, PageHead, Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import {
  CARE_KINDS,
  CARE_MAX,
  EARLIEST_CARE_DATE,
  latestDueDate,
  MAX_INTERVAL,
  offeredTargets,
  orderedTargets,
  usesProduct,
  usesTargets,
} from '../../lib/care';
import { addInterval } from '../../lib/dates';
import { presetNote, presetTitle } from '../../lib/labels';
import { petTabPath } from '../pets/PetPage';

const UNITS: readonly IntervalUnit[] = ['Day', 'Week', 'Month', 'Year'];

/** The server's field names this form shows under a field; presetCode is said over the form. */
const FIELDS = /^(kind|title|intervalValue|intervalUnit|nextDueOn|defaultProduct|targets|notes|presetCode)$/;

export function NewPlanPage() {
  const { id = '', preset: code = 'own' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  const own = code === 'own';
  const presets = useCarePresets(own ? undefined : pet.data?.species);
  if (pet.data && !isNotFound(pet.error) && (own || presets.data)) {
    // An unknown code (an old link, say) gives an own plan.
    const preset = presets.data?.find((item) => item.code === code) ?? null;
    return <PlanForm pet={pet.data} plan={null} preset={preset} />;
  }
  return (
    <Waiting
      petId={id}
      title={t.planFormAddTitle}
      error={pet.error ?? presets.error}
      onRetry={() => {
        void pet.refetch();
        void presets.refetch();
      }}
    />
  );
}

export function EditPlanPage() {
  const { id = '', planId = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  const plan = useCarePlan(planId);
  // A plan deleted meanwhile (on another phone) is not edited from an old copy.
  if (pet.data && plan.data && !isNotFound(plan.error) && !isNotFound(pet.error)) {
    return <PlanForm pet={pet.data} plan={plan.data} preset={null} />;
  }
  return (
    <Waiting
      petId={id}
      title={t.planFormEditTitle}
      error={pet.error ?? plan.error}
      onRetry={() => {
        void pet.refetch();
        void plan.refetch();
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
      <PageHead back={{ to: petTabPath(petId, 'health'), label: t.petTabHealth }} title={title} />
      {error ? <ErrorNotice error={error} onRetry={onRetry} /> : <Loading />}
    </>
  );
}

interface Values {
  title: string;
  kind: CareKind;
  repeats: boolean;
  intervalValue: string;
  unit: IntervalUnit;
  /** When it was last done (new plans only): the next date is counted from it. */
  lastDone: string;
  nextDue: string;
  product: string;
  targets: VaccineTarget[];
  notes: string;
  active: boolean;
}

/** Whether the plan the server answered with says what was sent (the targets as a set). */
function planHolds(saved: CarePlan, sent: CarePlanRequest): boolean {
  return (
    saved.kind === sent.kind &&
    saved.title === sent.title &&
    saved.intervalValue === sent.intervalValue &&
    saved.intervalUnit === sent.intervalUnit &&
    saved.nextDueOn === sent.nextDueOn &&
    saved.defaultProduct === sent.defaultProduct &&
    saved.notes === sent.notes &&
    orderedTargets(saved.targets).join() === orderedTargets(sent.targets ?? []).join()
  );
}

/** What a form holds, to tell whether leaving loses anything: the targets as a set. */
const snapshot = (values: Values) => JSON.stringify({ ...values, targets: orderedTargets(values.targets) });

function PlanForm({ pet, plan, preset }: { pet: Pet; plan: CarePlan | null; preset: CarePreset | null }) {
  const i18n = useI18n();
  const { t } = i18n;
  // The household the form opened in: its save goes there, whichever household is on screen meanwhile.
  const { current } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const today = useHouseholdDate();
  const form = useRef<HTMLFormElement>(null);
  const [requestId] = useState(() => crypto.randomUUID());

  const [values, setValues] = useState<Values>(() => {
    const start = plan
      ? plan.intervalValue && plan.intervalUnit
        ? { value: plan.intervalValue, unit: plan.intervalUnit }
        : null
      : preset
        ? preset.intervalValue && preset.intervalUnit
          ? { value: preset.intervalValue, unit: preset.intervalUnit }
          : null
        : { value: 1, unit: 'Month' as IntervalUnit };
    return {
      title: plan?.title ?? (preset ? presetTitle(t, preset) : ''),
      kind: plan?.kind ?? preset?.kind ?? 'Other',
      repeats: start !== null,
      intervalValue: String(start?.value ?? 1),
      unit: start?.unit ?? 'Month',
      lastDone: '',
      nextDue: plan?.nextDueOn ?? today,
      product: plan?.defaultProduct ?? '',
      targets: plan?.targets ?? preset?.targets ?? [],
      notes: plan?.notes ?? '',
      active: plan?.active ?? true,
    };
  });
  /** The next date was worked out from "last done", not picked. */
  const [computed, setComputed] = useState(false);
  const [opened] = useState(() => snapshot(values));
  // "Active" as the form opened: only a change of the person's own is sent, whatever the plan's answer says since.
  const [openedActive] = useState(() => values.active);
  // Tries of a new plan sent so far: a retry may get the plan an earlier try made, before a correction typed since.
  const tries = useRef(0);
  const [submitted, setSubmitted] = useState(0);
  const [busy, setBusy] = useState(false);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  const { allowLeave } = useLeaveGuard(snapshot(values) !== opened, busy);
  const stillHere = useStillHere(household);
  useFocusFirstError(form, submitted);

  // The product is asked where something is given, and whenever the plan has one: saving never drops it unseen.
  const showProduct = usesProduct(values.kind) || !!plan?.defaultProduct;
  const healthPath = petTabPath(pet.id, 'health');

  /** The interval as typed, or null for a one-off plan or a number the server wouldn't take. */
  function interval(from: Values): { value: number; unit: IntervalUnit } | null {
    if (!from.repeats) return null;
    const value = Number(from.intervalValue.trim());
    return Number.isInteger(value) && value >= 1 && value <= MAX_INTERVAL[from.unit]
      ? { value, unit: from.unit }
      : null;
  }

  /** Changes values; a new "last done" or interval counts the next date again (the person can still change it). */
  function change(update: Partial<Values>) {
    const next = { ...values, ...update };
    const every = interval(next);
    const recount = 'lastDone' in update || 'intervalValue' in update || 'unit' in update || 'repeats' in update;
    if (recount && next.lastDone && every) {
      next.nextDue = addInterval(next.lastDone, every.value, every.unit);
      setComputed(true);
    }
    setValues(next);
  }

  /** The form's own checks (`required`: after a first "Save"), and the server's word on fields it refused. */
  function problems(required: boolean, refused: Record<string, string[]>) {
    const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
    const tooLong = (value: string, max: number, field: string) =>
      value.trim().length > max ? t.formTooLong(max) : server(field);
    const max = MAX_INTERVAL[values.unit];
    return {
      title: required && !values.title.trim() ? t.planTitleRequired : tooLong(values.title, CARE_MAX.title, 'title'),
      kind: server('kind'),
      intervalValue:
        values.repeats && !interval(values) && (required || values.intervalValue.trim() !== '')
          ? t.planIntervalInvalid(max)
          : (server('intervalValue') ?? server('intervalUnit')),
      lastDone:
        values.lastDone && values.lastDone < EARLIEST_CARE_DATE
          ? t.dateTooEarly
          : values.lastDone > today
            ? t.dateInFuture
            : null,
      nextDueOn: !values.nextDue
        ? required
          ? t.dateRequired
          : null
        : values.nextDue < EARLIEST_CARE_DATE
          ? t.dateTooEarly
          : server('nextDueOn'),
      defaultProduct: showProduct ? tooLong(values.product, CARE_MAX.product, 'defaultProduct') : null,
      targets: server('targets'),
      notes: tooLong(values.notes, CARE_MAX.notes, 'notes'),
    };
  }
  const errors = problems(submitted > 0, serverFields);

  function request(): CarePlanRequest {
    const clean = (value: string) => value.trim() || null;
    const every = interval(values);
    return {
      kind: values.kind,
      title: values.title.trim(),
      intervalValue: every?.value ?? null,
      intervalUnit: every?.unit ?? null,
      nextDueOn: values.nextDue,
      // Kept as they are; a new plan gets the server's default (7, 1 and 0 days before).
      remindOffsetsDays: plan?.remindOffsetsDays ?? null,
      defaultProduct: showProduct ? clean(values.product) : null,
      targets: usesTargets(values.kind) ? orderedTargets(values.targets) : [],
      presetCode: plan?.presetCode ?? preset?.code ?? null,
      notes: clean(values.notes),
      // Sent only when changed here: null keeps the plan as it is, even if another phone changed it meanwhile.
      active: plan && values.active !== openedActive ? values.active : null,
      requestId: plan ? null : requestId,
    };
  }

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
    setBusy(true);
    const sent = request();
    try {
      if (plan) {
        await api.PUT('/api/v1/care-plans/{id}', { params: { path: { id: plan.id } }, body: sent });
      } else {
        const retry = tries.current > 0;
        tries.current += 1;
        const added = await data(
          api.POST('/api/v1/pets/{petId}/care-plans', { params: { path: { petId: pet.id } }, body: sent }),
        );
        // A retry after a lost answer gets the plan as the first try made it: a correction since then follows.
        if (retry && !planHolds(added, sent)) {
          await api.PUT('/api/v1/care-plans/{id}', {
            params: { path: { id: added.id } },
            body: { ...sent, requestId: null },
          });
        }
      }
      refreshCare(queryClient, household, pet.id);
      allowLeave();
      if (stillHere()) void navigate(healthPath, { replace: !plan });
    } catch (error) {
      // The save may have gone through and only the answer got lost: the lists show what the server has.
      refreshCare(queryClient, household, pet.id);
      if (isNotFound(error)) {
        // The plan (or, when adding, the pet) was deleted elsewhere: there is nothing left to save.
        toast(plan ? t.careGonePlan : t.careGonePet);
        allowLeave();
        if (stillHere()) void navigate(plan ? healthPath : '/pets');
        return;
      }
      const fields = fieldErrorsOf(error);
      const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => FIELDS.test(field));
      setServerFields(placed ? fields : {});
      setFailure(placed ? t.formCheckFields : errorMessage(t, error));
      if (placed) setSubmitted((value) => value + 1);
      setBusy(false);
    }
  }

  async function remove(target: CarePlan) {
    setBusy(true);
    try {
      await api.DELETE('/api/v1/care-plans/{id}', { params: { path: { id: target.id } } });
    } catch (error) {
      // Deleted already, on another device: that is what was wanted.
      if (!isNotFound(error)) {
        toast(errorMessage(t, error));
        setBusy(false);
        setDeleting(false);
        return;
      }
    }
    queryClient.removeQueries({ queryKey: keys.carePlan(household, target.id) });
    refreshCare(queryClient, household, pet.id);
    allowLeave();
    if (stillHere()) void navigate(healthPath);
  }

  // A ready-made plan's note on top; a product toxic to cats is a warning.
  const note = preset ? presetNote(t, preset) : null;
  const refusedPreset = serverFields.presetCode
    ? preset?.dogOnly
      ? t.planPresetDogOnly
      : t.planPresetOtherSpecies
    : null;
  const count = Number(values.intervalValue) || 1;

  return (
    <>
      <PageHead
        back={{ to: healthPath, label: pet.name }}
        title={plan ? t.planFormEditTitle : t.planFormAddTitle}
        actions={
          plan && (
            <button
              type="button"
              className="button button--ghost button--danger-text"
              onClick={() => setDeleting(true)}
              disabled={busy}
            >
              <Icon name="delete" />
              {t.planDelete}
            </button>
          )
        }
      />
      <form ref={form} className="form" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
        {preset?.dogOnly ? (
          <Notice tone="danger">
            <p>{[t.presetDogOnly, note].filter(Boolean).join('. ')}</p>
          </Notice>
        ) : (
          note && (
            <Notice>
              <p>{note}</p>
            </Notice>
          )
        )}
        {refusedPreset && (
          <Notice tone="danger">
            <p>{refusedPreset}</p>
          </Notice>
        )}
        <fieldset className="form-stack" disabled={busy}>
          <TextField
            label={t.planTitleLabel}
            placeholder={t.planTitleHint}
            value={values.title}
            onChange={(title) => change({ title })}
            error={errors.title}
          />
          <SelectField
            label={t.careKindLabel}
            value={values.kind}
            options={CARE_KINDS.map((kind) => ({ value: kind, label: t.careKind[kind] }))}
            onChange={(kind) => change({ kind })}
            error={errors.kind}
          />
          <ChoiceGroup
            label={t.planRepeatLabel}
            value={values.repeats ? 'repeats' : 'once'}
            options={[
              { value: 'repeats' as const, label: t.planRepeats },
              { value: 'once' as const, label: t.planOnce },
            ]}
            onChange={(choice) => change({ repeats: choice === 'repeats' })}
          />
          {values.repeats && (
            <>
              <div className="form-row form-row--interval">
                <TextField
                  label={t.planIntervalLabel}
                  value={values.intervalValue}
                  inputMode="numeric"
                  onChange={(intervalValue) => change({ intervalValue: intervalValue.replace(/\D/g, '') })}
                  error={errors.intervalValue}
                />
                <SelectField
                  label={t.planIntervalUnitLabel}
                  value={values.unit}
                  options={UNITS.map((unit) => ({ value: unit, label: t.intervalUnitName[unit](count) }))}
                  onChange={(unit) => change({ unit })}
                />
              </div>
              {!plan && (
                <DateField
                  label={t.planLastDoneLabel}
                  hint={t.planLastDoneHelper}
                  value={values.lastDone}
                  min={EARLIEST_CARE_DATE}
                  max={today}
                  onChange={(lastDone) => change({ lastDone })}
                  error={errors.lastDone}
                />
              )}
            </>
          )}
          <DateField
            label={values.repeats ? t.planNextDueLabel : t.planDueOnLabel}
            hint={computed ? t.planNextDueComputed : null}
            value={values.nextDue}
            min={EARLIEST_CARE_DATE}
            max={latestDueDate(today)}
            onChange={(nextDue) => {
              setComputed(false);
              change({ nextDue });
            }}
            error={errors.nextDueOn}
          />
          {showProduct && (
            <TextField
              label={t.planDefaultProductLabel}
              placeholder={t.planDefaultProductHint}
              hint={t.planDefaultProductHelper}
              value={values.product}
              onChange={(product) => change({ product })}
              error={errors.defaultProduct}
            />
          )}
          {usesTargets(values.kind) && (
            <MultiChoice
              label={t.careTargetsLabel}
              values={values.targets}
              options={offeredTargets(pet.species, values.targets).map((target) => ({
                value: target,
                label: t.vaccineTarget[target],
              }))}
              onChange={(targets) => change({ targets })}
              error={errors.targets}
            />
          )}
          <TextField
            label={t.careNotesLabel}
            value={values.notes}
            onChange={(notes) => change({ notes })}
            rows={4}
            error={errors.notes}
          />
          {plan && (
            <CheckboxField
              label={t.planActiveLabel}
              hint={t.planActiveHelper}
              checked={values.active}
              onChange={(active) => change({ active })}
            />
          )}
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
            onClick={() => void navigate(healthPath)}
            disabled={busy}
          >
            {t.commonCancel}
          </button>
        </div>
      </form>
      {deleting && plan && (
        <ConfirmDialog
          title={t.planDeleteTitle}
          body={t.planDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={busy}
          onConfirm={() => void remove(plan)}
          onCancel={() => setDeleting(false)}
        />
      )}
    </>
  );
}
