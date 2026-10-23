class_name MapCatalog
extends RefCounted
## The list of playable levels that must ship with map data (Update 04 section 1, DECISIONS T-065). It is read
## from tables the project already keeps, so a new level is required automatically the moment it is added:
##   - GRAVELIGHT: the campaign chain (data/gravelight/campaign.json "chain" + "scenes" + "display_names");
##   - Bolt & Sprocket: every planet on the star map with a built scene (data/bs/planets.json "campaign" rows whose
##     "scene" is not empty).
## A future table (Helvetia Works, the Colosseum, side-mode arenas) only needs a row in one of those, or a new
## source added to playable_levels(); the bake config (data/maps/bake_config.json) is optional per map.

const CAMPAIGN: String = "res://data/gravelight/campaign.json"
const PLANETS: String = "res://data/bs/planets.json"


## [{map_id, game ("gravelight" | "bs"), scene, display_name}] in campaign / star-map order.
static func playable_levels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var camp: Dictionary = _json(CAMPAIGN)
	var scenes: Dictionary = camp.get("scenes", {})
	var names: Dictionary = camp.get("display_names", {})
	for id: Variant in camp.get("chain", []):
		var sid: String = str(id)
		var scene: String = str(scenes.get(sid, ""))
		if scene == "":
			continue
		out.append({"map_id": StringName(sid), "game": "gravelight", "scene": scene, "display_name": str(names.get(sid, sid))})
	var planets: Dictionary = _json(PLANETS)
	for row: Variant in planets.get("campaign", []):
		var r: Dictionary = row as Dictionary
		var scene2: String = str(r.get("scene", ""))
		if scene2 == "":
			continue
		var lid: String = str(r.get("level_id", ""))
		out.append({"map_id": StringName(lid), "game": "bs", "scene": scene2, "display_name": lid.capitalize()})
	return out


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for l: Dictionary in playable_levels():
		out.append(l["map_id"] as StringName)
	return out


## The catalog row for one map id ({} when it is not a playable level).
static func level(map_id: StringName) -> Dictionary:
	for l: Dictionary in playable_levels():
		if l["map_id"] == map_id:
			return l
	return {}


static func _json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var v: Variant = JSON.parse_string(text)
	return v if v is Dictionary else {}
