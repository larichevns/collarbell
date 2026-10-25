// "Fill from photos" in the new item's form: photos of the package go up and to AI (POST /products/scan, with the
// barcode typed), and what it reads fills the form: the name, brand, kind, size and energy. What "Find" found for the
// barcode stays first (Open Pet Food Facts' data keeps its source; the photos fill in the rest); a medicine's package
// lasts as long as its doses protect; AI busy, not set up, or out of the month's photos is said in the dialog. A
// barcode typed by hand works as before. Not when changing an item, nor without AI.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { SupplyRequest } from '../../api/types';
import { productDraft } from '../../test/ai';
import { slowHeic, type SlowHeic } from '../../test/heic';
import { renderApp } from '../../test/render';
import { aiStatus, createTestServer, HOME, problem } from '../../test/server';

const SCAN = '/api/v1/products/scan';
const photo = (name: string) => new File([new Uint8Array(500)], name, { type: 'image/jpeg' });

/** Opens "Fill from photos", drops `files` in it and reads them. */
async function readPhotos(files: File[]) {
  fireEvent.click(await screen.findByRole('button', { name: 'Fill from photos' }));
  const dialogElement = await screen.findByRole('dialog', { name: 'Fill from photos of the package' });
  const dialog = within(dialogElement);
  fireEvent.drop(dialogElement.querySelector('.file-drop')!, { dataTransfer: { files, types: ['Files'] } });
  await dialog.findByRole('img', { name: `Photo ${files.length}: ${files.at(-1)!.name}` });
  fireEvent.click(dialog.getByRole('button', { name: 'Read' }));
  return dialog;
}

