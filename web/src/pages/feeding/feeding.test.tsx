// The Feeding tab: the schedules, and their form (times added and removed, the days, the food typed or picked from
// supplies, the portion and its unit, notes, pause, delete).
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { RoutineRequest } from '../../api/types';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, MURKA, problem, REX } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));

describe('the Feeding tab', () => {
  it('lists the schedules: times, days and what is given', async () => {
    renderApp(`/pets/${MURKA}/feeding`);
    const schedule = await region('Feeding schedule');
    const times = await schedule.findByRole('link', { name: '8:00 AM · 7:00 PM' });
    const row = within(times.closest('li') as HTMLElement);
    expect(row.getByText('Every day')).toBeTruthy();
    expect(row.getByText('Royal Canin, 40 g')).toBeTruthy();
  });

  it('adds a schedule: times added and removed, weekdays, a food typed, a portion with a comma', async () => {
    const { server, router } = renderApp(`/pets/${REX}/feeding/new`);
    const time = await screen.findByLabelText('New time');
    // 8:00 to start with, then twelve hours later.
    expect(time).toHaveProperty('value', '08:00');
    fireEvent.click(screen.getByRole('button', { name: 'Add time' }));
    expect(time).toHaveProperty('value', '20:00');
    fireEvent.change(time, { target: { value: '13:30' } });
    // Enter in the time adds it, rather than saving the form.
    fireEvent.keyDown(time, { key: 'Enter' });
    fireEvent.change(time, { target: { value: '20:00' } });
    fireEvent.click(screen.getByRole('button', { name: 'Add time' }));
    fireEvent.click(screen.getByRole('button', { name: 'Remove 1:30 PM' }));
    const days = within(screen.getByRole('group', { name: 'Days' }));
    fireEvent.click(days.getByRole('checkbox', { name: 'Sat' }));
    fireEvent.click(days.getByRole('checkbox', { name: 'Sun' }));
    // No food of the household's supplies is a dog's, so there is no choice: the food is typed.
    fireEvent.change(screen.getByLabelText('Food'), { target: { value: 'Acana' } });
    fireEvent.change(screen.getByLabelText('Portion'), { target: { value: '150,5' } });
    fireEvent.click(screen.getByRole('radio', { name: 'ml' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${REX}/feeding`));
    const sent = server.calls('POST', `/api/v1/pets/${REX}/routines`)[0]!.body as RoutineRequest;
    expect(sent).toMatchObject({
      kind: 'Feeding',
      times: ['08:00:00', '20:00:00'],
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      amount: 150.5,
      unit: 'Milliliter',
      active: null,
      supplyItemId: null,
    });
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);
    const schedule = await region('Feeding schedule');
    expect(await schedule.findByText('Mon, Tue, Wed, Thu, Fri')).toBeTruthy();
  });

  it('checks the times, the days and the portion before saving', async () => {
    const { server } = renderApp(`/pets/${REX}/feeding/new`);
    const days = within(await screen.findByRole('group', { name: 'Days' }));
    for (const day of ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      fireEvent.click(days.getByRole('checkbox', { name: day }));
    }
    fireEvent.change(screen.getByLabelText('Portion'), { target: { value: '0' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Add at least one time')).toBeTruthy();
    expect(screen.getByText('Choose at least one day')).toBeTruthy();
    expect(screen.getByText('Use a number above 0, up to 10 000')).toBeTruthy();
    expect(server.calls('POST', `/api/v1/pets/${REX}/routines`)).toHaveLength(0);
  });

  it("gives a food from supplies, in the food's unit; pauses the schedule", async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/feeding/routine-murka`);
    const supply = await screen.findByLabelText('Food from supplies');
    expect(supply).toHaveProperty('value', 'supply-food');
    // Litter is no food; the linked food's name is the food.
    expect(within(supply).queryByRole('option', { name: 'Clumping litter' })).toBeNull();
    expect(screen.queryByLabelText('Food')).toBeNull();
    expect(screen.getByRole('radio', { name: 'ml' })).toHaveProperty('disabled', true);
    fireEvent.change(screen.getByLabelText('Portion'), { target: { value: '45' } });
    fireEvent.click(screen.getByRole('checkbox', { name: 'Active' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/feeding`));
    expect(server.calls('PUT', '/api/v1/routines/routine-murka')[0]!.body).toMatchObject({
      supplyItemId: 'supply-food',
      food: 'Royal Canin Sterilised',
      amount: 45,
      unit: 'Gram',
      active: false,
      requestId: null,
    });
    expect(await (await region('Feeding schedule')).findByText('Every day · Paused')).toBeTruthy();
  });

  it("deletes a schedule after asking; shows the server's refusal under its field", async () => {
    const server = createTestServer();
    server.respond('PUT', '/api/v1/routines/routine-rex', () => problem(400, { errors: { times: ['Too many.'] } }), {
      once: true,
    });
    const { router } = renderApp(`/pets/${REX}/feeding/routine-rex`, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Save' }));
    expect(await screen.findByText("This value wasn't accepted. Check it.")).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: 'Delete schedule' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete this feeding schedule?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${REX}/feeding`));
    expect(server.calls('DELETE', '/api/v1/routines/routine-rex')).toHaveLength(1);
    expect(await (await region('Feeding schedule')).findByText(/^Add feeding times/)).toBeTruthy();
  });

  it('helpers see the schedules and change none', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Helper';
    renderApp(`/pets/${MURKA}/feeding`, { server });
    const schedule = await region('Feeding schedule');
    expect(await schedule.findByText('8:00 AM · 7:00 PM')).toBeTruthy();
    expect(schedule.queryByRole('link')).toBeNull();
    expect(schedule.queryByRole('link', { name: 'Add' })).toBeNull();
  });
});

// --- Review of part 2: another phone's pause, a typed time, the focus, a lost answer ---

describe('the feeding form and what happens meanwhile (review of part 2)', () => {
  it('a feeding paused on another phone stays paused when the web form saves another change', async () => {
    const server = createTestServer();
    const murka = server.world.households.get(HOME)!.routines.find((item) => item.id === 'routine-murka')!;
    renderApp(`/pets/${MURKA}/feeding/routine-murka`, { server });
    fireEvent.change(await screen.findByLabelText('Notes'), { target: { value: 'Soak the kibble' } });
    murka.active = false;
    const asked = server.calls('GET', '/api/v1/routines/routine-murka').length;
    act(() => {
      window.dispatchEvent(new Event('visibilitychange'));
    });
    await waitFor(() => expect(server.calls('GET', '/api/v1/routines/routine-murka').length).toBeGreaterThan(asked));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('PUT', '/api/v1/routines/routine-murka')).toHaveLength(1));
    const sent = server.calls('PUT', '/api/v1/routines/routine-murka')[0]!.body as { active: boolean | null };
    expect({ sentActive: sent.active, nowActive: murka.active }).toEqual({ sentActive: null, nowActive: false });
  });

  it('a removed time hands the focus to a time still there, then to the new-time field', async () => {
    renderApp(`/pets/${MURKA}/feeding/routine-murka`);
    const first = await screen.findByRole('button', { name: 'Remove 8:00 AM' });
    first.focus();
    fireEvent.click(first);
    await waitFor(() =>
      expect(window.document.activeElement).toBe(screen.getByRole('button', { name: 'Remove 7:00 PM' })),
    );
    fireEvent.click(screen.getByRole('button', { name: 'Remove 7:00 PM' }));
    await waitFor(() => expect(window.document.activeElement).toBe(screen.getByLabelText('New time')));
  });

  it('a time typed and not added counts for leaving, and "Save" adds it', async () => {
    const { server, router } = renderApp(`/pets/${REX}/feeding/routine-rex`);
    fireEvent.change(await screen.findByLabelText('New time'), { target: { value: '18:30' } });
    // Leaving would lose it.
    fireEvent.click(screen.getByRole('link', { name: 'Pets' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Cancel' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${REX}/feeding`));
    expect((server.calls('PUT', '/api/v1/routines/routine-rex')[0]!.body as RoutineRequest).times).toEqual([
      '08:00:00',
      '18:30:00',
    ]);
  });

  it('a new schedule: a correction after a lost answer follows it', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    const path = `/api/v1/pets/${REX}/routines`;
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
    const { router } = renderApp(`/pets/${REX}/feeding/new`, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Add time' }));
    fireEvent.change(screen.getByLabelText('Portion'), { target: { value: '150' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Portion'), { target: { value: '180' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${REX}/feeding`));
    const added = home.routines.filter((item) => item.petId === REX && item.id !== 'routine-rex');
    expect(added.map((item) => item.amount)).toEqual([180]);
  });
});
