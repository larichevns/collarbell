import { describe, expect, it, vi } from 'vitest';
import { ApiError, createAdminApi, errorText, type ApiOptions } from './client';

function respond(status: number, body: unknown = {}) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

function setup(fetchImpl: ApiOptions['fetch'], token: string | null = 'id-token') {
  const fetch = vi.fn(fetchImpl);
  const onAuthError = vi.fn();
  const api = createAdminApi({ fetch, token: async () => token, onAuthError });
  return { api, fetch, onAuthError };
}

const requestOf = (fetch: ReturnType<typeof vi.fn>, call = 0) => {
  const [url, init] = fetch.mock.calls[call] as [string, RequestInit];
  return { url, method: init.method, body: init.body, headers: new Headers(init.headers), signal: init.signal };
};

describe('createAdminApi', () => {
  it('sends the ID token and asks for JSON', async () => {
    const { api, fetch } = setup(async () => respond(200, { email: 'owner@example.com', displayName: null }));
    await expect(api.me()).resolves.toEqual({ email: 'owner@example.com', displayName: null });
    const { url, headers } = requestOf(fetch);
    expect(url).toBe('/api/admin/me');
    expect(headers.get('Authorization')).toBe('Bearer id-token');
    expect(headers.get('Accept')).toBe('application/json');
  });

  it('builds the addresses of the contract', async () => {
    const { api, fetch } = setup(async () => respond(200, []));
    await api.users('  anna ');
    await api.users('');
    await api.timeline('u 1', null);
    await api.timeline('u1', '2026-10-05T15:04:00.123456+00:00');
    await api.problems(24);
    await api.household('h1');
    expect(fetch.mock.calls.map(([url]) => url)).toEqual([
      '/api/admin/users?query=anna&limit=50',
      '/api/admin/users?limit=50',
      '/api/admin/users/u%201/timeline?limit=200',
      // The moment goes back exactly as the server wrote it.
      '/api/admin/users/u1/timeline?before=2026-10-05T15%3A04%3A00.123456%2B00%3A00&limit=200',
      '/api/admin/problems?hours=24',
      '/api/admin/households/h1',
    ]);
  });

  it('passes the cancel signal on', async () => {
    const { api, fetch } = setup(async () => respond(200, {}));
    const controller = new AbortController();
    await api.overview(controller.signal);
    expect(requestOf(fetch).signal).toBe(controller.signal);
  });

  it('tells the session about 401 and 403', async () => {
    const forbidden = setup(async () => respond(403, { title: 'Admins only.' }));
    await expect(forbidden.api.overview()).rejects.toMatchObject({ status: 403, message: 'Admins only.' });
    expect(forbidden.onAuthError).toHaveBeenCalledWith(403);

    const expired = setup(async () => respond(401));
    await expect(expired.api.overview()).rejects.toBeInstanceOf(ApiError);
    expect(expired.onAuthError).toHaveBeenCalledWith(401);
  });

  it('does not call the server when nobody is signed in', async () => {
    const { api, fetch, onAuthError } = setup(async () => respond(200, {}), null);
    await expect(api.overview()).rejects.toMatchObject({ status: 401 });
    expect(fetch).not.toHaveBeenCalled();
    expect(onAuthError).toHaveBeenCalledWith(401);
  });

  it('reads the server words of an error, else the status', async () => {
    const withDetail = setup(async () => respond(500, { title: 'Server error', detail: 'Database is down' }));
    await expect(withDetail.api.overview()).rejects.toMatchObject({ status: 500, message: 'Database is down' });
    const notJson = setup(async () => new Response('Bad gateway', { status: 502 }));
    await expect(notJson.api.overview()).rejects.toMatchObject({ status: 502, message: 'HTTP 502' });
    const notFound = setup(async () => respond(404));
    await expect(notFound.api.user('nobody')).rejects.toMatchObject({ status: 404 });
    expect(notFound.onAuthError).not.toHaveBeenCalled();
  });

  it('turns a network failure into status 0, but keeps a cancellation a cancellation', async () => {
    const offline = setup(async () => {
      throw new TypeError('Failed to fetch');
    });
    await expect(offline.api.overview()).rejects.toMatchObject({ status: 0 });

    const controller = new AbortController();
    const cancelled = setup(async () => {
      controller.abort();
      throw new DOMException('Aborted', 'AbortError');
    });
    await expect(cancelled.api.overview(controller.signal)).rejects.toMatchObject({ name: 'AbortError' });
  });
});

