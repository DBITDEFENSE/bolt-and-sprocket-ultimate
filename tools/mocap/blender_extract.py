"""Blender headless side of the mocap pipeline (T-210): an FBX or BVH capture -> the motion JSON mocaplib reads.

    "$BLENDER" -b --factory-startup --python tools/mocap/blender_extract.py -- <in.fbx|in.bvh> <out.motion.json>
    "$BLENDER" -b --factory-startup --python tools/mocap/blender_extract.py -- --to-fbx <in.bvh> <out.fbx>

Imports the file into an empty scene, takes the armature with the most bones, and writes for every bone its rest
world position / rotation and, per frame of its action, its world position / rotation, converted to Godot's frame
(+Y up: a Blender point (x, y, z) is Godot (x, z, -y)). Leaf bones also get a "<bone>_end" joint at their tail so a
head, hand or toe has a direction. The retarget (bone names, the rest-pose match, foot lock, smoothing) is all in
mocaplib.py, so FBX and BVH go through the same maths. `--to-fbx` re-exports a BVH as FBX (the tests make their
synthetic FBX clip this way).
"""
import json
import math
import sys

import bpy
from mathutils import Matrix

C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))   # Blender -> Godot
CT = C.transposed()


def _reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _import(path):
    low = path.lower()
    if low.endswith(".bvh"):
        bpy.ops.import_anim.bvh(filepath=path, axis_forward="-Z", axis_up="Y", update_scene_fps=True,
                                update_scene_duration=True, rotate_mode="NATIVE")
    elif low.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False, ignore_leaf_bones=False)
    else:
        raise SystemExit("not a .fbx or .bvh: " + path)
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not arms:
        raise SystemExit("no armature in " + path)
    return max(arms, key=lambda o: len(o.data.bones))


def _frame_range(ob):
    ad = ob.animation_data
    if ad is not None and ad.action is not None:
        a, b = ad.action.frame_range
        return int(math.floor(a)), int(math.ceil(b))
    sc = bpy.context.scene
    return sc.frame_start, sc.frame_end


def _rq(m3):
    """A Godot-frame rotation (w, x, y, z) from a Blender world 3x3 (scale removed)."""
    g = C @ m3 @ CT
    q = g.to_quaternion().normalized()
    return [q.w, q.x, q.y, q.z]


def _p(v):
    g = C @ v
    return [g.x, g.y, g.z]


def extract(src, out):
    _reset()
    ob = _import(src)
    sc = bpy.context.scene
    fps = sc.render.fps / max(1e-6, sc.render.fps_base)
    bones = list(ob.data.bones)
    names = [b.name for b in bones]
    index = {n: i for i, n in enumerate(names)}
    parents = [index[b.parent.name] if b.parent else -1 for b in bones]
    leaves = [b for b in bones if not b.children]
    for b in leaves:
        names.append(b.name + "_end")
        parents.append(index[b.name])
    mw = ob.matrix_world
    rest_pos, rest_rot = [], []
    for b in bones:
        m = mw @ b.matrix_local
        rest_pos.append(_p(m.to_translation()))
        rest_rot.append(_rq(m.to_3x3().normalized()))
    for b in leaves:
        rest_pos.append(_p(mw @ b.tail_local))
        rest_rot.append(rest_rot[index[b.name]])
    f0, f1 = _frame_range(ob)
    pos, rot = [], []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        fp, fr = [], []
        for pb in ob.pose.bones:
            m = mw @ pb.matrix
            fp.append(_p(m.to_translation()))
            fr.append(_rq(m.to_3x3().normalized()))
        for b in leaves:
            pb = ob.pose.bones[b.name]
            fp.append(_p(mw @ pb.tail))
            fr.append(fr[index[b.name]])
        pos.append(fp)
        rot.append(fr)
    with open(out, "w", encoding="utf-8") as fh:
        json.dump({"fps": fps, "names": names, "parents": parents, "rest_pos": rest_pos, "rest_rot": rest_rot,
                   "pos": pos, "rot": rot, "source": src.replace("\\", "/").split("/")[-1],
                   "frames": [f0, f1], "armature": ob.name}, fh)
    print("[mocap] %s: %d bones, frames %d-%d at %.2f fps -> %s" % (src, len(bones), f0, f1, fps, out))


def to_fbx(src, out):
    _reset()
    ob = _import(src)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={"ARMATURE"}, add_leaf_bones=False,
                             bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
                             bake_anim_simplify_factor=0.0)
    print("[mocap] %s -> %s" % (src, out))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) == 3 and argv[0] == "--to-fbx":
        to_fbx(argv[1], argv[2])
    elif len(argv) == 2:
        extract(argv[0], argv[1])
    else:
        raise SystemExit(__doc__)
