// "Done" for a plan (the phone app's Done screen): when it was done, what was given (the product, its maker and batch,
// for the kinds where something is given), how long a vaccine protects, the clinic, the vet, notes, and the plan's next
// date: worked out the way the server will, or chosen. POST /care-plans/{id}/complete adds the record and moves the
// plan; one id per dialog makes a retry after a lost answer safe (the plan is never marked twice). Helpers mark plans
// done as they are: the server works out the next date. Today and the pet's Health tab open it; photos of the sticker
// are added to the record afterwards, on its page.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { refreshCare, useCarePlan } from '../../api/queries';
import type { CarePlan, CompleteCarePlanRequest } from '../../api/types';
import { Dialog, DialogBody, DialogCancel, DialogFoot, DialogForm } from '../../components/Dialog';
import { DueLine } from '../../components/DueLine';
import { DateField, TextField, TimeField, useFocusFirstError } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { CARE_KIND_ICONS } from '../../components/kindIcons';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, Notice, Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import {
  EARLIEST_CARE_DATE,
  latestDueDate,
  nextDueAfterDone,
  usesProduct,
  usesTime,
  usesValidity,
} from '../../lib/care';
import { apiTime } from '../../lib/dates';
import { intervalLabel } from '../../lib/labels';

// The server's limits.
const MAX = { product: 100, manufacturer: 100, batchNumber: 50, clinic: 200, veterinarian: 100, notes: 2000 };

/** The fields the server's checks can name; a failure about anything else is said in words over the buttons. */
const FIELDS = [
  'performedOn',
  'performedTime',
  'product',
  'manufacturer',
  'batchNumber',
  'validFrom',
  'validUntil',
  'clinic',
  'veterinarian',
  'notes',
  'nextDueOn',
];

/** The plan to mark done, and the name of its pet. */
export interface DoneItem {
  planId: string;
  petName: string;
}

export function DoneDialog({ item, onClose }: { item: DoneItem; onClose: () => void }) {
  const { t } = useI18n();
  const plan = useCarePlan(item.planId);
  const [busy, setBusy] = useState(false);
  // Something typed: closing asks first.
  const [changed, setChanged] = useState(false);
  return (
    <Dialog title={t.doneTitle} onClose={onClose} busy={busy} changed={changed}>
      {plan.data ? (
        <DoneForm plan={plan.data} item={item} busy={busy} setBusy={setBusy} onChanged={setChanged} onClose={onClose} />
      ) : (
        <DialogBody>
          {plan.error ? <ErrorNotice error={plan.error} onRetry={() => void plan.refetch()} /> : <Loading />}
        </DialogBody>
      )}
    </Dialog>
  );
}

