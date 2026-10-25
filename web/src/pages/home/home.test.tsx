// Home on the pretend server: the pets, "Right now" from Today's data (the next feeding marked as on Today, the care
// overdue and due soon, the next visit, what to buy, all done, the first steps), the quick actions and their "Which
// pet?", what helpers see, and the addresses: Home at /, Today at /today.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { TodayFeeding, TodayVisit } from '../../api/types';
import { en } from '../../i18n/en';
import { feedingSlots, nextFeedingTime } from '../../lib/feeding';
import { renderApp } from '../../test/render';
import { ANNA, createTestServer, HOME, markKey, MURKA, OFFICE, REX, type TestServer } from '../../test/server';
import { greeting, nextVisit } from './HomePage';

const region = async (name: string) => within(await screen.findByRole('region', { name }));

/** Anna on the helper's household, Office, as if she had it on screen last time. */
function asHelper() {
  const office = { id: OFFICE, name: 'Office', role: 'Helper' };
  window.localStorage.setItem(`collarbell.household.uid-${ANNA}`, JSON.stringify(office));
}

/** Home's day done: every feeding marked, no care due within two weeks, no visit, nothing to buy. */
function dayDone(server: TestServer) {
  const home = server.world.households.get(HOME)!;
  for (const routine of home.routines) {
    for (const time of routine.times) {
      home.marks.set(markKey(routine.id, server.world.today, time), {
        id: `mark-${routine.id}-${time}`,
        routineId: routine.id,
        date: server.world.today,
        time,
        status: 'Done',
        doneAt: `${server.world.today}T05:00:00Z`,
        byName: 'Anna',
        byMe: true,
      });
    }
  }
  home.plans = home.plans.filter((plan) => plan.id === 'plan-exam');
  home.visits = home.visits.filter((visit) => visit.status !== 'Planned');
  home.supplies = [];
  home.stock = [];
}

