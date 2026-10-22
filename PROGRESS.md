# PROGRESS

RESUME HERE: Update 02 (UPDATE_02_POLISH.md) in progress. Wave 1 = §1 feel, §2 ADS, §3 Totenglocke, §4 ammo boxes, §7 landscape on branches u02-1..u02-7 (worktrees in .wt/); wave 2 = §5 bots, §6 cellar + Jakub, §8 polish. Merge order follows the brief.

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

## Update 02 — baseline playtest, 2026-10-22 (before any change)

Played Map 0 to round 10 with the playtest bot (`tools_src/playtest_gl.tscn`, which drives the real Player through
the input actions): one god-mode run with the Thompson, and one honest solo run with 3 squad bots. Plus viewmodel
contact sheets (`vm_shots`) and a read of the movement / weapon code. What feels wrong:

**Movement**
- Ground speed snaps: 45 m/s² acceleration (walk speed in 0.1 s) and the same instant stop; no slide on stop.
- Sprint is hold-only; there's no toggle setting. Turn speed doesn't change while sprinting. The sprint FOV is a flat ×1.06 inside the overall
  FOV lerp, with no own smoothing, and the head-bob barely differs from walking.
- **Eaten inputs:** while sprint is held, `fire` and `ads` are ignored (can_shoot needs not-sprinting, and ADS needs
  not-sprinting), so pressing fire mid-sprint does nothing until you let go of sprint. Sprint-out is a fixed 0.16 s
  for every class.
- No mantle/vault (bar counter, fences, low walls block training loops); no prone; crouch height snaps in 0.12 m
  steps (reads as a lerp but at fixed per-frame steps, frame-rate dependent).
- Landing shake is fixed (0.15), not scaled by fall height. No strafe roll, no weapon inertia beyond the look sway,
  no damage punch.

**Gunplay**
- Recoil is a random yaw kick per shot plus a pitch spring: no learnable per-weapon pattern.
- Bloom exists but decays at a fixed rate regardless of stance; the crosshair doesn't show crouch/still benefits.
- Hitmarker: one kind (no red kill tint, no headshot sound).
- Reload cancel by sprint/swap exists partly (sprint queues the reload instead of cancelling it).

**Thompson ADS:** the rear aperture fills the view and the front blade is hidden under the receiver top; the hand
and the mag/drum read into the lower view; sway at ADS is the SMG class sway (0.3) and drifts noticeably.

**Totenglocke:** each ring needs a 0.6 s hold *then* release (feels like a delay, not a gun); only 6 charges a mag
and 24 reserve (30 rings a refill); damage falls off to 60 % at the cone edge so edge zombies survive from round ~15;
no stagger on survivors; the feedback is one explosion puff 3 m ahead and a single bell sample; the reload is a flat
3 s. It doesn't feel like the strongest thing on the map.

**Bots / squad (3 bots, regular):** the squad wiped on round 5 (every bot down in the same round, 0 revives between
bots, 0 revives of the player); they camp where they stand instead of moving with the player; bots ended on the
M1911 (last-stand pistol) after going down.

**Map 0 navigation (god run):** the player got stuck on nav paths at the stair vestibule (6, 0, 15) ×18, the cellar
stairs/landing (27, 0, 11) ×8 and the cellar floor (34, −3, 19) ×12; zombies idled in CHASE at the stair head
(1, 3, 1) and in the taproom (15, 0, −1).

**World:** past the yard fence it's flat snow and black sky; no distant life; the inn reads as a box in a void.

## Done

- **Bots** (T-043, commit 33c1043): spawn kit (Thompson, Ironhide Stout, Second Wind) — works; local-AI planner bot
  (Ollama gemma3:27b) — works on Map 0's egg alone, Map 1's Requiem partly (power, doors, Totenglocke).
- **MZ** (T-041 + review fixes, commit 8a7ae4f, tag `mz`) — works; GUT 525/525, all smokes pass.
- **v3 Homage Bosses docs** (T-042, commit f594eaf) — done.
- **Morning kit** (T-044, commits 85ee6cb, efb3be3): `Play.bat` dev launcher, `tools/capture.sh`, `tools/run_smokes.sh`
  — works; screenshots in `morning/screenshots/overnight/` (git-ignored).
- **HB1 The Cousins** (T-045, commit 143156c, tag `hb1-wip`) — partly works: the round, three cousins with core moves,
  rewards, toggles, console verbs; extras listed in HOMAGE_BOSSES "HB1 build notes". GUT 546/546, all 21 smokes pass.
- **Morning report:** `morning/MORNING_REPORT.md`.
- Bolt & Sprocket: `delayed_blast.gd` freed-source script error (smoke_nova) fixed (35bdeac).

## In progress

Update 02 (started 2026-10-22 ~05:30). One branch + worktree (`.wt/<branch>`) per section, built in parallel,
merged into master in the brief's order after GUT + smokes pass:
- §1 movement & gunplay feel: `u02-1-feel` (T-046)
- §2 ADS / SightPoint / Thompson / ads_check: `u02-2-ads` (T-047)
- §3 Totenglocke rebuild: `u02-3-totenglocke` (T-048)
- §4 ammo boxes: `u02-4-ammo` (T-049)
- §5 bots (bonus perk, design, command wheel): `u02-5-bots` (T-050)
- §6.1 bigger cellar: `u02-6-cellar` (T-051); §6.2 Jakub after §5 merges
- §7 landscape, sky, distant war: `u02-7-landscape` (T-052)
- §8 polish pass: after §6.1 merges (T-053)

Update 03 (UPDATE_03_BOT_AI.md, arrived mid-run): smarter bots + Jakub on one utility-AI brain. U02 §5 was narrowed
to the parts that survive the rewrite (bonus perk, looks/animations, nameplate, barks, command wheel UI); behaviour
moves to U03. Order: U03 §0/§9 metrics + baseline soak (`u03-0-metrics`, T-054) now → after U02 §5 merges, the
brain rewrite (U03 §1–§8, T-055) → U02 §6.2 Jakub on the new brain.


## BLOCKED
