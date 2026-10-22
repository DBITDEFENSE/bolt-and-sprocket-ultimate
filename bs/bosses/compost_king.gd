class_name CompostKing
extends PatternBoss
## THE COMPOST KING — Verdant Sink boss, the Coolant Lagoon under the leaking Mega-Harvester (BS_ENEMIES §4.6).
## 560 HP, 45 bolts. A mound of mossy rot with a junk crown, two eyes, two arms and a core in its chest mound
## (the weak point; it flares when he slams). Trophies: "Zero Waste" (no damage taken), "Collective Bargaining"
## (the mercy ending). The fight is a plumbing puzzle under pressure: three coolant LEAKS (CoolantValve nodes
## in the arena) spray onto the floor; every open leak heals him `leak.heal_frac` (1%) of max HP per second
## (2% enraged). Sealing a valve feeds BREAK +35% of the threshold and staggers him for 1.0 s.
##
## Phase 1 ROTTING (100-60%): SLAM (0.6 s telegraph: arm raised high, a wet rumble, a green ring at the impact
##   spot 3 m in front; 20 damage in r5 with knockback) and SPORE VOLLEY (0.5 s chest-puff; 3 globs in a fan,
##   12 damage each, r2 blast, landing rings for the whole flight). Leak 1 (W) is open.
## Phase 2 THRASHING (60-30%): leaks 2 and 3 burst open (a sealed one near him re-cracks with a 1.0 s hiss
##   telegraph). THRASH: a 360° arm sweep (0.7 s wind-up, 16 damage in r4.5, jumpable: feet above his base +
##   `thrash.jump_clear` are safe). MURK WAVE: a slow water ring across the pit (0.8 s, 10 damage + SLOWED).
## Phase 3 NEGOTIATION (at 30%): he stops, becomes invulnerable and pleads for `negotiation.plea` (8 s).
##   All 3 leaks sealed + the arena's handshake (accept_mercy): MERCY ENDING: he stands down, hands over the core
##     (boss_defeated without a death; 45 + 60 bolts; "Collective Bargaining").
##   Otherwise NEGOTIATION FAILED: enraged for the rest of the fight (timers x0.6, 5 m/s); with every leak
##     sealed he no longer heals, with any open leak he heals 2%/s (seal them, then finish him).
##
## ARENA CONTRACT (opts["arena"], the planet's VerdantArena; every anchor is optional):
##   Center, BossSpawn   Node3D        the pit centre / where he starts (else the arena node's origin)
##   Valve_*             CoolantValve  the leaks (open / set_open / sealed signal); found by name prefix
##   AddSpawn*           Marker3D      (unused: the King has no adds; the leaks are the pressure)
##   set_handshake(on)   method        the planet's mercy interact (the arena relays it to accept_mercy)
## Without an arena it builds its own: a floor and three valves 8 m out (W, E, N) so a standalone fight runs.

var enraged: bool = false
var negotiating: bool = false
var mercy: bool = false
var plea_t: float = 0.0
var pleas: int = 0
var healed: float = 0.0
var seals_fed: int = 0
var waves: int = 0
var _last: StringName = &""
var _cycle: int = 0
var _wave: Dictionary = {}          # {"r": float, "max": float, "hit": bool}
var _slam_at: Vector3 = Vector3.ZERO
var _crack_t: float = 0.0
var _crack_valve: CoolantValve = null
var _talk_bark_cd: float = 0.0
var _stand_down_t: float = -1.0
var _arm_l: Node3D
var _arm_r: Node3D
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _crown: Node3D
var _valve_signals_wired: bool = false


func _init() -> void:
	boss_id = &"compost_king"
	id = &"compost_king"


# ------------------------------------------------------------------ visual (the mound)

