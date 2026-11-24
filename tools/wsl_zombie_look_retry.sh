#!/usr/bin/env sh
# tools/wsl_zombie_look.sh with retries: the WSL service on the owner's PC sometimes refuses a launch
# ("Wsl/Service/E_UNEXPECTED") or drops a run when several workers render at once. Same arguments.
cd "$(dirname "$0")/.." || exit 2
TAG="${1:-after}"
MAP="map00_crossroads"
for a in "$@"; do case "$a" in --map=*) MAP="${a#--map=}" ;; esac; done
LOG="docs/captures/t269/$TAG/$MAP/run.log"
n=0
while [ $n -lt ${ZLOOK_TRIES:-6} ]; do
	n=$((n + 1))
	sh tools/wsl_zombie_look.sh "$@"
	if grep -q "^\[zlook\] [0-9]* pictures" "$LOG" 2>/dev/null; then exit 0; fi
	echo "wsl_zombie_look_retry: try $n did not finish; waiting"
	powershell.exe -NoProfile -Command "Start-Sleep -Seconds 45" >/dev/null 2>&1
done
exit 1
