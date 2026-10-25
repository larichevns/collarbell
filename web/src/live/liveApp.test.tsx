// Live updates in the app: every request carries the tab's id; a ticket (the person's, naming no household) opens the
// household on screen; "Live" in the sidebar; the household's pages read again once connected again after a drop (not
// on the first connection: they have just been read); a change heard reads again what shows it (the tab's own
// skipped); Today stops asking every 30 seconds while connected; another household connects anew; a refusal stops it.
import { QueryClient } from '@tanstack/react-query';
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { keys } from '../api/keys';
import { testHub } from '../test/hub';
import { renderApp } from '../test/render';
import { HOME, MURKA, OFFICE } from '../test/server';
import { readTopics } from './topics';

const TAB = 'tab-test-1';
const sidebar = () => within(screen.getByRole('banner'));

afterEach(() => {
  vi.useRealTimers();
});

/** The app on `path` with live updates, connected once the hub's first connection opens. */
async function connected(path = '/') {
  const hub = testHub();
  const rendered = renderApp(path, { live: hub.factory, clientId: TAB });
  await waitFor(() => expect(hub.last).toBeTruthy());
  await waitFor(() => expect(hub.last!.ticket).toBeTruthy());
  await act(async () => hub.last!.open());
  await waitFor(() => expect(sidebar().getByText('Live')).toBeTruthy());
  return { hub, ...rendered };
}

describe('live updates in the app', () => {
  it("carries the tab's id on every request, and opens the household on screen with a ticket of the person's", async () => {
    const hub = testHub();
    const { server } = renderApp('/', { live: hub.factory, clientId: TAB });
    await waitFor(() => expect(hub.last?.ticket).toBe('ticket-1'));
    expect(sidebar().getByText('Connecting…')).toBeTruthy();
    const ticket = server.calls('POST', '/api/v1/live/tickets')[0]!;
    // The person's own: it names no household.
    expect(ticket.household).toBeNull();
    expect(hub.last!.url).toBe(`${window.location.origin}/hubs/household?household=${HOME}`);
    expect(ticket.authorization).toBe('Bearer token:anna@example.com');
    await act(async () => hub.last!.open());
    expect(await sidebar().findByText('Live')).toBeTruthy();
  });

  it('sends X-Client with every API request', async () => {
    const hub = testHub();
    const seen: (string | null)[] = [];
    const { server } = renderApp('/pets', { live: hub.factory, clientId: TAB });
    const answer = server.fetch;
    server.fetch = async (input, init) => {
      const request = input instanceof Request ? input : new Request(input, init);
      if (new URL(request.url).pathname.startsWith('/api/')) seen.push(request.headers.get('X-Client'));
      return answer(request);
    };
    fireEvent.click(await screen.findByRole('link', { name: /Murka/ }));
    await waitFor(() => expect(seen.length).toBeGreaterThan(0));
    expect(new Set(seen)).toEqual(new Set([TAB]));
  });

  it("doesn't read the pages again on the first connection, and does once connected again after a drop", async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'setTimeout', 'clearTimeout'], shouldAdvanceTime: true });
    const hub = testHub();
    const { server } = renderApp('/today', { live: hub.factory, clientId: TAB });
    await screen.findByRole('region', { name: 'Feeding' });
    await waitFor(() => expect(hub.last?.ticket).toBeTruthy());
    const asked = () => server.calls('GET', '/api/v1/today').length;
    const opened = asked();
    await act(async () => hub.last!.open());
    expect(await sidebar().findByText('Live')).toBeTruthy();
    await act(async () => new Promise((resolve) => setTimeout(resolve, 400)));
    // Read when the page opened: once is enough.
    expect(asked()).toBe(opened);
    await act(async () => hub.last!.drop());
    await act(async () => {
      await vi.advanceTimersByTimeAsync(1000);
    });
    await waitFor(() => expect(hub.connections).toHaveLength(2));
    await waitFor(() => expect(hub.last!.ticket).toBeTruthy());
    const dropped = asked();
    await act(async () => hub.last!.open());
    // Nothing was heard while it was down, and the server keeps no history.
    await waitFor(() => expect(asked()).toBe(dropped + 1));
  });

  it('reads again what a change heard shows, and skips the changes the tab made itself', async () => {
    const { hub, server } = await connected(`/pets/${MURKA}/health`);
    await screen.findByRole('region', { name: 'Care plan' });
    await waitFor(() => expect(server.calls('GET', `/api/v1/pets/${MURKA}/care-plans`).length).toBeGreaterThan(0));
    const plans = () => server.calls('GET', `/api/v1/pets/${MURKA}/care-plans`).length;
    const pets = () => server.calls('GET', `/api/v1/pets/${MURKA}`).length;
    // Read when the page opened; connecting doesn't read them again.
    await waitFor(() => expect(plans()).toBe(1));
    const [plansBefore, petsBefore] = [plans(), pets()];
    // The tab's own change: shown already.
    await act(async () => hub.last!.hear(['care'], TAB));
    await act(async () => new Promise((resolve) => setTimeout(resolve, 400)));
    expect(plans()).toBe(plansBefore);
    // Someone else's: the plans are read again, the pet isn't.
    await act(async () => hub.last!.hear(['care'], null));
    await waitFor(() => expect(plans()).toBe(plansBefore + 1));
    expect(pets()).toBe(petsBefore);
    // A topic this app doesn't know: everything of the household.
    await act(async () => hub.last!.hear(['litter-boxes'], null));
    await waitFor(() => expect(pets()).toBe(petsBefore + 1));
  });

  it("stops Today's 30-second reading while connected, and takes it up again once the connection drops", async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'setTimeout', 'clearTimeout'], shouldAdvanceTime: true });
    const { hub, server } = await connected('/today');
    await screen.findByRole('region', { name: 'Feeding' });
    const asked = () => server.calls('GET', '/api/v1/today').length;
    await waitFor(() => expect(asked()).toBe(1));
    await act(async () => {
      await vi.advanceTimersByTimeAsync(65_000);
    });
    expect(asked()).toBe(1);
    expect(sidebar().getByText('Live')).toBeTruthy();
    await act(async () => hub.last!.drop());
    expect(await sidebar().findByText('Reconnecting…')).toBeTruthy();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(31_000);
    });
    await waitFor(() => expect(asked()).toBeGreaterThan(1));
  });

  it('connects anew when another household is on screen', async () => {
    const { hub } = await connected('/');
    const first = hub.last!;
    fireEvent.change(sidebar().getByLabelText('Group'), { target: { value: OFFICE } });
    await waitFor(() => expect(first.closed).toBe(true));
    await waitFor(() => expect(hub.last!.url).toContain(`household=${OFFICE}`));
    expect(hub.last!.ticket).toBe('ticket-2');
  });

  it('a refusal: no "Live", and no more tries', async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'setTimeout', 'clearTimeout'], shouldAdvanceTime: true });
    const hub = testHub();
    renderApp('/', { live: hub.factory, clientId: TAB });
    await waitFor(() => expect(hub.last?.ticket).toBeTruthy());
    await act(async () => hub.last!.refuse());
    await waitFor(() => expect(sidebar().queryByText('Connecting…')).toBeNull());
    await act(async () => {
      await vi.advanceTimersByTimeAsync(120_000);
    });
    expect(hub.connections).toHaveLength(1);
    expect(sidebar().queryByText('Live')).toBeNull();
  });

  it('without live updates (the tests, unless they ask) nothing connects and the sidebar says nothing of it', async () => {
    const { server } = renderApp('/today');
    await screen.findByRole('region', { name: 'Feeding' });
    expect(server.calls('POST', '/api/v1/live/tickets')).toHaveLength(0);
    expect(sidebar().queryByText('Live')).toBeNull();
  });
});

