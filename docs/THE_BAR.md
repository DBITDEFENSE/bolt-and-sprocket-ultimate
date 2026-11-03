# THE BAR: the scorecard that makes "better than Maps 1–2" measurable (UPDATE 10 §1)

Written 2026-11-01 from the state of `master` at commit 9ceeb41 (UPDATE 09 merged, UPDATE 10 not started). The
scores are a baseline: §1.3's target is checked against this file at FINISH and the blind review (§1.4) is recorded
in section 6. Every cell carries its evidence so a second reviewer can re-derive it (section 5 says how).

**Re-scored at FINISH on 2026-11-02 (T-168):** the second table is section 1.1b, its evidence section 1.2b, the
"only here" features as built section 2.1 and the after-table with the rows sent back section 3.3. The baseline
table and its evidence are kept unchanged above them.

Names by play order, as the work order uses them: **Map 1** = Crossroads Inn (`map00`), **Map 2** = Kaltenbrunn
(`map01`), **Map 3** = Totenhafen (`map02`), **Map 4** = Fernflug, scored per act: **I** Werk Thalbach (`map04a`),
**II** der Kranich (`map04b`), **III** Groom Lake (`map04c`), **IV** Mondlicht (`map04d`).

## 0. How the scores were made

- **0** none · **1** placeholder (exists in name, or works but is a stub, or is unmeasured) · **2** good (a real,
  working version that is not what you remember the map by) · **3** memorable (the thing you tell someone about).
- Unmeasured is scored **1**, never guessed up: a boss that no soak has reached, a round economy no run has
  measured, a quest whose voice lines are silence with subtitles.
- Evidence is a file path, a capture name or a soak/QA number. Captures are the U09 §5 sets in
  `morning/screenshots/u09_before/<set>/` and `u09_after/<set>/` (git-ignored, on the owner's PC; the "after" set
  is the one scored unless `before` is said). They are Compatibility-renderer software-GL frames (no volumetrics,
  SSR or GI), so "dark" is read as "unlit in Compatibility", and the same caveat applies to the re-score.
- Soaks: `logs/ai_runs/*.md|csv` (git-ignored), `docs/QA_REPORT_U07.md` §6–7, `docs/QA_REPORT_U08.md`.
  Draw-call figures are the `census_map` peaks in `docs/DECISIONS.md` T-145..T-149 (not `docs/PERFORMANCE.md`'s
  spawn-view numbers, which are a different measure).
- Rows 1–18 are the work order's seed rows with their numbering. Rows 19–28 are the other things found in code and
  docs that make the Inn or Kaltenbrunn feel great and that differ per map. Systems that are identical on every map
  are listed in section 1.3 and not scored (they would add the same number to every column).
- Shorthand in the evidence cells: `T-0NN` = a `docs/DECISIONS.md` paragraph; `QA_U07`/`QA_U08` = the QA reports;
  `MAPS.md` = `docs/gravelight/MAPS.md`; `MAP4` = `docs/MAP4_FERNFLUG.md`; a bare capture name such as
  `10_D_hero` is in that map's `u09_after` set; `r` = round, act rounds for the acts.

## 1. The scorecard

### 1.1 Scores and totals

| # | Feature | M1 Inn | M2 Kalt. | M3 Toten. | Act I | Act II | Act III | Act IV |
|---|---|---|---|---|---|---|---|---|
| 1 | A living world past the walls | 3 | 1 | 2 | 2 | 2 | 2 | 2 |
| 2 | Timed world beats | 3 | 1 | 2 | 2 | 3 | 2 | 2 |
| 3 | Small reactive details | 3 | 1 | 1 | 1 | 2 | 1 | 1 |
| 4 | A hero landmark | 3 | 3 | 2 | 2 | 2 | 2 | 3 |
| 5 | A person to save or help | 3 | 3 | 2 | 2 | 2 | 2 | 1 |
| 6 | Room story | 3 | 3 | 2 | 1 | 1 | 2 | 2 |
| 7 | A mini-quest anyone can do | 3 | 2 | 0 | 1 | 0 | 1 | 1 |
| 8 | Verticality | 2 | 3 | 2 | 1 | 1 | 1 | 2 |
| 9 | A power-on spectacle | 2 | 3 | 2 | 2 | 1 | 2 | 0 |
| 10 | A holdout set-piece | 1 | 3 | 1 | 1 | 2 | 1 | 2 |
| 11 | A buildable wonder weapon | 1 | 3 | 1 | 1 | 1 | 2 | 1 |
| 12 | A full main Easter egg | 2 | 3 | 0 | 2 | 2 | 2 | 2 |
| 13 | A boss round | 3 | 1 | 1 | 2 | 2 | 2 | 2 |
| 14 | A trap with a show | 0 | 3 | 2 | 2 | 0 | 1 | 0 |
| 15 | The bank and its teller | 3 | 3 | 2 | 2 | 2 | 2 | 2 |
| 16 | A strong training loop + good chokes | 3 | 2 | 2 | 2 | 1 | 1 | 1 |
| 17 | Lighting pass | 3 | 3 | 3 | 2 | 2 | 2 | 2 |
| 18 | A campaign exit with a cutscene | 3 | 3 | 2 | 2 | 2 | 2 | 2 |
| | **Seed rows 1–18** | **44** | **44** | **29** | **30** | **28** | **30** | **28** |
| 19 | Relief squads (the living war) | 3 | 2 | 2 | 2 | 0 | 2 | 0 |
| 20 | Extra people with favours | 3 | 3 | 0 | 0 | 0 | 1 | 0 |
| 21 | The Jakub arc on this map | 3 | 3 | 1 | 1 | 1 | 2 | 1 |
| 22 | An opening / arrival you remember | 3 | 1 | 1 | 1 | 1 | 1 | 2 |
| 23 | Zone audio beds (sound per room) | 2 | 1 | 3 | 2 | 2 | 1 | 2 |
| 24 | Minimap and pause map current | 3 | 3 | 3 | 1 | 1 | 1 | 1 |
| 25 | Crate / weapon-parcel drama | 2 | 3 | 2 | 2 | 1 | 2 | 1 |
| 26 | Test coverage (launcher, smokes, GUT) | 3 | 2 | 1 | 1 | 1 | 1 | 2 |
| 27 | Recorded voice on the map | 3 | 3 | 2 | 1 | 1 | 1 | 1 |
| 28 | Pays well (Scrip per round) | 2 | 3 | 1 | 2 | 1 | 1 | 1 |
| | **Added rows 19–28** | **27** | **24** | **16** | **13** | **9** | **13** | **11** |
| | **TOTAL (28 rows, max 84)** | **71** | **68** | **45** | **43** | **37** | **43** | **39** |

Reading it: on the seed rows alone the two reference maps tie at 44 and the four new columns sit at 28–30, two
thirds of the bar. The added rows widen the gap (the Inn and Kaltenbrunn have people, favours, Jakub, recorded
voice and test coverage the new maps do not), which is the point of adding them: they are what the owner feels
when the Inn "feels great".

### 1.1b Re-score at FINISH (2026-11-02, commit db4c9ef6)

