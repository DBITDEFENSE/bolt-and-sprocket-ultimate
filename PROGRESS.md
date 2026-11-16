# PROGRESS

LAUNCHER 2026-11-12 (the owner: "create a launcher for the game that pulls the most up to date version from github and installs the dependency needed for any new users"): `launcher/` merged to master 2026-11-12. Electron app: news carousel + patch notes from git + Stable/Preview channels; installs Git for Windows (winget or the official installer), Godot 4.7.2 (checksum-verified), a blob:none clone + LFS pull, a headless --import. Verified: 13 offline checks, a real install from GitHub (5.6 min, 3.6 GB) and a headless boot of the main menu, hidden-window screenshots. News is `launcher/feed.json` on each channel's branch. Docs: launcher/README.md. Installer + portable exe: build/launcher/ (not in git; `cd launcher && npm run dist`).

ZOMBIE OVERHAUL MERGED 2026-11-12 (the owner: "push and merge it to main"): codex/zombie-overhaul is in master (a83f7441) and in this branch: licensed mocap gaits, swipes, deaths and stationary turns, the purchased pack and its 30 clips committed (private repo only), co-op turns, the foot IK order fix. Its own log is docs/ZOMBIE_PROGRESS.md; rules and next steps docs/CLAUDE_FABLE_5_2_ZOMBIE_HANDOFF.md and docs/ZOMBIE_OVERHAUL_PLAN.md. Not finished: models unchanged (2/5), the 24-horde foot-contact gate not met, toes sink into slopes. claude/boss-rework (update 15, maps 1-2, bosses) is still NOT in master.

RESUME HERE: 2026-11-15 T-258 (claude/fps-shadows, merged to master 0a693681 and pushed; smokes map00* (4), bots, bots_shop, bots_u10, ee_bots, coop PASS, bots_shop_m0 'bench' the known intermittent; GUT 2422/2423 + 1 known risky): the owner's low FPS on the RTX 5090 (CPU high, GPU idle). ShadowBudget keeps shadows only on the lamps nearest the camera within the Shadows setting's view budget (dual-paraboloid below Ultra), the individual graphics settings are read back at launch (they never were), physics catch-up capped at 4 steps, Play.bat starts with --render-thread separate (Play.bat safe = old). Map 0 round 15 with the owner's settings: 33 -> 66 FPS (one thread), 92 (separate thread), 88 live. See DECISIONS T-258 for the open points (texture errors in separate-thread mode at map load, other maps unmeasured, the game tick is the next limit). Before that: 2026-11-15 T-255 (claude/u19-fixes: perk spots flush on their walls, Kaethe's drawing, two lanterns per cellar room before the lever, Intel no longer at the origin) and T-257 (claude/gore-rework: GoreFx world blood marks, partial visible gain, see DECISIONS) merged and pushed with the lead's follow-ups (cinema test wait, smoke_jakub without relief squads). Verified on master: check_scripts 960/0, full GUT 2399 tests 2398 passing 1 risky (known), smokes map00* (4), coop, sherman, bots, bots_shop, bots_u10, squads, u19_box, jakub x2 PASS; known intermittents: smoke_bots_shop_m0 'bench', one thread-timing test in test_movement_perf. Then claude/launcher-news merged and pushed: launcher 1.1.0 (five news items with picture galleries, an Upcoming tab of ten proposals in launcher/feed.json; docs/launcher/launcher_news_2026-11.md; npm run check 19/19). The news reaches the existing launcher live from master; the Upcoming tab and galleries need the owner to build and hand out 1.1.0 (cd launcher, npm install, npm run dist). Old merged worker worktrees and local branches were cleaned up; .claude/worktrees/agent-a129bc5e797cc2785 (u10-9-sendback-m4, 23 modified files) was kept for the owner to decide. Before that: T-256 (claude/movement-perf, docs/perf/movement_perf_2026-11.md) merged and pushed: camera/viewmodel springs and pad turn frame-rate independent, zombie tick and spawn/rise/limb spikes cut; check_scripts 955/0, GUT 2383/2382 + 1 risky, smokes bots*, jakub, map00*, coop, sherman, squads PASS; the 16.6 ms worst-frame target is NOT met and GPU FPS is not measured (owner saw 15 FPS at rounds 13-15 while workers loaded the PC; retest with AI brain off/on on a quiet machine). Before that: UPDATE 19 (T-251..T-254, docs/u19/, DECISIONS) merged to master and pushed: Map 0's cellar +75 % (the Lagering Vault behind Door_Lager 750, the Dynamo Room behind Door_Dynamo 1000; the lever and the Crucible in the Dynamo Room, power now 3250 from the taproom), the twelve perk machines dealt onto 17 PerkSpots per match (perk_layout.json, host-seeded); new surface sets, shader variation and the night sky dome (map01/02/04a-d regenerated); the Sherman, dive bomber, sky aircraft, wagon and crate rebuilt; the Requisition Crate's locator column and roll, the Crucible built into its wall by probing. map00 regenerated once with all four in. Verified on master: check_scripts 952/0, full GUT 2366 tests 2365 passing 1 risky (known), smokes map0* (21), bots*, sherman, coop, companion_perks, u19_box, jakub, menus, horse* PASS; smoke_marks FAIL 'an empty spot: collect, go' as before this work. Open for the owner: dive bomber crosses on/off (StukaPlane.CROSSES), Kaltenbrunn brick less red, the look of the new rooms / paint shader / NIGHT_LIFT on a real GPU, the C-47 wreck is black at night, an invisible collider in front of the Crucible (ArtCollider.fit hulls the hidden offer bar), power lights may stay lit when a map loads after a powered one. Before this: UPDATE 18 (T-245..T-250).

