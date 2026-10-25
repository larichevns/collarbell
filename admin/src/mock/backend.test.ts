import { describe, expect, it } from 'vitest';
import { ApiError, createAdminApi } from '../api/client';
import type { TimelineEvent } from '../api/types';
import { checkPlanRequest, createMockBackend, mockToken, OWNER_EMAIL } from './backend';

const NOW = new Date('2026-10-05T15:00:00Z');

function mockApi(email = OWNER_EMAIL) {
  const backend = createMockBackend({ now: NOW, latencyMs: 0 });
  const api = createAdminApi({ fetch: backend.fetch, token: async () => mockToken(email) });
  return { backend, api };
}

describe('the mock backend', () => {
  it('answers like the server: 401 without a token, 403 for a non-admin, 404 for an unknown id', async () => {
    const { backend } = mockApi();
    expect((await backend.fetch('/api/admin/me')).status).toBe(401);
    const stranger = mockApi('stranger@example.com');
    await expect(stranger.api.overview()).rejects.toMatchObject({ status: 403 });
    const { api } = mockApi();
    await expect(api.user('no-such-person')).rejects.toMatchObject({ status: 404 });
    await expect(api.household('no-such-group')).rejects.toMatchObject({ status: 404 });
    await expect(api.me()).resolves.toEqual({ email: OWNER_EMAIL, displayName: 'Владелец' });
  });

  it('makes the same data every time', () => {
    const first = createMockBackend({ now: NOW, latencyMs: 0 }).fixtures;
    const second = createMockBackend({ now: NOW, latencyMs: 0 }).fixtures;
    expect(second.people).toEqual(first.people);
    expect(second.timeline(first.people[0]!.id, null, 500)).toEqual(first.timeline(first.people[0]!.id, null, 500));
  });

  it('searches people by e-mail or name, newest first', async () => {
    const { api } = mockApi();
    const all = await api.users('');
    expect(all).toHaveLength(21);
    const created = all.map((user) => Date.parse(user.createdAt));
    expect(created).toEqual([...created].sort((a, b) => b - a));
    expect((await api.users('СМИРН')).map((user) => user.displayName).sort()).toEqual(['Анна Смирнова', 'Дмитрий Смирнов']);
    expect((await api.users('example.de')).map((user) => user.email).sort()).toEqual(['lena.fischer@example.de', 'tom.becker@example.de']);
  });

  it('pages the визор by `before` without gaps or repeats, within 7 days', async () => {
    const { api, backend } = mockApi();
    const anna = backend.fixtures.people[0]!;
    const pages: TimelineEvent[][] = [];
    let before: string | null = null;
    for (;;) {
      const page: TimelineEvent[] = await api.timeline(anna.id, before);
      pages.push(page);
      if (page.length < 200) break;
      before = page[page.length - 1]!.at;
    }
    const all = pages.flat();
    expect(pages.length).toBeGreaterThan(1);
    expect(all).toEqual(backend.fixtures.timeline(anna.id, null, 100_000));
    const times = all.map((event) => Date.parse(event.at));
    expect(times).toEqual([...times].sort((a, b) => b - a));
    expect(NOW.getTime() - Math.min(...times)).toBeLessThan(7 * 24 * 3_600_000);
  });

  it('has problems that lead to their line in the визор', async () => {
    const { api } = mockApi();
    const problems = await api.problems(168);
    expect(problems.some((problem) => problem.kind === 'server' && problem.userId === null)).toBe(true);
    for (const problem of problems.filter((item) => item.userId)) {
      const lines = await api.timeline(problem.userId!, new Date(Date.parse(problem.at) + 1).toISOString());
      expect(lines[0]?.at).toBe(problem.at);
    }
    const day = await api.problems(24);
    expect(day.length).toBeLessThan(problems.length);
  });

  it('keeps the overview in line with the people and their визор', async () => {
    const { api } = mockApi();
    const overview = await api.overview();
    const day = await api.problems(24);
    expect(overview.people.users).toBe(21);
    expect(overview.people.households).toBe(18);
    expect(overview.people.sharedHouseholds).toBe(5);
    expect(overview.api.serverErrors24h).toBe(day.filter((problem) => problem.kind === 'server').length);
    expect(overview.devices.android + overview.devices.ios).toBe(
      overview.devices.appVersions.reduce((sum, version) => sum + version.devices, 0),
    );
  });
});

