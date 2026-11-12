# Recorded swipes and deaths — 2026-11-09

Open `swipe_l_comparison.mp4`, `swipe_r_comparison.mp4`, `death_sit_comparison.mp4`
and `death_back_comparison.mp4`. Each has legacy on the left and current on the right,
with the same soldier, camera and seed. This uses the real state callbacks, AnimationTree
and ragdoll on a lit floor; clip selection is forced. It does not test player damage/range.

The two swipes are trims of one purchased arm-loop performance, with the reviewed strike
retimed to 0.45 s. Actual gameplay windup remains per enemy, followed by the existing
0.35 s recovery. Tests also exercise 0.30 and 0.65 s windups and client-style presentation.
The captures hit at the same 60 Hz physics tick as the legacy version (0.4667 s for the
0.45 s threshold, due to accumulated tick rounding).

The original logical/network death names and indices remain intact. `death_sit` uses
`mco_death_back`, handing off at 1.0 s; `death_back` uses `mco_death_hit_back`, at 0.4 s.
Recorded root travel moves the visual pivot; per-bone linear/angular motion continues into
physics, with limits in `data/gravelight/zombie_mocap.json`. Pool reuse resets the pivot.
Immediate maximum bone displacement at both handoffs was 0.01089 m or less. This checks
handoff continuity, not every possible pose pop or collision arrangement.

Each case's `state.json` records actual events. The capture tool normalizes the ragdoll's
wall-clock freeze timer to simulated time so slow PNG writes cannot freeze it early.
Production timing is unchanged. Final renders contain no script/engine/leak errors;
the known Unicode/NUL startup warnings remain. Raw frames/logs remain ignored locally.

Repeat silently/offscreen from this worktree:

```powershell
./tools/zombie_state_compare.ps1 -Godot '<installed Godot console executable>'
```

Individual case, including headless checks:

```text
godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/zombie_state_check.tscn -- --case=death_back --out=<absolute output directory>
```

Visual review on the existing Ganger/soldier: the two swipes **2 -> 3/5** and the two
recorded death presentations **2 -> 3/5**. The model remains **2/5**; these clips do not
complete the full attack/death roster or the premium art target.
