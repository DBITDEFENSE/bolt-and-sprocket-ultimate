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

**Other new content** lives in its own files:
- The Fine Print: `FINEPRINT_SCRIPT.md`, `fp.*` IDs
- Jingles and back panels: `JINGLES.md`
- Gravelight §11 additions: `gravelight/*.md`, `gl.*` and `op.slip.*` IDs
- New boss title cards and the 4 new ad vignettes: `BS_ENEMIES.md`, `BS_WEAPONS.md`, `bs.*` IDs
