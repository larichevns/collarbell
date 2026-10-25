// The refusals of the AI calls in words (the phone app's error_messages.dart and ai_labels.dart): the month's AI
// photos used up (with how many and until when), the day's notes, too many requests a minute (with how long to wait
// when the server says), AI not set up; anything else as for any request.
//
// The API's own refusals carry a problem type of its own (ProblemTypes). The others carry whatever ASP.NET fills in for
// the status (a link to RFC 9110's section on 409, say) or none: both count as "no type of the API's".
import type { I18n } from '../i18n/i18n';
import { localDateOf } from '../lib/dates';
import { ApiError, ProblemTypes } from './client';
import { errorMessage } from './errors';

/** What the server says with a 409 ai-limit: whose photos, the plan, the limit, how many are used, when it resets. */
export interface AiLimit {
  /** The group's photos for its plan, or the person's in all their Free groups. */
  scope: 'household' | 'person';
  /** "Free" or "Premium", as the server names the plan. */
  plan: string;
  limit: number;
  used: number;
  /** The photos the refused request had. */
  requested: number | null;
  /** When the count starts again (a moment). */
  resetsAt: string;
}

const membersOf = (error: ApiError): Record<string, unknown> =>
  error.body && typeof error.body === 'object' ? (error.body as Record<string, unknown>) : {};

export function isAiLimit(error: unknown): boolean {
  return error instanceof ApiError && error.type === ProblemTypes.aiLimit;
}

/** The limit `error` ran into; null when it is no AI limit, or the server didn't say all of it. */
export function aiLimitOf(error: unknown): AiLimit | null {
  if (!(error instanceof ApiError) || error.type !== ProblemTypes.aiLimit) return null;
  const { plan, limit, used, requested, resetsAt, scope } = membersOf(error);
  if (typeof plan !== 'string' || typeof limit !== 'number' || typeof used !== 'number') return null;
  if (typeof resetsAt !== 'string' || Number.isNaN(Date.parse(resetsAt))) return null;
  return {
    // An answer without one is about the group, as before there were two.
    scope: scope === 'person' ? 'person' : 'household',
    plan,
    limit,
    used,
    requested: typeof requested === 'number' ? requested : null,
    resetsAt,
  };
}

const OWN_TYPES: ReadonlySet<string> = new Set(Object.values(ProblemTypes));

/** A refusal without a problem type of the API's own: none, or the generic one ASP.NET fills in for its status. */
function plain(error: ApiError): boolean {
  return error.type === null || !OWN_TYPES.has(error.type);
}

/** 409 of an AI call with no type of the API's own (not the month's photos): AI isn't set up on the server (any more). */
export function isAiNotSetUp(error: unknown): boolean {
  return error instanceof ApiError && error.status === 409 && plain(error);
}

/** AI has read the day's notes of the person: how many it reads a day (the refusal's limit), else null. */
export function noteLimitOf(error: unknown): number | null {
  if (!(error instanceof ApiError) || error.type !== ProblemTypes.textLimit) return null;
  const { limit } = membersOf(error);
  return typeof limit === 'number' && limit >= 1 ? Math.floor(limit) : 30;
}

/**
 * A refused AI call in words: the month's photos (used up, with the day the count starts again; or fewer left than
 * sent), too many requests a minute (with the seconds to wait when the server said), else as any request.
 */
export function aiErrorMessage(i18n: I18n, error: unknown): string {
  const { t } = i18n;
  if (isAiLimit(error)) {
    const limit = aiLimitOf(error);
    if (!limit) return t.errorAiLimit;
    const plan = limit.plan === 'Premium' || limit.plan === 'Free' ? t.planKind[limit.plan] : limit.plan;
    const left = Math.max(0, limit.limit - limit.used);
    const date = i18n.date(localDateOf(limit.resetsAt));
    if (limit.scope === 'person') {
      return left > 0
        ? t.errorAiLimitPersonNotEnough(left, limit.limit, plan)
        : t.errorAiLimitPersonUsedUp(limit.used, limit.limit, plan, date);
    }
    return left > 0 ? t.errorAiLimitNotEnough(left, limit.limit) : t.errorAiLimitUsedUp(limit.used, limit.limit, plan, date);
  }
  // Too many requests a minute: any 429 but the day's notes.
  if (error instanceof ApiError && error.status === 429 && plain(error)) {
    const wait = error.retryAfter;
    if (wait !== null && wait > 0 && wait < 60) return t.errorTooManyRequestsIn(Math.ceil(wait));
  }
  return errorMessage(t, error);
}
