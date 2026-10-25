// Supplies: the list grouped as on the phone with each one's estimate; "Bought" in packages and "Correct the stock",
// each with a request id kept across tries; an item's page (the forecast, the feedings that give it, its details, its
// history with "Take back"); stopping buying and deleting after asking; what helpers may do.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { StockEventRequest, SupplyRequest } from '../../api/types';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, MURKA, stockEntry, supply } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));
const STOCK = '/api/v1/supplies/supply-food/stock-events';

/** The test world with an item in every group: wet food running out soon, pills plenty, kitten food no longer bought. */
function worldWithEveryGroup() {
  const server = createTestServer();
  const home = server.world.households.get(HOME)!;
  home.supplies.push(
    supply('supply-wet', {
      name: 'Wet pouches',
      category: 'WetFood',
      unit: 'Piece',
      packageSize: 12,
      usageMode: 'Manual',
      manualDailyUsage: 1,
      leadTimeDays: 2,
    }),
    supply('supply-pills', {
      name: 'Milbemax',
      category: 'Medication',
      unit: 'Dose',
      packageSize: 4,
      usageMode: 'Manual',
      manualDailyUsage: 4 / 90,
    }),
    supply('supply-old', { name: 'Kitten food', active: false }),
  );
  home.stock.push(stockEntry('supply-wet', 'Adjustment', 8), stockEntry('supply-pills', 'Purchase', 4));
  return server;
}

