# Bolt & Sprocket: Port Inventory

This is the complete checklist of everything in the web build (v14) that the Godot remake must port. Every row was checked against the extracted data (`data/bs_source/*.json`), the ported story data (`data/bs/story/*.json`) and the original source (`reference/bs_web/index.html`). **The source is truth.** The brief's lists were used as a guide only.

**How to read a row**
- `[ ]` is the port checkbox. Tick it when the item works in the remake at parity with the web build.
- **Source** gives the table or function and its line number in `reference/bs_web/index.html` (`L1234`). Tables are also in `data/bs_source/<TABLE>.json`.
- **Remake notes** say what changes, where it is designed, or what to watch out for.
- **⚠ NOT IN SOURCE** marks something the brief lists that the web build does not have. It is new remake work.
- **➕ NOT IN BRIEF** marks something the web build has that the brief does not mention. It still gets ported.
- **🐞 BUG** marks a defect in the web build. The remake fixes it and does not port the defect.

Planet indexes are the source's `LEVELS` indexes: 0 Scrapheap Junction, 1 Rustvane Canyon, 2 Core Foundry, 3 ZONGA™, 4 GLAMBOT Colosseum, 5 Nova Plaza, 6 Glacius Vault, 7 Verdant Sink, 8 OmniGrand Prix venue, 9 Grand Galleria, 10 Loop Riot venue.

---

## 0. Summary of counts

| Category | Count in source | Brief says | Notes |
|---|---|---|---|
| Speakers (`SPEAKERS`) | 19 | 19 + Rex | Commander Rex Tremendous exists only in `HUMOR-REVIEW.md` (unwired) |
| Campaign planets (`CAMPAIGN`) | 7 | 7 | `[0,1,5,6,7,9,2]` |
| Levels in `LEVELS` | 11 | — | 7 story planets + Zonga, Colosseum, Grand Prix venue, Loop Riot venue |
| Cutscenes (`CUTSCENES`) | 54 | 54 | 28 story, 7 boss, 5 flyover, 13 ad, 1 empty stub (`zongaGo`) |
| Story beats (`STORY`) | 22 | 22 | Dialogue-only beats, triggered in levels |
| Cutscene gallery entries (`CUTSCENE_INDEX`) | 61 | — | 53 cutscenes + 8 story beats (the 8 never display, see §5) |
| Lines in cutscenes / story beats / quests | 183 / 72 / 113 | — | |
| Lines shown or spoken from code (`code_lines.json`, IDs `code.<function>.<nn>`) | 309 | — | Banners 127, hints 97, barks 17, GLAMBOT announcer 17, `speak` 16, signs 13, boss names 7, relay labels 5, Loop Riot taglines 5, shop pitches 3, Zonga feed 1, arena result 1 |
| Menu, lobby and credits strings (`html_text.json`, IDs `html.<screen>.<nnn>`) | 197 | — | |
| All line IDs (`lines_index.json`) | 1,000 | — | |
| Weapon ad vignettes | 13 | 13 | 12 weapons + K.A.R.E.N. |
| Guns (`WEAPONS`) | 12 | 12 (+4 new) | |
| Upgrade tracks (`UPG_TRACKS`) | 3 × 3 tiers | 3 | Damage / Fire Rate / Ammo Cap |
| Mallets (`MALLET_NAMES`) | 3 | 3 (+Riot) | |
| Memos (`MEMOS`) | 35 | 35 (+5 new) | 5 per story planet |
| Memo spots (`MEMO_SPOTS`) | 35 | — | |
| Side quests (`QUESTS`) | 19 | ~19 | 3 duplicate IDs fixed (T-004) |
| Gold bolts | 21 (3 per story planet) | 3–5 per planet | One Scrapheap index is spawned twice (🐞) |
| Enemy types (`ENEMY_DEFS` + `_V9`) | 12 + 9 = 21 | 21 (+7 new) | Plus crate, nanocrate, 3 legacy test types |
| Bosses (spawn types) | 7 | 9 named | Sentinel and Content Creator are one enemy in source; Grindstone has no separate body |
| Colosseum challenges (`CHALLENGES`) | 8 | 8 | |
| Grand Prix tracks (`TRACKS`) | **4** | 3 | ➕ GLACIUS GLIDE is the 4th |
| Grand Prix rivals (`RIVAL_ROSTER`) | 5 | 5 | |
| Zonga bot names (`BOT_NAMES`) | 53 | — | |
| Zonga zone stages (`ZONGA_STAGES`) | 5 | — | |
| Loop Riot crew (`CREW`) | 6 | 5 Recalls + Bolt | |
| Loop Riot leagues / ranks / decks / notices | 3 / 6 / 8 / 14 | — | |
| Loop Riot flips / grinds / grabs | 7 / 5 / 3 | — | |
| Paints / hats / mallet skins | 8 / 5 / 4 | 8 / hats / seams | Hats include "No Hat"; LR-earned items included |
| Settings (`SETTINGS_DEF`) | 25 rows (23 keyed + 2 actions) in 3 sections | — | |
| Music themes (`THEMES`) | 9 | — | |
| SFX (`sfx`) | 38 | — | |
| Voice profiles (`VOICE_PROFILES`) | 13 | — | |
| Out-of-bounds quips (`SPLASH_QUIPS`) | 6 | kept | |
| Sprocket barks (`BARKS`) | 18 in 4 categories | — | |
| Super Sprocket barks (`SUPER_BARKS`) | 5 | kept | |
| Blartz lines (`BLARTZ_LINES` / `BLARTZ_ITEM_LINES`) | 19 / 6 | kept | |
| Galleria PA lines (`GALLERIA_PA`) | 3 | kept | |
| Sky-ad slogans (`AD_LINES`) / Loop Riot ads (`LR_ADS`) | 5 / 7 | — | ➕ |
| Denizen barks not yet in data | 30 (15 denizens × 2) | — | ➕ See §25. Everything else shown from code is now in `code_lines.json` |

**Brief items not found in the source:** 24 (listed in §28.1). **Source items not in the brief:** 31 (listed in §28.2). **Bugs found:** 8 (listed in §28.3).

---

## 1. Story and cast (`SPEAKERS`, L10835)

| ✓ | Speaker id | Display name | Colour | Where they appear in source | Remake notes |
|---|---|---|---|---|---|
| [ ] | `bolt` | BOLT | `#ffb95e` | Everywhere | Hero. Voice profile `bolt`. |
| [ ] | `sprocket` | SPROCKET | `#3ee6ff` | Everywhere; barks; four face moods `normal`, `happy`, `alarmed`, `smug` (`setSprocketExpr` L3900) | Four moods confirmed in source. Refund-bin firmware and Clause 44 run through `l1_glitch`, `l2_holo1`, `coreGlacius`, `galleriaLedger`, `l3_brick`. |
| [ ] | `grindstone` | CHAIRMAN GRINDSTONE | `#ff5d5d` | `shieldReveal`, `l2_holo1`, `novaHolo`, `glaciusHolo`, `l3_holo2`, `l3_brick`, `gsIntro`, `shieldFall`, `ending` | "Everything is a subscription, boy" is `cs.gsIntro.03`. |
| [ ] | `blartz` | BLARTZ | `#7dff9a` | Shop, ads, `blartzFound`, `blartzRescue`, cell-lock barks (`meleeHit` L5025) | Arrested for "UNLICENSED INNOVATION" (`cs.blartzArrest.01`). New Forge and Holding Block lines in `additions.json`. |
| [ ] | `cc` | THE CONTENT CREATOR | `#c06aff` | `ccIntro`, `l2_glambot` | In source, CC survives its fight (see §8 bosses). |
| [ ] | `pa` | OMNISCRAP™ PA | `#8b95a8` | Cutscenes, REPO-TRON and Greeter shouts | Also voices V.I.B.E. in `zongaTruth`. |
| [ ] | `glambot` | GLAMBOT PRIME | `#ff7ab8` | `l2_glambot` (defects), `shieldReveal`, `arrive9`, `galleriaLedger`, `l3_vent`, `shieldFall`, boss intros, Zonga/Colosseum/Range announcer (`ANNOUNCER` L13100) | Eye-in-the-sky ally. |
| [ ] | `rusty` | RUSTY | `#ffb36b` | Quests `q1a`, `q1b` at Scrapheap hub (-13, 0, 6) | NPC voice `npc3`. |
| [ ] | `concierge` | CONCIERGE-TRON | `#ff8ac2` | Quests `q2a`, `q2b` at Rustvane landing (5, 0, 24) | `npc2`. |
| [ ] | `intern` | INTERN #4401 | `#9fc4e0` | Quests `q3a`, `q3b`, `q3c` at Foundry lobby (12, 30, 22); Loop Riot crew; `lrIntro` | `npc1`. Rival "THE INTERN (AGAIN)" in the Grand Prix. |
| [ ] | `darkmatter` | DARKMATTER SUBSCRIPTIONS LLC | `#c07dff` | `postCredits`; star-map tooltip for the locked Zonga slot ("Signal jammed by a 'DarkMatter Subscriptions LLC'", L12346) | Locked fact: colour `#c07dff`, motto "NOBODY CANCELS." The tooltip spells it "DarkMatter"; the remake uses "Darkmatter". |
| [ ] | `retention` | THE RETENTION SPECIALIST | `#8ad0e8` | Boss shouts in `updateRetention` L7221 (in `code_lines.json`) | New line `bs.boss.retention.dm.01` exists. |
| [ ] | `squat` | THE SQUATTER | `#8a9aff` | Quests `q4a`, `q4b` at Nova arrival (-6, 0, 12) | `npc3`. |
| [ ] | `bathrobe` | CONFUSED CUSTOMER | `#cdeeff` | Quests `q5a`, `q5b` at Glacius arrival (6, 0, 12); also a denizen on Verdant | `npc0`. |
| [ ] | `corn` | STEWARD CORNELIUS | `#ffd23e` | Quests `q7a`, `q7b` at Verdant arrival (-6, 0, 12). Also voices the Compost King's negotiation shouts (L6910, L6915) | Quest NPC name is "Shop Steward Cornelius". |
| [ ] | `clerk` | GILDA — KIOSK #7 | `#ff9ad0` | Quests `q9a`, `q9b` in the Galleria atrium (5, 0, -2) | There is no kiosk mesh in source; she stands on the atrium floor. |
| [ ] | `dent` | DENT — TEST UNIT #001 | `#ffd23e` | Loop Riot (`lrSignal`, `lrIntro`, `lrChampion`) | `npc3`. "There's a deck on the wall here whenever you want one" is in `lrChampion`. |
| [ ] | `gasket` | MAMA GASKET | `#ffb36b` | `l1_row`; quests `q1c`, `q1d` at Rusty's Row (37.5, 0.4, -11.5) | No `NPC_VOICE` entry: falls back to the hashed NPC profile (`npcHashProfile` L11078). Give her a profile. |
| [ ] | `bellhop` | BELLHOP-9 | `#ff8ac2` | `l2_staff`; quests `q2c`, `q2d` in Back of House (-3.5, 0.1, -72) | No `NPC_VOICE` entry (same fallback). |
| [ ] | (not a speaker) Commander Rex Tremendous | — | — | `reference/bs_web/HUMOR-REVIEW.md` §1 only | Unwired draft. Port only if approved at the M0 review. |
| [ ] | ➕ Unvoiced named cast | — | — | V.I.B.E. (`zongaTruth`), MODEL-M, SCUFF, TOASTY (`CREW` L14432), Loop Riot rivals, Grand Prix rivals (`RIVAL_ROSTER` L14071), Greeter Prime, REPO-TRON | Need bios and barks in their own docs; they are not `SPEAKERS`. |

