# Contact retention checkpoint — 2026-11-12

The mixed-horde planted-foot gate passes after retaining established contacts through brief collision stops.
This is a movement fix, not completion of the premium model/animation overhaul.

## What caused the failure

A collision could set velocity to zero for one tick. The locomotion blend moved from 1.0 to 0.9 and the old
condition immediately reset both world-space foot pins. Full-speed movement resumed on the next tick with new
pins. The feet actually moved in the final drawn pose; removing those samples would have hidden the problem.

`zombie.gd` now retains the existing recorded gait's contacts while its contribution remains at least
`contact_lock.retain_locomotion_blend` (0.5 in `zombie_mocap.json`). Entry still requires full locomotion.
Sustained idle, state fades and attacks release normally. Source motion, navigation, collision, gameplay speeds,
jitter and attack timing are unchanged. No bone animation was authored.

## The same gate before and after

Both runs: fixed 60 FPS/60 Hz physics, 60 seconds, 24 active zombies, full-rate animation, near-player terrain
modifiers. Feet are read at `Skeleton3D.skeleton_updated`, after all modifiers. The acceptance threshold and
sample-selection code are unchanged. The current callback must be full locomotion; the two sampled endpoints
can include a brief idle blend. Earlier reports incorrectly described the selection as excluding all blends.

| Measurement | Before / negative control | After |
|---|---:|---:|
| Final toe drift p95, m/s | 0.144702 | **0.012850** |
| Limit, m/s | 0.10 | 0.10 |
| Contact samples | 50,980 | 52,787 |
| Root/body speed mismatch p95 | 0.5167% | 0.8472% |
| Minimum active | 24 | 24 |
| Missing clips / sampled identity poses | 0 / 0 | 0 / 0 |
| Motion gate / engine exit | FAIL / 1 | PASS / 0 |

`horde_before.json` uses the new tool's negative control, which reproduced the original unmodified-runtime
measurement exactly. `horde_after.json` is the final runtime. Sample counts change with the resulting run;
no failing sample category is filtered out. Passing p95 does not mean every foot contact is perfect.

Diagnostics partition every gate sample:

| Category | Before samples / over 0.10 | After samples / over 0.10 |
|---|---:|---:|
| Lock absent at either endpoint | 2,143 / 2,129 | 60 / 60 |
| Re-pinned during the interval | 127 / 127 | 142 / 142 |
| Stable pin | 48,710 / 467 | 52,585 / 529 |

See `diagnosis_before.json` and `diagnosis_after.json` for distributions and the first eight failing examples
per category. They are diagnostic examples, not a random sample or the worst cases. Remaining failures include
correction-limit releases and leg reach residuals; 731 after-fix samples still exceed 0.10 m/s.

## Other executed checks

- Zombie GUT: 50/50 tests, 4,612 assertions. New final-pose regression covers a real source plant through a
  one-tick stop/restart, unchanged world anchor, then release for attack and sustained idle.
- Script scan: 860 scripts, zero failures. Imported bank: 30 clips, zero failures.
- Blender 5.1.2 headless: regenerated both chase clips, validated loops/contact cleanup, exit 0; bank remains 30.
- Stationary turn: p95 0.006314 m/s, 175 contacts, zero failures.
- Map2 zombie animation smoke: PASS, including climb, limb removal/Gore Off, knockdown/get-up, deaths, corpse
  return, distance modifier gates; worst median root/body discrepancy 1.5%.
- Ragdoll admission test: peak 6, cap 6, zero failures.
- Separate rendered performance run, 60 seconds with no capture: frame p95 **4.1667 ms**, synchronous zombie
  callback CPU p95 **0.146 ms/actor/frame**, minimum 24, PASS. `performance_after.json`.

Machine: Ryzen 7800X3D / RTX 5090. An unrelated headless Godot process remained active. This is not isolated
mid-range or full-map certification. The callback counter excludes deferred modifiers/engine/GPU work;
overall rendered frame time includes their effect. Fixed-FPS results are not performance measurements.
Known Unicode/NUL startup warnings remain; scoped logs contain no script/shader/engine/leak errors.

## Terrain and visual limits

The 22-case x 5-lane matrix completed with no lost actors or tool failures; see
`../terrain/terrain_contact_retain.json` versus `../terrain/terrain_lock_last.json`.

- Jog/run on real steps: slip p95 1.3216/16.0485 -> 0.0115/0.0132 m/s.
- Jog/run on rubble: 12.8299/13.4247 -> 0.0117/0.0092 m/s.
- Sprint remains bad on real steps/rubble: 10.8193/12.2039 m/s. Bellringer ramp20 worsened
  11.3951 -> 13.8384; thin male rubble 0.0501 -> 0.1605. No terrain-wide acceptance claim.
- Walk-case median toe height p05 on the stair-angle slope is still -0.1021 m. Landing adaptation needs work.

`sprint_studio_comparison.mp4` is an eight-second rendered flat-studio check, 24 sprinters, left negative control,
right current runtime. Capture is 12 FPS from a fixed-60 simulation. This short all-sprint case already has low
drift before the fix and is **not** the failing mixed-tier acceptance scenario. Crowding obscures some feet and
the gallery wraps actors to the track start. Sampled frames were inspected; this does not establish smoothness
through every transition or terrain case. The bodies remain visibly simplified and below the art bible.
Existing reviewed-soldier scores stay unchanged: locomotion/swipes/two deaths/turns 3/5, variety 3/5, model 2/5.

## Reproduce

Use this worktree and the Godot executable from `docs/CLAUDE_FABLE_5_2_ZOMBIE_HANDOFF.md`:

```powershell
& $zombieGodot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/zombie_gallery.tscn -- --horde --full-rate --near-player --seconds=60 --verify-motion --diagnose-contact --out=res://.mocap_work/zombies/contact_after
# Negative control: same command plus --contact-retention-off; expected exit 1 at 0.144702 m/s.
& $zombieGodot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/zombie_terrain_check.tscn -- --cases=bodies,tiers,kinds --seconds=24 --out=res://.mocap_work/zombies/contact_terrain
```

`--contact-retention-off` only changes the tool process's in-memory setting; it writes no tuning or user setting.
`--diagnose-contact` has no runtime cost when omitted beyond a tool-side flag check.

RESUME HERE: fix slope landing and sprint/Bellringer correction-limit releases, then terrain transitions/LOD
and rendered terrain review. Preserve speeds and the 0.10 gate. Continue the remaining asset/state work from
`docs/CLAUDE_FABLE_5_2_ZOMBIE_HANDOFF.md`; the owned Starter pack is already present.
