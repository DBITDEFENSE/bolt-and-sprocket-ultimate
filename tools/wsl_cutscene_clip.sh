#!/usr/bin/env sh
# T-184: film one cutscene through WSL + Xvfb (invisible, software GL; never a window on the owner's screen).
# gravelight/tools_src/clip_cutscene.gd plays it the way the game starts it and prints the START / END frames; the
# movie is trimmed to the START (the tail after the END stays in), encoded to <out>/<name>.mp4, with a contact sheet
# <name>_contact.png (one still every 2.5 s) and <name>_stills/NNN.png (one per second) for reading frame by frame.
# Usage: tools/wsl_cutscene_clip.sh <cut id> <out_dir> [name] [tool args, e.g. --skip-at=5]
#   e.g. tools/wsl_cutscene_clip.sh exfil_m0_m1 morning/clips/t184_before
# Env: CLIP_RES (960x540), CLIP_FPS (24), CLIP_CRF (24), WSL_TIMEOUT (3600).
cd "$(dirname "$0")/.." || exit 2
[ -n "$2" ] || { echo "usage: tools/wsl_cutscene_clip.sh <cut id> <out_dir> [name]" >&2; exit 2; }
CUT="$1"; OUT="$2"; NAME="${3:-$1}"
shift; shift; [ $# -ge 1 ] && shift
RES="${CLIP_RES:-960x540}"; FPS="${CLIP_FPS:-24}"; CRF="${CLIP_CRF:-24}"
export WSL_TIMEOUT="${WSL_TIMEOUT:-3600}"
mkdir -p "$OUT"
ABS="$(cd "$OUT" && pwd)"
WABS="$(printf '%s' "$ABS" | sed -e 's#^/\([A-Za-z]\)/#/mnt/\1/#' -e 's#^\([A-Za-z]\):#/mnt/\1#' -e 's#\\#/#g')"
rm -f "$ABS/$NAME.avi"
start=$(date +%s)
sh tools/wsl_godot.sh --res="$RES" --write-movie "$WABS/$NAME.avi" --fixed-fps "$FPS" \
	--path . res://gravelight/tools_src/clip_cutscene.tscn -- --cut="$CUT" "$@" > "$ABS/$NAME.full.log" 2>&1
grep -E "^\[clip\]|SCRIPT ERROR" "$ABS/$NAME.full.log" | tee "$ABS/$NAME.log"
echo "clip: the Godot run took $(( $(date +%s) - start )) s"
[ -f "$ABS/$NAME.avi" ] || { echo "clip: no AVI ($ABS/$NAME.avi)" >&2; exit 1; }
SF="$(grep -o 'START frame=[0-9]*' "$ABS/$NAME.log" | head -1 | cut -d= -f2)"
SS="$(awk "BEGIN { printf \"%.3f\", ${SF:-0} / $FPS }")"
ENC="cd '$WABS' && ffmpeg -y -loglevel error -ss $SS -i '$NAME.avi' -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2' -c:v libx264 -preset medium -crf $CRF -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart '$NAME.mp4' \
 && ffmpeg -y -loglevel error -i '$NAME.mp4' -vf 'fps=2/5,scale=320:-2,tile=6x6:padding=4' -frames:v 1 '${NAME}_contact.png' \
 && rm -rf '${NAME}_stills' && mkdir -p '${NAME}_stills' && ffmpeg -y -loglevel error -i '$NAME.mp4' -vf 'fps=1,scale=640:-2' '${NAME}_stills/%03d.png' \
 && ffprobe -v error -show_entries format=duration -of csv=p=0 '$NAME.mp4' | sed 's/^/clip: mp4 seconds /' && rm -f '$NAME.avi'"
wsl.exe -e bash -lc "$ENC"
ls -l "$ABS/$NAME.mp4" "$ABS/${NAME}_contact.png" 2>/dev/null
