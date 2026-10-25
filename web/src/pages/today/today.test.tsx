// Today on the pretend server: the household's feedings, visits, shopping and care, and what the buttons send.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, markedElsewhere, MURKA, problem, stockEntry } from '../../test/server';

afterEach(() => {
  vi.useRealTimers();
});

const region = async (name: string) => within(await screen.findByRole('region', { name }));

/** The feeding row of a pet at a time ("8:00 AM"). */
async function feedingRow(pet: string, time: string) {
  const feeding = await region('Feeding');
  const slot = feeding.getByRole('heading', { name: time }).closest('.slot') as HTMLElement;
  return within(within(slot).getByText(pet).closest('li') as HTMLElement);
}

describe('Today', () => {
  it("shows the day of the household: feedings by time, visits, what to buy and care that is due", async () => {
    const { server } = renderApp('/today');
    const feeding = await region('Feeding');
    expect(feeding.getByRole('heading', { name: '8:00 AM' })).toBeTruthy();
    expect(feeding.getByRole('heading', { name: '7:00 PM' })).toBeTruthy();
    expect(feeding.getAllByText('Royal Canin, 40 g')).toHaveLength(2);

    const visits = await region('Visits');
    expect(visits.getByText(/Yesterday at 10:30 AM · mark how it went/)).toBeTruthy();
    expect(visits.getByText(/at 3:00 PM$/)).toBeTruthy();

    const toBuy = await region('To buy');
    expect(toBuy.getByText('Royal Canin Sterilised')).toBeTruthy();
    expect(toBuy.getByText('Time to buy · enough for about 2 days')).toBeTruthy();

    const overdue = await region('Overdue');
    expect(overdue.getByText('Rabies')).toBeTruthy();
    expect(overdue.getByText(/3 days overdue/)).toBeTruthy();
    expect((await region('Due soon')).getByText('Deworming')).toBeTruthy();
    expect((await region('Later')).getByText('Yearly check-up')).toBeTruthy();

    // For the household's date, named in every request.
    const asked = server.calls('GET', '/api/v1/today')[0]!;
    expect(asked.query.get('date')).toBe(server.world.today);
    expect(asked.household).toBe(HOME);
  });

  it('marks a feeding, then takes the mark back after asking', async () => {
    const { server } = renderApp('/today');
    const row = await feedingRow('Murka', '8:00 AM');
    fireEvent.click(row.getByRole('button', { name: 'Fed' }));
    const mark = await row.findByRole('button', { name: /^Fed at .+\. Take back$/ });
    expect(server.calls('POST', '/api/v1/routines/routine-murka/completions')[0]!.body).toEqual({
      date: server.world.today,
      time: '08:00:00',
      status: 'Done',
    });

    fireEvent.click(mark);
    const dialog = within(await screen.findByRole('dialog', { name: 'Murka: take the mark back?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Take back' }));
    expect(await row.findByRole('button', { name: 'Fed' })).toBeTruthy();
    expect(server.calls('DELETE', /^\/api\/v1\/routines\/routine-murka\/completions\/.+/)).toHaveLength(1);
  });

  it('says who marked a feeding first when someone else did', async () => {
    const { server } = renderApp('/today');
    const row = await feedingRow('Murka', '8:00 AM');
    // Boris feeds Murka on his phone while Today is open here.
    markedElsewhere(server.world, 'routine-murka', '08:00:00', 'Boris');
    fireEvent.click(row.getByRole('button', { name: 'Fed' }));
    expect(await screen.findByText('Already marked: Boris, 8:02 AM')).toBeTruthy();
    expect(row.getByText('Marked by Boris')).toBeTruthy();
    // A helper takes back only their own marks; Anna owns the household and may take back Boris's.
    expect(row.getByRole('button', { name: /^Fed at 8:02 AM\. Take back$/ })).toBeTruthy();
  });

  it('skips a feeding on purpose, after asking', async () => {
    const { server } = renderApp('/today');
    const row = await feedingRow('Murka', '7:00 PM');
    fireEvent.click(row.getByRole('button', { name: 'Skip' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Murka: skip this feeding?' }));
    expect(dialog.getByText('The 7:00 PM feeding will be marked as skipped, with no reminder.')).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Skip' }));
    expect(await row.findByText(/^Skipped, /)).toBeTruthy();
    expect(server.calls('POST', '/api/v1/routines/routine-murka/completions')[0]!.body).toMatchObject({
      time: '19:00:00',
      status: 'Skipped',
    });
  });

  it('feeds everyone at a time at once', async () => {
    const { server } = renderApp('/today');
    const feeding = await region('Feeding');
    fireEvent.click(feeding.getByRole('button', { name: 'All fed' }));
    await waitFor(() => expect(server.calls('POST', /\/completions$/)).toHaveLength(2));
    expect(server.calls('POST', /\/completions$/).map((call) => call.path)).toEqual([
      '/api/v1/routines/routine-murka/completions',
      '/api/v1/routines/routine-rex/completions',
    ]);
    await waitFor(() => expect(feeding.queryByRole('button', { name: 'All fed' })).toBeNull());
  });

  it('marks a plan done with the date and the product, and says when it is next', async () => {
    const { server } = renderApp('/today');
    const overdue = await region('Overdue');
    fireEvent.click(overdue.getByRole('button', { name: 'Done' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Mark as done' }));
    // The plan's usual product is there to start with; a vaccine also has its protection dates.
    expect(await dialog.findByLabelText('Product')).toHaveProperty('value', 'Nobivac Rabies');
    expect(dialog.getByLabelText('Valid until')).toBeTruthy();
    expect(dialog.queryByLabelText('Time')).toBeNull();
    expect(dialog.getByText('Every year from this date')).toBeTruthy();

    fireEvent.change(dialog.getByLabelText('Batch number'), { target: { value: 'A123' } });
    fireEvent.change(dialog.getByLabelText('Clinic'), { target: { value: 'Vet+' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));

    expect(await screen.findByText(/^Marked as done\. Next time: /)).toBeTruthy();
    const sent = server.calls('POST', '/api/v1/care-plans/plan-rabies/complete')[0]!.body as Record<string, unknown>;
    expect(sent).toMatchObject({
      performedOn: server.world.today,
      product: 'Nobivac Rabies',
      batchNumber: 'A123',
      clinic: 'Vet+',
      manufacturer: null,
      nextDueOn: null,
    });
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('shows a field the server refused under the field', async () => {
    const server = createTestServer();
    server.respond('POST', '/api/v1/care-plans/plan-deworm/complete', () =>
      problem(400, { errors: { batchNumber: ['At most 50 characters.'] } }),
    );
    renderApp('/today', { server });
    fireEvent.click((await region('Due soon')).getByRole('button', { name: 'Done' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Mark as done' }));
    fireEvent.click(await dialog.findByRole('button', { name: 'Save' }));
    expect(await dialog.findByText("This value wasn't accepted. Check it.")).toBeTruthy();
    expect(dialog.getByLabelText('Batch number').getAttribute('aria-invalid')).toBe('true');
    expect(dialog.getByText('Check the highlighted fields.')).toBeTruthy();
  });

  it('records one package bought', async () => {
    const { server } = renderApp('/today');
    const toBuy = await region('To buy');
    fireEvent.click(toBuy.getByRole('button', { name: 'Bought' }));
    expect(await screen.findByText('Purchase saved')).toBeTruthy();
    const sent = server.calls('POST', '/api/v1/supplies/supply-food/stock-events')[0]!.body;
    expect(sent).toMatchObject({ kind: 'Purchase', quantity: 2000 });
    // Bought: it leaves the list.
    await waitFor(() => expect(screen.queryByRole('region', { name: 'To buy' })).toBeNull());
  });

  it('asks the server again every 30 seconds', async () => {
    vi.useFakeTimers({
      toFake: ['setInterval', 'clearInterval', 'setTimeout', 'clearTimeout'],
      shouldAdvanceTime: true,
    });
    const { server } = renderApp('/today');
    await screen.findByRole('region', { name: 'Feeding' });
    const asked = () => server.calls('GET', '/api/v1/today').length;
    expect(asked()).toBe(1);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(30_000);
    });
    await waitFor(() => expect(asked()).toBe(2));
  });

  it('says when the server is out of reach, and comes back with it', async () => {
    const server = createTestServer();
    server.respond(
      'GET',
      '/api/v1/pets',
      () => {
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    server.respond(
      'GET',
      '/health',
      () => {
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp('/pets', { server });
    const banner = await screen.findByText('No connection to the server');
    expect(await screen.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();

    fireEvent.click(within(banner.closest('.offline') as HTMLElement).getByRole('button', { name: 'Try again' }));
    // Still down: the strip stays.
    await waitFor(() => expect(server.calls('GET', '/health')).toHaveLength(1));
    expect(screen.getByText('No connection to the server')).toBeTruthy();

    fireEvent.click(within(banner.closest('.offline') as HTMLElement).getByRole('button', { name: 'Try again' }));
    await waitFor(() => expect(screen.queryByText('No connection to the server')).toBeNull());
    // Back: the page loads again.
    expect(await screen.findByText('Murka')).toBeTruthy();
  });

  it('opens the pet of a plan', async () => {
    const { router } = renderApp('/today');
    fireEvent.click((await region('Overdue')).getByRole('link', { name: 'Murka' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}`));
  });
});

// --- Review of part 1 (P8, P10, P13, and Today's failed reloads) ---

function hold() {
  let release!: () => void;
  const promise = new Promise<void>((resolve) => (release = resolve));
  return { promise, release };
}

describe('Today, kept steady (review)', () => {
  it('"Fed" pressed from the keyboard keeps the focus in the row: on the mark (P8)', async () => {
    renderApp('/today');
    const row = await feedingRow('Murka', '8:00 AM');
    const fed = row.getByRole('button', { name: 'Fed' });
    fed.focus();
    fireEvent.click(fed);
    const mark = await row.findByRole('button', { name: /^Fed at .+\. Take back$/ });
    await waitFor(() => expect(document.activeElement).toBe(mark));
  });

  it('the focus goes to the next row when a bought supply leaves the list (P8)', async () => {
    const server = createTestServer();
    // The litter runs out too: 150 g left at 100 g a day.
    const home = server.world.households.get(HOME)!;
    home.supplies.find((item) => item.id === 'supply-litter')!.manualDailyUsage = 100;
    home.stock.push(stockEntry('supply-litter', 'Adjustment', 150));
    renderApp('/today', { server });
    const toBuy = await region('To buy');
    const bought = toBuy.getAllByRole('button', { name: 'Bought' })[0]!;
    bought.focus();
    fireEvent.click(bought);
    await waitFor(() => expect(toBuy.getAllByRole('button', { name: 'Bought' })).toHaveLength(1));
    await waitFor(() => expect(document.activeElement).toBe(toBuy.getByRole('button', { name: 'Bought' })));
  });

  it('Esc with typed input in "Done" asks first (P10)', async () => {
    renderApp('/today');
    fireEvent.click((await region('Overdue')).getByRole('button', { name: 'Done' }));
    const element = await screen.findByRole('dialog', { name: 'Mark as done' });
    fireEvent.change(await within(element).findByLabelText('Batch number'), { target: { value: 'A123' } });
    fireEvent.change(within(element).getByLabelText('Notes'), { target: { value: 'Left shoulder' } });
    fireEvent(element, new Event('cancel', { cancelable: true }));
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Cancel' }));
    expect(screen.getByDisplayValue('A123')).toBeTruthy();
    // "Cancel" in the dialog asks too; "Leave" closes it.
    fireEvent.click(within(element).getByRole('button', { name: 'Cancel' }));
    const again = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(again.getByRole('button', { name: 'Leave' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Mark as done' })).toBeNull());
  });

  it('a dialog the browser closes while it saves opens again, so its answer is seen (P13)', async () => {
    const server = createTestServer();
    const wait = hold();
    server.respond(
      'POST',
      '/api/v1/care-plans/plan-rabies/complete',
      async () => {
        await wait.promise;
        return problem(500);
      },
      { once: true },
    );
    renderApp('/today', { server });
    const overdue = await region('Overdue');
    fireEvent.click(overdue.getByRole('button', { name: 'Done' }));
    const element = (await screen.findByRole('dialog', { name: 'Mark as done' })) as HTMLDialogElement;
    fireEvent.click(await within(element).findByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/care-plans/plan-rabies/complete')).toHaveLength(1));
    // Chrome: a second Esc can't be stopped, and the dialog closes.
    fireEvent(element, new Event('cancel', { cancelable: true }));
    fireEvent(element, new Event('cancel', { cancelable: false }));
    element.close();
    fireEvent(element, new Event('close'));
    expect(element.hasAttribute('open')).toBe(true);
    await act(async () => wait.release());
    expect(await within(element).findByText('Something went wrong on our side. Try again in a moment.')).toBeTruthy();
    expect(element.hasAttribute('open')).toBe(true);
  });

  it('a reload that fails keeps the day on screen, under the reason', async () => {
    const server = createTestServer();
    renderApp('/today', { server });
    await region('Feeding');
    server.respond('GET', '/api/v1/today', () => problem(500, { traceId: 'trace-9' }));
    act(() => {
      window.dispatchEvent(new Event('visibilitychange'));
    });
    expect(await screen.findByText('Error ID: trace-9')).toBeTruthy();
    expect(screen.getByRole('region', { name: 'Feeding' })).toBeTruthy();
  });
});

describe('"Bought" after part 3\'s review', () => {
  it('retries a lost "Bought" as the same purchase within a minute, and later as a new one', async () => {
    const server = createTestServer();
    const STOCK = '/api/v1/supplies/supply-food/stock-events';
    server.respond('POST', STOCK, () => {
      throw new TypeError('Failed to fetch');
    });
    renderApp('/today', { server });
    const toBuy = await region('To buy');
    const now = Date.now();
    const clock = vi.spyOn(Date, 'now').mockReturnValue(now);
    const buy = async (count: number) => {
      fireEvent.click(await toBuy.findByRole('button', { name: 'Bought' }));
      await waitFor(() => expect(server.calls('POST', STOCK)).toHaveLength(count));
      await toBuy.findByRole('button', { name: 'Bought' });
    };
    const ids = () => server.calls('POST', STOCK).map((call) => (call.body as { requestId: string }).requestId);
    await buy(1);
    clock.mockReturnValue(now + 30_000);
    await buy(2);
    // A minute after the lost one: another purchase, with an id of its own.
    clock.mockReturnValue(now + 95_000);
    await buy(3);
    clock.mockRestore();
    const [first, retry, later] = ids();
    expect(retry).toBe(first);
    expect(later).not.toBe(first);
  });
});