---

## 2. Campaign spine and gating

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Star-map order `CAMPAIGN = [0,1,5,6,7,9,2]` | `CAMPAIGN` L12274 | Keep. Locked fact. |
| [ ] | `planetLocked(i)`: 0 always open; 1 needs `clears[0]`; 5/6/7 need `clears[1]`; 9 needs ≥1 core; 2 needs all 3 cores | `planetLocked` L12276 | Keep exactly. The Galleria opens after the first core and is **optional** in source: the Foundry only needs the 3 cores. |
| [ ] | `coresDone()` = 3 cores | L12275 | |
| [ ] | Mission tracker text (check `code_lines.json`; extract any missing): CHAPTER 1 "Escape Scrapheap Junction", CHAPTER 2 "Infiltrate Rustvane Canyon", CHAPTER 3 — THE HEIST "Recover the 3 Keystone Cores" (with progress bar and remaining names), FINALE "Assault Core Foundry", CAMPAIGN COMPLETE "You Saved the Galaxy" | `computeMission` L12285 | |
| [ ] | Star-map lock tooltips ("Recover a Keystone Core first — GLAMBOT flags the lead after the heist begins", etc.), "ALREADY PARKED HERE" joke, Zonga "That's sequel content. Stop poking it." | `starmapFocusInfo` L12340, `pickPlanet` L12362 | Check against `code_lines.json` / `html_text.json`. |
| [ ] | Story stage `G.story`: 0 → 1 after Scrapheap, 2 after Rustvane, 2 after 3 cores, 3 after the ending | `completeLevel` L17599, `collectCore` L10328, `startEnding` L12557 | |
| [ ] | Shield reveal plays when you leave Rustvane for the first time (`btnNext`), then opens the star map | L17734 | |
| [ ] | Core pickup → core cutscene; the 3rd core chains `shieldFall` | `collectCore` L10328 | |
| [ ] | Final boss death → `ending` → `zongaReveal` (first time) → victory | `startEnding` L12557 | |
| [ ] | Victory → `postCredits` **only if all 35 memos are found** | `showVictory` L17629 | Remake decision needed (see §28.4): the brief makes post-credits lead into The Fine Print, so it should always play. |
| [ ] | Memo epilogue plays the moment the 35th memo is collected | `collectPickup` L7719 | With 40 memos, trigger on the 35 OmniScrap memos so `cs.epilogue.01` ("Thirty-five internal memos") stays true. |
| [ ] | Unlocks: Zonga + Colosseum menu after the ending; Grand Prix + Loop Riot after Scrapheap (`G.story >= 1`); NG+ after `G.story >= 3`; Loop Riot star-map slot via `lrUnlocked()` | `showMenu` L17514, `lrUnlocked` L14400 | |
| [ ] | Blartz is arrested on arrival at the Foundry and rescued in the Holding Block; Patent Pending is given in `blartzRescue` | `buildLevel3` L9976, L10023; `meleeHit` L5025; `P.owned[5]=true` L11527 | Omega Forge unlock is new (brief §5.1). |

---

## 3. Cutscenes (54, `CUTSCENES` L11327)

Lines are ported in `data/bs/story/cutscenes.json` with IDs `cs.<id>.<nn>`.

| ✓ | ID | Title (`CUTSCENE_INDEX`) | Group | Lines | Trigger in source | Remake notes |
|---|---|---|---|---|---|---|
| [ ] | `intro` | The Repossession | STORY | 8 | `newGame` L17536, `startNGPlus` L13654 | Plays at the end of the prologue garage (see BS_LEVELS). |
| [ ] | `arrive0` | Landing: Scrapheap | STORY | 2 | `finishTravel` L12471, only when `flyover0` is already seen | 🐞 order: see §28.3. |
| [ ] | `l1_glitch` | A Suspicious Clause | STORY (beat) | 3 | Dune bowl trigger (0, 2, -22) `wireStoryExtras` L13041 | Story beat in gallery index. |
| [ ] | `l1_vista` | Junk-Planet Kid | STORY (beat) | 4 | Hull-top vista (0, 17, -84) L13042 | |
| [ ] | `arrive1` | Landing: Rustvane | STORY | 2 | `finishTravel` | |
| [ ] | `l2_holo1` | Grindstone Calls | STORY (beat) | 5 | Resort deck A (0, 8.5, -24) L13044 | |
| [ ] | `ccIntro` | The Content Creator | BOSS | 5 | Boss deck approach (0, 10.5, -106) L9872 | |
| [ ] | `l2_glambot` | GLAMBOT Defects | STORY (beat) | 5 | Rustvane boss death L9868 | |
| [ ] | `shieldReveal` | The Shield Goes Up | STORY | 6 | Leaving Rustvane L17734 | |
| [ ] | `novaIntro` | Welcome to Nova Plaza | STORY | 3 | Core-plaza approach (0, 11, -84) `buildNewPlanet` L10401 | Plays near the boss, not on landing. |
| [ ] | `novaHolo` | Grindstone: Nova | STORY (beat) | 2 | Left district (-30, 11, -58) L10404 | |
| [ ] | `coreNova` | Core: Nova | STORY | 2 | Core pickup L10337 | |
| [ ] | `glaciusIntro` | Welcome to Glacius | STORY | 3 | Core approach L10401 | |
| [ ] | `glaciusHolo` | Grindstone: Glacius | STORY (beat) | 2 | Right district (30, 11, -58) L10404 | |
| [ ] | `coreGlacius` | Core: Glacius (RECALL) | STORY | 4 | Core pickup | Sprocket sees his Batch #1. |
| [ ] | `verdantIntro` | Welcome to Verdant Sink | STORY | 3 | Core approach L10401 | |
| [ ] | `coreVerdant` | Core: Verdant | STORY | 2 | Core pickup | "We solved a boss fight with plumbing." |
| [ ] | `shieldFall` | The Shield Falls | STORY | 4 | 3rd core L10339 | |
| [ ] | `arrive2` | Landing: Core Foundry | STORY | 2 | `finishTravel` (no Foundry flyover exists) | |
| [ ] | `blartzArrest` | Blartz Arrested | STORY | 3 | Lobby kiosk trigger L9990 | |
| [ ] | `blartzFound` | Found: The Cell | STORY | 3 | Holding Block trigger L10049 | |
| [ ] | `blartzRescue` | The Blartz Rescue | STORY | 5 | 3rd mallet hit on the cell lock L5040 | Grants Patent Pending. |
| [ ] | `l3_holo2` | HQ Lobby | STORY (beat) | 3 | Lobby (0, 32, 16) L13047 | |
| [ ] | `l3_vent` | GLAMBOT Assist | STORY (beat) | 3 | Piston catwalk (0, 19, -16) L13048 | |
| [ ] | `l3_brick` | Clause 44 | STORY | 6 | Boss bridge (0, 6, -77) L13049 | |
| [ ] | `arrive9` | Landing: Grand Galleria | STORY | 4 | `finishTravel` (no Galleria flyover exists) | |
| [ ] | `galleriaGreeter` | Guest Services | BOSS | 4 | Anchor Vault approach (0, 2, -86) L10713 | |
| [ ] | `galleriaLedger` | The Ledger | STORY | 5 | Touch the ledger after Greeter Prime dies L10704 | `cs.galleriaLedger.02` reworded (T-005). |
| [ ] | `gsIntro` | Chairman Grindstone | BOSS | 7 | Boss floor (0, 6, -84) L10122 | |
| [ ] | `ending` | The Ending | STORY | 8 | Final boss death | |
| [ ] | `epilogue` | The Memo Epilogue | STORY | 7 | 35th memo L7751 | |
| [ ] | `postCredits` | Post-Credits | STORY | 3 | Victory, if all memos found L17633 | See §2. |
| [ ] | `zongaReveal` | ZONGA Revealed | STORY | 6 | After the ending, first time L12568 | |
| [ ] | `zongaStart` | ZONGA: Drop In | STORY | 3 | First Zonga match L13348 | |
| [ ] | `zongaGo` | (no title) | none | 0 | Every later Zonga match L13348 | ➕ An empty camera-only stub. Not in the gallery. |
| [ ] | `zongaTruth` | ZONGA: The Truth | STORY | 5 | After a Zonga win (`Z.truthQueued`) L17760 | V.I.B.E. now reports to GLAMBOT. |
| [ ] | `firmwareScene` | Sprocket Finds His Settings | STORY | 9 | Rustvane top billboard deck (0, 21.6, -78) L13045 | ➕ The brief turns it into a voice-filter cosmetic unlock. |
| [ ] | `lrSignal` | Loop Riot: The Pirate Broadcast | STORY | 6 | Loop Riot first open (`LR`) L16684 | |
| [ ] | `lrIntro` | Loop Riot: Meet the Recalls | STORY | 6 | Loop Riot first race | |
| [ ] | `lrChampion` | Loop Riot: The Black Box | STORY | 8 | Win the Riot Cup | "Unit survived. Recommend recall." is `cs.lrChampion.02`. |
| [ ] | `flyover0` | Flyover: Scrapheap | FLYOVER | 2 | First travel to the planet | |
| [ ] | `flyover1` | Flyover: Rustvane | FLYOVER | 2 | First travel | |
| [ ] | `flyover5` | Flyover: Nova Plaza | FLYOVER | 2 | First travel | |
| [ ] | `flyover6` | Flyover: Glacius | FLYOVER | 2 | First travel | |
| [ ] | `flyover7` | Flyover: Verdant Sink | FLYOVER | 2 | First travel | |
| [ ] | `introAlgorithm` | Intro: The Algorithm | BOSS | 2 | Never in the campaign: `BOSS_INTRO` (L7609) only maps CC and Excavatron. Boss Rush marks it seen (L13949), which unlocks it in the gallery | 🐞 Wire every boss title card through one table so each plays on first aggro. |
| [ ] | `introCC` | Intro: Content Creator | BOSS | 1 | `bossStart` L7618 via `BOSS_INTRO` | |
| [ ] | `introCompost` | Intro: Compost King | BOSS | 2 | Same as `introAlgorithm`: never in the campaign | 🐞 Same fix. |
| [ ] | `introGrindstone` | Intro: Chairman Grindstone | BOSS | 1 | `bossStart` via `BOSS_INTRO` | |
| [ ] | `ad_blaster` | Ad: Omni-Blaster | AD | 2 | First equip of a bought gun (`playWeaponAd` L4441); all ads unlock in the gallery once owned | |
| [ ] | `ad_void` | Ad: Void Ripper | AD | 3 | as above | |
| [ ] | `ad_zap` | Ad: Zapinator | AD | 1 | as above | Title says "Zapinator"; the weapon is SPROCKET ZAP. Keep the title as a joke or align it (no line text changes). |
| [ ] | `ad_boom` | Ad: Boom Box | AD | 2 | | |
| [ ] | `ad_dart` | Ad: Lawn Dart | AD | 1 | | |
| [ ] | `ad_patent` | Ad: Patent Pending | AD | 3 | | |
| [ ] | `ad_cease` | Ad: Cease & Desist | AD | 1 | | |
| [ ] | `ad_buzz` | Ad: Buzzkill | AD | 1 | | |
| [ ] | `ad_grav` | Ad: Grav Grenade | AD | 1 | | |
| [ ] | `ad_mid` | Ad: The Middleman | AD | 2 | | |
| [ ] | `ad_frost` | Ad: Frostbyte | AD | 1 | | |
| [ ] | `ad_root` | Ad: Root Canal | AD | 1 | | |
| [ ] | `ad_karen` | Ad: K.A.R.E.N. | AD | 4 | Always unlocked in the gallery (L11795) | |

