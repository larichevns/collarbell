// The demo (npm run dev:mock): the app without an account or a server. The tests' pretend server answers from the
// demo's world (world.ts), the tests' pretend sign-in signs in, every answer comes after a short pause so loading
// shows, and files dropped or picked are shown from this computer. A pretend hub connects the live updates (hub.ts),
// and AI "reads" a scan or a note in a few seconds. Nothing leaves the browser tab, and a reload starts the world
// anew. Switches in the address of the first page:
//   ?mockLang=ru        the world in Russian (default: the language picked here, else the browser's)
//   ?mockUser=none      start signed out: any e-mail and password sign in, the password "wrong" doesn't
//   ?mockLatency=0      answer at once (default: 300 ms)
//   ?mockWorld=new      a new account with an empty household: the onboarding opens by itself the first time
//   ?mockWorld=pets     the pets with nothing set up: the first steps on Today and Home
//   ?mockWorld=done     the day done: Home's "All done for today"
import { langOf } from '../i18n/lang';
import type { Services } from '../session';
import { createTestAuth } from '../test/auth';
import { createTestServer } from '../test/server';
import { createDemoHub } from './hub';
import { createDemoWorld, isDemoShape, shapeDemoWorld } from './world';

/** Waits `ms`, or until the request is cancelled. */
function pause(ms: number, signal?: AbortSignal | null): Promise<void> {
  return new Promise((resolve, reject) => {
    if (ms <= 0) return resolve();
    const timer = window.setTimeout(resolve, ms);
    signal?.addEventListener('abort', () => {
      window.clearTimeout(timer);
      reject(new DOMException('Aborted', 'AbortError'));
    });
  });
}

function storedLanguage(): string | null {
  try {
    return window.localStorage.getItem('collarbell.language');
  } catch {
    return null;
  }
}

export function createDemoServices(search: string): Services {
  const params = new URLSearchParams(search);
  const lang = langOf(params.get('mockLang') ?? storedLanguage() ?? window.navigator.language);
  const latency = Number(params.get('mockLatency') ?? 300);
  const world = createDemoWorld(lang);
  const shape = params.get('mockWorld');
  if (isDemoShape(shape)) shapeDemoWorld(world, shape);
  // A file dropped or picked is shown from this computer, as the server would show it once stored.
  const server = createTestServer(world, { fileUrl: (_id, file) => URL.createObjectURL(file) });
  const auth = createTestAuth(params.get('mockUser') === 'none' ? null : world.me.email);
  return {
    auth,
    fetch: async (input, init) => {
      const request = input instanceof Request ? input : new Request(input, init);
      await pause(Number.isFinite(latency) ? latency : 300, request.signal);
      return server.fetch(request);
    },
    live: () => createDemoHub(Number.isFinite(latency) ? latency + 100 : 400),
    demo: true,
  };
}
