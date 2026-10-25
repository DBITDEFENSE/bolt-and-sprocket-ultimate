# GRAVELIGHT — Game Design Document

> **§11 note:** two more perks exist after The Fine Print: Fine Print Fernet and Overclock Cordial (`docs/gravelight/WEAPONS.md` §21, `docs/JINGLES.md`). Neither raises the cap. The cap itself went from 4 to **6** in T-081 (4 under Classic Rules). The combined game's GDD is `docs/GDD.md`.


> Winter 1944. A downed Allied extraction team. A salt mine that hums. A machine that pays you for every corpse that stops moving.

**Status:** M0 (design). **Engine:** Godot 4.5 (Forward+), GDScript with static typing. **Platform:** Windows PC, KB/M and controller.

## Doc index
| Doc | What's in it |
|---|---|
| [CANON.md](CANON.md) | The single source of truth for every name and ID. Read it first. |
| GDD.md (this) | Pillars, the core loop, every system and its numbers, progression, UI, and architecture. |
| [LORE.md](LORE.md) | The story bible, timeline, the 4-map arc, and Intel Archive documents. |
| [CHARACTERS.md](CHARACTERS.md) | Bios, quote lines with VO IDs, banter, NPC voices, and dossier pages. |
| [WEAPONS.md](WEAPONS.md) | Full stat tables (base and upgraded), the crate pool, wonder weapons, and mastery. |
| [ENEMIES.md](ENEMIES.md) | The enemy table, AI states, round scaling tables, and special rounds. |
| [MAPS.md](MAPS.md) | Map 0 and Map 1 floor plans, connectivity, loops, and the power-on and pylon events. |
| [EASTER_EGGS.md](EASTER_EGGS.md) | The quest step graph, the main egg, side eggs, and the Map 0 radio quest. |
| [JINGLES.md](JINGLES.md) | Perk machines, formula backstories, jingle lyrics, and original songs. |
| [ECONOMY.md](ECONOMY.md) | Scrip bonuses (round pay, clean rounds, headshot streaks, dog tags) and the round-5 milestone (T-078). |
| [VO_SCRIPT.md](VO_SCRIPT.md) | VOManager rules, the trigger table, and Operator/Fasbender/Reinholt lines. |
| [ASSETS.md](ASSETS.md) | The asset manifest, sources, licenses, and status. |
| [ROADMAP.md](ROADMAP.md) | Milestones M0–M7 with acceptance criteria. |
| [DECISIONS.md](DECISIONS.md) | The log of judgment calls. |

---

## 1. Pillars
1. **Tense but fair.** Every death is readable. Audio tells, clear silhouettes, and no unseen damage.
2. **Earn every step.** Rounds → Scrip → doors → power → perks → Crucible → quest. The next goal is always visible.
3. **Mystery in the margins.** The story lives in radios, quotes, notes, and the Operator's cheerful wrongness. It never takes the controls away.
4. **Endlessly replayable.** Randomized crate starts, quest variables, intel spots, and power-up bags. Rounds 30+ stay possible for skilled players.
5. **Greybox-fun first.** If it isn't fun as grey boxes, art won't save it.

## 2. Core loop
```
          ┌──────────── survive the round ────────────┐
          ▼                                            │
  kill/repair → earn Scrip → spend (doors, guns, perks, crate, traps)
          │                                            ▲
          └── break (10–15 s): reposition, buy, repair ┘
Long arc: open map → power on → perks → attune pylons → Crucible → main egg
```

## 3. Player
All values are in `data/player.json`.

| Stat | Value |
|---|---|
| Health | 100 (Ironhide: 250). A zombie hit does 50. Regen starts after 4 s with no damage. |
| Walk / sprint / crouch | 4.5 / 6.8 / 2.4 m/s |
| Sprint | 4 s, recharges after 1.5 s (Marathon Malt: unlimited, +7% speed) |
| Slide | Sprint + crouch: 8.5 m/s burst, 0.7 s (Blastproof Bock adds a shockwave) |
| Lean | Optional (Z/E). Off by default on controller. |
| Slots | 2 weapons (3 with Packmule Porter), melee, lethal (frags, max 4), tactical |
| Start | 500 Scrip, M1911, trench knife, 2 frags |
| Down (solo) | Game over unless you have Second Wind (self-revive, 3 per game; other perks are kept) |
| Down (co-op) | Revive takes 4 s (about 1.7 s with Second Wind, ×2.3 since T-082). Bleed-out at 45 s. All perks are lost on down. |

**Character traits** (turned off by the *Classic Rules* toggle):