describe('filling a new item from photos of its package', () => {
  it('reads the photos and fills in the name, brand, kind, size and energy; the item is saved as read by AI', async () => {
    const { server, router } = renderApp('/supplies/new');
    const dialog = await readPhotos([photo('front.jpg'), photo('side.jpg')]);
    expect(dialog.getByText('Add photos of the front and of the side with the weight and composition, up to 3.')).toBeTruthy();
    expect(dialog.getByText("The photos go to Gemini's free tier: keep personal data out of them.")).toBeTruthy();
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(2);
    expect(server.calls('POST', SCAN)[0]!.body).toEqual({ fileIds: expect.any(Array), barcode: null });
    expect(screen.getByLabelText('Name')).toHaveProperty('value', 'Brit Care Cat Sterilised');
    expect(screen.getByLabelText('Brand')).toHaveProperty('value', 'Brit');
    expect(screen.getByRole('radio', { name: 'Dry food' })).toHaveProperty('checked', true);
    expect(screen.getByLabelText('Package size')).toHaveProperty('value', '1.5');
    expect(screen.getByLabelText('Unit')).toHaveProperty('value', 'kilogram');
    expect(screen.getByLabelText('Energy, kcal/kg')).toHaveProperty('value', '3650');
    expect(screen.getByText('Read from photos of the package. Check the details.')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/supplies\/[^/]+$/));
    const sent = server.calls('POST', '/api/v1/supplies')[0]!.body as SupplyRequest;
    expect(sent).toMatchObject({ name: 'Brit Care Cat Sterilised', packageSize: 1500, unit: 'Gram', kcalPerKg: 3650, dataSource: 'Ai' });
  });

  it("keeps what \"Find\" found first, with the barcode sent along; Open Pet Food Facts' data keeps its source", async () => {
    const server = createTestServer();
    server.world.productDraft = productDraft({ name: 'Purina ONE', brand: null, packageSize: 1500, kcalPerKg: 3600 });
    const { router } = renderApp('/supplies/new', { server });
    fireEvent.change(await screen.findByLabelText('Barcode'), { target: { value: '5901234123457' } });
    fireEvent.click(screen.getByRole('button', { name: 'Find' }));
    await waitFor(() => expect(screen.getByLabelText('Name')).toHaveProperty('value', 'Purina One Sterilcat'));
    await readPhotos([photo('front.jpg')]);
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect((server.calls('POST', SCAN)[0]!.body as { barcode: string }).barcode).toBe('5901234123457');
    // The database's name and energy, as on the shelf.
    expect(screen.getByLabelText('Name')).toHaveProperty('value', 'Purina One Sterilcat');
    expect(screen.getByLabelText('Energy, kcal/kg')).toHaveProperty('value', '3800');
    expect(screen.getByText('Details from Open Pet Food Facts (ODbL licence). Check them.')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/supplies\/[^/]+$/));
    expect((server.calls('POST', '/api/v1/supplies')[0]!.body as SupplyRequest).dataSource).toBe('OpenPetFoodFacts');
  });

  it("a medicine's package lasts as long as its doses protect; a photo that is no pet product is said so", async () => {
    const server = createTestServer();
    server.world.productDraft = productDraft({
      isPetProduct: false,
      name: 'Bravecto',
      brand: 'MSD',
      category: 'Medication',
      unit: 'Dose',
      packageSize: 2,
      kcalPerKg: null,
      treatment: 'FleaTick',
      protectionWeeks: 12,
    });
    renderApp('/supplies/new', { server });
    await readPhotos([photo('box.jpg')]);
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(screen.getByText("The photos don't seem to show a pet product. Check the details.")).toBeTruthy();
    expect(screen.getByRole('radio', { name: 'Medicine' })).toHaveProperty('checked', true);
    expect(screen.getByRole('radio', { name: 'A package lasts' })).toHaveProperty('checked', true);
    // Two doses of twelve weeks each: 168 days.
    expect(screen.getByLabelText('Days one package lasts')).toHaveProperty('value', '168');
  });

  it.each([
    [() => problem(503, { title: 'Busy' }), 'AI is busy right now. Try again in a minute, or fill it in by hand.', true],
    [() => problem(409, { title: "AI isn't set up." }), "AI isn't set up: fill in the details by hand.", false],
    [() => problem(502, { title: 'Refused' }), 'AI refused to read the photos. Fill in the details by hand.', false],
  ])('says why the photos were not read, and offers "Try again" when it can help (%#)', async (answer, words, again) => {
    const server = createTestServer();
    server.respond('POST', SCAN, answer, { once: true });
    renderApp('/supplies/new', { server });
    const dialog = await readPhotos([photo('front.jpg')]);
    expect(await dialog.findByText(words)).toBeTruthy();
    const button = dialog.getByRole('button', { name: again ? 'Try again' : 'Read' });
    expect(button).toHaveProperty('disabled', !again);
    if (again) {
      fireEvent.click(button);
      await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
      // The photo went up once.
      expect(server.calls('POST', '/api/v1/files')).toHaveLength(1);
    }
  });

  it("the month's AI photos: said with the count, and the plan", async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.plan.aiPhotosUsed = 20;
    renderApp('/supplies/new', { server });
    const dialog = await readPhotos([photo('front.jpg')]);
    expect(await dialog.findByText(/^AI has read 20 of 20 photos this month/)).toBeTruthy();
    expect(dialog.getByRole('link', { name: 'See the plan' })).toBeTruthy();
  });

  it('takes 3 photos at most', async () => {
    renderApp('/supplies/new');
    fireEvent.click(await screen.findByRole('button', { name: 'Fill from photos' }));
    const dialogElement = await screen.findByRole('dialog', { name: 'Fill from photos of the package' });
    fireEvent.drop(dialogElement.querySelector('.file-drop')!, {
      dataTransfer: { files: ['a', 'b', 'c', 'd'].map((name) => photo(`${name}.jpg`)), types: ['Files'] },
    });
    const dialog = within(dialogElement);
    expect(await dialog.findByText('Use 3 photos or fewer: the first 3 are taken.')).toBeTruthy();
    expect(dialog.getAllByRole('img')).toHaveLength(3);
  });

  it('is offered only when adding an item, and only with AI', async () => {
    renderApp('/supplies/supply-food/edit');
    await screen.findByLabelText('Name');
    expect(screen.queryByRole('button', { name: 'Fill from photos' })).toBeNull();

    const server = createTestServer();
    server.world.ai = aiStatus({ configured: false });
    renderApp('/supplies/new', { server });
    await screen.findAllByLabelText('Name');
    await waitFor(() => expect(server.calls('GET', '/api/v1/ai/status')).toHaveLength(1));
    expect(screen.queryAllByRole('button', { name: 'Fill from photos' })).toHaveLength(0);
  });
});

