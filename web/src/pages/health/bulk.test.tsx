// The bulk entry of a passport's history: rows checked like the record form, one request per row with a request id of
// its own that a retry keeps, the saved rows leaving the table, and the refused ones staying with the reason.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { CareRecordRequest } from '../../api/types';
import { en } from '../../i18n/en';
import { addDays } from '../../lib/dates';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, MURKA, problem, record } from '../../test/server';
import { newRow, rowHolds, rowProblems, rowRequest } from './bulk';

const today = '2026-10-07';
const PATH = `/api/v1/pets/${MURKA}/care-records`;

/** The fields of row `number` (1, 2…). */
const row = (number: number) => within(screen.getByRole('group', { name: `Record ${number}` }));
const type = (number: number, label: string, value: string) =>
  fireEvent.change(row(number).getByLabelText(label), { target: { value } });

describe('a row of the bulk entry', () => {
  it('is checked like the record form', () => {
    const blank = { ...newRow(), touched: true };
    expect(rowProblems(en, blank, today)).toEqual({ performedOn: 'Choose a date' });
    expect(rowProblems(en, { ...blank, performedOn: '2026-10-08' }, today)).toEqual({
      performedOn: "Can't be later than today",
    });
    expect(rowProblems(en, { ...blank, performedOn: '1989-12-31' }, today).performedOn).toBe(
      'Use a date in 1990 or later',
    );
    const vaccination = { ...blank, performedOn: '2026-05-01' };
    expect(rowProblems(en, { ...vaccination, validFrom: '2026-04-30', validUntil: '2026-05-01' }, today)).toEqual({
      validFrom: "Can't be before the date of the vaccination",
      validUntil: 'Must be after the date of the vaccination and the start',
    });
    expect(rowProblems(en, { ...vaccination, batch: 'x'.repeat(51), vet: 'y'.repeat(101) }, today)).toEqual({
      batchNumber: 'Use 50 characters or fewer',
      veterinarian: 'Use 100 characters or fewer',
    });
    // A check-up has no batch and no validity: what was typed there before the kind changed isn't checked or sent.
    const exam = { ...vaccination, kind: 'VetExam' as const, batch: 'x'.repeat(51), validUntil: '2026-01-01' };
    expect(rowProblems(en, exam, today)).toEqual({});
    expect(rowRequest(en, exam)).toMatchObject({ batchNumber: null, validUntil: null, title: 'Check-up' });
  });

  it("becomes a record with the phone's default title, its own request id, and what the kind has", () => {
    const first = {
      ...newRow(),
      touched: true,
      performedOn: '2026-05-01',
      targets: ['Rabies' as const],
      vet: ' Dr. X ',
    };
    const sent = rowRequest(en, first);
    expect(sent).toMatchObject({
      kind: 'Vaccination',
      title: 'Rabies',
      performedOn: '2026-05-01',
      targets: ['Rabies'],
      veterinarian: 'Dr. X',
      performedTime: null,
      requestId: first.requestId,
    });
    // A new row takes the kind, the targets, the product and the vet of the row above: not the date or the batch.
    const next = newRow({ ...first, product: 'Nobivac', batch: 'A1' });
    expect(next).toMatchObject({
      kind: 'Vaccination',
      targets: ['Rabies'],
      product: 'Nobivac',
      vet: ' Dr. X ',
      batch: '',
    });
    expect(next.requestId).not.toBe(first.requestId);
    const echinococcus = { ...newRow(), kind: 'Echinococcus' as const, performedOn: '2026-05-01', time: '14:30' };
    expect(rowRequest(en, echinococcus)).toMatchObject({ title: 'Echinococcus treatment', performedTime: '14:30:00' });
  });

  it('knows whether a saved record still says what the row says (a correction after a lost answer)', () => {
    const row = { ...newRow(), performedOn: '2026-05-01', product: 'Nobivac', targets: ['Rabies' as const] };
    const sent = rowRequest(en, row);
    const saved = { ...record('r1', MURKA, { ...sent, targets: sent.targets ?? [], files: [] }), files: [] };
    expect(rowHolds(saved, sent)).toBe(true);
    expect(rowHolds({ ...saved, product: 'Rabisin' }, sent)).toBe(false);
  });
});

