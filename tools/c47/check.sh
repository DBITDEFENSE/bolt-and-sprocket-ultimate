#!/usr/bin/env sh
# T-211: GRAVELIGHT ONE's checks in one go (headless): the GUT tests the C-47 touches, one line each.
# Usage: tools/c47/check.sh [log_dir] [test names...]   (default: the C-47's set)
cd "$(dirname "$0")/../.."
. tools/env.sh
LOG="${1:-.smoke_logs/c47}"
[ $# -gt 0 ] && shift
mkdir -p "$LOG"
TESTS="$*"
[ -n "$TESTS" ] || TESTS="test_c47_wreck test_map00_art test_map00_grounds test_trapped_pilot test_u11_egg_guard test_map00_landscape test_license_gate test_assets_manifest"
FAIL=0
for t in $TESTS; do
	"$GODOT" --headless --audio-driver Dummy --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gselect="$t" > "$LOG/gut_$t.log" 2>&1
	P=$(grep -E "^Passing Tests" "$LOG/gut_$t.log" | tr -s ' ' | cut -d' ' -f3)
	F=$(grep -E "^Failing Tests" "$LOG/gut_$t.log" | tr -s ' ' | cut -d' ' -f3)
	echo "[check] $t: passing ${P:-?} failing ${F:-0}"
	[ "${F:-0}" = "0" ] && [ -n "$P" ] || FAIL=$((FAIL + 1))
done
echo "[check] failures: $FAIL"
exit $FAIL
