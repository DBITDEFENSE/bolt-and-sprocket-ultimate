#!/usr/bin/env sh
# UPDATE 12 contract C3: one rendered (windowed) Godot run at a time across every worker. Takes the GPU lock with an
# atomic mkdir (waits while another worker holds it), runs Godot off-screen and silent, releases the lock.
# Usage: tools/c47/gpu_run.sh <who> <timeout_s> <log> <godot args...>
#   e.g. tools/c47/gpu_run.sh u12-5-c47 300 .smoke_logs/u12_5/shots.log res://gravelight/tools_src/shots_c47.tscn -- --out=...
cd "$(dirname "$0")/../.."
. tools/env.sh
WHO="$1"; TO="$2"; LOG="$3"; shift 3
L="${GPU_LOCK:-/c/Users/Devin/PROJECTS/bolt-and-sprocket-ultimate/.claude/gpu.lock}"
[ -d "$(dirname "$L")" ] || L=".gpu.lock"
until mkdir "$L" 2>/dev/null; do sleep 20; done
echo "$$ $(date +%T) $WHO" > "$L/owner"
trap 'rm -rf "$L"' EXIT INT TERM
mkdir -p "$(dirname "$LOG")"
timeout "$TO" "${GPU_GODOT:-$GODOT}" --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . "$@" > "$LOG" 2>&1
RC=$?
rm -rf "$L"
echo "[gpu_run] $WHO exit $RC (log $LOG)"
exit $RC
