// Files on screen: the drop zone that takes photos and PDF files dragged from the computer (or picked), the progress
// of an upload, and a file as a tile: a photo's small picture, or a PDF that opens in a new tab. Download links expire
// after 15 minutes: a picture keeps the link it was first shown with while that lives (api/files.ts), and asks for a
// fresh one when it died while the page stood open; a PDF's link is renewed before it expires (PdfLink).
import { useEffect, useRef, useState, type DragEvent, type ReactNode } from 'react';
import {
  FILE_ACCEPT,
  fileProblem,
  fileUrl,
  freshFileLink,
  isPdf,
  linkLives,
  PHOTO_ACCEPT,
  photoProblem,
} from '../api/files';
import type { FileLink } from '../api/types';
import { errorMessage } from '../api/errors';
import { useApi } from '../household/household';
import { useI18n, type I18n } from '../i18n/i18n';
import { Icon } from './Icon';
import { Notice, Spinner } from './ui';
import type { Upload } from './useUpload';

/** Only a drag that carries files is taken: a dragged link or text goes its own way. */
const carriesFiles = (event: DragEvent) => Array.from(event.dataTransfer.types).includes('Files');

/**
 * An area that takes files dropped onto it, with a button to pick them. Each file is checked first (a photo, or a
 * PDF too unless `photosOnly`; up to 15 MB): the refused ones are listed with the reason, the others go to `onFiles`
 * in the order they came. Whatever `children` it wraps (a grid of pages) takes drops as well.
 *
 * With `prepare` (a HEIC photo turned into a JPEG takes a moment), the area is busy until the files are ready: it
 * says so, takes no other files meanwhile, and tells `onPreparing`; files ready after the area is gone go nowhere.
 */
export function FileDrop({
  buttonLabel,
  hint,
  onFiles,
  disabled = false,
  photosOnly = false,
  prepare,
  onPreparing,
  accept,
  primary = false,
  children,
}: {
  buttonLabel: string;
  /** Under the button: "Or drag photos and PDF files here." */
  hint: string;
  onFiles: (files: File[]) => void;
  disabled?: boolean;
  photosOnly?: boolean;
  /**
   * Checks the files instead of the usual check, and may change them (a HEIC photo made a JPEG for AI): the ones to
   * take, in order, and why the others can't be.
   */
  prepare?: (files: File[]) => Promise<{ files: File[]; refused: string[] }>;
  /** Hears when `prepare` starts and ends: leaving meanwhile asks first, another reader waits. */
  onPreparing?: (preparing: boolean) => void;
  /** What the file picker offers, when not the usual photos (and PDF files). */
  accept?: string;
  /** The page's main action (the Documents tab): a primary button. */
  primary?: boolean;
  children?: ReactNode;
}) {
  const { t } = useI18n();
  const input = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const [refused, setRefused] = useState<string[]>([]);
  // Files being prepared: as state for the screen, and as a ref for a second drop in the same moment.
  const [preparing, setPreparing] = useState(false);
  const busy = useRef(false);
  const alive = useRef(true);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);
  const off = disabled || preparing;

  function take(list: FileList | null | undefined) {
    const files = Array.from(list ?? []);
    if (!files.length) return;
    if (prepare) {
      if (busy.current) return;
      busy.current = true;
      setPreparing(true);
      onPreparing?.(true);
      void prepare(files)
        .then(
          (prepared) => {
            if (!alive.current) return;
            setRefused(prepared.refused);
            if (prepared.files.length) onFiles(prepared.files);
          },
          () => {
            // Nothing could be prepared: nothing is taken.
          },
        )
        .finally(() => {
          busy.current = false;
          if (!alive.current) return;
          setPreparing(false);
          onPreparing?.(false);
        });
      return;
    }
    const accepted: File[] = [];
    const reasons: string[] = [];
    for (const file of files) {
      const problem = photosOnly ? photoProblem(file) : fileProblem(file);
      if (problem) reasons.push(t.fileRefused(file.name, t[problem]));
      else accepted.push(file);
    }
    setRefused(reasons);
    if (accepted.length) onFiles(accepted);
  }

  return (
    <div
      className={`file-drop${dragging ? ' is-dragging' : ''}`}
      onDragOver={(event) => {
        if (!carriesFiles(event) || off) return;
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
        setDragging(true);
      }}
      onDragLeave={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setDragging(false);
      }}
      onDrop={(event) => {
        if (!carriesFiles(event)) return;
        event.preventDefault();
        setDragging(false);
        if (!off) take(event.dataTransfer.files);
      }}
    >
      <div className="file-drop-actions">
        <button
          type="button"
          className={`button ${primary ? 'button--primary' : 'button--secondary'}`}
          onClick={() => input.current?.click()}
          disabled={off}
        >
          <Icon name="upload_file" size={18} />
          {buttonLabel}
        </button>
        {preparing ? (
          <span className="loading-inline field-hint" role="status">
            <Spinner />
            {t.filesPreparing}
          </span>
        ) : (
          <span className="field-hint">{hint}</span>
        )}
      </div>
      {children}
      <input
        ref={input}
        className="visually-hidden"
        type="file"
        multiple
        accept={accept ?? (photosOnly ? PHOTO_ACCEPT : FILE_ACCEPT)}
        tabIndex={-1}
        aria-hidden="true"
        onChange={(event) => {
          take(event.target.files);
          // The same files again are a new choice.
          event.target.value = '';
        }}
      />
      {refused.length > 0 && (
        <div className="field-error" role="alert">
          <Icon name="error" size={16} />
          <ul className="plain-list">
            {refused.map((reason) => (
              <li key={reason}>{reason}</li>
            ))}
          </ul>
        </div>
      )}
      {dragging && (
        <span className="file-drop-target" aria-hidden="true">
          {t.filesDropHere}
        </span>
      )}
    </div>
  );
}

