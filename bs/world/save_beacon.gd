class_name SaveBeacon
extends InteractPoint
## The landing pad's Save Beacon (BS_LEVELS §0.3): interact to save manually and refill to full HP.

var saves: int = 0
var host: Node = null      # BSLevel: save_game() when present


func _ready() -> void:
	super._ready()
	LevelKit.cylinder(self, Vector3(0, 0.15, 0), 0.7, 0.3, "#2c3242")
	LevelKit.cylinder(self, Vector3(0, 1.4, 0), 0.18, 2.4, "#39404f")
	LevelKit.cylinder(self, Vector3(0, 2.7, 0), 0.32, 0.3, "#3ee6ff", false, "y", -1.0, 2.0)


func prompt_text() -> String:
	return "bs.level.beacon_prompt"


func _do_interact(bolt: Node) -> void:
	if bolt != null and bolt.has_method("heal"):
		bolt.call("heal", float(bolt.get("max_hp")))
	if host != null and is_instance_valid(host) and host.has_method("save_game"):
		host.call("save_game")
	else:
		BS.save_to_profile()
	saves += 1
	EventBus.banner.emit(LevelKit.text("bs.level.beacon_saved"), LevelKit.text("bs.level.beacon_saved_sub"), 1.6)
