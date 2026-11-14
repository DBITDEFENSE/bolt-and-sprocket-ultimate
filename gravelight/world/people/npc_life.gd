class_name NpcLife
extends Node3D
## T-246 (the owner, 2026-11-14: "MAKE ALL THE NPCS FEEL MORE ALIVE"): the small life every standing NPC shares,
## added under its body (PatronBody: the extra people, the opening's patrons, the survivors; RemoteBody while a
## companion or Jakub waits). The body asks it each pose frame and blends what it says over its own pose:
##   - look: the head (and a little of the chest) turns to the nearest human within LOOK_M, to a zombie within
##     ZOMBIE_M (that wins), to a gunshot or an explosion for a moment, else a slow glance around now and then;
##     past ~60 degrees the whole body turns toward a human who stands close (turn_yaw, visual only);
##   - idle: one of the body's idles at a time (warm: rubbing the hands in the cold and breathing into them,
##     hug: arms wrapped round in the cold / folded, adjust: a hand to the head, look: a scan round), with pauses;
##     a weight shift from one hip to the other and breathing all the time;
##   - startle: a shot within STARTLE_M or an explosion near: a jolt back, the hands come up, the head turns to it;
##   - hands_up: a human aims at them from AIM_M with the sights up: the hands go up (and the face shows fear);
##   - back: a human closer than CLOSE_M: half a step back (visual, at most BACK_M);
##   - breath fog in the cold (the map's frost_edges block outside its warm zones): a puff from the mouth every
##     few seconds.
## Cost: the world is read four times a second (staggered per NPC) and only while the camera is within ACTIVE_M;
## no raycasts. Presentation only: no collider, prompt, timing or position of anything gameplay moves.

const SCAN_S: float = 0.25
const ACTIVE_M: float = 32.0
const LOOK_M: float = 7.5
const ZOMBIE_M: float = 11.0
const CLOSE_M: float = 1.2
const BACK_M: float = 0.28
const AIM_M: float = 14.0
const AIM_COS: float = 0.993        # about 6.8 degrees off the barrel
const STARTLE_M: float = 12.0
const MAX_YAW: float = 1.15         # the head and chest together
const MAX_PITCH: float = 0.45
const TURN_FROM: float = 0.95       # a human further round than this (radians): the body turns too
const IDLES_COLD: Array[StringName] = [&"warm", &"hug", &"look", &"adjust"]
const IDLES_WARM: Array[StringName] = [&"look", &"adjust", &"hug"]

## The outputs (radians / 0..1), read by the body each pose frame.
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var turn_yaw: float = 0.0
var idle: StringName = &""
var idle_k: float = 0.0
var shift: float = 0.0              # -1 left hip .. +1 right hip
var breath: float = 0.0             # 0..1, the chest's breath cycle
var startle: float = 0.0
var hands_up: float = 0.0
var back: Vector3 = Vector3.ZERO    # body-local offset (x, z) away from a human too close
var cold: bool = false
var asleep: bool = false
## Settable by the owner: no idles (a pose that has its own hands: sitting, working, aiming, cowering).
var busy: bool = false
## Tests / tools.
var events: PackedStringArray = []
var breaths: int = 0
var idles: Array[StringName] = []

var map: Node = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _scan_t: float = 0.0
var _want_yaw: float = 0.0
var _want_pitch: float = 0.0
var _want_turn: float = 0.0
var _glance_t: float = 3.0
var _glance_yaw: float = 0.0
var _glance_left: float = 0.0
var _noise_at: Vector3 = Vector3.INF
var _noise_t: float = 0.0
var _idle_t: float = 0.0
var _idle_len: float = 4.0
var _last_idle: StringName = &""
var _shift_t: float = 0.0
var _shift_want: float = 0.0
var _breath_ph: float = 0.0
var _puff_t: float = 2.0
var _puff_on: float = 0.0
var _aimed: bool = false
var _near_human: Node3D = null
var _want_back: Vector3 = Vector3.ZERO
var _fog: GPUParticles3D = null
var _head: Node3D = null
var _own_idles: bool = false
var _cold_at: Vector3 = Vector3.ZERO   # where the cold was last read (re-read once the body has moved 3 m)
static var _fog_mat: ParticleProcessMaterial = null
static var _fog_mesh: QuadMesh = null


