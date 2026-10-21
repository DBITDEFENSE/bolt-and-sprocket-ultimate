# Story changes log

Every change to an **existing** line from the original web build is logged here as old → new + why. New lines are listed separately, because they don't change canon text but do add to it. Nothing is ever dropped silently.

**How changes are applied:**
- Edits live in `data/bs/story/additions.json` → `story_edits`.
- `tools/port_story.mjs` applies them, and refuses if the "old" text doesn't match the source exactly.
- The untouched originals stay in `data/bs_source/` and `reference/bs_web/index.html`.

`HUMOR-REVIEW.md` content is **not wired** until it's approved at the M0 review (see the yes/no list in the M0 summary).

---

## 1. Edits to existing lines

| Line ID | Old | New | Why |
|---|---|---|---|
| `cs.galleriaLedger.02` (Bolt) | "Then we keep it. If Grindstone ever tries that clause **again**, we'll have the receipts — every unit he tried to erase." | "Then we keep it. If Grindstone ever tries that clause **on you**, we'll have the receipts — every unit he tried to erase." | Continuity. The Galleria is played during the core hunt (`CAMPAIGN`, `planetLocked()`), *before* the Foundry's Clause 44 scene, so "again" referred to an event that hadn't happened yet. "On you" turns it into foreshadowing. DECISIONS T-005. |

### Gravelight lines (docs/gravelight, §11)
| Line ID | Old | New | Why |
|---|---|---|---|
| `REI_CYL1_01` (Reinholt) | "...the eleventh of **October** 1938..." | "...the eleventh of **December** 1938..." | The recording predated the locked probe landing (9 Nov 1938). |
| LORE §3 timeline | Gallery 7 deaths Mar 1938; Amt seizure Sep 1938; Helvetia founded 1921 by Imhof; "the Operator speaks" Mar 1942 | 11 Nov 1938; 2 Mar 1939; Imhof & Cie. 1921, re-founded as Helvetia by Vendelin Feb 1940; Opitz's splice-reader from Mar 1942, the Operator proper from 14 Sep 1944 | All the old dates fell before the landing, or contradicted the brief's Ch. 3 Ledger beat. |
| LORE §8.1 formulators | Venner, Strohwald, Ostrowski, von Aschau, Dessau-Roßlau | The §10.2 humans (Kessler, Agnieszka, Vogt, Brück, Grosi Gähwiler, Sowa, Ammer, Lehrkommando Kaltenbrunn). Strohwald, Ostrowski and von Aschau stay in new roles; Venner stays head of Abteilung III | Brief §11.3. |
| LORE §6.2 | "Fasbender designed the Crucible" | "Fasbender signed drawings that arrived finished in 1944" | The Crucible is Blartz's confiscated Forge (§10.3). |

## 2. Structural changes (no text changed)

| What | Old | New | Why |
|---|---|---|---|
| Quest IDs | `q6a`/`q6b` used by both the Grand Galleria and Verdant Sink quests; `q3b` used twice on Core Foundry (planet index 2) | Galleria `q9a`/`q9b`, Verdant `q7a`/`q7b`, "Art Criticism" `q3c`. The original ID is kept as `source_id` | Duplicate IDs made saved quest progress collide between quests. DECISIONS T-004. |

## 3. New lines (additions to canon, nothing replaced)

**Bolt & Sprocket** (`data/bs/story/additions.json`):

| ID | Who | What | Brief |
|---|---|---|---|
| `memo.36`–`memo.40` | memo | The five hidden Darkmatter memos: Sol-3; the confiscated Forge schematic; "Nobody Cancels"; Next-Era Delivery invoices; "the vending robot that never reported back" / Clause 0 | §5.4, §10.3 |
| `bs.boss.retention.dm.01` | The Retention Specialist | "Nobody cancels. I learned that from the best." | §5.4 |
| `bs.galleria.toniq.01–03` | Sprocket, Bolt | The derelict TONIQ™ Vitality Dispenser interaction | §5.4 |
| `bs.foundry.forge.01–04` | Blartz, Sprocket | Omega Forge opening: seized schematics, "rebuilt from memory, which is better than the original, which was also perfect" | §5.1 |
| `bs.foundry.holding.01–03` | Blartz, Bolt | Short Holding Block scene showing the confiscation and the patent number BLZ-40417 | §10.3.2 |

