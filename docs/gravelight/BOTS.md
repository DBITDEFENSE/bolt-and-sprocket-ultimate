# GRAVELIGHT AI teammates (bots)

Bots fill the empty survivor slots in a solo match (Play → pick a survivor → "Squad: you + N bots"). The base
behaviour is T-031: they follow, shoot, rebuild boards, buy guns, perks and doors with their own Scrip, use the
Crucible, revive you and each other. Code: `gravelight/bots/`. Tuning: `data/gravelight/bots.json`. Tests:
`gravelight/tests/unit/test_bots.gd`, `test_bot_planner.gd`; smokes `smoke_bots.tscn`, `smoke_bot_ai.tscn`.

## Spawn kit (2026-10-21)

Every bot spawns with a **Thompson** in hand (the start pistol stays in slot 1), **Ironhide Stout** (the
Juggernog equivalent: 250 health) and **Second Wind Schnapps** (the Quick Revive equivalent: 2× revive speed).
The kit is free and ignores the power rule. Co-op rules still take every perk on going down, so the kit perks come
back when the bot is revived; after a bleed-out respawn the Thompson comes back too (`spawn_kit.restore_after_down`).
A campaign arrival with a full loadout is never overwritten. Bots can still buy up to two more perks
(`shopping.max_perks` is 4, the perk cap).

Change the kit in `bots.json → spawn_kit` (`weapons`, `hold`, `perks`).

## The local-AI bot (2026-10-21)

With **"Local AI bot: On"** in the squad menu (default on; also a checkbox in the dev launcher), one bot (the
first, `local_ai.bot_index`) gets a **planner** that chooses its own objective instead of tagging along:

- the map's **easter egg**, step by step, read live from the quest system (any loaded quest, so new eggs work
  without bot code as long as they use the existing step types): radio notes, the Map 0 radio frequencies, Map 1
  radios, the switchboard code, Totenglocke parts and the workbench, pylons (pays and holds the ring), lighting the
  Chapel bell with an upgraded gun and holding the Chapel for the Foreman, the altar, the Four Bells in order, pulling
  the crate for Herr Tamtam and shooting him, the shard, Totenglocke kills at the heart, the Heartstorm;
- the **power**, a **door that blocks** an egg step, and the usual shopping (perks, wall guns, ammo, the Crucible,
  boards);
- **sticking with the team** (its score rises when zombies crowd the human or the human is hurt).

