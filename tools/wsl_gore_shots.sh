#!/usr/bin/env sh
# The gore scenes (gravelight/tools_src/shots_gore.gd) rendered invisibly under WSL + Xvfb on Forward+ (Vulkan on
# lavapipe: the picture the owner's GPU draws, not the Compatibility one; docs/u19/t252_textures.md), with
# --write-movie so game time is fixed per frame. Frames land in docs/captures/gore_rework/<tag>/, the movie is
# encoded to <tag>/gore.mp4 and the AVI removed.
#   tools/wsl_gore_shots.sh <tag: before|after|...> [--only=wall,snow] [--gore=full]
# Env: GORE_DRIVER (vulkan | opengl3), GORE_FPS (30), GORE_RES (1280x720), WSL_TIMEOUT (3000 s),
#      WSL_GODOT (the Linux Godot binary as a WSL path; default this checkout's tools/dl_godot, else the main checkout's).
cd "$(dirname "$0")/.." || exit 2
TAG="${1:-after}"; [ $# -ge 1 ] && shift
OUT="docs/captures/gore_rework/$TAG"
mkdir -p "$OUT"
to_wsl() { printf '%s' "$1" | sed -e 's#^/\([A-Za-z]\)/#/mnt/\1/#' -e 's#^\([A-Za-z]\):#/mnt/\1#' -e 's#\\#/#g'; }
WDIR="$(to_wsl "$(pwd)")"
BIN="${WSL_GODOT:-}"
if [ -z "$BIN" ]; then
	BIN="$WDIR/tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
	if [ ! -f "tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64" ]; then
		BIN="$(printf '%s' "$WDIR" | sed -e 's#/\.claude/worktrees/[^/]*$##' -e 's#/\.wt/[^/]*$##')/tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
	fi
fi
RES="${GORE_RES:-1280x720}"
ARGS=""
for a in "$@"; do ARGS="$ARGS '$a'"; done
CMD="cd '$WDIR' && timeout ${WSL_TIMEOUT:-3000} xvfb-run -a -s '-screen 0 ${RES}x24' '$BIN' --rendering-driver ${GORE_DRIVER:-vulkan} --audio-driver Dummy --resolution $RES --write-movie '$WDIR/$OUT/gore.avi' --fixed-fps ${GORE_FPS:-30} --path . res://gravelight/tools_src/shots_gore.tscn -- --out='$WDIR/$OUT'$ARGS > '$WDIR/$OUT/run.log' 2>&1; grep -E '^\[shots_gore\] (stats|[0-9])|SCRIPT ERROR|SHADER ERROR' '$WDIR/$OUT/run.log' | head -20; cd '$WDIR/$OUT' && [ -f gore.avi ] && ffmpeg -y -loglevel error -i gore.avi -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2' -c:v libx264 -preset medium -crf 26 -pix_fmt yuv420p -an -movflags +faststart gore.mp4 && rm -f gore.avi; ls | wc -l"
wsl.exe -e bash -lc "$CMD"
