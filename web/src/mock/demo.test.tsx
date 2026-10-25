// The demo (npm run dev:mock): its world in each language makes every screen of the app show something, with no
// error, so a look at it really shows the app.
import { act, screen, waitFor } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { en } from '../i18n/en';
import type { Lang } from '../i18n/lang';
import { ru } from '../i18n/ru';
import { renderApp } from '../test/render';
import { createTestServer } from '../test/server';
import { createDemoWorld, DEMO_IDS, shapeDemoWorld } from './world';

const { CAT, DOG, OFFICE } = DEMO_IDS;

/** Every screen, by address, and a heading it shows. */
function screens(world: ReturnType<typeof createDemoWorld>) {
  const home = world.households.get(DEMO_IDS.HOME)!;
  const record = home.records.find((item) => item.petId === CAT && item.files.length > 0)!;
  const document = home.documents.find((item) => item.type === 'LabResult')!;
  const plan = home.plans.find((item) => item.petId === CAT)!;
  const feeding = home.routines.find((item) => item.petId === CAT)!;
  const visit = home.visits[0]!;
  const food = home.supplies.find((item) => item.category === 'DryFood')!;
  const scan = home.imports.find((item) => item.status === 'Ready')!;
  const note = home.imports.find((item) => item.source === 'Text')!;
  return [
    '/',
    '/today',
    '/welcome',
    '/welcome?step=pet',
    '/welcome?step=feeding',
    '/welcome?step=family',
    '/pets',
    `/pets/${CAT}`,
    `/pets/${CAT}/health`,
    `/pets/${CAT}/passport`,
    `/pets/${CAT}/documents`,
    `/pets/${CAT}/feeding`,
    `/pets/${CAT}/weight`,
    `/pets/${DOG}/weight`,
    `/pets/${DOG}/passport`,
    `/pets/${CAT}/edit`,
    `/pets/${CAT}/plans/new`,
    `/pets/${CAT}/plans/new/cat-rabies`,
    `/pets/${CAT}/plans/${plan.id}`,
    `/pets/${CAT}/records/new`,
    `/pets/${CAT}/records/import`,
    `/pets/${CAT}/records/${record.id}`,
    `/pets/${CAT}/records/${record.id}/edit`,
    `/pets/${CAT}/passport/edit`,
    `/pets/${CAT}/documents/${document.id}`,
    `/pets/${CAT}/feeding/new`,
    `/pets/${CAT}/feeding/${feeding.id}`,
    `/pets/${CAT}/scans/${scan.id}`,
    `/pets/${CAT}/scans/${note.id}`,
    `/pets/${CAT}/scan`,
    `/pets/${CAT}/note`,
    '/visits',
    '/visits/new',
    `/visits/${visit.id}`,
    `/visits/${visit.id}/edit`,
    '/supplies',
    '/supplies/new',
    `/supplies/${food.id}`,
    `/supplies/${food.id}/edit`,
    '/settings',
    '/settings/delete-account',
    `/join#${DEMO_IDS.CODE}`,
  ];
}

