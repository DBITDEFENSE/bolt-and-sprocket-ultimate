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
            --player-kit=baseline|realistic (T-058: the scripted player's kit, below; baseline is the default)
            --god (the scripted player can't be hurt)  --trace=N  --orders=N
            tuning only, not for the acceptance numbers: --homage=0 (no Cousins round)  --start-round=N
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
- **Kit "baseline"** (the default; every number in sections 2, 4 and 7 before T-058): it buys nothing. It carries
  the bots' spawn kit (the Thompson, Ironhide Stout, Second Wind; restored after a revive or respawn like the bots'
  kit) and its reserve is topped up at each round start. Otherwise the run would measure the dummy running dry, not
  the bots. It never throws the power, so the bots never get perks or the Crucible in this mode.
- **Kit "realistic"** (`--player-kit=realistic`, T-058): it plays the economy like a person who knows the map. The
  Thompson only (the gun a player buys early), no free perks. When it is calm (the break, or nothing within 10 m
  and three or fewer zombies left) and it has the Scrip, from round 2 it opens the closed door on its way to the
  power switch (Map 0: the cellar door, 1500), throws the switch (round 3-4 in every run so far), then drinks
  Ironhide Stout and Second Wind, and buys them again after losing them to a down. The round-start reserve top-up
  stays. Each errand prints a `[dummy]` line; the run's extras carry `dummy_power_round`, `dummy_perks_bought`.
- In both kits it doesn't revive anyone. A harness safeguard (T-058): pinned for 6 s it heads for another loop
  point, after 15 s it is put back on its loop (`[dummy] ... stuck`, `dummy_unstuck` in the extras).
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
| fair revive rate (T-058) | The same, but a down counts against the bots only when a bot could have come: `reach_s`, the seconds of that down during which a teammate **bot** was on its feet, is 10 s or more. A down that bled out or was still open at the wipe while every bot was down too (the scripted player alone on its feet, and it revives nobody) is **excused**. The old rate stays in the tables for the comparison with the baseline. |
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

A/B on the same tree (master 9f9e0eb plus this branch): `tools/ai_soak.sh --loco=v1|v2`, 3 runs each, regular skill,
local AI off. Two soaks shared the CPU. The section 2 baseline was measured on an older master (before the Update 02
section 5 bots, the Old Cellar and the Map 0 polish), so the same-tree v1 column is the fair comparison.

| Metric (per run, mean) | Baseline (section 2) | v1, same tree | **v2 (locomotion)** |
|---|---|---|---|
| player3 time stuck | 124 s | 10.0 s | **1.9 s** (after the revive fix: 2.7 s) |
| player3 stuck recoveries / teleports | 0 / 0 | 0 / 0 | 0.3 / **0** (1.3 / 0) |
| player3 friendly blocking events | 25.7 | 147.7 | **0** (1.0) |
| player3 sustained blocking (> 2 s) | 0 | 5.7 | **0** (0) |
| player3 highest round (mean) | 8.0 | 6.3 | 6.0 (6.7) |
| player3 bot downs per round | 0.58 | 0.48 | 0.51 (0.45) |
| bots3 time stuck | 140 s | 168.9 s | **0.8 s** |
| bots3 teleports | 0 | 0 | 0.3 (1 in 3 runs) |
| bots3 highest round (mean) | 5.7 | 6.7 | 7.0 |
| Kaltenbrunn (1 run): stuck / blocking / sustained | 90 s / 6 / — | 24.3 s / 74 / 1 (90 s) | **18.9 s / 2 / 0** |

An earlier pair on the pre-merge tree agreed: v1 19.6 s stuck, 269 blocking events, 13 sustained; v2 1.5 s, 0.7, 0.
Survival and revives are the brain's job and stay within the run-to-run spread. In the v2 reruns every down came in
the final collapse (all four within about 15 s), so the revive rate couldn't be judged. The v2 Kaltenbrunn run hit the
150-minute cap: the three bots bled out in round 8, and the scripted player then survived alone for 140 minutes
without the round ending. That is a soak-dummy stall, not the layer.

**Cost.** `BotLocomotion.tick` averages **95–117 µs per bot** in the soaks (`loco_us_tick_body` in the soak's
extra line), and about 50 µs of that is the body's own `move_and_slide`, which the old `_move` paid too. A training
bot in the lab averages about 215 µs (its cut-off checks run at 5 Hz). The layer's path queries are budgeted at 2
per physics frame for the whole squad. The soak's physics frame stayed at 3.1–3.9 ms with v2, against 3.2–3.4 ms
with v1 (CPU shared).

## 5. The Update 03 brain (T-055)

The T-031 mode machine is gone. A bot's brain is now an orchestrator of four layers, each in its own file under
`gravelight/bots/`, with every number in `data/gravelight/ai/*.json` (the brief says `.tres`; this project keeps its
tuning in JSON tables, T-055).

```
              squad blackboard (BotBlackboard, BotSquad.blackboard)
  known zombies (4 s memory) . claims . route + leader . danger_zones . power-ups . pings . roles
         ^ sightings, hearing                         | claims, roles, revive + cover assignment
         |                                            v
 BotPerception --> context (0..1 inputs) --> BotUtility --> action --> BotActions / BotTasks
 sight cone,       hp, ammo, pressure,       every action   ~5 Hz,      executors: where to go
 budgeted rays,    n5/n10, revive claim,     scores 0..1,   staggered   (locomotion), may it fire
 hearing, threat   round, tasks, orders      hysteresis                 (aim), errands
                                                                          |                |
                                                    BotAim <--------------+                +--> loco (BotLocomotion API)
                                                    target, reaction, convergence,              move_to / follow / hold / train,
                                                    fire discipline, reloads, weapon            look_at_dir, path_length_to, ...
                                                    choice, knife, grenades, the bell           (BotLocomotion, section 4)
```

| File | Job |
|---|---|
| `bot_brain.gd` (BotBrain) | The orchestrator. Each physics frame: the aim layer's timers; the think (every 1 / think_hz s, staggered across bots: perception, squad upkeep, the aim layer's think, the context, the utility pick); the action's executor; the locomotion tick; the pose. Owns the options (perks, kit, shopping, accuracy, personality, escort, armed, ammo payer, revive priority), orders, tasks, the bonus perk and the profiling counters. |
| `bot_perception.gd` (BotPerception) | Sight: a 110 degree cone from the eye, `rays_per_think` line-of-sight rays, nearest first. Hearing without sight: groans within 4.5 m, a sprinter within 13 m, board tearing within 16 m, a boss within 28 m. Whatever any bot perceives goes on the blackboard, and every bot knows it for 4 s at the last place it was perceived. Nothing else is known (no wallhacks). Threat per zombie = proximity x speed tier x type (ai_counters) x targeting me / a downed teammate x behind me x still outside a window. Pressure = the sum / pressure_norm. |
| `bot_utility.gd` (BotUtility) | Pure. Response curves (linear, poly, logistic, step, points) and considerations with the IAUS make-up for their count. Scores are x personality x role x the order's multiplier, + the order's boost. The pick adds hysteresis (+0.1) and the commit bonus (+0.3 while mid-task, +1.0 for tasks that must not be dropped: a gun in the Crucible, a paid crate), plus gaussian decision noise by skill. |
| `bot_actions.gd` (BotActions) | The executors: Fight, Train, Hold, Retreat, Reload safely, Revive, Cover, Power-up, Follow, Regroup, Escort, Chatter, Idle, and the task actions (Repair, Buy, Crate, Trap, Order, Objective). |
| `bot_tasks.gd` (BotTasks) | Errands: walk to it, hold use, use it. Covers shopping, the Crucible, the crate, an ordered door / power switch / part, and the local-AI planner's objectives (radio, switchboard, bells, the drummer, holds, pylons). |
| `bot_aim.gd` (BotAim) | Target choice: threat x counters x specials-first x vulnerable / grab priority x escort, with kill-steal etiquette. Then the reaction delay and a damped-spring convergence with the skill's overshoot, plus a tracking error that shrinks over track_tau_s. Headshot preference by class / skill / personality / counter / slow-or-close target. Fire discipline (bursts at range, semi caps, max range per class, line of fire), reload intelligence, weapon choice (the pistol-trap fix), the knife, grenades, the Totenglocke (taps, the Great Toll on 6+ bunched, the Bell Dome for revives and covers), the gramophone. |
| `bot_economy.gd` (BotEconomy) | Pure rules (the perk plan, a gun for the round, the reserve, the crate, doors, the never-touch rule) and the map candidates, each with a 0..1 value. |
| `bot_blackboard.gd` (BotBlackboard) | Pure shared data: memory, claims (exclusive, or capped for window pairs), danger zones (`{pos, radius, cost, until}`, the shape the locomotion layer reads), power-ups, pings, roles. |
| `bot_squad.gd` (BotSquad) | Revive claims (the nearest healthy bot with a safe path; the human first, then bots, then companions), cover claims, roles, danger zones (boss keep-away rings, fire, Bell Domes), the "sprinter behind you" / "window's open" callouts, callouts with pings, the nine orders, the dev console command. |
| `bot_locomotion.gd` (BotLocomotion) | How it moves: section 4. The brain calls move_to / follow / hold / train / stop and look_at_dir each frame. |
| `bot_move_adapter.gd` (BotMoveAdapter) | The "v1" fallback (bots.json `"locomotion": "v1"`, the soak's `--loco=v1`): the same API over the old movement code: paths that never cross closed doors, the moving formation, making way, chokes, the 1.2 m bubble. Stuck handling: 2 s repath, 4 s nudge, 8 s teleport, the last only when no human can see the bot. |
| `bot_pings.gd`, `bot_debug_overlay.gd` | The pooled world-space ping markers, and the `ai_debug` overlay. |
| `bot_ai_data.gd` (BotAIData) | Loads and caches `data/gravelight/ai/*.json`. |

### The actions and when they win

| Action | Wins when (the considerations) | What it does |
|---|---|---|
| Fight | a visible target; mid pressure | Shoots. Keeps up with a leader on the move, backs off what gets too close, spreads out around a boss. |
| Train | a loop, high pressure, many known zombies, later rounds | Follows the human's moving formation, or runs the route / free loop around the leader, firing at the head of the train. |
| Hold | a hold spot (the Hold order, or a window pair in rounds 1-7), low to mid pressure | Holds the spot and shoots from it; Repair takes over between kills. |
| Retreat | swarmed, hurt, dry | Kites to open ground away from the crowd and toward the squad. Sprints clear of something fast and close first, then shoots on the move. |
| Reload safely | mag under 30%, reserve left, calm, no sprinter close | Steps behind a teammate and reloads. |
| Revive | holds the revive claim, not blocked (blocked = a sprinter within 6 m with more than 10 s of bleed-out left), bleed-out urgency, path length, Second Wind | Goes. Plants a Bell Dome / throws the gramophone if it is hot, then holds use; stops only for something in knife reach while more than 8 s are left. |
| Cover | holds the cover claim, or its own revive is blocked | Stands beside the downed teammate on the threat's side and kills what comes near them first. |
| Repair / Buy / Crate | the economy's best candidate, calm | The errand (BotTasks). |
| Power-up | etiquette allows it | Walks over it. |
| Follow / Regroup | not leading / far from the squad | Takes its formation slot / goes back to the nearest teammate. |
| Escort | it escorts someone (Jakub) | Stays a step behind and to the side of them, never ahead, and shoots what goes for them. |
| Trap | ordered, or a trap the human already used, with a crowd at it | Pulls the lever. |
| Chatter | between waves, off cooldown | Says a line, turned to a teammate, with idle fidgets. |
| Objective | the local-AI planner has a directive | Runs the planner's errand. |
| Order | an order with its own task (open that door, fetch that part) | Runs the task. |

### Teamwork

- **Revives** are claimed on the blackboard (`revive:<pid>`): one bot per downed teammate, the nearest standing one
  by path. The Medic counts 6 m closer than it is. An unsafe path (a known zombie within 1.6 m of it) counts 15 m
  longer. When the threat at the downed spot is over `cover_threat`, a second bot claims `cover:<pid>`.
- **Roles** (every 2 s): the assignment of Medic / Anchor / Builder / Runner that best fits the standing bots'
  `role_bias` (Deacon the Medic, Dutch the Anchor, Peg the Runner, ...). Each role multiplies some action scores.
- **Callouts** (BotSquad.callout), each with a world-space ping: a sprinter behind a teammate, a boss incoming
  (Peg first), the crate moved, a window open, covering, every power-up by its own name, reloading, "I've got you",
  low / no ammo, orders acknowledged, Dutch grumbling when he is moved, Wren's kill tally, chatter. The lines are
  in VO_SCRIPT section 15, voiced with the offline TTS bake.
- **Power-up etiquette**: Resupply and Fortify whenever it is safe. Death's Door, Double Scrip, Blackout and
  Clearance only when the human is within 9 m of it too (or no human is playing). Never one the human is walking
  toward.

### Economy (data/gravelight/ai/economy.json)

Each bot spends its own Scrip, by priority:

1. Perks in plan order: Ironhide, Second Wind in co-op, then Trigger Tonic or Twin Barrel by the main gun's class,
   then the rest.
2. A wall gun, only when it beats the best gun carried, by tier and by wall price. So no Kar98k after round 10, and
   nothing is bought only to be dropped.
3. Ammo: an ammo box when the main gun is under 25%, or wall ammo from its own wall-buy under 35%. A nearly dry gun
   comes before anything else. Between waves, with Scrip to spare, it tops up under 60%.
4. Doors only when ordered, on the human's path after the human has opened one, or when no human leads. A squad
   leading itself opens only the doors it has a use for: the one on the way to the power (bots alone), then the
   doors an authored training route needs (T-058).
5. The Requisition Crate above 2,500 Scrip with a gun weak for the round, or above 6,000 without a wonder weapon.
   Never someone else's roll.
6. The Crucible for a gun of tier 3.4+ from round 5, mid-round too when it is calm (T-058; it was the break only,
   from round 8, and the Crucible never happened). Never a teammate's weapon.

It keeps a reserve: a Second Wind rebuy plus an ammo box, x the personality's save_bias. It never touches
easter-egg objects, traps or the power switch unless ordered or the human already did that step. The local-AI
planner bot is the user-sanctioned exception. **Bots alone** (no human in the match, T-058) are their own leader:
they open the way to the power switch and throw it (section 8).

### Orders (the command wheel, bots.json commands.orders)

Follow me, Hold here, Train with me, Repair windows, Revive priority, Buy perks now, Save Scrip, Go open that door
(the door or power switch the human looks at), Fetch that part (the buildable part the human looks at). Each one is
a boost / multiplier set in actions.json `orders` that lasts 60 s or until done. BotMetrics.command_issued fires at
the order, command_done when the bot first runs an action that answers it.

### Difficulty (Bot Skill: Recruit / Veteran / Elite, default Veteran)

Set in Settings -> Gameplay -> Bot Skill, or with the squad menu's button. `skills.json` is merged over
`bots.json skills`.

| | Recruit | Veteran | Elite |
|---|---|---|---|
| Reaction | 0.27-0.33 s | 0.19-0.25 s | 0.14-0.17 s |
| Initial aim error | 7 deg | 5 deg | 3.5 deg |
| Settled aim error | 1.6 deg | 1.0 deg | 0.6 deg |
| Overshoot | 0.35 | 0.25 | 0.15 |
| Decision noise | 0.07 | 0.03 | 0.01 |
| Spend smartness | 0.6 | 0.88 | 1.0 |

Old saved names map: green -> recruit, regular -> veteran. No skill changes damage taken.

### Cheats removed

- The free start-pistol refill at every round start.
- The hidden 10% damage reduction on the old "veteran" skill.
- Omniscient zombie awareness: every active zombie used to be known, through walls.
- The teleport to the leader after 8 s apart. Teleports now happen only after an 8 s stuck with no human looking,
  or after a fall out of the world.

Kept, as the user asked: the visible spawn kit (Thompson, Ironhide Stout, Second Wind) and the bonus perk.

### Jakub (U02 section 6.2) on this brain

```
BotSquad.add_brain(player, {"perks": false, "bonus_perk": false, "kit": false, "shopping": false,
    "accuracy_mult": 1.4, "personality": "jakub", "escort_pid": <the freer>, "armed": <has a gun>,
    "ammo_payer_pid": <the freer>, "ammo_price_mult": 0.5, "revive_priority": 2})
```

- `escort_pid`: the Escort action keeps him a step behind the player who freed him, and his targets favour what goes
  for that player.
- `armed = false`: a coal-shovel fighter (melee only, never a boss).
- His ammo boxes are paid from the payer's Scrip at half price (AmmoBox.use_holder).
- He is revived after the human and the bots, and he never leads the squad.
- His own bleed-out clock is `Player.bleedout_seconds` (60 s).
- personality_jakub.json: bolt-actions, ammo conservation, no shopping, escort first.
- Built in U02 §6.2 (T-051): `JakubCompanion` makes these calls (`JakubCompanion.brain_options`, from
  `companion_jakub.json "brain"`); the gun-in-hand rules, the wall-buy for him, the breakout and the carry are there.
  With no gun the body carries his coal shovel (`BotBrain` shows `melee_id` for a companion with empty hands).

## 6. Tuning guide

- **What a bot prefers**: `actions.json` weights and considerations. Each consideration is an input (listed in
  `_inputs`) through a curve, written inline or named from `curves.json`. A `step` curve with `lo` 0 is a gate; an
  order's boost never revives a gated action. Watch the effect live with `ai_debug 1` (the top three scores over
  each bot), or in a soak with `--trace=5`.
