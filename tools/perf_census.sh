#!/usr/bin/env sh
# UPDATE 09 section 2d (T-139): the headless census of every map (no window, the dummy renderer): lights, shadow
# casters, shadowed lights per zone and the CPU cost of every script per frame (perf_marks --breakdown --probe) at
# round 15 with 24 zombies, 3 bots and the companions. Draw calls and triangles need a renderer: tools/wsl_perf.sh.
#   tools/perf_census.sh [maps (comma list)] [preset] [extra perf_marks flags]   -> .smoke_logs/u09/census/hl_<map>.log
cd "$(dirname "$0")/.."
. tools/env.sh
MAPS="${1:-map00_crossroads,map01_kaltenbrunn,map02_totenhafen,map04a_thalbach,map04b_kranich,map04c_groomlake,map04d_mondlicht}"
PRESET="${2:-low}"
shift 2 2>/dev/null || shift $#
OUT=.smoke_logs/u09/census
mkdir -p "$OUT"
for m in $(echo "$MAPS" | tr ',' ' '); do
	"$GODOT" --headless --audio-driver Dummy --path . res://gravelight/tools_src/perf_marks.tscn -- --map="$m" --preset="$PRESET" --breakdown --probe "$@" > "$OUT/hl_$m.log" 2>&1
	echo "== $m (exit $?)"
	grep -E "^\[perf\] (shadowed omni|probe:|brains|in play)|^\[perf\]   (zombie|bot_brain|player|people|patron|jakub|map_companion|zombie_body)[a-z_]*\.gd" "$OUT/hl_$m.log"
done