Scored by the §9 scorer from the state of `master` at db4c9ef6 (UPDATE 10 sections 1–5 and 8 merged, section 9's
launcher buttons in) by section 5's method: the same 0/1/2/3 scale, unmeasured is 1, a feature in data that no run,
test, smoke or capture shows is 1, shared systems out, the evidence per cell in section 1.2b. Two merges were still
pending when this block was written (`u10-6-polish`, T-162; `u10-7-bots`, T-163); rows **24, 26, 27 and 28** were
scored provisionally and **finalised at master 40cb5676** (both merged, 1827/1827 tests, 744 scripts): row 24 is 3
on every map (all seven minimaps re-baked 2026-11-02 14:29–15:01, `tools/check_mapdata.sh` PASS), row 27 is 3 on
Totenhafen (the Kielholer's four lines baked; the manifest's `missing` list is 6 stage directions), rows 26 and 28
are unchanged (T-163's tests and smokes are shared; it reports step completions and act rounds, not Scrip). Map 1
and Map 2 are re-scored too: Kaltenbrunn's living world (T-161) and PAUL (T-159) raise the bar.

| # | Feature | M1 Inn | M2 Kalt. | M3 Toten. | Act I | Act II | Act III | Act IV |
|---|---|---|---|---|---|---|---|---|
| 1 | A living world past the walls | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| 2 | Timed world beats | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| 3 | Small reactive details | 3 | 2 | 2 | 2 | 3 | 3 | 2 |
| 4 | A hero landmark | 3 | 3 | 3 | 2 | 3 | 3 | 3 |
| 5 | A person to save or help | 3 | 3 | 2 | 3 | 2 | 3 | 2 |
| 6 | Room story | 3 | 3 | 3 | 2 | 2 | 2 | 3 |
| 7 | A mini-quest anyone can do | 3 | 2 | 2 | 2 | 2 | 2 | 2 |
| 8 | Verticality | 2 | 3 | 2 | 2 | 2 | 2 | 2 |
| 9 | A power-on spectacle | 2 | 3 | 3 | 3 | 3 | 2 | 3 |
| 10 | A holdout set-piece | 1 | 3 | 3 | 2 | 3 | 2 | 3 |
| 11 | A buildable wonder weapon | 1 | 3 | 3 | 1 | 1 | 2 | 1 |
| 12 | A full main Easter egg | 2 | 3 | 3 | 2 | 2 | 2 | 2 |
| 13 | A boss round | 3 | 3 | 3 | 2 | 2 | 2 | 2 |
| 14 | A trap with a show | 0 | 3 | 3 | 3 | 2 | 2 | 2 |
| 15 | The bank and its teller | 3 | 3 | 2 | 2 | 3 | 2 | 2 |
| 16 | A strong training loop + good chokes | 3 | 2 | 2 | 2 | 1 | 1 | 1 |
| 17 | Lighting pass | 3 | 3 | 3 | 2 | 2 | 2 | 2 |
| 18 | A campaign exit with a cutscene | 3 | 3 | 3 | 2 | 2 | 2 | 3 |
| | **Seed rows 1–18** | **44** | **51** | **48** | **40** | **41** | **40** | **41** |
| 19 | Relief squads (the living war) | 3 | 2 | 2 | 2 | 2 | 2 | 1 |
| 20 | Extra people with favours | 3 | 3 | 0 | 2 | 2 | 2 | 2 |
| 21 | The Jakub arc on this map | 3 | 3 | 1 | 1 | 2 | 2 | 2 |
| 22 | An opening / arrival you remember | 3 | 1 | 1 | 1 | 1 | 2 | 2 |
| 23 | Zone audio beds (sound per room) | 2 | 2 | 3 | 2 | 2 | 2 | 3 |
| 24 | Minimap and pause map current | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| 25 | Crate / weapon-parcel drama | 2 | 3 | 2 | 2 | 1 | 2 | 2 |
| 26 | Test coverage (launcher, smokes, GUT) | 3 | 3 | 3 | 2 | 2 | 2 | 2 |
| 27 | Recorded voice on the map | 3 | 3 | 3 | 2 | 2 | 2 | 2 |
| 28 | Pays well (Scrip per round) | 2 | 3 | 3 | 2 | 1 | 1 | 1 |
| | **Added rows 19–28** | **27** | **26** | **21** | **19** | **18** | **20** | **20** |
| | **TOTAL (28 rows, max 84)** | **71** | **77** | **69** | **59** | **59** | **60** | **61** |
| | *Baseline (1.1)* | *71* | *68* | *45* | *43* | *37* | *43* | *39* |
| | *Change* | *0* | *+9* | *+24* | *+16* | *+22* | *+17* | *+22* |

Before the merges (at db4c9ef6) the provisional totals were M2 76, M3 67 and Act IV 59; T-162 moved row 24 to 3 on
those three columns and row 27 to 3 on Totenhafen, exactly as its branch paragraph said. Nothing else in T-162 or
T-163 moves a cell: the hints, citations, transitions, the audio mix and the bot set-piece layer are shared systems
(1.3); Pohl's own model (`ogpohl`) is noted in row 5; the Kaltenbrunn egg (0/5) and Q-19 (0/3) were already scored
from `QA_REPORT_U10.md`.

Reading it: the four new columns gained 16–22 points each and Totenhafen is now the third-best map on the seed
rows (48 against the Inn's 44). But the bar moved: Kaltenbrunn's living world, PAUL, the audio beds and the re-baked
minimap lift Map 2 to 77, so the target of §1.3 (the higher of the two re-scored totals) is **77**, and **no new
column reaches it**. What holds them down is the same list on every act: rows 16 and 28 (no soak reaches round 30
or measures Scrip past act round 5: Q-19 is 0/3 on the final code, QA_REPORT_U10 §2), row 13 (four bosses that no
run or capture has ever shown), row 21 (Jakub has lines but no scene of his own on three maps), row 27 (every line is
baked, but the new speakers are OneCore placeholders), and on Totenhafen rows 20 and 21 (no extra people, Jakub's
two arrival lines exist in `lines.json` and nothing plays them).

### 1.2 Evidence per cell

One line per map per row, under 120 characters each.

**1. A living world past the walls**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | `map00_ambience.json`: 22 systems (bombers, plane down r6, artillery, flak, crows, dog); `Landscape`; T-052 |
| M2 | 1 | no ambience file, no `MapAmbience`/`audio_zone` node in `map01.tscn`; base bed `ambient_map01` only |
| M3 | 2 | open-sea shader, 2 `BlinkLight`s, `LightningFlash` storm card (T-145); no sky traffic, no map02 living-world file |
| I | 2 | `ThalbachSky`: 4 searchlights, mauve dawn, ridges, lit windows with silhouettes (T-146; `00_A_wide`) |
| II | 2 | `FlightSky`: 6 legs by act round, cloud sheets, coast, London grid, 3 fighter passes/round (T-147; `18_E_window`) |
| III | 2 | `desert_sky.gdshader`, ridge rings, moving wreck fire, `DustStormFx` (T-148; `13_E_tower`) |
| IV | 2 | `earth.gdshader` with cloud deck and violet thread, hard stars, low Sun (T-149; `06_C_wide`) |

**2. Timed world beats**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | flares r2, Trudi r2, Jakub r5, plane down r6, farm dark r8, bell r9, dog r10, Cousins r10 (`map00_ambience.json`) |
| M2 | 1 | only the exfil at r30 (`map01.json`); Bellringer and Foreman are enemy schedules, not world beats |
| M3 | 2 | high tide every 3rd round from 3 with forecast VO (`map02.json tide`); exfil r40; nothing else on the clock |
| I | 2 | Fliegeralarm specials, Glasshide r8, `halle_open_round` 12, Kranführer r13, ramp r15 (`map04a.json act`) |
| II | 3 | breach r1, strafe r2, London r3, Bordwart r4, bomb run r5, autopilot r6, sky legs (`map04b.json act/flight`) |
| III | 2 | burrower r1, canary r3, jumpjockey r4, backorder r5, Test Pilot r6, rocket r9, dust storm (`map04c.json`) |
| IV | 2 | Earth spread from r3, Dee's radio r1/3/6, renewal r16, Solar Flare (`map04d.json act.events`) |

**3. Small reactive details**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 24 shootable lamps, 12 draft curtains, 3 swing doors, 8 hay puffs, crows scatter, footprints (`world/reactive/`) |
| M2 | 1 | 8 lantern `DecorHit`s in `map01.tscn` and nothing else |
| M3 | 1 | 1 lamp `DecorHit`, `TowerSway`, lightning, 2 blink lights; the gulls are audio one-shots only |
| I | 1 | 2 lamp `DecorHit`s; the sky searchlights are ambient; nothing answers a shot |
| II | 2 | 49 `flight_swing` nodes swing on the bank, core and reels spin, breach panels go see-through (T-147) |
| III | 1 | no `DecorHit`; fire and dust move on their own; nothing answers a shot or a step |
| IV | 1 | the airlock cycles when a survivor steps through (T-149); conveyor, hand and hum are ambient; no shot reactions |

**4. A hero landmark**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | GRAVELIGHT ONE burning with Selwyn pinned alive (`pilot.json`, T-126); the inn gable (`u09_ref/02_ref_yard`) |
| M2 | 3 | the headframe over Schacht II with the pylon crystal (`u09_ref/03_ref_minehead`); the heart in the Core |
| M3 | 2 | U-1047 Type VII loft, tower, gun, railings (T-145; `10_D_hero`), but the hull still reads as a corrugated box |
| I | 2 | the Kranich 86 m shell under 12 trusses (T-146; `20_H_kranich` reads as an olive dune); the church tower |
| II | 2 | the wing shell itself: frames, grating, spars (`06_C_wide`); the London window reads as a dot grid |
| III | 2 | radar lattice and dish against the blue hour (`13_E_tower`); the wreck interior is still a grey hall (`00_A_wide`) |
| IV | 3 | the Earth over the rim with the dish and the violet thread (`06_C_wide`); the NOBODY CANCELS nave (`12_E_wide`) |

**5. A person to save or help**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | Jakub's cage, Trudi, 3 survivors to arm, Selwyn, Lanz/Ebert/Hager (T-135, T-143, `map00_survivors.json`) |
| M2 | 3 | Jakub's Road, Ammer and his trade, Brzezina's miners, Roth's revive point, Seidl (`people_extra.json`, T-143) |
| M3 | 2 | Petersen only (`companions.json`, 42 shared lines): waits on the tower ramp, no scene; no extra people |
| I | 2 | Jette in the yardmaster's hut, joins and carries to Act III (`companions.json`, `jette_*` flags); no extra people |
| II | 2 | Jette carried in (`campaign.json carry_flags`); nobody new aboard |
| III | 2 | Jette leaves at the rocket; Dee's cage (a quest); Hale behind glass and Peg's choice (`test_pegs_choice`) |
| IV | 1 | no companion, no extra people; Dee's radio lines only if `dee_cage_done` carried (`map04d.json`) |

**6. Room story**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 7 `story_props`, 16 intel (7 fixed), the skat table, Frau Pohl's suitcase, the trunk invoice (T-072, MAPS.md) |
| M2 | 3 | 28 intel rows, the nursery, the Intake tag board, Liesl's music box, Fenske's ledger (`intel.json`, LORE 13.2) |
| M3 | 2 | 5 `story_props`, 5 fixed intel; drowned effects, chalk tally and boat log are labels, not StoryProps (T-145) |
| I | 1 | 0 `story_props` rows, 4 intel; the 3 files are egg steps; notices, the meal, the hopscotch are dressing (T-146) |
| II | 1 | 0 `story_props`, 1 intel; rack chalk, the load list and the engineer's log are dressing (T-147) |
| III | 2 | 2 `story_props`, 2 intel; the crate, the relay and the olive cabinets tell the twist (MAP4 5.2) |
| IV | 2 | 5 `story_props`, 6 intel; the terms plates, Pilch's hand, the crew tags by name (T-149) |

**7. A mini-quest anyone can do**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | `map00_radio`: 2 steps, 19 FAS_M0 + 78 M0_EGG lines, a cutscene-lite; bots 1/1 (QA_U08) |
| M2 | 2 | Lanterns Down Below ("placeholder audio"), KB-4471 with the Wren/Dutch exchange (`quests/map01_song`, `_wren_tag`) |
| M3 | 0 | `data/gravelight/quests/` has no map02 file; `objectives.json` map02 `side` list is empty |
| I | 1 | `map04a_jette` 2 steps; its VO is among 52 unrecorded M4A lines (`vo/audio_manifest.json` "bake on the PC") |
| II | 0 | none; Wren's tally needs Bolt in the match |
| III | 1 | `map04c_cage` 1 step, no VO; Fasbender's shack scene is an egg side-step |
| IV | 1 | `map04d_smile` 1 step, `vo_actor` unrecorded; Request Hour needs Vendelin or Fernet |

**8. Verticality**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | cellar −3.2 / 0 / hayloft 3.5 / 3.8, the bale drop, the stair (`lighting/shots_map00.json`); 3 minimap floors |
| M2 | 3 | 0 / −12 / −18, a 25 s lift ride, switchback stairs, the admin balcony over the yard; 4 floors (`gen_map01.gd`) |
| M3 | 2 | 0 / −2 / −3 / +7, 3 ladders, catwalks at +4 (`map02.json zones`, `climb_links`); a two-height ring |
| I | 1 | every zone at 0; the 2 crane ladders to y 12 are spawn climbs (`map04a.json`); 2 floors |
| II | 1 | a flat deck, `climb_links` empty, 1 minimap floor (`map04b.json`) |
| III | 1 | the lab and silo at −1, the hatch to the lakebed (`map04c.json`); 2 floors |
| IV | 2 | flat, but 0.38 g, 2.6x jumps, Jumpjockeys on the dome catwalks (`map04d.json`, `test_gravity_scale`) |

**9. A power-on spectacle**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | the cellar lever: 20 power lights, 3-zombie burst, `OPR_POWER_ON_M0_01`, 11 bulbs sweep into the inn (T-061) |
| M2 | 3 | Hauptschalter: turbines spin up, 60 lights G→A, perk stings, the Lab door reveal, 6 burst, FAS line (MAPS.md) |
| M3 | 2 | Pumpenschalter: 70 lights F→A, flywheels, 6 burst, needs `ballast_loaded`; no drain, no boat change (MAPS.md) |
| I | 2 | the Kraftzentrale breaker: 29 lights, 6 burst; `OPR_M4A_POWER_01` unrecorded (`power_switch.gd`, manifest) |
| II | 1 | an aux-bus sweep (25 lights, 4 burst) but no switch to seek out; the VO is the ARRIVE line (`map04b.json`) |
| III | 2 | the generator shed: 21 lights, 4 burst; `OPR_M4C_POWER_01` unrecorded; the dish does not turn yet |
| IV | 0 | `power_on_at_start`, no `power` block, no `PowerSwitch` node (`map04d.json`, `map04d.tscn`) |

**10. A holdout set-piece**

| Map | Score | Evidence |
|---|---|---|
| M1 | 1 | only the exfil window (90 s at r10, campaign only); the Cousins round is a boss, not a holdout |
| M2 | 3 | 3 pylons 45 s at x2 spawns + Heartstorm 2:00 with the Foreman twice (`world/pylon.gd`, `map01_requiem.json`) |
| M3 | 1 | only the exfil window at r40; the tide floods F but asks nothing of you |
| I | 1 | only the exfil at act r15; the Fliegeralarm circles are a special round |
| II | 2 | Druckabfall (4 breaches in sequence), the bomb run (6 racks every 35 s) (`map04b.json flight`) |
| III | 1 | the burn sequence and the gantry-lift exfil; no timed stand |
| IV | 2 | the renewal clock 6:00 in the finale; Solar Flare kills the air posts (`map04d.json renewal`) |

**11. A buildable wonder weapon**

| Map | Score | Evidence |
|---|---|---|
| M1 | 1 | crate-only (Ashlight, Elmsfeuer, Gramophone from the global pool, `crate.json`); nothing to build |
| M2 | 3 | Totenglocke: 9 seeded part spots + the bench, the wind-and-toll rebuild (T-048, `weapons.json` L1208) |
| M3 | 1 | crate-only; no bench, no parts (`map02.tscn` has no `buildable_part`) |
| I | 1 | crate-only |
| II | 1 | crate-only, and the act has 1 crate spot |
| III | 2 | Lodestone: 6 part spots + the lab bench (`test_lodestone`); no soak has reached Act III to prove it |
| IV | 1 | the Lodestone arrives in the kit (`campaign.json:630`); nothing to build |

**12. A full main Easter egg**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | Glasmacher Calling: 2 steps, a cutscene-lite, unlocks Map 2; bots 1/1 (QA_U08) |
| M2 | 3 | Requiem: 13 steps, parallel threads, seeded bells, the Foreman's key, Heartstorm, an ending; bots 0/6 past s3 |
| M3 | 0 | no quest file, `objectives.json` `easter_egg` empty; LETZTE FAHRT is design only (UPDATE_10 §2.2) |
| I | 2 | Kündigung Act I: 6 steps (3 files, the hangar door); `smoke_map04_egg` PASS; the soak's bots reached s1 only |
| II | 2 | Kündigung Act II: 5 steps (London, Bordwart, bomb run, autopilot); never reached by a soak |
| III | 2 | Kündigung Act III: 6 steps (carry, Peg's choice, Test Pilot, burn, launch); never reached by a soak |
| IV | 2 | Kündigung Act IV: 5 steps, two endings 150 s / 40 s (`test_endings`); 71 M4D lines unrecorded |

**13. A boss round**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | the Cousins at r10, returning every 5 (`bosses/cousins.json`, `test_homage_cousins`, `smoke_cousins`) |
| M2 | 1 | the Foreman special only; PAUL designed, unbuilt (HOMAGE_BOSSES.md §0) |
| M3 | 1 | the Foreman special only; the Kielholer deferred (MAPS.md) |
| I | 2 | Der Kranführer 24k HP at act r13 (`bosses/map04.json`, `test_kranfuehrer`); no soak or capture shows him |
| II | 2 | Der Bordwart 30k HP at act r4 (`bosses/map04.json`); unseen in any soak |
| III | 2 | The Test Pilot 32k HP at act r6 (`test_testpilot`); unseen in any soak |
| IV | 2 | The Account Manager 45k, never dies, 3 shield cells (`test_account_manager`); unseen in any soak |

**14. A trap with a show**

| Map | Score | Evidence |
|---|---|---|
| M1 | 0 | none (`traps.json` has no map00 entry) |
| M2 | 3 | ore cart (rumble, bells), live wire (buzz, zap, light), chandelier (crash, shake); 3 levers |
| M3 | 2 | Torpedo Trolley (`ore_cart`) and the Grille (`live_wire`), 2 levers; the same scripts as Map 2 |
| I | 2 | Coal Hopper and Jig Crane (chandelier style `skip`/`wing`, T-146), 2 levers; the wind tunnel is not a trap yet |
| II | 0 | none; the breach panels and racks are set-pieces |
| III | 1 | one live wire, 1 lever |
| IV | 0 | none |

**15. The bank and its teller**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | the Darlehenskasse shed, Lassmann with 19 lines, cowers at shots, `smoke_bank` (T-136) |
| M2 | 3 | the pay office, Lassmann's Kaltenbrunn greeting, Ledger Lager beside it (T-136, T-141) |
| M3 | 2 | the Marinekasse, Jessen with 8 lines (`bank.json`); not covered by `smoke_bank` |
| I | 2 | the Lohnkasse in the yardmaster's hut, Ruhland with 10 lines (T-141) |
| II | 2 | the Bordkasse at the forward bulkhead, Ruhland again (T-141) |
| III | 2 | the Range Finance Office at Dee's cage, Pruitt with 8 lines (T-141) |
| IV | 2 | Darkmatter Accounts: a speaking-tube window, the Operator's 8 lines, no teller by design (T-141) |

**16. A strong training loop + good chokes**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 10 routes, 36 spawns, 4 chokes, the Wreck and Well loops (`ai/routes_map00.json`, MAPS.md); soak r20 (QA_U08) |
| M2 | 2 | 3 routes, 37 spawns, 5 chokes, the Pew and Turbine loops; soak wipe r12 at 0.42 downs/round (QA_U08) |
| M3 | 2 | 3 routes, 24 spawns, 6 chokes, the two-height ring; soak wipe r11 at the quay (Q-12, QA_U07) |
| I | 2 | 4 routes, 31 spawns, 4 loops and 4 chokes; soak wipe r10, 7 human downs, 85 stuck events (T-146) |
| II | 1 | 3 routes, 14 spawns, 7 barricades; bots alone wipe at act r3–4 (Q-19 OPEN, QA_U07 §7) |
| III | 1 | 3 routes, 25 spawns; no soak has reached it; skip-to-act wipes at r21 in 0.7 min (QA_U07 §7) |
| IV | 1 | 4 routes, 19 spawns; skip-to-act wipes at r30 in 0.7 min without god mode (T-149) |

**17. Lighting pass**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | the T-061 pass, 15 shots (`lighting/shots_map00.json`), following lights, window spills |
| M2 | 3 | the T-062 depth grade, 18 shots (`shots_map01.json`) |
| M3 | 3 | the T-063 pass + T-145's one key per zone and ViewCells; 14 shots (`shots_map02.json`) |
| I | 2 | T-146: one key per zone, visible fixtures; no shots file; the Montage still reads dark ("not done") |
| II | 2 | T-147: 6 shadowed keys, caged fixtures; no shots file; the hatch windows look into closets |
| III | 2 | T-148: sun key, fire key, the sky shader; no shots file; the web 200k target not met |
| IV | 2 | T-149: SunGate, shadow shells, a key per zone; no shots file; a known moire on the hall wall |

**18. A campaign exit with a cutscene**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | exfil r10 THE CARTERS' ROAD, 30 s / 3 shots (`campaign.json`); the stable door opens free when it lights |
| M2 | 3 | exfil r30 THE NORTH GATE 30 s + the Requiem ending 60 s (`world/requiem_ending.gd`) |
| M3 | 2 | exfil r40 → WERK THALBACH 24 s / 3 shots; a "missing scene" noted in MAPS.md's campaign chain |
| I | 2 | the boarding 38 s / 4 shots, Jakub boards; Wittkamp's line is unrecorded silence with subtitles |
| II | 2 | the crash 40 s / 5 shots on the rip-out vote (`exfil_m4b_m4c`) |
| III | 2 | the rocket 40 s / 5 shots, Dee on the gantry (`exfil_m4c_m4d`) |
| IV | 2 | no exfil; `cancel_ending` 150 s with `cards_m4.json`, `renewal_ending` 40 s; the VO unrecorded |

**19. Relief squads (the living war, T-142)**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | Home Army + Soviet scouts on field-edge markers; `smoke_squads`, a launcher button (T-142) |
| M2 | 2 | Home Army + Volkssturm (`squads.json`) |
| M3 | 2 | British commandos from the sea + a Kriegsmarine shore party (`squads.json`) |
| I | 2 | a US paratrooper stick + Volkssturm (`squads.json`) |
| II | 0 | none by design: a plane in flight (`squads.json:180`) |
| III | 2 | MPs / range guards, one faction (`squads.json`) |
| IV | 0 | none by design: the Moon (`squads.json:187`) |

**20. Extra people with favours (T-143)**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | Lanz, Ebert, Hager with favours, Talk cards and minimap pins (`people_extra.json`, T-143) |
| M2 | 3 | Brzezina + 2 miners, Roth, Seidl, Ammer's trade card (`people_extra.json`) |
| M3 | 0 | none in `people_extra.json` |
| I | 0 | none |
| II | 0 | none |
| III | 1 | Hale talks through the glass, Dee in her cage (a scene and a quest, not a Talk card) |
| IV | 0 | none; the first retained is a prop |

**21. The Jakub arc on this map**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | the cage, the breakout at r5, tonics, the chalk alphabet (`companion_jakub.json`) |
| M2 | 3 | Jakub's Road, the miners greet him, the door discount, INT_MARKE_JAKUB on the stairs (T-143, T-137) |
| M3 | 1 | he comes along in the campaign; no line or spot of his own on the map |
| I | 1 | he boards the Kranich (MAP4 3.9); JAK_M4 lines baked (T-143) but no Thalbach scene |
| II | 1 | aboard; no scene |
| III | 2 | "I have ridden worse coal wagons" at the rocket (MAP4 5.9) |
| IV | 1 | present; no scene |

**22. An opening / arrival you remember**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | `InnOpening`: 5 patrons, the look-around, caught on the porch (`map00_opening.json`, T-076) |
| M2 | 1 | an intro banner and Ammer's call from the stores |
| M3 | 1 | an intro banner and an Operator line |
| I | 1 | an intro banner; Jette's call from the hut (`00_A_wide`) |
| II | 1 | a 20 s arrival grace "the crash" and a banner |
| III | 1 | an intro banner, Dee's line |
| IV | 2 | the arrival VO block, the airlock cycle, "there is no air" (`map04d.json arrival`, T-149) |

**23. Zone audio beds (sound per room)**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | 13 positional `audio_zone` nodes, no `ZoneAmbience` beds (`map00.tscn`) |
| M2 | 1 | the base bed `ambient_map01` only (`audio.json:101`) |
| M3 | 3 | 7 beds + 19 one-shots from two CC0 sea recordings, a storm bed (`ambience/map02.json`, T-145) |
| I | 2 | 8 synthesized 20 s mono beds, 13 one-shots (`ambience/map04a.json`) |
| II | 2 | 7 beds + 16 one-shots, the whole-wing drone (`ambience/map04b.json`) |
| III | 1 | 7 beds, 7 one-shots, F_LAB none; the base bed falls back to the Inn's wind (`audio.json:99-107`) |
| IV | 2 | 6 beds, the vacuum rule on the yard (`ambience/map04d.json`) |

**24. Minimap and pause map current**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 3 floors, 35 POIs, re-baked after T-136 (`data/maps/map00_crossroads/`) |
| M2 | 3 | 4 floors, 49 POIs (`data/maps/map01_kaltenbrunn/`) |
| M3 | 3 | 4 floors, 38 POIs, re-baked after T-145 through WSL |
| I | 1 | 2 floors, 40 POIs; the image not re-baked after the rebuild (T-146 "not done") |
| II | 1 | 1 floor, 29 POIs; re-bake unverified (MORNING_REPORT open list: minimaps not re-baked) |
| III | 1 | 2 floors, 35 POIs; re-bake unverified |
| IV | 1 | 1 floor, 27 POIs; re-bake unverified |

**25. Crate / weapon-parcel drama**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | 4 crate spots; the drummer vanishes; squad parcels from relief squads |
| M2 | 3 | 5 spots; Herr Tamtam marches as egg step 7 (`map01_requiem.json`) |
| M3 | 2 | 5 spots (MAPS.md crate table) |
| I | 2 | 4 spots |
| II | 1 | 1 spot |
| III | 2 | 3 spots |
| IV | 1 | 2 spots |

**26. Test coverage (launcher buttons, smokes, GUT files)**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | ~18 launcher buttons, 31 smokes, 11 GUT files (`ui/dev_launcher.gd`, `tools_src/smoke_*`) |
| M2 | 2 | 5 buttons, 13 smokes, 3 GUT files |
| M3 | 1 | 2 buttons, 7 smokes, 3 GUT files |
| I | 1 | 3 buttons, 6 smokes, 4 GUT files |
| II | 1 | 2 buttons, 7 smokes, 3 GUT files |
| III | 1 | 2 buttons, 5 smokes, 6 GUT files; `smoke_map04c` fails its burn-console steps on master (T-141 note) |
| IV | 2 | 2 buttons, 5 smokes, 9 GUT files |

**27. Recorded voice on the map**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 108 M0 files plus the opening and the survivors; everything baked (`vo/audio_manifest.json`) |
| M2 | 3 | 23 M1 files + OPR_QUEST 18, REI 23, FAS_M1 15, OPR_PYLON 9, all recorded |
| M3 | 2 | 8 M2 lines (5 files), the tide VO, JES 8, PET; no Kielholer or egg lines exist to record yet |
| I | 1 | 52 M4A lines "bake on the PC": timed silence with subtitles (`vo/audio_manifest.json`) |
| II | 1 | 72 M4B lines unrecorded |
| III | 1 | 84 M4C lines unrecorded |
| IV | 1 | 71 M4D lines unrecorded |

**28. Pays well (Scrip per round)**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | 5,105 Scrip after r8 (QA_U07 §6.5); about 7,560 spent per round in the r20 soak (QA_U08) |
| M2 | 3 | 6,695 after r8, the best of the three (QA_U07 §6.5) |
| M3 | 1 | 4,380 after r8, "pays the least" (QA_U07 §6.5); 1,370 spent per round in the r11 soak |
| I | 2 | 2,745 spent per round to r10 (`summary_fernflug.csv`); bots alone 53,600 over 15 act rounds (QA_U07 §7) |
| II | 1 | 20,500 over 4 rounds then a wipe (QA_U07 §7); unmeasured past act r4 |
| III | 1 | unmeasured: no soak has reached it |
| IV | 1 | unmeasured: no soak has reached it |

### 1.2b Evidence per cell, re-score

One line per map per row, under 120 characters each, from the section 5 inventory taken on 2026-11-02 at db4c9ef6.
Shorthand as in 1.2, plus: a bare `smoke_x` is the `RESULT: PASS` line of `.smoke_logs/rescore/smoke_x.log` (this
re-score's own headless run on the PC, 2026-11-02; `.smoke_logs/u10_*` = the lead's logs in the main checkout);
`test_x` = `gravelight/tests/unit/test_x.gd`; `u10_map04a/07` = `morning/screenshots/u10_after/u10_map04a/07_*.png`;
`QA_U10` = `docs/QA_REPORT_U10.md` (on `u10-7-bots` when written); counts such as "9 kinds" are the top-level keys of
`data/gravelight/<map>_ambience.json`; story props and intel are rows of `story_props.json` / `intel.json` by `map`.

**1. A living world past the walls**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | `map00_ambience.json` 23 kinds (bombers, plane down r6, artillery, flak, crows, dog); `Landscape`; unchanged (T-052) |
| M2 | 3 | `map01_ambience.json` 21 kinds: ridges, bombers, dogfight r7, avalanche, cable car (T-161); `smoke_map01_world` |
| M3 | 3 | `map02_ambience.json` 20 kinds: gulls, lighthouse, ships, raid r12, cutter r15 (T-154); `smoke_map02_world` |
| I | 3 | `map04a_ambience.json` 11 kinds: windows out, bell, jet r4, train, searchlights, posters (T-155); `smoke_map04a_world` |
| II | 3 | `map04b_ambience.json` 9 kinds: sunrise, formation of 4 (one shot down), flak, St Elmo, frost (T-156); `u10_map04b/09` |
| III | 3 | `map04c_ambience.json` 9 kinds: Milky Way, wildlife, B-29s, tumbleweeds, towers (T-157); `u10_map04c/06_B_storm` |
| IV | 3 | `map04d_ambience.json` 7 kinds: dust settle, relay mast, field units, meteors (T-158); `u10_map04d/08_Field_units` |

**2. Timed world beats**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | flares r2, Trudi r2, Jakub r5, plane down r6, farm dark r8, bell r9, dog r10, Cousins r10 (unchanged) |
| M2 | 3 | dogfight r7, siren r10, PAUL r15 (`bosses/map01.json`), snow harder r20, exfil r30 (`map01_ambience.json`, T-161) |
| M3 | 3 | tide every 3rd, spring every 9th (`map02.json tide`), lighthouse out r10, raid r12, cutter r15, bosses r20, r25 |
| I | 3 | blackout from act r2, train r3 and every 4th, jet r4, raid r8 (`map04a.json raid`), Kranführer r13, ramp r15 |
| II | 3 | strafe tears BreachL2 r2, decomp r2/r5, London r3, Bordwart r4, bomb run r5, tilts 2–3 per round (`map04b.json flight`) |
| III | 3 | burrower r1, canary r3, Test Pilot r6, dust storm every 5th act round, radar ping each minute (`map04c.json groom`) |
| IV | 3 | terminator r1→r16, Earth spread r3, Dee r1/3/6, meteors r33/39/45, renewal r16, Solar Flare (`map04d.json`) |

**3. Small reactive details**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 48 `DecorHit` in `map00.tscn`, 27 swing nodes, curtains, hay puffs, crows scatter, footprints (unchanged) |
| M2 | 2 | 16 lantern `DecorHit`s; dust when shelled, lift chains, drips, the salt glint (T-161): ambient, not shot-reactive |
| M3 | 2 | gulls scatter at the first shot, chains swing on blasts, fish crates tip, wet footprints, icicles (T-154); 2 `DecorHit` |
| I | 2 | sheet rattle, 3 swaying wing sections, welding, 6 posters, raid debris (T-155); 4 `DecorHit`; nothing answers a shot |
| II | 3 | 98 swing nodes; 9 sliders slide on the tilt, a casing kills (`tilt_slider.gd`); cables, rivets; `smoke_turbulence` |
| III | 3 | stalkers hunt by sound, a sprint or shot heard ×3 (`sound_hunter.gd`); collapses re-bake the nav; `smoke_wreck_collapse` |
| IV | 2 | dust settles after shots, the airlock cycles, the mast pulses (`map04d_ambience.json`); no `DecorHit` |

**4. A hero landmark**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | GRAVELIGHT ONE with Selwyn alive; the inn gable (unchanged) |
| M2 | 3 | the headframe over Schacht II, now with PAUL's leap from its head platform (T-159); the Core heart |
| M3 | 3 | U-1047 sails: the helm, scrolling scenery, boarders on the tanks (`uboat_sail.gd`, `smoke_sail`); `u09_map02/10_D_hero` |
| I | 2 | the Kranich from the lookout "a violet column and a dark shape at 65 m" (T-155 not done); `u10_map04a/07_lookout` |
| II | 3 | the wing itself, walkable 90 m to the tip with the formation beside it (`wing_walk.gd`; `u10_map04b/07_WW_out`) |
| III | 3 | the wreck as a changing arena (two collapses, the fire spreads: `u10_map04c/03_A_collapsed`); the dish turns at 22 m |
| IV | 3 | the Earth over the rim with the terminator line and the dish (`u10_map04d/00_T_line_yard`); the NOBODY CANCELS nave |

**5. A person to save or help**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | Jakub's cage, Trudi, 3 survivors, Selwyn, Lanz/Ebert/Hager (unchanged) |
| M2 | 3 | Jakub's Road, Ammer, Brzezina's miners, Roth, Seidl (unchanged) |
| M3 | 2 | Petersen moved to the tower stair, takes the helm (`companions.json`, `uboat_sail.gd:146`); PET_LF_TRAPPED_01 unplayed |
| I | 3 | Jette joins; Wendel's family in the raid cellar, Brack the signalman with favours (`people_extra.json`, T-155) |
| II | 2 | Jette carried; Ruhland and Riedl are body-less talk points with favours (`people_extra.json` `"body": false`) |
| III | 3 | Dee's cage + her valve favour, Hale behind glass with reactions, Peg's choice (`people_extra.json` dee/hale, T-157) |
| IV | 2 | Pohl in rack 2 bay 6, a Talk card and the tag favour (`people_extra.json` pohl, `tag_slot.gd`); `ogpohl` body (T-162) |

**6. Room story**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 7 story props, 16 intel (unchanged) |
| M2 | 3 | 2 story props, 28 intel, the nursery, the tag board (unchanged) |
| M3 | 3 | 10 story props (the sailor's letter, Hale telegram, pay slip, drawing, ration book), 15 placed intel (T-154) |
| I | 2 | 4 story props INT_M4A_WORKSPASS/RIVETLOG/WINDOWLETTER/LOADSHEET, 8 intel (T-155): the order's "4+" met, Map 2's 28 not |
| II | 2 | 4 story props INT_M4B_BORDBUCH/CREWPHOTO/AIMERCARD/AUTOPILOT, 6 intel incl. the last reel (T-156) |
| III | 2 | 2 story props, 2 intel, unchanged since T-148: the only act under the order's "4+ story props" |
| IV | 3 | 9 story props (4 new: delivery log, Haas's tag, relay card, flight card), 10 intel (T-158) |

**7. A mini-quest anyone can do**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | `map00_radio` 2 steps with VO and a cutscene-lite (unchanged) |
| M2 | 2 | Lanterns Down Below and KB-4471 (unchanged; the "(placeholder audio)" banner goes with T-162) |
| M3 | 2 | the Ballast choice: load 500 Scrip / dump +1 Glasshide (`smoke_ballast2`, `test_ballast_v2`); no own quest file |
| I | 2 | `map04a_jette` 2 steps, 8 lines baked, minimap notes on sight (`sight_note.gd`; T-155); `smoke_map04a` |
| II | 2 | The Crew's Tags `map04b_crew_tags.json` 3 steps, PA lines baked, bots finish s1 (T-156); the reel is player-only |
| III | 2 | `map04c_cage` 1 step with DEE voice (OneCore) + Dee's valve favour → a supply drop (`people_extra.json`, T-157) |
| IV | 2 | `map04d_smile` 1 step + a minimap note on first sight; Pohl's tag at the console (T-158); `smoke_map04d_world` |

**8. Verticality**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | cellar / ground / hayloft, 3 floors (unchanged) |
| M2 | 3 | 0 / −12 / −18, the lift, 4 floors; PAUL rides the lift shaft (T-159) (unchanged) |
| M3 | 2 | 0 / −2 / −3 / +7, 3 climb links moved to zone climb layers, the tower stair and searchlight stand (T-153); 4 floors |
| I | 2 | the Luftbeobachtung post: a ramp to a 12 m platform in its own nav box (T-155); the tunnel hatch shortcut; 2 floors |
| II | 2 | the wing walk: a 3.4 m catwalk to the wingtip at x −117 with a climb link (`Nav_WingRails`); 1 minimap floor |
| III | 2 | the radar perch (`tower_ladder.gd`), the lab at −1; 2 floors; the dead's link to the deck FAILs (`smoke_map04c_world`) |
| IV | 2 | flat at 0.38 g: 5 `jump_pad.gd` plates, leapers from the catwalks, a fling to orbit (`moon_lowg.gd`); `smoke_low_g` |

**9. A power-on spectacle**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | the cellar lever: 20 lights, 3 burst, 11 bulbs sweep (unchanged) |
| M2 | 3 | Hauptschalter: turbines, 60 lights, perk stings, the Lab reveal (unchanged) |
| M3 | 3 | pumps thunder, docks drain 0.4 m, lamps dock by dock, perks wake, U-1047 red→white (T-154 `power_spectacle`) |
| I | 3 | the breaker: 29 lights, PA crackle hall by hall, gantries jolt, perk stings, the fan spins (T-155 `power_on`) |
| II | 3 | `aux_bus.gd`: a beacon board with a hint, a breaker per room, perk stings, `dial_lit`, PA_M4B_POWER_01 (T-156) |
| III | 2 | the shed: 21 lights, 4 burst (unchanged); the dish turns and pings when powered (`radar_dish.gd`, `smoke_radar_ping`) |
| IV | 3 | `heater_switch.gd`: domes one by one, the mast surges, airlocks cycle, perks spark, 4 burst (T-158); `smoke_terminator` |

**10. A holdout set-piece**

| Map | Score | Evidence |
|---|---|---|
| M1 | 1 | only the exfil window (unchanged) |
| M2 | 3 | 3 pylons + Heartstorm 2:00 (unchanged) |
| M3 | 3 | the crank 30 s at ×2 spawns (`pump_crank.gd`, `smoke_tide2`), 3 diesel holds (`diesel_holdout.gd`), the deck hold |
| I | 2 | the air raid: shockwave, bomb walk, the roof fall, fires that cool over 3 rounds (`thalbach_raid.gd`, `smoke_air_raid`) |
| II | 3 | decompression (hold a rail or slide out), Druckabfall, the bomb run, the wing (`smoke_decompression`, `smoke_wing_walk`) |
| III | 2 | the dust storm round at 15 m (`smoke_dust_storm`) and the burn sequence; no timed stand |
| IV | 3 | the renewal clock 6:00, the meteor shower 40 s (`meteor_shower.gd`, `smoke_meteors`), the vent (`shaft_grate.gd`) |

**11. A buildable wonder weapon**

| Map | Score | Evidence |
|---|---|---|
| M1 | 1 | crate-only (unchanged) |
| M2 | 3 | the Totenglocke (unchanged) |
| M3 | 3 | THE UNDERTOW: 3 parts × 2 spots, the shard from a dumped coffin, a bench, MAELSTROM (`smoke_undertow`, `test_undertow`) |
| I | 1 | crate-only |
| II | 1 | crate-only; the wingtip chest has an empty Undertow-class slot (`wing_chest.gd`) |
| III | 2 | the Lodestone (`test_lodestone`); no soak has built it (QA_U10 §2: one run reached Act III and wiped at r21) |
| IV | 1 | the Lodestone in the kit; the orbit fling is a use, not a build (`moon_lowg.gd`) |

**12. A full main Easter egg**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | Glasmacher Calling, 2 steps (unchanged) |
| M2 | 3 | Requiem 13 steps (unchanged); honest bots 0/5, each step done in isolation (QA_U10 §1) |
| M3 | 3 | LETZTE FAHRT 16 steps, seeded cipher, 3 holds, boss, sail, dive (`quests/map02_letzte_fahrt.json`); bots 3/15 (T-153) |
| I | 2 | Kündigung s1–s6; `smoke_map04_egg` PASS (T-155); bots in a soak reached s1 only (T-146) |
| II | 2 | s7a–s10; s7a now completes with bots (T-156); never reached by a bots-alone soak (QA_U10 §2) |
| III | 2 | s11a–s14; unreached by any soak |
| IV | 2 | s15a–s18, two endings (`test_endings`); VO baked (T-166); unreached by any soak |

**13. A boss round**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | the Cousins (unchanged) |
| M2 | 3 | PAUL r15 (`homage_encounter.gd`): rage, retreat 6:00, death scene (T-159, `smoke_paul`, `test_paul`); met in QA_U10 |
| M3 | 3 | DER KIELHOLER r20/40, 28k, chain sweep, the key (`kielholer.gd`, `smoke_kielholer`); bots killed him 3× (T-153) |
| I | 2 | Der Kranführer 24k (`test_kranfuehrer`); no soak or capture shows him (T-155's soak ends at act r8) |
| II | 2 | Der Bordwart 30k; reached in QA_U10's Q-19 runs, never killed |
| III | 2 | The Test Pilot 32k (`test_testpilot`); unseen in any run |
| IV | 2 | The Account Manager 45k (`test_account_manager`); unseen (T-158's bots bleed out in r30) |

**14. A trap with a show**

| Map | Score | Evidence |
|---|---|---|
| M1 | 0 | none (unchanged) |
| M2 | 3 | ore cart, live wire, chandelier (unchanged) |
| M3 | 3 | Torpedo Trolley, the Grille, the Crane Drop: a pallet on the east apron, dust and crash (`traps.json crane_drop`, T-153) |
| I | 3 | Coal Hopper, Jig Crane, the rivet line (`trap_rivet_line.gd`, `smoke_rivet_line`), the wind tunnel (`smoke_wind_tunnel`) |
| II | 2 | the bay doors: klaxon, 8 s open, the dead drop out (`bay_doors_trap.gd`, `traps.json bay_doors`); one lever |
| III | 2 | live wire + the fuel dump that kills on contact (`trap_fuel_dump.gd`, T-157) |
| IV | 2 | the vent: `shaft_grate.gd` 1000 Scrip, 8 s, pulls the dead into the shaft (T-158); the meteor round is an event |

**15. The bank and its teller**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | Lassmann, 19 lines, cowers (unchanged) |
| M2 | 3 | the pay office (unchanged) |
| M3 | 2 | the Marinekasse, Jessen 8 lines; `smoke_bank` now covers map02 (`smoke_bank.gd:190`) |
| I | 2 | the Lohnkasse, Ruhland (unchanged); `smoke_bank` map04a |
| II | 3 | the Bordkasse: Ruhland is a Talk card with the ledger favour, 1500 Scrip (`people_extra.json` ruhland, T-156) |
| III | 2 | the Range Finance Office, Pruitt (unchanged); `smoke_bank` map04c |
| IV | 2 | Darkmatter Accounts, the Operator (unchanged); `smoke_bank` map04d |

**16. A strong training loop + good chokes**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 8 routes, 36 spawns (unchanged) |
| M2 | 2 | 3 routes, 24 spawns; honest squads now live to r21–32 (QA_U10 §1.1) but the loop is unchanged |
| M3 | 2 | 15 spawns + 2 quay spawns, interval ×0.75 (`rounds.json map_overrides`); bot squads wipe r13 in the diesel holds (T-153) |
| I | 2 | 4 routes, 17 spawns, the cellar loop; soak act r1–6 stuck 25 events / 25 s, T-146 was 85 / 101 (T-155) |
| II | 1 | 7 spawns; Q-19 0/3: bots alone wipe at act r3–5 (QA_U10 §2 final batch) |
| III | 1 | 11 spawns; the one run that reached Act III wiped at r21 (QA_U10 §2) |
| IV | 1 | 8 spawns; T-158's soak: the bots bleed out in r30 on the arrival kit, the ring past 30 unproven |

**17. Lighting pass**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | T-061, `shots_map00.json` (unchanged) |
| M2 | 3 | T-062, `shots_map01.json`; the new landscape reads dark in software GL (`u10_map01/00_A_yard_ridges`) |
| M3 | 3 | T-063 + T-145; the hall's pendants and the pump plinths (T-154); `shots_map02.json` |
| I | 2 | T-146 + lights for the outlet screen, the breach and under the wing (T-155); no shots file; `u10_map04a/00` |
| II | 2 | T-147 + hidden rail colliders, fairings, the visible formation (T-156); no shots file; `u10_map04b/01_Tilt_bay` |
| III | 2 | T-148 + the ridge fog blend, towers that sweep up, the olive dish (T-157); no shots file; `u10_map04c/06_B_storm` |
| IV | 2 | T-149 + the terminator's shadow wall (T-158); no shots file; the known moire; `u10_map04d/11_T_night` |

**18. A campaign exit with a cutscene**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | THE CARTERS' ROAD (unchanged) |
| M2 | 3 | THE NORTH GATE + the Requiem ending (unchanged) |
| M3 | 3 | exfil r40 24 s/3 shots + the dive `m2_letzte_fahrt_dive` 34 s/5 shots and the Hale telegram card (`campaign.json`) |
| I | 2 | the boarding 38 s/4 shots; Wittkamp's line baked (WIT, OneCore); the card preloads Act II (T-155) |
| II | 2 | the crash 40 s/5 shots; `Campaign.preload_next` from the cutscene (T-156) |
| III | 2 | the rocket 40 s/5 shots; the transition's own lore line (T-157) |
| IV | 3 | `cancel_ending` 150 s with cards, `renewal_ending` 40 s, the act's card as the curtain; VO baked (T-158, T-166) |

**19. Relief squads (the living war, T-142)**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | Home Army + Soviet scouts (unchanged); `.smoke_logs/u10w_resume/smoke_squads.log` PASS |
| M2 | 2 | Home Army + Volkssturm (unchanged) |
| M3 | 2 | British commandos + a shore party (`squads.json map02`, unchanged) |
| I | 2 | a paratrooper stick + Volkssturm (unchanged) |
| II | 2 | the lead's equivalent: a formation of 4 bombers, one shot down per act, fighter passes at the wing (T-156 `formation`) |
| III | 2 | Groom Lake MPs (unchanged) |
| IV | 1 | the equivalent: 3 Darkmatter field units walk the far rim and never engage (T-158); dressing, not relief |

**20. Extra people with favours (T-143)**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | Lanz, Ebert, Hager (unchanged) |
| M2 | 3 | Brzezina + 2 miners, Roth, Seidl (unchanged) |
| M3 | 0 | `people_extra.json` has no map02 person; Petersen is a companion, Jessen a teller |
| I | 2 | Wendel (coal → the cellar side door opens for good), Brack (the signal → 2 train drops) (`people_extra.json`) |
| II | 2 | Ruhland (ledger → 1500 Scrip), Riedl on the intercom (log → intel ping, until act r4); no bodies |
| III | 2 | Dee (valve → a supply drop), Hale (talk-only, reactions) (`people_extra.json`, T-157) |
| IV | 2 | Pohl (the tag → 750 Scrip, `pohl_tag_read`) (`people_extra.json`, T-158) |

**21. The Jakub arc on this map**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | the cage, the breakout, the chalk (unchanged) |
| M2 | 3 | Jakub's Road, the miners' greeting (unchanged) |
| M3 | 1 | JAK_M2_ARRIVE_01/02 in `lines.json`, played by nothing (no `JAK_M2` in any .gd or map json); no spot of his own |
| I | 1 | JAK_M4A_ARRIVE/CHALK/FILE baked (T-166), played by nothing; no Thalbach scene (T-155 lists none) |
| II | 2 | JAK_M4B_LONDON_01 at the window (`map04b.json:318`), JAK_M4B_MARKS_01 at the racks (`flight_controller.gd:714`) |
| III | 2 | JAK_M4C_ROCKET_01 in the rocket cutscene (`campaign.json:521`) |
| IV | 2 | JAK_M4D_CONSOLE_01 and _PILCH_01 (`mondlicht_controller.gd:480`), _EARTH_01 at r6, _KEY_01 in the ending |

**22. An opening / arrival you remember**

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | `InnOpening` (unchanged) |
| M2 | 1 | an intro banner and Ammer's call (unchanged) |
| M3 | 1 | an intro banner and the Operator's "I can see you now" (`u09_map02/00_A_wide`); no arrival beat built |
| I | 1 | a banner, Jette's call; the Kranich's violet breath from spawn (`u10_map04a/08_spawn_glow`) is a landmark, not a beat |
| II | 1 | a 20 s arrival grace and a banner (unchanged) |
| III | 2 | `map04c.json groom.arrival`: a quiet spell on the salt before the first spawns, Dee's line (T-157) |
| IV | 2 | the arrival VO block, the airlock cycle, "there is no air" (unchanged) |

**23. Zone audio beds (sound per room)**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | 13 positional `audio_zone`s (unchanged) |
| M2 | 2 | `ambience/map01.json` 10 zone beds, synthesized (T-161 `gen_ambience_map01.py`); the mix is T-162's |
| M3 | 3 | 7 beds + 10 new one-shots (foghorn, chains, radio static); every bed 9 dB under a footstep (T-154 `amb_loudness`) |
| I | 2 | 8 beds + 13 one-shots + 10 new sounds (T-155); mixed by T-162 |
| II | 2 | 7 beds + 16 one-shots, the engine-pitch bed, London hush −16 dB (T-156) |
| III | 2 | 7 beds + its own base bed `ambient_map04c` (`audio.json music.ambient`), the jukebox (T-157) |
| IV | 3 | 6 beds, the vacuum rule and the SFX low-pass in vacuum (`AudioDirector.set_vacuum_bed`, T-158) |

**24. Minimap and pause map current** *(finalised at 40cb5676: T-162 re-baked all seven through WSL + Xvfb)*

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | `map00_crossroads/mapdata.json` baked 2026-11-02 14:37, 3 floors, 35 POIs (T-162); `check_mapdata.sh` PASS |
| M2 | 3 | `map01_kaltenbrunn/mapdata.json` baked 2026-11-02 14:40 after T-161's landscape, 4 floors, 49 POIs |
| M3 | 3 | `map02_totenhafen/mapdata.json` baked 2026-11-02 14:59 after T-153/T-154's nodes, 4 floors, 38 POIs |
| I | 3 | `map04a_thalbach/mapdata.json` baked 2026-11-02 15:01, 2 floors, 42 POIs (the lookout platform band) |
| II | 3 | `map04b_kranich/mapdata.json` baked 2026-11-02 14:29, the wingtip footprint, 31 POIs; `smoke_marks --map=map04b` PASS |
| III | 3 | `map04c_groomlake/mapdata.json` baked 2026-11-02 14:31 after the perch and levers, 2 floors, 36 POIs |
| IV | 3 | `map04d_mondlicht/mapdata.json` baked 2026-11-02 14:34 with the pads, crater and vent, 27 POIs; `smoke_marks` map04d |

**25. Crate / weapon-parcel drama**

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | 9 `Crate*` nodes in `map00.tscn` (4 spots + the drummer's); squad parcels (unchanged) |
| M2 | 3 | Herr Tamtam's march (unchanged) |
| M3 | 2 | 6 `Crate*` nodes in `map02.tscn`; drifting power-ups float off in a flood (T-153) |
| I | 2 | 6 `Crate*` nodes; Brack's train drops a Resupply twice (T-155) |
| II | 1 | 2 spots (the second on the blisters' east wall, T-156); the decompression's two ammo tins |
| III | 2 | 5 `Crate*` nodes; Dee's supply drop (T-157) |
| IV | 2 | 3 `Crate*` nodes in `map04d.tscn` (was 2) |

**26. Test coverage (launcher buttons, smokes, GUT files)** *(finalised at 40cb5676: T-162/T-163 added
`smoke_bots_u10`, `smoke_transitions`, `test_bot_u10`, `test_bot_u10_eggs`, `test_first_hints`, `test_citations`,
`test_npc_navmesh`, `test_transitions`, all shared across maps; no column moves)*

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | ~14 launcher buttons, 33 smokes name map00, 11 own GUT files (unchanged) |
| M2 | 3 | 6 buttons (+PAUL), 18 smokes (`smoke_paul`, `smoke_map01_world`), 7 own GUT (test_paul, test_map01_ambience, …) |
| M3 | 3 | 6 buttons (Spring Tide, Letzte Fahrt, sailing, Slender), 16 smokes, 11 own GUT files (tide_v2, kielholer, undertow, …) |
| I | 2 | 4 buttons (+air raid), 10 smokes, 6 own GUT (test_thalbach_act1, test_fliegeralarm, test_kranfuehrer, …) |
| II | 2 | 3 buttons (+wing walk), 12 smokes, 4 own GUT (test_act2_setpieces 15, test_flight, test_flight_sky, test_map04b_data) |
| III | 2 | 3 buttons (+dust storm), 11 smokes, 6 own GUT (test_groom_setpieces, …); `smoke_map04c_world` FAIL on master |
| IV | 2 | 3 buttons (+terminator), 10 smokes, 9 own GUT (test_mondlicht_u10, test_endings, test_account_manager, …) |

**27. Recorded voice on the map** *(finalised at 40cb5676: T-162 baked the Kielholer's 4 KLH lines and the 18
reserved Bolt/Sprocket/Vendelin lines; `missing` is 6 stage directions)*

| Map | Score | Evidence |
|---|---|---|
| M1 | 3 | 108 M0 files, all baked (`vo/audio_manifest.json`) |
| M2 | 3 | 67 M1 files + PAUL's 21 (OneCore placeholder, no real voice); all baked |
| M3 | 3 | 50 M2 files incl. RADIO_UBOAT_01..06 in German, SLN 20 and KLH 4 (OneCore, as PAUL); all baked (T-162 item 8) |
| I | 2 | 65 M4A files, all baked (T-166): 37 Kokoro, 28 OneCore placeholders (OPR 18, WIT 10) |
| II | 2 | 96 M4B files, all baked: 51 Kokoro, 45 OneCore (OPR 21, PA 22, WIT 2) |
| III | 2 | 88 M4C files, all baked: 37 Kokoro, 51 OneCore (DEE 18, HAL 10, OPR 19, FAS 4) |
| IV | 2 | 106 M4D files, all baked: 42 Kokoro, the rest OneCore (OPR 40, WIV 13, the reserved BLT/SPR/VEN 8 since T-162) |

**28. Pays well (Scrip per round)** *(finalised at 40cb5676: T-163 reports rounds and steps, no Scrip; unchanged)*

| Map | Score | Evidence |
|---|---|---|
| M1 | 2 | 5,105 after r8 (QA_U07 §6.5, unchanged) |
| M2 | 3 | 6,695 after r8 (QA_U07); 7,010 by r7 in T-153's 10-minute soak under the new settings |
| M3 | 3 | T-153's soak: P1 10,385 Scrip by r8 before, 9,605 after the overrides, vs Kaltenbrunn's 7,010 by r7 (one run each) |
| I | 2 | 2,745 spent per round to r10 (`summary_fernflug.csv`, unchanged); T-155's soak reports no Scrip |
| II | 1 | unmeasured past act r5: every Q-19 run wipes at act r3–5 (QA_U10 §2) |
| III | 1 | unmeasured: the one run into Act III wiped at r21 |
| IV | 1 | unmeasured: T-158's bots bleed out in r30 |

### 1.3 Shared systems (identical on every map, not scored)

The Marke glints and bonus (`enemies.json marke`, T-137), the Crucible and its tiers, the perk machines and the
Ledger Lager machine (one per map since T-141), the crate pool (`crate.json` is global), the ammo boxes (4–6 per
map), the special-round scheduler (Bellringer / Fliegeralarm / Druckabfall / Dust Storm / Solar Flare on the same
`rounds.json` rule), the campaign carry (`Campaign.on_players_spawned` for Maps 1–3, 13 `carry_flags` for the
acts), the pause tabs and the OBJECTIVES log, the loading card and the T-144 menu. They make every map better by
the same amount; they do not move a column against another.

## 2. "Only here" features per map (as built today)

A feature counts as "only here" when no other map has it **and** it is built to at least a 2 (a first version that
exists in data but asks nothing of the player, or has never been seen in a run, is listed in brackets and not
counted).

| Map | Only-here features (counted) | Not counted (first versions, design only) | Count |
|---|---|---|---|
| M1 Inn | the opening (the bar empties, the look-around, T-076); the Cousins (HB1); the survivors upstairs you arm; GRAVELIGHT ONE with Selwyn alive in the seat; the radio dial quest with Fasbender's full message; the Grounds and the distant war (T-052, T-080); the Helvetia cellar and the Old Cellar | — | **7** |
| M2 Kaltenbrunn | Requiem (13 steps, seeded); the Totenglocke; the Core heart, the three pylon holdouts and Heartstorm; the 25 s lift ride and the depth grade; Lanterns Down Below; KB-4471; Herr Tamtam's march | PAUL (designed) | **7** |
| M3 Totenhafen | the tide (every 3rd round, wading, catwalk spawns, forecast VO); U-1047's interior with the Crucible in the torpedo room; the sea beds from real recordings and the storm card | the Ballast carry ("simple first version": lift, carry, hook one coffin for the power; no choice, no reward); the signal lamp (always on, nobody mans it); the Kielholer (deferred); LETZTE FAHRT, the Undertow (design only, UPDATE_10 §2) | **3**, two of them presentation |
| Act I Thalbach | the Fliegeralarm (impact circles, Fallschirm-Gänger, `test_fliegeralarm`); the boarding (the ramp, "I did not do that", the wing rolling out); the Kranich in its hangar | Der Kranführer (in data, never seen in a soak or capture); the wind tunnel (a prop, not yet a trap or a shortcut); the rivet line and the air raid's collapse (design only, UPDATE_10 §3) | **3**, one of them a cutscene |
| Act II der Kranich | turbulence that pushes everyone (`Player.external_push`); the breaches that suck zombies out and seal; the London window; the bomb run (six racks, six cities); Druckabfall; the Bordschützen climbers; FlightSky's legs | Der Bordwart (never seen in a soak); the wing walk, decompression ammo drops (design only) | **7** |
| Act III Groom Lake | the dust-storm round; Burrowers, Canaries, Jumpjockeys; the moving wreck fire; the Lodestone build; Peg's choice and Hale behind glass; Fasbender's radio scene; the rocket launch sequence | The Test Pilot (never seen in a soak); HB4 (reserved); the radar ping (design only) | **7** |
| Act IV Mondlicht | 0.38 g and the air gauge in vacuum; the Earth going violet city by city; the Account Manager who never dies and the CANCEL vote; the two endings with cards; the airlock cycles; Pilch's hand under the glass; the Solar Flare | the terminator, the meteor shower, the Lodestone fling into the shaft (design only, UPDATE_10 §3) | **7** |

**Plainly:** no column is under three today, but **Totenhafen's three are the thinnest in the game**: one
gameplay system (the tide, which floods one zone and the pumps cannot touch) and two pieces of presentation. Its
Ballast, signal lamp and Kielholer are the "only here" features the design promised, and none of them is built
past a stub. **Act I's three** are a special round, a cutscene and a landmark; its boss has never been seen running.
The §1.3 rule needs three "only here" features **that a player can act on**, so by that reading Totenhafen has
**one** (the tide) and Act I has **one** (the Fliegeralarm); Acts II–IV and the reference maps have at least four
each.

### 2.1 "Only here" features as built at FINISH (2026-11-02, db4c9ef6)

The same rule as above, read the strict way §1.3 needs it: a feature counts only if **a player can act on it** (a
choice, a hold, a switch, a climb, a weapon, a quest step), it exists on no other map, and a smoke, test, run or
capture shows it. Presentation-only features and first versions that ask nothing are listed in brackets.

| Map | Counted (what the player does; where it lives) | Not counted | Count |
|---|---|---|---|
| M1 Inn | the opening you walk through (`map00_opening.json`); arming the survivors upstairs (`map00_survivors.json`); handing Selwyn a gun (`trapped_pilot.gd`); the radio dial quest (`quests/map00_radio.json`); the Cousins (`cousins_round.gd`); the Old Cellar and Jakub's breakout (`companion_jakub.json`) | the Grounds and the distant war (presentation) | **6** |
| M2 Kaltenbrunn | Requiem's 13 steps (`quests/map01_requiem.json`); the Totenglocke build (`weapons.json`); the pylon holds and Heartstorm (`pylon.gd`); the lift ride (`map01.json lift`); Lanterns Down Below and KB-4471 (`quests/map01_song.json`, `_wren_tag.json`); PAUL: bottles to cool him, the neck from behind, his retreat clock (`paul.gd`, `paul_rage.gd`, `smoke_paul`); Herr Tamtam's march | the living world of T-161 (presentation) | **7** |
| M3 Totenhafen | Tide v2 with the Pumpenschalter crank: 30 s at ×2 spawns to shorten a flood, wading, sparking cables (`pump_crank.gd`, `tide_controller`, `smoke_tide2`); Ballast v2: carry melee-and-pistol, load for Scrip or dump at the sea stairs for a Glasshide and the shard (`totenhafen_ballast.gd`, `ballast_dump.gd`, `smoke_ballast2`); the signal-tower searchlight you man (`searchlight.gd`, MAN_SEARCHLIGHT mark); the Kielholer grab: shoot the arm, knife free, the diver's glass (`kielholer_controller.gd`); THE UNDERTOW build and MAELSTROM (`undertow_parts.gd`, `smoke_undertow`); LETZTE FAHRT: the cipher from three radios, four log pages, three diesel holds, the key, the curtain (`cipher_machine.gd`, `lf_radio.gd`, `lf_page.gd`, `diesel_holdout.gd`, `boat_key.gd`); the sail: the helm, the deck hold, the dive (`uboat_sail.gd`, `smoke_sail`); DER KIELHOLER (`kielholer.gd`, `smoke_kielholer`); THE SLENDER's watch: stay in the lamp pools, tear your page, the fuse boxes (`slender.gd`, `watch_meter.gd`, `smoke_slender`); the Crane Drop lever (`traps.json crane_drop`) | the living world of T-154, the sea beds, the lighthouse, the cutter slip (presentation; the hidden letter is an item) | **10** |
| Act I Thalbach | the air raid: get out of the roof bay, the route changes, fires to avoid (`thalbach_raid.gd`, `smoke_air_raid`); the rivet line lever (`trap_rivet_line.gd`, `smoke_rivet_line`); the wind tunnel: a trap, a 3 m/s push, the plenum-hatch shortcut (`wind_tunnel.gd`, `tunnel_hatch.gd`, `smoke_wind_tunnel`); the Fliegeralarm (`test_fliegeralarm`); the lookout platform climb (T-155 verticality); Wendel's coal and Brack's signal (`people_extra.json`, `smoke_people_extra`); the boarding | Der Kranführer (in data, never seen in a run); the living world (presentation) | **7** |
| Act II der Kranich | the wing walk: climb out, clip in, the tilt, the wingtip locker's discount token (`wing_walk.gd`, `clip_point.gd`, `wing_chest.gd`, `smoke_wing_walk`); the tilt you can use: sliders that kill, 3 s warning (`kranich_tilt.gd`, `tilt_slider.gd`, `smoke_turbulence`); decompression: hold a rail or be downed, two ammo tins (`decompression.gd`, `rail_grip.gd`, `smoke_decompression`); the aux bus to find (`aux_bus.gd`); the bay doors lever (`bay_doors_trap.gd`); The Crew's Tags (`quests/map04b_crew_tags.json`); the London window; the bomb run; Druckabfall; the Bordschützen climbers | Der Bordwart (reached, never killed, QA_U10); the formation and the sunrise (presentation) | **10** |
| Act III Groom Lake | the dust storm: walk, don't sprint, the stalkers hear you (`sound_hunter.gd`, `smoke_dust_storm`); the collapses that take ground off the navmesh and open the gap (`groom_controller.gd`, `smoke_wreck_collapse`); the radar perch and the ping (`tower_ladder.gd`, `radar_dish.gd`, `smoke_radar_ping`); the Lodestone build (`test_lodestone`); Peg's choice and Hale behind glass (`pegs_choice.gd`, `people_extra.json` hale); Dee's cage and her valve (`cage_item.gd`, `people_extra.json` dee); the fuel dump (`trap_fuel_dump.gd`); the jukebox with power (`jukebox.gd`); the rocket launch (`test_rocket_sequence`); Burrowers, Canaries, Jumpjockeys (`test_groom_enemies`) | The Test Pilot (never seen in a run); the Milky Way, wildlife, B-29s (presentation) | **10** |
| Act IV Mondlicht | the terminator: cross into night and pay air, the visor on the day side (`terminator.gd`, `smoke_terminator`); the heater breaker (`heater_switch.gd`); jump pads and the orbit fling (`jump_pad.gd`, `moon_lowg.gd`, `smoke_low_g`); the meteor shower: shelter in the modules (`meteor_shower.gd`, `smoke_meteors`); the vent lever (`shaft_grate_lever.gd`); Pohl's tag at the console (`tag_slot.gd`); Earthrise reversed by the CANCEL steps (`smoke_earthrise`); the Account Manager and the CANCEL vote; the two endings (`test_endings`); the airlock cycle | the field units on the rim (never engage); the dust settling (presentation) | **10** |

**Plainly:** every target column now has at least seven "only here" features a player can act on, against the
baseline's one (Totenhafen) and one (Act I). The §1.3 "three" condition passes everywhere. The features that are
still *in data only* are the four act bosses (Kranführer, Bordwart, Test Pilot, Account Manager): no soak or capture
has shown one running, so they are not counted here and row 13 stays at 2 for each act.

## 3. The target line and the gap per column

**Target (§1.3):** each of Totenhafen, Act I, Act II, Act III and Act IV scores at least Map 1's total **and**
Kaltenbrunn's total, so **≥ 71 of 84**, and has three "only here" features a player can act on.

71 of 84 means a column can afford at most 13 points below perfect: every row at 2 and 15 rows at 3, or no row below
2 and most at 3. So **every 0 and 1 has to go**, and most 2s have to become 3s. The rows at 0–1 are listed per
column below with the work-order section that pays for them.

| Column | Total | Gap to 71 | Rows at 0 | Rows at 1 |
|---|---|---|---|---|
| M3 Totenhafen | 45 | **26** | 7 mini-quest, 12 main egg, 20 extra people | 3 reactive, 10 holdout, 11 wonder weapon, 13 boss, 21 Jakub, 22 opening, 26 tests, 28 pays |
| Act I | 43 | **28** | 20 extra people | 3 reactive, 6 room story, 7 mini-quest, 8 verticality, 10 holdout, 11 wonder weapon, 21 Jakub, 22 opening, 24 minimap, 26 tests, 27 VO |
| Act II | 37 | **34** | 7 mini-quest, 14 trap, 19 squads, 20 extra people | 6 room story, 8 verticality, 9 power-on, 11 wonder weapon, 16 loop, 21 Jakub, 22 opening, 24 minimap, 25 crate, 26 tests, 27 VO, 28 pays |
| Act III | 43 | **28** | — | 3 reactive, 7 mini-quest, 8 verticality, 10 holdout, 14 trap, 16 loop, 20 extra people, 22 opening, 23 audio beds, 24 minimap, 26 tests, 27 VO, 28 pays |
| Act IV | 39 | **32** | 9 power-on, 14 trap, 19 squads, 20 extra people | 3 reactive, 5 person, 7 mini-quest, 11 wonder weapon, 16 loop, 21 Jakub, 24 minimap, 25 crate, 27 VO, 28 pays |

### 3.1 Where to spend, per column

**Totenhafen (26 points).** The three zeros are one job: the main egg LETZTE FAHRT (§2.2) with a step graph like
Requiem's gives row 12 its 3, and its side threads (the teletype cipher, the boat's log) are the mini-quest for
row 7; the Marinekasse's Jessen and a second person (Hinnerk's scene, a cannery survivor) with Talk cards and
favours fill row 20. The ones: the Kielholer boss (row 13), the Undertow (row 11), the three diesel holdouts
(row 10), the Map 1 ambience system in `map02_ambience.json` with the round-10 lighthouse, the round-15 cutter and
the raid (rows 1, 2 and 3 together), two quay spawns and the spawn pressure that lifts Scrip per round to at least
Kaltenbrunn's 6,695 after r8 (row 28, measured by the same `QA_U07 §6.5` agent), a Jakub line in the pens (row
21), an arrival beat on the quay (row 22), and smokes for each new system plus launcher buttons (row 26). The
2s that are cheap 3s: Ballast v2 with the choice and the Operator's two moods (row 5's Petersen scene and the
"only here" count), the power-on with the docks draining and U-1047 going red to white (row 9), story props as
real StoryProps rather than labels (row 6), the Crane Drop trap (row 14).

**Act I (28 points).** The air raid at act round 8 with the roof collapse is rows 2, 3 and 10 at once (a timed beat,
reactive debris, a holdout as the route changes); the rivet line and the wind tunnel as a trap are row 14's 3; a
`map04a_ambience.json` with the windows going dark, the bell, the test jet and the train is rows 1 and 3. Row 6
needs 4+ real `story_props` rows (none exist); row 7 needs Jette's logbook findable with its VO recorded; row 20
needs at least one person with a Talk card (a Siedlung family in the cellar, a railwayman at the Bahnhof); row 8 is
the cheapest point on the map: open the crane rails or the church tower to the player. Rows 24, 26 and 27 are
upkeep: re-bake the minimap, write smokes per set-piece, record the 52 M4A lines.

**Act II (34 points, the biggest gap).** The act is rich in "only here" and poor on the general bar, so the work is
breadth: the wing walk is rows 8, 10 and 3 (verticality, a holdout, wind and clouds); turbulence you can use and
decompression that drops ammo are row 3 and row 14 (the act's trap is the plane); a `map04b_ambience.json` with the
sun crossing, the coast and the other bombers is row 1's 3. Row 6 needs 4+ story props (none); row 7 needs a side
quest anyone can do (none today); row 9 needs a switch you can find (the aux bus as a visible panel with a sweep);
row 16 is Q-19, the bots alone through Act II (§7.4), and until a soak passes act round 4 rows 16 and 28 stay at 1;
row 25 has one crate spot. Rows 19 and 20 are structural zeros (no squads in flight; nobody new aboard): the
honest fix is a person aboard (Riedl before he is the Bordwart, Ruhland with the cash box as a Talk card), not a
squad.

**Act III (28 points).** No zeros, thirteen ones: the dust-storm round every 5th act round with stalkers hunting by
sound (rows 2, 3, 10), the burning wreck as a changing arena (row 3 and row 4's 3), the radar dish that turns and
pings the minimap when powered (rows 9 and 24); a `map04c_ambience.json` and its own base bed (row 23 is the only
act bed that falls back to the Inn's wind); row 7 (Dee's cage) needs VO and findability; row 14 needs a trap with a
show (one live wire today); row 20 is Hale and Dee as Talk cards; row 22 an arrival on the salt; row 26 the
burn-console smoke that fails on master; row 16 and 28 need a soak that reaches it.

**Act IV (32 points).** Four zeros: row 9 is the terminator switch (the suit heaters, the relay mast pulsing: give
the act a thing you turn on); row 14 the meteor-shower round and the Lodestone fling into the shaft as the act's
trap; rows 19 and 20 are structural (no squads on the Moon) so the points come from row 5 and 20 together: a
person at the relay (a retained Darkmatter clerk, Dee's voice given a body in the capsule). The ones: low gravity
done right with jump pads and long glides (rows 3, 8, 16), the Earthrise beats (row 2's 3), the `map04d_ambience`
with dust settling and the mast pulsing (row 1), Jakub's line at the console (row 21), the 71 M4D lines (row 27),
the minimap (row 24), a soak that reaches the finale (rows 16, 28).

### 3.2 The honest ceiling

Three rows are hard for structural reasons and the lead should decide whether the target counts them: **19 relief
squads** cannot exist in flight or on the Moon (Acts II and IV lose 3 each unless the rule is "a living war or its
equivalent": other bombers and fighters in flight, Darkmatter field units on the Moon); **28 pays well** needs a
soak that reaches each act, which needs Q-19 fixed first; **27 recorded voice** needs the owner's PC voices (the
cloud cannot bake them: `tools/cloud_setup.sh --tts` reinstalls Kokoro but 279 Map 4 lines are marked "bake on the
PC"). If §1.3 is read with row 19 waived for Acts II and IV, their gaps are 31 and 29.

### 3.3 After the re-score (2026-11-02, db4c9ef6)

**The target moved.** §1.3's target is the higher of the two re-scored reference totals: Map 1 stays at **71**, Map 2
rises to **77** (finalised at master 40cb5676 with T-162's minimap re-bake), so the bar is **≥ 77**.

| Column | Total | Gap to 77 | Rows at 0 | Rows at 1 | §1.3: ≥ target | ≥ 3 "only here" actable | No seed row at 0 | Verdict |
|---|---|---|---|---|---|---|---|---|
| M3 Totenhafen | 69 | **8** | 20 extra people | 21 Jakub, 22 opening | no | yes (10) | yes | **FAIL** (total) |
| Act I | 59 | **18** | — | 11 wonder weapon, 21 Jakub, 22 opening | no | yes (7) | yes | **FAIL** (total) |
| Act II | 59 | **18** | — | 11 wonder, 16 loop, 22 opening, 25 crate, 28 pays | no | yes (10) | yes | **FAIL** (total) |
| Act III | 60 | **17** | — | 16 loop, 28 pays | no | yes (10) | yes | **FAIL** (total) |
| Act IV | 61 | **16** | — | 11 wonder, 16 loop, 19 squads, 28 pays | no | yes (10) | yes | **FAIL** (total) |

Against the **baseline target of 71** (the number the work order's sections were planned to): Totenhafen 69 misses by
2; the acts miss by 10–12. Against the **seed rows alone** (the owner's 18): Totenhafen 48 beats
both references' baseline 44 and sits 3 under Kaltenbrunn's re-scored 51; the acts are at 40–41, where the
baseline references stood at 44.

**Rows sent back.** Section 6's rule, applied by the lead's re-score: every row where Totenhafen or an act scores
**below both** re-scored Map 1 and Map 2. One line per row, the columns that fall under and the owning work-order
section. The three rows that move the most points for the least work are marked **(first)**.

| Row | Below both M1 and M2 | Send back to | What would lift it |
|---|---|---|---|
| 4 hero landmark | Act I (2) | §3 Act I | a clear Kranich silhouette from the lookout (T-155 "not done") or a Forward+ capture that shows one |
| 5 person | M3, Act II, Act IV (2) | §2.2, §3 Acts II/IV | play PET_LF_TRAPPED_01 and the stair scene code; a body for Riedl/Ruhland; Pohl's crew model |
| 6 room story | Acts I, II, III (2) | §3 Act III **(first)** | Act III has 2 story props against the order's 4+; Acts I/II have 4 (Map 2 has 28 intel) |
| 13 boss | Acts I–IV (2) | §7 bots / §3 | one soak or capture per act boss that shows him running (a `--skip-to-act` run with god mode counts) |
| 15 bank | M3, Acts I, III, IV (2) | §2.2, §3 | a favour or a reaction per teller (Act II's Ruhland has one and scores 3) |
| 16 loop | Acts II, III, IV (1) | §7.4 **(first)** | Q-19: a bots-alone run past act round 5 (II), into Act III past r21, past r30 on the Moon |
| 17 lighting | Acts I–IV (2) | §3 | a `lighting/shots_<act>.json` per act and a Forward+ set of the same cameras (the owner's OK) |
| 18 exit | Acts I, II, III (2) | §3 | the act cutscenes are unchanged since T-146..T-148; cast voices instead of OneCore for Wittkamp |
| 19 squads | Act IV (1) | §3 Act IV | field units that matter (engage or cover, a parcel), per the lead's "equivalent" ruling |
| 20 extra people | M3 (0), Acts I–IV (2) | §2.2 **(first)** | Totenhafen has nobody in `people_extra.json`: Jessen or a cannery survivor with a Talk card and a favour |
| 21 Jakub | M3 (1), Act I (1), Acts II–IV (2) | §2.2, §3 Act I | play JAK_M2_ARRIVE_01/02 and JAK_M4A_* (baked, unused); a spot of his own on each map |
| 24 minimap (p) | Act IV (1) | §6.4 | lands with T-162 (all seven re-baked) |
| 25 crate | Act II (1) | §3 Act II | a third spot or a parcel event aboard |
| 26 tests (p) | Acts I–IV (2) | §6 / §7, §3 Act III | one launcher button per set-piece smoke (the acts have 3–4 against Map 2's 6); `smoke_map04c_world` FAILs on master: the perch's zombie climb link does not reach the deck |
| 27 voice (p) | M3 (2), Acts I–IV (2) | §6.8 / the owner | the Kielholer's 4 lines (T-162 bakes them); cast voices for the Operator, PA, WIT, DEE, HAL, WIV |
| 28 pays (p) | Acts II, III, IV (1) | §7.4 | the same soak as row 16, with Scrip after act r8 recorded |

After the merges (40cb5676) two entries above no longer fall under both references and are kept only until the
send-back pass closes: **row 24** (Act IV is 3) and **row 27 for Totenhafen** (3; the acts stay at 2 on their
placeholder speakers). Rows **1–3, 7–12, 14, 22, 23** have no column below both references (where Map 2 is itself
at 1 or 2, a 2 is not "below both"). Row 11 (wonder weapon) is at 1 on Acts I, II and IV, the same as Map 1, and is not sent back; it is
the honest ceiling of 3.2: one wonder per campaign branch, the Undertow on Totenhafen and the Lodestone on Act III.

## 4. Scoring notes the build workers should know

- Several Map 1 / Map 2 3s are **cheap to copy**: the `MapAmbience` + JSON system (row 1), `ExtraPerson` Talk
  cards (row 20), the `PowerSwitch` config table (row 9), the chandelier/ore-cart/live-wire trap scripts with an
  art `style` (row 14), `lighting/shots_<map>.json` for row 17's 3. The acts' rebuild already proved the pattern
  (T-146's traps, T-145's ZoneAmbience).
- The **captures favour the acts' interiors and punish the outsides**: Compatibility software GL draws no
  volumetrics or GI, so Totenhafen's quay wide (`00_A_wide` after) barely differs from before even though T-145
  added a cutter, hut roof and sea, while Act I's courtyard (`00_A_wide` after) reads as a place. A PC Forward+
  capture of the same cameras is the fairer evidence for row 4 and row 17 at re-score time (the owner's OK is
  needed for a rendered window).
- **Totenhafen is the nearest to the bar on dressing and the furthest on systems**: its 3s are lighting, audio
  beds and the minimap (presentation); its 0s are the egg, the quest and the people (play).
- **Act II is the opposite**: the most "only here" of any map and the lowest total, because every act-wide system
  (squads, people, story props, a switch, a trap, a crate) is missing or singular.

## 5. How to re-score

The re-score at FINISH (§1.3) and the blind review (§1.4) use the same sources and rules as section 0:

1. **Same capture sets, same cameras.** `data/gravelight/capture_cams.json` sets `u09_map02`, `u09_map04a` ..
   `u09_map04d` (3 cameras per zone, eye 1.62 m, power on) and `u09_ref` (the bar), rendered the same way as the
   `u09_after` set: `sh tools/wsl_godot.sh --path . res://tools_src/capture.tscn -- --set=<set>
   --out=<dir>` (WSL + Xvfb, Compatibility, invisible), into `morning/screenshots/u10_after/<set>/`. New cameras for
   new set-pieces are added to the same sets (not a new set) so before/after pairs stay comparable; add a
   `u10_before` copy of `u09_after` before the first UPDATE 10 merge. A Forward+ set on the PC (with the owner's
   OK) is a second opinion, never a replacement. Totenhafen's UPDATE 10 systems (T-153) have their own set
   `u10_map02` (14 cameras: the spring tide, the crank, a cable, the dump, the searchlight, the Crane Drop, a
   Kielholer, the cipher and a log page, a diesel hold, the Undertow, the curtain, the helm, mid-sail), rendered
   the same way into `morning/screenshots/u10_after/u10_map02/`.
2. **Same soak and QA numbers.** `tools/ai_soak.sh --scenario=totenhafen|fernflug --runs=3 --max-minutes=20
   [--skip-to-act=N]` (note `--scenario=`; the bare word runs Map 1) and the botmode baselines of QA_U08's table
   re-run with the same seeds; Scrip after r8 for the same weak agent as QA_U07 §6.5; bot egg completions per map
   out of 3 runs; `census_map --set=<set>` peaks against C4; the smoke list per map from `tools/run_smokes.sh`.
3. **Same data inventory.** Count again: `story_props.json` and `intel.json` rows per map, `quests/*.json` files
   and steps per map, `bosses/*.json`, `traps.json`, `people_extra.json`, `companions.json`, `squads.json`,
   `ambience/<map>.json` and a Map-1-style `<map>_ambience.json`, `DecorHit`/reactive nodes in the `.tscn`,
   `power` blocks, `climb_links`, `data/maps/<id>/floor_*.png` dates, `vo/audio_manifest.json` lines without
   audio, launcher buttons in `ui/dev_launcher.gd`, `smoke_*` and `tests/unit/test_*` files per map.
4. **Same rules.** 0/1/2/3 as in section 0; unmeasured is 1; a feature in data that no run or capture shows is 1;
   shared systems stay out of the totals; evidence under 120 characters per cell; the Map 1 and Map 2 columns are
   re-scored too (UPDATE 10 §5 gives Kaltenbrunn a living world, which raises the bar; the target is the higher of
   the two re-scored totals).
5. **Acceptance of §1.3:** each of Totenhafen, Act I, Act II, Act III and Act IV has a total ≥ max(Map 1, Map 2)
   **and** ≥ 3 "only here" features a player can act on (section 2's rule), **and** no seed row (1–18) at 0. The
   FINISH merge is blocked until all five columns pass. Record the re-scored table as a second block under section
   1.1 headed "Re-score at FINISH (date, commit)" and keep this baseline above it.

## 6. Blind review (§1.4)

*To be filled at the end of UPDATE 10 by a fresh Fable reviewer that has not seen the build work.*

**Method.**
- The reviewer gets: this file with **every score column blanked** (a copy with the numbers removed, the evidence
  cells kept), the `u10_before` and `u10_after` capture sets for Totenhafen and each act plus the `u09_ref` bar
  set, and a **2-minute capture video per map** (the same cameras, walked, with sound; recorded through
  `tools/wsl_godot.sh` or on the PC with the owner's OK; one file per map in `morning/clips/u10_blind/`).
- The reviewer does not read `docs/DECISIONS.md` T-15x, the morning report or any branch diff before scoring, and
  scores Map 1 and Map 2 from the same kind of evidence so the bar is scored blind too.
- Files produced for the review (T-167; all rendered through `tools/wsl_godot.sh`, Compatibility renderer, software
  GL): stills `morning/screenshots/u10_after/u09_map02/` (21, re-rendered after T-153) and
  `morning/screenshots/u10_after/u10_map02/` (14, the T-153 systems); clips `morning/clips/u10_blind/map00.mp4`
  (set u05), `map01.mp4` (u10_map01 + u09_ref's Kaltenbrunn cameras), `map02.mp4` (u09_map02 + u10_map02),
  `map04a.mp4` .. `map04d.mp4` (u09_map04x + u10_map04x), each 2 minutes at 1280x720, 24 fps, with the game's audio
  (beds, VO, the round), and beside each its 12-frame `<map>_contact.png` and the tour's `<map>.log`. Made by
  `tools/wsl_clip.sh <sets> 120 morning/clips/u10_blind <map>` (gravelight/tools_src/clip_tour.gd).
- The reviewer fills a 28-row table per map (0–3 with a one-line reason each), lists each map's "only here"
  features as it sees them, and marks every row where Totenhafen or an act scores **below both Map 1 and Map 2**.
- Any such row goes back to its build worker before FINISH; the reviewer re-scores only those rows after the fix.
- The verdict is recorded here, scores side by side with the lead's re-score, with the reviewer's "only here"
  counts and a one-paragraph summary per map.

**Verdict.** *(empty)*

| # | Feature | M1 | M2 | M3 | I | II | III | IV | Rows sent back |
|---|---|---|---|---|---|---|---|---|---|
| | *(filled by the blind reviewer)* | | | | | | | | |
