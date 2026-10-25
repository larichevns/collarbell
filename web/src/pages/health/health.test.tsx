// The Health tab: the plan by status with "Done", the plan form (from a ready-made plan or by hand; change, pause,
// delete), the history with its filter, the record form by kind, and a record's photos and files.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { addDays, addInterval } from '../../lib/dates';
import { renderApp } from '../../test/render';
import { createTestServer, HOME, MURKA, problem, REX } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));
const file = (name: string, type: string, size = 1000) => new File([new Uint8Array(size)], name, { type });
const drop = (target: Element, files: File[]) => fireEvent.drop(target, { dataTransfer: { files, types: ['Files'] } });

describe('the Health tab', () => {
  it('shows the plan by status, the finished and paused folded, and the history newest first by kind', async () => {
    renderApp(`/pets/${MURKA}/health`);
    expect((await screen.findByRole('tab', { name: 'Health' })).getAttribute('aria-selected')).toBe('true');
    const plans = await region('Care plan');
    expect(await plans.findByRole('heading', { name: 'Overdue' })).toBeTruthy();
    expect(plans.getByRole('link', { name: 'Rabies' })).toBeTruthy();
    expect(plans.getByText(/3 days overdue/)).toBeTruthy();
    expect(plans.getByRole('heading', { name: 'Upcoming' })).toBeTruthy();
    const exam = plans.getByRole('link', { name: 'Yearly check-up' }).closest('li') as HTMLElement;
    expect(within(exam).getByText('Every year')).toBeTruthy();
    // Paused plans are folded away.
    const folded = plans.getByRole('button', { name: 'Finished or paused (1)' });
    expect(folded.getAttribute('aria-expanded')).toBe('false');
    expect(plans.queryByText('Fleas and ticks')).toBeNull();
    fireEvent.click(folded);
    expect(plans.getByText('Fleas and ticks')).toBeTruthy();
    expect(plans.getByText('Paused')).toBeTruthy();

    const history = await region('History');
    const titles = () =>
      within(history.getByRole('list'))
        .getAllByRole('link')
        .map((link) => link.textContent);
    expect(await history.findByRole('link', { name: 'Check-up' })).toBeTruthy();
    expect(titles()).toEqual(['Check-up', 'Deworming', 'Rabies']);
    expect(history.getByText(/· Nobivac Rabies$/)).toBeTruthy();
    // The record with a photo says so.
    expect(history.getByText('1 file')).toBeTruthy();
    fireEvent.click(history.getByRole('radio', { name: 'Deworming' }));
    expect(titles()).toEqual(['Deworming']);
  });

  it('marks a plan done from the tab, and the new record joins the history', async () => {
    const { server } = renderApp(`/pets/${MURKA}/health`);
    const plans = await region('Care plan');
    const row = (await plans.findByRole('link', { name: 'Rabies' })).closest('li') as HTMLElement;
    fireEvent.click(within(row).getByRole('button', { name: 'Done' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Mark as done' }));
    expect(await dialog.findByLabelText('Product')).toHaveProperty('value', 'Nobivac Rabies');
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText(/^Marked as done\. Next time: /)).toBeTruthy();
    expect(server.calls('POST', '/api/v1/care-plans/plan-rabies/complete')).toHaveLength(1);
    const history = await region('History');
    await waitFor(() => expect(history.getAllByRole('link', { name: 'Rabies' })).toHaveLength(2));
  });
});

describe('the plan form', () => {
  it('starts from a ready-made plan: its words, the interval, and the next date counted from the last time', async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/plans/new`);
    const deworming = await region('Deworming');
    expect(deworming.getByText('When the risk is unknown: at least 4 times a year.')).toBeTruthy();
    // A cat's catalog has no dog-only products.
    expect(screen.queryByText('K9 Advantix')).toBeNull();
    fireEvent.click(deworming.getByRole('link', { name: 'Deworming' }));

    expect(await screen.findByLabelText('What to do')).toHaveProperty('value', 'Deworming');
    expect(screen.getByText('When the risk is unknown: at least 4 times a year.')).toBeTruthy();
    expect(screen.getByLabelText('Every')).toHaveProperty('value', '3');
    expect(screen.getByLabelText('Unit')).toHaveProperty('value', 'Month');
    const lastDone = addDays(server.world.today, -10);
    fireEvent.change(screen.getByLabelText('Last done (optional)'), { target: { value: lastDone } });
    expect(screen.getByLabelText('Next due')).toHaveProperty('value', addInterval(lastDone, 3, 'Month'));
    expect(screen.getByText('Counted from the last time and the interval. You can change it.')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Usual product (optional)'), { target: { value: 'Milbemax' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/health`));
    const sent = server.calls('POST', `/api/v1/pets/${MURKA}/care-plans`)[0]!.body as Record<string, unknown>;
    expect(sent).toMatchObject({
      kind: 'Deworming',
      title: 'Deworming',
      intervalValue: 3,
      intervalUnit: 'Month',
      nextDueOn: addInterval(lastDone, 3, 'Month'),
      defaultProduct: 'Milbemax',
      presetCode: 'cat-deworm',
      active: null,
    });
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(await (await region('Care plan')).findByRole('link', { name: 'Deworming' })).toBeTruthy();
  });

  it('makes an own plan once, with what a vaccine protects against', async () => {
    const { server } = renderApp(`/pets/${MURKA}/plans/new/own`);
    fireEvent.change(await screen.findByLabelText('What to do'), { target: { value: 'FeLV booster' } });
    fireEvent.change(screen.getByLabelText('Type'), { target: { value: 'Vaccination' } });
    fireEvent.click(screen.getByRole('radio', { name: 'Once' }));
    expect(screen.queryByLabelText('Every')).toBeNull();
    const targets = within(screen.getByRole('group', { name: 'Protects against' }));
    // A cat's diseases only.
    expect(targets.queryByRole('checkbox', { name: 'Distemper (CDV)' })).toBeNull();
    fireEvent.click(targets.getByRole('checkbox', { name: 'Leukaemia (FeLV)' }));
    fireEvent.change(screen.getByLabelText('Due on'), { target: { value: addDays(server.world.today, 14) } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', `/api/v1/pets/${MURKA}/care-plans`)).toHaveLength(1));
    expect(server.calls('POST', `/api/v1/pets/${MURKA}/care-plans`)[0]!.body).toMatchObject({
      kind: 'Vaccination',
      title: 'FeLV booster',
      intervalValue: null,
      intervalUnit: null,
      targets: ['Felv'],
      presetCode: null,
    });
  });

  it("says so when the server refuses a dog's product for this pet", async () => {
    const server = createTestServer();
    server.respond('POST', `/api/v1/pets/${REX}/care-plans`, () =>
      problem(400, { errors: { presetCode: ['This product is for dogs only.'] } }),
    );
    renderApp(`/pets/${REX}/plans/new/dog-advantix`, { server });
    // A product toxic to cats is a warning from the start.
    expect(
      await screen.findByText('Dogs only. Contains permethrin, which is toxic to cats. Never use it on a cat.'),
    ).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(
      await screen.findByText('This product is for dogs only: it is toxic to cats. Choose another plan.'),
    ).toBeTruthy();
    expect(screen.getByText('Check the highlighted fields.')).toBeTruthy();
  });

  it('checks the title and the interval before saving', async () => {
    const { server } = renderApp(`/pets/${MURKA}/plans/new/own`);
    fireEvent.change(await screen.findByLabelText('Every'), { target: { value: '0' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Enter what needs to be done')).toBeTruthy();
    expect(screen.getByText('Use a whole number from 1 to 120')).toBeTruthy();
    expect(document.activeElement).toBe(screen.getByLabelText('What to do'));
    expect(server.calls('POST', `/api/v1/pets/${MURKA}/care-plans`)).toHaveLength(0);
  });

  it('pauses a plan: it leaves the plan for "Finished or paused"', async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/plans/plan-exam`);
    const active = await screen.findByRole('checkbox', { name: 'Active' });
    expect(active).toHaveProperty('checked', true);
    fireEvent.click(active);
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/health`));
    expect(server.calls('PUT', '/api/v1/care-plans/plan-exam')[0]!.body).toMatchObject({ active: false });
    const plans = await region('Care plan');
    expect(await plans.findByRole('button', { name: 'Finished or paused (2)' })).toBeTruthy();
  });

  it('deletes a plan after asking', async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/plans/plan-rabies`);
    fireEvent.click(await screen.findByRole('button', { name: 'Delete plan' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete this plan?' }));
    expect(dialog.getByText(/Records already made with it stay in the history/)).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/health`));
    expect(server.calls('DELETE', '/api/v1/care-plans/plan-rabies')).toHaveLength(1);
    const plans = await region('Care plan');
    await waitFor(() => expect(plans.queryByRole('link', { name: 'Rabies' })).toBeNull());
  });
});

