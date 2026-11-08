"""T-210: the phone-mocap pipeline's tools (tools/mocap/). Run: tools/mocap.sh test (or pytest tests/mocap).

The test clip is our own synthetic BVH (tools/mocap/make_sample.py -> tests/data/mocap/sample_walk.bvh: a slate clap,
then a walk whose planted feet slide and whose joints jitter, Mixamo bone names, T-pose rest, centimetres).
"""
import json
import math
import os
import shutil
import subprocess
import sys

import numpy as np
import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "mocap"))
import lipsync  # noqa: E402
import make_sample  # noqa: E402
import mocap  # noqa: E402
import mocaplib as ml  # noqa: E402

SAMPLE = os.path.join(ROOT, "tests", "data", "mocap", "sample_walk.bvh")


@pytest.fixture(scope="module")
def rig():
    return ml.load_rig()


@pytest.fixture(scope="module")
def motion():
    return ml.read_bvh(SAMPLE)


@pytest.fixture(scope="module")
def clip(motion, rig):
    return ml.process(motion, rig, dur=3.0)


def _fk(c, rig, f):
    return ml.rig_fk(rig, c["hips"][f], {b: c["local"][b][f] for b in ml.DRIVEN})


def _angle(a, b):
    d = np.abs(np.sum(a * b, axis=-1))
    return np.degrees(2 * np.arccos(np.clip(d, 0, 1)))


def test_the_sample_is_reproducible(tmp_path):
    p = make_sample.write(str(tmp_path / "s.bvh"))
    with open(p, "r", encoding="utf-8") as a, open(SAMPLE, "r", encoding="utf-8") as b:
        assert a.read() == b.read(), "tests/data/mocap/sample_walk.bvh is make_sample.py's output"


def test_bone_names_map_for_every_app():
    cases = {
        "mixamo": ["mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2", "mixamorig:Neck", "mixamorig:Head",
                   "mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand", "mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:LeftFoot"],
        "deepmotion": ["hips_JNT", "spine_JNT", "spine1_JNT", "spine2_JNT", "neck_JNT", "head_JNT", "l_arm_JNT", "l_forearm_JNT",
                       "l_hand_JNT", "l_upleg_JNT", "l_leg_JNT", "l_foot_JNT"],
        "ue": ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "upperarm_l", "lowerarm_l", "hand_l", "thigh_l", "calf_l", "foot_l"],
    }
    for app, names in cases.items():
        parents = [-1, 0, 1, 2, 3, 4, 3, 6, 7, 0, 9, 10]
        mp = ml.map_bones(names, parents)
        for tgt, i in [("Hips", 0), ("Spine", 1), ("Chest", 3), ("Neck", 4), ("Head", 5), ("LeftUpperArm", 6), ("LeftLowerArm", 7),
                       ("LeftHand", 8), ("LeftUpperLeg", 9), ("LeftLowerLeg", 10), ("LeftFoot", 11)]:
            assert mp.get(tgt) == i, "%s: %s -> %s (got %s)" % (app, tgt, names[i], mp.get(tgt))


def test_retarget_lines_up_the_t_pose_with_our_rest(motion, rig):
    c = ml.retarget(motion, rig)
    wp, _ = ml.rig_fk(rig, c["hips"][0], {b: c["local"][b][0] for b in ml.DRIVEN})
    # frame 0 of the take: standing, arms down (80 deg from the BVH's T-pose rest), facing the rig's -Z
    for b in ("LeftHand", "RightHand"):
        assert wp[b][1] < 1.0, "%s hangs at the side (y %.2f)" % (b, wp[b][1])
    assert wp["LeftUpperLeg"][0] < 0 < wp["RightUpperLeg"][0], "left is -X (the character faces -Z)"
    assert abs(wp["Head"][1] - rig["head"]["Head"][1]) < 0.05, "head at the rig's height"
    assert abs(c["scale"] - 0.01) < 0.002, "centimetres scaled to metres by the leg length"


