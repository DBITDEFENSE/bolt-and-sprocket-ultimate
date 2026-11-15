# T-252 (UPDATE 19): the maps' surfaces: snow, ground, walls, sky

Branch `claude/u19-textures`. The owner, 2026-11-14: "Make the textures for the maps higher quality ... snow sky ...
walls". An art pass on surfaces only: no collider, navmesh, timing, hitbox or prompt changed (the six regenerated
scenes compare SAME in `tools/look/layout_fingerprint.py`, and every node block is identical once resource ids are
blanked).

## How surfaces were made before (what the survey found)

- One shared world shader, `assets/materials/shaders/surface_pbr.gdshader` (world-space triplanar, albedo / normal /
  ORM from the CC0 library, grime / wetness / frost), fed by `data/gravelight/materials.json` through
  `MaterialLibrary`; `Mats.get_mat(key)` hands out the library material for the keys the json enables and a
  procedural one (256 px `NoiseTexture2D`, or a flat colour) for the rest.
- **Baked, not referenced:** every map scene holds its materials as sub-resources (`lib_<key>` ShaderMaterials with
  the textures and the shader as ext_resources). A change to materials.json reached a map only when its generator
  ran again; a change to the shader file or to a PNG in place reached every map at once.
- Texel density was already at or over the bible's 512 px/m on Map 0 (2K sets on snow, plaster, planks, boards).
  The weak surfaces were not low resolution, they were the wrong picture or no picture:
  1. **Trodden snow / frozen mud** (`Snow015`, Map 0's paths and roads, the whole Kaltenbrunn yard): a photograph
     of snow on green grass. Under the lamps it read as a lawn with hard rectangular edges and visible rows.
  2. **Kaltenbrunn's architecture**: render, brick, concrete, concrete floors and rock were procedural noise
     (the headframe building was a blue blotch pattern at any distance).
  3. **The sky on Map 0 and Kaltenbrunn**: the dome shader existed: a flat grey deck with soft holes, a blurred
     blob for the moon, one-cell square stars. Totenhafen had a two-colour gradient.
  4. **Thalbach's yards** (`dirt_aerial_02`): an aerial photograph stretched over 9 m, a blur at walking distance.
  5. **The inn's plaster** (`beige_wall_001`): a 2K texture with nothing in it; a flat cream under the lamps.
  6. **Groom Lake's salt**: 2 m pillows with a soft 20 cm band between them, no detail at the feet.
  7. Totenhafen's and the works' concrete at 1K over 2.4 to 3 m tiles (340 to 430 px/m).
- Fernflug's acts II to IV already have their own sky shaders (stars, the dawn band, the Earth); left alone.

## What changed

### The shared shader (every map, no regeneration)
`surface_pbr.gdshader` + the new `surface_variation.gdshaderinc`, triplanar surfaces only:
- `macro_var` / `macro_scale`: a slow world-space brightness drift (default 0.18 over 7 m, no texture read): long
  walls and yards stop being one flat tone.
- `detile` (0 = off, the default): a second sample of the same set, 2.7 times larger and offset, blended in noise
  patches near the camera and mostly beyond 30 m, where the repeat of a 2 to 3 m tile is what the eye reads. On for
  unstructured ground and render (snow, trodden snow, mud, concrete floors, plaster, rock); never on coursed stone,
  brick or boards (a unit test holds that). Costs six texture reads, only on the materials that turn it on.
- `sparkle`: snow glints. One cell in fifty (1.2 cm cells, within 16 m) gets a slightly tilted normal and a low
  roughness, so it flashes under a lamp or the moon as the camera moves; nothing is emissive, so snow in the dark
  stays dark. Subtle on purpose (snow 0.7, trodden snow 0.3).
- `gravelight/world/landscape/shaders/near_land.gdshader` (the terrain round Map 0's and Kaltenbrunn's slabs) uses
  the same include with the slab snow's values (`Landscape._near_land_textures`), so the seam stays hidden.

### Baked materials follow the data at load
`MaterialLibrary.apply_runtime(mat)` / `LookMaterials.apply_library(map)`, one line in `MapRoot._ready` before the
look's material pass: a baked `lib_<key>` material gets the variation values from materials.json; a key marked
`"live": true` gets its whole entry, textures included (a set swapped after the scenes were baked); a renamed
variant is found by its albedo file (`by_texture`: Mondlicht's regolith). This is what lets Map 0 take the new
snow, mud and plaster **without regenerating map00.tscn** (T-251's file). Presentation only.

### Sets (all Poly Haven, CC0, `tools/fetch_cc0_materials.py`, LICENSE.txt + SOURCE.txt each)
| Key | Was | Now |
|---|---|---|
| `snow_trodden` | Snow015 (snow on grass), 1K | `asphalt_snow` 2K: thin grey walked snow, clean snow lying on it in patches (frost 0.5) |
| `frozen_mud` | Snow015 | `brown_mud_dry` 2K: churned frozen earth, snow in the hollows (frost 0.6); also the terrain's road blend |
| `plaster` | beige_wall_001 | `grey_plaster_03` 2K: hand-trowelled, uneven, stained; same brightness in the taproom (wall 176 to 174 of 255) |
| `fl_yard` | dirt_aerial_02 over 9 m | `brown_mud_dry` at 2.6 m with detile 0.75 |
| `m1_stucco` (Mats `stucco`) | noise | `white_plaster_rough_01` 2K |
| `m1_brick` (Mats `brick`) | flat procedural bond | `factory_brick` (in the repo), red-brown tint |
| `m1_concrete` / `m1_floor` (Mats `concrete`, `concrete_floor`) | noise | `concrete_wall_004`, `concrete_floor_worn_001` |
| `m1_rock` / `m1_rock_floor` (Mats `rock_dark`, `rock_floor`) | noise | `rock_face_03` 2K, dark and desaturated |

In place, albedo and normal from 1K to 2K (ORM stays 1K; same paths, so every map takes them):
`concrete_wall_004`, `concrete_floor_worn_001`, `dirty_concrete` (Totenhafen's bunker, quay and piers, the works'
concrete and floors: 430 to 850 px/m and 340 to 680 px/m) and `stone_wall` (Map 0's yard wall and hearth).
Halite, the lab's paint and tiles stay procedural (MapAmbience's salt glint finds the halite by name).

### Sky
- `sky_dome.gdshader` (Map 0, Kaltenbrunn; a mesh dome, unshaded): the moon is a disc (waning gibbous, maria, a
  soft limb) where a break shows it and a corona through the cloud where it does not; the deck is lit from above
  by the moon (`deck_light`), silvered on its rims toward the moon and shaded on the far side (one more noise
  sample toward the moon); a thin high veil drifts across the breaks; the stars are round, of several sizes and
  colours on two grids, and twinkle; half a display bit of noise breaks the banding. Every old uniform is kept
  (Landscape, MapAmbience's flashes and searchlight spots write them).
- `NightSkyDome` (`gravelight/world/look/night_sky_dome.gd`) + a `sky_dome` block in a map's grade json: the same
  dome for a map without a Landscape. Totenhafen has one: a low, nearly closed storm deck in the grade's
  green-grey.
- Interiors: the dome is unshaded geometry; the Environment's own sky, ambient, reflection source and SDFGI sky
  light are untouched on every map, so no room changes brightness because of the sky.
- Thalbach (cloud deck plane + searchlights), der Kranich, Groom Lake and Mondlicht keep their skies as they are.

### Groom Lake's salt
`salt_flat.gdshader`: narrower ridges that crumble at their edges, a second generation of hairline cracks inside
each polygon (a 0.46 m Voronoi, within 30 m of the camera), a fine grain in albedo and normal. Far away nothing
changes.

### Regenerated
map01, map02, map04a, map04b, map04c, map04d (gen runs of about 17 s each). Layout fingerprints SAME, node blocks
identical, same node and light counts. map00 was NOT regenerated and gen_map00.gd was not touched.

### Tools
- `tools_src/capture.gd`: a "maps" camera set with `"keep_map": true` keeps one map load for consecutive cameras
  and runs a camera's `do` list; set `u19_textures` in `data/gravelight/capture_cams.json` (37 cameras).
- `assets/import_presets/texture_albedo.cfg` (new) and `texture_normal.cfg` priority 20: a set whose name holds
  "rough" (white_plaster_rough_01) matched the data preset with all three maps (linear albedo, no normal flag).
- `tools/fetch_cc0_materials.py`: a generic User-Agent (nothing about the project goes out with a download).

## Calls
- Fixed the picture before the pixel count: Map 0 was already at 2K where it matters, so the pass went to wrong or
  empty textures, tiling, and the sky; only four sets were raised to 2K.
- Runtime data over regeneration for Map 0, because map00.tscn is T-251's in this update. After the lead
  regenerates map00 the `live` flags are harmless (the baked material is already current).
- Mats `concrete`, `brick`, `stucco`, `concrete_floor`, `rock_dark`, `rock_floor` are library sets for every
  generator now (they are global keys), so all six other scenes were regenerated and looked at.
- The sky keeps its level: on Forward+ the old dome averaged 37/255 (green channel, 32 degrees up) and the new
  one 38 to 40, with the contrast now inside the deck (shaded flanks, lit rims) instead of a flat grey.
- Sparkle through normals and roughness, not emission: an emissive glint would glow in unlit snow.
- Left the Snow015, beige_wall_001 and dirt_aerial_02 folders in the repo (no library key uses them now;
  removing assets is the owner's call).
- The sky's level was set on Forward+, not on the WSL Compatibility frames (see "Two renderers" below).

## Two renderers (read this before looking at the frames)

`tools/wsl_godot.sh` renders with the Compatibility renderer (opengl3, what the browser runs). The owner plays on
Forward+. For dark tones the two are not the same picture: Compatibility applies the grade's contrast in linear
space, so with contrast 1.16 everything under about 0.08 linear goes to pure black (the sky deck, a wall in
moonlight, an unlit room), while Forward+ applies it after the sRGB conversion and keeps those tones. The first
before frames of this job (Compatibility) showed a black sky and black walls on Map 0 that the owner never sees.

So the frames to judge by are Forward+, rendered invisibly under WSL with Vulkan on lavapipe (software):
`xvfb-run ... godot --rendering-driver vulkan ... res://tools_src/capture.tscn -- --set=u19_textures ...`
(about ten minutes a map; SDFGI, SSAO and volumetric fog all run). The "before" set was rendered from a copy of
the project at master's content in the scratch folder, so both sets come from the same cameras, the same tool and
the same renderer. The Compatibility sets are kept as the web build's record (`web_before`, `web_after`).

## Frames (`docs/captures/u19_textures/`)

- `before/`, `after/`: Forward+, 28 cameras on Map 0, Kaltenbrunn, Totenhafen, Thalbach, Groom Lake, Mondlicht
  (ground, wall, sky, an interior each). `pairs/`: the two side by side per camera, and a contact sheet.
- `web_before/`, `web_after/`: Compatibility, all 37 cameras of the set (der Kranich included).
- `sky_before/`, `sky_after/`: the dome alone on Forward+ (`gravelight/tools_src/sky_preview.tscn`): horizon,
  32 degrees up, the moon, the zenith.

What they show: Map 0's paths and roads go from a black-and-white speckle to walked snow and frozen earth; the
moon is a disc, the deck has form; the taproom's walls carry trowel marks and stains at the same brightness (the
red rug and every other colour unchanged); Kaltenbrunn's yard is one clean surface, its render is no longer a
blotch pattern; Thalbach's yards are gravelly earth instead of a blur; Groom Lake's salt has cracks at the feet;
Totenhafen's quay, hut and pens match the before frame (the sky keeps its level, with a faint structure).

Things in the frames that are not this job's: the capture set's crate spot and precipitation are random per run;
the bright dots in the sky frames are snowflakes and rain, not stars.

## Numbers

- New sets (2K albedo + normal, 1K ORM, PNG, LFS): asphalt_snow 21 MB, brown_mud_dry 21 MB, grey_plaster_03 16 MB,
  rock_face_03 17 MB, white_plaster_rough_01 16 MB = 91 MB. Four sets raised in place: 12.9 MB to 54.3 MB
  (+41 MB). About +132 MB in the repository in all.
- VRAM (compressed, with mips): a 2K albedo + normal pair is about 8 MB against 2 MB at 1K. Map 0 loads roughly
  23 MB more (three new 2K sets and stone_wall, less Snow015 and beige_wall_001, which it no longer loads).
- Shader cost: macro_var is two noise evaluations on triplanar surfaces; detile is six texture reads on the
  materials that ask for it; sparkle one hash. The dome is two more noise octave sets (unshaded, drawn behind
  everything).
- No triangle counts changed except the Totenhafen dome (one 48 x 24 sphere).
- Frames: 138 JPEGs, 25.5 MB (the PNGs were 185 MB; converted at quality 88).

## Verification

- `check_scripts`: 940 scripts, 0 failed.
- GUT, full suite: 2340 tests (master's 2330 and the 10 of `test_surface_variation.gd`), 2339 passing, the one
  known risky "did not assert". Run before the last data tuning (tints, the Totenhafen dome's numbers, the
  fix table); after it `test_surface_variation`, `test_material_library`, `test_look*`, `test_license_gate`,
  `test_assets_manifest`, `test_map0*`, `test_web_profile`, `test_gen_detail_lib`, `test_prop_library`, `test_earth_sky`,
  `test_flight_sky` and `test_zone_ambience` were run again: 251 tests, all passing.
- Smokes, `tools/run_smokes.sh .smoke_logs/u19_tex smoke_map0`: 21 of 21 PASS (map00 x4, map01 x3, map02 x3,
  map04 x11), 0 script errors.
- `tools/look/layout_fingerprint.py --diff` old against regenerated: SAME for map01, map02, map04a, map04b,
  map04c, map04d; every node block identical with resource ids blanked; node and light counts equal.
- `tools/look/material_audit.sh`: 2435 outliers before the pass, 3 after (master's report: 2369 and 2). The third
  is a flat black part of Jakub's M1911 on Map 0 (`rough_low`), listed as open; map00.tscn and Jakub are not touched by
  this branch, so it is there on master as well (master's committed report predates it).
- `audit_map_art` on every map, here and on the copy at master's content: the same findings on both
  (map00 74, map01 41, map02 1, map04a 33, map04b 59, map04c 17, map04d 12; all `invisible_wall` / `door_blocked`
  and map04b's `no_uv` 15, map04d's `invisible_material` 1). Nothing new, nothing fixed: they are geometry
  findings and this was a surface pass.
- `python -I tools/assets_manifest.py --check`: current, 117 folders.
- Not run: the FPS bench and the draw-call census (`tools/wsl_perf.sh`); FPS under software rendering means
  nothing and the draw calls can only have changed by the one dome. The web export was not built.

## For the lead at merge

1. **map00 does not need regenerating for this branch.** Its baked materials follow materials.json at load. When
   T-251's regenerated map00.tscn lands, nothing more is needed (gen_map00.gd was not touched here).
2. `data/credits_art.json` and `docs/ASSETS.md` are generated (`python -I tools/assets_manifest.py`); if another
   branch added assets, take either side and run the tool again.
3. After regenerating any map, do NOT keep the `...tscn::NoiseTexture2D_...` entries that
   `tools/look/material_audit.sh --write-fixes` writes into `data/look/_materials.json`: on Map 0 they took the
   taproom rug to grey. This branch's table is master's plus the four new library textures.
4. New data keys: materials.json `macro_var`, `macro_scale`, `detile`, `sparkle`, `live`, `by_texture`; a grade
   json's `sky_dome` block; a capture set's `keep_map`.
5. `override.cfg` (git-ignored) and `.smoke_logs/` are local.

## Open items

- Map 0's path slabs are boxes laid on the snow: their straight edges still show (much less, now that the two
  surfaces are the same family). Two of them overlap by the well and z-fight in a strip (it did before as well).
  A blended edge needs geometry or a decal: T-251's file.
- The inn's outside walls are a silhouette at night on Forward+ (no light reaches them); that is lighting, not
  texture, and was left alone.
- Kaltenbrunn's brick is a photographed brick now and less red than the procedural one, which was a code-built
  shader the material pass could not see; the new one is held to the bible's 0.30 saturation like every other
  wall. If the owner wants the red back it is one tint and one line in `_materials.json`.
- Halite, the lab's cream paint and tiles, and the props' steel / machine paints are still procedural.
- A map loaded straight after another whose power was on starts with its power lights lit (its PowerSwitch
  readies before MapRoot resets the match). Seen in the capture tool, worked round there; worth a look in the
  game's own map-to-map flow.
- Snow015, beige_wall_001 and dirt_aerial_02 are in the repo and unused by the library.
