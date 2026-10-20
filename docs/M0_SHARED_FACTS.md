# M0 shared facts (locked)

Every M0 document uses these facts verbatim, so the docs agree with each other. `CANON.md` is the full bible, and this sheet is its quick-reference spine. Change a fact here first, then in every doc that uses it.

## Sources of truth
- **Brief:** `docs/BRIEF.md`. Its §11 overrides Appendix A.
- **Original B&S data:**
  - `data/bs_source/*.json`: raw tables extracted from the web build v14 by `tools/extract_bs.mjs`.
  - `data/bs/story/*.json`: every written line, with stable VO line IDs (`tools/port_story.mjs`).
  - `data/bs/story/lines_index.json`: ID → {who, text}.
- **Original source code:** `reference/bs_web/index.html` (18,100 lines). Read it only in targeted chunks (grep for a function name, then read about 200 lines). Never read it whole.
- **Gravelight design:** `docs/gravelight/*.md`, copied from the working GRAVELIGHT Godot project at `C:\Users\Devin\PROJECTS\New folder`. Milestones M0–M6 of that project are built and playable. These docs are canon for Gravelight, amended by brief §11.
- **Original folder:** `C:\Users\Devin\PROJECTS\bolt-and-sprocket\` is READ-ONLY. Never touch it.

## Names, numbers, IDs
- **Game title constant:** `GAME_TITLE = "TERMS & CONDITIONS"`.
- **Darkmatter Subscriptions LLC:** Umbral Galaxy. Motto **"NOBODY CANCELS."** Brand color violet `#c07dff` with amber cracks `#ffb347`. Speaker id `darkmatter`.
- **DARK-GLASS™** is what Earth calls **Nachtglas**.
- **Patent number:** Blartz's Omega Forge patent and the PATENT PENDING gun's serial are both **BLZ-40417**. The Crucible plaque reads **"MOD. R-E · PAT. PEND. BLZ-40417"**.
- **Sol-3 probe:** Darkmatter test-market probe **TM-SOL3-001**. It landed in the Kaltenbrunn salt mine on **9 November 1938**, and everyone took it for a meteorite.
- **Vendelin:** Field Merchandiser Unit **V-1**, serial **DMS-FMU-V1-0001**. Directive **"DISTRIBUTE. RETAIN. REPORT."** Human cover **"Herr Viktor Vendelin, Ingenieur, Basel."** Founded **Helvetia Automaten AG** in Basel in **1940**.
- **Clause 0:** "Field units are inventory." It is the Darkmatter mirror of OmniScrap's **Clause 44** (remote decommission).
- **Vendelin's last transmission:** **18 March 1945, 03:12, Basel**. Sprocket finds it in Ch. 1.
- **Sable Vantage:** VP of Emerging Markets. In Gravelight she is only ever "the Woman in Violet," heard in Reinholt's recordings.
- **Res Gähwiler:** delivery driver from Grindelwald (Bernese Oberland). His cousin **Anni Gähwiler** is the SOE's Basel contact.
- **The Underwriter:** risk-assessment enforcer and the main boss of The Fine Print.
- **The Board:** a conference call of distorted voices, never shown. It says "Initiate acquisition."

### Vitality Plan IDs (stenciled under each machine's paint)
| Machine | Gravelight id | Plan | ID |
|---|---|---|---|
| Ironhide Stout | ironhide_stout | DURABILITY+ | DMS-VP-DUR-01 |
| Second Wind Schnapps | second_wind | CONTINUITY (Free Trial) | DMS-VP-CON-00 |
| Trigger Tonic | trigger_tonic | THROUGHPUT | DMS-VP-THR-02 |
| Twin Barrel Bitters | twin_barrel | VELOCITY | DMS-VP-VEL-03 |
| Marathon Malt | marathon_malt | MOBILITY | DMS-VP-MOB-04 |
| Hawkeye Brandy | hawkeye_brandy | FOCUS | DMS-VP-FOC-05 |
| Packmule Porter | packmule_porter | CAPACITY | DMS-VP-CAP-06 |
| Blastproof Bock | blastproof_bock | LIABILITY WAIVER | DMS-VP-LIA-07 |
| Fine Print Fernet (new) | fine_print_fernet | DISCLOSURE (unreleased) | DMS-VP-DIS-X1 |
| Overclock Cordial (new) | overclock_cordial | SURGE (unreleased) | DMS-VP-SRG-X2 |

## Timeline anchors
- **9 Nov 1938:** the probe lands. V-1 survives. The first retained miner rises (Ch. 2).
- **1940:** Helvetia Automaten AG is founded.
- **1941–44:** Reich contracts, Projekt Wiederkehr, the formula-makers (Ch. 3).
- **23 Dec 1944:** Gravelight One crashes. Map 0 takes place that night; Map 1 follows over the next days.
- **Helvetia Works / "The Return Trip"** (resolves a brief conflict, see DECISIONS.md):
  - At the Map 1 ending, the collapsing Nachtglas heart opens a fold.
  - The squad steps out of it in **Basel on the night of 17–18 March 1945**, which is Ch. 5.
  - When Vendelin cuts Darkmatter's fold at the finale, it "returns them to sender" in **late December 1944**.
  - To the squad it is one impossible night they later remember as a fever dream. Map 2 Totenhafen (Jan 1945) and Map 3 Morgenrot (Mar 1945) follow as written.
  - Bolt & Sprocket arrive from the far future through Blartz's misfired delivery pad (Ch. 4 ending).
- **Far future (B&S era):** the B&S campaign → post-credits → The Fine Print Ch. 1 and Ch. 4 → the rift.

## Locked story fixes
- **Galleria continuity:** the Grand Galleria stays playable during the core hunt (`CAMPAIGN = [0,1,5,6,7,9,2]`, `planetLocked()`). Line `cs.galleriaLedger.02` changes "If Grindstone ever tries that clause **again**" → "If Grindstone ever tries that clause **on you**", which foreshadows Clause 44 in the Foundry instead of contradicting it.
- **Duplicate quest IDs** in the web build get unique remake IDs: Galleria `q6a/q6b` → `q9a/q9b`, Verdant corn `q6a/q6b` → `q7a/q7b`, and the second Core Foundry `q3b` "Art Criticism" → `q3c`. The original ID is kept as `source_id`.

## VO line ID prefixes for new content
| Content | Prefix |
|---|---|
| The Fine Print | `fp.c<chapter>.<scene>.<nn>`, e.g. `fp.c3.ironhide.04` |
| Jingles and back-of-machine panels | `jingle.<perk_id>.<nn>`, `panel.<perk_id>` |
| Operator corporate slips | `op.slip.<nn>` |
| New Gravelight lines | `gl.<map>.<speaker>.<topic>.<nn>` |
| Bolt / Vendelin first-person quote packs | `gl.qp.bolt.<topic>.<nn>`, `gl.qp.vendelin.<topic>.<nn>` |
| New B&S lines | `bs.<planet or system>.<topic>.<nn>`, e.g. `bs.memo.36` for the new memos 36–40 |

## Working rules for every writer
- Everything must be original. No names, assets or lore from Ratchet & Clank, Call of Duty or any other commercial game. Real WW2 firearms are fine.
- No placeholders and no "TBD" in story or design docs.
- Never silently drop or change an original line. Any change goes in your report as **old → new + why**, so it can be logged in `docs/STORY_CHANGES.md`.
- Do not run Godot or any program that opens a window. The user is playing a fullscreen game on this PC. File reading and writing only.
- Write only the files you were assigned. Do not git commit; the lead commits.
