"""The Kinderhammer (`kinderhammer`), the Hammer's splitting maul: BLOCKOUT STUB, not the hero model.

Primitives only (cylinders, bevelled boxes) at the real size, with the GLB node names from
docs/gravelight/WONDER_DESIGN_SHEETS.md §3: an 0.80 m ash haft along -Z with the right hand at the origin
(0.12 m from the butt), the head at z -0.64 with the wedge edge toward -X (the leading side of the holder's
right-to-left sweep) and the poll toward +X. Melee: no sights, no reload. Built for real with HB1; never write
the output under assets/.

    blender -b -P tools_src/blender/wonder/stubs/kinderhammer_blockout.py -- --out <file.glb>

Authored in the Godot rig frame (metres, haft along -Z, +Y up, origin at the right-hand grip). Blender is Z-up
and the glTF exporter maps Blender (x, y, z) to glTF (x, z, -y), so a Godot point (gx, gy, gz) goes to B().
"""
import argparse, math, sys

import bpy
from mathutils import Matrix


def B(gx, gy, gz):
    return (gx, -gz, gy)


AXIS = {"x": (0.0, math.pi / 2, 0.0), "y": (0.0, 0.0, 0.0), "z": (math.pi / 2, 0.0, 0.0)}
MATS = {}


def mat(name, rgb, rough, metal, emit=0.0):
    m = MATS[name] = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*rgb, 1.0)
    p.inputs["Roughness"].default_value, p.inputs["Metallic"].default_value = rough, metal
    if emit > 0.0:
        p.inputs["Emission Color"].default_value, p.inputs["Emission Strength"].default_value = (*rgb, 1.0), emit


def keep_parent(o, parent):
    bpy.context.view_layer.update()
    o.parent, o.matrix_parent_inverse = parent, parent.matrix_world.inverted()
    return o


def node(name, at, parent=None):
    """An empty: a GLB node (a moving part's pivot, a marker, or the root)."""
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = B(*at)
    return keep_parent(e, parent) if parent is not None else e


def finish(o, name, m, parent, bevel):
    o.name = name
    o.data.materials.append(MATS[m])
    if bevel > 0.0:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width, mod.segments = bevel, 2
    return keep_parent(o, parent)


def box(name, size, at, m, parent, bevel=0.002, rot=(0, 0, 0)):
    """size and rot (degrees) in the Godot frame."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=B(*at))
    o = bpy.context.active_object
    o.data.transform(Matrix.Diagonal((size[0], size[2], size[1], 1.0)))
    o.rotation_euler = (math.radians(rot[0]), -math.radians(rot[2]), math.radians(rot[1]))
    return finish(o, name, m, parent, bevel)


def cyl(name, r, length, at, axis, m, parent, r_end=None, verts=24, bevel=0.0):
    """Along Godot `axis`; for "z", `r` is the front (-Z) radius and `r_end` the back one."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r_end is None else r_end,
                                    depth=length, location=B(*at), rotation=AXIS[axis])
    return finish(bpy.context.active_object, name, m, parent, bevel)


def ring(name, r, thick, at, axis, m, parent):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=thick, major_segments=24, minor_segments=8,
                                     location=B(*at), rotation=AXIS[axis])
    return finish(bpy.context.active_object, name, m, parent, 0.0)


def build():
    mat("ash", (0.55, 0.42, 0.28), 0.55, 0.0)
    mat("ash_dark", (0.30, 0.21, 0.13), 0.65, 0.0)
    mat("iron", (0.16, 0.15, 0.14), 0.45, 1.0)
    mat("edge", (0.55, 0.55, 0.56), 0.25, 1.0)
    mat("twine", (0.16, 0.12, 0.08), 0.95, 0.0)
    mat("leather", (0.22, 0.14, 0.08), 0.60, 0.0)
    root = node("kinderhammer", (0, 0, 0))
    root["reload"] = "none"
    root["length"] = 0.80
    # haft: oval, its long axis in line with the head (X); butt swell and leather thong
    box("Haft", (0.035, 0.028, 0.76), (0, 0, -0.26), "ash", root, 0.011)
    box("Swell", (0.042, 0.034, 0.05), (0, 0, 0.095), "ash", root, 0.014)
    ring("Thong", 0.016, 0.003, (0, 0, 0.13), "x", "leather", root)
    for i in range(3):   # three small notches near the butt, one per cousin (sheet §3, open question 1)
        box("Notch%d" % i, (0.012, 0.003, 0.002), (0, 0.0145, 0.03 + 0.012 * i), "ash_dark", root, 0.0)
    cyl("Whipping", 0.021, 0.03, (0, 0, -0.585), "z", "twine", root)
    # the head, poll (+X) to wedge edge (-X); the Head node carries the throw glow (sheet §3)
    head = node("Head", (0, 0, -0.64), root)
    box("Poll", (0.03, 0.06, 0.075), (0.075, 0, -0.64), "iron", head, 0.006)
    box("Cheeks", (0.08, 0.05, 0.075), (0.02, 0, -0.64), "iron", head, 0.004)
    box("Taper", (0.05, 0.03, 0.072), (-0.045, 0, -0.64), "iron", head, 0.003)
    box("Edge", (0.04, 0.01, 0.07), (-0.09, 0, -0.64), "edge", head, 0.002)
    box("Wedge", (0.03, 0.008, 0.004), (0, 0, -0.679), "iron", head, 0.0)
    box("WoodWedge", (0.026, 0.004, 0.003), (0, 0.007, -0.6785), "ash_dark", head, 0.0)
    # markers
    node("Muzzle", (-0.11, 0, -0.64), root)    # the striking edge (the knife's convention)
    node("Spin", (0, 0, -0.50), root)          # the balance point the thrown copy spins about (new)
    node("LeftHand", (0, 0, -0.30), root)      # support hand for the two-hand swing / throw wind-up


def tris():
    dg = bpy.context.evaluated_depsgraph_get()
    return sum(len(o.evaluated_get(dg).data.loop_triangles) for o in bpy.context.scene.objects if o.type == "MESH")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build()
    print("kinderhammer blockout: %d tris" % tris())
    bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB", export_yup=True, export_apply=True,
                              export_extras=True)
