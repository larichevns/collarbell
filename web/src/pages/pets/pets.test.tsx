// Pets: the list, a pet's page with its photo, the form with its checks and the server's, and deleting.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { FileLink, Pet } from '../../api/types';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, MURKA, OFFICE, problem, REX } from '../../test/server';

const photo = (type = 'image/jpeg', size = 1000) => new File([new Uint8Array(size)], 'murka.jpg', { type });

describe('the pets list', () => {
  it('shows each pet with species, breed and age, the archived ones last and quieter', async () => {
    renderApp('/pets');
    const murka = (await screen.findByRole('link', { name: 'Murka' })).closest('li') as HTMLElement;
    expect(within(murka).getByText('Cat · Siberian')).toBeTruthy();
    expect(within(murka).getByText('3 years')).toBeTruthy();
    const names = screen.getAllByRole('link', { name: /^(Murka|Rex|Tom)$/ }).map((link) => link.textContent);
    expect(names).toEqual(['Murka', 'Rex', 'Tom']);
    const tom = screen.getByRole('link', { name: 'Tom' }).closest('li') as HTMLElement;
    expect(within(tom).getByText('Archived')).toBeTruthy();
    expect(tom.className).toContain('pet-card--inactive');
  });
});

describe("a pet's page", () => {
  it('shows the details and the microchip, with the other sections as tabs', async () => {
    renderApp(`/pets/${MURKA}`);
    expect(await screen.findByRole('heading', { name: 'Murka', level: 1 })).toBeTruthy();
    const details = within(screen.getByRole('region', { name: 'Details' }));
    expect(details.getByText('Siberian')).toBeTruthy();
    expect(details.getByText('Female')).toBeTruthy();
    // Pets have no colour in the app any more: the API's coat isn't shown.
    expect(details.queryByText('Ginger')).toBeNull();
    const chips = within(screen.getByRole('region', { name: 'Microchips and tattoos' }));
    expect(chips.getByText('643 094 100 000 001')).toBeTruthy();
    expect(chips.getByText('Left side of the neck')).toBeTruthy();
    expect(screen.getByRole('tab', { name: 'Overview' }).getAttribute('aria-selected')).toBe('true');
    const health = screen.getByRole('tab', { name: 'Health' });
    expect(health.getAttribute('aria-selected')).toBe('false');
    expect(health.getAttribute('href')).toBe(`/pets/${MURKA}/health`);
    expect(screen.getAllByRole('tab').map((tab) => tab.textContent)).toEqual([
      'Overview',
      'Health',
      'Passport',
      'Documents',
      'Feeding',
      'Weight',
    ]);
  });

  it("takes a photo dropped onto it: uploads it, then makes it the pet's photo", async () => {
    const { server } = renderApp(`/pets/${MURKA}`);
    await screen.findByRole('heading', { name: 'Murka', level: 1 });
    const zone = document.querySelector('.photo-drop') as HTMLElement;
    fireEvent.drop(zone, { dataTransfer: { files: [photo()], types: ['Files'] } });
    await waitFor(() => expect(server.calls('PUT', `/api/v1/pets/${MURKA}/photo`)).toHaveLength(1));
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(1);
    const fileId = (server.calls('PUT', `/api/v1/pets/${MURKA}/photo`)[0]!.body as { fileId: string }).fileId;
    // The page shows the new photo once the pet is read again.
    await waitFor(() => expect(document.querySelector('.photo-drop img')?.getAttribute('src')).toContain(fileId));
    expect(screen.getByRole('button', { name: 'Change photo' })).toBeTruthy();
  });

  it('says why a dropped file is not taken, before uploading it', async () => {
    const { server } = renderApp(`/pets/${MURKA}`);
    await screen.findByRole('heading', { name: 'Murka', level: 1 });
    const zone = document.querySelector('.photo-drop') as HTMLElement;
    fireEvent.drop(zone, { dataTransfer: { files: [photo('image/heic')], types: ['Files'] } });
    expect(await screen.findByText("This file type isn't supported. Use a JPEG, PNG or WebP photo.")).toBeTruthy();
    fireEvent.drop(zone, { dataTransfer: { files: [photo('image/png', 16 * 1024 * 1024)], types: ['Files'] } });
    expect(await screen.findByText('This file is too large. Upload files up to 15 MB.')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(0);
  });

  it('deletes a pet after asking', async () => {
    const { server, router } = renderApp(`/pets/${REX}`);
    fireEvent.click(await screen.findByRole('button', { name: 'Delete pet' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete Rex?' }));
    expect(dialog.getByText(/also deletes the passport details/)).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/pets'));
    expect(server.calls('DELETE', `/api/v1/pets/${REX}`)).toHaveLength(1);
    await waitFor(() => expect(screen.queryByRole('link', { name: 'Rex' })).toBeNull());
  });
});

describe('the pet form', () => {
  it('checks what it can before sending anything', async () => {
    const { server } = renderApp('/pets/new');
    fireEvent.click(await screen.findByRole('button', { name: 'Add a microchip or tattoo' }));
    fireEvent.change(screen.getByLabelText('Chip number'), { target: { value: '643 094 100 000' } });
    expect(await screen.findByText('An ISO microchip number has 15 digits')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("Enter the pet's name")).toBeTruthy();
    expect(screen.getByText('Check the highlighted fields.')).toBeTruthy();
    expect(screen.getByLabelText('Name').getAttribute('aria-invalid')).toBe('true');
    // The first field with a mistake has the focus.
    expect(document.activeElement).toBe(screen.getByLabelText('Name'));
    expect(server.calls('POST', '/api/v1/pets')).toHaveLength(0);
  });

  it('a removed microchip hands the focus to the card now in its place, then to "Add"', async () => {
    renderApp('/pets/new');
    const add = await screen.findByRole('button', { name: 'Add a microchip or tattoo' });
    fireEvent.click(add);
    fireEvent.click(add);
    const removes = () => screen.getAllByRole('button', { name: 'Remove from the list' });
    expect(removes()).toHaveLength(2);
    removes()[0]!.focus();
    fireEvent.click(removes()[0]!);
    await waitFor(() => expect(removes()).toHaveLength(1));
    await waitFor(() => expect(document.activeElement).toBe(removes()[0]));
    fireEvent.click(removes()[0]!);
    await waitFor(() => expect(document.activeElement).toBe(add));
  });

  it('adds a pet with a microchip and a photo, and opens its page', async () => {
    const { server, router } = renderApp('/pets/new');
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: '  Luna ' } });
    fireEvent.click(screen.getByRole('radio', { name: 'Dog' }));
    fireEvent.click(screen.getByRole('radio', { name: 'Female' }));
    fireEvent.change(screen.getByLabelText('Date of birth'), { target: { value: '2024-03-01' } });
    fireEvent.click(screen.getByLabelText('The date is approximate'));
    fireEvent.click(screen.getByRole('button', { name: 'Add a microchip or tattoo' }));
    fireEvent.change(screen.getByLabelText('Chip number'), { target: { value: '276 098 100 123 456' } });
    fireEvent.drop(document.querySelector('.photo-drop') as HTMLElement, {
      dataTransfer: { files: [photo()], types: ['Files'] },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/pets\/[0-9a-f-]{36}$/));
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(1);
    expect(server.calls('POST', '/api/v1/pets')[0]!.body).toMatchObject({
      name: 'Luna',
      species: 'Dog',
      sex: 'Female',
      birthDate: '2024-03-01',
      birthDateApproximate: true,
      // Pets have no colour in the app: the server picks the API's coat.
      coat: null,
      neutered: null,
      status: null,
      identifiers: [{ type: 'IsoChip', code: '276 098 100 123 456', appliedOn: null, location: null, readOn: null }],
    });
    expect(server.calls('PUT', /^\/api\/v1\/pets\/[^/]+\/photo$/)).toHaveLength(1);
    expect(await screen.findByRole('heading', { name: 'Luna', level: 1 })).toBeTruthy();
  });

  it("shows the server's refusals under their fields, the microchip's too", async () => {
    const server = createTestServer();
    server.respond('PUT', `/api/v1/pets/${MURKA}`, () =>
      problem(400, {
        errors: { name: ['Too long.'], 'identifiers[0].code': ['Not a valid ISO chip.'] },
      }),
    );
    renderApp(`/pets/${MURKA}/edit`, { server });
    expect(await screen.findByLabelText('Name')).toHaveProperty('value', 'Murka');
    expect(screen.getByLabelText('Chip number')).toHaveProperty('value', '643 094 100 000 001');
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Check the highlighted fields.')).toBeTruthy();
    expect(screen.getByLabelText('Name').getAttribute('aria-invalid')).toBe('true');
    expect(screen.getByLabelText('Chip number').getAttribute('aria-invalid')).toBe('true');
    expect(screen.getAllByText("This value wasn't accepted. Check it.")).toHaveLength(2);
  });

  it('asks before leaving with typed input', async () => {
    const { router } = renderApp(`/pets/${MURKA}/edit`);
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Murka II' } });
    fireEvent.click(screen.getByRole('link', { name: 'Today' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Cancel' }));
    expect(router.state.location.pathname).toBe(`/pets/${MURKA}/edit`);

    fireEvent.click(screen.getByRole('link', { name: 'Today' }));
    const again = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(again.getByRole('button', { name: 'Leave' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/today'));
  });
});

// --- Review of part 1 (P1, P3, P9): saves that end after a move, deleted pets, a photo that couldn't be removed ---

const NOT_FOUND = "This wasn't found. It may have been deleted.";
const picker = () => within(screen.getByRole('banner')).getByLabelText('Group') as HTMLSelectElement;
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

function hold() {
  let release!: () => void;
  const promise = new Promise<void>((resolve) => (release = resolve));
  return { promise, release };
}

/** A new pet "Luna" whose save waits until released. */
function slowNewPet() {
  const server = createTestServer();
  const home = server.world.households.get(HOME)!;
  const wait = hold();
  const LUNA = 'bbbbbbbb-0000-4000-8000-000000000009';
  server.respond(
    'POST',
    '/api/v1/pets',
    async () => {
      await wait.promise;
      const created: Pet = { ...home.pets[1]!, id: LUNA, name: 'Luna', identifiers: [] };
      home.pets.push(created);
      return json(201, created);
    },
    { once: true },
  );
  return { server, wait, LUNA };
}

describe('a pet saving while the person moves (review P1)', () => {
  it('holds a group switch until the new pet is saved, then opens it in the group it was saved to', async () => {
    const { server, wait, LUNA } = slowNewPet();
    const { router } = renderApp('/pets/new', { server });
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Luna' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/pets')).toHaveLength(1));
    expect(server.calls('POST', '/api/v1/pets')[0]!.household).toBe(HOME);

    // While it saves, "Office" is picked in the sidebar: the move waits for the save.
    fireEvent.change(picker(), { target: { value: OFFICE } });
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 30));
    });
    expect(picker().value).toBe(HOME);
    expect(screen.queryByText('Barsik')).toBeNull();

    await act(async () => wait.release());
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${LUNA}`));
    expect(await screen.findByRole('heading', { name: 'Luna', level: 1 })).toBeTruthy();
    expect(server.calls('GET', `/api/v1/pets/${LUNA}`).map((call) => call.household)).not.toContain(OFFICE);
    expect(screen.queryByText(NOT_FOUND)).toBeNull();
  });

  it('opens nothing in another group when its own went away during the save', async () => {
    const { server, wait, LUNA } = slowNewPet();
    const { router, queryClient } = renderApp('/pets/new', { server });
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Luna' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/pets')).toHaveLength(1));

    // Meanwhile Anna is removed from Home on another phone, and the app learns it.
    server.world.memberships = [OFFICE];
    await act(async () => {
      await queryClient.invalidateQueries({ queryKey: ['households'] });
    });
    expect(await screen.findByText('Barsik')).toBeTruthy();

    await act(async () => wait.release());
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 50));
    });
    expect(router.state.location.pathname).toBe('/pets');
    expect(server.calls('GET', `/api/v1/pets/${LUNA}`)).toHaveLength(0);
    expect(screen.queryByText(NOT_FOUND)).toBeNull();
  });
});

describe('a deleted pet (review P3)', () => {
  it('does not come back, alive and editable, on Back', async () => {
    const { router, server } = renderApp(`/pets/${REX}`);
    fireEvent.click(await screen.findByRole('button', { name: 'Delete pet' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete Rex?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/pets'));

    await act(async () => {
      await router.navigate(-1);
    });
    await waitFor(() => expect(server.calls('GET', `/api/v1/pets/${REX}`).length).toBeGreaterThanOrEqual(2));
    expect(await screen.findByText(NOT_FOUND)).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Delete pet' })).toBeNull();
  });

  it('a pet deleted on another phone is not edited from an old copy', async () => {
    const server = createTestServer();
    const { router } = renderApp(`/pets/${REX}`, { server });
    expect(await screen.findByRole('heading', { name: 'Rex', level: 1 })).toBeTruthy();
    const home = server.world.households.get(HOME)!;
    home.pets = home.pets.filter((item) => item.id !== REX);
    await act(async () => {
      await router.navigate(`/pets/${REX}/edit`);
    });
    expect(await screen.findByText(NOT_FOUND)).toBeTruthy();
    expect(screen.queryByLabelText('Name')).toBeNull();
  });
});

describe('the words of a failed photo removal (review P9)', () => {
  it('says the photo could not be removed, not that it could not be uploaded', async () => {
    const server = createTestServer();
    const photo: FileLink = {
      id: 'f1',
      contentType: 'image/jpeg',
      sizeBytes: 1,
      width: 1,
      height: 1,
      url: 'https://files.example/f1',
      thumbnailUrl: 'https://files.example/f1/small',
      expiresAt: new Date(Date.now() + 900_000).toISOString(),
    };
    server.world.households.get(HOME)!.pets[0]!.photo = photo;
    server.respond('DELETE', `/api/v1/pets/${MURKA}/photo`, () => problem(500), { once: true });
    renderApp(`/pets/${MURKA}/edit`, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Remove photo' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(
      await screen.findByText("The pet is saved, but the photo couldn't be removed. Try again on the pet's page."),
    ).toBeTruthy();
  });
});

describe('the frame (review)', () => {
  it('ignores a file dropped outside a drop zone, rather than letting the browser open it', async () => {
    renderApp(`/pets/${MURKA}`);
    await screen.findByRole('heading', { name: 'Murka', level: 1 });
    const event = new Event('drop', { bubbles: true, cancelable: true });
    Object.defineProperty(event, 'dataTransfer', { value: { types: ['Files'], files: [] } });
    screen.getByRole('heading', { name: 'Murka', level: 1 }).dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
  });

  it('gives each page its own title', async () => {
    const { router } = renderApp(`/pets/${MURKA}`);
    await screen.findByRole('heading', { name: 'Murka', level: 1 });
    expect(document.title).toBe('Murka · Collarbell');
    await act(async () => {
      await router.navigate('/visits');
    });
    await waitFor(() => expect(document.title).toBe('Visits · Collarbell'));
  });
});

describe("the pet's tabs", () => {
  it('move with the arrow keys, Home and End, and open with Enter', async () => {
    const { router } = renderApp(`/pets/${MURKA}`);
    const overview = await screen.findByRole('tab', { name: 'Overview' });
    // Only the open tab is in the Tab order.
    expect(overview.getAttribute('tabindex')).toBe('0');
    expect(screen.getByRole('tab', { name: 'Health' }).getAttribute('tabindex')).toBe('-1');
    overview.focus();
    fireEvent.keyDown(overview, { key: 'ArrowRight' });
    expect(document.activeElement).toBe(screen.getByRole('tab', { name: 'Health' }));
    fireEvent.keyDown(document.activeElement!, { key: 'End' });
    expect(document.activeElement).toBe(screen.getByRole('tab', { name: 'Weight' }));
    fireEvent.keyDown(document.activeElement!, { key: 'ArrowRight' });
    expect(document.activeElement).toBe(screen.getByRole('tab', { name: 'Overview' }));
    fireEvent.keyDown(document.activeElement!, { key: 'ArrowLeft' });
    fireEvent.click(document.activeElement!);
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/weight`));
    expect(screen.getByRole('tab', { name: 'Weight' }).getAttribute('aria-selected')).toBe('true');
    expect(screen.getByRole('tabpanel', { name: 'Weight' })).toBeTruthy();
  });
});