(The 8 "STORY (beat)" rows are `STORY` entries listed in `CUTSCENE_INDEX`. They are counted in §4, not in the 54.)

---

## 4. Story beats (22, `STORY` L10857)

Ported in `data/bs/story/story_beats.json` with IDs `st.<id>.<nn>`. All play through `storyBeat()` (L11832): once per save, as dialogue.

| ✓ | ID | Lines | Speakers | Trigger in source | Remake notes |
|---|---|---|---|---|---|
| [ ] | `l1_row` | 5 | bolt, sprocket, gasket | Rusty's Row gate (31, -12) `expandScrapheap` L9414 | Line says "forty-one shacks"; the source builds 5. The remake builds the village to match. |
| [ ] | `l1_mast` | 3 | bolt, sprocket | Signal Mast crow's nest L9473 | Loop Riot tease. |
| [ ] | `l1_glitch` | 3 | bolt, sprocket | Dune bowl L13041 | |
| [ ] | `l1_vista` | 4 | bolt, sprocket | Hull-top vista L13042 | |
| [ ] | `l1_mid` | 2 | bolt, sprocket | Hull blast door L9636 | "That teleporter can get us off-world." |
| [ ] | `l1_repo` | 3 | pa, bolt, sprocket | Compaction lot entry L9669 | |
| [ ] | `l2_mid` | 3 | sprocket, bolt | Top billboard deck L9843 | Same spot as `firmwareScene`. |
| [ ] | `l2_holo1` | 5 | grindstone, sprocket, bolt | Deck A L13044 | |
| [ ] | `l2_camp` | 4 | bolt, sprocket | Co-op camp L9533 | |
| [ ] | `l2_staff` | 5 | pa, bellhop, bolt, sprocket | Back of House L9481 | |
| [ ] | `l2_glambot` | 5 | cc, glambot, bolt, sprocket | Rustvane boss death L9868 | |
| [ ] | `novaHolo` | 2 | grindstone, sprocket | Nova left district L10404 | |
| [ ] | `novaMid` | 3 | sprocket, bolt | Mid district (0, 9, -42) L10402 | |
| [ ] | `novaLate` | 3 | sprocket, bolt | (0, 9, -72) L10403 | The pre-fine joke. |
| [ ] | `glaciusHolo` | 2 | grindstone, bolt | Glacius right district L10404 | |
| [ ] | `glaciusMid` | 3 | bolt, sprocket | (0, 9, -42) | |
| [ ] | `glaciusLate` | 3 | bolt, sprocket | (0, 9, -72) | |
| [ ] | `verdantMid` | 3 | sprocket, bolt | (0, 9, -42) | |
| [ ] | `verdantLate` | 3 | sprocket, bolt | (0, 9, -72) | Union card. |
| [ ] | `l3_holo2` | 3 | grindstone, bolt | Lobby L13047 | |
| [ ] | `l3_vent` | 3 | glambot, sprocket, bolt | Piston catwalk L13048 | |
| [ ] | `l3_waves` | 2 | sprocket, bolt | Wave arena cleared `waveHook` L10209 | "I've beaten TWO bosses" is out of date in the remake (proposed change in the report to the lead). |

Verdant has no Grindstone hologram beat in source (`VERDANT_CFG` has no `holo`). ➕

---

## 5. Cutscene gallery and playback

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Gallery grouped as STORY, BOSS INTROS, ARRIVAL FLYOVERS, BLARTZ PRESENTS™; shows seen/locked; count in title | `openGallery` L11790, `playGalleryScene` L11815 | |
| [ ] | 🐞 The 8 STORY-beat entries in `CUTSCENE_INDEX` are skipped because they are not in `CUTSCENES` | L11800 `if (!CUTSCENES[id]) continue` | Fix: play story beats in the gallery as dialogue scenes. |
| [ ] | Cutscene step types: `cam` (from/to/look/dur), `line`, `fx`, `act` (actor animations such as the garage rise) | `runCutscene` L11839, `csNext` L11857 | `fx` steps are code; re-author per scene. |
| [ ] | Letterbox, hold-to-skip ring, typewriter text with blips, voice per line | `letterbox` L11853, `updateHoldSkip` L11250, `updateTypewriter` L11239 | |
| [ ] | Dialogue box and barks (`DLG`, `showBark`, `barkTry`) with bark voice map `BARK_VOICE` | L11197–11288 | |

---

## 6. Movement (`CONFIG`, L829): port 1:1 first

| ✓ | Feature | CONFIG keys (value) | Source function | Remake notes |
|---|---|---|---|---|
| [ ] | Walk / sprint with momentum carry | `move.walk` 7, `move.sprint` 10.5, `move.accel` 30, `move.decel` 12, `move.airAccel` 16, `move.airDecel` 3, `move.snapTurnSpeed` 4, `move.sprintCarry` 0.6, `move.sprintJumpBoost` 1.08 | `updatePlayer` L3366, `movePlayer` L3015 | Glacius slip multiplies the ground accel rate by `1 − 0.72 × slip` (L3446). |
| [ ] | Jump, double jump, variable height, coyote, buffer, apex hang | `jump.vel` 10.2, `jump.doubleVel` 9.4, `jump.riseGrav` 22, `jump.cutGrav` 58, `jump.fallGrav` 38, `jump.maxFall` 34, `jump.coyote` 0.14, `jump.buffer` 0.16, `jump.apexGrav` 0.72 | `updatePlayer` | |
| [ ] | Hover (Sprocket thrusters), drain and regen | `hover.thrust` 2.8, `hover.engageBelow` 2.5, `hover.drainTime` 1.5, `hover.regen` 0.9 | `updatePlayer` | Sprocket Glide (new) chains after the hover drains. |
| [ ] | Wall slide and wall kick | `wall.slideFall` 3.2, `wall.kickH` 9.5, `wall.kickV` 10.4, `wall.lockTime` 0.16, `wall.coyote` 0.1, `wall.minAir` 0.08 | `updatePlayer` | The v13 annex wings each have a wall-kick shaft that teaches this. |
| [ ] | Dash with i-frames (one air dash per airtime) | `dash.speed` 21, `dash.time` 0.18, `dash.cooldown` 0.8, `dash.iframes` 0.2, `dash.fovKick` 9 | `dash` L3131, `dashTrail` L3150 | Race mode: dash speed ×1.35 (L3399). |
| [ ] | Dash-jump | `dashJump.hMul` 0.82, `dashJump.v` 9.6 | `updatePlayer` | |
| [ ] | Slam and super slam (hold converts) | `slam.fallSpeed` 36, `slam.flipTime` 0.12, `slam.radius` 4.2, `slam.dmg` 30, `slam.superHang` 0.42, `slam.superFall` 58, `slam.superRadius` 6.8, `slam.superDmg` 62, `slam.knockUp` 10, `slam.holdConvert` 0.35 | `startSlam` L3170, `slamImpact` L3184 | Slam on a Grav Grenade clump gives bonus damage (shop text, L11975). |
| [ ] | Slam bounce | `slamBounce.window` 0.16, `slamBounce.v` 14.5, `slamBounce.superV` 17.5 | `slamImpact` | |
| [ ] | Slide and slide long-jump | `slide.speed` 14.5, `slide.time` 0.5, `slide.cooldown` 0.65, `slide.hy` 0.55, `slide.steer` 2.5, `slide.longJumpH` 13.5, `slide.longJumpV` 8.6 | `startSlide` L3273, `updateSlide` L3298, `slideLongJump` L3321 | Low lips (1.1 m) on sealed caches teach sliding. |
| [ ] | Camera follow, look-ahead, sprint FOV, lazy auto-camera | `cam.leadMax` 0.5, `cam.followRate` 11, `cam.sprintFov` 5, `cam.padCurve` 1.6, `cam.inputSmooth` 22, `cam.autoYawRate` 1.35, `cam.autoIdle` 0.75, `cam.autoPitch` 0.18; default distance 6.2, pitch 0.35 (`_scalars`) | `updateCamera` L4221 | Brief improvement: SpringArm collision, soft lock-on. |
| [ ] | Rail grinding (golden rails, auto-ride) | Ride speed 13.5 m/s, 17 m/s while sprint held; attach within 1.9 m horizontally and −0.4…+1.9 m vertically; jump-off 10.5 m/s up; end launch +3 m/s and 7.5 m/s up (hard-coded) | `tryAttachRail` L3074, `updateRail` L3100, `addRail` L7872 | ➕ The source already has campaign grind rails from the first planet. See BS_LEVELS for how Grind Soles extend this. Move the numbers into data. |
| [ ] | Moving platforms (sine, patrol, orbit), crushers, spinners, doors, bounce pads, updrafts, conveyors, water zones, triggers, checkpoints | `addMovingPlatform` L7839, `addCrusher` L8949, `addDoor` L8834, `addBouncePad` L8931 (power 16–20), `addUpdraft` L8939 (force 30), `addConveyor` L8794, `addWaterZone` L8787, `addCheckpoint` L7931 | Remake level kit. |
| [ ] | Fall and liquid handling: below `killY` = 20 damage and reset to the last safe spot (sampled every 0.4 s on solid ground); water = 8 damage, reset, and a `SPLASH_QUIPS` bark (20 s cooldown) | `updatePlayer` L3600–3640 | Per-planet `killY`: Scrapheap −8, Rustvane −8, Foundry −3.2, new planets −10, Galleria −12. |
| [ ] | Nanotech relay checkpoints: touch to set respawn, +25% max HP heal, label banner | `addCheckpoint` L7931, `activateCheckpoint` L7950; boss arenas add a virtual checkpoint (`checkpointHere` L7968) | ➕ |

