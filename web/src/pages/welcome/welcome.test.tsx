// The onboarding on the pretend server: when it opens by itself (once per account on this browser, for an empty
// household, never with pets, never when storage is off), opening it again from Settings, the pages and steps, adding
// the pet and its feeding with the right requests, a lost answer that mustn't add the pet twice, skipping, what helpers
// and members see, and leaving with a typed name.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { renderApp } from '../../test/render';
import { ANNA, createTestServer, HOME, OFFICE, pet, problem, type TestServer } from '../../test/server';

const FLAG = `collarbell.onboarding.uid-${ANNA}`;

/** Anna on the helper's household, Office, as if she had it on screen last time. */
function asHelper() {
  const office = { id: OFFICE, name: 'Office', role: 'Helper' };
  window.localStorage.setItem(`collarbell.household.uid-${ANNA}`, JSON.stringify(office));
}

afterEach(() => {
  vi.restoreAllMocks();
});

/** A new account's world: Anna is in one household, made for her at her first sign-in, with nothing in it yet. */
function emptyHome(): TestServer {
  const server = createTestServer();
  const home = server.world.households.get(HOME)!;
  Object.assign(home, { pets: [], routines: [], plans: [], visits: [], supplies: [], stock: [], records: [] });
  server.world.memberships = [HOME];
  return server;
}

const pause = () => act(async () => new Promise((resolve) => setTimeout(resolve, 50)));

const main = () => screen.getByRole('main');
const heading = async (name: string) =>
  within(await screen.findByRole('main')).findByRole('heading', { name, level: 1 });
const press = (name: string) => fireEvent.click(within(main()).getByRole('button', { name }));

/** From the first page to the pet step. */
async function toPetStep() {
  await heading('Reminders on time');
  press('Next');
  await heading('The passport in a minute');
  press('Next');
  await heading('Together with the family');
  press('Start');
  await heading('Who lives with you?');
}

describe('when the onboarding opens by itself', () => {
  it('opens once for a new account with an empty household, in place of Home', async () => {
    const { router } = renderApp('/', { server: emptyHome() });
    await waitFor(() => expect(router.state.location.pathname).toBe('/welcome'));
    expect(await heading('Reminders on time')).toBeTruthy();
    // In place of Home: Back doesn't bring Home's question back.
    expect(router.state.historyAction).toBe('REPLACE');
    expect(window.localStorage.getItem(FLAG)).toBe('1');

    // Home again, in its place: its turn is taken, Home stays.
    fireEvent.click(screen.getByRole('button', { name: 'Close' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/'));
    expect(router.state.historyAction).toBe('REPLACE');
    expect(await screen.findByRole('link', { name: 'Add a pet' })).toBeTruthy();
    await pause();
    expect(router.state.location.pathname).toBe('/');
  });

  it("never opens for a family member: their own empty household on screen, but they're in another too", async () => {
    // Anna joined Office; a new browser opens her own household, made at her first sign-in, still empty.
    const server = emptyHome();
    server.world.memberships = [HOME, OFFICE];
    const { router } = renderApp('/', { server });
    expect(await screen.findByRole('link', { name: 'Add a pet' })).toBeTruthy();
    await pause();
    expect(router.state.location.pathname).toBe('/');
    expect(window.localStorage.getItem(FLAG)).toBe('1');
  });

  it('never opens when the household has pets, even only archived ones', async () => {
    const server = emptyHome();
    server.world.households.get(HOME)!.pets = [pet('pet-old', 'Tom', { status: 'Archived' })];
    const { router } = renderApp('/', { server });
    // Home itself shows no active pets: the first step is a pet.
    expect(await screen.findByRole('link', { name: 'Add a pet' })).toBeTruthy();
    await pause();
    expect(router.state.location.pathname).toBe('/');
    expect(window.localStorage.getItem(FLAG)).toBe('1');
  });

  it('never opens after it was opened from Settings', async () => {
    const { router } = renderApp('/settings', { server: emptyHome() });
    fireEvent.click(await screen.findByRole('link', { name: 'Getting to know the app' }));
    await heading('Reminders on time');
    expect(window.localStorage.getItem(FLAG)).toBe('1');
    fireEvent.click(screen.getByRole('button', { name: 'Close' }));
    expect(await screen.findByRole('link', { name: 'Add a pet' })).toBeTruthy();
    await pause();
    expect(router.state.location.pathname).toBe('/');
  });

  it('never opens for a household with pets, and marks the turn as taken', async () => {
    const { router } = renderApp('/');
    await screen.findByRole('region', { name: 'Right now' });
    await waitFor(() => expect(window.localStorage.getItem(FLAG)).toBe('1'));
    expect(router.state.location.pathname).toBe('/');
  });

  it("keeps the turn per account: another account's doesn't count", async () => {
    window.localStorage.setItem('collarbell.onboarding.uid-boris@example.com', '1');
    const { router } = renderApp('/', { server: emptyHome() });
    await waitFor(() => expect(router.state.location.pathname).toBe('/welcome'));
  });

  it('never opens a second time on this browser', async () => {
    window.localStorage.setItem(FLAG, '1');
    const { router } = renderApp('/', { server: emptyHome() });
    expect(await screen.findByRole('link', { name: 'Add a pet' })).toBeTruthy();
    await pause();
    expect(router.state.location.pathname).toBe('/');
  });

  it("doesn't open (nor break Home) when the browser's storage is off", async () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new DOMException('The operation is insecure.', 'SecurityError');
    });
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('The operation is insecure.', 'SecurityError');
    });
    const { router } = renderApp('/', { server: emptyHome() });
    expect(await screen.findByRole('link', { name: 'Add a pet' })).toBeTruthy();
    await pause();
    expect(router.state.location.pathname).toBe('/');
  });

  it("doesn't open for a helper of a household without pets", async () => {
    const server = createTestServer();
    server.world.households.get(OFFICE)!.pets = [];
    asHelper();
    const { router } = renderApp('/', { server });
    expect(await screen.findByText('No pets yet')).toBeTruthy();
    await pause();
    expect(router.state.location.pathname).toBe('/');
    expect(window.localStorage.getItem(FLAG)).toBe('1');
  });
});

