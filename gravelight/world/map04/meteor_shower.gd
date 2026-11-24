class_name MeteorShower
extends Node3D
## The meteor-shower round on Mondlicht (UPDATE 10 §3 Act IV, contract C6 `meteor_shower`, the Bar's row 14, T-158;
## data map04d.json "meteor_shower"): on match rounds first_round, +every, ... (never a special round) the relay
## warns `warn_seconds` ahead (its klaxon, the Operator's "scheduled maintenance", a banner), then for `seconds`
## the open yard takes small impacts: each telegraphed by a ring `tele_s` ahead, a streak falling out of the black,
## a strike `radius_m` wide (the dead in it die; a player takes up to player_damage), dust, and a crater mark that
## fades. Every `aim_every`-th lands near a player standing in the yard. Nothing lands under a roof: shelter in the
## modules. Flag `meteor_shower` while it runs; each incoming strike is a danger zone on the squad's blackboard (the
## bots leave it). Host-owned (C8): the host picks every point; the warning, the rings and the strikes are mirrored.

var cfg: Dictionary = {}
var active: bool = false
var warning: bool = false             # U10 T-163: between the warning and the first strike (the bots take shelter)
var left: float = 0.0
var impacts: int = 0
var kills: int = 0
var showers: int = 0
var _next: float = 0.0
var _n: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending: Array = []             # [time left, pos] (host)
var _marks: Array = []               # [MeshInstance3D, seconds left]
## T-274: supply capsules that came down after a shower (the smoke and the tests read it)
var capsules: int = 0


## True when match round `r` is a shower round.
static func is_shower_round(r: int, first: int, every: int, special: bool) -> bool:
	if special or r < first or every <= 0:
		return false
	return (r - first) % every == 0


## Damage to a player `d` m from a strike of radius `r` (full at the centre, none at the edge).
static func damage_at(d: float, r: float, full: float) -> float:
	return 0.0 if d > r else full * (1.0 - d / maxf(0.01, r))


## A random strike point in the yard box [x0, z0, x1, z1].
static func point_in(box: Array, rx: float, rz: float) -> Vector3:
	return Vector3(lerpf(float(box[0]), float(box[2]), rx), 0.0, lerpf(float(box[1]), float(box[3]), rz))


func _ready() -> void:
	name = "MeteorShower"
	add_to_group(&"meteor_shower")
	cfg = GLData.load_json("res://data/gravelight/map04d.json").get("meteor_shower", {})
	_rng.randomize()
	GLBus.round_started.connect(_on_round_started)
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "meteors", _cmd, "meteors now|capsule|status: Mondlicht's meteor shower (T-158), its supply capsule (T-274)")


func _on_round_started(r: int, special: bool) -> void:
	if not Net.is_authority() or cfg.is_empty():
		return
	if is_shower_round(r, int(cfg.get("first_round", 33)), int(cfg.get("every", 6)), special):
		get_tree().create_timer(4.0).timeout.connect(begin)


## Host: the warning now, the shower `warn_seconds` later.
func begin() -> void:
	if active:
		return
	_warn()
	Net.mirror(self, &"_warn", [])
	GLVO.play(StringName(str(cfg.get("vo_warn", "OPR_M4D_METEOR_WARN_01"))))
	get_tree().create_timer(float(cfg.get("warn_seconds", 10.0))).timeout.connect(_start)


func _warn() -> void:
	warning = true
	AudioDirector.play_2d("m4d_meteor_warn", -2.0, 0.0)
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map != null and map.hud != null:
		map.hud.show_banner(str(cfg.get("banner", "SCHEDULED MAINTENANCE")), 3.5)


func _start() -> void:
	active = true
	warning = false
	showers += 1
	left = float(cfg.get("seconds", 40.0))
	_next = 0.5
	GameState.set_flag(&"meteor_shower")
	GLVO.play(StringName(str(cfg.get("vo_start", "OPR_M4D_METEOR_01"))))
	print("[m4d] meteor shower %d starts (%.0f s)" % [showers, left])


func _end() -> void:
	active = false
	GameState.set_flag(&"meteor_shower", false)
	GLVO.play(StringName(str(cfg.get("vo_end", "OPR_M4D_METEOR_END_01"))))
	print("[m4d] meteor shower ends: %d impacts, %d kills" % [impacts, kills])
	if Net.is_authority() and cfg.has("capsule"):   # T-274: the shower's tail brings a supply capsule down
		get_tree().create_timer(float((cfg["capsule"] as Dictionary).get("after_s", 4.0))).timeout.connect(capsule_incoming)