describe('the bulk entry page', () => {
  it('sends nothing while a row has a mistake, and says where', async () => {
    const { server } = renderApp(`/pets/${MURKA}/records/import`);
    await screen.findByRole('group', { name: 'Record 1' });
    type(1, 'Product', 'Nobivac Rabies');
    fireEvent.click(await screen.findByRole('button', { name: 'Add row' }));
    type(2, 'Date', addDays(server.world.today, -30));
    type(2, 'Valid until', addDays(server.world.today, -40));
    fireEvent.click(screen.getByRole('button', { name: 'Save 2 records' }));
    expect(await screen.findByText('Check the highlighted rows: nothing has been saved yet.')).toBeTruthy();
    expect(row(1).getByText('Choose a date')).toBeTruthy();
    expect(row(1).getByLabelText('Date').getAttribute('aria-invalid')).toBe('true');
    expect(row(2).getByText('Must be after the date of the vaccination and the start')).toBeTruthy();
    expect(server.calls('POST', PATH)).toHaveLength(0);
  });

  it('adds a row with Enter, taking the type, product and vet of the row above; a row of a type has its fields', async () => {
    renderApp(`/pets/${MURKA}/records/import`);
    const date = await screen.findByLabelText('Date');
    type(1, 'Type', 'Deworming');
    type(1, 'Product', 'Milbemax');
    fireEvent.keyDown(row(1).getByLabelText('Product'), { key: 'Enter' });
    await waitFor(() => expect(screen.getByRole('group', { name: 'Record 2' })).toBeTruthy());
    expect(row(2).getByLabelText('Type')).toHaveProperty('value', 'Deworming');
    expect(row(2).getByLabelText('Product')).toHaveProperty('value', 'Milbemax');
    expect(row(2).getByLabelText('Date')).toHaveProperty('value', '');
    // A deworming has no validity, a vaccination's diseases come with it.
    expect(row(2).queryByLabelText('Valid until')).toBeNull();
    expect(row(1).queryByRole('group', { name: 'Protects against' })).toBeNull();
    type(2, 'Type', 'Vaccination');
    expect(row(2).getByRole('group', { name: 'Protects against' })).toBeTruthy();
    expect(date).toBeTruthy();
  });

  it('saves each row as its own record with its own request id; the saved rows leave the table', async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/records/import`);
    await screen.findByRole('group', { name: 'Record 1' });
    const first = addDays(server.world.today, -700);
    type(1, 'Date', first);
    fireEvent.click(
      within(await screen.findByRole('group', { name: 'Record 1' })).getByRole('checkbox', { name: 'Rabies' }),
    );
    type(1, 'Product', 'Nobivac Rabies');
    type(1, 'Batch number', 'B-1');
    type(1, 'Valid until', addDays(first, 365));
    type(1, 'Vet', 'Dr. Petrova');
    fireEvent.keyDown(row(1).getByLabelText('Vet'), { key: 'Enter' });
    await waitFor(() => expect(screen.getByRole('group', { name: 'Record 2' })).toBeTruthy());
    type(2, 'Date', addDays(first, 365));
    type(2, 'Batch number', 'B-2');
    fireEvent.click(screen.getByRole('button', { name: 'Add row' }));
    type(3, 'Type', 'Echinococcus');
    type(3, 'Date', addDays(first, 400));
    type(3, 'Time', '14:30');
    fireEvent.click(screen.getByRole('button', { name: 'Save 3 records' }));

    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/health`));
    expect(await screen.findByText('3 records added to the history.')).toBeTruthy();
    const sent = server.calls('POST', PATH).map((call) => call.body as CareRecordRequest);
    expect(sent.map((body) => [body.kind, body.title, body.performedOn, body.batchNumber])).toEqual([
      ['Vaccination', 'Rabies', first, 'B-1'],
      ['Vaccination', 'Rabies', addDays(first, 365), 'B-2'],
      ['Echinococcus', 'Echinococcus treatment', addDays(first, 400), null],
    ]);
    expect(sent[1]).toMatchObject({ product: 'Nobivac Rabies', veterinarian: 'Dr. Petrova', targets: ['Rabies'] });
    expect(sent[2]).toMatchObject({ performedTime: '14:30:00', targets: [] });
    expect(new Set(sent.map((body) => body.requestId)).size).toBe(3);
    // In the passport's sections too.
    expect(
      server.world.households.get(HOME)!.records.filter((item) => item.batchNumber?.startsWith('B-')),
    ).toHaveLength(2);
  });

  it('keeps the rows that failed with the reason; saving again adds nothing twice', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    let tries = 0;
    server.respond('POST', PATH, (request) => {
      tries += 1;
      if (tries !== 2) return undefined;
      // The second row reaches the server, which adds it; the answer is lost on the way back.
      const body = request.body as CareRecordRequest;
      const added = record('lost-on-the-way', MURKA, { ...body, targets: body.targets ?? [], files: [] });
      home.records.push(added);
      server.world.requestIds.set(body.requestId!, added.id);
      throw new TypeError('Failed to fetch');
    });
    const { router } = renderApp(`/pets/${MURKA}/records/import`, { server });
    await screen.findByRole('group', { name: 'Record 1' });
    for (const [number, batch] of [
      [1, 'A'],
      [2, 'LOST'],
      [3, 'C'],
    ] as const) {
      if (number > 1) fireEvent.click(await screen.findByRole('button', { name: 'Add row' }));
      type(number, 'Date', addDays(server.world.today, -100 * number));
      type(number, 'Batch number', batch);
    }
    fireEvent.click(screen.getByRole('button', { name: 'Save 3 records' }));

    // Row 1 saved and left; row 2 lost its answer (it may have been saved: the retry checks), and row 3, after it,
    // waits, not sent.
    expect(
      await screen.findByText("2 rows weren't saved: the reasons are under them. Save again to retry."),
    ).toBeTruthy();
    expect(screen.queryByRole('group', { name: 'Record 3' })).toBeNull();
    expect(row(1).getByLabelText('Batch number')).toHaveProperty('value', 'LOST');
    expect(row(1).getByText(/^No answer from the server: this row may have been saved\./)).toBeTruthy();
    expect(row(2).getByText(/^Not saved\. Can't reach the server/)).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: 'Save 2 records' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/health`));
    const sent = server.calls('POST', PATH).map((call) => call.body as CareRecordRequest);
    // One try for the first row; two for the second, with one request id; one for the third.
    expect(sent.map((body) => body.batchNumber)).toEqual(['A', 'LOST', 'LOST', 'C']);
    expect(sent[1]!.requestId).toBe(sent[2]!.requestId);
    expect(home.records.filter((item) => item.batchNumber === 'LOST')).toHaveLength(1);
  });

  it('shows a field the server refused in its row, and saves the other rows', async () => {
    const server = createTestServer();
    server.respond('POST', PATH, (request) =>
      (request.body as CareRecordRequest).batchNumber === 'BAD'
        ? problem(400, { errors: { batchNumber: ['Not a batch.'] } })
        : undefined,
    );
    renderApp(`/pets/${MURKA}/records/import`, { server });
    await screen.findByRole('group', { name: 'Record 1' });
    type(1, 'Date', addDays(server.world.today, -10));
    type(1, 'Batch number', 'BAD');
    fireEvent.click(await screen.findByRole('button', { name: 'Add row' }));
    type(2, 'Date', addDays(server.world.today, -20));
    type(2, 'Batch number', 'GOOD');
    fireEvent.click(screen.getByRole('button', { name: 'Save 2 records' }));

    expect(await screen.findByText("1 row wasn't saved: the reason is under it. Save again to retry.")).toBeTruthy();
    expect(screen.queryByRole('group', { name: 'Record 2' })).toBeNull();
    expect(row(1).getByText("This value wasn't accepted. Check it.")).toBeTruthy();
    expect(row(1).getByText('Not saved. Check the highlighted fields.')).toBeTruthy();
    expect(row(1).getByLabelText('Batch number').getAttribute('aria-invalid')).toBe('true');
  });
});

