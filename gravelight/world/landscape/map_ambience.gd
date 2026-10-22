class_name MapAmbience
extends Node3D
## Map 0's living world (Update 02 section 7, DECISIONS T-052): the sky events, the distant war and the ambient life
## around the inn, all from data/gravelight/map00_ambience.json, all presentation (nothing here changes gameplay,
## so each co-op peer runs its own; the squad's reaction lines are local VO).
##
##   sky      bomber streams droning over every 2-4 min; low fighter pairs with tracer; once per match from round 6 a
##            plane is hit and goes down trailing smoke behind the hills, then the crash flash and the delayed boom
##            and a squad line; searchlights sweeping the cloud deck (the spot where each beam hits shows on it)
##   war      artillery flashes along the eastern horizon with the boom delayed by distance (~2.9 s/km), rumble,
##            a small camera shake and the inn's lanterns swinging when it is close; flak tracer arcs over the far
##            hills; parachute flares drifting down lighting the snow white or red; a far machine gun; the burning
##            town's glow. Intensity rises with the round (the war getting closer).
##   life     wind gusts (snow blown off the roofs, the snowfall pushed sideways, the inn sign creaking, the hayloft
##            door banging), crows on the wires that scatter at the first shots, a far dog that stops at round 10,
##            the church bell at midnight (round 9), chimney smoke that stops when the Cousins put the fire out,
##            breath fog in the cold, frost creeping over the windows, the farmhouse light going out at round 8,
##            the wreck's ammunition cooking off, and Dutch's line about the empty pilot's seat.
## The pure rules (intensity, delays, thresholds) are static so the unit tests can check them.

const FLASH_SLOTS: int = 8

@export var config_path: String = "res://data/gravelight/map00_ambience.json"

var cfg: Dictionary = {}
var land: Landscape
var round_now: int = 0
var intensity: float = 0.0
var fire_out: bool = false
var plane_down_done: bool = false
var pilot_said: bool = false
var bell_rung: bool = false
var farm_lit: bool = true
var crows: CrowFlock
var breath: BreathFog
var frost: FrostCreep
var sway: LampSway
var flights: Array[SkyFlight] = []
## Counters for the smoke test / dev overlay: event kind -> times it happened this match.
var counts: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timers: Dictionary = {}
var _later: Array = []                  # [seconds left, Callable]
var _t: float = 0.0
var _flashes: Array = []                # {dir, col, amt, decay, spread}
var _flash_light: DirectionalLight3D
var _flash_light_e: float = 0.0
var _beams: Array = []                  # {mi, base, bearing, phase, speed, mat}
var _aa: Array[GPUParticles3D] = []
var _aa_off: Array[float] = []
var _flares: Array = []                 # {node, light, glow, t, burn, energy, drift}
var _glows: Array = []                  # pooled horizon flash sprites: {mi, mat, t, life, energy, col}
var _wind: float = 0.25
var _gust: float = 0.0
var _gust_secs: float = 0.0
var _sign_a: float = 0.0
var _sign_v: float = 0.0
var _sign_creak_cd: float = 0.0
var _door_a: float = 0.0
var _door_v: float = 0.0
var _door_cd: float = 0.0
var _load_t: float = 0.0
var _fire_light: Light3D
var _fire_base: float = 0.0
var _chimney: GPUParticles3D
var _snow_pms: Array[ParticleProcessMaterial] = []
var _spindrift: Array[GPUParticles3D] = []
var _cook_light: OmniLight3D
var _sparks: GPUParticles3D
var _pilot_check: float = 0.0
var _setup_done: bool = false
var _sky_dirty: bool = true


func _ready() -> void:
	cfg = GLData.load_json(config_path)
	_rng.randomize()
	_setup.call_deferred()


# ================================================================== pure rules (unit-tested)

## How far the war has come, 0..1, at round `r`.
static func intensity_for(r: int, c: Dictionary) -> float:
	var i: Dictionary = c.get("intensity", {})
	var a: float = float(i.get("start_round", 1))
	var b: float = float(i.get("full_round", 15))
	return clampf((float(r) - a) / maxf(1.0, b - a), 0.0, 1.0)


## Seconds between a flash `km` away and its sound (the speed of sound, ~2.9 s per km).
static func boom_delay(km: float, c: Dictionary) -> float:
	return maxf(0.0, km) * float((c.get("artillery", {}) as Dictionary).get("seconds_per_km", 2.9))


## The [min, max] wait before the next event of a section at intensity `k`.
static func interval_range(section: Dictionary, k: float) -> Vector2:
	var a: Array = section.get("interval", [60, 120])
	var b: Array = section.get("interval_late", a)
	return Vector2(lerpf(float(a[0]), float(b[0]), k), lerpf(float(a[1]), float(b[1]), k))


## The [min, max] distance (km) of the artillery at intensity `k`: it closes in as the night goes on.
static func artillery_km_range(c: Dictionary, k: float) -> Vector2:
	var a: Dictionary = c.get("artillery", {})
	var e: Array = a.get("km", [5.5, 9.0])
	var l: Array = a.get("km_late", e)
	return Vector2(lerpf(float(e[0]), float(l[0]), k), lerpf(float(e[1]), float(l[1]), k))


static func farm_lit_at(r: int, c: Dictionary) -> bool:
	return r < int((c.get("farm_light", {}) as Dictionary).get("off_round", 8))


static func dog_barks_at(r: int, c: Dictionary) -> bool:
	return r < int((c.get("dog", {}) as Dictionary).get("stop_round", 10))


static func plane_down_allowed(r: int, done: bool, c: Dictionary) -> bool:
	return not done and r >= int((c.get("plane_down", {}) as Dictionary).get("min_round", 6))


## True when the hearth's light has sunk below the configured share of its base (the Cousins Round's setup).
static func hearth_out(energy: float, base: float, c: Dictionary) -> bool:
	return base > 0.0 and energy < base * float((c.get("chimney", {}) as Dictionary).get("fire_out_fraction", 0.45))


# ================================================================== setup

