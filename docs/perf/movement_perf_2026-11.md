# Movement feel and frame rate, November 2026

Branch `claude/movement-perf`, cut from master `4a527f4f` (UPDATE 19 in). Not merged, not pushed.

## What was asked

The owner, 2026-11-15: "Improve the game's movement feel and frame rate. First inspect the current code, recent
commits, project notes, and any existing movement or performance reports. Use the game's existing design and test
conventions. Focus on: More responsive, consistent movement that feels good at different frame rates. Better
performance in real gameplay, especially during large zombie hordes, combat effects, and co-op. Removing avoidable
CPU or GPU work without changing the game's intended behavior. Measure performance before and after using the
project's existing tools. Add or update focused tests for any behavior you change, then run the relevant tests and
performance checks. Preserve unrelated work and keep the game launching throughout. Don't guess at bottlenecks:
profile first, then address the largest confirmed causes. When finished, summarize what changed, report
before-and-after movement and FPS results with the test setup, list the checks you run, and commit your changes on
a focused branch."

Everything here was measured headless (no window may be opened on this PC without the owner's OK). **GPU frame
rate on the owner's hardware: not measured.** The command to measure it is at the end.

## In short

- **Movement.** The body already moves the same at every frame rate (it runs on the 60 Hz tick; the probe
  confirms it to the millimetre). What changed with the frame rate was everything drawn per rendered frame with
  smooth motion on: the recoil kick was up to 2.8 times larger at 240 FPS than at 60, the landing dip 1.6 times
  deeper, the gun's sway under a fast turn a third of its 60 FPS size, and the pad's stick turned the view in one
  rendered frame out of four. All four now give the 60 FPS result at 30, 60, 144 and 240 FPS. Nothing changes at
  60 FPS, on the tick, for bots or in the tests; no speed, jump, timing or tunable moved.
- **Frame cost** (CPU work of one 60 FPS frame, no renderer, medians of 3 runs):

  | Scenario (Map 0 unless said) | Before, ms | After, ms | Change | Frames over 16.7 ms, before -> after |
  |---|---|---|---|---|
  | Horde of 24, squad (3 bots + Jakub + companion) | 10.10 | 8.74 | -13 % | 6 -> 2 of 1800 |
  | Horde of 24, solo | 7.63 | 6.41 | -16 % | 2 -> 1 of 1800 |
  | Live round 15-16, squad (kills, spawns, grenades) | 8.96 | 8.29 | -7 % | 21 -> 4 of 3600 |
  | Live round, solo | 7.33 | 6.50 | -11 % | 3 -> 2 of 3600 |
  | Kaltenbrunn, horde of 24, squad | 7.09 | 6.59 | -7 % | 2 -> 1 of 1800 |
  | Kaltenbrunn, horde of 24, solo | 5.70 | 5.33 | -6 % | 0 -> 0 |

  The zombies' own tick went from 2.52 to 1.97 ms with 24 up. In the live round with the squad the frames over
  33 ms went from 5 to 0 of 3600 and the worst frame from 90 to 30 ms.
- **What caused it**, each found by timing before anything was changed: two calls every chasing zombie made
  every tick that it almost never needed (a third of the chase), and five kinds of mesh built in script in the
  middle of play the first time each was needed (2.5 to 100 ms a time).

## What I looked at first

`PROGRESS.md`, `docs/DECISIONS.md` (T-046 movement and gunplay feel, T-070 performance pass, T-133 smooth motion,
T-139 minimum spec, T-162 zombies above 60 Hz, T-236 movement feel, T-237 bot lag), `docs/PERFORMANCE.md`,
`docs/gravelight/PERFORMANCE.md`, `docs/u15/t236_movement.md`, `docs/u15/t237_bot_perf.md`, `morning/`, the git log,
and the tools: `perf_marks` (`--hitch`, `--probe`, `--live`), `tools/bot_perf.sh` + `bot_perf_table.py`, `BotProf`,
`smoke_move_feel`, `feel_probe`, `perf_census.sh`, `ai_soak.sh`. The code read end to end: `gravelight/player/player.gd`
(movement, camera), `move_intent.gd`, the viewmodel's motion in `gravelight/weapons/weapon_holder.gd`,
`gravelight/enemies/zombie.gd` (tick, chase, navigation, senses, animation), `zombie_body.gd`, `zombie_gore.gd`,
`zombie_director.gd`, `explosion.gd`, `relief_squad.gd`, `people_bodies.gd`.

What the earlier passes had left open and this one took up: T-237's "what is left" names the explosion in a pack
(9-35 ms) and the spawn tick (39-59 ms) as the largest spikes and did not find their cause; T-236's item 5 (parts
of the camera stepping at 60 Hz on a high-refresh screen) could not be measured headless then.

## Setup of every measurement

- The owner's PC (Ryzen 7 7800X3D, RTX 5090, Windows 11), Godot 4.7.2, `--headless --audio-driver Dummy`, one
  Godot at a time, nothing else running (the tool's noise floor read 0.032-0.034 ms in every run; T-237's
  batches read 0.035-0.046 on a shared machine).
