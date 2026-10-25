// "Download my data" (GET /me/export): a ZIP of everything of the person's, which the server writes as it reads it,
// so no total is known beforehand. It comes as a stream; `progress` hears the bytes so far. The file is named as the
// server suggests (Content-Disposition), when that is a plain name. At most 5 an hour: then a 429 with Retry-After.
import { ApiError, type ApiClient } from './client';

export interface ExportFile {
  blob: Blob;
  name: string;
}

export async function downloadExport(
  api: ApiClient,
  progress: (bytes: number) => void,
  signal: AbortSignal,
): Promise<ExportFile> {
  const { data: body, response } = await api.GET('/api/v1/me/export', { parseAs: 'stream', signal });
  const name = exportFileName(response.headers.get('Content-Disposition'), new Date());
  const chunks: Uint8Array<ArrayBuffer>[] = [];
  let received = 0;
  if (body) {
    const reader = body.getReader();
    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value as Uint8Array<ArrayBuffer>);
        received += value.byteLength;
        progress(received);
      }
    } catch (error) {
      if (signal.aborted) throw error;
      // The connection broke off midway: to the person, no answer.
      throw new ApiError(0, 'The download broke off.');
    }
  }
  return { blob: new Blob(chunks, { type: 'application/zip' }), name };
}

/**
 * The file's name: the server's (`attachment; filename=collarbell-export-2026-10-07.zip; filename*=UTF-8''…`) when
 * it is a plain one (letters, digits, dots and dashes), else the same with today's date.
 */
export function exportFileName(contentDisposition: string | null, today: Date): string {
  const suggested = /filename\*?=(?:UTF-8'')?"?([^";]+)/i.exec(contentDisposition ?? '')?.[1]?.trim();
  if (suggested && /^\w[\w.-]*\.zip$/.test(suggested)) return suggested;
  const pad = (value: number) => String(value).padStart(2, '0');
  return `collarbell-export-${today.getFullYear()}-${pad(today.getMonth() + 1)}-${pad(today.getDate())}.zip`;
}

/** Hands a file to the browser to save, as a download under its name. */
export function saveFile(url: string, name: string): void {
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  link.style.display = 'none';
  document.body.append(link);
  link.click();
  link.remove();
}