func _setup() -> void:
	land = Landscape.find(get_tree())
	if land == null or cfg.is_empty():
		return
	_setup_done = true
	GLBus.round_started.connect(_on_round_started)
	GLBus.weapon_fired.connect(_on_weapon_fired)
	GLBus.explosion.connect(_on_explosion)
	_flash_light = DirectionalLight3D.new()
	_flash_light.name = "WarFlash"
	_flash_light.shadow_enabled = false
	_flash_light.light_energy = 0.0
	_flash_light.light_volumetric_fog_energy = 0.3
	_flash_light.visible = false
	add_child(_flash_light)
	_build_searchlights()
	_build_aa()
	_build_glow_pool()
	crows = CrowFlock.new()
	crows.name = "Crows"
	add_child(crows)
	crows.setup(cfg.get("crows", {}), _rng.randi())
	breath = BreathFog.new()
	breath.name = "BreathFog"
	breath.cfg = cfg.get("breath", {})
	add_child(breath)
	frost = FrostCreep.new()
	frost.name = "Frost"
	add_child(frost)
	frost.setup(cfg.get("frost", {}))
	sway = LampSway.new()
	sway.name = "LampSway"
	add_child(sway)
	sway.setup(cfg.get("lamp_sway", {}), get_parent())
	_find_fire_and_chimney()
	_find_snow()
	_build_spindrift()
	_build_cookoff()
	for key: String in ["bombers", "fighters", "artillery", "tracers", "flares", "machine_guns", "gusts", "dog", "cookoff"]:
		var sec: Dictionary = cfg.get(key, {})
		var f: Array = sec.get("first_after", [20, 40])
		_timers[key] = _rng.randf_range(float(f[0]), float(f[1]))
	round_now = maxi(1, RoundManager.current_round)
	intensity = intensity_for(round_now, cfg)
	frost.apply(FrostCreep.frost_at(round_now, cfg.get("frost", {}), false))


func _find_fire_and_chimney() -> void:
	var m: Node = get_parent()
	_fire_light = m.find_child(str((cfg.get("chimney", {}) as Dictionary).get("fire_light", "Hearthfire")), true, false) as Light3D
	if _fire_light != null:
		_fire_base = float(_fire_light.get("base_energy")) if _fire_light.get("base_energy") != null else _fire_light.light_energy
	# the chimney's smoke is the GPUParticles3D gen_map00 puts on the stack (x 12, y 11.6, z 0.5)
	for n: Node in m.find_children("*", "GPUParticles3D", true, false):
		var p: GPUParticles3D = n as GPUParticles3D
		if p.global_position.distance_to(Vector3(12.0, 11.6, 0.5)) < 1.5:
			_chimney = p
			break


func _find_snow() -> void:
	var s: Node = get_parent().find_child("Snowfall", false, false)
	if s == null:
		return
	for c: Node in s.get_children():
		var p: GPUParticles3D = c as GPUParticles3D
		if p != null and p.process_material is ParticleProcessMaterial:
			_snow_pms.append(p.process_material as ParticleProcessMaterial)


# ================================================================== the loop

func _process(delta: float) -> void:
	if not _setup_done:
		return
	_t += delta
	var r: int = maxi(1, RoundManager.current_round)
	if r != round_now:
		_set_round(r)
	for i: int in range(_later.size() - 1, -1, -1):
		var e: Array = _later[i]
		e[0] = float(e[0]) - delta
		if float(e[0]) <= 0.0:
			_later.remove_at(i)
			(e[1] as Callable).call()
	for key: String in _timers.keys():
		_timers[key] = float(_timers[key]) - delta
		if float(_timers[key]) <= 0.0:
			var iv: Vector2 = interval_range(cfg.get(key, {}), intensity)
			_timers[key] = _rng.randf_range(iv.x, iv.y)
			_fire_event(key)
	_update_flashes(delta)
	_update_beams(delta)
	_update_aa(delta)
	_update_flares(delta)
	_update_glows(delta)
	_update_town()
	_update_wind(delta)
	_update_fire()
	_pilot_check -= delta
	if _pilot_check <= 0.0:
		_pilot_check = 0.5
		_check_pilot_line()
	if _sky_dirty:
		_write_sky()
	if not flights.is_empty():
		_prune_flights()


## Drops flights that have flown off (freed), without touching the freed objects' types.
func _prune_flights() -> void:
	var keep: Array = []
	for f: Variant in flights:
		if is_instance_valid(f):
			keep.append(f)
	if keep.size() != flights.size():
		flights.assign(keep)


func _after(secs: float, fn: Callable) -> void:
	_later.append([secs, fn])


func _count(kind: String) -> void:
	counts[kind] = int(counts.get(kind, 0)) + 1


func _set_round(r: int) -> void:
	round_now = r
	intensity = intensity_for(r, cfg)
	if farm_lit and not farm_lit_at(r, cfg):
		_farm_light_out()


func _on_round_started(r: int, _special: bool) -> void:
	_set_round(maxi(1, r))
	var b: Dictionary = cfg.get("bell", {})
	if not bell_rung and r == int(b.get("round", 9)):
		bell_rung = true
		_after(float(b.get("delay", 22.0)), _ring_midnight)


func _on_explosion(at: Vector3, _radius: float) -> void:
	if crows != null:
		crows.gunfire(at)


func _on_weapon_fired(_pid: int, _w: StringName, _u: bool, origin: Vector3, _d: Vector3) -> void:
	if crows != null:
		crows.gunfire(origin)


func _fire_event(key: String) -> void:
	match key:
		"bombers":
			spawn_bombers()
		"fighters":
			spawn_fighters()
		"artillery":
			_artillery()
		"tracers":
			_tracer_burst()
		"flares":
			if round_now >= int((cfg.get("flares", {}) as Dictionary).get("min_round", 2)):
				spawn_flare()
		"machine_guns":
			_machine_gun()
		"gusts":
			_start_gust()
		"dog":
			_dog()
		"cookoff":
			_cookoff()


# ================================================================== sound out past the pool's range

func _listener() -> Camera3D:
	return get_viewport().get_camera_3d() if get_viewport() != null else null


## Plays `key` from the direction of `world_pos` (a proxy 28 m out along it: the pool's 3D players stop at
## 150 m, and these sources are kilometres away; the files are already distant-sounding).
func far_sound(key: String, world_pos: Vector3, volume_db: float = 0.0) -> void:
	if key == "":
		return
	var cam: Camera3D = _listener()
	if cam == null:
		AudioDirector.play_2d(key, volume_db)
		return
	var d: Vector3 = world_pos - cam.global_position
	if d.length() < 1.0:
		d = Vector3.FORWARD
	AudioDirector.play_3d(key, cam.global_position + d.normalized() * 28.0, volume_db, 0.04)


func _shake(amount: float) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and bool(n.get("is_local")) and not bool(n.get("is_bot")):
			(n as Player).kick_camera(0.0, 0.0, 0.0, 3.0, amount, 0.0)


# ================================================================== the sky: flashes on the cloud deck

## A flash in direction `dir` (from the inn) lighting the clouds: `amt` brightness, `decay` per second,
## `spread` = sharpness (higher = tighter).
func add_flash(dir: Vector3, col: Color, amt: float, decay: float, spread: float) -> void:
	if _flashes.size() >= FLASH_SLOTS:
		_flashes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["amt"]) > float(b["amt"]))
		_flashes.pop_back()
	_flashes.append({"dir": dir.normalized(), "col": col, "amt": amt, "decay": decay, "spread": spread})
	_sky_dirty = true


