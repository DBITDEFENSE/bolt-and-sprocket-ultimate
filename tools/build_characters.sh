#!/usr/bin/env sh
# Rebuilds the character GLBs + skin textures in Blender (headless), then writes their .import files from the
# presets and imports them (T-091, docs/CHARACTER_PIPELINE.md).
# Usage: tools/build_characters.sh [--living] [--only=m_medium,f_thin] [--no-textures]
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.1/blender.exe}"
GODOT="${GODOT:-tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe}"
"$BLENDER" -b --factory-startup -P tools_src/blender/characters/build_all.py -- "$@" 2>&1 | grep -E "\[build_all\]|\[make_textures\]|Error|Traceback" || exit 1
# the editor's md5 check missed rebuilt GLBs after the preset pass: drop their cached imports so they re-import
rm -f .godot/imported/char_zombie_base_* .godot/imported/char_human_base_* .godot/imported/tex_zombie_skin_* .godot/imported/tex_human_skin_*
"$GODOT" --headless --audio-driver Dummy --path . --script res://tools_src/apply_import_presets.gd -- --root=res://assets/ours > /dev/null 2>&1
"$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
"$GODOT" --headless --audio-driver Dummy --import --path . > /dev/null 2>&1
echo "[characters] import done"