func _build_visual() -> void:
	var moss: StandardMaterial3D = EnemyFx.mat(Color("#4a6a2a"))
	flash_mats.append(moss)
	var rot: StandardMaterial3D = EnemyFx.mat(Color("#2f3a1e"))
	EnemyFx.sphere(visual, 2.0, Vector3(0, 1.3, 0), moss, 2.6)                     # the mound (squashed)
	EnemyFx.sphere(visual, 1.4, Vector3(0.6, 2.4, -0.3), rot, 1.6)
	EnemyFx.sphere(visual, 1.1, Vector3(-0.9, 2.2, 0.4), moss, 1.4)
	for i: int in 6:                                                              # junk in the rot
		var a: float = TAU * float(i) / 6.0
		EnemyFx.box(visual, Vector3(0.5, 0.3, 0.7), Vector3(cos(a) * 1.5, 0.5 + 0.2 * i, sin(a) * 1.5), EnemyFx.mat(Color("#5a6377"))).rotation.y = a
	_crown = Node3D.new()
	_crown.position = Vector3(0, 3.3, 0)
	visual.add_child(_crown)
	for i: int in 5:                                                              # the junk crown
		var a: float = TAU * float(i) / 5.0
		EnemyFx.box(_crown, Vector3(0.22, 0.7, 0.22), Vector3(cos(a) * 0.7, 0.35, sin(a) * 0.7), EnemyFx.mat(Color("#8a95a8")))
	EnemyFx.torus(_crown, 0.1, 0.75, Vector3.ZERO, EnemyFx.mat(Color("#ffd23e"))).rotation.x = PI / 2.0
	_eye_mat = EnemyFx.mat(Color("#9dff5a"), Color("#9dff5a"), 2.0)
	EnemyFx.sphere(visual, 0.22, Vector3(-0.55, 2.7, 1.5), _eye_mat)
	EnemyFx.sphere(visual, 0.22, Vector3(0.55, 2.7, 1.5), _eye_mat)
	_core_mat = EnemyFx.mat(Color("#39ff88"), Color("#39ff88"), 1.6)
	_core = EnemyFx.sphere(visual, 0.42, Vector3(0, 1.6, 1.75), _core_mat)         # the core in the chest mound
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-2.0, 2.2, 0.4)
	visual.add_child(_arm_l)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(2.0, 2.2, 0.4)
	visual.add_child(_arm_r)
	for arm: Node3D in [_arm_l, _arm_r]:
		EnemyFx.box(arm, Vector3(0.6, 0.6, 2.4), Vector3(0, -0.2, 1.1), moss)
		EnemyFx.sphere(arm, 0.55, Vector3(0, -0.3, 2.3), rot)


func _build_body() -> void:
	super._build_body()
	var cs: CylinderShape3D = CylinderShape3D.new()
	cs.radius = 2.0
	cs.height = 3.4
	_shape.shape = cs
	_shape.position.y = 1.7


func get_center() -> Vector3:
	return global_position + Vector3(0, 1.8, 0)


func core_pos() -> Vector3:
	return _core.global_position if _core != null else get_center()


func _build_default_arena() -> Node3D:
	var a: Node3D = Node3D.new()
	var rr: float = float(R.get("default_arena", {}).get("valve_ring", 8.0))
	PatternBoss.arena_marker(a, "Center", Vector3.ZERO)
	PatternBoss.arena_marker(a, "AddSpawn0", Vector3(-6, 0.3, 6))
	PatternBoss.arena_marker(a, "AddSpawn1", Vector3(6, 0.3, 6))
	var dirs: Dictionary = {"W": Vector3(-1, 0, 0), "E": Vector3(1, 0, 0), "N": Vector3(0, 0, -1)}
	for k: String in dirs.keys():
		var v: CoolantValve = CoolantValve.new()
		v.valve_id = k
		v.name = "Valve_" + k
		v.position = (dirs[k] as Vector3) * rr + Vector3(0, 0.5, 0)
		v.jet = v.position + (dirs[k] as Vector3) * -2.0 - Vector3(0, 0.5, 0)
		a.add_child(v)
	if _needs_floor():
		PatternBoss.arena_box(a, "Floor", Vector3(60, 1, 60), Vector3(0, -0.5, 0), Color("#1f2d22"))
	_attach_arena(a)
	return a


# ------------------------------------------------------------------ leaks

func valves() -> Array[CoolantValve]:
	var out: Array[CoolantValve] = []
	for n: Node3D in anchors("Valve_"):
		if n is CoolantValve:
			out.append(n as CoolantValve)
	return out