def test_end_to_end_bvh(clip, rig):
    st = clip["stats"]
    assert st["start_from"] == "clap" and abs(st["start"] - 1.7) < 0.1, "the shot starts 1 s after the slate clap"
    assert clip["hips"].shape[0] == 91, "trimmed to 3 s at 30 fps"
    for b in ml.DRIVEN:
        n = np.linalg.norm(clip["local"][b], axis=1)
        assert np.allclose(n, 1.0, atol=1e-5), b
    assert abs(clip["hips"][0][0]) < 1e-6 and abs(clip["hips"][0][2]) < 1e-6, "on the mark at the start"
    assert clip["hips"][-1][2] < -2.5, "walks forward (-Z): %.2f m" % clip["hips"][-1][2]
    wp, _ = _fk(clip, rig, 45)
    assert wp["Head"][1] > wp["Hips"][1] + 0.5, "upright"
    ft = ml.feet(clip, rig)
    low = np.minimum(ft["Left"]["sole"], ft["Right"]["sole"])
    assert abs(float(np.percentile(low, 5))) < 0.01, "the feet stand on the floor"


def test_foot_lock_takes_out_the_slide(clip):
    st = clip["stats"]
    assert st["contacts"] >= 4, "planted steps found"
    assert st["slide_before"] > 0.1, "the raw walk slides (%.3f m/s)" % st["slide_before"]
    assert st["slide_after"] < 0.05, "after the lock under 5 cm/s (%.3f)" % st["slide_after"]
    assert st["slide_after"] < 0.3 * st["slide_before"]


def test_smoothing_takes_out_the_jitter(clip):
    st = clip["stats"]
    assert st["jitter_after"] < 0.5 * st["jitter_before"], "%.4f -> %.4f" % (st["jitter_before"], st["jitter_after"])


def test_the_filter_keeps_slow_motion():
    t = np.arange(90) / 30.0
    x = np.sin(2 * math.pi * 1.0 * t)[:, None]
    y = ml.butter2(x, 6.0, 30.0)
    assert np.abs(x - y)[10:-10].max() < 0.03, "a 1 Hz move passes a 6 Hz low-pass"
    n = np.sin(2 * math.pi * 12.0 * t)[:, None]
    assert np.abs(ml.butter2(n, 6.0, 30.0))[10:-10].max() < 0.3, "12 Hz shake is cut"


def test_a_given_start_wins(motion, rig):
    c = ml.process(motion, rig, dur=1.0, start=2.0, lock=False)
    assert c["stats"]["start_from"] == "given" and c["hips"].shape[0] == 31


def test_the_clip_json(clip, tmp_path):
    p = tmp_path / "c.clip.json"
    d = ml.write_clip(clip, str(p), {"name": "shot_01_any", "root": "mocap"})
    j = json.loads(p.read_text(encoding="utf-8"))
    assert j["bones"] == ml.DRIVEN and len(j["hips"]) == 91 and abs(j["length"] - 3.0) < 1e-6
    assert len(j["rot"]["LeftFoot"][0]) == 4, "Godot order x, y, z, w"
    assert j["name"] == "shot_01_any" and d["fps"] == 30.0


def _blender():
    return mocap._blender()


@pytest.mark.skipif(not _blender(), reason="Blender not installed")
def test_end_to_end_fbx_through_blender(tmp_path, motion, rig):
    """The FBX path: the sample made into an FBX by Blender, read back by blender_extract.py, retargeted the same."""
    exe = _blender()
    fbx = str(tmp_path / "walk.fbx")
    r = subprocess.run([exe, "-b", "--factory-startup", "--python", os.path.join(ROOT, "tools", "mocap", "blender_extract.py"), "--",
                        "--to-fbx", SAMPLE, fbx], capture_output=True, text=True)
    assert r.returncode == 0 and os.path.exists(fbx), r.stdout[-500:] + r.stderr[-500:]
    m2 = mocap.extract_with_blender(fbx, str(tmp_path / "walk.motion.json"))
    a = ml.retarget(motion, rig)
    b = ml.retarget(m2, rig)
    best = 1e9
    for off in (-1, 0, 1):   # the FBX bake may lead by a frame
        worst = 0.0
        for bone in ml.DRIVEN:
            A = a["local"][bone][max(0, off):120 + max(0, off)]
            B = b["local"][bone][max(0, -off):120 + max(0, -off)]
            worst = max(worst, float(_angle(A, B).max()))
        best = min(best, worst)
    assert best < 3.0, "the FBX retargets like the BVH (worst bone %.2f deg)" % best
    c = ml.process(m2, rig, dur=3.0)
    assert c["stats"]["slide_after"] < 0.05