func _update_flashes(delta: float) -> void:
	if _flashes.is_empty() and _flash_light_e <= 0.0:
		return
	for i: int in range(_flashes.size() - 1, -1, -1):
		var f: Dictionary = _flashes[i]
		f["amt"] = float(f["amt"]) - float(f["decay"]) * delta * maxf(0.3, float(f["amt"]))
		if float(f["amt"]) < 0.01:
			_flashes.remove_at(i)
	_flash_light_e = maxf(0.0, _flash_light_e - delta * 3.5)
	_flash_light.light_energy = _flash_light_e
	_flash_light.visible = _flash_light_e > 0.01
	_sky_dirty = true


func _write_sky() -> void:
	_sky_dirty = false
	if land == null or land.sky_mat == null:
		return
	var fl: PackedVector4Array = PackedVector4Array()
	var fc: PackedVector4Array = PackedVector4Array()
	fl.resize(FLASH_SLOTS)
	fc.resize(FLASH_SLOTS)
	for i: int in mini(_flashes.size(), FLASH_SLOTS):
		var f: Dictionary = _flashes[i]
		var d: Vector3 = f["dir"]
		var c: Color = f["col"]
		fl[i] = Vector4(d.x, d.y, d.z, float(f["amt"]))
		fc[i] = Vector4(c.r, c.g, c.b, float(f["spread"]))
	land.sky_mat.set_shader_parameter("flashes", fl)
	land.sky_mat.set_shader_parameter("flash_cols", fc)
	var bm: PackedVector4Array = PackedVector4Array()
	bm.resize(4)
	var cam: Camera3D = _listener()
	for j: int in mini(_beams.size(), 4):
		var b: Dictionary = _beams[j]
		var mi: MeshInstance3D = b["mi"]
		if cam == null or not mi.visible:
			continue
		var tip: Vector3 = mi.global_transform * Vector3(0, float(b["len"]) * 0.5, 0)
		var d2: Vector3 = (tip - cam.global_position).normalized()
		bm[j] = Vector4(d2.x, d2.y, d2.z, float(b["spot"]))
	land.sky_mat.set_shader_parameter("beams", bm)


# ================================================================== the war

func _artillery() -> void:
	var a: Dictionary = cfg.get("artillery", {})
	var shells: int = 1
	var bc: float = lerpf(float(a.get("barrage_chance", 0.12)), float(a.get("barrage_chance_late", 0.35)), intensity)
	if _rng.randf() < bc:
		var bs: Array = a.get("barrage_shells", [3, 7])
		shells = _rng.randi_range(int(bs[0]), int(bs[1]))
	var br: Array = a.get("bearings", [12, 165])
	var bearing: float = _rng.randf_range(float(br[0]), float(br[1]))
	var kr: Vector2 = artillery_km_range(cfg, intensity)
	var km: float = _rng.randf_range(kr.x, kr.y)
	var at: float = 0.0
	for s: int in shells:
		var b2: float = bearing + _rng.randf_range(-6.0, 6.0)
		var k2: float = maxf(0.8, km + _rng.randf_range(-0.4, 0.4))
		_after(at, func() -> void: shell(b2, k2))
		at += _rng.randf_range(0.25, 1.3)


## One shell landing `km` away on `bearing`: the flash now, the boom when the sound arrives.
func shell(bearing: float, km: float) -> void:
	var a: Dictionary = cfg.get("artillery", {})
	_count("shell")
	var near: float = 1.0 - clampf((km - 1.2) / 8.0, 0.0, 1.0)     # 1 close .. 0 far
	var fr: Array = a.get("flash", [0.5, 1.6])
	var dir: Vector3 = LandscapeTerrain.dir_of(bearing) + Vector3(0, 0.035, 0)
	add_flash(dir, Color(1.0, 0.72, 0.42), lerpf(float(fr[0]), float(fr[1]), near), 3.2, lerpf(28.0, 9.0, near))
	var crest: float = LandscapeTerrain.ridge_crest(0, bearing)
	_glow(LandscapeTerrain.at_bearing(bearing, 318.0) + Vector3(0, crest * 0.45, 0), lerpf(28.0, 70.0, near), Color(1.0, 0.7, 0.4), 1.4 * (0.5 + near), 0.35)
	if km < 4.0:
		_flash_light_e = maxf(_flash_light_e, lerpf(0.0, 0.55, clampf((4.0 - km) / 2.5, 0.0, 1.0)))
		_flash_light.light_color = Color(1.0, 0.75, 0.5)
		var p: Vector3 = LandscapeTerrain.at_bearing(bearing, 300.0) + Vector3(0, 40, 0)
		_flash_light.look_at_from_position(p, Vector3(12, 0, 20), Vector3.UP)
	var vr: Array = a.get("volume_db", [-14.0, 2.0])
	var vol: float = lerpf(float(vr[0]), float(vr[1]), near)
	var key: String = str(a.get("near_sound", "")) if km < float(a.get("near_km", 3.0)) else str(a.get("sound", ""))
	var where: Vector3 = LandscapeTerrain.at_bearing(bearing, 300.0)
	_after(boom_delay(km, cfg), func() -> void:
		far_sound(key, where, vol)
		if km < float(a.get("shake_km", 3.0)):
			_shake(float(a.get("shake", 0.3)) * clampf((float(a.get("shake_km", 3.0)) - km) / 1.5, 0.2, 1.0))
		if km < float(a.get("sway_km", 3.4)) and sway != null:
			sway.impulse(-LandscapeTerrain.dir_of(bearing), float((cfg.get("lamp_sway", {}) as Dictionary).get("impulse", 0.22)) * clampf(3.6 - km, 0.3, 1.5)))


func _machine_gun() -> void:
	var m: Dictionary = cfg.get("machine_guns", {})
	var br: Array = m.get("bearings", [20, 160])
	var b: float = _rng.randf_range(float(br[0]), float(br[1]))
	var kr: Array = m.get("km", [1.5, 4.0])
	var km: float = lerpf(float(kr[1]), float(kr[0]), intensity * _rng.randf())
	_count("mg")
	far_sound(str(m.get("sound", "")), LandscapeTerrain.at_bearing(b, 300.0), lerpf(-6.0, -18.0, clampf((km - 1.5) / 3.0, 0.0, 1.0)))
	# a few red dashes low over the horizon where it's firing
	if _aa.size() > 0:
		var site: GPUParticles3D = _aa[_rng.randi() % _aa.size()]
		site.emitting = true
		_aa_off[_aa.find(site)] = 1.0


# ================================================================== searchlights, flak arcs, flash sprites

