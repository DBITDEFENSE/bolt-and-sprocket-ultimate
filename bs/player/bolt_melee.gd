class_name BoltMelee
extends Node
## The mallet, ported from the web build (index.html:4852-5175): wrenchSwing, beginMelee, startAttack,
## meleeHit, updateMelee, throwWrench/updateWrenchThrow, slamImpact damage, comboHit.
## Child of Bolt. Tuning: data/bs/tuning.json melee + slam (original CONFIG).

signal swung(tag: String)
signal hit_landed(count: int, finisher: bool)
signal thrown

var bolt: Bolt
var T: Dictionary
var attack_t: float = 0.0
var attack_def: Dictionary = {}
var attack_tag: String = ""
var attack_hit_done: bool = true
var combo_idx: int = 0
var combo_win_t: float = 0.0
var air_combo: int = 0
var queue: bool = false
var queue_t: float = 0.0
var combo_hits: int = 0
var combo_t: float = 0.0
# boomerang throw
var throw_active: bool = false
var throw_phase: String = "out"
var throw_t: float = 0.0
var throw_cd: float = 0.0
var throw_pos: Vector3 = Vector3.ZERO
var throw_vel: Vector3 = Vector3.ZERO
var throw_hits: Dictionary = {}


func _ready() -> void:
	bolt = get_parent() as Bolt
	T = Data.table("bs/tuning")


## resetPlayer() (index.html:2947): clear any attack in progress and retrieve a thrown mallet.
func reset() -> void:
	attack_t = 0.0
	attack_hit_done = true
	queue = false
	combo_idx = 0
	combo_win_t = 0.0
	air_combo = 0
	throw_active = false
	throw_cd = 0.0


func windup_committed() -> bool:
	return attack_t > 0.0 and not attack_hit_done


func down_held() -> bool:
	return Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed(&"crouch") \
		or Input.get_action_strength(&"move_back") > 0.5


func malletDmg(base: float) -> float:
	return roundf(base * (1.0 + 0.35 * BS.mallet_tier))


func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, float(T["loop"]["dt_max"]))
	if bolt.dead:
		return
	if bolt.scripted.get("melee_pressed", false):
		bolt.scripted.erase("melee_pressed")
		swing()
	elif bolt.scripted.is_empty() and bolt.input_enabled and not BS.blocked() and Input.is_action_just_pressed(&"melee"):
		swing()
	_update(dt)


## F / pad X (wrenchSwing 4877).
func swing() -> void:
	var m: BoltMotor = bolt.motor
	if m.slam != &"":
		return
	if not m.on_ground and m.jumps >= 2:              # double jump spent -> the slam family
		attack_t = 0.0
		m.start_slam(&"super" if down_held() else &"std")
		return
	if Input.is_action_pressed(&"aim") and not throw_active:
		throw_mallet()
		return
	if m.slide_t > 0.0 or m.slide_low:                # slide cancels into the launcher
		if not bolt.call("_blocked_above"):
			m.set_slide_hitbox(false)
			bolt.call("_apply_slide_shift")
			m.slide_t = 0.0
			start_attack(T["melee"]["launcher"], "launcher")
		return
	if attack_t > 0.0:
		queue = true
		queue_t = float(T["melee"]["queueWindow"])
		return
	begin()


func begin() -> void:
	var M: Dictionary = T["melee"]
	var m: BoltMotor = bolt.motor
	if throw_active:
		start_attack(M["punch"], "punch")
		return
	if m.dash_t > 0.0:
		start_attack(M["dashStab"], "dash")
		m.dash_t = maxf(m.dash_t, 0.12)
		return
	if not m.on_ground:
		if air_combo >= (M["air"] as Array).size():
			return
		start_attack((M["air"] as Array)[air_combo], "air%d" % air_combo)
		air_combo += 1
		return
	if combo_win_t <= 0.0:
		combo_idx = 0
	start_attack((M["ground"] as Array)[combo_idx], "ground%d" % combo_idx)


func start_attack(def: Dictionary, tag: String) -> void:
	attack_def = def
	attack_tag = tag
	attack_t = float(def["dur"])
	attack_hit_done = false
	var m: BoltMotor = bolt.motor
	if bolt.camera != null:
		m.yaw = bolt.camera.yaw + PI                    # face the swing
	var mk: float = AimAssist.melee_k()
	if mk > 0.0:
		var M: Dictionary = T["melee"]
		var f: Vector3 = Vector3(sin(m.yaw), 0, cos(m.yaw))
		var best: Node3D = AimAssist.pick_target(f, float(M["magnetCone"]), float(M["magnetRange"]), true)
		if best != null:
			var to: Vector3 = best.global_position - bolt.global_position
			m.yaw = lerp_angle(m.yaw, atan2(to.x, to.z), minf(1.0, 0.4 + mk))
			var d: float = Vector2(to.x, to.z).length()
			if d > float(def["range"]) * 0.55 and (m.on_ground or m.dash_t > 0.0):
				var lunge: float = float(T["AIM_ASSIST"]["meleeLunge"]) * mk
				var hd: Vector3 = Vector3(to.x, 0, to.z).normalized()
				m.vel.x += hd.x * lunge
				m.vel.z += hd.z * lunge
	swung.emit(tag)


