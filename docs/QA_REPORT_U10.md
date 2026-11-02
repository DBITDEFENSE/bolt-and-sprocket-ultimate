# QA report, UPDATE 10 section 7 (bots on the new content, the Kaltenbrunn egg, Q-19)

Work order: `docs/work_orders/UPDATE_10.md` section 7, contract `docs/U10_CONTRACTS.md` C7. Decision: `docs/DECISIONS.md`
T-163. The baseline is `docs/QA_REPORT_U08.md` (T-131). The design notes: `docs/BOT_AI.md` sections 14 and 15.

How the numbers were taken: `tools/ai_soak.sh`, headless, `--fixed-fps 60`, Bot Easter-Egg Help on **Full Partner**,
Bot Skill Veteran. Kaltenbrunn: `--scenario=botmode --map=map01 --bots=3 --ee=full --until-egg` (the agent plays the
human, three bots follow it), as in QA_REPORT_U08. The machine was shared with up to 40 other headless Godot runs
(other workers), so a game minute cost 25-60 real seconds; the soak's results don't depend on the wall clock.

## 1. The Kaltenbrunn egg ("Requiem for Kaltenbrunn")

### 1.1 Acceptance: 5 honest runs (no god mode)

**0 of 5 completed; the target was 3/5.** The final batch ran on c035043d. Two earlier batches were on the way
there (a116a2e1 and df227ff8) and also completed 0/5. Every run was `--scenario=botmode --map=map01 --bots=3 --ee=full
--until-egg --max-minutes=150`, with no god mode. The step lists come from each run's `[ee]` / `EE` lines.

**Final batch (c035043d: everything except the 45 s errand-window cap, 4827dc46, which came after it):**

