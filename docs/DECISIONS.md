# Decisions log

Judgment calls made without asking. Newest at the bottom.

Format: **ID, date: decision.** Why. *(Revisit if: ...)*

The GRAVELIGHT project's own log (D-001 … D-059, at `C:\Users\Devin\PROJECTS\New folder\docs\DECISIONS.md`) still applies to the Gravelight module. Entries here are numbered **T-###** so the two series never collide.

**T-001, 2026-10-19: Engine is Godot 4.7.2 stable, Forward+, GDScript with static typing.** This is the newest stable 4.x and the same build the GRAVELIGHT project is verified on. The portable binary lives in the git-ignored `tools/dl_godot/`, and `run_tests.sh` runs GUT 9.6.1 (MIT, `addons/gut`) headless.

**T-002, 2026-10-19: Data extraction uses acorn plus a static evaluator, not regex.**
- `tools/extract_bs.mjs` parses the `<script type="module">` block and evaluates literal initialisers: objects, arrays, template strings, arithmetic, spreads, and references between tables.
- Nested tables are collected too (the Loop Riot tables are declared inside their mode function).
- Functions become `{__fn__, __src__}` stubs, and references to code become `{__ref__}` / `{__call__}` / `{__expr__}`.
- Result: 134 tables. The only tables it skips are Three.js runtime objects (renderer, scene, lights, vectors).

**T-003, 2026-10-19: Every ported line gets a stable VO line ID, and the port is verified lossless.**
- `tools/port_story.mjs` assigns IDs: `cs.<cutscene>.<nn>`, `st.<beat>.<nn>`, `q.<quest>.<phase>.<nn>`, `memo.<nn>`, `bark.<cat>.<nn>`, and so on.
- It writes `data/bs/story/lines_index.json` for the VOManager.
- A check confirmed that all 707 text strings in the source story tables are present in the port.

**T-004, 2026-10-19: Duplicate quest IDs fixed.** The web build reuses `q6a`/`q6b` (Grand Galleria *and* Verdant Sink) and `q3b` (twice on Core Foundry, planet index 2), so saved progress for those quests collided. The remake IDs are `q9a`/`q9b` (Galleria), `q7a`/`q7b` (Verdant), and `q3c` ("Art Criticism"). The original ID is kept as `source_id`.

**T-005, 2026-10-19: Galleria continuity.** The Grand Galleria stays playable during the core hunt, as in the source (`CAMPAIGN = [0,1,5,6,7,9,2]`, `planetLocked()`). The one line that implied it came after the Foundry is reworded (`cs.galleriaLedger.02`: "tries that clause **again**" → "**on you**"). This is the smallest change that fixes the continuity, and it turns the line into foreshadowing. Logged in STORY_CHANGES.

