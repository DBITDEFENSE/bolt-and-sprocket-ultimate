# TERMS & CONDITIONS: Game Design Document (the combined game)

One Godot 4 game with three connected stories:
1. **Bolt & Sprocket (remade):** a third-person action-platformer-shooter.
2. **Gravelight:** a WW2 round-based zombies FPS.
3. **The Fine Print:** an origin story that bridges the two and ends in a crossover zombies map.

This GDD is the top level. Details live in the per-area docs it links to.

| Area | Detail docs |
|---|---|
| Story canon | `CANON.md`, `TIMELINE.md`, `M0_SHARED_FACTS.md` |
| Bolt & Sprocket | `BS_PORT_INVENTORY.md`, `BS_WEAPONS.md`, `BS_ENEMIES.md`, `BS_LEVELS.md`, `data/bs/story/` |
| Gravelight | `gravelight/GDD_GRAVELIGHT.md`, `gravelight/LORE.md`, `CHARACTERS.md`, `ENEMIES.md`, `WEAPONS.md`, `MAPS.md`, `EASTER_EGGS.md`, `VO_SCRIPT.md` |
| The Fine Print | `FINEPRINT_LORE.md`, `FINEPRINT_SCRIPT.md`, `JINGLES.md` |
| Production | `ROADMAP.md`, `DECISIONS.md`, `STORY_CHANGES.md`, `ASSETS.md` |

---

## 1. Pillars
1. **Nobody reads the fine print.** Every system has a satirical or sinister "terms" layer underneath it. In Bolt & Sprocket you laugh at it. In Gravelight it hunts you. The Fine Print makes you read it.
2. **Each world plays at its best.** Bolt & Sprocket must feel at least as good as the web build before anything is "improved." Gravelight keeps the tense, fair round-survival loop that is already built. Neither world's HUD, palette or tone bleeds into the other.
3. **Story you can trace.** One fact can be followed across both worlds through the shared Archive: a memo in the Foundry, a plaque in a Silesian vault, a cabinet in Basel.
4. **Everything is data.** Tuning numbers, every line of text and every unlock rule live in data files. Logic never hardcodes them.
5. **Original, always.** Generic genre mechanics, original names, original assets (`CANON.md` §10, `ASSETS.md`).

## 2. Structure and front end
- **Main menu hub:** a moody 3D scene of Blartz's shop at night. Bolt's ship is outside, and in the corner a dusty Helvetia perk machine hums its jingle, out of place.
- **Menu doors:**

| Door | Contents |
|---|---|
| BOLT & SPROCKET | Campaign, side modes, NG+ |
| GRAVELIGHT | Map select |
| THE FINE PRINT | Chapter select (locked until unlocked) |
| THE ARCHIVE | The shared Archive |
| EXTRAS | Gallery, ads, trophies, photo mode, credits |
| SETTINGS | All settings |

- **Unlock flow** (`data/unlocks.json`, unit-tested):

| Unlocks | When |
|---|---|
| B&S campaign; Gravelight Map 0 | Open from the start |
| Fine Print Ch. 1 | After the B&S ending |
| Ch. 2–3 | After the Map 1 main egg **or** reaching round 20 on Map 1 |
| Ch. 4 | After Ch. 1–3 |
| Ch. 5 / Helvetia Works | After Ch. 4 |
| Bolt, Vendelin, Fine Print Fernet, Overclock Cordial and the Anomalous Inventory option on every Gravelight map | After Ch. 5 |

- **One save profile** (`core/save_profile.gd`): versioned JSON with migrations. It holds three progress tracks plus the shared **Fine Print Archive**: 40 B&S memos, Gravelight intel, and Fine Print documents, cross-linked with "see also."
- **Cross-rewards are cosmetic only, never pay-to-win:**
  - Gravelight camos unlock B&S mallet seams and paints.
  - B&S trophies unlock Gravelight calling cards.
  - Helvetia Works gives the Nachtglas Seam mallet skin and the Violet Recall paint.

## 3. Bolt & Sprocket (remade)

