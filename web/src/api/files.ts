// Files: uploading photos and scans, and the address to show one at. The server checks an upload by its content
// (JPEG, PNG, WebP or PDF, up to 15 MB) and answers with its id and a download link; putting it somewhere (a pet's
// photo, a document's page, a record's file) is a second call. A file belongs to one place only.
import { data, type ApiClient } from './client';
import type { FileLink } from './types';

/** The photo types the server takes. HEIC (iPhone photos) is not one of them. */
const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const PDF = 'application/pdf';
const MAX_BYTES = 15 * 1024 * 1024;

/** What a file picker offers for photos, and for pages and records' files (photos and PDF). */
export const PHOTO_ACCEPT = PHOTO_TYPES.join(',');
export const FILE_ACCEPT = [...PHOTO_TYPES, PDF].join(',');

/** Why a picked file can't be a photo, said before uploading it (a key of the messages); null when it can. */
export function photoProblem(file: File): 'errorFileUnsupported' | 'errorFileTooLarge' | null {
  if (!PHOTO_TYPES.includes(file.type)) return 'errorFileUnsupported';
  if (file.size > MAX_BYTES) return 'errorFileTooLarge';
  return null;
}

/** Why a file can't be a document's page or a record's file (a photo or a PDF up to 15 MB); null when it can. */
export function fileProblem(file: File): 'errorFileUnsupportedDocument' | 'errorFileTooLarge' | null {
  if (!PHOTO_TYPES.includes(file.type) && file.type !== PDF) return 'errorFileUnsupportedDocument';
  if (file.size > MAX_BYTES) return 'errorFileTooLarge';
  return null;
}

/** A PDF opens in the browser's own viewer, in a new tab; photos open in the app. */
export function isPdf(file: { contentType: string }): boolean {
  return file.contentType === PDF;
}

/** POST /files: the file as the multipart field "file". */
export function uploadFile(api: ApiClient, file: File): Promise<FileLink> {
  const form = new FormData();
  form.append('file', file);
  return data(api.POST('/api/v1/files', { body: {}, bodySerializer: () => form }));
}

/** Uploads files one after another, in their order; `progress` hears how many are done out of how many. */
export async function uploadFiles(
  api: ApiClient,
  files: readonly File[],
  progress?: (done: number, total: number) => void,
): Promise<FileLink[]> {
  const links: FileLink[] = [];
  for (const file of files) {
    progress?.(links.length, files.length);
    links.push(await uploadFile(api, file));
  }
  progress?.(links.length, files.length);
  return links;
}

// Download links live 15 minutes, and every answer brings fresh ones. To the browser a new link is a new picture, so
// Today, read again every 30 seconds, would download every pet's photo again each time. A file keeps the link it was
// first shown with while that link has more than a minute left, as the phone app keeps pictures by file id.
const shown = new Map<string, { url: string; expiresAt: number }>();
const MARGIN_MS = 60_000;

/** The address to show a file at: its small version for avatars and tiles (`thumbnail`), else the full one. */
export function fileUrl(file: FileLink, thumbnail: boolean, now = Date.now()): string {
  const key = `${file.id}:${thumbnail ? 'small' : 'full'}`;
  const known = shown.get(key);
  if (known && known.expiresAt - MARGIN_MS > now) return known.url;
  const url = (thumbnail ? file.thumbnailUrl : null) ?? file.url;
  shown.set(key, { url, expiresAt: Date.parse(file.expiresAt) });
  return url;
}

/** Whether the link of `file` has a minute or more left: a PDF opened with it in a new tab will load. */
export function linkLives(file: FileLink, now = Date.now()): boolean {
  return Date.parse(file.expiresAt) - MARGIN_MS > now;
}

/**
 * A fresh link to a file (GET /files/{id}/url), which replaces the one shown: for a picture whose link has expired
 * while the page stood open, or a PDF to open.
 */
export async function freshFileLink(api: ApiClient, id: string): Promise<FileLink> {
  const link = await data(api.GET('/api/v1/files/{id}/url', { params: { path: { id } } }));
  const expiresAt = Date.parse(link.expiresAt);
  shown.set(`${id}:full`, { url: link.url, expiresAt });
  shown.set(`${id}:small`, { url: link.thumbnailUrl ?? link.url, expiresAt });
  return link;
}
