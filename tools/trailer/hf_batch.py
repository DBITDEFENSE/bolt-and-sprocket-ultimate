#!/usr/bin/env python3
"""T-285: print the generate_video_batch requests for teaser shots (Seedance 2.5 video_edit, 480p, the shot's
uploaded source as the video reference). Also rebuilds build/trailers/hf/prompts.json from teaser_prompts.json.
  python tools/trailer/hf_batch.py t01_crossroads t02_inn_front ...   (index = the shot number)"""
import json
import os
import sys

T = json.load(open(os.path.join(os.path.dirname(__file__), "teaser_prompts.json"), encoding="utf-8"))
R = T["rules"] + T.get("clothing_rule", "")
P = {k: T["wrapper"] + v + R for k, v in T["shots"].items()}
json.dump(P, open("build/trailers/hf/prompts.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)
ids = json.load(open("build/trailers/hf/media_ids.json"))
req = []
for k in sys.argv[1:]:
    extra = T.get("extra", {}).get(k, "")
    req.append({"index": int(k[1:3]), "params": {"model": T["model"], "mode": T["mode"], "resolution": T["resolution"],
                "generate_audio": False, "aspect_ratio": "16:9", "medias": [{"role": "video_references", "value": ids[k]}],
                "prompt": P[k] + extra}})
print(json.dumps(req, ensure_ascii=False))
