#!/usr/bin/env python3
"""T-285: write build/trailers/README.txt (the shot lists, the prompts, the credits, the licences) and
build/trailers/SOURCE.txt (where every sound and picture came from) from the edits and the prompt file."""
import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
B = os.path.join(ROOT, "build", "trailers")


def dur(p):
    try:
        return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p],
                                    capture_output=True, text=True).stdout.strip())
    except Exception:
        return 0.0


def shot_list(edit_json):
    d = json.load(open(edit_json))
    out = []
    t = 0.0
    for s in d["segments"]:
        what = os.path.basename(s.get("src") or s.get("card") or "?")
        extra = ""
        if s.get("overlay"):
            extra = "  + card " + os.path.basename(s["overlay"])
        out.append("  %6.2f  %5.2f s  %s%s" % (t, float(s["dur"]), what, extra))
        t += float(s["dur"])
    return out


def main():
    P = json.load(open(os.path.join(HERE, "teaser_prompts.json"), encoding="utf-8"))
    L = []
    L.append("T-285 TRAILERS (GRAVELIGHT), made 2026-11-26. Not in git (build/ is ignored); tooling and notes: tools/trailer/, docs/trailers/t285_trailers.md")
    L.append("")
    for name in ("teaser", "gameplay"):
        f = os.path.join(B, name + "_1080p.mp4")
        L.append("%s_1080p.mp4  %.2f s   %s_720p.mp4  %.2f s" % (name, dur(f), name, dur(os.path.join(B, name + "_720p.mp4"))))
    L.append("Both H.264 (High) + AAC, 24 fps; 1080p at CRF 17 / AAC 256k, 720p at CRF 19 / AAC 192k.")
    L.append("")
    L.append("== TEASER: shot list (start, length, clip) ==")
    if os.path.exists(os.path.join(B, "teaser_edit.json")):
        L += shot_list(os.path.join(B, "teaser_edit.json"))
    L.append("")
    L.append("Teaser clips (build/trailers/hf/): a clip named <shot>_v2.mp4 is the text-to-video take that replaced the")
    L.append("video_edit take; <shot>_omni.mp4 are rejected omni_reference takes; <shot>_cmp.jpg compare source (top) and take (bottom).")
    L.append("In-engine sources: build/trailers/src/teaser_m0/<shot>.mp4 (12 fps, 1280x720).")
    L.append("")
    L.append("== TEASER: prompts ==")
    L.append("video_edit wrapper: " + P["wrapper"])
    L.append("video_edit rules: " + P["rules"] + P.get("clothing_rule", ""))
    for k, v in P["shots"].items():
        L.append("  [video_edit] %s: %s" % (k, v))
    L.append("omni_reference wrapper: " + P.get("omni_wrapper", ""))
    for k, v in P.get("omni", {}).items():
        L.append("  [omni, rejected] %s: %s" % (k, v))
    for k, v in P.get("t2v", {}).items():
        if not k.startswith("_"):
            L.append("  [t2v] %s: %s" % (k, v))
    L.append("Used: " + json.dumps(P.get("used", {})))
    L.append("")
    L.append("== GAMEPLAY: shot list ==")
    if os.path.exists(os.path.join(B, "gameplay_edit.json")):
        L += shot_list(os.path.join(B, "gameplay_edit.json"))
    L.append("In-engine sources: build/trailers/src/game_m0|game_m1|game_m2|game_m4b|game_m4d/<shot>.mp4 (24 fps, 1920x1080,")
    L.append("WSL Xvfb, Forward+ on lavapipe, the Low preset at full scale); the shot definitions are gravelight/tools_src/trailer_shots.json.")
    L.append("")
    L.append("== HIGGSFIELD CREDITS ==")
    jobs = os.path.join(B, "hf", "jobs.txt")
    if os.path.exists(jobs):
        L += ["  " + ln.rstrip() for ln in open(jobs)]
    L.append(open(os.path.join(B, "credits.txt")).read().strip() if os.path.exists(os.path.join(B, "credits.txt")) else "")
    L.append("")
    L.append("== LICENCES ==")
    L.append("Pictures: the game's own in-engine renders (our work); Higgsfield Seedance 2.5 outputs generated on the owner's")
    L.append("account (the plan's commercial terms as for T-209/T-277: development and private use until the owner checks them).")
    L.append("Type: Stardos Stencil Bold and Special Elite (SIL Open Font License, assets/third_party/google_fonts).")
    L.append("Sound: see SOURCE.txt (all synthesized in-house or the game's own in-house sound files; no third-party audio).")
    open(os.path.join(B, "README.txt"), "w", encoding="utf-8").write("\n".join(L) + "\n")
    S = [
        "T-285 trailer sound and music: where it came from",
        "",
        "Score and sound design: synthesized by tools/trailer/trailer_audio.py with the game's own DSP core",
        "(gravelight/tools_src/gen_audio.py: oscillators, formant voices for the Ganger groans and the scream, noise-IR reverb,",
        "kick/snare/tom synthesis, string and brass-like saw stacks). Original, our own work, no samples.",
        "",
        "The game's own in-house sound files mixed in (each made by the repo's synthesizers, licence: ours):",
        "  gravelight/audio/sfx/weapons/fire_thompson_0[1-3].wav, fire_stg44_0[1-3].wav, fire_mg42_0[1-3].wav (gen_audio.py)",
        "  gravelight/audio/sfx/blast/blast_crack_0[1-3].wav, blast_debris_0[1-3].wav (T-280, in-house; SOURCE.txt there)",
        "  gravelight/audio/sherman/sherman_gun_1.ogg, sherman_engine.ogg (gen_audio_sherman.py)",
        "  gravelight/audio/horse/horse_blow_1.ogg, horse_boss_scream_1.ogg (gen_audio_horse.py)",
        "  gravelight/audio/bosses/boss_roar_low_2.ogg (gen_audio_bosses.py)",
        "  gravelight/audio/sfx/horror/whisper_02.ogg, whisper_04.ogg, bell_far_01.ogg (gen_audio_horror.py)",
        "",
        "No CC0 / third-party recordings were used (the map ambience folders that hold Freesound files were left out).",
    ]
    open(os.path.join(B, "SOURCE.txt"), "w", encoding="utf-8").write("\n".join(S) + "\n")
    print("wrote README.txt and SOURCE.txt")


if __name__ == "__main__":
    main()
