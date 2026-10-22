# GRAVELIGHT bot AI

Update 03 rewrites the AI teammates' brain. This file starts with the brain as it was before the rewrite and the
**baseline** numbers the rewrite has to beat (Update 03 section 0). The measuring tools are described after that
(section 9: the metrics logger and the soak test). The player-facing notes stay in `docs/gravelight/BOTS.md`.

## 1. The bots before Update 03 (T-031, plus later additions)

Code: `gravelight/bots/`. Tuning: `data/gravelight/bots.json`. The pure rules are in `bot_config.gd`
(tested in `test_bots.gd` and `test_bot_planner.gd`).

### Who decides what

| Piece | Job |
|---|---|
| `MapRoot` | In a solo match with `GameState.bot_count > 0`, it spawns a bot `Player` (`is_bot`) for each empty survivor slot (ids 2–4), starts an offline `NetMatch` that runs the co-op life cycle (down, bleed-out, revive, respawn, wipe), and adds a `BotSquad`. Round size counts each bot as 0.75 of a player (`scaling.bot_player_weight`). |
| `BotSquad` | Holds what the bots share. It hands out the **spawn kit** (a Thompson, Ironhide Stout and Second Wind, all free), decides **who leads** (the human, or the first standing bot when the human is spectating), and decides **who revives whom** (the human first, then bots; the nearest standing bot that isn't busy). It keeps the **claims** on errand objects (one bot per window or machine, cleared every round), the **kill-share** ledger, and the squad's **callouts** (survivor VO lines, one at a time, with a 7 s cooldown). |
| `BotBrain` | One per bot. A **mode machine**, re-decided at 8 Hz (`perception.think_hz`, staggered 0.05 s between bots). Movement, aiming and firing run every physics frame. |
| `BotPlanner` + `LocalAI` | Optional, on one bot only (`local_ai.bot_index`). Every 4 s it lists objectives (easter-egg steps, the power, doors, shopping, "stick with the team"), each with a score. A local Ollama LLM picks one, or the highest score wins when the model is offline, slow or answers nonsense. The pick becomes that bot's errand. With `GameState.bot_ai_mode = "off"` there is no planner at all. Every soak run uses that setting. |

### The modes (`BotBrain._decide_mode`, in priority order)

1. **REVIVE.** `BotSquad.revive_target_for(self)` names a downed teammate. The bot goes unless it is swarmed (a
   zombie within 3 m **and** either hurt below 40% or 3+ zombies within 6 m), but goes anyway when the target has
   15 s or less of bleed-out left. On arrival it holds for `revive_seconds` (4 s, or 2 s with Second Wind) by
   calling `coop.set_reviver` directly. It stops to shoot while a zombie is within 3 m and more than 15 s of bleed-out remain.
2. **FLEE.** A zombie within 3 m and (hurt, crowded, or the gun is dry). The bot kites to an open navmesh point 4–6.5 m
   away, picked from 12 directions, away from the zombies' centroid and toward the leader, and shoots on the move. It keeps
   fleeing for at least 1.2 s and while anything is within 4.8 m.
3. **FIGHT.** It has a target. Target choice: every active zombie within 26 m is scored (distance, minus a bonus
   when it is near a teammate, attacking, or at a window). The bot skips zombies the human is aiming at when the
   kill-share rule says the human is short of kills, then takes the first of the best 3 with a line of sight.
   Aim turns at the skill's rate. The error settles from `aim_error_deg` to `settle_error_deg`, and the bot fires
   inside `fire_tolerance_deg`, in bursts for automatics. It reloads, swaps to a loaded gun with a zombie within 6 m,
   and knifes anything within 1.7 m. It backpedals from zombies inside 2.6 m and moves to its slot if the leader gets far.
4. **ERRAND** (only when quiet: no zombies, the round break, or the nearest zombie beyond 7 m with 3 or fewer
   left). The highest score wins: boards within 9 m (30 minus distance), wall-gun ammo under 35% reserve (60), an
   ammo box (62), a perk from round 3 (45, up to 4), a better wall gun from the wishlist (20 + price/50), a door
   (25; the one the human looks at or stands nearest; 300 Scrip reserve; at most 1 per round, 20 s into the round),
   the Crucible from round 8 in the break (80). Everything must be within 24–30 m of the leader. Errands time out
   after 20 s. Bots never flip the power.
5. **FOLLOW.** A formation slot 3.2 m from the leader at 140°, −140° and 180°. If the slot is off the navmesh, the bot tries the same slot closer in, mirrored, or straight behind. It stays out of the leader's
   20° line-of-fire cone (sidesteps 1.8 m after 0.35 s in it) and out of doorways (1.3 m). It sprints beyond 11 m.
6. **DOWNED.** It lies still and shoots the pistol at whatever is within 14 m.
7. **OUT.** It bled out and spectates until the next round. It respawns with the start pistol, and the kit gives back the Thompson and the perks.

### Perception

- 8 Hz. Each think reads **every active zombie on the map** from the director (`active_zombies()`): there is no
  sight cone, no hearing and no memory. Awareness is omniscient, and only **shooting** needs a line of sight
  (at most 3 rays per think, from the eye; walls and closed doors block).
- "Danger" and "crowd" are plain distance counts (3 m, and zombies within 6 m). No threat types, speeds or "is it
  coming for me."
- The bots don't collide with each other. `_move` pushes apart anything inside 1 m of any player (bots and
  humans), which is the only personal-space rule.

