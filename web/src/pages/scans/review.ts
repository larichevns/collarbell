// A scan's draft as the person checks it (the phone app's scan_review.dart): every entry with the values the person
// left in it, whether it is ticked, and what still needs a look. The review page keeps one Review; saving turns the
// ticked entries into the request of POST /ai-imports/{id}/apply (sending), and the server's field errors are put back
// on the entries they name (placeServerErrors). Plain data and functions: an edit makes a new entry, so React sees it.
//
// The rules, as the phone has them:
// - An entry starts ticked when the server suggests it (a duplicate comes unticked) and it can be saved: a record needs
//   its date, a microchip its number, a weight its day and number. Edited so it can't be saved any more, it is
//   unticked; edited so it can, it is ticked, unless it repeats something (already saved, on another photo).
// - The AI's doubts about a value (unreadable, day and month that could be swapped, in the future…) show until that
//   value is changed; doubts about the whole entry (already saved, the same as another entry, differs from what is
//   saved) are badges that stay.
// - A record can be a "Done" of one of the pet's active plans of its kind (a vaccination's against the same diseases,
//   when both say which). A plan deleted since the scan was read can't take it.
// - The passport details fill in what the passport header doesn't have yet; a value that differs from the saved one
//   replaces it only when the person says so (or typed it by hand). An empty field keeps what is saved.
// - Microchips the pet has already take no place among its five: the server skips them.
import type { Messages } from '../../i18n/en';
import type {
  ApplyImportRequest,
  CareKind,
  CarePlan,
  CareRecordRequest,
  DraftIdentifier,
  DraftIssue,
  DraftPassport,
  DraftRecord,
  DraftWarning,
  DraftWeight,
  IdentifierType,
  ImportDraft,
  Passport,
  VaccineTarget,
} from '../../api/types';
import { CARE_MAX, EARLIEST_CARE_DATE, usesExam, usesTargets } from '../../lib/care';
import { identifierProblem, MAX_IDENTIFIERS, MAX_LOCATION_LENGTH, normalizeCode } from '../../lib/identifiers';
import { identifierProblemLabel } from '../../lib/labels';
import { countryOk, normalizePassportNumber, passportNumberOk } from '../../lib/passport';
import { EARLIEST_WEIGHT_DATE, grams, MAX_KG } from '../../lib/weight';

/** A field of the passport header a scan can fill in, by its name in the API. */
export type PassportField = 'passportNumber' | 'issuingCountry' | 'issuedOn';
export const PASSPORT_FIELDS: readonly PassportField[] = ['passportNumber', 'issuingCountry', 'issuedOn'];

/** The title of a record that has none of its own, for its kind and diseases, in the person's language. */
export type DefaultTitle = (kind: CareKind, targets: readonly VaccineTarget[]) => string;

interface Entry {
  /** Whether "save this" is ticked. */
  selected: boolean;
  /** Fields the person changed (API names): the AI's doubts about them no longer apply. */
  changed: string[];
  /** Fields the server refused at the last save (API names; "record" for a record as a whole). */
  serverErrors: string[];
}

export interface ReviewRecord extends Entry {
  entry: 'record';
  /** What the AI read; it never changes. */
  draft: DraftRecord;
  kind: CareKind;
  /** As read or typed. Null when neither gave one: the record goes under its kind's name (DefaultTitle). */
  title: string | null;
  performedOn: string | null;
  /** "09:30:00", as the API writes times. */
  performedTime: string | null;
  product: string | null;
  manufacturer: string | null;
  batchNumber: string | null;
  validFrom: string | null;
  validUntil: string | null;
  targets: VaccineTarget[];
  veterinarian: string | null;
  clinic: string | null;
  /** A check-up's weight; saved only while the record is a check-up. */
  weightKg: number | null;
  /** The plan this record is a "Done" of; null for none. */
  planId: string | null;
}

export interface ReviewIdentifier extends Entry {
  entry: 'identifier';
  draft: DraftIdentifier;
  type: IdentifierType;
  /** As the person typed it; empty when it couldn't be read. */
  code: string;
  appliedOn: string | null;
  location: string | null;
}

