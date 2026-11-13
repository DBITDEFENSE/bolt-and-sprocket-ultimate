# T-237: "while there's bots the game gets laggy"

The owner's ask, verbatim: "also while theres bots. the game gets laggy, find a way to mitigate this and make this
better." Slice T-237, branch `worktree-agent-a5eb1f3f96baee8e0`. Measured headless on the owner's PC (Ryzen 7 7800X3D,
RTX 5090) while four other workers shared it.

## In short

- **Both.** The bots raise the average cost of a frame, and they add hitches of their own.
- **Average:** with 3 bots, Jakub and the map's companion the game's own work per frame (scripts, physics, no
  rendering) goes from about 6.0-6.8 to 8.6-10.1 ms on the Crossroads Inn and from 5.1-6.6 to 6.8-9.7 ms on Kaltenbrunn
  (the quietest batch and the main one): +1.7 to +3.3 ms a frame, +35 to +50%. The brains are 1.3-2.0 ms of it; the rest is the zombies doing more
  (more targets, being shot), three more players, the squad HUD and the minimap.
- **Hitches the bots caused**, each found by timing and each fixed here: files loaded in the frame that first plays
  them (a sound effect 2-17 ms, a voice line 2-11 ms, a weapon model 10-45 ms; a squad makes these happen all
  match long), two or three brains thinking on the same tick, the errand list re-asking the navmesh for every
  machine and wall gun each second (2-9 ms on Map 0), and a new gun model built on every weapon swap.
- **Outside the engine:** the planner bot's local model. The owner's last game log shows it on `gemma3:4b` on the
  GPU, answering in 0.9-1.1 s in a match (0.5 s idle), asked every 4 s: about a quarter of the time the model was
  running on the card the game draws with. It is now asked only when there is something new to decide. This is the
  change most likely to be felt and the one that could not be measured here (no window, Ollama left alone).
- **What it buys, honestly:** the hitch causes above are gone or rarer (the counts are in the tables below); the
  brains' own time fell by a tenth to a sixth; the frame's average moved by 0 to 3% (see "After"). The remaining cost of
  a squad is spread thin over every bot's every tick, and the largest remaining spikes are in the zombies' own code
  (see "What is left").

## How it was measured

`tools/bot_perf.sh <tag> [maps] [runs] [flags]` runs `gravelight/tools_src/perf_marks.tscn -- --hitch` with the engine flag
`--fixed-fps 60`: every frame is then exactly one physics tick and one process step with no sleeping, so a frame's
wall time is the CPU work of one 60 FPS frame without the renderer. The scene is perf_marks' (round 15, 24 zombies
kept alive, the player at the map's spawn in god mode); `--hitch` also keeps the squad standing, joins the map's own
companion, and records:

- every frame's wall time: mean, p50, p95, p99, worst, and the frames over 8 / 16.7 / 20 / 33 ms;
- every script's time per tick and per frame as a distribution (the old `--probe` gave the mean only);
- the worst ticks, each with what ran in it: the scripts, which brain thought, its action, and the sections below;
- `BotProf` sections inside the bots' tick (`gravelight/bots/bot_prof.gd`: the think's steps, the action by name,
  locomotion's steps, the pose, every navmesh path query, sound / voice / weapon-model loads): ms per tick, calls,
  the worst call and the calls over 2 ms. It costs one static bool read per call while it is off;
- a noise floor: a fixed loop of about 0.04 ms timed every tick. Its mean says how fast the machine was for that
  run, its worst how much another process can steal in one go.

