class_name Foreman
extends Zombie
## The Foreman (Obersteiger Gustav Mahlknecht), Map 1 boss (docs/ENEMIES.md §2.4).
## Subclasses Zombie only so weapons, explosions and melee treat him like any enemy (take_damage,
## hitbox_rids, is_active); his body, AI and death are his own. Not pooled: the director creates him.
##
## AI: EMERGE -> STALK -> (jab | slam | whip | charge | vent) -> RECOVER -> STALK, plus STUNNED and ENRAGED.
##
## T-232 (docs/BOSS_REWORK.md 4.1, the boss rework). Model: the legacy body rebuilt with richer surfaces (HomageBoss.mat_ex:
## rust-rough iron with oil streaks on the pauldron, the helmet and the drill housing; the drill core pulsing violet
## with Nachtglas veins in the housing that pulse with it; the ore chain a real run of alternating links dragging behind
## him that sparks on the stone; the Obersteiger cap welded into the helmet with weld beads along the seam and a brass
## badge; the greatcoat's hem hanging in strips that sway (BossFx.SwayStrips); a headlamp that is a real spot light).
## Effects: the kit (`fx`, BossFx.make with enemies.json "dread": iron hits, boss_stomp footfalls with a view shake),
## foreman_drill_spin looping while the drill is up (jab, slam, charge, vent), foreman_chain_whip on the whip, dust under
## his feet, the rock-burst arrival with a dust burst and a light drop round the spawn, fx.tele on every telegraph,
## hits through fx.hit (the core: a violet weak-point flash), death_burst. Battle: ENRAGED (under 30%) puts the gallery
## lamps out round him and keeps them out as he walks (the dark follows him: he is the light, his core and headlamp
## burn brighter); one new ENRAGED move, Core Vent (he plants the drill, the core flares 1.0 s with the core taking x4,
## then a Nachtglas burst: damage + slow + a dread punch within 6 m); the squad rules (a hurt player becomes his target
## and he shouts the shift cadence at them; a lone player gets the chain whip from any side, not only from behind).

enum F { EMERGE, STALK, JAB, SLAM, WHIP, CHARGE_WINDUP, CHARGE, RECOVER, STUNNED, VENT }

const VIOLET: Color = Color(0.68, 0.32, 1.0)
const IRON: Color = Color(0.3, 0.3, 0.31)
const RUST: Color = Color(0.4, 0.18, 0.09)
const OIL: Color = Color(0.07, 0.07, 0.08)
const BRASS: Color = Color(0.62, 0.5, 0.26)
const COAT: Color = Color(0.13, 0.1, 0.08)

var fstate: F = F.EMERGE
var enraged: bool = false
var fx: BossFx = null                  # T-232: the shared effects kit
var vents_done: int = 0
var arrival_bursts: int = 0
var squad_state: Dictionary = {"alone": false, "hurt": null, "downed": 0}
var _fc: Dictionary = {}
var _ft: float = 0.0
var _cd: Dictionary = {"jab": 0.0, "slam": 2.0, "whip": 0.0, "charge": 4.0, "vent": 3.0}
var _charge_dir: Vector3 = Vector3.FORWARD
var _charge_from: Vector3 = Vector3.ZERO
var _hit_done: bool = false
var _weak_log: Array = []     # [time, amount] of recent weak-point damage
var _clock: float = 0.0
var _step_t: float = 0.0
var _step_left: bool = false
var _chain_t: float = 0.0
var _drill: Node3D
var _core_mat: StandardMaterial3D
var _vein_mat: StandardMaterial3D
var _core_light: OmniLight3D
var _headlamp: SpotLight3D
var _tele_light: OmniLight3D           # the kit's tele() drives it (BossFx reads boss._tele_light)
var _arm_r: Node3D
var _chain: Array[Node3D] = []
var _chain_sparks: GPUParticles3D = null
var _foot_dust: GPUParticles3D = null
var _strips: BossFx.SwayStrips = null
var _drill_loop: AudioStreamPlayer3D   # child of the drill: freed with him, played while the drill jabs
var _spin_loop: AudioStreamPlayer3D    # T-232: foreman_drill_spin while the drill is up
var _tell_t: float = 0.0
var _dim_center: Vector3 = Vector3.INF
var _dim_back_t: float = -1.0          # > 0: the arrival's light drop comes back when it runs out
var _redim_t: float = -1.0             # > 0: ENRAGED: the lamps are re-captured round him when it runs out
var _core_flash: float = 0.0
var _squad_t: float = 0.0
var _cadence_t: float = -99.0


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
	_spin_loop = AudioDirector.make_loop_3d("foreman_drill_spin", _drill, -4.0)
	fx = BossFx.make(self, _fc.get("dread", {}), &"foreman")
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


## Bursts out of the ground at `at` with `health`. A 4 s audio tell comes first (the wall cracking).
func spawn_boss(at: Vector3, health: float) -> void:
	if not name.begins_with("Foreman"):
		name = "Foreman"   # T-232: findable by the capture cameras (CaptureDo "callv:Foreman:debug_enrage")
	net_died = false
	max_hp = health
	hp = health
	global_position = at
	state = State.CHASE
	fstate = F.EMERGE
	_ft = 0.0
	_tell_t = 0.0
	enraged = false
	_dim_center = Vector3.INF
	_dim_back_t = -1.0
	_redim_t = -1.0
	_pivot.position.y = -3.4
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_sound("board_break", 6.0, 0.35)   # the wall cracking (GLBus.boss_spawned plays the roar)
	if _core_light != null:
		_core_light.light_energy = 1.4
		_core_light.omni_range = 4.0
	if _headlamp != null:
		_headlamp.light_energy = 1.1