---

## 7. Melee, combo and mallets

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | 3-hit ground string: sweep 24 dmg (range 2.8, 0.34 s, window 0.62, knock 6, hitstop 0.033) → rising backswing 28 (0.36 s, knock 8, hitstop 0.05) → 360° spin smash finisher 55 (range 3.2, 0.55 s, knock 16, hitstop 0.083, `hitK` 0.62) | `CONFIG.melee.ground`; `startAttack` L4908, `meleeHit` L4969 | Finisher makes a ground shockwave sized by mallet tier (2.6 + 1.1 × tier). |
| [ ] | Queue window 0.25, magnet cone 0.7, magnet range 4.2, small hitstop 0.045 | `CONFIG.melee` | |
| [ ] | ➕ Air string: 26 dmg → 36 dmg | `CONFIG.melee.air` | Brief adds "air combo 2 hits + spike": the 2 hits exist; add the spike. |
| [ ] | ➕ Launcher (22 dmg, launch 11, pop-jump 7.5, ding) | `CONFIG.melee.launcher` | |
| [ ] | ➕ Dash stab (38 dmg, range 3.4, arc 0.35) | `CONFIG.melee.dashStab` | |
| [ ] | ➕ Punch (8 dmg, unarmed while the mallet is thrown) | `CONFIG.melee.punch` | |
| [ ] | Mallet throw (out-and-back): 18 dmg, 24 m/s, 0.55 s out (≈13.2 m reach), 1.2 s cooldown, returns at 1.2× speed, hits on both legs | `CONFIG.melee.throw`; `throwWrench` L5117, `updateWrenchThrow` L5142 | Already a boomerang in source. Remake adds switch hits and bolt collection (see BS_LEVELS gadget rules). |
| [ ] | Combo counter (hits + timer), combo HUD | `COMBO` L4851, `comboHit` L4852, `updateComboHud` L4857 | Brief: combo tiers pay bonus bolts. |
| [ ] | Hitstop | `hitstop` L4848 | |
| [ ] | Three mallets: Scrap (start), Magma (220 bolts: +damage, burning patches), Thunder (450: +damage, wider finisher, chain lightning). Trail colours `0xffe08a`, `0xffb02e`, `0x9fecff` | `MALLET_NAMES` L2121, `MALLET_TRAIL` L2122, `shopStock` L11956, `firePatch` L5077, `arcToNeighbor` L5064 | Riot Mallet is new (Loop Riot). |
| [ ] | Percussive maintenance: 3 mallet hits break Blartz's cell lock, with Blartz counting barks | `meleeHit` L5021–5041 | Barks in `code_lines.json`. |

---

## 8. Guns, upgrades, Omega, wheel, aim assist

### 8.1 The 12 guns

Ammo per tier = extra capacity per Ammo Cap tier. Trade-in = `SHOP_TRADE_VALUE`. Unlock is the source shop condition (`shopStock` L11956). Starting loadout: Blaster, Void Ripper, Sprocket Zap (`resetSave` L1334).

| ✓ | # | Name (`WEAPONS` L4397) | Base dmg (`W_BASE_DMG` L12162) | Ammo base / per tier (L4415) | Shop price / unlock | Trade-in | Ad | Omega (`OMEGA_DESC` L4420) |
|---|---|---|---|---|---|---|---|---|
| [ ] | 0 | BLASTER | 8 | ∞ / 0 | Start | 0 | `ad_blaster` | Every 3rd shot is a HOT ROUND that forks sparks |
| [ ] | 1 | VOID RIPPER | 30 | 12 / 6 | Start | 0 | `ad_void` | Second implosion at impact |
| [ ] | 2 | SPROCKET ZAP | 18 | 30 / 12 | Start | 0 | `ad_zap` | 5 arcs, residue twice as wide |
| [ ] | 3 | B.O.O.M. BOX | 45 | 8 / 4 | 150, always | 90 | `ad_boom` | Bigger floor, double bolts |
| [ ] | 4 | LAWN DART | 55 | 5 / 3 | 250, always | 150 | `ad_dart` | Two darts, two locks |
| [ ] | 5 | PATENT PENDING | 70 | 4 / 2 | Gift in `blartzRescue`; upgrades only after rescue | 180 | `ad_patent` | Forks twice as fast |
| [ ] | 6 | CEASE & DESIST | 24 | 6 / 3 | 300, after ≥1 core | 180 | `ad_cease` | 6 ricochets, SERVED +70% |
| [ ] | 7 | BUZZKILL | 14 | 20 / 8 | 160, always | 96 | `ad_buzz` | 5 bounces, split on first |
| [ ] | 8 | GRAV GRENADE | 30 | 5 / 2 | 240, after Scrapheap | 144 | `ad_grav` | 6.5 s, crush from open |
| [ ] | 9 | THE MIDDLEMAN | 8 | 3 / 1 | 320, after the Nova core | 192 | `ad_mid` | Two Middlemen |
| [ ] | 10 | FROSTBYTE | 6 | 40 / 16 | 320, after the Glacius core | 192 | `ad_frost` | Longer beam, 9 s freeze |
| [ ] | 11 | ROOT CANAL | 8 | 8 / 3 | 300, after the Verdant core | 180 | `ad_root` | 5 gardens, 40% faster |

Per-weapon fire functions: `fireBlaster` L4552, `releaseRipper` L4729, `fireZap` L4783, `fireBoomBox` L4574 (+`danceFloor`, `detonateRave`, `RAVE_COLORS`), `fireLawnDart` L4637, `firePatent` L4684, `fireCease` L4711, `fireBuzzkill` L5617, `fireGrav` L5635 (+`spawnSingularity`), `fireMiddleman` L5689, `updateFrostbyte` L5735 (+`freezeEnemy`), `fireRoot` L5783 (+`plantAt`). The redesigns and the 4 new guns are in `BS_WEAPONS.md`.

### 8.2 Systems

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Upgrade tracks: Damage `[60,110,170]` "Makes the hurty end hurtier. Science!", Fire Rate `[50,90,140]` "Shoots faster than Blartz dodges taxes.", Ammo Cap `[40,70,110]` "Now holds more boom per bag. Pockets sold separately." Blaster has no Ammo track | `UPG_TRACKS` L11951, `tierMul` L4507 | Become Blartz Mod slots (brief §5.1). |
| [ ] | Omega: automatic when all tracks are maxed (`isOmega`) | L4434 | Replaced by the Omega Forge (2,000 bolts) in the remake. |
| [ ] | First equip of a bought gun plays its ad | `selectWeapon` L4446, `playWeaponAd` L4441 | |
| [ ] | Radial weapon wheel (opens with ≥2 guns; keyboard, mouse and pad), icons `WICONS` | `WHEEL` L17779, `openWheel` L17782, `updateWheel` L17818 | Brief: pages of 8 + last-weapon quick swap. |
| [ ] | Cycle weapon (skips unowned) | `cycleWeapon` L4459 | |
| [ ] | Aim assist: cones 0.966 / 0.906, ranges 30 / 22, falloff start 14 / floor 0.35, bend 6°, friction floor 0.45, rotation assist 30, sticky bonus 0.18, combo bonus 0.3, melee lunge 9, slam nudge 3.2, LOS step 0.8 | `CONFIG.AIM_ASSIST`; `ASSIST` L4110, `pickTarget` L4133, `updateAssist` L4167, `losClear` L4120 | Per-device stickiness = settings `stickPad` / `stickMouse`; `meleeAssist` toggle. |
| [ ] | SERVED status (+40%, +70% Omega) from Cease & Desist | `fireCease` L4711 | |
| [ ] | Weapon HUD, ammo display, recoil, muzzle flash, muzzle smoke per weapon (`W_LAST_SHOT`) | `updateWeaponHUD` L4466, `recoil` L1943, `muzzleFlash` L1900 | |

---

## 9. Super Sprocket Protocol

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | One-time shop unlock, 900 bolts ("Void the warranty. Awaken the little guy.") | `shopStock` L11956, `buyItem` L12230 | |
| [ ] | Meter charges from damage dealt: `+dmg × 0.0006` per hit | `damageEnemy` L5301 | Brief adds combo-tier charging. |
| [ ] | 30 s autonomous combat drone: strafes, twin cannons, zips between targets, everything hits twice as hard; activate with T / D-pad Up | `superActivate` L4016, `updateSuperSprocket` L4050, `superTransform` L4008, `superEnd` L4044 | ⚠ NOT IN SOURCE: Bulwark / Overclock / Zip modes. Source has one mode (with a zip move). |
| [ ] | First activation: 1.5 s slow-mo + bass drop + banner "Warranty status: OBLITERATED" | L4029 | |
| [ ] | `SUPER_BARKS` (5): "I AM BECOME WARRANTY VOID." … "Customer support has ENTERED THE CHAT." | L4001 | Keep. End bark "Protocol complete. Booting customer-service voice... hi there!" is in `code_lines.json` (L4047). |

---

## 10. K.A.R.E.N.

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | NG+-only shop item, 2,500 bolts. Press K. 45 s cooldown. Paints lock-on lines to every enemy within 20 m, then fires a screen-clearing sweep 0.55 s later | `shopStock` L11956, `fireKaren` L13668, `karenSweep` L13693 | Brief: becomes a purchasable Gadget-slot summon with a long cooldown (no longer NG+-only). |
| [ ] | Ad vignette `ad_karen` (4 lines), always in the gallery | L11795 | |
| [ ] | Name mismatch: the ad says "Kinetic Automated Retail Enforcement Nanny"; the shop text says "Kinetic Annihilation & Retribution Emitter Node" | `cs.ad_karen.01` vs L12001 | Both are canon jokes. Keep both: the shop line can be read as Blartz's own spec name. No text change. |

---

