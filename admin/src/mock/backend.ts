// A pretend server for the test data: a fetch() that answers /api/admin/… like the real one (JSON, 401 without a
// token, 403 for a non-admin, 404 for an unknown id, 400 with the failed checks by field for a wrong plan change),
// after a short pause so loading states show. The API client (api/client.ts) works with it unchanged, so mock mode
// and the tests go through the same code as the real admin.
import type { PlanRequest } from '../api/types';
import { PLAN_NOTE_MAX } from '../lib/plan';
import { createFixtures, OWNER_EMAIL, type Fixtures } from './fixtures';

export { OWNER_EMAIL };

/** The pretend token is "mock:<e-mail>"; an e-mail with "stranger" in it is not an admin. */
export function mockToken(email: string): string {
  return `mock:${email}`;
}

export interface MockBackendOptions {
  now?: Date;
  /** The time for plans (is a Premium still on, is an end in the future); the real one by default. */
  clock?: () => number;
  /** The pause before every answer, ms (0 in the tests). */
  latencyMs?: number;
  /** The overview with nothing wrong (?mockOverview=calm). */
  calm?: boolean;
}

export interface MockBackend {
  fetch: typeof fetch;
  fixtures: Fixtures;
}

export function createMockBackend({
  now = new Date(),
  clock = () => Date.now(),
  latencyMs = 250,
  calm = false,
}: MockBackendOptions = {}): MockBackend {
  const fixtures = createFixtures(now, clock);

  async function mockFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
    const href = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    const url = new URL(href, 'http://mock.invalid');
    await pause(latencyMs, init?.signal ?? undefined);

    const authorization = new Headers(init?.headers).get('Authorization') ?? '';
    const token = authorization.startsWith('Bearer ') ? authorization.slice('Bearer '.length) : '';
    if (!token.startsWith('mock:')) return json(401, { title: 'Unauthorized' });
    const email = token.slice('mock:'.length);
    if (email.includes('stranger')) return json(403, { title: 'Admins only.' });

    const path = url.pathname;
    const query = url.searchParams;
    const method = (init?.method ?? 'GET').toUpperCase();
    let match: RegExpExecArray | null;

    if ((match = /^\/api\/admin\/households\/([^/]+)\/plan$/.exec(path))) {
      if (method !== 'PUT') return json(405, { title: 'Method Not Allowed' });
      let body: unknown;
      try {
        body = JSON.parse(typeof init?.body === 'string' ? init.body : '');
      } catch {
        return json(400, { title: 'The request body is not JSON.' });
      }
      // Like the server: the checks first, then whether the group exists.
      const checked = checkPlanRequest(body, clock());
      if ('errors' in checked) {
        return json(400, {
          type: 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
          title: 'One or more validation errors occurred.',
          status: 400,
          errors: checked.errors,
        });
      }
      const plan = fixtures.setPlan(decodeURIComponent(match[1]!), checked.request, email);
      return plan ? json(200, plan) : json(404, { title: 'Not Found' });
    }
    if (method !== 'GET') return json(405, { title: 'Method Not Allowed' });

    if (path === '/api/admin/me') {
      return json(200, { email, displayName: email === OWNER_EMAIL ? 'Владелец' : null });
    }
    if (path === '/api/admin/overview') return json(200, fixtures.overview(calm));
    if (path === '/api/admin/users') {
      return json(200, fixtures.users(query.get('query') ?? '', Number(query.get('limit') ?? 50)));
    }
    if ((match = /^\/api\/admin\/users\/([^/]+)\/timeline$/.exec(path))) {
      const lines = fixtures.timeline(decodeURIComponent(match[1]!), query.get('before'), Number(query.get('limit') ?? 200));
      return lines ? json(200, lines) : json(404, { title: 'Not Found' });
    }
    if ((match = /^\/api\/admin\/users\/([^/]+)$/.exec(path))) {
      const user = fixtures.user(decodeURIComponent(match[1]!));
      return user ? json(200, user) : json(404, { title: 'Not Found' });
    }
    if ((match = /^\/api\/admin\/households\/([^/]+)$/.exec(path))) {
      const household = fixtures.household(decodeURIComponent(match[1]!));
      return household ? json(200, household) : json(404, { title: 'Not Found' });
    }
    if (path === '/api/admin/problems') return json(200, fixtures.problems(Number(query.get('hours') ?? 24)));
    return json(404, { title: 'Not Found' });
  }

  return { fetch: mockFetch, fixtures };
}

/**
 * The checks of PUT …/plan, with the server's words (backend: AdminEndpoints.SetPlan): Free or Premium; a Premium's
 * end, when there is one, in the future; the note trimmed (blank: none), at most 200 characters.
 */
export function checkPlanRequest(
  raw: unknown,
  at: number,
): { request: PlanRequest } | { errors: Record<string, string[]> } {
  const body = (raw && typeof raw === 'object' ? raw : {}) as { plan?: unknown; expiresAt?: unknown; note?: unknown };
  const errors: Record<string, string[]> = {};
  const add = (field: string, message: string) => (errors[field] ??= []).push(message);
  const plan = body.plan === 'Free' || body.plan === 'Premium' ? body.plan : null;
  const expiresAt = typeof body.expiresAt === 'string' ? body.expiresAt : null;
  const note = typeof body.note === 'string' && body.note.trim() ? body.note.trim() : null;

  if (plan === null) add('plan', 'Free or Premium.');
  else if (plan === 'Premium' && expiresAt !== null && !(Date.parse(expiresAt) > at)) {
    add('expiresAt', 'Premium can only end in the future.');
  }
  if (note !== null && note.length > PLAN_NOTE_MAX) add('note', `At most ${PLAN_NOTE_MAX} characters.`);

  if (plan === null || Object.keys(errors).length) return { errors };
  return { request: { plan, expiresAt: plan === 'Premium' ? expiresAt : null, note } };
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

function pause(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const abort = () => reject(new DOMException('The request was cancelled.', 'AbortError'));
    if (signal?.aborted) {
      abort();
      return;
    }
    if (ms <= 0) {
      resolve();
      return;
    }
    const timer = setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      clearTimeout(timer);
      abort();
    };
    signal?.addEventListener('abort', onAbort, { once: true });
  });
}
