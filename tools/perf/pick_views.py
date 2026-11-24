#!/usr/bin/env python
"""T-266: builds the capture sets t266_<map> (and t266_<map>_noon where the map has the day) from the headless view
census (perf_marks --views over every capture camera of a map): the worst cameras by surfaces, lights, lamp shadow
draws, particles and transparent surfaces in the frustum, plus the first camera. The same cameras are then measured
rendered (tools/wsl_perf.sh ... --views=t266_<key>) and captured before / after a change.
    python -I tools/perf/pick_views.py <log dir with <map id>.log> [per map, default 8]
"""
import json, os, re, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CAMS = os.path.join(ROOT, "data", "gravelight", "capture_cams.json")
MAPS = {"map00_crossroads": ("m00", "map00_crossroads/map00.tscn", True), "map01_kaltenbrunn": ("m01", "map01_kaltenbrunn/map01.tscn", True),
        "map02_totenhafen": ("m02", "map02_totenhafen/map02.tscn", True), "map04a_thalbach": ("m04a", "map04_fernflug/map04a.tscn", True),
        "map04b_kranich": ("m04b", "map04_fernflug/map04b.tscn", False), "map04c_groomlake": ("m04c", "map04_fernflug/map04c.tscn", False),
        "map04d_mondlicht": ("m04d", "map04_fernflug/map04d.tscn", False)}
VIEW = re.compile(r"^\[view\] (\S+) \S+ h\S+ (\S+) at \(([-\d., ]+)\) \| (.*)$")
NUM = {"surf": r"surf (\d+)", "lights": r"lights (\d+) of", "caster_draws": r"lamp caster draws (\d+)", "parts": r"particles (\d+) of", "transp": r"transparent (\d+)",
       "skinned": r"skinned (\d+)"}


def main(argv):
    logdir = argv[0]
    per = int(argv[1]) if len(argv) > 1 else 8
    cfg = json.load(open(CAMS, encoding="utf-8"))
    sets = cfg["sets"]
    by_name = {}
    for sn, sd in sets.items():
        if sn.startswith("t266_"):
            continue
        for c in sd.get("cams", []):
            if "pos" in c and "map" not in c:
                by_name.setdefault((sd.get("map", ""), c.get("name")), c)
    for mid, (key, scene, day) in MAPS.items():
        path = os.path.join(logdir, mid + ".log")
        if not os.path.exists(path):
            continue
        rows = []
        for ln in open(path, encoding="utf-8", errors="replace"):
            m = VIEW.match(ln.strip())
            if not m:
                continue
            r = {"name": m.group(2), "pos": [float(x) for x in m.group(3).split(",")]}
            for k, pat in NUM.items():
                mm = re.search(pat, m.group(4))
                r[k] = int(mm.group(1)) if mm else 0
            rows.append(r)
        if not rows:
            continue
        picked = [rows[0]]

        def far(r):
            return all(sum((a - b) ** 2 for a, b in zip(r["pos"], p["pos"])) > 36.0 for p in picked)
        order = ["surf", "lights", "caster_draws", "surf", "parts", "transp", "lights", "skinned", "surf", "caster_draws"]
        for k in order:
            if len(picked) >= per:
                break
            for r in sorted(rows, key=lambda x: -x[k]):
                if r not in picked and far(r):
                    picked.append(r)
                    break
        scene_path = "res://gravelight/maps/" + scene
        for noon in ([False, True] if day else [False]):
            cams = []
            for i, r in enumerate(picked):
                src = by_name.get((scene_path, r["name"]))
                if src is None:
                    continue
                c = {"name": re.sub(r"_h\d\d$", "", r["name"]), "pos": src["pos"], "yaw": src.get("yaw", 0.0), "pitch": src.get("pitch", 0.0)}
                if i == 0 and day:
                    c["do"] = ["callv:DayCycle:hold_hour:%d:1" % (12 if noon else 0)]
                cams.append(c)
            sets["t266_" + key + ("_noon" if noon else "")] = {"map": scene_path, "bots": 0, "settle_s": 6.0,
                "_doc": "T-266 render census: the heaviest views of the map (tools/perf/pick_views.py)" + (", the day held at noon" if noon else ""), "cams": cams}
        print(mid, [(r["name"], r["surf"], r["lights"], r["caster_draws"]) for r in picked])
    json.dump(cfg, open(CAMS, "w", encoding="utf-8", newline="\n"), indent=2, ensure_ascii=False)
    open(CAMS, "a", encoding="utf-8", newline="\n").write("\n")


if __name__ == "__main__":
    main(sys.argv[1:])
