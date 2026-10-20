"""RETIRED (M3): data/weapons.json has hand-tuned additions now; running this would overwrite them.
Run with --force only to rebuild from scratch.

Builds data/weapons.json for hitscan guns from the WEAPONS.md stat tables (M1 snapshot).
After this, data/weapons.json is the source of truth; edit it directly."""
import json, sys
if '--force' not in sys.argv:
    sys.exit('gen_weapons_json.py is retired; edit data/weapons.json directly (or pass --force).')

# id: (name, class, wall_price, dmg, pellets, rpm, mode, mag, reserve, rel_p, rel_e, per_round, ads, sway, pen, move, fo_s, fo_e, fo_min, spread_hip, spread_ads, limb)
G = {
 "m1911":      ("M1911", "pistol", 0, 40, 1, 450, "semi", 8, 80, 1.4, 1.8, False, .15, .20, 0, 1.00, 10, 30, .60, 2.5, 0.4, {}),
 "kar98k":     ("Kar98k", "bolt", 200, 100, 1, 50, "bolt", 5, 50, 0.6, 2.6, True, .30, .35, 1, .95, 60, 150, .85, 4.0, 0.0, {}),
 "m1_garand":  ("M1 Garand", "rifle", 600, 105, 1, 350, "semi", 8, 96, 2.2, 2.2, False, .28, .30, 1, .95, 45, 120, .80, 3.5, 0.2, {}),
 "gewehr43":   ("Gewehr 43", "rifle", 900, 115, 1, 320, "semi", 10, 120, 2.4, 3.0, False, .30, .30, 1, .95, 45, 120, .80, 3.5, 0.2, {}),
 "m1_carbine": ("M1 Carbine", "rifle", 600, 70, 1, 450, "semi", 15, 150, 1.9, 2.4, False, .22, .22, 0, .98, 30, 80, .70, 3.0, 0.3, {}),
 "mp40":       ("MP40", "smg", 1000, 50, 1, 500, "auto", 32, 192, 2.0, 2.6, False, .20, .25, 0, 1.00, 12, 35, .55, 3.5, 1.0, {}),
 "thompson":   ("Thompson M1A1", "smg", 1200, 55, 1, 700, "auto", 30, 210, 2.2, 2.9, False, .22, .30, 0, .98, 12, 35, .55, 3.8, 1.1, {}),
 "stg44":      ("STG-44", "assault", 1200, 65, 1, 550, "auto", 30, 210, 2.3, 2.9, False, .25, .28, 1, .96, 25, 60, .65, 3.5, 0.8, {}),
 "trench_gun": ("Trench Gun", "shotgun", 1500, 40, 8, 60, "pump", 6, 54, 0.5, 0.5, True, .25, .25, 0, .96, 6, 18, .20, 6.0, 4.0, {"head": 1.5, "neck": 1.25}),
 "bar":        ("BAR", "lmg", 1800, 100, 1, 500, "auto", 20, 180, 2.6, 3.2, False, .35, .40, 1, .92, 35, 80, .70, 4.5, 1.0, {}),
 "ppsh41":     ("PPSh-41", "smg", 0, 45, 1, 1000, "auto", 71, 284, 3.0, 3.6, False, .24, .35, 0, .97, 10, 30, .50, 4.0, 1.3, {}),
 "mg42":       ("MG42", "lmg", 0, 90, 1, 1200, "auto", 125, 500, 5.5, 6.5, False, .45, .55, 1, .88, 30, 70, .70, 5.5, 1.6, {}),
 "m1919":      ("Browning M1919", "lmg", 0, 110, 1, 500, "auto", 125, 500, 5.8, 6.8, False, .45, .50, 1, .88, 30, 70, .70, 5.0, 1.4, {}),
 "sawed_off":  ("Double-Barrel Sawed-Off", "shotgun", 0, 60, 10, 400, "semi", 2, 60, 2.4, 2.4, False, .20, .30, 0, 1.00, 4, 12, .15, 9.0, 7.0, {"head": 1.5, "neck": 1.25}),
 "type100":    ("Type 100", "smg", 0, 55, 1, 800, "auto", 30, 240, 2.1, 2.7, False, .20, .25, 0, 1.00, 12, 35, .55, 3.5, 1.0, {"legs": 1.0}),
 "ptrs41":     ("PTRS-41", "sniper", 0, 1000, 1, 120, "semi", 5, 50, 4.2, 4.2, False, .55, .60, 5, .85, 100, 200, .90, 6.0, 0.0, {"head": 2.0, "neck": 1.5}),
 "springfield":("Springfield M1903", "sniper", 0, 200, 1, 45, "bolt", 5, 60, 0.7, 3.0, True, .40, .45, 2, .93, 100, 200, .90, 6.0, 0.0, {"head": 5.0, "neck": 2.5}),
}
CRATE_UNUSED = {"ppsh41": 8, "mg42": 7, "m1919": 6, "sawed_off": 7, "type100": 8, "ptrs41": 5, "springfield": 5,
         "stg44": 5, "thompson": 6, "bar": 5, "gewehr43": 4, "m1_carbine": 3, "trench_gun": 4, "mp40": 3}

