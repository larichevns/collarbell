// Signing in and what the session does with the server's answers: the profile first, the household of last time,
// the language of the profile, signing out on a 401, "Couldn't open your account" when there is no answer.
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { opened, renderApp } from './test/render';
import { ANNA, createTestServer, HOME, OFFICE, problem } from './test/server';

describe('signing in', () => {
  it('signs in with the e-mail and password, and opens Home after asking for the profile first', async () => {
    const { server } = renderApp('/', { user: null });
    expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeTruthy();
    // No sign-up on the web: accounts start in the phone app.
    expect(screen.getByText(/Create an account in the phone app/)).toBeTruthy();

    fireEvent.change(screen.getByLabelText('Email'), { target: { value: ANNA } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'wrong' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByText('Wrong email or password.')).toBeTruthy();

    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'secret' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByRole('region', { name: 'Right now' })).toBeTruthy();
    expect(server.requests[0]).toMatchObject({
      method: 'GET',
      path: '/api/v1/me',
      authorization: `Bearer token:${ANNA}`,
    });
  });

  it('checks the form before asking Firebase', async () => {
    const { auth } = renderApp('/', { user: null });
    await screen.findByRole('heading', { name: 'Sign in' });
    fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'not an email' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByText('Enter an email like name@example.com')).toBeTruthy();
    expect(screen.getByText('Enter your password')).toBeTruthy();
    expect(screen.getByLabelText('Email').getAttribute('aria-invalid')).toBe('true');
    expect(auth.resets).toEqual([]);
  });

  it('sends the letter for a new password in the language on screen', async () => {
    const { auth } = renderApp('/', { user: null });
    await screen.findByRole('heading', { name: 'Sign in' });
    fireEvent.click(screen.getByRole('button', { name: 'Forgot password?' }));
    expect(await screen.findByText(/Enter your e-mail above/)).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: 'Русский' }));
    fireEvent.change(screen.getByLabelText('Эл. почта'), { target: { value: ANNA } });
    fireEvent.click(screen.getByRole('button', { name: 'Забыли пароль?' }));
    expect(await screen.findByText(/на него придёт письмо со ссылкой/)).toBeTruthy();
    expect(auth.resets).toEqual([{ email: ANNA, lang: 'ru' }]);
  });

  it('signs out from the sidebar', async () => {
    renderApp('/');
    await opened();
    fireEvent.click(screen.getByRole('button', { name: 'Sign out' }));
    expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeTruthy();
  });
});

