# QA REPORT — UPDATE 07 Phase 0 (the game as it was before Map 4), 2026-10-26

**Build:** master at `c254d4b` (after UPDATE 06), Godot 4.7.2 Linux headless in the cloud session, 4 cores shared by the soaks.
**Maps soaked:** Crossroads Inn (map00), Kaltenbrunn (map01), Totenhafen (map02). **Morgenrot and Helvetia Works are not built** (design only: `docs/MAP3_MORGENROT.md`, v1 §10.6), so the work order's "Morgenrot gets extra attention" item does not apply to this pass; it is recorded here so it is not mistaken for an omission (DECISIONS T-102 (13)).
**How it was played (all headless, `--audio-driver Dummy`):**
- the full GUT suite (`addons/gut/gut_cmdln.gd`, 1129 tests) and the full smoke suite (`tools/run_smokes.sh .smoke_logs/u07`);
- the playtest bot through the real Player's inputs: `tools_src/playtest_gl.tscn -- --rounds=15 --map=<map> --bots=3 --seed=7`;
- the AI soak with the metrics logger: `tools/ai_soak.sh --scenario=bots3|player3|kaltenbrunn|totenhafen|botmode --runs=2 --max-round=20` (logs in `logs/ai_runs/`, summaries in the tables below);
- player bot mode (`--scenario=botmode --bots=3`) on every map;
- the map-data check (`tools/check_mapdata.sh`), `check_scripts`, `ads_check.sh --headless --no-shots`.
Every issue below has a number (Q-NN), a rank, the evidence, and its fix (with the test that guards it) or the reason it is left.

## 0. Summary (filled at the end of the pass)

| Rank | Found | Fixed | Left |
|---|---|---|---|
| Crash / softlock | | | |
| Core feel | | | |
| AI | | | |
| Readability | | | |
| Polish | | | |

## 1. Crash / softlock