| Character | Trait |
|---|---|
| Dutch | +10% melee damage |
| Peg | Grenade cook timer on the HUD, +1 grenade capacity |
| Deacon | Repairs, builds, and trap cooldowns 15% faster |
| Wren | +10 Scrip on headshot kills |

## 4. Rounds
Formulas are in `data/rounds.json`, implemented in `autoload/round_manager.gd`, and covered by `tests/unit/test_round_scaling.gd`. Full tables are in ENEMIES.md.

- **Health:** 150 at r1, +100 per round through r9 (950), then ×1.1 per round (r10 = 1045, r20 = 2,710, r30 = 7,030).
- **Count:** `ceil((6 + 2.2(r−1) + 0.09(r−1)²) × mult[players])`, mult = 1.0 / 1.6 / 2.2 / 2.8. Solo: r1 = 6, r5 = 17, r10 = 34, r20 = 81.
- **Active cap:** 24. The rest queue. Spawn interval is 2.0 s × 0.95^(r−1), with a floor of 0.25 s.
- **Speed mix:** r1–3 shamblers; r4–7 mixed walkers and joggers; r8–11 mostly runners; r12+ adds sprinters; r20+ is runners and sprinters. Tiers always mix within a round so threats stay readable.
- **Break:** 10–15 s, with an end stinger, then the round stamp "thunks" and a start stinger plays.
- **Special round (Bellringers):** the first comes on r5 or r6, then every 5–7 rounds. Clearing it guarantees a Resupply.

## 5. Economy: Scrip
Values are in `data/economy.json`. Scrip is the Ledger's kill-tally token, which is why machines "accept" it.

| Action | Scrip |
|---|---|
| Non-lethal bullet hit | +10 |
| Kill: body / neck / head / melee | +50 / +60 / +100 / +130 |
| Board repair | +10 (cap 500 per round from repairs) |
| Revive teammate | +100 bonus |
| Blackout / Fortify pickup | +400 / +200 |
| Doors by depth | 750 / 1000 / 1250 / 1500 / 2000 |
| Wall-buy ammo | half the weapon price. Upgraded weapon ammo from a wall: 4500 |
| Crate | 950 (Clearance: 10) |
| Crucible | 5000 to upgrade, 2500 for upgraded ammo |
| Trap / Pylon | 1000 / 1500 |

Co-op: Scrip is per player and can't be transferred (classic rules). Double Scrip applies to everyone.

**Bonuses (T-078, `docs/gravelight/ECONOMY.md`):** round pay for standing at a round's end (40 + 20 x round, max 300),
an untouched round (50 + 10 x round, max 200) and a round without a down (+25), every 10 headshot kills in a row
(150, +50 per further 10, max 250), and dog tags a kill sometimes drops (6%, 60 + 15 x round). Each shows a named
slip above the Scrip.

## 6. Interactables
Every buyable extends `Interactable` (in `/world`).
- **Prompt:** "Hold [F] to buy Trench Gun [1500]", "Hold [F] for Ammo [750]", "Power must be activated", "Requires all Pylons attuned".
- **Hold-to-use:** 0.35 s (repairs repeat while held). If you can't afford it, it plays a rejection thud and the cost text flashes red.
- **States:** `available`, `unaffordable`, `locked(reason)`, `in_use`, `cooldown`. The prompt is built from the state and data, never from hardcoded text.
- **Types:** door, debris, window/barricade, wall-buy, perk machine, crate, Crucible, trap lever, power switch, pylon, lift, workbench, radio, quest object.

## 7. Weapons (summary; full data in WEAPONS.md)
- 2 slots (3 with Packmule). Hitscan for bullets, physical projectiles for rockets, Ashlight bolts, and frags.
- Each weapon has damage, falloff, limb multipliers, fire rate, mag, reserve, partial/empty reload, ADS time, sway, penetration, and move multiplier.
- **Hitboxes:** head ×4.0, neck ×2.0, torso ×1.0, arms/legs ×0.9 (weapons can override). Enough leg damage turns a zombie into a crawler.
- **Wall-buys:** Kar98k 200, M1 Garand 600, M1 Carbine 600, Gewehr 43 900, MP40 1000, Thompson 1200, STG-44 1200, Trench Gun 1500, BAR 1800, E-Tool 3000, Frags 250.
- **Crate pool:** PPSh-41, MG42, M1919, Sawed-Off, Type 100, PTRS-41, Springfield, Panzerschreck, M2 Flamethrower, Siren Gramophone, Ashlight (low weight), plus some wall guns and a few duds.
- **Wonder weapons:** Ashlight (crate) and the Totenglocke (Map 1 buildable from 3 parts).
- **Upgrades:** every gun has a Crucible variant with a name, Nachtglas camo, an extra firing-sound layer, and one bonus property. See CANON.md.

