#!/usr/bin/env sh
# Rebuilds the named people's GLBs in Blender (headless), then writes their .import files from the presets and
# imports them (T-092, docs/CHARACTER_PIPELINE.md section 9).
# Usage: tools/build_people.sh [--only=dutch,peg] [--preview=<dir>] [--faces=<dir>] [--stats=<json>]
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
[ -x "$GODOT" ] || { echo "[people] Godot not found; set GODOT"; exit 1; }
"$BLENDER" -b --factory-startup -P tools_src/blender/characters/build_people.py -- "$@" 2>&1 | grep -E "\[build_people\]|Error|Traceback" || exit 1
rm -f .godot/imported/char_person_*
"$GODOT" --headless --audio-driver Dummy --path . --script res://tools_src/apply_import_presets.gd -- --root=res://assets/ours/characters/people > /dev/null 2>&1
"$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
"$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
echo "[people] import done"
