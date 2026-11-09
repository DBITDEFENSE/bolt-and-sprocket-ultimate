# Zombie baseline tools

Open `tools/zombie_gallery.tscn` in the **isolated worktree's** Godot project.
Default: 24 Ganger bodies, all 14 outfit kits, cycling every clip in the existing library.
This directly previews AnimationPlayer clips, not the gameplay state machine. Special bosses
and their bespoke rigs are not yet included. Root translation remains visible in previews.

Use the installed Godot executable, with `--path` set to this worktree:

```
godot --headless --audio-driver Dummy --path . res://tools/zombie_gallery.tscn -- --horde --seconds=60
godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools/zombie_gallery.tscn -- --capture
godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools/zombie_gallery.tscn -- --capture --horde --seconds=60
```

Outputs default to `docs/captures/before/`. Set `--out=res://docs/captures/after` for comparison.
Capture requires rendering; headless capture is rejected. The window stays off-screen and silent.
The project stretch settings may produce a larger framebuffer than the requested window size.

Close-up/frame-sequence example (12 captures per second):
`--capture --kit=soldier --clip=walk_a --frames --out=res://docs/captures/before/closeup`.
`--kind=glasshide` selects a shared-rig enemy kind. Foreman and Screamer are explicitly rejected
until their bespoke rigs have their own viewer; they are never silently shown as Gangers.
Labels face the camera. Single-kit previews use a close camera; the original wide captures remain.

Add `--horde --emerge` to keep the real ground-emerge state before the first chase instead of
skipping directly to walking. This exercises deferred gait phase initialization. With captures,
the horde shot is delayed to six seconds to include the initial emerges and early strides.

Run `res://tools/zombie_ragdoll_check.tscn` headless to stress nine deaths against the six-ragdoll
budget. It fails if a new death is denied, the oldest keeps simulating, frozen corpses consume
the budget, or cleanup leaves a live registration. This checks lifecycle, not visual death quality.

Reports: runtime_inventory.json lists every loaded clip, duration, tracks, loop mode, kit and bone.
horde.json reports contact-foot velocity, timing, state-machine phase occupancy and rest-pose samples.
Contact detection uses a flat-floor height/vertical-velocity heuristic and moving bodies only;
it does not establish contact from mocap labels. No GPU claim is made by a headless run.
Rest-pose detection is not a complete pop/T-pose detector. Ragdoll_peak=0 does not test the cap.
The horde traverses a bare studio and recycles positions; it does not replace full-map benchmarks.

`zombie_asset_audit.py --source-root <main-checkout> --out <report.json>` inventories supplied assets
including ignored files, and reads GLB mesh/skin/animation metadata without importing code.
`blender --background --factory-startup --python-exit-code 1 --python tools/blender/zombie_mesh_audit.py -- --root . --out docs/captures/before/blender_meshes.json`
imports the six existing bodies and audits skinned geometry. Missing UVs are review findings:
current kit shaders may use procedural coordinates. Importer bone-display meshes are excluded.