## BossFx reads this for the dread meter (the kit's line of sight).
func has_los(p: Node3D) -> bool:
	return _has_los(p)


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
	_tick_lights(delta)
	target = _nearest_player()
	_tick_squad(delta)
	match fstate:
		F.EMERGE:
			_halt(delta)
			var tell: float = float(_fc.get("spawn_delay", 4.0))
			if _ft <= tell:
				# the wall cracks: chips and dust fall round the spot every so often
				_tell_t -= delta
				if _tell_t <= 0.0:
					_tell_t = float((_fc.get("arrival", {}) as Dictionary).get("dust_every", 0.7))
					BossFx.burst("dust", global_position + Vector3.UP * 0.3, get_tree(), 1.0, 1.4)
					BossFx.burst("chips", global_position + Vector3.UP * 1.2, get_tree(), 0.6, 1.0)
					_sound("board_break", -4.0, 0.3 + randf() * 0.1)
			else:
				var t: float = clampf((_ft - tell) / 1.6, 0.0, 1.0)
				_pivot.position.y = lerpf(-3.4, 0.0, t)
				if t >= 1.0:
					_rock_burst()
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
		F.VENT:
			_update_vent(delta)
	_update_audio(delta)


## T-232: the rock burst: he is up. A dust and chip burst, the ground shakes, the light round the spawn drops for a
## moment (the lamps gutter) and comes back.
func _rock_burst() -> void:
	var ar: Dictionary = _fc.get("arrival", {})
	_sound("grenade_explode", 2.0, 0.5)
	_sound("foreman_roar", 4.0)
	_sound("boss_stomp", 6.0, 0.6)
	GLBus.explosion.emit(global_position, 4.0)
	BossFx.burst("dust", global_position + Vector3.UP * 0.2, get_tree(), 4.0, 2.6)
	BossFx.burst("chips", global_position + Vector3.UP * 1.0, get_tree(), 3.0, 1.6)
	BossFx.burst("motes", global_position + Vector3.UP * 1.5, get_tree(), 1.5, 1.4)
	arrival_bursts += 1
	if fx != null:
		fx.shake_all(global_position, 0.9, 22.0)
		fx.lights_dim(global_position, float(ar.get("light_radius", 14.0)), float(ar.get("light_drop", 0.2)), 0.3)
		fx.lights_flicker(2.2, 0.85)
		_dim_back_t = float(ar.get("light_back_s", 2.5))


## T-232: the lights. The arrival's drop comes back after its moment; ENRAGED, the lamps round him stay out and the
## dark moves with him (re-captured when he has walked `follow_m` from where they went out).
func _tick_lights(delta: float) -> void:
	if fx == null:
		return
	if _dim_back_t > 0.0:
		_dim_back_t -= delta
		if _dim_back_t <= 0.0 and not enraged:
			fx.lights_restore(2.5)
	if not enraged:
		return
	var el: Dictionary = _fc.get("enrage_lights", {})
	if _redim_t > 0.0:
		_redim_t -= delta
		if _redim_t <= 0.0:
			_lights_out(float(el.get("radius", 26.0)), float(el.get("level", 0.08)), 1.5)
	elif _dim_center.is_finite() and global_position.distance_to(_dim_center) > float(el.get("follow_m", 16.0)):
		fx.lights_restore(1.2)
		_redim_t = 1.4


func _lights_out(radius: float, level: float, seconds: float) -> void:
	fx.lights_dim(global_position, radius, level, seconds)
	fx.lights_flicker(3.0, 0.9)
	_dim_center = global_position


## T-232: the squad read every third of a second: the hurt player (under the fraction, within range, in sight) is his
## target while he stalks and hears the shift cadence; a lone player gets the whip from any side (see _update_stalk).
func _tick_squad(delta: float) -> void:
	_squad_t -= delta
	var sq: Dictionary = _fc.get("squad", {})
	if _squad_t <= 0.0:
		_squad_t = 0.3
		var alive: Array[Player] = []
		var downed: int = 0
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p == null or p.spectating:
				continue
			if p.downed:
				downed += 1
			elif p.is_alive():
				alive.append(p)
		var hurt: Player = null
		var hk: float = float(sq.get("hurt_fraction", 0.35))
		for p: Player in alive:
			if p.max_hp > 0.0 and p.hp / p.max_hp < hk and p.global_position.distance_to(global_position) <= float(sq.get("hurt_range", 25.0)) and _has_los(p):
				if hurt == null or p.hp / p.max_hp < hurt.hp / hurt.max_hp:
					hurt = p
		squad_state = {"alone": alive.size() == 1, "hurt": hurt, "downed": downed}
	var h: Player = squad_state.get("hurt") as Player
	if h != null and is_instance_valid(h) and h.is_alive():
		if fstate == F.STALK:
			target = h
			if _clock - _cadence_t >= float(sq.get("hurt_shout_every", 12.0)):
				_cadence_t = _clock
				_sound("foreman_roar", 0.0)   # "Schicht! Weiter!" at the one who is slowing down
		if fx != null and h.is_local and not h.is_bot:
			fx.extra_dread = maxf(fx.extra_dread, float(sq.get("hurt_dread", 0.25)))
	else:
		squad_state["hurt"] = null


