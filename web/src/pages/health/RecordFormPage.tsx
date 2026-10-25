// A record of the history, by hand (the phone app's record_form_screen.dart): history from the paper passport, or a
// fix of a record. Its kind decides the fields: what a vaccine protects against and how long, the product with its
// maker and batch, the hour of a treatment before travel, a rabies antibody test's laboratory and result, a check-up's
// weight and "fit to travel"; and for all, the clinic, the vet and notes. A field the record already has a value in
// shows whatever the kind, so saving never drops it unseen. Records don't move plans: only "Done" does. One id per new
// record makes a retry after a lost answer safe. Photos and files are added on the record's page, where it opens next.
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type FormEvent } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { refreshCare, useCareRecord, usePet } from '../../api/queries';
import type { CareKind, CareRecord, CareRecordRequest, Pet, VaccineTarget } from '../../api/types';
import {
  CheckboxField,
  DateField,
  MultiChoice,
  SelectField,
  TextField,
  TimeField,
  useFocusFirstError,
} from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, PageHead, Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import {
  CARE_KINDS,
  CARE_MAX,
  defaultRecordTitle,
  EARLIEST_CARE_DATE,
  latestDueDate,
  offeredTargets,
  orderedTargets,
  usesExam,
  usesProduct,
  usesTargets,
  usesTime,
  usesTiter,
  usesValidity,
  VACCINE_TARGETS,
} from '../../lib/care';
import { apiTime, timeInputValue } from '../../lib/dates';
import { weightProblemLabel } from '../../lib/labels';
import { decimalText, parseDecimal } from '../../lib/numbers';
import { RECORD_DECIMALS, weightTextProblem } from '../../lib/weight';
import { petTabPath } from '../pets/PetPage';
import { backTab } from './RecordPage';

/** The server's field names this form shows under a field; anything else is said over "Save". */
const FIELDS =
  /^(kind|title|performedOn|performedTime|product|manufacturer|batchNumber|validFrom|validUntil|targets|clinic|veterinarian|weightKg|notes|details\.(laboratory|reportNumber|titerIuPerMl))$/;

/** Whether the record the server answered with says what was sent (the targets as a set). */
function recordHolds(saved: CareRecord, sent: CareRecordRequest): boolean {
  const time = (value: string | null) => (value ? value.slice(0, 5) : null);
  const weight = (value: number | null) => (value === null ? null : Math.round(value * 1000));
  return (
    saved.kind === sent.kind &&
    saved.title === sent.title &&
    saved.performedOn === sent.performedOn &&
    time(saved.performedTime) === time(sent.performedTime) &&
    saved.product === sent.product &&
    saved.manufacturer === sent.manufacturer &&
    saved.batchNumber === sent.batchNumber &&
    saved.validFrom === sent.validFrom &&
    saved.validUntil === sent.validUntil &&
    orderedTargets(saved.targets).join() === orderedTargets(sent.targets ?? []).join() &&
    saved.clinic === sent.clinic &&
    saved.veterinarian === sent.veterinarian &&
    weight(saved.weightKg) === weight(sent.weightKg) &&
    JSON.stringify(saved.details) === JSON.stringify(sent.details) &&
    saved.notes === sent.notes
  );
}

export function NewRecordPage() {
  const { id = '' } = useParams();
  const [search] = useSearchParams();
  const { t } = useI18n();
  const pet = usePet(id);
  // The passport's sections open it with their kind: a rabies vaccination, a deworming…
  const kind = CARE_KINDS.find((each) => each === search.get('kind')) ?? 'Vaccination';
  const target = VACCINE_TARGETS.find((each) => each === search.get('target'));
  if (pet.data && !isNotFound(pet.error)) {
    return <RecordForm pet={pet.data} record={null} kind={kind} targets={target ? [target] : []} />;
  }
  return <Waiting petId={id} title={t.recordFormAddTitle} error={pet.error} onRetry={() => void pet.refetch()} />;
}

