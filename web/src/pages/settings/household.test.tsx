// The group in Settings, by role: owners rename it, set its time zone, change roles (asking an owner who steps down),
// remove people, invite (a code and a link to copy) and revoke; members and helpers see the people and leave. Every
// person's groups: switch, create one, delete one of one's own, join another with a code (from an invite's link too).
import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { opened, renderApp } from '../../test/render';
import { ANNA, createTestServer, FRIENDS, FRIENDS_CODE, HOME, invite, OFFICE } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));
const picker = () => within(screen.getByRole('banner')).getByLabelText('Group') as HTMLSelectElement;

afterEach(() => {
  vi.restoreAllMocks();
});

/** Anna on screen in OFFICE, where she helps. */
function inOffice() {
  window.localStorage.setItem(
    `collarbell.household.uid-${ANNA}`,
    JSON.stringify({ id: OFFICE, name: 'Office', role: 'Helper' }),
  );
}

describe('an owner', () => {
  it('renames the group and sets its time zone: only what changed is sent, and the sidebar follows', async () => {
    const { server } = renderApp('/settings');
    const group = await region('Group');
    const name = await group.findByLabelText('Name');
    // The server's "Home" is no name of hers: she types one.
    expect(name).toHaveProperty('value', '');
    expect(name.getAttribute('placeholder')).toBe('My home');
    expect(group.getByLabelText('Time zone')).toHaveProperty('value', 'Europe/Moscow');
    fireEvent.change(name, { target: { value: 'Our flat' } });
    fireEvent.change(group.getByLabelText('Time zone'), { target: { value: 'Europe/Berlin' } });
    fireEvent.click(group.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Group saved')).toBeTruthy();
    expect(server.calls('PUT', '/api/v1/households/current')[0]).toMatchObject({
      household: HOME,
      body: { name: 'Our flat', timeZone: 'Europe/Berlin' },
    });
    await waitFor(() => expect([...picker().options].map((option) => option.text)).toContain('Our flat · Owner'));
  });

  it("lists the people with their roles; changes a role; an owner stepping down is asked, and the server's word said", async () => {
    const { server } = renderApp('/settings');
    const members = await region('Members');
    expect(await members.findByText('Boris')).toBeTruthy();
    expect(members.getByText('boris@example.com')).toBeTruthy();
    expect(members.getByText('anna@example.com · you')).toBeTruthy();
    fireEvent.click(members.getByRole('button', { name: 'Change role: Boris' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Boris' }));
    expect(dialog.getByRole('radio', { name: 'Member' })).toHaveProperty('checked', true);
    expect(dialog.getByText('Sees everything and marks feedings, “Done”, visits and purchases.')).toBeTruthy();
    fireEvent.click(dialog.getByRole('radio', { name: 'Helper' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(server.calls('PUT', '/api/v1/households/current/members/user-boris')[0]!.body).toEqual({ role: 'Helper' });
    const boris = members.getByText('Boris').closest('li') as HTMLElement;
    expect(within(boris).getByText('Helper')).toBeTruthy();

    // Anna steps down: asked first; she is the last owner, which the server says.
    fireEvent.click(members.getByRole('button', { name: 'Change role: Anna' }));
    const own = within(await screen.findByRole('dialog', { name: 'Anna' }));
    fireEvent.click(own.getByRole('radio', { name: 'Member' }));
    fireEvent.click(own.getByRole('button', { name: 'Save' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Stop being an owner?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Change my role' }));
    expect(await own.findByText('Make someone else an owner first.')).toBeTruthy();
  });

  it('removes someone after asking', async () => {
    const { server } = renderApp('/settings');
    const members = await region('Members');
    fireEvent.click(await members.findByRole('button', { name: 'Remove from group: Boris' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Remove from the group?' }));
    expect(dialog.getByText('Boris will no longer see the pets of this group. Their marks stay.')).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Remove' }));
    await waitFor(() => expect(members.queryByText('Boris')).toBeNull());
    expect(server.calls('DELETE', '/api/v1/households/current/members/user-boris')).toHaveLength(1);
    expect(members.queryByRole('button', { name: /^Remove from group/ })).toBeNull();
  });

  it('invites a helper: the code and a link to copy; the open invite is revoked', async () => {
    const copied: string[] = [];
    Object.defineProperty(window.navigator, 'clipboard', {
      configurable: true,
      value: { writeText: (text: string) => Promise.resolve(void copied.push(text)) },
    });
    const { server } = renderApp('/settings');
    fireEvent.click(await (await region('Members')).findByRole('button', { name: 'Invite' }));
    const choose = within(await screen.findByRole('dialog', { name: 'Who are you inviting?' }));
    fireEvent.click(choose.getByRole('radio', { name: 'Helper' }));
    fireEvent.click(choose.getByRole('button', { name: 'Create the code' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Invite code' }));
    expect(server.calls('POST', '/api/v1/households/current/invites')[0]!.body).toEqual({ role: 'Helper' });
    const code = server.world.households.get(HOME)!.invites[0]!.code;
    const shown = `${code.slice(0, 4)}-${code.slice(4)}`;
    expect(dialog.getByText(shown)).toBeTruthy();
    expect(dialog.getByText('The code works once, for 7 days.')).toBeTruthy();
    const link = dialog.getByLabelText('Link to join on the web') as HTMLInputElement;
    // The join page of the web app (under /app on the server; the tests' router has no base).
    expect(link.value).toBe(`${window.location.origin}/join#${shown}`);
    fireEvent.click(dialog.getByRole('button', { name: 'Copy the link' }));
    expect(await dialog.findByText('Copied.')).toBeTruthy();
    fireEvent.click(dialog.getByRole('button', { name: 'Copy the code' }));
    await waitFor(() => expect(copied).toEqual([link.value, shown]));
    fireEvent.click(dialog.getAllByRole('button', { name: 'Close' }).at(-1)!);

    const invites = await region('Open invites');
    expect(invites.getByText(/^Helper · until /)).toBeTruthy();
    fireEvent.click(invites.getByRole('button', { name: `Revoke ${shown}` }));
    expect(await screen.findByText('The invite was revoked.')).toBeTruthy();
    await waitFor(() => expect(screen.queryByRole('region', { name: 'Open invites' })).toBeNull());
    expect(server.world.households.get(HOME)!.invites).toEqual([]);
    Reflect.deleteProperty(window.navigator, 'clipboard');
  });

  it('asks before another group takes the place of a name typed here', async () => {
    renderApp('/settings');
    fireEvent.change(await (await region('Group')).findByLabelText('Name'), { target: { value: 'Our fl' } });
    fireEvent.change(picker(), { target: { value: OFFICE } });
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Cancel' }));
    expect(picker().value).toBe(HOME);
    expect((await region('Group')).getByLabelText('Name')).toHaveProperty('value', 'Our fl');
  });
});

describe('a member and a helper', () => {
  it('a member sees the people without changing them, and leaves after asking: the next group opens', async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.summary.role = 'Member';
    server.world.households.get(HOME)!.others[0]!.role = 'Owner';
    renderApp('/settings', { server });
    const members = await region('Members');
    expect(await members.findByText('Boris')).toBeTruthy();
    expect(members.queryByRole('button', { name: /^Change role/ })).toBeNull();
    expect(members.queryByRole('button', { name: 'Invite' })).toBeNull();
    expect(screen.queryByRole('region', { name: 'Open invites' })).toBeNull();
    const group = await region('Group');
    expect(group.queryByLabelText('Name')).toBeNull();
    expect(group.getByText('Europe/Moscow')).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: 'Leave group' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Leave “Home”?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Leave' }));
    expect(await screen.findByText('You left “Home”.')).toBeTruthy();
    expect(server.calls('DELETE', '/api/v1/households/current/members/user-anna')[0]!.household).toBe(HOME);
    // Office is on screen now; Home isn't hers any more, without a second word about it.
    await waitFor(() => expect(within(screen.getByRole('banner')).getByText('Office')).toBeTruthy());
    expect(screen.queryByText("You're no longer in “Home”.")).toBeNull();
    expect(server.world.memberships).toEqual([OFFICE]);
  });

  it('a helper sees the names (no e-mails) and nothing to change', async () => {
    inOffice();
    renderApp('/settings');
    const members = await region('Members');
    expect(await members.findByText('Olga')).toBeTruthy();
    expect(members.queryByText('olga@example.com')).toBeNull();
    // Someone without a name, whose e-mail a helper doesn't see.
    expect(members.getByText('No name')).toBeTruthy();
    expect(members.queryByRole('button', { name: /^(Change role|Remove from group)/ })).toBeNull();
    expect(screen.getByRole('button', { name: 'Leave group' })).toBeTruthy();
  });
});

describe("the person's groups", () => {
  it('switches to another group, and the page stays', async () => {
    const { server, router } = renderApp('/settings');
    const groups = await region('Your groups');
    expect(groups.getByText('Owner · 2 people')).toBeTruthy();
    expect(groups.getByText('Current')).toBeTruthy();
    fireEvent.click(groups.getByRole('button', { name: 'Switch to Office' }));
    await waitFor(() => expect(picker().value).toBe(OFFICE));
    expect(router.state.location.pathname).toBe('/settings');
    await waitFor(() => expect(server.calls('GET', '/api/v1/households/current').at(-1)!.household).toBe(OFFICE));
  });

  it('creates a group, which opens; one alone and empty is deleted after asking', async () => {
    const { server } = renderApp('/settings');
    fireEvent.click(await (await region('Your groups')).findByRole('button', { name: 'Create a group' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'New group' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Create' }));
    expect(await dialog.findByText('Give the group a name.')).toBeTruthy();
    fireEvent.change(dialog.getByLabelText('Name'), { target: { value: 'Studio' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Create' }));
    expect(await screen.findByText("You're in “Studio” now.")).toBeTruthy();
    await waitFor(() => expect(picker().selectedOptions[0]!.text).toBe('Studio · Owner'));

    // Alone in it, with nothing in it: "Delete group".
    expect(screen.queryByRole('button', { name: 'Leave group' })).toBeNull();
    fireEvent.click(await screen.findByRole('button', { name: 'Delete group' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Delete “Studio”?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Delete' }));
    expect(await screen.findByText('The group “Studio” was deleted.')).toBeTruthy();
    await waitFor(() => expect(picker().value).toBe(HOME));
    expect(server.world.memberships).toEqual([HOME, OFFICE]);
  });
});

describe('joining with a code', () => {
  it("checks a code from an invite's link at once, and joins: the group opens on Home", async () => {
    const { server, router } = renderApp(`/join#${FRIENDS_CODE}`);
    expect(await screen.findByText('Ivan invites you to “Friends” as a helper.')).toBeTruthy();
    expect(screen.getByLabelText('Invite code')).toHaveProperty('value', FRIENDS_CODE);
    expect(server.calls('POST', '/api/v1/invites/preview')[0]!.body).toEqual({ code: 'FRND2345' });
    fireEvent.click(screen.getByRole('button', { name: 'Join' }));
    expect(await screen.findByText('You joined “Friends”.')).toBeTruthy();
    await waitFor(() => expect(router.state.location.pathname).toBe('/'));
    await waitFor(() => expect(picker().value).toBe(FRIENDS));
    await waitFor(() => expect(server.calls('GET', '/api/v1/today').at(-1)!.household).toBe(FRIENDS));
  });

  it('a typed code is checked once all eight are in; a wrong one and impossible letters are said', async () => {
    const { server } = renderApp('/join');
    await opened();
    const field = await screen.findByLabelText('Invite code');
    fireEvent.change(field, { target: { value: 'abcd' } });
    expect(field).toHaveProperty('value', 'ABCD');
    fireEvent.change(field, { target: { value: 'ABCD23' } });
    expect(field).toHaveProperty('value', 'ABCD-23');
    expect(server.calls('POST', '/api/v1/invites/preview')).toHaveLength(0);
    fireEvent.change(field, { target: { value: 'ABCD-2345' } });
    expect(await screen.findByText("This code doesn't work: check it or ask for a new one.")).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Join' })).toHaveProperty('disabled', true);

    // Codes have no O, 0, I or 1: said at once, without one of the few tries.
    const asked = server.calls('POST', '/api/v1/invites/preview').length;
    fireEvent.change(field, { target: { value: 'OOPS-1234' } });
    expect(
      await screen.findByText('Codes have no letters O and I and no digits 0 and 1: check the code.'),
    ).toBeTruthy();
    expect(server.calls('POST', '/api/v1/invites/preview')).toHaveLength(asked);
    // A whole message pasted: its code.
    fireEvent.change(field, {
      target: { value: `Join “Friends” in Collarbell: code ${FRIENDS_CODE}, valid for 7 days.` },
    });
    expect(field).toHaveProperty('value', FRIENDS_CODE);
    expect(await screen.findByText(/^Ivan invites you to “Friends”/)).toBeTruthy();
  });

  it("says when the person is in that group already, and there's nothing to join", async () => {
    const server = createTestServer();
    server.world.households.get(OFFICE)!.invites.push(invite('invite-office', 'WRKS-2345', 'Member', 'user-olga'));
    renderApp('/join#WRKS-2345', { server });
    expect(await screen.findByText("You're already in this group.")).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Join' })).toHaveProperty('disabled', true);
  });
});

describe("groups after part 3's review", () => {
  it('leaving a group on Settings keeps the page: a name typed in the profile stays', async () => {
    inOffice();
    renderApp('/settings');
    fireEvent.change((await region('Profile')).getByLabelText('Your name'), { target: { value: 'Anna K.' } });
    fireEvent.click(await screen.findByRole('button', { name: 'Leave group' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Leave “Office”?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Leave' }));
    expect(await screen.findByText('You left “Office”.')).toBeTruthy();
    await waitFor(() => expect(within(screen.getByRole('banner')).getByText('My home')).toBeTruthy());
    expect((await region('Profile')).getByLabelText('Your name')).toHaveProperty('value', 'Anna K.');
  });

  it('leaving a group on Settings while "Download my data" runs: the download goes on', async () => {
    inOffice();
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
    renderApp('/settings', { server });
    const data = await region('Your data');
    fireEvent.click(data.getByRole('button', { name: 'Download my data' }));
    await waitFor(() => expect(send).toBeTypeOf('function'));
    await act(async () => send(new Uint8Array(2048)));
    expect(await data.findByText('Downloaded: 2 KB')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Leave group' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'Leave “Office”?' }));
    fireEvent.click(dialog.getByRole('button', { name: 'Leave' }));
    expect(await screen.findByText('You left “Office”.')).toBeTruthy();
    await waitFor(() => expect(within(screen.getByRole('banner')).getByText('My home')).toBeTruthy());
    expect((await region('Your data')).queryByText('Downloaded: 2 KB')).toBeTruthy();
  });

  it('"Create a group" says the new group opened only once it is on screen', async () => {
    renderApp('/settings');
    fireEvent.change((await region('Profile')).getByLabelText('Your name'), { target: { value: 'Anya' } });
    fireEvent.click(await (await region('Your groups')).findByRole('button', { name: 'Create a group' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'New group' }));
    fireEvent.change(dialog.getByLabelText('Name'), { target: { value: 'Studio' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Create' }));
    // The typed name holds the move back; staying keeps the group on screen, and nothing claims the switch.
    const asking = within(await screen.findByRole('dialog', { name: 'Leave without saving?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(picker().value).toBe(HOME);
    expect(screen.queryByText("You're in “Studio” now.")).toBeNull();
  });

  it('"Create a group" with nothing typed opens it and says so', async () => {
    renderApp('/settings');
    fireEvent.click(await (await region('Your groups')).findByRole('button', { name: 'Create a group' }));
    const dialog = within(await screen.findByRole('dialog', { name: 'New group' }));
    fireEvent.change(dialog.getByLabelText('Name'), { target: { value: 'Studio' } });
    fireEvent.click(dialog.getByRole('button', { name: 'Create' }));
    expect(await screen.findByText("You're in “Studio” now.")).toBeTruthy();
    expect(picker().selectedOptions[0]!.textContent).toMatch(/^Studio/);
  });

  it('deleting the only group says it was deleted, not "You\'re no longer in it"', async () => {
    const server = createTestServer();
    server.world.memberships = [HOME];
    const home = server.world.households.get(HOME)!;
    home.others = [];
    home.pets = [];
    home.supplies = [];
    home.stock = [];
    renderApp('/settings', { server });
    fireEvent.click(await screen.findByRole('button', { name: 'Delete group' }));
    const asking = within(await screen.findByRole('dialog', { name: 'Delete “My home”?' }));
    fireEvent.click(asking.getByRole('button', { name: 'Delete' }));
    // The server makes her a new home, which is on screen.
    await waitFor(() => expect(server.world.memberships[0]).not.toBe(HOME));
    await waitFor(() =>
      expect(server.calls('GET', '/api/v1/households/current').at(-1)!.household).toBe(server.world.memberships[0]),
    );
    expect(await screen.findByText('The group “My home” was deleted.')).toBeTruthy();
    expect(screen.queryByText("You're no longer in “My home”.")).toBeNull();
  });

  it('joining from a link while signed out signs in first, and the code never goes in an address', async () => {
    const { server } = renderApp(`/join#${FRIENDS_CODE}`, { user: null });
    fireEvent.change(await screen.findByLabelText('Email'), { target: { value: ANNA } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'secret' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByText('Ivan invites you to “Friends” as a helper.')).toBeTruthy();
    for (const request of server.requests) {
      expect(request.path).not.toMatch(/FRND/i);
      expect(request.query.toString()).not.toMatch(/FRND/i);
    }
  });
});
