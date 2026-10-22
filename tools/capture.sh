#!/usr/bin/env sh
# Morning screenshots: tools_src/capture.gd in an off-screen, silent window.
# Usage: tools/capture.sh [milestone] [only=map00,scrapheap]  -> morning/screenshots/<milestone>/*.png
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe}"
M="${1:-overnight}"
ONLY=""
[ -n "$2" ] && ONLY="--only=$2"
timeout 900 "$GODOT" --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/capture.tscn -- --milestone="$M" $ONLY
