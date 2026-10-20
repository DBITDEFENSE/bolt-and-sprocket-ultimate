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
