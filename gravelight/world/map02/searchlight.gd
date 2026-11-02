class_name Searchlight
extends Interactable
## The signal tower's searchlight (UPDATE 10 contract C2, DECISIONS T-153; data map02.json "searchlight"). After
## power a player mans it: they are held at the stand, their weapons holstered (WeaponHolder.set_holstered), and the
## beam follows their view within the station's limits; hold [interact] again to leave (going down leaves too).
## Zombies in the beam are slowed (`slow`) and take `lit_damage_mult` damage (Zombie.set_lit, refreshed every
## `tick_seconds`). A bot mans it through the MAN_SEARCHLIGHT mark order: it sweeps `bot_sweep_points` and swings to the
## densest group in range. During the sail (GameState flag `sailing`) it tracks the boat by itself.
## Co-op (C8): the host owns the aim (yaw, pitch) and mirrors it at 10 Hz; the lit marks run on the host.

signal manned(operator_id: int)
signal left(operator_id: int)

var operator_id: int = 0
var yaw: float = 0.0      # radians, relative to the station's facing
var pitch: float = -0.35  # radians
var auto_track: bool = false
var lit_count: int = 0    # zombies lit on the last tick (tests and the smoke read it)

var _cfg: Dictionary = {}
var _pivot: Node3D
var _light: SpotLight3D
var _cone: MeshInstance3D
var _cone_mat: StandardMaterial3D
var _stand: Vector3
var _tick: float = 0.0
var _net_t: float = 0.0
var _sweep_i: int = 0
var _sweep_t: float = 0.0
var _focus: Vector3 = Vector3.INF


func _ready() -> void:
	_cfg = GLData.load_json("res://data/gravelight/map02.json").get("searchlight", {})
	interact_size = Vector3(1.6, 2.0, 1.6)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"searchlights")
	_stand = global_position + global_basis * Vector3(0, 0, 1.1)
	_set_beam(false)
	GLBus.player_downed.connect(func(pid: int) -> void:
		if pid == operator_id and Net.is_authority():
			leave())
	GLBus.flag_changed.connect(_on_flag)


func build_greybox() -> void:
	var iron: StandardMaterial3D = greybox_mat(Color(0.2, 0.21, 0.22))
	var brass: StandardMaterial3D = greybox_mat(Color(0.55, 0.45, 0.25))
	add_box(self, Vector3(0.6, 0.9, 0.6), Vector3(0, 0.45, 0), iron)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position = Vector3(0, float(_cfg.get("pivot_height", 1.6)), 0)
	add_child(_pivot)
	var drum: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.36
	cm.height = 0.8
	drum.mesh = cm
	drum.material_override = brass
	drum.rotation.x = PI * 0.5
	_pivot.add_child(drum)
	var lens: MeshInstance3D = MeshInstance3D.new()
	var lm: CylinderMesh = CylinderMesh.new()
	lm.top_radius = 0.4
	lm.bottom_radius = 0.4
	lm.height = 0.04
	lens.mesh = lm
	lens.material_override = greybox_mat(Color(1.0, 0.95, 0.8), 3.0)
	lens.rotation.x = PI * 0.5
	lens.position = Vector3(0, 0, -0.42)
	_pivot.add_child(lens)
	_light = SpotLight3D.new()
	_light.name = "Beam"
	_light.spot_range = float(_cfg.get("range_m", 48.0))
	_light.spot_angle = float(_cfg.get("cone_deg", 9.0))
	_light.light_energy = 14.0
	_light.light_color = Color(1.0, 0.96, 0.85)
	_light.shadow_enabled = false
	_light.set_meta("zone", "G_SIGNAL")
	_light.position = Vector3(0, 0, -0.5)
	_pivot.add_child(_light)
	_cone = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	var rng: float = float(_cfg.get("range_m", 48.0)) * 0.55
	cone.top_radius = 0.38
	cone.bottom_radius = tan(deg_to_rad(float(_cfg.get("cone_deg", 9.0)))) * rng
	cone.height = rng
	cone.radial_segments = 16
	cone.cap_top = false
	cone.cap_bottom = false
	_cone.mesh = cone
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.albedo_color = Color(1.0, 0.95, 0.8, 0.07)
	_cone.material_override = _cone_mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.rotation.x = -PI * 0.5
	_cone.position = Vector3(0, 0, -0.5 - rng * 0.5)
	_pivot.add_child(_cone)
	var l: Label3D = add_label(self, "SCHEINWERFER", Vector3(0, 0.7, 0.31), 16, Color(0.9, 0.85, 0.7))
	l.rotation.y = PI


