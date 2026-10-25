import { describe, expect, it } from 'vitest';
import type { AdminPlan } from '../api/types';
import { aiPhotosUsage, isPurchased, planFormErrors, planSourceText, planState, serverCheckText } from './plan';

function plan(change: Partial<AdminPlan> = {}): AdminPlan {
  return {
    plan: 'Free',
    source: null,
    expiresAt: null,
    note: null,
    changedAt: null,
    changedBy: null,
    aiPhotosUsed: 0,
    aiPhotosPerMonth: 20,
    ...change,
  };
}

describe('planState', () => {
  it('tells Premium with an end, with no end, an ended one and plain Free apart', () => {
    expect(planState(plan({ plan: 'Premium', source: 'Manual', expiresAt: '2026-12-31T20:59:59.999Z' }))).toEqual({
      kind: 'premium',
      until: '2026-12-31T20:59:59.999Z',
    });
    expect(planState(plan({ plan: 'Premium', source: 'Manual' }))).toEqual({ kind: 'premium', until: null });
    expect(planState(plan({ source: 'Manual', expiresAt: '2026-10-01T10:00:00Z' }))).toEqual({
      kind: 'ended',
      endedAt: '2026-10-01T10:00:00Z',
    });
    expect(planState(plan())).toEqual({ kind: 'free' });
    // Taken back by hand: Free, no end.
    expect(planState(plan({ source: 'Manual', changedAt: '2026-10-05T10:00:00Z' }))).toEqual({ kind: 'free' });
  });
});

describe('aiPhotosUsage', () => {
  it('turns yellow near the limit and over it', () => {
    expect(aiPhotosUsage(plan({ aiPhotosUsed: 7, aiPhotosPerMonth: 300 }))).toMatchObject({ tone: 'ok', hint: 'осталось 293 фото' });
    expect(aiPhotosUsage(plan({ aiPhotosUsed: 15, aiPhotosPerMonth: 20 }))).toMatchObject({ tone: 'ok', share: 0.75 });
    expect(aiPhotosUsage(plan({ aiPhotosUsed: 16, aiPhotosPerMonth: 20 }))).toMatchObject({
      tone: 'warning',
      hint: 'почти исчерпан: осталось 4 фото',
    });
    expect(aiPhotosUsage(plan({ aiPhotosUsed: 20, aiPhotosPerMonth: 20 }))).toMatchObject({ tone: 'warning', hint: 'лимит исчерпан' });
    expect(aiPhotosUsage(plan({ aiPhotosUsed: 26, aiPhotosPerMonth: 20 }))).toMatchObject({
      tone: 'warning',
      share: 1.3,
      hint: 'лимит превышен на 6 фото',
    });
    expect(aiPhotosUsage(plan({ aiPhotosUsed: 3, aiPhotosPerMonth: 0 }))).toMatchObject({ share: null, tone: 'ok' });
  });
});

describe('who changed it', () => {
  it('names the source', () => {
    expect(planSourceText('Manual')).toBe('вручную');
    expect(planSourceText('Paddle')).toBe('покупка на сайте (Paddle)');
    expect(planSourceText('AppStore')).toBe('покупка в App Store');
    expect(planSourceText(null)).toBeNull();
    expect(isPurchased('Paddle')).toBe(true);
    expect(isPurchased('Manual')).toBe(false);
  });
});

describe('the server checks, in Russian and in their place', () => {
  it('translates the known checks and keeps an unknown one', () => {
    expect(serverCheckText('Premium can only end in the future.')).toBe('Дата окончания должна быть в будущем.');
    expect(serverCheckText('At most 200 characters.')).toBe('Заметка — не длиннее 200 знаков.');
    expect(serverCheckText('Something new.')).toBe('Something new.');
  });

  it('puts each check next to its field', () => {
    expect(
      planFormErrors({
        expiresAt: ['Premium can only end in the future.'],
        note: ['At most 200 characters.'],
        plan: ['Free or Premium.'],
      }),
    ).toEqual({
      expiresAt: 'Дата окончания должна быть в будущем.',
      note: 'Заметка — не длиннее 200 знаков.',
      form: 'Тариф может быть только Free или Premium.',
    });
    // A request the server couldn't read names the field "$.expiresAt".
    expect(planFormErrors({ '$.expiresAt': ['The JSON value could not be converted.'] })).toEqual({
      expiresAt: 'The JSON value could not be converted.',
    });
  });
});
