# GRAVELIGHT — Canon Sheet (single source of truth for names & IDs)

> **Partly superseded (§11):** the formulator names and "Imhof founded Helvetia" lines are replaced by `docs/CANON.md` §4 and `docs/M0_SHARED_FACTS.md` (Imhof & Cie. 1921, re-founded by Vendelin in 1940). Every other name here stands.


Every doc and every data file uses the names and IDs below. If a doc disagrees with this sheet, this sheet wins. Change it here first, then update the other docs.

## Conventions
- **IDs:** `snake_case` in data and code (`ironhide_stout`, `ganger`). Display names live in data.
- **VO line IDs:** `{SPK}_{CAT}_{NNN}`, e.g. `DUT_PERK_IRONHIDE_01`, `OPR_PWR_RESUPPLY_02`.
  - Speakers: `DUT` Dutch, `PEG` Peg, `DEA` Deacon, `WRN` Wren, `OPR` The Operator, `FAS` Fasbender, `REI` Reinholt, `LSL` Liesl (only on recordings), `NPC` misc.
- **Zones (Map 1):** `A_MINEHEAD`, `B_RAILYARD`, `C_ADMIN`, `D_BARRACKS`, `E_LIFT`, `F_CHAPEL`, `G_GENERATOR`, `H_LAB`, `I_CORE`.
- **Zones (Map 0):** `TAPROOM`, `UPSTAIRS`, `STABLE`.
- **Greybox colors:** green = buyable, blue = door, red = window/barricade, yellow = perk, purple = quest, orange = trap, white = structure.

## People
| ID | Name | Notes |
|---|---|---|
| `dutch` | Sgt. Walter "Dutch" Kowalczyk | US Army Ranger, 34. Grandmother: **Halina Kowalczyk ("Babcia")**, emigrated 1891 from **Wilcza Góra**, a village 6 km from Kaltenbrunn. |
| `peg` | Lt. Margaret "Peg" Ashworth | SOE, 29. Sealed orders: **Directive LANTERN** (retrieve a Nachtglas sample at any cost, then destroy the facility). Her contact is "Mr. Hale" in London. |
| `deacon` | Cpl. Elijah "Deacon" Brooks | 761st Tank Bn mechanic, 26. From Opelousas, Louisiana. Writes letters to his younger sister **Ruthie**. Names machines. |
| `wren` | Zofia "Wren" Nowak | Home Army sniper, 24. Brother **Tomasz Nowak**, forced laborer ID tag **KB-4471**, taken 1942. Keeps a kill tally in a notebook. |
| `fasbender` | Dr. Emil Fasbender | Resonance physicist. Contact name to the Allies: **"Glasmacher"**. |
| `reinholt` | Dr. Augusta Reinholt | Lead of Projekt Wiederkehr. Daughter **Liesl Reinholt** (b. 1932, d. Feb 1939, diphtheria). |
| `operator` | The Operator | The Ledger's voice. A sampled 1930s radio announcer, **"Your Friend at the Ledger."** |
| `agnieszka` | Sister Agnieszka Wróbel | Forced-labor nurse who made Second Wind Schnapps. Nursed Tomasz. Fate: unknown (Map 2 hook). |
| `kessler` | Otto Kessler | Bavarian brewmaster, made Ironhide Stout palatable. |
| `foreman` | Obersteiger Gustav Mahlknecht | Mine overseer → **The Foreman**. |
| `screamer` | Schwester Ilse Brandauer | Field nurse → **The Screamer**. |
| `imhof` | Konrad Imhof | Director of **Helvetia Automaten AG**, Basel. |
| `herr_tamtam` | **Herr Tamtam** | Liesl's wind-up tin drummer. |

## Places & things
- **Nachtglas:** black glassy mineral with violet-amber veins. Found 1938 in the Kaltenbrunn salt mine (an ancient meteorite strike buried in the salt).
- **The Ledger:** the relay computer in the Core Vault ante-room. German staff call it **"das Hauptbuch."**
- **Scrip:** Ledger tokens. HUD symbol: a stamped tally mark `ǂ`, written as "ǂ1500" or "1500 Scrip".
- **The Crucible:** upgrade forge in the Core Vault.
- **Lost Requisition Crate:** the Mystery Crate. Cost 950.
- **Operation Gravelight:** the C-47 is callsign **GRAVELIGHT ONE** and was brought down on 23 Dec 1944.
- **Fasbender's radio callsign:** "Glasmacher calling Gravelight."
- **The Bell:** the Salt Chapel's resonance alarm bell, **"die Totenglocke"** (the weapon is named after it).