## Adds the life under `body` (its local -Z forward). `head`: the node the breath leaves from (a bone attachment or
## the puppet's head node); `seed_key` keeps every NPC on its own rhythm.
static func attach(body: Node3D, head: Node3D, seed_key: String, idle_set: Array[StringName] = []) -> NpcLife:
	var l: NpcLife = NpcLife.new()
	l.name = "Life"
	l._rng.seed = hash("life_" + seed_key)
	l._scan_t = l._rng.randf_range(0.0, SCAN_S)
	l._glance_t = l._rng.randf_range(2.0, 6.0)
	l._idle_t = -l._rng.randf_range(1.0, 5.0)
	l._breath_ph = l._rng.randf_range(0.0, TAU)
	l._shift_t = l._rng.randf_range(2.0, 6.0)
	l._head = head
	body.add_child(l)
	l.map = _find_map(body)
	l.cold = cold_at(body.get_tree(), String(l.map.get("map_id")) if l.map != null else "", body.global_position) if body.is_inside_tree() else false
	l._own_idles = not idle_set.is_empty()
	l.idles = idle_set if l._own_idles else (IDLES_COLD if l.cold else IDLES_WARM)
	l._cold_at = body.global_position if body.is_inside_tree() else Vector3.ZERO
	if l.cold and head != null:
		l._fog = l._make_fog(head)
	if body.is_inside_tree():
		GLBus.weapon_fired.connect(l._on_shot)
		GLBus.explosion.connect(l._on_explosion)
	return l


static func _find_map(n: Node) -> Node:
	var cur: Node = n
	while cur != null:
		if cur is MapRoot:
			return cur
		cur = cur.get_parent()
	return null


## Whether breath shows at `pos` on map `map_id` (pure over the map's ambience file): its horror block has
## frost_edges and the point is not in one of its warm zones nor below its cold_min_y (Kaltenbrunn's depths).
static func cold_at(tree: SceneTree, map_id: String, pos: Vector3) -> bool:
	if map_id.length() < 5:
		return false
	var key: String = map_id.substr(0, 6) if map_id.length() >= 6 and map_id[5] != "_" else map_id.substr(0, 5)
	var path: String = "res://data/gravelight/%s_ambience.json" % key
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return false
	var fe: Dictionary = (GLData.load_json(path).get("horror", {}) as Dictionary).get("frost_edges", {})
	if fe.is_empty():
		return false
	if pos.y < float(fe.get("cold_min_y", -INF)):
		return false
	if tree == null:
		return true
	return not (fe.get("warm_zones", []) as Array).has(String(ZoneVolume.zone_at(tree, pos)))


## The head's turn toward `target` (pure): Vector2(yaw, pitch), body-relative, clamped. `from` is the eye,
## `basis` the body's (its -Z forward); yaw + turns left (Godot's +Y rotation), pitch + looks up.
static func look_angles(from: Vector3, basis: Basis, target: Vector3, max_yaw: float = MAX_YAW, max_pitch: float = MAX_PITCH) -> Vector2:
	var d: Vector3 = basis.orthonormalized().inverse() * (target - from)
	var flat: float = Vector2(d.x, d.z).length()
	if flat < 0.05 and absf(d.y) < 0.05:
		return Vector2.ZERO
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(flat, 0.05))
	return Vector2(clampf(yaw, -max_yaw, max_yaw), clampf(pitch, -max_pitch, max_pitch))


## The raw yaw toward `target` (pure, unclamped), body-relative.
static func yaw_to(from: Vector3, basis: Basis, target: Vector3) -> float:
	var d: Vector3 = basis.orthonormalized().inverse() * (target - from)
	return atan2(-d.x, -d.z)


## Whether a gun at `eye` pointing along `fwd` is aimed at a person standing at `at` (feet), pure: within `max_m`
## and the chest (1.2 m up) within the cone.
static func aimed_at(eye: Vector3, fwd: Vector3, at: Vector3, max_m: float = AIM_M, cos_min: float = AIM_COS) -> bool:
	var to: Vector3 = at + Vector3.UP * 1.2 - eye
	var d: float = to.length()
	if d > max_m or d < 0.3:
		return false
	return fwd.normalized().dot(to / d) >= cos_min


