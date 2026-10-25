// A microchip number read from a photo in the pet form: the photo goes up and to AI (POST /pets/identifiers/scan),
// one number fills the card (with a word to check it), two or more are picked from, none is said; AI not set up, busy,
// or the month's photos used up are said on the card; "Cancel" drops the reading. Without AI there is no button.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { chipReading } from '../../test/ai';
import { slowHeic } from '../../test/heic';
import { renderApp } from '../../test/render';
import { aiStatus, createTestServer, HOME, MURKA, problem } from '../../test/server';

const SCAN = '/api/v1/pets/identifiers/scan';
const photo = (name = 'sticker.jpg', type = 'image/jpeg') => new File([new Uint8Array(500)], name, { type });
const chipCard = async () => within((await screen.findAllByRole('group', { name: /^Microchips and tattoos \d$/ }))[0]!);

/** Drops `files` on the card's "Read from a photo". */
async function dropOnCard(files: File[]) {
  const card = await chipCard();
  // Once the server said it has AI.
  const zone = (await card.findByRole('button', { name: 'Read from a photo' })).closest('.file-drop')!;
  fireEvent.drop(zone, { dataTransfer: { files, types: ['Files'] } });
  return card;
}

describe('a chip number from a photo', () => {
  it('fills the card with the one number found, and asks to check it against the passport', async () => {
    const server = createTestServer();
    renderApp(`/pets/${MURKA}/edit`, { server });
    const card = await dropOnCard([photo()]);
    await waitFor(() => expect(server.calls('POST', SCAN)).toHaveLength(1));
    expect((server.calls('POST', SCAN)[0]!.body as { fileIds: string[] }).fileIds).toHaveLength(1);
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(1);
    await waitFor(() => expect(card.getByLabelText('Chip number')).toHaveProperty('value', '276 098 100 123 456'));
    expect(card.getByText('Read from the photo: check it against the passport.')).toBeTruthy();
    // Saved with the pet as typed numbers are.
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('PUT', `/api/v1/pets/${MURKA}`)).toHaveLength(1));
    const murka = server.world.households.get(HOME)!.pets.find((each) => each.id === MURKA)!;
    expect(murka.identifiers[0]!.code).toBe('276098100123456');
  });

  it('two numbers on the photo: the person picks the one of this card (one in the list already is said so)', async () => {
    const server = createTestServer();
    server.world.chipReadings = [
      chipReading({ code: '643094100000001', rawCode: '643 094 100 000 001', location: 'Neck' }),
      chipReading({ code: '276098100000001', rawCode: '276098100000001', location: 'Left shoulder' }),
    ];
    renderApp(`/pets/${MURKA}/edit`, { server });
    // A second card: the first one holds 643 094 100 000 001 already.
    fireEvent.click(await screen.findByRole('button', { name: 'Add a microchip or tattoo' }));
    const cards = await screen.findAllByRole('group', { name: /^Microchips and tattoos \d$/ });
    const second = within(cards[1]!);
    fireEvent.drop((await second.findByRole('button', { name: 'Read from a photo' })).closest('.file-drop')!, {
      dataTransfer: { files: [photo()], types: ['Files'] },
    });
    const picking = within(await screen.findByRole('dialog', { name: 'Several numbers on the photo. Which one is it?' }));
    expect(picking.getByText('This number is already in the list')).toBeTruthy();
    expect(picking.getByText('ISO microchip · Left shoulder')).toBeTruthy();
    fireEvent.click(picking.getByRole('button', { name: '276 098 100 000 001' }));
    await waitFor(() => expect(second.getByLabelText('Chip number')).toHaveProperty('value', '276098100000001'));
    expect(second.getByLabelText('Location')).toHaveProperty('value', 'Left shoulder');
  });

  it('no number on the photo: the card says to type it in', async () => {
    const server = createTestServer();
    server.world.chipReadings = [];
    renderApp(`/pets/${MURKA}/edit`, { server });
    const card = await dropOnCard([photo()]);
    expect(await card.findByText('No chip number found on the photo — type it in.')).toBeTruthy();
    expect(card.getByLabelText('Chip number')).toHaveProperty('value', '643 094 100 000 001');
  });

  it.each([
    [problem(409, { title: "AI isn't set up." }), "AI isn't set up to read photos: type the number in."],
    [problem(503, { title: 'Busy' }), 'AI is busy right now. Try again in a minute, or type the number in.'],
    [problem(502, { title: 'Refused' }), 'AI refused to read the photo. Type the number in.'],
  ])('says on the card why the photo was not read (%#)', async (answer, words) => {
    const server = createTestServer();
    server.respond('POST', SCAN, () => answer.clone(), { once: true });
    renderApp(`/pets/${MURKA}/edit`, { server });
    const card = await dropOnCard([photo()]);
    expect(await card.findByText(words)).toBeTruthy();
  });

  it("the month's AI photos used up: said with the count", async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.plan.aiPhotosUsed = 20;
    renderApp(`/pets/${MURKA}/edit`, { server });
    const card = await dropOnCard([photo()]);
    expect(await card.findByText(/^AI has read 20 of 20 photos this month/)).toBeTruthy();
  });

  it('"Cancel" while reading drops the answer', async () => {
    const server = createTestServer();
    let release!: () => void;
    server.respond('POST', SCAN, () => new Promise<undefined>((resolve) => (release = () => resolve(undefined))), {
      once: true,
    });
    renderApp(`/pets/${MURKA}/edit`, { server });
    const card = await dropOnCard([photo()]);
    const reading = within(await screen.findByRole('dialog', { name: 'Read from a photo' }));
    expect(reading.getByText('Reading the photo… Usually a few seconds, sometimes a minute.')).toBeTruthy();
    fireEvent.click(reading.getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    await waitFor(() => expect(release).toBeTypeOf('function'));
    release();
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(card.getByLabelText('Chip number')).toHaveProperty('value', '643 094 100 000 001');
    expect(card.queryByText('Read from the photo: check it against the passport.')).toBeNull();
  });

  it('a PDF is no photo for AI; the free tier is said before anything is sent', async () => {
    const { server } = renderApp(`/pets/${MURKA}/edit`);
    const card = await dropOnCard([photo('passport.pdf', 'application/pdf')]);
    expect(await card.findByText(/^passport\.pdf: AI doesn't read PDF files/)).toBeTruthy();
    expect(card.getByText(/The photo goes to AI on Gemini's free tier: only your own documents\./)).toBeTruthy();
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(0);
  });

  it('is not there without AI, nor on a tattoo', async () => {
    const server = createTestServer();
    server.world.ai = aiStatus({ configured: false });
    renderApp(`/pets/${MURKA}/edit`, { server });
    await chipCard();
    await waitFor(() => expect(server.calls('GET', '/api/v1/ai/status')).toHaveLength(1));
    expect(screen.queryByRole('button', { name: 'Read from a photo' })).toBeNull();

    const tattoo = createTestServer();
    tattoo.world.households.get(HOME)!.pets.find((each) => each.id === MURKA)!.identifiers[0]!.type = 'Tattoo';
    renderApp(`/pets/${MURKA}/edit`, { server: tattoo });
    await screen.findAllByLabelText('Tattoo code');
    await waitFor(() => expect(tattoo.calls('GET', '/api/v1/ai/status')).toHaveLength(1));
    expect(screen.queryByRole('button', { name: 'Read from a photo' })).toBeNull();
  });
});

describe('two cards, one reader', () => {
  it("while one card's photo is prepared and read, the other cards' readers wait; then each answer finds its card", async () => {
    const heic = slowHeic();
    try {
      const server = createTestServer();
      server.world.chipReadings = [chipReading({ code: '276098100000001', rawCode: '276098100000001' })];
      renderApp(`/pets/${MURKA}/edit`, { server });
      fireEvent.click(await screen.findByRole('button', { name: 'Add a microchip or tattoo' }));
      const cards = await screen.findAllByRole('group', { name: /^Microchips and tattoos \d$/ });
      const [first, second] = [within(cards[0]!), within(cards[1]!)];
      const zone = async (card: typeof first) =>
        (await card.findByRole('button', { name: 'Read from a photo' })).closest('.file-drop')!;
      fireEvent.drop(await zone(second), {
        dataTransfer: { files: [new File([new Uint8Array(500)], 'sticker.heic', { type: 'image/heic' })], types: ['Files'] },
      });
      expect(await second.findByText('Preparing the photos…')).toBeTruthy();
      // The first card's reader waits meanwhile.
      expect(first.getByRole('button', { name: 'Read from a photo' })).toHaveProperty('disabled', true);
      await waitFor(() => expect(heic.waiting).toBe(1));
      heic.finish();
      await waitFor(() => expect(second.getByLabelText('Chip number')).toHaveProperty('value', '276098100000001'));
      expect(first.getByLabelText('Chip number')).toHaveProperty('value', '643 094 100 000 001');
      // Done: the first card can read again.
      await waitFor(() => expect(first.getByRole('button', { name: 'Read from a photo' })).toHaveProperty('disabled', false));
    } finally {
      heic.restore();
    }
  });
});

describe("AI isn't set up any more", () => {
  it('the card says so, and the readers go from the form', async () => {
    const server = createTestServer();
    renderApp(`/pets/${MURKA}/edit`, { server });
    const card = await chipCard();
    await card.findByRole('button', { name: 'Read from a photo' });
    server.world.ai = aiStatus({ configured: false });
    await dropOnCard([photo()]);
    expect(await card.findByText("AI isn't set up to read photos: type the number in.")).toBeTruthy();
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Read from a photo' })).toBeNull());
    expect(card.getByText("AI isn't set up to read photos: type the number in.")).toBeTruthy();
  });
});
