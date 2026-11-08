class_name KranichAir
extends Node3D
## How der Kranich FEELS in flight (T-220, the owner's plane pass on Fernflug Act II; data/gravelight/map04b_plane.json
## "air"). Presentation only, local on every peer, no gameplay state; never moves a collider, the navmesh or a body.
##   exposure      how exposed the listener is: 0 inside .. 1 out on the wing walk (audio zones from data boxes, plus
##                 the live openings: the bay doors hanging open, a blown or torn breach panel, a decompression). It
##                 drives two loops on the Ambience bus: the wind roar and the impellers heard from outside
##                 (louder near the port nozzles). The engine drone everywhere is the map's own base bed.
##   turbulence    rare small events (every_s, only in a quiet moment, never in a boss fight, a cutscene, an egg
##                 holdout, a tilt, a decompression or the bomb run, not with the dead close or just after a hit): a
##                 light camera shake (CameraSway: the comfort setting scales it, Off removes it), a rattle, the
##                 airframe's groan, the nearby lamps flickering, the hangings and the canvas jolted
##   bank          the sky, the cloud sheets, the far deck and the key light bank a few degrees and recover (the world
##                 moves; the floor and the camera never do); paused while a KranichTilt rolls the deck
##   sun           the key light swings from the moon to the low sun behind the wing as the act's dawn rises
##   cloud banks   now and then a cloud bank streams through and over the wing: soft billboard puffs and a fog volume
## Pure rules are static (exposure_at, is_quiet, bank_deg_at, sun_mix, sun_dir) for the tests.

const DATA: String = "res://data/gravelight/map04b_plane.json"
const PUFF_SHADER: String = "res://gravelight/world/map04/cloud_puff.gdshader"

var cfg: Dictionary = {}
var exposure: float = 0.0
var events_done: int = 0
var events_skipped: int = 0
var bank_deg: float = 0.0
var flight_t: float = 0.0
var next_event_t: float = 60.0
var banks_seen: int = 0
var dawn_override: float = -1.0   # preview_dawn (captures)
## the perf A/B (perf_marks --no-plane): no audio, no events, no bank
static var disabled: bool = false
var _wait_t: float = 0.0
var _wind: AudioStreamPlayer = null
var _engine: AudioStreamPlayer = null
var _sky: Node = null
var _fc: Node = null
var _ext: Node = null
var _moon: DirectionalLight3D = null
var _moon_base: Basis = Basis.IDENTITY
var _bank_k: float = 1.0
var _last_step_t: float = -1000.0
var _last_hurt_t: float = -1000.0
var _flicker: Array = []         # [light, base energy]
var _flicker_t: float = -1.0
var _banks: Array[Dictionary] = []
var _next_bank_t: float = 40.0
var _puff_mat: ShaderMaterial = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _scan_t: float = 0.0
var _engines_x: Array[float] = []


# ---------------------------------------------------------------- pure rules

## The listener's exposure at `p`: the largest of the zone boxes [[lo], [hi], e, fade] (full inside, fading to 0 over
## `fade` m outside) and of the live spheres [centre, radius, e], never below `base`.
static func exposure_at(p: Vector3, boxes: Array, spheres: Array = [], base: float = 0.0) -> float:
	var e: float = base
	for b: Variant in boxes:
		var a: Array = b
		var lo: Array = a[0]
		var hi: Array = a[1]
		var q: Vector3 = Vector3(clampf(p.x, float(lo[0]), float(hi[0])), clampf(p.y, float(lo[1]), float(hi[1])), clampf(p.z, float(lo[2]), float(hi[2])))
		var d: float = q.distance_to(p)
		var fade: float = maxf(0.01, float(a[3]))
		var k: float = 1.0 - clampf(d / fade, 0.0, 1.0)
		e = maxf(e, float(a[2]) * k)
	for s: Variant in spheres:
		var c: Array = s
		var d2: float = (c[0] as Vector3).distance_to(p)
		var k2: float = 1.0 - smoothstep(float(c[1]) * 0.5, float(c[1]), d2)
		e = maxf(e, float(c[2]) * k2)
	return clampf(e, 0.0, 1.0)