export interface ReviewPassport extends Entry {
  entry: 'passport';
  draft: DraftPassport;
  /** The passport header as saved when the review opened. */
  saved: Pick<Passport, PassportField>;
  passportNumber: string | null;
  issuingCountry: string | null;
  issuedOn: string | null;
  /** Fields whose different saved value the person agreed to replace. */
  replace: PassportField[];
}

export interface ReviewWeight extends Entry {
  entry: 'weight';
  draft: DraftWeight;
  measuredOn: string | null;
  weightKg: number | null;
}

export type ReviewEntry = ReviewRecord | ReviewIdentifier | ReviewPassport | ReviewWeight;

export interface Review {
  records: ReviewRecord[];
  identifiers: ReviewIdentifier[];
  passport: ReviewPassport | null;
  weights: ReviewWeight[];
  /** The pet's microchips and tattoos as saved, normalized. */
  savedCodes: string[];
}

// --- Making the review ----------------------------------------------------------------------------------------------

export function recordFromDraft(draft: DraftRecord, planIds: ReadonlySet<string>): ReviewRecord {
  return {
    entry: 'record',
    draft,
    kind: draft.kind,
    title: draft.title,
    performedOn: draft.performedOn,
    performedTime: draft.performedTime,
    product: draft.product,
    manufacturer: draft.manufacturer,
    batchNumber: draft.batchNumber,
    validFrom: draft.validFrom,
    validUntil: draft.validUntil,
    targets: [...draft.targets],
    veterinarian: draft.veterinarian,
    clinic: draft.clinic,
    weightKg: draft.weightKg,
    // A plan deleted since the scan was read can't take a "Done".
    planId: draft.planId && planIds.has(draft.planId) ? draft.planId : null,
    selected: draft.selected && draft.performedOn !== null,
    changed: [],
    serverErrors: [],
  };
}

export function identifierFromDraft(draft: DraftIdentifier): ReviewIdentifier {
  const code = draft.code ?? '';
  return {
    entry: 'identifier',
    draft,
    type: draft.type,
    code,
    appliedOn: draft.appliedOn,
    location: draft.location,
    selected: draft.selected && code !== '',
    changed: [],
    serverErrors: [],
  };
}

export function weightFromDraft(draft: DraftWeight): ReviewWeight {
  return {
    entry: 'weight',
    draft,
    measuredOn: draft.measuredOn,
    weightKg: draft.weightKg,
    selected: draft.selected && draft.measuredOn !== null && draft.weightKg !== null,
    changed: [],
    serverErrors: [],
  };
}

export function passportFromDraft(draft: DraftPassport, saved: Pick<Passport, PassportField>): ReviewPassport {
  const entry: ReviewPassport = {
    entry: 'passport',
    draft,
    saved: { passportNumber: saved.passportNumber, issuingCountry: saved.issuingCountry, issuedOn: saved.issuedOn },
    passportNumber: draft.passportNumber,
    issuingCountry: draft.issuingCountry,
    issuedOn: draft.issuedOn,
    replace: [],
    selected: false,
    changed: [],
    serverErrors: [],
  };
  // The server leaves the card unticked when a value differs from the saved one. Here such a value has its own
  // switch, off until the person turns it on, so the card is ticked when it fills in something the header doesn't
  // have yet and the AI has no other doubts.
  const fillsIn = PASSPORT_FIELDS.some((field) => fills(entry, field));
  const otherDoubts = draft.warnings.some((w) => w.issue !== 'Ambiguous' && w.issue !== 'DiffersFromSaved');
  entry.selected = canSelect(entry) && (draft.selected || (fillsIn && !otherDoubts));
  return entry;
}

/** The review of a draft, against the pet's plans, passport header and microchips as the server has them now. */
export function reviewFromDraft(
  draft: ImportDraft,
  {
    planIds,
    savedPassport,
    savedCodes,
  }: { planIds: ReadonlySet<string>; savedPassport: Pick<Passport, PassportField>; savedCodes: readonly string[] },
): Review {
  return {
    records: draft.records.map((record) => recordFromDraft(record, planIds)),
    identifiers: draft.identifiers.map(identifierFromDraft),
    passport: draft.passport ? passportFromDraft(draft.passport, savedPassport) : null,
    weights: draft.weights.map(weightFromDraft),
    savedCodes: [...savedCodes],
  };
}

