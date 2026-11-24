#!/usr/bin/env bash
# T-266: before / after captures of every map's heaviest views in the desktop renderer (Forward+ on lavapipe under
# WSL / Linux + Xvfb, invisible). Each camera of the sets t266_<key> (and t266_<key>_noon on the four maps with the
# day) is shot twice from the one loaded map: T-266's render passes off, then on (tools_src/capture.gd --t266-ab).
#   From Windows:  wsl.exe --cd <worktree> -e bash tools/perf/captures.sh <preset> [keys] [cams per set] [WxH]
#   -> morning/screenshots/t266_<key>[_noon]/<preset>_before/ and .../<preset>/ ; then per set
#      python -I tools/compare_shots.py <preset>_before <preset> --set=t266_<key> --out=docs/captures/t266/<key>_<preset> --jpg
# One software-rendered job at a time (see render_census.sh). A set takes 15 to 30 minutes at 800x450 on High.
set -u
PRESET="${1:-high}"
KEYS="${2:-m00,m01,m02,m04a,m04b,m04c,m04d}"
NCAMS="${3:-4}"
RES="${4:-800x450}"
G="${GODOT_LINUX:-tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64}"
[ -x "$G" ] || G="../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$G" ] || G="../../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$G" ] || { echo "[captures] no Linux Godot (set GODOT_LINUX)"; exit 1; }
mkdir -p .smoke_logs/t266/captures
for k in ${KEYS//,/ }; do
	sets="t266_$k"
	case "$k" in m00|m01|m02|m04a) sets="t266_$k t266_${k}_noon" ;; esac
	for s in $sets; do
		# the first cameras of the set (the first one holds the hour)
		only=$(python3 -c "import json,sys; c=json.load(open('data/gravelight/capture_cams.json'))['sets']['$s']['cams']; print(','.join(x['name'] for x in c[:$NCAMS]))")
		[ -f "morning/screenshots/$s/$PRESET/.done" ] && { echo "[captures] $s $PRESET: done before"; continue; }
		until [ "$(free -m | awk '/^Mem:/ {print $7}')" -gt 8000 ]; do sleep 20; done
		timeout 5400 xvfb-run -a -s "-screen 0 1920x1080x24" "$G" --rendering-driver vulkan --audio-driver Dummy --resolution "$RES" --path . \
			res://tools_src/capture.tscn -- --set="$s" --label="$PRESET" --preset="$PRESET" --only="$only" --frames=4 --t266-ab > ".smoke_logs/t266/captures/${s}_$PRESET.log" 2>&1
		n=$(grep -c '^\[capture\] /' ".smoke_logs/t266/captures/${s}_$PRESET.log")
		echo "[captures] $s $PRESET: $n shots, $(grep -c 'SCRIPT ERROR' ".smoke_logs/t266/captures/${s}_$PRESET.log") script errors"
		[ "$n" -gt 0 ] && touch "morning/screenshots/$s/$PRESET/.done"
	done
done