## The next idle (pure over a roll 0..1): never the same one twice running when there is a choice.
static func pick_idle(roll: float, set_: Array[StringName], last: StringName) -> StringName:
	if set_.is_empty():
		return &""
	var pool: Array[StringName] = set_.filter(func(s: StringName) -> bool: return s != last)
	if pool.is_empty():
		pool = set_
	return pool[clampi(int(roll * float(pool.size())), 0, pool.size() - 1)]


func _on_shot(_p: int, _w: StringName, _u: bool, origin: Vector3, _d: Vector3) -> void:
	if asleep or not is_inside_tree():
		return
	var at: Vector3 = global_position
	var dist: float = origin.distance_to(at)
	if dist > STARTLE_M:
		return
	startle = maxf(startle, clampf(1.2 - dist / STARTLE_M, 0.35, 1.0))
	_noise_at = origin
	_noise_t = 1.6
	events.append("startle")


func _on_explosion(pos: Vector3, radius: float) -> void:
	if asleep or not is_inside_tree():
		return
	var dist: float = pos.distance_to(global_position)
	if dist > radius + STARTLE_M * 1.5:
		return
	startle = 1.0
	_noise_at = pos
	_noise_t = 2.2
	events.append("explosion")


## One pose frame. `body` is the owner (its global basis gives the facing); `eye_h` the eye height over its feet.
func tick(delta: float, body: Node3D, eye_h: float = 1.55) -> void:
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_S
		_scan(body, eye_h)
	if asleep:
		_ease(delta, 2.0)
		return
	# a noise wins the look for a moment, then a zombie / human (from the scan), else a glance around
	_noise_t = maxf(0.0, _noise_t - delta)
	startle = move_toward(startle, 0.0, delta * 1.4)
	if _noise_t > 0.0 and _noise_at != Vector3.INF:
		var a: Vector2 = look_angles(body.global_position + Vector3.UP * eye_h, body.global_basis, _noise_at)
		_want_yaw = a.x
		_want_pitch = a.y
	elif _near_human == null and not _zombie_seen:
		_glance_t -= delta
		if _glance_t <= 0.0:
			_glance_t = _rng.randf_range(3.5, 8.0)
			_glance_yaw = _rng.randf_range(-0.9, 0.9)
			_glance_left = _rng.randf_range(1.2, 2.4)
		_glance_left = maxf(0.0, _glance_left - delta)
		var scan: float = sin(Time.get_ticks_msec() * 0.0011) * 0.75 if idle == &"look" else 0.0
		_want_yaw = lerpf(scan, _glance_yaw, 1.0 if _glance_left > 0.0 else 0.0)
		_want_pitch = 0.0
		_want_turn = 0.0
	var k: float = clampf(delta * (7.0 if _noise_t > 0.0 else 3.2), 0.0, 1.0)
	look_yaw = lerpf(look_yaw, _want_yaw, k)
	look_pitch = lerpf(look_pitch, _want_pitch, k)
	turn_yaw = lerp_angle(turn_yaw, _want_turn, clampf(delta * 1.6, 0.0, 1.0))
	hands_up = move_toward(hands_up, 1.0 if _aimed else 0.0, delta * (4.0 if _aimed else 1.5))
	back = back.lerp(_want_back, clampf(delta * 3.0, 0.0, 1.0))
	# idles: one at a time, with pauses; none while busy, startled or aimed at
	var can_idle: bool = not busy and hands_up < 0.05 and startle < 0.2 and _near_human == null and not _zombie_seen
	_idle_t += delta
	if idle == &"":
		if can_idle and _idle_t >= 0.0:
			idle = pick_idle(_rng.randf(), idles, _last_idle)
			_last_idle = idle
			_idle_len = _rng.randf_range(3.5, 6.5)
			_idle_t = 0.0
			events.append("idle:" + String(idle))
	var idle_on: bool = idle != &"" and _idle_t < _idle_len and can_idle
	idle_k = move_toward(idle_k, 1.0 if idle_on else 0.0, delta * 2.2)
	if idle != &"" and not idle_on and idle_k <= 0.0:
		idle = &""   # it has eased out: a pause before the next
		_idle_t = -_rng.randf_range(2.5, 6.0)
	# the weight moves from hip to hip now and then; the breath goes on
	_shift_t -= delta
	if _shift_t <= 0.0:
		_shift_t = _rng.randf_range(4.0, 9.0)
		_shift_want = -_shift_want if absf(_shift_want) > 0.1 else (1.0 if _rng.randf() < 0.5 else -1.0)
	shift = move_toward(shift, _shift_want * (1.0 - hands_up), delta * 0.8)
	var rate: float = 1.35 + 1.6 * startle + 1.2 * hands_up
	_breath_ph = fmod(_breath_ph + delta * rate, TAU)
	breath = 0.5 - 0.5 * cos(_breath_ph)
	_tick_fog(delta)


