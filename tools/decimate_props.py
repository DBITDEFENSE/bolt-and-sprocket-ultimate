#!/usr/bin/env python
"""Bring the CC0 props down to the ART_BIBLE prop budget with Blender headless (UPDATE_05 section 1, T-088).

    python -I tools/decimate_props.py [--only=key,key] [--target=3000] [--all] [--dry-run]

For every prop in data/gravelight/props_library.json flagged over_budget (or every prop with --all) whose LOD0 is
above its target (the entry's "target_tris", else --target), runs tools_src/blender/decimate_gltf.py on its GLB,
packs the separate glTF Blender writes back into model.glb with external PNG textures (the same layout the fetch
script makes), and rewrites the entry's tris. The originals are one `python -I tools/fetch_cc0_materials.py --force
--only=<id>` away. Re-run tools/apply_import_presets.sh and tools/asset_report.sh afterwards.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from fetch_cc0_materials import to_png, write_glb  # noqa: E402

BLENDER = os.environ.get("BLENDER") or (r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" if os.name == "nt"
    else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools", "dl_blender", "blender"))   # see tools/env.sh
SCRIPT = os.path.join(ROOT, "tools_src", "blender", "decimate_gltf.py")
PROPS = os.path.join(ROOT, "data", "gravelight", "props_library.json")


def tris_of_gltf(doc: dict) -> int:
    n = 0
    for m in doc.get("meshes", []):
        for pr in m.get("primitives", []):
            if "indices" in pr:
                n += doc["accessors"][pr["indices"]]["count"] // 3
            else:
                n += doc["accessors"][pr["attributes"]["POSITION"]]["count"] // 3
    return n


def repack(tmp: str, out_dir: str, tex_px: int) -> int:
    with open(os.path.join(tmp, "model.gltf"), "r", encoding="utf-8") as f:
        doc = json.load(f)
    tex_dir = os.path.join(out_dir, "textures")
    old = set(os.listdir(tex_dir)) if os.path.isdir(tex_dir) else set()
    os.makedirs(tex_dir, exist_ok=True)
    kept = set()
    for img in doc.get("images", []):
        uri = img.get("uri", "")
        src = os.path.join(tmp, *uri.split("/"))
        base = os.path.splitext(os.path.basename(uri))[0]
        png = "%s.png" % base
        to_png(src, os.path.join(tex_dir, png), tex_px, "RGBA" if "alpha" in base.lower() else "RGB")
        img["uri"] = "textures/%s" % png
        img["mimeType"] = "image/png"
        kept.add(png)
    for stale in old - kept:
        if stale.lower().endswith(".png"):
            os.remove(os.path.join(tex_dir, stale))
            imp = os.path.join(tex_dir, stale + ".import")
            if os.path.exists(imp):
                os.remove(imp)
    buffers = doc.get("buffers", [])
    if len(buffers) != 1 or "uri" not in buffers[0]:
        raise RuntimeError("expected one external buffer in %s" % tmp)
    with open(os.path.join(tmp, buffers[0]["uri"]), "rb") as f:
        bin_data = f.read()
    del buffers[0]["uri"]
    buffers[0]["byteLength"] = len(bin_data)
    doc.setdefault("asset", {})["generator"] = "Blender decimate (tools/decimate_props.py), packed to GLB"
    write_glb(os.path.join(out_dir, "model.glb"), doc, bin_data)
    return tris_of_gltf(doc)


def main(argv):
    only, target, every, dry = set(), 3000, False, False
    for a in argv:
        if a.startswith("--only="):
            only = set(a[7:].split(","))
        elif a.startswith("--target="):
            target = int(a[9:])
        elif a == "--all":
            every = True
        elif a == "--dry-run":
            dry = True
    if not os.path.exists(BLENDER):
        print("Blender not found at %s (set BLENDER=...)" % BLENDER)
        return 2
    with open(PROPS, "r", encoding="utf-8") as f:
        data = json.load(f)
    changed = 0
    for key, e in data.get("props", {}).items():
        if only and key not in only:
            continue
        if not every and not only and not e.get("over_budget"):
            continue
        want = int(e.get("target_tris", target))
        if int(e.get("tris", 0)) <= want and not only:
            continue
        glb = os.path.join(ROOT, *e["path"].replace("res://", "").split("/"))
        if not glb.lower().endswith(".glb") or not os.path.exists(glb):
            print("- %s: no GLB at %s" % (key, glb))
            continue
        print("> %s: %d tris -> %d" % (key, int(e.get("tris", 0)), want))
        if dry:
            continue
        tmp = tempfile.mkdtemp(prefix="decimate_", dir=os.path.join(ROOT, "tools_src", "_downloads"))
        try:
            r = subprocess.run([BLENDER, "-b", "-P", SCRIPT, "--", glb, tmp, str(want)], capture_output=True, text=True, timeout=600)
            tail = [l for l in r.stdout.splitlines() if l.startswith("[decimate]")]
            for l in tail:
                print("    " + l)
            if r.returncode != 0 or not os.path.exists(os.path.join(tmp, "model.gltf")):
                print("  ! Blender failed (%d): %s" % (r.returncode, r.stderr[-400:]))
                continue
            tex_px = 1024
            tex_dir = os.path.join(os.path.dirname(glb), "textures")
            if os.path.isdir(tex_dir):
                try:
                    from PIL import Image
                    for fn in os.listdir(tex_dir):
                        if fn.lower().endswith(".png"):
                            with Image.open(os.path.join(tex_dir, fn)) as im:
                                tex_px = max(im.size)
                            break
                except Exception:  # noqa: BLE001
                    pass
            new_tris = repack(tmp, os.path.dirname(glb), tex_px)
            e["tris"] = new_tris
            e["over_budget"] = new_tris > 3000
            if not e["over_budget"]:
                e.pop("over_budget", None)
            e["decimated"] = "Blender collapse to %d (tools/decimate_props.py)" % want
            changed += 1
            print("  ok %d tris" % new_tris)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    if changed:
        with open(PROPS, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print("updated %s (%d props)" % (os.path.relpath(PROPS, ROOT), changed))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