describe('Home', () => {
  it('opens at /, with the pets, what is important right now and the quick actions', async () => {
    const { router } = renderApp('/');
    const pets = await region('Pets');
    expect(pets.getByRole('link', { name: 'Murka' }).getAttribute('href')).toBe(`/pets/${MURKA}`);
    expect(pets.getByRole('link', { name: 'Rex' }).getAttribute('href')).toBe(`/pets/${REX}`);
    // Archived pets stay on the Pets page.
    expect(pets.queryByRole('link', { name: 'Tom' })).toBeNull();
    expect(pets.getByRole('link', { name: 'Add pet' }).getAttribute('href')).toBe('/pets/new');

    const now = await region('Right now');
    // The next feeding: the earliest time with a pet not fed yet, both its pets.
    expect(await now.findByRole('heading', { name: 'Feeding at 8:00 AM' })).toBeTruthy();
    expect(now.queryByRole('heading', { name: 'Feeding at 7:00 PM' })).toBeNull();
    expect(now.getAllByRole('button', { name: 'Fed' })).toHaveLength(2);
    // Care: one overdue, one due soon, to Today.
    const care = now.getByRole('link', { name: 'Overdue: 1 Due soon: 1' });
    expect(care.getAttribute('href')).toBe('/today');
    // The visit waiting for "The visit took place" first, and what to buy.
    expect(now.getByRole('link', { name: 'Check-up' })).toBeTruthy();
    expect(now.getByRole('button', { name: 'The visit took place: Check-up' })).toBeTruthy();
    expect(now.queryByRole('link', { name: 'Groomer' })).toBeNull();
    expect(now.getByRole('link', { name: 'To buy: 1' }).getAttribute('href')).toBe('/supplies');

    const quick = await region('Quick actions');
    expect(quick.getByRole('link', { name: 'Add a visit' }).getAttribute('href')).toBe('/visits/new');
    expect(quick.getByRole('link', { name: 'Add to supplies' }).getAttribute('href')).toBe('/supplies/new');
    // With AI on the server, the scan and the note too.
    expect(await quick.findByRole('button', { name: 'Scan the passport' })).toBeTruthy();
    expect(quick.getByRole('button', { name: 'Write it in words' })).toBeTruthy();

    fireEvent.click(care);
    await waitFor(() => expect(router.state.location.pathname).toBe('/today'));
    expect(await screen.findByRole('heading', { name: 'Today', level: 1 })).toBeTruthy();
  });

  it('marks the next feeding as Today does, then shows the one after it', async () => {
    const { server } = renderApp('/');
    const now = await region('Right now');
    const allFed = await now.findByRole('button', { name: 'All fed' });
    allFed.focus();
    fireEvent.click(allFed);
    await waitFor(() => expect(server.calls('POST', /\/completions$/)).toHaveLength(2));
    expect(server.calls('POST', /\/completions$/).map((call) => call.body)).toEqual([
      { date: server.world.today, time: '08:00:00', status: 'Done' },
      { date: server.world.today, time: '08:00:00', status: 'Done' },
    ]);
    // 8:00 is done: 7:00 PM is next, Murka alone, and the focus is on its "Fed", not lost with the rows that went.
    expect(await now.findByRole('heading', { name: 'Feeding at 7:00 PM' })).toBeTruthy();
    expect(now.getAllByRole('button', { name: 'Fed' })).toHaveLength(1);
    await waitFor(() => expect(document.activeElement).toBe(now.getByRole('button', { name: 'Fed' })));
  });

  it('says who marked a feeding first, as Today does', async () => {
    const server = createTestServer();
    renderApp('/', { server });
    const now = await region('Right now');
    const row = within((await now.findByText('Murka')).closest('li') as HTMLElement);
    server.world.households.get(HOME)!.marks.set(markKey('routine-murka', server.world.today, '08:00:00'), {
      id: 'mark-boris',
      routineId: 'routine-murka',
      date: server.world.today,
      time: '08:00:00',
      status: 'Done',
      doneAt: `${server.world.today}T05:02:00Z`,
      byName: 'Boris',
      byMe: false,
    });
    fireEvent.click(row.getByRole('button', { name: 'Fed' }));
    expect(await screen.findByText('Already marked: Boris, 8:02 AM')).toBeTruthy();
  });

  it('says all is done for today, calmly', async () => {
    const server = createTestServer();
    dayDone(server);
    renderApp('/', { server });
    const now = await region('Right now');
    expect(await now.findByText('All done for today')).toBeTruthy();
    expect(now.getByText('New things show up here when they are due.')).toBeTruthy();
    expect(now.queryByRole('button', { name: 'Fed' })).toBeNull();
  });

  it('with pets and nothing set up, offers the first steps; several pets: "Which pet?"', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    Object.assign(home, { routines: [], plans: [], visits: [], supplies: [], stock: [] });
    const { router } = renderApp('/', { server });
    const now = await region('Right now');
    const feeding = await now.findByRole('button', { name: 'Add feeding' });
    expect(feeding.getAttribute('aria-describedby')).toBeTruthy();
    expect(now.getByRole('button', { name: 'Vaccinations and treatments' })).toBeTruthy();
    // The visit is among the quick actions already.
    expect(now.queryByRole('link', { name: 'Add a visit' })).toBeNull();

    fireEvent.click(feeding);
    const dialog = within(await screen.findByRole('dialog', { name: 'Which pet?' }));
    expect(dialog.getByRole('button', { name: 'Murka' })).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Rex' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${REX}/feeding/new`));
  });

  it('goes straight to the only pet', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    home.pets = home.pets.filter((pet) => pet.id === MURKA);
    renderApp('/', { server });
    const quick = await region('Quick actions');
    expect(quick.getByRole('link', { name: 'Vaccination or treatment' }).getAttribute('href')).toBe(
      `/pets/${MURKA}/records/new`,
    );
    expect((await quick.findByRole('link', { name: 'Scan the passport' })).getAttribute('href')).toBe(
      `/pets/${MURKA}/scan?from=passport`,
    );
    expect(quick.getByRole('link', { name: 'Write it in words' }).getAttribute('href')).toBe(
      `/pets/${MURKA}/note?from=health`,
    );
    // The weighing opens right here.
    fireEvent.click(quick.getByRole('button', { name: 'Weigh' }));
    expect(await screen.findByRole('dialog', { name: 'New weighing' })).toBeTruthy();
  });

  it('asks which pet to weigh, then opens the weighing for it', async () => {
    renderApp('/');
    fireEvent.click((await region('Quick actions')).getByRole('button', { name: 'Weigh' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Which pet?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Murka' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Which pet?' })).toBeNull());
    expect(await screen.findByRole('dialog', { name: 'New weighing' })).toBeTruthy();
  });

  it('shows helpers the pets and what is due, without quick actions or adding', async () => {
    asHelper();
    renderApp('/');
    const pets = await region('Pets');
    expect(pets.getByRole('link', { name: 'Barsik' })).toBeTruthy();
    expect(pets.queryByRole('link', { name: 'Add pet' })).toBeNull();
    expect(await screen.findByRole('heading', { name: 'Feeding at 9:00 AM' })).toBeTruthy();
    expect(screen.queryByRole('region', { name: 'Quick actions' })).toBeNull();
  });

  it('without pets: "Add a pet" first and the tour; helpers only what will show', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.pets = [];
    // The onboarding had its turn on this browser already.
    window.localStorage.setItem(`collarbell.onboarding.uid-${ANNA}`, '1');
    renderApp('/', { server });
    const add = await screen.findByRole('link', { name: 'Add a pet' });
    expect(add.getAttribute('href')).toBe('/pets/new');
    expect(add.className).toContain('action-card--primary');
    expect(screen.getByRole('link', { name: 'Take the tour' }).getAttribute('href')).toBe('/welcome');
    expect(screen.queryByRole('region', { name: 'Right now' })).toBeNull();
  });

  it('a helper in a household without pets is told what will show here', async () => {
    const server = createTestServer();
    server.world.households.get(OFFICE)!.pets = [];
    asHelper();
    renderApp('/', { server });
    expect(await screen.findByText('No pets yet')).toBeTruthy();
    expect(screen.getByText('When the group has pets, their feeding, care and shopping show up here.')).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Add a pet' })).toBeNull();
  });
});