var _zombie_seen: bool = false


func _scan(body: Node3D, eye_h: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	asleep = cam != null and cam.global_position.distance_squared_to(body.global_position) > ACTIVE_M * ACTIVE_M
	if asleep:
		_near_human = null
		_aimed = false
		_want_back = Vector3.ZERO
		return
	var feet: Vector3 = body.global_position
	var eye: Vector3 = feet + Vector3.UP * eye_h
	if feet.distance_squared_to(_cold_at) > 9.0:
		# moved (a patron fled out into the snow, a survivor came down): is it cold here?
		_cold_at = feet
		cold = cold_at(get_tree(), String(map.get("map_id")) if map != null else "", feet)
		if not _own_idles:
			idles = IDLES_COLD if cold else IDLES_WARM
		if cold and _fog == null and _head != null and is_instance_valid(_head):
			_fog = _make_fog(_head)
		elif not cold and _fog != null:
			_fog.emitting = false
	# a zombie close by wins the look
	_zombie_seen = false
	var zd: float = ZOMBIE_M * ZOMBIE_M
	var zat: Vector3 = Vector3.INF
	if map != null and map.get("director") != null:
		for z: Variant in (map.get("director") as Object).call("active_zombies"):
			if not is_instance_valid(z):
				continue
			var d2: float = (z as Node3D).global_position.distance_squared_to(feet)
			if d2 < zd:
				zd = d2
				zat = (z as Node3D).global_position + Vector3.UP * 1.4
	# the nearest human (not a bot), aimed or close
	_near_human = null
	_aimed = false
	_want_back = Vector3.ZERO
	var hd: float = LOOK_M * LOOK_M
	var humans: Array = []
	if map != null and map.get("players") is Dictionary:
		humans = (map.get("players") as Dictionary).values()
	for h: Variant in humans:
		var p: Player = h as Player
		if p == null or not is_instance_valid(p) or p.is_bot or p.downed:
			continue
		var d2h: float = p.global_position.distance_squared_to(feet)
		if p.camera != null and p.weapons != null and p.weapons.ads_t > 0.5 \
				and aimed_at(p.camera.global_position, -p.camera.global_basis.z, feet):
			_aimed = true
		if d2h < hd:
			hd = d2h
			_near_human = p
	if zat != Vector3.INF:
		_zombie_seen = true
		var az: Vector2 = look_angles(eye, body.global_basis, zat)
		if _noise_t <= 0.0:
			_want_yaw = az.x
			_want_pitch = az.y
		_want_turn = 0.0
		return
	if _near_human != null:
		var target: Vector3 = _near_human.global_position + Vector3.UP * 1.55
		if _near_human is Player and (_near_human as Player).camera != null:
			target = (_near_human as Player).camera.global_position
		var raw: float = yaw_to(eye, body.global_basis, target)
		# far round: the body turns toward them (the head takes the rest)
		if absf(raw - turn_yaw) > TURN_FROM:
			_want_turn = clampf(raw, -PI * 0.6, PI * 0.6)
		var a: Vector2 = look_angles(eye, body.global_basis.rotated(Vector3.UP, turn_yaw), target)
		if _noise_t <= 0.0:
			_want_yaw = a.x
			_want_pitch = a.y
		if hd < CLOSE_M * CLOSE_M:
			var away: Vector3 = body.global_basis.orthonormalized().inverse() * (feet - _near_human.global_position)
			away.y = 0.0
			if away.length() > 0.01:
				_want_back = away.normalized() * BACK_M * clampf(1.0 - sqrt(hd) / CLOSE_M + 0.4, 0.0, 1.0)
	else:
		_want_turn = 0.0


func _ease(delta: float, rate: float) -> void:
	var k: float = clampf(delta * rate, 0.0, 1.0)
	look_yaw = lerpf(look_yaw, 0.0, k)
	look_pitch = lerpf(look_pitch, 0.0, k)
	idle_k = move_toward(idle_k, 0.0, delta)
	hands_up = move_toward(hands_up, 0.0, delta)
	back = back.lerp(Vector3.ZERO, k)
	startle = move_toward(startle, 0.0, delta)


# ================================================================== breath fog in the cold

func _make_fog(head: Node3D) -> GPUParticles3D:
	if _fog_mat == null:
		_fog_mat = ParticleProcessMaterial.new()
		_fog_mat.direction = Vector3(0.0, 0.25, -1.0)
		_fog_mat.spread = 14.0
		_fog_mat.initial_velocity_min = 0.25
		_fog_mat.initial_velocity_max = 0.45
		_fog_mat.gravity = Vector3(0, 0.12, 0)
		_fog_mat.damping_min = 0.4
		_fog_mat.damping_max = 0.8
		_fog_mat.scale_min = 0.5
		_fog_mat.scale_max = 1.0
		var curve: Curve = Curve.new()
		curve.add_point(Vector2(0.0, 0.35))
		curve.add_point(Vector2(1.0, 1.6))
		var ct: CurveTexture = CurveTexture.new()
		ct.curve = curve
		_fog_mat.scale_curve = ct
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.0))
		ramp.add_point(0.2, Color(1, 1, 1, 1.0))
		ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
		var gt: GradientTexture1D = GradientTexture1D.new()
		gt.gradient = ramp
		_fog_mat.color_ramp = gt
		_fog_mat.color = Color(0.86, 0.9, 0.96, 0.32)
		_fog_mesh = QuadMesh.new()
		_fog_mesh.size = Vector2(0.12, 0.12)
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _soft_dot()
		_fog_mesh.material = m
	var e: GPUParticles3D = GPUParticles3D.new()
	e.name = "BreathFog"
	e.amount = 6
	e.lifetime = 1.3
	e.one_shot = false
	e.emitting = false
	e.local_coords = false
	e.explosiveness = 0.0
	e.process_material = _fog_mat
	e.draw_pass_1 = _fog_mesh
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-1, -1, -2), Vector3(2, 2, 3))
	e.position = Vector3(0.0, 0.06, -0.12)
	head.add_child(e)
	return e


