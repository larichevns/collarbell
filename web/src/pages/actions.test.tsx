// "Calls to action are buttons you want to press", app-wide (docs/mvp-spec.md, "Главная, знакомство, кнопки"): the
// main action of a page or section is a primary button, the others outlined (secondary) buttons or action cards where
// several things can be started; none is bare text. The action card itself, the empty states that mirror the phone's,
// and the calls to action that were bare text before.
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import { ActionCard, ActionList } from '../components/ActionCard';
import { renderApp } from '../test/render';
import { createTestServer, HOME, MURKA, problem, REX } from '../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));
const kind = (element: HTMLElement) =>
  ['button--primary', 'button--secondary', 'button--ghost'].find((each) => element.classList.contains(each));

describe('the action card', () => {
  function show(card: React.ReactNode) {
    const router = createMemoryRouter([{ path: '*', element: <ActionList>{card}</ActionList> }]);
    render(<RouterProvider router={router} />);
    return router;
  }

  it('is one link named by its title, the hint its description', async () => {
    const router = show(<ActionCard icon="restaurant" title="Add feeding" hint="We'll remind you" to="/pets" />);
    const card = screen.getByRole('link', { name: 'Add feeding' });
    expect(screen.getAllByRole('link')).toHaveLength(1);
    expect(document.getElementById(card.getAttribute('aria-describedby')!)?.textContent).toBe("We'll remind you");
    expect(card.className).toBe('action-card');
    // The chevron says it leads somewhere; the icon is decoration.
    expect(card.querySelectorAll('svg')).toHaveLength(2);
    fireEvent.click(card);
    await waitFor(() => expect(router.state.location.pathname).toBe('/pets'));
  });

  it('is a button when it does something here; primary and compact look their part', () => {
    const pressed = vi.fn();
    show(
      <>
        <ActionCard icon="pets" title="Add a pet" primary onClick={pressed} />
        <ActionCard icon="monitor_weight" title="Weigh" hint="Keep an eye on weight" compact onClick={pressed} />
      </>,
    );
    const first = screen.getByRole('button', { name: 'Add a pet' });
    expect(first.className).toBe('action-card action-card--primary');
    expect(first.getAttribute('aria-describedby')).toBeNull();
    const compact = screen.getByRole('button', { name: 'Weigh' });
    expect(compact.className).toBe('action-card action-card--compact');
    // Compact: no chevron.
    expect(compact.querySelectorAll('svg')).toHaveLength(1);
    fireEvent.click(compact);
    expect(pressed).toHaveBeenCalledTimes(1);
  });
});

