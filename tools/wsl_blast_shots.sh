#!/usr/bin/env sh
# T-280: the explosion scenes (gravelight/tools_src/shots_blast.gd) rendered invisibly under WSL + Xvfb on Forward+
# (Vulkan on lavapipe: the picture the owner's GPU draws), with --write-movie so game time is fixed per frame.
# Frames land in docs/captures/t280/<tag>/, the movie is encoded to <tag>/blast.mp4 (and a contact sheet per scene)
# and the AVI removed. One render at a time: check `free -m` and `pgrep -fa Xvfb` in WSL first.
#   tools/wsl_blast_shots.sh <tag: before|after|...> [--only=grenade_night,bomb_day]
# Env: BLAST_DRIVER (vulkan | opengl3), BLAST_FPS (24), BLAST_RES (1280x720), WSL_TIMEOUT (3600 s),
#      WSL_GODOT (the Linux Godot binary as a WSL path; default this checkout's tools/dl_godot, else the main checkout's).
cd "$(dirname "$0")/.." || exit 2
TAG="${1:-after}"; [ $# -ge 1 ] && shift
OUT="docs/captures/t280/$TAG"
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
RES="${BLAST_RES:-1280x720}"
ARGS=""
for a in "$@"; do ARGS="$ARGS '$a'"; done
CMD="cd '$WDIR' && timeout ${WSL_TIMEOUT:-3600} xvfb-run -a -s '-screen 0 ${RES}x24' '$BIN' --rendering-driver ${BLAST_DRIVER:-vulkan} --audio-driver Dummy --resolution $RES --write-movie '$WDIR/$OUT/blast.avi' --fixed-fps ${BLAST_FPS:-24} --path . res://gravelight/tools_src/shots_blast.tscn -- --out='$WDIR/$OUT'$ARGS > '$WDIR/$OUT/run.log' 2>&1; grep -E '^\[shots_blast\] (stats|[0-9])|SCRIPT ERROR|SHADER ERROR' '$WDIR/$OUT/run.log' | head -20; cd '$WDIR/$OUT' && [ -f blast.avi ] && ffmpeg -y -loglevel error -i blast.avi -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2' -c:v libx264 -preset medium -crf 26 -pix_fmt yuv420p -an -movflags +faststart blast.mp4 && rm -f blast.avi; for s in \$(ls *_01.png 2>/dev/null | sed 's/_01.png//'); do ffmpeg -y -loglevel error -pattern_type glob -i \"\${s}_*.png\" -vf 'scale=320:-2,tile=4x3' -frames:v 1 \"sheet_\${s}.jpg\"; done; ls | wc -l"
wsl.exe -e bash -lc "$CMD"
