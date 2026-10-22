class_name Foreman
extends Zombie
## The Foreman (Obersteiger Gustav Mahlknecht), Map 1 boss (docs/ENEMIES.md §2.4).
## Subclasses Zombie only so weapons, explosions and melee treat him like any enemy (take_damage,
## hitbox_rids, is_active); his body, AI and death are his own. Not pooled: the director creates him.
##
## AI: EMERGE -> STALK -> (jab | slam | whip | charge) -> RECOVER -> STALK, plus STUNNED and ENRAGED.

enum F { EMERGE, STALK, JAB, SLAM, WHIP, CHARGE_WINDUP, CHARGE, RECOVER, STUNNED }

var fstate: F = F.EMERGE
var enraged: bool = false
var _fc: Dictionary = {}
var _ft: float = 0.0
var _cd: Dictionary = {"jab": 0.0, "slam": 2.0, "whip": 0.0, "charge": 4.0}
var _charge_dir: Vector3 = Vector3.FORWARD
var _charge_from: Vector3 = Vector3.ZERO
var _hit_done: bool = false
var _weak_log: Array = []     # [time, amount] of recent weak-point damage
var _clock: float = 0.0
var _step_t: float = 0.0
var _chain_t: float = 0.0
var _drill: Node3D
var _core_mat: StandardMaterial3D
var _arm_r: Node3D
var _chain: Array[Node3D] = []
var _drill_loop: AudioStreamPlayer3D   # child of the drill: freed with him, played while the drill jabs


func _ready() -> void:
	enemy_id = &"foreman"
	_fc = GLData.table("enemies")["enemies"]["foreman"]
	_cfg = Zombie.kind_config(&"ganger")
	_collision = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.75
	cap.height = 3.2
	_collision.shape = cap
	_collision.position = Vector3(0, 1.6, 0)
	add_child(_collision)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.6
	_agent.radius = 0.5
	_agent.height = 3.2
	_agent.avoidance_enabled = false
	add_child(_agent)
	_build_foreman()
	_drill_loop = AudioDirector.make_loop_3d("foreman_drill", _drill)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


## Bursts out of the ground at `at` with `health`. A 4 s audio tell comes first (the wall cracking).
func spawn_boss(at: Vector3, health: float) -> void:
	net_died = false
	max_hp = health
	hp = health
	global_position = at
	state = State.CHASE
	fstate = F.EMERGE
	_ft = 0.0
	enraged = false
	_pivot.position.y = -3.4
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_sound("board_break", 6.0, 0.35)   # the wall cracking (GLBus.boss_spawned plays the roar)


func _speed() -> float:
	return float(_fc["walk_speed"]) * (float(_fc["enrage_speed_mult"]) if enraged else 1.0)


func _cd_mult() -> float:
	return float(_fc["enrage_cooldown_mult"]) if enraged else 1.0


func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_tick(delta)
		return
	if state == State.DEAD:
		_update_dead(delta)
		return
	_clock += delta
	_ft += delta
	for k: Variant in _cd.keys():
		_cd[k] = maxf(0.0, float(_cd[k]) - delta)
	_update_burn(delta)
	if _frost_t > 0.0:
		_frost_t -= delta
	target = _nearest_player()
	match fstate:
		F.EMERGE:
			_halt(delta)
			var tell: float = float(_fc.get("spawn_delay", 4.0))
			if _ft > tell:
				var t: float = clampf((_ft - tell) / 1.6, 0.0, 1.0)
				_pivot.position.y = lerpf(-3.4, 0.0, t)
				if t >= 1.0:
					_sound("grenade_explode", 2.0, 0.5)
					_sound("foreman_roar", 4.0)
					GLBus.explosion.emit(global_position, 4.0)
					_go(F.STALK)
		F.STALK:
			_update_stalk(delta)
		F.JAB:
			_update_jab(delta)
		F.SLAM:
			_update_slam(delta)
		F.WHIP:
			_update_whip(delta)
		F.CHARGE_WINDUP:
			_halt(delta)
			if target != null:
				_face(target.global_position)
			if _ft >= float(_fc["charge"]["windup"]):
				_charge_dir = -global_basis.z
				_charge_dir.y = 0.0
				_charge_dir = _charge_dir.normalized()
				_charge_from = global_position
				_go(F.CHARGE)
		F.CHARGE:
			_update_charge(delta)
		F.RECOVER:
			_halt(delta)
			if _ft >= float(_fc["recover_seconds"]):
				_go(F.STALK)
		F.STUNNED:
			_halt(delta)
			if _ft >= float(_fc["stun_seconds"]):
				_go(F.STALK)
	_update_audio(delta)


