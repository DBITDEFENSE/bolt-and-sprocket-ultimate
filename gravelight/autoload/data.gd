extends Node
## Loads every tuning table from res://data/gravelight/*.json once at startup.
## Logic reads numbers from here and never hardcodes them.

const DATA_DIR: String = "res://data/gravelight/"
const TABLES: PackedStringArray = [
	"economy", "rounds", "player", "perks", "powerups", "crate", "traps",
	"weapons", "enemies", "input_defaults", "world", "map01", "net", "bots", "campaign", "anim",

]

var _tables: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_tables.clear()
	for table_name: String in TABLES:
		_tables[table_name] = load_json(DATA_DIR + table_name + ".json")


func table(table_name: String) -> Dictionary:
	assert(_tables.has(table_name), "Unknown data table: %s" % table_name)
	return _tables[table_name]


static func load_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Data file missing or empty: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Data file is not a JSON object: %s" % path)
	return {}
