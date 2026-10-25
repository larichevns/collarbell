#!/usr/bin/env python3
"""Local bridge between this Mac and the "Collarbell Bridge" Figma plugin.

  python3 bridge.py serve [--refs DIR] [--shots DIR]
      Runs the server on localhost:8765 (refs default to .refs, shots to .shots). The plugin, while open in Figma,
      asks it for jobs every second, runs them and sends back the result.
  python3 bridge.py run job.js [more.js ...]
      Sends lib.js + the given files as one job and prints the result.

A job is plugin JavaScript, like a `use_figma` call: it ends with `return`,
and `bridge.shot(node, name)` saves a PNG of a node into the shots folder.
"""
import json
import os
import socket
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8765
HERE = os.path.dirname(os.path.abspath(__file__))

jobs, results, state = [], {}, {"last_poll": 0.0, "next_id": 1}
changed = threading.Condition()
folders = {"refs": os.path.join(HERE, ".refs"), "shots": os.path.join(HERE, ".shots")}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, body=b"", kind="application/json"):
        self.send_response(code)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, value, code=200):
        self._send(code, json.dumps(value, ensure_ascii=False).encode())

    def _body(self):
        return self.rfile.read(int(self.headers.get("Content-Length", 0)))

    def do_OPTIONS(self):
        self._send(204)

    def do_GET(self):
        path, _, query = self.path.partition("?")
        if path == "/job":
            with changed:
                state["last_poll"] = time.time()
                job = jobs.pop(0) if jobs else None
            return self._json(job) if job else self._send(204)
        if path == "/status":
            return self._json({"queued": len(jobs),
                               "since_poll": time.time() - state["last_poll"]})
        if path.startswith("/ref/"):
            name = os.path.basename(urllib.parse.unquote(path[5:]))
            file = os.path.join(folders["refs"], name)
            if not os.path.isfile(file):
                return self._send(404)
            with open(file, "rb") as f:
                return self._send(200, f.read(), "image/png")
        if path.startswith("/wait/"):
            job_id = path[6:]
            timeout = float(query.split("=")[1]) if query.startswith("timeout=") else 600
            deadline = time.time() + timeout
            with changed:
                while job_id not in results and time.time() < deadline:
                    changed.wait(1)
                result = results.pop(job_id, None)
            return self._json(result) if result else self._send(408)
        self._send(404)

    def do_POST(self):
        path = self.path
        if path == "/enqueue":
            with changed:
                job_id = str(state["next_id"])
                state["next_id"] += 1
                jobs.append({"id": job_id, "code": self._body().decode()})
                changed.notify_all()
            return self._json({"id": job_id})
        if path.startswith("/result/"):
            with changed:
                results[path[8:]] = json.loads(self._body() or b"null")
                changed.notify_all()
            return self._send(204)
        if path.startswith("/shot/"):
            name = os.path.basename(urllib.parse.unquote(path[6:]))
            os.makedirs(folders["shots"], exist_ok=True)
            with open(os.path.join(folders["shots"], name), "wb") as f:
                f.write(self._body())
            return self._send(204)
        self._send(404)


class Server6(ThreadingHTTPServer):
    address_family = socket.AF_INET6


def serve(args):
    for flag in ("--refs", "--shots"):
        if flag in args:
            folders[flag[2:]] = os.path.abspath(args[args.index(flag) + 1])
    # localhost may mean either address in the plugin's browser: listen on both,
    # and only on this Mac.
    # Another bridge may still hold the port (e.g. one about to stop): wait
    # for it, so this one takes over without anyone restarting the plugin.
    waiting = False
    while True:
        try:
            servers = [ThreadingHTTPServer(("127.0.0.1", PORT), Handler)]
            break
        except OSError:
            if not waiting:
                print(f"port {PORT} is busy (another bridge?), waiting for it…", flush=True)
                waiting = True
            time.sleep(2)
    try:
        servers.append(Server6(("::1", PORT), Handler))
    except OSError:
        pass
    for server in servers[1:]:
        threading.Thread(target=server.serve_forever, daemon=True).start()
    print(f"bridge on localhost:{PORT}, refs {folders['refs']}, shots {folders['shots']}",
          flush=True)
    servers[0].serve_forever()


def call(method, path, body=None, timeout=10):
    request = urllib.request.Request(f"http://127.0.0.1:{PORT}{path}", body, method=method)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.status, response.read()


def run(files):
    _, status = call("GET", "/status")
    since = json.loads(status)["since_poll"]
    if since > 10:
        print(f"WARNING: the plugin hasn't asked for jobs for {since:.0f} s"
              " (is it open in Figma?)", file=sys.stderr)
    code = "\n".join(open(f, encoding="utf-8").read()
                     for f in [os.path.join(HERE, "lib.js"), *files]
                     if os.path.isfile(f))
    _, answer = call("POST", "/enqueue", code.encode())
    job_id = json.loads(answer)["id"]
    try:
        status, body = call("GET", f"/wait/{job_id}?timeout=600", timeout=610)
    except urllib.error.HTTPError as error:
        sys.exit(f"no result in 10 minutes (HTTP {error.code})")
    result = json.loads(body)
    print(json.dumps(result, ensure_ascii=False, indent=1))
    sys.exit(0 if result.get("ok") else 1)


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "serve":
        serve(sys.argv[2:])
    elif command == "run" and len(sys.argv) > 2:
        run(sys.argv[2:])
    else:
        print(__doc__)