func _go(f: F) -> void:
	fstate = f
	_ft = 0.0
	_hit_done = false
	match f:
		F.JAB:
			_sound("gun_smg", -2.0, 0.6)
		F.SLAM:
			_sound("zombie_attack", 4.0, 0.55)
		F.WHIP:
			_sound("board_break", 0.0, 0.7)
		F.CHARGE_WINDUP:
			_sound("zombie_attack", 8.0, 0.45)
			_sound("board_break", 2.0, 0.4)
		F.STUNNED:
			_sound("board_slam", 6.0, 0.5)


func _update_stalk(delta: float) -> void:
	if target == null:
		_halt(delta)
		return
	var to_t: Vector3 = target.global_position - global_position
	var flat: Vector3 = Vector3(to_t.x, 0, to_t.z)
	var d: float = flat.length()
	var behind: bool = flat.length() > 0.1 and (-global_basis.z).dot(flat.normalized()) < -0.2
	if d <= float(_fc["jab"]["reach"]) and float(_cd["jab"]) <= 0.0:
		_go(F.JAB)
	elif d <= float(_fc["slam"]["radius"]) * 0.9 and float(_cd["slam"]) <= 0.0:
		_go(F.SLAM)
	elif behind and d >= float(_fc["whip"]["min"]) and d <= float(_fc["whip"]["max"]) and float(_cd["whip"]) <= 0.0:
		_go(F.WHIP)
	elif d >= float(_fc["charge"]["min_distance"]) and d <= float(_fc["charge"]["max_distance"]) and float(_cd["charge"]) <= 0.0 and _has_los(target):
		_go(F.CHARGE_WINDUP)
	else:
		_nav_move(target.global_position, _speed(), delta, 0.4)


func _update_jab(delta: float) -> void:
	_halt(delta)
	if target != null:
		_face(target.global_position)
	_drill.rotation.z += delta * 40.0
	var j: Dictionary = _fc["jab"]
	if not _hit_done and _ft >= float(j["windup"]):
		_hit_done = true
		_cd["jab"] = float(j["cooldown"]) * _cd_mult()
		if target != null and target.global_position.distance_to(global_position) <= float(j["reach"]) + 0.6:
			target.take_hit(float(j["damage"]), self)
			target.apply_knockback(_dir_to(target) * float(j["knockback"]))
	if _ft >= float(j["windup"]) + 0.3:
		_go(F.RECOVER)


func _update_slam(delta: float) -> void:
	_halt(delta)
	var s: Dictionary = _fc["slam"]
	var w: float = float(s["windup"])
	_arm_r.rotation.x = lerpf(0.3, 2.9, clampf(_ft / w, 0.0, 1.0)) if _ft < w else lerpf(2.9, 0.2, clampf((_ft - w) / 0.15, 0.0, 1.0))
	if not _hit_done and _ft >= w:
		_hit_done = true
		_cd["slam"] = float(s["cooldown"]) * _cd_mult()
		var at: Vector3 = global_position - global_basis.z * 1.2
		Effects.explosion(at + Vector3.UP * 0.2, float(s["radius"]))
		if Net.replicating():
			Net.session.zombie_event(self, &"fx", ["slam", at, float(s["radius"])])
		_sound("grenade_explode", 4.0, 0.6)
		GLBus.explosion.emit(at, float(s["radius"]))
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p == null or not p.is_alive():
				continue
			var d: float = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
			if absf(p.global_position.y - at.y) > 1.6:
				continue   # jumped over the shockwave
			if d <= float(s["radius"]):
				p.take_hit(float(s["damage"]), self)
				p.apply_status(&"knockdown", float(s["knockdown"]))
				p.apply_knockback(_dir_to(p) * 5.0)
			elif d <= float(s["radius_far"]):
				p.take_hit(float(s["damage_far"]), self)
	if _ft >= w + 0.5:
		_go(F.RECOVER)


