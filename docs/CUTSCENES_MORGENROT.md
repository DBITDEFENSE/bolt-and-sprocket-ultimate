# CUTSCENES_MORGENROT — shot lists for the Map 3 endings (ULTIMATE PROMPT v2 §5–§6)

Every cutscene is in-engine, built on the campaign cutscene player (DECISIONS T-033: data-driven shots `{t, from, to, look, fov, fx, vo, vo_at}` in `data/gravelight/campaign.json`-style tables, letterbox, subtitles), skippable after the first viewing, saved to the Archive's cutscene gallery. Characters shown are **the players' chosen characters** (lines for all six, Bolt and Vendelin included: VO_SCRIPT §11). Each ending runs **90–150 s**. Rule reminders (v2 §0): civilians only as skylines, shelters, sirens and sky; no gore in the launch; rocket detail stays at placard level; the Wiederkehr mark only (`ART_FACTIONS.md`).

Camera positions are in the Morgenrot map frame (`MAP3_MORGENROT.md` §2; z north-positive is the peak). All timings are targets for the shot tables, not code.

---

## 1. ABORT ENDING — "Morgenrot" (canon)   ~140 s

Trigger: `map03_letztes_licht` step 10 completes before the 5-minute countdown ends. The round loop pauses (`RoundManager.stop()`), zombies dissolve, the sky holds at the dawn fraction the clock reached.

| t | Shot | Camera | Action / VO | FX |
|---|---|---|---|---|
| 0.0 | 1a The keys | Leitstand interior, low behind the two key switches, looking up at the Zählwerk | Two hands turn the keys (the players' characters' hands); the red lamps go dark one by one; the flip boards clatter and **freeze at 00:03**. | lamp flicker-out; board clatter SFX; the siren layer cuts |
| 7.0 | 1b The periscope | through the Leitstand periscope, ringed vignette, on the Sonnenspeer | The engines cough, sputter, and die. The gantry groans. | engine cough stinger; gantry metal |
| 14.0 | 2a The slide | Kessel ring road, wide, the gantry centre-frame | The rocket **leans**, then slides back down into its launch pit; the gantry arms fold after it. | physics: the Sonnenspeer node tweens down 18 m over 6 s; dust |
| 22.0 | 2b The bloom | crater rim, high, looking down | Its Nachtglas fire is swallowed by the mountain in a contained **violet bloom**; the crater floor collapses inward around the pit. | violet fog volume swell then collapse; shake 0.6; the floods die |
| 32.0 | 3a Reinholt | gantry mid-level, close on Reinholt broken against the rail | She reaches toward the Liesl apparition as it fades; for the first time it looks like a little girl and not a weapon. `REI_END_01`. | the apparition's drummer stops; music: solo piano |
| 40.0 | 3b The choice (interactive, no time limit; co-op majority vote, solo your choice) | same, over the characters' shoulders | Prompt: **Let her go to Liesl** / **Pull her out**. | letterbox stays; the vote UI from the exfil beacon |
| — | 3c-A Let her go | close on Reinholt | She steps into the collapsing light. *"Mein Schatz."* (`REI_END_LETGO_01`) | light swallows the frame to violet-white |
| — | 3c-B Pull her out | two characters haul her over the rail | She lives, a prisoner; she looks at the pit and says nothing (`REI_END_PULLED_01`, one breath). | the floods come back on, cold white |
| 52.0 | 4a The last car | inside the gondola, dawn truly red over the Alps through the window | The last cable car descends. Wren reads the six names from her chalk-mark list, ends on **Tomasz Nowak**, and closes the notebook (`WRN_END_NAMES_01..06`, `WRN_END_CLOSE_01`). If no one plays Wren, Dutch reads them from her notebook. | choral swell begins under the names |
| 78.0 | 5a Peg's hands | close on Peg's hands at the window, the fragment | **Peg's choice** (whoever plays Peg; nobody → she chooses for herself, default *destroy*): **Destroy** / **Keep**. | |
| — | 5b-A Destroy | the window | She drops it into the abyss. `PEG_END_DESTROY_01` ("Orders are orders. These were the wrong ones.") | the fragment's violet dot falls into the fog |
| — | 5b-B Keep | the window | She pockets it. Cut to a sealed British crate stamped with a London address, D/LANTERN diamond, on a dock at dawn. `PEG_END_KEEP_01` | |
| 90.0 | 6 Epilogue cards | 2D, period-newspaper style, one per character present (+ Fasbender: alive at the summit / died on the mountain, per step 7; + Reinholt: testimony / "missing") | Text cards (WRITING: VO_SCRIPT §11.6). | typewriter SFX |
| 120.0 | 7 The Operator | black | Quieter than ever, in Sable Vantage's real voice: *"Regional rollout... postponed. We'll be in touch."* (`OPR_END_ABORT_01`) | |
| 125.0 | 8 Credits | the Gravelight saga credits over the summit at full dawn | | the "Morgenrot" theme |

## 2. LAUNCH ENDING — "Vergeltung" (non-canon)   ~120 s + Aftermath

