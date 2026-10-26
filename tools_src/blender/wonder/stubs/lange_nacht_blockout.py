"""Die Lange Nacht (`lange_nacht`), Morgenrot's LOX cryo-lance: BLOCKOUT STUB, not the hero model.

Primitives only (cylinders, bevelled boxes) at the real size, with the GLB node names from
docs/gravelight/WONDER_DESIGN_SHEETS.md §1, so scale, hand fit and the sight line can be checked before the
hero model (tools_src/blender/wonder/lange_nacht.py, built with Morgenrot in M8.5) exists. Never write the output
under assets/.

    blender -b -P tools_src/blender/wonder/stubs/lange_nacht_blockout.py -- --out <file.glb>

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
    mat("steel", (0.30, 0.31, 0.32), 0.35, 1.0)
    mat("blued", (0.10, 0.11, 0.12), 0.40, 1.0)
    mat("brass", (0.55, 0.42, 0.20), 0.30, 1.0)
    mat("felt", (0.42, 0.41, 0.39), 0.92, 0.0)
    mat("rubber", (0.06, 0.06, 0.06), 0.60, 0.0)
    mat("cream", (0.85, 0.81, 0.72), 0.30, 0.0)
    mat("iron", (0.05, 0.05, 0.05), 0.50, 0.9)
    root = node("lange_nacht", (0, 0, 0))
    root["reload"] = "fuel"
    root["length"] = 0.78
    # firing grip and regulator (the dam part)
    box("Grip", (0.03, 0.10, 0.035), (0, -0.045, 0.012), "rubber", root, 0.006, rot=(-15, 0, 0))
    box("TriggerGuard", (0.006, 0.006, 0.05), (0, -0.02, -0.03), "blued", root)
    box("Regulator", (0.05, 0.06, 0.10), (0, 0.05, -0.02), "brass", root, 0.006)
    cyl("GaugeBody", 0.02, 0.012, (-0.031, 0.06, -0.02), "x", "brass", root)
    dial = node("Dial", (-0.038, 0.06, -0.02), root)
    cyl("GaugeFace", 0.017, 0.002, (-0.038, 0.06, -0.02), "x", "cream", dial)
    box("Needle", (0.002, 0.014, 0.002), (-0.040, 0.066, -0.02), "iron", dial, 0.0)
    valve = node("Valve", (0, 0.05, 0.06), root)
    ring("Handwheel", 0.022, 0.004, (0, 0.05, 0.06), "z", "iron", valve)
    for i in range(2):
        box("Spoke%d" % i, (0.044, 0.005, 0.005), (0, 0.05, 0.06), "iron", valve, 0.0, rot=(0, 0, 90 * i))
    cyl("Hub", 0.007, 0.03, (0, 0.05, 0.045), "z", "iron", root)
    # rear notch on the regulator top
    for sx in (-0.006, 0.006):
        box("Notch%s" % ("L" if sx < 0 else "R"), (0.004, 0.015, 0.006), (sx, 0.0875, 0.0), "brass", root, 0.0)
    # lance, lagging and nozzle (the Assembly Hall part)
    cyl("LanceTube", 0.016, 0.55, (0, 0.05, -0.345), "z", "blued", root)
    cyl("Lagging", 0.026, 0.30, (0, 0.05, -0.25), "z", "felt", root, bevel=0.004)
    for i, z in enumerate((-0.11, -0.25, -0.39)):
        cyl("Binding%d" % i, 0.028, 0.006, (0, 0.05, z), "z", "steel", root)
    cyl("Collar", 0.026, 0.012, (0, 0.05, -0.60), "z", "brass", root)
    box("FrontPost", (0.004, 0.03, 0.006), (0, 0.08, -0.60), "blued", root, 0.0)
    cyl("Nozzle", 0.034, 0.08, (0, 0.05, -0.66), "z", "brass", root, r_end=0.02)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        box("Vane%d" % i, (0.004, 0.03, 0.06), (0.03 * math.cos(a), 0.05 + 0.03 * math.sin(a), -0.665),
            "blued", root, 0.0, rot=(0, 0, math.degrees(a) - 90))
    # the LOX flask (the depot part) slung under the lance
    flask = node("Mag", (0, -0.035, -0.26), root)
    cyl("Flask", 0.05, 0.30, (0, -0.035, -0.26), "z", "steel", flask, verts=32, bevel=0.018)
    cyl("FlaskNeck", 0.015, 0.03, (0, -0.035, -0.095), "z", "steel", flask)
    for i, z in enumerate((-0.18, -0.34)):
        cyl("Clamp%d" % i, 0.053, 0.012, (0, -0.035, z), "z", "blued", flask)
        box("Strap%d" % i, (0.012, 0.03, 0.012), (0, 0.025, z), "blued", flask, 0.0)
    cyl("Hose", 0.006, 0.07, (0, 0.0, -0.085), "y", "steel", root)
    # foregrip ahead of the flask
    cyl("Foregrip", 0.017, 0.10, (0, -0.025, -0.47), "y", "rubber", root, bevel=0.004)
    # markers
    node("Muzzle", (0, 0.05, -0.71), root)
    node("SightPoint", (0, 0.095, 0.0), root)
    node("FrontSight", (0, 0.095, -0.60), root)
    node("LeftHand", (0, -0.03, -0.47), root)
    # Polarnacht bits (sheet §1): hidden on the base weapon; marked here as empties at their spots
    node("UpCollar", (0, -0.035, -0.095), root)
    node("UpSpikes", (0, 0.05, -0.665), root)


def tris():
    dg = bpy.context.evaluated_depsgraph_get()
    return sum(len(o.evaluated_get(dg).data.loop_triangles) for o in bpy.context.scene.objects if o.type == "MESH")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build()
    print("lange_nacht blockout: %d tris" % tris())
    bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB", export_yup=True, export_apply=True,
                              export_extras=True)
