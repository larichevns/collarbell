// The live connection over the real @microsoft/signalr client (signalr.ts), against a pretend WebSocket that speaks the
// hub's protocol as the server does: the address (/hubs/household with the household and the one-time ticket as
// access_token, no negotiate), "Ready" invoked and answered, Changed heard, the server's refusal told apart, a drop.
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { LogLevel } from '@microsoft/signalr';
import { RealtimeRefused, type LiveChange } from './realtime';
import { createSignalRClient } from './signalr';

const SEPARATOR = '\u001e';

/** The server's end of one socket: what the client sent, and what the test makes the server say. */
class ServerSocket {
  static sockets: ServerSocket[] = [];
  static readonly CONNECTING = 0;
  static readonly OPEN = 1;
  static readonly CLOSING = 2;
  static readonly CLOSED = 3;
  readonly url: string;
  readyState = 0;
  binaryType = 'blob';
  sent: unknown[] = [];
  /** What the server does when the client invokes Ready: answer it (the default), or close with a refusal. */
  onReady: (socket: ServerSocket, invocationId: string) => void = (socket, id) =>
    socket.say({ type: 3, invocationId: id, result: null });
  onopen: ((event: unknown) => void) | null = null;
  onmessage: ((event: { data: string }) => void) | null = null;
  onclose: ((event: { code: number; reason: string; wasClean: boolean }) => void) | null = null;
  onerror: ((event: unknown) => void) | null = null;

  constructor(url: string) {
    this.url = url;
    ServerSocket.sockets.push(this);
    setTimeout(() => {
      this.readyState = 1;
      this.onopen?.({});
    }, 0);
  }

  send(data: string) {
    for (const part of data.split(SEPARATOR).filter(Boolean)) {
      const message = JSON.parse(part) as { protocol?: string; type?: number; target?: string; invocationId?: string };
      this.sent.push(message);
      // The handshake: the server takes JSON.
      if (message.protocol) this.say({});
      else if (message.type === 1 && message.target === 'Ready') this.onReady(this, message.invocationId!);
    }
  }

  /** A message of the server's. */
  say(message: object) {
    setTimeout(() => this.onmessage?.({ data: JSON.stringify(message) + SEPARATOR }), 0);
  }

  close(code = 1000, reason = '') {
    if (this.readyState === 3) return;
    this.readyState = 3;
    this.onclose?.({ code, reason, wasClean: code === 1000 });
  }
}

// In a browser the client puts the access token into the address (a browser's WebSocket can't send headers); under
// Node it would send a header instead. The tests run on Node: for the client, this is a browser.
const node = (globalThis as unknown as { process: object }).process;
let release: PropertyDescriptor | undefined;
beforeEach(() => {
  ServerSocket.sockets = [];
  release = Object.getOwnPropertyDescriptor(node, 'release');
  Object.defineProperty(node, 'release', { value: { name: 'browser' }, configurable: true });
});
afterEach(() => {
  if (release) Object.defineProperty(node, 'release', release);
});

const client = () => createSignalRClient({ WebSocket: ServerSocket as unknown as typeof WebSocket, logLevel: LogLevel.None });
const HUB = 'http://localhost/hubs/household?household=h1';

describe('the SignalR client', () => {
  it('opens the household with the ticket as access_token, no negotiate, and is open once Ready answers', async () => {
    const connection = client();
    await connection.connect(HUB, 'ticket-1');
    const [socket] = ServerSocket.sockets;
    expect(socket!.url).toBe('ws://localhost/hubs/household?household=h1&access_token=ticket-1');
    expect(socket!.sent[0]).toEqual({ protocol: 'json', version: 1 });
    expect(socket!.sent).toContainEqual(expect.objectContaining({ type: 1, target: 'Ready', arguments: [] }));
    expect(connection.connected).toBe(true);
    await connection.close();
    expect(connection.connected).toBe(false);
  });

  it("hears Changed with its topics and origin; what can't be read is a change of anything", async () => {
    const heard: LiveChange[] = [];
    const connection = client();
    connection.onChange = (change) => heard.push(change);
    await connection.connect(HUB, 'ticket-1');
    const [socket] = ServerSocket.sockets;
    socket!.say({ type: 1, target: 'Changed', arguments: [{ topics: ['care', 'pets'], origin: 'tab-1' }] });
    socket!.say({ type: 1, target: 'Changed', arguments: [{ topics: 'care' }] });
    await new Promise((resolve) => setTimeout(resolve, 10));
    expect(heard).toEqual([
      { topics: ['care', 'pets'], origin: 'tab-1' },
      { topics: [], origin: null },
    ]);
    await connection.close();
  });

  it("is refused when the server closes it for good: \"You aren't in this household.\"", async () => {
    const connection = client();
    const opening = connection.connect(HUB, 'ticket-1');
    await new Promise((resolve) => setTimeout(resolve, 0));
    ServerSocket.sockets[0]!.onReady = (socket) =>
      socket.say({
        type: 7,
        error: "Connection closed with an error. HubException: You aren't in this household.",
        allowReconnect: false,
      });
    const failure = await opening.catch((error: unknown) => error);
    expect(failure).toBeInstanceOf(RealtimeRefused);
    expect((failure as RealtimeRefused).reason).toBe("You aren't in this household.");
    expect(connection.connected).toBe(false);
  });

  it('fails (to be tried again) when the socket closes before Ready answers for another reason', async () => {
    const connection = client();
    const opening = connection.connect(HUB, 'ticket-1');
    await new Promise((resolve) => setTimeout(resolve, 0));
    ServerSocket.sockets[0]!.onReady = (socket) => socket.close(1011, 'Server error');
    const failure = await opening.catch((error: unknown) => error);
    expect(failure).toBeInstanceOf(Error);
    expect(failure).not.toBeInstanceOf(RealtimeRefused);
  });

  it('says when the open connection drops, and not when it is closed', async () => {
    let drops = 0;
    const dropping = client();
    dropping.onClose = () => (drops += 1);
    await dropping.connect(HUB, 'ticket-1');
    ServerSocket.sockets[0]!.close(1006, 'Gone');
    expect(drops).toBe(1);
    expect(dropping.connected).toBe(false);

    const closing = client();
    closing.onClose = () => (drops += 1);
    await closing.connect(HUB, 'ticket-2');
    await closing.close();
    expect(drops).toBe(1);
  });

  it('connects once', async () => {
    const connection = client();
    await connection.connect(HUB, 'ticket-1');
    await expect(connection.connect(HUB, 'ticket-2')).rejects.toThrow('connects once');
    await connection.close();
  });
});
