class_name Screamer
extends Zombie
## The Screamer (Schwester Ilse Brandauer), Map 1, rare (docs/ENEMIES.md §2.5).
## Reuses the Ganger body (Zombie) with a nurse's cape and winged headdress. She keeps her distance,
## winds up for 1.5 s with a rising tone, then screams down a 20 m line-of-sight cone:
## GLBus.player_status(player, &"scream", 3.0). She flees when a player gets within 5 m.

enum S { EMERGE, REPOSITION, WINDUP, CLAW }

var sstate: S = S.EMERGE
var _sc: Dictionary = {}
var _st: float = 0.0
var _scream_cd: float = 4.0
var _hum_t: float = 1.0
var _claw_cd: float = 0.0
var _throat: OmniLight3D
var _dress_built: bool = false


func _ready() -> void:
	super._ready()
	_sc = GLData.table("enemies")["enemies"]["screamer"]


func spawn_screamer(at: Vector3, health: float) -> void:
	net_died = false
	enemy_id = &"screamer"
	_cfg = Zombie.kind_config(&"screamer")
	max_hp = health
	hp = health
	speed = float(_sc["walk_speed"])
	tier = &"walk"
	armor_torso_mult = 1.0
	if not _dress_built:
		_build_dress()
	_apply_variant("nurse")
	_asym["hunch"] = 0.05
	_asym["jaw"] = 0.15
	_pivot.scale = Vector3.ONE * 1.05
	(_kind_nodes["glass"] as Node3D).hide()
	(_kind_nodes["glass_arm"] as Node3D).hide()
	(_kind_nodes["lantern"] as Node3D).hide()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	global_position = at
	_agent.avoidance_enabled = false
	state = State.CHASE
	sstate = S.EMERGE
	_st = 0.0
	_pivot.position.y = -1.7
	_scream_cd = randf_range(3.0, 5.0)


func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_tick(delta)
		return
	if state == State.DEAD:
		_state_t += delta
		_update_dead(delta)
		return
	_st += delta
	_scream_cd -= delta
	_claw_cd = maxf(0.0, _claw_cd - delta)
	_update_burn(delta)
	if _frost_t > 0.0:
		_frost_t -= delta
	target = _nearest_player()
	match sstate:
		S.EMERGE:
			_halt(delta)
			var t: float = clampf(_st / 1.4, 0.0, 1.0)
			_pivot.position.y = lerpf(-1.7, 0.0, t)
			if t >= 1.0:
				_set_s(S.REPOSITION)
		S.REPOSITION:
			_reposition(delta)
		S.WINDUP:
			_halt(delta)
			if target != null:
				_face(target.global_position)
			var w: float = float(_sc["windup"])
			_throat.light_energy = lerpf(0.4, 5.0, clampf(_st / w, 0.0, 1.0))
			if _st >= w:
				_scream()
				_set_s(S.REPOSITION)
		S.CLAW:
			_halt(delta)
			if target != null:
				_face(target.global_position)
			if _st >= 0.35:
				if target != null and target.global_position.distance_to(global_position) <= float(_sc["claw_range"]) + 0.5:
					target.take_hit(float(_sc["claw_damage"]), self)
				_claw_cd = 1.2
				_set_s(S.REPOSITION)
	_update_audio(delta)


func _set_s(s: S) -> void:
	sstate = s
	_st = 0.0
	if s == S.WINDUP:
		# the sharp intake of breath, then a rising tone
		var p: AudioStreamPlayer3D = AudioDirector.play_3d("zombie_sprint", global_position + Vector3.UP * 1.6, 2.0, 0.0)
		if p != null:
			p.pitch_scale = 1.6
		var tw: Tween = create_tween()
		tw.tween_interval(0.7)
		tw.tween_callback(func() -> void:
			var q: AudioStreamPlayer3D = AudioDirector.play_3d("zombie_sprint", global_position + Vector3.UP * 1.6, 4.0, 0.0)
			if q != null:
				q.pitch_scale = 2.1)
	elif s == S.REPOSITION:
		_throat.light_energy = 0.6


func _reposition(delta: float) -> void:
	if target == null:
		_halt(delta)
		return
	var away: Vector3 = global_position - target.global_position
	away.y = 0.0
	var d: float = away.length()
	if d <= float(_sc["claw_range"]) and _claw_cd <= 0.0:
		_set_s(S.CLAW)
		return
	if d < float(_sc["flee_dist"]):
		_nav_move(global_position + away.normalized() * 6.0, float(_sc["reposition_speed"]), delta, 0.3)
	elif d < float(_sc["keep_min"]):
		_nav_move(global_position + away.normalized() * 5.0, float(_sc["walk_speed"]), delta, 0.4)
	elif d > float(_sc["keep_max"]):
		_nav_move(target.global_position, float(_sc["walk_speed"]), delta, 0.5)
	else:
		_halt(delta)
		_face(target.global_position)
	if _scream_cd <= 0.0 and d <= float(_sc["scream_range"]) and _los(target):
		_set_s(S.WINDUP)