func _update_whip(delta: float) -> void:
	_halt(delta)
	var wd: Dictionary = _fc["whip"]
	if not _hit_done and _ft >= 0.4:
		_hit_done = true
		_cd["whip"] = float(wd["cooldown"]) * _cd_mult()
		if target != null and target.global_position.distance_to(global_position) <= float(wd["max"]) + 0.5:
			target.take_hit(float(wd["damage"]), self)
			target.apply_status(&"whip_slow", float(wd["slow_seconds"]))
	if _ft >= 0.8:
		_go(F.RECOVER)


func _update_charge(delta: float) -> void:
	var c: Dictionary = _fc["charge"]
	var before: Vector3 = global_position
	velocity.x = _charge_dir.x * float(_fc["charge_speed"])
	velocity.z = _charge_dir.z * float(_fc["charge_speed"])
	_apply_gravity(delta)
	move_and_slide()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and not _hit_done and p.global_position.distance_to(global_position) < 1.8:
			_hit_done = true
			p.take_hit(float(c["damage"]), self)
			p.apply_knockback(_charge_dir * float(c["knockback"]))
	var travelled: float = global_position.distance_to(_charge_from)
	var stalled: bool = before.distance_to(global_position) < float(_fc["charge_speed"]) * delta * 0.3
	if is_on_wall() and stalled and travelled > 1.0:
		_cd["charge"] = float(c["cooldown"]) * _cd_mult()
		GLBus.explosion.emit(global_position, 3.0)
		_go(F.STUNNED)
	elif travelled >= float(c["max_distance"]) or _ft > 3.0 or _hit_done:
		_cd["charge"] = float(c["cooldown"]) * _cd_mult()
		_go(F.RECOVER)


func _dir_to(p: Node3D) -> Vector3:
	var d: Vector3 = p.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.001 else -global_basis.z


func _has_los(p: Node3D) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0,
		p.global_position + Vector3.UP * 1.2, 1 | (1 << 8))
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ---------------------------------------------------------------- damage

func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", _armor_piercing: bool = false) -> bool:
	if puppet:
		return _puppet_damage(amount, limb, weapon_id, by_player, kind, _armor_piercing)
	last_hit_bone = ""   # his body has no rig bones; the weapon's report is simply consumed
	if not is_active():
		return false
	var mult: float = 1.0
	match limb:
		&"weakpoint":
			mult = float(_fc["stunned_weakpoint_mult"]) if fstate == F.STUNNED else float(_fc["weakpoint_mult"])
		&"helmet", &"head":
			mult = float(_fc["helmet_mult"])
	amount *= mult
	hp -= amount
	GLBus.enemy_damaged.emit(enemy_id, limb, amount, by_player)
	if hp <= 0.0:
		_die(limb, weapon_id, by_player, kind)
		return true
	if by_player > 0 and kind != &"fire":
		Economy.award(by_player, int(GLData.table("economy")["hit_nonlethal"]))
	if limb == &"weakpoint":
		_weak_log.append([_clock, amount])
		var sum: float = 0.0
		var keep: Array = []
		for e: Array in _weak_log:
			if _clock - float(e[0]) <= float(_fc["stun_burst_window"]):
				keep.append(e)
				sum += float(e[1])
		_weak_log = keep
		if sum >= max_hp * float(_fc["stun_burst_fraction"]) and fstate != F.STUNNED and fstate != F.EMERGE:
			_weak_log.clear()
			_go(F.STUNNED)
	if not enraged and hp <= max_hp * float(_fc["enrage_fraction"]):
		enraged = true
		_core_mat.emission_energy_multiplier = 9.0
		_sound("foreman_roar", 8.0)
	return false


func become_crawler() -> void:
	pass


func force_stagger() -> void:
	pass


func recycle() -> void:
	pass


func _die(limb: StringName, weapon_id: StringName, by_player: int, _kind: StringName) -> void:
	state = State.DEAD
	_state_t = 0.0
	collision_layer = 0
	collision_mask = LAYER_WORLD
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	velocity = Vector3.ZERO
	if by_player > 0:
		for pid: int in GameState.player_ids:
			Economy.award(pid, int(_fc["kill_scrip"]))
	var drops: Array = ["resupply", "deaths_door", "double_scrip", "blackout", "fortify"]
	PowerupManager.spawn(StringName(drops[randi() % drops.size()]), global_position + Vector3.UP * 0.5)
	_shards(Color(0.6, 0.3, 1.0), 60, 7.0)
	_sound("grenade_explode", 6.0, 0.4)
	_sound("foreman_roar", 8.0)
	if _drill_loop != null:
		_drill_loop.stop()
	var reported: StringName = &"head" if limb == &"helmet" else limb
	GLBus.enemy_killed.emit(enemy_id, reported, weapon_id, by_player)
	GLBus.enemy_killed_at.emit(enemy_id, global_position, by_player)
	RoundManager.on_zombie_died()
	if Net.replicating():
		Net.session.zombie_died(self, limb, _kind, 0, 1.0, false)


