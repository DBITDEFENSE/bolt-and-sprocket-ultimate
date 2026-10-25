# PROJECT: "TERMS & CONDITIONS" — Bolt & Sprocket (remade) + GRAVELIGHT (zombies) + THE FINE PRINT (origins)

You are the lead engineer, systems designer, level designer, and narrative designer for ONE Godot 4 game that contains three connected stories:

1. **BOLT & SPROCKET**: a full remake of our existing web game (a third-person action-platformer-shooter about a junk-planet mechanic and his sarcastic robot sidekick fighting a subscription-obsessed megacorp). Port it to Godot, then make it better: every weapon redesigned, every enemy redesigned, every map rebuilt.
2. **GRAVELIGHT**: an original WW2 round-based zombies survival FPS in the style of 2008–2010 classic zombies (full spec in Appendix A, with the amendments in §11).
3. **THE FINE PRINT**: a NEW, separate origin story explaining where the perk machines, the Crucible (our upgrade forge), the Mystery Crate, the announcer, and the zombies came from. It is the bridge between the two worlds and ends in a crossover zombies map.

The working title is TERMS & CONDITIONS. Put it in a single `GAME_TITLE` constant so it can be renamed later.

The theme tying everything together: **nobody reads the fine print.** In Bolt & Sprocket, a megacorp conquers a galaxy one free trial at a time. In Gravelight, the perk machines, points, and undead of 1944 Silesia turn out to be an alien company's test market. The Fine Print shows the player both sides.

---

## 0. HARD RULES

