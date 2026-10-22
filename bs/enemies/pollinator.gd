class_name Pollinator
extends EnemyBase
## Pollinator — tiny buffer (BS_ENEMIES §3.5). 10 HP / 5 sting / 3 bolts. A striped bee-drone with an oversized
## pollen sac. It flies between allies and every `dust_every` (3 s) DUSTS the nearest non-buffed ally within
## `dust_range`: +30% damage and +20% speed for `buff_time` (6 s), a gold pollen aura (the ally's aura_bonus /
## aura_t, the framework's ally-aura hook). Telegraph: the sac pulses, a buzzing crescendo, 0.4 s. It flees from
## Bolt to stay `flee_range` (8 m) away; cornered (within `sting_range`) it stings for 5 (0.3 s chip telegraph).
## Elite (Swarm Pricing, honey rim): spawns with two more, and a dust from two or more stacks to +45%.

var dusts: int = 0
var stings: int = 0
var _dust_cd: float = 0.0
var _dust_target: EnemyBase = null
var _buffed: Array = []            # [[ally, until, base_speed]]
var _sac: MeshInstance3D
var _sac_mat: StandardMaterial3D
var _wings: Array[MeshInstance3D] = []
var _swarm_done: bool = false


func PL() -> Dictionary:
	return def["pollinator"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#ffcf4d"))))
	flash_mats.append(body)
	var dark: StandardMaterial3D = EnemyFx.mat(Color("#2a1a10"))
	EnemyFx.sphere(visual, 0.22, Vector3.ZERO, body, 0.5)
	EnemyFx.torus(visual, 0.04, 0.21, Vector3(0, 0, 0.0), dark).rotation.x = PI / 2.0
	EnemyFx.torus(visual, 0.04, 0.19, Vector3(0, 0, -0.1), dark).rotation.x = PI / 2.0
	EnemyFx.sphere(visual, 0.1, Vector3(0, 0.04, 0.26), dark)
	_sac_mat = EnemyFx.mat(Color("#ffd23e"), Color("#ffd23e"), 0.8)
	_sac = EnemyFx.sphere(visual, 0.2, Vector3(0, -0.18, -0.16), _sac_mat)
	for sx: float in [-0.22, 0.22]:
		var w: MeshInstance3D = EnemyFx.box(visual, Vector3(0.34, 0.02, 0.16), Vector3(sx, 0.2, 0), EnemyFx.mat(Color("#d8dee9")))
		_wings.append(w)


func _on_activate() -> void:
	dusts = 0
	stings = 0
	_dust_cd = randf_range(0.6, 1.4)
	_dust_target = null
	_buffed.clear()
	fire_cd = 1.0
	if elite and not _swarm_done and is_inside_tree() and get_parent() != null and not bool(opts.get("swarm_child", false)):
		_swarm_done = true
		for i: int in 2:
			EnemySpawner.spawn(&"pollinator", global_position + Vector3((i * 2 - 1) * 1.2, 0.3, 0.8), get_parent(), {"aggro": aggro, "elite": true, "swarm_child": true})


func _timers(delta: float) -> void:
	super._timers(delta)
	_dust_cd -= delta
	# expire the speed part of our buffs (the damage part expires through the ally's own aura_t)
	for i: int in range(_buffed.size() - 1, -1, -1):
		var e: Array = _buffed[i]
		var ally: EnemyBase = e[0] as EnemyBase
		if ally == null or not is_instance_valid(ally) or not ally.is_alive():
			_buffed.remove_at(i)
		elif t >= float(e[1]):
			ally.speed = float(e[2])
			ally.remove_meta(&"pollen")
			_buffed.remove_at(i)


## The nearest living non-buffed ally within dust_range (not another Pollinator).
func _find_ally() -> EnemyBase:
	var best: EnemyBase = null
	var bd: float = float(PL()["dust_range"])
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: EnemyBase = n as EnemyBase
		if e == null or e == self or e is Pollinator or not e.is_alive() or e.is_in_group(&"picket_corn"):
			continue
		if e.aura_t > 0.0 and not elite:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _hover_to(goal: Vector3, dt: float, spd: float) -> void:
	var to: Vector3 = goal - global_position
	desired_vel = to.normalized() * minf(spd, to.length() * 2.0) * move_mult() if can_move() and to.length() > 0.1 else Vector3.ZERO
	if to.length() > 0.2:
		face(Vector3(to.x, 0, to.z), dt, 6.0)


func _idle_update(dt: float) -> void:
	var goal: Vector3 = home + Vector3(cos(t * 0.9) * 2.0, 2.4 + sin(t * 1.7) * 0.5, sin(t * 0.9) * 2.0)
	_hover_to(goal, dt, speed)


func _position_update(dt: float) -> void:
	var d: float = flat_dist_to_target()
	var flee: float = float(PL()["flee_range"])
	# cornered: sting
	if d < float(PL()["sting_range"]) and fire_cd <= 0.0 and can_attack() and target_alive():
		begin_telegraph(&"sting", float(telegraph_def(&"sting").get("dur", 0.3)), -1.0, Vector3.INF, false)
		return
	# dust an ally when one is near and the sac is ready
	if _dust_cd <= 0.0 and can_attack():
		var ally: EnemyBase = _find_ally()
		if ally != null and ally.global_position.distance_to(global_position) < float(PL()["dust_reach"]):
			_dust_target = ally
			begin_telegraph(&"dust", float(telegraph_def(&"dust").get("dur", 0.4)), -1.0, Vector3.INF, false)
			return
	# movement: stay 8+ m from Bolt, else fly to the ally that needs pollen, else hover near home
	if d < flee:
		var away: Vector3 = global_position - target_pos()
		away.y = 0.0
		_hover_to(global_position + away.normalized() * 4.0 + Vector3(0, 2.6 - (global_position.y - target_pos().y), 0), dt, speed * 1.3)
		return
	var ally2: EnemyBase = _find_ally()
	if ally2 != null:
		_hover_to(ally2.global_position + Vector3(0, float(PL()["hover_height"]), 0) + Vector3(cos(t * 1.5), 0, sin(t * 1.5)) * 1.2, dt, speed)
	else:
		_hover_to(target_pos() + (global_position - target_pos()).normalized() * (flee + 1.5) + Vector3(0, float(PL()["hover_height"]), 0), dt, speed)


func _telegraph_update(dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_sac.scale = Vector3.ONE * (1.0 + k * 0.6)
	_sac_mat.emission_energy_multiplier = 0.8 + k * 3.0
	desired_vel *= 0.3
	var _u: float = dt


func _attack_begin() -> void:
	_sac.scale = Vector3.ONE
	_sac_mat.emission_energy_multiplier = 0.8
	match attack_kind:
		&"dust":
			_dust_cd = float(PL()["dust_every"])
			if _dust_target != null and is_instance_valid(_dust_target) and _dust_target.is_alive():
				_apply_dust(_dust_target)
		&"sting":
			fire_cd = float(PL()["sting_every"])
			if target_alive() and flat_dist_to_target() < float(PL()["sting_range"]) + 0.5 and not target_dodging():
				hurt_target(float(def["dmg"]), 3.0)
				stings += 1


func _apply_dust(ally: EnemyBase) -> void:
	var B: Dictionary = PL()["buff"]
	var dmg: float = float(B["damage"])
	if elite and ally.aura_t > 0.0:
		dmg = float(B.get("elite_stack", 0.45))          # Swarm Pricing: a second dust stacks to +45%
	ally.aura_bonus = maxf(ally.aura_bonus if ally.aura_t > 0.0 else 0.0, dmg)
	ally.aura_t = float(B["time"])
	var base: float = float(ally.get_meta(&"pollen_base_speed", ally.speed))
	if not ally.has_meta(&"pollen"):
		ally.set_meta(&"pollen_base_speed", base)
		ally.speed = base * (1.0 + float(B["speed"]))
		ally.set_meta(&"pollen", true)
		_buffed.append([ally, t + float(B["time"]), base])
	if get_parent() != null:
		EnemyFx.chunks(get_parent(), ally.get_center(), Color("#ffd23e"), 0.6, 4, 6)
	dusts += 1


func _attack_update(_dt: float) -> bool:
	return true


func _recover_update(_dt: float) -> bool:
	return state_t >= 0.15


func _on_attack_cancelled() -> void:
	_sac.scale = Vector3.ONE
	_sac_mat.emission_energy_multiplier = 0.8


func _anim(_delta: float) -> void:
	for i: int in _wings.size():
		_wings[i].rotation.z = sin(t * 60.0 + float(i) * PI) * 0.5
	visual.position.y = sin(t * 4.0) * 0.08
	if state != State.TELEGRAPH:
		_sac_mat.emission_energy_multiplier = 0.8 + 0.3 * sin(t * 5.0)


func _owns_visual_y() -> bool:
	return true
