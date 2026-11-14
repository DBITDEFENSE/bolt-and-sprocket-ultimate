# T-248: the Type 100 and four more guns

**T-248, 2026-11-14.** The owner: "TYPE 100 NEEDS SOME WORK, IT WOULD ALSO BE NICE TO ADD ANOTHER 3 OR 4 GUNS." Branch `claude/u18-guns`.

## The Type 100: what was wrong

- **No real model.** It was one of the six greybox guns. Its viewmodel was the procedural `WeaponModels._w_type100`: a flat profile stock, two tubes and a box for a magazine. Next to the downloaded guns (the OGA palette set and the three Sketchfab hero guns) it read as a placeholder. No free model of it exists (FREE_ASSET_LIST: "no free match found").
- **Its reload pulled the side magazine straight down.** The holder's magazine reload always moved the Mag along -Y. The Type 100's magazine goes in from the left, so the old magazine dropped out of its own flank.
- **The extended-magazine attachment hung a box under the side magazine.** `WeaponKitModels._mag_ext` always grew the magazine downward.
- **No identity in the numbers.** Its stats were a Thompson's (55 damage, 30 rounds, the same spreads and falloff) at a faster 800 RPM: the same gun, but faster, with the weaker 8 mm cartridge.

## What changed on the Type 100

- **Model.** A hero model built in-house in headless Blender on the wonder-weapon toolkit: `tools_src/blender/guns/type100.py` (on `tools_src/blender/wonder/wonder_lib.py`, which is unchanged).
  - 21,144 tris and a baked 2K PBR set (albedo, normal, ORM), in `assets/ours/weapons/type100/` (licence "Ours").
  - The 1940 pattern at real size (0.865 m):
    - round receiver with a knurled end cap, half sunk in a one-piece wooden rifle stock (straight wrist, steel buttplate);
    - perforated barrel jacket with 8 x 4 oblong slots cut through, the barrel visible inside;
    - front band with the post between protective ears;
    - compensator with two side ports each side, and the bayonet lug bar under the jacket;
    - tangent rear sight;
    - 30-round curved magazine going in horizontally from the LEFT (the `Mag` part);
    - cocking handle on the right (`Bolt`), ejection port, strap trigger guard (`Trigger`), sling swivels, screws.
  - It goes through the shared weapon shader like every other gun.
  - This is the one exception to the weapon art rule "downloaded only, never modelled", because no free model exists. The rule still stands for every other gun.
  - Captures: `docs/captures/u18_guns/type100_turntable.png` and `type100_blender_{left,right,front34}.png` (Blender).
- **Reload direction (all guns).** The procedural twin's meta or model_fit can now give a `mag_dir`. `WeaponHolder._animate_reload` pulls the magazine out along it and feeds the fresh one back in along it. Default: down, so every existing gun is unchanged.
  - Type 100, Sten and FG 42: out to the left.
  - Bren: off the top.
  - `_mag_ext` (the extended-magazine attachment) grows the magazine the same way: sideways, or up for the Bren.
- **Stats** (old -> new). Reload timings, rate, magazine and reserve are unchanged.

| Key | Old | New |
|---|---|---|
| damage | 55 | 52 (between the MP40's 50 and the Thompson's 55) |
| sway | 0.25 | 0.22 |
| falloff start / end / min | 12 / 35 / 0.55 | 14 / 40 / 0.6 (the longer jacket) |
| spread hip / ADS | 3.5 / 1.0 | 3.2 / 0.8 |
| recoil (weapons.json recoil.weapons) | v 0.38, v_growth 0.05, h 0.12 | v 0.30, v_growth 0.045, h 0.08, h_swing 0.10, h_freq 0.5 |
| feel eye_relief / ads_zoom | 0.28 / 0.88 | 0.36 / 0.86 (the eye sits further back on the new model, so the receiver end cap stays under the sight picture) |

  - The identity: the heavy, rifle-stocked SMG, so the steadiest and most accurate SMG, hitting a little lighter than the .45.
  - Crucible **Hollow Blossom**: the same handling numbers. Its 130 / 850 / 40 and the `hollow_point` property are unchanged.
  - Bots' weapon tier: 3.3 -> 3.4.

## Four new guns

