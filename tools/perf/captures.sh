#!/usr/bin/env bash
# T-266: before / after captures of every map's heaviest views in the desktop renderer (Forward+ on lavapipe under
# WSL / Linux + Xvfb, invisible). Each camera of the sets t266_<key> (and t266_<key>_noon on the four maps with the
# day) is shot twice from the one loaded map: T-266's render passes off, then on (tools_src/capture.gd --t266-ab).
#   From Windows:  wsl.exe --cd <worktree> -e bash tools/perf/captures.sh <preset> [keys] [cams per set] [WxH]
#   -> morning/screenshots/t266_<key>[_noon]/<preset>_before/ and .../<preset>/ ; then per set
#      python -I tools/perf/shot_diff.py <.../preset_before> <.../preset> --sheet=docs/captures/t266/<key>_<preset>.jpg
# One software-rendered job at a time (see render_census.sh). A set takes 15 to 30 minutes at 800x450 on High.
# Env: T266_DRIVER=opengl3 shoots in the Compatibility renderer instead (minutes, not a quarter of an hour: enough to
# see what occlusion culling hides, which is the same in both renderers; the lamps and shadows are the browser
# profile's there), saved under <preset>_gl/ and <preset>_gl_before/; T266_NOON=0 leaves the noon sets out.
set -u
PRESET="${1:-high}"
KEYS="${2:-m00,m01,m02,m04a,m04b,m04c,m04d}"
NCAMS="${3:-4}"
RES="${4:-800x450}"
DRIVER="${T266_DRIVER:-vulkan}"
LABEL="$PRESET"
[ "$DRIVER" = "vulkan" ] || LABEL="${PRESET}_gl"
G="${GODOT_LINUX:-tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64}"
[ -x "$G" ] || G="../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$G" ] || G="../../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$G" ] || { echo "[captures] no Linux Godot (set GODOT_LINUX)"; exit 1; }
mkdir -p .smoke_logs/t266/captures
for k in ${KEYS//,/ }; do
	sets="t266_$k"
	if [ "${T266_NOON:-1}" = "1" ]; then
		case "$k" in m00|m01|m02|m04a) sets="t266_$k t266_${k}_noon" ;; esac
	fi
	for s in $sets; do
		# the first cameras of the set (the first one holds the hour)
		only=$(python3 -c "import json,sys; c=json.load(open('data/gravelight/capture_cams.json'))['sets']['$s']['cams']; print(','.join(x['name'] for x in c[:$NCAMS]))")
		[ -f "morning/screenshots/$s/$LABEL/.done" ] && { echo "[captures] $s $LABEL: done before"; continue; }
		until [ "$(free -m | awk '/^Mem:/ {print $7}')" -gt 8000 ]; do sleep 20; done
		log=".smoke_logs/t266/captures/${s}_$LABEL.log"
		timeout 5400 xvfb-run -a -s "-screen 0 1920x1080x24" "$G" --rendering-driver "$DRIVER" --audio-driver Dummy --resolution "$RES" --path . \
			res://tools_src/capture.tscn -- --set="$s" --label="$LABEL" --preset="$PRESET" --only="$only" --frames=4 --t266-ab > "$log" 2>&1
		n=$(grep -c '^\[capture\] /' "$log")
		echo "[captures] $s $LABEL: $n shots, $(grep -c 'SCRIPT ERROR' "$log") script errors"
		[ "$n" -gt 0 ] && touch "morning/screenshots/$s/$LABEL/.done"
	done
done