### Known hacks and hard-coded behaviour

- **Teleports.** In FOLLOW, if the leader is more than 14 m away and the path is finished or empty for 8 s, the bot
  teleports to a navmesh point 2.2 m behind the leader. The leader must be able to see that point; nobody checks
  whether anyone can see the **bot** vanish. It also teleports when it falls below y = −20. The count is `BotBrain.teleports`.
- **Stuck handling** in `_move`. The bot is stuck when it moves less than 0.015 m in a frame while it wants to move. It jumps
  after 1.2 s and drops the goal and repaths after 3 s. There is no nudge stage, and nothing else watches for a lack of progress.
- **The free kit.** Every bot starts with a Thompson, Ironhide Stout (250 HP) and Second Wind (2× revive speed)
  at no cost and outside the power rule. The perks come back after every revive, and the Thompson after every
  respawn (`spawn_kit.restore_after_down`).
- **The free pistol ammo.** The start pistol is refilled at every round start (`round_start_pistol_refill`).
- **The claims** (one bot per window, machine or door) are cleared at every round start. The revive assignment is
  "nearest free bot" and is recomputed at every think. The bot doesn't check whether the path is safe.
- **Hard-coded thresholds in code** (not in bots.json): the 0.8 s target-lost timeout, 6 m swap-instead-of-reload,
  60% mag top-up when idle, 1.2 s / 1.6× flee hysteresis, 12 retreat samples 4–6.5 m out, a 0.42 s weapon swap,
  a 0.7 s errand re-pick cooldown, the stuck thresholds above, and an eye 1.55 m up.
- **The shots** are traced in the brain with WeaponHolder's damage rules. The bot's WeaponHolder is inventory only.
  `damage_taken_mult` exists per skill (veteran 0.9).
- **Shopping** only buys a wall gun that ranks higher on the wishlist than the best one it holds. The kit already
  holds the Thompson, so on Map 0 bots never buy a wall gun (only the BAR and StG 44 rank higher, and Map 0 has neither).

## 2. Baseline (before the rewrite)

Measured on 2026-10-22 on master `57820ea` plus the three metric hooks (no behaviour change). The bots were on
`regular` skill with the local AI off, playing headless with `tools/ai_soak.sh` (section 3 explains the metrics). The raw
CSVs stay out of git (`logs/ai_runs/`). These are the tables they produced. Every change in Update 03 must beat
these numbers.

### Headline (the Update 03 section 0 numbers)

