# ART_BIBLE — GRAVELIGHT's look (UPDATE_05 §0.3, DECISIONS T-088)

Short and prescriptive. Every asset that goes into `gravelight/` or `assets/` follows this page; where a work order
and this page disagree, this page wins until DECISIONS.md says otherwise. Bolt & Sprocket (`bs/`) has its own bright
cartoon style and is not covered here.

## 1. The style in one line

**Stylized-realistic, late-2000s round-based zombies.** Readable silhouettes first, grime second, detail last.
Proportions are slightly exaggerated (hands, heads, boots, hinges, bolts about 10% bigger than life), surfaces are
hand-painted-plus-PBR (painted albedo with real roughness and normal maps), nothing is photoreal and nothing is
low-poly cartoon. If a thing can't be told apart from 40 m away in fog by its outline, it isn't done.

Reference tone: a village inn at night in deep winter, 1944, five minutes after the dead came. Warm inside, cold
outside, and the only clean, saturated colour anywhere is the violet of Nachtglas.

## 2. Palette

The scene is lit, not painted: most colour comes from the lights, so albedos stay muted and mid-valued.

| Role | Value | Where it comes from |
|---|---|---|
| Interior lamplight (oil, candles) | `#FFA85C` (1.0, 0.66, 0.36) | gen_map00 `warm`; bulbs are whiter `#FFCC8C` |
| Hearth / wreck fire | `#FF8C33` to `#FF9442` | WreckGlow, WindowSpill |
| Moonlight (key light outside) | `#8099F2` (0.5, 0.6, 0.95) | the Moon DirectionalLight3D |
| Cold fill / sky ambient | `#384566` (0.22, 0.27, 0.40) | env.ambient_light_color |
| Night sky / fog | `#030408` background, `#121726` fog | env.background_color, fog_light_color |
| **Nachtglas violet** (the only saturated accent) | emission `#8C33FF` (0.55, 0.20, 1.0), glass body `#14081F` | Mats "nachtglas"; UI `VIOLET #9E73D9` |
| Snow albedo | `#D6DCE6` (never pure white) | snow_02 tinted 0.84 |
| Wood family | `#5A3E2A` (floorboards) to `#8C6A48` (new planks) | the CC0 wood sets, tinted darker |
| Plaster | `#B8A890` interior, `#8C8A82` upper storey | plastered_stone_wall, grey_plaster |
| Iron / steel | `#2E2C2A` with rust `#8A4A1E` | rusty_metal_04, weapon "blued" |
| Blood | `#4A0A0A` dried, `#8C1414` fresh | effects |
| UI ink / paper | `INK #9E1714`, `PAPER #EDE3CC`, `GOLD #F2DB8C` | menu_kit.gd |

