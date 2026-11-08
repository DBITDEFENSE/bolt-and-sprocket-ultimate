#!/usr/bin/env python3
"""Train the bot planner's built-in brain from logged model answers (T-217).

Every time a local model (Ollama) picks a planner option, the game appends one JSON line to
user://bot_ai/decisions.jsonl: the match state, every option (kind, score, distance, current or not) and the pick.
This script fits the built-in brain to those picks, a choice model over the options:

    u = score_scale * score + kind_bias[kind] + dist_w * dist_m + current_bonus * (is the current objective)

(BotPlanner.learned_index picks the highest u; with score_scale 1, no biases and current_bonus 8 it is the plain
scripted planner.) The fit is a softmax over each decision's options (conditional logit), L2-regularised toward
the plain planner, trained on the first 80 % of the rows and checked on the last 20 %. The weights are written
only when they agree with the model more often than the plain planner does on the held-out rows (or --force).

Usage:
  python -I tools/bot_ai/train_planner.py [decisions.jsonl ...] [--out data/gravelight/bot_planner_learned.json]
                                          [--min-rows 60] [--force] [--dry-run]
With no files it reads the game's own log in the Godot user folder (TERMS & CONDITIONS / GRAVELIGHT).
"""
import argparse
import datetime
import json
import math
import os
import sys

DEFAULT_OUT = os.path.join("data", "gravelight", "bot_planner_learned.json")
PLAIN = {"score_scale": 1.0, "kind_bias": {}, "dist_w": 0.0, "current_bonus": 8.0}