function DoneForm({
  plan,
  item,
  busy,
  setBusy,
  onChanged,
  onClose,
}: {
  plan: CarePlan;
  item: DoneItem;
  busy: boolean;
  setBusy: (busy: boolean) => void;
  onChanged: (changed: boolean) => void;
  onClose: () => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const api = useApi();
  const { current, permissions } = useHousehold();
  const queryClient = useQueryClient();
  const toast = useToast();
  const today = useHouseholdDate();
  const form = useRef<HTMLDivElement>(null);

  // One id for this "Done", sent with every try.
  const [requestId] = useState(() => crypto.randomUUID());
  const [performedOn, setPerformedOn] = useState(today);
  const [time, setTime] = useState('');
  // Starts with the plan's usual product; what the field says is sent, so clearing it means "no product".
  const [product, setProduct] = useState(plan.defaultProduct ?? '');
  const [manufacturer, setManufacturer] = useState('');
  const [batch, setBatch] = useState('');
  const [validFrom, setValidFrom] = useState('');
  const [validUntil, setValidUntil] = useState('');
  const [clinic, setClinic] = useState('');
  const [vet, setVet] = useState('');
  const [notes, setNotes] = useState('');
  /** The next date the person picked instead of the worked-out one. */
  const [chosenNext, setChosenNext] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(0);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  useFocusFirstError(form, submitted);

  // Whether closing would lose anything typed.
  const typed = JSON.stringify([
    performedOn,
    time,
    product,
    manufacturer,
    batch,
    validFrom,
    validUntil,
    clinic,
    vet,
    notes,
    chosenNext,
  ]);
  const [opened] = useState(typed);
  useEffect(() => onChanged(typed !== opened), [typed, opened, onChanged]);

  const { kind } = plan;
  // The product is asked where something is given, and whenever the plan has a usual one: it is never dropped unseen.
  const showProduct = usesProduct(kind) || !!plan.defaultProduct;
  const interval =
    plan.intervalValue && plan.intervalUnit ? { value: plan.intervalValue, unit: plan.intervalUnit } : null;
  const next = nextDueAfterDone({
    interval,
    performedOn: performedOn || today,
    validUntil: usesValidity(kind) && validUntil ? validUntil : null,
    chosen: chosenNext,
  });

  /** The form's own checks (`required`: after a first "Save"), and the server's word on fields it refused. */
  function problems(required: boolean, refused: Record<string, string[]>): Record<string, string | null> {
    const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
    const tooLong = (value: string, field: keyof typeof MAX) =>
      value.trim().length > MAX[field] ? t.formTooLong(MAX[field]) : server(field);
    return {
      performedOn: required && !performedOn ? t.dateRequired : server('performedOn'),
      performedTime: server('performedTime'),
      product: tooLong(product, 'product'),
      manufacturer: tooLong(manufacturer, 'manufacturer'),
      batchNumber: tooLong(batch, 'batchNumber'),
      // The server's rules: protection starts on or after the day it was given, and ends after that day and the start.
      validFrom: validFrom && performedOn && validFrom < performedOn ? t.recordValidFromInvalid : server('validFrom'),
      validUntil:
        validUntil && performedOn && (validUntil <= performedOn || (validFrom && validUntil < validFrom))
          ? t.recordValidUntilInvalid
          : server('validUntil'),
      clinic: tooLong(clinic, 'clinic'),
      veterinarian: tooLong(vet, 'veterinarian'),
      notes: tooLong(notes, 'notes'),
      nextDueOn: server('nextDueOn'),
    };
  }
  const errors = problems(submitted > 0, serverFields);

  async function save() {
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(problems(true, {})).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }
    const clean = (value: string) => value.trim() || null;
    const body: CompleteCarePlanRequest = {
      performedOn,
      performedTime: usesTime(kind) && time ? apiTime(time) : null,
      product: showProduct ? clean(product) : null,
      manufacturer: showProduct ? clean(manufacturer) : null,
      batchNumber: showProduct ? clean(batch) : null,
      validFrom: usesValidity(kind) ? validFrom || null : null,
      validUntil: usesValidity(kind) ? validUntil || null : null,
      clinic: clean(clinic),
      veterinarian: clean(vet),
      notes: clean(notes),
      nextDueOn: chosenNext,
      requestId,
    };
    setBusy(true);
    try {
      const done = await data(
        api.POST('/api/v1/care-plans/{id}/complete', { params: { path: { id: plan.id } }, body }),
      );
      const nextDue = done.plan.active ? done.plan.nextDueOn : null;
      toast(nextDue ? t.doneSaved(i18n.date(nextDue)) : t.doneSavedFinished);
      onClose();
    } catch (error) {
      if (isNotFound(error)) {
        // Deleted on another device: there is nothing left to mark.
        toast(t.careGonePlan);
        onClose();
        return;
      }
      const fields = fieldErrorsOf(error);
      const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => FIELDS.includes(field));
      setServerFields(placed ? fields : {});
      setFailure(placed ? t.formCheckFields : errorMessage(t, error));
      if (placed) setSubmitted((value) => value + 1);
      setBusy(false);
    } finally {
      // Whatever happened, the lists show the server's truth: part of it may have gone through. The new record shows
      // in the history and the passport too.
      refreshCare(queryClient, current.id, plan.petId);
    }
  }

  let explanation: string;
  if (chosenNext) explanation = t.doneNextChosen;
  else if (!next) explanation = t.doneNextFinished;
  else if (usesValidity(kind) && validUntil && interval) explanation = t.doneNextFromValidUntil;
  else explanation = t.doneNextFromInterval(intervalLabel(t, plan.intervalValue, plan.intervalUnit));

  return (
    <DialogForm onSubmit={() => void save()} busy={busy}>
      <DialogBody>
        <div className="form-stack" ref={form}>
          <div className="plan-head">
            <span className="kind-icon">
              <Icon name={CARE_KIND_ICONS[kind]} />
            </span>
            <div>
              <p className="plan-title">{plan.title}</p>
              <p className="muted small">
                {item.petName} · {intervalLabel(t, plan.intervalValue, plan.intervalUnit)}
              </p>
              <DueLine status={plan.status} daysLeft={plan.daysLeft} dueOn={plan.nextDueOn} />
            </div>
          </div>
          <DateField
            label={t.donePerformedOnLabel}
            value={performedOn}
            onChange={(value) => {
              setPerformedOn(value);
              // A chosen next date can't be before this one.
              if (chosenNext && value && chosenNext < value) setChosenNext(null);
            }}
            min={EARLIEST_CARE_DATE}
            max={today}
            error={errors.performedOn}
          />
          {usesTime(kind) && (
            <TimeField
              label={t.careTimeLabel}
              hint={t.careTimeHelper}
              value={time}
              onChange={setTime}
              error={errors.performedTime}
            />
          )}
          {showProduct && (
            <>
              <TextField label={t.careProductLabel} value={product} onChange={setProduct} error={errors.product} />
              <div className="form-row">
                <TextField
                  label={t.careManufacturerLabel}
                  value={manufacturer}
                  onChange={setManufacturer}
                  error={errors.manufacturer}
                />
                <TextField label={t.careBatchLabel} value={batch} onChange={setBatch} code error={errors.batchNumber} />
              </div>
            </>
          )}
          {usesValidity(kind) && (
            <div className="form-row">
              <DateField
                label={t.careValidFromLabel}
                value={validFrom}
                onChange={setValidFrom}
                min={performedOn || undefined}
                error={errors.validFrom}
              />
              <DateField
                label={t.careValidUntilLabel}
                hint={t.doneValidUntilHelper}
                value={validUntil}
                onChange={setValidUntil}
                min={performedOn || undefined}
                max={latestDueDate(today)}
                error={errors.validUntil}
              />
            </div>
          )}
          <div className="form-row">
            <TextField label={t.careClinicLabel} value={clinic} onChange={setClinic} error={errors.clinic} />
            <TextField label={t.careVetLabel} value={vet} onChange={setVet} error={errors.veterinarian} />
          </div>
          <TextField label={t.careNotesLabel} value={notes} onChange={setNotes} rows={3} error={errors.notes} />
          <div className="next-date">
            <p className="field-label">{t.doneNextTitle}</p>
            {next && <p className="next-date-value">{i18n.date(next)}</p>}
            <p className="muted small">{explanation}</p>
            {errors.nextDueOn && <Notice tone="danger">{errors.nextDueOn}</Notice>}
            {/* Helpers' "Done" takes the worked-out date. */}
            {permissions.canEdit &&
              (chosenNext === null ? (
                <button
                  type="button"
                  className="button button--ghost"
                  onClick={() => setChosenNext(next ?? (performedOn || today))}
                >
                  {t.doneNextChange}
                </button>
              ) : (
                <div className="next-date-choice">
                  <DateField
                    label={t.doneNextLabel}
                    value={chosenNext}
                    onChange={(value) => setChosenNext(value || null)}
                    min={performedOn || undefined}
                    max={latestDueDate(today)}
                  />
                  <button type="button" className="button button--ghost" onClick={() => setChosenNext(null)}>
                    {t.doneNextReset}
                  </button>
                </div>
              ))}
          </div>
        </div>
      </DialogBody>
      <DialogFoot>
        {failure && (
          <p className="form-error" role="alert">
            <Icon name="error" size={18} />
            {failure}
          </p>
        )}
        <DialogCancel disabled={busy} />
        <button type="submit" className="button button--primary" disabled={busy}>
          {busy && <Spinner />}
          {busy ? t.commonSaving : t.commonSave}
        </button>
      </DialogFoot>
    </DialogForm>
  );
}
