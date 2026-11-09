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
