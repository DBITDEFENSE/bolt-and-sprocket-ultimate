"""The wall-gun mount (UPDATE_05 section 5, DECISIONS T-094).

    blender -b -P tools_src/blender/world/wall_mount.py

Writes assets/ours/world/wall_mount/model.glb, the pieces WallBuy hangs a gun on:
  Board  three planks painted the wall-buy green (the readability cue: the old flat board's colour, 0.18/0.45/0.2)
         worn to the wood at the edges, a batten frame, chalk dust along the bottom, a nail-hole or two; 1.3 x 0.55,
         its face at z = 0 and its back on the wall at z = +0.04 (the old board's box), origin at its centre
  Nail   one forged nail standing out of the board toward -Z, its head at z = -0.05 (the gun rests on two)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wo_lib as W  # noqa: E402

GREEN = "2e7333"


def board():
    p = W.Part("Board")
    w, h = 1.3, 0.55
    W.box(p, (-w * 0.5 + 0.01, -h * 0.5 + 0.01, 0.02), (w * 0.5 - 0.01, h * 0.5 - 0.01, 0.04), "lib_planks", 0.0)
    for i in range(3):
        y0 = -h * 0.5 + i * h / 3.0 + 0.004
        y1 = -h * 0.5 + (i + 1) * h / 3.0 - 0.004
        d = W.jit(i, 3, 0.003)
        W.box(p, (-w * 0.5 + 0.03, y0, 0.0 + d), (w * 0.5 - 0.03, y1, 0.022), W.paint(GREEN), 0.006)
        # bare wood where the paint has worn off the plank's ends
        for sx in (-1.0, 1.0):
            W.box(p, (sx * (w * 0.5 - 0.03) - (0.06 if sx > 0 else 0.0), y0 + 0.01, d - 0.0008), (sx * (w * 0.5 - 0.03) + (0.0 if sx > 0 else 0.06) - sx * 0.0, y1 - 0.01, d - 0.0002),
                  "lib_planks", 0.0)
    # the batten frame
    for (a, b) in [((-w * 0.5, -h * 0.5), (w * 0.5, -h * 0.5 + 0.035)), ((-w * 0.5, h * 0.5 - 0.035), (w * 0.5, h * 0.5)),
                   ((-w * 0.5, -h * 0.5), (-w * 0.5 + 0.035, h * 0.5)), ((w * 0.5 - 0.035, -h * 0.5), (w * 0.5, h * 0.5))]:
        W.box(p, (a[0], a[1], -0.008), (b[0], b[1], 0.04), "lib_planks", 0.006)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            W.dot(p, (sx * (w * 0.5 - 0.018), sy * (h * 0.5 - 0.018), -0.01), 0.007, "lib_iron", 4)
    # chalk dust along the bottom batten
    W.box(p, (-w * 0.4, -h * 0.5 + 0.035, -0.009), (w * 0.35, -h * 0.5 + 0.045, -0.006), "chalk", 0.0)
    p.build()


def nail():
    p = W.Part("Nail")
    W.cyl(p, (0, 0, -0.025), 0.004, 0.05, "lib_iron", axis="z", segs=6)
    W.cyl(p, (0, 0, -0.051), 0.009, 0.005, "lib_iron", axis="z", segs=8)
    p.build()


if __name__ == "__main__":
    W.reset()
    board()
    nail()
    W.export("wall_mount", "Wall-gun mount", "the green chalk board and the forged nails a wall gun hangs on", "wall_mount.py")