export function isEmpty(review: Review): boolean {
  return (
    review.records.length === 0 &&
    review.identifiers.length === 0 &&
    review.passport === null &&
    review.weights.length === 0
  );
}

// --- What an entry is now -------------------------------------------------------------------------------------------

/** Whether the entry has what it needs to be saved: a date, a number, a weight, something for the passport. */
export function canSelect(entry: ReviewEntry): boolean {
  switch (entry.entry) {
    case 'record':
      return entry.performedOn !== null;
    case 'identifier':
      return entry.code.trim() !== '';
    case 'weight':
      return entry.measuredOn !== null && entry.weightKg !== null;
    case 'passport':
      return PASSPORT_FIELDS.some((field) => fills(entry, field) || differs(entry, field));
  }
}

/** A doubt about the whole entry rather than one of its values: a badge, which stays when the entry is edited. */
export function isAboutEntry(issue: DraftIssue): boolean {
  return issue === 'AlreadySaved' || issue === 'Repeated' || issue === 'DiffersFromSaved';
}

export function hasIssue(entry: ReviewEntry, issue: DraftIssue): boolean {
  return entry.draft.warnings.some((warning) => warning.issue === issue);
}

/** The AI's doubts about values the person hasn't changed; doubts about the whole entry are badges instead. */
export function fieldWarnings(entry: ReviewEntry): DraftWarning[] {
  return entry.draft.warnings.filter(
    (warning) => !isAboutEntry(warning.issue) && !entry.changed.includes(warning.field),
  );
}

/** Already saved, or on another photo too: ticking it stays the person's choice. */
export function repeats(entry: ReviewEntry): boolean {
  return hasIssue(entry, 'AlreadySaved') || hasIssue(entry, 'Repeated');
}

/** The title as shown and saved: its own, or the default for the kind and diseases as they are now. */
export function titleOr(record: ReviewRecord, defaultTitle: DefaultTitle): string {
  return record.title ?? defaultTitle(record.kind, record.targets);
}

// --- The passport details against what is saved ---------------------------------------------------------------------

const clean = (text: string | null | undefined): string | null => {
  const trimmed = text?.trim();
  return trimmed ? trimmed : null;
};

/** What `field` would be saved as: the number without spaces in upper case, the country in upper case. */
export function passportValue(entry: ReviewPassport, field: PassportField): string | null {
  switch (field) {
    case 'passportNumber':
      return clean(normalizePassportNumber(entry.passportNumber ?? ''));
    case 'issuingCountry':
      return clean(entry.issuingCountry)?.toUpperCase() ?? null;
    case 'issuedOn':
      return entry.issuedOn;
  }
}

/** `field` has a value where the saved header has none. */
export function fills(entry: ReviewPassport, field: PassportField): boolean {
  return passportValue(entry, field) !== null && entry.saved[field] === null;
}

/** `field` has a value other than the saved one. */
export function differs(entry: ReviewPassport, field: PassportField): boolean {
  const value = passportValue(entry, field);
  const saved = entry.saved[field];
  return value !== null && saved !== null && value !== saved;
}

/** The fields saving would change: the empty ones filled in, and the different ones the person agreed to replace. */
export function passportChanges(entry: ReviewPassport): PassportField[] {
  return PASSPORT_FIELDS.filter(
    (field) => fills(entry, field) || (differs(entry, field) && entry.replace.includes(field)),
  );
}

// --- Changes --------------------------------------------------------------------------------------------------------

const union = (list: readonly string[], more: readonly string[]) => [...new Set([...list, ...more])];

/** The edited record, with the fields it changed against `before` marked: their doubts and server errors go. */
export function markRecordChanges(before: ReviewRecord, edited: ReviewRecord): ReviewRecord {
  const sameTargets =
    edited.targets.length === before.targets.length && edited.targets.every((target) => before.targets.includes(target));
  const fields = [
    edited.kind !== before.kind && 'kind',
    edited.title !== before.title && 'title',
    edited.performedOn !== before.performedOn && 'performedOn',
    edited.performedTime !== before.performedTime && 'performedTime',
    edited.product !== before.product && 'product',
    edited.manufacturer !== before.manufacturer && 'manufacturer',
    edited.batchNumber !== before.batchNumber && 'batchNumber',
    edited.validFrom !== before.validFrom && 'validFrom',
    edited.validUntil !== before.validUntil && 'validUntil',
    !sameTargets && 'targets',
    edited.veterinarian !== before.veterinarian && 'veterinarian',
    edited.clinic !== before.clinic && 'clinic',
    edited.weightKg !== before.weightKg && 'weightKg',
  ].filter((field): field is string => !!field);
  return {
    ...edited,
    changed: union(edited.changed, fields),
    // Any change answers an error about the record as a whole.
    serverErrors: edited.serverErrors.filter(
      (field) => !fields.includes(field) && !(fields.length > 0 && field === 'record'),
    ),
  };
}

