# CLAUDE ZOMBIES performance: the minimum spec, the targets, how to measure

UPDATE 09 §2d (DECISIONS T-139). The older, Map-0-only notes (Update 04 and 05: RenderWarm, ShadowProxies, the
modelled zombies' LODs, the VFX pools) are in `docs/gravelight/PERFORMANCE.md`.

## The minimum spec

A laptop with **Intel Iris Xe** (11th-13th gen Core) or **AMD Radeon 680M** (Ryzen 6000) integrated graphics, at
**1920x1080**, 16 GB RAM, a recent Chrome / Edge / Firefox for the browser build.

## The targets

| Build | Preset | Target | Load |
|---|---|---|---|
| Desktop (Windows, Forward+) | **Low** | **60 FPS** | 24 zombies, 3 bots, the map's companions (Jakub + the T-135 companion), round 15, on every map |
| Browser (Compatibility / WebGL 2) | **Browser** (`web`) | **30+ FPS** | the same |

Budgets per zone (contract C4; the map builders check them with `perf_marks --breakdown`): at most 2500 draw calls
in view, 6 shadowed lights per zone, 400k triangles in view on the desktop and 200k in the browser.

First launch picks a preset from the GPU (`GLSettings.auto_detect_preset`, T-139): integrated or software GPU ->
Low, a discrete NVIDIA / AMD card -> High, unknown -> Medium, the Compatibility renderer (the browser) -> Browser.
Settings > Video can change it at any time; nothing is picked again once a preset is saved.

## How to measure

1. **On the owner's PC (a real GPU), the real FPS:** play with `--frame-log` (the launcher forwards it); it writes
   `logs/frame_log_<time>.csv` with a row a second (FPS, p99, CPU / GPU ms, draw calls) and every spike.
   `gravelight/tools_src/perf_marks.tscn` is the fixed scene (round 15, 24 zombies kept alive, 3 bots, Jakub,
   marks): `-- --map=<map id> --preset=low|medium|high|web`, `--breakdown`, `--probe`. Rendered runs open a window:
   only with the owner's OK.
2. **Headless, anywhere (no window):** `tools/perf_census.sh [maps] [preset]` runs perf_marks with the dummy renderer
   for every map: the lights, shadow casters, shadowed lights per zone and the CPU cost of every script per frame
   (`--probe`). The FPS it prints is CPU-only (no rendering) and swings with whatever else the machine runs.
3. **Rendered but invisible (WSL / Linux + Xvfb, contract C8):** `wsl.exe --cd <repo> -e bash tools/wsl_perf.sh
   [maps] [presets]` runs perf_marks in the Linux Godot under Xvfb in software GL (Mesa llvmpipe): `web` on the
   Compatibility renderer (what the browser runs), any other preset on Forward+ through lavapipe Vulkan. Draw calls,
   objects, triangles, lights and shadow casters are real; the FPS is not (software rendering).
4. **The web build's size:** `tools/build_web.sh` prints the table; `python -I tools/pck_sizes.py <pck>` lists a
   pack by folder.

## What the UPDATE 09 pass changed (T-139)

- **The browser profile** (`gravelight/world/web_profile.gd`, the `web` preset, applied on the Compatibility
  renderer): no SDFGI / SSIL / SSR / SSAO / volumetric fog (depth fog of the same colour instead, or the map's own
  fog a little thicker), FogVolumes hidden and the code-built ones never made there (their shader can't compile on
  OpenGL), sun shadows to 40 m, no MSAA, at most 4 shadowed omni / spot lights per zone (nearest the spawn), zombie
  animation LOD distances halved, particles and snow halved, textures capped at 1024 px at export.
- **The bank branch** (T-136) built its counter, grille, ledger, lamp housing and safe from ~65 separate boxes and
  cylinders, every one a draw call and a caster in the bank lamp's cube shadow. They are merged into one mesh per
  material at load: Kaltenbrunn's branch went from 67 shadow casters to 14 (the map's shadow-casting geometry
  instances 709 -> 659). It looks the same (same meshes, same materials, same places).
- **The people's procedural posing** (`PatronBody`, the T-134 people: patrons, the Cousins, the teller, the survivors)
  now uses the zombies' animation LOD: every frame within 15 m of the camera, every 2nd frame to 35 m, every 4th
  beyond (anim.json lod; halved in the browser). The state (blends, flinch, the fall) still runs every frame.
- **Compatibility guards**: screen-space AA / TAA are not set on the Compatibility renderer (it warned on every
  apply), the SSAO / SSIL / SDFGI / volumetric quality calls are skipped there.

## Results (2026-11-01)

### Rendering census, the browser preset (WSL + Xvfb, Compatibility renderer, llvmpipe)