- **Frame cost:** `tools/bot_perf.sh <tag> <map> <runs> [flags]` = `perf_marks --hitch` under `--fixed-fps 60`
  at High priority: every frame is one physics tick and one process step with no sleep, so a frame's wall time
  is the CPU work of one 60 FPS frame without the renderer. Round 15, 24 zombies. "Horde": the round stopped,
  the 24 kept alive, the player in god mode at the spawn, 30 s sampled. "Live": `--live --secs=60 --seed=7`, the
  round runs (kills, spawns, grenades, the relief squad, the inn's survivors, the squad can go down), 60 s
  sampled. "Squad": 3 bots + Jakub + the map's companion; "solo": `--bots=0 --no-companions`. Preset Low.
  Three runs a side (two on Kaltenbrunn), medians (`python -I tools/bot_perf_table.py .smoke_logs/t237/<tag>`).
- **Before** is master's game code (`zombie.gd`, `zombie_body.gd`, `player.gd`, `weapon_holder.gd`,
  `player_bot.gd` checked out from master into this tree, the tools unchanged); **after** is the branch.
  Tags: `mp_base` and `mp_after_static` (horde), `mp_before_live` and `mp_after2_live` (live), `mp_before_map01`
  and `mp_after_map01` (Kaltenbrunn).
