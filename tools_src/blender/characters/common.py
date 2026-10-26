"""Shared helpers for the GRAVELIGHT character scripts (T-091, docs/CHARACTER_PIPELINE.md).

Everything here works in **Godot's frame** (metres, +Y up, the face toward -Z, the character's left at -X), the
frame of the ZombieRig (gravelight/enemies/zombie_rig.gd) exported by tools/export_rig.gd to rig.json. Blender is
Z-up with -Y forward, and its glTF exporter maps Blender (x, y, z) to glTF (x, z, -y); so a point (gx, gy, gz) is
created in Blender at (gx, -gz, gy) and comes back out of the GLB at exactly (gx, gy, gz).

The pieces:
- rig.json loading (bone heads, parents, children);
- mesh objects from numpy arrays (Godot frame in, Blender frame inside);
- bone weights as plain numpy arrays (N x 4 bone indices + N x 4 weights against the rig's bone order), written
  as vertex groups named after the rig bones so the GLB skin's joints carry our names;
- an armature built from rig.json (identity rest rotations in Godot terms: every bone's head is the rig's rest
  position; the tail only gives Blender a direction and length);
- the glTF export call.
"""
import json
import math
import os

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RIG_PATH = os.path.join(HERE, "rig.json")


# ---------------------------------------------------------------- rig

class Rig:
    def __init__(self, path=RIG_PATH):
        with open(path, encoding="utf-8") as f:
            self.data = json.load(f)
        self.bones = [b["name"] for b in self.data["bones"]]
        self.index = {n: i for i, n in enumerate(self.bones)}
        self.parent = {b["name"]: b["parent"] for b in self.data["bones"]}
        self.head = {b["name"]: np.array(b["head"], dtype=np.float64) for b in self.data["bones"]}
        self.children = {b["name"]: list(b["children"]) for b in self.data["bones"]}
        self.hitboxes = self.data["hitboxes"]
        self.builds = self.data["builds"]

    def chain_of(self, bone):
        out = [bone]
        i = 0
        while i < len(out):
            out.extend(self.children[out[i]])
            i += 1
        return out


# ---------------------------------------------------------------- frames

def g2b(p):
    """Godot (x, y, z) -> Blender (x, -z, y). Works on (3,) or (N, 3)."""
    p = np.asarray(p, dtype=np.float64)
    return np.stack([p[..., 0], -p[..., 2], p[..., 1]], axis=-1)


def b2g(p):
    p = np.asarray(p, dtype=np.float64)
    return np.stack([p[..., 0], p[..., 2], -p[..., 1]], axis=-1)