## The loudness (dB) of a loop at exposure `e`: db_min .. db_max along e^curve (silent-ish inside, full outside).
static func exposure_db(e: float, db_min: float, db_max: float, curve: float = 1.0) -> float:
	var k: float = pow(clampf(e, 0.0, 1.0), maxf(0.1, curve))
	if k <= 0.0005:
		return db_min
	return maxf(db_min, db_max + linear_to_db(k))


## Is now a quiet moment for a turbulence event? `s` holds what the world is doing (all optional): boss, cutscene,
## holdout, banking, tilt_soon_s, decompression, bomb_run, london, near_zombies, since_hurt_s, since_step_s; `q` the
## data's thresholds.
static func is_quiet(s: Dictionary, q: Dictionary) -> bool:
	for k: String in ["boss", "cutscene", "holdout", "banking", "decompression", "bomb_run", "london", "egg_step"]:
		if bool(s.get(k, false)):
			return false
	if float(s.get("tilt_soon_s", 1.0e9)) < float(q.get("tilt_clear_s", 12.0)):
		return false
	if int(s.get("near_zombies", 0)) > int(q.get("max_near_zombies", 2)):
		return false
	if float(s.get("since_hurt_s", 1.0e9)) < float(q.get("hurt_s", 5.0)):
		return false
	if float(s.get("since_step_s", 1.0e9)) < float(q.get("quiet_after_step_s", 25.0)):
		return false
	return true


## The world's bank (degrees) `t` seconds into the flight: two slow waves (periods_s, weights) at `deg`.
static func bank_deg_at(t: float, b: Dictionary) -> float:
	var deg: float = float(b.get("deg", 2.6))
	var ps: Array = b.get("periods_s", [53.0, 31.0])
	var ws: Array = b.get("weights", [0.62, 0.38])
	var v: float = 0.0
	for i: int in ps.size():
		v += float(ws[i] if i < ws.size() else 0.0) * sin(TAU * t / maxf(1.0, float(ps[i])) + float(i) * 1.3)
	return deg * v


## The sun's share of the key light at the act's sunrise `k` (0 the moon .. 1 the sun).
static func sun_mix(k: float, s: Dictionary) -> float:
	return smoothstep(float(s.get("from_sunrise", 0.35)), float(s.get("to_sunrise", 0.8)), k)


## The direction toward the sun at the act's sunrise `k`: low behind the wing, climbing a little.
static func sun_dir(k: float, s: Dictionary) -> Vector3:
	var a: Array = s.get("dir_from", [0.22, 0.017, -1.0])
	var b: Array = s.get("dir_to", [0.26, 0.12, -1.0])
	var t: float = smoothstep(float(s.get("elev_from_sunrise", 0.5)), 1.0, k)
	return Vector3(lerpf(float(a[0]), float(b[0]), t), lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t)).normalized()


## A DirectionalLight3D basis whose light comes FROM `toward` (the light shines along -Z).
static func light_basis(toward: Vector3) -> Basis:
	var z: Vector3 = toward.normalized()
	var up: Vector3 = Vector3.UP if absf(z.y) < 0.98 else Vector3.FORWARD
	var x: Vector3 = up.cross(z).normalized()
	return Basis(x, z.cross(x).normalized(), z)


# ---------------------------------------------------------------- setup

func _ready() -> void:
	add_to_group(&"kranich_air")
	if disabled:
		set_process(false)
		return
	process_priority = 50   # after MapAmbience (flight_sun) so preview_dawn holds
	_rng.randomize()
	var d: Dictionary = GLData.load_json(DATA)
	cfg = d.get("air", {})
	for x: Variant in (d.get("hull", {}) as Dictionary).get("engines", []):
		_engines_x.append(float(x))
	var tu: Dictionary = cfg.get("turbulence", {})
	var f: Array = tu.get("first_s", [50.0, 90.0])
	next_event_t = _rng.randf_range(float(f[0]), float(f[1]))
	var cb: Dictionary = cfg.get("cloud_banks", {})
	var f2: Array = cb.get("first_s", [25.0, 50.0])
	_next_bank_t = _rng.randf_range(float(f2[0]), float(f2[1]))
	var ex: Dictionary = cfg.get("exposure", {})
	_wind = _loop((ex.get("wind", {}) as Dictionary).get("key", "kranich_wind_roar"))
	_engine = _loop((ex.get("engine", {}) as Dictionary).get("key", "kranich_engine_outside"))
	if not GLBus.player_damaged.is_connected(_on_hurt):
		GLBus.player_damaged.connect(_on_hurt)
	if not GLBus.quest_step_completed.is_connected(_on_step):
		GLBus.quest_step_completed.connect(_on_step)
	var sh: Shader = load(PUFF_SHADER) as Shader
	if sh != null:
		_puff_mat = ShaderMaterial.new()
		_puff_mat.shader = sh


