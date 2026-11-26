#!/usr/bin/env sh
# Runs every headless smoke scene, silently, one after another, and prints one RESULT line each.
# Usage: tools/run_smokes.sh [log_dir] [scene_name_filter]   (SMOKE_PROJECT=<folder>: run them from that project folder)
# Exit code: the number of smokes that did not pass (0 = all passed).
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
LOGS="${1:-.smoke_logs}"
PROJ="${SMOKE_PROJECT:-.}"   # T-283: another project folder (e.g. a junction copy with another project.godot)
FILTER="${2:-}"
mkdir -p "$LOGS"
fails=0
for scene in gravelight/tools_src/smoke_*.tscn tools_src/smoke_*.tscn; do
	name=$(basename "$scene" .tscn)
	case "$name" in *"$FILTER"*) ;; *) continue ;; esac
	start=$(date +%s)
	# T-286: smoke_letzte_fahrt plays up to 55 game minutes at x2 on its own clock, which ends it with a RESULT line;
	# with three bots and a horde the game runs at about half speed headless (43.5 game min took 2,700 s on the
	# owner's PC), so the 1,200 s wall killed every run of it mid-egg (exit 124, no RESULT) since UPDATE 10: 3,900 s
	wall=1200
	case "$name" in smoke_letzte_fahrt) wall=3900 ;; esac
	timeout "$wall" "$GODOT" --headless --audio-driver Dummy --path "$PROJ" "res://$scene" > "$LOGS/$name.log" 2>&1
	code=$?
	secs=$(( $(date +%s) - start ))
	errs=$(grep -c "SCRIPT ERROR" "$LOGS/$name.log")
	result=$(grep -E "RESULT" "$LOGS/$name.log" | tail -1 | cut -c1-160)
	if [ $code -ne 0 ] || [ "$errs" -gt 0 ]; then fails=$((fails + 1)); fi
	echo "$name: exit $code, ${secs}s, script errors $errs | $result"
done
exit $fails
