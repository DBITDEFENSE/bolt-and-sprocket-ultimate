"""Registers the wonder-weapon models built by tools_src/blender/wonder/<id>.py (UPDATE_05 section 2, T-090).

    python -I tools/wonder_register.py

For every model with a build report (tools_src/blender/wonder/reports/<id>.json) and a GLB in assets/ours/wonder/<id>/:
  - writes the folder's paperwork (LICENSE.txt "Ours", SOURCE.txt in the intake format) and, for the three guns, an
    import_preset.txt naming the "weapon" import preset (mesh compression off: the sight markers must land exactly);
  - updates the wonder entries of data/gravelight/weapons/models.json (source "ours", glb, parts, native block in the
    game frame: forward -Z, scale 1, the grip at the origin) and extras.gramophone for the tactical;
  - rewrites the wonder rows of docs/WEAPON_MODELS.md (the rows tools/intake_guns.py writes for "ours").
Re-run after rebuilding a model. Nothing else in models.json is touched (its other entries come from intake_guns.py).
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORTS = os.path.join(ROOT, "tools_src", "blender", "wonder", "reports")
OURS = os.path.join(ROOT, "assets", "ours", "wonder")
MODELS = os.path.join(ROOT, "data", "gravelight", "weapons", "models.json")
WEAPONS_MD = os.path.join(ROOT, "docs", "WEAPON_MODELS.md")

# id -> (title, contract parts {models.json key: GLB node}, notes, is a gun)
TABLE = {
    "ashlight": ("Ashlight (Fasbender's resonance projector)", {"mag": "Mag", "needle": "Needle", "halo": "Halo", "body": "Body"},
                 "Brass spine, glass chamber with the Nachtglas capsule (Mag, slides out of the back), copper coils over the barrel, "
                 "bronze emitter bell, leather-wrapped grip; Needle = the charge gauge; Halo = the Ashlight Corona ring (Crucible only).", True),
    "totenglocke": ("Totenglocke (Opitz's bell cannon, built from the Map 1 parts)", {"bell": "Bell", "crank": "Crank", "clapper": "Clapper",
                    "hammer": "Hammer", "pawl": "Pawl", "runes": "Runes", "body": "Body"},
                    "Rail-yard locomotive bell on its cast yoke, barracks bunk-tube frame with a quartermaster stencil, Salt Chapel "
                    "turret-clock crank with a hank of bell rope; Bell vibrates, Crank winds, Hammer cocks on the wind and strikes on "
                    "the toll, Clapper swings, Pawl clicks; Runes = Mitternacht's violet runes (Crucible only).", True),
    "elmsfeuer": ("Sankt-Elmsfeuer (U-1047's arc projector)", {"crank": "Crank", "dial": "Dial", "arc": "Arc", "orb": "Orb", "body": "Body"},
                  "Navy-grey magneto breech with a hand crank (the reload), ammeter Dial, copper coil in a glass sleeve over a brass "
                  "bore, porcelain insulator sights, violet discharge gap (Arc flickers), wooden stock; Orb = Kugelblitz's ball "
                  "lightning (Crucible only).", True),
    "lodestone": ("Lodestone (the Groom Lake gravity caster, built from the Map 4 parts)", {"sphere": "Sphere", "cradle": "Cradle", "yoke": "Yoke",
                  "coil": "Coil", "grip_l": "Grip_L", "grip_r": "Grip_R", "corona": "Corona", "body": "Body"},
                  "A lead-glass lens (Sphere, spins; the Nachtglas seed inside) in a three-ring brass gyro cradle (Cradle, opens on a lift) on a "
                  "brass yoke with a stencilled yard tag, the relay coil on a ceramic former behind the head (Coil, glows on the fling charge), "
                  "wooden rear and front grips; Corona = Escape Velocity's violet ring of light round the lens (Crucible only).", True),
    "gramophone": ("Siren Gramophone (tactical)", {"record": "Record", "crank": "Crank", "tonearm": "Tonearm", "lid": "Lid", "body": "Body"},
                   "Portable wind-up gramophone: leatherette case with brass corners, open lid, felt platter, the record (spins while it "
                   "plays), tonearm with a brass horn (drops at the needle), side crank (turns while it plays).", False),
}


def paperwork(wid, rep, folder):
    title, parts, notes, gun = TABLE[wid]
    with open(os.path.join(folder, "LICENSE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("Ours: original in-house work for GRAVELIGHT (Devin Blair / DBIT Defense). Same terms as the rest of the project's own code and assets.\n")
    tex = ", ".join("textures/" + t for t in rep.get("textures", []))
    with open(os.path.join(folder, "SOURCE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("Title: %s\n" % title)
        f.write("Author: GRAVELIGHT project (modelled in-house by tools_src/blender/wonder/%s.py, T-090)\n" % wid)
        f.write("Source: this repository (tools_src/blender/wonder/%s.py + wonder_lib.py)\n" % wid)
        f.write("License: Ours (original work, in-house)\n")
        f.write("Credit line: none needed\n")
        f.write("Format: GLB (Blender %s export, external PNG textures): nodes %s; %d tris; baked PBR set %dpx (albedo, normal OpenGL, ORM)\n" % (
            rep.get("blender", "5.1"), ", ".join(n["name"] for n in rep["nodes"]), rep["tris"], rep.get("texture_size", 0)))
        f.write("Downloaded: n/a (generated 2026-10-26 by Claude for Devin Blair)\n")
        f.write("Files used: model.glb, %s\n" % tex)
        f.write("Game use: %s\n" % ("first-person wonder weapon (gravelight/weapons/weapon_glb.gd + wonder_look.gd)" if gun else
                                    "the thrown Siren Gramophone (gravelight/weapons/gramophone.gd + wonder_look.gd)"))
    if gun:
        with open(os.path.join(folder, "import_preset.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write("weapon\n")


def native(rep):
    mn, mx = rep["bbox_min"], rep["bbox_max"]
    length = round(mx[2] - mn[2], 4)
    return {"forward": "-Z", "up": "+Y", "origin": "the right-hand grip (authored in the game frame)", "length_m": length,
            "real_length_m": length, "scale": 1.0, "size": rep["size"], "bbox_min": mn, "bbox_max": mx, "tris": rep["tris"],
            "materials": sorted({m for n in rep["nodes"] for m in n["materials"]}), "textures": len(rep.get("textures", []))}


def main():
    with open(MODELS, "r", encoding="utf-8") as f:
        doc = json.load(f)
    rows = {}
    for wid in TABLE:
        rp = os.path.join(REPORTS, wid + ".json")
        folder = os.path.join(OURS, wid)
        if not (os.path.exists(rp) and os.path.exists(os.path.join(folder, "model.glb"))):
            print("skip", wid, "(no build)")
            continue
        with open(rp, "r", encoding="utf-8") as f:
            rep = json.load(f)
        paperwork(wid, rep, folder)
        title, parts, notes, gun = TABLE[wid]
        nodes = [n["name"] for n in rep["nodes"]]
        entry = {"source": "ours", "asset": "ours/wonder/" + wid, "glb": "res://assets/ours/wonder/%s/model.glb" % wid,
                 "parts": {k: v for k, v in parts.items() if v in nodes}, "native": native(rep), "alt": [],
                 "nodes": {n["name"]: n["tris"] for n in rep["nodes"]}, "notes": notes,
                 "script": "tools_src/blender/wonder/%s.py" % wid}
        if gun:
            doc["weapons"][wid] = entry
        else:
            doc.setdefault("extras", {})[wid] = entry
        rows[wid] = (entry, rep, title)
        print("%-12s %6d tris  %s" % (wid, rep["tris"], ", ".join(nodes)))
    with open(MODELS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")
    # docs/WEAPON_MODELS.md: the wonder rows
    with open(WEAPONS_MD, "r", encoding="utf-8") as f:
        md = f.read()
    for wid in ("ashlight", "totenglocke", "elmsfeuer", "lodestone"):
        if wid not in rows:
            continue
        entry, rep, title = rows[wid]
        parts = ", ".join("%s=%s" % (k, v) for k, v in entry["parts"].items())
        n = entry["native"]
        new = ("| `%s` | %s | wonder | ours | `ours/wonder/%s` (`tools_src/blender/wonder/%s.py`) | GRAVELIGHT (in-house, %s) | Ours | %s | "
               "-Z, %.3f m -> x1.000, %d tris | ours: holder choreography + WonderLook part drivers |" % (
                   wid, title.split(" (")[0], wid, wid, "T-105" if wid == "lodestone" else "T-090", parts, n["length_m"], n["tris"]))
        md = re.sub(r"^\| `%s` \|.*$" % wid, new.replace("\\", "\\\\"), md, flags=re.M)
    with open(WEAPONS_MD, "w", encoding="utf-8", newline="\n") as f:
        f.write(_section(md, rows))
    print("models.json and docs/WEAPON_MODELS.md updated")


SECTION = "## Wonder weapons (T-090)"


def _section(md, rows):
    """The docs/WEAPON_MODELS.md section about our own wonder-weapon models (replaced on every run)."""
    def tris(wid):
        return rows[wid][1]["tris"] if wid in rows else 0
    L = [SECTION, "",
         "Modelled by us from scratch in Blender (UPDATE_05 section 2): `tools_src/blender/wonder/<id>.py` on the shared "
         "`wonder_lib.py` (lathes, bevelled boxes and prisms, swept wires and coils, rivets, raised lettering; smart-UV atlas; "
         "Cycles bakes of AO and a Bevel-node curvature mask; per-material procedural paint baked to albedo / roughness / metallic "
         "and its bump to an OpenGL normal map; ORM packed; GLB with external PNGs), run headless "
         "(`blender -b --factory-startup -P tools_src/blender/wonder/<id>.py -- --out assets/ours/wonder/<id> [--turntable png]`), "
         "then `python -I tools/wonder_register.py` (paperwork, models.json, these rows) and `tools/apply_import_presets.sh`. "
         "WeaponGLB builds them like any GLB gun (model_fit.json gives every marker, pivot and hand); `WonderLook` "
         "(gravelight/weapons/wonder_look.gd) then puts the baked body in `wonder_body.gdshader` (the maps as baked, frost per "
         "map, the weapon's own Crucible look) and the glass / fluid / glow surfaces in their shaders "
         "(assets/ours/wonder/shaders/), shows the Crucible-only part, and drives the extra parts from the holder's state every "
         "frame. Animations are the holder's choreography on these parts; every timing stays in weapons.json "
         "(test_wonder_models). Shots: `gravelight/tools_src/wonder_shots.tscn`.", "",
         "- `ashlight` (%d tris, 2K): brass spine, knurled wind key, glass chamber with the Nachtglas capsule (Mag: slides out of the "
         "back on the capsule reload; its fluid level is the magazine, it sloshes with the gun's motion and flares on a shot), copper "
         "coils in two banks over the glowing core, bronze emitter bell with electrodes round a violet crystal, copper sight rod with "
         "a brass bead, the charge gauge (Needle), leather-wrapped grip. Corona: the Halo ring turns, the fluid burns brighter." % tris("ashlight"),
         "- `totenglocke` (%d tris, 2K): the Rail Yard locomotive bell (cast \"ZECHE KALTENBRUNN\" / \"GRUBENBAHN 1911\", yoke with its "
         "broken foot), the barracks bunk-tube frame (brass finials, spring hooks, \"KAS. II BETT 14\" tag), the Salt Chapel turret-clock "
         "crank (rope, salt). Bell vibration and Crank wind/reload are Totenglocke.pose_parts / reload_hand as before; WonderLook adds "
         "the striker Hammer (cocks over the wind, strikes on every toll and the Bell Dome) and the ratchet Pawl. Mitternacht: midnight-"
         "blue patina (body shader) and the Runes round the sound bow, flaring with the ring." % tris("totenglocke"),
         "- `elmsfeuer` (%d tris, 2K): navy magneto breech with horseshoe magnets and an armature end bell, the magneto Crank (the new "
         "\"crank\" reload: the support hand winds it five turns inside the data's reload time), the ammeter Dial (charge; climbs with the "
         "crank), U-1047 E-RAUM tag, coil in a glass sleeve, discharge gap with the flickering Arc, porcelain insulator sights, conduit "
         "skeleton stock. Kugelblitz: the Orb, a bluer arc, a brighter coil." % tris("elmsfeuer"),
         "- `gramophone` (extras; %d tris, 1K): the thrown Siren Gramophone's world model (gramophone.gd): the Record spins at 78 rpm and "
         "the Crank turns while it plays, the Tonearm swings in and drops at the needle; collision, lure and fuse unchanged." % tris("gramophone"),
         ""]
    block = "\n".join(L) + "\n"
    if SECTION in md:
        a = md.index(SECTION)
        b = md.find("\n## ", a + len(SECTION))
        return md[:a] + block + (md[b + 1:] if b >= 0 else "")
    anchor = "## Conversion notes"
    if anchor in md:
        return md.replace(anchor, block + "\n" + anchor, 1)
    return md + "\n" + block


if __name__ == "__main__":
    main()
