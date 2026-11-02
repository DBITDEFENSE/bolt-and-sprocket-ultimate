class_name MoonLowG
extends Node3D
## Low gravity done right on Mondlicht (UPDATE 10 §3 Act IV, contract C6 `low_g`, T-158; data map04d.json "low_g"):
##   · the PADS are JumpPad nodes; this node says the Operator's line on the first launch of the match;
##   · the LEAPERS: a Gänger that rises at one of the act's leap points (Catwalk_C_YARD_n, Catwalk_E_HALL_n) carries a
##     jump rig and, chasing a target leap_min_m..leap_max_m away, leaps at it in a high slow arc (air_seconds under
##     the zombies' Moon gravity): the dead come down at you from above. Shot in the air the rig fails and it falls
##     dead; a landing staggers players within land_radius. (Act III's Jumpjockeys live in GroomController, which
##     the Moon does not run; this is the Moon's own, smaller rule.)
##   · the FLING INTO SPACE: lodestone.gd hands every flung zombie to `on_flung`; in a vacuum zone at fling_speed
##     m/s or more it goes up and out: a kill credited to the flinger (+orbit_scrip), the corpse taken off the
##     regolith, a dark tumbling shape streaking up and away with a long fading scream. `orbit_count` is the HUD's
##     SENT TO ORBIT (MoonSuitHud). Host-owned (C8): the host decides; the streak and the count are mirrored.

var cfg: Dictionary = {}
var orbit_count: int = 0
var leapers: Dictionary = {}         # Zombie -> {cd, airborne, hp0, air_t}
var leaps: int = 0
var _pad_said: bool = false
var _launch_points: Array[Vector3] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## True when a fling at `speed` m/s in a vacuum zone sends the body to orbit.
static func orbits(speed: float, in_vacuum: bool, fling_speed: float) -> bool:
	return in_vacuum and speed >= fling_speed


## A leap's take-off velocity at `to` in `air_s` seconds under gravity `g` (lands level with the take-off).
static func leap_velocity(from: Vector3, to: Vector3, air_s: float, g: float, max_mps: float = 14.0) -> Vector3:
	var d: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	var flat: Vector3 = Vector3.ZERO if d.length() < 0.01 else d / maxf(0.2, air_s)
	if flat.length() > max_mps:
		flat = flat.normalized() * max_mps
	return Vector3(flat.x, 0.5 * g * air_s, flat.z)


## True when a chaser at `dist` m may leap (range) and is at a launch point or has waited long enough (cd < -8).
static func may_leap(dist: float, near_point: bool, cd: float, lo: float, hi: float) -> bool:
	if cd > 0.0 or dist < lo or dist > hi:
		return false
	return near_point or cd <= -8.0


func _ready() -> void:
	name = "MoonLowG"
	add_to_group(&"moon_lowg")
	cfg = GLData.load_json("res://data/gravelight/map04d.json").get("low_g", {})
	_rng.seed = 4044
	GLBus.enemy_spawned.connect(_on_enemy_spawned)
	(func() -> void:
		for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
			if String(n.name).begins_with("Catwalk_"):
				_launch_points.append((n as Node3D).global_position)).call_deferred()


# ---------------------------------------------------------------- the pads

func pad_used(_p: Player, _pad: Node) -> void:
	if _pad_said or not Net.is_authority():
		return
	_pad_said = true
	var id: String = str(cfg.get("vo_pad", ""))
	if id != "":
		GLVO.play(StringName(id))


# ---------------------------------------------------------------- the leapers

func _near_launch(p: Vector3, r: float) -> bool:
	for lp: Vector3 in _launch_points:
		if Vector2(p.x - lp.x, p.z - lp.z).length() <= r:
			return true
	return false


func _on_enemy_spawned(enemy_id: StringName, node_id: int) -> void:
	if not Net.is_authority() or enemy_id != &"ganger":
		return
	var z: Zombie = instance_from_id(node_id) as Zombie
	if z == null or z is HomageBoss or leapers.has(z):
		return
	(func() -> void:
		if is_instance_valid(z) and z.is_active() and _near_launch(z.global_position, 2.0):
			make_leaper(z)).call_deferred()