| # | Map | Issue | Evidence | Fix / test |
|---|---|---|---|---|
| Q-01 | all (tooling) | **The unit suite fails on a fresh checkout**: `test_mapdata` reports the Kaltenbrunn and Rustvane POIs out of date with their scenes (the T-098/T-099 bench and lamp changes were never re-baked). | GUT baseline: 1127/1129, the two fails in `test_mapdata.gd` (`test_bake_check_passes_for_every_playable_level`, `test_json_round_trip`): "map01_kaltenbrunn: POIs out of date with the scene; rustvane: …". | **Fixed**: re-baked both under a virtual display (`xvfb-run … bake_minimap.tscn -- --map=map01_kaltenbrunn,rustvane`, RESULT PASS 2 maps), re-imported; `test_mapdata` 11/11. Guard: the existing test (it is the right test; the bake was stale). Commit `db558d6`. |
| Q-02 | all (tooling) | **Every shell tool in `tools/` was committed without its executable bit** (`100644`), so `tools/ai_soak.sh`, `run_smokes.sh`, `bake_minimap.sh`, `check_mapdata.sh` … fail with "Permission denied" on Linux unless run through `bash`. | `git ls-files -s tools/*.sh` → 14 files at 100644; the first soak launch: `tools/ai_soak.sh: Permission denied`, exit 126. | **Fixed**: `chmod +x tools/*.sh run_tests.sh` committed (mode change). Commit `db558d6`. |
| Q-04 | all (tooling) | **`tools/ads_check.sh --headless --no-shots` was not headless**: the wrapper always opened a window (`--position -4000,-4000 --resolution 1280x720`) and passed `--headless` to the scene as a user arg, so in a cloud session it died with "Unable to create DisplayServer" (exit 1) although CLAUDE.md lists it as the headless form. | `logs/qa/ads_check.log` (first run): "X11 Display is not available … all display drivers failed", EXIT 1. | **Fixed**: the wrapper now launches Godot with `--headless` (implying `--no-shots`) when asked; guard: the headless run's own RESULT line is in §6. |
| Q-05 | Crossroads Inn (tooling) | **`smoke_bots` fails under CPU load**: in the refill phase P2 (Dutch, Thompson taught, 1/0 ammo, 3000 Scrip) did not reach an ammo box within the 90 s window while the suite ran beside two soaks and two worktree imports (load avg 7.8 on 4 cores). The smokes run without `--fixed-fps`, so a bot's 90 s window is 90 real seconds while the physics and brains are time-dilated. The U04 report already noted "two timing-flaky checks". | `.smoke_logs/u07/smoke_bots.log`: `FAIL: P2 never refilled its upgraded gun at an ammo box`, 745 s, 0 script errors; the same phase's rule (`bot_economy._ammo_candidate`: nearly dry → any reachable box, value 1.0) is unchanged since T-083. | **To verify alone** (re-run with the CPU free); if it passes, the fix is in the runner: `run_smokes.sh` gets `--fixed-fps 60` so a smoke's seconds are simulation seconds whatever the load (checked against the whole suite before it lands). |
| Q-06 | Crossroads Inn (tooling) | **`smoke_marks` passes and then aborts on quit** (exit 134, SIGABRT, nothing on stderr after `[marks] RESULT: PASS`), so the runner counts it as a failure. | `.smoke_logs/u07/smoke_marks.log`: `RESULT: PASS`, `exit 134, 63s, script errors 0`. Ran beside two soaks and three worktree imports. | **To verify alone** (queued after the soaks with `smoke_bots`); if it reproduces, the abort is in the scene's teardown (the marks UI / bot orders freed after the tree) and is fixed there with a test. |
| Q-07 | B&S (tooling) | `smoke_bosses` (Bolt & Sprocket) passed but logged 22 script errors: "Could not find type Kranfuehrer". Not a game bug: the Act I merge landed in the main checkout while the baseline suite was running, before the class cache was re-imported. | `.smoke_logs/u07/smoke_bosses.log`. | **Re-run after the import** in the final suite; the lesson (never merge into a checkout mid-suite; the final suite runs on a quiet tree) is in §0. |
| Q-08 | all (tooling) | **`test_weapons.test_input_actions_exist` is order-dependent**: Gravelight's bindings are added to the InputMap only by `GLSettings.activate()/apply_bindings()` (T-024), which some earlier test in the full suite happens to call; run alone (`-gselect=test_weapons`) it fails on ads/reload/lethal/dev_console on every commit back to the baseline. | `logs/qa/test_weapons_dbg.log`: 5/6 passed alone; passes inside the full suite. | **Fixed**: the test applies the bindings itself first (as `test_progression` does). |
| Q-03 | Totenhafen | **Zombies fall out of the world at the quay's seaward edge** (y < −15 near (22, 0, 0) and (26, 0, 0), the south edge of A_QUAY). A fallen zombie is never culled by the round, so a round can hang on it until the "last zombie" rule or the stall watcher. | playtest r15 bots3 seed 7: two `ISSUE: zombie fell out of the world` lines (rounds 4 and 10). | **Fixed** (T-103): the two parapet landing stages (`Stage` decks behind W_A_N1/N2) are timber over a shingle and sea bed with `collide=false`; a zombie shoved off a stage fell forever. Hidden kerb rails on each stage's three open sides (rope dressing on the posts), stages named `Stage_10`/`Stage_24`. Test `test_map02_edges`: kerbs on three open sides. Re-verified: playtest to round 8 with no fall message. |

## 2. Core feel (movement, ADS, recoil, hits, damage numbers, round pacing, economy per round, perks at the cap of 6, Crucible tiers, box odds)

| # | Map | Issue | Evidence | Fix / test |
|---|---|---|---|---|
| | | *(filled from the soak tables in §6)* | | |

## 3. AI (zombie pathing, bot stuck spots, revives)