# ------------------------------------------------------------------ pure rules (unit-tested)

## Is `p` inside the beam from `origin` along `fwd` (within `range_m` and `half_deg`)?
static func in_beam(origin: Vector3, fwd: Vector3, p: Vector3, range_m: float, half_deg: float) -> bool:
	var d: Vector3 = p - origin
	var dist: float = d.length()
	if dist > range_m or dist < 0.5:
		return false
	return rad_to_deg(fwd.normalized().angle_to(d / dist)) <= half_deg + rad_to_deg(atan2(1.0, dist))   # +1 m slack


## The (yaw, pitch) that aims from `origin` at `target`, relative to a station facing `facing` (radians, -Z forward).
static func aim_at(origin: Vector3, target: Vector3, facing: float) -> Vector2:
	var d: Vector3 = target - origin
	var world_yaw: float = atan2(-d.x, -d.z)
	var y: float = wrapf(world_yaw - facing, -PI, PI)
	var p: float = atan2(d.y, Vector2(d.x, d.z).length())
	return Vector2(y, p)


## Clamp an aim to the station's limits.
static func clamp_aim(a: Vector2, cfg: Dictionary) -> Vector2:
	var lim: float = deg_to_rad(float(cfg.get("yaw_limit_deg", 80.0)))
	return Vector2(clampf(a.x, -lim, lim), clampf(a.y, deg_to_rad(float(cfg.get("pitch_min_deg", -55.0))), deg_to_rad(float(cfg.get("pitch_max_deg", 5.0)))))


# ------------------------------------------------------------------ manning

func get_prompt(player: Player) -> String:
	if not GameState.power_on:
		return "The searchlight has no power"
	if operator_id == player.player_id:
		return "Hold [%s] to leave the searchlight" % prompt_key(&"interact")
	if operator_id != 0 or auto_track:
		return ""
	return "Hold [%s] to man the searchlight" % prompt_key(&"interact")


func can_interact(player: Player) -> bool:
	if not GameState.power_on:
		return false
	return operator_id == player.player_id or (operator_id == 0 and not auto_track)


func hold_time(_player: Player) -> float:
	return 0.6


func repeats() -> bool:
	return true


func interact(player: Player) -> void:
	if not Net.is_authority():
		return
	if operator_id == player.player_id:
		leave()
	elif operator_id == 0:
		man(player.player_id)


## A player (or a bot) takes the station (authority; every peer mirrors).
func man(pid: int) -> void:
	operator_id = pid
	var p: Player = _player(pid)
	if p != null and p.weapons != null:
		p.weapons.set_holstered(true)
	_set_beam(true)
	if Net.is_authority():
		Net.mirror(self, &"man", [pid])
		GLBus.searchlight_state.emit(true, pid)
		if p != null and not p.is_bot:
			GLVO.play_category(&"OPR", "SEARCHLIGHT_ON", 0.5)
	manned.emit(pid)


func leave() -> void:
	var was: int = operator_id
	var p: Player = _player(was)
	if p != null and p.weapons != null:
		p.weapons.set_holstered(false)
	operator_id = 0
	if not auto_track:
		_set_beam(false)
	if Net.is_authority():
		Net.mirror(self, &"leave")
		GLBus.searchlight_state.emit(auto_track, 0)
	left.emit(was)


func _on_flag(flag: StringName, value: Variant) -> void:
	if flag == &"sailing" and Net.is_authority():
		set_auto_track(bool(value))


## The finale: the tower light tracks the boat on its own (C2).
func set_auto_track(on: bool) -> void:
	auto_track = on
	if on and operator_id != 0:
		leave()
	_set_beam(on or operator_id != 0)
	if Net.is_authority():
		Net.mirror(self, &"set_auto_track", [on])
		GLBus.searchlight_state.emit(on, 0)


func is_on() -> bool:
	return operator_id != 0 or auto_track


