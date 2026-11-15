#!/usr/bin/env python3
"""The table of a tools/move_rates.sh batch: every "[move-rates] <metric> = <value>" line of
.smoke_logs/move_rates/<tag>/fps<N>.log (N frames a second, the game's 60 physics ticks) side by side, then the
same for ticks<N>.log (N frames and N physics ticks a second).

    python -I tools/move_rates_table.py .smoke_logs/move_rates/<tag> [--md]
"""
import glob
import os
import re
import sys


def read(path):
    out = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"\[move-rates\] (.+?)\s+= (.*)$", line.rstrip())
        if m:
            out[m.group(1)] = m.group(2)
    return out


def rate_of(path):
    return int(re.sub(r"\D", "", os.path.basename(path)))


def table(d, prefix, md):
    files = glob.glob(os.path.join(d, prefix + "*.log"))
    if prefix == "ticks" and files and os.path.exists(os.path.join(d, "fps60.log")):
        files.append(os.path.join(d, "fps60.log"))
    files.sort(key=rate_of)
    if not files:
        return
    cols = [(str(rate_of(p)), read(p)) for p in files]
    keys = []
    for _, c in cols:
        for k in c:
            if k not in keys:
                keys.append(k)
    what = "frames a second (60 physics ticks)" if prefix == "fps" else "frames and physics ticks a second"
    if md:
        print("| Measure, by %s | %s |" % (what, " | ".join(n for n, _ in cols)))
        print("|---|%s" % ("---|" * len(cols)))
        for k in keys:
            print("| %s | %s |" % (k, " | ".join(c.get(k, "-") for _, c in cols)))
        print()
    else:
        print("== by %s" % what)
        print("%-58s %s" % ("", "".join("%-24s" % n for n, _ in cols)))
        for k in keys:
            print("%-58s %s" % (k[:58], "".join("%-24s" % c.get(k, "-") for _, c in cols)))
        print()


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    table(args[0], "fps", "--md" in sys.argv)
    table(args[0], "ticks", "--md" in sys.argv)
