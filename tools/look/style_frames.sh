#!/usr/bin/env sh
# UPDATE 12 section 1 (T-207): the style frames. Renders the u12_look camera set (data/gravelight/capture_cams.json:
# one establishing frame per map plus the menu) twice, off-screen and silent: once with every grade off
# (--look=off, the "before") and once with data/look/<map>.json applied (the "after"), then files the pair as
# docs/look/frames/<name>_before|after.png (JPEG past 400 KB) and the side-by-side sheet.jpg.
# One GPU run at a time across the workers (U12 contract C3): the .claude/gpu.lock mkdir lock.
# Usage: tools/look/style_frames.sh [frames_dir] [only=map00_crossroads,menu] [before|after|both]
cd "$(dirname "$0")/../.."
. tools/env.sh   # GODOT / GODOT_W / PYTHON per OS
FRAMES="${1:-docs/look/frames}"
case "$FRAMES" in /*|[A-Za-z]:*) ;; *) FRAMES="$(pwd)/$FRAMES" ;; esac   # capture.gd saves where --out says, absolute
ONLY=""
[ -n "$2" ] && ONLY="--only=$2"
WHICH="${3:-both}"
L="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/../.claude/gpu.lock"
[ -d "$(dirname "$L")" ] || L=".claude/gpu.lock"
until mkdir "$L" 2>/dev/null; do sleep 20; done
echo "$$ $(date +%T) u12-1-bible style_frames" > "$L/owner"
trap 'rm -rf "$L"' EXIT INT TERM
mkdir -p "$FRAMES"
if [ "$WHICH" = "both" ] || [ "$WHICH" = "before" ]; then
	rm -rf "$FRAMES/_before"
	timeout 900 "$GODOT" --audio-driver Dummy --windowed --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/capture.tscn -- \
		--set=u12_look --out="$FRAMES/_before" --look=off $ONLY
fi
if [ "$WHICH" = "both" ] || [ "$WHICH" = "after" ]; then
	rm -rf "$FRAMES/_after"
	timeout 900 "$GODOT" --audio-driver Dummy --windowed --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/capture.tscn -- \
		--set=u12_look --out="$FRAMES/_after" $ONLY
fi
rm -rf "$L"
trap - EXIT INT TERM
"$PYTHON" -I tools/look/style_frames.py "$FRAMES"