func _exit_tree() -> void:
	for p: AudioStreamPlayer in [_wind, _engine]:
		if p != null and is_instance_valid(p):
			p.stop()
			p.queue_free()
	_wind = null
	_engine = null


## Dev / capture hook ("callv:KranichAir:preview_dawn:0.85"): holds the act's dawn at `k` (the sky's sunrise, the key
## light's colour and energy as MapAmbience's flight_sun would set them, the sun swing) for the rest of the run, so a
## capture can show the end of the act without playing to act round 6. Negative releases it.
func preview_dawn(k: float) -> void:
	dawn_override = k


func _apply_dawn_override() -> void:
	if dawn_override < 0.0 or _sky == null:
		return
	_sky.set("sunrise_hold", dawn_override)
	_sky.call("set_sunrise", dawn_override)
	var amb: Dictionary = (GLData.load_json("res://data/gravelight/map04b_ambience.json") as Dictionary).get("flight_sun", {})
	if _moon != null:
		if not has_meta("moon_col"):
			set_meta("moon_col", _moon.light_color)
			set_meta("moon_e", _moon.light_energy)
		_moon.light_color = (get_meta("moon_col") as Color).lerp(Color(str(amb.get("dawn_color", "#ffb27a"))), dawn_override * 0.7)
		_moon.light_energy = float(get_meta("moon_e")) * lerpf(1.0, float(amb.get("dawn_energy_mult", 1.6)), dawn_override)


func _loop(key: String) -> AudioStreamPlayer:
	if not AudioDirector.has_sound(key):
		return null
	var p: AudioStreamPlayer = AudioDirector.play_2d(key, -60.0, 0.0)
	if p != null:
		p.volume_db = -60.0
	return p


func _on_hurt(pid: int, amount: float) -> void:
	var lp: Node3D = _local_player()
	if amount > 0.0 and lp != null and int(lp.get("player_id")) == pid:
		_last_hurt_t = flight_t


func _on_step(_q: StringName, _s: StringName) -> void:
	_last_step_t = flight_t


func _local_player() -> Node3D:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_local:
			return n as Node3D
	return null


func _rescan() -> void:
	if _sky == null or not is_instance_valid(_sky):
		_sky = get_tree().get_first_node_in_group(&"flight_sky")
	if _fc == null or not is_instance_valid(_fc):
		_fc = get_tree().get_first_node_in_group(&"flight_controller")
	if _ext == null or not is_instance_valid(_ext):
		_ext = get_tree().get_first_node_in_group(&"kranich_exterior")
	if _moon == null or not is_instance_valid(_moon):
		var root: Node = get_parent() if get_parent() != null else get_tree().current_scene
		if root != null:
			var m: Node = root.get_node_or_null("Moon")
			if m is DirectionalLight3D:
				_moon = m as DirectionalLight3D
				_moon_base = _moon.basis


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	flight_t += delta
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 1.0
		_rescan()
	var cam: Camera3D = get_viewport().get_camera_3d()
	var lp: Vector3 = cam.global_position if cam != null else Vector3(0, 1.6, 37)
	_apply_dawn_override()
	_tick_exposure(delta, lp)
	_tick_bank(delta)
	_tick_turbulence(delta)
	_tick_flicker(delta)
	_tick_cloud_banks(delta)