func _go(f: F) -> void:
	fstate = f
	_ft = 0.0
	_hit_done = false
	match f:
		F.JAB:
			_sound("gun_smg", -2.0, 0.6)
			if fx != null:
				fx.tele(VIOLET, 2.0, float(_fc["jab"]["windup"]), false)
		F.SLAM:
			_sound("zombie_attack", 4.0, 0.55)
			_sound("boss_breath", 0.0, 0.6)
			if fx != null:
				fx.tele(VIOLET, 3.0, float(_fc["slam"]["windup"]))
		F.WHIP:
			_sound("foreman_chain", 2.0)   # the chain rattles behind him: the tell
			if fx != null:
				fx.tele(VIOLET, 2.0, 0.4, false)
		F.CHARGE_WINDUP:
			_sound("zombie_attack", 8.0, 0.45)
			_sound("foreman_roar", 2.0)
			_sound("boss_stomp", 2.0, 0.7)   # he plants his feet
			_sound("foreman_chain", 0.0)     # and scrapes the chain
			if fx != null:
				fx.tele(Color(1.0, 0.4, 0.5), 3.5, float(_fc["charge"]["windup"]))
		F.STUNNED:
			_sound("boss_stomp", 6.0, 0.5)
			_sound("boss_bone_crack", 0.0, 0.7)
			BossFx.burst("sparks", global_position + Vector3.UP * 1.6 - global_basis.z * 0.8, get_tree(), 2.0, 1.4)
			BossFx.burst("chips", global_position + Vector3.UP * 1.6 - global_basis.z * 0.8, get_tree(), 1.5, 1.2)
		F.VENT:
			_sound("foreman_roar", 4.0)
			_sound("boss_telegraph_rise", 2.0)
			if fx != null:
				fx.tele(VIOLET, 5.0, float((_fc.get("vent", {}) as Dictionary).get("windup", 1.0)), false)
			if _spin_loop != null:
				_spin_loop.pitch_scale = 1.35


func _update_stalk(delta: float) -> void:
	if target == null:
		_halt(delta)
		return
	var to_t: Vector3 = target.global_position - global_position
	var flat: Vector3 = Vector3(to_t.x, 0, to_t.z)
	var d: float = flat.length()
	var behind: bool = flat.length() > 0.1 and (-global_basis.z).dot(flat.normalized()) < -0.2
	# T-232: a lone player is whipped from any side (nobody else to circle him for)
	var whip_ok: bool = behind or (bool(squad_state.get("alone", false)) and bool((_fc.get("squad", {}) as Dictionary).get("alone_whip_any_side", true)))
	var vent: Dictionary = _fc.get("vent", {})
	if d <= float(_fc["jab"]["reach"]) and float(_cd["jab"]) <= 0.0:
		_go(F.JAB)
	elif enraged and not vent.is_empty() and d <= float(vent.get("radius", 6.0)) * 1.1 and d > float(_fc["jab"]["reach"]) and float(_cd["vent"]) <= 0.0:
		_go(F.VENT)
	elif d <= float(_fc["slam"]["radius"]) * 0.9 and float(_cd["slam"]) <= 0.0:
		_go(F.SLAM)
	elif whip_ok and d >= float(_fc["whip"]["min"]) and d <= float(_fc["whip"]["max"]) and float(_cd["whip"]) <= 0.0:
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
			BossFx.burst("sparks", target.global_position + Vector3.UP * 1.2, get_tree(), 1.2, 1.0)
			_sound("boss_hit_iron", 0.0, 0.8)
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
		_sound("boss_stomp", 8.0, 0.55)
		BossFx.burst("dust", at, get_tree(), 4.0, 2.6)
		BossFx.burst("chips", at + Vector3.UP * 0.3, get_tree(), 2.0, 1.5)
		if fx != null:
			fx.shake_all(at, 0.9, 20.0)
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
		_sound("foreman_chain_whip", 2.0)
		if target != null and target.global_position.distance_to(global_position) <= float(wd["max"]) + 0.5:
			target.take_hit(float(wd["damage"]), self)
			target.apply_status(&"whip_slow", float(wd["slow_seconds"]))
			BossFx.burst("sparks", target.global_position + Vector3.UP * 0.9, get_tree(), 1.5, 1.2)
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
			_sound("boss_hit_iron", 2.0, 0.7)
	var travelled: float = global_position.distance_to(_charge_from)
	var stalled: bool = before.distance_to(global_position) < float(_fc["charge_speed"]) * delta * 0.3
	if is_on_wall() and stalled and travelled > 1.0:
		_cd["charge"] = float(c["cooldown"]) * _cd_mult()
		GLBus.explosion.emit(global_position, 3.0)
		if fx != null:
			fx.shake_all(global_position, 0.7, 14.0)
		_go(F.STUNNED)
	elif travelled >= float(c["max_distance"]) or _ft > 3.0 or _hit_done:
		_cd["charge"] = float(c["cooldown"]) * _cd_mult()
		_go(F.RECOVER)