describe('empty pages and sections', () => {
  it("Today with pets and nothing set up: action cards, one pet's straight to its forms", async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    Object.assign(home, { routines: [], plans: [], visits: [], supplies: [], stock: [] });
    home.pets = home.pets.filter((pet) => pet.id === MURKA);
    renderApp('/today', { server });
    expect(await screen.findByText('Nothing scheduled yet')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Add feeding' }).getAttribute('href')).toBe(`/pets/${MURKA}/feeding/new`);
    expect(screen.getByRole('link', { name: 'Vaccinations and treatments' }).getAttribute('href')).toBe(
      `/pets/${MURKA}/plans/new`,
    );
    expect(screen.getByRole('link', { name: 'Add a visit' }).getAttribute('href')).toBe('/visits/new');
  });

  it('Today without pets: "Add pet" is the main button', async () => {
    const server = createTestServer();
    Object.assign(server.world.households.get(HOME)!, { pets: [], routines: [], plans: [], visits: [], supplies: [] });
    renderApp('/today', { server });
    expect(await screen.findByText('Start with a pet')).toBeTruthy();
    expect(kind(screen.getByRole('link', { name: 'Add pet' }))).toBe('button--primary');
  });

  it('Health: "Add plan" under the empty text; the ways to fill the history as cards', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    home.plans = [];
    home.records = [];
    renderApp(`/pets/${REX}/health`, { server });
    const plans = await region('Care plan');
    await waitFor(() => expect(kind(plans.getByRole('link', { name: 'Add plan' }))).toBe('button--primary'));
    const history = await region('History');
    expect(await history.findByRole('link', { name: 'Scan passport pages' })).toBeTruthy();
    expect(history.getByRole('link', { name: 'Write it in words' }).getAttribute('href')).toBe(
      `/pets/${REX}/note?from=health`,
    );
    expect(history.getByRole('link', { name: 'Enter from the passport' }).getAttribute('href')).toBe(
      `/pets/${REX}/records/import`,
    );
    expect(history.getByRole('link', { name: 'Add past record' }).className).toContain('action-card');
    // Not twice: no buttons beside the titles while empty.
    expect(plans.getAllByRole('link', { name: 'Add plan' })).toHaveLength(1);
  });

  it('Feeding: "Add feeding" under the empty text, "Add" beside the title once there are schedules', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    home.routines = home.routines.filter((routine) => routine.petId !== REX);
    const { router } = renderApp(`/pets/${REX}/feeding`, { server });
    const section = await region('Feeding schedule');
    expect(kind(await section.findByRole('link', { name: 'Add feeding' }))).toBe('button--primary');
    expect(section.queryByRole('link', { name: 'Add' })).toBeNull();
    await act(() => router.navigate(`/pets/${MURKA}/feeding`));
    await waitFor(() => {
      const section = within(screen.getByRole('region', { name: 'Feeding schedule' }));
      expect(kind(section.getByRole('link', { name: 'Add' }))).toBe('button--secondary');
    });
  });

  it('Visits: the button under the empty text, not over it', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.visits = [];
    renderApp('/visits', { server });
    expect(await screen.findByText('No visits yet')).toBeTruthy();
    expect(screen.getAllByRole('link', { name: 'Add a visit' })).toHaveLength(1);
    expect(kind(screen.getByRole('link', { name: 'Add a visit' }))).toBe('button--primary');
  });

  it('Supplies: a card starts the new item at the barcode, or with the photos open', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.supplies = [];
    const { router } = renderApp('/supplies', { server });
    fireEvent.click(await screen.findByRole('link', { name: 'Find by the barcode' }));
    await waitFor(() => expect(router.state.location.search).toBe('?start=barcode'));
    expect(await screen.findByLabelText('Barcode')).toBe(document.activeElement);
  });

  it('…or with "Fill from photos" open, only when AI is set up', async () => {
    renderApp('/supplies/new?start=photos');
    expect(await screen.findByRole('dialog', { name: 'Fill from photos of the package' })).toBeTruthy();
  });

  it('…and without AI, just the form', async () => {
    const server = createTestServer();
    server.world.ai = { ...server.world.ai, configured: false };
    renderApp('/supplies/new?start=photos', { server });
    expect(await screen.findByLabelText('Barcode')).toBeTruthy();
    await waitFor(() => expect(server.calls('GET', '/api/v1/ai/status')).toHaveLength(1));
    await act(async () => new Promise((resolve) => setTimeout(resolve, 50)));
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it("Today's first steps say when the pets couldn't be read, with Try again", async () => {
    const server = createTestServer();
    Object.assign(server.world.households.get(HOME)!, { routines: [], plans: [], visits: [], supplies: [] });
    server.respond('GET', '/api/v1/pets', () => problem(500), { once: true });
    renderApp('/today', { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('Nothing scheduled yet')).toBeTruthy();
  });
});

describe('calls to action that were bare text', () => {
  it('Today: "All visits", "Add a visit" and "All fed" are outlined buttons with an icon', async () => {
    renderApp('/today');
    const visits = await region('Visits');
    for (const name of ['All visits', 'Add a visit']) {
      const link = visits.getByRole('link', { name });
      expect(kind(link)).toBe('button--secondary');
      expect(link.querySelector('svg')).toBeTruthy();
    }
    const allFed = (await region('Feeding')).getByRole('button', { name: 'All fed' });
    expect(kind(allFed)).toBe('button--secondary');
    // "Skip" next to "Fed" is an escape: it stays text.
    expect(kind((await region('Feeding')).getAllByRole('button', { name: 'Skip' })[0]!)).toBe('button--ghost');
  });

  it('the pet tabs: the buttons beside the titles are outlined', async () => {
    const { router } = renderApp(`/pets/${MURKA}/health`);
    const plans = await region('Care plan');
    expect(kind(await plans.findByRole('link', { name: 'Add plan' }))).toBe('button--secondary');
    const history = await region('History');
    expect(kind(await history.findByRole('link', { name: 'Add past record' }))).toBe('button--secondary');
    expect(kind(await history.findByRole('link', { name: 'Scan a vet document' }))).toBe('button--secondary');

    await router.navigate(`/pets/${MURKA}/passport`);
    expect(kind(await (await region('Passport details')).findByRole('link', { name: 'Edit' }))).toBe(
      'button--secondary',
    );
    expect(kind((await region('Microchips and tattoos')).getByRole('link', { name: 'Edit' }))).toBe(
      'button--secondary',
    );
  });

  it("Settings: inviting, joining and creating a group are outlined buttons; removing someone stays text", async () => {
    renderApp('/settings');
    const members = await region('Members');
    expect(kind(await members.findByRole('button', { name: 'Invite' }))).toBe('button--secondary');
    expect(kind(members.getByRole('button', { name: 'Change role: Boris' }))).toBe('button--secondary');
    expect(kind(members.getByRole('button', { name: 'Remove from group: Boris' }))).toBe('button--ghost');
    const groups = await region('Your groups');
    expect(kind(groups.getByRole('link', { name: 'Join with a code' }))).toBe('button--secondary');
    expect(kind(groups.getByRole('button', { name: 'Create a group' }))).toBe('button--secondary');
  });

  it('a visit and an item: "Cancel visit" and "Stop buying" are outlined; deleting stays red text', async () => {
    const { router } = renderApp('/visits/visit-groomer');
    expect(kind(await screen.findByRole('button', { name: 'Cancel visit' }))).toBe('button--secondary');
    await router.navigate('/supplies/supply-food');
    expect(kind(await screen.findByRole('button', { name: 'Stop buying' }))).toBe('button--secondary');
    expect(kind(screen.getByRole('button', { name: 'Delete item' }))).toBe('button--ghost');
  });
});
