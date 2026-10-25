// The Documents tab: the documents by type, a new document from files dropped (in that order, the wrong ones refused
// before uploading), its pages viewed large with the arrow keys, a PDF in a new tab, pages added and removed, the
// details changed, a document deleted.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import type { DocumentRequest } from '../../api/types';
import { renderApp } from '../../test/render';
import { createTestServer, document, HOME, MURKA, storedFile } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));
const file = (name: string, type: string, size = 1000) => new File([new Uint8Array(size)], name, { type });
const dropOn = (files: File[]) =>
  fireEvent.drop(window.document.querySelector('.file-drop') as HTMLElement, {
    dataTransfer: { files, types: ['Files'] },
  });

describe('the Documents tab', () => {
  it('lists the documents by type, with their pages', async () => {
    renderApp(`/pets/${MURKA}/documents`);
    const lab = await region('Lab results');
    const blood = await lab.findByRole('link', { name: 'Blood test' });
    expect(within(blood.closest('li') as HTMLElement).getByText(/^Lab results · .+ · 1 page$/)).toBeTruthy();
    // A document without a title is called by its type.
    const pages = await region('Passport pages');
    expect(pages.getByRole('link', { name: 'Passport pages' })).toBeTruthy();
    expect(pages.getByText(/ · 2 pages$/)).toBeTruthy();
  });

  it('makes a document of the files dropped, in their order, after refusing what it can not take', async () => {
    const { server } = renderApp(`/pets/${MURKA}/documents`);
    await region('Lab results');
    dropOn([
      file('page-1.jpg', 'image/jpeg'),
      file('photo.heic', 'image/heic'),
      file('huge.pdf', 'application/pdf', 16 * 1024 * 1024),
      file('page-2.pdf', 'application/pdf'),
    ]);
    expect(
      await screen.findByText("photo.heic: This file type isn't supported. Use a photo (JPEG, PNG or WebP) or a PDF."),
    ).toBeTruthy();
    expect(screen.getByText('huge.pdf: This file is too large. Upload files up to 15 MB.')).toBeTruthy();
    const dialog = within(await screen.findByRole('dialog', { name: 'New document' }));
    expect(dialog.getByRole('img', { name: 'Page 1: page-1.jpg' })).toBeTruthy();
    expect(dialog.getByRole('img', { name: 'Page 2: page-2.pdf' })).toBeTruthy();
    fireEvent.change(dialog.getByLabelText('Type'), { target: { value: 'Prescription' } });
    fireEvent.change(dialog.getByLabelText('Title (optional)'), { target: { value: 'Antibiotics' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));

    expect(await screen.findByText('Document added')).toBeTruthy();
    const uploads = server.calls('POST', '/api/v1/files');
    expect(uploads).toHaveLength(2);
    const sent = server.calls('POST', `/api/v1/pets/${MURKA}/documents`)[0]!.body as DocumentRequest;
    expect(sent).toMatchObject({ type: 'Prescription', title: 'Antibiotics', documentDate: null, notes: null });
    // The pages in the order dropped: the photo first, the PDF second.
    const created = server.world.households.get(HOME)!.documents.at(-1)!;
    expect(created.pages).toEqual(sent.fileIds);
    expect(server.world.files.get(sent.fileIds[0]!)!.contentType).toBe('image/jpeg');
    expect(server.world.files.get(sent.fileIds[1]!)!.contentType).toBe('application/pdf');
    expect(await (await region('Prescription')).findByRole('link', { name: 'Antibiotics' })).toBeTruthy();
  });

  it('a document needs a page, and asks before its dropped files are thrown away', async () => {
    const { server } = renderApp(`/pets/${MURKA}/documents`);
    await region('Lab results');
    dropOn([file('page.jpg', 'image/jpeg')]);
    const dialog = within(await screen.findByRole('dialog', { name: 'New document' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Remove page 1' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await dialog.findByText('Add at least one page')).toBeTruthy();
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(0);
    fireEvent.click(dialog.getByRole('button', { name: 'Cancel' }));
    expect(await screen.findByRole('dialog', { name: 'Leave without saving?' })).toBeTruthy();
  });

  it("a new document's retry after a lost answer doesn't make it twice", async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    server.respond(
      'POST',
      `/api/v1/pets/${MURKA}/documents`,
      (request) => {
        // The document is made; the answer is lost.
        const body = request.body as DocumentRequest;
        home.documents.push(document('lost-answer', MURKA, { type: body.type, pages: [...body.fileIds] }));
        for (const id of body.fileIds) server.world.files.get(id)!.attached = true;
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp(`/pets/${MURKA}/documents`, { server });
    await region('Lab results');
    dropOn([file('page.jpg', 'image/jpeg')]);
    const dialog = within(await screen.findByRole('dialog', { name: 'New document' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await dialog.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Document added')).toBeTruthy();
    // The file was uploaded once, the document made once.
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(1);
    expect(server.calls('POST', `/api/v1/pets/${MURKA}/documents`)).toHaveLength(1);
    expect(home.documents.filter((item) => item.type === 'Other')).toHaveLength(1);
  });

  it('a helper sees the documents and adds none', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Helper';
    renderApp(`/pets/${MURKA}/documents`, { server });
    expect(await (await region('Lab results')).findByRole('link', { name: 'Blood test' })).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Add document' })).toBeNull();
  });
});

describe("a document's page", () => {
  it('turns the pages with the arrow keys and the buttons', async () => {
    renderApp(`/pets/${MURKA}/documents/doc-passport`);
    fireEvent.click(await (await region('Pages')).findByRole('button', { name: 'Page 1' }));
    const viewer = await screen.findByRole('dialog', { name: 'Page 1 of 2' });
    expect(within(viewer).getByRole('button', { name: 'Previous page' })).toHaveProperty('disabled', true);
    fireEvent.keyDown(viewer, { key: 'ArrowRight' });
    expect(await screen.findByRole('dialog', { name: 'Page 2 of 2' })).toBeTruthy();
    expect(within(viewer).getByRole('button', { name: 'Next page' })).toHaveProperty('disabled', true);
    fireEvent.click(within(viewer).getByRole('button', { name: 'Previous page' }));
    expect(await screen.findByRole('dialog', { name: 'Page 1 of 2' })).toBeTruthy();
    fireEvent.keyDown(viewer, { key: 'ArrowLeft' });
    expect(screen.getByRole('dialog', { name: 'Page 1 of 2' })).toBeTruthy();
  });

  it('opens a PDF in a new tab by its link; a link about to expire is renewed first', async () => {
    const { server } = renderApp(`/pets/${MURKA}/documents/doc-lab`);
    const link = await (await region('Pages')).findByRole('link', { name: 'Page 1: open the PDF in a new tab' });
    expect(link.getAttribute('target')).toBe('_blank');
    expect(link.getAttribute('rel')).toContain('noopener');
    expect(link.getAttribute('href')).toContain('file-lab.pdf');
    expect(server.calls('GET', '/api/v1/files/file-lab/url')).toHaveLength(0);
  });

  it('adds pages dropped onto the document, at its end', async () => {
    const { server } = renderApp(`/pets/${MURKA}/documents/doc-lab`);
    await (await region('Pages')).findByRole('link', { name: /^Page 1/ });
    dropOn([file('page-2.jpg', 'image/jpeg'), file('page-3.jpg', 'image/jpeg')]);
    await waitFor(() => expect(server.calls('POST', '/api/v1/documents/doc-lab/pages')).toHaveLength(1));
    expect(await (await region('Pages')).findByRole('button', { name: 'Page 3' })).toBeTruthy();
  });

  it('deletes a page after asking; the last one takes the document with it', async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/documents/doc-lab`);
    fireEvent.click(await (await region('Pages')).findByRole('button', { name: 'Remove page 1' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete this page?' }));
    expect(dialog.getByText(/It is the document's only page: the document will be deleted too/)).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/documents`));
    expect(server.calls('DELETE', '/api/v1/documents/doc-lab/pages/file-lab')).toHaveLength(1);
    expect(await screen.findByText('The document was deleted with its last page.')).toBeTruthy();
    expect(screen.queryByRole('region', { name: 'Lab results' })).toBeNull();
  });

  it('changes the details, and deletes the document after asking', async () => {
    const { server, router } = renderApp(`/pets/${MURKA}/documents/doc-lab`);
    fireEvent.click(await screen.findByRole('button', { name: 'Edit details' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Edit document' }));
    expect(dialog.getByLabelText('Title (optional)')).toHaveProperty('value', 'Blood test');
    fireEvent.change(dialog.getByLabelText('Title (optional)'), { target: { value: 'Blood test, full' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await screen.findByRole('heading', { name: 'Blood test, full', level: 1 })).toBeTruthy();
    expect(server.calls('PUT', '/api/v1/documents/doc-lab')[0]!.body).toMatchObject({
      type: 'LabResult',
      title: 'Blood test, full',
    });

    fireEvent.click(screen.getByRole('button', { name: 'Delete document' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Delete this document?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/pets/${MURKA}/documents`));
    expect(server.calls('DELETE', '/api/v1/documents/doc-lab')).toHaveLength(1);
  });

  it('a delete answered after the person went elsewhere leaves them where they went', async () => {
    const server = createTestServer();
    let answer!: () => void;
    const answered = new Promise<void>((resolve) => (answer = resolve));
    server.respond('DELETE', '/api/v1/documents/doc-lab', async () => {
      await answered;
      return undefined;
    });
    const { router } = renderApp(`/pets/${MURKA}/documents/doc-lab`, { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Delete document' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Delete this document?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(server.calls('DELETE', '/api/v1/documents/doc-lab')).toHaveLength(1));
    // Today, before the answer comes.
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

describe('download links (they live 15 minutes and change in every answer)', () => {
  it('keeps showing a page at its first link while it lives; a page whose link failed asks for a fresh one', async () => {
    const { server } = renderApp(`/pets/${MURKA}/documents/doc-passport`);
    const pages = await region('Pages');
    const image = () => pages.getByRole('img', { name: 'Page 1' }) as HTMLImageElement;
    await pages.findByRole('img', { name: 'Page 1' });
    const first = image().getAttribute('src');
    // Read again (the window came back): new links in the answer, the same picture on screen.
    const asked = server.calls('GET', '/api/v1/documents/doc-passport').length;
    act(() => {
      window.dispatchEvent(new Event('visibilitychange'));
    });
    await waitFor(() => expect(server.calls('GET', '/api/v1/documents/doc-passport').length).toBe(asked + 1));
    expect(image().getAttribute('src')).toBe(first);
    // The link died while the page stood open: one fresh link, from the server.
    fireEvent.error(image());
    await waitFor(() => expect(server.calls('GET', '/api/v1/files/file-page-1/url')).toHaveLength(1));
    await waitFor(() => expect(image().getAttribute('src')).not.toBe(first));
  });

  it('renews a PDF link about to expire before it is clicked: its address always works', async () => {
    const server = createTestServer();
    server.respond('GET', '/api/v1/documents/doc-lab', () =>
      json(200, {
        ...server.world.households.get(HOME)!.documents.find((item) => item.id === 'doc-lab'),
        pages: [{ ...oldPdfLink, expiresAt: new Date(Date.now() + 30_000).toISOString() }],
      }),
    );
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    renderApp(`/pets/${MURKA}/documents/doc-lab`, { server });
    const pages = await region('Pages');
    const link = () => pages.getByRole('link', { name: 'Page 1: open the PDF in a new tab' });
    // Renewed ahead: a click, a middle click or "Open in new tab" all use a link that works.
    await waitFor(() => expect(link().getAttribute('href')).toContain('file-lab.pdf'));
    expect(server.calls('GET', '/api/v1/files/file-lab/url')).toHaveLength(1);
    expect(fireEvent.click(link())).toBe(true);
    expect(open).not.toHaveBeenCalled();
    open.mockRestore();
  });

  it('a link that died all the same opens the tab within the click, and sends it to a fresh link', async () => {
    const server = createTestServer();
    server.respond('GET', '/api/v1/documents/doc-lab', () =>
      json(200, {
        ...server.world.households.get(HOME)!.documents.find((item) => item.id === 'doc-lab'),
        pages: [{ ...oldPdfLink, expiresAt: new Date(Date.now() - 1000).toISOString() }],
      }),
    );
    // The renewal ahead of time gets no answer (the computer was offline).
    server.respond(
      'GET',
      '/api/v1/files/file-lab/url',
      () => {
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    const tab = { opener: {} as unknown, location: { href: '' }, close: vi.fn() };
    const open = vi.spyOn(window, 'open').mockImplementation(() => tab as unknown as Window);
    renderApp(`/pets/${MURKA}/documents/doc-lab`, { server });
    const pages = await region('Pages');
    await waitFor(() => expect(server.calls('GET', '/api/v1/files/file-lab/url')).toHaveLength(1));
    // Opened at once, while the click counts as the person's: a pop-up blocker lets it through.
    expect(fireEvent.click(pages.getByRole('link', { name: 'Page 1: open the PDF in a new tab' }))).toBe(false);
    expect(open).toHaveBeenCalledWith('', '_blank');
    expect(tab.opener).toBeNull();
    await waitFor(() => expect(tab.location.href).toContain('file-lab.pdf'));
    expect(open).toHaveBeenCalledTimes(1);
    open.mockRestore();
  });

  it('never opens an expired link after a reload brought fresher ones (review of part 2)', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    home.documents.push(
      document('doc-pdf-probe', MURKA, {
        type: 'LabResult',
        title: 'Probe PDF',
        pages: [
          storedFile(server.world, 'file-pdf-probe', 'https://files.example/file-pdf-probe.pdf', 'application/pdf'),
        ],
      }),
    );
    const base = Date.now();
    let offset = 0;
    vi.spyOn(Date, 'now').mockImplementation(() => base + offset);
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    renderApp(`/pets/${MURKA}/documents/doc-pdf-probe`, { server });
    const pages = await region('Pages');
    const link = () => pages.getByRole('link', { name: 'Page 1: open the PDF in a new tab' });
    const firstHref = (await pages.findByRole('link', { name: 'Page 1: open the PDF in a new tab' })).getAttribute(
      'href',
    );
    // Ten minutes later the window comes back: the document is read again, with links for 15 more minutes.
    offset = 10 * 60_000;
    const asked = server.calls('GET', '/api/v1/documents/doc-pdf-probe').length;
    act(() => {
      window.dispatchEvent(new Event('visibilitychange'));
    });
    await waitFor(() => expect(server.calls('GET', '/api/v1/documents/doc-pdf-probe').length).toBe(asked + 1));
    // The address is the newer link at once: a PDF keeps no older link.
    await waitFor(() => expect(link().getAttribute('href')).not.toBe(firstHref));
    // Sixteen minutes after the first answer (whose link died at fifteen), the click follows a link that lives.
    offset = 16 * 60_000;
    expect(fireEvent.click(link())).toBe(true);
    expect(open).not.toHaveBeenCalled();
    vi.restoreAllMocks();
  });
});

/** A PDF page's link as an older answer gave it. */
const oldPdfLink = {
  id: 'file-lab',
  contentType: 'application/pdf',
  sizeBytes: 1000,
  width: null,
  height: null,
  url: 'https://files.example/old-link',
  thumbnailUrl: null,
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

// --- Review of part 2: a lost answer, removed pages, the last page, the details' data, the viewer ---

describe('documents and what happens meanwhile (review of part 2)', () => {
  it('a new document retried after a lost answer keeps the pages and details changed since', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    server.respond(
      'POST',
      `/api/v1/pets/${MURKA}/documents`,
      (request) => {
        // The document is made; the answer is lost.
        const body = request.body as DocumentRequest;
        home.documents.push(
          document('lost-answer', MURKA, { type: body.type, title: body.title, pages: [...body.fileIds] }),
        );
        for (const id of body.fileIds) server.world.files.get(id)!.attached = true;
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp(`/pets/${MURKA}/documents`, { server });
    await region('Lab results');
    dropOn([file('page-1.jpg', 'image/jpeg')]);
    const dialogElement = await screen.findByRole('dialog', { name: 'New document' });
    const dialog = within(dialogElement);
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await dialog.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();

    // The forgotten second page and a title, then "Save" again.
    fireEvent.drop(dialogElement.querySelector('.file-drop') as HTMLElement, {
      dataTransfer: { files: [file('page-2.jpg', 'image/jpeg')], types: ['Files'] },
    });
    await dialog.findByRole('img', { name: 'Page 2: page-2.jpg' });
    fireEvent.change(dialog.getByLabelText('Title (optional)'), { target: { value: 'Blood test, 2 pages' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Document added')).toBeTruthy();

    const made = home.documents.find((item) => item.id === 'lost-answer')!;
    expect(server.calls('POST', '/api/v1/files')).toHaveLength(2);
    expect(server.calls('POST', `/api/v1/pets/${MURKA}/documents`)).toHaveLength(1);
    expect({
      pages: made.pages.length,
      title: made.title,
      leftOver: [...server.world.files.values()].filter((item) => !item.attached).length,
    }).toEqual({ pages: 2, title: 'Blood test, 2 pages', leftOver: 0 });
  });

  it('a new document without pages: the focus goes to "Add pages", not the hidden file input', async () => {
    renderApp(`/pets/${MURKA}/documents`);
    await region('Lab results');
    dropOn([file('page-1.jpg', 'image/jpeg')]);
    const dialog = within(await screen.findByRole('dialog', { name: 'New document' }));
    const remove = dialog.getByRole('button', { name: 'Remove page 1' });
    remove.focus();
    fireEvent.click(remove);
    // The last page went: the focus stays in the dialog, on "Add pages".
    await waitFor(() => expect(window.document.activeElement).toBe(dialog.getByRole('button', { name: 'Add pages' })));
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await dialog.findByText('Add at least one page')).toBeTruthy();
    expect(window.document.activeElement).toBe(dialog.getByRole('button', { name: 'Add pages' }));
  });

  it("lets go of a removed page's picture at once", async () => {
    const revoke = vi.spyOn(URL, 'revokeObjectURL');
    renderApp(`/pets/${MURKA}/documents`);
    await region('Lab results');
    dropOn([file('page-1.jpg', 'image/jpeg'), file('page-2.jpg', 'image/jpeg')]);
    const dialog = within(await screen.findByRole('dialog', { name: 'New document' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Remove page 1' }));
    await waitFor(() => expect(dialog.queryByRole('img', { name: 'Page 2: page-2.jpg' })).toBeNull());
    expect(revoke).toHaveBeenCalledTimes(1);
    revoke.mockRestore();
  });

  it('a page deleted while another phone added one: the document stays, as the server says', async () => {
    const server = createTestServer();
    const lab = server.world.households.get(HOME)!.documents.find((item) => item.id === 'doc-lab')!;
    const { router } = renderApp(`/pets/${MURKA}/documents/doc-lab`, { server });
    const remove = await (await region('Pages')).findByRole('button', { name: 'Remove page 1' });
    // Another phone adds a second page meanwhile.
    lab.pages.push(storedFile(server.world, 'file-lab-2', 'https://files.example/file-lab-2'));
    fireEvent.click(remove);
    const dialog = within(await screen.findByRole('dialog', { name: 'Delete this page?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(server.calls('GET', '/api/v1/documents/doc-lab').length).toBeGreaterThan(1));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(router.state.location.pathname).toBe(`/pets/${MURKA}/documents/doc-lab`);
    expect(screen.queryByText('The document was deleted with its last page.')).toBeNull();
    expect(server.world.households.get(HOME)!.documents.some((item) => item.id === 'doc-lab')).toBe(true);
  });

  it("the details form waits for the document's own answer, not a list's copy", async () => {
    const server = createTestServer();
    let release!: () => void;
    const gate = new Promise<void>((resolve) => (release = resolve));
    server.respond(
      'GET',
      '/api/v1/documents/doc-lab',
      async () => {
        await gate;
        return undefined;
      },
      { once: true },
    );
    const { router } = renderApp(`/pets/${MURKA}/documents`, { server });
    await region('Lab results');
    await act(async () => {
      await router.navigate(`/pets/${MURKA}/documents/doc-lab`);
    });
    const edit = await screen.findByRole('button', { name: 'Edit details' });
    expect(edit).toHaveProperty('disabled', true);
    await act(async () => release());
    await waitFor(() => expect(edit).toHaveProperty('disabled', false));
  });

  it('the large view closes when its pages went away meanwhile', async () => {
    const server = createTestServer();
    renderApp(`/pets/${MURKA}/documents/doc-passport`, { server });
    fireEvent.click(await (await region('Pages')).findByRole('button', { name: 'Page 1' }));
    expect(await screen.findByRole('dialog', { name: 'Page 1 of 2' })).toBeTruthy();
    // Another phone deletes the pages; the window comes back and reads the document again.
    server.world.households.get(HOME)!.documents.find((item) => item.id === 'doc-passport')!.pages = [];
    act(() => {
      window.dispatchEvent(new Event('visibilitychange'));
    });
    await waitFor(() => expect(screen.queryByRole('dialog', { name: /^Page \d of/ })).toBeNull());
  });
});

describe("a new document after part 3's review", () => {
  it('retried after a lost answer with a page swapped meanwhile, is made once: found by any file a try sent', async () => {
    const server = createTestServer();
    const home = server.world.households.get(HOME)!;
    server.respond(
      'POST',
      `/api/v1/pets/${MURKA}/documents`,
      (request) => {
        // The document is made; the answer is lost.
        const body = request.body as DocumentRequest;
        home.documents.push(document('lost-answer', MURKA, { type: body.type, pages: [...body.fileIds] }));
        for (const id of body.fileIds) server.world.files.get(id)!.attached = true;
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp(`/pets/${MURKA}/documents`, { server });
    await region('Lab results');
    const before = home.documents.length;
    dropOn([file('wrong.jpg', 'image/jpeg', 10)]);
    const dialogElement = await screen.findByRole('dialog', { name: 'New document' });
    const dialog = within(dialogElement);
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await dialog.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    // The wrong photo out, the right one in, then "Save" again.
    fireEvent.click(dialog.getByRole('button', { name: 'Remove page 1' }));
    fireEvent.drop(dialogElement.querySelector('.file-drop') as HTMLElement, {
      dataTransfer: { files: [file('right.jpg', 'image/jpeg', 10)], types: ['Files'] },
    });
    await dialog.findByRole('img', { name: 'Page 1: right.jpg' });
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Document added')).toBeTruthy();
    // One new document: the lost answer's, with the right page only.
    expect(home.documents.length - before).toBe(1);
    const made = home.documents.find((each) => each.id === 'lost-answer')!;
    expect(made.pages).toHaveLength(1);
    expect(server.world.files.get(made.pages[0]!)).toBeTruthy();
  });
});
