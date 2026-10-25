// When the tab connects to the live updates, and what it reads again (live.ts): a fresh ticket for every attempt, the
// household's address, "Ready" (the household read again only after a time nothing was heard: a failure, a drop, a
// refusal, the tab hidden for long; not on the first connection, when the pages have just been read), the topics
// heard (the tab's own changes skipped), the pauses before trying again, the hidden tab, another household, a refusal.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { testHub } from '../test/hub';
import { LiveUpdates, RETRY_DELAYS_MS, type LiveOptions, type LiveStatus } from './live';

const ME = 'tab-1';

function setUp(change: Partial<LiveOptions> = {}) {
  const hub = testHub();
  let tickets = 0;
  const ticket = vi.fn(async () => `ticket-${(tickets += 1)}`);
  const onChanged = vi.fn<(household: string, topics: Set<string>) => void>();
  const onReconnected = vi.fn<(household: string) => void>();
  const statuses: LiveStatus[] = [];
  const live = new LiveUpdates({
    newClient: hub.factory,
    ticket,
    url: (household) => `https://app.example/hubs/household?household=${household}`,
    clientId: ME,
    onChanged,
    onReconnected,
    onStatus: (status) => statuses.push(status),
    ...change,
  });
  return { hub, ticket, onChanged, onReconnected, statuses, live };
}

