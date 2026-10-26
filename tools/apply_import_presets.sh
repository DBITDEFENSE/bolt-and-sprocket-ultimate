#!/usr/bin/env sh
# Writes .import files for the assets under assets/ from assets/import_presets/*.cfg, then runs the editor import so
# the textures (VRAM-compressed, mipmapped) and GLBs (LODs, compression per type) are ready. `*.import` is
# git-ignored here: run this once in every fresh checkout / worktree and after adding assets.
# Usage: tools/apply_import_presets.sh [--force] [--dry-run] [--root=res://assets/third_party] [--no-import]
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
ARGS=""
IMPORT=1
for a in "$@"; do
	case "$a" in
		--no-import) IMPORT=0 ;;
		*) ARGS="$ARGS $a" ;;
	esac
done
"$GODOT" --headless --audio-driver Dummy --path . --script res://tools_src/apply_import_presets.gd -- $ARGS || exit 1
if [ "$IMPORT" = "1" ]; then
	# --import waits for every pending import, so a 2K library doesn't get cut off like --quit-after would.
	"$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
	echo "[presets] editor import done"
fi