# ------------------------------------------------------------------ intake and the report

def _shots():
    return mocap.load_shots()


def test_file_names_parse():
    sc = mocap.scene_of(_shots(), "gravelight_one")
    assert mocap.parse_name(sc, "shot_04_seat1.fbx") == ("shot_04", "seat1")
    assert mocap.parse_name(sc, "shot_02_any.BVH") == ("shot_02", "any")
    assert mocap.parse_name(sc, "shot_04.fbx") is None
    assert mocap.parse_name(sc, "shot_04_seat1.mp4") is None
    ce = mocap.scene_of(_shots(), "cancel_ending")
    assert mocap.parse_name(ce, "last_wren.fbx") == ("last", "wren")


def test_the_missing_file_report(tmp_path):
    src = tmp_path / "mocap"
    (src / "gravelight_one").mkdir(parents=True)
    shutil.copy(SAMPLE, src / "gravelight_one" / "shot_04_seat1.bvh")
    (src / "exfil_m1_m2").mkdir()
    shutil.copy(SAMPLE, src / "exfil_m1_m2" / "shot_02_any.bvh")
    (src / "gravelight_one" / "notes.fbx").write_text("x")
    (src / "nowhere").mkdir()
    r = mocap.report(_shots(), str(src))
    gl = {s["shot"]: s for s in next(x for x in r["scenes"] if x["scene"] == "gravelight_one")["shots"]}
    assert gl["shot_04"]["have"] == ["seat1"] and gl["shot_04"]["missing"] == []
    assert gl["shot_02"]["missing"] == ["seat1", "seat2", "seat3", "seat4"]
    ex = {s["shot"]: s for s in next(x for x in r["scenes"] if x["scene"] == "exfil_m1_m2")["shots"]}
    assert ex["shot_02"]["missing"] == [] and ex["shot_02"]["any"], "one 'any' take covers every role"
    assert "notes.fbx" in next(x for x in r["scenes"] if x["scene"] == "gravelight_one")["unknown"]
    assert "nowhere/" in r["unknown_scenes"]
    t = r["total"]
    assert t["takes"] == sum(len(sh["roles"]) for sc in _shots()["scenes"] for sh in sc["shots"])
    assert t["present"] == 1 + 4
    assert t["missing_high"] + t["missing_optional"] == t["takes"] - t["present"]


def test_the_report_runs_on_an_empty_drop_folder(tmp_path, capsys):
    assert mocap.main(["report", "--src", str(tmp_path / "none")]) == 0
    out = capsys.readouterr().out
    assert "TOTAL 0 of" in out and "MISSING" in out


def test_build_without_godot(tmp_path):
    src = tmp_path / "mocap"
    (src / "cancel_ending").mkdir(parents=True)
    shutil.copy(SAMPLE, src / "cancel_ending" / "last_wren.bvh")
    (src / "cancel_ending" / "last_wren.json").write_text(json.dumps({"start": 2.0}))
    done, failed = mocap.build(_shots(), str(src), str(tmp_path / "work"), godot=False)
    assert not failed and len(done) == 1
    j = json.loads(open(done[0], encoding="utf-8").read())
    assert j["name"] == "last_wren" and j["scene"] == "cancel_ending" and j["root"] == "mocap"
    assert j["stats"]["start"] == 2.0 and j["stats"]["start_from"] == "given", "the sidecar's start"
    assert abs(j["length"] - (149 / 30.0 - 2.0)) < 0.05, "a 12 s shot from a 5 s take: as much as there is after the start"


def test_shots_json_is_complete():
    d = _shots()
    roles = set(d["roles"]) | {"any"}
    for sc in d["scenes"]:
        assert sc["kind"] in ("timeline", "script")
        for sh in sc["shots"]:
            assert sh["dur"] > 0 and sh["roles"], sh["id"]
            for r in sh["roles"]:
                assert r in roles, "%s %s: unknown role %s" % (sc["id"], sh["id"], r)
            for r in sh["action"]:
                assert r in sh["roles"] or r == "any", "%s %s: an action for %s, who is not in the shot" % (sc["id"], sh["id"], r)
            assert all(r in sh["action"] or "any" in sh["action"] for r in sh["roles"]), "%s %s: everyone has something to do" % (sc["id"], sh["id"])
            assert sh.get("root", "mocap") in ("mocap", "cast")


