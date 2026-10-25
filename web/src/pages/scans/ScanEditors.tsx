// Editors of one entry of a scan (the phone app's scan_editors.dart), opened from the review: the fields of the record
// form (or the microchip's, the passport's, the weighing's), with where the entry was read on top and the AI's doubts
// under its fields until they are changed. They change a copy of the entry and hand it back on "Done"; "Cancel" drops
// the changes (asking first when something was typed). Nothing is saved here: the review saves.
import { useState, type ReactNode } from 'react';
import type { CarePlan, IdentifierType, Pet } from '../../api/types';
import { Dialog, DialogBody, DialogCancel, DialogFoot, DialogForm } from '../../components/Dialog';
import { DateField, MultiChoice, SelectField, TextField, TimeField } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { CARE_KIND_ICONS } from '../../components/kindIcons';
import { Notice } from '../../components/ui';
import { useI18n } from '../../i18n/i18n';
import {
  CARE_KINDS,
  EARLIEST_CARE_DATE,
  latestDueDate,
  offeredTargets,
  orderedTargets,
  usesExam,
  usesProduct,
  usesTargets,
  usesTime,
} from '../../lib/care';
import { apiTime, timeInputValue } from '../../lib/dates';
import { intervalLabel, weightNumberLabel, weightProblemLabel } from '../../lib/labels';
import { decimalText, parseDecimal } from '../../lib/numbers';
import { firstWeighingDate, grams, RECORD_DECIMALS, WEIGHING_DECIMALS, weightTextProblem } from '../../lib/weight';
import { Evidence } from './DraftCards';
import { draftIssueMessage, scanDefaultTitle } from './labels';
import {
  fieldWarnings,
  identifierProblems,
  markIdentifierChanges,
  markPassportChanges,
  markRecordChanges,
  markWeightChanges,
  passportProblems,
  recordProblems,
  weightProblems,
  type ReviewEntry,
  type ReviewIdentifier,
  type ReviewPassport,
  type ReviewRecord,
  type ReviewWeight,
} from './review';

interface EditorProps<T extends ReviewEntry> {
  entry: T;
  today: string;
  fromNote: boolean;
  /** Opens the photo the entry was read from; null when there is none. */
  onOpenPage: (() => void) | null;
  onDone: (edited: T) => void;
  onClose: () => void;
}

/**
 * The problems an editor can do something about: those of its own fields. The rest (a plan link the server refused,
 * the entry as a whole, the pet's five microchips) stay on the review's card, and don't keep "Done" from closing.
 */
function ownProblems(problems: Record<string, string>, fields: readonly string[]): Record<string, string> {
  return Object.fromEntries(Object.entries(problems).filter(([field]) => fields.includes(field)));
}

const RECORD_FIELDS = [
  'kind',
  'title',
  'performedOn',
  'performedTime',
  'targets',
  'product',
  'manufacturer',
  'batchNumber',
  'validFrom',
  'validUntil',
  'weightKg',
  'veterinarian',
  'clinic',
];

/** The AI's doubts about `field` of `entry` in words, until it is changed; null when there are none. */
function useDoubt(entry: ReviewEntry, fromNote: boolean) {
  const { t } = useI18n();
  return (field: string): string | null => {
    const texts = fieldWarnings(entry)
      .filter((warning) => warning.field === field)
      .map((warning) => draftIssueMessage(t, warning.issue, { fromNote }));
    return texts.length ? texts.join(' ') : null;
  };
}

/** The frame of an editor: where the entry was read, its fields, "Done". */
function EditorDialog({
  title,
  entry,
  fromNote,
  onOpenPage,
  changed,
  failure,
  onDone,
  onClose,
  children,
}: {
  title: string;
  entry: ReviewEntry;
  fromNote: boolean;
  onOpenPage: (() => void) | null;
  changed: boolean;
  failure: string | null;
  onDone: () => void;
  onClose: () => void;
  children: ReactNode;
}) {
  const { t } = useI18n();
  return (
    <Dialog title={title} onClose={onClose} changed={changed}>
      <DialogForm onSubmit={onDone} busy={false}>
        <DialogBody>
          <div className="form-stack">
            <Evidence page={entry.draft.page} evidence={entry.draft.evidence} onOpen={onOpenPage} fromNote={fromNote} />
            {children}
          </div>
        </DialogBody>
        <DialogFoot>
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <DialogCancel />
          <button type="submit" className="button button--primary">
            {t.scanEditDone}
          </button>
        </DialogFoot>
      </DialogForm>
    </Dialog>
  );
}