def user_logs():
    """The decisions.jsonl files in the Godot user folders on this machine."""
    roots = []
    if os.name == "nt":
        roots.append(os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata"))
    else:
        roots.append(os.path.join(os.path.expanduser("~"), ".local", "share", "godot", "app_userdata"))
    out = []
    for r in roots:
        for app in ("TERMS & CONDITIONS", "GRAVELIGHT", "ClaudeZombies"):
            p = os.path.join(r, app, "bot_ai", "decisions.jsonl")
            if os.path.isfile(p):
                out.append(p)
    return out


def load_rows(paths):
    rows = []
    for p in paths:
        with open(p, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    r = json.loads(line)
                except ValueError:
                    continue
                opts = r.get("opts") or []
                pick = r.get("pick")
                if isinstance(pick, int) and 0 <= pick < len(opts) and len(opts) >= 2:
                    rows.append(r)
    return rows


def utilities(w, kinds, opts):
    """u per option for weights vector w = [scale, dist_w, cur_bonus, bias per kind...]."""
    out = []
    for o in opts:
        k = kinds.get(o.get("kind", ""), None)
        b = w[3 + k] if k is not None else 0.0
        out.append(w[0] * float(o.get("score", 0.0)) + b + w[1] * float(o.get("dist", 0.0)) + w[2] * (1.0 if o.get("cur") else 0.0))
    return out


def argmax(xs):
    best, bi = -math.inf, -1
    for i, x in enumerate(xs):
        if x > best:
            best, bi = x, i
    return bi


def agreement(w, kinds, rows):
    if not rows:
        return 0.0
    hit = sum(1 for r in rows if argmax(utilities(w, kinds, r["opts"])) == r["pick"])
    return hit / len(rows)


def fit(rows, kinds, iters=1500, lr=0.1, l2=0.002, temp=8.0):
    """Adam ascent on the softmax log-likelihood (utilities divided by temp, about one option score step), with an
    L2 pull toward the plain planner so rare kinds stay near 0."""
    n_k = len(kinds)
    w = [1.0, 0.0, 8.0] + [0.0] * n_k
    prior = list(w)
    m1 = [0.0] * len(w)
    m2 = [0.0] * len(w)
    for t in range(1, iters + 1):
        g = [0.0] * len(w)
        for r in rows:
            opts = r["opts"]
            u = [x / temp for x in utilities(w, kinds, opts)]
            m = max(u)
            e = [math.exp(x - m) for x in u]
            z = sum(e)
            p = [x / z for x in e]
            for j, o in enumerate(opts):
                d = ((1.0 if j == r["pick"] else 0.0) - p[j]) / temp
                g[0] += d * float(o.get("score", 0.0))
                g[1] += d * float(o.get("dist", 0.0))
                g[2] += d * (1.0 if o.get("cur") else 0.0)
                k = kinds.get(o.get("kind", ""), None)
                if k is not None:
                    g[3 + k] += d
        n = float(len(rows))
        for i in range(len(w)):
            gi = g[i] / n - l2 * (w[i] - prior[i])
            m1[i] = 0.9 * m1[i] + 0.1 * gi
            m2[i] = 0.999 * m2[i] + 0.001 * gi * gi
            mh = m1[i] / (1.0 - 0.9 ** t)
            vh = m2[i] / (1.0 - 0.999 ** t)
            w[i] += lr * mh / (math.sqrt(vh) + 1e-8)
        w[0] = max(0.1, w[0])
    return w


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*")
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--min-rows", type=int, default=60)
    ap.add_argument("--force", action="store_true", help="write the weights even when they don't beat the plain planner")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    paths = a.files or user_logs()
    rows = load_rows(paths)
    print("[train] %d usable decisions from %s" % (len(rows), ", ".join(paths) if paths else "no files"))
    if len(rows) < a.min_rows:
        print("[train] fewer than %d decisions: keeping the plain planner (play with a model brain, or run a soak with --local-ai=small)" % a.min_rows)
        return 0
    models = sorted({str(r.get("model", "")) for r in rows})
    kinds_seen = {}
    for r in rows:
        for o in r["opts"]:
            kinds_seen[o.get("kind", "")] = kinds_seen.get(o.get("kind", ""), 0) + 1
    kinds = {k: i for i, k in enumerate(sorted(kinds_seen))}
    cut = int(len(rows) * 0.8)
    train, test = rows[:cut], rows[cut:]
    plain_w = [1.0, 0.0, 8.0] + [0.0] * len(kinds)
    w = fit(train, kinds)
    base_tr, base_te = agreement(plain_w, kinds, train), agreement(plain_w, kinds, test)
    new_tr, new_te = agreement(w, kinds, train), agreement(w, kinds, test)
    print("[train] agreement with the model: plain planner %.0f%% train / %.0f%% held out; trained %.0f%% / %.0f%%" % (
        base_tr * 100, base_te * 100, new_tr * 100, new_te * 100))
    picks = {}
    for r in rows:
        k = r["opts"][r["pick"]].get("kind", "")
        picks[k] = picks.get(k, 0) + 1
    print("[train] the model's picks by kind: %s" % ", ".join("%s %d" % kv for kv in sorted(picks.items(), key=lambda kv: -kv[1])))
    weights = {"score_scale": round(w[0], 4), "dist_w": round(w[1], 4), "current_bonus": round(w[2], 3),
               "kind_bias": {k: round(w[3 + i], 3) for k, i in kinds.items() if abs(w[3 + i]) >= 0.05}}
    print("[train] weights: %s" % json.dumps(weights))
    better = new_te > base_te
    if not better and not a.force:
        print("[train] the trained weights don't beat the plain planner on the held-out rows: nothing written (--force writes anyway)")
        return 0
    doc = {
        "_doc": "T-217: the bot planner's built-in brain (BotPlanner.learned_index): u = score_scale * score + kind_bias[kind] + dist_w * dist_m + current_bonus for the current objective; the best u wins. Trained by tools/bot_ai/train_planner.py from logged local-model picks (user://bot_ai/decisions.jsonl). Retrain after more play with a model brain; delete the weights to go back to the plain scores (score_scale 1, current_bonus 8).",
        "trained": datetime.date.today().isoformat(),
        "rows": len(rows), "models": models,
        "agreement_plain_heldout": round(base_te, 3), "agreement_trained_heldout": round(new_te, 3),
    }
    doc.update(weights)
    if a.dry_run:
        print(json.dumps(doc, indent=1))
        return 0
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")
    print("[train] wrote %s" % a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