func open_leaks() -> int:
	var n: int = 0
	for v: CoolantValve in valves():
		if v.open:
			n += 1
	return n


func all_sealed() -> bool:
	var vs: Array[CoolantValve] = valves()
	return not vs.is_empty() and open_leaks() == 0


func _wire_valves() -> void:
	if _valve_signals_wired:
		return
	_valve_signals_wired = true
	for v: CoolantValve in valves():
		if not v.sealed.is_connected(_on_valve_sealed_direct):
			v.sealed.connect(_on_valve_sealed_direct)


func _on_valve_sealed_direct(v: CoolantValve) -> void:
	# the planet's director relays seals through on_leak_sealed; a self-built arena wires the valves directly
	if arena_owned or not has_meta(&"level_director"):
		on_leak_sealed(v.valve_id)


## A sealed leak: +35% of the BREAK threshold and a 1.0 s flinch (the pressure drop).
func on_leak_sealed(id: String) -> void:
	seals_fed += 1
	var L: Dictionary = R["leak"]
	var ln: Dictionary = R.get("lines", {})
	if ln.has("leak_sealed"):
		queue_line(str(ln["leak_sealed"]), 0.3)
	if not negotiating and not mercy and started and not defeated:
		self_stun(float(L.get("seal_stun", 1.0)), float(L.get("seal_break_frac", 0.35)), &"seal_flinch")
	telegraphed.emit(&"leak_sealed", &"valve_clank", 0.0)
	if negotiating and all_sealed():
		_offer_mercy()
	var _u: String = id


# ------------------------------------------------------------------ setup

func _pattern_activate() -> void:
	enraged = false
	negotiating = false
	mercy = false
	plea_t = 0.0
	pleas = 0
	healed = 0.0
	seals_fed = 0
	waves = 0
	_last = &""
	_cycle = 0
	_wave = {}
	_crack_t = 0.0
	_crack_valve = null
	_talk_bark_cd = 0.0
	_stand_down_t = -1.0
	_valve_signals_wired = false
	_wire_valves()
	# phase 1: only the first leak (W) is open
	var first: String = str(R["leak"].get("first_open", "W"))
	for v: CoolantValve in valves():
		v.set_open(v.valve_id == first)
	var ln: Dictionary = R.get("lines", {})
	if ln.has("leak_hint"):
		queue_line(str(ln["leak_hint"]), float(R["leak"].get("hint_delay", 5.0)))


func _ai(dt: float) -> void:
	if mercy:
		desired_vel = Vector3.ZERO
		if _stand_down_t > 0.0:
			_stand_down_t -= dt
			if _stand_down_t <= 0.0:
				despawn()
		return
	super._ai(dt)


func _accepts_hit(_hit: Combat.Hit) -> bool:
	return not mercy


# ------------------------------------------------------------------ fight

func move_speed() -> float:
	return float(R["enrage"].get("speed", 5.0)) if enraged else ph(R["move_speed"])


func timer_mult() -> float:
	return float(R["enrage"].get("timer_mult", 0.6)) if enraged else 1.0