export function RecordEditor({ entry, pet, today, fromNote, onOpenPage, onDone, onClose }: EditorProps<ReviewRecord> & { pet: Pet }) {
  const i18n = useI18n();
  const { t, lang } = i18n;
  // What the title shows for a record without a title of its own: left as it is, the record keeps going under its
  // kind's name, which then follows a new kind.
  const [defaultTitle] = useState(() => scanDefaultTitle(t, entry.kind, entry.targets));
  const [values, setValues] = useState(() => ({
    kind: entry.kind,
    title: entry.title ?? defaultTitle,
    performedOn: entry.performedOn ?? '',
    time: timeInputValue(entry.performedTime),
    targets: entry.targets,
    product: entry.product ?? '',
    manufacturer: entry.manufacturer ?? '',
    batch: entry.batchNumber ?? '',
    validFrom: entry.validFrom ?? '',
    validUntil: entry.validUntil ?? '',
    weight: entry.weightKg !== null ? decimalText(lang, entry.weightKg) : '',
    vet: entry.veterinarian ?? '',
    clinic: entry.clinic ?? '',
  }));
  const [opened] = useState(() => JSON.stringify(values));
  const [submitted, setSubmitted] = useState(false);
  const set = <K extends keyof typeof values>(field: K, value: (typeof values)[K]) =>
    setValues((old) => ({ ...old, [field]: value }));

  // A field shows when it belongs to the kind, and whenever the entry has a value in it, so a value is never dropped
  // unseen. The weight only while it is a check-up: the server keeps a weight on no other kind.
  const show = {
    time: usesTime(values.kind) || entry.performedTime !== null,
    product: usesProduct(values.kind) || !!(entry.product || entry.manufacturer || entry.batchNumber),
    validity: usesTargets(values.kind) || !!(entry.validFrom || entry.validUntil),
    weight: usesExam(values.kind),
  };

  function result(): ReviewRecord {
    const clean = (value: string) => value.trim() || null;
    const title = values.title.trim();
    return markRecordChanges(entry, {
      ...entry,
      kind: values.kind,
      title: entry.title === null && title === defaultTitle ? null : title,
      performedOn: values.performedOn || null,
      performedTime: show.time && values.time ? apiTime(values.time) : null,
      targets: orderedTargets(values.targets),
      product: show.product ? clean(values.product) : null,
      manufacturer: show.product ? clean(values.manufacturer) : null,
      batchNumber: show.product ? clean(values.batch) : null,
      validFrom: show.validity ? values.validFrom || null : null,
      validUntil: show.validity ? values.validUntil || null : null,
      weightKg: show.weight ? parseDecimal(values.weight) : null,
      veterinarian: clean(values.vet),
      clinic: clean(values.clinic),
    });
  }

  const edited = result();
  const doubt = useDoubt(edited, fromNote);
  // A check-up record keeps its weight to 10 g.
  const weightText = show.weight ? weightTextProblem(values.weight, RECORD_DECIMALS, false) : null;
  const problems = ownProblems(
    {
      ...recordProblems(t, edited, today),
      ...(weightText ? { weightKg: weightProblemLabel(t, weightText, RECORD_DECIMALS) } : {}),
    },
    RECORD_FIELDS,
  );
  const error = (field: string) => (submitted ? (problems[field] ?? null) : null);

  return (
    <EditorDialog
      title={t.scanEditRecordTitle}
      entry={entry}
      fromNote={fromNote}
      onOpenPage={onOpenPage}
      changed={JSON.stringify(values) !== opened}
      failure={submitted && Object.keys(problems).length ? t.formCheckFields : null}
      onDone={() => {
        setSubmitted(true);
        if (!Object.keys(problems).length) onDone(edited);
      }}
      onClose={onClose}
    >
      <SelectField
        label={t.careKindLabel}
        value={values.kind}
        options={CARE_KINDS.map((kind) => ({ value: kind, label: t.careKind[kind] }))}
        onChange={(kind) => set('kind', kind)}
        error={error('kind')}
      />
      <TextField
        label={t.recordTitleLabel}
        placeholder={t.recordTitleHint}
        value={values.title}
        onChange={(title) => set('title', title)}
        error={error('title')}
      />
      <div className="form-row">
        <DateField
          label={t.recordPerformedOnLabel}
          value={values.performedOn}
          min={EARLIEST_CARE_DATE}
          max={today}
          hint={doubt('performedOn')}
          onChange={(date) => set('performedOn', date)}
          error={error('performedOn')}
        />
        {show.time && (
          <TimeField
            label={t.careTimeLabel}
            hint={doubt('performedTime') ?? t.careTimeHelper}
            value={values.time}
            onChange={(time) => set('time', time)}
            error={error('performedTime')}
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
          onChange={(targets) => set('targets', targets)}
          error={error('targets')}
        />
      )}
      {show.product && (
        <>
          <TextField
            label={t.careProductLabel}
            value={values.product}
            onChange={(product) => set('product', product)}
            error={error('product')}
          />
          <div className="form-row">
            <TextField
              label={t.careManufacturerLabel}
              value={values.manufacturer}
              onChange={(manufacturer) => set('manufacturer', manufacturer)}
              error={error('manufacturer')}
            />
            <TextField
              label={t.careBatchLabel}
              value={values.batch}
              code
              onChange={(batch) => set('batch', batch)}
              error={error('batchNumber')}
            />
          </div>
        </>
      )}
      {show.validity && (
        <div className="form-row">
          <DateField
            label={t.careValidFromLabel}
            value={values.validFrom}
            min={EARLIEST_CARE_DATE}
            max={latestDueDate(today)}
            hint={doubt('validFrom')}
            onChange={(date) => set('validFrom', date)}
            error={error('validFrom')}
          />
          <DateField
            label={t.careValidUntilLabel}
            value={values.validUntil}
            min={EARLIEST_CARE_DATE}
            max={latestDueDate(today)}
            hint={doubt('validUntil')}
            onChange={(date) => set('validUntil', date)}
            error={error('validUntil')}
          />
        </div>
      )}
      {show.weight && (
        <TextField
          label={t.recordWeightLabel}
          placeholder={t.weightHint}
          value={values.weight}
          inputMode="decimal"
          autoComplete="off"
          hint={doubt('weightKg')}
          onChange={(weight) => set('weight', weight.replace(/[^\d.,]/g, ''))}
          error={error('weightKg')}
        />
      )}
      <div className="form-row">
        <TextField label={t.careVetLabel} value={values.vet} onChange={(vet) => set('vet', vet)} error={error('veterinarian')} />
        <TextField
          label={t.careClinicLabel}
          value={values.clinic}
          onChange={(clinic) => set('clinic', clinic)}
          error={error('clinic')}
        />
      </div>
    </EditorDialog>
  );
}

