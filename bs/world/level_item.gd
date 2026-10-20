class_name LevelItem
extends Collectible
## A one-off level pickup that runs data actions when taken (the hull power cell, a secret's bolt jar,
## nanotech upgrades). Taken state persists as BS flag "<level>.item.<id>".

var item_id: String = ""
var level_id: String = ""
var kind: String = "cell"           # visual: cell, jar, nano, crate
var actions: Array = []
var director: Node = null          # LevelDirector (runs the actions)


func persist_flag() -> String:
	return "%s.item.%s" % [level_id, item_id]


func _on_collect(bolt: Node) -> void:
	BS.set_flag(persist_flag())
	if director != null and is_instance_valid(director):
		director.call("run_actions", actions, self, bolt)


func _make_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	match kind:
		"cell":
			LevelKit.cylinder(root, Vector3.ZERO, 0.32, 0.9, "#3ee6ff", false, "y", -1.0, 1.8)
			LevelKit.cylinder(root, Vector3(0, 0.5, 0), 0.38, 0.12, "#39404f", false)
			LevelKit.cylinder(root, Vector3(0, -0.5, 0), 0.38, 0.12, "#39404f", false)
		"jar":
			LevelKit.cylinder(root, Vector3.ZERO, 0.3, 0.6, "#c9e8f0", false)
			LevelKit.cylinder(root, Vector3(0, 0.36, 0), 0.24, 0.1, "#ffd23e", false)
		"nano":
			LevelKit.box(root, Vector3.ZERO, Vector3(0.6, 0.6, 0.6), "#3ee6ff", false, Vector3(0, 45, 45), 1, 1.6)
		_:
			LevelKit.box(root, Vector3.ZERO, Vector3(0.7, 0.7, 0.7), "#8a5a30", false)
	return root
