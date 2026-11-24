#!/usr/bin/env sh
# T-264: the Linux build (x86_64; this is the SteamOS / handheld build), as a tar.gz.
#   tools/build_linux.sh   -> build/linux/ClaudeZombies_<version>/ClaudeZombies.x86_64 (the pck embedded) and
#                             build/ClaudeZombies_<version>_linux.tar.gz; <version> is project.godot's config/version
# Headless export of the committed "Linux" preset; needs the Godot 4.7.2 export templates (linux_release.x86_64).
# The executable bit: Windows file systems have none, so the archive is written by Python's tarfile with mode 0755
# set on the binary and the start script (a zip made on Windows would lose it). Unpack with `tar xzf`.
# Test without a window (WSL or Linux): ./ClaudeZombies.x86_64 --headless --audio-driver Dummy --quit-after 60
cd "$(dirname "$0")/.."
. tools/env.sh
VER=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot | head -1)
[ -n "$VER" ] || VER=dev
NAME="ClaudeZombies_$VER"
DIR="build/linux/$NAME"
OUT="build/${NAME}_linux.tar.gz"
mkdir -p build/linux
touch build/.gdignore   # the editor must not import what the export writes here
"$PYTHON" -I tools/cinema/archive_reel.py build || echo "[build_linux] the archive-reel build failed: the reels keep their in-engine stand-ins"
rm -rf "$DIR" "$OUT"
mkdir -p "$DIR"
"$GODOT" --headless --audio-driver Dummy --path . --export-release "Linux" "$DIR/ClaudeZombies.x86_64" > build/linux/export.log 2>&1
[ -f "$DIR/ClaudeZombies.x86_64" ] || { echo "[build_linux] export failed (see build/linux/export.log)"; exit 1; }
# the start script: logs next to the game, and "safe" starts the renderer on the game's thread (see docs/u21/t264_ports.md)
cat > "$DIR/start.sh" <<'EOF'
#!/bin/sh
# Starts CLAUDE ZOMBIES. "./start.sh safe" runs the renderer on the game's own thread (if anything looks wrong).
cd "$(dirname "$0")"
RT=""
[ "$1" = "safe" ] && { RT="--render-thread safe"; shift; }
exec ./ClaudeZombies.x86_64 $RT --log-file "$(pwd)/game_last.log" "$@"
EOF
"$PYTHON" -I -c "
import os, sys, tarfile
d, out = sys.argv[1], sys.argv[2]
top = os.path.basename(d)
def fix(ti):
    ti.uid = ti.gid = 0
    ti.uname = ti.gname = ''
    if ti.isdir() or ti.name.endswith('.x86_64') or ti.name.endswith('.sh'):
        ti.mode = 0o755
    else:
        ti.mode = 0o644
    return ti
with tarfile.open(out, 'w:gz', compresslevel=6) as t:
    t.add(d, arcname=top, filter=fix)
with tarfile.open(out) as t:
    for m in t.getmembers():
        print('[build_linux]   %s %s %d' % (oct(m.mode), m.name, m.size))
        if m.name.endswith('.x86_64') or m.name.endswith('.sh'):
            assert m.mode & 0o111, 'the executable bit is missing on ' + m.name
" "$DIR" "$OUT" || exit 1
echo "[build_linux] $DIR/ClaudeZombies.x86_64 $(du -h "$DIR/ClaudeZombies.x86_64" | cut -f1)"
echo "[build_linux] $OUT $(du -h "$OUT" | cut -f1)"
