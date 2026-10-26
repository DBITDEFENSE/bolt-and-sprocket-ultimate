#!/usr/bin/env sh
# Bakes the minimap data of playable levels (tools_src/bake_minimap.gd, Update 04 section 1, DECISIONS T-065) in an
# off-screen, silent window (the render needs the GPU): data/maps/<map_id>/mapdata.json + one PNG per floor, then
# imports the new PNGs so the game can load them. One Godot run per map, retried up to 3 times (a rendering run
# now and then exits early without a word; the retry is cheap, a map bakes in ~3 s).
# Usage: tools/bake_minimap.sh [all | map00_crossroads[,scrapheap,...]]
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
M="${1:-all}"
if [ "$M" = "all" ]; then
	M=$(timeout 120 "$GODOT" --headless --audio-driver Dummy --path . res://tools_src/bake_minimap.tscn -- --list 2>&1 | grep "bake_minimap. ids" | sed 's/.*ids //' | tr -d '\r')
fi
fails=0
for id in $(echo "$M" | tr ',' ' '); do
	ok=0
	for try in 1 2 3; do
		out=$(timeout 600 "$GODOT" --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/bake_minimap.tscn -- --map="$id" 2>&1)
		echo "$out" | grep "bake_minimap"
		if echo "$out" | grep -q "RESULT PASS"; then ok=1; break; fi
		echo "[bake_minimap] $id: try $try did not finish, retrying"
	done
	[ $ok -eq 1 ] || fails=$((fails + 1))
done
timeout 600 "$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
echo "[bake_minimap] done, $fails map(s) failed"
exit $fails
