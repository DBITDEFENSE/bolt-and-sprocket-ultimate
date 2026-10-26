# UPDATE 05 — "LOOK THE PART": make Crossroads Inn look like a real game

A work order for the existing project. All rules from `ULTIMATE_PROMPT.md`, v2, v3, `OVERNIGHT_RUN.md`, and Updates 02–04 (all in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`) still apply. Work unattended per OVERNIGHT_RUN.md: branch per section, `master` always launches, commit often, keep the `PROGRESS.md` resume line current, update `Play.bat`, and finish with a morning report.

## Why this update
The systems are deep: three playable maps, the campaign chain, bots, homage bosses, the minimap, 850+ tests. But everything on screen is still **greybox primitives**:
- the squad, the Cousins, and the zombies are box-figures with flat faces;
- the M1911 viewmodel is a box in a box hand;
- the inn reads as untextured shapes, and the trees are cones.

The lighting is already good. **This update makes one map, Crossroads Inn, look finished**, so every later map has a proven art pipeline and quality bar to copy.

## 0. RULES FOR THIS UPDATE
1. **Feature freeze.** No new gameplay features this run. Only art, animation, VFX, UI readability, and the bugs the art work exposes. Any gameplay idea goes into `ROADMAP.md` as a note.
2. **Licensing stays strict** (v1 §0.6): only CC0, our own original work, or assets whose license explicitly allows use in a commercial game. CC-BY is OK **with** a credit line. **Never** CC-NC or "editorial use only." Never anything ripped from a commercial game, including the Call of Duty games I own.
   - Every third-party file lives in `/assets/third_party/<source>/<pack>/` next to its `LICENSE.txt`, and gets a row in `docs/ASSETS.md` (source URL, author, license, credit text, files used).
   - **Add a GUT "license gate" test** that fails if any imported model, texture, or sound under `/assets` lacks a license row. No asset ships without paperwork.
3. **One consistent style:** **stylized-realistic, late-2000s round-based zombies** (readable silhouettes, grimy, slightly exaggerated proportions, hand-painted plus PBR). Not photoreal and not low-poly cartoon. Write `docs/ART_BIBLE.md` first, with the palette, material rules, scale (1 unit = 1 m, door 2.1 m), poly and texture budgets, texel density, and naming. Every asset must match it. Bolt & Sprocket keeps its own bright cartoon style; don't touch B&S this run.
4. **Gameplay doesn't move:** swapping visuals must never change collision, hitboxes, navmesh, buy prompts, or timing. Gameplay scenes reference visual subscenes (v1 Appendix A §A14), so the swap happens there. Re-run every test and smoke after each section.
5. **Performance:** 60 FPS on the High preset at round 15 with 3 bots + Jakub + 24 zombies.
   - Use LODs, impostors for distant trees, compressed textures (VRAM-compressed, with mipmaps), MultiMesh for repeated props, and shared materials.
   - **Rendered on-screen runs are approved for this update.** A Godot window may open for screenshots, clips, and the frame-rate check.

## 1. TOOLCHAIN & PIPELINE
- **Blender for scripted modelling:** install Blender if missing (`winget install BlenderFoundation.Blender`) and drive it headless (`blender -b -P script.py`).
  - **Prefer downloads over modelling everywhere:** for props, furniture, and environment pieces, first look for a CC0 or licensed asset (Poly Haven, Kenney, Quaternius, ambientCG, or a pack Devin supplies).
  - Build by script only what has no good download: our fictional, lore-specific items (the perk-machine cabinets, the Mystery Crate, the Ledger-era radio, the Crucible, the Armorer's Bench, signs and plaques with our text, and the wonder weapons in §2). Use proper bevels, real UVs, baked AO/curvature, and PBR texture sets.
  - **Never model real-world guns** (see §2).
  - Keep every generator script in `tools_src/blender/` so assets can be regenerated and tweaked from data.
- **Material library:** CC0 PBR materials (ambientCG, Poly Haven) for wood planks, rough plaster, fieldstone, roof shingles, wrought iron, canvas, wool cloth, leather, snow, ice, and frozen mud. Wrap them in a small set of shared `StandardMaterial3D`/shader templates (`/assets/materials/`) with grime, wetness, and frost-edge parameters.
- **Characters:** start from CC0 or game-licensed humanoid base meshes and rigs. Check Quaternius, Kenney, and Poly Haven first; Mixamo characters and animations are free for games but need my Adobe login (see §8). Retarget onto the MZ shared skeleton (v2 §7.1) so every existing animation and custom bone (the Reach, Alix, Paul's stages) keeps working.
- **Import presets:** one Godot import preset per asset type (character, prop, weapon, foliage, texture), plus a `tools/asset_report.gd` that lists each asset's tris, materials, texture memory, and LODs. Run it in the morning report.
- **Same-camera before/after capture:** extend `tools/capture` with a fixed list of ~20 camera positions on Map 0 (taproom, bar, stairs, upstairs rooms, stable, hayloft, cellar, cage, yard, wreck, road, field edge, and close-ups of a zombie, the squad, and the viewmodel). Capture them **before any change**, then after each section, into `morning/screenshots/u05/<section>/`.

## 2. FIRST-PERSON VIEWMODEL (what the player looks at 100% of the time — do first)
- **Arms:** real arm and hand meshes with sleeves and gloves **per character** (Dutch's Ranger field jacket and leather gloves, Peg's SOE smock cuffs, Deacon's coverall sleeves and bare hands, Wren's wool sweater and fingerless gloves, Bolt's mechanic gloves, Vendelin's brass hands) on a proper viewmodel rig.
- **Conventional guns are DOWNLOADED, not modelled.** Devin is buying or downloading licensed WW2 weapon packs (see `ASSET_SHOPPING_LIST.md` in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`) and will drop them in `/assets/user_supplied/weapons/<pack-name>/` with the license or receipt. **Do not spend time modelling any real-world gun.** Your job with them is **intake**:
  1. **Unpack** whatever arrives: FBX/GLB/Blend directly; `.unitypackage` by extracting the tar contents; Fab downloads in their FBX/GLB format. Copy the license text into `LICENSE.txt` and add the `ASSETS.md` rows.
  2. **Map each model to its weapon id** in `weapons.json` (`m1911`, `thompson`, `kar98k`, … all 22 conventional guns). Write the mapping in `data/gravelight/weapons/models.json`. Any gun with no model yet keeps its greybox (and is listed in the morning report).
  3. **Normalize:** scale to metres, a forward axis matching our rig, the pivot at the grip, and LODs. Run the materials through **one shared weapon shader** (wear, grime, wood-grain response, frost in cold maps) so guns from different packs look like one set.
  4. **Place `SightPoint`, muzzle, ejection port, magazine, and hand markers** on every model, then **re-run `tools/ads_check`** until all guns and attachment combos line up.
  5. **Animations:** if a pack ships first-person arms and animations, **retarget them onto our viewmodel rig** and our per-character arms. Keep our existing timings (reload, sprint-out, sprint reload T-083) by time-scaling the clips; never change gameplay timing to fit an animation. For anything a pack lacks, author it on our rig: start with reload, ADS, sprint, and draw.
  6. **Crucible versions are a material, not a model:** the violet-amber Nachtglas vein camo shader on the same mesh, plus small attached bits (a glowing core, wraps) where a Crucible weapon's lore needs it.
  7. **Attachments:** M1911/Armorer's Bench parts (drum, compensator, suppressor, stock, sights) can be modelled by script in Blender when the downloaded pack doesn't include them. They're small, simple parts that must fit our hand and sight markers.