| Metric | player3 (3 bots + scripted player, Map 0, 3 runs to the wipe) | bots3 (3 bots alone, Map 0, 3 runs) | cousins (round 10 forced, 3 runs) |
|---|---|---|---|
| Highest round reached | **9** (runs: 8, 9, 7; mean 8.0) | **6** (6, 6, 5; mean 5.7) | wiped in round 10 every run, after 36–54 s |
| Bot downs per round | **0.58** (14 downs in 24 rounds) | **0.53** (9 in 17) | 10 downs in 3 × <1 min |
| Revive success rate | **83%** (10 of 12 judged; 21 attempts, 10 completed; mean time to revive 16.3 s) | **0%** (no revive ever happened: the three go down together) | 33% (1 of 3) |
| Time stuck | **124 s per run** (11.3 s per game minute, all short stalls: 0 stuck recoveries, 1 stretch over 1.5 s) | 140 s per run (19.6 s/min; 1 recovery) | 19 s per run |
| Teleports | **0** | 0 | 0 |
| Friendly blocking events | **25.7 per run** (2.4 per game minute), **0 sustained** | — (no human) | 0 |
| Scrip wasted | **0** (no wall gun was ever bought) | 0 | 0 |
| Kar98k bought after round 10 | 0 | 0 | 0 |
| Ammo-empty moments | **104 per run** (9.5 per game minute; 145 s per run with an empty mag and a zombie within 6 m) | 90 per run (12.6/min; 152 s) | 20 per run (24 s) |