describe('the record form', () => {
  it("adds a past record with its kind's fields, and opens it", async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/records/new`);
    expect(await screen.findByLabelText('Title')).toHaveProperty('value', 'Vaccination');
    // The title follows the kind, and a vaccine's one disease, until something else is typed.
    fireEvent.click(
      within(screen.getByRole('group', { name: 'Protects against' })).getByRole('checkbox', {
        name: 'Rabies',
      }),
    );
    expect(screen.getByLabelText('Title')).toHaveProperty('value', 'Rabies');
    const date = addDays(server.world.today, -100);
    fireEvent.change(screen.getByLabelText('Date'), { target: { value: date } });
    fireEvent.change(screen.getByLabelText('Product'), { target: { value: 'Rabisin' } });
    fireEvent.change(screen.getByLabelText('Batch number'), { target: { value: 'R-77' } });
    fireEvent.change(screen.getByLabelText('Valid until'), { target: { value: addDays(date, 365) } });
    fireEvent.change(screen.getByLabelText('Vet'), { target: { value: 'Dr. Smirnov' } });
    expect(screen.queryByLabelText('Weight, kg')).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(router.state.location.pathname).toMatch(/^\/pets\/[^/]+\/records\/[0-9a-f-]{36}$/));
    const sent = server.calls('POST', `/api/v1/pets/${MURKA}/care-records`)[0]!.body as Record<string, unknown>;
    expect(sent).toMatchObject({
      kind: 'Vaccination',
      title: 'Rabies',
      performedOn: date,
      product: 'Rabisin',
      batchNumber: 'R-77',
      validUntil: addDays(date, 365),
      targets: ['Rabies'],
      veterinarian: 'Dr. Smirnov',
      weightKg: null,
      details: null,
    });
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(await screen.findByRole('heading', { name: 'Rabies', level: 1 })).toBeTruthy();
    expect((await region('Details')).getByText('R-77')).toBeTruthy();
  });

  it("a check-up's weight and fit to travel; the dates and the weight checked first", async () => {
    const { server } = renderApp(`/pets/${MURKA}/records/new?kind=VetExam`);
    expect(await screen.findByLabelText('Title')).toHaveProperty('value', 'Check-up');
    expect(screen.queryByLabelText('Product')).toBeNull();
    fireEvent.change(screen.getByLabelText('Weight, kg'), { target: { value: '4,2555' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Use 2 decimals at most')).toBeTruthy();
    expect(server.calls('POST', `/api/v1/pets/${MURKA}/care-records`)).toHaveLength(0);

    fireEvent.change(screen.getByLabelText('Weight, kg'), { target: { value: '4,25' } });
    fireEvent.click(screen.getByRole('checkbox', { name: 'Fit to travel' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('POST', `/api/v1/pets/${MURKA}/care-records`)).toHaveLength(1));
    expect(server.calls('POST', `/api/v1/pets/${MURKA}/care-records`)[0]!.body).toMatchObject({
      kind: 'VetExam',
      weightKg: 4.25,
      details: { fitForTravel: true, laboratory: null, reportNumber: null, titerIuPerMl: null },
      product: null,
    });
  });

  it("refuses a validity that ends before the vaccination, and shows the server's word under its field", async () => {
    const server = createTestServer();
    server.respond('PUT', '/api/v1/care-records/record-rabies', () =>
      problem(400, { errors: { batchNumber: ['At most 50 characters.'] } }),
    );
    renderApp(`/pets/${MURKA}/records/record-rabies/edit`, { server });
    const until = await screen.findByLabelText('Valid until');
    fireEvent.change(until, { target: { value: addDays(server.world.today, -400) } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Must be after the date of the vaccination and the start')).toBeTruthy();
    expect(server.calls('PUT', '/api/v1/care-records/record-rabies')).toHaveLength(0);

    fireEvent.change(until, { target: { value: addDays(server.world.today, 300) } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("This value wasn't accepted. Check it.")).toBeTruthy();
    expect(screen.getByLabelText('Batch number').getAttribute('aria-invalid')).toBe('true');
  });
});

describe("a record's page", () => {
  it('takes photos and PDF files dropped onto it, in order, and removes one after asking', async () => {
    const { server } = renderApp(`/pets/${MURKA}/records/record-rabies`);
    const files = await region('Photos and files');
    expect(files.getByRole('button', { name: 'File 1' })).toBeTruthy();
    const zone = document.querySelector('.file-drop') as HTMLElement;
    drop(zone, [file('sticker.jpg', 'image/jpeg'), file('conclusion.pdf', 'application/pdf')]);

    await waitFor(() => expect(server.calls('POST', '/api/v1/care-records/record-rabies/files')).toHaveLength(1));
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(2);
    const fileIds = (server.calls('POST', '/api/v1/care-records/record-rabies/files')[0]!.body as { fileIds: string[] })
      .fileIds;
    expect(fileIds).toHaveLength(2);
    // The PDF opens in a new tab, by its link.
    const pdf = await files.findByRole('link', { name: 'File 3: open the PDF in a new tab' });
    expect(pdf.getAttribute('target')).toBe('_blank');
    expect(pdf.getAttribute('href')).toContain(fileIds[1]);

    fireEvent.click(files.getByRole('button', { name: 'Remove file 1' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Remove this file?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Remove' }));
    await waitFor(() =>
      expect(server.calls('DELETE', '/api/v1/care-records/record-rabies/files/file-sticker')).toHaveLength(1),
    );
    await waitFor(() => expect(files.queryByRole('button', { name: 'File 3' })).toBeNull());
  });

  it("says why a file isn't taken, before uploading it", async () => {
    const { server } = renderApp(`/pets/${MURKA}/records/record-rabies`);
    await region('Photos and files');
    drop(document.querySelector('.file-drop') as HTMLElement, [
      file('photo.heic', 'image/heic'),
      file('scan.pdf', 'application/pdf', 16 * 1024 * 1024),
    ]);
    expect(
      await screen.findByText("photo.heic: This file type isn't supported. Use a photo (JPEG, PNG or WebP) or a PDF."),
    ).toBeTruthy();
    expect(screen.getByText('scan.pdf: This file is too large. Upload files up to 15 MB.')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(0);
  });

  it('opens a photo large', async () => {
    renderApp(`/pets/${MURKA}/records/record-rabies`);
    fireEvent.click(await (await region('Photos and files')).findByRole('button', { name: 'File 1' }));
    const viewer = within(await screen.findByRole('dialog', { name: 'Page 1 of 1' }));
    expect((viewer.getByRole('img', { name: 'Page 1' }) as HTMLImageElement).src).toContain('file-sticker');
  });

  it('deletes a record after asking; a deleted record is not shown from an old copy', async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/records/record-deworm`);
    fireEvent.click(await screen.findByRole('button', { name: 'Delete record' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete this record?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/health`));
    expect(server.calls('DELETE', '/api/v1/care-records/record-deworm')).toHaveLength(1);
    await act(async () => {
      await router.navigate(-1);
    });
    expect(await screen.findByText("This wasn't found. It may have been deleted.")).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Delete record' })).toBeNull();
  });

  it('a delete answered after the person went elsewhere leaves them where they went', async () => {
    const server = createTestServer();
    let answer!: () => void;
    const answered = new Promise<void>((resolve) => (answer = resolve));
    server.respond('DELETE', '/api/v1/care-records/record-deworm', async () => {
      await answered;
      return undefined;
    });
    const { router } = renderApp(`/pets/${MURKA}/records/record-deworm`, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Delete record' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete this record?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(server.calls('DELETE', '/api/v1/care-records/record-deworm')).toHaveLength(1));
    // Home, before the answer comes.
    await act(async () => {
      await router.navigate('/');
    });
    await act(async () => {
      answer();
      await new Promise((resolve) => setTimeout(resolve, 50));
    });
    expect(router.state.location.pathname).toBe('/');
  });
});

describe('for helpers', () => {
  it('shows the plan and the history, with "Done", and nothing to change', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Helper';
    const { router } = renderApp(`/pets/${MURKA}/health`, { server });
    const plans = await region('Care plan');
    expect(await plans.findByText('Rabies')).toBeTruthy();
    expect(plans.queryByRole('link', { name: 'Rabies' })).toBeNull();
    expect(plans.getAllByRole('button', { name: 'Done' }).length).toBeGreaterThan(0);
    expect(screen.queryByRole('link', { name: 'Add plan' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Add past record' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Enter from the passport' })).toBeNull();

    // A form's address typed in: a word instead of the form.
    await act(async () => {
      await router.navigate(`/pets/${MURKA}/plans/new`);
    });
    expect(await screen.findByRole('heading', { name: "Your role in the group doesn't allow this" })).toBeTruthy();
    await act(async () => {
      await router.navigate(`/pets/${MURKA}/records/record-rabies`);
    });
    expect(await screen.findByRole('heading', { name: 'Rabies', level: 1 })).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Edit' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Add files' })).toBeNull();
  });
});

// --- Review of part 2: lost answers, another phone's pause, a failed upload and more files ---

describe('records and plans and what happens meanwhile (review of part 2)', () => {
  it('a new record: a correction typed between a lost answer and the retry ends up in the record', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    let tries = 0;
    server.respond('POST', `/api/v1/pets/${MURKA}/care-records`, async (request) => {
      tries += 1;
      if (tries !== 1) return undefined;
      // The first try reaches the server, which adds the record; the answer is lost on the way back.
      await server.fetch(
        new Request(`http://localhost${request.path}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: request.authorization!, 'X-Household': HOME },
          body: JSON.stringify(request.body),
        }),
      );
      throw new TypeError('Failed to fetch');
    });
    renderApp(`/pets/${MURKA}/records/new`, { server });
    fireEvent.change(await screen.findByLabelText('Title'), { target: { value: 'Rabies (Nobivac)' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    // A typo fixed before saving again.
    fireEvent.change(screen.getByLabelText('Title'), { target: { value: 'Rabies (Nobivac RL)' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByRole('heading', { level: 1, name: 'Rabies (Nobivac RL)' })).toBeTruthy();
    expect(home.records.filter((item) => item.title.startsWith('Rabies (')).map((item) => item.title)).toEqual([
      'Rabies (Nobivac RL)',
    ]);
    expect(server.calls('PUT', /^\/api\/v1\/care-records\//)).toHaveLength(1);
  });

  it('a new plan: a correction after a lost answer follows it; a first try needs none', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    let tries = 0;
    server.respond('POST', `/api/v1/pets/${REX}/care-plans`, async (request) => {
      tries += 1;
      if (tries !== 1) return undefined;
      await server.fetch(
        new Request(`http://localhost${request.path}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: request.authorization!, 'X-Household': HOME },
          body: JSON.stringify(request.body),
        }),
      );
      throw new TypeError('Failed to fetch');
    });
    const { router } = renderApp(`/pets/${REX}/plans/new/own`, { server });
    fireEvent.change(await screen.findByLabelText('What to do'), { target: { value: 'Ear drops' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    fireEvent.change(screen.getByLabelText('What to do'), { target: { value: 'Ear cleaning' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${REX}/health`));
    expect(home.plans.filter((item) => item.title.startsWith('Ear')).map((item) => item.title)).toEqual([
      'Ear cleaning',
    ]);
  });

  it('a plan paused on another phone stays paused when the web form saves another change', async () => {
    const server = createTestServer();
    const exam = server.world.households.get(HOME)!.plans.find((item) => item.id === 'plan-exam')!;
    renderApp(`/pets/${MURKA}/plans/plan-exam`, { server });
    fireEvent.change(await screen.findByLabelText('What to do'), {
      target: { value: 'Yearly check-up with blood test' },
    });
    // Another member pauses the plan on the phone; the window comes back to the front and reads it again.
    exam.active = false;
    const asked = server.calls('GET', '/api/v1/care-plans/plan-exam').length;
    act(() => {
      window.dispatchEvent(new Event('visibilitychange'));
    });
    await waitFor(() => expect(server.calls('GET', '/api/v1/care-plans/plan-exam').length).toBeGreaterThan(asked));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(server.calls('PUT', '/api/v1/care-plans/plan-exam')).toHaveLength(1));
    const sent = server.calls('PUT', '/api/v1/care-plans/plan-exam')[0]!.body as { active: boolean | null };
    expect({ sentActive: sent.active, nowActive: exam.active }).toEqual({ sentActive: null, nowActive: false });
  });

  it('files dropped after a failed upload go along with the failed ones', async () => {
    const server = createTestServer();
    server.respond(
      'POST',
      '/api/v1/care-records/record-rabies/files',
      () => {
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp(`/pets/${MURKA}/records/record-rabies`, { server });
    await region('Photos and files');
    const zone = () => window.document.querySelector('.file-drop') as HTMLElement;
    drop(zone(), [file('sticker-back.jpg', 'image/jpeg')]);
    expect(await screen.findByRole('button', { name: 'Try again' })).toBeTruthy();
    // One more photo instead of "Try again".
    drop(zone(), [file('certificate.jpg', 'image/jpeg')]);
    await waitFor(() => expect(server.calls('POST', '/api/v1/care-records/record-rabies/files')).toHaveLength(2));
    await waitFor(() => expect(window.document.querySelector('.upload-progress')).toBeNull());
    const record = server.world.households.get(HOME)!.records.find((item) => item.id === 'record-rabies')!;
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(2);
    expect(record.files).toHaveLength(3);
    expect(screen.queryByRole('button', { name: 'Try again' })).toBeNull();
  });
});