## 11. Economy and pickups

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Bolts: dropped by enemies (`drops` per def) and crates; breadcrumb trails (`boltTrail`, the "15-second rule") and rows (`boltRow`) | `collectPickup` L7719, `boltTrail` L8027, `boltRow` L9227 | |
| [ ] | NG+ bolt multiplier: ×(1 + floor(time-without-damage / 25 s)), max ×5, reset when hit | `ngMult` L13653, `damagePlayer` L4371 | ➕ |
| [ ] | Gold bolts: 3 per story planet (21 total), saved per planet index, "GOLD BOLT! n of 3 found" | `spawnGoldBolt` L8037, `collectPickup` | ⚠ In source, gold bolts are collectibles only; nothing spends them. The brief makes them a currency for cosmetics, cheats and skins. 🐞 Victory screen shows "/ 9" (L17642). |
| [ ] | Nanocrates (`nanocrate` enemy type, 10 HP): break to release a nano pickup | `spawnEnemy` L6276, `makeCrate` L2580 | |
| [ ] | Nano pickup: +20 max HP permanently (full heal in Zonga) | `collectPickup` | |
| [ ] | Ammo pickups `ammoR` (Void Ripper +6, Boom Box +2) and `ammoZ` (Zap +10, Lawn Dart +1) | `collectPickup` | Rework for 16 guns. |
| [ ] | Memo datapads, quest items, Keystone Cores | `makeMemoPad` L7656, `makeQuestItem` L7662, `placeCore` L10301 | |
| [ ] | Bolt-stealing Vulture Drone (`steal: 5`) | `ENEMY_DEFS.vulture` L6225 | |

---

## 12. Blartz's shop v2

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Tabs: ALL, WEAPONS, UPGRADES, GEAR, STYLE, TRADE-IN | `SHOP_TABS` L11949, `renderShop` L12069 | |
| [ ] | Deal of the day: one random buyable at 25% off per shop visit | `openShop` L12048 | |
| [ ] | Wishlist (★ per item) with a HUD wish pin showing the cheapest unaffordable wish | `toggleWish` L12136, `updateWishPin` L12142 | |
| [ ] | Trade-in: sell a bought gun for ~60% (`SHOP_TRADE_VALUE`) | `renderTradeIn` L12108, `sellWeapon` L12125 | |
| [ ] | Purchase celebration: confetti burst + jingle | `confettiBurst` L12149, `shopJingle` L1709 | |
| [ ] | Stat bars and descriptions | `statBarsHTML` L12171, `shopShowDesc` L12187 | |
| [ ] | Stock: 9 guns, upgrades, mallet track, Super Sprocket, K.A.R.E.N., Ammo Grab-Bag (30), Nanotech Boost (+20 HP, 100 + 60 per previous buy), cosmetics | `shopStock` L11956 | ➕ Grab-Bag and Nanotech Boost. |
| [ ] | `BLARTZ_LINES`: pitches 6, deny 3, buy 3, gratefulPitches 3 (after the rescue), tips 4 | L11017; `shopPitch` L12058 | Ported in `blartz.json`. |
| [ ] | `BLARTZ_ITEM_LINES`: one pitch per category (weapon, upg, mallet, ammo, nano, super) | L12163 | |
| [ ] | Shop opens from the level kiosk or the star map; "FIRING RANGE" button | `openShop` L12038, L17728 | |
| [ ] | Kiosk in every landing zone; at the Foundry it is ransacked with a "BACK IN 5 MIN (ARRESTED)" sign until the rescue | `landingZone` L7991, `buildLevel3` L9976 | Remake: Omega Forge added to every kiosk after the rescue. |

---

## 13. Planet traversal mechanics

| ✓ | Mechanic | Tuning in source | Source | Remake notes |
|---|---|---|---|---|
| [ ] | Glacius ice slip | Ground accel × (1 − 0.72 × `slip`), `slip` = 1 on Glacius | L3446, `GLACIUS_CFG.slip` | Keep the ~72% cut. Also used by Whiteout Brawl and the Grand Prix (`TRACKS.slip`). |
| [ ] | Glacius blizzards | First gust after 8 s; gust lasts 4.5 s; wind force `sin(ramp) × 5.5` m/s² with direction rotating 0.4 rad/s from a random start; fog far shrinks to 42%; next gust 11–16 s later; banner "BLIZZARD — Brace against the wind!"; first-time bark | `updateBlizzard` L17839 | The Retention Specialist forces a 1.2 s gust at phase 2 (L7238). |
| [ ] | Verdant murk pools | While grounded inside radius and below pool height + 1.4 m: velocity ×0.86 per frame, 5 damage every 0.7 s, 50% chance of the "The swamp is LITIGIOUS" bark | `updateMurk` L17861, `addMurkPool` L17872 | Source pools: (−14, −30, r4), (16, −70, r5), (−2, −88, r4.5). The source damps velocity ×0.86 every frame, which depends on frame rate. At 60 fps that equals a drag of about 9 per second, so the remake uses `v *= exp(−9 × dt)`. |
| [ ] | Verdant bounce mushrooms | Bounce-pad power 22–24 | `addBounceMushroom` L17880 | Source: (−20, −40, 22), (22, −46, 22), (0, −72, 24). |
| [ ] | Nova moving walkways | Push force 10 m/s² (default 9) along −z while grounded on the strip | `updateWalkways` L17891, `addWalkway` L17901 | Source: (−16, −22, 4 × 16) and (20, −42, 4 × 16). ⚠ Reversing on HOA "violations" is NOT IN SOURCE. |
| [ ] | Scrapheap conveyors and magnet crane | Belts 3.2 and 2.6 m/s; crane platform patrol 0.55 | `buildLevel1` L9595–9602 | |
| [ ] | Rustvane umbrella bounce pads, floating billboard drones | Power 16–20; drones sine amp 0.9, speed 0.8 | `buildLevel2` | |
| [ ] | Foundry crushers, glass elevator, gear shaft orbit platforms, vent updrafts | Crushers speed 1.5, drop 3.7, phases 0 / 2.1 / 1.0; elevator patrol 0.32; updraft force 30–32 | `buildLevel3` | |
| [ ] | Galleria "escalators" (conveyor feed + glass updraft) | Conveyor 3.2, updraft 26 | `buildGalleria` L10616 | ⚠ Reversing escalators are NOT IN SOURCE. |
| [ ] | Galleria mannequins move only when unseen (`stalker`) | `ENEMY_DEFS.mannequin` | | |
| [ ] | Galleria PA every 40–70 s (`GALLERIA_PA`, 3 lines) | `buildGalleria` L10722 | | |
| [ ] | ⚠ Tether-Hook, Grind Soles, Sprocket Glide, lamp-post grapple, Rustvane wind updrafts outside the annex | — | NOT IN SOURCE | New. Tuning in BS_LEVELS §0. |

---

