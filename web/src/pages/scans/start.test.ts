// A scan or note that didn't start, in words, and what can be done about it (start.ts): AI not set up, as the API
// says it (a 409 with the generic type ASP.NET fills in, or none), apart from the month's AI photos (a 409 of its own
// type); more photos than a scan takes, said without "Try again"; uploads refused, uploaded anew; too many requests a
// minute, whatever generic type the 429 carries.
import { describe, expect, it } from 'vitest';
import { ApiError, ProblemTypes } from '../../api/client';
import type { FileLink } from '../../api/types';
import { en } from '../../i18n/en';
import type { I18n } from '../../i18n/i18n';
import { newStart, startFailure } from './start';

const i18n = { lang: 'en', t: en, date: (iso: string) => iso, number: String } as unknown as I18n;
const photos = (count: number) =>
  Array.from({ length: count }, (_, index) => new File([new Uint8Array(10)], `page-${index}.jpg`, { type: 'image/jpeg' }));
const scanOf = (count: number) => newStart({ source: 'PassportPages', files: photos(count) });
const link = (id: string): FileLink => ({
  id,
  contentType: 'image/jpeg',
  sizeBytes: 10,
  width: null,
  height: null,
  url: `https://files.example/${id}`,
  thumbnailUrl: null,
  expiresAt: '2026-10-07T12:00:00Z',
});
const RFC_400 = 'https://tools.ietf.org/html/rfc9110#section-15.5.1';
const RFC_409 = 'https://tools.ietf.org/html/rfc9110#section-15.5.10';

describe('a start refused', () => {
  it("AI isn't set up: a 409 with ASP.NET's generic type, or with none; said so, with nothing more to try", () => {
    for (const type of [RFC_409, null]) {
      expect(startFailure(i18n, new ApiError(409, "AI isn't set up.", { type }), scanOf(1))).toMatchObject({
        message: en.scanErrorNotConfigured,
        dead: true,
        notSetUp: true,
      });
    }
    const note = newStart({ source: 'Text', text: 'Weighs 4 kg' });
    expect(startFailure(i18n, new ApiError(409, "AI isn't set up.", { type: RFC_409 }), note)).toMatchObject({
      message: en.noteErrorNotConfigured,
      notSetUp: true,
    });
  });

  it('the month\'s AI photos are a 409 of their own type: "not set up" it is not', () => {
    const limit = new ApiError(409, 'Not enough AI photos left this month.', { type: ProblemTypes.aiLimit });
    expect(startFailure(i18n, limit, scanOf(2))).toMatchObject({ aiLimit: true, notSetUp: false, dead: true });
  });

  it('more photos than a scan takes (a 400 on their count): no "Try again", the photos are changed instead', () => {
    const count = new ApiError(400, 'One or more validation errors occurred.', {
      type: RFC_400,
      fields: { fileIds: ['Add 1 to 10 photos.'] },
    });
    const start = scanOf(11);
    expect(startFailure(i18n, count, start)).toMatchObject({ message: en.aiPhotoCountRefused(10), dead: true });
    // Read again from a failed scan of more photos than a scan takes now: the same.
    const stored = newStart({ source: 'PassportPages', stored: Array.from({ length: 11 }, (_, index) => link(`file-${index}`)) });
    expect(startFailure(i18n, count, stored)).toMatchObject({ message: en.aiPhotoCountRefused(10), dead: true });
  });

  it('uploads refused (gone, or used elsewhere): "Try again" uploads them anew', () => {
    const start = scanOf(2);
    start.uploaded = [link('a')];
    const refused = new ApiError(400, 'One or more validation errors occurred.', {
      type: RFC_400,
      fields: { fileIds: ['A file is used elsewhere.'] },
    });
    expect(startFailure(i18n, refused, start)).toMatchObject({ message: en.scanPhotosRefused, dead: false });
    expect(start.uploaded).toEqual([]);
  });

  it('too many requests a minute, whatever generic type the 429 carries: how long to wait, and "Try again"', () => {
    for (const type of ['https://tools.ietf.org/html/rfc6585#section-4', null]) {
      const tooMany = new ApiError(429, 'Too Many Requests', { type, retryAfter: 20 });
      expect(startFailure(i18n, tooMany, scanOf(1))).toMatchObject({
        message: en.errorTooManyRequestsIn(20),
        dead: false,
      });
    }
    // The day's notes are a 429 of their own type.
    const notes = new ApiError(429, 'AI has read enough of your notes for today.', {
      type: ProblemTypes.textLimit,
      body: { limit: 30 },
    });
    expect(startFailure(i18n, notes, newStart({ source: 'Text', text: 'Weighs 4 kg' }))).toMatchObject({
      message: en.noteLimitReached(30),
      dead: true,
    });
  });
});
