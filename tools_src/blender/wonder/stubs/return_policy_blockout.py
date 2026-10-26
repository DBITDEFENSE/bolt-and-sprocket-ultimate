"""The Return Policy (`return_policy`), Helvetia Works' refund gun: BLOCKOUT STUB, not the hero model.

Primitives only (cylinders, bevelled boxes) at the real size, with the GLB node names from
docs/gravelight/WONDER_DESIGN_SHEETS.md §2: a violet-enamel handset (earpiece cup to the rear, mouthpiece grille
forward), a round grip holding the receipt roll (Mag), the punch hood (Slide), the punch lever (Trigger), the
receipt slot (Receipt) and the counter window (Dial). Built for real with Helvetia Works; never write the output
under assets/.

    blender -b -P tools_src/blender/wonder/stubs/return_policy_blockout.py -- --out <file.glb>

Authored in the Godot rig frame (metres, barrel along -Z, +Y up, origin at the right-hand grip). Blender is Z-up
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


def build():
    mat("enamel", (0.24, 0.20, 0.28), 0.25, 0.0)
    mat("chrome", (0.62, 0.62, 0.64), 0.25, 1.0)
    mat("phenolic", (0.06, 0.05, 0.05), 0.40, 0.0)
    mat("paper", (0.84, 0.80, 0.70), 0.90, 0.0)
    mat("brass", (0.55, 0.42, 0.20), 0.30, 1.0)
    mat("nachtglas", (0.55, 0.20, 1.0), 0.08, 0.0, emit=2.0)
    mat("cord", (0.12, 0.08, 0.06), 0.85, 0.0)
    root = node("return_policy", (0, 0, 0))
    root["reload"] = "pistol"
    root["length"] = 0.25
    # grip = the receipt-roll housing, raked back 12 degrees
    cyl("GripHousing", 0.022, 0.12, (0, -0.04, 0.01), "y", "enamel", root, bevel=0.004)
    for sx in (-0.019, 0.019):
        box("GripPanel%s" % ("L" if sx < 0 else "R"), (0.006, 0.08, 0.03), (sx, -0.045, 0.012), "phenolic", root)
    box("RollWindow", (0.003, 0.05, 0.012), (0.0215, -0.02, 0.0), "paper", root, 0.0)
    roll = node("Mag", (0, -0.095, 0.015), root)
    cyl("RollCap", 0.024, 0.015, (0, -0.105, 0.012), "y", "chrome", roll, bevel=0.003)
    cyl("Roll", 0.017, 0.06, (0, -0.065, 0.012), "y", "paper", roll)
    cyl("CordStub", 0.004, 0.06, (0, -0.145, 0.015), "y", "cord", root, verts=12)
    cyl("CordFerrule", 0.006, 0.012, (0, -0.117, 0.015), "y", "brass", root, verts=12)
    # the handset bar, earpiece cup (rear, facing the player) and mouthpiece (front)
    box("HandsetBar", (0.036, 0.04, 0.20), (0, 0.045, -0.05), "enamel", root, 0.01)
    cyl("Earpiece", 0.026, 0.03, (0, 0.045, 0.06), "z", "enamel", root, r_end=0.03, bevel=0.004)
    dial = node("Dial", (0, 0.045, 0.076), root)
    cyl("CounterFace", 0.016, 0.003, (0, 0.045, 0.076), "z", "paper", dial)
    cyl("Mouthpiece", 0.034, 0.04, (0, 0.045, -0.165), "z", "enamel", root, r_end=0.024, bevel=0.004)
    cyl("Grille", 0.030, 0.004, (0, 0.045, -0.186), "z", "chrome", root)
    cyl("Lens", 0.012, 0.006, (0, 0.045, -0.189), "z", "nachtglas", root)
    box("LogoInlay", (0.002, 0.024, 0.024), (-0.0185, 0.045, -0.06), "brass", root, 0.0)
    # punch hood (Slide) carrying the rear notch; front bead on the mouthpiece rim
    slide = node("Slide", (0, 0.07, -0.03), root)
    box("Hood", (0.03, 0.012, 0.15), (0, 0.07, -0.03), "chrome", slide, 0.003)
    for sx in (-0.006, 0.006):
        box("Notch%s" % ("L" if sx < 0 else "R"), (0.004, 0.01, 0.006), (sx, 0.081, 0.042), "chrome", slide, 0.0)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.004, segments=12, ring_count=6, location=B(0, 0.081, -0.16))
    finish(bpy.context.active_object, "Bead", "chrome", root, 0.0)
    # punch lever (Trigger), pivoting at its front
    lever = node("Trigger", (0, 0.02, -0.09), root)
    box("Lever", (0.012, 0.012, 0.08), (0, 0.008, -0.05), "chrome", lever, 0.003, rot=(-15, 0, 0))
    # receipt slot, stub and tear bar on the right flank
    box("Slot", (0.004, 0.02, 0.03), (0.019, 0.035, 0.0), "phenolic", root, 0.0)
    receipt = node("Receipt", (0.02, 0.035, 0.0), root)
    box("Stub", (0.001, 0.018, 0.028), (0.026, 0.035, 0.0), "paper", receipt, 0.0)
    box("TearBar", (0.003, 0.022, 0.004), (0.021, 0.035, 0.017), "chrome", root, 0.0)
    # markers
    node("Muzzle", (0, 0.045, -0.19), root)
    node("SightPoint", (0, 0.085, 0.045), slide)
    node("FrontSight", (0, 0.085, -0.16), root)
    node("LeftHand", (-0.006, -0.042, 0.052), root)
    node("UpRing", (0, 0.045, -0.187), root)   # No Questions Asked: the Nachtglas ring round the grille (hidden on base)


def tris():
    dg = bpy.context.evaluated_depsgraph_get()
    return sum(len(o.evaluated_get(dg).data.loop_triangles) for o in bpy.context.scene.objects if o.type == "MESH")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build()
    print("return_policy blockout: %d tris" % tris())
    bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB", export_yup=True, export_apply=True,
                              export_extras=True)