Trigger: the Launch Clock hits zero (or the 5-minute countdown runs out). **Shots 1–2 render live** from wherever the players stand (the map's sightlines), then the cutscene player takes the camera.

| t | Shot | Camera | Action / VO | FX |
|---|---|---|---|---|
| 0.0 | 1 Zero | the player's own view | The Zählwerk hits **00:00** (audible from anywhere via the PA); the whole map shakes; the German PA counts the last five (`PA_COUNT_05..01`, subtitled). | shake 1.0 ramp; siren full |
| 6.0 | 2 The climb | live, then cut to the crater rim | The Sonnenspeer climbs on a violet-white column; three salvo rockets follow from the forest **unless sabotaged**: a toppled rocket stays toppled, and the sequence **respects which were sabotaged** (shots 5–6 skip saved cities). | the gantry arms fall away; exhaust fog |
| 24.0 | 3 Europe | a stylized map-table-meets-sky: a curved Europe at night, the arcs drawn in violet | Arcs over the continent. Fasbender on the radio, if alive: `FAS_END_LAUNCH_01`. | |
| 40.0 | 4a London | London before dawn: barrage balloons, searchlights, a generic but unmistakable skyline (dome, river, bridges); people looking up from a shelter entrance as the sirens rise | No faces in close-up; no gore. | sirens |
| 52.0 | 4b The burst | the sky above the skyline | The warhead air-bursts high; **violet fire falls like snow** over the rooftops. **Cut to silence.** | all audio out for 3 s |
| 60.0 | 5 Antwerp / Paris | one shot each, only for the unsabotaged rockets: a harbour skyline / a river skyline, the same falling fire, shorter | | |
| 78.0 | 6 Morgenrot | the Kessel rim, the sky violet instead of red | The Operator: *"Distribution successful. Thank you for your continued engagement."* (`OPR_END_LAUNCH_01`) | violet ash begins to fall and never stops |
| 90.0 | 7 Aftermath card | 2D | "VERGELTUNG" title; the match continues. | |

**Aftermath state** (`map03.json "aftermath"`): violet ash on the map permanently (a Snowfall instance with the violet mote material), zombie health scaled one round step higher, LUFTALARM every 3–4 rounds, perks +25% ("market demand", the Operator says so once), the "Vergeltung" calling card after 5 more rounds. The main egg is closed; the Moon egg's step 6b stays open.

## 3. MOON ENDING — "Mondlicht"   ~150 s

Trigger: Moon step 6a (the Kessel held through Reinholt's fight and the clock reaches zero re-targeted to MOND).

| t | Shot | Camera | Action / VO | FX |
|---|---|---|---|---|
| 0.0 | 1 The rim | the Kessel rim, every player character in frame, dawn | The Sonnenspeer launches; everyone watches. One line per character present: Dutch *"Huh. Well, nobody lives there."* (`DUT_END_MOON_01`), Deacon *"Lord, forgive us for littering."* (`DEA_END_MOON_01`), Peg, Wren, Bolt, Vendelin (VO_SCRIPT §11.5). | exhaust, shake 0.5 |
| 14.0 | 2 The ride | the camera rides the rocket: through the cloud deck, past the curve of the Earth, into stars | **Hold the silence.** Then cut. | audio out; stars shader |
| 44.0 | 3 The strike | the Moon filling the frame | The warhead strikes. A violet bloom spreads across the grey and leaves a **long curved violet crack across the lunar face that looks exactly like a smile.** | |
| 60.0 | 4 The answer | the same, a beat | Far across the surface, **a single violet light blinks back.** | one blink, then dark |
| 66.0 | 5 The Operator | black | Delighted: *"Delivery rerouted. A new market has been... discovered."* (`OPR_END_MOON_01`) | |
| 72.0 | 6 Callbacks | the rim again | Bolt present → Sprocket: *"Bolt. BOLT. I've seen that crack before. There was a MEMO about that crack."* (`SPR_END_MOON_01`). Vendelin present → *"That is a Darkmatter relay beacon. Oh no. Oh, they will be SO pleased."* (`VEN_END_MOON_01`). | |
| 84.0 | 7 Epilogue cards | 2D | The war still ends; London is safe; the squad's cards; "the Moon has a smile now." | |
| 120.0 | 8 Title | black | **"MONDLICHT."** (the sequel tease; ROADMAP outline only). Credits. | |

### 3.1 Variant 6b — "Mondlicht (Reserve)"   ~100 s

Trigger: Moon step 6b after a city launch (§2). The cities have already been hit; the reserve rocket in the pit is re-targeted.

| t | Shot | Action |
|---|---|---|
| 0.0 | 1 The pit | The reserve rocket rises from the pit on its lift, smaller than the Sonnenspeer, in the violet-ash night. The characters watch from the Leitstand's periscope slit. One line per character, sadder (`*_END_MOONB_01`): Dutch *"Late. But it's going."* |
| 12.0 | 2 The ride | as §3 shot 2, shorter, the Earth below already violet in places. |
| 36.0 | 3–4 The strike and the answer | as §3 shots 3–4. |
| 56.0 | 5 The Operator | *"Delivery rerouted. Partially. A new market has been... discovered."* (`OPR_END_MOONB_01`) |
| 62.0 | 6 Cards | the Moon cards with the Aftermath framing ("the cities burn; the Moon smiles"). No credits; the match resumes in Aftermath. |

---

## 4. Shared mechanics

- **Choice prompts** reuse the exfil beacon's vote UI (T-033): a held key, majority in co-op, the time limit off for the Reinholt choice and 20 s for Peg's (default destroy).
- **Sabotage-aware shots:** the launch and reserve cutscenes read `GameState.flags` `rocket_london_sabotaged` etc. and skip or replace shots; the shot table carries a `requires_flag` / `skip_if_flag` field per shot (an extension of the campaign player).
- **Live shots** (Launch 1–2) are rendered with the player's camera; the cutscene player takes over at shot 2's cut.
- **Gallery:** every ending viewed is saved to the Archive cutscene gallery with its choices recorded (`ProfileSave` `endings_seen`).
- **Skipping:** allowed after the first viewing of that ending; the choice prompts are never skipped.