## 14. Star map, space travel, flyovers

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Diegetic star map: planet nodes with lock state, target pulse, gold count "⭐ n/3", CORE ✓/? or CLEAR/GO, HERE tag; Zonga "???" slot; Loop Riot "???" slot with "SIGNAL LIVE / BEST / RIOT CUP" status; shop button | `openStarmap` L12266, `populateStarmap` L12306 | |
| [ ] | Mission panel (label, title, target, description, Keystone progress bar) | `populateStarmap` | |
| [ ] | Space travel: liftoff 2.6 s (ship rises 26 m) → hyperspace 3.2 s (260 star lines, FOV +24) → orbit approach 3.0 s (planet orb in the destination's `orbColor`) → land | `startTravel` L12421, `enterHyper` L12443, `enterOrbit` L12459, `finishTravel` L12471, `updateTravel` L12498 | ⚠ The brief calls this a "minigame". In source it is a non-interactive transition. |
| [ ] | Skip with hold-advance once travel has been seen (`settings.seenTravel`) | `travelSkip` L12494 | HUMOR-REVIEW travel tips only if approved. |
| [ ] | Flyovers for planets 0, 1, 5, 6, 7 | `finishTravel` | ⚠ None for Foundry or Galleria; brief wants one for every planet (see BS_LEVELS §9). |
| [ ] | ➕ Sky dressing: drifting ad blimps with `AD_LINES` (5 slogans), per-planet sky | `buildSky` L8596, `drawAd` L8588 | |

---

## 15. Memos (35 + 5 new)

Ported in `memos.json` (`memo.01`–`memo.35`); new ones in `additions.json` (`memo.36`–`memo.40`, `hidden: true`). Memo log opens from pause and Extras (`openMemoLog` L17687). Banner: `INTERNAL MEMO RECOVERED "<title>" · n/35 · read from PAUSE`. One-left bark at 34 (L7753).

| ✓ | Planet | IDs | Titles | Source spots (`MEMO_SPOTS` L13002) |
|---|---|---|---|---|
| [ ] | Scrapheap (0) | memo.01–05 | RE: RE: RE: The Moon · Garage Repossession FAQ · Scrap Mutt Feeding Policy · Conveyor Safety Update · Sunset Monetization Pilot | (13,1.2,2) (−17,1.2,−14) (14,6.2,−46) (−3,11.2,−84) (0,5.2,−126) |
| [ ] | Rustvane (1) | memo.06–10 | Twin Suns: One Is An Ad · Infinity Pool Incident · Ambassadog Vests · Selfie Sentry Firmware 9.1 · RE: The Lava Pool | (−18,1.2,24) (16,3.4,6) (−14,8.9,−47) (5,18.7,−67) (13,9.6,−112) |
| [ ] | Foundry (2) | memo.11–15 | Mandatory Fun: Guidance · Lobby Statue Maintenance · Molten Core: Q3 KPIs · Termination Notice Style Guide · PROJECT ZONGA (CONFIDENTIAL) | (−12,31.4,30) (0,24.3,5) (7,18.4,−26) (9,14.7,−42) (29,6.9,−76) |
| [ ] | Nova (5) | memo.16–20 | HOA Charter, Article 1 · FineTree Illumination · Surge Pricing the Air · RE: The Fountains · Cleaning Bot Directive | (10,1,6) (−30,10,−56) (30,4,−56) (−38,1.5,−40) (0,7,−96) |
| [ ] | Glacius (6) | memo.21–25 | ForeverYou Terms, Sec. 9 · Cancellation Flow · RECALL BATCH #1 · Aurora Licensing · The Bathrobe Situation | (−10,1,6) (−28,3,−56) (26,6,−56) (38,6,−44) (0,4,−96) |
| [ ] | Verdant (7) | memo.26–30 | TerraFarm Incident Report · RE: The Glowing · Harvester HR-9 (Missing) · Coolant Leak Memo · Corn Union Local 404 | (10,1,6) (−28,5,−56) (28,4,−56) (−38,1,−40) (0,0,−96) |
| [ ] | Galleria (9) | memo.31–35 | RE: Why Is The Mall In Space · Mannequin Recall (CANCELED) · Greeter Prime: Performance Review · Everything Must Go: Clarification · Document Retention Policy | (14,25.6,18) (3,1.4,−12) (−56,1.4,2) (5,1.4,−74) (0,23.8,−44) |
| [ ] | ⚠ New (hidden) | memo.36–40 | Sol-3 (Glacius) · Forge schematic (Foundry) · "Nobody Cancels" (Nova) · Next-Era Delivery (Verdant) · the vending robot / Clause 0 (Galleria) | Placed in BS_LEVELS per DECISIONS T-012 |

Remake placements for all 40 are in `BS_LEVELS.md`.

---

## 16. Side quests (19, `QUESTS` L12575)

Two kinds: `kill` (counted by `questKill` L12879 on the quest's planet) and `collect` (items spawn when accepted). Flow: intro → progress → done, with "All settled, friend. Go save something." afterwards (`questTalk` L12856). One NPC can hold two quests (`npcTalk` L13062).

| ✓ | Remake ID | Source ID | Planet | Name | Giver (pos) | Goal | Reward |
|---|---|---|---|---|---|---|---|
| [ ] | q1a | q1a | Scrapheap | Mutt Census | Rusty (−13,0,6) | Kill 4 scrapmutt | 80 |
| [ ] | q1b | q1b | Scrapheap | Sandwich Recovery | Rusty | Collect 3 sandwich | 100 |
| [ ] | q1c | q1c | Scrapheap | Lights On | Mama Gasket (37.5,0.4,−11.5) | Collect 3 fuse | 110 |
| [ ] | q1d | q1d | Scrapheap | Dusk Appraisal | Mama Gasket | Kill 3 vulture | 90 |
| [ ] | q2a | q2a | Rustvane | Delete My Reviews | Concierge-Tron (5,0,24) | Kill 3 selfie | 90 |
| [ ] | q2b | q2b | Rustvane | Towel Service | Concierge-Tron | Collect 3 towel | 100 |
| [ ] | q2c | q2c | Rustvane | Tip Jar Liberation | Bellhop-9 (−3.5,0.1,−72) | Collect 3 tip jar | 110 |
| [ ] | q2d | q2d | Rustvane | Break Enforcement | Bellhop-9 | Kill 2 lifeguard | 100 |
| [ ] | q3a | q3a | Foundry | Mandatory Fun Audit | Intern #4401 (12,30,22) | Kill 2 hrdrone | 110 |
| [ ] | q3b | q3b | Foundry | Clock Out Forever | Intern #4401 | Collect 3 chip | 130 |
| [ ] | q3c | q3b 🐞 | Foundry | Art Criticism | Intern #4401 | Kill 1 statue | 120 |
| [ ] | q4a | q4a | Nova | Fine Evasion | The Squatter (−6,0,12) | Kill 4 metermaid | 130 |
| [ ] | q4b | q4b | Nova | Reboot the Fountains | The Squatter | Collect 3 chip | 110 |
| [ ] | q5a | q5a | Glacius | Wake-Up Call | Confused Customer (6,0,12) | Kill 3 popsicle | 130 |
| [ ] | q5b | q5b | Glacius | Lost & Frozen | Confused Customer | Collect 3 slipper | 120 |
| [ ] | q7a | q6a 🐞 | Verdant | Pest Control (Reverse) | Shop Steward Cornelius (−6,0,12) | Kill 5 pollinator | 130 |
| [ ] | q7b | q6b 🐞 | Verdant | Stop the Leak | Shop Steward Cornelius | Collect 3 seal | 140 |
| [ ] | q9a | q6a 🐞 | Galleria | Visual Merchandising | Gilda (5,0,−2) | Kill 4 mannequin | 150 |
| [ ] | q9b | q6b 🐞 | Galleria | Final Markdown | Gilda | Collect 3 pricegun | 140 |

Brief: each quest gets a proper start, a waypoint-free hint system using Sprocket barks, and a reward. Placement in BS_LEVELS. Quest NPCs show a "!" marker (`makeNPC` L12890); each giver has a bespoke model (squat, gasket, bellhop, bathrobe, corn, default civic drone).

---

## 17. Ad vignettes (13)

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | 12 weapon ads + `ad_karen`, Blartz-presents picnic/cookout format, with PA disclaimers | `CUTSCENES.ad_*`, `WEAPON_AD` L11789 | Ported in `cutscenes.json` and `ads.json`. Brief: write 4 more for the new guns (in BS_WEAPONS). |

---

## 18. Photo mode

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Orbit camera (yaw, pitch, distance 5.5, FOV 55), filters `none`, `grade`, `noir`, `vhs`, poses `idle`, `point`, `flex`, `victory`, HUD toggle, capture to PNG | `PHOTO` L17023, `enterPhoto` L17028, `updatePhoto` L17050, `photoCapture` L17067 | From the pause menu. |

---

## 19. New Game+

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Keeps all gear, upgrades and bolts; resets story, cutscenes, quests and hints; replays from the intro | `startNGPlus` L13654 | Brief adds carry-over arsenal (already true) and new Omega-tier Blartz stock. |
| [ ] | Roster bleed: 22% chance per spawn to swap to a random enemy from the first three planets, on Scrapheap, Rustvane and the Foundry only | `spawnEnemy` L6259 | Remake: extend the bleed to every planet's elite pool. |
| [ ] | HP tiers: enemies ×1.6 HP, bosses ×1.4 | `spawnEnemy` L6317 | |
| [ ] | Player takes ×1.35 damage; bolt multiplier (see §11) | `damagePlayer` L4371 | |
| [ ] | NG+ Chrome paint (300 bolts, NG+ only) | `PAINTS` | |
| [ ] | K.A.R.E.N. in stock | `shopStock` | Moves to normal stock in the remake. |
| [ ] | Banner "NEW GAME+ — Everything hits harder. Including you." | L13665 | |

---

## 20. Cosmetics

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Paints (8): Factory Blue 0 · Ember Ops 120 · Mint Condition 120 · Royal Grape 150 · Stealth Unit 150 · Rustvane Sunset 180 · NG+ Chrome 300 (NG+) · Crash-Test Yellow (Loop Riot "Four Thousand and One") | `PAINTS` L13714 | Prices in bolts in source. |
| [ ] | Sprocket hats (5): No Hat · Top Hat 100 · Propeller Beanie 120 · Tiny Crown 200 · Crash Helmet (Loop Riot "Legally a Flip") | `HATS` L13724 | `sprocketHat` mesh |
| [ ] | Mallet seams (4): Standard · Void 100 · Gilded 140 · Riot (Loop Riot "Unscheduled Flight") | `MSKINS` L13731 | |
| [ ] | ➕ Zonga champion gold Sprocket body | `G.zongaGold` L3994, L13404 | |
| [ ] | Apply and buy | `applyCosmetics` L13738, `cosmeticItems` L13773, `buyCosmetic` L13808 | |
| [ ] | ⚠ Sprocket voice-filter cosmetic (OPERA / whisper / legal-disclaimer / CEO) | Not in source; scene `firmwareScene` exists | New. |

---

## 21. Firing range

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Opens from the shop; reuses the Colosseum; every gun with infinite ammo; 45 s; 6 ring-marked crate targets respawning; 5 bolts per hit; GLAMBOT lines; loadout snapshot restored after | `startRange` L13826, `updateRange` L13851, `rangeEnd` L13874, `rangeAbort` L13867 | |

---

## 22. Settings (`SETTINGS_DEF` L17306)

| ✓ | Section | Key | Label | Type / range |
|---|---|---|---|---|
| [ ] | CONTROLS | `mouseSens` | Mouse Sensitivity | range 0.3–2.5 |
| [ ] | | `padSens` | Controller Sensitivity | range 0.3–2.5 |
| [ ] | | `invertY` | Invert Y Axis | toggle |
| [ ] | | `invertX` | Invert X Axis | toggle |
| [ ] | | `camAuto` | Lazy Auto-Camera (follows your run) | toggle |
| [ ] | | `camLookAhead` | Camera Look-Ahead | toggle |
| [ ] | | `aimAssist` | Aim Assist | toggle |
| [ ] | | `stickPad` | Assist Stickiness (Pad) | range 0–1 |
| [ ] | | `stickMouse` | Assist Stickiness (Mouse) | range 0–1 |
| [ ] | | `meleeAssist` | Melee Assist | toggle |
| [ ] | | `rumble` | Controller Rumble | toggle |
| [ ] | | `deadzone` | Stick Deadzone | range 0.05–0.35 |
| [ ] | GRAPHICS | `quality` | Quality Preset | cycle low / medium / high / ultra (`QUALITIES` L1154) |
| [ ] | | `fov` | Field of View | range 60–110 |
| [ ] | | `shakeMul` | Screen Shake | range 0–1.5 |
| [ ] | | `fps` | FPS Counter | toggle |
| [ ] | | `showColliders` | Debug: Collider Wireframes | toggle |
| [ ] | | `showAssist` | Debug: Aim Assist View | toggle |
| [ ] | | (action) | Fullscreen | action |
| [ ] | AUDIO | `master` | Master Volume | range 0–1 |
| [ ] | | `sfxV` | SFX Volume | range 0–1 |
| [ ] | | `musicV` | Music Volume | range 0–1 |
| [ ] | | `voiceOn` | Voice Acting | toggle |
| [ ] | | `voiceVol` | Voice Volume | range 0–1 |
| [ ] | | (action) | Voice Test (cast) | action (`voiceTest` L17426) |

Hidden settings in `settings` (L1143): `seenTravel` and others are stored there too. Keep key names (DECISIONS T-010). Controls overlay screen (`closeControls` L17453) is ➕.

---

## 23. Credits and front end

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Credits panel (in `html_text.json`): "BOLT & SPROCKET — a one-file experiment in scrap and spite · Everything — Devin + Claude · Bolts harmed — several million · Warranty status — VOID · No OmniScrap™ executives were consulted. Clause 44 has been removed from all shipping firmware." | HTML L440–455 | Port the jokes into the unified credits. |
| [ ] | Main menu: CONTINUE, NEW GAME, NEW GAME+, ZONGA™, ARENA, OMNIGRAND PRIX™, LOOP RIOT™, SETTINGS, EXTRAS, CONTROLS; subtitle "Scrap the rogue mega-corp. Save the galaxy. Read the fine print." | HTML L404–420, `showMenu` L17514 | Subtitle fits the unified theme; keep. |
| [ ] | Extras: OmniScrap Memos, Cutscene Gallery, Credits | HTML L423 | |
| [ ] | ➕ Menu campfire scene (`MENUSCENE`, `buildMenuScene` L17461) | | |
| [ ] | Pause, level-complete summary (bolts, gold n/3, time), victory screen | `setPause` L17584, `completeLevel` L17599, `showVictory` L17629 | |
| [ ] | Save/load (`SAVE_KEY`), settings save (`SETTINGS_KEY`), wipe | `collectSave` L1227, `loadGame` L1255, `wipeProgress` L1312 | Godot save format replaces localStorage. |
| [ ] | Gamepad support: `BTN`, `PAD`, `padNav`, rumble, input glyphs | L1351–1472, `updateInputHints` L17223 | |
| [ ] | Objective marker, banners, hints, gold HUD | `updateObjectiveMarker` L17130, `showBanner` L17098, `showHint` L17105 | |

---

## 24. Music, sound, voice

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Procedural music themes (9): menu, junk, canyon, foundry, zonga, nova, glacius, verdant, boss; combat layer, boss push/pop, beat listeners | `THEMES` L1485, `startMusic` L1629, `updateMusic` L1667 | Galleria uses `nova`; remake may give it its own. |
| [ ] | 38 procedural SFX (shoot … warp) | `sfx` L944ff | |
| [ ] | Stingers: shop jingle, defeat, victory | L1709–1723 | |
| [ ] | Per-planet ambience and soundscape one-shots | `updateAmbience` L9127, `updateSoundscape` | |
| [ ] | Voice: Web Speech TTS with `VOICE_PROFILES` (13), `NPC_VOICE`, `BARK_VOICE`, music ducking, radio filter | `speak` L11138, `voiceProfile` L11083, `startRadio` L11180 | Placeholder TTS (DECISIONS T-009). |

---

## 25. Barks and loose text

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Sprocket `BARKS`: lowhp 3, bolts 3, idle 5, combat 7 | L10988 | Ported in `barks.json`. |
| [ ] | `SPLASH_QUIPS` (6) out-of-bounds lines | L10979 | Ported (`barks.json` → `out_of_bounds`). Per-planet pools in BS_LEVELS. |
| [ ] | `GALLERIA_PA` (3) | L10733 | Ported. |
| [ ] | ➕ **Still not in data:** denizen barks (15 `spawnDenizen` calls, 2 lines each = 30 lines) in `junkProcessor`, `poolScene`, `shiftChange`, `populateLife` L8154–8320, e.g. "Best seat in the yard — front row to the crushin'." and "I'm grandfathered in. GRANDFATHERED." | | Not in `code_lines.json` (the array argument is not a direct string). Port them before the levels are built (suggested IDs `code.populateLife.denizen.<nn>`). These are canon jokes. |
| [ ] | Boss and enemy shouts via `speak()` and `showBark()`: REPO-TRON PA lines, Retention Specialist pitches, Compost King negotiation, Greeter "WELCOME!", "UNPAID FINE!", "It brought a CAMERA CREW", "Repo THIS.", the Blartz cell-lock count, Super Sprocket end bark, memo one-left bark | L6860–7331, L9668, L5029, L4047, L7753 | Ported in `code_lines.json` (`code.<function>.<nn>`, with `src_line`). |
| [ ] | Banner and hint strings (127 banners, 97 hints, e.g. "FORECLOSURE REVERSED — The junkyard stays yours", "DEMONETIZED!", "TRENDING", "NEGOTIATION FAILED — He composts you out of SPITE", "LIQUIDATION MODE"), signs, relay labels, GLAMBOT announcer lines | `showBanner`, `showHint`, `textSign`, `ANNOUNCER` call sites | Ported in `code_lines.json`. Tutorial hints can be rewritten for the new controls; the jokes stay. |
| [ ] | ➕ Sky ad slogans `AD_LINES` (5) and ad boards | L8567 | |
| [ ] | Painted signs (in `code_lines.json`): "RUSTY'S ROW", "FUSES · PARTS · SOUP", "EMPLOYEES MUST SMILE (SMILES ARE BILLABLE)", "RUSTVANE MINING CO-OP — WORKER-OWNED SINCE BEFORE THE RESORT", "BACK IN 5 MIN (ARRESTED)" | `textSign` calls L9412–9528, L9984 | |

---

## 26. Enemies, bosses and ambient life (detail in `BS_ENEMIES.md`)

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Scrapheap: scrapmutt (30 HP, 4.2, pounce, 10 dmg), tinkerturret (55, ambush), vulture (26, dive, steals 5) | `ENEMY_DEFS` L6225 | |
| [ ] | Rustvane: ambassadog (26, 5.6), selfie (30, flash), lifeguard (85, 2.3, lob, heavy) | | |
| [ ] | Foundry: slaggolem (75, plated, heavy), hrdrone (34, paper, hover-home), weldwasp (8, swarm), statue (40, prop, 22 bolts) | | |
| [ ] | Galleria: mannequin (44, 7.2, stalker), couponcrier (28, rally) | | |
| [ ] | Nova: metermaid (34, 6.2), hoaenforcer (70, plated turret), surgedrone (26, surge) | `ENEMY_DEFS_V9` L6173 | |
| [ ] | Glacius: popsicle (48, ambush turret), chillsplit (30, burrow), frostpeddler (30, freeze) | | |
| [ ] | Verdant: gloomstalker (32, cloak), sporelobber (40, spore), pollinator (10, buffer) | | |
| [ ] | Bosses: REPO-TRON 380 HP · `miniboss` "THE CONTENT CREATOR" / "RUSTVANE SENTINEL" 420 · THE ALGORITHM 520 · THE RETENTION SPECIALIST 520 · THE COMPOST KING 560 · GREETER PRIME 540 · EXCAVATRON PRIME 950 | `spawnEnemy` L6270–6276; AI L6840–7533 | ⚠ The Sentinel and the Content Creator are one turret-tank enemy in source (comment says Sentinel L7336, boss bar says CONTENT CREATOR L7341). Grindstone has no separate body; "Grindstone 2.0" exists only as an `ending` line. |
| [ ] | Boss support: BREAK meter (`bossBreak` L7628), beams, shockwaves, boss bar, boss music, arena checkpoint | L7536–7656 | |
| [ ] | Wave arena (Foundry, 2 waves) and Galleria FLASH SALE ambush | `startWaveArena` L10157, `spawnWave` L10186, `buildGalleria` L10657 | ➕ |
| [ ] | ➕ Ambient critters (scrapmouse, oiljelly, glowbird, rocktoad, weldcrab, mothswarm, sandcrab, junglebird) and set pieces (Scrapheap junk processor, Rustvane pool diver, Foundry shift change) | `makeCritter` L8052, `populateLife` L8270, `updateSetpiece` L8228 | Keep as life dressing. |
| [ ] | ➕ Legacy test types `crawler`, `turret`, `flyer` | `makeCrawler` L2439 etc. | Do not port. |

---

## 27. Side modes

### 27.1 ZONGA™ (battle royale, level 3)

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Island: 330 × 330 terrain, beaches, jungle valleys, climbable volcano (~23°), west river, caldera loot, sea out of bounds | `buildZonga` L13126, `TERRAIN_SPECS.zonga` | |
| [ ] | Lobby with contestant count 12 / 25 / 50 | HTML L541, L17743 | ➕ |
| [ ] | Bots from `BOT_NAMES` (53), think loop, kill feed | `makeZBot` L13236, `zBotThink` L13533, `zFeed` L13357 | Brief: smarter bots (flank, retreat, third-party). |
| [ ] | Shrinking Engagement Zone: radii 110 → 76 → 50 → 30 → 14 with 32 / 30 / 27 / 24 / 22 s stages (start r 160) | `ZONGA_STAGES` L13079, `updateZonga` L13431 | |
| [ ] | `SPONSOR_JOKES` (5) on eliminations; GLAMBOT announcer | L13093 | |
| [ ] | Payout: max(25, 600 / place) + 15 per kill; stats (wins, best, kills, matches); gold Sprocket for the first win | `zongaPayout` L13387, `zongaEnd` L13390 | |
| [ ] | Story: `zongaReveal`, `zongaStart`, `zongaGo`, `zongaTruth`; memo.15 PROJECT ZONGA | | |
| [ ] | ⚠ Loot rarity tiers, sponsor supply drops | Not in source | New (brief §8). |

### 27.2 GLAMBOT COLOSSEUM (level 4)

| ✓ | Challenge (`CHALLENGES` L13888) | Rules in source (`arenaWave` L13962, `updateArena` L13996) | Reward |
|---|---|---|---|
| [ ] | Wave Survival "5 waves. Mixed rosters. Zero refunds." | 5 waves, 3 + wave enemies from `ARENA_POOLS.base` | 200 |
| [ ] | Mallet Only "Guns disabled. Percussion approved." | 5 waves, guns off | 220 |
| [ ] | One-Hit KO "Everyone dies in one hit. EVERYONE." | 1 wave, enemies at 1 HP | 250 |
| [ ] | Timed Gauntlet "Clear 12 contestants in 60 seconds." | 12 enemies, 60 s | 250 |
| [ ] | Sponsored Round "Today's sponsor modifies the rules." | 1 wave; 50/50 **LowGrav Cola™** (gravity ×0.38) or **Ad-Block Premium™** (enemies ×2 HP, tinted) | 300 |
| [ ] | Boss Rush "The Sentinel, the Algorithm, the Compost King. Back to back." | 3 rounds from `BOSS_RUSH` L13961 | 450 |
| [ ] | Whiteout Brawl "5 waves on live ice, in a blizzard. Good luck." | 5 waves from `ARENA_POOLS.ice`, slip 1, blizzard from 3 s | 350 |
| [ ] | Bounty Hunt "4 waves. Drop the GOLDEN target fast for the crowd." | 4 waves, one gold target ×2.5 HP, ×1.3 scale | 320 |
| [ ] | Arena build: 44 × 44 floor, 8 m walls, 8 crowd camera drones, 3 ad boards, sealed door; medals and best times saved | `buildArena` L13899, `openArena` L13920, `arenaEnd` L14006 | Brief: Boss Rush gains every campaign boss. |

### 27.3 OMNIGRAND PRIX™ (level 8)

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Tracks (`TRACKS` L14049): **JUNKYARD SPRINT** (3 laps, slip 0.5, rewards 260/150/80) · **RUSTVANE ESSES** (3 laps, 0.45, 300/170/90) · **GLACIUS GLIDE** (3 laps, 0.85, 340/190/100) · **RUSTVANE SKYWAY** (2 laps, flight, 400/220/120) | `buildRaceTrack` L14083, `updateRace` L14268, `updateRaceFlight` L14345 | ➕ The brief says 3 tracks; the source has 4. Port all 4. |
| [ ] | Rivals (`RIVAL_ROSTER` L14071): MS. TORQUE, GLAM-8, RUSTY JR., LEEROY DUBSTEP, THE INTERN (AGAIN) | `makeRival` L14164, `spawnRivals` L14176 | |
| [ ] | Hoverboard, gates, progress, medals, best times, dash = boost ×1.35 | `ensureBoard` L14194, `highlightGate` L14251, `raceFinish` L14358 | Sponsor quips: HUMOR-REVIEW §6 only if approved. |

### 27.4 LOOP RIOT™ (level 10, the `LR` module L14401–17022)

| ✓ | Item | Source | Remake notes |
|---|---|---|---|
| [ ] | Physics constants: HALF_W 6, RAIL_H 1.0, SLAB_T 0.8, G_AIR 36, G_SLOPE 26, ADHESION 10, LOOP_MIN_SPEED 21, DRAG 0.00105, ROLL_RES 0.9, PUSH_ACC 24, PUSH_MAX 44, BOOST_ACC 46, BOOST_MAX 96, NITRO_USE 26, MAX_SPEED 118, SPEED_TO_KMH 1.6, LAPS 3, RIDER_R 0.7 | L14424–14428 | |
| [ ] | Track: hairpins, a full loop, a corkscrew, an unfinished gap, a shortcut fork (FORK_OFF −12, BRANCH_HW 5), track sampling (RAW_STEP 0.25, SAMPLE_STEP 1.0) | L14513, L14769 | |
| [ ] | Crew (`CREW` L14432, 6): BOLT, DENT, MODEL-M, SCUFF, TOASTY, INTERN #4401 with bios; `BOT_SKINS` L15432; `BIO_BOLT` | | |
| [ ] | AI (`AI_PROFILES` L14445: skill, shortcut, grind, aggro), `AI_FLIPS` L16253 | | |
| [ ] | Leagues (`LEAGUES` L14454): SCRAP LEAGUE (skill 0.93, pay 0.6, rep 0.7) · RIOT CUP (1/1/1) · UNRECALLED (1.06/1.6/1.6, locked until the Riot Cup) | | |
| [ ] | Rep ranks (`RANKS` L14459): TEST SUBJECT 0 · PROTOTYPE 500 · FLOOR MODEL 1300 · RECALLED 2600 · UNRECALLABLE 4400 · RIOT LEGEND 7000 | | |
| [ ] | Decks (`DECKS` L14460, 8): Garage Door, Hazard Tape, Galleria Neon, Showroom Chrome, Slag Runner, Void Seam, Mint in Box, Gilded Recall | | |
| [ ] | Recall Notices (`NOTICES` L14471, 14): Signed Nothing, Floor Model Behaviour, Four Thousand and One, Adequate, Peer-Reviewed, Warranty Intact, Ambient Velocity, Load-Bearing Balance, Legally a Flip, Unfinished Business, Unscheduled Flight, Supervisory Capacity, Showroom Ready, Unrecallable (each gives decks, riders or cosmetics) | | |
| [ ] | Tricks: `FLIPS` (7: Kickflip 400, Heelflip 400, Pop Shove-It 300, Varial Kickflip 650, Varial Heelflip 650, 360 Flip 900, Hardflip 750), `GRAB_NAMES` (Mallet Grab, Wrench Tweak, Warranty Void), `GRIND_NAMES` (Boardslide, Lipslide, 5-0 Grind, Nosegrind; plus 50-50 Grind default), `GRIND_YAW`, manuals, combo banking, overclock boost | L15831–15842 | The grind tech is reused by Grind Soles. |
| [ ] | `QUIPS` (Sprocket race lines: bail 3, fall 3, bank 3, loop 1, final 1, lead 1, start 1) | L14502 | |
| [ ] | `LR_ADS` (7), track skin colours `SKIN`, rewards 320/180/100, cup purse 400 | L15177, L14429 | |
| [ ] | Input (`RACE_KEYS`, `In`), auto-pilot (`Auto`), game manager (`GM`) | L16362–16494 | |
| [ ] | Story: `lrSignal`, `lrIntro`, `lrChampion` (black box); `l1_mast` tease | | Riot Mallet is new (brief §5.3). |

---

## 28. Discrepancies

### 28.1 In the brief but NOT found in the source (24)

1. Space-travel **minigame**: the source has a non-interactive transition (skippable).
2. Super Sprocket **Bulwark / Overclock / Zip** modes: one mode in source.
3. **Gold bolts as a currency**: collectible only in source.
4. **K.A.R.E.N. as a gadget-slot summon**: NG+-only superweapon in source.
5. **Rustvane Sentinel and The Content Creator as two bosses**: one enemy in source.
6. Content Creator phases "unboxing / collab / going live" and **camera drones that break its armor**: armor blows off at 50% HP, then 2 selfie "camera crew" adds and a twin beam.
7. **REPO-TRON's magnet steals your weapon** and **compactor walls close in**: the magnet pulls the player and drops crushed cars; the lot walls are static.
8. **The Algorithm overloaded by Cease & Desist notices**: not in source (it summons enforcers and stamps violation zones; "TRENDING" at 50%).
9. **Retention Specialist "cancellation flow" maze phase**: not in source (frost breath, ice spikes, homing "pitch", blizzard gust and chillsplitter adds).
10. **Compost King plumbing puzzle (3 coolant leaks) and mercy ending**: source has a one-time NEGOTIATION pause at 30% HP that fails; the leak fix exists only in `coreVerdant` dialogue and quest `q7b`.
11. **Greeter Prime "WELCOME" sign generators**: not in source (cart charge, welcome-wave shockwave, coupon storm).
12. **Grindstone 2.0 rebrand phase / Grindstone as a fight**: only Excavatron Prime's 3 phases (enrage 50%, LIQUIDATION 25%).
13. **Nova walkways that reverse on HOA violations; lamp-post grapple points**.
14. **Galleria escalators that reverse; Kiosk #7 as a place; Guest Services as a zone** (it is only the cutscene title).
15. **Glacius zones**: Thaw-Queue Hall, Premium Tier wing, blizzard ridge, Recall Storage, Master Freezer (source uses the shared skeleton: arrival shelf, cryo-dome basin, ice-shelf climb, crevasse, core facility, Icebreaker Yard wing).
16. **Nova zones**: HOA District, Permit Office, empty transit loop (source: arrival plaza, raised mid district, tower district, mall apron with THE CONSUMPTION ZONE™ facade, FineTree plaza, Underpass wing).
17. **Verdant zones**: Union Hall (Local 404), Spore Groves (source: swamp flats, root ridge, dead Mega-Harvester region, lagoon basin, Root Cellar wing).
18. **Foundry zones**: BoltBuddy Assembly Line, HR Floor, Executive Bridge (only mentioned in lines).
19. **Rustvane wind updrafts, Infinity Lava Pool as real lava** (the pool is water; "the pool has always been lava" is a joke).
20. **Tether-Hook, Grind Soles, Sprocket Glide** gadgets.
21. **Trophies** (HUMOR-REVIEW names only).
22. **Save point** object (the source autosaves; relays are checkpoints only).
23. **Omega Forge** (Omega is automatic in source).
24. **Sprocket voice-filter cosmetic** and **Riot Mallet**; flyovers for the Foundry and the Galleria.

### 28.2 In the source but NOT in the brief (31)

1. v13 **annex wings** on every planet (Boneyard, Strip Mine, Slag Pits, Underpass, Icebreaker Yard, Root Cellar, Parking Structure): gate → climb + lift → wall-kick shaft → grind → plaza fight → updraft vault with a nanotech upgrade (`buildAnnex` L9240).
2. **Pockets A/B** (sealed slide-under caches and hover perches) on every planet.
3. **Nanotech relay checkpoints** (+25% HP) and boss-mouth virtual checkpoints.
4. Foundry **wave arena** (2 waves, +25 bolts) and Galleria **FLASH SALE** food-court ambush.
5. Extra melee: **air string, launcher, dash stab, punch**.
6. Campaign **grind rails** already on every planet from the start.
7. `firmwareScene` trigger location (Rustvane billboard top).
8. `zongaGo` empty cutscene stub.
9. **Ambient life**: critters, 15 denizens with barks, three set pieces.
10. **309 strings shown from code** (now in `code_lines.json`) plus **30 denizen barks** still to port.
11. Sky ad slogans `AD_LINES`; painted signs.
12. NG+ **bolt multiplier** and player damage ×1.35; roster bleed limited to 3 planets.
13. Zonga lobby sizes **12/25/50**; Zonga champion **gold Sprocket**.
14. Colosseum Sponsored Round gimmicks **LowGrav Cola™** and **Ad-Block Premium™**.
15. Grand Prix **4th track** GLACIUS GLIDE.
16. Shop **Ammo Grab-Bag** and **Nanotech Boost** items; firing-range button.
17. **Statue** bolt piñata and the Intern's "Art Criticism" quest.
18. Foundry **glass elevator**, **gear shaft**, **molten core**, **crane-hook bonus island**.
19. Memo **one-left bark**; post-credits gated on all memos.
20. Weapon **ad on first equip**.
21. Debug settings (collider wireframes, aim-assist view), quality presets, FPS counter.
22. Photo mode **filters and poses**.
23. Retention Specialist's phase-2 **blizzard gust**.
24. Loop Riot **Recall Notices** (14), rep ranks, decks, AI profiles (brief mentions them in passing; the details are only in source).
25. **Klaxon** in the Foundry (`L.klaxon`).
26. Rustvane **waterfall secret**, **umbrella bounce pads**, **floating billboard drones**, rescue umbrellas under the high route.
27. Scrapheap **buried starship hull**, **car-cube stair tower**, **Buried Vault**, **Ridge Lookout**.
28. Galleria **roof deck and skylight drop**, **mezzanine rings**, **storefront sign parkour to the cinema balcony**, **freight tunnel**, **Parking Structure** wing.
29. Verdant has **no Grindstone hologram beat**.
30. Star-map **Loop Riot slot** and its status text; "ALREADY PARKED HERE" joke.
31. Controls overlay screen and the menu campfire scene.

### 28.3 Bugs in the web build (fix, don't port)

1. Duplicate quest IDs `q6a`/`q6b` (Galleria and Verdant) and `q3b` (twice on the Foundry): fixed as `q9a`/`q9b`, `q7a`/`q7b`, `q3c` (T-004).
2. Scrapheap gold bolt index 1 is spawned twice (crane slab L9608 and Buried Vault L9698), so one of the two can never count.
3. Victory screen shows gold "/ 9"; there are 21.
4. The gallery silently skips the 8 story-beat entries in `CUTSCENE_INDEX`.
5. `arrive0`/`arrive1` only play on the second visit, because the unseen flyover always wins the first landing (`finishTravel` L12485).
6. Murk-pool slowdown is per frame (×0.86), so it depends on frame rate.
7. Boss title cards are wired inconsistently: `BOSS_INTRO` maps only CC and Excavatron, so `introAlgorithm` and `introCompost` never play in the campaign (Boss Rush only marks them seen).
8. `NPC_VOICE` lacks `gasket`, `bellhop` and `clerk`, so those three get a random hashed voice.

### 28.4 Decisions the lead should log (proposed)

1. **Post-credits always plays after the ending** (the source requires all 35 memos), because The Fine Print starts from its synergy-screening invite. The memo epilogue still fires when the 35th OmniScrap memo is found, whenever that is.
2. **The epilogue counts the 35 original memos**, not 40, so `cs.epilogue.01` ("Thirty-five internal memos") stays true. Memos 36–40 form a separate "DO NOT DISCUSS" folder in the memo log.
3. **First landing plays the flyover, then the arrival scene**, back to back (fixes bug 5).
4. **The Content Creator survives its fight** (demonetized, not destroyed), matching `l2_glambot` ("I love you. I'm keeping you."). The "co-host" it says Bolt just deleted is the Rustvane Sentinel. Arena layout in BS_LEVELS follows this.