## Enemies (IDs)
`ganger`, `ganger_crawler` (a state, not a type), `glasshide`, `bellringer`, `foreman`, `screamer`.

## Perks (IDs → display, cost)
| ID | Name | Cost | Color |
|---|---|---|---|
| `ironhide_stout` | Ironhide Stout | 2500 | iron-red |
| `second_wind` | Second Wind Schnapps | 500 solo / 1500 co-op | pale blue |
| `trigger_tonic` | Trigger Tonic | 3000 | lime-gold |
| `twin_barrel` | Twin Barrel Bitters | 2000 | amber |
| `marathon_malt` | Marathon Malt | 2000 | sky/white |
| `hawkeye_brandy` | Hawkeye Brandy | 1500 | deep green |
| `packmule_porter` | Packmule Porter | 4000 | brown/olive |
| `blastproof_bock` | Blastproof Bock | 2000 | orange/black |

## Power-ups (IDs)
`resupply`, `deaths_door`, `double_scrip`, `blackout`, `fortify`, `clearance`.

## Weapons (IDs → upgraded name)
| ID | Weapon | Source | Upgraded name | Bonus property |
|---|---|---|---|---|
| `m1911` | M1911 | start | **Last Rites** | rounds ricochet once |
| `trench_knife` | Trench Knife | start | (none) | |
| `etool` | Sharpened E-Tool | wall 3000 | (none) | melee upgrade |
| `frag` | Mk 2 Frag | start/wall 250 | (none) | |
| `kar98k` | Kar98k | wall 200 | **Final Verdict** | penetrates 4 targets |
| `m1_garand` | M1 Garand | wall 600 | **Eight-Ping Benediction** | rifle-grenade attachment |
| `gewehr43` | Gewehr 43 | wall 900 | **Stille Nacht** | headshot kills don't break stealth aggro + 2× head mult |
| `m1_carbine` | M1 Carbine | wall 600 | **Reveille** | full-auto selector |
| `mp40` | MP40 | wall 1000 | **Grabesgesang** | +damage, faster reload |
| `thompson` | Thompson M1A1 | wall 1200 | **Chicago Lament** | bigger mag, armor-piercing |
| `stg44` | STG-44 | wall 1200 | **Sturmwind** | burst mode, bigger mag |
| `trench_gun` | Trench Gun (M1897) | wall 1500 | **Gravedigger's Due** | incendiary pellets |
| `bar` | BAR | wall 1800 | **Ironmonger** | bigger mag, stagger |
| `ppsh41` | PPSh-41 | crate | **Red Winter** | frost slow on hit |
| `mg42` | MG42 | crate | **Bone Saw** | bigger belt |
| `m1919` | Browning M1919 | crate | **The Long Amen** | no overheat, penetration |
| `sawed_off` | Double-Barrel Sawed-Off | crate | **Twin Coffins** | four-barrel volley |
| `type100` | Type 100 | crate | **Hollow Blossom** | hollow-point: +limb damage, crawler chance up |
| `fg42` | FG 42 | crate (T-248) | **Sturzflug** | hits stagger |
| `mosin_nagant` | Mosin-Nagant M91/30 | crate (T-248) | **Second Opinion** | rounds ricochet twice |
| `bren` | Bren Mk II | crate (T-248) | **Last Orders** | armor-piercing, bigger magazine |
| `sten` | Sten Mk II | crate (T-248) | **Cheap Funeral** | incendiary rounds, bigger magazine |
| `ptrs41` | PTRS-41 | crate | **Bear Tax** | penetrates everything, armor-ignore |
| `springfield` | Springfield M1903 (scoped) | crate | **Long Goodbye** | headshot kills burst in a Nachtglas pop |
| `panzerschreck` | Panzerschreck | crate | **Stovepipe Sermon** | cluster bomblets |
| `flamethrower` | M2 Flamethrower | crate | **Furnace Warrant** | longer reach, burning ground |
| `gramophone` | Siren Gramophone | crate (tactical) | (none) | |
| `ashlight` | Ashlight | crate (low weight) | **Ashlight Corona** | bolts chain to 3 targets |
| `totenglocke` | Totenglocke | Map 1 buildable | **Totenglocke: Mitternacht** | larger cone, more charges |

