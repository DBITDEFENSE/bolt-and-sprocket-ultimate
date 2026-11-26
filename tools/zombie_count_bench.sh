#!/usr/bin/env sh
# T-281: the frame's cost against the horde's size. Headless perf_marks --hitch runs (60 fixed frames a second, no
# window, silent), A/B interleaved: for every repeat, every map and every count, the A side then the B side.
#   tools/zombie_count_bench.sh <tag> "<counts>" "<maps>" <repeats> "<A flags>" "<B flags>" [extra perf_marks flags]
#     counts: e.g. "8 16 24 32 48"; maps: m0 (Map 0) m1 (Kaltenbrunn); A/B flags e.g. "--ab=t281_off" and ""
#     (an empty B runs only the A side). -> .smoke_logs/t281/<tag>/<map>_z<N>_<A|B>_<repeat>.log
#   python -I tools/zombie_count_table.py .smoke_logs/t281/<tag> prints the table.
# Every run: round 15 (or --round=N in the extra flags), 3 bots + Jakub + the map's companion, the player at the spawn
# in god mode, the horde kept up, 20 s sampled. On Windows at High priority (TICK_PERF_PRIO=normal turns that off).
cd "$(dirname "$0")/.."
. tools/env.sh
TAG="${1:-run}"
COUNTS="${2:-8 16 24 32 48}"
MAPS="${3:-m0}"
REPS="${4:-1}"
AF="${5:-}"
BF="${6:-__none__}"
shift 6 2>/dev/null || shift $#
OUT=".smoke_logs/t281/$TAG"
mkdir -p "$OUT"
HIGH=0
case "$(uname -s 2>/dev/null)" in
	MINGW*|MSYS*|CYGWIN*) [ "${TICK_PERF_PRIO:-high}" = high ] && HIGH=1 ;;
esac
one() {   # one run: <log> <map flag> <count> <side flags...>
	LOG="$1"; MF="$2"; N="$3"; shift 3
	if [ "$HIGH" = 1 ]; then
		cmd //c start "" //b //high //wait "$(cygpath -w "$GODOT")" --headless --audio-driver Dummy --fixed-fps 60 --path . \
			res://gravelight/tools_src/perf_marks.tscn -- --preset=low --hitch --no-marks --probe-all --vo-async --seed=7 --secs=20 $MF --zombies=$N "$@" > "$LOG" 2>&1
	else
		"$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . res://gravelight/tools_src/perf_marks.tscn -- \
			--preset=low --hitch --no-marks --probe-all --vo-async --seed=7 --secs=20 $MF --zombies=$N "$@" > "$LOG" 2>&1
	fi
	echo "== $(basename "$LOG") $(grep -E '^\[hitch\] frame wall' "$LOG" | cut -c1-80)"
}
r=1
while [ "$r" -le "$REPS" ]; do
	for m in $MAPS; do
		case "$m" in
			m0) MF="--map=map00_crossroads" ;;
			m1) MF="--map=map01_kaltenbrunn" ;;
			m2) MF="--map=map02_totenhafen" ;;
			*) echo "unknown map $m"; exit 2 ;;
		esac
		for n in $COUNTS; do
			one "$OUT/${m}_z${n}_A_$r.log" "$MF" "$n" $AF "$@"
			[ "$BF" != "__none__" ] && one "$OUT/${m}_z${n}_B_$r.log" "$MF" "$n" $BF "$@"
		done
	done
	r=$((r + 1))
done