| # | Map | Issue | Evidence | Fix / test |
|---|---|---|---|---|
| Q-10 | Totenhafen | **The player-bot's wall-buy errands time out** at the frag (−0.2, 1.5, 26) and the Trench Gun (−0.2, 1.5, 22), both on the quay/cannery wall: the agent walks to them and never gets the prompt. | playtest r15 bots3 seed 7: `ISSUE: errand timed out: gun frag …`, `… gun trench_gun …`. | **Fixed** (T-103): a tool bug and two map bugs. The playtest bot's `_front_of` used the board's origin (a WallBuy's prompt Area sits at its origin; only the shape is offset), so it accepted a path ending on the quay side of the x=0 wall; it now uses the board's facing (local −Z) and rejects paths ending behind it. The test it got then found the BAR board hung over Basin 1 and the Thompson board inside Locker2: both moved to the lockers' free faces. Map data re-baked for the moved boards (the bake is part of any wall-buy move). Test: navmesh within 2 m in front of every map02 wall-buy. Re-verified: a round-6 playtest with zero ISSUE lines (the agent buys, repairs, refills). |
| Q-11 | Totenhafen | **The AI soak and bot mode cannot run on Totenhafen**: `ai_soak.gd` knows only map00/map01, there is no `routes_map02.json` (so bots have no training routes there) and no map02 plan in `player_bot.json`. The bots on Totenhafen train "a ring of reachable points around the spawn" and nothing else. | `tools_src/ai_soak.gd` `const MAPS`; `data/gravelight/ai/` listing; the playtest's bot block: Peg/Deacon/Wren ended at round 14 with 25–41k Scrip unspent, doors 0, upgrades 0, all three down within 2 m of (1, 0, 29). | **Fixed** (T-103): `--scenario=totenhafen` (map02 in `ai_soak.gd` and `route_tool.gd`), `routes_map02.json` (hut, cannery, apron loops; all PASS in `route_tool --validate`), a map02 plan in `player_bot.json`. Test: every point of every `routes_map0*.json` on its map's navmesh. First measurement: seed 31 to round 12 (the cap) in 15.2 min, bot kills 441, bot downs 3 (0.25/round), no STALL. |
| Q-13 | Kaltenbrunn | **The `kaltenbrunn` soak scenario cannot measure the bots on Map 1**: its scripted human stands in the Minehead Yard on the baseline kit and never opens a door, and the bots never lead while a human is up, so the squad plays round 9 in the spawn yard with 0 Scrip spent and wipes there. The wipe itself is also evidence: all four down inside 10 s (Dutch t=674.5, Wren 679.3, Deacon 680.1, Peg 684.3 at x 3–14, z 13–24) with 4 revives pending and 0 attempted. | `logs/ai_runs/20261026_101033_kaltenbrunn_r1_s21.csv`: end=wipe round=9 in 11.4 min, bot kills 229, downs 3 (0.33/round) + 1 human, revives 0/0 judged (pending 4), scrip spent 0, empty-mag 44 (63.9 s), stuck 0. | Re-measured with `--open-doors=all --power` and with `--scenario=bots3 --map=map01` (bots lead themselves) in §6; the revive finding is judged on those runs. The scenario's doc gets the caveat. |
| Q-14 | Crossroads Inn | **Bots get stuck on top of the taproom's centre table** at (16.5, 0.8, 11.5): a bot vaults onto the table (U02 §1 mantle) and the stuck detector then fires there over and over (37 of the run's 42 stuck events, 19.8 s), because the table top is not navmesh and the brain's unstick walks it round the table's edge. | `logs/ai_runs/20261026_101033_bots3_r1_s11.csv` stuck events grouped by place: 37 × (16.5, 0.8, 11.5) (the "map" story prop sits on that table at y 0.752, `gen_map00.gd:3109`); 6 + 3 × (23.6, 3.5, 31.7) (the stable loft). | **To fix** (worker u07-qa-map00): no bot vault onto furniture tops (the mantle target must be navmesh), or a nav-blocked table footprint plus a "step down" unstick; test: a bot placed on the table reaches the floor navmesh within 2 s. |
| Q-15 | Kaltenbrunn | **Bots alone never spend a Scrip on Kaltenbrunn**: with no human they are meant to lead (open the way, throw the power, buy perks; Map 0: 216,300 spent, round 21), but both Map 1 runs end at round 9 with **0 Scrip spent**, no door, no gun, no perk, milling at the yard's north wall (stuck 101 and 122 events, teleports 7 and 6). | `--scenario=bots3 --map=map01` seeds 41–42: `logs/ai_runs/20261026_104126_bots3_r{1,2}_s4{1,2}.csv`; stuck clusters (30.9, 0, 3.5) ×7, (38.7, 0, 6.4) ×4, (8.7, 0, 3.1), (3.6, 0, 4.3); teleports at (4.9, 0.6, 3.5). | **In progress** (worker u07-qa-map01): the door/shop candidate rules for a bot-led squad on a per-zone navmesh map; test. |
| Q-16 | Kaltenbrunn | **A bot is "lost" for 956 s at one spot in the Administration Block** (−11.8, 0, 27.4): 17 stuck/stretch events there and two teleports nearby, in a run with every door open and the power on. | `--scenario=kaltenbrunn --open-doors=all --power` seed 51: wipe at round 12, spent 30,310, revives 67%, stuck 19 / 42.2 s, teleports 2, lost 956 s (`20261026_104126_kaltenbrunn_r1_s51.csv`). | **In progress** (worker u07-qa-map01): the geometry/navmesh at that spot and the unstick; test. |
| Q-17 | Kaltenbrunn | **A round that never ends**: in bot mode (player agent + 3 bots) round 12 stalled for 140 minutes until the 150-min cap. The players were down in the Generator Hall (y −12); four zombies stayed upstairs, a crawler at (2.0, 0, 24.9) whose path ends at (39.2, 0.5, 31.2) on the surface. It cannot reach the players, and the last-zombie rule never culls a crawler, so nothing ends the round. | `logs/qa/soak_map01_botmode.log`: 129 identical STALL blocks; `20261026_105053_botmode_r1_s71.csv`: end=time cap, round 12, 150 min. | **In progress** (worker u07-qa-map01, task C2): the missing path down (stairs/lift links) and a generic director fail-safe (a zombie whose path has not reached any player for N s while nothing is left to spawn is respawned near the players); tests. |
| Q-12 | Totenhafen | **The squad wipes together at the quay around round 14 with three bots and a weak human**: all three bots went down within 2 m of each other at (1, 0, 29) in the same round with 0 bot-to-bot revives (1 revive of the human all match). | playtest DOWN block r14; `bots revived each other 0 times`. | Evidence for the AI pass (§6): re-measured with the real soak once Q-11 lands; the Map 0 baseline for the same squad is 71–91% bot revives. |