## T-232: Core Vent (ENRAGED). He plants the drill in the ground; the core flares for `windup` s (the core takes
## core_mult the whole time: the window), then the Nachtglas bursts out of it: damage, whip_slow and a dread punch on
## every player within `radius`; the counter is to back off 6 m or to shoot the core while it flares.
func _update_vent(delta: float) -> void:
	_halt(delta)
	var v: Dictionary = _fc.get("vent", {})
	var w: float = float(v.get("windup", 1.0))
	var k: float = clampf(_ft / w, 0.0, 1.0)
	_arm_r.rotation.x = lerpf(0.5, -0.9, k)   # the drill goes down into the stone
	_drill.rotation.z += delta * 50.0
	_core_flash = maxf(_core_flash, k)
	if not _hit_done and _ft >= w:
		_hit_done = true
		vents_done += 1
		_cd["vent"] = float(v.get("cooldown", 14.0)) * _cd_mult()
		var at: Vector3 = _drill.global_position
		_sound("boss_hit_glass", 4.0, 0.5)
		_sound("boss_weakpoint_hit", 2.0, 0.6)
		_sound("foreman_roar", 2.0)
		BossFx.burst("motes", at, get_tree(), 5.0, 2.6)
		BossFx.burst("sparks", at, get_tree(), 2.5, 1.6)
		BossFx.burst("dust", at, get_tree(), 2.0, 1.8)
		if fx != null:
			fx.shake_all(at, 0.7, 14.0)
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p == null or not p.is_alive():
				continue
			if p.global_position.distance_to(at) <= float(v.get("radius", 6.0)):
				p.take_hit(float(v.get("damage", 35)), self)
				p.apply_status(&"whip_slow", float(v.get("slow_seconds", 1.5)))
				var d: DreadFx = DreadFx.of(p)
				if d != null:
					d.punch(1.0)
		if _spin_loop != null:
			_spin_loop.pitch_scale = 1.0
	if _ft >= w + 0.6:
		_go(F.RECOVER)


## Dev / smoke: the Core Vent now (ENRAGED or not; the cooldown is ignored).
func debug_vent() -> void:
	_cd["vent"] = 0.0
	if target != null:
		_face(target.global_position)
	_go(F.VENT)


## Dev / capture: ENRAGED now (his health to 25%).
func debug_enrage() -> void:
	if is_active() and not enraged:
		take_damage(maxf(0.0, hp - max_hp * 0.25), &"torso", &"debug", 0, &"world")


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
			if fstate == F.STUNNED:
				mult = float(_fc["stunned_weakpoint_mult"])
			elif fstate == F.VENT:
				mult = float((_fc.get("vent", {}) as Dictionary).get("core_mult", 4.0))   # T-232: the core exposed as it flares
			else:
				mult = float(_fc["weakpoint_mult"])
			_core_flash = 1.0
		&"helmet", &"head":
			mult = float(_fc["helmet_mult"])
	amount *= mult
	hp -= amount
	GLBus.enemy_damaged.emit(enemy_id, limb, amount, by_player)
	if fx != null:
		fx.hit(limb, amount, mult if limb == &"weakpoint" else 1.0, max_hp)   # T-232: iron sparks; the core flashes violet
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
		_enrage()
	return false


## T-232: ENRAGED (under 30%): faster, shorter cooldowns (as before), and the gallery lamps round him go out and stay
## out as he walks; his core and headlamp burn brighter: he is the light.
func _enrage() -> void:
	enraged = true
	_core_mat.emission_energy_multiplier = 13.0
	if _core_light != null:
		_core_light.light_energy = 3.8
		_core_light.omni_range = 9.0
	if _headlamp != null:
		_headlamp.light_energy = 2.4
	_sound("foreman_roar", 8.0)
	_sound("boss_roar_low", 4.0, 0.75)
	BossFx.burst("motes", global_position + Vector3.UP * 2.0, get_tree(), 2.0, 2.0)
	BossFx.burst("sparks", global_position + Vector3.UP * 2.2, get_tree(), 1.5, 1.5)
	if fx != null:
		var el: Dictionary = _fc.get("enrage_lights", {})
		_dim_back_t = -1.0
		_lights_out(float(el.get("radius", 26.0)), float(el.get("level", 0.08)), 2.0)
		fx.shake_all(global_position, 0.6, 18.0)
	print("[foreman] ENRAGED: the lamps go out round him (%d), the core burns" % (fx.dimmed_count() if fx != null else 0))


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
	_stop_loops()
	if fx != null:
		fx.death_burst(global_position, VIOLET)
		fx.lights_restore(3.0)
	if _chain_sparks != null:
		_chain_sparks.emitting = false
	if _foot_dust != null:
		_foot_dust.emitting = false
	var reported: StringName = &"head" if limb == &"helmet" else limb
	GLBus.enemy_killed.emit(enemy_id, reported, weapon_id, by_player)
	GLBus.enemy_killed_at.emit(enemy_id, global_position, by_player)
	RoundManager.on_zombie_died()
	if Net.replicating():
		Net.session.zombie_died(self, limb, _kind, 0, 1.0, false)


func _stop_loops() -> void:
	if _drill_loop != null:
		_drill_loop.stop()
	if _spin_loop != null:
		_spin_loop.stop()