export function markIdentifierChanges(before: ReviewIdentifier, edited: ReviewIdentifier): ReviewIdentifier {
  const fields = [
    edited.type !== before.type && 'type',
    // The server's check of the number depends on the type too.
    (edited.code !== before.code || edited.type !== before.type) && 'code',
    edited.appliedOn !== before.appliedOn && 'appliedOn',
    edited.location !== before.location && 'location',
  ].filter((field): field is string => !!field);
  return {
    ...edited,
    changed: union(edited.changed, fields),
    serverErrors: edited.serverErrors.filter((field) => !fields.includes(field)),
  };
}

/** The edited passport details: a value typed by hand replaces the saved one. */
export function markPassportChanges(before: ReviewPassport, edited: ReviewPassport): ReviewPassport {
  const fields = PASSPORT_FIELDS.filter((field) => edited[field] !== before[field]);
  return {
    ...edited,
    changed: union(edited.changed, fields),
    serverErrors: edited.serverErrors.filter((field) => !(fields as string[]).includes(field)),
    replace: [...new Set([...edited.replace, ...fields])],
  };
}

export function markWeightChanges(before: ReviewWeight, edited: ReviewWeight): ReviewWeight {
  const fields = [
    edited.measuredOn !== before.measuredOn && 'measuredOn',
    edited.weightKg !== before.weightKg && 'weightKg',
  ].filter((field): field is string => !!field);
  return {
    ...edited,
    changed: union(edited.changed, fields),
    serverErrors: edited.serverErrors.filter((field) => !fields.includes(field)),
  };
}

/**
 * After an edit: an entry that can't be saved any more is unticked, and one that couldn't be saved before (no date,
 * no number, no weight) but can now is ticked, unless it repeats something.
 */
export function afterEdit<T extends ReviewEntry>(before: T, edited: T): T {
  if (!canSelect(edited)) return { ...edited, selected: false };
  if (!canSelect(before) && !repeats(edited)) return { ...edited, selected: true };
  return edited;
}

/** A date of an entry set by the person (entered, or day and month swapped): its doubt and server error go. */
export function withDate<T extends ReviewEntry>(entry: T, field: string, date: string): T {
  const changed: T = {
    ...entry,
    [field]: date,
    changed: union(entry.changed, [field]),
    serverErrors: entry.serverErrors.filter((each) => each !== field && each !== 'record'),
  };
  // A date of the passport set by hand replaces the saved one.
  if (changed.entry === 'passport' && field === 'issuedOn' && !changed.replace.includes('issuedOn')) {
    return { ...changed, replace: [...changed.replace, 'issuedOn'] };
  }
  return changed;
}

/** The record as a "Done" of the plan `planId` (null: none). */
export function withPlan(record: ReviewRecord, planId: string | null): ReviewRecord {
  return { ...record, planId, serverErrors: record.serverErrors.filter((field) => field !== 'planId') };
}

/** [date] with day and month swapped ("2025-03-04" → "2025-04-03"), for a date the AI wasn't sure about; else null. */
export function swapDayAndMonth(date: string): string | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!match) return null;
  const [, year, month, day] = match;
  return Number(day) <= 12 && day !== month ? `${year}-${day}-${month}` : null;
}

// --- The whole review -----------------------------------------------------------------------------------------------

function passportSent(review: Review): boolean {
  const { passport } = review;
  return passport !== null && passport.selected && passportChanges(passport).length > 0;
}