## 4. Readability (HUD, prompts, minimap, audio mix, subtitles)

| # | Map | Issue | Evidence | Fix / test |
|---|---|---|---|---|
| | | | | |

## 5. Polish

| # | Map | Issue | Evidence | Fix / test |
|---|---|---|---|---|
| | | | | |

## 6. Measured curves (the evidence)

### 6.1 Playtest bot, round by round (solo human agent + 3 Veteran bots, seed 7; the agent is a weak player: 27% hits, so this measures the maps' pressure, not a good player's)

**Totenhafen (map02), to round 14, game over at r14 (18.5 min):**

| Round | Seconds | Agent kills | Dmg taken | Scrip after | Max alive |
|---|---|---|---|---|---|
| 1 | 52 | 2 | 0 | 595 | 8 |
| 2 | 60 | 0 | 0 | 810 | 7 |
| 3 | 73 | 2 | 0 | 1255 | 9 |
| 4 | 75 | 0 | 0 | 1880 | 9 |
| 5 | 91 | 6 | 0 | 2785 | 8 |
| 6 | 32 | 0 | 0 | 3130 | 5 |
| 7 | 102 | 4 | 0 | 3965 | 8 |
| 8 | 97 | 0 | 0 | 4380 | 8 |
| 9 | 104 | 1 | 50 | 4715 | 8 |
| 10 | 110 | 5 | 100 | 5820 | 9 |
| 11 | 118 | 2 | 250 (down) | 7195 | 9 |
| 12 | 34 | 0 | 105 | 8500 | 5 |
| 13 | 131 | 2 | 0 | 9495 | 9 |
| 14 | — | — | 205 (down, wipe) | — | — |

