# Roadmap

Each milestone ends with: tests passing headless, the game launched and played, a short summary for review (what works, how to test it, known issues), and a git tag `m<N>`. After M0 the project **pauses for review**. After that it goes milestone to milestone.

| # | Milestone | Status |
|---|---|---|
| M0 | Port inventory, bible, skeleton | done (tag m0) |
| M1 | Shared core + Bolt vertical slice (Scrapheap Junction) | done (tag m1); gaps listed in T-023 |
| M2 | Gravelight vertical slice (migration of the built GRAVELIGHT project + §11 on Map 0) | done (tag m2): cellar + 8 machines, lore, slips, playtest fixes (T-024..T-028) |
| M3 | Full B&S arsenal + Acts 1–2 (Rustvane, Nova Plaza) | **partway (WIP, not tagged)**: see "M3 status" below |
| M4 | B&S complete campaign | |
| M5 | Gravelight Map 1 Kaltenbrunn (with §11) | Map 2 Totenhafen first playable (T-036): zones, tide set-piece, campaign arrival at round 31; Ballast carry and the Kielholer deferred |
| M6 | B&S side modes & extras | |
| M7 | The Fine Print Ch. 1–4 | |
| M8 | Helvetia Works + finale | |
| **M8.5** | **MORGENROT, the Gravelight finale** (v2): the full map, Treibstoff-Gänger / Frostbiss / Bergwacht / LUFTALARM Fallers / Der Startmeister / Reinholt "Wiederkehr", Die Lange Nacht, the Launch Clock, "Letztes Licht", "Mondfahrt", the three ending cutscenes + Aftermath, all VO, 10 Archive entries. Design docs done: `docs/MAP3_MORGENROT.md`, `CUTSCENES_MORGENROT.md`, `ART_FACTIONS.md`. Acceptance: power-on through either ending in solo with dev skips, and a full un-skipped Relaxed run. | design done, paused for review |
| **MZ** | **Zombie animation & design upgrade** (v2 §7; `docs/ZOMBIE_ANIM_SPEC.md`): shared humanoid skeleton + retargeting, AnimationTree with root motion, per-instance variation and posture traits, foot IK / look-at, barricade / climb / attack sets, flinches / stagger / knockdown / 8+ deaths into ragdoll, dismemberment with a gore setting, outfit kits per map and the infection shader, animation LOD; retrofits every map. **Goes before M8.5** (as early as the schedule allows). Acceptance: the §7.7 side-by-side capture, no foot-sliding, 24 zombies at 60 FPS. | spec done, paused for review |
| M9 | Unified front end & meta | |
| M10 | Art/audio pass & polish | |
| M11 | (stretch) Online co-op | |
| — | **MONDLICHT** (the Moon-ending hook): outline only, never built in this plan. The Moon has a smile and something on it blinked back; the Operator calls it a new market. | hook |

**Gravelight campaign chain (T-033, 2026-10-21):** Map 0 → Map 1 → Map 2 linked by exfil beacons at rounds 10 and 30 with full carry-over (weapons, ammo, upgrades, Scrip, perks, rounds) and in-engine transition cutscenes; the third map falls back to a "campaign continues" screen until its scene lands.

---

## M0: Port inventory & bible
**Acceptance**
- The extraction tool dumps every original table to `/data/bs_source/`.
- Every written line is ported to `/data/bs/story/` with VO line IDs, losslessly.
- All M0 docs are written in full: BS_PORT_INVENTORY, CANON, TIMELINE, GDD, BS_WEAPONS, BS_ENEMIES, BS_LEVELS, FINEPRINT_LORE, FINEPRINT_SCRIPT, JINGLES, STORY_CHANGES, ASSETS, DECISIONS, ROADMAP, plus the Gravelight docs with §11 applied.
- The Godot skeleton, autoloads, git repo and tests are in place.
- The HUMOR-REVIEW yes/no list is presented.

**Done:**
- 134 tables extracted.
- 494 lines indexed (all 707 source strings verified present), plus 5 new memos and new lines.
- Skeleton with core autoloads; 12 GUT tests passing.

## M1: Shared core + Bolt vertical slice
**Scope**
- **Shared core (`/core`):**
  - damage model: hitboxes, weak points, damage types kinetic/energy/fire/frost/shock/legal/void, the status effects, knockback, hitstop
  - weapon framework: WeaponData resources; hitscan, projectile, beam, deployable and thrown archetypes; V-level pipeline; mods
  - enemy AI framework: NavigationAgent3D, data-driven state machines, archetypes, AI LOD, pooling
  - interaction system, input remapping with full controller support, aim assist with per-device stickiness, subtitles, the dev console with every listed cheat
