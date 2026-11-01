#!/usr/bin/env sh
# Run the Linux Godot binary under WSL + Xvfb (software GL, invisible on the owner's screen). Generic wrapper:
#   tools/wsl_godot.sh [--res=WxH] <godot args...>
# Example: tools/wsl_godot.sh --path . res://tools_src/capture.tscn -- --milestone=u09_before
#          tools/wsl_godot.sh --headless --path . -s res://some_census.gd      (any flags, e.g. --breakdown)
# Windows only (Git Bash). Never runs the Windows binary with a window (CLAUDE.md, contract C8).
# Env: WSL_GODOT (Linux binary; default this repo's tools/dl_godot, else the main checkout's), WSL_TIMEOUT (s, 1800).
RES="1280x720"
case "$1" in --res=*) RES="${1#--res=}"; shift ;; esac
HERE="$(pwd)"
# Git Bash path -> WSL path: /c/Users/x -> /mnt/c/Users/x ; C:\Users\x -> /mnt/c/Users/x
to_wsl() { printf '%s' "$1" | sed -e 's#^/\([A-Za-z]\)/#/mnt/\1/#' -e 's#^\([A-Za-z]\):#/mnt/\1#' -e 's#\\#/#g'; }
WDIR="$(to_wsl "$HERE")"
BIN="${WSL_GODOT:-}"
if [ -z "$BIN" ]; then
	BIN="tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
	if [ ! -f "$HERE/$BIN" ]; then
		# a git worktree has no tools/dl_godot of its own: use the main checkout's binary (same as tools/env.sh)
		MAIN="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/.."
		MAINW="$(cd "$MAIN" 2>/dev/null && pwd)"
		[ -f "$MAINW/$BIN" ] && BIN="$(to_wsl "$MAINW")/$BIN"
	fi
fi
case "$BIN" in /*) ;; *) BIN="$WDIR/$BIN" ;; esac
# quote every Godot arg for the bash -lc string
QARGS=""
for a in "$@"; do
	QARGS="$QARGS '$(printf '%s' "$a" | sed "s/'/'\\\\''/g")'"
done
CMD="cd '$WDIR' && timeout ${WSL_TIMEOUT:-1800} xvfb-run -a -s '-screen 0 1920x1080x24' '$BIN' --rendering-driver opengl3 --audio-driver Dummy --resolution $RES$QARGS"
echo "tools/wsl_godot.sh runs: wsl.exe -e bash -lc \"$CMD\""
wsl.exe -e bash -lc "$CMD"
