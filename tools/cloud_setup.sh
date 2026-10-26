#!/usr/bin/env bash
# Sets up a Linux box (a Claude Code cloud session, WSL, a container) to build, test and convert assets for this
# project, then runs the tests. Idempotent: safe to run again; it skips what is already in place.
#
#   tools/cloud_setup.sh                 everything: packages, Godot, Blender, Python, import, GUT, every smoke
#   tools/cloud_setup.sh --quick         GUT + a short smoke set (map00, m2, interact, muster) instead of all smokes
#   tools/cloud_setup.sh --no-tests      set up only
#   tools/cloud_setup.sh --no-blender    skip Blender (only needed for asset conversion / tools_src/blender/*)
#   tools/cloud_setup.sh --tts           also the Kokoro neural TTS venv + models (tools/setup_tts.sh; ~350 MB)
#
# Installs into the repo's git-ignored folders: tools/dl_godot/ (Godot 4.7.2 Linux x86_64, the exact version the
# project uses), tools/dl_blender/ (Blender 5.1.2), tools/venv/ (Python packages). System packages (ffmpeg,
# python3, xvfb, mesa, git-lfs...) go through apt when root or passwordless sudo is available; otherwise it says
# what is missing and carries on. Logs: .smoke_logs/cloud/. Exit code: 0 when every test it ran passed.
set -u
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

QUICK=0; TESTS=1; BLENDER_ON=1; TTS=0
for a in "$@"; do
	case "$a" in
		--quick) QUICK=1 ;;
		--no-tests) TESTS=0 ;;
		--no-blender) BLENDER_ON=0 ;;
		--tts) TTS=1 ;;
		-h|--help) sed -n 2,16p "$0"; exit 0 ;;
		*) echo "unknown option $a"; exit 2 ;;
	esac
done