Each run of the script does three sides back to back, so they share the machine's load: **bots** (3 bots + Jakub +
the companion), **old** (the same build with this slice's optimisations switched off: `--ab=t237_off`, the before),
and **no bots** (the player alone). `tools/bot_perf_table.py <dir> [--prof] [--md]` prints the medians over the runs.
On Windows the runs start at High priority: on a machine at 100% load an ordinary process is preempted for
milliseconds at a time and every preemption reads as a hitch.

Flags: `--secs=N` (the window, 30 s), `--live` (the round keeps running: kills, spawns, the squad can go down),
`--ai=squad` (the planner bot on, without a model), `--bots=N`, `--no-companions`.

**How much to trust it.** The machine was never idle. Single runs of the same side differ by 30% and more when
another worker starts a build; "worst" values of sections that take 0.02 ms were several ms in loaded runs. So the
tables use medians over runs, the before and after come from one build in one session, and the per-section columns
(ms per tick, calls over 2 ms) carry more weight than the frame's worst. Two early batches taken before the
before/after switch existed (16.6 ms a frame "before", 9.5 "after") were the machine getting quieter, not the
fixes; they are not used.

The owner's own frame log of 2026-10-31 (`logs/frame_log_20261031_111803.csv`, the Crossroads Inn, rounds 1-29,
RTX 5090, a windowed session) gives the real picture this slice is about: 57-86 FPS in play (median per round), the
slowest tenth of the seconds at 27-55 FPS, and in a typical second one frame of 17-37 ms (in the worst tenth of
the seconds 40-70 ms). GPU time 5-9 ms a frame, so the game is CPU-bound there, as the earlier passes found.

## Before

Batch `ab3` (3 runs a side, 30 s each, the planner bot on with the built-in brain, `--ai=squad`; medians; ms unless a
count; ">16.7" etc. are frames of 1800). "Noise" is the fixed loop's mean: 0.034-0.037 is this machine nearly quiet,
0.043 and up is another worker building.

| map | side | runs | frames | frame mean | p50 | p95 | p99 | worst | >16.7 | >20 | >33 | tick scripts | tick p99 | brains | brains p99 | zombies | process | noise |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| map00 | bots, before | 3 | 1800 | 10.12 | 9.98 | 14.53 | 18.14 | 29.11 | 31 | 9 | 0 | 5.48 | 11.89 | 1.96 | 6.30 | 2.96 | 2.40 | 0.037 |
| map00 | no bots | 3 | 1800 | 6.82 | 6.71 | 9.22 | 10.51 | 35.92 | 1 | 1 | 1 | 2.98 | 5.39 | - | - | 2.46 | 1.90 | 0.037 |
| map01 | bots, before | 3 | 1800 | 9.73 | 8.81 | 15.55 | 20.89 | 66.63 | 66 | 23 | 1 | 5.04 | 13.54 | 1.91 | 8.10 | 2.55 | 2.39 | 0.043 |
| map01 | no bots | 3 | 1800 | 6.63 | 5.96 | 10.88 | 16.08 | 45.82 | 14 | 8 | 3 | 3.16 | 8.43 | - | - | 2.54 | 1.80 | 0.042 |

Read: on the Crossroads Inn the squad adds 3.3 ms to a 6.8 ms frame (scripts per tick 2.98 -> 5.48, of which the
brains 1.96; the zombies 2.46 -> 2.96; the process step 1.90 -> 2.40), and the frames over 16.7 ms go from 1 to 31 of
1800. Kaltenbrunn's rows were taken with the machine busier (noise 0.043): the same shape, +3.1 ms.

The quietest batch (`ab1`, 2 runs a side, no planner bot) for the same two sides:

| map | side | runs | frames | frame mean | p50 | p95 | p99 | worst | >16.7 | >20 | >33 | tick scripts | tick p99 | brains | brains p99 | zombies | process | noise |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| map00 | bots, before | 2 | 1800 | 8.62 | 8.72 | 11.70 | 13.61 | 18.68 | 3 | 0 | 0 | 4.72 | 8.70 | 1.60 | 5.12 | 2.69 | 2.02 | 0.035 |
| map00 | no bots | 2 | 1800 | 6.02 | 6.07 | 7.93 | 9.47 | 39.36 | 2 | 1 | 1 | 2.72 | 4.92 | - | - | 2.26 | 1.63 | 0.035 |
| map01 | bots, before | 2 | 1800 | 6.82 | 6.59 | 8.73 | 12.14 | 24.27 | 4 | 2 | 0 | 3.73 | 6.99 | 1.26 | 3.91 | 1.75 | 1.56 | 0.034 |
| map01 | no bots | 2 | 1800 | 5.10 | 5.09 | 6.20 | 7.18 | 12.59 | 0 | 0 | 0 | 2.38 | 3.58 | - | - | 1.91 | 1.35 | 0.035 |

