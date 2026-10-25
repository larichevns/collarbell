// The household on screen: picked in the sidebar, named in every request, remembered per account, and left when the
// server says the person isn't in it any more.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { opened, renderApp } from '../test/render';
import { ANNA, createTestServer, HOME, MURKA, OFFICE, problem } from '../test/server';

const picker = () => within(screen.getByRole('banner')).getByLabelText('Group') as HTMLSelectElement;

describe('the household on screen', () => {
  it('lists the groups with the role in each, and switches: every request names the new one', async () => {
    const { server, router } = renderApp('/pets');
    await opened();
    expect(await screen.findByText('Murka')).toBeTruthy();
    expect([...picker().options].map((option) => option.text)).toEqual(['My home · Owner', 'Office · Helper']);
    expect(server.calls('GET', '/api/v1/pets').at(-1)!.household).toBe(HOME);

    fireEvent.change(picker(), { target: { value: OFFICE } });
    expect(await screen.findByText('Barsik')).toBeTruthy();
    expect(screen.queryByText('Murka')).toBeNull();
    expect(server.calls('GET', '/api/v1/pets').at(-1)!.household).toBe(OFFICE);
    expect(router.state.location.pathname).toBe('/pets');
    expect(JSON.parse(window.localStorage.getItem(`collarbell.household.uid-${ANNA}`)!)).toMatchObject({
      id: OFFICE,
      role: 'Helper',
    });
  });

  it('opens the first page of the section in the other household', async () => {
    const { router } = renderApp('/visits/visit-groomer');
    expect(await screen.findByRole('heading', { name: 'Groomer', level: 1 })).toBeTruthy();
    fireEvent.change(picker(), { target: { value: OFFICE } });
    await waitFor(() => expect(router.state.location.pathname).toBe('/visits'));
    expect(await screen.findByText('No visits yet')).toBeTruthy();
  });

  it('shows a helper what helpers do, and hides what they may not', async () => {
    window.localStorage.setItem(
      `collarbell.household.uid-${ANNA}`,
      JSON.stringify({ id: OFFICE, name: 'Office', role: 'Helper' }),
    );
    renderApp('/pets');
    expect(await screen.findByText('Barsik')).toBeTruthy();
    expect(screen.getByText('Sees everything and marks feedings, “Done”, visits and purchases.')).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Add pet' })).toBeNull();

    fireEvent.click(screen.getByRole('link', { name: 'Barsik' }));
    expect(await screen.findByRole('heading', { name: 'Barsik', level: 1 })).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Edit details' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Delete pet' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Add photo' })).toBeNull();
  });

  it('moves to the first household when the server says the person left this one', async () => {
    window.localStorage.setItem(
      `collarbell.household.uid-${ANNA}`,
      JSON.stringify({ id: OFFICE, name: 'Office', role: 'Helper' }),
    );
    const server = createTestServer();
    const { router } = renderApp('/pets', { server });
    expect(await screen.findByText('Barsik')).toBeTruthy();

    // Removed from "Office" on another phone; the next request there is refused.
    server.world.memberships = [HOME];
    fireEvent.click(screen.getByRole('link', { name: 'Barsik' }));
    expect(await screen.findByText("You're no longer in “Office”.")).toBeTruthy();
    // One household left: no picker any more.
    await waitFor(() => expect(within(screen.getByRole('banner')).queryByLabelText('Group')).toBeNull());
    expect(await screen.findByText('Murka')).toBeTruthy();
    expect(router.state.location.pathname).toBe('/pets');
    expect(server.calls('GET', '/api/v1/households').length).toBeGreaterThan(0);
  });

  it('reads the role again when the server refuses what the role can do', async () => {
    const server = createTestServer();
    server.respond('DELETE', /^\/api\/v1\/pets\/[^/]+$/, () =>
      problem(403, { type: 'urn:collarbell:problem:role-forbidden' }),
    );
    renderApp('/pets', { server });
    fireEvent.click(await screen.findByRole('link', { name: 'Rex' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Delete pet' }));
    // Meanwhile an owner made Anna a helper of her home.
    server.world.households.get(HOME)!.summary.role = 'Helper';
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete Rex?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    expect(await dialog.findByText("Your role in the group doesn't allow this.")).toBeTruthy();
    // The new role shows: the buttons a helper doesn't have are gone.
    await waitFor(() => expect(screen.queryByRole('link', { name: 'Edit details' })).toBeNull());
  });
});

// --- Review of part 1 (P6, P7): Back across groups, and forms a helper can't use ---

describe('the household and the history', () => {
  it('Back after switching groups opens the page in its own group again (P6)', async () => {
    const { router, server } = renderApp(`/pets/${MURKA}`);
    expect(await screen.findByRole('heading', { name: 'Murka', level: 1 })).toBeTruthy();
    fireEvent.change(picker(), { target: { value: OFFICE } });
    expect(await screen.findByText('Barsik')).toBeTruthy();

    await act(async () => {
      await router.navigate(-1);
    });
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}`));
    expect(await screen.findByRole('heading', { name: 'Murka', level: 1 })).toBeTruthy();
    expect(picker().value).toBe(HOME);
    expect(server.calls('GET', `/api/v1/pets/${MURKA}`).map((call) => call.household)).not.toContain(OFFICE);
    expect(screen.queryByText("This wasn't found. It may have been deleted.")).toBeNull();
  });

  it('a helper gets a word instead of a form, whatever the address (P7)', async () => {
    window.localStorage.setItem(
      `collarbell.household.uid-${ANNA}`,
      JSON.stringify({ id: OFFICE, name: 'Office', role: 'Helper' }),
    );
    const { server, router } = renderApp('/pets/new');
    expect(await screen.findByRole('heading', { name: "Your role in the group doesn't allow this" })).toBeTruthy();
    expect(screen.queryByLabelText('Name')).toBeNull();
    for (const path of ['/visits/new', '/pets/aaaaaaaa-0000-4000-8000-000000000004/feeding/new']) {
      await act(async () => {
        await router.navigate(path);
      });
      expect(await screen.findByRole('heading', { name: "Your role in the group doesn't allow this" })).toBeTruthy();
    }
    expect(server.calls('POST', '/api/v1/pets')).toHaveLength(0);
  });
});

// --- Review of part 2: a forced move's mark, and a move while a dialog saves ---

describe('leaving and the frame (review of part 2)', () => {
  it('Back from a form with typed input to the page a forced move left in the history still asks', async () => {
    window.localStorage.setItem(
      `collarbell.household.uid-${ANNA}`,
      JSON.stringify({ id: OFFICE, name: 'Office', role: 'Helper' }),
    );
    const server = createTestServer();
    const { router } = renderApp('/pets', { server });
    expect(await screen.findByText('Barsik')).toBeTruthy();
    // Removed from "Office" on another phone: the app moves to /pets of "Home" by itself.
    server.world.memberships = [HOME];
    fireEvent.click(screen.getByRole('link', { name: 'Barsik' }));
    expect(await screen.findByText('Murka')).toBeTruthy();
    await waitFor(() => expect(router.state.location.state).toBeNull());

    fireEvent.click(await screen.findByRole('link', { name: 'Add pet' }));
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Pushok' } });
    await act(async () => {
      await router.navigate(-1);
    });
    expect(await screen.findByRole('dialog', { name: 'Leave without saving?' })).toBeTruthy();
    expect(router.state.location.pathname).toBe('/pets/new');
  });

  it('a link clicked while a dialog saves what was typed waits for it, then goes on', async () => {
    const server = createTestServer();
    let release!: () => void;
    const gate = new Promise<void>((resolve) => (release = resolve));
    server.respond(
      'POST',
      `/api/v1/pets/${MURKA}/weights`,
      async () => {
        await gate;
        return undefined;
      },
      { once: true },
    );
    const { router } = renderApp(`/pets/${MURKA}/weight`, { server });
    const latest = await screen.findByRole('region', { name: 'Latest weighing' });
    fireEvent.click(within(latest).getByRole('button', { name: 'Add' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'New weighing' }));
    fireEvent.change(dialog.getByLabelText('Weight, kg'), { target: { value: '4,3' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', `/api/v1/pets/${MURKA}/weights`)).toHaveLength(1));
    // The sidebar's "Visits" mid-save: no question, the move waits.
    fireEvent.click(within(screen.getByRole('navigation', { name: 'Sections' })).getByRole('link', { name: 'Visits' }));
    await new Promise((resolve) => setTimeout(resolve, 30));
    expect(screen.queryByRole('dialog', { name: 'Leave without saving?' })).toBeNull();
    expect(router.state.location.pathname).toBe(`/pets/${MURKA}/weight`);
    await act(async () => release());
    await waitFor(() => expect(router.state.location.pathname).toBe('/visits'));
    expect(server.world.households.get(HOME)!.weights.some((item) => item.weightKg === 4.3)).toBe(true);
  });
});