| Run (seed) | End | Rounds | Game min | Egg steps done | What stopped it |
|---|---|---|---|---|---|
| 31 | wipe | 10 | 17.2 | s0, s3 | an early wipe: the squad was split across floors at round 10 |
| 32 | wipe | 21 | 40.7 | s0, s3 | s1: the pylons were never started before round 21 (the bots worked s3 and the side quest; the agent's plan came first) |
| 33 | wipe | 22 | 51.4 | s0, s1, s2a, s3 | s4: no bot had a Crucible gun yet ("no_upgraded") |
| 34 | wipe | 29 | 80.0 | s0-s5 | s6: the squad had not seen all four little bells; the new scout task didn't start because the Full Partner bots kept re-picking an open s2a step |
| 35 | wipe | 28 | 64.9 | s0-s5 (+ s2b) | s6: the same |

**Earlier batches (before the gun-before-wonder, scout and errand-cap fixes):**

| Batch | Run | End | Rounds | Game min | Steps | What stopped it |
|---|---|---|---|---|---|---|
| a116a2e1 | 11 | time cap | 26 | 150 | s0, s1, s2a, s3 | s4: the bots had taught their Totenglocken (no Crucible gun); a round held open at the end |
| a116a2e1 | 12 | wipe | 28 | 76.1 | s0, s3 | the same, and s1 not done |
| a116a2e1 | 13 | wipe | 26 | 78.5 | s0-s5 (s4 at round 25, after two failed Foreman kills) | s6: the bells weren't all seen |
| a116a2e1 | 14 | wipe | 29 | 73.4 | s0, s1, s2a, s3 | s4: a taught wonder, no Crucible gun |
| a116a2e1 | 15 | wipe | 26 | 57.0 | s0, s1, s2a, s3 | s4: the same |
| df227ff8 | 21 | time cap | 14 | 150 | s0, s1, s2a, s3 | round 14 never ended: the errand window kept the agent's hunt off, and the squad stood 15 m from a stuck zombie with out-of-range Totenglocken (fixed afterwards: the 45 s cap) |
| df227ff8 | 22 | wipe | 21 | 44.0 | s0, s1, s2a, s3 | s4 not reached (no Crucible gun yet) |
| df227ff8 | 23 | wipe | 32 | 86.2 | s0, s3 | s1 never done |
| df227ff8 | 24 | time cap | 25 | 150 | s0-s5 (s4 and s5 at round 15) | s6: the bells weren't all seen |
| df227ff8 | 25 | wipe | 25 | 52.8 | s0, s1, s2a, s3 | s4 not reached |

**The baseline for comparison.** QA_REPORT_U08's honest Kaltenbrunn run wiped at round 12, stuck at s1. This
update's own first honest probes, before most of these fixes, wiped at rounds 11-13 with at most s0 + s3 done.

**What changed.**
- **Survival.** The squads now live to rounds 21-32. They survive PAUL's first visit at round 15 (he retreats) with
  four Totenglocken from the bench.
- **Steps.** s0-s3 are routine. s4 + s5 were done in 4 of the 15 honest runs.

**What still stops it, in order:**
1. **s6, seeing the four little bells.** The squad has to have seen all four (the no-cheat `find: seen` rule).
   - Late squads stay on two loops, so some bell spots are never seen.
   - The scout task (`BotEEHub.scout_job`) only starts when a free bot has nothing else to pick, and an open
     collect step (s2a) kept the bots busy.
   - Next step: let the scout pre-empt a collect step whose targets aren't found.
2. **s4, a Crucible gun.** A gun has to be taught before the Chapel bell, so s4 now waits on Crucible money.
   - The first batch taught wonders first (fixed afterwards).
3. **s1, the pylons.** In some runs they were started late: the agent's plan put the Lab door and the perks first.
4. **Round 10-12 wipes in a few seeds,** with the squad split across floors.

### 1.2 Each step on its own (`--egg-from`, god mode for the agent only)

`--egg-from=<step>` completes the egg up to that step with the skipped steps' world effects; the runs started at round
12 with every door open and the agent holding a Crucible StG-44, 25-30 game minutes each. God mode keeps the agent
alive; the three bots can go down and bleed out as usual.

| Step | Before (U08 code + this update's earlier fixes) | What stopped it | After |
|---|---|---|---|
| s4 the Chapel bell + the Foreman | not reached: round 12 never ended (25-30 min) | a Foreman wedged on the rail-yard fence line; the agent's loop and its hunt kept resetting the game's no-progress recycle | round 12 ends in 131 s; a Full Partner bot lights the bell; the Foreman was shot on its way in (failed) -> rally + hold fire (the rally and hold-fire came after this run; s4 was then done by bots in 4 of the honest runs and in god run 2) |
| s6 the Four Bells | 13 tries x 24 rounds at the specimen-tank bell, none rang | the vantage was "in sight" through the copper pipes (decor layer, which stops bullets) | rang after one change of angle; the third bell next |
| s7 Herr Tamtam | no drummer in 30 min | the crate pull was the agent's alone (breaks only); Full Partner's "nothing to do" cancelled the pull series; the plan dropped its own roll mid-cycle | the drummer after 6 pulls, shot by Deacon: s7 done in 5 game min (from_s7_drummer_d) |
| s8b 30 Totenglocke kills | done in 8.5 game min (Dutch took the Totenglocke and farmed) | (worked once the round ended) | done |
| s9 the Heartstorm | the agent couldn't start it ("couldn't use Crucible": out of ammo with zombies at arm's length; round 12 stalled first) | the stalled round; no Crucible guard | **egg complete** 13.4 game min after s9 opened (the 120 s holdout with the Bellringers and the two Foremen held) |

### 1.3 Full god-mode runs (the agent can't die; from round 1)

| Run | Code | End | Rounds | Steps done | What stopped it |
|---|---|---|---|---|---|
| god 1 | before (U08 + the catalog fix) | time cap 90 min | 15 | s0, s3 | the agent hoarded 21,000 Scrip with an MP40 (Ironhide never bought: every break went to egg work); rounds held open by stragglers |
| god 2 | the hunt, buy-first, Full Partner stages, the errand window | time cap 90 min | 19 | s0-s5 (s4 + s5 at round 15) | s6: the specimen-tank bell, 18 tries from a spot whose rounds hit the decor-layer pipes (fixed afterwards: the shot-mask vantage) |

### 1.4 Honest probes on the way (one run each, seeds 1-4)

| Run | Code | End | Rounds | Steps | What killed it |
|---|---|---|---|---|---|
| honest 0 | the hunt only | wipe | 13 | s0 | the agent stuck on the Lab door (83 m from its loop) with 15,000-22,000 Scrip; 9 bot downs |
| honest 1 | + buy-first, the errand window | wipe | 11 | s0, s3 | the agent went down twice at 100 HP in round 6 (no Ironhide before the power); the round-11 wipe began with a bot alone on an egg errand 33-78 m from the others |
| honest 2 | rebased on T-161 + unreachable stragglers, the bell angles | wipe | 12 | s0, s3 | the Lab door errand timed out on the 83 m walk every round (fixed: timeouts count the walk); every down was alone, 24-60 m from the nearest teammate |
| honest 3 | + bench wonders, PAUL tactics | wipe | 30 | s1-s5 | s6: the bells weren't all seen (it survived PAUL at round 15) |

## 2. Q-19: bots alone through Fernflug Act II into Act III

Q-19's target: bots alone get through Fernflug Act II into Act III in at least 1 of 3 runs. Every run used
`--scenario=fernflug --bots-alone --skip-to-act=2 --max-minutes=40`. Act II starts at match round 14, so act round 1
is match round 15.

| Batch | Code | Run 1 | Run 2 | Run 3 | Into Act III |
|---|---|---|---|---|---|
| Baseline | master, the old Act II | wipe, act round 1 (0.9 min) | wipe, act round 1 (0.9) | wipe, act round 1 (1.6) | 0/3 |
| Stand-fast (helper, mid-tuning) | home loops, doors in a break, retreat, counters, stand-fast | act round 3 (5.7) | act round 3 (8.0) | **act rounds 1-6, then the exfil (13.0 min); wiped in Act III's round 21** | **1/3** |
| Traps + yield (helper) | + traps for a squad alone, the yield rule | act round 1 (2.0) | act round 4 (9.2) | act round 4 (8.6) | 0/3 |
| b5 (helper's final) | everything of the helper's | act round 5 (12.1) | act round 4 (10.5) | act round 3 (6.5) | 0/3 |
| Merged (130e8088) | + this branch's Kaltenbrunn changes | act round 1 (2.1) | time cap in act round 4 (a ganger pushed into the hull hit Wren through it for 25 min) | act round 3 (6.4) | 0/3 |
| **Final (604e521b)** | + the knife for an unseen zombie at arm's length | **act round 5 (12.7)** | **act round 3 (7.1)** | **act round 3 (7.2)** | **0/3** |

**Q-19 is not met on the final code.** It was reached once on a mid-tuning commit.
- **What improved.** Every final run survives act round 1; at the baseline, none did.
- **Where they die now.** Act rounds 3-5: the London window's round, the Bordwart's round and the bomb run.
  - The deaths come with sprinters.
  - The bots are split 17-35 m apart.
  - No revive lands (0 revived in every final run).
- **The Bordwart** was never killed; the act's own fallback carried the exfil run through.

## 3. The new content (C7)

Routes, plans and tasks per set-piece: `docs/BOT_AI.md` section 15 (Fernflug: Acts II-IV) and section 14 (Kaltenbrunn,
Totenhafen's boss and wonder).

- **Totenhafen.** The Totenhafen systems (T-153, branch u10-2-totenhafen-systems) were not on master when this
  closed.
  - That branch already gives every LETZTE FAHRT step a bot_task: the coffins as carries, the cipher solver with its
    think_s delay, the three diesel holds, the sail as a hold on `uboat_sail`.
  - It also has the MAN_SEARCHLIGHT mark order and the reach fixes to the signal tower.
  - Here: the Kielholer's counter (`der_kielholer`) and the grab break-free (`BotAim.break_free`), and the Undertow
    as a wonder taken from the bench (its tier 6.5 comes with that branch's economy.json).
  - Not done: verifying each LETZTE FAHRT task in a soak, and the searchlight-order case in smoke_bots_u10. Both
    wait for T-153's merge.

## 4. Tests and smokes

- After the final rebase (master aa1807c5), the full unit suite passes 1738/1738 and check_scripts checks 696 scripts
  with 0 failures.
- New unit tests: `test_bot_u10_eggs.gd` (25 tests) and `test_bot_u10.gd` (21 tests).
- Smoke RESULT lines, all PASS: bot_ai, bot_loco, botmode, bots, bots_u10 (new: the storm, the wing walk with its
  clip and token, the breach rail, the meteor shelter, Pohl's tag), ee_bots, late_kit, requiem, squads.
- `smoke_bot_loco` failed its CPU-time budget twice while ~40 other headless runs loaded the machine; it passed on
  the final run.
