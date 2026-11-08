#!/usr/bin/env sh
# UPDATE 09 section 2c (DECISIONS T-139): the browser build, split into a main pack and map packs.
#   tools/build_web.sh            -> build/web/ (index.html, cz-<hash>.wasm/.js, cz-main-<hash>.pck, packs/, vercel.json,
#                                    middleware.js) and a size table
#   tools/build_web.sh --single   -> one plain export of the "Web" preset (everything in one .pck, no packs)
# Steps: tools_src/web_pack_lists.gd decides which files leave the main pack (each map's own scene and the files only
# it needs; the deferred "game" pack: VO, the Poly Haven / ambientCG / Sketchfab / OpenGameArt libraries, our wonder
# weapons, world objects and arms), tools/web_build.py writes a temporary export_presets.cfg with a "Web Main" and one
# "Web Pack <name>" preset per pack (Godot's customized export mode), Godot exports them headless, the committed
# export_presets.cfg is put back, and web_build.py hashes the names (cache forever), writes packs/manifest.json and
# prints the sizes. Needs the Godot 4.7.2 export templates (web_nothreads_release.zip).
cd "$(dirname "$0")/.."
. tools/env.sh
OUT=build/web
LOG=build/web_logs
SINGLE=0
for a in "$@"; do
	case "$a" in
		--single) SINGLE=1 ;;
	esac
done
rm -rf "$OUT" "$LOG"
mkdir -p "$OUT/packs" "$LOG"
touch build/.gdignore   # the editor must not import what the export writes here
# UPDATE 12 s3 (T-209): treat any new archive-reel clip (assets/user_supplied/cutscenes) into assets/cutscene_reels first
"$PYTHON" -I tools/cinema/archive_reel.py build || echo "[build_web] the archive-reel build failed: the reels keep their in-engine stand-ins"

if [ "$SINGLE" = "1" ]; then
	"$GODOT" --headless --audio-driver Dummy --path . --export-release "Web" "$OUT/index.html" > "$LOG/export_web.log" 2>&1 || { echo "[build_web] export failed (see $LOG/export_web.log)"; exit 1; }
	ls -la "$OUT"
	exit 0
fi

echo "[build_web] 1/4 pack lists"
"$GODOT" --headless --audio-driver Dummy --path . --script res://tools_src/web_pack_lists.gd -- --out=build/web_lists.json 2>&1 | grep "\[web_pack_lists\]" || { echo "[build_web] pack lists failed"; exit 1; }

echo "[build_web] 2/4 export presets"
cp export_presets.cfg build/export_presets.cfg.bak
restore() { cp build/export_presets.cfg.bak export_presets.cfg; }
trap restore EXIT INT TERM
"$PYTHON" -I tools/web_build.py presets build/web_lists.json build/export_presets.cfg.bak build/export_presets.web.cfg || exit 1
cp build/export_presets.web.cfg export_presets.cfg

echo "[build_web] 3/4 exports (main + packs; a few minutes)"
"$GODOT" --headless --audio-driver Dummy --path . --export-release "Web Main" "$OUT/index.html" > "$LOG/export_main.log" 2>&1
[ -f "$OUT/index.pck" ] || { echo "[build_web] main export failed (see $LOG/export_main.log)"; exit 1; }
grep "web_texture_cap" "$LOG/export_main.log"
for pack in $("$PYTHON" -I -c "import json;print(' '.join(sorted(json.load(open('build/web_lists.json'))['packs'])))"); do
	"$GODOT" --headless --audio-driver Dummy --path . --export-pack "Web Pack $pack" "$OUT/packs/$pack.pck" > "$LOG/export_$pack.log" 2>&1
	[ -f "$OUT/packs/$pack.pck" ] || { echo "[build_web] pack $pack failed (see $LOG/export_$pack.log)"; exit 1; }
	echo "  pack $pack: $(du -h "$OUT/packs/$pack.pck" | cut -f1)"
done
restore
trap - EXIT INT TERM

echo "[build_web] 4/4 names, manifest, vercel files"
"$PYTHON" -I tools/web_build.py finish "$OUT" build/web_lists.json || exit 1
echo "[build_web] done: $OUT (serve it with tools/serve_web.sh)"