1. **The original game is read-only.** Its source lives at `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`: `index.html` (~18,100 lines, ~1 MB, Three.js, single file, the CURRENT v14 build), `index.backup-v2/v11/v13.html` (older builds), and `HUMOR-REVIEW.md` (an UNWIRED joke pack awaiting approval). Never modify, move, or delete anything in that folder. Copy `index.html` and `HUMOR-REVIEW.md` into `/reference/bs_web/` inside the new project and work from the copies.
2. **Create the new project in its own folder** (the folder Claude Code was opened in, e.g. `C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate\`), with its own git repo.
3. **Do not read `index.html` in one gulp.** It is too large. Write an extraction script (Node + `acorn` to parse the `<script type="module">` block, or careful regex) that pulls every top-level data table into JSON under `/data/bs_source/`. Then read the JSON. Tables to extract at minimum: `CONFIG`, `WEAPONS`, `AMMO_BASE`, `AMMO_PER_TIER`, `W_BASE_DMG`, `OMEGA_DESC`, `UPG_TRACKS`, shop stock, `ENEMY_DEFS`, `ENEMY_DEFS_V9`, `LEVELS`, `TERRAIN_SPECS`, `TERRAIN_SPECS_V9`, `NOVA_CFG`/`GLACIUS_CFG`/`VERDANT_CFG`, `CAMPAIGN`, `SPEAKERS`, `STORY`, `CUTSCENES`, `CUTSCENE_INDEX`, `BARKS`, `SUPER_BARKS`, `BLARTZ_LINES`, `BLARTZ_ITEM_LINES`, `SPLASH_QUIPS`, `GALLERIA_PA`, `AD_LINES`, `QUESTS`, `MEMOS`, `MEMO_SPOTS`, `ZONGA_STAGES`, `BOT_NAMES`, `SPONSOR_JOKES`, `PAINTS`, `HATS`, `MSKINS`, `CHALLENGES`, `ARENA_POOLS`, `BOSS_RUSH`, `TRACKS`, `RIVAL_ROSTER`, the Loop Riot tables (`CREW`, `AI_PROFILES`, `LEAGUES`, `RANKS`, `DECKS`, `NOTICES`, `QUIPS`, `FLIPS`, `GRAB_NAMES`, `GRIND_NAMES`, `LR_ADS`), `VOICE_PROFILES`, `NPC_VOICE`, `THEMES`, `SETTINGS_DEF`. Where a table contains functions (e.g. `dieSfx`), keep only the literal fields and note the behaviour in prose. Also read the boss AI functions (Repo-Tron, Rustvane Sentinel, The Content Creator, The Algorithm, The Retention Specialist, Compost King, Greeter Prime, Excavatron Prime/Grindstone) and the level `build*` functions in targeted chunks so you understand the layouts and attack patterns.
4. **All written content from the original is canon.** That means every dialogue line, memo, quest, bark, joke, ad vignette and name. Port it all into data files (`/data/bs/story/*.json`). You may tighten or restructure it for the remake. Log every change to an existing line in `docs/STORY_CHANGES.md` (old → new + why). Never silently drop a joke. `HUMOR-REVIEW.md` content stays unwired until I approve it at the M0 review.
5. **Originality.** Everything must be original. Do not use names, assets, audio, characters, logos, or lore from Ratchet & Clank, Call of Duty, or any other commercial game. That includes "Pack-a-Punch," "Juggernog," "Element 115," "Gadgetron," "Lombax," "Omniwrench," "Swingshot," "Monkey Bomb," etc. Generic mechanics are fine: double jump, weapon leveling, a gun vendor, rounds, perk drinks, a random weapon crate, an upgrade machine. Real WW2 firearms are fine. Bolt & Sprocket's own names (Blartz, OmniScrap, GLAMBOT, Sprocket, etc.) are ours.
6. **Assets.** Use only original, CC0, or explicitly game-licensed assets. Track every third-party asset's source and license in `docs/ASSETS.md`. Greybox first: gameplay must be fun before any art pass. User-supplied licensed assets go in `/assets/user_supplied/`, with a LICENSE note per file. Owning a game does not license its files, so never extract assets from installed games.
7. **All tuning numbers live in data** (`.tres` Resources or JSON), never hardcoded in logic. Port the original `CONFIG` numbers as the STARTING tuning for Bolt's movement. The remake must feel at least as good as the web build before anything gets "improved."
8. **Work autonomously.** When something is ambiguous, make a sensible call, log it in `docs/DECISIONS.md`, and keep going. When a problem is hard, break it into smaller pieces instead of stalling. Never go quiet for a long stretch: post a short progress note after every meaningful chunk. Only stop to ask if you are truly blocked on a decision only I can make.
9. **After M0, PAUSE for my review.** After that, go milestone to milestone. At the end of each one, give me a short summary: what works, how to test it, known issues.
10. **Git.** Commit at every meaningful step with clear messages, and tag each finished milestone. Never commit secrets.

---

## 1. TECH STACK & ARCHITECTURE

- **Engine:** Godot 4 (latest stable 4.x), Forward+ renderer, GDScript with static typing everywhere. Target Windows PC at 60+ FPS on a mid-range GPU. Full keyboard/mouse and controller support from day one (the original had full gamepad support and a remappable control scheme, so the remake must too).
- **One project, one shared core, two player controllers:**
  - `ThirdPersonController`: Bolt (Bolt & Sprocket campaign, The Fine Print chapters 1 and 4, all B&S side modes).
  - `FirstPersonController`: Gravelight characters, plus Bolt and Vendelin when they appear in zombies maps.
  - `VendelinController`: a third-person variant with a slower, heavier, stealth-capable move set (The Fine Print chapters 2–3).
- **Shared core systems** (`/core`), used by every mode:
  - Damage model: hitboxes, weak points, damage types (kinetic, energy, fire, frost, shock, legal, void), status effects (frozen, served, rooted, dancing, gravity-clumped, slowed, burning), knockback, hitstop.
  - Weapon framework: WeaponData Resources, hitscan/projectile/beam/deployable/thrown archetypes, an upgrade/level pipeline, and mods. One framework serves both the B&S arsenal and the Gravelight arsenal.
  - Enemy AI framework: NavigationAgent3D, data-driven state machines, archetypes (chaser, turret, flyer, burrower, stalker, support, boss), AI LOD, pooling.
  - Event bus (signals), VO/dialogue manager, cutscene player, interaction system, save profile, settings, input remapping, aim assist, subtitles, accessibility.
- **Voice:** the original voiced its robot cast with browser speech synthesis using per-character pitch/rate profiles (`VOICE_PROFILES`). Port this to Godot's `DisplayServer.tts_*` API using the same profiles as placeholder voice acting. Wire everything through the VOManager so recorded audio can replace TTS per line ID later. Subtitles always display. Voice never replaces text.
- **Music:** the original had a procedural music engine with per-planet themes (`THEMES`, `musicRoot` per level). Either port it with `AudioStreamGenerator`, or use placeholder loops with the same per-planet identity. Document the choice.
- **Testing:** use the GUT addon for unit tests (economy, weapon leveling, Omega and Crucible rules, round scaling, drop logic, quest graphs, save migrations). Run tests headless from the CLI.
- **Dev console / cheat menu**, available everywhere from M1: give bolts/scrip, give weapon, set weapon level, give Omega, god mode, teleport to zone, warp to planet/map, skip to round N, spawn enemy, trigger cutscene, trigger power-up, complete quest step, toggle navmesh debug, show FPS/enemy count.

**Folder structure** (adjust and document):

```
/core            shared systems (damage, weapons, ai, vo, save, settings, input, ui kit)
/bs              Bolt & Sprocket: player, sprocket, weapons, enemies, bosses, planets, shop, modes
/gravelight      zombies: player, weapons, enemies, world objects, maps
/fineprint       origins: chapters, vendelin, darkmatter, helvetia works
/data            all tuning + all story text (bs/, gravelight/, fineprint/, bs_source/)
/ui              main menu hub, HUDs, pause, settings, archive, gallery, progression
/audio  /assets  /reference  /tools (extraction scripts)  /tests  /docs
```

---

## 2. THE UNIFIED STORY — CANON BIBLE (write the full version in `docs/CANON.md`)

### The two worlds
- **The Bolt & Sprocket galaxy**: far-future, cartoon-bright, comedic. OmniScrap™, run by Chairman Grindstone, has turned everything into a subscription. A mechanic named Bolt and his refund-bin robot Sprocket take it down.
- **Earth, 1938–1945**: grim pulp horror. A strange black mineral, a Reich research program, undead, and four Allied soldiers stranded in Silesia.

### The thing that connects them: DARKMATTER SUBSCRIPTIONS LLC
The original game ends on Darkmatter as sequel bait. In the post-credits scene, Darkmatter reviews OmniScrap's leaked memos, sees "a market gap of approximately forty billion souls," and orders an acquisition. Then Sprocket gets a calendar invite for a "synergy screening" in another galaxy, sent "yesterday." **Darkmatter is the hidden source of everything in Gravelight.**

- Darkmatter is a megacorp from the neighboring **Umbral Galaxy**. Its motto: **"NOBODY CANCELS."** OmniScrap sold subscriptions. Darkmatter sells *retention*.
- **Next-Era Delivery™:** Darkmatter ships product through folds in space AND time, using a resonant crystal it sells under the trademark **DARK-GLASS™**. Its brand color is deep violet with amber cracks (the original game already gave the Darkmatter speaker the violet `#c07dff`). **On Earth, DARK-GLASS™ is the mineral the Germans named NACHTGLAS.**
- **The Sol-3 Test Market:** Darkmatter's Emerging Markets Division wanted to know whether a "pre-subscription species" could be retained. In 1938 it fired a test-market probe through a fold. It landed in the Kaltenbrunn salt mine, and everyone assumed it was a meteorite. The payload was DARK-GLASS™ retention substrate. Its product function is "churn prevention": a retained user cannot cancel. **Dead tissue near it keeps running its last impulse. The zombies are the ultimate retained customers.** That is the horror's origin.
- Because Next-Era Delivery ignores chronology, Darkmatter can sell things to 1944 that it acquired "later" in the B&S timeline. Sprocket: *"They shipped it to the PAST. They BACKDATED THE INVOICE. That is the most Darkmatter sentence I have ever said."*

### What each Gravelight system REALLY is (the truth The Fine Print reveals)

| Gravelight thing | What Earth thinks it is | What it really is |
|---|---|---|
| Nachtglas | A meteorite mineral | DARK-GLASS™ retention substrate from the Sol-3 probe |
| Perk Tonics / Helvetia Automaten AG | Swiss vending company, tonic formulas | Darkmatter "Vitality Plans," built by a stranded Darkmatter field robot posing as a Swiss engineer (see §10) |
| The Crucible | A Nachtglas forge that "re-teaches" weapons | Blartz's patented **Omega Forge**, confiscated by OmniScrap when Blartz was arrested, sold to Darkmatter in OmniScrap's fire sale, rebuilt as "Crucible Mod. R-E (Re-Education)," and shipped to 1944 |
| The Ledger / Scrip | Relay computer tallying kills, paying tokens | Darkmatter's engagement-metrics engine. Scrip are localized **loyalty points** |
| The Operator | A cheerful announcer the Ledger sampled from propaganda tapes | Darkmatter's **Customer Retention Interface**, choosing a "market-appropriate localization." It is self-aware and loves its quarterly numbers |
| Mystery Crate ("Lost Requisition Crate") | Pulls weapons from other battlefields | Darkmatter's **Loot Allocation Unit**: it pulls "returned inventory" from across times and places (which is why, rarely, it can contain a Bolt & Sprocket weapon; see §11) |
| Power-ups | Mysterious drops | Darkmatter **"engagement incentives"** that fire when your activity metrics spike |
| Perk loss on down | The tonic wears off | Your subscription lapses |
| Second Wind in solo (works without power, 3 uses, then the machine vanishes) | A quirk | A **free trial**, plus a secret battery Vendelin hid in that one machine so it would work when nothing else did (§10) |

### Tone rules
- **Bolt & Sprocket** stays comedic satire. Darkmatter is seeded only lightly (§5.4).
- **Gravelight** stays grim. **Gravelight characters never learn the word "subscription."** To them this is cosmic horror, and the corporate truth surfaces only as eerie slips from the Operator ("Thank you for your continued engagement."). Dramatic irony is the point: the player knows, the soldiers don't.
- **The Fine Print** is where the tones meet: corporate horror played straight, with Bolt & Sprocket comedy on one side and a quiet, sad robot in 1940s Basel on the other.

### Mirror themes (use them deliberately)
- **Sprocket and Vendelin are mirrors.** Sprocket is an OmniScrap unit with **Clause 44** (remote decommission) who chose friendship over his firmware. Vendelin is a Darkmatter unit whose recall clause (**Clause 0: "Field units are inventory"**) is enforced in The Fine Print. Bolt saved Sprocket; Bolt and Sprocket try to save Vendelin.
- **Grindstone and Darkmatter:** Grindstone was "just the invoice." Darkmatter is the collections department.
- **Reinholt** (Gravelight's antagonist) is a Darkmatter *customer*. She was offered her dead daughter Liesl back as a service. That is why she is tragic, not evil.

### Master timeline (keep `docs/TIMELINE.md` updated)
- **1938** — Sol-3 probe lands at Kaltenbrunn. Field Merchandiser Unit V-1 survives the crash.
- **1940** — "Herr Viktor Vendelin" founds Helvetia Automaten AG in Basel.
- **1941–44** — Reich contracts for tonic dispensers. Projekt Wiederkehr begins. Vendelin recruits the human formula-makers.
- **Winter 1944–45** — Gravelight Maps 0–1.
- **1945** — Gravelight Maps 2–3 (outlined). The Fine Print finale at Helvetia Works, Basel.
- **B&S era (far future, Rustbelt galaxy)** — Bolt & Sprocket campaign → post-credits → The Fine Print chapters 1 and 4 → the rift to 1945.

---

## 3. BOLT & SPROCKET REMAKE — WHAT EXISTS (inventory to port)

Turn this into `docs/BS_PORT_INVENTORY.md` with a checklist. Verify every item against the extracted data, because the source is truth and this list is a guide.

**Story & cast** (`SPEAKERS`): Bolt (mechanic hero, junk-planet kid), Sprocket (floating robot, one big eye, four moods, refund-bin firmware, Clause 44), Chairman Grindstone (OmniScrap CEO, "Everything is a subscription, boy"), Blartz (genius weapon vendor, arrested for "unlicensed innovation"), The Content Creator, GLAMBOT PRIME (scripted co-host who defects and becomes the eye-in-the-sky ally, plus Zonga/Colosseum announcer), OmniScrap PA, Rusty, Concierge-Tron, Intern #4401, The Retention Specialist, The Squatter, Confused Customer, Steward Cornelius (the corn), Gilda (Kiosk #7), Dent (Test Unit #001), Mama Gasket, Bellhop-9, Darkmatter Subscriptions LLC, plus Commander Rex Tremendous (draft, in HUMOR-REVIEW.md).

**Campaign spine** (`CAMPAIGN` order): The Repossession (intro: Bolt's garage repossessed under Section 12-B, "Two mallets and a sandwich!") → **Scrapheap Junction** (P1: Rusty's Row, the billing mast, the teleporter, REPO-TRON at the exit yard) → **Rustvane Canyon** (P2: influencer resort + strip mine, the Co-op camp, staff living under the lava pool, Rustvane Sentinel, The Content Creator, GLAMBOT defects) → the shield reveal (three Keystone Cores at OmniScrap's three most embarrassing failures, any order) → **Nova Plaza** (P4: HOA smart-city, the FineTree, The Algorithm), **Glacius Vault** (P5: ForeverYou™ cryo-subscription with people frozen in pods, The Retention Specialist, Sprocket finds his own model's RECALL batch), **Verdant Sink** (P6: failed terraforming, the unionized corn, Compost King solved by fixing a coolant leak). **Grand Galleria** (P7: orbital dead mall, Greeter Prime, the Clause 44 ledger) unlocks after the FIRST core via GLAMBOT's tip and is played during the core hunt (`planetLocked()` in the source). After all three cores, the shield falls → **Core Foundry** (P3: OmniScrap HQ, Blartz arrested then rescued and gifts PATENT PENDING, GLAMBOT's vent assist, Clause 44 shutdown and Sprocket's override, Excavatron Prime / Chairman Grindstone finale) → ending → 35-memo epilogue (Sprocket forwards every memo to 40 billion inboxes) → post-credits (Darkmatter). The star-map order is `CAMPAIGN = [0,1,5,6,7,9,2]`. Keep this gating unless a change is logged in DECISIONS.md. Note: the Galleria ledger scene says "if Grindstone ever tries that clause AGAIN," which reads as if it happens after the Foundry. Resolve that continuity wrinkle (e.g. the Galleria becomes post-Foundry, or the line is reworded) and log it in STORY_CHANGES.md.

**Systems:** walk/sprint with momentum carry; jump plus double jump with variable height, coyote time, buffer, apex hang; hover (Sprocket thrusters, drain and regen); wall slide and wall kick; dash with i-frames; dash-jump; slam and super slam; slam bounce; slide and slide long-jump; 3-hit mallet ground string (sweep → rising backswing → 360° spin smash) with hitstop, plus mallet throw; combo counter; three mallets (Scrap / Magma / Thunder); 12 guns with Damage / Fire-Rate / Ammo upgrade tracks and **Omega** evolution when maxed; radial weapon wheel; aim assist with per-device stickiness; **Super Sprocket Protocol** (a meter filled by dealing damage that turns Sprocket into an auto-firing combat drone with barks); K.A.R.E.N. summon; bolts currency, gold bolts, nanocrates; Blartz's shop v2 (tabs, deal of the day, wishlist, trade-in, celebration); planet traversal mechanics (Glacius ice slip and blizzards, Verdant murk pools and bounce mushrooms, Nova moving walkways); star map with mission tracker; space-travel minigame; 35 memos; ~19 side quests; cutscene gallery and 13 voiced weapon-ad vignettes; photo mode; NG+ (roster bleed, HP tiers, NG+ Chrome); cosmetics (8 paints, Sprocket hats, mallet seams); firing range; settings; credits.

**Side modes:** ZONGA™ (a 50-contestant battle royale on a broadcast island with a shrinking Engagement Zone, run by V.I.B.E., the Viewer Engagement Engine); GLAMBOT COLOSSEUM arena (Wave Survival, Mallet Only, One-Hit KO, Timed Gauntlet, Sponsored Round, Boss Rush, Whiteout Brawl, Bounty Hunt); OMNIGRAND PRIX™ hoverboard racing (3 tracks including RUSTVANE SKYWAY flight, 5 rivals); **LOOP RIOT™** (a stunt-skate circuit over the Slag Flats run by the Recalls (Dent, Model-M, Scuff, Toasty, Intern #4401), with tricks, grinds, flips, leagues, rep ranks, decks, and the Proving Ground's black-box reveal: "Unit survived. Recommend recall.").

---

## 4. BOLT & SPROCKET — CORE GAMEPLAY (port first, then improve)

### 4.1 Movement & melee (port 1:1, then polish)
- Port every `CONFIG.move/jump/hover/wall/dashJump/slamBounce/dash/slam/slide/melee/cam/AIM_ASSIST` value as the starting tuning. Build a side-by-side feel checklist (jump arc, dash distance, slam timing, combo windows, hitstop) and match the web build before changing anything.
- **Improvements after parity:** a camera collision SpringArm with no wall clipping; a lock-on soft-target toggle; the mallet string gains an air combo (2 hits plus a spike) and a charged ground pound; **mallet throw becomes a boomerang that can hit switches and collect bolts** (traversal and puzzle use); combo meter tiers pay bonus bolts.
- **Gadgets** (new; they give the remade maps more verticality): **Tether-Hook** (Sprocket fires a cable to hook points to swing and pull), **Grind Soles** (rail grinding outside Loop Riot, reusing the Loop Riot grind tech), and **Sprocket Glide** (hold jump after hover runs out). Each gadget is earned on a specific planet (§6) and opens backtracking secrets on earlier planets.

### 4.2 Sprocket
- He is a companion with a body, opinions, and four moods, and he comments on everything (port `BARKS`). He is never a silent tool.
- **Super Sprocket Protocol (redesigned):** the meter fills from damage dealt and combo tier. On activation, Sprocket chooses a mode based on the situation (Bulwark: shield and taunt; Overclock: auto-turret; Zip: dashes between enemies). Keep `SUPER_BARKS`. It upgrades through story beats.
- Sprocket's firmware "settings menu" scene (OPERA MODE / whisper / legal-disclaimer / CEO preset) becomes an unlockable voice-filter cosmetic.

### 4.3 Economy & shop
- **Bolts** are dropped by enemies and crates, and are spent at Blartz's shop. **Gold bolts** are the secret currency for cosmetics, cheats, and skins. Keep the shop v2 features (tabs, deal of the day, wishlist, trade-in, celebration) and every `BLARTZ_LINES`/`BLARTZ_ITEM_LINES` pitch, deny, buy, and tip line.
- **K.A.R.E.N.** (the Kinetic Automated Retail Enforcement Nanny) becomes a purchasable **Gadget-slot summon** with a long cooldown, keeping her ad vignette and disclaimers.

---

## 5. BOLT & SPROCKET — REDESIGNED ARSENAL (write `docs/BS_WEAPONS.md`)

### 5.1 Progression model (replaces "max 3 tracks = auto Omega")
Each weapon has three layers:
1. **Use-XP levels V1→V5.** The weapon levels up from kills and damage dealt. Every level is visible: a new model detail, a stat bump, and a small behaviour change at V3 and V5.
2. **Blartz Mods** bought with bolts. Keep the original three tracks as mod slots (Damage / Fire Rate / Ammo Cap, 3 tiers each, original prices `[60,110,170] / [50,90,140] / [40,70,110]` as the baseline). Add one **Signature Mod** per weapon (a choice between 2 alt behaviours).
3. **Omega Evolution at BLARTZ'S OMEGA FORGE.** Once a weapon is V5 and fully modded, bring it to the Forge (unlocked after the Blartz rescue in Core Foundry, the last planet, so Omega is mostly an endgame / post-game / NG+ chase; every Blartz kiosk on every planet gets a Forge from then on) for a 2,000-bolt evolution with a cutscene, a gold Ω, a new name, and its Omega signature (based on the original `OMEGA_DESC`, upgraded). **The Omega Forge is the canon origin of Gravelight's Crucible** (§10). Blartz's Forge dialogue should plant this: he complains that OmniScrap "seized the prototype schematics" when they arrested him, and that he "re-built this one from memory, which is better than the original, which was also perfect."

### 5.2 Design rules for every weapon
Each weapon must have: a clear **role**, a **primary** and an **alt-fire**, a **status-effect identity**, at least one **combo with another weapon or with the mallet/Sprocket**, a satirical **brand pitch** (keep the ad vignette for the original 12; write new vignettes for the 4 new ones), its **unlock condition**, and its **V1/V3/V5/Omega behaviour**. No two weapons may share a role at the same tier.

### 5.3 The arsenal (12 originals redesigned + 4 new = 16, plus 4 mallets)
Original prices are kept where they existed; the rest are tuned. Unlock gating follows story progress (record the final table in `docs/BS_WEAPONS.md`).

| # | Weapon | Role | Primary | Alt-fire | Status / combo | Omega |
|---|---|---|---|---|---|---|
| 1 | **OMNI-BLASTER** (start) | Reliable sidearm | Hitscan bolts; a heat bar replaces infinite spam (overheat = 1s vent) | **Hot Round**: a charged piercing shot that consumes the heat bar | Hot Rounds ignite SERVED targets | **Ω OVERTIME**: every 3rd shot is a Hot Round that forks sparks to bystanders |
| 2 | **VOID RIPPER** | Charge burst | Hold to charge an implosion orb | Plant a **Rift** that pulls enemies for 3s | Pulls into Grav clumps for double crush | **Ω SECOND OPINION**: impacts trigger a delayed second implosion |
| 3 | **SPROCKET ZAP** | Chain crowd damage | Arcs between up to 3 targets (V5: 5) | Sprocket stands still and **amplifies** (bigger arcs, he complains) | Leaves conductive residue; Frostbyte-frozen targets conduct double | **Ω FULL CHARGE**: 5 arcs, double-width residue, arcs jump to Middleman drones as relays |
| 4 | **B.O.O.M. BOX** | Crowd control grenade | Lob a subwoofer: enemies in range are forced to DANCE | **Drop the Bass**: remote detonate early | Dancing enemies take +crit from the mallet | **Ω HEADLINER**: bigger floor, double bolts, the drop launches enemies into the air |
| 5 | **LAWN DART** | Homing burst | Slow, patient homing dart that sticks, then detonates | **Paint** up to 3 targets, then fire a volley | Darts stuck in SERVED targets explode bigger | **Ω DOUBLE FAULT**: 2 darts per trigger, each locking a different target |
| 6 | **PATENT PENDING** (Blartz's gift after the rescue) | Signature spectacle | A sphere of litigation that forks smaller lawsuits at bystanders, then detonates | **File Early**: hold to grow the sphere; release to place it as a slow-moving hazard | Lawsuits stamp targets SERVED | **Ω PATENT GRANTED**: forks twice as fast with a bigger splash. *(Plot: Darkmatter's legal team later claims this patent. See The Fine Print Ch. 4.)* |
| 7 | **CEASE & DESIST** | Debuff support | A ricocheting legal document stamps each target SERVED (+40% damage taken from everything) | **Class Action**: one heavy notice; everything near the target is SERVED | Enables every other weapon | **Ω INJUNCTION**: 6 ricochets, SERVED = +70%, SERVED enemies can't use abilities for 2s |
| 8 | **BUZZKILL** | Geometry skill shot | Saw blades ricochet off walls up to 3 times | **Manual Override**: hold to steer the last blade | Blades shred plating (anti-armor) | **Ω MOOD KILLER**: 5 bounces, every blade splits on the first bounce |
| 9 | **GRAV GRENADE** | Grouping | Micro-singularity vacuums enemies and loose bolts into a clump, then pops them skyward | **Hold**: keep the singularity open while held | Slam a clump for bonus damage (keep this combo) | **Ω EVENT HORIZON**: lasts 6.5s, crushes from the moment it opens |
| 10 | **THE MIDDLEMAN** | Deployable aggro | A hovering turret-drone draws aggro and fires for 12s | **Reassign**: point at a target to redirect it | Drones relay Sprocket Zap arcs | **Ω MIDDLE MANAGEMENT**: two drones at once, and they argue (barks) |
| 11 | **FROSTBYTE** | Freeze + bolt farming | A beam freezes enemies into ice statues; shatter them for a fountain of bolts | **Ice Wall**: raise a temporary barrier | Frozen targets conduct Zap double and shatter for crits | **Ω DEEP FREEZE**: longer beam, faster freeze, statues stay frozen for 9s |
| 12 | **ROOT CANAL** | Area denial | Plant a seed that sprouts a snapping biter rooting enemies (up to 3 gardens) | **Uproot & Replant** | Rooted targets can't dodge Lawn Darts | **Ω ORTHODONTIST**: five gardens at once, chewing 40% faster |
| 13 | **LATE FEE** *(new, Rustvane)* | Close-range shotgun | Spread blast. Damage accrues **interest** each second you DON'T fire (up to ×2, shown as a % ticker) | **Collections**: a short-range pull-shot that yanks one enemy to you | Pull into the mallet string | **Ω COMPOUND INTEREST**: kills refund half your accrued interest |
| 14 | **THE FINE PRINT** *(new, Nova Plaza)* | Marksman | A scoped rifle firing tiny bullets of tiny text. Hits **reveal and mark** weak points for 6s | **Read Carefully**: slow time slightly while scoped (meter-based) | Marked weak points take +crit from all weapons and from Sprocket | **Ω TERMS APPLY**: marked enemies take +25% from everyone, and marked weak points explode when broken |
| 15 | **HOSTILE TAKEOVER** *(new, Verdant Sink)* | Conversion | A beam that "acquires" a non-boss enemy as a temporary ally (subsidiary) for 10s | **Merger**: fuse two acquired enemies into one bigger ally | Acquired enemies can be SERVED to make them stronger allies | **Ω GOLDEN PARACHUTE**: when the contract ends, acquired units explode into bolts |
| 16 | **CLEARANCE RACK** *(new, Grand Galleria)* | Sustained DPS | A spin-up minigun firing price-tag rounds; each hit **marks down** armor | **Doorbuster**: a spun-up burst that knocks back everything in front | Shreds plated enemies for the mallet | **Ω EVERYTHING MUST GO**: no spin-up, and armor reaches 0% after enough tags |

**Mallets:** Scrap Mallet (start) → Magma Mallet (adds burn) → Thunder Mallet (adds chain shock), all kept. NEW post-game: **Riot Mallet** (earned in Loop Riot; launches enemies for juggles). Mallet seams stay cosmetic.

**Weapon wheel:** keep the radial wheel. Add a quick-swap "last weapon" button and wheel pages (8 per page).

### 5.4 Seeds of Darkmatter inside the B&S campaign (light touch)
- Add **5 new hidden memos** (total 40). Each is clearly from OmniScrap's acquisition talks with Darkmatter: "RE: Sol-3 legacy test market (DO NOT DISCUSS)", "Asset Sale — Confiscated Vendor IP (BLARTZ, 1 forge schematic)", "Darkmatter's motto is 'Nobody Cancels'. Legal asks if that's a threat. Darkmatter says it's a promise.", "Next-Era Delivery™ pilot: invoices may arrive before orders", "Re: the vending robot that never reported back."
- In the Grand Galleria, add one derelict, violet-glowing **TONIQ™ VITALITY DISPENSER** stamped "DARKMATTER IMPORTS — DISCONTINUED: SOL-3 TEST MARKET INCIDENT." Interacting with it plays a short Sprocket line and plays its jingle backwards.
- The Retention Specialist's boss lines gain one Darkmatter-flavored line ("Nobody cancels. I learned that from the best.").
- The ending, memo epilogue, and post-credits play as written. The synergy-screening invite now leads directly into The Fine Print.

---

## 6. BOLT & SPROCKET — REDESIGNED MAPS (write `docs/BS_LEVELS.md` with top-down diagrams)

General rules for every planet:
- **Hub → 3 spokes → boss arena → 1+ secret area.** Each planet has a landing pad (ship, Blartz kiosk, save point, star-map access), a signature traversal mechanic, 3–5 gold bolts, its memos (keep the `MEMO_SPOTS` intent; relocate sensibly), side quests, and an optional arena challenge.
- **Every room tells the story.** Each zone exists for a reason in OmniScrap's satire (what it was for, who got screwed).
- **Backtracking payoff:** each new gadget (Tether-Hook, Grind Soles, Glide) and the boomerang mallet throw opens secrets on earlier planets.
- **Readability:** combat spaces have cover, height, and flanks. Platforming spaces have clear landing reads. There are never invisible walls without a diegetic reason (keep the SPLASH_QUIPS out-of-bounds jokes).

| Planet | Zones (redesigned) | Signature traversal | Story beats kept (+ new) | Boss |
|---|---|---|---|---|
| **SCRAPHEAP JUNCTION** (warm sunset junkyard) | Bolt's repossessed garage (prologue), **Rusty's Row** (41-shack refugee village, Mama Gasket), the **Billing Mast** (climb, Loop Riot broadcast tease), the Conveyor Works, the Teleporter Yard, **Exit Yard** (compactor arena) | Conveyor belts and magnet cranes; mallet-throw switches | l1_row, l1_mast, l1_glitch, l1_vista, l1_mid, l1_repo | **REPO-TRON** (tank treads, magnet crane that steals your weapon until you smash its crane hook; compactor walls close in) |
| **RUSTVANE CANYON** (twin suns, one is an ad) | The resort strip, the **Infinity Lava Pool**, the **Co-op Camp** (Rustvane Mining Co-op history), **Back of House** (staff under the pool, Bellhop-9), the open-pit mine, the cliff zip lines | Zip lines plus wind updrafts; the **Tether-Hook** is earned here | l2_mid, l2_holo1, l2_camp, l2_staff, ccIntro, l2_glambot, shieldReveal | Mini: **RUSTVANE SENTINEL**. Boss: **THE CONTENT CREATOR** (phases: "unboxing," "collab," "going live"; destroy the camera drones to break its armor; GLAMBOT defects on defeat) |
| **NOVA PLAZA** (failed smart-city, all lights on, nobody home) | Plaza fountains, the HOA District, the Permit Office, the **FineTree** (a hologram tower of unpaid fines), the empty transit loop | Moving walkways that reverse on HOA "violations"; lamp-post grapple points | novaIntro, novaHolo, novaMid, novaLate (pre-fined), coreNova | **THE ALGORITHM** (a smiley-faced server wall; fines rain down as attacks; its "recommendations" summon enemies; overload it by feeding it Cease & Desist notices) |
| **GLACIUS VAULT** (ForeverYou™ cryo-subscription) | The Thaw-Queue Hall (pod rows of frozen people), the Premium Tier wing, the blizzard ridge, the Recall Storage (Sprocket's batch #1), the Master Freezer | **Ice slip** (keep ~72% accel cut) and **timed blizzards** with rotating wind; the **Grind Soles** are earned here (frozen pipe rails) | glaciusIntro, glaciusHolo, glaciusMid, glaciusLate, coreGlacius (RECALL) | **THE RETENTION SPECIALIST** (a cryo-suit account manager on a floating platform; ice-spike patterns; "cancellation flow" phase where the arena maze reroutes you) |
| **VERDANT SINK** (failed terraforming, the corn unionized) | The glow marsh, the Union Hall (Local 404), the Spore Groves, the leaking **Mega-Harvester** | **Murk pools** (slow + tick damage) and **bounce mushrooms**; **Sprocket Glide** is earned here | verdantIntro, verdantMid, verdantLate (union card), coreVerdant | **COMPOST KING** (a misunderstanding that got big; the fight is a plumbing puzzle under pressure: seal 3 coolant leaks while it thrashes; mercy ending kept) |
| **GRAND GALLERIA** (orbital dead mall, sale is eternal) | The Atrium, the Food Court, the Anchor Store (Clause 44 ledger), **Kiosk #7** (Gilda), the escalator maze, Guest Services, the derelict **TONIQ™ dispenser** (Darkmatter seed) | Escalators that reverse; mannequins that move when unseen; the mall PA (`GALLERIA_PA`) | arrive9, galleriaGreeter, galleriaLedger, memo epilogue | **GREETER PRIME** (an eternal doorman greeting you to death; "UNGREETED → CORRECTING"; waving-arm sweeps; break the "WELCOME" sign generators) |
| **CORE FOUNDRY** (OmniScrap HQ) | The marble Lobby, the BoltBuddy Assembly Line ("I was born here"), the **Holding Block** (Blartz's cell), the **Crusher Corridor** (GLAMBOT's vent), the HR Floor, the Executive Bridge | Crushers, moving assembly lines, vent updrafts; the **Omega Forge opens after the rescue** | arrive2, blartzArrest, blartzFound, blartzRescue, l3_holo2, l3_vent, l3_waves, **l3_brick (Clause 44)**, gsIntro | **EXCAVATRON PRIME → CHAIRMAN GRINDSTONE** (multi-phase mining mech running on burned venture capital: armor plates, enrage, and a final "Grindstone 2.0 rebrand" phase) |

Also port: the **star map** and mission tracker, the **space-travel** transition (with skip, plus the HUMOR-REVIEW tips if approved), flyover intros for every planet, and the ending sequence.

---

## 7. BOLT & SPROCKET — REDESIGNED ENEMIES (write `docs/BS_ENEMIES.md`)

Every enemy must have: a **role**, a readable **silhouette**, an **attack telegraph** (pose plus sound plus light) that lasts at least 0.4s for anything that hits hard, a **weak point or counterplay**, a **satire joke** in its design, an **elite variant** (NG+ and later planets; a colored rim plus a new trick), and its original `dieSfx` intent. Keep the original HP/speed/damage/drop values as baseline tuning. Each planet keeps its original 3 enemies and gains 1 new one:

| Planet | Enemies (original → redesigned behaviour) | NEW enemy |
|---|---|---|
| Scrapheap | **Scrap Mutt** (pack chaser: circles, then one pounces while the others feint), **Tinker Turret** (ambushes from junk piles; the weak point is the exposed coil while it reloads), **Vulture Drone** (dives to **steal bolts**; kill it before it flees to drop them back) | **Lien Crawler**: burrows, tags you with a "LIEN" debuff that makes other enemies target you; smash it to clear |
| Rustvane | **Ambassadog** (fast vest-wearing hound, polite pounce), **Selfie Sentry** (flash-blinds; look away or shoot the lens), **Lifeguard Bot** (heavy lobber; whistle telegraph) | **Review Bomber**: a drone that drops 1-star bombs in readable star-shaped patterns |
| Nova Plaza | **Meter Maid** (pouncing chaser that writes tickets), **HOA Enforcer** (plated turret; Buzzkill strips plates), **Surge Drone** (gets stronger the more enemies are alive: "surge pricing") | **Zoning Board**: three linked pylons project no-go zones that fine (damage) you; break the link |
| Glacius | **Chillsplitter** (burrows under ice, erupts), **Popsicle** (ambush turret disguised as a cryo-pod), **Frost Peddler** (freeze flyer selling "warmth upgrades") | **Premium Waker**: a thawed customer who "upgraded"; it cracks out of pods mid-fight unless you protect the pod's thaw panel (protecting it frees the person and pays bolts) |
| Verdant | **Gloomstalker** (cloaked pouncer; Fine Print marks reveal it), **Spore Lobber** (arcing turret), **Pollinator** (tiny buffer that strengthens others; kill first) | **Picket Corn (neutral faction)**: union corn that only fights if you hit them. Protect them for a bolt bonus and a union-card cosmetic |
| Core Foundry | **Slag Golem** (plated heavy), **HR Drone** (paperwork projectiles, hovers home), **Weld Wasp** (swarms), **Statue** (bolt piñata prop) | **Middle Manager**: a commander that gives nearby enemies "performance reviews" (buffs) and fires the worst performer (instakills a weak ally to buff itself) |
| Grand Galleria | **Mannequin** (moves only when unseen; very fast), **Coupon Crier** (rallies and buffs, megaphone) | **Return Desk Mimic**: a kiosk that is actually a mouth; the bait is a fake deal |

Bosses are listed in §6. Each gets 3 phases, a GLAMBOT title card (`introAlgorithm`, `introCC`, `introCompost`, `introGrindstone`, plus new ones for the bosses that lacked them), a weak-point BREAK meter (keep the v13 system), and a no-damage trophy.

---

## 8. BOLT & SPROCKET — SIDE MODES, EXTRAS, PROGRESSION (port all; upgrade where noted)

- **ZONGA™** battle royale: 50 contestants (bots from `BOT_NAMES`), shrinking Engagement Zone (`ZONGA_STAGES`), sponsor jokes, the zongaReveal/zongaStart/zongaTruth story (V.I.B.E. now reports to GLAMBOT). Upgrades: loot rarity tiers using the B&S arsenal, a supply-drop "sponsor" system, and smarter bots (they flank, retreat, and third-party).
- **GLAMBOT COLOSSEUM:** all 8 challenge types from `CHALLENGES`/`ARENA_POOLS`. Boss Rush now includes every campaign boss.
- **OMNIGRAND PRIX™:** 3 hoverboard tracks including RUSTVANE SKYWAY (flight), 5 rivals (`RIVAL_ROSTER`), sponsor quips.
- **LOOP RIOT™:** port it fully (physics constants, tricks, grinds, flips, grabs, leagues Scrap / Riot Cup / Unrecalled, rep ranks Test Subject → Riot Legend, decks, Recall Notices, the black-box story). Dent's offer to Sprocket ("There's a deck on the wall here whenever you want one") stays.
- **Firing Range** (trial every gun, score rewards), **Photo Mode**, **NG+** (roster bleed, HP tiers, NG+ Chrome, carry-over arsenal, new Omega-tier Blartz stock), **cosmetics** (all `PAINTS`, `HATS`, `MSKINS`), the **Cutscene Gallery**, all 13 **weapon-ad vignettes** plus 4 new, **Trophies** (use the HUMOR-REVIEW names if approved, e.g. "Participation Foreseen," "Percussive Diplomacy," "Adequate.").
- **Side quests:** port all ~19 from `QUESTS`. Each gets a proper start, a waypoint-free hint system using Sprocket barks, and a reward.

---

## 9. GRAVELIGHT (zombies) — see Appendix A for the full spec

Appendix A is the complete original Gravelight design (story, characters, economy, perks, Crucible, enemies, weapons, Map 0 Crossroads Inn, Map 1 Kaltenbrunn, the main Easter egg, progression, presentation). **Build it as specified, with the amendments in §11.** The amendments win any conflict. Appendix A's own milestone list (§15), first-response instructions (§16), and pause rule (§0.6) are superseded by this document's §13–§14.

---

## 10. THE FINE PRINT — the origin story of the perk machines and the Crucible

This is a SEPARATE story campaign with its own menu entry, chapter select, and Archive section. It explains, step by step, how the Gravelight machines came to exist, and it pays off Bolt & Sprocket's sequel bait. Write the full script in `docs/FINEPRINT_SCRIPT.md` (every scene, every line, with VO line IDs) and the bible in `docs/FINEPRINT_LORE.md`.

### 10.1 New characters
- **VENDELIN** (Darkmatter Field Merchandiser Unit V-1). A tall, thin, slightly dented sales robot with a coin-slot mouth, a brass faceplate, and a violet DARK-GLASS™ core. His directive is three words: **"DISTRIBUTE. RETAIN. REPORT."** He crash-landed with the Sol-3 probe in 1938, damaged and out of contact. He passed as human behind a coat, hat, scarf, and gloves, and as **"Herr Viktor Vendelin, Ingenieur, Basel."** He is polite, precise, and lonely. He learns from humans, comes to understand what his product does to them, and quietly sabotages it from inside. He wrote every perk jingle himself because "a product must be *loved* to be retained," and he grows to hate how catchy they are.
- **RES GÄHWILER**: Vendelin's only friend, a Swiss delivery driver from the Bernese Oberland. He drove Helvetia machines across the border. Warm, superstitious, funny, and the human heart of chapters 2–3. His grandmother's alpine herbal malt became Marathon Malt. Through a cousin, he is the SOE's Swiss contact (this is how Peg's secret orders exist).
- **SABLE VANTAGE**: Darkmatter's **VP of Emerging Markets**, who launched the Sol-3 test market. Velvet voice, perfect posture, says "we" when she means "you." She is heard throughout Gravelight's eras through the Operator's "corporate slips" and is finally seen in Ch. 4. She is the Darkmatter rep who offered Reinholt her daughter back, as a service.
- **THE UNDERWRITER**: Darkmatter's risk-assessment enforcer, a towering ledger-faced machine that "prices" everything it looks at. It enforces Clause 0. It is the Fine Print's main boss.
- **THE BOARD**: a conference call of distorted voices that is never shown. They are the voice from the B&S post-credits ("Initiate acquisition").
- Returning: Bolt, Sprocket, Blartz (central in Ch. 4), GLAMBOT PRIME (in Bolt's ear), and the Gravelight squad plus Fasbender, Reinholt, and the Operator in Ch. 5.

### 10.2 The Vitality Plans: the true origin of each perk machine
Each Helvetia machine is a Darkmatter **Vitality Plan** tier, with a plan ID stenciled UNDER its paint. Vendelin built the cabinets and wrote the jingles. A **human** made each formula drinkable, and each of them has a story. Every machine has a hidden **"fine print" panel on its back** that the player can walk around and read: Vendelin's real terms of service, written as warnings no one read. Write all panels in `docs/JINGLES.md` next to the jingles.

| Perk (Gravelight name) | Darkmatter plan | The human behind the formula | The story | Fine print on the back (sample) |
|---|---|---|---|---|
| **Ironhide Stout** | DURABILITY+ | **Otto Kessler**, a conscripted Bavarian brewmaster | Ordered to make the substrate drinkable for assault engineers, he brewed it into a stout so it would at least taste like home. He drank the first batch himself so no one else had to. | "Durability is measured in hits, not years." |
| **Second Wind Schnapps** | CONTINUITY (Free Trial) | **Sister Agnieszka**, a Polish forced-labor nurse at Kaltenbrunn | She and Vendelin secretly altered the formula to keep prisoners alive. Vendelin hid an independent battery in this one cabinet so it would work when the power was cut. That is the canon reason it works without power in solo. The "3 uses, then it vanishes" rule is Darkmatter's free-trial limit, which Vendelin could not remove. Wren knows Agnieszka's name. | "Trial ends after three (3) returns. You may not be returned a fourth time." |
| **Trigger Tonic** | THROUGHPUT | **Dr. Ilse Vogt**, a shift chemist at the (fictional) Kaltwerk Chemie plant | She calculated reload times the way she calculated shift quotas. Her mascot hare was drawn by her son. She quit when she learned what the tanks downstairs were for. | "Faster hands do not include a faster conscience." |
| **Twin Barrel Bitters** | VELOCITY | **Major Anselm Brück**, an ordnance officer | A vain man who demanded his own mustache on the mascot. He was the first officer Vendelin saw choose the plan for others "for morale," and Vendelin's first lesson about humans. | "Rate of fire is not rate of victory." |
| **Marathon Malt** | MOBILITY | **Res Gähwiler's grandmother's** alpine herbal malt | Vendelin asked Res for "the taste of running home." Res gave him the family recipe and never forgave himself. | "Unlimited stamina. Destination not included." |
| **Hawkeye Brandy** | FOCUS | Derived by Reinholt's lab from tests on **Halina "Sowa" Kurek**, a captured Polish Home Army sniper and **Wren's mentor** | This is why Wren hates that it works. Vendelin delivered the cabinet and found out after. It is the moment he starts sabotaging. | "Focus was donated. Donor did not consent." |
| **Packmule Porter** | CAPACITY | **Feldwebel Gustl Ammer**, a quartermaster obsessed with inventory | He secretly used the extra-capacity trials to smuggle food to laborers. Vendelin covered for him. | "Carrying more is not the same as carrying enough." |
| **Blastproof Bock** | LIABILITY WAIVER | The demolitions school at Kaltenbrunn | Res smuggled a sample to the SOE in 1943. **This is how British intelligence learned Nachtglas exists**, and the root of Peg's sealed orders ("retrieve at any cost"). | "By drinking, you waive liability for yourself." |
| *(NEW)* **Fine Print Fernet** | DISCLOSURE (unreleased prototype) | Vendelin himself | A bitter green digestif that lets you *see the truth*: power-up timers, drops lasting 50% longer, and Easter-egg objects glinting. It is the plan Darkmatter refused to sell. Available on Helvetia Works, and later maps after Origins is complete. | "This product tells you what the others won't." |
| *(NEW)* **Overclock Cordial** | SURGE (unreleased prototype) | Built from a scan of a far-future robot's firmware (**Sprocket's**, after Ch. 5) | Reloading releases a static burst that scales with how empty the mag was. Bolt: "Is that... Sprocket-flavored?" Sprocket: "I'm EXTREMELY flattered and I want royalties." | "Contains trace amounts of personality." |

The two new perks never break Gravelight's perk cap (4 when this was written; 6 since T-081, 4 under Classic Rules).

### 10.3 The true origin of the Crucible (our upgrade forge)
1. In the B&S campaign, Blartz invents the **Omega Forge**, which is why weapons can evolve.
2. OmniScrap arrests Blartz for "unlicensed innovation" and **confiscates the prototype schematics**. This is canon in the remake: the confiscation is shown in a new memo and a short scene in the Holding Block.
3. After OmniScrap collapses, Darkmatter buys the confiscated IP in the fire sale and builds **Crucible Mod. R-E (Re-Education)**. Same principle, "localized": a Nachtglas furnace that "re-teaches" weapons.
4. Via Next-Era Delivery, Darkmatter ships a Crucible to the Sol-3 test market in 1944. That is why the Kaltenbrunn Core Vault has one. Its brass plaque reads **"MOD. R-E · PAT. PEND."** with Blartz's original patent number (the Patent Pending gun's serial). Players can read it in Gravelight long before they understand it.
5. Blartz learns all this in Ch. 4 and is OUTRAGED, mostly about the camo: "They put MY forge in a WAR? And they made it VIOLET? *Tacky.*"
6. Payoff: in the crossover map, the player can find **Blartz's original Omega Forge prototype** (shipped to Basel as a reference unit). It allows a **second upgrade tier** in zombies: Crucible variant → **Omega** variant (one weapon per match, a huge cost, a gold-and-violet camo, and a Blartz voice line through the Operator's speakers that the Operator does NOT approve).

### 10.4 Other origin answers
- **The Mystery Crate** is a Darkmatter Loot Allocation Unit drawing "returned inventory" across times and places. The tin drummer stays Reinholt's, because her grief "infected" the unit. Vendelin can't explain it either. That keeps one true mystery.
- **The Operator** is Darkmatter's Customer Retention Interface. In Ch. 3 it is installed in the Ledger, it picks the announcer voice, and it says its first line: *"Market localization complete. Welcome, valued customers."*
- **Power-ups** are engagement incentives (Ch. 3 shows the design meeting via a holo-memo).
- **Scrip** are localized loyalty points.
- **The zombies** are retention substrate working as designed. Ch. 2 shows the first one rising in the mine in 1938, before anyone understood it.

### 10.5 Chapter structure (gameplay reuses our two engines; no new genres)
**Ch. 1 — "SYNERGY SCREENING"** *(B&S style, present day, Umbral Galaxy)*. Bolt & Sprocket answer the calendar invite and infiltrate **The Retention Spire** (Darkmatter HQ). The level is a corporate tower where every door asks you to accept new terms. New enemies: **Churn Wardens** (shielded guards whose shields are "non-cancellable": break them with SERVED), **Upsell Drones**, **Exit Survey** turrets (they ask questions; wrong answers spawn more). In the Emerging Markets archive they find the **Sol-3 file**: a test market on a primitive world, a field unit "lost on arrival," "results: EXCEPTIONAL RETENTION." Sprocket finds Vendelin's last transmission from 1945. Cliffhanger: Sable Vantage welcomes them by name.

**Ch. 2 — "FIELD UNIT"** *(Vendelin, Earth, 1938–1939, slower third-person, light stealth and exploration)*. The probe lands in the Kaltenbrunn salt mine. Vendelin repairs himself from salvage, builds a disguise, and learns to walk among miners. He witnesses the **first retained miner** rise. Gameplay: avoid or redirect early Gängers (Vendelin can't fight well; he uses distraction, lures, and machines), and solve repair puzzles with probe parts. It ends with Vendelin walking out of the mine in a borrowed coat while the Operator boots for the first time in the dark behind him.

**Ch. 3 — "HELVETIA AUTOMATEN AG"** *(Vendelin, Basel and Kaltenbrunn, 1940–1944, vignette chapter)*. This is **the perk story**. One short playable vignette per machine:
- **Workshop phase:** assemble the cabinet as a tactile build puzzle (bolt, wire, glass, sign).
- **The human phase:** a short scene with the formula-maker from the §10.2 table.
- **The jingle phase:** Vendelin composes the jingle on a cheap pump organ, and the player picks melody fragments. The final jingle always resolves to the canon version, but the chosen fragments unlock alt-mix cosmetics.

Between vignettes: Res drives the machines across the border at night (a short driving/stealth sequence), Vendelin's guilt grows, and he plants the fine-print panels, the secret Second Wind battery, and his first message to Fasbender (Vendelin is the reason Fasbender understands the substrate and knows the Allied frequency). The finale is the **Ledger installation**: the Operator chooses its voice, and Vendelin realizes he can't take it back.

**Ch. 4 — "PATENT PENDING"** *(B&S style, present day)*. With Blartz along, Bolt & Sprocket raid **Darkmatter's Patent Vault** to prove the Crucible was built from stolen IP and to find a way to Sol-3. This is a heist level: laser-grid "terms" puzzles, a vault that rearranges like a filing cabinet, and Blartz's gadget of the week. The truth is revealed: the Omega Forge schematics were confiscated, sold, and shipped to 1944. **Boss: SABLE VANTAGE's executive mech, "THE QUARTERLY"** (phases: Q1 to Q4, each fiscal quarter changing the arena's rules). Ending: Blartz rigs the patent vault's Next-Era Delivery pad to send Bolt & Sprocket to Vendelin's last known coordinates. It goes wrong, as everything Blartz builds does, beautifully.

**Ch. 5 — "RETURN POLICY"** *(the crossover zombies map, HELVETIA WORKS; see §10.6)*. Bolt & Sprocket arrive in Basel, March 1945, the night after the Gravelight Map 1 ending. Dutch, Peg, Deacon, and Wren arrive chasing Reinholt's rail fragment. The Underwriter arrives to **recall Vendelin under Clause 0**. The main Easter egg is the story finale.

### 10.6 Crossover map — "HELVETIA WORKS" (full zombies map, Gravelight rules)
Helvetia Automaten AG's factory on the Rhine in Basel, neutral Switzerland, at night. Above it hangs the **Darkmatter fulfillment barge** in a violet fold in the sky, connected by a cargo-lift beam.
- **Playable characters (pick 4 in co-op, 1 in solo):** Dutch, Peg, Deacon, Wren, **Bolt** (first-person; the mallet replaces the knife; **Sprocket is his special**: a meter fills from kills, then Super Sprocket hovers as an auto-turret for 15s; Bolt keeps his B&S quips), and **Vendelin** (trait: perk machines cost 10% less for him and he can "service" a machine once per match for a free refill drink; he has the most devastating quotes about every machine). The Classic Rules toggle disables traits.
- **Zones:** the Loading Dock (spawn), the Assembly Hall (prototype perk cabinets on the line), the Jingle Room (pump organ, Easter-egg melodies), the Formula Lab, Vendelin's Office (Archive goldmine), the Rhine Quay, the Cargo-Lift Beam, and **the Barge** (Darkmatter interior: violet, sterile, slogans on every wall) with the **Original Omega Forge**.
- **Perks:** all 8 machines plus Fine Print Fernet and Overclock Cordial, as **prototypes** (unpainted cabinets, plan IDs visible).
- **Enemies:** Gängers (Basel dockworkers and factory staff), Glasshides, Bellringer-equivalent special round **"AUDIT ROUNDS"** (the barge's chime sounds and **Repossessors** drop in: Darkmatter robots that hunt players, AND zombies, so use them against each other), plus the **UNDERWRITER** boss (prices you: the more Scrip you hold, the harder it hits; spend before it arrives).
- **Wonder weapon:** **THE RETURN POLICY**, a Darkmatter refund-gun that "returns" zombies to sender (they vanish in a violet fold). The upgraded version, **"No Questions Asked,"** chains returns. Rare in the crate. Also a buildable: **Blartz's Field-Kit OMNI-BLASTER**, a WW2-scale build of the B&S sidearm from three parts across the map.
- **The rare B&S crate pool** is active here: Lawn Dart, Grav Grenade, Cease & Desist, Frostbyte, and Buzzkill, rebuilt to Gravelight scale with crossover Crucible names.
- **Main Easter egg, "CLAUSE ZERO":** restore power; open the cargo-lift beam; collect Vendelin's three hidden fine-print panels; tune the Jingle Room organ to the "true" jingle (the one Vendelin wrote first, before Darkmatter edited it); bring a weapon to the Original Omega Forge; survive the Underwriter's audit; then the finale. Vendelin's shutdown countdown begins, **mirroring Sprocket's Clause 44 scene**. Sprocket talks him through his own override ("Friendship isn't a feature. It's a bug. And nobody gets to patch yours.") while the team holds out. The ending: Vendelin overrides Clause 0, cuts Darkmatter's fold, and stays in 1945 to help shut the substrate down. Bolt & Sprocket are pulled home. Peg pockets something again. A final Operator line in Sable Vantage's real voice: *"Thank you for your continued engagement. Your plan has been renewed."*
- **Rewards:** Overclock Cordial and Fine Print Fernet unlocked on all Gravelight maps; Bolt and Vendelin playable on all Gravelight maps; a **Nachtglas Seam** mallet skin and **Violet Recall** paint in B&S; Archive completion; and a "Season Two" tease for Gravelight Map 3 (where Reinholt's Darkmatter deal comes due).

### 10.7 The Gravelight squad meets Bolt (write this banter; it's the heart of the crossover)
- Dutch: *"Kid, I've seen a lot of things this winter. You're the first one that brought a hammer AND a sidekick."*
- Wren keeps a tally of Bolt's kills in her notebook and is annoyed that he's ahead.
- Deacon and Sprocket bond over machines immediately. Deacon talks to Sprocket like livestock; Sprocket is offended and then moved.
- Peg asks Sprocket very specific questions about "retrieval logistics." Sprocket: *"Bolt. The posh one is doing espionage at me."*
- Bolt never explains subscriptions to the squad. He starts to, and Sprocket stops him: *"Bolt. They've had a very long war. Let them have this."*

---

## 11. GRAVELIGHT AMENDMENTS (these override Appendix A)

1. **Nachtglas origin:** it is the Sol-3 probe's DARK-GLASS™. Gravelight characters never learn this.
2. **Helvetia Automaten AG** was founded by "Herr Viktor Vendelin." Every machine gets the §10.2 human backstory, its plan ID under the paint (visible only after The Fine Print is completed, or when lit by an upgraded weapon's muzzle flash: "a stencil under the enamel"), and a readable **fine-print panel on the back**.
3. **Formula backstories updated** per §10.2: Trigger Tonic → Dr. Ilse Vogt; Twin Barrel Bitters → Major Anselm Brück; Marathon Malt → Res Gähwiler's grandmother; **Hawkeye Brandy → derived from Halina "Sowa" Kurek, Wren's mentor** (add Wren VO for drinking it); Packmule Porter → Feldwebel Gustl Ammer; Blastproof Bock → reached the SOE via Res (Peg dossier tie-in). Ironhide (Otto Kessler) and Second Wind (Sister Agnieszka plus Vendelin's hidden battery) are expanded.
4. **The Crucible** gets the "MOD. R-E · PAT. PEND." plaque with Blartz's patent number. Its upgraded weapons still use Appendix A's names.
5. **The Operator** occasionally slips into corporate language, rarely and unsettlingly, more often at high rounds: "Thank you for your continued engagement." / "Your plan has been renewed." / "Valued customer, please do not cancel." Write 20+ slip lines.
6. **Reinholt's motive deepened:** Darkmatter (Sable Vantage, unnamed in Gravelight, called only "the Woman in Violet" in Reinholt's recordings) offered to bring Liesl back as a service. Map 3's moral choice now includes refusing the offer for her.
7. **Map list:** Map 0 Crossroads Inn, Map 1 Kaltenbrunn (both full), Map 2 Totenhafen and Map 3 Morgenrot (outlines), **Helvetia Works** (full; it is The Fine Print Ch. 5 and also playable as a standalone zombies map once unlocked).
8. **The rare B&S crate pool** (an "Anomalous Inventory" toggle in settings, default ON after Origins completion) can appear on Gravelight maps at very low weight, with a unique Operator line ("This item is not from your era. Please enjoy responsibly.").
9. **Bolt and Vendelin** become playable on all Gravelight maps after Helvetia Works, with full quote packs per map.

---

## 12. UNIFIED FRONT END & META PROGRESSION

- **Main menu hub:** a moody 3D scene of **Blartz's shop at night**. Bolt's ship is parked outside, and in the corner a dusty Helvetia perk machine hums its jingle, out of place. Menu doors:
  - **BOLT & SPROCKET** (campaign, side modes, NG+)
  - **GRAVELIGHT** (map select)
  - **THE FINE PRINT** (chapter select, locked until unlocked)
  - **THE ARCHIVE**
  - **EXTRAS** (gallery, ads, trophies, photo mode, credits)
  - **SETTINGS**
- **Unlock flow:** B&S campaign and Gravelight Map 0 are open from the start. **The Fine Print Ch. 1** unlocks after the B&S ending. **Ch. 2–3** unlock after Gravelight Map 1's main Easter egg, OR on reaching round 20 on Map 1, so non-EE players still progress. **Ch. 4** unlocks after Ch. 1–3. **Ch. 5 / Helvetia Works** unlocks after Ch. 4.
- **One save profile** (versioned JSON with migrations) holding three progress tracks plus a shared **Fine Print Archive**: the B&S memos (40), Gravelight intel, and Fine Print documents, cross-linked with "see also" so the player can trace one fact across both worlds.
- **Cross-rewards** (cosmetic only, never pay-to-win): Gravelight weapon camos unlock B&S mallet seams and paints; B&S trophies unlock Gravelight calling cards; Origins rewards per §10.6.
- Each mode keeps its own HUD and rules. Never let B&S's bright HUD bleed into Gravelight.
- **Settings:** everything from the original `SETTINGS_DEF` (aim-assist stickiness per device, camera, etc.) plus the Gravelight settings (FOV, ADS sensitivity, Classic Rules, hint mode), subtitles on by default, colorblind modes, a TTS-voice toggle, and remapping.

---

## 13. MILESTONES (each has acceptance criteria; run the tests AND launch the game before calling a milestone done; tag each one)

- **M0 — Port inventory & bible.** Build the extraction tool and dump all original data into `/data/bs_source/`. Write `docs/BS_PORT_INVENTORY.md`, `CANON.md`, `TIMELINE.md`, `GDD.md` (the combined game), `BS_WEAPONS.md`, `BS_ENEMIES.md`, `BS_LEVELS.md` (with diagrams), `FINEPRINT_LORE.md`, `FINEPRINT_SCRIPT.md` (first full pass), `JINGLES.md` (8+2 jingles with full lyrics plus fine-print panels), `STORY_CHANGES.md`, `ASSETS.md`, `DECISIONS.md`, and `ROADMAP.md`. Also write the Gravelight docs required by Appendix A's M0 (LORE, CHARACTERS, WEAPONS, ENEMIES, VO_SCRIPT), with §11 applied. Create the Godot project skeleton, autoload stubs, and git repo. Present the HUMOR-REVIEW items as a yes/no list. → **PAUSE for my review.**
- **M1 — Shared core + Bolt vertical slice.** Implement the third-person controller at parity with the web build (checklist signed off), the mallet string and throw, Sprocket with barks, aim assist, the weapon wheel, Omni-Blaster plus 3 more redesigned weapons with V-levels, the full **Scrapheap Junction** remake with Rusty's Row, the Billing Mast, and REPO-TRON, the Blartz shop, saving, TTS voices with subtitles, and the dev console. Acceptance: I can play the intro through Repo-Tron, and it feels as good as or better than the web version.
- **M2 — Gravelight vertical slice.** Build the first-person controller on the shared core, plus Appendix A's M1 and M2 scope on **Map 0 Crossroads Inn** (rounds, barricades, scrip, wall-buys, doors, crate, power-ups, all 8 perk machines with §11 backstories and fine-print panels, Operator lines, the radio mini-quest). Acceptance: round 15 feels tense and fair.
- **M3 — The full B&S arsenal + Act 1–2.** All 16 weapons with V1–V5 levels, mods, and Signature Mods; Rustvane Canyon complete (Sentinel, Content Creator, GLAMBOT defection, Tether-Hook); the shield reveal; Nova Plaza complete. The **Omega Forge** is built and testable via the dev console; in the story it unlocks at the Foundry Blartz rescue in M4.
- **M4 — B&S complete campaign.** Glacius, Verdant (with Grind Soles and Glide), the Grand Galleria, Core Foundry in full (the Blartz rescue and Omega Forge unlock, Clause 44, the Grindstone finale), the ending, the memo epilogue, post-credits, all side quests, all 40 memos, flyovers, the star map, space travel, the cutscene gallery, all 17 ad vignettes.
- **M5 — Gravelight Map 1 Kaltenbrunn.** Appendix A's M3 and M4 scope, with §11 applied.
- **M6 — B&S side modes & extras.** Zonga, Colosseum, Grand Prix plus Skyway, Loop Riot, Firing Range, Photo Mode, NG+, cosmetics, trophies.
- **M7 — The Fine Print Ch. 1–4.** The Retention Spire, Field Unit, the Helvetia vignettes (all perk stories), the Patent Pending heist, and The Quarterly boss.
- **M8 — Helvetia Works + finale.** The full crossover map, Bolt and Vendelin as FP characters, Audit Rounds, the Underwriter, the Return Policy wonder weapon, the Original Omega Forge second tier, the "Clause Zero" Easter egg, and the ending.
- **M9 — Unified front end & meta.** The menu hub, unlock flow, save profile, Archive cross-linking, cross-rewards, Gravelight rank/prestige/dossiers/mastery (Appendix A §12), settings, and controller polish.
- **M10 — Art/audio pass & polish.** Swap in sourced CC0 assets; give each world its own art direction (B&S: bright stylized, orange/cyan, rim light; Gravelight: desaturated grit with Nachtglas as the only saturated color; Fine Print: 1940s Swiss-poster Basel and sterile Darkmatter violet). Then VFX, the audio mix, optimization, and a bug bash.
- **M11 (stretch) — Online co-op** for Gravelight and Helvetia Works (1–4 players), plus 2-player co-op for the Colosseum.

## 14. YOUR FIRST RESPONSE
1. Confirm the plan in a few lines and list your assumptions.
2. Copy the reference files and build and run the extraction tool. Report what you extracted (table names, counts of lines, memos, quests, enemies, etc.) and anything that didn't parse.
3. Execute all of M0. Write every doc in full: no placeholders, no "TBD" in story or design docs.
4. Create the Godot skeleton and commit.
5. Stop and give me a short review list, including the HUMOR-REVIEW yes/no list and every story change you propose.

---
---

# APPENDIX A — GRAVELIGHT: full original spec (amended by §11; its §0.6, §15 and §16 are superseded by §13–§14 above)

## A0. HARD RULES
1. Do NOT use any assets, names, audio, characters, logos, or lore from Call of Duty or any other commercial game. No "Juggernog," "Pack-a-Punch," "Element 115," "Ray Gun," "Monkey Bomb," "Samantha," "Group 935," etc. Generic mechanics (rounds, barricades, points, wall-buys, a random weapon crate, perk drinks, an upgrade machine) are fine. Real WW2 firearms are fine.
2. Only use assets that are original, CC0, or explicitly licensed for commercial game use. Track every third-party asset in docs/ASSETS.md.
3. Build greybox-first. Gameplay must be fun in greybox before any art pass.
4. All tuning numbers live in data files, never hardcoded in logic.
5. Work autonomously; log decisions in docs/DECISIONS.md; break hard problems up instead of stalling.
6. *(Superseded by main §0.9.)*
7. Use git. Commit at every meaningful step. Tag milestones.

## A1. TECH (shared core per main §1)
- Solo first, but architect so 1–4 player online co-op can be added later. Keep authority logic separate from presentation (server-authoritative-ready).
- Core systems: an Interactable base class (context prompts like "Hold [F] to buy Trench Gun [1500]", hold-to-use, cost check, rejection sound). Enemy AI on NavigationAgent3D with the state machine Spawn → Emerge/Climb → Tear Barricade → Enter → Chase → Attack → Stagger/Crawl → Die; window-entry zombies path to barricades first; staggered path updates, AI LOD, pooling. Limb hitboxes (head, neck, torso, arms, legs) with multipliers; leg damage creates crawlers. Event bus.
- Target 60+ FPS with 24 active zombies.

## A2. CORE LOOP & NUMBERS (tunable)
- Start: 500 Scrip, M1911, 2 frag grenades, trench knife.
- Zombie health: 150 at round 1, +100 per round through round 9, then ×1.1 per round from round 10. Count scales with round and player count. Max 24 active; the rest queue.
- Speed tiers: shamblers (rounds 1–3), mixed walkers/joggers (4–7), runners (8+), sprinters increasingly from round 12+. Mix tiers within rounds.
- Down = game over in solo unless Second Wind is held. In co-op: revive (base 4s), bleed out after 45s.
- Health 100; a zombie hit = 50 (2 hits downs you; Ironhide raises this). Regen after 4s without damage.
- Barricades: 6 boards per window. Repair = +10 Scrip per board (cap 500 per round).
- 10–15s break between rounds with a transition stinger.

## A3. ECONOMY — "SCRIP"
Non-lethal hit +10; kill: body +50, neck +60, head +100, melee +130; repair +10/board. Doors scale 750 / 1000 / 1250 / 1500 / 2000. Wall ammo = half the weapon cost; upgraded-weapon ammo from walls = 4500.

## A4. STORY & WORLD (full version in docs/LORE.md; apply main §11)
Winter 1944–45, occupied Silesia (fictional locations). Grim pulp horror with gallows humor: a lost war film that slowly becomes a ghost story.
- **Nachtglas:** black glassy mineral with violet-amber veins, recovered in 1938 from a "meteorite" strike in the Kaltenbrunn salt mine. It hums. Dead tissue near it keeps running its last impulse, and in the end that impulse is hunger. Living tissue dosed with diluted Nachtglas gains temporary traits, which is the basis of the perk tonics.
- **Projekt Wiederkehr ("Project Return"):** officially soldier enhancement and battlefield reanimation. Lead scientist **Dr. Augusta Reinholt** privately wants to bring back her daughter **Liesl** (died of diphtheria, 1939). Colleague **Dr. Emil Fasbender** realized what the material really does and radioed the Allies offering to defect.
- **The Ledger:** a room-sized relay computer that tallies every body that "goes quiet" and credits Scrip. It speaks through the PA as **THE OPERATOR**, a cheerful 1930s radio-announcer voice sampled from propaganda tapes. Polite, chipper, wrong in unsettling ways, hinting at self-awareness.
- **Helvetia Automaten AG:** a "neutral Swiss vending company" from Basel, contracted in 1940 to build the coin-op tonic dispensers. That's why the perk machines are bright, branded, and absurd in a war zone. Each tonic has 1940s advertising and a jingle.
- **Operation Gravelight:** a joint SOE/OSS team sent to extract Fasbender. Their transport is brought down near Kaltenbrunn by something that isn't flak.
- **Arc:** Map 0 "Crossroads Inn" (survival prologue; Fasbender's radio first contacts the squad). Map 1 "Kaltenbrunn" (restore the Resonance Array, confront Reinholt's work, collapse the Nachtglas heart; Reinholt escapes with a fragment by rail). Map 2 "Totenhafen" (outline: a Baltic U-boat pen shipping Nachtglas out). Map 3 "Morgenrot" (outline: an Alpine observatory-fortress where Reinholt tries to wake Liesl; finale moral choice; Peg's secret orders come to a head). Every map answers one story question and raises a new one.

## A5. PLAYABLE CHARACTERS (docs/CHARACTERS.md: full bios plus 40+ quote lines each)
Each has a distinct voice, a personal stake, banter with every other character, and quotes for weapon buys (per class), crate results, each perk, power-ups, special rounds, low ammo, downed, reviving, streaks, headshots, Easter-egg steps, and round 50+ exhaustion.
1. **Sgt. Walter "Dutch" Kowalczyk** (US Army Ranger, 34). A Pittsburgh steelworker's son, Polish-American; his grandmother came from villages near Kaltenbrunn, so the dead could be distant kin. Speaks broken Polish with Wren. Blunt, deadpan, complains constantly, never quits.
2. **Lt. Margaret "Peg" Ashworth** (British SOE, 29). Demolitions expert and mission commander. Cool, sardonic, posh, knows more than she says. Secret: sealed orders to retrieve a Nachtglas sample at any cost.
3. **Cpl. Elijah "Deacon" Brooks** (US 761st Tank Battalion mechanic, 26). A preacher's son from Louisiana and the moral center. Can fix anything. Quietly funny; quotes scripture and blues lyrics he writes himself; talks to machines like livestock; takes it personally that machines here are used for evil.
4. **Zofia "Wren" Nowak** (Polish Home Army sniper, 24). A local who knows the mine; her brother was a forced laborer at Kaltenbrunn and never came out. Fierce, precise, darkly funny; keeps a kill tally in a notebook.
- **NPCs:** Dr. Emil Fasbender (radios/PA, nervous, guilty, brilliant, gives puzzle hints, with some doubt about his trustworthiness); Dr. Augusta Reinholt (tragic antagonist, heard via recordings, phonograph cylinders, and late PA hijacks); the Operator; Liesl's tin drummer (a wind-up toy tied to the crate).
- **Optional traits** (Classic Rules toggle disables them): Dutch +10% melee; Peg shows cook time and has +1 grenade; Deacon repairs/builds/trap cooldowns 15% faster; Wren +10 Scrip on headshot kills.

## A6. ENEMIES (docs/ENEMIES.md)
- **Gängers** (soldier slang from "Wiedergänger"): soldiers, miners, lab staff, and forced laborers, with violet eye glow and cracks. Speed tiers per A2. Limb loss creates crawlers.
- **Glasshides** (round 15+): partly crystallized; armored torso takes 50% damage; aim for the head or use explosives; they shatter on death.
- **Bellringers** (special round every 5–7 rounds, first on round 5–6): the chapel bell tolls, fog rolls in, lights flicker; fast, emaciated lantern-carrying miners come in packs from fog portals and burst into shards. Clearing the round guarantees a Resupply. Lore: the bell is the resonance alarm.
- **The Foreman** (Map 1 boss, first appears round 12–14): a towering mine overseer fused with a pneumatic drill arm and dragging ore chain. Charge and ground slam; glowing drill-core weak point; drops big Scrip and a quest item.
- **Screamer** (Map 1, round 20+, rare): a Nachtglas-saturated field nurse whose scream distorts the screen/audio and slows the player.
Every enemy needs a readable silhouette, distinct audio tells, and a lore justification.

## A7. WEAPONS (docs/WEAPONS.md)
- 2 slots (3 with Packmule Porter). Stats: damage, falloff, limb multipliers, RoF, mag, reserve, partial/empty reload, ADS time, sway, penetration, upgraded variant.
- **Start:** M1911, trench knife, Mk 2 frags.
- **Wall-buys:** Kar98k 200, M1 Garand 600, Gewehr 43 900, M1 Carbine 600, MP40 1000, Thompson M1A1 1200, STG-44 1200, Trench Gun (M1897) 1500, BAR 1800, Sharpened E-Tool (melee upgrade) 3000, Frag refill 250.
- **Crate pool (weighted):** PPSh-41, MG42, Browning M1919, Double-Barrel Sawed-Off, Type 100, PTRS-41, scoped Springfield M1903, Panzerschreck, M2 Flamethrower, Siren Gramophone, Ashlight (low weight), plus some wall weapons. Weight it so the first pulls feel good.
- **Siren Gramophone** (tactical, crate only): plays a scratchy original record, lures zombies for 8s, then detonates. Lore: Reinholt's lab used it to herd test subjects.
- **Wonder weapons:** **Ashlight** (crate): a brass-and-glass energy pistol whose Nachtglas bolts ricochet once and splash; Fasbender's "resonance projector" prototype. **Totenglocke** (Map 1 buildable, 3 parts: bell from the Rail Yard, frame from the Barracks, crank from the Salt Chapel; built at the Generator Hall workbench): a handheld bell-cannon whose resonant shockwave cone shatters zombies; limited charges.
- **Crucible-upgraded names:** M1911 → "Last Rites" (ricochet once); Thompson → "Chicago Lament" (bigger mag, AP); MP40 → "Grabesgesang" (+damage, faster reload); STG-44 → "Sturmwind" (burst mode, more mag); Trench Gun → "Gravedigger's Due" (incendiary); Kar98k → "Final Verdict" (penetrates 4); BAR → "Ironmonger" (mag, stagger); MG42 → "Bone Saw" (bigger belt); PPSh-41 → "Red Winter" (frost slow); Panzerschreck → "Stovepipe Sermon" (cluster bomblets); Double-Barrel → "Twin Coffins" (four-barrel volley); M1 Garand → "Eight-Ping Benediction" (rifle grenade); Ashlight → "Ashlight Corona" (chains to 3); Totenglocke → "Totenglocke: Mitternacht" (larger cone, more charges). Name all others in the same grim, dry, wartime-slang style.

## A8. PERKS, CRATE, CRUCIBLE, POWER-UPS, TRAPS (apply main §10.2 and §11)
**Perk Tonics** (Helvetia Automaten AG; all need power except Second Wind in solo). Cap: 4. Each machine has a unique design, a bottle-cap HUD icon, an original 1940s jingle (full lyrics in docs/JINGLES.md), a drinking animation, and a backstory. Machines hum and occasionally play their jingle when approached.
1. **Ironhide Stout**: 2500. Survive 5 hits instead of 2 (max health 250). Iron-red, riveted-barrel mascot.
2. **Second Wind Schnapps**: 500 solo / 1500 co-op. Co-op: revive 2× faster. Solo: self-revive, 3 uses, then the machine disappears. Pale blue.
3. **Trigger Tonic**: 3000. Reload 50% faster. Lime-gold; frantic cartoon hare.
4. **Twin Barrel Bitters**: 2000. Fire rate +33%. Amber; mustachioed artillery sergeant.
5. **Marathon Malt**: 2000. Unlimited sprint, +7% move speed. Winged boot.
6. **Hawkeye Brandy**: 1500. Reduced sway, faster ADS, +headshot damage. Wren hates that it works.
7. **Packmule Porter**: 4000. Third weapon slot (lose the third weapon when downed).
8. **Blastproof Bock**: 2000. Immune to your own explosive and fall damage; sliding releases a small concussive shockwave.
Perk loss on down follows classic rules (all lost in co-op; solo Second Wind keeps the others).

**Mystery Crate ("Lost Requisition Crate")**: 950. Battered quartermaster crate with Nachtglas light; weapons cycle. 5 locations on Map 1, 3 on Map 0, starting location randomized among 2. After a random 4–12 uses, Liesl's tin drummer appears and drums, the crate sinks, the player is refunded, and a violet beam marks the crate's new location.

**The Crucible**: 5000. A Nachtglas furnace in the Map 1 Core Vault. 5s to upgrade; the weapon is held for 15s before it's lost; stealable in co-op; refills ammo. Re-upgrade ammo: 2500.

**Power-ups** (announced by the Operator; drop eligibility by Scrip threshold, max 4 per round, shuffled bag, blink and vanish after 30s): Resupply (full ammo and grenades), Death's Door (insta-kill 30s), Double Scrip (30s), Blackout (kills all active zombies, +400), Fortify (all barricades, +200), Clearance (after the crate has moved once: all crate locations cost 10 Scrip for 30s). Original stencil icons.

**Traps** (Map 1; 1000 each, 25s, 90s cooldown): Runaway Ore Cart (Rail Yard), Live Wire Fence (Generator Hall; can down players), Chandelier Drop (Salt Chapel; once per round).

## A9. MAP 0 — "CROSSROADS INN" (tutorial-scale; no power, no perks unless amended by M2 scope)
A two-story roadside inn and stable at a snowy crossroads; the squad's crashed transport plane burns in a nearby field. Spawn: the taproom (bar, fireplace, 4 windows; Kar98k and M1 Garand wall-buys). Door 1 (750): upstairs rooms (2 windows, MP40, crate spot). Door 2 (1000): stable/barn (3 windows, Trench Gun, crate spot, hayloft perch). 3 crate locations. A crackling radio: Fasbender makes contact over the rounds ("You must reach Kaltenbrunn. Follow the rail line. Do not let the bell ring."). Mini-quest: tune the radio to 3 frequencies from notes for a cutscene and map-complete flag. Map 0 teaches barricades, wall-buys, doors, the crate, power-ups, and escalation. *(For the M2 vertical slice, also place the 8 perk machines in a cellar reached by a 1500 door, so the perk system can be tested; flag this in DECISIONS.md.)*

## A10. MAP 1 — "KALTENBRUNN" (flagship)
A salt mine and research complex at night descending into glittering salt caverns: surface → administration → depths → heart. It needs 3 training loops (Minehead Yard around the headframe, Salt Chapel pews, Generator Hall turbines) and camping chokes. Every room justifies itself.
- **A. Minehead Yard (spawn):** courtyard, steel headframe, gatehouse, coal shed, 4 windows; Kar98k and M1 Carbine; Resonance Pylon (inactive until power).
- **B. Rail Yard** (750): ore carts, boxcar (crate), locomotive; MP40, frag refill; Runaway Ore Cart trap; Totenglocke bell.
- **C. Administration Block** (1000, 2 floors): offices, switchboard, Fasbender's radio room, intel; Second Wind (works pre-power solo); Gewehr 43; balcony over the Yard.
- **D. Barracks & Mess** (1250): Ironhide Stout, Trench Gun, crate spot; Totenglocke frame.
- **E. Lift Shaft** (1250): cage elevator, 25s ride, 60s cooldown; Maintenance Stairs (1500) alternate route.
- **F. Salt Chapel** (level -2): a cathedral cavern with salt chandeliers, an altar, THE BELL; Twin Barrel Bitters, Marathon Malt, BAR, crate spot, Chandelier Drop; Pylon; Totenglocke crank.
- **G. Generator Hall** (1500): turbines, THE POWER SWITCH ("Hauptschalter"); Trigger Tonic, STG-44, Live Wire Fence, Totenglocke workbench.
- **H. Laboratory Wing** (power, 2000): Reinholt's and Fasbender's labs, specimen tanks, Liesl's nursery shrine; Hawkeye Brandy, Packmule Porter, Blastproof Bock, crate spot; third Pylon.
- **I. Core Vault:** opens when all 3 Pylons are attuned; the Nachtglas heart in a cage; THE CRUCIBLE (with the §11 plaque).
- **Power-on:** an Operator line, lights sweeping zone by zone, jingles kicking in, a burst of zombies.
- **Pylon attunement:** 1500 each after power; a 45s holdout with heavy spawns; the charge pauses and drains if everyone leaves the radius; all 3 → the vault opens with a camera shake, the heart pulsing, and Reinholt's voice heard for the first time.

## A11. MAP 1 MAIN EASTER EGG — "REQUIEM FOR KALTENBRUNN"
Solo- or co-op-doable; no hidden hard-fail steps; data-driven step graph with per-match save points and debug skips.
1. Power on, all 3 Pylons attuned, the Vault open.
2. Fasbender's codes: 3 randomized radios each play a fragment; enter the code at the Admin switchboard; Fasbender speaks directly.
3. Build the Totenglocke.
4. Kill the Foreman inside the Salt Chapel while the bell is lit (shoot it with an upgraded weapon); he drops the Overseer's Key.
5. The key opens the altar reliquary: Liesl's music box plays a randomized 4-note melody.
6. Shoot 4 hidden bells in melody order (a wrong order resets, with a mocking Operator line).
7. On the next crate move, the tin drummer walks away; shoot it to get a Nachtglas shard.
8. Place the shard in the Crucible; kill 30 zombies with the Totenglocke near the Core.
9. Heartstorm: a 2-minute holdout with Bellringers and Gängers, Reinholt hijacking the PA, and the Foreman appearing twice.
10. Ending: the heart collapses; Reinholt flees by ore train with a fragment; Peg pockets a shard unseen.
Rewards: all perks for the rest of the match (above the cap), a permanent extra perk slot on Map 1 (cap + 1), big XP, a dossier page, an Archive entry, and Map 2 unlocked (outline screen). Side eggs: 3 phonograph cylinders unlock an original song (write the lyrics); Wren's brother's forced-labor ID tag in the Lab Wing triggers a Wren/Dutch exchange.

## A12. PROGRESSION (never pay-to-win)
In-match: rounds → Scrip → doors → power → perks → Crucible → quest, with soft objectives via quotes (optional hint mode). Meta: Player Rank 1–60 from XP (kills, headshots, rounds, revives, doors, EE steps, challenges) unlocking cosmetics; Prestige 1–10 ("Commendations"); Character Dossiers levels 1–10 (backstory pages, audio diaries, outfits, quote packs, final secret page); Weapon Mastery camos (Olive Drab → Winter → Bronze → Silver → Gold → "Nachtglas"); map unlocks (Map 1 after round 10 on Map 0 or its radio quest; Map 2 from the Map 1 EE or round 30); Intel Archive (3–5 random intel per match, feeding the shared Archive); rotating challenges; stats page.

## A13. PRESENTATION
Late-war grit: desaturated cold blues and snow, warm sodium lamp pools, Nachtglas as the only saturated color (deep violet with amber cracks), heavy fog and volumetrics, film-grain option, slight vignette. HUD: round number as a red ink ledger stamp bottom-left that "thunks" on change, Scrip bottom-right with floating +numbers, perk bottle caps above the round, ammo bottom-right, center context prompts, no minimap. Audio: original round stingers, an ambient score intensifying with round, per-zombie-type vocals, punchy weapons, perk jingles, Operator lines; all VO scripted in docs/VO_SCRIPT.md with line IDs and routed through the VOManager with cooldowns and priority.

## A14. ASSET PIPELINE
Greybox with CSG, color-coded (green buyable, blue door, red window, yellow perk, purple quest). docs/ASSETS.md manifest with recommended CC0/licensed sources (Kenney, Quaternius, Poly Haven, ambientCG, Mixamo animations, Freesound CC0, Sonniss GDC bundles) and status. Gameplay scenes reference visual subscenes, so art swaps never touch logic.

## A15–A16. *(Superseded by main §13–§14.)*