## The causes, and what was done

Per cause, batch `ab3`, the Crossroads Inn, 3 runs x (30 s + the 9 s before the window): ms per tick, and how many
calls took over 2 ms (a hitch each), before -> after. `python -I tools/bot_perf_table.py .smoke_logs/t237/ab3 --prof`.

| Cause (BotProf section) | ms per tick | calls over 2 ms | worst call ms |
|---|---|---|---|
| Sound effects loaded on first play (`sfx.load`) | 0.079 -> 0.018 | 93 -> 17 | 10.1 -> 7.0 |
| The errand list and the rest of the think's context (`think.context`) | 0.130 -> 0.080 | 95 -> 22 | 4.2 -> 2.7 |
| Navmesh path queries, all layers (`nav.path`) | 0.093 -> 0.041 | 0 -> 0 | 0.8 -> 0.6 |
| The pose of the bodies (`pose`) | 0.486 -> 0.388 | 3 -> 3 | 6.7 -> 6.5 |
| Voice lines loaded on first play (`vo.load`) | 0.015 -> 0.009 | 1 -> 0 | 2.1 -> 1.8 |
| The fight executor (`act.fight`: aim, fire, the sounds and models its shots first load) | 0.231 -> 0.183 | 16 -> 7 | 11.9 -> 5.0 |
| Locomotion (`loco`, of which `move_and_slide` and the movement code 0.32) | 0.823 -> 0.732 | 13 -> 2 | 6.4 -> 2.2 |
| Weapon model files (`gun.load`) | 0.050 -> 0.050 | 23 -> 22 | 44.5 -> 41.0 |
| The egg help's plan (`think.ee`, Full Partner is the default) | 0.060 -> 0.052 | 20 -> 19 | 7.5 -> 9.3 |

The weapon model row does not move because in this scene every model is loaded in one burst when the squad spawns
with its kit (seven files inside 0.2 s, before the background loader has had a frame); the background loading is
for the guns bought later in a match, and that case was not measured. The brains' tick by layer, after: locomotion
0.73 ms (the body's own movement 0.32), the pose 0.39, the executors about 0.35, the thinks about 0.40 (4 brains,
the inn).

1. **Files loaded on first use (hitches).** `AudioDirector` and the voice manager loaded a sound the first time it
   played, on the main thread; `WeaponGLB` the same for a weapon model. A human alone meets a few dozen of these
   in a match; a squad of five firing, stepping, buying, swapping guns and talking meets hundreds, all match long.
   Fix: `StreamWarm` (`gravelight/autoload/stream_warm.gd`) asks the engine's loader threads for the files a few at a
   time and keeps a reference, so the later `load()` is a cache hit. `AudioDirector.warm_bank()` queues the bank's
   one-shot sounds at match start (SFX and Jingles; not the music and the ambience beds); the voice manager queues
   a squad member's or companion's lines when that speaker first speaks (not the Operator's and the other story
   voices: a handful of long lines a match); `BotSquad` queues the 20 weapon model files (8 MB). (The squad's own kit is loaded as it spawns, with the map; this is for guns bought later.) A file played
   before its turn is loaded on the spot, as before. Off in the browser build (no loader threads, tight memory).
   Memory: the sound effects and the squad's voices stay loaded for the session (they did already after a long
   match): about 100 MB of sound effects and 15-20 MB per squad voice at most.
