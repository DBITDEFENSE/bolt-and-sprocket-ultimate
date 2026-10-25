#!/usr/bin/env sh
# Asset report: tris, materials, texture memory, LODs and bounds for everything under assets/ plus the procedural
# builders -> morning/asset_report.md (and one line per model on stdout). Headless; run the editor import first.
# Usage: tools/asset_report.sh [out.md] [res://assets/third_party]
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe}"
OUT="${1:-res://morning/asset_report.md}"
ROOT="${2:-res://assets}"
"$GODOT" --headless --audio-driver Dummy --path . res://tools_src/asset_report.tscn -- --out="$OUT" --root="$ROOT"
