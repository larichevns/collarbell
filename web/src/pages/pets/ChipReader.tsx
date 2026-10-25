// A microchip number read from a photo (the phone app's chip_reader.dart, "From a photo"): a photo of the chip sticker
// or of the passport page, picked or dropped on a microchip's card in the pet form, goes to AI (POST /files, then
// POST /pets/identifiers/scan; nothing is saved) and the number it finds fills the card, with a word to check it
// against the passport. Two numbers or more: the person picks the one of this card. None: the card says so. The phone
// looks for the barcode first; a browser has no reader of its own, so the photo always goes to AI, after the free
// tier's warning. Reading takes a few seconds, sometimes a minute; "Cancel" drops its answer. One card reads at a
// time (IdentifierFields): each answer finds its card. AI not set up (any more): the readers go from the form.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useEffectEvent, useRef, useState } from 'react';
import { aiErrorMessage, isAiLimit, isAiNotSetUp } from '../../api/aiErrors';
import { ApiError, data, type ApiClient } from '../../api/client';
import { uploadFile } from '../../api/files';
import { refreshAiStatus } from '../../api/queries';
import type { IdentifierReading } from '../../api/types';
import { Dialog, DialogBody, DialogFoot } from '../../components/Dialog';
import { FileDrop } from '../../components/Files';
import { Spinner } from '../../components/ui';
import { useI18n, type I18n } from '../../i18n/i18n';
import { displayCode, identifierProblem } from '../../lib/identifiers';
import { identifierProblemLabel } from '../../lib/labels';
import { MAX_READER_PHOTOS } from '../scans/labels';
import { AI_PHOTO_ACCEPT, preparePhotos } from '../scans/photos';

/** How a reading went, as the card says it. */
export interface ChipNote {
  text: string;
  failed: boolean;
}

/** Why AI couldn't read the photo, in words: the server's 409 (no AI), 502 (refused), 503 (busy), the month's photos. */
export function chipScanErrorMessage(i18n: I18n, error: unknown): string {
  const { t } = i18n;
  if (!isAiLimit(error) && error instanceof ApiError) {
    if (error.status === 409) return t.chipScanNoAi;
    if (error.status === 502) return t.chipScanRejected;
    if (error.status === 503) return t.chipScanBusy;
  }
  return aiErrorMessage(i18n, error);
}

/** Uploads the photos and asks AI for the numbers on them; `signal` stops it. */
export async function readChipPhotos(api: ApiClient, photos: readonly File[], signal: AbortSignal) {
  const fileIds: string[] = [];
  for (const photo of photos) {
    signal.throwIfAborted();
    fileIds.push((await uploadFile(api, photo)).id);
  }
  signal.throwIfAborted();
  const read = await data(api.POST('/api/v1/pets/identifiers/scan', { body: { fileIds }, signal }));
  return read.identifiers;
}

/**
 * "Read from a photo" on a microchip's card: picks or takes dropped photos (up to 3), reads them while a dialog says
 * so (with "Cancel"), and hands over what was found, or says on the card why not.
 */
export function ChipPhotoReader({
  api,
  freeTier,
  disabled = false,
  onBusy,
  onFound,
  onFailed,
}: {
  api: ApiClient;
  freeTier: boolean;
  /** Another card's photo is being read: this one waits. */
  disabled?: boolean;
  /** Hears when this card's photo starts being prepared or read, and when that is over. */
  onBusy?: (busy: boolean) => void;
  /** The numbers found (none, one or more). */
  onFound: (readings: IdentifierReading[]) => void;
  onFailed: (message: string) => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const queryClient = useQueryClient();
  const [reading, setReading] = useState<AbortController | null>(null);
  const [preparing, setPreparing] = useState(false);
  const running = useRef<AbortController | null>(null);
  const busy = preparing || reading !== null;
  const tell = useEffectEvent((now: boolean) => onBusy?.(now));
  useEffect(() => {
    tell(busy);
    // Gone while busy (the card removed): the others needn't wait for it.
    return () => {
      if (busy) tell(false);
    };
  }, [busy]);
  // The card removed while its photo is read: the answer has nowhere to go.
  useEffect(() => () => running.current?.abort(), []);

  async function read(files: File[]) {
    const photos = files.slice(0, MAX_READER_PHOTOS);
    const controller = new AbortController();
    running.current = controller;
    setReading(controller);
    try {
      const readings = await readChipPhotos(api, photos, controller.signal);
      if (!controller.signal.aborted) onFound(readings);
    } catch (error) {
      if (!controller.signal.aborted) {
        // AI was turned off on the server meanwhile: the readers go from the form.
        if (isAiNotSetUp(error)) refreshAiStatus(queryClient);
        onFailed(chipScanErrorMessage(i18n, error));
      }
    } finally {
      if (running.current === controller) {
        running.current = null;
        setReading(null);
      }
    }
  }

  function cancel() {
    running.current?.abort();
    running.current = null;
    setReading(null);
  }

  return (
    <>
      <FileDrop
        buttonLabel={t.chipReadPhoto}
        hint={freeTier ? `${t.chipReadHint} ${t.chipScanFreeTier}` : t.chipReadHint}
        accept={AI_PHOTO_ACCEPT}
        prepare={(files) => preparePhotos(t, files)}
        onPreparing={setPreparing}
        disabled={reading !== null || disabled}
        onFiles={(files) => void read(files)}
      />
      {reading && (
        <Dialog title={t.chipReadPhoto} onClose={cancel}>
          <DialogBody>
            <p className="loading-inline" role="status">
              <Spinner />
              {t.chipScanReading}
            </p>
          </DialogBody>
          <DialogFoot>
            <button type="button" className="button button--ghost" onClick={cancel}>
              {t.commonCancel}
            </button>
          </DialogFoot>
        </Dialog>
      )}
    </>
  );
}

/**
 * Several numbers on the photo: which one is this card's? Each with its type and place, and what saving it would
 * refuse (in the app's own words; a rule of the server it doesn't know, as a word to check it). Null: none.
 */
export function ReadingPicker({
  readings,
  otherCodes,
  onPick,
  onClose,
}: {
  readings: readonly IdentifierReading[];
  /** The normalized numbers of the form's other cards: one among them is said to be in the list already. */
  otherCodes: readonly string[];
  onPick: (reading: IdentifierReading) => void;
  onClose: () => void;
}) {
  const { t } = useI18n();
  return (
    <Dialog title={t.chipScanPickTitle} onClose={onClose}>
      <DialogBody>
        <ul className="card card--list rows">
          {readings.map((reading) => {
            const problem = identifierProblem(reading.type, reading.rawCode, otherCodes);
            const said = problem ? identifierProblemLabel(t, problem) : reading.problem ? t.formServerFieldError : null;
            return (
              <li key={`${reading.type}-${reading.code}`} className="row">
                <div className="row-main">
                  <button type="button" className="row-button row-link code" onClick={() => onPick(reading)}>
                    {displayCode(reading.type, reading.code)}
                  </button>
                  <span className="row-sub">
                    {[t.identifierType[reading.type], reading.location].filter(Boolean).join(' · ')}
                  </span>
                  {said && <span className="row-sub danger-text">{said}</span>}
                </div>
              </li>
            );
          })}
        </ul>
      </DialogBody>
    </Dialog>
  );
}
