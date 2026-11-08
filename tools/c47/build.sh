#!/usr/bin/env sh
# GRAVELIGHT ONE's C-47 (UPDATE 12 section 5, DECISIONS T-211): builds the intact and the crashed aircraft from
# whichever source exists and imports them. The game picks the result up with no code change (C47Art).
#
#   tools/c47/build.sh                 the first model found in assets/user_supplied/u12/c47/ (in the order below),
#                                      else our stand-in
#   tools/c47/build.sh --standin       the stand-in only (also rewrites data/gravelight/c47_colliders.json)
#   tools/c47/build.sh --preview=DIR   also Cycles previews of both (CPU, no window)
#
# A downloaded model: one folder per model under assets/user_supplied/u12/c47/ (git-ignored), holding the GLB
# (model.glb, or any *.glb / *.gltf) and a SOURCE.txt with the Sketchfab page's link. The folder names it looks for:
#   c47-manilov-ap               "C47" by manilov.ap, CC-BY 4.0 (the main model)
#   c47-dakota-kn645-mgg8        "Douglas C-47B Dakota IV KN645" by mgg8, CC0
#   c47-skytrain-spark-customs   "Douglas C-47 Skytrain" by Spark_Customs, CC-BY 4.0
#   dc3-manilov-ap               "Dc3" by manilov.ap, CC-BY 4.0
# The output goes to assets/third_party/sketchfab/<id>/{intact,crashed}.glb with LICENSE.txt and SOURCE.txt (its
# credit line), then tools/assets_manifest.py regenerates docs/ASSETS.md and data/credits_art.json, so the Credits
# screen lists the artist. The colliders (data/gravelight/c47_colliders.json) stay the stand-in's: the crash layout is
# the same for any source (the pieces are cut and posed by data/gravelight/c47_wreck.json), so the map's navmesh does
# not change when the real model arrives (re-run with --write-colliders and gen_map00 to fit them to it exactly).
cd "$(dirname "$0")/../.."
. tools/env.sh
STANDIN=0
EXTRA=""
for a in "$@"; do
	case "$a" in
		--standin) STANDIN=1 ;;
		*) EXTRA="$EXTRA $a" ;;
	esac
done
"$PYTHON" -I tools/c47/make_decals.py tools/c47/_gen/decals.png || exit 1
INBOX=assets/user_supplied/u12/c47
SRC=""
ID=""
if [ $STANDIN = 0 ]; then
	for id in c47-manilov-ap c47-dakota-kn645-mgg8 c47-skytrain-spark-customs dc3-manilov-ap; do
		[ -d "$INBOX/$id" ] || continue
		f=$(ls "$INBOX/$id"/model.glb "$INBOX/$id"/*.glb "$INBOX/$id"/*.gltf 2>/dev/null | head -1)
		if [ -n "$f" ]; then SRC="$f"; ID="$id"; break; fi
	done
fi
if [ -z "$SRC" ]; then
	echo "[c47] building the stand-in (no model in $INBOX)"
	"$BLENDER" -b --factory-startup -P tools/c47/build_c47.py -- --standin --write-colliders $EXTRA 2>&1 | grep -E "^\[c47\]|Error|Traceback" || exit 1
	ROOT_ASSETS="res://assets/ours/world"
else
	OUT="assets/third_party/sketchfab/$ID"
	mkdir -p "$OUT"
	echo "[c47] building from $SRC -> $OUT"
	"$BLENDER" -b --factory-startup -P tools/c47/build_c47.py -- --source="$SRC" --id="$ID" --out="$OUT" $EXTRA 2>&1 | grep -E "^\[c47\]|Error|Traceback" || exit 1
	"$PYTHON" -I tools/c47/intake.py "$ID" "$INBOX/$ID" "$OUT" || exit 1
	"$PYTHON" -I tools/assets_manifest.py || exit 1
	ROOT_ASSETS="res://$OUT"
fi
"$GODOT" --headless --audio-driver Dummy --path . --script res://tools_src/apply_import_presets.gd -- --root="$ROOT_ASSETS" > /dev/null 2>&1
"$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
echo "[c47] imported; the game uses: $( [ -n "$ID" ] && echo "$ID" || echo standin )"