# ---------------------------------------------------------------- T-274: the supply capsule

## Host: a supply capsule comes down on the yard's open ground (`capsule.land_box`): the ring and the streak like a
## strike's (`capsule.tele_s`), then it lands: the dead under it die (nobody living is hurt), the capsule lies in its
## crater with a beacon blinking, and `capsule.ammo_out` ammunition tins (AmmoDrop, walk over: the gun in your hands
## refilled) lie round it. Keyed to the shower's end, so it follows the shower's own schedule.
func capsule_incoming() -> void:
	var cc: Dictionary = cfg.get("capsule", {})
	var box: Array = cc.get("land_box", cfg.get("yard_box", [-39.0, 61.0, 39.0, 109.0]))
	var pos: Vector3 = point_in(box, _rng.randf(), _rng.randf())
	for _try: int in 16:   # open ground: nothing solid within 2.4 m (a rock, the rover), so every tin can be walked to
		if _clear_at(pos, 2.4):
			break
		pos = point_in(box, _rng.randf(), _rng.randf())
	var tele: float = float(cc.get("tele_s", 2.4))
	_ring(pos, tele)
	Net.mirror(self, &"_ring", [pos, tele])
	_mark_danger(pos, tele)
	get_tree().create_timer(tele).timeout.connect(func() -> void: _capsule_land_host(pos))


func _clear_at(pos: Vector3, r: float) -> bool:
	if not is_inside_tree():
		return true
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = r
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * (r + 0.15))
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _capsule_land_host(pos: Vector3) -> void:
	var r: float = float(cfg.get("radius_m", 2.6))
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir != null and dir.has_method("active_zombies"):
		for z: Zombie in dir.call("active_zombies"):
			if not (z is HomageBoss) and Vector2(z.global_position.x - pos.x, z.global_position.z - pos.z).length() <= r:
				z.take_damage(z.hp + 1.0, &"torso", &"meteor", 0, &"explosive", true)
				kills += 1
	_capsule_land(pos)
	Net.mirror(self, &"_capsule_land", [pos])


## Every peer: the capsule in its crater, its beacon, the banner, the tins (named alike on every peer: AmmoDrop's
## pickup is host-decided and mirrored by name).
func _capsule_land(pos: Vector3) -> void:
	capsules += 1
	var cc: Dictionary = cfg.get("capsule", {})
	_impact(pos)
	var pod: Node3D = Node3D.new()
	pod.name = "SupplyCapsule_%d" % capsules
	add_child(pod)
	pod.global_position = pos
	pod.rotation = Vector3(0.0, _rng.randf() * TAU if Net.is_authority() else float(capsules) * 2.1, 0.0)
	var body: Node3D = Props.group(pod, "Body", Vector3(0, 0.55, 0))
	body.rotation_degrees = Vector3(0, 0, 24)   # nose down in the regolith
	Props.cyl(body, Vector3.ZERO, 0.55, 1.5, "chrome_worn", Vector3(0, 0, 90))
	Props.cone(body, Vector3(-0.95, 0, 0), 0.55, 0.45, "grey_paint").rotation_degrees = Vector3(0, 0, 90)
	Props.cyl(body, Vector3(0.8, 0, 0), 0.6, 0.12, "black_paint", Vector3(0, 0, 90))   # the heat shield's lip
	for k: int in 3:
		Props.block(body, Vector3(-0.5 + 0.45 * k, 0.5, -0.03), Vector3(-0.38 + 0.45 * k, 0.6, 0.03), "yellow_paint", false)
	var beacon: MeshInstance3D = Props.ball(body, Vector3(0.2, 0.62, 0), Vector3(0.12, 0.1, 0.12), "lamp_red_lit")
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(1.0, 0.25, 0.15)
	l.omni_range = 6.0
	l.shadow_enabled = false
	l.position = Vector3(0, 1.4, 0)
	pod.add_child(l)
	var tw: Tween = l.create_tween().set_loops(int(float(cc.get("beacon_s", 60.0)) / 1.2))
	tw.tween_property(l, "light_energy", 1.4, 0.1)
	tw.tween_property(l, "light_energy", 0.0, 1.1)
	tw.finished.connect(func() -> void:
		if is_instance_valid(l):
			l.queue_free())
	for i: int in int(cc.get("ammo_out", 2)):
		var d: AmmoDrop = AmmoDrop.new()
		d.name = "CapsuleAmmo_%d_%d" % [capsules, i]
		add_child(d)
		var a: float = TAU * float(i) / maxf(1.0, float(cc.get("ammo_out", 2))) + 0.6
		d.global_position = pos + Vector3(cos(a) * 1.6, 0.0, sin(a) * 1.6)
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map != null and map.hud != null and str(cc.get("banner", "")) != "":
		map.hud.show_banner(str(cc.get("banner", "")), 3.0)
	print("[m4d] supply capsule %d down at %s" % [capsules, str(pos.snapped(Vector3.ONE * 0.1))])


