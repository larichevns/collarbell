// One live connection to the changes of a household (system-design 3.4), as the rest of the app knows it: open it,
// hear what changed, learn that it closed, close it. The phone app's RealtimeClient (data/live/realtime_client.dart).
// signalr.ts is the one over @microsoft/signalr; the tests and the demo have pretend ones.

/**
 * The tab's id, sent as X-Client with every request: a change it made comes back with it as the origin. Letters,
 * digits and hyphens, as the server takes it (LiveChanges.Origin). randomUUID needs a secure page (https, localhost);
 * the random bytes alone do anywhere.
 */
export const TAB_ID: string =
  typeof crypto.randomUUID === 'function'
    ? crypto.randomUUID()
    : Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => byte.toString(16).padStart(2, '0')).join('');

/**
 * The kinds of things a household's screens show, as live updates name them (the server's LiveTopics). The app knows
 * which of its queries show each one (topics.ts); a topic it doesn't know means anything may have changed.
 */
export const LIVE_TOPICS = [
  'pets',
  'passport',
  'care',
  'weight',
  'feeding',
  'visits',
  'supplies',
  'documents',
  'imports',
  'household',
  'plan',
] as const;

export type LiveTopic = (typeof LIVE_TOPICS)[number];

/** Something changed in the household (the server's LiveChange). It carries no data: the pages read it again. */
export interface LiveChange {
  /** What changed. Empty when the message couldn't be read: then anything may have changed. */
  topics: string[];
  /** The X-Client of the request that made it: this tab's id when this tab made it. Null when the server did. */
  origin: string | null;
}

/**
 * The server refused the connection and asks not to try again soon: the household it names isn't the person's (they
 * left, or were removed), or the person has too many connections open.
 */
export class RealtimeRefused extends Error {
  readonly reason: string;

  constructor(reason: string) {
    super(`Live updates refused: ${reason}`);
    this.name = 'RealtimeRefused';
    this.reason = reason;
  }
}

export interface RealtimeClient {
  /**
   * Opens the connection to `url` with the one-time `ticket` as its access token, and resolves once the server hears
   * the household for it (it answered Ready): what changes after that comes to onChange. Rejects with RealtimeRefused
   * when the server refused the connection, with any other error when it failed (no network, the server away, a
   * ticket it didn't take). A client connects once.
   */
  connect(url: string, ticket: string): Promise<void>;
  /** What the server says changed, while the connection is open (also before Ready answers). */
  onChange: ((change: LiveChange) => void) | null;
  /** The open connection closed by itself: the network or the server dropped it. Not after close(). */
  onClose: (() => void) | null;
  /** Open, and the server hears the household for it. */
  readonly connected: boolean;
  /** Closes the connection, also one still opening. Nothing more is heard. */
  close(): Promise<void>;
}

/** Makes the client of each connection: the app makes a new one for every connection, with a fresh ticket. */
export type RealtimeClientFactory = () => RealtimeClient;

/**
 * Why the server closes a connection for good (its HouseholdHub.NotAMember and LiveChanges.TooManyConnections). It
 * also asks the client not to reconnect, which the SignalR client doesn't pass on, so the words tell.
 */
export const REFUSAL_REASONS = ["You aren't in this household.", 'Too many open connections.'] as const;

/**
 * The refusal an error tells of, if any: the SignalR client reports the server's close message as an error with its
 * words ("Server returned an error on close: Connection closed with an error. HubException: …").
 */
export function refusalIn(error: unknown): RealtimeRefused | null {
  if (error === null || error === undefined) return null;
  const text = error instanceof Error ? error.message : String(error);
  const reason = REFUSAL_REASONS.find((each) => text.includes(each));
  return reason ? new RealtimeRefused(reason) : null;
}

/**
 * The change in the hub's Changed call: one argument, {"topics": [...], "origin": "..."}. What can't be read becomes a
 * change without topics, after which the app reads everything again.
 */
export function liveChangeFrom(argument: unknown): LiveChange {
  if (!argument || typeof argument !== 'object') return { topics: [], origin: null };
  const { topics, origin } = argument as { topics?: unknown; origin?: unknown };
  return {
    topics: Array.isArray(topics) ? topics.filter((topic): topic is string => typeof topic === 'string') : [],
    origin: typeof origin === 'string' ? origin : null,
  };
}
