#!/usr/bin/env sh
# Runs every headless smoke scene, silently, one after another, and prints one RESULT line each.
# Usage: tools/run_smokes.sh [log_dir] [scene_name_filter]
# Exit code: the number of smokes that did not pass (0 = all passed).
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
LOGS="${1:-.smoke_logs}"
FILTER="${2:-}"
mkdir -p "$LOGS"
fails=0
for scene in gravelight/tools_src/smoke_*.tscn tools_src/smoke_*.tscn; do
	name=$(basename "$scene" .tscn)
	case "$name" in *"$FILTER"*) ;; *) continue ;; esac
	start=$(date +%s)
	timeout 1200 "$GODOT" --headless --audio-driver Dummy --path . "res://$scene" > "$LOGS/$name.log" 2>&1
	code=$?
	secs=$(( $(date +%s) - start ))
	errs=$(grep -c "SCRIPT ERROR" "$LOGS/$name.log")
	result=$(grep -E "RESULT" "$LOGS/$name.log" | tail -1 | cut -c1-160)
	if [ $code -ne 0 ] || [ "$errs" -gt 0 ]; then fails=$((fails + 1)); fi
	echo "$name: exit $code, ${secs}s, script errors $errs | $result"
done
exit $fails