## Songs (original)
- **"Come Along, Little Soldier"** (*Komm mit, kleiner Soldat*): the Siren Gramophone record.
- **"Lanterns Down Below"**: the Map 1 hidden song (side Easter egg, 3 phonograph cylinders).

## Map 0 radio quest
Three frequencies on notes: **3.120**, **5.785**, **7.440** (Mc/s). Tune in that order.

## Additions (merged from the M0 doc pass)
- **Gasthaus Zum Kreuzweg:** the Map 0 inn, kept by **Anselm Vogt**.
- **"der Sarg"** ("the coffin"): the miners' name for the Map 1 lift.
- **Hattie:** Deacon's name for the Generator Hall turbine.
- **Strzyżyk** ("wren"): Wren's Home Army codename. **czarna sól** ("black salt"): the locals' word for Nachtglas.
- Dutch: **Polish Hill**, Pittsburgh. Deacon: father **Rev. Josiah Brooks**, **Mount Moriah Baptist Church**, **Uncle Clement**. Peg: **Ashworth Hall**, Wiltshire.
- Wren's notebook tally stands at **61** when Map 0 begins.
- Reinholt specimen log **entry 211** (Tomasz Nowak).
- **Quest IDs:** `map00_radio`, `map01_requiem`, `map01_song`, `map01_wren_tag`. **Quest items:** `overseers_key`, `music_box`, `nachtglas_shard`. **Flag:** `map00_complete`.
- **VO prefixes:** `CUT_REQ_*` (ending cutscene), `LSL_REC_*` (Liesl recordings), `BNT_*` (banter).
- **Map 2:** "Kielholer" (drowned sailors), the "Ballast" carry mechanic. **Map 3:** the "Echoes" mechanic and the Mirror Room.
- **Perk mascots:** Fassl (Ironhide barrel), Flitzi (Trigger Tonic hare), Feldwebel Pomp (Twin Barrel sergeant), Esel Ede (Packmule mule), Kaboomer (Blastproof ram).
- **Formula makers:** Otto Kessler of Freising (Ironhide), Maj. Rüdiger Strohwald (Twin Barrel), Dr. Hanne Ostrowski (Marathon), Freiherr Leopold von Aschau (Hawkeye). Blastproof came from the Pionierschule, Dessau-Roßlau.
- **Helvetia motto:** "Ein Griff, ein Genuss." **Operator sign-on:** "Your Friend at the Ledger", station ID **"Sender Kaltenbrunn"**.
- **Reinholt's "Subject 740".** Pylon tones D / F / A (a D-minor chord). Map 1 radio code colors: red, blue, white. Map 0 frequency notes: 6 possible spots, 3 used per match.
- **Meta camo:** "Nachtglas Absolute". **Buildable IDs:** `tg_part_bell`, `tg_part_frame`, `tg_part_crank`, `tg_workbench`.
- **Lore (from LORE.md):**
  - **The Operator's source voice:** Lionel Marchbank ("Uncle Lionel"), host of the propaganda show *"Calling the Home Front"*. The Ledger's engineer: Hans Opitz.
  - **Organizations:** the Amt für Sonderforschung and Abteilungen I–III. Dr. Kurt Venner (Abt. III). Garrison: Maj. Dietrich Lenz.
  - **GRAVELIGHT ONE:** pilot Flt Lt Harry Selwyn, out of Brindisi.
  - **Miners:** Jan Pilch, Bruno Hasse. The ore locomotive **"Bertha"**.
  - **Events:** the **Gallery Seven Flood** (June 1943, **187 dead**); **the Erwachen** (20 Dec 1944).
  - **Terms:** the Nursery; the Nachhall-Hypothese; the Verglaste; the Stimmversuch.
  - **Herr Tamtam's cadence:** "tam-tam, ta-ta-tam". **Map 3 endings:** Silence, LANTERN, Return (hidden).