- **Flip-flopping**: raise `hysteresis` (0.1) or `min_action_s` (0.4 s).
- **A character's style**: `personality_<char>.json`: `actions` multipliers, `role_bias`, `aim.class_pref` /
  `head_bias` / `specials_first`, `combat.*`, `economy.save_bias`, `callouts.*`.
- **Roles**: the `actions.json roles` multipliers. **Orders**: `actions.json orders` (boost, mult, duration_s).
- **Perception, threat, aim, reloads, grenades, revive rules, power-up etiquette, early-round holds**: `combat.json`.
- **Spending**: `economy.json`. **Special enemies**: `ai_counters.json`; add a key for a new enemy id and the
  defaults fill the rest. **Difficulty**: `skills.json`.
- **Checking a change**: run `tools/ai_soak.sh --scenario=player3 --runs=3` (and bots3, cousins) and compare the
  `logs/ai_runs/<batch>.md` table with the one below. GUT `test_bot_brain.gd` pins the decision scenarios,
  `test_bot_tuning.gd` the T-058 rules.
- **Why did it die?** (T-058) Every down prints the bot's last ten thinks in the soak log (`[soak] DOWN before:`
  action, gun mag/reserve, health, nearest zombie, zombies within 5 m, shots so far, speed, stamina, `R` reloading,
  `S` sprinting). Shots that don't rise while a zombie is at 0.7 m, `v0.0` with `S`, `R` that never ends: each was a
  bug. The squad report adds each bot's hits / shots and what its misses hit first (`TapN_1`: the taproom's north
  wall beside a window). Use `--trace=N` for the action scores over time, and `--start-round=N` / `--homage=0` /
  `--character=<id>` (Peg among the bots) to get to a situation quickly (tuning only, not the acceptance numbers).
