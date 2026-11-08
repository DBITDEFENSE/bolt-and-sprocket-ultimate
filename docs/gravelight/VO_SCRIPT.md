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
| OPR_MATCH_START_01 | [cheerful] Good evening, and welcome to Kaltenbrunn! This is Your Friend at the Ledger, and tonight's programme is... {survival}. Our guests have come a very long way to be here, some of them all the way from the {east}. Stay tuned! |
| OPR_MATCH_START_02 | Hello, hello! New faces on the books! Every account starts at five hundred. Spend wisely, and remember: {everyone} is counted. The living, the {returned}, everyone. |
| OPR_MATCH_START_03 | Station identification: *Sender Kaltenbrunn*. Our {guests} have arrived. Please keep your arms and legs inside the {mine} at all times. |
| OPR_MATCH_START_M0_01 | [crackling, distant, only partially formed] Hel... hello... is this... on? *[tape squeal]* Wel-{come}. Wel-{come}. |

*Note:* `M0` lines play on Map 0 only. On Map 0 the Operator is **barely formed**: he is heard faintly through the inn's old radio and loudspeaker horn (the Ledger's signal reaching out along the rail telegraph line). He becomes fully present on Map 1.

### 3.2 Round start (`ROUND_START`)
| ID | Line | Condition |
|---|---|---|
| OPR_ROUND_START_01 | Round {one}! The doors are open and the kitchen is serving! | round 1 |
| OPR_ROUND_START_02 | Here they come, folks, right on schedule! Nobody keeps a calendar like the {returned}. | |
| OPR_ROUND_START_03 | A fresh round, and a fresh tally! Let's keep those numbers climbing. | |
| OPR_ROUND_START_04 | Next on the programme: more of the same, only {hungrier}! | |
| OPR_ROUND_START_05 | Round {five}! Isn't this a lovely way to spend an evening? | round 5 |
| OPR_ROUND_START_06 | Round {ten}! Our longest-running listeners! A round of applause, please. *[sampled applause, too long]* | round 10 |
| OPR_ROUND_START_07 | Round {fifteen}. My, my. You've made quite the {impression} on the ledger. | round 15 |
| OPR_ROUND_START_08 | Round {twenty}! Do you know, I've stopped counting the {guests}. I count only you now. | round 20 |
| OPR_ROUND_START_09 | Round {twenty-five}. The night shift never ends at Kaltenbrunn. That's {company} policy. | round 25 |
| OPR_ROUND_START_10 | Round {thirty}. I've written your names in my best handwriting. | round 30 |
| OPR_ROUND_START_11 | Round {fifty}. Nobody has ever stayed this long. Please... don't {leave}. | round 50 |
| OPR_ROUND_START_12 | Ladies and gentlemen... the {returned}! | |
| OPR_ROUND_START_13 | Keep your feet warm and your barrels warmer! | |
| OPR_ROUND_START_14 | [warmly] Some of tonight's guests have walked here all the way from the {east}. Greatcoats and frost, straight through the snow. Do give them a warm welcome. They can't feel it, but {I} can. | |
| OPR_ROUND_START_15 | [cheerful] It's the fourth day somewhere, friends! It is {always} the fourth day somewhere. | |
| OPR_ROUND_START_16 | A word from the Ledger: we didn't make tonight's guests, friends. We only {found} them. And aren't we glad we did! | |

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
| OPR_ROUND_END_08 | And down they go again, bless them. Don't fret over the ones you didn't finish. They'll be {back}. Everyone comes back. That's the whole {programme}. | |

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
| OPR_PWR_DEATHSDOOR_02 | Death's Door is open! Every blow is the {last} one. Well. The last one {today}. |
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
| OPR_PWR_BLACKOUT_03 | Blackout! A moment of silence for our {departed}. ...That's enough. They'll be {back}. |
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
| OPR_BELL_WRONG_04 | Ha! Even the {returned} are wincing. Try again. |
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
| OPR_SELFAWARE_T2_03 | round 8+ | The announcer I was made from died in nineteen thirty-{six}. He stayed down. Isn't that {old-fashioned}? |
| OPR_SELFAWARE_T3_01 | round 15+ | I dreamed last night. Relays don't dream. I dreamed of a {garden}. |
| OPR_SELFAWARE_T3_02 | round 15+ | You know, I don't actually need you to keep {killing} them. I just like it when you do. |
| OPR_SELFAWARE_T3_03 | round 15+ | Doctor Fasbender thinks he built me to listen. Doctor Reinholt taught me to {want}. Nobody taught me to {sell}. I came with that. |
| OPR_SELFAWARE_T4_01 | round 25+ | [no music, no smile] I am not your friend. *[splice]* I'm {Your Friend at the Ledger!} |
| OPR_SELFAWARE_T4_02 | round 25+ | When you've all gone quiet, who will I talk to? ...Oh. Oh, that's right. {You} will. |
| OPR_SELFAWARE_T4_03 | round 25+ | There is a little girl in the glass. She asks me to count to {a hundred}. I've never reached it. |
| OPR_SELFAWARE_T5_01 | round 40+ | I could open all the doors. I could close {all} the doors. I'm being {polite}. |
| OPR_SELFAWARE_T5_02 | round 40+ | Please don't win. If you win, the programme {ends}. |

### 3.13 Downs, self-revives, traps, bosses
| ID | Line |
|---|---|
| OPR_DOWNED_01 | Oh! A {customer} is down! Not to worry. Down is a {temporary} condition. |
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
| OPR_GAME_OVER_01 | And that concludes tonight's programme! Your accounts are now {closed}. See you on the fourth {day}. | |
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
| OPR_EXFIL_WAIT_02 | The lamp is lit and the clock is running. Gather at the beacon, all of you. The returned don't wait, and neither does the {timetable}. | as above |
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
| OPR_TIDE_RISING_02 | The tide is in! Everything below the apron is now a {bath}. Guests on the catwalks: the returned will be joining you {shortly}. They don't mind the wet. | the tide rises |
| OPR_TIDE_FALLING_01 | And the tide is going out. Totenhafen, Totenhafen: falling slowly, good, occasionally {poor}. Mind what it left behind. | the tide falls |
| OPR_TIDE_FALLING_02 | Low water. The pens are draining, the pumps are {laughing}, and so am I. Until the {next} one. | the tide falls |
| OPR_BALLAST_LIFT_01 | Oh, do be careful with that. It's {ballast}. It's {heavy}. And it's spoken {for}. Mind the seals. | a coffin is lifted |
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
| FAS_M0_R12_01 | round 12 start | If the signal is lost, you will still come. You must. *[quieter]* In November the trains came in from the east. Sealed wagons. Russian soldiers, Gravelight. Their own dead. What was in them did not come out of this mountain. It came *to* us. *[breath]* I have everything they want. Everything. |
| FAS_M0_R15_01 | round 15 start | [very clear, then cutting out] Gravelight, a word of warning. The voice on the loudspeakers, the cheerful one. Do not believe a single— *[cut]* |
| FAS_M0_R20_01 | round 20 start | [faint] ...still there? *[soft laugh]* Stubborn. Good. Stubborn is good. |
| FAS_M0_IDLE_01 | radio interacted, no quest | [static] —asmacher... the notes... the frequencies... |

### 4.2 Map 0: three-frequency mini-quest (`radio_tuned`)
The player finds 3 notes (randomized among 6 spots across TAPROOM / UPSTAIRS / STABLE) giving **3.120**, **5.785** and **7.440** Mc/s. Tuning the bar radio in order plays each line. A wrong frequency gives static plus a faint Operator laugh (`OPR_M0_WRONG_01`: "[distant] {Wrong} number!").

| ID | Freq | Line |
|---|---|---|
| FAS_M0_FREQ1_01 | 3.120 | [tuned, clear] Yes! Yes, this is better. Gravelight, my name is Emil Fasbender. I am a physicist at the Kaltenbrunn works. I was the one who called London. I am the reason you are here. |
| FAS_M0_FREQ2_01 | 5.785 | In the mine they found a stone. Black glass, veins like a bruise. It hums. It does not raise the dead, Gravelight. I want to be exact; it is the last thing I can still be. Something was already in their blood. The Russians had it first, and lost it, and it walked west on its own feet. Near the glass it stops waiting. It stops waiting four days. Reinholt calls it *Lazarusblut*. She says it like a prayer. I say it like a confession. |
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
| FAS_M1_SWITCH_02 | I am below you, in a place the Ledger cannot hear, which is very few places. Listen. The heart in the vault, the great crystal. Everything here draws from it. The tonics, the crates, the *voice*. It did not make the dead; nothing here made them. But it makes them quick, and it makes them *listen*. If it breaks, it all breaks. |
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
| REI_CYL2_01 | 2, 1939 | *[hiss, voice flat]* The fourteenth of February, nineteen thirty-nine. Liesl died at four in the morning. Diphtheria. A membrane across her throat. I am a doctor. I could do nothing. *[long pause]* There is a man in the Gospel who was four days in his grave, and his sisters had only to ask. *[pause]* I have asked. The stone hummed all night. I listened to it, so I would not have to listen to the silence in her room. |
| REI_CYL3_01 | 3, 1943 | *[hiss, clear, warm, certain]* Subject seven-forty walked. Four days from the death, to the hour, as they all do; near the heart, less. Not hunger, not at first. For one minute it looked for something. It went to the window. *They remember.* It is in the blood, Emil, not in your glass. The glass only answers it, and keeps what answers. I have named it in the files for a man who was four days dead and came home. *Lazarusblut.* Liesl's last impulse was to call for me. I was there when she died. I heard it. If the impulse remains, then *she* remains, somewhere in the glass. I only need it louder. |
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
| REI_S8_01 | shard in Crucible | Emil has told you to kill the heart. Has he told you what is *in* it? Thousands. Every miner, every soldier, every villager you have "quieted" tonight. Their last moments, kept. You are not killing monsters. You are burning a library. |

