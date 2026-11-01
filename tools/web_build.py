#!/usr/bin/env python3
"""Helpers for tools/build_web.sh (UPDATE 09 section 2c, DECISIONS T-139).

  python -I tools/web_build.py presets <lists.json> <export_presets.cfg> <out.cfg>
      Writes a copy of export_presets.cfg with one extra preset per pack: "Web Main" (the "Web" preset, every pack
      file marked "remove") and "Web Pack <name>" (only that pack's files, marked "keep"; the root "remove"), all in
      Godot's "customized" export mode so a pack holds exactly its files and nothing it depends on.
  python -I tools/web_build.py finish <build/web> <lists.json>
      Gives the engine files and the packs content-hashed names (so they can be cached forever), points index.html
      at them, writes packs/manifest.json (the pack names, files and sizes MapPacks reads), copies web/vercel.json and
      web/middleware.js in, and prints the size table.
"""
import hashlib
import json
import os
import re
import shutil
import sys

MB = 1048576.0


def _preset_blocks(text):
    """[(index, header_block, options_block)] from an export_presets.cfg."""
    out = []
    for m in re.finditer(r"^\[preset\.(\d+)\]\n(.*?)(?=^\[preset\.\1\.options\]\n)\[preset\.\1\.options\]\n(.*?)(?=^\[preset\.\d+\]\n|\Z)",
                         text, re.S | re.M):
        out.append((int(m.group(1)), m.group(2), m.group(3)))
    return out


def _set(block, key, value):
    line = "%s=%s" % (key, value)
    if re.search(r"^%s=.*$" % re.escape(key), block, re.M):
        return re.sub(r"^%s=.*$" % re.escape(key), lambda _m: line, block, count=1, flags=re.M)
    return block.rstrip("\n") + "\n" + line + "\n"


def _dict(entries):
    return "{\n" + ",\n".join('"%s": "%s"' % (k, v) for k, v in entries) + "\n}"


def presets(lists_path, cfg_path, out_path):
    lists = json.load(open(lists_path, encoding="utf-8"))
    text = open(cfg_path, encoding="utf-8").read()
    blocks = _preset_blocks(text)
    web = [b for b in blocks if re.search(r'^name="Web"$', b[1], re.M)]
    if not web:
        raise SystemExit("no \"Web\" preset in " + cfg_path)
    _, head, opts = web[0]
    nxt = max(b[0] for b in blocks) + 1
    extra = []
    all_pack_files = [f for files in lists["packs"].values() for f in files]
    main = _set(head, "name", '"Web Main"')
    main = _set(main, "export_filter", '"customized"')
    main = _set(main, "customized_files", _dict([("res://", "keep")] + [(f, "remove") for f in all_pack_files]))
    extra.append((nxt, main, opts))
    nxt += 1
    for pack, files in sorted(lists["packs"].items()):
        h = _set(head, "name", '"Web Pack %s"' % pack)
        h = _set(h, "export_filter", '"customized"')
        h = _set(h, "customized_files", _dict([("res://", "remove")] + [(f, "keep") for f in files]))
        extra.append((nxt, h, opts))
        nxt += 1
    body = text.rstrip("\n") + "\n"
    for i, h, o in extra:
        body += "\n[preset.%d]\n%s[preset.%d.options]\n%s" % (i, h if h.endswith("\n") else h + "\n", i, o if o.endswith("\n") else o + "\n")
    open(out_path, "w", encoding="utf-8", newline="\n").write(body)
    print("[web_build] presets: Web Main + %d packs -> %s" % (len(lists["packs"]), out_path))


