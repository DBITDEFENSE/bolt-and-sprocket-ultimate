#!/usr/bin/env bash
# Blender stand-in for cloud sessions where download.blender.org and its mirrors are blocked (UPDATE 07, T-102 (14)):
# the official `bpy` wheel from PyPI (Blender as a Python module, installed in tools/venv by cloud_setup/the session)
# runs the project's headless scripts. Understands the subset the repo uses:
#   blender -b [--factory-startup] -P script.py -- args...      and      blender -b --version
# Written by the UPDATE 07 session; cloud_setup.sh's real download replaces this file when a mirror is reachable.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PY="$ROOT/tools/venv/bin/python"
script=""; args=(); seen_dd=0
while [ $# -gt 0 ]; do
	case "$1" in
		-b|--background|--factory-startup) ;;
		--version) exec "$PY" -c "import bpy; print('Blender ' + bpy.app.version_string + ' (bpy wheel)')" ;;
		-P|--python) script="$2"; shift ;;
		--) seen_dd=1 ;;
		*) if [ $seen_dd = 1 ]; then args+=("$1"); fi ;;
	esac
	shift
done
[ -n "$script" ] || { echo "blender shim: no -P script" >&2; exit 2; }
exec "$PY" - "$script" "${args[@]}" <<'PYEOF'
import sys, runpy, os
script = sys.argv[1]
sys.argv = ["blender", "-b", "-P", script, "--"] + sys.argv[2:]
import bpy  # noqa: F401  (the wheel; loads the glTF add-on with it)
try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
except Exception as e:  # noqa: BLE001
    print("[blender shim] factory settings:", e, file=sys.stderr)
runpy.run_path(script, run_name="__main__")
PYEOF
