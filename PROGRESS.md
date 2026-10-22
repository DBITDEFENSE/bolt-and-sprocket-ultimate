# PROGRESS

RESUME HERE: overnight run 2026-10-21/22. Step 1 (bots) is written and passing its own tests (GUT 517/517, smoke_bot_ai PASS on Map 0 scripted and with gemma3:27b); waiting on the full smoke suite (tools/run_smokes.sh), the Map 1 planner run, the MZ review-fix agent and the v3 docs agent. Then: commit MZ, commit bots + launcher on branches, merge to master, start HB1.

## Overnight run, 2026-10-21 → 22: the plan

State at the start: M0, M1, M2 are done and tagged; GRAVELIGHT has three playable maps (Crossroads Inn, Kaltenbrunn,
Totenhafen) with the campaign chain, perk machines in the Map 0 cellar, the Requisition Crate, power-ups, the
Crucible, wonder weapons, voiced VO and AI bot teammates. Bolt & Sprocket has its slice plus M3 work in progress.
So from the overnight work order only these remain, in this order:

1. **Bots** (asked for tonight): every bot spawns with a Thompson, Ironhide Stout (Juggernog) and Second Wind
   Schnapps (Quick Revive); one bot runs on a local LLM (Ollama, gemma3) that picks its objectives and does the
   map's tasks and easter egg. Branch `bots-local-ai`.
2. **MZ, zombie animation upgrade** (v2 §7): the work is in the working tree from the last session; verify (GUT,
   smokes), fix the open review findings, commit. Branch `mz-anim`.
3. **v3 Homage Bosses docs** (`docs/gravelight/HOMAGE_BOSSES.md` and the doc updates), written in parallel.
4. **HB1, The Cousins** (v3 §2) on Map 0, round 10. Branch `hb1-cousins`.
5. **Morning kit:** `PLAY.bat` dev menu (every playable thing, skip-to-round, god mode), `tools/capture.gd`
   screenshots into `morning/screenshots/`, `morning/MORNING_REPORT.md`.

Rules: `master` is the main branch and must always launch; each step is merged only after GUT + the smokes pass.

## Done

## In progress

- Bots: spawn kit (Thompson, Ironhide Stout, Second Wind) + local-AI planner bot (`gravelight/bots/bot_planner.gd`,
  `local_ai.gd`, docs `docs/gravelight/BOTS.md`). Tests: `test_bot_planner.gd`, `smoke_bot_ai.tscn` — pass.
- Morning kit: `Play.bat` now opens `res://ui/dev_launcher.tscn` (maps, boss tests, B&S planets, start round, god
  mode, survivor, bots, local AI); `tools/capture.sh` → `tools_src/capture.gd` → `morning/screenshots/<milestone>/`
  (tested on Map 0); `tools/run_smokes.sh` runs every smoke silently.
- MZ review fixes (8 findings from the /code-review) — a helper agent is fixing them in `gravelight/enemies/`.
- v3 Homage Bosses design docs — a helper agent is writing them.

## BLOCKED
