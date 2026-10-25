// Photos for AI to read, picked or dropped: the server's file preparation takes JPEG, PNG and WebP (by their first
// bytes) and turns them into JPEG; AI reads photos only, so a PDF is refused here with a word to take a screenshot or a
// photo of the page instead. iPhone photos come as HEIC, which the server can't open: a browser that can show one
// (Safari) turns it into a JPEG here before it goes up; another says how to send it instead.
import { photoProblem } from '../../api/files';
import type { Messages } from '../../i18n/en';

const HEIC_TYPES = ['image/heic', 'image/heif', 'image/heic-sequence', 'image/heif-sequence'];
const HEIC_NAME = /\.(heic|heif)$/i;
/** A HEIC photo turned into a JPEG is made no larger than this on its long side: the server keeps 2048 at most. */
const MAX_SIDE = 2048;

export function isHeic(file: File): boolean {
  return HEIC_TYPES.includes(file.type.toLowerCase()) || HEIC_NAME.test(file.name);
}

export function isPdfFile(file: File): boolean {
  return file.type === 'application/pdf' || /\.pdf$/i.test(file.name);
}

/** What a picker offers for photos AI reads: HEIC among them, turned into JPEG before it goes up. */
export const AI_PHOTO_ACCEPT = 'image/jpeg,image/png,image/webp,image/heic,image/heif,.heic,.heif';

/**
 * A HEIC photo as a JPEG, drawn by the browser the way up the camera held it (its EXIF orientation); null when this
 * browser can't open HEIC. The decoded picture's memory is given back whatever happens.
 */
export async function heicToJpeg(file: File): Promise<File | null> {
  if (typeof createImageBitmap !== 'function') return null;
  let bitmap: ImageBitmap | null = null;
  try {
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
    const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    const context = canvas.getContext('2d');
    if (!context) return null;
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    bitmap.close();
    bitmap = null;
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.9));
    if (!blob) return null;
    return new File([blob], file.name.replace(HEIC_NAME, '') + '.jpg', { type: 'image/jpeg' });
  } catch {
    return null;
  } finally {
    bitmap?.close();
  }
}

/**
 * The files AI can read, in their order, and why the others can't: a PDF (a screenshot of it can), a HEIC photo this
 * browser can't open, another type, more than 15 MB.
 */
export async function preparePhotos(t: Messages, files: readonly File[]): Promise<{ files: File[]; refused: string[] }> {
  const accepted: File[] = [];
  const refused: string[] = [];
  for (const file of files) {
    if (isPdfFile(file)) {
      refused.push(t.aiPdfRefused(file.name));
      continue;
    }
    let photo: File | null = file;
    if (isHeic(file)) {
      photo = await heicToJpeg(file);
      if (!photo) {
        refused.push(t.aiHeicRefused(file.name));
        continue;
      }
    }
    const problem = photoProblem(photo);
    if (problem === 'errorFileTooLarge') refused.push(t.fileRefused(file.name, t.errorFileTooLarge));
    else if (problem) refused.push(t.aiPhotoUnsupported(file.name));
    else accepted.push(photo);
  }
  return { files: accepted, refused };
}