func _build_searchlights() -> void:
	var s: Dictionary = cfg.get("searchlights", {})
	var sh: Shader = load("res://gravelight/world/landscape/shaders/light_beam.gdshader") as Shader
	var length: float = float(s.get("length", 330.0))
	for b: Variant in s.get("bearings", []):
		var bearing: float = float(b)
		var base: Vector3 = LandscapeTerrain.at_bearing(bearing, float(s.get("radius", 296.0)))
		base.y = LandscapeTerrain.ridge_crest(0, bearing) * 0.35
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Searchlight"
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 16.0
		cm.bottom_radius = 0.9
		cm.height = length
		cm.radial_segments = 16
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("color", Vector3(0.75, 0.8, 0.9))
		m.set_shader_parameter("intensity", float(s.get("intensity", 0.2)))
		m.set_shader_parameter("length_falloff", 1.3)
		m.set_shader_parameter("edge_power", 3.0)
		m.set_shader_parameter("near_fade", 30.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 50.0
		add_child(mi)
		mi.set_instance_shader_parameter("beam_len", length)
		var sw: Array = s.get("sweep", [0.04, 0.11])
		_beams.append({"mi": mi, "base": base, "bearing": bearing, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(float(sw[0]), float(sw[1])),
			"len": length, "spot": 0.0})
	_update_beams(0.0)


func _update_beams(_delta: float) -> void:
	var s: Dictionary = cfg.get("searchlights", {})
	var el: Array = s.get("elevation", [38, 72])
	for b: Dictionary in _beams:
		var ph: float = float(b["phase"]) + _t * float(b["speed"]) * TAU * 0.25
		var az: float = float(b["bearing"]) + 180.0 + 34.0 * sin(ph)
		var e: float = deg_to_rad(lerpf(float(el[0]), float(el[1]), 0.5 + 0.5 * sin(ph * 0.63 + 1.7)))
		var d: Vector3 = (LandscapeTerrain.dir_of(az) * cos(e) + Vector3.UP * sin(e)).normalized()
		var mi: MeshInstance3D = b["mi"]
		var x: Vector3 = d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.RIGHT).normalized()
		mi.global_transform = Transform3D(Basis(x, d, x.cross(d)), (b["base"] as Vector3) + d * float(b["len"]) * 0.5)
		b["spot"] = float(s.get("intensity", 0.2)) * 1.8
	if not _beams.is_empty():
		_sky_dirty = true


func _build_aa() -> void:
	var t: Dictionary = cfg.get("tracers", {})
	var br: Array = t.get("bearings", [35, 150])
	for i: int in 3:
		var bearing: float = lerpf(float(br[0]), float(br[1]), (float(i) + 0.5) / 3.0) + _rng.randf_range(-8, 8)
		var p: GPUParticles3D = GPUParticles3D.new()
		p.name = "FlakTracers"
		p.amount = 60
		p.lifetime = 3.6
		p.emitting = false
		p.local_coords = false
		var base: Vector3 = LandscapeTerrain.at_bearing(bearing, 300.0)
		base.y = LandscapeTerrain.ridge_crest(0, bearing) * 0.4
		p.position = base
		p.visibility_aabb = AABB(Vector3(-200, -20, -200), Vector3(400, 260, 400))
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 16.0
		pm.initial_velocity_min = 48.0
		pm.initial_velocity_max = 62.0
		pm.gravity = Vector3(0, -9.8, 0)
		pm.color_ramp = Props._ramp_tex([[0.0, Color(1.0, 0.75, 0.4, 1.0)], [0.6, Color(1.0, 0.4, 0.15, 1.0)], [1.0, Color(0.8, 0.2, 0.1, 0.0)]])
		p.process_material = pm
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(1.5, 1.5)
		var m: StandardMaterial3D = Props._particle_mat(Color(1, 0.6, 0.3), Color(1, 0.4, 0.2), 4.0, true)
		m.disable_fog = true
		q.material = m
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_aa.append(p)
		_aa_off.append(0.0)


func _tracer_burst() -> void:
	if _aa.is_empty():
		return
	var t: Dictionary = cfg.get("tracers", {})
	var k: int = _rng.randi() % _aa.size()
	var site: GPUParticles3D = _aa[k]
	var pm: ParticleProcessMaterial = site.process_material as ParticleProcessMaterial
	pm.direction = Vector3(_rng.randf_range(-0.6, 0.6), 1.0, _rng.randf_range(-0.6, 0.6)).normalized()
	site.emitting = true
	var bu: Array = t.get("burst", [1.5, 4.0])
	_aa_off[k] = _rng.randf_range(float(bu[0]), float(bu[1])) * (1.0 + intensity)
	_count("tracers")


func _update_aa(delta: float) -> void:
	for i: int in _aa.size():
		if _aa_off[i] > 0.0:
			_aa_off[i] -= delta
			if _aa_off[i] <= 0.0:
				_aa[i].emitting = false


func _build_glow_pool() -> void:
	for i: int in 6:
		var mi: MeshInstance3D = LandscapeProps.glow_sprite(Vector3.ZERO, 40.0, Color(1, 0.7, 0.4), 1.0)
		mi.visible = false
		add_child(mi)
		_glows.append({"mi": mi, "mat": mi.material_override, "t": 0.0, "life": 0.0, "energy": 0.0, "col": Color.WHITE})


## A flash sprite on the horizon at `pos`, fading over `life` seconds.
func _glow(pos: Vector3, size: float, col: Color, energy: float, life: float) -> void:
	var best: Dictionary = _glows[0]
	for g: Dictionary in _glows:
		if not (g["mi"] as MeshInstance3D).visible:
			best = g
			break
		if float(g["t"]) / maxf(0.01, float(g["life"])) > float(best["t"]) / maxf(0.01, float(best["life"])):
			best = g
	var mi: MeshInstance3D = best["mi"]
	mi.global_position = pos
	(mi.mesh as QuadMesh).size = Vector2(size, size)
	mi.visible = true
	best["t"] = 0.0
	best["life"] = life
	best["energy"] = energy
	best["col"] = col


func _update_glows(delta: float) -> void:
	for g: Dictionary in _glows:
		var mi: MeshInstance3D = g["mi"]
		if not mi.visible:
			continue
		g["t"] = float(g["t"]) + delta
		var k: float = 1.0 - float(g["t"]) / maxf(0.01, float(g["life"]))
		if k <= 0.0:
			mi.visible = false
			continue
		var c: Color = g["col"]
		var e: float = float(g["energy"]) * k * k
		(g["mat"] as StandardMaterial3D).albedo_color = Color(c.r * e, c.g * e, c.b * e, 1.0)


# ================================================================== flares

