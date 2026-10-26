#!/usr/bin/env sh
# Lighting shots from fixed viewpoints (tools_src/light_shots.gd) in an off-screen, silent window.
# Usage: tools/light_shots.sh <tag> [map00,map01,map02] [preset]  -> morning/screenshots/lighting/<tag>/*.png
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
T="${1:-now}"
M="${2:-map00,map01,map02}"
P=""
[ -n "$3" ] && P="--preset=$3"
timeout 900 "$GODOT" --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/light_shots.tscn -- --tag="$T" --maps="$M" $P
