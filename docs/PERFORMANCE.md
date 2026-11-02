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
   pack by folder. The split rules are in `tools_src/web_pack_lists.gd` (T-139, T-150).

### The web build's sizes (T-150, after the section 5 map rebuilds and the new main menu)

Target: under 150 MB to reach the menu; every pack at most 70 MB (static hosts cap single files near 100 MB).

| Piece | MB |
|---|---|
| Engine (wasm + js) | 37.7 |
| Main pack | 97.8 |
| html / js / icons | 0.3 |
| **To reach the menu** | **135.8** |
| game1 / game2 / game3 / game4 / game5 / game6 | 48.0 / 45.7 / 63.8 / 37.3 / 24.9 / 56.5 |
| map00 / map01 / map02 | 14.4 / 7.7 / 28.9 |
| map04a / map04b / map04c / map04d | 22.0 / 9.6 / 14.4 / 22.4 |
| **First match** on map00 / 01 / 02 / 04a / 04b / 04c / 04d | 426 / 420 / 441 / 434 / 422 / 426 / 434 |

What the menu keeps (main pack 97.8): the inn set `menu_inn.tscn` and its 63 Poly Haven / ambientCG textures (44 MB: the
set's own materials, the biggest block and the one that cannot leave), the six zombie bodies and the Marke armband,
the squad's four people (Dutch, Wren, Deacon, Peg), the menu music, the UI sounds and the sounds the menu plays
(`music_menu`, the Map 0 war ambience the menu patches, the radio and gramophone), the map previews, fonts, scripts and
data. Everything else is deferred: the other 21 people and the six `human_base` bodies, all other music, stingers and
sounds (game packs), and each map's own beds, ambience one-shots and textures (that map's pack).

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

### Rendering census, the desktop Low preset (WSL + Xvfb, Forward+ through lavapipe Vulkan)

`tools/wsl_perf.sh map00_crossroads,map02_totenhafen low` (the same scene; Forward+ in software is very slow, so
only the two heaviest maps were run). All passes counted, cube omni shadows (the desktop keeps them).

| Map | Shadowed lights | Draw calls | Objects | Primitives |
|---|---|---|---|---|
| Crossroads Inn (map00) | 17 | 7,042 | 9,767 | 7,161k |
| Totenhafen (map02) | 17 | 2,825 | 4,129 | 1,025k |

On a real desktop GPU these are cheap (Update 04-05 measured Map 0 at 70-80 FPS on High on the RTX 5090 with the
CPU as the limit); on an Iris Xe the inn's 7k draw calls and 7M primitives a frame (mostly its ten cube-shadowed
lamps re-rendered as the squad and the zombies move) are the risk for 60 FPS on Low: the next lever there is the
browser profile's dual-paraboloid omni shadows for the Low preset too (owner's call: it looks worse, T-070).

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

## UPDATE 10 section 6 (T-162): the frame cost of smooth motion and the detailed people, zombies above 60 Hz

Measured headless on the min-spec profile (`--preset=low` and `--preset=web`, `perf_marks --probe`, round 15, 24 zombies
kept alive, 3 bots + Jakub + the companion) on map00 and map01. The machine was shared with 30+ other Godot processes
(other workers), so single runs swing by 15%; the proportions are what counts.

| Per frame / tick (ms) | map00 low | map00 web | map01 low | map01 web |
|---|---|---|---|---|
| Zombies `_process` (32 nodes), smoothing off | 0.945 | 1.016 | 1.009 | 0.999 |
| Zombies `_process`, smoothing on (`--ab=zsmooth`) | 1.014 | 0.929 | 1.046 | 0.871 |
| Zombies `_physics_process` (32 nodes) | 3.31 | 3.35 | 3.08 | 3.03 |
| People posing (`patron_body.gd`) | 0.58 (13) | 0.61 (13) | 0.29 (6) | 0.29 (6) |
| Faces (`face_driver.gd`) | 0.14 (18) | 0.15 (18) | 0.11 (10) | 0.12 (16) |
| Players, all six incl. their weapon holders (`player.gd`) | 0.008 + 0.41 | 0.009 + 0.41 | 0.007 + 0.39 | 0.006 + 0.36 |

- **The T-133 smooth motion** (the local player's camera and viewmodel in `_process`) is 0.01 ms a frame of script; the
  bots' and Jakub's weapon holders are inside `player.gd`'s 0.4 ms for six players, i.e. about 0.07 ms a player: there is
  nothing left to win by skipping the invisible viewmodels, so it was not touched (it would risk the reload cues).
- **The T-134 people**: the posing already runs at the zombies' animation LOD (T-139: every frame within 15 m, every 2nd
  to 35 m, every 4th beyond). The faces now use the same LOD (`PatronBody.lod_div`, `FaceDriver._process` steps with the
  time it skipped, so the blink and lip flap stay in time). In the perf scene most faces are inside 15 m, so the
  measured change is inside the noise (0.14 -> 0.14 ms); it pays when the camera is far from the crowd.
- **Zombies above 60 Hz** (`Zombie.smooth_motion`, GLSettings `zombie_smooth`, default on, Settings > Video > "Smooth
  zombies"; never on headless): the Pivot (the visible rig) is offset each rendered frame to the position interpolated
  between the tick's start and end, within the full-rate animation distance; collision, hitboxes and every gameplay timer
  stay on the 60 Hz tick (the visual leads the body by under 7 cm at a sprinter's speed). Global physics interpolation
  stays off (many nodes are moved in `_process`). **Cost per zombie**: `tools_src/bench_zombie_smooth.tscn` (32 zombies, 3000
  frames, the added per-frame work only): **0.44 us before, 1.05 us after, +0.6 us per zombie per rendered frame** (+0.02
  ms a frame for 32); the `--probe` columns above agree: the difference is under the 15% noise. On the web preset it
  stays on (it is cheaper than one skipped zombie animation frame).
- Draw calls: neither change adds a draw call or a node (the census in the section above stands: map00 5,804 / map01
  1,448 on `web`).
