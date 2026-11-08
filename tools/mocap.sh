#!/usr/bin/env sh
# Phone motion capture + lip sync for the in-engine cutscenes (UPDATE 12 section 4, T-210; docs/MOCAP_GUIDE.md).
#   tools/mocap.sh report [--json]          what is in assets/user_supplied/mocap/ and what is missing, per scene
#   tools/mocap.sh build [--scene=ID]       captures -> assets/ours/mocap/<scene>/mocap_<scene>.res (Blender for FBX)
#   tools/mocap.sh guide                    rewrites docs/MOCAP_GUIDE.md's shot tables from data/gravelight/mocap/shots.json
#   tools/mocap.sh lipsync [--all|--ids=]   Rhubarb mouth cues -> data/gravelight/vo/lipsync/<ID>.json
#   tools/mocap.sh sample                   rewrites the synthetic test clip (tests/data/mocap/sample_walk.bvh)
#   tools/mocap.sh test                     the pipeline's pytest suite (tests/mocap/)
# Python: tools/venv's (a worktree uses the main checkout's), else $PYTHON; needs numpy (+ soundfile for lipsync).
set -e
cd "$(dirname "$0")/.."
. tools/env.sh
VPY=""
for base in . "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/.."; do
	for rel in tools/venv/Scripts/python.exe tools/venv/bin/python; do
		if [ -z "$VPY" ] && [ -x "$base/$rel" ]; then VPY="$base/$rel"; fi
	done
done
[ -n "$VPY" ] || VPY="$PYTHON"
export GODOT BLENDER
cmd="${1:-help}"
[ $# -gt 0 ] && shift
case "$cmd" in
	report|build|guide|sample) exec "$VPY" tools/mocap/mocap.py "$cmd" "$@" ;;
	lipsync) exec "$VPY" tools/mocap/lipsync.py "$@" ;;
	test) exec "$VPY" -m pytest -q tests/mocap "$@" ;;
	*) sed -n '2,9p' "$0" ;;
esac
