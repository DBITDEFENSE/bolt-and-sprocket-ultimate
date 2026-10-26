"""convert_to_glb.py: Blender (5.x) headless converter for the asset intake (UPDATE_05A section 3, T-087).

Usage:
  blender -b -P tools_src/blender/convert_to_glb.py -- <in> <out.glb> [options]

  <in>            .blend, .fbx, .obj, .glb or .gltf
  <out.glb>       written next to a `textures/` folder holding every texture as a PNG; the GLB references them by
                  relative URI (no embedded images), so Godot imports the PNGs through its own texture import presets.
Options:
  --object NAME        keep only this object (or every object of the collection with this name); repeatable
  --max-tex N          cap textures to N px on the long side (default 2048; downscaled by whole factors)
  --split-vgroups      split a rigged single-mesh gun into one object per vertex group (the OGA packs)
  --map old=new        rename a vertex group or object; several groups mapped to one name are merged (repeatable,
                       also accepts a comma list). Names not mapped keep their own (sanitised) name.
  --keep-rig           keep armatures and skins (default: drop them, export plain meshes in the bind pose)
  --drop-black-emissive remove emissive textures that are black everywhere (Sketchfab exports them by habit)
  --preview out.png    also render a side+top Workbench preview (off-screen; no window) with one colour per object
  --min-faces N        groups with fewer faces than N fold into the biggest group (default 1)
  --drop NAME          delete this object after the split/rename (stray rounds, scene clutter); repeatable
  --opaque             every material exported OPAQUE (a gun has no see-through parts; Sketchfab packs alpha junk
                       into the albedo and the glTF exporter then writes alphaMode BLEND). T-098.
  --auto-tex           texel-density cap per material: the longest side of the geometry a material covers decides
                       its cap (>= 0.6 m: max-tex; >= 0.25 m: max-tex/2; smaller: max-tex/4)

Prints one `REPORT_JSON {...}` line: objects (name, tris, bbox), total tris, bbox and size in metres, glTF axes
(+Y up), the texture list, and a `forward` guess (the narrower end of the long axis, muzzle side).
"""
import bpy
import bmesh
import json
import math
import os
import re
import shutil
import struct
import sys
import tempfile


def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        print(__doc__)
        sys.exit(2)
    opt = {"in": argv[0], "out": argv[1], "objects": [], "max_tex": 2048, "split": False, "map": {},
           "keep_rig": False, "drop_black_emissive": False, "preview": None, "min_faces": 1, "drop": [], "auto_tex": False, "opaque": False}
    i = 2
    while i < len(argv):
        a = argv[i]
        if a == "--object":
            opt["objects"].append(argv[i + 1]); i += 2
        elif a == "--max-tex":
            opt["max_tex"] = int(argv[i + 1]); i += 2
        elif a == "--split-vgroups":
            opt["split"] = True; i += 1
        elif a == "--map":
            for pair in argv[i + 1].split(","):
                if "=" in pair:
                    k, v = pair.split("=", 1)
                    opt["map"][k.strip()] = v.strip()
            i += 2
        elif a == "--keep-rig":
            opt["keep_rig"] = True; i += 1
        elif a == "--drop-black-emissive":
            opt["drop_black_emissive"] = True; i += 1
        elif a == "--preview":
            opt["preview"] = argv[i + 1]; i += 2
        elif a == "--min-faces":
            opt["min_faces"] = int(argv[i + 1]); i += 2
        elif a == "--drop":
            opt["drop"].append(argv[i + 1]); i += 2
        elif a == "--opaque":
            opt["opaque"] = True; i += 1
        elif a == "--auto-tex":
            opt["auto_tex"] = True; i += 1
        else:
            raise SystemExit("unknown option " + a)
    return opt


def sanitize(name):
    name = re.sub(r"[^A-Za-z0-9_]+", "_", name).strip("_")
    return name or "part"


def load(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path, merge_vertices=False)
    else:
        raise SystemExit("unsupported input " + ext)