All four come from the OpenGameArt "Ultimate Low Poly Guns" WW2 set (TastyTony / Pichuliru, CC-BY 4.0, credited in each folder's SOURCE.txt and in `data/credits_art.json`). It is the same set the 13 baseline guns came from, and the owner's zip was already in `assets/user_supplied/packs/`.

- **Conversion.** `python -I tools/intake_guns.py --only tt-fg42,tt-mosin-nagant,tt-bren,tt-sten --merge`. The new `--merge` updates only those entries in models.json, because the earlier conversion reports are not in a fresh checkout.
- **Smoothing.** Then smoothed like the rest (`tools_src/blender/smooth_palette_guns.py`, T-241 b).
- **Why these four.** Each gives the roster something it lacked:
  - **FG 42**: the second assault (battle) rifle.
  - **Mosin-Nagant**: the second bolt rifle.
  - **Bren**: the magazine-fed accurate LMG, and the first British long gun.
  - **Sten**: the cheap side-magazine SMG.
- **Not picked.** The C96 was the other candidate: its magazine is fixed in the frame, so it has no Mag part for a reload. It stays in the pack, along with the Hi-Power, Nagant M1895, Welrod, DP 28, SVT 40 and M3.

| Id | Name | Class | Dmg | RPM | Mag / reserve | Reload p / e | Notes | Crucible (property) |
|---|---|---|---|---|---|---|---|---|
| `fg42` | FG 42 | assault | 85 | 650 | 20 / 160 | 2.4 / 3.0 | pen 1; falloff 40-100 m; climbs hard on auto (recoil v 0.72) | **Sturzflug**: 200, 700 RPM, 30 / 300, pen 2, `stagger 0.3` |
| `mosin_nagant` | Mosin-Nagant M91/30 | bolt | 120 | 45 | 5 / 50 | 0.65 a round / 2.8 | pen 2; bolt 1.3 s; heavier than the Kar98k (100) | **Second Opinion**: 420, 10 / 90, pen 4, `ricochet 2` |
| `bren` | Bren Mk II | lmg | 95 | 520 | 30 / 240 | 2.8 / 3.4 | pen 1; the accurate LMG (ADS spread 0.8, recoil v 0.6) | **Last Orders**: 200, 560 RPM, 45 / 360, pen 2, `armor_piercing` |
| `sten` | Sten Mk II | smg | 48 | 550 | 32 / 224 | 1.9 / 2.5 | MP40-class, a quicker reload, a looser cone | **Cheap Funeral**: 115, 600 RPM, 50 / 350, `incendiary` |

- **Balance.**
  - Damage per second: FG 42 55k and Bren 49k (BAR 50k); Sten 26k (MP40 25k); Type 100 42k (Thompson 38k, PPSh 45k).
  - The Crucible properties are existing ones, so there are no new code paths.
- **Availability: the Requisition Crate** (`crate.json`): FG 42 B 5, Bren B 5, Sten C 4, Mosin-Nagant C 3.
- **No wall-buys.** A wall-buy changes a map's baked mapdata and its minimap signature (a WSL re-bake per map) and the wall audit. The order says not to move existing ones, and every map's free walls would need the owner's eye. So these are crate guns, like the Type 100. Adding one later is a scene node plus a mapdata re-bake.
- **Bots** (`ai/economy.json` weapon_tiers):
  - tiers: Sten 3.1, Mosin 1.3 (dropped after round 12 like the Kar98k's 10), FG 42 4.3, Bren 4.4;
  - they keep or swap crate pulls by those tiers and feed the guns to the Crucible like any other;
  - squad NPCs (`squads.json`): the Soviet scouts carry a Mosin in place of a Kar98k, and the British commandos one Sten in place of a Thompson (same classes).
- **Sounds.**
  - Synthesized with the existing generator (`gravelight/tools_src/gen_audio.py`, our own work): `fire_fg42`, `fire_mosin_nagant`, `fire_bren`, `fire_sten`, three variants each.
  - The upgraded rows get the usual Nachtglas layer; reload foley is shared by kind.
- **Models and fit.**
  - Each gun builds through WeaponGLB with a procedural twin (`_w_fg42`, `_w_mosin_nagant`, `_w_bren`, `_w_sten`) that gives the metas and is the greybox fallback.
  - `model_fit.json` places the sights from vertex scans and `ads_check --autofit`. All five guns pass `ads_check --headless --geometry` (markers and sight geometry).
  - Per gun:
    - the Sten's model faces backwards in the pack (`extra_rot` 180);
    - the Bren's sights sit offset to the LEFT of its top magazine, as on the real gun (the working rear sight is the aperture ring on the ladder base's left side; T-250 folds the raised carrying handle down to the right with model_fit `fold` and sets eye relief 0.20);
    - the Mosin-Nagant's model is 3.4 mm off centre, so its markers sit in the notch and on the post.
  - Casings: `models.json extras.cartridges.casing_for`.
  - Attachments: no drum on the Sten or FG 42; the Mosin's scope is a "PU Scope"; the Bren's extended magazine is a "Long Box Magazine".
- **World model.** Bots' bodies and remote players build the same `WeaponModels.build(id)`, so the new models are their third-person guns too. The HUD draws weapon names, not icons.

## Checks

- **Tests and checks:** GUT `test_t248_guns` (new), the weapon / ads / crate / economy / bot / kit / upgrade / vfx / audio suites, `check_scripts`, the smokes. Results are in the commit message and the hand-back.
- **Renders** (WSL, software GL, darker than a real GPU), in `docs/captures/u18_guns/`. Every first-person sheet shows hip, ADS, reload at 30 % and reload at 70 %.
  - `type100_before_fp.png`: the procedural greybox, via vm_shots `--greybox`. Its reload columns already use the new left pull, because the procedural twin carries `mag_dir`.
  - `type100_after_fp.png`, `type100_up_fp.png` (Hollow Blossom);
  - `fg42_fp.png`, `mosin_nagant_fp.png`, `bren_fp.png`, `sten_fp.png`;
  - `ads/<gun>_ads.png`: large ADS frames of the Type 100, FG 42 and Bren, with the Thompson as the reference;
  - `type100_turntable.png`, `type100_blender_*.png`: the model in Blender, EEVEE.