## Gives a live Gänger the jump rig (the spawn hook, the console and the smoke).
func make_leaper(z: Zombie) -> void:
	if z == null or leapers.has(z):
		return
	leapers[z] = {"cd": 1.5, "airborne": false, "hp0": z.hp, "air_t": 0.0}
	var rig: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.42, 0.5, 0.22)
	rig.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.19, 0.24)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.3, 1.0)
	m.emission_energy_multiplier = 0.8
	rig.material_override = m
	rig.position = Vector3(0, 1.25, 0.2)
	rig.name = "MoonRig"
	z.add_child(rig)
	z.set_meta("moon_rig", rig)


func _drop_leaper(z: Variant) -> void:
	var zz: Zombie = z as Zombie
	if zz != null and is_instance_valid(zz) and zz.has_meta("moon_rig"):
		var r: Node = zz.get_meta("moon_rig") as Node
		if r != null and is_instance_valid(r):
			r.queue_free()
		zz.remove_meta("moon_rig")
	leapers.erase(z)


func _physics_process(delta: float) -> void:
	if not Net.is_authority() or leapers.is_empty():
		return
	for z: Variant in leapers.keys():
		var zz: Zombie = z as Zombie
		if zz == null or not is_instance_valid(zz) or not zz.is_active():
			_drop_leaper(z)
			continue
		var d: Dictionary = leapers[z]
		if bool(d["airborne"]):
			d["air_t"] = float(d["air_t"]) + delta
			if zz.hp < float(d["hp0"]) - 0.5 and zz.state != Zombie.State.DEAD:
				zz.take_damage(zz.hp + 1.0, &"torso", &"fall", 0, &"explosive", true)   # shot in the air: the rig fails
				d["airborne"] = false
				continue
			if not zz.is_pushed() or float(d["air_t"]) > float(cfg.get("air_seconds", 2.4)) + 1.0:
				d["airborne"] = false
				_land(zz)
			continue
		d["cd"] = float(d["cd"]) - delta
		if zz.state != Zombie.State.CHASE or zz.target == null:
			continue
		var to: Vector3 = zz.target.global_position
		var dist: float = Vector2(to.x - zz.global_position.x, to.z - zz.global_position.z).length()
		if may_leap(dist, _near_launch(zz.global_position, float(cfg.get("launch_near_m", 5.0))), float(d["cd"]), float(cfg.get("leap_min_m", 6.0)), float(cfg.get("leap_max_m", 24.0))):
			leap(zz, to)


## One leap at `to` (the console and the smoke call it too).
func leap(z: Zombie, to: Vector3) -> void:
	var air: float = float(cfg.get("air_seconds", 2.4))
	var v: Vector3 = leap_velocity(z.global_position, to, air, GameState.g_zombie())
	z.external_push(v, air + 0.2)
	if not z.is_pushed():
		return
	z.velocity.y = v.y   # Zombie._update_push only takes a push's vertical on a state's first frame: the take-off here

	var d: Dictionary = leapers.get(z, {"cd": 0.0, "airborne": false, "hp0": z.hp, "air_t": 0.0})
	d["airborne"] = true
	d["hp0"] = z.hp
	d["air_t"] = 0.0
	d["cd"] = float(cfg.get("cooldown", 7.0))
	leapers[z] = d
	leaps += 1
	AudioDirector.play_3d("zombie_sprint", z.global_position + Vector3.UP, 2.0)
	Effects.dust_puff(z.global_position, "earth", 10)


func _land(z: Zombie) -> void:
	Effects.dust_puff(z.global_position, "earth", 14)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var dd: Vector3 = p.global_position - z.global_position
		if Vector2(dd.x, dd.z).length() <= float(cfg.get("land_radius", 2.2)) and absf(dd.y) < 2.0:
			p.apply_knockback(Vector3(dd.x, 0, dd.z).normalized() * 5.0)


# ---------------------------------------------------------------- the fling into space

## lodestone.gd: a zombie was just flung with `vel` by `pid`. In the open vacuum, fast enough: to orbit.
func on_flung(z: Zombie, vel: Vector3, pid: int, weapon_id: StringName) -> bool:
	if not Net.is_authority() or z == null or not is_instance_valid(z) or not z.is_active():
		return false
	if not orbits(vel.length(), ZoneVolume.vacuum_at(get_tree(), z.global_position), float(cfg.get("fling_speed", 15.0))):
		return false
	send_to_orbit(z, vel, pid, weapon_id)
	return true


