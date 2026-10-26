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

## UPDATE 05 section 6, the VFX pass (T-095)
Same scene (perf_marks, High, round 15, 3 bots + Jakub, 24 zombies, marks), RTX 5090, with three other builders'
Godot processes sharing the machine, so single runs swing by ~10 FPS:
- before (master 3029025): avg 51.4 FPS, 1% low 23.8, worst 46.2 ms, 4 frames over 40 ms.
- after (T-095 pools: flashes, casings, impact debris, near snow, far snow, beam motes, west fog, noise flicker),
  three runs: avg 55.3 / 40.7 / 52.1 FPS, 1% low 34.2 / 19.5 / 27.2, frames over 40 ms 0 / 21 / 1.
  Median 52.1 vs 51.4 before: no drop beyond the machine's noise. Every T-095 pool is preallocated (GUT test_vfx
  counts Effects' nodes before and after 500 shots' worth of everything) and the flash lights are capped at 4
  (2 on Low). Particles stay CPUParticles3D for the one-shot bursts (dozens of tiny emitters with a mesh swap per
  burst, which GPUParticles3D cannot do without a buffer rebuild); the continuous layers (near / far snow, beam
  motes) are GPUParticles3D. `vfx_quality` low halves counts and drops the smoke wisps.

## UPDATE 05 section 3, the modelled zombies (T-091)
Same scene (perf_marks, High, round 15, 3 bots + Jakub, 24 zombies, marks), RTX 5090, other builders' Godot
processes on the machine (single runs swing 20+ FPS), three runs each, alternating:
- pre-T-091 procedural bodies (`-- --legacy-bodies`): avg 63.3 / 67.1 / 84.3 FPS (median 67.1), 1% low 27.5 / 35.7 / 53.8.
- modelled bodies, no LODs (`-- --body-lod=none`): 64.7 / 60.8 / 68.4 (median 64.7), 1% low 29.9 / 35.0 / 34.0.
- modelled bodies with Godot's mesh LODs (the default, `--body-lod=auto`): 58.7 / 77.8 / 87.8 (median 77.8), 1% low
  31.9 / 45.9 / 59.5, no frame over 40 ms.
The scene is CPU-bound, so ~9k-triangle bodies cost little; the generated LODs win back what they add. Still two
draw calls per body (plus a gear piece or two, as before). The scripted LOD meshes in the GLBs (`Body_LOD1/2`) are
not used at runtime: swapping them needs two more skinned MeshInstance3D per zombie (each skinned every frame
whatever its visibility range), while Godot's LODs are index buffers on the same mesh. They stay in the GLB for
other tools and the people builder.
