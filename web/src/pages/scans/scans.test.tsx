// Scans of passport pages and vet documents: the card on the Passport tab, the photos picked or dropped (a PDF said to
// be no photo for AI, ten at most), the upload and the start (POST /files, then POST /ai-imports), the wait (asked
// every two seconds), the draft to check and its save; the month's AI photos, too many requests, AI not set up; a
// failed scan read again in its place, or dismissed; a ready one picked up from its card; helpers, and a server
// without AI, see no scan buttons.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ApplyImportRequest, CreateAiImportRequest } from '../../api/types';
import { draft, draftRecord } from '../../test/ai';
import { slowHeic, type SlowHeic } from '../../test/heic';
import { renderApp } from '../../test/render';
import { aiImport, aiStatus, createTestServer, HOME, MURKA, problem, uploadedFile } from '../../test/server';

const photo = (name: string, type = 'image/jpeg') => new File([new Uint8Array(500)], name, { type });
const drop = (files: File[], target: Element | null = document.querySelector('.file-drop')) =>
  fireEvent.drop(target as Element, { dataTransfer: { files, types: ['Files'] } });
const region = async (name: string) => within(await screen.findByRole('region', { name }));

afterEach(() => {
  vi.useRealTimers();
});

describe('a scan of passport pages', () => {
  it('uploads the photos, starts the scan, waits for AI, and opens the draft to check; saving says what it saved', async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'setTimeout', 'clearTimeout'], shouldAdvanceTime: true });
    const { server, router } = renderApp(`/pets/${MURKA}/passport`);
    const card = await screen.findByRole('link', { name: 'Scan pages' });
    expect(screen.getByText('Scan passport pages')).toBeTruthy();
    fireEvent.click(card);
    expect(await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 })).toBeTruthy();
    // Before anything is sent: a draft only, and the free tier's warning.
    expect(screen.getByText('AI only prepares a draft: you check every entry and decide what to save.')).toBeTruthy();
    expect(screen.getByText(/^Free Gemini tier: Google may use what is sent/)).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Read the pages' })).toHaveProperty('disabled', true);
    drop([photo('page-1.jpg'), photo('page-2.png', 'image/png')]);
    expect(await screen.findByRole('img', { name: 'Page 2: page-2.png' })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Read the pages' }));

    await waitFor(() => expect(server.calls('POST', '/api/v1/ai-imports')).toHaveLength(1));
    const uploads = server.calls('POST', '/api/v1/files');
    expect(uploads).toHaveLength(2);
    const sent = server.calls('POST', '/api/v1/ai-imports')[0]!.body as CreateAiImportRequest;
    expect(sent).toMatchObject({ petId: MURKA, source: 'PassportPages', text: null, retryOf: null });
    expect(sent.fileIds).toHaveLength(2);
    expect(sent.requestId).toMatch(/^[0-9a-f-]{36}$/);
    // The scan's own page: being read, asked about again two seconds later, then the draft.
    await waitFor(() => expect(router.state.location.pathname).toMatch(new RegExp(`^/pets/${MURKA}/scans/[^/]+$`)));
    expect(await screen.findByText('Reading the pages…')).toBeTruthy();
    expect(screen.getByText(/the scan waits for you on the Passport tab/)).toBeTruthy();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(2100);
    });
    expect(await screen.findByRole('heading', { name: 'Check the scan', level: 1 })).toBeTruthy();
    const records = await region('Records');
    expect(records.getByRole('heading', { name: 'Rabies vaccination' })).toBeTruthy();
    expect(records.getByRole('checkbox', { name: 'Save this entry: Rabies vaccination' })).toHaveProperty('checked', true);
    expect(records.getByRole('checkbox', { name: 'Mark as done in plan “Rabies”' })).toHaveProperty('checked', true);
    // The photos beside the draft, kept as passport pages unless said otherwise.
    const photos = await region('Photos');
    expect(photos.getByRole('button', { name: 'Page 1' })).toBeTruthy();
    expect(photos.getByRole('checkbox', { name: 'Keep the photos as passport pages' })).toHaveProperty('checked', true);

    fireEvent.click(screen.getByRole('button', { name: 'Save 1 selected' }));
    expect(await screen.findByText('Saved 1 record · 1 plan updated · photos added to the passport pages')).toBeTruthy();
    const applied = server.calls('POST', /\/api\/v1\/ai-imports\/[^/]+\/apply$/)[0]!.body as ApplyImportRequest;
    expect(applied).toMatchObject({
      records: [
        {
          planId: 'plan-rabies',
          record: { kind: 'Vaccination', title: 'Rabies vaccination', product: 'Nobivac Rabies', targets: ['Rabies'] },
        },
      ],
      identifiers: [],
      passport: null,
      weights: [],
      keepPhotos: true,
    });
    // The pages are the passport's now.
    const home = server.world.households.get(HOME)!;
    expect(home.documents.find((each) => each.id === 'doc-passport')!.pages).toHaveLength(4);
    expect(home.records.filter((each) => each.source === 'AiScan')).toHaveLength(1);
    expect(screen.getByRole('link', { name: 'To the Passport tab' }).getAttribute('href')).toBe(`/pets/${MURKA}/passport`);
  });

  it("says a PDF is no photo for AI (a screenshot of it is), and takes ten pages at most", async () => {
    const { server } = renderApp(`/pets/${MURKA}/scan`);
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop([photo('results.pdf', 'application/pdf'), photo('page.jpg')]);
    expect(
      await screen.findByText(
        "results.pdf: AI doesn't read PDF files. Take a screenshot or a photo of the page and add that instead.",
      ),
    ).toBeTruthy();
    expect(await screen.findByRole('img', { name: 'Page 1: page.jpg' })).toBeTruthy();
    drop(Array.from({ length: 11 }, (_, index) => photo(`more-${index}.jpg`)));
    expect(await screen.findByText('Only the first 10 pages are used.')).toBeTruthy();
    await waitFor(() => expect(screen.getAllByRole('img', { name: /^Page \d+:/ })).toHaveLength(10));
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(0);
  });

  it('a HEIC photo this browser can\'t open is said so (the server takes JPEG, PNG and WebP)', async () => {
    renderApp(`/pets/${MURKA}/scan`);
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop([photo('IMG_0042.HEIC', '')]);
    expect(await screen.findByText(/^IMG_0042\.HEIC: this browser can't open HEIC photos/)).toBeTruthy();
  });

  it("the month's AI photos used up: says how many are left and until when, with the plan, and no \"Try again\"", async () => {
    const server = createTestServer();
    const plan = server.world.households.get(HOME)!.plan;
    plan.aiPhotosUsed = 19;
    renderApp(`/pets/${MURKA}/scan`, { server });
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop([photo('a.jpg'), photo('b.jpg')]);
    await screen.findByRole('img', { name: 'Page 2: b.jpg' });
    fireEvent.click(screen.getByRole('button', { name: 'Read the pages' }));
    expect(await screen.findByText('1 of 20 photos are left this month: choose fewer.')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'See the plan' }).getAttribute('href')).toBe('/settings');
    expect(screen.queryByRole('button', { name: 'Try again' })).toBeNull();
    // Fewer photos may do: back to them, still picked.
    fireEvent.click(screen.getByRole('button', { name: 'Change the photos' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Remove page 2' }));
    fireEvent.click(screen.getByRole('button', { name: 'Read the pages' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/ai-imports')).toHaveLength(2));
    expect(plan.aiPhotosUsed).toBe(20);
  });

  it("all used up: \"AI has read 20 of 20 photos\" with the day the count starts again", async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.plan.aiPhotosUsed = 20;
    renderApp(`/pets/${MURKA}/scan`, { server });
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop([photo('a.jpg')]);
    fireEvent.click(await screen.findByRole('button', { name: 'Read the pages' }));
    expect(
      await screen.findByText(/^AI has read 20 of 20 photos this month: that's the limit of the Free plan\. The count starts again on /),
    ).toBeTruthy();
  });

  it('too many requests a minute: how long to wait; "Try again" sends the same request id and the uploads once', async () => {
    const server = createTestServer();
    server.respond(
      'POST',
      '/api/v1/ai-imports',
      () => new Response(null, { status: 429, headers: { 'Retry-After': '20' } }),
      { once: true },
    );
    renderApp(`/pets/${MURKA}/scan`, { server });
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop([photo('a.jpg')]);
    fireEvent.click(await screen.findByRole('button', { name: 'Read the pages' }));
    expect(await screen.findByText('Too many requests in a row. Try again in 20 seconds.')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/ai-imports')).toHaveLength(2));
    const [first, second] = server.calls('POST', '/api/v1/ai-imports').map((call) => call.body as CreateAiImportRequest);
    expect(second!.requestId).toBe(first!.requestId);
    expect(second!.fileIds).toEqual(first!.fileIds);
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(1);
  });

  it("AI not set up on the server (any more): said so, nothing more to try, and the scan buttons go", async () => {
    const server = createTestServer();
    renderApp(`/pets/${MURKA}/scan`, { server });
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    server.world.ai = aiStatus({ configured: false });
    drop([photo('a.jpg')]);
    fireEvent.click(await screen.findByRole('button', { name: 'Read the pages' }));
    expect(await screen.findByText(/^AI isn't set up on the server\./)).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Try again' })).toBeNull();
    await waitFor(() => expect(server.calls('GET', '/api/v1/ai/status').length).toBeGreaterThanOrEqual(2));
  });

  it('a vet document is a scan of its own kind, from the Health tab', async () => {
    const { server } = renderApp(`/pets/${MURKA}/health`);
    fireEvent.click(await screen.findByRole('link', { name: 'Scan a vet document' }));
    expect(await screen.findByRole('heading', { name: 'Scan a vet document', level: 1 })).toBeTruthy();
    expect(screen.getByRole('radio', { name: 'Vet document' })).toHaveProperty('checked', true);
    drop([photo('invoice.jpg')]);
    fireEvent.click(await screen.findByRole('button', { name: 'Read the pages' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/ai-imports')).toHaveLength(1));
    expect((server.calls('POST', '/api/v1/ai-imports')[0]!.body as CreateAiImportRequest).source).toBe('VetDocument');
  });
});

describe('scans waiting on the Passport tab', () => {
  function withScans() {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    home.imports.push(
      aiImport('scan-ready', MURKA, {
        fileIds: [uploadedFile(server.world, 'upload-1')],
        outcome: { draft: draft({ records: [draftRecord({ performedOn: server.world.today })] }) },
      }),
      aiImport('scan-failed', MURKA, {
        status: 'Failed',
        error: 'Busy',
        fileIds: [uploadedFile(server.world, 'upload-2'), uploadedFile(server.world, 'upload-3')],
      }),
      aiImport('note-ready', MURKA, { source: 'Text', text: 'Weighs 4 kg' }),
    );
    return server;
  }

  it('shows a ready one to continue and a failed one with why; notes wait on the Health tab instead', async () => {
    const server = withScans();
    renderApp(`/pets/${MURKA}/passport`, { server });
    const ready = await screen.findByRole('link', { name: /^Continue checking the scan from / });
    expect(ready.getAttribute('href')).toBe(`/pets/${MURKA}/scans/scan-ready`);
    expect(screen.getByText("Couldn't be read")).toBeTruthy();
    expect(screen.getByText('The AI models are busy or out of free requests right now. Try again in a few minutes.')).toBeTruthy();
    expect(screen.queryByText(/note from/i)).toBeNull();
    expect(server.calls('GET', `/api/v1/pets/${MURKA}/ai-imports`)[0]!.query.get('notes')).toBe('false');
  });

  it('"Try again" reads the failed scan\'s photos anew, in its place (retryOf)', async () => {
    const server = withScans();
    const { router } = renderApp(`/pets/${MURKA}/passport`, { server });
    fireEvent.click(await screen.findByRole('link', { name: 'Try again' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/ai-imports')).toHaveLength(1));
    const sent = server.calls('POST', '/api/v1/ai-imports')[0]!.body as CreateAiImportRequest;
    expect(sent).toMatchObject({ petId: MURKA, source: 'PassportPages', fileIds: ['upload-2', 'upload-3'], retryOf: 'scan-failed' });
    // Nothing uploaded again: the photos are on the server.
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(0);
    await waitFor(() => expect(router.state.location.pathname).toMatch(/\/scans\/(?!scan-failed)[^/]+$/));
    expect(server.world.households.get(HOME)!.imports.find((each) => each.id === 'scan-failed')!.status).toBe('Discarded');
  });

  it('"Dismiss" throws a failed scan away', async () => {
    const server = withScans();
    renderApp(`/pets/${MURKA}/passport`, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Dismiss' }));
    await waitFor(() => expect(server.calls('DELETE', '/api/v1/ai-imports/scan-failed')).toHaveLength(1));
    await waitFor(() => expect(screen.queryByText("Couldn't be read")).toBeNull());
  });

  it("a ready scan's page is its review; discarding it asks first, then the Passport tab", async () => {
    const server = withScans();
    const { router } = renderApp(`/pets/${MURKA}/scans/scan-ready`, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Discard scan' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Discard this scan?' }));
    expect(asking.getByText('Nothing from it is saved, and its photos are deleted.')).toBeTruthy();
    fireEvent.click(asking.getByRole('button', { name: 'Discard' }));
    expect(await screen.findByText('Scan discarded')).toBeTruthy();
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/passport`));
    expect(server.world.households.get(HOME)!.imports.find((each) => each.id === 'scan-ready')!.status).toBe('Discarded');
  });

  it("a server without AI shows no scan card, but the scans waiting still show", async () => {
    const server = withScans();
    server.world.ai = aiStatus({ configured: false });
    renderApp(`/pets/${MURKA}/passport`, { server });
    expect(await screen.findByRole('link', { name: /^Continue checking the scan from / })).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Scan pages' })).toBeNull();
  });

  it('helpers see no scans and no scan buttons', async () => {
    const server = withScans();
    server.world.households.get(HOME)!.summary.role = 'Helper';
    renderApp(`/pets/${MURKA}/passport`, { server });
    await screen.findByRole('region', { name: 'Passport details' });
    expect(screen.queryByRole('link', { name: 'Scan pages' })).toBeNull();
    expect(screen.queryByText(/Continue checking the scan/)).toBeNull();
  });

  it('a scan saved elsewhere opens as saved, with what it saved', async () => {
    const server = withScans();
    const home = server.world.households.get(HOME)!;
    const saved = home.imports.find((each) => each.id === 'scan-ready')!;
    saved.status = 'Applied';
    saved.result = { recordIds: ['r1', 'r2'], plansMoved: 0, identifiersAdded: 0, passportUpdated: false, documentId: null, weightsAdded: 0 };
    renderApp(`/pets/${MURKA}/scans/scan-ready`, { server });
    expect(await screen.findByText('Saved 2 records')).toBeTruthy();
  });

  it('a scan that is gone says so', async () => {
    renderApp(`/pets/${MURKA}/scans/no-such-scan`);
    expect(await screen.findByText('This scan no longer exists.')).toBeTruthy();
  });

  it("the pet gone while starting: said, and back to the pets", async () => {
    const server = createTestServer();
    server.respond('POST', '/api/v1/ai-imports', () => problem(404), { once: true });
    const { router } = renderApp(`/pets/${MURKA}/scan`, { server });
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop([photo('a.jpg')]);
    fireEvent.click(await screen.findByRole('button', { name: 'Read the pages' }));
    expect(await screen.findByText('This pet has been deleted, probably on another device.')).toBeTruthy();
    await waitFor(() => expect(router.state.location.pathname).toBe('/pets'));
  });
});

describe('photos for a scan, while iPhone photos are made JPEGs', () => {
  let heic: SlowHeic;
  beforeEach(() => {
    heic = slowHeic();
  });
  afterEach(() => {
    heic.restore();
    vi.restoreAllMocks();
  });
  const heics = (count: number) => Array.from({ length: count }, (_, index) => photo(`iphone-${index}.heic`, 'image/heic'));
  const jpegs = (count: number) => Array.from({ length: count }, (_, index) => photo(`page-${index}.jpg`));
  async function convertAll(count: number) {
    for (let done = 0; done < count; done += 1) {
      await waitFor(() => expect(heic.waiting).toBeGreaterThan(0));
      heic.finish();
    }
  }

  it('the drop zone waits, saying so, and takes no other photos meanwhile: never more than 10 in all', async () => {
    const { server } = renderApp(`/pets/${MURKA}/scan?from=passport`);
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop(heics(5));
    expect(await screen.findByText('Preparing the photos…')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Add photos' })).toHaveProperty('disabled', true);
    expect(screen.getByRole('button', { name: 'Read the pages' })).toHaveProperty('disabled', true);
    // Eight more meanwhile: not taken.
    drop(jpegs(8));
    await convertAll(5);
    expect(await screen.findByRole('img', { name: 'Page 5: iphone-4.jpg' })).toBeTruthy();
    expect(screen.queryByText('Preparing the photos…')).toBeNull();
    expect(screen.getAllByRole('img', { name: /^Page \d+: / })).toHaveLength(5);
    // The eight again, now: five fit.
    drop(jpegs(8));
    expect(await screen.findByText('Only the first 10 pages are used.')).toBeTruthy();
    expect(screen.getAllByRole('img', { name: /^Page \d+: / })).toHaveLength(10);
    fireEvent.click(screen.getByRole('button', { name: 'Read the pages' }));
    await waitFor(() => expect(server.calls('POST', '/api/v1/ai-imports')).toHaveLength(1));
    expect((server.calls('POST', '/api/v1/ai-imports')[0]!.body as CreateAiImportRequest).fileIds).toHaveLength(10);
  });

  it('leaving while they are made asks first; ready after leaving, they make no pictures', async () => {
    const pictures = vi.spyOn(URL, 'createObjectURL');
    const { router } = renderApp(`/pets/${MURKA}/scan?from=passport`);
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop(heics(1));
    await screen.findByText('Preparing the photos…');
    fireEvent.click(screen.getAllByRole('link', { name: 'Murka' })[0]!);
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Leave' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/passport`));
    await convertAll(1);
    await act(async () => new Promise((resolve) => setTimeout(resolve, 20)));
    expect(pictures).not.toHaveBeenCalled();
  });

  it('a photo removed gives its picture back at once; the others theirs when the page goes', async () => {
    const given = vi.spyOn(URL, 'revokeObjectURL');
    const { router } = renderApp(`/pets/${MURKA}/scan?from=passport`);
    await screen.findByRole('heading', { name: 'Scan passport pages', level: 1 });
    drop(jpegs(3));
    await screen.findByRole('img', { name: 'Page 3: page-2.jpg' });
    fireEvent.click(screen.getByRole('button', { name: 'Remove page 1' }));
    expect(given).toHaveBeenCalledTimes(1);
    expect(screen.getByRole('img', { name: 'Page 1: page-1.jpg' })).toBeTruthy();
    fireEvent.click(screen.getAllByRole('link', { name: 'Murka' })[0]!);
    fireEvent.click(within(await screen.findByRole('dialog', { name: 'Leave without saving?' })).getByRole('button', { name: 'Leave' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/passport`));
    expect(new Set(given.mock.calls.map(([url]) => url)).size).toBe(3);
  });
});

describe('a failed scan, again', () => {
  it('"Scan again" on a failed vet document whose photos are gone scans a vet document again', async () => {
    const server = createTestServer();
    server.world.households
      .get(HOME)!
      .imports.push(aiImport('doc-scan', MURKA, { source: 'VetDocument', status: 'Failed', error: 'PhotosMissing', fileIds: [] }));
    const { router } = renderApp(`/pets/${MURKA}/scans/doc-scan`, { server });
    fireEvent.click(await screen.findByRole('link', { name: 'Scan again' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/scan`));
    expect(await screen.findByRole('heading', { name: 'Scan a vet document', level: 1 })).toBeTruthy();
    expect(screen.getByRole('radio', { name: 'Vet document' })).toHaveProperty('checked', true);
    // Its card on the Passport tab says the same.
    await act(() => router.navigate(`/pets/${MURKA}/passport`));
    const card = await screen.findByRole('link', { name: 'Scan again' });
    expect(card.getAttribute('href')).toBe(`/pets/${MURKA}/scan?source=document&from=passport`);
  });

  it('opened again after its "Try again" had started it (a reload): the scan that took its place opens', async () => {
    const server = createTestServer();
    const photos = [uploadedFile(server.world, 'upload-1'), uploadedFile(server.world, 'upload-2')];
    server.world.households
      .get(HOME)!
      .imports.push(
        aiImport('scan-failed', MURKA, { status: 'Discarded', error: 'Busy', fileIds: photos, createdAt: '2026-10-06T09:00:00Z' }),
        aiImport('scan-again', MURKA, { status: 'Processing', fileIds: photos }),
      );
    const { router } = renderApp(`/pets/${MURKA}/scan?again=scan-failed&from=passport`, { server });
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/scans/scan-again`));
    expect(await screen.findByText('Reading the pages…')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/ai-imports')).toHaveLength(0);
    expect(screen.queryByText('The photos of this scan are gone. Scan the pages again.')).toBeNull();
  });

  it('read again or dismissed, with no scan in its place: said so, and photos can be picked anew', async () => {
    const server = createTestServer();
    server.world.households
      .get(HOME)!
      .imports.push(aiImport('scan-failed', MURKA, { status: 'Discarded', fileIds: [uploadedFile(server.world, 'upload-1')] }));
    renderApp(`/pets/${MURKA}/scan?again=scan-failed&from=passport`, { server });
    expect(
      await screen.findByText('This scan was read again already, or dismissed. Its photos are no longer here to read.'),
    ).toBeTruthy();
    expect(screen.queryByText('The photos of this scan are gone. Scan the pages again.')).toBeNull();
    expect(screen.getByRole('button', { name: 'Add photos' })).toHaveProperty('disabled', false);
    expect(server.calls('POST', '/api/v1/ai-imports')).toHaveLength(0);
  });
});
