// The item form: kilograms and litres kept in grams and millilitres, the daily use from the feedings or by hand ("a
// package lasts N days", "so much a day"), what is there now (adding only), its checks before saving, a barcode checked
// by its check digit and looked up, the server's refusals under their fields, changing an item, and leaving it.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { SupplyRequest } from '../../api/types';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, problem, supply } from '../../test/server';

const sentOf = (server: ReturnType<typeof createTestServer>, method = 'POST', path = '/api/v1/supplies') =>
  server.calls(method, path)[0]!.body as SupplyRequest;
const usage = () => within(screen.getByRole('group', { name: 'Daily use' }));

/** The first new item goes through, but its answer is lost on the way back. */
function loseFirstAnswer(server: ReturnType<typeof createTestServer>) {
  let tries = 0;
  server.respond('POST', '/api/v1/supplies', async (request) => {
    tries += 1;
    if (tries !== 1) return undefined;
    await server.fetch(
      new Request('http://localhost/api/v1/supplies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: request.authorization!, 'X-Household': HOME },
        body: JSON.stringify(request.body),
      }),
    );
    throw new TypeError('Failed to fetch');
  });
}
const kinds = () => within(screen.getByRole('group', { name: 'Kind' }));

describe('a new item', () => {
  it('takes a bag of dry food in kilograms, counted from the feedings, with the bag just bought', async () => {
    const { server, router } = renderApp('/supplies/new');
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Purina One' } });
    fireEvent.change(screen.getByLabelText('Brand'), { target: { value: 'Purina' } });
    // Dry food is counted in kilograms from the feedings, by default.
    expect(kinds().getByRole('radio', { name: 'Dry food' })).toHaveProperty('checked', true);
    expect(screen.getByLabelText('Unit')).toHaveProperty('value', 'kilogram');
    expect(usage().getByRole('radio', { name: 'From feedings' })).toHaveProperty('checked', true);
    fireEvent.change(screen.getByLabelText('Package size'), { target: { value: '1,5' } });
    fireEvent.change(screen.getByLabelText('Energy, kcal/kg'), { target: { value: '3800' } });
    // What is there now: the bag just bought, and half of the open one.
    expect(screen.getByRole('checkbox', { name: 'Say how much there is now' })).toHaveProperty('checked', true);
    fireEvent.change(screen.getByLabelText('Open package: about 0%'), { target: { value: '5' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/supplies\/[0-9a-f-]{36}$/));
    const sent = sentOf(server);
    expect(sent).toMatchObject({
      name: 'Purina One',
      brand: 'Purina',
      category: 'DryFood',
      unit: 'Gram',
      packageSize: 1500,
      kcalPerKg: 3800,
      usageMode: 'Feeding',
      manualDailyUsage: null,
      leadTimeDays: 5,
      initialStock: 2250,
      active: null,
      dataSource: null,
    });
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(await screen.findByRole('heading', { level: 1, name: 'Purina One' })).toBeTruthy();
  });

  it('takes litter by hand as "a package lasts N days", and another item in litres "so much a day"', async () => {
    const { server } = renderApp('/supplies/new');
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Pine pellets' } });
    fireEvent.click(kinds().getByRole('radio', { name: 'Litter' }));
    // Litter is counted by hand: there are no feedings of it.
    expect(usage().queryByRole('radio', { name: 'From feedings' })).toBeNull();
    expect(usage().getByRole('radio', { name: 'A package lasts' })).toHaveProperty('checked', true);
    fireEvent.change(screen.getByLabelText('Package size'), { target: { value: '10' } });
    expect(screen.getByText('How many days one package (10 kg) lasts')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Days one package lasts'), { target: { value: '30' } });
    fireEvent.click(screen.getByRole('checkbox', { name: 'Say how much there is now' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/supplies')).toHaveLength(1));
    const litter = sentOf(server);
    expect(litter).toMatchObject({ category: 'Litter', unit: 'Gram', packageSize: 10_000, usageMode: 'Manual' });
    expect(litter.manualDailyUsage).toBeCloseTo(333.3333, 3);
    expect(litter.initialStock).toBeNull();
    expect(litter.kcalPerKg).toBeNull();
  });

  it('keeps litres in millilitres; a use a day is in the base unit', async () => {
    const { server } = renderApp('/supplies/new');
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Oatmeal shampoo' } });
    fireEvent.click(kinds().getByRole('radio', { name: 'Other' }));
    fireEvent.change(screen.getByLabelText('Unit'), { target: { value: 'liter' } });
    fireEvent.change(screen.getByLabelText('Package size'), { target: { value: '0,5' } });
    fireEvent.click(usage().getByRole('radio', { name: 'Per day' }));
    fireEvent.change(screen.getByLabelText('Used a day, ml'), { target: { value: '12,5' } });
    // Two unopened bottles.
    fireEvent.click(screen.getByRole('button', { name: 'Unopened packages of 500 ml: more' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/supplies')).toHaveLength(1));
    expect(sentOf(server)).toMatchObject({
      category: 'Other',
      unit: 'Milliliter',
      packageSize: 500,
      usageMode: 'Manual',
      manualDailyUsage: 12.5,
      initialStock: 1000,
    });
  });

  it('checks the form before saving', async () => {
    const { server } = renderApp('/supplies/new');
    fireEvent.change(await screen.findByLabelText('Barcode'), { target: { value: '4600699503410' } });
    fireEvent.change(screen.getByLabelText('Energy, kcal/kg'), { target: { value: '20000' } });
    fireEvent.change(screen.getByLabelText('Days for delivery'), { target: { value: '61' } });
    fireEvent.change(screen.getByLabelText('Where to buy'), { target: { value: 'shop.example/food' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Check the highlighted fields.')).toBeTruthy();
    expect(screen.getByText("Check the barcode's digits")).toBeTruthy();
    expect(screen.getByText('Enter a name')).toBeTruthy();
    expect(screen.getByText('A number above 0')).toBeTruthy();
    expect(screen.getByText('A number from 1 to 10,000')).toBeTruthy();
    expect(screen.getByText('Use 0 to 60 days')).toBeTruthy();
    expect(screen.getByText('Use a link starting with https:// or http://')).toBeTruthy();
    expect(screen.getByLabelText('Name').getAttribute('aria-invalid')).toBe('true');
    // The first wrong field has the focus.
    expect(window.document.activeElement).toBe(screen.getByLabelText('Barcode'));
    expect(server.calls('POST', '/api/v1/supplies')).toHaveLength(0);
  });

  it("shows the server's refusal under its field, and a barcode already in supplies in words", async () => {
    const server = createTestServer();
    server.respond('POST', '/api/v1/supplies', () => problem(400, { errors: { storeUrl: ['Not a web address.'] } }), {
      once: true,
    });
    renderApp('/supplies/new', { server });
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Royal Canin again' } });
    fireEvent.change(screen.getByLabelText('Package size'), { target: { value: '2' } });
    fireEvent.change(screen.getByLabelText('Where to buy'), { target: { value: 'https://shop.example/rc' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("This value wasn't accepted. Check it.")).toBeTruthy();
    expect(screen.getByLabelText('Where to buy').getAttribute('aria-invalid')).toBe('true');

    // The barcode of the household's own Royal Canin.
    fireEvent.change(screen.getByLabelText('Barcode'), { target: { value: '4600699503415' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('An item with this barcode is in supplies already')).toBeTruthy();
    expect(screen.getByLabelText('Barcode').getAttribute('aria-invalid')).toBe('true');
  });

  it('a correction typed between a lost answer and the retry follows the item the first try made', async () => {
    const server = createTestServer();
    loseFirstAnswer(server);
    const { router } = renderApp('/supplies/new', { server });
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Purina Oen' } });
    fireEvent.change(screen.getByLabelText('Package size'), { target: { value: '1,5' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Name'), { target: { value: 'Purina One' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/supplies\/[0-9a-f-]{36}$/));
    const home = server.world.households.get(HOME)!;
    expect(home.supplies.filter((item) => item.name.startsWith('Purina')).map((item) => item.name)).toEqual([
      'Purina One',
    ]);
    // The stock entered once, with the item.
    const made = home.supplies.find((item) => item.name === 'Purina One')!;
    expect(home.stock.filter((entry) => entry.supplyId === made.id)).toHaveLength(1);
  });

  it('what is there now, corrected between a lost answer and the retry, is the count the item ends up with', async () => {
    const server = createTestServer();
    loseFirstAnswer(server);
    const { router } = renderApp('/supplies/new', { server });
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Purina One' } });
    fireEvent.change(screen.getByLabelText('Package size'), { target: { value: '1,5' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    // Half of the open bag is left as well.
    fireEvent.change(screen.getByLabelText('Open package: about 0%'), { target: { value: '5' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/supplies\/[0-9a-f-]{36}$/));
    const home = server.world.households.get(HOME)!;
    const made = home.supplies.filter((item) => item.name === 'Purina One');
    expect(made).toHaveLength(1);
    // One count, the one on screen: the first try's 1.5 kg went.
    expect(home.stock.filter((entry) => entry.supplyId === made[0]!.id).map((entry) => entry.quantity)).toEqual([2250]);
  });

  it('asks before leaving what was typed', async () => {
    const { router } = renderApp('/supplies/new');
    fireEvent.change(await screen.findByLabelText('Name'), { target: { value: 'Treats' } });
    fireEvent.click(within(screen.getByRole('navigation', { name: 'Sections' })).getByRole('link', { name: 'Today' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Leave' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/today'));
  });
});

describe('a barcode typed in', () => {
  it('finds a product of Open Pet Food Facts and fills in what is known', async () => {
    const { server } = renderApp('/supplies/new');
    fireEvent.change(await screen.findByLabelText('Barcode'), { target: { value: '5901234123457' } });
    fireEvent.click(screen.getByRole('button', { name: 'Find' }));
    expect(await screen.findByText('Details from Open Pet Food Facts (ODbL licence). Check them.')).toBeTruthy();
    expect(server.calls('GET', '/api/v1/products/lookup')[0]!.query.get('code')).toBe('5901234123457');
    expect(screen.getByLabelText('Name')).toHaveProperty('value', 'Purina One Sterilcat');
    expect(screen.getByLabelText('Brand')).toHaveProperty('value', 'Purina');
    expect(screen.getByLabelText('Package size')).toHaveProperty('value', '1.5');
    expect(screen.getByLabelText('Unit')).toHaveProperty('value', 'kilogram');
    expect(screen.getByLabelText('Energy, kcal/kg')).toHaveProperty('value', '3800');
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/supplies')).toHaveLength(1));
    expect(sentOf(server)).toMatchObject({
      barcode: '5901234123457',
      name: 'Purina One Sterilcat',
      packageSize: 1500,
      dataSource: 'OpenPetFoodFacts',
    });
  });

  it("says when it is the household's own item, a name only, nothing, or not a barcode's digits", async () => {
    const { server } = renderApp('/supplies/new');
    const field = await screen.findByLabelText('Barcode');
    const find = (code: string) => {
      fireEvent.change(field, { target: { value: code } });
      // Enter in the barcode looks it up.
      fireEvent.keyDown(field, { key: 'Enter' });
    };
    find('4600699503415');
    expect(await screen.findByText('This product is in your supplies already: Royal Canin Sterilised.')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Open the item' }).getAttribute('href')).toBe('/supplies/supply-food');

    find('4006381333931');
    expect(await screen.findByText('The name comes from UPCitemdb. Add the package size.')).toBeTruthy();
    expect(screen.getByLabelText('Name')).toHaveProperty('value', 'Whiskas pouches');

    find('7613031351107');
    expect(await screen.findByText('No product with this barcode was found. Fill in the details.')).toBeTruthy();

    const asked = server.calls('GET', '/api/v1/products/lookup').length;
    find('7613031351100');
    expect(await screen.findByText("Check the barcode's digits")).toBeTruthy();
    expect(server.calls('GET', '/api/v1/products/lookup')).toHaveLength(asked);
    expect(server.calls('POST', '/api/v1/supplies')).toHaveLength(0);
  });
});

describe('changing an item', () => {
  it('opens with its values in the units they read best in, and sends them back with the change', async () => {
    const { server, router } = renderApp('/supplies/supply-food/edit');
    expect(await screen.findByLabelText('Package size')).toHaveProperty('value', '2');
    expect(screen.getByLabelText('Unit')).toHaveProperty('value', 'kilogram');
    expect(usage().getByRole('radio', { name: 'From feedings' })).toHaveProperty('checked', true);
    // What is there now is said with "Bought" and "Correct the stock", not here.
    expect(screen.queryByRole('checkbox', { name: 'Say how much there is now' })).toBeNull();
    fireEvent.change(screen.getByLabelText('Name'), { target: { value: 'Royal Canin Sterilised 37' } });
    fireEvent.click(screen.getByRole('checkbox', { name: 'Still buying' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/supplies/supply-food'));
    expect(sentOf(server, 'PUT', '/api/v1/supplies/supply-food')).toMatchObject({
      name: 'Royal Canin Sterilised 37',
      brand: 'Royal Canin',
      barcode: '4600699503415',
      unit: 'Gram',
      packageSize: 2000,
      usageMode: 'Feeding',
      active: false,
      initialStock: null,
      requestId: null,
    });
    // The feeding that gives it is renamed with it.
    const routine = server.world.households.get(HOME)!.routines.find((item) => item.id === 'routine-murka')!;
    expect(routine.food).toBe('Royal Canin Sterilised 37');
  });

  it('shows a daily use by hand as whole days a package lasts when it is that', async () => {
    const server = createTestServer();
    const litter = server.world.households.get(HOME)!.supplies.find((item) => item.id === 'supply-litter')!;
    litter.packageSize = 10_000;
    litter.manualDailyUsage = 333.333333;
    renderApp('/supplies/supply-litter/edit', { server });
    expect(await screen.findByLabelText('Days one package lasts')).toHaveProperty('value', '30');
    expect(usage().getByRole('radio', { name: 'A package lasts' })).toHaveProperty('checked', true);
    expect(screen.getByLabelText('Package size')).toHaveProperty('value', '10');
  });

  it('is not for helpers', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Helper';
    renderApp('/supplies/supply-food/edit', { server });
    expect(await screen.findByRole('heading', { name: "Your role in the group doesn't allow this" })).toBeTruthy();
    expect(screen.queryByLabelText('Name')).toBeNull();
  });
});

describe("the item form after part 3's review", () => {
  it('keeps a daily use typed by hand as it was when the kind changes (300 g a day stays 300 g a day)', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    home.supplies.push(
      supply('supply-sand', {
        name: 'Sand',
        category: 'Litter',
        unit: 'Gram',
        packageSize: 10_000,
        usageMode: 'Manual',
        manualDailyUsage: 300,
      }),
    );
    const { router } = renderApp('/supplies/supply-sand/edit', { server });
    // 10 kg at 300 g a day isn't whole days: it opens as so much a day.
    expect(await screen.findByLabelText('Used a day, g')).toHaveProperty('value', '300');
    expect(usage().getByRole('radio', { name: 'Per day' })).toHaveProperty('checked', true);
    fireEvent.click(kinds().getByRole('radio', { name: 'Other' }));
    expect(usage().getByRole('radio', { name: 'Per day' })).toHaveProperty('checked', true);
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/supplies/supply-sand'));
    const sent = sentOf(server, 'PUT', '/api/v1/supplies/supply-sand');
    expect(sent.category).toBe('Other');
    expect(sent.manualDailyUsage).toBe(300);
  });

  it("keeps another phone's purchase: \"Still buying\" is sent only when changed here", async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    home.supplies.push(supply('supply-old', { name: 'Kitten food', active: false }));
    const { queryClient, router } = renderApp('/supplies/supply-old/edit', { server });
    const notes = await screen.findByLabelText('Notes');
    expect(screen.getByRole('checkbox', { name: 'Still buying' })).toHaveProperty('checked', false);
    // A purchase on the phone brings it back meanwhile, and the form's item is read again (the window's focus).
    home.supplies.find((item) => item.id === 'supply-old')!.active = true;
    await act(async () => {
      await queryClient.invalidateQueries({ queryKey: [HOME, 'supplies'] });
      await new Promise((resolve) => setTimeout(resolve, 20));
    });
    fireEvent.change(notes, { target: { value: 'The big bag' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/supplies/supply-old'));
    expect(sentOf(server, 'PUT', '/api/v1/supplies/supply-old').active).toBeNull();
    expect(home.supplies.find((item) => item.id === 'supply-old')!.active).toBe(true);
  });

  it("drops Open Pet Food Facts as the source when another barcode is typed after \"Find\"", async () => {
    const { server, router } = renderApp('/supplies/new');
    const barcode = await screen.findByLabelText('Barcode');
    fireEvent.change(barcode, { target: { value: '5901234123457' } });
    fireEvent.click(screen.getByRole('button', { name: 'Find' }));
    await waitFor(() => expect(screen.getByLabelText('Name')).toHaveProperty('value', 'Purina One Sterilcat'));
    // Another product's code: the details are the person's now, not that product's.
    fireEvent.change(barcode, { target: { value: '4006381333931' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/supplies\/[^/]+$/));
    expect(sentOf(server)).toMatchObject({ barcode: '4006381333931', dataSource: null });
  });

  it('keeps Open Pet Food Facts as the source for its own barcode', async () => {
    const { server, router } = renderApp('/supplies/new');
    fireEvent.change(await screen.findByLabelText('Barcode'), { target: { value: '5901234123457' } });
    fireEvent.click(screen.getByRole('button', { name: 'Find' }));
    await waitFor(() => expect(screen.getByLabelText('Name')).toHaveProperty('value', 'Purina One Sterilcat'));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/supplies\/[^/]+$/));
    expect(sentOf(server).dataSource).toBe('OpenPetFoodFacts');
  });
});