say() { printf '\n[cloud_setup] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

GODOT_VER="4.7.2"
GODOT_ZIP="Godot_v${GODOT_VER}-stable_linux.x86_64.zip"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/${GODOT_ZIP}"
GODOT_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
BLENDER_VER="5.1.2"
BLENDER_TAR="blender-${BLENDER_VER}-linux-x64.tar.xz"
# download.blender.org refuses scripted downloads (403); these are official Blender mirrors
BLENDER_URLS="https://mirrors.ocf.berkeley.edu/blender/release/Blender5.1/${BLENDER_TAR} https://ftp.nluug.nl/pub/graphics/blender/release/Blender5.1/${BLENDER_TAR}"
BLENDER_SHA256="aaccb355f50183979b698bcce7467103a76261b5fa59f4972295842662a285fb"

# ---------------------------------------------------------------- 1. system packages
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
	if have sudo && sudo -n true 2>/dev/null; then SUDO="sudo"; else SUDO="none"; fi
fi
PKGS="git git-lfs curl ca-certificates unzip xz-utils python3 python3-venv python3-pip ffmpeg xvfb xauth libgl1 libglu1-mesa libegl1 libgles2 mesa-vulkan-drivers libxi6 libxrender1 libxkbcommon0 libxkbcommon-x11-0 libxxf86vm1 libxfixes3 libsm6 libfontconfig1 libfreetype6"
missing=""
for p in $PKGS; do dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"; done
if [ -n "$missing" ]; then
	if [ "$SUDO" = "none" ] || ! have apt-get; then
		say "cannot install system packages (no apt / no root). Missing:$missing"
	else
		say "apt-get install:$missing"
		$SUDO apt-get update -qq && DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq --no-install-recommends $missing >/dev/null
	fi
else
	say "system packages already present"
fi

# ---------------------------------------------------------------- 2. LFS files (a fresh clone may hold pointers)
if have git-lfs || git lfs version >/dev/null 2>&1; then
	git lfs install --local >/dev/null 2>&1
	if git lfs ls-files 2>/dev/null | grep -q " - "; then
		say "git lfs pull (some LFS files are still pointer stubs)"
		git lfs pull
	fi
else
	say "WARNING: git-lfs is not installed; models, textures and audio are pointer stubs until it is"
fi

# ---------------------------------------------------------------- 3. Godot 4.7.2 (Linux)
mkdir -p tools/dl_godot
GODOT_BIN="tools/dl_godot/Godot_v${GODOT_VER}-stable_linux.x86_64"
if [ ! -x "$GODOT_BIN" ]; then
	say "downloading Godot ${GODOT_VER}"
	curl -fL --retry 3 -o "tools/dl_godot/${GODOT_ZIP}" "$GODOT_URL" || { echo "Godot download failed"; exit 3; }
	echo "${GODOT_SHA512}  tools/dl_godot/${GODOT_ZIP}" | sha512sum -c - || { echo "Godot checksum mismatch"; exit 3; }
	unzip -o -q "tools/dl_godot/${GODOT_ZIP}" -d tools/dl_godot && rm -f "tools/dl_godot/${GODOT_ZIP}"
	chmod +x "$GODOT_BIN"
fi
"$GODOT_BIN" --version 2>/dev/null | head -1

# ---------------------------------------------------------------- 4. Blender 5.1.2 (Linux)
if [ "$BLENDER_ON" = 1 ]; then
	if [ ! -x tools/dl_blender/blender ]; then
		mkdir -p tools/dl_blender
		ok=0
		for u in $BLENDER_URLS; do
			say "downloading Blender ${BLENDER_VER} from ${u%%/release*}"
			if curl -fL --retry 3 -o "tools/dl_blender/${BLENDER_TAR}" "$u" \
					&& echo "${BLENDER_SHA256}  tools/dl_blender/${BLENDER_TAR}" | sha256sum -c - >/dev/null; then ok=1; break; fi
		done
		if [ "$ok" = 1 ]; then
			tar -xJf "tools/dl_blender/${BLENDER_TAR}" -C tools/dl_blender --strip-components=1 && rm -f "tools/dl_blender/${BLENDER_TAR}"
		else
			# UPDATE 07 (T-102 (14)): the cloud network policy may block every Blender mirror. Fall back to the
			# official `bpy` wheel from PyPI (Blender as a Python module) behind tools/blender_shim.sh, which
			# understands `blender -b --factory-startup -P script.py -- args` (every script in tools_src/blender).
			say "WARNING: Blender download/checksum failed; trying the bpy wheel from PyPI instead"
			[ -x tools/venv/bin/python ] || python3 -m venv tools/venv
			if tools/venv/bin/python -m pip install -q --disable-pip-version-check bpy \
					&& tools/venv/bin/python -c "import bpy" 2>/dev/null; then
				cp tools/blender_shim.sh tools/dl_blender/blender && chmod +x tools/dl_blender/blender
				say "Blender: using the bpy wheel through tools/blender_shim.sh"
			else
				say "WARNING: no Blender and no bpy wheel; asset conversion tools will not run"
			fi
		fi
	fi
	[ -x tools/dl_blender/blender ] && tools/dl_blender/blender -b --factory-startup --version 2>/dev/null | head -1
fi

# ---------------------------------------------------------------- 5. Python packages (tools/*.py)
if have python3; then
	[ -x tools/venv/bin/python ] || python3 -m venv tools/venv
	tools/venv/bin/python -m pip install -q --disable-pip-version-check pillow numpy
	# UPDATE 06 Part B (voice pipeline): PDFs, loudness, audio IO, local Whisper
	tools/venv/bin/python -m pip install -q --disable-pip-version-check reportlab soundfile scipy pyloudnorm pytest faster-whisper || say "WARNING: voice-pipeline packages failed to install"
	if [ "$TTS" = 1 ]; then PY=python3 sh tools/setup_tts.sh; fi
fi

# ---------------------------------------------------------------- 5b. keep Godot out of the tool folders
# Godot scans the whole project folder on import: Blender's own .blend/.tex files under tools/dl_blender make the
# headless --import give up silently (no texture imported, Map 0 never loads), and the bpy wheel (UPDATE 07) is 400 MB
# of files it would try to import. A .gdignore makes Godot skip a folder.
for d in tools/dl_blender tools/dl_godot tools/venv tools/tts tools/node_modules tools_src/_downloads; do
	[ -d "$d" ] && [ ! -f "$d/.gdignore" ] && : > "$d/.gdignore"
done

# ---------------------------------------------------------------- 6. tools/local_paths.env for this machine
cat > tools/local_paths.env <<EOF
# written by tools/cloud_setup.sh (git-ignored); read by tools/env.sh
GODOT=${ROOT}/${GODOT_BIN}
GODOT_W=${ROOT}/${GODOT_BIN}
BLENDER=${ROOT}/tools/dl_blender/blender
PYTHON=${ROOT}/tools/venv/bin/python
EOF
. tools/env.sh

# ---------------------------------------------------------------- 7. import (class cache + every resource)
say "importing the project headless (first run takes several minutes)"
timeout 1800 "$GODOT" --headless --audio-driver Dummy --editor --quit-after 900 --path . >/dev/null 2>&1
timeout 1800 "$GODOT" --headless --audio-driver Dummy --import --path . >/dev/null 2>&1
"$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/check_scripts.gd 2>&1 | tail -1

[ "$TESTS" = 1 ] || { say "setup done (tests skipped)"; exit 0; }

# ---------------------------------------------------------------- 8. tests
LOGS=.smoke_logs/cloud; mkdir -p "$LOGS"
say "GUT unit tests"
timeout 3600 "$GODOT" --headless --audio-driver Dummy --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json > "$LOGS/gut.log" 2>&1
gut=$?
grep -E "^Tests|^Passing|^Failing|^Pending" "$LOGS/gut.log"
say "smoke tests ($([ "$QUICK" = 1 ] && echo quick set || echo all))"
smk=0
if [ "$QUICK" = 1 ]; then
	for f in smoke_map00 smoke_m2 smoke_interact smoke_muster; do sh tools/run_smokes.sh "$LOGS" "$f" || smk=$((smk + $?)); done
else
	sh tools/run_smokes.sh "$LOGS"; smk=$?
fi
say "voice pipeline tests (pytest; Whisper itself skipped unless GRAVELIGHT_WHISPER_MODEL is set)"
if [ -n "${GRAVELIGHT_WHISPER_MODEL:-}" ]; then sh tools/voice.sh test > "$LOGS/voice_pytest.log" 2>&1; vt=$?
else GRAVELIGHT_SKIP_WHISPER=1 sh tools/voice.sh test > "$LOGS/voice_pytest.log" 2>&1; vt=$?; fi
tail -1 "$LOGS/voice_pytest.log"
say "GUT exit $gut, smoke failures $smk, voice tests exit $vt (logs in $LOGS)"
[ "$gut" = 0 ] && [ "$smk" = 0 ] && [ "$vt" = 0 ]