**T-006, 2026-10-19: The Return Trip resolves a timeline conflict.**
- **The conflict:** the brief puts Helvetia Works on "the night after the Gravelight Map 1 ending" *and* in "Basel, March 1945." The existing Gravelight canon puts the crash on 23 Dec 1944 and Map 2 in January 1945, and Kaltenbrunn to Basel is roughly 1,000 km.
- **The resolution:** the collapsing heart at the end of Map 1 opens a fold that drops the squad in Basel on **17–18 March 1945**. When Vendelin cuts the fold, it "returns its contents to sender," putting the squad back in **late December 1944**.
- **Effect:** both brief anchors hold, Maps 2 and 3 keep their dates, and the squad never learns the corporate truth (they remember a fever dream). Next-Era Delivery™ ignoring chronology is already canon, so the mechanism is in-world.
- *(Revisit if: you'd rather move Helvetia Works to January 1945.)*

**T-007, 2026-10-19: Gravelight is brought in from the existing GRAVELIGHT project, not rebuilt.**
- Appendix A describes Gravelight from scratch, but its M0–M6 scope is already built, tested and playable at `C:\Users\Devin\PROJECTS\New folder`. That covers Maps 0–1, the egg, progression, menus, and the art/audio pass.
- Its design docs are copied into `docs/gravelight/` and amended there per §11.
- In M2, its code moves into `/gravelight` and its autoloads merge into `/core` (path rewrite by script). That makes the brief's M2 Gravelight slice a migration plus the §11 features, rather than a rebuild.
- *(Revisit if: you want the two projects kept separate.)*

**T-008, 2026-10-19: Core autoload names match the GRAVELIGHT project's** (`EventBus`, `Data`, `Settings`, `VOManager`). In M2 the Gravelight versions merge into these instead of colliding.

**T-009, 2026-10-19: Voice is placeholder TTS with the original voice profiles.**
- `core/vo_manager.gd` looks up a line ID and always emits a subtitle.
- It then plays `res://audio/vo/<id>.ogg` if one exists, otherwise `DisplayServer.tts_speak` with the speaker's pitch, rate and preferred-voice keywords from `VOICE_PROFILES` (NPCs share the generic `npc0–3` profiles, as in `NPC_VOICE`).
- It is silent in headless runs, so tests and CI never make a sound.

**T-010, 2026-10-19: Settings keep the original web build's key names and defaults** (`mouseSens`, `stickPad`, `shakeMul`, `voiceOn`…). Gravelight and shared settings are added alongside them. `shakeMul` is the one shake setting for every mode.

**T-011, 2026-10-19: Locked numbers for the crossover canon** (all in `M0_SHARED_FACTS.md`):
- Blartz patent / PATENT PENDING serial: **BLZ-40417**
- Probe ID: **TM-SOL3-001**, landing on 9 Nov 1938
- Vendelin's serial: **DMS-FMU-V1-0001**
- Vitality Plan IDs: **DMS-VP-xxx-nn**
- Vendelin's last transmission: **18 Mar 1945, 03:12**

**T-012, 2026-10-19: The five new memos (36–40) are placed thematically:** 36 Sol-3 on Glacius, 37 Forge schematic in the Foundry, 38 "Nobody Cancels" in Nova Plaza, 39 Next-Era Delivery in Verdant Sink, 40 "the vending robot" in the Galleria beside the TONIQ™ dispenser. Memo 37 is also the "new memo" that shows the schematic confiscation (§10.3.2).

**T-013, 2026-10-19: Unlock rules are data** (`data/unlocks.json`) resolved by a pure function (`core/unlocks.gd`). The brief's flow is unit-tested, including "Ch. 2–3 open on the Map 1 egg OR round 20 on Map 1."

**T-014, 2026-10-19: Nothing that opens a window runs while the user is playing.** All automated Godot runs are headless: no window, no audio (GRAVELIGHT D-058, made stricter). Rendered screenshot checks wait until the user says they've stopped playing.

**T-015, 2026-10-19: The M0 docs were written by parallel writers against one fact sheet** (`docs/M0_SHARED_FACTS.md`). Each writer owned separate files. The lead reconciled their decisions into this log and STORY_CHANGES.

**T-016, 2026-10-19: Text spoken from code is ported too.**
- About 309 player-facing lines live in function calls rather than tables: boss barks, banners, hints, the Zonga announcer, shop pitches, signs, Loop Riot taglines. `tools/extract_code_lines.mjs` extracts them to `data/bs/story/code_lines.json` with IDs `code.<function>.<nn>` and source line numbers.
- 197 pieces of menu, lobby and credits copy come from the HTML (`tools/extract_html_text.py` → `html.<screen>.<nnn>`).
- Both are merged into `lines_index.json`, which now holds 1,000 entries.
- BS_ENEMIES' proposed `bs.boss.*.orig.*` IDs were replaced with the real `code.*` IDs.

**T-017, 2026-10-19: B&S arsenal and enemy design calls (from BS_WEAPONS.md / BS_ENEMIES.md):**
- **Use-XP:** V2 600 / V3 1,800 / V4 4,000 / V5 8,000.
- **Signature Mod:** unlocks at V3 for 200 bolts and can be swapped free. Omega needs a Signature Mod too: 840 in mods + 200 + 2,000 = 3,040 bolts per gun.
- **V-levels vs mods:** the original damage-tier-3 behaviours move to V-levels; mods are stat-only. The Blaster's ammo slot becomes Heat Sink.
- **Mallets** have no XP and no Omega. The Riot Mallet comes from winning Loop Riot's Unrecalled league.
- **New gun prices:** Late Fee 280, The Fine Print 300, Hostile Takeover 340, Clearance Rack 360. Trade-in is 60%.
- **Inputs:** alt-fire is LB/V. A tap of RB/Q quick-swaps; holding it opens the wheel at 30% time.
- **Elites:** ×1.8 HP and ×1.5 drops. They're 25% of NG+ spawns.
- **Combat pacing:** fast source telegraphs raised to 0.4–0.8 s. Attack tokens allow at most 2 melee attackers and 3 ranged shot starts per second.
- **Rustvane Sentinel:** the source has no separate Sentinel (the `miniboss` tank is labelled THE CONTENT CREATOR but its banner says "The Sentinel sheds its armor!"). The remake splits it: the Sentinel is a 300 HP tank mini-boss, and the Content Creator keeps 420 HP plus its camera drones.
- **Compost King's mercy ending** didn't exist in the source; his plea always failed. The remake adds it: during an 8 s plea, seal all 3 leaks, holster, shake hands.
- **"Grindstone 2.0"** becomes phase 3 ("public beta"), so `cs.ending.01` still works unchanged.
- **Five v9 enemy behaviour flags** that were never coded (surge, freeze, cloak, burrow, buffer) are now designed. So is Middleman aggro, which the shop promised but never implemented.
- **Boss Rush** has all 8 bosses; Compost King's mercy path is unavailable there.

**T-018, 2026-10-19: Text coverage is audited, not assumed.** `tools/audit_text_coverage.mjs` lists every sentence-like string literal in the original script (770) that isn't in a ported file or a raw table. `--emit` writes the remainder to `data/bs/story/code_misc.json` (`misc.<function>.<nn>`): shop descriptions, mission-tracker text, annex signs, Omega descriptions. Coverage is 770/770, and denizen barks (`spawnDenizen`) are now extracted too. Re-run the audit whenever the extractors change.

**T-019, 2026-10-19: B&S level and inventory calls (BS_LEVELS.md / BS_PORT_INVENTORY.md):**
- **Post-credits** always plays after the ending (the source gated it on 35/35 memos), because The Fine Print needs it.
- **The memo epilogue** still triggers on the 35 originals, so "Thirty-five internal memos" stays true. Memos 36–40 sit in a separate "DO NOT DISCUSS" folder, each behind a gadget.
- **Flyovers:** on first landing, the flyover plays and then the arrival scene, back to back. New camera-only flyovers for the Foundry and Galleria use the `arrive2`/`arrive9` lines.
- **Rustvane mini-bosses:** the Content Creator survives its fight, demonetized. The "co-host" it says Bolt deleted is the Sentinel, fought first on the same Sunset Stage.
- **Traversal:** golden ride-rails stay usable from the start. Grind Soles add frost-striped pipes with manual speed and Loop Riot trick names. The boomerang throw is available from the start. Magma and Thunder mallet throws are extra backtracking keys.
- **Gadget sources:** Rustvane's Co-op winch, Glacius's Premium Tier concierge, Verdant's Local 404 union hall.
- **The Galleria stays optional** (as in the source). It's flagged from the first core, and its main path needs only the Tether-Hook.
- **The Blartz rescue is on the critical path:** the Holding Block console lifts the Crusher Corridor lockdown.
- **Compost King:** completing quest `q7b` pre-seals one of his three leaks.
- **The Algorithm** can be overloaded with canisters printed by complaint kiosks or by bat-backs, since Nova may be the first core.
- **Ice friction:** outdoor 72% cut (the source value), indoor 36%, rubber mats 0%. Blizzards only blow outdoors.
- **Scrapheap's ship** is wheel-clamped until REPO-TRON falls.
- **Gold bolts:** 30 in total (Scrapheap 5, Foundry 5, 4 everywhere else). Each planet saves at a Save Beacon on the pad.
- **8 source bugs** are listed in BS_PORT_INVENTORY §28.3 and fixed in the remake (e.g. the "/ 9" gold-bolt counter, `introAlgorithm`/`introCompost` never playing, frame-rate-dependent murk drag).

**T-020, 2026-10-19: Fine Print canon calls (FINEPRINT_LORE.md and the chapter scripts).**
*Origins and the mine:*
- **The probe** was delivered into solid salt that flowed shut, so the void looked ancient. The pre-1938 "black salt" folklore is the fold's wake arriving early, and its meaning is left open.
- **11 Nov 1938:** Pilch and Hasse die in Gallery 7, and Pilch is the first retained miner. **2 Mar 1939:** the Amt seizes the mine. Both move from older LORE dates that came before the landing.
- **Florian Kubitza** names him "Viktor Wendelin," and V-1 respells it with a V. Florian's grey loden coat is the borrowed coat.

*Helvetia:*
- **Imhof & Cie. (1921)** was bought and re-founded by Vendelin as Helvetia Automaten AG in Feb 1940, with Konrad Imhof as nominal President, so existing Gravelight "since 1921" lines still hold.
- **Vignette dates:** Ironhide 3/41, Second Wind 1/42, Trigger 5/42, Twin Barrel 8/42, Marathon 11/42, Hawkeye 4/43, Packmule 7/43, Blastproof 10/43, Fernet 3/44, Overclock 4/44 (blueprint).
- **Darkmatter re-contacts V-1 on 9 Feb 1943** (status LOST → INVENTORY). The **Ledger installation is 14 Sep 1944**; from Mar 1942, Opitz's mechanical splice-reader was "the Operator." The Interface picks Marchbank's voice.
- **The Crucible drawings** arrive finished in 1944 in a "Kühlanlage" crate, and Fasbender signs them (this reconciles LORE's "Fasbender designed it").
- **The Woman in Violet's product** is RECURRING™ Bereavement Continuity (DMS-BC-01). The barge is FB-7 *Standing Order*. The Patent Vault sits in a sealed fold called "Escrow."
- **The true jingles are wordless first drafts** hidden in the harmonium bench. Overclock's can't resolve until after Ch. 5 (the organ's cracked F-sharp reed) — a deliberate exception.

*Ch. 1 and Ch. 4 gameplay:*
- **Terms Doors** offer ACCEPT / DECLINE / READ. The Exit Survey rule: any answer implying leaving is wrong. Ch. 4's gadget is THE LOOPHOLE.
- **THE QUARTERLY** (Sable Vantage's mech): the health bar is the DMS share price, with Q2–Q4 starting at 75/50/25%. In Q3 she acquires your most-used weapon (PATENT PENDING exempt). If the Q4 clock runs out she renews to 40%, the clock lengthens after two renewals so the fight can't stall, and the killing blow is the mallet.

*Ch. 5 finale:*
- **The finale's clock is the 03:12 transmission time** ("close of business"). The loophole is Clause 0.2: undeliverable inventory returns to sender, "inventory only." Vendelin's override makes him not inventory, so he stays and everything else the fold carried goes home.
- Vendelin's new directive: **"REFUND. RELEASE. REMAIN."** Peg pockets his serial tag.
- Nobody on Helvetia Works says "subscription" — not even Bolt (his near-misses are a running gag). Sable is subtitled THE WOMAN IN VIOLET. On Gravelight maps Super Sprocket uses new `gl.all.sprocket.super.*` lines, because B&S `super.02` contains "subscription."
- **The transmission is reconciled:** Ch. 1 recovers the long Report No. 207 plus a corrupted 03:12 addendum (`fp.c1.transmission.30–31`, "Do not send anyone else"), and Ch. 5 broadcasts the addendum in full (`fp.c5.finale.81–83`). `fp.doc.29` matches both.

*Speaker IDs:* the Board speaks as `darkmatter` (shared with `cs.postCredits`). New IDs: `courtesy`, `dm_pa`, `nextera`, `middleman_a`, `middleman_b`, `statue`.

**T-021, 2026-10-20: Input changes from the web build.**
- **E is interact only.** The original overloaded it as next-weapon when nothing interactable was in reach, and that clashed with the shop kiosk.
- **Alt-fire** is X, middle mouse, or pad LB.
- **Pad weapon cycling** moves to D-pad left/right, plus an RB tap (holding RB opens the wheel).
- **Keyboard weapon cycling:** Q, the mouse wheel, the number keys, and Tab (tap = last weapon, hold = wheel).

**T-022, 2026-10-20: M1 was built by four parallel builders against `docs/M1_CONTRACTS.md`, then integrated by the lead.**
- **Weapons:** the framework and 4 guns, with the other 12 as archetype placeholders.
- **Enemies:** the AI framework, 4 enemies plus a crate, and REPO-TRON.
- **Level:** Scrapheap Junction, built from data through LevelDirector.
- **UI/systems:** BSLevel, Sprocket with Super Protocol, HUD, cutscenes, shop v2, dev console, pause.
- **Integration fixes:**
  - VOManager voices every line file (`LINE_SOURCES`).
  - Bolt has a Status node.
  - The summary screen reads the planet's `gold_total`.
  - Enemy shots gained `deny()`.
- **Respawn fix:** respawning no longer leaves stale air/melee state.

**T-023, 2026-10-20: Known M1 gaps carried to M3:**
- Super Sprocket's Bulwark and Zip modes are chosen and announced but run as Overclock.
- Rails and the three gadgets are markers only; Scrapheap's main path doesn't need them.
- Bolt picks splash quips from all six rather than the planet's own pool.
- Boss music push/pop has no music system to call yet (the procedural score port is still to do).

**T-024, 2026-10-20: GRAVELIGHT migration (M2 step 1).**
- **How it was moved:** `tools/migrate_gravelight.py` copies the built GRAVELIGHT project into `gravelight/<dir>/`, with its data in `data/gravelight/`, and rewrites all `res://` paths. The source folder is only read, never modified, and the script can be re-run.
- **Renamed autoloads:** the five that collide with the shared core are renamed inside Gravelight code only: EventBus→GLBus, Data→GLData, Settings→GLSettings, VOManager→GLVO, DevConsole→GLConsole. Their signal signatures differ from the core's, so unifying them is M9 work, not a blind merge.
- **Separate save files:** Gravelight saves to `user://gravelight_profile.json` and `user://gravelight_settings.cfg`.
- **Mode gating:** Gravelight's input bindings, screen overlays (colorblind, film grain) and environment presets apply only while Gravelight is active.
  - Its menu and map root call `GLSettings.activate()` and `Game.set_mode(GRAVELIGHT)`.
  - BSLevel deactivates them and re-applies the B&S bindings.
- **Hub:** the GRAVELIGHT door opens Gravelight's own menu.
- **Verification:** 252 scripts compile, 259 GUT tests pass (B&S and Gravelight), the Scrapheap smoke passes, and Map 0 renders correctly.

**T-025, 2026-10-20: Front-end menus and shared settings.**
- **The bug:** clicking GRAVELIGHT appeared to crash the game. GRAVELIGHT's menu had a **Quit** button wired to `get_tree().quit()`, which closed the whole merged game. A carried-over or second click could hit it, and the window vanished with nothing in the log.
- **The fix:**
  - That button is now "Back to Terms & Conditions".
  - Both menus ignore clicks for about 0.35 s after they appear.
  - Both changes are migration patches, so a re-migration keeps them.
- **The hub was rebuilt** from `data/hub.json`:
  - door list on the left, preview card on the right, drifting contract fine print behind it
  - an "ACCEPTED" stamp when a door is chosen
  - lock states, and full mouse, keyboard and pad support
- **New shared Settings screen** (`ui/settings_menu.gd`), built from `data/settings_page.json`:
  - The rows come from the web build's SETTINGS_DEF, keeping its labels.
  - Its Fullscreen action became a Display Mode cycle.
  - New rows: V-Sync, frame cap, Gravelight FOV, TTS voices, subtitles, colorblind filter, film grain, hint mode.
  - It opens from the hub and from the Bolt & Sprocket pause menu (the original's pause SETTINGS button).
- **Core Settings changes:**
  - Changes apply live: audio buses, window mode, V-Sync, frame cap, quality.
  - The keys Gravelight also stores are mirrored to GLSettings, and read back from it when the screen opens.
- **Display safety:** window mode is never applied for headless or `--position` (off-screen tool) runs.
- **New display defaults:** borderless fullscreen, V-Sync on.

**T-026, 2026-10-20: Fixes from the Map 0 playtest to round 10** (full review in `docs/PLAYTEST_GL_MAP0.md`). The playtest bot, `tools_src/playtest_gl.gd`, plays through the real Player's input actions.

**The migration is now one-way.** `gravelight/` is edited in place from here on, and `tools/migrate_gravelight.py` refuses to re-run without `--force`.

Fixes:
1. **Zombie melee needs a clear line to the target,** world and door geometry trimmed 0.35 m at each end (`Zombie._clear_to`). Bellringers were hitting through walls and closed doors.
2. **Window swipe reach is measured from the window opening.** `window_attack_reach` is now 1.5, plus 0.2 m grace. Before, players 2.7 m inside the room got hit.
3. **Bellringer fog portals only open in zones the players have opened,** and never across a closed door. Map 0's navmesh runs under closed doors, so packs spawned behind them and stalled rounds.
4. **Wider stuck recycling.** A zombie in CHASE that hasn't moved 1 m in 15 s is recycled if it isn't within reach, or has no clear line to its target. Before, this only happened when the player was more than 8 m away.

**Flagged, not changed** (design calls for the user):
- Map 0 two-hit downs with no perks.
- No scrip sink after the guns are bought.
- Stair navmesh tighter than a player-sized body.
- Approximate zone boxes.
- A first-use shader hitch.

**T-027, 2026-10-20: M2 on Map 0. The Helvetia cellar, machine lore, corporate slips.**

**The cellar** (Appendix A's vertical-slice note; built in `gen_map00.gd`, the map's source of truth):
- **Door 3** (1500, zone CELLAR) in the taproom's east wall, then a stair hall and ramp down to a 12 × 12 m vaulted cellar under the east yard.
- **Contents:**
  - all 8 perk machines, standing 1.1 m or more off the walls so their back panels are reachable (JINGLES.md §0.3)
  - two pillars, to loop around
  - "the cellar lever", Map 0's power: `PowerSwitch` is now data-driven per map (`config_table`), with a new `data/gravelight/map00.json` and an original Operator line, `OPR_POWER_ON_M0_01`
  - a coal-chute ground spawn from round 6
- **Garand wall-buy moved** from z 12.5 to z 4 on the same taproom wall to make room for the door.

**Answers to the two open Map 0 questions** (the user didn't pick):
- **Harsh solo:** cellar perks first. Ironhide gives 5 hits and Second Wind self-revives, which is the canon fix. A mild round 1–3 easing comes only if round-15 playtests still say it's too harsh.
- **Spare points:** the cellar door (1500), the perks (500–4000) and the 4-perk cap give scrip a purpose all game.

**Machine lore** (§10.2 and §11.2–3):
- `tools/build_perk_lore.py` turns docs/JINGLES.md into `data/gravelight/perk_lore.json`: plan IDs, the human behind each formula, and the panels.
- Each machine gets:
  - a brass maker's plate ("Rezeptur: <name>")
  - a matte-violet plan-ID stencil. It's revealed for 1.2 s, plus a 0.4 s fade, when an upgraded weapon fires within 8 m with the machine inside a 60° cone, or always once `fp_ch5_done` is set. The first reveal shows the hint "A stencil under the enamel." It uses a new `GLBus.weapon_fired` signal.
  - a readable `FinePrintPanel` on the back, with a full-screen brass-plate reader. The reader closes if you're hit.
- Panels and stencils file into the Intel Archive as `panel.<perk>` (with the formula-maker's story) and `plan.<perk>`, under "Helvetia Automaten AG".

**Corporate slips** (§11.5):
- All 32 lines, `op.slip.*` from script_ch5 §3.8, are added to `data/gravelight/vo/lines.json`.
- **Rules:**
  - they play per VO_SCRIPT §10, which owns the playback rules
  - per-line tier rounds come from the Ch. 5 table (A 10 / B 20 / C 30)
- **Conflicts resolved toward VO_SCRIPT §10**, which declares itself the owner:
  - **Map 0:** slips are allowed from round 15 at half rate; the Ch. 5 table said "never on Map 0".
  - **Squad reactions:** none ("no character reacts to a slip"). The Ch. 5 squad reaction lines stay in the script, unused. They're new content, not original B&S canon.
- **Re-extraction warning:** lines.json was originally built by `gravelight/tools_src/extract_vo.py`; re-running that extractor would drop these lines.

**FP controller on the shared core:** deferred to M7. GRAVELIGHT's `Player` is the complete first-person controller and nothing else needs one yet. The Fine Print's Field Unit (Vendelin, M7) is the second user, so the shared base is extracted then, with both users in hand.

**T-028, 2026-10-20: Zombie bugs found by the round-15 Map 0 playtests** (all GRAVELIGHT, so they also apply to Map 1).
1. **Runtime colliders were missing from the navmesh.** Perk-machine and mystery-crate bodies are created at runtime, after the bake, so zombies pathed into them and stuck. `gen_map00.gd` now bakes invisible nav blocks for their footprints (`MACHINE_FOOTPRINTS` mirrors `PerkMachine._shape_footprint`). Map 1's machines sit against walls; they get the same treatment in M5.
2. **Zombies stacked on each other's heads.** Two zombies emerging on one spot (the power-on burst, a busy ground spawn) ended with one standing on the other, stuck in mid-air.
   - Ground emergences now take the first free slot on a ring, at least 0.9 m from every active zombie (`ZombieDirector._scatter`).
   - Any zombie whose floor is another zombie steps off sideways (`Zombie._slide_off_zombie`).
3. **Bellringer portals snapped onto furniture.** A portal's offset point could snap onto a bed top. Offsets that change height by more than 0.4 m now fall back to the portal point.
4. **Closed-door test fixed.** "Does this path cross a closed door" is now a real plane crossing between the jambs (`ZombieDirector.door_crossed`). The old distance test rejected any path that merely started next to a door.
5. **Cellar zone box** stops below the ceiling, so the yard above isn't counted as "cellar".

**T-029, 2026-10-20: M3 lead work.**
- **Super Sprocket's three modes all run** (GDD section 3.3), each tuned in `data/bs/sprocket.json`:
  - **Bulwark** (picked when Bolt is hurting): Sprocket guards between Bolt and the nearest threat. Bolt takes 35% of each hit and regenerates 3/s. Enemy shots within 3.2 m of Bolt are denied, and Sprocket returns fire at half rate.
  - **Zip** (picked against a crowd): a hop every 0.45 s, with a 14 × 2 damage burst within 2.2 m on each arrival.
  - **Overclock** is unchanged.
- **Per-planet splash quips:** each planet's level data can list `splash_quips` (BS_LEVELS's per-planet out-of-bounds tables); otherwise all six are used. Scrapheap uses splash.05, .06 and .01.
- **Minimal star map** (`ui/bs/star_map`, `data/bs/planets.json`):
  - planets in campaign order, with the `planetLocked` rules, gold counts and taglines
  - travel to built planets
  - opened from the planet summary's STAR MAP button, and from the hub once Scrapheap is cleared
  - the full port (cockpit, mission tracker, travel sequence, flyovers) is M4
- **M3 builders** work against `docs/M3_CONTRACTS.md`: A for the arsenal and Forge, B for Rustvane, C for Nova Plaza, D for enemies and bosses.

**T-030, 2026-10-20: M3 paused at the user's request ("come to a stopping point").**
- **State:** all four builders' work is committed as "M3 WIP" (not tagged).
- **Verified:** compile is clean, 404/404 tests pass, and every smoke passes.
- **Lead changes at the pause:**
  - `run_tests.sh` timeout 300 → 900 s (the suite now takes about 308 s)
  - the new line files are added to `VOManager.LINE_SOURCES`
- **Builder decisions kept:**
  - Tether-Hook gates are vertical only: Bolt already covers about 31 m flat and 5.4 m up alone.
  - The Sentinel fights on the Quarry Floor.
  - Rustvane's shield reveal plays on the Return Relay, before the summary.
  - Nova walkways add a 2.5 m/s floor carry (the source push alone barely moves a standing Bolt).
  - The Zoning Board is a controller that spawns 3 pylons.
  - Bosses run on a new `PatternBoss` base.
- **Open items:** listed in ROADMAP "M3 status".

**T-031, 2026-10-21: AI teammates (bots) for solo GRAVELIGHT.** "Add a way to play with 3 other bots on your team."
- **How to use:** Play → survivor → the map page has "Squad: you + N bots" (0–3) and "Bot skill: Green / Regular / Veteran". Both are remembered in the settings (`bots`, `bot_skill`). The bots take the survivors you didn't pick. Dev tools: `gravelight/tools_src/smoke_bots.tscn` (headless), `shots_bots.tscn` (screenshots), `tools_src/playtest_gl.tscn -- --bots=3`.
- **A match with bots is a co-op match, offline.** `GameState.player_ids` is `[1, 2..]` with `bot_ids` for the bots, so `is_solo()` is false and the co-op rules apply: last stand, 4 s revives (2 s with Second Wind), 45 s bleed-out, spectate until the next round, perks lost on a down, co-op perk prices, game over only when everyone (human and bots) is down. The human's solo Second Wind self-revive is therefore off when bots are in; the bots revive you instead. A `NetMatch` is created offline as a *local session* (`Net.session`, nothing sent) so the RevivePoints, the co-op HUD ledger and the MapRoot read one life-cycle (`CoopState`).
- **Bots are Players, not input-driven clones.** A bot is a `Player` with `is_local = false, is_bot = true`: a RemoteBody (the co-op third-person soldier in its survivor's colours), a mirrored WeaponHolder as inventory, real collision, local damage and downs. Its `BotBrain` child moves it on the navmesh (NavigationServer3D paths that never cross a closed door; bots never buy doors or the power), aims with a capped turn rate and an aim error that settles from `aim_error_deg` to `settle_error_deg`, reacts after `reaction_s`, needs a line of sight from its eye for every target (never shoots through walls or a teammate), fires with the weapon's own rpm/spread/damage/falloff/limb rules (shots are traced like `WeaponHolder._trace`), reloads with the weapon's timings, swaps to a loaded gun up close, knifes what reaches it, kites when surrounded, hurt or dry, rebuilds boards near it between fights, buys wall guns / ammo / up to 2 cheap perks with its own Scrip within shopping range of the leader, revives downed teammates (the human first; one reviver per downed player) and gets revived. Zombies target bots through the `players` group like anyone else. Survivor VO lines double as callouts (DOWN, REVIVE, REVIVED, AMMO_NONE, bosses, rare headshots), rate-limited squad-wide.
- **Scaling (`bots.json scaling.bot_player_weight = 0.75`):** a bot counts as three quarters of a player for zombie counts, the Bellringer count and the Foreman's health: 1 human + 3 bots = 3 players' worth (`BotConfig.scaled_player_count`), not a full four, because bots don't carry: they share kills (the kill-share rule leaves the zombies the human is aiming at alone when the human has had under 45% of the recent kills, unless they threaten someone) and don't use the crate. The start pistol is refilled at each round start so a bot with no wall gun yet stays useful.
- **Performance:** perception at 8 Hz per bot, staggered; at most 3 LOS rays per think plus 1 for the current target; paths every 0.6 s; no NavigationAgent avoidance. The headless smoke test with 3 bots and up to 24 zombies on Map 0 runs at ~14 ms p50 per physics frame including the whole scene.
- **Bots spend their own Scrip on doors, guns and the Crucible** (the user's follow-up: "make sure the bots buy doors and other weapons"; this replaces the earlier "opens nothing on its own" rule). `bots.json shopping`:
  - **Doors** (`shopping.doors`, `enabled` switches it off): a bot buys a closed door when its Scrip covers the cost plus `reserve_scrip` (300), at least `round_delay_s` (20 s) into the round, at most `max_per_round_per_bot` (1) a round; it prefers the door the human is looking at (`human_look_cone_deg`) and then the one nearest the human (`near_bonus_m` minus the distance); doors that need the power wait for it; it stands on its own side of the door (`BuyDoor` paths are rejected through other closed doors). Pure rules: `BotConfig.door_allowed`, `BotConfig.pick_door`.
  - **Wall weapons:** from the pistol up the wishlist as Scrip comes in (`pick_weapon` keeps `weapon_buffer_scrip`), and ammo for a held gun under `ammo_below_frac`.
  - **The Crucible** (`shopping.crucible`): from `min_round` (8), with the upgrade price plus `reserve_scrip` in hand, when the map has one and the gun in hand can learn something: the bot feeds it, waits for the forge and takes the result (`BotConfig.crucible_wanted`). Map 0 has no Crucible, so this only shows on Kaltenbrunn.
  - The smoke test hands every bot 1200 Scrip at round 2 and requires a wall-gun purchase and a door purchase by a bot before round 4.
  - **Crucible in practice (T-033 follow-up, "make sure the bots know how to pack a punch their weapons"):** Map 0's cellar Crucible (lever-gated) and Map 1's Core Vault Crucible both work for bots: the upgrade is a *round-break* errand (`crucible.only_in_break`), first in line (`crucible.priority` 80 over ammo 60 and boards 30), never while the human is down; a bot feeds its best non-pistol gun that can learn something (`_upgradeable_slot`), waits the forge in front of the mouth (shooting from there if the round starts: a fed errand is never dropped for a fight), takes only its *own* result (the co-op steal rule: a teammate's offer is left alone), raises it like a swap, and later buys upgraded ammo (2500) when the upgraded gun in hand is under `ammo_below_frac` with `ammo_reserve_scrip` to spare. Unpowered Crucibles (`Crucible.is_powered()`) are ignored until the lever. The bug this surfaced: the bots' approach point used the Area's origin, but every Interactable keeps its offset on the shape (`interact_offset`), so the "front" of the Crucible was inside its body; `BotBrain._front_of` now uses `interact_offset` in the node's frame (also better fronts for perk machines and wall buys). The smoke's Crucible phase sets round 9, powers up, opens the cellar door and hands each bot 7000 Scrip; `-- --map=map01 --crucible-only` runs the Core Vault with the map debug-opened.
  - A bot never trades an upgraded gun away: with both slots full it switches to its worst non-upgraded gun before a wall buy (that is the slot a wall gun replaces) and buys nothing when every slot is upgraded (`BotBrain._slot_to_give_up`; found when a bot swapped its fresh kar98k_up for a Garand).
  - **Overclock Cordial:** the bots' own reload state calls `PerkManager.overclock_reload(player, overclock_spent(mag, mag_size))` at reload start (a no-op without the perk), and `overclock_cordial` is on their perk wishlist.
- **Catch-up:** a bot cut off from the leader (a door bought while it was elsewhere) for 8 s at 14 m+ teleports to a navmesh point behind the leader in the same room.
- **Online co-op lobbies: bots deferred.** Filling empty host-lobby slots with bots needs roster slots with no peer, bot rows in the player stream, inventory and fire events for the bot pids and respawn/op routing per peer; feasible on the same `is_bot` Player, but it touches every stream, so it is not in this change. Solo-with-bots only.
- **Tuning** in `data/gravelight/bots.json` (skills, perception, follow slots, combat and kill share, revive, repair, shopping, callouts); pure rules in `gravelight/bots/bot_config.gd`, unit-tested in `gravelight/tests/unit/test_bots.gd` (20 tests).

**T-032, 2026-10-21: the Crucible on Map 0.** The user asked "where's pack a punch on the first map? make sure it's there." Map 0 had none (MAPS.md: "no power, no perks, and no Crucible"); the cellar had brought power and the perks in T-027, so the Crucible joins them.
- **Where:** the Helvetia cellar, in a brick alcove on the vault's north wall at x 29.5 between the stair mouth and the cellar lever, facing south (`gen_map00.gd build_cellar_gameplay`, setting in `_crucible_setting`). The spot blocks neither the stair spill, the machine rows, the lever, nor the north pillar's north face (the story docket). Its footprint is a navmesh block like the machines'.
- **Power:** `Crucible.needs_power` (new export, false elsewhere) makes it answer "Power must be activated" and refuse until `GameState.power_on`, mirroring the perk machines; the mouth glow and the Nachtglas light stay off until the sweep. Prices stay in `economy.json` (`crucible_upgrade`, `crucible_upgraded_ammo`).
- **Checks:** `smoke_map00` asserts the Crucible exists in the cellar; `smoke_m2` asserts it refuses before the lever and forges a Kar98k into its upgrade after.
- **Art pass (same change):** the cellar got its vault dressing (stone ribs and corbels under a brick soffit, flagstones, shelves, barrels, wine rack, coal chute, pendant bulbs lit by the sweep, cobwebs, puddles), the staircase its banister, runner with brass rods, sloped wainscot, sconce and framed procedural pictures, and the taproom and guest rooms a few more pictures, a clock, rugs and nightstands. Materials in `Mats._build_map0`, props in the Map 0 section of `props.gd`.

**T-034, 2026-10-21: the ninth perk, Overclock Cordial.** "Add another perk." The perk was already designed (`docs/gravelight/WEAPONS.md` §20.2, `docs/JINGLES.md` §10, lore in `LORE.md` §8 / `perk_lore.json`), so this is the build, not the design.
- **Effect:** `PerkManager.overclock_reload(player, spent)` is the one hook. `WeaponHolder.start_reload` calls it with e = 1 − mag / mag_size (once per reload, so bolt and shell-by-shell reloads burst on the first round only); a heat-bar weapon's overheat vent (`heat_per_shot`, the OMNI-BLASTER when it lands) calls it with e = 1.0. Rules as the doc: trigger at e ≥ 0.25, 3 s cooldown, the burst lands 0.15 s later at the player (nothing if they dropped meanwhile), radius 2.5 + 3.5e m, damage 0.6 × health(r) × e to the nearest 10 non-bosses (Repossessors ×2, `kind = &"electric"` so Glasshide plate is ignored), a flat 1500e to `foreman` / `underwriter`, a stagger at e ≥ 0.75, no self / team / barricade damage. The numbers sit in `perks.json` "effects" so tuning is data. Bots reload in `bot_brain.gd`, not `WeaponHolder`, so a bot holding the perk needs that one call (`PerkManager.overclock_reload(player, PerkManager.overclock_spent(mag, size))`) at its reload start; the bots agent owns that line.
- **Presentation:** `Effects.static_burst` (a teal-to-violet ring racing out to the radius, a core flash, sparks, a violet light), `perk_overclock_burst` (two synthesized ZAPs), `GLBus.overclock_burst` (the cabinet's gauge needle swings to VOLL when a burst lands within 6 m). Camera shake was deliberately left off a reload.
- **Machine:** shape `coil` in `InteractableArt` on the cabinet footprint 0.8 × 2.3 × 0.6 (Map 0's placement relies on it): teal enamel with copper bands and cable loops, a porthole under the LEER · HALB · VOLL gauge, an induction coil on a ceramic collar with the brass ball as the lamp globe, Funki the tin mascot, violet neon from a new optional `"neon"` colour in `perks.json` (the brand colour stays teal for the HUD cap). The arc snaps every 3–7 s with a flash and a snap; the stencil is crooked (stenciled in haste); the maker's plate reads *Prototyp · Rezeptur: ein Freund* because this Plan has no human behind it. The jingle (`jingle_overclock_cordial`, Jingles bus) is the §10 organ incipit at 152 BPM with the cracked F♯ and no final chord; `_resolved` (B♭ chord, the off-key bass, the bee-boop) plays once the profile holds `fp_ch5_done`. `PerkMachine._play_jingle` is generic: any machine whose `jingle_<perk_id>` key exists plays it on purchase, so the other eight get theirs when their jingles are synthesized.
- **Map 1:** the Generator Hall, in the switchgear gap on the north wall at x 60.25 facing the turbines (the electrical machine on the hall's own bus); `MAPS.md` table updated, `smoke_map01_systems` buys it and checks a reload at e = 0.5 hurts a zombie 2 m away. Availability gating by `gl_perk_overclock` / `fp_ch5_done` is deferred until The Fine Print exists: the machine is simply there.
- **VO:** `PERK_OVERCLOCK` token in `VOManager.PERK_TOKENS`; `extract_vo.py` now reads the CHARACTERS.md §5 `gl.all.<char>.perk_<token>.NN` rows as `{SPK}_PERK_{TOKEN}_{NN}` (an id another pass defined is kept). Only the eight Overclock lines were added to `lines.json` here; a full extractor run also pulls in the VO agent's pending doc changes and is theirs to do.
- **Tools:** `gen_audio.py` paths fixed for the merged layout (`data/gravelight/audio.json`, `res://gravelight/audio/`), its prefix filter takes a comma list; `check_scripts.gd` now walks `res://gravelight/*` (it was checking 28 shared tests and nothing else).

**T-035, 2026-10-21: real voice audio and a squad that talks.** "Give the characters some actual dialogue and the announcer some real sound." Before this, one audio file existed; every VO line was a timed silence with a subtitle, and most squad categories never fired.
- **Voice approach:** placeholder VO baked offline, not synthesized at runtime. `gravelight/tools_src/gen_vo.py` speaks every line of `data/gravelight/vo/lines.json` with the Windows offline OneCore voices (Microsoft David / Mark / Zira) through `gen_vo_tts.ps1` (WinRT `SpeechSynthesizer` → stream → WAV; **file output only, it never touches the speakers**), with per-speaker SSML prosody, then processes it with our own numpy/scipy DSP and encodes it with ffmpeg to Ogg Vorbis mono ~64 kbps at `res://gravelight/audio/vo/<speaker>/<id>.ogg` (a `.wav` fallback if an encode fails; VOManager accepts either). Exchange parts (banter, the Tag) are `<id>_p<n>` under the part speaker's folder. Deterministic (every effect's RNG is seeded by the file id) and incremental (`data/gravelight/vo/audio_manifest.json` holds a hash of text + voice profile + tool version per file, plus `missing` with a reason: two lines are stage directions with no speech). 703 files, 51 minutes of speech, 27 MB with the import files.
- **Per-speaker profiles** (voice, SSML rate/pitch, phase-vocoder "size" = pitch+formant factor, channel): **Operator** Mark +8%/+6%, 1.00, *tannoy* (320–3600 Hz band-pass, brass saturation, hall, tape hiss, crackle, 50 Hz hum, flutter, a key click; `{braces}` in the text become the Ledger splices: a 70 ms gap and a +18% pitch jump on the fragment) and `op.slip.*` a cleaner, slower *corporate* timbre (140–7500 Hz, light compression, no hiss); **Fasbender** David +6%/−2%, 0.97, *radio* (420–3000 Hz, saturation, a 2.7 kHz low-pass for the hand over the mic, white static bed, hum, static bursts at both ends, stronger on `[static]`); **Reinholt** Zira −10%/−12%, 0.94, *PA* (1.4 s hall, hum) for the hijacks and *phonograph* for cylinders and diary samples; **Liesl** Zira +4%/+28%, 1.22, *phonograph* (wow and flutter, wax hiss, crackle, 300–4300 Hz); **Dutch** David −8%/−14%, 0.93, low-shelf and gravel saturation; **Peg** Zira −2%/−4%, 1.00, presence boost; **Deacon** Mark −7%/−7%, 0.97, warm low-mids and a small room; **Wren** Zira −4%/+6%, 1.07, mid cut and a touch of presence. Bracket cues steer effects (`[whisper]`, `[distant]`, `[slowed]`, `[static]`, `[cheerful]`); parentheticals, `♪` and `*markers*` are not spoken. All speech is normalized to about −19 dBFS RMS.
- **Playback (`vo_manager.gd`):** real streams on the VO bus with the duration read from the file (the silence estimate only when a file is missing); the local player and the story voices are 2D, any other survivor's line (a co-op teammate, a bot) is an `AudioStreamPlayer3D` that follows their body; Music −6 dB, Jingles −9 dB and, through `AudioDirector.set_vo_duck`, the ambience bed and score −5 dB while a story voice speaks. Files load through the import (`.import` files are committed) or `AudioStreamOggVorbis.load_from_file` as a fallback. Volume settings apply through the VO bus as before.
- **The squad talks:** VOManager now handles every survivor's signal-driven categories (`say_as(pid, category)`), so humans in co-op and bots speak in their own character's voice: SPAWN, ROUND_START / ROUND_END, BELL, FOREMAN / SCREAMER, BUY_*, BUY_AMMO, CRATE_*, PERK_*, DENY_*, DOOR, POWER, TRAP, INTEL, DOWN, TEAM_DOWN, REVIVE / REVIVED, AMMO_*, GLASSHIDE, CRUCIBLE, PWR_*. The categories that were dead because nobody had written them (SPAWN, ROUND_START, ROUND_END, BUY_AMMO, TEAM_DOWN, INTEL, DENY_NO_POWER / DENY_CAP / DENY_NO_SCRIP) got 13 lines per character in CHARACTERS.md §8; the ones dead because no trigger was wired (BELL, FOREMAN / SCREAMER, GLASSHIDE, TRAP, CRUCIBLE, BUY_AMMO, TEAM_DOWN, INTEL, DENY_*, SPECIAL_END, DOWNED, CRUCIBLE_*) are wired, with three new signals (`crucible_started` / `crucible_ready` / `crucible_expired`, emitted by `crucible.gd`). Squad reactions to an Operator announcement are delayed 2.5–5 s so nobody talks over him; DOWN / TEAM_DOWN / REVIVE / REVIVED are tier 2 for the squad (`rules.json` `player_category_priority`): they skip the chatter gap, cut a quip and never expire in a queue. The **down sequence is deterministic** (`rules.json` `down_sequence`, `squad_second_channel`): the downed player's DOWN at once on the player channel; TEAM_DOWN on a *second squad channel* (its own 2D/3D players) 1 s later, its speaker chosen when it starts so it is never the downed player or the reviver (dropped only if nobody else is standing or 8 s have passed); the reviver's REVIVE queues behind TEAM_DOWN on that channel and is never displaced (if the reviver's line never got out, through BotSquad's callout cooldown or chance, it is said at revive completion instead); REVIVED comes on the player channel when the revive lands, overlapping whatever the others are still saying. Two voices at most, no line waits more than about 4 s. `smoke_vo` asserts the four lines and their speakers, and passed five runs in a row on the merged tree. BotSquad's own callouts (REVIVE at revive start, rare headshots, AMMO_NONE) stay and now pass the bot's pid so they are positional; its DOWN / REVIVED / boss handlers were removed in favour of VOManager (the `bots.json` callout chances for those keys are now unused).
- **Round-break banter:** after `round_ended` (round 2+), `rules.json` `banter` (30%, 180 s cooldown, 2.5 s delay, pair within 15 m, once per exchange per match) picks two standing survivors with different characters and plays a `BNT_<A>_<B>` exchange, each part at its speaker's body. Twelve new two- and three-line exchanges (`_04` / `_05` per pair). Chatter limits unchanged (3.5 s gap, one line per group, cooldowns per category, `player_category_cooldown` overrides for the squad).
- **Data pipeline:** `extract_vo.py` works from the merged layout again and merges: doc ids win, ids that only exist in `lines.json` (slips, lines other passes add) are kept, existing `rules.json` keys are never overwritten and the T-035 keys are among its defaults (the T-034 warning about re-extraction is retired). `data/gravelight/vo/lines.json`: 625 lines (OPR 197, DUT 78, PEG 77, DEA 82, WRN 80, FAS 47, REI 23, LSL 10, BNT 30, TAG 1).
- **How to re-bake:** `python gravelight/tools_src/extract_vo.py && python gravelight/tools_src/gen_vo.py` (only new or changed lines are rendered; `--only=OPR` or `--only=BNT_DUT` for a subset, `--force` for everything, bump `TOOL_VERSION` after changing a profile), then `tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe --headless --editor --quit-after 300 --path .` to import the new files.
- **Verification:** `gravelight/tests/unit/test_vo.gd` (every line has a file or a listed reason, durations > 0, a played line takes the file's duration, new banter ids valid, every squad category has lines for all four, `say_as` uses the player's own voice); `gravelight/tools_src/smoke_vo.tscn` (Map 0 with 3 bots, rounds 1–3, chance rolls forced: logs every category per speaker, asserts the Operator's announcements, the key squad categories, a banter exchange and that 2D and positional audio streams started on the Dummy driver). Asset note in `docs/ASSETS.md` §3.

**T-033, 2026-10-21: the campaign chain: Map 0 → Map 1 → Map 2 by exfil, kit and all.** "Connect the maps. Allow the players to exfil to the next map at round 10, then once they make it to round 30 the third map. Create a cut scene to the next map. Players and bots should keep their loot and guns."
- **How to play it:** Play → survivor → **Campaign** (above the single-map list; the co-op lobby has the same button for the host). The run starts at the inn. Single-map play is untouched: no beacon, no chain.
- **The exfil beacon** (`gravelight/world/exfil_point.gd`, spawned by `MapRoot` from the map json's `exfil` block, like the story props): a signal lantern on a post with a painted board ("THE CARTERS' ROAD" at the stable's great doors on Map 0, `(18, 0, 32)`; "THE NORTH GATE" inside the yard gate on Map 1, `(20, 0, 2.2)`). Dormant (the board says when it opens) until the exfil round **starts** (round 10 / round 30, `round_started`), then lit with a pulsing beacon and flare, an Operator announcement (`OPR_EXFIL_OPEN*`), a HUD banner and a countdown in the prompt. The window is `window_seconds` (90) **during the round**: the zombies keep coming while the squad gathers, which is the tension. Map 0's beacon stands in the stable, so when it lights the stable's doors open for free (`opens_zone`): nobody is locked out of the exfil by a door they didn't buy. If the window closes the campaign continues on this map and the beacon lights again `retry_rounds` (3) rounds later (10 → 13 → 16 …), so no run is soft-locked. Tuning in `data/gravelight/map00.json` / `map01.json` (`exfil`) and `data/gravelight/campaign.json` (chain, scenes, arrival grace, vote hold, skip delay, beacon look, both cutscenes).
- **The vote:** hold Use (1.5 s) at the beacon. Solo: you alone. Co-op (and solo with bots, which is a local co-op session): every living human must vote, like the Crucible's rules; downed and bled-out players don't count. Bots don't vote: they follow the leader (BotBrain FOLLOW), so they gather at the beacon with the human and leave with the squad. The prompt shows the tally; the Operator nags the stragglers (`OPR_EXFIL_WAIT`). A client's vote is the normal host-validated interact request; the beacon's state is mirrored (`Net.mirror`).
- **Carry-over** (`gravelight/world/campaign.gd`, static, unit-tested): at departure the host serializes every player, human and bot: character, both weapons with ammo and upgraded state (`WeaponHolder.to_net()`; a downed player's stashed kit, not the crawl pistol), melee, grenades, the tactical (Siren Gramophone), Scrip, perks and bonus perk slots, plus the round, `next_special` / `next_boss`, the match stats and the run clock. The payload goes to every peer (`Net.travel` / `_rpc_travel`), the scene changes, and the new `MapRoot` restores it through three hooks: `Campaign.on_roster` (the same survivors keep their ids), `on_players_spawned` (each peer restores the player it owns with `WeaponHolder.apply_carry`; the authority also its bots, everyone's Scrip and perks; a teammate's puppet gets its inventory from its owner over the usual stream) and `on_rounds_started` (`RoundManager.resume_at`). Not carried: active power-up timers, map flags, open doors (they belong to the map they were bought on).
- **Rounds across maps:** the count continues: Map 1 starts "at the end of round 10" with a **14 s arrival grace** (instead of the 6 s intro) and round 11 brings round-11 zombies for the same scaled player count; the third map starts after round 30 (or 33, 36 … after misses). The carried Bellringer / Foreman schedule is kept; an entry already behind the arrival round is re-rolled past it with its usual gap (`RoundManager.carried_schedule`). A down after the transfer follows the normal rules (co-op: perks lost; solo Second Wind as usual).
- **The cutscenes** (`gravelight/ui/exfil_cutscene.gd`, the Requiem ending's pattern: timed shots, free camera, banners, VO): ~30 s, data-driven (`campaign.json` `cutscenes`: camera from/to/look per shot, VO ids, effects). Map 0 → 1: the squad at the beacon as the great doors fall outward, the crossroads at first light (the moon becomes a low winter sun, the environment warms), the east road, title card **KALTENBRUNN**. Map 1 → 2: the yard gate rises, the north road, a high pull-out, title card **TOTENHAFEN**. Letterbox, fade, skippable with Use after 3 s (co-op: every human, through a whitelisted `request_skip`). The round stops and the dead are cleared at departure; players are invulnerable and frozen; every peer plays its own copy, the host's copy ends it. New Operator / Fasbender lines in `lines.json` + VO_SCRIPT.md §3.15 (`EXFIL_*` tier 3, `CUT_EXFIL*` tier 4).
- **The third map while it is being built:** `map02_totenhafen` is the round-30 target. When its scene is missing the cutscene plays, then a "THE CAMPAIGN CONTINUES" results screen (`gravelight/ui/campaign_end.gd`) shows the run and the kit, the profile has Totenhafen unlocked, and the menu button leaves (host: everyone to the lobby); the run ends there with a logged warning. Once `gravelight/maps/map02_totenhafen/map02.tscn` exists it loads at round 31 with everyone's kit, no further change needed (its own `exfil` block, if any, would come from `map02.json`).
- **Profile:** reaching a map by exfil unlocks it (`ProfileSave.unlock_map` on every peer); the per-map XP leg is committed when the next map's match starts (the existing `finish_match` on `match_started`).
- **Verification:** `gravelight/tests/unit/test_campaign.gd` (15 tests: exfil data, retry rounds, schedule carry, `resume_at` continuity with round-11 counts, loadout round-trips with ammo and upgraded state, payload validation, account restore); `gravelight/tools_src/smoke_campaign.tscn` (headless: solo + 3 bots, round 10 → beacon → vote → fast-forwarded cutscene → Map 1 at round 11 with every player's weapons/ammo/upgraded/Scrip/perks/grenades verified, bots alive and following; round 30 missed → round 33 → vote → the "campaign continues" screen, profile unlocks); `shots_campaign.tscn` (silent off-screen frames of the beacon and the cutscene).
- **Known limits:** the great doors fall but the stable's south wall behind them is solid greybox (an opening needs the Map 0 generator, another owner); online co-op was exercised through the existing host/client smoke only for regressions, not a full two-process exfil; bots in online lobbies are still deferred (T-031).

**T-036, 2026-10-21: Map 2 "Totenhafen", first playable.** The map the campaign reaches at round 30 from Kaltenbrunn (T-033): a Baltic U-boat pen in a winter storm. Design first (`docs/gravelight/MAPS.md` Map 2, in the Map 1 format: zone graph, floor plans, spawn counts, wall-buys, perks, crate spots, traps, the power switch, the Crucible, choke points, a pacing table from round 31, the story items), then the build.
- **Zones (7):** Harbour Quay (spawn, outdoors) → Fish Cannery / Torpedo Workshop (1000 each) → Pen Hall (1500 from either side, one link group: three wet docks, three piers, catwalks at +4, the crane bay) → U-1047 (gangway 1500: the boat's deck, an open hatch aft of the conning tower, a 48 m interior with the Crucible in the torpedo room), the Lower Pens (pump stair 1500: the pump deck under the east apron, the Pumpenschalter) and the Signal Tower (2500, power required, over the NE apron). Door prices skip the 750/1250/2000 steps: the squad arrives with Kaltenbrunn money.
- **Generator:** `gravelight/tools_src/gen_map02.gd` → `maps/map02_totenhafen/map02.tscn` (5.3 MB, ~590 batches from ~4650 primitives), same layering as gen_map01: collision shell, per-zone navmesh regions on navigation layers (several boxes per zone, links across every seam and doorway), dressing, batching, lights, gameplay. Lessons that cost a few runs: window closets cut into the 3 m bunker slab need their own navmesh islands (zone boxes), otherwise a window zombie's nearest navmesh is the room beyond the wall and it walks into the closet's back; a ramp that lands beside a catwalk needs a landing, not a side-step; the north catwalk widens to a platform so the tower ramp doesn't cut the ring; a 2 m door next to a railing's end is eroded shut by the agent radius (the boat's hatch is now on the open deck aft of a solid conning tower).
- **The tide** (`map02.json "tide"`, `maps/map02_totenhafen/tide_controller.gd`): high water on every round divisible by 3 (33, 36 … in the campaign; 3, 6 … standalone), rising over 24 s at the round's start from −4.0 to −2.2 and falling at the next; one subdivided water plane with a vertex-heaved sea shader (`Mats "sea_water"`). The lower pens' deck (−3) goes under 0.8 m: players there get the new `enemies.json` status `wading` (move ×0.55, refreshed every tick), zombies the frost slow ×0.45; the two drain-grate spawns switch off and three catwalk emerge points switch on (`ZombieSpawn.enabled`, a new export). The Operator reads the forecast the round before and calls the rise and the fall (`VO_SCRIPT.md` §3.16, 7 lines, baked). The pumps don't stop the tide in this version.
- **Reused systems:** `PowerSwitch` (config_table map02, the Pumpenschalter in the pump room; sweep F → D → E → G → B → C → A; 6-zombie burst), `Crucible` with `needs_power`, the ore-cart trap as the Torpedo Trolley in the workshop, the live-wire trap as the Grille at the pump-stair foot, 6 perk machines (Second Wind, Marathon, Ironhide, Trigger Tonic, Overclock Cordial, Hawkeye), 9 wall-buys from the existing arsenal, 5 crate spots (start: the hut or the warhead store), 15 barricaded windows, 6 ground + 3 catwalk spawns. Glasshides, the Foreman and the Screamer are listed for the map in `enemies.json`.
- **Story items** (`LORE.md` §13.2, four fixed props, `extract_intel.py` now marks every "fixed story items" subsection): Agnieszka's infirmary letter, the pump keeper's log, the loading manifest naming the consignee "Hale, L." care of Helvetia Automaten AG (the squad's own Mr. Hale is buying the stone), and the teletype strip in which the Operator talks in the Ledger's and Liesl's voices. `MapRoot._spawn_intel` maps `map02_totenhafen` to story key "2".
- **Registered:** the menu's map row points at the scene (unlock unchanged: Map 1 main egg or round 30), `campaign.json` already named the scene.
- **Ballast (follow-up in the same change):** three coffins are `BallastCoffin` interactables (lift 1.2 s, carried in the arms with the `ballast` slow, dropped if the carrier goes down); the crane's `BallastHook` takes one (1.5 s), sets `ballast_loaded`, and the Pumpenschalter refuses until it is set (`PowerSwitch.requires_flag`, new optional export). Shooting while carrying, dumping coffins overboard for the egg and bots carrying are not in this version.
- **Deferred:** the Kielholer (ENEMIES.md hook), a boat's log / Deacon's engine quest, Bellringer-round and Foreman tuning for the hall, the pumps shortening the flood.
- **Tools and tests:** `smoke_map02` (navigation per zone with layer gating, spawn points on the mesh and the json counts, power, the powered door, the Crucible, both traps, the tide rules and controller, then rounds 31–34 with 3 bots), `perf_map02`, `shots_map02`; `tests/unit/test_map02_data.gd` (graph connected, prices, ids, tide block, the scene matches the table); `test_story_props` covers §13.2.
