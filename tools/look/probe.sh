#!/usr/bin/env sh
# UPDATE 12 (T-214): what is under a pixel of a look capture, headless (gravelight/tools_src/look_probe.gd).
#   tools/look/probe.sh --cam=u12_post:map04d_concourse "--px=640,300;100,400" [--n=4]
#   tools/look/probe.sh --map=res://...tscn --find=cloud,vein
cd "$(dirname "$0")/../.."
. tools/env.sh
"$GODOT" --headless --audio-driver Dummy --path . res://gravelight/tools_src/look_probe.tscn -- "$@" 2>&1 | grep "\[probe\]\|SCRIPT ERROR"
