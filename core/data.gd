extends Node
## Loads JSON data under res://data on demand and caches it. Logic reads every number and line from
## here and never hardcodes them. Paths are relative to res://data without ".json",
## e.g. Data.table("bs/story/speakers") or Data.table("bs_source/CONFIG").

const DATA_DIR: String = "res://data/"

var _cache: Dictionary = {}


func table(path: String) -> Variant:
	if not _cache.has(path):
		_cache[path] = load_json(DATA_DIR + path + ".json")
	return _cache[path]


func has_table(path: String) -> bool:
	return FileAccess.file_exists(DATA_DIR + path + ".json")


func reload() -> void:
	_cache.clear()


## Returns the parsed JSON (Dictionary or Array), or null with an error if missing/invalid.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Data file missing: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("Data file is not valid JSON: %s" % path)
	return parsed
