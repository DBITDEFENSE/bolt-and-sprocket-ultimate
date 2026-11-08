#!/usr/bin/env sh
# Runs the project's Blender (tools/env.sh's BLENDER) headless with the given arguments (T-211 C-47 pipeline).
# Usage: tools/c47/blender.sh -P <script.py> -- <args>
cd "$(dirname "$0")/../.."
. tools/env.sh
exec "$BLENDER" -b --factory-startup "$@"
