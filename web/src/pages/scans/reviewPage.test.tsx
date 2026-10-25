// Checking a scan on its page: the ticks (a duplicate unticked, an entry without its date can't be ticked until the
// date is entered), the AI's doubts highlighted (day and month swapped with a click), the badges, a record's plan link
// and its choice, the editors (a kind changed drops a plan that can't take it), the passport's "Replace the saved
// value", what a save sends, the server's field errors back on their entries, a scan saved elsewhere meanwhile, a
// save whose answer got lost, and leaving with changes. The review opens only from the scan as read since its page
// opened: Back to a scan saved or thrown away here shows it so, as does one saved on another device.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { keys } from '../../api/keys';
import type { ApplyImportRequest, ImportDraft } from '../../api/types';
import { draft, draftIdentifier, draftPassport, draftRecord, draftWeight } from '../../test/ai';
import { renderApp } from '../../test/render';
import { aiImport, createTestServer, HOME, MURKA, plan, problem, uploadedFile } from '../../test/server';
import { addDays } from '../../lib/dates';

const APPLY = '/api/v1/ai-imports/scan-1/apply';
const region = async (name: string) => within(await screen.findByRole('region', { name }));
const card = (title: string) => screen.getByRole('article', { name: title });
/** An entry of the review once it is there (the pet, its plans and passport are read afresh first). */
const findCard = (title: string) => screen.findByRole('article', { name: title });

/** A ready scan of Murka's three photos with `content`; its review open. */
function reviewOf(
  content: (today: string) => Partial<ImportDraft>,
  options: { note?: boolean; server?: ReturnType<typeof createTestServer> } = {},
) {
  const server = options.server ?? createTestServer();
  const today = server.world.today;
  const home = server.world.households.get(HOME)!;
  home.imports.push(
    aiImport('scan-1', MURKA, {
      source: options.note ? 'Text' : 'PassportPages',
      text: options.note ? 'Yesterday the rabies shot; weighs 4.2 kg' : null,
      fileIds: options.note ? [] : ['p1', 'p2', 'p3'].map((id) => uploadedFile(server.world, id)),
      outcome: { draft: draft(content(today)) },
    }),
  );
  const rendered = renderApp(`/pets/${MURKA}/scans/scan-1`, { server });
  return { ...rendered, today, home };
}
const applied = (server: ReturnType<typeof createTestServer>) => server.calls('POST', APPLY).at(-1)!.body as ApplyImportRequest;

