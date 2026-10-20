extends Node
## User settings (user://settings.cfg). The full set (original SETTINGS_DEF + Gravelight settings) is
## defined in data/settings_defaults.json; this stub loads and saves it so every mode reads one place.

const PATH: String = "user://settings.cfg"

var values: Dictionary = {}
var path: String = PATH   # tests point this elsewhere


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var defaults: Variant = Data.table("settings_defaults")
	values = (defaults as Dictionary).duplicate(true) if defaults is Dictionary else {}
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key: String in values.keys():
		values[key] = cfg.get_value("settings", key, values[key])


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in values.keys():
		cfg.set_value("settings", key, values[key])
	cfg.save(path)


func get_value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)
