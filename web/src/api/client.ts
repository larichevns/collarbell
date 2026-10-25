// The API client: openapi-fetch over the paths of the contract (schema.d.ts, generated from contracts/openapi.json),
// on this page's address under /api/v1. Every call carries the signed-in person's Firebase ID token and names the
// household it is about in X-Household (the server's CurrentUserAccessor.HouseholdHeader), and this browser tab's id
// in X-Client: a change the tab makes comes back to it from the live updates with that id, and it skips it (it shows
// the change already). forHousehold(id) gives the
// client of one household: a page, a dialog or a form keeps the client it was opened with, so its changes go to that
// household even if the person switched meanwhile (there they fail instead of landing in the other one).
//
// A call that fails throws ApiError (status 0: no answer at all), and every listener hears of it first: the session
// signs out on a 401, the household moves on when the person isn't in it any more, the offline banner shows while the
// server can't be reached. errors.ts turns an ApiError into words.
import createClient, { type Client, type Middleware } from 'openapi-fetch';
import { TokenError } from '../auth/auth';
import type { paths } from './schema';

const HOUSEHOLD_HEADER = 'X-Household';
/** The server's LiveChanges.ClientHeader. */
const CLIENT_HEADER = 'X-Client';

/** The problem types the app tells apart (the server's problem URNs). */
export const ProblemTypes = {
  /** 403: the request named a household the person isn't in any more. */
  notAHouseholdMember: 'urn:collarbell:problem:not-a-household-member',
  /** 403: the person's role in the household can't do this. */
  roleForbidden: 'urn:collarbell:problem:role-forbidden',
  /** 401: the account was deleted (on a phone); its sign-in token still works for up to an hour. */
  accountDeleted: 'urn:collarbell:problem:account-deleted',
  /** 409: the household would be left without an owner (the last one leaving or stepping down). */
  lastOwner: 'urn:collarbell:problem:last-owner',
  /** 409: joining a household the person is in already. */
  alreadyAMember: 'urn:collarbell:problem:already-a-member',
  /** 409: in the most households one person can be in (20). */
  householdLimit: 'urn:collarbell:problem:household-limit',
  /** 409: the most open invites of one household (20). */
  inviteLimit: 'urn:collarbell:problem:invite-limit',
  /** 409: only an empty household of one person can be deleted. */
  householdNotEmpty: 'urn:collarbell:problem:household-not-empty',
  /**
   * 409: the month's AI photos are used up, or fewer are left than the request has (the group's for its plan, or the
   * person's in all their Free groups). Other 409s of the AI calls have no type of the API's (ASP.NET fills in RFC
   * 9110's): AI isn't set up.
   */
  aiLimit: 'urn:collarbell:problem:ai-limit',
  /** 429: AI has read as many of the person's notes as it does in a day. Other 429s: too many requests a minute. */
  textLimit: 'urn:collarbell:problem:text-limit',
  /** 403: deleting the account needs the password typed in the last 5 minutes. */
  recentSignInRequired: 'urn:collarbell:problem:recent-sign-in-required',
  /** 409: nothing was deleted: a household's fate isn't the one the person was shown any more. */
  deletionPlanChanged: 'urn:collarbell:problem:deletion-plan-changed',
} as const;

interface ApiErrorDetails {
  type?: string | null;
  fields?: Record<string, string[]>;
  traceId?: string | null;
  body?: unknown;
  household?: string | null;
  retryAfter?: number | null;
}

/** The status of a call that wasn't sent: the sign-in couldn't give a token this time (a hiccup of Firebase). */
export const NOT_SENT = -1;

/** A call that failed: an answer that isn't 2xx, or none at all (status 0), or not sent (NOT_SENT). */
export class ApiError extends Error {
  /** The HTTP status; 0 when no answer came (no network, the server or its proxy down); NOT_SENT when not sent. */
  readonly status: number;
  /** The problem type the server named (ProblemTypes), if any. */
  readonly type: string | null;
  /** A 400's failed checks by field ("name", "identifiers[0].code"), in the server's own (English) words. */
  readonly fields: Record<string, string[]>;
  /** The server's trace id: support finds the request in the logs by it. */
  readonly traceId: string | null;
  /** The answer as JSON, e.g. a 409's "who marked this feeding first". */
  readonly body: unknown;
  /** The household the call named. */
  readonly household: string | null;
  /** A 429's wait before the next try, in seconds (the Retry-After header), when the server said. */
  readonly retryAfter: number | null;
  /** The sign-in the call started under (ApiOptions.epoch): a 401 of an earlier sign-in says nothing of this one. */
  epoch: number | null = null;

  constructor(status: number, message: string, details: ApiErrorDetails = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.type = details.type ?? null;
    this.fields = details.fields ?? {};
    this.traceId = details.traceId ?? null;
    this.body = details.body;
    this.household = details.household ?? null;
    this.retryAfter = details.retryAfter ?? null;
  }
}

export type ApiClient = Client<paths>;

export type ApiEvent = { kind: 'answer' } | { kind: 'failure'; error: ApiError };

export interface Api {
  /** The client whose calls name `household` (null: none; the server then takes the person's first household). */
  forHousehold(household: string | null): ApiClient;
  /** Hears every answer and every failure. Returns "stop". */
  listen(listener: (event: ApiEvent) => void): () => void;
}