export function EditRecordPage() {
  const { id = '', recordId = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  const record = useCareRecord(recordId);
  // The form opens on the record's own answer, not a list's older copy; a record deleted meanwhile isn't edited.
  if (pet.data && record.data && !record.isPlaceholderData && !isNotFound(record.error)) {
    return <RecordForm pet={pet.data} record={record.data} kind={record.data.kind} targets={record.data.targets} />;
  }
  return (
    <Waiting
      petId={id}
      title={t.recordFormEditTitle}
      error={pet.error ?? record.error}
      onRetry={() => {
        void pet.refetch();
        void record.refetch();
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
  kind: CareKind;
  title: string;
  performedOn: string;
  time: string;
  targets: VaccineTarget[];
  product: string;
  manufacturer: string;
  batch: string;
  validFrom: string;
  validUntil: string;
  laboratory: string;
  reportNumber: string;
  titer: string;
  weight: string;
  fitForTravel: boolean;
  clinic: string;
  vet: string;
  notes: string;
}

const snapshot = (values: Values) => JSON.stringify({ ...values, targets: orderedTargets(values.targets) });

function RecordForm({
  pet,
  record,
  kind,
  targets,
}: {
  pet: Pet;
  record: CareRecord | null;
  kind: CareKind;
  targets: VaccineTarget[];
}) {
  const i18n = useI18n();
  const { t, lang } = i18n;
  const { current } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [search] = useSearchParams();
  const toast = useToast();
  const today = useHouseholdDate();
  const form = useRef<HTMLFormElement>(null);
  const [requestId] = useState(() => crypto.randomUUID());
  // Tries of a new record sent so far: a retry may get the record an earlier try made, before a correction since.
  const tries = useRef(0);
  const details = record?.details ?? null;

  const [values, setValues] = useState<Values>(() => ({
    kind,
    title: record?.title ?? defaultRecordTitle(t, kind, targets),
    performedOn: record?.performedOn ?? today,
    time: timeInputValue(record?.performedTime),
    targets,
    product: record?.product ?? '',
    manufacturer: record?.manufacturer ?? '',
    batch: record?.batchNumber ?? '',
    validFrom: record?.validFrom ?? '',
    validUntil: record?.validUntil ?? '',
    laboratory: details?.laboratory ?? '',
    reportNumber: details?.reportNumber ?? '',
    titer: details?.titerIuPerMl != null ? decimalText(lang, details.titerIuPerMl) : '',
    weight: record?.weightKg != null ? decimalText(lang, record.weightKg) : '',
    fitForTravel: details?.fitForTravel ?? false,
    clinic: record?.clinic ?? '',
    vet: record?.veterinarian ?? '',
    notes: record?.notes ?? '',
  }));
  const [opened] = useState(() => snapshot(values));
  const [submitted, setSubmitted] = useState(0);
  const [busy, setBusy] = useState(false);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const { allowLeave } = useLeaveGuard(snapshot(values) !== opened, busy);
  const stillHere = useStillHere(household);
  useFocusFirstError(form, submitted);

  // A field shows when it belongs to the kind, and whenever the record already has a value in it.
  const show = {
    time: usesTime(values.kind) || !!record?.performedTime,
    product: usesProduct(values.kind) || !!(record?.product || record?.manufacturer || record?.batchNumber),
    validity: usesValidity(values.kind) || !!(record?.validFrom || record?.validUntil),
    titer: usesTiter(values.kind) || !!(details?.laboratory || details?.reportNumber || details?.titerIuPerMl != null),
    exam: usesExam(values.kind) || record?.weightKg != null || details?.fitForTravel != null,
  };

  const set = <K extends keyof Values>(field: K, value: Values[K]) => setValues((old) => ({ ...old, [field]: value }));

  /** A new record's title follows its kind (and a vaccine's one target) until something else is typed. */
  function retitle(next: Pick<Values, 'kind' | 'targets'>) {
    setValues((old) => {
      const title = old.title.trim();
      const follows = !record && (!title || title === defaultRecordTitle(t, old.kind, old.targets));
      const targetsNow = usesTargets(next.kind) ? next.targets : [];
      return { ...old, ...next, title: follows ? defaultRecordTitle(t, next.kind, targetsNow) : old.title };
    });
  }

  function problems(required: boolean, refused: Record<string, string[]>) {
    const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
    const tooLong = (value: string, max: number, field: string) =>
      value.trim().length > max ? t.formTooLong(max) : server(field);
    const { performedOn, validFrom, validUntil } = values;
    const titer = values.titer.trim();
    const titerValue = parseDecimal(titer);
    const weight = weightTextProblem(values.weight, RECORD_DECIMALS, false);
    return {
      kind: server('kind'),
      title: required && !values.title.trim() ? t.recordTitleRequired : tooLong(values.title, CARE_MAX.title, 'title'),
      performedOn: !performedOn
        ? required
          ? t.dateRequired
          : null
        : performedOn < EARLIEST_CARE_DATE
          ? t.dateTooEarly
          : performedOn > today
            ? t.dateInFuture
            : server('performedOn'),
      performedTime: server('performedTime'),
      targets: server('targets'),
      product: tooLong(values.product, CARE_MAX.product, 'product'),
      manufacturer: tooLong(values.manufacturer, CARE_MAX.manufacturer, 'manufacturer'),
      batchNumber: tooLong(values.batch, CARE_MAX.batchNumber, 'batchNumber'),
      // The server's rules: protection starts on or after the day it was given, and ends after that day and the start.
      validFrom: validFrom && performedOn && validFrom < performedOn ? t.recordValidFromInvalid : server('validFrom'),
      validUntil:
        validUntil && performedOn && (validUntil <= performedOn || (validFrom && validUntil < validFrom))
          ? t.recordValidUntilInvalid
          : server('validUntil'),
      laboratory: tooLong(values.laboratory, CARE_MAX.laboratory, 'details.laboratory'),
      reportNumber: tooLong(values.reportNumber, CARE_MAX.reportNumber, 'details.reportNumber'),
      titer:
        titer && (titerValue === null || titerValue < 0 || titerValue > CARE_MAX.titer)
          ? t.recordTiterInvalid
          : server('details.titerIuPerMl'),
      weightKg: show.exam && weight ? weightProblemLabel(t, weight, RECORD_DECIMALS) : server('weightKg'),
      clinic: tooLong(values.clinic, CARE_MAX.clinic, 'clinic'),
      veterinarian: tooLong(values.vet, CARE_MAX.veterinarian, 'veterinarian'),
      notes: tooLong(values.notes, CARE_MAX.notes, 'notes'),
    };
  }
  const errors = problems(submitted > 0, serverFields);

  function request(): CareRecordRequest {
    const clean = (value: string) => value.trim() || null;
    const laboratory = show.titer ? clean(values.laboratory) : null;
    const reportNumber = show.titer ? clean(values.reportNumber) : null;
    const titer = show.titer ? parseDecimal(values.titer) : null;
    // A checkbox can't say "not stated": unticked, a record that never said stays silent instead of "not fit".
    const fit = !show.exam ? null : values.fitForTravel ? true : details?.fitForTravel === false ? false : null;
    const hasDetails = laboratory !== null || reportNumber !== null || titer !== null || fit !== null;
    return {
      kind: values.kind,
      title: values.title.trim(),
      performedOn: values.performedOn,
      performedTime: show.time && values.time ? apiTime(values.time) : null,
      product: show.product ? clean(values.product) : null,
      manufacturer: show.product ? clean(values.manufacturer) : null,
      batchNumber: show.product ? clean(values.batch) : null,
      validFrom: show.validity ? values.validFrom || null : null,
      validUntil: show.validity ? values.validUntil || null : null,
      targets: usesTargets(values.kind) ? orderedTargets(values.targets) : [],
      clinic: clean(values.clinic),
      veterinarian: clean(values.vet),
      weightKg: show.exam ? parseDecimal(values.weight) : null,
      details: hasDetails ? { laboratory, reportNumber, titerIuPerMl: titer, fitForTravel: fit } : null,
      notes: clean(values.notes),
      requestId: record ? null : requestId,
    };
  }

  const from = search.get('from');
  const suffix = from ? `?from=${from}` : '';
  const backPath = record ? `/pets/${pet.id}/records/${record.id}${suffix}` : petTabPath(pet.id, backTab(from));

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
      let saved: CareRecord;
      if (record) {
        saved = await data(api.PUT('/api/v1/care-records/{id}', { params: { path: { id: record.id } }, body: sent }));
      } else {
        const retry = tries.current > 0;
        tries.current += 1;
        saved = await data(
          api.POST('/api/v1/pets/{petId}/care-records', { params: { path: { petId: pet.id } }, body: sent }),
        );
        // A retry after a lost answer gets the record as the first try added it: a correction since then follows.
        if (retry && !recordHolds(saved, sent)) {
          saved = await data(
            api.PUT('/api/v1/care-records/{id}', {
              params: { path: { id: saved.id } },
              body: { ...sent, requestId: null },
            }),
          );
        }
      }
      refreshCare(queryClient, household, pet.id);
      allowLeave();
      // On to the record's page, where its photos and files are added.
      if (stillHere()) void navigate(`/pets/${pet.id}/records/${saved.id}${suffix}`, { replace: !record });
    } catch (error) {
      refreshCare(queryClient, household, pet.id);
      if (isNotFound(error)) {
        toast(record ? t.careGoneRecord : t.careGonePet);
        allowLeave();
        if (stillHere()) void navigate(record ? petTabPath(pet.id, 'health') : '/pets');
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

  return (
    <>
      <PageHead
        back={{ to: backPath, label: record ? record.title : pet.name }}
        title={record ? t.recordFormEditTitle : t.recordFormAddTitle}
      />
      <form ref={form} className="form" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
        <fieldset className="form-stack" disabled={busy}>
          <SelectField
            label={t.careKindLabel}
            value={values.kind}
            options={CARE_KINDS.map((each) => ({ value: each, label: t.careKind[each] }))}
            onChange={(next) => retitle({ kind: next, targets: values.targets })}
            error={errors.kind}
          />
          <TextField
            label={t.recordTitleLabel}
            placeholder={t.recordTitleHint}
            value={values.title}
            onChange={(value) => set('title', value)}
            error={errors.title}
          />
          <div className="form-row">
            <DateField
              label={t.recordPerformedOnLabel}
              value={values.performedOn}
              min={EARLIEST_CARE_DATE}
              max={today}
              onChange={(value) => set('performedOn', value)}
              error={errors.performedOn}
            />
            {show.time && (
              <TimeField
                label={t.careTimeLabel}
                hint={t.careTimeHelper}
                value={values.time}
                onChange={(value) => set('time', value)}
                error={errors.performedTime}
              />
            )}
          </div>
          {usesTargets(values.kind) && (
            <MultiChoice
              label={t.careTargetsLabel}
              values={values.targets}
              options={offeredTargets(pet.species, values.targets).map((target) => ({
                value: target,
                label: t.vaccineTarget[target],
              }))}
              onChange={(next) => retitle({ kind: values.kind, targets: next })}
              error={errors.targets}
            />
          )}
          {show.product && (
            <>
              <TextField
                label={t.careProductLabel}
                value={values.product}
                onChange={(value) => set('product', value)}
                error={errors.product}
              />
              <div className="form-row">
                <TextField
                  label={t.careManufacturerLabel}
                  value={values.manufacturer}
                  onChange={(value) => set('manufacturer', value)}
                  error={errors.manufacturer}
                />
                <TextField
                  label={t.careBatchLabel}
                  value={values.batch}
                  onChange={(value) => set('batch', value)}
                  code
                  error={errors.batchNumber}
                />
              </div>
            </>
          )}
          {show.validity && (
            <div className="form-row">
              <DateField
                label={t.careValidFromLabel}
                value={values.validFrom}
                min={values.performedOn || EARLIEST_CARE_DATE}
                max={latestDueDate(today)}
                onChange={(value) => set('validFrom', value)}
                error={errors.validFrom}
              />
              <DateField
                label={t.careValidUntilLabel}
                value={values.validUntil}
                min={values.performedOn || EARLIEST_CARE_DATE}
                max={latestDueDate(today)}
                onChange={(value) => set('validUntil', value)}
                error={errors.validUntil}
              />
            </div>
          )}
          {show.titer && (
            <>
              <div className="form-row">
                <TextField
                  label={t.recordLaboratoryLabel}
                  value={values.laboratory}
                  onChange={(value) => set('laboratory', value)}
                  error={errors.laboratory}
                />
                <TextField
                  label={t.recordReportNumberLabel}
                  value={values.reportNumber}
                  onChange={(value) => set('reportNumber', value)}
                  code
                  error={errors.reportNumber}
                />
              </div>
              <TextField
                label={t.recordTiterLabel}
                hint={t.recordTiterHelper}
                value={values.titer}
                inputMode="decimal"
                onChange={(value) => set('titer', value)}
                error={errors.titer}
              />
            </>
          )}
          {show.exam && (
            <div className="form-row">
              <TextField
                label={t.recordWeightLabel}
                placeholder={t.weightHint}
                value={values.weight}
                inputMode="decimal"
                onChange={(value) => set('weight', value)}
                error={errors.weightKg}
              />
              <CheckboxField
                label={t.recordFitForTravel}
                checked={values.fitForTravel}
                onChange={(value) => set('fitForTravel', value)}
              />
            </div>
          )}
          <div className="form-row">
            <TextField
              label={t.careClinicLabel}
              value={values.clinic}
              onChange={(value) => set('clinic', value)}
              error={errors.clinic}
            />
            <TextField
              label={t.careVetLabel}
              value={values.vet}
              onChange={(value) => set('vet', value)}
              error={errors.veterinarian}
            />
          </div>
          <TextField
            label={t.careNotesLabel}
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
          <button
            type="button"
            className="button button--ghost"
            onClick={() => void navigate(backPath)}
            disabled={busy}
          >
            {t.commonCancel}
          </button>
        </div>
      </form>
    </>
  );
}
