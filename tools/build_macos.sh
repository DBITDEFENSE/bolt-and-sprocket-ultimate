#!/usr/bin/env sh
# T-264: the macOS build (universal: Apple silicon + Intel), an ad-hoc-signed .app in a zip.
#   tools/build_macos.sh   -> build/ClaudeZombies_<version>_macos.zip (holds "CLAUDE ZOMBIES.app"); <version> is
#                             project.godot's config/version
# Headless export of the committed "macOS" preset; needs the Godot 4.7.2 export templates (macos.zip) and the
# project setting rendering/textures/vram_compression/import_etc2_astc (Apple silicon's texture formats).
# Signing: Godot's built-in ad-hoc signature (codesign/codesign=1), the only kind possible without an Apple
# developer certificate; not notarized, so a downloaded copy is stopped by Gatekeeper until the quarantine flag is
# cleared (docs/u21/t264_ports.md has the steps). The zip is written by Godot itself and keeps the executable bit;
# do NOT unzip and re-zip it on Windows (that loses the bit and breaks the signature's seal).
# It cannot be run or tested on this PC: tools/check_macos_build.py reads the archive instead.
cd "$(dirname "$0")/.."
. tools/env.sh
VER=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot | head -1)
[ -n "$VER" ] || VER=dev
OUT="build/ClaudeZombies_${VER}_macos.zip"
mkdir -p build/macos
touch build/.gdignore   # the editor must not import what the export writes here
"$PYTHON" -I tools/cinema/archive_reel.py build || echo "[build_macos] the archive-reel build failed: the reels keep their in-engine stand-ins"
rm -f "$OUT"
"$GODOT" --headless --audio-driver Dummy --path . --export-release "macOS" "$OUT" > build/macos/export.log 2>&1
[ -f "$OUT" ] || { echo "[build_macos] export failed (see build/macos/export.log)"; exit 1; }
"$PYTHON" -I tools/check_macos_build.py "$OUT" || { echo "[build_macos] the archive check found problems"; exit 1; }
echo "[build_macos] $OUT $(du -h "$OUT" | cut -f1)"