Every few seconds (`decide_every_s`, 4 s) the planner lists those options with a score. A **local LLM served by
Ollama** reads a short summary of the match (round, health, Scrip, guns, perks, teammates, quest progress) and the
option list, and answers with one option id (structured output: the ids are an enum, so it can't invent one) plus
a short remark, shown as a subtitle in the bot's voice. The bot's body still does all the moving, aiming and
shooting, and fights, revives and flees on its own first.

If Ollama isn't installed or running, is still loading the model, takes longer than `timeout_s`, or answers
nonsense, the planner uses its own scores (the scripted planner), so the bot never stalls. The game starts
`ollama serve` itself (no window) when the API is down and the exe is found (`autostart_ollama`).

**Setup:** install Ollama (https://ollama.com) and pull a model, e.g. `ollama pull gemma3:27b` (best decisions;
~17 GB VRAM, ~1.2 s a decision on an RTX 5090) or `gemma3:4b` (fast, 3.3 GB). The first installed model in
`local_ai.models` is used: `gemma3:27b`, then `gemma3:4b`, then `gemma4:31b`. The first request loads the weights
(20–50 s, in the background); `keep_alive` keeps them loaded for 30 minutes.

Measured (smoke_bot_ai, Map 0, 2026-10-21): the scripted planner finishes "Glasmacher Calling" alone in ~117 s;
with gemma3:27b in ~84 s; 16 of 16 model answers valid. The squad report (dev console, smoke logs) prints a
`planner [...]` line per planner bot: model, latency, how many picks came from the model vs. the scores, and the
current objective.

### Limits

- Only the host/solo match has bots; the planner never runs in online co-op.
- The planner bot roams the whole map on its own; on later rounds alone it can go down far from help.
- Egg steps that need luck (the crate drummer) or a long fight (the Heartstorm, the Foreman in the Chapel) are
  attempted but not guaranteed; the Map 1 Requiem is long and the bot usually needs the human's help to finish it.
- Map 2 Totenhafen has no easter egg yet, so its planner bot does the power, doors, perks and guns.

## Update 02 (T-050): bonus perks, the command wheel, nameplates, character bodies, better squad play

### Bonus perk
At match start each bot gets **one random perk, free, outside the perk cap** (`PerkManager.grant_bonus`), drawn
from the perks this map's machines sell, never a spawn-kit perk (Ironhide Stout, Second Wind), never one in
`bonus_perk.exclude`, and no two bots the same (`BotConfig.pick_bonus_perks`, unit-tested). When a bot goes down it
loses its perks like a player, **except the bonus perk** (its trait); the kit perks come back on getting up as
before. It shows as a gold-ringed bottle cap with a star on the bot's nameplate and in the squad ledger (the co-op
HUD list, which is the match's scoreboard). The bot says a line about it in character the first time it matters
(`bonus_perk.triggers`: Trigger Tonic on the first reload, Twin Barrel on the first burst, Marathon on the first
sprint, Hawkeye on the first headshot kill, Packmule on the first weapon swap, Blastproof at the first explosion
nearby, Overclock at its first burst, Ironhide when first hurt, Second Wind on the first revive), or at the start
of round `fallback_round` (4) if that hasn't happened. Lines: VO_SCRIPT §13 (`BONUS_<perk token>`), voiced with
the offline TTS bake. **Settings → Gameplay → "Bot Bonus Perk"** (`bot_bonus_perk`, default on) turns it off.

### Squad orders (the command wheel)
Hold **T** (pad: **D-pad down**; action `bot_command`, rebindable) to open a radial menu; steer with the mouse
(the mouse stays captured, the camera holds still while the wheel is open) or the right stick; release to give the
order to every bot (`BotSquad.set_command`); release in the middle to cancel. The game is not paused.
- **Follow me** (top, the default): the formation below.
- **Hold here** (right): the spot under the crosshair (up to `commands.hold_point_range_m`, else your feet); the
  bots stand in a ring round it, fight from there, repair only boards within `hold_repair_radius_m`, never
  teleport; they still revive anyone.
- **Repair barricades** (bottom): boards first, anywhere within `repair_range_m` of you, also mid-round when
  nothing is within `repair_quiet_m`.
- **Revive priority** (left): revive at once even under fire (only something in knife reach stops it), no
  shopping, a tight follow (`revive_follow_m`).
The nearest bot acknowledges (VO `CMD_<ID>`) and a banner shows the order.

**The order list is data:** `bots.json → commands.orders` (`[{"id", "label"}]`, clockwise from the top; the wheel
splits into as many segments as there are entries). Every order given emits `BotSquad.order_given(order_id, at)`;
the brains act on the four built-in ids (`BotConfig.COMMANDS`), any other id (Update 03: "train", "buy_perks",
"save_scrip", "open_door", "fetch_part") is only emitted, for the new AI layer to handle. API:
`BotSquad.set_command(id, at)`, `BotConfig.orders / order_ids / order_label`, `BotCommandState` (pure, tested).

### Formation and making way
- **Training:** while you move faster than `follow.moving_speed_mps`, the slots sit **beside and a little ahead**
  of your heading (`moving_slots`, predicted `lead_s` ahead), never behind you (where you back into and the horde
  follows), and a fighting bot keeps moving with you, shooting on the move, instead of holding its ground.
  Standing still they take the old slots round your facing.
- **Making way:** you walking into a bot (within `nudge_near_m`, heading at it) makes it step aside; a bot parked
  in a **choke point** (an open doorway, a staircase or ramp slab, a passage narrower than 2 × `narrow_half_width_m`
  measured with two rays) with you within `choke_near_m` moves out; formation slots and teleports avoid choke
  points; a bot never parks in one (`_leave_choke`).
- **Soak check:** every time a bot stays inside a door / stair volume longer than `choke_report_s` (3 s, not
  while reviving) `BotSquad.choke_events` gets a line; the squad report prints them (`CHOKE ...`).

### Survival (measured, not reached)
Playtest bot, Map 0, solo + 3 regular bots, 13-round target, 4 runs per batch. Baseline (before): wiped round 5.
After the formation / make-way / revive / resupply changes: rounds reached 5–8 (batches a–d: 8, 6, 6, 8 / 7, 7, 5, 8 /
5, 7, 6, 8 / 6, 7, 8, 7), bot revives of the human 0–3 per run, revives between bots 0–2. **Round 12 is not reached.**
The down log (`DOWN ...` lines in the squad report) shows the pattern: the human goes down first (cellar, stair hall),
the bots' main guns run dry mid-round and they fall back to kiting with the start pistol in cramped rooms. Update 03
replaces the decision layer; the telemetry (down log, choke reports) is there for it.

### Other behaviour
- **Traps:** any node in the `traps` group with `danger_contains(point)` (the live wire, the ore cart, the
  chandeliers on Map 1) is avoided while live: bots leave it, wait outside it, and don't pick slots or errands in it.
- **Easter eggs:** an ordinary bot never notifies quest shootables (bells, the drummer); only the local-AI planner
  bot (with the AI setting on) does egg steps, as before.
- **Barks:** "Reloading!" (a long gun near zombies), "Board's up!", "I've got you, hold on!", low ammo, power-up
  sightings, from each character's voice (VO_SCRIPT §13), rate-limited for the squad (`callouts.cooldown_s`) and per
  bot per family (`callouts.per_bot_cooldown_s`); orders, bonus perks and downs skip the squad gap.
- **Between waves** the board-repair radius grows (`repair.break_radius_mult`).

### Bodies and nameplates
`RemoteBody` gives each survivor a distinct silhouette (Dutch: netted helmet, broad build, BAR belt, low wide
stance; Peg: tilted beret, cross strap and two satchel charges, wristwatch; Deacon: one-colour mechanic's coveralls
with grease stains, knit cap, the wrench on his belt; Wren: white smock, scarf, AK armband, the notebook at her belt
and the scoped Springfield slung across her back), and procedural poses: reload, drink (a perk), buy, repair (a
plank to the window), revive (kneeling), downed, and per-character idle fidgets when calm (Wren writes in her
notebook, Deacon taps with his wrench, Dutch stretches his back, Peg checks her watch). Co-op teammates use the same
body; their actions come from the replicated events and the reviver state. Bolt and Vendelin aren't selectable
in the Gravelight menu yet, so they have no body outfit. `gravelight/tools_src/shots_bot_bodies.tscn` renders the
contact sheets.
Each bot wears a **screen-space nameplate** (`BotPlates`): name, perk caps (bonus first, ringed), health bar
(bleed-out bar while down); fixed size at any distance, faded out behind walls (one camera ray per bot, a few
times a second) and beyond 60 m.

### Companion hooks (for Jakub, U02 §6)
- `BotSquad.add_brain(player, options)` adds a brain for any Player (it gets orders, revives, repairs, follows).
- `BotBrain.options`: `perks` (false: no kit / bonus / perk shopping), `bonus_perk`, `shopping` (false: boards
  only), `kit` (false: no spawn kit), `accuracy_mult` (aim error scale; ~1.4 for "70% of a player").
- `Player.bleedout_seconds` (> 0) gives that player its own co-op bleed-out clock (NetMatch.coop_downed).
- Not counting as a player for zombie scaling: keep the companion out of `GameState.bot_ids` / `player_ids`
  scaling (MapRoot.scaled_player_count counts those); ammo boxes come from the §4 builder's `ammo_box` errand.
- Update 03 adds `personality` ("jakub"), `escort_pid` (the player who freed him: he stays a step behind them),
  `armed` (false: the coal shovel, melee only), `ammo_payer_pid` / `ammo_price_mult` (the party pays, half price:
  AmmoBox.use_holder) and `revive_priority` (2: revived after the human and the bots). See docs/BOT_AI.md section 5.
- **Built (U02 §6.2, T-051): `JakubCompanion`** (`gravelight/world/jakub_companion.gd`, data `companion_jakub.json`).
  He is a bot-style Player with `is_companion` and a fixed pid (9) that is in no `GameState.player_ids` / `bot_ids`, no
  `MapRoot.players`, no lobby slot and no round scaling. In a solo match without bots `MapRoot.ensure_companion_session()`
  makes the offline session and an empty BotSquad for him (no co-op HUD; the human keeps the solo rules: Jakub can't pick
  you up in pure solo, he can with bots or in co-op). `NetMatch.add_companion` / `CoopState.companions`: he goes down,
  is revived and bleeds out (60 s) like anyone, never respawns, and never keeps a match alive alone. `BotSquad.add_brain`
  now builds the plates / wheel / pings for a squad that had no bots, `player_by_id` finds companions, `remove_brain`
  drops a bled-out one. `Zombie.forced_target` is how the breakout zombie goes for him. The blackboard never hands out a
  freed zombie any more (a Homage boss that retreats is freed, not pooled; that raised "freed object" errors).

## Update 03 section 3 (T-056): how bots move

Bots now move with the human's own movement code: the same acceleration, sprint stamina, sprint-out before the
first shot, slide and mantle, and a player's turn rate. Their bodies face the way they walk unless they are aiming.
They keep out of your 1.2 m personal space, step aside when you walk at them, never park in doorways, on stairs or
on your training line, and run training loops ahead of the horde (`data/gravelight/ai/routes_<map>.json`). When one
is really stuck it re-plans after 2 s and wriggles free after 4 s. After 8 s it teleports, but only where nobody
can see it. Details, the API and the numbers are in `docs/BOT_AI.md` section 4. Turn it off with `bots.json`
`"locomotion": "v1"`.

## Update 03 (T-055): a new brain

The bots' decisions are rebuilt from scratch. Each one weighs everything it could do several times a second
(fight, train, hold a window, retreat, reload, revive, cover a revive, repair, buy, the crate, a power-up, follow,
regroup, an order) and does the best, without flip-flopping. Architecture, tuning and numbers: `docs/BOT_AI.md`
sections 5 and 6. All the tuning is in `data/gravelight/ai/*.json`.

- **They play fair.** A bot knows a zombie only when it saw it (a 110 degree view and line of sight), heard it
  (groans close by, a sprinter's scream, boards being torn off, a boss), or a teammate did, and it remembers that for
  4 seconds. The old free pistol refill and the hidden 10 % damage reduction are gone. They keep the visible spawn
  kit and their bonus perk.
- **Shooting like people.** A short reaction delay, then the aim swings onto the target, a little past it and back,
  and steadies. They prefer heads, burst at range, take single shots with rifles, never shoot through you, and don't
  spray at what they can't hit. They reload when it's safe (never with a sprinter in their face; they swap guns
  instead) and top up every gun between waves. A dry Thompson no longer leaves them on the start pistol all round.
  Grenades go only into groups clear of the squad, or onto bosses. They knife crawlers, never bosses.
- **Teamwork.** One bot claims each revive (the human first, then bots, then Jakub). It waits while a sprinter is on
  the downed teammate unless the bleed-out clock is short, and goes anyway under 8 s. A second bot covers a hot revive
  from the far side. The bots split roles (Anchor, Runner, Medic, Builder) by personality.
- **Callouts with pings.** "Sprinter, behind you!", "Boss incoming!", "Crate's moved", "Window's open", "Covering
  you", every power-up by its name, "Reloading!", "I need ammo", each with a small marker at the spot. Peg calls
  bosses first, Wren keeps a kill tally, Dutch grumbles when you move him. New lines: VO_SCRIPT section 15.
- **Power-ups.** They take Resupply and Fortify when it's safe. Death's Door, Double Scrip, Blackout and Clearance
  they leave for you unless you're there too. They never take one you are walking toward.
- **Their own Scrip.** Perks in order (Ironhide, Second Wind, then Trigger Tonic or Twin Barrel by gun), a wall gun
  only when it beats what they carry (never a Kar98k after round 10), ammo boxes when running low, the Requisition
  Crate with Scrip to spare, the Crucible for a good gun. They always keep a reserve. They never take your crate roll
  or your Crucible weapon. They never touch easter-egg objects, traps or the power switch unless you order it or
  already did that step (the local-AI planner bot is the exception you asked for). Doors: only when ordered, or when
  you opened the way and stand by the next one.
- **The command wheel has nine orders.** Follow me, Hold here, Train with me, Repair windows, Revive priority, Buy
  perks now, Save Scrip, Go open that door (or the power switch you're looking at), Fetch that part (the buildable
  part you're looking at). Each lasts 60 s or until done.
- **Bot Skill: Recruit / Veteran / Elite** (Settings -> Gameplay, and the squad menu; default Veteran; old saves map
  green -> Recruit, regular -> Veteran). It changes reaction, aim, decision quality and spending, never health.
- **Personalities.** Dutch anchors and loves LMGs; Peg flanks, saves Scrip and throws the best grenades; Deacon
  revives and repairs first; Wren takes rifles and kills specials first. Bolt, Vendelin and Jakub have profiles ready.
- **Special enemies.** They shoot the Hammer while her mallet is in the air, shoot the Reach's wrist the moment she
  holds someone, keep out of Alix's reach and focus her while she kneels. Counters for Paul, the Slender, Frostbiss,
  the Bergwacht and the Treibstoff-Gaenger are in `ai_counters.json`, ready for when they exist.
- **Debug:** dev console `ai_debug 1` (action, top scores, role and target over each bot, path lines), `ai_debug
  panel` (the squad blackboard), `ai_debug heat` (a threat heatmap on the floor), `ai_debug 0`.


## Update 04 section 5 (T-067): bots on the easter egg

UPDATE_03 said bots never touch easter-egg objects. Now they can, when you allow it: **Settings -> Gameplay -> Bot
Easter-Egg Help**:

- **Off:** bots never touch egg objects (the local-AI planner bot doesn't either, any more).
- **When Asked** (the default): a bot only does a step you give it: the Objectives tab's "Assign to bot", a map mark
  or the ping key on an egg object, part or power-up, or the dev console. The best bot takes it (closest, able, not
  busy reviving) unless you pick one.
- **Full Partner:** up to two bots at a time pick open steps they can do themselves, one task each, and say so ("I'll
  go pick those up. Cover the windows." with a ping on the note). The last steps wait for you to be there.

How a bot does a step is data: every step in `data/gravelight/quests/*.json` has a `bot_task` (task types Collect,
Shoot target, Hold zone, Carry, Interact sequence, Kill with weapon X near Y, Escort/defend the player, Turn key; the
schema is in `docs/gravelight/EASTER_EGGS.md` section 9). Code: `gravelight/bots/bot_ee_catalog.gd` (the rules, pure),
`bot_ee_knowledge.gd` (what the squad knows), `bot_ee.gd` (one bot's task: a planner and an executor per type),
`bot_ee_hub.gd` (the setting, assignments, Full Partner, discoveries, console). Numbers: `data/gravelight/ai/ee.json`.
The local-AI planner no longer lists egg steps (every bot works the egg through this now).

- **Puzzle knowledge.** Bots know only what the squad found out: the frequencies once all three notes are read, the
  switchboard code once the three radios were heard, the bell order once the music box played, where the four little
  bells and the Totenglocke parts are once someone (you or a bot) saw them, the calling radios once someone heard them.
  Until then: "Can't do that yet: we haven't heard the music box's melody." A debug-skipped step teaches nothing.
- **Never breaks the egg.** A bot only ever makes the input the sequence expects next (read from the quest, never a
  guess); its bullets ring only the bell it is aiming at; it never makes the input that finishes a step whose last
  input is your commit (Map 0's radio: it locks two frequencies and says "Last one's yours"); it never pulls the
  crate for the drummer or lights the Chapel bell (both can fail a step) unless you ordered it; at the Crucible it
  only places the shard while the quest is ready for it, so it never hands its gun to the forge by mistake.
- **Player-only steps** (cutscenes, the final step's commit, story choices, the Crucible weapon handoff, giving Jakub
  a gun): asked to do one, the bot covers you while you do it ("That one's yours, partner. I'll watch your back.").
  Today: the Requiem ending, the phonograph, Wren's tag; the Heartstorm's start (the bots hold the Core once it runs).
- **One task at a time, and the fight first.** Egg work pauses when the bot is under pressure, a teammate is down or
  the round is ending (for 20 s at most, so a round that drags on doesn't stop the work), and resumes ("Back to it.").
  Holding a zone keeps holding through all that: that is the job. A bot opens a door in the way with its own Scrip
  (the first closed door on the way there).
- **Jakub** carries, collects and holds ground; he refuses the Crucible, the perk machines and anything else, in
  character ("Not the furnace. I have seen what fires like that get fed. Ask me anything else.").
- **Voice:** VO_SCRIPT section 18 (acknowledge per task type, progress, done, the hand-over, can't with the reason,
  interrupted, back to it), every survivor and Jakub; unbaked for now, they play as subtitles.
- **Debug:** `ai_debug 1` shows each bot's egg task over it ("EE map00_radio/s1_notes: Collecting the radio notes
  (2/3)") and the panel lists the squad's discoveries; `ee_bot_mode off|ask|full`, `ee_bot_assign <step> [quest]
  [pid]` (`ee_bot_assign cancel`), `ee_bot_status`.
- **API** (the Objectives tab and the map marks call these): `BotSquad.ee_assign(quest_id, step_id, pid = -1) ->
  {ok, reason, pid}`, `ee_can_assign(quest_id, step_id) -> bool`, `ee_task_of(pid) -> {quest_id, step_id, type, label,
  state, paused, source, ordered, pid}`, `ee_cancel(pid = -1)`, `ee_assign_node(node, pid = -1)` (finds the open step
  the object belongs to and makes it the task's focus: that note, that bell).
- **Tests:** `gravelight/tests/unit/test_bot_ee.gd`; smokes `smoke_ee_bots` (When Asked: marks, assignments, the
  hand-over, Off) and `smoke_bot_ai` (Full Partner); soak `tools/ai_soak.sh --scenario=ee_full --runs=3`.


## Update 04 section 3 (T-069): map marks and the ping key

Mark something on the pause page's MAP tab (or with the ping key: middle mouse / D-pad up) and pick who it is for: a
bot by its portrait, Any bot (the closest free one that can afford it), Jakub, or yourself. A mark for a bot is its
order (one each; a new one replaces the old), the action `mark_order` on the utility AI. Revives come first; the order
resumes after ("Back to it.").

- **BUY THIS** (perk, wall weapon, ammo, a door you confirmed, the crate, the Crucible, a trap, the Armorer's Bench):
  it says it's on it, checks its Scrip, walks over and buys it, and says so; short, it tells you by how much ("Need
  600 more for that, boss.") and waits up to 60 s while it earns. A wall weapon marked **for me**: it buys it with its
  own Scrip and drops it at your feet (or you take it off the bot).
- **DEFEND HERE** (holds ~4 m, rebuilds the windows close by), **REGROUP** (every bot comes), **DANGER** (every bot's
  paths avoid it for 60 s; the nearest calls it out), **GO HERE**, **COLLECT / ACTIVATE** (an egg object goes to the
  section 5 egg help: the setting, what the squad knows, Jakub's limits).
- The map shows each bot's order line by its portrait ("Going to buy Ironhide Stout (1,200 short)", "Defending Rail
  Yard", "Doing: ...", "Idle").
- Jakub goes, defends, regroups and does what section 5 lets him on the egg; he never buys anything.

Details, the APIs and the tuning: `docs/gravelight/MARKS.md`; lines: VO_SCRIPT section 19; tests: `test_mark_orders.gd`,
`smoke_marks`.


## Player bot mode (T-071): an agent plays your survivor

Press **F6** (Settings > Controls: "Bot mode (an AI plays you)"), tick **Bot mode** on the pause menu's Settings page,
or type `botmode on` in the dev console, and a local agent plays your own survivor while you watch in first person.
The HUD says **BOT MODE — press F6 to take over**, with what it is doing under it ("training: face, 6 following
(round the taproom tables)", the planner's next purchase). Any real input hands control back at once: a move key or
the stick, fire, aim, jump, sprint, reload, use, knife, a grenade, a weapon key, or a real mouse / right-stick move
(keys you were already holding when you switched it on don't count until you let go). F6 again also stops it.

- **What plays you:** the bots' own Update 03 brain (perception without wallhacks, the utility actions, the aim layer,
  the economy, revives) on your Player through the same movement code (BotLocomotion on your MoveIntent). It aims with
  the Elite preset and turns your view on a damped curve (never a snap). It shops with your Scrip (no free bot kit)
  by a **game plan** per map (`player_bot.json` "plans"; pass 2): on the Crossroads Inn the Garand, the cellar door
  and the power, Second Wind (your solo self-revive), Ironhide, the stable and the yard, the Thompson on the stable
  wall, Marathon, then the Crucible; on Kaltenbrunn the carbine, the Rail Yard and the MP40, Second Wind in
  Administration, the Barracks, the lift and the Generator Hall for the Hauptschalter, Ironhide, Marathon, the StG-44.
  Ammo, an ammo box and the boards are always allowed; nothing else jumps the queue.
- **Training:** once the plan's training ground is open (Map 0: the yard's Well Loop, the map's open ground; Map 1:
  the Generator Hall's turbine loop) it **owns every round**: it lets the round come out and group up behind it
  (a train of 5-11, more in later rounds), walks the loop's own line, picking a lane across the ring that keeps it
  clear of where every zombie will be in the next second and a half (and turning back round the loop when that is
  clearer), and turns on the train to fire while it walks backwards round the loop (there is no backpedal penalty:
  a walk backwards outpaces a jog). It sprints (facing the way) when the head of the train gets within reach, reloads
  on the walk, shoots what cuts in ahead, glances forward every few seconds, and stands still to aim at the round's
  last few. Before that (and in a special round before it) it holds the taproom and fights, training only a horde of
  four or more. It never walks back to its loop through zombies already close: it fights where it is first.
- **The bots and Jakub** follow it as their leader, as they would follow you; with nobody human leading, the squad's
  "bots alone" rules apply (it may throw the power, and they drink).
- **Local AI:** with the Bot Local AI setting on and Ollama running, the local model picks what to buy or open next
  (the planner); without it the scripted planner does, and everything else is the same.
- **Co-op:** only the host can hand over their survivor (a client's world is the host's).
- **Launcher:** `res://gravelight/tools_src/play_botmode.tscn` (args `-- --map=map00|map01 --bots=N --round=R`), or
  `--botmode` on any map.
- Tuning: `data/gravelight/ai/player_bot.json`; the design and the numbers: `docs/BOT_AI.md` section 10.
