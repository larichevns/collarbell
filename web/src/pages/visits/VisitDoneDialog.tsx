// "The visit took place" (the phone app's visit-done sheet): whether to write it into the pets' care history (a
// check-up after the vet, grooming after the groomer) and which of their plans it completes, e.g. the yearly check-up.
// POST /appointments/{id}/complete: each pet gets a record of the chosen kind, and the chosen plans count as "Done".
import { useQueries, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf } from '../../api/errors';
import { keys } from '../../api/keys';
import { refreshCare, usePets } from '../../api/queries';
import type { CareKind, CarePlan, VisitType } from '../../api/types';
import { Dialog, DialogBody, DialogCancel, DialogFoot, DialogForm } from '../../components/Dialog';
import { CheckboxField, ChoiceGroup, TextField } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useToast } from '../../components/Toasts';
import { Loading, Spinner } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';

/** The kinds of record a visit can become. */
const RECORD_KINDS: readonly CareKind[] = ['VetExam', 'Dental', 'Grooming', 'Procedure', 'Other'];

/** The record a visit of this type usually becomes; none for training and the rest. */
function usualKind(type: VisitType): CareKind | null {
  return type === 'Vet' ? 'VetExam' : type === 'Grooming' ? 'Grooming' : null;
}

export function VisitDoneDialog({
  visit,
  onClose,
}: {
  visit: { id: string; type: VisitType; petIds: string[] };
  onClose: () => void;
}) {
  const { t } = useI18n();
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  const toast = useToast();
  const pets = usePets().data;
  const [writeRecord, setWriteRecord] = useState(usualKind(visit.type) !== null);
  const [kind, setKind] = useState<CareKind>(usualKind(visit.type) ?? 'VetExam');
  /** The plan picked by hand for a pet (null: none); the others follow the suggestion. */
  const [picked, setPicked] = useState<ReadonlyMap<string, string | null>>(new Map());
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  const plans = useQueries({
    queries: visit.petIds.map((petId) => ({
      queryKey: keys.carePlans(current.id, petId),
      queryFn: ({ signal }: { signal: AbortSignal }) =>
        data(api.GET('/api/v1/pets/{petId}/care-plans', { params: { path: { petId } }, signal })),
      enabled: writeRecord,
    })),
  });

  /** The pet's active plans of the chosen kind. */
  const matching = (index: number): CarePlan[] =>
    (plans[index]?.data ?? []).filter((plan) => plan.active && plan.kind === kind);

  /** The only matching plan, when it repeats: a one-off plan (a check before a trip) isn't closed by just any visit. */
  function chosen(petId: string, index: number): string | null {
    if (picked.has(petId)) return picked.get(petId) ?? null;
    const only = matching(index);
    return only.length === 1 && only[0]!.intervalValue !== null ? only[0]!.id : null;
  }

  async function save() {
    setBusy(true);
    setFailure(null);
    const planIds = writeRecord
      ? visit.petIds.map((petId, index) => chosen(petId, index)).filter((id): id is string => id !== null)
      : [];
    try {
      const done = await data(
        api.POST('/api/v1/appointments/{id}/complete', {
          params: { path: { id: visit.id } },
          body: { recordKind: writeRecord ? kind : null, planIds, notes: notes.trim() || null },
        }),
      );
      toast(done.movedPlanIds.length ? t.visitDoneSavedPlans(done.movedPlanIds.length) : t.visitDoneSaved);
      onClose();
    } catch (error) {
      // Cancelled meanwhile, or not happened yet: say so rather than "check the fields".
      setFailure('status' in fieldErrorsOf(error) ? t.visitDoneNotPossible : errorMessage(t, error));
      setBusy(false);
    } finally {
      void queryClient.invalidateQueries({ queryKey: keys.visits(current.id) });
      // The records the visit made show in the pets' history and passports.
      refreshCare(queryClient, current.id);
    }
  }

  const petName = (id: string) => pets?.find((pet) => pet.id === id)?.name ?? '';

  return (
    <Dialog
      title={t.visitDoneTitle}
      onClose={onClose}
      busy={busy}
      // Something typed or chosen: closing asks first.
      changed={notes.trim() !== '' || picked.size > 0 || writeRecord !== (usualKind(visit.type) !== null)}
    >
      <DialogForm onSubmit={() => void save()} busy={busy}>
        <DialogBody>
          <div className="form-stack">
            <CheckboxField
              label={t.visitDoneWriteRecord}
              hint={t.visitDoneWriteRecordHelper}
              checked={writeRecord}
              onChange={setWriteRecord}
            />
            {writeRecord && (
              <>
                <ChoiceGroup
                  label={t.visitDoneKindLabel}
                  value={kind}
                  options={RECORD_KINDS.map((value) => ({ value, label: t.careKind[value] }))}
                  onChange={(value) => {
                    setKind(value);
                    // Other plans now: start from the suggestion again.
                    setPicked(new Map());
                  }}
                />
                {plans.some((plan) => plan.isPending) ? (
                  <Loading />
                ) : (
                  visit.petIds.flatMap((petId, index) =>
                    matching(index).map((plan) => (
                      <CheckboxField
                        key={plan.id}
                        label={t.visitDonePlan(plan.title)}
                        hint={petName(petId)}
                        checked={chosen(petId, index) === plan.id}
                        onChange={(on) => setPicked((old) => new Map(old).set(petId, on ? plan.id : null))}
                      />
                    )),
                  )
                )}
              </>
            )}
            <TextField
              label={t.visitDoneNotesLabel}
              placeholder={t.visitDoneNotesHint}
              value={notes}
              onChange={setNotes}
              rows={3}
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
          <DialogCancel disabled={busy} />
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {t.visitDone}
          </button>
        </DialogFoot>
      </DialogForm>
    </Dialog>
  );
}
