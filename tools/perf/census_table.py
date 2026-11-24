#!/usr/bin/env python
"""T-266: tables from the render census logs (tools/perf/render_census.sh; perf_marks --views).

    python -I tools/perf/census_table.py <dir> [<dir after>] [--views] [--md]

One row per map / preset / hour: the average and the worst view's draw calls (all passes), the colour pass and the
shadow passes apart, triangles, and from the frustum census the lights, the shadow views (lamps + sun), skinned
meshes, particle systems, decals, transparent surfaces and materials. With two directories the second is printed
under the first with the change. --views lists every view.
"""
import glob, os, re, sys

VIEW = re.compile(r"^\[view\] (\S+) (\S+) h(\S+) (\S+) at \(([^)]*)\) \| (.*)$")
PAT = {
    "dc": r"all dc (\d+)", "col_dc": r"colour \d+ obj (\d+) dc", "sh_dc": r"shadow \d+ obj (\d+) dc", "col_tri_k": r"colour \d+ obj \d+ dc (\d+)k tri",
    "sh_tri_k": r"shadow \d+ obj \d+ dc (\d+)k tri", "col_obj": r"colour (\d+) obj", "sh_obj": r"shadow (\d+) obj",
    "inst": r"frustum: inst (\d+)", "surf": r"surf (\d+)", "skinned": r"skinned (\d+)", "lights": r"lights (\d+) of", "lights_all": r"lights \d+ of (\d+)",
    "lamp_views": r"= (\d+) views", "sun_views": r"\+ sun (\d+)", "casters": r"casters (\d+)", "parts": r"particles (\d+) of", "decals": r"decals (\d+) of",
    "transp": r"transparent (\d+)", "mats": r"materials (\d+)", "shaders": r"shaders (\d+)",
}
COLS = ["dc", "col_dc", "sh_dc", "col_tri_k", "sh_tri_k", "inst", "skinned", "lights", "lamp_views", "sun_views", "casters", "parts", "decals", "transp", "mats", "shaders"]


def load(d):
    rows = {}
    for f in sorted(glob.glob(os.path.join(d, "*.log"))):
        for ln in open(f, encoding="utf-8", errors="replace"):
            m = VIEW.match(ln.strip())
            if not m:
                continue
            r = {"view": m.group(4)}
            for k, p in PAT.items():
                mm = re.search(p, m.group(6))
                r[k] = int(mm.group(1)) if mm else 0
            rows.setdefault((m.group(1), m.group(2), m.group(3)), []).append(r)
    return rows


def summary(views):
    out = {}
    for c in COLS:
        vals = [v[c] for v in views]
        out[c] = (sum(vals) / len(vals), max(vals))
    out["worst_view"] = max(views, key=lambda v: (v["dc"], v["surf"]))["view"]
    return out


def main(argv):
    dirs = [a for a in argv if not a.startswith("--")]
    per_view = "--views" in argv
    rows = {}
    for d in dirs:
        for k, v in load(d).items():
            preset, _, tag = k[1].partition("/")
            # a run with T-266's passes switched off step by step tags its lines "<preset>/before", "<preset>/-<off>"
            order = 0 if tag == "before" else (1 + (5 - tag.count("-")) if tag else 9)
            label = tag if tag else "after"
            if len(dirs) > 1:
                label = os.path.basename(os.path.normpath(d)) + (" " + tag if tag else "")
            rows.setdefault((k[0], preset, k[2]), []).append((dirs.index(d), order, label, v))
    print("| map | preset | hour | run | " + " | ".join(COLS) + " | worst view |")
    print("|" + "---|" * (len(COLS) + 5))
    for k in sorted(rows):
        base = None
        for _, _, label, views in sorted(rows[k], key=lambda r: (r[0], r[1])):
            s = summary(views)
            cells = []
            for c in COLS:
                t = "%.0f / %d" % (s[c][0], s[c][1])
                if base is not None and base[c][0] > 0 and c in ("dc", "col_dc", "sh_dc", "col_tri_k", "sh_tri_k", "lights", "inst"):
                    t += " (%+.0f%%)" % (100.0 * (s[c][0] - base[c][0]) / base[c][0])
                cells.append(t)
            print("| %s | %s | %s | %s | %s | %s |" % (k[0], k[1], k[2], label, " | ".join(cells), s["worst_view"]))
            if base is None:
                base = s
            if per_view:
                for v in views:
                    print("| | | | %s | %s | |" % (v["view"], " | ".join(str(v[c]) for c in COLS)))
    print()
    print("Each cell: average over the views / the worst view; the change is against the group's first row. Triangles in thousands.")
    print("Counted with perf_marks --views --quick --cheap (see its header): draw calls, objects, lights and shadow views are exact, triangles are for a quarter-size picture.")


if __name__ == "__main__":
    main(sys.argv[1:])