describe('the session', () => {
  it('signs out and says so when the account was deleted on the phone', async () => {
    const server = createTestServer();
    server.respond('GET', '/api/v1/today', () => problem(401, { type: 'urn:collarbell:problem:account-deleted' }));
    renderApp('/', { server });
    expect(await screen.findByText('Your account has been deleted.')).toBeTruthy();
    expect(screen.getByRole('heading', { name: 'Sign in' })).toBeTruthy();
  });

  it("forgets the deleted account's household on this browser; an expired sign-in keeps it for the next one", async () => {
    const remembered = `collarbell.household.uid-${ANNA}`;
    const deleted = createTestServer();
    const { router } = renderApp('/today', { server: deleted });
    await screen.findByRole('region', { name: 'Feeding' });
    await waitFor(() => expect(window.localStorage.getItem(remembered)).not.toBeNull());
    deleted.respond('GET', '/api/v1/pets', () => problem(401, { type: 'urn:collarbell:problem:account-deleted' }));
    await act(() => router.navigate('/pets'));
    expect(await screen.findByText('Your account has been deleted.')).toBeTruthy();
    expect(window.localStorage.getItem(remembered)).toBeNull();

    const expired = createTestServer();
    const second = renderApp('/today', { server: expired });
    await screen.findAllByRole('region', { name: 'Feeding' });
    await waitFor(() => expect(window.localStorage.getItem(remembered)).not.toBeNull());
    expired.respond('GET', '/api/v1/pets', () => problem(401));
    await act(() => second.router.navigate('/pets'));
    expect(await screen.findByText('Your session has expired. Sign in again.')).toBeTruthy();
    expect(window.localStorage.getItem(remembered)).not.toBeNull();
  });

  it('signs out when the sign-in is no longer valid', async () => {
    const server = createTestServer();
    server.respond('GET', '/api/v1/pets', () => problem(401));
    renderApp('/pets', { server });
    expect(await screen.findByText('Your session has expired. Sign in again.')).toBeTruthy();
  });

  it('says it when the account could not be opened, and tries again', async () => {
    const server = createTestServer();
    server.respond('GET', '/api/v1/me', () => problem(500, { traceId: 'trace-7' }), { once: true });
    renderApp('/', { server });
    expect(await screen.findByRole('heading', { name: "Couldn't open your account" })).toBeTruthy();
    expect(screen.getByText('Error ID: trace-7')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await opened()).toBeTruthy();
  });

  it('speaks the language of the profile, and keeps a language picked in this browser', async () => {
    const server = createTestServer();
    server.world.locale = 'ru';
    renderApp('/today', { server });
    expect(await screen.findByRole('heading', { name: 'Сегодня', level: 1 })).toBeTruthy();
    expect(document.documentElement.lang).toBe('ru');

    fireEvent.click(screen.getByRole('radio', { name: 'English' }));
    expect(await screen.findByRole('heading', { name: 'Today', level: 1 })).toBeTruthy();
    expect(window.localStorage.getItem('collarbell.language')).toBe('en');
  });

  it('opens the household of last time, and says when the person is no longer in it', async () => {
    window.localStorage.setItem(
      `collarbell.household.uid-${ANNA}`,
      JSON.stringify({ id: OFFICE, name: 'Office', role: 'Helper' }),
    );
    const server = createTestServer();
    renderApp('/', { server });
    await opened();
    expect(server.calls('GET', '/api/v1/me')[0]!.household).toBe(OFFICE);
    expect(within(screen.getByRole('banner')).getByLabelText('Group')).toHaveProperty('value', OFFICE);
    await waitFor(() => expect(server.calls('GET', '/api/v1/today')[0]!.household).toBe(OFFICE));
  });

  it('moves to the first household when the remembered one is gone', async () => {
    window.localStorage.setItem(
      `collarbell.household.uid-${ANNA}`,
      JSON.stringify({ id: OFFICE, name: 'Office', role: 'Helper' }),
    );
    const server = createTestServer();
    server.world.memberships = [HOME];
    renderApp('/', { server });
    expect(await screen.findByText("You're no longer in “Office”.")).toBeTruthy();
    await waitFor(() => expect(server.calls('GET', '/api/v1/today').at(-1)!.household).toBe(HOME));
  });
});

// --- Review of part 1 (P5, P11 and the sign-out): another sign-in starts from nothing ---

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const pause = (ms = 40) =>
  act(async () => {
    await new Promise((resolve) => setTimeout(resolve, ms));
  });

