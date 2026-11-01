#!/usr/bin/env python3
"""Serves the browser build locally (UPDATE 09 section 2c, T-139): python -I tools/serve_web.py [dir] [--port=8060] [--coop]

The right MIME types for .wasm / .pck / .js, no caching (so a rebuild shows at once), and with --coop the
Cross-Origin-Opener-Policy / Cross-Origin-Embedder-Policy headers a threaded Godot web export needs (ours uses the
single-threaded web_nothreads template, so it isn't needed).
"""
import functools
import http.server
import sys

TYPES = {".wasm": "application/wasm", ".pck": "application/octet-stream", ".js": "text/javascript",
         ".html": "text/html", ".json": "application/json", ".png": "image/png"}


class Handler(http.server.SimpleHTTPRequestHandler):
    coop = False
    extensions_map = dict(http.server.SimpleHTTPRequestHandler.extensions_map, **TYPES)

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        if self.coop:
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict((a[2:].split("=", 1) + [""])[:2] for a in sys.argv[1:] if a.startswith("--"))
    root = args[0] if args else "build/web"
    port = int(opts.get("port") or 8060)
    Handler.coop = "coop" in opts
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(Handler, directory=root))
    print("[serve_web] http://127.0.0.1:%d/  (%s%s)  Ctrl+C stops" % (port, root, ", COOP/COEP on" if Handler.coop else ""), flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