- **Claude models only the WONDER WEAPONS and our fictional items**, each from scratch in Blender (`tools_src/blender/wonder/`), at hero quality because they're the stars:
  - **Ashlight:** brass-and-glass energy pistol, with Fasbender's hand-made look (exposed coils, a glass chamber with violet Nachtglas fluid, rivets, a leather-wrapped grip). The Crucible version "Ashlight Corona" adds a halo ring and brighter fluid.
  - **Totenglocke:** a hand-cranked bronze bell cannon on its frame, built from the three map parts (the bell, frame, and crank show their origins). The crank and bell must animate for the tap, wind-up, Great Toll, Bell Dome, and the crank-reload. The Crucible version "Mitternacht" gets midnight-blue patina and violet runes.
  - **Sankt-Elmsfeuer:** Totenhafen's wonder weapon, per its existing design data. Read its entry in WEAPONS.md and build the look from its lore.
  - **Later wonder weapons** get a design sheet now and are built with their maps: **Die Lange Nacht** (Morgenrot LOX cryo-lance), **The Return Policy** (Helvetia Works Darkmatter refund-gun), **Kinderhammer** (the Cousins' mallet), and **Blartz's Field-Kit Omni-Blaster**.
  - **Tactical:** the Siren Gramophone (a wind-up portable gramophone with a crank and a spinning record).
  - Each gets full first-person animations on our rig, its own sounds hooked to animation events, and a turntable render for the report.
- **Acceptance:**
  - every gun that arrived is mapped, normalized, and aligned; ads_check passes for every gun and attachment combination;
  - reload timings unchanged (test);
  - before/after viewmodel shots per gun;
  - turntable and in-hand shots of Ashlight, Totenglocke, Sankt-Elmsfeuer, and the Gramophone;
  - `docs/WEAPON_MODELS.md` lists each weapon's source pack, license, and whether its animations are from the pack or ours.

## 3. ZOMBIES
- Replace the box-figures with real **base meshes**: male and female bodies in 3 builds, with faces: sunken eyes with the violet glow, slack jaws, frostbitten skin.
- Keep the **outfit kits** (v2 §7.6) as real clothing meshes: villagers in coats and scarves, Wehrmacht greatcoats with a fictional insignia (v2 `ART_FACTIONS.md`), patrol helmets, and work clothes.
- Keep the **dismemberment pieces** with stump caps, the **infection shader** (pulsing veins, crystal cracks that grow with round), and the gore setting.
- All MZ animations must play on the new meshes: run `smoke_zombie_anim` (foot-slide ≤ 5%, climbs, knockdown, deaths/ragdoll) and fix the retargeting until it passes.
- **Acceptance:** zombie close-ups (front, side, damaged, crawler, ragdoll) before/after; smoke_zombie_anim passes; 24 zombies at 60 FPS.

## 4. THE PEOPLE: squad, Jakub, the Map 0 patrons and survivors, the Cousins
- Real character models for **Dutch, Peg, Deacon, Wren** (bots and third-person views), **Jakub**, the Map 0 patrons and the three upstairs survivors (T-076/T-077), and **The Cousins** (v3 §2: modest period clothing, creepy-doll horror, never sexualized).
- Each needs a face that sells emotion at bot distance (eyes, brows, simple blendshapes for blink, jaw, and a few expressions), driven by the existing VO for basic lip flap.
- Use the Likeness Sheet in `docs/HOMAGE_BOSSES.md` for the Cousins. Where a placeholder is still open, use the documented default and list it in the report.
- **Acceptance:** a character lineup shot (all four squad members, Jakub, the Cousins), plus in-game shots of the bots and of the Cousins round.

## 5. CROSSROADS INN ENVIRONMENT
- **Exterior:**
  - timber framing and plaster on the inn, a shingled roof with snow load and icicles, real window frames with frost and lit panes;
  - the stable with plank walls and a hay loft;
  - the yard wall in fieldstone, fences, the well, the inn sign, the chimney smoke;
  - the Grounds ring (T-080) with snow drifts against walls and tracks.
- **Terrain & nature:**
  - a snow terrain material with height-blended frozen mud and road ruts;
  - **real pine and birch models** with LODs and impostors, replacing the cones;
  - bare winter bushes, rocks, the frozen stream;
  - the distant mountains and forest layers kept, but textured.
- **Interior:**
  - textured plank floors and beams, plaster walls with wear and water stains;
  - a proper bar counter, shelves of bottles, tables and chairs, the fireplace with hearth stones and the antlers, framed pictures, curtains, the radio;
  - the upstairs bedrooms, the cellar's wine racks, coal cage, root and ice cellars.

  Every story prop from `MAP0_POLISH.md` gets a real model.
- **World objects:** perk-machine cabinets per the lore (each with its unique shape, sign, and bottle), the Mystery Crate, ammo boxes, wall-buy chalk outlines with the gun mounted, barricade boards, doors with price plaques, the Armorer's Bench, and the transport-plane wreck with its parachute.
- **Readability first:** buyables, windows, and doors must still read instantly. Check with the existing color-coding in a debug view.
- **Acceptance:** all ~20 before/after camera pairs; navmesh soak (10 min) with no new snags; FPS target met.

## 6. VFX & SMALL POLISH
- Muzzle flashes per weapon class, shell ejection with real casing models, impact decals per surface (wood splinters, plaster puff, snow spray, stone chips).
- Blood and Nachtglas spark hits on zombies, the shatter VFX, the Totenglocke ring distortion.
- Breath fog, falling snow with depth, firelight flicker, dust in light shafts, and fog volumes in the field.
- **Acceptance:** a 60-second gameplay clip on Map 0, round 8–12, with the squad, showing combat, a reload, a Crucible weapon, and the yard.

## 7. UI READABILITY PASS (Gravelight only)
- **One font family** with period flavor (an open-licensed typewriter/stencil for headers plus a clean readable face for body text), and consistent sizes.
- **HUD cleanup:**
  - the round stamp, Scrip, ammo, and perk bottle caps aligned on a grid, with a subtle drop shadow so they read on snow and in the dark;
  - real bottle-cap icons for all perks;
  - the minimap bezel art;
  - the boss bar and title-card art;
  - the hitmarker and crosshair cleaned up.
- **Acceptance:** HUD screenshots in the dark cellar and the bright snow, both readable.

## 8. THINGS ONLY DEVIN CAN DO
Write `morning/NEEDS_DEVIN.md` with short numbered steps for anything that needs my accounts or downloads, then **continue without it** using CC0 fallbacks. Example: "Log in to Mixamo, download these 12 animations as FBX for Godot, and drop them in `/assets/user_supplied/mixamo/`". Never wait on it.

## 9. FINISH
- Re-run the full suite: GUT (including the new license gate), every smoke, ads_check, the map-data check, the asset report, and the on-screen FPS check.
- Add `Play.bat` buttons: "Map 0 — art slice (round 1)", "Map 0 — art slice (round 12, 3 bots)", "Character lineup", "Weapon viewer".
- **Morning report:**
  - the before/after camera pairs (side-by-side), the 60-second clip, the character lineup, and the asset report summary (tris, texture memory);
  - FPS numbers, and each section marked works / partly / not started;
  - `NEEDS_DEVIN.md` items, and the decisions made;
  - **a short plan for rolling the same pipeline out to Kaltenbrunn and Totenhafen**: reusable assets, what's new per map, and an estimate.
