import { describe, expect, it, vi } from 'vitest';
import { TokenError } from '../auth/auth';
import { en } from '../i18n/en';
import { ApiError, createApi, data, ProblemTypes, type ApiEvent } from './client';
import { errorMessage } from './errors';

const BASE = 'http://localhost:3000';

function respond(status: number, body?: unknown, contentType = 'application/problem+json') {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: body === undefined ? {} : { 'Content-Type': contentType },
  });
}

function setup(
  answer: (request: Request) => Response | Promise<Response>,
  token: () => Promise<string | null> = async () => 'id-token',
) {
  const fetch = vi.fn(async (input: RequestInfo | URL) => answer(input as Request));
  const api = createApi({ fetch, token, baseUrl: BASE });
  const events: ApiEvent[] = [];
  api.listen((event) => events.push(event));
  return { api, fetch, events };
}

const sent = (fetch: ReturnType<typeof vi.fn>, call = 0) => fetch.mock.calls[call]![0] as Request;

describe('createApi', () => {
  it('sends the ID token and names the household', async () => {
    const { api, fetch } = setup(() => respond(200, [], 'application/json'));
    await data(api.forHousehold('h1').GET('/api/v1/pets'));
    const request = sent(fetch);
    expect(request.url).toBe(`${BASE}/api/v1/pets`);
    expect(request.headers.get('Authorization')).toBe('Bearer id-token');
    expect(request.headers.get('X-Household')).toBe('h1');
    expect(request.headers.get('Accept')).toBe('application/json');
  });

  it('names no household for null, and keeps one client per household', async () => {
    const { api, fetch } = setup(() => respond(200, [], 'application/json'));
    await api.forHousehold(null).GET('/api/v1/households');
    expect(sent(fetch).headers.get('X-Household')).toBeNull();
    expect(api.forHousehold('h1')).toBe(api.forHousehold('h1'));
    expect(api.forHousehold('h1')).not.toBe(api.forHousehold('h2'));
  });

  it('builds the addresses of the contract', async () => {
    const { api, fetch } = setup(() => respond(200, {}, 'application/json'));
    const client = api.forHousehold('h1');
    await client.GET('/api/v1/today', { params: { query: { date: '2026-10-07' } } });
    await client.DELETE('/api/v1/routines/{id}/completions/{completionId}', {
      params: { path: { id: 'r 1', completionId: 'c1' } },
    });
    await client.POST('/api/v1/routines/{id}/completions', {
      params: { path: { id: 'r1' } },
      body: { date: '2026-10-07', time: '08:00:00', status: 'Done' },
    });
    expect(sent(fetch, 0).url).toBe(`${BASE}/api/v1/today?date=2026-10-07`);
    expect(sent(fetch, 1).method).toBe('DELETE');
    expect(sent(fetch, 1).url).toBe(`${BASE}/api/v1/routines/r%201/completions/c1`);
    expect(sent(fetch, 2).headers.get('Content-Type')).toBe('application/json');
    expect(await sent(fetch, 2).json()).toEqual({ date: '2026-10-07', time: '08:00:00', status: 'Done' });
  });

  it('gives back the answer, and hears it', async () => {
    const { api, events } = setup(() => respond(200, [{ id: 'p1' }], 'application/json'));
    await expect(data(api.forHousehold('h1').GET('/api/v1/pets'))).resolves.toEqual([{ id: 'p1' }]);
    expect(events).toEqual([{ kind: 'answer' }]);
  });
});

