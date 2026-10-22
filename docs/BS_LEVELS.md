# Bolt & Sprocket: Level Design

The blueprints for the remade planets (brief §6): the prologue garage, Scrapheap Junction, Rustvane Canyon, Nova Plaza, Glacius Vault, Verdant Sink, the Grand Galleria and Core Foundry. Each planet section starts with **what the web build actually contained** (read from the `build*` functions, `LEVELS`, the terrain specs and the planet configs in `reference/bs_web/index.html`), then gives the **remake design**.

Related docs: `BS_PORT_INVENTORY.md` (everything to port), `BS_ENEMIES.md` (enemy and boss behaviour), `BS_WEAPONS.md` (guns and their unlocks), `CANON.md`, `M0_SHARED_FACTS.md`. This doc only gives boss **arena space and phase geometry**; the bosses themselves live in `BS_ENEMIES.md`.

---

## 0. Rules that apply to every planet

### 0.1 Units and orientation
- Units are metres. Bolt walks 7 m/s, sprints 10.5 m/s, jumps about 2.4 m (double jump about 4.6 m with apex hang), hovers 1.5 s, dashes about 3.8 m.
- Diagrams are top-down with **north up**. North is the source's −z axis (the direction the web build's levels run toward their boss).
- Coordinates in "Original" sections are the source's `(x, y, z)`. Coordinates in "Remake" zone tables are the remake's `(x, z)` centre, size and floor height, in the same frame, so builders can lay the greybox straight from the tables.

### 0.2 Diagram legend
```
[ZONE NAME]   a zone          ===  golden ride-rail / zip line (no gadget needed)
P   landing pad               ~~~  liquid or kill plane
R   Return Relay (exit)       ##   wall or cliff
X   boss arena                ..   path / breadcrumb trail
A   arena challenge           >>>  conveyor or walkway (arrow = default direction)
S   secret area               (T)  Tether-Hook point       (G) Grind Soles rail
*n  gold bolt n               (L)  Glide gap               (B) boomerang switch
Mnn memo nn                   (F)  Magma-throw target       (Z) Thunder-throw relay
Q   quest giver               !id  story beat / cutscene trigger
r   relay checkpoint          U    updraft
```

### 0.3 The landing pad kit
Every planet has one landing pad in its hub. It always holds the same four things, in the same arrangement, so the player never has to look for them:
1. **Bolt's ship.** Enter the cockpit to open the **star map** (travel, mission tracker). The ship also has a **stash locker** for cosmetics and the voice-filter cosmetic.
2. **Blartz kiosk** (shop v2). After the Blartz rescue in Core Foundry, every kiosk also has an **Omega Forge** bolted to its side (brief §5.1). Until the rescue, the Foundry's kiosk shows "BACK IN 5 MIN (ARRESTED)".
3. **Save Beacon.** A pylon on the pad's edge. Interact to save manually and refill to full HP. The game also autosaves at every relay checkpoint, quest step, memo, gold bolt and core (the web build only autosaved; the beacon is the brief's "save point").
4. **Pad relay.** The default respawn point.

### 0.4 Exits, relays and respawns
- **Return Relay** (`R`): the web build's "teleporter" goal pad (`placeGoal`, "EXIT ONLINE! Get to the teleporter!"). It lights up when the planet's boss falls (or its core is taken). Stepping on it ends the planet (summary screen), then beams Bolt back to the ship and opens the star map. The player can also leave by ship at any time without finishing.
- **Relay checkpoints** (`r`): the web build's nanotech relay pylons. Touch one to set the respawn point and heal 25% of max HP (`activateCheckpoint`). Every boss arena mouth has one.
- **Falls and liquids** follow the web build (`updatePlayer` L3600–3640):
  - **Kill planes** (void, lava, slag, deep murk, vacuum): 20 damage, then reset to the last safe ground (sampled every 0.4 s).
  - **Water-type liquids** (water, scalding pool, meltwater): 8 damage, splash, reset, and a `SPLASH_QUIPS` bark at most once every 20 s.
  - Each planet section lists which quips play where. The source picked from all six at random; the remake picks from a per-planet pool so the joke fits the place.
- **No invisible walls.** Every boundary is something in the world: a cliff, a fence with a sign, a force field with a notice, a liquid. Where the player could reasonably try to leave, there is a sign or a bark.

### 0.5 Gadgets and how they gate secrets
Gadgets are earned on the main path of one planet and then open secrets everywhere (brief §4.1, §6).

| Gadget | Earned | Marker in the world | Starting tuning (data, not code) |
|---|---|---|---|
| **Boomerang mallet throw** | Start (prologue teaches it) | Yellow-black bullseye plates `(B)`, crane levers, latches | Source throw: 18 dmg, 24 m/s, 0.55 s out (≈13.2 m reach), returns at 1.2× speed, 1.2 s cooldown (`CONFIG.melee.throw`). Remake adds: it curves toward a switch within 18° of the aim line; it picks up loose bolts within 1.2 m of its path on both legs; it hits switches on either leg. |
| **Magma throw** | Buy the Magma Mallet (220 bolts, any time) | Wax seals, tarp and vine curtains, ice plugs `(F)` | The thrown Magma Mallet ignites what it touches; ice plugs melt in 1.5 s. |
| **Thunder throw** | Buy the Thunder Mallet (450 bolts, any time) | Dead junction boxes with a blue lightning glyph `(Z)` | The thrown Thunder Mallet powers a box for 10 s and arcs to one more box within 8 m. |
| **Tether-Hook** | Rustvane Canyon (Old Co-op Camp) | Orange cable-anchor rings `(T)`; green rings are pull points | Acquire range 16 m within a 30° cone of the camera; rope length = attach distance clamped to 5–14 m; swing gravity 38 m/s² (`jump.fallGrav`); pumping adds 6 m/s² along the swing; max swing speed 18 m/s; release keeps velocity and adds 4 m/s up, then double jump and hover are available; pull points reel at 20 m/s and end in a 6 m/s hop; 0.25 s re-fire. Sprocket flies the cable to the ring and is the anchor (he comments on his weight limit). |
| **Grind Soles** | Glacius Vault (Premium Tier) | Blue frost-striped pipes and edges `(G)` | Golden ride-rails stay usable without the Soles, exactly as in the web build (auto-ride at 13.5 m/s, 17 m/s with sprint, attach within 1.9 m, jump-off 10.5 m/s up). With the Soles Bolt can also grind any `(G)` surface, with manual speed: +6 m/s² downhill per unit of slope, −4 m/s² uphill, never below 6 m/s; side-hop to a parallel rail at 6 m/s; Loop Riot grind names score combo bolts (50-50, Boardslide, Lipslide, 5-0, Nosegrind). |
| **Sprocket Glide** | Verdant Sink (Union Hall) | Local 404 wind-sock pennants `(L)` at gap edges | Engages when jump is held after the hover meter is empty. Fall speed capped at 3 m/s, forward speed 9 m/s (accel 6 m/s²), turn rate 120°/s. Updrafts lift a glide (force 30, as `addUpdraft`). Dash, slam or landing cancels it. Rule of thumb for builders: **a glide gap may be at most 3 m of horizontal distance per 1 m of drop** (30 m from a 10 m height). |

**Main-path guarantees.** The core-hunt planets can be played in any order, so main paths only ask for what the player is certain to have:

| Planet | Gadgets the main path may require | Secrets may also require |
|---|---|---|
| Scrapheap Junction | Boomerang | Everything |
| Rustvane Canyon | Boomerang, Tether-Hook (earned mid-level) | Everything |
| Nova Plaza, Glacius Vault, Verdant Sink | Boomerang, Tether-Hook, plus that planet's own gadget after it is earned | The other two core-planet gadgets, Magma and Thunder throws |
| Grand Galleria (opens after the first core) | Boomerang, Tether-Hook | Grind Soles, Glide, Magma, Thunder |
| Core Foundry (needs all 3 cores) | All three gadgets | Magma, Thunder |

