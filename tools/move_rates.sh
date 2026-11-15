#!/usr/bin/env sh
# Movement at different frame rates (docs/perf/movement_perf_2026-11.md): runs gravelight/tools_src/move_rates.tscn
# headless at a fixed 30 / 60 / 144 / 240 frames a second with the game's 60 physics ticks (what a player on a
# slow laptop, a 60 Hz, a 144 Hz and a 240 Hz screen gets), then once more per rate with the physics tick rate
# set to the same number (what the movement code itself does with another step; the game ships at 60).
#   tools/move_rates.sh <tag> [rates (comma list, default 30,60,144,240)] [--no-ticks]
#     -> .smoke_logs/move_rates/<tag>/fps<N>.log and ticks<N>.log, then the table (tools/move_rates_table.py)
cd "$(dirname "$0")/.."
. tools/env.sh
TAG="${1:-run}"
RATES="${2:-30,60,144,240}"
OUT=".smoke_logs/move_rates/$TAG"
mkdir -p "$OUT"
for r in $(echo "$RATES" | tr ',' ' '); do
	"$GODOT" --headless --audio-driver Dummy --fixed-fps "$r" --path . res://gravelight/tools_src/move_rates.tscn > "$OUT/fps$r.log" 2>&1
	echo "== $r frames a second, 60 ticks (exit $?): $(grep -c '^\[move-rates\]' "$OUT/fps$r.log") lines, $(grep -c 'SCRIPT ERROR' "$OUT/fps$r.log") script errors"
	if [ "$3" != "--no-ticks" ] && [ "$r" != 60 ]; then
		"$GODOT" --headless --audio-driver Dummy --fixed-fps "$r" --path . res://gravelight/tools_src/move_rates.tscn -- --ticks="$r" > "$OUT/ticks$r.log" 2>&1
		echo "== $r frames a second, $r ticks (exit $?)"
	fi
done
"$PYTHON" -I tools/move_rates_table.py "$OUT"
