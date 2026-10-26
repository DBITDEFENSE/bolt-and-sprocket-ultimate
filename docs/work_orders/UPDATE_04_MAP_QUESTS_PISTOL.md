# UPDATE 04 — MINIMAP, PAUSE MAP & MARKERS, QUEST LOG, BOTS ON THE EASTER EGG, PISTOL ATTACHMENTS

A work order for the existing project. All rules from `ULTIMATE_PROMPT.md`, v2, v3, `OVERNIGHT_RUN.md`, `UPDATE_02_POLISH.md`, and `UPDATE_03_BOT_AI.md` (all in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`) still apply. Work unattended per OVERNIGHT_RUN.md: branch per section, `main` always launches, commit often, keep the `PROGRESS.md` resume line current, update `PLAY.bat`, and write a morning report.

**These rules change with this update** (log them in `DECISIONS.md`):
- v1 Appendix A §A13 said "no minimap." The minimap is now **on by default**, with a **"Classic HUD"** setting that turns it off.
- v1 said objectives come only from character quotes. Now there is a **quest log in the pause menu**, with a spoiler setting (§4).
- UPDATE_03 said bots never touch Easter-egg objects. Now they **can, when the player allows it** (§5).

---

## 1. MAP DATA FOR EVERY MAP (build this first; everything else uses it)

- **Every playable level gets a `MapData` resource** (`/data/maps/<map_id>/mapdata.tres`):
  - Gravelight: Crossroads Inn, Kaltenbrunn, Helvetia Works, Morgenrot, and any future map.
  - Bolt & Sprocket: every planet hub, side-mode arenas, Zonga, and the Colosseum.

  `MapData` holds:
  - **Floors:** a list of floors/layers, each with a height range. Kaltenbrunn has surface / admin / level −2 / vault; Morgenrot has valley / tunnels / Kessel / summit; the Inn has cellar / ground / upstairs.
  - **One top-down map image per floor, baked automatically** by `tools/bake_minimap.gd`. It does an orthographic render of the level geometry per height slice (walls dark, floors light, outdoor terrain textured), then a stylization shader. The art style per game:
    - **Gravelight:** a field-sketch / ink-on-paper look with a slight paper texture and pencil hatching for walls, matching the ledger-stamp HUD.
    - **Bolt & Sprocket:** a clean holo-map in the orange/cyan UI style.
    - **Fine Print / Helvetia Works:** a Swiss-blueprint look.
  - **Zones:** named polygons (e.g. "Salt Chapel") for labels and "you are here."
  - **Points of interest**, generated automatically from the scene by scanning for buyable / door / perk / crate-spot / ammo-box / Crucible / power-switch / workbench / trap / lift nodes, each with an icon type.
- **Bake check:** `tools/check_mapdata.gd` fails if any playable level is missing MapData, is missing a floor image, or has POIs out of date with the scene. Run it in the test suite, so **no map can ship without its map.**
- Re-bake whenever a level changes. Add a dev console command, `bake_minimap <map_id>`.

## 2. THE MINIMAP (top-left HUD)

- **Placement:** top-left corner, circular (or a rounded square, as a setting).
  - **Gravelight:** framed like a brass compass bezel, with the round counter's ledger-stamp style nearby. Move the existing HUD elements so nothing overlaps.
  - **B&S:** the holo style, and the HP bar moves under it.
- **Shows:**
  - the player arrow (center);
  - teammates and bots (character-colored dots with an initial); Jakub (his own icon); downed allies (a pulsing red cross with their bleed-out ring);
  - **marks** (§3);
  - doors (open or locked, and the price on hover in the full map);
  - **discovered** buyables (perks, wall weapons, ammo boxes, the crate's current spot once seen, the Crucible, workbenches);
  - active power-ups (blinking);
  - the boss icon when a boss is active;
  - Easter-egg objectives the player has discovered, with the spoiler setting applied (§4).
- **Zombies are NOT shown by default** (classic tension), with three exceptions:
  - Zombies that are **firing-revealed**: when a player fires an unsuppressed weapon, nearby zombies blip for 1s.
  - The **Overwatch** reward from The Slender (v3 §4.7) shows zombies within 12 m.
  - A setting, "Show nearby zombies: Off / Firing only / Always," with Off by default.
- **Fog of war / discovery:** areas reveal as you visit them (or always visible, as a setting). Buyable icons appear once you've seen them in person.
- **Floors:** the view switches floors automatically by player height. Other floors are faintly ghosted underneath, and stairs, ladders, and lifts get arrows.
- **Settings:** rotate-with-player vs. north-up, zoom (3 levels; also a key), size, opacity, position (TL/TR), and icon scale. Colorblind-safe icon shapes (shape, not just color).
- **Performance:** draw it with a SubViewport or a 2D canvas using pre-baked textures. No live 3D render. Budget: under 0.3 ms per frame.

## 3. PAUSE MAP & MARKERS

When the player pauses, the pause screen opens on a **MAP tab** by default. In solo, the game is frozen while it's open. In co-op (later) it doesn't pause the game. The tabs are **MAP · OBJECTIVES · LOADOUT · SETTINGS · QUIT**.

**The full map:**
- full-screen, with floor tabs (or a scroll wheel / bumpers), pan and zoom, zone labels, and a legend;
- hover any icon to see what it is, its price, and whether it's open, bought, or locked;
- the current round and power status in a corner.

**Marking (mouse or controller):**
- **Click an empty spot** → a radial menu: **Go Here · Defend Here · Danger · Regroup · Custom note** (type a short note or pick a preset).
- **Click a buyable icon** → **BUY THIS**: perk machine, wall weapon, ammo box, door, Mystery Crate, Crucible, trap, or buildable workbench.
- **Click an Easter-egg objective / part / power-up icon** → **Collect / Activate this**.
- Each mark then asks **who** it's for: **Me** (just a waypoint), **Any bot**, a **specific bot** (by portrait), or **Jakub**. The default is "Any bot" for BUY/COLLECT/DEFEND and "Me" for Go Here.
- Marks appear on the minimap, on the full map, and **in the world** as small diegetic markers: a chalk "X" on the floor for Gravelight, a holo pin for B&S, with distance and icon, fading with distance. In-world they're readable but never cluttered.
- **Limits:** up to 3 personal marks and 1 active order per bot. Placing a new one replaces the oldest. Right-click / press B on a mark to remove it.
- **Quick-mark in-game:** a **ping key** (middle mouse / D-pad up) marks whatever you're looking at with the same logic as the map: look at a perk machine → "Buy this" for any bot; look at a wall → "Go here"; double-tap → "Danger."

**What bots do with marks** (built on the UPDATE_03 utility AI; marks become high-weight **Orders** on the blackboard):
- **BUY THIS:** the assigned bot (or the best available one: closest, with enough Scrip, not busy reviving) acknowledges in character with a voice line and a ping. It **checks its Scrip**:
  - **Can afford:** it paths there, buys, and confirms ("Got the Ironhide. Feel like a barrel.").
  - **Can't afford:** it says so with how much it's short ("Need 600 more for that, boss."). The order stays queued for 60s while it earns.
  - **Item for the player:** a wall weapon marked for the player puts a **"Buy for teammate"** prompt in front of the bot. The bot buys it and drops it at the player's feet, or holds it until the player comes to take it (it costs the bot's Scrip).
  - **Doors:** it opens marked doors only if it can afford them and the player marked them. (Doors cost shared progress, so always ask for confirmation in the radial when marking a door: "Open this door for 1,250?")
- **DEFEND HERE:** the bot holds within ~4 m and repairs nearby windows. **REGROUP:** all bots come to the mark. **DANGER:** bots raise the pathing cost around it for 60s and call it out.
- **Order priority:** revive emergencies interrupt orders. Orders resume afterward, and the bot says so ("Back to it.").
- The full map shows a small **order status** next to each bot's portrait: "Going to buy Ironhide (1,200 short)", "Defending Rail Yard", "Idle".

## 4. OBJECTIVES TAB (quest log on pause)

A clean list in the game's style: ledger pages for Gravelight, a holo panel for B&S. Selecting any entry **highlights its location on the MAP tab**, if known, and offers **"Assign to bot"** where possible (§5).
- **CURRENT OBJECTIVE** (always on top, 1 line): a soft main goal derived from match state. Examples: "Open the path to the Generator Hall," "Turn on the power," "Attune the 3 Resonance Pylons (1/3)," "Survive."
- **EASTER EGG:** a step list from the QuestManager step graph:
  - **completed** steps ✔ in plain words;
  - the **current** step with its hint;
  - **future** steps shown as "???".
- **Spoiler setting:**
  - **Hidden:** only completed steps, no hints.
  - **Hints** (default): current step as a cryptic, in-character hint ("Fasbender said the codes are in the radios…").
  - **Full Guide:** a clear instruction and its map location.
- **SIDE QUESTS:** per map. Examples:
  - Jakub's escape (UPDATE_02);
  - the Cousins' hidden room and chalk drawings (v3);
  - Wren's brother's tag;
  - the phonograph cylinders;
  - the Moon plates (v2);
  - Paul's letter;
  - the Slender's watch-book.

  Use the same spoiler rules.
- **CHALLENGES:** the active rotating challenges with progress bars.
- **INTEL:** the intel found this match (opens the Archive entry).
- **B&S:** this tab shows the planet's main mission (the existing mission tracker), side quests (the original `QUESTS`), gold bolts and memos found, and the planet's challenges. Same layout, B&S skin.

## 5. BOTS WORK ON THE EASTER EGG (the local AI squad-mates)

- **Setting "Bot Easter-Egg Help":**
  - **Off:** bots never touch EE objects.
  - **When Asked** (default): they only do steps you assign them through the Objectives tab, a map mark, or the ping key.
  - **Full Partner:** bots actively work on the EE alongside you, picking up open steps they're able to do and calling out what they're doing.
- **Each EE step in the QuestManager graph gets a `bot_task` definition**, the data that tells a bot how to perform it. Task types:
  - **Collect** (fetch a part or item to a place)
  - **Shoot target** (e.g. bells, the drummer, stick figures)
  - **Hold zone** (pylon holdouts, the Bell Dome during steps)
  - **Carry** (the Antwerpen gyroscope)
  - **Interact sequence** (valves in order, relays, radio tuning)
  - **Kill with weapon X near Y** (Totenglocke kills at the Core)
  - **Escort / defend player** while the player does a step
  - **Turn key** (the two-key abort on Morgenrot: **a bot can be your second key** in solo, matching v2 §4.2 step 10)
- **Steps that stay player-only** (bots defend instead): story choices (Reinholt's fate, Peg's fragment, the Moon re-target confirmation, giving Jakub a gun), anything that starts a cutscene, the Crucible weapon handoff, and the final step's commit.
- **Puzzle knowledge:** bots know **only what the squad has discovered**. If the music-box melody hasn't been heard, they can't do the bell order. Once a step's info is discovered (heard, read, or seen by any squad member), it goes on the blackboard and bots can use it.
- **Making it fun, not automatic:**
  - Bots work one EE task at a time.
  - They announce it ("I'll grab the bell from the Rail Yard. Cover the windows.").
  - They pause EE work when threat is high, a teammate is down, or the round is ending, then resume.
  - In Full Partner mode, the player must still be present for the final steps.
  - Bots never sequence-break or trigger anything that could fail the egg (e.g. a wrong bell order) unless the player ordered it.
- **Voice:** each character gets EE-assist lines in VO_SCRIPT (acknowledge, progress, done, can't-do-that-yet with the reason, interrupted). Jakub can do Collect, Hold, and Carry tasks, and refuses anything involving the Crucible or the perk machines.
- **Debug:** the AI overlay shows each bot's current EE task. The dev console has `ee_bot_assign <step>` and `ee_bot_mode off|ask|full`.

## 6. STARTING-PISTOL UPGRADES (M1911 attachments)

The starting M1911 should stay useful longer and feel like **your** gun. Add an **Armorer's Bench**: a diegetic gunsmith workbench with vise, tools, and a lamp. Place one per Gravelight map near spawn:
- Crossroads Inn: the stable tack room;
- Kaltenbrunn: the gatehouse;
- Morgenrot and Helvetia Works: near spawn.

The bench works on **the M1911 only** (and its upgraded "Last Rites"). In B&S, the Omni-Blaster already has its own mod system, so keep these separate. There are **5 slots**, with one choice per slot. All costs and stats are in `/data/gravelight/weapons/m1911_attachments.tres`.

| Slot | Options (pick one) | Effect | Scrip |
|---|---|---|---|
| **Magazine** | Extended Mag (12 rds) · **Drum Mag** (30 rds, slower reload and ADS) | Capacity | 750 / 1,500 |
| **Barrel** | Match Barrel (+damage, +range) · **Compensator** (−40% recoil, faster follow-up) · Suppressor (quiet: doesn't reveal on the minimap, −10% damage; a period "can," clearly marked as an experimental OSS device in the description) | Handling/stealth | 1,000 each |
| **Sights** | Radium Night Sights (faster ADS, glow in the dark) · Raised Target Sight (+ADS accuracy) | Aim | 600 each |
| **Grip / Stock** | **Detachable Shoulder Stock** (rifle-like stability, ADS sway −60%, a little slower hip draw) · Checkered Grips (+hip-fire accuracy, faster draw) | Stability | 900 / 500 |
| **Ammo** | Hollow-Points (+headshot damage) · **Nachtglas-Tipped** (rounds glow violet, +20% damage, a tiny chance to slow; unlocked after the power is on, it's sold "under the counter") | Damage | 1,200 / 2,000 |

- **Visuals:** every attachment is visible on the gun model (first-person and third-person) with its own sounds. The compensator changes the muzzle flash; the drum is a chunky barrel under the grip; the stock clips on. **Run `tools/ads_check.gd` (UPDATE_02) on every attachment combination** that changes sights or stock, so the sights stay centered.
- **Bench UI:** a small 3D close-up of the pistol in the vise, with the camera orbiting. Pick a slot, see the stat bars change (damage, range, recoil, ADS speed, mobility, capacity), then buy. A **"Gunsmith"** voice line per character.
- **Rules:**
  - Attachments persist for the match on that pistol.
  - If you **Crucible-upgrade** the M1911 into "Last Rites," the attachments stay and each one gets an upgraded version (e.g. the Drum becomes "Rosary Drum," 40 rds; the Compensator adds a muzzle flare that ignites zombies).
  - If you trade the pistol away (to a wall-buy, or by giving it to Jakub), the attachments go with it.
  - Bots can be ordered to the bench via a mark. Jakub refuses the Nachtglas rounds.
- **Meta progression** (ties into v1 Appendix A §A12 weapon mastery): kill milestones with the M1911 unlock **cosmetic** pistol finishes (engraved, nickel, blued, battle-worn, Nachtglas inlay) and one **"Loadout Pick"**: choose one attachment to start every match with already installed. It is cheap and never pay-to-win: Extended Mag or Checkered Grips only.

## 7. TESTS & ACCEPTANCE

- **GUT tests:**
  - MapData bake check (§1) for every map;
  - the order system: assignment, affordability, queue expiry, revive interruption;
  - "buy for teammate";
  - EE `bot_task` execution for each task type, the discovered-info gate, and the never-sequence-break rule;
  - the quest log spoiler filters;
  - attachment pricing, slot exclusivity, carry-over through the Crucible, and transfer with the weapon.
- **Soak test:** Map 0 with 3 bots on "Full Partner": they must progress the Map 0 radio mini-quest steps they're able to do, with zero failed-egg events, in 3 runs.
- **Captures for the morning report:**
  - the minimap on every Gravelight map (and one B&S planet);
  - the pause map with marks on Kaltenbrunn;
  - a bot buying a marked perk;
  - a bot doing a marked EE step;
  - the Objectives tab at each spoiler level;
  - the Armorer's Bench UI;
  - ADS check images for the stock and sight attachments.
- 60 FPS still holds with the minimap and 3 bots + Jakub + 24 zombies.

## 8. FINISH
- Add `PLAY.bat` buttons: "Map 0 — Pause map & marks test", "Kaltenbrunn — Bots Full Partner EE test", "Armorer's Bench test".
- Write the morning report: each section marked works / partly / not started, screenshots and clips, decisions made, and questions for me.
