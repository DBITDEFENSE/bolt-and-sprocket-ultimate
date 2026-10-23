#!/usr/bin/env sh
# The AI soak test (Update 03 sections 0 and 9): headless, silent, as fast as the CPU allows. Writes a CSV per
# run, a summary CSV per scenario and a markdown table per batch to logs/ai_runs/ (git-ignored).
# Usage: tools/ai_soak.sh --scenario=player3|bots3|cousins|kaltenbrunn|ee_full [--runs=3] [--seed=1] [--max-round=N]
#                        [--speed=1] [--skill=recruit|veteran|elite] [--max-minutes=150] [--loco=v1|v2]
#                        [--trace=N (a status line per bot every N s)] [--orders=N (a wheel order every N s)]
#                        [--ee=off|ask|full (Bot Easter-Egg Help; ee_full: the bots on Map 0's radio egg, T-067)]
# The Godot tool itself is res://tools_src/ai_soak.tscn (docs/BOT_AI.md explains the scenarios and the metrics).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe}"
exec "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/ai_soak.tscn -- "$@"
