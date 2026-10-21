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
| `gl.map03.opr.refuse.01` | Map 3 **Refuse** ending, last Operator line (LORE.md §9.3) | *[unspliced, slowing]* Cancellation... cannot be... {processed}— *[the station goes off the air]* |

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
