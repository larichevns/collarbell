// The Passport tab: the note that the copy is for information, the details and their form, the pages (dropped,
// several at once, viewed large, deleted after asking) and the health sections V–X.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { PassportRequest } from '../../api/types';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, MURKA, REX } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));
const photo = (name: string) => new File([new Uint8Array(500)], name, { type: 'image/jpeg' });

describe('the Passport tab', () => {
  it('shows the note, the details, the microchip, the pages and the health sections', async () => {
    renderApp(`/pets/${MURKA}/passport`);
    expect(
      await screen.findByText(
        'This digital copy is for your information. The paper passport stays the official document.',
      ),
    ).toBeTruthy();
    const details = await region('Passport details');
    expect(await details.findByText('RU0123456')).toBeTruthy();
    expect(details.getByText('EU passport (2014 model)')).toBeTruthy();
    expect(details.getByText(/Vet\+, Lenina 1/)).toBeTruthy();
    expect((await region('Microchips and tattoos')).getByText('643 094 100 000 001')).toBeTruthy();
    const pages = await region('Pages');
    expect(await pages.findByRole('button', { name: 'Passport page 1' })).toBeTruthy();
    expect(pages.getByRole('button', { name: 'Passport page 2' })).toBeTruthy();

    const rabies = await region('V. Rabies vaccination');
    expect(await rabies.findByRole('link', { name: 'Nobivac Rabies · Batch A123' })).toBeTruthy();
    expect(rabies.getByText(/^Valid .+ – .+$/)).toBeTruthy();
    // Treatments say their kind: the section mixes worms, fleas and heartworm.
    expect((await region('VIII. Other parasite treatments')).getByText('Deworming · Milbemax')).toBeTruthy();
    expect((await region('X. Clinical examination')).getByText('Fit to travel · Vet+')).toBeTruthy();
    expect((await region('VI. Rabies antibody test')).getByText('No entries yet.')).toBeTruthy();
    // "Add" in a section opens the record form with its kind.
    expect(rabies.getByRole('link', { name: 'Add' }).getAttribute('href')).toBe(
      `/pets/${MURKA}/records/new?kind=Vaccination&target=Rabies&from=passport`,
    );
    expect(screen.getByRole('link', { name: 'Enter from the passport' }).getAttribute('href')).toBe(
      `/pets/${MURKA}/records/import`,
    );
  });

  it("adds pages dropped onto the passport, several at once, to the end of its pages' document", async () => {
    const { server } = renderApp(`/pets/${MURKA}/passport`);
    const pages = await region('Pages');
    await pages.findByRole('button', { name: 'Passport page 2' });
    fireEvent.drop(document.querySelector('.file-drop') as HTMLElement, {
      dataTransfer: { files: [photo('page-3.jpg'), photo('page-4.jpg')], types: ['Files'] },
    });
    await waitFor(() => expect(server.calls('POST', '/api/v1/documents/doc-passport/pages')).toHaveLength(1));
    const uploaded = server.calls('POST', '/api/v1/files');
    expect(uploaded).toHaveLength(2);
    expect(
      (server.calls('POST', '/api/v1/documents/doc-passport/pages')[0]!.body as { fileIds: string[] }).fileIds,
    ).toHaveLength(2);
    expect(await pages.findByRole('button', { name: 'Passport page 4' })).toBeTruthy();
  });

  it("starts the pages' document of a pet that has none", async () => {
    const { server } = renderApp(`/pets/${REX}/passport`);
    const pages = await region('Pages');
    expect(
      await pages.findByText("Add photos or scans of the paper passport's pages to keep a copy at hand."),
    ).toBeTruthy();
    fireEvent.drop(document.querySelector('.file-drop') as HTMLElement, {
      dataTransfer: { files: [photo('page-1.jpg')], types: ['Files'] },
    });
    await waitFor(() => expect(server.calls('POST', `/api/v1/pets/${REX}/documents`)).toHaveLength(1));
    expect(server.calls('POST', `/api/v1/pets/${REX}/documents`)[0]!.body).toMatchObject({
      type: 'PassportPage',
      title: null,
    });
    expect(await pages.findByRole('button', { name: 'Passport page 1' })).toBeTruthy();
  });

  it('views the pages large, turns them with the arrow keys, and deletes one after asking', async () => {
    const { server } = renderApp(`/pets/${MURKA}/passport`);
    fireEvent.click(await (await region('Pages')).findByRole('button', { name: 'Passport page 1' }));
    const viewer = await screen.findByRole('dialog', { name: 'Page 1 of 2' });
    fireEvent.keyDown(viewer, { key: 'ArrowRight' });
    expect(await screen.findByRole('dialog', { name: 'Page 2 of 2' })).toBeTruthy();
    expect((within(viewer).getByRole('img', { name: 'Page 2' }) as HTMLImageElement).src).toContain('file-page-2');
    fireEvent.click(within(viewer).getByRole('button', { name: 'Delete page' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Delete this page?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Delete' }));
    await waitFor(() =>
      expect(server.calls('DELETE', '/api/v1/documents/doc-passport/pages/file-page-2')).toHaveLength(1),
    );
    // The page before takes its place.
    expect(await screen.findByRole('dialog', { name: 'Page 1 of 1' })).toBeTruthy();
  });

  it('a helper reads the passport and changes nothing', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Helper';
    renderApp(`/pets/${MURKA}/passport`, { server });
    expect(await (await region('Passport details')).findByText('RU0123456')).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Edit' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Add pages' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Add' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Remove page 1' })).toBeNull();
  });
});