## A parachute flare popping `r` metres out on `bearing`, then drifting down lighting the snow.
func spawn_flare(bearing: float = -1.0, r: float = -1.0) -> Node3D:
	var f: Dictionary = cfg.get("flares", {})
	if _flares.size() >= 2:
		return null
	var br: Array = f.get("bearings", [0, 360])
	var rr: Array = f.get("radius", [75, 165])
	if bearing < 0.0:
		bearing = _rng.randf_range(float(br[0]), float(br[1]))
	if r < 0.0:
		r = _rng.randf_range(float(rr[0]), float(rr[1]))
	var hr: Array = f.get("height", [95, 135])
	var red: bool = _rng.randf() < float(f.get("red_share", 0.4))
	var col: Color = Color(1.0, 0.3, 0.18) if red else Color(1.0, 0.94, 0.82)
	var n: Node3D = Node3D.new()
	n.name = "Flare"
	add_child(n)
	n.global_position = LandscapeTerrain.at_bearing(bearing, r) + Vector3(0, _rng.randf_range(float(hr[0]), float(hr[1])), 0)
	var glow: MeshInstance3D = LandscapeProps.glow_sprite(Vector3.ZERO, 7.0, col, 3.0)
	n.add_child(glow)
	var core: MeshInstance3D = LandscapeProps.glow_sprite(Vector3.ZERO, 1.6, Color(1, 1, 1), 6.0)
	n.add_child(core)
	var chute: MeshInstance3D = Props.ball(n, Vector3(0, 5.5, 0), Vector3(3.2, 1.2, 3.2), "linen")
	chute.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = col
	l.omni_range = float(f.get("light_range", 135.0))
	l.omni_attenuation = 1.2
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.4
	n.add_child(l)
	var smoke: GPUParticles3D = _flare_smoke()
	n.add_child(smoke)
	_flares.append({"node": n, "light": l, "glow": glow, "t": 0.0, "burn": float(f.get("burn_seconds", 38.0)), "energy": float(f.get("light_energy", 2.4)),
		"drift": Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.4, 0.4)), "col": col})
	far_sound(str(f.get("sound", "")), n.global_position, -6.0)
	add_flash((n.global_position - Vector3(12, 1.6, 20)).normalized(), col, 0.5, 0.25, 6.0)
	_count("flare")
	return n


