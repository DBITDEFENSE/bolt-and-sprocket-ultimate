# T-281: lag that grows with the zombie count (2026-11-25)

The owner: "the more zombies the more lag i get find the cause and fix it. game should never go under 60 fps".
Branch `claude/zombie-perf`, cut from master `25deacbd`. Not merged, not pushed.

Everything here is headless (no window may be opened on this PC). The PC was shared all session: other workers ran
GUT suites, smokes and WSL software renders, so the CPU stood at 90 % or more before this work started a run (the
same build's 48-zombie frame read 25 to 30 ms p50 from one hour to the next). Read every millisecond below as this
machine's under that load, about 1.7 times a quiet machine's (T-256 measured the 24-zombie Map 0 frame at 8.7 ms on
the quiet machine; it read 15 ms p50 here). What the claims rest on: counts (which do not depend on the load) and
A/B pairs taken inside one run, one second a side (`perf_marks --flip`), so both sides share the load second by second.

## In short

- **The cause, named.** A zombie costs the game thread about 0.18-0.20 ms a frame on this machine under load (about
  0.11 ms on a quiet one), and almost all of it is engine work each body asks for itself: its AnimationTree's advance
  and pose (the largest part), its skeleton with the foot-IK modifier, 14 bone attachments and 18 hitbox areas that
  follow the bones, its `move_and_slide`, its foot rays, and its share of the physics and navigation servers' step.
  So the frame grows **linearly** with the zombie count, from a base of about 11 ms here (the bots, the HUD, the map's
  people and lamps) by about 0.2 ms per zombie: on Map 0 8 zombies cost 12.3 ms (p50), 24 cost 15.0, 48 cost 25.0.
- **No game loop grows quadratically.** No zombie scans the other zombies, the bots see the horde through a ray
  budget, path queries are capped per frame, the bots' brains cost the same at 8 and 48 zombies. **The one part that
  grows worse than linearly is the physics server's step on Map 0**, where the horde packs round the inn's windows
  (0.87 ms at 8 zombies, 1.38 at 24, 2.92 at 48): not avoidance (0.26 ms) and not the bodies colliding (under
  0.1 ms), but the physics server stepping the crowd of bodies and hitbox areas.
- **Waste that was fixed**, all counted: a third to a half of a full horde stands (queued at windows, tearing boards,
  staggered) and each standing body still asked the physics engine every tick to slide it nowhere (now skipped at
  rest: 8,500-9,100 slides saved per 30 s run at 48); still feet re-cast their ground rays every tick (now kept:
  5,000-9,000 feet a run); five of each zombie's 18 hitbox areas had no collision layer and still moved with their
  bones in the physics space (now out of it); every death built a 23-node ragdoll (now rigs are kept and reused); the
  animation step re-read tables and rebuilt arrays every frame.
- **Result, A/B inside each run, three runs a case, medians:** Map 0's frame 4-10 % lower at 16-48 zombies (48:
  27.6 -> 26.3 ms here), the zombies' physics scripts 9-13 % lower, the late-round mix with kills 3-6 % (zombie
  physics 10-16 %). Kaltenbrunn, where the horde spreads and chases, 2-9 % off the zombies' physics scripts and the
  frame within the noise. Nothing in gameplay or the look changed; every change is behind `Zombie.t281_opt`
  (`perf_marks --flip=t281`, `--ab=t281_off`).
- **The aim is not met.** 48 zombies on Map 0 are about 26 ms of game thread here, about 15 ms on a quiet machine,
  against an aim of under 10 ms; 24 zombies (the game's cap outside the Sherman's round) are 9-12 ms quiet. What is left
  is the engine's per-body work listed under "What is left"; cutting it further means either a visible change (a
  coarser animation rate for zombies in view at middle distance, hitboxes at the physics rate) or an engine part
  (Jolt physics), which are the owner's decisions. On the owner's RTX 5090 the frame is CPU-bound (T-258): whether 24
  or 48 zombies hold 60 FPS rendered needs the command at the end, which was not run (no window without the owner's
  OK).