describe('signing in again, or as someone else', () => {
  it('the same person signing in again gets the groups and role /me answers now, /me first (P5)', async () => {
    const server = createTestServer();
    renderApp('/today', { server });
    await opened();
    await screen.findByRole('region', { name: 'Feeding' });
    fireEvent.click(screen.getByRole('button', { name: 'Sign out' }));
    await screen.findByRole('heading', { name: 'Sign in' });
    // Meanwhile, on the phone, Anna left "Office" and an owner made her a helper of Home.
    server.world.memberships = [HOME];
    server.world.households.get(HOME)!.summary.role = 'Helper';

    const from = server.requests.length;
    fireEvent.change(screen.getByLabelText('Email'), { target: { value: ANNA } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'secret' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    await waitFor(() => expect(server.calls('GET', '/api/v1/me')).toHaveLength(2));
    await screen.findByRole('region', { name: 'Feeding' });
    await pause();
    const after = server.requests.slice(from).map((request) => `${request.method} ${request.path}`);
    expect(after[0]).toBe('GET /api/v1/me');
    expect(within(screen.getByRole('banner')).queryByLabelText('Group')).toBeNull();
    expect(screen.getByText('Sees everything and marks feedings, “Done”, visits and purchases.')).toBeTruthy();
  });

  it("someone else signed in without a sign-out in between never sees the last person's groups or day (P11)", async () => {
    const server = createTestServer();
    const { auth } = renderApp('/today', { server });
    await screen.findAllByRole('button', { name: 'Fed' });

    const BOB = 'bob@example.com';
    const BOB_HOME = '33333333-3333-4333-8333-333333333333';
    const bobHome = { id: BOB_HOME, name: 'Home', role: 'Owner' as const, timeZone: 'Europe/Moscow', memberCount: 1 };
    const seenByBob: string[] = [];
    server.respond('GET', /.*/, (request) => {
      // Anna's requests still on their way are refused: her sign-in is over.
      if (request.authorization !== `Bearer token:${BOB}`) return problem(401);
      seenByBob.push(`${request.path} @${request.household}`);
      if (request.path === '/api/v1/me') {
        return json(200, {
          id: 'user-bob',
          email: BOB,
          displayName: 'Bob',
          locale: 'en',
          timeZone: 'Europe/Moscow',
          household: { id: BOB_HOME, name: 'Home', role: 'Owner', timeZone: 'Europe/Moscow' },
          households: [bobHome],
        });
      }
      if (request.path === '/api/v1/households') return json(200, [bobHome]);
      if (request.household && request.household !== BOB_HOME) {
        return problem(403, { type: 'urn:collarbell:problem:not-a-household-member' });
      }
      if (request.path === '/api/v1/today') {
        return json(200, { date: request.query.get('date'), feedings: [], appointments: [], care: [], shopping: [] });
      }
      return json(200, []);
    });

    const shownToBob: string[] = [];
    const observer = new MutationObserver(() => {
      if (seenByBob.length && document.body.textContent?.includes('Murka')) shownToBob.push('Murka');
      if (seenByBob.length && document.body.textContent?.includes('Office · Helper')) shownToBob.push('Office');
    });
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    await act(async () => {
      await auth.signIn(BOB, 'secret');
    });
    await waitFor(() => expect(seenByBob.some((line) => line.startsWith('/api/v1/me'))).toBe(true));
    await pause(150);
    observer.disconnect();

    expect([...new Set(shownToBob)]).toEqual([]);
    expect(seenByBob.filter((line) => line.includes(HOME) || line.includes(OFFICE))).toEqual([]);
    expect(screen.queryByText("You're no longer in “My home”.")).toBeNull();
    // A 401 of Anna's earlier request doesn't sign Bob out.
    expect(screen.queryByRole('heading', { name: 'Sign in' })).toBeNull();
    expect(await screen.findByRole('heading', { name: 'Today', level: 1 })).toBeTruthy();
  });

  it('signing out takes the messages away and forgets what this browser keeps of other accounts', async () => {
    window.localStorage.setItem('collarbell.household.uid-someone@example.com', JSON.stringify({ id: 'x' }));
    window.localStorage.setItem('collarbell.onboarding.uid-someone@example.com', '1');
    const server = createTestServer();
    server.respond('POST', /\/completions$/, () => problem(500), { once: true });
    renderApp('/', { server });
    fireEvent.click((await screen.findAllByRole('button', { name: 'Fed' }))[0]!);
    expect(await screen.findByText('Something went wrong on our side. Try again in a moment.')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Sign out' }));
    await screen.findByRole('heading', { name: 'Sign in' });
    expect(screen.queryByText('Something went wrong on our side. Try again in a moment.')).toBeNull();
    expect(window.localStorage.getItem('collarbell.household.uid-someone@example.com')).toBeNull();
    expect(window.localStorage.getItem('collarbell.onboarding.uid-someone@example.com')).toBeNull();
    expect(window.localStorage.getItem(`collarbell.household.uid-${ANNA}`)).not.toBeNull();
    // Anna's own onboarding had its turn on Home (her household has pets): it stays taken.
    expect(window.localStorage.getItem(`collarbell.onboarding.uid-${ANNA}`)).toBe('1');
  });
});