describe('changing a plan (PUT)', () => {
  const answer = {
    plan: 'Premium',
    source: 'Manual',
    expiresAt: '2026-12-31T20:59:59.999+00:00',
    note: 'тестер',
    changedAt: '2026-10-05T19:31:00+00:00',
    changedBy: 'owner@example.com',
    aiPhotosUsed: 7,
    aiPhotosPerMonth: 300,
  };

  it('sends JSON with the token and reads the plan back', async () => {
    const { api, fetch } = setup(async () => respond(200, answer));
    const request = { plan: 'Premium' as const, expiresAt: '2026-12-31T20:59:59.999Z', note: 'тестер' };
    await expect(api.setPlan('h 1', request)).resolves.toEqual(answer);
    const sent = requestOf(fetch);
    expect(sent.url).toBe('/api/admin/households/h%201/plan');
    expect(sent.method).toBe('PUT');
    expect(sent.headers.get('Content-Type')).toBe('application/json');
    expect(sent.headers.get('Authorization')).toBe('Bearer id-token');
    expect(JSON.parse(String(sent.body))).toEqual(request);
  });

  it('reads are still plain GETs without a body', async () => {
    const { api, fetch } = setup(async () => respond(200, {}));
    await api.household('h1');
    const sent = requestOf(fetch);
    expect(sent.method).toBe('GET');
    expect(sent.body).toBeUndefined();
    expect(sent.headers.get('Content-Type')).toBeNull();
  });

  it('gives back the failed checks of a 400 by field', async () => {
    const { api, onAuthError } = setup(async () =>
      respond(400, {
        title: 'One or more validation errors occurred.',
        status: 400,
        errors: { expiresAt: ['Premium can only end in the future.'], note: ['At most 200 characters.'] },
      }),
    );
    const failure = await api.setPlan('h1', { plan: 'Premium', expiresAt: '2020-01-01T00:00:00Z', note: null }).catch((e) => e);
    expect(failure).toBeInstanceOf(ApiError);
    expect(failure).toMatchObject({
      status: 400,
      message: 'One or more validation errors occurred.',
      fields: { expiresAt: ['Premium can only end in the future.'], note: ['At most 200 characters.'] },
    });
    expect(onAuthError).not.toHaveBeenCalled();
  });

  it('tells the session about 401 and 403 here too', async () => {
    const expired = setup(async () => respond(401));
    await expect(expired.api.setPlan('h1', { plan: 'Free', expiresAt: null, note: null })).rejects.toMatchObject({ status: 401 });
    expect(expired.onAuthError).toHaveBeenCalledWith(401);
    const forbidden = setup(async () => respond(403, { title: 'Admins only.' }));
    await expect(forbidden.api.setPlan('h1', { plan: 'Free', expiresAt: null, note: null })).rejects.toMatchObject({ status: 403 });
    expect(forbidden.onAuthError).toHaveBeenCalledWith(403);
  });
});

describe('errorText', () => {
  it('says what went wrong, in Russian', () => {
    expect(errorText(new ApiError(0, ''))).toMatch(/Нет связи с сервером/);
    expect(errorText(new ApiError(404, ''))).toBe('Не найдено.');
    expect(errorText(new ApiError(503, ''))).toMatch(/Ошибка сервера \(503\)/);
    expect(errorText(new ApiError(400, 'Bad limit'))).toBe('Сервер ответил ошибкой 400: Bad limit');
    expect(errorText(new Error('boom'))).toMatch(/Что-то пошло не так/);
  });
});