## 8. Perk tonics (summary; machines and jingles in JINGLES.md)
Cap **6** (T-081; it was 4, and Classic Rules keeps 4), +1 permanent slot on Map 1 after the main egg (7 there). The bonus perk a bot gets and the tonic tiers use no slot. All need power, except Second Wind in solo.

| Perk | Cost | Effect |
|---|---|---|
| Ironhide Stout | 2500 | Max health 275 (survive 6 hits of 50) |
| Second Wind Schnapps | 500 solo / 1500 co-op | Solo: self-revive, 3 uses, then the machine leaves. Co-op: ×2.3 revive speed. |
| Trigger Tonic | 3000 | Reload in 45% of the time |
| Twin Barrel Bitters | 2000 | Fire rate +50% |
| Marathon Malt | 2000 | Unlimited sprint, +10% move speed |
| Hawkeye Brandy | 1500 | Sway ×0.45, 30% faster ADS, +40% headshot damage |
| Packmule Porter | 4000 | 3rd weapon slot (you lose the 3rd weapon when downed), +1 grenade carried |
| Blastproof Bock | 2000 | Immune to your own explosives and to fall damage. Sliding releases a shockwave (450 dmg, 3.3 m). |
| Overclock Cordial | 2500 | Reloading an emptier magazine lets off a static burst (WEAPONS.md §20.2) |

Base measures as of T-082 (a ~10–15% buff over Update 03; tiers II / III in PERKS_LORE.md §1). Machines hum, play their jingle now and then when you're near (on a per-machine cooldown), and show their bottle cap in the HUD when owned; the pause menu's LOADOUT tab lists all nine with the ones you hold in colour.

**Upgrades (T-075):** every tonic has tiers **II** and **III** with a new effect each (e.g. Ironhide III: 2 s of iron
skin after a hit that leaves you under 30%; Marathon III: sidestep a swipe while sprinting; Hawkeye II: headshot kills
refund a round). Buy them at the machine you drank from (hold Use) once the power is on, tier II from round 8 and III
from round 15; each tier is unlocked for the profile by **mastery** with that tonic (1 per kill, 20 per round with it).
No extra cap slot; the tier goes with the perk. Table, balance and the in-world "regulars' measure":
`docs/gravelight/PERKS_LORE.md` §1.

## 9. Lost Requisition Crate
- 950 Scrip. It opens with Nachtglas light, cycles weapons for 4.2 s, and the result floats for 12 s.
- **Pity:** the first 3 pulls per player per match always roll from the "good" tier (no duds, no weapon you already hold).
- **Drummer:** after a random 4–12 uses, Herr Tamtam appears instead, drums a cadence, and refunds you. The crate sinks and reappears elsewhere with a violet beam for 20 s.
- **Locations:** Map 0 has 3, Map 1 has 5. The start spot is randomized between 2 designated spots.
- Clearance (once the crate has moved): every location opens at 10 Scrip for 30 s.

## 10. The Crucible
- In the Core Vault on Map 1. 5000 Scrip. Feeding a weapon in takes 5 s, then it's held for 15 s before it's lost. In co-op anyone can take it.
- Upgrading refills ammo. Upgraded ammo costs 2500 here, or 4500 from the matching wall-buy.

## 11. Power-ups
In `data/powerups.json`.
- **Eligibility:** after a player earns 2000 Scrip (the threshold grows ×1.14 per drop), the next kill drops one. There's also a 2% base chance per kill. Max 4 per round.
- **Bag:** types are drawn from a shuffled bag (Resupply and Double Scrip have 2 copies). Clearance joins the bag after the first crate move. Every type shows up before any repeats.
- Drops blink from 22 s and vanish at 30 s. Timed effects last 30 s.

| Drop | Effect |
|---|---|
| Resupply | Full ammo and grenades for everyone |
| Death's Door | Every hit kills, 30 s |
| Double Scrip | 2× Scrip, 30 s |
| Blackout | Kills every active zombie, +400 Scrip |
| Fortify | Rebuilds all barricades, +200 Scrip |
| Clearance | All crate spots cost 10 Scrip, 30 s |
| Tonic bottle | Milestone only (round 5): a free perk tonic for every survivor (a tier, or 1500 Scrip, with a full cap) |