`tools/wsl_perf.sh <map> web` (perf_marks `--quick`: round 15, 24 zombies kept alive, 3 bots + Jakub + the map's
companion, the player at the map's spawn, 6 frames averaged after the census). Per frame, **all passes counted**
(the main view plus every shadow render: the Compatibility renderer's counters don't split them).

| Map | Shadowed lights (most per zone) | Draw calls | Objects | Primitives |
|---|---|---|---|---|
| Crossroads Inn (map00), **no profile** | 17 (5) | 12,068 | 9,533 | 7,136k |
| Crossroads Inn, first profile (cube shadows, 4 cascades) | 15 (4) | 9,524 | 7,450 | 6,638k |
| **Crossroads Inn, final profile** | 15 (4) | **5,804** | **4,024** | **1,738k** |
| Kaltenbrunn (map01) | 2 (1) | 1,448 | 2,494 | 375k |
| Totenhafen (map02), **no profile** | 17 (11 outside zones: window moon shafts + 5 sea lights) | 6,253 | 4,021 | 1,015k |
| **Totenhafen, final profile** | 9 (3) | **3,303** | **3,009** | **639k** |
| Fernflug I Werk Thalbach (map04a) | 6 (2) | 868 | 1,875 | 236k |
| Fernflug II der Kranich (map04b) | 0 | 478 | 1,449 | 91k |
| Fernflug III Groom Lake (map04c) | 0 | 583 | 1,642 | 148k |
| Fernflug IV Mondlicht (map04d) | 1 (1) | 767 | 1,696 | 177k |

Against the C4 browser budget (2,500 draw calls and 200k triangles in view): the Fernflug acts and Kaltenbrunn's
draw calls are inside it; **the Crossroads Inn and Totenhafen are not** even with every shadow pass included in the
count: the inn's landscape (672 mesh pines, 3,627 impostor cards, the village) and its 15 shadowed lights, and
Totenhafen's moon shafts and sea lights. These are the next levers (below).

### CPU census, the scripts (headless, `tools/perf_census.sh`, Low)

Per frame / per physics tick (60 a second), `perf_marks --probe`; the machine was shared with one or two WSL
software renderers for every map but Map 0, so the absolute numbers run high; the proportions hold.

| Map | Scripts `_process` ms/frame | Scripts `_physics_process` ms/tick | Zombies (32 nodes) process + physics | Bot brains (n) physics | People posing (PatronBody) | Faces | Players process + physics | Shadow-casting geometry |
|---|---|---|---|---|---|---|---|---|
| map00 | 2.59 | 6.67 | 0.80 + 3.03 | 2.94 (4) | 0.33 (10) | 0.08 | 0.01 + 0.35 | 1002 |
| map01 | 3.86 | 12.64 | 1.32 + 6.37 | 4.90 (3) | 0.13 (1) | 0.10 | 0.01 + 0.62 | 659 |
| map02 | 3.77 | 13.57 | 1.75 + 7.93 | 3.99 (3) | - | 0.05 | 0.01 + 0.73 | 462 |
| map04a | 2.75 | 10.68 | 1.20 + 5.13 | 4.05 (3) | - | 0.07 | 0.01 + 0.73 | 403 |
| map04b | 2.35 | 9.19 | 1.24 + 4.94 | 3.22 (3) | - | 0.05 | 0.01 + 0.71 | 274 |
| map04c | 2.93 | 9.98 | 1.48 + 5.14 | 3.83 (3) | - | 0.06 | 0.01 + 0.87 | 358 |
| map04d | 2.17 | 8.23 | 0.88 + 3.12 | 4.26 (3) | - | 0.05 | 0.01 + 0.73 | 286 |

The T-133 smooth-motion update (the local player's camera and viewmodel in `_process`) is inside `player.gd`'s
process column: about 0.01 ms (it is off headless, so its cost is the tick path's; on a real screen it adds the
viewmodel animation per rendered frame, priced by the owner's `--frame-log`). The T-134 people's posing is
`PatronBody` (0.33 ms for Map 0's 10 people); their faces (`face_driver.gd`) 0.05-0.10 ms.

**The CPU is the risk for 60 FPS on Low** on a 4-core laptop: the scripts take ~9-16 ms a frame (zombies ~0.15-0.25
ms each per tick, the bot brains 1-1.6 ms each). Not changed in this pass: both are gameplay (AI timings, senses,
paths). Next levers if the owner's laptop numbers need it: a zombie think-rate LOD (far zombies plan every 2nd-4th
tick, as their animation already does), staggering the brains' heavy planning across ticks.

### Next levers for the browser (not done)

- The inn's landscape: shorter visibility ranges for the pines / impostor cards and the village props on the
  Compatibility renderer, or a lower impostor density.
- Shadowed lights: 2 per zone instead of 4 in the browser (the profile's MAX_SHADOWED_PER_ZONE), or zombies not
  casting into omni shadows there.
- Totenhafen: the five 60 m sea spotlights could share one shadowed light.
