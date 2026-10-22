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