func _update_dead(delta: float) -> void:
	_state_t += delta
	_pivot.rotation.x = lerpf(_pivot.rotation.x, -1.4, clampf(delta * 2.0, 0.0, 1.0))
	if _state_t > 2.5:
		_pivot.position.y -= delta * 1.2
	if _state_t > 4.0:
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		state = State.INACTIVE
		if director != null:
			director.call("on_zombie_returned", self)


# ---------------------------------------------------------------- presentation

func _process(delta: float) -> void:
	if state == State.INACTIVE:
		return
	_drill.rotation.z += delta * (4.0 if fstate != F.JAB else 0.0)
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.3
	if moving:
		_phase += delta * (3.0 if fstate != F.CHARGE else 9.0)
	(_parts["hip_l"] as Node3D).rotation.x = sin(_phase) * 0.35 if moving else 0.0
	(_parts["hip_r"] as Node3D).rotation.x = -sin(_phase) * 0.35 if moving else 0.0
	(_parts["shin_l"] as Node3D).rotation.x = (-maxf(0.0, cos(_phase)) * 0.6 - 0.1) if moving else -0.1
	(_parts["shin_r"] as Node3D).rotation.x = (-maxf(0.0, -cos(_phase)) * 0.6 - 0.1) if moving else -0.1
	if fstate != F.SLAM:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 1.2 if fstate == F.JAB or fstate == F.CHARGE else 0.5, 0.2)
	if fstate == F.STUNNED:
		_pivot.rotation.x = lerpf(_pivot.rotation.x, -0.35, 0.1)
		_core_mat.emission_energy_multiplier = 6.0 + sin(_clock * 18.0) * 4.0
	elif state != State.DEAD:
		_pivot.rotation.x = lerpf(_pivot.rotation.x, -0.12 if fstate == F.CHARGE else 0.0, 0.1)
		_core_mat.emission_energy_multiplier = 9.0 if enraged else 4.0 + sin(_clock * 4.0)
	# the chain drags behind
	for i: int in _chain.size():
		_chain[i].position = Vector3(-0.9 - sin(_phase + float(i)) * 0.05, 0.1, 0.35 + float(i) * 0.17)


func _update_audio(delta: float) -> void:
	if not is_active():
		return
	_step_t -= delta
	_chain_t -= delta
	if Vector2(velocity.x, velocity.z).length() > 0.3 and _step_t <= 0.0:
		_step_t = 0.7 if fstate != F.CHARGE else 0.25
		_sound("foreman_step", 0.0)
	if _chain_t <= 0.0:
		_chain_t = 1.2
		_sound("foreman_chain", 0.0)
		if randf() < 0.15:
			_sound("foreman_roar", -2.0)   # "Schicht! Weiter!"
	# The drill screams only while it jabs (toggled on change, never restarted per frame).
	if _drill_loop != null:
		var want: bool = fstate == F.JAB and state != State.DEAD
		if want != _drill_loop.playing:
			if want:
				_drill_loop.play()
			else:
				_drill_loop.stop()