func _fight_tick(dt: float) -> void:
	_talk_bark_cd -= dt
	# the leaks heal him (not while he pleads; enraged with every leak sealed he no longer heals)
	if not negotiating and not defeated:
		var n: int = open_leaks()
		if n > 0:
			var L: Dictionary = R["leak"]
			var frac: float = float(L.get("enraged_heal_frac", 0.02)) if enraged else float(L.get("heal_frac", 0.01))
			var h: float = max_hp * frac * n * dt
			var before: float = hp
			hp = minf(max_hp, hp + h)
			healed += hp - before
	# re-cracking a sealed valve he passes (phase 2+, a 1.0 s hiss telegraph)
	if phase >= 2 and not negotiating and _crack_valve == null:
		for v: CoolantValve in valves():
			if not v.open and v.global_position.distance_to(global_position) < float(R["leak"].get("crack_range", 5.0)) and randf() < dt * 0.5:
				_crack_valve = v
				_crack_t = float(R["leak"].get("crack_tele", 1.0))
				log_parallel(&"crack", _crack_t, &"pipe_hiss")
				EnemyFx.ring(get_parent(), v.jet, 1.6, _crack_t, Color("#39ff88"))
				break
	if _crack_valve != null:
		_crack_t -= dt
		if _crack_t <= 0.0:
			if is_instance_valid(_crack_valve) and not negotiating:
				_crack_valve.set_open(true)
			_crack_valve = null
	# the murk wave rolls on its own
	if not _wave.is_empty():
		_wave["r"] = float(_wave["r"]) + float(R["wave"]["speed"]) * dt
		var r: float = float(_wave["r"])
		if not bool(_wave["hit"]) and target_alive():
			var d: float = flat_dist_to_target()
			var feet: float = target_pos().y
			if absf(d - r) < float(R["wave"]["width"]) and feet < global_position.y + float(R["wave"].get("jump_clear", 1.0)) and not target_dodging():
				_wave["hit"] = true
				hurt_target(float(R["wave"]["dmg"]), 6.0)
				if target.is_in_group(&"player"):
					PlayerDebuffs.of(target).slow(&"murk_wave", 1.0 - float(R["wave"]["slow"]), float(R["wave"]["slow_time"]))
		if r > float(_wave["max"]):
			_wave = {}
	# the negotiation clock
	if negotiating:
		plea_t -= dt
		desired_vel = Vector3.ZERO
		if plea_t <= 0.0:
			_plea_over()


func _idle_tick(dt: float) -> void:
	if negotiating or target == null:
		desired_vel = Vector3.ZERO
		return
	var d: float = flat_dist_to_target()
	if d > float(R["hold_distance"]):
		steer_toward(target_pos(), move_speed())
	else:
		desired_vel = Vector3.ZERO
		face(target_pos() - global_position, dt, 2.5)


func _allowed(kind: StringName) -> bool:
	if negotiating or mercy:
		return false
	if kind == &"thrash" or kind == &"wave":
		return phase >= 2
	return true


func _pick() -> StringName:
	if negotiating or mercy:
		return &""
	var d: float = flat_dist_to_target()
	_cycle += 1
	if phase >= 2:
		match _cycle % 4:
			1: return &"slam" if d < float(R["slam"]["range"]) else &"volley"
			2: return &"wave"
			3: return &"volley"
			_: return &"thrash" if d < float(R["thrash"]["r"]) + 2.0 else &"slam"
	return &"slam" if d < float(R["slam"]["range"]) and _last != &"slam" else &"volley"


func _start(kind: StringName) -> void:
	_last = kind
	match kind:
		&"slam":
			var f: Vector3 = forward()
			_slam_at = global_position + f * float(R["slam"]["reach"])
			_slam_at.y = EnemyFx.floor_y(self, _slam_at, global_position.y)
			begin_telegraph(&"slam", float(R["slam"]["tele"]), float(R["slam"]["r"]), _slam_at)
			tele_light.light_color = Color("#9dff5a")
		&"volley":
			begin_telegraph(&"volley", float(R["volley"]["tele"]), -1.0, Vector3.INF, false)
			tele_light.light_color = Color("#c06aff")
		&"thrash":
			begin_telegraph(&"thrash", float(R["thrash"]["tele"]), float(R["thrash"]["r"]))
			tele_light.light_color = Color("#ff5d2e")
		&"wave":
			begin_telegraph(&"wave", float(R["wave"]["tele"]), 2.0)
			tele_light.light_color = Color("#4fc3ff")


