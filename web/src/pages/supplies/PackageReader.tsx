// "Fill from photos" in the new item's form (the phone app's product_scan_screen.dart, its photos): photos of the
// package (the front, and the side with the weight and composition; up to 3) go to AI (POST /files, then
// POST /products/scan with the barcode typed, if any), which reads the name, brand, kind, size and energy, and for a
// medicine how long a dose protects; the form fills in what it found (SupplyFormPage's fillFromPhotos). Nothing is
// saved here. The free tier's warning shows before anything is sent; reading takes a few seconds, sometimes a minute
// or two, and "Cancel" drops its answer. AI not set up (any more): the button goes from the form.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router';
import { aiErrorMessage, isAiLimit, isAiNotSetUp } from '../../api/aiErrors';
import { ApiError, data, type ApiClient } from '../../api/client';
import { uploadFile } from '../../api/files';
import { refreshAiStatus } from '../../api/queries';
import type { FileLink, ProductDraft } from '../../api/types';
import { Dialog, DialogBody, DialogCancel, DialogFoot } from '../../components/Dialog';
import { FileDrop, LocalFileTile } from '../../components/Files';
import { Icon } from '../../components/Icon';
import { Notice, Spinner } from '../../components/ui';
import { useI18n, type I18n } from '../../i18n/i18n';
import { MAX_READER_PHOTOS } from '../scans/labels';
import { AI_PHOTO_ACCEPT, preparePhotos } from '../scans/photos';

/** Why the package couldn't be read, and whether trying again can help. */
interface Failure {
  message: string;
  retry: boolean;
  aiLimit: boolean;
}

/**
 * The server's refusals of a package scan of `count` photos: 409 (no AI), 502 (refused), 503 (busy), the month's AI
 * photos; a 400: more photos than it reads (only other photos help), or uploads it refused (they go up anew).
 */
export function packageFailure(i18n: I18n, error: unknown, count: number): Failure {
  const { t } = i18n;
  if (isAiLimit(error)) return { message: aiErrorMessage(i18n, error), retry: false, aiLimit: true };
  if (error instanceof ApiError) {
    if (error.status === 400) {
      if (count === 0 || count > MAX_READER_PHOTOS) {
        return { message: t.aiPhotoCountRefused(MAX_READER_PHOTOS), retry: false, aiLimit: false };
      }
      return { message: t.scanPhotosRefused, retry: true, aiLimit: false };
    }
    if (error.status === 409) return { message: t.productScanNoAi, retry: false, aiLimit: false };
    if (error.status === 502) return { message: t.productScanRejected, retry: false, aiLimit: false };
    if (error.status === 503) return { message: t.productScanBusy, retry: true, aiLimit: false };
  }
  return { message: aiErrorMessage(i18n, error), retry: true, aiLimit: false };
}

export function PackageReader({
  available,
  api,
  freeTier,
  barcode,
  startOpen = false,
  onRead,
}: {
  /** AI is set up on the server: the button shows. A dialog open when it stops being stays until closed. */
  available: boolean;
  api: ApiClient;
  freeTier: boolean;
  /** The barcode typed in, when it is a valid one: kept when the photos don't show it. */
  barcode: string | null;
  /** Opened from the empty Supplies' "Fill in from photos": the dialog opens at once, once AI is known to be set up. */
  startOpen?: boolean;
  onRead: (read: ProductDraft) => void;
}) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const started = useRef(false);
  useEffect(() => {
    if (!startOpen || !available || started.current) return;
    started.current = true;
    setOpen(true);
  }, [startOpen, available]);
  if (!available && !open) return null;
  return (
    <>
      {available && (
        <button type="button" className="button button--secondary align-start" onClick={() => setOpen(true)}>
          <Icon name="photo_camera" size={18} />
          {t.productScanFill}
        </button>
      )}
      {open && (
        <PackageDialog
          api={api}
          freeTier={freeTier}
          barcode={barcode}
          onRead={(read) => {
            setOpen(false);
            onRead(read);
          }}
          onClose={() => setOpen(false)}
        />
      )}
    </>
  );
}