func _process(delta: float) -> void:
	for i: int in range(_marks.size() - 1, -1, -1):
		var m: Array = _marks[i]
		m[1] = float(m[1]) - delta
		var mi: MeshInstance3D = m[0] as MeshInstance3D
		if not is_instance_valid(mi):
			_marks.remove_at(i)
			continue
		if float(m[1]) < 3.0:
			mi.transparency = 1.0 - clampf(float(m[1]) / 3.0, 0.0, 1.0)
		if float(m[1]) <= 0.0:
			mi.queue_free()
			_marks.remove_at(i)
	if not Net.is_authority():
		return
	for i2: int in range(_pending.size() - 1, -1, -1):
		var p: Array = _pending[i2]
		p[0] = float(p[0]) - delta
		if float(p[0]) <= 0.0:
			_pending.remove_at(i2)
			_strike(p[1])
	if not active:
		return
	left -= delta
	_next -= delta
	if _next <= 0.0 and left > 0.0:
		_next = 1.0 / maxf(0.1, float(cfg.get("impacts_per_s", 1.4))) * _rng.randf_range(0.6, 1.4)
		incoming(_pick_point())
	if left <= 0.0 and _pending.is_empty():
		_end()


func _pick_point() -> Vector3:
	_n += 1
	var box: Array = cfg.get("yard_box", [-39.0, 61.0, 39.0, 109.0])
	if _n % maxi(1, int(cfg.get("aim_every", 3))) == 0:
		var targets: Array[Vector3] = []
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var pl: Player = n as Player
			if pl != null and pl.is_alive() and ZoneVolume.vacuum_at(get_tree(), pl.global_position):
				targets.append(pl.global_position)
		if not targets.is_empty():
			var t: Vector3 = targets[_rng.randi() % targets.size()]
			var a: float = _rng.randf() * TAU
			var r: float = _rng.randf() * float(cfg.get("aim_m", 5.0))
			return Vector3(clampf(t.x + cos(a) * r, float(box[0]), float(box[2])), 0.0, clampf(t.z + sin(a) * r, float(box[1]), float(box[3])))
	return point_in(box, _rng.randf(), _rng.randf())


## Host: a strike will land at `pos` in tele_s + fall_s (the ring now, the streak, the hit).
func incoming(pos: Vector3) -> void:
	var box: Array = cfg.get("yard_box", [-39.0, 61.0, 39.0, 109.0])
	pos = Vector3(clampf(pos.x, float(box[0]), float(box[2])), 0.0, clampf(pos.z, float(box[1]), float(box[3])))   # never under a roof
	var tele: float = float(cfg.get("tele_s", 1.2))
	_pending.append([tele, pos])
	_ring(pos, tele)
	Net.mirror(self, &"_ring", [pos, tele])
	_mark_danger(pos, tele)


func _mark_danger(pos: Vector3, tele: float) -> void:
	var map: Node = get_tree().current_scene
	var squad: Object = map.get("squad") if map != null else null
	if squad == null:
		return
	var bb: Object = squad.get("blackboard")
	if bb == null or not bb.has_method("add_danger"):
		return
	var now: float = float(squad.call("time")) if squad.has_method("time") else 0.0
	bb.call("add_danger", pos, float(cfg.get("radius_m", 2.6)) + 1.0, 3.0, now + tele + 0.5, "meteor")