- **`ThirdPersonController` at parity with the web build:**
  - every `CONFIG.move/jump/hover/wall/dashJump/slamBounce/dash/slam/slide/melee/cam/AIM_ASSIST` value ported as the starting tuning
  - a side-by-side feel checklist signed off: jump arc, dash distance, slam timing, combo windows, hitstop
  - then the camera SpringArm and soft lock-on
- **Melee:** the 3-hit mallet string with hitstop, plus mallet throw. Throw → boomerang can come in M1 or M3.
- **Sprocket:** body, four moods, barks wired from `data/bs/story/barks.json`.
- **Weapons:** the weapon wheel; OMNI-BLASTER plus 3 more redesigned weapons with V-levels.
- **The full Scrapheap Junction remake:**
  - the garage prologue
  - Rusty's Row (Mama Gasket, Rusty's quests), the Billing Mast, the Conveyor Works, the Teleporter Yard
  - Exit Yard and REPO-TRON
- **Also:** the Blartz shop (v2 tabs, deal of the day, wishlist, trade-in, celebration), saving, TTS voices with subtitles.

**Acceptance:** intro through Repo-Tron is playable and feels as good as or better than the web build (checked side by side).

## M2: Gravelight vertical slice
**Scope**
- Move the GRAVELIGHT project's code into `/gravelight` (scripted `res://` path rewrite) and merge its autoloads into `/core` (DECISIONS T-007, T-008).
- `FirstPersonController` on the shared core.
- Map 0 Crossroads Inn already has rounds, barricades, Scrip, wall-buys, doors, crate, power-ups, the radio quest and Operator lines. Add or verify all 8 perk machines in the cellar (behind a 1500 door) with §11 backstories, readable fine-print panels on their backs, and hidden plan-ID stencils.
- Operator corporate slips.
- The settings merge.

**Acceptance:** round 15 on Map 0 feels tense and fair, and the existing GRAVELIGHT QA suite passes inside the new project.

## M3 status (paused 2026-10-20, committed as "M3 WIP", not tagged)
**Verified at the pause:**
- 349 scripts compile.
- 404 tests pass.
- These smokes all pass: Scrapheap, Rustvane, Nova, bosses, arsenal, and GRAVELIGHT Map 0.

**Finished:**
- **All 16 weapons**, each with V1–V5, alt-fire, Ω and both Signature Mods (`bs/weapons/guns/`, `data/bs/weapons.json`). Shared hit rules include the Super Sprocket ×2.
- **Omega Forge:** station, UI, and `ForgeDebug` helpers (`bs/forge/`, `ui/bs/forge_ui.gd`). Locked until `blartzRescue` (M4); not placed in any level yet.
- **Enemies:** 4 Rustvane enemies, plus 4 Nova Plaza enemies and the Zoning Board.
- **Bosses:** Rustvane Sentinel, The Content Creator, The Algorithm (on `PatternBoss`).
- **Rustvane Canyon** is complete and playable: the Tether-Hook and gadget framework, the GLAMBOT defection, the shield reveal on the Return Relay, and both boss arenas.
- **Nova Plaza** is complete and playable: HOA Compliance Eyes, moving walkways, the Permit Office, the Transit Loop, and The Algorithm in FineTree Plaza.
- **Lead work:**
  - Super Sprocket's Bulwark and Zip modes
  - per-planet splash quips
  - a minimal star map: Scrapheap → Rustvane → Nova Plaza travel, unlocked by clearing the previous planet
  - all new line files are voiced

**Left to finish M3:**
1. **Lead integration:**
   - Public `CutscenePlayer.play_steps` (B and C call its internal `_start`).
   - `GadgetManager.attach_to(bolt)` from `BSLevel`, for all planets.
   - Dev-console commands for `ForgeDebug`.
   - Weapon ad vignettes on `WeaponManager.first_equip`.
   - Unify the `blartzRescue` / `blartzRescued` flag between `shop.json` and weapons/forge.
   - Speakers `middleman_a`, `middleman_b`, `statue`.
   - `BoltMotor` reading the `bs_move_mult` meta (Clearance Rack).
   - HUD stamps for slowed / clamped / blinded.
   - Boss music: there's no B&S music system yet; bosses emit `music:push`/`music:pop` beats.
