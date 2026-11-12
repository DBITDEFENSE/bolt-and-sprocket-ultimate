# Zombie clothing material checkpoint — 2026-11-09

`soldier_comparison.jpg`, `miner_comparison.jpg` and `sailor_comparison.jpg` show the previous
material on the left and the current one on the right. Same camera, pose, seed and lighting.
This is a modest detail improvement; the existing model quality remains **2/5**.

The existing CC0 Fabric031/Leather014 normal and ORM maps now supply zombie cloth/leather
surface detail. Colour, roughness and normal detail share rest-space projections that follow
deformation. The derivative tangent frame needs no extra vertex attributes, mesh surfaces or
textures created by this pass. Normal strength, roughness floors and repeat scale live in
`data/gravelight/zombie_materials.json`. People keep their previous material settings; a
regression verifies material separation and the severed sleeve's material retention.

The shader reconstructs normal Z from RG, matching Godot's normal-map compression contract.
The source RGB unit-length diagnostic is retained in `blender_maps.json` but does not reject
resampled normals whose RG data is valid. [Godot spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).

Executed checks:

- Blender 5.1.2 headless: four maps, finite pixels, matching 1024x1024 normal/ORM sizes,
  valid non-flat RG normal data; zero failures.
- Godot: 45 zombie tests / 2,679 assertions, 859-script scan / zero failures,
  license gate 4 tests / 367 assertions; asset manifest current (108 folders).
- 24-active near-player rendered real-time soak, 60 s: frame interval p95 **4.7619 ms**;
  synchronous zombie callback CPU p95 **0.155 ms/actor/frame**. Both within configured budgets.
- Fixed-60 headless motion acceptance, 60 s: **50,255** source-contact samples,
  planted toe drift p95 **0.012804 m/s**, root/body mismatch p95 **1.0104%**. Minimum 24 active,
  zero missing clips or sampled rest poses, 83,520 pose samples in each soak.

Hardware: Ryzen 7800X3D / RTX 5090. These are local studio results, not a mid-range GPU or
full-map certification. A headless license check overlapped part of the rendered run; do not
attribute the small timing difference from older runs solely to the shader. Fixed-step timing
is not a performance result. Ragdolls are checked separately by the state captures and map smoke.

The first prototype failed shader compilation because one sampler helper mixed filter modes;
separating the ORM helper fixed it. The texture audit initially applied an RGB-unit-vector rule
to data decoded from RG; its corrected RG validation passes. Final render logs contain no
shader/script/engine errors. Known Unicode/NUL startup warnings remain.

Reproduce a still (add `--legacy-zombie-materials` for the left side):

```text
godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --fixed-fps 60 --path . res://tools/zombie_gallery.tscn -- --clip=mco_idle --kit=soldier --material-closeup --capture --out=<output directory>
blender -b --factory-startup --python-exit-code 1 -P tools/blender/zombie_material_audit.py
```

Final soak reports are in `../acceptance_materials_rendered` and `../acceptance_materials_motion`.
Earlier state videos document the attack/death pass before this material addition. No new base
mesh, garment design, tear topology, full texel-density/LOD or per-type art sign-off is claimed.
