# Wonder weapon design sheets: the later four (UPDATE_05 §2)

UPDATE_05 §2 asks for a design sheet now for the wonder weapons that get built with their maps: **Die Lange Nacht**
(Morgenrot), **The Return Policy** and **Blartz's Field-Kit Omni-Blaster** (Helvetia Works), and the **Kinderhammer**
(the Hammer's drop, Map 0). This page is that sheet: what each one looks like, how big it is, what it is made of,
which GLB nodes move and what drives them, what it sounds like, and what is still open. It designs looks only.
Every gameplay number is quoted from `docs/gravelight/WEAPONS.md` or `data/gravelight/weapons.json` and none is
invented here. Where the data doesn't exist yet, the sheet says **"timing from data"** and names the key the weapon's
`weapons.json` entry will carry.

Rules every sheet follows (ART_BIBLE.md, ART_FACTIONS.md, HOMAGE_BOSSES.md §1.2):
- stylized-realistic, late-2000s round-based zombies; the silhouette reads first;
- **Nachtglas violet (emission `#8C33FF`, glass body `#14081F`) is the only saturated accent**; every other albedo stays
  under saturation 0.35 and between value 0.04 and 0.90;
- no real-world brand names in any in-game text, decal or stencil; fictional marks only (P·W·K, the Darkmatter
  circle, the Helvetia plate); no real insignia;
- the Crucible version is **a material plus small attached bits on the same mesh** (UPDATE_05 §2.6), never a new model;
- budgets: hero wonder weapon **≤ 35 000 tris**, **one 2K texture set** (albedo sRGB, normal OpenGL +Y, ORM),
  **1024 px/m** viewmodel texel density;
- the Cousins are never sexualized, and Jakub is never a joke (neither appears on these models, but the Kinderhammer
  is the Hammer's maul and is treated with the same care).

## 0. The pipeline the built wonder weapons use

The built ones are the **Ashlight**, the **Totenglocke**, **Sankt-Elmsfeuer** and the **Siren Gramophone** tactical;
the u05-wonder builder documents them in detail elsewhere. These four follow the same path when their maps are built:

1. **Generator script:** `tools_src/blender/wonder/<id>.py` on the shared `tools_src/blender/wonder/wonder_lib.py`,
   headless Blender 5.1 (`blender -b --factory-startup -P tools_src/blender/wonder/<id>.py -- --out assets/ours/wonder/<id> [--turntable <png>]`).
   It is authored directly in the game frame (the library rotates every object into Blender's Z-up at export so the
   glTF Y-up conversion lands back on the authored numbers). The library does the modelling primitives (lathes,
   bevelled boxes and prisms, swept wires, coils, rivets, bolt heads, raised lettering, strokes), the smart-UV atlas,
   the Cycles bakes (AO, a Bevel-node curvature mask, then the per-material procedural paint into albedo / roughness /
   metallic and its bump into an OpenGL normal map), the ORM packing, the GLB with external PNGs, a build report and
   an 8-angle EEVEE turntable. Surfaces named `glass`, `fluid`, `glow`, `coil_glow`, `emitter`, `arc`, `runes`, `halo`,
   `orb` are not baked: the game gives them their own shaders.
2. **Output:** `assets/ours/wonder/<id>/model.glb` plus `textures/<id>_albedo|normal|orm.png` (2K) and `LICENSE.txt` /
   `SOURCE.txt` ("Ours"), so `test_license_gate` passes.
3. **Registration:** `python -I tools/wonder_register.py` (add the id to its TABLE): paperwork, `models.json`
   `weapons.<id>` with `"source": "ours"`, the `glb`, the `parts` map and a game-frame native block, and the
   WEAPON_MODELS.md rows; then a hand-written `model_fit.json` entry (every marker, pivots, hands, and a `wonder`
   block: Crucible parts, special-material colours, the upgraded look).
4. **Build in game:** `WeaponGLB` builds it like any GLB gun; `WonderLook` (`gravelight/weapons/wonder_look.gd`) puts
   the baked body in `assets/ours/wonder/shaders/wonder_body.gdshader`, the special surfaces in their shaders, toggles
   the Crucible part, and drives any new part from the holder's state (add a `_tick_<id>` there).
5. **Checks:** `tools/ads_check.sh`, `gravelight/tools_src/wonder_shots.tscn` (in-hand states and `--greybox` before
   shots), `test_wonder_models` (contract, parts, Crucible = same meshes, timings equal to the greybox).

**The rig frame** (WEAPON_MODELS.md "Viewmodel fit"): metres, the barrel along **-Z**, **+Y** up, the origin at the
right-hand grip. Moving parts carry the contract names `Mag`, `Bolt`, `Slide`, `Pump`, `Cover`, `Barrels`, `Crank`,
`Rocket`, `Valve`; markers are `Muzzle`, `LeftHand`, `SightPoint`, `FrontSight`; the root carries the metas
(`reload`, `length`, and so on). The holder's reload kinds today are `mag`, `pistol`, `drum`, `capsule`, `belt`,
`bolt`, `shell`, `enbloc`, `break`, `rocket`, `fuel` (spins `Valve` 1.5 turns about Z) and `bell`, plus `none`.
Nodes outside the contract (`Dial`, as Sankt-Elmsfeuer already carries) are allowed but need holder or weapon-script
code to move. Each sheet lists them as **new** under its named parts.

**Blockout stubs** (primitives only, right size, named parts, for scale and sight checks):
`tools_src/blender/wonder/stubs/<id>_blockout.py`, run as
`blender -b -P <stub> -- --out <somewhere>.glb`. They are not the hero models and never write under `assets/`.

**Side views** below look from the weapon's **left (-X)**, so the muzzle (-Z) is on the left and the player's eye is on
the right.

---

## 1. DIE LANGE NACHT (`lange_nacht`), Morgenrot's cryo-lance

**Pitch:** a hand-built liquid-oxygen lance, the rocket's own fuel turned against it. A frost-caked flask under a
lagged steel lance, a brass dam regulator on top, and a vaned nozzle that breathes white fog.

**Lore tie-in:** WEAPONS.md §22.1; MAP3_MORGENROT.md §3.2. It is built from three parts: the **LOX flask** from the
Treibstofflager (D, the fuel depot with its frost-caked tanks), the **nozzle** from the Assembly Hall (C_STOLLEN,
the rocket-section cranes), and the **pressure regulator** from the dam (E_KRAFTWERK). It is assembled at the
Leitstand workbench in the Kessel (Totenglocke buildable rules). Rocket detail stays at museum-placard level
(MAP3 §0 rule 4): "liquid oxygen", "valve", "regulator", nothing that reads as a manual. Flavor: *"The rocket's own
fuel, turned against it."*

**Silhouette:** a long, thin lance with one fat cylinder slung under its back half, a squat block and handwheel at
the rear, a vertical foregrip ahead of the flask, and a flared four-vaned nozzle. From 40 m in fog it reads as
"a pipe with a bottle under it". No other gun in the game has that outline, and the fog trailing from the nozzle
makes it unmistakable in hand.

```
   muzzle (-Z)                                                  eye (+Z)
                     front post                     rear notch
      __            |                                    |   _
  ===<__|==|=========[####lagging####]=========[=REGULATOR=]=(O)  <- Valve handwheel
   nozzle  collar    |                           | (Dial) |
   +vanes          |FG|  (________LOX FLASK________)-hose-  |grip|
                   |__|   clamp            clamp            |____|
```

**Real dimensions:**

| | |
|---|---|
| Overall length | **0.78 m** (handwheel back at z +0.07 to the nozzle face at z -0.71) |
| Grip to muzzle | **0.71 m** |
| Bore line | y +0.05 (lance tube centre) |
| Flask | Ø 0.10 m × 0.30 m, centre (0, -0.035, -0.26) |
| Height | 0.20 m (flask bottom to sight tips) |
| Weight feel | **~6.5 kg**: a full two-litre flask is most of it. It is nose-heavy and slow to swing, and it sits lower in the hip pose than the flamethrower's wand. The `feel` block (hip, sway_mult) belongs in data; the flamethrower's (`hip` [0.1, -0.12, -0.32], `sway_mult` 1.2) is the starting point to copy. |

**Materials** (ART_BIBLE §3 families, the shared weapon shader):

| Part | Family | Roughness / metal | Notes |
|---|---|---|---|
| Flask shell | gun metal (brushed steel) | 0.35 / 1.0 | **permanent rime**: a per-part frost mask (new shader input, see below) so the flask stays frosted on every map; thick white-blue rime at the ends and clamp bands, condensate streaks below |
| Lance tube, clamps, vanes | gun metal (blued) | 0.40 / 1.0 | bluing from the shader; frost on up-facing faces |
| Lagging (insulation over the lance) | cloth: felt / canvas | 0.92 / 0 | grey felt bound with wire, cracked rime in the folds |
| Regulator body, nozzle | brass | 0.30 / 1.0 | the regulator is dam-plant brass with a stamped plate; the nozzle has machined orifices |
| Gauge face (Dial) | painted metal / enamel | 0.30 / 0 | cream face `#D8CFB8`, black ticks, red-brown needle (desaturated) |
| Handwheel | gun metal (cast iron), painted | 0.50 / 0.9 | worn black paint, bare at the rim |
| Grip, foregrip | leather family (rubber wrap) | 0.60 / 0 | rubberised cloth tape over wood |
| Hose | gun metal (braided) | 0.45 / 1.0 | braided sleeve on a normal map, not geometry |

**Markings** (decals in the albedo, black paint, value 0.05): the flask carries **"FLÜSSIGER SAUERSTOFF"** and a black
**P·W·K HW** sunburst stencil (depot stock, so no red ring: ART_FACTIONS §3 keeps the ring for launch-crew gear).
The regulator plate reads **"KRAFTWERK · DRUCKMINDERER"**, and the nozzle carries an assembly-line chalk number. No
violet anywhere on the base weapon: it is plain rocket fuel.

**Texture plan:** one 2K set (albedo, normal, ORM). The gun's unwrapped surface is about 0.3 m², and at 1024 px/m that
fills about 1K, so the 2K set gives the flask, regulator and nozzle (what the camera sees) 2× density, with the
underside and lance rear at 1×. The rime and condensate are painted into the albedo/ORM and boosted by the frost mask.

**Named parts (GLB nodes):**

| Node | Pivot | What drives it |
|---|---|---|
| `Valve` | the handwheel centre (0, 0.05, 0.06), axis Z | holder reload kind **`fuel`**: `rotation.z` = 1.5 turns over p 0.2 to 0.8; the left hand goes to `Valve.position + (-0.03, 0, 0)` |
| `Mag` | the flask centre (0, -0.035, -0.26) | the flask; the refill swaps it (see reload); the flamethrower's `fuel` kind only marks Mag, so a flask-swap motion is **new** |
| `Dial` (**new**) | the gauge centre on the regulator's left flank (-0.031, 0.06, -0.02), axis X | the gauge needle = fuel fraction (`w.mag / mag_size`); needs a one-line hook in the weapon script (Sankt-Elmsfeuer's `Dial` is the precedent) |
| `Muzzle` | (0, 0.05, -0.71) | stream origin (`stream.reach`, `cone_deg`) and the fog VFX |
| `LeftHand` | (0, -0.03, -0.47), `lh_axis` "y" | the vertical foregrip |
| `SightPoint` / `FrontSight` | (0, 0.095, 0.0) / (0, 0.095, -0.60) | see the sight picture |
| root metas | `reload` = `"fuel"`, `length` = 0.78 | |

**Animation beats:**

| Beat | What happens | Timing |
|---|---|---|
| Draw | It swings up from low right, the flask's weight dips the muzzle, and a puff of boil-off vents from the regulator | the holder's raise, `SWAP_TIME` 0.42 s × `draw_mult` (code) |
| Idle | a slow wisp of boil-off from the nozzle, every ~3 s a tick of frost creaking on the flask; the needle trembles | cosmetic loop |
| Fire (held) | the nozzle exhales a widening fog cone, the needle sinks with fuel, the lance shivers (low-amplitude buzz, no climb), and frost creeps up the lagging while firing | timing from data: `lange_nacht.stream.tick_rate` (WEAPONS §22.1: 20 ticks/s, reach 9 m, cone 30°); fuel `lange_nacht.mag` = 80 units, 8 s |
| Freeze | not a model beat: the target frosts and stops; on the gun, the needle kicks once | `frozen` status, 1.2 s in the cone (§22.1) |
| Out of fuel | the nozzle sputters, the needle sits on zero, and the valve can't be turned | |
| Reload / refill | **There is no reserve.** It refills at the Crucible (2500) or from the LOX flask part that respawns every 3 rounds at the depot (§22.1). On a refill the left hand spins the handwheel (`fuel` kind), the old flask is unclamped and dropped, a fresh frosted flask clicks in, and a white burst vents from the regulator | timing from data: `lange_nacht.reload_partial` / `reload_empty` (**not in WEAPONS.md**; the flamethrower's 3.8 s is the archetype default if the entry copies it). Open question 1 |
| Inspect | (no inspect system in the holder yet) tilt the lance, the left hand wipes rime off the gauge glass, and the needle bounces | wanted |

**Sound beats** (AudioDirector keys; `fire_<id>` is the holder's firing-sound convention):

| Beat | Existing key (stand-in) | Wanted key |
|---|---|---|
| Spray loop | `fire_flamethrower` (stand-in only: it is a roar, and this should be a hiss) | `fire_lange_nacht`: a pressurised hiss with a cold crackle, looping |
| Spray start / stop | | `lange_nacht_open`, `lange_nacht_close` (valve squeal + puff) |
| Target freezes | | `lange_nacht_freeze` (ice-skin crackle, positional) |
| Frozen target shatters | `glasshide_shatter` (via `Effects.shatter`, already the Glasshide shatter path) | |
| Empty sputter | `gun_dry` | `lange_nacht_empty` |
| Refill / handwheel | `reload_start`, `reload_end`, `build_part` | `lange_nacht_valve` (iron wheel squeak), `lange_nacht_refill` (LOX pour and boil-off roar) |
| Idle | | `lange_nacht_idle` (faint boil-off and metal tick, very quiet) |
| Polarnacht spread | | `lange_nacht_spread` (a chain of crackles) |

**Crucible version: POLARNACHT** (`lange_nacht_up`; WEAPONS §22.1: reach 12 m, cone 40°, freeze in 0.9 s,
`freeze_spread` 3 m, 120 fuel). Same mesh:
- **Material:** the Nachtglas vein camo over the brass and steel; the rime turns faintly violet at its edges (frost
  mask × vein mask, emission ≤ 1.5 so it never outshines the HUD).
- **Toggled bits** (nodes present in the GLB, hidden on the base): `UpCollar`, a Nachtglas sight-glass collar on the
  flask neck (emissive 2 to 3, pulses when a freeze spreads); `UpSpikes`, ice-crystal spikes (ice family 0.1 / 0,
  non-emissive) grown along the four nozzle vanes.

**Budget:** target **20 000 tris** (flask 3k, nozzle and vanes 4k, regulator, gauge and handwheel 6k, lance, lagging
and binding 4k, grips 2k, Crucible bits 1k), cap 35 000. One 2K set; the Crucible bits share it.

**Sight picture:** rear notch on the regulator top (SightPoint (0, 0.095, 0.0)), a frost-shield post on the nozzle
collar (FrontSight (0, 0.095, -0.60)). The 0.60 m sight radius is long for a hose weapon on purpose: the ADS shows the
whole lance running into the fog with the post standing in the cone's centre. The lagging stays below the line.
Check with `ads_check` once `feel.eye_relief` is set.

**Open questions:**
1. Refill timing: §22.1 gives fuel and the refill sources but no `reload_*` timing. Is the refill instant on
   pickup/purchase (and then the animation is cosmetic, ~1.5 s, gun lowered), or a timed refill like the
   flamethrower's 3.8 s?
2. Does the flask need its own hitbox tell for Reinholt's step-9 shield moment? (No for now: the cone is VFX.)
3. Should the frost mask also drive the **player's** glove frosting while firing (arms shader)? Nice, but it is
   arms-pipeline work.

---

## 2. THE RETURN POLICY (`return_policy`), Helvetia Works' refund gun

**Pitch:** a sleek violet-enamel handset, half ticket punch, half telephone receiver, with a receipt roll in the grip.
Pull the punch lever, it *dings*, a receipt stub feeds out, and the target folds up into a violet seam and is gone.

**Lore tie-in:** WEAPONS.md §19.2 (stats, audio, flavor *"Unsatisfied? Return it. No receipt required."*);
LORE.md §9.3 "Helvetia Works: Return Policy" (the map shares the name; the squad is itself "returned to sender");
FINEPRINT_LORE.md §1.4 (Product **localizes** everything Darkmatter sells, "Swiss enamel and swing jingles for 1940s
Europe"). The gun is Darkmatter merchandise localized as a Swiss office appliance, which is why it looks like a
1940s enamel telephone. **Writer rule:** no Gravelight character learns the words "Darkmatter" or "subscription".
The model may carry the closed-circle mark and a plan-ID stencil (the channels LORE §2.4 allows), but no slogan
text.

**Silhouette:** a pistol whose top is a telephone receiver: a round **earpiece cup facing the player** at the back, a
straight enamel bar, and a **bell-mouthed mouthpiece grille** at the front, set on a thick round grip (the roll
housing). A long conductor's-punch lever sits under the bar instead of a trigger guard, and a short cut cord hangs
from the grip butt. It reads as "a phone you hold like a gun", round where every other gun is square.

```
   muzzle (-Z)                                      eye (+Z)
        bead            _____________ Slide (punch hood) _ notch
     .--o--.  _________|_____________________________|_n_  ___
    ( grille)=[  ·RÜCKGABE·RETOUR·RETURN·  (·) mark   ]=( Dial )  <- earpiece cup
     '-----'  ~~~~\________punch lever_____  |slot|tear ]  '---'
                                           \ |  ||roll| |
                                             |  ||    | |   grip = roll housing
                                             |__'----'__|
                                                 |~|  cut cord + ferrule
```

**Real dimensions:**

| | |
|---|---|
| Overall length | **0.25 m** (earpiece face z +0.075 to grille face z -0.19) |
| Grip to muzzle | **0.19 m** |
| Bore line | y +0.045 (the handset bar's centre) |
| Height | 0.22 m with the cord stub (0.18 m without) |
| Width | 0.068 m across the mouthpiece |
| Weight feel | **~0.9 kg**, lighter than the M1911 and a touch nose-heavy from the mouthpiece; it snaps to the eye (WEAPONS §19.2: ADS 0.20, sway 0.15, move 1.00) |

**Materials:**

| Part | Family | Roughness / metal | Notes |
|---|---|---|---|
| Body, cups, grip housing | **vitreous enamel on steel** (not in the bible's table: treated as glass-on-metal) | 0.22–0.32 / 0 | deep violet-grey albedo `#3E3248` (saturation 0.31, under the 0.35 cap); chips at the edges show steel (metal 1, from the edge-wear mask). The violet comes from the lit Nachtglas lens reflecting in the gloss, not from the albedo |
| Trim, hood (Slide), lever, grille, tear bar | gun metal (nickel-chrome) | 0.25 / 1.0 | the family's lowest roughness; finger-smudge breakup in the ORM |
| Grip panels | phenolic resin (black) | 0.40 / 0 | value 0.06, fine moulding seams on the normal map. The resin is never named by a brand on any decal |
| Receipt roll and stub | paper | 0.90 / 0 | `PAPER #EDE3CC`, printed with a faint grid and a stamped tally `ǂ`; no words |
| Lens behind the grille | **Nachtglas** | 0.08 / 0 | body `#14081F`, emission `#8C33FF` at 2 idle, flaring to 4 on a return |
| Logo inlay | brass | 0.30 / 1.0 | the hairline crack in the circle |
| Cord | cloth-braided rubber | 0.85 / 0 | dark brown braid on a normal map; brass ferrule 0.3 / 1 |

**Markings:** the Darkmatter mark (FINEPRINT_LORE §1.1: a closed circle with one hairline crack) **embossed tone-on-tone**
in the enamel on the left flank, its crack a thread of brass. It is never painted in Darkmatter's own brand violet
(`#c07dff`, see the contradictions at the end). Swiss trilingual enamel-sign lettering in cream along the bar:
**"RÜCKGABE · RETOUR · RETURN"**. A tiny plan-ID stencil under the enamel on the grip base (open question 2). The
transaction counter in the earpiece window shows the round count as numbers on a drum.

**Texture plan:** one 2K set. The gun is small (~0.08 m² unwrapped), so at 1024 px/m it fits in 512 px. The 2K set
spends the spare on the enamel's surface (orange-peel normal, chip mask, the embossed mark) at ~4× density, because
this is a pistol held close and the gloss shows everything. The Crucible bits share the sheet.

**Named parts (GLB nodes):**

| Node | Pivot | What drives it |
|---|---|---|
| `Mag` | the roll cartridge's base cap (0, -0.095, 0.015) | holder reload kind **`pistol`**: out along -Y over p 0.06 to 0.22, hidden at 0.24, the new roll seats at 0.72 to 0.8 (the receipt roll and its spool) |
| `Slide` | the punch hood's centre (0, 0.07, -0.03) | holder blowback: +Z 0.03 m over 0.07 s per shot, **locked back when the mag is empty**, racked on an empty reload (p 0.84 to 0.97). It carries the rear notch (`sight_rear_on` = Slide) |
| `Trigger` (**new**, the OGA guns' name) | the lever's front pivot (0, 0.02, -0.09), axis X | the punch lever squeezes up 12° on each shot; needs the shot hook (the pack guns' `Trigger` nodes are static today) |
| `Receipt` (**new**) | the slot on the right flank (0.02, 0.03, 0.0) | a paper stub scales out +X 0–15 mm per shot and resets on reload; the left hand **tears it off at the tear bar** at the start of the reload (WEAPONS §19.2 "it tears off a receipt") |
| `Dial` (**new**) | the earpiece window (0, 0.045, 0.076), axis Z | the counter drum = rounds in mag (cosmetic; can be a texture-offset uniform instead of geometry) |
| `Muzzle` | (0, 0.045, -0.19) | the refund beam's origin; the fold VFX plays on the target, not here |
| `LeftHand` | (-0.006, -0.042, 0.052), `lh_axis` "y", radius 0.03 | the Ashlight's two-hand cup round the grip |
| `SightPoint` / `FrontSight` | (0, 0.085, 0.045) on the Slide / (0, 0.085, -0.16) | see the sight picture |
| root metas | `reload` = `"pistol"`, `length` = 0.25 | |

**Animation beats:**

| Beat | What happens | Timing |
|---|---|---|
| Draw | it comes up "answering a call": a quick roll of the wrist, the lens wakes from dark to idle glow, a soft *ding* | `SWAP_TIME` 0.42 s × `draw_mult` (code) |
| Idle | the lens breathes (emission 1.8 to 2.2 over 4 s); every ~8 s the counter drum clicks over one digit and back (a tic, not information) | cosmetic |
| Fire | the lever squeezes, the hood blows back, the lens flares, a receipt stub feeds out a little further, and there is a small kick with no muzzle flash (a violet lens flash instead) | timing from data: `return_policy.rpm` = 100 (§19.2; 0.6 s between shots), `mode` semi; blowback 0.07 s (holder) |
| On a return | (target-side VFX) the target folds into a violet seam; on the gun, the lens dims for 0.2 s as if "processing" | |
| Boss hit | the red *RÜCKGABE ABGELEHNT* stamp VFX at the target; the lens flickers red-violet once | §19.2 |
| Reload | the left hand **tears the receipt stub off** at the tear bar (p 0 to 0.06), the roll cartridge drops from the butt, a fresh roll goes in, and on an empty reload the thumb racks the hood | timing from data: `return_policy.reload_partial` 2.2 / `reload_empty` 2.8 (§19.2); the holder's `pistol` phases |
| Inspect | (no inspect system yet) turn it over: the embossed mark catches the light, the thumb rubs the brass crack, the counter clicks | wanted |

**Sound beats:**

| Beat | Existing key (stand-in) | Wanted key |
|---|---|---|
| Fire | `gun_pistol` (stand-in) | `fire_return_policy`: a cash-register *ding* over a soft punch-clack (§19.2) |
| Return (target) | | `return_policy_fold`: a soft reversed whoosh as the seam closes (§19.2) |
| Scrip for a return | `scrip_tick` / `ui_scrip` | |
| Boss refused | | `return_policy_refused`: a rubber-stamp thud and a sour bell |
| Reload | `reload_mag_out` (p 0.08), `reload_mag_in` (p 0.74), `reload_bolt_fwd` (p 0.93 empty), via RELOAD_CUES `pistol` | `return_policy_tear` (paper tear, p ≈ 0.04, §19.2), then swap the mag keys for `return_policy_roll_out` / `_roll_in` |
| Dry | `gun_dry` | |
| Draw | `weapon_raise` | `return_policy_ding_soft` |
| No Questions Asked chain | | `return_policy_ding_chain`: descending *dings*, one per chained return (§19.2) |

**Crucible version: "NO QUESTIONS ASKED"** (`return_policy_up`, §19.2: threshold 12 000, chains to 4 within 7 m,
12 / 72, 110 RPM, reload 2.0 / 2.5). Same mesh:
- **Material:** the Nachtglas vein camo in the enamel (the veins run *under* the gloss, like cracks in glazing); the
  chrome trim gets a faint violet tarnish in the cavity mask; the receipt paper becomes **heavy violet stock**
  (desaturated violet albedo `#4A3A5A`, value 0.3), an echo of the unsigned paper in Morgenrot's Mirror Room
  (LORE §9.3 Map 3).
- **Toggled bit:** `UpRing`, a thin Nachtglas ring round the grille (emissive 3), which the chain arcs leave from.

**Budget:** target **14 000 tris** (cups and grille 4k, body and hood 3k, grip, roll and cord 3k, lever, slot and
counter 2k, Crucible ring 0.5k), cap 35 000. One 2K set.

**Sight picture:** a shallow U-notch in the hood's rear (SightPoint (0, 0.085, 0.045), on the Slide so it rides the
blowback) and a chrome bead on the mouthpiece rim (FrontSight (0, 0.085, -0.16)). The sight radius is 0.205 m, like a
service pistol. In ADS the earpiece cup frames the bottom of the view as a dark round shoulder, and the bead sits
over the glowing lens. The grille stays below the line. Set `eye_relief` so the cup never clips the near plane.

**Open questions:**
1. Should the gun carry the Helvetia plate too (it is a crate weapon at Helvetia Works), or only the Darkmatter mark?
   The sheet says Darkmatter-only, because it is the barge's merchandise, not a factory product.
2. The plan-ID stencil: invent an ID (e.g. `DMS-RTN-01`) or leave it blank until JINGLES.md/FINEPRINT assigns one?
3. Should the cut cord swing on a spring bone? It is a lovely tell, but it costs a bone chain on a viewmodel that has
   none today.

---

## 3. THE KINDERHAMMER (`kinderhammer`), the Hammer's maul

**Pitch:** the inn's splitting maul: a well-oiled ash haft, a forged wedge head, and fine violet glints in the
hairline cracks of the steel. Swing it, or hold melee and throw it round a corner, and it comes back to your hand.

**Lore tie-in:** WEAPONS.md §23.1 (stats, the throw, Bolt's line *"...Oh, that's mine. Kind of."*
`BLT_KINDERHAMMER_01`, flavor *"Wood for Auntie."*); HOMAGE_BOSSES.md §4.3 (the Hammer: she drags it one-handed and
its head scrapes sparks; the head flares violet on the throw; death: she lays it across her lap); LORE.md §15.1
(%COUSIN_1_NAME% split the firewood with **the inn's splitting maul**; the inn was Lene Vogt's family's). The squad's
pickup lines all say the same thing about it: *"Somebody took care of this tool"* (Deacon), *"Well kept. She kept it
well"* (Vendelin). **It is a cared-for family tool, not a horror prop.** No blood is baked into it, nothing about
it is cute, and nothing about it mocks the Cousins.

**Silhouette:** a long straight haft with a heavy asymmetric head: a broad hammer **poll** on one side and a fat
**wedge** on the other, with twine whipping just under the head. It reads as "an axe that isn't an axe". In flight it
is a spinning cross with a violet streak.

```
        wedge   poll
      <|====[##]=|       head, edge toward -X (the swing's leading side)
           |~~|          twine whipping
           |  |
           |  |          ash haft, oval, oiled, pale where the hands go
           |  |  <- LeftHand (two-hand swing)
           |  |
           |  |  ||| three small notches near the butt
           |__|  <- origin: the right hand
           (__)  swell knob + leather thong
```
(Shown head-up for legibility; in the rig the haft runs along -Z with the head at the far end.)

**Real dimensions:**

| | |
|---|---|
| Overall length | **0.80 m** (the butt swell at z +0.12 to the top of the head at z -0.68; 0.83 m with the leather thong loop) |
| Grip to head centre | **0.64 m** (the right hand sits 0.12 m from the butt) |
| Head | 0.20 m edge to poll (edge at x -0.11, poll face at x +0.09), 0.075 m tall along the haft, 0.06 m wide at the poll |
| Haft | 0.035 × 0.028 m oval, the long axis in line with the head |
| Weight feel | **~3.6 kg** (a 2.7 kg head). Heavy on the wind-up, fast through the arc; the swing carries past the target and the arm has to haul it back. In flight it spins about its balance point (~0.5 m from the hand, near the head) |

**Materials:**

| Part | Family | Roughness / metal | Notes |
|---|---|---|---|
| Haft | raw wood (ash), oiled | 0.55 / 0 | the family's glossiest end; grain along the long axis; **hand-polished pale** at the grip and the left-hand spot, darker and oil-soaked near the head; one old split filled and glued |
| Head | gun metal (forged iron) | 0.45 / 1.0 | forge scale on the cheeks (rust mask, metal 0.2 there); the **edge** is filed bright (0.25 / 1); the poll face is mushroomed from years of driving wedges |
| Nachtglas in the head | **Nachtglas** | 0.10 / 0 | hairline cracks in the cheeks carry Nachtglas dust: emission **0 at rest**, pulsing 2–3 on the throw wind-up and in flight (HOMAGE_BOSSES §4.3, "the maul's head flares violet"); a new `glow` uniform on the shader, driven by the throw state |
| Iron and wood wedges | gun metal / wood | 0.5 / 1, 0.7 / 0 | visible on the head's top |
| Twine whipping | cloth (twine) | 0.95 / 0 | an overstrike guard, tarred dark |
| Thong | leather | 0.60 / 0 | a worn loop through the butt |

**Markings:** a burnt-in crossroads **✕** under the head, the inn's woodpile mark for Gasthaus Zum Kreuzweg (open
question 1); **three small knife notches** near the butt, one per cousin (no names: the names come from the Likeness
Sheet, and nothing is ever carved with them). No text at all.

**Texture plan:** one 2K set. It is long (0.8 m), but most of the surface is a thin haft, about 0.12 m² unwrapped,
so ~1K at 1024 px/m. The 2K spends the rest on the head (forge scale, the bright edge, the Nachtglas crack mask in a
separate emission-mask channel) and on the grip polish. The **thrown** copy (world space, third person) uses the same
GLB and textures, so there is one asset.

**Named parts (GLB nodes):** a melee weapon, so no contract part moves for a reload.

| Node | Pivot | What drives it |
|---|---|---|
| `Head` (**new**) | head centre (0, 0, -0.64) | static; it carries the `glow` emission mask, driven by the throw state (wind-up 0 to 1, flight 1, catch back to 0) |
| `Muzzle` | the blade edge's centre (-0.11, 0, -0.64) | the melee strike point (the knife's convention: Muzzle at the striking edge); trail VFX attach here |
| `Spin` (**new marker**) | the balance point (0, 0, -0.50) | the thrown copy spins about this; the boomerang path is code (§23.1: 20 m, one corner, out and back) |
| `LeftHand` | (0, 0, -0.30), `lh_axis` "z" | the support hand on the haft for the two-hand swing (the holder poses only the right hand for melee today) |
| `SightPoint` / `FrontSight` | none | melee: no ADS, not in `ads_check` |
| root metas | `reload` = `"none"`, `length` = 0.80 | |

**Animation beats:** the melee view model is only shown while swinging today (`_knife` in the holder); the Kinderhammer
needs a **held** pose because it replaces the melee for the match, and the throw needs its own beats (new holder work).

| Beat | What happens | Timing |
|---|---|---|
| Pickup | it is picked up off the floor where she toppled; the hand closes, it lifts, and the head's glow fades out | on the pickup event (HB1 `kinderhammer_pickup.gd`) |
| Draw / held | when melee is pressed it comes up from the right hip over the shoulder; nothing is held between swings (the current gun stays up), as with the knife | |
| Swing | a wide right-to-left sweep (edge leading, -X), a heavy follow-through, and the haul back | timing from data: §23.1 `swing` 0.75 s, `arc_deg` 100, `reach` 2.4, 3 targets; the hit lands at `swing - 0.13` (holder rule) |
| Throw wind-up (hold melee) | it is drawn back over the shoulder in two hands, the head glow rises, a short spin of the wrist | §23.1: 0.4 s wind-up |
| Throw / flight | a release snap; the empty hand stays open; the thrown copy spins about `Spin` with a violet trail, rounds one corner and comes back | §23.1: up to 20 m, one corner, 5 targets per pass |
| Catch | it smacks into the open palm from behind the player's view (a quick camera nudge); the glow fades; a 3 s cooldown | §23.1: caught automatically; 3 s before the next throw; downed thrower: it lands at their feet |
| Inspect | (wanted) the thumb runs over the three notches, and the hand turns the head to the light | |

**Sound beats:**

| Beat | Existing key (stand-in) | Wanted key |
|---|---|---|
| Swing | `knife_swing` | `kinderhammer_swing` (a heavy, low whoosh) |
| Hit | `knife_hit`, `impact_flesh` | `kinderhammer_hit` (a dull thunk with wood in it) |
| Throw wind-up | | `kinderhammer_windup` (the haft creaks; the glow hums) |
| Flight loop | | `kinderhammer_whirr` (positional spin; a doppler tell for the return, like the boss's) |
| Catch | | `kinderhammer_catch` (haft into the palm) |
| Pickup | `item_pickup` | then the character VO (`*_KINDERHAMMER_01`) |
| Drop on a bleed-out / downed throw | | `kinderhammer_drop` (a thud on floorboards) |

**Crucible version: none.** WEAPONS §23.1: *Crucible: Refused (melee)*. Classic Rules use the trench knife's stats
with no throw (and the trench knife's model). So no `_up` material and no toggled bits. The only state change on the
model is the throw glow above, which is lore (the Hammer's flare), not an upgrade.

**Budget:** target **9 000 tris** (head and wedges 4k, haft 2k, whipping, thong and knob 2k, notches and wedge 1k).
The thrown copy is the same mesh, so no LOD is needed (it is small and short-lived). One 2K set.

**Sight picture:** none (melee). For the throw, aim with the screen centre; the 0.4 s wind-up pose keeps the head
**out of the central 20 %** of the frame so the aim point stays clear.

**Open questions:**
1. The ✕ mark and the three notches: are they welcome? They are invented details, small and respectful, but they
   touch the homage (Devin's call).
2. Held pose: does it stay visible on the left side of the screen while held (a melee-slot weapon you *carry*), or
   only appear on a swing like the knife? The sheet assumes "on swing only", the cheaper option.
3. Bolt: §23.1 says it replaces his mallet. Does Bolt see the **same** model (yes, the sheet assumes so) and swing it
   with his mallet's animation set?
4. The boss rig's attachment bone is named `Mallet` (HOMAGE_BOSSES §3.4). The boss and the drop should share this GLB:
   the bone name can stay, the mesh is the maul.

---

## 4. BLARTZ'S FIELD-KIT OMNI-BLASTER (`omni_blaster`), Helvetia Works buildable

**Pitch:** Bolt & Sprocket's starting sidearm, rebuilt by hand in a 1945 Swiss factory from three alien parts and
whatever was on the QA bench: hose clamps, a bent bracket, friction tape, and the courier case's own label taped
round the grip.

**Lore tie-in:** WEAPONS.md §19.3. The parts come from Blartz's dented courier case, *"BLARTZ — FIELD KIT — IF FOUND,
RETURN TO BLARTZ (REWARD: GRATITUDE)"*, which burst open across the factory when his delivery pad misfired (LORE.md
§3, 17–18 Mar 1945; BRIEF.md §10.5, the Ch. 4 ending). The parts are the **grip** (`ob_part_grip`, HW_DOCK), the **heat coil**
(`ob_part_coil`, HW_LAB) and the **emitter barrel** (`ob_part_emitter`, HW_QUAY), assembled at the QA bench in
HW_ASSEMBLY. BS_WEAPONS.md §8.1 gives the original's look language (heat fins, a heat gauge on top, an orange-hot
muzzle ring, gold Ω fins) and the Forge's (squat, Blartz-green with gold trim, exposed coils, taped warnings).
Flavor: *"Somebody's sidearm from a very long way off. It runs hot. So did he."*

**Silhouette:** a chunky, short pistol with a **fat ring of exposed coils** round the barrel root, a slim ringed
emitter tube ending in a flared muzzle ring, a deep square grip, and visible **clamps and a strap bracket** where the
parts don't quite agree. It is the only Gravelight gun that looks *assembled* rather than manufactured, which is the
point: the three parts are three different materials, joined by Swiss hardware.

```
   muzzle (-Z)                                      eye (+Z)
        blade        Cover (vent shroud, hinged rear)   notch
     _   |     ____________________    ______Slide_____n_
    | |==[]==[]=|  (((( COIL ))))  |==|   receiver       |
    |_|  emitter|__clamp__bracket__|clamp  (gauge)       |
    ring  rings                       |trigger |  label  |
                                      '--------|  tape   |   grip (alien, finger-grooved)
                                               |__trim___|
                                                  [GEPRÜFT tag]
```

**Real dimensions:**

| | |
|---|---|
| Overall length | **0.32 m** (slide rear z +0.05 to the muzzle ring face z -0.27) |
| Grip to muzzle | **0.27 m** |
| Bore line | y +0.04 |
| Coil ring | Ø 0.066 m round the emitter root, z -0.10 to -0.17 |
| Height | 0.19 m; width 0.066 m at the coil |
| Weight feel | **~1.4 kg**: chunkier than the M1911, the coil ring putting the weight forward of the hand; quick and point-and-shoot (§19.3: ADS 0.18, sway 0.15, move 1.00) |

**Materials:**

| Part | Family | Roughness / metal | Notes |
|---|---|---|---|
| Grip and receiver shell (Blartz's) | painted metal | 0.35 / 0 (paint), 1.0 at chips | **desaturated Blartz green** `#4D5A4A` (saturation 0.2): his bright green would break the palette, so it is a sun-faded, grimy version (see the contradictions); finger grooves sized for Bolt but fine for anyone |
| Trim ("gold") | brass | 0.30 / 1.0 | the B&S gold, read as brass in this light |
| Heat coil | copper | 0.30 / 1.0 | **incandescent emission by heat fraction**: none below 30 %, then hearth `#FF8C33` rising to near-white `#FFCC8C` at 100 %, strength 0 to 3. Heat glow is "fire" in the bible's emissive list (§8), not a new accent |
| Emitter tube and rings | ceramic (insulator) + brass | 0.40 / 0, 0.30 / 1 | cream ceramic `#CFC6B0`, scorched dark toward the muzzle |
| Muzzle ring | gun metal (heat-blued) | 0.35 / 1.0 | a straw-to-blue temper gradient in the albedo |
| Hose clamps, bracket, screws (Helvetia's) | gun metal (zinc-plated steel) | 0.45 / 1.0 | crisp, new, very obviously Earth hardware |
| Friction tape | cloth | 0.92 / 0 | black, frayed |
| Courier label, QA tag | paper / card | 0.90 / 0 | the label in Blartz's printed type; the tag is stamped **"GEPRÜFT"** in violet-grey ink |

**Markings:** the courier label (text above, verbatim from §19.3) wrapped round the grip under the tape; a B&S
pictogram hazard sticker on the coil cage (a flame-in-triangle pictogram, no words); the Helvetia QA tag on a string
from the trigger guard. No Helvetia plate and no Darkmatter mark: this gun is the one thing on the map neither
company owns.

**Texture plan:** one 2K set. About 0.1 m² unwrapped, so ~640 px at 1024 px/m. The 2K gives the coil cage, label and
receiver flank (what the camera sees) ~3×. The coil's emission is a mask channel times a heat uniform, not a second
texture.

**Named parts (GLB nodes):**

| Node | Pivot | What drives it |
|---|---|---|
| `Slide` | the top bar's centre (0, 0.065, -0.02) | holder blowback, 0.03 m over 0.07 s per shot. The mag never reaches 0 (infinite ammo), so it never locks. It carries the rear notch |
| `Cover` | the vent shroud's rear hinge (0, 0.072, -0.105), axis X | **opens during the overheat vent**: `rotation.x` up ~35° and back. That is a **new** holder kind, `vent` (the `belt` kind is the only Cover user today), and it is the vent Overclock Cordial counts as a reload (§19.3, §20.2) |
| `Gauge` (**new**) | the glass heat tube on the left flank (-0.021, 0.035, -0.04) | the heat fraction (`w.heat`) as a shader uniform on the tube's inner core; the coil's emission uses the same value |
| `Muzzle` | (0, 0.04, -0.272) | hitscan origin; the Hot Round's bigger flash |
| `LeftHand` | (-0.006, -0.042, 0.052), `lh_axis` "y", radius 0.03 | two-hand cup round the grip (the Ashlight's) |
| `SightPoint` / `FrontSight` | (0, 0.083, 0.035) on the Slide / (0, 0.083, -0.25) | see the sight picture |
| root metas | `reload` = `"vent"` (new; `"none"` until the holder supports it), `length` = 0.32 | |

**Animation beats:**

| Beat | What happens | Timing |
|---|---|---|
| Draw | it comes up with a rising whine as the coil wakes (a dull red flicker), and the QA tag swings | `SWAP_TIME` 0.42 s × `draw_mult` (code) |
| Idle | the coil ticks as it cools, the tag sways with the bob, and heat shimmer sits above the coil while heat > 30 % | cosmetic, scaled by heat |
| Fire | the slide kicks, the coil brightens a step, and a small white-orange bolt flash (no violet) | timing from data: `omni_blaster.rpm` 360 (§19.3; 0.167 s), semi; `heat_per_shot` 6 % |
| Alt: Hot Round | needs heat ≥ 40 %: the coil flares white, the Cover pops a crack, a heavy recoil roll, and the heat dumps to 0 (the coil goes from white to dark red over 0.4 s) | timing from data: `omni_blaster.alt` (§19.3: 5000 × heat fraction, consumes all heat) |
| Overheat / vent | at 100 % the shroud flips open, steam and shimmer pour out, the gun dips, and the left hand fans it once (a Bolt-and-Sprocket beat played straight) | timing from data: §19.3 vent **1.0 s** (`omni_blaster.vent_seconds` or the heat block's key; 0.8 s on Field Promotion) |
| Cooling | the coil fades with the heat bar; the Cover shuts on its own when the vent ends | §19.3: −35 %/s after 0.4 s without firing |
| Reload | **none**: infinite ammo; the vent is its reload (Overclock Cordial, §19.3) | |
| Inspect | (wanted) turn it to read the label, then flick the GEPRÜFT tag | |

**Sound beats:**

| Beat | Existing key (stand-in) | Wanted key |
|---|---|---|
| Fire | `gun_pistol` (stand-in) | `fire_omni_blaster`: a bright *zap-thump*, B&S-ish but recorded in a cold room |
| Hot Round | `perk_overclock_burst` (stand-in) | `omni_blaster_hot_round`: a rising whine and a heavy crack |
| Overheat | **`weapon_overheat`** (the holder already plays it on the overheat edge, and the Cordial vent hook is there) | |
| Vent | | `omni_blaster_vent` (a steam blast), `omni_blaster_cover` (the shroud clank) |
| Heat loop | | `omni_blaster_heat` (the coil whine, pitch by heat, very quiet) |
| Cool ticks | `casing_tink` (stand-in) | `omni_blaster_tick` |
| Field Promotion fork | `wire_zap` (stand-in) | `omni_blaster_fork` (a small spark crack at the bystander) |

**Crucible version: "FIELD PROMOTION"** (`omni_blaster_up`, §19.3: 520 dmg, 400 RPM, +4 %/shot, 0.8 s vent,
`overtime_lite`). Same mesh:
- **Material:** the Nachtglas vein camo over the green paint and the ceramic; the clamps stay plain (the Earth parts
  are not "promoted").
- **Toggled bits:** `UpFins`, four brass heat fins along the emitter (a nod to the B&S V2 / Ω gold fins, here
  brass); `UpCore`, a violet Nachtglas core inside the coil (emission 2 to 3) whose glow mixes with the heat glow,
  which the every-5th-shot fork visibly leaves from.
- The B&S **"Ω OVERTIME — NO BREAKS"** stencil belongs to the Omega tier (§19.3, §17.1), not the Crucible. If Omega
  ever gets a look, it is a decal on the same receiver.

**Budget:** target **16 000 tris** (coil and cage 5k, emitter, rings and muzzle 3k, receiver, slide and grip 4k,
clamps, bracket and tag 2k, Crucible fins and core 1.5k), cap 35 000. One 2K set.

**Sight picture:** a square notch on the top bar (SightPoint (0, 0.083, 0.035), on the Slide) and a brass blade
**hose-clamped** to the muzzle ring (FrontSight (0, 0.083, -0.25)). The sight radius is 0.285 m. In ADS the coil ring
fills the lower third of the view and glows by heat, so the player reads the heat without the HUD bar. The blade
sits just above the coil's top, and the shimmer above the coil sits right in the sight line when hot: **cap the
shimmer's opacity under ADS** so it never hides the target.

**Open questions:**
1. Holder support: the `vent` reload kind (Cover + left-hand fan) and the `Gauge` uniform are new. Fold them into the
   holder or into a small `omni_blaster.gd` like `totenglocke.gd`?
2. Should the three parts show their seeded pickup spots (forklift-seat oil on the grip, lab frost on the coil, river
   damp on the emitter)? It is cheap as a decal, but it varies per seed, so it would need a per-part decal swap.
3. Is Blartz's green allowed at full B&S brightness here as a deliberate "this thing isn't from here" tell? The sheet
   says no (palette rule) and uses the faded green.

---

## 5. Contradictions and loose ends found in the source docs

1. **Kinderhammer: mallet or maul.** UPDATE_05 §2 calls it "the Cousins' mallet", and HOMAGE_BOSSES §2 and §3.4 say
   the Hammer "carries a mallet" and give her a `Mallet` attachment bone; the move is the "Mallet Throw". LORE §15.1,
   WEAPONS §23.1 and every pickup VO line say **splitting maul**. The sheet models the **maul** (the canon object)
   and keeps the bone name. It is also only the Hammer's (Cousin 1's), not all three Cousins'.
2. **Where our assets live.** ART_BIBLE §9 step 3 says "our own work goes under `assets/gravelight/<kind>/`"; the
   built pipeline (and `assets/ours/arms/`) uses `assets/ours/wonder/<id>/`. The sheet follows the pipeline in use.
3. **Darkmatter's brand violet vs the single accent.** FINEPRINT_LORE §1.1 gives Darkmatter `#c07dff` violet with amber
   `#ffb347` cracks; ART_BIBLE §2 allows one saturated accent, Nachtglas `#8C33FF`, and caps everything else at
   saturation 0.35. The Return Policy ("violet enamel") is therefore a low-saturation violet-grey enamel with
   Nachtglas emission only in the lens, and the mark is tone-on-tone with a brass crack, not amber.
4. **Blartz green.** BS_WEAPONS §2.4 (the Forge) and the B&S look language are Blartz-green with gold; in Gravelight
   that breaks the same rule. The sheet uses a faded green and brass.
5. **Die Lange Nacht has no reload timing.** WEAPONS §22.1 gives 80 fuel units and two refill sources, but no
   `reload_*`. The refill animation cannot take its timing from data until the entry exists.
6. **The Kinderhammer has no melee data entry and no Crucible.** `weapons.json` `melee` has only `trench_knife`,
   `etool` and `coal_shovel`; §23.1's numbers will need a `kinderhammer` entry (with `swing` 0.75 and so on) plus
   throw keys. "Crucible: refused" means its sheet has no Crucible version.
7. **(Side note)** Sankt-Elmsfeuer's procedural model sets `reload` = `"crank"`, which `_animate_reload` has no case for
   (it falls through to no part motion). That may be intended (the crank is driven elsewhere), but it is worth a look.
