#!/usr/bin/env python3
"""A three-way merge of a JSON object by top-level key (U11, T-189), for data files many branches edit at once
(data/gravelight/vo/lines.json, audio_manifest.json). Use it when `git merge` stops on such a file:

    python -I tools/json_merge3.py data/gravelight/vo/lines.json            # reads the index stages :1: :2: :3:
    python -I tools/json_merge3.py OUT --base B --ours O --theirs T          # or three files

A key changed on one side only takes that side; changed the same way on both, fine; changed differently on both
is a conflict: listed, and ours is kept unless --prefer theirs. Nested objects named in --deep (default "files",
the manifests' map) are merged the same way one level down. Writes OUT with the indent of the file on disk (key
order as ours). Exit code = conflicts.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys

_MISSING = object()


def _stage(path: str, n: int) -> dict:
    try:
        out = subprocess.run(["git", "show", ":%d:%s" % (n, path)], capture_output=True, check=True).stdout
    except subprocess.CalledProcessError:
        return {}
    return json.loads(out.decode("utf-8"))


def merge(base: dict, ours: dict, theirs: dict, prefer: str = "ours", deep: tuple = ("files",), where: str = "") -> tuple[dict, list]:
    out: dict = {}
    conflicts: list = []
    keys = list(ours.keys()) + [k for k in theirs.keys() if k not in ours]
    keys += [k for k in base.keys() if k not in ours and k not in theirs]
    for k in keys:
        b, o, t = base.get(k, _MISSING), ours.get(k, _MISSING), theirs.get(k, _MISSING)
        if k in deep and isinstance(o, dict) and isinstance(t, dict):
            sub, c = merge(b if isinstance(b, dict) else {}, o, t, prefer, (), where + k + ".")
            out[k] = sub
            conflicts += c
            continue
        if o == t:
            v = o
        elif o == b:
            v = t
        elif t == b:
            v = o
        else:
            conflicts.append(where + str(k))
            v = t if prefer == "theirs" else o
            if v is _MISSING:
                v = o if prefer == "theirs" else t
        if v is not _MISSING:
            out[k] = v
    return out, conflicts


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("--base")
    ap.add_argument("--ours")
    ap.add_argument("--theirs")
    ap.add_argument("--prefer", choices=["ours", "theirs"], default="ours")
    ap.add_argument("--deep", default="files")
    ap.add_argument("--indent", type=int, default=0, help="0 = the indent of the file on disk (default)")
    a = ap.parse_args()
    if a.base:
        load = lambda p: json.load(open(p, encoding="utf-8"))  # noqa: E731
        base, ours, theirs = load(a.base), load(a.ours), load(a.theirs)
    else:
        base, ours, theirs = _stage(a.out, 1), _stage(a.out, 2), _stage(a.out, 3)
    if a.indent <= 0:
        try:
            second = open(a.ours or a.out, encoding="utf-8").read().split("
", 2)[1]
            a.indent = max(1, len(second) - len(second.lstrip(" ")))
        except (OSError, IndexError):
            a.indent = 1
    merged, conflicts = merge(base, ours, theirs, a.prefer, tuple(x for x in a.deep.split(",") if x))
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(merged, f, ensure_ascii=False, indent=a.indent)
        f.write("\n")
    for c in conflicts:
        print("CONFLICT", c)
    print("merged %d keys, %d conflicts" % (len(merged), len(conflicts)))
    return len(conflicts)


if __name__ == "__main__":
    sys.exit(main())
