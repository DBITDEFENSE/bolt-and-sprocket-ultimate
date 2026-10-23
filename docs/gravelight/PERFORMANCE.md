# GRAVELIGHT performance notes (Update 04, DECISIONS T-070)

## Measuring
`gravelight/tools_src/perf_marks.tscn` is the measuring scene: Map 0 at round 15 with the minimap, 3 bots and Jakub, 24
zombies kept alive and marks in play, with vsync off. It prints the average FPS, the worst frame, the 1% low, the
frames over 40 ms, the minimap's µs and the brains' ms. The flags go after `--`:
- `--breakdown`: render CPU/GPU per frame, physics steps, draw calls, a census of lights, geometry and areas, the
  shadow casters by place, the shadowed lights (and which of them move), and for each slow frame its pipeline
  compiles by kind and the nodes added. This costs about 1 ms a frame, so take headline numbers from a plain run.
- `--probe`: the cost per script of `_process` and `_physics_process`.
- `--ab=a,b`: diagnosis experiments (`no_omni_shadows`, `omni_dp`, `no_shadow_proxy`, `hide_zombies`, `no_sdfgi`, ...).
- `--preset=medium|low`, `--mm-bench` (the minimap's parts timed in a tight loop), `--compiles`.

Rendered runs open a window on the user's screen, even at `--position -4000,-4000`. Ask the user before doing one.

## Where the time went (Map 0, RTX 5090, Safe render thread)
The scene is CPU-bound: the GPU takes about 3.5 ms a frame. Shadowed omni and spot lights cost about 4.6 ms of a
~11.5 ms frame. The inn's 10 cube-shadow lamps re-render all six faces whenever anything in range moves, and with 24
zombies plus the squad that is every frame. Dual-paraboloid omni shadows cut it to ~9.5 ms, but they look worse, so
they are not used. Scripts take about 6 ms: zombies 2.7 ms (24 of them), the 4 brains 1.5 ms, then players, HUD,
minimap and ambience. The 100-150 ms spikes were first-use shader compiles. The first wound decal cost ~95 ms, the
first severed piece ~110 ms, and the first ReactiveFx glass ~320 ms. Each spike was followed by a physics catch-up
frame of ~50 ms.

## What the pass changed
- `RenderWarm` (`gravelight/world/render_warm.gd`): at map load it draws each of those materials once at 1/1000
  scale in front of the camera. Other systems add their own with `RenderWarm.add_provider(f)`.
- `ShadowProxies` (`gravelight/world/shadow_proxies.gd`): the map's StaticBatches cast their shadows through a few
  merged depth meshes (positions + normals, grouped per cell, cull mode and layers). This took draw calls from about
  5000 to 3600 and frame time from about 13.4 to 11.5 ms. Screenshots before and after differ no more than two
  plain shots do.
- Minimap: the bezel is retained, and zombie dots, marks and colours go through lean paths. It went from about
  300-360 µs to 190-280 µs.
- HUD and co-op HUD: font-colour overrides are only set when the colour changes.
- The render thread stays **Safe**. `--render-thread separate` roughly doubled the FPS, but Godot 4.7.2 calls it
  experimental (crashes, instability), and with the dummy renderer it raced RID creation in GUT.

## Follow-ups
- Landscape/Batches (82 casters) could get proxies too. They weren't measured because rendered runs were stopped.
- More first-use visuals could warm up through providers: powerups, crate weapons and weapon models.