## How it was measured

- **The bench** (new): `perf_marks --zombies=N` keeps N zombies up instead of 24 (the pool grows for the bench when N is
  over its 32), `--mix=high` makes them a late round's (run and sprint tiers, every 5th a crawler, every 6th a burning
  fire zombie of the Sherman's round with its light, flames and burst), `--kills=K` kills K a second (a ragdoll and a
  death's listeners each, every damage kind in turn) and puts the dead back. Round 15, 3 bots + Jakub + the map's
  companion fighting, the player in god mode at the spawn (inside the inn on Map 0: the horde queues at the windows
  and the door, as it does in a real round), 60 fixed frames a second, so a frame is one physics tick plus one process
  step and its wall time is the game thread's CPU work for a 60 FPS frame without the renderer.
- `tools/zombie_count_bench.sh <tag> "<counts>" "<maps>" <repeats> "<A flags>" "<B flags>"` runs a sweep;
  `python -I tools/zombie_count_table.py <dir> [--p50] [--prof]` prints the table.
- **Where the frame goes**: the probe times every script's `_physics_process` / `_process` (`zombie.gd`,
  `bot_brain.gd`, the rest) and the two gaps between them: after the physics scripts (the physics server's step, the
  navigation server's step and avoidance, the agents' own physics work, the deferred calls) and after the process
  scripts (animation players and trees outside the scripts, the skeletons and their modifiers, bone attachments and
  everything that follows a bone, audio, the dummy renderer). Inside `zombie.gd` a temporary section profiler
  (BotProf sections round `move_and_slide`, the AnimationTree's advance, the foot rays, the chase's steps, the
  ragdoll; not committed: it costs about 1 us a section) split the zombies' own share.
- **The A/B**: every T-281 change sits behind `Zombie.t281_opt` (on by default). `perf_marks --flip=t281` switches it
  off and on every second inside the run (the first 15 frames after each switch are not counted) and reports both
  sides; `--ab=t281_off` runs a whole build without them. The diagnostic flips `z_no_avoid`, `z_no_zcollide` and
  `z_no_dead_areas` change what the zombies do and only answer "how much does this part cost".

## What grows with the zombie count (the cause)

