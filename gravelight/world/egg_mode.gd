class_name EggMode
extends RefCounted
## T-181: Easter Egg Mode, a practice match for the egg (the owner: "make a mode where the zombies just don't spawn,
## or they spawn very minimally as crawlers"). A match option (GLSettings egg_mode: off / sparse / none; Settings >
## Gameplay and the map-select screen's top row); the host's setting decides, captured at match start
## (GameState.egg_mode). Numbers in data/gravelight/rounds.json "egg_mode".
##   sparse  each round queues a few crawlers (count.base, +1 every count.per_rounds, at most count.max), all with
##           capped health; the round ends when they die or after round_max_s;
##   none    no round queue at all: a round lasts round_s and the next one comes after the normal break.
## What still comes, so the egg can finish: every boss and set piece an egg step summons (the Foreman at the Chapel
## bell, der Kielholer, the Heartstorm's waves, the diesel holds' boarders: their own spawn paths, as crawlers
## where they take an ordinary zombie), a few crawlers while a hold runs (hold_active) and, while a kill-count step
## is open (Requiem's 30 Totenglocke kills, Fernflug's tunnel), a steady feed of crawlers (feed_active).
## Off: no Bellringer rounds, no scheduled Foreman, no Screamer or Glasshide rolls, no homage boss rounds.
## Practice: no profile progress (XP, challenges, stats, best round, map unlocks, egg rewards and egg records); the
## match's own in-game rewards (the egg's tonics, Scrip) still pay. Pure rules here, unit-tested (test_egg_mode.gd).

const SETTING: String = "egg_mode"
const MODES: PackedStringArray = ["off", "sparse", "none"]
const MODE_LABELS: PackedStringArray = ["Off", "Few Crawlers", "No Zombies"]
const HUD_TEXT: String = "EASTER EGG MODE · practice, no progress"


static func mode_of(values: Dictionary) -> String:
	var m: String = str(values.get(SETTING, "off"))
	return m if MODES.has(m) else "off"


## The match's mode (GameState.egg_mode, set at match start; while a map loads, before MapRoot's reset_match, its
## children read the setting itself: the Kielholer / Cousins reserve their rounds in their _ready).
static func current() -> String:
	var m: String = str(GameState.egg_mode) if GameState.phase == GameState.Phase.PLAYING else mode_of(GLSettings.values)
	return m if MODES.has(m) else "off"


static func on() -> bool:
	return current() != "off"


static func cfg() -> Dictionary:
	return (GLData.table("rounds") as Dictionary).get("egg_mode", {})


## The round's queue in this mode (normal = the normal count, which it never exceeds).
static func round_count(mode: String, round_number: int, normal: int, c: Dictionary) -> int:
	if mode == "none":
		return 0
	if mode != "sparse":
		return normal
	var cc: Dictionary = c.get("count", {})
	var per: int = maxi(1, int(cc.get("per_rounds", 10)))
	var n: int = int(cc.get("base", 2)) + int(float(maxi(0, round_number - 1)) / float(per))
	return mini(normal, mini(n, int(cc.get("max", 4))))


## How many zombies may be up at once beyond the queue: feed (a kill-count step open) beats a hold.
static func extra_cap(mode: String, held: bool, feed: bool, c: Dictionary) -> int:
	if mode == "off":
		return -1
	if feed:
		return int(c.get("feed_active", 6))
	if held:
		return int((c.get("hold_active", {}) as Dictionary).get(mode, 0))
	return 0


## The round is over (no hold running): every queued crawler came and died, or the round ran its time (what is
## still queued then is dropped: crawlers left from earlier rounds can fill the cap, and the round must not wait).
static func round_over(mode: String, elapsed: float, to_spawn: int, alive: int, held: bool, c: Dictionary) -> bool:
	if mode == "off" or held:
		return false
	if mode == "none":
		return elapsed >= float(c.get("round_s", 25.0))
	if elapsed >= float(c.get("round_max_s", 60.0)):
		return true
	return to_spawn <= 0 and alive <= 0


## A crawler spec's health: the normal health of round min(round, health_round_cap).
static func health_round(round_number: int, c: Dictionary) -> int:
	return mini(maxi(1, round_number), int(c.get("health_round_cap", 5)))


## Step types that need ordinary zombies to die (the feed).
static func feeds(step_type: String, c: Dictionary) -> bool:
	return (c.get("feed_step_types", ["kill_count"]) as Array).has(step_type)


## Is a kill-count step of a loaded quest open now?
static func feed_wanted() -> bool:
	var c: Dictionary = cfg()
	for qid: StringName in QuestManager.quest_ids():
		for st: Variant in QuestManager.steps_of(qid):
			var s: Dictionary = st
			if feeds(str(s.get("type", "")), c) and QuestManager.is_active(qid, StringName(str(s.get("id", "")))):
				return true
	return false
