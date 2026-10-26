#!/usr/bin/env sh
# UPDATE 05 section 6 acceptance clip (T-095): 60 s of Map 0 round 8 with 3 bots through the player-bot's eyes,
# rendered off-screen and silent, encoded to mp4 with a 12-frame contact sheet.
# Usage: tools/clip_map00.sh [out_dir] [extra args after --, e.g. --secs=60 --round=8]
# Output: <out_dir>/map00_vfx_r8.mp4, <out_dir>/frames/f_NN.png (one every 5 s), <out_dir>/map00_vfx_contact.png
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
OUT="${1:-morning/clips/u05}"
shift 2>/dev/null
mkdir -p "$OUT/frames"
ABS="$(cd "$OUT" && pwd -W 2>/dev/null || pwd)"
AVI="$ABS/map00_vfx_r8.avi"
rm -f "$AVI"
"$GODOT" --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie "$AVI" --fixed-fps 30 \
	--path . res://gravelight/tools_src/clip_map00.tscn -- "$@" 2>&1 | grep -E "^\[clip\]|RESULT|SCRIPT ERROR" | tee "$OUT/clip_map00.log"
if command -v ffmpeg >/dev/null 2>&1 && [ -f "$AVI" ]; then
	ffmpeg -y -loglevel error -i "$AVI" -vf scale=1280:-2 -c:v libx264 -pix_fmt yuv420p -an "$ABS/map00_vfx_r8.mp4"
	ffmpeg -y -loglevel error -i "$ABS/map00_vfx_r8.mp4" -vf "fps=1/5,scale=640:-2" "$ABS/frames/f_%02d.png"
	ffmpeg -y -loglevel error -i "$ABS/map00_vfx_r8.mp4" -vf "fps=1/5,scale=426:-2,tile=4x3" -frames:v 1 "$ABS/map00_vfx_contact.png"
	rm -f "$AVI"
	echo "clip: $ABS/map00_vfx_r8.mp4"
else
	echo "clip: ffmpeg not found; AVI kept at $AVI"
fi