/** How many entries would be saved; the passport details count when they change something. */
export function selectedCount(review: Review): number {
  return (
    review.records.filter((record) => record.selected).length +
    review.identifiers.filter((identifier) => identifier.selected).length +
    (passportSent(review) ? 1 : 0) +
    review.weights.filter((weight) => weight.selected).length
  );
}

/** Whether the ticked `entry` would pass the pet's limit of microchips and tattoos; numbers it has take no place. */
export function overLimit(review: Review, entry: ReviewIdentifier): boolean {
  if (!entry.selected) return false;
  let free = MAX_IDENTIFIERS - review.savedCodes.length;
  for (const identifier of review.identifiers) {
    if (!identifier.selected || review.savedCodes.includes(normalizeCode(identifier.code))) continue;
    free -= 1;
    if (identifier.draft.key === entry.draft.key) return free < 0;
  }
  return false;
}

/** The normalized codes of the ticked identifiers before `entry`: the second of two equal codes gets the error. */
export function codesBefore(review: Review, entry: ReviewIdentifier): string[] {
  const before: string[] = [];
  for (const identifier of review.identifiers) {
    if (identifier.draft.key === entry.draft.key) break;
    if (identifier.selected) before.push(normalizeCode(identifier.code));
  }
  return before;
}

/** Puts an edited entry in the place of the one it was made from. */
export function replaceEntry(review: Review, edited: ReviewEntry): Review {
  switch (edited.entry) {
    case 'record':
      return { ...review, records: review.records.map((each) => (each.draft.key === edited.draft.key ? edited : each)) };
    case 'identifier':
      return {
        ...review,
        identifiers: review.identifiers.map((each) => (each.draft.key === edited.draft.key ? edited : each)),
      };
    case 'weight':
      return { ...review, weights: review.weights.map((each) => (each.draft.key === edited.draft.key ? edited : each)) };
    case 'passport':
      return { ...review, passport: edited };
  }
}

/** Forgets the server's errors of the last save: the next save asks the server again, as the other forms do. */
export function clearServerErrors(review: Review): Review {
  const clear = <T extends ReviewEntry>(entry: T): T => (entry.serverErrors.length ? { ...entry, serverErrors: [] } : entry);
  return {
    ...review,
    records: review.records.map(clear),
    identifiers: review.identifiers.map(clear),
    passport: review.passport ? clear(review.passport) : null,
    weights: review.weights.map(clear),
  };
}

/** What a save sends, and the entry behind each item of it: the server names refused values by their position. */
export interface Sending {
  input: ApplyImportRequest;
  recordKeys: number[];
  identifierKeys: number[];
  weightKeys: number[];
  /** The passport fields sent, for the summary of what changed. */
  passportFields: PassportField[];
}

function recordRequest(record: ReviewRecord, defaultTitle: DefaultTitle): CareRecordRequest {
  return {
    kind: record.kind,
    title: titleOr(record, defaultTitle).trim(),
    performedOn: record.performedOn!,
    performedTime: record.performedTime,
    product: clean(record.product),
    manufacturer: clean(record.manufacturer),
    batchNumber: clean(record.batchNumber),
    validFrom: record.validFrom,
    validUntil: record.validUntil,
    // Only vaccinations protect against diseases (the server refuses targets on other kinds).
    targets: usesTargets(record.kind) ? record.targets : [],
    clinic: clean(record.clinic),
    veterinarian: clean(record.veterinarian),
    // A weight is noted at a check-up only.
    weightKg: usesExam(record.kind) ? record.weightKg : null,
    details: null,
    notes: null,
    // Saving a scan is safe to repeat as a whole: no request id per record.
    requestId: null,
  };
}