def select_only(names):
    """Keep the named objects (or every object of a collection with that name) and their children."""
    if not names:
        return
    keep = set()
    for n in names:
        if n in bpy.data.collections:
            for o in bpy.data.collections[n].all_objects:
                keep.add(o.name)
        elif n in bpy.data.objects:
            keep.add(n)
            stack = list(bpy.data.objects[n].children)
            while stack:
                c = stack.pop(); keep.add(c.name); stack.extend(c.children)
        else:
            raise SystemExit("no object or collection named %r" % n)
    for o in list(bpy.data.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)


def flatten(keep_rig):
    """Name Sketchfab's 'defaultMaterial' meshes after their parent empties, bake every transform into the mesh data,
    drop empties and (unless keep_rig) armatures and their modifiers."""
    for o in list(bpy.data.objects):
        if o.type == "MESH" and re.fullmatch(r"defaultMaterial(\.\d+)?", o.name) and o.parent is not None and o.parent.type == "EMPTY":
            wanted = o.parent.name
            o.parent.name = "__empty__" + wanted
            o.name = wanted
    view = bpy.context.view_layer
    for o in bpy.data.objects:
        o.hide_set(False); o.hide_viewport = False
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type == "MESH":
            if not keep_rig:
                for m in list(o.modifiers):
                    if m.type == "ARMATURE":
                        o.modifiers.remove(m)
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
            o.select_set(True)
            view.objects.active = o
    if bpy.context.selected_objects:
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in list(bpy.data.objects):
        if o.type == "EMPTY" or (o.type == "ARMATURE" and not keep_rig) or o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o, do_unlink=True)


def split_by_groups(obj, mapping, min_faces):
    """One object per (mapped) vertex-group name; faces follow their dominant group."""
    me = obj.data
    if not obj.vertex_groups:
        return [obj]
    gnames = [g.name for g in obj.vertex_groups]
    poly_target = []
    counts = {}
    for p in me.polygons:
        acc = {}
        for vi in p.vertices:
            for g in me.vertices[vi].groups:
                acc[g.group] = acc.get(g.group, 0.0) + g.weight
        g = gnames[max(acc, key=acc.get)] if acc else "body"
        t = mapping.get(g, sanitize(g))
        poly_target.append(t)
        counts[t] = counts.get(t, 0) + 1
    biggest = max(counts, key=counts.get)
    for i, t in enumerate(poly_target):
        if counts[t] < min_faces:
            poly_target[i] = biggest
    targets = {}
    for i, t in enumerate(poly_target):
        targets.setdefault(t, set()).add(i)
    out = []
    for t, polys in targets.items():
        new = obj.copy()
        new.data = me.copy()
        new.name = t
        new.data.name = t
        for c in obj.users_collection:
            c.objects.link(new)
        bm = bmesh.new()
        bm.from_mesh(new.data)
        bm.faces.ensure_lookup_table()
        doomed = [f for f in bm.faces if f.index not in polys]
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(new.data)
        bm.free()
        new.vertex_groups.clear()
        for m in list(new.modifiers):
            new.modifiers.remove(m)
        out.append(new)
    bpy.data.objects.remove(obj, do_unlink=True)
    return out


def rename_objects(mapping):
    for o in list(bpy.data.objects):
        if o.name in mapping:
            o.name = mapping[o.name]
        elif sanitize(o.name) in mapping:
            o.name = mapping[sanitize(o.name)]
        else:
            o.name = sanitize(o.name)
    # objects mapped to one name: join them
    by_name = {}
    for o in bpy.data.objects:
        if o.type == "MESH":
            by_name.setdefault(o.name.split(".")[0], []).append(o)
    for base, objs in by_name.items():
        if len(objs) > 1:
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.object.join()
            objs[0].name = base
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.data.name = o.name