Before any change (master's game code, the profiler in, one run each, ms a frame, means):

| Map | Zombies (up) | Frame p50 | 1 % worst | Max | `zombie.gd` physics | `zombie.gd` process | Bots (4 brains) | After the physics scripts | After the process scripts | Other scripts |
|---|---|---|---|---|---|---|---|---|---|---|
| Map 0 | 8 | 12.34 | 48.8 | 61.8 | 1.34 | 0.74 | 2.46 | 0.87 | 1.27 | 5.31 |
| Map 0 | 16 | 13.02 | 49.4 | 69.5 | 1.78 | 1.01 | 2.36 | 1.07 | 1.52 | 4.90 |
| Map 0 | 24 | 14.98 | 50.8 | 65.0 | 2.85 | 1.51 | 2.49 | 1.38 | 1.94 | 4.37 |
| Map 0 | 32 | 17.17 | 72.5 | 95.4 | 3.66 | 1.90 | 2.61 | 1.73 | 2.42 | 4.56 |
| Map 0 | 48 | 24.96 | 92.9 | 136.8 | 5.85 | 2.95 | 3.00 | **2.92** | 3.39 | 6.04 |
| Kaltenbrunn | 8 (7) | 7.44 | 29.9 | 43.0 | 0.65 | 0.27 | 1.26 | 0.56 | 0.62 | 3.79 |
| Kaltenbrunn | 16 (14) | 9.99 | 51.6 | 84.8 | 1.63 | 0.47 | 1.30 | 0.80 | 0.90 | 4.43 |
| Kaltenbrunn | 24 (21) | 10.45 | 41.5 | 67.9 | 2.06 | 0.98 | 1.30 | 0.96 | 1.12 | 3.75 |
| Kaltenbrunn | 32 (29) | 13.48 | 59.9 | 95.0 | 3.61 | 0.99 | 1.64 | 1.29 | 1.45 | 3.59 |
| Kaltenbrunn | 48 (42) | 13.98 | 43.1 | 65.2 | 4.43 | 1.71 | 1.24 | 1.62 | 1.49 | 2.95 |
| Map 0, late-round mix + 3 kills/s | 24 (26) | 19.50 * | 89.0 | 109.1 | 3.53 | 1.59 | 3.67 | 2.84 | 2.95 | 4.45 |
| Map 0, late-round mix + 3 kills/s | 48 (50) | 29.28 * | 178.9 | 572.6 | 6.38 | 2.75 | 4.17 | 4.54 | 4.51 | 6.41 |

The parts are p50s of each part (a busy machine's spikes left out of them); "1 % worst" is the mean of the slowest
hundredth of the frames and, like the max, is mostly the machine (the tool's noise floor had single ticks of 5-45 ms
in these runs). \* mean, not p50. Kaltenbrunn recycled a few stuck bodies, hence fewer up than asked. "Other
scripts" is everything else that runs (HUD, minimap, people, lamps, a relief squad when one came: 0.8 ms in two of
the runs).

1. **The zombies' cost is linear, about 0.18-0.20 ms of the game thread per zombie on this loaded machine** (about
   0.11 on a quiet one), and it is engine work that each body asks for itself, not a loop over the others:

      | The zombies' part, 48 up on Map 0 (master, ms a frame for the horde) | ms | per zombie | grows |
   |---|---|---|---|
   | AnimationTree advance and the pose script round it (`_animate`; the engine's advance about 55 % of it) | 3.15 | 0.066 | linearly with the zombies the camera sees within 15 m |
   | Skeletons, the foot-IK / spring modifier, 14 bone attachments and the 18 hitbox areas that follow them (in the gap after the process scripts) | about 2.1 over 8 zombies' | 0.053 | linearly |
   | `move_and_slide` of the moving bodies | 2.13 | 0.044 | linearly (0.049 to 0.053 ms a call from 24 to 48: a crowd costs a call a little more) |
   | `move_and_slide` of bodies standing still (queued, tearing, staggered) | 0.76 | 0.016 | with the share of the horde that waits at the windows |
   | foot rays (4 a tick within 15 m, in view) and the look-at | 1.21 | 0.025 | linearly |
   | the chase's decisions and the nav agent's reads | about 1.3 | 0.027 | linearly |
   | physics and navigation servers (the gap after the physics scripts) | about 2.05 over 8 zombies' | 0.051 | **worse than linearly on Map 0**: see 3 |
   | a death: the ragdoll (23 nodes) | 0.78 a death, 15 ms worst | - | with the kill rate |

2. **No script loop grows worse than linearly.** Every zombie looks for its target among the 4-6 players (not among
   the other zombies), the bots see the horde through a ray budget (6 a think) and a per-frame shared list, path
   queries are capped at 6 a frame (`repath.budget_per_frame`), `active_zombies()` is not called per zombie per
   frame. The bots' brains cost the same at 8 and at 48 zombies (2.4-3.0 ms p50 for the four). The one quadratic loop
   found (`BotAim.grenade_spot`, known zombies against known zombies) runs only when a bot considers a grenade.
3. **The one part that grows worse than linearly is the server step after the physics scripts on Map 0**: 0.87, 1.07,
   1.38, 1.73, 2.92 ms (p50) at 8, 16, 24, 32, 48 zombies, the last step doubling for half again as many bodies. It is
   **not** avoidance (switched off inside one run at 48: -0.26 ms) and **not** the zombies' bodies colliding with
   each other (switched off: under 0.1 ms). What is left in it is the physics server stepping a crowd of bodies and
   their hitbox areas packed round the inn's windows (the space's pairs went from 76 at 24 to 151-183 at 48). On
   Kaltenbrunn, where the horde spreads, it grows linearly (0.56 to 1.62 ms).