/** The ticked entries as the server takes them; a record without a title of its own goes under its kind's name. */
export function sending(
  review: Review,
  { keepPhotos, defaultTitle }: { keepPhotos: boolean; defaultTitle: DefaultTitle },
): Sending {
  const records = review.records.filter((record) => record.selected);
  const identifiers = review.identifiers.filter((identifier) => identifier.selected);
  const weights = review.weights.filter((weight) => weight.selected);
  const { passport } = review;
  // Only the fields that change: the others stay as saved (null keeps).
  const fields = passport && passportSent(review) ? passportChanges(passport) : [];
  const sent = (field: PassportField) => (passport && fields.includes(field) ? passportValue(passport, field) : null);
  return {
    input: {
      records: records.map((record) => ({ record: recordRequest(record, defaultTitle), planId: record.planId })),
      identifiers: identifiers.map((identifier) => ({
        type: identifier.type,
        // As typed: the server normalizes it and keeps what was written.
        code: identifier.code.trim(),
        appliedOn: identifier.appliedOn,
        readOn: null,
        location: clean(identifier.location),
      })),
      passport: fields.length
        ? {
            passportNumber: sent('passportNumber'),
            issuingCountry: sent('issuingCountry'),
            issuedOn: sent('issuedOn'),
          }
        : null,
      keepPhotos,
      // To the gram, as the log keeps it: a double may carry a tail such as 4.2350000001.
      weights: weights.map((weight) => ({ measuredOn: weight.measuredOn!, weightKg: grams(weight.weightKg!) / 1000 })),
    },
    recordKeys: records.map((record) => record.draft.key),
    identifierKeys: identifiers.map((identifier) => identifier.draft.key),
    weightKeys: weights.map((weight) => weight.draft.key),
    passportFields: fields,
  };
}

const RECORD_ERROR = /^records\[(\d+)\]\.(?:record\.)?(.+)$/;
const IDENTIFIER_ERROR = /^identifiers\[(\d+)\]\.(.+)$/;
const PASSPORT_ERROR = /^passport\.(.+)$/;
const WEIGHT_ERROR = /^weights\[(\d+)\]\.(.+)$/;

/**
 * Puts the field errors of a refused save (by API name: "records[2].record.performedOn", "identifiers[0].code",
 * "passport.issuedOn", "weights[0].weightKg") on the entries of `sent` they name. `placedAll` is false when some error
 * names no entry, such as "records" (too many at once): the page then says what went wrong in general.
 */
export function placeServerErrors(
  review: Review,
  errors: Record<string, string[]>,
  sent: Sending,
): { review: Review; placedAll: boolean } {
  let placedAll = true;
  let next = review;
  const add = <T extends ReviewEntry>(entry: T, field: string): T => ({
    ...entry,
    serverErrors: union(entry.serverErrors, [field]),
  });
  for (const key of Object.keys(errors)) {
    const weight = WEIGHT_ERROR.exec(key);
    const record = RECORD_ERROR.exec(key);
    const identifier = IDENTIFIER_ERROR.exec(key);
    const passport = PASSPORT_ERROR.exec(key);
    if (weight) {
      const entry = next.weights.find((each) => each.draft.key === sent.weightKeys[Number(weight[1])]);
      if (entry) next = replaceEntry(next, add(entry, weight[2]!));
      else placedAll = false;
    } else if (record) {
      const entry = next.records.find((each) => each.draft.key === sent.recordKeys[Number(record[1])]);
      if (entry) next = replaceEntry(next, add(entry, record[2]!));
      else placedAll = false;
    } else if (identifier) {
      const entry = next.identifiers.find((each) => each.draft.key === sent.identifierKeys[Number(identifier[1])]);
      if (entry) next = replaceEntry(next, add(entry, identifier[2]!));
      else placedAll = false;
    } else if (passport && next.passport) {
      next = replaceEntry(next, add(next.passport, passport[1]!));
    } else {
      placedAll = false;
    }
  }
  return { review: next, placedAll };
}

/** The plans a record can be a "Done" of, as the server allows it: the active ones of its kind (and the one it has). */
export function planChoices(record: ReviewRecord, plans: readonly CarePlan[]): CarePlan[] {
  return plans.filter(
    (plan) =>
      plan.kind === record.kind &&
      (plan.active || plan.id === record.planId) &&
      (record.kind !== 'Vaccination' ||
        plan.targets.length === 0 ||
        record.targets.length === 0 ||
        plan.targets.some((target) => record.targets.includes(target))),
  );
}

// --- Problems -------------------------------------------------------------------------------------------------------
//
// What keeps a ticked entry from being saved, by API field name: the server's rules (the same as for a record typed
// in), and the fields the server refused at the last save. The cards show them after a save was tried; the editors
// under their fields.

type Problems = Record<string, string>;

function tooLong(problems: Problems, t: Messages, field: string, value: string | null, max: number) {
  if ((value ?? '').trim().length > max) problems[field] = t.formTooLong(max);
}