- **Movement:** `tools/move_rates.sh <tag>` (new) runs `gravelight/tools_src/move_rates.tscn` at a fixed 30, 60,
  144 and 240 frames a second with the game's 60 ticks, then once more per rate with the tick rate set to the
  same number. The real local player on a flat floor, driven through the input actions, smooth motion forced on
  (headless turns it off; this is what a window runs). Tags `base` (master's player code) and `after`.

## Movement

### What the probe found on master

The body: identical at 30, 60, 144 and 240 frames a second in every measure (it is simulated on the 60 Hz tick
whatever is drawn). The eye: with smooth motion it covers exactly walk speed x the frame's time in every rendered
frame at every rate, no frame stands still (T-133 and T-236 hold). What was not the same:

| Measure (master) | 30 FPS | 60 FPS | 144 FPS | 240 FPS |
|---|---|---|---|---|
| Recoil kick of 3 degrees, soft spring (recover 10): peak | 2.06 | 2.07 | 2.62 | 2.77 |
| The same on a stiff spring (recover 22): peak | 0.90 | 0.90 | 2.15 | 2.50 |
| Landing dip at 7 m/s: depth, cm | 2.92 | 2.92 | 4.27 | 4.64 |
| The gun's take-off dip: depth, mm | 12.4 | 12.7 | 16.9 | 18.0 |
| Gun sway under a 180 deg/s turn (x1000) | 64.3 | 64.3 | 31.3 | 18.8 |
| Pad stick held: rendered frames in which the view turned | 100 % | 100 % | 41.7 % | 25 % |
| Sprint FOV: seconds to 90 % | 0.400 | 0.433 | 0.438 | 0.450 |
| Head bob: seconds to 90 % | 0.300 | 0.317 | 0.333 | 0.342 |

Why, from the code:

1. **The springs** (`Player._update_camera`: the recoil kick, the landing dip; `WeaponHolder._animate` and
   `_feel_rig`: the gun's kick, look sway and inertia) took one explicit Euler step of the frame's own time. With
   smooth motion they run per rendered frame, so the step was 1/60 s at 60 FPS and 1/240 s at 240, and an
   explicit step damps a stiff spring far more when it is long. The same impulse gave a different kick.
2. **The gun's look sway** divided the look input gathered per physics tick by the time of a rendered frame: at
   240 FPS it saw one frame turning at four times the rate and three frames at none, and the sway's cap
   (`limit_length(0.075)`) cut the one frame down.
3. **The pad's right stick** was read in the physics tick: the view turned 60 times a second under a camera
   drawn 144 or 240 times (the mouse is applied per event and was fine).
4. **Two eases** written `lerp(a, b, rate * delta)` (the head bob's amount, the FOV) are a slightly different
   curve at every frame rate (12 % between 30 and 240 FPS).

### What changed

All in `gravelight/player/player.gd`, `gravelight/weapons/weapon_holder.gd` and the new
`gravelight/player/tick_spring.gd`:

1. **`TickSpring.advance`**: a spring's state only ever advances in whole steps of 1/60 s, however the frames
   fall; a frame between two steps draws the straight line from the last step to the next. At 60 FPS and on the
   tick (bots, headless, every test) it is the old code step for step (pinned by a test to 1e-7). At 144 and
   240 FPS the kick has its 60 FPS size and still moves every frame. Used by the camera's recoil and landing
   springs and the viewmodel's kick, sway and inertia springs (`WeaponHolder._spring2` / `_spring3` are gone).
2. **The look sway** reads the frame's own look input when the viewmodel animates per frame
   (`Player.take_frame_look`, `WeaponHolder._per_frame`); on the tick it reads the tick's, as before.
3. **The pad's stick** turns the view in `_process` with the frame's time when smooth motion is on
   (`Player._pad_look(delta, true)`); its aim-assist ray is still cast once a tick (`_pad_assist_tick`), not once
   a frame. Without smooth motion, in last stand and for bots nothing changes.
4. **`Player._ease60`**: the two eases use the weight that is exactly `rate / 60` at 60 FPS and leaves the same
   share after the same time at any other rate.

**Which value was kept, and why.** The comment on `kick_camera` says the impulse is sized so the kick "peaks at
about the remaining kick" (3 degrees here); the code never did that at 60 Hz (2.07 on a soft spring, 0.90 on a
stiff one), and did so more nearly the higher the frame rate. I kept the 60 Hz result at every rate rather than
the comment's: it is what every weapon row was tuned and tested at, what the bots and the soaks run, and what a
60-90 FPS session has been showing (the owner's frame log of 2026-10-31 is 57-86 FPS). If the stronger kick
seen at 240 FPS was the one that felt right, that is one multiplier in `weapons.json`'s recoil rows, the same at
every frame rate now. **No tunable moved**: `movement.json`, `player.json`, `weapons.json` and `world.json` are
untouched.

### Before and after, by frame rate (the game's 60 ticks)

`tools/move_rates.sh base` on master's player code, `tools/move_rates.sh after` on the branch. Only the rows that
differ between rates or between the two sides are shown; the body rows are below.

| Measure | Side | 30 FPS | 60 FPS | 144 FPS | 240 FPS |
|---|---|---|---|---|---|
| Recoil kick 3 deg, recover 10: peak deg | before | 2.058 | 2.073 | 2.618 | 2.772 |
| | after | 2.058 | 2.073 | 2.073 | 2.073 |
| Recoil kick 3 deg, recover 22: peak deg | before | 0.903 | 0.903 | 2.153 | 2.495 |
| | after | 0.903 | 0.903 | 0.886 | 0.903 |
| Landing dip at 7 m/s: depth cm | before | 2.92 | 2.92 | 4.27 | 4.64 |
| | after | 2.92 | 2.92 | 2.92 | 2.92 |
| Gun take-off dip: depth mm / overshoot mm | before | 12.44 / 1.40 | 12.73 / 1.55 | 16.85 / 2.46 | 17.96 / 2.75 |
| | after | 12.59 / 1.47 | 12.73 / 1.55 | 12.64 / 1.55 | 12.73 / 1.55 |
| Gun sway, 45 deg/s turn (x1000) | before | 16.07 | 16.07 | 16.07 | 16.07 |
| | after | 16.07 | 16.07 | 16.07 | 16.07 |
| Gun sway, 180 deg/s turn (x1000) | before | 64.27 | 64.27 | 31.26 | 18.76 |
| | after | 64.27 | 64.27 | 64.27 | 64.27 |
| Pad stick: deg/s | before | 160.4 | 160.4 | 160.4 | 160.4 |
| | after | 160.4 | 160.4 | 160.4 | 160.4 |
| Pad stick: rendered frames in which the view turned | before | 100 % | 100 % | 41.7 % | 25.0 % |
| | after | 100 % | 100 % | 100 % | 100 % |
| Sprint FOV: s to 90 % of 6 degrees | before | 0.400 | 0.433 | 0.438 | 0.450 |
| | after | 0.433 | 0.433 | 0.431 | 0.438 |
| Head bob: s to 90 % | before | 0.300 | 0.317 | 0.333 | 0.342 |
| | after | 0.333 | 0.317 | 0.319 | 0.325 |
| Key press to the eye moving: mean / worst ms | before | 33.3 / 33.3 | 33.3 / 33.3 | 15.6 / 20.8 | 15.6 / 20.8 |
| | after | 33.3 / 33.3 | 33.3 / 33.3 | 15.6 / 20.8 | 15.6 / 20.8 |

(At 144 FPS a frame can fall beside the one 60 Hz step that holds a stiff spring's peak: 0.886 against 0.903. At
30 FPS a frame draws every second step, and the remaining spread of the eases is the frame's own length.)

The body, the same before and after and at every frame rate:

| Measure | 30 / 60 / 144 / 240 FPS |
|---|---|
| Walk: seconds to 95 % speed | 0.117 |
| Walk: metres in 2 s | 8.842 |
| Walk stop: seconds / metres | 0.183 / 0.346 |
| Sprint: metres in 2 s | 13.361 |
| Sprint jump: metres | 4.420 |
| Sprint stop: seconds / metres | 0.250 / 0.698 |
| Standing jump: apex m / seconds in the air | 0.665 / 0.633 |
| Strafe reversal: seconds to 95 % the other way | 0.200 |
| Eye at a walk: slowest / fastest frame, x walk speed | 1.000 / 1.000 |
| Eye at a walk: frames the picture stood still | 0 % |

### Measured and left alone

- **Key press to the eye moving** (33 ms at 30 and 60 FPS, 16 ms mean and 21 ms worst at 144 and 240): the
  movement keys are read on the tick and the eye is drawn between the last two ticks (T-133), so the first
  visible movement trails the press by up to a tick plus a frame. The mouse does not go through this (it turns
  the view per event). Drawing the eye ahead of the body instead would remove most of it and would also put the
  eye past the body for a frame at every stop and landing; that is a look-and-feel choice to make with a window
  open, not headless. Not changed.
- **The movement code at another tick rate** (the second table `tools/move_rates.sh` prints; the game ships at
  60 ticks a second and no setting changes it, so no player can reach this): the body is stepped with explicit
  Euler, so a 30 Hz tick would jump 0.700 m and 4.76 m, a 240 Hz tick 0.639 m and 4.17 m, against 0.665 m and
  4.42 m at 60; walking 2 s covers 8.95 / 8.84 / 8.78 / 8.76 m. Making it exact would move the 60 Hz jump from
  4.42 m to about 4.15 m. Not changed; the table is there if the tick rate ever becomes a setting.
- **The physics jitter fix** (`physics/common/physics_jitter_fix`, Godot's default 0.5; the engine's notes
  suggest 0 for a game that interpolates itself). Its effect only exists with real, uneven frame times; under a
  fixed frame rate it does nothing, so it could not be measured here. Not changed.

## Performance

### The baseline, and where the frame went

Map 0, round 15, 24 zombies, the squad, master (`mp_base`, 3 runs): **10.10 ms a frame** (p99 15.2, worst 37),
of which the scripts' physics tick 5.14, the scripts' process step 2.52, the engine (physics server, navigation,
the tree) about 2.4. By script (`perf_marks --hitch`, one run):

| Script | ms per frame | Nodes |
|---|---|---|
| `zombie.gd`, physics tick | 2.52 | 32 (24 active) |
| `bot_brain.gd`, physics tick | 1.69 | 4 |
| `zombie.gd`, process (animation) | 0.80 | 32 |
| `soldier.gd` (the relief squad on the map) | 0.40 | 3 |
| `patron_body.gd` (the people's poses) | 0.38 | 13 |
| `player.gd`, physics tick | 0.19 | 6 |
| `map_canvas.gd` (minimap) | 0.15 | 2 |
| `grenade.gd` | 0.14 mean, p99 8.3, worst 15-21 | - |
| everything else, 30 scripts | about 1.3 | |

The zombies are a third of the frame, so they were opened up with `BotProf` sections (a temporary patch, not
committed; `tools/zombie_profiled.gd`'s note stands: no instrumentation in the shipped zombie callbacks):

| Part of the zombies' 2.8 ms tick (that run) | ms per tick | What it is |
|---|---|---|
| `_update_chase`, all of it | 1.95 | 9 chasers a tick on average, 0.16 ms each |
| ... `_nav_move` (of which `move_and_slide` 0.45) | 0.86 | the walk itself |
| ... **`_off_navmesh_height`** | **0.55** | `NavigationServer3D.map_get_closest_point`, 0.053 ms a call, every tick, for a check that needs 3 s to trip |
| ... **`_update_hop`** | **0.26** | two rays (`_clear_to`) and a zone lookup evaluated as arguments of `hop_due`, which returns false at 1 g whatever they say |
| ... the prey / lure / nearest-player / roam checks | 0.18 | |
| `move_and_slide`, all states | 0.85 | engine physics, 24 bodies in a crowd |
| `_update_senses` (foot IK rays, look-at) | 0.46 | 4 rays per near zombie per tick |
| `_update_wait_window` | 0.27 | 7 queued at windows |
| `_process`: `_animate` (of which `AnimationTree.advance` 0.46) | 0.85 | |

The spikes were named the same way (the worst ticks of the baseline runs, with a temporary trace on the body
builders):

| Spike (master) | Size | Cause |
|---|---|---|
| `grenade.gd`: a blast in a pack | 8-28 ms | `Zombie.become_crawler` -> `ZombieGore.sever` x2 -> `ZombieBody.piece_mesh`: the severed leg is cut out of the skinned body mesh in script the first time that body kind loses that limb (2.5-5.5 ms a piece idle, 9 ms for a crawler in play). Cached after, but a map has its kits x 4 bodies x 10 pieces to meet |
| `zombie_director.gd`: a spawn | 21-38 ms | `ZombieBody.build_skinned` for a woman of a medium or heavy build: `warm_up` built women only thin, the kits spawn them in every build (villager 50 % women, lab staff 35 %, dock worker 20 %); 20 ms a merge, two in one tick |
| `inn_survivor.gd`: a survivor rises | 40-106 ms | the person's risen mesh (`PeopleBodies.mesh(id, true)`, 36-42 ms) and the villager woman's zombie body, merged in the tick they got up; the same for the opening's three patrons |
| `relief_squad.gd`: a soldier rises, a squad arrives | 20-41 ms | `SoldierKits.body_mesh` -> `ZombieBody.build_dressed`: a per-soldier body (rolled tone and palette) merged at the arrival (3 in one tick) and again, risen, at each rise. **Not fixed, see below** |
| `bot_brain.gd`: think.ee / act.fight / act.retreat | 5-20 ms | T-237's list. **Not touched** |
| a zombie's kill, `vo.load` | 6-10 ms | a squad voice line loaded on first use. **Not touched** |
| `jakub_companion.gd` | 20-29 ms, once a match | his breakout tick. **Not touched** |

### What changed

1. **The wedge check looks five times a second** (`Zombie._wedged`, `WEDGE_CHECK_S` 0.2). A body pushed well
   above the walkable floor for 3 s of chase is recycled; the navmesh was asked on every tick of every chaser.
   It is asked every 0.2 s now, each look counts the chase time since the last, and the pool's bodies look on
   different ticks. **Behaviour:** a wedged zombie is recycled 3.0 to 3.2 s on instead of at 3.0 s; a body that
   comes back under 1 m for less than a look does not reset the clock.
2. **The leap-hop's rays wait for the cheap gates** (`Zombie._update_hop`). `hop_due` is asked first with a
   clear line and no vacuum; only if a hop could be due are the two rays and the zone lookup made and the real
   question asked. **Behaviour:** none (a test walks the whole grid: a due hop always passes the gate).
3. **Severed pieces are cut ahead of time on a worker thread** (`ZombieBody.warm_pieces`, called from `warm_up`
   at map load for every body the map's kits can spawn). The cut itself is `_cut_arrays`, the old `_cut_piece`
   loop moved into a function that reads nothing but its arguments; the worker returns plain arrays, the main
   thread makes the mesh the first time the piece is asked for (0.1 ms). A piece asked for before its cut is in
   is cut on the spot, as before. Not in the browser build (no threads). **Behaviour:** none; a test compares
   the ten pieces of a body cut ahead with the same ten cut on the spot, array for array.
4. **`warm_up` builds every body a kit can spawn**: a kit that spawns women gets them in every build of its
   row, with their pieces.
5. **The Inn's people who rise are built at map load** (`PeopleBodies.warm_risen`, from `InnSurvivors._ready`
   and `InnOpening._ready`): the three survivors and the three patrons who turn.

**What the load pays for 3-5** (Map 0, measured in a scratch scene): 4 more bodies 110 ms, reading the bodies'
arrays and handing the pieces over 160 ms (the worker's 400 cuts are done by the time `warm_up` returns), six
risen people 280 ms: about 0.55 s more on a map load whose body warm-up alone took 0.77 s.

Tools: `perf_marks` gained `--ab=no_piece_warm` (the pieces cut on the spot, the before of item 3 from the same
build) and `--seed=N` (seeds the global generator before the map loads).

### Before and after

Medians over the runs; ms unless a count. "Tick" is the scripts' physics tick, "zombies" `zombie.gd`'s share of
it, "process" the scripts' process step. Noise floor 0.032-0.034 in all of them.

| Scenario | Side | Frame mean | p50 | p95 | p99 | Worst | >16.7 | >20 | >33 | Tick | Tick p99 | Brains | Zombies | Process |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Map 0 horde, squad (1800 frames) | before | 10.10 | 10.21 | 12.75 | 15.23 | 37.03 | 6 | 2 | 1 | 5.14 | 8.94 | 1.69 | 2.52 | 2.52 |
| | after | 8.74 | 8.88 | 10.86 | 12.57 | 18.55 | 2 | 0 | 0 | 4.03 | 6.84 | 1.52 | 1.97 | 2.43 |
| Map 0 horde, solo (1800) | before | 7.63 | 7.88 | 9.60 | 11.21 | 40.29 | 2 | 2 | 1 | 3.49 | 5.51 | - | 2.33 | 2.21 |
| | after | 6.41 | 6.49 | 7.95 | 8.78 | 27.57 | 1 | 1 | 0 | 2.39 | 3.71 | - | 1.88 | 2.13 |
| Map 0 live round, squad (3600) | before | 8.96 | 9.06 | 11.49 | 14.60 | 90.05 | 21 | 12 | 5 | 4.80 | 9.27 | 1.45 | 2.49 | 2.14 |
| | after | 8.29 | 8.67 | 10.24 | 11.61 | 29.89 | 4 | 3 | 0 | 3.77 | 6.40 | 1.24 | 2.01 | 2.28 |
| Map 0 live round, solo (3600) | before | 7.33 | 8.02 | 9.11 | 9.67 | 40.22 | 3 | 2 | 1 | 3.30 | 4.88 | - | 2.81 | 2.19 |
| | after | 6.50 | 7.00 | 7.99 | 8.74 | 46.24 | 2 | 2 | 1 | 2.53 | 4.01 | - | 2.00 | 2.17 |
| Kaltenbrunn horde, squad (1800) | before | 7.09 | 7.04 | 8.72 | 10.63 | 35.43 | 2 | 2 | 0 | 3.38 | 5.56 | 1.12 | 1.92 | 1.89 |
| | after | 6.59 | 6.53 | 8.04 | 9.60 | 16.80 | 1 | 0 | 0 | 2.91 | 4.75 | 1.08 | 1.50 | 1.88 |
| Kaltenbrunn horde, solo (1800) | before | 5.70 | 5.78 | 6.94 | 7.58 | 14.25 | 0 | 0 | 0 | 2.59 | 3.69 | - | 2.10 | 1.63 |
| | after | 5.33 | 5.41 | 6.36 | 6.86 | 13.12 | 0 | 0 | 0 | 2.33 | 3.09 | - | 1.59 | 1.60 |

As a rate with no renderer (1000 / frame mean): the Map 0 horde with the squad 99 -> 114 a second, solo 131 ->
156. These are **not** frame rates: the renderer's CPU and the GPU come on top (the earlier passes found the
game CPU-bound on the RTX 5090 at 57-86 FPS in play, so most of a millisecond saved here should show, but that
is an expectation, not a measurement).

Reading the live rows: a live round plays out differently run to run (other fights, other kills, the squad down
or not), which three runs a side do not average out; the per-frame mean is 7-11 % lower, and what the changes
were aimed at is the spike columns. The worst ticks of the three "after" runs with the squad are the relief
squad (20-41 ms, four of the worst ticks of one run), a bot's first shots (18-20 ms, once a run), a survivor's rise (18-20 ms,
down from 40-106) and bot thinks (7-20 ms); no grenade tick and no spawn tick is in the lists any more. One solo
"after" run had a 193 ms frame that was not in any script (every script in the ticks around it ran five to ten
times slower than its own average: the machine, not the game); the solo "worst" column carries it.

## Second part: rounds 13-15 on Map 0, the local model, and the 16.6 ms target

The owner, while this work ran: on Map 0 "around round 13-15 the game drops to 15 fps ... the game should never
dip below 60 fps", and asked whether the local models cause it. The lead added that two other workers were
running headless Godot and WSL software renders on the PC during that session.

**The machine was no longer idle for this part.** From about 06:30 other workers' WSL renders held the CPU at
about 50 % (the tool's noise floor p95 went from 0.041 to 0.055 ms; the same build's live round went from 8.3 to
10.7-12.3 ms a frame). Everything in this part is from single runs or runs on that loaded machine: it shows what
grows and what spikes, not clean before / after numbers. The tables of the first part (idle machine) stand for
the commits up to `6862e9ac`.

### What grows with the round

`tools/bot_perf.sh <tag> map00_crossroads 1 --live --secs=45 --seed=7 --round=N --ai=squad` (the default squad:
3 bots + Jakub + the companion, the planner bot on its built-in brain; `--round` is new), one run each:

| Round | Frame mean | p99 | Worst | 1 % low (ms) | Frames over 16.7 of 2700 | Zombies up at the end | `zombie.gd` tick + animation | `bot_brain.gd` | Soldiers | Corpses / ragdoll bones / decals at the end |
|---|---|---|---|---|---|---|---|---|---|---|
| 5 | 6.23 | 15.8 | 32.3 | 19.0 | 16 | 9 | 0.32 + 0.17 | 1.78 | - | 2 / 22 / 47 |
| 10 | 8.11 | 18.5 | 45.2 | 21.4 | 54 | 13 | 1.21 + 0.46 | 1.90 | - | 5 / 55 / 47 |
| 13 | 8.64 | 16.2 | 56.7 | 21.1 | 21 | 24 | 1.73 + 0.66 | 1.68 | 0.37 | 4 / 33 / 47 |
| 15 | 9.56 | 19.1 | 36.6 | 23.4 | 45 | 19 | 1.90 + 0.67 | 1.74 | 0.64 | 6 / 55 / 47 |
| 20 | 11.45 | 23.4 | 37.5 | 26.8 | 174 | 24 | 2.70 + 1.17 | 1.74 | - | 4 / 44 / 47 |

- **What grows is the zombies**: their number until the cap of 24 is reached (about round 13), then their cost
  each (round 20: 0.16 ms a zombie a frame against 0.10 at round 13: faster tiers, more of them in a crowd at
  the player). The squad's brains do not grow (1.7-1.9 ms at every round).
- **Nothing piles up**: the node count stays at 12,500-13,100, corpses at 2-7, ragdoll bones at 55 or under (the
  cap), decals at 47, rigid bodies at 0-2. No leak, no growing list.
- A relief squad on the map adds 0.4-0.6 ms a frame while it is there (its soldiers' brains).
- UPDATE 19's dealt perk machines, new shaders and LODs do not show in the scripts' time (`perk_machine.gd`
  0.05 ms for 12); their GPU side was not measured.

So the CPU work of the game at rounds 13-15 with the default squad is 8.6-9.6 ms a frame on this machine while
it was loaded and 8.0-8.3 ms idle: about 100-120 frames a second before the renderer. **15 FPS is a 66 ms frame;
nothing in the game's own per-frame work comes near it.** What does reach those sizes are single frames (the
spikes below, 20-100 ms before this work) and anything that takes the CPU or the GPU away from the game: the
other workers' processes during that session are the most likely cause of a sustained drop, and the frame-log
command at the end will show which it was (its CPU ms and GPU ms columns).

### The local model (the planner bot)

How it works, from the code (`gravelight/bots/bot_planner.gd`, `local_ai.gd`, `bots.json` `local_ai`): one bot of
the squad plans its own objectives. With `bot_local_ai` on (the default) and Ollama there, its brain is "small":
`gemma3:4b` on the GPU. Every call is an `HTTPRequest` node: nothing waits on the network on the main thread, one
request is in flight at a time, a timeout is 10 s. The model is asked at most once every 8 s (`ask_gap_s`), and
only when the options changed, the built-in brain changed its pick, or 20 s passed (T-237); the answer is capped
at 90 tokens. The rate does not depend on the round.

Measured (`--round=14 --live --secs=60`, one run a side, the loaded machine; the three rounds played out
differently, so the frame means are not comparable: 24, 11 and 5 zombies were up at the end):

| | `--ai=local` (gemma3:4b) | `--ai=squad` (built-in) | `--ai=off` |
|---|---|---|---|
| `bot_planner.gd`, ms per tick | 0.029 | 0.021 | - |
| Model answers in 69 s | 5 (and 7 asks skipped, 3 scripted picks) | 0 | 0 |
| Seconds per answer (the GPU otherwise idle) | 0.28 | - | - |
| Frame mean / zombies' share | 10.72 / 2.29 + 0.97 | 8.08 / 1.42 + 0.66 | 8.06 / 1.27 + 0.59 |

- **On the CPU the model costs nothing that can be seen**: 0.008 ms a tick more than the built-in brain. It
  cannot explain a drop on the main thread. (The planner's own option list is a spike of 6-13 ms every few
  seconds with or without the model: `gather` -> the errand list's path queries; see the list below.)
- **On the GPU it is plausible as a hitch, not as a sustained drop.** While the model answers, the card is doing
  inference and drawing the game at once. Idle it took 0.28 s an answer here; T-237 read 0.9-1.1 s an answer
  from the owner's own log during a match. Five answers a minute is 2-9 % of the time. That fits a dip for a
  second every 10-20 s. It does not fit 15 FPS for a whole round, unless the card's memory is the limit (the
  model holds 2.9 GB of it; on a 32 GB card that is not).
- **The test the owner can run** (two matches to round 15 on Map 0, same squad, with the frame log on):
  the AI bot's brain in Settings (`bot_ai_brain`) on "builtin" (or the local AI bot off) for one, "auto" for the other;
  or leave the setting and run `ollama stop gemma3:4b` before the first. Compare the GPU ms column and the
  spike rows of the two `logs/frame_log_*.csv`. And once more with no other Godot or WSL job running.

### The 16.6 ms target: where it stands

Not met. With the frame at 8-9.5 ms, a tick's scripts may spike by about 7 ms before the frame passes 16.6. What
spiked above that at rounds 13-15, what this work did about it, and what is left:

| Spike | Size before | Now | State |
|---|---|---|---|
| A severed limb's piece cut on the spot (a crawler, a grenade in a pack, a head) | 5-28 ms | gone from the lists | fixed (first part) |
| A woman's body of a medium / heavy build merged at her spawn | 21-42 ms | not seen again in a trace of two rounds | fixed (first part) |
| An Inn survivor or patron rising: their risen mesh merged | 40-106 ms | 17-25 ms | reduced; the rest of that tick is not traced |
| A risen person's limb cut on the spot (`PeopleBodies.piece_mesh`) | 7-18 ms a piece, 32 ms for a crawler | - | fixed: cut ahead by a worker (`warm_mesh_pieces`) |
| A relief squad arriving: 3-6 bodies merged in one tick | 60-120 ms (38-41 measured for 2-3) | not seen in six rounds; one 19.5 ms `relief_squad` tick | fixed: merged by workers, the squad fielded when they are in (`_spawn_squad_soon`, at most 0.6 s later) |
| A soldier rising: its risen body merged | 20-25 ms each | (the same one tick above) | fixed: merged by a worker while the soldier lives |
| A risen soldier's first lost limb: its zombie body merged | 20 ms | - | fixed: built at load (`ReliefSquad._warm_bodies`) |
| A spawn tick (`zombie_director.gd`) | 21-38 ms | 18-25 ms, once or twice a round | **left**: not the bodies any more (the trace shows no merge after load); not traced further |
| A bot's first shots (`act.fight`) | 18-39 ms, once a match, at the same second every run | the same | **left** (a first-use load inside the fight executor) |
| Bot thinks: `think.ee` 5-14, `think.context` 12-14, `think.shared` 6-7, `act.retreat` / `act.cover` / `act.escort` 8-26, `loco.plan` 8-11 | | the same | **left** (T-237's list; the bots' own code) |
| The planner's option list (`bot_planner.gd`) | 6-13 ms every few seconds | the same | **left** |
| A kill's listeners: a power-up built in script at each drop (`powerup_manager` 6-7 ms), the horror layer's first flies (27 ms once), `ScripBonuses` (9 ms once), a voice line loaded (`vo.load` 2-10 ms) | | the same | **left**: `claude/gore-rework` is in the horror / gore files now |
| Jakub's breakout tick | 20-29 ms, once a match | the same | **left** |

On the idle machine, before the worker-thread changes of this part, the live round at 15 with the squad had 4
frames over 16.7 ms of 3600 (21 before the work), none over 33 (5 before), 1 % low not recorded then. On the
loaded machine the last build read 140-320 frames over 16.7 ms of 3600 and a 1 % low of 24.5-28.1 ms a frame
(36-41 a second, no renderer): that is the machine (the same build's mean went from 8.3 to 10.7-12.3 ms), and
it is the honest state of the number: **this build's worst frame and 1 % low on an idle machine were not
re-measured after the last commit.** The command: `tools/bot_perf.sh <tag> map00_crossroads 3 --live --secs=60
--seed=7 --round=14 --ai=squad`, then `grep "1% low"` in `.smoke_logs/t237/<tag>/`.

What it would take to reach the target, in order of size: the bots' executors and thinks (most of the
remaining ticks over 12 ms; a time budget per think, as T-237 began), the spawn tick, the survivor's rise, the
kill listeners (pooled pickups; the gore branch's pools). Each needs its own trace first.

## Checks run

- `check_scripts` on the last commit: 955 scripts, 0 failed (952 on master + `tick_spring.gd`, `move_rates.gd`,
  `test_movement_perf.gd`).
- New test `gravelight/tests/unit/test_movement_perf.gd`, 17 tests (the last four are the second part's: a dressed
  body merged by a worker equals the one merged on the spot, a body asked for early is merged on the spot, a
  squad's plan rolls the look the soldier rolls, a person's pieces cut ahead equal the ones cut on the spot); the
  first 13: `TickSpring` step for step the old code at
  60 FPS, the same peak at 30 / 72 / 144 / 240 / 500 FPS (and the old per-frame step shown to peak over 1.2
  times higher at 240), a shown value that moves every frame, a 2 s frame survived; the player's recoil kick and
  landing dip at 30 / 144 / 240 FPS against 60; `_ease60`; the pad's turn by the frame's time; the frame look
  taken once; the gun sway at 30 / 144 / 240 against 60; the hop gate over the whole grid; the wedge check's 3 s
  and its number of looks; pieces cut ahead equal to pieces cut on the spot; a piece asked for early is cut on
  the spot; `warm_up` builds every body a kit can spawn.
- The related existing tests, alone: `-gselect=feel` 27, `zombie` 56, `leap_hop` 4, `player_bot` 21, `t237` 13,
  `weapons` 74: all passing.
- **The full GUT suite on the last commit**: 240 scripts, 2383 tests, 2382 passing, 1 risky (the known
  `test_neural_lines_are_loudness_normalised` "did not assert"), 0 failing, 552 s. Master today: 2366 tests, the
  same one risky; the 17 more are this branch's.
- **Smokes** (`tools/run_smokes.sh .smoke_logs/perf_smokes <filter>`), first on the commit before the second part:
  28 run, 26 passed: `smoke_map00`, `_alive`, `_cellar_bay`, `_loop`, `smoke_bots`, `smoke_bots_shop`,
  `smoke_bots_u10`, `smoke_coop`, `smoke_sherman`, `smoke_move_feel`, `smoke_feel`, `smoke_zombie_anim`,
  `smoke_low_g`, `smoke_map04d`, `_world`, `smoke_ladders`, `smoke_botmode`, `smoke_inn_survivors`,
  `smoke_inn_opening_paths`, `smoke_map01`, `_systems`, `_world`, `smoke_horse`, `smoke_horse_boss`, `smoke_jakub`,
  `smoke_hard_truth`, `smoke_menus`. **Two failed in that batch**: `smoke_bots_shop_m0` ("no squad bot did
  'bench'": the bots bought tonics and the Crucible instead) and `smoke_squads` ("no round ended after the
  rise"). Both ran while the other workers' renders had taken the CPU. Then, on the last commit
  (`.smoke_logs/perf_smokes2`): `smoke_squads`, `smoke_bots_shop_m0`, `smoke_inn_survivors`, `smoke_hard_truth`,
  `smoke_coop`, `smoke_sherman`, `smoke_map00` (4) and `smoke_people_extra`: 11 run, 11 passed, the two included.
  I did not run those two on master to see how often they fail there; they depend on what the bots choose to do
  in a few minutes of play. `smoke_bots`, `smoke_bots_shop`, `smoke_bots_u10`, `smoke_jakub` and the other smokes
  of the first batch were not run again after the second part's commits. `smoke_marks` (known to fail on
  master) was not run.
- The owner's bench scene runs to its end on the branch headless (`perf_marks` without `--hitch`: the `in play`
  and `pause map open` lines print).
- The measurements of the first part: `tools/bot_perf.sh` (7 batches, 38 runs: the six tags named under Setup, and a first
  live "after" batch `mp_after_live` taken before item 5, which the table does not use), `tools/move_rates.sh`
  (2 batches of 7 runs).

## Not measured

- **GPU frame rate and frame times on the owner's hardware.** No window was opened.
- **A networked co-op match.** "Co-op" above is the offline squad (3 bots, Jakub, the map's companion) on the
  host's code path. Nothing here touches the replication or the puppets' tick (`_puppet_tick` returns before the
  chase), and the severed pieces are local on every peer; `smoke_coop` covers the function. A client's frame
  cost was not timed: there is no headless tool for it.
- **The look of any of it.** The springs, the pad and the sway were measured as numbers, not seen.
- **Whole-map load time** before and after (only the three warm-ups' own cost, above).

## The command for the owner's GPU bench

The existing bench is `perf_marks` (T-070): Map 0, round 15, 24 zombies kept alive, 3 bots + Jakub, vsync off;
it prints `[perf] in play: avg FPS ..., worst frame ..., 1% low ...` after 24 s and the pause map's cost after
34 s, then quits. It opens a window. It is the same scene on master and on the branch (the flags used here
exist on both), so run it once in each checkout and compare the two `in play` lines. From a Windows prompt:

```
cd /d C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate
tools\dl_godot\Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --resolution 1920x1080 --path . res://gravelight/tools_src/perf_marks.tscn -- --map=map00_crossroads --preset=high --no-marks > logs\fps_master.log
tools\dl_godot\Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --resolution 1920x1080 --path .claude\worktrees\agent-ac516329e86ce7112 res://gravelight/tools_src/perf_marks.tscn -- --map=map00_crossroads --preset=high --no-marks > logs\fps_branch.log
findstr /C:"in play" logs\fps_master.log logs\fps_branch.log
```

The first line needs the main checkout on master; the second runs this branch from the worktree it was built
in (imported, LFS pulled). If that worktree is gone: `git worktree add ..\gl-movement-perf claude/movement-perf`,
then in it `git lfs pull` and one headless `--import`, and use its path. Add `--breakdown` for the CPU / GPU
split per frame and the draw calls, `--map=map01_kaltenbrunn` for the other map. For a played session rather
than the fixed scene, `Play.bat`'s line with `-- --frame-log` (T-133) writes `logs/frame_log_<time>.csv` in
either checkout.

The movement side on a real screen: play at 240 Hz and at a 60 FPS cap and fire the same gun; the kick should
be the same size. Before, it was visibly stronger uncapped.

## Open items

1. **The 16.6 ms target is not met**: the table in the second part lists every spike that is left, with its size.
   The relief squad's bodies, which were the largest when the first part was written, are merged on worker
   threads now.
2. **A survivor's rise still costs 18-20 ms** after the warm-up (it was 40-106). What is left in that tick was
   not traced.
3. **A bot's first shots** (18-20 ms once a run, at the same moment every run: a first-use load inside
   `act.fight`), **the egg help's plan** (`think.ee`, 5-9 ms every few seconds with Full Partner on) and **voice
   lines loaded at a kill** (6-10 ms) are T-237's remaining list, unchanged.
4. **The zombies' animation and foot rays for zombies behind the camera.** Tried (quarter-rate animation and no
   foot rays more than 75 degrees off the view axis, as the squad's bodies do since T-237) and taken out again:
   in the measured scene 22 % of the horde was out of view and the saving was inside the run-to-run spread
   (under 0.15 ms). It would pay when the player runs from a horde; it was not measured there, so it is not in.
5. **Key press to the eye** (above): a choice for a session with a window.
6. `physics_jitter_fix` (above): needs a real display to judge.