describe('failures', () => {
  const failure = async (answer: () => Response | Promise<Response>, token?: () => Promise<string | null>) => {
    const context = setup(answer, token);
    const error = await context.api.forHousehold('h1').GET('/api/v1/pets').catch((caught: unknown) => caught);
    return { error: error as ApiError, ...context };
  };

  it('keeps the problem: its type, the failed checks by field, the trace id and the household named', async () => {
    const { error, events } = await failure(() =>
      respond(400, {
        title: 'One or more validation errors occurred.',
        errors: { name: ['Required.'], 'identifiers[0].code': ['15 digits.'] },
        traceId: '00-abc-01',
      }),
    );
    expect(error).toBeInstanceOf(ApiError);
    expect(error).toMatchObject({
      status: 400,
      message: 'One or more validation errors occurred.',
      fields: { name: ['Required.'], 'identifiers[0].code': ['15 digits.'] },
      traceId: '00-abc-01',
      household: 'h1',
    });
    // An answer came: the server is there.
    expect(events.map((event) => event.kind)).toEqual(['answer', 'failure']);
  });

  it('tells a household the person left from a role that may not', async () => {
    const left = await failure(() => respond(403, { type: ProblemTypes.notAHouseholdMember }));
    expect(left.error).toMatchObject({ status: 403, type: ProblemTypes.notAHouseholdMember, household: 'h1' });
    expect(errorMessage(en, left.error)).toBe(en.errorNotInHousehold);
    const refused = await failure(() => respond(403, { type: ProblemTypes.roleForbidden }));
    expect(errorMessage(en, refused.error)).toBe(en.errorForbidden);
  });

  it('keeps the body of a conflict: who marked the feeding first', async () => {
    const mark = { id: 'm1', byName: 'Boris', byMe: false, doneAt: '2026-10-07T05:02:00Z' };
    const { error } = await failure(() => respond(409, mark, 'application/json'));
    expect(error).toMatchObject({ status: 409, body: mark });
  });

  it('says a deleted account apart from an expired sign-in', async () => {
    const deleted = await failure(() => respond(401, { type: ProblemTypes.accountDeleted }));
    expect(errorMessage(en, deleted.error)).toBe(en.accountDeletedNotice);
    const expired = await failure(() => respond(401));
    expect(errorMessage(en, expired.error)).toBe(en.errorUnauthorized);
  });

  it('turns no answer, and a proxy without its server, into status 0', async () => {
    const offline = await failure(() => {
      throw new TypeError('Failed to fetch');
    });
    expect(offline.error).toMatchObject({ status: 0 });
    expect(offline.events).toEqual([{ kind: 'failure', error: offline.error }]);
    expect(errorMessage(en, offline.error)).toBe(en.errorNetwork);

    const deploying = await failure(() => new Response('<html>502 Bad Gateway</html>', { status: 502 }));
    expect(deploying.error).toMatchObject({ status: 0 });
    // A 503 of the server itself (AI busy) is the server's answer.
    const busy = await failure(() => respond(503, { title: 'All models are busy.' }));
    expect(busy.error).toMatchObject({ status: 503 });
    expect(errorMessage(en, busy.error)).toBe(en.errorServer);
  });

  it('keeps a cancellation a cancellation', async () => {
    const controller = new AbortController();
    const { api, events } = setup(() => {
      controller.abort();
      throw new DOMException('Aborted', 'AbortError');
    });
    const error = await api
      .forHousehold('h1')
      .GET('/api/v1/pets', { signal: controller.signal })
      .catch((caught: unknown) => caught);
    expect(error).toMatchObject({ name: 'AbortError' });
    expect(events).toEqual([]);
  });

  it('asks nothing without a token, and says why', async () => {
    const signedOut = await failure(() => respond(200, []), async () => null);
    expect(signedOut.fetch).not.toHaveBeenCalled();
    expect(signedOut.error).toMatchObject({ status: 401 });

    const offline = await failure(
      () => respond(200, []),
      async () => {
        throw new TokenError('offline');
      },
    );
    expect(offline.error).toMatchObject({ status: 0 });

    const gone = await failure(
      () => respond(200, []),
      async () => {
        throw new TokenError('gone');
      },
    );
    expect(gone.error).toMatchObject({ status: 401, type: ProblemTypes.accountDeleted });
  });

  it('reads the server words of an error when there are no others', async () => {
    const { error } = await failure(() => respond(500, { title: 'Server error', detail: 'Database is down' }));
    expect(error).toMatchObject({ status: 500, message: 'Database is down' });
    expect(errorMessage(en, error)).toBe(en.errorServer);
    expect(errorMessage(en, new Error('boom'))).toBe(en.errorUnknown);
  });
});

describe('the sign-in a call started under', () => {
  it('goes with its failure, so a 401 of an earlier sign-in can be told apart', async () => {
    let epoch = 1;
    let answer!: () => void;
    const fetch = vi.fn(
      () =>
        new Promise<Response>((resolve) => {
          answer = () => resolve(respond(401, { title: 'Unauthorized' }));
        }),
    );
    const api = createApi({ fetch, token: async () => 'id-token', baseUrl: BASE, epoch: () => epoch });
    const call = api
      .forHousehold('h1')
      .GET('/api/v1/pets')
      .catch((error: unknown) => error);
    await vi.waitFor(() => expect(fetch).toHaveBeenCalledTimes(1));
    // Someone else signs in while the call is on its way.
    epoch = 2;
    answer();
    const error = (await call) as ApiError;
    expect(error.status).toBe(401);
    expect(error.epoch).toBe(1);
  });
});