4. **Work done for bodies that do nothing** (fixed): a third to a half of a full horde stands (queued at a window,
   tearing boards, staggered, getting up) and every one of them asked the physics engine every tick to slide it
   nowhere; each still foot cast its two ground rays every tick onto the same ground; five of every zombie's eighteen
   hitbox areas (the Marke and wound sites that are not this body's) had no collision layer and were still moved with
   their bones in the physics space at every animation step.
5. **A death builds nodes** (fixed for the ragdoll): every ragdoll was 23 new nodes (11 physical bones, their shapes,
   the simulator) built in the frame the corpse fell, 0.4-1.1 ms each, several in one frame when a grenade lands.

## What changed

All in the zombie's own files, all behind `Zombie.t281_opt` except the last (which is the same code written cheaper):

| Change | Where | What it does | Why it is the same |
|---|---|---|---|
| **A halted body at rest skips its slide** | `zombie.gd` `_halt`, `_at_rest` | When the body has no velocity on the flat, is on the floor (and not about to step off another zombie's head), is not on a moving floor, has not been moved by anyone since its last real slide and that slide moved it by nothing, `move_and_slide` is not called. Every 10th tick it slides for real all the same. | A slide at rest presses the body into the floor it stands on and returns it where it was (checked: the same position to the float, `test_t281_zombie_count`). Other zombies cannot push a kinematic body; anything that moves it (a relocation, a step up, a push, a hit's knockback, a death) changes its position or velocity first and the next tick slides. |
| **Weak-point boxes that are not live leave the physics space** | `zombie.gd` `_marke_layers` / `_weak_box_live` | The Marke's two sites and the four wound sites: the body's live one keeps its layer and stays; the others (layer 0) are switched off (process off removes a CollisionObject from the space). | A box with no collision layer can never be found by a ray or an area (mask & 0 = 0). |
| **A still foot keeps its two ground rays** | `zombie.gd` `_update_senses` | A foot whose ray start point moved less than 5 mm (its toe point less than 1 cm) since its last rays keeps the two hits (stored in world space) and only takes them into the skeleton's frame again. | The map's colliders do not move under a zombie's feet; the ground 5 mm away is the same ground (on a 45-degree slope at most 5 mm off). Reset at every spawn. |
| **Ragdoll rigs are kept for the next death** | `zombie_ragdoll.gd` `stop`, `_unpark`; `zombie_director.gd` `_exit_tree` | `stop()` keeps up to 8 rigs out of the tree; the next death takes one (its bodies' speeds zeroed, the collision mask back) instead of building 23 nodes. Freed with the map. | A PhysicalBone3D takes the bone's current pose when its simulation starts, and the rig is the same set of bones on every zombie skeleton (checked per bone; a rig that does not fit is freed and a new one built). The launch, the recorded fall and the cap are unchanged. |
| The animation step's lookups | `zombie.gd` `_animate`, `_update_senses` | The crack glow's table read only when the round changed; the tree's per-frame parameters by StringName; the state lists built once. | The same calls with the same values. |

Not changed: speeds, damage, hitboxes, the navmesh, spawn rules, AI decisions, any timing, the animation rates, the
look of any zombie.

## Before / after

`tools/zombie_count_bench.sh final_m0 "8 16 24 32 48" m0 3 "--flip=t281 --secs=30"` and the same for `m1`: three
runs of each map and count, each run the A/B inside itself (`--flip=t281`: one second with the T-281 changes off,
one second on, 15 frames after each switch left out, 900 frames a side). Every value is the median over the three
runs of that run's own value. ms a frame of the game thread with no renderer, at 60 fixed frames a second.

**The load.** Both maps' sweeps ran at the same time, beside this work's smokes and the other workers' GUT runs,
smokes and WSL renders: the CPU read 100 % and 13 Godot processes were up at one check. The means and the 1 % worst
and max columns carry whole seconds stolen by other processes (the tool's own noise floor, a fixed 0.1 ms loop, had
single ticks of 26-48 ms); a second stolen in an "on" second or an "off" second lands on one side only, so these
columns move by 20 % either way between runs and are **not** what the result rests on. The medians (p50) below them
are: a stolen second does not move a median of 900 frames.

Means, 1 % worst (the mean of the slowest hundredth of the frames) and max:

| Map | Zombies (up) | Before: mean / 1 % worst / max | After: mean / 1 % worst / max | Mean change | Runs |
|---|---|---|---|---|---|
| Map 0 | 8 (8) | 15.56 / 78.82 / 100.29 | 15.98 / 95.06 / 123.79 | +2.7 % | 3 |
| Map 0 | 16 (16) | 20.18 / 81.95 / 84.09 | 16.23 / 70.57 / 98.15 | -19.6 % | 3 |
| Map 0 | 24 (24) | 25.84 / 117.74 / 161.27 | 23.71 / 103.73 / 116.28 | -8.2 % | 3 |
| Map 0 | 32 (32) | 22.81 / 108.66 / 146.21 | 21.81 / 130.10 / 143.67 | -4.4 % | 3 |
| Map 0 | 48 (48) | 34.34 / 157.26 / 199.42 | 31.85 / 160.10 / 179.09 | -7.3 % | 3 |
| Kaltenbrunn | 8 (8) | 14.04 / 102.95 / 111.82 | 12.92 / 112.09 / 129.49 | -8.0 % | 3 |
| Kaltenbrunn | 16 (15) | 14.34 / 99.11 / 123.09 | 16.77 / 125.01 / 197.42 | +17.0 % | 3 |
| Kaltenbrunn | 24 (23) | 16.67 / 59.73 / 73.77 | 20.09 / 104.85 / 143.91 | +20.5 % | 3 |
| Kaltenbrunn | 32 (29) | 19.03 / 77.12 / 80.93 | 16.70 / 63.09 / 69.12 | -12.2 % | 3 |
| Kaltenbrunn | 48 (45) | 42.43 / 206.68 / 256.59 | 42.35 / 199.00 / 237.60 | -0.2 % | 3 |

The medians (p50) of the frame and its parts, before -> after:

| Map | Zombies | p50 before -> after: frame | zombie.gd phys | zombie.gd proc | bots | after physics scripts | after process scripts |
|---|---|---|---|---|---|---|---|
| m0 | 8 | 11.92 -> 12.40 | 1.07 -> 0.98 | 0.62 -> 0.65 | 2.74 -> 2.72 | 0.83 -> 0.85 | 1.26 -> 1.28 |
| m0 | 16 | 15.34 -> 13.78 | 2.48 -> 2.17 | 1.27 -> 1.23 | 2.78 -> 2.60 | 1.14 -> 1.07 | 2.08 -> 1.92 |
| m0 | 24 | 21.01 -> 19.80 | 4.03 -> 3.62 | 1.91 -> 1.85 | 2.88 -> 2.84 | 1.76 -> 1.69 | 2.63 -> 2.55 |
| m0 | 32 | 18.97 -> 18.19 | 4.57 -> 3.96 | 2.23 -> 2.13 | 2.65 -> 2.55 | 1.73 -> 1.66 | 2.65 -> 2.54 |
| m0 | 48 | 27.55 -> 26.27 | 6.08 -> 5.36 | 3.27 -> 3.12 | 3.25 -> 3.05 | 2.81 -> 2.71 | 4.19 -> 4.10 |
| m1 | 8 | 9.80 -> 9.66 | 0.86 -> 0.81 | 0.41 -> 0.39 | 1.59 -> 1.62 | 0.69 -> 0.70 | 0.94 -> 0.92 |
| m1 | 16 | 11.86 -> 12.14 | 1.93 -> 1.76 | 0.93 -> 0.84 | 1.58 -> 1.55 | 0.94 -> 0.98 | 1.38 -> 1.36 |
| m1 | 24 | 15.68 -> 15.26 | 2.69 -> 2.67 | 1.16 -> 1.10 | 1.59 -> 1.66 | 1.29 -> 1.25 | 1.58 -> 1.66 |
| m1 | 32 | 14.44 -> 13.71 | 3.35 -> 3.08 | 1.29 -> 1.31 | 1.72 -> 1.61 | 1.37 -> 1.34 | 1.56 -> 1.48 |
| m1 | 48 | 29.73 -> 30.77 | 6.83 -> 6.47 | 2.83 -> 2.83 | 1.95 -> 1.97 | 2.97 -> 2.91 | 3.26 -> 3.23 |

What it says:

- **Map 0, 16 to 48 zombies: the frame's median is 4-10 % lower** (48: 27.6 -> 26.3 ms here, about 16.2 -> 15.5 on a
  quiet machine), **the zombies' physics scripts 9-13 % lower** in every count, their process step 2-5 %, the gap
  after the process scripts (skeletons, the hitbox areas that follow them) 2-8 %. At 8 zombies nothing is waiting at
  a window and the change is inside the noise.
- **Kaltenbrunn: 2-9 % off the zombies' physics scripts, the frame within the noise.** Its horde spreads over open
  ground and chases instead of queueing, so fewer bodies stand.
- The late-round mix with kills is in the next table.

**The late round** (`--mix=high --kills=3 --round=30`: run and sprint tiers, crawlers, every 6th a fire zombie with
its burst, three kills a second spread over the second, the dead put back; 90-94 deaths in each 30 s window; three
runs a count, the same flip):

| Map | Zombies (up) | Before: mean / 1 % worst / max | After: mean / 1 % worst / max | Mean change | Runs |
|---|---|---|---|---|---|
| Map 0 | 24 (23) | 15.76 / 45.27 / 50.72 | 15.60 / 44.41 / 56.13 | -1.1 % | 3 |
| Map 0 | 48 (47) | 22.71 / 76.69 / 85.27 | 20.77 / 32.47 / 33.91 | -8.6 % | 3 |

| Map | Zombies | p50 before -> after: frame | zombie.gd phys | zombie.gd proc | bots | after physics scripts | after process scripts |
|---|---|---|---|---|---|---|---|
| m0 | 24 | 14.80 -> 14.31 | 2.67 -> 2.39 | 1.22 -> 1.20 | 2.58 -> 2.69 | 2.00 -> 1.99 | 1.99 -> 1.87 |
| m0 | 48 | 22.20 -> 20.82 | 5.10 -> 4.28 | 2.29 -> 2.19 | 3.13 -> 3.17 | 3.26 -> 3.18 | 3.30 -> 3.24 |

Here the zombies' physics scripts are 10-16 % lower (the corpses' and the fire zombies' bodies stand too), the frame's
median 3-6 %. Ragdoll rigs: 24-33 of each run's 85-95 came from the kept ones (only the "on" seconds keep and take
them, and a corpse hands its rig back only when it dissolves, some seconds after the death). The 1 % worst at 48
(77 -> 32 ms) is one run's stolen seconds landing on the "off" side; not claimed.

