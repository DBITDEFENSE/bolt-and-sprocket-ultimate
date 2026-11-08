# ART_BIBLE — the look of GRAVELIGHT (UPDATE 12 §1, DECISIONS T-207; asset rules from UPDATE_05 §0.3, T-088)

Short and prescriptive. Every asset, light, grade and capture that goes into `gravelight/` or `assets/` follows this
page; where a work order and this page disagree, this page wins until DECISIONS.md says otherwise. **Bolt & Sprocket
(`bs/`) and The Fine Print stay cartoon**: bright, clean, saturated, flat-lit. The contrast between them and this is
part of the story, so nothing below applies to them.

Part A (§1–§10) is the look: the direction, palette, values, fog, lens, the accent rules, materials, lighting, the
per-map grades and the do/don't sheet. Part B (§11–§16) is the asset contract that was here before (materials
shader, scale, budgets, naming, readability, how to add an asset); it is unchanged except where Part A tightens it.

---

## PART A — THE LOOK

## 1. The direction in one line (decided; don't re-litigate it)

**Desaturated war-film realism: grim, stylized, closer to *Black Ops 1* zombies than to anything photoreal.**

- **Colour:** muted greys, browns and cold blues. Most of the frame sits inside a 30% saturation box. Heavy fog.
- **Accents:** **Nachtglas violet** is the only bright supernatural colour anywhere. **Blood red** is the second
  accent. Everything else that glows is a practical lamp: warm, dim, flickering.
- **Light:** warm practicals against cold ambient. Nights are darker than they were; what you see, you see because
  something is lit, not because the air is grey.
- **Surface:** nothing is clean. A roughness floor, a dirt layer and wear on every material, so assets from different
  artists sit in one world.