/** Retries after a lost answer: the first try reaches the server, the answer is lost. */
function loseFirstAnswer(server: ReturnType<typeof createTestServer>, path: string) {
  let tries = 0;
  server.respond('POST', path, async (request) => {
    tries += 1;
    if (tries !== 1) return undefined;
    await server.fetch(
      new Request(`http://localhost${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: request.authorization!, 'X-Household': HOME },
        body: JSON.stringify(request.body),
      }),
    );
    throw new TypeError('Failed to fetch');
  });
}

describe('the supplies list', () => {
  it('groups the items as the phone does, each with how long it lasts', async () => {
    const server = worldWithEveryGroup();
    renderApp('/supplies', { server });
    const toBuy = await region('To buy');
    expect(toBuy.getByRole('link', { name: 'Royal Canin Sterilised' })).toBeTruthy();
    expect(toBuy.getByText('Royal Canin')).toBeTruthy();
    expect(toBuy.getByText('Time to buy · enough for about 2 days')).toBeTruthy();
    expect(toBuy.getByRole('button', { name: 'Bought' })).toBeTruthy();
    const soon = await region('Running out soon');
    expect(soon.getByRole('link', { name: 'Wet pouches' })).toBeTruthy();
    expect(soon.getByText(/^Buy by .+ · enough for about 8 days$/)).toBeTruthy();
    const inStock = await region('In stock');
    expect(inStock.getAllByRole('link').map((link) => link.textContent)).toEqual(['Clumping litter', 'Milbemax']);
    expect(inStock.getByText('Stock not entered')).toBeTruthy();
    expect(inStock.getByText('Enough for about 90 days')).toBeTruthy();
    expect(inStock.queryByRole('button', { name: 'Bought' })).toBeNull();
    const notBought = await region('No longer bought');
    expect(notBought.getByRole('link', { name: 'Kitten food' })).toBeTruthy();
    // Sections in the phone's order.
    expect(screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual([
      'To buy',
      'Running out soon',
      'In stock',
      'No longer bought',
    ]);
  });

  it('"Bought" takes packages; the item moves on to "In stock"', async () => {
    const { server } = renderApp('/supplies');
    fireEvent.click((await region('To buy')).getByRole('button', { name: 'Bought' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Bought: Royal Canin Sterilised' }));
    const packages = dialog.getByLabelText('Packages of 2 kg');
    expect(packages).toHaveProperty('value', '1');
    // Never fewer than one package.
    expect(dialog.getByRole('button', { name: 'Packages of 2 kg: fewer' }).getAttribute('aria-disabled')).toBe('true');
    fireEvent.click(dialog.getByRole('button', { name: 'Packages of 2 kg: more' }));
    expect(packages).toHaveProperty('value', '2');
    fireEvent.click(dialog.getByRole('button', { name: 'Save the purchase' }));
    expect(await screen.findByText('Purchase saved')).toBeTruthy();
    const sent = server.calls('POST', STOCK)[0]!.body as StockEventRequest;
    expect(sent).toMatchObject({ kind: 'Purchase', quantity: 4000 });
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(await (await region('In stock')).findByRole('link', { name: 'Royal Canin Sterilised' })).toBeTruthy();
    expect(screen.queryByRole('region', { name: 'To buy' })).toBeNull();
  });

  it('a purchase retried after a lost answer keeps its request id and counts once', async () => {
    const server = createTestServer();
    loseFirstAnswer(server, STOCK);
    renderApp('/supplies', { server });
    fireEvent.click((await region('To buy')).getByRole('button', { name: 'Bought' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Bought: Royal Canin Sterilised' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Save the purchase' }));
    expect(await dialog.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Save the purchase' }));
    expect(await screen.findByText('Purchase saved')).toBeTruthy();
    const tries = server.calls('POST', STOCK).map((call) => (call.body as StockEventRequest).requestId);
    // Our two tries (the lost one passed through to the server once more).
    expect(new Set(tries).size).toBe(1);
    const home = server.world.households.get(HOME)!;
    expect(home.stock.filter((entry) => entry.supplyId === 'supply-food' && entry.kind === 'Purchase')).toHaveLength(2);
  });

  it('a purchase changed between the lost answer and the retry ends up as the amount on screen', async () => {
    const server = createTestServer();
    loseFirstAnswer(server, STOCK);
    renderApp('/supplies', { server });
    fireEvent.click((await region('To buy')).getByRole('button', { name: 'Bought' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Bought: Royal Canin Sterilised' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Save the purchase' }));
    expect(await dialog.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    // Two bags, in fact.
    fireEvent.click(dialog.getByRole('button', { name: 'Packages of 2 kg: more' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Save the purchase' }));
    expect(await screen.findByText('Purchase saved')).toBeTruthy();
    const home = server.world.households.get(HOME)!;
    const bought = home.stock.filter((entry) => entry.supplyId === 'supply-food' && entry.kind === 'Purchase');
    // The purchase a month ago, and today's: two bags, once.
    expect(bought.map((entry) => entry.quantity)).toEqual([2000, 4000]);
  });

  it('shows the empty list with what to do, and helpers what will show', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.supplies = [];
    renderApp('/supplies', { server });
    expect(await screen.findByText('No supplies yet')).toBeTruthy();
    expect(screen.getByText("Add food, litter or medicine: the app tells you when it's time to buy.")).toBeTruthy();
    // The ways to add the first item are cards under the words (as on the phone), not the button over the list.
    expect(screen.queryByRole('link', { name: 'Add item' })).toBeNull();
    expect(screen.getByRole('link', { name: 'Find by the barcode' }).getAttribute('href')).toBe(
      '/supplies/new?start=barcode',
    );
    expect(screen.getByRole('link', { name: 'Fill in by hand' }).getAttribute('href')).toBe('/supplies/new');
    // The photos need AI on the server.
    expect(await screen.findByRole('link', { name: 'Fill in from photos of the package' })).toBeTruthy();
  });
});

describe('an item', () => {
  it('shows the forecast, the feedings that give it, its details and its history', async () => {
    renderApp('/supplies/supply-food');
    expect(await screen.findByRole('heading', { level: 1, name: 'Royal Canin Sterilised' })).toBeTruthy();
    const card = window.document.querySelector('.forecast') as HTMLElement;
    await waitFor(() => expect(within(card).getByText('Enough for about 2 days')).toBeTruthy());
    expect(within(card).getByText('Left: ≈ 200 g (≈ 0.1 pkg)')).toBeTruthy();
    expect(within(card).getByText(/^Runs out around /)).toBeTruthy();
    expect(within(card).getByText(/^Buy by .+ · delivery 5 days$/)).toBeTruthy();
    expect(within(card).getByText('Uses 80 g a day, from the feedings')).toBeTruthy();

    const feedings = await region('Feedings with this food');
    expect(feedings.getByRole('link', { name: 'Murka' }).getAttribute('href')).toBe(`/pets/${MURKA}/feeding`);
    expect(feedings.getByText('40 g × 2 a day')).toBeTruthy();

    const details = await region('Details');
    expect(details.getByText('Dry food')).toBeTruthy();
    expect(details.getByText('2 kg')).toBeTruthy();
    expect(details.getByText('5 days')).toBeTruthy();
    expect(details.getByText('4600699503415')).toBeTruthy();

    const history = await region('Purchases and counts');
    const titles = await history.findAllByText(/^(Bought|Left)/);
    expect(titles.map((title) => title.textContent)).toEqual(['Left: 200 g', 'Bought +2 kg']);
    expect(history.getByText(/· Boris$/)).toBeTruthy();
    expect(history.getByText(/· you$/)).toBeTruthy();
  });

  it('"Correct the stock" starts from the estimate and sends what is there, with a request id of its own', async () => {
    const { server } = renderApp('/supplies/supply-food');
    fireEvent.click(await screen.findByRole('button', { name: 'Bought' }));
    const purchase = within(await screen.findByRole('dialog', { name: 'Bought: Royal Canin Sterilised' }));
    fireEvent.click(purchase.getByRole('button', { name: 'Save the purchase' }));
    await screen.findByText('Purchase saved');
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());

    fireEvent.click(screen.getByRole('button', { name: 'Correct the stock' }));
    const dialog = within(await screen.findByRole('dialog', { name: "What's left: Royal Canin Sterilised" }));
    // 2.2 kg by the estimate: one unopened bag and a tenth of the open one.
    expect(dialog.getByLabelText('Unopened packages of 2 kg')).toHaveProperty('value', '1');
    const open = dialog.getByLabelText('Open package: about 10%');
    fireEvent.change(open, { target: { value: '5' } });
    expect(dialog.getByLabelText('Open package: about 50%').getAttribute('aria-valuetext')).toBe('50%');
    expect(dialog.getByText('In all ≈ 3 kg')).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Stock saved')).toBeTruthy();
    const [bought, counted] = server.calls('POST', STOCK).map((call) => call.body as StockEventRequest);
    expect(counted).toMatchObject({ kind: 'Adjustment', quantity: 3000 });
    expect(counted!.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(counted!.requestId).not.toBe(bought!.requestId);
  });

  it('"None left" counts nothing left, and the item ran out', async () => {
    const { server } = renderApp('/supplies/supply-food');
    fireEvent.click(await screen.findByRole('button', { name: 'Correct the stock' }));
    const dialog = within(await screen.findByRole('dialog', { name: "What's left: Royal Canin Sterilised" }));
    fireEvent.click(dialog.getByRole('button', { name: 'None left' }));
    expect(await screen.findByText('Stock saved')).toBeTruthy();
    expect(server.calls('POST', STOCK)[0]!.body).toMatchObject({ kind: 'Adjustment', quantity: 0 });
    await waitFor(() =>
      expect(within(window.document.querySelector('.forecast') as HTMLElement).getByText('Ran out')).toBeTruthy(),
    );
  });

  it('takes an entry back after asking; the forecast follows', async () => {
    const { server } = renderApp('/supplies/supply-food');
    const history = await region('Purchases and counts');
    fireEvent.click(await history.findByRole('button', { name: /^Take back: Left: 200 g, / }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Take this entry back?' }));
    expect(dialog.getByText('The entry is deleted and the forecast recalculated.')).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Take back' }));
    await waitFor(() =>
      expect(server.calls('DELETE', /^\/api\/v1\/supplies\/supply-food\/stock-events\//)).toHaveLength(1),
    );
    // Counted from the purchase a month ago now: it ran out.
    await waitFor(() =>
      expect(within(window.document.querySelector('.forecast') as HTMLElement).getByText('Ran out')).toBeTruthy(),
    );
    await waitFor(() => expect(history.queryByText('Left: 200 g')).toBeNull());
  });

  it('stops buying after asking, sending the whole item back', async () => {
    const { server } = renderApp('/supplies/supply-food');
    fireEvent.click(await screen.findByRole('button', { name: 'Stop buying' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Stop buying Royal Canin Sterilised?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Stop buying' }));
    expect(await screen.findByText('Moved to “No longer bought”')).toBeTruthy();
    expect(server.calls('PUT', '/api/v1/supplies/supply-food')[0]!.body).toMatchObject({
      name: 'Royal Canin Sterilised',
      brand: 'Royal Canin',
      barcode: '4600699503415',
      packageSize: 2000,
      usageMode: 'Feeding',
      leadTimeDays: 5,
      active: false,
    } satisfies Partial<SupplyRequest>);
    expect(
      await screen.findByText(
        'You no longer buy this item: there are no reminders about it. A purchase brings it back.',
      ),
    ).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Stop buying' })).toBeNull();
  });

  it('deletes after asking; the feeding keeps the food without the link', async () => {
    const { server, router } = renderApp('/supplies/supply-food');
    fireEvent.click(await screen.findByRole('button', { name: 'Delete item' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete Royal Canin Sterilised?' }));
    expect(dialog.getByText("Its purchases and stock are deleted. Feedings keep the food's name.")).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/supplies'));
    expect(server.calls('DELETE', '/api/v1/supplies/supply-food')).toHaveLength(1);
    const routine = server.world.households.get(HOME)!.routines.find((item) => item.id === 'routine-murka')!;
    expect([routine.food, routine.supplyItemId]).toEqual(['Royal Canin', null]);
  });

  it('helpers buy and correct the stock, take back only their own, and change nothing else', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Helper';
    renderApp('/supplies/supply-food', { server });
    expect(await screen.findByRole('button', { name: 'Bought' })).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Correct the stock' })).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Edit' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Stop buying' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Delete item' })).toBeNull();
    const history = await region('Purchases and counts');
    // Anna's purchase is hers; Boris's count isn't.
    expect(await history.findByRole('button', { name: /^Take back: Bought \+2 kg, / })).toBeTruthy();
    expect(history.queryByRole('button', { name: /^Take back: Left: 200 g/ })).toBeNull();
    fireEvent.click(
      within(screen.getByRole('navigation', { name: 'Sections' })).getByRole('link', { name: 'Supplies' }),
    );
    expect(await screen.findByRole('heading', { level: 1, name: 'Supplies' })).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Add item' })).toBeNull();
  });
});

describe("the packages after part 3's review", () => {
  it('can be emptied and typed anew: Backspace over 1, then 3, is 3 packages, not 13', async () => {
    const { server } = renderApp('/supplies');
    const toBuy = await region('To buy');
    fireEvent.click(toBuy.getByRole('button', { name: 'Bought' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Bought: Royal Canin Sterilised' }));
    const packages = dialog.getByLabelText('Packages of 2 kg') as HTMLInputElement;
    fireEvent.change(packages, { target: { value: '' } });
    expect(packages.value).toBe('');
    fireEvent.change(packages, { target: { value: `${packages.value}3` } });
    expect(packages.value).toBe('3');
    fireEvent.click(dialog.getByRole('button', { name: 'Save the purchase' }));
    await screen.findByText('Purchase saved');
    expect((server.calls('POST', STOCK)[0]!.body as StockEventRequest).quantity).toBe(6000);
  });

  it('an emptied field is the least, shown so once the focus leaves', async () => {
    renderApp('/supplies');
    fireEvent.click((await region('To buy')).getByRole('button', { name: 'Bought' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Bought: Royal Canin Sterilised' }));
    const packages = dialog.getByLabelText('Packages of 2 kg') as HTMLInputElement;
    fireEvent.change(packages, { target: { value: '7' } });
    fireEvent.change(packages, { target: { value: '' } });
    fireEvent.blur(packages);
    expect(packages.value).toBe('1');
  });
});
