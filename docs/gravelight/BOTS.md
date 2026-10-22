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
The nearest bot acknowledges (VO `CMD_*`) and a banner shows the order.

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
