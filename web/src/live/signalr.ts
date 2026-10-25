// The RealtimeClient over @microsoft/signalr: one connection to the server's HouseholdHub (/hubs/household).
//
// WebSockets only and without the negotiate request, as the server takes them. A browser's WebSocket can't send the
// Authorization header the phone sends, so the app asks for a one-time ticket first (POST /live/tickets, good once
// for a minute) and gives it as the access token: in a browser the client puts it into the address as access_token,
// where the server's LiveTicket sign-in takes it. A sign-in token there would stay in the servers' logs for the hour it
// is valid; a ticket is spent the moment the connection opens.
//
// The client doesn't reconnect by itself (no automatic reconnect is configured): the app does, with a fresh ticket
// each time (live.ts). Its own log says only warnings and errors: what it says at "information" names the address,
// ticket and all.
import { HttpTransportType, HubConnectionBuilder, LogLevel } from '@microsoft/signalr';
import { liveChangeFrom, refusalIn, type RealtimeClient } from './realtime';

/** What the hub calls with a change (the server's IHouseholdClient.Changed). */
export const CHANGED_METHOD = 'Changed';

/** What the app asks once the socket is open (the server's HouseholdHub.Ready). */
export const READY_METHOD = 'Ready';

export interface SignalROptions {
  /** The WebSocket to open the connection with: the browser's, or a pretend one in the tests. */
  WebSocket?: typeof WebSocket;
  /** How much the SignalR client tells the console. */
  logLevel?: LogLevel;
}

export function createSignalRClient(options: SignalROptions = {}): RealtimeClient {
  let state: 'new' | 'connecting' | 'connected' | 'closed' = 'new';
  let closeError: Error | undefined;
  let stop: (() => Promise<void>) | null = null;

  const client: RealtimeClient = {
    onChange: null,
    onClose: null,
    get connected() {
      return state === 'connected';
    },
    async connect(url, ticket) {
      if (state !== 'new') throw new Error('A RealtimeClient connects once.');
      const hub = new HubConnectionBuilder()
        .withUrl(url, {
          transport: HttpTransportType.WebSockets,
          skipNegotiation: true,
          accessTokenFactory: () => ticket,
          ...(options.WebSocket ? { WebSocket: options.WebSocket } : {}),
        })
        .configureLogging(options.logLevel ?? LogLevel.Warning)
        .build();
      stop = () => hub.stop().catch(() => undefined);
      // Also before Ready answers: the connection hears the household from the moment the server adds it.
      hub.on(CHANGED_METHOD, (change: unknown) => client.onChange?.(liveChangeFrom(change)));
      hub.onclose((error) => {
        closeError = error;
        const open = state === 'connected';
        state = 'closed';
        if (open) client.onClose?.();
      });
      state = 'connecting';
      try {
        await hub.start();
        // The server checks the household once the socket is open: Ready answers when this connection hears it. A
        // refusal closes the connection instead, which fails the call with the server's words.
        await hub.invoke(READY_METHOD);
      } catch (error) {
        state = 'closed';
        void stop();
        throw refusalIn(closeError) ?? refusalIn(error) ?? error;
      }
      // Closed meanwhile, by close() or the server.
      if (state !== 'connecting') throw new Error('The connection closed while it opened.');
      state = 'connected';
    },
    async close() {
      state = 'closed';
      await stop?.();
    },
  };
  return client;
}