describe('photos of a package, while iPhone photos are made JPEGs', () => {
  let heic: SlowHeic;
  beforeEach(() => {
    heic = slowHeic();
  });
  afterEach(() => heic.restore());

  async function openDialog() {
    fireEvent.click(await screen.findByRole('button', { name: 'Fill from photos' }));
    const element = await screen.findByRole('dialog', { name: 'Fill from photos of the package' });
    const dropOn = (files: File[]) =>
      fireEvent.drop(element.querySelector('.file-drop')!, { dataTransfer: { files, types: ['Files'] } });
    return { dialog: within(element), dropOn };
  }

  it('the dialog waits, saying so, and takes no other photos meanwhile: never more than 3 in all', async () => {
    renderApp('/supplies/new');
    const { dialog, dropOn } = await openDialog();
    dropOn([photo('front.heic'), photo('side.heic')].map((file) => new File([file], file.name, { type: 'image/heic' })));
    expect(await dialog.findByText('Preparing the photos…')).toBeTruthy();
    expect(dialog.getByRole('button', { name: 'Read' })).toHaveProperty('disabled', true);
    dropOn([photo('a.jpg'), photo('b.jpg')]);
    for (let done = 0; done < 2; done += 1) {
      await waitFor(() => expect(heic.waiting).toBeGreaterThan(0));
      heic.finish();
    }
    expect(await dialog.findByRole('img', { name: 'Photo 2: side.jpg' })).toBeTruthy();
    expect(dialog.getAllByRole('img', { name: /^Photo \d+: / })).toHaveLength(2);
    dropOn([photo('a.jpg'), photo('b.jpg')]);
    expect(await dialog.findByText('Use 3 photos or fewer: the first 3 are taken.')).toBeTruthy();
    expect(dialog.getAllByRole('img', { name: /^Photo \d+: / })).toHaveLength(3);
  });

  it('closing while photos are made JPEGs asks first', async () => {
    renderApp('/supplies/new');
    const { dialog, dropOn } = await openDialog();
    dropOn([new File([new Uint8Array(500)], 'front.heic', { type: 'image/heic' })]);
    await dialog.findByText('Preparing the photos…');
    fireEvent.click(dialog.getByRole('button', { name: 'Cancel' }));
    expect(await screen.findByRole('dialog', { name: 'Leave without saving?' })).toBeTruthy();
  });
});

describe("AI isn't set up any more", () => {
  it('said in the dialog, which stays until closed; then "Fill from photos" is gone from the form', async () => {
    const server = createTestServer();
    renderApp('/supplies/new', { server });
    await screen.findByRole('button', { name: 'Fill from photos' });
    server.world.ai = aiStatus({ configured: false });
    const dialog = await readPhotos([photo('front.jpg')]);
    expect(await dialog.findByText("AI isn't set up: fill in the details by hand.")).toBeTruthy();
    await waitFor(() => expect(server.calls('GET', '/api/v1/ai/status').length).toBeGreaterThanOrEqual(2));
    expect(screen.getByRole('dialog', { name: 'Fill from photos of the package' })).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Cancel' }));
    const leaving = screen.queryByRole('dialog', { name: 'Leave without saving?' });
    if (leaving) fireEvent.click(within(leaving).getByRole('button', { name: 'Leave' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(screen.queryByRole('button', { name: 'Fill from photos' })).toBeNull();
  });
});