## UPDATE 08 s4 resume (deferred behind UPDATE 09)
2026-10-31 T-136 the savings bank merged (Map 0 woodshed Darlehenskasse + Kaltenbrunn pay office, teller Erwin Lassmann, 1% a round, kept in the profile; smoke_bank). Earlier, 2026-10-29 also merged: T-133 smooth motion + graphics settings, T-134 more detailed people models, T-135 one more companion per map (Trudi / Gustl Ammer / Hinnerk Petersen / Jette Maurer; MapCompanion, companions.json, smoke_map_companions). Open from those: frame cost of T-133/T-134 unmeasured on the owner's GPU (play with --frame-log), zombies still move at 60 Hz. Before that: 2026-10-28 UPDATE 08 merged to master EXCEPT section 4 acceptance (work order docs/work_orders/UPDATE_08.md). DONE and merged: s1 baseline (docs/QA_REPORT_U08.md), s2 tier IV perma perks (T-129), s3 bot late kit (T-130), s5 launcher buttons, MORNING_REPORT; s4 partial (T-131): the agent does player-only steps / starts the Heartstorm / starts pylons, Full Partner default picks (Peg), Map 4 power/burn knowledge, Kaltenbrunn plan (egg block, Lab door, surface loop, 3 Crucible teachings), the agent stays on a charging pylon, BotLocomotion fall rescue, soak --until-egg, EGG_DEBUG plan logging. Unit suite 1370/1370; smokes late_kit bots ee_bots botmode jakub map04_egg requiem launcher map01 map01_systems coop vo feel pass. NEXT (s4): iterate EGG_DEBUG=1 sh tools/ai_soak.sh --scenario=botmode --map=map01 --bots=3 --ee=full --god --speed=4 --until-egg --trace=60 (logs .smoke_logs/u08/egg_map01_*.log). Open blockers: in god mode the bot-mode trainer kites 2 straggling crawlers forever (nobody hunts the last zombies; give the trainer a round-end hunt); pylons F/H under x2 spawns; then s4 bell + Foreman in F_CHAPEL, s6 bells, s7 drummer chase, s8b 30 Totenglocke kills, s9 Heartstorm 120 s holdout. Then: honest 5-run Kaltenbrunn acceptance (3/5), Fernflug egg soak (--scenario=fernflug --egg=full), per-map egg smokes, QA report After + MORNING_REPORT update.

