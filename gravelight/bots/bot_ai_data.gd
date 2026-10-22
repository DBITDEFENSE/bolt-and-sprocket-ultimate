class_name BotAIData
extends RefCounted
## The bots' AI tuning tables (Update 03, T-055): data/gravelight/ai/*.json, loaded once and cached.
## actions (utility actions, roles, orders), curves (response curves), combat (perception, threat, aim, executors),
## economy (the spending plan), ai_counters (special-enemy knowledge), skills (Recruit / Veteran / Elite) and
## personality_<character>.json. The brief names .tres resources; this project keeps its tuning in JSON tables.

const DIR: String = "res://data/gravelight/ai/"

static var _cache: Dictionary = {}


## One table by file name without ".json" ("actions", "curves", "combat", "economy", "ai_counters", "skills").
static func table(name: String) -> Dictionary:
	if not _cache.has(name):
		var path: String = DIR + name + ".json"
		_cache[name] = GLData.load_json(path) if FileAccess.file_exists(path) else {}
	return _cache[name]


## Drops the cache (tests that edit tuning, a dev reload).
static func reload() -> void:
	_cache.clear()


## A section of combat.json ("perception", "threat", "aim", "weapons", "reload", ...).
static func combat(section: String) -> Dictionary:
	return table("combat").get(section, {})


## The personality profile for a character id (personality_<id>.json); an empty profile for an unknown one.
static func personality(character: String) -> Dictionary:
	var t: Dictionary = table("personality_" + character)
	return t if not t.is_empty() else {"character": character, "actions": {}, "role_bias": {}, "aim": {}, "combat": {}, "economy": {}, "callouts": {}}


## The brain-layer skill preset (skills.json); falls back to "veteran".
static func skill(name: String) -> Dictionary:
	var s: Dictionary = table("skills")
	if s.has(name):
		return s[name]
	return s.get("veteran", {})


## Counters for an enemy id (ai_counters.json), with the defaults filled in.
static func counter(enemy_id: StringName) -> Dictionary:
	var key: String = "counter:" + String(enemy_id)
	if _cache.has(key):
		return _cache[key]
	var c: Dictionary = table("ai_counters")
	var out: Dictionary = (c.get("default", {}) as Dictionary).duplicate()
	out.merge(c.get(String(enemy_id), {}), true)
	_cache[key] = out
	return out
