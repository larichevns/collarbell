// Live updates (system-design 3.4), the phone app's LiveUpdates (app/live_updates.dart) for a browser tab: while a
// person is signed in and a household is on screen, a connection to the server's hub tells the tab what someone else
// in the household changed, and the pages that show it read it again. This class decides when to connect and when
// to read again; the callbacks do the reading (LiveProvider.tsx).
//
// - Connected only while signed in, with a household on screen and the tab in view ([update]). A moment away (another
//   tab, the file picker of another app) keeps the connection: only after 30 seconds hidden does it close, and the
//   tab connects again (and reads again) when it is shown.
// - Every attempt asks for a fresh one-time ticket first (a browser can't send the sign-in token on a WebSocket) and
//   makes a new client. After a failure or a drop it tries again after 1, 2, 5, 10 and 30 seconds, then every 30
//   seconds; a connection that held 30 seconds starts the pauses from the first again. A refusal (the household isn't
//   the person's any more) isn't tried again until another household is on screen or the tab is shown again.
// - Connected again after a time it heard nothing (a failure or a drop, a refusal, the tab hidden for long), the
//   household's pages are read again once the server answers Ready: the server keeps no history, so whatever changed
//   meanwhile would be missed. The first connection for a person and household isn't: the pages have just been read
//   (on opening the app, or for the household just put on screen).
// - Changes this tab made come back with its id as the origin and are skipped; the others are collected for 300 ms and
//   read in one go. A topic the app doesn't know means anything may have changed.
import { RealtimeRefused, type LiveChange, type RealtimeClient, type RealtimeClientFactory } from './realtime';

/**
 * Where live updates stand. off: not wanted (signed out, the tab hidden for long); connecting: the first attempt;
 * reconnecting: waiting to try again after a failure or a drop; live: what others change shows at once; refused: the
 * server said no, until another household is on screen.
 */
export type LiveStatus = 'off' | 'connecting' | 'reconnecting' | 'live' | 'refused';

/** The pauses before the next try after a failure or a drop; the last one repeats. */
export const RETRY_DELAYS_MS = [1_000, 2_000, 5_000, 10_000, 30_000] as const;

/** How long opening a connection may take: a network that answers nothing would wait minutes. */
export const CONNECT_TIMEOUT_MS = 15_000;

/** A connection that held this long counts as good: after it drops, the pauses start again from the first. */
export const STEADY_AFTER_MS = 30_000;

/** The changes heard within this time are read in one go. */
export const COLLECT_MS = 300;

/** How long the connection stays while the tab is hidden. */
export const HIDDEN_GRACE_MS = 30_000;

/** A topic no page knows: anything may have changed. */
export const ANYTHING = '*';

export interface LiveOptions {
  newClient: RealtimeClientFactory;
  /** A fresh one-time ticket into the hub (POST /live/tickets). */
  ticket: () => Promise<string>;
  /** The hub's address for a household: /hubs/household?household=<id>. */
  url: (household: string) => string;
  /** This tab's id: a change that comes back with it is the tab's own. */
  clientId: string;
  /** Someone else changed `topics` in `household`: read again what shows them. */
  onChanged: (household: string, topics: Set<string>) => void;
  /** Connected again after a time nothing was heard, and the server hears `household` for it: read its pages again. */
  onReconnected: (household: string) => void;
  onStatus?: (status: LiveStatus) => void;
}

export interface LiveState {
  /** The person signed in (their uid); null when nobody is. */
  user: string | null;
  /** The household on screen; null until known. */
  household: string | null;
  /** The tab is shown (not in the background, not minimized). */
  visible: boolean;
}

type Timer = ReturnType<typeof setTimeout>;

export class LiveUpdates {
  private readonly options: LiveOptions;
  private user: string | null = null;
  private household: string | null = null;
  private visible = true;
  /** Runs while the tab is hidden: when it fires, the connection closes. */
  private away: Timer | null = null;
  private current: LiveStatus = 'off';
  /** The client of the connection open or opening. */
  private client: RealtimeClient | null = null;
  /** Grows with every attempt and every disconnection: an older attempt's answer comes too late. */
  private run = 0;
  /** The tries that failed in a row: the next pause. */
  private attempt = 0;
  private retry: Timer | null = null;
  private steady: Timer | null = null;
  /** The topics heard and not read yet. */
  private readonly topics = new Set<string>();
  /** Nothing was heard for a while (a failure, a drop, a refusal, the tab hidden for long): read again once connected. */
  private missed = false;
  private collecting: Timer | null = null;
  private disposed = false;

  constructor(options: LiveOptions) {
    this.options = options;
  }

  get status(): LiveStatus {
    return this.current;
  }