- **Not:** photoreal (free assets can't reach it and near-real faces fall into the uncanny valley); not low-poly
  cartoon; not neon; not a colour-graded music video. If a frame could be a 1944 photograph someone coloured by
  hand with three pencils, it is right.

Reference tone, unchanged since T-088: a village inn at night in deep winter, 1944, five minutes after the dead came.
Warm inside, cold outside, and the only clean, saturated colour anywhere is the violet of Nachtglas.

Silhouettes still come first (§15): readable from 40 m in fog by outline, grime second, detail last. Proportions
stay slightly exaggerated (hands, heads, boots, hinges, bolts about 10% bigger than life), surfaces are
hand-painted-plus-PBR.

## 2. Palette (hex swatches)

The scene is lit, not painted: most colour comes from the lights and the grade, so albedos stay muted and
mid-valued. Values below are display (sRGB) colours as they should read on screen after the grade.

### 2.1 The neutrals (what most of every frame is made of)

| Swatch | Hex | Name | Where |
|---|---|---|---|
| ![#0b0d12](https://placehold.co/16x16/0b0d12/0b0d12.png) | `#0b0d12` | **Night black** | the darkest a night exterior goes; never pure `#000000` except the Moon's sky |
| ![#1a2230](https://placehold.co/16x16/1a2230/1a2230.png) | `#1a2230` | **Frost shadow** | the shadow side of snow and stone at night; Map 0's fog colour |
| ![#2a3340](https://placehold.co/16x16/2a3340/2a3340.png) | `#2a3340` | **Cold ambient** | the split tone's shadows on every winter map; moonlit interiors |
| ![#5b6672](https://placehold.co/16x16/5b6672/5b6672.png) | `#5b6672` | **Field grey** | wool, steel in shade, the mid-value of a night frame |
| ![#8c8a82](https://placehold.co/16x16/8c8a82/8c8a82.png) | `#8c8a82` | **Plaster grey** | walls, concrete, limed brick |
| ![#b8a890](https://placehold.co/16x16/b8a890/b8a890.png) | `#b8a890` | **Old paper** | lit plaster, bone, canvas, salt |
| ![#d6dce6](https://placehold.co/16x16/d6dce6/d6dce6.png) | `#d6dce6` | **Snow** | snow albedo; never pure white, never brighter than value 0.90 |
| ![#5a3e2a](https://placehold.co/16x16/5a3e2a/5a3e2a.png) | `#5a3e2a` | **Floorboard brown** | wood family, dark end |
| ![#8c6a48](https://placehold.co/16x16/8c6a48/8c6a48.png) | `#8c6a48` | **New plank** | wood family, light end |
| ![#352c24](https://placehold.co/16x16/352c24/352c24.png) | `#352c24` | **Soot brown** | Thalbach's air, burnt timber, oil |
| ![#2e2c2a](https://placehold.co/16x16/2e2c2a/2e2c2a.png) | `#2e2c2a` | **Iron** | world steel, with rust `#8a4a1e` as a mask |

### 2.2 The practicals (warm against the cold)

| Swatch | Hex | Name | Where |
|---|---|---|---|
| ![#ffa85c](https://placehold.co/16x16/ffa85c/ffa85c.png) | `#ffa85c` | **Lamplight** | oil lamps, candles (gen_map00 `warm`); bulbs are whiter `#ffcc8c` |
| ![#ff8c33](https://placehold.co/16x16/ff8c33/ff8c33.png) | `#ff8c33` | **Fire** | the hearth, GRAVELIGHT ONE's fuel fire, fire barrels |
| ![#e8b86a](https://placehold.co/16x16/e8b86a/e8b86a.png) | `#e8b86a` | **Sodium** | Kaltenbrunn's goosenecks and the depths; Totenhafen's west floods |
| ![#c8d8e8](https://placehold.co/16x16/c8d8e8/c8d8e8.png) | `#c8d8e8` | **Mercury** | Totenhafen's east floods, der Kranich's cabin lamps |
| ![#8099f2](https://placehold.co/16x16/8099f2/8099f2.png) | `#8099f2` | **Moonlight** | the Moon DirectionalLight3D on every winter map |

Warm practicals never exceed saturation 0.65 after the grade (the mono rule in §5 pulls them down from the source
colours above). They may clip to white in their core; the halo is where the colour lives.

### 2.3 The accents (the only clean colour)

| Swatch | Hex | Name | Rule |
|---|---|---|---|
| ![#8a4dff](https://placehold.co/16x16/8a4dff/8a4dff.png) | `#8a4dff` | **Nachtglas violet** (emission `#8c33ff`, glass body `#14081f`, UI `#9e73d9`) | the only bright supernatural colour; §5 |
| ![#8f1d1d](https://placehold.co/16x16/8f1d1d/8f1d1d.png) | `#8f1d1d` | **Blood red** (fresh `#8c1414`, dried `#4a0a0a`) | the second accent; blood, battle lanterns, warning lamps; §5 |

Faction colour (docs/ART_FACTIONS.md): the Wiederkehr mark is **black** on raw metal, concrete or canvas; a thin
**red ring** only on Morgenrot launch-crew gear; **violet never** on the mark (violet is the Nachtglas's own).
Allies carry no insignia colours: plain cloth, stitched names. No real-world emblem anywhere. UI: `INK #9e1714`,
`PAPER #ede3cc`, `GOLD #f2db8c` (menu_kit.gd) are the paper world's colours and are not graded.

### 2.4 Each map's key (three swatches per map; the grades in §8 produce them)

| Map | Air | Shadow | Light |
|---|---|---|---|
| Crossroads Inn | ![#1a2230](https://placehold.co/16x16/1a2230/1a2230.png) `#1a2230` frost | ![#2a3340](https://placehold.co/16x16/2a3340/2a3340.png) `#2a3340` | ![#d9c9a8](https://placehold.co/16x16/d9c9a8/d9c9a8.png) `#d9c9a8` window warmth, fire `#ff8c33` |
| Kaltenbrunn surface | ![#141a26](https://placehold.co/16x16/141a26/141a26.png) `#141a26` | ![#26303a](https://placehold.co/16x16/26303a/26303a.png) `#26303a` cold steel | ![#c8d8e8](https://placehold.co/16x16/c8d8e8/c8d8e8.png) `#c8d8e8` |
| Kaltenbrunn depths | ![#0f0c08](https://placehold.co/16x16/0f0c08/0f0c08.png) `#0f0c08` | ![#4f4538](https://placehold.co/16x16/4f4538/4f4538.png) `#4f4538` salt | ![#e8b86a](https://placehold.co/16x16/e8b86a/e8b86a.png) `#e8b86a` sodium |
| Kaltenbrunn Core | ![#0a0510](https://placehold.co/16x16/0a0510/0a0510.png) `#0a0510` | ![#42336b](https://placehold.co/16x16/42336b/42336b.png) `#42336b` | ![#8a4dff](https://placehold.co/16x16/8a4dff/8a4dff.png) violet, full saturation (GDD 17) |
| Totenhafen | ![#28352f](https://placehold.co/16x16/28352f/28352f.png) `#28352f` storm | ![#1f2b28](https://placehold.co/16x16/1f2b28/1f2b28.png) `#1f2b28` wet concrete | ![#b7c2b3](https://placehold.co/16x16/b7c2b3/b7c2b3.png) `#b7c2b3`, lanterns `#8f1d1d` |
| Fernflug I Thalbach | ![#352c24](https://placehold.co/16x16/352c24/352c24.png) `#352c24` soot | ![#1b1714](https://placehold.co/16x16/1b1714/1b1714.png) `#1b1714` | ![#cfa865](https://placehold.co/16x16/cfa865/cfa865.png) `#cfa865` ochre |
| Fernflug II der Kranich | ![#232c38](https://placehold.co/16x16/232c38/232c38.png) `#232c38` dawn | ![#1c2736](https://placehold.co/16x16/1c2736/1c2736.png) `#1c2736` | ![#d4dce8](https://placehold.co/16x16/d4dce8/d4dce8.png) `#d4dce8` aluminium, bay lamps red |
| Fernflug III Groom Lake | ![#d1bca6](https://placehold.co/16x16/d1bca6/d1bca6.png) `#d1bca6` dust | ![#4a3d30](https://placehold.co/16x16/4a3d30/4a3d30.png) `#4a3d30` | ![#ece0c8](https://placehold.co/16x16/ece0c8/ece0c8.png) `#ece0c8` bleached |
| Fernflug IV Mondlicht | ![#000000](https://placehold.co/16x16/000000/000000.png) `#000000` vacuum | ![#404040](https://placehold.co/16x16/404040/404040.png) grey, no hue | ![#8a4dff](https://placehold.co/16x16/8a4dff/8a4dff.png) violet, the only colour |
| Menu / prologue / the reels | ![#101214](https://placehold.co/16x16/101214/101214.png) `#101214` print black | ![#6e7378](https://placehold.co/16x16/6e7378/6e7378.png) silver grey | ![#d6dbe3](https://placehold.co/16x16/d6dbe3/d6dbe3.png) `#d6dbe3` silver, no colour at all |

## 3. Value ranges (display luma, 0–255, of a 1280x720 frame after the grade)

Measured on the style frames (`docs/look/frames/`, `tools/look/style_frames.py` prints them). "Mean" is the whole
frame; "floor" the 5th percentile; "ceiling" the 95th. A frame outside its row is a lighting or grade bug, not a
mood.

| Time of day | Where | Mean | Floor | Ceiling | Notes |
|---|---|---|---|---|---|
| **Night, exterior** | Map 0's field and road, Kaltenbrunn's yard, Totenhafen's quay, Thalbach's street | 26–55 | ≤ 8 | 140–200 | true black is allowed in the corners; windows and fire clip to white only in their core (T-061's 26–71 power-off means still hold) |
| **Night, interior, unpowered** | the taproom by lamplight, the barracks, the pen's sheds | 30–60 | ≤ 10 | 160–220 | every play space has a visible source (T-061/062/063); nothing is black because "it's night" |
| **Night, interior, powered** | after the switch | 45–80 | ≤ 12 | 180–235 | the sweep adds light, not saturation |
| **Dusk / dawn** | der Kranich over the cloud deck, Thalbach under the raid glow, the Kaltenbrunn depths' sodium | 50–85 | ≤ 10 | 190–235 | the one time a sky may be a colour (dawn blue `#232c38` to `#6f86a8`) |
| **Day** | Groom Lake's salt | 95–140 | ≥ 12 | 235–250 | dust lifts the blacks; the salt is the only thing allowed near white |
| **Vacuum** | Mondlicht's yard | 20–60 | 0 | 240–255 | hard sun, black sky, no air: the one place blacks go to 0 and whites to 255 |
| **The reels / menu** | archive black-and-white | 60–110 | 8–14 (a print's lifted black) | 200–230 | no colour; grain and vignette carry the frame |

The player's Brightness slider (T-133, 0.7–1.4) scales each map's own grade; these rows are at 1.0.

## 4. Fog density ranges

Fog is the medium the look lives in: heavy, dark, lit only where lamps reach. Depth fog (`fog_density`) carries
the far field and the sky; volumetric fog (`volumetric_fog_density`, Forward+ only, the preset's `gfx_fog` quality)
carries the lamp halos and the shafts. The grade files set both (§8).

| Space | Depth fog density | Fog colour value (0–1) | Volumetric density (High) | Notes |
|---|---|---|---|---|
| Night exterior, winter | 0.012–0.020 | 0.07–0.14 | 0.018–0.030 | Map 0: 0.018 / 0.026. The fog is darker than the snow it sits on |
| Night interior | 0.006–0.011 | 0.04–0.10 | 0.010–0.018 | Kaltenbrunn 0.011 / 0.018; Totenhafen 0.011 / 0.015 |
| Industrial / soot | 0.010–0.012 | 0.12–0.20 (brown, not grey) | 0.012–0.016 | Thalbach 0.011 / 0.015 |
| High altitude | 0.004–0.009 | 0.10–0.18 | 0.008–0.012 | der Kranich: thin air, the cloud deck is the Landscape, not the fog |
| Desert day | 0.0028 clear, 0.010–0.020 in a storm | 0.55–0.75 (dust) | 0.005 clear | DustStormFx owns the density during a storm (T-157); the grade leaves it alone |
| Vacuum | 0.0 outside, ≤ 0.004 inside | — | 0 / 0.004 | Mondlicht: no air outside; a little haze inside the station |
| The Bellringer's fog, the Core's halo | the systems' own tweens | — | — | zombie_director.gd owns Kaltenbrunn's fog density (T-062); the grade never fights it |

`fog_sky_affect` stays 1.0 outdoors on the winter maps (the sky is the fog), 0.4–0.6 where a sky must read (the
pen mouth, der Kranich's windows, the Earth over Mondlicht). Volumetric albedo is cool and light (`#bfc8d8` to
`#c9b89a` in soot); emission under 0.03 (a glow in the air is a lamp's job, not the fog's).

## 5. Grain, vignette and lens (the `post` block; §2 builds the shader, this page sets the numbers)

| Setting | Maps | The reels / menu | Rule |
|---|---|---|---|
| **Film grain** (`grain`, luma-weighted, strongest in the shadows) | 0.05–0.08 | 0.14–0.16 | fine, monochrome, animated every frame; never a coloured noise; the settings' `film_grain` toggle turns it off |
| **Vignette** (`vignette`, the edge darkening) | 0.34–0.42 | 0.50–0.52 | an oval (1.15 : 1), starts past 55% of the half-diagonal; never black at the corners on a map (0.5 is a reel's gate) |
| **Edge softness** (`edge_soft`, lens blur at the frame edge) | 0.16–0.24 | 0.35–0.40 | the centre 60% of the frame stays sharp; never a full-frame blur (the HUD and the sights are read there) |
| **Chromatic aberration** (`ca`, edge only) | 0.001–0.002 | 0.0 | a red/blue split growing from zero at 60% of the half-diagonal; zero in the centre, always; zero on the reels (old glass had none worth faking) |
| **Flicker** (`flicker`, the reels) | 0 | 0.04–0.06 | the archive projector's gate; §3's treatment on video, the shader on in-engine stand-ins |
| **Tonemap** | Filmic, white 6.0 | Filmic | the maps were AGX at exposure 1.3–2.0; Filmic keeps the warm practicals warm (AGX pulled their highlights toward grey) |

Everything in the post block is data (`data/look/<map>.json` `post`, `LookGrade.post_params(map_id)`), toggled by
the graphics settings piece by piece, and off on the web profile where the budget says so (U09 §2d).

## 6. The rules for violet and red

**Where violet may appear:** Nachtglas (the shards, the Crucible's veins, the vault's heart, the specimen jars, the
pylons), the Mondlicht station's lamps and strips, the Earth-side point on the Moon, the menu's progress point on the
Moon, the Crucible camo (veins on the gun's own material, never a recolour), the UI's `VIOLET` for Nachtglas text.
Nowhere else: no violet lamp "for mood", no violet fog, no violet sky.

**Where red may appear:** blood (pools, decals, the infection shader's wounds), battle lanterns and emergency lamps
(Totenhafen, der Kranich's bay, the Morgenrot ring), warning paint on a lever or a blast door, the UI's `INK`. No red
practical that isn't a lamp with a reason; no red fog; the fire is orange (`#ff8c33`), not red.

**How much of the frame:**

| | Violet | Red |
|---|---|---|
| A normal frame on any map | ≤ 5% of the pixels past saturation 0.5 | ≤ 3% |
| A frame built around the accent (the Crucible room, a Nachtglas pickup in hand, a kill) | ≤ 12% | ≤ 8% |
| The climax rooms (Kaltenbrunn's Core, Mondlicht's hall, the Earth over the yard) | up to 25%, and nothing else in the frame is coloured | ≤ 3% |
| Mondlicht | the only colour on the map (the grade's `mono` 1.0 keeps hue 268 ± 36° and greys everything else, red included) | 0% |
| The reels / menu | 0% (the menu's Moon point is the exception: one pixel-sized dot) | 0% |

Both accents are **kept, not added, by the grade**: every map's grade desaturates the frame by 40–60% through a
generated 3D LUT that leaves a saturated hue 268 ± 20° (violet) and 0 ± 12° (red; ± 18° until T-208 half-kept the warm lamps at 17-23° and painted red halos) at full saturation, so Nachtglas
and blood are the only things that stay as saturated as their source. A new asset in those hues that isn't Nachtglas
or blood will read as one: don't make it.

## 7. Material rules (the surface pass; §2's audit, `tools/look/material_audit`, lists the outliers)

1. **Roughness floor.** World materials never go below roughness **0.45** (wood, plaster, stone, cloth, leather,
   skin, paint); world metal never below **0.35**; gun metal on the viewmodel never below **0.25**. Only ice, glass,
   standing water and Nachtglas go lower (0.05–0.25), and water only where `wetness` puts it.
2. **No clean plastic.** Nothing in 1944 is injection-moulded: no uniform roughness, no flat albedo over a whole
   mesh, no untextured bright colour. A material that reads as plastic gets a roughness lift, a grime layer and a
   desaturated albedo, in that order, until it reads as painted metal, bakelite or enamel.
3. **Wear and dirt on everything.** Every world material exposes `grime`, `wetness`, `frost` (§11, the shared
   `surface_pbr.gdshader`); defaults 0.35 indoors, 0.5 outdoors, and nothing ships at 0. Edges wear light (paint
   off the corners), floors and the lower 0.4 m of walls wear dark (the `grime_height` mask), anything near a fire is
   sooted, anything outdoors is frosted on its up-faces. Imported props get the shared detail texture or triplanar
   grime (§2) so assets from different artists sit together.
4. **Desaturated albedo.** Albedo saturation stays **under 0.30** (it was 0.35), value between 0.04 and 0.90.
   Olive drab, field grey, rust, oak, lime, soot. A texture that fights the palette is tinted in the material
   library (`materials.json` tint), not repainted.
5. **No baked light.** No lighting, no AO beyond the ORM map, no highlights in albedo; the grade and the lamps do it.
6. **Emissive is a short list.** Lamps, bulbs, fire, Nachtglas, warning lamps, the HUD, the screens on Mondlicht.
   Emission energy 2–4 on Nachtglas, 1–2 on a bulb's glass (LampGlow dims it with the light, T-057). Nothing else
   glows.
7. **Skin.** Zombie and people skin roughness 0.45–0.65, albedo desaturated to under 0.25 and cooled toward
   `#8c8a82` on the dead (the infection shader owns surface 0); the living keep a little warmth (the Cousins, Jakub,
   the squad) so they read as alive against the dead.

## 8. Lighting rules

1. **Warm practicals against cold ambient.** Every interior light that is a thing (lamp, candle, bulb, stove, fire)
   is warm (`#ffa85c` to `#ff8c33`, sodium `#e8b86a`); the ambient and the moon are cold (`#384566`, `#8099f2`); the
   fog takes the ambient's colour. Mercury floods (`#c8d8e8`) are the exception and always sit opposite a sodium one
   (Totenhafen's hall, T-063) so warm-against-cold is kept inside one frame.
2. **Darker nights.** Ambient energy on the winter maps drops to 0.8–0.9 of what it was (the grades' `ambient
   energy_scale`), SDFGI bounce does the filling on High and the flat fill stays as Low's fallback (T-061/062).
   The horror layer's darker night (T-192, 0.9 brightness) still stacks on top. Darker means *fewer lit places*,
   not a dimmer everything: the lamps keep their energy and their shadows.
3. **Readability is a hard rule.** Zombies and pickups stay readable at night: a zombie 20 m away in the dark must
   separate from the ground by at least 12 luma levels (its rim from the moon, its infection glow, its outline
   against fog), a buyable, a drop, a crate, a perk machine and a door plaque keep their T-088 shapes and colours
   (§15) and are never darker than the wall behind them. The capture set `u05` `close_zombie` and the `_objects`
   cameras are the check; `docs/look/frames/*_after.*` the record. If a grade makes a frame fail this, the grade
   loses, not the light.
4. **Shadows are from lamps, not from everywhere.** Shadow casters stay few (§13): the moon, the lamps that shape a
   room, the floods. A new light casts a shadow only if it is bigger than a chair's worth of light.
5. **Lightning, fire, the Bellringer, the Core** keep their own systems (LightningFlash, WreckGlow, zombie_director's
   fog tween, depth_grade.gd); the grade is applied once at load and never animates against them.
6. **Cutscenes** take the grade of the map they play over (`LookGrade.cinema_id`), the reels (`cinema_reel`) and
   the menu the archive black-and-white, so a cut into gameplay doesn't change the air.

## 9. One grade per map (`data/look/<map_id>.json`, applied by `gravelight/world/look/look_grade.gd`)

The schema is U12 contract C2. Absent keys leave the map's own value alone; a map with no file is untouched;
`zones` merge over the map (Kaltenbrunn's `surface` / `depths` / `core` feed `depth_grade.gd`); the web profile
merges `_web.json` (no LUT on Compatibility) and the file's own `web` block. `--look=off` turns every grade off (the
"before" frames). `tools/look/style_frames.sh` renders the `u12_look` camera set before and after into
`docs/look/frames/`.

| Map (`map_id`) | The grade | Frames |
|---|---|---|
| Crossroads Inn (`map00_crossroads`) | **frozen night**: Filmic at exposure 1.0 (was AGX 1.3), contrast 1.16, mono 0.50 (violet and red kept), split tone `#203238` → `#d9c9a8` at 0.3, ambient 0.7x, fog 0.022 `#10161f`, volumetric 0.030; the windows' warmth, the door lantern and the wreck's orange fire are the only warm things | `frames/map00_crossroads_before|after` |
| Kaltenbrunn (`map01_kaltenbrunn`) | **cold steel over salt and sodium**: Filmic, contrast 1.12, mono 0.40, split tone `#22303a` → `#d8c6a0` at 0.25, fog 0.012 / 0.020; zones (depth_grade.gd): surface `#384566` fill at 0.26, exposure 1.05, saturation 0.8; depths `#4f4538` fill at 0.6 (salt white lit sodium amber), exposure 1.2, saturation 0.86; Core `#42336b`, exposure 1.2, saturation 1.0 | `frames/map01_kaltenbrunn_*` |
| Totenhafen (`map02_totenhafen`) | **storm green-grey**: Filmic at exposure 1.7 (was AGX 2.0), contrast 1.12, mono 0.45, split tone `#1f2b28` → `#b7c2b3` at 0.35, ambient 0.85x, fog 0.011 `#2a3a33`, volumetric 0.015 albedo `#b8c4bb`; the red battle lanterns kept | `frames/map02_totenhafen_*` |
| Fernflug I Thalbach (`map04a_thalbach`) | **industrial ochre and soot**: Filmic 1.7, contrast 1.10, mono 0.50, split tone `#1f1a14` → `#cfa865` at 0.45 (brown shadows, not blue), ambient 0.85x, fog 0.011 `#3a2f26`, volumetric 0.015 albedo `#c9b89a` | `frames/map04a_thalbach_*` |
| Fernflug II der Kranich (`map04b_kranich`) | **dawn blue over cloud, cold aluminium inside**: Filmic 1.7, contrast 1.12, mono 0.45, split tone `#1c2736` → `#d4dce8` at 0.3, fog `#232c38`; the ambient is left alone (the unpowered bay is black in any grade); the bay's red lamps kept | `frames/map04b_kranich_*` (the cockpit) |
| Fernflug III Groom Lake (`map04c_groomlake`) | **bleached desert, dust brown**: Filmic 1.7, contrast 1.06, mono 0.60 with the violet keep at half (the impeller crater lights the salt), split tone `#4a3d30` → `#ece0c8` at 0.5, fog colour `#5a4e40` and albedo `#d8c8b0` (dust); the density left to the dust storm | `frames/map04c_groomlake_*` (the hull from the salt) |
| Fernflug IV Mondlicht (`map04d_mondlicht`) | **hard black and white, violet the only colour**: Filmic 1.7, contrast 1.2, mono 1.0 keeping hue 268 ± 36° only (the amber lamps and the red go grey on purpose); no tint, no fog change | `frames/map04d_mondlicht_*` |
| Menu / prologue (`menu`), the reels (`cinema_reel`: `lazarus_saturday`, `fourth_day`, `staub`) | **archive black-and-white**: saturation 0, contrast 1.16, silver split tone `#101214` → `#d6dbe3` at 0.25, black lifted 0.04 like a print; grain 0.14–0.16, vignette 0.5, flicker | `frames/menu_*` |

The LUT's keep rule (§6) only keeps a *saturated* violet or red (saturation past 0.3–0.55, hue 268 ± 20°): moonlit
salt, a blue-grey sky and the Moon's light on snow sit outside it and desaturate with the rest. The first pass kept a
± 34° window and the salt flats and Map 0's snow came out lavender; the frames decided the width.
T-214 (the blind review): the red keep needs saturation 0.6–0.85 (blood, a battle lantern), not 0.3 (a warm-lit board
in the Filmic toe turned red and stayed); Mondlicht's violet keep also needs brightness (value 0.3–0.5: the tube and
its glow, never the floor its fill washed); and a `suppress` band greys the pink / salmon / lavender that a warm lamp
and the cold moon sum to on a pale wall (hue 290–15 and 250–290 at low saturation only). Warm against cold stays in
the light's colour, never as a pink third colour. Practical violet fills go neutral and keep a small violet pool
(`lights.rules` `sat_scale` + `pool`).

Per-map numbers are picked by the style frames and logged in DECISIONS T-207; change them in the json, re-render
the frame, look at it, log it. Never in the generator.

## 10. Do / don't (with our own captures)

The pairs live in `docs/look/frames/` (`<map>_before.*` is the U11 look with every grade off, `<map>_after.*` the
grade); `sheet.jpg` is all of them side by side for the blind review.

| Do | Don't | See |
|---|---|---|
| Let the night be dark and the inn's windows be the warmest thing for a hundred metres. | Lift the ambient until the snow glows blue on its own: a lit field is a stage, not a winter night. | `map00_crossroads_after` vs `_before`: the road and the field drop into frost shadow; the windows, the lantern by the door and the wreck's glow stay |
| Keep the fog dark, lit only where a lamp reaches into it. | Grey fog that brightens the far field and flattens the inn into the sky. | `map00_crossroads_after`: the tree line goes into `#1a2230`, not grey |
| Cold steel on the surface, warm salt below: one map, two temperatures, blended by the lift ride. | A single grade for a map with an underground: the depths go moon-blue and the salt reads as snow. | `map01_kaltenbrunn_*`; the depth zones in `data/look/map01_kaltenbrunn.json` |
| Storm green in the air, wet black on the ground, and red only on the lanterns. | A blue night everywhere: Totenhafen is not Map 0 with water. | `map02_totenhafen_after`: the sheds' walls go green-grey, the floor goes to wet black, the lanterns keep red |
| Soot in the air of a factory town: the ochre comes from the raid glow and the sodium, the shadows are brown. | Blue shadows in Thalbach (it's an industrial night, not a snowfield). | `map04a_thalbach_after` |
| Dawn blue through the windows, aluminium inside, the red bay lamps the only warmth. | Orange cabin light: der Kranich is cold at altitude. | `map04b_kranich_after` |
| Bleach the desert: lifted blacks, dusty highlights, brown shadows. | Saturated sand and a blue sky: it's the one day map and it should look tired, not like a postcard. | `map04c_groomlake_after` |
| Black and white with violet as the only colour on the Moon. | Any other hue on Mondlicht, including red: the mono rule greys it on purpose. | `map04d_mondlicht_after`: the station lamps stay violet, the Earth's blue is gone |
| The menu and the reels as an archive print: silver, grain, a gate vignette, a lifted black. | Colour in the menu's backdrop: the menu is a 1944 newsreel, the game is the colour that follows it. | `menu_after` |
| Keep Nachtglas and blood at full saturation through the grade (the LUT's `keep`). | Desaturate with `adjust.saturation` on a map with violet in it: that greys the one colour that must stay. | `map01` Core and `map04d`: violet kept, the rest grey |
| Read the frame after the grade: a zombie 20 m away separates from the ground, a buyable is brighter than its wall. | Chase mood until the HUD is the only readable thing. | `frames/25_close_zombie_before|after` (the `u05 close_zombie` camera: the risen Ganger in the stable at 3.4 m, still readable at 0.7x ambient); the `u05_objects` cameras after any grade change |
| Grain fine and monochrome, vignette oval and soft, CA at the edges only. | Coloured grain, a black-cornered vignette on a map, CA in the centre of the frame (the sights live there). | §5 |
| Warm practical lamps, cold ambient, one mercury flood opposite one sodium flood. | A violet or red lamp "for mood"; a white ambient; a blue bulb. | §8 |
| Roughness ≥ 0.45, grime ≥ 0.35, albedo saturation < 0.30 on everything that isn't Nachtglas or blood. | A clean, bright, uniform-roughness prop from a free pack dropped in as is. | §7; `tools/look/material_audit` (§2) |

---

## PART B — THE ASSET CONTRACT (unchanged from T-088 unless Part A tightens it)

## 11. Materials (the shader family)

One shader family for the world: `assets/materials/shaders/surface_pbr.gdshader` (albedo + normal + ORM, optional
height, triplanar for untextured blocks) with three shared wear parameters every material exposes:

| Parameter | What it does | Default indoors / outdoors |
|---|---|---|
| `grime` 0..1 | darkens and roughens from a world-space noise mask, strongest at the floor and in corners (`grime_height`) | 0.35 / 0.5 (never 0: §7.3) |
| `wetness` 0..1 | darkens albedo, drops roughness toward 0.15, from the same mask (melt water, blood pools, the cellar) | 0.0 / 0.2 |
| `frost` 0..1 | a pale rim on up-facing surfaces above `frost_height`, blended by the world normal's Y | 0.0 / 0.6 |

Roughness ranges per family (read from the ORM map, then clamped by `rough_min/rough_max`; the floors are §7.1's):

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

## 12. Scale

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

## 13. Budgets

| Asset | Triangles | Textures | LODs |
|---|---|---|---|
| Viewmodel gun | ≤ 25 000 (hero ≤ 35 000 for the wonder weapons) | 2K set, 1K for attachments | none (always close) |
| Zombie body | ≤ 8 000 + ≤ 3 000 per outfit kit piece | one 2K atlas per kit | LOD1 at 15 m (50%), LOD2 at 35 m (25%), impostor crowd past 24 active |
| Hero character (squad, Jakub, the Cousins, the named people) | ≤ 20 000 (T-134; people.json budget.hero_tris 19 600) | 2K body + 1K head | LOD1 at 20 m |
| Prop | 200–3 000 | 1K (512 small) | auto LOD (import preset) past 1 000 tris |
| Tree | LOD0 ≤ 4 000, LOD1 ≤ 1 200, impostor card past 60 m | 1K bark + 1K branch atlas | required |
| World block (generator) | whatever the box is | the material library, triplanar | merged by StaticBatches |
| Hero landmark (GRAVELIGHT ONE, U12 §5) | LOD0 ≤ 60 000 all parts, LOD1 ≤ 20 000, LOD2 ≤ 6 000, an impostor from the inn | 2K fuselage + 2K wings + 1K cockpit + 1K cabin | required; ArtCollider hulls (T-188) |

Frame budget (docs/gravelight/PERFORMANCE.md): 60 FPS on High at round 15 with 3 bots, Jakub and 24 zombies; the
scene is CPU-bound, so **draw calls and shadow casters** are what art spends, not triangles. Repeated props (bottles,
bales, fence posts, trees, casings) go through MultiMesh; everything static shares materials from the library so
batches merge; nothing new casts a shadow from an omni light unless it is bigger than a chair. The post stack (§5)
is one full-screen pass and the grade is a 32³ LUT: neither costs a draw call per object, and the web profile
drops what the U09 §2d budget says.

## 14. Naming

- Files and folders: `<kind>_<name>_<variant>` in lowercase snake case: `prop_crate_military`, `tex_floorboards_worn`,
  `char_zombie_villager_m`, `vm_arms_dutch`. Variants are `_a/_b`, `_broken`, `_snow`, `_lit`.
- Third-party folders: `assets/third_party/<source>/<asset-id>/` (kebab-case id, exactly the source's) with
  `LICENSE.txt` and `SOURCE.txt`; the generated manifest reads those (`python tools/assets_manifest.py`).
- Material keys (MaterialLibrary / `data/gravelight/materials.json`): plain nouns, `floorboards`, `planks`, `plaster`,
  `plaster_upper`, `fieldstone`, `shingles`, `iron`, `canvas`, `burlap`, `wool`, `leather`, `snow`, `ice`,
  `frozen_mud`, `dirt`. A map-specific variant suffixes the map: `plaster_map01`.
- Prop keys (`data/gravelight/props_library.json`): `barrel_wine`, `crate_wood_a`, `lantern_oil`, ... noun first.
- Look files: `data/look/<map_id>.json` (the MapRoot `map_id`), plus `menu`, `cinema_reel`, `_web`. Style frames:
  `docs/look/frames/<map_id>_before|after.png|jpg`.
- **GLB node names are a contract.** A weapon GLB (weapon_models.gd) names its moving parts `Mag`, `Bolt`, `Slide`,
  `Pump`, `Cover`, `Barrels`, `Crank`, `Rocket`, `Valve`, its points `Muzzle`, `LeftHand`, `SightPoint`, `FrontSight`,
  and its root carries the metas `reload`, `length`, `port`, `bore`, `grip_r`, `grip_r_radius`, `lh_axis`,
  `lh_radius`, `cylinder`, `scope`. A character GLB uses the Godot humanoid profile's bone names (ZOMBIE_ANIM_SPEC §1).
  A prop GLB's root is the prop; a `Collision` child is ignored (collision is the generator's job, UPDATE_05 §0.4).

## 15. Readability (keep what works)

Buyables, windows and doors must read before anything else in the frame, and they already do: wall-buys are chalk
outlines with the gun mounted and a price; doors carry a price plaque and the bought/locked colour; barricade windows
show their boards and the blue snow-light beyond; crate spots have the lantern; perk machines each have one unique
silhouette, sign and bottle; ammo boxes are the olive tin with the stencil. New art **keeps those shapes and colours**
and never puts a prop within 0.6 m in front of any of them (MAP0_POLISH.md's rule). Check with the dev console's
interaction colouring after every dressing pass. Nothing decorative is brighter or more saturated than a buyable.
The grade (§6, §8.3) never takes a buyable, a pickup or a zombie below the wall behind it.

## 16. How to add an asset

1. **Licence first.** CC0, ours, or CC-BY with the credit line copied from the page. Never NC, editorial, NoAI,
   rips or anything from a commercial game. If in doubt, don't.
2. **Fetch into quarantine.** Each download in its own folder under `tools_src/_downloads/<name>/` (git-ignored);
   parse with `python -I`; never run anything from inside an archive. CC0 textures / Poly Haven props: add a line to
   `data/gravelight/art/cc0_assets.json` and run `python -I tools/fetch_cc0_materials.py` (re-runnable).
3. **Folder.** `assets/third_party/<source>/<asset-id>/` with `model.glb` or `textures/*.png`, `LICENSE.txt` (the
   licence text) and `SOURCE.txt` (Title / Authors / Source / File / License / Credit line / Format / Downloaded /
   Files used). Our own work goes under `assets/gravelight/<kind>/`.
4. **Normalise.** Metres, +Y up, forward −Z, pivot per §12, textures ≤ the budget in §13, normal maps OpenGL +Y, ORM
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
   `test_prop_library` (every key resolves and loads), `test_look_grade` (the grades still load), then
   `tools/asset_report.sh` for the tris / texture-memory numbers, and the smokes your change touches (always
   `smoke_map00`).
9. **Look at it.** `tools/capture.sh` with `--set=u05 --label=<section>` renders the fixed camera list; compare
   against `before` with `python tools/compare_shots.py before <section>`. For the look: `tools/look/style_frames.sh`
   and the §7 / §8 rules against the frame, then the material audit (§2 of UPDATE 12).
