"""The mocap pipeline's maths (UPDATE 12 section 4, T-210). Pure Python + numpy, no Blender, no Godot.

    motion  = read_bvh(path)            # or the JSON blender_extract.py writes for an FBX (same shape)
    clip    = process(motion, rig, dur) # retarget + resample + trim + smooth + ground + foot lock
    write_clip(clip, out_json)          # tools/mocap/mocap_import.gd turns it into an AnimationLibrary

A *motion* is the source skeleton in the Godot frame (+Y up, metres or any unit): names, parents, rest world
positions / rotations, and per frame world positions / rotations of every joint. A *clip* is our rig's pose per frame:
the Hips position and the local rotation of every driven bone (ZombieRig rest rotations are identity, so the local
rotation is the bone's pose rotation), at a fixed fps, plus the stats the tests read (foot slide before / after).

Quaternions are numpy arrays (w, x, y, z); the clip JSON writes them Godot's way (x, y, z, w).
"""
import json
import math
import os
import re

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RIG_JSON = os.path.join(ROOT, "tools_src", "blender", "characters", "rig.json")

# the bones a clip drives (ZombieRig minus Root and Jaw: the jaw belongs to the lip sync)
DRIVEN = ["Hips", "Spine", "Chest", "Neck", "Head",
          "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
          "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"]
# the target bone each bone points at (its "child" for the direction match); None = continue the parent's line
AIM = {"Spine": "Chest", "Chest": "Neck", "Neck": "Head", "Head": None,
       "LeftUpperLeg": "LeftLowerLeg", "LeftLowerLeg": "LeftFoot", "LeftFoot": "toe",
       "RightUpperLeg": "RightLowerLeg", "RightLowerLeg": "RightFoot", "RightFoot": "toe",
       "LeftUpperArm": "LeftLowerArm", "LeftLowerArm": "LeftHand", "LeftHand": None,
       "RightUpperArm": "RightLowerArm", "RightLowerArm": "RightHand", "RightHand": None}
TOE = np.array([0.0, -0.06, -0.15])    # PersonRig's toe point from the ankle, in the foot's frame
HEEL = np.array([0.0, -0.07, 0.03])
OUT_FPS = 30.0


# ------------------------------------------------------------------ quaternions (w, x, y, z)

def qmul(a, b):
    aw, ax, ay, az = np.moveaxis(np.asarray(a, float), -1, 0)
    bw, bx, by, bz = np.moveaxis(np.asarray(b, float), -1, 0)
    return np.stack([aw * bw - ax * bx - ay * by - az * bz,
                     aw * bx + ax * bw + ay * bz - az * by,
                     aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw], axis=-1)


def qinv(q):
    q = np.asarray(q, float)
    return q * np.array([1.0, -1.0, -1.0, -1.0])


def qnorm(q):
    q = np.asarray(q, float)
    n = np.linalg.norm(q, axis=-1, keepdims=True)
    return q / np.where(n < 1e-12, 1.0, n)


def qrot(q, v):
    q = np.asarray(q, float)
    v = np.asarray(v, float)
    u = q[..., 1:]
    w = q[..., :1]
    t = 2.0 * np.cross(u, v)
    return v + w * t + np.cross(u, t)


def qaxis(axis, ang):
    axis = np.asarray(axis, float)
    axis = axis / max(1e-12, np.linalg.norm(axis))
    h = ang * 0.5
    return np.concatenate([[math.cos(h)], axis * math.sin(h)])


def qbetween(u, v):
    """The shortest rotation taking direction u onto direction v."""
    u = np.asarray(u, float) / max(1e-12, np.linalg.norm(u))
    v = np.asarray(v, float) / max(1e-12, np.linalg.norm(v))
    d = float(np.dot(u, v))
    if d < -0.999999:
        ax = np.cross([1.0, 0.0, 0.0], u)
        if np.linalg.norm(ax) < 1e-6:
            ax = np.cross([0.0, 1.0, 0.0], u)
        return qaxis(ax, math.pi)
    c = np.cross(u, v)
    return qnorm(np.array([1.0 + d, c[0], c[1], c[2]]))