func _flare_smoke() -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 6.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 60, 60))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0.2, 0.3, 0)
	pm.scale_curve = Props._curve_tex([[0.0, 0.3], [1.0, 1.0]])
	pm.color_ramp = Props._ramp_tex([[0.0, Color(0.9, 0.9, 0.9, 0.35)], [1.0, Color(0.5, 0.5, 0.55, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	var m: StandardMaterial3D = Props._particle_mat(Color(0, 0, 0), Color(0, 0, 0), 0.0, false)
	m.disable_fog = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _update_flares(delta: float) -> void:
	var f: Dictionary = cfg.get("flares", {})
	for i: int in range(_flares.size() - 1, -1, -1):
		var e: Dictionary = _flares[i]
		var n: Node3D = e["node"]
		e["t"] = float(e["t"]) + delta
		var t: float = float(e["t"])
		var burn: float = float(e["burn"])
		n.global_position += (Vector3(0, -float(f.get("fall_speed", 3.0)), 0) + (e["drift"] as Vector3) * (0.5 + _wind)) * delta
		var on: float = clampf(t / 0.6, 0.0, 1.0) * (1.0 - smoothstep(burn - 3.0, burn, t))
		var flick: float = 0.85 + 0.15 * sin(t * 23.0) * sin(t * 7.3 + 1.0)
		(e["light"] as OmniLight3D).light_energy = float(e["energy"]) * on * flick
		var gm: StandardMaterial3D = (e["glow"] as MeshInstance3D).material_override as StandardMaterial3D
		var c: Color = e["col"]
		gm.albedo_color = Color(c.r * 3.0 * on * flick, c.g * 3.0 * on * flick, c.b * 3.0 * on * flick, 1.0)
		if t > burn or n.global_position.y < 2.0:
			n.queue_free()
			_flares.remove_at(i)


# ================================================================== planes

## A bomber stream crossing the sky (bearing of travel from the json's headings unless given).
func spawn_bombers(heading_bearing: float = -1.0, offset: float = 1e9, count: int = -1) -> SkyFlight:
	var b: Dictionary = cfg.get("bombers", {})
	var hb: Array = b.get("headings", [70, 110])
	if heading_bearing < 0.0:
		heading_bearing = _rng.randf_range(float(hb[0]), float(hb[1]))
	var ofr: Array = b.get("offset", [-160, 120])
	if offset > 1e8:
		offset = _rng.randf_range(float(ofr[0]), float(ofr[1]))
	var cr: Array = b.get("count", [7, 13])
	if count < 0:
		count = _rng.randi_range(int(cr[0]), int(cr[1]))
	var ar: Array = b.get("altitude", [165, 225])
	var alt: float = _rng.randf_range(float(ar[0]), float(ar[1]))
	var dir: Vector3 = LandscapeTerrain.dir_of(heading_bearing)
	var side: Vector3 = Vector3(-dir.z, 0, dir.x)
	var c: Vector3 = Vector3(LandscapeTerrain.CENTER.x, alt, LandscapeTerrain.CENTER.y) + side * offset
	var half: float = sqrt(maxf(0.0, 330.0 * 330.0 - alt * alt - offset * offset))
	var f: SkyFlight = SkyFlight.new()
	f.name = "Bombers"
	f.sound = far_sound
	add_child(f)
	f.setup_bombers(b, c - dir * half, dir, half * 2.0, count, _rng.randi())
	_fade_far(f)
	flights.append(f)
	_count("bombers")
	if plane_down_allowed(round_now, plane_down_done, cfg) and _rng.randf() < float((cfg.get("plane_down", {}) as Dictionary).get("chance_per_flight", 0.6)) \
			* (1.0 - float((cfg.get("plane_down", {}) as Dictionary).get("fighter_share", 0.35))):
		var secs: float = half / maxf(1.0, f.speed) * _rng.randf_range(0.75, 1.05)
		_after(secs, func() -> void:
			if is_instance_valid(f):
				_shoot_down(f, _rng.randi() % maxi(1, f.planes.size())))
	return f


## A low fighter pair passing in front of the inn (centre bearing given or random).
func spawn_fighters(center_bearing: float = -1.0) -> SkyFlight:
	var c: Dictionary = cfg.get("fighters", {})
	if center_bearing < 0.0:
		center_bearing = _rng.randf_range(0.0, 360.0)
	var pr: Array = c.get("pass_distance", [90, 200])
	var d: float = _rng.randf_range(float(pr[0]), float(pr[1]))
	var ar: Array = c.get("altitude", [40, 85])
	var alt: float = _rng.randf_range(float(ar[0]), float(ar[1]))
	var sgn: float = 1.0 if _rng.randf() < 0.5 else -1.0
	var p0: Vector3 = LandscapeTerrain.at_bearing(center_bearing - 70.0 * sgn, 310.0) + Vector3(0, alt + 25.0, 0)
	var p3: Vector3 = LandscapeTerrain.at_bearing(center_bearing + 75.0 * sgn, 310.0) + Vector3(0, alt + 10.0, 0)
	var mid: Vector3 = LandscapeTerrain.at_bearing(center_bearing, d) + Vector3(0, alt, 0)
	var p1: Vector3 = mid + (p0 - p3).normalized() * 120.0 + Vector3(0, -10, 0)
	var p2: Vector3 = mid - (p0 - p3).normalized() * 120.0 + Vector3(_rng.randf_range(-40, 40), 15, _rng.randf_range(-40, 40))
	var ctrl: Array[Vector3] = [p0, p1, p2, p3]
	var f: SkyFlight = SkyFlight.new()
	f.name = "Fighters"
	f.sound = far_sound
	add_child(f)
	f.setup_fighters(c, ctrl, float(c.get("length", 640.0)) / float(c.get("speed", 42.0)), _rng.randi())
	_fade_far(f)
	flights.append(f)
	_count("fighters")
	if plane_down_allowed(round_now, plane_down_done, cfg) and _rng.randf() < float((cfg.get("plane_down", {}) as Dictionary).get("chance_per_flight", 0.6)) \
			* float((cfg.get("plane_down", {}) as Dictionary).get("fighter_share", 0.35)):
		_after(f.duration * 0.55, func() -> void:
			if is_instance_valid(f):
				_shoot_down(f, 0))
	return f


## Planes fade into the haze at the edge of the dome rather than popping in.
func _fade_far(f: SkyFlight) -> void:
	for p: Node3D in f.planes:
		var mi: MeshInstance3D = p as MeshInstance3D
		if mi == null:
			continue
		var m: ArrayMesh = mi.mesh as ArrayMesh
		for s: int in m.get_surface_count():
			var mat: StandardMaterial3D = (m.surface_get_material(s) as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			mat.distance_fade_min_distance = 372.0
			mat.distance_fade_max_distance = 300.0
			mi.set_surface_override_material(s, mat)


## Sets plane `index` of `f` on fire and sends it down behind the hills; the crash, the boom and the squad follow.
func _shoot_down(f: SkyFlight, index: int) -> void:
	if plane_down_done or f.planes.is_empty():
		return
	var pd: Dictionary = cfg.get("plane_down", {})
	plane_down_done = true
	index = clampi(index, 0, f.planes.size() - 1)
	var at: Vector3 = f.planes[index].global_position
	var cb: Array = pd.get("crash_bearing", [25, 150])
	var b: float = clampf(LandscapeTerrain.bearing(at.x, at.z) + _rng.randf_range(-15, 25), float(cb[0]), float(cb[1]))
	var crash: Vector3 = LandscapeTerrain.at_bearing(b, float(pd.get("crash_radius", 255.0)))
	crash.y = LandscapeTerrain.height(crash.x, crash.z) - 6.0
	# flak bursts round it first
	for k: int in 4:
		var off: Vector3 = Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-6, 10), _rng.randf_range(-12, 12))
		_after(k * 0.35, func() -> void: _glow(at + off, 9.0, Color(1.0, 0.65, 0.3), 2.0, 0.4))
	var lead: float = float(pd.get("burn_lead", 3.0))
	_after(lead * 0.4, func() -> void:
		if not is_instance_valid(f):
			return
		var faller: Node3D = f.shoot_down(mini(index, f.planes.size() - 1), crash, float(pd.get("dive_seconds", 11.0)))
		if faller == null:
			return
		far_sound(str(pd.get("dive_sound", "")), faller.global_position, 0.0)
		f.crashed.connect(_on_crash))
	_after(lead * 0.4 + float(pd.get("vo_delay", 2.5)), func() -> void: _squad_line(str(pd.get("vo_category", "SKY_PLANE_DOWN"))))
	_count("plane_down")


func _on_crash(pos: Vector3) -> void:
	var pd: Dictionary = cfg.get("plane_down", {})
	var dir: Vector3 = (pos - Vector3(12, 1.6, 20)).normalized() + Vector3(0, 0.04, 0)
	add_flash(dir, Color(1.0, 0.55, 0.22), 2.4, 0.6, 7.0)
	_glow(pos + Vector3(0, 12, 0), 90.0, Color(1.0, 0.55, 0.25), 2.2, 1.8)
	_flash_light_e = 0.35
	_flash_light.light_color = Color(1.0, 0.6, 0.3)
	_flash_light.look_at_from_position(pos + Vector3(0, 60, 0), Vector3(12, 0, 20), Vector3.UP)
	# what burns on behind the hill for the rest of the round
	var g: MeshInstance3D = LandscapeProps.glow_sprite(pos + Vector3(0, 8, 0), 34.0, Color(1.0, 0.45, 0.15), 0.8)
	g.name = "CrashGlow"
	add_child(g)
	var life: float = float(pd.get("wreck_glow_seconds", 140.0))
	var tw: Tween = g.create_tween()
	tw.tween_interval(life * 0.6)
	tw.tween_property(g, "scale", Vector3(0.3, 0.3, 0.3), life * 0.4)
	tw.tween_callback(g.queue_free)
	var smoke: GPUParticles3D = _flare_smoke()
	smoke.amount = 14
	smoke.lifetime = 20.0
	(smoke.draw_pass_1 as QuadMesh).size = Vector2(22, 22)
	(smoke.process_material as ParticleProcessMaterial).initial_velocity_min = 3.0
	(smoke.process_material as ParticleProcessMaterial).initial_velocity_max = 4.5
	(smoke.process_material as ParticleProcessMaterial).color_ramp = Props._ramp_tex([[0.0, Color(0.5, 0.25, 0.12, 0.5)], [0.3, Color(0.12, 0.11, 0.12, 0.45)], [1.0, Color(0.08, 0.08, 0.1, 0.0)]])
	smoke.position = pos + Vector3(0, 6, 0)
	smoke.visibility_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 160, 160))
	add_child(smoke)
	_after(life, func() -> void:
		if is_instance_valid(smoke):
			smoke.emitting = false)
	var km: float = float(pd.get("crash_km", 2.4))
	_after(boom_delay(km, cfg), func() -> void:
		far_sound(str(pd.get("crash_sound", "")), pos, 2.0)
		_shake(0.18)
		if sway != null:
			sway.impulse(-dir, 0.12))
	_count("crash")


func _squad_line(category: String) -> void:
	if not is_inside_tree() or category == "":
		return
	VOManager.squad_say(category, 1.0)


# ================================================================== the town, the wind, the inn

func _update_town() -> void:
	if land == null or land.sky_mat == null:
		return
	var tcfg: Dictionary = cfg.get("town", {})
	var sr: Array = tcfg.get("strength", [0.3, 0.6])
	var fl: float = float(tcfg.get("flicker", 0.25))
	var s: float = lerpf(float(sr[0]), float(sr[1]), intensity) * (1.0 - fl * 0.5 + fl * 0.5 * sin(_t * 0.9) * sin(_t * 2.3 + 1.0))
	land.sky_mat.set_shader_parameter("town_strength", s)
	for i: int in land.town_fires.size():
		var mi: MeshInstance3D = land.town_fires[i]
		var e: float = (0.35 + 0.35 * intensity) * (0.75 + 0.25 * sin(_t * (1.3 + i * 0.37) + i) * sin(_t * 3.1 + i * 2.0))
		(mi.material_override as StandardMaterial3D).albedo_color = Color(1.0 * e, 0.42 * e, 0.12 * e, 1.0)


func _start_gust() -> void:
	var g: Dictionary = cfg.get("gusts", {})
	var sr: Array = g.get("seconds", [3.0, 6.0])
	_gust_secs = _rng.randf_range(float(sr[0]), float(sr[1]))
	_gust = 1.0
	AudioDirector.play_2d(str(g.get("sound", "")), -4.0)
	for p: GPUParticles3D in _spindrift:
		if _rng.randf() < 0.75:
			p.restart()
	_count("gust")


func _update_wind(delta: float) -> void:
	if _gust_secs > 0.0:
		_gust_secs -= delta
	else:
		_gust = maxf(0.0, _gust - delta * 0.4)
	_wind = 0.22 + 0.08 * sin(_t * 0.37) + _gust * 0.8
	var push: float = float((cfg.get("gusts", {}) as Dictionary).get("snow_push", 2.6))
	for pm: ParticleProcessMaterial in _snow_pms:
		pm.gravity = Vector3(0.25 + _gust * push, -0.6, 0.05 + _gust * push * 0.3)
	# the inn sign: a pendulum the wind leans on; it creaks at the ends of its swing
	if land != null and land.inn_sign != null:
		var torque: float = _wind * 0.9 * (0.6 + 0.4 * sin(_t * 1.7)) - 9.0 * _sign_a - 1.2 * _sign_v
		var prev_v: float = _sign_v
		_sign_v += torque * delta
		_sign_a += _sign_v * delta
		land.inn_sign.rotation.x = _sign_a
		_sign_creak_cd -= delta
		if signf(prev_v) != signf(_sign_v) and absf(_sign_a) > 0.05 and _sign_creak_cd <= 0.0:
			_sign_creak_cd = 1.6
			AudioDirector.play_3d(str((cfg.get("inn_sign", {}) as Dictionary).get("sound", "")), land.inn_sign.global_position, -2.0)
	# the hayloft door: the gusts throw it open and it slams back on the frame
	if land != null and land.hayloft_door != null:
		var push_out: float = maxf(0.0, _wind - 0.3) * 5.0 * (0.5 + 0.5 * sin(_t * 2.9))
		_door_v += (push_out - 2.2 - 0.6 * _door_v) * delta
		_door_a += _door_v * delta
		_door_cd -= delta
		if _door_a < 0.0:
			if _door_v < -0.6 and _door_cd <= 0.0:
				_door_cd = 0.5
				AudioDirector.play_3d(str((cfg.get("shutter", {}) as Dictionary).get("sound", "")), land.hayloft_door.global_position, lerpf(-6.0, 0.0, clampf(-_door_v / 3.0, 0.0, 1.0)))
			_door_a = 0.0
			_door_v = -_door_v * 0.25
		_door_a = minf(_door_a, 1.9)
		land.hayloft_door.rotation.y = -_door_a
	if land != null and land.parachute_load != null:
		_load_t += delta * (0.6 + _wind)
		land.parachute_load.rotation = Vector3(sin(_load_t * 0.8) * 0.06 * (0.5 + _wind), _load_t * 0.15, cos(_load_t * 0.6) * 0.05)


func _update_fire() -> void:
	var out: bool = fire_out
	if _fire_light != null and is_instance_valid(_fire_light):
		var e: float = float(_fire_light.get("base_energy")) if _fire_light.get("base_energy") != null else _fire_light.light_energy
		out = hearth_out(e, _fire_base, cfg)
	if out != fire_out:
		fire_out = out
		if _chimney != null and is_instance_valid(_chimney):
			_chimney.emitting = not fire_out
		_count("fire_out" if fire_out else "fire_lit")
	if breath != null:
		breath.fire_out = fire_out
	if frost != null:
		frost.ease_to(FrostCreep.frost_at(round_now, cfg.get("frost", {}), fire_out), get_process_delta_time())


func _farm_light_out() -> void:
	farm_lit = false
	if land == null or land.farm_window == null:
		return
	var w: Node3D = land.farm_window
	var tw: Tween = w.create_tween()
	for k: int in 3:   # it gutters, then it's gone
		tw.tween_callback(func() -> void: w.visible = false)
		tw.tween_interval(0.12 + 0.1 * k)
		tw.tween_callback(func() -> void: w.visible = true)
		tw.tween_interval(0.25)
	tw.tween_callback(func() -> void: w.visible = false)
	_count("farm_dark")


func _dog() -> void:
	if not dog_barks_at(round_now, cfg) or land == null:
		return
	var d: Dictionary = cfg.get("dog", {})
	var where: Vector3 = LandscapeTerrain.at_bearing(float(d.get("bearing", 312.0)), 180.0)
	var n: int = _rng.randi_range(2, 5)
	var at: float = 0.0
	for k: int in n:
		_after(at, func() -> void: far_sound(str(d.get("sound", "")), where, -12.0))
		at += _rng.randf_range(0.55, 0.95)
	_count("dog")


func _ring_midnight() -> void:
	var b: Dictionary = cfg.get("bell", {})
	var where: Vector3 = land.church_pos if land != null else LandscapeTerrain.at_bearing(28.0, 300.0)
	var tolls: int = int(b.get("tolls", 12))
	var gap: float = float(b.get("gap", 3.4))
	for k: int in tolls:
		_after(k * gap, func() -> void: far_sound(str(b.get("sound", "")), where, -4.0))
	_after(tolls * gap + float(b.get("vo_after", 3.0)), func() -> void: _squad_line(str(b.get("vo_category", "MIDNIGHT"))))
	_count("bell")


# ================================================================== the crash site

func _build_cookoff() -> void:
	if land == null or land.cookoff_points.is_empty():
		return
	_cook_light = OmniLight3D.new()
	_cook_light.name = "CookOffFlash"
	_cook_light.light_color = Color(1.0, 0.75, 0.4)
	_cook_light.omni_range = 9.0
	_cook_light.light_energy = 0.0
	_cook_light.visible = false
	add_child(_cook_light)
	_sparks = GPUParticles3D.new()
	_sparks.name = "CookOffSparks"
	_sparks.amount = 40
	_sparks.lifetime = 1.1
	_sparks.one_shot = true
	_sparks.explosiveness = 0.85
	_sparks.emitting = false
	_sparks.local_coords = false
	_sparks.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 12, 16))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.color_ramp = Props._ramp_tex([[0.0, Color(1.0, 0.9, 0.5, 1.0)], [1.0, Color(1.0, 0.35, 0.05, 0.0)]])
	_sparks.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = Props._particle_mat(Color(1, 0.7, 0.3), Color(1, 0.4, 0.1), 7.0, true)
	_sparks.draw_pass_1 = q
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


