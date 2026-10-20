class_name TeleporterExit
extends Area3D
## The Return Relay (placeGoal / activateGoal / updateGoal): OmniScrap's freight teleporter. Dark until
## activate() ("EXIT ONLINE! · Get to the teleporter!"); stepping on it while lit completes the planet:
## BS flag "planet_complete.<planet>", SaveProfile doc["bs"]["planets_cleared"] gets the planet index,
## campaign_step is raised, the profile is saved and `planet_completed` fires (the director then asks the
## host level to show the summary / return to the ship).

signal planet_completed(planet_id: String)

var planet_id: String = ""
var planet_index: int = 0
var campaign_step_after: int = 1
var active: bool = false
var completed: bool = false
var _beam: Node3D
var _ring: Node3D
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 1
	monitoring = true
	add_to_group(&"exits")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = 1.8
	sh.height = 3.0
	cs.shape = sh
	cs.position.y = 1.5
	add_child(cs)
	LevelKit.cylinder(self, Vector3(0, 0.15, 0), 2.4, 0.3, "#2c3242")
	LevelKit.cylinder(self, Vector3(0, 0.32, 0), 1.9, 0.06, "#39404f")
	_ring = LevelKit.cylinder(self, Vector3(0, 0.5, 0), 1.6, 0.12, "#3ee6ff", false, "y", -1.0, 0.6)
	_beam = LevelKit.cylinder(self, Vector3(0, 4.0, 0), 1.2, 8.0, "#3ee6ff", false, "y", -1.0, 1.5)
	_beam.visible = active
	body_entered.connect(_on_enter)


func activate(silent: bool = false) -> void:
	if active:
		return
	active = true
	_beam.visible = true
	if not silent:
		EventBus.banner.emit(LevelKit.text("code.activateGoal.01"), LevelKit.text("code.activateGoal.02"), 2.0)


func _process(delta: float) -> void:
	_t += delta
	if _ring != null:
		_ring.position.y = 0.5 + sin(_t * 2.0) * 0.15


func _on_enter(b: Node) -> void:
	if b.is_in_group(&"player"):
		try_complete()


func try_complete() -> bool:
	if not active or completed:
		return false
	completed = true
	BS.set_flag("planet_complete." + planet_id)
	var bs: Dictionary = SaveProfile.doc["bs"]
	var cleared: Array = bs.get("planets_cleared", [])
	if not (planet_index in cleared):
		cleared.append(planet_index)
	bs["planets_cleared"] = cleared
	bs["campaign_step"] = maxi(int(bs.get("campaign_step", 0)), campaign_step_after)
	BS.save_to_profile()
	planet_completed.emit(planet_id)
	return true
