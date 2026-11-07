#!/usr/bin/env sh
# Voice acting with the cast (UPDATE 06 Part B, T-101; docs/VOICE_ACTING.md). Runs tools/voice/*.py with
# tools/venv's Python (Windows Scripts/python.exe, Linux bin/python; a worktree uses the main checkout's venv).
#   tools/voice.sh scripts [--since=REF] [--actor=ID]   per-actor script PDFs + checklists (voice_scripts/)
#   tools/voice.sh import [--actor=ID] [--dry-run]      voice_inbox/ -> takes -> the game (+ the review page)
#   tools/voice.sh review                               the review page on http://127.0.0.1:8765 (Ctrl+C stops)
#   tools/voice.sh reimport                             Godot headless import so new .ogg files are picked up
#   tools/voice.sh test                                 the pipeline's pytest suite (tests/voice/)
#   tools/voice.sh synthetic                            rebuild the end-to-end test recording (needs Kokoro TTS)
#   tools/voice.sh elevenlabs plan|bake|voices|assign|design|sfx|check   the ElevenLabs voices (docs/VOICES.md)
#   tools/voice.sh bake [...]                           = elevenlabs bake (the default voice bake, U11 T-193)
#   tools/voice.sh plan [...]                           = elevenlabs plan (characters to bake, quota, NEEDS_DEVIN)
# Needs ffmpeg on PATH; packages: reportlab soundfile numpy scipy pyloudnorm pytest elevenlabs python-dotenv
# (+ faster-whisper, found in GRAVELIGHT_WHISPER_PY, ~/whisper-env or tools/venv). First time on a new machine:
#   "$VPY" -m pip install reportlab soundfile numpy scipy pyloudnorm pytest faster-whisper elevenlabs python-dotenv
set -e
cd "$(dirname "$0")/.."
. tools/env.sh
VPY=""
for base in . "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/.."; do
	for rel in tools/venv/Scripts/python.exe tools/venv/bin/python; do
		if [ -z "$VPY" ] && [ -x "$base/$rel" ]; then VPY="$base/$rel"; fi
	done
done
[ -n "$VPY" ] || VPY="$PYTHON"
cmd="${1:-help}"
[ $# -gt 0 ] && shift
case "$cmd" in
	scripts) exec "$VPY" tools/voice/make_scripts.py "$@" ;;
	import) exec "$VPY" tools/voice/import.py "$@" ;;
	review) exec "$VPY" tools/voice/review.py "$@" ;;
	reimport) exec "$GODOT" --headless --audio-driver Dummy --editor --quit-after 900 --path . ;;
	test) exec "$VPY" -m pytest -q -p no:cacheprovider tests/voice "$@" ;;
	synthetic) exec "$VPY" tools/voice/make_synthetic.py "$@" ;;
	elevenlabs) exec "$VPY" tools/voice/eleven.py "$@" ;;
	bake|plan) exec "$VPY" tools/voice/eleven.py "$cmd" "$@" ;;
	*) sed -n '2,17p' "$0" ;;
esac