/** How an upload goes: "Uploading 2 of 5…" with a bar, or why it failed with "Try again". */
export function UploadStatus({ upload, retryLabel }: { upload: Upload; retryLabel?: string }) {
  const { t } = useI18n();
  if (upload.progress) return <UploadProgress done={upload.progress.done} total={upload.progress.total} />;
  if (!upload.failure) return null;
  return (
    <Notice tone="danger">
      <p>{errorMessage(t, upload.failure)}</p>
      <div className="notice-actions">
        {upload.canRetry && (
          <button type="button" className="button button--secondary" onClick={() => void upload.retry()}>
            <Icon name="refresh" size={18} />
            {retryLabel ?? t.commonTryAgain}
          </button>
        )}
        <button type="button" className="button button--ghost" onClick={upload.dismiss}>
          {t.commonClose}
        </button>
      </div>
    </Notice>
  );
}

/** "Uploading 2 of 5…", with a bar. */
export function UploadProgress({ done, total }: { done: number; total: number }) {
  const { t } = useI18n();
  return (
    <div className="upload-progress" role="status">
      <Spinner />
      <span>{t.filesUploading(Math.min(done + 1, total), total)}</span>
      <progress max={total} value={done} aria-hidden="true" />
    </div>
  );
}

/** "1.2 MB", "350 KB". */
export function fileSizeLabel(i18n: I18n, bytes: number): string {
  if (bytes >= 1024 * 1024) return i18n.t.fileSizeMb(i18n.number(bytes / (1024 * 1024), 1));
  return i18n.t.fileSizeKb(i18n.number(Math.max(1, Math.round(bytes / 1024)), 0));
}

/**
 * A stored photo. Its link may have expired while the page stood open: then it asks once for a fresh one; when that
 * fails too, it says the file couldn't be loaded.
 */
export function FileImage({
  file,
  thumbnail,
  alt,
  className,
}: {
  file: FileLink;
  thumbnail: boolean;
  alt: string;
  className?: string;
}) {
  const { t } = useI18n();
  const api = useApi();
  const [state, setState] = useState<'first' | 'renewing' | 'renewed' | 'gone'>('first');

  if (state === 'gone') {
    return (
      <span
        className={`file-missing${className ? ` ${className}` : ''}`}
        role="img"
        aria-label={`${alt}. ${t.fileLoadFailed}`}
      >
        <Icon name="error" />
      </span>
    );
  }
  return (
    <img
      className={className}
      src={fileUrl(file, thumbnail)}
      alt={alt}
      loading="lazy"
      onError={() => {
        if (state === 'renewed') {
          setState('gone');
          return;
        }
        if (state !== 'first') return;
        setState('renewing');
        // A fresh link replaces the one shown (fileUrl gives it from now on).
        freshFileLink(api, file.id).then(
          () => setState('renewed'),
          () => setState('gone'),
        );
      }}
    />
  );
}

/** A link is renewed this long before it expires, so the one in a PDF's address always works. */
const RENEW_BEFORE_MS = 90_000;