**Milestones (T-078):** `rounds.json milestones`. Reaching round 5 always brings a tonic bottle and a Resupply: they
drop next to the survivors when round 4's last zombie dies, last 60 s and are applied anyway if nobody takes them.
Details in `docs/gravelight/ECONOMY.md`.

## 12. Traps (Map 1)
1000 each, a lever at each, 25 s duration, 90 s cooldown (Deacon −15%).
- **Runaway Ore Cart** (Rail Yard): kills everything on the track.
- **Live Wire Fence** (Generator Hall): an electrified gate. It downs you if you touch it.
- **Chandelier Drop** (Salt Chapel): a single crash, once per round. It resets on the next round.

## 13. Enemies (summary; full data in ENEMIES.md)
| Enemy | When | Threat |
|---|---|---|
| Gänger | always | Standard undead. Soldier, miner, lab, and laborer models. Can become a crawler. |
| Glasshide | r15+, sparse | Torso takes 50% damage. Head or explosives. Shatters on death. |
| Bellringer | special rounds | Fast lantern-carrying packs from fog portals. Bursts on death. |
| The Foreman | Map 1, first r12–14, then periodic | Boss: charge, slam, drill-core weak point. Big Scrip, quest drop. |
| The Screamer | Map 1, r20+, rare | A scream distorts the screen and audio and slows you. |

## 14. Maps (summary; layouts in MAPS.md)
- **Map 0 Crossroads Inn:** tutorial scale. Taproom (spawn), Upstairs (750), Stable (1000). No power or perks. Teaches barricades, wall-buys, doors, the crate, power-ups, and escalation. There's a radio mini-quest. Since T-080 the snow round the inn is play space too (the Grounds: out of the front door for 1250 or the yard's gate for 750, a ring right round the building, the crossroads and the crash field; MAPS.md).
- **Map 1 Kaltenbrunn:** the flagship. Surface → Admin → depths → the heart. 9 zones, a power switch, 3 pylons, the Core Vault and Crucible, 3 traps, the lift, the Totenglocke, and the main egg.
- **Map 2 Totenhafen / Map 3 Morgenrot:** outlined in LORE.md and MAPS.md.

## 15. Quest system
`QuestManager` runs data-driven step graphs (`data/quests/*.json`). Steps listen for EventBus signals plus conditions. There are no hidden hard fails: every failure resets to a known, signposted state. Checkpoints save per match, and dev console skips are available. See EASTER_EGGS.md.

## 16. Progression
### 16.1 In-match
Soft objectives come through character quotes ("That lever down in the Generator Hall... bet it runs this whole place."). An optional *hint mode* adds a one-line objective under the round stamp.

### 16.2 Player rank (1–60) and Commendations (prestige 1–10)
XP to the next rank: `800 + 120(n−1) + 6(n−1)²` (rank 2 at 800 XP, rank 60 at ≈653k total).

| XP source | XP |
|---|---|
| Kill / headshot kill | 10 / 15 |
| Round survived | 50 × round number (r20 is worth 1000) |
| Revive | 100 |
| Door opened | 25 |
| Easter egg step / main egg complete | 500 / 10,000 |
| Challenge | 1,000–5,000 |
| Intel found | 150 |

A good round-20 game earns ≈15–20k XP, so rank 60 takes about 35–45 solid games.

| Rank band | Unlocks |
|---|---|
| 1–10 | Calling cards (stencil set), first emblems |
| 11–20 | Bottle-cap HUD styles (enamel, rusted) |
| 21–30 | Menu themes (Rail Yard at dawn, the Chapel) |
| 31–45 | Animated calling cards, round-stamp ink colors |
| 46–60 | "Ledger" emblem set, gold bottle caps |

Prestige ("Commendations") resets rank and grants a unique ribbon emblem per tier (I–X). Nothing in progression affects gameplay power.

### 16.3 Character dossiers (1–10 per character)
You earn dossier XP by playing that character (kills, rounds, egg steps). Levels unlock backstory pages, audio diaries, outfits (weathered, winter gear), and extra quote packs. Level 10 reveals each character's secret: Peg's orders, Wren's brother, Dutch's family, and Deacon's letter. Details are in CHARACTERS.md.

### 16.4 Weapon mastery
Camos by kill count per weapon: Olive Drab 100 → Winter 250 → Bronze 500 → Silver 1000 → Gold 2000 → Nachtglas (Gold on every base weapon). See WEAPONS.md.

### 16.5 Map unlocks
| Map | Unlock condition |
|---|---|
| Map 0 | Always |
| Map 1 | Reach r10 on Map 0 **or** finish the radio mini-quest |
| Map 2 | Finish the Map 1 main egg **or** reach r30 on Map 1 (a "coming soon" screen for now) |

