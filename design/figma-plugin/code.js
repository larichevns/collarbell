// Collarbell Bridge: runs jobs from the bridge server on this Mac (bridge.py)
// in the open file. The window (ui.html) does the network part, because the
// plugin's main thread has no network.

figma.showUI(__html__, { width: 300, height: 190, title: 'Collarbell Bridge' });

const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const waiting = new Map();
let nextRequest = 1;

// Asks the window for something and waits for its answer.
function ask(message) {
  const requestId = nextRequest++;
  return new Promise((resolve, reject) => {
    waiting.set(requestId, { resolve, reject });
    figma.ui.postMessage(Object.assign({ requestId }, message));
  });
}

function makeBridge(logs) {
  return {
    log: (...parts) => logs.push(parts.map(String).join(' ')),
    // Saves a PNG of the node into the shots folder on the Mac.
    async shot(node, name, scale) {
      const bytes = await node.exportAsync({
        format: 'PNG',
        constraint: { type: 'SCALE', value: scale || 1 },
      });
      await ask({ type: 'shot', name: name.endsWith('.png') ? name : name + '.png', bytes });
      return bytes.length;
    },
    // A reference screenshot from the Mac, as a Figma image.
    async ref(name) {
      const bytes = await ask({ type: 'ref', name: name.endsWith('.png') ? name : name + '.png' });
      return figma.createImage(bytes);
    },
  };
}

function plain(value) {
  try {
    return value === undefined ? null : JSON.parse(JSON.stringify(value));
  } catch (error) {
    return String(value);
  }
}

async function runJob(id, code) {
  const logs = [];
  const started = Date.now();
  let result;
  let timer;
  try {
    const job = new AsyncFunction('bridge', code);
    const timeout = new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('job took longer than 5 minutes')), 300000);
    });
    const value = await Promise.race([job(makeBridge(logs)), timeout]);
    result = { ok: true, value: plain(value) };
  } catch (error) {
    result = { ok: false, error: String(error), stack: error && error.stack };
  }
  clearTimeout(timer);
  result.logs = logs;
  result.ms = Date.now() - started;
  figma.ui.postMessage({ type: 'result', id, result });
}

figma.ui.onmessage = async (message) => {
  if (message.type === 'job') {
    await runJob(message.id, message.code);
  } else if (message.type === 'answer' || message.type === 'failed') {
    const request = waiting.get(message.requestId);
    if (!request) return;
    waiting.delete(message.requestId);
    if (message.type === 'answer') request.resolve(message.value);
    else request.reject(new Error(message.error));
  }
};