const IDENTIFIER_TYPES: readonly IdentifierType[] = ['IsoChip', 'LegacyChip', 'Tattoo'];

export function IdentifierEditor({
  entry,
  otherCodes,
  today,
  fromNote,
  onOpenPage,
  onDone,
  onClose,
}: EditorProps<ReviewIdentifier> & { otherCodes: readonly string[] }) {
  const { t } = useI18n();
  const [values, setValues] = useState(() => ({
    type: entry.type,
    code: entry.code,
    appliedOn: entry.appliedOn ?? '',
    location: entry.location ?? '',
  }));
  const [opened] = useState(() => JSON.stringify(values));
  const [submitted, setSubmitted] = useState(false);
  const set = <K extends keyof typeof values>(field: K, value: (typeof values)[K]) =>
    setValues((old) => ({ ...old, [field]: value }));
  const edited = markIdentifierChanges(entry, {
    ...entry,
    type: values.type,
    code: values.code.trim(),
    appliedOn: values.appliedOn || null,
    location: values.location.trim() || null,
  });
  const doubt = useDoubt(edited, fromNote);
  const problems = ownProblems(identifierProblems(t, edited, today, otherCodes), [
    'type',
    'code',
    'appliedOn',
    'location',
  ]);
  const error = (field: string) => (submitted ? (problems[field] ?? null) : null);
  const tattoo = values.type === 'Tattoo';
  const hint = values.type === 'IsoChip' ? t.identifierIsoHint : values.type === 'LegacyChip' ? t.identifierLegacyHint : null;
  return (
    <EditorDialog
      title={t.scanEditIdentifierTitle}
      entry={entry}
      fromNote={fromNote}
      onOpenPage={onOpenPage}
      changed={JSON.stringify(values) !== opened}
      failure={submitted && Object.keys(problems).length ? t.formCheckFields : null}
      onDone={() => {
        setSubmitted(true);
        if (!Object.keys(problems).length) onDone(edited);
      }}
      onClose={onClose}
    >
      <SelectField
        label={t.identifierTypeLabel}
        value={values.type}
        options={IDENTIFIER_TYPES.map((type) => ({ value: type, label: t.identifierType[type] }))}
        onChange={(type) => set('type', type)}
        error={error('type')}
      />
      <TextField
        label={tattoo ? t.identifierTattooLabel : t.identifierChipLabel}
        value={values.code}
        code
        autoComplete="off"
        inputMode={values.type === 'IsoChip' ? 'numeric' : 'text'}
        hint={doubt('code') ?? hint}
        onChange={(code) => set('code', code)}
        error={error('code')}
      />
      <DateField
        label={tattoo ? t.identifierTattooDateLabel : t.identifierChipDateLabel}
        value={values.appliedOn}
        max={today}
        hint={doubt('appliedOn')}
        onChange={(date) => set('appliedOn', date)}
        error={error('appliedOn')}
      />
      <TextField
        label={t.identifierLocationLabel}
        placeholder={t.identifierLocationHint}
        value={values.location}
        hint={doubt('location')}
        onChange={(location) => set('location', location)}
        error={error('location')}
      />
    </EditorDialog>
  );
}

