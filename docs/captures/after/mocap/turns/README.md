# Recorded stationary turns — 2026-11-11

Watch `comparison.mp4`: left is the prior turning blend, right uses the cleaned recording.
Both retain the current mocap gaits/idles and the identical gameplay-facing function. The tool
turns left 45 degrees, then returns right 45 degrees. This is not a new character model.

Run from the zombie worktree:

```powershell
./tools/zombie_turn_compare.ps1 -Godot <installed-Godot-console-executable>
```

For an interactive preview, run `res://tools/zombie_turn_check.tscn` in Godot. For numerical
verification use `--headless --audio-driver Dummy --fixed-fps 60 --path .` followed by that scene.
Add `-- --interrupt=move` or `-- --interrupt=attack` for the interruption checks. `--legacy-zombie-turns`
disables only the new turns for comparison; `--legacy-zombies` also disables all other mocap.
Default report directory is `check/`; pass `--out=res://...` to preserve a separate report.

## Executed checks

- Blender 5.1.2 headless: two additional derived clips from the already-owned left/right 45-degree
  recordings. Factoring hip yaw into Root reconstructed every sampled world-space bone position
  within 1e-6 m. The original raw turn conversions remain available. No new poses were authored.
- Godot 4.7.2 headless import: 30/30 clips passed shared-rest, finite-pose and identity-pose checks;
  both new Root rotation tracks matched their exported curves at 60 Hz.
- Studio before/after: max visual heading increment **11.2500 -> 1.7943 degrees/frame** at 60 Hz.
  Gameplay heading matched the original response within **0.000006 degrees**.
- New stationary turns: **175 source-contact samples**, planted-toe horizontal drift p95
  **0.008172 m/s**. Headless and rendered checks agree. Blending into the turn is excluded from
  the contact metric; it is not a claim of zero sliding on every transition or terrain type.
- Movement and attack interruptions: passed; presentation offset clears and the attack state
  takes priority. Their 11.25-degree maximum includes the unchanged subsequent gameplay turn.
- Unit regression also exercises both directions at 35/45/60 degrees, actual AnimationTree root
  extraction, foot contact, attack interruption, original gameplay speed, and pool reuse.

## Runtime scope and limitations

The visual-only `Turn` AnimationTree state runs below the existing 0.5 m/s threshold in CHASE
and TO_WINDOW, with requests between 25 and 65 degrees. The body continues to face using the
original response. The pivot temporarily compensates for that rotation and follows the recorded
yaw curve over the source clip's 1.267 seconds. The hip track is de-yawed, preventing a double turn.
Contact IK operates after the pose and root compensation; angle scaling changes root yaw only.
Movement, attacks, crawling, other states and significant target changes cancel the turn; residual
pivot compensation decays. All tuning lives in `data/gravelight/zombie_mocap.json`.

This does not provide a new 90/180-degree recording, moving turns, or a full co-op acceptance.
The puppet hook receives observed snapshot yaw instead of the host's intended destination:
small interpolated snapshot increments can remain below the trigger and not start a turn.
Finish that behavior and verify it with actual host/client traffic before claiming identical
network presentation. The recorded clips and host-side behavior are verified; packet timing
and stairs/rubble/special-body coverage remain open for the next owner.

Visual review of the captured soldier sequence: stationary turns **2 -> 3/5**. The body/clothes
remain simplified (**model 2/5**); this does not meet full premium acceptance. Raw frame PNGs
and verbose logs remain local; compact videos and numerical reports are committed.