func _update(dt: float) -> void:
	combo_win_t -= dt
	queue_t -= dt
	if queue_t <= 0.0:
		queue = false
	if combo_t > 0.0:
		combo_t -= dt
		if combo_t <= 0.0:
			combo_hits = 0
			EventBus.combo_changed.emit(0)
	_update_throw(dt)
	if attack_t > 0.0:
		var def: Dictionary = attack_def
		attack_t -= dt
		if not attack_hit_done and attack_t <= float(def["dur"]) * (1.0 - float(def.get("hitK", 0.45))):
			attack_hit_done = true
			hit(def)
		if attack_t <= 0.0:
			if attack_tag.begins_with("ground"):
				if def.get("finisher", false):
					combo_idx = 0
					combo_win_t = 0.0
				else:
					combo_idx += 1
					combo_win_t = float(def["window"])
			if queue:
				queue = false
				begin()
			elif Input.is_action_pressed(&"melee") and bolt.motor.on_ground and attack_tag.begins_with("ground") \
					and not attack_def.get("finisher", false):
				start_attack(T["melee"]["launcher"], "launcher")    # held melee -> uppercut launcher
				combo_idx = 0
				combo_win_t = 0.0
	elif queue:
		queue = false
		begin()
	if bolt.motor.on_ground:
		air_combo = 0


func combo_hit(n: int = 1) -> void:
	combo_hits += n
	combo_t = 1.4
	EventBus.combo_changed.emit(combo_hits)
	BS.add_super(0.012 * n)


## The moment of impact (meleeHit 4969).
func hit(def: Dictionary) -> bool:
	var m: BoltMotor = bolt.motor
	var f: Vector3 = Vector3(sin(m.yaw), 0, cos(m.yaw))
	var arc_dot: float = float(def.get("arc", -0.1))
	var hit_count: int = 0
	var range_: float = float(def["range"])
	for e: Node3D in Combat.in_radius(get_tree(), bolt.global_position, range_ + 2.0):
		var to: Vector3 = (e.call("get_center") as Vector3) - bolt.global_position
		if absf(to.y) > 2.6:
			continue
		if to.length() > range_ + float(e.get("radius")):
			continue
		if Vector3(to.x, 0, to.z).normalized().dot(f) < arc_dot:
			continue
		hit_count += 1
		AimAssist.last_melee = e
		var st: StatusEffects = e.get_node_or_null("Status") as StatusEffects
		var h: Combat.Hit = Combat.Hit.make(malletDmg(float(def["dmg"])), Combat.Type.KINETIC, bolt)
		h.weapon_id = &"mallet"
		h.is_melee = true
		h.point = e.call("get_center")
		h.dir = f
		h.knock = float(def.get("knock", 5.0))
		h.launch = float(def.get("launch", 0.0))
		if st != null and st.has(&"frozen"):
			h.amount *= 2.5                               # SHATTER
			h.status = {"shatter": 0.01}
			st.clear(&"frozen")
		if def.get("finisher", false):
			h.status["stun"] = 0.8
		e.call("take_damage", h)
		combo_hit()
		if BS.mallet_tier >= 2 and not def.get("finisher", false):
			_arc_to_neighbor(e, 12.0)
	if hit_count > 0:
		Game.hitstop(float(def.get("hitstop", T["melee"]["hitstopSmall"])) + 0.012 * (hit_count - 1))
		if bolt.camera != null:
			bolt.camera.shake(0.35 if def.get("finisher", false) else 0.15)
			if def.get("finisher", false):
				bolt.camera.punch_in(1.3)
				m.fov_kick = maxf(m.fov_kick, 6.0)
		if def.has("launch"):
			m.vel.y = maxf(m.vel.y, float(T["melee"]["launcher"]["popJump"]))
			m.jumps = 1
			air_combo = 0
			m.coyote = 0.0
	if def.get("finisher", false) and m.on_ground:     # finisher shockwave
		var c: Vector3 = bolt.global_position + f * 1.3
		var rr: float = 2.6 + BS.mallet_tier * 1.1
		for e2: Node3D in Combat.in_radius(get_tree(), c, rr):
			var h2: Combat.Hit = Combat.Hit.make(malletDmg(12.0), Combat.Type.KINETIC, bolt)
			h2.weapon_id = &"mallet"
			h2.is_melee = true
			h2.point = e2.call("get_center")
			e2.call("take_damage", h2)
			if BS.mallet_tier >= 2:
				_arc_to_neighbor(e2, 14.0)
		if bolt.camera != null:
			bolt.camera.shake(0.3)
	hit_landed.emit(hit_count, bool(def.get("finisher", false)))
	return hit_count > 0