# ---------------------------------------------------------------- scene / mesh helpers

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def mesh_from_arrays(name, verts_g, faces, uvs=None):
    """A mesh object from Godot-frame vertices and polygon index lists (any n-gon)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in g2b(verts_g)], [], [list(f) for f in faces])
    me.update()
    ob = bpy.data.objects.new(name, me)
    link(ob)
    if uvs is not None:
        set_loop_uvs(ob, uvs)
    return ob


def mesh_arrays(ob, evaluated=True):
    """(verts Godot frame (N,3), list of polygons) of an object, modifiers applied when evaluated."""
    if evaluated:
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
    else:
        me = ob.data
    n = len(me.vertices)
    co = np.zeros(n * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(n, 3)
    mw = np.array(ob.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    faces = [list(p.vertices) for p in me.polygons]
    if evaluated:
        ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    return b2g(co), faces


def set_verts(ob, verts_g):
    me = ob.data
    flat = g2b(verts_g).astype(np.float32).ravel()
    me.vertices.foreach_set("co", flat)
    me.update()


def get_verts(ob):
    me = ob.data
    n = len(me.vertices)
    co = np.zeros(n * 3)
    me.vertices.foreach_get("co", co)
    return b2g(co.reshape(n, 3))


def tri_count(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def set_loop_uvs(ob, loop_uvs, name="UVMap"):
    me = ob.data
    if name not in me.uv_layers:
        me.uv_layers.new(name=name)
    me.uv_layers[name].data.foreach_set("uv", np.asarray(loop_uvs, dtype=np.float32).ravel())


def get_loop_uvs(ob, name="UVMap"):
    me = ob.data
    n = len(me.loops)
    a = np.zeros(n * 2, dtype=np.float32)
    me.uv_layers[name].data.foreach_get("uv", a)
    return a.reshape(n, 2)


def select_only(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def apply_modifiers(ob):
    select_only(ob)
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def smart_uv(ob, margin=0.004, angle=66.0):
    select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=1.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def scale_face_uvs(ob, face_mask, factor):
    """Scales the UVs of the masked faces (about their own centre) and re-packs every island: gives the head and the
    hands more texels than smart_project's area weighting would."""
    me = ob.data
    uv = get_loop_uvs(ob)
    starts = np.zeros(len(me.polygons), dtype=np.int64)
    sizes = np.zeros(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_start", starts)
    me.polygons.foreach_get("loop_total", sizes)
    sel = np.zeros(len(uv), dtype=bool)
    for fi in np.where(face_mask)[0]:
        sel[starts[fi]:starts[fi] + sizes[fi]] = True
    c = uv[sel].mean(axis=0)
    uv[sel] = c + (uv[sel] - c) * factor
    set_loop_uvs(ob, uv)
    select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")


def shade_smooth(ob, auto_angle=None):
    me = ob.data
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.update()


def join(objs, name):
    """Joins objects into the first; returns it renamed."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


# ---------------------------------------------------------------- per-vertex data

def set_color_attr(ob, rgba, name="Col"):
    """A per-vertex (POINT) float colour attribute (glTF COLOR_0)."""
    me = ob.data
    if name in me.color_attributes:
        me.color_attributes.remove(me.color_attributes[name])
    attr = me.color_attributes.new(name=name, type="FLOAT_COLOR", domain="POINT")
    attr.data.foreach_set("color", np.asarray(rgba, dtype=np.float32).ravel())
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = me.color_attributes.find(name)
    return attr


def set_weights(ob, rig, bones_idx, weights):
    """Vertex groups from (N,4) rig bone indices + (N,4) weights (rows sum to 1)."""
    ob.vertex_groups.clear()
    groups = {}
    for b in rig.bones:
        groups[b] = ob.vertex_groups.new(name=b)
    n = bones_idx.shape[0]
    for vi in range(n):
        for k in range(bones_idx.shape[1]):
            w = float(weights[vi, k])
            if w > 1e-4:
                groups[rig.bones[int(bones_idx[vi, k])]].add([vi], w, "REPLACE")


def get_weights(ob, rig, k=4):
    """(N,k) bone indices + weights from the vertex groups (sorted by weight, normalised)."""
    me = ob.data
    n = len(me.vertices)
    bi = np.zeros((n, k), dtype=np.int32)
    bw = np.zeros((n, k), dtype=np.float64)
    names = {g.index: g.name for g in ob.vertex_groups}
    for v in me.vertices:
        gs = sorted(((g.weight, rig.index.get(names[g.group], 0)) for g in v.groups if g.weight > 1e-4), reverse=True)[:k]
        for j, (w, b) in enumerate(gs):
            bi[v.index, j] = b
            bw[v.index, j] = w
    s = bw.sum(axis=1, keepdims=True)
    s[s <= 0] = 1.0
    return bi, bw / s


# ---------------------------------------------------------------- armature

def build_armature(rig, name="Armature"):
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    link(ob)
    select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for b in rig.bones:
        e = arm.edit_bones.new(b)
        h = rig.head[b]
        kids = rig.children[b]
        if b == "Root":
            t = h + np.array([0.0, 0.0, -0.15])   # Root lies flat, pointing forward
        elif kids and b not in ("Hips", "Chest"):
            t = rig.head[kids[0]]
        elif b == "Hips":
            t = rig.head["Spine"] + np.array([0.0, 0.05, 0.0])
        elif b == "Chest":
            t = rig.head["Neck"]
        else:
            par = rig.parent[b]
            d = h - rig.head[par]
            if np.linalg.norm(d) < 1e-6:
                d = np.array([0.0, 0.1, 0.0])
            t = h + d / np.linalg.norm(d) * (0.08 if b in ("Head", "Jaw") else 0.1)
            if b == "Head":
                t = h + np.array([0.0, 0.2, 0.0])
            if b == "Jaw":
                t = h + np.array([0.0, -0.04, -0.08])
            if b.endswith("Foot"):
                t = h + np.array([0.0, -0.04, -0.14])
            if b.endswith("Hand"):
                t = h + np.array([0.0, -0.16, 0.0])
        if np.linalg.norm(t - h) < 1e-4:
            t = h + np.array([0.0, 0.05, 0.0])
        e.head = tuple(g2b(h))
        e.tail = tuple(g2b(t))
        e.roll = 0.0
        eb[b] = e
    for b in rig.bones:
        p = rig.parent[b]
        if p:
            eb[b].parent = eb[p]
            eb[b].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def bind(mesh_ob, arm_ob):
    mesh_ob.parent = arm_ob
    m = mesh_ob.modifiers.new("Armature", "ARMATURE")
    m.object = arm_ob


# ---------------------------------------------------------------- export

def export_glb(path, objects, arm_ob=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    if arm_ob is not None:
        arm_ob.select_set(True)
        bpy.context.view_layer.objects.active = arm_ob
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_materials="PLACEHOLDER",
        export_skins=True,
        export_all_influences=False,
        export_def_bones=False,
        export_animations=False,
        export_morph=True,
        export_extras=True,
    )


# ---------------------------------------------------------------- small maths

def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def gauss(d2, r):
    return np.exp(-d2 / (r * r))


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0.0], [s, c, 0.0], [0.0, 0.0, 1.0]])


def seg_dist(p, a, b):
    """Distance from points p (N,3) to segment a-b, and the clamped parameter t."""
    ab = b - a
    l2 = max(float(ab @ ab), 1e-12)
    t = np.clip(((p - a) @ ab) / l2, 0.0, 1.0)
    proj = a + t[:, None] * ab
    return np.linalg.norm(p - proj, axis=1), t


def top_k_weights(raw, k=4, prune=0.04):
    """raw (N, B) non-negative weights -> (N,k) indices + normalised weights, tiny influences pruned."""
    idx = np.argsort(-raw, axis=1)[:, :k]
    w = np.take_along_axis(raw, idx, axis=1)
    s = w.sum(axis=1, keepdims=True)
    s[s <= 0] = 1.0
    w = w / s
    w[w < prune] = 0.0
    s = w.sum(axis=1, keepdims=True)
    s[s <= 0] = 1.0
    return idx.astype(np.int32), w / s
