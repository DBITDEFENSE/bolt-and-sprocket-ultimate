#!/usr/bin/env sh
# The AI soak test (Update 03 sections 0 and 9): headless, silent, as fast as the CPU allows. Writes a CSV per
# run, a summary CSV per scenario and a markdown table per batch to logs/ai_runs/ (git-ignored).
# Usage: tools/ai_soak.sh --scenario=bots3|cousins|kaltenbrunn|totenhafen|ee_full|botmode|fernflug [--runs=3] [--seed=1]
#                        [--max-round=N] [--speed=1] [--skill=recruit|veteran|elite] [--max-minutes=150] [--loco=v1|v2]
#                        [--trace=N (a status line per bot every N s)] [--orders=N (a wheel order every N s)]
#                        [--ee=off|ask|full (Bot Easter-Egg Help; ee_full: the bots on Map 0's radio egg, T-067)]
#                        fernflug (UPDATE 07, T-116: Map 4 as one campaign run, Act I to an ending): [--bots-alone]
#                        [--skip-to-act=2|3|4] [--egg=off|ask|full] [--max-minutes=240]; per-act rows in the batch .md
#                        --until-egg (U08: end a run when the map's main egg completes; prints EGG lines and EGG RATE)
#                        --egg-mode=off|sparse|none (T-181 Easter Egg Mode: few crawlers / no zombies, practice)
# The Godot tool itself is res://tools_src/ai_soak.tscn (docs/BOT_AI.md explains the scenarios and the metrics).
cd "$(dirname "$0")/.."
. tools/env.sh   # GODOT / GODOT_W / BLENDER / PYTHON per OS (tools/local_paths.env overrides)
exec "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/ai_soak.tscn -- "$@"
