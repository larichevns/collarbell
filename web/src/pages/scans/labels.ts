// Words for the scans and notes (the phone app's ai_labels.dart): a scan's status, why one failed, what a doubt of
// the AI means, what saving did, a record's title when the page names none.
import type { AiImport, AiImportError, AiImportSource, AiImportStatus, ApplyImportResponse, CareKind, DraftIssue, VaccineTarget } from '../../api/types';
import type { Messages } from '../../i18n/en';
import type { PassportField } from './review';

/** At most this many photos a scan (the server's limit). */
export const MAX_SCAN_PHOTOS = 10;
/** At most this many characters in a note, counted after trimming, as the server counts them (UTF-16 units). */
export const MAX_NOTE_LENGTH = 1000;
/** How many notes AI reads for one person a day, when the server's refusal doesn't say (its Ai:TextEntriesPerDay). */
export const NOTES_PER_DAY = 30;
/** At most this many photos of a chip sticker or a package (the server's limits). */
export const MAX_READER_PHOTOS = 3;

/** The length of a note as the server counts it against the limit: trimmed, in UTF-16 units (an emoji counts 2). */
export function noteLength(text: string): number {
  return text.trim().length;
}

/**
 * Whether a note has something to read: a letter or a digit, as the server checks it (.NET's char.IsLetterOrDigit
 * on each UTF-16 unit, so letters and digits of the Basic Multilingual Plane). Punctuation, emoji and invisible
 * characters alone are no note.
 */
export function noteHasWords(text: string): boolean {
  // The server looks at one UTF-16 unit at a time: a character outside the Basic Multilingual Plane (a surrogate
  // pair, like most emoji) is no letter there. Without the u flag, the class matches each unit of a pair.
  return /[\p{L}\p{Nd}]/u.test(text.replace(/[\uD800-\uDFFF]/g, ''));
}

export function isNote(scan: Pick<AiImport, 'source'>): boolean {
  return scan.source === 'Text';
}

/** A failed scan can be read again while its photos are there; a failed note, while its text is. */
export function canReadAgain(scan: Pick<AiImport, 'status' | 'source' | 'text' | 'pages' | 'error'>): boolean {
  if (scan.status !== 'Failed') return false;
  if (isNote(scan)) return !!scan.text?.trim();
  return scan.pages.length > 0 && scan.error !== 'PhotosMissing';
}

/**
 * The scan or note that took the place of `failed` when it was read again (by "Try again" here before, or in another
 * tab): of those waiting, newest first, the scan with any of its photos, or the note of its day (a note read again
 * unchanged keeps the day it was written). Null when none of them is.
 */
export function successorOf(failed: AiImport, waiting: readonly AiImport[]): AiImport | null {
  const others = waiting.filter((each) => each.id !== failed.id && isNote(each) === isNote(failed));
  if (isNote(failed)) return others.find((each) => each.createdAt === failed.createdAt) ?? null;
  const photos = new Set(failed.pages.map((page) => page.id));
  return others.find((each) => each.pages.some((page) => photos.has(page.id))) ?? null;
}

/** A new scan of the same kind as `scan` (a vet document's again as a vet document), back to `tab`. */
export function scanAgainPath(petId: string, scan: Pick<AiImport, 'source'>, tab: 'passport' | 'health'): string {
  return `/pets/${petId}/scan?${scan.source === 'VetDocument' ? 'source=document&' : ''}from=${tab}`;
}

/** The title of the scan page for what is read. */
export function scanTitle(t: Messages, source: AiImportSource): string {
  return source === 'Text' ? t.noteTitle : source === 'VetDocument' ? t.scanTitleDocument : t.scanTitlePassport;
}

/** The status of a scan, or of a note ("Reading the note…"). */
export function scanStatusLabel(t: Messages, status: AiImportStatus, note = false): string {
  return note && status === 'Processing' ? t.noteStatusProcessing : t.scanStatus[status];
}

/** Why a scan (or a note) failed, with what to do; a reason the app can't name reads as "something went wrong". */
export function scanErrorMessage(t: Messages, error: AiImportError | null, note = false): string {
  switch (error) {
    case 'Busy':
      return t.scanErrorBusy;
    case 'NotConfigured':
      return note ? t.noteErrorNotConfigured : t.scanErrorNotConfigured;
    case 'Rejected':
      return t.scanErrorRejected;
    // A note has no photos to lose.
    case 'PhotosMissing':
      return note ? t.noteErrorUnexpected : t.scanErrorPhotosMissing;
    default:
      return note ? t.noteErrorUnexpected : t.scanErrorUnexpected;
  }
}