describe('what each topic reads again', () => {
  function cached(household: string) {
    const queryClient = new QueryClient();
    const all = [
      keys.pets(household),
      keys.pet(household, 'p1'),
      keys.carePlans(household, 'p1'),
      keys.careRecords(household, 'p1'),
      keys.passportRecords(household, 'p1'),
      keys.weights(household, 'p1'),
      keys.todayAll(household),
      keys.supplies(household),
      keys.routines(household, 'p1'),
      keys.documents(household, 'p1'),
      keys.passport(household, 'p1'),
      keys.visits(household),
      keys.aiImports(household, 'p1', 'scans'),
      keys.aiImport(household, 'scan-1'),
      keys.plan(household),
      keys.aiStatus(household),
      keys.householdDetails(household),
    ];
    for (const key of all) queryClient.setQueryData(key, 'x');
    for (const key of [keys.me('u1'), keys.households('u1'), keys.deletion('u1')]) queryClient.setQueryData(key, 'x');
    return queryClient;
  }
  const stale = (queryClient: QueryClient) =>
    queryClient
      .getQueryCache()
      .getAll()
      .filter((query) => query.state.isInvalidated)
      .map((query) => query.queryKey.slice(query.queryKey[0] === HOME ? 1 : 0).join('/'))
      .sort();

  it("care: the plans, records, passport sections, weights and Today; nothing of the pets' or supplies'", () => {
    const queryClient = cached(HOME);
    readTopics(queryClient, HOME, 'u1', ['care']);
    expect(stale(queryClient)).toEqual(
      ['care-plans/p1', 'care-records/p1', 'passport-records/p1', 'today', 'weights/p1'].sort(),
    );
  });

  it('household: its details, the person, their groups, Today and what deleting the account would do', () => {
    const queryClient = cached(HOME);
    readTopics(queryClient, HOME, 'u1', ['household']);
    expect(stale(queryClient)).toEqual(['deletion/u1', 'household', 'households/u1', 'me/u1', 'today'].sort());
  });

  it("imports: the waiting scans, a scan's page, the plan and the AI status", () => {
    const queryClient = cached(HOME);
    readTopics(queryClient, HOME, 'u1', ['imports']);
    expect(stale(queryClient)).toEqual(['ai-import/scan-1', 'ai-imports/p1/scans', 'ai-status', 'plan'].sort());
  });

  it("an unknown topic: everything of the household and the person's lists, nothing of another household", () => {
    const queryClient = cached(HOME);
    for (const key of [keys.pets(OFFICE), keys.todayAll(OFFICE)]) queryClient.setQueryData(key, 'x');
    readTopics(queryClient, HOME, 'u1', ['something-new']);
    const invalidated = queryClient
      .getQueryCache()
      .getAll()
      .filter((query) => query.state.isInvalidated)
      .map((query) => query.queryKey[0]);
    expect(invalidated).not.toContain(OFFICE);
    expect(invalidated.filter((first) => first === HOME)).toHaveLength(17);
    expect(invalidated).toEqual(expect.arrayContaining(['me', 'households', 'deletion']));
  });
});