2. **Cross-builder fixes:**
   - The Algorithm reverses every walkway on the level; it should filter to its arena.
   - `delayed_blast.gd` uses a freed source after a boss dies (one script error).
   - Mallet and Sprocket damage don't apply the gun-only hit rules: MARKED, TERMS APPLY, Braces, armour markdown.
   - Enemies don't read `silenced`, `acquired`, `marked` or plates (`pop_plate`, `plate_pierce`).
   - `marked_down_stacks` meta handoff between weapons and enemies.
3. **Review:**
   - Rendered screenshot tour of Rustvane: built but not yet looked at.
   - Bot or human playtest of both planets end to end.
   - Fix `BS_LEVELS` §3.10: the Sentinel fights on the Quarry Floor.
   - Then tag `m3`.

**How to resume:** read `docs/M3_CONTRACTS.md` and this list, then work through items 1–3. The builders' full reports are summarised in DECISIONS T-030.

## M4 status (in progress)
- **Verdant Sink (T-039)** is the first M4 planet built and playable end to end: the Sprocket Glide, murk pools and bounce mushrooms, the four Verdant enemies and the neutral Picket Corn, the Compost King with the mercy ending, all six story beats, q7a/q7b, the Picket Line pop-up. 26 unit tests, `smoke_verdant` passes. Open follow-ups are listed in DECISIONS T-039.
- Still to build: Glacius Vault (Grind Soles), the Grand Galleria, Core Foundry, the ending.

## M3: Full B&S arsenal + Act 1–2
All 16 weapons with V1–V5, mods and Signature Mods. Rustvane Canyon complete (Sentinel, Content Creator, GLAMBOT defection, Tether-Hook). The shield reveal. Nova Plaza complete (The Algorithm). The Omega Forge built and testable through the dev console.

## M4: B&S complete campaign
Glacius (Grind Soles), Verdant (Glide), the Grand Galleria (TONIQ™ dispenser), and Core Foundry in full: the Blartz rescue and Omega Forge unlock, the Holding Block schematic scene, Clause 44, the Grindstone finale. Then the ending, memo epilogue and post-credits; all side quests and all 40 memos; flyovers, star map, space travel, the cutscene gallery, all 17 ad vignettes.

## M5: Gravelight Map 1 Kaltenbrunn
Already built in GRAVELIGHT (M3–M4 there). This milestone verifies it after the migration and adds §11: the Crucible plaque, the stencils lit by muzzle flash, Operator slips, Reinholt's "Woman in Violet" recordings, Wren's Hawkeye Brandy VO, and the new perk backstories in-world.

## M6: B&S side modes & extras
ZONGA™ (rarity tiers, sponsor drops, smarter bots), the GLAMBOT Colosseum (all 8 challenge types; Boss Rush with every boss), OMNIGRAND PRIX™ with RUSTVANE SKYWAY, LOOP RIOT™ in full, the Firing Range, Photo Mode, NG+, cosmetics, trophies.

## M7: The Fine Print Ch. 1–4
The Retention Spire, Field Unit (VendelinController with stealth), the Helvetia vignettes (cabinet build puzzles, human scenes, the pump-organ jingle composer), the Patent Pending heist, THE QUARTERLY.

## M8: Helvetia Works + finale
The full crossover map. Bolt and Vendelin as first-person characters. Audit Rounds and Repossessors, the Underwriter, THE RETURN POLICY and its upgrade "No Questions Asked," the Field-Kit OMNI-BLASTER buildable, the Original Omega Forge second tier, the Anomalous Inventory crate pool, the "Clause Zero" egg, the ending and its rewards.

## M9: Unified front end & meta
The hub (Blartz's shop at night), the unlock flow, the one save profile, Archive cross-linking, cross-rewards, Gravelight rank/prestige/dossiers/mastery inside the shared profile, the full settings menu, controller polish.

## M10: Art/audio pass & polish
Sourced CC0 assets per `ASSETS.md`; per-world art direction; VFX; the audio mix; optimization (60+ FPS mid-range, 24 zombies); a bug bash.

## M11 (stretch): Online co-op
Gravelight and Helvetia Works for 1–4 players. Their authority logic is already kept separate from presentation. 2-player Colosseum.
