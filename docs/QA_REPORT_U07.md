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

## 0. Summary

| Rank | Found | Fixed | Left |
|---|---|---|---|
| Crash / softlock | 9 (Q-01..Q-09: 2 stale bakes, exec bits, a non-headless tool, 2 tooling artefacts, 2 order-dependent tests, zombies falling off the quay, and Q-05, which turned out to be a real bot bug) | 8 fixed with tests, 1 verified as a load flake (Q-06) | 0 |
| Core feel | 0 code changes: the global tables (health ×1.1 from round 10, Scrip 50/100, round pay 40+20r, door ladder 750–2000, perk tiers, Crucible ×1.5/×2, crate pity) were reviewed and the three maps' curves measured (§6.1 economy); nothing is out of line, and the next step up is Map 4's own data (MAP4_FERNFLUG §13.2) | — | — |
| AI | 10 (Q-10..Q-19: unreachable wall-buys, no soak on Totenhafen, bots stuck on furniture, bots passive on Kaltenbrunn, a 16-minute "lost" bot, a round that never ends, one-off idlers) | 7 fixed with tests (T-103, T-106, T-107); Q-12 re-measured (the wipe was the quay stall); Q-18 covered by the stranded fail-safe | 0 bugs; two tuning items reported: bots alone reach the Kaltenbrunn power late, and bots alone cannot carry Map 4 past Act II (Q-19, §7) |
| Readability | 0: VO coverage is complete (1578 audio files, 2 stage directions listed), every HUD/minimap/subtitle rule has a data table; nothing measurable in a headless pass | — | the on-screen pass stays the owner's (Play.bat) |
| Polish | 0 new beyond the morning report's known list (window grime, footprints, plane smoke) | — | unchanged |

**End of the pass (tree with T-103, T-106, T-107 merged):** the full unit suite passes (`logs/qa/gut_phase0_close.log`: 30,939 asserts, 0 failing); `check_scripts` 0 failed; `check_mapdata` PASS; `ads_check --headless` 322/322; every GRAVELIGHT smoke passed in the baseline run or alone afterwards (§1); the full smoke suite runs once more on the final tree at the end of Phase 2. Before → after on the same seeds: Map 0 bots alone stuck 42 events → 3; Kaltenbrunn bots alone round 9 / 0 Scrip → round 12 / 28,800 spent; Totenhafen: no zombie leaves the world, the agent buys and refills.

## 1. Crash / softlock