func _live_spheres() -> Array:
	var ex: Dictionary = cfg.get("exposure", {})
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"bay_doors"):
		if bool(n.get("active")):
			var bb: Array = ex.get("bay_box", [[-9, -1, 0], [9, 4.6, 24]])
			var c: Vector3 = (Vector3(float(bb[0][0]), float(bb[0][1]), float(bb[0][2])) + Vector3(float(bb[1][0]), float(bb[1][1]), float(bb[1][2]))) * 0.5
			out.append([c, 14.0, float(ex.get("bay_doors", 0.72))])
	var root: Node = get_parent() if get_parent() != null else get_tree().current_scene
	var gp: Node = root.get_node_or_null("Gameplay") if root != null else null
	if gp != null:
		for c2: Node in gp.get_children():
			if c2 is BreachPanel:
				var bp: BreachPanel = c2 as BreachPanel
				if bp.is_open or bp.torn:
					out.append([bp.global_position + Vector3(0, 1.2, 0), float(ex.get("breach_r", 7.0)), float(ex.get("breach_open", 0.62)) if bp.is_open else float(ex.get("breach_torn", 0.4))])
			elif c2 is DecompressionBreach:
				if int(c2.get("phase")) != 0:
					out.append([(c2 as Node3D).global_position, float(ex.get("decomp_r", 10.0)), float(ex.get("decomp", 0.85))])
	return out


func _tick_exposure(delta: float, lp: Vector3) -> void:
	var ex: Dictionary = cfg.get("exposure", {})
	var target: float = exposure_at(lp, ex.get("boxes", []), _live_spheres(), float(ex.get("base", 0.03)))
	exposure = move_toward(exposure, target, delta / maxf(0.05, float(ex.get("smooth_s", 0.6))))
	if _wind != null and is_instance_valid(_wind):
		var w: Dictionary = ex.get("wind", {})
		_wind.volume_db = exposure_db(exposure, float(w.get("db_min", -48.0)), float(w.get("db_max", -1.0)), float(w.get("curve", 1.4)))
	if _engine != null and is_instance_valid(_engine):
		var en: Dictionary = ex.get("engine", {})
		var db: float = exposure_db(exposure, float(en.get("db_min", -46.0)), float(en.get("db_max", -5.0)), float(en.get("curve", 1.1)))
		# louder by the nozzles (the port pair the walk passes)
		var near: float = 1.0e9
		for x: float in _engines_x:
			near = minf(near, Vector2(lp.x - x, lp.z - 14.0).length())
		var nm: float = float(en.get("near_m", 18.0))
		db += float(en.get("near_db", 4.0)) * (1.0 - clampf(near / nm, 0.0, 1.0)) * exposure
		_engine.volume_db = db


func _tick_bank(delta: float) -> void:
	var bc: Dictionary = cfg.get("bank", {})
	var banking: bool = _fc != null and bool(_fc.get("banking"))
	# the deck's own tilt owns the roll while it runs: the world's slow bank eases out and back in after it
	_bank_k = move_toward(_bank_k, 0.0 if banking else 1.0, delta / maxf(0.1, float(bc.get("ease_s", 3.0))))
	bank_deg = bank_deg_at(flight_t, bc) * _bank_k
	var rad: float = deg_to_rad(bank_deg)
	var sunrise: float = float(_sky.get("sunrise")) if _sky != null else 0.0
	var sc: Dictionary = cfg.get("sun", {})
	var sm: float = sun_mix(sunrise, sc)
	if _sky != null and _sky.has_method("set_bank"):
		_sky.call("set_bank", rad, sm)
	if _moon != null:
		var key: Basis = _moon_base
		if sm > 0.0:
			key = Basis(_moon_base.get_rotation_quaternion().slerp(light_basis(sun_dir(sunrise, sc)).get_rotation_quaternion(), sm))
		_moon.basis = Basis(Vector3(0, 0, 1), rad) * key


# ---------------------------------------------------------------- turbulence

