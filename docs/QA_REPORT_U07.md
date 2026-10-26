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
| Q-03 | Totenhafen | **Zombies fall out of the world at the quay's seaward edge** (y < −15 near (22, 0, 0) and (26, 0, 0), the south edge of A_QUAY). A fallen zombie is never culled by the round, so a round can hang on it until the "last zombie" rule or the stall watcher. | playtest r15 bots3 seed 7: two `ISSUE: zombie fell out of the world` lines (rounds 4 and 10). | **In progress** (worker u07-qa-map02): root cause and generator fix + a test that the quay edge is solid under the navmesh. |

## 2. Core feel (movement, ADS, recoil, hits, damage numbers, round pacing, economy per round, perks at the cap of 6, Crucible tiers, box odds)

| # | Map | Issue | Evidence | Fix / test |
|---|---|---|---|---|
| | | *(filled from the soak tables in §6)* | | |

## 3. AI (zombie pathing, bot stuck spots, revives)

| # | Map | Issue | Evidence | Fix / test |
|---|---|---|---|---|
| Q-10 | Totenhafen | **The player-bot's wall-buy errands time out** at the frag (−0.2, 1.5, 26) and the Trench Gun (−0.2, 1.5, 22), both on the quay/cannery wall: the agent walks to them and never gets the prompt. | playtest r15 bots3 seed 7: `ISSUE: errand timed out: gun frag …`, `… gun trench_gun …`. | **In progress** (worker u07-qa-map02): reach check vs the wall thickness / closet islands; test that every map02 wall-buy is within interact reach of the open side's navmesh. |
| Q-11 | Totenhafen | **The AI soak and bot mode cannot run on Totenhafen**: `ai_soak.gd` knows only map00/map01, there is no `routes_map02.json` (so bots have no training routes there) and no map02 plan in `player_bot.json`. The bots on Totenhafen train "a ring of reachable points around the spawn" and nothing else. | `tools_src/ai_soak.gd` `const MAPS`; `data/gravelight/ai/` listing; the playtest's bot block: Peg/Deacon/Wren ended at round 14 with 25–41k Scrip unspent, doors 0, upgrades 0, all three down within 2 m of (1, 0, 29). | **In progress** (worker u07-qa-map02): `--scenario=totenhafen`, `routes_map02.json`, a map02 plan, a test that every route point of every map is on its navmesh. |
| Q-13 | Kaltenbrunn | **The `kaltenbrunn` soak scenario cannot measure the bots on Map 1**: its scripted human stands in the Minehead Yard on the baseline kit and never opens a door, and the bots never lead while a human is up, so the squad plays round 9 in the spawn yard with 0 Scrip spent and wipes there. The wipe itself is also evidence: all four down inside 10 s (Dutch t=674.5, Wren 679.3, Deacon 680.1, Peg 684.3 at x 3–14, z 13–24) with 4 revives pending and 0 attempted. | `logs/ai_runs/20261026_101033_kaltenbrunn_r1_s21.csv`: end=wipe round=9 in 11.4 min, bot kills 229, downs 3 (0.33/round) + 1 human, revives 0/0 judged (pending 4), scrip spent 0, empty-mag 44 (63.9 s), stuck 0. | Re-measured with `--open-doors=all --power` and with `--scenario=bots3 --map=map01` (bots lead themselves) in §6; the revive finding is judged on those runs. The scenario's doc gets the caveat. |
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

*(Map 0 and Map 1 tables, the AI-soak tables (rounds reached, revive rate, stuck time, Scrip earned by round 3/5/8) and the bot-mode tables follow as the runs finish.)*