- **Fire discipline** (`combat.json aim`): `body_half_width_m` (point-blank tolerance), `sights_on_mult` (how far
  off the real target the sights may be when it fires), `spray_width_mult` (how wide a spread it accepts at range),
  `quick_switch_*`, `line_of_fire_radius_m`.
- **Moving under pressure** (`combat.json fight`, `retreat`): the backpedal radius by zombie speed, the boss
  margin, `stack_m` in special rounds, when retreat sprints and when a boxed-in bot turns to fight.
- **Revives** (`combat.json revive`): `self_swarm_*` (zombies on the reviver itself), `abort_*` (letting go
  mid-hold), `last_chance_s` overrides both.
- **Special enemies** (`ai_counters.json`): `hold_ground` (no backpedal / sprint-away: the Bellringers),
  `adds_first_m` (the runner at its heels before the boss), `keep_distance_m` (paths avoid it, on foot it is backed
  out of with `fight.boss_margin_m`).
- **Bots alone** (`economy.json power`, `self_led_mid_round_m`; `routes_<map>.json` `home`, `high_ground`): see
  section 8. The last-zombie hunt: `combat.json hunt`.

## 7. Results: before and after (Update 03 section 10)

The **After tuning** column (T-058, section 8) was measured on 2026-10-22 on u03-3-tuning merged with master
66e5494 (u02-fixes, Jakub), headless `tools/ai_soak.sh`, Veteran, local AI off, 6-9 soaks at a time on a CPU other
builders shared: player3 seeds 1-6 (baseline kit) and 1-3 (realistic kit), bots3 seeds 11-15, cousins seeds 1-3,
kaltenbrunn seed 1. The **After the rewrite** column:

Measured on 2026-10-22 on u03-1-brain (the brain, merged with the locomotion layer, master ed13950). Settings:
headless `tools/ai_soak.sh`, Veteran, local AI off. Several other builders' Godot runs shared the CPU. The baseline
is section 2 (the T-031 brain on an older master). player3 is 9 runs in three batches of 3 (seeds 1-3, 1-3, 21-23);
the last two batches ran the final code, the first one the code before the aim presets were sharpened. bots3 is the
final batch of 3 (seeds 11-13). cousins is 3 runs. kaltenbrunn is 1 run (40-minute cap). The orders figure comes
from one player3 run with `--orders=30`.