func _world_state(p: Node3D) -> Dictionary:
	var s: Dictionary = {}
	for b: Node in get_tree().get_nodes_in_group(&"homage_bosses"):
		if is_instance_valid(b) and b.is_inside_tree() and (not b.has_method("is_active") or bool(b.call("is_active"))):
			s["boss"] = true
	s["cutscene"] = GameState.has_flag(&"cutscene")
	s["holdout"] = not (QuestManager.get("_holdouts") as Dictionary).is_empty() if QuestManager.get("_holdouts") is Dictionary else false
	if _fc != null:
		s["banking"] = bool(_fc.get("banking"))
		s["bomb_run"] = bool(_fc.get("run_on"))
		var tt: Variant = _fc.get("tilt_times")
		var clock: float = float(_fc.get("round_clock")) if _fc.get("round_clock") != null else 0.0
		var soon: float = 1.0e9
		if tt is Array:
			for t: Variant in tt:
				if float(t) >= clock:
					soon = minf(soon, float(t) - clock)
		s["tilt_soon_s"] = soon
	var root: Node = get_parent() if get_parent() != null else get_tree().current_scene
	if root != null:
		for c: Node in root.get_children():
			if c is LondonWindow:
				s["london"] = true
		var gp: Node = root.get_node_or_null("Gameplay")
		if gp != null:
			for c2: Node in gp.get_children():
				if c2 is DecompressionBreach and int(c2.get("phase")) != 0:
					s["decompression"] = true
	var near: int = 0
	var dir: Node = root.get("director") if root != null and "director" in root else null
	if dir != null and p != null and dir.has_method("active_zombies"):
		var nm: float = float(((cfg.get("turbulence", {}) as Dictionary).get("quiet", {}) as Dictionary).get("near_m", 12.0))
		for z: Node in dir.call("active_zombies"):
			if is_instance_valid(z) and (z as Node3D).global_position.distance_to(p.global_position) < nm:
				near += 1
	s["near_zombies"] = near
	s["since_hurt_s"] = flight_t - _last_hurt_t
	s["since_step_s"] = flight_t - _last_step_t
	return s


func _tick_turbulence(delta: float) -> void:
	var tu: Dictionary = cfg.get("turbulence", {})
	if flight_t < next_event_t:
		return
	var p: Node3D = _local_player()
	if is_quiet(_world_state(p), tu.get("quiet", {})):
		event_now()
		_wait_t = 0.0
		var ev: Array = tu.get("every_s", [70.0, 150.0])
		next_event_t = flight_t + _rng.randf_range(float(ev[0]), float(ev[1]))
		return
	# not now: look again in a few seconds; past give_up_s the event is skipped and the next one scheduled
	_wait_t += float(tu.get("retry_s", 6.0))
	if _wait_t > float(tu.get("give_up_s", 45.0)):
		_wait_t = 0.0
		events_skipped += 1
		var ev2: Array = tu.get("every_s", [70.0, 150.0])
		next_event_t = flight_t + _rng.randf_range(float(ev2[0]), float(ev2[1]))
	else:
		next_event_t = flight_t + float(tu.get("retry_s", 6.0))


## One turbulence event, now (dev console / capture hook "call:KranichAir:event_now"): the shake, the rattle, the
## groan, the flicker, the jolt through the hangings and the canvas.
func event_now() -> void:
	var tu: Dictionary = cfg.get("turbulence", {})
	events_done += 1
	var p: Node3D = _local_player()
	CameraSway.shake(p, float(tu.get("shake", 0.14)))
	var g: String = str(tu.get("groan", "kranich_groan"))
	if not AudioDirector.has_sound(g):
		g = "kranich_creak"
	if AudioDirector.has_sound(g):
		AudioDirector.play_2d(g, float(tu.get("groan_db", -3.0)), 0.0)
	var r: String = str(tu.get("rattle", "kranich_rattle"))
	if AudioDirector.has_sound(r):
		AudioDirector.play_2d(r, float(tu.get("rattle_db", -7.0)), 0.0)
	if _sky != null and _sky.has_method("nudge"):
		_sky.call("nudge", float(tu.get("nudge_rad_s", 0.35)))
	if _ext != null and _ext.has_method("gust_now"):
		_ext.call("gust_now", 1.0)
	# the lamps near the listener flicker
	_flicker.clear()
	var at: Vector3 = p.global_position if p != null else Vector3(0, 1.6, 37)
	var fm: float = float(tu.get("flicker_m", 16.0))
	var root: Node = get_parent() if get_parent() != null else get_tree().current_scene
	if root != null:
		for n: Node in root.find_children("*", "OmniLight3D", true, false):
			var l: OmniLight3D = n as OmniLight3D
			if l.visible and l.light_energy > 0.01 and l.global_position.distance_to(at) < fm:
				_flicker.append([l, l.light_energy])
	_flicker_t = 0.0