**What this does not reach: the aim.** 48 zombies on Map 0 cost about 26 ms of game thread here after the change,
about 15 ms on a quiet machine; the aim was under 10. 24 zombies (the real game's cap outside the Sherman's round)
cost about 20 ms here, 9-12 on a quiet machine. The next section says why.

## What is left, and what it would take

What a zombie still costs after this work is the engine doing, for each body, what the game needs it to do. None of
it can be cut further without either changing what a player sees or how the game plays, or replacing an engine
part; each is a decision for the owner. In order of size (48 on Map 0, this machine; per zombie in brackets):

| What | ms at 48 | What it would take | Changes |
|---|---|---|---|
| The AnimationTree's advance for every body the camera sees within 15 m, and the pose script round it | 3.1-3.7 (0.07) | A coarser rate for zombies in view at middle distance when the horde is big (for example half rate beyond 8-10 m when more than 24 are up), or `Zombie.anim_lod_scale` on a low preset; or a lighter tree (fewer blend nodes: the zombie overhaul's files) | the look of zombies in view: **not done** (the brief: no visible change) |
| Skeletons, the IK / spring modifier, 14 bone attachments and the 13 hitbox areas that follow them | about 2 (0.05) | Hitboxes that follow the body at the physics tick rather than every animation step (the same at 60 FPS, less above it), or fewer of them | hit registration: its own task |
| `move_and_slide` of the bodies that move | about 2 (0.045) | The Jolt physics engine (`physics/3d/physics_engine`; T-265 measured the zombies' script share -12 % and the physics step -0.35 ms at 24) | every body, ragdoll and ray in the game: the owner's call with a full smoke pass |
| The physics and navigation servers' step (the part that grows worse than linearly on Map 0) | about 2.8 | Jolt as above; avoidance is only 0.26 ms of it and the zombies' bodies touching each other under 0.1 | as above |
| The foot rays of moving feet within 15 m | about 0.8 (0.017) | Two rays a tick alternating feet instead of four | feet on stairs and slopes settle at 30 Hz: **not done** |
| The four bot brains | 2.5-3.0, flat | T-265's list (a think budget, fewer brains on a low preset) | the bots, not the zombies |

**Considered and not done:**

- *Animating zombies behind walls at the out-of-view rate.* Most of a full horde on Map 0 queues outside the inn's
  walls, inside the camera's view cone but out of sight. A physics ray from the camera cannot tell a stone wall from
  a fence, a grate or a window pane (Map 0's yard and grounds fences are solid colliders), so a zombie seen through
  one would animate at a quarter of the rate in plain view. It would need occluders that are the visible walls
  (OcclusionWalls' big opaque triangles as a physics layer of their own); that is a task of its own.
- *Moving far zombies every second tick.* It halves `move_and_slide` for bodies far from every player, but changes
  when a body meets a wall or another body by a tick: a timing change, out of the brief.
- *Thinking less often.* The zombies' own decisions are 0.6-1.3 ms for 48 and already gated (repaths 6 a frame, the
  wedge check 5 a second, the roam check every 0.8 s): spreading them further buys little.

**Hitches left** (the 1 % worst frames): on this machine most of them were other processes' (the noise floor's
spikes). Of the game's own: a death in a pack still costs its listeners (the kill's signals, gore, Scrip, the
director's refill: the explosion worker's T-280 area), a body leaving and entering the physics space at each death and
spawn (19 collision objects), a bot's think (T-265's list).

