// The entries of a scan on its review (the phone app's draft_cards.dart): a card per record, weighing, microchip or
// tattoo, and one for the passport details. Each has its tick ("save this"), its values with the AI's doubts
// highlighted (yellow status tags: an icon and words), quick fixes (the date the AI couldn't read, day and month
// swapped, a saved passport value replaced), where it was read (the page, which opens large, and the words as on the
// paper; for a note, the words of the note), a record's link to a plan it is the "Done" of, and "Edit". After a save
// was tried, a ticked entry says what keeps it from being saved. The cards change their entry only through onChange.
import { useId, type ReactNode } from 'react';
import type { CarePlan, DraftWarning } from '../../api/types';
import { DateField } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { CARE_KIND_ICONS } from '../../components/kindIcons';
import type { IconName } from '../../components/icons';
import { useI18n } from '../../i18n/i18n';
import { EARLIEST_CARE_DATE, usesExam, usesTargets } from '../../lib/care';
import { displayCode, normalizeCode } from '../../lib/identifiers';
import { weightValueLabel } from '../../lib/labels';
import type { Messages } from '../../i18n/en';
import { draftIssueBadge, draftIssueMessage, scanDefaultTitle } from './labels';
import {
  canSelect,
  differs,
  fieldWarnings,
  passportChanges,
  passportValue,
  planChoices,
  repeats,
  swapDayAndMonth,
  titleOr,
  withDate,
  withPlan,
  type PassportField,
  type ReviewEntry,
  type ReviewIdentifier,
  type ReviewPassport,
  type ReviewRecord,
  type ReviewWeight,
} from './review';

interface CardProps<T extends ReviewEntry> {
  entry: T;
  /** What keeps the entry from being saved (by API field name). */
  problems: Record<string, string>;
  /** A save was tried: the problems of a ticked entry show. */
  showProblems: boolean;
  /** Read from a note, not from photos. */
  fromNote: boolean;
  onChange: (entry: T) => void;
  onEdit: () => void;
  /** Opens the photo the entry was read from; null when it is gone, and for a note. */
  onOpenPage: (() => void) | null;
  /** Today in the household: dates entered here can't be later. */
  today: string;
}