/** Lets the ticket's promise and the connection's settle. */
const settle = () => vi.advanceTimersByTimeAsync(0);

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('live updates', () => {
  it('asks for a ticket and connects to the household on screen with it; its pages, just read, are not read again', async () => {
    const { hub, ticket, onReconnected, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    expect(live.status).toBe('connecting');
    await settle();
    expect(ticket).toHaveBeenCalledTimes(1);
    expect(hub.last!.url).toBe('https://app.example/hubs/household?household=h1');
    expect(hub.last!.ticket).toBe('ticket-1');
    hub.last!.open();
    await settle();
    expect(live.status).toBe('live');
    expect(onReconnected).not.toHaveBeenCalled();
  });

  it('a first try that failed: once connected, the household is read again (nothing was heard meanwhile)', async () => {
    const { hub, onReconnected, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.fail();
    await vi.advanceTimersByTimeAsync(1000);
    // Not before the server answered Ready: a change made before it joined would be missed.
    expect(onReconnected).not.toHaveBeenCalled();
    hub.last!.open();
    await settle();
    expect(onReconnected).toHaveBeenCalledExactlyOnceWith('h1');
  });

  it('reads again what the topics heard show, collected for 300 ms; an unreadable change means anything', async () => {
    const { hub, onChanged, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.open();
    await settle();
    hub.last!.hear(['care']);
    hub.last!.hear(['pets', 'care']);
    await vi.advanceTimersByTimeAsync(299);
    expect(onChanged).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(onChanged).toHaveBeenCalledTimes(1);
    expect(onChanged.mock.calls[0]![0]).toBe('h1');
    expect([...onChanged.mock.calls[0]![1]].sort()).toEqual(['care', 'pets']);
    hub.last!.hear([]);
    await vi.advanceTimersByTimeAsync(300);
    expect([...onChanged.mock.calls[1]![1]]).toEqual(['*']);
  });

  it("skips the tab's own changes: they come back with its id as the origin", async () => {
    const { hub, onChanged, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.open();
    await settle();
    hub.last!.hear(['supplies'], ME);
    await vi.advanceTimersByTimeAsync(1000);
    expect(onChanged).not.toHaveBeenCalled();
    // Another phone of the same person: its change is read.
    hub.last!.hear(['supplies'], 'phone-2');
    await vi.advanceTimersByTimeAsync(300);
    expect([...onChanged.mock.calls[0]![1]]).toEqual(['supplies']);
  });

  it('tries again after 1, 2, 5, 10 and 30 seconds, then every 30, each time with a fresh ticket', async () => {
    const { hub, ticket, live, statuses } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    const waits: number[] = [];
    for (let attempt = 0; attempt < 6; attempt += 1) {
      const tries = hub.connections.length;
      hub.last!.fail();
      await settle();
      expect(live.status).toBe('reconnecting');
      // Measured: nothing before the pause is over, a new connection right after.
      let waited = 0;
      while (hub.connections.length === tries) {
        await vi.advanceTimersByTimeAsync(500);
        waited += 500;
      }
      waits.push(waited);
    }
    expect(waits).toEqual([1000, 2000, 5000, 10_000, 30_000, 30_000]);
    expect(RETRY_DELAYS_MS).toEqual([1000, 2000, 5000, 10_000, 30_000]);
    expect(ticket).toHaveBeenCalledTimes(7);
    expect(new Set(hub.connections.map((connection) => connection.ticket)).size).toBe(7);
    expect(statuses).toContain('reconnecting');
  });

  it('a drop: closed, tried again after a second with a new ticket, and the household read again', async () => {
    const { hub, onReconnected, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.open();
    await settle();
    const first = hub.last!;
    first.drop();
    expect(live.status).toBe('reconnecting');
    await vi.advanceTimersByTimeAsync(1000);
    expect(hub.connections).toHaveLength(2);
    expect(hub.last!.ticket).toBe('ticket-2');
    hub.last!.open();
    await settle();
    expect(live.status).toBe('live');
    expect(onReconnected).toHaveBeenCalledExactlyOnceWith('h1');
  });

  it('a connection that held 30 seconds starts the pauses from the first again', async () => {
    const { hub, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.fail();
    await vi.advanceTimersByTimeAsync(1000);
    hub.last!.fail();
    await vi.advanceTimersByTimeAsync(2000);
    hub.last!.open();
    await settle();
    await vi.advanceTimersByTimeAsync(30_000);
    hub.last!.drop();
    // A second again, not the 5 that would come next.
    await vi.advanceTimersByTimeAsync(1000);
    expect(hub.connections).toHaveLength(4);
  });

  it('a hidden tab keeps the connection for 30 seconds, then closes it; shown again, it connects and reads again', async () => {
    const { hub, onReconnected, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.open();
    await settle();
    // Back within the half minute: the same connection, nothing read again.
    live.update({ user: 'u1', household: 'h1', visible: false });
    await vi.advanceTimersByTimeAsync(20_000);
    live.update({ user: 'u1', household: 'h1', visible: true });
    expect(hub.connections).toHaveLength(1);
    expect(hub.last!.closed).toBe(false);
    // Away for longer: closed.
    live.update({ user: 'u1', household: 'h1', visible: false });
    await vi.advanceTimersByTimeAsync(30_000);
    expect(hub.last!.closed).toBe(true);
    expect(live.status).toBe('off');
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    expect(hub.connections).toHaveLength(2);
    expect(onReconnected).not.toHaveBeenCalled();
    hub.last!.open();
    await settle();
    expect(onReconnected).toHaveBeenCalledExactlyOnceWith('h1');
  });

  it('another household on screen: the connection closes and one for the new household opens', async () => {
    const { hub, onReconnected, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.fail();
    live.update({ user: 'u1', household: 'h2', visible: true });
    expect(hub.connections[0]!.closed).toBe(true);
    await settle();
    expect(hub.last!.url).toBe('https://app.example/hubs/household?household=h2');
    expect(hub.last!.ticket).toBe('ticket-2');
    // Its pages load afresh when it is put on screen: nothing to catch up on, even after h1's failure.
    hub.last!.open();
    await settle();
    expect(onReconnected).not.toHaveBeenCalled();
  });

  it('a refusal waits for another household: no more tries until then', async () => {
    const { hub, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.refuse();
    await settle();
    expect(live.status).toBe('refused');
    await vi.advanceTimersByTimeAsync(120_000);
    expect(hub.connections).toHaveLength(1);
    live.update({ user: 'u1', household: 'h2', visible: true });
    await settle();
    expect(hub.connections).toHaveLength(2);
    expect(hub.last!.url).toContain('household=h2');
  });

  it("a ticket that can't be had is tried again like a failed connection", async () => {
    let calls = 0;
    const { hub, live } = setUp({
      ticket: async () => {
        calls += 1;
        if (calls === 1) throw new Error('No answer');
        return 'ticket-ok';
      },
    });
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    expect(hub.connections).toHaveLength(0);
    expect(live.status).toBe('reconnecting');
    await vi.advanceTimersByTimeAsync(1000);
    expect(hub.last!.ticket).toBe('ticket-ok');
  });

  it('a connection that takes over 15 seconds to open is given up and tried again', async () => {
    const { hub, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    await vi.advanceTimersByTimeAsync(15_000);
    expect(hub.connections[0]!.closed).toBe(true);
    await vi.advanceTimersByTimeAsync(1000);
    expect(hub.connections).toHaveLength(2);
  });

  it('signed out (or disposed): the connection closes and nothing connects', async () => {
    const { hub, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.open();
    await settle();
    live.update({ user: null, household: 'h1', visible: true });
    expect(hub.last!.closed).toBe(true);
    expect(live.status).toBe('off');
    await vi.advanceTimersByTimeAsync(60_000);
    expect(hub.connections).toHaveLength(1);
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    live.dispose();
    expect(hub.last!.closed).toBe(true);
    expect(live.status).toBe('off');
  });

  it('a change heard by a connection closed since is not read', async () => {
    const { hub, onChanged, live } = setUp();
    live.update({ user: 'u1', household: 'h1', visible: true });
    await settle();
    hub.last!.open();
    await settle();
    const old = hub.last!;
    old.hear(['care']);
    live.update({ user: 'u1', household: 'h2', visible: true });
    old.hear(['pets']);
    await vi.advanceTimersByTimeAsync(1000);
    expect(onChanged).not.toHaveBeenCalled();
  });
});