## Render side (counted, not timed)

Counted from the scene tree at the end of each bench run (`[t281] per zombie`), Map 0, 48 up:

| Per zombie | Plain horde | Late-round mix (fire zombies) |
|---|---|---|
| Visible meshes | 5.0 | 5.3 |
| Surfaces (a draw call each in the colour pass when in the frustum) | 6.5 | 8.7 |
| Skinned meshes (a skeleton the renderer skins) | 1 | 1 |
| Shadow casters / their surfaces (draw calls in every shadow view the body stands in) | 1 / 2 | 1 / 2 |
| Lights | 0 | 0.17 (one unshadowed omni per fire zombie) |
| Hitbox areas (physics) | 18 (13 live), now 13 in the space | 18 (12 live) |
| Distinct materials over the whole horde | 10 | 9 |

So the render thread's CPU work grows by about 6.5-9 draw calls, one skeleton upload and one or two shadow-pass draw
calls per shadowed view per zombie: 48 zombies in view are about 310-420 colour-pass draw calls and 100 more per
shadow view (T-266 measured 4,000-7,000 a frame on Map 0's heavy views, so the horde is 5-10 % of them). With the
renderer on its own thread (`Play.bat`) this is not on the game's thread. No zombie casts a shadow from a light of its
own and the fire zombies' lights are unshadowed. **The rendered census under WSL (`tools/wsl_perf.sh`) was not run**:
other workers' software renders held the WSL display the whole session (checked seven times; the brief allows one
render at a time), so these are tree counts, not the renderer's own numbers.