## pitch 1.0 keeps the bank's own pitch range; the remaining generic sounds (blasts, cracking) are pitched down.
func _sound(n: String, db: float, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer3D = AudioDirector.play_3d(n, global_position + Vector3.UP * 2.0, db, 0.05)
	if p != null:
		if pitch != 1.0:
			p.pitch_scale = pitch
		p.max_distance = maxf(p.max_distance, 60.0)


func _build_foreman() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_mats["coat"] = ZombieBody.material("miner", "cloth")
	_mats["skin"] = ZombieBody.material("_", "skin_base")
	_mats["metal"] = ZombieBody.material("_", "metal")
	_core_mat = Interactable.greybox_mat(Color(0.65, 0.3, 1.0), 4.0)
	var V: String = "miner"   # material set: brown work clothes, leather, steel
	# legs: thigh + bending shin, heavy boots and knee guards
	for side: float in [-1.0, 1.0]:
		var hip: Node3D = Node3D.new()
		hip.position = Vector3(0.32 * side, 1.35, 0)
		_pivot.add_child(hip)
		_hitbox(hip, Vector3(0.42, 1.35, 0.48), Vector3(0, -0.67, 0), &"legs")
		_mesh(hip, [ZombieBody._cyl(0.2, 0.165, 0.72, Vector3(0, -0.34, 0), "cloth2", Vector3.ZERO, Vector3(1, 1, 1.05), 10),
			ZombieBody._sph(0.13, Vector3(0, -0.68, -0.07), "metal", Vector3(1.0, 1.0, 0.6))], V)
		var shin: Node3D = Node3D.new()
		shin.position = Vector3(0, -0.7, 0)
		hip.add_child(shin)
		_mesh(shin, [ZombieBody._cyl(0.16, 0.14, 0.5, Vector3(0, -0.25, 0), "leather", Vector3.ZERO, Vector3.ONE, 10),
			ZombieBody._box(Vector3(0.3, 0.16, 0.48), Vector3(0, -0.58, -0.1), "leather"),
			ZombieBody._box(Vector3(0.32, 0.04, 0.5), Vector3(0, -0.66, -0.1), "metal")], V)
		_parts["hip_l" if side < 0.0 else "hip_r"] = hip
		_parts["shin_l" if side < 0.0 else "shin_r"] = shin
	# pelvis + work apron
	_mesh(_pivot, [ZombieBody._cyl(0.42, 0.4, 0.34, Vector3(0, 1.38, 0), "cloth2", Vector3.ZERO, Vector3(1.25, 1, 0.85), 12),
		ZombieBody._box(Vector3(0.62, 0.9, 0.04), Vector3(0, 1.15, -0.37), "leather", Vector3(0.12, 0, 0))], V)
	# hunched barrel torso with a hump, straps and Nachtglas veins breaking through
	var torso: Node3D = _hitbox(_pivot, Vector3(1.35, 1.25, 0.85), Vector3(0, 2.0, 0), &"torso")
	var chest_mesh: Array = [
		ZombieBody._cyl(0.62, 0.46, 1.25, Vector3.ZERO, "cloth", Vector3(-0.18, 0, 0), Vector3(1.15, 1, 0.82), 14),
		ZombieBody._sph(0.5, Vector3(0, 0.38, 0.22), "cloth", Vector3(1.3, 0.8, 1.0)),
		ZombieBody._box(Vector3(0.08, 1.2, 0.04), Vector3(-0.28, 0.0, -0.4), "leather", Vector3(-0.15, 0, 0.12)),
		ZombieBody._box(Vector3(0.08, 1.2, 0.04), Vector3(0.28, 0.0, -0.4), "leather", Vector3(-0.15, 0, -0.12)),
		ZombieBody._box(Vector3(0.9, 0.1, 0.06), Vector3(0, -0.45, -0.38), "leather")]
	for k: int in 7:
		var a: float = float(k) * 0.9
		chest_mesh.append(ZombieBody._box(Vector3(0.03, 0.35 + 0.05 * float(k % 3), 0.03), Vector3(sin(a) * 0.45, -0.1 + 0.08 * float(k), -cos(a) * 0.4 - 0.05), "crystal", Vector3(0.2, 0, a)))
	_mesh(torso, chest_mesh, V)
	# head: heavy jaw, sunken eyes, the Obersteiger helmet with a headlamp
	var head: Node3D = _hitbox(_pivot, Vector3(0.48, 0.5, 0.5), Vector3(0, 2.9, -0.1), &"helmet")
	_mesh(head, [
		ZombieBody._sph(0.24, Vector3(0, -0.02, 0), "skin", Vector3(0.95, 1.05, 1.0)),
		ZombieBody._box(Vector3(0.3, 0.12, 0.26), Vector3(0, -0.2, -0.06), "skin"),
		ZombieBody._box(Vector3(0.22, 0.03, 0.02), Vector3(0, -0.16, -0.2), "teeth"),
		ZombieBody._sph(0.06, Vector3(-0.09, 0.02, -0.19), "dark", Vector3(1.3, 0.8, 0.6)),
		ZombieBody._sph(0.06, Vector3(0.09, 0.02, -0.19), "dark", Vector3(1.3, 0.8, 0.6)),
		ZombieBody._sph(0.024, Vector3(-0.09, 0.02, -0.225), "eye"),
		ZombieBody._sph(0.024, Vector3(0.09, 0.02, -0.225), "eye"),
		ZombieBody._sph(0.31, Vector3(0, 0.08, 0.02), "metal", Vector3(1, 0.75, 1.05), true, 12),
		ZombieBody._box(Vector3(0.5, 0.03, 0.2), Vector3(0, 0.07, -0.3), "metal", Vector3(-0.2, 0, 0)),
		ZombieBody._cyl(0.06, 0.06, 0.1, Vector3(0, 0.2, -0.3), "metal", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 8),
		ZombieBody._cyl(0.05, 0.05, 0.02, Vector3(0, 0.2, -0.36), "lens", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 8)], V)
	# right arm: pauldron, piston arm and the pneumatic drill with its glowing core (the weak point)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.88, 2.45, 0)
	_pivot.add_child(_arm_r)
	_hitbox(_arm_r, Vector3(0.36, 0.9, 0.36), Vector3(0, -0.4, 0), &"arms")
	_mesh(_arm_r, [
		ZombieBody._sph(0.3, Vector3(0.05, 0.05, 0), "metal", Vector3(1.1, 0.8, 1.1), true, 10),
		ZombieBody._cyl(0.17, 0.14, 0.85, Vector3(0, -0.4, 0), "cloth", Vector3.ZERO, Vector3.ONE, 10),
		ZombieBody._cyl(0.035, 0.035, 0.7, Vector3(0.17, -0.45, 0.08), "metal", Vector3(0, 0, 0.1), Vector3.ONE, 6),
		ZombieBody._cyl(0.035, 0.035, 0.7, Vector3(-0.15, -0.45, 0.1), "metal", Vector3(0, 0, -0.1), Vector3.ONE, 6)], V)
	_drill = Node3D.new()
	_drill.position = Vector3(0, -0.95, -0.3)
	_drill.rotation.x = -PI * 0.5
	_arm_r.add_child(_drill)
	var bit: Array = [
		ZombieBody._cyl(0.2, 0.22, 1.0, Vector3(0, 0, -0.25), "metal", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12),
		ZombieBody._cyl(0.24, 0.24, 0.08, Vector3(0, 0, -0.75), "leather", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12),
		ZombieBody._cyl(0.0, 0.16, 0.8, Vector3(0, 0, -1.18), "metal", Vector3(-PI * 0.5, 0, 0), Vector3.ONE, 10)]
	for k2: int in 6:
		var a2: float = float(k2) * TAU / 6.0
		bit.append(ZombieBody._box(Vector3(0.03, 0.14, 0.25), Vector3(cos(a2) * 0.1, sin(a2) * 0.1, -0.95 - 0.06 * float(k2)), "metal", Vector3(0, 0, a2)))
	_mesh(_drill, bit, V)
	var core_holder: Node3D = _hitbox(_arm_r, Vector3(0.36, 0.36, 0.36), Vector3(0, -0.95, 0.12), &"weakpoint")
	var core: MeshInstance3D = MeshInstance3D.new()
	var cs: SphereMesh = SphereMesh.new()
	cs.radius = 0.19
	cs.height = 0.38
	core.mesh = cs
	core.material_override = _core_mat
	core_holder.add_child(core)
	_mesh(core_holder, [ZombieBody._box(Vector3(0.04, 0.44, 0.04), Vector3(0.14, 0, 0), "metal"),
		ZombieBody._box(Vector3(0.04, 0.44, 0.04), Vector3(-0.14, 0, 0), "metal"),
		ZombieBody._box(Vector3(0.44, 0.04, 0.04), Vector3(0, 0.14, 0), "metal")], V)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.65, 0.3, 1.0)
	glow.omni_range = 4.0
	glow.light_energy = 1.4
	core_holder.add_child(glow)
	# left arm: a fist wrapped in ore chain
	var arm_l: Node3D = Node3D.new()
	arm_l.position = Vector3(-0.88, 2.45, 0)
	_pivot.add_child(arm_l)
	_hitbox(arm_l, Vector3(0.36, 1.1, 0.36), Vector3(0, -0.5, 0), &"arms")
	var fist: Array = [
		ZombieBody._cyl(0.17, 0.14, 1.0, Vector3(0, -0.5, 0), "skin", Vector3.ZERO, Vector3.ONE, 10),
		ZombieBody._sph(0.26, Vector3(0, -1.15, -0.02), "skin", Vector3(1.0, 1.1, 0.95))]
	for k3: int in 5:
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = 0.2
		tor.outer_radius = 0.28
		tor.rings = 10
		tor.ring_segments = 6
		fist.append([tor, Transform3D(Basis.from_euler(Vector3(0.3 * float(k3), 0, 0.5 * float(k3 % 2))), Vector3(0, -1.0 - 0.07 * float(k3), 0)), "metal"])
	_mesh(arm_l, fist, V)
	# the dragging chain
	for i: int in 8:
		var link: MeshInstance3D = MeshInstance3D.new()
		var t: TorusMesh = TorusMesh.new()
		t.inner_radius = 0.05
		t.outer_radius = 0.1
		t.rings = 8
		t.ring_segments = 6
		link.mesh = t
		link.material_override = _mats["metal"]
		link.rotation = Vector3(PI * 0.5, 0, PI * 0.5 * float(i % 2))
		add_child(link)
		_chain.append(link)


