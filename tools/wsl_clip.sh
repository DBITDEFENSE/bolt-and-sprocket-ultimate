#!/usr/bin/env sh
# A walked capture-set clip through WSL + Xvfb (invisible, software GL; T-167, THE_BAR section 6): the tour tool
# gravelight/tools_src/clip_tour.gd writes an AVI (video + the Dummy driver's audio mix) with --write-movie, then
# ffmpeg (in WSL) encodes <name>.mp4 and a 12-frame contact sheet <name>_contact.png beside it.
# Usage: tools/wsl_clip.sh <set[,set]> [secs] [out_dir] [name] [tour args: --map=res://... --bots=2 --round=5]
#   e.g. tools/wsl_clip.sh u09_map02,u10_map02 120 morning/clips/u10_blind map02
#        tools/wsl_clip.sh u10_map01,u09_ref 120 morning/clips/u10_blind map01 --map=res://gravelight/maps/map01_kaltenbrunn/map01.tscn
# Env: CLIP_RES (1280x720), CLIP_FPS (24), CLIP_CRF (23), CLIP_MAX_MB (48: over it the mp4 is re-encoded at CLIP_KBPS, 2800,
#      so a clip stays a plain git file under GitHub's limit), WSL_TIMEOUT (seconds for the Godot run, 5400).
# Windows only (Git Bash); never runs the Windows binary with a window (CLAUDE.md, contract C8).
cd "$(dirname "$0")/.." || exit 2
[ -n "$1" ] || { echo "usage: tools/wsl_clip.sh <set[,set]> [secs] [out_dir] [name] [tour args]" >&2; exit 2; }
SETS="$1"; SECS="${2:-120}"; OUT="${3:-morning/clips/u10_blind}"; NAME="${4:-}"
[ $# -ge 1 ] && shift; [ $# -ge 1 ] && shift; [ $# -ge 1 ] && shift; [ $# -ge 1 ] && shift
[ -n "$NAME" ] || NAME="$(printf '%s' "$SETS" | tr ',' '_')"
RES="${CLIP_RES:-1280x720}"; FPS="${CLIP_FPS:-24}"; CRF="${CLIP_CRF:-23}"
export WSL_TIMEOUT="${WSL_TIMEOUT:-5400}"
mkdir -p "$OUT"
ABS="$(cd "$OUT" && pwd)"
# Git Bash path -> WSL path (as tools/wsl_godot.sh)
WABS="$(printf '%s' "$ABS" | sed -e 's#^/\([A-Za-z]\)/#/mnt/\1/#' -e 's#^\([A-Za-z]\):#/mnt/\1#' -e 's#\\#/#g')"
AVI="$WABS/$NAME.avi"
rm -f "$ABS/$NAME.avi"
start=$(date +%s)
sh tools/wsl_godot.sh --res="$RES" --write-movie "$AVI" --fixed-fps "$FPS" \
	--path . res://gravelight/tools_src/clip_tour.tscn -- --sets="$SETS" --secs="$SECS" "$@" > "$ABS/$NAME.full.log" 2>&1
grep -E "^\[tour\]|RESULT|SCRIPT ERROR" "$ABS/$NAME.full.log" | tee "$ABS/$NAME.log"
echo "clip: the Godot run took $(( $(date +%s) - start )) s"
if [ ! -f "$ABS/$NAME.avi" ]; then
	echo "clip: no AVI was written ($ABS/$NAME.avi)" >&2
	exit 1
fi
SHEET_EVERY="$(awk "BEGIN { v = $SECS / 12.0; if (v < 1) v = 1; printf \"%.3f\", v }")"
ENC="cd '$WABS' && ffprobe -v error -show_entries stream=codec_type,codec_name,sample_rate -of csv=p=0 '$NAME.avi' | sed 's/^/clip: avi stream /' \
 && ffmpeg -y -loglevel error -i '$NAME.avi' -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2' -c:v libx264 -preset medium -crf $CRF -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart '$NAME.mp4' \
 && if [ \$(stat -c %s '$NAME.mp4') -gt $(( ${CLIP_MAX_MB:-48} * 1000000 )) ]; then echo 'clip: over ${CLIP_MAX_MB:-48} MB, re-encoding with a bitrate cap'; ffmpeg -y -loglevel error -i '$NAME.avi' -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2' -c:v libx264 -preset medium -b:v ${CLIP_KBPS:-2800}k -maxrate ${CLIP_KBPS:-2800}k -bufsize 5600k -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart '$NAME.mp4'; fi  && ffmpeg -y -loglevel error -i '$NAME.mp4' -vf 'fps=1/$SHEET_EVERY,scale=426:-2,tile=4x3' -frames:v 1 '${NAME}_contact.png' \
 && ffprobe -v error -show_entries format=duration:stream=codec_type -of csv=p=0 '$NAME.mp4' | sed 's/^/clip: mp4 /' \
 && rm -f '$NAME.avi'"
wsl.exe -e bash -lc "$ENC"
ls -l "$ABS/$NAME.mp4" "$ABS/${NAME}_contact.png" 2>/dev/null
echo "clip: $ABS/$NAME.mp4"
