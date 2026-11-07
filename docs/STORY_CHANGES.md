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

## UPDATE 07 (2026-10-26): Map 4 "Fernflug" (`docs/MAP4_FERNFLUG.md`)
- Morgenrot canon gains one line: after the ABORT, the squad sent the reserve rocket to the Moon (Mondfahrt step 6b run after an Abort). That is the smile and the light. The light was already Darkmatter's relay (RR-7 "Mondlicht", the 1938 probe's uplink).
- The saga's ending: the squad cancels. On Earth the dead stop walking. The Operator's last line is unscripted. Darkmatter records the event as "not a cancellation" (FINEPRINT_LORE's classification stands; the squad never learns that).
- New fictional people: Wittkamp, Riedl, Beck, Jette Maurer, Lionel Hale (the "Hale, L." consignee of Totenhafen), Dolores Marchetti, Calvin Rourke. Sable Vantage attends through a machine and stays unnamed.
- The Allies had their own Nachtglas program (Groom Lake), fed by Peg's samples, Res's 1943 vial, the Morgenrot crate and a second probe (TM-SOL3-002, 11 Aug 1944). Peg's canon choice is to refuse Hale and resign.

## 2026-10-28 (T-126): GRAVELIGHT ONE's pilot lives (the owner: "have a pilot trapped in there that you can give a gun")
- Changed canon (LORE section 9.2 and the 23 Dec 1944 timeline row): old "The pilots died." / "The pilots die." -> new: the co-pilot died; **Flt Lt Harry Selwyn** survived the glide pinned in his seat, his legs caught under the instrument panel. He can't be freed on Map 0; he fights from the cockpit with any gun the squad hands him. Why: the owner's request for a trapped pilot who turns into a turret.
- His fate after Map 0 is **[OPEN]** (he is not carried to Kaltenbrunn). The flight log (`INT_M0_05`) is still his last entry before the crash; nothing in it changes.
- New lines, not changes: `SEL_*` (VO_SCRIPT section 14.15).

## 2026-10-29 (T-135): one more companion per map (the owner: "add an additional NPC on each map like Jakob")
- **Trudi Hanke** (Map 0): after she runs out of the inn in round 1 she hides in the stable; she can join the survivors. (Her fate after the opening was unstated.)
- **Fw. August "Gustl" Ammer** (Kaltenbrunn): alive, locked in the barracks stores by his own sergeant for feeding the labourers; he can join. No insignia anywhere.
- **Hinnerk Petersen** (Totenhafen, NEW character): the old harbour pilot who refused to take the cargo ship out at night, shut in the signal tower. Chosen over Sister Agnieszka, whom Map 4 already sends away with the cargo.
- **Jette Maurer** (Fernflug): alive, locked in the yardmaster's hut for refusing to fly the glider; she goes with the squad through Acts I-III and stays behind at Groom Lake (the rocket seats four). Her logbook egg is unchanged.

## 2026-10-31 (T-136): the savings bank
- **Erwin Lassmann** (NEW character): the junior clerk of the village's Spar- und Darlehenskasse, whose branch is the old woodshed by the west road at the Crossroads. Terrified, polite to the end. He carries the cash box up to Kaltenbrunn and keeps the accounts in the pay office there.

## UPDATE 09: the Marke (2026-11-01, T-137; section 1 "THE MARK")

The dead come from a chip, not only a sickness (CANON section 2.2, LORE section 2.5, contract C1 in `docs/U09_CONTRACTS.md`).

**VO lines checked for a contradiction.** Every record in `data/gravelight/vo/lines.json` (1938 lines) and the whole of
`docs/gravelight/VO_SCRIPT.md` were searched for sickness / virus / plague / infection / infected / disease / contagion /
epidemic / "in the water" / bite / caught / cure. Nothing in the game ever explained the dead as a sickness: the only
hits are two curses ("bright plague", *cholera jasna*), a gun that "bites back", "Spread out", Deacon's "full of poison"
(the Kranich's Nachtglas fuel) and Fasbender's `FAS_M0_FREQ2_01` ("The dead near it... remember. Only one thing.
Hunger."), which is the raw-substrate truth the Marke canon keeps (the mine's Erwachen). **No existing line was
changed.** Deacon's `DEA_SQ7_M0_EGG_LOCK2_01` ("The dead remember. One thing.") stands for the same reason.

**Canon text changed (old -> new, why):**
- Directive LANTERN item 1 (Peg's dossier 10 and the CHARACTERS.md secret): old "recover a viable sample of the
  material designated NACHTGLAS" only -> new: also "Retrieve the tokens: the small implanted pieces reported in enemy
  personnel (right hand or brow), as many as practicable, from the dead. Same container. Do not ask the bearer." Why:
  C1 ("Peg's sealed orders say retrieve the tokens"); London learned of the mark with Res's 1943 sample.
- Deacon's audio diary 2 and Wren's audio diary 2 (dossier level 8): each gains a sentence about the glass in the right
  hand (Deacon will not say the verse into a wire recorder; Wren has checked every right hand on the road and none of
  "ours" has it). Why: the dossiers are where the Archive explains the outbreak; the respect rule in the same breath.
- LORE section 4.1, Abteilung III: old "Tonic formulas, the dispenser program with Helvetia" -> new adds "from June
  1942 the Marken: cutting, implanting, the pay-office readers". Why: the same department, the same people.
- LORE section 3 / TIMELINE.md: new dated rows, no existing date moved: 14 Jun 1942 the first Marken cut (implant order
  14/42); Aug 1942 Major Brueck takes the first one, the garrison recruited under "DIE MARKE, DIE DICH HAELT"; May 1943
  the labour gangs' overseers are offered it and refuse, Jakub in Gallery Nine; 20 Dec 1944 the Erwachen explained as
  both the raw substrate *and* every marked guard who died that night; May 1945 Fernflug Act IV: the key turns on
  RR-7 and every Marke goes dark the same second (MAP4_FERNFLUG section 6.8 gains that sentence).
- CANON section 3 table: the Nachtglas row notes the Marken; a new row "The Marke". Section 8 gains the respect rule.

**New canon, not changes:** Brueck was the first volunteer; Kessler took it; Ammer took it and regrets it; Fasbender
refused in 1942 and Lenz wrote his name in a column; Agnieszka was never marked; Tomasz and the Laboratory Wing's
subjects rose unmarked, from the ore. Far from the mine, everything that rises was marked. The labourers were never
offered it, and nobody in Gallery Nine was asked twice.

**New lines (not changes):** `DUT/PEG/DEA/WRN/JAK_MARKE_FIRST_01`, `*_MARKE_KILL_01..03`, `OPR_MARKE_OPR_01..03`,
`FAS_MARKE_RELAY_01..02` (VO_SCRIPT section 25). **New intel:** `INT_MARKE_ORDER` (Kaltenbrunn, random pool),
`INT_MARKE_POSTER` (the inn's notice wall), `INT_MARKE_MEDIC` (the Totenhafen infirmary's middle cot),
`INT_MARKE_TERMS` (the Moon's reception desk), `INT_MARKE_JAKUB` (the Maintenance Stairs' second landing).

**Respect rule (CANON section 8):** the Marke is never a camp tattoo or a number, never on a forced labourer; it was
sold, to people who had a choice.

## UPDATE 11 "LAZARUS": a grittier origin rooted in history and faith (2026-11-07, T-190; work order §1–§3)

**What changed, in one sentence.** The dead no longer come from an alien company. They come from a sickness kept for a
thousand years in a sealed vessel that travelled with the relics of Lazarus of Bethany (*what death left behind when it
gave him back*), opened on Lazarus Saturday 1930 by a Soviet anti-religious brigade, kept by the NKVD's Laboratory No. 4
("FOURTH DAY"), released by the Red Army in East Prussia in October 1944, and made fast and airborne (STAUB) at
Kaltenbrunn. Darkmatter, Vendelin and the Bolt & Sprocket crossover stay with a smaller job: they explain **only the
technology** (perk machines, the Crucible, the Ledger and Scrip, the Operator, the crate, Nachtglas). Darkmatter did not
make the dead; it **found** them, **packaged** the sickness with its crystal, and **sells** to them. Full bible:
`docs/LAZARUS.md`; summary: `docs/CANON.md` §0.

**Why.** The owner's work order (`docs/work_orders/UPDATE_11_LAZARUS.md` §1): a harder, sadder origin rooted in real
history and real faith, in which the horror is what men did when they broke a seal, and the comedy of a company that
thinks it discovered a market when it walked into a graveyard stands in contrast to it rather than explaining it away.

**Canon text changed (old -> new, why):**
- `docs/CANON.md`: a new **§0 "The Lazarus origin"** ahead of everything. The theme line ("the undead of 1944 Silesia turn
  out to be an alien company's test market") -> the dead come from the sickness; the company came to sell to it. §1.2
  Nachtglas: "dead tissue near it keeps running its last impulse" -> it answers the sickness; a body carrying it rises in
  minutes near the crystal. §2: "Darkmatter is the hidden source of everything in Gravelight" -> of every machine, and
  none of its dead; the Sol-3 bullets gain the 1930 awakening as the reason for the market, the culture (lot LZR-04) in the
  probe, and "The zombies are the ultimate retained customers. That is the horror's origin" -> to Darkmatter they are; it
  did not make them; the origin is §0. §2.2 the Marke gains its November 1944 second reason (protection against the
  Lazarus sickness; actually a tag that makes the marked rise on command). §3 table: the Nachtglas row and a new row for
  the sickness. §6.2: Peg's orders retrieve samples of the sickness and the crystal; Fasbender saw the trains. §8: the
  Lazarus respect rules.
- `docs/gravelight/LORE.md`: §1 a tone bullet; §2 a new opening ("What Nachtglas is not"); §2.4 "the hum, the Nachhall,
  the hunger are the product working as designed ... the Gängers are the ultimate retained customers" -> the substrate
  answering the sickness; Darkmatter found, packaged, sells. §2.5 "The dead do not come from a sickness. They come from a
  chip." -> the dead come from the sickness; the chip makes the marked rise on command; the poster's second line. §3
  timeline: new rows for AD 33, 890/898, 1453, 12 Apr 1930, Apr 1930, Oct 1934, 16–30 Oct 1944, Nov 1944, 1953; the 1938
  row now carries the culture and the rising at 01:12 on 13 Nov (the Fine Print Ch. 2's own night; it said "that night
  [the 11th]"); Reinholt's Lazarusblut (Jun 1939); the Erwachen row gains the STAUB release. §9.2 the crash crosses the
  front; Map 0's dead include the Soviet risen; Fasbender says what the Russians did first; Totenhafen's coffins hold
  Lazarusblut and STAUB. §13 a pointer to the Lazarus Archive. §14 glossary rows.
- `docs/TIMELINE.md`: rewritten with the Lazarus rows (AD 33, 890/898, 1453, 1930, 1934, 1938 (the culture; the 13 Nov
  rising), 1939, Oct 1944, Nov 1944, 20 Dec 1944, 23 Dec 1944, 1953); existing rows kept, three amended (9 Nov 1938, 11 Nov
  1938 -> 11–13 Nov, Jan 1945, May 1945).
- `docs/gravelight/CHARACTERS.md` (prose only): Peg's secret and dossier 10 item 1 (samples of the sickness and the
  crystal; amendment of 16 Nov 1944); Dutch's secret (the letter unchanged, what he hears in it); Deacon's voice notes and
  stake (the quiet theological voice, no sermons, "the debt"); Wren's bio (she knows the NKVD); Fasbender's profile (the
  trains); new voice profiles for Father Serafim (`SER`) and Volkov (`VOL`). No ID table changed.
- `docs/FINEPRINT_LORE.md`: §1.5 property 2 gains the sickness; §2.1 a reason 0 (the 1930 awakening as "a natural
  retention phenomenon", why Darkmatter came at all); §2.3 the returned-inventory culture, lot LZR-04; §2.5 the results
  line stands, with what it does not say; §4.2 "The dead walk because the product works" -> because of the sickness; the
  product answers it. The Fine Print keeps its chapters; its lines change only where they say Darkmatter created the dead
  (T-199).
- `docs/MAP3_MORGENROT.md` §1: the warheads carry STAUB; cities and egg unchanged; aimed east first, now at everyone.
- `docs/MAP4_FERNFLUG.md` §0, §1.1, §1.2, §6.8, §11.5, §12.11: the Kranich's casings carry STAUB; Groom Lake's programme on
  the samples Peg's orders bought; the relay keeps the sickness awake worldwide and the marked obedient; CANCEL makes the
  dust go dark and the dead lie down (mechanics unchanged); the **Moscow, 1953** epilogue card (`cards.m4.moscow53`,
  three cards, last, canon ending only).
- `docs/U10_TOTENHAFEN_DESIGN.md` §1: the coffins hold Lazarusblut and STAUB; Brecht saw the wagons; Lenz's refusal.

**New canon, not changes** (`docs/LAZARUS.md`): the vessel and the brotherhood of the lamp; Chetverodnevo, Staryi Brod,
Father Serafim Lebedev, Arkady Volkov, Matvei Grach, Avdotya Pakhomova; Lazarus Saturday 12 April 1930 (30 March O.S.)
beat by beat; the fourth-day calendar; the typhus cordon; Laboratory No. 4 and its six rules; the order of last resort;
Darkmatter's "natural retention phenomenon" and lot LZR-04; Pilch's fourth day counted from the glass room; Lazarusblut;
the Returned; STAUB; the Marke's second poster line; the Erwachen as the first STAUB release; the trains; the Lazarus
Archive (`data/gravelight/archive_lazarus.json`: Serafim's diary, one page per map, the last on the Moon; the Laboratory
No. 4 files; the front report; the STAUB memos; Hale's order) and the diary read-alouds `SER_DIARY_<MAP>_01` (VO_SCRIPT
§27).

**Checked and left alone.** `data/gravelight/intel.json`, `dossiers.json` (regenerated from the docs above),
`machine_lore.json`, `perk_lore.json`, `citations.json`, `story_props.json`: searched for the dead's origin (Darkmatter,
retention, retained, origin, rise, substrate). Every hit is Darkmatter's own product language on its own documents (the
relay's plate, the cabinets' plates, the fine-print panels, the Terms of the Mark), which is still true in the company's
mouth; nothing in them says Darkmatter made the dead, so no id, count or gameplay fact moved. Quest files untouched (the
egg guard). `docs/BRIEF.md` is the original brief and is left as history; `docs/gravelight/ENEMIES.md` (the Helvetia
Works dead "retained by substrate leaking from the barge") is T-192's and reads correctly under the new canon (the dust
was already in Basel's air). Not changed: every voice line (T-191, T-195–T-199 rewrite them from these docs).

**Respect rules (CANON §8, LAZARUS §10):** faith is never the villain; the miracle is never mocked, faked or called a
disease (the sickness is the debt, not the gift); no real person is a villain or a victim by name; no real atrocity site
or real secret laboratory is ours; Soviet and German soldiers are people; camp prisoners and forced labourers are never
zombies and never spectacle; Jakub unchanged.

