#!/usr/bin/env sh
# Bot AI pass (2026-11): the before/after soak sets for "do the bots get stuck" and "do they last past round 22".
# Headless, silent, one Godot at a time. Every run adds the BotCensus (tools_src/bot_census.gd) to the soak.
#   tools/bot_census.sh <tag> <set> [seeds (space list in quotes)] [extra ai_soak flags]
#     -> .smoke_logs/bot_ai/<tag>/<set>_s<seed>.log  (the [census] hot-spot and per-round tables are in the log;
#        the episode list, the round rows and the top-down plots are in logs/ai_runs/<run>_*)
# Sets:
#   tour00 / tour01 / tour02   stuck census: the scripted player (unhurt) tours random navmesh points all over
#                              Map 0 / Kaltenbrunn / Totenhafen with every door open and the power on, real rounds
#                              1 to 12, the squad following; the Easter-egg help off (the egg hands out every tonic)
#   late                       the late game as the owner plays it: Map 0, the scripted player with the realistic kit
#                              and a taught MG 42, unhurt (it never goes down, never revives), real rounds 1 to 30
#   alone                      three bots alone on Map 0, real rounds to the wipe (or round 35)
#   late01                     as late, on Kaltenbrunn
# tools/bot_census_table.py <dir> prints the tables of a tag.
cd "$(dirname "$0")/.."
. tools/env.sh
TAG="${1:-run}"
SET="${2:-tour00}"
SEEDS="${3:-1 2 3}"
shift 3 2>/dev/null || shift $#
OUT=".smoke_logs/bot_ai/$TAG"
mkdir -p "$OUT"
case "$SET" in
	tour00) F="--scenario=player3 --map=map00 --max-round=12 --tour --god --open-doors=all --power --ee=off" ;;
	tour01) F="--scenario=kaltenbrunn --max-round=12 --tour --god --open-doors=all --power --ee=off" ;;
	tour02) F="--scenario=totenhafen --max-round=12 --tour --god --open-doors=all --power --ee=off" ;;
	late) F="--scenario=player3 --map=map00 --max-round=30 --god --player-kit=realistic --give=mg42_up --ee=off --max-minutes=260" ;;
	late01) F="--scenario=kaltenbrunn --max-round=30 --god --player-kit=realistic --give=mg42_up --ee=off --max-minutes=260" ;;
	alone) F="--scenario=bots3 --map=map00 --max-round=35 --ee=off --max-minutes=260" ;;
	*) echo "unknown set $SET"; exit 2 ;;
esac
for s in $SEEDS; do
	start=$(date +%s)
	"$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/ai_soak.tscn -- $F --seed="$s" --runs=1 --census "$@" > "$OUT/${SET}_s$s.log" 2>&1
	echo "== $SET seed $s: exit $?, $(( $(date +%s) - start )) s, script errors $(grep -a -c 'SCRIPT ERROR' "$OUT/${SET}_s$s.log")"
	grep -a -E "^\[census\] [0-9.]+ bot-hours|SUMMARY" "$OUT/${SET}_s$s.log" | cut -c1-330
done