func _scream() -> void:
	_scream_cd = randf_range(float(_sc["cooldown_min"]), float(_sc["cooldown_max"]))
	var fwd: Vector3 = -global_basis.z
	var hit_any: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var to_p: Vector3 = p.global_position - global_position
		var dist: float = to_p.length()
		var flat: Vector3 = Vector3(to_p.x, 0, to_p.z).normalized()
		if dist > float(_sc["scream_range"]) or fwd.dot(flat) < cos(deg_to_rad(float(_sc["scream_cone_deg"]))) or not _los(p):
			continue
		GLBus.player_status.emit(p.player_id, &"scream", float(_sc["effect_seconds"]))
		hit_any = true
	var s: AudioStreamPlayer3D = AudioDirector.play_3d("screamer_scream", global_position + Vector3.UP * 1.6, 4.0, 0.0)
	if s != null:
		s.max_distance = maxf(s.max_distance, 50.0)
	if Net.replicating():
		Net.session.zombie_event(self, &"fx", ["scream"])
	if hit_any:
		GLBus.explosion.emit(global_position, 0.1)


func _los(p: Node3D) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.6,
		p.global_position + Vector3.UP * 1.5, 1 | (1 << 8))
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func recycle() -> void:
	pass


func become_crawler() -> void:
	pass


func _die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	_throat.light_energy = 0.0
	_shards(Color(0.65, 0.3, 1.0), 20, 3.0)
	var p: AudioStreamPlayer3D = AudioDirector.play_3d("zombie_death", global_position + Vector3.UP * 1.5, 4.0, 0.0)
	if p != null:
		p.pitch_scale = 1.7   # the choked final note
	super._die(limb, weapon_id, by_player, kind)


func _update_audio(delta: float) -> void:
	if not is_active():
		return
	_hum_t -= delta
	if _hum_t <= 0.0:
		_hum_t = randf_range(2.5, 4.0)
		AudioDirector.play_3d("screamer_hum", global_position + Vector3.UP * 1.6, 0.0, 0.0)   # a lullaby hummed wrong


func _build_dress() -> void:
	_dress_built = true
	# The winged wimple, cape and apron are part of the "nurse" body variant (ZombieBody).
	# Here: the Nachtglas-saturated throat that glows brighter as she winds up.
	var neck: Node3D = _bones["neck"]
	var throat_mesh: MeshInstance3D = MeshInstance3D.new()
	throat_mesh.mesh = ZombieBody.build_mesh("_", [
		ZombieBody._cyl(0.035, 0.04, 0.09, Vector3(0, 0.05, -0.022), "crystal", Vector3.ZERO, Vector3(1.0, 1, 0.6), 8),
		ZombieBody._box(Vector3(0.012, 0.09, 0.006), Vector3(0.03, 0.12, -0.09), "crystal", Vector3(0, 0, 0.4)),
		ZombieBody._box(Vector3(0.01, 0.07, 0.006), Vector3(-0.03, 0.13, -0.09), "crystal", Vector3(0, 0, -0.5))])
	neck.add_child(throat_mesh)
	_throat = OmniLight3D.new()
	_throat.light_color = Color(0.7, 0.35, 1.0)
	_throat.omni_range = 3.5
	_throat.light_energy = 0.6
	_throat.position = Vector3(0, 0.05, -0.12)
	neck.add_child(_throat)


# ---------------------------------------------------------------- co-op puppet (M7)

func net_sub_state() -> int:
	return int(sstate)


func puppet_activate(_enemy: StringName, _tier_v: StringName, _variant: String, hp_max: float, pos: Vector3, yaw: float,
		_st: int, sub: int, local_p: Player) -> void:
	target = local_p
	spawn_screamer(pos, hp_max)
	collision_mask = 0
	rotation.y = yaw
	interp.snap(float(Time.get_ticks_msec()), pos, yaw)
	if (sub as S) != S.EMERGE:
		sstate = sub as S
		_pivot.position.y = 0.0
	GLBus.enemy_spawned.emit(enemy_id, get_instance_id())


func _puppet_enter(_st: int, sub: int) -> void:
	if (sub as S) != sstate:
		_set_s(sub as S)


func _puppet_visual_tick(delta: float) -> void:
	_st += delta
	if sstate == S.EMERGE:
		_pivot.position.y = lerpf(-1.7, 0.0, clampf(_st / 1.4, 0.0, 1.0))
	elif _pivot.position.y < 0.0:
		_pivot.position.y = 0.0
	if sstate == S.WINDUP:
		_throat.light_energy = lerpf(0.4, 5.0, clampf(_st / float(_sc["windup"]), 0.0, 1.0))


func puppet_die(limb: StringName, kind: StringName, death_kind: int, side: float, pop: bool, pos: Vector3) -> void:
	if state == State.DEAD or state == State.INACTIVE:
		return
	_throat.light_energy = 0.0
	_shards(Color(0.65, 0.3, 1.0), 20, 3.0)
	var p: AudioStreamPlayer3D = AudioDirector.play_3d("zombie_death", global_position + Vector3.UP * 1.5, 4.0, 0.0)
	if p != null:
		p.pitch_scale = 1.7
	super.puppet_die(limb, kind, death_kind, side, pop, pos)


func puppet_fx(what: StringName, _args: Array) -> void:
	if what == &"scream":
		var sp: AudioStreamPlayer3D = AudioDirector.play_3d("screamer_scream", global_position + Vector3.UP * 1.6, 4.0, 0.0)
		if sp != null:
			sp.max_distance = maxf(sp.max_distance, 50.0)