out = {"_doc": "Weapon tuning (docs/WEAPONS.md). Damage per pellet. Times in seconds. Falloff: full to start m, linear to min at end m.",
       "default_limb_mults": {"head": 4.0, "neck": 2.0, "torso": 1.0, "arms": 0.9, "legs": 0.9},
       "melee": {
         "trench_knife": {"name": "Trench Knife", "damage": 150, "swing": 0.55, "lunge_range": 3.5, "lunge_distance": 2.5, "reach": 2.0, "arc_deg": 70, "targets": 1},
         "etool": {"name": "Sharpened E-Tool", "damage": 1000, "swing": 0.60, "lunge_range": 3.5, "lunge_distance": 3.0, "reach": 2.2, "arc_deg": 100, "targets": 2, "wall_price": 3000}},
       "lethal": {
         "frag": {"name": "Mk 2 Frag", "damage": 1200, "edge_mult": 0.2, "radius": 6.0, "stagger_radius": 9.0, "fuse": 4.0,
                  "throw_speed": 16.0, "start": 2, "max": 4, "per_round": 2, "wall_price": 250,
                  "self_damage_near": 100, "self_near_m": 3.0, "self_damage_far": 50}},
       "weapons": {}}
for wid, g in G.items():
    (name, cls, price, dmg, pel, rpm, mode, mag, res, rp, re_, pr, ads, sway, pen, move, fs, fe, fm, sh, sa, limb) = g
    w = {"name": name, "class": cls, "damage": dmg, "pellets": pel, "rpm": rpm, "mode": mode, "mag": mag, "reserve": res,
         "reload_partial": rp, "reload_empty": re_, "per_round_reload": pr, "ads_time": ads, "sway": sway, "penetration": pen,
         "move_mult": move, "falloff_start": fs, "falloff_end": fe, "falloff_min": fm, "spread_hip": sh, "spread_ads": sa,
         "limb_mults": limb, "wall_price": price, "upgraded": wid + "_up"}
    if mode == "bolt": w["bolt_time"] = round(60.0 / rpm, 2)
    out["weapons"][wid] = w
# ---- special weapons (M2)
out["weapons"]["panzerschreck"] = {"name": "Panzerschreck", "class": "launcher", "damage": 1000, "pellets": 1, "rpm": 30, "mode": "semi",
    "mag": 1, "reserve": 10, "reload_partial": 3.5, "reload_empty": 3.5, "per_round_reload": False, "ads_time": 0.5, "sway": 0.45,
    "penetration": 0, "move_mult": 0.88, "falloff_start": 999, "falloff_end": 1000, "falloff_min": 1.0, "spread_hip": 2.0, "spread_ads": 0.3,
    "limb_mults": {}, "wall_price": 0, "upgraded": "panzerschreck_up",
    "projectile": {"kind": "rocket", "speed": 38.0, "radius": 5.0, "edge_mult": 0.25, "self_damage": 75, "self_radius": 5.0}}
out["weapons"]["flamethrower"] = {"name": "M2 Flamethrower", "class": "special", "damage": 40, "pellets": 1, "rpm": 1200, "mode": "auto",
    "mag": 160, "reserve": 480, "reload_partial": 3.8, "reload_empty": 3.8, "per_round_reload": False, "ads_time": 0.3, "sway": 0.3,
    "penetration": 0, "move_mult": 0.9, "falloff_start": 999, "falloff_end": 1000, "falloff_min": 1.0, "spread_hip": 0.0, "spread_ads": 0.0,
    "limb_mults": {}, "wall_price": 0, "upgraded": "flamethrower_up",
    "stream": {"reach": 7.0, "cone_deg": 15.0, "tick_rate": 20.0, "burn_dps": 25.0, "burn_seconds": 3.0}}
out["weapons"]["ashlight"] = {"name": "Ashlight", "class": "wonder", "damage": 900, "pellets": 1, "rpm": 180, "mode": "semi",
    "mag": 20, "reserve": 160, "reload_partial": 2.0, "reload_empty": 2.5, "per_round_reload": False, "ads_time": 0.2, "sway": 0.15,
    "penetration": 0, "move_mult": 1.0, "falloff_start": 999, "falloff_end": 1000, "falloff_min": 1.0, "spread_hip": 1.2, "spread_ads": 0.2,
    "limb_mults": {}, "wall_price": 0, "upgraded": "ashlight_up",
    "projectile": {"kind": "bolt", "speed": 45.0, "splash": 600, "radius": 2.5, "edge_mult": 0.3, "ricochets": 1, "self_damage": 40, "self_radius": 2.5}}
out["tactical"] = {"gramophone": {"name": "Siren Gramophone", "damage": 1500, "radius": 7.0, "inner_radius": 3.0, "lure_seconds": 8.0,
    "lure_radius": 25.0, "per_pickup": 2, "max": 3, "per_round": 1, "throw_speed": 11.0}}