describe.each<Lang>(['en', 'ru'])('the demo in %s', (lang) => {
  it('shows every screen with its data, and none fails', async () => {
    const world = createDemoWorld(lang);
    const server = createTestServer(world);
    // Every answer that wasn't a success, by request.
    const failures: string[] = [];
    const answer = server.fetch;
    server.fetch = async (input, init) => {
      const response = await answer(input, init);
      const request = input instanceof Request ? input : new Request(input, init);
      if (!response.ok) failures.push(`${request.method} ${new URL(request.url).pathname} ${response.status}`);
      return response;
    };
    const { router } = renderApp('/', { server });
    for (const path of screens(world)) {
      await act(async () => {
        await router.navigate(path);
      });
      await waitFor(() => expect(screen.getByRole('heading', { level: 1 })).toBeTruthy());
      await waitFor(() => expect(document.querySelector('.loading')).toBeNull());
      expect(document.querySelector('.notice--danger'), path).toBeNull();
    }
    expect(failures).toEqual([]);
    expect(server.requests.length).toBeGreaterThan(30);
  });

  it('has its words in its language, a helper household and the pages of a passport', () => {
    const world = createDemoWorld(lang);
    expect(world.locale).toBe(lang);
    const home = world.households.get(DEMO_IDS.HOME)!;
    expect(home.pets.map((item) => item.name)).toEqual(lang === 'ru' ? ['Мурка', 'Рекс'] : ['Murka', 'Rex']);
    expect(world.households.get(OFFICE)!.summary.role).toBe('Helper');
    expect(home.documents.find((item) => item.type === 'PassportPage')!.pages).toHaveLength(3);
    expect(home.records.some((item) => item.kind === 'VetExam' && item.weightKg !== null)).toBe(true);
    expect(home.routines.some((item) => !item.active)).toBe(true);
    expect(home.plans.some((item) => !item.active)).toBe(true);
    // A member, a helper and an open invite; and a code to join the neighbours.
    expect(home.others.map((each) => each.role).sort()).toEqual(['Helper', 'Member']);
    expect(home.invites).toHaveLength(1);
    expect(world.households.get(DEMO_IDS.NEIGHBOURS)!.invites[0]!.code).toBe(DEMO_IDS.CODE.replace('-', ''));
  });

  it('has a scan to check with every kind of entry and doubt, and a note that failed', () => {
    const world = createDemoWorld(lang);
    const home = world.households.get(DEMO_IDS.HOME)!;
    const scan = home.imports.find((item) => item.status === 'Ready')!;
    const read = 'draft' in scan.outcome ? scan.outcome.draft : null;
    expect(scan.fileIds).toHaveLength(3);
    expect(read!.records.length).toBeGreaterThan(0);
    expect(read!.weights.length).toBeGreaterThan(0);
    expect(read!.identifiers.length).toBeGreaterThan(0);
    expect(read!.passport).toBeTruthy();
    const issues = new Set(
      [...read!.records, ...read!.weights, ...read!.identifiers, read!.passport!].flatMap((entry) =>
        entry.warnings.map((warning) => warning.issue),
      ),
    );
    expect([...issues].sort()).toEqual(
      ['AlreadySaved', 'Ambiguous', 'DiffersFromSaved', 'EndsBeforeStart', 'InFuture', 'InvalidFormat', 'Repeated', 'Unreadable'],
    );
    const note = home.imports.find((item) => item.source === 'Text')!;
    expect(note.status).toBe('Failed');
    expect(note.text).toBeTruthy();
    // Two chip numbers on a photo: the pet form offers the choice.
    expect(world.chipReadings).toHaveLength(2);
  });

  it('has supplies in every state of the list', async () => {
    const world = createDemoWorld(lang);
    const server = createTestServer(world);
    renderApp('/supplies', { server });
    // The app takes the profile's language, the demo world's. The names from the dictionary: the Russian ones keep
    // short words with the next by a no-break space («В запасе»).
    const { supplyGroup } = lang === 'ru' ? ru : en;
    for (const group of [supplyGroup.toBuy, supplyGroup.soon, supplyGroup.inStock, supplyGroup.notBought]) {
      expect(await screen.findByRole('region', { name: group })).toBeTruthy();
    }
  });

  it('has a new account to look at: the onboarding opens by itself', async () => {
    const fresh = createDemoWorld(lang);
    shapeDemoWorld(fresh, 'new');
    expect(fresh.memberships).toEqual([DEMO_IDS.HOME]);
    expect(fresh.households.get(DEMO_IDS.HOME)!.pets).toEqual([]);
    // Another account: this browser hasn't had its onboarding.
    expect(fresh.me.email).not.toBe(createDemoWorld(lang).me.email);
    const { router } = renderApp('/', { server: createTestServer(fresh), user: fresh.me.email });
    await waitFor(() => expect(router.state.location.pathname).toBe('/welcome'));
  });

  it('has pets with nothing set up to look at: the first steps', async () => {
    const t = lang === 'ru' ? ru : en;
    const bare = createDemoWorld(lang);
    shapeDemoWorld(bare, 'pets');
    renderApp('/today', { server: createTestServer(bare) });
    expect(await screen.findByRole('button', { name: t.todayAddFeeding })).toBeTruthy();
  });

  it('has a day done to look at', async () => {
    const t = lang === 'ru' ? ru : en;
    const done = createDemoWorld(lang);
    shapeDemoWorld(done, 'done');
    renderApp('/', { server: createTestServer(done) });
    // The text query sees no-break spaces as spaces.
    expect(await screen.findByText(t.homeAllDoneTitle.replace(/\u00a0/g, ' '))).toBeTruthy();
  });
});