| # | Map | Issue | Evidence | Fix / test |
|---|---|---|---|---|
| Q-01 | all (tooling) | **The unit suite fails on a fresh checkout**: `test_mapdata` reports the Kaltenbrunn and Rustvane POIs out of date with their scenes (the T-098/T-099 bench and lamp changes were never re-baked). | GUT baseline: 1127/1129, the two fails in `test_mapdata.gd` (`test_bake_check_passes_for_every_playable_level`, `test_json_round_trip`): "map01_kaltenbrunn: POIs out of date with the scene; rustvane: …". | **Fixed**: re-baked both under a virtual display (`xvfb-run … bake_minimap.tscn -- --map=map01_kaltenbrunn,rustvane`, RESULT PASS 2 maps), re-imported; `test_mapdata` 11/11. Guard: the existing test (it is the right test; the bake was stale). Commit `db558d6`. |
| Q-02 | all (tooling) | **Every shell tool in `tools/` was committed without its executable bit** (`100644`), so `tools/ai_soak.sh`, `run_smokes.sh`, `bake_minimap.sh`, `check_mapdata.sh` … fail with "Permission denied" on Linux unless run through `bash`. | `git ls-files -s tools/*.sh` → 14 files at 100644; the first soak launch: `tools/ai_soak.sh: Permission denied`, exit 126. | **Fixed**: `chmod +x tools/*.sh run_tests.sh` committed (mode change). Commit `db558d6`. |
| Q-04 | all (tooling) | **`tools/ads_check.sh --headless --no-shots` was not headless**: the wrapper always opened a window (`--position -4000,-4000 --resolution 1280x720`) and passed `--headless` to the scene as a user arg, so in a cloud session it died with "Unable to create DisplayServer" (exit 1) although CLAUDE.md lists it as the headless form. | `logs/qa/ads_check.log` (first run): "X11 Display is not available … all display drivers failed", EXIT 1. | **Fixed**: the wrapper now launches Godot with `--headless` (implying `--no-shots`) when asked; guard: the headless run's own RESULT line is in §6. |
| Q-05 | all maps (AI) | **A bot with a full crate gun never refilled its dry Crucible-taught gun.** `smoke_bots`' refill phase failed 3 of 5 full runs (first blamed on CPU load; it then failed twice on a quiet machine). The resupply action weighed the bot's *fullest* long gun, so a full MG42 from the crate beside a dry taught Thompson read 100% ammo and the errand scored zero, though two reachable boxes were free. | The smoke's new diagnostic: "slot 1 thompson_up 1/0 … slot 2 mg42 125/500 … AmmoBox_Taproom reachable true, cooldown 0.0, claimable true, 13 m … brain follow 0.28". | **Fixed** (T-117): the action reads the ammo of the gun its candidate refills. The smoke's refill phase now always adds the full second gun; with the old rule it fails every run, with the fix it passes. Test: `test_resupply_weighs_the_gun_it_refills`. |
| Q-06 | Crossroads Inn (tooling) | **`smoke_marks` passes and then aborts on quit** (exit 134, SIGABRT, nothing on stderr after `[marks] RESULT: PASS`), so the runner counts it as a failure. | `.smoke_logs/u07/smoke_marks.log`: `RESULT: PASS`, `exit 134, 63s, script errors 0`. Ran beside two soaks and three worktree imports. | **Verified a load flake**: alone `smoke_marks: exit 0, 68s | RESULT: PASS`. Not reproduced; left as a note. |
| Q-07 | B&S (tooling) | `smoke_bosses` (Bolt & Sprocket) passed but logged 22 script errors: "Could not find type Kranfuehrer". Not a game bug: the Act I merge landed in the main checkout while the baseline suite was running, before the class cache was re-imported. | `.smoke_logs/u07/smoke_bosses.log`. | **Re-run after the import** in the final suite; the lesson (never merge into a checkout mid-suite; the final suite runs on a quiet tree) is in §0. |
| Q-08 | all (tooling) | **`test_weapons.test_input_actions_exist` is order-dependent**: Gravelight's bindings are added to the InputMap only by `GLSettings.activate()/apply_bindings()` (T-024), which some earlier test in the full suite happens to call; run alone (`-gselect=test_weapons`) it fails on ads/reload/lethal/dev_console on every commit back to the baseline. | `logs/qa/test_weapons_dbg.log`: 5/6 passed alone; passes inside the full suite. | **Fixed**: the test applies the bindings itself first (as `test_progression` does). |
| Q-09 | all (tooling) | **`test_map00_alive.test_slots_come_out_of_the_round_queue` is order-dependent**: `RoundManager._cfg` is filled only by `start_game`, so run before any test that starts a game, `take_spawn()` dies on `speed_tiers`. In the game this was harmless (nothing takes a spawn before a match starts) but it made the Map 0 selection red. | `-gselect=test_map00` after the T-106 merge: "Invalid access to property or key 'speed_tiers'". | **Fixed**: `RoundManager._ready` loads the rounds table (start_game reloads it). |
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
| Q-13 | Kaltenbrunn | **The `kaltenbrunn` soak scenario cannot measure the bots on Map 1**: its scripted human stands in the Minehead Yard on the baseline kit and never opens a door, and the bots never lead while a human is up, so the squad plays round 9 in the spawn yard with 0 Scrip spent and wipes there. The wipe itself is also evidence: all four down inside 10 s (Dutch t=674.5, Wren 679.3, Deacon 680.1, Peg 684.3 at x 3–14, z 13–24) with 4 revives pending and 0 attempted. | `logs/ai_runs/20261026_101033_kaltenbrunn_r1_s21.csv`: end=wipe round=9 in 11.4 min, bot kills 229, downs 3 (0.33/round) + 1 human, revives 0/0 judged (pending 4), scrip spent 0, empty-mag 44 (63.9 s), stuck 0. | Re-measured in §6.4; the root cause of the bots' passivity was Q-15 (T-107). The scenario's scripted human still never leaves the yard by design, so its numbers measure the bots only with `--open-doors=all --power`. |
| Q-14 | Crossroads Inn | **Bots get stuck on top of the taproom's centre table** at (16.5, 0.8, 11.5): a bot vaults onto the table (U02 §1 mantle) and the stuck detector then fires there over and over (37 of the run's 42 stuck events, 19.8 s), because the table top is not navmesh and the brain's unstick walks it round the table's edge. | `logs/ai_runs/20261026_101033_bots3_r1_s11.csv` stuck events grouped by place: 37 × (16.5, 0.8, 11.5) (the "map" story prop sits on that table at y 0.752, `gen_map00.gd:3109`); 6 + 3 × (23.6, 3.5, 31.7) (the stable loft). | **Fixed** (T-106): the bake left a 0.2 m navmesh island on every table top (a 1.2 m table eroded by the 0.5 m agent radius), so the bot's path never left the table; `region_min_size` 8 cells drops them, bots mantle only where the landing has navmesh under it (`mantle_land_ok`), and a marooned bot steps down after 2 s. Tests: `test_bot_locomotion` (+2), loco-lab phases `furniture` and `marooned` (off the table in 0.5 s). Same seed before → after: 42 stuck events / 19.8 s → 3 / 18.6 s, 0 on furniture, the round cap reached. |
| Q-15 | Kaltenbrunn | **Bots alone never spend a Scrip on Kaltenbrunn**: with no human they are meant to lead (open the way, throw the power, buy perks; Map 0: 216,300 spent, round 21), but both Map 1 runs end at round 9 with **0 Scrip spent**, no door, no gun, no perk, milling at the yard's north wall (stuck 101 and 122 events, teleports 7 and 6). | `--scenario=bots3 --map=map01` seeds 41–42: `logs/ai_runs/20261026_104126_bots3_r{1,2}_s4{1,2}.csv`; stuck clusters (30.9, 0, 3.5) ×7, (38.7, 0, 6.4) ×4, (8.7, 0, 3.1), (3.6, 0, 4.3); teleports at (4.9, 0.6, 3.5). | **Fixed** (T-107): the self-led power plan queried the navmesh with the open zones' layers only; on a per-zone-region map that is a partial path to the yard's corner and never crosses a door, so no "power door" and no other door (the routes named none). The plan now runs across every zone but the lift's and buys the nearest closed door it crosses; `routes_map01.json` names its doors. Tests: `test_bot_brain` (+3), `test_map01_edges` (routes name real doors). Same seed before → after: r9 / 0 spent / stuck 101 / teleports 7 → r12 / 28,800 spent (4 doors) / 42 / 3, kills 297 → 548. |
| Q-16 | Kaltenbrunn | **A bot is "lost" for 956 s at one spot in the Administration Block** (−11.8, 0, 27.4): 17 stuck/stretch events there and two teleports nearby, in a run with every door open and the power on. | `--scenario=kaltenbrunn --open-doors=all --power` seed 51: wipe at round 12, spent 30,310, revives 67%, stuck 19 / 42.2 s, teleports 2, lost 956 s (`20261026_104126_kaltenbrunn_r1_s51.csv`). | **Fixed** (T-107): the navmesh ran over the Admin ramp's low east edge (0.27 m, under max_climb), so paths entered the stairs from the side and the body hit the ramp's face; closed stair strings on both sides (`AdminStairStringE/W`). Test: no navmesh vertex climbs the ramp's side. Open-map run: stuck 19 / 42.2 s → 4 / 4.4 s, teleports 2 → 1. |
| Q-17 | Kaltenbrunn | **A round that never ends**: in bot mode (player agent + 3 bots) round 12 stalled for 140 minutes until the 150-min cap. The players were down in the Generator Hall (y −12); four zombies stayed upstairs, a crawler at (2.0, 0, 24.9) whose path ends at (39.2, 0.5, 31.2) on the surface. It cannot reach the players, and the last-zombie rule never culls a crawler, so nothing ends the round. | `logs/qa/soak_map01_botmode.log`: 129 identical STALL blocks; `20261026_105053_botmode_r1_s71.csv`: end=time cap, round 12, 150 min. | **Fixed** (T-107): two things. The stall report (and `Zombie.can_walk_to`) queried the navmesh with the default one-layer mask, so "path ends on the surface" was the tool's blindness: the navmesh *is* connected to the Generator Hall with those doors open (now a `smoke_map01` path check). The real jam (crawlers at the Admin door) is covered by the new generic fail-safe: a chasing zombie whose path end stays > 6 m from every living player for 45 s once nothing is left to spawn is relocated to a ground spawn near the players (`rounds.json "stranded"`, bosses excluded). Tests: `test_stranded` (3). |
| Q-18 | Crossroads Inn | Two single 20 s zombie idles in a 16-round playtest: one in TO_WINDOW at (26, 0, −1) (a west-side window closet) and one in CHASE at (4, 0, 15) while the player stood upstairs at (20, 4, 3); plus one "player stuck while walking a nav path" at (24, 4, 32) (the stable loft) and two wall-buy errand timeouts (Kar98k ammo at (0.2, 1.5, 3.1), MP40 at (0.2, 5.3, 3.4): the agent's own approach, as in Q-10). | `logs/qa/playtest_map00_r15_bots3.log`: REACHED round 15 (16 in 22.8 min), 1 bot down, frame p50 7.9 / p99 20.7 ms. | Each a one-off (no repeats in 23 minutes); the idlers are the case the generic unreachable-zombie fail-safe from Q-17 covers (a zombie that cannot reach any player is respawned near them); the loft snag is the T-106 hay-stair rail hug; the errands are the tool. Re-measured in the final soak. |
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

**Crossroads Inn (map00), to round 16 (the cap), 22.8 min:**

| Round | s | Agent kills | Dmg | Scrip after | Max alive |
|---|---|---|---|---|---|
| 1 | 66 | 2 | 0 | 605 | 7 |
| 2 | 97 | 3 | 300 | 1010 | 13 |
| 3 | 83 | 2 | 0 | 425 | 12 |
| 4 | 76 | 3 | 0 | 3060 | 12 |
| 5 | 79 | 8 | 50 | 2875 | 9 |
| 6 | 31 | 0 | 210 | 3560 | 12 |
| 7 | 101 | 7 | 100 | 3580 | 8 |
| 8 | 98 | 4 | 50 | 5105 | 7 |
| 9 | 107 | 0 | 100 | 5670 | 8 |
| 10 (Cousins) | 60 | 2 | 550 | 9615 | 9 |
| 11 | 117 | 3 | 150 | 10760 | 9 |
| 12 | 132 | 0 | 150 | 11515 | 9 |
| 13 | 36 | 1 | 175 | 11770 | 8 |
| 14 | 134 | 6 | 200 | 8075 | 13 |
| 15 | 141 | 1 | 250 | 1360 | 13 |

Bots 726 kills, 1 bot down, 1 bot-to-bot revive; frame p50 7.9 / p99 20.7 / max 246 ms.

**Kaltenbrunn (map01), game over at round 9 (10.7 min):** r1–r8 at 47 / 56 / 59 / 74 / 31 / 88 / 91 / 101 s, agent kills 2 / 1 / 3 / 3 / 2 / 7 / 6 / 5, Scrip 605 → 6,695, max alive 5–10; the agent down twice in round 8 at the yard's north wall (38, 0, 3), the squad wiped in round 9 at (37, 0, 31) with 0 bot-to-bot revives. The same picture as Q-13/Q-15: nobody leaves the Minehead Yard.

**Economy across the three maps (the agent's Scrip after round 8, the same weak player):** Inn 5,105 · Kaltenbrunn 6,695 · Totenhafen 4,380; doors to open the whole map 7,750 / 9,250 / 9,000. Totenhafen pays least per round at the quay (its spawns are the slowest to arrive: max alive 5–9 vs the Inn's 7–13), so it is the map where a cautious squad stalls on Scrip; Kaltenbrunn pays best because the yard feeds from three sides. Map 4's acts are tuned against these (MAP4_FERNFLUG §13.2).

*(The bot-mode and final-soak tables (rounds reached, revive rate, stuck time, Scrip earned by round 3/5/8) and the bot-mode tables follow as the runs finish.)*

## 7. Map 4 "Fernflug": the full-run soak (UPDATE 07 Phase 2 finish; T-116)

`tools/ai_soak.sh --scenario=fernflug` plays Map 4 as one campaign run with 3 Veteran bots, headless, `--fixed-fps 60`. Two kinds of proof:

**The whole chain, Act I → the ending** (dev skips a player has: `exfil now`, `quest skipto`, console gives, `cancel now`):
- `smoke_map04_full`: Act I → the boarding → Act II → the crash → Act III → the rocket → Act IV → the KÜNDIGUNG ending, the carry checked at every arrival (guns, perks, Scrip, round, act label, `london_seen`/`bomb_*`/`peg_*` flags); then a skip to Act IV and the renewal into the Retained state. **PASS, 74 s, 0 script errors.**
- `smoke_map04_egg`: the main egg s1–s18 across the four acts with the bots on Full Partner, the two Act IV side eggs, the profile rewards, the ending to the credits. **PASS, 163 s, 0 script errors.**

**Unskipped runs with bots** (no dev skips; the clock moves the acts):

| run | act | rounds | game min | bot downs | revived | stuck events / s | teleports | Scrip spent | doors | end |
|---|---|---|---|---|---|---|---|---|---|---|
| bots + scripted human (seed 91) | I Werk Thalbach | 1–12 | 18.0 | 5 | 10 | 8 / 25.0 | 1 | 13,300 | 3 | wipe |
| bots alone (seed 92) | I Werk Thalbach | 1–15 | 24.7 | 0 | 0 | 21 / 70.8 | 3 | 53,600 | 5 | boarded (the harness held the beacon) |
| bots alone (seed 92) | II der Kranich | 16–19 | 9.0 | 3 | 0 | 33 / 92.8 | 3 | 20,500 | 3 | wipe |
| bots alone, skip to Act III (seed 94) | III Groom Lake | 21 | 0.7 | 3 | 0 | 2 / 0.0 | 0 | 0 | 0 | wipe |
| bots alone, skip to Act IV (seed 95) | IV Mondlicht | 30 | 1.8 | 4 | 1 | 1 / 1.9 | 0 | 3,000 | 0 | wipe |

0 script errors and 0 stalls in every run (the stranded fail-safe and the no-spawn fallback were never needed in these seeds).

**What the runs say:**
- **The chain and the transitions are sound.** A bots-only squad cleared Act I to round 15, opened five doors, threw the power in round 2, boarded and arrived in Act II with its kit, round and Scrip.
- **Q-19 (balance, reported, not retuned):** bots without a human cannot carry Map 4 past Act II. A cold skip into Act III (round 21) or Act IV (round 30) is overrun inside the first wave (8 fast zombies within 3 m at 38 s), even with the arrival kit (a taught STG-44/Thompson, Ironhide). With a human leading, the same squad is the U03 bots; Map 4's difficulty is set for players. The arrival kits stay as designed (the owner judges them on the PC); the bots' Map 4 routes and plans (T-115) are in place for a later tuning pass.
- **A harness limit, not a game bug:** a god-mode run (seed 93) was stopped at Act I round 14: all three bots had bled out and the invulnerable scripted player cannot clear 24 zombies, so the round could not end. Real players don't hit this (a downed solo player ends the match; god mode is a dev toggle).
- Two smoke-tool bugs found and fixed on the way (T-115): the egg smoke never printed its RESULT; the Act III smoke polled the freed map after the hand-over to Act IV.
