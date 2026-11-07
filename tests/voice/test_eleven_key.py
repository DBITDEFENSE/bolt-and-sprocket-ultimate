"""U11 T-193: the ElevenLabs key is never written to disk. The test loads the key itself the way the tools do (the
environment, else the ignored .env.local of this or the main checkout), keeps it in an object that never prints, and
scans every tracked file and every log / cache file the voice tools write for it, and for anything key-shaped
("sk_" + 40 or more hex digits, the ElevenLabs key format). It passes without a key too (the pattern scan still runs).
A failure names the files, never the key."""
import glob
import os
import re
import subprocess

import eleven as E
import voicelib as V

MEDIA = {".png", ".jpg", ".jpeg", ".webp", ".ogg", ".wav", ".mp3", ".flac", ".glb", ".gltf", ".bin", ".fbx", ".blend",
         ".exr", ".hdr", ".tga", ".psd", ".ttf", ".otf", ".woff", ".woff2", ".mp4", ".webm", ".pck", ".zip", ".ktx",
         ".svgz", ".dds", ".pdf", ".ico", ".icns", ".res", ".scn", ".mesh", ".anim"}
KEY_SHAPE = re.compile(rb"sk_[0-9a-f]{40,}")


class Secret:
    def __init__(self, s: str):
        self._b = s.encode("utf-8") if s else b""

    def __bool__(self):
        return bool(self._b)

    def found_in(self, data: bytes) -> bool:
        return bool(self._b) and self._b in data

    def __repr__(self):
        return "<the key, redacted>"

    __str__ = __repr__


def _tracked(root: str) -> list[str]:
    cp = subprocess.run(["git", "-C", root, "ls-files", "-z"], capture_output=True)
    return [os.path.join(root, f) for f in cp.stdout.decode("utf-8", "replace").split("\0") if f]


def _tool_outputs(roots: list[str]) -> list[str]:
    out = []
    for r in roots:
        for pat in ("logs/**/*", ".smoke_logs/**/*", "voice_review/**/*.html", "voice_review/**/*.json",
                    "voice_work/**/*.json", ".voice_cache/**/*.json", ".voice_cache/**/*.log"):
            out += [p for p in glob.glob(os.path.join(r, pat), recursive=True) if os.path.isfile(p)]
    return out


def test_key_is_never_on_disk(monkeypatch):
    monkeypatch.setenv("GL_ELEVEN_KEYFILES", "1")        # this test, and only this one, reads the real key
    monkeypatch.delenv("ELEVENLABS_API_KEY", raising=False)
    key = Secret(E.load_key())
    roots = sorted({V.ROOT, E.main_checkout()})
    files = _tracked(V.ROOT) + _tool_outputs(roots)
    assert len(files) > 1000
    hits = []
    for p in files:
        if os.path.splitext(p)[1].lower() in MEDIA or not os.path.isfile(p) or os.path.getsize(p) > 16 << 20:
            continue
        if os.path.basename(p) == ".env.local":
            continue                                    # the one place the key is allowed (ignored, never tracked)
        with open(p, "rb") as f:
            data = f.read()
        if key.found_in(data) or KEY_SHAPE.search(data):
            hits.append(os.path.relpath(p, V.ROOT))
    assert not hits, "the key (or something key-shaped) is on disk in: %s" % hits


def test_env_local_is_ignored():
    cp = subprocess.run(["git", "-C", V.ROOT, "check-ignore", "-q", ".env.local"])
    assert cp.returncode == 0, ".env.local must be git-ignored"
    cp = subprocess.run(["git", "-C", V.ROOT, "check-ignore", "-q", ".voice_cache/eleven/x.json"])
    assert cp.returncode == 0, "the take cache must be git-ignored"
