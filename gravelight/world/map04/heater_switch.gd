class_name HeaterSwitch
extends Interactable
## The relay mast's heaters (UPDATE 10 §3 Act IV, the Bar's row 9, T-158; data map04d.json "heaters"): a breaker
## panel on the concourse's north wall by the yard airlock. The relay runs from the start (every machine has power,
## T-112), but its heaters sit in economy mode: the domes dimmed, the suits' heaters on the batteries. Throw it
## (a hold, free) and the act's power-on plays: the domes' lights come up dome by dome, the mast pulses violet,
## the airlocks cycle once, the perks wake with a spark and a chime, a burst of the dead at the burst points, the
## Operator. After it the terminator's cold drain is `heater_cold_mult` of itself (Terminator.heaters_on).
## Host-owned; the spectacle is mirrored. Flag `heaters_on`; group `heater_switch` (the bots' task, C7).

var thrown: bool = false
var cfg: Dictionary = {}
var _lamp: OmniLight3D
var _lever: Node3D


func _ready() -> void:
	interact_size = Vector3(1.4, 1.8, 0.8)
	interact_offset = Vector3(0, 1.2, 0.3)
	super._ready()
	add_to_group(&"heater_switch")
	cfg = GLData.load_json("res://data/gravelight/map04d.json").get("heaters", {})
	GLBus.flag_changed.connect(func(f: StringName, v: Variant) -> void:
		if f == &"heaters_on" and bool(v) and not thrown:
			_set_thrown())


func build_greybox() -> void:
	# a graphite cabinet on the wall, a chrome lever, a violet status lamp; its front faces -Z
	add_box(self, Vector3(1.1, 1.5, 0.22), Vector3(0, 1.35, 0.11), greybox_mat(Color(0.16, 0.16, 0.19)))
	add_box(self, Vector3(1.16, 0.08, 0.26), Vector3(0, 2.14, 0.13), greybox_mat(Color(0.7, 0.7, 0.75)))
	add_box(self, Vector3(0.7, 0.35, 0.02), Vector3(0, 1.75, -0.005), greybox_mat(Color(0.75, 0.45, 1.0), 1.4))
	_lever = Node3D.new()
	_lever.position = Vector3(0, 1.15, -0.05)
	add_child(_lever)
	add_box(_lever, Vector3(0.08, 0.55, 0.08), Vector3(0, -0.22, 0), greybox_mat(Color(0.78, 0.78, 0.82)))
	add_box(_lever, Vector3(0.22, 0.1, 0.12), Vector3(0, -0.5, 0), greybox_mat(Color(0.12, 0.12, 0.12)))
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 1.75, -0.4)
	_lamp.light_color = Color(1.0, 0.45, 0.25)
	_lamp.light_energy = 0.6
	_lamp.omni_range = 3.0
	_lamp.shadow_enabled = false
	add_child(_lamp)
	var lb: Label3D = add_label(self, "RELAY HEATERS\nECONOMY MODE", Vector3(0, 2.45, -0.02), 22, Color(0.9, 0.85, 1.0, 0.95))
	lb.name = "HeaterLabel"
	lb.rotation_degrees.y = 180.0


func get_prompt(player: Player) -> String:
	if player == null or thrown:
		return ""
	return "Hold [%s] to run the relay heaters" % prompt_key(&"interact")


func can_interact(player: Player) -> bool:
	return player != null and not thrown and not GameState.has_flag(&"heaters_on")


func hold_time(_player: Player) -> float:
	return float(cfg.get("hold_seconds", 1.5))


func interact(player: Player) -> void:
	if not can_interact(player) or not Net.is_authority():
		return
	throw_switch()


## Host: the spectacle (also the console verb and the smoke).
func throw_switch() -> void:
	if thrown:
		return
	_spectacle()
	Net.mirror(self, &"_spectacle", [])
	# the burst and the Operator are the host's
	var t: float = float(cfg.get("burst_after", 3.5))
	get_tree().create_timer(t).timeout.connect(_burst)
	get_tree().create_timer(t + 0.6).timeout.connect(func() -> void:
		GLVO.play(StringName(str(cfg.get("vo", "OPR_M4D_HEATERS_01"))))
		GLVO.squad_say("M4D_HEATERS", 0.8))
	print("[m4d] the relay heaters run")


func _set_thrown() -> void:
	thrown = true
	if _lever != null:
		_lever.rotation_degrees.x = -70.0
	if _lamp != null:
		_lamp.light_color = Color(0.72, 0.42, 1.0)
		_lamp.light_energy = 1.4
	var lb: Label3D = get_node_or_null(^"HeaterLabel") as Label3D
	if lb != null:
		lb.text = "RELAY HEATERS\nRUNNING"


## Every peer: the domes come up one by one, the mast flares, the airlocks cycle, the perks wake.
func _spectacle() -> void:
	var term: Terminator = get_tree().get_first_node_in_group(&"terminator") as Terminator
	if term != null:
		term.wake_dome("A_RECEPTION")
	_set_thrown()
	GameState.set_flag(&"heaters_on")
	AudioDirector.play_3d("m4d_heater_on", global_position + Vector3.UP, 4.0)
	var order: Array = cfg.get("dome_order", ["A_RECEPTION", "B_CONCOURSE", "D_FULFILLMENT", "E_HALL", "F_CORE"])
	var gap: float = float(cfg.get("dome_gap", 0.8))
	for i: int in order.size():
		var z: String = str(order[i])
		get_tree().create_timer(gap * float(i)).timeout.connect(func() -> void:
			if term != null and is_instance_valid(term):
				term.wake_dome(z)
			AudioDirector.play_2d("m4d_dome_lights", -10.0 + 1.0 * float(i), 0.03))
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		for m: Node in get_tree().get_nodes_in_group(&"relay_mast"):
			m.call("surge"))
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		for c: Node in get_tree().current_scene.find_children("AirlockCycle_*", "", true, false):
			if c.has_method("start_cycle"):
				c.call("start_cycle"))
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		for pm: Node in get_tree().get_nodes_in_group(&"perk_machines"):
			var n3: Node3D = pm as Node3D
			if n3 != null:
				Effects.shatter(n3.global_position + Vector3.UP * 1.6, Color(0.72, 0.45, 1.0), 14, 2.5)
				AudioDirector.play_3d("m4d_perk_wake", n3.global_position + Vector3.UP, -2.0))
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map != null and map.hud != null:
		map.hud.show_banner("THE RELAY'S HEATERS RUN", 3.0)


func _burst() -> void:
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir == null or not dir.has_method("spawn_special"):
		return
	var pts: Array = []
	for a: Variant in cfg.get("burst_points", []):
		var v: Array = a
		pts.append(Vector3(float(v[0]), float(v[1]), float(v[2])))
	dir.call("spawn_special", &"ganger", int(cfg.get("burst", 4)), pts)
