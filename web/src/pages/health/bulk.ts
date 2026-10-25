// The rows of the bulk entry of a passport's history: each row is one record (its kind, date, product, batch, how long
// a vaccine protects, the vet; what a vaccine protects against; the hour of a treatment before travel), checked like
// the record form and sent as its own POST /pets/{id}/care-records. A row keeps one request id until it is saved, so
// a retry after a lost answer adds nothing twice.
import type { CareKind, CareRecord, CareRecordRequest, VaccineTarget } from '../../api/types';
import type { Messages } from '../../i18n/en';
import {
  CARE_MAX,
  defaultRecordTitle,
  EARLIEST_CARE_DATE,
  latestDueDate,
  orderedTargets,
  usesProduct,
  usesTargets,
  usesTime,
  usesValidity,
} from '../../lib/care';
import { apiTime } from '../../lib/dates';

export interface BulkRow {
  /** Keeps a row's fields when a row above it goes. */
  key: string;
  /** Sent with every try of this row: the server answers a retry with the record the first try added. */
  requestId: string;
  /** Something was typed or chosen: an untouched row is left out of saving. */
  touched: boolean;
  kind: CareKind;
  performedOn: string;
  time: string;
  product: string;
  batch: string;
  validFrom: string;
  validUntil: string;
  vet: string;
  targets: VaccineTarget[];
}

/** The fields of a row, by the server's names (a 400 names them so). */
export type BulkField =
  | 'kind'
  | 'title'
  | 'performedOn'
  | 'performedTime'
  | 'product'
  | 'batchNumber'
  | 'validFrom'
  | 'validUntil'
  | 'veterinarian'
  | 'targets';

export const BULK_FIELDS: readonly BulkField[] = [
  'kind',
  'title',
  'performedOn',
  'performedTime',
  'product',
  'batchNumber',
  'validFrom',
  'validUntil',
  'veterinarian',
  'targets',
];

/**
 * A new row. It takes the kind, the vaccine's targets, the product and the vet of the row above: a passport's lines
 * often repeat them; the date, the batch and the validity are each line's own.
 */
export function newRow(above?: BulkRow): BulkRow {
  return {
    key: crypto.randomUUID(),
    requestId: crypto.randomUUID(),
    touched: false,
    kind: above?.kind ?? 'Vaccination',
    performedOn: '',
    time: '',
    product: above?.product ?? '',
    batch: '',
    validFrom: '',
    validUntil: '',
    vet: above?.vet ?? '',
    targets: above?.targets ?? [],
  };
}

/** Which fields a row of this kind has. */
export function rowFields(kind: CareKind) {
  return {
    time: usesTime(kind),
    product: usesProduct(kind),
    validity: usesValidity(kind),
    targets: usesTargets(kind),
  };
}

/** What the app can see is wrong with a row, by field: the record form's checks. */
export function rowProblems(t: Messages, row: BulkRow, today: string): Partial<Record<BulkField, string>> {
  const has = rowFields(row.kind);
  const found: Partial<Record<BulkField, string>> = {};
  const { performedOn, validFrom, validUntil } = row;
  if (!performedOn) found.performedOn = t.dateRequired;
  else if (performedOn < EARLIEST_CARE_DATE) found.performedOn = t.dateTooEarly;
  else if (performedOn > today) found.performedOn = t.dateInFuture;
  if (has.product && row.product.trim().length > CARE_MAX.product) found.product = t.formTooLong(CARE_MAX.product);
  if (has.product && row.batch.trim().length > CARE_MAX.batchNumber) {
    found.batchNumber = t.formTooLong(CARE_MAX.batchNumber);
  }
  if (row.vet.trim().length > CARE_MAX.veterinarian) found.veterinarian = t.formTooLong(CARE_MAX.veterinarian);
  if (has.validity) {
    const latest = latestDueDate(today);
    if (validFrom && ((performedOn && validFrom < performedOn) || validFrom > latest)) {
      found.validFrom = t.recordValidFromInvalid;
    }
    if (validUntil && ((performedOn && validUntil <= performedOn) || (validFrom && validUntil < validFrom))) {
      found.validUntil = t.recordValidUntilInvalid;
    } else if (validUntil > latest) {
      found.validUntil = t.recordValidUntilInvalid;
    }
  }
  return found;
}

/** The record a row becomes. Its title is the phone's default: "Rabies" for a rabies vaccine, else the kind's name. */
export function rowRequest(t: Messages, row: BulkRow): CareRecordRequest {
  const has = rowFields(row.kind);
  const clean = (value: string) => value.trim() || null;
  const targets = has.targets ? orderedTargets(row.targets) : [];
  return {
    kind: row.kind,
    title: defaultRecordTitle(t, row.kind, targets),
    performedOn: row.performedOn,
    performedTime: has.time && row.time ? apiTime(row.time) : null,
    product: has.product ? clean(row.product) : null,
    manufacturer: null,
    batchNumber: has.product ? clean(row.batch) : null,
    validFrom: has.validity ? row.validFrom || null : null,
    validUntil: has.validity ? row.validUntil || null : null,
    targets,
    clinic: null,
    veterinarian: clean(row.vet),
    weightKg: null,
    details: null,
    notes: null,
    requestId: row.requestId,
  };
}

/**
 * Whether the record the server answered with says what the row says. A retry after a lost answer gets the record the
 * first try added, as it was then: if the row was corrected meanwhile, the correction goes after it (PUT).
 */
export function rowHolds(record: CareRecord, request: CareRecordRequest): boolean {
  const time = (value: string | null) => (value ? value.slice(0, 5) : null);
  return (
    record.kind === request.kind &&
    record.title === request.title &&
    record.performedOn === request.performedOn &&
    time(record.performedTime) === time(request.performedTime) &&
    record.product === request.product &&
    record.batchNumber === request.batchNumber &&
    record.validFrom === request.validFrom &&
    record.validUntil === request.validUntil &&
    record.veterinarian === request.veterinarian &&
    orderedTargets(record.targets).join() === (request.targets ?? []).join()
  );
}