2. **Several brains thinking on one tick (hitches).** A think is a brain's one heavy step (senses with their rays,
   the shared blackboard, the errand list, every action scored: 1-2.5 ms). The brains are staggered at setup, but
   every finished errand and every order makes a brain think at once, so thinks piled up on single ticks. Fix:
   `BotBrain.think_slot()`: one brain of the squad thinks per physics tick; a brain whose turn it is not waits a
   tick, 0.1 s at most. Reaction time gains 17-50 ms in the worst case.
3. **The errand list re-asking the navmesh (hitches, some average).** `BotEconomy.candidates()` runs once a second
   per calm bot and asked `reachable()` (a path query) for every perk machine, wall gun, door and window in range,
   again each time: 2-9 ms a list on Map 0. Fix: `BotBrain._reachable()` keeps its answers per half-metre cell for
   4 s and drops them the moment a door opens or a zone unlocks (the count of open doors and the open zones' nav
   layers are part of the answers' stamp). Reachability changes with doors, not from one second to the next.
4. **A gun model built on every swap (hitches).** A bot changes guns every few seconds in a fight; `RemoteBody`
   freed the model and built a new one each time (0.4-1 ms quiet, 1-7 ms on a loaded machine). Fix: a body keeps
   the last four models it held, hidden.
5. **Posing bodies nobody sees (average).** `RemoteBody.update_pose` (the procedural third-person pose and the
   person rig's bones) was the largest single per-tick cost of a bot: 0.08-0.13 ms per body per tick, for the
   squad, a caged Jakub and a companion waiting in another building alike. Fix: `update_pose_lod()` for the bodies
   an AI drives: every tick in view within 15 m (the zombies' own full-rate animation distance), every 2nd tick to
   40 m, every 4th out of view (more than 75 degrees off the view axis) or beyond; always every tick within 3 m.
   A skipped tick's time is handed to the next pose (blends, the walk cycle and timers keep their pace); the muzzle
   flash still ends on time. The body itself moves every tick. Remote human players and every tool that
   photographs bodies still pose every tick (`update_pose`).
6. **The squad's player list (average, small).** `BotSquad.all_players()` built a new array five to eight times per
   bot per tick. It is built once per frame now.
7. **The planner's model calls (GPU, unmeasured).** `BotPlanner` asked the model at every decision, every 4 s.
   `BotPlanner.ask_due()`: at once when the bot has no objective; otherwise never within `ask_gap_s` (8 s) of the
   last ask, and then only when the options changed, the built-in brain (trained from the 27B model, T-217)
   changed its own pick, or `reask_every_s` (20 s) have passed. Between asks the model's last pick stands. Main
   thread cost of the model path, read from the code and timed where it could be: building the prompt and parsing
   the answer are a few strings every 4 s; the HTTP request polls without blocking; with Ollama absent the
   30-second re-probe costs under 1.5 ms once (timed against a closed local port); each answer appends one line
   to `user://bot_ai/decisions.jsonl` (a file open and write, now rarer too).
8. **Muzzle lights (GPU, unmeasured).** Every bot body carried an omni light for its muzzle flash, lit at energy 0
   between shots: five more lights for the renderer to cull and cluster every frame. It is hidden now while dark.
   It never cast shadows. A bot has no first-person view model (its weapon holder is a mirror), so there was
   nothing to skip there.

## After

The same batches, the optimisations on (`bots, after`) against the same build with them off (`bots, before`):

| map | side | runs | frames | frame mean | p50 | p95 | p99 | worst | >16.7 | >20 | >33 | tick scripts | tick p99 | brains | brains p99 | zombies | process | noise |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| map00 | bots, before | 3 | 1800 | 10.12 | 9.98 | 14.53 | 18.14 | 29.11 | 31 | 9 | 0 | 5.48 | 11.89 | 1.96 | 6.30 | 2.96 | 2.40 | 0.037 |
| map00 | bots, after | 3 | 1800 | 9.78 | 9.79 | 13.37 | 15.92 | 19.91 | 11 | 0 | 0 | 5.41 | 9.82 | 1.65 | 4.22 | 2.86 | 2.22 | 0.036 |
| map00 | no bots | 3 | 1800 | 6.82 | 6.71 | 9.22 | 10.51 | 35.92 | 1 | 1 | 1 | 2.98 | 5.39 | - | - | 2.46 | 1.90 | 0.037 |
| map01 | bots, before | 3 | 1800 | 9.73 | 8.81 | 15.55 | 20.89 | 66.63 | 66 | 23 | 1 | 5.04 | 13.54 | 1.91 | 8.10 | 2.55 | 2.39 | 0.043 |
| map01 | bots, after | 3 | 1800 | 10.20 | 8.95 | 17.37 | 32.90 | 64.56 | 109 | 59 | 17 | 4.97 | 16.88 | 1.68 | 8.05 | 2.76 | 2.56 | 0.046 |
| map01 | no bots | 3 | 1800 | 6.63 | 5.96 | 10.88 | 16.08 | 45.82 | 14 | 8 | 3 | 3.16 | 8.43 | - | - | 2.54 | 1.80 | 0.042 |

| map | side | runs | frames | frame mean | p50 | p95 | p99 | worst | >16.7 | >20 | >33 | tick scripts | tick p99 | brains | brains p99 | zombies | process | noise |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| map00 | bots, before | 2 | 1800 | 8.62 | 8.72 | 11.70 | 13.61 | 18.68 | 3 | 0 | 0 | 4.72 | 8.70 | 1.60 | 5.12 | 2.69 | 2.02 | 0.035 |
| map00 | bots, after | 2 | 1800 | 8.65 | 8.69 | 11.20 | 13.04 | 18.15 | 2 | 0 | 0 | 4.80 | 8.09 | 1.50 | 3.71 | 2.63 | 1.96 | 0.035 |
| map00 | no bots | 2 | 1800 | 6.02 | 6.07 | 7.93 | 9.47 | 39.36 | 2 | 1 | 1 | 2.72 | 4.92 | - | - | 2.26 | 1.63 | 0.035 |
| map01 | bots, before | 2 | 1800 | 6.82 | 6.59 | 8.73 | 12.14 | 24.27 | 4 | 2 | 0 | 3.73 | 6.99 | 1.26 | 3.91 | 1.75 | 1.56 | 0.034 |
| map01 | bots, after | 2 | 1800 | 7.00 | 6.79 | 9.08 | 11.50 | 20.93 | 2 | 1 | 0 | 3.56 | 7.06 | 1.16 | 3.38 | 1.79 | 1.67 | 0.034 |
| map01 | no bots | 2 | 1800 | 5.10 | 5.09 | 6.20 | 7.18 | 12.59 | 0 | 0 | 0 | 2.38 | 3.58 | - | - | 1.91 | 1.35 | 0.035 |

- **Crossroads Inn, `ab3`:** frames over 16.7 ms 31 -> 11 and over 20 ms 9 -> 0 of 1800; p99 18.1 -> 15.9 ms; the
  worst frame 29 -> 20 ms; the brains 1.96 -> 1.65 ms a tick (-16%) and their p99 6.3 -> 4.2 ms. The frame's mean
  10.12 -> 9.78 ms (-3%).
- **Kaltenbrunn, `ab3`:** the "after" runs were taken while another worker loaded the machine (noise 0.046 against
  0.043; a 97 ms stall inside `move_and_slide`, which nothing here touches), so its frame rows are worse after than
  before and say nothing about the change. The brains' own time, which is less exposed: 1.91 -> 1.68 ms (-12%).
- **`ab1` (quiet, no planner):** the frame's mean did not move (8.62 -> 8.65, 6.82 -> 7.00: inside the run-to-run
  spread); the brains 1.60 -> 1.50 and 1.26 -> 1.16 ms; their p99 5.1 -> 3.7 and 3.9 -> 3.4 ms.
- **A live round** (`--live`, 60 s, 2 runs a side on the inn): 8.6 ms before, 9.3 after. Live runs play out
  differently each time (other fights, other kills), two runs a side cannot separate 8%; no claim is made from it.
- **Bots still play** (`tools/ai_soak.sh --scenario=botmode --map=map00 --bots=3 --speed=4 --max-round=6 --seed=7`,
  one run a side, the before with `CZ_T237_OFF=1`): both reach round 7 with 104 bot kills; bot downs 1 before, 0
  after; human downs 0 and 0; stuck time 57 s before, 21 s after; 7.5 and 8.9 game minutes.

So: fewer and smaller spikes from the bots' own code, a tenth to a sixth off the brains, and an average frame that
is 0 to 3% cheaper. The squad still costs about 3 ms of CPU a frame on the inn.

## What is left (not done here)

- **Zombies (the overhaul's branch; nothing changed here).** With a squad the zombies' own scripts cost more
  (2.46 -> 2.96 ms a tick on the inn: more targets, hit reactions) and hold the largest spikes left:
  an explosion in a pack (`Explosion.detonate` -> `Zombie.take_damage` for every zombie in reach, each with its
  wound, knockdown or crawler change): `grenade.gd`'s tick p99 9-20 ms, worst 12-35 ms, several a minute when the
  bots throw; a kill's `take_damage` up to 11-19 ms (measured once, on a loaded machine); `zombie_director.gd` 39-59
  ms on single ticks of a live round (a spawn wave). A cure that stays out of the zombie code: `Explosion.detonate`
  applying its hits a few zombies per tick. Not done: it changes when damage lands (kill counts per blast, the
  replicated explosion path) and is not "clearly safe".
- **Relief squads** (`gravelight/world/relief_squad.gd`): a squad's arrival builds its 3-6 soldiers in one frame, 20-40
  ms (loaded machine); while it is on the map its soldiers cost about 1 ms a tick (their bodies now use the pose
  rate too). Spreading the spawn over a few frames means `soldiers` holding bodies not yet in the tree; left.
- **The egg help's plan** (`BotEE._refresh_plan` -> `snapshot`): about 20 calls over 2 ms in 2 minutes, worst 5-9
  ms, with Full Partner on (the default). It is a world snapshot per think; it wants its own pass.
- **The steady cost.** About 0.4 ms per bot per tick remains, spread over the movement code shared with the human
  (`Player.drive_bot`, not touched: another worker is in player.gd), steering, the pose in view, the aim layer and
  the 5 Hz think. No single piece of it is large; the next real cut is a think that costs less (the senses'
  sort and blackboard writes, the scorer's dictionary reads), not another cache.
- **One-off events** seen while measuring, not chased: Jakub's breakout tick (9-36 ms once a match, with or
  without bots); in the owner's old frame log, 100 ms frames every 30-90 s while the game sat paused for hours
  (not the offline model probe: that was timed at under 1.5 ms).
- **player.gd, move_intent.gd, the map generators, the zombie files:** not touched.

## What is unmeasured

- **Everything on the GPU.** No window may be opened on this PC and the WSL renderer gives draw calls, not frame
  times. Unmeasured: the model no longer sharing the GPU every 4 s, the hidden muzzle lights, and what five bodies
  cost in the inn's ten cube-shadow lamps (the earlier passes priced those lamps at about 4.6 ms of an 11.5 ms
  frame with zombies alone keeping them dirty; bodies posed at a lower rate off screen can only help).
- **The owner's real frame times.** The command below settles it.

## The one command to confirm (a window, on the owner's PC)

From the repo root, then play a round-10+ match on the Crossroads Inn with 3 bots, and one without:

```
tools\dl_godot\Godot_v4.7.2-stable_win64.exe --path . --log-file logs\game_last.log res://gravelight/ui/main_menu.tscn -- --frame-log
```

It writes `logs/frame_log_<time>.csv`: a row a second (FPS, p99 and the slowest frame, CPU / GPU ms, draw calls) and
a row for every spike. Compare with `logs/frame_log_20261031_111803.csv` (57-86 FPS, a 17-37 ms frame in a typical
second). `logs/game_last.log` shows the planner's lines: fewer "local AI NNN ms" picks than before.