/**
 * A link that opens a stored PDF in a new tab, in the browser's own viewer. Its address is the newest link the page
 * has (a PDF isn't loaded before it is opened, so no older one is kept for it), renewed shortly before it expires
 * (GET /files/{id}/url): a click, a middle click and "Open in new tab" all find a link that works, and the tab never
 * opens on "access denied". Should the link have died all the same (the renewal failed, the computer slept), a click
 * opens the tab at once, while it still counts as the person's (a window opened after waiting is taken for a pop-up
 * and blocked), and sends it to a fresh link.
 */
export function PdfLink({
  file,
  label,
  className,
  children,
}: {
  file: FileLink;
  /** What a screen reader hears: "Page 2: open the PDF in a new tab". */
  label: string;
  className?: string;
  children: ReactNode;
}) {
  const api = useApi();
  const [renewed, setRenewed] = useState<FileLink | null>(null);
  // The newer of the two: the page's (an answer read again brings fresh links) and one renewed here.
  const link = renewed && Date.parse(renewed.expiresAt) > Date.parse(file.expiresAt) ? renewed : file;

  useEffect(() => {
    const wait = Math.max(0, Date.parse(link.expiresAt) - RENEW_BEFORE_MS - Date.now());
    const timer = window.setTimeout(() => {
      // Not renewed (no connection): a click renews it.
      freshFileLink(api, file.id).then(setRenewed, () => {});
    }, wait);
    return () => window.clearTimeout(timer);
  }, [api, file.id, link.expiresAt]);

  return (
    <a
      className={className}
      href={link.url}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={label}
      onClick={(event) => {
        if (linkLives(link)) return;
        event.preventDefault();
        const tab = window.open('', '_blank');
        if (tab) tab.opener = null;
        freshFileLink(api, file.id).then(
          (fresh) => {
            setRenewed(fresh);
            if (tab) tab.location.href = fresh.url;
            else window.open(fresh.url, '_blank', 'noopener,noreferrer');
          },
          () => tab?.close(),
        );
      }}
    >
      {children}
    </a>
  );
}

/**
 * A stored file as a tile: a photo's small picture (a button that opens it large) or a PDF (a link to a new tab),
 * with a remove button in its corner when it can be removed.
 */
export function FileTile({
  file,
  label,
  onOpen,
  onRemove,
  removeLabel,
}: {
  file: FileLink;
  /** "Page 2", "File 3". */
  label: string;
  /** Opens a photo large; a PDF opens in a new tab by itself. */
  onOpen: () => void;
  onRemove?: () => void;
  removeLabel?: string;
}) {
  const i18n = useI18n();
  return (
    <li className="file-tile">
      {isPdf(file) ? (
        <PdfLink file={file} label={i18n.t.fileOpenPdf(label)} className="file-tile-open file-tile-pdf">
          <Icon name="picture_as_pdf" size={32} />
          <span className="file-tile-name">{i18n.t.filePdf}</span>
          <span className="file-tile-size">{fileSizeLabel(i18n, file.sizeBytes)}</span>
        </PdfLink>
      ) : (
        <button type="button" className="file-tile-open" onClick={onOpen}>
          <FileImage file={file} thumbnail alt={label} />
        </button>
      )}
      {onRemove && (
        <button
          type="button"
          className="icon-button file-tile-remove"
          aria-label={removeLabel}
          title={removeLabel}
          onClick={onRemove}
        >
          <Icon name="close" size={18} />
        </button>
      )}
    </li>
  );
}

/** A file picked on this computer and not uploaded yet: its picture (from memory) or a PDF with its name. */
export function LocalFileTile({
  file,
  preview,
  label,
  onRemove,
  removeLabel,
}: {
  file: File;
  /** An object URL of a picked photo. */
  preview: string | null;
  label: string;
  onRemove?: () => void;
  removeLabel: string;
}) {
  const i18n = useI18n();
  return (
    <li className="file-tile">
      <span className="file-tile-open" role="img" aria-label={`${label}: ${file.name}`}>
        {preview ? (
          <img src={preview} alt="" />
        ) : (
          <span className="file-tile-pdf">
            <Icon name="picture_as_pdf" size={32} />
            <span className="file-tile-name">{file.name}</span>
            <span className="file-tile-size">{fileSizeLabel(i18n, file.size)}</span>
          </span>
        )}
        <span className="file-tile-number" aria-hidden="true">
          {label}
        </span>
      </span>
      {onRemove && (
        <button
          type="button"
          className="icon-button file-tile-remove"
          aria-label={removeLabel}
          title={removeLabel}
          onClick={onRemove}
        >
          <Icon name="close" size={18} />
        </button>
      )}
    </li>
  );
}
