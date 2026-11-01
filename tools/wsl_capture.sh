#!/usr/bin/env sh
# Morning screenshots through WSL + Xvfb (invisible, software GL). Same scene as tools/capture.sh
# (tools_src/capture.gd) -> morning/screenshots/<milestone>/*.png. Slow: allows up to 1800 s.
# Usage: tools/wsl_capture.sh <milestone> [only=map00,map02] [res=1920x1080]
#   res is the Godot window size (default 1280x720). Example:
#   tools/wsl_capture.sh u09_before only=map00,map01,map02 res=1280x720
cd "$(dirname "$0")/.." || exit 2
[ -n "$1" ] || { echo "usage: tools/wsl_capture.sh <milestone> [only=map00,map02] [res=1920x1080]" >&2; exit 2; }
M="$1"; shift
ONLY=""; RES="1280x720"
for a in "$@"; do
	case "$a" in
		only=*) ONLY="--only=${a#only=}" ;;
		res=*) RES="${a#res=}" ;;
		*) echo "unknown argument: $a" >&2; exit 2 ;;
	esac
done
# shellcheck disable=SC2086
exec sh tools/wsl_godot.sh --res="$RES" --path . res://tools_src/capture.tscn -- --milestone="$M" $ONLY