describe('the review of a scan', () => {
  it('ticks what can be saved: a duplicate unticked with its badge, an entry without its date until it is entered', async () => {
    const { server, today } = reviewOf((day) => ({
      records: [
        draftRecord({ kind: 'Deworming', title: 'Milbemax', performedOn: addDays(day, -60), selected: false, warnings: [{ field: 'record', issue: 'AlreadySaved' }] }),
        draftRecord({ kind: 'FleaTick', title: 'Frontline', performedOn: null, warnings: [{ field: 'performedOn', issue: 'Unreadable' }] }),
      ],
    }));
    const duplicate = within(await findCard('Milbemax'));
    expect(duplicate.getByRole('checkbox', { name: 'Save this entry: Milbemax' })).toHaveProperty('checked', false);
    expect(duplicate.getByText('Already saved')).toBeTruthy();
    expect(duplicate.getByText('The same entry is already in the history.')).toBeTruthy();
    const undated = within(card('Frontline'));
    const tick = undated.getByRole('checkbox', { name: 'Save this entry: Frontline' });
    expect(tick).toHaveProperty('disabled', true);
    expect(undated.getByText('Enter the date to save this entry.')).toBeTruthy();
    expect(undated.getByText("Couldn't be read. Enter it from the paper.")).toBeTruthy();
    // Nothing ticked: the photos alone can still be kept.
    expect(screen.getByRole('button', { name: 'Save the photos only' })).toHaveProperty('disabled', false);
    // Entered: it can be saved, and is ticked.
    fireEvent.change(undated.getByLabelText('Enter the date'), { target: { value: addDays(today, -3) } });
    await waitFor(() => expect(tick).toHaveProperty('checked', true));
    expect(undated.queryByText("Couldn't be read. Enter it from the paper.")).toBeNull();
    fireEvent.click(screen.getByRole('checkbox', { name: 'Keep the photos as passport pages' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    await waitFor(() => expect(server.calls('POST', APPLY)).toHaveLength(1));
    expect(applied(server).records).toEqual([
      expect.objectContaining({ record: expect.objectContaining({ kind: 'FleaTick', performedOn: addDays(today, -3) }) }),
    ]);
    expect(applied(server).keepPhotos).toBe(false);
  });

  it('highlights the doubts, swaps day and month with a click, and says where each entry was read', async () => {
    const { server } = reviewOf(() => ({
      records: [
        draftRecord({
          kind: 'Vaccination',
          title: 'Purevax',
          performedOn: '2026-03-04',
          validUntil: '2025-03-04',
          evidence: 'Purevax 03/04/2026',
          page: 2,
          warnings: [
            { field: 'performedOn', issue: 'Ambiguous' },
            { field: 'validUntil', issue: 'EndsBeforeStart' },
          ],
        }),
      ],
    }));
    const entry = within(await findCard('Purevax'));
    expect(entry.getByText('Day and month could be swapped. Check against the paper.')).toBeTruthy();
    expect(entry.getByText('“Valid until” isn’t after the vaccination date. Check it.')).toBeTruthy();
    expect(entry.getByText('Read on page 2')).toBeTruthy();
    expect(entry.getByText('“Purevax 03/04/2026”')).toBeTruthy();
    fireEvent.click(entry.getByRole('button', { name: 'Change to Apr 3, 2026' }));
    expect(entry.queryByText('Day and month could be swapped. Check against the paper.')).toBeNull();
    // The page it was read on opens large.
    fireEvent.click(entry.getByRole('button', { name: /Read on page 2/ }));
    expect(await screen.findByRole('dialog', { name: 'Page 2 of 3' })).toBeTruthy();
    fireEvent.click(within(screen.getByRole('dialog', { name: 'Page 2 of 3' })).getByRole('button', { name: 'Close' }));
    // Its protection ends before it starts: saving says what keeps it, on the entry.
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    expect(await screen.findByText('Check the highlighted fields.')).toBeTruthy();
    expect(entry.getByText('Valid until: Must be after the date of the vaccination and the start')).toBeTruthy();
    expect(entry.getByText('Fix this entry or untick it.')).toBeTruthy();
    expect(server.calls('POST', APPLY)).toHaveLength(0);
  });

  it("links a record to a plan it is the \"Done\" of: one choice at once, several from a list, or none", async () => {
    const server = createTestServer();
    const today = server.world.today;
    const home = server.world.households.get(HOME)!;
    home.plans.push(plan('plan-rabies-2', MURKA, today, { kind: 'Vaccination', title: 'Rabies (3 years)', targets: ['Rabies'], daysLeft: 300 }));
    home.imports.push(
      aiImport('scan-1', MURKA, {
        outcome: {
          draft: draft({
            records: [
              draftRecord({ kind: 'Vaccination', title: 'Nobivac Rabies', performedOn: addDays(today, -2), targets: ['Rabies'], planId: 'plan-rabies' }),
              draftRecord({ kind: 'VetExam', title: 'Exam', performedOn: addDays(today, -2) }),
            ],
          }),
        },
      }),
    );
    renderApp(`/pets/${MURKA}/scans/scan-1`, { server });
    const vaccine = within(await findCard('Nobivac Rabies'));
    expect(vaccine.getByRole('checkbox', { name: 'Mark as done in plan “Rabies”' })).toHaveProperty('checked', true);
    expect(vaccine.getByText('The plan moves on only if this entry is newer than its last “Done”.')).toBeTruthy();
    // Two plans of its kind: another one is chosen from the list.
    fireEvent.click(vaccine.getByRole('button', { name: 'Choose another plan' }));
    const choosing = within(await screen.findByRole('dialog', { name: 'Mark as done in which plan?' }));
    fireEvent.click(choosing.getByRole('button', { name: 'Rabies (3 years)' }));
    expect(await vaccine.findByRole('checkbox', { name: 'Mark as done in plan “Rabies (3 years)”' })).toBeTruthy();
    // The check-up's one plan of its kind: ticking the link takes it at once.
    const exam = within(card('Exam'));
    fireEvent.click(exam.getByRole('checkbox', { name: 'Mark as done in a plan' }));
    expect(await exam.findByRole('checkbox', { name: 'Mark as done in plan “Yearly check-up”' })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Save 2 selected' }));
    await waitFor(() => expect(server.calls('POST', APPLY)).toHaveLength(1));
    expect(applied(server).records.map((record) => record.planId)).toEqual(['plan-rabies-2', 'plan-exam']);
  });

  it('edits an entry with the rules of the record form; a kind that a plan can\'t take drops the link', async () => {
    const { server, today } = reviewOf((day) => ({
      records: [
        draftRecord({ kind: 'Vaccination', performedOn: addDays(day, -2), targets: ['Rabies'], planId: 'plan-rabies', product: 'Nobivac' }),
      ],
    }));
    const entry = within(await findCard('Rabies vaccination'));
    fireEvent.click(entry.getByRole('button', { name: 'Edit: Rabies vaccination' }));
    const editor = within(await screen.findByRole('dialog', { name: 'Edit entry' }));
    // The title the person sees is the kind's name: left as it is, it follows the kind.
    expect(editor.getByLabelText('Title')).toHaveProperty('value', 'Rabies vaccination');
    fireEvent.change(editor.getByLabelText('Date'), { target: { value: addDays(today, 5) } });
    fireEvent.click(editor.getByRole('button', { name: 'Done' }));
    expect(await editor.findByText("A date in the future can't be saved")).toBeTruthy();
    fireEvent.change(editor.getByLabelText('Date'), { target: { value: addDays(today, -4) } });
    fireEvent.change(editor.getByLabelText('Type'), { target: { value: 'Deworming' } });
    fireEvent.click(editor.getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Edit entry' })).toBeNull());
    // A deworming: Murka's rabies plan can't take it, and its name, never typed, follows the new kind.
    const edited = within(await findCard('Deworming'));
    expect(edited.queryByRole('checkbox', { name: /Mark as done in plan/ })).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    await waitFor(() => expect(server.calls('POST', APPLY)).toHaveLength(1));
    expect(applied(server).records[0]).toEqual({
      planId: null,
      record: expect.objectContaining({ kind: 'Deworming', title: 'Deworming', performedOn: addDays(today, -4), targets: [] }),
    });
  });

  it("sends microchips, weighings and the passport's details; a different saved value only when told to replace it", async () => {
    const { server, today } = reviewOf((day) => ({
      weights: [draftWeight({ measuredOn: addDays(day, -1), weightKg: 4.2 })],
      identifiers: [
        draftIdentifier({ code: '643094100000001', selected: false, warnings: [{ field: 'code', issue: 'AlreadySaved' }] }),
        draftIdentifier({ type: 'Tattoo', code: 'MRK12', location: 'Right ear' }),
      ],
      passport: draftPassport({
        passportNumber: 'RU0123457',
        issuingCountry: 'RU',
        selected: false,
        warnings: [{ field: 'passportNumber', issue: 'DiffersFromSaved' }],
      }),
    }));
    const chip = within(await findCard('643 094 100 000 001'));
    expect(chip.getByText('The pet already has this number.')).toBeTruthy();
    const passport = within(card('Add to the passport details'));
    expect(passport.getByText("Differs from what's saved")).toBeTruthy();
    expect(passport.getByText('Saved: RU0123456')).toBeTruthy();
    expect(passport.getByText('Already in the passport details')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Save 2 selected' })).toBeTruthy();
    fireEvent.click(passport.getByRole('checkbox', { name: 'Replace the saved value' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Save 3 selected' }));
    await waitFor(() => expect(server.calls('POST', APPLY)).toHaveLength(1));
    expect(applied(server)).toMatchObject({
      records: [],
      identifiers: [{ type: 'Tattoo', code: 'MRK12', appliedOn: null, readOn: null, location: 'Right ear' }],
      passport: { passportNumber: 'RU0123457', issuingCountry: null, issuedOn: null },
      weights: [{ measuredOn: addDays(today, -1), weightKg: 4.2 }],
    });
    expect(
      await screen.findByText(
        '1 weighing added · 1 microchip or tattoo added · passport details updated: number · photos added to the passport pages',
      ),
    ).toBeTruthy();
  });

  it("puts the server's field errors back on the entries they name, and a change answers them", async () => {
    const { server } = reviewOf((day) => ({
      records: [
        draftRecord({ kind: 'Deworming', title: 'Milbemax', performedOn: addDays(day, -2) }),
        draftRecord({ kind: 'Deworming', title: 'Drontal', performedOn: addDays(day, -3) }),
      ],
    }));
    server.respond(
      'POST',
      APPLY,
      () => problem(400, { errors: { 'records[1].record.product': ['Too long.'], 'records[1].planId': ['No.'] } }),
      { once: true },
    );
    await findCard('Drontal');
    fireEvent.click(screen.getByRole('button', { name: 'Save 2 selected' }));
    expect(await screen.findByText('Check the highlighted fields.')).toBeTruthy();
    const second = within(card('Drontal'));
    expect(second.getByText("Product: This value wasn't accepted. Check it.")).toBeTruthy();
    expect(second.getByText("Care plan: This value wasn't accepted. Check it.")).toBeTruthy();
    expect(within(card('Milbemax')).queryByText(/wasn't accepted/)).toBeNull();
    // The product typed anew: the server's word on it goes. The plan link's isn't the editor's to answer (the card's
    // link is), so it doesn't keep "Done" from closing.
    fireEvent.click(second.getByRole('button', { name: 'Edit: Drontal' }));
    const editor = within(await screen.findByRole('dialog', { name: 'Edit entry' }));
    fireEvent.change(editor.getByLabelText('Product'), { target: { value: 'Drontal Plus' } });
    fireEvent.click(editor.getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Edit entry' })).toBeNull());
    expect(second.queryByText("Product: This value wasn't accepted. Check it.")).toBeNull();
    expect(second.getByText("Care plan: This value wasn't accepted. Check it.")).toBeTruthy();
  });

  it('a scan saved elsewhere meanwhile: saving finds it so and shows what it saved', async () => {
    const { server, home } = reviewOf((day) => ({ records: [draftRecord({ performedOn: addDays(day, -2) })] }));
    await findCard('Vaccination');
    const scan = home.imports[0]!;
    scan.status = 'Applied';
    scan.result = { recordIds: ['r1'], plansMoved: 0, identifiersAdded: 0, passportUpdated: false, documentId: null, weightsAdded: 0 };
    server.respond('POST', APPLY, () => problem(409, { title: "The draft isn't ready." }), { once: true });
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    expect(await screen.findByText('Saved 1 record')).toBeTruthy();
  });

  it('a save whose answer got lost: the server is asked, and a scan saved by it shows as saved', async () => {
    const { server } = reviewOf((day) => ({ records: [draftRecord({ performedOn: addDays(day, -2) })] }));
    server.respond(
      'POST',
      APPLY,
      async (request) => {
        // Saved, and the answer lost on the way back.
        await server.fetch(
          new Request(`http://localhost${APPLY}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: request.authorization!, 'X-Household': HOME },
            body: JSON.stringify(request.body),
          }),
        );
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    await findCard('Vaccination');
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    expect(
      await screen.findByText('Saved 1 record · photos added to the passport pages (saved before the connection dropped)'),
    ).toBeTruthy();
    expect(server.world.households.get(HOME)!.records.filter((each) => each.source === 'AiScan')).toHaveLength(1);
  });

  it('no answer at all: "Couldn\'t tell whether it was saved", and the next save asks the server first', async () => {
    const { server } = reviewOf((day) => ({ records: [draftRecord({ performedOn: addDays(day, -2) })] }));
    await findCard('Vaccination');
    // The save, and the question whether it went through, both get no answer.
    const lost = () => {
      throw new TypeError('Failed to fetch');
    };
    server.respond('POST', APPLY, lost, { once: true });
    server.respond('GET', '/api/v1/ai-imports/scan-1', lost, { once: true });
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    expect(await screen.findByText(/^Couldn't tell whether it was saved\./)).toBeTruthy();
    const asked = server.calls('GET', '/api/v1/ai-imports/scan-1').length;
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    expect(await screen.findByText('Saved 1 record · photos added to the passport pages')).toBeTruthy();
    expect(server.calls('GET', '/api/v1/ai-imports/scan-1').length).toBeGreaterThan(asked);
  });

  it('asks before leaving a review with changes: the scan stays on the Passport tab', async () => {
    const { router } = reviewOf((day) => ({ records: [draftRecord({ title: 'Nobivac', performedOn: addDays(day, -2) })] }));
    const entry = within(await findCard('Nobivac'));
    fireEvent.click(entry.getByRole('checkbox', { name: 'Save this entry: Nobivac' }));
    fireEvent.click(screen.getAllByRole('link', { name: 'Murka' })[0]!);
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    expect(asking.getByText('Your changes here will be lost. The scan stays on the Passport tab to check later.')).toBeTruthy();
    fireEvent.click(asking.getByRole('button', { name: 'Leave' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/passport`));
  });

  it('a note is quoted with when it was written, with no photos to keep; its entries say they come from the note', async () => {
    const { server } = reviewOf(
      (day) => ({ weights: [draftWeight({ measuredOn: addDays(day, -1), weightKg: 4.2, evidence: 'weighs 4.2 kg' })] }),
      { note: true },
    );
    expect(await screen.findByRole('heading', { name: 'Check the note', level: 1 })).toBeTruthy();
    const quoted = await region('Your note');
    expect(quoted.getByText('“Yesterday the rabies shot; weighs 4.2 kg”')).toBeTruthy();
    expect(quoted.getByText(/^Written /)).toBeTruthy();
    expect(screen.queryByRole('checkbox', { name: /Keep the photos/ })).toBeNull();
    expect(screen.getByText('From your note')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    await waitFor(() => expect(server.calls('POST', APPLY)).toHaveLength(1));
    expect(applied(server).keepPhotos).toBe(false);
  });
});

describe('a scan saved or thrown away', () => {
  const twoRecords = (day: string) => ({
    records: [
      draftRecord({ title: 'Milbemax', kind: 'Deworming' as const, performedOn: addDays(day, -3) }),
      draftRecord({ title: 'Frontline', kind: 'FleaTick' as const, performedOn: addDays(day, -3), selected: false }),
    ],
  });
  const savedOnAPhone = {
    recordIds: ['r1', 'r2'],
    plansMoved: 0,
    identifiersAdded: 0,
    passportUpdated: false,
    documentId: null,
    weightsAdded: 0,
  };

  it('Back to the page of a scan saved here: it shows saved, and no review to tick more on and "save" again', async () => {
    const { server, router } = reviewOf(twoRecords);
    await findCard('Milbemax');
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    expect(await screen.findByText(/^Saved 1 record/)).toBeTruthy();
    await act(() => router.navigate(`/pets/${MURKA}/passport`));
    await screen.findByRole('region', { name: 'Passport details' });
    await act(() => router.navigate(-1));
    expect(router.state.location.pathname).toBe(`/pets/${MURKA}/scans/scan-1`);
    expect(await screen.findByText(/^Saved 1 record/)).toBeTruthy();
    // As the server has it now, read again.
    await waitFor(() => expect(server.calls('GET', '/api/v1/ai-imports/scan-1').length).toBeGreaterThanOrEqual(2));
    expect(screen.queryByRole('checkbox', { name: 'Save this entry: Frontline' })).toBeNull();
    expect(screen.queryByRole('button', { name: /^Save / })).toBeNull();
    expect(server.calls('POST', APPLY)).toHaveLength(1);
  });

  it('thrown away here, then Back: it shows thrown away, not its review', async () => {
    const { router } = reviewOf(twoRecords);
    await findCard('Milbemax');
    fireEvent.click(screen.getByRole('button', { name: 'Discard scan' }));
    fireEvent.click(within(await screen.findByRole('dialog', { name: 'Discard this scan?' })).getByRole('button', { name: 'Discard' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/passport`));
    await act(() => router.navigate(-1));
    expect(await screen.findByText('Nothing from this scan was saved.')).toBeTruthy();
    expect(screen.queryByRole('button', { name: /^Save / })).toBeNull();
  });

  it('saved on another device while live updates were off: opened from a copy of when it was ready, it shows saved', async () => {
    const { router, home } = reviewOf(twoRecords);
    await findCard('Milbemax');
    await act(() => router.navigate(`/pets/${MURKA}/passport`));
    await screen.findByRole('region', { name: 'Passport details' });
    // Saved on a phone meanwhile; nothing tells this tab.
    Object.assign(home.imports[0]!, { status: 'Applied', result: savedOnAPhone });
    await act(() => router.navigate(`/pets/${MURKA}/scans/scan-1`));
    expect(await screen.findByText('Saved 2 records')).toBeTruthy();
    expect(screen.queryByRole('button', { name: /^Save / })).toBeNull();
  });

  it('saved on another device while checked here: once read again (a live update), the page shows it saved', async () => {
    const { server, home, queryClient } = reviewOf(twoRecords);
    await findCard('Milbemax');
    Object.assign(home.imports[0]!, { status: 'Applied', result: savedOnAPhone });
    await act(() => queryClient.invalidateQueries({ queryKey: keys.aiImport(HOME, 'scan-1') }));
    expect(await screen.findByText('Saved 2 records')).toBeTruthy();
    expect(screen.queryByRole('button', { name: /^Save / })).toBeNull();
    expect(server.calls('POST', APPLY)).toHaveLength(0);
  });

  it("the pet's passport not read for the review: why, with \"Try again\", which opens the review", async () => {
    const server = createTestServer();
    server.respond('GET', `/api/v1/pets/${MURKA}/passport`, () => problem(500, { title: 'Boom' }), { once: true });
    reviewOf(twoRecords, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Try again' }));
    expect(await findCard('Milbemax')).toBeTruthy();
  });
});
