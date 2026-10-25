// A weighing (the phone app's weighing_sheet.dart), added or changed: the day, the weight in kilograms to the gram
// (typed with a point or a comma), a body condition score when wanted (on the 9- or the 5-point scale) and a note; a
// weighing that exists can be deleted after a question. One id per new weighing, kept across tries: a retry after a
// lost answer adds nothing twice, and gets the weighing as the first try saved it; a correction typed since then goes
// after it (PUT).
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import type { Pet, Weight, WeightRequest } from '../../api/types';
import { ConfirmDialog, Dialog, DialogBody, DialogCancel, DialogFoot, DialogForm } from '../../components/Dialog';
import { ChoiceGroup, DateField, TextField, useFocusFirstError } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useToast } from '../../components/Toasts';
import { Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { weightNumberLabel, weightProblemLabel } from '../../lib/labels';
import { parseDecimal } from '../../lib/numbers';
import {
  BCS_SCALES,
  bcsIdeal,
  EARLIEST_WEIGHT_DATE,
  firstWeighingDate,
  grams,
  MAX_WEIGHT_NOTE,
  WEIGHING_DECIMALS,
  weightTextProblem,
  type BcsScale,
} from '../../lib/weight';

const FIELDS = ['measuredOn', 'weightKg', 'bcs', 'bcsScale', 'note'];

interface Values {
  measuredOn: string;
  weight: string;
  /** The score is folded away until asked for. */
  scoring: boolean;
  scale: BcsScale;
  score: number | null;
  note: string;
}

/** Whether the weighing the server answered with says what was sent, as the server keeps it (to the gram). */
export function weighingHolds(saved: Weight, sent: WeightRequest): boolean {
  return (
    saved.measuredOn === sent.measuredOn &&
    grams(saved.weightKg) === grams(sent.weightKg) &&
    saved.bcs === sent.bcs &&
    (saved.bcs === null || saved.bcsScale === sent.bcsScale) &&
    (saved.note ?? '') === (sent.note ?? '')
  );
}

export function WeightDialog({ pet, weighing, onClose }: { pet: Pet; weighing: Weight | null; onClose: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { current } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const toast = useToast();
  const today = useHouseholdDate();
  const body = useRef<HTMLDivElement>(null);
  // One id for adding this weighing, sent with every try.
  const [requestId] = useState(() => crypto.randomUUID());
  const [values, setValues] = useState<Values>(() => ({
    measuredOn: weighing?.measuredOn ?? today,
    weight: weighing ? weightNumberLabel(i18n, weighing.weightKg).replace(/\s/g, '') : '',
    scoring: weighing?.bcs != null,
    scale: weighing?.bcsScale === 5 ? 5 : 9,
    score: weighing?.bcs ?? null,
    note: weighing?.note ?? '',
  }));
  const [opened] = useState(() => JSON.stringify(values));
  const [submitted, setSubmitted] = useState(0);
  const [busy, setBusy] = useState(false);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  useFocusFirstError(body, submitted);
  const first = firstWeighingDate(pet, today);

  const set = <K extends keyof Values>(field: K, value: Values[K]) => setValues((old) => ({ ...old, [field]: value }));

  function problems(required: boolean, refused: Record<string, string[]>) {
    const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
    const { measuredOn } = values;
    const weight = weightTextProblem(values.weight, WEIGHING_DECIMALS, required);
    return {
      measuredOn: !measuredOn
        ? required
          ? t.dateRequired
          : null
        : measuredOn < EARLIEST_WEIGHT_DATE
          ? t.dateTooEarly
          : measuredOn > today
            ? t.dateInFuture
            : // Like the server, the birth date checks only a new date: an old weighing keeps its day.
              measuredOn < first && measuredOn !== weighing?.measuredOn
              ? t.weightDateBeforeBirth
              : server('measuredOn'),
      weightKg: weight ? weightProblemLabel(t, weight, WEIGHING_DECIMALS) : server('weightKg'),
      bcs: server('bcs') ?? server('bcsScale'),
      note: values.note.trim().length > MAX_WEIGHT_NOTE ? t.formTooLong(MAX_WEIGHT_NOTE) : server('note'),
    };
  }
  const errors = problems(submitted > 0, serverFields);

  function request(): WeightRequest {
    const note = values.note.trim();
    // An open score without a pick says nothing: it isn't sent.
    const scored = values.scoring && values.score !== null;
    return {
      measuredOn: values.measuredOn,
      weightKg: grams(parseDecimal(values.weight)!) / 1000,
      bcs: scored ? values.score : null,
      bcsScale: scored ? values.scale : null,
      note: note || null,
      requestId: weighing ? null : requestId,
    };
  }

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: keys.weights(household, pet.id) });
  }

  async function save() {
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(problems(true, {})).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }
    const sent = request();
    setBusy(true);
    try {
      if (weighing) {
        await api.PUT('/api/v1/weights/{id}', { params: { path: { id: weighing.id } }, body: sent });
      } else {
        const added = await data(
          api.POST('/api/v1/pets/{petId}/weights', { params: { path: { petId: pet.id } }, body: sent }),
        );
        // A retry after a lost answer gets the weighing as the first try added it: a correction since then follows.
        if (!weighingHolds(added, sent)) {
          await api.PUT('/api/v1/weights/{id}', {
            params: { path: { id: added.id } },
            body: { ...sent, requestId: null },
          });
        }
      }
      refresh();
      onClose();
    } catch (error) {
      refresh();
      if (isNotFound(error)) {
        // The weighing (or, when adding, the pet) was deleted elsewhere: there is nothing left to save.
        toast(weighing ? t.weightGone : t.careGonePet);
        onClose();
        return;
      }
      const fields = fieldErrorsOf(error);
      const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => FIELDS.includes(field));
      setServerFields(placed ? fields : {});
      setFailure(placed ? t.formCheckFields : errorMessage(t, error));
      if (placed) setSubmitted((value) => value + 1);
    } finally {
      setBusy(false);
    }
  }

  async function remove(target: Weight) {
    setBusy(true);
    setFailure(null);
    try {
      await api.DELETE('/api/v1/weights/{id}', { params: { path: { id: target.id } } });
      refresh();
      onClose();
    } catch (error) {
      refresh();
      // Deleted elsewhere already: what was wanted.
      if (isNotFound(error)) {
        onClose();
        return;
      }
      setDeleting(false);
      setFailure(errorMessage(t, error));
      setBusy(false);
    }
  }

  return (
    <Dialog
      title={weighing ? t.weightEditTitle : t.weightAddTitle}
      onClose={onClose}
      busy={busy}
      changed={JSON.stringify(values) !== opened}
    >
      <DialogForm onSubmit={() => void save()} busy={busy}>
        <DialogBody>
          <div className="form-stack" ref={body}>
            <DateField
              label={t.weightMeasuredOnLabel}
              value={values.measuredOn}
              min={first}
              max={today}
              onChange={(measuredOn) => set('measuredOn', measuredOn)}
              error={errors.measuredOn}
            />
            <TextField
              label={t.recordWeightLabel}
              placeholder={t.weightHint}
              value={values.weight}
              inputMode="decimal"
              autoComplete="off"
              onChange={(weight) => set('weight', weight.replace(/[^\d.,]/g, ''))}
              error={errors.weightKg}
            />
            {values.scoring ? (
              <div className="bcs">
                <ChoiceGroup
                  label={t.weightBcsScaleLabel}
                  value={String(values.scale) as '9' | '5'}
                  options={BCS_SCALES.map((scale) => ({
                    value: String(scale) as '9' | '5',
                    label: t.weightBcsScale(scale),
                  }))}
                  onChange={(scale) =>
                    // A score on one scale means nothing on the other.
                    setValues((old) => ({
                      ...old,
                      scale: Number(scale) as BcsScale,
                      score: Number(scale) === old.scale ? old.score : null,
                    }))
                  }
                />
                <ChoiceGroup
                  label={t.weightBcsLabel}
                  value={values.score === null ? null : String(values.score)}
                  options={Array.from({ length: values.scale }, (_, index) => ({
                    value: String(index + 1),
                    label: String(index + 1),
                  }))}
                  onChange={(score) => set('score', Number(score))}
                  hint={t.weightBcsHelp(bcsIdeal(values.scale), values.scale)}
                  error={errors.bcs}
                />
                <button
                  type="button"
                  className="button button--ghost"
                  onClick={() => setValues((old) => ({ ...old, scoring: false, score: null, scale: 9 }))}
                >
                  {t.weightBcsRemove}
                </button>
              </div>
            ) : (
              <button
                type="button"
                className="button button--ghost align-start"
                onClick={() => set('scoring', true)}
              >
                <Icon name="add" size={18} />
                {t.weightBcsAdd}
              </button>
            )}
            <TextField
              label={t.weightNoteLabel}
              placeholder={t.weightNoteHint}
              value={values.note}
              rows={2}
              onChange={(note) => set('note', note)}
              error={errors.note}
            />
          </div>
        </DialogBody>
        <DialogFoot>
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          {weighing && (
            <button
              type="button"
              className="button button--ghost button--danger-text dialog-foot-start"
              onClick={() => setDeleting(true)}
              disabled={busy}
            >
              <Icon name="delete" />
              {t.weightDelete}
            </button>
          )}
          <DialogCancel disabled={busy} />
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {busy ? t.commonSaving : t.commonSave}
          </button>
        </DialogFoot>
      </DialogForm>
      {deleting && weighing && (
        <ConfirmDialog
          title={t.weightDeleteTitle}
          body={t.weightDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={busy}
          onConfirm={() => void remove(weighing)}
          onCancel={() => setDeleting(false)}
        />
      )}
    </Dialog>
  );
}
