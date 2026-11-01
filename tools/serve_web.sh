#!/usr/bin/env sh
# UPDATE 09 section 2c (T-139): serve build/web on http://127.0.0.1:8060/ with the right MIME types (no cache).
#   tools/serve_web.sh [--port=8060] [--coop]     (build it first with tools/build_web.sh)
# The browser build uses the single-threaded template, so no COOP/COEP headers are needed (--coop adds them anyway).
# Desktop check of the split build without a browser (headless, the main pack plus the packs from disk):
#   "$GODOT" --headless --audio-driver Dummy --main-pack build/web/cz-main-<hash>.pck -- --packs-from=build/web/packs
cd "$(dirname "$0")/.."
. tools/env.sh
[ -f build/web/index.html ] || { echo "[serve_web] no build/web/index.html: run tools/build_web.sh first"; exit 1; }
exec "$PYTHON" -I tools/serve_web.py build/web "$@"
