class_name CheckpointRelay
extends Area3D
## A nanotech relay pylon (addCheckpoint / activateCheckpoint): touching it makes it the respawn point,
## heals heal_frac of max HP, and shows "<label> · Nanotech relay synced — respawn here". The director keeps
## only one relay lit at a time.

signal activated(relay: CheckpointRelay, bolt: Node)

var relay_id: String = ""
var label: String = ""          # line id or text
var heal_frac: float = 0.25
var active: bool = false
var _lamp: LevelLamp


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 1
	monitoring = true
	add_to_group(&"checkpoints")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(4.2, 4.0, 4.2)
	cs.shape = sh
	cs.position.y = 1.5
	add_child(cs)
	LevelKit.cylinder(self, Vector3(0, 0.12, 0), 0.9, 0.24, "#2c3242")
	LevelKit.cylinder(self, Vector3(0, 1.1, 0), 0.16, 2.0, "#39404f")
	_lamp = LevelLamp.new()
	_lamp.off_color = "#ff9d2e"
	_lamp.on_color = "#3ee6ff"
	_lamp.lamp_radius = 0.32
	_lamp.position.y = 2.3
	add_child(_lamp)
	body_entered.connect(_on_enter)


func respawn_pos() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func _on_enter(b: Node) -> void:
	if b.is_in_group(&"player"):
		activate(b)


func activate(bolt: Node, silent: bool = false) -> void:
	if active:
		return
	active = true
	_lamp.set_lit(true)
	if not silent:
		if bolt != null and bolt.has_method("heal"):
			bolt.call("heal", float(bolt.get("max_hp")) * heal_frac)
		EventBus.banner.emit(LevelKit.text(label), LevelKit.text("code.activateCheckpoint.01"), 1.5)
	activated.emit(self, bolt)


func deactivate() -> void:
	active = false
	if _lamp != null:
		_lamp.set_lit(false)
