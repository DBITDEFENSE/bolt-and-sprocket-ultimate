#!/usr/bin/env bash
# T-266: one map's views rendered several ways, one after the other (WSL / Linux + Xvfb, lavapipe; counts only).
#   wsl.exe --cd <worktree> -e bash tools/perf/ab_views.sh <label> <map> <preset> <views flags> <variant> [<variant> ...]
# A variant is a comma list of extra perf_marks flags ("-" for none), e.g.  -  --t266-off  --ab=no_dir_shadows
#   -> .smoke_logs/t266/<label>/<map>_<preset>_<n>.log, the [views] summary of each printed at the end.
set -u
LABEL="$1"; MAP="$2"; PRESET="$3"; VFLAGS="$4"; shift 4
G="${GODOT_LINUX:-tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64}"
[ -x "$G" ] || G="../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$G" ] || G="../../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
OUT=".smoke_logs/t266/$LABEL"
mkdir -p "$OUT"
n=0
for v in "$@"; do
	n=$((n + 1))
	[ "$v" = "-" ] && v=""
	# one software-rendered job at a time, and only with 8 GB free: several at once took the whole WSL VM down
	until [ "$(free -m | awk '/^Mem:/ {print $7}')" -gt 8000 ]; do sleep 20; done
	( timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --rendering-driver vulkan --audio-driver Dummy --resolution 1280x720 --path . \
		res://gravelight/tools_src/perf_marks.tscn -- --map="$MAP" --preset="$PRESET" --quick --cheap $VFLAGS ${v//,/ } > "$OUT/${MAP}_${PRESET}_$n.log" 2>&1 )
done
n=0
for v in "$@"; do
	n=$((n + 1))
	echo "== $n: $v"
	grep -E "^\[views\]|^\[ShadowProxies\]|SCRIPT ERROR" "$OUT/${MAP}_${PRESET}_$n.log" | cut -c1-600
done