Faction colour (docs/ART_FACTIONS.md): the Wiederkehr mark is **black** on raw metal, concrete or canvas; a thin
**red ring** only on Morgenrot launch-crew gear; **violet never** on the mark (violet is the Nachtglas's own).
Allies carry no insignia colours: plain cloth, stitched names. No real-world emblem anywhere.

Rules: no albedo darker than value 0.04 or brighter than 0.90 (black soot is 0.05, fresh snow 0.84); saturation
stays under 0.35 except Nachtglas, blood and the UI ink; the Crucible camo is violet-amber veins on the gun's own
material, never a recolour of the whole gun.

## 3. Materials

One shader family for the world: `assets/materials/shaders/surface_pbr.gdshader` (albedo + normal + ORM, optional
height, triplanar for untextured blocks) with three shared wear parameters every material exposes:

| Parameter | What it does | Default indoors / outdoors |
|---|---|---|
| `grime` 0..1 | darkens and roughens from a world-space noise mask, strongest at the floor and in corners (`grime_height`) | 0.35 / 0.5 |
| `wetness` 0..1 | darkens albedo, drops roughness toward 0.15, from the same mask (melt water, blood pools, the cellar) | 0.0 / 0.2 |
| `frost` 0..1 | a pale rim on up-facing surfaces above `frost_height`, blended by the world normal's Y | 0.0 / 0.6 |

Roughness ranges per family (read from the ORM map, then clamped by `rough_min/rough_max`):

| Family | Roughness | Metallic | Notes |
|---|---|---|---|
| raw / painted wood | 0.55–0.95 | 0 | boards run along the long axis; `uv_scale` = tiles per metre from the set's tile size |
| plaster, stone, brick | 0.75–1.0 | 0 | grime strongest here |
| iron, steel (world) | 0.35–0.8 | 0.9 (rust 0.2) | rust is an albedo+roughness mask, never a second mesh |
| gun metal (viewmodel) | 0.25–0.55 | 1.0 | the shared weapon shader (`assets/materials/shaders/weapon.gdshader`, T-089) adds bluing, edge wear, grime, frost; weapon rules: `docs/WEAPON_MODELS.md` "Viewmodel fit" |
| cloth: wool, canvas, burlap | 0.85–1.0 | 0 | no specular highlight wider than a thumb |
| leather | 0.45–0.7 | 0 | |
| snow | 0.6–0.9 | 0 | subsurface-ish: albedo lifted 10% in shadow via `frost` |
| ice, glass, Nachtglas | 0.05–0.25 | 0 | ice gets `refraction` off; Nachtglas is emissive 2–4 |
| skin (zombie, people) | 0.45–0.65 | 0 | the infection shader owns surface 0 of a zombie |

Texture conventions: albedo sRGB; normal **OpenGL +Y** (Godot's); ORM = R occlusion, G roughness, B metallic
(glTF's packing); height 8-bit. Every texture under `assets/` is imported VRAM-compressed with mipmaps
(`assets/import_presets/texture.cfg`); normal maps with the normal-map flag. 2K is the ceiling; props are 1K;
things smaller than a bucket are 512. Target texel density **512 px / m** for anything the player can touch,
256 px / m for the rest, 1024 px / m on the viewmodel.

## 4. Scale

1 unit = 1 m. Build to these and the player's capsule and the doors agree with you:

| Thing | Size |
|---|---|
| Player capsule | radius 0.35, height 1.80 standing / 1.10 crouched (player.gd) |
| Eye height | 1.62 standing / 1.00 crouched |
| Door | 2.1 m clear (the inn's frames are 2.4 to the lintel) |
| Counter / bar | 1.10 m; the wainscot rail 1.10 |
| Table | 0.75 m; chair seat 0.45 |
| Window sill / top | 0.9 / 2.2 m |
| Taproom ceiling | 3.5 m; upstairs 3.0; the stable 7.0 with the loft at 3.5 |
| Zombie | 1.75–1.95 m on the shared ZombieRig; crawler 0.7 |
| Rifle | 1.1–1.3 m long; the M1911 0.21 m; grip point at the model origin, barrel along −Z, +Y up |

Pivots: props sit on their footprint's centre at y = 0; hanging things pivot at the hook; doors at the hinge;
weapons at the firing hand's grip (`weapon_models.gd`'s frame).

## 5. Budgets

| Asset | Triangles | Textures | LODs |
|---|---|---|---|
| Viewmodel gun | ≤ 25 000 (hero ≤ 35 000 for the wonder weapons) | 2K set, 1K for attachments | none (always close) |
| Zombie body | ≤ 8 000 + ≤ 3 000 per outfit kit piece | one 2K atlas per kit | LOD1 at 15 m (50%), LOD2 at 35 m (25%), impostor crowd past 24 active |
| Hero character (squad, Jakub, the Cousins) | ≤ 15 000 | 2K body + 1K head | LOD1 at 20 m |
| Prop | 200–3 000 | 1K (512 small) | auto LOD (import preset) past 1 000 tris |
| Tree | LOD0 ≤ 4 000, LOD1 ≤ 1 200, impostor card past 60 m | 1K bark + 1K branch atlas | required |
| World block (generator) | whatever the box is | the material library, triplanar | merged by StaticBatches |

Frame budget (docs/gravelight/PERFORMANCE.md): 60 FPS on High at round 15 with 3 bots, Jakub and 24 zombies; the
scene is CPU-bound, so **draw calls and shadow casters** are what art spends, not triangles. Repeated props (bottles,
bales, fence posts, trees, casings) go through MultiMesh; everything static shares materials from the library so
batches merge; nothing new casts a shadow from an omni light unless it is bigger than a chair.

## 6. Naming

- Files and folders: `<kind>_<name>_<variant>` in lowercase snake case: `prop_crate_military`, `tex_floorboards_worn`,
  `char_zombie_villager_m`, `vm_arms_dutch`. Variants are `_a/_b`, `_broken`, `_snow`, `_lit`.
- Third-party folders: `assets/third_party/<source>/<asset-id>/` (kebab-case id, exactly the source's) with
  `LICENSE.txt` and `SOURCE.txt`; the generated manifest reads those (`python tools/assets_manifest.py`).
- Material keys (MaterialLibrary / `data/gravelight/materials.json`): plain nouns, `floorboards`, `planks`, `plaster`,
  `plaster_upper`, `fieldstone`, `shingles`, `iron`, `canvas`, `burlap`, `wool`, `leather`, `snow`, `ice`,
  `frozen_mud`, `dirt`. A map-specific variant suffixes the map: `plaster_map01`.
- Prop keys (`data/gravelight/props_library.json`): `barrel_wine`, `crate_wood_a`, `lantern_oil`, ... noun first.
- **GLB node names are a contract.** A weapon GLB (weapon_models.gd) names its moving parts `Mag`, `Bolt`, `Slide`,
  `Pump`, `Cover`, `Barrels`, `Crank`, `Rocket`, `Valve`, its points `Muzzle`, `LeftHand`, `SightPoint`, `FrontSight`,
  and its root carries the metas `reload`, `length`, `port`, `bore`, `grip_r`, `grip_r_radius`, `lh_axis`,
  `lh_radius`, `cylinder`, `scope`. A character GLB uses the Godot humanoid profile's bone names (ZOMBIE_ANIM_SPEC §1).
  A prop GLB's root is the prop; a `Collision` child is ignored (collision is the generator's job, UPDATE_05 §0.4).

## 7. Readability (keep what works)

Buyables, windows and doors must read before anything else in the frame, and they already do: wall-buys are chalk
outlines with the gun mounted and a price; doors carry a price plaque and the bought/locked colour; barricade windows
show their boards and the blue snow-light beyond; crate spots have the lantern; perk machines each have one unique
silhouette, sign and bottle; ammo boxes are the olive tin with the stencil. New art **keeps those shapes and colours**
and never puts a prop within 0.6 m in front of any of them (MAP0_POLISH.md's rule). Check with the dev console's
interaction colouring after every dressing pass. Nothing decorative is brighter or more saturated than a buyable.

## 8. Lighting is finished; art serves it

T-061's lighting stays: shadowed oil lamps inside, moonlight and window spill outside, SDFGI. Materials are authored
for that light: mid-value albedo, real roughness, no baked lighting in albedo, no emissive except lamps, bulbs,
fire, Nachtglas and the HUD. Frost and snow are material parameters, not white paint.

## 9. How to add an asset

1. **Licence first.** CC0, ours, or CC-BY with the credit line copied from the page. Never NC, editorial, NoAI,
   rips or anything from a commercial game. If in doubt, don't.
2. **Fetch into quarantine.** Each download in its own folder under `tools_src/_downloads/<name>/` (git-ignored);
   parse with `python -I`; never run anything from inside an archive. CC0 textures / Poly Haven props: add a line to
   `data/gravelight/art/cc0_assets.json` and run `python -I tools/fetch_cc0_materials.py` (re-runnable).
3. **Folder.** `assets/third_party/<source>/<asset-id>/` with `model.glb` or `textures/*.png`, `LICENSE.txt` (the
   licence text) and `SOURCE.txt` (Title / Authors / Source / File / License / Credit line / Format / Downloaded /
   Files used). Our own work goes under `assets/gravelight/<kind>/`.
4. **Normalise.** Metres, +Y up, forward −Z, pivot per §4, textures ≤ the budget in §5, normal maps OpenGL +Y, ORM
   packed. Blender headless scripts live in `tools_src/blender/`.
5. **Import preset.** Run `tools/apply_import_presets.sh` (headless; writes the `.import` files for new assets from
   `assets/import_presets/*.cfg`: `texture`, `prop`, `weapon`, `character`, `foliage`), then the editor import
   (`godot --headless --editor --quit-after 300`). `*.import` files are git-ignored in this repo, so the presets are
   the source of truth and every checkout regenerates them the same way.
6. **Register it.** A texture set → a key in `data/gravelight/materials.json`; a prop → `data/gravelight/props_library.json`
   (key, path, scale, pivot note, size); a weapon → `data/gravelight/weapons/models.json`.
7. **Manifest.** `python tools/assets_manifest.py` regenerates docs/ASSETS.md's third-party table and the in-game art
   credits from the SOURCE.txt files. Never hand-edit the generated section.
8. **Test.** GUT: `test_license_gate` (every file under `assets/` has its paperwork), `test_material_library` /
   `test_prop_library` (every key resolves and loads), then `tools/asset_report.sh` for the tris / texture-memory
   numbers, and the smokes your change touches (always `smoke_map00`).
9. **Look at it.** `tools/capture.sh` with `--set=u05 --label=<section>` renders the fixed camera list; compare
   against `before` with `python tools/compare_shots.py before <section>`.
