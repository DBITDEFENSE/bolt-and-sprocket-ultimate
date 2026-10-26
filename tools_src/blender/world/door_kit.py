"""Door ironmongery (UPDATE_05 section 5, DECISIONS T-094).

    blender -b -P tools_src/blender/world/door_kit.py

Writes assets/ours/world/door_kit/model.glb: the parts DoorArt (gravelight/world/door_art.gd) hangs on the bought
doors' plank leaves, whatever their size. Every part faces -Z (its front plane at z = 0, built toward -Z), +Y up.
  Hinge    a blacksmith's strap hinge: a tapered strap with a fleur end and rivets, pivot at the knuckle, running +X
  Plaque   the brass price plaque: a bevelled brass frame round a dark enamel field (the price label is the
           script's, so set_cost keeps working), four screws; 0.62 x 0.3, centred
  Padlock  a hasp and staple with a heavy padlock hanging from it; origin at the staple
  Chain    a sagging chain 1 m across between two eye staples (DoorArt scales X to the opening)
  Pull     a ring pull on a back plate
  Bar      a timber drop-bar on two iron brackets, 1 m (scaled to the opening)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wo_lib as W  # noqa: E402


def hinge():
    p = W.Part("Hinge")
    L = 0.55
    W.cyl(p, (0, 0, -0.012), 0.016, 0.12, "lib_iron", segs=10)                     # the knuckle (pin along Y)
    pts = [(0.0, -0.028), (L * 0.75, -0.022), (L * 0.85, -0.04), (L, 0.0), (L * 0.85, 0.04), (L * 0.75, 0.022), (0.0, 0.028)]
    W.prism(p, pts, -0.012, -0.004, "lib_iron", bevel=0.002)
    for k in range(4):
        W.dot(p, (0.06 + k * 0.13, 0.0, -0.013), 0.007, "lib_iron", 4)
    p.build()


def plaque():
    p = W.Part("Plaque")
    w, h = 0.62, 0.3
    W.box(p, (-w * 0.5, -h * 0.5, -0.016), (w * 0.5, h * 0.5, 0.0), "mats_brass", 0.006, segs=2)
    W.box(p, (-w * 0.5 + 0.03, -h * 0.5 + 0.03, -0.019), (w * 0.5 - 0.03, h * 0.5 - 0.03, -0.012), "mats_nameplate", 0.003)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            W.cyl(p, (sx * (w * 0.5 - 0.015), sy * (h * 0.5 - 0.015), -0.018), 0.007, 0.006, "mats_steel", axis="z", segs=8)
    p.build()


def padlock():
    p = W.Part("Padlock")
    W.box(p, (-0.03, -0.02, -0.014), (0.03, 0.02, 0.0), "lib_iron", 0.003)            # the staple's plate
    W.torus(p, (0, 0.0, -0.03), 0.018, 0.005, "lib_iron", rot=(0, 90, 0), segs=10, rsegs=4)
    W.box(p, (-0.13, -0.025, -0.02), (0.02, 0.025, -0.012), "lib_iron", 0.003)        # the hasp over it
    W.torus(p, (0, -0.045, -0.032), 0.024, 0.006, "mats_steel", axis="z", segs=12, rsegs=4)
    W.box(p, (-0.04, -0.12, -0.048), (0.04, -0.055, -0.018), "mats_brass", 0.008, segs=2)
    W.cyl(p, (0, -0.095, -0.05), 0.007, 0.004, "mats_char", axis="z", segs=8)
    p.build()


def chain():
    p = W.Part("Chain")
    n = 18
    prev = None
    for k in range(n):
        t = (k + 0.5) / n
        x = -0.5 + t
        y = -math.sin(t * math.pi) * 0.14
        yaw = 0.0
        if prev is not None:
            yaw = math.degrees(math.atan2(y - prev[1], x - prev[0]))
        rot = (90, 0, yaw) if k % 2 == 0 else (0, 0, yaw)
        W.torus(p, (x, y, -0.02), 0.028, 0.006, "lib_iron", rot=rot, segs=10, rsegs=4)
        prev = (x, y)
    for sx in (-0.5, 0.5):
        W.cyl(p, (sx, 0.0, -0.02), 0.014, 0.04, "lib_iron", axis="z", segs=8)
    p.build()


def pull():
    p = W.Part("Pull")
    W.cyl(p, (0, 0, -0.006), 0.05, 0.012, "lib_iron", axis="z", segs=14, bevel=0.003)
    W.cyl(p, (0, 0.02, -0.02), 0.01, 0.025, "lib_iron", axis="z", segs=8)
    W.torus(p, (0, -0.03, -0.03), 0.05, 0.008, "lib_iron", axis="z", segs=16, rsegs=5)
    p.build()


def bar():
    p = W.Part("Bar")
    W.box(p, (-0.5, -0.06, -0.08), (0.5, 0.06, -0.01), "lib_planks", 0.01)
    for sx in (-0.42, 0.42):
        W.box(p, (sx - 0.03, -0.08, -0.095), (sx + 0.03, 0.08, -0.004), "lib_iron", 0.004)
        W.dot(p, (sx, 0.06, -0.098), 0.008, "lib_iron", 4)
        W.dot(p, (sx, -0.06, -0.098), 0.008, "lib_iron", 4)
    p.build()


if __name__ == "__main__":
    W.reset()
    hinge()
    plaque()
    padlock()
    chain()
    pull()
    bar()
    W.export("door_kit", "Door ironmongery", "strap hinge, brass price plaque, padlock and hasp, chain, ring pull, drop bar", "door_kit.py")