def _classify_image_node(mat, node):
    """albedo / normal / orm / emissive / tex, by where the image node's colour goes."""
    for link in mat.node_tree.links:
        if link.from_node != node:
            continue
        to = link.to_node
        sock = link.to_socket.name
        if to.type == "BSDF_PRINCIPLED":
            if sock == "Base Color":
                return "albedo"
            if sock.startswith("Emission"):
                return "emissive"
            if sock in ("Metallic", "Roughness"):
                return "orm"
            if sock == "Alpha":
                return "albedo"
        if to.type == "NORMAL_MAP":
            return "normal"
        if to.type in ("SEPARATE_COLOR", "SEPRGB", "GROUP"):
            return "orm"
        if to.type == "MIX_SHADER" or to.type == "EMISSION":
            return "emissive"
    return "tex"


def _material_extent(mat):
    """Longest bbox side (metres) of the geometry using this material."""
    mn = [1e9] * 3; mx = [-1e9] * 3; any_ = False
    for o in bpy.data.objects:
        if o.type != "MESH" or mat.name not in [m.name for m in o.data.materials if m]:
            continue
        slots = [i for i, m in enumerate(o.data.materials) if m and m.name == mat.name]
        for p in o.data.polygons:
            if p.material_index in slots:
                for vi in p.vertices:
                    co = o.matrix_world @ o.data.vertices[vi].co
                    any_ = True
                    for k in range(3):
                        mn[k] = min(mn[k], co[k]); mx[k] = max(mx[k], co[k])
    return max(mx[k] - mn[k] for k in range(3)) if any_ else 0.0