## Ammunition in the hold cooking off: a run of pops, sparks spraying, a flicker of light. Harmless.
func _cookoff() -> void:
	if _sparks == null:
		return
	var c: Dictionary = cfg.get("cookoff", {})
	var p: Vector3 = land.cookoff_points[_rng.randi() % land.cookoff_points.size()]
	var pr: Array = c.get("pops", [2, 6])
	var n: int = _rng.randi_range(int(pr[0]), int(pr[1]))
	var at: float = 0.0
	for k: int in n:
		_after(at, func() -> void:
			_sparks.global_position = p + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.0, 0.5), _rng.randf_range(-0.6, 0.6))
			_sparks.restart()
			_cook_light.global_position = _sparks.global_position + Vector3(0, 0.5, 0)
			_cook_light.visible = true
			_cook_light.light_energy = _rng.randf_range(2.0, 4.0)
			var tw: Tween = _cook_light.create_tween()
			tw.tween_property(_cook_light, "light_energy", 0.0, 0.18)
			tw.tween_callback(func() -> void: _cook_light.visible = false)
			AudioDirector.play_3d(str(c.get("sound", "")), _sparks.global_position, 0.0))
		at += _rng.randf_range(0.08, 0.5)
	_count("cookoff")


func _build_spindrift() -> void:
	# snow blown off the ridges of the inn's and the stable's roofs (gen_map00 _gable), and the porch roofs
	for spot: Array in [[Vector3(12.0, 10.3, 5.0), Vector3(24, 0.3, 1.2)], [Vector3(15.0, 10.3, 28.0), Vector3(18, 0.3, 1.2)],
			[Vector3(4.0, 3.9, -1.3), Vector3(5, 0.1, 2.0)], [Vector3(20.0, 3.9, -1.3), Vector3(5, 0.1, 2.0)]]:
		var p: GPUParticles3D = GPUParticles3D.new()
		p.name = "Spindrift"
		p.amount = 70
		p.lifetime = 2.6
		p.one_shot = true
		p.explosiveness = 0.35
		p.emitting = false
		p.local_coords = false
		p.position = spot[0]
		p.visibility_aabb = AABB(Vector3(-20, -12, -20), Vector3(40, 20, 40))
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = (spot[1] as Vector3) * 0.5
		pm.direction = Vector3(1.0, 0.4, 0.3)
		pm.spread = 25.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 5.0
		pm.gravity = Vector3(1.2, -1.6, 0.4)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.2
		pm.scale_min = 0.6
		pm.scale_max = 1.6
		pm.color_ramp = Props._ramp_tex([[0.0, Color(0.9, 0.93, 1.0, 0.0)], [0.1, Color(0.9, 0.93, 1.0, 0.55)], [1.0, Color(0.9, 0.93, 1.0, 0.0)]])
		p.process_material = pm
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.35, 0.35)
		q.material = Props._particle_mat(Color(1, 1, 1), Color(1, 1, 1), 0.0, false)
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_spindrift.append(p)


