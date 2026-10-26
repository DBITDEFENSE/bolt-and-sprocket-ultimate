#!/usr/bin/env sh
# Shared tool paths for every tools/*.sh script (source it after `cd` to the repo root: `. tools/env.sh`).
# Order: a value already in the environment wins; then tools/local_paths.env (git-ignored, one KEY=value per
# line, for machine-specific paths); then the per-OS default below. Windows (Git Bash) defaults are the paths
# this project has always used; Linux defaults are where tools/cloud_setup.sh installs things.
#   GODOT    the Godot 4.7.2 console/headless binary
#   GODOT_W  the windowed Godot binary (rendered tools); Linux uses the same binary under Xvfb
#   BLENDER  Blender 5.1 (asset conversion)
#   PYTHON   Python 3

if [ -f tools/local_paths.env ]; then
	while IFS='=' read -r _k _v; do
		case "$_k" in ''|\#*) continue ;; esac
		eval "_cur=\${$_k:-}"
		[ -z "$_cur" ] && export "$_k=$_v"
	done < tools/local_paths.env
fi

case "$(uname -s 2>/dev/null)" in
	MINGW*|MSYS*|CYGWIN*)
		: "${GODOT:=tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe}"
		: "${GODOT_W:=tools/dl_godot/Godot_v4.7.2-stable_win64.exe}"
		: "${BLENDER:=/c/Program Files/Blender Foundation/Blender 5.1/blender.exe}"
		: "${PYTHON:=python}"
		;;
	*)
		: "${GODOT:=tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64}"
		: "${GODOT_W:=$GODOT}"
		: "${BLENDER:=tools/dl_blender/blender}"
		: "${PYTHON:=python3}"
		;;
esac
# a worktree (.wt/<branch>) has no tools/dl_godot of its own: fall back to the main checkout's
if [ ! -x "$GODOT" ] && command -v git >/dev/null 2>&1; then
	_main="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/.."
	[ -x "$_main/$GODOT" ] && GODOT="$_main/$GODOT"
	[ -x "$_main/$GODOT_W" ] && GODOT_W="$_main/$GODOT_W"
fi
export GODOT GODOT_W BLENDER PYTHON
