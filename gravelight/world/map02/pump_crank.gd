class_name PumpCrank
extends HoldoutStation
## The Pumpenschalter's hand crank at the head of the pump stair (Tide v2, contract C2, DECISIONS T-153): while a
## flood is up and the power is on, hold [interact] to start a 30 s crank holdout under ×2 spawns; done, it takes
## `pump_crank.shortens_by_s` off the flood (TideController.crank_completed). Once per flood (it rearms when the water
## falls). Tuning in map02.json "tide" "pump_crank".

var _wheel: Node3D
var _cranked_this_flood: bool = false


func _ready() -> void:
	var pc: Dictionary = _pc()
	holdout_id = &"pump_crank"
	zone_id = &"D_PENHALL"
	seconds = float(pc.get("seconds", 30.0))
	spawn_mult = float(pc.get("spawn_mult", 2.0))
	radius = float(pc.get("radius_m", 3.5))
	label = "the pump crank (pull the flood down)"
	hud_title = "PUMPS"
	repeatable = true
	interact_size = Vector3(1.2, 1.6, 1.0)
	interact_offset = Vector3(0, 0.9, 0)
	super._ready()
	add_to_group(&"pump_cranks")
	GLBus.tide_flood_end.connect(func() -> void: _cranked_this_flood = false)


static func _pc() -> Dictionary:
	return (GLData.load_json("res://data/gravelight/map02.json").get("tide", {}) as Dictionary).get("pump_crank", {})


func build_greybox() -> void:
	var base: StandardMaterial3D = greybox_mat(Color(0.22, 0.25, 0.24))
	var brass: StandardMaterial3D = greybox_mat(Color(0.62, 0.48, 0.22))
	add_box(self, Vector3(0.7, 1.0, 0.5), Vector3(0, 0.5, 0), base)
	_wheel = Node3D.new()
	_wheel.name = "Wheel"
	_wheel.position = Vector3(0, 1.15, -0.3)
	add_child(_wheel)
	var rim: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.4
	rim.mesh = tm
	rim.material_override = brass
	rim.rotation.x = PI * 0.5
	_wheel.add_child(rim)
	add_box(_wheel, Vector3(0.7, 0.05, 0.05), Vector3.ZERO, brass)
	add_box(_wheel, Vector3(0.05, 0.7, 0.05), Vector3.ZERO, brass)
	add_box(_wheel, Vector3(0.06, 0.06, 0.22), Vector3(0.36, 0, -0.1), brass)
	var l: Label3D = add_label(self, "PUMPEN · HANDBETRIEB", Vector3(0, 0.75, -0.26), 16, Color(0.9, 0.85, 0.7))
	l.rotation.y = 0.0


func _tide() -> TideController:
	return get_tree().get_first_node_in_group(&"tide") as TideController


func start_block(player: Player) -> String:
	var base: String = super.start_block(player)
	if base != "":
		return base
	if not GameState.power_on:
		return "The pumps have no power"
	var t: TideController = _tide()
	if t == null or not t.can_crank():
		return ""   # nothing to pump: no prompt
	if _cranked_this_flood:
		return "The pumps are already pulling"
	return ""


func get_prompt(player: Player) -> String:
	var t: TideController = _tide()
	if state == State.IDLE and GameState.power_on and (t == null or not t.can_crank()):
		return ""
	return super.get_prompt(player)


func can_interact(player: Player) -> bool:
	var t: TideController = _tide()
	return super.can_interact(player) and GameState.power_on and t != null and t.can_crank() and not _cranked_this_flood


func _on_started() -> void:
	var pc: Dictionary = _pc()
	if Net.is_authority():
		GLVO.play(StringName(str(pc.get("vo_start", ""))))


func _twist_tick(delta: float) -> void:
	if _wheel != null and occupied:
		_wheel.rotation.z -= delta * 3.0


func _process(delta: float) -> void:
	super._process(delta)
	if state == State.RUNNING and _wheel != null and Net.is_client() and occupied:
		_wheel.rotation.z -= delta * 3.0


func _completed() -> void:
	_cranked_this_flood = true
	var pc: Dictionary = _pc()
	var t: TideController = _tide()
	if Net.is_authority():
		if t != null:
			t.crank_completed()
		GLVO.play(StringName(str(pc.get("vo_done", ""))))
	var root: Node = get_parent()
	while root != null and not (root is MapRoot):
		root = root.get_parent()
	if root != null and (root as MapRoot).hud != null:
		(root as MapRoot).hud.show_banner(str(pc.get("banner", "")), 3.0)
	AudioDirector.play_3d("lift_winch", global_position + Vector3.UP, -2.0, 0.0)