describe('plans in the mock', () => {
  const DAY = 86_400_000;
  const later = (days: number) => new Date(Date.now() + days * DAY).toISOString();
  const failure = (promise: Promise<unknown>) => promise.then(() => null, (error: unknown) => error as ApiError);

  it('starts with Premium until a day, Premium with no end, an ended trial and never-changed Free', async () => {
    const { api, backend } = mockApi();
    const ids = backend.fixtures.householdIds;
    const until = (await api.household(ids.smirnovy!)).plan;
    expect(until).toMatchObject({ plan: 'Premium', source: 'Manual', note: 'тестер', changedBy: OWNER_EMAIL, aiPhotosPerMonth: 300 });
    expect(Date.parse(until.expiresAt!)).toBeGreaterThan(Date.now());
    expect((await api.household(ids.ivanovy!)).plan).toMatchObject({ plan: 'Premium', expiresAt: null });
    const ended = (await api.household(ids.garcia!)).plan;
    expect(ended).toMatchObject({ plan: 'Free', source: 'Manual', aiPhotosUsed: 26, aiPhotosPerMonth: 20 });
    expect(Date.parse(ended.expiresAt!)).toBeLessThan(Date.now());
    expect((await api.household(ids.kozlov!)).plan).toMatchObject({
      plan: 'Free',
      source: null,
      expiresAt: null,
      changedAt: null,
      changedBy: null,
    });
    expect((await api.overview()).people.premiumHouseholds).toBe(2);
  });

  it('gives Premium until a moment or with no end, by the signed-in admin, with the note trimmed', async () => {
    const { api, backend } = mockApi('boss@example.com');
    const id = backend.fixtures.householdIds.kozlov!;
    const end = later(30);
    expect(await api.setPlan(id, { plan: 'Premium', expiresAt: end, note: '  тестер  ' })).toMatchObject({
      plan: 'Premium',
      source: 'Manual',
      expiresAt: end,
      note: 'тестер',
      changedBy: 'boss@example.com',
      aiPhotosPerMonth: 300,
    });
    expect(await api.setPlan(id, { plan: 'Premium', expiresAt: null, note: '   ' })).toMatchObject({ expiresAt: null, note: null });
    expect((await api.household(id)).plan.plan).toBe('Premium');
    expect((await api.overview()).people.premiumHouseholds).toBe(3);
  });

  it('takes Premium back: Free, and the end goes too', async () => {
    const { api, backend } = mockApi();
    const id = backend.fixtures.householdIds.smirnovy!;
    expect(await api.setPlan(id, { plan: 'Free', expiresAt: later(10), note: null })).toMatchObject({
      plan: 'Free',
      expiresAt: null,
      aiPhotosPerMonth: 20,
    });
    const anna = backend.fixtures.people[0]!;
    expect((await api.user(anna.id)).households[0]!.plan).toBe('Free');
    expect((await api.overview()).people.premiumHouseholds).toBe(1);
  });

  it('says no like the server: an end in the past, a long note, an unknown plan', async () => {
    const { api, backend } = mockApi();
    const id = backend.fixtures.householdIds.kozlov!;
    const past = await failure(api.setPlan(id, { plan: 'Premium', expiresAt: later(-1), note: null }));
    expect(past).toMatchObject({ status: 400, fields: { expiresAt: ['Premium can only end in the future.'] } });
    const long = await failure(api.setPlan(id, { plan: 'Premium', expiresAt: null, note: 'x'.repeat(201) }));
    expect(long).toMatchObject({ status: 400, fields: { note: ['At most 200 characters.'] } });
    expect((await api.household(id)).plan.plan).toBe('Free');
    expect(checkPlanRequest({ plan: 'Gold', expiresAt: null, note: null }, Date.now())).toEqual({
      errors: { plan: ['Free or Premium.'] },
    });
    // An end in the past doesn't matter when taking Premium back.
    expect(checkPlanRequest({ plan: 'Free', expiresAt: later(-5), note: null }, Date.now())).toEqual({
      request: { plan: 'Free', expiresAt: null, note: null },
    });
  });

  it('checks first, then looks for the group; a non-admin gets 403', async () => {
    const { api } = mockApi();
    expect(await failure(api.setPlan('nobody', { plan: 'Premium', expiresAt: later(-1), note: null }))).toMatchObject({ status: 400 });
    expect(await failure(api.setPlan('nobody', { plan: 'Premium', expiresAt: null, note: null }))).toMatchObject({ status: 404 });
    const stranger = mockApi('stranger@example.com');
    expect(await failure(stranger.api.setPlan('nobody', { plan: 'Free', expiresAt: null, note: null }))).toMatchObject({
      status: 403,
    });
  });
});
