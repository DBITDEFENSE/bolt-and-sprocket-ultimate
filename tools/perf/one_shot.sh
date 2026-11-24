#!/usr/bin/env bash
# T-266: one capture camera shot once per variant of T-266's switches (Compatibility renderer under WSL / Linux +
# Xvfb: minutes), to find which pass a difference in a before / after pair comes from.
#   wsl.exe --cd <worktree> -e bash tools/perf/one_shot.sh <set> <camera> <preset> <variant> [<variant> ...]
# A variant is "-" (everything on), a --t266-off value (all, proxies, props, occlusion, proxies,props ...) or
# holders=<container>[,<container>] (ShadowProxies merges only those batch containers).
#   -> morning/screenshots/<set>/one_<variant>/NN_<camera>.png
set -u
SET="$1"; CAM="$2"; PRESET="$3"; shift 3
G="${GODOT_LINUX:-tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64}"
[ -x "$G" ] || G="../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$G" ] || G="../../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
mkdir -p .smoke_logs/t266/captures
for v in "$@"; do
	flag="--t266-off=$v"; label="one_${v//,/_}"
	[ "$v" = "all" ] && flag="--t266-off"
	[ "$v" = "-" ] && { flag=""; label="one_on"; }
	case "$v" in holders=*) flag="--t266-holders=${v#holders=}"; label="one_only_$(echo "${v#holders=}" | tr -c 'A-Za-z0-9
' '_')" ;; esac
	until [ "$(free -m | awk '/^Mem:/ {print $7}')" -gt 8000 ]; do sleep 20; done
	timeout 3000 xvfb-run -a -s "-screen 0 1920x1080x24" "$G" --rendering-driver "${T266_DRIVER:-opengl3}" --audio-driver Dummy --resolution 1280x720 --path . \
		res://tools_src/capture.tscn -- --set="$SET" --label="$label" --preset="$PRESET" --only="$CAM" --frames=4 $flag > ".smoke_logs/t266/captures/${SET}_$label.log" 2>&1
	echo "[one_shot] $SET $CAM $label: $(grep -c '^\[capture\] /' ".smoke_logs/t266/captures/${SET}_$label.log") shots"
done