Bots: 576 kills (Peg 222 / Deacon 107 / Wren 247), 3 bot downs, 1 revive of the human, 0 bot-to-bot revives; brain 0.53 ms/bot/frame; frame ms p50 6.0 / p99 16.0 / max 191 (one >100 ms frame at r13). Nobody opened a door (the agent buys guns only; bots never lead while a human stands): the whole match was the quay.

### 6.2 AI soak, bots alone on Crossroads Inn (`--scenario=bots3`, Veteran, seeds 11–12, max round 20)

| run | end | round | min | bot kills | bot downs | downs/round | revive % (judged) | stuck events / s | Scrip spent | empty-mag events / s |
|---|---|---|---|---|---|---|---|---|---|---|
| r1 | reached the cap | 21 | 34.2 | 1424 | 0 | 0.00 | — (0/0) | 42 / 19.8 | 216,300 | 19 / 11 |
| r2 | wipe | 15 | 22.2 | 683 | 8 | 0.53 | 83% (5/6) | 4 / 19.7 | 105,200 | 87 / 63 |
| mean | | **18.0** | 28.2 | 1053 | 4.0 | 0.27 | | 23 / 19.8 | 160,750 | 53 / 37 |

Against the U03 baseline (mean 14.7, best 20, revives 71–91%): **the bots are better on Map 0 than at U03** (mean 18, one run at the cap); the stuck time is one spot (Q-14). The Cousins round was cleared in both runs under the bots-alone scaling.

### 6.3 AI soak, Kaltenbrunn with the scripted human (`--scenario=kaltenbrunn`, seeds 21–22)

| run | end | round | min | bot kills | bot downs | human downs | revives | Scrip spent | empty-mag s |
|---|---|---|---|---|---|---|---|---|---|
| r1 | wipe | 9 | 11.4 | 229 | 3 | 1 | 0/0 judged, 4 pending | **0** | 64 |
| r2 | wipe | 8 | 9.5 | 196 | 3 | 1 | 0/3 judged, 1 attempt | **0** | 71 |

Not a measure of the bots (Q-13): nobody leaves the yard. The re-measure is in §6.4.

### 6.4 AI soak, Kaltenbrunn re-measured (seeds 41–42 bots alone; seed 51 open map + passive human)

| run | end | round | min | bot kills | bot downs | revive % | stuck events / s | teleports | lost s | Scrip spent |
|---|---|---|---|---|---|---|---|---|---|---|
| bots alone r1 | wipe | 9 | 11.6 | 297 | 3 | 0% (0/1) | 101 / 37.4 | 7 | 0 | **0** |
| bots alone r2 | wipe | 9 | 11.1 | 242 | 6 | 100% (3/3) | 122 / 7.6 | 6 | 0 | **0** |
| open map + human | wipe | 12 | 22.1 | 441 | 5 (+1 human) | 67% (2/3) | 19 / 42.2 | 2 | **956** | 30,310 |

Map 0's same squad: 18.0 mean round, 23 stuck events, 0 teleports, 160,750 spent. **Kaltenbrunn is where the bots fail** (Q-15, Q-16), not Map 0.

### 6.5 Bot mode (the player agent + 3 Veteran bots; `--scenario=botmode --bots=3`)

| map | end | round | min | agent downs | bot downs | revive % | stuck events / s | lost s | Scrip spent | training share |
|---|---|---|---|---|---|---|---|---|---|---|
| Crossroads Inn (seed 61) | wipe | 18 | 28.5 | 1 | 11 (0.61/round) | 70% (7/10) | 7 / 40 | 398 | 112,650 | 35% |
| Kaltenbrunn (seed 71) | **time cap** | 12 | 150.0 | 1 | 4 (0.33/round) | 60% (3/5) | 146 / 69 | 514 | 39,700 | 3% |

The Kaltenbrunn run is Q-17 (a round that never ends); its 146 stuck events are the agent's, mostly in the long stall. Map 0's agent reaches round 18 with the squad, against the U04 target of 20–25.

*(Map 0 and Map 1 playtest tables (rounds reached, revive rate, stuck time, Scrip earned by round 3/5/8) and the bot-mode tables follow as the runs finish.)*
