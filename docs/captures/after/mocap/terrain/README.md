# Terrain and body matrix (2026-11-12)

`tools/zombie_terrain_check.tscn`, headless at a fixed 60, 24 s a case, live AI on real collision, poses read at
`Skeleton3D.skeleton_updated` (the final pose, with the foot IK).

- `terrain_baseline.json`: the runtime as committed (bf395bc3 + the co-op turn slice). 22 cases x 5 lanes.
- `terrain_trial_tilt_and_eased_release.json`: the same run with two trial changes that were NOT kept (a foot tilt
  from the ground normal; an eased contact-lock release). Kept for the comparison in PROGRESS.md only.

Columns worth reading first: `playback_rate_p50` (how far from its recorded cadence the gait is played),
`toe_height_p05_m` / `p95` (the toe against the ground under it inside the recording's contact windows; the flat
lane is the control), `slip_p95_mps` (a planted toe's horizontal speed; values near 11 are the contact lock's
one-frame release), `pose_steps_over_30_deg` with `pose_steps_over_30_by_bone_and_phase`, `stuck_s`, `trips`.
Numbers only: nothing here was looked at rendered.