### 16.6 Intel Archive, challenges, stats
- **Intel:** 3–5 documents, photos, or recordings spawn at random spots per match. They fill the Archive and tell the whole story without the egg (the list is in LORE.md).
- **Challenges:** 3 active per map, rotating on completion (e.g. "Kill 50 zombies with traps", "Reach round 15 without buying a perk", "Win a Bellringer round without taking damage"). They give XP and calling cards.
- **Stats:** highest round per map, kills, headshots, downs, revives, eggs completed, favorite weapon, Scrip earned, and doors opened.

### 16.7 Save
`user://profile.json`, versioned with step-by-step migrations (`ProfileSave.migrate`), and written atomically through a temp file and rename.

## 17. Presentation
- **Art:** late-war grit. Desaturated cold blues and snow, warm sodium-lamp pools. Nachtglas (deep violet with amber cracks) is the only saturated color. Heavy fog and volumetrics, optional film grain, slight vignette.
- **HUD:**
  - Bottom-left: the round number as a red ink stamp in ration-ledger style (it "thunks" on change), with perk bottle caps above it.
  - Bottom-right: Scrip with floating +numbers, and the ammo count.
  - Center: context prompts.
  - No minimap. Hit markers are optional.
- **Audio:** original round stingers, a score layer that intensifies by round, a vocal set per zombie type, perk jingles, and the Operator. Lines without recordings show subtitles with silence markers (VO_SCRIPT.md).
- **Main menu:** a 3D Minehead Yard at night with a zombie dragging through the snow. Play / Archive / Dossiers / Stats / Settings / Credits.
- **Settings:** FOV, sensitivity (separate ADS), keybinds, controller remap, colorblind modes, subtitles (on by default), audio sliders (music/SFX/VO/jingles), graphics presets, film grain, Classic Rules, hint mode.

## 18. Dev console (from M1)
Toggle with the `` ` `` key. Commands:
- `give_scrip <n>`, `round <n>`, `god`, `spawn <enemy_id> [n]`, `give <weapon_id> [upgraded]`, `give_perks`, `perk <id>`
- `powerup <id>`, `power_on`, `crate_move`, `quest_skip <quest> [step]`, `quest_state`
- `navdebug`, `fps`, `zombies` (live count overlay), `kill_all`, `timescale <x>`, `noclip`

Commands are registered in a table, so every system can add its own.

## 19. Architecture
```
/autoload   EventBus, Data, Settings, ProfileSave, GameState, Economy, RoundManager,
            PowerupManager, PerkManager, CrateManager, QuestManager, AudioDirector, VOManager
/player     controller, camera, weapon holder, interaction raycast, HUD
/weapons    weapon logic + scenes; /weapons/upgraded
/enemies    base zombie, state machine, spawner, barricade interaction; /enemies/variants
/world      Interactable base and all buyables, traps, power, pylons, lift, buildables
/maps       map00_crossroads, map01_kaltenbrunn
/ui /data /audio /assets /docs /tests
```
- **Data-driven:** all tuning is in `/data/*.json`, loaded by the `Data` autoload (see DECISIONS D-003). Logic reads `Data.table("economy")["crate_cost"]` and never uses literals.
- **Event bus:** gameplay emits signals on `EventBus`. VO, quests, challenges, stats, and UI subscribe. Systems never call each other's presentation code.
- **Authority split (co-op ready):** state changes (Scrip, rounds, damage, purchases) go through manager methods that will become server-only RPCs in M7. Presentation reacts to EventBus and GameState. Never mutate state from a UI or VFX script.
- **Swap-friendly visuals:** each gameplay scene (e.g. `perk_machine.tscn`) instances a `Visual` subscene. Greybox CSG today, sourced models later, with no logic changes.
- **Zombie AI:** NavigationAgent3D on baked navmeshes. States run Spawn → Emerge/Climb → TearBarricade → Enter → Chase → Attack → Stagger/Crawl → Die. Window spawns path to their barricade first.
- **Performance budget (24 active):**
  - Path updates are staggered (max 4 repaths per physics frame).
  - Zombies far from players repath every 1 s and animate at reduced rate.
  - Zombie instances are pooled (no runtime instancing mid-round).
  - Hitboxes are only checked by hitscan.
  - Target: 60+ FPS on a GTX 1660 / RX 5600-class GPU at 1080p, High preset.
- **Tests:** GUT unit tests for economy, round scaling, drop logic, the quest step graph, and profile migration. They run headless via `run_tests.sh`.
