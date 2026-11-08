#!/usr/bin/env python3
"""Phone motion capture for the in-engine cutscenes (UPDATE 12 section 4, T-210). Run it as tools/mocap.sh:

    tools/mocap.sh report [--json] [--src=DIR]   dry run: per scene, which shot / role files are there and missing
    tools/mocap.sh build [--scene=ID] [--src=DIR] [--blender] [--no-godot] [--force]
                                                 every capture -> retarget, smooth, trim, ground, foot lock -> one
                                                 AnimationLibrary per scene: assets/ours/mocap/<scene>/mocap_<scene>.res
    tools/mocap.sh guide                         rewrites the generated part of docs/MOCAP_GUIDE.md from shots.json
    tools/mocap.sh lipsync [--all] [--ids=A,B]   mouth cues for the cutscene lines (tools/mocap/lipsync.py)
    tools/mocap.sh sample                        rewrites the synthetic test clip tests/data/mocap/sample_walk.bvh
    tools/mocap.sh test                          the pipeline's pytest suite (tests/mocap/)

Captures go in assets/user_supplied/mocap/<scene>/<shot>_<role>.fbx (or .bvh); <scene>, <shot> and <role> are
data/gravelight/mocap/shots.json's ids (gravelight_one/shot_04_seat1.fbx, cancel_ending/last_wren.bvh). A sidecar
<shot>_<role>.json may set {"start": seconds into the take where the shot begins, "cutoff": smoothing Hz, "lock":
false}; without one the shot starts 1.0 s after the slate clap (or after a still start), see mocaplib.find_start.
FBX goes through Blender headless (blender_extract.py); BVH is read in Python (or Blender with --blender).
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mocaplib as ml  # noqa: E402

ROOT = ml.ROOT
SHOTS = os.path.join(ROOT, "data", "gravelight", "mocap", "shots.json")
SRC = os.path.join(ROOT, "assets", "user_supplied", "mocap")
WORK = os.path.join(ROOT, ".mocap_work")
OUT_RES = "res://assets/ours/mocap"
OUT_DIR = os.path.join(ROOT, "assets", "ours", "mocap")
EXTS = (".fbx", ".bvh")


def load_shots(path=SHOTS):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def scene_of(data, sid):
    for s in data["scenes"]:
        if s["id"] == sid:
            return s
    return None


def parse_name(scene, fname):
    """(shot id, role) for a capture file name in a scene, or None."""
    base, ext = os.path.splitext(fname)
    if ext.lower() not in EXTS:
        return None
    for sh in sorted(scene["shots"], key=lambda x: -len(x["id"])):
        p = sh["id"] + "_"
        if base.startswith(p) and re.fullmatch(r"[a-z0-9]+", base[len(p):]):
            return sh["id"], base[len(p):]
    return None


def scan(data, src=SRC):
    """{scene id: {"files": {(shot, role): path}, "unknown": [names]}} for what is on disk."""
    out = {}
    for scene in data["scenes"]:
        d = os.path.join(src, scene["id"])
        rec = {"files": {}, "unknown": []}
        if os.path.isdir(d):
            for fn in sorted(os.listdir(d)):
                if fn.lower().endswith(".json") or fn.upper() in ("SOURCE.TXT", "LICENSE.TXT", "README.TXT"):
                    continue
                pr = parse_name(scene, fn)
                if pr is None:
                    rec["unknown"].append(fn)
                else:
                    rec["files"][pr] = os.path.join(d, fn)
        out[scene["id"]] = rec
    if os.path.isdir(src):
        for fn in sorted(os.listdir(src)):
            if os.path.isdir(os.path.join(src, fn)) and scene_of(data, fn) is None and not fn.startswith("_"):
                out.setdefault("_unknown_scenes", {"files": {}, "unknown": []})["unknown"].append(fn + "/")
    return out


def report(data, src=SRC):
    """The dry run: per scene and shot, the roles with a file and the roles missing ('any' covers every role)."""
    found = scan(data, src)
    rows = []
    tot = {"takes": 0, "present": 0, "missing_high": 0, "missing_optional": 0}
    for scene in data["scenes"]:
        files = found[scene["id"]]["files"]
        srow = {"scene": scene["id"], "title": scene["title"], "shots": [], "unknown": found[scene["id"]]["unknown"]}
        for sh in scene["shots"]:
            have, miss = [], []
            any_file = (sh["id"], "any") in files
            for role in sh["roles"]:
                if (sh["id"], role) in files or any_file:
                    have.append(role)
                else:
                    miss.append(role)
            extra = sorted(r for (s, r) in files if s == sh["id"] and r not in sh["roles"] and r != "any")
            tot["takes"] += len(sh["roles"])
            tot["present"] += len(have)
            tot["missing_high" if sh.get("priority") == "high" else "missing_optional"] += len(miss)
            srow["shots"].append({"shot": sh["id"], "dur": sh["dur"], "priority": sh.get("priority", "high"),
                                  "have": have, "missing": miss, "extra": extra, "any": any_file})
        rows.append(srow)
    return {"src": src, "scenes": rows, "total": tot, "unknown_scenes": found.get("_unknown_scenes", {}).get("unknown", [])}


def print_report(r):
    print("[mocap] captures in %s" % os.path.relpath(r["src"], ROOT))
    for s in r["scenes"]:
        done = sum(1 for x in s["shots"] if not x["missing"])
        print("\n%s  (%s): %d of %d shots complete" % (s["scene"], s["title"], done, len(s["shots"])))
        for x in s["shots"]:
            state = "ok" if not x["missing"] else "MISSING " + " ".join(x["missing"])
            extra = ("  (also: %s)" % " ".join(x["extra"])) if x["extra"] else ""
            print("  %-9s %5.1f s  %-8s %s%s" % (x["shot"], x["dur"], x["priority"], state, extra))
        for u in s["unknown"]:
            print("  ?? %s: not <shot>_<role>.fbx/.bvh for this scene" % u)
    for u in r["unknown_scenes"]:
        print("?? folder %s is not a scene in shots.json" % u)
    t = r["total"]
    print("\nTOTAL %d of %d takes; missing %d high-priority, %d optional" % (t["present"], t["takes"], t["missing_high"], t["missing_optional"]))


# ------------------------------------------------------------------ build

def _blender():
    b = os.environ.get("BLENDER", "")
    if b and os.path.exists(b):
        return b
    for c in (r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe", os.path.join(ROOT, "tools", "dl_blender", "blender")):
        if os.path.exists(c):
            return c
    return ""


def extract_with_blender(path, out_json):
    exe = _blender()
    if not exe:
        raise RuntimeError("Blender not found (set BLENDER, see tools/env.sh); FBX needs it")
    r = subprocess.run([exe, "-b", "--factory-startup", "--python", os.path.join(HERE, "blender_extract.py"), "--", path, out_json],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out_json):
        raise RuntimeError("Blender failed on %s: %s" % (path, (r.stdout + r.stderr)[-800:]))
    return ml.load_motion_json(out_json)


def _work_dir(work):
    os.makedirs(work, exist_ok=True)
    g = os.path.join(work, ".gdignore")   # (inside the project: Godot must not import the working files)
    if not os.path.exists(g):
        open(g, "w").close()


def motion_of(path, work_dir, use_blender=False):
    if path.lower().endswith(".bvh") and not use_blender:
        return ml.read_bvh(path)
    os.makedirs(work_dir, exist_ok=True)
    mj = os.path.join(work_dir, os.path.basename(path) + ".motion.json")
    if os.path.exists(mj) and os.path.getmtime(mj) >= os.path.getmtime(path):
        return ml.load_motion_json(mj)
    return extract_with_blender(path, mj)


def build_one(scene, shot, role, path, work, rig, use_blender=False):
    side = os.path.splitext(path)[0] + ".json"
    opts = {}
    if os.path.exists(side):
        with open(side, "r", encoding="utf-8") as f:
            opts = json.load(f)
    m = motion_of(path, os.path.join(work, scene["id"]), use_blender)
    c = ml.process(m, rig, dur=float(shot["dur"]), start=opts.get("start"), cutoff=float(opts.get("cutoff", 6.0)),
                   lock=bool(opts.get("lock", True)))
    out = os.path.join(work, scene["id"], "%s_%s.clip.json" % (shot["id"], role))
    meta = {"scene": scene["id"], "shot": shot["id"], "role": role, "root": shot.get("root", "mocap"),
            "source": os.path.relpath(path, ROOT).replace("\\", "/"), "built": datetime.date.today().isoformat(),
            "name": "%s_%s" % (shot["id"], role)}
    ml.write_clip(c, out, meta)
    return out, c["stats"]


def godot_import(work, scenes, out_res=OUT_RES):
    exe = os.environ.get("GODOT", "")
    if not exe or not os.path.exists(exe):
        raise RuntimeError("Godot not found (set GODOT, see tools/env.sh)")
    args = [exe, "--headless", "--audio-driver", "Dummy", "--path", ROOT, "--script", "res://tools/mocap/mocap_import.gd", "--",
            "--work=" + work, "--out=" + out_res, "--scenes=" + ",".join(scenes)]
    r = subprocess.run(args, capture_output=True, text=True)
    sys.stdout.write("\n".join(l for l in (r.stdout or "").splitlines() if "[mocap]" in l) + "\n")
    if r.returncode != 0:
        raise RuntimeError("Godot import failed: %s" % (r.stdout + r.stderr)[-1500:])


SOURCE_TXT = """Title: GRAVELIGHT cutscene motion capture (phone mocap of the owner and friends, retargeted)
Authors: GRAVELIGHT project (performances by the owner and friends; processed by tools/mocap, T-210)
Source: assets/user_supplied/mocap/ (the owner's own captures, git-ignored) through tools/mocap/mocap.py build
License: Ours (original work)
Credit line: none needed (original work)
Format: Godot AnimationLibrary (.res), one per cutscene, on the ZombieRig bone names
Files used: every file in this folder tree
Notes: the performers are the owner and his friends. If a capture went through an online app (Rokoko Vision, DeepMotion, QuickMagic), its plan must allow commercial use of the export: see docs/MOCAP_GUIDE.md "The apps".
"""
LICENSE_TXT = """Ours: original work made for GRAVELIGHT (T-210).

The animation files under assets/ours/mocap/ are the project's own performances (the owner and friends, filmed by
phone), turned into animation by the project's own scripts (tools/mocap/*.py, tools/mocap/mocap_import.gd). No
third-party motion data is used. Owned by the GRAVELIGHT project; same terms as the game.
"""


def paperwork(out_dir=OUT_DIR):
    os.makedirs(out_dir, exist_ok=True)
    for name, text in (("SOURCE.txt", SOURCE_TXT), ("LICENSE.txt", LICENSE_TXT)):
        p = os.path.join(out_dir, name)
        if not os.path.exists(p):
            with open(p, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)


def build(data, src=SRC, work=WORK, only="", use_blender=False, godot=True, out_res=OUT_RES):
    rig = ml.load_rig()
    found = scan(data, src)
    _work_dir(work)
    done, failed, scenes = [], [], []
    for scene in data["scenes"]:
        if only and scene["id"] != only:
            continue
        files = found[scene["id"]]["files"]
        if not files:
            continue
        shots = {s["id"]: s for s in scene["shots"]}
        for (sid, role), path in sorted(files.items()):
            try:
                out, st = build_one(scene, shots[sid], role, path, work, rig, use_blender)
                done.append(out)
                print("[mocap] %s/%s_%s: %d frames, start %.2f s (%s), foot slide %.3f -> %.3f m/s, jitter %.4f -> %.4f" % (
                    scene["id"], sid, role, st["frames"], st["start"], st["start_from"], st.get("slide_before", 0),
                    st.get("slide_after", 0), st["jitter_before"], st["jitter_after"]))
            except Exception as e:  # one bad take never stops the rest
                failed.append((path, str(e)))
                print("[mocap] FAILED %s: %s" % (os.path.relpath(path, ROOT), e))
        if scene["id"] not in scenes:
            scenes.append(scene["id"])
    if godot and scenes:
        if out_res == OUT_RES:
            paperwork()
        godot_import(work, scenes, out_res)
    return done, failed


# ------------------------------------------------------------------ the guide's generated part

def line_rows():
    lines = {}
    p = os.path.join(ROOT, "data", "gravelight", "vo", "lines.json")
    with open(p, "r", encoding="utf-8") as f:
        d = json.load(f)
    lines = d.get("lines", d)
    with open(os.path.join(ROOT, "data", "gravelight", "vo", "audio_manifest.json"), "r", encoding="utf-8") as f:
        man = json.load(f).get("files", {})
    return lines, man


SQUAD_CODES = {"dutch": "DUT", "peg": "PEG", "deacon": "DEA", "wren": "WRN"}


def _line_text(lines, man, lid):
    """[(id, seconds or None, text)] for a line id; a <seat1>/<seat2>/<turner> id expands to the four squad lines."""
    if lid.startswith("<"):
        suffix = lid.split(">", 1)[1]
        return [r for c in ("DUT", "PEG", "DEA", "WRN") for r in _line_text(lines, man, c + suffix)]
    row = lines.get(lid, {})
    dur = man.get(lid, {}).get("duration")
    txt = re.sub(r"\{([^}]*)\}", r"\1", str(row.get("text", "?")))
    return [(lid, dur, txt)]


def guide_tables(data):
    lines, man = line_rows()
    out = []
    n_shots = n_takes = 0
    secs = 0.0
    high_takes = 0
    for scene in data["scenes"]:
        out.append("### %s\n" % scene["title"])
        out.append("Scene id `%s` (%s). **Set-up:** %s\n" % (scene["id"], scene["data"], scene["set_up"]))
        for sh in scene["shots"]:
            n_shots += 1
            n_takes += len(sh["roles"])
            secs += sh["dur"] * len(sh["roles"])
            if sh.get("priority", "high") == "high":
                high_takes += len(sh["roles"])
            tag = "" if sh.get("priority", "high") == "high" else " *(optional: small in frame)*"
            out.append("#### `%s` · %.1f s · %s%s\n" % (sh["id"], sh["dur"], ", ".join(sh["roles"]), tag))
            out.append("- **Phone:** %s" % sh["camera"])
            out.append("- **Marks:** %s" % sh["marks"])
            if sh.get("root") == "cast":
                out.append("- **Walking:** the game moves the character along its own path; just walk naturally at the pace given.")
            acts = sh["action"]
            for role in sh["roles"]:
                a = acts.get(role, acts.get("any", ""))
                out.append("- **%s** (`%s_%s.fbx`): %s" % (data["roles"].get(role, role), sh["id"], role, a))
            if "any" in acts and any(r not in acts for r in sh["roles"]) and len(sh["roles"]) > 1:
                out.append("  (One take `%s_any.fbx` can stand in for every role without its own.)" % sh["id"])
            out.append("- **Props:** %s" % sh["props"])
            if sh["lines"]:
                out.append("- **Lines** (say them, or mouth them in time: the game plays the recorded voice):")
                for at, lid, who in sh["lines"]:
                    for (i, d, t) in _line_text(lines, man, lid):
                        out.append("  - at %.1f s, %s, `%s` (%s): \"%s\"" % (float(at), who, i, ("%.1f s" % d) if d else "no take yet", t))
            else:
                out.append("- **Lines:** none.")
            out.append("")
    out.append("### Not filmed\n")
    for nf in data.get("not_filmed", []):
        out.append("- %s: %s" % (nf["scene"], nf["why"]))
    out.append("")
    # the time it takes: per take about 3 tries of the shot plus 60 s to reset, per shot 4 min to set marks and the phone
    tries_min = sum(len(sh["roles"]) * (3 * (sh["dur"] + 8) + 60) / 60.0 for sc in data["scenes"] for sh in sc["shots"])
    setup_min = 4.0 * n_shots
    total = {"shots": n_shots, "takes": n_takes, "high_takes": high_takes, "seconds": round(secs, 1),
             "minutes": round(tries_min + setup_min)}
    return "\n".join(out), total


BEGIN = "<!-- mocap:begin -->"
END = "<!-- mocap:end -->"


def write_guide(data, path=os.path.join(ROOT, "docs", "MOCAP_GUIDE.md")):
    tables, total = guide_tables(data)
    summary = ("**%d shots, %d takes** (%d of them high priority), **%.0f s of captured motion** in all. Filming time: "
               "about **%d minutes** (%.1f hours) with the marks and phone set once per shot and about three tries per "
               "take, one performer at a time; two performers in parallel with two phones cut it nearly in half." % (
                   total["shots"], total["takes"], total["high_takes"], total["seconds"], total["minutes"], total["minutes"] / 60.0))
    block = "%s\n<!-- generated by tools/mocap.sh guide from data/gravelight/mocap/shots.json; edit that file, not this block -->\n\n%s\n\n## Total\n\n%s\n%s" % (BEGIN, tables, summary, END)
    with open(path, "r", encoding="utf-8") as f:
        doc = f.read()
    if BEGIN in doc and END in doc:
        doc = doc[:doc.index(BEGIN)] + block + doc[doc.index(END) + len(END):]
    else:
        doc = doc.rstrip() + "\n\n" + block + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(doc)
    return total


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["report", "build", "guide", "sample"])
    ap.add_argument("--src", default=SRC)
    ap.add_argument("--work", default=WORK)
    ap.add_argument("--scene", default="")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--blender", action="store_true")
    ap.add_argument("--no-godot", action="store_true")
    ap.add_argument("--out", default=OUT_RES, help="where the libraries go (res:// path or an absolute folder)")
    a = ap.parse_args(argv)
    data = load_shots()
    if a.cmd == "report":
        r = report(data, a.src)
        if a.json:
            print(json.dumps(r, indent=1))
        else:
            print_report(r)
        return 0
    if a.cmd == "build":
        done, failed = build(data, a.src, a.work, a.scene, a.blender, not a.no_godot, a.out)
        print("[mocap] built %d clips, %d failed" % (len(done), len(failed)))
        return 1 if failed else 0
    if a.cmd == "guide":
        t = write_guide(data)
        print("[mocap] docs/MOCAP_GUIDE.md: %(shots)d shots, %(takes)d takes, %(seconds).0f s, about %(minutes)d min of filming" % t)
        return 0
    if a.cmd == "sample":
        import make_sample
        print(make_sample.write(os.path.join(ROOT, "tests", "data", "mocap", "sample_walk.bvh")))
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
