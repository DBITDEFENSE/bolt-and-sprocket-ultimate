#!/usr/bin/env sh
# T-222: the Fernflug lighting pass's frames. Renders capture sets off-screen and silent (U12 contract C3: the
# .claude/gpu.lock mkdir lock, --position -4000,-4000, --audio-driver Dummy, one run at a time) into
# <out>/<set>/*.png at 1600x900.
# Usage: tools/look/light_frames.sh <out_dir> <set>[,<set>...] [only=cam,cam]
cd "$(dirname "$0")/../.." || exit 2
. tools/env.sh
OUT="$1"
case "$OUT" in /*|[A-Za-z]:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
SETS="$2"
ONLY=""
case "${3:-}" in only=*) ONLY="--only=${3#only=}" ;; esac
L="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/../.claude/gpu.lock"
[ -d "$(dirname "$L")" ] || L=".claude/gpu.lock"
until mkdir "$L" 2>/dev/null; do sleep 20; done
echo "$$ $(date +%T) t222-fernflug-lighting light_frames" > "$L/owner"
trap 'rm -rf "$L"' EXIT INT TERM
for s in $(echo "$SETS" | tr ',' ' '); do
	mkdir -p "$OUT/$s"
	timeout 900 "$GODOT" --audio-driver Dummy --windowed --position -4000,-4000 --resolution 1600x900 --path . \
		res://tools_src/capture.tscn -- --set="$s" --out="$OUT/$s" $ONLY > "$OUT/$s.log" 2>&1
	echo "$s exit $? ($(ls "$OUT/$s" | wc -l) frames)"
done
rm -rf "$L"
trap - EXIT INT TERM