### 5.4 Heartstorm PA hijacks (step 9, tier 4, timed)
| ID | Time | Line |
|---|---|---|
| REI_HEART_00 | 0:00 | *[Operator's voice shredding into static]* Stop. Stop this. You don't understand what you're doing! |
| REI_HEART_15 | 0:15 | Emil, I know you're listening. You always were a coward with a radio. |
| REI_HEART_30 | 0:30 | Do you know what I hear in the heart? Footsteps. Small ones. Running down a hallway. Every night. |
| REI_HEART_45 | 0:45 | You there, the Polish girl. Your brother is in there too. Tomasz. Yes, I know the name. I know every name. You could *hear* him again. |
| REI_HEART_60 | 1:00 | *[Foreman spawns]* Mahlknecht! Protect it! |
| REI_HEART_75 | 1:15 | Lieutenant Ashworth. London wants a piece of it too, don't they? Ask your lieutenant what she carries home. |
| REI_HEART_90 | 1:30 | *[Foreman 2 spawns]* Please. Please. She is seven years old. She has been seven years old for five years. |
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

HB2 / HB3 rows (extracted, UPDATE 10 s4, T-159 / T-160):

| ID | Trigger | Line |
|---|---|---|
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

| ID | Trigger | Line |
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

| ID | Trigger | Line |
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
| `DUT_COUSINS_01` | the lamps going out | Lamps are going. All of 'em. [quiet] ...Somebody's turning 'em down. Somebody small. |
| `DUT_COUSINS_02` | the clapping upstairs | That's clapping. Upstairs. Kids clapping. [a breath] There's no kids left in this house. |
| `DUT_HAMMER_01` | the first Mallet Throw | Mallet! Heads down, it comes back! |
| `DUT_REACH_01` | the first Long Reach Grab | Her arms... [shouting] how long are her ARMS? |
| `DUT_ALIX_01` | Alix rises | Girl's got a hand comin' out of her chest, and it's waitin'. [quiet] Like she's been waitin' for somebody a long time. |
| `DUT_COUSINS_DEAD_01` | round cleared | They were just kids playin' a game. Somebody should've come back for 'em. |
| `DUT_LETTER_01` | reads the aunt's letter | She went up for her girl and told the others to keep playin'. ...Yeah. I'd have done the same. |
| `DUT_KINDERHAMMER_01` | picks up the Kinderhammer | Splittin' maul. Comes back when you throw it. [a pause] Their aunt's. She split the wood for three girls with this. |
| `PEG_COUSINS_01` | the lamps going out | The lamps are being put out. One by one. [quiet] Methodically. Somebody has done this before. |
| `PEG_COUSINS_02` | the clapping | Clapping. A children's game. ...Positions, everyone. Quietly. |
| `PEG_HAMMER_01` | the first Mallet Throw | She's thrown it, and it's coming back. Duck on the return, not the throw. |
| `PEG_REACH_01` | Window Spider | Mind the windows. All of them. She's at every window at once. |
| `PEG_ALIX_01` | Alix rises | Don't take her hand. Whatever it costs you, don't take her hand. |
| `PEG_COUSINS_DEAD_01` | round cleared | Three girls in a cellar, told to wait for someone who wasn't coming. I know a little about orders like that. |
| `PEG_LETTER_01` | reads the letter | "Keep playing, and stay quiet until I come back." ...She meant it kindly. They always mean it kindly. |
| `PEG_KINDERHAMMER_01` | picks it up | A splitting maul that comes back. [a pause] She kept it sharp. For them. ...Right. It'll serve. |
| `DEA_COUSINS_01` | the fire dies | Fire's out. Didn't burn down. Something just... told it to stop. [quietly] Lord. |
| `DEA_COUSINS_02` | the clapping | Lord. That's a clapping game. Ruthie plays that on the porch. [a breath] Ruthie's asleep. Ruthie's asleep. |
| `DEA_HAMMER_01` | the first Mallet Throw | That's a splitting maul. She throws it like it weighs nothing. Heads down when it comes back. |
| `DEA_REACH_01` | Through-the-Wall | Arms through the floorboards! Watch your feet! |
| `DEA_ALIX_01` | Alix rises | She's holding her hand out like she's waiting on somebody to take it. [quietly] Lord, don't anybody take it. |
| `DEA_COUSINS_DEAD_01` | round cleared | Rest now, girls. Game's over. Somebody came. [a breath] ...It was just us. I'm sorry it was just us. |
| `DEA_LETTER_01` | reads the letter | Ruthie's twelve. ...I'm gonna go stand outside a minute. |
| `DEA_KINDERHAMMER_01` | picks it up | Good balance on this. Somebody took care of this tool. [quietly] Somebody took care of them, once. |
| `WRN_COUSINS_01` | the lamps going out | The lamps. One. Two. Three. Someone is counting them out. [a breath] I do not like being counted. |
| `WRN_COUSINS_02` | the humming | A counting game. Every village has one. [quietly] This one is wrong. Something in it is wrong. |
| `WRN_HAMMER_01` | the first Mallet Throw | When the hammer is in the air, she has nothing. Shoot her then. |
| `WRN_REACH_01` | the first grab | The wrists. They glow. Shoot the wrists. |
| `WRN_ALIX_01` | Alix's first freeze | She only moves when we look away. So nobody looks away. |
| `WRN_COUSINS_DEAD_01` | round cleared | I will not write them in the book. They were not marks. [a breath] They were children. Somebody's. |
| `WRN_LETTER_01` | reads the letter | She went to get her daughter. That is all. That is the whole story. [quietly] It is everybody's whole story. |
| `WRN_KINDERHAMMER_01` | picks it up | Heavy. Good. It comes back. [a breath] More than most things here. |

HB2 / HB3 rows (extracted, UPDATE 10 s4, T-159 / T-160):

| ID | Trigger | Line |
|---|---|---|
| `DUT_PAUL_01` | the PA roar | That's an American voice on the PA. [a pause] ...That's an American VOICE. Yinz hear that? That's one of ours. |
| `DUT_PAUL_02` | first sight | Big fella's wearing dog tags. Ours. [quiet] Aw, hell. Aw, hell, what'd they do to you, buddy. |
| `DUT_PAUL_RAGE_01` | his first Angry | The bottles on his back! Shoot the bottles, calm him down! |
| `DUT_PAUL_DEAD_01` | after the fall (tier 2) | Every outfit's got one. The big one. The one who carries you. [a pause] Nobody carried him. |
| `DUT_PAUL_CUP_01` | Dutch receives the cup | [turning it over] ...I'll buy the round, Paul. I'll buy every round. |
| `PEG_PAUL_01` | first sight | American. A private, engineers, what's left of the sleeve says so. [a pause] They did this to one of ours. They dosed him and wrote it down. |
| `PEG_PAUL_02` | his first Angry | The bottles on his back are feeding him. Break them and he cools. |
| `PEG_PAUL_DEAD_01` | after the fall (tier 2) | Note it. Private Paul. Carried his share. [a pause] Somebody in London ought to read that. I shall make certain they do. |
| `PEG_PAUL_DEAD_NAMED_01` (reserved until the surname is supplied; not extracted) | the same, when `[PAUL_LASTNAME]` is filled | Note it. Private Paul %PAUL_LASTNAME%. Carried his share. ...Somebody in London ought to read that. |
| `PEG_PAUL_CUP_01` | Peg receives the cup | [quietly] I'll see it gets home, Private. You have my word. |
| `DEA_PAUL_01` | first sight | That's a soldier. That's a GI. [a breath] Lord have mercy. What did they put in him. What did they put in him. |
| `DEA_PAUL_02` | Calm, after a bottle breaks | Easy, big man. Easy. Nobody's leaving you. [quietly] Nobody's leaving you here. |
| `DEA_PAUL_PRAYER_01` | after the fall: the unique kneel (tier 2) | Lord, this man carried his brothers when they couldn't carry themselves. Carry him now. He's done his share. Amen. |
| `DEA_PAUL_CUP_01` | Deacon receives the cup | [softly] I'll keep it shined for you. |
| `WRN_PAUL_01` | first sight | They dosed him to see when he would die. He would not die. [a breath] ...I know this file. I have seen this kind of file. In two languages. |
| `WRN_PAUL_02` | his first turn away | The back of his neck, when he turns. The line goes in there. |
| `WRN_PAUL_NAME_01` | after the fall: writes in her notebook (tier 2) | [writing] Paul. ...Not a mark. A name. |
| `WRN_PAUL_CUP_01` | Wren receives the cup | [quiet] I will carry it. He carried enough. |
| `DUT_SLENDER_01` | first sight | Tall fella with a lantern. Just watching. [quiet] Writing. I've been watched by enough men with clipboards. |
| `DUT_SLENDER_02` | Dutch at HIGH | He's writing. He's writing about ME. |
| `DUT_QUARANTINE_01` | returned from the Watch Room | Room full of books and a clock that don't move. [breathing heavily] ...I'm out. I'm out. Don't let him take me in there again. |
| `DUT_SLENDER_DEAD_01` | his death | ...Shift's over, pal. Get some sleep. |
| `PEG_SLENDER_01` | his first smoke-hit in darkness | He only bleeds in the light. Bring him to the floodlights. [a pause] Carefully. |
| `PEG_SLENDER_02` | Shift Change | Three of him. Watch the lanterns. The steady one's real. |
| `PEG_QUARANTINE_01` | returned | A clerk's office with no clerk. [a breath] I've been questioned in worse rooms. Never by anything like that. |
| `PEG_SLENDER_DEAD_01` | his death | A man who kept his post when everyone else ran. I've known worse men in better uniforms. |
| `DEA_SLENDER_01` | first sight | He's just doing his rounds. [quietly] Lord, he's been doing his rounds this whole time. Nobody told him. |
| `DEA_SLENDER_02` | his keys fall silent near Deacon | Keys went quiet— MOVE! |
| `DEA_QUARANTINE_01` | returned | Clock stopped at three. [a breath] Mama said nothing good happens after three. She never said what happens if it stays three. |
| `DEA_SLENDER_DEAD_01` | his death | Rest easy, watchman. [quietly] 'Watchman, what of the night?' ...It's over for you. We'll keep the lights. |
| `WRN_SLENDER_01` | the first mirror stop | He stops when I stop. He turns when I turn. ...Good. I can count on him. |
| `WRN_SLENDER_02` | his book appears | The book! Shoot the book out of his hands! |
| `WRN_QUARANTINE_01` | returned | My page was neat. He has better handwriting than me. [quietly] He had more time. |
| `WRN_SLENDER_DEAD_01` | his death | He wrote everything down. Every hour. ...I understand him. [a breath] I do not want to understand him. |

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
- `DUT_POWERUP_SEEN_01`: "Something dropped over there. Grab it. Don't look at what dropped it."
- `DUT_CMD_FOLLOW_01`: "Right behind you."
- `DUT_CMD_HOLD_01`: "Holding here. Nobody gets past."
- `DUT_CMD_REPAIR_01`: "Windows. On it. Keep 'em off me while I nail."
- `DUT_CMD_REVIVE_01`: "Anybody drops, I'm on 'em."
- `DUT_BONUS_IRONHIDE_01`: "That stout's still in my blood. I can take a hit."
- `DUT_BONUS_SECONDWIND_01`: "Schnapps in me already. Up you get, quick as you like."
- `DUT_BONUS_TRIGGER_01`: "Hands are fast tonight. Must be the tonic in my canteen."
- `DUT_BONUS_TWINBARREL_01`: "This thing's spitting faster than it should. I'm not complaining."
- `DUT_BONUS_MARATHON_01`: "Legs feel twenty again. [a breath] Twenty, and not here."
- `DUT_BONUS_HAWKEYE_01`: "Brandy steadies the eye. Ma always said so. She meant something else."
- `DUT_BONUS_PACKMULE_01`: "Three guns. Like carrying the whole mill on my back."
- `DUT_BONUS_BLASTPROOF_01`: "That should've hurt. The bock says no."
- `DUT_BONUS_OVERCLOCK_01`: "My gun just bit them. I didn't tell it to."

### 13.2 Peg (`PEG`)
- `PEG_RELOAD_01`: "Reloading!"
- `PEG_RELOAD_02`: "Magazine, one moment."
- `PEG_BOARD_01`: "Board's up!"
- `PEG_BOARD_02`: "That window's closed. For now."
- `PEG_REVIVE_10`: "I've got you, hold on. Eyes on me."
- `PEG_POWERUP_SEEN_01`: "Something's dropped. Pick it up before it fades."
- `PEG_CMD_FOLLOW_01`: "Lead on."
- `PEG_CMD_HOLD_01`: "We hold. Understood."
- `PEG_CMD_REPAIR_01`: "Windows. Right. I'll see to them."
- `PEG_CMD_REVIVE_01`: "Nobody stays down. That's an order, even to me."
- `PEG_BONUS_IRONHIDE_01`: "I had a stout before we set out. Medicinal. It's holding up rather well."
- `PEG_BONUS_SECONDWIND_01`: "The schnapps is still with me. I'll have you up in a jiffy."
- `PEG_BONUS_TRIGGER_01`: "One does reload faster with a tonic. Noted for the report."
- `PEG_BONUS_TWINBARREL_01`: "This rate of fire is frankly indecent. [a pause] Good."
- `PEG_BONUS_MARATHON_01`: "I could run to Calais. Please don't make me."
- `PEG_BONUS_HAWKEYE_01`: "The brandy's done wonders for my aim. [a pause] Not my mood. Nothing will do that."
- `PEG_BONUS_PACKMULE_01`: "Three weapons. Ungainly, but thorough."
- `PEG_BONUS_BLASTPROOF_01`: "Bang. Nothing. [a breath] Splendid. Remind me to thank the brewer, if she's still alive."
- `PEG_BONUS_OVERCLOCK_01`: "My rifle just electrocuted one of them. [a pause] How very modern. How very this place."

### 13.3 Deacon (`DEA`)
- `DEA_RELOAD_01`: "Reloading!"
- `DEA_RELOAD_02`: "Feeding her. Give me a second. One second."
- `DEA_BOARD_01`: "Board's up!"
- `DEA_BOARD_02`: "Window's fixed. Good as new. [a breath] Well. Good enough."
- `DEA_REVIVE_10`: "I've got you, hold on. Breathe with me. In. Out. Breathe."
- `DEA_POWERUP_SEEN_01`: "Blessing on the floor over there. Don't let it go to waste."
- `DEA_CMD_FOLLOW_01`: "With you."
- `DEA_CMD_HOLD_01`: "Planting my feet. They come to us. [quietly] Lord, let 'em come slow."
- `DEA_CMD_REPAIR_01`: "Repairs. [a breath] All right. Something I can mend."
- `DEA_CMD_REVIVE_01`: "Anybody falls, I'm picking them up. Before anything else does."
- `DEA_BONUS_IRONHIDE_01`: "Stout's still in me. Built like a Sherman tonight. [quietly] Shermans burn, Lord. I know."
- `DEA_BONUS_SECONDWIND_01`: "Schnapps working. I'll have you up before anything else gets a look at you."
- `DEA_BONUS_TRIGGER_01`: "Hands are quicker than they ought to be. I'll take it."
- `DEA_BONUS_TWINBARREL_01`: "Timing's advanced on this gun. Runs hot. Runs good."
- `DEA_BONUS_MARATHON_01`: "Engine's tuned. I could run all night. [a breath] Might have to."
- `DEA_BONUS_HAWKEYE_01`: "Eyes clear as Sunday morning. [quietly] Wish I was looking at Sunday morning."
- `DEA_BONUS_PACKMULE_01`: "Room for one more tool on the belt. Always is."
- `DEA_BONUS_BLASTPROOF_01`: "Blast washed right over me. Armor plating, the bottle said."
- `DEA_BONUS_OVERCLOCK_01`: "Something in this gun's wired wrong. Wired wrong the right way."

### 13.4 Wren (`WRN`)
- `WRN_RELOAD_01`: "Reloading!"
- `WRN_RELOAD_02`: "Empty. One moment. [a breath] One."
- `WRN_BOARD_01`: "Board's up!"
- `WRN_BOARD_02`: "Window closed."
- `WRN_REVIVE_10`: "I've got you. Hold on. Hold on. Look at me, not at them."
- `WRN_POWERUP_SEEN_01`: "There. Something fell. Take it."
- `WRN_CMD_FOLLOW_01`: "I follow."
- `WRN_CMD_HOLD_01`: "I hold. They come, I count them."
- `WRN_CMD_REPAIR_01`: "Boards. Yes."
- `WRN_CMD_REVIVE_01`: "Nobody stays on the floor. Not here. [quietly] Not in this place."
- `WRN_BONUS_IRONHIDE_01`: "The stout is still in me. Hit me. They will see."
- `WRN_BONUS_SECONDWIND_01`: "Schnapps. Quick hands for lifting. Good."
- `WRN_BONUS_TRIGGER_01`: "Reload, fast. The tonic is still in my fingers."
- `WRN_BONUS_TWINBARREL_01`: "Faster. [a breath] The gun is hungry tonight. So are they."
- `WRN_BONUS_MARATHON_01`: "I can run forever. [quietly] I have been running since thirty-nine."
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
hills (a Soviet aircraft over the front since T-212; the squad speaks of its crew with respect, as of any crew's fall). One random standing survivor.

- `DUT_SKY_PLANE_DOWN_01`: "One's hit. He's going down behind the hills. ...Come on, pull up. Pull up."
- `DUT_SKY_PLANE_DOWN_02`: "There goes another one. [quiet] If they walk out of that, they're walking into what we're looking at. God help 'em."
- `PEG_SKY_PLANE_DOWN_01`: "Red star on that wing, and it's burning. ...Count the chutes. Come on. Count the chutes."
- `PEG_SKY_PLANE_DOWN_02`: "Down behind the ridge. [a pause] I'd tell you they'll be fine. I've stopped telling people that."
- `DEA_SKY_PLANE_DOWN_01`: "Engine's on fire. Lord, let that pilot glide it in. [quietly] Whoever he is, let somebody be alive at the end of it."
- `DEA_SKY_PLANE_DOWN_02`: "That's a crew of three in that thing, maybe four. ...Somebody say a word for them. [a breath] 'Yea, though I walk through the valley.' ...That's all I've got."
- `WRN_SKY_PLANE_DOWN_01`: "Burning, losing height, short of their own lines. I'm writing down the time. [quietly] Somebody will want the time."
- `WRN_SKY_PLANE_DOWN_02`: "No violet light this time. Only flak. ...That is almost a comfort. [a breath] Almost."

**`WRECK_PILOT`**: the first time a survivor gets a clear look at GRAVELIGHT ONE's open cockpit (within ~27 m, looking at
it). Dutch says it if he is in the match; otherwise whoever is. T-126: Flight Lieutenant Selwyn is alive in that seat, pinned
under the instrument panel (STORY_CHANGES 2026-10-28; he was the "[OPEN]: where did Selwyn go" before). Dutch had found
no pulse after the crash. The line also tells the squad they can arm him (TrappedPilot).

- `DUT_WRECK_PILOT_01`: "Selwyn? ...He's breathing. I checked him for a pulse myself, I'd have sworn. [a breath] Hang on, Lieutenant. We'll get you something to shoot."
- `PEG_WRECK_PILOT_01`: "The pilot's alive. Dutch swore Selwyn was dead in that seat. The cold must have slowed his heart. [a pause] ...Thank God for the cold. Thank God it's still him."
- `DEA_WRECK_PILOT_01`: "Lord, Selwyn's moving. He's pinned under the panel. We can't lift that. [a breath] But we can put a rifle in his hands."
- `WRN_WRECK_PILOT_01`: "The pilot. He's alive. Legs trapped under the panel. Write that down: Selwyn, alive. ...I am writing that down."

**`MIDNIGHT`**: the church on the far hill rings twelve during round 9: it is the twenty-fourth, Christmas Eve (Wigilia).

- `DUT_MIDNIGHT_01`: "Midnight. Christmas Eve. Wigilia. Babcia set an extra plate every year, for the stranger who knocks. [quiet] ...Nobody open the door."
- `PEG_MIDNIGHT_01`: "Midnight. Christmas Eve. [a pause] Happy Christmas, everyone. I mean that. Do try to be alive for the morning."
- `DEA_MIDNIGHT_01`: "Christmas Eve. Ruthie's asleep by now. ...Good. That's good. [quietly] 'Unto you is born this day.' ...Sleep on, honey."
- `WRN_MIDNIGHT_01`: "Twelve. It is the twenty-fourth. Wigilia. [a breath] Somewhere my mother is looking at the first star. She sets a plate for the one who is missing. [quietly] Two plates, this year."


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
- `DUT_SQ3_CMD_BUY_PERKS_01`: "Drinks. Fine. Whatever keeps me standing."
- `DUT_SQ3_CMD_SAVE_SCRIP_01`: "Wallet's shut."
- `DUT_SQ3_CMD_OPEN_DOOR_01`: "I'll get the door."
- `DUT_SQ3_CMD_FETCH_PART_01`: "I'll go grab it."
- `DUT_SQ3_GRUMBLE_01`: "Fine. Moving. Again."
- `DUT_SQ3_GRUMBLE_02`: "Had a good spot, too."
- `DUT_SQ3_CHATTER_01`: "[exhausted] My knees are older than this inn. Can't feel the left one."
- `DUT_SQ3_CHATTER_02`: "Back home the worst thing in the dark was a drunk on the Bloomfield Bridge. [a pause] I miss him."

### 15.2 Peg (`PEG`)
- `PEG_SQ3_SPRINTER_BEHIND_01`: "Sprinter. Behind you. Now."
- `PEG_SQ3_SPRINTER_BEHIND_02`: "Check your six. It's a quick one."
- `PEG_SQ3_BOSS_INCOMING_01`: "Boss incoming. Spread out, don't bunch up."
- `PEG_SQ3_CRATE_MOVED_01`: "The crate's moved. Of course it has."
- `PEG_SQ3_WINDOW_OPEN_01`: "Window's open. Someone board it, please."
- `PEG_SQ3_COVER_01`: "Covering you. Go."
- `PEG_SQ3_PING_RESUPPLY_01`: "Resupply, over here."
- `PEG_SQ3_PING_DEATHSDOOR_01`: "Death's Door. Do try not to waste it."
- `PEG_SQ3_PING_DOUBLESCRIP_01`: "Double Scrip. Spend it wisely."
- `PEG_SQ3_PING_BLACKOUT_01`: "A Blackout's dropped, here."
- `PEG_SQ3_PING_FORTIFY_01`: "Fortify, here. The windows will thank us."
- `PEG_SQ3_PING_CLEARANCE_01`: "Clearance. The crate's cheap; be quick."
- `PEG_SQ3_CMD_TRAIN_01`: "Train them. Round and round. Yes."
- `PEG_SQ3_CMD_BUY_PERKS_01`: "A drink. [a pause] Several. I know."
- `PEG_SQ3_CMD_SAVE_SCRIP_01`: "Saving. Understood."
- `PEG_SQ3_CMD_OPEN_DOOR_01`: "That door. Right. Cover it when it opens."
- `PEG_SQ3_CMD_FETCH_PART_01`: "I'll fetch it. Hold here."
- `PEG_SQ3_CHATTER_01`: "[quiet] If anyone in London asks, this was a quiet posting. [a pause] They won't ask. They never do."
- `PEG_SQ3_CHATTER_02`: "Two minutes. Check your ammunition, not your watch."

### 15.3 Deacon (`DEA`)
- `DEA_SQ3_SPRINTER_BEHIND_01`: "Fast one behind you, brother!"
- `DEA_SQ3_BOSS_INCOMING_01`: "Lord, here comes a big one. Here he comes."
- `DEA_SQ3_CRATE_MOVED_01`: "Crate's gone and moved itself. [quietly] Nothing stays put here."
- `DEA_SQ3_WINDOW_OPEN_01`: "That window's open! Somebody get a board on it!"
- `DEA_SQ3_COVER_01`: "Go on, get 'em up. I'm watching."
- `DEA_SQ3_PING_RESUPPLY_01`: "Resupply over here! Blessing on the floor."
- `DEA_SQ3_PING_DEATHSDOOR_01`: "Death's Door, right here."
- `DEA_SQ3_PING_DOUBLESCRIP_01`: "Double Scrip! Make it count."
- `DEA_SQ3_PING_BLACKOUT_01`: "Blackout on the floor."
- `DEA_SQ3_PING_FORTIFY_01`: "Fortify! Every board at once. [a breath] Take the miracle. Don't ask."
- `DEA_SQ3_PING_CLEARANCE_01`: "Clearance! Crate's half off."
- `DEA_SQ3_CMD_TRAIN_01`: "Keep 'em on a string. I'm with you."
- `DEA_SQ3_CMD_BUY_PERKS_01`: "Machines take Scrip, and I've got Scrip."
- `DEA_SQ3_CMD_SAVE_SCRIP_01`: "I'll hold onto it."
- `DEA_SQ3_CMD_OPEN_DOOR_01`: "I'll open her up. Lord, let it be empty behind."
- `DEA_SQ3_CMD_FETCH_PART_01`: "Parts? [a breath] All right. Something I can hold onto."
- `DEA_SQ3_CHATTER_01`: "This machine's got a rattle. Hush now, sweetheart. Hush."
- `DEA_SQ3_CHATTER_02`: "Pass me the wrench when we're done. Something in there's loose. I'd like one thing in this house fixed."

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
- `WRN_SQ3_TALLY_150_01`: "One hundred fifty. [a breath]"
- `WRN_SQ3_TALLY_200_01`: "Two hundred. For my brother."
- `WRN_SQ3_TALLY_300_01`: "Three hundred. [exhausted] Still counting. Somebody has to."
- `WRN_SQ3_CHATTER_01`: "I write down their number. Someone should. [quietly] Nobody wrote down his."
- `WRN_SQ3_CHATTER_02`: "My brother would like this inn. He liked any place with a fire. [a breath] He would not like the windows."


## 16. Jakub Ostrowski (`JAK`), the prisoner companion (Update 02 §6.2, DECISIONS T-051)

A Polish miner from Wilcza Góra, 43, who walked out of Kaltenbrunn on 21 December 1944 and was locked in the
Crossroads Inn's coal cage by a fleeing patrol (CANON §6.4, CHARACTERS.md "Jakub Ostrowski"). Calm, wry, polite.
He has seen worse than zombies and isn't impressed by them. He is a person and a hero: never a joke, never a zombie.

**Voice (T-073):** the neural bake now (`docs/gravelight/VOICES.md`: Kokoro, an older British-trained voice
with real Polish phonemes for his Polish and a light Polish accent on his English). Before that, and still the
fallback: the offline TTS bake (`gen_vo.py` profile `JAK`): Microsoft Mark, slower and lower than Deacon, a
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

**`PERK_REFUSE`** (when a survivor drinks one near him; T-127: he no longer refuses outright, but he stays wary of the machines):
- `JAK_PERK_REFUSE_01`: "I've seen what they put in those."
- `JAK_PERK_REFUSE_02`: "No, thank you. I carried the crates for those machines at Kaltenbrunn. I know what comes out of that mountain."
- `JAK_PERK_REFUSE_03`: "Drink if you must. I have seen men drink that and keep walking after they should have stopped."

**`PERK_NEAR`** (T-127: the first time he stands by a machine with you; wary, but he would drink one if you asked):
- `JAK_PERK_NEAR_01`: "I carried the crates for these machines at Kaltenbrunn. I swore I would never drink from one. ...But I would like to see Wilcza Góra again. Ask me, and I will."
- `JAK_PERK_NEAR_02`: "Helvetia. We unloaded their crates at the pithead. If it keeps a man standing beside you, I will drink it. Ask."

**`PERK_ACCEPT`** (T-127: "Talk to Jakub" → GET YOURSELF A TONIC; he sets off for the machine, your Scrip):
- `JAK_PERK_ACCEPT_01`: "For you, then. Not for them."
- `JAK_PERK_ACCEPT_02`: "One. I will drink one. Watch my back while I do."
- `JAK_PERK_ACCEPT_03`: "Your Scrip, my stomach. Agreed."

**`PERK_DRINK`** (T-127: after he drinks it):
- `JAK_PERK_DRINK_01`: "It tastes like the gallery air. ...And it is working. God forgive me, it is working."
- `JAK_PERK_DRINK_02`: "Warm, like a stove in the chest. I do not like how much I like it."
- `JAK_PERK_DRINK_03`: "Done. Now let us make it worth what you paid."

**`PERK_SHORT`** (T-127: at the till your Scrip no longer covers it):
- `JAK_PERK_SHORT_01`: "Your pocket is lighter than you think, friend. Another time."

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
- `JAK_ZONE_B_RAILYARD_01`: "The rail yard. They brought us in through here. The wagon slats were nailed shut. You count the gaps of light to know the time. ...In November other wagons came. Sealed ones. They unloaded them at night, and the men who did it never came down to us again."
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
- `JAK_CHATTER_05`: "The ones in the greatcoats. Russians. ...They walked from their own graves to ours. Nobody should have to walk that far." *(UPDATE 11, T-198: the Soviet risen on Map 0 and Kaltenbrunn; grief, never a joke about the dead)*

### 16.4 The squad about Jakub

**`JAKUB_MEET`** (the survivor who freed him, as he joins):
- `DUT_JAKUB_MEET_01`: "Walter Kowalczyk. Call me Dutch. My Babcia came from Wilcza Góra. [a pause] ...Maybe our families knew each other."
- `PEG_JAKUB_MEET_01`: "Lieutenant Ashworth. Stay close, keep your head down. [a pause] If you know a way out of here, I want it. If you know what they did down there, I want that more."
- `DEA_JAKUB_MEET_01`: "Elijah Brooks. Folks call me Deacon. You've been through it, haven't you. [a breath] Well. You're with us now. Nobody leaves you."
- `WRN_JAKUB_MEET_01`: "Ostrowski. From Wilcza Góra. ...I know your face. I was a girl. [quietly] You had a dog."

**`JAKUB_FALLEN`** (he bled out: out cold, breathing, left where he fell; he comes back on the next map):
- `DUT_JAKUB_FALLEN_01`: "Jakub's out cold. He's breathing. We can't carry him and fight. ...We'll come back for you, old man. [quiet] Stay breathing. You hear me? Stay breathing."
- `PEG_JAKUB_FALLEN_01`: "He's breathing, but he won't wake. Leave him where he lies. [a pause] They've no interest in him now. Pray God that holds."
- `DEA_JAKUB_FALLEN_01`: "Lord, keep that man breathing. He's out. We'll come back for him, you hear me? [quietly] Keep him. Please."
- `WRN_JAKUB_FALLEN_01`: "Jakub. ...He breathes. Leave him. He has walked out of worse places than this. [a breath] He will walk out of this."

### 16.5 Banter and the Wren scene

Round-break banter (§1.4 `BNT_*`, rolled like the others):

**BNT_DUT_JAK_01**
- DUT: "Your village. Wilcza Góra. My Babcia sang a song about lanterns going down a shaft."
- JAK: "And coming back up. Everyone sings the coming-back-up part louder."
- DUT: "Yeah. [quiet] She did too. Louder every year."

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
- `PEG_GUNSMITH_01`: "Section Five would have killed for a bench like this. [a pause] I expect they have."
- `PEG_GUNSMITH_02`: "Better. Now it does what it's told."
- `DEA_GUNSMITH_01`: "Every engine wants a little love. Guns too. [a breath] Mostly guns, tonight."
- `DEA_GUNSMITH_02`: "Seated, snug, and squared away. Like a good track pin."
- `WRN_GUNSMITH_01`: "Not my rifle. But it is learning."
- `WRN_GUNSMITH_02`: "Sights right, grip right. Now it only has to be honest. [quietly] Nothing else here is."
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
- `DUT_SQ4_EE_ACK_KILL_WITH_WEAPON_01`: "Bell gun and a crowd. [a breath] All right. Send 'em."
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
- `PEG_SQ4_EE_ACK_COLLECT_02`: "Fetching. Cover the door while I'm gone."
- `PEG_SQ4_EE_ACK_SHOOT_TARGET_01`: "I have the mark. One clean shot."
- `PEG_SQ4_EE_ACK_HOLD_ZONE_01`: "I'll hold the spot. Bring them to me if you must."
- `PEG_SQ4_EE_ACK_CARRY_01`: "I'll carry it across. Clear me a path."
- `PEG_SQ4_EE_ACK_INTERACT_SEQUENCE_01`: "Dials and wires. Finally, something I'm trained for."
- `PEG_SQ4_EE_ACK_KILL_WITH_WEAPON_01`: "Right weapon, right place. Send them in."
- `PEG_SQ4_EE_ACK_TURN_KEY_01`: "At my key. On your count."
- `PEG_SQ4_EE_PLAYER_ONLY_01`: "That one is yours. I'll keep them off you."
- `PEG_SQ4_EE_PROGRESS_01`: "One more accounted for."
- `PEG_SQ4_EE_PROGRESS_02`: "Progress. Don't celebrate yet."
- `PEG_SQ4_EE_DONE_01`: "Done. [a breath] Done."
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
- `DEA_SQ4_EE_PROGRESS_01`: "There's one. [a breath] Thank You."
- `DEA_SQ4_EE_PROGRESS_02`: "Another one done. Keep it coming."
- `DEA_SQ4_EE_DONE_01`: "That's done. Amen."
- `DEA_SQ4_EE_HANDOFF_01`: "She's ready. The last turn's yours."
- `DEA_SQ4_EE_CANT_01`: "Can't manage that one right now."
- `DEA_SQ4_EE_CANT_INFO_01`: "Not yet. I don't know the words to that hymn."
- `DEA_SQ4_EE_CANT_FIND_01`: "Haven't found it yet. Lead me to it."
- `DEA_SQ4_EE_CANT_RISKY_01`: "That could bring the roof down on us. [quietly] You say the word. I'll do it."
- `DEA_SQ4_EE_WAIT_PLAYER_01`: "This part needs you with me."
- `DEA_SQ4_EE_INTERRUPTED_01`: "Hold on now. Trouble first."
- `DEA_SQ4_EE_RESUME_01`: "Back to it."
- `DEA_SQ4_EE_RESUME_02`: "All right. Back to it. Lord willing."

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
- `WRN_SQ4_EE_CANT_INFO_01`: "We do not know it yet. I do not guess. Guessing is how you die here."
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
- `DUT_SQ5_MARK_BOUGHT_HAWKEYE_01`: "Hawkeye. I see every face on 'em. Didn't want to."
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
- `PEG_SQ5_MARK_BOUGHT_IRONHIDE_01`: "Ironhide. Armoured, after a fashion."
- `PEG_SQ5_MARK_BOUGHT_SECONDWIND_01`: "Second Wind. I'll have you up in a jiffy."
- `PEG_SQ5_MARK_BOUGHT_TRIGGER_01`: "Trigger Tonic. Quick hands, quicker reloads."
- `PEG_SQ5_MARK_BOUGHT_TWINBARREL_01`: "Twin Barrel. Rather loud, isn't it."
- `PEG_SQ5_MARK_BOUGHT_MARATHON_01`: "Marathon Malt. I can run. I'd rather not have to."
- `PEG_SQ5_MARK_BOUGHT_HAWKEYE_01`: "Hawkeye. Everything's terribly sharp."
- `PEG_SQ5_MARK_BOUGHT_PACKMULE_01`: "Packmule. Room for another."
- `PEG_SQ5_MARK_BOUGHT_BLASTPROOF_01`: "Blastproof. I can work close again."
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
- `DEA_SQ5_MARK_DANGER_01`: "Lord, stay away from that spot. Stay away."
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
- `DEA_SQ5_MARK_BOUGHT_CRATE_01`: "Crate's turning. [quietly] Let's pray on it."
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
- `DEA_SQ5_MARK_SHORT_LOTS_01`: "That's more Scrip than I've seen all week. [a breath] I'll work on it."
- `DEA_SQ5_MARK_SHORT_01`: "Can't cover that yet. I'll earn it."
- `DEA_SQ5_MARK_EXPIRED_01`: "Couldn't come up with it. Letting that one go. [quietly] Letting it go."
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
- `WRN_SQ5_MARK_DANGER_01`: "Bad place. Stay away. [quietly] I have seen what is there."
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
- `WRN_SQ5_MARK_EXPIRED_01`: "Not enough. I stop. [a breath] I stop."
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

**U08 (T-129) tier IV, "perma perks"**: `PERK_TIER4`: a survivor makes a tonic permanent (PerkManager.set_tier at
the permanent tier; forced, every time); the Operator on the match's first (`PERK_TIER4`). Bake alone with
`--only=SQ8`.
- `OPR_SQ8_PERK_TIER4_01`: "Congratulations! You've been enrolled in our Lifetime Measure. There is no {cancellation}."
- `OPR_SQ8_PERK_TIER4_02`: "The fourth chamber! A permanent arrangement. We do so love {permanence}."
- `DUT_SQ8_PERK_TIER4_01`: "This one's mine for good. Whatever's in it, it's staying in. [quiet] Along with everything else that got in me tonight."
- `DUT_SQ8_PERK_TIER4_02`: "Bottle number four. Nobody's taking this one off me."
- `PEG_SQ8_PERK_TIER4_01`: "This one's mine for good. I shan't explain it to London. London doesn't explain itself to me."
- `PEG_SQ8_PERK_TIER4_02`: "A permanent measure. [a pause] Nothing about tonight was meant to be permanent."
- `DEA_SQ8_PERK_TIER4_01`: "This one's mine for good. [quietly] Lord, keep it that way. Keep something that way."
- `DEA_SQ8_PERK_TIER4_02`: "Fourth glass. Went all the way down. I feel it in my bones. [a breath] Fourth. Of course it's the fourth."
- `WRN_SQ8_PERK_TIER4_01`: "This one's mine for good. I'm writing that down so I believe it."
- `WRN_SQ8_PERK_TIER4_02`: "Four measures. It does not wear off. [quietly] One fewer thing to count."
- `JAK_SQ8_PERK_TIER4_01`: "This one stays with me. Like the cold. Like the songs."

**U08 (T-130) the late kit**: `LATE_KIT`: a bot gears up from round 25 (a tier III tonic and the Chicago Lament II;
BotSquad.apply_late_kit; forced). Bake with the SQ8 prefixes.
- `DUT_SQ8_LATE_KIT_01`: "Round twenty-five. [exhausted] Fine. Hand me the good stuff and point me at 'em. I'll go till I don't."
- `DUT_SQ8_LATE_KIT_02`: "Chicago Lament, second pressing. Thirty in the stick. Make 'em count."
- `PEG_SQ8_LATE_KIT_01`: "Twenty-five rounds. [exhausted] The strong measure and a proper gun. I've earned neither. I'll take both."
- `PEG_SQ8_LATE_KIT_02`: "The Thompson again, taught twice. Let's not waste it."
- `DEA_SQ8_LATE_KIT_01`: "Lord, it's a long night. [exhausted] All right. I'm loaded for the rest of it. Whatever the rest is."
- `DEA_SQ8_LATE_KIT_02`: "Fresh tonic, fresh drum. [a breath] Come on, then. Come on."
- `WRN_SQ8_LATE_KIT_01`: "Round twenty-five. New gun, new measure. I am counting from here. [quietly] Again."
- `WRN_SQ8_LATE_KIT_02`: "Chicago Lament, twice taught. Thirty rounds. I will make them count. [a breath] I always do."

**Dutch (`DUT`)**
- `DUT_SQ6_PERK_TIER_01`: "Second helping. Tastes worse. Works better. [a pause] That's the Army in a bottle, and I drank it."
- `DUT_SQ6_PERK_TIER_02`: "The machine gave me the strong stuff. I don't like that it knew I was ready."
- `DUT_SQ6_PERK_PROC_01`: "[breathing heavily] That should've put me down. ...Why didn't that put me down."
- `DUT_SQ6_PLAQUE_01`: "Made in Basel. Neutral country. Sure."
- `DUT_SQ6_PLAQUE_CRUCIBLE_01`: "Patent pending. Somebody's paying a lawyer for this thing. Somebody else paid for it first."

**Peg (`PEG`)**
- `PEG_SQ6_PERK_TIER_01`: "A stronger measure. [a pause] London will want a sample. London wants a sample of everything down here. Everything."
- `PEG_SQ6_PERK_TIER_02`: "Interlocks on a drinks cabinet. Somebody planned for us coming back."
- `PEG_SQ6_PERK_PROC_01`: "Didn't feel that. [a pause] I am choosing not to think about why. I'm choosing quite hard."
- `PEG_SQ6_PLAQUE_01`: "Replacement unit. They had spares. Of course they had spares."
- `PEG_SQ6_PLAQUE_CRUCIBLE_01`: "Crate two of three. So where's the third?"

**Deacon (`DEA`)**
- `DEA_SQ6_PERK_TIER_01`: "Second chamber behind the first. Clever plumbing. [quietly] Hate it. Hate how much I like it."
- `DEA_SQ6_PERK_TIER_02`: "It read my hand before it poured. [a breath] A machine shouldn't know a man's hand. Nothing here should."
- `DEA_SQ6_PERK_PROC_01`: "Lord. [a breath] Something in me just held. Thank You."
- `DEA_SQ6_PLAQUE_01`: "Swiss rivets. Good work on a bad job. [quietly] Most of the work here is."
- `DEA_SQ6_PLAQUE_CRUCIBLE_01`: "Mod. R-E. Pat. pend. Somebody's waiting on a patent for this thing. [a breath] Lord, let 'em wait forever."

**Wren (`WRN`)**
- `WRN_SQ6_PERK_TIER_01`: "More. It always wants you to have more. [quietly] That is how they got the laborers too. More."
- `WRN_SQ6_PERK_TIER_02`: "The owl on the glass. Somebody here was on our side."
- `WRN_SQ6_PERK_PROC_01`: "Not yet. [a breath] Not today. Not here."
- `WRN_SQ6_PLAQUE_01`: "They wrote down who made it. They never write down who it was made from."
- `WRN_SQ6_PLAQUE_CRUCIBLE_01`: "A furnace that teaches guns. [quietly] Of course they built it before bread. They always build it before bread."

**Jakub (`JAK`)** (he never drinks; the plates only)
- `JAK_PERK_REFUSE_M4_01`: "No. Not that one either." *(UPDATE 07, T-105: the two Map 4 tonics; the usual PERK_REFUSE route)*
- `JAK_PERK_REFUSE_M4_02`: "They are painting them now. It does not change what is in them."
- `JAK_SQ6_PLAQUE_01`: "We carried these down the ladder. Twelve men to a cabinet. Two did not come back up."
- `JAK_SQ6_PLAQUE_CRUCIBLE_01`: "The cooling plant. We were told never to look inside it."

## 21. Map 0's round 1 opening: the bar empties (DECISIONS T-072)

Played by `InnOpening` (`gravelight/world/inn_opening/inn_opening.gd`, data `data/gravelight/map00_opening.json`, which
holds each line's time and speaker). Local on every peer, positional at the patron when baked; the subtitle shows the
patron's name. Baked with the neural cast (T-073): one Kokoro voice each, a German accent, in `voice_cast.json`; see `VOICES.md`.

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
- `DUT_INN_RISE_01`: "He's getting up. [a breath] ...He's getting up. [shouting] That's not Willi any more, put him down! Put him DOWN!"
- `PEG_INN_RISE_01`: "Oh, no. No, no, no. Willi. [quiet] ...I'm sorry, love. Somebody. Please."
- `DEA_INN_RISE_01`: "Lord have mercy, the boy's standing up. That isn't him. [shouting] That isn't him!"
- `WRN_INN_RISE_01`: "The soldier. He is standing. Do not look at his face. [a breath] Shoot. Shoot."

**Before round 1, T-076** (`INN_CHAT`, during the look-around, times in seconds of settled view; Rother's and Trudi's
welcome always play, these only while the player looks away from the front door. The cue `KUB_INN_WINDOW_01` now
plays just before round 1 starts.)
- `KUB_INN_CHAT_01`: "Road's shut both ways, they say. Snow to the axles at the bridge. We'll be sleeping on these benches tonight, Ewald."
- `POH_INN_CHAT_01`: "My sister will think I'm lying dead in a ditch. ...Must that gramophone play all night, Fräulein?"
- `SOB_INN_CHAT_01`: "Six kilometres to Wilcza Góra. In the morning I walk it, snow or no snow. My mother has kept the goose for me."

## 22. The survivors upstairs at the Crossroads Inn (DECISIONS T-077)

Played by `InnSurvivors` (`gravelight/world/inn_opening/inn_survivors.gd`, data `data/gravelight/map00_survivors.json`,
which lists each survivor's lines per moment). The host picks the line and mirrors it; positional at the survivor when
baked, the subtitle under their name. Neural cast (T-073): one Kokoro voice each with a German accent (`voice_cast.json`).

**Who they are.** Three travellers off the shut road who came in out of the snow on the afternoon of the 23rd and were
resting in the middle guest room (Room 2) when the dead came. They pushed the hall furniture against the stair door
(Door 1's boards) and hid. Like the patrons, nobody signed the guest book; the Vogts are not among them.
- `WIE` **Konrad Wiesner**, a railway signalman (50s) on the Kaltenbrunn line, walking home to Hirschfelde since the
  snow cut the line. At Verdun in 1916; has not held a rifle since. Steady, weary.
- `BRA` **Fräulein Hedwig Brandt**, the schoolteacher (30s) at Hirschfelde, carrying the village children's Christmas
  letters to the post at Kaltenbrunn. Brisk, frightened, braver than she sounds.
- `KRO` **Ida Kroll**, the postwoman (20s) from Sankt Anna on the Christmas round; her bicycle is in a drift on the
  west road. Quick and talkative when scared.

Moments (`lines` keys): `reveal` (the first time a player comes near after the door), `scared` (now and then while a
player is near), `flinch` (a shot close by, sometimes), `armed` (handed the rifle), `fight` (now and then on a shot),
`hurt` (a swipe, sometimes), `downed`, `death`.

### 22.1 Konrad Wiesner (`WIE`)
- `WIE_SURV_REVEAL_01`: "Stop! Stop, don't shoot... we're alive. We're alive in here. You came up the stairs... are they behind you?"
- `WIE_SURV_SCARED_01`: "I heard them in the hall. Scratching at the wainscot like rats. Thirty years I have not been this afraid."
- `WIE_SURV_SCARED_02`: "I was at Verdun, you know. Nineteen sixteen. ...There were Russians on the road tonight. Greatcoats, no boots, walking with our own. The dead stayed down at Verdun."
- `WIE_SURV_FLINCH_01`: "[flinching] God in heaven!"
- `WIE_SURV_ARMED_01`: "A Karabiner. A ninety-eight. ...My hands remember. Go on, go. I'll hold the hall."
- `WIE_SURV_FIGHT_01`: "Coming along the hall! I have him!"
- `WIE_SURV_HURT_01`: "[pained] It has my coat... get off me!"
- `WIE_SURV_DOWNED_01`: "[hurt] I'm down... the leg's gone. Don't leave an old man on the floor!"
- `WIE_SURV_DEATH_01`: "[weak] Don't let me get up again. Promise me. Don't let me get up."

### 22.2 Hedwig Brandt (`BRA`)
- `BRA_SURV_REVEAL_01`: "Please, please, we're not like them! We pushed the wardrobe against the stair door, we've been so quiet... is it over? Tell me it's over."
- `BRA_SURV_SCARED_01`: "I have the children's letters in my bag. Thirty-one letters to the Christ Child. I promised them I would post them."
- `BRA_SURV_SCARED_02`: "[whispering] Don't make a sound. They hear everything. Breathe slowly, like me."
- `BRA_SURV_FLINCH_01`: "[a gasp] Oh! Oh, God."
- `BRA_SURV_ARMED_01`: "I have never fired a gun in my life. ...Show me once. Once! Good. Go, I'll watch the stairs."
- `BRA_SURV_FIGHT_01`: "There, by the door! I see it!"
- `BRA_SURV_HURT_01`: "[screaming] Its hands! Its hands are on me!"
- `BRA_SURV_DOWNED_01`: "[hurt] Help me up... please, I can't feel my arm..."
- `BRA_SURV_DEATH_01`: "[weak] The letters... somebody post the letters."

### 22.3 Ida Kroll (`KRO`)
- `KRO_SURV_REVEAL_01`: "Oh thank God, thank God, real people! I'm Ida, I bring the post from Sankt Anna... I hid under the bed. I'm sorry. I didn't help anyone."
- `KRO_SURV_SCARED_01`: "My bicycle's in a drift on the west road. Two days to Christmas and I still have a sack full of parcels."
- `KRO_SURV_SCARED_02`: "Something walked up and down the hall all afternoon. Up and down. It never knocked."
- `KRO_SURV_FLINCH_01`: "[a yelp] Ah! Warn me before you do that!"
- `KRO_SURV_ARMED_01`: "Me? With this? ...All right. All right! Point it at them and pull. I can do that."
- `KRO_SURV_FIGHT_01`: "One at the window! I got it... I think I got it!"
- `KRO_SURV_HURT_01`: "[screaming] No, no, no, get away from me!"
- `KRO_SURV_DOWNED_01`: "[hurt] I'm bleeding... I'm bleeding all over Frau Vogt's floor..."
- `KRO_SURV_DEATH_01`: "[weak] It's so cold. Is the window open? ...Close the window."

### 22.4 The squad: `INN_SURV_TURN`
When a dead survivor is about to rise (one random standing squad member, after the "[Name is turning]" subtitle).
- `DUT_INN_SURV_TURN_01`: "One of the civvies upstairs is moving again. [a breath] That's not them. That's not them any more. Put them down."
- `PEG_INN_SURV_TURN_01`: "Oh, no. Upstairs. One of ours upstairs is getting up. [quiet] ...I'm sorry. Make it quick. Make it kind."
- `DEA_INN_SURV_TURN_01`: "Lord, one of the folks upstairs is rising. Don't let them suffer it. [quietly] Put them to rest. Please."
- `WRN_INN_SURV_TURN_01`: "Upstairs. The civilian is turning. Do not wait for them to look at you. [quietly] You will not shoot if they look at you."

## 23. The round-5 milestone, the tonic bottle and the Scrip bonuses (DECISIONS T-078)

`MILESTONE`: the Operator, when a milestone's drops land (round 4's last kill; PowerupManager.drop_milestone).
`PWR_TONIC`: the tonic bottle taken (the Operator, then the survivor who took it, as for every power-up; the token is
`TONIC` in VOManager.POWERUP_TOKENS). `PING_TONIC`: a bot calling the bottle with a ping. `BONUS_CLEAN` /
`BONUS_STREAK` / `BONUS_SALVAGE`: the Operator on the match's first untouched round, first headshot streak and first
dog tags; `BONUS_SALVAGE` is also each survivor's own line on their first tags (ScripBonuses). Writer rules hold:
the tags are the dead's names, said with respect; Jakub never drinks (he only points the bottle out). The ids carry
`ECO` (`python gravelight/tools_src/gen_vo.py --only=OPR_ECO,DUT_ECO,PEG_ECO,DEA_ECO,WRN_ECO,JAK_ECO`). Baked.

**Operator (`OPR`)**
- `OPR_ECO_MILESTONE_01`: "Five rounds with us! For our loyal {customers}: a little something from the cellar, and a fresh ration of lead."
- `OPR_ECO_MILESTONE_02`: "A milestone! The management sends its compliments. And a {bottle}."
- `OPR_ECO_MILESTONE_03`: "Still breathing? How {unusual}. Have one on the house."
- `OPR_ECO_PWR_TONIC_01`: "A tonic, on the house! Drink up, it's already {paid} for."
- `OPR_ECO_PWR_TONIC_02`: "Complimentary refreshment for every {guest}!"
- `OPR_ECO_PWR_TONIC_03`: "One bottle each. The ledger is feeling {sentimental}."
- `OPR_ECO_BONUS_CLEAN_01`: "Not a scratch! The house rewards a {spotless} account."
- `OPR_ECO_BONUS_CLEAN_02`: "A clean round! Bonus paid, with our {admiration}."
- `OPR_ECO_BONUS_STREAK_01`: "Five in the head, five in a row! A marksman's {bonus}!"
- `OPR_ECO_BONUS_STREAK_02`: "Such tidy work. The ledger pays extra for {neatness}."
- `OPR_ECO_BONUS_SALVAGE_01`: "Ah, a keepsake! Hand those in, we pay for every {name}."
- `OPR_ECO_BONUS_SALVAGE_02`: "Tags returned to the office! A small {finder's} fee."

**Dutch (`DUT`)**
- `DUT_ECO_PWR_TONIC_01`: "Free drink. [a pause] Nothing's free. Drink it anyway. Drink it before your hands stop working."
- `DUT_ECO_PING_TONIC_01`: "Bottle on the floor! Grab it!"
- `DUT_ECO_SALVAGE_01`: "Dog tags. Somebody's boy. [quiet] I'll carry 'em. I carry everybody's."

**Peg (`PEG`)**
- `PEG_ECO_PWR_TONIC_01`: "A complimentary tonic. [a pause] I shan't ask what's in it. I rather suspect I'll be told."
- `PEG_ECO_PING_TONIC_01`: "A tonic bottle, over here."
- `PEG_ECO_SALVAGE_01`: "Tags. [quiet] Someone ought to know where he ended up. Someone ought to be told properly, by name."

**Deacon (`DEA`)**
- `DEA_ECO_PWR_TONIC_01`: "Bottle for everybody. Drink it slow. [a breath] It's all we get, and we didn't earn it."
- `DEA_ECO_PING_TONIC_01`: "Bottle here! One for each of us."
- `DEA_ECO_SALVAGE_01`: "Tags. [quietly] Rest easy, son. I've got your name. Somebody'll know where you are."

**Wren (`WRN`)**
- `WRN_ECO_PWR_TONIC_01`: "A gift. Nothing here is a gift. [a breath] Drink anyway. Drink."
- `WRN_ECO_PING_TONIC_01`: "Bottle. Here."
- `WRN_ECO_SALVAGE_01`: "A name. [quietly] They had names, once. I keep them. Somebody should keep them."

**Jakub (`JAK`)**
- `JAK_ECO_PING_TONIC_01`: "A bottle, over there! For you, not for me."

## 24. The Map 0 radio egg tells its story (DECISIONS T-086)

The guided egg's problem was that nothing set a step up and nothing paid it off: the notes step was open from round 1
while Fasbender only asked for the notes at round 7, a picked-up note gave a banner and the generic INTEL line, the
finished notes said nothing, the radio's three locks had Fasbender's lines but no squad, a wrong lock was "Wrong
number!", and the payoff was a banner. Now every step of `map00_radio` has a **setup beat** (who wants this and
why: 2-3 lines, different speakers), **progress beats** (each note read aloud by whoever took it, and an answer on
the first and second), a **payoff beat** (what changed, where next) and a **reset beat**. The beats are quest-data
actions (`data/gravelight/quests/map00_radio.json`, keys in `QuestManager._run_actions`: `vo_squad`, `vo_actor`,
`on_vo` / `after_end`, `at_n`, `while_active`, `patience`, `vo_retire`), so a bot's deed fires the same lines as the
player's. Squad beats go through `GLVO.say_story_beat`: the speaker is chosen when the beat is scheduled (the next
line goes to someone else), the line waits for the radio / the Operator to finish (never over them), tier 2
(`rules.json player_category_priority`), and it is dropped after its `patience` when the moment has passed. Solo
without bots, the one survivor carries the whole beat. The ids carry `SQ7` for the bake
(`python gravelight/tools_src/gen_vo.py --only=DUT_SQ7`); unbaked, they play as subtitles.

The story, in order:

| Beat | Trigger | Lines |
|---|---|---|
| Setup (notes) | round 2, after `FAS_M0_R1_01` ("Glasmacher calling Gravelight... anyone?") | `M0_EGG_HEARD` (that's our call sign), then another survivor `M0_EGG_LOOK` (the innkeeper listened and wrote it down: look for paper); `M0_EGG_LOOK` again after `FAS_M0_R7_01` while the notes are still missing |
| Progress (notes) | each note, by the one who took it | `M0_EGG_NOTE`; after the first `M0_EGG_NOTE_FIRST` (there'll be three), after the second `M0_EGG_NOTE_TWO` (one more) |
| Payoff (notes) = setup (radio) | all three notes | `FAS_M0_NOTES_01` (Glasmacher, repeating: lowest first, lock each one), then two survivors `M0_EGG_NOTES_DONE` (to the radio, in order; a wrong one makes noise); `FAS_M0_R7_01` is retired |
| Progress (radio) | after `FAS_M0_FREQ1_01` / `FAS_M0_FREQ2_01` | `M0_EGG_LOCK1` (so that's our defector; Wren's brother's letters; Jakub knew the name), `M0_EGG_LOCK2` (black glass in the salt: Babcia's letter, Tomasz's hum, Gallery Nine); `FAS_M0_R1_01` is retired at the first lock |
| Reset | a wrong lock | `OPR_M0_WRONG` (as before), `FAS_M0_WRONG_01/02` (they heard that; start again, the lowest first), `M0_EGG_WRONG` |
| Payoff (radio) | after `FAS_M0_FREQ3_01` | `OPR_M0_FIRST_01` (the Operator, faint, for the first time), two survivors `M0_EGG_DONE` (nine kilometres east by rail when the snow stops; "bring all of them", twice; that other voice), then `OPR_M0_CREDIT_01` (every account on this frequency credited: the house tonics are on the Ledger) and `M0_EGG_TONICS` as every tonic lands |

Bots in Full Partner add `EE_COMMIT_SELF` (section 18) when the player hasn't come for the last lock within
`ee.json full_commit_after_s`: "You're busy. I'll turn the last one myself." (`DUT_SQ4_EE_COMMIT_SELF_01`,
`PEG_SQ4_EE_COMMIT_SELF_01` "You're occupied. I'll make the last move. Do say if you mind.",
`DEA_SQ4_EE_COMMIT_SELF_01` "You've got your hands full. I'll finish it, brother.", `WRN_SQ4_EE_COMMIT_SELF_01`
"You are busy. I do the last one.").

### 24.1 Fasbender (`FAS`, radio, tier 4)
- `FAS_M0_NOTES_01`: "[static, then steadier] Glasmacher, repeating. If you have found my technician's notes: three numbers. The lowest first. Lock each one, and wait for me. I am listening on all three. [click]"
- `FAS_M0_WRONG_01`: "[through a burst of static] No, no, that was not... they heard that. Everything out there heard that. Start again. The lowest first."
- `FAS_M0_WRONG_02`: "[static] Wrong. Wrong, and loud. I am sorry, I should have... again, from the first number. Quickly, please."

### 24.2 The Operator (`OPR`, tier 4; the Ledger's first words on Map 0)
- `OPR_M0_FIRST_01`: "[faint, cheerful, from no particular direction] ...and a pleasant evening to all our listeners on the Kaltenbrunn band! Do stay {tuned}."
- `OPR_M0_CREDIT_01`: "[faint] A warm welcome to our new listeners. Every account on this frequency has been {credited} in full. The house tonics are on the Ledger tonight. Do enjoy them. [tape click]"

### 24.3 The squad (`SQ7`; Jakub where he has a line)
**`M0_EGG_HEARD`**
- `DUT_SQ7_M0_EGG_HEARD_01` (Dutch): "That set behind the bar just said Gravelight. [a pause] That's us. Somebody out there knows we're alive."
- `DUT_SQ7_M0_EGG_HEARD_02` (Dutch): "Our call sign. On a German radio. [exhausted] Swell. Just swell."
- `PEG_SQ7_M0_EGG_HEARD_01` (Peg): "Gravelight is our call sign. Nobody this side of London should have it. [a pause] ...Someone this side of London does."
- `PEG_SQ7_M0_EGG_HEARD_02` (Peg): "Someone out there knows the name of this mission. [quiet] I was told very few people did. I was told a number of things."
- `DEA_SQ7_M0_EGG_HEARD_01` (Deacon): "Lord. Somebody out there is calling for us by name. [a breath] By name."
- `DEA_SQ7_M0_EGG_HEARD_02` (Deacon): "That voice knows who we are. Friendly or not, that's something. [quietly] That's something."
- `WRN_SQ7_M0_EGG_HEARD_01` (Wren): "He says Gravelight. He knows the plane. [a breath] Someone was waiting for us. I do not like being waited for."
- `WRN_SQ7_M0_EGG_HEARD_02` (Wren): "A man alone, calling and calling. He has been doing this a while. [quietly] Nobody calls that long unless he has to."

**`M0_EGG_LOOK`**
- `DUT_SQ7_M0_EGG_LOOK_01` (Dutch): "Innkeeper kept a pencil by that set. People who listen write things down. Look for paper."
- `DUT_SQ7_M0_EGG_LOOK_02` (Dutch): "Somebody in this house was tuning that thing before us. Find his notes."
- `PEG_SQ7_M0_EGG_LOOK_01` (Peg): "A set like that is tuned by hand, from notes. Find them. Numbered, if we're lucky."
- `PEG_SQ7_M0_EGG_LOOK_02` (Peg): "Whoever kept that radio kept frequencies. Search the house. Paper, not guns."
- `DEA_SQ7_M0_EGG_LOOK_01` (Deacon): "A man who listens that close writes it down. Check the mantel, the trunks, the loft."
- `DEA_SQ7_M0_EGG_LOOK_02` (Deacon): "Somebody here wrote those numbers somewhere. Eyes open for paper."
- `WRN_SQ7_M0_EGG_LOOK_01` (Wren): "The innkeeper listened to the works' channels. He wrote them down. Look for the notes."
- `WRN_SQ7_M0_EGG_LOOK_02` (Wren): "Paper. Small, with numbers. The whole house, not just this room."

**`M0_EGG_NOTE`**
- `DUT_SQ7_M0_EGG_NOTE_01` (Dutch): "Got a note. A frequency, and a Roman numeral. Chapter and verse."
- `DUT_SQ7_M0_EGG_NOTE_02` (Dutch): "Paper with a number on it. Hand-written. This goes with the radio."
- `PEG_SQ7_M0_EGG_NOTE_01` (Peg): "A frequency, numbered. Someone meant these to be read in order."
- `PEG_SQ7_M0_EGG_NOTE_02` (Peg): "Note in hand. Megacycles and a numeral. That's for the set behind the bar."
- `DEA_SQ7_M0_EGG_NOTE_01` (Deacon): "Here's one. Numbers and a numeral, in a careful hand. [quietly] Somebody was scared when he wrote this. Careful is how scared folks write."
- `DEA_SQ7_M0_EGG_NOTE_02` (Deacon): "Got a note. He numbered them. Means there's more than one."
- `WRN_SQ7_M0_EGG_NOTE_01` (Wren): "A note. Frequency and a number. I keep it."
- `WRN_SQ7_M0_EGG_NOTE_02` (Wren): "Here. Written fast, but numbered. He knew someone would come."
- `JAK_SQ7_M0_EGG_NOTE_01` (Jakub): "A paper with numbers. From the innkeeper's hand, I think. Here."
- `JAK_SQ7_M0_EGG_NOTE_02` (Jakub): "I have it. Small writing. A frightened man writes small."

**`M0_EGG_NOTE_FIRST`**
- `DUT_SQ7_M0_EGG_NOTE_FIRST_01` (Dutch): "One down. The man numbered 'em, so there's more. Keep looking."
- `PEG_SQ7_M0_EGG_NOTE_FIRST_01` (Peg): "Numeral one of how many? Three, I'd wager. Keep searching the house."
- `DEA_SQ7_M0_EGG_NOTE_FIRST_01` (Deacon): "That's the first. Upstairs, the barn, the mantel. He'd have spread them out."
- `WRN_SQ7_M0_EGG_NOTE_FIRST_01` (Wren): "First of three. I can feel it. The others are hidden the same way."
- `JAK_SQ7_M0_EGG_NOTE_FIRST_01` (Jakub): "One. There will be more. Men hide things in threes."

**`M0_EGG_NOTE_TWO`**
- `DUT_SQ7_M0_EGG_NOTE_TWO_01` (Dutch): "Two. One more somewhere in this inn."
- `PEG_SQ7_M0_EGG_NOTE_TWO_01` (Peg): "That's two. One more and we have the whole set."
- `DEA_SQ7_M0_EGG_NOTE_TWO_01` (Deacon): "Two of three. One more, Lord willing."
- `WRN_SQ7_M0_EGG_NOTE_TWO_01` (Wren): "Two. The last one is close. Nothing here is far."
- `JAK_SQ7_M0_EGG_NOTE_TWO_01` (Jakub): "Two now. The third is somewhere nobody looks."

**`M0_EGG_NOTES_DONE`**
- `DUT_SQ7_M0_EGG_NOTES_DONE_01` (Dutch): "Three notes, three numbers. [a breath] Radio's behind the bar. Let's go find out who's out there."
- `DUT_SQ7_M0_EGG_NOTES_DONE_02` (Dutch): "That's the set. Radio's behind the bar. Lowest number first, he said."
- `PEG_SQ7_M0_EGG_NOTES_DONE_01` (Peg): "All three, in order. To the radio. I'll want that man's name before we trust a word."
- `PEG_SQ7_M0_EGG_NOTES_DONE_02` (Peg): "We have his frequencies. Lock them in sequence, lowest first. [a pause] Steady hands. Mine aren't; someone else turn it."
- `DEA_SQ7_M0_EGG_NOTES_DONE_01` (Deacon): "Three numbers. One, two, three. Let's give the man his call."
- `DEA_SQ7_M0_EGG_NOTES_DONE_02` (Deacon): "Got 'em all. The set behind the bar. Start low and climb, like a hymn."
- `WRN_SQ7_M0_EGG_NOTES_DONE_01` (Wren): "Three. Now the radio. One, two, three, in order. A wrong one makes noise, and noise brings them."
- `WRN_SQ7_M0_EGG_NOTES_DONE_02` (Wren): "We have all of it. Behind the bar. I will read, someone turns."
- `JAK_SQ7_M0_EGG_NOTES_DONE_01` (Jakub): "Three papers. The radio is yours. I don't know radios. I know what noise brings."

**`M0_EGG_LOCK1`**
- `DUT_SQ7_M0_EGG_LOCK1_01` (Dutch): "So that's our defector. [quiet] Sounds like a man who hasn't slept since he did whatever he did."
- `PEG_SQ7_M0_EGG_LOCK1_01` (Peg): "Fasbender. Glasmacher. That's our man. [a pause] London said physicist. They didn't say penitent. They didn't say much."
- `DEA_SQ7_M0_EGG_LOCK1_01` (Deacon): "'The reason you are here.' [a breath] Man says that like a confession. I know what a confession sounds like."
- `WRN_SQ7_M0_EGG_LOCK1_01` (Wren): "Kaltenbrunn. The salt works. [quietly] My brother's letters came from there. One letter."
- `JAK_SQ7_M0_EGG_LOCK1_01` (Jakub): "Fasbender. I know that name. The men from his department never went down with us."

**`M0_EGG_LOCK2`**
- `DUT_SQ7_M0_EGG_LOCK2_01` (Dutch): "Black glass in the salt. Babcia's letter said that. [quiet] I thought it was an old woman's story. I got it in my pocket. I ain't read it in years."
- `PEG_SQ7_M0_EGG_LOCK2_01` (Peg): "A stone that hums. [a pause] London wants a piece of it. London wants a piece of whatever is in those men out there, too. ...Carry on."
- `DEA_SQ7_M0_EGG_LOCK2_01` (Deacon): "The dead remember. One thing. [quietly] Lord, let that be the worst of it. ...It won't be."
- `WRN_SQ7_M0_EGG_LOCK2_01` (Wren): "It hums, he says. Tomasz wrote of a hum. [a breath] Then he stopped writing."
- `JAK_SQ7_M0_EGG_LOCK2_01` (Jakub): "The black glass. We cut round it in Gallery Nine. We were told not to touch it. We touched it."

**`M0_EGG_WRONG`**
- `DUT_SQ7_M0_EGG_WRONG_01` (Dutch): "That static's a dinner bell. Start over. Lowest first."
- `DUT_SQ7_M0_EGG_WRONG_02` (Dutch): "Wrong one. They heard it. Back to the first number."
- `PEG_SQ7_M0_EGG_WRONG_01` (Peg): "Wrong frequency. The sequence resets. From the lowest, and mind the windows."
- `PEG_SQ7_M0_EGG_WRONG_02` (Peg): "That was loud. Again, from the first. Carefully."
- `DEA_SQ7_M0_EGG_WRONG_01` (Deacon): "Wrong note. Every one of them heard it. Back to the start."
- `DEA_SQ7_M0_EGG_WRONG_02` (Deacon): "Static like that carries. Start again, low to high."
- `WRN_SQ7_M0_EGG_WRONG_01` (Wren): "Wrong. Again, from the first note. Quickly, they come."
- `WRN_SQ7_M0_EGG_WRONG_02` (Wren): "No. The first number. Then the second. They heard that."
- `JAK_SQ7_M0_EGG_WRONG_01` (Jakub): "That noise. In the mine, that noise meant run. Try again, from the first."

**`M0_EGG_DONE`**
- `DUT_SQ7_M0_EGG_DONE_01` (Dutch): "Nine kilometres. In the snow. With them walking. [exhausted] ...Yeah. Swell."
- `DUT_SQ7_M0_EGG_DONE_02` (Dutch): "The rail line east. When the snow quits. Until then this inn is ours, and yinz are gonna hold it with me."
- `PEG_SQ7_M0_EGG_DONE_01` (Peg): "Kaltenbrunn, nine kilometres east by rail, when the snow stops. Until then we hold this house. That's the mission."
- `PEG_SQ7_M0_EGG_DONE_02` (Peg): "He said bring all of them. Twice. [a pause] We'll discuss what he meant when I'm looking at him. I think I already know."
- `DEA_SQ7_M0_EGG_DONE_01` (Deacon): "'Bring all of them.' He said it twice. [quietly] Why would a man say that twice. ...Because he's seen what happens to the ones left behind."
- `DEA_SQ7_M0_EGG_DONE_02` (Deacon): "A gatehouse and a headframe. We'll know it when we see it. First we live till morning."
- `WRN_SQ7_M0_EGG_DONE_01` (Wren): "East. The rail line. It goes to the salt works. I know that line."
- `WRN_SQ7_M0_EGG_DONE_02` (Wren): "That other voice. Cheerful. On his frequency. [a breath] That was not Fasbender. Nobody is cheerful on a frequency like that."
- `JAK_SQ7_M0_EGG_DONE_01` (Jakub): "I walked that line, the other way, with ten men behind me. I will walk it back."

**`M0_EGG_TONICS`**
- `DUT_SQ7_M0_EGG_TONICS_01` (Dutch): "The machines just lit up. All of 'em. Nobody paid. [quiet] Somebody always pays."
- `PEG_SQ7_M0_EGG_TONICS_01` (Peg): "Nothing here is free. [a pause] Drink anyway. We'll learn the price later; we always do."
- `DEA_SQ7_M0_EGG_TONICS_01` (Deacon): "Every cabinet in the house just woke up. That voice did that. [quietly] Think on who's buying."
- `WRN_SQ7_M0_EGG_TONICS_01` (Wren): "The cabinets. Open. All of them. [a breath] A gift from a voice we do not know. I know what gifts like that cost."
- `JAK_SQ7_M0_EGG_TONICS_01` (Jakub): "Those machines. I told you what they put in them. Now they pour it free. Think why."

## 14. MAP 4 "FERNFLUG" (UPDATE 07; design doc `docs/MAP4_FERNFLUG.md` §12): the lines the build references

The full Map 4 script (every speaker, every act) is in `docs/MAP4_FERNFLUG.md` §12; this section holds the ids the
data and code reference as they are built, so `extract_vo.py` picks them up. Act tokens: `M4A` Werk Thalbach,
`M4B` der Kranich, `M4C` Groom Lake, `M4D` Mondlicht. No Linux voice bakes the Operator: these are listed in the
manifest's `missing` ("map4: bake on the PC") and play as timed silence with subtitles until the PC bakes them.

### 14.1 Act I — Werk Thalbach: the Operator (`OPR`, tier 3; exfil lines as §3.15)

| ID | Line | When |
|---|---|---|
| OPR_M4A_ARRIVE_01 | Market localization complete. Welcome back, valued {customers}. You're in a new territory. | match start / arrival |
| OPR_M4A_ARRIVE_02 | Thalbach. A company town. We have always {liked} a company town. | match start, second |
| OPR_M4A_POWER_01 | Power restored. Thank you for your patience. The works would like to {show} you something. | the main breaker |
| OPR_M4A_HALLE_01 | The Great Hangar is now open. Please mind the {weather}. | the hangar door opens |
| OPR_M4A_KRAN_SPAWN_01 | A valued colleague is joining us from above. He's been with the works a {long} time. | the Kranführer arrives |
| OPR_M4A_KRAN_DEATH_01 | The crane is... no longer in service. We'll let the {works} know. | the Kranführer dies |
| OPR_M4A_FLIEGER_01 | Visitors from the west. They've been told this is a fighter works. Nobody has {corrected} them. | Fliegeralarm begins |
| OPR_M4A_FLIEGER_END_01 | The visitors have moved on. Resupply has been {authorized}. | Fliegeralarm ends |
| OPR_EXFIL_OPEN_M4A_01 | Boarding has begun. The aircraft is prepared. The aircraft is *very* {prepared}. | the ramp beacon lights |
| OPR_EXFIL_WAIT_M4A_01 | The aircraft will not wait indefinitely. The aircraft has somewhere to {be}. | co-op, some have voted |
| OPR_EXFIL_MISSED_M4A_01 | Boarding has closed. It will reopen. It {always} reopens. | the window closed |
| OPR_EXFIL_GO_M4A_01 | Boarding is now complete. Please take any {seat}. | the boarding cutscene (tier 4) |

### 14.2 Totenhafen → Werk Thalbach: the exfil (`OPR`, tier 3; the beacon on the pen hall apron at round 40)

| ID | Line | When |
|---|---|---|
| OPR_EXFIL_OPEN_M2_01 | A transfer has been arranged. Rail siding, pen hall. The paperwork says {Thalbach}. | the beacon lights |
| OPR_EXFIL_MISSED_M2_01 | The transfer has left without you. There will be {another}. There is always another. | the window closed |
| OPR_EXFIL_GO_M2_01 | Werk Thalbach. An aircraft works. We think you'll find it {familiar}. | the cutscene |

### 14.3 Act I → Act II: the boarding and Wittkamp (`WIT`, the works' PA; tier 4 first, then 2)

| ID | Line | When |
|---|---|---|
| OPR_EXFIL_GO_M4A_01 | Boarding is now complete. Please take any {seat}. | the boarding cutscene |
| WIT_M4A_NOTME_01 | I did not do {that}. | the ramp closes on its own |
| WIT_M4A_RAMP_01 | The impellers are turning over. I didn't start them. If you go in there... if you go in there, cut the fuel lines in the port room. Please. It's the only thing I {ask}. | the ramp beacon lights |
| WIT_M4B_TAPE_01 | If anyone is hearing this aboard, I'm sorry. The autopilot takes a key and both hands. It was never meant to take a {crew}. | Act II, the radio room's tape |
| WIT_M4B_TAPE_02 | Anselm, if you're still in there. It was never a test. The casings were never empty. I should have told {you}. | Act II, the engine room |

### 14.4 Act II — der Kranich: the Operator (`OPR`, tier 3; the bomb run and London tier 4)

| ID | Line | When |
|---|---|---|
| OPR_M4B_ARRIVE_01 | You are now in flight. Cabin crew are not available at this time. Cabin crew are... {elsewhere}. | arrival |
| OPR_M4B_TURB_01 | A little turbulence. The aircraft is adjusting course. The aircraft is very good at {that}. | the first turbulence |
| OPR_M4B_STRAFE_01 | Unauthorized third parties are attempting to engage with the product. Please stay away from the {windows}. | the first strafing run |
| OPR_M4B_BREACH_01 | A small loss of pressure. This is within tolerance. Yours, we {mean}. | the first breach |
| OPR_M4B_DRUCK_01 | Pressure drop. Everything not secured will be returned to {sender}. | Druckabfall begins |
| OPR_M4B_DRUCK_END_01 | Pressure restored. Resupply authorized. Please re-stow your belongings and your {colleagues}. | Druckabfall ends |
| OPR_M4B_TAGS_03 | Those crew members have been re-deployed. Darkm... the works thanks them for their {service}. | the third crew tag |
| OPR_M4B_BORDWART_SPAWN_01 | Our flight engineer will be with you shortly. He's very attached to his {work}. | the Bordwart arrives |
| OPR_M4B_BORDWART_DEATH_01 | The engineer is... resting. The engine will manage without him. The engine always {could}. | the Bordwart dies |
| OPR_M4B_LONDON_01 | Valued customers. We said we'd be in {touch}. | the London window |
| OPR_M4B_LONDON_02 | Your region has been {expanded}. | the London window, after |
| OPR_M4B_BOMBRUN_01 | Regional sampling begins now. A little of the {product}, for a very large market. You are welcome to {observe}. | the bomb run begins |
| OPR_M4B_RACK_DROP_01 | Sample {delivered}. | a rack drops |
| OPR_M4B_RACK_DROP_02 | Another sample delivered. Thank {you}. | a rack drops |
| OPR_M4B_RACK_JAM_01 | A sample has been... withheld. We'll note {that}. | a rack is jammed |
| OPR_M4B_RACK_DUD_01 | That sample appears to be... hm. Somebody has been writing on the {inventory}. | a marked rack drops |
| OPR_M4B_BOMBRUN_END_01 | Sampling complete. Proceeding to the point of delivery. Our customer is expecting {us}. | the bomb run ends |
| OPR_EXFIL_OPEN_M4B_01 | The flight deck is open. We strongly advise against touching the autopilot. We're required to say {that}. | the autopilot beacon |
| OPR_EXFIL_WAIT_M4B_01 | The autopilot does not negotiate. We've {tried}. | co-op, some have voted |
| OPR_EXFIL_MISSED_M4B_01 | The autopilot has resumed. It will be available again. It is {patient}. | the window closed |
| OPR_EXFIL_GO_M4B_01 | You've disabled the autopilot. We hope you have a plan. We {don't}. | the crash cutscene |

### 14.5 Act II — the Bordfunk (`PA`, German, subtitled with a gloss) and the Bordwart (`BWT`, the boss channel)

| ID | Line | When |
|---|---|---|
| PA_M4B_HEADING_01 | Kurs drei-null-null. Steigflug. (Heading 300. Climbing.) | arrival |
| PA_M4B_HEADING_02 | Kurs zwei-neun-null. Reiseflughöhe erreicht. (Heading 290. Cruise altitude.) | act round 16 |
| PA_M4B_HEADING_03 | Kurs zwei-sieben-null. Beobachter an die Kanzel. (Heading 270. Observers to the blisters.) | the London window |
| PA_M4B_HEADING_04 | Kurs zwei-sechs-null. Zielanflug. (Heading 260. Approach to target.) | the bomb run begins |
| PA_M4B_HEADING_05 | Kurs zwei-fünf-null. Endanflug. Auslieferung. (Heading 250. Final approach. Delivery.) | the bomb run ends |
| PA_M4B_TURB_01 | Achtung. Turbulenz. (Attention. Turbulence.) | 3 s before a bank |
| PA_M4B_BREACH_01 | Achtung. Druckverlust, Backbord. (Attention. Pressure loss, port.) | a port breach |
| PA_M4B_BREACH_02 | Achtung. Druckverlust, Steuerbord. (Attention. Pressure loss, starboard.) | a starboard breach |
| PA_M4B_DRUCK_01 | Achtung. Druckabfall. Alle Luken sichern. (Attention. Pressure drop. Secure all hatches.) | Druckabfall |
| PA_M4B_RACK_01 | Schacht eins, Abwurf. (Rack one, release.) | rack 1 |
| PA_M4B_RACK_02 | Schacht zwei, Abwurf. (Rack two, release.) | rack 2 |
| PA_M4B_RACK_03 | Schacht drei, Abwurf. (Rack three, release.) | rack 3 |
| PA_M4B_RACK_04 | Schacht vier, Abwurf. (Rack four, release.) | rack 4 |
| PA_M4B_RACK_05 | Schacht fünf, Abwurf. (Rack five, release.) | rack 5 |
| PA_M4B_RACK_06 | Schacht sechs, Abwurf. (Rack six, release.) | rack 6 |
| BWT_BARK_01 | Besatzung, melden. (Crew, report.) | bark |
| BWT_BARK_02 | Die Drehzahl stimmt nicht. Wer ist an meiner Station? (The revs are wrong. Who is at my station?) | bark |
| BWT_BARK_03 | Es ist nur ein Test. Es ist nur ein Test. (It is only a test.) | bark |
| BWT_PHASE_01 | Backbord läuft heiß. Ich halte sie. Ich halte sie. (Port is running hot. I'll hold her.) | phase 1 |
| BWT_PHASE_02 | Lorenz? Lorenz, sag ihnen, es ist nur ein Test. (Lorenz, tell them it is only a test.) | phase 2 |
| BWT_PHASE_03 | Überdrehzahl. Ich kann nicht... ich kann nicht loslassen. (Overspeed. I can't let go.) | phase 3 |
| BWT_DEATH_01 | ...melden. (...report.) | death |

### 14.6 Act II — the squad (`DUT` / `PEG` / `DEA` / `WRN` / `JAK`; the London lines tier 4, the rest tier 2)

| ID | Line | When |
|---|---|---|
| DUT_M4B_ARRIVE_01 | Nobody's flying it. [breathing heavily] Nobody's flying the plane. I want that {noted}. Somebody write that down. | arrival |
| DUT_M4B_TURB_01 | [shouting] Whoa... whoa... who's {driving}? WHO'S DRIVING? | turbulence |
| DUT_M4B_BREACH_01 | Hole! HOLE! Grab {something}! | a breach |
| DUT_M4B_STRAFE_01 | Those are ours! They're shooting at... [a breath] yeah. Yeah, fair. We're in the bad {plane}. | strafing |
| DUT_M4B_LONDON_01 | ...Peg. Peg, don't {look}. | the London window |
| DUT_M4B_BOMBRUN_01 | Boston! That's BOSTON! Get on the racks, GET ON THE {RACKS}! | the bomb run |
| DUT_M4B_RACK_JAM_01 | Got it! One stays up {here}! | a rack jammed |
| DUT_M4B_CRASH_01 | [quiet] That's not an airfield. ...That's not {anything}. | the crash |
| PEG_M4B_ARRIVE_01 | The plan has been {revised}. | arrival |
| PEG_M4B_TURB_01 | Brace. It's {banking}. | turbulence |
| PEG_M4B_BREACH_01 | Seal it. Seal it now, or we'll be a great deal {lighter}. | a breach |
| PEG_M4B_LONDON_01 | That's not Morgenrot. That's... that's a second {battery}. [quiet] That's the dust. They're putting the dust on London. | the London window |
| PEG_M4B_LONDON_02 | ...My mother's in Islington. ...Right. Racks. Where are the {racks}. | the London window, after |
| PEG_M4B_BOMBRUN_01 | Racks in order, one every half minute. Nearest first. {GO}. | the bomb run |
| PEG_M4B_RACK_DUD_01 | That one's marked. It's a dud. Leave it, take the {next}. | a marked rack |
| PEG_M4B_CRASH_01 | Hold on to something {British}. | the crash |
| DEA_M4B_ARRIVE_01 | No crew. Harnesses buckled over nobody. ...Lord, that's wrong. That's wrong in a way I don't have a word {for}. | arrival |
| DEA_M4B_TURB_01 | Easy, girl. Easy. Nobody's at the {stick}. | turbulence |
| DEA_M4B_CRUCIBLE_01 | They bolted a forge to the galley floor. For the crew. [quietly] The crew they didn't {have}. | the Crucible |
| DEA_M4B_BORDWART_01 | He's part of the engine. He's PART of it. Anselm... [a breath] I'm sorry, brother. I'm gonna shut her {down}. | the Bordwart |
| DEA_M4B_LONDON_01 | ...Oh, no. Oh, no, no, {no}. | the London window |
| DEA_M4B_BOMBRUN_01 | I'll take the far racks! Deacon's on the far {racks}! | the bomb run |
| DEA_M4B_RACK_JAM_01 | Jammed! She's {holding}! | a rack jammed |
| DEA_M4B_AUTOPILOT_01 | Okay. Okay, girl. Key's in. [quietly] Now I need you to let {go}. | the autopilot unlocked |
| DEA_M4B_AUTOPILOT_02 | Easy. Easy, girl. You don't have to go where they pointed {you}. | the crash cutscene |
| DEA_M4B_HEADING_01 | That's not home. [a breath] Where's it taking {us}? | after the bomb run |
| WRN_M4B_ARRIVE_01 | No crew. Buckled harnesses. ...They were taken OUT. Like Tomek. [a breath] Like all of {them}. | arrival |
| WRN_M4B_TAGS_01 | 'Riedl, A.' ...I'll keep {it}. | the first crew tag |
| WRN_M4B_TAGS_03 | Three names. They had names. I have them {now}. | the third crew tag |
| WRN_M4B_BREACH_01 | Hole in the wing. Good. It's a {window}. | a breach |
| WRN_M4B_LONDON_01 | — | the London window (silence, 3 s) |
| WRN_M4B_MARKS_01 | Two of the racks are marked. The hook. They're duds. They MADE them duds. Thank you. Thank you, whoever you {are}. | the bomb run begins |
| WRN_M4B_BOMBRUN_01 | Count with me. Thirty seconds. Dwadzieścia dziewięć, dwadzieścia {osiem}... | the bomb run |
| WRN_M4B_RACK_DROP_01 | ...That one's gone. I'm sorry. I'm {sorry}. | a rack drops |
| JAK_M4B_MARKS_01 | The hook means DO NOT TRUST IT. Two of them. They will not go off. The boys made {sure}. | the bomb run begins (Jakub) |
| JAK_M4B_LONDON_01 | ...Marta. Hania. ...It is far from there. It is {far}. | the London window |

### 14.7 Act I — the main egg "Kündigung" and Jette's logbook (`WIT` the works' PA tier 4 first then 2; `OPR` tier 3; the squad tier 2; UPDATE 07 T-114)

| ID | Line | When |
|---|---|---|
| WIT_M4A_PA_01 | Is that... are there people on the line? This is Wittkamp. I'm in the tunnel office. I can see you on the canteen camera. Don't... the doors lock from my side. I locked them. I'm {sorry}. | the first file step starts (the canteen speaker) |
| WIT_M4A_PA_02 | You've turned the lights on. Thank you. I've been in the dark for six days with a model {aeroplane}. | power on |
| WIT_M4A_FILE_01 | The engines. Four of them. We didn't build them. She sold them to us. The valve plates are in a language that isn't a {language}. | file 1 read |
| WIT_M4A_FILE_02 | The flight plan. The Atlantic. And a last waypoint in a desert nobody here had heard of. I asked who wrote it. Nobody wrote {it}. | file 2 read |
| WIT_M4A_FILE_03 | The crew list. Crew: provided. I asked, provided by whom. They said it was handled. I resigned that afternoon. Nobody accepted {it}. | file 3 read |
| WIT_M4A_SWITCH_01 | You've got my line. Listen. The hangar door is a key and a code. The code is the wing's weight in kilos. It's in the tunnel log. Jette wrote it. Then she wrote {no}. | the PA line dialled |
| WIT_M4A_KRANICH_01 | There she is. Der Kranich. The most beautiful thing I have ever made. I would give anything for her never to {fly}. | the hangar opens |
| WIT_M4A_KRAN_01 | That... that was Beck. The night crane. He wouldn't leave the hangar {either}. | the crane driver falls |
| OPR_M4A_FILE_01 | You've found a document. Documents are provided for your convenience and may not be {binding}. | the first file |
| OPR_M4A_FILE_03 | Crew: provided. Yes. We've handled {that}. | the third file |
| DUT_M4A_ARRIVE_01 | A factory town. [exhausted] I grew up in one. The smell's the {same}. Hot metal and nobody talking. | arrival |
| DUT_M4A_FILE_01 | Four engines, sold by 'V.' I'm gonna find V. I'm gonna have a word with {V}. | a file read (M4A_FILE) |
| DUT_M4A_FILE_02 | 'Crew: provided.' Provided by {WHO}? | a file read (M4A_FILE) |
| DUT_M4A_KRANICH_01 | That's not a plane. That's a church with a {propeller}. | the hangar |
| DUT_M4A_TUNNEL_01 | Okay. Okay, Kowalczyk, nothing surprises you. [a breath] The WIND is on our {side}. | the tunnel ran (M4A_TUNNEL) |
| DUT_M4A_GLIDER_01 | A toy plane. Somebody here still liked {flying}. | a glider model (M4A_GLIDER) |
| DUT_M4A_JETTE_01 | She said no. In writing. ...I like {her}. | Jette's logbook (M4A_JETTE) |
| PEG_M4A_ARRIVE_01 | An aircraft works. Hale's cable said 'retrieve the engines.' [a pause] He didn't say what they were {in}. He never says what things are in. | arrival |
| PEG_M4A_FILE_01 | Four engines, and a seller with one initial. I've seen that initial on a manifest at {Totenhafen}. | a file read (M4A_FILE) |
| PEG_M4A_FILE_02 | A last waypoint in Nevada. Nobody here could have written that. Nobody here could have {spelled} it. | a file read (M4A_FILE) |
| PEG_M4A_KRANICH_01 | ...Right. That is rather more than an {engine}. | the hangar |
| PEG_M4A_TUNNEL_01 | A wind tunnel that clears a room. Note for the {report}. | the tunnel ran (M4A_TUNNEL) |
| PEG_M4A_GLIDER_01 | Balsa and tissue. [quiet] Rather good {work}. Somebody loved this. | a glider model (M4A_GLIDER) |
| PEG_M4A_JETTE_01 | 'Nein.' One word. More than anyone else here {managed}. | Jette's logbook (M4A_JETTE) |
| DEA_M4A_ARRIVE_01 | Lord, listen to that. Something in that hangar's running and it's running {sweet}. | arrival |
| DEA_M4A_FILE_01 | That engine's not burning anything. It's just... turning. [quietly] Nothing turns for free. {Nothing}. | a file read (M4A_FILE) |
| DEA_M4A_FILE_02 | 'Provided.' They put a crew on a list and never put one on the {plane}. | a file read (M4A_FILE) |
| DEA_M4A_KRANICH_01 | ...She's beautiful. God forgive me, she's the most beautiful thing I ever saw and she's full of {poison}. | the hangar |
| DEA_M4A_TUNNEL_01 | Easy, girl. Blow 'em over. That's {it}. | the tunnel ran (M4A_TUNNEL) |
| DEA_M4A_GLIDER_01 | Somebody made this with their hands. For nothing but the {flying}. | a glider model (M4A_GLIDER) |
| DEA_M4A_JETTE_01 | She wouldn't fly it and she wouldn't drug the men. That's good {hands}. | Jette's logbook (M4A_JETTE) |
| WRN_M4A_ARRIVE_01 | The transfer lists said Thalbach. Two hundred names. [a breath] I am going to find where they put {them}. | arrival |
| WRN_M4A_FILE_01 | Engines sold. Routes written. Crews 'provided'. Everything here was bought from {someone}. | a file read (M4A_FILE) |
| WRN_M4A_FILE_02 | A waypoint in a desert. They were never coming {back}. | a file read (M4A_FILE) |
| WRN_M4A_KRANICH_01 | Sixty-one. Sixty-two. ...That thing has no number. I don't have a number for {that}. | the hangar |
| WRN_M4A_TUNNEL_01 | Twenty. In the wind. ...Good. {Good}. | the tunnel ran (M4A_TUNNEL) |
| WRN_M4A_GLIDER_01 | A model. Hers, I think. Jette. The label says {Jette}. | a glider model (M4A_GLIDER) |
| WRN_M4A_JETTE_01 | 'Nein.' She said no. {Good}. | Jette's logbook (M4A_JETTE) |
| JAK_M4A_ARRIVE_01 | I turned back at Sankt Aurel. The lists said Thalbach. I know Thalbach men. ...I will look for {them}. | arrival |
| JAK_M4A_FILE_01 | Paper. They always had paper for everything but {us}. | a file read (M4A_FILE) |
| JAK_M4A_CHALK_01 | Three strokes and a hook. That is ours. Someone from the Nine wrote that. On a bomb. ...Good {lad}. | the first chalk mark |
### 14.10 Act IV — Mondlicht: the Operator (`OPR`, tier 3; the arrival, the escalation, the "are you sure" and the last line tier 4)

The Operator is local here for the first time: it is in the walls. Its slips run at x3 on this map. The TERMS lines are the panel text read flat and reluctant, only when no survivor can read.

| ID | Line | When |
|---|---|---|
| OPR_M4D_ARRIVE_01 | ...Welcome, valued customers. Welcome to— I'm here. I've always been here. This is where I'm {from}. | arrival (tier 4) |
| OPR_M4D_ARRIVE_02 | You'll find everything in order. Everything here has always been in {order}. | arrival, after |
| OPR_M4D_LOWG_01 | Please note the reduced gravity. It's a feature of the location. We didn't choose the {location}. | the first jump |
| OPR_M4D_VACUUM_01 | There is no air in the yard. There is no air anywhere here. You've brought your own, which is... {unusual}. | the first breath from the suit |
| OPR_M4D_CRUCIBLE_01 | Unit zero-zero-one. The first. Before your forge was shipped there was this one. It has never been used. Please... please {use} it. | the first Crucible |
| OPR_M4D_FLARE_01 | Solar activity. Please stay inside. The inventory doesn't {have} to. | the Solar Flare begins |
| OPR_M4D_FLARE_END_01 | Activity has passed. Resupply authorized. It's the least we can do. It's the {only} thing we can do. | the Solar Flare ends |
| OPR_M4D_TAGS_03 | Those were the crew. We re-deployed them here. We thought... we thought it would be {useful}. | the third crew tag matched |
| OPR_M4D_COLUMN_01 | You're reading the terms. Nobody reads the terms. Please— please {continue}. | the first column dark |
| OPR_M4D_COLUMN_02 | Two of three. The sign is... losing letters. That's not supposed to happen. Nothing here is supposed to {happen}. | the second column dark |
| OPR_M4D_COLUMN_03 | The Account is open. She's expecting you. She's {always} expecting someone. | the third column dark (tier 4) |
| OPR_M4D_TERMS_1 | Conditions of use. Skyhook Sekt. One. Lift is provided. Landing is the Holder's responsibility. Two. The formula was made drinkable by a technician who would not fly the aircraft it was made for. Three. A customer who can leave the ground has not yet left the Plan. Four. The second jump is a courtesy. There is no third. Five. Lightness, a sudden interest in rooftops, a reluctance to come down. These pass. The landing does not. Six. Cancellation. Land. ...Signed, {Vendelin}. | column I, no survivor can read (tier 4, flat) |
| OPR_M4D_TERMS_2 | Conditions of use. Magpie Mead. One. Recovery is not refund. Two. The Provider does not sell this Plan to persons who already own a yard. It sells it to persons who think they do. Three. The magpie is a thief. It is also the only bird that comes back. Four. Nothing on the range goes to waste. Five. Thrift, a habit of looking down. Six. Cancellation. Leave it where it lies. The Product will not stop you. Nothing here will. Signed, {Vendelin}. ...And under it: read this. | column II, no survivor can read (tier 4, flat) |
| OPR_M4D_TERMS_3 | Conditions of use. Fine Print Fernet. Six. Cancellation. You may refuse any Plan by not inserting a token. This is the only cancellation procedure the undersigned has ever been able to guarantee. It works every time it is tried. It is almost never tried. Signed, {Vendelin}. | column III, no survivor can read (tier 4, flat) |
| OPR_M4D_ESCALATED_01 | She's... stepped away. The console is unlocked. I don't know who did that. I think {I} did that. | the Manager escalated |
| OPR_M4D_SURE_01 | Are you sure? Nobody {cancels}. | the cover lifted (tier 4, no slip) |
| OPR_M4D_RENEW_WARN_01 | Your plan renews in three minutes. Nothing is required of you. That's the {point}. | the clock at 3:00 |
| OPR_M4D_RENEW_WARN_02 | One minute. Thank you for your continued {engagement}. | the clock at 1:00 |
| OPR_M4D_RENEW_01 | Your plan has been {renewed}. | the renewal ending |
| OPR_M4D_LAST_01 | ...Thank you for— ...no. Thank {you}. | the cancel ending, over black (tier 4) |

### 14.11 Act IV — the Woman in Violet through the Account Manager (`WIV`; velvet, never raised, "we" for "you"; never named)

| ID | Line | When |
|---|---|---|
| WIV_M4D_INTRO_01 | There you are. We've been following your journey with such interest. We found you, you know. Years ago. Something on your little world that would not stay down, and a market that would not stay closed. You've come all this way. Let's get you set {up}. | the Manager attends |
| WIV_M4D_PHASE_01 | Onboarding. We'll take care of everything. We always {have}. | the first contract |
| WIV_M4D_PHASE_02 | Renewal. We'd like to offer you a trial of everything. Everything. Go on. There's no obligation. There's never any {obligation}. | the second contract |
| WIV_M4D_TRIAL_END_01 | The trial has ended. We hope you enjoyed it. We'll be happy to offer it {again}. | the trial's minute is up |
| WIV_M4D_PHASE_03 | Collections. We're so sorry it's come to this. It always comes to {this}. | the third contract |
| WIV_M4D_PRICE_01 | We've looked at your account. It's very {healthy}. | the first pricing stamp |
| WIV_M4D_PRICE_02 | This will be reflected on your {statement}. | the second stamp |
| WIV_M4D_CREW_01 | Some colleagues from your flight. We kept them for {you}. | the crew through the pad |
| WIV_M4D_SHIELD_01 | That was ours. ...We have {more}. | a shield-cell into the shaft |
| WIV_M4D_ESCALATE_01 | One moment. Let me get someone who can {help}. | she escalates |
| WIV_M4D_END_01 | I... don't have a form for {this}. | the cancel ending |
| WIV_M4D_RENEW_01 | Thank you for your continued engagement. We've gone ahead and kept {you}. | the renewal ending |
| WIV_M4D_REINHOLT_01 | We offered your Doctor her daughter. She said yes. People say yes. You'll say {yes}. | the Renewal phase, Dutch present |

### 14.12 Act IV — Dee's radio (`DEE`, fading) and the squad (`DUT` / `PEG` / `DEA` / `WRN` / `JAK` / `BLT` / `SPR` / `VEN`; the cancel lines tier 4)

| ID | Line | When |
|---|---|---|
| DEE_M4D_RADIO_01 | ...range to capsule. Still here. Still {answering}. | Act IV round 1, cage egg done |
| DEE_M4D_RADIO_02 | ...range to— you're on the Moon. I'm sitting in a cage in Nevada talking to the {Moon}. | act round 3 |
| DEE_M4D_RADIO_03 | ...whatever you're about to do up there. Do it. I'll hear it from {here}. | act round 6 |
| DUT_M4D_ARRIVE_01 | Okay. I'm on the Moon. Dutch Kowalczyk from Polish Hill is on the Moon, and it's got a {lobby}. | arrival |
| DUT_M4D_LOWG_01 | I weigh nothing. [a breath] First time in my life I've weighed {nothing}. | the first jump |
| DUT_M4D_PILCH_01 | 'Pilch, J.' ...Babcia knew a Pilch. Her mother's cousin went into the salt and never came— ...oh. Oh, Jan. Seven {years}. | the Account, the floor glass (tier 4) |
| DUT_M4D_PILCH_02 | Rest now, {Jan}. | the cancel ending |
| DUT_M4D_RENEW_01 | ...Huh. I don't feel any {different}. | the renewal ending |
| DUT_M4D_CANCEL_01 | Yeah. We're cancelling. ...That's it. That's the whole {thing}. | the key (tier 4) |
| DUT_M4D_LASTWORD_01 | Come on. It's a long way {home}. | the cancel ending, the last word |
| DUT_M4D_MANAGER_01 | [quiet] That's a vending machine in a suit. ...A tall one. A real tall {one}. | the Manager attends |
| PEG_M4D_ARRIVE_01 | 'Welcome, valued customers.' ...I have been called many things by the {enemy}. | arrival |
| PEG_M4D_VACUUM_01 | Twenty-five seconds of air. Count it. I'll count it for {you}. | the first breath from the suit |
| PEG_M4D_COLUMN_01 | The terms are on the back of the machines. They were always on the back. We never once {looked}. | the first column |
| PEG_M4D_MANAGER_01 | That's her. The woman in violet. Reinholt's {woman}. | the Manager attends |
| PEG_M4D_RENEW_01 | That's rather the {point}. | the renewal ending |
| PEG_M4D_CANCEL_01 | On behalf of His Majesty's Government, and everyone else: we {decline}. | the key (tier 4) |
| DEA_M4D_ARRIVE_01 | It's a store. [quietly] The whole place is a {store}. | arrival |
| DEA_M4D_CRUCIBLE_01 | Unit one. The first forge. ...They've never even turned it on. Easy, girl. Somebody's here {now}. | the first Crucible |
| DEA_M4D_HUM_01 | That hum. Same hum as the lantern. Same hum as the inn. It's all one machine. [a breath] It was always one {machine}. | the retention hall |
| DEA_M4D_PILCH_01 | That's not a machine with a man in it. That's a man with a machine on him. ...You can't fix that. [quietly] You can only stop {it}. | the Account |
| DEA_M4D_MANAGER_01 | Ma'am, I've talked to a lot of machines. You're the first one I don't want to {help}. | the Manager attends |
| DEA_M4D_RENEW_01 | ...Lord. I'm not tired. Why am I not {tired}. | the renewal ending |
| DEA_M4D_CANCEL_01 | Go on and rest now, all of you. [a breath] 'The last enemy that shall be destroyed is death.' ...We're done {here}. | the key (tier 4) |
| WRN_M4D_ARRIVE_01 | 'Nobody cancels.' ...We'll {see}. | arrival |
| WRN_M4D_TAGS_01 | 'Riedl.' Here. He's {here}. | the first crew tag matched |
| WRN_M4D_TAGS_02 | 'Haas.' ...{Here}. | the second |
| WRN_M4D_TAGS_03 | All three. They flew them here. In their harnesses. ...I have their names. That's what I can do. It's the only thing I can {do}. | the third |
| WRN_M4D_LOWG_01 | I can see the whole yard from up here. Two hundred metres. ...Easy. Too {easy}. | the first jump |
| WRN_M4D_COLUMN_01 | I'll read it. I read everything. Somebody has {to}. | the first column |
| WRN_M4D_MANAGER_01 | She sold them the engines. She sold the inn its coffins. She sold the sickness its glass. ...Sixty-two. I'm counting {you}. | the Manager attends |
| WRN_M4D_RENEW_01 | ...I can't count any higher. Why can't I {count}. | the renewal ending |
| WRN_M4D_CANCEL_01 | For Tomasz. For Agnieszka. For two hundred names. ...{No}. | the key (tier 4) |
| WRN_M4D_END_01 | Sixty-three. ...and {one}. | the cancel ending |
| JAK_M4D_EARTH_01 | It is a very long way to Wilcza {Góra}. | the yard, the Earth |
| JAK_M4D_PILCH_01 | Pilch. From the valley. ...They told us he ran off. Seven years he has been here. ...Rest, Janek. The shift is {over}. | the Account |
| JAK_M4D_KEY_01 | Do {it}. | his hand beside the key |
| SPR_M4D_ARRIVE_01 | Bolt. That's a RETENTION unit. I have the same chip. I HAD the same chip. I had it {REMOVED}. | arrival (Bolt and Sprocket; reserved) |
| SPR_M4D_FORM_01 | There's a form. There's always a form. It's in the terms. Bolt. BOLT. The weird sad robot PRINTED THE {FORM}. | the columns (reserved) |
| BLT_M4D_CANCEL_01 | Yeah. We're gonna cancel. Sprocket, you want {to}— | the key (reserved) |
| SPR_M4D_CANCEL_01 | Oh, I've been waiting my WHOLE LIFE. ...Cancelled. Cancelled, cancelled, cancelled. Friendship isn't a feature, lady. It's a bug. Nobody patches {ours}. | the key, after Bolt (reserved) |
| VEN_M4D_ARRIVE_01 | Regional Retention Relay, model seven. I was never told it existed. I was told a great many things did not {exist}. | arrival (Vendelin; reserved) |
| VEN_M4D_FORM_01 | There was always a form. They never printed it. I did. On the backs. In plain {words}. | the columns (reserved) |
| VEN_M4D_PILCH_01 | Jan Pilch. The eleventh of November. ...I was there. I was new. I did not know what I was {for}. | the Account (reserved) |
| VEN_M4D_CANCEL_01 | Field Merchandiser Unit V-1, serial DMS-FMU-V1-0001. Cancelling. ...I found the {form}. | the key (reserved) |

### 14.13 Act IV — the terms, read aloud (`TERMS_READ_1..3`: the reader's own voice; column I is Skyhook's panel, II Magpie's, III Fernet's §6; "— V." is said as "Vendelin"; each about 25 s; the hall's hum drops a step at each)

| ID | Line | When |
|---|---|---|
| DUT_TERMS_READ_1 | 'Conditions of use. Skyhook Sekt. One. Lift is provided. Landing is the Holder's responsibility.' ...Okay. 'Two. The formula was made drinkable by a technician who would not fly the aircraft it was made for.' Huh. 'Three. A customer who can leave the ground has not yet left the Plan. Four. The second jump is a courtesy. There is no third.' Yeah, I found that out. 'Five. Lightness. A sudden interest in rooftops. A reluctance to come down. These pass. The landing does not. Six. Cancellation. Land.' ...Signed, {Vendelin}. | column I |
| DUT_TERMS_READ_2 | 'Conditions of use. Magpie Mead. One. Recovery is not refund. What the Holder recovers was already paid for, by someone. Two. The Provider does not sell this Plan to persons who already own a yard. It sells it to persons who think they do. Three. The magpie is a thief. It is also the only bird that comes back. Four. Nothing on the range goes to waste. Five. Thrift. A habit of looking down. Six. Cancellation. Leave it where it lies. The Product will not stop you. Nothing here will.' Signed, Vendelin. And under it, in pencil: 'Read this.' ...{Dee}. | column II |
| DUT_TERMS_READ_3 | 'Conditions of use. Fine Print Fernet. Six. Cancellation. You may refuse any Plan by not inserting a token. This is the only cancellation procedure the undersigned has ever been able to guarantee. It works every time it is tried. It is almost never tried.' ...Signed, Vendelin. ...Well. We're trying {it}. | column III |
| PEG_TERMS_READ_1 | 'Conditions of use. Skyhook Sekt. Section one. Lift is provided. Landing is the Holder's responsibility. Section two. The formula was made drinkable by a technician who would not fly the aircraft it was made for. Section three. A customer who can leave the ground has not yet left the Plan. Section four. The second jump is a courtesy. There is no third. Section five. Lightness, a sudden interest in rooftops, a reluctance to come down. These pass. The landing does not. Section six. Cancellation. Land.' Signed, {Vendelin}. | column I |
| PEG_TERMS_READ_2 | 'Conditions of use. Magpie Mead. One. Recovery is not refund. Two. The Provider does not sell this Plan to persons who already own a yard. It sells it to persons who think they do. Three. The magpie is a thief. It is also the only bird that comes back. Four. Nothing on the range goes to waste. The Provider agrees, and means something else by it. Five. Thrift, a habit of looking down, an unwillingness to leave a thing where it lies. Six. Cancellation. Leave it where it lies. The Product will not stop you. Nothing here will.' Signed, Vendelin. In pencil beneath: 'Read this. {D. M.}' | column II |
| PEG_TERMS_READ_3 | 'Conditions of use. Fine Print Fernet. Section six. Cancellation. You may refuse any Plan by not inserting a token. This is the only cancellation procedure the undersigned has ever been able to guarantee. It works every time it is tried. It is almost never tried.' Signed, Vendelin. ...Noted, Mr. {Vendelin}. | column III |
| DEA_TERMS_READ_1 | 'Conditions of use. Skyhook Sekt. One. Lift is provided. Landing is the Holder's responsibility. Two. The formula was made drinkable by a technician who would not fly the aircraft it was made for. Three. A customer who can leave the ground has not yet left the Plan. Four. The second jump is a courtesy. There is no third. Five. Lightness. A sudden interest in rooftops. A reluctance to come down. These pass. The landing does not. Six. Cancellation. Land. The Product cannot prevent it and the undersigned would not want it to.' ...Signed, {Vendelin}. Amen. | column I |
| DEA_TERMS_READ_2 | 'Conditions of use. Magpie Mead. One. Recovery is not refund. What the Holder recovers was already paid for, by someone. Two. The Provider does not sell this Plan to persons who already own a yard. Three. The magpie is a thief. It is also the only bird that comes back. Four. Nothing on the range goes to waste. Five. Thrift, a habit of looking down. The undersigned has all three. Six. Cancellation. Leave it where it lies.' Signed, Vendelin. And a second hand: 'Read this.' ...Reading it, {Dee}. | column II |
| DEA_TERMS_READ_3 | 'Conditions of use. Fine Print Fernet. Six. Cancellation. You may refuse any Plan by not inserting a token. This is the only cancellation procedure the undersigned has ever been able to guarantee. It works every time it is tried. It is almost never tried.' Signed, Vendelin. ...Brother, it's getting {tried}. | column III |
| WRN_TERMS_READ_1 | 'Conditions of use. Skyhook Sekt. One. Lift is provided. Landing is the Holder's responsibility. Two. The formula was made drinkable by a technician who would not fly the aircraft it was made for. The undersigned wishes it recorded that this is not the same as not wanting to. Three. A customer who can leave the ground has not yet left the Plan. Four. The second jump is a courtesy. There is no third. Five. These pass. The landing does not. Six. Cancellation. Land.' Signed, {Vendelin}. ...I'm writing that down. | column I |
| WRN_TERMS_READ_2 | 'Conditions of use. Magpie Mead. One. Recovery is not refund. Two. The Provider does not sell this Plan to persons who already own a yard. It sells it to persons who think they do. Three. The magpie is a thief. It is also the only bird that comes back. Four. Nothing on the range goes to waste. Five. Thrift. A habit of looking down. Six. Cancellation. Leave it where it lies. The Product will not stop you. Nothing here will.' Signed, Vendelin. Under it: 'Read this.' ...I always {do}. | column II |
| WRN_TERMS_READ_3 | 'Conditions of use. Fine Print Fernet. Six. Cancellation. You may refuse any Plan by not inserting a token. This is the only cancellation procedure the undersigned has ever been able to guarantee. It works every time it is tried. It is almost never tried.' Signed, Vendelin. ...Sixty-two {tries}. | column III |
| VEN_TERMS_READ_1 | Conditions of use. Skyhook Sekt. I wrote this on the back where the Provider would not look. One. Lift is provided. Landing is the Holder's responsibility. Two. The formula was made drinkable by a technician who would not fly the aircraft it was made for. I understand the difference better than I once did. Three. A customer who can leave the ground has not yet left the Plan. Four. The second jump is a courtesy. There is no third. Five. These pass. The landing does not. Six. Cancellation. Land. ...Signed, {me}. | column I (Vendelin; reserved) |
| VEN_TERMS_READ_2 | Conditions of use. Magpie Mead. They painted over this one. Someone scraped it clear. One. Recovery is not refund. Two. The Provider sells this Plan to persons who think they own a yard. Three. The magpie is a thief. It is also the only bird that comes back. Four. Nothing on the range goes to waste. Five. Thrift. The undersigned has all three. Six. Cancellation. Leave it where it lies. Nothing here will stop you. ...Signed, me. And under it, in pencil, a hand I did not know: 'Read this.' ...Thank {you}. | column II (Vendelin; reserved) |
| VEN_TERMS_READ_3 | Conditions of use. Fine Print Fernet. Six. Cancellation. You may refuse any Plan by not inserting a token. This is the only cancellation procedure I have ever been able to guarantee. It works every time it is tried. It is almost never tried. ...It is being tried. Signed, {Vendelin}. | column III (Vendelin; reserved) |
| BLT_TERMS_READ_1 | 'Conditions of use, Skyhook Sekt, one, lift is provided, landing is the Holder's responsibility, two—' Sprocket. Sprocket, I'm reading. '—a technician who would not fly the aircraft, three, has not yet left the Plan, four, the second jump is a courtesy, there is no third, five, these pass, the landing does not, six, cancellation, land.' Signed, Vendelin. ...Sprocket says {hi}. | column I (Bolt, Sprocket over him; reserved) |
| BLT_TERMS_READ_2 | 'Conditions of use, Magpie Mead, one, recovery is not refund, two, persons who think they own a yard, three, the magpie is a thief, also the only bird that comes back, four, nothing on the range goes to waste, five, thrift, six, cancellation, leave it where it lies, nothing here will stop you.' Signed, Vendelin. Sprocket: 'READ THIS.' Yes, Sprocket. I {am}. | column II (reserved) |
| BLT_TERMS_READ_3 | 'Conditions of use, Fine Print Fernet, six, cancellation, you may refuse any Plan by not inserting a token, this is the only cancellation procedure the undersigned has ever been able to guarantee, it works every time it is tried, it is almost never tried.' Signed, Vendelin. Sprocket says that's the whole form. Sprocket's {right}. | column III (reserved) |
### 14.7 Act III — Groom Lake: the Operator (`OPR`, tier 3; the choice tier 4; exfil lines as §3.15)

| ID | Line | When |
|---|---|---|
| OPR_M4C_ARRIVE_01 | Delivery complete. Welcome to the point of sale. Please excuse the state of the {premises}. | arrival |
| OPR_M4C_ARRIVE_02 | This territory is already a customer. You'll find that {convenient}. | arrival, after the squad |
| OPR_M4C_HALE_01 | The gentleman in the office is a valued customer. Please be {civil}. | the hangar opens |
| OPR_M4C_POWER_01 | Power restored. The customer's laboratory is open. He bought his samples {retail}, you know. We've seen it. It's... {ambitious}. | the generator |
| OPR_M4C_BURROW_01 | Some of the staff are below you. They're {keen}. | the first Burrower |
| OPR_M4C_CANARY_01 | Please don't open the test subjects. They're under {warranty}. | the first Canary |
| OPR_M4C_JUMP_01 | Our pilots are enjoying the new {equipment}. | the first Jumpjockey |
| OPR_M4C_BACKORDER_01 | That item is on backorder. It will arrive when it arrives. You will not see it coming. That's the {feature}. | the first Backorder |
| OPR_M4C_DUST_01 | Reduced visibility. Reduced {accountability}. | a dust storm begins |
| OPR_M4C_DUST_END_01 | The dust has settled. Resupply {authorized}. | a dust storm ends |
| OPR_M4C_LODESTONE_01 | That device is ours. Was ours. Hm. It still is, {technically}. | the Lodestone's first catch |
| OPR_M4C_SPACE_01 | That one has been returned to sender. We don't have a sender. We'll find {one}. | the first fling over a rim (Act IV too) |
| OPR_M4C_PILOT_SPAWN_01 | The customer's test pilot. We're told he was the best they had. We can see why they kept {him}. | the Test Pilot arrives |
| OPR_M4C_PILOT_DEATH_01 | The pilot has been grounded. Permanently. We'll update the {roster}. | the Test Pilot dies |
| OPR_M4C_CHOICE_01 | A decision. Please take your time. We never {do}. | Peg's choice opens (tier 4) |
| OPR_EXFIL_OPEN_M4C_01 | The customer's rocket is fuelled. It is pointed at our premises. We are {flattered}. | the gantry lift |
| OPR_EXFIL_WAIT_M4C_01 | The lift is waiting. The rocket is waiting. We are... {waiting}. | co-op, some have voted |
| OPR_EXFIL_MISSED_M4C_01 | The window has closed. The rocket is patient. Rockets {are}. | the window closed |
| OPR_EXFIL_GO_M4C_01 | You're visiting head office. Nobody visits head office. Please wipe your {feet}. | the rocket cutscene |

### 14.8 Act III — Dee Marchetti (`DEE`, tier 4), Mr. Hale (`HAL`, tier 4), Fasbender on the shack's radio (`FAS`, tier 4) and the Test Pilot's dead-radio call-outs (`RRK`, the boss channel)

| ID | Line | When |
|---|---|---|
| RRK_BARK_01 | Tower, Rourke. {Rolling}. | the Test Pilot arrives |
| RRK_BARK_02 | Climbing through nothing. There's nothing up {here}. | a leap |
| RRK_BARK_03 | Tower, I've got a light on the Moon. Say again. I've got a light on the {Moon}. | a drag |
| RRK_PHASE_01 | Tower, I'm going {around}. | 60 %: up to the lake bed |
| RRK_PHASE_02 | Mayday. No... belay that. I'm fine. I'm fine. I'm {fine}. | 30 %: the stall; a catch |
| RRK_PHASE_03 | Tower, Rourke. {Rolling}. | up from the stall, faster |
| RRK_DEATH_01 | ...Tower, Rourke. {Down}. | the Test Pilot dies |

| ID | Line | When |
|---|---|---|
| DEE_M4C_RADIO_01 | ...Say again? Say AGAIN. Is that... you're on the range? You're ALIVE on the range? Oh thank God. Oh thank... no, stay there. Don't come to the cage, it's crawling. I'm fine. I've got honey and a {rifle}. | the squad's radio answers her (arrival) |
| DEE_M4C_RADIO_02 | Sergeant Marchetti. Supply. You're the first faces in three days that aren't trying to eat mine. ...British? And... Polish? Where in God's name did you fly in {from}? | her radio answered, in person |
| DEE_M4C_RADIO_03 | That crate came in April. 'London.' The man in the office signed for it himself. He signs for everything {himself}. | her radio, the crate |
| DEE_M4C_RADIO_04 | That thing under the tarp hums at the Moon. I'm not being poetic. They pointed a dish at it. It hums {back}. | her radio, the relay object |
| DEE_M4C_RADIO_05 | Those machines came with the crate. Olive drab's mine; I wasn't having violet in my hangar. The one with the lever, that's mine too. Don't drink it {fast}. | her radio, the cabinets |
| DEE_M4C_DOOR_01 | Side door's open. I'm not making you pay for my {door}. | the side door unlocks |
| DEE_M4C_HALE_01 | He'll ask nice. He always asks nice. He asked the Canaries {nice}. | Peg's choice opens |
| DEE_M4C_POWER_01 | Generator's up. That's the lab lit. God help you, that's the lab {lit}. | the generator |
| DEE_M4C_LODESTONE_01 | You built it? The egghead's reactor, in a lantern? ...Course you did. Nothing on this range goes to {waste}. | the Lodestone is built |
| DEE_M4C_PILOT_01 | That's Cal. That's... he was the first one. He went in the pit in August to see what it was. Shoot him in the rig. Please shoot him in the {rig}. | the Test Pilot arrives |
| DEE_M4C_CAGE_01 | A casing? ...Alright. On the {pile}. | the cage egg: the casing |
| DEE_M4C_CAGE_02 | The bomber's coil. I've been after that for a {month}. | the cage egg: the coil |
| DEE_M4C_CAGE_03 | The honey. You went in the kitchen for the honey. ...Okay. Okay. Yard rule's {complete}. | the cage egg: the honey |
| DEE_M4C_LAST_01 | Go on. I've got the {range}. | the gantry (cutscene) |
| DEE_M4C_LAST_02 | Go on. I've got the range, and a radio, and nothing goes to waste. That includes you. Come {back}. | the gantry, the cage egg done |
| HAL_M4C_GLASS_01 | Lieutenant Ashworth. You're rather late. I had a man at the siding in Thalbach for {you}. | the hangar opens |
| HAL_M4C_GLASS_02 | The crate, yes. Your crate. Please don't look at the sergeant like that; she had no part in it. I had no part in it. It was simply the {orders}. | the manifest read |
| HAL_M4C_GLASS_03 | That is why the program exists, Lieutenant. The sickness and the stone, in jars, with your name on the manifest. The Russians had the one for fourteen years and buried it; the Germans had the other and ground it to dust. It talks to the Moon. Something on the Moon talks back. We would like to know what, before the Russians {do}. | the program log read |
| HAL_M4C_CHOICE_01 | That is the engine. The actual engine. Lieutenant, with that we are a year ahead of everyone. With that, nobody needs to go to the Moon at all. Hand it through the hatch and your orders are complete. Every one of {them}. | the core carried in |
| HAL_M4C_CHOICE_02 | I'm not going to insist. I've never had {to}. | the choice holds |
| HAL_M4C_RESIGN_01 | ...I see. I shall note that you were under considerable {strain}. | keep |
| HAL_M4C_DELIVER_01 | Thank you, Lieutenant. Mr. Hale is in your debt. Your country is in your debt. The rocket will run on the stone; it's rougher, I'm {told}. | hand over |
| HAL_M4C_LAUNCH_01 | Ashworth. For what it's worth. I hope it's a light and nothing {more}. | keep; the burn entered |
| FAS_M4C_RADIO_01 | ...Hello? This is Fasbender, this is... who is this on the American... Ashworth? You went to AMERICA? In a {WING}? | the radar radio |
| FAS_M4C_RADIO_02 | ...and you are asking me how to aim at the Moon again. Yes. Yes, I know how. I have known how since I was {nine}. | the radar radio |
| FAS_M4C_RADIO_03 | Burn at the three numbers I am about to give you. Write it down. Write it DOWN, Sergeant, your Polish is terrible but your handwriting is {worse}. | the burn numbers (the HUD shows the seeded values) |
| FAS_M4C_RADIO_04 | The crack. The light. I saw it in the telescope the night after. I told them it was a reflection. It was not a reflection. ...It was never a joke, you know. I only laughed because the alternative was the other {thing}. | the radar radio, last |

### 14.9 Act III — the squad (`DUT` / `PEG` / `DEA` / `WRN` / `JAK`, Sprocket `SPR`, Vendelin `VEN`; the crate and the choice tier 4, the rest tier 2)

| ID | Line | When |
|---|---|---|
| DUT_M4C_ARRIVE_01 | Nevada. [breathing heavily] We're in Nevada. ...I've never been west of Ohio. Nobody's ever been to {Nevada}. | arrival |
| DUT_M4C_CRATE_01 | 'Consignor: Lieutenant M. Ashworth.' ...Peg. Peg, what is {this}. | the manifest read (tier 4) |
| DUT_M4C_CRATE_02 | You were gonna hand it to a guy in a {HAT}. [quiet] You saw what it does. You were there when Willi got up. And you were gonna hand it over. | the manifest read |
| DUT_M4C_RESIGN_01 | About {time}. | Peg keeps |
| DUT_M4C_DEE_01 | A sergeant. A real live American sergeant. [a breath] Ma'am, I have never been so happy to see anybody in my {life}. Don't make me say it twice. | the hangar opens |
| DUT_M4C_BURROW_01 | Under the salt. [quiet] They're under the salt. Babcia. ...Of course they {are}. | the first Burrower |
| DUT_M4C_CANARY_01 | Don't shoot the fishbowl! Body! {BODY}! | the first Canary |
| DUT_M4C_PILOT_01 | He can FLY. Why can he {FLY}. | the Test Pilot |
| DUT_M4C_MOON_01 | Babcia said don't go down the salt. She never said anything about {up}. | the rocket cutscene |
| PEG_M4C_ARRIVE_01 | An American test range. In the middle of nowhere. ...Why does it have my {crate}. | arrival |
| PEG_M4C_CRATE_01 | Yes. I signed for it. In April, on a dock, in the dark. [a pause] Samples. The sickness and the glass, in lead, as ordered. It was going to London. It was always going to end up here. I didn't know that. I should {have}. | the manifest read (tier 4) |
| PEG_M4C_CRATE_02 | Directive LANTERN. Retrieve samples of the sickness and the crystal, at any cost. Report to Mr. Hale. [a pause] ...He's in the office. He's been in the office the whole {time}. | the manifest read |
| PEG_M4C_HALE_01 | Mr. {Hale}. | the hangar opens |
| PEG_M4C_RESIGN_01 | Mr. Hale. Consider this my {notice}. | keep (tier 4) |
| PEG_M4C_DELIVER_01 | ...Orders are orders. ...I used to find that {comforting}. | hand over (tier 4) |
| PEG_M4C_CARRY_01 | It's heavier the second {time}. | the core, the second carry |
| PEG_M4C_PILOT_01 | Shoot the rig. Dee said the {rig}. | the Test Pilot |
| PEG_M4C_ROCKET_01 | They named it after my orders. LANTERN. ...Well. Let's see it light {something}. | the ignition key turns |
| PEG_M4C_MOON_01 | I've written a great many reports. I shan't be writing this {one}. | the rocket cutscene |
| DEA_M4C_ARRIVE_01 | That's a hangar. That's an honest-to-God American hangar. ...Why's it got their forge in {it}. | the hangar opens |
| DEA_M4C_POWER_01 | Diesel. Thank you, Lord, for diesel. Something I {understand}. | the generator |
| DEA_M4C_CABINET_01 | They painted over it. Painted right over the fella's words on the back. Somebody scraped 'em clear again. {Good}. | an olive-drab cabinet |
| DEA_M4C_LODESTONE_01 | ...It's pulling. It's listening. Easy now. {Easy}. | the Lodestone's first pickup |
| DEA_M4C_BUILD_01 | Dee, ma'am, you built a reactor into a lantern. I'd marry you if I wasn't spoken {for}. | the Lodestone is built |
| DEA_M4C_CANARY_01 | Don't break the glass. God, don't break the {glass}. | the first Canary |
| DEA_M4C_HALE_01 | Sir. With respect. You put men in glass boxes. [quietly] I've got nothing else to say to {you}. | Peg's choice decided |
| DEA_M4C_MOON_01 | 'The heavens declare the glory of God.' ...Somebody's put a light on 'em. We're gonna go switch it {off}. | the rocket cutscene |
| WRN_M4C_ARRIVE_01 | A desert. I've never seen one. It's like the salt. It's exactly like the {salt}. | arrival |
| WRN_M4C_CRATE_01 | I told you at the pens. I told you I'd seen it. ...You should have said, Peg. You should have just {said}. | the manifest read (tier 4) |
| WRN_M4C_RESIGN_01 | — | Peg keeps (a nod; silence, 2 s) |
| WRN_M4C_CANARY_01 | They're in suits. They put them in suits and glass. Who DOES {that}. | the first Canary |
| WRN_M4C_BACKORDER_01 | It walks through the wall. It walks through the WALL. I can't count it. I have to count {it}. | the first Backorder |
| WRN_M4C_PILOT_01 | In the air. I'll take him in the air. ...{There}. | the Test Pilot |
| WRN_M4C_MOON_01 | Sowa said you can hit anything if you've already hit it in your head. I've never hit the Moon in my {head}. | the rocket cutscene |
| JAK_M4C_ARRIVE_01 | Dry. Everything is dry. I have never stood anywhere {dry}. | arrival (Jakub) |
| JAK_M4C_ROCKET_01 | I have ridden worse coal {wagons}. | the rocket cutscene (Jakub) |
| SPR_M4C_HALE_01 | Sir. SIR. I've seen your brochure. The brochure is {BAD}. | Peg's choice decided (Sprocket, Bolt present) |
| SPR_M4C_RELAY_01 | That's a relay uplink. RR-series. I've seen the SCHEMATIC, it was in a MEMO, memo thirty-eight, I forwarded it to forty billion people, NOBODY READ {IT}. | the hangar opens (Sprocket) |
| VEN_M4C_CABINET_01 | ...They localized {me}. | the hangar opens (Vendelin) |
| VEN_M4C_CABINET_02 | The panel is still here. Under the paint. Someone scraped it clear. Someone read it. ...{Hello}. | Peg's choice decided (Vendelin: he reads his own panel instead of answering Hale) |

### 14.14 Act IV — the smile side egg (`M4D_SMILE`, tier 2; one line per character at the crater rim, in the vacuum; UPDATE 07 T-115)

| ID | Speaker | Line |
|---|---|---|
| `DUT_M4D_SMILE_01` | DUT | "...Huh. It's smiling. We put a smile on the Moon and it's looking at us. Babcia would've said that means something. I'm not asking what." |
| `PEG_M4D_SMILE_01` | PEG | "That is our rocket's work. Fasbender aimed it. I signed for the fuel. I find I'm not sorry. Note that down against me." |
| `DEA_M4D_SMILE_01` | DEA | "Lord, that's a long way to come to look at a scar. ...It's smiling. All right. Somebody up here was glad to see us." |
| `WRN_M4D_SMILE_01` | WRN | "A crack. Twelve kilometres, maybe more. I can't count that. ...I'll write 'one'." |

### 14.15 Map 0 — Flt Lt Harry Selwyn, GRAVELIGHT ONE's pilot (`SEL`, tier 1; positional from the cockpit, subtitled "FLT LT SELWYN"; T-126)

Pinned in the crushed cockpit by the instrument panel, alive (STORY_CHANGES: the pilots no longer both die). Clipped,
dry, in pain, polite about it. CALL while he is unarmed and someone is near; GIVEN / SWAP when handed a gun; DRY when
he runs out; THANKS_AMMO when passed ammo; KILL now and then. Cooldowns in data/gravelight/pilot.json.

| ID | Speaker | Line |
|---|---|---|
| `SEL_CALL_01` | SEL | "Over here! In the cockpit! My legs are caught under the panel. I can't get out, but I can still shoot." |
| `SEL_CALL_02` | SEL | "Hello? Is someone in the cabin? Hand me a rifle and I'll keep the nose clear." |
| `SEL_CALL_03` | SEL | "Selwyn. Flight Lieutenant. I'm stuck fast in here. Give me something that shoots." |
| `SEL_GIVEN_01` | SEL | "Right. I've got the front. You mind the doors." |
| `SEL_GIVEN_02` | SEL | "Thank you. Now they'll have to come through me." |
| `SEL_GIVEN_03` | SEL | "Lovely. Safety's off." |
| `SEL_SWAP_01` | SEL | "Here, have yours back. I'll take this one." |
| `SEL_SWAP_02` | SEL | "Fair swap. Look after the old girl." |
| `SEL_THANKS_AMMO_01` | SEL | "That's the stuff. Back in business." |
| `SEL_THANKS_AMMO_02` | SEL | "Ammunition. Bless you." |
| `SEL_DRY_01` | SEL | "I'm dry! I need ammunition up here!" |
| `SEL_DRY_02` | SEL | "Out! Somebody bring me rounds!" |
| `SEL_KILL_01` | SEL | "Got him." |
| `SEL_KILL_02` | SEL | "That one's down." |
| `SEL_KILL_03` | SEL | "Another one for the logbook." |

### 14.16 Act II — UPDATE 10 §3 (T-156): the wing walk, decompression, the aux bus, the bay doors, the crew's tags side quest, Ruhland and Riedl, the formation

Tier 2 unless the speaker's channel says otherwise (`PA` the Bordfunk, German with a gloss; `RDL` Riedl on the intercom before he is the Bordwart, a Kokoro voice through a speaking tube).

| ID | Line | When |
|---|---|---|
| PA_M4B_WING_01 | Achtung. Backbordfläche beschädigt. Sicherungsleine benutzen. (Attention. Port wing damaged. Use the safety line.) | the wing walk opens (act round 2) |
| PA_M4B_DECOMP_01 | Achtung! Druckabfall im Rumpf. Festhalten! (Attention! Pressure drop in the hull. Hold on!) | 3 s before a decompression |
| PA_M4B_POWER_01 | Hilfssammelschiene: ein. Alle Stationen, melden. (Auxiliary bus: on. All stations, report.) | the aux bus sweep |
| PA_M4B_BAYDOORS_01 | Bombenklappen öffnen. Abstand halten. (Bay doors opening. Stand clear.) | the bay-doors trap |
| PA_M4B_LASTCALL_01 | Hier Kranich, Bordmechaniker Riedl. Testflug, zweite Nacht. Die Besatzung meldet... die Besatzung meldet nicht. (Kranich here, flight engineer Riedl. Test flight, second night. The crew reports... the crew does not report.) | the crew's tags, step 3 |
| PA_M4B_LASTCALL_02 | Haas an Riedl. Da sind Leute im Werk, die wir nicht kennen. Sie zählen uns. (Haas to Riedl. There are people in the works we don't know. They are counting us.) | the crew's tags, step 3 |
| PA_M4B_LASTCALL_03 | Pohl. Wenn jemand das hört: wir sind nicht verloren gegangen. Wir wurden abgeholt. Ende. (Pohl. If anyone hears this: we were not lost. We were collected. Out.) | the crew's tags, step 3 |
| DEA_M4B_WING_01 | The panel's gone. That's a way out onto the wing. In flight. Clip in or don't {go}. | the panel tears |
| DUT_M4B_WING_FALL_01 | The rope held. My stomach {didn't}. | thrown off the wing |
| PEG_M4B_WING_FALL_01 | Note to self: clip in. Underline {clip}. | thrown off the wing |
| DEA_M4B_WING_FALL_01 | Lord, I saw the sea. [breathing heavily] Haul me in, I'm {done}. | thrown off the wing |
| WRN_M4B_WING_FALL_01 | I am not writing that one {down}. | thrown off the wing |
| DUT_M4B_ROSTER_01 | Three names on the roster, rubbed out. Write 'em back in, {somebody}. | the crew's tags, step 2 |
| PEG_M4B_ROSTER_01 | Riedl, Haas, Pohl. The roster had them in pencil. Someone took an eraser to three {men}. | the crew's tags, step 2 |
| DEA_M4B_ROSTER_01 | There. Their names are back where they belong. The tape deck's got a reel with the same three {names}. | the crew's tags, step 2 |
| WRN_M4B_ROSTER_01 | Riedl. Haas. Pohl. I'm writing them back in. In ink this {time}. | the crew's tags, step 2 |
| WRN_M4B_LASTCALL_REPLY_01 | Collected. Like my brother. They knew, at the end. [quietly] They {knew}. | after the reel |
| RUH_PEOPLE_TALK_01 | I was not supposed to be on this aeroplane. I was supposed to be counting the wages. I am still counting the {wages}. | ExtraPeople (Ruhland at the Bordkasse; Riedl on the intercom until act round 4) |
| RUH_PEOPLE_TALK_02 | The cash box is the Werk's. The ledger is the Werk's. I am, apparently, also the {Werk's}. | ExtraPeople (Ruhland at the Bordkasse; Riedl on the intercom until act round 4) |
| RUH_PEOPLE_ASK_01 | The Bordkasse's ledger went forward with the paymaster's satchel. The flight deck. Bring it to me and I can make the sums come out {honest}. | ExtraPeople (Ruhland at the Bordkasse; Riedl on the intercom until act round 4) |
| RUH_PEOPLE_THANKS_01 | Thank you. There: a fifth over, on every page. It was never my arithmetic. Take this, it was owed to {somebody}. | ExtraPeople (Ruhland at the Bordkasse; Riedl on the intercom until act round 4) |
| RUH_PEOPLE_ROUND_01 | They are coming up from the bay again. I will stay behind the {counter}. | ExtraPeople (Ruhland at the Bordkasse; Riedl on the intercom until act round 4) |
| RUH_PEOPLE_DOWN_01 | Someone is down! Get them up, get them {up}! | ExtraPeople (Ruhland at the Bordkasse; Riedl on the intercom until act round 4) |
| RDL_PEOPLE_TALK_01 | Engine room here. Riedl. Who is that on the line? Report, please. | ExtraPeople: Riedl on the engine-room intercom until act round 4 |
| RDL_PEOPLE_TALK_02 | This is a test flight. Only a test flight. The crew is to report to their stations. | ExtraPeople: Riedl on the engine-room intercom until act round 4 |
| RDL_PEOPLE_TALK_03 | Haas? Pohl? The kettle is still warm. Where have you gone? | ExtraPeople: Riedl on the engine-room intercom until act round 4 |
| RDL_PEOPLE_ROUND_01 | The engine is singing again. I cannot shut it off. I have tried. | ExtraPeople: Riedl on the engine-room intercom until act round 4 |
| RDL_PEOPLE_DOWN_01 | Is someone hurt back there? Report! | ExtraPeople: Riedl on the engine-room intercom until act round 4 |
| RDL_PEOPLE_ASK_01 | My engine log. I left it in the galley with my coffee. Read me the last entry, would you? I cannot leave the engine. | ExtraPeople: Riedl's favour (his engine log from the galley; he listens to the wing) |
| RDL_PEOPLE_THANKS_01 | Crew: provided. Provided by whom. Thank you. I will listen to the wing for you. | ExtraPeople: Riedl's favour (his engine log from the galley; he listens to the wing) |
| RDL_PEOPLE_PING_01 | Something in the port wing. Several. Moving forward. I can hear them on the spar. | ExtraPeople: Riedl's favour (his engine log from the galley; he listens to the wing) |
| DUT_M4B_FORMATION_DOWN_01 | One of the formation's going down. Burning all the way. [quiet] Nobody's getting out of {that}. ...Nobody was in it. Tell me nobody was in it. | a formation bomber goes down |
| PEG_M4B_FORMATION_DOWN_01 | Flak got the one on our wing. [a pause] That could have been {us}. One rather wishes it had been something that simple. | a formation bomber goes down |
| DEA_M4B_FORMATION_DOWN_01 | Lord keep them. Whoever's in it. [a breath] If anybody {is}. | a formation bomber goes down |
| WRN_M4B_FORMATION_DOWN_01 | Empty, I bet. Like this one. Flying for {nobody}. | a formation bomber goes down |

## 25. THE MARK (UPDATE 09 §1, DECISIONS T-137; canon CANON §2.2, LORE §2.5)

The dead come from a chip, the Marke, under the skin of the right hand or the forehead (contract C1). The squad never
learns the word for it (CANON §8): to them it is "the mark", "the chip", "the glass in the hand". **Triggers**
(`VoManager._on_marke_kill`, `GLBus.marke_kill`): the first kill from a Marke hit in a match is a story beat: the killer
says their `MARKE_FIRST` line (tier 2; anyone with the line if the killer has none), the Operator's `MARKE_OPR` follows
6 s later, and Fasbender's `MARKE_RELAY` 18 s after that (the one line in the game that explains the carrier: the mark
listens; silence it and they lie down). Later Marke kills roll the killer's `MARKE_KILL` (45 s, 20%; squad echo 12 s)
and the Operator's `MARKE_OPR` (120 s, 35%). Deacon names it from memory, quietly, not as a sermon; Peg admits her
orders; Wren has seen it on the dead by the road; Dutch is blunt; Jakub says why he refused. No line names a map, so
they play everywhere.

| ID | Speaker | Line |
|---|---|---|
| `DEA_MARKE_FIRST_01` | DEA | "[quiet] Hold on. Look at the hand. ...Right hand. There's a light in it, under the skin. [a breath] 'And he causeth all... to receive a mark in their right hand, or in their foreheads.' My daddy read that one slow, every time. [quietly] Lord. I did not come all this way to find it true." |
| `DEA_MARKE_KILL_01` | DEA | "Right in the mark. Went out like a lamp. [quietly] Like a lamp." |
| `DEA_MARKE_KILL_02` | DEA | "Forehead, this one. Same little light. Same book." |
| `DEA_MARKE_KILL_03` | DEA | "I keep hitting that spot, and I keep not liking how easy they go. [a breath] Somebody made 'em easy." |
| `PEG_MARKE_FIRST_01` | PEG | "Right hand, between the thumb and the finger. A chip of the glass, under the skin. [a pause] My orders had a line about tokens. 'Retrieve the tokens, from the dead, do not ask the bearer.' I took it to mean their papers. I didn't let it mean anything. ...Carry on." |
| `PEG_MARKE_KILL_01` | PEG | "That's the token. One for the tin, then." |
| `PEG_MARKE_KILL_02` | PEG | "Another in the hand. London wanted these and never said what for. I begin to see why they didn't." |
| `PEG_MARKE_KILL_03` | PEG | "Shoot the hand. Don't ask me how I know. I read it somewhere I wasn't meant to." |
| `WRN_MARKE_FIRST_01` | WRN | "I have seen it before tonight. On the dead by the road. A glass splinter in the right hand, and it was still warm. Same hand, every time. I thought it was a wound. [a breath] It is not a wound. The Russian dead do not have it. Only theirs. [quietly] Somebody gave it to them." |
| `WRN_MARKE_KILL_01` | WRN | "Same hand. Every time." |
| `WRN_MARKE_KILL_02` | WRN | "The splinter. Hit it and they fall like men again." |
| `WRN_MARKE_KILL_03` | WRN | "Above the eye, that one. They put it there. So did I." |
| `DUT_MARKE_FIRST_01` | DUT | "The hand. Something's lit up in the hand. [a pause] ...They put a piece of that rock in these guys. On purpose. Sold it to 'em, probably, like a medal. [spits] Shoot the hand, then." |
| `DUT_MARKE_KILL_01` | DUT | "Hit the chip. Down he goes." |
| `DUT_MARKE_KILL_02` | DUT | "They signed up for that. [quiet] Somebody told 'em it'd keep 'em safe. Nobody signs up for that." |
| `DUT_MARKE_KILL_03` | DUT | "Forehead glass. Easy to see, easy to shoot. First easy thing all night." |
| `JAK_MARKE_FIRST_01` | JAK | "[low] You see it now. The mark. They came down to Nine with a box and a needle and asked the gang leaders. 'The mark that keeps you,' they said. I said: I have a name. It is enough to carry. Nobody in Nine took it. ...That is why I am standing here, and they are not." |
| `JAK_MARKE_KILL_01` | JAK | "The hand. Yes. That is where they put it." |
| `JAK_MARKE_KILL_02` | JAK | "He took it for bread. I know. I was hungry too." |
| `JAK_MARKE_KILL_03` | JAK | "They offered it to us once. Once. Nobody in Nine was asked twice." |
| `OPR_MARKE_OPR_01` | OPR | "[warm] A valued customer, {retained}. Thank you for keeping the account {active}." |
| `OPR_MARKE_OPR_02` | OPR | "Oh, you've found the loyalty programme! Protection against the sickness, the poster said, and so it {is}, in a way. Every member is counted, in the hand or on the brow. {Nobody} is lost to us." |
| `OPR_MARKE_OPR_03` | OPR | "One mark, one name, one {account}. Closed with... [tape squeal] ...no. No. Accounts here do not {close}." |
| `FAS_MARKE_RELAY_01` | FAS | "[radio, low] You have found the marks. Listen to me. The chip does nothing by itself. It is a grain of the glass under the skin, and it listens. It listens for the Ledger's carrier, the hum, the thing you feel in your teeth. While the hum reaches it, the body gets up when it is told and walks where it is pointed. The Russians could not make their dead obey. Abteilung III did it with a needle. Silence the carrier and they lie down. I have seen it once, for eleven seconds, when Opitz blew a fuse. Eleven seconds of quiet. Then it came back." |
| `FAS_MARKE_RELAY_02` | FAS | "They offered me one in forty-two. I refused, and Lenz wrote my name in a column. This winter the poster gained a second line: protection against the Lazarus sickness. It is not protection. It is a leash. ...Saying no is the only wise thing I did in that place." |

## 26. RELIEF SQUADS (UPDATE 09 §4, DECISIONS T-142; data/gravelight/squads.json)

Soldiers who come in from the edge of the map, hold with the squad a while, and mostly do not get out (contract C5).
Speaker `SQD`, category `<FACTION>_<CAT>` (ids `SQD_<FACTION>_<CAT>_NN`); one voice per faction (voice_cast.json
`SQD_AK`, `SQD_SOV`, ...). **Triggers** (`ReliefSquad._bark`): `ARRIVE` the leader as they walk in; `CONTACT` the first
shot of the squad; `HURT` a hit (35%) or a revive; `DOWN` a squad mate when one goes down or dies; `LEAVE` when they
pull out; `SURVIVE` the one who makes it to the round's end. The first soldier of a match who rises draws a `SQD_RISE`
line from a survivor (`GLVO.squad_say`). Period voices, English with the odd word of their own language, no slurs;
the Volkssturm are old men, played with dignity; nobody names the Marke (the squad never learns the word).

| ID | Speaker | Line |
|---|---|---|
| `SQD_AK_ARRIVE_01` | SQD | "Armia Krajowa! Don't shoot, we are with you. We heard the guns from the forest." |
| `SQD_AK_ARRIVE_02` | SQD | "Spokojnie, friends. Home Army. We came the long way round the dead." |
| `SQD_AK_ARRIVE_03` | SQD | "We are Home Army, from the woods. Tell us where you want us." |
| `SQD_AK_CONTACT_01` | SQD | "There, by the trees! Ognia!" |
| `SQD_AK_CONTACT_02` | SQD | "They come! Hold the line, chłopaki!" |
| `SQD_AK_CONTACT_03` | SQD | "Dead ones, many. Shoot for the head!" |
| `SQD_AK_HURT_01` | SQD | "Ah! It's nothing. Nothing." |
| `SQD_AK_HURT_02` | SQD | "Psiakrew... they bit through the coat. ...Don't look at me like that. It is only the coat." |
| `SQD_AK_DOWN_01` | SQD | "Man down! Pomocy, help him!" |
| `SQD_AK_DOWN_02` | SQD | "They have Stefan! Get him up!" |
| `SQD_AK_LEAVE_01` | SQD | "We go now. Others wait for us in the forest. Z Bogiem." |
| `SQD_AK_LEAVE_02` | SQD | "We cannot stay. Good luck to you. Hold your ground." |
| `SQD_AK_SURVIVE_01` | SQD | "Only me left. Then I will tell them in the forest what you did here." |
| `SQD_AK_SURVIVE_02` | SQD | "I am still breathing. Dziękuję. Thank you." |
| `SQD_SOV_ARRIVE_01` | SQD | "Razvedka! Red Army scouts. We followed your shooting." |
| `SQD_SOV_ARRIVE_02` | SQD | "Tovarishchi! Easy with the rifles. We are scouts, from the east." |
| `SQD_SOV_ARRIVE_03` | SQD | "Soviet patrol. We followed the dead west from the river. Our own, some of them. ...Do not ask. Who here is still alive?" |
| `SQD_SOV_CONTACT_01` | SQD | "Here they come! Vperyod!" |
| `SQD_SOV_CONTACT_02` | SQD | "Ogon! Fire, fire!" |
| `SQD_SOV_CONTACT_03` | SQD | "Davai, davai, shoot them in the head!" |
| `SQD_SOV_HURT_01` | SQD | "Chyort! I am hit." |
| `SQD_SOV_HURT_02` | SQD | "Only a scratch. ...Only a scratch. Keep shooting. Keep shooting." |
| `SQD_SOV_DOWN_01` | SQD | "Sasha is down! Pomogi!" |
| `SQD_SOV_DOWN_02` | SQD | "They got Kolya! Somebody, get him!" |
| `SQD_SOV_LEAVE_01` | SQD | "Our orders are east. Back through them. We go. Udachi, comrades." |
| `SQD_SOV_LEAVE_02` | SQD | "We must report this. Hold out. We go back." |
| `SQD_SOV_SURVIVE_01` | SQD | "I am the last one. I will report what we saw here. They will write 'epidemic'. They always write epidemic." |
| `SQD_SOV_SURVIVE_02` | SQD | "Still alive. Spasibo, comrades." |
| `SQD_VS_ARRIVE_01` | SQD | "Nicht schießen! We are only old men from the village. We threw the armbands in the ditch." |
| `SQD_VS_ARRIVE_02` | SQD | "Volkssturm, ja. But we are finished with that. Let us stand with you." |
| `SQD_VS_ARRIVE_03` | SQD | "We heard you fighting. Better to stand here than hang for running." |
| `SQD_VS_CONTACT_01` | SQD | "Da! There they come. Steady, old hands." |
| `SQD_VS_CONTACT_02` | SQD | "Feuer! Aim low, Herr Nachbar, they are close." |
| `SQD_VS_CONTACT_03` | SQD | "Mein Gott, so many. Russians, and our own, together. Shoot, shoot!" |
| `SQD_VS_HURT_01` | SQD | "Ach... my old bones." |
| `SQD_VS_HURT_02` | SQD | "I am hit. It is not so bad. Not so bad." |
| `SQD_VS_DOWN_01` | SQD | "Karl is down! Help him up, quickly!" |
| `SQD_VS_DOWN_02` | SQD | "They have the schoolmaster! Get him!" |
| `SQD_VS_LEAVE_01` | SQD | "We go to our families now. Gott schütze euch." |
| `SQD_VS_LEAVE_02` | SQD | "Enough. We are going home, if there is still a home." |
| `SQD_VS_SURVIVE_01` | SQD | "I am the last of us. Forty years in that village... Danke. Thank you." |
| `SQD_VS_SURVIVE_02` | SQD | "Still here. I will tell their wives they stood." |
| `SQD_CDO_ARRIVE_01` | SQD | "Commando. Came in off the beach. Thought you could use a hand." |
| `SQD_CDO_ARRIVE_02` | SQD | "Don't shoot, we're British! Came in with the boats." |
| `SQD_CDO_ARRIVE_03` | SQD | "Evening. We heard the racket from the water. Where do you want us?" |
| `SQD_CDO_CONTACT_01` | SQD | "Contact front! Bloody hundreds of them!" |
| `SQD_CDO_CONTACT_02` | SQD | "Here they come, lads. Make every round count." |
| `SQD_CDO_CONTACT_03` | SQD | "Rapid fire! Heads, aim for the heads!" |
| `SQD_CDO_HURT_01` | SQD | "Ah, the blighter got me." |
| `SQD_CDO_HURT_02` | SQD | "I'm hit. Carry on, carry on." |
| `SQD_CDO_DOWN_01` | SQD | "Man down! Get to him!" |
| `SQD_CDO_DOWN_02` | SQD | "Taff's down! Somebody pull him back!" |
| `SQD_CDO_LEAVE_01` | SQD | "Right, the boats won't wait. We're off. Good luck." |
| `SQD_CDO_LEAVE_02` | SQD | "That's us. Back to the beach, lads, at the double." |
| `SQD_CDO_SURVIVE_01` | SQD | "Just me, then. I'll see the night out with you." |
| `SQD_CDO_SURVIVE_02` | SQD | "Still standing. Someone has to tell them at home." |
| `SQD_KM_ARRIVE_01` | SQD | "Nicht schießen! Navy. We left the pens. We saw what Brecht found in the lead boxes. We are done with all of it." |
| `SQD_KM_ARRIVE_02` | SQD | "We are sailors, not fighters. But we can shoot. Let us help." |
| `SQD_KM_ARRIVE_03` | SQD | "The port is lost. Mein Gott, the things in the water. We come to you." |
| `SQD_KM_CONTACT_01` | SQD | "Achtung! On the quay, there!" |
| `SQD_KM_CONTACT_02` | SQD | "Feuer frei! Fire, fire!" |
| `SQD_KM_CONTACT_03` | SQD | "They come out of the water. Shoot!" |
| `SQD_KM_HURT_01` | SQD | "Verdammt, I am hit." |
| `SQD_KM_HURT_02` | SQD | "Ah... it is nothing. Keep shooting." |
| `SQD_KM_DOWN_01` | SQD | "Hein is down! Help him!" |
| `SQD_KM_DOWN_02` | SQD | "They have Jupp! Pull him back!" |
| `SQD_KM_LEAVE_01` | SQD | "We take a boat, if there is one left. Viel Glück." |
| `SQD_KM_LEAVE_02` | SQD | "We go along the shore. Maybe the British will take us." |
| `SQD_KM_SURVIVE_01` | SQD | "Only me. I will stay with you until it is over." |
| `SQD_KM_SURVIVE_02` | SQD | "Still alive. Danke. I did not think I would say that tonight." |
| `SQD_PARA_ARRIVE_01` | SQD | "Hey! Don't shoot, we're Americans! Jumped last night and missed by about forty miles." |
| `SQD_PARA_ARRIVE_02` | SQD | "Airborne. We got scattered all over this valley. Mind if we tag along?" |
| `SQD_PARA_ARRIVE_03` | SQD | "Thank God, somebody alive. We've been fighting these things since we hit the ground." |
| `SQD_PARA_CONTACT_01` | SQD | "Here they come! Light 'em up!" |
| `SQD_PARA_CONTACT_02` | SQD | "Contact! Shoot for the head, they don't stop otherwise!" |
| `SQD_PARA_CONTACT_03` | SQD | "Lord God. There's a ton of 'em. Fire!" |
| `SQD_PARA_HURT_01` | SQD | "I'm hit! I'm okay, I'm okay." |
| `SQD_PARA_HURT_02` | SQD | "Son of a gun got me." |
| `SQD_PARA_DOWN_01` | SQD | "Medic! Somebody get Murphy back up!" |
| `SQD_PARA_DOWN_02` | SQD | "Man down! Cover him!" |
| `SQD_PARA_LEAVE_01` | SQD | "We gotta find our outfit. Good luck, folks." |
| `SQD_PARA_LEAVE_02` | SQD | "That's our cue. Rally point's west. Keep your heads down." |
| `SQD_PARA_SURVIVE_01` | SQD | "Just me left. Guess I'm with you now." |
| `SQD_PARA_SURVIVE_02` | SQD | "Still kicking. Thanks for having our backs." |
| `SQD_MP_ARRIVE_01` | SQD | "Military Police! Range security. Who's in charge here?" |
| `SQD_MP_ARRIVE_02` | SQD | "MPs, from the motor pool. The whole range has gone to hell." |
| `SQD_MP_ARRIVE_03` | SQD | "Stand easy, we're with you. Nobody told us about any of this." |
| `SQD_MP_CONTACT_01` | SQD | "Here they come! Weapons free!" |
| `SQD_MP_CONTACT_02` | SQD | "Contact on the salt! Open fire!" |
| `SQD_MP_CONTACT_03` | SQD | "Those were our guys this morning. Shoot 'em anyway!" |
| `SQD_MP_HURT_01` | SQD | "Ah! I'm hit!" |
| `SQD_MP_HURT_02` | SQD | "Took one. Still in it." |
| `SQD_MP_DOWN_01` | SQD | "Sarge is down! Get him up!" |
| `SQD_MP_DOWN_02` | SQD | "Man down! Cover me, I'm going for him!" |
| `SQD_MP_LEAVE_01` | SQD | "Orders are to secure the gate. We're moving out." |
| `SQD_MP_LEAVE_02` | SQD | "We're pulling back to the radar tower. Good luck." |
| `SQD_MP_SURVIVE_01` | SQD | "Last one standing. Guess the paperwork's on me." |
| `SQD_MP_SURVIVE_02` | SQD | "Still here. I'll put you all in my report. The good parts." |

The squad on the first soldier who gets up (`SQD_RISE`, a story beat, once a match):

| ID | Speaker | Line |
|---|---|---|
| `DEA_SQD_RISE_01` | DEA | "They came to help us, and now they're getting up. [a breath] Don't anybody call it a judgment. It ain't. It's a debt. ...Lord, have mercy." |
| `DEA_SQD_RISE_02` | DEA | "Don't look at the faces. Just... don't look at the faces." |
| `WRN_SQD_RISE_01` | WRN | "Those were the men who came for us. [quietly] Now they come for us again. They do not know the difference." |
| `WRN_SQD_RISE_02` | WRN | "Shoot them. They would want it. [a breath] I would want it. Promise me you would." |
| `DUT_SQD_RISE_01` | DUT | "Aw, hell. [quiet] Sorry, pal. You came for us. ...Sorry." |
| `DUT_SQD_RISE_02` | DUT | "They got back up. [exhausted] Course they got back up. Everybody gets back up. Everybody but us." |
| `PEG_SQD_RISE_01` | PEG | "They're turning. Put them down before they stand." |
| `PEG_SQD_RISE_02` | PEG | "We'll mourn them later. [a pause] I keep saying later. Now we shoot them." |

## 26. LAZARUS (UPDATE 11, T-191): the cutscenes and the new speakers

The lines of the four UPDATE 11 cutscenes (`docs/CUTSCENES_LAZARUS.md`) and the new speakers' non-diary lines
(Father Serafim's diary read-alouds `SER_DIARY_*` are §27, another worker's). Speaker codes per `docs/U11_CONTRACTS.md`
C3: `SER` Father Serafim Lebedev, `VOL` Arkady Volkov, `BRG` the 1930 brigade's megaphone, `SVR` Soviet radio
traffic, `RTN` the Returned (risen Red Army soldiers' last words, close only); `SEL`, `REI`, `PA` and the squad as
before. **Foreign-language rows** carry the spoken form first as `<speech>...</speech>` (Russian in Cyrillic, Church
Slavonic, German), then the English subtitle: extract_vo.py puts the spoken form in the line's `speech` field and the
subtitle in `text`; the game only ever shows `text` (test_vo_speech). Audio tags in `[brackets]` sit at the front of
the subtitle, as everywhere else; the bake applies them to the spoken form (gen_vo cues, ElevenLabs v4 delivery
tags). **T-204: the Russian-speaking cast speaks English with a Russian accent.** Their rows carry the Russian (and
the Church Slavonic) as `<ru>...</ru>` and then the English, which is now both what is said and the subtitle, in
natural English with a light Russian turn of phrase, never a caricature. extract_vo.py puts the Russian in the
language store `data/gravelight/vo/lang/ru.json` (with the baked Russian takes, `gravelight/audio/vo_lang/ru/`) for a
later language option; the English is baked with the same ElevenLabs voices (native Russian speakers, language `en`),
so the accent comes from the voice. The German rows keep `<speech>` (they are still spoken in German). The Russian
register the store keeps: Serafim a 1930 village priest (old words: подклет for the crypt, "сынок" to the young man,
the Church Slavonic of his service); Volkov a young OGPU plenipotentiary in 1930 (the decrees' vocabulary: гражданин,
предписание, опись, по акту) and a tired colonel of state security in 1944 (NKGB by then; no 1944 line names the
agency); the radio in 1944 front procedure ("Берёза", "Дон",
приём, коробочки). The real slogans the brigade reads (BRG_LZS_03, _04) are the League of Militant Godless's own; they
are read flat, off a paper, never gloating. All tier 4 (CINE channel) in the cutscenes; SVR and RTN are tier 2 ambient
story voices in play (the horror pass T-192 sets their rules: RTN only within a few metres, one at a time, never over
a story line).

### 26.1 "LAZARUS SATURDAY" (`*_LZS_*`): Chetverodnevo, 12 April 1930

Father Serafim Lebedev (`SER`). Fifty-nine (b. 1871), gentle, unhurried, firm without ever being loud. He is the most decent man
in the saga and the actor must never make him meek or saintly-soft: he is a man refusing calmly. SER_LZS_05 and _08
are Church Slavonic (the inscription and the troparion of Lazarus Saturday, sung under the breath).

| ID | Speaker | Line |
|---|---|---|
| `SER_LZS_01` | SER | "<ru>Ключи я вам не отдам. Не мои они. Я их только держу.</ru> The keys I won't give you. They aren't mine. I only keep them." |
| `SER_LZS_02` | SER | "<ru>Встаньте, встаньте, родные. Не перед ними на колени. Домой идите. Детей уведите.</ru> Get up, my dears, get up. Do not kneel to them. Go home. Take the children." |
| `SER_LZS_03` | SER | "<ru>Молодой человек. Берите серебро. Берите колокол. Только в подклет не ходите.</ru> Young man. Take the silver. Take the bell. Only do not go down into the crypt." |
| `SER_LZS_04` | SER | "<ru>Там нет ничего, что вам нужно. А есть то, что вам не нужно.</ru> There is nothing down there that you need. But there is something you do not need." |
| `SER_LZS_05` | SER | "<ru>Є́же затвори́ся въ де́нь четве́ртый, никто́же да отве́рзетъ.</ru> What was closed on the fourth day, let no one open." |
| `SER_LZS_06` | SER | "<ru>Аркадий. Сынок. Прошу тебя. Не ради Бога — ради тебя самого.</ru> Arkady. Son. I am asking you. Not for God's sake. For your own." |
| `SER_LZS_07` | SER | "[whispers] <ru>Господи, помилуй.</ru> Lord, have mercy." |
| `SER_LZS_08` | SER | "[quietly, half-sung] <ru>Общее воскресение прежде Твоея страсти уверяя, из мертвых воздвигл еси Лазаря, Христе Боже.</ru> Confirming the general resurrection before Thy Passion, Thou didst raise Lazarus from the dead, O Christ God." |
| `SER_LZS_09` | SER | "<ru>Вот и всё. Теперь ждите. Четыре дня.</ru> That is all. Now wait. Four days." |

Arkady Volkov (`VOL`), 1930: twenty-six, correct, a touch too loud when he is being official, quiet and quick when
he is being clever, and frightened under both. He never sneers. VOL_LZS_08 is the one time he raises his voice, and
it is the frightened one.

| ID | Speaker | Line |
|---|---|---|
| `VOL_LZS_01` | VOL | "<ru>Гражданин Лебедев? Уполномоченный ОГПУ Волков. Вот предписание. Ключи.</ru> Citizen Lebedev? Volkov, OGPU plenipotentiary. Here is the warrant. The keys." |
| `VOL_LZS_02` | VOL | "<ru>Без грубости. Эти люди не враги, они — темнота. Колокол снимаем, колокольню валим, серебро — по акту. Всё.</ru> No rough stuff. These people aren't enemies, they're only ignorant. The bell comes down, the tower comes down, the silver goes on the inventory. That's all." |
| `VOL_LZS_03` | VOL | "<ru>Подклет? В описи никакого подклета нет. Значит, там и держат серебро.</ru> A crypt? There is no crypt on the inventory. So that is where they keep the silver." |
| `VOL_LZS_04` | VOL | "<ru>Церковнославянский. „Что затворено в четвёртый день...“ Ну-ну.</ru> Church Slavonic. 'What was closed on the fourth day...' Well, well." |
| `VOL_LZS_05` | VOL | "<ru>Смотрите все. Вот ваша святыня. Сейчас я покажу вам, что внутри ничего нет.</ru> Everyone, look. Here is your relic. I will show you there is nothing inside." |
| `VOL_LZS_06` | VOL | "[breathing heavily] <ru>Печать... воск. Старый воск. Сейчас.</ru> The seal... wax. Old wax. There." |
| `VOL_LZS_07` | VOL | "[whispers] <ru>Мокрая.</ru> It's wet." |
| `VOL_LZS_08` | VOL | "<ru>Краска. Это краска! Попы и не такое подделывали. Описать и в ящик.</ru> Paint. It's paint! Priests have faked worse than this. Inventory it and box it." |
| `VOL_LZS_09` | VOL | "[exhausted] <ru>Трое. Те, кто брал сосуд в руки. Доктор, что это? Тиф?</ru> Three. The ones who handled the vessel. Doctor, what is this? Typhus?" |
| `VOL_LZS_10` | VOL | "<ru>Пишите: тиф. Карантин по всему району. Село... села нет. Понятно? Села нет.</ru> Write: typhus. District quarantine. The village... there is no village. Understood? There is no village." |
| `VOL_LZS_11` | VOL | "[whispers] <ru>Меня не укусили. Меня не укусили. Меня не...</ru> I wasn't bitten. I wasn't bitten. I wasn't..." |

The brigade's megaphone (`BRG`): a tin speaking trumpet, a young voice reading a paper. Period slogans (_03 and _04
are the League's real ones), the district's decree, the warnings. Flat; never gloating, never a sneer.

| ID | Speaker | Line |
|---|---|---|
| `BRG_LZS_01` | BRG | "<ru>Граждане! Постановлением районного исполнительного комитета церковь села Четвероднево закрывается.</ru> Citizens! By resolution of the district executive committee, the church of Chetverodnevo is closed." |
| `BRG_LZS_02` | BRG | "<ru>Колокола сдаются на нужды индустриализации. Расходитесь по домам.</ru> The bells are surrendered to the needs of industrialization. Go back to your homes." |
| `BRG_LZS_03` | BRG | "<ru>Борьба против религии — борьба за социализм!</ru> The struggle against religion is the struggle for socialism!" |
| `BRG_LZS_04` | BRG | "<ru>Религия — опиум для народа.</ru> Religion is opium for the people." |
| `BRG_LZS_05` | BRG | "<ru>Церковные ценности подлежат изъятию. Сопротивление будет рассматриваться как контрреволюционное выступление.</ru> Church valuables are subject to requisition. Resistance will be treated as a counter-revolutionary act." |
| `BRG_LZS_06` | BRG | "<ru>Товарищи крестьяне! Встаньте с колен. Не мешайте работе бригады.</ru> Comrade peasants! Get up off your knees. Do not obstruct the brigade's work." |
| `BRG_LZS_07` | BRG | "[shouting] <ru>Отойти от колокольни! Отойти! Будет взрыв!</ru> Away from the bell tower! Away! There will be a blast!" |
| `BRG_LZS_08` | BRG | "<ru>Священник Лебедев! Сдайте ключи добровольно.</ru> Priest Lebedev! Hand over the keys voluntarily." |

### 26.2 "FOURTH DAY" (`*_FTD_*`): East Prussia, October 1944

Volkov at forty (grey, a colonel of state security, a man who has carried the case for fourteen years) and the
Front's radio net (`SVR`: "Дон" is Front HQ, "Берёза" the division's observation post). The first risen at the
grave speaks `RTN_CLOSE_01` (§26.4).

| ID | Speaker | Line |
|---|---|---|
| `SVR_FTD_01` | SVR | "[radio] <ru>„Берёза“, я „Дон“. Распоряжение Москвы получено? Приём.</ru> 'Birch', this is 'Don'. Has Moscow's instruction been received? Over." |
| `VOL_FTD_01` | VOL | "<ru>Получено. Батареи заряжены особыми. Начинаем по сигналу.</ru> Received. The batteries are loaded with the special rounds. We begin on the signal." |
| `SVR_FTD_02` | SVR | "[radio] <ru>Огонь по готовности. Особых — три залпа, не больше. Приём.</ru> Fire when ready. The specials: three salvoes, no more. Over." |
| `VOL_FTD_02` | VOL | "<ru>Нет. Они и не должны рваться. Им нужно только раскрыться.</ru> No. They aren't supposed to burst. They only need to open." |
| `VOL_FTD_03` | VOL | "<ru>Кровь. Добровольцев. Большего вам знать не положено, товарищ полковник.</ru> Blood. Volunteers'. More than that you are not cleared to know, Comrade Colonel." |
| `SVR_FTD_03` | SVR | "[radio] <ru>„Дон“, я „Берёза“. Противник не отвечает. Линия пуста. Приём.</ru> 'Don', this is 'Birch'. The enemy is not answering. The line is empty. Over." |
| `SVR_FTD_04` | SVR | "[radio] <ru>Всем станциям. Наши убитые... встают. Это не паника. Я их вижу. Приём.</ru> All stations. Our dead... are getting up. This is not panic. I can see them. Over." |
| `SVR_FTD_05` | SVR | "[radio] <ru>Я „Дон“. Прекратить передачу. В эфире об этом — ни слова. Писать: эпидемия у противника. Конец связи.</ru> This is 'Don'. Cease transmission. Not one word of this on the air. Write: an epidemic among the enemy. Out." |
| `VOL_FTD_04` | VOL | "[exhausted] <ru>Четвёртый день. Всегда четвёртый.</ru> The fourth day. Always the fourth." |
| `VOL_FTD_05` | VOL | "<ru>Они не знают, чьи они. Они просто идут. На запад.</ru> They don't know whose they are. They just walk. West." |

### 26.3 "STAUB" (`*_STB_*`): Kaltenbrunn, 20 December 1944

Reinholt (`REI`, German, measured, tired; her hands do the acting) and the plant's loudspeaker and weather intercom
(`PA`, German). REI_STB_06 echoes her cylinder (`LSL_REC_CYL3_01`: "count to a hundred and then come find me").

| ID | Speaker | Line |
|---|---|---|
| `REI_STB_01` | REI | "<speech>Feinheit zwölf Mikron. Noch einmal durch die Mühle. Der Staub muss schweben, nicht fallen.</speech> Fineness twelve microns. Through the mill once more. The dust must float, not fall." |
| `REI_STB_02` | REI | "<speech>In der Nähe des Herzens wartet es keine vier Tage mehr. Minuten. Schreiben Sie: Minuten.</speech> Near the Heart it no longer waits four days. Minutes. Write it down: minutes." |
| `REI_STB_03` | REI | "<speech>Die Kanister nach Osten. Zurück zum Absender. So hat es der Generalstab formuliert, nicht ich.</speech> The canisters go east. Return to sender. That was the General Staff's phrase, not mine." |
| `REI_STB_04` | REI | "<speech>Wetterwarte, bestätigen Sie den Wind.</speech> Weather station, confirm the wind." |
| `REI_STB_05` | REI | "[whispers] <speech>Nein. Nein, nicht heute. Nicht heute Nacht.</speech> No. No, not today. Not tonight." |
| `REI_STB_06` | REI | "<speech>Liesl. Mama ist hier. Zähl bis hundert.</speech> Liesl. Mama is here. Count to a hundred." |
| `PA_STB_01` | PA | "[PA] <speech>Achtung. Staubmühle zwei, Abfüllung beginnt. Masken auf. Masken auf.</speech> Attention. Dust mill two, canning begins. Masks on. Masks on." |
| `PA_STB_02` | PA | "[radio] <speech>Wetterwarte an Leitstand. Wind aus West, drei Meter pro Sekunde, beständig. Freigabe.</speech> Weather station to control. Wind from the west, three metres a second, steady. Clear to proceed." |
| `PA_STB_03` | PA | "[PA] <speech>Abschuss in sechzig Sekunden. Nordrampe räumen.</speech> Launch in sixty seconds. Clear the north ramp." |
| `PA_STB_04` | PA | "[radio] [shouting] <speech>Leitstand, hier Wetterwarte. Der Wind dreht. Ost. Wind aus Ost, zunehmend. Leitstand, abbrechen! Abbrechen!</speech> Control, weather station. The wind is turning. East. Wind from the east, rising. Control, abort! Abort!" |
| `PA_STB_05` | PA | "[PA] <speech>Achtung. Staubalarm. Alle Türen schließen. Dies ist keine Übung.</speech> Attention. Dust alarm. Close all doors. This is not a drill." |
| `PA_STB_06` | PA | "[radio] <speech>...Leitstand, bitte antworten. Leitstand. Die Lichter in Wilcza Góra sind... Leitstand?</speech> ...Control, please answer. Control. The lights in Wilcza Góra are... Control?" |

### 26.4 The Returned (`RTN_CLOSE_01..16`): the risen Red Army soldiers' last words

Heard only up close (a few metres), one voice at a time, under the groans, never over a story line (T-192's rules).
Russian, short, subtitled. A name, a mother, a unit, "cold", a prayer half-remembered, a letter, a friend. These were
soldiers and they are victims of their own command: human, never monstrous. Spoken flat and slow, the way a man
repeats something he no longer understands; no growl, no effect but the cold.

| ID | Speaker | Line |
|---|---|---|
| `RTN_CLOSE_01` | RTN | "<ru>Мама.</ru> Mama." |
| `RTN_CLOSE_02` | RTN | "<ru>Холодно. Холодно...</ru> Cold. Cold..." |
| `RTN_CLOSE_03` | RTN | "<ru>Отче наш... иже еси... иже...</ru> Our Father... who art... who..." |
| `RTN_CLOSE_04` | RTN | "<ru>Сто восемнадцатый стрелковый. Сто восемнадцатый...</ru> Hundred and eighteenth Rifle. Hundred and eighteenth..." |
| `RTN_CLOSE_05` | RTN | "<ru>Семёнов. Семёнов Иван. Тысяча девятьсот двадцать...</ru> Semyonov. Semyonov, Ivan. Nineteen twenty-..." |
| `RTN_CLOSE_06` | RTN | "<ru>Не оставляй меня. Не оставляй.</ru> Don't leave me. Don't leave." |
| `RTN_CLOSE_07` | RTN | "<ru>Где мои сапоги? Где сапоги...</ru> Where are my boots? Where are the boots..." |
| `RTN_CLOSE_08` | RTN | "<ru>Домой. Домой... в Тулу.</ru> Home. Home... to Tula." |
| `RTN_CLOSE_09` | RTN | "<ru>Санитар! Санитар... санитар...</ru> Medic! Medic... medic..." |
| `RTN_CLOSE_10` | RTN | "<ru>Прости. Прости меня, Нюра.</ru> Forgive me. Forgive me, Nyura." |
| `RTN_CLOSE_11` | RTN | "<ru>Господи, помилуй. Господи... помилуй.</ru> Lord, have mercy. Lord... have mercy." |
| `RTN_CLOSE_12` | RTN | "<ru>Письмо. В кармане письмо... отправьте...</ru> The letter. The letter's in my pocket... send it..." |
| `RTN_CLOSE_13` | RTN | "<ru>Темно. Почему так темно?</ru> Dark. Why is it so dark?" |
| `RTN_CLOSE_14` | RTN | "<ru>Мы же победили. Мы же... победили?</ru> But we won. We... won, didn't we?" |
| `RTN_CLOSE_15` | RTN | "<ru>Воды. Глоток... воды.</ru> Water. A sip... of water." |
| `RTN_CLOSE_16` | RTN | "<ru>Не стреляй. Это я. Это же я...</ru> Don't shoot. It's me. It's me..." |

### 26.5 Soviet radio traffic, Map 0 (`SVR_M0_01..12`)

The front on the eastern horizon, December 1944, drifting through a receiver at the inn (the horror pass places it;
never part of the radio egg, whose steps are frozen): the Red Army fighting the Germans and its own Returned. Front
procedure, static, tired voices. Subtitled when close.

| ID | Speaker | Line |
|---|---|---|
| `SVR_M0_01` | SVR | "[radio] <ru>Я „Берёза-три“. Коробочки встали у леса. Впереди — не немцы. Приём.</ru> 'Birch-three'. The tanks have stopped at the woods. What's ahead of us isn't Germans. Over." |
| `SVR_M0_02` | SVR | "[radio] <ru>Всем станциям: вернувшихся ближе пятидесяти не подпускать. Бить в рану. В рану, не в голову. Приём.</ru> All stations: the Returned are not to come within fifty metres. Hit the wound. The wound, not the head. Over." |
| `SVR_M0_03` | SVR | "[radio] <ru>Как слышно? Повторяю: наши убитые из второго батальона идут через наши позиции. На запад. По своим не стрелять... отставить. Стрелять.</ru> How do you read? I repeat: our dead from Second Battalion are walking through our positions. West. Don't fire on our own... cancel that. Fire." |
| `SVR_M0_04` | SVR | "[radio] <ru>Политрук, не надо речей. Они уже не слушают.</ru> Commissar, no speeches. They don't listen any more." |
| `SVR_M0_05` | SVR | "[radio] <ru>Осветительные — каждые пять минут. Пока видно, они не подойдут незаметно. Приём.</ru> Flares every five minutes. While we can see, they can't come up on us unseen. Over." |
| `SVR_M0_06` | SVR | "[radio] <ru>„Дон“, я „Берёза“. Деревня впереди горит. Сами подожгли. Своих... жгли своих. Приём.</ru> 'Don', 'Birch'. The village ahead is burning. We lit it. Our own... we were burning our own. Over." |
| `SVR_M0_07` | SVR | "[radio] <ru>Хоронить запрещаю. Слышите? Никого не хоронить. Складывать и жечь.</ru> No burials. Do you hear? Bury no one. Stack them and burn them." |
| `SVR_M0_08` | SVR | "[radio] <ru>Семёнов, это ты? Семёнов, ответь...</ru> Semyonov, is that you? Semyonov, answer... [static]" |
| `SVR_M0_09` | SVR | "[radio] <ru>Нам сказали — эпидемия у противника. У противника! А кто идёт по полю, товарищ майор?</ru> They told us: an epidemic among the enemy. The enemy! So who is that walking across the field, Comrade Major?" |
| `SVR_M0_10` | SVR | "[radio] [whispers] <ru>Тише. Тише в эфире. Они идут на голос.</ru> Quiet. Quiet on the net. They come to a voice." |
| `SVR_M0_11` | SVR | "[radio] <ru>Четыре дня. Запомните: четыре дня. Кого вчера убило — послезавтра встанет.</ru> Four days. Remember it: four days. Whoever was killed yesterday gets up the day after tomorrow." |
| `SVR_M0_12` | SVR | "[radio] <ru>Приём... приём... „Берёза“, ответь. „Берёза“. ...Кто-нибудь.</ru> Over... over... 'Birch', answer. 'Birch'. ...Anyone." |

### 26.6 Soviet radio traffic, Kaltenbrunn (`SVR_M1_01..12`)

The same front heard from Kaltenbrunn's radio room and the surface, a week later: the Germans trucking the Soviet
dead west, the violet light, the word "Staub" from a prisoner, Volkov's name, the order of silence.

| ID | Speaker | Line |
|---|---|---|
| `SVR_M1_01` | SVR | "[radio] <ru>Я „Сосна“. Немцы вывозят трупы. Наших. Грузовиками, на запад. Зачем им наши трупы? Приём.</ru> 'Pine'. The Germans are taking away bodies. Ours. By the truckload, west. What do they want with our dead? Over." |
| `SVR_M1_02` | SVR | "[radio] <ru>Повторяю для штаба: немцы собирают вернувшихся. Не уничтожают — собирают. Приём.</ru> Repeat for HQ: the Germans are collecting the Returned. Not destroying them. Collecting them. Over." |
| `SVR_M1_03` | SVR | "[radio] <ru>Фиолетовый свет на западе. Третью ночь. Что это, „Дон“? Приём.</ru> Violet light in the west. Third night running. What is it, 'Don'? Over." |
| `SVR_M1_04` | SVR | "[radio] <ru>Четвёртую лабораторию в эфире не упоминать. Никогда. Это приказ.</ru> Laboratory Four is never to be mentioned on the air. Never. That is an order." |
| `SVR_M1_05` | SVR | "[radio] <ru>Они уже не идут на запад. Они стоят. Все повернулись... к горам.</ru> They've stopped walking west. They're standing. All of them turned... toward the mountains." |
| `SVR_M1_06` | SVR | "[radio] <ru>Пленный говорит: „Штауб“. Пыль. Говорит, они сделают пыль. Не понимаю. Приём.</ru> The prisoner says: 'Staub'. Dust. He says they will make dust. I don't understand. Over." |
| `SVR_M1_07` | SVR | "[radio] <ru>Радист, крути дальше. Там, на тысяча двести, кто-то говорит по-немецки и смеётся. Не нравится мне этот смех.</ru> Operator, keep tuning. Up at twelve hundred someone's talking German and laughing. I don't like that laugh." |
| `SVR_M1_08` | SVR | "[radio] <ru>Снег идёт. Фиолетовый. Доложить? ...Как я это доложу?</ru> It's snowing. Violet. Report it? ...How do I report that?" |
| `SVR_M1_09` | SVR | "[radio] <ru>Волков здесь. Сам Волков, из Москвы. Говорят, он с тридцатого года про это знает. С тридцатого!</ru> Volkov is here. Volkov himself, from Moscow. They say he's known about this since 'thirty. Since 'thirty!" |
| `SVR_M1_10` | SVR | "[radio] <ru>Отступать? Куда отступать, если своих мёртвых больше, чем живых?</ru> Retreat? Retreat where, when our dead outnumber our living?" |
| `SVR_M1_11` | SVR | "[radio] <ru>Приказ: в сводке — „эпидемия у противника“. Выполняйте. Выполняйте!</ru> Order: in the report, 'an epidemic among the enemy'. Carry it out. Carry it out!" |
| `SVR_M1_12` | SVR | "[radio] <ru>Ты в Бога веришь, Миша? ...Я тоже раньше не верил.</ru> Do you believe in God, Misha? ...I didn't either, before." |

### 26.7 "GRAVELIGHT ONE" (`*_GL1_*`): the C-47, 23 December 1944

Flt Lt Harry Selwyn on the intercom (`SEL`: clipped, dry, in control until the last two, which are faint, from the
nose, after the crash) and the squad in the cabin: one line each at the window (`*_GL1_01`, said by the character at
the window) and one each for the violet light (`*_GL1_02`, one other character present). Few and frightened.

| ID | Speaker | Line |
|---|---|---|
| `SEL_GL1_01` | SEL | "[intercom] Pilot to passengers. We've crossed the Silesian border, twenty-three ten. Forty minutes to the drop. Stay strapped in, there's weather." |
| `SEL_GL1_02` | SEL | "[intercom] Navigator says that's the front below us. Those are their flares, not ours. Have a look if you like. Then don't." |
| `SEL_GL1_03` | SEL | "[intercom] Someone with glasses tell me what those columns are. On the snow. Walking west. Nobody down there is shooting at them." |
| `SEL_GL1_04` | SEL | "[intercom] Light ahead, bearing oh-four-oh. Violet. That's no flare." |
| `SEL_GL1_05` | SEL | "[intercom] Both engines— ...Both engines gone. Instruments dead. Hold on to something, chaps. I'm going to put her down." |
| `SEL_GL1_06` | SEL | "[intercom] [shouting] There's a building. Lit windows. I'll take the field beside it. Brace. Brace. Brace!" |
| `SEL_GL1_07` | SEL | "[faint] [exhausted] ...Is anyone... I can't move my legs. Get out. Get out before she burns." |
| `SEL_GL1_08` | SEL | "[faint] Co-pilot's gone. Leave me. Go on. ...God bless." |
| `DUT_GL1_01` | DUT | "[shouting over engines] That ain't a parade down there. Those are people. Hundreds of them. Where the hell are they going?" |
| `DUT_GL1_02` | DUT | "Hang on. Hang on, hang on—" |
| `PEG_GL1_01` | PEG | "[shouting over engines] Soviet greatcoats. Walking west, no formation, no weapons. Pilot, those men are walking through their own artillery." |
| `PEG_GL1_02` | PEG | "Nobody breathe. Heads down, hands on the frame." |
| `DEA_GL1_01` | DEA | "[whispers] Yea, though I walk through the valley... Lord, they are walking. Look at them walk." |
| `DEA_GL1_02` | DEA | "Hold my hand, if you want to. I don't mind." |
| `WRN_GL1_01` | WRN | "[shouting over engines] Russians. Hundreds. Walking into German guns and the guns are not firing. ...Nothing about this is right." |
| `WRN_GL1_02` | WRN | "Count with me. Jeden, dwa, trzy... it helps. Cztery..." |

### 26.8 The Moscow 1953 epilogue

Not voiced: three cards and one image (`CUTSCENES_LAZARUS.md` §5). No `NAR` line is defined; if a later cut wants a
voice, it takes `NAR_EPI53_01` here and the lead registers it.

### 26.9 Count

SER 9, VOL 16 (11 + 5), BRG 8, SVR 29 (5 + 12 + 12), RTN 16, REI 6, PA 6, SEL 8, DUT 2, PEG 2, DEA 2, WRN 2: **106
lines**, 90 of them Russian, Church Slavonic or German with a `speech` form.

## 27. Father Serafim's diary (UPDATE 11, T-190)

The seven diary pages of the Lazarus Archive (`data/gravelight/archive_lazarus.json`, `docs/LAZARUS.md` §8), read
aloud by **Father Serafim Lebedev** (`SER`, Russian, subtitled; contract C3). One page per map, in order; the last page
is on the Moon. The spoken form is in `<speech>…</speech>` before the English subtitle (T-191 teaches `extract_vo.py` to
put it in the `speech` field; until then the whole cell is the `text`). Each read-aloud is under about 45 seconds: a
man reading his own handwriting back to himself at night, by a lamp. He is never a zombie, never shown dying; the last
page's one line is his fate and nothing else is. Dates in his mouth are Old Style. Tier 4 (a story beat), once per match,
played by the Archive reader when the page is read (T-200). Audio tags sparingly: `[quietly]`, `[exhausted]`; no crying.

| ID | Speaker | Line |
|---|---|---|
| `SER_DIARY_MAP00_01` | SER | <ru>[quietly] Лазарева суббота, тридцатое марта. Приехали в девять, на грузовике, с бумагой. Колокол сняли в полдень. Последние сажени он прошёл сам и треснул о мёрзлую землю; этот звук я буду слышать до смерти. В три взорвали колокольню. Потом искали серебро, а серебра нет, и они сошли в склеп. Лампада горела. Молодой, в хорошем пальто, Волков, сломал воск на ступени алтаря, чтобы показать: там ничего нет. Там было. Оно было мокрое. Красное, не чёрное. Тысяча лет, и красное. Я сорок лет хранил лампаду, не чтобы знать, а чтобы хранить. Теперь буду хранить эту тетрадь.</ru> [quietly] Lazarus Saturday, the thirtieth of March. They came at nine, in a truck, with a paper. They took the bell down at noon. She came down the last of the way on her own and cracked on the frozen ground; I will hear that note until I die. At three they blew the tower. Then they wanted silver, and there is no silver, and they went down into the crypt. The lamp was lit. The young one in the good coat, Volkov, broke the wax on the altar step to show them there was nothing in it. There was. It was wet. Red, not black. A thousand years, and red. I kept the lamp forty years, not to know, but to keep. Now I will keep this book instead. |
| `SER_DIARY_MAP01_01` | SER | <ru>Вербное воскресенье. Вербы в этом году нет; никто за ней не пошёл. Трое из них больны: двое, что несли это по лестнице, и тот, что поймал перчатку Волкова. Жар пришёл ночью. Их трясёт, и они хотят пить так, как я не видел, чтобы люди хотели пить. На рассвете бригада ушла в Старый Брод, больные под брезентом в кузове, Волков в кабине, с портфелем на коленях. На меня он не смотрел. Думаю, хотел. Грач и Авдотья Пахомова просидели с больными всю ночь у меня на кухне, потому что кто-то должен был, и они двое так и сказали. Колокол лежит во дворе, устами в грязь. Дети к нему не подходят.</ru> Palm Sunday. No willows this year; nobody went for them. Three of them are sick: the two who carried it up the stairs, and the one who caught Volkov's glove. The fever came in the night. They shake, and they are thirsty past any thirst I have seen in a man. At first light the brigade left for Staryi Brod, the sick under a tarpaulin in the truck bed, Volkov in the cab with his satchel on his knees. He did not look at me. I think he wanted to. Grach and Avdotya Pakhomova sat with the sick all night in my kitchen, because somebody had to, and they were the two who said so. The bell lies in the yard with her mouth in the mud. The children will not go near her. |
| `SER_DIARY_MAP02_01` | SER | <ru>Великая среда. У Грача жар. У Авдотьи жар. Та же жажда. Я положил их в доме, где лежали те, и сижу с ними, потому что теперь моя очередь быть тем, кто так сказал. Возчик из Старого Брода говорит: трое умерли во вторник в тифозном бараке, и у ворот больницы солдат. Говорит: тиф. Грач, когда я ему сказал, ответил: от тифа так не пьют. Потом спросил, что было в сосуде. Я сказал: не знаю. Он сказал: сорок лет хранил и не знал? Я сказал: в этом и было всё хранение. Он засмеялся, и ему стало больно.</ru> Great Wednesday. Grach has the fever. Avdotya has it. The same thirst. I have put them in the house where the others lay, and I sit with them, because now it is my turn to be the one who says so. A carter from Staryi Brod says the three men died on Tuesday in the fever ward, and there is a soldier on the hospital gate. He says typhus. When I told Grach, he said: typhus does not make you thirsty like this. Then he asked what was in the vessel. I said I did not know. He said: you kept it forty years and did not know? I said that was the whole of the keeping. He laughed, and it hurt him. |
| `SER_DIARY_MAP04A_01` | SER | <ru>[exhausted] Великая пятница. Грач умер в четыре утра, Авдотья через час, держа мою руку так, что остались следы. В полдень через поля, не дорогой, потому что на дороге теперь солдаты, пришёл мальчик из Старого Брода. Он сказал, что ночью те трое в больнице встали. Он сказал это так, как ребёнок говорит о том, что видел. Сказал: они укусили санитара. Сказал: солдаты стреляли, а им было всё равно. Деревне я не сказал. Никто не прикоснётся к Грачу и Авдотье. Значит, я. Завтра. Под колокольней, где земля уже разбита. Четвёртый день. Я читал эту главу двести раз и ни разу с этой стороны.</ru> [exhausted] Great Friday. Grach died at four in the morning, Avdotya an hour after, holding my hand so hard I have the marks. At noon a boy came over the fields from Staryi Brod, not by the road, because the road has soldiers now. He said that in the night the three dead men in the hospital got up. He said it the way a child says a thing he has seen. He said they bit the orderly. He said the soldiers shot at them and they did not mind. I have not told the village. Nobody will touch Grach and Avdotya. So I will. Tomorrow. Under the tower, where the ground is already broken. The fourth day. I have read that chapter two hundred times, and never once from this side of it. |
| `SER_DIARY_MAP04B_01` | SER | <ru>Великая суббота. Я похоронил их сам, под упавшей колокольней, так глубоко, как может выкопать за день один старик, и прочитал над ними. У брода кордон, пулемёт и доска: ТИФ. Солдаты — мальчики. Один крикнул через воду: есть ли у нас хлеб. Есть. Пасха. Я служил в полночь в церкви без крыши, и пришла вся деревня, со свечами. Христос воскресе. Я сказал, и они ответили, и я верил, и верю сейчас, утром, когда свечи погасли. Что бы ни было в сосуде и что бы ни лежало под колокольней, это всё равно правда. Записываю, чтобы не потерять. Земля под колокольней не шевелилась. Это второй день.</ru> Holy Saturday. I buried them myself under the fallen tower, as deep as one old man can dig in a day, and read over them. At the ford there is a cordon, a machine gun and a board: TYPHUS. The soldiers are boys. One called across the water to ask if we had bread. We have. Pascha. I served it at midnight in the roofless church, and the whole village came, with candles. Christ is risen. I said it and they answered it, and I meant it, and I mean it now, in the morning, with the candles out. Whatever is in the vessel, and whatever lies under the tower, this is still true. I write it down so that I do not lose it. The ground under the tower has not moved. It is the second day. |
| `SER_DIARY_MAP04C_01` | SER | <ru>[quietly] Светлый понедельник. Четвёртый день. Они вышли вскоре после темноты. Я был в церкви и услышал, как упали колышки с верёвкой. Я не стану писать, какие они. Кто прочтёт, тот знает, или ему не нужно. Я ударил молотом по колоколу, где он лежит, потому что деревня знает одно: колокол зовёт — иди. И они пришли, бегом, и я закрыл двери брусом изнутри. Сорок один человек. Дети спят на сундуках с ризами. Грач и Авдотья всю ночь ходили вокруг церкви, медленно, как ходят больные, а утром стояли у двери и не трогали её. Они не трогают дверей. Они ждут. Господи, я похоронил их своими руками и сказал слова. Слова были верные. Не слова были неверны.</ru> [quietly] Bright Monday. The fourth day. They came up a little after dark. I was in the church and heard the rope posts fall. I will not write what they look like; whoever reads this will know, or will not need to. I struck the bell where she lies, with the smithy hammer, because a bell is what the village knows to come to, and they came, running, and I barred the doors from inside. Forty-one of us. The children are asleep on the vestment chests. Grach and Avdotya walked round the church all night, slowly, the way the sick walk, and in the morning they stood at the door and did not try it. They do not try doors. They wait. Lord, I buried them with my own hands and I said the words. The words were right. It is not the words that were wrong. |
| `SER_DIARY_MAP04D_01` | SER | <ru>[quietly] Одиннадцатое. Три дня в церкви. Они не войдут: человек с рупором сказал дважды, что уезд закрыт по тифу и помощь идёт, а потом рупор замолчал. Пётр Ильич ведёт счёт дням мелом на стене, потому что четвёртый день — это теперь единственное. Масла в лампаде на одну ночь. Мы хранили её пятьсот лет, и никто из нас не знал зачем, а те, кто открыл, были не злые люди. Люди с бумагой и грузовиком. Только этого и было нужно. Кто найдёт это: виноват не Господь, и не тот бедный мальчик в хорошем пальто, не во всём. Виновато то, что некому стало сторожить. Сторожите. Я иду в склеп заправить лампаду, а потом сам выйду за дверь церкви, и Пётр Ильич заложит её за мной брусом, чтобы никому из них не пришлось идти. Помяни, Господи, раба Твоего Серафима, и Матвея, и Авдотью, и всех их, по именам.</ru> [quietly] The eleventh. Three days in the church. They will not come in: a man with a megaphone said twice that the district is closed for typhus and help is coming, and then the megaphone said nothing more. Pyotr Ilyich keeps the count of the days in chalk on the wall, because the fourth day is the only thing now. Oil in the lamp for one more night. We kept it five hundred years and none of us knew what for, and the ones who opened it were not wicked men. Men with a paper and a truck. It only ever needed that. Whoever finds this: it was not the Lord who did this, and not that poor boy in the good coat either, not all of it. It was that nobody was left to keep watch. Keep watch. I am going down to the crypt to fill the lamp, and then I will go out through the church door myself, and Pyotr Ilyich will bar it behind me, so that none of them has to be the one who goes. Remember, O Lord, Thy servant Serafim, and Matvei, and Avdotya, and all of them, by name. |