describe('the passport form', () => {
  it('checks the number and the country as the server does, and saves the details with two owners', async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/passport/edit`);
    expect(await screen.findByLabelText('Passport number')).toHaveProperty('value', 'RU0123456');
    fireEvent.change(screen.getByLabelText('Passport number'), { target: { value: 'de 12-34/5' } });
    fireEvent.change(screen.getByLabelText('Issuing country'), { target: { value: 'Deu' } });
    expect(await screen.findByText('Use the two-letter country code, such as DE or FR')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Issuing country'), { target: { value: 'de' } });
    fireEvent.change(screen.getByLabelText('Passport model'), { target: { value: 'Eu2026' } });
    fireEvent.click(screen.getByRole('button', { name: 'Add owner' }));
    const second = within(screen.getByRole('group', { name: 'Owner 2' }));
    fireEvent.change(second.getByLabelText('Name'), { target: { value: 'Boris' } });
    fireEvent.change(second.getByLabelText('Email'), { target: { value: 'boris' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Enter an email like name@example.com')).toBeTruthy();
    fireEvent.change(second.getByLabelText('Email'), { target: { value: 'boris@example.com' } });
    // Two owners at most, as in the paper passport.
    expect(screen.queryByRole('button', { name: 'Add owner' })).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/passport`));
    const sent = server.calls('PUT', `/api/v1/pets/${MURKA}/passport`)[0]!.body as PassportRequest;
    expect(sent).toMatchObject({
      model: 'Eu2026',
      passportNumber: 'DE12-34/5',
      issuingCountry: 'DE',
      issuer: { name: 'Dr. Petrova', address: 'Vet+, Lenina 1', phone: null, email: null },
    });
    expect(sent.owners).toEqual([
      { name: 'Anna', address: null, phone: '+7 900 000-00-00', email: 'anna@example.com' },
      { name: 'Boris', address: null, phone: null, email: 'boris@example.com' },
    ]);
    expect(await (await region('Passport details')).findByText('DE12-34/5')).toBeTruthy();
  });

  it('asks before leaving with typed input', async () => {
    const { router } = renderApp(`/pets/${REX}/passport/edit`);
    fireEvent.change(await screen.findByLabelText('Passport number'), { target: { value: 'X1' } });
    fireEvent.click(screen.getByRole('link', { name: 'Pets' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Cancel' }));
    expect(router.state.location.pathname).toBe(`/pets/${REX}/passport/edit`);
  });
});

// --- Review of part 2: the e-mail rule, uploads in progress, the focus when an owner goes ---

describe('the passport and what happens meanwhile (review of part 2)', () => {
  it("saves a passport whose e-mail the server took: like the phone, it only asks for an '@'", async () => {
    const server = createTestServer();
    const passport = server.world.households.get(HOME)!.passports.get(MURKA)!;
    passport.issuer = { name: 'Dr. Petrova', address: null, phone: null, email: 'petrova@vetclinic' };
    renderApp(`/pets/${MURKA}/passport/edit`, { server });
    fireEvent.change(await screen.findByLabelText('Notes'), { target: { value: 'Microchip read at the border.' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('PUT', `/api/v1/pets/${MURKA}/passport`)).toHaveLength(1));
  });

  it('asks before the tab is closed while dropped pages are still uploading', async () => {
    const server = createTestServer();
    server.respond('POST', '/api/v1/files', () => new Promise<undefined>(() => {}));
    renderApp(`/pets/${MURKA}/passport`, { server });
    await region('Pages');
    const zone = (await screen.findByRole('button', { name: 'Add pages' })).closest('.file-drop') as HTMLElement;
    fireEvent.drop(zone, { dataTransfer: { files: [photo('page-3.jpg')], types: ['Files'] } });
    expect(await screen.findByText('Uploading 1 of 1…')).toBeTruthy();
    const unload = new Event('beforeunload', { cancelable: true });
    window.dispatchEvent(unload);
    expect(unload.defaultPrevented).toBe(true);
  });

  it('another tab waits for an upload; when it fails, leaving asks and "Upload again" stays', async () => {
    const server = createTestServer();
    let release: () => void = () => {};
    const gate = new Promise<void>((resolve) => (release = resolve));
    server.respond('POST', '/api/v1/files', async () => {
      await gate;
      return undefined;
    });
    server.respond('POST', '/api/v1/documents/doc-passport/pages', () => {
      throw new TypeError('Failed to fetch');
    });
    const { router } = renderApp(`/pets/${MURKA}/passport`, { server });
    await region('Pages');
    const zone = (await screen.findByRole('button', { name: 'Add pages' })).closest('.file-drop') as HTMLElement;
    fireEvent.drop(zone, { dataTransfer: { files: [photo('page-3.jpg')], types: ['Files'] } });
    expect(await screen.findByText('Uploading 1 of 1…')).toBeTruthy();
    // The Documents tab meanwhile: the move waits for the upload, without a question.
    fireEvent.click(screen.getByRole('tab', { name: 'Documents' }));
    await new Promise((resolve) => setTimeout(resolve, 30));
    expect(router.state.location.pathname).toBe(`/pets/${MURKA}/passport`);
    expect(screen.queryByRole('dialog', { name: 'Leave without saving?' })).toBeNull();
    await act(async () => {
      release();
      await gate;
    });
    // The page couldn't be added: leaving would lose it, so the frame asks; the person stays.
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Cancel' }));
    expect(router.state.location.pathname).toBe(`/pets/${MURKA}/passport`);
    expect(screen.getByRole('button', { name: 'Upload again' })).toBeTruthy();
  });

  it('a removed owner hands the focus to the owner now in their place, then to "Add owner"', async () => {
    renderApp(`/pets/${MURKA}/passport/edit`);
    const remove = await screen.findByRole('button', { name: 'Remove owner 1' });
    remove.focus();
    fireEvent.click(remove);
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Remove owner 1' })).toBeNull());
    expect(window.document.activeElement).toBe(screen.getByRole('button', { name: 'Add owner' }));
  });
});
