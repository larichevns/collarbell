// The demo's live updates (npm run dev:mock): a pretend hub that connects a moment after it is asked, so the sidebar
// says "Live", and hears nothing: in the demo nobody else changes anything. The tickets come from the pretend server.
import type { RealtimeClient } from '../live/realtime';

export function createDemoHub(delay = 400): RealtimeClient {
  let state: 'new' | 'connecting' | 'connected' | 'closed' = 'new';
  return {
    onChange: null,
    onClose: null,
    get connected() {
      return state === 'connected';
    },
    async connect(_url, ticket) {
      if (state !== 'new') throw new Error('A RealtimeClient connects once.');
      if (!ticket) throw new Error('No ticket.');
      state = 'connecting';
      await new Promise((resolve) => setTimeout(resolve, delay));
      if (state !== 'connecting') throw new Error('The connection closed while it opened.');
      state = 'connected';
    },
    async close() {
      state = 'closed';
    },
  };
}
