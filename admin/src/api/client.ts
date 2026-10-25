// The admin API client: /api/admin/… on the same address, with the signed-in person's Firebase ID token. Reads are
// GET; changing a household's plan is a PUT with a JSON body. Every call: Authorization: Bearer <token>. A 401 or 403
// is also told to the session (onAuthError), which then shows the sign-in form or "no access"; the page that asked gets
// an ApiError either way.
import type {
  AdminMe,
  AdminPlan,
  HouseholdDetail,
  Overview,
  PlanRequest,
  Problem,
  TimelineEvent,
  UserDetail,
  UserRow,
} from './types';

/** How many people the search shows, and how many визор lines one page brings. */
export const USERS_LIMIT = 50;
export const TIMELINE_LIMIT = 200;

/** An answer that isn't 2xx; status 0: no answer at all (no network, the server is down). */
export class ApiError extends Error {
  readonly status: number;
  /** A 400's checks that failed, by field ("expiresAt", "note"): the server's own words (ASP.NET validation problem). */
  readonly fields: Record<string, string[]>;

  constructor(status: number, message: string, fields: Record<string, string[]> = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.fields = fields;
  }
}

export interface AdminApi {
  me(signal?: AbortSignal): Promise<AdminMe>;
  overview(signal?: AbortSignal): Promise<Overview>;
  /** People whose e-mail or name contains the query; an empty query: the newest. */
  users(query: string, signal?: AbortSignal): Promise<UserRow[]>;
  user(id: string, signal?: AbortSignal): Promise<UserDetail>;
  /** The визор, newest first; before: the `at` of the last line already shown (passed back as the server wrote it). */
  timeline(id: string, before: string | null, signal?: AbortSignal): Promise<TimelineEvent[]>;
  household(id: string, signal?: AbortSignal): Promise<HouseholdDetail>;
  /** Give Premium (until a moment, or with no end) or take it back; answers with the plan as it is now. */
  setPlan(householdId: string, request: PlanRequest, signal?: AbortSignal): Promise<AdminPlan>;
  problems(hours: number, signal?: AbortSignal): Promise<Problem[]>;
}

export interface ApiOptions {
  /** window.fetch, or the test data's fetch in mock mode and in tests. */
  fetch: typeof fetch;
  /** The signed-in person's ID token (Firebase renews it when needed); null when nobody is signed in. */
  token: () => Promise<string | null>;
  /** Called on 401 (the sign-in is no longer valid) and 403 (not an admin). */
  onAuthError?: (status: 401 | 403) => void;
}

type Params = Record<string, string | number | null | undefined>;

export function createAdminApi(options: ApiOptions): AdminApi {
  async function call<T>(
    method: 'GET' | 'PUT',
    path: string,
    { params = {}, body, signal }: { params?: Params; body?: unknown; signal?: AbortSignal } = {},
  ): Promise<T> {
    const token = await options.token();
    if (!token) {
      options.onAuthError?.(401);
      throw new ApiError(401, 'Вход не выполнен.');
    }

    const query = new URLSearchParams();
    for (const [name, value] of Object.entries(params)) {
      if (value !== null && value !== undefined && value !== '') query.set(name, String(value));
    }
    const search = query.toString();
    const url = `/api/admin${path}${search ? `?${search}` : ''}`;
    const headers: Record<string, string> = { Accept: 'application/json', Authorization: `Bearer ${token}` };
    if (body !== undefined) headers['Content-Type'] = 'application/json';

    let response: Response;
    try {
      response = await options.fetch(url, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
        signal,
      });
    } catch (error) {
      // A cancelled request (the page closed, a newer search) stays a cancellation, not an error to show.
      if (signal?.aborted) throw error;
      throw new ApiError(0, 'Нет связи с сервером.');
    }

    if (!response.ok) {
      if (response.status === 401 || response.status === 403) options.onAuthError?.(response.status);
      const problem = await readProblem(response);
      throw new ApiError(response.status, problem.message, problem.fields);
    }
    return (await response.json()) as T;
  }

  const get = <T>(path: string, params: Params, signal?: AbortSignal) => call<T>('GET', path, { params, signal });
  const id = (value: string) => encodeURIComponent(value);

  return {
    me: (signal) => get('/me', {}, signal),
    overview: (signal) => get('/overview', {}, signal),
    users: (query, signal) => get('/users', { query: query.trim(), limit: USERS_LIMIT }, signal),
    user: (userId, signal) => get(`/users/${id(userId)}`, {}, signal),
    timeline: (userId, before, signal) =>
      get(`/users/${id(userId)}/timeline`, { before, limit: TIMELINE_LIMIT }, signal),
    household: (householdId, signal) => get(`/households/${id(householdId)}`, {}, signal),
    setPlan: (householdId, request, signal) =>
      call('PUT', `/households/${id(householdId)}/plan`, { body: request, signal }),
    problems: (hours, signal) => get('/problems', { hours }, signal),
  };
}

/**
 * The server's own words for an error (ASP.NET problem details: detail, title) and, for a validation problem, the
 * failed checks by field ({ errors: { expiresAt: ["…"] } }). Not JSON: the status says enough.
 */
async function readProblem(response: Response): Promise<{ message: string; fields: Record<string, string[]> }> {
  const fields: Record<string, string[]> = {};
  let message = `HTTP ${response.status}`;
  try {
    const body: unknown = await response.json();
    if (body && typeof body === 'object') {
      const { detail, title, errors } = body as { detail?: unknown; title?: unknown; errors?: unknown };
      if (typeof detail === 'string' && detail) message = detail;
      else if (typeof title === 'string' && title) message = title;
      if (errors && typeof errors === 'object') {
        for (const [field, texts] of Object.entries(errors)) {
          if (Array.isArray(texts)) fields[field] = texts.filter((text): text is string => typeof text === 'string');
        }
      }
    }
  } catch {
    // Not JSON.
  }
  return { message, fields };
}

/** What to tell the owner about a failed call, in Russian. */
export function errorText(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status === 0) return 'Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.';
    if (error.status === 401) return 'Вход больше не действует. Войдите снова.';
    if (error.status === 403) return 'Нет доступа: этот аккаунт не админ.';
    if (error.status === 404) return 'Не найдено.';
    if (error.status >= 500) return `Ошибка сервера (${error.status}). Попробуйте ещё раз чуть позже.`;
    return `Сервер ответил ошибкой ${error.status}: ${error.message}`;
  }
  return 'Что-то пошло не так. Попробуйте ещё раз.';
}

export function isNotFound(error: unknown): boolean {
  return error instanceof ApiError && error.status === 404;
}
