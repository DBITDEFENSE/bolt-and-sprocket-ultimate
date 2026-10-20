extends Node
## One save profile for the whole game: a versioned JSON document with three progress tracks (Bolt &
## Sprocket, Gravelight, The Fine Print) and the shared Fine Print Archive. Older saves are upgraded by
## MIGRATIONS in order, so a save written by any build loads in every later build.

const PATH: String = "user://profile.json"
const VERSION: int = 1

## version N -> N+1. Each entry takes the old document and returns the upgraded one.
const MIGRATIONS: Dictionary = {
	0: "_migrate_0_to_1",
}

var doc: Dictionary = {}
var path: String = PATH   # tests point this elsewhere


func _ready() -> void:
	load_profile()


static func blank() -> Dictionary:
	return {
		"version": VERSION,
		"bs": {"campaign_step": 0, "planets_cleared": [], "bolts": 0, "gold_bolts": 0, "memos": [], "quests": {},
			"weapons": {}, "cosmetics": [], "ng_plus": 0, "trophies": []},
		"gravelight": {"maps_unlocked": ["map00_crossroads"], "rank_xp": 0, "prestige": 0, "dossiers": {},
			"camos": {}, "egg_rewards": {}, "intel": [], "stats": {}},
		"fineprint": {"chapters_unlocked": [], "chapters_done": [], "documents": []},
		"archive": {"found": []},
		"unlocks": [],
	}


func load_profile() -> void:
	if not FileAccess.file_exists(path):
		doc = blank()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	doc = migrate(parsed if parsed is Dictionary else {})


func save_profile() -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write profile: %s" % path)
		return
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	EventBus.save_written.emit(path)


## Brings any older document up to VERSION. Unknown/empty documents become a blank profile.
func migrate(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return blank()
	var v: int = int(d.get("version", 0))
	while v < VERSION:
		d = call(MIGRATIONS[v], d)
		v += 1
		d["version"] = v
	# fill any keys added since (never removes the player's data)
	var b: Dictionary = blank()
	for k: String in b.keys():
		if not d.has(k):
			d[k] = b[k]
		elif d[k] is Dictionary:
			for k2: String in (b[k] as Dictionary).keys():
				if not (d[k] as Dictionary).has(k2):
					d[k][k2] = b[k][k2]
	return d


## Version 0 = a pre-release flat profile {"bolts", "memos"}: moved under "bs".
func _migrate_0_to_1(d: Dictionary) -> Dictionary:
	var out: Dictionary = blank()
	out["bs"]["bolts"] = int(d.get("bolts", 0))
	out["bs"]["memos"] = d.get("memos", [])
	return out


func is_unlocked(unlock_id: String) -> bool:
	return unlock_id in (doc.get("unlocks", []) as Array)


func unlock(unlock_id: String) -> void:
	if is_unlocked(unlock_id):
		return
	(doc["unlocks"] as Array).append(unlock_id)
	EventBus.unlock_granted.emit(unlock_id)
