// Starting a scan or a note (the phone app's scan_screen.dart, _run): the photos picked on this computer upload one
// after another (POST /files), then the server starts reading them (POST /ai-imports); or the note is sent. One
// request id per scan or note the person starts, the same on every try: a retry after a lost answer gets the scan the
// first try started. "Try again" after a failed scan is a new scan of its photos (or its text) naming the failed one
// (retryOf): the server throws that away, whoever started it, and a note read again unchanged keeps the day it was
// written.
import { ApiError, data, type ApiClient } from '../../api/client';
import { aiErrorMessage, isAiLimit, isAiNotSetUp, noteLimitOf } from '../../api/aiErrors';
import { errorMessage, fieldErrorsOf } from '../../api/errors';
import { uploadFile } from '../../api/files';
import type { AiImport, AiImportSource, FileLink } from '../../api/types';
import type { I18n } from '../../i18n/i18n';
import { MAX_SCAN_PHOTOS } from './labels';

export interface Start {
  source: AiImportSource;
  /** Photos from this computer, in page order. */
  files: File[];
  /** The ones uploaded so far, in the same order: a retry uploads only the rest. */
  uploaded: FileLink[];
  /** Photos on the server already: a failed scan's, read again. */
  stored: FileLink[];
  /** The note, trimmed; null for photos. */
  text: string | null;
  /** The failed scan or note this reads again. */
  retryOf: string | null;
  /** One per scan or note the person starts, sent with every try. */
  requestId: string;
}

export function newStart(change: Partial<Start> & Pick<Start, 'source'>): Start {
  return {
    files: [],
    uploaded: [],
    stored: [],
    text: null,
    retryOf: null,
    requestId: crypto.randomUUID(),
    ...change,
  };
}

/** Uploads the photos still to go and starts the scan (or sends the note); `progress` hears the uploads. */
export async function startImport(
  api: ApiClient,
  petId: string,
  start: Start,
  progress: (done: number, total: number) => void,
): Promise<AiImport> {
  while (start.uploaded.length < start.files.length) {
    progress(start.uploaded.length, start.files.length);
    start.uploaded.push(await uploadFile(api, start.files[start.uploaded.length]!));
  }
  const fileIds = (start.stored.length ? start.stored : start.uploaded).map((file) => file.id);
  return data(
    api.POST('/api/v1/ai-imports', {
      body: {
        petId,
        source: start.source,
        fileIds,
        requestId: start.requestId,
        text: start.text,
        retryOf: start.retryOf,
      },
    }),
  );
}

/** Why a start failed, and what can be done about it. */
export interface StartFailure {
  message: string;
  /** Trying the same again can't help: AI is off, the photos are refused for good, the day's notes are used up. */
  dead: boolean;
  /** The month's AI photos: the plan is offered. */
  aiLimit: boolean;
  /** AI isn't set up (any more): its status is read again, and the scan buttons go. */
  notSetUp: boolean;
  /** The note's text was refused (empty or too long after all): said on its field. */
  textRefused: boolean;
}

/** A failed start in words (404, the pet gone, is the page's business). Refused uploads are dropped to go up anew. */
export function startFailure(i18n: I18n, error: unknown, start: Start): StartFailure {
  const { t } = i18n;
  const note = start.source === 'Text';
  const failure = (message: string, dead: boolean, more: Partial<StartFailure> = {}): StartFailure => ({
    message,
    dead,
    aiLimit: false,
    notSetUp: false,
    textRefused: false,
    ...more,
  });
  // The month's AI photos: a 409 of its own type. The same pages fail again; fewer may not.
  if (isAiLimit(error)) return failure(aiErrorMessage(i18n, error), true, { aiLimit: true });
  // The day's notes: a 429 of its own type. Any note fails until tomorrow.
  const notes = noteLimitOf(error);
  if (notes !== null) return failure(t.noteLimitReached(notes), true);
  if (isAiNotSetUp(error)) {
    return failure(note ? t.noteErrorNotConfigured : t.scanErrorNotConfigured, true, { notSetUp: true });
  }
  const status = error instanceof ApiError ? error.status : null;
  if (status === 400 || status === 422) {
    if (note && fieldErrorsOf(error).text) return failure(t.formCheckFields, false, { textRefused: true });
    if (note) return failure(errorMessage(t, error), false);
    // More photos than a scan takes (or none): the same ones fail every time, only other photos help.
    const count = (start.stored.length ? start.stored : start.files).length;
    if (count === 0 || count > MAX_SCAN_PHOTOS) return failure(t.aiPhotoCountRefused(MAX_SCAN_PHOTOS), true);
    // The photos of a failed scan can't be used any more.
    if (start.stored.length) return failure(t.scanErrorPhotosMissing, true);
    // The uploads were refused (used elsewhere meanwhile, or gone): "Try again" uploads the photos anew.
    start.uploaded = [];
    return failure(t.scanPhotosRefused, false);
  }
  // A photo itself is refused (too large, not a photo): only other photos help.
  if (status === 413 || status === 415) return failure(errorMessage(t, error), true);
  return failure(aiErrorMessage(i18n, error), false);
}