### 3.1 The game
A third-person action-platformer-shooter across seven planets and a prologue, in campaign order:
- the prologue garage
- Scrapheap Junction → Rustvane Canyon → the shield reveal
- the core hunt: Nova Plaza, Glacius Vault and Verdant Sink in any order, with the Grand Galleria opening after the first core
- Core Foundry, then the ending, memo epilogue and post-credits

The star-map order is `CAMPAIGN = [0,1,5,6,7,9,2]`. Bolt fights with a mallet and a 16-gun arsenal while Sprocket floats beside him and comments on everything.

### 3.2 Controls and movement
**Port 1:1 first**, using the original `CONFIG` values as the starting tuning:
- walk 7 / sprint 10.5 with momentum carry
- jump 10.2 and double jump 9.4, with coyote 0.14 s, buffer 0.16 s, apex hang ×0.72 gravity and variable height
- hover (2.8 thrust, 1.5 s drain, 0.9 regen)
- wall slide and kick
- dash (21 m/s for 0.18 s, 0.2 s i-frames)
- dash-jump
- slam and super slam (radius 4.2 / 6.8, damage 30 / 62) and slam bounce
- slide (14.5 m/s) and slide long-jump
- the 3-hit mallet string with hitstop (24 → 28 → 55 damage), and mallet throw

The full list and source keys are in `BS_PORT_INVENTORY.md`.

**Then improve** (all optional, toggled in data):
- a camera collision SpringArm with no clipping
- a soft lock-on toggle
- an air combo (2 hits plus a spike) and a charged ground pound
- the boomerang mallet throw, which hits switches and collects bolts
- combo-tier bolt bonuses
- **gadgets** that open backtracking: the Tether-Hook (Rustvane), Grind Soles (Glacius) and Sprocket Glide (Verdant)

### 3.3 Sprocket
A companion with a body, four moods and opinions, never a silent tool.
- Barks come from `data/bs/story/barks.json`.
- **Super Sprocket Protocol:** the meter fills from damage dealt and combo tier. It picks a mode from the situation (**Bulwark**: shield and taunt; **Overclock**: auto-turret; **Zip**: dashes between enemies) and upgrades at story beats.
- His firmware settings scene becomes an unlockable voice-filter cosmetic.

### 3.4 Arsenal and economy
**Weapons** (`BS_WEAPONS.md`):
- 16 guns: the 12 originals redesigned plus LATE FEE, THE FINE PRINT, HOSTILE TAKEOVER and CLEARANCE RACK.
- 4 mallets: Scrap, Magma, Thunder and the new Riot.
- Each gun has three progression layers:
  1. use-XP levels V1→V5
  2. Blartz Mods (the original Damage / Fire-Rate / Ammo tracks as mod slots, plus one Signature Mod with a choice of two behaviours)
  3. **Omega Evolution** at Blartz's Omega Forge: 2,000 bolts, opened after the Blartz rescue in Core Foundry, so it is an endgame and NG+ chase
- Radial wheel with pages of 8, plus a quick-swap to the last weapon.

**Economy:**
- Bolts drop from enemies and crates, and are spent at Blartz's shop v2 (tabs, deal of the day, wishlist, trade-in, celebration, every original Blartz line).
- Gold bolts buy cosmetics, cheats and skins.
- K.A.R.E.N. becomes a purchasable Gadget-slot summon.

### 3.5 Enemies and bosses
`BS_ENEMIES.md`:
- Each planet keeps its original 3 enemies, redesigned, and gains 1 new one.
- Every enemy has a role, a readable silhouette, a telegraph of at least 0.4 s for heavy hits, a counterplay, a satire joke and an elite variant.
- Bosses: Repo-Tron, Rustvane Sentinel (mini), The Content Creator, The Algorithm, The Retention Specialist, Compost King (mercy ending), Greeter Prime, and Excavatron Prime → Chairman Grindstone.
- Each boss has 3 phases, a GLAMBOT title card, a weak-point BREAK meter and a no-damage trophy.

### 3.6 Levels
`BS_LEVELS.md`:
- Every planet is hub → 3 spokes → boss arena → at least 1 secret.
- Each has a landing pad (ship, Blartz kiosk, save point, star map), a signature traversal mechanic, 3–5 gold bolts, memos, side quests and an optional arena challenge.
- Every room tells the story of who OmniScrap screwed there.
- No invisible walls without a diegetic reason; the original out-of-bounds jokes are kept.

