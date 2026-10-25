// An iPhone's HEIC photo for AI (photos.ts): drawn by the browser the way up the camera held it, as a JPEG, with the
// decoded picture given back on every way out; a browser that can't draw it refuses it with a word.
import { afterEach, describe, expect, it, vi } from 'vitest';
import { en } from '../../i18n/en';
import { slowHeic, type SlowHeic } from '../../test/heic';
import { heicToJpeg, preparePhotos } from './photos';

const heicFile = (name = 'IMG_0042.HEIC') => new File([new Uint8Array(500)], name, { type: 'image/heic' });
let heic: SlowHeic | null = null;

afterEach(() => {
  heic?.restore();
  heic = null;
});

describe('an iPhone photo made a JPEG', () => {
  it('is opened upright (its EXIF orientation), drawn as a JPEG, and its decoded picture given back', async () => {
    heic = slowHeic();
    const converting = heicToJpeg(heicFile());
    await vi.waitFor(() => expect(heic!.waiting).toBe(1));
    heic.finish();
    const jpeg = await converting;
    expect(jpeg).toMatchObject({ name: 'IMG_0042.jpg', type: 'image/jpeg' });
    expect(heic.opened).toEqual([{ imageOrientation: 'from-image' }]);
    expect(heic.bitmaps.map((bitmap) => bitmap.closed)).toEqual([true]);
  });

  it("a canvas that can't be drawn on: no JPEG, and the decoded picture given back all the same", async () => {
    heic = slowHeic({ drawable: false });
    const converting = heicToJpeg(heicFile());
    await vi.waitFor(() => expect(heic!.waiting).toBe(1));
    heic.finish();
    expect(await converting).toBeNull();
    expect(heic.bitmaps.map((bitmap) => bitmap.closed)).toEqual([true]);
  });

  it('among other photos keeps its place; one this browser can\'t open is said so', async () => {
    heic = slowHeic();
    const preparing = preparePhotos(en, [
      new File([new Uint8Array(10)], 'front.jpg', { type: 'image/jpeg' }),
      heicFile('side.heic'),
    ]);
    await vi.waitFor(() => expect(heic!.waiting).toBe(1));
    heic.finish();
    const prepared = await preparing;
    expect(prepared.files.map((file) => file.name)).toEqual(['front.jpg', 'side.jpg']);
    expect(prepared.refused).toEqual([]);
    heic.restore();
    heic = null;
    // No createImageBitmap at all (jsdom, an old browser): refused with a word.
    const refused = await preparePhotos(en, [heicFile('back.heic')]);
    expect(refused.files).toEqual([]);
    expect(refused.refused).toEqual([en.aiHeicRefused('back.heic')]);
  });
});
