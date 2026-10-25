// Settings: the profile (the name; this browser's language; the phone's time zone, read only), the theme of this
// browser, the group's plan and AI (read only), where reminders come, "Download my data" (the ZIP saved under the
// server's name, the bytes so far, the limit of 5 an hour), and the way to deleting the account.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { exportFileName } from '../../api/export';
import { renderApp } from '../../test/render';
import { aiStatus, createTestServer, freePlan, OFFICE } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));

afterEach(() => {
  vi.restoreAllMocks();
});

/** The files the page handed to the browser to save, by name. */
function savedFiles() {
  const saved: string[] = [];
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function save(this: HTMLAnchorElement) {
    saved.push(this.download);
  });
  return saved;
}

describe('the profile', () => {
  it("saves the name only: this browser's language and the phone's time zone are never sent", async () => {
    const { server } = renderApp('/settings');
    const profile = await region('Profile');
    expect(profile.getByText('anna@example.com')).toBeTruthy();
    const name = profile.getByLabelText('Your name');
    expect(name).toHaveProperty('value', 'Anna');
    // The time zone is the phone's: shown, not changed here.
    expect(profile.getByText('Europe/Moscow')).toBeTruthy();
    expect(profile.queryByLabelText('Time zone')).toBeNull();
    fireEvent.change(name, { target: { value: 'Anna K.' } });
    fireEvent.click(profile.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Name saved')).toBeTruthy();
    expect(server.calls('PUT', '/api/v1/me').map((call) => call.body)).toEqual([
      { displayName: 'Anna K.', locale: null, timeZone: null },
    ]);

    // The language is this browser's, as in the sidebar.
    fireEvent.click(profile.getByRole('radio', { name: 'Русский' }));
    expect(await screen.findByRole('heading', { level: 1, name: 'Настройки' })).toBeTruthy();
    expect(window.localStorage.getItem('collarbell.language')).toBe('ru');
    expect(server.calls('PUT', '/api/v1/me')).toHaveLength(1);
  });

  it('asks before leaving a name typed and not saved', async () => {
    const { router } = renderApp('/settings');
    fireEvent.change((await region('Profile')).getByLabelText('Your name'), { target: { value: 'Anya' } });
    fireEvent.click(within(screen.getByRole('navigation', { name: 'Sections' })).getByRole('link', { name: 'Pets' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Cancel' }));
    expect(router.state.location.pathname).toBe('/settings');
  });
});

describe('the theme', () => {
  it("is the system's, or light or dark picked and remembered in this browser", async () => {
    renderApp('/settings');
    const theme = await region('Theme');
    expect(theme.getByRole('radio', { name: 'System' })).toHaveProperty('checked', true);
    expect(window.document.documentElement.dataset.theme).toBeUndefined();

    fireEvent.click(theme.getByRole('radio', { name: 'Dark' }));
    expect(window.document.documentElement.dataset.theme).toBe('dark');
    expect(window.localStorage.getItem('collarbell.theme')).toBe('dark');
    expect(theme.getByRole('radio', { name: 'Dark' })).toHaveProperty('checked', true);

    fireEvent.click(theme.getByRole('radio', { name: 'Light' }));
    expect(window.document.documentElement.dataset.theme).toBe('light');

    fireEvent.click(theme.getByRole('radio', { name: 'System' }));
    expect(window.document.documentElement.dataset.theme).toBeUndefined();
    expect(window.localStorage.getItem('collarbell.theme')).toBeNull();
  });

  it('starts with the one picked here before', async () => {
    window.localStorage.setItem('collarbell.theme', 'dark');
    renderApp('/settings');
    expect((await region('Theme')).getByRole('radio', { name: 'Dark' })).toHaveProperty('checked', true);
  });
});

describe('the plan, AI and notifications', () => {
  it("shows the group's plan and this month's AI photos, whether AI is set up, and where reminders come", async () => {
    renderApp('/settings');
    const plan = await region('Plan');
    expect(await plan.findByText('Free')).toBeTruthy();
    expect(plan.getByText('The plan of “My home”')).toBeTruthy();
    expect(plan.getByText('7 of 20')).toBeTruthy();
    expect(plan.getByText(/^The count starts again on /)).toBeTruthy();
    expect(plan.getByText('Premium: up to 300 AI photos a month.')).toBeTruthy();
    expect(plan.queryByRole('button')).toBeNull();

    const ai = await region('Reading photos with AI');
    expect(await ai.findByText('Connected')).toBeTruthy();
    expect(ai.getByText(/^Free Gemini tier/)).toBeTruthy();
    expect((await region('Notifications')).getByText(/^Reminders come to the phone app/)).toBeTruthy();
  });

  it('shows Premium with its end, used-up photos, and AI not set up', async () => {
    const server = createTestServer();
    const office = server.world.households.get(OFFICE)!;
    office.plan = freePlan({
      plan: 'Premium',
      source: 'Manual',
      expiresAt: '2027-12-31T12:00:00Z',
      aiPhotosPerMonth: 300,
      aiPhotosUsed: 300,
    });
    server.world.ai = aiStatus({ configured: false, freeTier: false });
    window.localStorage.setItem(
      'collarbell.household.uid-anna@example.com',
      JSON.stringify({ id: OFFICE, name: 'Office', role: 'Helper' }),
    );
    renderApp('/settings', { server });
    const plan = await region('Plan');
    expect(await plan.findByText('Premium')).toBeTruthy();
    expect(plan.getByText('Until Dec 31, 2027')).toBeTruthy();
    expect(plan.getByText(/^This month's AI photos are used up/)).toBeTruthy();
    expect(plan.queryByText(/^Premium: up to/)).toBeNull();
    const ai = await region('Reading photos with AI');
    expect(await ai.findByText('Not set up')).toBeTruthy();
    expect(ai.queryByText(/^Free Gemini tier/)).toBeNull();
  });
});

describe('your data', () => {
  it('downloads the ZIP under the name the server gives it', async () => {
    const saved = savedFiles();
    const { server } = renderApp('/settings');
    const data = await region('Your data');
    fireEvent.click(data.getByRole('button', { name: 'Download my data' }));
    expect(
      await data.findByText(/^Ready: .+ Saved to your downloads as collarbell-export-\d{4}-\d{2}-\d{2}\.zip\.$/),
    ).toBeTruthy();
    const today = new Date().toISOString().slice(0, 10);
    expect(saved).toEqual([`collarbell-export-${today}.zip`]);
    expect(server.calls('GET', '/api/v1/me/export')).toHaveLength(1);
    expect(data.getByRole('link', { name: 'Save it again' }).getAttribute('download')).toBe(
      `collarbell-export-${today}.zip`,
    );
  });

  it('shows the bytes so far while it comes, and stops on "Cancel"', async () => {
    const server = createTestServer();
    let send!: (bytes: Uint8Array) => void;
    server.respond('GET', '/api/v1/me/export', () => {
      const body = new ReadableStream<Uint8Array>({
        start(controller) {
          send = (bytes) => controller.enqueue(bytes);
        },
      });
      return new Response(body, {
        status: 200,
        headers: { 'Content-Type': 'application/zip', 'Content-Disposition': 'attachment; filename=export.zip' },
      });
    });
    const saved = savedFiles();
    renderApp('/settings', { server });
    const data = await region('Your data');
    fireEvent.click(data.getByRole('button', { name: 'Download my data' }));
    expect(await data.findByText('Preparing the file…')).toBeTruthy();
    await waitFor(() => expect(send).toBeTypeOf('function'));
    await act(async () => send(new Uint8Array(2048)));
    expect(await data.findByText('Downloaded: 2 KB')).toBeTruthy();
    fireEvent.click(data.getByRole('button', { name: 'Cancel' }));
    expect(await data.findByRole('button', { name: 'Download my data' })).toBeTruthy();
    expect(saved).toEqual([]);
  });

  it("says how long to wait after five downloads in an hour (the server's 429)", async () => {
    const server = createTestServer();
    server.respond(
      'GET',
      '/api/v1/me/export',
      () => new Response(null, { status: 429, headers: { 'Retry-After': '1500' } }),
      {
        once: true,
      },
    );
    savedFiles();
    renderApp('/settings', { server });
    const data = await region('Your data');
    fireEvent.click(data.getByRole('button', { name: 'Download my data' }));
    expect(
      await data.findByText("You've downloaded your data several times this hour. Try again in 25 minutes."),
    ).toBeTruthy();
    // No "Try again": it would be refused too.
    expect(data.queryByRole('button', { name: 'Try again' })).toBeNull();
  });

  it('the sixth download in an hour is refused by the server, with the wait', async () => {
    const server = createTestServer();
    server.world.exports = [1, 2, 3, 4, 5].map((minutes) => Date.now() - minutes * 60_000);
    savedFiles();
    renderApp('/settings', { server });
    const data = await region('Your data');
    fireEvent.click(data.getByRole('button', { name: 'Download my data' }));
    expect(
      await data.findByText(/^You've downloaded your data several times this hour\. Try again in 55 minutes\.$/),
    ).toBeTruthy();
  });

  it("leads to deleting the account, and keeps the site's page about it for those without a password", async () => {
    renderApp('/settings');
    const data = await region('Your data');
    expect(data.getByText(/^You see first what happens to each of your groups/)).toBeTruthy();
    expect(data.getByRole('link', { name: 'Delete account…' }).getAttribute('href')).toBe('/settings/delete-account');
    expect(data.getByRole('link', { name: 'How deleting an account works' }).getAttribute('href')).toBe(
      '/delete-account/',
    );
    fireEvent.click(within(screen.getByRole('banner')).getByRole('radio', { name: 'Русский' }));
    expect((await screen.findByRole('link', { name: 'Как удаляется аккаунт' })).getAttribute('href')).toBe(
      '/ru/delete-account/',
    );
  });
});

describe("the download's file name after part 3's review", () => {
  it("names the file as the server's Content-Disposition does, in its forms, and nothing else", () => {
    const today = new Date(2026, 9, 7);
    expect(
      exportFileName(
        "attachment; filename=collarbell-export-2026-10-06.zip; filename*=UTF-8''collarbell-export-2026-10-06.zip",
        today,
      ),
    ).toBe('collarbell-export-2026-10-06.zip');
    expect(exportFileName('attachment; filename="collarbell-export-2026-10-06.zip"', today)).toBe(
      'collarbell-export-2026-10-06.zip',
    );
    expect(exportFileName('attachment; filename="../evil.zip"', today)).toBe('collarbell-export-2026-10-07.zip');
    expect(exportFileName(null, today)).toBe('collarbell-export-2026-10-07.zip');
  });
});
