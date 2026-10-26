"""glb_sanitize.py: fixes the materials of an already converted GLB in place (T-098), so anything that loads the raw
GLB (the wall-buy mounts, WeaponModels outside the viewmodel, the editor) draws it as WeaponShader does:

  - an emissiveFactor with no emissive texture is removed (Sketchfab's exporter leaves [1,1,1] behind once its black
    emissive map is dropped: a plain StandardMaterial3D would glow white);
  - with --opaque, alphaMode BLEND / MASK becomes OPAQUE (junk alpha in a Sketchfab albedo made the exporter write BLEND:
    the gun drew see-through and out of depth order).

The same rules run inside tools_src/blender/convert_to_glb.py (fix_materials) on every new conversion.

Usage: python -I tools/glb_sanitize.py [--opaque] [--check] <model.glb> [...]
  --check   change nothing; exit 1 if a file would change
Only the JSON chunk is rewritten; the binary chunk is copied byte for byte.
"""
import json
import struct
import sys


def fix_materials(js, opaque):
    changed = False
    for m in js.get("materials", []):
        if "emissiveTexture" not in m and "emissiveFactor" in m:
            del m["emissiveFactor"]
            changed = True
        ext = m.get("extensions", {})
        if "emissiveTexture" not in m and "KHR_materials_emissive_strength" in ext:
            del ext["KHR_materials_emissive_strength"]
            changed = True
        if opaque and m.get("alphaMode", "OPAQUE") != "OPAQUE":
            m.pop("alphaMode", None)
            m.pop("alphaCutoff", None)
            changed = True
    return changed


def read_glb(path):
    with open(path, "rb") as f:
        d = f.read()
    magic, ver, total = struct.unpack("<III", d[:12])
    if magic != 0x46546C67 or ver != 2:
        raise SystemExit(path + ": not a glTF 2 binary")
    jl, jt = struct.unpack("<II", d[12:20])
    if jt != 0x4E4F534A:
        raise SystemExit(path + ": first chunk is not JSON")
    js = json.loads(d[20:20 + jl].decode("utf-8"))
    return js, d[20 + jl:]


def write_glb(path, js, rest):
    jtxt = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jtxt += b" " * ((4 - len(jtxt) % 4) % 4)
    total = 12 + 8 + len(jtxt) + len(rest)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(jtxt), 0x4E4F534A))
        f.write(jtxt)
        f.write(rest)


def main(argv):
    opaque = "--opaque" in argv
    check = "--check" in argv
    files = [a for a in argv if not a.startswith("--")]
    if not files:
        print(__doc__)
        return 2
    bad = 0
    for p in files:
        js, rest = read_glb(p)
        if fix_materials(js, opaque):
            bad += 1
            if check:
                print("would fix", p)
            else:
                write_glb(p, js, rest)
                print("fixed", p)
        else:
            print("ok", p)
    return 1 if (check and bad) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
