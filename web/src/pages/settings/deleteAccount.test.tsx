// Deleting the account: what happens to each group (handed over to whom, kept, deleted with its pets; helpers left
// alone lose it), what goes and what stays, the data to download first; the tick and the password again (Firebase's
// reauthentication, so the token says it was typed a moment ago), then DELETE /me with the fates shown. The fates
// changed meanwhile (409, or a new picture read before deleting): shown anew, ticked again. The password typed too
// long ago (403): asked for again. A wrong password: said, nothing deleted. A deletion whose answer got lost: the
// server is asked first. Afterwards: signed out, and the sign-in page says the account was deleted.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { keys } from '../../api/keys';
import { renderApp } from '../../test/render';
import { ANNA, createTestServer, HOME, OFFICE, person, problem } from '../../test/server';

const region = async (name: string) => within(await screen.findByRole('region', { name }));
const tick = () => fireEvent.click(screen.getByRole('checkbox', { name: 'I understand what happens to my account and my groups' }));
const password = (value: string) => fireEvent.change(screen.getByLabelText('Password'), { target: { value } });
const remove = () => fireEvent.click(screen.getByRole('button', { name: 'Delete account' }));

describe('deleting the account', () => {
  it('opens from Settings, and shows what happens to each group, what goes and what stays', async () => {
    const { router } = renderApp('/settings');
    fireEvent.click(await (await region('Your data')).findByRole('link', { name: 'Delete account…' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/settings/delete-account'));
    expect(await screen.findByText("Your account will be deleted for good. This can't be undone.")).toBeTruthy();
    const groups = await region('What happens to your groups');
    expect(groups.getByText('My home')).toBeTruthy();
    expect(groups.getByText('Stays with the others; Boris becomes its owner.')).toBeTruthy();
    expect(groups.getByText('Office')).toBeTruthy();
    expect(groups.getByText('Stays with the others as it is.')).toBeTruthy();
    expect((await region('What gets deleted')).getByText('Your sign-in: the e-mail and password.')).toBeTruthy();
    expect((await region('What stays')).getByText(/^Backups keep the data for up to 14 days/)).toBeTruthy();
    expect((await region('Download my data first')).getByRole('button', { name: 'Download my data' })).toBeTruthy();
    // Nothing of hers is deleted with it: no group is named.
    expect(screen.getByText("This can't be undone.")).toBeTruthy();
  });

  it("a group left with helpers only goes with the account, and they lose it: the last question names it", async () => {
    const server = createTestServer();
    server.world.households.get(HOME)!.others = [person('user-kate', 'Kate', 'kate@example.com', 'Helper')];
    renderApp('/settings/delete-account', { server });
    const groups = await region('What happens to your groups');
    expect(
      groups.getByText(
        'Will be deleted with its 3 pets and all their records, photos and documents. Only helpers would be left in it, and they lose access.',
      ),
    ).toBeTruthy();
    expect(screen.getByText("“My home” will be deleted with everything in it. This can't be undone.")).toBeTruthy();
  });

  it('wants the tick and the password: nothing is checked or deleted without them', async () => {
    const { server, auth } = renderApp('/settings/delete-account');
    await region('What happens to your groups');
    remove();
    expect(await screen.findByText('Tick this to delete the account.')).toBeTruthy();
    expect(screen.getByText('Enter your password')).toBeTruthy();
    expect(auth.reauthentications).toEqual([]);
    expect(server.calls('DELETE', '/api/v1/me')).toHaveLength(0);
  });

  it("types the password again, deletes with the fates shown, signs out, and says the account was deleted", async () => {
    const { server, auth } = renderApp('/settings/delete-account');
    await region('What happens to your groups');
    const shown = server.calls('GET', '/api/v1/me/deletion')[0]!;
    // The person's own: it names no household.
    expect(shown.household).toBeNull();
    tick();
    password('secret');
    remove();
    expect(await screen.findByText('Your account has been deleted.')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Sign in' })).toBeTruthy();
    expect(auth.reauthentications).toEqual(['secret']);
    const deleted = server.calls('DELETE', '/api/v1/me')[0]!;
    // A token from after the password was typed, and the fingerprint of the fates she was shown.
    expect(deleted.authorization).toBe(`Bearer token:${ANNA};recent`);
    expect(deleted.query.get('plan')).toMatch(/^plan-/);
    expect(server.world.deleted).toBe(true);
    expect(window.localStorage.getItem(`collarbell.household.uid-${ANNA}`)).toBeNull();
  });

  it('a wrong password: said, the field emptied, nothing deleted', async () => {
    const { server } = renderApp('/settings/delete-account');
    await region('What happens to your groups');
    tick();
    password('wrong');
    remove();
    expect(await screen.findByText('Wrong password. Try again.')).toBeTruthy();
    expect(screen.getByLabelText('Password')).toHaveProperty('value', '');
    expect(server.calls('DELETE', '/api/v1/me')).toHaveLength(0);
  });

  it('the password typed too long ago for the server (403): asked for again, then deleted', async () => {
    const server = createTestServer();
    server.respond(
      'DELETE',
      '/api/v1/me',
      () => problem(403, { type: 'urn:collarbell:problem:recent-sign-in-required' }),
      { once: true },
    );
    renderApp('/settings/delete-account', { server });
    await region('What happens to your groups');
    tick();
    password('secret');
    remove();
    expect(await screen.findByText('For your safety, type your password again.')).toBeTruthy();
    expect(screen.getByLabelText('Password')).toHaveProperty('value', '');
    // No "Enter your password" before the next try.
    expect(screen.queryByText('Enter your password')).toBeNull();
    password('secret');
    remove();
    expect(await screen.findByText('Your account has been deleted.')).toBeTruthy();
  });

  it('the groups changed meanwhile (409): nothing deleted, the new picture shown, ticked again, then deleted', async () => {
    const server = createTestServer();
    renderApp('/settings/delete-account', { server });
    const groups = await region('What happens to your groups');
    expect(groups.getByText('Stays with the others; Boris becomes its owner.')).toBeTruthy();
    // Boris leaves "Home" on his phone: it would go with her account now.
    server.world.households.get(HOME)!.others = [];
    tick();
    password('secret');
    remove();
    expect(
      await screen.findByText('Something changed in your groups. Check again what happens to them, then delete.'),
    ).toBeTruthy();
    expect(await groups.findByText('Will be deleted with its 3 pets and all their records, photos and documents.')).toBeTruthy();
    expect(server.world.deleted).toBe(false);
    expect(screen.getByRole('checkbox', { name: 'I understand what happens to my account and my groups' })).toHaveProperty(
      'checked',
      false,
    );
    tick();
    remove();
    expect(await screen.findByText('Your account has been deleted.')).toBeTruthy();
    expect(server.calls('DELETE', '/api/v1/me')).toHaveLength(2);
  });

  it('a new picture read after ticking (a live update): said at once, the tick goes, and only a new tick deletes', async () => {
    const server = createTestServer();
    const { queryClient } = renderApp('/settings/delete-account', { server });
    const groups = await region('What happens to your groups');
    const shownFirst = server.calls('GET', '/api/v1/me/deletion').length;
    tick();
    password('secret');
    server.world.households.get(HOME)!.others = [];
    await queryClient.invalidateQueries({ queryKey: keys.deletion(`uid-${ANNA}`) });
    expect(await groups.findByText('Will be deleted with its 3 pets and all their records, photos and documents.')).toBeTruthy();
    expect(
      screen.getByText('Something changed in your groups. Check again what happens to them, then delete.'),
    ).toBeTruthy();
    expect(screen.getByRole('checkbox', { name: 'I understand what happens to my account and my groups' })).toHaveProperty(
      'checked',
      false,
    );
    remove();
    expect(await screen.findByText('Tick this to delete the account.')).toBeTruthy();
    expect(server.calls('DELETE', '/api/v1/me')).toHaveLength(0);
    // Ticked for what she sees now: deleted with those fates.
    tick();
    remove();
    expect(await screen.findByText('Your account has been deleted.')).toBeTruthy();
    const read = server.calls('GET', '/api/v1/me/deletion');
    expect(read.length).toBeGreaterThan(shownFirst);
    expect(server.calls('DELETE', '/api/v1/me')).toHaveLength(1);
  });

  it('after one "Something changed", a later change of the fates is not deleted with before it is ticked again', async () => {
    const server = createTestServer();
    const { queryClient } = renderApp('/settings/delete-account', { server });
    const groups = await region('What happens to your groups');
    // The first change: Boris leaves "Home".
    server.world.households.get(HOME)!.others = [];
    tick();
    password('secret');
    remove();
    await screen.findByText('Something changed in your groups. Check again what happens to them, then delete.');
    await groups.findByText('Will be deleted with its 3 pets and all their records, photos and documents.');
    // She agrees to that picture…
    tick();
    // …and "Office" would now go with her account too, heard by a live update (or a reload on coming back).
    server.world.households.get(OFFICE)!.others = [];
    const before = server.calls('GET', '/api/v1/me/deletion').length;
    await queryClient.invalidateQueries({ queryKey: keys.deletion(`uid-${ANNA}`) });
    await waitFor(() => expect(server.calls('GET', '/api/v1/me/deletion').length).toBeGreaterThan(before));
    expect(
      await screen.findByText('Something changed in your groups. Check again what happens to them, then delete.'),
    ).toBeTruthy();
    remove();
    expect(await screen.findByText('Tick this to delete the account.')).toBeTruthy();
    expect(server.world.deleted).toBe(false);
    // Only the first try went out, and the server refused it (409): nothing since.
    expect(server.calls('DELETE', '/api/v1/me')).toHaveLength(1);
  });

  it('"Tick this" is said with the box, which takes the focus; then the password, when it is missing', async () => {
    renderApp('/settings/delete-account');
    await region('What happens to your groups');
    remove();
    const box = screen.getByRole('checkbox', { name: 'I understand what happens to my account and my groups' });
    await waitFor(() => expect(document.activeElement).toBe(box));
    expect(box.getAttribute('aria-invalid')).toBe('true');
    const said = document.getElementById(box.getAttribute('aria-describedby')!)!;
    expect(said.textContent).toBe('Tick this to delete the account.');
    tick();
    remove();
    const field = screen.getByLabelText('Password');
    await waitFor(() => expect(document.activeElement).toBe(field));
    expect(field.getAttribute('aria-invalid')).toBe('true');
  });

  it('a deletion whose answer got lost: the groups are read again, the server says the account is gone, and the browser forgets its household', async () => {
    const server = createTestServer();
    server.respond(
      'DELETE',
      '/api/v1/me',
      () => {
        // Deleted, and the answer lost on the way back.
        server.world.deleted = true;
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp('/settings/delete-account', { server });
    await region('What happens to your groups');
    expect(window.localStorage.getItem(`collarbell.household.uid-${ANNA}`)).not.toBeNull();
    tick();
    password('secret');
    remove();
    expect(await screen.findByText('Your account has been deleted.')).toBeTruthy();
    expect(server.calls('DELETE', '/api/v1/me')).toHaveLength(1);
    // As after a deletion that answered: nobody opens that account's household here again.
    expect(window.localStorage.getItem(`collarbell.household.uid-${ANNA}`)).toBeNull();
  });

  it('a deletion with no answer and the account still there: said so, and the next try asks the server first', async () => {
    const server = createTestServer();
    server.respond(
      'DELETE',
      '/api/v1/me',
      () => {
        throw new TypeError('Failed to fetch');
      },
      { once: true },
    );
    renderApp('/settings/delete-account', { server });
    await region('What happens to your groups');
    tick();
    password('secret');
    remove();
    expect(await screen.findByText("Can't reach the server. Check your connection and try again.")).toBeTruthy();
    const asked = server.calls('GET', '/api/v1/me/deletion').length;
    remove();
    expect(await screen.findByText('Your account has been deleted.')).toBeTruthy();
    expect(server.calls('GET', '/api/v1/me/deletion').length).toBeGreaterThan(asked);
    expect(server.calls('DELETE', '/api/v1/me')).toHaveLength(2);
  });
});
