#!/usr/bin/env bash
# One-time setup of the offline neural voice engine for the GRAVELIGHT VO bake (T-073):
#   tools/venv/        a project-local Python venv: kokoro-onnx (MIT), onnxruntime (MIT), misaki (Apache-2.0, the
#                      lexicons only; installed without spaCy), espeakng-loader (eSpeak NG, GPL-3.0: a build tool,
#                      nothing of it ships with the game), phonemizer-fork, numpy, scipy, soundfile, regex, num2words
#   tools/tts/kokoro/  Kokoro-82M v1.0 ONNX weights + voice styles (Apache-2.0), from the kokoro-onnx releases
# Nothing is installed system-wide; no admin; the bake itself runs offline. Both folders are git-ignored.
# A git worktree can skip this: gen_vo.py also looks in the main checkout's tools/.
#
# Usage: tools/setup_tts.sh            (from the repo root; re-running skips what is already there)
#        PYTHON=py tools/setup_tts.sh  (pick the interpreter that creates the venv; 3.12+ tested on 3.14)
set -euo pipefail
cd "$(dirname "$0")/.."
PY="${PYTHON:-python}"
MODEL_DIR="tools/tts/kokoro"
REL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"

mkdir -p "$MODEL_DIR"
for f in kokoro-v1.0.onnx voices-v1.0.bin; do
	if [ ! -s "$MODEL_DIR/$f" ]; then
		echo "downloading $f ..."
		curl -fL --retry 3 -o "$MODEL_DIR/$f.part" "$REL/$f"
		mv "$MODEL_DIR/$f.part" "$MODEL_DIR/$f"
	fi
done

if [ ! -d tools/venv ]; then
	echo "creating tools/venv ..."
	"$PY" -m venv tools/venv
fi
VPY="tools/venv/Scripts/python.exe"
[ -x "$VPY" ] || VPY="tools/venv/bin/python"
"$VPY" -m pip install -q --disable-pip-version-check numpy scipy soundfile regex num2words kokoro-onnx
# misaki's English module imports spaCy only for tagging; gen_vo_neural.py tokenizes without it.
"$VPY" -m pip install -q --disable-pip-version-check --no-deps misaki
"$VPY" -c "import kokoro_onnx, misaki, espeakng_loader, onnxruntime; print('neural TTS ready:', onnxruntime.__version__)"