def test_the_guide_is_current():
    tables, total = mocap.guide_tables(_shots())
    with open(os.path.join(ROOT, "docs", "MOCAP_GUIDE.md"), "r", encoding="utf-8") as f:
        doc = f.read()
    assert tables in doc, "docs/MOCAP_GUIDE.md is out of date: run tools/mocap.sh guide"
    assert ("**%d shots, %d takes**" % (total["shots"], total["takes"])) in doc


# ------------------------------------------------------------------ lip sync

def test_committed_cues_end_with_their_takes():
    lines, man = lipsync.vo_data()
    ids = lipsync.cutscene_ids(lines)
    assert len(ids) > 60, "the cutscene lines"
    missing, off = [], []
    for lid in ids:
        if not lipsync.audio_of(lid, man):
            continue
        p = os.path.join(lipsync.OUT, lid + ".json")
        if not os.path.exists(p):
            missing.append(lid)
            continue
        d = json.load(open(p, encoding="utf-8"))
        dur = float(man.get(lid, {}).get("duration", d["duration"]))
        if abs(d["duration"] - dur) > 0.1 or d["cues"][-1][0] >= d["duration"]:
            off.append((lid, d["duration"], dur))
        assert all(c[1] in "ABCDEFGHX" for c in d["cues"]), lid
        assert [c[0] for c in d["cues"]] == sorted(c[0] for c in d["cues"]), lid
    assert not missing, "no cues yet for %s: run tools/mocap.sh lipsync" % missing[:10]
    assert not off, "cues not ending with the take: %s" % off[:5]


def _tone_wav(path, sr=48000):
    import soundfile as sf
    t = np.arange(int(sr * 2.0)) / sr
    env = (np.sin(2 * math.pi * 3.0 * t) > 0).astype(float) * np.clip(np.sin(2 * math.pi * 1.5 * t) + 0.3, 0, 1)
    sf.write(path, 0.4 * env * np.sin(2 * math.pi * 220 * t), sr)
    return 2.0


def test_the_loudness_fallback(tmp_path):
    p = str(tmp_path / "beep.wav")
    length = _tone_wav(p)
    cues, dur = lipsync.amplitude_cues(p)
    assert abs(dur - length) < 0.01
    assert cues[0][0] == 0.0 and cues[-1][0] < dur
    shapes = {c[1] for c in cues}
    assert "X" in shapes and len(shapes) >= 3, "rest and some open shapes: %s" % shapes
    assert all(b[0] - a[0] >= 0.049 for a, b in zip(cues, cues[1:])), "no flicker shorter than 50 ms"


def test_make_writes_a_cue_file(tmp_path, monkeypatch):
    monkeypatch.setattr(lipsync, "OUT", str(tmp_path))
    p = str(tmp_path / "beep.wav")
    length = _tone_wav(p)
    src = lipsync.make("TEST_BEEP_01", {"text": "beep beep"}, p, "", force=True)
    assert src == "amplitude", "no Rhubarb given: the fallback, and it says so"
    d = json.load(open(tmp_path / "TEST_BEEP_01.json", encoding="utf-8"))
    assert abs(d["duration"] - length) < 0.1 and d["source"] == "amplitude"


@pytest.mark.skipif(not lipsync.rhubarb_exe(fetch=False), reason="Rhubarb not fetched (tools/mocap.sh lipsync fetches it)")
def test_rhubarb_cues_end_within_a_tenth_of_the_take(tmp_path, monkeypatch):
    monkeypatch.setattr(lipsync, "OUT", str(tmp_path))
    lines, man = lipsync.vo_data()
    lid = "SEL_GL1_04"
    au = lipsync.audio_of(lid, man)
    if not au:
        pytest.skip("no take for %s" % lid)
    src = lipsync.make(lid, lines[lid], au, lipsync.rhubarb_exe(fetch=False), force=True)
    assert src.startswith("rhubarb")
    d = json.load(open(tmp_path / (lid + ".json"), encoding="utf-8"))
    assert abs(d["duration"] - lipsync.audio_length(au)) < 0.1
    assert d["cues"][-1][0] < d["duration"] and len(d["cues"]) > 10