# ---- upgraded variants (used from M3; WEAPONS.md section 5)
UP = {
 "m1911": ("Last Rites", 120, 450, 12, 120, 1.2, 1.6, 0, {"ricochet": 1}),
 "kar98k": ("Final Verdict", 400, 60, 8, 80, 0.5, 2.2, 4, {}),
 "m1_garand": ("Eight-Ping Benediction", 260, 380, 12, 144, 2.0, 2.0, 2, {"underbarrel": "rifle_grenade"}),
 "gewehr43": ("Stille Nacht", 280, 340, 16, 160, 2.2, 2.7, 2, {"head_mult": 8.0, "quiet_kills": True}),
 "m1_carbine": ("Reveille", 150, 750, 30, 300, 1.7, 2.2, 1, {"fire_modes": ["semi", "auto"]}),
 "mp40": ("Grabesgesang", 120, 550, 40, 280, 1.5, 1.9, 0, {"reload_mult": 0.75}),
 "thompson": ("Chicago Lament", 120, 720, 50, 350, 2.4, 3.0, 2, {"armor_piercing": True}),
 "stg44": ("Sturmwind", 140, 600, 40, 320, 2.1, 2.6, 2, {"fire_modes": ["auto", "burst3"]}),
 "trench_gun": ("Gravedigger's Due", 90, 70, 10, 80, 0.4, 0.4, 1, {"incendiary": {"dps": 60, "dur": 3.0}}),
 "bar": ("Ironmonger", 210, 520, 30, 300, 2.4, 3.0, 2, {"stagger": 0.35}),
 "ppsh41": ("Red Winter", 100, 1000, 115, 460, 2.8, 3.4, 0, {"frost": {"slow": 0.3, "dur": 2.0}}),
 "mg42": ("Bone Saw", 180, 1200, 200, 800, 5.0, 6.0, 2, {"sever_chance": 0.15}),
 "m1919": ("The Long Amen", 200, 550, 250, 750, 5.2, 6.2, 3, {"no_overheat": True}),
 "sawed_off": ("Twin Coffins", 140, 400, 4, 80, 2.2, 2.2, 1, {"volley": 4}),
 "type100": ("Hollow Blossom", 130, 850, 40, 320, 1.8, 2.3, 0, {"hollow_point": True}),
 "ptrs41": ("Bear Tax", 2000, 130, 8, 80, 3.6, 3.6, 99, {"armor_ignore": True}),
 "springfield": ("Long Goodbye", 600, 50, 8, 96, 0.6, 2.6, 3, {"headshot_pop": {"dmg": 300, "r": 2.0}}),
 "panzerschreck": ("Stovepipe Sermon", 1500, 30, 2, 20, 3.2, 3.2, 0, {"cluster": {"count": 6, "dmg": 400, "r": 2.5}}),
 "flamethrower": ("Furnace Warrant", 80, 1200, 240, 720, 3.4, 3.4, 0, {"reach": 10, "burning_ground": {"dps": 150, "dur": 4}}),
 "ashlight": ("Ashlight Corona", 1400, 200, 40, 200, 1.8, 2.2, 0, {"chain": 3, "splash": 900}),
}
out["upgraded"] = {}
for base, u in UP.items():
    (name, dmg, rpm, mag, res, rp, re_, pen, props) = u
    up = dict(out["weapons"][base])
    up.update({"name": name, "damage": dmg, "rpm": rpm, "mag": mag, "reserve": res, "reload_partial": rp, "reload_empty": re_,
               "penetration": pen, "properties": props, "base": base})
    up.pop("upgraded", None)
    out["upgraded"][base + "_up"] = up
json.dump(out, open("data/weapons.json", "w"), indent=2)
print(len(out["weapons"]), "weapons,", len(out["upgraded"]), "upgraded")

# ---- crate pool (WEAPONS.md section 10)
POOL = [("ppsh41","A",10),("mg42","A",10),("m1919","A",8),("panzerschreck","A",6),("ptrs41","A",6),("ashlight","A",3),
        ("sawed_off","B",8),("type100","B",8),("springfield","B",6),("flamethrower","B",5),("gramophone","B",6),("thompson","B",5),
        ("stg44","B",5),("trench_gun","B",5),("bar","B",5),("mp40","C",4),("m1_carbine","C",3),("m1_garand","C",3),("gewehr43","C",3),("kar98k","C",3)]
crate = json.load(open("data/crate.json"))
crate["pool"] = [{"id": i, "tier": t, "weight": w} for (i, t, w) in POOL]
crate.update({"cycle_seconds": 4.5, "pickup_window_seconds": 12.0, "pity_first_pulls": 3, "pity_tiers": ["A", "B"],
              "dud_breaker_c_streak": 2, "a_breaker_pulls": 5, "wonder_bonus_every": 6, "wonder_max_weight": 9,
              "drummer_never_first_pulls_at_location": 2})
crate.pop("pity_min_tier", None)
json.dump(crate, open("data/crate.json", "w"), indent=2)
print("crate pool", len(POOL))
