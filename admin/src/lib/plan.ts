// A household's plan in words, apart from how it looks (the card: pages/PlanCard.tsx): which state it is in, how full
// the month's AI photos are, who changed it last, and the server's checks of a change in Russian.
import type { AdminPlan, PlanSource } from '../api/types';

/** The longest note of a plan change (backend: HouseholdPlan.MaxNoteLength). */
export const PLAN_NOTE_MAX = 200;

export type PlanState =
  /** Premium works now; until: its end, or null for no end. */
  | { kind: 'premium'; until: string | null }
  /** Free after a given Premium ran out: the server keeps the end that has passed. */
  | { kind: 'ended'; endedAt: string }
  /** Free: never changed, or taken back. */
  | { kind: 'free' };

export function planState(plan: AdminPlan): PlanState {
  if (plan.plan === 'Premium') return { kind: 'premium', until: plan.expiresAt };
  // Taking Premium back clears the end, so a Free plan with an end is one that ran out.
  if (plan.expiresAt !== null) return { kind: 'ended', endedAt: plan.expiresAt };
  return { kind: 'free' };
}

/** From this share of the month's AI photos on, the bar turns yellow and the hint becomes a yellow pill. */
export const AI_PHOTOS_NEAR_LIMIT = 0.8;

export interface AiPhotosUsage {
  /** used / limit, for the bar; null when there is no limit to compare with. */
  share: number | null;
  tone: 'ok' | 'warning';
  /** What the numbers mean: «осталось 13 фото», «лимит исчерпан». */
  hint: string;
}

export function aiPhotosUsage({ aiPhotosUsed: used, aiPhotosPerMonth: limit }: AdminPlan): AiPhotosUsage {
  if (limit <= 0) return { share: null, tone: 'ok', hint: 'лимита нет' };
  const share = used / limit;
  if (used > limit) return { share, tone: 'warning', hint: `лимит превышен на ${used - limit} фото` };
  if (used === limit) return { share, tone: 'warning', hint: 'лимит исчерпан' };
  if (share >= AI_PHOTOS_NEAR_LIMIT) return { share, tone: 'warning', hint: `почти исчерпан: осталось ${limit - used} фото` };
  return { share, tone: 'ok', hint: `осталось ${limit - used} фото` };
}

/** How the last change came about, for «Изменил …»: by hand in the admin, or a purchase (later). */
export function planSourceText(source: PlanSource | null): string | null {
  switch (source) {
    case 'Manual':
      return 'вручную';
    case 'Paddle':
      return 'покупка на сайте (Paddle)';
    case 'AppStore':
      return 'покупка в App Store';
    default:
      return null;
  }
}

/** A purchase, not the admin, set the plan: changing it by hand replaces what was bought. */
export function isPurchased(source: PlanSource | null): boolean {
  return source === 'Paddle' || source === 'AppStore';
}

/** The server's checks of PUT …/plan (backend: AdminEndpoints.SetPlan) in Russian; an unknown one as it is. */
const SERVER_CHECKS: Record<string, string> = {
  'Premium can only end in the future.': 'Дата окончания должна быть в будущем.',
  'At most 200 characters.': 'Заметка — не длиннее 200 знаков.',
  'Free or Premium.': 'Тариф может быть только Free или Premium.',
};

export function serverCheckText(message: string): string {
  return SERVER_CHECKS[message] ?? message;
}

export type PlanFormField = 'expiresAt' | 'note' | 'form';

/**
 * Where a failed check belongs in the form. The server names the fields "plan", "expiresAt", "note"; a request it
 * couldn't read at all names them like "$.expiresAt". Anything else goes above the buttons.
 */
export function planFormField(field: string): PlanFormField {
  const name = field.toLowerCase();
  if (name.includes('expiresat')) return 'expiresAt';
  if (name.includes('note')) return 'note';
  return 'form';
}

/** The failed checks of a 400, in Russian, by the place in the form. */
export function planFormErrors(fields: Record<string, string[]>): Partial<Record<PlanFormField, string>> {
  const errors: Partial<Record<PlanFormField, string>> = {};
  for (const [field, messages] of Object.entries(fields)) {
    const place = planFormField(field);
    const text = messages.map(serverCheckText).join(' ');
    if (text) errors[place] = errors[place] ? `${errors[place]} ${text}` : text;
  }
  return errors;
}
