#!/usr/bin/env sh
# T-265: one headless perf_marks --hitch run (60 fixed frames a second, no window, silent) of a named scenario.
#   tools/tick_perf.sh <tag> <scenario> [runs] [extra perf_marks flags]
#     -> .smoke_logs/t265/<tag>/<scenario>_<run>.log, and the summary lines on the screen
# Scenarios: m0 m1 m2 m4a m4b m4c m4d (round 15, 24 zombies kept alive, 3 bots + Jakub + the map's companion),
#   m0r30 (round 30, the Sherman parked and firing), m0r35, m0noon (the day held at noon), m0corpses (four of the
#   24 killed and replaced every second), m0live (the round runs), m0boss (a live Foreman round), m0live30 (a live
#   round 30 for 60 s: the Sherman's arrival and the assault), m0play (a live round 15 for 60 s with the player's
#   own survivor played by the agent, training the horde round the map: a moving camera with the horde behind it).
#   tools/tick_perf_table.py <dir> prints the medians.
# The probe walks the whole tree (--probe-all) and the random numbers are seeded (--seed=7).
# On Windows the run starts at High priority (TICK_PERF_PRIO=normal turns that off).
cd "$(dirname "$0")/.."
. tools/env.sh
TAG="${1:-run}"
SC="${2:-m0}"
RUNS="${3:-1}"
shift 3 2>/dev/null || shift $#
OUT=".smoke_logs/t265/$TAG"
mkdir -p "$OUT"
case "$SC" in
	m0) F="--map=map00_crossroads" ;;
	m1) F="--map=map01_kaltenbrunn" ;;
	m2) F="--map=map02_totenhafen" ;;
	m4a) F="--map=map04a_thalbach" ;;
	m4b) F="--map=map04b_kranich" ;;
	m4c) F="--map=map04c_groomlake" ;;
	m4d) F="--map=map04d_mondlicht" ;;
	m0r30) F="--map=map00_crossroads --round=30 --tank" ;;
	m0r35) F="--map=map00_crossroads --round=35" ;;
	m0live) F="--map=map00_crossroads --live" ;;
	m0live30) F="--map=map00_crossroads --live --round=30 --secs=60" ;;
	m0corpses) F="--map=map00_crossroads --corpses" ;;
	m0boss) F="--map=map00_crossroads --live --boss" ;;
	m0play) F="--map=map00_crossroads --live --botmode --secs=60" ;;
	m0noon) F="--map=map00_crossroads --hour=12" ;;
	*) echo "unknown scenario $SC"; exit 2 ;;
esac
HIGH=0
case "$(uname -s 2>/dev/null)" in
	MINGW*|MSYS*|CYGWIN*) [ "${TICK_PERF_PRIO:-high}" = high ] && HIGH=1 ;;
esac
r=1
while [ "$r" -le "$RUNS" ]; do
	LOG="$OUT/${SC}_$r.log"
	if [ "$HIGH" = 1 ]; then
		cmd //c start "" //b //high //wait "$(cygpath -w "$GODOT")" --headless --audio-driver Dummy --fixed-fps 60 --path . \
			res://gravelight/tools_src/perf_marks.tscn -- --preset=low --hitch --no-marks --probe-all --vo-async --seed=7 --secs=30 $F "$@" > "$LOG" 2>&1
	else
		"$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . res://gravelight/tools_src/perf_marks.tscn -- --preset=low --hitch --no-marks --probe-all --vo-async --seed=7 --secs=30 $F "$@" > "$LOG" 2>&1
	fi
	echo "== $SC run $r (exit $?)"
	grep -E "^\[hitch\] (frame wall|scripts per)" "$LOG"
	r=$((r + 1))
done
