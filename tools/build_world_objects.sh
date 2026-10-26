#!/usr/bin/env sh
# Regenerates every world-object model (UPDATE_05 section 5, DECISIONS T-094) from its Blender script in
# tools_src/blender/world/ into assets/ours/world/<object>/model.glb (+ LICENSE.txt and SOURCE.txt, "Ours"), then
# writes their import presets and runs the editor import. Headless; nothing is downloaded.
# Usage: tools/build_world_objects.sh [--no-import]
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.1/blender.exe}"
GODOT="${GODOT:-tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe}"
for s in perk_cabinets requisition_crate ammo_crate barricade_planks door_kit wall_mount story_machines; do
	"$BLENDER" -b -P "tools_src/blender/world/$s.py" 2>&1 | grep -E "^\[world\]|Error|Traceback"
done
if [ "$1" != "--no-import" ]; then
	"$GODOT" --headless --audio-driver Dummy --path . --script res://tools_src/apply_import_presets.gd -- --root=res://assets/ours
	"$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
	echo "[world] imported"
fi
