#!/usr/bin/env python3
"""T-285: PUT the teaser's source clips to the presigned URLs a Higgsfield media_upload returned (saved as JSON),
as the T-277 recipe: Content-Type video/mp4 and If-None-Match: *. Writes build/trailers/hf/media_ids.json.
  python tools/trailer/hf_put.py <media_upload result json> <dir with <shot>.mp4>"""
import json
import os
import re
import subprocess
import sys

d = json.load(open(sys.argv[1], encoding="utf-8"))
src = sys.argv[2]
idsf = os.path.join("build", "trailers", "hf", "media_ids.json")
ids = json.load(open(idsf)) if os.path.exists(idsf) else {}
for u in d["uploads"]:
    blob = json.dumps(u)
    m = re.search(r"t285_([a-z0-9_]+)\.mp4", blob)
    if not m:
        print("no file name in", list(u.keys()))
        continue
    shot = m.group(1)
    path = os.path.join(src, shot + ".mp4")
    r = subprocess.run(["curl", "-s", "-o", os.devnull, "-w", "%{http_code}", "-X", "PUT", "-H", "Content-Type: video/mp4",
                        "-H", "If-None-Match: *", "--data-binary", "@" + path, u["upload_url"]], capture_output=True, text=True)
    print(shot, r.stdout)
    if r.stdout == "200":
        ids[shot] = u["media_id"]
json.dump(ids, open(idsf, "w"), indent=1)
print(len(ids), "ids")
