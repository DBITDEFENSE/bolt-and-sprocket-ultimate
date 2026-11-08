#!/usr/bin/env sh
# T-211: the smokes GRAVELIGHT ONE can touch, one RESULT line each (as tools/run_smokes.sh, by exact name).
# Usage: tools/c47/smokes.sh [log_dir] [names...]
cd "$(dirname "$0")/../.."
. tools/env.sh
LOG="${1:-.smoke_logs/c47}"
[ $# -gt 0 ] && shift
NAMES="$*"
[ -n "$NAMES" ] || NAMES="smoke_wreck_pilot smoke_wreck_collapse smoke_map00 smoke_map00_alive smoke_map00_cellar_bay smoke_map00_loop smoke_landscape smoke_bots_shop_m0 smoke_bots smoke_cinema_lazarus"
mkdir -p "$LOG"
FAIL=0
for name in $NAMES; do
	scene="gravelight/tools_src/$name.tscn"
	[ -f "$scene" ] || scene="tools_src/$name.tscn"
	start=$(date +%s)
	timeout 1200 "$GODOT" --headless --audio-driver Dummy --path . "res://$scene" > "$LOG/$name.log" 2>&1
	code=$?
	secs=$(( $(date +%s) - start ))
	errs=$(grep -c "SCRIPT ERROR" "$LOG/$name.log")
	result=$(grep -E "RESULT" "$LOG/$name.log" | tail -1 | cut -c1-160)
	if [ $code -ne 0 ] || [ "$errs" -gt 0 ]; then FAIL=$((FAIL + 1)); fi
	echo "$name: exit $code, ${secs}s, script errors $errs | $result"
done
echo "[smokes] failures: $FAIL"
exit $FAIL