**GRAVELIGHT Map 0 fixed story items** (`docs/gravelight/LORE.md` §13.1, `INT_M0_09`–`INT_M0_14`; placements in `data/gravelight/story_props.json`, spawned by `StoryProp.spawn_all`, read in the `StoryReader`). Six hand-placed readables on the Crossroads Inn, always in the same place, filed in the Intel Archive on first read. Nothing replaced; the canon they add:

| ID | Item | Canon added |
|---|---|---|
| `INT_M0_09` | The Kreuzweg Guest Book (bar side counter) | The Vogts' daughter is **Käthe** (about nine in 1944; the third name on the 1937 photograph `INT_M0_06`). Res and Vendelin stopped at the inn on **3 Mar 1944** with the Crucible's "Kühlanlage" crate. A six-man **signals section** was quartered in the taproom from 28 Nov 1944 and sent down the Kaltenbrunn road on 21 Dec (not back). Two Abteilung II men had leave in Rooms 2 and 3, 17–20 Dec, recalled for "the attempt". Her last line, "four guests from the sky", means something on the wireless knew GRAVELIGHT ONE was coming; **whose voice it is stays [OPEN]**, as does the Vogts' fate (the book stops on 22 Dec). |
| `INT_M0_10` | Wireless Log, Signals Section (NE taproom table) | **The Erwachen reached the inn at 23:02 on 20 Dec**: one carrier on every band, a hum, lamps burning violet, every watch in the section stopped. Next morning the Operator greeted them with "this fine twentieth of December" (§7.3). The set left on the landlord's bar is the signals section's. |
| `INT_M0_11` | Käthe's Drawing (upstairs hall, top of the stairs) | Käthe hears a child's voice on the wireless and sings back; she drew the drummer on the back of Frequency Card (Grey) (`INT_M0_03`). Her radio girl has a drum and a paper hat (compare `INT_M1_16`), never a name. |
| `INT_M0_12` | Unsent Letter, Room 3 (on the bed) | **Josef Brenner**, Abteilung II relay technician (wife Hedwig, Liegnitz): the hum felt nine kilometres away, Opitz talking to the relays, the recall for the twentieth. Their escort's MP40 is the upstairs wall-buy (MAPS.md). |
| `INT_M0_13` | Helvetia Delivery Docket (cellar, north pillar) | **Why eight Helvetia machines are in the inn's cellar:** Abteilung III's replacement units, delivered 9 Oct 1944 for interim storage at the last stop on the salt road, fitted by Vendelin, driven by A. Gähwiler, storage paid to A. Vogt. Their coin mechanisms tally to the works over a line Opitz arranged (§7.1). "Cabinet 2: please do not disconnect. V." |
| `INT_M0_14` | Framed Clipping: "A Hundred Years at the Crossroads" (taproom south wall) | The inn opened in **1836**. **Bruno Hasse** drank at the inn on Tue 8 Nov 1938, the night before the tremor; a Wilcza Góra milk girl saw him on the salt road the night his body left the mortuary shed (Nov 1938 cutting: Jan Pilch and Bruno Hasse, "bodies taken from mine mortuary"). |

**Other new content** lives in its own files:
- The Fine Print: `FINEPRINT_SCRIPT.md`, `fp.*` IDs
- Jingles and back panels: `JINGLES.md`
- Gravelight §11 additions: `gravelight/*.md`, `gl.*` and `op.slip.*` IDs
- New boss title cards and the 4 new ad vignettes: `BS_ENEMIES.md`, `BS_WEAPONS.md`, `bs.*` IDs

## M3 (builders A–D, logged at the M3 WIP pause)
- `bs.weapon.middleman.argue.01` was two speakers in one line; it's split into `.01` (middleman_a) and `.01b` (middleman_b). Nothing cut.
- `code.buildLevel2.07` and `.09` (Rustvane hints) are no longer used. Their text no longer matched the remade spots. They're replaced by `bs.rustvane.hint_mine` and `bs.rustvane.hint_roost`.
- `code.populateLife.16` (Nova Plaza squatter): now said when you interact with the vending machine by his bench, instead of being dropped. `.15` stays his idle line.
- The Content Creator's DEMONETIZED banner subtitle now reads "The Content Creator sheds its armor!" (`bs.boss.cc.banner.demonetized.02`).
- New content, not changes: the "NO JUMPING ON THE LAWN" HOA rule (Nova Plaza clubhouse puzzle); `bs.forge.*`, `bs.rustvane.*`, `bs.gadget.tether.*`, `bs.nova.*` (120 lines), `bs.boss.*` and `bs.enemy.*` lines.