function PackageDialog({
  api,
  freeTier,
  barcode,
  onRead,
  onClose,
}: {
  api: ApiClient;
  freeTier: boolean;
  barcode: string | null;
  onRead: (read: ProductDraft) => void;
  onClose: () => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const queryClient = useQueryClient();
  const [photos, setPhotos] = useState<{ file: File; preview: string }[]>([]);
  // The photos as they are now, for photos that come in before the dialog draws again.
  const photosNow = useRef<{ file: File; preview: string }[]>([]);
  // Photos being prepared (an iPhone's HEIC made a JPEG): the drop zone waits, and closing asks first.
  const [preparing, setPreparing] = useState(false);
  const [tooMany, setTooMany] = useState(false);
  const [reading, setReading] = useState(false);
  const [failure, setFailure] = useState<Failure | null>(null);
  // Photos uploaded by an earlier try: "Try again" doesn't upload them twice.
  const uploaded = useRef(new Map<File, FileLink>());
  const running = useRef<AbortController | null>(null);
  const previews = useRef<string[]>([]);
  useEffect(
    () => () => {
      running.current?.abort();
      previews.current.forEach((url) => URL.revokeObjectURL(url));
    },
    [],
  );

  function show(next: { file: File; preview: string }[]) {
    photosNow.current = next;
    setPhotos(next);
  }

  function add(files: File[]) {
    const old = photosNow.current;
    const room = Math.max(0, MAX_READER_PHOTOS - old.length);
    setTooMany(files.length > room);
    const taken = files.slice(0, room).map((file) => {
      const preview = URL.createObjectURL(file);
      previews.current.push(preview);
      return { file, preview };
    });
    show([...old, ...taken]);
    setFailure(null);
  }

  function remove(index: number) {
    const old = photosNow.current;
    const gone = old[index];
    if (gone) {
      URL.revokeObjectURL(gone.preview);
      previews.current = previews.current.filter((url) => url !== gone.preview);
    }
    setTooMany(false);
    setFailure(null);
    show(old.filter((_, at) => at !== index));
  }

  async function read() {
    // Never more than it reads, whatever came in meanwhile.
    const sending = photosNow.current.slice(0, MAX_READER_PHOTOS);
    if (!sending.length || preparing) return;
    const controller = new AbortController();
    running.current = controller;
    setReading(true);
    setFailure(null);
    try {
      const fileIds: string[] = [];
      for (const { file } of sending) {
        let link = uploaded.current.get(file);
        if (!link) {
          link = await uploadFile(api, file);
          uploaded.current.set(file, link);
        }
        fileIds.push(link.id);
        controller.signal.throwIfAborted();
      }
      const read = await data(api.POST('/api/v1/products/scan', { body: { fileIds, barcode }, signal: controller.signal }));
      if (!controller.signal.aborted) onRead(read.product);
    } catch (error) {
      if (!controller.signal.aborted) {
        // Uploads it refused go up anew with "Try again".
        if (error instanceof ApiError && error.status === 400) uploaded.current.clear();
        // AI was turned off on the server meanwhile: "Fill from photos" goes from the form.
        if (isAiNotSetUp(error)) refreshAiStatus(queryClient);
        setFailure(packageFailure(i18n, error, sending.length));
      }
    } finally {
      if (running.current === controller) {
        running.current = null;
        setReading(false);
      }
    }
  }

  function cancel() {
    running.current?.abort();
    running.current = null;
    setReading(false);
  }

  return (
    <Dialog
      title={t.productScanTitle}
      onClose={reading ? cancel : onClose}
      changed={!reading && (photos.length > 0 || preparing)}
    >
      <DialogBody>
        <div className="form-stack">
          <p>{t.productScanPhotosHint}</p>
          {freeTier && <Notice tone="warning">{t.productScanFreeTier}</Notice>}
          {reading ? (
            <p className="loading-inline" role="status">
              <Spinner />
              {t.productScanReading}
            </p>
          ) : (
            <FileDrop
              buttonLabel={t.scanPhotosAdd}
              hint={t.productScanPhotosDrop}
              accept={AI_PHOTO_ACCEPT}
              prepare={(files) => preparePhotos(t, files)}
              onPreparing={setPreparing}
              disabled={photos.length >= MAX_READER_PHOTOS}
              onFiles={add}
            >
              {photos.length > 0 && (
                <ul className="file-grid">
                  {photos.map((photo, index) => (
                    <LocalFileTile
                      key={photo.preview}
                      file={photo.file}
                      preview={photo.preview}
                      label={t.productScanPhoto(index + 1)}
                      onRemove={() => remove(index)}
                      removeLabel={t.productScanPhotoRemove(index + 1)}
                    />
                  ))}
                </ul>
              )}
            </FileDrop>
          )}
          {tooMany && <p className="field-hint">{t.productScanTooMany(MAX_READER_PHOTOS)}</p>}
          {failure && (
            <Notice tone="danger">
              <p>{failure.message}</p>
              {failure.aiLimit && <Link to="/settings">{t.aiSeePlan}</Link>}
            </Notice>
          )}
        </div>
      </DialogBody>
      <DialogFoot>
        {reading ? (
          // Drops the reading's answer; the photos stay.
          <button type="button" className="button button--ghost" onClick={cancel}>
            {t.commonCancel}
          </button>
        ) : (
          // Closes, after asking when photos are picked or being prepared.
          <DialogCancel />
        )}
        <button
          type="button"
          className="button button--primary"
          disabled={reading || preparing || photos.length === 0 || (failure !== null && !failure.retry)}
          onClick={() => void read()}
        >
          {reading && <Spinner />}
          {failure?.retry ? t.commonTryAgain : t.productScanRead}
        </button>
      </DialogFoot>
    </Dialog>
  );
}
