#!/usr/bin/env sh
# T-221 b: der Kranich's casing drop as a slow-motion trailer clip. Runs the capture set trailer_kranich_clip (the
# camera under the belly, the golden hour held, rack 1's casing released, timescale 0.3) with Godot's movie writer at a
# fixed 30 fps, off-screen and silent under the shared GPU lock (U12 contract C3), then cuts the last seconds (the
# drop) to an MP4 with ffmpeg.
#   tools/look/kranich_drop_clip.sh [out.mp4] [seconds]   -> docs/captures/fernflug/lighting/trailer/kranich_drop_slowmo.mp4
cd "$(dirname "$0")/../.."
. tools/env.sh
OUT="${1:-docs/captures/fernflug/lighting/trailer/kranich_drop_slowmo.mp4}"
SECS="${2:-5.5}"
TMP="$(pwd)/.smoke_logs/clip"
mkdir -p "$TMP" "$(dirname "$OUT")"
L="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/../.claude/gpu.lock"
[ -d "$(dirname "$L")" ] || L=".claude/gpu.lock"
until mkdir "$L" 2>/dev/null; do sleep 20; done
echo "$$ $(date +%T) kranich_drop_clip" > "$L/owner"
trap 'rm -rf "$L"' EXIT INT TERM
rm -f "$TMP/drop.avi"
timeout 900 "$GODOT" --audio-driver Dummy --windowed --position -4000,-4000 --resolution 1600x900 --fixed-fps 30 \
	--write-movie "$TMP/drop.avi" --path . res://tools_src/capture.tscn -- --set=trailer_kranich_clip --out="$TMP/stills"
rm -rf "$L"
trap - EXIT INT TERM
ffmpeg -y -loglevel error -sseof "-$SECS" -i "$TMP/drop.avi" -vf "scale=1600:-2" -c:v libx264 -pix_fmt yuv420p -crf 20 -an "$OUT"
echo "wrote $OUT"
