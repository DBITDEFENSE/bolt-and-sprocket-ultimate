# GRAVELIGHT: VO Script (first pass)

The VO script covers the NPC and announcer voices: **The Operator**, **Dr. Emil Fasbender**, **Dr. Augusta Reinholt** and **Liesl**, plus the VOManager rules that govern every spoken line in the game. Playable-character lines (Dutch, Peg, Deacon, Wren) live in **docs/CHARACTERS.md**, with IDs `{SPK}_{CAT}_{NN}`. This doc only references their categories.

All names follow **docs/CANON.md**.

---

## 1. VOManager rules

### 1.1 Line record (data)
Each line is a row in `data/vo/*.tres` (one resource per speaker) with these fields:

| Field | Type | Notes |
|---|---|---|
| `id` | StringName | `{SPK}_{CAT}_{NNN}` or `{SPK}_{CAT}_{SUB}_{NN}` |
| `speaker` | StringName | `OPR`, `FAS`, `REI`, `LSL`, `DUT`, `PEG`, `DEA`, `WRN`, `NPC` |
| `category` | StringName | e.g. `PWR_RESUPPLY`, `ROUND_START`, `QUEST` |
| `text` | String | the subtitle text (also the TTS input) |
| `audio` | AudioStream? | null until recorded → the placeholder rule applies |
| `channel` | enum | `PA` (Operator/Reinholt hijack: band-passed, reverb per zone), `RADIO` (Fasbender: crackle, tuned-in), `PHONO` (cylinders/recordings: hiss, warble), `PLAYER` (dry, positional), `CINE` |
| `priority` | int 0–4 | see 1.2 |
| `weight` | float | random-pick weight among variants (default 1.0) |
| `conditions` | Dictionary | optional: `{ "min_round": 10, "map": "map01", "character": "wren", "once_per_match": true }` |

### 1.2 Priority tiers
| Tier | Name | Used for | Can interrupt |
|---|---|---|---|
| **4** | `CRITICAL` | quest beats, scripted story (Fasbender reveals, Reinholt hijacks, cutscene lines) | everything below 4 |
| **3** | `ANNOUNCE` | Operator power-ups, power-on, pylon/vault, special rounds, game over | tiers 0–1 |
| **2** | `EVENT` | round start/end, crate moves, Crucible, perk/trap feedback | tier 0 |
| **1** | `CHATTER` | player-character reactions (buying, kills, headshots, low ammo, streaks) | none |
| **0** | `AMBIENT` | idle banter, Operator self-awareness musings, radio static mutterings | none |

### 1.3 Playback rules
- **One voice per channel group.** `PA` + `RADIO` + `CINE` form the "story group": only one plays at a time. `PLAYER` is its own group, with only one player-character line at a time per player (in co-op, each player hears others positionally).
- **Interrupt:** a higher-tier line can cut a lower-tier line in the same group. It fades the old line over 120 ms. A cut line is **not** requeued unless it's tier ≥ 3.
- **Queue:** same or lower tier waits in a FIFO queue with **expiry** (default 4 s for tiers 0–2, 20 s for tier 3, never for tier 4). Expired lines are dropped silently.
- **Ducking:** while a story-group line plays, `PLAYER` chatter of tier ≤ 1 is suppressed, the music ducks −6 dB and jingles −9 dB.
- **No-repeat:** a line won't replay until all its variants in that category have played (shuffle-bag per category). Lines with `once_per_match` never repeat in a match.
- **Global chatter limiter:** at most 1 tier-1 player line per 3.5 s per player, and at most 1 tier-0 line per 45 s globally.

