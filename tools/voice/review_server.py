#!/usr/bin/env python3
"""A tiny local server for the voice review page (T-101): http://127.0.0.1:8765/ (this computer only).
Serves voice_review/ and the audio it plays, and saves the page's choices to data/voice/selections.json.
Started by `tools/voice.sh review` (and the dev launcher's "Voice review page" button). Ctrl+C stops it.
"""
from __future__ import annotations

import json
import mimetypes
import os
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voicelib as V  # noqa: E402

ALLOWED = ("voice_review/", "voice_work/takes/", "gravelight/audio/vo/", "gravelight/audio/vo_tts/", "audio/vo/")
mimetypes.add_type("audio/ogg", ".ogg")


def valid_selections(data, ids: set[str]) -> dict:
    if not isinstance(data, dict):
        raise ValueError("selections must be an object")
    out = {}
    for k, v in data.items():
        if k not in ids:
            raise ValueError("unknown line id %s" % k)
        take = v.get("take") if isinstance(v, dict) else v
        if not isinstance(take, str) or not take or len(take) > 200:
            raise ValueError("bad take for %s" % k)
        out[k] = {"take": take, "by": "review", "at": str(v.get("at", V.today()) if isinstance(v, dict) else V.today())[:10]}
    return out


class Handler(BaseHTTPRequestHandler):
    ids: set[str] = set()

    def log_message(self, fmt, *args):  # quiet
        pass

    def _local(self) -> bool:
        host = (self.headers.get("Host") or "").split(":")[0]
        origin = self.headers.get("Origin") or ""
        return host in ("127.0.0.1", "localhost") and (not origin or urlparse(origin).hostname in ("127.0.0.1", "localhost"))

    def do_GET(self):
        if not self._local():
            return self.send_error(403)
        path = unquote(urlparse(self.path).path).lstrip("/")
        if path in ("", "index.html"):
            self.send_response(302)
            self.send_header("Location", "/voice_review/index.html")
            self.end_headers()
            return
        if ".." in path.split("/") or not path.startswith(ALLOWED):
            return self.send_error(404)
        full = os.path.join(V.ROOT, *path.split("/"))
        if not os.path.isfile(full):
            return self.send_error(404)
        with open(full, "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(full)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if not self._local() or urlparse(self.path).path != "/api/selections":
            return self.send_error(403)
        n = int(self.headers.get("Content-Length") or 0)
        try:
            data = valid_selections(json.loads(self.rfile.read(min(n, 5_000_000)).decode("utf-8")), self.ids)
        except Exception as e:  # noqa: BLE001
            body = str(e).encode()
            self.send_response(400)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        V.save_json(V.SELECTIONS_PATH, data)
        self.send_response(204)
        self.end_headers()


def serve(port: int = 8765, open_browser: bool = True) -> int:
    Handler.ids = {ln.file_id for ln in V.collect_all()}
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = "http://127.0.0.1:%d/voice_review/index.html" % port
    print("voice review page:", url, "(Ctrl+C to stop)")
    if open_browser:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(serve(int(sys.argv[1]) if len(sys.argv) > 1 else 8765))