def _hash(paths):
    h = hashlib.sha1()
    for p in paths:
        with open(p, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
    return h.hexdigest()[:10]


def finish(out_dir, lists_path):
    lists = json.load(open(lists_path, encoding="utf-8"))
    idx = os.path.join(out_dir, "index.html")
    html = open(idx, encoding="utf-8").read()
    engine = [os.path.join(out_dir, "index" + s) for s in (".js", ".wasm")]
    eh = _hash(engine)
    stem = "cz-" + eh
    for suffix in (".js", ".wasm", ".audio.worklet.js", ".audio.position.worklet.js"):
        src = os.path.join(out_dir, "index" + suffix)
        if os.path.exists(src):
            os.replace(src, os.path.join(out_dir, stem + suffix))
    ph = _hash([os.path.join(out_dir, "index.pck")])
    main_pck = "cz-main-%s.pck" % ph
    os.replace(os.path.join(out_dir, "index.pck"), os.path.join(out_dir, main_pck))
    html = html.replace('src="index.js"', 'src="%s.js"' % stem)
    html = re.sub(r'"executable":\s*"index"', '"executable":"%s"' % stem, html)
    html = re.sub(r'"mainPack":\s*"index.pck",?', '', html)
    html = html.replace("const GODOT_CONFIG = {", 'const GODOT_CONFIG = {"mainPack":"%s",' % main_pck, 1)
    # file sizes in the config drive the loading bar; keep them pointing at the new names
    html = html.replace('"index.wasm"', '"%s.wasm"' % stem).replace('"index.pck"', '"%s"' % main_pck)
    open(idx, "w", encoding="utf-8", newline="\n").write(html)
    packs_dir = os.path.join(out_dir, "packs")
    manifest = {"version": 1, "main": main_pck, "packs": {}, "maps": lists["maps"]}
    for pack in sorted(lists["packs"]):
        src = os.path.join(packs_dir, pack + ".pck")
        if not os.path.exists(src):
            print("[web_build] WARNING: pack %s missing" % pack)
            continue
        h = _hash([src])
        name = "%s-%s.pck" % (pack, h)
        os.replace(src, os.path.join(packs_dir, name))
        manifest["packs"][pack] = {"file": name, "bytes": os.path.getsize(os.path.join(packs_dir, name))}
    json.dump(manifest, open(os.path.join(packs_dir, "manifest.json"), "w", encoding="utf-8"), indent=1)
    for f in ("vercel.json", "middleware.js"):
        src = os.path.join("web", f)
        if os.path.exists(src):
            shutil.copy(src, os.path.join(out_dir, f))
    # the size table
    wasm = os.path.getsize(os.path.join(out_dir, stem + ".wasm"))
    pck = os.path.getsize(os.path.join(out_dir, main_pck))
    small = sum(os.path.getsize(os.path.join(out_dir, f)) for f in os.listdir(out_dir)
                if os.path.isfile(os.path.join(out_dir, f)) and f not in (stem + ".wasm", main_pck))
    print("[web_build] size table (MB):")
    print("  %-28s %8.1f" % (stem + ".wasm", wasm / MB))
    print("  %-28s %8.1f" % (main_pck, pck / MB))
    print("  %-28s %8.1f" % ("html/js/icons/config", small / MB))
    print("  %-28s %8.1f   (target < 150)" % ("TO REACH THE MENU", (wasm + pck + small) / MB))
    tot_packs = 0
    for pack, e in manifest["packs"].items():
        tot_packs += e["bytes"]
        print("  %-28s %8.1f" % ("packs/" + e["file"], e["bytes"] / MB))
    print("  %-28s %8.1f" % ("ALL PACKS", tot_packs / MB))
    for map_id, need in sorted(lists["maps"].items()):
        b = sum(manifest["packs"][p]["bytes"] for p in need if p in manifest["packs"])
        print("  first match on %-13s %8.1f   (menu + %s)" % (map_id, (wasm + pck + small + b) / MB, " + ".join(need)))


if __name__ == "__main__":
    if len(sys.argv) >= 5 and sys.argv[1] == "presets":
        presets(sys.argv[2], sys.argv[3], sys.argv[4])
    elif len(sys.argv) >= 4 and sys.argv[1] == "finish":
        finish(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(2)
