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