## Checks run

All headless, in `.wt/locker` on `claude/zombie-perf`; logs under `.smoke_logs/t281/` (git-ignored).

- **Script check**: 1030 scripts, 0 failed (master 1029 + the new test).
- **Full GUT suite** (on `fcc4389e` plus the animation rewrites, before the new test file was added): 262 scripts,
  2650 tests, 2648 passing, 1 risky (`test_neural_lines_are_loudness_normalised`, the known one), **1 failing**:
  `test_cinema_reels` "nothing missing: video:user://_qa_reels_unit/staub/shot_02.ogv", a file in the user data
  folder every worktree shares (another worker's run on the same folder); run alone afterwards: 14 of 14 passing.
- **`test_t281_zombie_count`** (new, 8 tests): 8 of 8 passing, twice (the slide at rest against the switch off to the
  float, everything that must make a body slide, a body in the air, the weak-point boxes in and out of the space, a
  still foot's kept rays against fresh ones, a kept ragdoll rig on another skeleton: every bone, the mask back, at
  rest, at the new pose; switched off: freed; the cap of 8). `-gselect=zombie` (the zombie tests): 76 of 76.
  `test_zombie_ragdoll_cap` frees the kept rigs after each test now.
- **Smokes** (one run each unless said; the machine at 90-100 % all the time): `smoke_map00`, `smoke_map00_alive`,
  `smoke_map00_cellar_bay`, `smoke_map00_loop`, `smoke_coop`, `smoke_zombie_anim`, `smoke_horse_boss` (81 checks),
  `smoke_sherman` (74), `smoke_map01_sherman` (36), `smoke_ladders`, `smoke_inn_survivors` **PASS**.
  `smoke_squads` FAIL once ("no round ended after the rise", the load-dependent check T-256 saw fail under load too),
  then PASS with the changes on and PASS with them off (`CZ_T281_OFF=1`). `smoke_bots_shop_m0` FAIL, FAIL, PASS with
  the changes on and **FAIL with them off** ("no squad bot did 'bench'", the known intermittent in PROGRESS and
  DECISIONS): not caused here.
- **The bench**: 30 runs of the final sweep, 6 of the late-round mix, 12 diagnosis runs, 5 diagnostic experiments,
  4 flips (`.smoke_logs/t281/`).
- **Not run / not verified:** anything rendered (no window on this PC without the owner's OK), so no frame rate on
  the GPU and no look at the reused ragdolls or the kept foot rays on screen (both are pinned by the unit tests to
  the old numbers); the rendered census under WSL (the WSL display was taken by other workers' renders all session);
  a networked co-op client (the changes run on the host's bodies and on puppets alike, puppets do not halt or ray
  their feet differently); Totenhafen and the Fernflug acts; a quiet machine (every millisecond here is the loaded
  machine's); the other 70 smokes.

## The rendered benchmark for the owner's GPU (not run: needs the owner's OK)

`perf_marks` without `--hitch` is the T-070 / T-258 bench: it loads the map, sets round 15, puts the horde up, samples
the frames from 9 s to 24 s, prints `[perf] in play: avg FPS ..., worst frame ..., 1% low ...` and the pause map's
cost, then quits. `--zombies=N` works there too. From a Windows prompt in the main checkout, running this branch's
worktree, off-screen and silent, the owner's Ultra preset, the renderer on its own thread as `Play.bat` starts it;
four runs (24 and 48 zombies, the T-281 changes on and off), then the four result lines:

```
cd /d C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate && for %z in (24 48) do for %a in (none t281_off) do tools\dl_godot\Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --position -4000,-4000 --resolution 1920x1080 --render-thread separate --path .wt\locker res://gravelight/tools_src/perf_marks.tscn -- --map=map00_crossroads --preset=ultra --no-marks --zombies=%z --ab=%a > logs\t281_z%z_%a.log 2>&1
findstr /C:"in play" logs\t281_z*.log
```

`--ab=none` changes nothing; `--ab=t281_off` is the build without this task's changes. In a .bat file write `%%z` and
`%%a`. Add `--breakdown` for the CPU / GPU split and the draw calls; `--map=map01_kaltenbrunn` for the other map. The
preset is the plain Ultra preset, not the owner's saved individual settings (perf_marks uses its own settings file).
Each run opens a window for about 40 s (off-screen at -4000,-4000).
