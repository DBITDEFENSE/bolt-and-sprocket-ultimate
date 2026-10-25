#!/usr/bin/env python3
"""Gun intake (UPDATE_05A sections 1-3, T-087): converts the downloaded gun packs into assets/third_party/<source>/<id>/
(model.glb + textures/*.png + LICENSE.txt + SOURCE.txt) and writes data/gravelight/weapons/models.json.

    python -I tools/intake_guns.py [--only id,id] [--force] [--no-convert] [--user-supplied DIR] [--previews DIR]

The table below is the one place that knows which pack file is which gun, which vertex groups become which named
parts, and the real length of each gun. Conversion runs Blender headless through tools_src/blender/convert_to_glb.py
(one process per asset); each run's REPORT_JSON is cached in tools_src/_downloads/reports/<id>.json so models.json
can be rewritten with --no-convert. PNGs are re-compressed with Pillow (lossless). Nothing here touches
assets/user_supplied/ except to read it.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")
CONVERTER = os.path.join(ROOT, "tools_src", "blender", "convert_to_glb.py")
DOWNLOADS = os.path.join(ROOT, "tools_src", "_downloads")
REPORTS = os.path.join(DOWNLOADS, "reports")
THIRD = os.path.join(ROOT, "assets", "third_party")
MODELS_JSON = os.path.join(ROOT, "data", "gravelight", "weapons", "models.json")
WEAPONS_JSON = os.path.join(ROOT, "data", "gravelight", "weapons.json")
CC_BY_TXT = os.path.join(DOWNLOADS, "cc-by-4.0.txt")
TODAY = "2026-10-25"

OGA_WW2 = os.path.join(DOWNLOADS, "oga_ww2", "x", "Ultimate Low Poly Guns World War 2", "Guns", "World War 2")
OGA_MAIN = os.path.join(DOWNLOADS, "oga_main", "x")
OGA_URL = "https://opengameart.org/content/ultimate-low-poly-guns"
OGA_ZIP_WW2 = "https://opengameart.org/sites/default/files/ultimate_low_poly_guns_world_war_2.zip"
OGA_ZIP_MAIN = "https://opengameart.org/sites/default/files/ultimate_low_poly_guns.zip"
OGA_AUTHOR = "TastyTony (gun models); Pichuliru (pack, palette, rigs)"
OGA_AUTHOR_URLS = "https://sketchfab.com/TastyTony ; https://opengameart.org/users/pichuliru"
OGA_CREDIT = "Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0)"
CC_BY = "CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)"
SKETCHFAB_FORMAT = ("GLB (Sketchfab auto-conversion, the larger 'model.glb' download) re-exported with Blender 5.1 "
                    "(tools_src/blender/convert_to_glb.py): transforms applied, parts kept as named nodes, textures "
                    "re-encoded as PNG and capped at 2K (smaller parts 1K/512 by texel density), black emissive maps dropped")

# Our part names (what WeaponHolder animates): Mag, Bolt, Slide, Pump, Cover, Barrels, Crank, plus Body, Trigger,
# Hammer, Cylinder, Clip, Shells, Stock and descriptive names for Sketchfab pieces.


def oga(asset_id, title, blend_rel, main=False, parts_map=None, game=None, real_len=None, notes="", **kw):
    base = OGA_MAIN if main else OGA_WW2
    return {
        "id": asset_id, "source": "opengameart", "input": os.path.join(base, blend_rel),
        "title": "Ultimate Low Poly Guns: " + title + (" (main set)" if main else " (World War 2 set)"),
        "author": OGA_AUTHOR, "author_urls": OGA_AUTHOR_URLS, "url": OGA_URL,
        "file": (OGA_ZIP_MAIN if main else OGA_ZIP_WW2) + " (" + blend_rel.replace(os.sep, "/") + ")",
        "license": CC_BY, "credit": OGA_CREDIT,
        "format": ("Blender .blend (one rigged mesh, one palette material, 8x8 PichuliruPalette.png) converted with "
                   "Blender 5.1 (tools_src/blender/convert_to_glb.py): the armature dropped, the mesh split by vertex "
                   "group into named parts, the palette exported as a nearest-filtered PNG"),
        "downloaded": TODAY + " by Devin Blair (zip in assets/user_supplied/packs) and by Claude (main set zip); converted " + TODAY + " by Claude (T-087)",
        "args": ["--split-vgroups", "--map", parts_map or "body=Body"],
        "game": game or [], "real_len": real_len, "notes": notes, **kw}


def sketchfab(asset_id, folder, title, author, url, game, real_len, args, notes="", parts=None, **kw):
    return {
        "id": asset_id, "source": "sketchfab", "input": ("user_supplied", "weapons", folder, "model.glb"),
        "title": title, "author": author, "author_urls": "https://sketchfab.com/" + author.split("@")[1].rstrip(")"), "url": url, "license": CC_BY,
        "credit": '"%s" by %s (%s), licensed under CC-BY 4.0. Modified.' % (title, author.split(" (")[0], url),
        "format": SKETCHFAB_FORMAT,
        "downloaded": TODAY + " by Devin Blair (Sketchfab); converted " + TODAY + " by Claude (T-087)",
        "args": ["--drop-black-emissive", "--auto-tex"] + args,
        "game": game, "real_len": real_len, "notes": notes, "parts": parts or {}, **kw}


MAG_PARTS = {"mag": "Mag", "bolt": "Bolt", "body": "Body", "trigger": "Trigger"}

TABLE = [
    # --- Devin's Sketchfab hero models (priority over the OGA baseline) ---
    sketchfab("thompson-artem-goyko", "sketchfab-thompson-artem-goyko", "Thompson submachine gun",
              "Artem Goyko (@Artem.Goyko)", "https://sketchfab.com/3d-models/thompson-submachine-gun-5fe11dfebf734b4aa49c43545397abd1",
              ["thompson"], 0.86,
              ["--map", "Plane.001=Stock,Plane=Grip,Plane.003=Foregrip,Cylinder=Barrel,Cylinder.003_Cylinder.004=Mag,"
                        "Cylinder.002_Cylinder.003=Bolt,Plane.005=RearSight,Plane.007=Receiver,Plane.006=ReceiverTop,"
                        "Plane.004=TriggerGroup,Cube=Rib,Cylinder.006_Cylinder.007=Frame"],
              notes="A 1928-pattern Thompson: finned barrel, Cutts compensator, vertical foregrip and a 50-round L drum "
                    "(the drum is the Mag part; the game's M1A1 stick mag is a phase-2 choice: hide the drum and build a stick, or keep the drum look). "
                    "Top-mounted bolt knob is the Bolt part. 12 materials, 1K textures.",
              parts={"mag": "Mag", "bolt": "Bolt", "body": "Receiver", "stock": "Stock", "grip": "Grip", "foregrip": "Foregrip", "barrel": "Barrel"}),
    sketchfab("m1-garand-sky-hunter", "sketchfab-m1-garand-sky-hunter", "M1 Garand ( US Rifle, Caliber .30, M1)",
              "Sky_Hunter (@Sky_Hunter)", "https://sketchfab.com/3d-models/m1-garand-us-rifle-caliber-30-m1-1be4bb0f8c05423abdccb50b779de6e6",
              ["m1_garand"], 1.10,
              ["--map", "Gun=Body,Bullet_pack=Clip"],
              notes="One gun mesh (no separate bolt / op rod) plus a loose en-bloc clip with eight rounds floating above the "
                    "receiver (the Clip part; phase 2 parents it to the reload hand). 2K textures on the gun, 512 on the clip.",
              parts={"body": "Body", "clip": "Clip"}),
    sketchfab("kar98k-dsamuta", "sketchfab-kar98k-dsamuta", "Kar98k Free Model",
              "Danya (@dsamuta)", "https://sketchfab.com/3d-models/kar98k-free-model-e88c90c8e203401fa28e8f4ef03e657f",
              ["kar98k"], 1.11,
              ["--map", "a_low=Barrel,b_low=Stock,c_low=Bolt,d_low=Receiver,e_low=RearSight", "--drop", "p_low", "--drop", "f_low"],
              notes="Five textured parts; the bolt (with its handle) is its own mesh. A stray untextured cartridge that floated "
                    "above the action (p_low/f_low) was dropped. 2K textures on the stock, barrel and receiver, 1K bolt, 512 rear sight.",
              parts={"bolt": "Bolt", "body": "Receiver", "stock": "Stock", "barrel": "Barrel"}),
    # --- OpenGameArt baseline (TastyTony / Pichuliru), one folder per gun ---
    oga("tt-m1911", "M1911", os.path.join("Handguns", "M1911.blend"),
        parts_map="body=Body,slide=Slide,barrel=Body,mag=Mag,hammer=Hammer,release=Body,safety=Body,trigger=Trigger",
        game=["m1911"], real_len=0.216, parts={"mag": "Mag", "slide": "Slide", "hammer": "Hammer", "body": "Body", "trigger": "Trigger"}),
    oga("tt-walther-p38", "Walther P38", os.path.join("Handguns", "P38.blend"),
        parts_map="body=Body,slide=Slide,barrel=Body,mag=Mag,bullet=Mag,hammer=Hammer,trigger=Trigger,safety=Slide,slide release=Body,magrelease=Body",
        game=["walther_p38"], real_len=0.216, parts={"mag": "Mag", "slide": "Slide", "hammer": "Hammer", "body": "Body", "trigger": "Trigger"}),
    oga("tt-webley-mkiv", "Webley MkIV", os.path.join("Handguns", "Webley MKIV.blend"),
        parts_map="body=Body,barrel=Barrels,cylinder=Cylinder,ejector=Cylinder,b1=Cylinder,b2=Cylinder,b3=Cylinder,b4=Cylinder,b5=Cylinder,b6=Cylinder,cylinderelease=Body,hammer=Hammer,trigger=Trigger",
        game=["webley"], real_len=0.286,
        notes="The pack's Webley is the .38 Mk IV; the game's is the .455 Mk VI (same top-break family, the Mk VI has a longer barrel and squared grip). "
              "Barrels = the tilting barrel assembly, Cylinder = cylinder + rounds + ejector star (parent it under Barrels for the break).",
        parts={"barrels": "Barrels", "cylinder": "Cylinder", "hammer": "Hammer", "body": "Body", "trigger": "Trigger"}),
    oga("tt-kar98k", "Kar 98K", os.path.join("Rifles", "Kar 98K.blend"),
        parts_map="body=Body,bolt=Bolt,bolthandle=Bolt,firingpin=Bolt,trigger=Trigger",
        game=["kar98k"], real_len=1.11, alt_for=["kar98k"], parts={"bolt": "Bolt", "body": "Body", "trigger": "Trigger"}),
    oga("tt-m1-garand", "M1 Garand", os.path.join("Rifles", "M1 Garand.blend"),
        parts_map="body=Body,bolt=Bolt,charginghandle=Bolt,clip=Clip,bullets=Clip,bullet=Clip,follower=Body,safety=Body",
        game=["m1_garand"], real_len=1.10, alt_for=["m1_garand"], parts={"bolt": "Bolt", "clip": "Clip", "body": "Body"}),
    oga("tt-gewehr-43", "Gewehr 43", os.path.join("Rifles", "Gewehr 43.blend"),
        parts_map="body=Body,bolt=Bolt,mag=Mag,trigger=Trigger", game=["gewehr43"], real_len=1.13, parts=MAG_PARTS),
    oga("tt-m1-carbine", "M1 Carbine", os.path.join("Rifles", "M1 Carbine.blend"),
        parts_map="body=Body,mag=Mag,bullet=Mag,bolt=Bolt,boltrotateybit=Bolt,charginghandle=Bolt",
        game=["m1_carbine"], real_len=0.90, parts={"mag": "Mag", "bolt": "Bolt", "body": "Body"}),
    oga("tt-mp40", "MP 40", os.path.join("SMGs", "MP 40.blend"),
        parts_map="body=Body,mag=Mag,bullets=Mag,bullet=Mag,bolthead+rotate=Bolt,boltsegment2=Bolt,stock=Stock,stockend=Stock",
        game=["mp40"], real_len=0.83, notes="Folding stock is its own part (Stock), modelled extended.",
        parts={"mag": "Mag", "bolt": "Bolt", "body": "Body", "stock": "Stock"}),
    oga("tt-thompson-m1a1", "M1A1 Thompson", os.path.join("SMGs", "M1A1.blend"),
        parts_map="body=Body,bolt=Bolt,mag=Mag,bullets=Mag,bullet=Mag,magrelease=Body,safety=Body,selector=Body",
        game=["thompson"], real_len=0.81, alt_for=["thompson"], parts={"mag": "Mag", "bolt": "Bolt", "body": "Body"}),
    oga("tt-stg44", "STG 44", os.path.join("ARs", "STG 44.blend"),
        parts_map="body=Body,bolt=Bolt,bolthandle=Bolt,mag=Mag,bullets=Mag,bullet=Mag,safety=Body,selector=Body,dustcover=Cover",
        game=["stg44"], real_len=0.94, parts={"mag": "Mag", "bolt": "Bolt", "cover": "Cover", "body": "Body"}),
    oga("tt-m1897-trench-gun", "M1897 (trench gun)", os.path.join("Shotguns", "M1897.blend"),
        parts_map="body=Body,bolt=Pump,carrier=Body,hammer=Hammer,trigger=Trigger",
        game=["trench_gun"], real_len=1.0, notes="The pack's 'bolt' group is the whole action slide (forend + bolt), exported as Pump.",
        parts={"pump": "Pump", "hammer": "Hammer", "body": "Body"}),
    oga("tt-bar-m1918", "BAR", os.path.join("LMGs", "BAR.blend"),
        parts_map="body=Body,mag=Mag,bullet=Mag,bullets=Mag,charginghandle=Bolt,bolt1=Bolt,bolt2=Bolt,ch_unlock=Bolt,selector=Body,battlesight=Body",
        game=["bar"], real_len=1.21, parts={"mag": "Mag", "bolt": "Bolt", "body": "Body"}),
    oga("tt-ppsh41", "PPSH 41", os.path.join("SMGs", "PPSH 41.blend"),
        parts_map="body=Body,bolt=Bolt,mag=Mag,trigger=Trigger", game=["ppsh41"], real_len=0.84,
        notes="71-round drum as the Mag part.", parts=MAG_PARTS),
    oga("tt-mg42", "MG 42", os.path.join("LMGs", "MG 42.blend"),
        parts_map="body=Body,MAG=Mag,b1=Mag,b2=Mag,b3=Mag,b4=Mag,b5=Mag,magcatch=Body,cover=Cover,covercatch=Cover,charginghandle=Bolt,charginghandlemove=Bolt,chargerelease=Body",
        game=["mg42"], real_len=1.22, notes="Belt drum + the visible belt = Mag; the feed cover (with its catch) = Cover; charging handle = Bolt. No bipod in the model.",
        parts={"mag": "Mag", "cover": "Cover", "bolt": "Bolt", "body": "Body"}),
    oga("tt-springfield-m1903", "Springfield M1903", os.path.join("Rifles", "Springfield M1903.blend"),
        parts_map="body=Body,bolt=Bolt,firingpin=Bolt,safety=Bolt,trigger=Trigger", game=["springfield"], real_len=1.10,
        parts={"bolt": "Bolt", "body": "Body", "trigger": "Trigger"}),
    oga("tt-double-barrel", "Double Barrel", os.path.join("Shotguns", "Double Barrel.blend"), main=True,
        parts_map="body=Body,breakaction=Barrels,breakrelease=Body,trigger=Trigger,trigger2=Trigger,safety=Body,shell=Shells,shell.001=Shells",
        game=["sawed_off"], real_len=1.13,
        notes="A full-length side-by-side (1.13 m). The game's Sawed-Off is this gun with the barrels cut and the stock shortened: "
              "Barrels is a separate part, so phase 2 can clip it (the mesh's barrel geometry is a straight extrusion) or scale the long axis.",
        parts={"barrels": "Barrels", "shells": "Shells", "body": "Body", "trigger": "Trigger"}),
    oga("pichuliru-cartridges", "Cartridges", os.path.join("Cartridges", "Cartridges.blend"), main=True,
        parts_map="", game=[], real_len=None, no_split=True,
        notes="15 cartridges as named nodes (12_Gauge, 45_ACP, 9x19mm, 7_62x51mm, 7_62x54mmR, 50_BMG, 44_Magnum, 9x18mm, ...), "
              "metres, each standing on +Y at its own offset. Casings for the shell-ejection VFX (section 6).",
        parts={}),
]

# weapon id -> (fallback asset id, casing node); every conventional id in weapons.json must appear here or in GREYBOX
PRIMARY = {
    "m1911": "opengameart/tt-m1911", "walther_p38": "opengameart/tt-walther-p38", "webley": "opengameart/tt-webley-mkiv",
    "kar98k": "sketchfab/kar98k-dsamuta", "m1_garand": "sketchfab/m1-garand-sky-hunter", "gewehr43": "opengameart/tt-gewehr-43",
    "m1_carbine": "opengameart/tt-m1-carbine", "mp40": "opengameart/tt-mp40", "thompson": "sketchfab/thompson-artem-goyko",
    "stg44": "opengameart/tt-stg44", "trench_gun": "opengameart/tt-m1897-trench-gun", "bar": "opengameart/tt-bar-m1918",
    "ppsh41": "opengameart/tt-ppsh41", "mg42": "opengameart/tt-mg42", "springfield": "opengameart/tt-springfield-m1903",
    "sawed_off": "opengameart/tt-double-barrel",
}
GREYBOX = {
    "luger_p08": "no Luger in either OGA set; FREE_ASSET_LIST pick: 'P08 Luger Standard' by I_Live (Sketchfab, CC-BY)",
    "m1919": "not in the packs; FREE_ASSET_LIST pick: 'Browning M1919' by MelvinEbbuts (Sketchfab, CC-BY; skip any '(Enlisted)' rip)",
    "type100": "no free match found (FREE_ASSET_LIST); keeps the procedural model",
    "ptrs41": "not in the packs; FREE_ASSET_LIST pick: 'PTRS-41 Modified' by Naudaff3D (162k faces, needs decimation)",
    "panzerschreck": "not in the packs; FREE_ASSET_LIST pick: 'Panzerschreck' by Tactical_Beard (Sketchfab, CC-BY)",
    "flamethrower": "no free match found (FREE_ASSET_LIST); keeps the procedural model",
}
WONDER = ["ashlight", "totenglocke", "elmsfeuer"]
# casing stand-ins from Pichuliru's modern cartridge set (nearest shape; nothing in the set is the exact WW2 round)
CASINGS = {
    "m1911": "45_ACP", "thompson": "45_ACP", "walther_p38": "9x19mm", "luger_p08": "9x19mm", "mp40": "9x19mm", "type100": "9x19mm",
    "ppsh41": "9x19mm", "webley": "44_Magnum", "kar98k": "7_62x54mmR", "gewehr43": "7_62x54mmR", "mg42": "7_62x54mmR", "stg44": "7_62x39mm",
    "m1_garand": "7_62x51mm", "bar": "7_62x51mm", "m1919": "7_62x51mm", "springfield": "7_62x51mm", "m1_carbine": "7_62x39mm",
    "trench_gun": "12_Gauge", "sawed_off": "12_Gauge", "ptrs41": "50_BMG",
}


def run_blender(entry, out_glb, preview):
    args = [BLENDER, "-b", "--python-exit-code", "1", "-P", CONVERTER, "--", entry["input"], out_glb] + entry["args"]
    if preview:
        args += ["--preview", preview]
    p = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    rep = None
    for line in p.stdout.splitlines():
        if line.startswith("REPORT_JSON "):
            rep = json.loads(line[len("REPORT_JSON "):])
    if p.returncode != 0 or rep is None:
        sys.stderr.write(p.stdout[-4000:] + "\n" + p.stderr[-4000:] + "\n")
        raise SystemExit("blender failed for %s" % entry["id"])
    for line in p.stdout.splitlines():
        if line.startswith("WARN"):
            print("  ", line)
    return rep


def optimize_pngs(folder):
    try:
        from PIL import Image
    except ImportError:
        print("   (Pillow missing: PNGs left as Blender wrote them)")
        return 0
    saved = 0
    for name in sorted(os.listdir(folder)):
        if not name.lower().endswith(".png"):
            continue
        path = os.path.join(folder, name)
        before = os.path.getsize(path)
        with Image.open(path) as im:
            im.load()
            mode = im.mode
            if mode == "RGBA" and im.getextrema()[3] == (255, 255):
                im = im.convert("RGB")   # a fully opaque alpha channel is dead weight
            im.save(path + ".tmp", "PNG", optimize=True, compress_level=9)
        os.replace(path + ".tmp", path)
        saved += before - os.path.getsize(path)
    return saved


def write_paperwork(entry, folder, rep):
    with open(CC_BY_TXT, "r", encoding="utf-8") as f:
        cc = f.read()
    with open(os.path.join(folder, "LICENSE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("Creative Commons Attribution 4.0 International (CC-BY 4.0)\n")
        f.write("Applies to every file in this folder. Attribution: see SOURCE.txt.\n")
        f.write("https://creativecommons.org/licenses/by/4.0/\n\n")
        f.write(cc)
    files = ["model.glb"] + ["textures/" + n for n in rep["texture_files"]]
    lines = [
        "Title: " + entry["title"],
        "Author: " + entry["author"],
        "Source: " + entry["url"],
    ]
    if entry.get("author_urls"):
        lines.append("Author URL: " + entry["author_urls"])
    if entry.get("file"):
        lines.append("File: " + entry["file"])
    lines += [
        "License: " + entry["license"],
        "Credit line: " + entry["credit"],
        "Format: " + entry["format"],
        "Downloaded: " + entry["downloaded"],
        "Files used: " + ", ".join(files),
        "Game use: " + (", ".join(entry["game"]) if entry["game"] else "extras (casings)") +
        (" (fallback / third-person LOD; the viewmodel uses the Sketchfab model)" if entry.get("alt_for") else ""),
    ]
    if entry.get("notes"):
        lines.append("Notes: " + entry["notes"])
    with open(os.path.join(folder, "SOURCE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def native_of(entry, rep):
    size = rep["size"]
    axis = {"X": 0, "Y": 1, "Z": 2}[rep["forward_guess"][1]]
    length = size[axis]
    real = entry.get("real_len")
    nat = {
        "forward": rep["forward_guess"], "up": "+Y", "origin": "bbox centre (the pack's own origin; not the grip)",
        "length_m": round(length, 4), "real_length_m": real,
        "scale": round(real / length, 4) if real else 1.0,
        "size": size, "bbox_min": rep["bbox_min"], "bbox_max": rep["bbox_max"], "tris": rep["tris"],
        "materials": sorted({m for o in rep["objects"] for m in o["materials"]}),
        "textures": len(rep["texture_files"]),
    }
    trig = [o for o in rep["objects"] if o["name"] == "Trigger"]
    if trig:
        a, b = trig[0]["bbox_min"], trig[0]["bbox_max"]
        nat["trigger_center"] = [round((a[k] + b[k]) * 0.5, 4) for k in range(3)]
    return nat


def build_models_json(entries, reports, weapons_ids):
    assets = {}
    for e in entries:
        rep = reports.get(e["id"])
        if rep is None:
            continue
        key = e["source"] + "/" + e["id"]
        assets[key] = {
            "glb": "res://assets/third_party/%s/%s/model.glb" % (e["source"], e["id"]),
            "title": e["title"], "author": e["author"].split(";")[0], "license": "CC-BY 4.0", "credit": e["credit"],
            "parts": e.get("parts", {}),
            "nodes": [o["name"] for o in rep["objects"]],
            "part_bounds": {o["name"]: [o["bbox_min"], o["bbox_max"]] for o in rep["objects"]},
            "part_tris": {o["name"]: o["tris"] for o in rep["objects"]},
            "native": native_of(e, rep),
            "notes": e.get("notes", ""),
        }
    weapons = {}
    greybox = []
    for wid in weapons_ids:
        if wid in WONDER:
            weapons[wid] = {"source": "ours", "asset": None, "glb": None, "parts": {}, "notes": "wonder weapon: modelled by us (UPDATE_05 section 2, tools_src/blender/wonder/)"}
            continue
        key = PRIMARY.get(wid)
        if key is None or key not in assets:
            greybox.append(wid)
            weapons[wid] = {"source": None, "asset": None, "glb": None, "parts": {}, "alt": [],
                            "notes": "greybox (procedural WeaponModels): " + GREYBOX.get(wid, "no model converted")}
            continue
        a = assets[key]
        alts = [e["source"] + "/" + e["id"] for e in entries if wid in e.get("alt_for", []) and (e["source"] + "/" + e["id"]) in assets]
        weapons[wid] = {"source": key.split("/")[0], "asset": key, "glb": a["glb"], "parts": a["parts"], "native": a["native"],
                        "alt": alts, "notes": a["notes"]}
    extras = {}
    cart_key = "opengameart/pichuliru-cartridges"
    if cart_key in assets:
        extras["cartridges"] = {"asset": cart_key, "glb": assets[cart_key]["glb"], "nodes": assets[cart_key]["nodes"],
                                "casing_for": {k: v for k, v in CASINGS.items() if v in assets[cart_key]["nodes"]},
                                "notes": "nearest-shape stand-ins from a modern cartridge set; the ejected casing is the case only (phase 2 cuts the bullet, or scales)"}
    extras["stick_grenade"] = {"source": None, "asset": None, "notes": "no model in the packs; FREE_ASSET_LIST pick: 'Stielhandgranate 24' by dsamuta (Sketchfab, CC-BY)"}
    extras["frag_grenade"] = {"source": None, "asset": None, "notes": "no model in the packs; FREE_ASSET_LIST pick: 'FREE Hand-Painted WW2 Grenade MK 2' (Unity Asset Store)"}
    doc = {
        "_doc": ("Weapon model intake (T-087). weapons: every id in weapons.json -> the GLB that replaces its procedural "
                 "WeaponModels build (source sketchfab > opengameart; null = keeps the greybox; 'ours' = wonder weapon). "
                 "parts: our animation part name -> node name inside the GLB (Mag/Bolt/Slide/Pump/Cover/Barrels/...). "
                 "native: the GLB as exported (glTF axes, +Y up): forward = the axis the muzzle points along, origin = the "
                 "pack's own (bbox centre), length_m along forward, scale = real_length_m / length_m to bring it to metres, "
                 "trigger_center when a Trigger part exists (grip reference). Our rig wants barrel along -Z, +Y up, origin at "
                 "the right-hand grip: for forward '+X' rotate +90 deg about Y, for '-X' -90, for '-Z' nothing, for '+Z' 180, "
                 "then scale, then translate the grip to the origin. assets: every converted folder with its parts, node "
                 "list, per-node bounds (glTF axes, native scale) and tri counts. extras: casings and grenades. "
                 "Regenerate with: python -I tools/intake_guns.py --no-convert"),
        "frame": {"rig_forward": "-Z", "rig_up": "+Y", "rig_origin": "right-hand grip point", "units": "m"},
        "weapons": weapons,
        "greybox": greybox,
        "assets": assets,
        "extras": extras,
    }
    return doc


WEAPON_MODELS_MD = os.path.join(ROOT, "docs", "WEAPON_MODELS.md")
# phase 2 (u05-guns) edits this when a pack's animations are retargeted; everything else is ours
ANIMS = {}
SPARE_WW2 = ["FG 42", "C96", "Hi-Power", "Nagant M1895", "Welrod", "Bren", "DP 28", "Mosin Nagant", "SVT 40", "M3 Grease", "Sten"]


def write_weapon_models_md(doc, weapons):
    L = []
    L.append("# Weapon models: source, licence, parts, scale (generated)")
    L.append("")
    L.append("Generated by `python -I tools/intake_guns.py` (T-087, UPDATE_05A section 3) from its intake table and the Blender conversion "
             "reports; the same data is `data/gravelight/weapons/models.json`. Do not edit the tables by hand: change the table in "
             "`tools/intake_guns.py` (or the `ANIMS` dict once phase 2 retargets pack animations) and re-run with `--no-convert`.")
    L.append("")
    L.append("**Frame.** Our rig (`WeaponModels`, `WeaponHolder`): barrel along -Z, +Y up, origin at the right-hand grip, metres. "
             "Every GLB below is as exported (glTF axes, +Y up, the pack's own origin = bounding-box centre): `forward` is the axis the "
             "muzzle points along, `scale` brings the model to its real length. Phase 2 (u05-guns) normalises: rotate about Y "
             "(+X -> +90 deg, -X -> -90 deg, -Z -> 0, +Z -> 180), scale, move the grip to the origin, then places Muzzle / SightPoint / "
             "FrontSight / LeftHand markers and runs `tools/ads_check.sh`.")
    L.append("")
    L.append("**Priority.** Devin's Sketchfab downloads are the hero viewmodels (Thompson, M1 Garand, Kar98k); the OpenGameArt "
             "\"Ultimate Low Poly Guns\" set (TastyTony / Pichuliru, CC-BY 4.0) is the baseline for every other gun and the "
             "fallback / third-person LOD for the three heroes (`alt`). Guns with no model keep the procedural greybox.")
    L.append("")
    L.append("| Weapon id | Name | Class | Source | Model | Author | Licence | Parts in the GLB | Native: forward, length, scale, tris | Animations |")
    L.append("|---|---|---|---|---|---|---|---|---|---|")
    for wid, w in doc["weapons"].items():
        wj = weapons.get(wid, {})
        name = wj.get("name", wid)
        cls = wj.get("class", "")
        if w["source"] == "ours":
            L.append("| `%s` | %s | %s | ours | modelled in phase 2 (`tools_src/blender/wonder/`) | GRAVELIGHT | ours | | | ours |" % (wid, name, cls))
            continue
        if w["source"] is None:
            L.append("| `%s` | %s | %s | **greybox** | procedural `WeaponModels` | ours | ours | | | ours |" % (wid, name, cls))
            continue
        a = doc["assets"][w["asset"]]
        n = w["native"]
        parts = ", ".join("%s=%s" % (k, v) for k, v in w["parts"].items())
        alt = (" (alt: " + ", ".join("`%s`" % x for x in w["alt"]) + ")") if w.get("alt") else ""
        L.append("| `%s` | %s | %s | %s | `%s`%s | %s | %s | %s | %s, %.3f m -> x%.3f, %d tris | %s |" % (
            wid, name, cls, w["source"], w["asset"], alt, a["author"].replace("|", "/"), a["license"], parts,
            n["forward"], n["length_m"], n["scale"], n["tris"], ANIMS.get(wid, "ours (phase 2)")))
    L.append("")
    L.append("Greybox (no model yet): " + ", ".join("`%s`" % g for g in doc["greybox"]) + ". Picks for Devin are in `models.json` "
             "(`weapons.<id>.notes`) and `FREE_ASSET_LIST.md`.")
    L.append("")
    L.append("## Every converted asset")
    L.append("")
    L.append("| Asset | Title | Nodes (tris) | Size | Textures | Notes |")
    L.append("|---|---|---|---|---|---|")
    for key, a in doc["assets"].items():
        nodes = ", ".join("%s (%d)" % (nm, a["part_tris"][nm]) for nm in a["nodes"])
        n = a["native"]
        L.append("| `%s` | %s | %s | %.3f x %.3f x %.3f m | %d | %s |" % (
            key, a["title"], nodes, n["size"][0], n["size"][1], n["size"][2], n["textures"], a["notes"].replace("|", "/")))
    L.append("")
    L.append("## Extras")
    L.append("")
    ex = doc["extras"]
    if "cartridges" in ex:
        L.append("- **Casings:** `%s` (%s): nodes %s. Stand-ins per weapon: %s." % (
            ex["cartridges"]["asset"], ex["cartridges"]["glb"], ", ".join("`%s`" % x for x in ex["cartridges"]["nodes"]),
            ", ".join("%s -> `%s`" % (k, v) for k, v in ex["cartridges"]["casing_for"].items())))
    for k in ("stick_grenade", "frag_grenade"):
        if k in ex:
            L.append("- **%s:** %s" % (k.replace("_", " "), ex[k]["notes"]))
    L.append("")
    L.append("## Still in the packs, not imported")
    L.append("")
    L.append("World War 2 set: " + ", ".join(SPARE_WW2) + " (one `.blend` each, same palette; import with `tools/intake_guns.py` when a weapon id needs one). "
             "Main set: 50 modern guns (AKs, M4, FAL, MP5, shotguns, DMRs...), none period-correct for GRAVELIGHT.")
    L.append("")
    L.append("## Conversion notes")
    L.append("")
    L.append("- OGA `.blend`: one mesh per gun under an armature whose bones (body, slide, bolt, mag, hammer, trigger...) are the "
             "vertex groups; `convert_to_glb.py --split-vgroups --map` turns the dominant group of each face into a separate named "
             "object (several groups can merge into one name), drops the armature, applies transforms and exports the 8x8 "
             "`PichuliruPalette.png` with nearest filtering (the glTF sampler keeps `magFilter` NEAREST). Rounds inside a magazine "
             "are merged into `Mag`; the en-bloc clip and its rounds into `Clip`; a revolver's rounds into `Cylinder`.")
    L.append("- Sketchfab GLB: Sketchfab normalises geometry to a [-1, 1] box and carries the scale on the root matrix; after the "
             "transform is applied the models are ~2 m long, so `scale` (real length / model length) is 0.43-0.56. Node names were "
             "meaningless (`Plane.003`, `c_low`); they were identified from Workbench previews (`morning/screenshots/u05/intake/`) and renamed. "
             "Textures: 4K maps capped at 2K, small parts 1K / 512 by texel density, black emissive maps dropped, everything re-encoded as PNG.")
    L.append("- Size: see `docs/ASSETS.md` (generated block) for per-folder sizes.")
    with open(WEAPON_MODELS_MD, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--no-convert", action="store_true")
    ap.add_argument("--user-supplied", default="")
    ap.add_argument("--previews", default="")
    a = ap.parse_args()
    user_supplied = a.user_supplied
    if not user_supplied:
        for cand in (os.path.join(ROOT, "assets", "user_supplied"), os.path.join(ROOT, "..", "..", "assets", "user_supplied")):
            if os.path.isdir(os.path.join(cand, "weapons")):
                user_supplied = cand
                break
    only = {s.strip() for s in a.only.split(",") if s.strip()}
    os.makedirs(REPORTS, exist_ok=True)
    # Godot must never scan the raw downloads (the .blend files make the headless import pass abort)
    with open(os.path.join(DOWNLOADS, ".gdignore"), "w") as f:
        f.write("")
    reports = {}
    with open(WEAPONS_JSON, "r", encoding="utf-8") as f:
        weapon_ids = list(json.load(f)["weapons"].keys())
    for e in TABLE:
        if isinstance(e["input"], tuple):
            e["input"] = os.path.join(user_supplied, *e["input"][1:])
        if e.get("no_split"):
            e["args"] = []
        folder = os.path.join(THIRD, e["source"], e["id"])
        rep_path = os.path.join(REPORTS, e["id"] + ".json")
        glb = os.path.join(folder, "model.glb")
        need = a.force or not (os.path.exists(glb) and os.path.exists(rep_path))
        if only and e["id"] not in only:
            need = False
        if need and not a.no_convert:
            if not os.path.exists(e["input"]):
                print("SKIP %s: input missing: %s" % (e["id"], e["input"]))
                continue
            print("convert", e["id"])
            os.makedirs(folder, exist_ok=True)
            preview = os.path.join(a.previews, e["id"] + ".png") if a.previews else None
            if preview:
                os.makedirs(a.previews, exist_ok=True)
            rep = run_blender(e, glb, preview)
            saved = optimize_pngs(os.path.join(folder, "textures"))
            rep["texture_bytes"] = sum(os.path.getsize(os.path.join(folder, "textures", n)) for n in rep["texture_files"])
            rep["png_optimize_saved"] = saved
            with open(rep_path, "w", encoding="utf-8") as f:
                json.dump(rep, f, indent=1)
            write_paperwork(e, folder, rep)
            print("   %d tris, %d parts, glb %.1f KB, textures %.1f MB, forward %s, size %s" % (
                rep["tris"], len(rep["objects"]), rep["glb_bytes"] / 1024.0, rep["texture_bytes"] / 1e6, rep["forward_guess"], rep["size"]))
        if os.path.exists(rep_path) and os.path.exists(glb):
            with open(rep_path, "r", encoding="utf-8") as f:
                reports[e["id"]] = json.load(f)
            if a.no_convert or not need:
                write_paperwork(e, folder, reports[e["id"]])
    doc = build_models_json(TABLE, reports, weapon_ids)
    os.makedirs(os.path.dirname(MODELS_JSON), exist_ok=True)
    with open(MODELS_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")
    print("models.json: %d weapons, %d assets, greybox: %s" % (len(doc["weapons"]), len(doc["assets"]), ", ".join(doc["greybox"])))
    with open(WEAPONS_JSON, "r", encoding="utf-8") as f:
        write_weapon_models_md(doc, json.load(f)["weapons"])
    total = 0
    for e in TABLE:
        folder = os.path.join(THIRD, e["source"], e["id"])
        if os.path.isdir(folder):
            sz = sum(os.path.getsize(os.path.join(dp, fn)) for dp, _, fns in os.walk(folder) for fn in fns)
            total += sz
            print("  %-45s %7.2f MB" % (e["source"] + "/" + e["id"], sz / 1e6))
    print("total %.1f MB" % (total / 1e6))


if __name__ == "__main__":
    main()
