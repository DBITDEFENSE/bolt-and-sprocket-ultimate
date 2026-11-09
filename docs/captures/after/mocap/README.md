# Licensed mocap verification

Run from the zombie worktree:

```powershell
./tools/zombie_mocap_build.ps1 -Godot '<installed Godot console path>' -Blender '<installed Blender path>'
```

Config: `data/gravelight/zombie_mocap.json`. Original FBXs and converted GLBs are ignored licensed
files. The command requires the owner-supplied pack in the configured source folder; it installs
or downloads nothing. Keep the generated manifest beside the GLBs.

`conversion.json`: Blender hashes, contacts, loop seams and root distances, all 26 sources.
`godot_import.json`: actual imported rests/durations/track targets checked. The import hook
attaches BoneMap; no second rest normalization is applied. Metadata alone does not retarget;
Blender performs that work.

Native close-up preview (silent off-screen window):

```text
<Godot> --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --fixed-fps 60 --path . res://tools/zombie_gallery.tscn -- --kit=soldier --clip=mco_fast_chase --follow --capture --frames --out=res://docs/captures/after/mocap/native_fast
```

Local PNG/video sequences are visual evidence, not performance benchmarks. Previews bypass
gameplay transitions. The first native capture contained a tool-only initial rest frame; the
viewer now evaluates the clip immediately before capture. Full gameplay captures must follow.

## Current runtime evidence

Upright mocap is enabled. Current speed/jitter values in `enemies.json` are unchanged.
The six controlled before/after tier videos are in `../mocap_compare/`; left is legacy motion,
right is current. Full results and limitations: `docs/ZOMBIE_OVERHAUL_PLAN.md`.

Each acceptance folder contains `horde.json` and the exact runtime library inventory. Commands
below run from the worktree; rendered commands must keep the silent/off-screen options above.

```text
# Contact correctness (fixed timestep, not a performance measurement)
<Godot> --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/zombie_gallery.tscn -- --horde --full-rate --emerge --near-player --seconds=60 --verify-motion --out=res://docs/captures/after/mocap/acceptance_motion

# Real-time local performance (omit --headless for the rendered run)
<Godot> --headless --audio-driver Dummy --path . res://tools/zombie_gallery.tscn -- --horde --full-rate --emerge --near-player --seconds=60 --verify-performance --out=res://docs/captures/after/mocap/acceptance_headless
```

`--near-player` keeps the track close enough to exercise normal IK/look-at gates and wraps actors
before they reach melee range. Wraps reset only the tool's progress/contact/root measurement state.
Thresholds live in `data/gravelight/zombie_mocap.json`. `--legacy-zombies` selects the existing
fallback library for an A/B. Missing licensed local imports also fall back, so fresh clones remain
playable but require the owner-supplied pack plus build command to enable mocap.

Final local checks: `smoke_zombie_anim.tscn` PASS, `zombie_ragdoll_check.tscn` 9 admitted/peak 6,
42 zombie GUT tests / 2,550 asserts, 858 scripts / zero failures. Startup Unicode/NUL warnings
remain. Source clips sampled at 60 Hz have no identity/nonfinite poses; this is not certification
of every possible semantic T-pose, abrupt transition or animation pop in the full game.
