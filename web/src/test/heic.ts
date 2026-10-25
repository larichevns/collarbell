// A browser that opens iPhone's HEIC photos (Safari), slowly: each photo becomes a JPEG only when the test lets it
// (`finish`), as a big photo takes a moment to decode. jsdom has neither createImageBitmap nor a canvas that draws.
import { vi } from 'vitest';

export interface SlowHeic {
  /** The conversions waiting. */
  readonly waiting: number;
  /** Ends the oldest conversion waiting. */
  finish(): void;
  /** The options each photo was opened with. */
  readonly opened: (ImageBitmapOptions | undefined)[];
  /** The decoded pictures, and whether each was given back (closed). */
  readonly bitmaps: { closed: boolean }[];
  restore(): void;
}

export function slowHeic({ drawable = true }: { drawable?: boolean } = {}): SlowHeic {
  const pending: (() => void)[] = [];
  const opened: (ImageBitmapOptions | undefined)[] = [];
  const bitmaps: { closed: boolean }[] = [];
  vi.stubGlobal('createImageBitmap', (_photo: Blob, options?: ImageBitmapOptions) => {
    opened.push(options);
    return new Promise((resolve) =>
      pending.push(() => {
        const bitmap = {
          width: 4032,
          height: 3024,
          closed: false,
          close() {
            bitmap.closed = true;
          },
        };
        bitmaps.push(bitmap);
        resolve(bitmap);
      }),
    );
  });
  const getContext = HTMLCanvasElement.prototype.getContext;
  const toBlob = HTMLCanvasElement.prototype.toBlob;
  HTMLCanvasElement.prototype.getContext = (() => (drawable ? { drawImage() {} } : null)) as never;
  HTMLCanvasElement.prototype.toBlob = function toJpeg(callback: BlobCallback) {
    callback(new Blob([new Uint8Array(500)], { type: 'image/jpeg' }));
  };
  return {
    get waiting() {
      return pending.length;
    },
    finish() {
      pending.shift()?.();
    },
    opened,
    bitmaps,
    restore() {
      HTMLCanvasElement.prototype.getContext = getContext;
      HTMLCanvasElement.prototype.toBlob = toBlob;
      vi.unstubAllGlobals();
    },
  };
}
