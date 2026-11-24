#!/usr/bin/env bash
# UPDATE 09 section 2d (T-139): the draw-call / triangle / light census of every map, rendered invisibly (contract C8:
# WSL or Linux + Xvfb + the Linux Godot, software GL). FPS here is meaningless (llvmpipe); draw calls, triangles,
# lights, shadow casters and the scripts' CPU costs are not.
#   From Windows (PowerShell):  wsl.exe --cd <repo or worktree> -e bash tools/wsl_perf.sh [maps] [presets] [extra flags]
#   On Linux:                   tools/wsl_perf.sh [maps] [presets] [extra flags]
#   Runs at 1280x720 (draw calls and triangles are the same at any 16:9 size; software GL is just faster).
#   maps     comma list of map ids (default: all seven), presets: comma list (default: web,low)
#   "web" runs the Compatibility renderer (opengl3: what the browser runs); any other preset runs Forward+ on Vulkan
#   (lavapipe). Extra flags go to perf_marks (e.g. --probe, --no-webprofile). Logs: .smoke_logs/u09/census/.
set -u
MAPS="${1:-map00_crossroads,map01_kaltenbrunn,map02_totenhafen,map04a_thalbach,map04b_kranich,map04c_groomlake,map04d_mondlicht}"
PRESETS="${2:-web,low}"
shift 2 2>/dev/null || shift $#
EXTRA="$*"
G="${GODOT_LINUX:-tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64}"
[ -x "$G" ] || G="../../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"   # a worktree under .claude/worktrees
[ -x "$G" ] || G="../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"   # a worktree under .wt
[ -x "$G" ] || { echo "[wsl_perf] no Linux Godot (set GODOT_LINUX)"; exit 1; }
OUT="${PERF_OUT:-.smoke_logs/u09/census}"
mkdir -p "$OUT"
for m in ${MAPS//,/ }; do
	for p in ${PRESETS//,/ }; do
		if [ "$p" = "web" ]; then DRV="--rendering-driver opengl3"; else DRV="--rendering-driver vulkan"; fi
		tag="${m}_${p}$(echo "$EXTRA" | tr -dc 'a-z_' | head -c 24)"
		echo "[wsl_perf] $m $p $EXTRA"
		timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" "$G" $DRV --audio-driver Dummy --resolution 1280x720 --path . \
			res://gravelight/tools_src/perf_marks.tscn -- --map="$m" --preset="$p" --breakdown --quick $EXTRA > "$OUT/$tag.log" 2>&1
		grep -E "^\[view|^\[perf\] (per frame|shadowed omni|in play|census:|env:|renderer|map |WebProfile)|^\[WebProfile\]|SHADER ERROR|shader compilation failed" "$OUT/$tag.log" | head -20
	done
done