func _arc_to_neighbor(from: Node3D, dmg: float) -> void:
	var c: Vector3 = from.call("get_center")
	for e: Node3D in Combat.in_radius(get_tree(), c, 7.0):
		if e == from:
			continue
		var h: Combat.Hit = Combat.Hit.make(dmg, Combat.Type.SHOCK, bolt)
		h.weapon_id = &"mallet"
		h.point = e.call("get_center")
		e.call("take_damage", h)
		return


## Slam shockwave damage (slamImpact 3184): radius/damage by kind, scaled by mallet tier; gravity-clumped
## enemies take x1.6; knockback outward and a launch.
func slam_impact(kind: StringName) -> void:
	var S: Dictionary = T["slam"]
	var big: bool = kind == &"super"
	var tier_k: float = 1.0 + 0.15 * BS.mallet_tier
	var radius: float = (float(S["superRadius"]) if big else float(S["radius"])) * tier_k
	var dmg: float = roundf((float(S["superDmg"]) if big else float(S["dmg"])) * tier_k)
	var c: Vector3 = bolt.global_position - Vector3(0, bolt.motor.hy - 0.08, 0)
	if bolt.camera != null:
		bolt.camera.shake(0.7 if big else 0.4)
	var n: int = 0
	for e: Node3D in Combat.in_radius(get_tree(), c, radius):
		n += 1
		var ec: Vector3 = e.call("get_center")
		var d: float = ec.distance_to(c)
		var st: StatusEffects = e.get_node_or_null("Status") as StatusEffects
		var clumped: bool = st != null and st.has(&"gravity_clumped")
		var h: Combat.Hit = Combat.Hit.make(roundf(dmg * (1.0 - 0.4 * d / (radius + float(e.get("radius")))) * (1.6 if clumped else 1.0)), Combat.Type.KINETIC, bolt)
		h.weapon_id = &"mallet"
		h.is_melee = true
		h.is_slam = true
		h.point = ec
		h.dir = Vector3(ec.x - c.x, 0, ec.z - c.z).normalized()
		h.knock = 8.0 if big else 6.0
		h.launch = float(S["knockUp"]) * (1.3 if big else 0.8)
		e.call("take_damage", h)
		combo_hit()
	if big and n >= 3:
		Game.slowmo(0.3)                                 # earned spectacle


# ------------------------------------------------------------------ boomerang throw

func throw_mallet() -> void:
	var TH: Dictionary = T["melee"]["throw"]
	if throw_active or throw_cd > 0.0 or attack_t > 0.0:
		return
	throw_active = true
	throw_phase = "out"
	throw_t = 0.0
	throw_hits.clear()
	var d: Vector3 = bolt.aim_dir()
	throw_vel = d * float(TH["speed"])
	throw_pos = bolt.global_position + Vector3(0, 0.5, 0) + d * 0.8
	if bolt.camera != null:
		bolt.motor.yaw = bolt.camera.yaw + PI
	thrown.emit()


func _update_throw(dt: float) -> void:
	throw_cd -= dt
	if not throw_active:
		return
	var TH: Dictionary = T["melee"]["throw"]
	throw_t += dt
	if throw_phase == "out":
		var next: Vector3 = throw_pos + throw_vel * dt
		var space: PhysicsDirectSpaceState3D = bolt.get_world_3d().direct_space_state
		var hit_world: bool = not space.intersect_ray(PhysicsRayQueryParameters3D.create(throw_pos, next, 1)).is_empty()
		throw_pos = next
		if throw_t >= float(TH["outTime"]) or hit_world:
			throw_phase = "back"
			throw_hits.clear()
			_hit_switches(throw_pos)
	else:
		var home: Vector3 = bolt.global_position + Vector3(0, 0.5, 0)
		var to: Vector3 = home - throw_pos
		if to.length() < 1.1:
			throw_active = false
			throw_cd = float(TH["cooldown"]) - float(TH["outTime"])
			return
		throw_pos += to.normalized() * float(TH["speed"]) * 1.2 * dt
	for e: Node3D in Combat.in_radius(get_tree(), throw_pos, 0.55):
		if throw_hits.has(e):
			continue
		throw_hits[e] = true
		var h: Combat.Hit = Combat.Hit.make(float(TH["dmg"]), Combat.Type.KINETIC, bolt)
		h.weapon_id = &"mallet_throw"
		h.is_melee = true
		h.point = e.call("get_center")
		e.call("take_damage", h)
		combo_hit()
	# remake: the boomerang collects loose bolts and hits switches (brief §4.1)
	for p: Node in get_tree().get_nodes_in_group(&"pickups"):
		if (p as Node3D).global_position.distance_to(throw_pos) < 1.2 and p.has_method("collect"):
			p.call("collect", bolt)
	_hit_switches(throw_pos)


func _hit_switches(at: Vector3) -> void:
	for s: Node in get_tree().get_nodes_in_group(&"mallet_switches"):
		if (s as Node3D).global_position.distance_to(at) < 1.4 and s.has_method("on_mallet"):
			s.call("on_mallet", bolt)
