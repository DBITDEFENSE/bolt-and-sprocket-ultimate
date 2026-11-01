#!/usr/bin/env sh
# UPDATE 09 section 2c (T-139): the Windows build, zipped.
#   tools/build_windows.sh   -> build/windows/ClaudeZombies_<version>/ClaudeZombies.exe (the pck embedded, no console
#                               wrapper) and build/ClaudeZombies_<version>.zip; <version> is project.godot's config/version
# Headless export of the committed "Windows Desktop" preset; needs the Godot 4.7.2 export templates
# (windows_release_x86_64.exe). Test the result without a window: ClaudeZombies.exe --headless --quit-after 60
cd "$(dirname "$0")/.."
. tools/env.sh
VER=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot | head -1)
[ -n "$VER" ] || VER=dev
NAME="ClaudeZombies_$VER"
DIR="build/windows/$NAME"
mkdir -p build
touch build/.gdignore   # the editor must not import what the export writes here
rm -rf "$DIR" "build/$NAME.zip"
mkdir -p "$DIR"
"$GODOT" --headless --audio-driver Dummy --path . --export-release "Windows Desktop" "$DIR/ClaudeZombies.exe" > build/windows/export.log 2>&1
[ -f "$DIR/ClaudeZombies.exe" ] || { echo "[build_windows] export failed (see build/windows/export.log)"; exit 1; }
"$PYTHON" -I -c "
import os, sys, zipfile
d, z = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as f:
    for root, _, files in os.walk(d):
        for n in files:
            p = os.path.join(root, n)
            f.write(p, os.path.relpath(p, os.path.dirname(d)))
" "$DIR" "build/$NAME.zip" || exit 1
echo "[build_windows] $DIR/ClaudeZombies.exe $(du -h "$DIR/ClaudeZombies.exe" | cut -f1)"
echo "[build_windows] build/$NAME.zip $(du -h "build/$NAME.zip" | cut -f1)"
