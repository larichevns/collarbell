// Visits: the list, the form, "The visit took place", cancelling and deleting.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { Visit } from '../../api/types';
import { addDays } from '../../lib/dates';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, MURKA, OFFICE, problem, REX } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));

describe('visits', () => {
  it('lists the planned visits, then the past ones', async () => {
    renderApp('/visits');
    const planned = await region('Planned');
    expect(planned.getAllByRole('link').map((link) => link.textContent)).toEqual(['Check-up', 'Groomer']);
    expect(planned.getByText('Rex')).toBeTruthy();
    // Its day has come: it can be marked from the list; the button says which visit, for those who hear it alone.
    const checkUp = planned.getByRole('link', { name: 'Check-up' }).closest('li') as HTMLElement;
    expect(within(checkUp).getByRole('button', { name: 'The visit took place: Check-up' })).toBeTruthy();
    const groomer = planned.getByRole('link', { name: 'Groomer' }).closest('li') as HTMLElement;
    expect(within(groomer).queryByRole('button', { name: /^The visit took place/ })).toBeNull();
    const past = await region('Past and cancelled');
    expect(past.getByText(/· Took place$/)).toBeTruthy();
  });

  it('adds a visit for a pet: the kind of visit names it when no title is typed', async () => {
    const { server, router } = renderApp(`/visits/new?pet=${REX}`);
    const pets = await screen.findByRole('group', { name: 'Pets' });
    expect(within(pets).getByRole('checkbox', { name: 'Rex' })).toHaveProperty('checked', true);
    // Archived pets aren't offered.
    expect(within(pets).queryByRole('checkbox', { name: 'Tom' })).toBeNull();
    const reminders = screen.getByRole('group', { name: 'Remind' });
    expect(within(reminders).getByRole('checkbox', { name: 'A day before' })).toHaveProperty('checked', true);

    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Choose a date')).toBeTruthy();
    expect(screen.getByText('Choose the time')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/appointments')).toHaveLength(0);

    fireEvent.click(screen.getByRole('radio', { name: 'Groomer' }));
    fireEvent.change(screen.getByLabelText('Date'), { target: { value: addDays(server.world.today, 3) } });
    fireEvent.change(screen.getByLabelText('Time'), { target: { value: '09:30' } });
    fireEvent.click(within(pets).getByRole('checkbox', { name: 'Murka' }));
    fireEvent.click(within(reminders).getByRole('checkbox', { name: 'A week before' }));
    fireEvent.change(screen.getByLabelText('Where'), { target: { value: 'Happy Paws' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/visits\/[0-9a-f-]{36}$/));
    const sent = server.calls('POST', '/api/v1/appointments')[0]!.body as Record<string, unknown>;
    expect(sent).toMatchObject({
      type: 'Grooming',
      title: 'Groomer',
      date: addDays(server.world.today, 3),
      time: '09:30:00',
      // In the order of the pets list, whatever order they were picked in.
      petIds: [MURKA, REX],
      remindOffsetsMinutes: [10080, 1440, 120],
      location: 'Happy Paws',
      status: null,
    });
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(await screen.findByRole('heading', { name: 'Groomer', level: 1 })).toBeTruthy();
  });

  it("shows the server's refusal under its field", async () => {
    const server = createTestServer();
    server.respond('PUT', '/api/v1/appointments/visit-groomer', () =>
      problem(400, { errors: { location: ['At most 200 characters.'] } }),
    );
    renderApp('/visits/visit-groomer/edit', { server });
    expect(await screen.findByLabelText('Where')).toHaveProperty('value', 'Happy Paws');
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("This value wasn't accepted. Check it.")).toBeTruthy();
    expect(screen.getByLabelText('Where').getAttribute('aria-invalid')).toBe('true');
  });

  it('marks a visit as took place: a check-up for the pet, and its yearly plan done', async () => {
    const { server } = renderApp('/visits/visit-vet');
    fireEvent.click(await screen.findByRole('button', { name: 'The visit took place' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'How did the visit go?' }));
    expect(dialog.getByRole('checkbox', { name: 'Add to the care history' })).toHaveProperty('checked', true);
    expect(dialog.getByRole('radio', { name: 'Check-up' })).toHaveProperty('checked', true);
    // The pet's only check-up plan, which repeats, is suggested.
    const suggested = await dialog.findByRole('checkbox', { name: 'Mark “Yearly check-up” done' });
    expect(suggested).toHaveProperty('checked', true);
    fireEvent.change(dialog.getByLabelText('Notes'), { target: { value: 'All well' } });
    fireEvent.click(dialog.getByRole('button', { name: 'The visit took place' }));

    expect(await screen.findByText('Saved. One plan moved to its next date.')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/appointments/visit-vet/complete')[0]!.body).toEqual({
      recordKind: 'VetExam',
      planIds: ['plan-exam'],
      notes: 'All well',
    });
    expect(await region('Result')).toBeTruthy();
  });

  it('marks a visit from Today without a record when that is the choice', async () => {
    const { server } = renderApp('/today');
    fireEvent.click((await region('Visits')).getByRole('button', { name: 'The visit took place: Check-up' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'How did the visit go?' }));
    fireEvent.click(dialog.getByRole('checkbox', { name: 'Add to the care history' }));
    fireEvent.click(dialog.getByRole('button', { name: 'The visit took place' }));
    expect(await screen.findByText('Saved: the visit took place.')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/appointments/visit-vet/complete')[0]!.body).toEqual({
      recordKind: null,
      planIds: [],
      notes: null,
    });
  });

  it('cancels a visit after asking, with the whole visit sent back', async () => {
    const { server } = renderApp('/visits/visit-groomer');
    fireEvent.click(await screen.findByRole('button', { name: 'Cancel visit' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Cancel this visit?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Cancel visit' }));
    expect(await screen.findByText('This visit is cancelled.')).toBeTruthy();
    expect(server.calls('PUT', '/api/v1/appointments/visit-groomer')[0]!.body).toMatchObject({
      title: 'Groomer',
      petIds: [REX],
      location: 'Happy Paws',
      status: 'Cancelled',
    });
    expect(screen.getByRole('button', { name: 'Plan again' })).toBeTruthy();
  });

  it('deletes a visit after asking', async () => {
    const { server, router } = renderApp('/visits/visit-old');
    fireEvent.click(await screen.findByRole('button', { name: 'Delete' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete this visit?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/visits'));
    expect(server.calls('DELETE', '/api/v1/appointments/visit-old')).toHaveLength(1);
  });
});

// --- Review of part 1 (P2, P4, P10b): a save during a move, a visit deleted elsewhere, typed notes ---

const NOT_FOUND = "This wasn't found. It may have been deleted.";
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('visits and what happens meanwhile', () => {
  it('holds a group switch while a new visit saves, then opens it in its group (review P2)', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    let release!: () => void;
    const wait = new Promise<void>((resolve) => (release = resolve));
    const NEW_VISIT = 'cccccccc-0000-4000-8000-000000000009';
    server.respond(
      'POST',
      '/api/v1/appointments',
      async () => {
        await wait;
        const created: Visit = { ...home.visits[1]!, id: NEW_VISIT, title: 'Vet' };
        home.visits.push(created);
        return json(201, created);
      },
      { once: true },
    );
    const { router } = renderApp(`/visits/new?pet=${REX}`, { server });
    fireEvent.change(await screen.findByLabelText('Date'), { target: { value: addDays(server.world.today, 3) } });
    fireEvent.change(screen.getByLabelText('Time'), { target: { value: '09:30' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/appointments')).toHaveLength(1));

    const picker = within(screen.getByRole('banner')).getByLabelText('Group') as HTMLSelectElement;
    fireEvent.change(picker, { target: { value: OFFICE } });
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 30));
    });
    expect(picker.value).toBe(HOME);

    await act(async () => release());
    await waitFor(() => expect(router.state.location.pathname).toBe(`/visits/${NEW_VISIT}`));
    expect(server.calls('GET', `/api/v1/appointments/${NEW_VISIT}`).map((call) => call.household)).not.toContain(
      OFFICE,
    );
    expect(screen.queryByText(NOT_FOUND)).toBeNull();
  });

  it('a visit deleted on another phone is not shown as planned when the window comes back (review P4)', async () => {
    const server = createTestServer();
    renderApp('/visits/visit-groomer', { server });
    expect(await screen.findByRole('heading', { name: 'Groomer', level: 1 })).toBeTruthy();
    const home = server.world.households.get(HOME)!;
    home.visits = home.visits.filter((visit) => visit.id !== 'visit-groomer');
    const asked = server.calls('GET', '/api/v1/appointments/visit-groomer').length;
    act(() => {
      window.dispatchEvent(new Event('visibilitychange'));
    });
    await waitFor(() => expect(server.calls('GET', '/api/v1/appointments/visit-groomer').length).toBe(asked + 1));
    expect(await screen.findByText(NOT_FOUND)).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Cancel visit' })).toBeNull();
  });

  it('Esc with typed notes in "How did the visit go?" asks first (review P10b)', async () => {
    renderApp('/visits/visit-vet');
    fireEvent.click(await screen.findByRole('button', { name: 'The visit took place' }));
    const element = await screen.findByRole('dialog', { name: 'How did the visit go?' });
    fireEvent.change(within(element).getByLabelText('Notes'), { target: { value: 'All well, weight 4.2 kg' } });
    fireEvent(element, new Event('cancel', { cancelable: true }));
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Cancel' }));
    // Still there, with what was typed.
    expect(screen.getByDisplayValue('All well, weight 4.2 kg')).toBeTruthy();
  });
});
