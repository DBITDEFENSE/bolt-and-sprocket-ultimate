#!/usr/bin/env sh
# UPDATE 12 section 2 (DECISIONS T-208): the material audit. Loads every map headless (one Godot run per map, the
# material pass held back), lists every world material against docs/ART_BIBLE.md section 7 before and after the pass
# (gravelight/tools_src/material_audit.gd), then files docs/look/material_audit.md (tools/look/material_audit.py).
# Usage: tools/look/material_audit.sh [--write-fixes] [maps,comma,separated]
#   --write-fixes  merge the texture fixes the run found (tex_tint, tex_rough) into data/look/_materials.json, then
#                  run again so the report shows the data as committed.
cd "$(dirname "$0")/../.."
. tools/env.sh
WRITE=""
if [ "$1" = "--write-fixes" ]; then WRITE="--write-fixes"; shift; fi
MAPS="${1:-map00_crossroads,map01_kaltenbrunn,map02_totenhafen,map04a_thalbach,map04b_kranich,map04c_groomlake,map04d_mondlicht}"
OUT="$(pwd)/.smoke_logs/material_audit"
run_all() {
	mkdir -p "$OUT"
	for m in $(echo "$MAPS" | tr ',' ' '); do
		timeout 900 "$GODOT" --headless --audio-driver Dummy --path . res://gravelight/tools_src/material_audit.tscn -- \
			--map="$m" --out="$OUT" > "$OUT/$m.log" 2>&1
		grep -E "^RESULT|SCRIPT ERROR" "$OUT/$m.log" | head -3
	done
}
run_all
if [ -n "$WRITE" ]; then
	"$PYTHON" -I tools/look/material_audit.py "$OUT" --write-fixes data/look/_materials.json
	run_all
fi
"$PYTHON" -I tools/look/material_audit.py "$OUT" --report docs/look/material_audit.md