function serverProblems(problems: Problems, t: Messages, entry: ReviewEntry) {
  for (const field of entry.serverErrors) problems[field] ??= t.formServerFieldError;
}

export function recordProblems(t: Messages, record: ReviewRecord, today: string): Problems {
  const problems: Problems = {};
  // Without a title of its own the record goes under its kind's name, which always fits.
  const title = record.title?.trim();
  if (title !== undefined && title === '') problems.title = t.recordTitleRequired;
  else tooLong(problems, t, 'title', record.title, CARE_MAX.title);
  const { performedOn, validFrom, validUntil } = record;
  if (performedOn === null) problems.performedOn = t.dateRequired;
  else if (performedOn > today) problems.performedOn = t.scanDateInFuture;
  else if (performedOn < EARLIEST_CARE_DATE) problems.performedOn = t.dateTooEarly;
  tooLong(problems, t, 'product', record.product, CARE_MAX.product);
  tooLong(problems, t, 'manufacturer', record.manufacturer, CARE_MAX.manufacturer);
  tooLong(problems, t, 'batchNumber', record.batchNumber, CARE_MAX.batchNumber);
  if (validFrom && performedOn && validFrom < performedOn) problems.validFrom = t.recordValidFromInvalid;
  if (validUntil && ((performedOn && validUntil <= performedOn) || (validFrom && validUntil < validFrom))) {
    problems.validUntil = t.recordValidUntilInvalid;
  }
  tooLong(problems, t, 'clinic', record.clinic, CARE_MAX.clinic);
  tooLong(problems, t, 'veterinarian', record.veterinarian, CARE_MAX.veterinarian);
  // Another kind doesn't send its weight, so only a check-up's counts.
  const weight = record.weightKg;
  if (weight !== null && usesExam(record.kind) && (weight <= 0 || weight > MAX_KG)) problems.weightKg = t.weightInvalid;
  serverProblems(problems, t, record);
  return problems;
}

/** `otherCodes`: the normalized codes of the ticked identifiers before it; `over`: the pet would pass its five. */
export function identifierProblems(
  t: Messages,
  identifier: ReviewIdentifier,
  today: string,
  otherCodes: readonly string[] = [],
  over = false,
): Problems {
  const problems: Problems = {};
  if (over) problems.entry = t.scanTooManyIdentifiers(MAX_IDENTIFIERS);
  const problem = identifierProblem(identifier.type, identifier.code, otherCodes);
  if (problem) problems.code = identifierProblemLabel(t, problem);
  if (identifier.appliedOn && identifier.appliedOn > today) problems.appliedOn = t.scanDateInFuture;
  tooLong(problems, t, 'location', identifier.location, MAX_LOCATION_LENGTH);
  serverProblems(problems, t, identifier);
  return problems;
}

export function passportProblems(t: Messages, passport: ReviewPassport, today: string): Problems {
  const problems: Problems = {};
  if (!passportNumberOk(passport.passportNumber ?? '')) problems.passportNumber = t.passportNumberInvalid;
  if (!countryOk(passport.issuingCountry ?? '')) problems.issuingCountry = t.passportCountryInvalid;
  if (passport.issuedOn && passport.issuedOn > today) problems.issuedOn = t.scanDateInFuture;
  serverProblems(problems, t, passport);
  return problems;
}

/** Checked like a weighing added on the Weight tab: `firstDate` is the pet's exact birth date, else 1990. */
export function weightProblems(t: Messages, weight: ReviewWeight, today: string, firstDate: string): Problems {
  const problems: Problems = {};
  const { measuredOn, weightKg } = weight;
  if (measuredOn === null) problems.measuredOn = t.dateRequired;
  else if (measuredOn > today) problems.measuredOn = t.scanDateInFuture;
  else if (measuredOn < EARLIEST_WEIGHT_DATE) problems.measuredOn = t.dateTooEarly;
  else if (measuredOn < firstDate) problems.measuredOn = t.weightDateBeforeBirth;
  if (weightKg === null) problems.weightKg = t.weightRequired;
  else if (grams(weightKg) <= 0 || grams(weightKg) > MAX_KG * 1000) problems.weightKg = t.weightInvalid;
  serverProblems(problems, t, weight);
  return problems;
}
