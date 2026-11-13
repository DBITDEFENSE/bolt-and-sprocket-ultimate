"""Points a GLB's embedded images back at external files (the pack's palette PNGs): images[i] gets `uri` (from the
original GLB's same-named image) instead of its bufferView. The orphaned bytes stay in the binary chunk (harmless).
Usage: python -I tools_src/blender/glb_relink_images.py <processed.glb> <original.glb>"""
import json
import struct
import sys


def read(p):
    f = open(p, "rb").read()
    jl = struct.unpack("<I", f[12:16])[0]
    j = json.loads(f[20:20 + jl])
    rest = f[20 + jl:]
    return j, rest


out, orig = sys.argv[1], sys.argv[2]
j, rest = read(out)
jo, _ = read(orig)
uris = {im.get("name"): im["uri"] for im in jo.get("images", []) if "uri" in im}
n = 0
if not j.get("images") and jo.get("images"):
    # the processed export lost the texture (Blender could not find the external PNG): restore the original's
    # images, textures and samplers and each same-named material's colour texture
    for k in ("images", "textures", "samplers"):
        if k in jo:
            j[k] = jo[k]
    om = {m.get("name"): m for m in jo.get("materials", [])}
    for m in j.get("materials", []):
        bct = om.get(m.get("name"), {}).get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if bct is not None:
            m.setdefault("pbrMetallicRoughness", {})["baseColorTexture"] = bct
    n = len(j["images"])
for im in j.get("images", []):
    if im.get("name") in uris:
        im.pop("bufferView", None)
        im["uri"] = uris[im["name"]]
        n += 1
js = json.dumps(j, separators=(",", ":")).encode("utf8")
js += b" " * ((4 - len(js) % 4) % 4)
body = struct.pack("<II", len(js), 0x4E4F534A) + js + rest
open(out, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)
print(f"RELINK {out}: {n} image(s) -> external")