func _tick_flicker(delta: float) -> void:
	if _flicker_t < 0.0:
		return
	_flicker_t += delta
	var curve: Array = (cfg.get("turbulence", {}) as Dictionary).get("flicker", [[0.0, 1.0], [0.42, 1.0]])
	var k: float = 1.0
	var done: bool = true
	for i: int in curve.size():
		var a: Array = curve[i]
		if _flicker_t <= float(a[0]):
			var prev: Array = curve[maxi(0, i - 1)]
			var span: float = maxf(0.001, float(a[0]) - float(prev[0]))
			k = lerpf(float(prev[1]), float(a[1]), clampf((_flicker_t - float(prev[0])) / span, 0.0, 1.0))
			done = false
			break
	for f: Array in _flicker:
		var l: OmniLight3D = f[0] as OmniLight3D
		if is_instance_valid(l):
			l.light_energy = float(f[1]) * (1.0 if done else k)
	if done:
		_flicker.clear()
		_flicker_t = -1.0


# ---------------------------------------------------------------- cloud banks

## A cloud bank, now (dev console / capture hook "call:KranichAir:cloud_bank_now"): `at_z` puts it already that far
## along (the capture's mid-pass).
func cloud_bank_now(at_z: float = 1.0e9, at_x: float = 1.0e9) -> void:
	var cb: Dictionary = cfg.get("cloud_banks", {})
	var node: Node3D = Node3D.new()
	node.name = "CloudBank%d" % banks_seen
	add_child(node)
	var xr: Array = cb.get("x", [-125.0, 40.0])
	var yr: Array = cb.get("y", [-4.0, 12.0])
	var c: Vector3 = Vector3(_rng.randf_range(float(xr[0]), float(xr[1])), _rng.randf_range(float(yr[0]), float(yr[1])), float(cb.get("from_z", 300.0)))
	if at_x < 1.0e8:
		c.x = at_x
	if at_z < 1.0e8:
		c.z = at_z
	node.position = c
	var sp: Array = cb.get("spread", [44.0, 9.0, 40.0])
	var sz: Array = cb.get("puff_size", [20.0, 42.0])
	var np: Array = cb.get("puffs", [9, 14])
	if _puff_mat != null:
		for i: int in _rng.randi_range(int(np[0]), int(np[1])):
			var q: MeshInstance3D = MeshInstance3D.new()
			var qm: QuadMesh = QuadMesh.new()
			var s: float = _rng.randf_range(float(sz[0]), float(sz[1]))
			qm.size = Vector2(s, s * 0.62)
			q.mesh = qm
			var m: ShaderMaterial = _puff_mat.duplicate() as ShaderMaterial
			m.set_shader_parameter("seed", _rng.randf() * 100.0)
			m.set_shader_parameter("dawn", float(_sky.get("sunrise")) if _sky != null else 0.0)
			q.material_override = m
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			q.position = Vector3(_rng.randf_range(-1, 1) * float(sp[0]), _rng.randf_range(-1, 1) * float(sp[1]), _rng.randf_range(-1, 1) * float(sp[2]))
			node.add_child(q)
	var fv: FogVolume = FogVolume.new()
	var fs: Array = cb.get("fog", [62.0, 16.0, 48.0])
	fv.size = Vector3(float(fs[0]), float(fs[1]), float(fs[2]))
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var fmat: FogMaterial = FogMaterial.new()
	fmat.density = float(cb.get("fog_density", 0.035))
	fmat.albedo = Color(0.62, 0.66, 0.74)
	fmat.edge_fade = 0.6
	fv.material = fmat
	node.add_child(fv)
	_banks.append({"node": node, "speed": float(cb.get("speed", 46.0)), "to_z": float(cb.get("to_z", -240.0))})
	banks_seen += 1


func _tick_cloud_banks(delta: float) -> void:
	var cb: Dictionary = cfg.get("cloud_banks", {})
	if cb.is_empty():
		return
	if flight_t >= _next_bank_t and not (_sky != null and bool(_sky.get("desert"))):
		cloud_bank_now()
		var ev: Array = cb.get("every_s", [55.0, 120.0])
		_next_bank_t = flight_t + _rng.randf_range(float(ev[0]), float(ev[1]))
	var rot: Basis = Basis(Vector3(0, 0, 1), deg_to_rad(bank_deg))
	for b: Dictionary in _banks.duplicate():
		var n: Node3D = b["node"] as Node3D
		if not is_instance_valid(n):
			_banks.erase(b)
			continue
		n.position.z -= float(b["speed"]) * delta
		n.basis = rot
		if n.position.z < float(b["to_z"]):
			n.queue_free()
			_banks.erase(b)
