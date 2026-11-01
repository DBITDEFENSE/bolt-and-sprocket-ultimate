#!/usr/bin/env python3
"""List what a Godot 4 .pck holds, summed by folder (UPDATE 09 section 2c, T-139: the web build's size budget).

  python -I tools/pck_sizes.py build/web/index.pck [--depth=3] [--top=25] [--files=20]

Reads the PCK directory (format v2 and v3; unencrypted) and prints the total, the biggest folders at the given
depth (the res:// path's first N components; `.godot/imported/<file>-<hash>.<ext>` is folded back to its source
file's folder through the matching `.import` entries in the same pack when it can be matched) and the biggest files.
"""
import struct
import sys
from collections import defaultdict


def read_dir(path):
    with open(path, "rb") as f:
        data = f.read()
    off = 0
    if data[:4] != b"GDPC":
        # embedded in an executable: the last 12 bytes are [pck size u64]["GDPC"]
        if data[-4:] == b"GDPC":
            size = struct.unpack_from("<Q", data, len(data) - 12)[0]
            off = len(data) - 12 - size
        else:
            raise SystemExit("not a pck: %s" % path)
    ver, major, minor, patch = struct.unpack_from("<4I", data, off + 4)
    p = off + 20
    flags = 0
    file_base = 0
    dir_off = None
    if ver >= 2:
        flags, file_base = struct.unpack_from("<IQ", data, p)
        p += 12
    if ver >= 3:
        dir_off = struct.unpack_from("<Q", data, p)[0]
        p += 8
    p += 16 * 4  # reserved
    if dir_off is not None:
        p = off + dir_off
    if flags & 1:
        raise SystemExit("encrypted directory: can't list")
    count = struct.unpack_from("<I", data, p)[0]
    p += 4
    out = []
    for _ in range(count):
        n = struct.unpack_from("<I", data, p)[0]
        p += 4
        name = data[p:p + n].rstrip(b"\0").decode("utf-8", "replace")
        if not name.startswith("res://"):
            name = "res://" + name   # PCK v3 (4.4+) stores paths without the prefix
        p += n
        _ofs, size = struct.unpack_from("<QQ", data, p)
        p += 16 + 16  # offset, size, md5
        if ver >= 2:
            p += 4  # flags
        out.append((name, size))
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    depth = int(opts.get("depth", 3))
    top = int(opts.get("top", 25))
    nfiles = int(opts.get("files", 20))
    for path in args:
        entries = read_dir(path)
        total = sum(s for _, s in entries)
        # map imported artefacts back to their source: the .import entries name them (path="res://.godot/imported/...")
        owner = {}
        names = {n for n, _ in entries}
        exported = {}
        for n in names:
            if n.endswith(".import"):
                src = n[: -len(".import")]
                base = src.rsplit("/", 1)[-1]
                owner[base] = src
            elif n.endswith(".remap"):
                src = n[: -len(".remap")]
                exported[src.rsplit("/", 1)[-1].rsplit(".", 1)[0]] = src
        by = defaultdict(int)
        files = []
        for n, s in entries:
            src = n
            if n.startswith("res://.godot/imported/"):
                fname = n.rsplit("/", 1)[-1]
                stem = fname.rsplit("-", 1)[0]
                src = owner.get(stem, n)
            elif n.startswith("res://.godot/exported/"):
                stem = n.rsplit("/", 1)[-1].split("-", 2)[-1].rsplit(".", 1)[0]
                src = exported.get(stem, n)
            rel = src.replace("res://", "")
            key = "/".join(rel.split("/")[: depth]) if "/" in rel else "(root)"
            by[key] += s
            files.append((s, src))
        print("%s: %d files, %.1f MB" % (path, len(entries), total / 1048576))
        for k, v in sorted(by.items(), key=lambda kv: -kv[1])[:top]:
            print("  %8.1f MB  %s" % (v / 1048576, k))
        print("  biggest files:")
        for s, n in sorted(files, reverse=True)[:nfiles]:
            print("  %8.1f MB  %s" % (s / 1048576, n))


if __name__ == "__main__":
    main()
