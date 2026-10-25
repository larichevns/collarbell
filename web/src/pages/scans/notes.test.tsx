// Notes written in words for AI (the phone's "Write it in words"): on the Health tab with "Scan a vet document"; the
// free tier's warning before anything is sent; the note's checks (words in it, 1000 characters at most, counted as
// the server counts them); one request id per text, kept when the same text is sent again; the day's limit; a failed
// note on the Health tab, read again in its place (retryOf) or thrown away after asking.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { keys } from '../../api/keys';
import type { CreateAiImportRequest } from '../../api/types';
import { renderApp } from '../../test/render';
import { aiImport, aiStatus, createTestServer, HOME, MURKA, problem } from '../../test/server';

const NOTES = '/api/v1/ai-imports';
const sentNotes = (server: ReturnType<typeof createTestServer>) =>
  server.calls('POST', NOTES).map((call) => call.body as CreateAiImportRequest);
const type = (text: string) => fireEvent.change(screen.getByLabelText('Note'), { target: { value: text } });
const read = () => fireEvent.click(screen.getByRole('button', { name: 'Read' }));

describe('a note written in words', () => {
  it('is offered on the Health tab with the vet document scan, when AI is set up, to those who change things', async () => {
    const { router } = renderApp(`/pets/${MURKA}/health`);
    fireEvent.click(await screen.findByRole('link', { name: 'Write it in words' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/note`));
    expect(await screen.findByRole('heading', { name: 'Write it in words', level: 1 })).toBeTruthy();
    expect(screen.getByText(/^Free Gemini tier: .* Don't write personal details/)).toBeTruthy();
    expect(screen.getByText('AI only prepares a draft: you check every entry and decide what to save.')).toBeTruthy();
  });

  it('is not offered without AI, nor to helpers', async () => {
    const server = createTestServer();
    server.world.ai = aiStatus({ configured: false });
    renderApp(`/pets/${MURKA}/health`, { server });
    await screen.findByRole('region', { name: 'History' });
    expect(screen.queryByRole('link', { name: 'Write it in words' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Scan a vet document' })).toBeNull();

    const helping = createTestServer();
    helping.world.households.get(HOME)!.summary.role = 'Helper';
    renderApp(`/pets/${MURKA}/note`, { server: helping });
    expect(await screen.findByRole('heading', { name: "Your role in the group doesn't allow this" })).toBeTruthy();
  });

  it('needs words, up to 1000 characters as the server counts them: nothing is sent until then', async () => {
    const { server } = renderApp(`/pets/${MURKA}/note`);
    await screen.findByLabelText('Note');
    read();
    expect(await screen.findByText('Write what was done, in words.')).toBeTruthy();
    type(' 🐾 !? ');
    expect(screen.getByText('Write what was done, in words.')).toBeTruthy();
    // An emoji counts two, as on the server; the spaces around don't count.
    type(`  ${'a'.repeat(999)}😺  `);
    expect(screen.getByText('1001/1000')).toBeTruthy();
    expect(screen.getByText('Use 1000 characters or fewer')).toBeTruthy();
    read();
    expect(sentNotes(server)).toHaveLength(0);
    type(`  ${'a'.repeat(998)}😺  `);
    expect(screen.getByText('1000/1000')).toBeTruthy();
    expect(screen.queryByText('Use 1000 characters or fewer')).toBeNull();
  });

  it("is sent trimmed, as a note of the pet's, then read; its draft opens to check", async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/note`);
    await screen.findByLabelText('Note');
    type('  Yesterday the rabies shot, Nobivac; weighs 4.2 kg  ');
    read();
    await waitFor(() => expect(sentNotes(server)).toHaveLength(1));
    expect(sentNotes(server)[0]).toEqual({
      petId: MURKA,
      source: 'Text',
      fileIds: [],
      text: 'Yesterday the rabies shot, Nobivac; weighs 4.2 kg',
      retryOf: null,
      requestId: expect.stringMatching(/^[0-9a-f-]{36}$/),
    });
    await waitFor(() => expect(router.state.location.pathname).toMatch(new RegExp(`^/pets/${MURKA}/scans/`)));
    expect(await screen.findByText('Reading the note…')).toBeTruthy();
  });

  it('keeps one request id per text: the same text sent again has it, another text has its own', async () => {
    const server = createTestServer();
    let tries = 0;
    server.respond('POST', NOTES, () => {
      tries += 1;
      // The first three get no answer.
      if (tries <= 3) throw new TypeError('Failed to fetch');
      return undefined;
    });
    renderApp(`/pets/${MURKA}/note`, { server });
    await screen.findByLabelText('Note');
    type('Weighs 4.2 kg');
    read();
    expect(await screen.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    read();
    await waitFor(() => expect(sentNotes(server)).toHaveLength(2));
    type('Weighs 4.3 kg');
    read();
    await waitFor(() => expect(sentNotes(server)).toHaveLength(3));
    type('Weighs 4.2 kg');
    read();
    await waitFor(() => expect(sentNotes(server)).toHaveLength(4));
    const ids = sentNotes(server).map((note) => note.requestId);
    expect(ids[1]).toBe(ids[0]);
    expect(ids[2]).not.toBe(ids[0]);
    expect(ids[3]).toBe(ids[0]);
  });

  it("the day's notes used up: said with the server's limit, and \"Read\" is off", async () => {
    const server = createTestServer();
    server.world.notesRead = 25;
    server.world.notesPerDay = 25;
    renderApp(`/pets/${MURKA}/note`, { server });
    await screen.findByLabelText('Note');
    type('Weighs 4.2 kg');
    read();
    expect(
      await screen.findByText(
        'AI has already read 25 notes in the last 24 hours. Try again tomorrow or add the record by hand.',
      ),
    ).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Read' })).toHaveProperty('disabled', true);
  });

  it("the server refusing the text: said on the field, until it changes", async () => {
    const server = createTestServer();
    server.respond('POST', NOTES, () => problem(400, { errors: { text: ['Write what was done.'] } }), { once: true });
    renderApp(`/pets/${MURKA}/note`, { server });
    await screen.findByLabelText('Note');
    type('Weighs 4.2 kg');
    read();
    expect(await screen.findByText("This value wasn't accepted. Check it.")).toBeTruthy();
    expect(screen.getByText('Check the highlighted fields.')).toBeTruthy();
    type('Weighs 4.25 kg');
    expect(screen.queryByText("This value wasn't accepted. Check it.")).toBeNull();
  });
});

describe('a note refused, and "Read" again', () => {
  it("AI isn't set up, as ASP.NET writes the 409 (RFC 9110's type): said so, no \"Try again\", and the buttons go", async () => {
    const server = createTestServer();
    server.respond('POST', NOTES, () => {
      server.world.ai = aiStatus({ configured: false });
      return problem(409, {
        type: 'https://tools.ietf.org/html/rfc9110#section-15.5.10',
        title: "AI isn't set up.",
        detail: 'Add an AI model on the server (Ai settings) to read photos.',
      });
    });
    const { router } = renderApp(`/pets/${MURKA}/note?from=health`, { server });
    await screen.findByLabelText('Note');
    type('Yesterday the rabies shot');
    read();
    expect(await screen.findByText(/^AI isn't set up on the server/)).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Try again' })).toBeNull();
    expect(screen.getByRole('button', { name: 'Read' })).toHaveProperty('disabled', true);
    // Whether AI is set up is read again: the Health tab has no AI buttons now.
    await waitFor(() => expect(server.calls('GET', '/api/v1/ai/status').length).toBeGreaterThanOrEqual(2));
    await act(() => router.navigate(`/pets/${MURKA}/health`));
    // The note typed isn't sent: leaving asks first.
    fireEvent.click(within(await screen.findByRole('dialog', { name: 'Leave without saving?' })).getByRole('button', { name: 'Leave' }));
    await screen.findByRole('region', { name: 'History' });
    expect(screen.queryByRole('link', { name: 'Write it in words' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Scan a vet document' })).toBeNull();
  });

  it('"Read" comes back once AI is set up again, for the same text', async () => {
    const server = createTestServer();
    server.world.ai = aiStatus({ configured: false });
    const { queryClient } = renderApp(`/pets/${MURKA}/note`, { server });
    await screen.findByLabelText('Note');
    type('Weighs 4.2 kg');
    read();
    expect(await screen.findByText(/^AI isn't set up on the server/)).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Read' })).toHaveProperty('disabled', true);
    server.world.ai = aiStatus({ configured: true });
    await act(() => queryClient.invalidateQueries({ queryKey: keys.aiStatus(HOME) }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Read' })).toHaveProperty('disabled', false));
    read();
    await waitFor(() => expect(sentNotes(server)).toHaveLength(2));
  });

  it("the day's notes used up: \"Read\" is off for that text only, and back for another", async () => {
    const server = createTestServer();
    server.world.notesRead = 25;
    server.world.notesPerDay = 25;
    renderApp(`/pets/${MURKA}/note`, { server });
    await screen.findByLabelText('Note');
    type('Weighs 4.2 kg');
    read();
    await screen.findByText('AI has already read 25 notes in the last 24 hours. Try again tomorrow or add the record by hand.');
    const button = screen.getByRole('button', { name: 'Read' });
    expect(button).toHaveProperty('disabled', true);
    type('Weighs 4.25 kg');
    expect(button).toHaveProperty('disabled', false);
    type('Weighs 4.2 kg');
    expect(button).toHaveProperty('disabled', true);
  });

  it('the count of characters is said politely as it changes, in words', async () => {
    renderApp(`/pets/${MURKA}/note`);
    await screen.findByLabelText('Note');
    type('Weighs 4.2 kg');
    const spoken = screen.getByText('13 of 1000 characters');
    expect(spoken.closest('[aria-live]')!.getAttribute('aria-live')).toBe('polite');
    expect(spoken.closest('[aria-hidden="true"]')).toBeNull();
    // Seen as "13/1000", which a screen reader skips for the words.
    expect(screen.getByText('13/1000').getAttribute('aria-hidden')).toBe('true');
  });
});

describe('a failed note on the Health tab', () => {
  function withFailedNote() {
    const server = createTestServer();
    server.world.households
      .get(HOME)!
      .imports.push(
        aiImport('note-failed', MURKA, {
          source: 'Text',
          status: 'Failed',
          error: 'Busy',
          text: 'Yesterday the rabies shot',
          createdAt: '2026-10-06T09:30:00Z',
        }),
      );
    return server;
  }

  it('says why, quoting the note; "Try again" reads its text anew in its place', async () => {
    const server = withFailedNote();
    const { router } = renderApp(`/pets/${MURKA}/health`, { server });
    expect(await screen.findByText(/^Note from Oct 6, 2026/)).toBeTruthy();
    expect(screen.getByText('“Yesterday the rabies shot”')).toBeTruthy();
    expect(screen.getByText('The AI models are busy or out of free requests right now. Try again in a few minutes.')).toBeTruthy();
    expect(server.calls('GET', `/api/v1/pets/${MURKA}/ai-imports`)[0]!.query.get('notes')).toBe('true');
    fireEvent.click(screen.getByRole('link', { name: 'Try again' }));
    await waitFor(() => expect(sentNotes(server)).toHaveLength(1));
    expect(sentNotes(server)[0]).toMatchObject({ source: 'Text', text: 'Yesterday the rabies shot', retryOf: 'note-failed' });
    await waitFor(() => expect(router.state.location.pathname).toMatch(/\/scans\/(?!note-failed)/));
    const notes = server.world.households.get(HOME)!.imports;
    expect(notes.find((each) => each.id === 'note-failed')!.status).toBe('Discarded');
    // Read again unchanged, the note keeps the day it was written: its "yesterday" counts from then.
    expect(notes.at(-1)!.createdAt).toBe('2026-10-06T09:30:00Z');
  });

  it('"Dismiss" asks first (its text goes with it), then throws it away', async () => {
    const server = withFailedNote();
    renderApp(`/pets/${MURKA}/health`, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Dismiss' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Discard this note?' }));
    expect(asking.getByText('Nothing from it is saved, and its text is deleted.')).toBeTruthy();
    fireEvent.click(asking.getByRole('button', { name: 'Discard' }));
    await waitFor(() => expect(server.calls('DELETE', '/api/v1/ai-imports/note-failed')).toHaveLength(1));
    await waitFor(() => expect(screen.queryByText('“Yesterday the rabies shot”')).toBeNull());
  });

  it("its page says why it failed, with the note and \"Try again\"", async () => {
    const server = withFailedNote();
    renderApp(`/pets/${MURKA}/scans/note-failed`, { server });
    expect(await screen.findByText("Couldn't be read")).toBeTruthy();
    expect(screen.getByText('“Yesterday the rabies shot”')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Try again' }).getAttribute('href')).toBe(
      `/pets/${MURKA}/note?again=note-failed&from=health`,
    );
  });
});

describe('a failed note read again', () => {
  it('"Try again" on a note written two hours ago: the wait doesn\'t say at once that it takes longer than usual', async () => {
    const server = createTestServer();
    const twoHoursAgo = new Date(Date.now() - 2 * 3_600_000).toISOString();
    server.world.households.get(HOME)!.imports.push(
      aiImport('note-1', MURKA, {
        source: 'Text',
        status: 'Failed',
        error: 'Busy',
        text: 'Yesterday the rabies shot',
        createdAt: twoHoursAgo,
        completedAt: twoHoursAgo,
      }),
    );
    const { router } = renderApp(`/pets/${MURKA}/note?again=note-1&from=health`, { server });
    await waitFor(() => expect(router.state.location.pathname).toMatch(new RegExp(`^/pets/${MURKA}/scans/(?!note-1)`)));
    expect(await screen.findByText('Reading the note…')).toBeTruthy();
    // Read again unchanged, it is still the note written two hours ago…
    expect(server.world.households.get(HOME)!.imports.at(-1)!.createdAt).toBe(twoHoursAgo);
    // …which says nothing of how long this wait has been.
    expect(screen.queryByText(/^Taking longer than usual/)).toBeNull();
  });

  it('opened again after its "Try again" had started it (a reload): the note that took its place opens', async () => {
    const server = createTestServer();
    const written = '2026-10-06T09:30:00Z';
    server.world.households
      .get(HOME)!
      .imports.push(
        aiImport('note-failed', MURKA, { source: 'Text', status: 'Discarded', text: null, createdAt: written }),
        aiImport('note-again', MURKA, { source: 'Text', status: 'Processing', text: 'Yesterday the rabies shot', createdAt: written }),
      );
    const { router } = renderApp(`/pets/${MURKA}/note?again=note-failed&from=health`, { server });
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/scans/note-again`));
    expect(await screen.findByText('Reading the note…')).toBeTruthy();
    expect(sentNotes(server)).toHaveLength(0);
  });

  it('read again or dismissed, with no note in its place: said so, and a note can be written anew', async () => {
    const server = createTestServer();
    server.world.households
      .get(HOME)!
      .imports.push(aiImport('note-failed', MURKA, { source: 'Text', status: 'Discarded', text: null }));
    renderApp(`/pets/${MURKA}/note?again=note-failed&from=health`, { server });
    expect(await screen.findByText('This note was read again already, or dismissed. Write it anew to read it.')).toBeTruthy();
    expect(screen.getByLabelText('Note')).toHaveProperty('value', '');
    expect(sentNotes(server)).toHaveLength(0);
  });
});