def qfrom_mat(m):
    m = np.asarray(m, float)
    tr = m[0, 0] + m[1, 1] + m[2, 2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        q = [0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [(m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s]
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s]
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s]
    return qnorm(np.array(q))


def qslerp(a, b, t):
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    d = float(np.dot(a, b))
    if d < 0:
        b = -b
        d = -d
    if d > 0.9995:
        return qnorm(a + (b - a) * t)
    th = math.acos(min(1.0, d))
    s = math.sin(th)
    return (math.sin((1 - t) * th) / s) * a + (math.sin(t * th) / s) * b


def yaw_to_minus_z(fwd):
    """The rotation about +Y that turns a horizontal direction onto -Z (the rig's forward)."""
    f = np.array([fwd[0], 0.0, fwd[2]])
    if np.linalg.norm(f) < 1e-9:
        return np.array([1.0, 0.0, 0.0, 0.0])
    ang = math.atan2(-f[0], -f[2])   # yaw of f measured the Godot way (0 = -Z)
    return qaxis([0, 1, 0], -ang)


# ------------------------------------------------------------------ the rig

def load_rig(path=RIG_JSON):
    with open(path, "r", encoding="utf-8") as f:
        r = json.load(f)
    bones = {b["name"]: b for b in r["bones"]}
    return {"names": [b["name"] for b in r["bones"]], "parent": {b["name"]: b["parent"] for b in r["bones"]},
            "head": {b["name"]: np.array(b["head"], float) for b in r["bones"]},
            "offset": {b["name"]: np.array(b["offset"], float) for b in r["bones"]}, "bones": bones}


def rig_fk(rig, hips_pos, local):
    """World positions / rotations of every driven bone for one frame (rest rotations identity)."""
    wpos, wrot = {}, {}
    for b in DRIVEN:
        par = rig["parent"][b]
        if b == "Hips":
            wrot[b] = qnorm(local[b])
            wpos[b] = np.asarray(hips_pos, float)
            continue
        wrot[b] = qnorm(qmul(wrot[par], local[b]))
        wpos[b] = wpos[par] + qrot(wrot[par], rig["offset"][b])
    return wpos, wrot


def rig_dir(rig, b, toward):
    h = rig["head"]
    if toward == "toe":
        return TOE
    if toward is None:
        par = rig["parent"][b]
        d = h[b] - h[par]
        return d if b != "Head" else np.array([0.0, 1.0, 0.0])
    return h[toward] - h[b]


# ------------------------------------------------------------------ source bone names -> rig bones

_ALIASES = {
    "Hips": ["hips", "pelvis", "hip", "root", "bip01pelvis"],
    "UpperLeg": ["upleg", "upperleg", "thigh", "hipjoint2", "femur"],
    "LowerLeg": ["leg", "lowerleg", "calf", "knee", "shin", "tibia"],
    "Foot": ["foot", "ankle"],
    "Toe": ["toebase", "toe", "toes", "ball", "foottoe"],
    "UpperArm": ["arm", "upperarm", "humerus"],
    "LowerArm": ["forearm", "lowerarm", "elbow", "radius"],
    "Hand": ["hand", "wrist"],
    "Neck": ["neck", "neck1", "neck01"],
    "Head": ["head"],
}
_SPINE = re.compile(r"^(spine\d*|spine0\d|chest|upperchest|lowerback|back|torso|abdomen|spine_?\d+)$")


def _norm(name):
    n = name.split(":")[-1].split("|")[-1]
    n = re.sub(r"(?i)^mixamorig\d*", "", n)
    n = re.sub(r"(?i)_jnt$|_joint$|_bone$", "", n)
    side = ""
    low = n.lower()
    m = re.match(r"^(left|right)(.*)$", low)
    if m:
        side, low = m.group(1)[0], m.group(2)
    else:
        m = re.match(r"^([lr])[_\.\s-](.*)$", low) or re.match(r"^(.*?)[_\.\s-]([lr])$", low)
        if m:
            if len(m.group(1)) == 1:
                side, low = m.group(1), m.group(2)
            else:
                low, side = m.group(1), m.group(2)
        else:
            m = re.match(r"^([lr])((?:up|upper|low|lower)?(?:leg|arm|hand|foot|thigh|calf|shoulder|forearm|toe).*)$", low)
            if m:
                side, low = m.group(1), m.group(2)
    low = re.sub(r"[_\.\s-]", "", low)
    return side, low


def map_bones(names, parents):
    """{rig bone: source joint index} for a source skeleton (Mixamo, Rokoko, DeepMotion, QuickMagic, CMU BVH, UE)."""
    out = {}
    info = [_norm(n) for n in names]
    for i, (side, base) in enumerate(info):
        for key, al in _ALIASES.items():
            if base in al:
                if key in ("Hips", "Neck", "Head"):
                    if side == "" and key not in out:
                        out[key] = i
                elif side:
                    tgt = ("Left" if side == "l" else "Right") + key
                    if tgt not in out:
                        out[tgt] = i
                break
    if "Hips" not in out:
        roots = [i for i, p in enumerate(parents) if p < 0]
        if roots:
            out["Hips"] = roots[0]
    # spine: the first spine-ish child chain from the hips; chest = the last spine joint before the neck
    def children(i):
        return [j for j, p in enumerate(parents) if p == i]
    if "Hips" in out:
        chain = []
        cur = out["Hips"]
        while True:
            nxt = [j for j in children(cur) if _SPINE.match(info[j][1]) and info[j][0] == ""]
            if not nxt:
                break
            cur = nxt[0]
            chain.append(cur)
        if chain:
            out["Spine"] = chain[0]
            out["Chest"] = chain[-1] if len(chain) > 1 else chain[0]
            if "Neck" in out:   # the chest is the neck's nearest spine ancestor
                p = parents[out["Neck"]]
                while p >= 0 and p not in chain:
                    p = parents[p]
                if p in chain:
                    out["Chest"] = p
    for side in ("Left", "Right"):   # an arm's upper bone must not be a forearm matched as "arm"
        if side + "UpperArm" in out and side + "LowerArm" in out and out[side + "UpperArm"] == out[side + "LowerArm"]:
            del out[side + "UpperArm"]
    return out


REQUIRED = ["Hips", "Spine", "Neck", "Head", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
            "RightLowerLeg", "RightFoot", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
            "RightLowerArm", "RightHand"]


# ------------------------------------------------------------------ BVH (pure Python)

def _euler(order, angles_deg):
    q = np.array([1.0, 0.0, 0.0, 0.0])
    for ax, a in zip(order, angles_deg):
        axis = {"X": [1, 0, 0], "Y": [0, 1, 0], "Z": [0, 0, 1]}[ax]
        q = qmul(q, qaxis(axis, math.radians(a)))
    return q


def read_bvh(path):
    """A BVH file as a motion (world positions / rotations per joint per frame, rest = the offsets, identity)."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        tokens = f.read().split()
    i = 0
    names, parents, offsets, channels = [], [], [], []
    stack = []
    while i < len(tokens):
        t = tokens[i]
        if t in ("ROOT", "JOINT"):
            names.append(tokens[i + 1])
            parents.append(stack[-1] if stack else -1)
            offsets.append([0.0, 0.0, 0.0])
            channels.append([])
            i += 2
        elif t == "End":
            names.append(names[stack[-1]] + "_end")
            parents.append(stack[-1])
            offsets.append([0.0, 0.0, 0.0])
            channels.append([])
            i += 2
        elif t == "{":
            stack.append(len(names) - 1)
            i += 1
        elif t == "}":
            stack.pop()
            i += 1
        elif t == "OFFSET":
            offsets[stack[-1]] = [float(tokens[i + 1]), float(tokens[i + 2]), float(tokens[i + 3])]
            i += 4
        elif t == "CHANNELS":
            n = int(tokens[i + 1])
            channels[stack[-1]] = tokens[i + 2:i + 2 + n]
            i += 2 + n
        elif t == "MOTION":
            i += 1
            break
        else:
            i += 1
    nframes = int(tokens[i + 1])          # Frames: N
    ft = float(tokens[i + 4])             # Frame Time: x
    i += 5
    nch = sum(len(c) for c in channels)
    data = np.array([float(x) for x in tokens[i:i + nframes * nch]], float).reshape(nframes, nch)
    J = len(names)
    off = np.array(offsets, float)
    rest_pos = np.zeros((J, 3))
    for j in range(J):
        rest_pos[j] = off[j] + (rest_pos[parents[j]] if parents[j] >= 0 else 0.0)
    pos = np.zeros((nframes, J, 3))
    rot = np.zeros((nframes, J, 4))
    for fi in range(nframes):
        col = 0
        lp = [None] * J
        lr = [None] * J
        for j in range(J):
            ch = channels[j]
            vals = data[fi, col:col + len(ch)]
            col += len(ch)
            p = off[j].copy()
            rorder, rang = [], []
            for c, v in zip(ch, vals):
                if c.endswith("position"):
                    p["XYZ".index(c[0])] = v if parents[j] < 0 else v
                else:
                    rorder.append(c[0])
                    rang.append(v)
            lp[j] = p
            lr[j] = _euler(rorder, rang) if rorder else np.array([1.0, 0.0, 0.0, 0.0])
        for j in range(J):
            if parents[j] < 0:
                rot[fi, j] = lr[j]
                pos[fi, j] = lp[j]
            else:
                pr = rot[fi, parents[j]]
                rot[fi, j] = qnorm(qmul(pr, lr[j]))
                pos[fi, j] = pos[fi, parents[j]] + qrot(pr, lp[j])
    m = {"fps": 1.0 / ft, "names": names, "parents": parents, "rest_pos": rest_pos,
         "rest_rot": np.tile([1.0, 0.0, 0.0, 0.0], (J, 1)), "pos": pos, "rot": rot, "source": os.path.basename(path)}
    return z_up_fix(m)


def z_up_fix(m):
    """A Z-up skeleton (hips -> head along Z at rest) turned to Y-up."""
    names = m["names"]
    mp = map_bones(names, m["parents"])
    if "Hips" in mp and "Head" in mp:
        d = m["rest_pos"][mp["Head"]] - m["rest_pos"][mp["Hips"]]
        if abs(d[2]) > abs(d[1]) * 1.5:
            c = qaxis([1, 0, 0], -math.pi / 2 * (1 if d[2] > 0 else -1))
            for k in ("rest_pos", "pos"):
                m[k] = qrot(c, m[k])
            for k in ("rest_rot", "rot"):
                m[k] = qnorm(qmul(np.broadcast_to(c, m[k].shape), m[k]))
    return m


def load_motion_json(path):
    with open(path, "r", encoding="utf-8") as f:
        d = json.load(f)
    return {"fps": float(d["fps"]), "names": d["names"], "parents": d["parents"],
            "rest_pos": np.array(d["rest_pos"], float), "rest_rot": np.array(d["rest_rot"], float),
            "pos": np.array(d["pos"], float), "rot": np.array(d["rot"], float), "source": d.get("source", "")}


def save_motion_json(m, path):
    d = {"fps": m["fps"], "names": m["names"], "parents": m["parents"], "source": m.get("source", ""),
         "rest_pos": np.asarray(m["rest_pos"]).tolist(), "rest_rot": np.asarray(m["rest_rot"]).tolist(),
         "pos": np.asarray(m["pos"]).round(6).tolist(), "rot": np.asarray(m["rot"]).round(7).tolist()}
    with open(path, "w", encoding="utf-8") as f:
        json.dump(d, f)


# ------------------------------------------------------------------ retarget

def _src_child(m, mp, b, toward):
    """The source point a rig bone aims at (rest and per frame), or None to continue the parent's line."""
    if toward == "toe":
        side = "Left" if b.startswith("Left") else "Right"
        if side + "Toe" in mp:
            return mp[side + "Toe"]
        kids = [j for j, p in enumerate(m["parents"]) if p == mp[b]]
        return kids[0] if kids else None
    if toward is None:
        return None
    return mp.get(toward)


def retarget(m, rig):
    """The source motion on our rig: {fps, hips (F,3), local {bone: (F,4)}}, facing -Z at frame 0, hips xz at 0."""
    mp = map_bones(m["names"], m["parents"])
    missing = [b for b in REQUIRED if b not in mp]
    if missing:
        raise ValueError("cannot map bones %s (source names: %s)" % (missing, ", ".join(m["names"][:40])))
    if "Chest" not in mp:
        mp["Chest"] = mp["Spine"]
    F = m["pos"].shape[0]
    up = np.array([0.0, 1.0, 0.0])
    rp, rr = m["rest_pos"], m["rest_rot"]

    def facing(p):
        r = p[mp["RightUpperLeg"]] - p[mp["LeftUpperLeg"]]
        return np.cross(up, r)
    yr = yaw_to_minus_z(facing(rp))
    ya = yaw_to_minus_z(facing(m["pos"][0]))
    rp_n = qrot(yr, rp)
    rr_n = qnorm(qmul(np.broadcast_to(yr, rr.shape), rr))
    pos_n = qrot(ya, m["pos"])
    rot_n = qnorm(qmul(np.broadcast_to(ya, m["rot"].shape), m["rot"]))
    # the rest-pose alignment per bone: the rig's rest direction onto the source's rest direction
    align = {}
    for b in DRIVEN:
        if b == "Hips":
            align[b] = np.array([1.0, 0.0, 0.0, 0.0])
            continue
        toward = AIM[b]
        s = mp[b]
        c = _src_child(m, mp, b, toward)
        if c is not None:
            ds = rp_n[c] - rp_n[s]
        elif toward == "toe":
            ds = np.array([0.0, -0.4, -1.0])
        else:
            par = rig["parent"][b]
            ds = rp_n[s] - rp_n[mp[par]] if b != "Head" else rp_n[s] - rp_n[mp["Neck"]]
        dt = rig_dir(rig, b, toward)
        if b == "Head":
            dt = rig["head"]["Head"] - rig["head"]["Neck"]
        align[b] = qbetween(dt, ds) if np.linalg.norm(ds) > 1e-9 else np.array([1.0, 0.0, 0.0, 0.0])
    world = {}
    for b in DRIVEN:
        s = mp[b]
        delta = qmul(rot_n[:, s], np.broadcast_to(qinv(rr_n[s]), (F, 4)))
        world[b] = qnorm(qmul(delta, np.broadcast_to(align[b], (F, 4))))
    local = {}
    for b in DRIVEN:
        par = rig["parent"][b]
        local[b] = world[b] if b == "Hips" else qnorm(qmul(qinv(world[par]), world[b]))
    # the hips: scaled by leg length (hip to ankle at rest), start at x = z = 0
    src_leg = float(rp_n[mp["Hips"], 1] - 0.5 * (rp_n[mp["LeftFoot"], 1] + rp_n[mp["RightFoot"], 1]))
    tgt_leg = float(rig["head"]["Hips"][1] - rig["head"]["LeftFoot"][1])
    k = tgt_leg / max(1e-6, src_leg)
    hp = pos_n[:, mp["Hips"]].copy()
    hp[:, 0] -= hp[0, 0]
    hp[:, 2] -= hp[0, 2]
    floor = float(0.5 * (rp_n[mp["LeftFoot"], 1] + rp_n[mp["RightFoot"], 1]))
    hp[:, 1] = (hp[:, 1] - floor) * k + float(rig["head"]["LeftFoot"][1])
    hp[:, 0] *= k
    hp[:, 2] *= k
    _hemi(local)
    return {"fps": float(m["fps"]), "hips": hp, "local": local, "scale": k, "map": {b: m["names"][i] for b, i in mp.items()}}


def _hemi(local):
    for b, q in local.items():
        for f in range(1, q.shape[0]):
            if np.dot(q[f], q[f - 1]) < 0:
                q[f] = -q[f]


def resample(c, fps=OUT_FPS):
    F = c["hips"].shape[0]
    src_t = np.arange(F) / c["fps"]
    length = src_t[-1] if F > 1 else 0.0
    n = int(math.floor(length * fps + 1e-6)) + 1
    t = np.arange(n) / fps
    out = {"fps": fps, "hips": np.stack([np.interp(t, src_t, c["hips"][:, i]) for i in range(3)], axis=1), "local": {}}
    for b, q in c["local"].items():
        r = np.zeros((n, 4))
        for i, ti in enumerate(t):
            x = ti * c["fps"]
            a = int(min(F - 1, math.floor(x)))
            bb = min(F - 1, a + 1)
            r[i] = qnorm(qslerp(q[a], q[bb], x - a))
        out["local"][b] = r
    _hemi(out["local"])
    for k in c:
        if k not in out:
            out[k] = c[k]
    return out


# ------------------------------------------------------------------ smoothing (zero-phase Butterworth)

def butter2(x, cutoff, fps):
    """A 2nd-order Butterworth low-pass run forward and back (zero phase), reflect-padded. x: (N, ...)."""
    x = np.asarray(x, float)
    n = x.shape[0]
    if n < 6 or cutoff <= 0 or cutoff >= fps * 0.45:
        return x.copy()
    k = math.tan(math.pi * cutoff / fps)
    nrm = 1.0 / (1.0 + math.sqrt(2.0) * k + k * k)
    b0 = k * k * nrm
    b1, b2 = 2.0 * b0, b0
    a1 = 2.0 * (k * k - 1.0) * nrm
    a2 = (1.0 - math.sqrt(2.0) * k + k * k) * nrm
    pad = min(n - 1, int(fps))

    def run(y):
        out = np.empty_like(y)
        out[0] = y[0]
        out[1] = y[1]
        for i in range(2, len(y)):
            out[i] = b0 * y[i] + b1 * y[i - 1] + b2 * y[i - 2] - a1 * out[i - 1] - a2 * out[i - 2]
        return out
    y = np.concatenate([2 * x[0] - x[pad:0:-1], x, 2 * x[-1] - x[-2:-pad - 2:-1]], axis=0)
    y = run(y)
    y = run(y[::-1])[::-1]
    return y[pad:pad + n]


def smooth(c, cutoff_rot=6.0, cutoff_pos=5.0):
    fps = c["fps"]
    c["hips"] = butter2(c["hips"], cutoff_pos, fps)
    for b in c["local"]:
        c["local"][b] = qnorm(butter2(c["local"][b], cutoff_rot, fps))
    return c


def jitter(c):
    """Mean frame-to-frame second difference of every bone's rotation (rad / frame^2): the jitter measure."""
    tot, n = 0.0, 0
    for q in c["local"].values():
        if q.shape[0] < 3:
            continue
        d2 = q[2:] - 2 * q[1:-1] + q[:-2]
        tot += float(np.linalg.norm(d2, axis=1).sum())
        n += d2.shape[0]
    return tot / max(1, n)


# ------------------------------------------------------------------ trim

def find_start(c, rig, window_s=5.0):
    """The take's start: a clap (both hands within 12 cm) in the first `window_s` seconds starts the shot 1.0 s after
    it; else the end of a still start (0.4 s+ below 0.12 m/s mean joint speed) inside the window; else 0."""
    fps = c["fps"]
    F = c["hips"].shape[0]
    lim = min(F, int(window_s * fps))
    pts = []
    for f in range(F):
        wp, _ = rig_fk(rig, c["hips"][f], {b: c["local"][b][f] for b in DRIVEN})
        pts.append(wp)
    for f in range(lim):
        if np.linalg.norm(pts[f]["LeftHand"] - pts[f]["RightHand"]) < 0.12:
            # the clap's closest frame
            g = f
            while g + 1 < lim and np.linalg.norm(pts[g + 1]["LeftHand"] - pts[g + 1]["RightHand"]) <= np.linalg.norm(pts[g]["LeftHand"] - pts[g]["RightHand"]):
                g += 1
            return min((F - 1) / fps, g / fps + 1.0), "clap"
    speeds = []
    for f in range(1, lim):
        speeds.append(np.mean([np.linalg.norm(pts[f][b] - pts[f - 1][b]) for b in DRIVEN]) * fps)
    still = 0
    for f, s in enumerate(speeds):
        if s < 0.12:
            still += 1
        else:
            if still >= int(0.4 * fps):
                return max(0.0, (f - 2) / fps), "still"
            still = 0
    return 0.0, "none"


def trim(c, start, dur):
    fps = c["fps"]
    a = int(round(start * fps))
    b = a + int(round(dur * fps)) + 1 if dur > 0 else c["hips"].shape[0]
    b = min(b, c["hips"].shape[0])
    c["hips"] = c["hips"][a:b].copy()
    c["hips"][:, 0] -= c["hips"][0, 0]
    c["hips"][:, 2] -= c["hips"][0, 2]
    for k in c["local"]:
        c["local"][k] = c["local"][k][a:b].copy()
    # the facing at the shot's first frame becomes the rig's forward again
    q0 = c["local"]["Hips"][0]
    f = qrot(q0, [0.0, 0.0, -1.0])
    y = yaw_to_minus_z(f)
    c["local"]["Hips"] = qnorm(qmul(np.broadcast_to(y, c["local"]["Hips"].shape), c["local"]["Hips"]))
    c["hips"] = qrot(y, c["hips"])
    return c


# ------------------------------------------------------------------ ground + foot lock

def feet(c, rig):
    """Per frame: ankle positions, sole heights and foot rotations of both feet."""
    F = c["hips"].shape[0]
    out = {s: {"ankle": np.zeros((F, 3)), "sole": np.zeros(F)} for s in ("Left", "Right")}
    for f in range(F):
        wp, wr = rig_fk(rig, c["hips"][f], {b: c["local"][b][f] for b in DRIVEN})
        for s in ("Left", "Right"):
            a = wp[s + "Foot"]
            q = wr[s + "Foot"]
            out[s]["ankle"][f] = a
            out[s]["sole"][f] = min((a + qrot(q, HEEL))[1], (a + qrot(q, TOE))[1])
    return out


def ground(c, rig):
    """Shifts the hips so the feet stand on y = 0 (the 5th percentile of the lower sole)."""
    ft = feet(c, rig)
    low = np.minimum(ft["Left"]["sole"], ft["Right"]["sole"])
    g = float(np.percentile(low, 5))
    c["hips"][:, 1] -= g
    return c


def contacts(ankle, sole, fps, h_max=0.05, v_max=0.35, min_frames=3):
    """Frames where a foot is planted: its sole within h_max of the floor and its ankle slower than v_max (m/s)."""
    F = len(sole)
    v = np.zeros(F)
    d = np.linalg.norm(np.diff(ankle[:, [0, 2]], axis=0), axis=1) * fps
    v[1:] = d
    v[0] = d[0] if F > 1 else 0.0
    on = (sole < h_max) & (v < v_max)
    spans = []
    f = 0
    while f < F:
        if on[f]:
            g = f
            while g + 1 < F and on[g + 1]:
                g += 1
            if g - f + 1 >= min_frames:
                spans.append((f, g))
            f = g + 1
        else:
            f += 1
    return spans


def slide(ankle, spans, fps):
    """Mean horizontal ankle speed (m/s) over the contact frames: the foot-slide measure."""
    tot, n = 0.0, 0
    for a, b in spans:
        if b > a:
            d = np.linalg.norm(np.diff(ankle[a:b + 1][:, [0, 2]], axis=0), axis=1)
            tot += float(d.sum())
            n += b - a
    return tot / max(1, n) * fps


def _ik_leg(hip, knee, ankle, target, l1, l2):
    """Two-bone IK: the new knee for an ankle target, the knee kept in its current bend plane."""
    d = target - hip
    dl = float(np.linalg.norm(d))
    dl = min(max(dl, 1e-4), (l1 + l2) * 0.9999)
    dn = d / max(1e-9, np.linalg.norm(d))
    pole = knee - hip
    pole = pole - dn * np.dot(pole, dn)
    if np.linalg.norm(pole) < 1e-6:
        pole = np.array([0.0, 0.0, -1.0]) - dn * np.dot([0.0, 0.0, -1.0], dn)
    pole = pole / max(1e-9, np.linalg.norm(pole))
    a = (l1 * l1 - l2 * l2 + dl * dl) / (2 * dl)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    return hip + dn * a + pole * h, hip + dn * dl


def foot_lock(c, rig, blend_frames=4, **kw):
    """Pins each planted foot where it landed (an IK on the leg, eased in and out over `blend_frames`); the foot keeps
    its own rotation. Returns the clip with stats {slide_before, slide_after, contacts}."""
    fps = c["fps"]
    F = c["hips"].shape[0]
    ft = feet(c, rig)
    stats = {"slide_before": 0.0, "slide_after": 0.0, "contacts": 0}
    spans_all = {}
    for s in ("Left", "Right"):
        spans_all[s] = contacts(ft[s]["ankle"], ft[s]["sole"], fps, **kw)
    sb = [slide(ft[s]["ankle"], spans_all[s], fps) for s in ("Left", "Right")]
    stats["slide_before"] = float(np.mean(sb))
    stats["contacts"] = int(sum(len(v) for v in spans_all.values()))
    l1 = float(np.linalg.norm(rig["offset"]["LeftLowerLeg"]))
    l2 = float(np.linalg.norm(rig["offset"]["LeftFoot"]))
    for s in ("Left", "Right"):
        w = np.zeros(F)
        pin = np.zeros((F, 3))
        for a, b in spans_all[s]:
            p = ft[s]["ankle"][a].copy()
            p[1] = float(np.mean(ft[s]["ankle"][a:b + 1, 1]))
            for f in range(max(0, a - blend_frames), min(F, b + blend_frames + 1)):
                if f < a:
                    k = 1.0 - (a - f) / (blend_frames + 1.0)
                elif f > b:
                    k = 1.0 - (f - b) / (blend_frames + 1.0)
                else:
                    k = 1.0
                k = k * k * (3 - 2 * k)
                if k > w[f]:
                    w[f] = k
                    pin[f] = p
        up, lo, fo = s + "UpperLeg", s + "LowerLeg", s + "Foot"
        for f in range(F):
            if w[f] <= 1e-4:
                continue
            loc = {b: c["local"][b][f] for b in DRIVEN}
            wp, wr = rig_fk(rig, c["hips"][f], loc)
            target = wp[fo] + (pin[f] - wp[fo]) * w[f]
            knee2, ankle2 = _ik_leg(wp[up], wp[lo], wp[fo], target, l1, l2)
            par = wr[rig["parent"][up]]
            r_up = qnorm(qmul(qbetween(wp[lo] - wp[up], knee2 - wp[up]), wr[up]))
            # the lower leg: from the new upper leg, aimed at the new ankle
            r_lo0 = qnorm(qmul(r_up, loc[lo]))
            cur = qrot(r_lo0, rig["offset"][fo])
            r_lo = qnorm(qmul(qbetween(cur, ankle2 - knee2), r_lo0))
            c["local"][up][f] = qnorm(qmul(qinv(par), r_up))
            c["local"][lo][f] = qnorm(qmul(qinv(r_up), r_lo))
            c["local"][fo][f] = qnorm(qmul(qinv(r_lo), wr[fo]))
    _hemi(c["local"])
    ft2 = feet(c, rig)
    sa = [slide(ft2[s]["ankle"], spans_all[s], fps) for s in ("Left", "Right")]
    stats["slide_after"] = float(np.mean(sa))
    c["stats"] = dict(c.get("stats", {}), **stats)
    return c


# ------------------------------------------------------------------ the whole chain

def process(m, rig, dur=0.0, start=None, cutoff=6.0, lock=True):
    """Source motion -> our clip: retarget, resample to 30 fps, trim (`start` seconds or auto), smooth, ground, lock."""
    c = retarget(m, rig)
    c = resample(c, OUT_FPS)
    how = "given"
    if start is None:
        start, how = find_start(c, rig)
    c = trim(c, float(start), float(dur))
    j0 = jitter(c)
    c = smooth(c, cutoff, cutoff * 0.85)
    c = ground(c, rig)
    if lock:
        c = foot_lock(c, rig)
    c["stats"] = dict(c.get("stats", {}), jitter_before=j0, jitter_after=jitter(c), start=float(start), start_from=how,
                      frames=int(c["hips"].shape[0]))
    return c


def write_clip(c, path, meta=None):
    d = {"fps": c["fps"], "length": (c["hips"].shape[0] - 1) / c["fps"], "bones": DRIVEN,
         "hips": np.asarray(c["hips"]).round(5).tolist(),
         "rot": {b: np.asarray(c["local"][b])[:, [1, 2, 3, 0]].round(6).tolist() for b in DRIVEN},
         "stats": c.get("stats", {}), "map": c.get("map", {})}
    if meta:
        d.update(meta)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(d, f, separators=(",", ":"))
    return d