### 3.7 Side modes and extras
- ZONGA™ battle royale
- GLAMBOT COLOSSEUM (8 challenge types; Boss Rush with every boss)
- OMNIGRAND PRIX™ (3 tracks including RUSTVANE SKYWAY, 5 rivals)
- LOOP RIOT™ (the full stunt-skate circuit)
- Firing Range, Photo Mode, NG+ (roster bleed, HP tiers, NG+ Chrome, Omega-tier stock), cosmetics
- the Cutscene Gallery, 17 ad vignettes, trophies
- 19 side quests with Sprocket-bark hints instead of waypoints

### 3.8 Darkmatter seeds (light touch)
- 5 hidden memos (36–40)
- the derelict violet TONIQ™ dispenser in the Galleria, which plays its jingle backwards
- one Darkmatter line for the Retention Specialist
- the Forge dialogue about the seized schematics, and the patent number BLZ-40417

All new text is in `data/bs/story/additions.json`. The synergy-screening invite leads directly into The Fine Print.

## 4. Gravelight
Gravelight is already designed and built in the GRAVELIGHT project (DECISIONS T-007): `gravelight/GDD_GRAVELIGHT.md` and the docs beside it. The amendments in brief §11 are applied in those docs.

**The loop:** rounds → Scrip → doors → power → perks → Crucible → Easter egg.

**Rules and numbers:**
- Start: 500 Scrip, M1911, 2 frags, trench knife.
- Zombie health: 150 at round 1, +100 per round to round 9, then ×1.1 per round.
- Max 24 zombies active.
- Barricades: 6 boards per window.
- 2 weapon slots (3 with Packmule Porter).
- Perk cap: 4.

**Maps:**
- Map 0, Crossroads Inn (a tutorial with the perk cellar for the vertical slice)
- Map 1, Kaltenbrunn (the flagship, with the "Requiem for Kaltenbrunn" egg)
- Map 2, Totenhafen and Map 3, Morgenrot (outlines)
- **Helvetia Works**, the crossover

**Meta:** rank 1–60, prestige 1–10, character dossiers, weapon-mastery camos, the Intel Archive and challenges.

**What §11 adds:**
- Nachtglas is the probe's DARK-GLASS™, but the squad never learns it.
- Helvetia was founded by Herr Viktor Vendelin.
- New human backstories for every perk, plus readable fine-print panels on the machines' backs and plan-ID stencils revealed by an upgraded muzzle flash.
- The Crucible's "MOD. R-E · PAT. PEND. BLZ-40417" plaque.
- 20+ Operator corporate slips.
- Reinholt's "Woman in Violet" deal.
- The Anomalous Inventory crate pool (rare B&S weapons).
- Bolt and Vendelin playable on every map after Helvetia Works.

## 5. The Fine Print
A separate story campaign with its own menu entry, chapter select and Archive section. It explains how the Gravelight machines came to exist and pays off Bolt & Sprocket's sequel bait. Gameplay reuses the two existing engines; there are no new genres.

| Ch. | Title | Engine | Content |
|---|---|---|---|
| 1 | Synergy Screening | B&S third-person, present day | Infiltrate the Retention Spire, Darkmatter HQ, where every door asks you to accept new terms. New enemies: Churn Wardens, Upsell Drones, Exit Survey turrets. Find the Sol-3 file and Vendelin's last transmission. Sable Vantage welcomes them by name. |
| 2 | Field Unit | VendelinController (slower, heavier, stealth), 1938–39 | The probe lands. Vendelin repairs himself, builds a disguise and learns to walk among miners. The first retained miner rises. He walks out of the mine as the Operator boots. |
| 3 | Helvetia Automaten AG | Vendelin vignettes, 1940–44 | The perk story. One vignette per machine: a cabinet build puzzle, a scene with the human formula-maker, and the jingle at the pump organ. Res's night border drives. Ends with the Ledger installation. |
| 4 | Patent Pending | B&S third-person, present day | A heist in Darkmatter's Patent Vault with Blartz. The stolen Forge is revealed. Boss: THE QUARTERLY (Sable Vantage). The misfired delivery pad. |
| 5 | Return Policy | Gravelight first-person | HELVETIA WORKS, the full crossover zombies map, with the "Clause Zero" egg finale. |

