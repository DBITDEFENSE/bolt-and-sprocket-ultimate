"""Licensed FBX -> shared ZombieRig animations. Run in installed Blender, no installers.

blender -b --factory-startup --python-exit-code 1 -P tools/blender/zombie_anim_batch.py -- --root .
Optional --only=mco_walk,mco_fast_chase; --no-foot-lock for an uncorrected comparison.
No motion is authored here: all rotations come from FBX, plus retarget/seam cleanup/contact IK.
GLB uses explicit glTF joint transforms to preserve ZombieRig's identity rests exactly (Blender
bone-tail conventions otherwise introduce a second rest-frame conversion on Godot import).
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/mocap"))
import blender_extract as extract
import mocaplib as ml


def target_rig(root):
    rows = json.loads((root / "data/gravelight/anim.json").read_text(encoding="utf-8"))["skeleton"]["bones"]
    r = {"names": [], "parent": {}, "head": {}, "offset": {}}
    for name, parent, xyz in rows:
        r["names"].append(name)
        r["parent"][name] = parent
        r["offset"][name] = np.array(xyz, float)
        r["head"][name] = r["offset"][name] + (r["head"][parent] if parent else 0)
    return r


def spans(mask):
    out, start = [], None
    for i, on in enumerate(list(mask) + [False]):
        if on and start is None:
            start = i
        elif not on and start is not None:
            out.append((start, i - 1))
            start = None
    return out


def source_contacts(m, clip, cfg):
    """Detect contacts on the source recording, independent of the corrected target feet."""
    mp = ml.map_bones(m["names"], m["parents"])
    rate = m["fps"]
    result = {}
    for side in ("Left", "Right"):
        # A running ankle moves around the planted toes. Test the toe joint, not the ankle.
        p = m["pos"][:, mp[side + "Toe"]] * clip["scale"]
        height = p[:, 1] - np.percentile(p[:, 1], 5)
        found = ml.contacts(p, height, rate, h_max=cfg["height_m"], v_max=cfg["speed_mps"], min_frames=cfg["minimum_frames"])
        times = clip.get("source_times", np.arange(len(clip["hips"])) / clip["fps"])
        mask = np.zeros(len(times), bool)
        for a, b in found:
            mask |= (times >= a / rate) & (times <= b / rate)
        result[side] = mask
    return result


def retime_recording(c, row):
    """Trim/time-warp an existing performance around a reviewed impact; never create poses."""
    timing = row.get("timing")
    if not timing:
        return c
    src, dst = np.array(timing["source_seconds"]), np.array(timing["target_seconds"])
    length = (len(c["hips"])-1) / c["fps"]
    if len(src) != len(dst) or len(src) < 2 or src[0] < 0 or src[-1] > length + 1e-5 or dst[0] != 0 or np.any(np.diff(src) <= 0) or np.any(np.diff(dst) <= 0):
        raise ValueError("Invalid timing map: " + row["name"])
    fps = float(row.get("sample_fps", c["fps"]))
    times = np.arange(round(dst[-1]*fps)+1) / fps
    source_times = np.interp(times, dst, src)
    original_times = np.arange(len(c["hips"])) / c["fps"]
    out = dict(c, fps=fps, source_times=source_times,
               hips=np.stack([np.interp(source_times, original_times, c["hips"][:, j]) for j in range(3)], axis=1), local={})
    for bone, qs in c["local"].items():
        result = []
        for t in source_times:
            x = t*c["fps"]
            a = min(len(qs)-1, int(np.floor(x)))
            b = min(len(qs)-1, a+1)
            result.append(ml.qnorm(ml.qslerp(qs[a], qs[b], x-a)))
        out["local"][bone] = np.array(result)
    ml._hemi(out["local"])
    return out


def close_loop(c, root, seconds):
    """Correct only the residual mismatch near the seam, retaining total root displacement."""
    n = len(c["hips"])
    window = min(n - 1, max(1, round(seconds * c["fps"])))
    hip_error = (c["hips"][-1] - root[-1]) - (c["hips"][0] - root[0])
    for i in range(n - window - 1, n):
        k = (i - (n - window - 1)) / window
        k = k * k * (3 - 2 * k)
        c["hips"][i] -= hip_error * k
    for q in c["local"].values():
        correction = ml.qmul(ml.qinv(q[-1]), q[0])
        for i in range(n - window - 1, n):
            k = (i - (n - window - 1)) / window
            k = k * k * (3 - 2 * k)
            q[i] = ml.qnorm(ml.qmul(q[i], ml.qslerp(np.array([1., 0, 0, 0]), correction, k)))
        q[-1] = q[0]
    ml._hemi(c["local"])


def lock_contacts(c, rig, contacts, blend_frames):
    feet = toe_positions(c, rig)
    n = len(c["hips"])
    l1 = np.linalg.norm(rig["offset"]["LeftLowerLeg"])
    l2 = np.linalg.norm(rig["offset"]["LeftFoot"])
    for side in ("Left", "Right"):
        weights, pins = np.zeros(n), np.zeros((n, 3))
        for a, b in spans(contacts[side]):
            pin = feet[side][a:b+1].mean(axis=0)
            pin[1] = 0.0
            for i in range(max(0, a - blend_frames), min(n, b + blend_frames + 1)):
                k = 1.0 if a <= i <= b else 1 - min(abs(i-a), abs(i-b)) / (blend_frames + 1)
                k = k*k*(3-2*k)
                if k > weights[i]:
                    weights[i], pins[i] = k, pin
        up, lo, foot = [side + x for x in ("UpperLeg", "LowerLeg", "Foot")]
        for i in range(n):
            if weights[i] <= 0:
                continue
            local = {b: c["local"][b][i] for b in ml.DRIVEN}
            wp, wr = ml.rig_fk(rig, c["hips"][i], local)
            toe = wp[foot] + ml.qrot(wr[foot], ml.TOE)
            target = wp[foot] + (pins[i] - toe) * weights[i]
            knee, ankle = ml._ik_leg(wp[up], wp[lo], wp[foot], target, l1, l2)
            upper = ml.qnorm(ml.qmul(ml.qbetween(wp[lo]-wp[up], knee-wp[up]), wr[up]))
            lower0 = ml.qnorm(ml.qmul(upper, local[lo]))
            lower = ml.qnorm(ml.qmul(ml.qbetween(ml.qrot(lower0, rig["offset"][foot]), ankle-knee), lower0))
            c["local"][up][i] = ml.qnorm(ml.qmul(ml.qinv(wr[rig["parent"][up]]), upper))
            c["local"][lo][i] = ml.qnorm(ml.qmul(ml.qinv(upper), lower))
            c["local"][foot][i] = ml.qnorm(ml.qmul(ml.qinv(lower), wr[foot]))
    ml._hemi(c["local"])


def toe_positions(c, rig):
    result = {s: [] for s in ("Left", "Right")}
    for i in range(len(c["hips"])):
        wp, wr = ml.rig_fk(rig, c["hips"][i], {b: c["local"][b][i] for b in ml.DRIVEN})
        for side in result:
            b = side + "Foot"
            result[side].append(wp[b] + ml.qrot(wr[b], ml.TOE))
    return {s: np.asarray(v) for s, v in result.items()}


def contact_speeds(c, rig, contacts):
    values = []
    ft = toe_positions(c, rig)
    for side in ("Left", "Right"):
        d = np.linalg.norm(np.diff(ft[side][:, [0, 2]], axis=0), axis=1) * c["fps"]
        valid = contacts[side][1:] & contacts[side][:-1]
        values.extend(d[valid].tolist())
    return {"samples": len(values), "mean_mps": float(np.mean(values)) if values else None,
            "p95_mps": float(np.percentile(values, 95)) if values else None}


def periodic_lock(c, rig, contacts, root, cfg, looping):
    if not looping:
        lock_contacts(c, rig, contacts, cfg["blend_frames"])
        return
    # Three periods keep stance windows spanning the seam intact. Keep the middle period.
    n = len(c["hips"]) - 1
    d = root[-1] - root[0]
    padded = dict(c, hips=np.concatenate([c["hips"][:-1]-d, c["hips"][:-1], c["hips"]+d]),
                  local={b: np.concatenate([q[:-1], q[:-1], q]) for b, q in c["local"].items()})
    masks = {s: np.concatenate([v[:-1], v[:-1], v]) for s, v in contacts.items()}
    lock_contacts(padded, rig, masks, cfg["blend_frames"])
    c["local"] = {b: q[n:2*n+1].copy() for b, q in padded["local"].items()}
    for q in c["local"].values():
        q[-1] = q[0]


def write_glb(path, c, rig, root, name, meta):
    """glTF 2.0, metres, Y-up. A tiny weighted marker preserves joints on scene import.
    Runtime loads only the Animation; it never attaches this marker to an enemy."""
    blob, views, accessors = bytearray(), [], []
    def accessor(value, dtype, component, kind, bounds=False):
        a = np.asarray(value, dtype=dtype)
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        blob.extend(a.tobytes())
        views.append({"buffer": 0, "byteOffset": off, "byteLength": a.nbytes})
        row = {"bufferView": len(views)-1, "componentType": component, "count": len(a), "type": kind}
        if bounds:
            row.update(min=np.atleast_1d(a.min(axis=0)).tolist(), max=np.atleast_1d(a.max(axis=0)).tolist())
        accessors.append(row)
        return len(accessors)-1
    names = rig["names"]
    indices = {b: i+1 for i, b in enumerate(names)}
    nodes = [{"name": "ZombieMocap", "children": [indices["Root"], len(names)+1]}]
    for b in names:
        node = {"name": b, "translation": rig["offset"][b].tolist()}
        children = [indices[x] for x in names if rig["parent"][x] == b]
        if children: node["children"] = children
        nodes.append(node)
    nodes.append({"name": "RigMarker", "mesh": 0, "skin": 0})
    pos = accessor([[0, 0, 0], [.001, 0, 0], [0, .001, 0]], "<f4", 5126, "VEC3", True)
    joints = accessor([[0, 0, 0, 0]]*3, "<u2", 5123, "VEC4")
    weights = accessor([[1, 0, 0, 0]]*3, "<f4", 5126, "VEC4")
    ibm = []
    for b in names:
        mat = np.eye(4)
        mat[:3, 3] = -rig["head"][b]
        ibm.append(mat.T.reshape(16))
    binds = accessor(ibm, "<f4", 5126, "MAT4")
    times = accessor(np.arange(len(c["hips"])) / c["fps"], "<f4", 5126, "SCALAR", True)
    channels, samplers = [], []
    def track(bone, channel, data, kind):
        ai = accessor(data, "<f4", 5126, kind)
        samplers.append({"input": times, "output": ai, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers)-1, "target": {"node": indices[bone], "path": channel}})
    track("Root", "translation", root, "VEC3")
    track("Hips", "translation", c["hips"]-root, "VEC3")
    for b in names:
        q = c["local"].get(b, np.tile([1., 0, 0, 0], (len(c["hips"]), 1)))
        track(b, "rotation", q[:, [1, 2, 3, 0]], "VEC4")
    doc = {"asset": {"version": "2.0", "generator": "Gravelight licensed zombie retargeter", "copyright": "Animation: Motus Digital LLC / MoCap Online; licensed project use only"},
           "scene": 0, "scenes": [{"nodes": [0]}], "nodes": nodes,
           "skins": [{"joints": list(indices.values()), "skeleton": indices["Root"], "inverseBindMatrices": binds}],
           "meshes": [{"primitives": [{"attributes": {"POSITION": pos, "JOINTS_0": joints, "WEIGHTS_0": weights}}]}],
           "animations": [{"name": name, "samplers": samplers, "channels": channels, "extras": meta}],
           "buffers": [{"byteLength": len(blob)}], "bufferViews": views, "accessors": accessors}
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    js += b" " * (-len(js) % 4)
    blob.extend(b"\0" * (-len(blob) % 4))
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, 12+8+len(js)+8+len(blob)) + struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(blob), 0x004E4942) + blob)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--only", default="")
    parser.add_argument("--no-foot-lock", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    root = args.root.resolve()
    cfg = json.loads((root / "data/gravelight/zombie_mocap.json").read_text(encoding="utf-8"))
    rig = target_rig(root)
    out, work = root / cfg["output_dir"], root / ".mocap_work/zombies"
    out.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    selected = set(args.only.split(",")) if args.only else set()
    unknown = selected - {r["name"] for r in cfg["clips"]}
    if unknown:
        raise ValueError("Unknown clips: " + ", ".join(sorted(unknown)))
    report = {"blender": bpy.app.version_string, "source": "MoCap Online Zombie Starter 2.7", "license_url": cfg["license_url"], "clips": {}, "errors": []}
    for row in cfg["clips"]:
        name = row["name"]
        if selected and name not in selected: continue
        src = root / cfg["source_dir"] / (row["source"] + ".fbx")
        digest = hashlib.sha256(src.read_bytes()).hexdigest()
        motion_file = work / (row["source"] + ".motion.json")
        digest_file = motion_file.with_suffix(".sha256")
        if not motion_file.exists() or not digest_file.exists() or digest_file.read_text() != digest:
            extract.extract(str(src), str(motion_file))
            digest_file.write_text(digest)
        m = ml.load_motion_json(motion_file)
        # Motus has BOTH Root and Hips. The generic importer aliases Root as Hips; prevent that.
        if "Root" in m["names"] and "Hips" in m["names"]:
            m["names"][m["names"].index("Root")] = "MotionRoot"
        c = retime_recording(ml.resample(ml.retarget(m, rig), float(cfg["fps"])), row)
        trajectory = np.outer(np.linspace(0, 1, len(c["hips"])), (c["hips"][-1]-c["hips"][0]) * [1, 0, 1]) if row.get("extract_root", True) else np.zeros_like(c["hips"])
        # Straight gait root faces -Z; rotate recording and trajectory together (no pose invention).
        if row.get("foot_lock") or name == "mco_crawl":
            yaw = ml.yaw_to_minus_z(trajectory[-1]) if np.linalg.norm(trajectory[-1]) > 1e-5 else np.array([1., 0, 0, 0])
            c["hips"] = ml.qrot(yaw, c["hips"])
            c["local"]["Hips"] = ml.qnorm(ml.qmul(yaw, c["local"]["Hips"]))
            trajectory = ml.qrot(yaw, trajectory)
        if row.get("foot_lock"):
            c = ml.ground(c, rig)
        if row["loop"]:
            close_loop(c, trajectory, cfg["loop_blend_seconds"])
        contact = source_contacts(m, c, cfg["contact"])
        before = contact_speeds(c, rig, contact)
        if row.get("foot_lock") and not args.no_foot_lock:
            periodic_lock(c, rig, contact, trajectory, cfg["contact"], row["loop"])
        after = contact_speeds(c, rig, contact)
        duration = (len(c["hips"])-1) / c["fps"]
        seam = max(float(2*np.arccos(np.clip(abs(np.dot(q[0], q[-1])), 0, 1))) for q in c["local"].values())
        meta = {"file": name+".glb", "source_fbx": src.relative_to(root).as_posix(), "sha256": digest,
                "duration": duration, "frames": len(c["hips"]), "loop": row["loop"], "bone_map": c["map"],
                "root_displacement": trajectory[-1].tolist(), "speed_mps": float(np.linalg.norm(trajectory[-1]) / duration),
                "loop_seam_radians": seam if row["loop"] else None, "source_contact_before": before, "source_contact_after": after,
                "contact_windows": {s: [[a/c["fps"], b/c["fps"]] for a, b in spans(mask)] for s, mask in contact.items()},
                "foot_lock": bool(row.get("foot_lock") and not args.no_foot_lock),
                "timing": row.get("timing"), "events": row.get("events", {})}
        if not np.isfinite(c["hips"]).all() or not all(np.isfinite(q).all() for q in c["local"].values()):
            raise RuntimeError("Non-finite retarget: " + name)
        if row["loop"] and seam > 0.002:
            raise RuntimeError("Loop seam: " + name)
        write_glb(out / (name+".glb"), c, rig, trajectory, name, meta)
        report["clips"][name] = meta
        print("ZOMBIE_ANIM", name, "seconds", round(duration, 3), "m/s", round(meta["speed_mps"], 3), "contact", before, "->", after, flush=True)
    # An --only iteration must not discard previously generated clip metadata.
    manifest = out / "mocap_manifest.json"
    if selected and manifest.exists():
        old = json.loads(manifest.read_text())
        old["clips"].update(report["clips"])
        report = old
    manifest.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    summary = root / "docs/captures/after/mocap"
    summary.mkdir(parents=True, exist_ok=True)
    (summary / "conversion.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print("ZOMBIE_ANIM_BATCH", len(report["clips"]), "clips complete", flush=True)


if __name__ == "__main__":
    main()
