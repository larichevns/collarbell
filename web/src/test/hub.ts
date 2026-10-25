// A pretend hub for the tests: every connection the app opens is a TestConnection the test drives. It opens (the
// server answered Ready), is refused, fails, drops, and hears changes when the test says so.
import { RealtimeRefused, type LiveChange, type RealtimeClient } from '../live/realtime';

export class TestConnection implements RealtimeClient {
  onChange: ((change: LiveChange) => void) | null = null;
  onClose: (() => void) | null = null;
  connected = false;
  closed = false;
  url: string | null = null;
  ticket: string | null = null;
  private settle: { resolve: () => void; reject: (error: unknown) => void } | null = null;

  connect(url: string, ticket: string): Promise<void> {
    this.url = url;
    this.ticket = ticket;
    return new Promise<void>((resolve, reject) => {
      this.settle = { resolve, reject };
    });
  }

  /** The server answered Ready: what changes from now on is heard. */
  open(): void {
    this.connected = true;
    this.settle?.resolve();
  }

  /** The server closed it for good: not a member, or too many connections. */
  refuse(reason = "You aren't in this household."): void {
    this.settle?.reject(new RealtimeRefused(reason));
  }

  /** It couldn't be opened: no network, a ticket the server didn't take. */
  fail(): void {
    this.settle?.reject(new Error('WebSocket failed to connect.'));
  }

  /** The open connection dropped (the network, a restart of the server). */
  drop(): void {
    this.connected = false;
    this.onClose?.();
  }

  /** The server says something changed. */
  hear(topics: string[], origin: string | null = null): void {
    this.onChange?.({ topics, origin });
  }

  async close(): Promise<void> {
    this.closed = true;
    this.connected = false;
  }
}

/** A factory whose connections are kept in order, the newest last. */
export function testHub() {
  const connections: TestConnection[] = [];
  return {
    connections,
    factory: () => {
      const connection = new TestConnection();
      connections.push(connection);
      return connection;
    },
    /** The newest connection. */
    get last(): TestConnection | undefined {
      return connections.at(-1);
    },
  };
}
