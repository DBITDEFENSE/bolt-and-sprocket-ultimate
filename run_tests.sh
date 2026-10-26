#!/usr/bin/env sh
# Runs the GUT unit tests headless.
# Uses the portable Godot in tools/ (git-ignored) unless GODOT is set.
cd "$(dirname "$0")"
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
if [ ! -d .godot ]; then
  timeout 200 "$GODOT" --headless --editor --quit-after 300 --path . >/dev/null 2>&1
fi
timeout 900 "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