## UPDATE 07, 2026-10-26: Map 4 Fernflug + QA pass (DONE, merged to master)

Phase 0 QA: running (T-103 merged; Map 0/Map 1 workers out). Phase 1 design: DONE. Phase 2: Acts I–IV MERGED (T-104, T-108/T-109, T-110/T-111, T-112/T-113), perks+Lodestone MERGED (T-105), egg Acts I–II MERGED (T-114), boarding, Act 2, crash, Act 3, rocket, Act 4, perks/wonder/egg/endings (pending). Finish: pending.

## Overnight run, 2026-10-25 -> 26: UPDATE 05 "Look the part" (plan)

Work orders (original folder, read-only): UPDATE_05A_ASSET_INTAKE.md, UPDATE_05_ART_SLICE.md, OVERNIGHT_RUN.md. Rendered off-screen runs are approved for this update.

Phase 1 (parallel): T-087 asset intake (OGA guns + Devin's Sketchfab guns -> assets/third_party, models.json, ASSETS.md + credits generated from SOURCE.txt, license gate) and T-088 pipeline (ART_BIBLE.md, CC0 material library + shared material templates, CC0 props, import presets, asset_report, 20-camera capture + BEFORE shots, NEEDS_DEVIN.md).
Phase 2 (parallel): T-089 viewmodel guns (normalize, shared weapon shader, markers, ads_check, animation fit, per-character arms), T-090 wonder weapons + gramophone, T-091 zombies, T-092 people, T-093 Map 0 environment, T-094 world objects, T-095 VFX, T-096 UI readability.
Phase 3: full suite, ads_check, map-data check, asset report, FPS check, clip, Play.bat buttons, morning report, rollout plan.

Status: T-087 intake MERGED (3029025; 16 guns in assets/third_party, models.json, license gate). T-088 pipeline MERGED (ART_BIBLE, MaterialLibrary/PropLibrary, 28-cam capture, BEFORE shots in morning/screenshots/u05/before). Phase 2a started: T-089 guns (.wt/u05-guns), T-095 VFX (.wt/u05-vfx), T-096 UI (.wt/u05-ui). Phase 2b: T-093 environment MERGED, T-094 world objects MERGED, T-091 zombies MERGED; running: T-094 world objects (.wt/u05-worldobjects), T-091 zombies (.wt/u05-zombies). T-090 wonder weapons MERGED. T-092 people MERGED. Phase 2 complete; phase 3 (full suite, after capture, FPS, morning report) running.


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

**Update 02 (2026-10-22):** §1 feel (T-046) works · §2 ADS (T-047) works, 44/44 guns aligned · §3 Totenglocke (T-048)
works · §4 ammo boxes (T-049) works, 10 boxes on 3 maps (+1 in the Old Cellar) · §5 bots (T-050) partly: bonus perk,
looks, nameplates, barks, command wheel work; behaviour moved to U03 · §6.1 Old Cellar (T-051) works · §7 living
world (T-052) works · §8 polish (T-053) works. U03 §0/§9 metrics + baseline (T-054) works. Campaign carry fix for
bot bonus perks (d22d640). GUT 651/651, every smoke passes.

**Update 02 §6.2 + Update 03 (2026-10-22):** Jakub (T-051) works · U03 locomotion (T-056) works · U03 brain (T-055)
works · U03 tuning (T-058) partly: bots alone reach round 10 (best 16), target 20–25; revives 96 % with a realistic
player, 78 % with the do-nothing one · U02 follow-up fixes (T-057) · deflake (T-059). Final: GUT 729/729, all 27
smokes pass, ads_check 44/44.

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

## In progress (none: Update 02 + 03 done)

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


## Known flaky tests (Update 02/03)
- Fixed in T-059: smoke_bot_loco "stuck" (a real ladder bug), smoke_vo TEAM_DOWN (a real speaker bug), smoke_m2
  Panzerschreck (timing under load).
- smoke_map02 failed once after the U03 brain merge (the squad left the Foreman alive for 420 s at round 33);
  passed on rerun; handed to the U03 tuning pass.

## BLOCKED
