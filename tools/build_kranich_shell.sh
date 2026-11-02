#!/usr/bin/env sh
# Regenerates der Kranich's inner shell (UPDATE 09 section 5.3, DECISIONS T-147) from its Blender script
# tools_src/blender/world/kranich_shell.py into assets/ours/world/kranich_<room>/model.glb (+ LICENSE.txt and
# SOURCE.txt, "Ours"), then imports them. Headless; nothing is downloaded. Then regenerate the act:
#   "$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/gen_map04b.gd
# Usage: tools/build_kranich_shell.sh [--no-import]
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / BLENDER per OS (tools/local_paths.env overrides)
"$BLENDER" -b -P tools_src/blender/world/kranich_shell.py 2>&1 | grep -E "^\[kranich\]|Error|Traceback|line [0-9]+"
if [ "$1" != "--no-import" ]; then
	"$GODOT" --headless --audio-driver Dummy --path . --script res://tools_src/apply_import_presets.gd -- --root=res://assets/ours/world
	"$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
	echo "[kranich] imported"
fi