/**
 * What a doubt about a value means: "Day and month could be swapped. Check against the paper." `identifier` words
 * "already saved" for a microchip number, `weight` "already saved" and "repeated" for a weight; `fromNote`, the doubts
 * are about a note the person wrote, not a paper.
 */
export function draftIssueMessage(
  t: Messages,
  issue: DraftIssue,
  { identifier = false, weight = false, fromNote = false }: { identifier?: boolean; weight?: boolean; fromNote?: boolean } = {},
): string {
  switch (issue) {
    case 'Unreadable':
      return fromNote ? t.noteIssueUnreadable : t.scanIssueUnreadable;
    case 'Ambiguous':
      return fromNote ? t.noteIssueAmbiguous : t.scanIssueAmbiguous;
    case 'InFuture':
      return t.scanIssueInFuture;
    case 'EndsBeforeStart':
      return t.scanIssueEndsBeforeStart;
    case 'InvalidFormat':
      return fromNote ? t.noteIssueInvalidFormat : t.scanIssueInvalidFormat;
    case 'AlreadySaved':
      return weight ? t.scanWeightAlreadySaved : identifier ? t.scanIssueAlreadySavedCode : t.scanIssueAlreadySaved;
    case 'Repeated':
      return weight ? t.scanWeightRepeated : fromNote ? t.noteIssueRepeated : t.scanIssueRepeated;
    case 'DiffersFromSaved':
      return t.scanBadgeDiffers;
    default:
      // An issue of a newer server.
      return t.scanIssueOther;
  }
}

/** The badge of a doubt about a whole entry; null for doubts about one value. */
export function draftIssueBadge(t: Messages, issue: DraftIssue): string | null {
  switch (issue) {
    case 'AlreadySaved':
      return t.scanBadgeAlreadySaved;
    case 'Repeated':
      return t.scanBadgeRepeated;
    case 'DiffersFromSaved':
      return t.scanBadgeDiffers;
    default:
      return null;
  }
}

/** A passport field in a sentence, in lower case: "number", «номер». */
export function passportFieldLabel(t: Messages, field: PassportField): string {
  return t.scanPassportField[field];
}

/**
 * What saving a scan did: "Saved 3 records · 1 plan updated · 1 weighing added · photos added to the passport pages".
 * `passportFields` and `identifiersSent` are what the save sent, when known: they say which passport details
 * changed, and that numbers the pet had already were skipped.
 */
export function scanResultSummary(
  t: Messages,
  result: ApplyImportResponse,
  source: AiImportSource,
  { passportFields = [], identifiersSent = 0 }: { passportFields?: readonly PassportField[]; identifiersSent?: number } = {},
): string {
  const skipped = identifiersSent - result.identifiersAdded;
  const parts = [
    result.recordIds.length > 0 && t.scanSavedRecords(result.recordIds.length),
    result.plansMoved > 0 && t.scanSavedPlans(result.plansMoved),
    result.weightsAdded > 0 && t.scanSavedWeights(result.weightsAdded),
    result.identifiersAdded > 0 && t.scanSavedIdentifiers(result.identifiersAdded),
    skipped > 0 && t.scanSkippedIdentifiers(skipped),
    result.passportUpdated &&
      (passportFields.length
        ? t.scanSavedPassportFields(passportFields.map((field) => passportFieldLabel(t, field)).join(', '))
        : t.scanSavedPassport),
    result.documentId !== null &&
      (source === 'PassportPages' ? t.scanSavedPhotosPassport : t.scanSavedPhotosDocument),
  ].filter((part): part is string => !!part);
  if (!parts.length) return t.scanSavedNothing;
  // The parts read as one sentence: only its first letter is a capital.
  const text = parts.join(' · ');
  return text[0]!.toUpperCase() + text.slice(1);
}

/** The title of a scanned record whose page names none: "Rabies vaccination", else the kind's name. */
export function scanDefaultTitle(t: Messages, kind: CareKind, targets: readonly VaccineTarget[]): string {
  return kind === 'Vaccination' && targets.includes('Rabies') ? t.scanTitleRabiesVaccination : t.careKind[kind];
}