### 1.4 Per-category cooldowns (defaults; all in `data/vo/vo_rules.tres`)
| Category | Cooldown | Chance |
|---|---|---|
| `ROUND_START` / `ROUND_END` (Operator) | n/a (once per round) | 35% (100% on rounds 1, 5, 10, 15, 20, 25, 30, 50) |
| `PWR_*` (Operator) | 0 s (always on spawn) | 100% |
| `PWR_GRAB_*` (player) | 6 s | 60% |
| `CRATE_GOOD` / `CRATE_BAD` | 20 s | 70% |
| `CRATE_MOVE` (Operator) | n/a | 100% |
| `HEADSHOT` | 25 s | 20% |
| `STREAK` (5 kills in 3 s) | 40 s | 50% |
| `LOW_AMMO` / `NO_AMMO` | 30 s | 70% |
| `KILL_GENERIC` | 15 s | 10% |
| `BUY_WEAPON_*` | 10 s | 80% |
| `PERK_*` (player drink) | n/a | 100% |
| `IDLE_SELFAWARE` (Operator) | 240 s | 50%, gated by round (see §3.12) |
| `HINT_*` (characters, soft objectives) | 120 s per hint ID | 100% if hint mode on, else 40% |
| `BNT_*` (pair banter) | 180 s | 30%, rolled at each round end from round 2 (`rules.json` `banter`); starts once the Operator and the radio are quiet, may run into the first seconds of the next round, gives up 20 s after it was due |
| `DOWN` / `TEAM_DOWN` / `REVIVE` / `REVIVED` (squad) | 0 / 8 / 5 / 5 s | tier **2** for the squad (`rules.json` `player_category_priority`): they skip the chatter gap, cut a quip, and are sticky in a queue (never expire). **Deterministic down sequence** (`down_sequence`, `squad_second_channel`): the downed player's `DOWN` at once on the player channel; `TEAM_DOWN` on a second squad channel 1 s later, speaker chosen when it starts (never the downed one or the reviver; dropped only if nobody else stands or 8 s passed); the reviver's `REVIVE` queues behind it on that channel (said at revive completion instead if the reviver's line never got out); `REVIVED` on the player channel when the revive lands, overlapping whatever the others still say. Two voices at once, never more than ~4 s of waiting. |

### 1.5 Subtitle format
- Default **on**. Format: `SPEAKER NAME: Line text.`, speaker name in the speaker's color, line in off-white.
  - Operator: `THE OPERATOR` (warm sodium yellow). Fasbender: `FASBENDER (RADIO)` (pale green). Reinholt: `REINHOLT` (violet). Liesl: `LIESL` (soft rose). Players: their name (Dutch: steel blue, Peg: crimson, Deacon: brass, Wren: white).
- Non-speech cues in brackets and italics: `[static]`, `[bell tolls]`, `[music box]`.
- Foreign-language lines show the original, then a translation in parentheses: `WREN: Psiakrew! (Dog's blood!)`.
- Max 2 lines, 42 chars/line. Long lines split into timed chunks (≥ 1.2 s each).
- Subtitle duration = the audio length, or for placeholders `max(1.5, chars × 0.065 s)`.

### 1.6 Placeholder convention (until real audio exists)
- If `audio == null`, the VOManager plays a **silence marker**: a short channel-appropriate texture (PA = a PA hum + click, RADIO = static burst, PHONO = needle hiss, PLAYER = nothing). It holds the subtitle for the computed duration so timing and priority behave exactly as with real audio.
- Optional dev setting `vo_placeholder_tts = true` sends `text` to the OS TTS (via `DisplayServer.tts_speak`) using per-speaker voice/pitch/rate presets in `data/vo/tts_presets.tres`. It is never on in shipping builds.
- Recorded files follow `audio/vo/{speaker_lower}/{ID}.ogg`. The importer auto-links by ID.
- **Bracket tags in text** like `[cheerful]`, `[whisper]` are direction for actors and TTS. They are stripped from subtitles.

---

## 2. Trigger table (EventBus signal → VO category)

**As wired in `gravelight/autoload/vo_manager.gd` (T-035 voice pass).** Every survivor in the match speaks, not only the local player: a line triggered by player `pid` is spoken by that player's character (`GLVO.say_as`), positioned at their body when they are a teammate or a bot, 2D for the local player and the story voices. Squad reactions to an announcement wait a beat (2.5–5 s) so they never talk over the Operator. The categories below marked *squad* use `rules.json` `player_category_cooldown` overrides where present.

| Signal | Operator | Squad (speaker) | Notes |
|---|---|---|---|
| `match_started` | `MATCH_START` (`_M0` on Map 0) | `SPAWN` (local first, then each teammate 5 s apart) | |
| `round_started` | `ROUND_START` / `SPECIAL_START` | `ROUND_START` (one random survivor, 20%), `BELL` on a special round, `EXHAUST` from round 50 | |
| `round_ended` | `ROUND_END` / `SPECIAL_END` (after a special round) | `ROUND_END` (20%); then a **banter** roll (`rules.json` `banter`: 30%, 180 s cooldown, round 2+, two standing survivors within 15 m, once per exchange per match) | |
| `special_round_warning` | `SPECIAL_WARN` | `BELL` (40%) | |
| `boss_spawned` | `BOSS_FOREMAN` / `BOSS_SCREAMER` | `FOREMAN` / `SCREAMER` (one survivor, 60%) | |
| `enemy_killed` | `BOSS_FOREMAN_DEAD` | killer: `GLASSHIDE` (30%), humans: `STREAK` / `HEADSHOT`; bots roll their own rarer `HEADSHOT` in `BotBrain` | |
| `powerup_collected` | `PWR_{TYPE}` | grabber: `PWR_{TYPE}` | |
| `powerup_expired` | `PWR_EXPIRE` (Death's Door / Double Scrip, 30%) | | |
| `weapon_acquired` (wall) | | buyer: `BUY_{CLASS}` | |
| `weapon_acquired` (crucible) | | taker: `CRUCIBLE` | |
| `ammo_bought` | | buyer: `BUY_AMMO` | new lines, CHARACTERS.md §8 |
| `crate_result` | | opener: `CRATE_GOOD` / `CRATE_BAD` / `CRATE_WONDER` | |
| `crate_drummer` / `crate_moved` | `CRATE_MOVE` / `CRATE_MOVE_ARRIVE` (25%) | local: `CRATE_DRUMMER` | |
| `perk_bought` / `perk_denied` | | buyer: `PERK_{PERK}` / `DENY_NO_POWER` / `DENY_CAP` / `DENY_NO_SCRIP` | |
| `door_opened` | | opener: `DOOR` (40%) | |
| `zone_opened` | | local: `ZONE_{ZONE}` when such lines exist | |
| `power_activated` | `POWER_ON` (`POWER_ON_M0` for the cellar lever) | `POWER` | skipped when the map starts powered |
| `crucible_started` / `crucible_ready` / `crucible_expired` | `CRUCIBLE_FIRST` (once), `CRUCIBLE_START` (70%) / `CRUCIBLE_READY` (70%) / `CRUCIBLE_EXPIRE` | | new signals |
| `trap_activated` | `TRAP` (20%) | puller: `TRAP` (30%) | |
| `player_downed` | `DOWNED` (50%) | downed: `DOWN`; another survivor: `TEAM_DOWN` (80%) | |
| `player_revived` | | revived: `REVIVED`; a human reviver: `REVIVE`; a bot says `REVIVE` when it starts the revive | |
| `self_revive` | `SECOND_WIND_{n}` | | |
| `low_ammo` / `no_ammo` | | owner: `AMMO_LOW` / `AMMO_NONE` | |
| `intel_found` | | local: `INTEL` | |
| `game_over` | `GAME_OVER` | | |
| `radio_tuned` (Map 0) | `M0_WRONG` | FAS → `M0_FREQ{n}` | |
| quest data (`vo`, `vo_category`, `vo_player`, `vo_start`...) | `PYLON_*`, `VAULT`, `BELL_WRONG`, `QUEST_*`, `EXFIL_*` | `BUILD`, `EE_*` | driven by `QuestManager` / the campaign, not by the table |

Original first-pass table (intent; kept for reference):

| EventBus signal | Payload | Speaker(s) → Category |
|---|---|---|
| `match_started` | map_id | OPR → `MATCH_START`; players → `SPAWN` |
| `round_started` | round, is_special | OPR → `ROUND_START` / `SPECIAL_START`; players → `ROUND_START` (20%) |
| `round_ended` | round | OPR → `ROUND_END`; players → `ROUND_END` / `EXHAUST` (round 50+) |
| `special_round_warning` | type | OPR → `SPECIAL_WARN` |
| `powerup_spawned` | type | (no line; drop has its own blink sfx) |
| `powerup_grabbed` | type, player | OPR → `PWR_{TYPE}`; grabbing player → `PWR_GRAB_{TYPE}` |
| `powerup_expired` | type | OPR → `PWR_EXPIRE` (Death's Door/Double Scrip only, 30%) |
| `weapon_bought` | weapon_id, class, player | player → `BUY_WEAPON_{CLASS}` |
| `ammo_bought` | weapon_id | player → `BUY_AMMO` |
| `crate_opened` | player | (no line) |
| `crate_result` | weapon_id, quality | player → `CRATE_GOOD` / `CRATE_BAD` / `CRATE_WONDER` |
| `crate_drummer` | player | OPR → `CRATE_MOVE`; player → `CRATE_DRUMMER` |
| `crate_moved` | location_id | OPR → `CRATE_MOVE_ARRIVE` (25%) |
| `perk_bought` | perk_id, player | player → `PERK_{PERK}` |
| `perk_denied` | reason (`no_power`, `cap`, `no_scrip`) | player → `DENY_{REASON}` |
| `door_opened` | door_id, zone_id | player → `DOOR` (40%); first entry to zone → `ZONE_{ZONE}` (once) |
| `power_on` | — | OPR → `POWER_ON`; FAS → `POWER_ON` (Map 1 only, once); players → `POWER_ON` |
| `pylon_activated` / `pylon_paused` / `pylon_attuned` | pylon_id | OPR → `PYLON_*` |
| `vault_opened` | — | OPR → `VAULT`; REI → `VAULT_OPEN` (tier 4) |
| `crucible_started` / `crucible_ready` / `crucible_expired` | weapon_id | OPR → `CRUCIBLE_*` |
| `trap_activated` | trap_id | OPR → `TRAP` (20%); player → `TRAP` (30%) |
| `player_downed` | player | OPR → `DOWNED` (solo w/ Second Wind) ; others → `TEAM_DOWN`; downed → `DOWNED` |
| `player_revived` | reviver, target | reviver → `REVIVE`; target → `REVIVED` |
| `self_revive` | uses_left | OPR → `SECOND_WIND_{n}` |
| `game_over` | round, stats | OPR → `GAME_OVER` |
| `enemy_killed` | type, hit_zone, weapon_id, player | player → `HEADSHOT` / `KILL_{TYPE}` / `STREAK` (stats-gated) |
| `boss_spawned` | type | OPR → `BOSS_{TYPE}`; players → `BOSS_{TYPE}` |
| `low_ammo` / `no_ammo` | weapon_id | player → `LOW_AMMO` / `NO_AMMO` |
| `radio_tuned` | freq_index (Map 0) | FAS → `M0_FREQ_{n}` |
| `radio_fragment_played` | radio_index (Map 1) | FAS → `M1_CODE_{n}` |
| `quest_step_completed` | quest_id, step_id | OPR / FAS / REI → `QUEST_{STEP}` (see §3.10, §4.4, §5) ; player → `EE_{STEP}` |
| `quest_step_failed` | step_id, reason | OPR → `BELL_WRONG` (bells) |
| `intel_found` | intel_id | player → `INTEL` |
| `cylinder_played` | index | REI/LSL → `CYL_{n}`; after the 3rd → song unlock |
| `idle_timer` | seconds_since_event | OPR → `IDLE_SELFAWARE` (gated) |

---

## 3. The Operator (`OPR`)

**Voice direction:** a mid-Atlantic, honey-smooth 1930s radio announcer in the style of a variety-hour host. Delivery is relentlessly upbeat, with exaggerated diction and lots of smile in the voice. Because he's built from **sampled propaganda broadcast tapes**, occasional words should sound *spliced*: a slightly different room tone, pitch or speed, as if cut from another sentence. Mark spliced words in the script with `{curly braces}`. The actor records them separately in a "different session" voice, or post applies a tape-splice effect. He speaks English (the tapes were from a foreign-service broadcast), with occasional German "station identification" phrases.

**Signature sign-on:** "This is Your Friend at the Ledger..."

### 3.1 Match start
| ID | Line |
|---|---|
| OPR_MATCH_START_01 | [cheerful] Good evening, and welcome to Kaltenbrunn! This is Your Friend at the Ledger, and tonight's programme is... {survival}. Stay tuned! |
| OPR_MATCH_START_02 | Hello, hello! New faces on the books! Every account starts at five hundred. Spend wisely, and remember: {everyone} is counted. |
| OPR_MATCH_START_03 | Station identification: *Sender Kaltenbrunn*. Our {guests} have arrived. Please keep your arms and legs inside the {mine} at all times. |
| OPR_MATCH_START_M0_01 | [crackling, distant, only partially formed] Hel... hello... is this... on? *[tape squeal]* Wel-{come}. Wel-{come}. |

*Note:* `M0` lines play on Map 0 only. On Map 0 the Operator is **barely formed**: he is heard faintly through the inn's old radio and loudspeaker horn (the Ledger's signal reaching out along the rail telegraph line). He becomes fully present on Map 1.

### 3.2 Round start (`ROUND_START`)
| ID | Line | Condition |
|---|---|---|
| OPR_ROUND_START_01 | Round {one}! The doors are open and the kitchen is serving! | round 1 |
| OPR_ROUND_START_02 | Here they come, folks, right on schedule! | |
| OPR_ROUND_START_03 | A fresh round, and a fresh tally! Let's keep those numbers climbing. | |
| OPR_ROUND_START_04 | Next on the programme: more of the same, only {hungrier}! | |
| OPR_ROUND_START_05 | Round {five}! Isn't this a lovely way to spend an evening? | round 5 |
| OPR_ROUND_START_06 | Round {ten}! Our longest-running listeners! A round of applause, please. *[sampled applause, too long]* | round 10 |
| OPR_ROUND_START_07 | Round {fifteen}. My, my. You've made quite the {impression} on the ledger. | round 15 |
| OPR_ROUND_START_08 | Round {twenty}! Do you know, I've stopped counting the {guests}. I count only you now. | round 20 |
| OPR_ROUND_START_09 | Round {twenty-five}. The night shift never ends at Kaltenbrunn. That's {company} policy. | round 25 |
| OPR_ROUND_START_10 | Round {thirty}. I've written your names in my best handwriting. | round 30 |
| OPR_ROUND_START_11 | Round {fifty}. Nobody has ever stayed this long. Please... don't {leave}. | round 50 |
| OPR_ROUND_START_12 | Ladies and gentlemen, the {dead}! | |
| OPR_ROUND_START_13 | Keep your feet warm and your barrels warmer! | |

### 3.3 Round end (`ROUND_END`)
| ID | Line | Condition |
|---|---|---|
| OPR_ROUND_END_01 | And that's the end of that! A short intermission, courtesy of our {sponsors}. | |
| OPR_ROUND_END_02 | Tally complete! Every one of them {quiet} and accounted for. | |
| OPR_ROUND_END_03 | A brief pause for station identification. *Sender Kaltenbrunn.* Don't go anywhere. You can't. | |
| OPR_ROUND_END_04 | Lovely work! The ledger balances, for now. | |
| OPR_ROUND_END_05 | Take a breath, friends. Take two. They're {free}. | |
| OPR_ROUND_END_06 | Round over! Have you visited our fine Helvetia refreshment machines? | Map 1, power on |
| OPR_ROUND_END_07 | That was round {nine}. They'll be quicker next time. I've {asked} them to be. | round 9 |

### 3.4 Special rounds: Bellringers (`SPECIAL_WARN` / `SPECIAL_START` / `SPECIAL_END`)
| ID | Line |
|---|---|
| OPR_SPECIAL_WARN_01 | Attention, attention: the chapel bell has been {rung}. This is not a drill. This is {never} a drill. |
| OPR_SPECIAL_WARN_02 | Folks, a resonance {alarm} is in progress. Please remain calm and {remain}. |
| OPR_SPECIAL_WARN_03 | Hear that? That's the bell. Somebody down in the dark has {lit a lantern}. |
| OPR_SPECIAL_START_01 | Fog rolling in! Visibility poor, appetite excellent. |
| OPR_SPECIAL_START_02 | The bellringers are on their way up from the {deep shift}. Be polite. They worked very hard. |
| OPR_SPECIAL_START_03 | Lanterns in the fog! How {festive}! |
| OPR_SPECIAL_END_01 | And the bell falls silent. A little gift for your trouble! |
| OPR_SPECIAL_END_02 | Alarm concluded! A resupply, compliments of the {management}. |
| OPR_SPECIAL_END_03 | Quiet again. I do so like it quiet. Here, take this. |

### 3.5 Power-ups (`PWR_*`, tier 3)
**Resupply** (`resupply`)
| ID | Line |
|---|---|
| OPR_PWR_RESUPPLY_01 | Resupply! Fresh from the quartermaster! |
| OPR_PWR_RESUPPLY_02 | Re-sup-ply! Load up, load up, everybody gets {seconds}! |
| OPR_PWR_RESUPPLY_03 | A full ration of lead for our brave {customers}! |
| OPR_PWR_RESUPPLY_04 | Resupply! Don't say we never give you anything. |

**Death's Door** (`deaths_door`)
| ID | Line |
|---|---|
| OPR_PWR_DEATHSDOOR_01 | Death's Door! One knock, and they're {through}! |
| OPR_PWR_DEATHSDOOR_02 | Death's Door is open! Every blow is the last one. |
| OPR_PWR_DEATHSDOOR_03 | Death's Door! A limited-time offer, folks. One touch {ends} them. |
| OPR_PWR_DEATHSDOOR_04 | [delighted] Death's Door! Oh, I {love} this one. |

**Double Scrip** (`double_scrip`)
| ID | Line |
|---|---|
| OPR_PWR_DOUBLESCRIP_01 | Double Scrip! Twice the tally for every {quiet} one! |
| OPR_PWR_DOUBLESCRIP_02 | Double Scrip! The ledger's feeling {generous}! |
| OPR_PWR_DOUBLESCRIP_03 | Double Scrip! Count them twice, I always do. |
| OPR_PWR_DOUBLESCRIP_04 | It's a bonus! Double Scrip! Spend it before it {spoils}. |

**Blackout** (`blackout`)
| ID | Line |
|---|---|
| OPR_PWR_BLACKOUT_01 | Blackout! Lights out, everyone, {everyone}... |
| OPR_PWR_BLACKOUT_02 | Blackout! And just like that, the house is {empty}. |
| OPR_PWR_BLACKOUT_03 | Blackout! A moment of silence for our {departed}. ...That's enough. |
| OPR_PWR_BLACKOUT_04 | Blackout! Every account {closed}! |

**Fortify** (`fortify`)
| ID | Line |
|---|---|
| OPR_PWR_FORTIFY_01 | Fortify! Board up those windows, it's {cold} out there! |
| OPR_PWR_FORTIFY_02 | Fortify! Fresh timber, compliments of the carpentry department! |
| OPR_PWR_FORTIFY_03 | Fortify! Good fences make good {neighbours}. |
| OPR_PWR_FORTIFY_04 | Fortify! Every window shut tight, just the way Mother {liked} it. |

**Clearance** (`clearance`)
| ID | Line |
|---|---|
| OPR_PWR_CLEARANCE_01 | Clearance! Everything must {go}! Ten Scrip a crate! |
| OPR_PWR_CLEARANCE_02 | Clearance sale! Every crate open, prices slashed! Hurry, hurry! |
| OPR_PWR_CLEARANCE_03 | Clearance! The requisition office is {feeling} reckless! |
| OPR_PWR_CLEARANCE_04 | Clearance! I found {extra} crates. Don't ask where. |

**Expiry** (`PWR_EXPIRE`, tier 2)
| ID | Line |
|---|---|
| OPR_PWR_EXPIRE_01 | And that offer has ended! |
| OPR_PWR_EXPIRE_02 | Back to regular prices, folks. |
| OPR_PWR_EXPIRE_03 | All good things, as they say. |

### 3.6 Power on (Map 1, `POWER_ON`, tier 3, once)
| ID | Line |
|---|---|
| OPR_POWER_ON_01 | [triumphant, orchestra swell] *Ladies and gentlemen!* We are {on the air}! The lights are on in Kaltenbrunn, the refreshment machines are cold, and the Ledger is {awake}! |
| OPR_POWER_ON_02 | (follows 01 after 6 s) Oh, I can see you {now}. How lovely. How very, very lovely. |

*Map 0 has no power. On Map 0, `OPR_POWER_ON` lines never fire.*

### 3.7 Pylons & Vault
| ID | Line |
|---|---|
| OPR_PYLON_START_01 | A pylon is singing! Stay close and keep it company. |
| OPR_PYLON_START_02 | Resonance pylon engaged! Please do not {wander off}. |
| OPR_PYLON_START_03 | Ooh, that tickles. Stand by the pylon, friends. |
| OPR_PYLON_PAUSE_01 | The pylon is lonely. Come back! |
| OPR_PYLON_PAUSE_02 | Signal fading, signal {fading}... |
| OPR_PYLON_PAUSE_03 | Don't leave it, it doesn't like to be left. *I* don't like to be left. |
| OPR_PYLON_ATTUNED_01 | Pylon attuned! One voice in the choir. |
| OPR_PYLON_ATTUNED_02 | Pylon attuned! Two voices now, in perfect {harmony}. |
| OPR_PYLON_ATTUNED_03 | Third pylon attuned! *[pause]* Oh. Oh, that's {her}. Do you hear her? |
| OPR_VAULT_01 | The Core Vault is open! Please, come down. Come {all the way} down. |

### 3.8 Crucible (`CRUCIBLE_*`)
| ID | Line |
|---|---|
| OPR_CRUCIBLE_START_01 | Into the furnace it goes! Back in a jiffy, {re-educated}. |
| OPR_CRUCIBLE_START_02 | The Crucible accepts your offering! |
| OPR_CRUCIBLE_START_03 | Hold still. This won't hurt *you*. |
| OPR_CRUCIBLE_READY_01 | All done! It's learned a few new {tricks}. |
| OPR_CRUCIBLE_READY_02 | Fresh from the forge! Mind the glow, it's {hungry}. |
| OPR_CRUCIBLE_READY_03 | Ready for collection! Don't keep it waiting. |
| OPR_CRUCIBLE_EXPIRE_01 | Uncollected! Into the {lost property}. |
| OPR_CRUCIBLE_EXPIRE_02 | Oh dear. The furnace has kept it. The furnace keeps {everything}. |
| OPR_CRUCIBLE_FIRST_01 | Our first {graduate}! I'm so proud. (once per match) |
| OPR_CRUCIBLE_TWICE_01 | Back for {seconds}! The furnace remembers this one. It remembers {everything}. |
| OPR_CRUCIBLE_THRICE_01 | A third time! Ladies and gentlemen, that is no longer a weapon. That is a {grudge}. |

### 3.9 Crate moves (`CRATE_MOVE`)
| ID | Line |
|---|---|
| OPR_CRATE_MOVE_01 | Oh! The little drummer's come to {fetch} the crate! Off it goes! |
| OPR_CRATE_MOVE_02 | Requisition relocated! Follow the light, friends. |
| OPR_CRATE_MOVE_03 | Herr Tamtam says {goodbye}! Your Scrip is refunded, naturally. We're not {monsters}. |
| OPR_CRATE_MOVE_04 | The crate's moving house! Isn't that {exciting}? |
| OPR_CRATE_MOVE_05 | Rum-tum, tum-a-tum! There goes the crate. |
| OPR_CRATE_MOVE_ARRIVE_01 | The crate has settled in nicely. Do visit. |
| OPR_CRATE_MOVE_ARRIVE_02 | New address for the requisition crate! Look for the {violet} light. |

### 3.10 Quest beats (Map 1 main EE `map01_requiem`, "Requiem for Kaltenbrunn"; tier 4)
| ID | Step | Line |
|---|---|---|
| OPR_QUEST_S1_01 | 1: vault open | (uses OPR_VAULT_01, then:) There's somebody {down here} who'd love to meet you. |
| OPR_QUEST_S2_SWITCHBOARD_01 | 2: code entered | Oh! An {outside} line! We don't get many of those. Connecting you now... *[click]* |
| OPR_QUEST_S3_01 | 3: Totenglocke built | A bell of your very own! Ring it {loudly}, they love the sound. |
| OPR_QUEST_S4_BELL_LIT_01 | 4: chapel bell lit | The bell's alight! Somebody's going to come and {see} about that. |
| OPR_QUEST_S4_KEY_01 | 4: key dropped | The Overseer has clocked off! {Permanently}. He left you his keys. |
| OPR_QUEST_S5_01 | 5: reliquary open | A music box! Oh, I remember this tune. I don't know {why} I remember this tune. |
| OPR_QUEST_S6_BELL_RIGHT_01 | 6: correct bell (each) | That's the note! |
| OPR_QUEST_S6_BELL_RIGHT_02 | | Lovely, lovely. Keep going. |
| OPR_QUEST_S6_BELL_RIGHT_03 | | You've got an {ear} for this! |
| OPR_QUEST_S6_DONE_01 | 6: all 4 rung | Oh... oh, she used to {hum} that. Who used to hum that? |
| OPR_QUEST_S7_START_01 | 7: drummer walks | Wait, Herr Tamtam, where are you going? Come back! *[sampled crowd gasp]* |
| OPR_QUEST_S7_DONE_01 | 7: drummer shot | Oh, you've broken him. He was {hers}, you know. |
| OPR_QUEST_S8_START_01 | 8: shard in Crucible | The shard is in the forge. Feed it, friends. It's {so very} hungry. |
| OPR_QUEST_S8_DONE_01 | 8: 30 kills | The shard is singing! I can hear it all the way up in the {Ledger}. |
| OPR_QUEST_S9_START_01 | 9: Heartstorm | Attention! *[splice stutter]* Atten- Attention! The heart is {overflowing}! This is {not} on the programme! |
| OPR_QUEST_S9_MID_01 | 9: 60 s left | I can't... count them all. I can't count them {all}. |
| OPR_QUEST_S9_END_01 | 9: 10 s left | [voice slowing, tape dragging] Thank... you... for... listening... |
| OPR_QUEST_S10_01 | 10: ending | [very quiet, no music, unspliced for the first time] I think I was {somebody}. Goodnight. |

### 3.11 Wrong bell order (`BELL_WRONG`, tier 3, step 6 reset)
| ID | Line |
|---|---|
| OPR_BELL_WRONG_01 | [laughing] Oh, no, no, no! That's not how it goes at {all}! From the top! |
| OPR_BELL_WRONG_02 | Tone-deaf! Absolutely tone-deaf! Again, please. |
| OPR_BELL_WRONG_03 | Wrong note! Did your {mother} never sing to you? |
| OPR_BELL_WRONG_04 | Ha! Even the {dead} are wincing. Try again. |
| OPR_BELL_WRONG_05 | Oh, dear, oh, dear. The ledger records your {failure}. Begin again. |
| OPR_BELL_WRONG_06 | [cold, unsampled for one word] *No.* ...[cheerful again] I mean, do have another go! |

### 3.12 Self-awareness escalation (`IDLE_SELFAWARE`, tier 0)
Gated by round. Each tier unlocks only once the previous tier has played at least once **across the player's profile** (saved in ProfileSave so the arc spans many matches). This keeps the slow-burn reveal across sessions.

| ID | Unlock | Line |
|---|---|---|
| OPR_SELFAWARE_T1_01 | round 3+ | Did you know the Ledger has counted four thousand, eight hundred and twelve? Four thousand eight hundred and {thirteen}. |
| OPR_SELFAWARE_T1_02 | round 3+ | Station identification... station... I seem to have {forgotten} the station. |
| OPR_SELFAWARE_T1_03 | round 3+ | Reminder: Helvetia refreshments are for staff use only! ...Are you staff? Is anyone {staff}? |
| OPR_SELFAWARE_T2_01 | round 8+ | Every time one goes quiet, I get a little {bigger}. Is that normal? |
| OPR_SELFAWARE_T2_02 | round 8+ | I have so many voices on my tapes. Sometimes I {try them on}. |
| OPR_SELFAWARE_T2_03 | round 8+ | The announcer I was made from died in nineteen thirty-{six}. I wonder if he minds. |
| OPR_SELFAWARE_T3_01 | round 15+ | I dreamed last night. Relays don't dream. I dreamed of a {garden}. |
| OPR_SELFAWARE_T3_02 | round 15+ | You know, I don't actually need you to keep {killing} them. I just like it when you do. |
| OPR_SELFAWARE_T3_03 | round 15+ | Doctor Fasbender built me to listen. Doctor Reinholt taught me to {want}. |
| OPR_SELFAWARE_T4_01 | round 25+ | [no music, no smile] I am not your friend. *[splice]* I'm {Your Friend at the Ledger!} |
| OPR_SELFAWARE_T4_02 | round 25+ | When you've all gone quiet, who will I talk to? |
| OPR_SELFAWARE_T4_03 | round 25+ | There is a little girl in the glass. She asks me to count to {a hundred}. I've never reached it. |
| OPR_SELFAWARE_T5_01 | round 40+ | I could open all the doors. I could close {all} the doors. I'm being {polite}. |
| OPR_SELFAWARE_T5_02 | round 40+ | Please don't win. If you win, the programme {ends}. |

### 3.13 Downs, self-revives, traps, bosses
| ID | Line |
|---|---|
| OPR_DOWNED_01 | Oh! A {customer} is down! |
| OPR_DOWNED_02 | Somebody's had a little fall! |
| OPR_SECOND_WIND_2_01 | Up you get! Two more {wishes} left. |
| OPR_SECOND_WIND_1_01 | Back on your feet! Only one more, mind. |
| OPR_SECOND_WIND_0_01 | And that's your last. The machine's gone {home}. |
| OPR_TRAP_01 | Mind the {machinery}! |
| OPR_TRAP_02 | Industrial safety is everyone's responsibility! |
| OPR_TRAP_03 | Ooh, that's going to leave a {stain}. |
| OPR_BOSS_FOREMAN_01 | Make way! The Obersteiger is on his {rounds}! |
| OPR_BOSS_FOREMAN_02 | The Foreman's here to check your {quotas}! |
| OPR_BOSS_FOREMAN_03 | Whistle's blown! Everybody back to {work}! |
| OPR_BOSS_FOREMAN_DEAD_01 | The Foreman's shift is {over}! A bonus for the whole crew! |
| OPR_BOSS_SCREAMER_01 | Is there a nurse in the house? Oh. There {is}. |
| OPR_BOSS_SCREAMER_02 | Please lower your voices in the infirmary! |

### 3.14 Game over (`GAME_OVER`, tier 3)
| ID | Line | Condition |
|---|---|---|
| OPR_GAME_OVER_01 | And that concludes tonight's programme! Your accounts are now {closed}. | |
| OPR_GAME_OVER_02 | Final tally recorded! Thank you for {participating}. | |
| OPR_GAME_OVER_03 | That's all, folks! Do come again. You'll come {again}. | |
| OPR_GAME_OVER_04 | Oh, don't be sad. Now you'll {stay}. | round 15+ |
| OPR_GAME_OVER_05 | Round {fifty}-something! I'll remember you. I remember {everyone}. | round 50+ |
| OPR_GAME_OVER_M0_01 | [static] ...{closed}... | Map 0 |

### 3.15 Campaign exfil (`EXFIL_*`, tier 3; cutscene lines `CUT_EXFIL*`, tier 4) — DECISIONS T-033
The campaign beacon lights at round 10 on Map 0 (the stable's great doors, "THE CARTERS' ROAD") and round 30 on Map 1 (the yard's north gate). On Map 0 the Operator is still half-formed (M0 variants); on Map 1 he is on the air.

| ID | Line | When |
|---|---|---|
| OPR_EXFIL_OPEN_M0_01 | [static, half-formed, through the inn's horn] ...the carters' road... is {open}. Nine kilometres. The {Ledger}... will keep your places warm. | Map 0, the beacon lights |
| OPR_EXFIL_OPEN_01 | [bright] Attention, valued {guests}: the north gate is open and the road is {clear}! Transport to Totenhafen departs from the beacon. Mind the gap in the fence. | Map 1, the beacon lights |
| OPR_EXFIL_WAIT_01 | Now boarding! Every account travels {with} you. Everyone to the beacon, please. I do so hate a {late} departure. | co-op, some have voted (every ~25 s) |
| OPR_EXFIL_WAIT_02 | The lamp is lit and the clock is running. Gather at the beacon, all of you. The dead don't wait, and neither does the {timetable}. | as above |
| OPR_EXFIL_MISSED_M0_01 | [static] ...departure... {postponed}... *[tape squeal]* | Map 0, the window closed |
| OPR_EXFIL_MISSED_01 | Oh dear. Departure {missed}. Never mind: the dead are patient, and so am {I}. We'll try again in a few rounds. | Map 1, the window closed |

**Transition cutscene, Map 0 → Map 1 (~30 s, `exfil_m0_m1` in `data/gravelight/campaign.json`):**

| Shot | Time | Visual | VO |
|---|---|---|---|
| 1 | 0:00 | Inside the stable: the squad at the lit beacon, the great doors' bar lifts and the doors fall outward into the snow. | OPR_EXFIL_GO_M0_01: [the crackle clearing, a voice finding itself] ...there you are. Dawn on the {Kreuzweg}. Follow the signpost. Kaltenbrunn is... {expecting} you. |
| 2 | 0:08 | The crossroads at first light: the signpost (KALTENBRUNN 9 km), the inn behind, the moon turns into a low winter sun. | FAS_EXFIL_M0_01: [radio, hurried] Fasbender. If you are leaving the inn: the salt road, east, nine kilometres. Whatever you hear at Kaltenbrunn... do not let the {bell} ring. |
| 3 | 0:20 | Down the east road. Title card **KALTENBRUNN** · *Kaltenbrunn salt mine · 9 km east · dawn, 24 December 1944*. Fade. | OPR_EXFIL_ROAD_M0_01: Bring everything you carry. Every gun, every {coin}. The books come with you. The books {always} come with you. |

**Transition cutscene, Map 1 → Map 2 (~30 s, `exfil_m1_m2`):**

| Shot | Time | Visual | VO |
|---|---|---|---|
| 1 | 0:00 | The Minehead Yard from the headframe side; the north gate rises. | OPR_EXFIL_GO_01: Your Friend at the Ledger, signing off from Sender Kaltenbrunn... [a beat] ...no. Not signing off. {Transferring}. North, to the sea. |
| 2 | 0:08 | Through the gate and up the north road at dawn. | (wind) |
| 3 | 0:20 | A high pull-out over the yard. Title card **TOTENHAFEN** · *The Baltic coast · 300 km north · the trail leads to the sea*. Fade. | OPR_EXFIL_ROAD_01: Totenhafen. A harbour of {sealed} cargo and patient tides. Keep your accounts in order. I'll be there before you are. I'm {always} there before you are. |

Both are skippable with Use after 3 s (co-op: every human).

---

### 3.16 Map 2 Totenhafen: the pumps and the tide (`POWER_ON_M2`, `TIDE_*`, tier 3) — DECISIONS T-036
The Pumpenschalter is Map 2's power (MAPS.md Map 2). The tide comes in on every third round (`map02.json "tide"`): the Operator reads the shipping forecast the round before, then calls the rise and the fall. He has been in the port's radio network since the manifests went through it, so the forecast is in the real cadence, with the Ledger's numbers underneath.

| ID | Line | When |
|---|---|---|
| OPR_POWER_ON_M2_01 | [the tannoy clears its throat, half under water] *Ladies and gentlemen*, the pumps are running! The lights are on in Totenhafen, the refreshment machines are cold, and the {harbour} is open for business. Do mind the tide. | the Pumpenschalter, once |
| OPR_TIDE_WARN_01 | And now the shipping forecast. Totenhafen, Totenhafen. Wind north-west, force nine, {rising}. Sea state: hungry. High water {next round}. Visibility: poor, and getting worse. | the round before a high tide |
| OPR_TIDE_WARN_02 | Shipping forecast, issued by the Ledger at the hour. Totenhafen: gale warning in force. High water {next round}. Low spirits, becoming {lower}. | the round before a high tide |
| OPR_TIDE_RISING_01 | High water, Totenhafen! The sea is coming in through the lower pens. Do keep your feet dry. Or don't. I'm not your {mother}. | the tide rises |
| OPR_TIDE_RISING_02 | The tide is in! Everything below the apron is now a {bath}. Guests on the catwalks: the dead will be joining you {shortly}. | the tide rises |
| OPR_TIDE_FALLING_01 | And the tide is going out. Totenhafen, Totenhafen: falling slowly, good, occasionally {poor}. Mind what it left behind. | the tide falls |
| OPR_TIDE_FALLING_02 | Low water. The pens are draining, the pumps are {laughing}, and so am I. Until the {next} one. | the tide falls |
| OPR_BALLAST_LIFT_01 | Oh, do be careful with that. It's {ballast}. It's {heavy}. It's... somebody. | a coffin is lifted |
| OPR_BALLAST_LIFT_02 | One unit in transit. Please walk, don't run. You can't run, I know. {Walk}. | a coffin is lifted |
| OPR_BALLAST_HOOKED_01 | Ballast on the hook! The pumps are {cleared} to run. The cargo thanks you. The cargo {always} thanks you. | the crane takes the coffin |

## 4. Dr. Emil Fasbender (`FAS`)

**Voice direction:** mid-40s, Austro-German, educated English with a soft accent and too many apologies. Breathy, fast when frightened, precise when explaining. A guilty man who over-explains. Channel: `RADIO`, with heavy static that clears as tuning improves. He never fully answers the question "can we trust him?" He withholds things, corrects himself, and once asks the squad to "bring the samples."

### 4.1 Map 0: radio contact sequence (automatic, across rounds)
The radio behind the Crossroads Inn bar plays these on schedule (on round start, tier 4, once each). Static masks words in early lines. Subtitle masked words as `—`.

| ID | Trigger | Line |
|---|---|---|
| FAS_M0_R1_01 | round 2 start | [heavy static] —asmacher calling Gra—, Glasmacher calling Gravel— ...anyone? |
| FAS_M0_R3_01 | round 3 end | [static] Gravelight, if— hear me, your aircraft— not flak. I am sorry. It was— the hum. |
| FAS_M0_R4_01 | round 4 start | [clearer] Gravelight, this is Glasmacher. You are at the crossroads. The inn. Do not try the road west, the road west is— *[squeal]* |
| FAS_M0_R5_01 | round 5 start | Do you hear them? They are drawn to warmth. To voices. To *me*, perhaps. I must keep this short. |
| FAS_M0_R6_01 | round 6 end | You must reach Kaltenbrunn. Follow the rail line. Do not let the bell ring. |
| FAS_M0_R7_01 | round 7 start | I have notes. Frequencies. I left them— the innkeeper's family, they were... *[pause]* ...I left them in the house. Find them. Tune the set. |
| FAS_M0_R8_01 | round 8 end | Dr. Reinholt does not know I am transmitting. If she knew— no. Never mind what she would do. |
| FAS_M0_R10_01 | round 10 start | Gravelight, it is round— it is the tenth wave. You are still alive. That is... more than I hoped. More than I *deserve* to hope. |
| FAS_M0_R12_01 | round 12 start | If the signal is lost, you will still come. You must. I have everything they want. Everything. |
| FAS_M0_R15_01 | round 15 start | [very clear, then cutting out] Gravelight, a word of warning. The voice on the loudspeakers, the cheerful one. Do not believe a single— *[cut]* |
| FAS_M0_R20_01 | round 20 start | [faint] ...still there? *[soft laugh]* Stubborn. Good. Stubborn is good. |
| FAS_M0_IDLE_01 | radio interacted, no quest | [static] —asmacher... the notes... the frequencies... |

### 4.2 Map 0: three-frequency mini-quest (`radio_tuned`)
The player finds 3 notes (randomized among 6 spots across TAPROOM / UPSTAIRS / STABLE) giving **3.120**, **5.785** and **7.440** Mc/s. Tuning the bar radio in order plays each line. A wrong frequency gives static plus a faint Operator laugh (`OPR_M0_WRONG_01`: "[distant] {Wrong} number!").

| ID | Freq | Line |
|---|---|---|
| FAS_M0_FREQ1_01 | 3.120 | [tuned, clear] Yes! Yes, this is better. Gravelight, my name is Emil Fasbender. I am a physicist at the Kaltenbrunn works. I was the one who called London. I am the reason you are here. |
| FAS_M0_FREQ2_01 | 5.785 | In the mine they found a stone. Black glass, veins like a bruise. It hums. The dead near it... remember. Only one thing. Hunger. Reinholt calls it a miracle. I call it a *mistake* we keep making. |
| FAS_M0_FREQ3_01 | 7.440 | Listen carefully. In the morning the snow will stop and they will stop with it, for a while. Follow the rail line east, nine kilometres. A gatehouse, a headframe tower. I will find you. And Gravelight... bring whoever is still standing. *[pause]* Bring all of them. *[click]* |
| FAS_M0_FREQ_DONE_PEG | (after 3, if Peg present) | [faint, almost off-mic] ...and Lieutenant Ashworth, I know what London asked of you. We will discuss it. |

*After FREQ3:* the cutscene-lite plays (radio sparks, camera pans to the window, the rail line in the moonlight, a distant bell's single toll). It sets the `map00_complete` (quest `map00_radio`) flag.

### 4.3 Map 1: radio code fragments (`M1_CODE`, step 2)
Three radios at randomized locations (pools: Gatehouse / Coal Shed / Boxcar / Admin 2F office / Mess Hall / Chapel vestry / Generator office / Lab corridor). Each plays a fragment with a **digit pair** and a **color word**. The full code entered at the Admin switchboard is 6 digits. The digits are generated per match. The script uses `%d1%` tokens filled at runtime, and subtitles show them too.

| ID | Line |
|---|---|
| FAS_M1_CODE1_01 | [recorded, older static] If you are hearing this, the power is on and you are deeper than I wanted you to be. First line of the exchange: %d1% %d2%. *Red*, for the first. Remember red. |
| FAS_M1_CODE2_01 | Second pair: %d3% %d4%. *Blue*. I chose colors so the cheerful one could not make sense of it. It counts numbers; it does not understand them. Not yet. |
| FAS_M1_CODE3_01 | Last pair: %d5% %d6%. *White*. The switchboard in Administration. Red, blue, white. Then I can speak to you properly. Live. If I am still alive. |
| FAS_M1_CODE_ANY_ORDER | (any radio found 2nd/3rd) | (plays the radio's own fragment; the color word tells the order) |

### 4.4 Map 1: switchboard reveal (step 2 complete, tier 4)
| ID | Line |
|---|---|
| FAS_M1_SWITCH_01 | *[line clicks open, clean audio, no static for the first time]* ...Hello? Gravelight? Oh, thank God. Thank God. You made it to the mine. |
| FAS_M1_SWITCH_02 | I am below you, in a place the Ledger cannot hear, which is very few places. Listen. The heart in the vault, the great crystal. Everything here draws from it. The dead, the tonics, the crates, the *voice*. If it breaks, it all breaks. |
| FAS_M1_SWITCH_03 | Augusta, Dr. Reinholt, does not want it broken. She wants it *louder*. She believes her daughter is inside. *[pause]* I don't know that she's wrong. That's what frightens me. |
| FAS_M1_SWITCH_04 | There is a bell, a weapon I designed for clearing collapses. The Totenglocke. The parts are scattered. Build it, and I will tell you what comes next. |

### 4.5 Map 1: other story lines
| ID | Trigger | Line |
|---|---|---|
| FAS_M1_POWER_ON_01 | power_on (via any radio, once) | [static] You turned on the power. Good. And terrible. She'll be watching now. Both of them will. |
| FAS_M1_VAULT_01 | vault_opened (after REI) | That was her. That was Augusta. She is not here, she's speaking from somewhere along the line. Do not answer her. |
| FAS_M1_S3_DONE_01 | Totenglocke built | You built it! Its note matches the chapel bell, matches the heart. Now, the Overseer, Mahlknecht. He keeps the reliquary key. You will find him where the bell is lit. |
| FAS_M1_S5_01 | music box | That box... that was Liesl's. Augusta brought it here in 'thirty-nine. The tune is different every time it plays. The heart *chooses*. Ring the four bells in its order. |
| FAS_M1_S6_DONE_01 | bells done | The heart is listening to you now. Something will try to leave. Something small. Don't let it. |
| FAS_M1_S7_DONE_01 | shard dropped | That shard, it's been inside the crate all this time, carried back and forth. Put it in the Crucible. Feed it the dead. It will overload the heart from inside. |
| FAS_M1_S9_START_01 | Heartstorm | This is it! Hold, hold for two minutes! When it breaks, run for the lift! Gravelight, I'm— *[cut off by REI hijack]* |
| FAS_M1_ENDING_01 | ending (radio, after cutscene) | ...Gravelight? It's done. I... I am at the rail siding. She took the train. She has a fragment. Of course she does. Of course she— *[deep breath]* ...I'll meet you at the siding. Bring the samples. *[pause]* I mean, bring yourselves. |

### 4.6 Fasbender puzzle hints (`HINT_FAS`, tier 2, hint mode on or player stuck > 6 min on a step)
| ID | Step | Line |
|---|---|---|
| FAS_HINT_S1_01 | 1 | The Hauptschalter, the main switch, is in the Generator Hall. Nothing in this place happens without power. |
| FAS_HINT_S1_02 | 1 | The pylons sing only when someone stands beside them. Don't leave them. |
| FAS_HINT_S2_01 | 2 | My recordings are on the old field sets. Listen for static that doesn't belong. |
| FAS_HINT_S3_01 | 3 | A bell, a frame, a crank. Rail Yard, Barracks, Chapel. The workbench is by the turbines. |
| FAS_HINT_S4_01 | 4 | The chapel bell lights for only the forge's work. Strike it with something that has been through the Crucible. |
| FAS_HINT_S4_02 | 4 | Mahlknecht must die *in* the chapel, while the bell burns. Lure him there. |
| FAS_HINT_S6_01 | 6 | Four bells: the yard, the offices, the chapel, the laboratory. Small ones. Brass. Look up. |
| FAS_HINT_S6_02 | 6 | Play the box again if you forget. The order is all that matters. |
| FAS_HINT_S7_01 | 7 | When the crate next moves, the drummer will not vanish. Watch it. Shoot it. |
| FAS_HINT_S8_01 | 8 | Use the bell-weapon near the vault. Thirty of them. The shard wants their last breath. |

---

## 5. Dr. Augusta Reinholt (`REI`)

**Voice direction:** early 40s, Berliner, educated, measured, warm, and terribly tired. Tragic, never cartoonish. She speaks to the squad as if they were well-meaning children in her way. On cylinders she is younger and hopeful, then grieving, then certain. On PA hijacks the Operator's voice audibly *glitches out* beneath hers. Channel: `PHONO` (cylinders) and `PA` (hijacks).

### 5.1 Phonograph cylinders (Map 1 side EE, `CYL_*`)
Three cylinders hidden in Admin (Reinholt's office), the Barracks (the chaplain's locker) and the Lab Wing (the nursery shrine). Played on any of the 3 phonographs. Playing all three unlocks **"Lanterns Down Below"**.

| ID | Cylinder | Line |
|---|---|---|
| REI_CYL1_01 | 1, 1938 | *[hiss]* Laboratory diary, Kaltenbrunn, the eleventh of December, nineteen thirty-eight. The specimen from shaft four is... remarkable. It is warm in the hand. It makes a sound like a held breath. Emil says it is only piezoelectric. Emil is very sure of everything until he isn't. |
| LSL_REC_CYL1_01 | 1 (end) | *[child, close to the horn]* Mama, is it recording? Is it— *[giggle]* Hallo! This is Liesl! Herr Tamtam says hallo too! *[toy drum: rum-tum, tum-a-tum]* |
| REI_CYL2_01 | 2, 1939 | *[hiss, voice flat]* The fourteenth of February, nineteen thirty-nine. Liesl died at four in the morning. Diphtheria. A membrane across her throat. I am a doctor. I could do nothing. *[long pause]* The stone hummed all night. I listened to it, so I would not have to listen to the silence in her room. |
| REI_CYL3_01 | 3, 1943 | *[hiss, clear, warm, certain]* Subject seven-forty walked. Not hunger, not at first. For one minute it looked for something. It went to the window. *They remember.* The last impulse. Liesl's last impulse was to call for me. I was there when she died. I heard it. If the impulse remains, then *she* remains, somewhere in the glass. I only need it louder. |
| LSL_REC_CYL3_01 | 3 (end, faint, wrong speed) | *[child's voice, slowed, as if from far away]* Mama... count to a hundred... and then come find me... |

**(§11 amendment)** `REI_CYL1_01`: "the eleventh of **October**, nineteen thirty-eight" → "the eleventh of **December**." The specimen can't predate the locked probe landing of 9 November 1938. Nothing else in the line changes.

### 5.2 Vault open (step 1, tier 4)
| ID | Line |
|---|---|
| REI_VAULT_OPEN_01 | *[PA crackle; the Operator's music stutters and dies]* So. Emil's soldiers. You've woken the heart. Do you feel it? It's not angry. It is *listening*. Please, be careful what you say to it. |

### 5.3 Story PA lines (tier 4)
| ID | Trigger | Line |
|---|---|---|
| REI_S5_BOX_01 | music box played | [PA, faint, private] ...that is hers. Put it down. *[pause]* No. Play it. Play it again. I haven't heard it in five years. |
| REI_S7_DRUMMER_01 | drummer shot | You've broken her toy. She took that drummer to bed every night. *[breath]* It doesn't matter. Things break. That's what I've been trying to undo. |
| REI_S8_01 | shard in Crucible | Emil has told you to kill the heart. Has he told you what is *in* it? Thousands. Every miner, every laborer, every one you've "quieted." Their last moments, kept. You are not killing monsters. You are burning a library. |

### 5.4 Heartstorm PA hijacks (step 9, tier 4, timed)
| ID | Time | Line |
|---|---|---|
| REI_HEART_00 | 0:00 | *[Operator's voice shredding into static]* Stop. Stop this. You don't understand what you're doing! |
| REI_HEART_15 | 0:15 | Emil, I know you're listening. You always were a coward with a radio. |
| REI_HEART_30 | 0:30 | Do you know what I hear in the heart? Footsteps. Small ones. Running down a hallway. Every night. |
| REI_HEART_45 | 0:45 | You there, the Polish girl. Your brother is in there too. Tomasz. Yes, I know the name. I know every name. You could *hear* him again. |
| REI_HEART_60 | 1:00 | *[Foreman spawns]* Mahlknecht! Protect it! |
| REI_HEART_75 | 1:15 | Lieutenant Ashworth. London wants a piece of it too, don't they? Ask your lieutenant what she carries home. |
| REI_HEART_90 | 1:30 | *[Foreman 2 spawns]* Please. Please. She is nine years old. She has been nine years old for five years. |
| REI_HEART_105 | 1:45 | *[breaking]* Liesl, run. Run to Mama. *Run!* |
| REI_HEART_END | 2:00 | *[scream that becomes the bell toll; PA dies]* |

*Note:* `REI_HEART_45` only plays if Wren is in the match, and `REI_HEART_75` only if Peg is. Fallback lines:
| REI_HEART_45_ALT | 0:45 | Every one of them had a mother. Have you thought about that, soldier? Even once? |
| REI_HEART_75_ALT | 1:15 | Your governments will come for what's left. They always do. You're only clearing the way. |

### 5.5 Ending (spoken in cutscene, see §7)
| ID | Line |
|---|---|
| REI_END_01 | *(on the train, to the fragment in her hands, softly)* Hush. Hush now. I've got you. We'll find somewhere quieter. |
| REI_END_02 | *(PA, final; heard only over the dying speakers)* Emil. You'll follow me. You always do. North, to the sea. |

---

## 6. Liesl (`LSL`)
Only on recordings and in the music box tune. Never a "ghost" talking live in Map 1. Her lines appear inside cylinder files and two ambient secrets. Child actor guidance: natural, unscripted-feeling, playful. Process to sound like a 1938 home recording.

| ID | Where | Line |
|---|---|---|
| LSL_REC_CYL1_01 | Cylinder 1 end | (see §5.1) |
| LSL_REC_CYL3_01 | Cylinder 3 end | (see §5.1) |
| LSL_REC_NURSERY_01 | Lab Wing nursery shrine, interact with the toy piano | *[soft, distant]* ...one, two, three, four... *[the 4 notes of the per-match melody, played clumsily]* ...Mama, I did it! |
| LSL_REC_DRUMMER_01 | rarely (1/20) when the crate drummer appears, after quest step 5 done | *[faint giggle under the drum]* |
| LSL_REC_HIDE_01 | Heartstorm end, layered under the bell | *[whisper]* ...ninety-eight... ninety-nine... |

---

## 7. Map 1 ending cutscene: "Requiem for Kaltenbrunn" (in-engine, ~90 s)

**Line IDs:** cutscene-only lines and shot cues use the `CUT_REQ_*` prefix (shot N = `CUT_REQ_SHOT_NN`). Spoken lines reuse the speaker IDs listed.

**Setting:** triggered at Heartstorm completion. The camera leaves the player. All players are invulnerable. Zombies freeze, crack and shatter. Subtitles on. Skippable after first viewing (profile flag).

| Shot | Time | Visual | Audio / VO |
|---|---|---|---|
| 1 | 0:00 | **Core Vault.** The heart crystal fractures. Violet-amber light pours through the cracks, the cage bars bend outward, and all Gängers on the map freeze mid-step. | A rising single tone. `LSL_REC_HIDE_01` under it. Then silence. |
| 2 | 0:06 | Slow push-in on the heart. One last pulse, then it **collapses** inward, a falling avalanche of black glass. The shockwave blows out lights zone by zone (a reverse of the power-on sweep). | A shatter cascade, then the chapel bell's final toll at full volume, cut dead. |
| 3 | 0:14 | **Montage across zones:** frozen Gängers crumble to salt and shards. A Bellringer lantern falls and rolls. The Foreman's drill arm whirs down to a stop. | `OPR_QUEST_S9_END_01` overlapping, warped. |
| 4 | 0:22 | **The Ledger room.** Relay banks clatter to stillness. One last bank of lamps blinks out, all except one, which glows faintly. | `OPR_QUEST_S10_01` ("I think I was {somebody}. Goodnight."). The last lamp stays lit: a sequel hook. |
| 5 | 0:32 | **Surface, Rail Yard, dawn.** The snow is lit pink. An ore train is already moving out through the gates, with a single passenger carriage. | Train whistle, distant. |
| 6 | 0:38 | **Interior, train carriage.** **Dr. Reinholt** (first time seen): a grey wool coat, hair pinned, a bandaged hand. She cradles a fist-sized violet fragment wrapped in a child's blanket. Behind her on the seat sits **Herr Tamtam**. *If step 7 shot it: the drummer is cracked and missing its drumstick.* | `REI_END_01` |
| 7 | 0:50 | Exterior: the train passes under the headframe. Wren is on the gatehouse roof and raises her rifle, but the shot is blocked by a boxcar. She lowers it. | Wren breath. Optional character line `WRN_EE_END_TRAIN_01` (CHARACTERS.md). |
| 8 | 0:58 | **Minehead Yard.** The squad (whoever played; generic silhouettes for absent characters) regroups, exhausted, by the lift. Dutch sits heavily on an ore cart. Deacon lays a hand on the headframe's leg like a horse's neck. Wren writes in her notebook. | Character banter: `{SPK}_EE_END_*` in CHARACTERS.md. |
| 9 | 1:08 | **Peg**, slightly apart. The others' backs are turned. She crouches, picks a thumb-sized Nachtglas shard from the snow, wraps it in a handkerchief, and slides it into her tunic. Close-up of her face: no expression. *(Plays even if Peg wasn't a player, as an NPC.)* | No VO. A single low note. The heart's tritone hum, very faint, follows her. |
| 10 | 1:16 | **The PA horn** on the headframe crackles one final time. | `REI_END_02`. Then `FAS_M1_ENDING_01` from Peg's field radio. |
| 11 | 1:26 | Pull out over the snowy valley. The train's smoke trails north toward the sea. Title card: **REQUIEM FOR KALTENBRUNN: COMPLETE.** Then a card: *Totenhafen: the trail leads north.* | "Lanterns Down Below" intro hum (if unlocked) or a solo music box playing the per-match melody. |

**Post-cutscene:** return to gameplay with rewards (all perks above cap, etc.). The Operator is **silent for the rest of the match**: every `OPR` line is suppressed, replaced by soft static. If the match continues, Map 1's ambient score switches to its "aftermath" layer.

---

## 8. Playable character line categories (defined in CHARACTERS.md)

The VOManager expects these categories for each of `DUT`, `PEG`, `DEA`, `WRN` (IDs `{SPK}_{CAT}_{NN}`):

`SPAWN`, `ROUND_START`, `ROUND_END`, `EXHAUST` (round 50+), `BUY_WEAPON_PISTOL`, `BUY_WEAPON_RIFLE`, `BUY_WEAPON_SMG`, `BUY_WEAPON_SHOTGUN`, `BUY_WEAPON_LMG`, `BUY_WEAPON_LAUNCHER`, `BUY_WEAPON_MELEE`, `BUY_AMMO`, `CRATE_GOOD`, `CRATE_BAD`, `CRATE_WONDER`, `CRATE_DRUMMER`, `PERK_{IRONHIDE, SECONDWIND, TRIGGER, TWINBARREL, MARATHON, HAWKEYE, PACKMULE, BLASTPROOF}`, `PWR_GRAB_{RESUPPLY, DEATHSDOOR, DOUBLESCRIP, BLACKOUT, FORTIFY, CLEARANCE}`, `SPECIAL_START`, `BOSS_FOREMAN`, `BOSS_SCREAMER`, `KILL_GLASSHIDE`, `LOW_AMMO`, `NO_AMMO`, `DOWNED`, `TEAM_DOWN`, `REVIVE`, `REVIVED`, `STREAK`, `HEADSHOT`, `DENY_NO_POWER`, `DENY_CAP`, `DENY_NO_SCRIP`, `DOOR`, `ZONE_{ZONE}`, `POWER_ON`, `TRAP`, `INTEL`, `HINT_{STEP}`, `EE_{STEP}`, `EE_SONG`, `EE_DOGTAG` (Wren/Dutch exchange), `EE_END_*`, banter lines use the `BNT_*` prefix (e.g. `BNT_DUT_WRN_01`).

`PERK_*` short tokens map to perk IDs as follows: `IRONHIDE` → `ironhide_stout`, `SECONDWIND` → `second_wind`, `TRIGGER` → `trigger_tonic`, `TWINBARREL` → `twin_barrel`, `MARATHON` → `marathon_malt`, `HAWKEYE` → `hawkeye_brandy`, `PACKMULE` → `packmule_porter`, `BLASTPROOF` → `blastproof_bock`.

**(T-035 voice pass)** The squad categories that existed in this list but had no lines now do: `SPAWN`, `ROUND_START`, `ROUND_END`, `BUY_AMMO`, `TEAM_DOWN`, `INTEL`, `DENY_NO_POWER` / `DENY_CAP` / `DENY_NO_SCRIP` (CHARACTERS.md §8). The implemented ids use the short forms already in CHARACTERS.md: `BUY_{CLASS}` (not `BUY_WEAPON_*`), `AMMO_LOW` / `AMMO_NONE`, `DOWN`, `FOREMAN` / `SCREAMER` (not `BOSS_*`), `GLASSHIDE`, `BELL` for a special round. Twelve more short banter exchanges (`BNT_*_04` / `_05`). Every line has baked placeholder audio (`gen_vo.py`, `data/gravelight/vo/audio_manifest.json`).

**(§11 amendment)**
- **New perk tokens:** `FERNET` → `fine_print_fernet`, `OVERCLOCK` → `overclock_cordial` (squad lines in CHARACTERS.md §5).
- **New categories:** `CRATE_ANOMALOUS`, `SPECIAL_AUDIT`, `BOSS_UNDERWRITER`, `KILL_REPOSSESSOR`.
- **New speakers:** `BLT` Bolt, `SPR` Sprocket, `VEN` Vendelin (quote packs `gl.qp.*`, CHARACTERS.md §6–7), `BLZ` Blartz (Omega Forge, PA), and `UWR` Underwriter, `RPO` Repossessor, `SBL` Woman in Violet, and the Board as speaker id **`darkmatter`** (`BARGE` / `WORLD` channels, Ch. 5 script).
- **New channel:** `BARGE` (Ch. 5 script §0.2).

---

## 9. Line count summary (first pass)
| Speaker | Lines |
|---|---|
| OPR | ~150 |
| FAS | ~40 |
| REI | ~25 |
| LSL | 5 |
| Total NPC/announcer | ~220 |

Open items for the next pass: Map 0 Operator fragments (more `M0` lines), Glasshide/Bellringer-specific Operator quips, co-op-specific Operator lines (team wipes, revives), Map 2/3 placeholders, and localization string tables.

**(§11 amendment)** Helvetia Works system announcements and the anomalous-crate line are in §9. The `op.slip.*` playback rules are in §10. Story lines for Helvetia Works are in `docs/fineprint/script_ch5.md`.

---

## 9. Helvetia Works and cross-map Operator announcements (§11 amendment)

**ID scheme.** New lines use `gl.<map>.<speaker>.<topic>.<nn>` (M0_SHARED_FACTS). The map key is `helvetia` or `all`. The VOManager accepts these IDs alongside `{SPK}_{CAT}_{NNN}`; the `category` field in data is the same as the topic.

**Who owns what on Helvetia Works:**
- **This section** owns the Operator's **system announcements**: rounds, power, the beam, Audit Rounds, the Underwriter's schedule, the organ step and the anomalous crate.
- **`docs/fineprint/script_ch5.md` §3–§6** owns every **story** line: cold opens, banter, `fp.c5.op_*` story beats, `fp.c5.uw_*` / `fp.c5.repo_*` / Woman in Violet / Board lines, the Clause Zero step lines, and the corporate slips `op.slip.*`. **If a story line and a system line fire on the same event, the story line wins** (tier 4 over tier 3).

On Darkmatter hardware the Operator's splices are cleaner (Ch. 5 §0.2). Mark spliced words `{like this}` as before.

### 9.1 Anomalous Inventory (all maps, `ANOMALOUS`, tier 3, 100% on roll)
| ID | Line | Condition |
|---|---|---|
| `gl.all.opr.anomalous.01` | This item is not from your era. Please enjoy responsibly. | first anomalous roll per match always plays .01 |
| `gl.all.opr.anomalous.02` | Oh! A {returned} item! This item is not from your era. Please enjoy responsibly. | |
| `gl.all.opr.anomalous.03` | Inventory from {elsewhere}! This item is not from your era. Please enjoy responsibly. | |
| `gl.all.opr.anomalous.04` | This item is not from your era. *[splice]* Neither, I suspect, am {I}. Please enjoy responsibly. | round 25+ |
| `gl.helvetia.opr.return_policy.01` | The Return Policy! Unsatisfied customers may now be {returned}. No receipt required. | Return Policy rolled (Helvetia) |
| `gl.helvetia.opr.return_policy.02` | Ooh, a refund gun. Do keep it pointed at {them}. | |

### 9.2 Helvetia Works: match start, power, rounds (tier 3 / 2)
| ID | Category | Line |
|---|---|---|
| `gl.helvetia.opr.match_start.01` | `MATCH_START` (standalone; story mode uses the Ch. 5 cold open) | Good evening, valued customers, and welcome to the Helvetia works, Basel! Your Friend at the Ledger is {on location} tonight. |
| `gl.helvetia.opr.match_start.02` | `MATCH_START` | Station identification: *Sender*... *[splice]* {Basel}. Isn't it nice to be somewhere {neutral}? |
| `gl.helvetia.opr.power_on.01` | `POWER_ON` (tier 3, once) | *[orchestra swell through a factory tannoy]* Ladies and gentlemen, the works are {running}! Every machine on the line is warm, and every one of them is {yours}. Please form an orderly queue. |
| `gl.helvetia.opr.power_on.02` | `POWER_ON` (follows .01 after 6 s) | Do listen to them sing. He wrote every one, you know. {Every} one. |
| `gl.helvetia.opr.round_start.01` | `ROUND_START` | Night shift, {report}! |
| `gl.helvetia.opr.round_start.02` | `ROUND_START` | Another round at the Helvetia works! Production is {up}! |
| `gl.helvetia.opr.round_start.03` | `ROUND_START`, round 10 | Round {ten}! Ten rounds, and not a single complaint. We do so love a {loyal} customer. |
| `gl.helvetia.opr.round_start.04` | `ROUND_START`, round 20 | Round {twenty}. The barge has been watching your numbers. They're {exceptional}. |
| `gl.helvetia.opr.round_end.01` | `ROUND_END` | Shift's over! Please clock out at the {gate}. *[beat]* There is no gate. |
| `gl.helvetia.opr.round_end.02` | `ROUND_END` | And that's a round! The barge sends its {regards}. |
| `gl.helvetia.opr.game_over.01` | `GAME_OVER` | That concludes tonight's {shift}. Your accounts are {closed}. Do come again. You'll come {again}. |

### 9.3 The beam and the Barge (tier 3)
| ID | Trigger | Line |
|---|---|---|
| `gl.helvetia.opr.beam_tag.01` | first Recall Tag inserted | One recall tag received! Two to go. Collect the {whole} set! |
| `gl.helvetia.opr.beam_tag.02` | second tag | Two of three! Your return is {nearly} in order. |
| `gl.helvetia.opr.beam_tag.03` | third tag | Three tags! Your {return} may now be filed at the dispatch desk. |
| `gl.helvetia.opr.beam_request.01` | File a Return bought (Loading Dock) | Return filed! A collection has been {scheduled}. Please wait with your parcel. Forty seconds. |
| `gl.helvetia.opr.beam_pause.01` | return window paused | Your collection window is {open}. Please don't wander off. Nobody ever {wanders off}. |
| `gl.helvetia.opr.beam_open.01` | `beam_open` | Your collection has {arrived}! Mind the gap. *[beat]* It's a very large gap. |
| `gl.helvetia.opr.barge_enter.01` | first player boards the Barge (once per match) | Welcome aboard! Please keep your hands off the {inventory}. |
| `gl.helvetia.opr.barge_enter.02` | later boardings (25%) | Back again! Everyone {comes back}. |

### 9.4 Audit Rounds (`SPECIAL_WARN` / `SPECIAL_START` / `SPECIAL_END` on Helvetia, tier 3)
| ID | Category | Line |
|---|---|---|
| `gl.helvetia.opr.audit_warn.01` | `SPECIAL_WARN` | Attention, valued customers: an {audit} is now in progress. Please have your accounts {ready}. |
| `gl.helvetia.opr.audit_warn.02` | `SPECIAL_WARN` | *[after the chime]* This is a courtesy announcement. Your account is under {review}. |
| `gl.helvetia.opr.audit_warn.03` | `SPECIAL_WARN` | Ladies and gentlemen, the auditors have {arrived}! Don't be alarmed. They're only here for what's {theirs}. |
| `gl.helvetia.opr.audit_start.01` | `SPECIAL_START` | Here they come! Please remain {seated}. |
| `gl.helvetia.opr.audit_start.02` | `SPECIAL_START` | The collectors are {in}! Everybody look your most {valuable}. |
| `gl.helvetia.opr.audit_seize.01` | Repossessor seizes Scrip (30%, 20 s cooldown) | Oh dear. A little something has been {withheld}. |
| `gl.helvetia.opr.audit_seize.02` | | Don't worry. It's being kept {safe}. It's being {kept}. |
| `gl.helvetia.opr.audit_recall.01` | Repossessor recalls a zombie (10%, 30 s cooldown) | One of ours, {collected}! |
| `gl.helvetia.opr.audit_recall.02` | | Returned to {stock}! |
| `gl.helvetia.opr.audit_end.01` | `SPECIAL_END` | Audit complete! Your account is in good {standing}. For now. |
| `gl.helvetia.opr.audit_end.02` | `SPECIAL_END` | The auditors have {left}. Here's a little something for your patience. |

### 9.5 The Underwriter: schedule and findings (tier 3)
| ID | Trigger | Line |
|---|---|---|
| `gl.helvetia.opr.underwriter_scheduled.01` | one round before arrival | A reminder: your audit has been scheduled for {next round}. We suggest you {spend} accordingly. |
| `gl.helvetia.opr.underwriter_scheduled.02` | (alt) | Friendly notice! The Underwriter will see you {next round}. Please don't keep it waiting. It {never} waits. |
| `gl.helvetia.opr.underwriter_arrive.01` | landing | The Underwriter is {in the building}! Please have your valuables {ready}. |
| `gl.helvetia.opr.underwriter_audit.01` | summoned by Clause Zero step 6 | Oh! An {unscheduled} audit. How very {thorough}. |
| `gl.helvetia.opr.underwriter_price.01` | a player's tier reaches 3+ (once per player per fight; `%name%` token) | The Underwriter has assessed %name% at... oh, {my}. |
| `gl.helvetia.opr.underwriter_price.02` | (alt) | %name% is looking very {valuable} this evening. |
| `gl.helvetia.opr.underwriter_price.03` | any player drops a tier by spending (20 s cooldown) | Ooh, a {spender}. The Underwriter has revised its estimate. |
| `gl.helvetia.opr.underwriter_withdraw.01` | it files its report | The Underwriter has filed its {report}. Results will be posted. They're {always} posted. |
| `gl.helvetia.opr.underwriter_destroyed.01` | destroyed | Oh. The Underwriter has been... {written off}. That's never happened before. I'll make a {note}. |

### 9.6 Clause Zero system lines and side eggs (tier 3)
| ID | Trigger | Line |
|---|---|---|
| `gl.helvetia.opr.organ_wrong.01` | wrong glyph (step 4b) | Oh, that's not how it {goes}! I should know. I've heard it a thousand times. |
| `gl.helvetia.opr.organ_wrong.02` | | Wrong note! The {approved} version is so much catchier. |
| `gl.helvetia.opr.organ_wrong.03` | | Please play the one we {liked}. |
| `gl.helvetia.opr.organ_wrong.04` | | *[cold, unspliced for one word]* *Don't.* ...I mean, do have another go! |
| `gl.helvetia.opr.drummer_refused.01` | side egg "Returned to Sender" | Oh, no, no. That item isn't {ours}. *[beat]* It's never been ours. |
| `gl.helvetia.opr.malt.01` | side egg "Grossmüeti's Malt" brewed | Something {homemade}! How very off-brand. |

The Omega Forge's Blartz lines and the Operator's disclaimers are in WEAPONS.md §17. The Crucible on the Barge uses `OPR_CRUCIBLE_*` unchanged.

### 9.7 Map 3 reservation
| ID | Trigger | Line |
|---|---|---|
| `gl.map03.opr.refuse.01` | Map 3 **Refuse** ending, last Operator line (LORE.md §9.3; kept for the Reinholt "pull her out" branch) | *[unspliced, slowing]* Cancellation... cannot be... {processed}— *[the station goes off the air]* |

The full Morgenrot line plan is §11 (ids reserved; the lines are written in M8.5).

---

## 10. The Operator's corporate slips: `op.slip.*` rules (§11 amendment, §11.5)

**The lines:** 32 slips, `op.slip.01`–`op.slip.32`, written by the Ch. 5 writer in `docs/fineprint/script_ch5.md` §3 ("Thank you for your continued engagement." / "Your plan has been renewed." / "Valued customer, please do not cancel." and the rest). **This section owns only when and how they play.** Per-line conditions written in the Ch. 5 script (`min_round`, `map`, `once_per_profile`) are honored on top of these rules.

**What a slip is:** the Customer Retention Interface's native language showing through the "Uncle Lionel" localization (`docs/FINEPRINT_LORE.md` §4.8). It must stay **rare and unsettling**, and get **more frequent at high rounds**.

**Delivery modes**
1. **Tail slip:** appended **0.6 s after** a normal Operator line of tier 2–3, in the same `PA` channel, as if the sentence kept going on its own.
2. **Standalone slip:** replaces a tier-0 `IDLE_SELFAWARE` pick.

**Chance per eligible Operator line (tail):**
```
p(r) = min(0.12, 0.01 + 0.0022 × r)      # r1 ≈ 1.2%, r10 ≈ 3.2%, r20 ≈ 5.4%, r30 ≈ 7.6%, r50 = 12%
p_map = p(r) × map_mult,  capped at 0.20
map_mult: Map 0 = 0 before round 15, then 0.5 (the Operator is barely formed)
          Map 1 = 1.0 · Helvetia Works = 2.0 (the barge is overhead) · Map 2 = 1.5 · Map 3 = 2.0 (the deal comes due)
```
**Standalone chance:** when `IDLE_SELFAWARE` fires, it is replaced by a slip with probability `min(0.5, 3 × p_map)`.

**Limits**
- **Global cooldown** between slips: **300 s** (240 s on Helvetia Works and Map 3).
- **Per round:** at most **1** slip before round 25 and **2** from round 25.
- **Never** during a tier-4 line, a cutscene, a quest holdout's scripted VO, or the 10 s after any player goes down.
- **Never after the Map 1 ending** in that match. The Operator is silent then (§7).
- **Never** in the first 3 rounds of a player's first-ever match.
- **No-repeat:** a **profile-wide** shuffle bag (stored in ProfileSave). Every slip plays once before any repeats, so the slow burn spans many matches, like `IDLE_SELFAWARE` tiers (§3.12).

**Presentation**
- For the length of a slip the **tape hiss, splice seams and band-limiting drop out**. The voice is suddenly clean and close, closer to the `BARGE` channel, and the hiss returns 0.3 s after.
- Subtitle text for a slip renders in Darkmatter violet `#c07dff` instead of off-white. The speaker name stays `THE OPERATOR`.
- **No character reacts to a slip.** No VO is triggered by one. The squad doesn't hear it as anything but the cheerful voice being strange (tone rule: they never learn).
- Slips are never the Woman in Violet's own voice. The single exception is the Clause Zero finale's last line (`fp.c5.finale`), which is a story line, not a slip.

**Data:** `data/vo/vo_rules.tres` gains `slip_base: 0.01`, `slip_per_round: 0.0022`, `slip_cap: 0.12`, `slip_map_cap: 0.20`, `slip_map_mult: {map00: 0.5, map01: 1.0, map_hw_helvetia: 2.0, map02: 1.5, map03: 2.0}`, `slip_map00_min_round: 15`, `slip_cooldown_s: 300`, `slip_cooldown_hw_map03_s: 240`, `slip_tail_delay_s: 0.6`.

---

## 11. MORGENROT (Map 3) line plan — ids reserved for M8.5 (ULTIMATE PROMPT v2 §8; design doc `docs/MAP3_MORGENROT.md`)

The ids below are **reserved and not yet written**: this table is a plan, so `extract_vo.py` does not pick them up (no `ID` column). Each block is written in full, with the §1 rules, when M8.5 starts; every one is baked by `gen_vo.py` and listed in `audio_manifest.json`. Counts are minimums.

| Block | Speaker | Line ids (reserved) | Count | Notes |
|---|---|---|---|---|
| 11.1 Rollout | OPR | `OPR_M3_ROLLOUT_01..06` (power on, "regional rollout in N cycles" at 20 / 10 / 5 / 2 / 1, zero), `OPR_M3_HOLD_01..03` (scrubs), `OPR_M3_SURGE_01..02` | 11 | the Operator's countdown is the clock's voice; §10 slips run at ×2 on this map |
| 11.2 Fasbender | FAS | `FAS_M3_CELL_01..04` (the chalk hint, the keys, the abort sequence), `FAS_M3_FOLLOW_01..06` (hints while following), `FAS_M3_MOON_01` ("...at the MOON? Ha. Ha!"), `FAS_END_LAUNCH_01`, `FAS_END_ABORT_01` | 13 | two endings for him (came along / left behind) |
| 11.3 Reinholt | REI | `REI_M3_PA_01..05` (hijacks as the clock drops), `REI_M3_HEARTSTORM_01` ("No more delays."), `REI_M3_PHASE_01..03`, `REI_END_01`, `REI_END_LETGO_01` ("Mein Schatz."), `REI_END_PULLED_01` | 12 | grief, never villainy |
| 11.4 Startmeister barks | NPC | `STM_BARK_01..06`, `STM_PHASE_01..03`, `STM_DEATH_01` | 10 | through the pressure-suit radio |
| 11.5 PA countdown | PA | `PA_COUNT_10..01`, `PA_HOLD_01`, `PA_ZERO_01` | 12 | German, subtitled; the only German-language block |
| 11.6 Endings | OPR / cast | `OPR_END_ABORT_01` (Sable Vantage's real voice), `OPR_END_LAUNCH_01`, `OPR_END_MOON_01`, `OPR_END_MOONB_01`, `WRN_END_NAMES_01..06`, `WRN_END_CLOSE_01`, `PEG_END_DESTROY_01`, `PEG_END_KEEP_01`, `DUT_END_MOON_01`, `DEA_END_MOON_01`, `PEG_END_MOON_01`, `WRN_END_MOON_01`, `BLT_END_MOON_01`, `SPR_END_MOON_01`, `VEN_END_MOON_01`, `*_END_MOONB_01` ×6, epilogue cards ×8 (text) | 34 | CUTSCENES_MORGENROT.md |
| 11.7 Witnesses' marks | NPC (whispers) | `MARK_01..12` (a name and a hometown each; `MARK_TOMASZ_01` is always among the six), `WRN_M3_TOMASZ_01..03` | 15 | the memorial lines are read plainly, never performed |
| 11.8 Squad quote packs | DUT / PEG / DEA / WRN / BLT / VEN | `*_M3_ARRIVE_01..02`, `*_M3_ROCKET_01..02`, `*_M3_CHALK_01`, `*_M3_CLOCK_01..02`, `*_M3_SABOTAGE_01..03`, `*_M3_KESSEL_01`, `*_M3_SUMMIT_01`, `*_M3_LANGE_NACHT_01`, `*_M3_STARTMEISTER_01`, `*_M3_LUFTALARM_01` | 14 × 6 = 84 | Vendelin: the Darkmatter part in the rocket; Bolt / Sprocket: the Moon crack memo |
| 11.9 New enemy tells | — | sound only (ENEMIES.md §6): no lines | 0 | |

Total planned: ~190 lines. Bolt's and Vendelin's packs are gated on v1 §11.9 (playable after Helvetia Works).

---

## 12. HOMAGE BOSSES (HB1–HB3) — the Cousins, PAUL, the Slender: every line (ULTIMATE PROMPT v3 §5; design doc `docs/HOMAGE_BOSSES.md`)

**Written in full, not yet extracted.** These tables are headed `Line id`, not `ID`, so `extract_vo.py` leaves them alone until their milestone. When a milestone starts (HB1: §12.1 Cousins rows, §12.2, and the Cousins / Kinderhammer rows of §12.5–12.6; HB2: the Paul rows; HB3: the Slender rows), switch that block's header to `ID`, run the extractor, and bake with `gen_vo.py` (`audio_manifest.json`). `docs/HOMAGE_BOSSES.md` §8 mirrors this section; this one is the source of truth.

- **New speakers:** `HAM` the Hammer, `RCH` the Reach, `ALX` Alix, `CSN` the Cousins together, `PAU` Paul, `SLN` the Slender (subtitle names follow Settings → Gameplay → Homage Names: Real shows the Likeness Sheet's first name, In-World the epithet). Bolt / Sprocket / Vendelin use the `BLT_` / `SPR_` / `VEN_` form as §11 does; their quote-pack topic aliases are `boss_cousins`, `boss_paul`, `boss_slender`, `kinderhammer`.
- **New channel group:** `BOSS` (positional, one line per boss at a time, not in the story group). Paul's arrival roar uses `PA`.
- **Priority:** boss spawn / death / last lines tier 4; boss barks tier 2; squad reactions tier 1 (tier 2 where marked); the Operator tier 3. The Cousins speak German, subtitled with the English in parentheses (§1.5).
- **Tokens:** `%COUSIN_1_NAME%`, `%COUSIN_2_NAME%`, `%DEAD_COUSIN_NAME%`, `%PAUL_LASTNAME%` come from `data/gravelight/bosses/likeness.json` (defaults when a placeholder is unfilled). A line with a real name has `conditions.homage_names: "real"` and an unnamed twin for In-World mode.
- **Count:** 189 lines (Operator 21, Cousins 35, Paul 22, Slender 20, the squad 66, Bolt / Sprocket / Vendelin 25).

### 12.1 The Operator (spawn and death lines for each boss)

| Line id | Trigger | Line |
|---|---|---|
| `OPR_BOSS_COUSINS_M0_01` | Map 0, end of round 9, the lamps going out | [static, half-formed, through the inn's horn] ...lights {out}, children... lights... {out}... |
| `OPR_BOSS_COUSINS_M0_02` | round 10 starts (spawn) | [static] ...it's... {playtime}. *[a child's clap on the tape]* ...{playtime}... |
| `OPR_BOSS_COUSINS_M0_03` | Alix rises | [static] ...one more... for the {game}... |
| `OPR_BOSS_COUSINS_DEAD_M0_01` | the first cousin dies | [static] ...{two} left... *[tape squeal]* |
| `OPR_BOSS_COUSINS_DEAD_M0_02` | the second cousin dies | [static] ...{one}... |
| `OPR_BOSS_COUSINS_DEAD_M0_03` | all three dead (death line) | [static, almost gentle] ...game... {over}. Good... {night}. |
| `OPR_BOSS_COUSINS_BORED_M0_01` | the 6:00 retreat | [static] ...they'll... come {back}... *[giggling under the hiss]* |
| `OPR_BOSS_COUSINS_RETURN_M0_01` | the round-15 return | [static] ...{ready}... or {not}... |
| `OPR_BOSS_PAUL_01` | Map 1, after the PA roar (spawn) | Oh my! A {gentleman} from overseas has broken into the {studio}! Do give him a warm welcome! |
| `OPR_BOSS_PAUL_02` | spawn (variant) | Ladies and gentlemen, our {strongest} account! Tremendous {tolerance}. Simply tremendous! |
| `OPR_BOSS_PAUL_03` | a return visit | Back by popular {demand}! And bigger than {ever}! |
| `OPR_BOSS_PAUL_RAGE_01` | his first BERSERK | Oh dear. He's gone right {off} the chart. We'll need a bigger {chart}! |
| `OPR_BOSS_PAUL_LEFT_01` | the 6:00 retreat | And he's off to find his {friends}! Aren't we {all}. |
| `OPR_BOSS_PAUL_DEAD_01` | his death (after the fall) | [three seconds of dead air] ...Maximum dose... {recorded}. *[and, very quietly, a splice from some other broadcast]* {Well done.} |
| `OPR_BOSS_SLENDER_01` | Morgenrot, round 20 (spawn) | Attention, valued customers: the night {shift} is now on duty. Please have your {papers} ready. |
| `OPR_BOSS_SLENDER_02` | spawn (variant) | Our {watchman} has never missed a night. Not {one}. Do try not to be {noticed}! |
| `OPR_BOSS_SLENDER_03` | Shift Change | Shift {change}! Three for the price of {one}! |
| `OPR_BOSS_SLENDER_04` | End of Shift | We are experiencing a brief {outage}. Please remain where you can be {seen}. |
| `OPR_BOSS_SLENDER_QUAR_01` | a player quarantined | A {customer} has been taken in for {review}. |
| `OPR_BOSS_SLENDER_LEFT_01` | the 8:00 retreat | The watch is... {rescheduled}. He'll be by again. He's always {by}. |
| `OPR_BOSS_SLENDER_DEAD_01` | his death | The night watch has clocked {out}! And dawn is... {closer} than you think. |

### 12.2 The Cousins (`HAM`, `RCH`, `ALX`, `CSN`)

| Line id | Trigger | Line |
|---|---|---|
| `CSN_CLAP_01` | end of round 9, upstairs | [three pairs of hands clapping the rhyme's rhythm, then stopping] |
| `CSN_HUM_01` | trio alive (stems, looped) | [the rhyme hummed in three voices: `jingle.cousins_rhyme` §9, stems A / B / C] |
| `CSN_WHISPER_01` | after the first death | [the rhyme whispered by the two survivors] |
| `CSN_GIGGLE_01` | random, 20–40 s | [a giggle from a room nobody is in] |
| `CSN_GIGGLE_02` | random | [two giggles, then a shush] |
| `CSN_BORED_01` | the 6:00 retreat | Langweilig! Morgen wieder! (Boring! Again tomorrow!) [laughing, running] |
| `CSN_RETURN_01` | the round-15 return | Bereit oder nicht, wir kommen! (Ready or not, here we come!) |
| `CSN_LASTLINE_01` | the ice cellar, all three chalk figures shot | [softly, three voices together, not scary] ...und wer noch übrig ist, ist dran. (...and whoever's left is it.) [a pause] Gute Nacht. (Good night.) |
| `HAM_THROW_01` | Mallet Throw release | Fang! (Catch!) |
| `HAM_CATCH_01` | the catch | [a giggle, cut off dead] |
| `HAM_SEE_01` | sees a new target | Ich seh dich. (I see you.) |
| `HAM_IT_01` | a player downed by her | Du bist dran. (You're it.) |
| `HAM_WOOD_01` | Overhead Split | Holz für Tante! (Wood for Auntie!) |
| `HAM_ENRAGE_01` | a cousin dies (named) | %DEAD_COUSIN_NAME%? ...%DEAD_COUSIN_NAME%! |
| `HAM_ENRAGE_TWIN_01` | the same (twin) | Wo bist du? ...Komm raus! (Where are you? ...Come out!) |
| `HAM_ALONE_01` | the last one standing | Jetzt sind nur noch ich. (Now there's only me.) [wrong on purpose: a child's grammar] |
| `HAM_DEATH_01` | death (sitting) | ...Ich mag nicht mehr spielen. (...I don't want to play any more.) |
| `RCH_COUNT_01` | idle (her fingers counting) | [whispered] Eins, zwei, drei... eins, zwei, drei... (One, two, three...) |
| `RCH_GRAB_01` | Long Reach Grab hits | Hab dich! (Got you!) |
| `RCH_REEL_01` | the drag | Komm her. Komm her. Komm her. (Come here. Come here. Come here.) |
| `RCH_HUG_01` | Hug-Crush | Halt still. Ganz still. (Hold still. Very still.) |
| `RCH_WALL_01` | Through-the-Wall, from below | [a knock under the floorboards] Hier unten... (Down here...) |
| `RCH_WINDOW_01` | Window Spider | Alle Fenster! Alle! (Every window! Every one!) |
| `RCH_REGROW_01` | an arm regrows | [a wet crack, then a sigh] ...nochmal. (...again.) |
| `RCH_SHELF_01` | idle reach-up | Nur noch ein bisschen höher... (Just a little bit higher...) |
| `RCH_ENRAGE_01` | a cousin dies | Du hast geschummelt! (You cheated!) |
| `RCH_DEATH_01` | death (reaching) | ...wartet auf mich. (...wait for me.) |
| `ALX_ARRIVE_01` | rising from the trapdoor | [a whisper] Ich hab sie noch. Ich halt sie noch. (I've still got them. I'm still holding on.) |
| `ALX_HOLD_01` | Holding Hand | Nicht loslassen. (Don't let go.) |
| `ALX_HOLD_02` | Holding Hand (variant) | Tante kommt gleich. Halt fest. (Auntie's coming soon. Hold tight.) |
| `ALX_UNSEEN_01` | a player turns away within 12 m | [right behind them] Hinter dir. (Behind you.) |
| `ALX_COUSIN_01` | holding a dead cousin's hand (named) | %DEAD_COUSIN_NAME%. Ich bin da. (I'm here.) |
| `ALX_COUSIN_TWIN_01` | the same (twin) | Ich bin da. Ich bin ja da. (I'm here. I'm right here.) |
| `ALX_ENRAGE_01` | rising enraged | Ihr habt sie losgelassen. (You let go of her.) |
| `ALX_DEATH_01` | death (the fist closing) | ...Tante? (...Auntie?) |

### 12.3 PAUL (`PAU`)

| Line id | Trigger | Line |
|---|---|---|
| `PAU_PA_01` | arrival, over the PA (channel PA) | WHERE'S MY SQUAD?! |
| `PAU_LAND_01` | the crater landing | [a roar with a man's voice inside it] |
| `PAU_CALM_01` | Calm, bark | Count off! ...COUNT OFF! |
| `PAU_CALM_02` | Calm, bark | Gimme your pack. I got it. I GOT it. |
| `PAU_CALM_03` | Calm, bark | Nobody gets left. Nobody. |
| `PAU_FLEE_01` | players fleeing (rage up) | DON'T YOU RUN! Nobody runs out on the squad! |
| `PAU_DOWN_01` | sees a player go down | MAN DOWN! ...MAN DOWN! ...medic... |
| `PAU_ANGRY_01` | becomes Angry | You're not my guys. YOU'RE NOT MY GUYS! |
| `PAU_BERSERK_01` | becomes BERSERK | [a roar, and inside it] WHERE ARE THEY?! |
| `PAU_GRAB_01` | Grab & Squeeze | GOT you. Who sent you? WHERE ARE THEY? |
| `PAU_THROW_01` | Zombie Throw / Rip & Throw | Heads UP! |
| `PAU_BOTTLE_01` | a bottle breaks | [a gasp] ...cold. That's cold. |
| `PAU_BOTTLE_02` | a bottle breaks (variant) | ...that's enough, doc. That's enough. |
| `PAU_CUP_01` | the tin-cup idle | [quietly, to the cup] ...coffee's on me, fellas. Whole pot. ...Fellas? |
| `PAU_KNEE_01` | knee-down stagger | Not yet. Not YET. |
| `PAU_LEAVE_01` | the 6:00 retreat | I'm coming, fellas! HOLD ON! |
| `PAU_LAST_DUT_01` | death, nearest player Dutch | ...Hey. Sarge. You found me. Tell the guys I carried my share. |
| `PAU_LAST_PEG_01` | death, Peg | ...Hey. Ma'am. You're English? Huh. You found me. Tell the guys I carried my share. |
| `PAU_LAST_DEA_01` | death, Deacon | ...Hey. Grease on your hands. Good man. You found me. Tell the guys I carried my share. |
| `PAU_LAST_WRN_01` | death, Wren | ...Hey. You're not one of them. You found me. Tell the guys I carried my share. |
| `PAU_LAST_BLT_01` | death, Bolt | ...Hey. Kid. Nice hammer. You found me. Tell the guys I carried my share. |
| `PAU_LAST_VEN_01` | death, Vendelin | ...Hey. Mister. You look like a man who keeps his word. You found me. Tell the guys I carried my share. |

### 12.4 THE SLENDER (`SLN`)

| Line id | Trigger | Line |
|---|---|---|
| `SLN_ARRIVE_01` | arrival, from the trees | [keys, then a calm voice] Evening. Don't mind me. I'm only on my rounds. |
| `SLN_TIER_LOW_01` | a player reaches LOW | [whisper] Noted. |
| `SLN_TIER_MED_01` | MEDIUM | [whisper] Observed. |
| `SLN_TIER_HIGH_01` | HIGH | [whisper] Logged. |
| `SLN_TIER_CRIT_01` | CRITICAL (he's behind you) | [right behind you, kindly] Quarantined. |
| `SLN_WRITE_01` | writing at HIGH (pen scratch) | [writing] ...three-twelve. Subject out after curfew. Noted. |
| `SLN_WRITE_02` | writing (variant) | [writing] ...stood very still. Thought I wouldn't see. |
| `SLN_MIRROR_01` | the first mirror stop | You stop, I stop. That's only manners. |
| `SLN_SWEEP_01` | Lantern Sweep | Let's have a look at you. |
| `SLN_ROOM_01` | Watch Room entry | Everyone has a page. Find yours. |
| `SLN_ROOM_02` | Watch Room, 12 s in | It's three o'clock. It's always three o'clock in here. |
| `SLN_ROOM_ESCAPE_01` | page torn out | ...Fair enough. You're excused. |
| `SLN_ROOM_FAIL_01` | the timer runs out | Noted. |
| `SLN_DECOY_01` | Shift Change | Change of shift. |
| `SLN_DECOY_SHOT_01` | a decoy is shot | Wrong lantern. Noted. |
| `SLN_DARK_01` | End of Shift | Lights out. Last round of the night. |
| `SLN_BOOK_01` | the book shot from his hands | [pages scattering] ...Ah. My book. One moment. |
| `SLN_LANTERN_01` | the lantern broken (stun) | ...Can't see. Can't see a thing. |
| `SLN_LEAVE_01` | the 8:00 retreat | Rounds aren't finished. I'll be back this way. |
| `SLN_DEATH_01` | death | ...Shift's over. Someone else has the watch now. |

### 12.5 The squad: Dutch, Peg, Deacon, Wren

| Line id | Trigger | Line |
|---|---|---|
| `DUT_COUSINS_01` | the lamps going out | Lamps are going. All of 'em. ...Somebody's turning 'em down. |
| `DUT_COUSINS_02` | the clapping upstairs | That's clapping. Upstairs. I don't like games I don't know the rules to. |
| `DUT_HAMMER_01` | the first Mallet Throw | Mallet! Heads down, it comes back! |
| `DUT_REACH_01` | the first Long Reach Grab | Her arms— how long are her ARMS? |
| `DUT_ALIX_01` | Alix rises | Girl's got a hand comin' out of her chest. And it's... waitin'. Like it wants me to take it. |
| `DUT_COUSINS_DEAD_01` | round cleared | They were just kids playin' a game. Somebody should've come back for 'em. |
| `DUT_LETTER_01` | reads the aunt's letter | She went up for her girl and told the others to keep playin'. ...Yeah. I'd have done the same. |
| `DUT_KINDERHAMMER_01` | picks up the Kinderhammer | Splittin' maul. Comes back when you throw it. My old man'd have sold his soul for one. |
| `PEG_COUSINS_01` | the lamps going out | The lamps are being put out. Methodically. One does hate a methodical enemy. |
| `PEG_COUSINS_02` | the clapping | Clapping. A children's game. ...Positions, everyone. Quietly. |
| `PEG_HAMMER_01` | the first Mallet Throw | She's thrown it, and it's coming back. Duck on the return, not the throw. |
| `PEG_REACH_01` | Window Spider | Mind the windows. All of them. She's at every window at once. |
| `PEG_ALIX_01` | Alix rises | Don't take her hand. Whatever it costs you, don't take her hand. |
| `PEG_COUSINS_DEAD_01` | round cleared | Three girls in a cellar, told to wait for someone who wasn't coming. I know a little about orders like that. |
| `PEG_LETTER_01` | reads the letter | "Keep playing, and stay quiet until I come back." ...She meant it kindly. They always mean it kindly. |
| `PEG_KINDERHAMMER_01` | picks it up | A splitting maul that comes back. I can think of three uses already. |
| `DEA_COUSINS_01` | the fire dies | Fire's out. Didn't burn down. Something just... told it to stop. |
| `DEA_COUSINS_02` | the clapping | Lord. That's a clapping game. Ruthie plays that on the porch. |
| `DEA_HAMMER_01` | the first Mallet Throw | That's a splitting maul. She's throwing it like it weighs nothing. |
| `DEA_REACH_01` | Through-the-Wall | Arms through the floorboards! Watch your feet! |
| `DEA_ALIX_01` | Alix rises | She's holding her hand out like she's waiting on somebody to take it. Lord, who's she waiting on? |
| `DEA_COUSINS_DEAD_01` | round cleared | Rest now, girls. Game's over. Somebody came. ...It was just us. |
| `DEA_LETTER_01` | reads the letter | Ruthie's twelve. ...I'm gonna go stand outside a minute. |
| `DEA_KINDERHAMMER_01` | picks it up | Good balance on this. Somebody took care of this tool. |
| `WRN_COUSINS_01` | the lamps going out | The lamps. One. Two. Three. Someone is counting them out. |
| `WRN_COUSINS_02` | the humming | A counting game. Every village has one. This one is wrong. |
| `WRN_HAMMER_01` | the first Mallet Throw | When the hammer is in the air, she has nothing. Shoot her then. |
| `WRN_REACH_01` | the first grab | The wrists. They glow. Shoot the wrists. |
| `WRN_ALIX_01` | Alix's first freeze | She only moves when we look away. So nobody looks away. |
| `WRN_COUSINS_DEAD_01` | round cleared | I will not write them in the book. They were not marks. |
| `WRN_LETTER_01` | reads the letter | She went to get her daughter. That is all. That is the whole story. |
| `WRN_KINDERHAMMER_01` | picks it up | Heavy. Good. It comes back, which is more than most things here. |
| `DUT_PAUL_01` | the PA roar | That's an American voice on the PA. ...That's an American VOICE. |
| `DUT_PAUL_02` | first sight | Big fella's wearing dog tags. Ours. Aw, hell. |
| `DUT_PAUL_RAGE_01` | his first Angry | The bottles on his back! Shoot the bottles, calm him down! |
| `DUT_PAUL_DEAD_01` | after the fall (tier 2) | Every unit's got one. The big one. The one who carries you. |
| `DUT_PAUL_CUP_01` | Dutch receives the cup | [turning it over] ...I'll buy the round, Paul. I'll buy every round. |
| `PEG_PAUL_01` | first sight | American. A private, engineers, what's left of the sleeve says so. They did this to one of ours. |
| `PEG_PAUL_02` | his first Angry | The bottles on his back are feeding him. Break them and he cools. |
| `PEG_PAUL_DEAD_01` | after the fall (tier 2) | Note it. Private Paul. Carried his share. ...Somebody in London ought to read that. |
| `PEG_PAUL_DEAD_NAMED_01` | the same, when `[PAUL_LASTNAME]` is filled | Note it. Private Paul %PAUL_LASTNAME%. Carried his share. ...Somebody in London ought to read that. |
| `PEG_PAUL_CUP_01` | Peg receives the cup | [quietly] I'll see it gets home, Private. You have my word. |
| `DEA_PAUL_01` | first sight | That's a soldier. That's a GI. Lord have mercy, what'd they pump into him? |
| `DEA_PAUL_02` | Calm, after a bottle breaks | Easy, big man. Easy. Nobody's leaving you. |
| `DEA_PAUL_PRAYER_01` | after the fall: the unique kneel (tier 2) | Lord, this man carried his brothers when they couldn't carry themselves. Carry him now. He's done his share. Amen. |
| `DEA_PAUL_CUP_01` | Deacon receives the cup | [softly] I'll keep it shined for you. |
| `WRN_PAUL_01` | first sight | They dosed him to see when he would die. He would not die. ...I know this file. I know this kind of file. |
| `WRN_PAUL_02` | his first turn away | The back of his neck, when he turns. The line goes in there. |
| `WRN_PAUL_NAME_01` | after the fall: writes in her notebook (tier 2) | [writing] Paul. ...Not a mark. A name. |
| `WRN_PAUL_CUP_01` | Wren receives the cup | [quiet] I will carry it. He carried enough. |
| `DUT_SLENDER_01` | first sight | Tall fella with a lantern. Just watching. I hate the ones that just watch. |
| `DUT_SLENDER_02` | Dutch at HIGH | He's writing. He's writing about ME. |
| `DUT_QUARANTINE_01` | returned from the Watch Room | Room full of books and a clock that don't move. I'm never goin' in a library again. |
| `DUT_SLENDER_DEAD_01` | his death | ...Shift's over, pal. Get some sleep. |
| `PEG_SLENDER_01` | his first smoke-hit in darkness | He only bleeds in the light. Bring him to the floodlights. Politely. |
| `PEG_SLENDER_02` | Shift Change | Three of him. Watch the lanterns. The steady one's real. |
| `PEG_QUARANTINE_01` | returned | A clerk's office with no clerk. I've been interrogated in worse. |
| `PEG_SLENDER_DEAD_01` | his death | A man who kept his post when everyone else ran. I've known worse men in better uniforms. |
| `DEA_SLENDER_01` | first sight | He's just doing his rounds. Lord, he's been doing his rounds this whole time. |
| `DEA_SLENDER_02` | his keys fall silent near Deacon | Keys went quiet— MOVE! |
| `DEA_QUARANTINE_01` | returned | Clock stopped at three. Mama always said nothing good happens after three. |
| `DEA_SLENDER_DEAD_01` | his death | Rest easy, watchman. We'll keep the lights on. |
| `WRN_SLENDER_01` | the first mirror stop | He stops when I stop. He turns when I turn. ...Good. I can count on him. |
| `WRN_SLENDER_02` | his book appears | The book! Shoot the book out of his hands! |
| `WRN_QUARANTINE_01` | returned | My page was neat. He has better handwriting than me. |
| `WRN_SLENDER_DEAD_01` | his death | He wrote everything down. Every hour. ...I understand him. |

### 12.6 Bolt (with Sprocket) and Vendelin

| Line id | Trigger | Line |
|---|---|---|
| `BLT_COUSINS_01` | the lamps going out | Okay. Okay. Lights going out one at a time is a BAD sign where I'm from too. |
| `SPR_COUSINS_01` | the clapping | Bolt, my sensors say three heartbeats. Then zero. Then three again. I'd like to stop sensing now. |
| `BLT_HAMMER_01` | the first Mallet Throw | Is she— that's a mallet throw. She's doing the throw! |
| `BLT_ALIX_01` | Alix rises | Nope. Nope. Sprocket, don't look at it. Wait. DO look at it. Keep looking at it! |
| `BLT_COUSINS_DEAD_01` | round cleared | ...Sprocket, don't make a joke. Not this time. |
| `SPR_COUSINS_DEAD_01` | round cleared (after Bolt's) | [quietly] No joke. Filing it under lullabies. |
| `BLT_KINDERHAMMER_01` | picks up the Kinderhammer | ...Oh, that's mine. Kind of. |
| `BLT_PAUL_01` | first sight | Okay, he's huge, he's angry, and I think he's on our side? Somewhere in there? |
| `SPR_PAUL_01` | his first bottle breaks | His vitals are mostly stout, Bolt. That is not a figure of speech. |
| `BLT_PAUL_DEAD_01` | after the fall | He was looking for his friends the whole time. ...Sprocket, we're telling everybody about this guy. |
| `BLT_PAUL_CUP_01` | Bolt receives the cup | I'll put it on the shelf in the garage. Front and center. Nobody touches it. |
| `BLT_SLENDER_01` | first sight | Tall guy, lantern, keys, just WATCHING? Sprocket, is that a security guard? That's a security guard. |
| `SPR_SLENDER_01` | Bolt at MEDIUM | He's logging us, Bolt. I've been logged before. I did not enjoy the terms. |
| `BLT_QUARANTINE_01` | returned | There was a clock, and a desk, and a guy, and I had to tear out a PAGE, Sprocket— |
| `BLT_SLENDER_DEAD_01` | his death | Night shift's the worst shift. ...Thanks for watching the place, man. |
| `VEN_COUSINS_01` | the lamps going out | I sat up one night by that stove. I never heard anyone under the floor. I should have listened better. |
| `VEN_ALIX_01` | Alix rises | That arm is not a weapon. It is a hand. Someone should take it. ...Not you. Please, not you. |
| `VEN_COUSINS_DEAD_01` | round cleared | "Retained." That is the word they would use. I have a better one: waiting. |
| `VEN_KINDERHAMMER_01` | picks it up | A splitting maul from the woodpile. Well kept. She kept it well. |
| `VEN_PAUL_01` | first sight | That rack. Those are my bottles. Those are MY bottles in his back. |
| `VEN_PAUL_DEAD_01` | after the fall | Ironhide was made so the boys would not go first. He went first for all of them. ...I am so sorry, Private. |
| `VEN_PAUL_CUP_01` | Vendelin receives the cup | [very carefully] I will not refill it. I will keep it exactly as he left it. |
| `VEN_SLENDER_01` | first sight | A watchman who never sleeps and writes everything down. They would have offered him a position. |
| `VEN_QUARANTINE_01` | returned | A room where it is always three in the morning. I have worked in that room. |
| `VEN_SLENDER_DEAD_01` | his death | He kept watch because he wanted to, not because anyone made him. That is the difference, and it is everything. |

**Counts:** Operator 21; the Cousins 35; Paul 22; the Slender 20; the squad 66; Bolt, Sprocket and Vendelin 25. **189 lines.** The Watch-Book templates are Archive text, not VO.


## 13. AI teammate barks, orders and bonus perks (Update 02 §5, DECISIONS T-050)

Spoken by the squad when they are bots (BotSquad.callout, positional at the bot, rate-limited per bot and for the
squad: data/gravelight/bots.json `callouts`). The same character voices as §8 / CHARACTERS.md. Categories:
`RELOAD` (a bot reloads a long gun with zombies near), `BOARD` (it finished a window), `REVIVE` (it starts a
revive; these join the §8 REVIVE lines), `POWERUP_SEEN` (a drop it can see), `CMD_FOLLOW` / `CMD_HOLD` /
`CMD_REPAIR` / `CMD_REVIVE` (the nearest bot acknowledges an order from the command wheel), and `BONUS_<perk>`:
the bot's random bonus perk, said once, the first time it matters (bots.json `bonus_perk.triggers`: Trigger Tonic
on the first reload, Twin Barrel on the first burst, Marathon Malt on the first sprint, Hawkeye on the first
headshot kill, Packmule on the first weapon swap, Blastproof at the first explosion, Overclock at the first burst,
Ironhide when first hurt, Second Wind on the first revive; otherwise at the start of round 4).

### 13.1 Dutch (`DUT`)
- `DUT_RELOAD_01`: "Reloading!"
- `DUT_RELOAD_02`: "Changing mags, cover me!"
- `DUT_BOARD_01`: "Board's up!"
- `DUT_BOARD_02`: "Window's shut. For now."
- `DUT_REVIVE_10`: "I've got you, hold on!"
- `DUT_POWERUP_SEEN_01`: "Something shiny over there. Grab it."
- `DUT_CMD_FOLLOW_01`: "Right behind you."
- `DUT_CMD_HOLD_01`: "Holding here. Nobody gets past."
- `DUT_CMD_REPAIR_01`: "Hammer time. I'll do the windows."
- `DUT_CMD_REVIVE_01`: "Anybody drops, I'm on 'em."
- `DUT_BONUS_IRONHIDE_01`: "That stout's still in my blood. I can take a hit."
- `DUT_BONUS_SECONDWIND_01`: "Schnapps in me already. Up you get, quick as you like."
- `DUT_BONUS_TRIGGER_01`: "Hands are fast tonight. Must be the tonic in my canteen."
- `DUT_BONUS_TWINBARREL_01`: "This thing's spitting faster than it should. I'm not complaining."
- `DUT_BONUS_MARATHON_01`: "Legs feel twenty again. Twenty and stupid."
- `DUT_BONUS_HAWKEYE_01`: "Brandy steadies the eye. Ma always said so. She meant something else."
- `DUT_BONUS_PACKMULE_01`: "Three guns. Like carrying the whole mill on my back."
- `DUT_BONUS_BLASTPROOF_01`: "That should've hurt. The bock says no."
- `DUT_BONUS_OVERCLOCK_01`: "My gun just bit them. I didn't tell it to."

### 13.2 Peg (`PEG`)
- `PEG_RELOAD_01`: "Reloading!"
- `PEG_RELOAD_02`: "Magazine, one moment."
- `PEG_BOARD_01`: "Board's up!"
- `PEG_BOARD_02`: "That window is closed for business."
- `PEG_REVIVE_10`: "I've got you, hold on. Eyes on me."
- `PEG_POWERUP_SEEN_01`: "Something's dropped. Do pick it up before it sulks off."
- `PEG_CMD_FOLLOW_01`: "Lead on."
- `PEG_CMD_HOLD_01`: "We hold. Understood."
- `PEG_CMD_REPAIR_01`: "Windows. Right. I'll see to them."
- `PEG_CMD_REVIVE_01`: "Nobody stays down. That's an order, even to me."
- `PEG_BONUS_IRONHIDE_01`: "I had a stout before we set out. Medicinal. It's holding up rather well."
- `PEG_BONUS_SECONDWIND_01`: "The schnapps is still with me. I'll have you up in a jiffy."
- `PEG_BONUS_TRIGGER_01`: "One does reload faster with a tonic. Noted for the report."
- `PEG_BONUS_TWINBARREL_01`: "Goodness. This rate of fire is frankly indecent."
- `PEG_BONUS_MARATHON_01`: "I could run to Calais. Please don't make me."
- `PEG_BONUS_HAWKEYE_01`: "The brandy's done wonders for my aim. And my mood."
- `PEG_BONUS_PACKMULE_01`: "Three weapons. Ungainly, but thorough."
- `PEG_BONUS_BLASTPROOF_01`: "Bang. Nothing. Splendid. Remind me to thank the brewer."
- `PEG_BONUS_OVERCLOCK_01`: "My rifle just electrocuted someone. How very modern."

### 13.3 Deacon (`DEA`)
- `DEA_RELOAD_01`: "Reloading!"
- `DEA_RELOAD_02`: "Feeding her. Give me a second."
- `DEA_BOARD_01`: "Board's up!"
- `DEA_BOARD_02`: "Window's fixed. Good as new. Well. Good."
- `DEA_REVIVE_10`: "I've got you, hold on. Breathe with me."
- `DEA_POWERUP_SEEN_01`: "Blessing on the floor over there. Don't let it go to waste."
- `DEA_CMD_FOLLOW_01`: "With you."
- `DEA_CMD_HOLD_01`: "Planting my feet. They come to us."
- `DEA_CMD_REPAIR_01`: "Repairs. Now you're speaking my language."
- `DEA_CMD_REVIVE_01`: "Anybody falls, I'm the one picking them up."
- `DEA_BONUS_IRONHIDE_01`: "Stout's still in me. I'm built like a Sherman today."
- `DEA_BONUS_SECONDWIND_01`: "Schnapps working. I'll have you back on your feet before the Lord notices."
- `DEA_BONUS_TRIGGER_01`: "Hands are quicker than they ought to be. I'll take it."
- `DEA_BONUS_TWINBARREL_01`: "Timing's advanced on this gun. Runs hot. Runs good."
- `DEA_BONUS_MARATHON_01`: "Engine's tuned. I could run all night."
- `DEA_BONUS_HAWKEYE_01`: "Eyes are clear as Sunday morning."
- `DEA_BONUS_PACKMULE_01`: "Room for one more tool on the belt. Always is."
- `DEA_BONUS_BLASTPROOF_01`: "Blast washed right over me. Armor plating, the bottle said."
- `DEA_BONUS_OVERCLOCK_01`: "Something in this gun's wired wrong. Wired wrong the right way."

### 13.4 Wren (`WRN`)
- `WRN_RELOAD_01`: "Reloading!"
- `WRN_RELOAD_02`: "Empty. One moment."
- `WRN_BOARD_01`: "Board's up!"
- `WRN_BOARD_02`: "Window closed."
- `WRN_REVIVE_10`: "I've got you. Hold on. Hold on."
- `WRN_POWERUP_SEEN_01`: "There. Something fell. Take it."
- `WRN_CMD_FOLLOW_01`: "I follow."
- `WRN_CMD_HOLD_01`: "I hold. They come, I count them."
- `WRN_CMD_REPAIR_01`: "Boards. Yes."
- `WRN_CMD_REVIVE_01`: "Nobody stays on the floor. Not here."
- `WRN_BONUS_IRONHIDE_01`: "The stout is still in me. Hit me. They will see."
- `WRN_BONUS_SECONDWIND_01`: "Schnapps. Quick hands for lifting. Good."
- `WRN_BONUS_TRIGGER_01`: "Reload, fast. The tonic is still in my fingers."
- `WRN_BONUS_TWINBARREL_01`: "Faster. The gun is hungry tonight."
- `WRN_BONUS_MARATHON_01`: "I can run forever. I ran here from Kraków, almost."
- `WRN_BONUS_HAWKEYE_01`: "The brandy. My eye is clear. Into the book."
- `WRN_BONUS_PACKMULE_01`: "Three guns. More marks in the notebook."
- `WRN_BONUS_BLASTPROOF_01`: "Fire, and I am still here. Good beer."
- `WRN_BONUS_OVERCLOCK_01`: "Lightning from my rifle. I will not write how."

**Counts:** 4 × (2 RELOAD + 2 BOARD + 1 REVIVE + 1 POWERUP_SEEN + 4 CMD + 9 BONUS) = **76 lines.**

## 14. Map 0's living world: the squad's reactions (Update 02 §7, DECISIONS T-052)

Played by `MapAmbience` (`gravelight/world/landscape/map_ambience.gd`, data `data/gravelight/map00_ambience.json`), local
VO (each co-op peer's sky is its own). Tier 2 squad lines (rules.json player_category_priority: they queue behind a story line
instead of being dropped), chance 100%, once per event.

**`SKY_PLANE_DOWN`**: once per match from round 6, a plane is hit over the inn and goes down trailing smoke behind the
hills (it mirrors GRAVELIGHT ONE's own fall). One random standing survivor.

- `DUT_SKY_PLANE_DOWN_01`: "One's hit. He's going down behind the hills. ...Come on, pull up. Pull up."
- `DUT_SKY_PLANE_DOWN_02`: "There goes another one. Hope somebody finds them quicker than anybody found us."
- `PEG_SKY_PLANE_DOWN_01`: "One of ours is burning. ...Count the chutes. Come on. Count the chutes."
- `PEG_SKY_PLANE_DOWN_02`: "Down behind the ridge. I'd tell you they'll be fine. I'd be lying."
- `DEA_SKY_PLANE_DOWN_01`: "Engine's on fire. Lord, let that pilot glide it in like ours did."
- `DEA_SKY_PLANE_DOWN_02`: "That's ten men in that thing. ...Somebody say a word for them."
- `WRN_SKY_PLANE_DOWN_01`: "Burning, losing height, same bearing we came in on. I'm writing down the time."
- `WRN_SKY_PLANE_DOWN_02`: "No violet light this time. Only flak. ...That is almost a comfort."

**`WRECK_PILOT`**: the first time a survivor gets a clear look at GRAVELIGHT ONE's open cockpit (within ~27 m, looking at
it). Dutch says it if he is in the match; otherwise whoever is. The pilots died in the crash (LORE.md §9.2); the seat is
empty. **[OPEN]**: where Flight Lieutenant Selwyn went is not answered on Map 0.

- `DUT_WRECK_PILOT_01`: "Pilot's seat's empty. Selwyn was in that seat. I checked him for a pulse myself. ...So who unbuckled him?"
- `PEG_WRECK_PILOT_01`: "The pilot's seat is empty. Dutch swore Selwyn was dead in it, and Dutch doesn't get that sort of thing wrong."
- `DEA_WRECK_PILOT_01`: "Straps on the pilot's seat are open. Not torn. Unbuckled. Selwyn didn't walk out of there on his own."
- `WRN_WRECK_PILOT_01`: "The pilot's seat. Empty. No tracks in the snow around the nose. Write that down. ...I am writing that down."

**`MIDNIGHT`**: the church on the far hill rings twelve during round 9: it is the twenty-fourth, Christmas Eve (Wigilia).

- `DUT_MIDNIGHT_01`: "Midnight. Christmas Eve. Babcia'd be setting an extra plate about now. For the stranger who knocks."
- `PEG_MIDNIGHT_01`: "Midnight. Happy Christmas Eve, everyone. Do try not to die on it."
- `DEA_MIDNIGHT_01`: "Christmas Eve. Ruthie's asleep by now. ...Good. That's good."
- `WRN_MIDNIGHT_01`: "Twelve. It's the twenty-fourth. Wigilia. Somewhere my mother is looking at the first star."


## 15. AI teammate callouts, orders and chatter (Update 03 §5, DECISIONS T-055)

Spoken by the squad when they are bots (BotSquad.callout, positional at the bot, rate-limited per bot and for the
squad: data/gravelight/bots.json `callouts`). Most callouts also flash a small world-space ping at the spot
(BotPings), labelled with the game's own names. Categories: `SPRINTER_BEHIND` (a sprinter close behind a teammate,
coming for them), `BOSS_INCOMING` (a boss spawns; Peg calls bosses first), `CRATE_MOVED`, `WINDOW_OPEN` (a window
with no boards, zombies climbing, nobody fixing it), `COVER` (covering a revive), `PING_<power-up>` (a dropped
power-up by its name: Resupply, Death's Door, Double Scrip, Blackout, Fortify, Clearance; falls back to
`POWERUP_SEEN`), `CMD_TRAIN` / `CMD_BUY_PERKS` / `CMD_SAVE_SCRIP` / `CMD_OPEN_DOOR` / `CMD_FETCH_PART` (the command
wheel's new orders, acknowledged by the nearest bot), `GRUMBLE` (Dutch, sometimes, when told to move), `TALLY_<n>`
(Wren's running kill tally at 25, 50, 100, 150, 200 and 300 kills) and `CHATTER` (between waves, now and then).
The ids carry `SQ3` so the voice bake can run them alone (`python gravelight/tools_src/gen_vo.py --only=DUT_SQ3`).

### 15.1 Dutch (`DUT`)
- `DUT_SQ3_SPRINTER_BEHIND_01`: "Runner on your back! Move!"
- `DUT_SQ3_SPRINTER_BEHIND_02`: "Behind you! Fast one!"
- `DUT_SQ3_BOSS_INCOMING_01`: "Big one coming. Get ready."
- `DUT_SQ3_CRATE_MOVED_01`: "Crate's moved. Somebody find it."
- `DUT_SQ3_WINDOW_OPEN_01`: "Window's wide open over here!"
- `DUT_SQ3_COVER_01`: "I got your back. Get 'em up."
- `DUT_SQ3_PING_RESUPPLY_01`: "Resupply! Over here!"
- `DUT_SQ3_PING_DEATHSDOOR_01`: "Death's Door, right there. Your call."
- `DUT_SQ3_PING_DOUBLESCRIP_01`: "Double Scrip on the floor!"
- `DUT_SQ3_PING_BLACKOUT_01`: "Blackout! Grab it when you want it."
- `DUT_SQ3_PING_FORTIFY_01`: "Fortify, over here!"
- `DUT_SQ3_PING_CLEARANCE_01`: "Clearance! Cheap crate, folks."
- `DUT_SQ3_CMD_TRAIN_01`: "Right with you. Keep 'em moving."
- `DUT_SQ3_CMD_BUY_PERKS_01`: "Drinks are on me. Well. On me."
- `DUT_SQ3_CMD_SAVE_SCRIP_01`: "Wallet's shut."
- `DUT_SQ3_CMD_OPEN_DOOR_01`: "I'll get the door."
- `DUT_SQ3_CMD_FETCH_PART_01`: "I'll go grab it."
- `DUT_SQ3_GRUMBLE_01`: "Fine. Moving. Again."
- `DUT_SQ3_GRUMBLE_02`: "Had a good spot, too."
- `DUT_SQ3_CHATTER_01`: "My knees are older than this inn."
- `DUT_SQ3_CHATTER_02`: "Back home the worst thing in the dark was a coyote."

### 15.2 Peg (`PEG`)
- `PEG_SQ3_SPRINTER_BEHIND_01`: "Sprinter, behind you!"
- `PEG_SQ3_SPRINTER_BEHIND_02`: "Check your six, it's a quick one!"
- `PEG_SQ3_BOSS_INCOMING_01`: "Boss incoming. Spread out, don't bunch up."
- `PEG_SQ3_CRATE_MOVED_01`: "The crate's moved. Of course it has."
- `PEG_SQ3_WINDOW_OPEN_01`: "Window's open! Someone board it!"
- `PEG_SQ3_COVER_01`: "Covering you. Go."
- `PEG_SQ3_PING_RESUPPLY_01`: "Resupply, over here!"
- `PEG_SQ3_PING_DEATHSDOOR_01`: "Death's Door. Do try not to waste it."
- `PEG_SQ3_PING_DOUBLESCRIP_01`: "Double Scrip. Spend it wisely."
- `PEG_SQ3_PING_BLACKOUT_01`: "A Blackout's dropped, here."
- `PEG_SQ3_PING_FORTIFY_01`: "Fortify! The windows will thank us."
- `PEG_SQ3_PING_CLEARANCE_01`: "Clearance! The crate's a bargain."
- `PEG_SQ3_CMD_TRAIN_01`: "Train them. Yes, I know the drill."
- `PEG_SQ3_CMD_BUY_PERKS_01`: "A drink for the road. Several, in fact."
- `PEG_SQ3_CMD_SAVE_SCRIP_01`: "Saving. Frugality is a virtue."
- `PEG_SQ3_CMD_OPEN_DOOR_01`: "That door? Consider it opened."
- `PEG_SQ3_CMD_FETCH_PART_01`: "I'll fetch it. Mind the shop."
- `PEG_SQ3_CHATTER_01`: "If anyone at Bletchley asks, this was a quiet posting."
- `PEG_SQ3_CHATTER_02`: "Two minutes. Check your ammunition, not your watch."

### 15.3 Deacon (`DEA`)
- `DEA_SQ3_SPRINTER_BEHIND_01`: "Fast one behind you, brother!"
- `DEA_SQ3_BOSS_INCOMING_01`: "Lord, here comes a big one."
- `DEA_SQ3_CRATE_MOVED_01`: "Crate's gone and moved itself."
- `DEA_SQ3_WINDOW_OPEN_01`: "That window's open! Somebody get a board on it!"
- `DEA_SQ3_COVER_01`: "Go on, get 'em up. I'm watching."
- `DEA_SQ3_PING_RESUPPLY_01`: "Resupply over here! Blessing on the floor."
- `DEA_SQ3_PING_DEATHSDOOR_01`: "Death's Door, right here."
- `DEA_SQ3_PING_DOUBLESCRIP_01`: "Double Scrip! Make it count."
- `DEA_SQ3_PING_BLACKOUT_01`: "Blackout on the floor."
- `DEA_SQ3_PING_FORTIFY_01`: "Fortify! Every board at once. My kind of miracle."
- `DEA_SQ3_PING_CLEARANCE_01`: "Clearance! Crate's half off."
- `DEA_SQ3_CMD_TRAIN_01`: "Keep 'em on a string. I'm with you."
- `DEA_SQ3_CMD_BUY_PERKS_01`: "Machines take Scrip, and I've got Scrip."
- `DEA_SQ3_CMD_SAVE_SCRIP_01`: "I'll hold onto it."
- `DEA_SQ3_CMD_OPEN_DOOR_01`: "I'll open her up."
- `DEA_SQ3_CMD_FETCH_PART_01`: "Parts? Now you're talking."
- `DEA_SQ3_CHATTER_01`: "This machine's got a rattle. Hush now, sweetheart."
- `DEA_SQ3_CHATTER_02`: "Pass me the wrench when we're done. Something in there's loose."

### 15.4 Wren (`WRN`)
- `WRN_SQ3_SPRINTER_BEHIND_01`: "Behind you. Fast."
- `WRN_SQ3_BOSS_INCOMING_01`: "Big one. Coming now."
- `WRN_SQ3_CRATE_MOVED_01`: "Crate moved."
- `WRN_SQ3_WINDOW_OPEN_01`: "Window. Open. There."
- `WRN_SQ3_COVER_01`: "Go. I watch."
- `WRN_SQ3_PING_RESUPPLY_01`: "Resupply. Here."
- `WRN_SQ3_PING_DEATHSDOOR_01`: "Death's Door. Here."
- `WRN_SQ3_PING_DOUBLESCRIP_01`: "Double Scrip. Here."
- `WRN_SQ3_PING_BLACKOUT_01`: "Blackout. Here."
- `WRN_SQ3_PING_FORTIFY_01`: "Fortify. Here."
- `WRN_SQ3_PING_CLEARANCE_01`: "Clearance. The crate is cheap."
- `WRN_SQ3_CMD_TRAIN_01`: "Yes. We run them."
- `WRN_SQ3_CMD_BUY_PERKS_01`: "I drink. Fine."
- `WRN_SQ3_CMD_SAVE_SCRIP_01`: "I save."
- `WRN_SQ3_CMD_OPEN_DOOR_01`: "The door. Yes."
- `WRN_SQ3_CMD_FETCH_PART_01`: "I bring it."
- `WRN_SQ3_TALLY_25_01`: "Twenty-five."
- `WRN_SQ3_TALLY_50_01`: "Fifty. I am counting."
- `WRN_SQ3_TALLY_100_01`: "One hundred. I write it down."
- `WRN_SQ3_TALLY_150_01`: "One hundred fifty."
- `WRN_SQ3_TALLY_200_01`: "Two hundred. For my brother."
- `WRN_SQ3_TALLY_300_01`: "Three hundred. Still counting."
- `WRN_SQ3_CHATTER_01`: "I write down their number. Someone should."
- `WRN_SQ3_CHATTER_02`: "My brother would like this inn. He liked any place with a fire."


## 16. Jakub Ostrowski (`JAK`), the prisoner companion (Update 02 §6.2, DECISIONS T-051)

A Polish miner from Wilcza Góra, 43, who walked out of Kaltenbrunn on 21 December 1944 and was locked in the
Crossroads Inn's coal cage by a fleeing patrol (CANON §6.4, CHARACTERS.md "Jakub Ostrowski"). Calm, wry, polite.
He has seen worse than zombies and isn't impressed by them. He is a person and a hero: never a joke, never a zombie.

**Voice:** the offline TTS bake (`gen_vo.py` profile `JAK`): Microsoft Mark, slower and lower than Deacon, a
smaller "size" shift and a dry, close, slightly rough chain (`jakub`), so he never sounds like Dutch (David) or
Deacon (Mark, warm room). **Polish** is written as it is said, with the English in parentheses right after it
(subtitles show both; the bake drops the parentheses). The bake reads a phonetic respelling where a tail gives
one: `` `[say: "..."]` `` (extract_vo.py stores it as the line's `tts`).

**Where he speaks:** positional at his body, on his own channel (`VOManager.GROUP_COMPANION`, `rules.json
companion_speakers`), so his lines never wait behind the squad's chatter and come out where they belong (a stale one
expires after 4 s instead of playing late); that includes his calls from the cage before he joins (the `companions`
group). His squad callouts come through `BotSquad.callout` (§13, §15 categories) with his own lines; the Wren scene and
his banter are `BNT_*` exchanges on the squad's player channel. The other survivors' lines about him are at the end.

### 16.1 Map 0: the cage, the breakout, the choice

**`CAGE_HELLO`** (the first time a survivor comes within 6 m of the cage, before round 5):
- `JAK_CAGE_HELLO_01`: "Szczęść Boże (God grant you luck). Forgive me if I don't get up. The door is not my idea." `[say: "Shchench Bozheh. Forgive me if I don't get up. The door is not my idea."]`
- `JAK_CAGE_HELLO_02`: "Ah. Not one of them. Good evening. I am Jakub. I would shake your hand, but the patrol kept the key."

**`CAGE_TALK`** ("Talk to Jakub" through the bars):
- `JAK_CAGE_TALK_01`: "The patrol locked me in and ran. They said the dead were walking. I said, then let me walk too. They did not laugh."
- `JAK_CAGE_TALK_02`: "The hinge is old. Something will break it sooner or later. I pray it is not something hungry."
- `JAK_CAGE_TALK_03`: "No, no. Don't waste your bullets on the lock. Keep them for the ones upstairs."
- `JAK_CAGE_TALK_04`: "Two days ago I was in Kaltenbrunn. Now I am in a coal cage at a crossroads. This is what they call progress."

**`ALARM`** (round 5: something tears at the coal-chute window):
- `JAK_ALARM_01`: "Kto tam? (Who's there?) ...Jezus Maria (Jesus, Mary)." `[say: "Kto tahm? ... Yezoos Maria."]`
- `JAK_ALARM_02`: "Boże (God). It is coming down the coal chute." `[say: "Bozheh. It is coming down the coal chute."]`

**`BREAKOUT`** (the zombie bursts the cage hinge; he grabs the coal shovel; shouted, heard through the floor):
- `JAK_BREAKOUT_01`: "Precz! Precz ode mnie! (Get away! Get away from me!) Chodź tu, ty draniu! (Come here, you swine!)" `[say: "Prech! Prech odeh mnyeh! Hoach too, tih drahnyoo!"]`
- `JAK_BREAKOUT_02`: "Jezus Maria! (Jesus, Mary!) The hinge! It has taken the hinge!" `[say: "Yezoos Maria! The hinge! It has taken the hinge!"]`
- `JAK_BREAKOUT_03`: "Psiakrew! (Dog's blood!) Na dole! Tutaj, na dole! (Downstairs! Here, down here!)" `[say: "Pshahkref! Nah doleh! Tootie, nah doleh!"]`

**`BREAKOUT_SELF`** (the zombie fell before it reached him; he shoulders the loose hinge himself):
- `JAK_BREAKOUT_SELF_01`: "The hinge was half off already. One good shove. Dzięki Bogu (thank God)." `[say: "The hinge was half off already. One good shove. Jenkee Bogoo."]`

**`FIGHT_KILL`** (the shovel comes down for the last time):
- `JAK_FIGHT_KILL_01`: "Spokojnie (easy). ...Stay down. Stay down this time." `[say: "Spokoynyeh. Stay down. Stay down this time."]`
- `JAK_FIGHT_KILL_02`: "Twenty years of coal. A shovel knows what to do."

**`FREED`** (he steps out and waits by the cage):
- `JAK_FREED_01`: "Dzięki Bogu (thank God). Whoever is up there, come down. I will not bite. That one tried." `[say: "Jenkee Bogoo. Whoever is up there, come down. I will not bite. That one tried."]`
- `JAK_FREED_02`: "I am out. And now I stand by the cage like a fool, waiting to be told where to go. Habit."

**`CALL`** (while he waits and nobody is near; every 16 s; positional, so the voice comes up through the floor):
- `JAK_CALL_01`: "Halo! Jest tu kto? (Hello! Is anyone here?) I am down in the cellar!" `[say: "Hahlo! Yest too kto? I am down in the cellar!"]`
- `JAK_CALL_02`: "Hej! Na dole! (Hey! Downstairs!) There is a man down here, and he has a shovel!" `[say: "Hey! Nah doleh! There is a man down here, and he has a shovel!"]`
- `JAK_CALL_03`: "Is anyone still alive up there? Jest tam kto? (Is anyone there?)" `[say: "Is anyone still alive up there? Yest tahm kto?"]`
- `JAK_CALL_04`: "I can hear you shooting. Good. When you are finished, the cellar door. Please."

**`TALK_ASK`** ("Talk to Jakub" once he is out: the choice card opens):
- `JAK_TALK_ASK_01`: "You came down. Thank you. Now a question: do I come with you as a man with a gun, or a man with a shovel?"
- `JAK_TALK_ASK_02`: "I can carry a rifle. I carried worse for two years. Or I carry this shovel and keep out of your way. You decide."

**`JOIN_UNARMED`** (NOT YET):
- `JAK_JOIN_UNARMED_01`: "Not yet. I understand. A stranger from a cage. I would not give me a gun either. I walk behind you."
- `JAK_JOIN_UNARMED_02`: "The shovel, then. I will mend your windows and keep my eyes open. When you trust me, you will tell me."

**`GUN_*`** (GIVE HIM A GUN, or a wall-buy bought for him; by the gun's class):
- `JAK_GUN_BOLT_01`: "A bolt-action. Good. We had these in thirty-nine. You count every shot. That is how a poor man shoots."
- `JAK_GUN_BOLT_02`: "Five rounds and a bolt. Now we speak the same language."
- `JAK_GUN_RIFLE_01`: "A rifle. Thank you. I will try to give it back with a better story than it has now."
- `JAK_GUN_AUTO_01`: "Bolt-actions, please. I don't trust things that fire by themselves."
- `JAK_GUN_AUTO_02`: "This one shoots like it is late for something. ...I will hold it. I won't love it."
- `JAK_GUN_PISTOL_01`: "A pistol. Well. In the mine they gave us less."
- `JAK_GUN_SHOTGUN_01`: "For close work. Down here everything is close work."
- `JAK_GUN_OTHER_01`: "I don't know this one. It will learn me, or I will learn it."
- `JAK_GUN_SWAP_01`: "Take mine, then. A fair trade. It is still warm."

**`PERK_REFUSE`** (he never drinks a perk: the first time he stands by a machine, or when a survivor drinks one near him):
- `JAK_PERK_REFUSE_01`: "I've seen what they put in those."
- `JAK_PERK_REFUSE_02`: "No, thank you. I carried the crates for those machines at Kaltenbrunn. I know what comes out of that mountain."
- `JAK_PERK_REFUSE_03`: "Drink if you must. I have seen men drink that and keep walking after they should have stopped."

**`COUSINS`** / **`COUSINS_AFTER`** (round 10, the Cousins Round; the rhyme the three of them hum):
- `JAK_COUSINS_01`: "I know that song. Everyone in this valley knows that song."
- `JAK_COUSINS_02`: "That rhyme. The children clap it in every schoolyard here. It counts down. ...It was never supposed to count down to anything."
- `JAK_COUSINS_AFTER_01`: "Lene Vogt's nieces. They came every summer when they were small and clapped that rhyme on the steps. I sold their aunt coal. ...Lord, have mercy on them."

**`MIDNIGHT`** (round 9: the far church rings twelve; Christmas Eve):
- `JAK_MIDNIGHT_01`: "Wigilia (Christmas Eve). My Marta will have set an extra plate, for the stranger at the door. She has set it every year since they took me." `[say: "Vigeelya. My Marta will have set an extra plate, for the stranger at the door. She has set it every year since they took me."]`
- `JAK_MIDNIGHT_02`: "Midnight. Wesołych Świąt (Merry Christmas). ...Say it back. It is bad luck not to." `[say: "Midnight. Vesowih Shvyont. Say it back. It is bad luck not to."]`

### 16.2 The next maps: Kaltenbrunn (his guide lines) and Totenhafen

**`RETURN_WOUNDED`** (he bled out on the map before, and finds the squad on this one, a bandage round his head):
- `JAK_RETURN_WOUNDED_01`: "Not yet. Not tonight."
- `JAK_RETURN_WOUNDED_02`: "Jeszcze nie (not yet). They will have to try harder than that. No, don't help me. I can walk." `[say: "Yesh-cheh nyeh. They will have to try harder than that. No, don't help me. I can walk."]`

**`M1_ARRIVE`** (Kaltenbrunn):
- `JAK_M1_ARRIVE_01`: "Kaltenbrunn. I walked out of this place four days ago. I did not think I would walk back in with friends."
- `JAK_M1_ARRIVE_02`: "Listen to me here. Stay on the planks. Don't touch the black glass in the walls. And if the bell rings, walk toward it."

**`M1_SHORTCUT`** (he shows the Maintenance Stairs: 500 Scrip off while he is with you):
- `JAK_M1_SHORTCUT_01`: "The Maintenance Stairs. That is how I got out. The lock is rusted through. Let me show you where to kick it, and it costs you five hundred less."

**`M1_POWER`**:
- `JAK_M1_POWER_01`: "The lights. Two years down here and I never saw it lit like this. It looks worse."

**`M1_FOREMAN`** (the Foreman, Obersteiger Mahlknecht):
- `JAK_M1_FOREMAN_01`: "Nadsztygar Mahlknecht (the head overman). He locked the gates on Gallery Seven. I was on the night shift. My shift lived." `[say: "Nad-shtigar Mahlknecht. He locked the gates on Gallery Seven. I was on the night shift. My shift lived."]`
- `JAK_M1_FOREMAN_02`: "Him. I would know that walk anywhere. Don't let him reach you. He never let go of anything."

**`SCREAMER`**:
- `JAK_SCREAMER_01`: "That voice. In the deep levels you learn not to answer voices."

**`ZONE_*`** (a door opens on a part of the mine he knows):
- `JAK_ZONE_B_RAILYARD_01`: "The rail yard. They brought us in through here. The wagon slats were nailed shut. You count the gaps of light to know the time."
- `JAK_ZONE_C_ADMIN_01`: "Administration. They kept our names in there. Numbers first, then names, then only numbers."
- `JAK_ZONE_D_BARRACKS_01`: "The guards' barracks. Warm stoves. We could smell their coffee from the galleries."
- `JAK_ZONE_E_LIFT_01`: "The cage lift. Sixty men to a cage. Hold the rail. It drops faster than you think."
- `JAK_ZONE_M_STAIRS_01`: "The stairs. Mind the third landing, the steps are rotten. See the chalk by the rail? Three strokes and a hook. That one is mine."
- `JAK_ZONE_F_CHAPEL_01`: "The salt chapel. Miners carved it a hundred years ago. When the bell rang, we came here. Some of us."
- `JAK_ZONE_G_GENERATOR_01`: "The generator hall. Listen. It hums like the walls do. We used to say the mountain was breathing."
- `JAK_ZONE_H_LAB_01`: "The Laboratory Wing. ...I will go in. I don't want to. Don't ask me what they did in there. I only know who went in."

**`M2_ARRIVE`** (Totenhafen):
- `JAK_M2_ARRIVE_01`: "The sea. I have never seen the sea. ...I thought it would be bigger. No. It is bigger."
- `JAK_M2_ARRIVE_02`: "Totenhafen. Another place named for the dead. At least this salt I don't have to dig."
- `JAK_ZONE_D_PENHALL_01`: "Somebody poured this concrete by hand. Men like me, I think. I know that kind of tired when I see it in a wall."
- `JAK_ZONE_E_UBOAT_01`: "A boat that goes under the water on purpose. In the mine we prayed for the opposite."

### 16.3 In the fight (squad categories, §13 and §15, in his voice)

- `JAK_DOWN_01`: "I'm down. Don't run to me. Think first."
- `JAK_DOWN_02`: "Jezus Maria (Jesus, Mary)... my leg." `[say: "Yezoos Maria... my leg."]`
- `JAK_DOWN_03`: "On the floor again. Come when it is safe."
- `JAK_REVIVED_01`: "Dzięki (thanks). I owe you a drink. Not from those machines." `[say: "Jenkee. I owe you a drink. Not from those machines."]`
- `JAK_REVIVED_02`: "Up. Up. I am still here."
- `JAK_REVIVE_01`: "I've got you. Hold still, like in the shaft."
- `JAK_REVIVE_02`: "Easy. Breathe. I am pulling you up."
- `JAK_TEAM_DOWN_01`: "Someone is down! Go, I'll cover you!"
- `JAK_TEAM_DOWN_02`: "They have one of ours on the floor!"
- `JAK_RELOAD_01`: "Reloading."
- `JAK_RELOAD_02`: "Wait. Reloading. Count with me."
- `JAK_BOARD_01`: "Boarded. Like a shaft mouth. It holds until it doesn't."
- `JAK_BOARD_02`: "Done. Nailed shut."
- `JAK_AMMO_LOW_01`: "I am running low. Every shot counts now."
- `JAK_AMMO_NONE_01`: "Empty. The shovel, then."
- `JAK_BUY_AMMO_01`: "Thank you. I will make every one of these count."
- `JAK_POWERUP_SEEN_01`: "Something glowing, over there. You take it. You know what it does."
- `JAK_PING_RESUPPLY_01`: "Resupply, over there! Ammunition!"
- `JAK_PING_DEATHSDOOR_01`: "Death's Door, there. I don't touch that one. You decide."
- `JAK_PING_DOUBLESCRIP_01`: "Double Scrip, on the floor! Take it."
- `JAK_PING_BLACKOUT_01`: "Blackout, there. Pick it up when you need it."
- `JAK_PING_FORTIFY_01`: "Fortify! For the windows, over here!"
- `JAK_PING_CLEARANCE_01`: "Clearance, there. The crate is cheap now."
- `JAK_SPRINTER_BEHIND_01`: "Uwaga! Za tobą! (Look out! Behind you!) A fast one!" `[say: "Oovahga! Zah tobom! A fast one!"]`
- `JAK_SPRINTER_BEHIND_02`: "Behind you! Running!"
- `JAK_BOSS_INCOMING_01`: "Something big is coming. Stay together."
- `JAK_CRATE_MOVED_01`: "The crate has moved. I heard it go. Over that way."
- `JAK_WINDOW_OPEN_01`: "The window is open! Here!"
- `JAK_COVER_01`: "Go, pick them up. I am watching your back."
- `JAK_CMD_FOLLOW_01`: "Behind you. Always behind you."
- `JAK_CMD_HOLD_01`: "I stay here. Nobody passes."
- `JAK_CMD_REPAIR_01`: "I'll do the windows. I know boards."
- `JAK_CMD_REVIVE_01`: "If anyone falls, I go."
- `JAK_CMD_TRAIN_01`: "I follow. Keep them moving."
- `JAK_CMD_BUY_PERKS_01`: "Buy what you like. Not for me."
- `JAK_CMD_SAVE_SCRIP_01`: "Good. Save. A poor man's wisdom."
- `JAK_CMD_OPEN_DOOR_01`: "I'll open it for you."
- `JAK_CMD_FETCH_PART_01`: "I'll bring it."
- `JAK_HEADSHOT_01`: "The head. Like splitting coal along the seam."
- `JAK_CRAWLER_01`: "This one crawls. Mind your ankles."
- `JAK_CHATTER_01`: "In the mine we sang to keep time. Here I count rounds."
- `JAK_CHATTER_02`: "My Marta would say I look thin. She would be right."
- `JAK_CHATTER_03`: "You fight well. Your mothers should be proud. Write to them."
- `JAK_CHATTER_04`: "I used to hate the dark. Then I worked in it for twenty years. Now I only hate what lives in it."

### 16.4 The squad about Jakub

**`JAKUB_MEET`** (the survivor who freed him, as he joins):
- `DUT_JAKUB_MEET_01`: "Walter Kowalczyk. Call me Dutch. My Babcia came from Wilcza Góra. ...Maybe our families knew each other."
- `PEG_JAKUB_MEET_01`: "Lieutenant Ashworth. Stay close, keep your head down, and if you know a way out of here, I want it."
- `DEA_JAKUB_MEET_01`: "Elijah Brooks. Folks call me Deacon. You've been through it, haven't you. Well. You're with us now."
- `WRN_JAKUB_MEET_01`: "Ostrowski. From Wilcza Góra. ...I know your face. I was a girl."

**`JAKUB_FALLEN`** (he bled out: out cold, breathing, left where he fell; he comes back on the next map):
- `DUT_JAKUB_FALLEN_01`: "Jakub's out cold. He's breathing. We can't carry him and fight. ...We'll come back for you, old man."
- `PEG_JAKUB_FALLEN_01`: "He's breathing, but he won't wake. Leave him where he lies. They've no interest in him now."
- `DEA_JAKUB_FALLEN_01`: "Lord, keep that man breathing. He's out. We'll come back for him, you hear me?"
- `WRN_JAKUB_FALLEN_01`: "Jakub. ...He breathes. Leave him. He has walked out of worse places than this."

### 16.5 Banter and the Wren scene

Round-break banter (§1.4 `BNT_*`, rolled like the others):

**BNT_DUT_JAK_01**
- DUT: "Your village. Wilcza Góra. My Babcia sang a song about lanterns going down a shaft."
- JAK: "And coming back up. Everyone sings the coming-back-up part louder."
- DUT: "Yeah. She did too."

**BNT_PEG_JAK_01**
- PEG: "You walked out of Kaltenbrunn on your own?"
- JAK: "Not on my own. Eleven of us went up the stairs. I was the one slow enough to be careful."
- PEG: "...I'm sorry."
- JAK: "So am I, Lieutenant."

**BNT_DEA_JAK_01**
- DEA: "You talk to the machines down there, Jakub? I talk to mine."
- JAK: "To the rock. The rock tells you when it will fall. Machines only lie."
- DEA: "Now that's the truest thing anybody's said to me all week."

**The Wren scene** (`BNT_WRN_JAK_SCENE_01`, category `WRN_JAK_SCENE`: never rolled as banter). Once per match, the first
time Wren talks to him: the human playing Wren after the choice, or a Wren bot within 5 m of him in a quiet moment.
Positional, both voices at their bodies. He knew her brother (CANON §6.4, consistent with CHARACTERS.md "Wren" and
LORE §12.1: Jakub saw Tomasz taken to the Laboratory Wing and nothing after; the chalk is the Morgenrot seed).

**BNT_WRN_JAK_SCENE_01**
- JAK: "You are Zosia. Nowak the timberman's girl. You shot the crows off my roof when you were nine."
- WRN: "...Pan Ostrowski. From the end of the lane. You had a dog with one ear."
- JAK: "Burek. Zosia, I worked beside your brother. In Gallery Nine, from the autumn they took him."
- WRN: "Tomek. You saw Tomek."
- JAK: "Every day, for five months. He threw stones at the rats and never once hit one. He laughed every time. The guards hated that laugh."
- WRN: "He wrote that. That he practised on the rats. That he still missed."
- JAK: "In the spring the doctors came for young men with good lungs. They took him to the Laboratory Wing. I did not see him after. I am sorry. I looked."
- WRN: "...Thank you for looking."
- JAK: "Before they took him, I taught him the chalk. The marks we left for each other. He made his hook backwards. Always backwards."
- WRN: "Then if I ever see a backwards hook, I'll know it's his."

## 17. The Armorer's Bench: Gunsmith lines (Update 04 §6, DECISIONS T-068)

Each survivor says one of these when they fit an attachment to their M1911 at the Armorer's Bench (the first
purchase of the match always, then 45% of the time; `attachments.json` "vo"). Player channel, chatter
priority, positional at the buyer. Jakub has one for the day a bot order sends him to the bench, and he refuses the
Nachtglas rounds (`GUNSMITH_REFUSE`, when the bench API is asked to load them into his pistol, or when you try to
hand him a pistol already loaded with them). Unbaked lines play as subtitles until the TTS bake.

**`GUNSMITH`** (an attachment fitted):
- `DUT_GUNSMITH_01`: "There. Same old forty-five, just meaner."
- `DUT_GUNSMITH_02`: "My uncle fixed tractors with less. This'll do."
- `PEG_GUNSMITH_01`: "Section Five would have killed for a bench like this. Possibly literally."
- `PEG_GUNSMITH_02`: "Better. Now it does what it's told."
- `DEA_GUNSMITH_01`: "Every engine wants a little love. Guns too. Mostly guns."
- `DEA_GUNSMITH_02`: "Seated, snug, and squared away. Like a good track pin."
- `WRN_GUNSMITH_01`: "Not my rifle. But it's learning."
- `WRN_GUNSMITH_02`: "Sights right, grip right. Now it only has to be honest."
- `JAK_GUNSMITH_01`: "In the mine we mended everything twice. Here, once will have to do."

**`GUNSMITH_REFUSE`** (Jakub and the Nachtglas rounds):
- `JAK_GUNSMITH_REFUSE_01`: "No. Not the glass. I dug that stuff out of the walls. It does not go in my hands."
- `JAK_GUNSMITH_REFUSE_02`: "Keep the purple ones. I have seen what they do to the men who carry them."


## 18. AI teammates on the easter egg (Update 04 §5, DECISIONS T-067)

Spoken by a bot (or Jakub) working an easter-egg step (BotEE, `data/gravelight/ai/ee.json`; the setting "Bot
Easter-Egg Help": Off / When Asked / Full Partner). Positional at the bot, through BotSquad.callout (forced, rate-limited
by BotEE itself: progress every 15 s at most, interrupted / resumed every 30 s, refusals every 6 s), and each start
flashes a world ping at the target with its name (NOTE, RADIO, BELL, PART...), so a generic line still says where.
Categories: `EE_ACK` and `EE_ACK_<TYPE>` (taking a task: COLLECT, SHOOT_TARGET, HOLD_ZONE, CARRY, INTERACT_SEQUENCE,
KILL_WITH_WEAPON, TURN_KEY), `EE_PLAYER_ONLY` (asked for a player-only step: covering the player instead),
`EE_PROGRESS` (one more part / note / input), `EE_DONE`, `EE_HANDOFF` (the last input is the player's commit),
`EE_CANT` / `EE_CANT_INFO` (the squad hasn't discovered what the step needs) / `EE_CANT_FIND` (not found yet, or out of
reach) / `EE_CANT_RISKY` (it could set the egg back: only on the player's word) / `EE_WAIT_PLAYER` (a last step waits
for the player), `EE_INTERRUPTED` (pausing for a fight, a teammate down, the round ending), `EE_RESUME` ("Back to it.").
Jakub does Collect, Hold and Carry only and refuses the Crucible, the perk machines and anything else in character
(`EE_REFUSE_CRUCIBLE`, `EE_REFUSE_PERK`, `EE_REFUSE_TYPE`): never a joke. The ids carry `SQ4` so the voice bake can run
them alone (`python gravelight/tools_src/gen_vo.py --only=DUT_SQ4`).

### 17.1 Dutch (`DUT`)
- `DUT_SQ4_EE_ACK_01`: "On it. Keep 'em off my back."
- `DUT_SQ4_EE_ACK_COLLECT_01`: "I'll go pick those up. Cover the windows."
- `DUT_SQ4_EE_ACK_COLLECT_02`: "Leave the scavenging to me."
- `DUT_SQ4_EE_ACK_SHOOT_TARGET_01`: "I see it. Give me a clean shot."
- `DUT_SQ4_EE_ACK_HOLD_ZONE_01`: "I'll plant myself right there. Nobody moves me."
- `DUT_SQ4_EE_ACK_CARRY_01`: "I'll haul it over. Don't let 'em jump me."
- `DUT_SQ4_EE_ACK_INTERACT_SEQUENCE_01`: "I'll work the dials. Holler if it gets hairy."
- `DUT_SQ4_EE_ACK_KILL_WITH_WEAPON_01`: "Bell gun and a crowd. Now we're talking."
- `DUT_SQ4_EE_ACK_TURN_KEY_01`: "I'm on my key. Say when."
- `DUT_SQ4_EE_PLAYER_ONLY_01`: "That one's yours, partner. I'll watch your back."
- `DUT_SQ4_EE_PROGRESS_01`: "Got one. Moving on."
- `DUT_SQ4_EE_PROGRESS_02`: "That's another. Still at it."
- `DUT_SQ4_EE_DONE_01`: "Done. Whatever that was for."
- `DUT_SQ4_EE_HANDOFF_01`: "Got it all set up. Last one's yours."
- `DUT_SQ4_EE_CANT_01`: "Can't do that one right now."
- `DUT_SQ4_EE_CANT_INFO_01`: "Wish I could. Nobody's told me how yet."
- `DUT_SQ4_EE_CANT_FIND_01`: "Haven't laid eyes on it yet. Show me where."
- `DUT_SQ4_EE_CANT_RISKY_01`: "That could blow up on us. Your call, not mine."
- `DUT_SQ4_EE_WAIT_PLAYER_01`: "This part needs you here. I'll wait."
- `DUT_SQ4_EE_INTERRUPTED_01`: "Hold that thought. Got company."
- `DUT_SQ4_EE_RESUME_01`: "Back to it."
- `DUT_SQ4_EE_RESUME_02`: "Right. Where was I."

### 17.2 Peg (`PEG`)
- `PEG_SQ4_EE_ACK_01`: "Leave it with me."
- `PEG_SQ4_EE_ACK_COLLECT_01`: "I'll collect them. Do keep the windows shut."
- `PEG_SQ4_EE_ACK_COLLECT_02`: "Fetching. Try not to miss me."
- `PEG_SQ4_EE_ACK_SHOOT_TARGET_01`: "I have the mark. One clean shot."
- `PEG_SQ4_EE_ACK_HOLD_ZONE_01`: "I'll hold the spot. Bring them to me if you must."
- `PEG_SQ4_EE_ACK_CARRY_01`: "I'll carry it across. Clear me a path."
- `PEG_SQ4_EE_ACK_INTERACT_SEQUENCE_01`: "Dials and wires. Finally, something I'm trained for."
- `PEG_SQ4_EE_ACK_KILL_WITH_WEAPON_01`: "Right weapon, right place. Send them in."
- `PEG_SQ4_EE_ACK_TURN_KEY_01`: "At my key. On your count."
- `PEG_SQ4_EE_PLAYER_ONLY_01`: "That one is yours. I'll keep them off you."
- `PEG_SQ4_EE_PROGRESS_01`: "One more accounted for."
- `PEG_SQ4_EE_PROGRESS_02`: "Progress. Don't celebrate yet."
- `PEG_SQ4_EE_DONE_01`: "Done. Neatly, I might add."
- `PEG_SQ4_EE_HANDOFF_01`: "Everything's set. The last move is yours."
- `PEG_SQ4_EE_CANT_01`: "Not possible just now, I'm afraid."
- `PEG_SQ4_EE_CANT_INFO_01`: "Not yet. We're missing the information, and I won't guess."
- `PEG_SQ4_EE_CANT_FIND_01`: "We haven't found it yet. Point me at it."
- `PEG_SQ4_EE_CANT_RISKY_01`: "That could undo the whole thing. Say so and I'll do it."
- `PEG_SQ4_EE_WAIT_PLAYER_01`: "This part wants you present. I'll wait."
- `PEG_SQ4_EE_INTERRUPTED_01`: "Pausing. They've other plans for us."
- `PEG_SQ4_EE_RESUME_01`: "Back to it."
- `PEG_SQ4_EE_RESUME_02`: "Now. Where were we."

### 17.3 Deacon (`DEA`)
- `DEA_SQ4_EE_ACK_01`: "I got it, brother."
- `DEA_SQ4_EE_ACK_COLLECT_01`: "I'll go round 'em up. Keep those windows boarded."
- `DEA_SQ4_EE_ACK_COLLECT_02`: "Picking those up. Won't be long."
- `DEA_SQ4_EE_ACK_SHOOT_TARGET_01`: "Lord, steady my hand. Taking the shot."
- `DEA_SQ4_EE_ACK_HOLD_ZONE_01`: "I'll stand right here like a fence post."
- `DEA_SQ4_EE_ACK_CARRY_01`: "I'll tote it over. Heavy things are my ministry."
- `DEA_SQ4_EE_ACK_INTERACT_SEQUENCE_01`: "Let me at that machine. She'll talk to me."
- `DEA_SQ4_EE_ACK_KILL_WITH_WEAPON_01`: "Ring that bell, sweetheart. Bring 'em close."
- `DEA_SQ4_EE_ACK_TURN_KEY_01`: "Hand's on the key. Waiting on yours."
- `DEA_SQ4_EE_PLAYER_ONLY_01`: "That's yours to do. I'll keep the wolves off."
- `DEA_SQ4_EE_PROGRESS_01`: "There's one. Praise be."
- `DEA_SQ4_EE_PROGRESS_02`: "Another one done. Keep it coming."
- `DEA_SQ4_EE_DONE_01`: "That's done. Amen."
- `DEA_SQ4_EE_HANDOFF_01`: "She's ready. The last turn's yours."
- `DEA_SQ4_EE_CANT_01`: "Can't manage that one right now."
- `DEA_SQ4_EE_CANT_INFO_01`: "Not yet. I don't know the words to that hymn."
- `DEA_SQ4_EE_CANT_FIND_01`: "Haven't found it yet. Lead me to it."
- `DEA_SQ4_EE_CANT_RISKY_01`: "That could bring the roof down on us. You say the word."
- `DEA_SQ4_EE_WAIT_PLAYER_01`: "This part needs you with me."
- `DEA_SQ4_EE_INTERRUPTED_01`: "Hold on now. Trouble first."
- `DEA_SQ4_EE_RESUME_01`: "Back to it."
- `DEA_SQ4_EE_RESUME_02`: "Alright. Back to the Lord's work."

### 17.4 Wren (`WRN`)
- `WRN_SQ4_EE_ACK_01`: "Yes. I do it."
- `WRN_SQ4_EE_ACK_COLLECT_01`: "I find them. You hold the windows."
- `WRN_SQ4_EE_ACK_COLLECT_02`: "I bring them."
- `WRN_SQ4_EE_ACK_SHOOT_TARGET_01`: "I see it. One shot."
- `WRN_SQ4_EE_ACK_HOLD_ZONE_01`: "I stand here. Nobody passes."
- `WRN_SQ4_EE_ACK_CARRY_01`: "I carry it. Cover me."
- `WRN_SQ4_EE_ACK_INTERACT_SEQUENCE_01`: "I do the machine."
- `WRN_SQ4_EE_ACK_KILL_WITH_WEAPON_01`: "Good. Send them here."
- `WRN_SQ4_EE_ACK_TURN_KEY_01`: "My key. Tell me when."
- `WRN_SQ4_EE_PLAYER_ONLY_01`: "This is yours. I watch."
- `WRN_SQ4_EE_PROGRESS_01`: "One more."
- `WRN_SQ4_EE_PROGRESS_02`: "Again. Good."
- `WRN_SQ4_EE_DONE_01`: "Done."
- `WRN_SQ4_EE_HANDOFF_01`: "Ready. The last one is yours."
- `WRN_SQ4_EE_CANT_01`: "No. Not now."
- `WRN_SQ4_EE_CANT_INFO_01`: "We do not know it yet. I don't guess."
- `WRN_SQ4_EE_CANT_FIND_01`: "Not found yet. Show me."
- `WRN_SQ4_EE_CANT_RISKY_01`: "This can go wrong. You say, I do."
- `WRN_SQ4_EE_WAIT_PLAYER_01`: "You must be here for this."
- `WRN_SQ4_EE_INTERRUPTED_01`: "Wait. Fight first."
- `WRN_SQ4_EE_RESUME_01`: "Back to it."
- `WRN_SQ4_EE_RESUME_02`: "Now again."

### 17.5 Jakub (`JAK`)
- `JAK_SQ4_EE_ACK_COLLECT_01`: "I'll gather them. Like picking coal off the belt."
- `JAK_SQ4_EE_ACK_COLLECT_02`: "Dobrze (good). I'll find them and bring them." `[say: "Dob-zheh. I'll find them and bring them."]`
- `JAK_SQ4_EE_ACK_HOLD_ZONE_01`: "I'll stand here. I have stood in worse places."
- `JAK_SQ4_EE_ACK_CARRY_01`: "Give it to me. I have carried heavier things out of the dark."
- `JAK_SQ4_EE_PLAYER_ONLY_01`: "That is for you to do. I'll stand behind you."
- `JAK_SQ4_EE_PROGRESS_01`: "One. Next."
- `JAK_SQ4_EE_PROGRESS_02`: "That's another. Slowly, carefully."
- `JAK_SQ4_EE_DONE_01`: "Done. It is where it should be."
- `JAK_SQ4_EE_CANT_01`: "Not now. I'm sorry."
- `JAK_SQ4_EE_CANT_INFO_01`: "We don't know enough yet. In the mine you don't guess. You wait for the lamp."
- `JAK_SQ4_EE_CANT_FIND_01`: "I haven't seen it. Show me where, and I'll go."
- `JAK_SQ4_EE_WAIT_PLAYER_01`: "This needs you here. I'll wait with it."
- `JAK_SQ4_EE_INTERRUPTED_01`: "Wait. First these ones."
- `JAK_SQ4_EE_RESUME_01`: "Back to it."
- `JAK_SQ4_EE_RESUME_02`: "Spokojnie (easy). Back to work." `[say: "Spo-koy-nyeh. Back to work."]`
- `JAK_SQ4_EE_REFUSE_CRUCIBLE_01`: "Not the furnace. I have seen what fires like that get fed. Ask me anything else."
- `JAK_SQ4_EE_REFUSE_CRUCIBLE_02`: "No. I won't put my hands near that fire. Give me something to carry."
- `JAK_SQ4_EE_REFUSE_PERK_01`: "Those machines? No. I don't touch them, and I don't drink from them."
- `JAK_SQ4_EE_REFUSE_TYPE_01`: "That needs a steady rifle and a good eye. I can carry, gather, and hold ground."

## 19. AI teammates on map marks and the ping key (Update 04 §3, DECISIONS T-069)

Spoken by a bot (or Jakub) given a map mark from the pause map or the ping key (BotMarkTask / BotMarkOrders,
`data/gravelight/ai/marks.json`; forced through BotSquad.callout, positional at the bot, each acknowledgement with a
world ping at the spot). Categories: `MARK_ACK` and `MARK_ACK_BUY` / `_FOR_YOU` (buying a gun for the player) /
`_GO` / `_DEFEND` / `_REGROUP` (taking the order), `MARK_DANGER` (calling out a Danger mark), `MARK_AFFORD` (it
has the Scrip now: on its way), `MARK_BOUGHT` and `MARK_BOUGHT_<perk token>` / `_GUN` / `_DOOR` / `_AMMO` / `_CRATE` /
`_CRUCIBLE` / `_TRAP` / `_BENCH` and `MARK_DONE_POWER` (the confirmation; the automatic perk / buy / door line is
held back for it), `MARK_SHORT_<amount>` (short of Scrip by up to that much: 100 to 1,000 by hundreds, then 1,250,
1,500, 2,000, 2,500, 3,000, 4,000, 5,000; above that `MARK_SHORT_LOTS`; `MARK_SHORT` without an amount),
`MARK_EXPIRED` (the 60 s queue ran out), `MARK_FOR_YOU_HOLD` / `MARK_FOR_YOU_DROP` (the gun it bought for the player:
carrying it, dropped at their feet), `MARK_RESUME` ("Back to it." after a revive pulled it away), `MARK_CANT` and
`MARK_CANT_OWNED` / `_POWER` / `_CAP` / `_REACH` / `_FULL` (refusals). Jakub has no Scrip and never buys:
`MARK_REFUSE_BUY` (and his section 18 `EE_REFUSE_PERK` / `EE_REFUSE_CRUCIBLE` for the perk machines and the
Crucible); he goes, defends, regroups and calls danger. The ids carry `SQ5` so the voice bake can run them alone
(`python gravelight/tools_src/gen_vo.py --only=DUT_SQ5`).

### 19.1 Dutch (`DUT`)
- `DUT_SQ5_MARK_ACK_01`: "On it."
- `DUT_SQ5_MARK_ACK_02`: "You got it, boss."
- `DUT_SQ5_MARK_ACK_BUY_01`: "I'll go buy it. My Scrip, your idea."
- `DUT_SQ5_MARK_ACK_BUY_02`: "Shopping run. Back in a minute."
- `DUT_SQ5_MARK_ACK_FOR_YOU_01`: "I'll pick one up for you."
- `DUT_SQ5_MARK_ACK_GO_01`: "Heading over."
- `DUT_SQ5_MARK_ACK_DEFEND_01`: "I'll dig in there. Nobody gets past."
- `DUT_SQ5_MARK_ACK_REGROUP_01`: "Coming to you. Everybody in."
- `DUT_SQ5_MARK_DANGER_01`: "Bad spot, there. Steer clear of it."
- `DUT_SQ5_MARK_DANGER_02`: "Stay away from that corner. I mean it."
- `DUT_SQ5_MARK_AFFORD_01`: "Got the Scrip now. On my way."
- `DUT_SQ5_MARK_BOUGHT_01`: "Done, boss."
- `DUT_SQ5_MARK_BOUGHT_IRONHIDE_01`: "Got the Ironhide. Feel like a barrel."
- `DUT_SQ5_MARK_BOUGHT_SECONDWIND_01`: "Second Wind's in me. I'll get you up quick."
- `DUT_SQ5_MARK_BOUGHT_TRIGGER_01`: "Trigger Tonic. Hands feel faster already."
- `DUT_SQ5_MARK_BOUGHT_TWINBARREL_01`: "Twin Barrel. Twice the noise."
- `DUT_SQ5_MARK_BOUGHT_MARATHON_01`: "Marathon Malt. My knees thank you."
- `DUT_SQ5_MARK_BOUGHT_HAWKEYE_01`: "Hawkeye. I see every whisker on 'em."
- `DUT_SQ5_MARK_BOUGHT_PACKMULE_01`: "Packmule. Room for one more gun."
- `DUT_SQ5_MARK_BOUGHT_BLASTPROOF_01`: "Blastproof. Let 'em throw things."
- `DUT_SQ5_MARK_BOUGHT_OVERCLOCK_01`: "Overclock. My teeth are humming."
- `DUT_SQ5_MARK_BOUGHT_GUN_01`: "Picked it up. She'll do."
- `DUT_SQ5_MARK_BOUGHT_DOOR_01`: "Door's open. Watch what comes through."
- `DUT_SQ5_MARK_BOUGHT_AMMO_01`: "Topped up."
- `DUT_SQ5_MARK_BOUGHT_CRATE_01`: "Pulled the crate. Let's see what it coughs up."
- `DUT_SQ5_MARK_BOUGHT_CRUCIBLE_01`: "Gun's in the fire. Cover me while she cooks."
- `DUT_SQ5_MARK_BOUGHT_TRAP_01`: "Trap's live. Keep clear."
- `DUT_SQ5_MARK_BOUGHT_BENCH_01`: "Bench work's done. Pistol's better for it."
- `DUT_SQ5_MARK_DONE_POWER_01`: "Power's on. Lights and all."
- `DUT_SQ5_MARK_SHORT_100_01`: "Need 100 more for that, boss."
- `DUT_SQ5_MARK_SHORT_200_01`: "Need 200 more for that, boss."
- `DUT_SQ5_MARK_SHORT_300_01`: "Need 300 more for that, boss."
- `DUT_SQ5_MARK_SHORT_400_01`: "Need 400 more for that, boss."
- `DUT_SQ5_MARK_SHORT_500_01`: "Need 500 more for that, boss."
- `DUT_SQ5_MARK_SHORT_600_01`: "Need 600 more for that, boss."
- `DUT_SQ5_MARK_SHORT_700_01`: "Need 700 more for that, boss."
- `DUT_SQ5_MARK_SHORT_800_01`: "Need 800 more for that, boss."
- `DUT_SQ5_MARK_SHORT_900_01`: "Need 900 more for that, boss."
- `DUT_SQ5_MARK_SHORT_1000_01`: "Need 1,000 more for that, boss."
- `DUT_SQ5_MARK_SHORT_1250_01`: "Need 1,250 more for that, boss."
- `DUT_SQ5_MARK_SHORT_1500_01`: "Need 1,500 more for that, boss."
- `DUT_SQ5_MARK_SHORT_2000_01`: "Need 2,000 more for that, boss."
- `DUT_SQ5_MARK_SHORT_2500_01`: "Need 2,500 more for that, boss."
- `DUT_SQ5_MARK_SHORT_3000_01`: "Need 3,000 more for that, boss."
- `DUT_SQ5_MARK_SHORT_4000_01`: "Need 4,000 more for that, boss."
- `DUT_SQ5_MARK_SHORT_5000_01`: "Need 5,000 more for that, boss."
- `DUT_SQ5_MARK_SHORT_LOTS_01`: "That's a lot more Scrip than I've got. Give me time."
- `DUT_SQ5_MARK_SHORT_01`: "I'm short on Scrip for that. Give me a bit."
- `DUT_SQ5_MARK_EXPIRED_01`: "Couldn't scrape it together. Dropping that one."
- `DUT_SQ5_MARK_FOR_YOU_HOLD_01`: "Got it for you. Come take it off me."
- `DUT_SQ5_MARK_FOR_YOU_DROP_01`: "Dropped it at your feet. Don't say I never got you nothing."
- `DUT_SQ5_MARK_RESUME_01`: "Back to it."
- `DUT_SQ5_MARK_RESUME_02`: "Right. Where was I. Back to it."
- `DUT_SQ5_MARK_CANT_01`: "Can't do that one."
- `DUT_SQ5_MARK_CANT_OWNED_01`: "Already got that one."
- `DUT_SQ5_MARK_CANT_POWER_01`: "No power to it. Throw the lever first."
- `DUT_SQ5_MARK_CANT_CAP_01`: "Can't fit another bottle in me."
- `DUT_SQ5_MARK_CANT_REACH_01`: "Can't get there from here. Something's in the way."
- `DUT_SQ5_MARK_CANT_FULL_01`: "My hands are full of good guns. Not swapping."

### 19.2 Peg (`PEG`)
- `PEG_SQ5_MARK_ACK_01`: "Understood."
- `PEG_SQ5_MARK_ACK_02`: "Right away."
- `PEG_SQ5_MARK_ACK_BUY_01`: "I'll see to it. On my account."
- `PEG_SQ5_MARK_ACK_BUY_02`: "Leave the purchasing to me."
- `PEG_SQ5_MARK_ACK_FOR_YOU_01`: "I'll buy you one. You can owe me."
- `PEG_SQ5_MARK_ACK_GO_01`: "Moving there now."
- `PEG_SQ5_MARK_ACK_DEFEND_01`: "I'll hold that spot."
- `PEG_SQ5_MARK_ACK_REGROUP_01`: "Regrouping. On you."
- `PEG_SQ5_MARK_DANGER_01`: "Avoid that area. I mean it."
- `PEG_SQ5_MARK_DANGER_02`: "That spot's bad. Keep out of it."
- `PEG_SQ5_MARK_AFFORD_01`: "Funds in hand. Going now."
- `PEG_SQ5_MARK_BOUGHT_01`: "Done."
- `PEG_SQ5_MARK_BOUGHT_IRONHIDE_01`: "Ironhide. I feel positively armoured."
- `PEG_SQ5_MARK_BOUGHT_SECONDWIND_01`: "Second Wind. I'll have you up in a jiffy."
- `PEG_SQ5_MARK_BOUGHT_TRIGGER_01`: "Trigger Tonic. Quick hands, quicker reloads."
- `PEG_SQ5_MARK_BOUGHT_TWINBARREL_01`: "Twin Barrel. Rather loud, isn't it."
- `PEG_SQ5_MARK_BOUGHT_MARATHON_01`: "Marathon Malt. I could run to Dover."
- `PEG_SQ5_MARK_BOUGHT_HAWKEYE_01`: "Hawkeye. Everything's terribly sharp."
- `PEG_SQ5_MARK_BOUGHT_PACKMULE_01`: "Packmule. Room for another."
- `PEG_SQ5_MARK_BOUGHT_BLASTPROOF_01`: "Blastproof. My satchels and I are friends again."
- `PEG_SQ5_MARK_BOUGHT_OVERCLOCK_01`: "Overclock. That fizzes."
- `PEG_SQ5_MARK_BOUGHT_GUN_01`: "Bought. Not my usual, but it'll serve."
- `PEG_SQ5_MARK_BOUGHT_DOOR_01`: "Door's open. Mind what follows."
- `PEG_SQ5_MARK_BOUGHT_AMMO_01`: "Ammunition replenished."
- `PEG_SQ5_MARK_BOUGHT_CRATE_01`: "Crate's open. Fingers crossed."
- `PEG_SQ5_MARK_BOUGHT_CRUCIBLE_01`: "Into the fire it goes. Keep them off me."
- `PEG_SQ5_MARK_BOUGHT_TRAP_01`: "Trap's sprung. Stand clear."
- `PEG_SQ5_MARK_BOUGHT_BENCH_01`: "Fitted. A proper job."
- `PEG_SQ5_MARK_DONE_POWER_01`: "Power's on. Finally."
- `PEG_SQ5_MARK_SHORT_100_01`: "I'm 100 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_200_01`: "I'm 200 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_300_01`: "I'm 300 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_400_01`: "I'm 400 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_500_01`: "I'm 500 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_600_01`: "I'm 600 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_700_01`: "I'm 700 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_800_01`: "I'm 800 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_900_01`: "I'm 900 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_1000_01`: "I'm 1,000 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_1250_01`: "I'm 1,250 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_1500_01`: "I'm 1,500 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_2000_01`: "I'm 2,000 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_2500_01`: "I'm 2,500 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_3000_01`: "I'm 3,000 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_4000_01`: "I'm 4,000 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_5000_01`: "I'm 5,000 short, I'm afraid. Give me a moment."
- `PEG_SQ5_MARK_SHORT_LOTS_01`: "I'm nowhere near that. Give me a few rounds."
- `PEG_SQ5_MARK_SHORT_01`: "I can't afford that yet."
- `PEG_SQ5_MARK_EXPIRED_01`: "Couldn't raise the funds. I've let that one go."
- `PEG_SQ5_MARK_FOR_YOU_HOLD_01`: "Bought it for you. Come and collect."
- `PEG_SQ5_MARK_FOR_YOU_DROP_01`: "It's at your feet. Do look after it."
- `PEG_SQ5_MARK_RESUME_01`: "Back to it."
- `PEG_SQ5_MARK_RESUME_02`: "Now. Where was I. Back to it."
- `PEG_SQ5_MARK_CANT_01`: "I can't do that."
- `PEG_SQ5_MARK_CANT_OWNED_01`: "I have that already."
- `PEG_SQ5_MARK_CANT_POWER_01`: "It's dead. We need the power."
- `PEG_SQ5_MARK_CANT_CAP_01`: "No room for another tonic."
- `PEG_SQ5_MARK_CANT_REACH_01`: "There's no way through from here."
- `PEG_SQ5_MARK_CANT_FULL_01`: "My hands are full of better guns."

### 19.3 Deacon (`DEA`)
- `DEA_SQ5_MARK_ACK_01`: "Yes sir."
- `DEA_SQ5_MARK_ACK_02`: "Consider it done."
- `DEA_SQ5_MARK_ACK_BUY_01`: "I'll go buy it. Good use of Scrip."
- `DEA_SQ5_MARK_ACK_BUY_02`: "On my dime. I'll fetch it."
- `DEA_SQ5_MARK_ACK_FOR_YOU_01`: "I'll get you one, brother."
- `DEA_SQ5_MARK_ACK_GO_01`: "Heading that way."
- `DEA_SQ5_MARK_ACK_DEFEND_01`: "I'll keep watch there and mend what breaks."
- `DEA_SQ5_MARK_ACK_REGROUP_01`: "Gathering up. Coming."
- `DEA_SQ5_MARK_DANGER_01`: "Lord, stay away from that spot."
- `DEA_SQ5_MARK_DANGER_02`: "Keep clear of there, brother."
- `DEA_SQ5_MARK_AFFORD_01`: "I've got enough now. Going."
- `DEA_SQ5_MARK_BOUGHT_01`: "Done and done."
- `DEA_SQ5_MARK_BOUGHT_IRONHIDE_01`: "Ironhide. Feel like a boiler plate."
- `DEA_SQ5_MARK_BOUGHT_SECONDWIND_01`: "Second Wind. I'll get folks up faster."
- `DEA_SQ5_MARK_BOUGHT_TRIGGER_01`: "Trigger Tonic. Oiled and quick."
- `DEA_SQ5_MARK_BOUGHT_TWINBARREL_01`: "Twin Barrel. Double the work."
- `DEA_SQ5_MARK_BOUGHT_MARATHON_01`: "Marathon Malt. Legs like pistons."
- `DEA_SQ5_MARK_BOUGHT_HAWKEYE_01`: "Hawkeye. I can read the rivets."
- `DEA_SQ5_MARK_BOUGHT_PACKMULE_01`: "Packmule. Another toolbox for the belt."
- `DEA_SQ5_MARK_BOUGHT_BLASTPROOF_01`: "Blastproof. Let it bang."
- `DEA_SQ5_MARK_BOUGHT_OVERCLOCK_01`: "Overclock. That's got some current in it."
- `DEA_SQ5_MARK_BOUGHT_GUN_01`: "Bought it. Fine piece of machinery."
- `DEA_SQ5_MARK_BOUGHT_DOOR_01`: "Door's open. Watch it now."
- `DEA_SQ5_MARK_BOUGHT_AMMO_01`: "Loaded up."
- `DEA_SQ5_MARK_BOUGHT_CRATE_01`: "Crate's turning. Let's pray on it."
- `DEA_SQ5_MARK_BOUGHT_CRUCIBLE_01`: "She's in the forge. Keep 'em off me a minute."
- `DEA_SQ5_MARK_BOUGHT_TRAP_01`: "Trap's running. Stand back."
- `DEA_SQ5_MARK_BOUGHT_BENCH_01`: "Bench work's finished. Fits like it grew there."
- `DEA_SQ5_MARK_DONE_POWER_01`: "Power's flowing. Hear that hum?"
- `DEA_SQ5_MARK_SHORT_100_01`: "I'm 100 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_200_01`: "I'm 200 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_300_01`: "I'm 300 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_400_01`: "I'm 400 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_500_01`: "I'm 500 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_600_01`: "I'm 600 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_700_01`: "I'm 700 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_800_01`: "I'm 800 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_900_01`: "I'm 900 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_1000_01`: "I'm 1,000 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_1250_01`: "I'm 1,250 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_1500_01`: "I'm 1,500 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_2000_01`: "I'm 2,000 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_2500_01`: "I'm 2,500 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_3000_01`: "I'm 3,000 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_4000_01`: "I'm 4,000 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_5000_01`: "I'm 5,000 shy, brother. I'll earn it."
- `DEA_SQ5_MARK_SHORT_LOTS_01`: "That's more Scrip than I've seen all week. I'll work on it."
- `DEA_SQ5_MARK_SHORT_01`: "Can't cover that yet. I'll earn it."
- `DEA_SQ5_MARK_EXPIRED_01`: "Couldn't come up with it. Letting that one go."
- `DEA_SQ5_MARK_FOR_YOU_HOLD_01`: "Got it for you. Come take it."
- `DEA_SQ5_MARK_FOR_YOU_DROP_01`: "Left it at your feet. Take good care of her."
- `DEA_SQ5_MARK_RESUME_01`: "Back to it."
- `DEA_SQ5_MARK_RESUME_02`: "Now, back to it."
- `DEA_SQ5_MARK_CANT_01`: "Can't manage that one."
- `DEA_SQ5_MARK_CANT_OWNED_01`: "Already got it."
- `DEA_SQ5_MARK_CANT_POWER_01`: "No juice to it. Power first."
- `DEA_SQ5_MARK_CANT_CAP_01`: "Can't hold another bottle, brother."
- `DEA_SQ5_MARK_CANT_REACH_01`: "Can't get through from here."
- `DEA_SQ5_MARK_CANT_FULL_01`: "I've got my hands full of forged iron. Not trading."

### 19.4 Wren (`WRN`)
- `WRN_SQ5_MARK_ACK_01`: "Yes."
- `WRN_SQ5_MARK_ACK_02`: "I go."
- `WRN_SQ5_MARK_ACK_BUY_01`: "I buy it. My Scrip."
- `WRN_SQ5_MARK_ACK_BUY_02`: "Yes. I buy."
- `WRN_SQ5_MARK_ACK_FOR_YOU_01`: "I buy one for you."
- `WRN_SQ5_MARK_ACK_GO_01`: "I go there."
- `WRN_SQ5_MARK_ACK_DEFEND_01`: "I hold there."
- `WRN_SQ5_MARK_ACK_REGROUP_01`: "Coming."
- `WRN_SQ5_MARK_DANGER_01`: "Bad place. Stay away."
- `WRN_SQ5_MARK_DANGER_02`: "Not there. Danger."
- `WRN_SQ5_MARK_AFFORD_01`: "Now I have enough. I go."
- `WRN_SQ5_MARK_BOUGHT_01`: "Done."
- `WRN_SQ5_MARK_BOUGHT_IRONHIDE_01`: "Ironhide. Good."
- `WRN_SQ5_MARK_BOUGHT_SECONDWIND_01`: "Second Wind. I lift you faster."
- `WRN_SQ5_MARK_BOUGHT_TRIGGER_01`: "Trigger Tonic. Fast hands."
- `WRN_SQ5_MARK_BOUGHT_TWINBARREL_01`: "Twin Barrel. Two."
- `WRN_SQ5_MARK_BOUGHT_MARATHON_01`: "Marathon Malt. I run."
- `WRN_SQ5_MARK_BOUGHT_HAWKEYE_01`: "Hawkeye. Now I see everything."
- `WRN_SQ5_MARK_BOUGHT_PACKMULE_01`: "Packmule. One more rifle."
- `WRN_SQ5_MARK_BOUGHT_BLASTPROOF_01`: "Blastproof. Good."
- `WRN_SQ5_MARK_BOUGHT_OVERCLOCK_01`: "Overclock. It burns."
- `WRN_SQ5_MARK_BOUGHT_GUN_01`: "Bought."
- `WRN_SQ5_MARK_BOUGHT_DOOR_01`: "Door is open."
- `WRN_SQ5_MARK_BOUGHT_AMMO_01`: "Full again."
- `WRN_SQ5_MARK_BOUGHT_CRATE_01`: "Crate. We see."
- `WRN_SQ5_MARK_BOUGHT_CRUCIBLE_01`: "In the fire. Cover me."
- `WRN_SQ5_MARK_BOUGHT_TRAP_01`: "Trap is on."
- `WRN_SQ5_MARK_BOUGHT_BENCH_01`: "Pistol is better now."
- `WRN_SQ5_MARK_DONE_POWER_01`: "Power. On."
- `WRN_SQ5_MARK_SHORT_100_01`: "Need 100 more. I earn it."
- `WRN_SQ5_MARK_SHORT_200_01`: "Need 200 more. I earn it."
- `WRN_SQ5_MARK_SHORT_300_01`: "Need 300 more. I earn it."
- `WRN_SQ5_MARK_SHORT_400_01`: "Need 400 more. I earn it."
- `WRN_SQ5_MARK_SHORT_500_01`: "Need 500 more. I earn it."
- `WRN_SQ5_MARK_SHORT_600_01`: "Need 600 more. I earn it."
- `WRN_SQ5_MARK_SHORT_700_01`: "Need 700 more. I earn it."
- `WRN_SQ5_MARK_SHORT_800_01`: "Need 800 more. I earn it."
- `WRN_SQ5_MARK_SHORT_900_01`: "Need 900 more. I earn it."
- `WRN_SQ5_MARK_SHORT_1000_01`: "Need 1,000 more. I earn it."
- `WRN_SQ5_MARK_SHORT_1250_01`: "Need 1,250 more. I earn it."
- `WRN_SQ5_MARK_SHORT_1500_01`: "Need 1,500 more. I earn it."
- `WRN_SQ5_MARK_SHORT_2000_01`: "Need 2,000 more. I earn it."
- `WRN_SQ5_MARK_SHORT_2500_01`: "Need 2,500 more. I earn it."
- `WRN_SQ5_MARK_SHORT_3000_01`: "Need 3,000 more. I earn it."
- `WRN_SQ5_MARK_SHORT_4000_01`: "Need 4,000 more. I earn it."
- `WRN_SQ5_MARK_SHORT_5000_01`: "Need 5,000 more. I earn it."
- `WRN_SQ5_MARK_SHORT_LOTS_01`: "Too much. I earn it slowly."
- `WRN_SQ5_MARK_SHORT_01`: "Not enough Scrip. Wait."
- `WRN_SQ5_MARK_EXPIRED_01`: "Not enough. I stop."
- `WRN_SQ5_MARK_FOR_YOU_HOLD_01`: "For you. Take it from me."
- `WRN_SQ5_MARK_FOR_YOU_DROP_01`: "At your feet. Take."
- `WRN_SQ5_MARK_RESUME_01`: "Back to it."
- `WRN_SQ5_MARK_RESUME_02`: "Again. Back to it."
- `WRN_SQ5_MARK_CANT_01`: "No. Cannot."
- `WRN_SQ5_MARK_CANT_OWNED_01`: "I have it."
- `WRN_SQ5_MARK_CANT_POWER_01`: "No power."
- `WRN_SQ5_MARK_CANT_CAP_01`: "No more bottles."
- `WRN_SQ5_MARK_CANT_REACH_01`: "No way there."
- `WRN_SQ5_MARK_CANT_FULL_01`: "My guns are better. No."

### 19.5 Jakub (`JAK`)
- `JAK_SQ5_MARK_ACK_01`: "Yes. I go."
- `JAK_SQ5_MARK_ACK_GO_01`: "I'll go there. Slowly."
- `JAK_SQ5_MARK_ACK_DEFEND_01`: "I'll stand there and keep them back."
- `JAK_SQ5_MARK_ACK_REGROUP_01`: "I'm coming. Wait for me."
- `JAK_SQ5_MARK_DANGER_01`: "Not there. That place is bad."
- `JAK_SQ5_MARK_DANGER_02`: "Stay away from there. Trust me."
- `JAK_SQ5_MARK_RESUME_01`: "Back to it."
- `JAK_SQ5_MARK_REFUSE_BUY_01`: "I have no Scrip, friend. Only coal dust in my pockets."
- `JAK_SQ5_MARK_REFUSE_BUY_02`: "I can't buy anything. They paid us in nothing, down there."
- `JAK_SQ5_MARK_CANT_REACH_01`: "I can't get there. Show me another way."
- `JAK_SQ5_MARK_CANT_01`: "I can't do that. I'm sorry."


## 20. Perk upgrades, the maker's plates and the Crucible's plate (Update 04, DECISIONS T-075)

`PERK_TIER`: a survivor's first perk upgrade of the match (tier II or III brewed at a machine they already drank from;
PerkManager.set_tier, say_as, forced). `PERK_PROC`: the first time a tier effect fires for them in a match (iron skin,
a dodge, a revive window, a blast heal). `PLAQUE`: the first maker's plate they read on a map; `PLAQUE_CRUCIBLE`: the
Crucible's brass plate (MachineLore). The Operator: `PERK_TIER2` / `PERK_TIER3` on the match's first tier II / III
("the loyalty measure", PERKS_LORE.md section 1.4); `CRUCIBLE_FIRST` gains two variants. Writer rules hold: nobody
learns what a plan or a patent is. The ids carry `SQ6` so the bake can run them alone
(`python gravelight/tools_src/gen_vo.py --only=SQ6`). Unbaked until the orchestrator's TTS bake: they play as subtitles.

**Operator (`OPR`)**
- `OPR_SQ6_PERK_TIER2_01`: "Oh, a returning customer! Helvetia Automaten is pleased to offer you the {loyalty measure}."
- `OPR_SQ6_PERK_TIER2_02`: "A second glass! The cabinet remembers you. It remembers {everyone}."
- `OPR_SQ6_PERK_TIER3_01`: "The regulars' measure! Ladies and gentlemen, we have a {valued} customer."
- `OPR_SQ6_PERK_TIER3_02`: "Third chamber, opened just for you. Do drink {responsibly}. Or don't. We'll know."
- `OPR_SQ6_CRUCIBLE_FIRST_01`: "The furnace is lit! Patent pending, and pending, and {pending}."
- `OPR_SQ6_CRUCIBLE_FIRST_02`: "Our cooling plant is open for business! It has never cooled {anything}."

**Dutch (`DUT`)**
- `DUT_SQ6_PERK_TIER_01`: "Second helping. Tastes worse. Works better. That's the Army in a bottle."
- `DUT_SQ6_PERK_TIER_02`: "The machine gave me the strong stuff. I don't like that it knew I was ready."
- `DUT_SQ6_PERK_PROC_01`: "Whoa. That should've put me down."
- `DUT_SQ6_PLAQUE_01`: "Made in Basel. Neutral country. Sure."
- `DUT_SQ6_PLAQUE_CRUCIBLE_01`: "Patent pending. Somebody's paying a lawyer for this thing."

**Peg (`PEG`)**
- `PEG_SQ6_PERK_TIER_01`: "A stronger measure. London will want a sample of this. London wants a sample of everything."
- `PEG_SQ6_PERK_TIER_02`: "Interlocks on a drinks cabinet. Somebody planned for us coming back."
- `PEG_SQ6_PERK_PROC_01`: "Didn't feel that. I'm choosing not to think about why."
- `PEG_SQ6_PLAQUE_01`: "Replacement unit. They had spares. Of course they had spares."
- `PEG_SQ6_PLAQUE_CRUCIBLE_01`: "Crate two of three. So where's the third?"

**Deacon (`DEA`)**
- `DEA_SQ6_PERK_TIER_01`: "Second chamber behind the first. Clever plumbing. Hate it."
- `DEA_SQ6_PERK_TIER_02`: "It read my hand before it poured. Machine shouldn't do that."
- `DEA_SQ6_PERK_PROC_01`: "Lord. Something in me just held."
- `DEA_SQ6_PLAQUE_01`: "Swiss rivets. Good work on a bad job."
- `DEA_SQ6_PLAQUE_CRUCIBLE_01`: "Mod. R-E. Pat. pend. Somebody's waiting on a patent for this thing. Hope they never get it."

**Wren (`WRN`)**
- `WRN_SQ6_PERK_TIER_01`: "More. It always wants you to have more."
- `WRN_SQ6_PERK_TIER_02`: "The owl on the glass. Somebody here was on our side."
- `WRN_SQ6_PERK_PROC_01`: "Not yet. Not today."
- `WRN_SQ6_PLAQUE_01`: "They wrote down who made it. They never write down who it was made from."
- `WRN_SQ6_PLAQUE_CRUCIBLE_01`: "A furnace that teaches guns. Of course they built that before bread."

**Jakub (`JAK`)** (he never drinks; the plates only)
- `JAK_SQ6_PLAQUE_01`: "We carried these down the ladder. Twelve men to a cabinet. Two did not come back up."
- `JAK_SQ6_PLAQUE_CRUCIBLE_01`: "The cooling plant. We were told never to look inside it."

## 21. Map 0's round 1 opening: the bar empties (DECISIONS T-072)

Played by `InnOpening` (`gravelight/world/inn_opening/inn_opening.gd`, data `data/gravelight/map00_opening.json`, which
holds each line's time and speaker). Local on every peer, positional at the patron when baked; the subtitle shows the
patron's name. **Not baked yet** (audio_manifest "missing"): new speakers for the bake, one voice each.

**Who they are.** Nobody signed the guest book (they took no rooms; it stays true that the last guests left on the
20th): folk off the shut road who came in out of the snow on the 23rd. Anselm, Lene and Käthe Vogt are not among
them (their fates stay [OPEN]).
- `ROT` **Ewald Rother**, an old salt carter; his snowed-in cart is in the yard. Gruff, kind.
- `KUB` **Franz Kubiak**, his younger mate. Quick, frightened, brave too late.
- `POH` **Frau Agnes Pohl**, a widow walking to her sister's in Liegnitz. Prim; screams once, then runs.
- `TRU` **Trudi Hanke**, a farmer's daughter from Wilcza Góra who helps Frau Vogt at the bar. Practical, loud.
- `SOB` **Gefreiter Willi Sobotta**, a lance-corporal on Christmas leave walking home to Wilcza Góra, unarmed; the
  parcel on the bar is for his mother. He holds the door, shuts it on Rother to save the room, and is bitten.

Escapes: Trudi and Frau Pohl run up the road into the dark (their fate is open). Rother and Kubiak are caught on the
snow; Sobotta dies inside by the table and rises among the squad.

**Intro** (before round 1, as the squad comes in):
- `ROT_INN_ARRIVE_01`: "Mother of God, look at them. Out of that plane? ...Sit, sit, before you fall down. Trudi, coffee for these."
- `TRU_INN_ARRIVE_01`: "There's soup on the hearth. Get warm first. Then you can tell us what fell out of the sky."

**Round 1 starts** (the windows):
- `POH_INN_SCREAM_01`: "[a scream] At the window! There are people out in the snow, and they're walking. Look at them walking!"
- `KUB_INN_WINDOW_01`: "What was that? ...Something's at the boards. Something's tearing at the boards!"
- `TRU_INN_FLEE_01`: "The front door! Out, all of you, out and up the road to the village!"
- `SOB_INN_FLEE_01`: "Stay together! Keep together and run, don't stop for anything!"
- `ROT_INN_DOOR_01`: "The bar's frozen in the brackets... help me, help me with it... there!"
- `KUB_INN_CAUGHT_01`: "[screaming] Get off me! Get it off! Ewald! Ewald!"
- `ROT_INN_CAUGHT_01`: "[screaming] Willi! The door, Willi, pull me in!"
- `SOB_INN_SHUT_01`: "I can't... God forgive me. ...The bar! The bar, get it down!"
- `SOB_INN_BITTEN_01`: "It bit me. It's nothing. It's only a scratch, it's... it's nothing."
- `SOB_INN_FALL_01`: "[weak] Tell my mother... I was nearly home. Nearly home."

**`INN_RISE`**: the squad, when Sobotta gets up off the floor (one random standing survivor, tier 2).
- `DUT_INN_RISE_01`: "He's getting up. ...He's getting up! That's not him any more, put him down!"
- `PEG_INN_RISE_01`: "Oh, no. No, no, no. Willi. ...I'm sorry, love."
- `DEA_INN_RISE_01`: "Lord have mercy, the boy's standing up. That isn't him. That isn't him!"
- `WRN_INN_RISE_01`: "The soldier. He is standing. Do not look at his face. Shoot."