func _update_dead(delta: float) -> void:
	_state_t += delta
	_pivot.rotation.x = lerpf(_pivot.rotation.x, -1.4, clampf(delta * 2.0, 0.0, 1.0))
	_core_mat.emission_energy_multiplier = lerpf(_core_mat.emission_energy_multiplier, 0.4, clampf(delta * 1.5, 0.0, 1.0))
	if _core_light != null:
		_core_light.light_energy = lerpf(_core_light.light_energy, 0.0, clampf(delta * 1.5, 0.0, 1.0))
	if _headlamp != null:
		_headlamp.light_energy = lerpf(_headlamp.light_energy, 0.0, clampf(delta * 2.0, 0.0, 1.0))
	if _state_t > 2.5:
		_pivot.position.y -= delta * 1.2
	if _state_t > 4.0:
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		state = State.INACTIVE
		if fx != null:
			fx.release_dread()
		if director != null:
			director.call("on_zombie_returned", self)


# ---------------------------------------------------------------- presentation

## True while the drill is up and spinning (the foreman_drill_spin loop, the faster bit).
func _drill_up() -> bool:
	return fstate == F.JAB or fstate == F.SLAM or fstate == F.CHARGE_WINDUP or fstate == F.CHARGE or fstate == F.VENT


func _process(delta: float) -> void:
	if state == State.INACTIVE:
		return
	_drill.rotation.z += delta * (26.0 if _drill_up() and fstate != F.JAB and fstate != F.VENT else (4.0 if not _drill_up() else 0.0))
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.3
	if moving:
		_phase += delta * (3.0 if fstate != F.CHARGE else 9.0)
	(_parts["hip_l"] as Node3D).rotation.x = sin(_phase) * 0.35 if moving else 0.0
	(_parts["hip_r"] as Node3D).rotation.x = -sin(_phase) * 0.35 if moving else 0.0
	(_parts["shin_l"] as Node3D).rotation.x = (-maxf(0.0, cos(_phase)) * 0.6 - 0.1) if moving else -0.1
	(_parts["shin_r"] as Node3D).rotation.x = (-maxf(0.0, -cos(_phase)) * 0.6 - 0.1) if moving else -0.1
	if fstate != F.SLAM and fstate != F.VENT:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 1.2 if fstate == F.JAB or fstate == F.CHARGE else 0.5, 0.2)
	_core_flash = maxf(0.0, _core_flash - delta * 2.5)
	var core_e: float
	if fstate == F.STUNNED:
		_pivot.rotation.x = lerpf(_pivot.rotation.x, -0.35, 0.1)
		core_e = 6.0 + sin(_clock * 18.0) * 4.0
	elif state != State.DEAD:
		_pivot.rotation.x = lerpf(_pivot.rotation.x, -0.12 if fstate == F.CHARGE else 0.0, 0.1)
		core_e = (13.0 + sin(_clock * 6.0) * 3.0) if enraged else (4.0 + sin(_clock * 4.0))
		if fstate == F.VENT:
			core_e = lerpf(core_e, 24.0, _core_flash)
	else:
		core_e = _core_mat.emission_energy_multiplier
	if state != State.DEAD:
		_core_mat.emission_energy_multiplier = core_e + 6.0 * _core_flash
		if _vein_mat != null:
			_vein_mat.emission_energy_multiplier = 0.6 + core_e * 0.12 + 2.0 * _core_flash
		if _core_light != null:
			var base: float = 3.8 if enraged else 1.4
			_core_light.light_energy = base * (0.8 + 0.2 * sin(_clock * (6.0 if enraged else 4.0))) + 2.5 * _core_flash
	# the chain drags behind, link by link, and sparks on the stone while he walks
	for i: int in _chain.size():
		_chain[i].position = Vector3(-0.9 - sin(_phase + float(i) * 0.9) * 0.06, 0.1, 0.35 + float(i) * 0.17)
		_chain[i].rotation = Vector3(PI * 0.5, sin(_phase * 0.5 + float(i)) * 0.15, PI * 0.5 * float(i % 2))
	if _chain_sparks != null:
		_chain_sparks.emitting = moving and state != State.DEAD
	if _foot_dust != null:
		_foot_dust.emitting = moving and state != State.DEAD


func _update_audio(delta: float) -> void:
	if not is_active():
		return
	_step_t -= delta
	_chain_t -= delta
	if Vector2(velocity.x, velocity.z).length() > 0.3 and _step_t <= 0.0:
		_step_t = 0.7 if fstate != F.CHARGE else 0.25
		_step_left = not _step_left
		_sound("foreman_step", 0.0)   # the pneumatic hiss and clank
		if fx != null:
			fx.stomp(_foot_pos(_step_left))   # T-232: the weight: dust, boss_stomp, the view shake
	if _chain_t <= 0.0:
		_chain_t = 1.2
		_sound("foreman_chain", 0.0)
		if randf() < 0.15:
			_sound("foreman_roar", -2.0)   # "Schicht! Weiter!"
	# The drill screams only while it jabs (toggled on change, never restarted per frame); the spin loop runs while
	# the drill is up (T-232).
	if _drill_loop != null:
		var want: bool = fstate == F.JAB and state != State.DEAD
		if want != _drill_loop.playing:
			if want:
				_drill_loop.play()
			else:
				_drill_loop.stop()
	if _spin_loop != null:
		var want_spin: bool = _drill_up() and state != State.DEAD
		if want_spin != _spin_loop.playing:
			if want_spin:
				_spin_loop.play()
			else:
				_spin_loop.stop()
				_spin_loop.pitch_scale = 1.0