func _tele_tick(kind: StringName, dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	match kind:
		&"slam":
			_arm_r.rotation.x = -k * 2.2                     # the arm goes up high
			_core_mat.emission_energy_multiplier = 1.6 + k * 3.0
			face(_slam_at - global_position, dt, 3.0)
		&"volley":
			visual.scale = Vector3(1.0 + k * 0.08, 1.0 - k * 0.06, 1.0 + k * 0.08)   # the chest puffs
		&"thrash":
			_arm_l.rotation.y = k * 1.2
			_arm_r.rotation.y = -k * 1.2
		&"wave":
			visual.position.y = -k * 0.4                     # he sinks to push the water


func _attack_start(kind: StringName) -> void:
	match kind:
		&"slam":
			_arm_r.rotation.x = 0.4
			_core_mat.emission_energy_multiplier = 5.0
			EnemyFx.chunks(get_parent(), _slam_at, Color("#4a6a2a"), 1.2, 4, 6)
			if target_alive() and not target_dodging() and target_center().distance_to(_slam_at) < float(R["slam"]["r"]):
				hurt_target(float(R["slam"]["dmg"]), float(R["slam"]["knock"]))
		&"volley":
			visual.scale = _base_scale
			var V: Dictionary = R["volley"]
			var n: int = int(V["count"])
			var fan: float = deg_to_rad(float(V["fan_deg"]))
			var base: Vector3 = target_pos() - global_position
			base.y = 0.0
			var dist: float = maxf(4.0, base.length())
			var dir: Vector3 = base.normalized() if base.length() > 0.1 else forward()
			for i: int in n:
				var a: float = (float(i) - float(n - 1) * 0.5) * fan
				var land: Vector3 = global_position + dir.rotated(Vector3.UP, a) * dist
				lob_shell(get_center() + Vector3(0, 1.0, 0), land, float(V["flight"]), float(V["dmg"]), Color("#9dff5a"), float(V["blast_r"]), {"size": 0.35})
		&"thrash":
			_arm_l.rotation.y = -1.4
			_arm_r.rotation.y = 1.4
			if target_alive() and not target_dodging() and flat_dist_to_target() < float(R["thrash"]["r"]) + radius * 0.5 \
					and target_pos().y < global_position.y + float(R["thrash"].get("jump_clear", 1.0)):
				hurt_target(float(R["thrash"]["dmg"]), 9.0)
		&"wave":
			visual.position.y = 0.0
			waves += 1
			_wave = {"r": 1.0, "max": maxf(arena_size.x, arena_size.y) * 0.6, "hit": false}
			EnemyFx.ring(get_parent(), global_position, 2.0, 0.5, Color("#4fc3ff"))


func _attack_tick(kind: StringName, _dt: float) -> bool:
	match kind:
		&"slam":
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.0, 0.1)
			return state_t >= 0.5
		&"thrash":
			_arm_l.rotation.y = lerpf(_arm_l.rotation.y, 0.0, 0.08)
			_arm_r.rotation.y = lerpf(_arm_r.rotation.y, 0.0, 0.08)
			return state_t >= 0.6
		&"wave":
			return state_t >= 0.4
	return state_t >= 0.3


func _idle_after(kind: StringName) -> float:
	var r: Array = R["idle"][clampi(phase - 1, 0, 2)]
	var base: float = randf_range(float(r[0]), float(r[1]))
	if kind == &"slam":
		base = ph(R["slam"]["every"]) * 0.5
	return base * timer_mult()


func _pattern_cancelled() -> void:
	_arm_r.rotation.x = 0.0
	_arm_l.rotation.y = 0.0
	_arm_r.rotation.y = 0.0
	visual.scale = _base_scale
	visual.position.y = 0.0
	_core_mat.emission_energy_multiplier = 1.6


# ------------------------------------------------------------------ weak point / phases

func weak_point_exposed() -> bool:
	return true


func _weak_point_pos() -> Vector3:
	return core_pos()


