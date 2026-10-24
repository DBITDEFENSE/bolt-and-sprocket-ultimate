class_name MachineLore
extends RefCounted
## Why the perk machines, the Crucible and the wall guns are where they are, per map (DECISIONS T-075):
## data/gravelight/machine_lore.json, generated from docs/gravelight/PERKS_LORE.md by tools/build_perk_lore.py.
## Entry keys per map: "perk.<perk_id>" (the maker's plate), "crucible" (its brass plate), "chalk" (the map's
## Standing Order 17 entry) and "chalk.<weapon_id>" (the line under a wall gun's prompt). Each has "plate" (one line)
## and, when it is an Archive row, "title" + "text" (the first paragraph is the reader's caption).
## Used by PerkMachine / Crucible (a LorePlaque at the base), WallBuy (the chalk line) and ProfileSave (Archive rows).
## A map with no section here simply shows no plates: a future map adds its section to PERKS_LORE.md.

const PATH: String = "res://data/gravelight/machine_lore.json"

## Archive ids filed this session (so a prompt can file its entry once without re-emitting every frame).
static var _filed: Dictionary = {}
static var _maps: Dictionary = {}


## The parsed file, cached (prompts ask for plate lines every frame).
static func maps() -> Dictionary:
	if _maps.is_empty():
		_maps = GLData.load_json(PATH).get("maps", {})
	return _maps


static func entry(map_id: StringName, key: String) -> Dictionary:
	return ((maps().get(String(map_id), {}) as Dictionary).get("entries", {}) as Dictionary).get(key, {})


## The one-line plate text ("" when the map has none for this key).
static func plate(map_id: StringName, key: String) -> String:
	return str(entry(map_id, key).get("plate", ""))


## The Archive id of an entry: "lore.<map_id>.<key>".
static func intel_id(map_id: StringName, key: String) -> StringName:
	return StringName("lore.%s.%s" % [map_id, key])


## The current map (GameState.map_id).
static func here() -> StringName:
	return GameState.map_id


## A full Archive row for an entry ({} when it has no text). The chalk entry lists every wall gun's line under it.
static func row(map_id: StringName, key: String) -> Dictionary:
	var m: Dictionary = maps().get(String(map_id), {})
	var e: Dictionary = (m.get("entries", {}) as Dictionary).get(key, {})
	if e.is_empty() or not e.has("text"):
		return {}
	var text: String = str(e["text"])
	if key == "chalk":
		var lines: PackedStringArray = []
		var ents: Dictionary = m.get("entries", {})
		for k: Variant in ents.keys():
			if str(k).begins_with("chalk."):
				lines.append("%s: %s" % [_weapon_name(str(k).substr(6)), (ents[k] as Dictionary).get("plate", "")])
		if not lines.is_empty():
			text += "\n\nOn the clamps:\n" + "\n".join(lines)
	var type: String = "PLAQUE"
	if key == "crucible":
		type = "FORGE"
	elif key == "chalk":
		type = "CHALK"
	return {"id": String(intel_id(map_id, key)), "title": str(e.get("title", key)), "type": type,
		"map": str(m.get("archive_map", map_id)), "text": text}


## Every Archive row of every map (ProfileSave adds them to the Intel Archive).
static func archive_rows() -> Array:
	var out: Array = []
	for mid: Variant in maps().keys():
		for k: Variant in ((maps()[mid] as Dictionary).get("entries", {}) as Dictionary).keys():
			var r: Dictionary = row(StringName(mid), str(k))
			if not r.is_empty():
				out.append(r)
	return out


## Opens the reader on an entry of the current map (the first read files it in the Archive).
static func open_for(player: Player, key: String) -> void:
	var r: Dictionary = row(here(), key)
	if r.is_empty():
		return
	StoryReader.open_for(player, StringName(r["id"]), r)
	_maybe_say(player, key)


## Files an entry once (a wall gun's chalk is read just by looking at it).
static func file_once(map_id: StringName, key: String) -> void:
	var id: StringName = intel_id(map_id, key)
	if _filed.has(id) or row(map_id, key).is_empty():
		return
	_filed[id] = true
	if ProfileSave.has_intel(String(id)):
		return
	GLBus.intel_found.emit(id)


## The first plate a player reads in a match gets a line from them (PLAQUE / PLAQUE_CRUCIBLE, VO_SCRIPT section 20).
static var _said: Dictionary = {}
static func _maybe_say(player: Player, key: String) -> void:
	var cat: String = "PLAQUE_CRUCIBLE" if key == "crucible" else "PLAQUE"
	var k: String = "%d:%s:%s" % [player.player_id, cat, GameState.map_id]
	if _said.has(k):
		return
	_said[k] = true
	GLVO.say_as(player.player_id, cat, 1.0)


static func _weapon_name(wid: String) -> String:
	var w: Dictionary = GLData.table("weapons")
	for table: String in ["weapons", "melee", "lethal"]:
		if (w.get(table, {}) as Dictionary).has(wid):
			return str((w[table][wid] as Dictionary).get("name", wid))
	return wid
