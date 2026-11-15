#!/usr/bin/env python
"""Fetch the CC0 art library (UPDATE_05 section 1 / 05A section 1.2-1.3, T-088).

Driven by data/gravelight/art/cc0_assets.json. Re-runnable: an asset whose folder already holds a SOURCE.txt is
skipped unless --force. Add an entry to the list, run the script, commit the new folder.

    python -I tools/fetch_cc0_materials.py [--only=id,id] [--force] [--dry-run] [--keep-downloads]

Sources: Poly Haven (api.polyhaven.com; textures, HDRIs, glTF models), ambientCG (ambientcg.com/api/v2; texture zips)
and a Kenney CC0 pack (named GLB members out of its zip). Everything they return is untrusted data: each download
goes in its own folder under tools_src/_downloads/ (git-ignored), archives are opened with zipfile and only image /
GLB members with safe names are read, nothing downloaded is ever executed, and the raw files are deleted after the
import unless --keep-downloads.

What lands in assets/third_party/<source>/<kebab-id>/:
  textures/<id>_albedo.png   sRGB colour
  textures/<id>_normal.png   tangent-space normal, OpenGL convention (+Y up; Godot's convention)
  textures/<id>_orm.png      R = ambient occlusion, G = roughness, B = metallic (Godot's / glTF's packing)
  textures/<id>_height.png   8-bit height (only when the list says height: true)
  <id>_<res>.hdr             for HDRIs
  model.glb + textures/*.png for models (the glTF is packed into a GLB here; images stay external PNGs)
  LICENSE.txt                the CC0 1.0 legal code
  SOURCE.txt                 title / authors / source / license / credit line / format / downloaded / files used
"""
import io
import json
import os
import re
import shutil
import struct
import sys
import time
import urllib.request
import zipfile
from datetime import date

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("Pillow is required: pip install pillow", file=sys.stderr)
    sys.exit(2)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
LIST_PATH = os.path.join(ROOT, "data", "gravelight", "art", "cc0_assets.json")
DL_ROOT = os.path.join(ROOT, "tools_src", "_downloads")
OUT_ROOT = os.path.join(ROOT, "assets", "third_party")
UA = "cc0-asset-fetch/1.0"   # generic: nothing about the project goes out with a download (T-252)
CC0_URL = "https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt"
CC0_FALLBACK = (
    "CC0 1.0 Universal (CC0 1.0) Public Domain Dedication\n"
    "https://creativecommons.org/publicdomain/zero/1.0/\n\n"
    "The person who associated a work with this deed has dedicated the work to the public domain by waiving all of\n"
    "his or her rights to the work worldwide under copyright law, including all related and neighboring rights, to\n"
    "the extent allowed by law. You can copy, modify, distribute and perform the work, even for commercial purposes,\n"
    "all without asking permission.\n"
)
RES_PX = {"512": 512, "1k": 1024, "2k": 2048, "4k": 4096}
WHO = "Claude Code (tools/fetch_cc0_materials.py)"

Image.MAX_IMAGE_PIXELS = 64 * 1024 * 1024


# ----------------------------------------------------------------------------------------------- helpers

def kebab(asset_id: str) -> str:
    s = asset_id.replace("_", "-")
    s = re.sub(r"([a-z])([A-Z])", r"\1-\2", s)
    s = re.sub(r"([A-Za-z])(\d)", r"\1-\2", s)
    return s.lower()


def log(msg: str) -> None:
    print(msg, flush=True)