func send_to_orbit(z: Zombie, vel: Vector3, pid: int, weapon_id: StringName) -> void:
	var at: Vector3 = z.global_position
	var dir: Vector3 = Vector3(vel.x, 0.0, vel.z)
	dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	_drop_leaper(z)
	z.take_damage(z.hp + 1.0, &"torso", weapon_id, pid, &"explosive", true)
	if z.state == Zombie.State.DEAD:
		# no corpse on the regolith: the body is the shape streaking away (the pool takes it back at once)
		z.set("_death_sink", true)
		z.set("_sink_corpse_s", 0.05)
	if pid > 0:
		Economy.grant(pid, int(cfg.get("orbit_scrip", 120)))
	orbit_count += 1
	_streak(at, dir, orbit_count)
	Net.mirror(self, &"_streak", [at, dir, orbit_count])
	if orbit_count == 1:
		GLVO.play(StringName(str(cfg.get("vo_orbit", "OPR_M4D_ORBIT_01"))))
	elif orbit_count % 5 == 0:
		var more: Array = cfg.get("vo_orbit_more", [])
		if not more.is_empty():
			GLVO.play(StringName(str(more[_rng.randi() % more.size()])))
	print("[m4d] sent to orbit: %d (by %d)" % [orbit_count, pid])


## Every peer: the dark shape tumbling up and out, its streak, the scream fading after it.
func _streak(at: Vector3, dir: Vector3, count: int) -> void:
	orbit_count = maxi(orbit_count, count)
	var s: OrbitStreak = OrbitStreak.new()
	get_tree().current_scene.add_child(s)
	s.start(at + Vector3.UP * 0.9, dir)


## The tumbling shape (presentation): up and away along `dir` for `life` s, shrinking, a violet-white trail, the
## scream (m4d_orbit_scream) following it and falling away.
class OrbitStreak extends Node3D:
	var life: float = 6.0
	var t: float = 0.0
	var from: Vector3
	var dir: Vector3
	var body: MeshInstance3D
	var trail: MeshInstance3D
	var trail_mat: StandardMaterial3D
	var voice: AudioStreamPlayer3D

	func start(at: Vector3, d: Vector3) -> void:
		from = at
		dir = d
		global_position = at
		body = MeshInstance3D.new()
		var cm: CapsuleMesh = CapsuleMesh.new()
		cm.radius = 0.25
		cm.height = 1.7
		body.mesh = cm
		var bm: StandardMaterial3D = StandardMaterial3D.new()
		bm.albedo_color = Color(0.08, 0.07, 0.09)
		body.material_override = bm
		add_child(body)
		trail = MeshInstance3D.new()
		var tm: CylinderMesh = CylinderMesh.new()
		tm.top_radius = 0.02
		tm.bottom_radius = 0.18
		tm.height = 1.0
		trail.mesh = tm
		trail_mat = StandardMaterial3D.new()
		trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		trail_mat.albedo_color = Color(0.85, 0.7, 1.0, 0.8)
		trail_mat.disable_fog = true
		trail.material_override = trail_mat
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(trail)
		voice = AudioStreamPlayer3D.new()
		voice.bus = &"SFX"
		voice.max_distance = 120.0
		voice.unit_size = 8.0
		var st: Variant = AudioDirector.call("_pick", "m4d_orbit_scream") if AudioDirector.has_sound("m4d_orbit_scream") else null
		if st is AudioStream:
			voice.stream = st
			add_child(voice)
			voice.play()
		Effects.dust_puff(at - Vector3.UP * 0.9, "earth", 12)

	func pos_at(tt: float) -> Vector3:
		return from + dir * (10.0 * tt) + Vector3.UP * (5.0 * tt + 3.5 * tt * tt)

	func _process(delta: float) -> void:
		t += delta
		var p: Vector3 = pos_at(t)
		global_position = p
		body.rotation += Vector3(3.1, 1.7, 2.3) * delta
		var k: float = clampf(1.0 - t / life, 0.0, 1.0)
		body.scale = Vector3.ONE * maxf(0.05, k)
		var back: Vector3 = pos_at(maxf(0.0, t - 0.45))
		var mid: Vector3 = (p + back) * 0.5
		var len: float = maxf(0.1, p.distance_to(back))
		var up: Vector3 = (p - back).normalized()
		var side: Vector3 = up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
		trail.global_transform = Transform3D(Basis(side, up, side.cross(up)).scaled(Vector3(1, len, 1)), mid)
		trail_mat.albedo_color.a = 0.8 * k
		if voice != null and voice.playing:
			voice.volume_db = linear_to_db(maxf(0.0005, k * k))
			voice.pitch_scale = lerpf(0.72, 1.0, k)
		if t >= life:
			trail.queue_free()
			queue_free()
