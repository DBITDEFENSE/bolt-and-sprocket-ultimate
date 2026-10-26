"""Blartz's Field-Kit Omni-Blaster (`omni_blaster`), Helvetia Works buildable: BLOCKOUT STUB, not the hero model.

Primitives only (cylinders, bevelled boxes) at the real size, with the GLB node names from
docs/gravelight/WONDER_DESIGN_SHEETS.md §4: Blartz's grip and receiver (`ob_part_grip`), a ring of exposed heat
coils round the barrel root (`ob_part_coil`) under a hinged vent shroud (Cover), the ringed ceramic emitter
(`ob_part_emitter`), the top bar (Slide), the heat tube (Gauge), and the Helvetia QA-bench hardware holding it
together. Built for real with Helvetia Works; never write the output under assets/.

    blender -b -P tools_src/blender/wonder/stubs/omni_blaster_blockout.py -- --out <file.glb>

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


def ring(name, r, thick, at, axis, m, parent):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=thick, major_segments=24, minor_segments=8,
                                     location=B(*at), rotation=AXIS[axis])
    return finish(bpy.context.active_object, name, m, parent, 0.0)


def build():
    mat("blartz_green", (0.30, 0.35, 0.29), 0.35, 0.0)
    mat("brass", (0.55, 0.42, 0.20), 0.30, 1.0)
    mat("copper", (0.80, 0.35, 0.12), 0.30, 1.0, emit=0.6)   # in game the glow follows the heat bar
    mat("ceramic", (0.81, 0.78, 0.69), 0.40, 0.0)
    mat("steel", (0.40, 0.41, 0.42), 0.45, 1.0)
    mat("tape", (0.04, 0.04, 0.04), 0.92, 0.0)
    mat("paper", (0.84, 0.80, 0.70), 0.90, 0.0)
    mat("glass", (0.20, 0.18, 0.16), 0.10, 0.0)
    root = node("omni_blaster", (0, 0, 0))
    root["reload"] = "none"   # "vent" once the holder has that kind (sheet §4)
    root["length"] = 0.32
    # Blartz's grip and receiver (ob_part_grip), the courier label taped round the grip
    for nm, sz, at, m in (("Grip", (0.034, 0.11, 0.045), (0, -0.05, 0.012), "blartz_green"),
                          ("GripTrim", (0.036, 0.008, 0.047), (0, -0.104, 0.03), "brass"),
                          ("Label", (0.037, 0.022, 0.048), (0, -0.03, 0.006), "paper"),
                          ("Tape", (0.038, 0.006, 0.049), (0, -0.017, 0.002), "tape")):
        box(nm, sz, at, m, root, 0.006 if nm == "Grip" else 0.001, rot=(-18, 0, 0))
    box("Receiver", (0.04, 0.05, 0.15), (0, 0.035, -0.035), "blartz_green", root, 0.006)
    box("Trigger", (0.006, 0.02, 0.008), (0, -0.005, -0.03), "brass", root, 0.001)
    box("TriggerGuard", (0.006, 0.006, 0.05), (0, -0.022, -0.035), "brass", root, 0.001)
    gauge = node("Gauge", (-0.022, 0.035, -0.04), root)
    cyl("HeatTube", 0.005, 0.08, (-0.022, 0.035, -0.04), "z", "glass", gauge, verts=12)
    # emitter barrel (ob_part_emitter)
    cyl("Emitter", 0.016, 0.16, (0, 0.04, -0.19), "z", "ceramic", root)
    for i, z in enumerate((-0.20, -0.235)):
        cyl("EmitterRing%d" % i, 0.02, 0.008, (0, 0.04, z), "z", "brass", root)
    cyl("MuzzleRing", 0.024, 0.02, (0, 0.04, -0.26), "z", "steel", root, r_end=0.018)
    cyl("EmitterLens", 0.01, 0.003, (0, 0.04, -0.2705), "z", "glass", root)
    # heat coil (ob_part_coil): copper turns in a steel cage, held on with two Helvetia hose clamps and a bracket
    for i in range(6):
        ring("Coil%d" % i, 0.024, 0.004, (0, 0.04, -0.115 - 0.01 * i), "z", "copper", root)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        box("CageBar%d" % i, (0.004, 0.004, 0.07), (0.031 * math.cos(a), 0.04 + 0.031 * math.sin(a), -0.14),
            "steel", root, 0.0)
    for i, z in enumerate((-0.105, -0.175)):
        cyl("HoseClamp%d" % i, 0.034, 0.006, (0, 0.04, z), "z", "steel", root)
    box("Bracket", (0.004, 0.04, 0.08), (0.024, 0.03, -0.11), "steel", root, 0.001)
    # vent shroud (Cover), hinged at its rear top edge
    cover = node("Cover", (0, 0.072, -0.105), root)
    box("Shroud", (0.064, 0.006, 0.07), (0, 0.072, -0.14), "blartz_green", cover, 0.002)
    # top bar (Slide) with the rear notch; brass front blade clamped to the muzzle ring
    slide = node("Slide", (0, 0.065, -0.02), root)
    box("TopBar", (0.026, 0.012, 0.12), (0, 0.065, -0.02), "blartz_green", slide, 0.003)
    for sx in (-0.006, 0.006):
        box("Notch%s" % ("L" if sx < 0 else "R"), (0.004, 0.012, 0.006), (sx, 0.077, 0.035), "brass", slide, 0.0)
    box("FrontBlade", (0.004, 0.019, 0.006), (0, 0.0735, -0.25), "brass", root, 0.0)
    box("QATag", (0.002, 0.03, 0.02), (0.012, -0.045, -0.05), "paper", root, 0.0)   # the Helvetia "GEPRÜFT" tag
    # markers
    node("Muzzle", (0, 0.04, -0.272), root)
    node("SightPoint", (0, 0.083, 0.035), slide)
    node("FrontSight", (0, 0.083, -0.25), root)
    node("LeftHand", (-0.006, -0.042, 0.052), root)
    node("UpFins", (0, 0.04, -0.215), root)   # Field Promotion: brass fins along the emitter (hidden on base)
    node("UpCore", (0, 0.04, -0.14), root)    # Field Promotion: the Nachtglas core inside the coil


def tris():
    dg = bpy.context.evaluated_depsgraph_get()
    return sum(len(o.evaluated_get(dg).data.loop_triangles) for o in bpy.context.scene.objects if o.type == "MESH")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build()
    print("omni_blaster blockout: %d tris" % tris())
    bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB", export_yup=True, export_apply=True,
                              export_extras=True)
