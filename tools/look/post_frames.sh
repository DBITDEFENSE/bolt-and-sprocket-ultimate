#!/usr/bin/env sh
# UPDATE 12 section 2 (T-208): before / after captures of the post stack and the material pass on every map and act.
# Renders, off-screen and silent, the u12_look set (one establishing frame per map + the menu), the u12_post set (one
# more camera per map: an interior under the practicals, Groom Lake's crater) and the readability frames (u05
# close_zombie: a risen Ganger at 3.4 m; u05_objects perk_dark (shot first: the opening card), ammo_box, wall_buy_close), once with
# --look=off (the U11 game: no grade, no post block, no material pass, no night lights) and once as shipped, then
# files them as docs/look/post/<name>_before|after.jpg + sheet.jpg (tools/look/post_frames.py).
# One GPU run at a time across the workers (U12 contract C3): the .claude/gpu.lock mkdir lock.
# Usage: tools/look/post_frames.sh [out_dir] [before|after|both] [only=name,name]
#   only= (or the ONLY environment variable) shoots just those cameras (T-214: re-shoot what a fix touched; the
#   sheet is rebuilt from every pair in out_dir).
cd "$(dirname "$0")/../.."
. tools/env.sh
OUT="${1:-docs/look/post}"
case "$OUT" in /*|[A-Za-z]:*) ;; *) OUT="$(pwd)/$OUT" ;; esac
WHICH="${2:-both}"
case "${3:-}" in only=*) ONLY="${3#only=}" ;; esac
ONLY="${ONLY:-}"
L="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/../.claude/gpu.lock"
[ -d "$(dirname "$L")" ] || L=".claude/gpu.lock"
until mkdir "$L" 2>/dev/null; do sleep 20; done
echo "$$ $(date +%T) u12-2-post post_frames" > "$L/owner"
trap 'rm -rf "$L"' EXIT INT TERM
shoot() {   # $1 label, $2 extra arg
	D="$OUT/_$1"
	rm -rf "$D"
	mkdir -p "$D"
	for spec in "u12_look:" "u12_post:" "u05:close_zombie" "u05_objects:perk_dark,ammo_box,wall_buy_close"; do
		set_name="${spec%%:*}"
		only="${spec#*:}"
		if [ -n "$ONLY" ]; then
			# the cameras of this set that are asked for (none: skip the set)
			only="$("$PYTHON" -I -c "import json,sys; s=json.load(open('data/gravelight/capture_cams.json'))['sets'][sys.argv[1]]; d=sys.argv[2].split(',') if sys.argv[2] else [c.get('name') for c in s['cams']]; print(','.join(n for n in sys.argv[3].split(',') if n in d))" "$set_name" "$only" "$ONLY")"
			[ -z "$only" ] && continue
		fi
		[ -n "$only" ] && only="--only=$only"
		timeout 900 "$GODOT" --audio-driver Dummy --windowed --position -4000,-4000 --resolution 1280x720 --path . \
			res://tools_src/capture.tscn -- --set="$set_name" --out="$D" $only $2
	done
}
if [ "$WHICH" = "both" ] || [ "$WHICH" = "before" ]; then shoot before --look=off; fi
if [ "$WHICH" = "both" ] || [ "$WHICH" = "after" ]; then shoot after ""; fi
rm -rf "$L"
trap - EXIT INT TERM
"$PYTHON" -I tools/look/post_frames.py "$OUT"