def prepare_textures(stem, max_tex, drop_black_emissive, auto_tex=False):
    used = {}
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.users == 0:
            continue
        for node in list(mat.node_tree.nodes):
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            kind = _classify_image_node(mat, node)
            img = node.image
            if drop_black_emissive and kind == "emissive" and _is_black(img):
                mat.node_tree.nodes.remove(node)
                continue
            used.setdefault(img.name, (img, mat, kind))
    report = []
    extents = {}
    for key, (img, mat, kind) in used.items():
        w, h = img.size
        if w == 0 or h == 0:
            print("WARN image has no pixels:", img.name, img.filepath)
            continue
        cap = max_tex
        if auto_tex and max_tex > 0:
            if mat.name not in extents:
                extents[mat.name] = _material_extent(mat)
            ext = extents[mat.name]
            cap = max_tex if ext >= 0.6 else (max_tex // 2 if ext >= 0.25 else max_tex // 4)
        if cap > 0 and max(w, h) > cap:
            f = 1
            while max(w, h) / (f * 2) >= cap:
                f *= 2
            img.scale(max(1, w // f), max(1, h // f))
        _force_png(img)
        new_name = "%s_%s_%s" % (stem, sanitize(mat.name).lower(), kind)
        if new_name in bpy.data.images and bpy.data.images[new_name] is not img:
            n = 2
            while "%s%d" % (new_name, n) in bpy.data.images:
                n += 1
            new_name = "%s%d" % (new_name, n)
        img.name = new_name
        img.filepath_raw = "//textures/" + new_name + ".png"
        report.append({"name": new_name, "kind": kind, "material": mat.name, "size": list(img.size), "was": [w, h],
                       "material_extent_m": round(extents.get(mat.name, 0.0), 3)})
    return report


def _force_png(img):
    """Re-encode the image as PNG inside the .blend (packed) so the glTF exporter writes a PNG whatever the source
    file was (it copies untouched JPEG bytes verbatim otherwise)."""
    try:
        import numpy as np
        w, h = img.size
        px = np.empty(w * h * img.channels, dtype=np.float32)
        img.pixels.foreach_get(px)
        if img.packed_file is not None:
            img.unpack(method="REMOVE")
        img.file_format = "PNG"
        img.pixels.foreach_set(px)   # marks the image dirty: pack() encodes the pixels with file_format
        img.pack()
    except Exception as e:  # noqa
        print("WARN force_png failed:", img.name, e)


def _is_black(img):
    try:
        import numpy as np
        w, h = img.size
        if w == 0:
            return True
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        return float(px.reshape(-1, 4)[:, :3].max()) < 0.02
    except Exception as e:  # noqa
        print("WARN black check failed:", e)
        return False


def bbox_of(objs):
    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    for o in objs:
        for v in o.data.vertices:
            co = o.matrix_world @ v.co
            for k in range(3):
                mn[k] = min(mn[k], co[k]); mx[k] = max(mx[k], co[k])
    return mn, mx


def to_gltf(v):
    """Blender (x, y, z; Z up, -Y forward) to glTF/Godot (x, z, -y; Y up)."""
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def forward_guess(objs, mn, mx):
    """The gun's long axis; the muzzle end has the smaller cross-section."""
    ext = [mx[k] - mn[k] for k in range(3)]
    axis = ext.index(max(ext))
    lo = mn[axis] + ext[axis] * 0.12
    hi = mx[axis] - ext[axis] * 0.12
    others = [k for k in range(3) if k != axis]
    lo_mn = [1e9, 1e9]; lo_mx = [-1e9, -1e9]; hi_mn = [1e9, 1e9]; hi_mx = [-1e9, -1e9]
    for o in objs:
        for v in o.data.vertices:
            co = o.matrix_world @ v.co
            if co[axis] <= lo:
                for j, k in enumerate(others):
                    lo_mn[j] = min(lo_mn[j], co[k]); lo_mx[j] = max(lo_mx[j], co[k])
            elif co[axis] >= hi:
                for j, k in enumerate(others):
                    hi_mn[j] = min(hi_mn[j], co[k]); hi_mx[j] = max(hi_mx[j], co[k])
    lo_area = max(0.0, lo_mx[0] - lo_mn[0]) * max(0.0, lo_mx[1] - lo_mn[1])
    hi_area = max(0.0, hi_mx[0] - hi_mn[0]) * max(0.0, hi_mx[1] - hi_mn[1])
    sign = "+" if hi_area < lo_area else "-"
    # Blender axis -> glTF axis name
    gl = {0: "X", 1: "Z", 2: "Y"}[axis]
    if axis == 1:  # Blender +Y is glTF -Z
        sign = "-" if sign == "+" else "+"
    return sign + gl, {"muzzle_end_area": round(min(lo_area, hi_area), 5), "butt_end_area": round(max(lo_area, hi_area), 5)}


def fix_materials(js, opaque):
    """T-098: an emissiveFactor with no emissive texture (Sketchfab's exporter leaves [1,1,1] behind once the black
    emissive map is dropped) would make every plain loader draw the gun glowing white: it is removed. With `opaque`,
    alphaMode BLEND / MASK becomes OPAQUE. Same rules as tools/glb_sanitize.py (for GLBs already converted)."""
    for m in js.get("materials", []):
        if "emissiveTexture" not in m and "emissiveFactor" in m:
            del m["emissiveFactor"]
        ext = m.get("extensions", {})
        if "emissiveTexture" not in m and "KHR_materials_emissive_strength" in ext:
            del ext["KHR_materials_emissive_strength"]
        if opaque and m.get("alphaMode", "OPAQUE") != "OPAQUE":
            m.pop("alphaMode", None)
            m.pop("alphaCutoff", None)


def export(out_glb, opaque=False):
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("nothing to export")
    tmp = tempfile.mkdtemp(prefix="glb_")
    gltf_path = os.path.join(tmp, "model.gltf")
    bpy.ops.object.select_all(action="DESELECT")
    kwargs = dict(filepath=gltf_path, export_format="GLTF_SEPARATE", export_texture_dir="textures",
                  export_image_format="AUTO", export_apply=True, export_yup=True, export_animations=False,
                  export_skins=False, export_morph=False, export_materials="EXPORT", export_extras=False,
                  use_selection=False, export_texcoords=True, export_normals=True, export_tangents=False,
                  export_keep_originals=False, export_cameras=False, export_lights=False)
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        for k in ("export_morph", "export_cameras", "export_lights", "export_keep_originals"):
            kwargs.pop(k, None)
        bpy.ops.export_scene.gltf(**kwargs)
    with open(gltf_path, "r", encoding="utf-8") as f:
        js = json.load(f)
    fix_materials(js, opaque)
    bins = js.get("buffers", [])
    if len(bins) != 1 or "uri" not in bins[0]:
        raise SystemExit("expected one external .bin buffer, got %r" % bins)
    with open(os.path.join(tmp, bins[0]["uri"]), "rb") as f:
        bin_data = f.read()
    out_dir = os.path.dirname(os.path.abspath(out_glb))
    tex_out = os.path.join(out_dir, "textures")
    if os.path.isdir(tex_out):
        shutil.rmtree(tex_out)
    os.makedirs(tex_out, exist_ok=True)
    written = []
    for im in js.get("images", []):
        uri = im.get("uri")
        if uri is None:
            raise SystemExit("embedded image in a separate export?")
        src = os.path.join(tmp, uri.replace("/", os.sep))
        want = im.get("name") or os.path.splitext(os.path.basename(src))[0]
        want = sanitize(os.path.splitext(want)[0]) if not want.lower().endswith(".png") else sanitize(want[:-4])
        name = want + ".png"
        if not src.lower().endswith(".png"):
            # the exporter kept another format: re-encode through Blender as PNG
            img = bpy.data.images.load(src)
            img.update()
            bpy.context.scene.render.image_settings.file_format = "PNG"
            bpy.context.scene.render.image_settings.color_mode = "RGBA"
            img.save_render(filepath=os.path.join(tex_out, name))
        else:
            shutil.copyfile(src, os.path.join(tex_out, name))
        if name in written:
            raise SystemExit("two images want the name " + name)
        im["uri"] = "textures/" + name
        im["mimeType"] = "image/png"
        written.append(name)
    js["buffers"] = [{"byteLength": len(bin_data)}]
    js.setdefault("asset", {})["generator"] = "GRAVELIGHT convert_to_glb.py (Blender %s)" % bpy.app.version_string
    jtxt = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jtxt += b" " * ((4 - len(jtxt) % 4) % 4)
    bin_pad = bin_data + b"\0" * ((4 - len(bin_data) % 4) % 4)
    total = 12 + 8 + len(jtxt) + 8 + len(bin_pad)
    with open(out_glb, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(jtxt), 0x4E4F534A)); f.write(jtxt)
        f.write(struct.pack("<II", len(bin_pad), 0x004E4942)); f.write(bin_pad)
    shutil.rmtree(tmp, ignore_errors=True)
    return written


def preview(path, meshes, mn, mx):
    """Side view (left) and top view (right), Workbench, one flat colour per object. Off-screen only."""
    import random
    rnd = random.Random(7)
    colors = {}
    for o in meshes:
        c = (rnd.random() * 0.7 + 0.3, rnd.random() * 0.7 + 0.3, rnd.random() * 0.7 + 0.3, 1.0)
        o.color = c
        colors[o.name] = [round(x, 2) for x in c[:3]]
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "OBJECT"
    sh.show_object_outline = True
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("W")
    scene.world.use_nodes = False
    scene.world.color = (0.18, 0.18, 0.2)
    ext = [mx[k] - mn[k] for k in range(3)]
    ctr = [(mx[k] + mn[k]) * 0.5 for k in range(3)]
    size = max(ext) * 1.15 + 0.02
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = size
    cam_data.clip_end = 100.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.use_file_extension = True
    scene.frame_set(scene.frame_start)
    tmp = tempfile.mkdtemp(prefix="pv_")
    if ext[1] > ext[0]:   # long axis is Blender Y: look along -X for the side, turn the top view to match
        views = [("side", (ctr[0] + 10.0, ctr[1], ctr[2]), (math.pi / 2, 0.0, math.pi / 2)),
                 ("top", (ctr[0], ctr[1], ctr[2] + 10.0), (0.0, 0.0, math.pi / 2))]
    else:
        views = [("side", (ctr[0], ctr[1] - 10.0, ctr[2]), (math.pi / 2, 0.0, 0.0)),
                 ("top", (ctr[0], ctr[1], ctr[2] + 10.0), (0.0, 0.0, 0.0))]
    files = []
    for name, loc, rot in views:
        cam.location = loc
        cam.rotation_euler = rot
        p = os.path.join(tmp, name + ".png")
        scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        files.append(p)
    # stack the two renders vertically into one image
    a = bpy.data.images.load(files[0]); b = bpy.data.images.load(files[1])
    w, h = a.size
    out = bpy.data.images.new("preview", w, h * 2, alpha=False)
    try:
        import numpy as np
        pa = np.empty(w * h * 4, dtype=np.float32); a.pixels.foreach_get(pa)
        pb = np.empty(w * h * 4, dtype=np.float32); b.pixels.foreach_get(pb)
        out.pixels.foreach_set(np.concatenate([pb, pa]))
    except Exception:  # noqa
        out.pixels = list(b.pixels) + list(a.pixels)
    out.file_format = "PNG"
    out.filepath_raw = path
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    out.save()
    shutil.rmtree(tmp, ignore_errors=True)
    return colors


def main():
    opt = _args()
    src = os.path.abspath(opt["in"])
    out = os.path.abspath(opt["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    stem = sanitize(os.path.splitext(os.path.basename(os.path.dirname(out)) if os.path.basename(out) == "model.glb" else os.path.basename(out))[0]).lower()
    load(src)
    select_only(opt["objects"])
    flatten(opt["keep_rig"])
    if opt["split"]:
        for o in [o for o in bpy.data.objects if o.type == "MESH"]:
            split_by_groups(o, opt["map"], opt["min_faces"])
    rename_objects(opt["map"])
    for n in opt["drop"]:
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
        else:
            print("WARN --drop: no object named", n)
    textures = prepare_textures(stem, opt["max_tex"], opt["drop_black_emissive"], opt["auto_tex"])
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    mn, mx = bbox_of(meshes)
    fwd, fwd_info = forward_guess(meshes, mn, mx)
    objs = []
    for o in meshes:
        omn, omx = bbox_of([o])
        o.data.calc_loop_triangles()
        objs.append({"name": o.name, "tris": len(o.data.loop_triangles), "verts": len(o.data.vertices),
                     "materials": [m.name for m in o.data.materials if m],
                     "bbox_min": to_gltf([omn[0], omn[1], omn[2]]), "bbox_max": to_gltf([omx[0], omx[1], omx[2]])})
    # glTF axes: (x, z, -y) swaps min/max on the third component
    for d in objs:
        a, b = d["bbox_min"], d["bbox_max"]
        d["bbox_min"], d["bbox_max"] = [min(a[0], b[0]), min(a[1], b[1]), min(a[2], b[2])], [max(a[0], b[0]), max(a[1], b[1]), max(a[2], b[2])]
    gmn, gmx = to_gltf(mn), to_gltf(mx)
    gmn, gmx = [min(gmn[k], gmx[k]) for k in range(3)], [max(gmn[k], gmx[k]) for k in range(3)]
    written = export(out, opt["opaque"])
    colors = preview(opt["preview"], meshes, mn, mx) if opt["preview"] else {}
    rep = {"in": src, "out": out, "objects": objs, "tris": sum(d["tris"] for d in objs),
           "bbox_min": gmn, "bbox_max": gmx, "size": [round(gmx[k] - gmn[k], 4) for k in range(3)],
           "axes": "glTF/Godot: +Y up", "forward_guess": fwd, "forward_info": fwd_info,
           "textures": textures, "texture_files": written, "preview_colors": colors,
           "glb_bytes": os.path.getsize(out),
           "texture_bytes": sum(os.path.getsize(os.path.join(os.path.dirname(out), "textures", n)) for n in written)}
    print("REPORT_JSON " + json.dumps(rep))


main()