export function RecordCard({
  entry,
  plans,
  onChoosePlan,
  ...props
}: CardProps<ReviewRecord> & { plans: readonly CarePlan[]; onChoosePlan: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { onChange, fromNote, today } = props;
  const warnings = fieldWarnings(entry);
  const about = (field: string) => warnings.filter((warning) => warning.field === field);
  const kind = t.careKind[entry.kind];
  const title = titleOr(entry, (each, targets) => scanDefaultTitle(t, each, targets));
  const product = [entry.product, entry.manufacturer].filter(Boolean).join(', ');
  const swap = (field: 'performedOn' | 'validFrom' | 'validUntil', date: string | null) =>
    date && <SwapButton warnings={warnings} field={field} date={date} onSwap={(swapped) => onChange(withDate(entry, field, swapped))} />;
  return (
    <EntryCard
      {...props}
      entry={entry}
      icon={CARE_KIND_ICONS[entry.kind]}
      title={title}
      // A title that is the kind's name says it already.
      subtitle={title === kind ? null : kind}
      labels={RECORD_LABELS}
    >
      <Badges entry={entry} fromNote={fromNote} />
      {!canSelect(entry) && <p className="muted small">{t.scanNeedsDate}</p>}
      <ValueRow
        label={t.recordPerformedOnLabel}
        value={
          entry.performedOn &&
          (entry.performedTime
            ? t.dateWithTime(i18n.date(entry.performedOn), i18n.time(entry.performedTime))
            : i18n.date(entry.performedOn))
        }
        warnings={[...about('performedOn'), ...about('performedTime')]}
        fromNote={fromNote}
      >
        {entry.performedOn === null ? (
          <div className="draft-enter-date">
            <DateField
              label={t.scanEnterDate}
              value=""
              min={EARLIEST_CARE_DATE}
              max={today}
              onChange={(date) => {
                if (!date) return;
                // Entered to be saved: ticked, unless it repeats something.
                const dated = withDate(entry, 'performedOn', date);
                onChange(repeats(dated) ? dated : { ...dated, selected: true });
              }}
            />
          </div>
        ) : (
          swap('performedOn', entry.performedOn)
        )}
      </ValueRow>
      {usesTargets(entry.kind) && entry.targets.length > 0 && (
        <ValueRow label={t.careTargetsLabel} value={entry.targets.map((target) => t.vaccineTarget[target]).join(', ')} />
      )}
      {product && <ValueRow label={t.careProductLabel} value={product} />}
      {entry.batchNumber && <ValueRow label={t.careBatchLabel} value={entry.batchNumber} code />}
      {(['validFrom', 'validUntil'] as const).map(
        (field) =>
          (entry[field] !== null || about(field).length > 0) && (
            <ValueRow
              key={field}
              label={field === 'validFrom' ? t.careValidFromLabel : t.careValidUntilLabel}
              value={entry[field] && i18n.date(entry[field])}
              warnings={about(field)}
              fromNote={fromNote}
            >
              {swap(field, entry[field])}
            </ValueRow>
          ),
      )}
      {/* Only a check-up keeps a weight: another kind saves none. */}
      {usesExam(entry.kind) && (entry.weightKg !== null || about('weightKg').length > 0) && (
        <ValueRow
          label={t.petTabWeight}
          value={entry.weightKg !== null ? weightValueLabel(i18n, entry.weightKg) : null}
          warnings={about('weightKg')}
          fromNote={fromNote}
        />
      )}
      {entry.veterinarian && <ValueRow label={t.careVetLabel} value={entry.veterinarian} />}
      {entry.clinic && <ValueRow label={t.careClinicLabel} value={entry.clinic} />}
      <Evidence page={entry.draft.page} evidence={entry.draft.evidence} onOpen={props.onOpenPage} fromNote={fromNote} />
      <PlanLink entry={entry} plans={plans} onChange={onChange} onChoosePlan={onChoosePlan} />
    </EntryCard>
  );
}

export function IdentifierCard(props: CardProps<ReviewIdentifier>) {
  const i18n = useI18n();
  const { t } = i18n;
  const { entry, onChange, fromNote } = props;
  const warnings = fieldWarnings(entry);
  const about = (field: string) => warnings.filter((warning) => warning.field === field);
  const tattoo = entry.type === 'Tattoo';
  const code = normalizeCode(entry.code);
  const details = [
    entry.appliedOn &&
      (tattoo ? t.identifierTattooAppliedOn : t.identifierChipImplantedOn)(i18n.date(entry.appliedOn)),
    entry.location,
  ].filter(Boolean);
  return (
    <EntryCard
      {...props}
      icon="id_card"
      overline={t.identifierType[entry.type]}
      title={code ? displayCode(entry.type, code) : t.scanNotRead}
      titleCode={!!code}
      labels={identifierLabels(t, tattoo)}
    >
      <Badges entry={entry} identifier fromNote={fromNote} />
      {!canSelect(entry) && <p className="muted small">{t.scanNeedsCode}</p>}
      <Warnings warnings={about('code')} fromNote={fromNote} />
      {details.length > 0 && <p className="row-sub">{details.join(' · ')}</p>}
      <Warnings warnings={[...about('appliedOn'), ...about('location')]} fromNote={fromNote} />
      {entry.appliedOn && (
        <SwapButton
          warnings={warnings}
          field="appliedOn"
          date={entry.appliedOn}
          onSwap={(swapped) => onChange(withDate(entry, 'appliedOn', swapped))}
        />
      )}
      <Evidence page={entry.draft.page} evidence={entry.draft.evidence} onOpen={props.onOpenPage} fromNote={fromNote} />
    </EntryCard>
  );
}

/**
 * The passport details against what is saved: a value for an empty field is added when the card is ticked; a value
 * that differs from the saved one has its own switch to replace it, off until the person turns it on (or changes it).
 */
export function PassportCard(props: CardProps<ReviewPassport>) {
  const i18n = useI18n();
  const { t } = i18n;
  const { entry, onChange, fromNote } = props;
  const warnings = fieldWarnings(entry);
  const about = (field: PassportField) => warnings.filter((warning) => warning.field === field);
  const readNothing = (['passportNumber', 'issuingCountry', 'issuedOn'] as const).every(
    (field) => passportValue(entry, field) === null,
  );
  const shown = (field: PassportField, value: string | null) =>
    field === 'issuedOn' && value ? i18n.date(value) : value;
  // Under a value: the same as saved, or what is saved (and the switch to replace it).
  const note = (field: PassportField) =>
    differs(entry, field)
      ? t.scanSavedValue(shown(field, entry.saved[field])!)
      : passportValue(entry, field) !== null && entry.saved[field] !== null
        ? t.scanPassportSame
        : null;
  const replaceSwitch = (field: PassportField) =>
    differs(entry, field) && (
      <label className="check-inline">
        <input
          type="checkbox"
          checked={entry.replace.includes(field)}
          onChange={(event) => {
            const on = event.target.checked;
            onChange({
              ...entry,
              replace: on ? [...entry.replace, field] : entry.replace.filter((each) => each !== field),
              // Replacing is the reason to save the card.
              selected: on ? true : entry.selected,
            });
          }}
        />
        {t.scanPassportReplace}
      </label>
    );
  const rows: [PassportField, string, boolean][] = [
    ['passportNumber', t.passportNumberLabel, true],
    ['issuingCountry', t.passportCountryLabel, false],
    ['issuedOn', t.passportIssuedOnLabel, false],
  ];
  return (
    <EntryCard {...props} icon="menu_book" title={t.scanPassportFillIn} labels={PASSPORT_LABELS}>
      <Badges entry={entry} fromNote={fromNote} />
      {!canSelect(entry) ? (
        <p className="muted small">{readNothing ? t.scanNothingToFill : t.scanPassportNothingNew}</p>
      ) : (
        entry.selected &&
        passportChanges(entry).length === 0 && <p className="muted small">{t.scanPassportTurnOnReplace}</p>
      )}
      {rows.map(
        ([field, label, code]) =>
          (entry[field] !== null || about(field).length > 0) && (
            <ValueRow
              key={field}
              label={label}
              value={shown(field, entry[field])}
              code={code}
              note={note(field)}
              warnings={about(field)}
              fromNote={fromNote}
            >
              {field === 'issuedOn' && entry.issuedOn && (
                <SwapButton
                  warnings={warnings}
                  field="issuedOn"
                  date={entry.issuedOn}
                  onSwap={(swapped) => onChange(withDate(entry, 'issuedOn', swapped))}
                />
              )}
              {replaceSwitch(field)}
            </ValueRow>
          ),
      )}
      <Evidence page={entry.draft.page} evidence={entry.draft.evidence} onOpen={props.onOpenPage} fromNote={fromNote} />
    </EntryCard>
  );
}

/** A weight of the scan or the note, saved as a weighing of the pet's log. */
export function WeightCard(props: CardProps<ReviewWeight>) {
  const i18n = useI18n();
  const { t } = i18n;
  const { entry, onChange, fromNote } = props;
  const warnings = fieldWarnings(entry);
  const about = (field: string) => warnings.filter((warning) => warning.field === field);
  return (
    <EntryCard
      {...props}
      icon="monitor_weight"
      overline={t.weightSource.Weighing}
      title={entry.weightKg !== null ? weightValueLabel(i18n, entry.weightKg) : t.scanNotRead}
      labels={WEIGHT_LABELS}
    >
      <Badges entry={entry} weight fromNote={fromNote} />
      {entry.weightKg === null ? (
        <p className="muted small">{t.scanNeedsWeight}</p>
      ) : (
        entry.measuredOn === null && <p className="muted small">{t.scanNeedsDate}</p>
      )}
      <Warnings warnings={about('weightKg')} fromNote={fromNote} />
      <ValueRow
        label={t.weightMeasuredOnLabel}
        value={entry.measuredOn && i18n.date(entry.measuredOn)}
        warnings={about('measuredOn')}
        fromNote={fromNote}
      >
        {entry.measuredOn && (
          <SwapButton
            warnings={warnings}
            field="measuredOn"
            date={entry.measuredOn}
            onSwap={(swapped) => onChange(withDate(entry, 'measuredOn', swapped))}
          />
        )}
      </ValueRow>
      <Evidence page={entry.draft.page} evidence={entry.draft.evidence} onOpen={props.onOpenPage} fromNote={fromNote} />
    </EntryCard>
  );
}

// --- The parts of a card --------------------------------------------------------------------------------------------

/** The names of an entry's fields on screen, for its problems: "Date: A date in the future can't be saved". */
type FieldLabels = (t: Messages, field: string) => string | null;

const RECORD_LABELS: FieldLabels = (t, field) =>
  ({
    kind: t.careKindLabel,
    title: t.recordTitleLabel,
    performedOn: t.recordPerformedOnLabel,
    performedTime: t.careTimeLabel,
    targets: t.careTargetsLabel,
    product: t.careProductLabel,
    manufacturer: t.careManufacturerLabel,
    batchNumber: t.careBatchLabel,
    validFrom: t.careValidFromLabel,
    validUntil: t.careValidUntilLabel,
    clinic: t.careClinicLabel,
    veterinarian: t.careVetLabel,
    weightKg: t.petTabWeight,
    planId: t.healthPlansTitle,
  })[field] ?? null;

const identifierLabels =
  (t: Messages, tattoo: boolean): FieldLabels =>
  (_, field) =>
    ({
      type: t.identifierTypeLabel,
      code: tattoo ? t.identifierTattooLabel : t.identifierChipLabel,
      appliedOn: tattoo ? t.identifierTattooDateLabel : t.identifierChipDateLabel,
      location: t.identifierLocationLabel,
    })[field] ?? null;

const PASSPORT_LABELS: FieldLabels = (t, field) =>
  ({
    passportNumber: t.passportNumberLabel,
    issuingCountry: t.passportCountryLabel,
    issuedOn: t.passportIssuedOnLabel,
  })[field] ?? null;

const WEIGHT_LABELS: FieldLabels = (t, field) =>
  ({ measuredOn: t.weightMeasuredOnLabel, weightKg: t.petTabWeight })[field] ?? null;

/** The frame of an entry: the tick, an icon, the title, "Edit", then its details and, after a save, its problems. */
function EntryCard<T extends ReviewEntry>({
  entry,
  problems,
  showProblems,
  onChange,
  onEdit,
  icon,
  overline,
  title,
  titleCode = false,
  subtitle,
  labels,
  children,
}: CardProps<T> & {
  icon: IconName;
  overline?: string;
  title: string;
  titleCode?: boolean;
  subtitle?: string | null;
  labels: FieldLabels;
  children: ReactNode;
}) {
  const { t } = useI18n();
  const titleId = useId();
  const shownProblems = showProblems && entry.selected ? Object.entries(problems) : [];
  return (
    <article
      className={`card draft-card${entry.selected ? ' is-selected' : ''}${shownProblems.length ? ' is-invalid' : ''}`}
      aria-labelledby={titleId}
      data-invalid={shownProblems.length ? true : undefined}
    >
      <div className="draft-card-head">
        <input
          type="checkbox"
          className="draft-tick"
          checked={entry.selected}
          disabled={!canSelect(entry)}
          aria-label={t.scanSelectEntry(title)}
          onChange={(event) => onChange({ ...entry, selected: event.target.checked })}
        />
        <span className="kind-icon" aria-hidden="true">
          <Icon name={icon} />
        </span>
        <div className="draft-card-title">
          {overline && <span className="row-sub">{overline}</span>}
          <h3 id={titleId} className={`row-title${titleCode ? ' code' : ''}`}>
            {title}
          </h3>
          {subtitle && <span className="row-sub">{subtitle}</span>}
        </div>
        <button
          type="button"
          className="icon-button"
          aria-label={t.scanEditEntry(title)}
          title={t.commonEdit}
          onClick={onEdit}
        >
          <Icon name="edit" />
        </button>
      </div>
      <div className="draft-card-body">
        {children}
        {shownProblems.length > 0 && (
          <div className="draft-problems">
            {shownProblems.map(([field, message]) => {
              const label = labels(t, field);
              return (
                <p key={field} className="field-error">
                  <Icon name="error" size={16} />
                  {label ? `${label}: ${message}` : message}
                </p>
              );
            })}
            <p className="field-error">{t.scanEntryFix}</p>
          </div>
        )}
      </div>
    </article>
  );
}

/** One value: its label, the value (or "Not read"), what is saved when it differs, the AI's doubts, quick fixes. */
function ValueRow({
  label,
  value,
  code = false,
  note,
  warnings = [],
  fromNote = false,
  children,
}: {
  label: string;
  value: string | null;
  code?: boolean;
  note?: string | null;
  warnings?: readonly DraftWarning[];
  fromNote?: boolean;
  children?: ReactNode;
}) {
  const { t } = useI18n();
  return (
    <div className="draft-value">
      <span className="draft-value-label">{label}</span>
      <span className={value === null ? 'muted' : code ? 'code' : undefined}>{value ?? t.scanNotRead}</span>
      {note && <span className="row-sub">{note}</span>}
      <Warnings warnings={warnings} fromNote={fromNote} />
      {children}
    </div>
  );
}

/** The AI's doubts about a value: "check this", in yellow status tags with an icon. */
function Warnings({ warnings, fromNote }: { warnings: readonly DraftWarning[]; fromNote: boolean }) {
  const { t } = useI18n();
  if (!warnings.length) return null;
  return (
    <>
      {warnings.map((warning) => (
        <p key={`${warning.field}-${warning.issue}`} className="tag tag--warning draft-warning">
          <Icon name="warning" size={16} />
          {draftIssueMessage(t, warning.issue, { fromNote })}
        </p>
      ))}
    </>
  );
}

/** Badges for doubts about the whole entry ("Already saved", "Same as another entry"), with what they mean. */
function Badges({
  entry,
  identifier = false,
  weight = false,
  fromNote,
}: {
  entry: ReviewEntry;
  identifier?: boolean;
  weight?: boolean;
  fromNote: boolean;
}) {
  const { t } = useI18n();
  const issues = [...new Set(entry.draft.warnings.map((warning) => warning.issue))].filter(
    (issue) => draftIssueBadge(t, issue) !== null,
  );
  if (!issues.length) return null;
  return (
    <ul className="draft-badges plain-list">
      {issues.map((issue) => (
        <li key={issue}>
          <span className="badge badge--warning">{draftIssueBadge(t, issue)}</span>
          {issue !== 'DiffersFromSaved' && (
            <span className="muted small">{draftIssueMessage(t, issue, { identifier, weight, fromNote })}</span>
          )}
        </li>
      ))}
    </ul>
  );
}

/** "Change to Mar 4, 2025" under a date whose day and month could be the other way round. */
function SwapButton({
  warnings,
  field,
  date,
  onSwap,
}: {
  warnings: readonly DraftWarning[];
  field: string;
  date: string;
  onSwap: (swapped: string) => void;
}) {
  const i18n = useI18n();
  const ambiguous = warnings.some((warning) => warning.field === field && warning.issue === 'Ambiguous');
  const swapped = swapDayAndMonth(date);
  if (!ambiguous || !swapped) return null;
  return (
    <button type="button" className="button button--secondary align-start" onClick={() => onSwap(swapped)}>
      <Icon name="swap_horiz" size={18} />
      {i18n.t.scanSwapTo(i18n.date(swapped))}
    </button>
  );
}

/**
 * Where an entry was read: "Read on page 2" and the text as on the page; a click opens that photo. For a note: "From
 * your note" and its words, or nothing when the AI gave none.
 */
export function Evidence({
  page,
  evidence,
  onOpen,
  fromNote,
}: {
  page: number;
  evidence: string | null;
  onOpen: (() => void) | null;
  fromNote: boolean;
}) {
  const { t } = useI18n();
  if (fromNote) {
    if (!evidence) return null;
    return (
      <div className="draft-evidence">
        <span className="small muted">{t.noteEvidence}</span>
        <span>{t.scanEvidence(evidence)}</span>
      </div>
    );
  }
  const content = (
    <>
      <span className="small muted">{t.scanReadOnPage(page)}</span>
      {evidence && <span>{t.scanEvidence(evidence)}</span>}
    </>
  );
  if (!onOpen) return <div className="draft-evidence">{content}</div>;
  return (
    <button type="button" className="draft-evidence draft-evidence--button" onClick={onOpen} title={t.scanOpenPage(page)}>
      <span className="draft-evidence-text">{content}</span>
      <Icon name="photo" size={20} />
    </button>
  );
}

/** "Mark as done in plan “Rabies”": for a record whose kind has plans, and a way to choose another plan or none. */
function PlanLink({
  entry,
  plans,
  onChange,
  onChoosePlan,
}: {
  entry: ReviewRecord;
  plans: readonly CarePlan[];
  onChange: (entry: ReviewRecord) => void;
  onChoosePlan: () => void;
}) {
  const { t } = useI18n();
  const id = useId();
  const linked = plans.find((plan) => plan.id === entry.planId) ?? null;
  const choices = planChoices(entry, plans);
  if (entry.planId === null && choices.length === 0) return null;
  return (
    <div className="draft-plan">
      <div className="check-field">
        <input
          id={id}
          type="checkbox"
          // On while a plan is linked, even one gone since: turning it off unlinks it.
          checked={entry.planId !== null}
          aria-describedby={entry.planId ? `${id}-hint` : undefined}
          onChange={(event) => {
            if (!event.target.checked) onChange(withPlan(entry, null));
            else if (choices.length === 1) onChange(withPlan(entry, choices[0]!.id));
            else onChoosePlan();
          }}
        />
        <label htmlFor={id}>{linked ? t.scanPlanDone(linked.title) : t.scanPlanLink}</label>
        {entry.planId && (
          <p className="field-hint" id={`${id}-hint`}>
            {t.scanPlanHint}
          </p>
        )}
      </div>
      {entry.planId !== null && choices.length > 1 && (
        <button type="button" className="button button--secondary align-start" onClick={onChoosePlan}>
          {t.scanPlanChange}
        </button>
      )}
    </div>
  );
}