// --- Review of part 2: a correction after a lost answer, and the focus when a row goes ---

describe('the bulk entry and what happens meanwhile (review of part 2)', () => {
  it('saves a row corrected after a lost answer once, with the correction', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    let tries = 0;
    server.respond('POST', PATH, async (request) => {
      tries += 1;
      if (tries !== 1) return undefined;
      // The real pretend server adds it; the answer is lost.
      await server.fetch(
        new Request(`http://localhost${PATH}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: request.authorization!, 'X-Household': HOME },
          body: JSON.stringify(request.body),
        }),
      );
      throw new TypeError('Failed to fetch');
    });
    const { router } = renderApp(`/pets/${MURKA}/records/import`, { server });
    await screen.findByRole('group', { name: 'Record 1' });
    type(1, 'Date', '2025-03-01');
    type(1, 'Batch number', 'B-0');
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 record' }));
    expect(await screen.findByText(/1 row wasn't saved/)).toBeTruthy();
    expect(row(1).getByText(/^No answer from the server: this row may have been saved\./)).toBeTruthy();
    type(1, 'Batch number', 'B-1');
    fireEvent.click(screen.getByRole('button', { name: 'Save 1 record' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/health`));
    expect(home.records.filter((item) => item.performedOn === '2025-03-01').map((item) => item.batchNumber)).toEqual([
      'B-1',
    ]);
  });

  it('a removed row hands the focus to the row now in its place', async () => {
    renderApp(`/pets/${MURKA}/records/import`);
    await screen.findByRole('group', { name: 'Record 1' });
    fireEvent.click(screen.getByRole('button', { name: 'Add row' }));
    await screen.findByRole('group', { name: 'Record 2' });
    const remove = row(1).getByRole('button', { name: 'Remove row 1' });
    remove.focus();
    fireEvent.click(remove);
    await waitFor(() => expect(screen.queryByRole('group', { name: 'Record 2' })).toBeNull());
    expect(window.document.activeElement).toBe(row(1).getByRole('button', { name: 'Remove row 1' }));
  });
});