describe('the addresses and the menu', () => {
  it('has Home first, then Today at /today; each lit only on its own page', async () => {
    const { router } = renderApp('/');
    const nav = within(await screen.findByRole('navigation', { name: 'Sections' }));
    const links = nav.getAllByRole('link');
    expect(links.map((link) => link.textContent)).toEqual(['Home', 'Today', 'Pets', 'Visits', 'Supplies', 'Settings']);
    expect(nav.getByRole('link', { name: 'Home' }).getAttribute('aria-current')).toBe('page');
    expect(nav.getByRole('link', { name: 'Today' }).getAttribute('aria-current')).toBeNull();

    fireEvent.click(nav.getByRole('link', { name: 'Today' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/today'));
    expect(nav.getByRole('link', { name: 'Today' }).getAttribute('aria-current')).toBe('page');
    expect(nav.getByRole('link', { name: 'Home' }).getAttribute('aria-current')).toBeNull();
    expect(document.title).toBe('Today · Collarbell');
  });

  it('names the page "Home" in the browser tab, whatever the greeting', async () => {
    renderApp('/');
    await region('Right now');
    await waitFor(() => expect(document.title).toBe('Home · Collarbell'));
  });

  it('an address that leads nowhere has a button to Home', async () => {
    const { router } = renderApp('/nowhere');
    fireEvent.click(await screen.findByRole('link', { name: 'To Home' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/'));
  });
});

describe("Home's rules", () => {
  it('greets by the time of day', () => {
    expect([4, 5, 11, 12, 16, 17, 22, 23, 0].map((hour) => greeting(en, hour))).toEqual([
      'Good evening',
      'Good morning',
      'Good morning',
      'Good afternoon',
      'Good afternoon',
      'Good evening',
      'Good evening',
      'Good evening',
      'Good evening',
    ]);
  });

  const feeding = (petId: string, time: string, marked = false): TodayFeeding => ({
    routineId: `routine-${petId}`,
    petId,
    petName: petId,
    petCoat: 'Ginger',
    petPhoto: null,
    time,
    food: null,
    amount: null,
    unit: null,
    mark: marked
      ? {
          id: 'm',
          routineId: `routine-${petId}`,
          date: '2026-10-14',
          time,
          status: 'Skipped',
          doneAt: '',
          byName: null,
          byMe: true,
        }
      : null,
  });

  it('takes the earliest time with a pet not marked as the next feeding', () => {
    const day = [feeding('rex', '19:00:00'), feeding('murka', '08:00:00', true), feeding('rex', '08:00:00', true)];
    expect([...feedingSlots(day).keys()]).toEqual(['08:00:00', '19:00:00']);
    expect(nextFeedingTime(day)).toBe('19:00:00');
    expect(nextFeedingTime([feeding('rex', '08:00:00', true)])).toBeNull();
  });

  it('shows a past visit waiting for its answer before the next one', () => {
    const visit = (id: string, daysAway: number) => ({ id, daysAway }) as TodayVisit;
    expect(nextVisit([visit('soon', 2), visit('past', -1)])?.id).toBe('past');
    expect(nextVisit([visit('soon', 2), visit('later', 7)])?.id).toBe('soon');
    expect(nextVisit([])).toBeNull();
  });
});
