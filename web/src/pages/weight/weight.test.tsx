// The Weight tab: the latest weight and its change, the chart, the history (a vet's weight opens its record), and
// the weighing dialog: its checks, a retry that keeps its request id, changing and deleting. Helpers only look.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { WeightRequest } from '../../api/types';
import { addDays, addInterval } from '../../lib/dates';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, MURKA, REX, weighing } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));

describe('the Weight tab', () => {
  it('shows the latest weight with its change, the chart and the history; a vet weight opens its record', async () => {
    const { router } = renderApp(`/pets/${MURKA}/weight`);
    const latest = await region('Latest weighing');
    expect(await latest.findByText('4.2')).toBeTruthy();
    expect(latest.getByText(/^\+0\.1 kg since /)).toBeTruthy();
    expect(latest.getByText('BCS 5/9 · ideal 4–5')).toBeTruthy();

    const trend = await region('Trend');
    const chart = trend.getByRole('img', { name: /^Weight chart from / });
    expect(chart.getAttribute('aria-label')).toMatch(
      /3\.85 kg at the start, 4\.2 kg at the end, lowest 3\.85 kg, highest 4\.2 kg\.$/,
    );
    // A vet's weight is a diamond, a weighing a dot: the legend says which.
    expect(trend.getByText('Vet check-up')).toBeTruthy();
    expect(chart.querySelectorAll('circle')).toHaveLength(2);
    expect(chart.querySelectorAll('.weight-chart-vet')).toHaveLength(1);
    // The log is longer than three months: the periods to choose from.
    expect(trend.getByRole('radio', { name: 'All time' })).toHaveProperty('checked', true);
    fireEvent.click(trend.getByRole('radio', { name: '3 months' }));
    expect(trend.getByRole('img', { name: /4\.1 kg at the start/ })).toBeTruthy();

    const history = await region('History');
    expect(history.getAllByRole('button').map((button) => button.textContent)).toEqual(['4.2 kg', '3.85 kg']);
    fireEvent.click(history.getByRole('link', { name: '4.1 kg' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/records/record-exam`));
    expect(await screen.findByRole('heading', { name: 'Check-up', level: 1 })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Murka' }).getAttribute('href')).toBe(`/pets/${MURKA}/weight`);
  });

  it('starts empty, with why and how often to weigh', async () => {
    renderApp(`/pets/${REX}/weight`);
    expect(await screen.findByRole('heading', { name: 'No weighings yet' })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Add weight' }));
    expect(await screen.findByRole('dialog', { name: 'New weighing' })).toBeTruthy();
  });

  it('shows one weight without a chart', async () => {
    const server = createTestServer();
    server.world.households
      .get(HOME)!
      .weights.push(weighing('w-rex', REX, { measuredOn: server.world.today, weightKg: 31 }));
    renderApp(`/pets/${REX}/weight`, { server });
    expect(await (await region('Trend')).findByText('The chart shows after the second weighing.')).toBeTruthy();
    expect(screen.queryByRole('img', { name: /^Weight chart/ })).toBeNull();
  });
});

describe('the weighing dialog', () => {
  it('checks the date, the weight and its decimals before saving', async () => {
    const { server } = renderApp(`/pets/${MURKA}/weight`);
    fireEvent.click(await (await region('Latest weighing')).findByRole('button', { name: 'Add' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'New weighing' }));
    expect(dialog.getByLabelText('Date')).toHaveProperty('value', server.world.today);
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await dialog.findByText('Enter the weight')).toBeTruthy();
    fireEvent.change(dialog.getByLabelText('Weight, kg'), { target: { value: '4,2355' } });
    expect(await dialog.findByText('Use 3 decimals at most')).toBeTruthy();
    fireEvent.change(dialog.getByLabelText('Weight, kg'), { target: { value: '250' } });
    expect(await dialog.findByText('Use a weight above 0 and up to 200 kg')).toBeTruthy();
    // Murka's birth date is exact: no weighing before it.
    const born = addInterval(server.world.today, -3, 'Year');
    fireEvent.change(dialog.getByLabelText('Date'), { target: { value: addDays(born, -1) } });
    expect(await dialog.findByText("Can't be before the pet was born")).toBeTruthy();
    expect(server.calls('POST', `/api/v1/pets/${MURKA}/weights`)).toHaveLength(0);
  });

  it('adds a weighing with a comma and a body condition score; a retry after no answer keeps its request id', async () => {
    const server = createTestServer();
    server.respond(
      'POST',
      `/api/v1/pets/${MURKA}/weights`,
      () => {
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp(`/pets/${MURKA}/weight`, { server });
    fireEvent.click(await (await region('Latest weighing')).findByRole('button', { name: 'Add' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'New weighing' }));
    fireEvent.change(dialog.getByLabelText('Weight, kg'), { target: { value: '4,25' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Add body condition score' }));
    fireEvent.click(dialog.getByRole('radio', { name: 'Scale 1–5' }));
    fireEvent.click(dialog.getByRole('radio', { name: '3' }));
    fireEvent.change(dialog.getByLabelText('Note'), { target: { value: 'Before breakfast' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await dialog.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'New weighing' })).toBeNull());
    const tries = server.calls('POST', `/api/v1/pets/${MURKA}/weights`).map((call) => call.body as WeightRequest);
    expect(tries).toHaveLength(2);
    expect(tries[0]).toMatchObject({
      measuredOn: server.world.today,
      weightKg: 4.25,
      bcs: 3,
      bcsScale: 5,
      note: 'Before breakfast',
    });
    expect(tries[0]!.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(tries[1]!.requestId).toBe(tries[0]!.requestId);
    expect(await (await region('Latest weighing')).findByText('4.25')).toBeTruthy();
  });

  it('corrects the weighing a lost answer saved, when the weight was changed before the retry', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    server.respond(
      'POST',
      `/api/v1/pets/${MURKA}/weights`,
      (request) => {
        // Saved, and the answer lost.
        const body = request.body as WeightRequest;
        home.weights.push(weighing('lost', MURKA, { measuredOn: body.measuredOn, weightKg: body.weightKg }));
        server.world.requestIds.set(body.requestId!, 'lost');
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp(`/pets/${MURKA}/weight`, { server });
    fireEvent.click(await (await region('Latest weighing')).findByRole('button', { name: 'Add' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'New weighing' }));
    fireEvent.change(dialog.getByLabelText('Weight, kg'), { target: { value: '4.3' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    await dialog.findByText("Can't reach the server. Check your connection and try again.");
    fireEvent.change(dialog.getByLabelText('Weight, kg'), { target: { value: '4.31' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('PUT', '/api/v1/weights/lost')).toHaveLength(1));
    expect(home.weights.find((item) => item.id === 'lost')!.weightKg).toBe(4.31);
    expect(home.weights.filter((item) => item.measuredOn === server.world.today)).toHaveLength(1);
  });

  it('changes a weighing, and deletes one after asking', async () => {
    const { server } = renderApp(`/pets/${MURKA}/weight`);
    fireEvent.click(await (await region('History')).findByRole('button', { name: '3.85 kg' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Edit weighing' }));
    expect(dialog.getByLabelText('Weight, kg')).toHaveProperty('value', '3.85');
    fireEvent.change(dialog.getByLabelText('Weight, kg'), { target: { value: '3.9' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('PUT', '/api/v1/weights/weight-1')).toHaveLength(1));
    expect(server.calls('PUT', '/api/v1/weights/weight-1')[0]!.body).toMatchObject({ weightKg: 3.9, requestId: null });

    fireEvent.click(await (await region('History')).findByRole('button', { name: '3.9 kg' }));
    const again = within(await screen.findByRole('dialog', { name: 'Edit weighing' }));
    fireEvent.click(again.getByRole('button', { name: 'Delete weighing' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Delete this weighing?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(server.calls('DELETE', '/api/v1/weights/weight-1')).toHaveLength(1));
    await waitFor(() => expect(screen.queryByRole('button', { name: '3.9 kg' })).toBeNull());
  });

  it('asks before typed input is thrown away', async () => {
    renderApp(`/pets/${MURKA}/weight`);
    fireEvent.click(await (await region('Latest weighing')).findByRole('button', { name: 'Add' }));
    const element = await screen.findByRole('dialog', { name: 'New weighing' });
    fireEvent.change(within(element).getByLabelText('Weight, kg'), { target: { value: '4' } });
    fireEvent(element, new Event('cancel', { cancelable: true }));
    expect(await screen.findByRole('dialog', { name: 'Leave without saving?' })).toBeTruthy();
  });

  it('helpers see the weights and change none', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Helper';
    renderApp(`/pets/${MURKA}/weight`, { server });
    expect(await (await region('Latest weighing')).findByText('4.2')).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Add' })).toBeNull();
    expect((await region('History')).queryAllByRole('button')).toHaveLength(0);
    // A vet's weight still opens its record.
    expect((await region('History')).getByRole('link', { name: '4.1 kg' })).toBeTruthy();
  });
});

describe('when the weights can not be read', () => {
  it('says why, and tries again', async () => {
    const server = createTestServer();
    server.respond(
      'GET',
      `/api/v1/pets/${MURKA}/weights`,
      () => new Response(null, { status: 503, headers: { 'Content-Type': 'application/json' } }),
      {
        once: true,
      },
    );
    renderApp(`/pets/${MURKA}/weight`, { server });
    expect(await screen.findByText('Something went wrong on our side. Try again in a moment.')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await (await region('Latest weighing')).findByText('4.2')).toBeTruthy();
  });
});

// --- Review of part 2: the focus after a delete ---

describe('the weighing dialog and the focus (review of part 2)', () => {
  it('a deleted weighing hands the focus to the weight now in its place', async () => {
    renderApp(`/pets/${MURKA}/weight`);
    const history = await region('History');
    const first = await history.findByRole('button', { name: '4.2 kg' });
    first.focus();
    fireEvent.click(first);
    const dialog = within(await screen.findByRole('dialog', { name: 'Edit weighing' }));
    const remove = dialog.getByRole('button', { name: 'Delete weighing' });
    remove.focus();
    fireEvent.click(remove);
    const asking = within(await screen.findByRole('dialog', { name: 'Delete this weighing?' }));
    const confirm = asking.getByRole('button', { name: 'Delete' });
    confirm.focus();
    fireEvent.click(confirm);
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    await waitFor(() => expect(history.queryByRole('button', { name: '4.2 kg' })).toBeNull());
    // Still in the list: on the weight that moved up (the vet's 4.1 kg).
    await waitFor(() => expect(window.document.activeElement?.closest('ul')).toBe(history.getByRole('list')));
  });
});