export interface ApiOptions {
  /** window.fetch, or the pretend server's in the tests. */
  fetch: typeof fetch;
  /** The signed-in person's ID token (Firebase renews it when needed); null when nobody is signed in. */
  token: () => Promise<string | null>;
  /** Where the API is: this page's address by default. */
  baseUrl?: string;
  /** Which sign-in a call starts under (it grows with every sign-in and sign-out); each failure carries it. */
  epoch?: () => number;
  /** This browser tab's id, sent as X-Client with every call (live/clientId.ts). */
  clientId?: string;
}

export function createApi(options: ApiOptions): Api {
  const listeners = new Set<(event: ApiEvent) => void>();
  const emit = (event: ApiEvent) => listeners.forEach((listener) => listener(event));
  // The sign-in each call started under.
  const epochs = new WeakMap<Request, number>();
  const epochOf = (request: Request) => epochs.get(request) ?? options.epoch?.() ?? 0;
  const fail = (error: ApiError, epoch: number) => {
    error.epoch = epoch;
    emit({ kind: 'failure', error });
    return error;
  };

  const middleware: Middleware = {
    async onRequest({ request }) {
      const household = request.headers.get(HOUSEHOLD_HEADER);
      const epoch = options.epoch?.() ?? 0;
      let token: string | null;
      try {
        token = await options.token();
      } catch (error) {
        throw fail(tokenFailure(error, household), epoch);
      }
      // Nobody signed in: no session to end, so nobody is told (a request that started just before "Sign out").
      if (!token) throw new ApiError(401, 'Not signed in.', { household });
      request.headers.set('Authorization', `Bearer ${token}`);
      request.headers.set('Accept', 'application/json');
      if (options.clientId) request.headers.set(CLIENT_HEADER, options.clientId);
      epochs.set(request, epoch);
      return request;
    },
    async onResponse({ request, response }) {
      const household = request.headers.get(HOUSEHOLD_HEADER);
      if (isProxyError(response)) throw fail(noAnswer(household), epochOf(request));
      emit({ kind: 'answer' });
      if (!response.ok) throw fail(await errorOf(response, household), epochOf(request));
      return undefined;
    },
    onError({ request }) {
      // A cancelled request (the page closed, a newer one replaced it) stays a cancellation: nothing to show.
      if (request.signal.aborted) return undefined;
      return fail(noAnswer(request.headers.get(HOUSEHOLD_HEADER)), epochOf(request));
    },
  };

  const baseUrl = options.baseUrl ?? window.location.origin;
  const clients = new Map<string, ApiClient>();

  return {
    forHousehold(household) {
      const key = household ?? '';
      let client = clients.get(key);
      if (!client) {
        client = createClient<paths>({
          baseUrl,
          fetch: options.fetch,
          headers: household ? { [HOUSEHOLD_HEADER]: household } : {},
        });
        client.use(middleware);
        clients.set(key, client);
      }
      return client;
    },
    listen(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
  };
}

/** What a call answered. Its failures were thrown as ApiError, so the answer is all there is. */
export async function data<T>(call: Promise<{ data?: T }>): Promise<T> {
  const { data } = await call;
  return data as T;
}

function noAnswer(household: string | null): ApiError {
  return new ApiError(0, 'No answer from the server.', { household });
}

/**
 * No token, no call: the internet is gone (the token couldn't be renewed), the sign-in is, or Firebase failed for a
 * moment (then only this call fails: not sent, and the sign-in stays).
 */
function tokenFailure(error: unknown, household: string | null): ApiError {
  const reason = error instanceof TokenError ? error.reason : 'expired';
  if (reason === 'offline') return noAnswer(household);
  if (reason === 'failed') return new ApiError(NOT_SENT, 'The sign-in gave no token this time.', { household });
  return new ApiError(401, 'The sign-in is no longer valid.', {
    type: reason === 'gone' ? ProblemTypes.accountDeleted : null,
    household,
  });
}

/**
 * 502, 503 or 504 without a problem of the server's: the proxy (nginx) answering for an API that is down, e.g. during
 * a deploy. To the person that is the same as no answer.
 */
function isProxyError(response: Response): boolean {
  const json = (response.headers.get('Content-Type') ?? '').includes('json');
  return !json && (response.status === 502 || response.status === 503 || response.status === 504);
}

/** The server's problem details (RFC 9457) of a failed answer; not JSON: the status says enough. */
async function errorOf(response: Response, household: string | null): Promise<ApiError> {
  let body: unknown;
  try {
    const raw = await response.text();
    body = raw ? JSON.parse(raw) : undefined;
  } catch {
    // Not JSON.
  }
  const problem = (body && typeof body === 'object' ? body : {}) as Record<string, unknown>;
  const text = (key: string) => {
    const value = problem[key];
    return typeof value === 'string' && value ? value : null;
  };
  const fields: Record<string, string[]> = {};
  const errors = problem.errors;
  if (errors && typeof errors === 'object') {
    for (const [field, texts] of Object.entries(errors)) {
      if (Array.isArray(texts)) fields[field] = texts.filter((item): item is string => typeof item === 'string');
    }
  }
  return new ApiError(response.status, text('detail') ?? text('title') ?? `HTTP ${response.status}`, {
    type: text('type'),
    fields,
    traceId: text('traceId'),
    body,
    household,
    retryAfter: retryAfterOf(response.headers.get('Retry-After')),
  });
}

/** Retry-After in seconds: a number of them, or a date (HTTP's two ways); null when there is none. */
function retryAfterOf(header: string | null): number | null {
  if (!header) return null;
  const seconds = Number(header);
  if (Number.isFinite(seconds)) return Math.max(0, seconds);
  const at = Date.parse(header);
  return Number.isNaN(at) ? null : Math.max(0, Math.ceil((at - Date.now()) / 1000));
}
