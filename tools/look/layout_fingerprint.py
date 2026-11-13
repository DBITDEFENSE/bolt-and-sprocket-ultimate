#!/usr/bin/env python
"""T-222: the layout fingerprint of a generated map scene (what an art pass must not change).

    python -I tools/look/layout_fingerprint.py <scene.tscn> [--json=<out>]
    python -I tools/look/layout_fingerprint.py --diff <a.tscn|a.json> <b.tscn|b.json>

Reads the .tscn as text (no Godot needed). Counts CollisionShape3D / StaticBody3D / NavigationRegion3D /
NavigationLink3D nodes, hashes every navmesh's vertex and polygon arrays, and fingerprints every gameplay-relevant
node by its path: the collision and navigation nodes (transform, shape content, link ends, region enabled), every
node under Gameplay (type, transform, script, the properties that are not resource ids), and the root's direct
non-visual children. Resource ids are resolved to their content, so a regenerated scene whose generator drew new
random ids still compares equal. Lights, meshes, materials, labels, particles and the dressing are left out.
--diff prints what differs and exits 1 if anything does.
"""
import hashlib
import json
import re
import sys

LAYOUT_TYPES = {"CollisionShape3D", "StaticBody3D", "NavigationRegion3D", "NavigationLink3D", "Area3D", "Marker3D",
                "CharacterBody3D", "AnimatableBody3D", "RigidBody3D", "CollisionPolygon3D"}
SKIP_PROPS = {"material_override", "mesh", "surface_material_override", "light_energy", "light_color"}


def parse(path):
    text = open(path, encoding="utf-8").read()
    blocks = re.split(r"\n(?=\[)", text)
    subs, nodes = {}, []
    for b in blocks:
        head, _, body = b.partition("\n")
        m = re.match(r"\[sub_resource type=\"([^\"]+)\" id=\"([^\"]+)\"", head)
        if m:
            subs[m.group(2)] = (m.group(1), body.strip())
            continue
        m = re.match(r"\[ext_resource [^\]]*path=\"([^\"]+)\"[^\]]*id=\"([^\"]+)\"", head)
        if m:
            subs["ext:" + m.group(2)] = ("ext", m.group(1))
            continue
        m = re.match(r"\[node name=\"([^\"]+)\"(.*)\]", head)
        if m:
            attrs = dict(re.findall(r"(\w+)=\"([^\"]*)\"", m.group(2)))
            inst = re.search(r"instance=ExtResource\(\"([^\"]+)\"\)", m.group(2))
            props = {}
            key = None
            for line in body.split("\n"):
                mm = re.match(r"^([A-Za-z_][\w/]*) = (.*)$", line)
                if mm:
                    key = mm.group(1)
                    props[key] = mm.group(2)
                elif key and line.strip():
                    props[key] += "\n" + line
            nodes.append({"name": m.group(1), "type": attrs.get("type", ""), "parent": attrs.get("parent"),
                          "inst": inst.group(1) if inst else None, "props": props})
    return subs, nodes


def resolve(val, subs, depth=0):
    def sub_r(m):
        sid = m.group(1)
        if sid not in subs or depth > 3:
            return "?"
        t, body = subs[sid]
        return "%s{%s}" % (t, resolve(body, subs, depth + 1))

    def ext_r(m):
        e = subs.get("ext:" + m.group(1))
        return "ext(%s)" % (e[1] if e else "?")
    val = re.sub(r"SubResource\(\"([^\"]+)\"\)", sub_r, val)
    val = re.sub(r"ExtResource\(\"([^\"]+)\"\)", ext_r, val)
    return val


