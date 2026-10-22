#!/usr/bin/env sh
# ADS alignment check (Update 02 §2, T-047): aims every weapon (base + upgraded), prints where each one's rear
# and front sight land relative to the screen center (PASS/FAIL, tolerance in px at 1280x720) and saves
# morning/screenshots/ads/<weapon>.png with a center-dot overlay. Runs off-screen and silent.
# Usage: tools/ads_check.sh [out_dir] [--only=thompson,mp40_up] [--tol=1.5] [--no-shots]
# Exit code: the number of misaligned weapons (0 = every sight on the dot). Run it after any weapon change.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe}"
OUT="$(pwd)/morning/screenshots/ads"
case "${1:-}" in --*|"") ;; *) OUT="$1"; shift ;; esac
exec "$GODOT" --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . \
	res://gravelight/tools_src/ads_check.tscn -- --out="$OUT" "$@"
