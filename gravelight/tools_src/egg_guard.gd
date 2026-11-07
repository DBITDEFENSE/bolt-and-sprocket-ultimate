extends RefCounted
## U11 §2 (T-189): the Easter eggs are frozen. A digest of every quest file under data/gravelight/quests/: one hash for
## the whole file and one per step, over the parsed JSON with keys sorted and doc keys ("_doc", "_story", ...) left
## out. The snapshot was taken on master before Update 11's first change (gravelight/tests/fixtures/u11_egg_guard.json);
## test_u11_egg_guard.gd fails if any step, item, code, reward or bot_task differs from it.
##   Snapshot (only when the owner changes an egg on purpose):
##   "$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/egg_guard_snapshot.gd

const QUESTS: String = "res://data/gravelight/quests/"
const FIXTURE: String = "res://gravelight/tests/fixtures/u11_egg_guard.json"


static func strip(v: Variant) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (v as Dictionary):
			if str(k).begins_with("_"):
				continue
			out[k] = strip((v as Dictionary)[k])
		return out
	if v is Array:
		var a: Array = []
		for x: Variant in (v as Array):
			a.append(strip(x))
		return a
	return v


static func _h(v: Variant) -> String:
	return JSON.stringify(v, "", true).sha256_text()


static func digest_all() -> Dictionary:
	var out: Dictionary = {}
	var files: PackedStringArray = DirAccess.get_files_at(QUESTS)
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUESTS + f))
		var s: Variant = strip(d)
		var parts: Dictionary = {"_file": _h(s)}
		if s is Dictionary:
			for k: Variant in (s as Dictionary):
				if str(k) != "steps":
					parts["key:" + str(k)] = _h((s as Dictionary)[k])
			for st: Variant in ((s as Dictionary).get("steps", []) as Array):
				if st is Dictionary:
					parts["step:" + str((st as Dictionary).get("id", "?"))] = _h(st)
		out[f] = parts
	return out
