#!/usr/bin/env bash
# T-266: the rendered census of every map's heaviest views (capture sets t266_<key>, tools/perf/pick_views.py), on
# presets low and high, at night and (the four maps with the day) at noon, invisibly under WSL / Linux + Xvfb
# (Forward+ on lavapipe, perf_marks --views --quick --cheap: counts are exact, times mean nothing). Every view is
# counted with T-266's render passes off ("before") and then switched on step by step, from the one loaded map
# (perf_marks --t266-ab), so one run gives the before / after table and what each pass bought.
#   From Windows:  wsl.exe --cd <worktree> -e bash tools/perf/render_census.sh <label> [maps] [presets] [views per map] [extra flags]
#   -> .smoke_logs/t266/<label>/<map>_<preset>.log ; then  python -I tools/perf/census_table.py .smoke_logs/t266/<label>
# One software-rendered job at a time, and only with 8 GB free: a High map takes 11 GB there, and several at once
# took the whole WSL VM down (2026-11-23). A map takes 20 to 50 minutes.
set -u
LABEL="${1:-now}"
MAPS="${2:-map00_crossroads,map01_kaltenbrunn,map02_totenhafen,map04a_thalbach,map04b_kranich,map04c_groomlake,map04d_mondlicht}"
PRESETS="${3:-high,low}"
NVIEWS="${4:-4}"
shift 4 2>/dev/null || shift $#
EXTRA="$*"
G="${GODOT_LINUX:-tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64}"
[ -x "$G" ] || G="../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$G" ] || G="../../../tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64"
[ -x "$G" ] || { echo "[render_census] no Linux Godot (set GODOT_LINUX)"; exit 1; }
OUT=".smoke_logs/t266/$LABEL"
mkdir -p "$OUT"
for m in ${MAPS//,/ }; do
	for p in ${PRESETS//,/ }; do
		case "$m" in
			map00_crossroads) k=m00; h="--hours=0,12" ;;
			map01_kaltenbrunn) k=m01; h="--hours=0,12" ;;
			map02_totenhafen) k=m02; h="--hours=0,12" ;;
			map04a_thalbach) k=m04a; h="--hours=0,12" ;;
			map04b_kranich) k=m04b; h="" ;;
			map04c_groomlake) k=m04c; h="" ;;
			*) k=m04d; h="" ;;
		esac
		# what a pass changes is apart by counter (proxies / props / sun: shadow draws; occlusion: colour draws; lights:
		# lamps in view), so Low needs no step of its own for each of the last three; on High only the first two act
		if [ "$p" = "high" ] || [ "$p" = "ultra" ]; then steps="proxies:props+occlusion+sun+lights"; else steps="proxies:props:occlusion+sun+lights"; fi
		[ -s "$OUT/${m}_$p.log" ] && grep -q "active zombies" "$OUT/${m}_$p.log" && { echo "[render_census] $m $p: done before"; continue; }
		until [ "$(free -m | awk '/^Mem:/ {print $7}')" -gt 8000 ]; do sleep 20; done
		timeout 5400 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --rendering-driver vulkan --audio-driver Dummy --resolution 1280x720 --path . \
			res://gravelight/tools_src/perf_marks.tscn -- --map="$m" --preset="$p" --quick --cheap --views="t266_$k" --views-max="$NVIEWS" $h --t266-ab="$steps" $EXTRA > "$OUT/${m}_$p.log" 2>&1
		echo "[render_census] $m $p: $(grep -c '^\[view\] map' "$OUT/${m}_$p.log") view lines, $(grep -c 'SCRIPT ERROR' "$OUT/${m}_$p.log") script errors"
	done
done