| Metric | Baseline | After the rewrite (T-055) | **After tuning (T-058)** |
|---|---|---|---|
| player3 highest round (mean / max), baseline player kit | 8.0 / 9 | 8.1 / 9 (9 runs) | **9.3 / 10** (6 runs: 9, 9, 10, 8, 10, 10; the batch before the Jakub merge: 9.7 / 10) |
| player3 highest round, **realistic** player kit (it throws the power) | — | — | **12.7 / 18** (3 runs: 18, 10, 10; the player throws the power in rounds 3-5) |
| bots3 highest round (mean / max) | 5.7 / 6 | 7.0 / 10 | **10.0 / 13** (5 runs: 7, 10, 10, 10, 13; with the batch before the Jakub merge, 10 runs: 10.6 / 16) |
| bots3 with the Homage Bosses off (tuning only) | — | — | 19, 17, 12 (3 runs): the Cousins at round 10 are the wall |
| Kaltenbrunn round (1 run, 40-min cap) | 5 | 7 | **9** |
| player3 bot downs per round | 0.58 | 0.67 | **0.41** (baseline kit), 0.45 (realistic) |
| player3 revive success, old rule (pooled) | 83% (10 of 12) | 78% (31 of 40) | **74%** baseline kit (25 of 34, 12 runs); **96%** realistic kit (51 of 53) |
| player3 revive success, fair rule (T-058) | — | — | **78%** baseline kit (25 of 32); **96%** realistic |
| bots3 revive success (pooled) | 0% (never) | 91% (10 of 11) | 71% (10 of 14) |
| player3 time stuck (per run / per game minute) | 124 s / 11.3 | 3.6 s / 0.4 | **2.4 s / 0.2** baseline kit; 51 s / 1.0 realistic (bots meeting in the cellar's Crucible alcove and at the perk machines) |
| bots3 time stuck (per run) | 140 s | 10.6 s | **8.1 s** |
| Teleports | 0 | 0 | **0** in every run |
| player3 friendly blocking events / sustained | 25.7 / 0 | 1.7 / 0 | **0.5 / 0** (realistic 1.7 / 0) |
| Scrip wasted | 0 | 0 | 0 in player3; bots3: 1,900 in one run of 5 (a G43 and an MP40 dropped a round later for crate guns) |
| Kar98k bought after round 10 | 0 | 0 | **0** |
| player3 empty-mag moments (per game minute) | 9.5 | 7.4 | **2.9** (realistic 1.7) |
| bots3 empty-mag moments (per game minute) | 12.6 | 4.4 | **2.7** |
| Time on the pistol with a loaded gun (player3, per run) | 683 s | 68 s | **0-1 s** |
| Bot kills per game minute (player3) | 14.7 | 21 | **26.0** |
| Bot headshot share of kills (player3) | — | 58% | 62% |
| Bot shots that hit a zombie (new: the soak's shot audit) | — | ~25-35% (measured on the T-055 tree, rounds 1-2) | **56%** (Map 1: 10% -> 52%) |
| The power on (bots alone) | never | never | **rounds 2-3**, every bots3 run (the bots throw it) |
| Crucible upgrades per bots3 run | 0 | 0 | **3.2** |
| cousins: time to the wipe (scripted player, no god mode) | 36-54 s | 30-37 s | 32-34 s (3 runs; the batch before: 29-51 s, one cousin killed) |
| bots3 at the Cousins round (round 10) | — | always wiped | **cleared in 2 of 10 runs** (55 and 59 s, all three cousins dead); with the realistic player 2 of 3 |
| Brain cost per bot per physics frame | — | 0.22-0.27 ms (headless) | **0.224 ms** alone (player3 to round 8); 0.29-0.37 ms with 6-9 soaks sharing the CPU |

One realistic run (seed 2) first stalled at round 16 for 150 game minutes: the last zombie of the round sat at
the cellar stairs, a bot 4.6 m from it with no line of sight (the hunt stopped at 5 m), and the scripted player was
pinned against a perk machine. Both were fixed (the hunt walks until it sees the zombie; the scripted player gets
back on its loop after 15 s pinned, `dummy_unstuck` in the extras) and the seed was run again (round 10, in the
table).

**After tuning (T-058): where the targets stand.**
- **Survival, bots alone (target round 20-25):** not met. 10.0 / 13 (10.6 / 16 over ten runs). The bots now take
  the power in round 2-3, drink, upgrade the Thompson and pull the crate, and they get through the rounds before 10
  with few downs (0.4-0.5 per round). The wall is **round 10, the Cousins** (Homage Bosses are on in every soak):
  three bosses with 12,500-18,750 health at this squad size plus 30 runners. The squad clears them in 2 runs of 10
  (55-59 s); the rest wipe there. With the Homage Bosses off the same squad reaches 19, 17 and 12. Raising this
  further is a balance question as much as a bot one (the Cousins' health scaling counts a bot as 0.75 of a player;
  a bot can't be ordered to skip the round).
  **T-060 (user call: the Cousins scale):** while no human is standing, the Cousins take 50 % health, 60 % damage,
  1.3x cooldowns, 0.9x speed and a 60 % horde (`cousins.json "bots_alone"`). bots3, 6 runs (seeds 11-16): the
  Cousins cleared 5 of 5 times reached; highest rounds 7, 11, 14, 16, 20, 20 (**mean 14.7, best 20**). The same
  soaks found a stall (a bot rebuilding the window the round's last zombie was tearing at, two hours on round 2):
  bots no longer board windows during the last-zombie hunt unless ordered.
- **Revive success above 85% (player3):** met with the realistic player (96%, 51 of 53). With the baseline player
  74% (old rule) / 78% (fair rule). The remaining failures are downs still open at the wipe while a bot was still on
  its feet: the squad losing the last fight, not a bot walking past a teammate (no bleed-outs in 12 runs).
- **Cousins scenario (round 10 forced, 3,000 Scrip, no power, no upgrades, scripted player without god mode):**
  still a wipe in 30-50 s, as in every baseline run. The same bots clear the Cousins when they arrive with the power,
  perks and an upgraded gun (bots3 and realistic player3 above).
- Everything else holds or improved: zero teleports, zero sustained blocking, no Kar98k, stuck time down 98%,
  empty-mag moments down 70%, kills per minute +77% over the baseline, the pistol trap gone, 56% of shots hit.

**What didn't reach its target (T-055, before the tuning pass).**
- **Survival.** The brief's target is round 20-25 on Veteran with bots alone; they reach 5-10. The early rounds
  are clearly better: bots3 survives about a round and a half longer on average, with a best of 10. But every run
  still collapses in rounds 7-10. Each collapse is the same. At round 8 a zombie has 850 HP, about 16 Thompson body
  hits, and the squad has no perks beyond the kit: perks and the Crucible need the power, and bots never throw the
  power switch. So 6-8 runners and joggers arriving together put the squad down within 10-20 s. The brain now trains,
  aims down the sights, prefers heads (x4), resupplies under fire and reloads sensibly; what's left is damage
  output. The levers are a human (or the local-AI planner bot) turning the power on, wonder weapons from the crate,
  and Veteran's aim numbers in `skills.json`. Tuning those is a design call for the user.
- **Revive success above 85% (player3).** Most failures are downs still open in the final collapse. The metric
  counts a down that is 10 s or more old at the wipe as a failure. Outside the collapse, revives almost always
  succeed: 17 of 18 in one batch, 10 of 11 in bots3.
- **The Cousins scenario** (round 10 forced, scripted player without god mode) still wipes; it did every baseline
  run too. With the player kept alive, the bots focus the cousins correctly and the round clears.

**Performance.** Rendered (1280x720, RTX 5090, vsync on, other builders' Godot runs sharing the CPU), Map 0 round 15
with 3 bots and the horde topped up to 24 alive (`clip_bots.tscn -- --shot=perf`): **63 fps average** (15.9 ms),
1% low 34 fps. The brain (perception, utility, aim, executors, locomotion) costs **0.35 ms per bot per frame**, inside
the 0.5 ms budget. The headless soaks measure 0.22-0.27 ms per bot per frame and 0.5-0.9 ms per think (one think
per bot every 0.2 s). BotLocomotion.tick is about 100 µs of that.

**Clips.** `morning/clips/u03/bots_train_r15.mp4`: round 15, the squad training with the scripted player in the
taproom; a bot downed under pressure and revived, callouts ("Sprinter, behind you!", the window, a Resupply with its
ping). `morning/clips/u03/bots_cousins.mp4`: the Cousins round. The rendered clip runs showed the Hammer killed,
6 hits while the mallet was in the air, three Reach grabs broken by the bots' fire, and nobody within 2.3 m of Alix.

## 8. The tuning pass (T-058)

The brain of section 5 was right in shape but lost its squads to a handful of concrete faults. The soak's down log
now prints the last ten thinks of every bot that goes down (action, gun, mag/reserve, health, nearest zombie,
zombies within 5 m, shots fired, speed, stamina, reloading, sprinting: `[soak] DOWN before: ...`), and every fix
below came from reading those lines.

### What was wrong, and the fix

| Fault (from the down logs) | Fix | Where |
|---|---|---|
| A bot with an empty magazine and a zombie in knife reach knifed it (150 damage against 650+ health), which cancelled the reload, which restarted on the next think: it never reloaded and died with a full reserve. | Dry, it only knifes what one swing kills (or a crawler); otherwise it finishes the reload while the executor backs it off. The revive's "deal with what's in knife reach" uses the same rule. | `BotAim._try_melee_target`, `knife_kills`, `BotActions._revive` |
| The fire tolerance (1.8 degrees on Veteran) held at any range: with a zombie at 0.7 m its aim point swings across 20+ degrees, so a bot with a full magazine didn't fire while it was torn apart. | The tolerance never goes below the angle the target's half width covers at its range (`aim.body_half_width_m`). Point-blank, anything on the body is a hit. | `BotAim._fire_if_on` |
| Retreat sprinted (no shooting) from anything at 3 m/s or faster: joggers too, which a walking bot out-walks while shooting. Boxed in, it kept "sprinting" at 0 m/s. | It sprints only from runners and sprinters (`retreat.sprint_from_speed` 4.2); still in reach or not moving after 0.8 s of that, it turns and fights for 1.5 s. Never from a Bellringer. | `BotActions._retreat`, `combat.json retreat` |
| Train skipped aiming while the locomotion layer wanted a sprint, even out of stamina and stuck against the train's head. | It only skips aiming while it really runs (sprinting above 2.5 m/s, or the head beyond 2.2 m). | `BotActions._train` |
| From round 5 the start pistol (8 x 40 damage) was still "a loaded gun to swap to" with the main gun dry, so the bot swapped instead of reloading. | After `weapons.weak_pistol_after_round` (4) a plain pistol is worth 0.1x and doesn't count as a loaded gun; an upgraded one still does. | `BotAim.weapon_value`, `_other_loaded` |
| Cover and Revive re-weighted the targets every think; every target change re-rolled the full reaction delay, so no shot came out. | A new target within 20 degrees of the aim is a flick (0.06 s). | `BotAim._acquire`, `aim.quick_switch_*` |
| A reviver walked into the swarm round the downed teammate; once there, it held use through 4-5 hits; Revive and Cover flipped every think and restarted the hold each time. | Two zombies within 2.2 m of the reviver itself block the revive (latched 1.2 s) while more than 14 s of bleed-out are left; mid-hold under 40% health with something within 2 m it lets go and fights for 1.2 s; the last-chance rule (under 8 s) still overrides both. | `BotBrain.context`, `BotActions._revive`, `combat.json revive` |
| Backpedal started at 2.6 m whatever the zombie: a runner closes that in half a second. The straight-back spot snapped into the wall behind a cornered bot. | Backpedal radius = 1.7 m + speed x 0.55 s (2.6-4.4 m), plus a boss's keep-away ring + 0.8 m (Alix's 2 m Holding Hand); the spot is the clearest of seven angles off the straight line (re-planned 4x a second). | `BotActions.backpedal_radius`, `_back_off`, `combat.json fight` |
| Rounds 5-7 collapsed in most runs: that is the first **special round** (Bellringers: 5.4 m/s with a 2 m lunge, out of portals). The bots backpedalled, trained and sprinted off alone and were run down one by one. | In a special round (and against any `hold_ground` enemy) no window holds, no training (x0.15), less retreat, no backpedal, no sprint-away; a bot more than 3 m from its nearest teammate closes up (back to back). | `BotBrain.stand_fast`, `actions.json stand_fast`, `ai_counters bellringer.hold_ground` |
| Window holds stood 2.2 m inside the sill: what climbed in was already in reach. | `hold.stand_back_m` 3.6. | `BotBrain.hold_spot` |
| The Crucible never happened (break only, from round 8; its errand lost to repairs and power-ups). | From round 5, mid-round when calm; priority 1.0 (the buy weight 0.8). | `bots.json shopping.crucible`, `economy.json` |
| The crate rarely won a think (weight 0.5). | Weight 0.75, priority 0.8, two pulls a round, "rich" from 5,000. | `actions.json`, `economy.json crate` |
| Twin Barrel for the Thompson: more rate on a 30-round magazine only empties it sooner (2.6 s of fire, 2.9 s of reload). | Magazine-bound automatics take Trigger Tonic (half reload), semi rifles and bolt guns Twin Barrel. | `economy.json weapon_perk` |
| Bosses: the bots shot a 15,000-health cousin while the runner at their heels ate them. | `adds_first_m`: with an ordinary zombie within 5 m, a cousin's target value is x0.35, unless she is vulnerable (mallet out, Alix grieving) or holds a teammate. | `BotAim.target_value`, `ai_counters cousin_*` |
| A round held up by its last zombie (a boss loose in another hall, a stuck straggler): the bots never went looking (the smoke_map02 Foreman stall after the brain merge). | After 12 s with nothing left to spawn and 1-2 zombies alive, the squad hears the last one (blackboard, no line of sight: nothing is shot through walls) and the bots with nothing else to do walk to it until it is in sight. | `BotSquad._update_hunt`, `combat.json hunt` |
| Shots held back by a 0.6 m line-of-fire radius round teammates standing back to back. | 0.45 m (a body). | `combat.json aim.line_of_fire_radius_m` |

### Bots alone lead themselves

With **no human in the match** (`BotSquad.bots_alone()`: no local player, or one sitting the match out of the
co-op life-cycle like the bots3 soak's benched player) the squad is its own leader: the never-touch rule protects
a human's choices, and there is no human to take the step from.

- **The power.** From round 2 (`economy.json power.min_round`) a bot buys the closed door on the way to the power
  switch (the navmesh runs through doors: the nearest closed door the path to the switch crosses whose near side it
  can reach; Map 0: the cellar door) keeping only 300 Scrip back, then throws the switch. Until that door is bought,
  any other door must leave its price in hand. In the soaks the power came on in round 2 or 3 every time.
- **Useful doors only** (`power.self_led_useful_doors_only`; also while a human has only bled out for the round):
  the power's door, then the doors an authored training route needs (`routes_<map>.json requires_doors`). No more
  attic doors that took the squad upstairs to die.
- **A home.** Routes may carry `home` (Map 0: the taproom loop). The squad holds the windows round its home (early
  rounds), trains on it when the leader isn't by another loop, and the leader walks back to it when it has nothing
  else to do.
- **Far errands between waves.** Mid-round it only shops within 16 m of home (`self_led_mid_round_m`); the cellar's
  perks, the Crucible and the switch wait for the break (bots used to die alone in the cellar while the coal chute
  spawned on them).
- Then the usual plan: Ironhide and Second Wind come with the kit; Trigger Tonic, then Hawkeye Brandy and on down the plan (the cap is 6 since T-081);
  the crate when rich; the Crucible for the Thompson from round 5.
- Easter-egg objects, buildable parts and traps stay off limits even then.

**With a human in the match** nothing changed: the power only on an order, and once the human threw it (the
power is on) the bots drink in plan order (GUT `test_bot_tuning.gd`). A human who bled out for the round is still
in the match: the bots don't throw the power behind their back.

### Personality movement

- **Peg flanks** (`personality.combat.flank`): on a boss or a special (counter priority 1.3+) she doesn't stand
  behind the squad's guns but moves to its flank: her `keep_distance_m` (7) from it, 70 degrees round from the
  line between it and the squad, on her side, on a reachable navmesh spot with a line of sight and no danger zone,
  re-planned every 1.5 s (`BotActions._flank`, the pure `flank_point`). Peg is the player character in every soak
  (`GameState.character_id`), so the soaks never show her flanking; a Peg bot does it in a match where the human
  plays someone else.
- **Wren takes high ground** (`personality.combat.high_ground`): with the fight within a map high-ground spot's
  `watch_m` and the squad within 14 m of it, she fights from up there (`routes_<map>.json high_ground`; Map 0: the
  stable's hayloft edge, two spots, needs the stable door). Never with a boss within 20 m of the spot (the Reach
  drops into that hayloft). Checked every 2 s (`BotActions._high_ground`).
- The soak's squad report counts both (`flanks`, `high ground`), and the bonus and bought perks at the end.


## 9. Bots on the easter egg (Update 04 section 5, T-067)

UPDATE_03's "never touch easter-egg objects" became a setting, "Bot Easter-Egg Help" (Off / When Asked, the default /
Full Partner). The local-AI planner's egg step list (BotPlanner._egg_options, which only the planner bot used) moved
into the quest data as a `bot_task` per step and into four files every bot uses:

| File | Job |
|---|---|
| `bot_ee_catalog.gd` (BotEECatalog) | Pure rules: the mode, the gate (mode, step state, player-only, Jakub's limits, the discovered-info gate, risky stages, final steps need the player), the never-sequence-break guard (`safe_input`, `commit_blocked`), the pause rule (threat with hysteresis, a teammate down, the round ending), node specs. |
| `bot_ee_knowledge.gd` (BotEEKnowledge) | What the squad has discovered (on the blackboard as `ee_known`). |
| `bot_ee.gd` (BotEE) | One bot's task: a pure planner per task type (`plan_collect`, `plan_inputs`, `plan_shoot`, `plan_hold`, `plan_carry`, `plan_kill`, `plan_escort`, `plan_turn_key`) over a world snapshot, and the executor that carries the move out through BotTasks errands, BotAim and the locomotion layer. Opens the first closed door on the way with its own Scrip. |
| `bot_ee_hub.gd` (BotEEHub, `squad.ee`) | The setting, the public API (`BotSquad.ee_assign / ee_can_assign / ee_task_of / ee_cancel / ee_assign_node`), Full Partner's picks, the discovery feeds and sight sweep, the failed-egg counter, the console. |

The brain gets one utility action, **ee_task** (actions.json: weight 0.88, the `order` curve on the task's value,
falling with pressure). Its input is `BotEE.value()`: 0 with no task, while paused or while waiting, else 0.8 (0.95
holding a zone, 0.9 killing with a weapon, 0.75 covering the player). So a calm bot works the task, a fight or a revive
wins, and the task resumes. Holding a zone never pauses for threat (it fights in place, and anything at arm's length is
fought the normal way). A quest shootable only reacts to a bot's bullet when that bot's task aimed at exactly it this
frame (`BotEE.shot_allowed`, `BotBrain.may_touch_quest(shootable)`).

Measured (`tools/ai_soak.sh --scenario=ee_full --runs=3 --seed=1`: Map 0, 3 bots + the scripted player, Full Partner;
the run ends when the egg is complete):

| run (seed) | notes taken by bots | radio locks by bots | handed to the player at | egg complete | egg-failure events |
|---|---|---|---|---|---|
| 1 (1) | 3/3 | 2/3 | 83 s (round 2) | yes, 1.4 game min | 0 |
| 2 (2) | 3/3 | 2/3 | 143 s (round 2) | yes, 2.4 game min | 0 |
| 3 (3) | 3/3 | 2/3 | 78 s (round 2) | yes, 1.3 game min | 0 |

Every step a bot can do on Map 0 was done by the bots (opening the upstairs and stable doors with their own Scrip on the
way); the last frequency is the player's commit, which the harness locks. Zero quest_step_failed events in all runs.
Brain cost with the egg work: 0.23-0.26 ms per bot per frame (the 0.5 ms budget holds).


## 10. Player bot mode (T-071)

The local human's own survivor played by the bots' brain while they watch (`gravelight/bots/player_bot.gd`,
`PlayerBot`, one per match, a MapRoot child). Player-facing notes: `docs/gravelight/BOTS.md` "Player bot mode".

### How it is wired

| Piece | Job |
|---|---|
| `PlayerBot` | The toggle: the `bot_mode` action (F6), the pause menu's Settings page, the console (`botmode on\|off\|toggle\|status`), `--botmode` / `PlayerBot.pending_on` (the launcher scene `gravelight/tools_src/play_botmode.tscn`). The hand-back poll (pure: `PlayerBot.takeover`): any of `player_bot.json takeover.actions`, the move stick, a mouse move over `mouse_px` or the right stick; keys held at the switch-on count only once let go; `grace_s` after a switch-on. `PlayerBot.can_enable`: solo, or the online host (a client's shots, buys and revives would need relaying). The HUD tag (its own CanvasLayer). |
| `Player.bot_driven` | The local Player reads no input (movement, look, the interaction ray, the WeaponHolder's tick); `drive_bot` accepts it; `bot_view_tick` (called by the brain at the end of its frame) turns the head the brain left into the view pitch, runs the camera update and the WeaponHolder's `bot_view_tick` (the gun in hand, raise, sprint pose, the reload animation and cues; never ammo). `BotAim.fire` calls `WeaponHolder.bot_shot_fx` for the local player: viewmodel kick, flash, 2D sound, hitmarker, a visual-only camera punch, and `Net.session.local_fired` (co-op relay). |
| `BotSquad.add_player_brain` / `player_bot` | A BotBrain with `is_player_bot`, **not** in `brains` (no plate, wheel orders, roles, kit, bonus perk, callouts). It may claim revives (`reviver_brains()`), it is `_brain_of(1)`, round starts reach it. `human_is_agent()`: `bot_led()` and `bots_alone()` are true while it plays, so the T-058 self-led rules (power, useful doors, home loop) apply to the squad and to it. In solo without bots PlayerBot makes a squad (no co-op session: the solo rules stay). |
| Brain options (`player_bot.json brain`) | No kit, no bonus perk, shopping and perks on, `skill` its own preset (Elite; the bots keep the Bot Skill setting), personality `player_agent` (lead_train is its fight, no follow / hold / chatter, no bolt-actions, Second Wind first: the human's solo self-revive; `economy.priority_mult` a real gun before the power's door). Before the power is on its Scrip reserve is only `reserve.min_scrip` (no perk to rebuy yet). |
| `BotLocomotion` | `steer_path(points, urgency)` (an explicit polyline: the trainer's), `skill_override`, `smooth_turn` (player_bot.json `turn`: angular speed = error x gain, capped, accel-limited: the first-person view eases into every turn). |
| `BotPlanner` | On the agent's brain (`player_bot.json planner`): the local LLM when the Bot Local AI setting is on and Ollama answers, else the scripted pick (`PLAYER_BOT_PROMPT`; it offers no door of its own: the economy's power / loop doors are the agent's). |
| `BotTrainer` (`lead_train`) | Section below. |

### Training (`gravelight/bots/bot_trainer.gd`, player_bot.json `trainer`)

- **Value** (the utility input `trainer`): 0 outside a round, with no loop, in special rounds (`special_round:
  "fight"`: the Bellringers are fought where it stands, the T-058 stand-fast rule), or with fewer than `train_min`
  (4) zombies chasing within `horde_m` (a handful is shot by the plain Fight action: measured better than kiting
  them); 1 otherwise (it keeps on while `train_keep` still follow); `low_ammo_value` when nearly dry (resupply first).
- **The loop:** `choose_loop` over `TrainingRoute.for_map(map, true)` (width, length, travel, windows on its line, home,
  `agent_bonus`, stickiness). New on Map 0: `map00_yard_well` (46.6 m round the yard's well, ring 4.5 m, validated;
  `agent_only`, so the bots' route pick and door rules are unchanged); the lollipop and the 21 m stable ring carry a
  negative `agent_bonus`.
- **The picture** (10 Hz): every known zombie (perception: no wallhacks) on the loop; unseen ones dead-reckoned toward
  the agent at their speed (`dead_reckon`); at-window ones (outside, tearing) are not on the loop but mark the window
  ahead. Classes (`classify`): behind (the train), ahead (a cutter; also one close in front off the line), close, off.
  The train's compactness (`train_stats`): followers, spread round their centroid, bunched share within `bunch_m`.
- **Phases:** TRAVEL (back to the loop at the clearest entry; away from anything in reach first), RUN (facing the way:
  walk, sprint inside the gap, reload on the walk, shoot what is in front), FACE (turned on the train: fire, stand for
  the aim while it is far, back round the loop when it closes; `safe_to_turn`: the head beyond the gap, the stretch
  ahead and its windows clear), CUT (a cutter with the train well back: shoot it). The gap (`gap_for`): the head's
  reach (`ai_counters reach_m`: 1.5, a Bellringer 3.4) + a margin + its speed x 0.38 s.
- **The kite** (`kite_score`, every 0.1 s, 16 directions): along the loop, clear of where every known zombie will be in
  0.7 s (reach + margin, squared) and of a straight line that brushes one, away from walls (a ray each); a loop whose
  best way stays against travel for 0.5 s is reversed. Cutters are swerved round on the open side.
- **Shopping on the way:** the economy's gun / ammo / perk within 4 m of it while the train is well back
  (BotTasks._shop), then back to the loop.
- The last zombies of a round are killed (the code has no keep-a-crawler pattern); a stalled round sends it to the
  squad's hunt point.

### Measuring

`tools/ai_soak.sh --scenario=botmode [--bots=N] [--map=map01]` (the agent replaces the scripted player). Extras
`pb_*`: training time and share, the train's mean / max length, 4+ share, spread, bunched share, cut-ins, hits (all /
while training), hits per training minute, stuck time, kills, reversals, phases, shops, its perks and guns, downs and
hits per round; `--trace=N` adds a line per N s and every hit with the zombies within 9 m. Tuning only:
`--player-kit=bots` (the bots' free kit for the agent), `--no-trainer` (the plain brain, no BotTrainer).

### Results (2026-10-24, headless, `--scenario=botmode`, Elite agent, scripted planner, Homage Bosses on)

| Batch | Highest round (runs) | mean | agent downs / round | hits per run | stuck | notes |
|---|---|---|---|---|---|---|
| Map 0 solo, seeds 1-8 | 7, 6, 6, 7, 6, 7, 4, 7 | **6.25** | 0.33-0.57 | 4-19 | 0 s | starts with the M1911; power on in round 2-3 (it buys the cellar door), Second Wind self-revives |
| Map 0 + 3 bots, seeds 11-14 | 10, 10, 10, 10 | **10.0** | 0.1-0.4 | 6-18 | 0 s | every run ends at the Cousins (round 10): the agent counts as a human standing, so the T-060 "bots alone" Cousins scaling doesn't apply |
| Kaltenbrunn solo, seeds 1-3 | 9, 8, 8 | **8.3** | 0.11-0.13 | 4-10 | 0 s | the power never came on |
| Kaltenbrunn + 3 bots, seeds 1-3 | 10, 9, 10 | **9.7** | 0.1-0.2 | 6-8 | 0 s | |
| (tuning) Map 0 solo with the bots' free kit, `--player-kit=bots` | 9, 8, 6, 7 | 7.5 | | 12-38 | | |
| (tuning) the same, `--no-trainer` (the plain brain) | 8, 11, 10, 8 | 9.25 | | 26-47 | | the plain Fight action kills faster than kiting a small train |

How it got there (each iteration 4-6 seeds, Map 0 solo unless said): v1 (follow the loop, turn at a gap) 4-5; cutters
(window spill, an open ring the zombies cut across), passes into the NE corner and the Bellringers were the deaths;
v2 the gap by reach (`reach_m`), window-state zombies off the loop, cut decisions with commitment, an opportunistic
shop, a gun before the power: 4-6; v3 the kite steering (16 scored directions) 4-7; v4 training only a horde of 4+,
the plain fight for the rest and in special rounds, no errand commitment with a zombie in reach, the idle back-off
and travel safety: 6.25 (no round-1 or round-2 deaths left).

**Where it stands against the brief's targets:** not met. Solo Map 0 averages 6.25 rounds (the bots3 reference is
14.7, but those three bots start with a free Thompson, Ironhide and Second Wind and share the downs); Kaltenbrunn
reaches 8-10, not 15. Training is measured but is not yet the strength it should be: on Map 0's taproom (an open ring
round three tables, four windows feeding it) the agent trains only 0-6 % of the time with a mean train of 1.5-3.5 (max
10, bunched 60-100 %), takes 6-37 hits per training minute, and the plain Fight action measured better than training
small groups. The yard's Well Loop (authored for this) is rarely reached solo: it needs 2,250 Scrip of doors after the
power. Open work: a commit to the yard loop earlier, glance-ahead timing while backing round the loop, the
special-round stand (Bellringers are what down it in rounds 5-6), and the Cousins at full strength with a human
standing.

### Pass 2 (2026-10-24): training as the round's owner, the lane steering, the game plan

What the first pass's numbers said: the agent was rarely on its loop at all (soak hit logs: almost every hit taken
in TRAVEL or in the plain Fight action), the free 16-direction kite drifted it off the ring into side rooms and dead
ends (the bar's pocket, the stairwell, the root cellar through the vault's arch), and its spending left it on the
Garand without Ironhide. What changed (`bot_trainer.gd`, `agent_plan.gd`, player_bot.json):

- **The game plan** (`AgentPlan`, player_bot.json `plans`): a step list per map (door / power / perk / gun with
  `or_tier` / crucible). `BotEconomy.candidates` keeps only the current step's errand (plus ammo, an ammo box,
  upgraded ammo, the boards, the power switch); when the ordinary rules don't offer it (a door's per-round limit, a
  gun the tier table skips) the plan makes its own errand, in the break or a quiet moment only. Map 0: Garand, the
  cellar door, power, Second Wind, Ironhide, stable, yard, Thompson, Marathon, Crucible, Trigger Tonic. Map 1:
  carbine, Rail Yard, MP40, Administration, Second Wind, Barracks, lift, Generator Hall, power, Ironhide, Marathon,
  StG-44. `train_at`: the loops it prefers (`plan_bonus` on the loop score).
- **The trainer owns the round** (`owns_round`, a one-line override in `BotBrain._think`) from `own_from_round` once
  the plan's first loop is open (`ready_to_own`; `own_force_round` forces it); before that, pass 1's gating (a horde
  of 4+, Fight for the rest and for special rounds). It never walks back to its loop through zombies already within
  `travel_fight_m` (it fights there first).
- **Kite-shoot by default:** there is no backpedal penalty, so FACE (turned on the train, firing, walking backwards
  round the loop) is the default with a train behind; RUN (facing the way, sprinting) only when the head comes within
  its reach + `sprint_close_m` and stamina allows (Marathon: a wider gap), to reload, or for a glance every
  `face_max_s`; CUT shoots a cutter when the train is well back. Gathering: the trigger waits until the train has
  `gather_target()` followers (`gather_by_round`) or the round's spawns are out, except for what comes inside the
  gap. The round's last few are stood still for and aimed at. An empty gun is reloaded on the walk.
- **Lane steering** (`_flow`, replacing the free kite): the loop's own line is the path; every 0.1 s it scores five
  lanes across the ring (clipped by rays to the room each side) in both directions with `kite_score`, which now
  simulates every known zombie chasing it for `kite_horizon_s` (1.5 s, pursuit, as their navigation does), less a
  cost for leaving the line, changing lane and turning back.
- Soak tools (tuning only): `--open-doors=`, `--power`, `--give=`, `--loop=` (force a loop), `--posdump=<stem>` (a
  JSON line per 0.2 s: the agent, its phase, every zombie; plus the navmesh) for top-down plots; the trace shows the
  plan's step.

Testbed (round 8, MG42 + Ironhide + Second Wind + Marathon, 3 seeds, only the loop's doors open), hits per training
minute: taproom 14.6, barrel vault 9.5, yard Well Loop 3.1 (training 91%, mean train 8.2, max 18): the yard is the
map's open ground, so the plan heads there. A tight loop round the barrel stack (`map00_cellar_tight`, agent-only,
an experiment) didn't help: the zombies' inner line is shorter than any line the agent can run.

| Batch (seeds) | rounds | mean | notes |
|---|---|---|---|
| Map 0 solo, pass 1 (1-8) | 7 6 6 7 6 7 4 7 | 6.25 | |
| Map 0 solo, pass 2 final (1-12) | 7 4 6 8 7 9 7 6 8 8 7 8 | 7.08 | runs that reach the yard: training 56-90 %, mean train 7-15, 1-5 hits / training min |
| Map 0 + 3 bots (1-4) | 10 10 10 10 | 10.0 | the Cousins (round 10) as in pass 1 |
| Kaltenbrunn solo (1-3) | 9 7 7 | 7.67 | the power still never on: the Generator Hall door is a long trip from the surface |

**Still short of the brief:** solo Map 0 dies at rounds 7-8 (runners, the Garand, the yard reached in only a third
of the runs: the Scrip for Ironhide, two doors and the Thompson comes too late); Kaltenbrunn 7-9 with no power.

### Pass 3 (2026-10-25): how long it goes on its own, and why it stops

The brief: "see how long the bot mode will go by its self and try to improve it", training first. Method: 12-seed
solo batches (`--scenario=botmode --max-minutes=40`), a per-round ledger line in the soak (`[soak] R<n>`: Scrip
earned / spent, training share, kit, the plan's step), the agent's state on every STALL, and two new counters
(`pb_fire_blocks`: why an aimed shot didn't go; `face_exit`: why FACE ended), plus yard testbeds
(`--start-round=7 --open-doors=door_stable,door_yard,door_cellar --power --give=thompson,ironhide_stout,second_wind`)
with `--posdump` plots of every hit.

What the numbers showed, and what changed (`agent_plan.gd`, `agent_crawler.gd`, `bot_trainer.gd`, `bot_aim.gd`,
`bot_locomotion.gd`, `bot_squad.gd`, `bot_perception.gd`, player_bot.json, combat.json):

- **It hardly fired while training.** `pb_fire_blocks` on the yard testbed: 4,379 frames "turning" against 269
  shots. The first-person damped turn (gain 11/s) trailed any moving target by more than the 3 degree fire
  tolerance. Now the turn adds a feed-forward of the look's own turn rate (`turn.ff_max_rad_s` 4, `ff_smooth`
  0.25; gain 16): shots per minute roughly doubled, kills on the testbed 20 -> 44-60. Training a train of 3+, the
  fire discipline's spray width is x `trainer.train_spray_mult` (2): hip fire on the walk into a bunched train hits
  what is behind the target.
- **Dry reloads thrashed.** With a runner at its heels the pass-2 rule started a reload at reach + 0.9 m and
  cancelled it under that, every frame, and it ran a whole train with an empty Garand. A dry reload now starts only
  with room for all of it at a walk (`reload_room`: reach + (head speed - walk) x reload time + 0.9) and is given up
  only when the head is about to swing; part-empty reloads use the same room (not gap + 1 m, which a runner train
  never gave it).
- **Solo it had no home.** `BotSquad._pick_route` looked for a leader in `brains[]`, empty with the agent alone,
  so the squad's home loop stayed null: after a cellar errand it idled in the cellar (a dead end; most pass-2
  solo downs were there, mid-round, in Retreat with the Garand dry). The solo agent now gets a home: its plan's
  first open training ground (the taproom, then the yard).
- **Scrip sat in its pocket** (pass 2 died with 3,000-5,000 Scrip in about half the runs). `AgentPlan.later_steps`:
  while the current step can't be done (too dear: the next `skip_ahead` cheaper steps may go first; affordable but
  waiting, e.g. a Second Wind rebuy in the cellar mid-round: any of them); a `firm` step (Ironhide) is never
  jumped. Wall ammo for the main gun below 55 % (`wall_ammo_below`; the bots keep 35 %).
- **The crawler break** (`AgentCrawler`, player_bot.json `crawler`): with the round down to its last one or two and an
  errand pending (the plan's step affordable and reachable, a Second Wind rebuy, low ammo), it shoots one in the
  legs until it crawls (the game's own leg rule: one sever roll at 35 % of its health, 60 %), leaves it out of the
  threat picture beyond 1.8 m, does the errands as in a break, walks back to its home loop and only then lets it be
  killed. Solo / no bot teammates only. Measured 1-4 crawlers made per run (about a third of the tries fail the
  sever roll), 10-60 s held.
- **A self-revive stood up into the same crowd** (the second down came on the same spot within seconds): after a
  Second Wind self-revive it breaks away at a sprint for `revive_escape_s` (2 s) first.
- **The plan** (Map 0): Garand, cellar, power, Second Wind, **upstairs + MP40**, Ironhide, stable, yard, Thompson,
  Marathon, Crucible. Tried and measured: the yard before the cellar (no Second Wind, 100 health: 4.75 rounds), the
  yard before Ironhide (6.6), pass 2's order with the new code (7.3); an SMG for the rounds before the yard won
  (8.2). Kaltenbrunn: the **maintenance stairs** instead of the lift (`door_stairs`): the lift is a 25 s cage ride,
  not a navmesh way down, so the Generator Hall door was never "reachable" and the plan stalled there with up to
  9,000 Scrip.
- **Stalls.** A round's last crawler could sink below the ground's collision at the yard's edge: the line of sight
  failed at every height (`pb_los` names the blockers) and the agent circled it until the 40-minute cap (also seen in
  the pass-2 baseline). The trainer now walks up and knifes the round's last crawler; crawlers are aimed at the first
  clear height of `combat.json aim.crawler_aim_heights`, and the crawler break never retries a zombie it gave up on
  (it did, every think, and held a round open).
- Tried and dropped: knifing for Scrip in rounds 1-2 (`points.knife_until_round`, now 0): it earned less (the agent
  waited for the zombies to come) and one run died in round 2.

Measured (headless, solo, `--max-minutes=40`; "training runs" = runs with 20 %+ of their time training, their mean
train and median hits per training minute). The pass-2 baseline was re-measured on this machine first. After the
merge of master (T-076 spawn and opening, T-078 Scrip bonuses and the round-5 tonic, T-079 Muster) both sides
were run again on the merged game, so each pair compares the same economy:

| Batch | runs | mean round | best | stall runs (40 min cap) | training share | training runs: train / hits per min | power on |
|---|---|---|---|---|---|---|---|
| Map 0, pass 2 (a2754e7, old economy) | 12 | 7.25 | 9 | 1 | 0.16 | 2 runs: 3.7 / 2.3 | |
| Map 0, pass 3 before the merge | 12 | 8.17 | 10 | 0 | 0.27 | 6 runs: 8.5 / 5.3 | |
| Map 0, pass 2 on merged master (aba1189) | 24 | 7.17 | 9 | 4 | 0.33 | 13 runs: 6.1 / 3.0 | |
| **Map 0, pass 3 on merged master** | 24 | **7.71** | **10** | **0** | 0.28 | 12 runs: 7.7 / 4.5 | |
| Kaltenbrunn, pass 2 (a2754e7) | 6 | 7.50 | 9 | 0 | 0.01 | none | 0 / 6 |
| Kaltenbrunn, pass 2 on merged master | 8 | 7.75 | 10 | 0 | 0.00 | none | 0 / 8 |
| **Kaltenbrunn, pass 3 on merged master** | 8 | **7.00** | 9 | 0 | 0.12 | 2 runs: 4.5 / 5.5 | **5 / 8** |

12-run batches of the same code differ by up to a round (two pass-3 batches of 12 on the merged game: 8.2 and 7.2),
so the Map 0 gain (+0.5 rounds over 24 seeds, no stalls, best 10) is real but small. Most of pass 2's training
share in the old baseline came from the stalled runs (a train of one for 40 minutes).

**Still short of the brief (targets: Map 0 12+, Kaltenbrunn 10+ with the power):** not met. Why it stops:
- On Map 0 the runs that reach the yard with Ironhide and an SMG train well (training 40-90 %, a train of 6-12) and
  die in rounds 9-10 at 4-6 hits per training minute: runners (4.8 m/s) against a walk backwards of ~5.1 m/s, the
  yard's three windows and the stable door feeding cutters into the loop's ends, and a Thompson / MP40 that needs
  15+ hits a zombie from round 8. Most of those runs die with 3,000-7,000 Scrip and Marathon / the Crucible
  unbought: they sit in the cellar and the breaks are 10-15 s; the crawler break helps (1-4 a run) but the sever
  roll fails a third of the time.
- Runs that don't reach the yard by round 7 (about half) die at 6-8 in the taproom / cellar fights with the Garand
  or the MP40.
- Kaltenbrunn: the power now comes on (rounds 5-7) in most runs, but the trip down costs: it dies underground at
  7-8 with Ironhide (in the Barracks, on the surface) unbought and Scrip in hand. Mean rounds went down
  (7.75 -> 7.0 on 8 seeds).
- `smoke_botmode` failed once in four runs (round-4 taproom test with a Thompson: 5 hits, downed); it passed the
  other three.


## 11. T-086: the bots finish the egg, and the agent does it too

**Full Partner is the default** (`settings.gd`, `ee.json default_mode`; an older settings file is migrated once by
`bot_ee_help_rev`). Two rules that kept the egg the player's are now bounded waits, in data (`ee.json`):
`full_commit_after_s` (45 s): a Full Partner bot at a `commit: last_input` step says the last one is the player's
(`EE_HANDOFF`), waits that long, then makes it (`EE_COMMIT_SELF`; `BotEECatalog.commit_open`, `BotEE._commit_ok`);
`full_final_wait_s` (60 s): a `final` step waits that long for the player within `presence_m` from the first time a
bot could have started it (`BotEEHub.final_wait_over`), then the bots go on alone. When Asked keeps both the old way
(an assigned bot never takes the commit). A bot at the radio lets the story channel finish (Fasbender's answer to
each lock) before its next input, so the lines never pile up. A collect step whose data gives the actor a story line
(`on_item` `vo_actor`) silences the bot's generic "Got one."

**The bot-mode agent (T-071) does the egg** through a separate `egg` block of its map plan (`player_bot.json`
plans.map00.egg: quest, `after` steps, from_round, max_pressure, quiet_m, value, every_s; `AgentPlan.egg_block /
egg_ready / egg_value / egg_pending / tick_egg`). It never sits in the spend order: once Ironhide is drunk (from
round 3) and the agent is quiet (a break, its crawler break, or nothing within quiet_m with low pressure) it takes
the next open step from `BotEEHub.pick_for` (the Full Partner pick, `ordered` true: the agent is the player, so it
makes the commit) and the brain's `ee_task` action carries it out; the trainer still owns the rounds, so the work
happens between them, and `AgentCrawler.errands_pending` holds the round open for it. `PlayerBot` attaches the BotEE
on enable and ticks the plan; the HUD tag shows the task. Smoke: `smoke_ee_bots -- --full` (Map 0, Full Partner,
nobody asks: notes, locks, the hand-off wait, the bots' own commit, the story beats, every tonic on the Ledger's
credit). Soak: `tools/ai_soak.sh --scenario=botmode --map=map00` (the `ee_notes` / `ee_tune_locks` /
`ee_complete` columns say how far the agent got).