/** The passport details, with what is saved under each field: an empty field keeps it, a value changed replaces it. */
export function PassportEditor({ entry, today, fromNote, onOpenPage, onDone, onClose }: EditorProps<ReviewPassport>) {
  const i18n = useI18n();
  const { t } = i18n;
  const [values, setValues] = useState(() => ({
    passportNumber: entry.passportNumber ?? '',
    issuingCountry: entry.issuingCountry ?? '',
    issuedOn: entry.issuedOn ?? '',
  }));
  const [opened] = useState(() => JSON.stringify(values));
  const [submitted, setSubmitted] = useState(false);
  const set = <K extends keyof typeof values>(field: K, value: (typeof values)[K]) =>
    setValues((old) => ({ ...old, [field]: value }));
  const edited = markPassportChanges(entry, {
    ...entry,
    passportNumber: values.passportNumber.trim() || null,
    issuingCountry: values.issuingCountry.trim().toUpperCase() || null,
    issuedOn: values.issuedOn || null,
  });
  const doubt = useDoubt(edited, fromNote);
  const problems = ownProblems(passportProblems(t, edited, today), ['passportNumber', 'issuingCountry', 'issuedOn']);
  const error = (field: string) => (submitted ? (problems[field] ?? null) : null);
  const saved = entry.saved;
  return (
    <EditorDialog
      title={t.scanEditPassportTitle}
      entry={entry}
      fromNote={fromNote}
      onOpenPage={onOpenPage}
      changed={JSON.stringify(values) !== opened}
      failure={submitted && Object.keys(problems).length ? t.formCheckFields : null}
      onDone={() => {
        setSubmitted(true);
        if (!Object.keys(problems).length) onDone(edited);
      }}
      onClose={onClose}
    >
      <Notice>{t.scanPassportKeeps}</Notice>
      <TextField
        label={t.passportNumberLabel}
        placeholder={t.passportNumberHint}
        value={values.passportNumber}
        code
        autoComplete="off"
        hint={doubt('passportNumber') ?? (saved.passportNumber ? t.scanSavedValue(saved.passportNumber) : null)}
        onChange={(number) => set('passportNumber', number)}
        error={error('passportNumber')}
      />
      <TextField
        label={t.passportCountryLabel}
        placeholder={t.passportCountryHint}
        value={values.issuingCountry}
        autoComplete="off"
        hint={doubt('issuingCountry') ?? (saved.issuingCountry ? t.scanSavedValue(saved.issuingCountry) : null)}
        onChange={(country) => set('issuingCountry', country)}
        error={error('issuingCountry')}
      />
      <DateField
        label={t.passportIssuedOnLabel}
        value={values.issuedOn}
        max={today}
        hint={doubt('issuedOn') ?? (saved.issuedOn ? t.scanSavedValue(i18n.date(saved.issuedOn)) : null)}
        onChange={(date) => set('issuedOn', date)}
        error={error('issuedOn')}
      />
    </EditorDialog>
  );
}

