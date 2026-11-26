class_name Citations
extends RefCounted
## UPDATE 10 s6 item 9 (DECISIONS T-162; data/gravelight/citations.json): the achievements. A citation is earned once
## per profile (ProfileSave.profile["citations"][id] = true), announced by a HUD toast (GLBus.bonus_awarded with the
## kind `citation`, which the HUD already draws as a slip above the Scrip) and listed on the Service Record
## (MenuStats). The pure rules are static so the tests can drive them without a map:
##   defs()              every citation that is listed (a guard that fails hides it: Totenhafen's egg until it lands)
##   fire(event, info)   earns every citation whose event and filters match; returns the ids earned now
##   earned(id) / rows() the profile's state for the Service Record
## `info` keys: map (the current map id), enemy (an enemy id), quest (a quest id), count (a running count).

const PATH: String = "res://data/gravelight/citations.json"

static var _cache: Array = []


static func all_defs() -> Array:
	if _cache.is_empty():
		_cache = GLData.load_json(PATH).get("citations", [])
	return _cache


## Is this citation available in this build (its guard file / signal exists)?
static func available(c: Dictionary) -> bool:
	if c.has("guard_data") and not FileAccess.file_exists(str(c["guard_data"])):
		return false
	if c.has("guard_signal") and not GLBus.has_signal(StringName(str(c["guard_signal"]))):
		return false
	return true


static func defs() -> Array:
	var out: Array = []
	for c: Dictionary in all_defs():
		if available(c):
			out.append(c)
	return out


static func def_for(id: String) -> Dictionary:
	for c: Dictionary in all_defs():
		if str(c.get("id", "")) == id:
			return c
	return {}


static func earned(id: String) -> bool:
	return bool((ProfileSave.profile.get("citations", {}) as Dictionary).get(id, false))


static func count_earned() -> int:
	var n: int = 0
	for c: Dictionary in defs():
		if earned(str(c["id"])):
			n += 1
	return n


## Pure: does `c` answer this event? (the map must match when the citation names one, and the enemy / quest ids.)
static func matches(c: Dictionary, event: String, info: Dictionary) -> bool:
	if str(c.get("event", "")) != event:
		return false
	# (a boss or an egg counts wherever it falls; the map-bound events must happen on the citation's map)
	var map_bound: bool = event in ["wing_walk", "orbit", "spring_tide", "special_survived"]
	if map_bound and c.has("map") and info.has("map") and not str(info["map"]).begins_with(str(c["map"]).get_slice("_", 0)):
		return false
	if c.has("enemy") and str(info.get("enemy", "")) != str(c["enemy"]):
		return false
	if c.has("quest") and str(info.get("quest", "")) != str(c["quest"]):
		return false
	if c.has("target") and int(info.get("count", 0)) < int(c["target"]):
		return false
	return true


## Earns one citation: the profile flag, a save, the toast. Returns false when it was already earned or unknown.
static func award(id: String) -> bool:
	var c: Dictionary = def_for(id)
	if c.is_empty() or not available(c) or earned(id):
		return false
	if not (ProfileSave.profile.get("citations", null) is Dictionary):
		ProfileSave.profile["citations"] = {}
	ProfileSave.profile["citations"][id] = true
	ProfileSave.save_profile()
	GLBus.bonus_awarded.emit(Net.local_player_id(), &"citation", 0, "CITATION: %s" % str(c.get("name", id)))
	return true


## An event happened: earns every citation it answers. Returns the ids earned now.
static func fire(event: String, info: Dictionary = {}) -> PackedStringArray:
	var got: PackedStringArray = []
	if Zombie.t283_opt and Zombie.t283_death:
		# T-283: the event first, then the guard: available() asks the disk for a file, and every zombie's death fires
		# "boss_killed" (FirstHints), 0.1 ms a kill for nothing. The same citations in the same order are earned.
		for c2: Dictionary in all_defs():
			if matches(c2, event, info) and available(c2) and award(str(c2["id"])):
				got.append(str(c2["id"]))
		return got
	for c: Dictionary in defs():
		if matches(c, event, info) and award(str(c["id"])):
			got.append(str(c["id"]))
	return got


## The Service Record's rows: {id, name, desc, map, earned}.
static func rows() -> Array:
	var out: Array = []
	for c: Dictionary in defs():
		out.append({"id": str(c["id"]), "name": str(c.get("name", c["id"])), "desc": str(c.get("desc", "")),
			"map": str(c.get("map", "")), "earned": earned(str(c["id"]))})
	return out
