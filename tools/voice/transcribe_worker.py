#!/usr/bin/env python3
"""Whisper transcription worker for tools/voice/pipeline.py (T-101). Runs under whichever Python has faster-whisper
(the owner's existing ~/whisper-env on the PC, or tools/venv in the cloud), so it imports nothing from the project.

  python transcribe_worker.py jobs.json
jobs.json: {"model": "large-v3", "device": "auto", "jobs": [{"wav": in.wav, "out": out.json}, ...]}
Each out.json: {"model", "language", "duration", "words": [{"w", "s", "e", "p"}], "segments": [{"s", "e", "text"}]}
"""
import glob
import json
import os
import sys


def _cuda_dlls() -> None:
    # pip's nvidia-cublas / cudnn wheels put their DLLs in site-packages/nvidia/*/bin, which Windows doesn't search
    if os.name != "nt":
        return
    for sp in sys.path:
        for b in glob.glob(os.path.join(sp, "nvidia", "*", "bin")):
            try:
                os.add_dll_directory(b)
            except OSError:
                pass
            os.environ["PATH"] = b + os.pathsep + os.environ.get("PATH", "")


def main() -> int:
    with open(sys.argv[1], encoding="utf-8") as f:
        cfg = json.load(f)
    _cuda_dlls()
    from faster_whisper import WhisperModel
    model_name = cfg.get("model", "medium")
    device = cfg.get("device", "auto")
    model = None
    tried = []
    for dev, ct in ([("cuda", "float16"), ("cpu", "int8")] if device == "auto" else [(device, "float16" if device == "cuda" else "int8")]):
        try:
            model = WhisperModel(model_name, device=dev, compute_type=ct)
            # a CUDA build without the runtime libraries only fails at the first encode: probe it
            if dev == "cuda":
                import numpy as np
                list(model.transcribe(np.zeros(16000, dtype="float32"), language="en")[0])
            device_used = dev
            break
        except Exception as e:  # noqa: BLE001
            tried.append("%s: %s" % (dev, e))
            model = None
    if model is None:
        print("could not load whisper model %s: %s" % (model_name, "; ".join(tried)))
        return 2
    prompt = cfg.get("prompt", "")
    for job in cfg["jobs"]:
        segs, info = model.transcribe(job["wav"], language=cfg.get("language", "en"), word_timestamps=True,
                                      vad_filter=False, condition_on_previous_text=False, beam_size=5,
                                      initial_prompt=prompt or None)
        words, segments = [], []
        for s in segs:
            segments.append({"s": round(s.start, 3), "e": round(s.end, 3), "text": s.text.strip()})
            for w in (s.words or []):
                words.append({"w": w.word.strip(), "s": round(float(w.start), 3), "e": round(float(w.end), 3),
                              "p": round(float(w.probability), 3)})
        out = {"model": model_name, "device": device_used, "language": info.language,
               "duration": round(float(info.duration), 3), "words": words, "segments": segments}
        with open(job["out"], "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False)
        print("transcribed %s (%d words)" % (os.path.basename(job["wav"]), len(words)), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