**Helvetia Works:**
- **Setting:** Basel, the night of 17–18 March 1945, with Darkmatter's fulfillment barge hanging in a violet fold overhead.
- **Characters:** pick from Dutch, Peg, Deacon, Wren, Bolt and Vendelin.
- **Perks:** all 10 machines, as unpainted prototypes.
- **Enemies:** Audit Rounds with Repossessors, and the Underwriter boss, which prices you by the Scrip you hold.
- **Weapons:** the RETURN POLICY wonder weapon; the Field-Kit OMNI-BLASTER buildable; the Original Omega Forge second tier; the rare B&S crate pool.
- **The finale** mirrors Sprocket's Clause 44 scene. Vendelin overrides Clause 0, cuts the fold, and stays in 1945.

Script and lore: `FINEPRINT_SCRIPT.md`, `FINEPRINT_LORE.md`. Mechanics: `gravelight/MAPS.md`, `gravelight/EASTER_EGGS.md`.

## 6. Shared technology
- **Engine:** Godot 4.7 (Forward+), GDScript with static typing. Target: Windows PC at 60+ FPS on a mid-range GPU, with full keyboard/mouse and controller support from day one.
- **Shared core (`/core`):**
  - damage model with hitboxes, weak points, damage types and status effects (frozen, served, rooted, dancing, gravity-clumped, slowed, burning), knockback and hitstop
  - one weapon framework for both arsenals
  - enemy AI framework with archetypes, LOD and pooling
  - event bus, VO and dialogue manager, cutscene player, interaction system, save profile, settings, input remapping, aim assist, subtitles, accessibility
- **Three controllers:** `ThirdPersonController` (Bolt), `FirstPersonController` (Gravelight; Bolt and Vendelin in zombies) and `VendelinController` (Fine Print Ch. 2–3).
- **Voice:** placeholder TTS through the VOManager, using the original voice profiles. Recorded audio replaces it per line ID. Subtitles always show; voice never replaces text.
- **Music:** the original had a procedural per-planet music engine (`THEMES`, `MUS`, each level's `musicRoot`). Decision for M1: port it to `AudioStreamGenerator`, keeping its per-planet identity. Gravelight keeps its original synthesized score.
- **Testing:** GUT unit tests run headless: economy, weapon levels, Omega and Crucible rules, round scaling, drop logic, quest graphs, save migrations, unlock flow. Each milestone also gets scripted smoke tests.
- **Dev console** in every mode from M1: give bolts/Scrip/weapon, set weapon level, give Omega, god mode, teleport, warp, skip to round N, spawn enemy, trigger cutscene, trigger power-up, complete quest step, navmesh debug, FPS and enemy counter.

## 7. Folder structure
```
/core          shared systems (game, event bus, data, settings, save, VO, unlocks; M1: damage, weapons, ai, input, ui kit)
/bs            Bolt & Sprocket: player, sprocket, weapons, enemies, bosses, planets, shop, modes
/gravelight    zombies: player, weapons, enemies, world objects, maps (migrated from GRAVELIGHT in M2)
/fineprint     origins: chapters, vendelin, darkmatter, helvetia works
/data          all tuning and all story text (bs/, bs_source/, gravelight/, fineprint/, settings_defaults, unlocks)
/ui            main menu hub, HUDs, pause, settings, archive, gallery, progression
/audio /assets /reference /tools /tests /docs
```

## 8. Accessibility
- Subtitles on by default, with speaker names in each character's color.
- Colorblind modes and a screen shake scale (`shakeMul`, all modes).
- Aim-assist stickiness per device; melee assist; full remapping.
- A TTS voice toggle; Gravelight's hint mode; the Classic Rules toggle.
- No information carried by color alone: SERVED, FROZEN and similar statuses get icons as well as tints.
