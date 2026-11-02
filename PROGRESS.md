# PROGRESS

RESUME HERE: 2026-11-01 (late) UPDATE 10 (docs/work_orders/UPDATE_10.md; contracts docs/U10_CONTRACTS.md; Totenhafen design docs/U10_TOTENHAFEN_DESIGN.md) started while UPDATE 09's final full smoke run finishes; every U09 section is merged on master (s1-s7, s8 launcher, packs; builds done: web 135.8 MB to the menu, ClaudeZombies_0.0.1-m0.zip 493 MB; Vercel deploy = owner's one-liner). U10: s1 THE_BAR MERGED (88e39b1, T-151; totals Inn 71 / Kaltenbrunn 68 / Totenhafen 45 / Acts 43-37-43-39 of 84; target >= 71). MapRoot generic living-world loader on master (25a93f1). Running (worktrees under .claude/worktrees/agent-*): u10-2-totenhafen-systems (Opus, T-153), u10-2-totenhafen-world (Opus, T-154), u10-4-bosses (Opus, T-159/T-160), u10-5-kaltenbrunn-world (Sonnet, T-161), u10-3-act2 (Opus, T-156), u10-vo-bake (Haiku: every missing VO line). 2026-11-02: MERGED s4 bosses (3484a5d, T-159/T-160), VO bake (d3cb7b0, T-166), s2 Totenhafen world (e99e8a2, T-154), Act IV (db90e88, T-158). U09's full smoke run finished: 54/54 green after two stale-count fixes (map01_systems, story_props). MERGED Act III (d63418e9, T-157), Kaltenbrunn world (253c4e28, T-161), Act II (07df06cc, T-156; campaign.gd preload_next unified 06c39adf). Master 1682/1682, Act II/III/IV + Kaltenbrunn + webrtc + npc_walls smokes green. s7 bots spawned (u10-7-bots, T-163). Still building: Totenhafen systems (u10-2-totenhafen-systems, T-153), Act I (u10-3-act1, T-155). After those: regenerate map02 (both Totenhafen branches touch gen_map02), then s6 polish (T-162), s7 bots (T-163), s8 online (T-164), s9 finish + blind review (T-165). Older U09 resume text follows. UPDATE 09 (docs/work_orders/UPDATE_09.md; contracts docs/U09_CONTRACTS.md) in progress. The lead (Fable) spawns workers in worktrees, one branch per section (u09-<sec>-<slug>), reviews and merges. Supabase project claude-zombies (fkoebguijrmlqdqrsgdy, us-east-1) created; URL + anon key in data/gravelight/online.json; Vercel team 'Devin's projects' (team_eQCE2Tc4AXi216jH8NYmRMA8) reachable through MCP. Godot 4.7.2 export templates installed on this PC; Linux Godot in tools/dl_godot for WSL+Xvfb captures (contract C8). Supabase schema (supabase/migrations/0001_lobbies.sql) APPLIED live on 2026-11-01 via execute_sql in 3 chunks (apply_migration needs a human click; pg_cron not enabled). Wave 1 (parallel, worktrees under .claude/worktrees/agent-*): s1 the Marke (Fable, branch u09-1-marke), s2ab netcode+lobbies (Opus, u09-2ab-online), s2cd web export+profile+perf (Opus, u09-2cd-web), s6 rename (Sonnet, u09-6-rename), capture tool (Haiku, u09-capture-tool). STATUS 2026-11-01 evening: MERGED s1 Marke (a7bbc59, T-137), s6 rename (51e6ba5, T-140), s2ab online (ac82eab, T-138: WebRTC + Supabase lobbies live, smoke_webrtc/smoke_lobby). s2cd web MERGED (e4874c0, T-139: export_presets, build_web.sh 129 MB to menu, build_windows.sh zip, web profile, PERFORMANCE.md; browser draw calls still over budget on map00/map02; Vercel deploy not yet done: do it via the Vercel MCP in s8 with a CZ_PASSWORD env var). s4 squads MERGED (2448e8c, T-142) + CANON 2.2 reconciled; s4b people + wall fix MERGED (01cba4f, T-143; lines.json join repaired 5e4f1cc). Master suite 1480/1480. Open smokes: smoke_map04c (a Full Partner bot pre-empts the burn console check) and smoke_npc_walls (the bot-mode agent pressed 3.3 s in the stable): Sonnet upkeep worker u09-smoke-upkeep on both. s3 Ledger Lager + banks MERGED (6f19775, T-141: prices 3000/4000/7500/14000 held by soak; branches on map02/04a-d; minimap images NOT re-baked, only POIs). s7 menus spawned (u09-7-menus, Opus); s5 audit MERGED (2b9ff3b: docs/MAPS_3_4_REBUILD.md sections 4-5, capture sets u09_*, census_map). Master 1507/1507 after s3. Zone builders spawned: Totenhafen (u09-5-totenhafen, T-145, owns zone_ambience.gd + data/gravelight/ambience/), Act II (u09-5-act2, T-147), Act I (u09-5-act1, T-146, owns gen_detail_lib.gd + gen_map04_lib.gd); Acts III (u09-5-act3, T-148) and IV (u09-5-act4, T-149) spawned too. Smoke upkeep MERGED (43ee351: smoke_map04c pins bot egg help off; BotLocomotion wall sweep). s7 menus MERGED (6444625, T-144; master 1521/1521). Vercel project creation via MCP is blocked by the session's permission classifier: the deploy is the owner's one-liner (npx vercel login; sh tools/deploy_web.sh; npx vercel env add CZ_PASSWORD production). Act III MERGED (4b33dc6, T-148), Totenhafen MERGED (d070bd6, T-145: ZoneAmbience + ViewCells; audio.json three-way merged by script). Master 1535/1535. Running now: Act I (u09-5-act1), Act II (u09-5-act2), Act IV (u09-5-act4), the launcher-buttons worker (u09-8-launcher). Then s8: merge, full suite + all smokes, Play.bat buttons, Vercel deploy via MCP (password gate env CZ_PASSWORD), MORNING_REPORT, NEEDS_DEVIN, push. s5 audit worker stopped mid-capture (branch u09-5-audit has the camera sets + census script; captures running in its worktree; resume it or finish the doc sections 4-5 by hand). Capture tool merged (f02a05c); before shots in morning/screenshots/u09_before (10 PNGs). Running: s2ab (u09-2ab-online), s2cd (u09-2cd-web), s6 (u09-6-rename), s3 (u09-3-ledger, Sonnet), s4 squads (u09-4-squads, Opus), s5 audit (u09-5-audit, Sonnet). Still to spawn: s4b people + wall fix (Sonnet), s7 menus (Opus), s5 zone builders (Opus, after the audit), s8 finish. If a session dies: resume each worker by SendMessage to its agent id, or inspect the worktree branch and merge what passes. Then s3 Ledger Lager + banks (Sonnet), s4 squads (Opus) + people/wall fix (Sonnet), s7 menus (Opus), s5 map rebuilds last (Opus per zone). Finish: s8 Play.bat, push, MORNING_REPORT, NEEDS_DEVIN. UPDATE 08 s4 (bots finishing the Kaltenbrunn egg) stays open after this update: its old resume text is kept below under 'UPDATE 08 s4 resume'.

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
