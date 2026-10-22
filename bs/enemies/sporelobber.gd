class_name SporeLobber
extends EnemyBase
## Spore Lobber — arcing turret (BS_ENEMIES §3.5). 40 HP / rooted / 10 + r2.2 blast / 8 bolts. A plant on a rooted
## stalk with a swollen purple bulb and an open "spore mouth". Every `fire_every` (2.2 s) within `fire_radius`
## it LOBS a toxic glob that arcs over cover (10 damage, r2.2 blast) and lands where a decal ring showed for the
## whole flight; the landing leaves a spore cloud (r2.2, `cloud_life` 2 s) that ticks 3 damage every 0.5 s.
## Telegraph: the bulb swells, the mouth puckers and glows green, a wet inhale, 0.55 s. Weak point: the bulb
## (always a crit). Globs are fragile in flight (hittable; a hit pops them). Elite (Organic Certified, violet
## rim): globs split into three on landing.

var globs_fired: int = 0
var clouds: int = 0
var _bulb: MeshInstance3D
var _bulb_mat: StandardMaterial3D
var _mouth_mat: StandardMaterial3D
var _bulb_node: Node3D


func SL() -> Dictionary:
	return def["lobber"]


func _build_visual() -> void:
	var stalk: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#4a6a2a"))))
	flash_mats.append(stalk)
	EnemyFx.cyl(visual, 0.55, 0.2, Vector3(0, 0.1, 0), EnemyFx.mat(Color("#2f2a1e")))                  # the roots
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		EnemyFx.box(visual, Vector3(0.6, 0.12, 0.16), Vector3(cos(a) * 0.45, 0.1, sin(a) * 0.45), EnemyFx.mat(Color("#3b2a1e"))).rotation.y = -a
	EnemyFx.cyl(visual, 0.18, 1.0, Vector3(0, 0.7, 0), stalk)
	_bulb_node = Node3D.new()
	_bulb_node.position = Vector3(0, 1.35, 0)
	visual.add_child(_bulb_node)
	_bulb_mat = EnemyFx.mat(Color("#7a3a8a"), Color("#c06aff"), 0.6)
	_bulb = EnemyFx.sphere(_bulb_node, 0.42, Vector3.ZERO, _bulb_mat)
	_mouth_mat = EnemyFx.mat(Color("#1f3a1f"), Color("#5affc8"), 0.0)
	_mouth_mat.emission_enabled = true
	EnemyFx.cyl(_bulb_node, 0.2, 0.18, Vector3(0, 0.1, 0.36), _mouth_mat, 0.12).rotation.x = PI / 2.0
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0
		EnemyFx.box(_bulb_node, Vector3(0.5, 0.05, 0.22), Vector3(cos(a) * 0.3, -0.3, sin(a) * 0.3), EnemyFx.mat(Color("#3fa04a"))).rotation.y = -a


func _on_activate() -> void:
	globs_fired = 0
	clouds = 0
	fire_cd = randf_range(0.8, 1.6)


func _initial_state() -> int:
	return State.CHASE if aggro else State.IDLE


func _idle_update(dt: float) -> void:
	_bulb_node.scale = Vector3.ONE * (1.0 + 0.04 * sin(t * 2.0))
	var _u: float = dt


func _position_update(dt: float) -> void:
	desired_vel = Vector3.ZERO
	var d: float = dist_to_target()
	if d < float(SL()["track_radius"]) and target_alive():
		face(target_pos() - global_position, dt, 3.0)
		var tele: float = float(telegraph_def(&"lob").get("dur", 0.55))
		if d < float(SL()["fire_radius"]) and fire_cd <= tele and can_attack():
			if AttackTokens.request_ranged():
				var land: Vector3 = _landing_spot()
				begin_telegraph(&"lob", tele, float(SL()["blast_r"]), land, false)
			else:
				fire_cd = tele + 0.15


## Where the glob lands: Bolt's position led by a little of his motion.
func _landing_spot() -> Vector3:
	var tp: Vector3 = target_pos()
	if target != null and "motor" in target:
		var m: Object = target.get("motor")
		if m != null:
			var v: Vector3 = m.get("vel")
			tp += Vector3(v.x, 0, v.z) * float(SL().get("lead", 0.35))
	return Vector3(tp.x, EnemyFx.floor_y(self, tp, tp.y - 0.9), tp.z)


func _telegraph_update(dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_bulb_node.scale = Vector3.ONE * (1.0 + k * 0.35)
	_mouth_mat.emission_energy_multiplier = k * 3.5
	if target_alive():
		face(target_pos() - global_position, dt, 3.0)


func _attack_begin() -> void:
	_bulb_node.scale = Vector3.ONE
	_mouth_mat.emission_energy_multiplier = 0.0
	fire_cd = float(SL()["fire_every"])
	var land: Vector3 = _landing_spot()
	_lob(land)
	globs_fired += 1


func _lob(land: Vector3) -> void:
	if get_parent() == null:
		return
	var flight: float = float(SL()["flight"])
	var g: float = float(SL().get("grav", 14.0))
	var from: Vector3 = _bulb_node.global_position + Vector3(0, 0.2, 0)
	var to: Vector3 = land + Vector3(0, 0.25, 0)
	var d: Vector3 = to - from
	var v: Vector3 = Vector3(d.x / flight, (d.y + 0.5 * g * flight * flight) / flight, d.z / flight)
	var c: Color = EnemyFx.col(str(SL().get("glob_color", "#9dff5a")))
	var opts: Dictionary = {"grav": g, "boom_r": float(SL()["blast_r"]), "source": self, "fragile": true, "hittable": true, "kind": &"spore_glob",
		"on_land": func(pos: Vector3, _hit_player: bool) -> void: _land(pos)}
	EnemyProjectile.fire(get_parent(), from, v, float(def["dmg"]) * out_mult(), c, float(SL().get("glob_size", 0.32)), flight + 1.5, opts)


func _land(pos: Vector3) -> void:
	if get_parent() == null or not is_inside_tree():
		return
	var SC: Dictionary = SL()["cloud"]
	SlowPuddle.spawn(get_parent(), pos, float(SC["r"]), float(SC["life"]), float(SC.get("slow", 0.0)), &"spore",
		{"tick_dmg": float(SC["tick_dmg"]) * out_mult(), "source": self})
	clouds += 1
	if elite:
		# Organic Certified: the glob splits into three on landing
		for i: int in 3:
			var a: float = TAU * float(i) / 3.0 + t
			var p2: Vector3 = pos + Vector3(cos(a), 0, sin(a)) * float(SL().get("split_spread", 2.6))
			SlowPuddle.spawn(get_parent(), p2, float(SC["r"]) * 0.7, float(SC["life"]), 0.0, &"spore", {"tick_dmg": float(SC["tick_dmg"]) * 0.6, "source": self})
			clouds += 1


func _attack_update(_dt: float) -> bool:
	return true


func _recover_update(_dt: float) -> bool:
	return state_t >= 0.2


func _on_attack_cancelled() -> void:
	_bulb_node.scale = Vector3.ONE
	_mouth_mat.emission_energy_multiplier = 0.0


func weak_point_exposed() -> bool:
	return true


func _weak_point_pos() -> Vector3:
	return _bulb.global_position if _bulb != null else get_center()


func _anim(_delta: float) -> void:
	_bulb_mat.emission_energy_multiplier = 0.6 + 0.3 * sin(t * 3.0)
	if state != State.TELEGRAPH:
		_bulb_node.rotation.z = sin(t * 1.3) * 0.08