func _set_beam(on: bool) -> void:
	if _light != null:
		_light.visible = on
	if _cone != null:
		_cone.visible = on


func _player(pid: int) -> Player:
	if pid == 0:
		return null
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p
	return null


# ------------------------------------------------------------------ the beam

func beam_origin() -> Vector3:
	return _pivot.global_position if _pivot != null else global_position + Vector3.UP * 1.6


func beam_forward() -> Vector3:
	return (global_basis * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, -1)).normalized()


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation = Vector3(pitch, yaw, 0)
	if not is_on() or not Net.is_authority():
		return
	_steer(delta)
	_net_t -= delta
	if _net_t <= 0.0:
		_net_t = 0.1
		Net.mirror(self, &"_net_aim", [yaw, pitch])


func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		return
	# hold the operator at the stand
	var op: Player = _player(operator_id)
	if op != null:
		if not op.is_alive():
			leave()
		elif op.global_position.distance_to(_stand) > 0.35:
			op.global_position = Vector3(_stand.x, op.global_position.y, _stand.z)
			op.velocity = Vector3.ZERO
	if not is_on():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	var step: float = float(_cfg.get("tick_seconds", 0.2))
	_tick = step
	_light_zombies(step)


func _steer(delta: float) -> void:
	var want: Vector2 = Vector2(yaw, pitch)
	var op: Player = _player(operator_id)
	var facing: float = global_rotation.y
	if auto_track:
		var tp: Array = _cfg.get("sail_track_point", [7.0, 1.0, 62.0])
		want = aim_at(beam_origin(), Vector3(float(tp[0]), float(tp[1]), float(tp[2])), facing)
		want.x += sin(Time.get_ticks_msec() * 0.0008) * 0.12   # a slow searching drift over the deck
	elif op != null and op.is_bot:
		want = aim_at(beam_origin(), _bot_target(delta), facing)
	elif op != null and op.camera != null:
		var f: Vector3 = -op.camera.global_basis.z
		want = aim_at(beam_origin(), beam_origin() + f * 20.0, facing)
	want = clamp_aim(want, _cfg)
	var rate: float = deg_to_rad(float(_cfg.get("turn_deg_per_s", 70.0))) * delta
	if op != null and not op.is_bot and not auto_track:
		rate *= 3.0   # a human's own view: near-direct
	yaw = move_toward(yaw, want.x, rate)
	pitch = move_toward(pitch, want.y, rate)


## A bot operator: the densest group of zombies in range, else the next sweep point.
func _bot_target(delta: float) -> Vector3:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	var best: Vector3 = Vector3.INF
	var best_n: int = 0
	if dir != null:
		var zs: Array = dir.active_zombies()
		for z: Zombie in zs:
			if z.global_position.distance_to(beam_origin()) > float(_cfg.get("range_m", 48.0)):
				continue
			var n: int = 0
			for o: Zombie in zs:
				if o.global_position.distance_to(z.global_position) < 4.0:
					n += 1
			if n > best_n:
				best_n = n
				best = z.global_position
	if best_n >= 2:
		return best
	_sweep_t -= delta
	var pts: Array = _cfg.get("bot_sweep_points", [])
	if pts.is_empty():
		return beam_origin() + global_basis * Vector3(0, -6, -20)
	if _sweep_t <= 0.0:
		_sweep_t = float(_cfg.get("bot_sweep_seconds", 4.0))
		_sweep_i = (_sweep_i + 1) % pts.size()
	var a: Array = pts[_sweep_i]
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _light_zombies(step: float) -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	lit_count = 0
	if dir == null:
		return
	var o: Vector3 = beam_origin()
	var f: Vector3 = beam_forward()
	var rng: float = float(_cfg.get("range_m", 48.0))
	var half: float = float(_cfg.get("cone_deg", 9.0))
	var slow: float = float(_cfg.get("slow", 0.4))
	var mult: float = float(_cfg.get("lit_damage_mult", 1.25))
	for z: Zombie in dir.active_zombies():
		if in_beam(o, f, z.global_position + Vector3.UP, rng, half):
			z.set_lit(true, slow, mult, step * 2.5)
			lit_count += 1


func _net_aim(y: float, p: float) -> void:
	yaw = y
	pitch = p