  /** Tells it where the tab is now: who is signed in, the household on screen, whether the tab is shown. */
  update({ user, household, visible }: LiveState): void {
    if (this.disposed) return;
    const session = user !== this.user || household !== this.household;
    const hiding = this.visible && !visible;
    const back = !this.visible && visible;
    // Shown again before the connection closed: nothing was missed, nothing to do.
    const stayed = back && this.away !== null;
    this.user = user;
    this.household = household;
    this.visible = visible;
    if (back && this.away !== null) {
      clearTimeout(this.away);
      this.away = null;
    }
    if (session) {
      // Another person or household: a connection of its own. Its pages load afresh anyway: nothing to catch up on.
      this.missed = false;
      this.restart();
    } else if (hiding) {
      // Not yet: the tab may be shown again in a moment.
      this.away = setTimeout(() => this.gone(), HIDDEN_GRACE_MS);
    } else if (back && !stayed) {
      // The connection closed meanwhile: connected again, the pages read again.
      this.restart();
    }
  }

  dispose(): void {
    this.disposed = true;
    if (this.away !== null) clearTimeout(this.away);
    this.away = null;
    this.disconnect();
    this.setStatus('off');
  }

  /** Shown, or hidden for less than HIDDEN_GRACE_MS. */
  private get present(): boolean {
    return this.visible || this.away !== null;
  }

  private get wanted(): boolean {
    return !this.disposed && this.user !== null && this.present;
  }

  private get canConnect(): boolean {
    return this.wanted && this.household !== null;
  }

  private setStatus(status: LiveStatus): void {
    if (status === this.current) return;
    this.current = status;
    this.options.onStatus?.(status);
  }

  /** Hidden for HIDDEN_GRACE_MS: the connection closes. Nothing is heard meanwhile: once shown, the pages read again. */
  private gone(): void {
    this.away = null;
    if (this.current !== 'off') this.missed = true;
    this.restart();
  }

  /** Starts over: closes the connection and opens a new one if wanted. */
  private restart(): void {
    this.disconnect();
    this.attempt = 0;
    if (this.canConnect) void this.connect();
    else this.setStatus(this.wanted ? 'connecting' : 'off');
  }

  private async connect(): Promise<void> {
    const run = ++this.run;
    const household = this.household!;
    this.setStatus(this.attempt === 0 ? 'connecting' : 'reconnecting');
    let ticket: string;
    try {
      // Asked for every attempt: a ticket works once, within a minute.
      ticket = await this.options.ticket();
    } catch {
      if (run === this.run) this.failed();
      return;
    }
    if (run !== this.run) return;
    const client = this.options.newClient();
    this.client = client;
    // Before connecting: a change can come before Ready answers.
    client.onChange = (change) => {
      if (this.client === client) this.heard(change);
    };
    client.onClose = () => {
      if (this.client === client && this.current === 'live') this.failed();
    };
    try {
      await withTimeout(client.connect(this.options.url(household), ticket), CONNECT_TIMEOUT_MS);
    } catch (error) {
      if (this.client !== client) return;
      if (error instanceof RealtimeRefused) this.refused();
      else this.failed();
      return;
    }
    if (this.client !== client) return;
    // It closed again before this ran.
    if (!client.connected) {
      this.failed();
      return;
    }
    this.setStatus('live');
    this.steady = setTimeout(() => {
      this.steady = null;
      this.attempt = 0;
    }, STEADY_AFTER_MS);
    // The server keeps no changes: what the pages show may be behind, after a time nothing was heard.
    if (this.missed) {
      this.missed = false;
      this.options.onReconnected(household);
    }
  }

  /** Opening failed or the connection dropped: again after a pause. */
  private failed(): void {
    this.disconnect();
    this.missed = true;
    const delay = RETRY_DELAYS_MS[Math.min(this.attempt, RETRY_DELAYS_MS.length - 1)]!;
    this.attempt += 1;
    this.setStatus('reconnecting');
    this.retry = setTimeout(() => {
      this.retry = null;
      if (this.canConnect) void this.connect();
    }, delay);
  }

  /** The server refused: no more tries until another household is on screen or the tab is shown again. */
  private refused(): void {
    this.disconnect();
    this.missed = true;
    this.setStatus('refused');
  }

  /** Closes the connection, calls off a try that waits, and forgets what was heard and not read. */
  private disconnect(): void {
    this.run += 1;
    for (const timer of [this.retry, this.steady, this.collecting]) if (timer !== null) clearTimeout(timer);
    this.retry = null;
    this.steady = null;
    this.collecting = null;
    this.topics.clear();
    const client = this.client;
    this.client = null;
    if (client) {
      client.onChange = null;
      client.onClose = null;
      void client.close().catch(() => undefined);
    }
  }

  private heard(change: LiveChange): void {
    // The tab made it: its pages show it already.
    if (change.origin === this.options.clientId) return;
    // A change that couldn't be read: anything may have changed.
    for (const topic of change.topics.length ? change.topics : [ANYTHING]) this.topics.add(topic);
    this.collecting ??= setTimeout(() => this.readHeard(), COLLECT_MS);
  }

  private readHeard(): void {
    this.collecting = null;
    const topics = new Set(this.topics);
    this.topics.clear();
    if (topics.size && !this.disposed && this.household !== null) this.options.onChanged(this.household, topics);
  }
}

/** The promise, or a failure after `ms`. */
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('The connection took too long to open.')), ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error: unknown) => {
        clearTimeout(timer);
        reject(error instanceof Error ? error : new Error(String(error)));
      },
    );
  });
}

export type { LiveChange };