### 0.6 Collectibles and counts
- **Gold bolts:** 30 in the campaign (Scrapheap 5, Rustvane 4, Nova 4, Glacius 4, Verdant 4, Galleria 4, Foundry 5). The 21 source locations are all kept; 9 new ones are added, mostly behind gadgets. Gold bolts are now a currency (brief §4.3); the star map and summary screen show "n / total" per planet (fixes the web build's stale "/ 9").
- **Memos:** 40. Memos 1–35 keep the `MEMO_SPOTS` intent (each memo sits where its joke lands). The 5 hidden Darkmatter memos (36–40, `hidden: true` in `additions.json`) follow DECISIONS T-012 and sit behind gadget secrets. Each planet keeps its own 5 OmniScrap memos.
- **Side quests:** 19, by remake ID. Givers stand where they did in the web build, as near as the new layout allows. Quest hints are **Sprocket barks, not waypoints**: when a quest is active and the player is within 25 m of an item or target, Sprocket remarks on it (smell, sound, a glint) once per 60 s. Each planet section says what the hint points at.
- **Nanotech:** every planet keeps its source nanocrates and its annex vault's permanent +20 HP upgrade.

### 0.7 Optional arena challenges
Each planet has one **GLAMBOT Pop-Up Segment**: a short arena challenge in a space built for it (usually the plaza of the planet's v13 annex wing). GLAMBOT is the host, so pop-ups appear only after he defects (`l2_glambot`). On Scrapheap that means a return visit; on Rustvane it opens as soon as the boss falls. Each pop-up pays bolts, records a best time, and shows on the Colosseum's records board. They are separate from the GLAMBOT Colosseum mode.

### 0.8 How every room tells the story
Every zone below answers three questions in its row: **what OmniScrap built it for**, **who got screwed**, and **how the space shows it** (signage, props, set dressing that a player reads without text boxes). If a room cannot answer all three, it gets cut.

---

## 1. The Prologue: Bolt's Garage

### 1.1 Original
- There is no separate prologue level. `newGame` (L17536) loads Scrapheap and runs `intro` immediately.
- The garage is a small box with a roof slab, a door and a glowing "BOLT'S" sign at `(13, 0, 2)`, beside the hub's landing yard (`buildLevel1` L9547). The intro cutscene's `act` step lifts it 40 m and spins it away (L11364–11370).
- The first hints fire on the landing yard: move/jump at `(0, 3, 12)`, slide-and-slam under a low scrap pipe at `(0, 1.55, −2)`.

### 1.2 Remake: "The Last Morning"
A 3–4 minute playable tutorial in and around the garage, which ends in the `intro` cutscene. It sits on the south-east edge of Scrapheap's hub, so the empty lot stays there for the rest of the game.

```
            NORTH (the Junction's landing yard is 15 m north-west)
   +----------------------------------------------------+
   | SCRAP-FENCE YARD (14 x 12)                         |
   |   tire stack  car door ramp     workbench          |
   |   [3 m crates]      (B) pit-lid latch -> *1 pit    |
   |   +----------------------------+                   |
   |   | BOLT'S GARAGE (8 x 6)      |  roof 2.7 m       |
   |   |  bunk  toaster  shelf(M02*) |  sign "BOLT'S"   |
   |   |  workbench  low shelf (slide)                  |
   |   +-----------door-------------+                   |
   |   drive -> gate (repo drones land here)            |
   +--------------------- gate -------------------------+
                         |
                     to the Junction
```
*M02 appears on the empty lot after the cutscene (see Scrapheap memos).

| Beat | Space | What the player learns | Notes |
|---|---|---|---|
| 1 | Inside the garage | Walk, look, jump onto the bunk, double jump to the loft shelf | Sprocket wakes on the workbench (moods: `normal` → `happy`). Idle `BARKS` only; no new dialogue. |
| 2 | The low shelf by the door | Slide under it (sprint + crouch) to grab the mallet | The source's slide-teaching pipe moves in here. |
| 3 | Yard | 3-hit mallet string on a broken repo drone dummy; mallet throw at the yellow-black pit-lid latch `(B)` | The latch opens the inspection pit: **gold bolt 1**. |
| 4 | Yard crates and roof | Hover from the crates to the garage roof; slam off the roof onto a junk pile | Teaches hover and slam. |
| 5 | Gate | Repo drones land on the drive. Walking out of the gate starts `intro` | `intro` plays as written: PA announcement, the garage lifts away (the `act` rise step), "Two mallets and a sandwich!" |

After `intro`, the lot is a bare concrete slab with a stake sign reading "SECTION 12-B: EXISTING WITHOUT A SUBSCRIPTION", the inspection pit, and memo 02. The yard fence stays, so the lot is a small, readable landmark in the hub. NG+ replays the prologue (`startNGPlus` runs `intro`).

---

## 2. Scrapheap Junction (Planet 1, `LEVELS[0]`)

### 2.1 Original (`buildLevel1` L9537, `expandScrapheap` L9406, `buildAnnex` L9240)
- **Terrain** `TERRAIN_SPECS.p1`: 200 × 220 m centred on z −60 (so z +50 to −170), rolling scrap dunes, the ground climbing toward the exit yard. Warm sunset palette, fog 45–165 m, music root 130.8 Hz, theme `junk`. Kill plane y −8.
- **Hub / landing yard:** spawn `(0, 1.2, 12)`, pad `(−8, 0, 8)`, kiosk `(8, 0, 10)`, garage `(13, 0, 2)`, crates, a low pipe for the slide lesson.
- **Dune Bowl** (z −14 to −40): six mounds as cover; 3 scrap mutts, a tinker turret, a vulture; gold #1 in a pocket behind the west-rim wreck `(−19, 1.9, −32)`; `l1_glitch` at `(0, 2, −22)`.
- **Car-cube stair tower** `(10–14, −40 to −52)`: five crushed cars stacked into steps to a top at y 4.55, with a mutt on top and a crane tower beside it.
- **Conveyor yard** at y 5: a west belt (3.2 m/s) and a return belt (2.6 m/s) at z −52/−57, a west landing with a vulture, then a magnet-crane platform lift (patrol speed 0.55) up to y 9.6. Gold #2 on a slab you reach by bailing off the crane `(−17, 9.3, −60)`.
- **Buried starship hull:** a 26 m wreck lying north–south at z −70 to −96, interior walkway at y 9.5, light shafts through hull breaches, two tinker turrets, a heavy blast door at z −70.5 (`l1_mid`).
- **Hull-top vista** y 15 at z −86 (`l1_vista`, banner "The whole junkyard, from the wreck that started it"); gold #3 on a side slab `(6.5, 16.6, −82)`.
- **Grind rail** from the hull top down to the exit yard `(0, 15, −90) → (0, 4, −122)`.
- **Exit yard / Compaction Lot** (z −121 to −144): checkpoint, crushed-car walls, REPO-TRON at `(0, 2, −136)`, `l1_repo`, the goal pad at `(0, 2, −144)`. Banner on the kill: "FORECLOSURE REVERSED — The junkyard stays yours".
- **THE BONEYARD** annex, west of the hull from `(−24, −104)`: gate → slab climb + lift → wall-kick shaft → grind → **THE CRUSHER PIT** plaza fight → updraft vault with a nanotech upgrade.
- **Pocket A, the Buried Vault** `(−46, −40)`: slide under a 1.1 m lip into a sealed scrap cache with a nanocrate and the relocated gold #2 (🐞 the crane slab gold uses the same index).
- **Pocket B, Ridge Lookout** `(40, −70)`: dash and hover chain to a perch.
- **Rusty's Row** (x 25–48, z −5 to −25): 5 shacks with walkable roofs, a square with a fire barrel, a "FUSES · PARTS · SOUP" stall, string lights, a water tower `(45.5, −24.5)` with a nanocrate on its catwalk; `l1_row` at the gate; Mama Gasket at `(37.5, 0.4, −11.5)`.
- **Signal Mast** `(−36, −72)`: a spiral of six scrap steps to a crow's nest at y 16, a dish and a blinking beacon, a nanocrate; `l1_mast`; a golden cable rail back down to the dune bowl.
- **Set piece:** junk processor `(−40, −100)`: crane, conveyor and a stamping crusher, with a squatter who loves the show.
- **Life:** scrap mice, oil jellies, 4 denizens (the Row's ledger-keeper, the "roof's a car door" resident, and others).
- **Quests:** Rusty at `(−13, 0, 6)` (q1a, q1b); Mama Gasket (q1c, q1d).
- **Memos:** `(13, 1.2, 2)` garage, `(−17, 1.2, −14)` bowl, `(14, 6.2, −46)` car tower, `(−3, 11.2, −84)` hull, `(0, 5.2, −126)` exit yard.

### 2.2 Remake overview
**Fantasy:** home, sweet foreclosed home. A sunset junkyard where everyone OmniScrap repossessed ended up. **Signature traversal:** conveyor belts and magnet cranes, plus mallet-throw switches. **Structure:** the Junction (hub) → Rusty's Row (east), the Billing Mast (west), the Conveyor Works and the Hull (north) → the Compaction Lot (boss) → the Teleporter Yard (exit).

**Why the player goes everywhere.** OmniScrap clamped Bolt's ship with a repo boot ("SECTION 12-B"), so the way off-world is the dead freight teleporter beyond the Compaction Lot (`l1_mid`: "That teleporter can get us off-world. I just need to 'borrow' a few parts first."). The teleporter needs:
- **POWER**: the wreck's power cell, inside the Buried Hull (north spoke).
- **UPLINK**: the Billing Mast's dish re-aimed at the teleporter (west spoke).

Two lamps on the Compaction Lot gate show POWER and UPLINK; both are visible from the hull-top vista. Rusty's Row (east spoke) is optional but is where the planet's heart, both quest givers and the Loop Riot tease live. When REPO-TRON falls, its PAST DUE stamp is the boot's authority, so the boot drops off the ship ("FORECLOSURE REVERSED"); the teleporter becomes the Return Relay.

### 2.3 Map
```
                         NORTH (the Slag Flats: Loop Riot's horizon)
x:  -90        -60        -36        -10    0    10        40       60
    ~~~~~~~~~~~~~~~~~~~~~~ SLAG FLATS (kill plane, y -8) ~~~~~~~~~~~~~~~~~~~~~
-148                             +-------------+
                                 |TELEPORTER   |  R (Return Relay)
                                 |YARD         |
-140                       +-----+-------------+-----+
                           | ##> COMPACTION LOT <## |  car-cube walls slide in
                           |      X REPO-TRON       |  Impound Cage (NE)
-120                       +------[POWER][UPLINK]---+  r  !l1_repo
     [THE BONEYARD]  <-wall-kick shaft     ||
-104  A Crusher Pit  <=====gate=====.      ||  golden rail descent
      S vault U  (Z) junk processor  .     ||
 -90                                [HULL-TOP VISTA] *4 M05 !l1_vista
                (T) blimp *5  ...   [BURIED STARSHIP HULL] power cell
 -72 [BILLING MAST]========cable==========+  !l1_mid (blast door)  [RIDGE
      M01 !l1_mast                         |                        LOOKOUT]
      (B)x3 dish bearings     [CONVEYOR WORKS] >>>>> <<<<< (G) M04   S (L)
 -55  spiral steps            car-cube tower  magnet crane *3       mailbox
                              r                                    (Z) shack
 -40 [BURIED VAULT] S                 .                         [RUSTY'S ROW]
      slide lip            *2 wreck   .                          41 shacks
 -25                       [THE JUNCTION: DUNE BOWL] M03          Q Gasket
                             !l1_glitch    turret pile           water tower
 -10                                   .                         !l1_row r
   0          Q Rusty     slide pipe   .                [GARAGE LOT]
   8                       [P] ship (booted) kiosk beacon  M02 *1 (B)
  20  ##### PROPERTY LINE fence: "OMNISCRAP — ALL SIDES" ##########
```
Scale: about 1 character = 2.5 m east–west; rows are labelled with their z.

### 2.4 Zones

| Zone | Centre (x, z) · size · floor | What OmniScrap built it for | Who got screwed | Combat / platforming read |
|---|---|---|---|---|
| **The Junction (hub)**: landing yard + Dune Bowl | Yard (−2, 8) 30 × 20 at y 0; bowl (0, −27) 40 × 30 at y −0.5 | A repossession staging yard: OmniScrap drops seized goods here before compaction | Everyone in town: the bowl is ringed with repossessed fridges, cars and a child's bike with a tag | Bowl: six scrap mounds (r 3.5–7, 1.5–3 m tall) for cover; a junk-pile ridge on the east rim (2.5 m) gives height; open flanks east and west. Breadcrumb bolt trails lead to all three spokes. |
| **Garage Lot** (prologue) | (13, 2) 14 × 12 at y 0 | — | Bolt | See §1. |
| **Rusty's Row** (east spoke) | (42, −15) 36 × 28; three terraces at y 0, 2.6 and 5.2 | Nothing. It grew out of OmniScrap's "displaced occupant" policy | Every family whose house was repossessed. It "was three shacks" when Bolt was a kid; now **41 shacks** (`l1_row`) | A village, not a fight: shacks stack in three terraces against the east dune, roofs are walkable (the source's 2.6 m shack with a 0.3 m roof slab), and car-door ramps link terraces. The square holds the fire barrel and the "FUSES · PARTS · SOUP" stall. Water tower at the top terrace (catwalk 7.4 m). Only vultures (circling the tower at dusk) and one Lien Crawler (tagging doors with liens) threaten it. |
| **Ridge Lookout** (end of the east spoke) | (40, −70) perch at +7.4 m | An OmniScrap survey post | — | The source's dash-and-hover chain of three slabs. |
| **Billing Mast** (west spoke) | (−36, −72) 7 × 7 base, crow's nest y 16, dish y 19.4 | OmniScrap's billing antenna: it beamed invoices to every home in the junkyard | Everyone who received a bill for "ambient scrap" | Spiral of six scrap steps (2.8 m slabs, 2.3 m rise each, the source layout). Two scrap mutts at the base, a vulture at mid-height. Re-aiming: three yellow-black **bearing clamps** `(B)` on the dish yoke are hit with mallet throws: one from the crow's nest, two from steps 3 and 5 (each within the 13.2 m reach). When all three are free, the dish swings north-east toward the teleporter and its beacon turns cyan: UPLINK. |
| **Buried Vault** (on the west path) | (−46, −40) 8 × 8 | A sealed scrap cache for "assets pending valuation" | — | Slide under a 1.1 m lip. Nanocrate and ammo. |
| **Conveyor Works** (north spoke) | (0, −50) 40 × 22; belts at y 5 | The junkyard's sorting line: it carries scrap to the crusher | The Row: the belts carry their repossessed things past their windows | Car-cube stair tower up to the belts (five 0.9 m steps). The **west belt** (3.2 m/s) and **return belt** (2.6 m/s) run side by side; a yellow **belt-reverser lever** `(B)` at each end flips a belt's direction for 8 s (mallet throw), which is how you ride to the far landing against the flow. Two tinker turrets hide in junk piles beside the belts; a vulture patrols overhead; one Lien Crawler rides the return belt. **Magnet crane:** a 3.4 m magnet platform patrols from the west landing (y 6) to the hull ledge (y 9.6) at speed 0.55. Bailing off mid-ride reaches gold 3. Overhead rusted pipes `(G)` lead to a hidden pipe-top cache (memo 04). |
| **Buried Starship Hull** | (0, −83) 9 × 22 interior at y 9.5 | "The wreck that started it": the first ship that crashed here, and the reason the junkyard exists | The crew, who were billed for the crash | Interior walkway with two tinker turrets at the far ends, light shafts as visual rhythm, crates as cover. The heavy blast door at the south end plays `l1_mid`. The **power cell** sits in the engine room at the north end; pulling it lights POWER on the gate and opens the rear hatch to the roof. |
| **Hull-top Vista** | (0, −86) 7 × 10 at y 15 | — | — | The view over the whole junkyard at sunset (`l1_vista`). Three steps up the hull crown. The golden antenna cable from the Mast arrives here, and the golden descent rail leaves for the Compaction Lot. |
| **Compaction Lot** (boss) | (0, −131) 36 × 24 at y 2 | REPO-TRON's yard, where repossessed property is crushed into cubes | The neighbours: `l1_repo` ("It took the neighbour's house. And the neighbour.") | See §2.10. |
| **Teleporter Yard** (exit) | (0, −146) 14 × 8 at y 2.5 | OmniScrap's freight teleporter, for shipping crushed cubes off-world | — | Return Relay. |
| **The Boneyard** (annex wing, optional) | From (−24, −104) running west to (−92, −104) | "Every ship that ever missed a payment" | Ship owners | The v13 annex grammar kept: gate relay → three staggered slabs and a lift → **wall-kick shaft** (two 9.5 m walls 5 m apart) → grind back down → **THE CRUSHER PIT** plaza (22 × 22) → updraft vault (nanotech +20 HP). Roster: 2 scrap mutts, a tinker turret, a vulture. The **junk processor** set piece sits at its gate. |

### 2.5 Signature traversal: tuning
- **Conveyors:** 3.2 m/s and 2.6 m/s (source). Belt-reverser levers flip a belt for 8 s with a 1 s warning (belt chevrons flash).
- **Magnet crane:** platform 3.4 × 3.4 m, patrol speed 0.55 (source), 3.6 m rise over 6 m of travel.
- **Mallet-throw switches:** the boomerang rules in §0.5. Every switch on this planet is reachable from a standing position within 13.2 m, because this is where the throw is taught.
- **Golden rails:** the source's three rails are kept: the antenna cable (Mast ↔ hull top, now running both ways), the hull-top descent, and the Boneyard grind.

### 2.6 Enemies by zone
| Zone | Enemies |
|---|---|
| Junction / Dune Bowl | 3 Scrap Mutts (pack), 1 Tinker Turret (east junk pile), 1 Vulture Drone |
| Rusty's Row | 2 Vulture Drones (circle the water tower), 1 Lien Crawler (outskirts) |
| Billing Mast | 2 Scrap Mutts (base), 1 Vulture Drone (mid-height) |
| Buried Vault approach | 1 Lien Crawler |
| Conveyor Works | 1 Scrap Mutt (tower top), 2 Tinker Turrets (junk piles), 1 Vulture Drone, 1 Lien Crawler (return belt) |
| Buried Hull | 2 Tinker Turrets |
| Compaction Lot (pre-fight) | 1 Vulture Drone, 1 Tinker Turret (west car stack) |
| The Boneyard | 2 Scrap Mutts, 1 Tinker Turret, 1 Vulture Drone, 1 Lien Crawler |

### 2.7 Collectibles
**Gold bolts (5)**
| # | Where | How |
|---|---|---|
| 1 | Garage Lot inspection pit | Mallet throw at the pit-lid latch `(B)` (prologue) |
| 2 | Pocket behind the west-rim wreck in the Dune Bowl `(−19, −32)` | Source #1; walk behind the wreck screen |
| 3 | Slab off the magnet-crane path `(−17, 9.3, −60)` | Source #2; jump off the crane mid-ride |
| 4 | Hull-top side slab `(6.5, 16.6, −82)` | Source #3 |
| 5 | Gondola of the AIR PREMIUM™ ad blimp, moored over the bowl's west rim at y 20 | **Tether-Hook** (Rustvane): swing from the Mast's step 6 to the blimp's mooring ring |

The Buried Vault keeps its nanocrate; its gold is moved to the crane slab only (fixes the duplicate index).

**Memos (5)**
| Memo | Where | Why there |
|---|---|---|
| 01 RE: RE: RE: The Moon | Billing Mast crow's nest | The best view of the cracked, "branded" moon |
| 02 Garage Repossession FAQ | The empty Garage Lot slab (appears after `intro`) | "Fixtures convey. Sandwiches convey." |
| 03 Scrap Mutt Feeding Policy | Dune Bowl, by an overturned feeding trough on the west mound | Where the mutts gather |
| 04 Conveyor Safety Update | Pipe-top cache above the Conveyor Works | **Grind Soles** (Glacius): grind the `(G)` pipe from the car-tower top to the cache |
| 05 Sunset Monetization Pilot | Hull-top Vista | The sunset OmniScrap wants to watermark |

**Secrets**
| ID | Secret | Gate | Reward |
|---|---|---|---|
| S1 | Buried Vault | Slide (start) | Nanocrate, ammo, bolts |
| S2 | AIR PREMIUM™ blimp | Tether-Hook | Gold 5 |
| S3 | Pipe-top cache | Grind Soles | Memo 04, 60 bolts |
| S4 | Mama Gasket's mailbox ("the one with teeth marks", a denizen joke) on a scrap spire 24 m east of Ridge Lookout | **Glide** from the Lookout perch (7.4 m drop) | 100 bolts; Mama Gasket's denizen bark changes |
| S5 | Junk processor crusher bay | **Thunder throw** `(Z)` on its control box stops the stamp for 10 s | Nanocrate |
| S6 | Boneyard updraft vault | Annex route (start) | Nanotech +20 HP |
| S7 | The Row's back shed, behind a tarp curtain on the top terrace | **Magma throw** `(F)` burns the tarp | The Row ledger-keeper's spare bolt jar (80 bolts) |

### 2.8 Quests
| Quest | Giver | Placement | Hint bark points at |
|---|---|---|---|
| q1a Mutt Census (4 scrap mutts) | Rusty, at the hub beside the pad (−13, 6) | Mutts in the Dune Bowl, Mast base and Works | Distant barking |
| q1b Sandwich Recovery (3 sandwiches) | Rusty | Dune Bowl east mound `(16, −30)`; Conveyor Works west landing `(−8, 5.6, −54)`; inside the Hull `(3, 10.6, −76)` (source spots) | The smell of mustard |
| q1c Lights On (3 fuses) | Mama Gasket, Rusty's Row square (37.5, −11.5) | Car-cube tower top `(9.5, 5.8, −50.5)`; crane ledge `(−5, 10.5, −66)`; hull top `(−2.5, 16.3, −88)` (source spots) | A fuse humming |
| q1d Dusk Appraisal (3 vultures) | Mama Gasket | The water-tower pair and the Works patroller | Wing-flaps overhead |

### 2.9 Story beats
| Beat | Where |
|---|---|
| `intro` | End of the prologue, at the garage gate |
| `l1_glitch` | Entering the Dune Bowl (`(0, −22)`, as in source) |
| `l1_row` | Rusty's Row gate (with the banner "Population: everyone OmniScrap repossessed") |
| `l1_mast` | Crow's nest of the Billing Mast (the Loop Riot broadcast tease) |
| `l1_mid` | The Hull's blast door |
| `l1_vista` | Hull-top Vista |
| `l1_repo` | Compaction Lot gate, once POWER and UPLINK are both lit |
| `flyover0` → `arrive0` | Back-to-back on the first return by ship (fixes the web build's order bug) |

### 2.10 Boss arena: the Compaction Lot (REPO-TRON)
```
            Teleporter Yard (locked fence until the kill)
   +-------------------------------------------------+
   |##|  Impound Cage (NE corner, 3x3)          |##|  <- car-cube walls on
   |##|                                         |##|     rails (E and W)
   |##|   [cube]          crane gantry rail     |##|
   |##|        ===========================      |##|
   |##|               REPO-TRON start           |##|
   |##|   [cube]                      [cube]    |##|
   |##|                                         |##|
   |##|  [container stack 3 m]  [cube]          |##|
   +--------------gate (r arena checkpoint)----------+
```
- **Space:** 36 × 24 m at y 2, fenced by stacked crushed cars (the source's car walls).
- **Cover:** four 2.5 m crushed-car cubes and one 3 m two-container stack on the south side (the only high ground).
- **Phase geometry:**
  - **Phase 1:** full width. A crane gantry rail crosses the lot at 9 m; REPO-TRON's magnet arm rides it. When the magnet steals a weapon, it drops it in the **Impound Cage** in the north-east corner. Smashing the magnet hook (the boss doc's weak point) opens the cage.
  - **Phase 2 ("REPOSSESSION MODE"):** the east and west car walls slide inward on rails, 4 m each, to a 28 m width. Two cubes are pushed with them, so the cover changes.
  - **Phase 3:** the walls step in to 22 m. The container stack is crushed flat, removing the high ground; a clear 1.5 m gap opens behind each wall's rail track as a dodge lane.
- **Exit:** the north fence drops after the kill and the Teleporter Yard's relay lights.

### 2.11 Arena challenge: "Compactor Countdown" (THE CRUSHER PIT)
In the Boneyard plaza (22 × 22). Four waves of the Scrapheap roster with Lien Crawlers. Every 15 s the pit's walls step in 1 m (minimum 14 m). Reward 180 bolts.

### 2.12 Out of bounds
| Edge | What the player sees | Quip pool |
|---|---|---|
| South and side edges | Scrap cliffs topped by OmniScrap's fence: "PROPERTY LINE — ALL SIDES" | "The map ends. Like my patience." |
| North beyond the Teleporter Yard | The glowing Slag Flats (kill plane) | "Rust warranty voided. Again." |
| Oil-jelly ponds in the dunes (water-type) | Black, shimmering oil | "I rated that dive 2 stars. The splash lacked commitment." |

---

## 3. Rustvane Canyon (Planet 2, `LEVELS[1]`)

### 3.1 Original (`buildLevel2` L9744, `expandRustvane` L9477)
- **Terrain** `TERRAIN_SPECS.p2`: 190 × 220 m centred on z −45 (z +65 to −155), banded red strata walls, sandy floor, a river carved at x ≈ −10.5. Boundary caps at z +58 and z −148. Twin suns (one is an ad), fog 55–210 m, theme `canyon`. Kill plane y −8.
- **Landing:** spawn `(0, 1.2, 30)`, pad `(−3, 0, 30)`, kiosk `(7, 0, 32)`. Hint: "Two ways up: hop the RIVER STONES west, or climb the CLIFF LEDGES east!"
- **River route (west):** five stepping stones (z +16 to −8, alternating x −12/−9), a waterfall at `(−21.4, −8)` with **gold #1** behind it, an umbrella bounce pad `(−18, −16)` with power 19, an ambassadog.
- **Cliff route (east):** five switchback ledges (x 12–16, z +12 to −12, rising to y 5.9), a selfie sentry, the resort's service gate (a door at `(10, 6.5, −18.6)`), and a secret cave in the east wall with **gold #2** `(20.5, 6.4, −6)`.
- **Resort decks** on stilts at y 6–7: deck A `(0, −26)` 20 × 14 with an infinity pool (water, foam edge, a glowing spill), two cabanas, 2 ambassadogs and a lifeguard; deck B `(13, −41)` with 2 ambassadogs, a selfie and a crate; deck C `(−10, −44)` with a lifeguard and a nanocrate. A pool set piece: floaties and an eternally hesitating diver.
- **Billboard ascent:** a bounce pad on deck B to an upper walk at y 12; four floating billboard platforms (sine bob 0.9, speed 0.8) climbing to y 19.5; a selfie; the top billboard deck `(0, 21.6, −78)` with `l2_mid`, `firmwareScene` and the banner "Twin suns, zero refunds"; **gold #3** on a stray side board `(−9, 21.5, −74)`.
- **Zip rail** from the top deck down to the main pool deck `(0, 21.4, −80) → (0, 9.8, −108)`.
- **Boss deck** `(0, 7.9, −116)` 32 × 24: a show pool, cabanas, parasols; the turret-tank `miniboss` (boss bar "THE CONTENT CREATOR") at `(0, 8.4, −122)`; `ccIntro` at z −106; `l2_glambot` on its death; goal `(−13, 8.4, −125)`.
- **THE STRIP MINE** annex through the east wall from `(22, −58)`: "Where the resort gets its 'authentic canyon' gravel", plaza **THE QUARRY FLOOR**.
- **Back of House** (under the decks, around z −58 to −92): the sign "EMPLOYEES MUST SMILE (SMILES ARE BILLABLE)", stacked bunk containers, a break area with a vending machine "that charges for eye contact", a time clock, laundry lines, a dumpster, a nanocrate on the top bunk, a lifeguard and an ambassadog; `l2_staff`; Bellhop-9 at `(−3.5, 0.1, −72)`; three staff denizens.
- **Old Co-op Camp** `(18, 31)` beside the landing: two tents, ore-cart rails, a cart of glowing ore, the sign "RUSTVANE MINING CO-OP — WORKER-OWNED SINCE BEFORE THE RESORT", a lantern; `l2_camp`.
- **Pocket A, Collapsed Mine** `(0, 40)` south of the pad; **Pocket B, Cliff Roost** `(22, −30)`. Rescue umbrellas under the high route at `(10, −46)` and `(0, −100)`.
- **Quests:** Concierge-Tron `(5, 0, 24)` (q2a, q2b); Bellhop-9 (q2c, q2d).
- **Memos:** `(−18, 1.2, 24)`, `(16, 3.4, 6)`, `(−14, 8.9, −47)`, `(5, 18.7, −67)`, `(13, 9.6, −112)`.

### 3.2 Remake overview
**Fantasy:** OmniScrap™'s two-star influencer resort, built on top of a worker-owned mine. Twin suns, one of which is an ad. **Signature traversal:** cliff zip lines and canyon wind updrafts; the **Tether-Hook** is earned here. **Structure:** the Resort Strip (hub) → the Old Co-op Camp (south-east); the Resort Decks, Infinity Pool and Back of House (centre); the Strip Mine and Cliff Zip Lines (east) → the Sunset Stage (boss).

**Critical path.** The Sunset Stage sits at the canyon's north end behind a **"VIP WRISTBAND REQUIRED"** gate. Guests reach it by the scenic cliff zip lines, which have gaps only a Tether-Hook can cross. Staff reach the cliffs by the service lift in Back of House. The design uses both:
1. **Old Co-op Camp:** Sprocket rigs the Co-op's old ore-cable winch into the **Tether-Hook**. The Co-op hauled ore up these cliffs on cables; `l2_camp` explains whose canyon this was.
2. **Back of House:** punching the staff time clock prints a staff badge, which runs the **service lift** 18 m up the canyon wall to the Strip Mine rim.
3. **Strip Mine and Cliff Zip Lines:** zip and hook across the canyon to the billboard ascent and the Top Billboard Deck, then ride the long zip line down to the Sunset Stage.

The Co-op and Back of House can be done in either order. The Strip Mine needs both.

### 3.3 Map
```
                          NORTH (canyon end: lava falls)
x:   -40       -20        0        20        40        60
     ######  ~~~~~ lava falls (kill plane) ~~~~~  ######
-125 ##  +------------------------------------+  ##
     ##  |   THE SUNSET STAGE  X              |  ##   CC hover-stage over
-110 ##  |   pool deck: Sentinel act          |  ##   the infinity edge
     ##  +---------VIP gate---r---------------+  ##
 -95 ##              ^ long zip line ===       ##
     ##              |                 [TOP BILLBOARD DECK] y 21.6
 -78 ##              |                  !l2_mid !firmwareScene M06 *3
     ##     floating billboards ^^^^             ##  (L) projector rig S7
 -60 ## [BACK OF HOUSE]          [STRIP MINE / QUARRY FLOOR] A   ##
     ##  under the decks          ore-cart line (G) *4           ##
     ##  Q Bellhop-9 !l2_staff    (T)(T) cliff zip lines ===     ##
     ##  service lift ->--------> mine rim  U updrafts           ##
 -45 ## [DECK C] kennel M08   [DECK B]                [CLIFF ROOST] S4 (T)
     ##   (Z) vending S6      umbrellas              ##
 -26 ##   [DECK A + INFINITY POOL] M07 !l2_holo1     ##
     ##       service gate                            ##
  -8 ## waterfall *1 S1  river   [CLIFF LEDGES] M09  cave *2 S2
     ##  stepping stones ~~~|~~~                      ##
  10 ##   river boardwalk   ~      [RESORT STRIP: HUB]  ##
     ##                     ~   valet loop  Q Concierge-Tron
  30 ##                     ~  [P] ship kiosk beacon   [OLD CO-OP CAMP]
     ##                     ~                           winch (T) !l2_camp
  40 ##   [COLLAPSED MINE] S3 (F) timbers
     ###################### canyon mouth ###############
```

### 3.4 Zones

| Zone | Centre (x, z) · size · floor | What OmniScrap built it for | Who got screwed | Combat / platforming read |
|---|---|---|---|---|
| **Resort Strip (hub)** | (0, 20) 50 × 30 at y 0 | The arrivals experience: valet loop, gift shop, river boardwalk, a two-star rating sign | The Co-op miners, now "Guest Experience Staff" | Pad and kiosk at the south end, Concierge-Tron's desk by the valet loop. The stilt decks loom north, the cliff ledges rise east, the river boardwalk runs west. Light combat: 2 Ambassadogs "greeting" guests. |
| **Old Co-op Camp** (south-east spoke) | (22, 32) 24 × 18 at y 0.5 | Nothing: it predates the resort | The Rustvane Mining Co-op, worker-owned for sixty years until OmniScrap "bought the river" | Tents, ore-cart rails into the cliff, the cart of glowing ore, the Co-op sign. **The winch** (a big cable drum with an anchor ring 12 m up the cliff) is where Sprocket builds the Tether-Hook. Three practice rings lead up the cliff and back: a first swing, a first pull point, a two-ring chain. The first Review Bomber appears over the camp once the hook is earned. |
| **Collapsed Mine** (secret off the camp) | (0, 40) 12 × 8 | The Co-op's old working | The Co-op | Dark tunnel with a nanocrate (source pocket A). Its back passage is boarded with timbers: Magma throw `(F)`. |
| **Cliff Ledges** (east side of the hub) | (14, 0), switchbacks to y 5.9 | The resort's "nature trail" | — | The source's five ledges, the secret cave (gold 2) and a Selfie Sentry charging dock (memo 09). Leads up to the service gate onto deck A. |
| **River route** (west side of the hub) | (−12, 4), stones from z +16 to −8 | The "authentic river experience" | The Co-op: OmniScrap bought the river, then billed the miners for "ambient moisture" (`l2_camp`) | Stepping stones over the river (water-type liquid), the waterfall grotto (gold 1), an umbrella bounce pad (power 19) up to deck C. |
| **Resort Decks A, B, C + the Infinity Pool** (centre spoke) | A (0, −26) 20 × 14 at y 6.1; B (13, −41) 12 × 12 at y 7.3; C (−10, −44) 12 × 10 at y 7.3 | The resort itself: cabanas, deck chairs, the "finite-adjacent" infinity pool | Guests, who rate it two stars; staff, who live underneath | The main combat space. Deck A: cabanas and deck-chair rows as low cover, the pool as a no-go centre (scalding, water-type), flanks along both rails. Decks B and C are higher side platforms linked by umbrella bounce pads (power 16–19) and step bridges, so fights use height. Rescue umbrellas below catch falls (source). Grindstone's hologram (`l2_holo1`) projects over the pool. A security kennel on deck C (memo 08). |
| **Back of House** (under the decks) | (0, −74) 30 × 30 at the canyon floor | Staff housing, under the pool | The staff: bunk containers stacked like luggage, a time clock, laundry lines, a vending machine that charges for eye contact, the pool dripping "complimentary rain" | Cramped, low-ceiling combat with stacked bunk containers (2.6 m) as cover and climbable height. The time clock prints a staff badge; the **service lift** (a freight cage on the canyon wall) rises 18 m to the Strip Mine rim. A Lifeguard Bot and an Ambassadog patrol (source). |
| **Strip Mine / the Quarry Floor** (east spoke) | Annex from (22, −58) east to (90, −58) | "Where the resort gets its 'authentic canyon' gravel" | The Co-op's mine, gutted for decorative gravel | The annex grammar (climb, wall-kick shaft, grind, plaza fight, updraft vault). New: **canyon updrafts** (warm air rising off the pit) carry Bolt up to the zip-line towers. The abandoned **ore-cart line** `(G)` leads into the cliff (gold 4). The plaza hosts the arena challenge. |
| **Cliff Zip Lines** | Three towers across the canyon at y 14–18, between x +20 and −5, z −55 to −70 | The resort's "scenic transfer" for VIP guests | — | Golden zip lines between towers, with two gaps where the line was never finished; each gap has a Tether-Hook ring at its midpoint. Review Bombers drop star-pattern bombs on the towers. |
| **Billboard ascent and Top Billboard Deck** | Platforms from (6, −57) to (−3, −72) at y 13.5→19.5; deck (0, −78) 9 × 7 at y 21.6 | Ad space | Everyone who looks up | The source's four bobbing billboard platforms. The top deck has the giant ad board and the console Sprocket plugs into (`firmwareScene`). The long zip line leaves from here for the Sunset Stage. A rig on the north-east rim projects the second sun (secret S7). |
| **The Sunset Stage** (boss) | (0, −116) 32 × 24 at y 7.9, plus the hover-stage | The resort's livestream stage | The audience | See §3.10. |

### 3.5 Signature traversal: tuning
- **Zip lines:** golden ride-rails (13.5 m/s, 17 m/s with sprint).
- **Tether-Hook:** §0.5. The zip-line gaps are 9–12 m wide with the ring at the midpoint, 3 m above the line, so one swing crosses a gap.
- **Canyon updrafts:** radius 2.4 m, height 12 m, force 30 (the source's annex updraft). They pulse 3 s on and 1.5 s off, shown by dust plumes, so the timing reads clearly.
- **Bounce umbrellas:** power 16–20 (source).
- **Floating billboards:** sine bob amplitude 0.9 m, speed 0.8 (source).

### 3.6 Enemies by zone
| Zone | Enemies |
|---|---|
| Resort Strip | 2 Ambassadogs |
| River route | 1 Ambassadog (source) |
| Cliff Ledges | 1 Selfie Sentry |
| Old Co-op Camp | 1 Review Bomber (after the hook is earned) |
| Deck A | 2 Ambassadogs, 1 Lifeguard Bot |
| Deck B | 2 Ambassadogs, 1 Selfie Sentry |
| Deck C | 1 Lifeguard Bot |
| Back of House | 1 Lifeguard Bot, 1 Ambassadog |
| Strip Mine | 2 Ambassadogs, 1 Lifeguard Bot, 1 Selfie Sentry (annex roster) |
| Cliff Zip Lines | 2 Review Bombers |
| Billboard ascent | 1 Selfie Sentry, 1 Review Bomber |

### 3.7 Collectibles
**Gold bolts (4)**
| # | Where | How |
|---|---|---|
| 1 | Behind the waterfall `(−20.5, 1.8, −8)` | Source #1 |
| 2 | Secret cave in the east cliff `(20.5, 6.4, −6)` | Source #2 |
| 3 | Stray side billboard `(−9, 21.5, −74)` | Source #3 |
| 4 | End of the abandoned ore-cart line, deep in the Strip Mine's cliff | **Grind Soles** (Glacius) |

**Memos (5)**
| Memo | Where | Why there |
|---|---|---|
| 06 Twin Suns: One Is An Ad | Top Billboard Deck, facing the ad sun | The best view of both suns |
| 07 Infinity Pool Incident | The infinity edge of deck A | "Finite-adjacent" |
| 08 Ambassadog Vests | Security kennel on deck C, by a rack of XS-Corporate vests | |
| 09 Selfie Sentry Firmware 9.1 | Sentry charging dock on the Cliff Ledges (the source spot `(16, 3.4, 6)`) | |
| 10 RE: The Lava Pool | Back of House laundry, under the pool's drip | "Towels are now legally personnel — do NOT lay on the staff" |

**Secrets**
| ID | Secret | Gate | Reward |
|---|---|---|---|
| S1 | Waterfall grotto | Start | Gold 1 |
| S2 | East-cliff cave | Start | Gold 2 |
| S3 | Collapsed Mine back passage | **Magma throw** `(F)` on the timbers | A Co-op time capsule (100 bolts) and a nanocrate |
| S4 | Cliff Roost `(22, −30)` | Tether-Hook ring on the east wall | Ammo cache, 60 bolts |
| S5 | Ore-cart line | **Grind Soles** | Gold 4 |
| S6 | Back of House vending machine | **Thunder throw** `(Z)` shorts it | It coughs up 120 bolts of "eye-contact fees" |
| S7 | The second-sun projector rig on the north-east rim | **Glide** from the Top Billboard Deck (14 m drop, 38 m out) | Switching it off darkens the ad sun for the rest of the visit; 150 bolts |
| S8 | Strip Mine updraft vault | Annex route | Nanotech +20 HP |

### 3.8 Quests
| Quest | Giver | Placement | Hint bark points at |
|---|---|---|---|
| q2a Delete My Reviews (3 Selfie Sentries) | Concierge-Tron, hub valet desk (5, 24) | Cliff Ledges, deck B, billboard ascent | A camera shutter sound |
| q2b Towel Service (3 towels) | Concierge-Tron | A river stone `(−10.5, 1, 4)`; deck B `(13, 8.7, −44)`; Top Billboard Deck `(0, 22.6, −78)` (source spots) | A towel flapping in the wind |
| q2c Tip Jar Liberation (3 tip jars) | Bellhop-9, Back of House (−3.5, −72) | Deck A `(−3, 7.3, −22)`; deck B `(13, 8.5, −44.5)`; the Sunset Stage's east wing `(10, 9.2, −121)` (source spots; the third is collected during or after the boss) | Coins rattling |
| q2d Break Enforcement (2 Lifeguard Bots) | Bellhop-9 | Deck C and Back of House | A whistle |

### 3.9 Story beats
| Beat | Where |
|---|---|
| `flyover1` → `arrive1` | First landing, back-to-back |
| `l2_camp` | Old Co-op Camp, at the sign (as in source) |
| `l2_holo1` | Deck A: Grindstone's hologram over the pool |
| `l2_staff` | Entering Back of House |
| `l2_mid` | Arriving on the Top Billboard Deck |
| `firmwareScene` | Interacting with the ad console on the Top Billboard Deck (10 m from the `l2_mid` trigger, so the two never fire together). Unlocks the Sprocket voice-filter cosmetic. |
| `ccIntro` | At the VIP gate of the Sunset Stage |
| `l2_glambot` | After the Content Creator is beaten (see §3.10) |
| `shieldReveal` | Leaving Rustvane for the first time (as in source) |

### 3.10 Boss arena: the Sunset Stage (Rustvane Sentinel, then The Content Creator)
```
       ~~~~~~~~~~~~ lava falls (the infinity edge spills here) ~~~~~~~~~~~~
       (T)mast       [CC HOVER-STAGE, 4-8 m up, over the edge]     (T)mast
   +----------------------------------------------------------------+
   | west wing (cabana roof 2.5 m)                east wing (2.5 m)  |
   |   cabana            +----------------+           cabana         |
   |   parasol           |  SHOW POOL     |           parasol        |
   |                     |  (scalding)    |           tip jar (q2c)  |
   |   deck chairs       +----------------+           deck chairs    |
   |                     SENTINEL start                               |
   | (T)mast                                                 (T)mast  |
   +-------------------------- VIP gate (r) --------------------------+
```
- **Space:** the source's 32 × 24 pool deck at y 7.9, plus the Content Creator's hover-stage above the north infinity edge.
- **Cover and height:** two destructible cabanas, parasols (bounce pads, power 16), deck-chair rows (low cover), and raised wings on the east and west (cabana roofs at 2.5 m). The show pool in the centre is scalding (water-type).
- **Camera masts:** four, at the deck corners, 12 m tall, each with a Tether-Hook ring at 8 m. The Content Creator's camera drones dock on them, so swinging from a mast is how Bolt reaches a drone.
- **Act 1, the Rustvane Sentinel** fights on the deck. Its charge beam (source: a 30 m line, 0.45 m radius, with a guide line during the 1.25 s telegraph) runs along the deck's long axis, so the cabana wings and the pool rim are the dodge lanes. When its armour blows ("DEMONETIZED!"), a twin beam fans 35° off the first, so strafing one way is the wrong answer (source behaviour).
- **Act 2, The Content Creator** fights from the hover-stage. Phase geometry:
  - "Unboxing": the stage hangs low (4 m) over the north edge.
  - "Collab": the stage drifts along the north edge while camera drones fly between the masts.
  - "Going live": the stage rises to 8 m and its ring light sweeps the deck; the cabana roofs are the only shade.
- **Story timing:** `ccIntro` plays at the gate, where the Content Creator introduces its "collab" partner (the Sentinel, with "this industrial charge beam"). `l2_glambot` plays when the Content Creator is beaten. The Creator is demonetized, not destroyed: "CUT! ... you just DELETED my co-host!" refers to the Sentinel minutes earlier, and "I love you. I'm keeping you." needs the Creator alive. GLAMBOT then defects.
- **Out of bounds:** falling off the infinity edge is a lava kill plane.

### 3.11 Arena challenge: "Poolside Pile-Up" (THE QUARRY FLOOR)
In the Strip Mine plaza, dressed with poolside furniture that GLAMBOT had trucked in. Five waves of resort enemies plus Review Bombers. Updraft pulses lift Bolt between two quarry terraces. A 25% bolt bonus if Bolt never touches the plunge pool in the centre. Reward 200 bolts.

### 3.12 Out of bounds
| Edge | What the player sees | Quip pool |
|---|---|---|
| Canyon walls | Banded cliffs with "RESORT PROPERTY — TRESPASSERS WILL BE REVIEWED" signs | "The map ends. Like my patience." |
| River (water-type) | Bright turquoise river | "You're a ROBOT-ADJACENT lifeform. Water is a lawsuit." |
| Infinity Pool and show pool (water-type, scalding) | Steaming pool | "The pool is for GUESTS, Bolt. We are trespassers." |
| Lava falls and the mine pit floor (kill plane) | Molten runoff | "I rated that dive 2 stars. The splash lacked commitment." |

---

## The three core planets: what the web build shared
Nova Plaza, Glacius Vault and Verdant Sink were built by one skeleton, `buildNewPlanet(cfg)` (L10345), dressed per planet by `novaDress` / `glaciusDress` / `verdantDress` and configured by `NOVA_CFG` / `GLACIUS_CFG` / `VERDANT_CFG` (L10518–10529). The shared layout was:
- **Terrain** 240 × 200 m centred on z −50 (z +50 to −150), from `TERRAIN_SPECS_V9`. Walls at z +42 and z −122. Kill plane y −10.
- **Landing** spawn `(0, 1.4, 22)`, pad `(−6, 0, 26)`, kiosk `(6, 0, 28)`, exit pad `(6, 0, 30)` (opens once the core is taken).
- **Region 1, arrival** around `(0, 8)`: three crates, two roster-0 enemies, one roster-2 flyer, a planet hint.
- **Region 2A, left district** `(−30, −60)`: roster-1 turret, roster-0, roster-2, ammo, **gold 0** `(−30, 11, −66)`.
- **Region 2B, right district** `(30, −60)`: roster-1, roster-0, ammo, **gold 1** `(34, 5, −66)`.
- **Connectors:** a grind rail `(−16, 6, −30) → (−30, 10, −58)` to the left district, an updraft at `(30, −30)` to the right.
- **Pocket A** sealed cache `(−38, −40)` (slide under a lip) with a nanocrate and **gold 2**; **Pocket B** high perch `(38, −44)` with a nano pickup.
- **Region 3, core plaza** `(0, −95)`: two roster-1 turrets, the mid-boss at `(0, 9, −102)`, the Keystone Core at `(0, 1.6, −104)` (hidden until the boss falls).
- **Beats:** `introBeat` at `(0, −84)`, `midBeat` at `(0, −42)`, `lateBeat` at `(0, −72)`, `holo` in a district at `(±30, −58)`.
- **v13 wing:** an annex running west from `(−46, −12)`.
- **Memos:** `(±10, 1, 6)`, two in the districts at `(±28–30, …, −56)`, one at a pocket, one at the core plaza `(0, …, −96)`.

The remake replaces this skeleton with three genuinely different planets, keeping each config's roster, mechanic tuning, beats, memo intent and wing.

---

## 4. Nova Plaza (Planet 4, `LEVELS[5]`)

### 4.1 Original (`NOVA_CFG`, `novaDress` L10446, `TERRAIN_SPECS_V9.nova`)
- **Terrain:** terraced smart-city. Arrival plaza flat at `(0, 8)`; a raised mid district (+4.5 m) at `(0, −30)`; a tower district base (+9 m) on the left `(−30, −60)`; a "mall apron" (+3 m) on the right `(30, −60)`; the FineTree plaza (+6 m) at `(0, −95)`. The rim rises 20 m. Night palette (sky `#0a0e24`), neon, theme `nova`.
- **Dressing:** twin gateway skyscrapers (22 m cyan, 26 m pink), a welcome arch with an ad board, an elevated highway at +14 m with eight neon silhouette cars, light shafts. Districts: clusters of lit-window towers (8–18 m) and holo-billboards; the right district has **THE CONSUMPTION ZONE™** mall facade (16 × 10 m, a sign strip and three glowing doors). The core plaza has **the FineTree™**: a seven-tier hologram cone of unpaid fines (to 17.5 m), a gold "star of debt", and five fine-o-meter kiosks in a ring (r 9).
- **Mechanic:** two moving walkways, `(−16, −22)` and `(20, −42)`, each 4 × 16 m, pushing toward −z at force 10.
- **Roster:** metermaid, hoaenforcer, surgedrone. Mid-boss: **the Algorithm** (520 HP).
- **Wing:** **THE UNDERPASS** ("Where the fined went when the fines came due"), plaza **PERMIT PARKING ONLY**.
- **Beats:** `novaIntro` at the core approach, `novaMid` at the mid district, `novaLate` at `(0, −72)`, `novaHolo` in the left district.
- **Life:** pigeon drones, moths, a squatter denizen ("I'm grandfathered in. GRANDFATHERED.").
- **Quests:** The Squatter at `(−6, 0, 12)` (q4a, q4b).

### 4.2 Remake overview
**Fantasy:** a fully automated smart city with zero residents. Every light is on. Nobody is home. The HOA fined everyone into exile and kept charging the empty houses. **Signature traversal:** **moving walkways that reverse on HOA violations**, and smart **lamp posts that are Tether-Hook points**. **Structure:** the Fountain Plaza (hub) → the HOA District (west), the Permit Office (east), the Transit Loop (north) → the FineTree Plaza (boss).

**Critical path.** The FineTree Plaza's gate needs two stamps, in either order:
- an **HOA Variance**, from the HOA Clubhouse in the HOA District (west);
- a **Permit to Approach**, from the Permit Office (east).

With both stamps, the empty **Transit Loop** monorail (north) carries Bolt around the city to the FineTree Plaza's upper platform.

### 4.3 Map
```
                                 NORTH
x:  -110      -84      -50     -30       0       30       50
    ########################## HOA perimeter wall (rim +20 m) #########
 -105                      [FINETREE PLAZA]  X  The Algorithm (north)
                            FineTree hologram  M17 kiosks ring
  -90                       +----r gate [VARIANCE][PERMIT]----+
                    ==== TRANSIT LOOP (elevated ring, y 12) ====
  -72             ||  station M18   !novaLate          (L) dead train *4 S
  -60  [HOA DISTRICT]          ||              [PERMIT OFFICE]
       cul-de-sacs +9 m        ||               Consumption Zone facade
       HOA Clubhouse M16 *1(T) ||               take-a-number hall >>><<<
       Compliance Eyes (B)     ||               M20 cleaning-bot closet
       !novaHolo               ||               (G) tube rails -> S M38
  -40  sealed cache S *3     [CIVIC CENTER +4.5 m]  !novaMid    perch S
       ..                     walkways >>> (reversible)          *2 sign
  -12  [THE UNDERPASS] A <-- gate            ..
       (annex, west)                        ..
    8                      [FOUNTAIN PLAZA: HUB]  M19 central fountain
                            gateway towers, welcome arch, highway +14 m
   26                      [P] ship kiosk beacon   Q The Squatter (bench)
    ########################## HOA perimeter wall #####################
```

### 4.4 Zones

| Zone | Centre (x, z) · size · floor | What OmniScrap built it for | Who got screwed | Combat / platforming read |
|---|---|---|---|---|
| **Fountain Plaza (hub)** | (0, 8) 32 × 24 at y 0 | The city's welcome plaza: fountains, gateway towers, a welcome arch, "WELCOME HOME, RESIDENT" | The residents, fined out of their homes. The fountains still run for nobody (memo 19) | Pad on the south edge; The Squatter on a "grandfathered" bench. The central fountain (water-type) splits the plaza; planters and benches give low cover; the twin gateway towers frame the north exit. The elevated highway at +14 m crosses overhead with silhouette traffic. Light combat: 2 Meter Maids and a Surge Drone (source arrival roster). |
| **Civic Center** (between hub and spokes) | (0, −30) 30 × 26 at y 4.5 | City hall and the "Civic Compliance" hub | — | The source's raised mid district. Two **reversible walkways** climb to it (the source's walkways, now reversing on violations, §4.5). It branches west to the HOA District, east to the Permit Office, and up to the Transit Loop station once both stamps are in. `novaMid` plays here. |
| **HOA District** (west spoke) | (−32, −58) 40 × 34 at y 9 | Gated cul-de-sacs of identical smart homes, all managed by the HOA algorithm | Every resident: each lawn has a FINED placard, each door a "VACANT — BALANCE DUE" notice | Terraced streets climbing in two steps (y 6, y 9). Hedges and parked smart-cars as cover; the cul-de-sac roundabouts are the fight pockets. **Compliance Eyes** (HOA cameras on poles) watch each street; mallet-throw one to blind it for 20 s (`(B)` switch rules). **Smart lamp posts** are Tether-Hook points (spacing 10–12 m) and form the high route over the hedges. The **HOA Clubhouse** at the top holds the HOA Variance stamp: a rules-board puzzle where Bolt has to violate three rules in front of three Eyes to be "found in contravention" and issued a variance. `novaHolo` plays at the clubhouse. |
| **The Underpass** (annex, off the HOA District) | From (−46, −12) west to (−110, −12) | "Where the fined went when the fines came due" | The evicted: cardboard homes under the highway, a soup line with no soup | Annex grammar; the plaza **PERMIT PARKING ONLY** hosts the arena challenge. Roster: Meter Maids, an HOA Enforcer, a Surge Drone. |
| **Permit Office** (east spoke) | (32, −58) 36 × 30 at y 3, inside the old Consumption Zone™ mall | The Department of Permits, in a mall that closed when the shoppers were fined | Anyone who ever needed a permit | Indoor. The **take-a-number hall**: a hall of walkways in a grid, all reversing on violations; the ticket display never moves. The player "takes a number" and has to reach the counter while walkways reverse around them. Upstairs, the long **records hallway** (60 m, columns every 8 m) is the marksman space: HOA Enforcers behind plating at the far end and weak-point targets on the walls. A cleaning-bot closet (memo 20). Outside, pneumatic-tube rails `(G)` run up the facade to a sealed window (memo 38). |
| **Transit Loop** (north spoke) | Elevated ring at y 12, radius 45 m around (0, −55) | The city monorail, still running empty on schedule | Commuters with no city to commute to | The maintenance rail under the monorail is a golden ride-rail ring; stations at the hub, the Civic Center and the FineTree. Lamp-post Tether points bridge two broken spans. Surge Drones swarm the loop; a Zoning Board projects no-go zones on the station platforms. A dead train sits on a broken spur off the north-east curve (secret). `novaLate` plays as Bolt rides past a FineTree screen. |
| **FineTree Plaza** (boss) | (0, −98) 36 × 36 at y 6 | The FineTree™: a hologram that shows every unpaid fine in the city, forever | The whole city | See §4.10. |

### 4.5 Signature traversal: tuning
- **Walkways:** push force 10 m/s² along their arrows while grounded (source `addWalkway` value). Strips are 4 m wide and 16 m long (source size); the remake has 9 of them (2 Civic Center ramps, 5 in the take-a-number hall, 2 on the FineTree ring).
- **HOA violation reversal (new):** a violation is logged when Bolt is inside a Compliance Eye's cone (14 m, 40°) while sprinting, jumping on a walkway, or fighting. The lamp posts in that district flash red for **1.0 s**, then every walkway in the district reverses for **6 s**, then a **8 s** cooldown before the next reversal. A blinded Eye (mallet throw) logs nothing for 20 s.
- **Lamp-post Tether points:** Tether-Hook rules (§0.5), posts 10–12 m apart, ring at 7 m.
- **Golden ride-rails:** the Transit Loop ring and the source's left-district rail.
- **Updraft:** the source's right-side updraft (radius 3, height 12, force 30) becomes a ventilation shaft beside the Permit Office.

### 4.6 Enemies by zone
| Zone | Enemies |
|---|---|
| Fountain Plaza | 2 Meter Maids, 1 Surge Drone |
| Civic Center | 1 HOA Enforcer, 2 Meter Maids |
| HOA District | 2 HOA Enforcers (cul-de-sacs), 3 Meter Maids, 1 Surge Drone, 1 Zoning Board (the clubhouse lawn) |
| The Underpass | 2 Meter Maids, 1 HOA Enforcer, 1 Surge Drone (annex roster) |
| Permit Office | 2 Meter Maids (hall), 2 HOA Enforcers (records hallway), 1 Zoning Board (counter) |
| Transit Loop | 3 Surge Drones, 1 Zoning Board (FineTree station) |
| FineTree Plaza (pre-fight) | 2 HOA Enforcers (the source's two core-plaza turrets) |

### 4.7 Collectibles
**Gold bolts (4)**
| # | Where | How |
|---|---|---|
| 1 | HOA Clubhouse roof (source left gold `(−30, 11, −66)`) | Tether-Hook along the lamp posts |
| 2 | The Consumption Zone™ sign strip on the Permit Office facade (source right gold `(34, 5, −66)`) | Ventilation-shaft updraft, then a ledge |
| 3 | Sealed cache under the Civic Center's west steps (source pocket A `(−38, −40)`) | Slide under the lip |
| 4 | The dead train on the Transit Loop's broken spur | **Glide** (Verdant) from the loop's highest point: an 8 m drop over 22 m |

**Memos (6)**
| Memo | Where | Why there |
|---|---|---|
| 16 HOA Charter, Article 1 | HOA Clubhouse notice board | "We call this 'the Nova Loop'." |
| 17 FineTree Illumination | FineTree Plaza, at a fine-o-meter kiosk (pre-fight side) | |
| 18 Surge Pricing the Air | Transit Loop's Civic Center station, at an "AIR — PEAK PRICING" vending kiosk | |
| 19 RE: The Fountains | Fountain Plaza, the central fountain's valve box | "The HOA is the fountains." |
| 20 Cleaning Bot Directive | Permit Office cleaning-bot closet, with bots still polishing | |
| 38 (hidden) "Darkmatter's motto is 'Nobody Cancels'" | The Permit Office's sealed **Cancellations Department**, a door no one has opened, reached by the pneumatic-tube rails outside | **Grind Soles** (Glacius) |

**Secrets**
| ID | Secret | Gate | Reward |
|---|---|---|---|
| S1 | Sealed cache under the Civic Center | Slide | Gold 3, nanocrate |
| S2 | High perch on the Permit Office roof (source pocket B) | Updraft + hover | Nano pickup |
| S3 | Cancellations Department | Grind Soles | Memo 38 |
| S4 | Dead train | Glide | Gold 4, 100 bolts in the "lost fares" box |
| S5 | The Underpass updraft vault | Annex route | Nanotech +20 HP |
| S6 | HOA Clubhouse server closet | **Thunder throw** `(Z)` on its dead fuse box | Reboots the clubhouse's "resident rewards" kiosk: 120 bolts |
| S7 | The fountains' pump room under the hub | **Magma throw** `(F)` melts the wax seal on the HOA's "DO NOT OPEN — WORK ORDER PENDING" hatch | Nanocrate and the Squatter's spare bench cushion (a hub prop changes) |

### 4.8 Quests
| Quest | Giver | Placement | Hint bark points at |
|---|---|---|---|
| q4a Fine Evasion (4 Meter Maids) | The Squatter, hub bench (−6, 12) | Fountain Plaza, Civic Center, HOA District | Ticket printers whirring |
| q4b Reboot the Fountains (3 chips) | The Squatter | HOA Clubhouse pump closet; Permit Office basement; the FineTree Plaza's fountain ring (source spots: left district, right district, core plaza) | Water gurgling in a pipe |

### 4.9 Story beats
| Beat | Where |
|---|---|
| `flyover5` | First landing |
| `novaIntro` | Arriving on the Transit Loop's FineTree platform, overlooking the boss (the source played it at the core approach) |
| `novaMid` | Civic Center |
| `novaHolo` | HOA Clubhouse |
| `novaLate` | On the Transit Loop, riding past a FineTree screen |
| `introAlgorithm` | First aggro of the Algorithm (fixes the source never playing it) |
| `coreNova` | Core pickup |

### 4.10 Boss arena: FineTree Plaza (The Algorithm)
```
              [THE ALGORITHM: smiley server wall, 12 m wide, 8 m tall]
              intake slots: (1.5 m)   (4 m)   (6.5 m)
   +----------------------------------------------------------+
   |  walkway ring >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>   |
   |   kiosk           complaint kiosk            kiosk       |
   |          +-------------------------------+               |
   |  kiosk   |   FINETREE hologram (7 tiers)  |  complaint   |
   |          |   core pillar behind the wall  |  kiosk       |
   |          +-------------------------------+               |
   |   complaint kiosk      kiosk          kiosk              |
   |  <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< walkway ring |
   +----------------- gate (r) / Transit Loop platform y 12 ---+
```
- **Space:** a 36 m round plaza at y 6 (the source's FineTree plaza). The Algorithm's server wall stands on the north edge. The FineTree hologram rises 17.5 m in the centre and shows the fines it is raining on Bolt.
- **Cover:** the five source fine-o-meter kiosks (r 9 m ring, 3 m tall) plus three **complaint kiosks** between them. Kiosks can be destroyed by the Algorithm's violation stamps (source: 3.4 m telegraphed rings), so cover thins as the fight goes on.
- **Height and flanks:** the Transit Loop platform on the south side is 6 m above the plaza (two ramps down); the walkway ring around the plaza edge carries Bolt clockwise and reverses when the Algorithm logs a violation.
- **Feeding it notices (brief):** the server wall has three intake slots at 1.5 m, 4 m and 6.5 m. A SERVED stamp from Cease & Desist that hits a slot counts as a notice. Because Cease & Desist only goes on sale after the first core (source `shopStock`), and Nova can be the first core, the plaza also has three **complaint kiosks** that print a "Formal Complaint" canister every 12 s; Bolt punts or mallet-throws a canister into a slot. The 6.5 m slot needs a jump from a kiosk top or a Tether swing from a lamp post on the plaza edge.
- **The core** sits in a pillar behind the server wall and is revealed when the Algorithm falls.

### 4.11 Arena challenge: "Tow Zone" (PERMIT PARKING ONLY)
In the Underpass plaza. Five waves of Nova enemies. Every 20 s a Zoning Board repaints the no-parking zones (no-go zones that fine Bolt). Reward 220 bolts.

### 4.12 Out of bounds
| Edge | What the player sees | Quip pool |
|---|---|---|
| City rim | The 20 m HOA perimeter wall: "RESIDENTS MAY NOT LEAVE UNTIL BALANCE IS PAID" | "The map ends. Like my patience." |
| Under the elevated highway and the Transit Loop gaps (kill plane) | A drop into the dark service level | "I rated that dive 2 stars. The splash lacked commitment." |
| Fountains (water-type) | Spotless, lit fountains | "You're a ROBOT-ADJACENT lifeform. Water is a lawsuit." |

---

## 5. Glacius Vault (Planet 5, `LEVELS[6]`)

### 5.1 Original (`GLACIUS_CFG`, `glaciusDress` L10477, `TERRAIN_SPECS_V9.glacius`)
- **Terrain:** a glacier with noise ×4. A **crevasse** winds north along x ≈ 6 (sine wobble ±5) between z −15 and −90, up to 6 m deep. Arrival shelf flat at `(0, 8)`; a cryo-dome basin (+2.5 m) on the left `(−28, −40)`; an ice-shelf climb (+5 m) on the right `(26, −55)`; the core facility floor (+3 m) at `(0, −95)`. Rim +18 m. Bright white palette, theme `glacius`.
- **Dressing:** cryo-dome clusters (translucent shells over warm amber interiors, three capsule racks each), a ForeverYou™ sign, ice spires, half-buried facility struts; at the core, a frozen waterfall and an ice arch.
- **Mechanics:** ice slip (`slip: 1`, ground accel ×0.28) and blizzards (§5.5).
- **Roster:** chillsplit, popsicle, frostpeddler. Mid-boss: **the Retention Specialist** (520 HP).
- **Wing:** **THE ICEBREAKER YARD** ("Frozen customers, stacked for shipping"), plaza **THE COLD STORAGE**.
- **Beats:** `glaciusIntro`, `glaciusMid`, `glaciusLate`, `glaciusHolo` (right district), `coreGlacius`.
- **Life:** snow-hares, frost-flits, a tourist denizen ("Is it Tuesday? Is it the future? Both?").
- **Quests:** Confused Customer at `(6, 0, 12)` (q5a, q5b).

### 5.2 Remake overview
**Fantasy:** ForeverYou™: pay to be frozen, and thawing is a premium tier. Thousands of people are paused mid-subscription. **Signature traversal:** ice slip (keep the ~72% acceleration cut) and **timed blizzards** with rotating wind; the **Grind Soles** are earned here and used on frozen pipe rails. **Structure:** ForeverYou™ Reception (hub) → the Thaw-Queue Hall (west), the Premium Tier wing (east), the Blizzard Ridge (north) → Recall Storage → the Master Freezer (boss).

**Critical path.**
- The **Blizzard Ridge** starts across the crevasse; the only way over is a set of frozen coolant pipes, which need the **Grind Soles** from the Premium Tier (east).
- The **Master Freezer** door only opens for "the next customer in the queue". Bolt has to take a number in the **Thaw-Queue Hall** (west) and then break the queue display so the counter finally advances (ticket 000,000,005).
- The Ridge leads through **Recall Storage** (Sprocket's Batch #1) to the Master Freezer.

### 5.3 Map
```
                                   NORTH
x:  -110       -84      -40     -10   0    10      30       50
    ######## glacier rim (+18 m): "CUSTOMERS BEYOND THIS POINT NOT COVERED"
 -105                    [MASTER FREEZER]  X  core pillar
                          frozen waterfall (F) ice plug -> cave *4 S
  -92                    anteroom M22 "cancellation desk"  r
                         [RECALL STORAGE] M23  (L) -> Legacy cold room M36 S
  -78                         !glaciusLate
  -65  [THAW-QUEUE HALL]     [BLIZZARD RIDGE] M24 summit   [PREMIUM TIER]
       pod rows, queue sign    wind breaks, gusts           luxury pods +5 m
       !glaciusMid  *1         ice pillars                  heated rails (G)
       M25 his empty pod       ||  (G) frozen coolant pipes   Grind Soles
       Premium Wakers          ||      over the crevasse      !glaciusHolo *2
  -40  (Z) stalled thaw panel  ~~ CREVASSE (kill plane) ~~    perch S
       sealed cache S *3       ~~                           ..
  -12  [ICEBREAKER YARD] A <- gate                           ..
       (annex, west)                                     ..
    8                     [FOREVERYOU RECEPTION: HUB]  M21 desk
                           warm amber dome, ice-arch entrance
   26                     [P] ship kiosk beacon   Q Confused Customer
    ######## glacier rim ##############################################
```

### 5.4 Zones

| Zone | Centre (x, z) · size · floor | What OmniScrap built it for | Who got screwed | Combat / platforming read |
|---|---|---|---|---|
| **ForeverYou™ Reception (hub)** | (0, 8) 30 × 24 at y 0 | The sign-up lobby: a warm amber dome, "PAUSE YOUR LIFE. RESUME WHEN THE ECONOMY DOES." | Every customer who signed | Pad outside the dome on the open shelf (outdoor ice, blizzards). Inside the dome: carpet (slip 0), the reception desk (memo 21), brochures. The Confused Customer wanders between the two in a bathrobe and slippers. Light combat outside: 2 Chillsplitters and a Frost Peddler (source arrival roster). |
| **Thaw-Queue Hall** (west spoke) | (−32, −55) 40 × 40 at y 2.5, under the cryo-dome basin | The freezer floor for standard-tier customers | Thousands of people frozen in pod rows, waiting for a thaw that is a premium add-on. The queue display reads "NOW THAWING: 000,000,004" and has for years | Indoor, polished floor (slip 0.5). Pod rows 3 m tall make long aisles, so fights are lane-based with cross-aisles as flanks; pod stacks give height (the top row at 6 m, gold 1). **Popsicles** pose as pods. **Premium Wakers** crack out of pods mid-fight unless Bolt protects the pod's thaw panel; protecting a panel frees the person and pays bolts. The take-a-number machine is at the entrance; the queue display hangs over the far end, and breaking it (three mallet hits on its junction) advances the queue. `glaciusMid` plays on entry. |
| **Premium Tier** (east spoke) | (28, −55) 30 × 30 at y 5, on the ice-shelf climb | The luxury wing: private pods with mood lighting, a spa, a concierge station | The customers who paid extra and are just as frozen | Climbing the shelf (outdoor ice, slip 1) to a glass wing (slip 0.5). **Heated rails** run between the luxury pods; the concierge station issues the "Premium Glide Soles" that Sprocket refits into **Grind Soles**, and the first `(G)` rails teach grinding right there. `glaciusHolo` plays when Grindstone's hologram appears at the concierge. |
| **Blizzard Ridge** (north spoke) | (6, −62) a ridge 12 m wide along the crevasse's north side, rising to y 9 | The facility's "scenic" exterior walk | — | Reached from the hub by grinding the frozen coolant pipes `(G)` over the crevasse (two parallel pipes, so side-hopping dodges Frost Peddler shots). Outdoor ice, full blizzards with stronger gusts (§5.5). **Ice pillars** every 10 m are wind breaks: standing in a pillar's lee cancels the gust push. Chillsplitters burrow under the ridge snow. The summit (memo 24) looks over the aurora. |
| **Recall Storage** | (0, −85) 30 × 18 at y 3 | Cold storage for recalled products | **BoltBuddy Batch #1**: Sprocket's own model, boxed and stacked, "DEFECTIVE: ATTACHMENTS". Memo 23 is here | Indoor warehouse: shelving canyons 8 m tall with forklift-pallet platforms. Narrow aisles, high catwalks. `glaciusLate` plays on the catwalk over the BoltBuddy boxes. This room is right before the boss, so `coreGlacius` ("I saw a BoltBuddy in storage. Batch #1.") lands minutes after the player has seen them. |
| **Icebreaker Yard** (annex, west) | From (−46, −12) west to (−110, −12) | "Frozen customers, stacked for shipping" | Customers sold on as inventory | Annex grammar; the plaza **THE COLD STORAGE** hosts the arena challenge. |
| **Master Freezer** (boss) | (0, −102) 40 m round at y 3 | The heart of the vault: the freezer the Keystone Core powers | Everyone in the vault | See §5.10. |

### 5.5 Signature traversal: tuning
- **Ice slip:** ground acceleration × (1 − 0.72 × slip) (source L3446). Slip values: outdoor ice **1.0** (the full 72% cut, as in the web build); indoor polished floors **0.5**; rubber "ForeverYou™ Courtesy Mats" **0** in every combat space's safe spots (so fights stay readable).
- **Blizzards (source `updateBlizzard`):** first gust 8 s after landing; each gust lasts **4.5 s** with force `sin(ramp) × 5.5 m/s²`; the wind direction starts random and rotates **0.4 rad/s**; fog far drops to **42%**; the next gust comes **11–16 s** later. Banner "BLIZZARD — Brace against the wind!" and Sprocket's first-time bark stay.
  - **Remake:** blizzards only blow outdoors (hub shelf, Premium shelf climb, Blizzard Ridge, Icebreaker Yard). On the **Blizzard Ridge** the gust force is **7.0 m/s²** and the gap between gusts is **9–12 s**. Ice-pillar wind breaks cancel the push.
- **Grind Soles:** §0.5. The crevasse pipes are 40 m long with a 1.5 m downhill drop, so speed stays near 13.5 m/s.
- **Meltwater pools** (water-type) sit in the low basin.

### 5.6 Enemies by zone
| Zone | Enemies |
|---|---|
| Reception (outdoor) | 2 Chillsplitters, 1 Frost Peddler |
| Thaw-Queue Hall | 3 Popsicles (posing as pods), 2 Premium Wakers (pods along the main aisle), 1 Frost Peddler |
| Premium Tier | 2 Popsicles, 1 Premium Waker, 2 Chillsplitters (shelf climb) |
| Blizzard Ridge | 3 Chillsplitters, 2 Frost Peddlers |
| Recall Storage | 2 Popsicles, 1 Frost Peddler |
| Icebreaker Yard | 2 Chillsplitters, 1 Popsicle, 1 Frost Peddler (annex roster) |
| Master Freezer (pre-fight) | 2 Popsicles flanking the door (the source's two core-plaza turrets) |

### 5.7 Collectibles
**Gold bolts (4)**
| # | Where | How |
|---|---|---|
| 1 | Top of the tallest pod stack in the Thaw-Queue Hall (source left gold) | Climb the pod stacks |
| 2 | The penthouse pod in the Premium Tier (source right gold) | Grind the heated rails to it |
| 3 | Sealed cache under the reception dome's west wall (source pocket A) | Slide under the lip |
| 4 | Ice cave behind the frozen waterfall outside the Master Freezer | **Magma throw** `(F)` melts the ice plug (1.5 s) |

**Memos (6)**
| Memo | Where | Why there |
|---|---|---|
| 21 ForeverYou Terms, Sec. 9 | Reception desk | Where people signed |
| 22 Cancellation Flow | The Master Freezer's anteroom, at the "cancellation desk" | Right before the boss's own cancellation flow |
| 23 RECALL BATCH #1 | Recall Storage, on the BoltBuddy pallets | |
| 24 Aurora Licensing | Blizzard Ridge summit, under the aurora | |
| 25 The Bathrobe Situation | Thaw-Queue Hall, in the Confused Customer's open, empty pod | |
| 36 (hidden) RE: Sol-3 legacy test market (DO NOT DISCUSS) | The "Legacy Programs" cold room: an office pod hanging off the Recall Storage ceiling | **Glide** (Verdant) from the Recall Storage catwalk: a 6 m drop over 16 m |

**Secrets**
| ID | Secret | Gate | Reward |
|---|---|---|---|
| S1 | Sealed cache under the reception | Slide | Gold 3, nanocrate |
| S2 | Premium Tier perch (source pocket B) | Grind + hover | Nano pickup |
| S3 | Legacy Programs cold room | Glide | Memo 36 |
| S4 | Frozen-waterfall ice cave | Magma throw | Gold 4 |
| S5 | A stalled thaw panel on a family pod in the Thaw-Queue Hall | **Thunder throw** `(Z)` restarts it | The family thaws, waves and leaves 150 bolts "for the trouble" |
| S6 | Icebreaker Yard updraft vault | Annex route | Nanotech +20 HP |
| S7 | Tether-Hook ice-anchor chain down into the crevasse to a ledge cache | Tether-Hook | 100 bolts, ammo |

### 5.8 Quests
| Quest | Giver | Placement | Hint bark points at |
|---|---|---|---|
| q5a Wake-Up Call (3 Popsicles) | Confused Customer, hub (6, 12) | Thaw-Queue Hall (the Popsicles posing as pods) | A pod that is "breathing wrong" |
| q5b Lost & Frozen (3 slippers) | Confused Customer | Thaw-Queue Hall pod row; Premium Tier spa; a Blizzard Ridge snowdrift (source spots: left basin, right shelf, the perch) | A fuzzy pink shape in the snow |

### 5.9 Story beats
| Beat | Where |
|---|---|
| `flyover6` | First landing |
| `glaciusIntro` | The Master Freezer's anteroom, with the boss visible through the frost window (the source played it at the core approach) |
| `glaciusMid` | Entering the Thaw-Queue Hall |
| `glaciusHolo` | Premium Tier concierge station |
| `glaciusLate` | Recall Storage catwalk |
| `coreGlacius` | Core pickup |

### 5.10 Boss arena: the Master Freezer (The Retention Specialist)
```
                 frozen waterfall wall (north)
   +--------------------------------------------------+
   |  catwalk ring (4 m) ......................  ramp |
   |   vent         . . . . . . . . . .         vent  |
   |  pillar        .  5 x 5 maze grid  .       pillar |
   |    mat         .   (ice walls rise .         mat  |
   |                .   in "cancellation .             |
   |   vent         .   flow")    CORE  .        vent  |
   |  pillar        .           PILLAR  .      pillar  |
   |                . . . . . . . . . . .              |
   |  ramp   mat          "CANCEL" door (far side)     |
   +----------------- anteroom door (r) ---------------+
```
- **Space:** a 40 m round vault at y 3. The floor is a grid of 2.5 m ice tiles (slip 1) with three rubber courtesy mats (slip 0, 3 × 3 m) as safe footing. The Retention Specialist hovers on his floating podium (source: he keeps 8–11 m from Bolt and strafes, within 26 m of home).
- **Cover:** four coolant-vent pillars (2 m wide) at the quarter points. A 4 m catwalk ring runs around the wall with two ramps, giving height and a way out of the ice.
- **The core** sits in a central pillar inside the maze grid.
- **Phase geometry:**
  - **Phase 1:** open floor. Ice spikes (source: 5 telegraphed 2.3 m rings around Bolt, 0.85 s) and frost breath (an 11 m cone).
  - **Phase 2 ("CANCELLATION FEE"):** the roof hatch opens for the source's forced 1.2 s blizzard gust, and 7 spike rings instead of 5.
  - **Phase 3, the "cancellation flow" (brief):** 1.8 m ice walls rise along a 5 × 5 grid in the middle of the floor, forming a maze whose exit is a door marked "CANCEL" on the far side. Every 8 s a third of the walls drop and others rise, rerouting Bolt. The catwalk ring is the escape route around the maze, but the Specialist's homing "pitches" (source) cover it.
- **Out of bounds:** none inside; the vault is sealed.

### 5.11 Arena challenge: "Freezer Burn" (THE COLD STORAGE)
In the Icebreaker Yard plaza, on live ice with blizzards on a fixed 15 s timer. Four waves of Glacius enemies; three pod thaw panels must be kept alive against Premium Wakers. Reward 240 bolts.

### 5.12 Out of bounds
| Edge | What the player sees | Quip pool |
|---|---|---|
| Glacier rim | Ice cliffs with ForeverYou™ fencing: "CUSTOMERS BEYOND THIS POINT ARE NOT COVERED" | "The map ends. Like my patience." |
| The crevasse (kill plane, about 6 m deep then a void) | Blue ice falling away | "I rated that dive 2 stars. The splash lacked commitment." |
| Meltwater pools (water-type) | Slush | "You're a ROBOT-ADJACENT lifeform. Water is a lawsuit." |

---

## 6. Verdant Sink (Planet 6, `LEVELS[7]`)

### 6.1 Original (`VERDANT_CFG`, `verdantDress` L10498, `TERRAIN_SPECS_V9.verdant`)
- **Terrain:** a bioluminescent swamp. Swamp landing flat at `(0, 8)`; wide swamp flats near water level (−0.6 m) at `(0, −30)`; a root-ridge region (+4 m) on the left `(−28, −55)`; a dead-harvester region (+3 m) on the right `(28, −55)`; a lagoon basin (−0.4 m) at `(0, −92)` for the mid-boss. Rim +16 m. Dark teal palette, fog 35–150 m, theme `verdant`.
- **Dressing:** glow-mushroom groves (nine per region, four glow colours), root arches over the paths, a glowing torus; on the left, **the dead MEGA-HARVESTER**, a climbable ruin (12 × 8 × 7 m body, an overgrown reactor, a broken intake, draped glow-vines).
- **Mechanics:** three murk pools `(−14, −30, r 4)`, `(16, −70, r 5)`, `(−2, −88, r 4.5)` and three bounce mushrooms `(−20, −40, power 22)`, `(22, −46, 22)`, `(0, −72, 24)`.
- **Roster:** gloomstalker, sporelobber, pollinator. Mid-boss: **the Compost King** (560 HP) with a one-time NEGOTIATION pause at 30% HP.
- **Wing:** **THE ROOT CELLAR** ("The crops keep their prisoners here"), plaza **THE COMPOST RING**.
- **Beats:** `verdantIntro`, `verdantMid`, `verdantLate`, `coreVerdant`. No Grindstone hologram on this planet.
- **Life:** frog-bots, fireflies, a corn-union denizen ("Ask me about our dental."), the Confused Customer again ("You again! Is it Tuesday HERE too?").
- **Quests:** Shop Steward Cornelius at `(−6, 0, 12)` (q7a, q7b; source IDs q6a/q6b).

### 6.2 Remake overview
**Fantasy:** a failed TerraFarm™ terraforming project. A mega-harvester has leaked coolant into the swamp for six years; everything mutated around it, glows, talks, and the corn unionized (Local 404). **Signature traversal:** **murk pools** (slow + tick damage) and **bounce mushrooms**; **Sprocket Glide** is earned here. **Structure:** the Glow Marsh landing (hub) → the Union Hall (west), the Spore Groves (east), the Mega-Harvester (north) → the Coolant Lagoon (boss).

**Critical path.**
- The Mega-Harvester sits across a wide murk lake, and the corn's **picket line** guards it ("The corn's been guarding it", `verdantMid`). The corn will not let a non-member cross.
- **Union Hall (west):** Bolt is offered a union card (`verdantLate`) and Sprocket is given a husk-silk **solidarity sail** by Local 404: the **Glide**.
- **Spore Groves (east):** bounce mushrooms climb the root ridge to the canopy, where the harvester's fallen grain boom rests.
- **Mega-Harvester (north):** from the boom's high end, Glide down over the murk lake into the harvester's cab, climb down through its insides, and come out at the Coolant Lagoon.

The Union Hall must come before the long glide. The Spore Groves can be climbed earlier, but the boom's end only connects with the Glide.

### 6.3 Map
```
                                   NORTH
x:  -110       -84      -40     -10   0    10      30       50
    ####### toxic marsh rim (+16 m): "TERRAFARM™ TEST BED — NO EXIT" #####
 -100                     [COOLANT LAGOON]  X  Compost King
                           3 leak valves (W ground, E 4 m, N 7 m)
  -88                      leak junction M29   r
                          [MEGA-HARVESTER] cab M28  insides (conveyor guts)
  -72                      fallen grain boom ======\  (L) long glide 30 m
       ~~~~~~~~~ MURK LAKE (deep centre = kill plane) ~~~~~~~~
  -55  [UNION HALL]          picket line (Picket Corn)   [SPORE GROVES]
       Local 404, silo-barn                               root ridge +4 m
       M30 bulletin  !verdantLate                         bounce mushrooms ^
       Glide earned  (F) vine curtain                     M27 glow caps *1
       -> Root Cellar dead letters M39 S                  canopy -> boom end
  -40  hollow log S *3                                    perch S
       ..                 swamp flats, murk pools          ..
  -12  [THE ROOT CELLAR] A <- gate  (under the Union Hall)
    8                     [GLOW MARSH: HUB]  boardwalk  M26 TerraFarm kiosk
                           puffball mushrooms, small murk   Confused Customer
   26                     [P] ship kiosk beacon   Q Shop Steward Cornelius
    ####### toxic marsh rim ###########################################
```

### 6.4 Zones

| Zone | Centre (x, z) · size · floor | What OmniScrap built it for | Who got screwed | Combat / platforming read |
|---|---|---|---|---|
| **Glow Marsh (hub)** | (0, 10) 34 × 28; a boardwalk ring at y 0.6 over marsh at y −0.3 | TerraFarm™'s welcome boardwalk: "THE FUTURE OF FOOD (PATENT PENDING)" | The crops, engineered to be harvested; the swamp, poisoned by the leak | Pad on a raised boardwalk platform. Shop Steward Cornelius stands at the picket line's south end. Small murk pools between boardwalk sections teach the murk rules safely (low damage, short wade). Puffball mushrooms (power 16) teach bouncing. Light combat: 2 Gloomstalkers (cloaked) and a Pollinator. |
| **Union Hall** (west spoke) | (−32, −55) a converted silo-barn 26 × 20, on the root ridge at y 4 | TerraFarm™'s grain silo | Nobody, now: the corn took it over as Local 404's hall | Indoor ground floor (the meeting, the bulletin board with memo 30) and a three-storey silo climb (rafters, grain chutes, hanging sacks) to the loft where the sail is woven. **Glide is taught in the silo:** a drop from the loft rafters (9 m) over a 25 m interior gap. Picket Corn are neutral here. A vine curtain `(F)` hides the stairs to the Root Cellar's dead-letter storeroom. |
| **The Root Cellar** (annex, under the Union Hall, opening west) | From (−46, −12) west to (−110, −12) | "The crops keep their prisoners here": captured harvester drones, held by the corn | The drones, arguably | Annex grammar; the plaza **THE COMPOST RING** hosts the arena challenge. |
| **Spore Groves** (east spoke) | (30, −55) 36 × 36 on the root ridge, canopy at y 18 | A TerraFarm™ fungal-protein trial | The test crops, now a mushroom forest | Vertical: giant mushroom stalks with cap platforms (r 2–4 m) at 3–4 m steps; **bounce mushrooms** (power 22–24) are the express lifts. Spore Lobbers on high caps cover the climb; Gloomstalkers hunt the floor; Pollinators buff them (kill first). Murk pools fill the low ground between stalks. The canopy top reaches the end of the harvester's fallen grain boom. |
| **Mega-Harvester** (north spoke) | Cab (0, −74) at y 8; body down to the lagoon at y 0 | TerraFarm™'s HR-9 harvester | HR-9 itself (memo 28: "the moss is talking to me and it makes GOOD POINTS") | The fallen **grain boom** is a 30 m golden ride-rail from the Spore Groves canopy to a broken end over the murk lake, where the **long glide** (30 m from a 10 m drop) reaches the cab. Inside: conveyor guts (moving belts, 2.6 m/s), seed-hopper drops and threshing drums (timed rotating platforms) leading down to the reactor bay. `verdantMid` plays in the cab, where Sprocket reads the leak logs. |
| **Coolant Lagoon** (boss) | (0, −100) 40 × 32 oval at y −0.4 | The harvester's coolant outfall | The whole ecosystem | See §6.10. |

### 6.5 Signature traversal: tuning
- **Murk pools (source `updateMurk`):** while grounded inside the radius and below pool height + 1.4 m: a drag of about 9 per second (the source's ×0.86 per frame at 60 fps, made frame-rate-independent) and **5 damage every 0.7 s**, with the "The swamp is LITIGIOUS. And acidic. Mostly acidic." bark at 50% chance. Radii 4–5 m (source). The murk lake's deep centre is a kill plane.
- **Bounce mushrooms:** power **22–24** (source). Puffballs (new, small) power **16** for short hops.
- **Glide:** §0.5. Every required glide on this planet obeys the 3:1 rule with a 10% margin.
- **Golden ride-rail:** the grain boom.
- **Harvester insides:** belts at 2.6 m/s (Scrapheap's return-belt value); threshing drums rotate 0.5 rad/s (the Foundry gear-shaft value).

### 6.6 Enemies by zone
| Zone | Enemies |
|---|---|
| Glow Marsh | 2 Gloomstalkers, 1 Pollinator |
| Picket line | 6 Picket Corn (neutral) |
| Union Hall | 4 Picket Corn (neutral); 2 Gloomstalkers sneak in during the silo climb |
| Spore Groves | 3 Spore Lobbers (high caps), 3 Gloomstalkers, 3 Pollinators |
| Mega-Harvester | 2 Spore Lobbers (inside), 2 Pollinators, 1 Gloomstalker |
| The Root Cellar | 2 Gloomstalkers, 1 Spore Lobber, 1 Pollinator (annex roster) |
| Coolant Lagoon (pre-fight) | 2 Spore Lobbers on the rim (the source's two core-plaza turrets) |

### 6.7 Collectibles
**Gold bolts (4)**
| # | Where | How |
|---|---|---|
| 1 | Spore Groves, on the tallest glowing cap (source right gold) | Bounce-mushroom chain |
| 2 | Top of the Union Hall silo, outside on the roof vane (source left gold) | Silo climb, then out a hatch |
| 3 | Inside a hollow log on the west flats (source pocket A `(−38, −40)`) | Slide under the lip |
| 4 | The old TerraFarm™ weather mast on the lagoon's east rim | **Grind Soles** (Glacius): grind the root-wrapped irrigation pipes `(G)` around the rim |

**Memos (6)**
| Memo | Where | Why there |
|---|---|---|
| 26 TerraFarm Incident Report | Hub, the TerraFarm™ welcome kiosk | "Two of these are reasonable." |
| 27 RE: The Glowing | Spore Groves, under the brightest caps | |
| 28 Harvester HR-9 (Missing) | Mega-Harvester cab, on the last log | |
| 29 Coolant Leak Memo | The leak junction just before the Coolant Lagoon | Right where the 40-bolt fix was never made |
| 30 Corn Union Local 404 | Union Hall bulletin board | |
| 39 (hidden) Next-Era Delivery™ pilot | The Root Cellar's **dead-letter storeroom**: an undelivered OmniScrap crate whose invoice is dated next year | **Magma throw** `(F)` burns the vine curtain on the Union Hall's cellar stairs |

**Secrets**
| ID | Secret | Gate | Reward |
|---|---|---|---|
| S1 | Hollow log | Slide | Gold 3, nanocrate |
| S2 | Spore Groves perch (source pocket B) | Bounce + hover | Nano pickup |
| S3 | Dead-letter storeroom | Magma throw | Memo 39 |
| S4 | Irrigation pipes and weather mast | Grind Soles | Gold 4 |
| S5 | The TerraFarm™ sprinkler pump by the hub | **Thunder throw** `(Z)` restarts it for 10 s and flushes the nearest murk pool clear, showing 100 bolts on its bed | |
| S6 | Root Cellar updraft vault | Annex route | Nanotech +20 HP |
| S7 | A Tether-Hook ring line under the harvester's belly, across the murk lake from the west shore | Tether-Hook | Ammo cache, 80 bolts |

### 6.8 Quests
| Quest | Giver | Placement | Hint bark points at |
|---|---|---|---|
| q7a Pest Control (Reverse) (5 Pollinators) | Shop Steward Cornelius, the picket line (−6, 12) | Glow Marsh, Spore Groves, Mega-Harvester | A buzzing that "sounds like a performance review" |
| q7b Stop the Leak (3 sealant cores) | Shop Steward Cornelius | Union Hall loft; a Spore Groves cap; the Mega-Harvester cab (source spots: left, right, lagoon; the lagoon spot moves to the cab so the item is reachable before the boss) | A hiss of coolant |

**q7b payoff (new):** if q7b is complete before the boss, one of the three coolant leaks (the 7 m north valve) is already sealed, so the fight needs two seals instead of three.

### 6.9 Story beats
| Beat | Where |
|---|---|
| `flyover7` | First landing |
| `verdantIntro` | The reactor bay inside the Mega-Harvester, overlooking the Coolant Lagoon (the source played it at the core approach) |
| `verdantMid` | Mega-Harvester cab (the leak logs) |
| `verdantLate` | Union Hall, when the union card is offered |
| `introCompost` | First aggro of the Compost King (fixes the source never playing it) |
| `coreVerdant` | Core pickup, after the leaks are sealed ("We solved a boss fight with plumbing.") |

### 6.10 Boss arena: the Coolant Lagoon (Compost King)
```
              [HARVESTER REACTOR BULK, north wall]
                N valve: 7 m up, on the reactor collar (Glide from the arm)
   +-----------------------------------------------------+
   |  root arch         murk          murk     mushroom  |
   |   (cover)                                  cluster  |
   | W valve                                             |
   | (ground, behind     COMPOST KING start      E valve |
   |  a root arch)                               4 m up  |
   |                                             (bounce |
   |  mushroom      murk          root arch       mush.) |
   |  cluster                                            |
   |       picket corn spectators on the rim             |
   +------------- reactor bay ramp (r) -------------------+
```
- **Space:** a 40 × 32 m oval basin at y −0.4. About 40% of the floor is shallow murk (slow + tick), so footing is a constant choice.
- **Cover:** four root arches (2.5 m tall, the source's root-arch dressing) and two mushroom clusters.
- **The three coolant leaks** (brief: seal 3 leaks while it thrashes):
  - **West valve** at ground level, tucked behind a root arch.
  - **East valve** 4 m up a pipe stack, reached by a bounce mushroom (power 22).
  - **North valve** 7 m up on the reactor collar, reached by gliding from the harvester's broken arm, which hangs over the arena's north-east (Glide is guaranteed: the player needed it to get here).
  - Sealing = hold interact for 2 s at the valve, or three mallet hits on its wheel. Each sealed leak dries one third of the murk.
- **Mercy ending:** the boss doc owns the behaviour. Geometrically, when the third leak is sealed the murk drains and the King has nowhere to rot; the picket corn on the rim come down to "negotiate", and the core rises out of the drained outfall at the centre.

### 6.11 Arena challenge: "Picket Line" (THE COMPOST RING)
In the Root Cellar plaza. Four waves of Gloomstalkers and Pollinators come for six Picket Corn. Hitting a corn fails the challenge ("You crossed the picket line."). Reward 240 bolts.

### 6.12 Out of bounds
| Edge | What the player sees | Quip pool |
|---|---|---|
| Marsh rim | Root walls and a rusted TerraFarm™ fence: "TEST BED — NO EXIT" | "The map ends. Like my patience." |
| The murk lake's deep centre and sinkholes (kill plane) | Black, glowing water | "I rated that dive 2 stars. The splash lacked commitment." |
| Murk pools | Not out of bounds: they hurt and slow (see tuning), with the swamp bark | (murk bark) |

---

### 6.13 Built (T-039)
Verdant Sink is playable: `data/bs/levels/verdant.json` + `verdant_lines.json`, `bs/planets/verdant/`, `bs/world/verdant/` (director, dressing, murk pools, bounce mushrooms, threshing drums, coolant valves, the lagoon arena), `bs/gadgets/sprocket_glide.gd`, the four enemies and the Compost King. Where the build departs from the plan above: the murk lake is a reset (water zone) rather than a kill plane; the grain boom runs 28 m from the canopy C5 (46, −62) to a broken end over the lake at (30, −84) and the glide into the cab (0, −88, y 8.5) is 28 m from an 11 m drop; the harvester's broken arm is reached from its roof by a puffball; the three coolant leaks are W (ground, behind a root arch), E (the pipe stack, bounce mushroom) and N (the reactor collar on the lagoon's north wall, a glide from the arm); q7b's third core sits in the cab (as §6.8 says); the "q7b seals the N valve early" payoff is not wired yet.

## 7. Grand Galleria (Planet 7, `LEVELS[9]`)

### 7.1 Original (`buildGalleria` L10541)
- **Indoor build** (no terrain), kill plane y −12, palette pink/cyan neon on dark violet, theme `nova`. "EVERYTHING MUST GO. NOTHING MAY LEAVE."
- **Roof deck** at y 23.5 (44 × 26 at z +22): pad `(9, 24, 26)`, kiosk `(−8, 24, 25)`, spawn `(9, 25.4, 22)`, parapets, a dead marquee wall with the GRAND GALLERIA ad board, vented junk, and the **broken skylight** (18 × 7 m hole at z +9…+15) that drops into the atrium.
- **Grand Atrium:** floor y 0, 58 × 76 m (z +26 to −50), ceiling y 24; a dead fountain at `(0, −8)`; six storefronts on the side walls with ad boards and neon doorframes, with mannequin "models"; two coupon criers; **mezzanine ring 1** at y 6.7 (10 m wide, 66 m long, both sides) and **ring 2** at y 13.7 (8 m wide, 56 m long); a back bridge at y 6.7 (z −44) joining the rings; three **"escalators"** (a conveyor feed at 3.2 m/s plus a glass updraft, force 26) at `(±17.5, 14)` floor → ring 1 and `(24, −44)` bridge → ring 2; selfie sentries on the rings; **gold 1** at the far end of ring 2 `(24, 15.6, 6)`.
- **Storefront sign parkour** (east wall above ring 2): four neon sign platforms climbing from `(20, 17, −22)` to `(1, 21.5, −40)`, to the **cinema balcony** `(0, 22.6, −46)` with a nano pickup and a nanocrate (pocket B).
- **Food Court** (west wing, 32 × 40 at x −45): a dead palm-tree column, six tables, an ad board; entering triggers a **FLASH SALE** ambush (3 mannequins, a coupon crier, an HR drone); **gold 2** in the back booth `(−58, 1.6, −28)`.
- **Pocket A:** a maintenance room behind a vent on ring 1 west `(−34, 6.7, 10)` with a nano pickup.
- **THE PARKING STRUCTURE** annex through the east wall door at `(31, −12)`: "Validation is a lie. Validation was always a lie.", plaza **LEVEL P3 — LOST CARS**.
- **Freight tunnel** behind a heavy door in the back wall (z −50 to −82, 14 m wide): a conveyor (4.5 m/s), a golden rail ride, two HR drones.
- **Anchor Vault** (46 × 36 at z −100): the EVERYTHING MUST GO anchor sign, two display blocks at `(±16, −112)`, **Greeter Prime** at `(0, 0, −106)` (540 HP; clamped to x ±21, z −116…−85 when charging), `galleriaGreeter` at z −86, the floating **Clause 44 ledger** at `(0, 1.8, −112)` after the kill (+150 bolts, `galleriaLedger`), the exit at `(0, 0, −84)`, **gold 3** behind the anchor displays `(−19, 1.6, −114)`.
- **Mall PA:** a `GALLERIA_PA` line every 40–70 s.
- **Life:** mall mice, sign moths. **Quests:** Gilda at `(5, 0, −2)` in the atrium (q9a, q9b; source IDs q6a/q6b).

### 7.2 Remake overview
**Fantasy:** an orbital dead mall, launched into space to dodge every tax jurisdiction at once. The sale is eternal. The exits are decorative. **Signature traversal:** **escalators that reverse**, **mannequins that move when unseen**, and the mall PA. **Structure:** the Grand Atrium (hub, entered from the roof deck) → the Food Court (west), the Escalator Maze and Parking Structure (east), Guest Services and the Anchor Store (north, boss). The derelict **TONIQ™ VITALITY DISPENSER** (Darkmatter seed, brief §5.4) is in the Food Court.

**When it is played (locked fact).** The Galleria opens on the star map after the **first** Keystone Core, through GLAMBOT's tip (`planetLocked(9)`; `arrive9`: "My sources say the Clause 44 paperwork is in the anchor store."). It stays playable during the rest of the core hunt. As in the web build it is not required for Core Foundry (which only needs the three cores), but the star map marks it as a target from the first core onward and `cs.galleriaLedger.02` ("If Grindstone ever tries that clause **on you**") foreshadows the Foundry's Clause 44 scene.

**Critical path.** The Anchor Store's shutters are down ("STORE OPENING SOON", for eleven years). Two things open them, in either order:
- **POWER**, from the Food Court's backup generator (west): the mall clock restarts.
- **SECURITY**, from the Security Office at the top of the Escalator Maze (east): the freight doors unlock.

Then the freight tunnel (north) leads to Guest Services and the Anchor Store.

The main path only needs the Tether-Hook (guaranteed). Grind Soles and Glide open secrets.

### 7.3 Map
```
                                   NORTH
x:   -62        -45       -28        0        28        45        80
                         +----------------------------+
 -112                    | ANCHOR STORE  X Greeter    |
                         |  ledger vault M35 *3       |
  -90                    | GUEST SERVICES desk M33 r  |
                         +-------------+--------------+
  -66                       FREIGHT TUNNEL === rail  >>> belt
  -50   +-----------------+---[POWER][SECURITY]---+-----------------+
        | FOOD COURT      |   back bridge y 6.7   |                 |
        | FLASH SALE      |                       |  [ESCALATOR     |
  -30   | TONIQ dispenser |   ring 2 (y 13.7) *1  |   MAZE]         |
        | (Z) hatch M40   |   sign parkour -> cinema S              |
        | generator       |   [GRAND ATRIUM: HUB] | Security Office |
  -12   | *2 back booth   |   dead fountain       |  (top, y 20)    |
        |                 |   KIOSK #7 Q Gilda    |  M32 showroom   | [PARKING
   +2   | tables          |   ring 1 (y 6.7)      |  return desks   |  STRUCTURE]
        +-----------------+   storefronts         +-----------------+  A  S vault
  +14   maintenance S (vent)  escalators ^ ^    main exits M34 (decorative)
  +22                    ====== skylight drop (from the roof) ======
            ROOF DECK y 23.5: [P] ship kiosk beacon  M31  marquee "G" (L) *4
```

### 7.4 Zones

| Zone | Centre (x, z) · size · floor | What OmniScrap built it for | Who got screwed | Combat / platforming read |
|---|---|---|---|---|
| **Roof Deck** (arrival) | (0, 22) 44 × 26 at y 23.5 | The mall's sky-lot, with the GRAND GALLERIA marquee | Employees "present at launch", now "orbital assets" (memo 31) | Pad, kiosk and beacon. The broken skylight is the way in: a drop into the atrium past ring 2 (Bolt can hover-steer to ring 2 or ring 1, or fall to the floor). A "CUSTOMER ELEVATOR" on the roof edge is the shortcut back up once the atrium's power is on. The marquee letters rise 6 m above the deck (secret). |
| **Grand Atrium (hub)** | (0, −12) 58 × 76; floor y 0, rings at y 6.7 and 13.7 | The mall's showpiece: fountain, storefronts, two mezzanine rings, a skylight | Shoppers, staff, and the shop owners whose stores never closed | Big, readable combat space with three heights. Floor: the dead fountain as centre cover, storefront doorways as flank pockets. Rings: long lanes with brass railings, Selfie Sentries and Coupon Criers. Mannequins pose in storefront windows (they move only when unseen; the brief's mannequin rule). **Kiosk #7** stands by the fountain: Gilda's phone-case cart ("phone cases and existential dread"). The mall PA plays a `GALLERIA_PA` line every 40–70 s. |
| **Food Court** (west spoke) | (−45, −12) 32 × 40 at y 0 | The food court, where "sampling the samples constitutes a subscription" | Fry cooks, who are still on shift | The source's **FLASH SALE** ambush on entry (3 Mannequins, a Coupon Crier, an HR drone kept as "mall security"). Tables and a dead palm column as cover; the service counter as a long low wall. The **backup generator** is behind the counters (three breaker levers `(B)`, thrown in any order, one of them from a table top). The derelict **TONIQ™ dispenser** stands in a "CLOSED FOR RENOVATION" corner. |
| **Escalator Maze** (east spoke) | (40, −20) 30 × 50, floors y 0 to 20 | The "shopping journey": escalators designed so you can never leave a floor without passing every store | Shoppers, permanently lost | A tower of four half-floors linked by eight escalators that **reverse** (§7.5). The showroom (memo 32) is full of mannequins in poses that change when the camera looks away. Return Desk Mimics wait at "RETURNS" counters (one fake deal per floor). The **Security Office** sits at the top (y 20) and unlocks the freight doors. The source's sign parkour to the cinema balcony leaves from this spoke's third floor. |
| **The Parking Structure** (annex, east) | From (31, −12) east to (95, −12) | "Validation is a lie. Validation was always a lie." | Everyone who ever parked here: the cars are still waiting | Annex grammar; the plaza **LEVEL P3 — LOST CARS** hosts the arena challenge. Its east end is an open deck with a force field onto space. |
| **Freight Tunnel** (north spoke) | (0, −66) 14 × 32 at y 0 | Deliveries: everything the mall "sold" and never let leave | — | The source's conveyor (4.5 m/s) and golden rail ride, with two HR drones and stacked crates. |
| **Guest Services** (boss antechamber) | (0, −88) 30 × 8 at y 0 | The help desk | Lost children, "reclaimed for a modest restocking fee" (a `GALLERIA_PA` line) | A long desk with take-a-number tickets and memo 33. `galleriaGreeter` plays as the PA announces "Now approaching: GUEST SERVICES." |
| **The Anchor Store** (boss) | (0, −104) 46 × 36 at y 0 | The anchor tenant, where Legal stored the Clause 44 ledger "in plain sight" (memo 35) | Every BoltBuddy filed in the ledger, Sprocket first | See §7.10. |

### 7.5 Signature traversal: tuning
- **Escalators (source "esc"):** a conveyor feed at **3.2 m/s** plus a glass updraft (force **26**) that lifts Bolt up the run. **Reversal (new):** every escalator in the Escalator Maze reverses on a **12 s** cycle, with a 1.5 s warning (the chevrons flash and the PA chimes); a reversed escalator pushes down at the same 3.2 m/s and its updraft switches off. A **"SALE NOW ON"** PA line reverses all of them at once, at most once every 40 s.
- **Mannequins move only when unseen** (source `stalker`, speed 7.2): they freeze when inside the camera frustum and within 30 m. Puzzle rooms use this: walk backward to keep them still.
- **Mall PA:** `GALLERIA_PA`, one line every 40–70 s (source).
- **Tether-Hook points:** the clothing-rack hook rails and the hanging store signs.

### 7.6 Enemies by zone
| Zone | Enemies |
|---|---|
| Roof Deck | 1 Selfie Sentry |
| Grand Atrium | 3 Mannequins (storefront windows), 2 Coupon Criers, 2 Selfie Sentries (rings) (source) |
| Food Court | FLASH SALE: 3 Mannequins, 1 Coupon Crier, 1 HR Drone (source) |
| Escalator Maze | 4 Mannequins (showroom), 2 Return Desk Mimics, 1 Coupon Crier, 1 Selfie Sentry |
| The Parking Structure | 2 Mannequins, 2 Coupon Criers (annex roster) |
| Freight Tunnel | 2 HR Drones (source) |

### 7.7 Collectibles
**Gold bolts (4)**
| # | Where | How |
|---|---|---|
| 1 | Far end of ring 2 `(24, 15.6, 6)` | Source gold 1 |
| 2 | Food Court back booth `(−58, 1.6, −28)` | Source gold 2 |
| 3 | Behind the anchor displays `(−19, 1.6, −114)` | Source gold 3 (after the boss) |
| 4 | Inside the "G" of the GRAND GALLERIA marquee on the roof | **Glide** (Verdant) from the Customer Elevator roof: a 7 m drop over 20 m |

**Memos (6)**
| Memo | Where | Why there |
|---|---|---|
| 31 RE: Why Is The Mall In Space | Roof Deck, at the viewport over the planet below | |
| 32 Mannequin Recall (CANCELED) | Escalator Maze showroom | Surrounded by the units that walked away from their recall |
| 33 Greeter Prime: Performance Review | Guest Services desk | Just before you meet him |
| 34 Everything Must Go: Clarification | The atrium's main exit doors (south wall), which are painted on | "The exits are decorative." |
| 35 Document Retention Policy | The Anchor Store's ledger vault, beside the Clause 44 ledger | |
| 40 (hidden) Re: the vending robot that never reported back | Inside the TONIQ™ dispenser's restock hatch, Food Court | **Thunder throw** `(Z)` jolts the dispenser; the hatch drops open |

**The TONIQ™ VITALITY DISPENSER** (brief §5.4): a derelict, violet-glowing vending machine with amber cracks (`#c07dff` / `#ffb347`), stamped "DARKMATTER IMPORTS — DISCONTINUED: SOL-3 TEST MARKET INCIDENT." Anyone can interact with it: it plays `bs.galleria.toniq.01–03` and its jingle backwards. It sells nothing. Memo 40 is behind its restock hatch (above).

**Secrets**
| ID | Secret | Gate | Reward |
|---|---|---|---|
| S1 | Maintenance room behind the ring-1 vent (source pocket A) | Walk through the vent cover | Nano pickup |
| S2 | Cinema balcony (source pocket B) | Sign parkour from the Escalator Maze | Nano pickup, nanocrate |
| S3 | Marquee "G" | Glide | Gold 4 |
| S4 | TONIQ™ restock hatch | Thunder throw | Memo 40 |
| S5 | The Galleria Express: a dead mini-monorail track along the atrium ceiling at y 20 | **Grind Soles** (Glacius) | Ends at the **Lost & Found** room: 150 bolts and Gilda's missing lanyard (she reacts at Kiosk #7) |
| S6 | Parking Structure updraft vault | Annex route | Nanotech +20 HP |
| S7 | A Return Desk Mimic's "real" deal in the Escalator Maze basement, behind a wax-sealed returns chute | **Magma throw** `(F)` | 100 bolts |

### 7.8 Quests
| Quest | Giver | Placement | Hint bark points at |
|---|---|---|---|
| q9a Visual Merchandising (4 Mannequins) | Gilda, Kiosk #7 in the atrium (5, −2) | Atrium storefronts and the Escalator Maze showroom | Something that moved when you blinked |
| q9b Final Markdown (3 price guns) | Gilda | Food Court `(−45, 1, 4)`; ring 2 `(24, 14.6, −30)`; Freight Tunnel `(3, 1, −70)` (source spots) | A price-gun click |

### 7.9 Story beats
| Beat | Where |
|---|---|
| Flyover (new camera path) → `arrive9` | First landing: a camera-only orbit around the mall, then `arrive9` (see §9.3) |
| `galleriaGreeter` | Guest Services |
| `galleriaLedger` | Touching the ledger in the Anchor Store after Greeter Prime falls (+150 bolts, as in source) |
| `bs.galleria.toniq.01–03` | The TONIQ™ dispenser, Food Court |

### 7.10 Boss arena: the Anchor Store (Greeter Prime)
```
            "EVERYTHING MUST GO" anchor sign (north wall, 12 m up)
   +-------------------------------------------------------+
   |  display mezzanine (5 m) along the back wall .......  |
   |  [display]   ledger vault (after)          [display]  |
   |   WELCOME sign generator N (on a pylon, 6 m)          |
   |                                                       |
   | WELCOME              GREETER start           WELCOME  |
   | gen. W                                       gen. E   |
   | clothing racks (T)                    clothing racks  |
   |  ===== checkout counters (1.2 m) ===== (cover line) = |
   +------------------ Guest Services (r) -----------------+
```
- **Space:** the source's 46 × 36 m Anchor Vault at y 0, walls 22 m. Greeter Prime's cart charges stay inside x ±21, z −116…−85 (source clamp), so the edges of the room are safe lanes only if Bolt keeps moving.
- **Cover:** a row of checkout counters (1.2 m high) across the south third: low cover against coupon storms (source: 7–10 radial paper projectiles), useless against a cart charge. The two source display blocks (6 × 6 × 4 m) at `(±16, −112)`.
- **Height:** a display mezzanine at 5 m along the back wall, reached by Tether-Hook from the clothing-rack hook rails.
- **WELCOME sign generators (brief):** three neon WELCOME signs on pylons: west, east (at 3 m) and north (at 6 m, reached from the mezzanine). They power Greeter Prime's waving-arm sweeps; breaking a generator removes one sweep pattern. The welcome-wave shockwave (source: radius 9, damage 14) still needs a jump.
- **After the fight** the ledger floats up in the vault between the displays (source position), with memo 35 beside it, and gold 3 behind the west display.

### 7.11 Arena challenge: "Doorbuster" (LEVEL P3 — LOST CARS)
In the Parking Structure plaza. A timed gauntlet: clear 14 Mannequins and Coupon Criers in 75 s while the lights flicker (mannequins move in the dark, because unlit counts as "unseen"). Reward 260 bolts.

### 7.12 Out of bounds
| Edge | What the player sees | Quip pool |
|---|---|---|
| Main exits | Doors painted on the wall: "EXIT (DECORATIVE)" | "The map ends. Like my patience." |
| Parking Structure's open deck | A shimmering force field onto space: "VALIDATED PARKING ONLY BEYOND THIS POINT" | "The map ends. Like my patience." |
| Escalator pits and the freight shaft (kill plane, y −12) | A dark drop into the mall's sub-levels | "I rated that dive 2 stars. The splash lacked commitment." |
| Fountain (dry) | Not a hazard | — |

---

## 8. Core Foundry (Planet 3, `LEVELS[2]`)

### 8.1 Original (`buildLevel3` L9935, wave arena L10157–10230)
- **Terrain** `TERRAIN_SPECS.p3`: 230 × 160 m centred on z −50, a slag seabed under a lava sea at y −4.1, scorched plateaus, a molten-core sphere glowing under `(0, −72)`, five foundry towers. Kill plane y −3.2. Blue-to-orange palette, theme `foundry`, a klaxon.
- **Lobby** at the top (y 29.4, 34 × 26 at z +22): white marble, side walls, a canopy, a cyan sign, a fountain, **the Grindstone statue** `(7, 30.6, 16)` (smash for bolts), crates. Pad `(−9, 30, 28)`, kiosk `(9, 30, 30)` ransacked with "BACK IN 5 MIN (ARRESTED)" and `blartzArrest`. Hint "Please enjoy the muzak while it lasts."
- **Glass elevator** from y 29.3 down to y 16.9 at z +5, behind a heavy lobby security door.
- **Catwalk and piston gauntlet** at y 17 (z 0 to −24) over the lava, with gap lips, an updraft from below `(0, 5, −6)`, three crushers (speed 1.5, drop 3.7, phases 0 / 2.1 / 1.0), an HR drone; `l3_vent` at `(0, 19, −16)`; **gold #1** on a slab under the piston line `(7, 17.1, −14)`.
- **The Holding Block** east of the catwalk (`(16, 16.6, −16)`, 14 × 16 m): an access bridge, three cells along the east wall with Blartz in the middle one, guards (a slag golem, an HR drone, two weld wasps), `blartzFound`, a door that seals until the guards fall, then three mallet hits on the cell lock → `blartzRescue` (Patent Pending).
- **Gear shaft** (z −37 to −44): two spinning gears, two orbit platforms, an updraft, weld wasps, a ledge over the arena; banner "THE MOLTEN CORE — OmniScrap runs on this. And unpaid interns."; **gold #2** on a gear slab `(9, 13.5, −42)`.
- **Wave arena** on a plateau at `(0, −58)`, 31 × 31 m: cyan walls seal it, two waves (6 then 8: weld wasps, slag golems, HR drones), +25 bolts, a bridge extends, `l3_waves`.
- **Crane-hook side ride** to a bonus island `(29, 5.1, −76)` with a nanocrate, and from it a girder east into **THE SLAG PITS** annex ("OmniScrap dumps what the foundry cannot bill", plaza **THE COOLING FLOOR**).
- **Boss floor** at `(0, −100)`: **Excavatron Prime** (950 HP; phases: enrage at 50%, LIQUIDATION at 25%); `l3_brick` on the bridge `(0, −77)`; `gsIntro` at z −84; **gold #3** on a pillar `(14, 7.2, −80)`.
- **Pocket A:** a maintenance shaft under the lobby `(−14, 26, 30)` with a nanocrate. **Pocket B:** a lava islet `(−13, 11.5, −42)` reached from the orbit gears.
- **Set piece:** shift change (`(−12, 22, 30)`): worker bots trudge a loop and punch a clock.
- **Quests:** Intern #4401 at `(12, 30, 22)` (q3a, q3b, q3c).
- **Memos:** `(−12, 31.4, 30)`, `(0, 24.3, 5)`, `(7, 18.4, −26)`, `(9, 14.7, −42)`, `(29, 6.9, −76)`.

### 8.2 Remake overview
**Fantasy:** OmniScrap HQ. Marble on top, industrial hell underneath. This is where the BoltBuddies are built ("I was born here", `arrive2`). **Signature traversal:** crushers, moving assembly lines, and vent updrafts. The **Omega Forge opens after the Blartz rescue.** This is the last planet: all three gadgets are owned, so the main path uses all of them. **Structure:** the Marble Lobby and the Shift Floor (hub) → the BoltBuddy Assembly Line and HR Floor (west), the Holding Block (east), the Crusher Corridor and the Molten Core (north) → the Foundry Floor and the Executive Bridge (boss).

**Critical path.** The Crusher Corridor's far door is under **SECURITY LOCKDOWN** ("unlicensed innovation detected"), controlled from the Holding Block's guard console. Clearing the Holding Block's guards lifts the lockdown and leads straight into the Blartz rescue, so Blartz is always rescued before the finale and the Omega Forge is always open for the post-game. The Assembly Line and HR Floor are optional but strongly signposted (Sprocket's birthplace, both Intern quests, two memos, a gold bolt).

### 8.3 Map
```
                                    NORTH
x:   -60        -40       -20       0        20        40        60
    ~~~~~~~~~~~~~~~~~~~~~~~~ LAVA SEA (kill plane) ~~~~~~~~~~~~~~~~~~~~~
 -112          [EXECUTIVE BRIDGE] glass boardroom 14 m up   (T)  U U
 -100          [FOUNDRY FLOOR]  X  Excavatron Prime  slag tanks  *3 pillar
  -84                       !gsIntro   r
  -77                       boss bridge !l3_brick
  -58          [WAVE ARENA] plateau 31 x 31  !l3_waves     crane hook ->
                                                       [BONUS ISLAND] M15
  -42  lava islet S  [MOLTEN CORE / GEAR SHAFT] *2  M13     [THE SLAG PITS]
                      orbit gears, updraft U              A Cooling Floor
  -24  [ASSEMBLY LINE]   [CRUSHER CORRIDOR] y 17     [HOLDING BLOCK]
       belts >>> presses   pistons x3, vent U !l3_vent  cells, Blartz
       QA "DEFECTIVE" *4    *1 under the pistons       !blartzFound
       (G) overhead rail   LOCKDOWN door (north end)    !blartzRescue
  -10  [HR FLOOR] M11 M14  ............................  evidence locker
       cubicle maze  *5 (G)                            (Z) M37 S
   +5                     [SHIFT FLOOR: elevator foot, y 17]  time clock
                          glass elevator ^
  +22          [MARBLE LOBBY y 30]  statue  fountain  M12  Q Intern #4401
                !l3_holo2   maintenance shaft S (under)
  +30          [P] ship  kiosk (ARRESTED -> Omega Forge)  beacon  !blartzArrest
```

### 8.4 Zones

| Zone | Centre (x, z) · size · floor | What OmniScrap built it for | Who got screwed | Combat / platforming read |
|---|---|---|---|---|
| **Marble Lobby (hub top)** | (0, 22) 34 × 26 at y 30 | The headquarters lobby: "Marble floors. Forty thousand subscription tiers paid for them." (`l3_holo2`) | Every subscriber who paid for the marble; the interns who polish the statue at 5 AM (memo 12) | Pad on the open-air landing deck; the ransacked kiosk (`blartzArrest`). The statue (q3c), the fountain, planter poles and lobby monitors. Intern #4401 by reception. Light combat: an HR Drone and a Middle Manager "welcoming" visitors. The glass elevator descends behind the security door. |
| **Shift Floor (hub bottom)** | (0, 0) 20 × 14 at y 17 | Where workers clock in | The worker bots on the shift-change loop ("Same shift. It never actually changes.") | The source's shift-change set piece moves here: worker bots trudge a loop past the time clock. Three exits: west (Assembly Line), east (Holding Block bridge), north (Crusher Corridor). A relay checkpoint. |
| **BoltBuddy Assembly Line** (west spoke) | (−36, −24) 40 × 24 at y 14–17 | BoltBuddy™ production | Sprocket: this is the line he came off, stamped DEFECTIVE at QA | **Moving assembly lines** (belts at 3.2 m/s carrying half-built BoltBuddies), robot-arm welders (timed sweeps), and stamping presses (crushers: the source's speed 1.5, drop 3.7). The **QA station** stamps every unit "DEFECTIVE" and drops it in a reject bin (gold 4). An overhead parts rail `(G)` crosses the line. Sprocket's moods shift to `alarmed` here. |
| **HR Floor** (west, below the line) | (−36, −8) 30 × 18 at y 14 | Human Resources | Everyone fired by aerodynamic termination notice (memo 14) | A cubicle maze with 1.6 m walls (cover and line-of-sight breaks), a "Mandatory Fun" break room (memo 11), and the paper-plane launcher room where HR Drones refill. Cable trays `(G)` above the cubicles lead to the "Employee of the Month" frame (gold 5). |
| **Holding Block** (east spoke) | (16, −16) 14 × 16 at y 16.6 (source) | The "Unlicensed Innovation Division" | Blartz, arrested for refusing to put subscription DRM in munitions | The source layout: access bridge, three cells on the east wall, Blartz in the middle one, guards (a Slag Golem, an HR Drone, two Weld Wasps, plus a Middle Manager in the remake). The door seals until the guards fall; the guard console then lifts the Crusher Corridor lockdown, and three mallet hits on the cell lock free Blartz (Blartz counts the hits, as in source). The **evidence locker** next door holds memo 37 behind a dead lock `(Z)`; `bs.foundry.holding.01–03` plays as Blartz walks past it after the rescue. |
| **Crusher Corridor** (north spoke) | (0, −12) 5 × 30 catwalk at y 17 (source) | The "efficient" route through the foundry | Anyone who walks it: "rated for zero survivals" (`l3_vent`) | The source's piston gauntlet: three crushers at phases 0 / 2.1 / 1.0. GLAMBOT's jammed vent (`l3_vent`) is the updraft at the corridor's middle gap. The lockdown door is at the north end. |
| **Molten Core / Gear Shaft** | (0, −42) at y 7–14 | OmniScrap's power source ("And unpaid interns.") | — | The source's two spinning gears and two orbit platforms (radius 5–5.5 m, speeds 0.55 / −0.5) wind down past the core's glow; an updraft (force 30) helps. The fireproof suggestion box (memo 13) is on the overlook ledge. |
| **Wave Arena** | (0, −58) 31 × 31 at y 4 (source) | Security's "reception" | — | Two waves (source rosters plus a Middle Manager in wave 2). Cyan arena walls seal it; the bridge extends after (`l3_waves`). |
| **Bonus Island** (crane-hook ride) | (29, −76) 5 × 5 at y 5 | The Chairman's **executive escape pod** pad | — | Reached on the source's orbiting crane hook. The pod holds memo 15 ("If the mechanic reaches this floor, initiate Project ZONGA"). A girder leads east into the Slag Pits. |
| **The Slag Pits** (annex, east) | From (36, −72) east to (100, −72) | "OmniScrap dumps what the foundry cannot bill" | — | Annex grammar; the plaza **THE COOLING FLOOR** hosts the arena challenge. |
| **Foundry Floor + Executive Bridge** (boss) | Floor (0, −100) 40 m round at y 4; bridge 30 × 10 at y 18 over the north edge | Excavatron Prime's proving floor; the Chairman's boardroom | The galaxy | See §8.10. |

### 8.5 Signature traversal: tuning
- **Crushers:** speed 1.5, drop 3.7, floor y 17.4, phases 0 / 2.1 / 1.0 (source `addCrusher` calls). Stamping presses on the Assembly Line use the same values with phases 0 / 1.4 / 2.8.
- **Assembly lines:** belts 3.2 m/s (Scrapheap's belt value); robot-arm sweeps every 3 s with a 0.6 s amber light telegraph.
- **Vent updrafts:** radius 2.6–3, height 9–13, force 30–32 (source).
- **Orbit platforms:** radius 5–5.5, speed 0.55 / −0.5 (source); spinners 0.5 / −0.7.
- **Glass elevator:** patrol speed 0.32 (source).
- **Gadgets on the main path:** Tether-Hook rings on the gear shaft (a fall-back if an orbit platform is missed); Grind Soles on the Assembly Line's overhead rail is optional; Glide from the wave arena's bridge to the boss floor is a shortcut on repeat attempts.

### 8.6 Enemies by zone
| Zone | Enemies |
|---|---|
| Marble Lobby | 1 HR Drone, 1 Middle Manager, the Statue (prop) |
| Shift Floor | none (the marchers are life dressing) |
| Assembly Line | 2 Slag Golems, 4 Weld Wasps (swarm from the welders) |
| HR Floor | 3 HR Drones, 1 Middle Manager |
| Holding Block | 1 Slag Golem, 1 HR Drone, 2 Weld Wasps (source guards), 1 Middle Manager |
| Crusher Corridor | 1 HR Drone (source) |
| Gear Shaft | 2 Weld Wasps (source) |
| Wave Arena | Wave 1: 4 Weld Wasps, 1 Slag Golem, 1 HR Drone. Wave 2: 2 HR Drones, 2 Slag Golems, 4 Weld Wasps, 1 Middle Manager |
| The Slag Pits | 1 Slag Golem, 1 HR Drone, 2 Weld Wasps (annex roster) |

### 8.7 Collectibles
**Gold bolts (5)**
| # | Where | How |
|---|---|---|
| 1 | Slab under the piston line `(7, 17.1, −14)` | Source #1 |
| 2 | Gear slab `(9, 13.5, −42)` | Source #2 |
| 3 | Pillar on the boss floor `(14, 7.2, −80)` | Source #3 |
| 4 | The QA reject bin at the end of the Assembly Line | Ride the belts through the press timing |
| 5 | The "Employee of the Month" frame above the HR Floor | **Grind Soles** on the cable trays |

**Memos (6)**
| Memo | Where | Why there |
|---|---|---|
| 11 Mandatory Fun: Guidance | HR Floor break room | |
| 12 Lobby Statue Maintenance | Marble Lobby, on the statue's polishing cart | |
| 13 Molten Core: Q3 KPIs | Gear-shaft overlook, in the fireproof suggestion box | |
| 14 Termination Notice Style Guide | HR Floor paper-plane launcher room | |
| 15 PROJECT ZONGA (CONFIDENTIAL) | Bonus Island, inside the executive escape pod | Sets up `zongaReveal` |
| 37 (hidden) Asset Sale — Confiscated Vendor IP (BLARTZ, 1 forge schematic) | Holding Block evidence locker | **Thunder throw** `(Z)` powers its dead lock. Sits beside the confiscation scene (`bs.foundry.holding`) |

**Secrets**
| ID | Secret | Gate | Reward |
|---|---|---|---|
| S1 | Maintenance shaft under the lobby (source pocket A) | Drop through the vent | Nanocrate |
| S2 | Lava islet (source pocket B) | Orbit-gear hop | Ammo, nanocrate |
| S3 | Evidence locker | Thunder throw | Memo 37, and Blartz's confiscated shoes (a prop) |
| S4 | Employee of the Month frame | Grind Soles | Gold 5 |
| S5 | The Slag Pits updraft vault | Annex route | Nanotech +20 HP |
| S6 | Behind the lobby fountain, a wax-sealed "CHAIRMAN ONLY" humidor | **Magma throw** `(F)` | 150 bolts |
| S7 | A Glide line from the Executive Bridge's roof (reachable after the finale) to the foundry tower tops | Glide | A Grindstone bobblehead (a lobby prop) and 200 bolts |

### 8.8 Quests
| Quest | Giver | Placement | Hint bark points at |
|---|---|---|---|
| q3a Mandatory Fun Audit (2 HR Drones) | Intern #4401, Marble Lobby (12, 22) | HR Floor | Clipboards rustling |
| q3b Clock Out Forever (3 chips) | Intern #4401 | Lobby reception `(−10, 31.4, 26)`; the Crusher Corridor `(5, 18.4, −30)`; the Bonus Island `(25, 6.9, −70)` (source spots) | A time clock's ding |
| q3c Art Criticism (the Statue) | Intern #4401 | The lobby statue | "Marble disappointment" |

### 8.9 Story beats
| Beat | Where |
|---|---|
| Flyover (new camera path) → `arrive2` | First landing (see §9.3) |
| `blartzArrest` | The ransacked kiosk on the landing deck |
| `l3_holo2` | Marble Lobby |
| `l3_vent` | Crusher Corridor, at GLAMBOT's jammed vent |
| `blartzFound` | Entering the Holding Block |
| `blartzRescue` | The third mallet hit on the cell lock |
| `bs.foundry.holding.01–03` | Right after `blartzRescue`, at the evidence locker |
| `bs.foundry.forge.01–04` | First interaction with the Omega Forge at the lobby kiosk |
| `l3_waves` | Wave Arena cleared |
| `l3_brick` | The boss bridge |
| `gsIntro` | Entering the Foundry Floor |
| `introGrindstone` | First aggro (via the boss title-card table) |
| `ending` → `zongaReveal` (first time) → post-credits | Final boss defeat |

### 8.10 Boss arena: the Foundry Floor and the Executive Bridge (Excavatron Prime → Chairman Grindstone)
```
          [EXECUTIVE BRIDGE: glass boardroom, 30 x 10, y 18]
           long table (cover)   shareholder screens   panoramic window
        U vent (T)                                         (T) vent U
   ~~~~~ lava ~~~~+--------------------------------------+~~~~ lava ~~~~
                  |  slag tank      bollards     slag tank|
                  |   pillar                       pillar |
                  |          EXCAVATRON start             |
                  |                                       |
                  |  slag tank                   slag tank|
                  |   pillar    gold 3 pillar      pillar |
   ~~~~~ lava ~~~~+-------- boss bridge (r) --------------+~~~~ lava ~~~~
```
- **Space:** a 40 m round plateau at y 4, ringed by lava (kill plane). Its radius is just over the source's sweep-beam reach (22–24 m), so there is no safe edge: the only beam shelter is behind cover.
- **Cover:** four slag-tank pillars (3 m wide, 6 m tall) at the quarter points, and warning bollards (low, decorative) around the edge.
- **Phase geometry (Excavatron):**
  - **Phase 1:** rockets (3 homing) and stomps (8.5 m shockwave ring; jump it, then hit the exposed core). Pillars block rockets.
  - **Phase 2 (enraged, <50%):** armour plates blow off, a sweeping mining beam (24 m) joins in, the stomp ring grows to 11 m with a second inner ring at 6.5 m, and weld-wasp adds arrive.
  - **Phase 3 (LIQUIDATION, <25%):** a second beam orbits forever (22 m, 0.75 rad/s). It **cuts the slag-tank pillars**: each pillar it crosses three times melts down to a 1 m stub, so cover shrinks through the phase.
- **Final phase (Grindstone 2.0, brief):** the Chairman ejects up to the **Executive Bridge**, a glass boardroom 14 m above the north edge. Bolt rides the two vent updrafts (force 30) at the north-west and north-east corners, with Tether-Hook rings at the top, to reach it. The bridge has a long boardroom table (1 m high cover down its length), shareholder screens on the walls (the "rebrand" visuals), and a panoramic window over the foundry. The floor below heats, so the fight stays up top.
- **Clause 44 (`l3_brick`)** plays on the 4 × 6 m bridge between the wave arena and the floor, before `gsIntro`: a deliberately narrow space for a scene about one robot.

### 8.11 Arena challenge: "Overtime" (THE COOLING FLOOR)
In the Slag Pits plaza. Five waves of Foundry enemies led by a Middle Manager. Floor panels heat in a moving pattern with a 1 s glow telegraph; standing on a hot panel burns 6 damage per second. Reward 300 bolts.

### 8.12 Out of bounds
| Edge | What the player sees | Quip pool |
|---|---|---|
| The lava sea (kill plane, y −3.2) | Molten lava under every catwalk | "Rust warranty voided. Again." · "I rated that dive 2 stars. The splash lacked commitment." |
| The Lobby's back and sides | Marble walls; the open-air landing deck has a glass balustrade with "NO REFUNDS BEYOND THIS POINT" | "The map ends. Like my patience." |
| Lobby fountain (water-type) | A decorative fountain | "You're a ROBOT-ADJACENT lifeform. Water is a lawsuit." |

---

## 9. Star map, space travel and flyovers

### 9.1 Star map
- Opened from the **ship's cockpit** on any landing pad (and from the main menu's CONTINUE, as in the web build).
- Port the web build's star map (`populateStarmap` L12306): planet nodes in `CAMPAIGN` order with lock state and tooltips, the target pulse on the current mission's planets, the per-planet line (now "★ n/total · CORE ✓/? or CLEAR/GO · HERE"), the Zonga "???" slot, the Loop Riot slot, and the shop button.
- **Mission tracker** (`computeMission` L12285): CHAPTER 1 → CHAPTER 2 → CHAPTER 3 — THE HEIST (Keystone progress bar, remaining planets listed) → FINALE → CAMPAIGN COMPLETE. The Grand Galleria is added to the CHAPTER 3 targets once the first core is in.
- **Gating** is `planetLocked()` exactly (§10).

### 9.2 Space travel
- Port the web build's transition (`updateTravel` L12498): **liftoff** 2.6 s (the ship rises 26 m from the pad, camera beside it) → **hyperspace** 3.2 s (260 star-line streaks, FOV +24°) → **orbit** 3.0 s (the destination planet in its `orbColor` grows ahead) → land. About 9 s in total.
- **Skip:** hold advance once travel has been seen (`settings.seenTravel`), as in the web build.
- The brief calls this a "minigame"; the web build has no interactive part. The remake keeps it a transition. HUMOR-REVIEW's travel tips appear during hyperspace only if approved at the M0 review.

### 9.3 Flyovers
- **Order fix:** on the first landing, play the planet's flyover, then its arrival scene, back to back (the web build played only the flyover first time and the arrival scene on the next visit).
- **Existing flyovers:** `flyover0` (Scrapheap, first played on the first return by ship, since the campaign starts on the planet), `flyover1`, `flyover5`, `flyover6`, `flyover7`.
- **New flyovers, camera only, no new lines:**
  - **Core Foundry:** the camera comes down through the parted shield over the lava sea, past the foundry towers, to the Marble Lobby's landing deck, while `arrive2` plays over it.
  - **Grand Galleria:** the camera orbits the mall in space, past the dead marquee, and settles on the roof deck, while `arrive9` plays over it.
- Each flyover's camera path ends looking at the pad, so control hands over cleanly.

---

## 10. Campaign order and the Galleria during the core hunt
| Step | Planet | Unlock rule (`planetLocked`) | Gadget earned |
|---|---|---|---|
| 0 | Prologue (Bolt's Garage) | New game | Boomerang throw taught |
| 1 | Scrapheap Junction | Always open | — |
| 2 | Rustvane Canyon | Scrapheap cleared | Tether-Hook |
| — | `shieldReveal` | Leaving Rustvane the first time | — |
| 3–5 | Nova Plaza, Glacius Vault, Verdant Sink, any order | Rustvane cleared | Grind Soles (Glacius), Glide (Verdant) |
| 3–6 | **Grand Galleria** | **At least one Keystone Core** (GLAMBOT's tip). Playable for the rest of the core hunt and after. Not required for the Foundry. | — |
| — | `shieldFall` | Third core | — |
| 7 | Core Foundry | All three cores | Omega Forge (after the Blartz rescue) |
| — | `ending` → `zongaReveal` → post-credits | Excavatron Prime / Grindstone defeated | — |

---

## 11. Master tables

### 11.1 Gold bolts (30)
| Planet | # | Location | Gate |
|---|---|---|---|
| Scrapheap | 1 | Garage Lot inspection pit | Boomerang latch |
| | 2 | Dune Bowl west-rim wreck pocket | Start |
| | 3 | Magnet-crane bail-out slab | Start |
| | 4 | Hull-top side slab | Start |
| | 5 | AIR PREMIUM™ blimp gondola | Tether-Hook |
| Rustvane | 1 | Behind the waterfall | Start |
| | 2 | East-cliff cave | Start |
| | 3 | Stray side billboard | Start |
| | 4 | Ore-cart line end | Grind Soles |
| Nova | 1 | HOA Clubhouse roof | Tether-Hook |
| | 2 | Consumption Zone™ sign strip | Start |
| | 3 | Sealed cache under the Civic Center | Slide |
| | 4 | Dead train on the Transit Loop spur | Glide |
| Glacius | 1 | Thaw-Queue Hall pod-stack top | Start |
| | 2 | Premium Tier penthouse pod | Grind Soles (earned there) |
| | 3 | Sealed cache under Reception | Slide |
| | 4 | Frozen-waterfall ice cave | Magma throw |
| Verdant | 1 | Spore Groves tallest cap | Start |
| | 2 | Union Hall silo roof vane | Start |
| | 3 | Hollow log | Slide |
| | 4 | Lagoon weather mast | Grind Soles |
| Galleria | 1 | Ring 2 far end | Start |
| | 2 | Food Court back booth | Start |
| | 3 | Behind the anchor displays | After the boss |
| | 4 | Marquee "G" | Glide |
| Foundry | 1 | Under the piston line | Start |
| | 2 | Gear slab | Start |
| | 3 | Boss-floor pillar | Start |
| | 4 | QA reject bin | Start |
| | 5 | Employee of the Month frame | Grind Soles |

### 11.2 Memos (40)
| Memo | Planet | Zone | Gate |
|---|---|---|---|
| 01 RE: RE: RE: The Moon | Scrapheap | Billing Mast crow's nest | Start |
| 02 Garage Repossession FAQ | Scrapheap | Garage Lot (after `intro`) | Start |
| 03 Scrap Mutt Feeding Policy | Scrapheap | Dune Bowl | Start |
| 04 Conveyor Safety Update | Scrapheap | Conveyor Works pipe-top cache | Grind Soles |
| 05 Sunset Monetization Pilot | Scrapheap | Hull-top Vista | Start |
| 06 Twin Suns: One Is An Ad | Rustvane | Top Billboard Deck | Start |
| 07 Infinity Pool Incident | Rustvane | Deck A infinity edge | Start |
| 08 Ambassadog Vests | Rustvane | Deck C kennel | Start |
| 09 Selfie Sentry Firmware 9.1 | Rustvane | Cliff Ledges charging dock | Start |
| 10 RE: The Lava Pool | Rustvane | Back of House laundry | Start |
| 11 Mandatory Fun: Guidance | Foundry | HR Floor break room | Start |
| 12 Lobby Statue Maintenance | Foundry | Marble Lobby | Start |
| 13 Molten Core: Q3 KPIs | Foundry | Gear-shaft suggestion box | Start |
| 14 Termination Notice Style Guide | Foundry | HR Floor launcher room | Start |
| 15 PROJECT ZONGA (CONFIDENTIAL) | Foundry | Bonus Island escape pod | Start |
| 16 HOA Charter, Article 1 | Nova | HOA Clubhouse | Start |
| 17 FineTree Illumination | Nova | FineTree Plaza kiosk | Start |
| 18 Surge Pricing the Air | Nova | Transit Loop station | Start |
| 19 RE: The Fountains | Nova | Fountain Plaza valve box | Start |
| 20 Cleaning Bot Directive | Nova | Permit Office closet | Start |
| 21 ForeverYou Terms, Sec. 9 | Glacius | Reception desk | Start |
| 22 Cancellation Flow | Glacius | Master Freezer anteroom | Start |
| 23 RECALL BATCH #1 | Glacius | Recall Storage | Start |
| 24 Aurora Licensing | Glacius | Blizzard Ridge summit | Start |
| 25 The Bathrobe Situation | Glacius | Thaw-Queue Hall empty pod | Start |
| 26 TerraFarm Incident Report | Verdant | Hub welcome kiosk | Start |
| 27 RE: The Glowing | Verdant | Spore Groves | Start |
| 28 Harvester HR-9 (Missing) | Verdant | Mega-Harvester cab | Start |
| 29 Coolant Leak Memo | Verdant | Leak junction | Start |
| 30 Corn Union Local 404 | Verdant | Union Hall | Start |
| 31 RE: Why Is The Mall In Space | Galleria | Roof Deck | Start |
| 32 Mannequin Recall (CANCELED) | Galleria | Escalator Maze showroom | Start |
| 33 Greeter Prime: Performance Review | Galleria | Guest Services | Start |
| 34 Everything Must Go: Clarification | Galleria | Atrium main exits | Start |
| 35 Document Retention Policy | Galleria | Anchor Store ledger vault | After the boss |
| 36 (hidden) Sol-3 legacy test market | Glacius | Legacy Programs cold room | Glide |
| 37 (hidden) Confiscated Vendor IP | Foundry | Holding Block evidence locker | Thunder throw |
| 38 (hidden) "Nobody Cancels" | Nova | Cancellations Department | Grind Soles |
| 39 (hidden) Next-Era Delivery™ pilot | Verdant | Root Cellar dead-letter storeroom | Magma throw |
| 40 (hidden) the vending robot | Galleria | TONIQ™ dispenser restock hatch | Thunder throw |

Memo 04 is the only original memo behind a gadget, so the memo epilogue (35 OmniScrap memos) needs one return trip to Scrapheap with Grind Soles.

### 11.3 Gadget backtracking payoffs
| Earlier planet | Tether-Hook | Grind Soles | Glide | Magma throw | Thunder throw |
|---|---|---|---|---|---|
| Scrapheap | Blimp, gold 5 | Pipe-top cache, memo 04 | Mama Gasket's mailbox | The Row's tarp shed | Junk processor bay |
| Rustvane | Cliff Roost | Ore-cart line, gold 4 | Second-sun projector | Collapsed Mine timbers | Vending machine |
| Nova | (main path) | Cancellations Dept., memo 38 | Dead train, gold 4 | Fountain pump room | Clubhouse server closet |
| Glacius | Crevasse ledge cache | (earned here) | Legacy cold room, memo 36 | Ice cave, gold 4 | Stalled thaw panel |
| Verdant | Harvester belly ring line | Weather mast, gold 4 | (earned here) | Dead-letter storeroom, memo 39 | Sprinkler pump |
| Galleria | (main path) | Galleria Express, Lost & Found | Marquee "G", gold 4 | Returns chute | TONIQ™ hatch, memo 40 |
| Foundry | (main path) | Employee of the Month, gold 5 | Tower-top line (post-game) | Chairman's humidor | Evidence locker, memo 37 |

### 11.4 Arena challenges
| Planet | Name | Space | Reward |
|---|---|---|---|
| Scrapheap | Compactor Countdown | The Crusher Pit (Boneyard) | 180 |
| Rustvane | Poolside Pile-Up | The Quarry Floor (Strip Mine) | 200 |
| Nova | Tow Zone | Permit Parking Only (Underpass) | 220 |
| Glacius | Freezer Burn | The Cold Storage (Icebreaker Yard) | 240 |
| Verdant | Picket Line | The Compost Ring (Root Cellar) | 240 |
| Galleria | Doorbuster | Level P3 — Lost Cars (Parking Structure) | 260 |
| Foundry | Overtime | The Cooling Floor (Slag Pits) | 300 |