func _boss_on_hurt(_hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	if negotiating and _talk_bark_cd <= 0.0:
		_talk_bark_cd = 1.5
		var ln: Dictionary = R.get("lines", {})
		EventBus.banner.emit(line_text(str(ln.get("talk_banner", "code.updateCompostKing.03"))), "", 0.8)


func _on_phase(p: int) -> void:
	var ln: Dictionary = R.get("lines", {})
	if p == 2:
		for v: CoolantValve in valves():
			v.set_open(true)
		if ln.has("phase2_banner"):
			banner_lines(ln["phase2_banner"], 2.0)
		if ln.has("phase2"):
			VOManager.play(str(ln["phase2"]))
		for v: CoolantValve in valves():
			EnemyFx.ring(get_parent(), v.jet, 1.6, 1.0, Color("#39ff88"))
	elif p == 3:
		_begin_negotiation()


func _begin_negotiation() -> void:
	negotiating = true
	pleas += 1
	plea_t = float(R["negotiation"]["plea"])
	phase_invuln = plea_t + 0.2
	_crack_valve = null
	_wave = {}
	cancel_attack()
	idle_t = plea_t
	var ln: Dictionary = R.get("lines", {})
	if ln.has("plea_banner"):
		banner_lines(ln["plea_banner"], 2.4)
	if ln.has("plea"):
		VOManager.play(str(ln["plea"]))
	telegraphed.emit(&"negotiation", &"corn_voice", plea_t)
	if all_sealed():
		_offer_mercy()
	elif ln.has("plea_leaks_open"):
		queue_line(str(ln["plea_leaks_open"]), 2.5)


func _offer_mercy() -> void:
	if not negotiating or mercy:
		return
	arena_call(&"set_handshake", [true])
	var ln: Dictionary = R.get("lines", {})
	if ln.has("mercy_offer"):
		queue_line(str(ln["mercy_offer"]), 2.0)


func _plea_over() -> void:
	negotiating = false
	arena_call(&"set_handshake", [false])
	if mercy:
		return
	enraged = true
	phase_invuln = 0.0
	idle_t = 1.0
	var ln: Dictionary = R.get("lines", {})
	if ln.has("failed_banner"):
		banner_lines(ln["failed_banner"], 2.4)
	if ln.has("failed"):
		VOManager.play(str(ln["failed"]))
	telegraphed.emit(&"enrage", &"corn_roar", 0.0)


## The mercy ending (BS_ENEMIES §4.6): during the plea with every leak sealed, the handshake stands him down.
## Returns true when accepted. boss_defeated fires without a death: 45 + 60 bolts, "Collective Bargaining".
func accept_mercy(_by: Node = null) -> bool:
	if not negotiating or mercy or defeated or not all_sealed():
		return false
	mercy = true
	negotiating = false
	defeated = true
	cancel_attack()
	desired_vel = Vector3.ZERO
	arena_call(&"set_handshake", [false])
	_music(false)
	EventBus.boss_health.emit(boss_id, 0.0, 0.0)
	EventBus.boss_defeated.emit(boss_id)
	var ln: Dictionary = R.get("lines", {})
	if ln.has("mercy_banner"):
		banner_lines(ln["mercy_banner"], 3.0)
	drop_loot(get_center())
	BS.add_bolts(int(R.get("mercy_bonus", 60)))
	var trophy: String = str(R.get("mercy_trophy", "collective_bargaining"))
	BS.set_flag("trophy_" + trophy)
	EventBus.unlock_granted.emit("bs.trophy." + trophy)
	if not has_meta(&"level_director"):
		for k: String in ["mercy_accepted", "mercy_core", "mercy_bolt"]:
			if ln.has(k):
				queue_line(str(ln[k]), 1.0 + 3.0 * ["mercy_accepted", "mercy_core", "mercy_bolt"].find(k))
	_core_mat.emission_energy_multiplier = 0.6
	_eye_mat.emission_energy_multiplier = 0.8
	_stand_down_t = float(R["negotiation"].get("stand_down", 8.0))
	telegraphed.emit(&"mercy", &"corn_sigh", 0.0)
	return true


func _pattern_died(_hit: Combat.Hit) -> void:
	_wave = {}
	arena_call(&"set_handshake", [false])


func _anim(_delta: float) -> void:
	if state != State.TELEGRAPH and state != State.ATTACK:
		_core_mat.emission_energy_multiplier = (1.6 + sin(t * 4.0) * 0.6) if not mercy else 0.6
	_crown.rotation.y = t * 0.3
	if negotiating:
		visual.rotation.z = sin(t * 2.0) * 0.03
	elif not mercy:
		visual.rotation.z = 0.0
	if _eye_mat != null and not mercy:
		_eye_mat.emission_energy_multiplier = 3.0 if enraged else 2.0