def fingerprint(path):
    subs, nodes = parse(path)
    counts = {}
    out = {}
    nav_hashes = []
    # Godot's auto names (@Marker3D@8365) carry a process-wide counter that moves when the generator makes more
    # nodes before them: they are compared by their order among their siblings instead (@Marker3D@#0, #1, ...)
    seen, rename = {}, {}
    for n in nodes:
        p = n["parent"]
        full = n["name"] if p is None else (n["name"] if p == "." else p + "/" + n["name"])
        for old, new in sorted(rename.items(), key=lambda kv: -len(kv[0])):
            if p is not None and (p == old or p.startswith(old + "/")):
                full = new + full[len(old):]
                break
        m = re.match(r"^@(\w+)@\d+$", n["name"])
        if m:
            parent_path = full[: -len(n["name"]) - 1] if "/" in full else ""
            k = (parent_path, m.group(1))
            seen[k] = seen.get(k, -1) + 1
            orig = full
            full = (parent_path + "/" if parent_path else "") + "@%s@#%d" % (m.group(1), seen[k])
            rename[orig] = full
        n["path"] = full
    for n in nodes:
        t = n["type"]
        counts[t] = counts.get(t, 0) + 1
        path = n["path"]
        in_gameplay = path.startswith("Gameplay/") or path == "Gameplay"
        top_level = n["parent"] == "."
        if not (t in LAYOUT_TYPES or in_gameplay or (top_level and t in ("Node3D", "") and n["inst"] is None and path not in ("Dressing", "StaticBatches", "Geometry"))):
            continue
        if t in ("MeshInstance3D", "MultiMeshInstance3D", "Label3D", "OmniLight3D", "SpotLight3D", "GPUParticles3D", "Decal", "Sprite3D"):
            continue
        props = {k: resolve(v, subs) for k, v in n["props"].items() if k not in SKIP_PROPS}
        if t == "NavigationRegion3D" and "navigation_mesh" in n["props"]:
            h = hashlib.sha1(props["navigation_mesh"].encode()).hexdigest()[:16]
            nav_hashes.append(h)
            props["navigation_mesh"] = h
        out[path] = hashlib.sha1(json.dumps([t, n["inst"] and resolve('ExtResource("%s")' % n["inst"], subs), props], sort_keys=True).encode()).hexdigest()[:16]
    keep = {k: counts.get(k, 0) for k in sorted(LAYOUT_TYPES)}
    return {"scene": path, "counts": keep, "navmesh_hashes": sorted(nav_hashes),
            "navmesh_all": hashlib.sha1("".join(sorted(nav_hashes)).encode()).hexdigest()[:16], "nodes": out}


def load(p):
    if p.endswith(".json"):
        return json.load(open(p, encoding="utf-8"))
    return fingerprint(p)


def main(argv):
    if argv and argv[0] == "--diff":
        a, b = load(argv[1]), load(argv[2])
        bad = 0
        if a["counts"] != b["counts"]:
            print("counts differ:", a["counts"], b["counts"])
            bad += 1
        if a["navmesh_all"] != b["navmesh_all"]:
            print("navmesh hashes differ: %s vs %s" % (a["navmesh_all"], b["navmesh_all"]))
            bad += 1
        ka, kb = set(a["nodes"]), set(b["nodes"])
        for k in sorted(ka - kb):
            print("only in A:", k)
            bad += 1
        for k in sorted(kb - ka):
            print("only in B:", k)
            bad += 1
        for k in sorted(ka & kb):
            if a["nodes"][k] != b["nodes"][k]:
                print("differs:", k)
                bad += 1
        print("%s: %d layout nodes, %d navmeshes, counts %s -> %s" % ("SAME" if bad == 0 else "DIFFERENT (%d)" % bad,
              len(kb), len(b["navmesh_hashes"]), json.dumps(a["counts"]), "same" if a["counts"] == b["counts"] else json.dumps(b["counts"])))
        return 1 if bad else 0
    fp = fingerprint(argv[0])
    js = [a for a in argv[1:] if a.startswith("--json=")]
    if js:
        json.dump(fp, open(js[0][7:], "w", encoding="utf-8"), indent=1)
    print(json.dumps({"counts": fp["counts"], "navmeshes": len(fp["navmesh_hashes"]), "navmesh_all": fp["navmesh_all"], "layout_nodes": len(fp["nodes"])}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
