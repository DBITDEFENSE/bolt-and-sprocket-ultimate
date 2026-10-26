#!/usr/bin/env sh
# The minimap bake check (Update 04 section 1, DECISIONS T-065): fails when a playable level has no map data, is
# missing a floor image, or has POIs out of date with its scene. Headless, silent. Fix with tools/bake_minimap.sh.
# Usage: tools/check_mapdata.sh [--quick]
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
timeout 600 "$GODOT" --headless --audio-driver Dummy --path . res://tools_src/check_mapdata.tscn -- "$@" 2>&1 | grep "check_mapdata"