## The foot on the ground (the shin's end), for the kit's footfall.
func _foot_pos(left: bool) -> Vector3:
	var shin: Node3D = _parts.get("shin_l" if left else "shin_r") as Node3D
	if shin == null:
		return global_position
	return shin.global_position + Vector3.DOWN * 0.65


## pitch 1.0 keeps the bank's own pitch range; the remaining generic sounds (blasts, cracking) are pitched down.
func _sound(n: String, db: float, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer3D = AudioDirector.play_3d(n, global_position + Vector3.UP * 2.0, db, 0.05)
	if p != null:
		if pitch != 1.0:
			p.pitch_scale = pitch
		p.max_distance = maxf(p.max_distance, 60.0)


## One body piece in one material (T-232): `parts` are ZombieBody._cyl / _sph / _box results; their material key is
## ignored for `m` (rust, oil, brass, the core's glass).
func _shape(parent: Node3D, parts: Array, m: Material) -> MeshInstance3D:
	var mesh: ArrayMesh = ArrayMesh.new()
	var st: SurfaceTool = SurfaceTool.new()
	for p: Array in parts:
		st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
	st.commit(mesh)
	mesh.surface_set_material(0, m)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


func _build_foreman() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_mats["coat"] = ZombieBody.material("miner", "cloth")
	_mats["skin"] = ZombieBody.material("_", "skin_base")
	_mats["metal"] = ZombieBody.material("_", "metal")
	# T-232: the surfaces: the core's glass (his own instance: it pulses), the veins, rust, oil, brass, weld
	_core_mat = HomageBoss.mat_ex(Color(0.5, 0.22, 0.9), 0.1, 0.3, 4.0, VIOLET).duplicate() as StandardMaterial3D
	_vein_mat = HomageBoss.mat_ex(Color(0.42, 0.18, 0.78), 0.15, 0.3, 1.2, VIOLET).duplicate() as StandardMaterial3D
	var m_rust: StandardMaterial3D = HomageBoss.mat_ex(RUST, 0.95, 0.15)
	var m_oil: StandardMaterial3D = HomageBoss.mat_ex(OIL, 0.12, 0.55)
	var m_brass: StandardMaterial3D = HomageBoss.mat_ex(BRASS, 0.35, 0.9)
	var m_weld: StandardMaterial3D = HomageBoss.mat_ex(Color(0.22, 0.21, 0.2), 0.85, 0.5)
	var m_iron: StandardMaterial3D = HomageBoss.mat_ex(IRON, 0.5, 0.75)
	var m_coat: StandardMaterial3D = HomageBoss.mat_ex(COAT, 0.92, 0.0)
	var V: String = "miner"   # material set: brown work clothes, leather, steel
	# legs: thigh + bending shin, heavy boots and knee guards
	for side: float in [-1.0, 1.0]:
		var hip: Node3D = Node3D.new()
		hip.position = Vector3(0.32 * side, 1.35, 0)
		_pivot.add_child(hip)
		_hitbox(hip, Vector3(0.42, 1.35, 0.48), Vector3(0, -0.67, 0), &"legs")
		_mesh(hip, [ZombieBody._cyl(0.2, 0.165, 0.72, Vector3(0, -0.34, 0), "cloth2", Vector3.ZERO, Vector3(1, 1, 1.05), 10),
			ZombieBody._sph(0.13, Vector3(0, -0.68, -0.07), "metal", Vector3(1.0, 1.0, 0.6))], V)
		_shape(hip, [ZombieBody._sph(0.06, Vector3(0.04 * side, -0.62, -0.14), "_", Vector3(1.0, 0.6, 0.4))], m_rust)   # rust on the knee guard
		var shin: Node3D = Node3D.new()
		shin.position = Vector3(0, -0.7, 0)
		hip.add_child(shin)
		_mesh(shin, [ZombieBody._cyl(0.16, 0.14, 0.5, Vector3(0, -0.25, 0), "leather", Vector3.ZERO, Vector3.ONE, 10),
			ZombieBody._box(Vector3(0.3, 0.16, 0.48), Vector3(0, -0.58, -0.1), "leather"),
			ZombieBody._box(Vector3(0.32, 0.04, 0.5), Vector3(0, -0.66, -0.1), "metal")], V)
		_shape(shin, [ZombieBody._box(Vector3(0.33, 0.02, 0.1), Vector3(0, -0.665, -0.3), "_")], m_rust)   # the boot's rusted toe cap
		_parts["hip_l" if side < 0.0 else "hip_r"] = hip
		_parts["shin_l" if side < 0.0 else "shin_r"] = shin
	# pelvis + work apron (oil-black where the drill hangs)
	_mesh(_pivot, [ZombieBody._cyl(0.42, 0.4, 0.34, Vector3(0, 1.38, 0), "cloth2", Vector3.ZERO, Vector3(1.25, 1, 0.85), 12),
		ZombieBody._box(Vector3(0.62, 0.9, 0.04), Vector3(0, 1.15, -0.37), "leather", Vector3(0.12, 0, 0))], V)
	_shape(_pivot, [ZombieBody._box(Vector3(0.18, 0.5, 0.012), Vector3(0.18, 1.1, -0.395), "_", Vector3(0.12, 0, 0.1)),
		ZombieBody._box(Vector3(0.08, 0.3, 0.012), Vector3(-0.1, 0.95, -0.4), "_", Vector3(0.12, 0, -0.08))], m_oil)
	# the greatcoat's hem: strips that sway with his walk (BossFx.SwayStrips)
	_strips = BossFx.SwayStrips.new()
	_strips.name = "CoatStrips"
	_strips.position = Vector3(0, 1.32, 0.12)
	_pivot.add_child(_strips)
	_strips.build(7, 0.55, 0.12, m_coat, 0.9, 7)
	# hunched barrel torso with a hump, straps and Nachtglas veins breaking through
	var torso: Node3D = _hitbox(_pivot, Vector3(1.35, 1.25, 0.85), Vector3(0, 2.0, 0), &"torso")
	var chest_mesh: Array = [
		ZombieBody._cyl(0.62, 0.46, 1.25, Vector3.ZERO, "cloth", Vector3(-0.18, 0, 0), Vector3(1.15, 1, 0.82), 14),
		ZombieBody._sph(0.5, Vector3(0, 0.38, 0.22), "cloth", Vector3(1.3, 0.8, 1.0)),
		ZombieBody._box(Vector3(0.08, 1.2, 0.04), Vector3(-0.28, 0.0, -0.4), "leather", Vector3(-0.15, 0, 0.12)),
		ZombieBody._box(Vector3(0.08, 1.2, 0.04), Vector3(0.28, 0.0, -0.4), "leather", Vector3(-0.15, 0, -0.12)),
		ZombieBody._box(Vector3(0.9, 0.1, 0.06), Vector3(0, -0.45, -0.38), "leather")]
	_mesh(torso, chest_mesh, V)
	var veins: Array = []
	for k: int in 7:
		var a: float = float(k) * 0.9
		veins.append(ZombieBody._box(Vector3(0.03, 0.35 + 0.05 * float(k % 3), 0.03), Vector3(sin(a) * 0.45, -0.1 + 0.08 * float(k), -cos(a) * 0.4 - 0.05), "_", Vector3(0.2, 0, a)))
	_shape(torso, veins, _vein_mat)
	# the straps' brass buckles, oil down the front of the coat
	_shape(torso, [ZombieBody._box(Vector3(0.1, 0.06, 0.02), Vector3(-0.28, -0.3, -0.43), "_"), ZombieBody._box(Vector3(0.1, 0.06, 0.02), Vector3(0.28, -0.3, -0.43), "_")], m_brass)
	_shape(torso, [ZombieBody._box(Vector3(0.14, 0.5, 0.012), Vector3(0.1, -0.2, -0.44), "_", Vector3(-0.1, 0, 0.05))], m_oil)
	# the telegraph light the kit drives (BossFx.tele reads _tele_light)
	_tele_light = OmniLight3D.new()
	_tele_light.light_color = VIOLET
	_tele_light.omni_range = 5.0
	_tele_light.light_energy = 0.0
	_tele_light.shadow_enabled = false
	_tele_light.position = Vector3(0, 0.2, -0.6)
	torso.add_child(_tele_light)
	# head: heavy jaw, sunken eyes, the Obersteiger helmet with a headlamp, the peaked cap welded into it
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
		ZombieBody._cyl(0.06, 0.06, 0.1, Vector3(0, 0.2, -0.3), "metal", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 8)], V)
	# the cap: crown and visor in coat cloth, the brass badge, weld beads where the steel took it
	_shape(head, [ZombieBody._cyl(0.2, 0.23, 0.07, Vector3(0, 0.33, 0.0), "_", Vector3.ZERO, Vector3(1.0, 1.0, 1.05), 12),
		ZombieBody._box(Vector3(0.3, 0.02, 0.16), Vector3(0, 0.3, -0.3), "_", Vector3(-0.15, 0, 0))], m_coat)
	_shape(head, [ZombieBody._cyl(0.035, 0.035, 0.012, Vector3(0, 0.34, -0.2), "_", Vector3(PI * 0.5 - 0.3, 0, 0), Vector3.ONE, 10)], m_brass)
	var welds: Array = []
	for w: int in 10:
		var wa: float = TAU * float(w) / 10.0
		welds.append(ZombieBody._sph(0.022, Vector3(sin(wa) * 0.22, 0.29 + 0.01 * float(w % 2), cos(wa) * 0.22 + 0.01), "_", Vector3(1.2, 0.7, 1.2)))
	_shape(head, welds, m_weld)
	_shape(head, [ZombieBody._sph(0.09, Vector3(0.18, 0.12, 0.12), "_", Vector3(1.0, 0.6, 1.0)), ZombieBody._box(Vector3(0.05, 0.14, 0.012), Vector3(-0.2, 0.0, -0.21), "_")], m_rust)   # rust on the helmet
	# the headlamp: the lens and a real light
	_headlamp = SpotLight3D.new()
	_headlamp.light_color = Color(1.0, 0.82, 0.55)
	_headlamp.light_energy = 1.1
	_headlamp.spot_range = 14.0
	_headlamp.spot_angle = 28.0
	_headlamp.shadow_enabled = false
	_headlamp.position = Vector3(0, 0.2, -0.36)
	_headlamp.rotation = Vector3(-0.15, 0, 0)
	head.add_child(_headlamp)
	_shape(head, [ZombieBody._cyl(0.05, 0.05, 0.02, Vector3(0, 0.2, -0.36), "lens", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 8)],
		HomageBoss.mat_ex(Color(0.95, 0.8, 0.5), 0.2, 0.0, 2.2, Color(1.0, 0.82, 0.55)))
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
	_shape(_arm_r, [ZombieBody._sph(0.12, Vector3(0.2, 0.12, -0.12), "_", Vector3(1.0, 0.5, 1.0)), ZombieBody._box(Vector3(0.03, 0.3, 0.012), Vector3(0.28, -0.1, -0.1), "_")], m_rust)   # rust on the pauldron
	_shape(_arm_r, [ZombieBody._box(Vector3(0.04, 0.4, 0.012), Vector3(0.1, -0.5, -0.15), "_", Vector3(0, 0, 0.08))], m_oil)   # oil down the piston
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
	# the housing's rust band, oil streaks and the Nachtglas veins that pulse with the core
	_shape(_drill, [ZombieBody._cyl(0.225, 0.225, 0.06, Vector3(0, 0, 0.0), "_", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12)], m_rust)
	_shape(_drill, [ZombieBody._box(Vector3(0.03, 0.012, 0.6), Vector3(0.12, 0.2, -0.3), "_"), ZombieBody._box(Vector3(0.02, 0.012, 0.4), Vector3(-0.15, 0.17, -0.4), "_")], m_oil)
	var dveins: Array = []
	for k3: int in 5:
		var a3: float = float(k3) * TAU / 5.0 + 0.4
		dveins.append(ZombieBody._box(Vector3(0.016, 0.016, 0.3 + 0.08 * float(k3 % 2)), Vector3(cos(a3) * 0.21, sin(a3) * 0.21, -0.1 - 0.05 * float(k3)), "_", Vector3(0, 0, a3)))
	_shape(_drill, dveins, _vein_mat)
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
	_core_light = OmniLight3D.new()
	_core_light.light_color = Color(0.65, 0.3, 1.0)
	_core_light.omni_range = 4.0
	_core_light.light_energy = 1.4
	_core_light.shadow_enabled = false
	core_holder.add_child(_core_light)
	# left arm: a fist wrapped in ore chain
	var arm_l: Node3D = Node3D.new()
	arm_l.position = Vector3(-0.88, 2.45, 0)
	_pivot.add_child(arm_l)
	_hitbox(arm_l, Vector3(0.36, 1.1, 0.36), Vector3(0, -0.5, 0), &"arms")
	var fist: Array = [
		ZombieBody._cyl(0.17, 0.14, 1.0, Vector3(0, -0.5, 0), "skin", Vector3.ZERO, Vector3.ONE, 10),
		ZombieBody._sph(0.26, Vector3(0, -1.15, -0.02), "skin", Vector3(1.0, 1.1, 0.95))]
	_mesh(arm_l, fist, V)
	var wraps: Array = []
	for k4: int in 5:
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = 0.2
		tor.outer_radius = 0.28
		tor.rings = 10
		tor.ring_segments = 6
		wraps.append([tor, Transform3D(Basis.from_euler(Vector3(0.3 * float(k4), 0, 0.5 * float(k4 % 2))), Vector3(0, -1.0 - 0.07 * float(k4), 0)), "_"])
	_shape(arm_l, wraps, m_iron)
	_shape(arm_l, [ZombieBody._sph(0.05, Vector3(0.2, -1.05, 0.1), "_", Vector3(1.0, 0.6, 1.0))], m_rust)
	# the dragging chain: a real run of links, alternating their turn, sparking on the stone (T-232)
	var link_mesh: TorusMesh = TorusMesh.new()
	link_mesh.inner_radius = 0.05
	link_mesh.outer_radius = 0.1
	link_mesh.rings = 8
	link_mesh.ring_segments = 6
	for i: int in 10:
		var link: MeshInstance3D = MeshInstance3D.new()
		link.mesh = link_mesh
		link.material_override = m_iron if i % 3 != 2 else m_rust
		link.rotation = Vector3(PI * 0.5, 0, PI * 0.5 * float(i % 2))
		add_child(link)
		_chain.append(link)
	_chain_sparks = BossFx.emitter("sparks", _chain[_chain.size() - 1], Vector3.ZERO, 0.6)
	_foot_dust = BossFx.emitter("dust", _pivot, Vector3(0, 0.05, 0), 0.9)


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
		if fstate == F.EMERGE and (sub as F) == F.STALK:
			_rock_burst()
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
		_enrage()
	_tick_lights(delta)
	if _spin_loop != null:
		var want_spin: bool = _drill_up() and state != State.DEAD
		if want_spin != _spin_loop.playing:
			if want_spin:
				_spin_loop.play()
			else:
				_spin_loop.stop()


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
	_stop_loops()
	if fx != null:
		fx.death_burst(global_position, VIOLET)
		fx.lights_restore(3.0)


func puppet_fx(what: StringName, args: Array) -> void:
	if what == &"slam" and args.size() >= 2:
		Effects.explosion((args[0] as Vector3) + Vector3.UP * 0.2, float(args[1]))
		_sound("grenade_explode", 4.0, 0.6)
		BossFx.burst("dust", args[0] as Vector3, get_tree(), 4.0, 2.6)
