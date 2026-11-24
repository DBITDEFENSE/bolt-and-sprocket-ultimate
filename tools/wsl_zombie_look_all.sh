#!/usr/bin/env sh
# T-269: tools/wsl_zombie_look.sh for a list of maps, one render at a time (the WSL VM is shared: several software
# renders at once took the service down on 2026-11-23). Waits until WSL has 8 GB available before each one.
#   tools/wsl_zombie_look_all.sh <tag> "<map ids>" [args passed on, e.g. --zombie-look=off]
cd "$(dirname "$0")/.." || exit 2
TAG="$1"; MAPS="$2"; shift 2
for M in $MAPS; do
	n=0
	while [ $n -lt 40 ]; do
		AV="$(wsl.exe -e bash -lc "free -m | awk '/^Mem:/ {print \$7}'" 2>/dev/null | tr -d '\r\0')"
		case "$AV" in ''|*[!0-9]*) AV=0 ;; esac
		[ "$AV" -ge 8000 ] && break
		n=$((n + 1))
		powershell.exe -NoProfile -Command "Start-Sleep -Seconds 30" >/dev/null 2>&1
	done
	echo "== $TAG $M (WSL available: $AV MB)"
	sh tools/wsl_zombie_look.sh "$TAG" --map="$M" "$@" | grep -E "pictures|ERROR" 
done