## Dutch's line the first time someone gets a look at the empty pilot's seat (or the nearest squad-mate's
## version of it when Dutch isn't here).
func _check_pilot_line() -> void:
	var pl: Dictionary = cfg.get("pilot_line", {})
	if pilot_said or land == null or land.wreck_node == null or _t < float(pl.get("min_seconds", 12.0)):
		return
	var seat: Vector3 = land.wreck_node.global_transform * Vector3(-0.45, 2.2, -5.6)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_local or p.is_bot or p.camera == null:
			continue
		var eye: Vector3 = p.camera.global_position
		var to: Vector3 = seat - eye
		if to.length() > float(pl.get("distance", 27.0)):
			continue
		if (-p.camera.global_transform.basis.z).dot(to.normalized()) < float(pl.get("look_dot", 0.86)):
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, seat, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(seat) > 5.0:
			continue
		pilot_said = true
		_count("pilot_line")
		var cat: String = str(pl.get("category", "WRECK_PILOT"))
		for pid: int in VOManager.standing_pids():
			if VOManager.speaker_of(pid) == &"DUT":
				VOManager.say_as(pid, str(pl.get("dutch_category", cat)), 1.0)
				return
		VOManager.squad_say(cat, 1.0)
		return


# ================================================================== dev / capture hooks

## Sets the war's state as if round `r` were running (the farmhouse, the dog, the frost) without the RoundManager.
func debug_set_round(r: int) -> void:
	if not _setup_done:
		await get_tree().process_frame
	_set_round(maxi(1, r))
	if frost != null:
		frost.apply(FrostCreep.frost_at(r, cfg.get("frost", {}), fire_out))


## Stages the sky for a screenshot looking along `cam`: bombers crossing the view, a fighter pair, a flare, a
## barrage on the horizon ahead and (once) a plane going down.
func debug_stage_for_view(cam: Camera3D) -> void:
	var fwd: Vector3 = -cam.global_transform.basis.z
	var bearing: float = fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	_prune_flights()
	for f: SkyFlight in flights:
		f.queue_free()
	flights.clear()
	var fl: SkyFlight = spawn_bombers(bearing + 90.0, 0.0, 11)
	if fl != null:
		# put the stream in front of the camera, a little past the middle of its crossing
		fl.position = Vector3(LandscapeTerrain.CENTER.x, fl.position.y, LandscapeTerrain.CENTER.y) + LandscapeTerrain.dir_of(bearing) * 120.0 - fl.heading * 60.0
		fl.start = fl.position - fl.heading * 200.0
	spawn_fighters(bearing + 12.0)
	spawn_flare(bearing - 18.0, 110.0)
	for k: int in 4:
		_after(0.4 * k, func() -> void: shell(bearing + _rng.randf_range(-12, 12), _rng.randf_range(2.0, 5.0)))


## Fires one event by name (clips / the dev console): bombers, fighters, plane_down, flare, barrage, tracers, gust,
## cookoff, bell, dog.
func debug_trigger(kind: String, bearing: float = 90.0) -> void:
	match kind:
		"bombers":
			spawn_bombers()
		"fighters":
			spawn_fighters(bearing)
		"plane_down":
			plane_down_done = false
			var f: SkyFlight = spawn_bombers(bearing + 90.0, 0.0, 9)
			f.position = Vector3(LandscapeTerrain.CENTER.x, f.position.y, LandscapeTerrain.CENTER.y) + LandscapeTerrain.dir_of(bearing) * 90.0 - f.heading * 130.0
			_after(6.0, func() -> void:
				if is_instance_valid(f):
					_shoot_down(f, 4))
		"flare":
			spawn_flare(bearing, 100.0)
		"barrage":
			for k: int in 5:
				_after(0.5 * k, func() -> void: shell(bearing + _rng.randf_range(-10, 10), _rng.randf_range(1.6, 3.0)))
		"tracers":
			_tracer_burst()
		"gust":
			_start_gust()
		"cookoff":
			_cookoff()
		"bell":
			_ring_midnight()
		"dog":
			_dog()