def fetch(url: str, dest: str, retries: int = 3) -> str:
    """Download url to dest (streaming). Returns dest."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r, open(dest, "wb") as f:
                shutil.copyfileobj(r, f, 1 << 16)
            return dest
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("download failed: %s (%s)" % (url, last))


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def cc0_text() -> str:
    cache = os.path.join(DL_ROOT, "cc0", "legalcode.txt")
    if not os.path.exists(cache):
        try:
            fetch(CC0_URL, cache)
        except Exception as e:  # noqa: BLE001
            log("  ! CC0 legal code not fetched (%s); writing the short dedication" % e)
            return CC0_FALLBACK
    with open(cache, "r", encoding="utf-8", errors="replace") as f:
        txt = f.read()
    if "CC0 1.0 Universal" not in txt:
        return CC0_FALLBACK
    return txt


def write_text(path: str, text: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def to_png(src: str, dest: str, max_px: int, mode: str = "RGB") -> int:
    """Convert an image to an 8-bit PNG no larger than max_px on a side. Returns the written size in bytes."""
    with Image.open(src) as im:
        im = im.convert(mode)
        if max(im.size) > max_px:
            scale = max_px / float(max(im.size))
            im = im.resize((max(1, round(im.size[0] * scale)), max(1, round(im.size[1] * scale))), Image.LANCZOS)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        im.save(dest, optimize=True, compress_level=9)
    return os.path.getsize(dest)


def pack_orm(ao: str, rough: str, metal: str, dest: str, max_px: int) -> int:
    """R = AO (white when missing), G = roughness, B = metallic (black when missing)."""
    with Image.open(rough) as r_im:
        r_im = r_im.convert("L")
        size = r_im.size
        if max(size) > max_px:
            scale = max_px / float(max(size))
            size = (max(1, round(size[0] * scale)), max(1, round(size[1] * scale)))
            r_im = r_im.resize(size, Image.LANCZOS)
        if ao and os.path.exists(ao):
            with Image.open(ao) as a_im:
                a_im = a_im.convert("L").resize(size, Image.LANCZOS)
        else:
            a_im = Image.new("L", size, 255)
        if metal and os.path.exists(metal):
            with Image.open(metal) as m_im:
                m_im = m_im.convert("L").resize(size, Image.LANCZOS)
        else:
            m_im = Image.new("L", size, 0)
        out = Image.merge("RGB", (a_im, r_im, m_im))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        out.save(dest, optimize=True, compress_level=9)
    return os.path.getsize(dest)


def folder_size(path: str) -> int:
    total = 0
    for dp, _dn, fn in os.walk(path):
        for f in fn:
            total += os.path.getsize(os.path.join(dp, f))
    return total


def source_txt(title: str, authors: str, page: str, files_urls: list, credit: str, fmt: str, used: list,
               extra: dict | None = None) -> str:
    lines = [
        "Title: %s" % title,
        "Authors: %s" % authors,
        "Source: %s" % page,
        "File: %s" % ("; ".join(files_urls) if files_urls else page),
        "License: CC0 1.0 Universal (public domain dedication) — https://creativecommons.org/publicdomain/zero/1.0/",
        "Credit line: %s" % credit,
        "Format: %s" % fmt,
    ]
    for k, v in (extra or {}).items():
        lines.append("%s: %s" % (k, v))
    lines.append("Downloaded: %s by %s (tools/fetch_cc0_materials.py)" % (date.today().isoformat(), WHO))
    lines.append("Files used: %s" % ", ".join(used))
    return "\n".join(lines) + "\n"


def safe_member(name: str) -> bool:
    if name.startswith("/") or name.startswith("\\") or ".." in name.replace("\\", "/").split("/"):
        return False
    return True


# ----------------------------------------------------------------------------------------------- Poly Haven

PH_API = "https://api.polyhaven.com"


def ph_info(asset_id: str) -> dict:
    return fetch_json("%s/info/%s" % (PH_API, asset_id))


def ph_authors(info: dict) -> str:
    a = info.get("authors") or {}
    if isinstance(a, dict):
        parts = []
        for name, role in a.items():
            parts.append("%s (%s)" % (name, role) if role and role != "All" else name)
        return ", ".join(parts) if parts else "Poly Haven"
    return str(a)


def ph_texture(entry: dict, out_dir: str, dl_dir: str) -> dict:
    aid = entry["id"]
    res = entry.get("res", "2k")
    orm_res = entry.get("orm_res", "1k")
    info = ph_info(aid)
    files = fetch_json("%s/files/%s" % (PH_API, aid))
    tex_dir = os.path.join(out_dir, "textures")
    os.makedirs(tex_dir, exist_ok=True)
    used, urls = [], []

    def grab(map_key: str, want_res: str) -> str | None:
        m = files.get(map_key)
        if not m:
            return None
        r = want_res if want_res in m else next((k for k in ("2k", "1k", "4k") if k in m), None)
        if r is None:
            return None
        fmt = "jpg" if "jpg" in m[r] else next(iter(m[r]))
        url = m[r][fmt]["url"]
        dest = os.path.join(dl_dir, "%s_%s_%s.%s" % (aid, map_key, r, fmt))
        if not os.path.exists(dest):
            log("    get %s" % os.path.basename(dest))
            fetch(url, dest)
        urls.append(url)
        return dest

    px = RES_PX[res]
    orm_px = RES_PX[orm_res]
    diff = grab("Diffuse", res)
    nor = grab("nor_gl", res)
    if diff is None or nor is None:
        raise RuntimeError("%s has no Diffuse / nor_gl map" % aid)
    to_png(diff, os.path.join(tex_dir, "%s_albedo.png" % aid), px)
    used.append("textures/%s_albedo.png" % aid)
    to_png(nor, os.path.join(tex_dir, "%s_normal.png" % aid), px)
    used.append("textures/%s_normal.png" % aid)
    arm = grab("arm", orm_res)
    if arm is not None:
        to_png(arm, os.path.join(tex_dir, "%s_orm.png" % aid), orm_px)
    else:
        rough = grab("Rough", orm_res)
        ao = grab("AO", orm_res)
        metal = grab("Metal", orm_res)
        if rough is None:
            raise RuntimeError("%s has neither arm nor Rough" % aid)
        pack_orm(ao, rough, metal, os.path.join(tex_dir, "%s_orm.png" % aid), orm_px)
    used.append("textures/%s_orm.png" % aid)
    if entry.get("height"):
        disp = grab("Displacement", orm_res)
        if disp is not None:
            to_png(disp, os.path.join(tex_dir, "%s_height.png" % aid), orm_px, "L")
            used.append("textures/%s_height.png" % aid)
    dims = info.get("dimensions") or [1000, 1000]
    tile_m = round(float(dims[0]) / 1000.0, 3)
    name = info.get("name", aid)
    authors = ph_authors(info)
    write_text(os.path.join(out_dir, "SOURCE.txt"), source_txt(
        name, authors, "https://polyhaven.com/a/%s" % aid, urls,
        '"%s" by %s (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed.' % (name, authors),
        "PNG texture set at %s (albedo, normal OpenGL +Y, ORM at %s%s)" % (res, orm_res, ", height" if entry.get("height") else ""),
        used, {"Tile size": "%.2f x %.2f m" % (float(dims[0]) / 1000.0, float(dims[1]) / 1000.0),
               "Poly Haven id": aid, "Library key": entry.get("key", "")}))
    return {"tile_m": tile_m, "title": name}


def ph_hdri(entry: dict, out_dir: str, dl_dir: str) -> dict:
    aid = entry["id"]
    res = entry.get("res", "2k")
    info = ph_info(aid)
    files = fetch_json("%s/files/%s" % (PH_API, aid))
    h = files["hdri"]
    r = res if res in h else next(iter(h))
    url = h[r]["hdr"]["url"]
    dest = os.path.join(dl_dir, "%s_%s.hdr" % (aid, r))
    if not os.path.exists(dest):
        log("    get %s" % os.path.basename(dest))
        fetch(url, dest)
    os.makedirs(out_dir, exist_ok=True)
    final = os.path.join(out_dir, "%s_%s.hdr" % (aid, r))
    shutil.copyfile(dest, final)
    name = info.get("name", aid)
    authors = ph_authors(info)
    write_text(os.path.join(out_dir, "SOURCE.txt"), source_txt(
        name, authors, "https://polyhaven.com/a/%s" % aid, [url],
        '"%s" by %s (Poly Haven), CC0.' % (name, authors),
        "Radiance HDR equirectangular panorama at %s (skybox / lighting reference)" % r,
        ["%s_%s.hdr" % (aid, r)], {"Poly Haven id": aid}))
    return {"title": name}


def ph_model(entry: dict, out_dir: str, dl_dir: str) -> dict:
    aid = entry["id"]
    res = entry.get("res", "1k")
    tex_px = int(entry.get("tex_px", 1024))
    info = ph_info(aid)
    files = fetch_json("%s/files/%s" % (PH_API, aid))
    g = files.get("gltf")
    if not g:
        raise RuntimeError("%s has no glTF" % aid)
    r = res if res in g else next(iter(g))
    main = g[r]
    if "url" not in main and "gltf" in main:   # the API nests the .gltf entry under its own format key
        main = main["gltf"]
    gltf_path = os.path.join(dl_dir, "%s_%s.gltf" % (aid, r))
    if not os.path.exists(gltf_path):
        log("    get %s" % os.path.basename(gltf_path))
        fetch(main["url"], gltf_path)
    urls = [main["url"]]
    includes = {}
    for rel, meta in (main.get("include") or {}).items():
        if not safe_member(rel):
            continue
        dest = os.path.join(dl_dir, rel.replace("/", "__"))
        if not os.path.exists(dest):
            log("    get %s" % rel)
            fetch(meta["url"], dest)
        urls.append(meta["url"])
        includes[rel] = dest
    with open(gltf_path, "r", encoding="utf-8") as f:
        doc = json.load(f)
    # textures -> PNG next to the GLB
    tex_dir = os.path.join(out_dir, "textures")
    os.makedirs(tex_dir, exist_ok=True)
    used = ["model.glb"]
    for img in doc.get("images", []):
        uri = img.get("uri", "")
        src = includes.get(uri)
        if src is None:
            raise RuntimeError("%s: image %s not in the include list" % (aid, uri))
        base = os.path.splitext(os.path.basename(uri))[0]
        base = re.sub(r"_%s$" % r, "", base)
        png = "%s.png" % base
        to_png(src, os.path.join(tex_dir, png), tex_px, "RGBA" if "alpha" in base.lower() else "RGB")
        img["uri"] = "textures/%s" % png
        img["mimeType"] = "image/png"
        used.append("textures/%s" % png)
    # a single external buffer -> the GLB's BIN chunk
    buffers = doc.get("buffers", [])
    if len(buffers) != 1 or "uri" not in buffers[0]:
        raise RuntimeError("%s: expected one external buffer" % aid)
    bin_src = includes.get(buffers[0]["uri"])
    if bin_src is None:
        raise RuntimeError("%s: buffer %s not downloaded" % (aid, buffers[0]["uri"]))
    with open(bin_src, "rb") as f:
        bin_data = f.read()
    del buffers[0]["uri"]
    buffers[0]["byteLength"] = len(bin_data)
    doc.setdefault("asset", {})["generator"] = "Poly Haven glTF, packed to GLB by tools/fetch_cc0_materials.py"
    write_glb(os.path.join(out_dir, "model.glb"), doc, bin_data)
    name = info.get("name", aid)
    authors = ph_authors(info)
    write_text(os.path.join(out_dir, "SOURCE.txt"), source_txt(
        name, authors, "https://polyhaven.com/a/%s" % aid, urls,
        '"%s" by %s (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized.' % (name, authors),
        "GLB (metres, +Y up) with external PNG textures at <= %d px" % tex_px,
        used, {"Poly Haven id": aid}))
    return {"title": name}


def write_glb(path: str, doc: dict, bin_data: bytes) -> None:
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    bd = bytes(bin_data)
    while len(bd) % 4:
        bd += b"\0"
    total = 12 + 8 + len(js) + 8 + len(bd)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(bd), 0x004E4942))
        f.write(bd)


# ----------------------------------------------------------------------------------------------- ambientCG

ACG_API = "https://ambientcg.com/api/v2/full_json?id=%s&include=downloadData,tagData,dimensionsData,displayData"


def acg_texture(entry: dict, out_dir: str, dl_dir: str) -> dict:
    aid = entry["id"]
    res = entry.get("res", "2k").upper()
    orm_res = entry.get("orm_res", "1k")
    meta = fetch_json(ACG_API % aid)
    assets = meta.get("foundAssets") or []
    if not assets:
        raise RuntimeError("ambientCG has no asset %s" % aid)
    a = assets[0]
    dls = (a.get("downloadFolders", {}).get("default", {}).get("downloadFiletypeCategories", {}).get("zip", {}).get("downloads", []))
    want = "%s-JPG" % res
    pick = next((d for d in dls if d.get("attribute") == want), None)
    if pick is None:
        raise RuntimeError("%s has no %s zip" % (aid, want))
    url = pick["downloadLink"]
    zpath = os.path.join(dl_dir, "%s_%s.zip" % (aid, want))
    if not os.path.exists(zpath):
        log("    get %s" % os.path.basename(zpath))
        fetch(url, zpath)
    maps = {}
    with zipfile.ZipFile(zpath) as z:
        for m in z.infolist():
            n = m.filename
            if not safe_member(n) or m.is_dir():
                continue
            low = n.lower()
            if not low.endswith((".jpg", ".jpeg", ".png")):
                continue
            for key in ("Color", "NormalGL", "Roughness", "AmbientOcclusion", "Displacement", "Metalness"):
                if ("_%s." % key.lower()) in low:
                    dest = os.path.join(dl_dir, "%s_%s%s" % (aid, key, os.path.splitext(n)[1].lower()))
                    with z.open(m) as src, open(dest, "wb") as out:
                        shutil.copyfileobj(src, out)
                    maps[key] = dest
    if "Color" not in maps or "NormalGL" not in maps or "Roughness" not in maps:
        raise RuntimeError("%s: zip lacks Color / NormalGL / Roughness (%s)" % (aid, sorted(maps)))
    px = RES_PX[entry.get("res", "2k")]
    orm_px = RES_PX[orm_res]
    tex_dir = os.path.join(out_dir, "textures")
    used = []
    to_png(maps["Color"], os.path.join(tex_dir, "%s_albedo.png" % aid), px)
    used.append("textures/%s_albedo.png" % aid)
    to_png(maps["NormalGL"], os.path.join(tex_dir, "%s_normal.png" % aid), px)
    used.append("textures/%s_normal.png" % aid)
    pack_orm(maps.get("AmbientOcclusion"), maps["Roughness"], maps.get("Metalness"), os.path.join(tex_dir, "%s_orm.png" % aid), orm_px)
    used.append("textures/%s_orm.png" % aid)
    if entry.get("height") and "Displacement" in maps:
        to_png(maps["Displacement"], os.path.join(tex_dir, "%s_height.png" % aid), orm_px, "L")
        used.append("textures/%s_height.png" % aid)
    dim = a.get("dimensionX")
    tile_m = None
    try:
        if dim:
            tile_m = round(float(dim) / 100.0, 3)   # ambientCG reports centimetres
    except (TypeError, ValueError):
        tile_m = None
    name = a.get("displayName", aid)
    write_text(os.path.join(out_dir, "SOURCE.txt"), source_txt(
        name, "ambientCG.com (Lennart Demes)", "https://ambientcg.com/a/%s" % aid, [url],
        '"%s" from ambientCG.com, CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed.' % name,
        "PNG texture set at %s (albedo, normal OpenGL +Y, ORM at %s%s)" % (entry.get("res", "2k"), orm_res, ", height" if "Displacement" in maps and entry.get("height") else ""),
        used, {"Tile size": ("%.2f m" % tile_m) if tile_m else "see the asset page", "ambientCG id": aid, "Library key": entry.get("key", "")}))
    return {"tile_m": tile_m, "title": name}


# ----------------------------------------------------------------------------------------------- Kenney

def kenney_pack(entry: dict, out_dir: str, dl_dir: str) -> dict:
    aid = entry["id"]
    url = entry["url"]
    zpath = os.path.join(dl_dir, "%s.zip" % aid)
    if not os.path.exists(zpath):
        log("    get %s" % os.path.basename(zpath))
        fetch(url, zpath)
    members = entry.get("members", {})
    used = []
    lic = None
    os.makedirs(out_dir, exist_ok=True)
    with zipfile.ZipFile(zpath) as z:
        names = set(z.namelist())
        for src, dst in members.items():
            if src not in names or not safe_member(src) or not dst.lower().endswith(".glb"):
                log("    ! member missing or refused: %s" % src)
                continue
            with z.open(src) as s, open(os.path.join(out_dir, os.path.basename(dst)), "wb") as o:
                shutil.copyfileobj(s, o)
            used.append(os.path.basename(dst))
        for src, dst in (entry.get("extra") or {}).items():   # textures the GLBs reference by relative path
            if src in names and safe_member(src) and safe_member(dst) and dst.lower().endswith((".png", ".jpg")):
                dest = os.path.join(out_dir, *dst.split("/"))
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                with z.open(src) as s_, open(dest, "wb") as o:
                    shutil.copyfileobj(s_, o)
                used.append(dst)
        for n in names:
            if os.path.basename(n).lower() in ("license.txt", "licence.txt") and safe_member(n):
                with z.open(n) as s:
                    lic = s.read().decode("utf-8", errors="replace")
                break
    if lic:
        write_text(os.path.join(out_dir, "LICENSE.txt"), lic)
    write_text(os.path.join(out_dir, "SOURCE.txt"), source_txt(
        "Kenney %s" % aid.replace("-", " ").title(), "Kenney (kenney.nl)", entry.get("page", "https://kenney.nl"), [url],
        'Assets from "%s" by Kenney (kenney.nl), CC0.' % aid.replace("-", " ").title(),
        "GLB (embedded palette texture), low-poly", used, {"Pack members": ", ".join(members.keys())}))
    return {"title": "Kenney %s" % aid, "keep_license": bool(lic)}


# ----------------------------------------------------------------------------------------------- main

def main(argv: list) -> int:
    only, force, dry, keep = set(), False, False, False
    for a in argv:
        if a.startswith("--only="):
            only = set(a[7:].split(","))
        elif a == "--force":
            force = True
        elif a == "--dry-run":
            dry = True
        elif a == "--keep-downloads":
            keep = True
    with open(LIST_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    entries = data.get("assets", [])
    totals, failures, changed = {}, [], False
    cc0 = None
    for e in entries:
        aid, source, kind = e["id"], e["source"], e.get("kind", "texture")
        if only and aid not in only:
            continue
        out_dir = os.path.join(OUT_ROOT, source, kebab(aid))
        if os.path.exists(os.path.join(out_dir, "SOURCE.txt")) and not force:
            log("= %s/%s (have it)" % (source, kebab(aid)))
            totals[source] = totals.get(source, 0) + folder_size(out_dir)
            continue
        log("> %s/%s [%s %s]" % (source, kebab(aid), kind, e.get("res", "")))
        if dry:
            continue
        dl_dir = os.path.join(DL_ROOT, "%s_%s" % (source, kebab(aid)))
        os.makedirs(dl_dir, exist_ok=True)
        try:
            if source == "polyhaven" and kind == "texture":
                r = ph_texture(e, out_dir, dl_dir)
            elif source == "polyhaven" and kind == "hdri":
                r = ph_hdri(e, out_dir, dl_dir)
            elif source == "polyhaven" and kind == "model":
                r = ph_model(e, out_dir, dl_dir)
            elif source == "ambientcg":
                r = acg_texture(e, out_dir, dl_dir)
            elif source == "kenney":
                r = kenney_pack(e, out_dir, dl_dir)
            else:
                raise RuntimeError("unknown source/kind %s/%s" % (source, kind))
            if not r.get("keep_license"):
                if cc0 is None:
                    cc0 = cc0_text()
                write_text(os.path.join(out_dir, "LICENSE.txt"), cc0)
            if r.get("tile_m") and not e.get("tile_m"):
                e["tile_m"] = r["tile_m"]
                changed = True
            size = folder_size(out_dir)
            totals[source] = totals.get(source, 0) + size
            log("  ok %.1f MB" % (size / 1e6))
            if not keep:
                shutil.rmtree(dl_dir, ignore_errors=True)
        except Exception as ex:  # noqa: BLE001
            log("  ! FAILED %s: %s" % (aid, ex))
            failures.append(aid)
            shutil.rmtree(out_dir, ignore_errors=True)
    if changed:
        with open(LIST_PATH, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        log("updated %s with tile sizes" % os.path.relpath(LIST_PATH, ROOT))
    log("--- sizes per source")
    for s, b in sorted(totals.items()):
        log("  %-10s %7.1f MB" % (s, b / 1e6))
    log("  %-10s %7.1f MB" % ("total", sum(totals.values()) / 1e6))
    if failures:
        log("FAILED: %s" % ", ".join(failures))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