/** A weight of the scan or the note: its day and the weight in kilograms to the gram, checked like a weighing. */
export function WeightEditor({ entry, pet, today, fromNote, onOpenPage, onDone, onClose }: EditorProps<ReviewWeight> & { pet: Pet }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [values, setValues] = useState(() => ({
    measuredOn: entry.measuredOn ?? '',
    weight: entry.weightKg !== null ? weightNumberLabel(i18n, entry.weightKg).replace(/\s/g, '') : '',
  }));
  const [opened] = useState(() => JSON.stringify(values));
  const [submitted, setSubmitted] = useState(false);
  const set = <K extends keyof typeof values>(field: K, value: (typeof values)[K]) =>
    setValues((old) => ({ ...old, [field]: value }));
  const kg = parseDecimal(values.weight);
  const edited = markWeightChanges(entry, {
    ...entry,
    measuredOn: values.measuredOn || null,
    weightKg: kg === null ? null : grams(kg) / 1000,
  });
  const first = firstWeighingDate(pet, today);
  const doubt = useDoubt(edited, fromNote);
  // A weighing keeps its weight to the gram.
  const weightText = weightTextProblem(values.weight, WEIGHING_DECIMALS, true);
  const problems = ownProblems(
    {
      ...weightProblems(t, edited, today, first),
      ...(weightText ? { weightKg: weightProblemLabel(t, weightText, WEIGHING_DECIMALS) } : {}),
    },
    ['measuredOn', 'weightKg'],
  );
  const error = (field: string) => (submitted ? (problems[field] ?? null) : null);
  return (
    <EditorDialog
      title={t.scanEditWeightTitle}
      entry={entry}
      fromNote={fromNote}
      onOpenPage={onOpenPage}
      changed={JSON.stringify(values) !== opened}
      failure={submitted && Object.keys(problems).length ? t.formCheckFields : null}
      onDone={() => {
        setSubmitted(true);
        if (!Object.keys(problems).length) onDone(edited);
      }}
      onClose={onClose}
    >
      <DateField
        label={t.weightMeasuredOnLabel}
        value={values.measuredOn}
        min={first}
        max={today}
        hint={doubt('measuredOn')}
        onChange={(date) => set('measuredOn', date)}
        error={error('measuredOn')}
      />
      <TextField
        label={t.recordWeightLabel}
        placeholder={t.weightHint}
        value={values.weight}
        inputMode="decimal"
        autoComplete="off"
        hint={doubt('weightKg')}
        onChange={(weight) => set('weight', weight.replace(/[^\d.,]/g, ''))}
        error={error('weightKg')}
      />
    </EditorDialog>
  );
}

/** Which plan a record is a "Done" of: one of `plans`, or none. */
export function PlanPicker({
  plans,
  current,
  onPick,
  onClose,
}: {
  plans: readonly CarePlan[];
  current: string | null;
  onPick: (planId: string | null) => void;
  onClose: () => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const choice = (id: string | null, icon: ReactNode, title: string, sub: string | null) => (
    <li key={id ?? 'none'} className="row">
      {icon}
      <div className="row-main">
        <button type="button" className="row-button row-link" aria-pressed={id === current} onClick={() => onPick(id)}>
          {title}
        </button>
        {sub && <span className="row-sub">{sub}</span>}
      </div>
      {id === current && <Icon name="check" className="ok-icon" />}
    </li>
  );
  return (
    <Dialog title={t.scanPlanPickTitle} onClose={onClose}>
      <DialogBody>
        <ul className="card card--list rows">
          {plans.map((plan) =>
            choice(
              plan.id,
              <span className="kind-icon" aria-hidden="true">
                <Icon name={CARE_KIND_ICONS[plan.kind]} />
              </span>,
              plan.title,
              [intervalLabel(t, plan.intervalValue, plan.intervalUnit), i18n.date(plan.nextDueOn)].join(' · '),
            ),
          )}
          {choice(
            null,
            <span className="kind-icon" aria-hidden="true">
              <Icon name="close" />
            </span>,
            t.scanPlanNone,
            null,
          )}
        </ul>
      </DialogBody>
    </Dialog>
  );
}
