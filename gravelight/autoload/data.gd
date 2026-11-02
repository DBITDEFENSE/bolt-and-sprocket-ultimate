extends Node
## Loads every tuning table from res://data/gravelight/*.json once at startup.
## Logic reads numbers from here and never hardcodes them.

const DATA_DIR: String = "res://data/gravelight/"
const TABLES: PackedStringArray = [
	"movement",   # Update 02 §1: acceleration, sprint, mantle, camera feel (Player)
	"economy", "rounds", "player", "perks", "powerups", "crate", "traps",
	"weapons", "enemies", "input_defaults", "world", "map01", "net", "bots", "campaign", "anim",
	"bosses/cousins", "bosses/likeness",   # the homage bosses (HB1): table("bosses/cousins") reads data/gravelight/bosses/cousins.json
	"bosses/map01", "bosses/map02", "bosses/map03",   # UPDATE 10 C5: PAUL (map01), THE SLENDER + der Kielholer (map02), the Morgenrot hook (map03)
	"bosses/map04",   # Map 4 "Fernflug" bosses (UPDATE 07): the Kranführer, the Bordwart, the Test Pilot, the Account Manager
	"bank",   # T-136: the savings bank (BankAccount)
	"online",   # T-138: online lobbies (LobbyService), WebRTC ICE servers, rejoin grace, timeouts
	"companions",   # T-135: one more companion per map (MapCompanion)
	"pilot",   # T-126: GRAVELIGHT ONE's trapped pilot (TrappedPilot), Map 0's wreck
	"squads",   # T-142: the relief squads (ReliefSquad, Soldier, SoldierBrain)
	"vfx",   # UPDATE 05 section 6 (T-095): muzzle flashes, casings, impact debris, atmosphere (Effects)

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
