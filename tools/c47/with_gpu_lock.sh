#!/usr/bin/env sh
# UPDATE 12 contract C3: runs a command that opens a rendered Godot window (off-screen, silent: the command's own
# business) while holding the workers' GPU lock (atomic mkdir; waits while someone else holds it).
# Usage: tools/c47/with_gpu_lock.sh <who> <command...>     e.g. tools/c47/with_gpu_lock.sh u12-5-c47 sh tools/bake_minimap.sh map00_crossroads
cd "$(dirname "$0")/../.."
WHO="$1"; shift
L="${GPU_LOCK:-/c/Users/Devin/PROJECTS/bolt-and-sprocket-ultimate/.claude/gpu.lock}"
[ -d "$(dirname "$L")" ] || L=".gpu.lock"
until mkdir "$L" 2>/dev/null; do sleep 20; done
echo "$$ $(date +%T) $WHO" > "$L/owner"
trap 'rm -rf "$L"' EXIT INT TERM
"$@"
RC=$?
rm -rf "$L"
exit $RC
