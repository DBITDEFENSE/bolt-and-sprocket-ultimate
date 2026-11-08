#!/usr/bin/env python3
"""T-211: how far the bots' Wreck Loop (data/gravelight/ai/routes_map00.json) keeps from GRAVELIGHT ONE's colliders.

    python -I tools/c47/route_clearance.py

Samples the loop every 0.25 m and measures the horizontal distance to every debris box (data/gravelight/
c47_colliders.json, site frame) and the hull's boxes (the wreck frame, approximated by their footprints after the
yaw). The loop's notes ask for 3.5 m+ off the hull, the wings and the tail; prints the closest per box.
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = (46.0, 6.0)
YAW = math.radians(28.0)


def to_site(wx, wz):
    dx, dz = wx - SITE[0], wz - SITE[1]
    return dx * math.cos(YAW) - dz * math.sin(YAW), dx * math.sin(YAW) + dz * math.cos(YAW)


def dist_obb(px, pz, box):
    c = box["center"]
    s = box["size"]
    b = box["basis"]   # rows; columns are the axes
    ax = [(b[0][k], b[1][k], b[2][k]) for k in range(3)]
    d = (px - c[0], 0.0, pz - c[2])
    # horizontal distance: project onto each axis' horizontal part, clamp, measure in xz
    q = [0.0, 0.0, 0.0]
    best = None
    # brute force on the box's footprint (8 corners projected; the point-in-hull test via sampling)
    corners = []
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            for sz in (-0.5, 0.5):
                x = c[0] + ax[0][0] * s[0] * sx + ax[1][0] * s[1] * sy + ax[2][0] * s[2] * sz
                z = c[2] + ax[0][2] * s[0] * sx + ax[1][2] * s[1] * sy + ax[2][2] * s[2] * sz
                corners.append((x, z))
    hull = convex_hull(corners)
    return poly_dist(px, pz, hull)


def convex_hull(pts):
    pts = sorted(set(pts))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def poly_dist(px, pz, hull):
    inside = True
    n = len(hull)
    for i in range(n):
        a, b = hull[i], hull[(i + 1) % n]
        if (b[0] - a[0]) * (pz - a[1]) - (b[1] - a[1]) * (px - a[0]) < 0:
            inside = False
    if inside:
        return 0.0
    best = 1e9
    for i in range(n):
        a, b = hull[i], hull[(i + 1) % n]
        dx, dz = b[0] - a[0], b[1] - a[1]
        L2 = dx * dx + dz * dz
        t = max(0.0, min(1.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / L2)) if L2 > 0 else 0.0
        best = min(best, math.hypot(px - a[0] - t * dx, pz - a[1] - t * dz))
    return best


def main():
    routes = json.load(open(os.path.join(ROOT, "data", "gravelight", "ai", "routes_map00.json"), encoding="utf-8"))
    loop = None
    for r in routes.get("routes", routes if isinstance(routes, list) else []):
        if isinstance(r, dict) and r.get("id") == "map00_wreck_loop":
            loop = r
    if loop is None:
        raise SystemExit("no map00_wreck_loop")
    pts = [to_site(p[0], p[2]) for p in loop["points"]]
    samples = []
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 0.25))
        for k in range(n):
            samples.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
    boxes = json.load(open(os.path.join(ROOT, "data", "gravelight", "c47_colliders.json"), encoding="utf-8"))["boxes"]
    # the hull's own footprint in the site frame (the wreck frame's x is ~the site's: the roll is about z)
    eye = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    hull = [{"name": "hull", "center": [0.0, 0.0, -1.2], "size": [2.9, 3.0, 14.5], "basis": eye},
            {"name": "port wing", "center": [-5.2, 0.0, -0.2], "size": [7.6, 2.0, 4.5], "basis": eye}]
    worst = 1e9
    for b in boxes + hull:
        d, at = min((dist_obb(x, z, b), (round(x, 1), round(z, 1))) for (x, z) in samples)
        worst = min(worst, d)
        print("%-22s %.2f m  (loop at site %s)" % (b["name"], d, at))
    print("closest: %.2f m (the loop asks 3.5 m+)" % worst)


if __name__ == "__main__":
    main()