static func _soft_dot() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t


func _tick_fog(delta: float) -> void:
	if not cold:
		return
	if _puff_on > 0.0:
		_puff_on -= delta
		if _puff_on <= 0.0 and _fog != null:
			_fog.emitting = false
		return
	_puff_t -= delta
	if _puff_t <= 0.0:
		_puff_t = _rng.randf_range(2.6, 4.2) / (1.0 + startle + hands_up)
		_puff_on = 0.45 if idle != &"warm" else 0.7
		breaths += 1
		if _fog != null:
			_fog.emitting = true


## The idle's hand targets in the chest's space (the puppet's chest node: +Y up its spine, -Z forward), for the
## bodies whose hands are free: [left, right] or [] when this idle leaves the hands where they were. `t` = seconds.
static func idle_hands(kind: StringName, t: float, chest_up: float = 0.0) -> Array:
	match kind:
		&"warm":   # the hands together under the chin, rubbing, now and then breathed into
			var rub: float = 0.018 * sin(t * 9.0)
			var lift: float = 0.05 * clampf(sin(t * 0.8) * 2.0 - 1.0, 0.0, 1.0)
			return [Vector3(-0.04 + rub, 0.34 + chest_up + lift, -0.17), Vector3(0.04 - rub, 0.34 + chest_up + lift, -0.17)]
		&"hug":    # arms wrapped round in the cold (folded where it is warm)
			return [Vector3(0.12, 0.12 + chest_up, -0.17), Vector3(-0.12, 0.15 + chest_up, -0.15)]
		&"adjust": # a hand to the hair or the scarf, then back
			var up: float = clampf(sin(t * 1.1) * 1.6, 0.0, 1.0)
			return [null, Vector3(0.1, lerpf(0.0, 0.5, up) + chest_up, lerpf(-0.05, -0.12, up))]
	return []