func _strike(pos: Vector3) -> void:
	impacts += 1
	var r: float = float(cfg.get("radius_m", 2.6))
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir != null and dir.has_method("active_zombies"):
		for z: Zombie in dir.call("active_zombies"):
			if z is HomageBoss:
				continue
			if Vector2(z.global_position.x - pos.x, z.global_position.z - pos.z).length() <= r:
				z.take_damage(z.hp + 1.0, &"torso", &"meteor", 0, &"explosive", true)
				kills += 1
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var d: float = Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
		var dmg: float = damage_at(d, r, float(cfg.get("player_damage", 90.0)))
		if dmg > 0.0:
			p.take_hit(dmg, self)
	_impact(pos)
	Net.mirror(self, &"_impact", [pos])


# ---------------------------------------------------------------- presentation (every peer)

func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.disable_fog = true
	return m


## The telegraph: an amber ring on the regolith that closes in, and the streak out of the sky in its last fall_s.
func _ring(pos: Vector3, tele: float) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	var r: float = float(cfg.get("radius_m", 2.6))
	tm.inner_radius = r - 0.15
	tm.outer_radius = r
	tm.rings = 32
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = _mat(Color(1.0, 0.6, 0.2, 0.85))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.6, 0.05, 1.6)
	add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.05
	var tw: Tween = ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(1.0, 0.05, 1.0), tele)
	tw.tween_callback(ring.queue_free)
	var fall: float = minf(tele, float(cfg.get("fall_s", 0.9)))
	get_tree().create_timer(maxf(0.0, tele - fall)).timeout.connect(func() -> void: _streak(pos, fall))


func _streak(pos: Vector3, fall: float) -> void:
	var from: Vector3 = pos + Vector3(-18.0, 70.0, 10.0)
	var s: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.22
	cm.height = 1.0
	s.mesh = cm
	var m: StandardMaterial3D = _mat(Color(1.0, 0.85, 0.6, 0.9))
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	var dir: Vector3 = (pos - from).normalized()
	var side: Vector3 = dir.cross(Vector3.RIGHT).normalized()
	var length: float = 9.0
	var xf: Callable = func(t: float) -> void:
		if not is_instance_valid(s):
			return
		var head: Vector3 = from.lerp(pos, t)
		s.global_transform = Transform3D(Basis(side, -dir, side.cross(-dir)).scaled(Vector3(1, length, 1)), head - dir * length * 0.5)
	xf.call(0.0)
	var tw: Tween = s.create_tween()
	tw.tween_method(xf, 0.0, 1.0, maxf(0.05, fall))
	tw.tween_callback(s.queue_free)


func _impact(pos: Vector3) -> void:
	AudioDirector.play_3d("m4d_meteor_impact", pos + Vector3.UP * 0.3, 2.0)
	Effects.dirt_burst(pos, "earth", 1.6, Vector3.UP, 22)
	Effects.dust_puff(pos, "earth", 18)
	Effects.shatter(pos + Vector3.UP * 0.3, Color(1.0, 0.7, 0.4), 18, 7.0)
	var mark: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	var r: float = float(cfg.get("radius_m", 2.6)) * 0.7
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 16
	mark.mesh = cm
	var mm: StandardMaterial3D = StandardMaterial3D.new()
	mm.albedo_color = Color(0.05, 0.045, 0.05)
	mm.roughness = 1.0
	mark.material_override = mm
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	mark.global_position = pos + Vector3.UP * (0.015 + 0.001 * float(_marks.size() % 8))
	_marks.append([mark, float(cfg.get("mark_seconds", 30.0))])
	var map: Node = get_tree().current_scene
	var lp: Player = map.get("player") as Player if map != null else null
	if lp != null and lp.global_position.distance_to(pos) < 14.0 and lp.has_method("kick_camera"):
		lp.call("kick_camera", 2.5, 0.0, 0.0, 9.0, 0.0, 0.0)


func _cmd(a: PackedStringArray) -> String:
	if a.size() > 0 and a[0] == "capsule":   # T-274
		if not Net.is_authority():
			return "the host runs the shower"
		capsule_incoming()
		return "a supply capsule is coming down in the yard"
	if a.size() > 0 and a[0] == "now":
		if not Net.is_authority():
			return "the host runs the shower"
		begin()
		return "the relay warns: a meteor shower in %.0f s" % float(cfg.get("warn_seconds", 10.0))
	return "meteor shower: %s, %.0f s left, %d impacts, %d kills, %d showers" % ["running" if active else "idle", maxf(0.0, left), impacts, kills, showers]
