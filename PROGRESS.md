# PROGRESS

RESUME HERE: overnight run. Bots, MZ, the v3 docs and the morning kit are committed and merged to master (efb3be3, tag mz). HB1 The Cousins is being built on branch hb1-cousins by a helper agent (uncommitted in the working tree); when it reports: run check_scripts, GUT, tools/run_smokes.sh, commit on hb1-cousins, merge to master, capture `tools/capture.sh overnight`, write morning/MORNING_REPORT.md.

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

- **Bots** (T-043, commit 33c1043): spawn kit (Thompson, Ironhide Stout, Second Wind) — works; local-AI planner bot
  (Ollama gemma3:27b) — works on Map 0's egg alone, Map 1's Requiem partly (power, doors, Totenglocke).
- **MZ** (T-041 + review fixes, commit 8a7ae4f, tag `mz`) — works; GUT 525/525, all smokes pass.
- **v3 Homage Bosses docs** (T-042, commit f594eaf) — done.
- **Morning kit** (T-044, commits 85ee6cb, efb3be3): `Play.bat` dev launcher, `tools/capture.sh`, `tools/run_smokes.sh`
  — works; screenshots in `morning/screenshots/overnight/` (git-ignored).
- Bolt & Sprocket: `delayed_blast.gd` freed-source script error (smoke_nova) fixed (35bdeac).

## In progress

- **HB1 The Cousins** (branch `hb1-cousins`): being built by a helper agent from `docs/HOMAGE_BOSSES.md`.

## BLOCKED
