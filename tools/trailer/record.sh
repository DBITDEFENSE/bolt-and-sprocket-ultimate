#!/usr/bin/env sh
# T-285: record one run of gravelight/tools_src/trailer_shots.json invisibly under WSL + Xvfb (Forward+ on lavapipe,
# as T-280's blast captures), frame by frame at a fixed game step, then encode each shot's frames to
# build/trailers/src/<run>/<shot>.mp4 (H.264, 24 fps) with a contact sheet. ONE render at a time: the script refuses
# when another Xvfb runs in WSL or less than 8 GB is free.
#   tools/trailer/record.sh <run> [--only=a,b] [--stride=12] [--scale=0.75]
# Env: TRAILER_RES (1280x720), TRAILER_DRIVER (vulkan | opengl3), WSL_TIMEOUT (5400 s), WSL_GODOT (the Linux binary).
cd "$(dirname "$0")/../.." || exit 2
RUN="$1"; [ -n "$RUN" ] || { echo "usage: tools/trailer/record.sh <run> [args]" >&2; exit 2; }
shift
OUT="build/trailers/src/$RUN"
mkdir -p "$OUT"
if wsl.exe -e bash -lc "pgrep -x Xvfb >/dev/null"; then
	echo "record: another Xvfb runs in WSL; wait for it" >&2
	exit 3
fi
FREE=$(wsl.exe -e bash -lc "free -m | awk '/^Mem:/ {print \$7}'" | tr -d '\r')
if [ "${FREE:-0}" -lt 8000 ]; then
	echo "record: only ${FREE} MB free in WSL (want 8000)" >&2
	exit 3
fi
to_wsl() { printf '%s' "$1" | sed -e 's#^/\([A-Za-z]\)/#/mnt/\1/#' -e 's#^\([A-Za-z]\):#/mnt/\1#' -e 's#\\#/#g'; }
WDIR="$(to_wsl "$(pwd)")"
BIN="${WSL_GODOT:-}"
if [ -z "$BIN" ]; then
	BIN="$WDIR/tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
	if [ ! -f "tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64" ]; then
		BIN="$(printf '%s' "$WDIR" | sed -e 's#/\.claude/worktrees/[^/]*$##' -e 's#/\.wt/[^/]*$##')/tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
	fi
fi
RES="${TRAILER_RES:-1280x720}"
ARGS=""
for a in "$@"; do ARGS="$ARGS '$a'"; done
start=$(date +%s)
CMD="cd '$WDIR' && timeout ${WSL_TIMEOUT:-5400} xvfb-run -a -s '-screen 0 ${RES}x24' '$BIN' --rendering-driver ${TRAILER_DRIVER:-vulkan} --audio-driver Dummy --resolution $RES --fixed-fps 24 --path . res://gravelight/tools_src/clip_trailer.tscn -- --run=$RUN --out='$WDIR/$OUT'$ARGS > '$WDIR/$OUT/run.log' 2>&1; grep -E '^\[trailer\]|SCRIPT ERROR|SHADER ERROR' '$WDIR/$OUT/run.log' | head -80"
wsl.exe -e bash -lc "$CMD"
echo "record: the render took $(( $(date +%s) - start )) s"
# encode every shot folder that has frames (24 fps; a stride preview is encoded at 24/stride)
FPS=24
case "$ARGS" in *--stride=*) FPS=$(printf '%s' "$ARGS" | sed -e "s/.*--stride=\([0-9]*\).*/\1/"); FPS=$(awk "BEGIN{printf \"%.3f\", 24/$FPS}") ;; esac
ENC="cd '$WDIR/$OUT' && for d in */; do d=\${d%/}; ls \"\$d\"/*.jpg >/dev/null 2>&1 || continue; ffmpeg -y -loglevel error -framerate $FPS -pattern_type glob -i \"\$d/*.jpg\" -c:v libx264 -preset medium -crf 16 -pix_fmt yuv420p -movflags +faststart \"\$d.mp4\" && ffmpeg -y -loglevel error -i \"\$d.mp4\" -vf 'thumbnail=6,scale=320:-2,tile=3x1' -frames:v 1 \"\$d.jpg\" 2>/dev/null; echo \"record: \$d.mp4 \$(ffprobe -v error -show_entries format=duration -of csv=p=0 \$d.mp4) s\"; done"
wsl.exe -e bash -lc "$ENC"