describe('the onboarding', () => {
  it('opens again from Settings → Help', async () => {
    const { router } = renderApp('/settings');
    const help = within(await screen.findByRole('region', { name: 'Help' }));
    const card = help.getByRole('link', { name: 'Getting to know the app' });
    expect(card.getAttribute('aria-describedby')).toBeTruthy();
    expect(help.getByText('What the app does and the first steps')).toBeTruthy();
    fireEvent.click(card);
    await waitFor(() => expect(router.state.location.pathname).toBe('/welcome'));
    expect(await heading('Reminders on time')).toBeTruthy();
    expect(document.title).toBe('Getting to know the app · Collarbell');
  });

  it("says truthfully where reminders come: the phone app (there's no notifications step here)", async () => {
    renderApp('/welcome');
    await heading('Reminders on time');
    expect(await within(main()).findByText(/the phone app reminds you at the right minute/)).toBeTruthy();
    expect(screen.getByRole('img', { name: 'Page 1 of 3' })).toBeTruthy();
  });

  it('walks the pages and steps with the address, so Back goes to the one before', async () => {
    const { router } = renderApp('/welcome', { server: emptyHome() });
    await toPetStep();
    expect(router.state.location.search).toBe('?step=pet');
    expect(within(main()).getByText('Step 1 of 3')).toBeTruthy();
    // The arrow goes back as the browser does.
    fireEvent.click(screen.getByRole('button', { name: 'Back' }));
    expect(await heading('Together with the family')).toBeTruthy();
    expect(router.state.location.search).toBe('?page=3');
    await act(() => router.navigate(-1));
    expect(await heading('The passport in a minute')).toBeTruthy();
    await act(() => router.navigate(1));
    expect(await heading('Together with the family')).toBeTruthy();
  });

  it('adds the pet and its feeding times with the right requests, then invites the family', async () => {
    const server = emptyHome();
    const { router } = renderApp('/welcome', { server });
    await toPetStep();
    // The family member's way: a code instead of a second pet.
    expect(within(main()).getByRole('link', { name: 'I was invited to a family' }).getAttribute('href')).toBe('/join');

    fireEvent.change(within(main()).getByLabelText('Name'), { target: { value: ' Barsik ' } });
    fireEvent.click(within(main()).getByRole('radio', { name: 'Dog' }));
    press('Save and continue');
    expect(await heading('Feeding times')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/pets').map((call) => call.body)).toMatchObject([
      { name: 'Barsik', species: 'Dog', sex: 'Unknown', status: null, identifiers: [] },
    ]);
    const barsik = server.world.households.get(HOME)!.pets[0]!;
    expect(within(main()).getByText('Barsik')).toBeTruthy();

    // Twice a day by default; one more time, then one less.
    const times = within(await within(main()).findByRole('group', { name: 'Times' }));
    expect(times.getByRole('button', { name: 'Remove 8:00 AM' })).toBeTruthy();
    fireEvent.change(times.getByLabelText('New time'), { target: { value: '13:30' } });
    fireEvent.click(times.getByRole('button', { name: 'Add time' }));
    fireEvent.click(times.getByRole('button', { name: 'Remove 7:00 PM' }));
    press('Save and continue');
    expect(await heading('Invite your family')).toBeTruthy();
    const sent = server.calls('POST', `/api/v1/pets/${barsik.id}/routines`)[0]!.body as Record<string, unknown>;
    expect(sent).toMatchObject({
      kind: 'Feeding',
      times: ['08:00:00', '13:30:00'],
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      food: null,
      supplyItemId: null,
    });
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);

    press('Invite');
    const dialog = within(await screen.findByRole('dialog', { name: 'Who are you inviting?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Create the code' }));
    expect(await dialog.findByText(/^[A-Z0-9]{4}-?[A-Z0-9]{4}$/)).toBeTruthy();
    fireEvent.click(dialog.getAllByRole('button', { name: 'Close' }).at(-1)!);
    expect(await within(main()).findByText('Invite created. The code works for 7 days.')).toBeTruthy();
    press('Done');
    await waitFor(() => expect(router.state.location.pathname).toBe('/'));
  });

  it("doesn't add the pet twice when the answer got lost: the pets are read again first", async () => {
    const server = emptyHome();
    // The server adds the pet, and the answer never comes back.
    server.respond(
      'POST',
      '/api/v1/pets',
      () => {
        server.world.households.get(HOME)!.pets.push(pet('pet-lost', 'Barsik'));
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp('/welcome?step=pet', { server });
    await heading('Who lives with you?');
    fireEvent.change(within(main()).getByLabelText('Name'), { target: { value: 'Barsik' } });
    press('Save and continue');
    // The failure is said, and the pets read again show the one added.
    expect(await within(main()).findByText(/^Can't reach the server/)).toBeTruthy();
    expect(await within(main()).findByText('Already here: Barsik')).toBeTruthy();
    expect(within(main()).queryByLabelText('Name')).toBeNull();
    press('Next');
    expect(await heading('Feeding times')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/pets')).toHaveLength(1);
  });

  it('reads the pets before trying again when even that failed, and adds nothing twice', async () => {
    const server = emptyHome();
    server.respond(
      'POST',
      '/api/v1/pets',
      () => {
        server.world.households.get(HOME)!.pets.push(pet('pet-lost', 'Barsik'));
        // The list can't be read right after either.
        server.respond(
          'GET',
          '/api/v1/pets',
          () => {
            throw new TypeError('Failed to fetch');
          },
          { once: true },
        );
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp('/welcome?step=pet', { server });
    await heading('Who lives with you?');
    fireEvent.change(await within(main()).findByLabelText('Name'), { target: { value: 'Barsik' } });
    press('Save and continue');
    expect(await within(main()).findByText(/Can't reach the server/)).toBeTruthy();
    // The list read again failed too: the form is still there, and pressing again reads the list first.
    await waitFor(() => expect(server.calls('GET', '/api/v1/pets').length).toBe(2));
    await waitFor(() =>
      expect(within(main()).getByRole('button', { name: 'Save and continue' })).toHaveProperty('disabled', false),
    );
    press('Save and continue');
    expect(await within(main()).findByText('Already here: Barsik')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/pets')).toHaveLength(1);
    expect(await heading('Who lives with you?')).toBeTruthy();
  });

  it('keeps the step with the reason when the save fails, and a refused name under the field', async () => {
    const server = emptyHome();
    server.respond('POST', '/api/v1/pets', () => problem(400, { errors: { name: ['Too long.'] } }), { once: true });
    renderApp('/welcome?step=pet', { server });
    await heading('Who lives with you?');
    press('Save and continue');
    // Nothing typed: said before anything is sent.
    expect(await within(main()).findByText("Enter the pet's name")).toBeTruthy();
    expect(server.calls('POST', '/api/v1/pets')).toHaveLength(0);
    fireEvent.change(within(main()).getByLabelText('Name'), { target: { value: 'Barsik' } });
    press('Save and continue');
    expect(await within(main()).findByText("This value wasn't accepted. Check it.")).toBeTruthy();
    expect(within(main()).getByText('Check the highlighted fields.')).toBeTruthy();
    expect(within(main()).getByLabelText('Name').getAttribute('aria-invalid')).toBe('true');
    expect(await heading('Who lives with you?')).toBeTruthy();
  });

  it('sends one request for a double press, and a double click never reaches the next step', async () => {
    const server = emptyHome();
    const { router } = renderApp('/welcome', { server });
    await heading('Reminders on time');
    const next = within(main()).getByRole('button', { name: 'Next' });
    fireEvent.click(next, { detail: 1 });
    await heading('The passport in a minute');
    // The second click of the double click lands on the next page's button: nothing.
    fireEvent.click(within(main()).getByRole('button', { name: 'Next' }), { detail: 2 });
    expect(router.state.location.search).toBe('?page=2');

    // The same for "Skip" and the arrow: the second click does nothing.
    fireEvent.click(screen.getByRole('button', { name: 'Skip' }), { detail: 1 });
    await heading('Who lives with you?');
    fireEvent.click(screen.getByRole('button', { name: 'Skip' }), { detail: 2 });
    expect(router.state.location.search).toBe('?step=pet');
    // Back goes where the browser's Back would: the page "Skip" left.
    fireEvent.click(screen.getByRole('button', { name: 'Back' }), { detail: 1 });
    await heading('The passport in a minute');
    fireEvent.click(screen.getByRole('button', { name: 'Back' }), { detail: 2 });
    expect(router.state.location.search).toBe('?page=2');

    await act(() => router.navigate('/welcome?step=pet'));
    fireEvent.change(await within(main()).findByLabelText('Name'), { target: { value: 'Barsik' } });
    const save = within(main()).getByRole('button', { name: 'Save and continue' });
    fireEvent.click(save);
    fireEvent.click(save);
    expect(await heading('Feeding times')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/pets')).toHaveLength(1);
  });

  it('moves nothing when the save ends after its household went away', async () => {
    const server = emptyHome();
    server.world.memberships = [HOME, OFFICE];
    let release!: () => void;
    const answered = new Promise<void>((resolve) => (release = resolve));
    server.respond(
      'POST',
      '/api/v1/pets',
      async () => {
        await answered;
        const created = pet('pet-luna', 'Luna');
        server.world.households.get(HOME)!.pets.push(created);
        return new Response(JSON.stringify(created), { status: 201, headers: { 'Content-Type': 'application/json' } });
      },
      { once: true },
    );
    const { router, queryClient } = renderApp('/welcome?step=pet', { server });
    await heading('Who lives with you?');
    fireEvent.change(within(main()).getByLabelText('Name'), { target: { value: 'Luna' } });
    press('Save and continue');
    await waitFor(() => expect(server.calls('POST', '/api/v1/pets')).toHaveLength(1));
    // Meanwhile Anna is removed from her household on another phone: Office is on screen, the onboarding starts again.
    server.world.memberships = [OFFICE];
    await act(async () => {
      await queryClient.invalidateQueries({ queryKey: ['households'] });
    });
    expect(await heading('Reminders on time')).toBeTruthy();
    await act(async () => release());
    await pause();
    expect(router.state.location.search).toBe('?step=pet');
    expect(await heading('Reminders on time')).toBeTruthy();
  });

  it('keeps one request id for the feeding across tries, so a retry adds nothing twice', async () => {
    const server = emptyHome();
    server.world.households.get(HOME)!.pets = [pet('pet-murka', 'Murka')];
    server.respond(
      'POST',
      '/api/v1/pets/pet-murka/routines',
      () => {
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp('/welcome?step=feeding', { server });
    await heading('Feeding times');
    expect(await within(main()).findByText('Murka')).toBeTruthy();
    press('Save and continue');
    expect(await within(main()).findByText(/Can't reach the server/)).toBeTruthy();
    expect(await heading('Feeding times')).toBeTruthy();
    await waitFor(() =>
      expect(within(main()).getByRole('button', { name: 'Save and continue' })).toHaveProperty('disabled', false),
    );
    press('Save and continue');
    expect(await heading('Invite your family')).toBeTruthy();
    const ids = server
      .calls('POST', '/api/v1/pets/pet-murka/routines')
      .map((call) => (call.body as { requestId: string }).requestId);
    expect(ids).toHaveLength(2);
    expect(ids[1]).toBe(ids[0]);
  });

  it('shows what is set up already: the pets here, a feeding schedule', async () => {
    renderApp('/welcome?step=pet');
    await heading('Who lives with you?');
    expect(await within(main()).findByText('Already here: Murka, Rex')).toBeTruthy();
    expect(within(main()).getByRole('link', { name: 'Add another' }).getAttribute('href')).toBe('/pets/new');
    press('Next');
    expect(await within(main()).findByText('Feeding is already set up')).toBeTruthy();
  });

  it('skips every step, and ends on Home', async () => {
    const server = emptyHome();
    const { router } = renderApp('/welcome', { server });
    await heading('Reminders on time');
    press('Skip');
    expect(await heading('Who lives with you?')).toBeTruthy();
    press('Skip');
    expect(await heading('Feeding times')).toBeTruthy();
    // No pet: nothing to feed, said so.
    expect(within(main()).getByText(/Feeding is set up for a pet/)).toBeTruthy();
    press('Skip');
    expect(await heading('Invite your family')).toBeTruthy();
    press('Skip');
    await waitFor(() => expect(router.state.location.pathname).toBe('/'));
    // Home in the onboarding's place.
    expect(router.state.historyAction).toBe('REPLACE');
    expect(server.calls('POST', /.*/).filter((call) => !call.path.startsWith('/api/v1/live'))).toEqual([]);
  });

  it('shows helpers only the pages: "Start" ends it', async () => {
    asHelper();
    const { router } = renderApp('/welcome?page=3');
    await heading('Together with the family');
    press('Start');
    await waitFor(() => expect(router.state.location.pathname).toBe('/'));
    // A step's address doesn't open a step for them either.
    await act(() => router.navigate('/welcome?step=pet'));
    expect(await heading('Reminders on time')).toBeTruthy();
  });

  it('has the family step only for owners: a member ends after the feeding', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Member';
    const { router } = renderApp('/welcome?step=feeding', { server });
    await heading('Feeding times');
    expect(within(main()).getByText('Step 2 of 2')).toBeTruthy();
    expect(await within(main()).findByText('Feeding is already set up')).toBeTruthy();
    press('Done');
    await waitFor(() => expect(router.state.location.pathname).toBe('/'));
  });

  it('asks before leaving with a name typed and not saved', async () => {
    const { router } = renderApp('/welcome?step=pet', { server: emptyHome() });
    await heading('Who lives with you?');
    fireEvent.change(await within(main()).findByLabelText('Name'), { target: { value: 'Barsik' } });
    fireEvent.click(within(screen.getByRole('navigation', { name: 'Sections' })).getByRole('link', { name: 'Pets' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Cancel' }));
    expect(router.state.location.pathname).toBe('/welcome');
    expect(within(main()).getByLabelText('Name')).toHaveProperty('value', 'Barsik');
  });
});
