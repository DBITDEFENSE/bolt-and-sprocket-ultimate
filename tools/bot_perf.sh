#!/usr/bin/env sh
# T-237: what the bots cost per frame, and the hitches (headless, silent, no window). Runs perf_marks --hitch
# (round 15, 24 zombies kept alive, the squad kept standing, the map's spawn) at 60 fixed frames a second: every
# frame is one physics tick + one process step, so a frame's wall time is the CPU work of one 60 FPS frame without
# the renderer.
#   tools/bot_perf.sh <tag> [maps (comma list)] [runs] [extra perf_marks flags]
#     -> .smoke_logs/t237/<tag>/<map>_<bots|nobots>_<run>.log, and the [hitch] summary lines on the screen
# Each run does bots-on (3 bots + Jakub + the map's companion), the same with T-237's optimisations switched off
# ("old": the before), then bots-off (the player alone), back to back, so the three share the machine's load.
# tools/bot_perf_table.py <dir> prints the medians over the runs as a table. Extra flags: --secs=N (the window, default 30), --live (the round runs: kills
# and spawns; the squad can go down), --ai=squad (the planner bot, scripted; --ai=local would start Ollama).
# --no-marks is always on. BOT_PERF_ONLY="bots old" (any of bots, old, nobots) runs those sides only.
# On Windows the run is started at High priority (a busy machine otherwise preempts it and every preemption
# reads as a hitch); BOT_PERF_PRIO=normal turns that off.
cd "$(dirname "$0")/.."
. tools/env.sh
TAG="${1:-run}"
MAPS="${2:-map00_crossroads,map01_kaltenbrunn}"
RUNS="${3:-3}"
shift 3 2>/dev/null || shift $#
OUT=".smoke_logs/t237/$TAG"
mkdir -p "$OUT"
HIGH=0
case "$(uname -s 2>/dev/null)" in
	MINGW*|MSYS*|CYGWIN*) [ "${BOT_PERF_PRIO:-high}" = high ] && HIGH=1 ;;
esac
run_one() {   # $1 log, the rest: perf_marks flags
	_log="$1"
	shift
	if [ "$HIGH" = 1 ]; then
		cmd //c start "" //b //high //wait "$(cygpath -w "$GODOT")" --headless --audio-driver Dummy --fixed-fps 60 --path . \
			res://gravelight/tools_src/perf_marks.tscn -- "$@" > "$_log" 2>&1
	else
		"$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . res://gravelight/tools_src/perf_marks.tscn -- "$@" > "$_log" 2>&1
	fi
}
for m in $(echo "$MAPS" | tr ',' ' '); do
	r=1
	while [ "$r" -le "$RUNS" ]; do
		for cfg in ${BOT_PERF_ONLY:-bots old nobots}; do
			case "$cfg" in
				bots) B="--bots=3" ;;
				old) B="--bots=3 --ab=t237_off" ;;   # the same build with T-237's optimisations off: the "before"
				*) B="--bots=0 --no-companions" ;;
			esac
			run_one "$OUT/${m}_${cfg}_$r.log" --map="$m" --preset=low --hitch --no-marks --secs=30 $B "$@"
			echo "== $m $cfg run $r (exit $?)"
			grep -E "^\[hitch\] (map|frame wall|scripts per)" "$OUT/${m}_${cfg}_$r.log"
		done
		r=$((r + 1))
	done
done