func _mesh(parent: Node3D, parts: Array, variant: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ZombieBody.build_mesh(variant, parts)
	parent.add_child(mi)
	return mi


## A pivot holder at `pos` with a hitbox of `size` (same layout as the old box body).
func _hitbox(parent: Node3D, size: Vector3, pos: Vector3, limb: StringName) -> Node3D:
	var holder: Node3D = Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var hb: Hitbox = Hitbox.new()
	hb.setup(self, limb, size * 1.05)
	holder.add_child(hb)
	_hitboxes.append(hb)
	return holder


func _bpart(parent: Node3D, size: Vector3, pos: Vector3, limb: StringName, m: Material) -> Node3D:
	var holder: Node3D = Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	holder.add_child(mi)
	var hb: Hitbox = Hitbox.new()
	hb.setup(self, limb, size * 1.05)
	holder.add_child(hb)
	_hitboxes.append(hb)
	return holder


# ---------------------------------------------------------------- co-op puppet (M7)

func net_sub_state() -> int:
	return int(fstate)


func puppet_activate(_enemy: StringName, _tier_v: StringName, _variant: String, hp_max: float, pos: Vector3, yaw: float,
		_st: int, sub: int, local_p: Player) -> void:
	target = local_p
	spawn_boss(pos, hp_max)
	collision_mask = 0
	rotation.y = yaw
	interp.snap(float(Time.get_ticks_msec()), pos, yaw)
	if (sub as F) != F.EMERGE:
		fstate = sub as F
		_pivot.position.y = 0.0
	GLBus.enemy_spawned.emit(enemy_id, get_instance_id())


func _puppet_enter(_st: int, sub: int) -> void:
	if (sub as F) != fstate:
		_go(sub as F)


func _puppet_visual_tick(delta: float) -> void:
	_ft += delta
	_clock += delta
	if fstate == F.EMERGE:
		var tell: float = float(_fc.get("spawn_delay", 4.0))
		if _ft > tell:
			_pivot.position.y = lerpf(-3.4, 0.0, clampf((_ft - tell) / 1.6, 0.0, 1.0))
	elif _pivot.position.y < 0.0:
		_pivot.position.y = 0.0
	if not enraged and ((interp.flags >> 8) & NetMatch.ZF_ENRAGED) != 0:
		enraged = true
		_sound("foreman_roar", 8.0)


func _puppet_dead(delta: float) -> void:
	_update_dead(delta)


func puppet_die(_limb: StringName, _kind: StringName, _death_kind: int, _side: float, _pop: bool, pos: Vector3) -> void:
	if state == State.DEAD or state == State.INACTIVE:
		return
	if pos.is_finite():
		global_position = pos
	_puppet_hide_hitboxes()
	state = State.DEAD
	_state_t = 0.0
	_shards(Color(0.6, 0.3, 1.0), 60, 7.0)
	_sound("grenade_explode", 6.0, 0.4)
	_sound("foreman_roar", 8.0)
	if _drill_loop != null:
		_drill_loop.stop()


func puppet_fx(what: StringName, args: Array) -> void:
	if what == &"slam" and args.size() >= 2:
		Effects.explosion((args[0] as Vector3) + Vector3.UP * 0.2, float(args[1]))
		_sound("grenade_explode", 4.0, 0.6)