Kaltenbrunn (`kaltenbrunn`, 1 run): wiped in round 5 after 5.3 min. 3 bot downs, revives 1 of 1, 90 s stuck,
6 blocking events, 46 empty-mag moments, 0 teleports. Paul is skipped (he doesn't exist yet).

### Per run (the soak's tables)

player3:

| run | end | round | min | bot kills | bot downs | downs/round | human downs | revive % | revived | ttr s | stuck s | teleports | lost s | block ev | sustained | spent | wasted | empty-mag | empty-mag s | pistol s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| s1 | wipe | 8 | 10.3 | 175 | 5 | 0.63 | 3 | 67% | 4 | 19.1 | 137 | 0 | 37 | 19 | 0 | 7100 | 0 | 119 | 156 | 845 |
| s2 | wipe | 9 | 13.3 | 166 | 6 | 0.67 | 3 | 100% | 5 | 16.2 | 142 | 0 | 66 | 34 | 0 | 8700 | 0 | 113 | 167 | 636 |
| s3 | wipe | 7 | 9.2 | 140 | 3 | 0.43 | 2 | 100% | 1 | 5.5 | 91 | 0 | 40 | 24 | 0 | 7350 | 0 | 79 | 111 | 570 |
| **mean** | | 8.0 | 10.9 | 160 | 4.7 | 0.58 | 2.7 | 83% (pooled) | 3.3 | 16.3 | 124 | 0 | 48 | 25.7 | 0 | 7717 | 0 | 104 | 145 | 683 |

bots3:

| run | end | round | min | bot kills | bot downs | revive % | stuck s | stuck recoveries | spent | wasted | empty-mag | empty-mag s | pistol s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| s11 | wipe | 6 | 7.6 | 133 | 3 | — | 114 | 0 | 6250 | 0 | 109 | 208 | 555 |
| s12 | wipe | 6 | 7.3 | 137 | 3 | — | 218 | 1 | 8550 | 0 | 108 | 172 | 801 |
| s13 | wipe | 5 | 6.5 | 101 | 3 | 0% | 88 | 0 | 5500 | 0 | 52 | 78 | 422 |
| **mean** | | 5.7 | 7.1 | 124 | 3 | 0% | 140 | 0.3 | 6767 | 0 | 90 | 152 | 592 |

cousins: three wipes in round 10 after 0.9, 0.7 and 0.6 min. The Hammer died once (in run 1); the others got no
cousin. 24 bot kills in all, 10 bot downs, 1 revive of 3, 52 s per run on the pistol.

### What the numbers say (the rewrite's to-do list)

- **The pistol trap.** This is the biggest single problem. When the Thompson's magazine runs dry with a zombie within 6 m, the
  bot swaps to its loaded pistol (`_weapon_logic`) and then **never swaps back** while the pistol has ammo. The
  pistol is refilled every round (`round_start_pistol_refill`), so it always has ammo. Bots spend **35% of all their time** in player3, and
  46% in bots3, on the M1911 while a Thompson with ammo sits in the other slot (`pistol s` above: 683 s per ~11 min
  run with 3 bots). That is very likely a big part of why the squad wipes at rounds 7–9.
- **Scrip hoarded.** In player3 the bots ended each run with ~22,000 Scrip unspent between them, about 7,500 each.
  Per run they spent 4,500 on doors, 2,400 on ammo boxes and 800 on wall ammo, and nothing else. Perks need the power, and bots never flip it. On Map 0 no wall gun outranks the kit's Thompson. So Scrip wasted is 0 only because
  nothing is bought.
- **Revives come late, and the bots give up mid-revive.** It takes 16 s from a down to getting up. Only 10 of 21 revive
  holds were finished (a bot drops the hold to fight whenever a zombie is within 3 m and more than 15 s are left).
  Alone, the bots never revive at all: they go down together.
- **Short stalls, not stuck recoveries.** About 2 minutes of every run is bots pushing against something for 0.5–1.5 s at a
  time. The 3 s give-up fired once in 6 Map 0 runs, and the teleport never fired. The brief's "cut teleports 90%" target
  starts from 0 here, so the stall time is the number to cut.
- **Blocking.** About 26 blocking half-seconds per run, but no episode over 2 s. The bots drift through the player's
  space rather than parking in it.
- **Empty mags.** About 100 empty-mag moments per run, roughly one every 6 s, with a zombie within 6 m. The bots reload with
  zombies close.

### Real time vs accelerated (the soak's time base)

The same seeds (201, 202) were played to round 5 three ways: real time (no `--fixed-fps`, 1×), accelerated
(`--fixed-fps 60`, unthrottled), and accelerated with `--speed=2` (Engine.time_scale 2):

| mode | wall time (2 runs) | game min | bot kills | bot downs | stuck s | blocking ev | empty-mag | lost s |
|---|---|---|---|---|---|---|---|---|
| real time | 377 + 425 s | 6.2 / 7.1 | 79 / 86 | 0 / 0 | 122 / 90 | 5 / 11 | 52 / 29 | 28 / 42 |
| accelerated | 67 + 59 s | 7.3 / 6.9 | 85 / 89 | 0 / 0 | 81 / 142 | 12 / 26 | 27 / 35 | 34 / 20 |
| accelerated, time_scale 2 | 58 + 58 s | 6.3 / 6.6 | 80 / 83 | 0 / 0 | 155 / 84 | 13 / 19 | 38 / 38 | 30 / 47 |

The three modes agree within the run-to-run spread. Accelerated is ~6× faster than real time. time_scale 2 buys nothing
(the physics step stays 1/60 s and the wall time per game minute doesn't change).

## 3. Measuring: the metrics logger and the soak test

### The soak test

```
tools/ai_soak.sh --scenario=player3 --runs=3     # = godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/ai_soak.tscn -- ...
tools/ai_soak.sh --scenario=bots3 --runs=3
tools/ai_soak.sh --scenario=cousins
tools/ai_soak.sh --scenario=kaltenbrunn          # rounds 1-20 on Map 1
   options: --runs=N  --seed=S (run k uses S+k-1)  --max-round=R (stop when round R+1 starts; 0 = to the wipe)
            --skill=green|regular|veteran  --max-minutes=150 (game-time cap)  --speed=N (Engine.time_scale)
```

The Update 03 brief names it `tools/ai_soak.gd`. In this repo the Godot tools live in `tools_src/` (next to
`playtest_gl`), and `tools/` holds the shell wrappers, so the tool is `tools_src/ai_soak.gd/.tscn` with a
`tools/ai_soak.sh` wrapper.

| Scenario | What runs |
|---|---|
| `player3` | Map 0, 3 bots + the **scripted player** (`tools_src/soak_dummy.gd`), from round 1 until the squad wipes. |
| `bots3` | Map 0, 3 bots alone. The game needs a local Player (the HUD, the camera and the round code expect one), so the human slot is benched: it bleeds out at the start (downed + spectating, no collision, no guns, so zombies and bots ignore it and the bots lead themselves) and is taken out of the co-op life cycle (it never respawns and doesn't count for the wipe). Round size still counts it as 1 player plus 2 for the bots, the same as player3. |
| `cousins` | `player3` forced to round 10 (the Cousins round, HB1, Homage Bosses on), the same way the dev launcher does it. Everyone gets 3000 Scrip. It runs until the round ends (cleared, or the cousins got bored and left) or the squad wipes. |
| `kaltenbrunn` | `player3` on Map 1, rounds 1–20. The brief also forces Paul at round 15. Paul doesn't exist yet, so that part is skipped. The scripted player runs a ring of navmesh points around the spawn there. |

- **The local-AI planner is off** in every run (`GameState.bot_ai_mode = "off"`), so no result depends on Ollama
  being installed or on a model's mood.
- **Accelerated.** Headless with `--fixed-fps 60` isn't tied to the clock. A run goes as fast as the CPU allows (6–7×
  real time on Map 0 with 3 bots on this machine, ~2.4 ms per physics tick) with the exact 1/60 s physics step of a
  real-time match, so every bot and game timer behaves the same. `--speed=N` (Engine.time_scale) gains nothing under
  `--fixed-fps`: the step stays ~1/60 s and a game minute costs the same wall time (measured below).
- **Seeds** seed the global RNG and the round manager. The bots roll their own RNG (`randomize()`), and physics isn't
  bit-for-bit repeatable, so compare means over several runs, not single runs.
- Output, in `logs/ai_runs/` (git-ignored; the folder gets a `.gdignore` so Godot never imports the CSVs):
  `<run>.csv` per run, `summary_<scenario>.csv` (one row per run, appended), and `<batch>.md` (the batch's table
  plus a mean row). Each run also prints a one-line `[ai_metrics] SUMMARY ...` to stdout.

### The scripted player (`tools_src/soak_dummy.gd`)

The real local Player (pid 1), driven through the same input actions a person presses, so the bots follow it, revive
it and get in its way like a human's. It's simpler than `playtest_gl` on purpose, because it's the bots' test load
and should behave the same for every brain:
- It runs a fixed **training loop** on the navmesh, in rounds and breaks alike. On Map 0 it goes clockwise round the
  taproom tables east of the bar: (10.5, 3) → (16.5, 2.4) → (22.2, 2.6) → (22.2, 9) → (19.4, 14.4) → (14.5, 14.2) →
  (10.2, 13.6) → (10.4, 6.5). Once the stable door (Door 2) is open (the bots buy doors), each lap also goes down the
  yard passage and round the east half of the stable and back: the taproom-to-stable loop. It turns back when two or
  more zombies sit on the next stretch within 7 m.
- It shoots the nearest zombie in sight within 14 m (0.25 s reaction, 6 rad/s turn, aim noise, heads), reloads when
  empty or when nothing is within 8 m, and knifes what reaches it with an empty gun.
- It buys nothing. It carries the bots' spawn kit (the Thompson, Ironhide Stout, Second Wind; restored after a
  revive or respawn like the bots' kit) and its reserve is topped up at each round start. Otherwise the run would
  measure the dummy running dry, not the bots. It doesn't revive anyone.
- It can be downed (then it shoots from the ground), revived and bleed out like anyone.

### The metrics (`gravelight/bots/bot_metrics.gd`, `BotMetrics`)

A plain node the soak adds next to the match. There is no autoload, and nothing in the game creates one. It watches
from outside (GLBus signals, the co-op state, the Players), so it measures any brain the same way. The rules are static
functions, unit-tested in `gravelight/tests/unit/test_bot_metrics.gd`. All numbers are for the bots unless the
column says "human".

| Metric | Definition |
|---|---|
| round reached | `RoundManager.current_round` when the run ended (the wipe's round). |
| kills / headshots | `enemy_killed` by each bot (limb `head`). |
| downs per round | `player_downed` of a bot, per round; the table shows bot downs ÷ rounds reached. |
| revive success rate | The share of downs (bots and the human) that ended in a revive. Failures are bleed-outs and downs still open when the match ended that were 10 s old or more. Younger open downs are the wipe itself (nobody was left standing) and don't count either way. |
| revive attempts / ok | An attempt starts when a reviver appears in the co-op state (`coop.reviver_of`); it is ok when that down ends in `player_revived`. |
| time to revive (ttr) | From the down to getting up, for the revived ones. |
| stuck events / stuck time | Reported by the brain through the hook (see below). Stuck time adds up the stretches of "wants to move, isn't moving" longer than 0.5 s (all of each such stretch). Stretches over 1.5 s are also logged with the position. |
| teleports | Reported by the brain through the hook, with the position. |
| lost time | Time a standing bot spent more than 14 m (flat) from a standing human, counted after the first 4 s of each spell. |
| blocking events | A bot inside a standing human's **1.2 m** personal space (flat, same floor) while that human moves faster than **1 m/s**: one event per full 0.5 s of an unbroken episode. A **sustained** event is an episode longer than 2 s, counted once per episode and logged with the position. |
| Scrip spent | `purchase_made` per category, from the item id: perk, wall gun (by gun id and round), wall-buy ammo, ammo box, door, crate, Crucible (upgrades and upgraded ammo), pylon, trap. |
| Scrip wasted | Wall-gun purchases only, the first matching rule: a **Kar98k after round 10**; a gun **worse than the best one carried** at the time (gun quality = its wall price; the start pistol 0; a crate-only gun 1500; an upgraded gun 5000); a gun **no longer carried within 2 rounds** of buying it (guns lost to a bleed-out don't count; that isn't a choice). |
| Kar98k after r10 | Its own count, because the brief's acceptance names it. |
| empty-mag moments | The gun in a standing bot's hands has an empty magazine while a zombie is within 6 m (flat, same floor). It counts the episodes (rising edges) and the time. |
| pistol time | A standing bot holding a pistol while it carries another gun that still has ammo. |
| command response | Hook pair for the command wheel (not in the game yet): the time from `command_issued` to `command_done`. |

**Hooks a brain must call** (each is a no-op when no logger is running). The current `BotBrain` calls the first three
in `_move` and `_teleport_to`, and the Update 03 brain must keep calling them:

```gdscript
BotMetrics.note(pid, &"stuck_time", delta)   # every frame it wants to move and isn't getting anywhere
BotMetrics.note(pid, &"stuck")               # a stuck recovery fired (repath / nudge / give up)
BotMetrics.note(pid, &"teleport")            # it was teleported
BotMetrics.command_issued(bot_pid, cmd)      # the command wheel gave an order
BotMetrics.command_done(bot_pid, cmd)        # the bot started acting on it
```

With the locomotion layer on (section 4), `BotLocomotion` makes the first three calls. A brain that moves through
it must not call them again.

## 4. Locomotion layer (Update 03 section 3, T-056)

The brain decides WHAT to do; `BotLocomotion` (`gravelight/bots/bot_locomotion.gd`, tuning in
`data/gravelight/ai/locomotion.json`) decides HOW the body gets there. It is on by default (`bots.json`
`"locomotion": "v2"`; `"v1"` = the old `BotBrain._move`; the soak's `--loco=v1|v2` overrides it for A/B runs).

### The same movement as the human

`Player` movement no longer reads `Input` directly. It reads a `MoveIntent` (`gravelight/player/move_intent.gd`:
the move stick in the body's frame, jump, sprint, crouch, and fire/ADS for the sprint cancel). The local human fills
it from the input actions each frame (`Player._read_move_intent`, the same reads as before, so `smoke_feel`,
`test_feel_u02`, the playtest bot and the soak dummy are unchanged). A bot's locomotion fills its own and calls
`Player.drive_bot(delta, intent)`. Bots therefore get the acceleration curves, sprint stamina, sprint only within
~70° of where the body faces, slide physics and the mantle/vault probe. They cannot sprint while strafing or
aiming. After a sprint, `fire_ready()` stays false for the gun's `movement.json sprint_out` time. The body turns at
`bots.json skills.<skill>.turn_rate` (× `sprint_turn_mult` at a run). Without a look it faces where it moves (no
moonwalking). With `look_at_dir` it faces the look and strafes. Bot footsteps stay with the RemoteBody (3D);
`Player._footstep` is skipped for non-local players.

### API (the brain codes against this)

```gdscript
loco.setup(player, squad)
# every physics frame: exactly one of
loco.move_to(pos, urgency := 0.5, stop_dist := 1.0)  # urgency 0 walk, >= 0.7 sprint (no look), 1 flee
loco.follow(leader, slot_index)                      # loose wedge (formation.still / formation.moving)
loco.hold(pos, facing)
loco.train(route)                                    # TrainingRoute or null (a ring round the leader)
loco.stop()
loco.look_at_dir(dir) / loco.clear_look()            # 3D aim direction (yaw + pitch), turn-rate limited
loco.tick(delta)
# queries
loco.arrived(), loco.is_stuck(), loco.path_length_to(pos), loco.current_target(), loco.debug_path()
loco.train_face_dir(), loco.train_ok(), loco.fire_ready(), loco.sprint_out_left(), loco.avg_tick_us()
loco.teleport_near(leader)                           # catch-up teleport, same unseen rule
# pure (GUT: test_bot_locomotion.gd)
BotLocomotion.personal_space_push(me, human, human_vel) -> Vector3
BotLocomotion.wedge_offset(slots, i, heading, mirrored) / should_yield(...) / stuck_stage(...)
BotLocomotion.path_crosses_door(...) / lift_ok(...)
TrainingRoute.for_map(map_key) -> Array[TrainingRoute]   # routes whose doors / zones are open now
```

Locomotion owns the facing and calls the BotMetrics hooks. The brain keeps `net_flags` and the RemoteBody pose.
Until the Update 03 brain lands, a thin adapter in `BotBrain` (`_loco_move`, marked "U03 section 3 locomotion
adapter") turns the old brain's `_goal`/`_sprint`/aim into these calls.

### What it does

- **Paths:** `NavigationServer3D.map_get_path` with the squad's nav mask, rejected when it crosses a shut `BuyDoor`
  (the same rule as `ZombieDirector.door_crossed`; Map 0's navmesh runs through doors). Danger is a post-path
  cost: the path is sampled every metre against zombies (falling off over 2.5 m), live traps (`danger_contains`), a
  Bell Dome's rim (group `bell_domes`), `fire_hazards` nodes, the blackboard's `danger_zones` (duck-typed) and an
  unsafe lift cage. When that cost passes `alt_threshold`, detours through points 2.5 m and 4.5 m to either side of
  the worst spot are planned and the cheapest wins. Godot 4.7 region travel costs can't express small moving
  dangers, so this approach was chosen and measured instead. Path queries are budgeted at `plans_per_frame` (2) for
  the whole squad. On an authored training loop the route's own validated samples are the path (no query).
- **Never block a human:** a 1.2 m bubble, stretched up to 1 m ahead of a moving human, pushes the bot out, mostly
  sideways off their line. A bot never steers into a human's bubble (that part of its wish is removed). A human whose
  straight line passes within 1.3 m in the next 1.2 s makes it step aside, and so does standing on the human's
  training line (their velocity 3 s ahead). A stopped bot leaves doorways and stairs (squad chokes) after 0.6 s.
  Bots keep 0.9 m from each other.
- **Formation:** `follow()` uses wedge slots `[angle from heading, radius]`. Standing: 135°/−135°/180° at
  2.8–3.8 m. While the leader moves: 80°/−80°/40° at 2.4–3.6 m, predicted 0.6 s ahead, beside and ahead and never
  behind (the horde's side). Slots snap to the navmesh and skip chokes, traps and danger zones (mirrored and
  shrunk fallbacks). A slot more than 3.5 m away is run to.
- **Training:** `train(route)` runs `lead_m` (3.5 m) ahead of its place on the loop. It sprints when the train's
  head is within 3 m, walks at mid range, and waits when the head falls back past 7.5 m (turning to it:
  `train_face_dir()`). Every 2 m it checks the next 6 m (zombies within 1.6 m of the line, a ray along it). If cut
  off, it reverses (at most every 1.5 s), or `train_ok()` goes false when both ways are blocked.
- **Stuck ladder:** no progress means the goal hasn't come 0.3 m closer and the body hasn't moved 0.6 m net in a
  1 s window, so a moving goal isn't "stuck". At 2 s it repaths; at 4 s it nudges (a 1.2 s walk to a random
  navmesh spot 1.5–3 m away); at 8 s it teleports past the obstacle (the goal, or the furthest path point 3–8 m on).
  The teleport happens only when no human sees the bot or the spot (a 65° view cone to 60 m plus line of sight, and
  never within 2 m of a human). Every teleport is logged. While watched it keeps nudging and retries every second.
- **Lift (Kaltenbrunn):** a cage is a danger cost unless every standing teammate is in it and no zombie is within
  10 m (`lift_ok`). Riding it (the button) is the brain's job.
- **Mantle / slide:** blocked for 0.35 s walking into something `Player.probe_mantle()` accepts → jump (the shared
  vault). Fleeing at a sprint (urgency ≥ 0.9) with a zombie within 4 m behind and 6 m of straight path → slide.

### Training routes

`TrainingRoute` (`gravelight/bots/training_route.gd`) is a closed loop. Its points are smoothed (Chaikin, with the
cut capped at 1.2 m from each corner) and resampled every 0.5 m. It has `closest_param`, `point_at`, `advance`,
`length`, `contains_ring`, `distance_along` and `tangent_at`. The brief asks for `TrainingRoute` resources; this
project keeps tuning in JSON, so routes are data in `data/gravelight/ai/routes_<map>.json`. Validate them with
`gravelight/tools_src/route_tool.tscn -- --map=map00 --validate`. The validator checks that every sample is on the
navmesh, that there is room on both sides (physics rays at knee and chest height), that the ring width holds along
85% of the loop, and that sample i to i+4 is walkable on the navmesh without a detour. `--dump=x0,z0,x1,z1,y`
prints the navmesh as ASCII for authoring.

| route | map | loop | needs |
|---|---|---|---|
| `map00_taproom` | 0 | 41 m round the taproom tables (the soak dummy's loop) | — |
| `map00_taproom_stable` | 0 | 80 m: the taproom loop, out through the kitchen door, round the stable's east half, back | door_stable |
| `map00_stable` | 0 | 21 m in the stable's east half | door_stable |
| `map00_cellar_barrels` | 0 | 27 m round the Old Cellar barrel stack | door_old_cellar |
| `map01_headframe` | 1 | 56 m round the headframe tower base, between the gatehouse and the coal shed | — |
| `map01_pews` | 1 | 128 m, the Salt Chapel's outer aisles round the four pew blocks | zone F_CHAPEL |
| `map01_turbines` | 1 | 48 m round turbine 1 (the T2–T3 gap is the Live Wire Fence's) | zone G_GENERATOR |

Map notes found on the way: the navmesh has no way round the north end of Map 0's hay stairs (the stalls and the
space under the landing), so the stable loop uses the east half. Map 1's navmesh has walkable islands inside the
headframe tower base and the gatehouse (closest-point queries can land there; paths go round correctly).

### The lab and the smoke

`gravelight/tools_src/loco_lab.tscn` (`-- --only=<phase>`, `--clip`) and `smoke_bot_loco.tscn` use the same
script. They run Map 0 with the bots' brains paused and drive the layer directly. Checks: the routes validate;
follow (close, out of the bubble, spread ≥ 25°, no chokes); following a training human (within 7 m ≥ 80% of the
time, no sustained blocking, no moonwalking); yield (a human walks through a holding bot's spot at full speed);
hold (spot and facing); mantle (a waist-high box the navmesh doesn't know); door (never through the shut stable
door); train (a lap ahead of 6 zombies, in the ring, the train tight, turning back when cut off); stuck (no teleport
while watched, nudges, a teleport once unseen); budget.

### Measured

METRICS_PLACEHOLDER
