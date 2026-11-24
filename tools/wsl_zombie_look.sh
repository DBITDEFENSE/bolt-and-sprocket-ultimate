#!/usr/bin/env sh
# T-269: the zombie look scenes (gravelight/tools_src/shots_zombie_look.gd) rendered invisibly under WSL + Xvfb on
# Forward+ (Vulkan on lavapipe: the renderer the owner's GPU uses, with the map's grade LUT; the Compatibility
# renderer has no LUT and would hide the grade's desaturation). --write-movie fixes game time per frame.
#   tools/wsl_zombie_look.sh <tag: before|after|...> --map=map00_crossroads [--only=taproom,yard] [--count=24]
# Frames land in docs/captures/t269/<tag>/<map>/ ; then: python -I tools/zombie_look_stats.py docs/captures/t269/<tag>/<map>
# Env: ZLOOK_DRIVER (vulkan | opengl3), ZLOOK_RES (1280x720), WSL_TIMEOUT (3000 s), WSL_GODOT.
cd "$(dirname "$0")/.." || exit 2
TAG="${1:-after}"; [ $# -ge 1 ] && shift
MAP="map00_crossroads"
for a in "$@"; do case "$a" in --map=*) MAP="${a#--map=}" ;; esac; done
OUT="docs/captures/t269/$TAG/$MAP"
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
RES="${ZLOOK_RES:-1280x720}"
ARGS=""
for a in "$@"; do ARGS="$ARGS '$a'"; done
CMD="cd '$WDIR' && timeout ${WSL_TIMEOUT:-3000} xvfb-run -a -s '-screen 0 ${RES}x24' '$BIN' --rendering-driver ${ZLOOK_DRIVER:-vulkan} --audio-driver Dummy --resolution $RES --write-movie '/tmp/zlook_${TAG}_${MAP}.avi' --fixed-fps 30 --path . res://gravelight/tools_src/shots_zombie_look.tscn -- --out='$WDIR/$OUT'$ARGS > '$WDIR/$OUT/run.log' 2>&1; rm -f '/tmp/zlook_${TAG}_${MAP}.avi'; grep -E '^\[zlook\]|SCRIPT ERROR|SHADER ERROR' '$WDIR/$OUT/run.log' | head -60"
wsl.exe -e bash -lc "$CMD"
