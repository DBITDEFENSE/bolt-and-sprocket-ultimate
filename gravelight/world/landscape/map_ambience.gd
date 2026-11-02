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
##
## UPDATE 10 (contract C1, DECISIONS T-154): every map may have its own living world. MapRoot._attach_map_ambience
## adds this node with data/gravelight/<map prefix>_ambience.json when the scene has no MapAmbience of its own; Map 0
## keeps its scene node and file, unchanged. A file with
## "needs_landscape": false runs without the Landscape (the Map 0 sky pieces then stay off). Every Map 0 section
## only runs when its key is in the file. New event kinds are data blocks that default to off: a block is a
## _kinds_setup_<name>() method (found and run in name order at setup) that reads its key and registers what it
## needs (_ticks, _round_fns, _power_fns, _shot_fns, _boom_fns, _flag_fns, _every timers, debug_kinds). Totenhafen's
## kinds are in the "U10 Totenhafen" block at the end; each Fernflug act appends its own block after it.

const FLASH_SLOTS: int = 8

@export var config_path: String = "res://data/gravelight/map00_ambience.json"
## Timed beats' delays are multiplied by this (smokes run them fast). Never changes what happens, only when.
@export var delay_scale: float = 1.0

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
# UPDATE 10 kinds registry (see the header)
var _ticks: Array[Callable] = []
var _round_fns: Array[Callable] = []
var _power_fns: Array[Callable] = []
var _shot_fns: Array[Callable] = []
var _boom_fns: Array[Callable] = []
var _flag_fns: Array[Callable] = []
var _kind_timers: Array = []            # {key, section, fn, left}
## kind -> Callable for debug_trigger (the dev console, clips, smokes).
var debug_kinds: Dictionary = {}
## Campaign arrival: the timed beats count rounds on this map (beat_round); -1 until known.
var round_base: int = -1
var _campaign: bool = false


func _ready() -> void:
	add_to_group(&"map_ambience")
	cfg = GLData.load_json(config_path)
	_rng.randomize()
	var mid: Variant = get_parent().get("map_id") if get_parent() != null else null
	_campaign = mid != null and Campaign.arriving(StringName(str(mid)))
	_setup.call_deferred()


## The round as the timed beats count it: rounds since this map began on a campaign arrival, else the round.
static func beat_round_of(r: int, base: int) -> int:
	return r - maxi(0, base)


func beat_round(r: int = -1) -> int:
	return beat_round_of(round_now if r < 0 else r, round_base)


## The wind right now, ~0.15 (lull) .. ~1.1 (a full gust): the reactive dressing (curtains, wind at the broken
## windows; Update 02 section 8, T-053) reads it through ReactiveWind.
func wind_strength() -> float:
	return _wind


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
	if cfg.is_empty() or (land == null and bool(cfg.get("needs_landscape", true))):
		return
	_setup_done = true
	GLBus.round_started.connect(_on_round_started)
	GLBus.weapon_fired.connect(_on_weapon_fired)
	GLBus.explosion.connect(_on_explosion)
	GLBus.power_activated.connect(_on_power_activated)
	GLBus.flag_changed.connect(_on_flag_changed)
	_flash_light = DirectionalLight3D.new()
	_flash_light.name = "WarFlash"
	_flash_light.shadow_enabled = false
	_flash_light.light_energy = 0.0
	_flash_light.light_volumetric_fog_energy = 0.3
	_flash_light.visible = false
	add_child(_flash_light)
	_build_searchlights()
	if cfg.has("tracers"):
		_build_aa()
	_build_glow_pool()
	if cfg.has("crows"):
		crows = CrowFlock.new()
		crows.name = "Crows"
		add_child(crows)
		crows.setup(cfg.get("crows", {}), _rng.randi())
	if cfg.has("breath"):
		breath = BreathFog.new()
		breath.name = "BreathFog"
		breath.cfg = cfg.get("breath", {})
		add_child(breath)
	if cfg.has("frost"):
		frost = FrostCreep.new()
		frost.name = "Frost"
		add_child(frost)
		frost.setup(cfg.get("frost", {}))
	sway = LampSway.new()
	sway.name = "LampSway"
	add_child(sway)
	sway.setup(cfg.get("lamp_sway", {}), get_parent())
	if cfg.has("chimney"):
		_find_fire_and_chimney()
	_find_snow()
	if land != null and not cfg.has("no_spindrift"):
		_build_spindrift()
	_build_cookoff()
	for key: String in ["bombers", "fighters", "artillery", "tracers", "flares", "machine_guns", "gusts", "dog", "cookoff"]:
		if not cfg.has(key):
			continue
		var sec: Dictionary = cfg.get(key, {})
		var f: Array = sec.get("first_after", [20, 40])
		_timers[key] = _rng.randf_range(float(f[0]), float(f[1]))
	round_now = maxi(1, RoundManager.current_round)
	intensity = intensity_for(round_now, cfg)
	if frost != null:
		frost.apply(FrostCreep.frost_at(round_now, cfg.get("frost", {}), false))
	if not _campaign:
		round_base = 0
	elif RoundManager.current_round > 0:
		round_base = RoundManager.current_round - 1
	_setup_kinds()


## Runs every _kinds_setup_* block in name order (each returns at once when its key is not in the file).
func _setup_kinds() -> void:
	var names: Array[String] = []
	for m: Dictionary in get_method_list():
		var n: String = str(m["name"])
		if n.begins_with("_kinds_setup_") and not names.has(n):
			names.append(n)
	names.sort()
	for n2: String in names:
		call(n2)


## A kind's random timer: `fn` fires after section.first_after, then every section.interval (interval_late at full
## intensity; with "by": "storm" the storm's strength stands in for the war's intensity).
func _every(key: String, section: Dictionary, fn: Callable) -> void:
	var f: Array = section.get("first_after", [20, 40])
	_kind_timers.append({"key": key, "section": section, "fn": fn, "left": _rng.randf_range(float(f[0]), float(f[1]))})


func _update_kind_timers(delta: float) -> void:
	for t: Dictionary in _kind_timers:
		t["left"] = float(t["left"]) - delta
		if float(t["left"]) <= 0.0:
			var sec: Dictionary = t["section"]
			var k: float = storm_k if str(sec.get("by", "")) == "storm" else intensity
			var iv: Vector2 = interval_range(sec, k)
			t["left"] = _rng.randf_range(iv.x, iv.y)
			(t["fn"] as Callable).call()


## A node of the map by name ("" or missing: null).
func _named(n: String) -> Node3D:
	if n == "" or get_parent() == null:
		return null
	return get_parent().find_child(n, true, false) as Node3D


## _after for a timed beat: the delay scales with delay_scale.
func _beat_after(secs: float, fn: Callable) -> void:
	_after(secs * delay_scale, fn)


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
	var s: Node = get_parent().find_child("Snowfall", true, false)
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
	for fn: Callable in _ticks:
		fn.call(delta)
	if not _kind_timers.is_empty():
		_update_kind_timers(delta)


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
	if farm_lit and cfg.has("farm_light") and not farm_lit_at(r, cfg):
		_farm_light_out()


func _on_round_started(r: int, _special: bool) -> void:
	_set_round(maxi(1, r))
	var b: Dictionary = cfg.get("bell", {})
	if cfg.has("bell") and not bell_rung and r == int(b.get("round", 9)):
		bell_rung = true
		_after(float(b.get("delay", 22.0)), _ring_midnight)
	if round_base < 0:
		round_base = maxi(0, r - 1)
	for fn: Callable in _round_fns:
		fn.call(beat_round(r))


func _on_explosion(at: Vector3, radius: float) -> void:
	if crows != null:
		crows.gunfire(at)
	for fn: Callable in _boom_fns:
		fn.call(at, radius)


func _on_weapon_fired(_pid: int, _w: StringName, _u: bool, origin: Vector3, _d: Vector3) -> void:
	if crows != null:
		crows.gunfire(origin)
	for fn: Callable in _shot_fns:
		fn.call(origin)


func _on_power_activated() -> void:
	for fn: Callable in _power_fns:
		fn.call()


func _on_flag_changed(flag: StringName, value: Variant) -> void:
	for fn: Callable in _flag_fns:
		fn.call(flag, value)


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
		_flash_light.look_at_from_position(p, _c3(0.0), Vector3.UP)
	var vr: Array = a.get("volume_db", [-14.0, 2.0])
	var vol: float = lerpf(float(vr[0]), float(vr[1]), near)
	var key: String = str(a.get("near_sound", "")) if km < float(a.get("near_km", 3.0)) else str(a.get("sound", ""))
	var where: Vector3 = LandscapeTerrain.at_bearing(bearing, 300.0)
	_after(boom_delay(km, cfg), func() -> void:
		far_sound(key, where, vol)
		if km < float(a.get("shake_km", 3.0)):
			_shake(float(a.get("shake", 0.3)) * clampf((float(a.get("shake_km", 3.0)) - km) / 1.5, 0.2, 1.0))
		for sfn: Callable in _shell_fns:
			sfn.call(bearing, km)
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
	add_flash((n.global_position - _c3(1.6)).normalized(), col, 0.5, 0.25, 6.0)
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
	if bool(pd.get("ridge", false)):   # U10 Kaltenbrunn: it hits the mountain wall, high up, and burns there
		crash = LandscapeTerrain.at_bearing(b, 330.0)
		crash.y = LandscapeTerrain.ridge_crest(1, b) * 0.78
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
	var dir: Vector3 = (pos - _c3(1.6)).normalized() + Vector3(0, 0.04, 0)
	add_flash(dir, Color(1.0, 0.55, 0.22), 2.4, 0.6, 7.0)
	_glow(pos + Vector3(0, 12, 0), 90.0, Color(1.0, 0.55, 0.25), 2.2, 1.8)
	_flash_light_e = 0.35
	_flash_light.light_color = Color(1.0, 0.6, 0.3)
	_flash_light.look_at_from_position(pos + Vector3(0, 60, 0), _c3(0.0), Vector3.UP)
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
	GLVO.squad_say(category, 1.0)


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


## Dutch's line the first time someone gets a look into the cockpit, where Selwyn sits pinned alive (T-126), or the
## nearest squad-mate's version of it when Dutch isn't here.
func _check_pilot_line() -> void:
	var pl: Dictionary = cfg.get("pilot_line", {})
	if pilot_said or land == null or land.wreck_node == null or _t < float(pl.get("min_seconds", 12.0)):
		return
	var seat: Vector3 = land.wreck_node.global_transform * Vector3(-0.35, 1.5, -5.75)   # his head (gen_map00 WRECK_PILOT_SEAT)
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
		for pid: int in GLVO.standing_pids():
			if GLVO.speaker_of(pid) == &"DUT":
				GLVO.say_as(pid, str(pl.get("dutch_category", cat)), 1.0)
				return
		GLVO.squad_say(cat, 1.0)
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
		# put the stream in front of the camera, ~25 degrees up, crossing the view
		var c: Vector3 = cam.global_position + LandscapeTerrain.dir_of(bearing) * 230.0
		fl.position = Vector3(c.x, cam.global_position.y + 100.0, c.z) - fl.heading * 45.0
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
		_:
			if debug_kinds.has(kind):
				(debug_kinds[kind] as Callable).call()


# ---- U10 Totenhafen ----
# Totenhafen's living world (UPDATE 10 section 2.2, docs/U10_TOTENHAFEN_DESIGN.md section 7, DECISIONS T-154), from
# data/gravelight/map02_ambience.json. Every block returns at once when its key is not in the file. Presentation
# only: the one gameplay touch is the cutter's flag (set by the host) that the systems worker's sea-stair spawn
# reads. Shared helpers first, then one block per kind: gulls, lighthouse, bell_tower, ships, low_pass, raid,
# chains, drips, conveyor_jolt, radio_chatter, cutter_slip, footprints, frozen_spray, fish_crates, storm,
# power_spectacle.

var storm_k: float = 0.0                 # 0 calm .. 1 spring-tide storm (the tide drives it)
var tide_stage_name: StringName = &""
var gulls: CrowFlock
var lighthouse_lit: bool = true
var bell_tolled: bool = false
var low_pass_done: bool = false
var raid_done: bool = false
var raid_bombs: int = 0
var cutter_slipped: bool = false
var conveyor_running: bool = false
var drain_now: float = 0.0
var chain_sway: LampSway
var _storm_target: float = 0.0
var _mist_pool: Array[GPUParticles3D] = []
var _dust_pool: Array[GPUParticles3D] = []
var _dust_points: Array[Vector3] = []
var _icicles: Array[Node3D] = []
var _drip_boost_left: float = 0.0
var _lh: Node3D
var _lh_pivot: Node3D
var _lh_light: OmniLight3D
var _lh_glow: MeshInstance3D
var _bell: Node3D
var _bell_a: float = 0.0
var _bell_v: float = 0.0
var _fire_lights: Array[Light3D] = []
var _dbeam: MeshInstance3D
var _destroyer: Node3D
var _flak_sites: Array[GPUParticles3D] = []
var _flak_off: Array[float] = []
var _cans: Node3D
var _radio_bag: Array = []
var _fp_mm: MultiMeshInstance3D
var _fp_life: PackedFloat32Array = PackedFloat32Array()
var _fp_next: int = 0
var _fp_last: Dictionary = {}           # player instance id -> [last step position, side]
var _crates: Array = []                 # {node, spilled}
var _crate_tick: float = 0.0
var _chain_tick: float = 0.0
var _lightnings: Array = []             # [LightningFlash, base every_s, base peak]
var _rain_mats: Array[ShaderMaterial] = []
var _sea_mat: ShaderMaterial
var _dock_mat: ShaderMaterial
var _tide_node: Node
var _tide_poll: float = 0.0


# ================================================================== U10 pure rules (unit-tested)

static func lighthouse_lit_at(r: int, c: Dictionary) -> bool:
	return r < int((c.get("lighthouse", {}) as Dictionary).get("off_round", 10))


## True on the round a one-shot beat fires (the low pass, the raid, the cutter): exactly that beat round.
static func beat_fires(beat_r: int, section: Dictionary, done: bool) -> bool:
	return not done and section.has("round") and beat_r == int(section["round"])


## The storm's strength for a tide stage name (storm.stages), 0 when unknown.
static func storm_level_for(stage: StringName, c: Dictionary) -> float:
	return clampf(float(((c.get("storm", {}) as Dictionary).get("stages", {}) as Dictionary).get(String(stage), 0.0)), 0.0, 1.0)


## A tide level (the TideController's water y) as a storm strength, for when the tide signals aren't there: from
## the low water (0) to the spring height (1).
static func storm_level_for_y(y: float, c: Dictionary) -> float:
	var s: Dictionary = c.get("storm", {})
	var lo: float = float(s.get("calm_y", -4.0))
	var hi: float = float(s.get("spring_y", -1.0))
	return clampf((y - lo) / maxf(0.01, hi - lo), 0.0, 1.0)


## Seconds after its zone's turn that a power light at `p` comes on in the sweep from `from` (sweep.speed_mps,
## capped at sweep.max_s).
static func sweep_delay_for(p: Vector3, sweep: Dictionary) -> float:
	var f: Array = sweep.get("from", [0, 0, 0])
	var d: float = Vector2(p.x - float(f[0]), p.z - float(f[2])).length()
	return clampf(d / maxf(0.1, float(sweep.get("speed_mps", 14.0))), 0.0, float(sweep.get("max_s", 4.0)))


static func _v3(v: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var a: Array = v if v is Array else []
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else fallback


static func _inside(p: Vector3, box: Variant) -> bool:
	var b: Array = box if box is Array else []
	if b.size() < 2:
		return false
	var lo: Vector3 = _v3(b[0])
	var hi: Vector3 = _v3(b[1])
	return p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y and p.z >= lo.z and p.z <= hi.z


# ================================================================== U10 helpers

func _snd3(key: String, at: Vector3, db: float = 0.0) -> AudioStreamPlayer3D:
	if key == "" or not AudioDirector.has_sound(key):
		return null
	return AudioDirector.play_3d(key, at, db)


## The local player's eye (the listener), or null.
func _listener_pos() -> Variant:
	var cam: Camera3D = _listener()
	return cam.global_position if cam != null else null


## A shake for the local player, `inside` when they stand in `box`, else `outside`.
func _shake_in(box: Variant, inside: float, outside: float) -> void:
	var lp: Variant = _listener_pos()
	var amount: float = outside
	if lp != null and _inside(lp as Vector3, box):
		amount = inside
	if amount > 0.0:
		_shake(amount)


## A light's energy, through FlickerLight's base_energy when it has one (its flicker rewrites light_energy).
static func _light_e(l: Light3D) -> float:
	return float(l.get("base_energy")) if l.get("base_energy") != null else l.light_energy


static func _set_light_e(l: Light3D, e: float) -> void:
	if l.get("base_energy") != null:
		l.set("base_energy", e)
	else:
		l.light_energy = e


## A one-shot particle burst from a small pool (mist over the parapet, dust from the hall's ceiling).
func _burst_pool(pool: Array[GPUParticles3D], make: Callable, at: Vector3, size: int = 4) -> void:
	var p: GPUParticles3D = null
	for q: GPUParticles3D in pool:
		if not q.emitting:
			p = q
			break
	if p == null:
		if pool.size() < size:
			p = make.call() as GPUParticles3D
			add_child(p)
			pool.append(p)
		else:
			p = pool[_rng.randi() % pool.size()]
	p.global_position = at
	p.restart()


func _make_mist() -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "SprayMist"
	p.amount = 48
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.8
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.0, 0.2, 0.3)
	pm.direction = Vector3(0, 1, 0.6)
	pm.spread = 30.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -4.0, 1.2)
	pm.scale_min = 0.6
	pm.scale_max = 1.8
	pm.color_ramp = Props._ramp_tex([[0.0, Color(0.85, 0.9, 0.95, 0.0)], [0.15, Color(0.85, 0.9, 0.95, 0.22)], [1.0, Color(0.8, 0.85, 0.9, 0.0)]])
	pm.scale_curve = Props._curve_tex([[0.0, 0.4], [1.0, 1.0]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	q.material = Props._particle_mat(Color(1, 1, 1), Color(1, 1, 1), 0.0, false)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _make_dust() -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "CeilingDust"
	p.amount = 60
	p.lifetime = 3.4
	p.one_shot = true
	p.explosiveness = 0.7
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -14, -8), Vector3(16, 16, 16))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.6, 0.1, 1.6)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 2.2
	pm.color_ramp = Props._ramp_tex([[0.0, Color(0.55, 0.53, 0.5, 0.0)], [0.1, Color(0.55, 0.53, 0.5, 0.55)], [1.0, Color(0.5, 0.48, 0.45, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = Props._particle_mat(Color(0, 0, 0), Color(0, 0, 0), 0.0, false)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## A light-beam shaft (the searchlights' shader) from `parent`'s origin along its local `axis`.
func _beam(parent: Node3D, axis: Vector3, length: float, width: float, intensity_v: float, col: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Beam"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = width
	cm.bottom_radius = 0.5
	cm.height = length
	cm.radial_segments = 14
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://gravelight/world/landscape/shaders/light_beam.gdshader") as Shader
	m.set_shader_parameter("color", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("intensity", intensity_v)
	m.set_shader_parameter("length_falloff", 1.4)
	m.set_shader_parameter("edge_power", 2.6)
	m.set_shader_parameter("near_fade", 30.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 40.0
	parent.add_child(mi)
	mi.set_instance_shader_parameter("beam_len", length)
	var y: Vector3 = axis.normalized()
	var x: Vector3 = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.FORWARD).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), y * length * 0.5)
	return mi


# ================================================================== gulls: scatter at the first shot

func _kinds_setup_gulls() -> void:
	if not cfg.has("gulls"):
		return
	gulls = CrowFlock.new()
	gulls.name = "Gulls"
	add_child(gulls)
	gulls.setup(cfg["gulls"], _rng.randi())
	_shot_fns.append(func(at: Vector3) -> void: _gulls_scare(at))
	_boom_fns.append(func(at: Vector3, _r: float) -> void: _gulls_scare(at))
	debug_kinds["gulls"] = func() -> void: _gulls_scare(gulls.crows[0]["node"].global_position if not gulls.crows.is_empty() else Vector3.ZERO)


func _gulls_scare(at: Vector3) -> void:
	var before: int = gulls.perched_count()
	gulls.gunfire(at)
	if gulls.perched_count() < before:
		_count("gulls_scatter")


# ================================================================== the lighthouse: a beam every 9 s, dark from round 10

func _kinds_setup_lighthouse() -> void:
	if not cfg.has("lighthouse"):
		return
	var c: Dictionary = cfg["lighthouse"]
	_lh = _named(str(c.get("node", "Lighthouse")))
	if _lh == null:
		return
	_lh_pivot = Node3D.new()
	_lh_pivot.name = "LampTurn"
	_lh_pivot.position = Vector3(0, float(c.get("lamp_height", 17.0)), 0)
	_lh.add_child(_lh_pivot)
	var col: Color = Color(str(c.get("color", "#fff1cf")))
	for s: float in [1.0, -1.0]:
		_beam(_lh_pivot, Vector3(0, -0.035, s), float(c.get("beam_length", 220.0)), float(c.get("beam_width", 9.0)), float(c.get("beam_intensity", 0.3)), col)
	_lh_light = OmniLight3D.new()
	_lh_light.light_color = col
	_lh_light.omni_range = float(c.get("light_range", 26.0))
	_lh_light.light_energy = 0.0
	_lh_light.shadow_enabled = false
	_lh_light.light_volumetric_fog_energy = 1.2
	_lh_pivot.add_child(_lh_light)
	_lh_glow = LandscapeProps.glow_sprite(Vector3.ZERO, float(c.get("glow_size", 6.0)), col, 2.0)
	_lh_pivot.add_child(_lh_glow)
	_ticks.append(_tick_lighthouse)
	_round_fns.append(func(br: int) -> void:
		if lighthouse_lit and not lighthouse_lit_at(br, cfg):
			_lighthouse_out(false))
	if round_base >= 0 and not lighthouse_lit_at(beat_round(round_now), cfg):
		_lighthouse_out(true)
	if c.has("foghorn"):
		_every("foghorn", c["foghorn"], func() -> void:
			if lighthouse_lit:
				far_sound(str((c["foghorn"] as Dictionary).get("sound", "")), _lh.global_position, float((c["foghorn"] as Dictionary).get("db", -6.0)))
				_count("foghorn"))
	debug_kinds["lighthouse_dark"] = func() -> void: _lighthouse_out(false)


func _tick_lighthouse(_delta: float) -> void:
	if not lighthouse_lit or _lh_pivot == null:
		return
	var period: float = maxf(1.0, float((cfg["lighthouse"] as Dictionary).get("period_s", 9.0)))
	_lh_pivot.rotation.y = TAU * fmod(_t, period) / period
	# the flash when the beam sweeps past the viewer (a two-ended beam: twice a turn would be every 4.5 s, so the
	# far end is dimmer and only the near one flashes full)
	var k: float = 0.0
	var lp: Variant = _listener_pos()
	if lp != null:
		var to: Vector3 = (lp as Vector3) - _lh_pivot.global_position
		to.y = 0.0
		var fwd: Vector3 = _lh_pivot.global_transform.basis.z
		fwd.y = 0.0
		if to.length() > 0.1 and fwd.length() > 0.1:
			k = pow(maxf(0.0, fwd.normalized().dot(to.normalized())), 60.0)
	_lh_light.light_energy = float((cfg["lighthouse"] as Dictionary).get("light_energy", 4.0)) * (0.25 + 0.75 * k)
	(_lh_glow.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.94, 0.8) * (1.2 + 5.0 * k)


func _lighthouse_out(instant: bool) -> void:
	if not lighthouse_lit:
		return
	lighthouse_lit = false
	_count("lighthouse_dark")
	if _lh_pivot == null:
		return
	if instant:
		_lh_pivot.visible = false
		return
	var piv: Node3D = _lh_pivot
	var tw: Tween = piv.create_tween()
	for k: int in 3:   # it gutters, then it's gone
		tw.tween_callback(func() -> void: piv.visible = false)
		tw.tween_interval(0.15 + 0.12 * k)
		tw.tween_callback(func() -> void: piv.visible = true)
		tw.tween_interval(0.3)
	tw.tween_callback(func() -> void: piv.visible = false)


# ================================================================== the cliff church's bell: swings in the wind, tolls once

func _kinds_setup_bell_tower() -> void:
	if not cfg.has("bell_tower"):
		return
	var c: Dictionary = cfg["bell_tower"]
	_bell = _named(str(c.get("pivot", "CliffBellPivot")))
	if GameState.has_flag(StringName(str(c.get("flag", "egg_lf_started")))):
		bell_tolled = true   # the egg was started before this peer joined: no toll now
	_ticks.append(_tick_bell)
	_flag_fns.append(func(f: StringName, v: Variant) -> void:
		if String(f) == str(c.get("flag", "egg_lf_started")) and bool(v) and not bell_tolled:
			_bell_toll())
	debug_kinds["bell_toll"] = func() -> void:
		bell_tolled = false
		_bell_toll()


func _tick_bell(delta: float) -> void:
	if _bell == null:
		return
	var c: Dictionary = cfg["bell_tower"]
	var torque: float = _wind * float(c.get("wind_swing", 0.5)) * (0.6 + 0.4 * sin(_t * 1.3)) - 4.0 * _bell_a - 0.35 * _bell_v
	_bell_v += torque * delta
	_bell_a = clampf(_bell_a + _bell_v * delta, -0.9, 0.9)
	_bell.rotation.x = _bell_a


func _bell_toll() -> void:
	var c: Dictionary = cfg["bell_tower"]
	bell_tolled = true
	_bell_v += float(c.get("toll_swing", 1.6))
	var where: Vector3 = _bell.global_position if _bell != null else _v3(c.get("position"), Vector3(-40, 50, 0))
	_beat_after(0.35, func() -> void: far_sound(str(c.get("sound", "")), where, float(c.get("db", 0.0))))
	if str(c.get("vo_category", "")) != "":
		_beat_after(float(c.get("vo_after", 4.0)), func() -> void: _squad_line(str(c["vo_category"])))
	_count("bell_toll")


# ================================================================== ships: a burning freighter, a destroyer's searchlight, star shells

func _kinds_setup_ships() -> void:
	if not cfg.has("ships"):
		return
	var c: Dictionary = cfg["ships"]
	var fr: Node3D = _named(str((c.get("freighter", {}) as Dictionary).get("node", "BurningFreighter")))
	if fr != null:
		for n: Node in fr.find_children("*", "Light3D", true, false):
			_fire_lights.append(n as Light3D)
			n.set_meta("base_e", (n as Light3D).light_energy)
	var ds: Dictionary = c.get("destroyer", {})
	_destroyer = _named(str(ds.get("node", "DestroyerLight")))
	if _destroyer != null:
		_dbeam = _beam(_destroyer, Vector3(0, 0.04, -1), float(ds.get("length", 240.0)), float(ds.get("width", 7.0)), float(ds.get("intensity", 0.22)), Color(0.82, 0.88, 1.0))
	_ticks.append(_tick_ships)
	if c.has("guns"):
		_every("ship_guns", c["guns"], _ship_guns)
	if c.has("star_shells"):
		_every("star_shells", c["star_shells"], func() -> void: _star_shell(false))
	debug_kinds["ship_guns"] = _ship_guns
	debug_kinds["star_shell"] = func() -> void: _star_shell(true)


func _tick_ships(_delta: float) -> void:
	for i: int in _fire_lights.size():
		var l: Light3D = _fire_lights[i]
		l.light_energy = float(l.get_meta("base_e", 2.0)) * (0.7 + 0.3 * sin(_t * (2.1 + i * 0.7) + i) * sin(_t * 5.3 + i * 1.9))
	if _destroyer != null and _dbeam != null:
		var ds: Dictionary = (cfg["ships"] as Dictionary).get("destroyer", {})
		var sw: float = deg_to_rad(float(ds.get("sweep_deg", 60.0)))
		_destroyer.rotation.y = deg_to_rad(float(ds.get("yaw", 180.0))) + sw * sin(_t * float(ds.get("sweep_speed", 0.07)) * TAU)


func _ship_guns() -> void:
	var g: Dictionary = (cfg["ships"] as Dictionary).get("guns", {})
	var at: Vector3 = _destroyer.global_position if _destroyer != null else _v3(g.get("position"), Vector3(80, 2, -120))
	var kr: Array = g.get("km", [4.0, 7.0])
	var km: float = _rng.randf_range(float(kr[0]), float(kr[1]))
	var shots: int = _rng.randi_range(1, 3)
	for k: int in shots:
		_after(k * _rng.randf_range(0.6, 1.4), func() -> void:
			_glow(at + Vector3(_rng.randf_range(-6, 6), 3.0, 0), 22.0, Color(1.0, 0.72, 0.42), 2.2, 0.35)
			_after(boom_delay(km, cfg), func() -> void: far_sound(str(g.get("sound", "war_artillery_boom")), at, float(g.get("db", -6.0)))))
	_count("ship_guns")


## A star shell over the water: a parachute flare lighting the bay white, drifting down.
func _star_shell(force: bool = false) -> void:
	var c: Dictionary = (cfg["ships"] as Dictionary).get("star_shells", {})
	if (not force and round_now < int(c.get("min_round", 1))) or _flares.size() >= 2:
		return
	var pts: Array = c.get("points", [[16, 0, -90]])
	var base: Vector3 = _v3(pts[_rng.randi() % pts.size()])
	var hr: Array = c.get("height", [60, 85])
	var pos: Vector3 = base + Vector3(_rng.randf_range(-25, 25), _rng.randf_range(float(hr[0]), float(hr[1])), _rng.randf_range(-15, 15))
	var col: Color = Color(1.0, 0.95, 0.85)
	var n: Node3D = Node3D.new()
	n.name = "StarShell"
	add_child(n)
	n.global_position = pos
	var glow: MeshInstance3D = LandscapeProps.glow_sprite(Vector3.ZERO, 7.0, col, 3.0)
	n.add_child(glow)
	n.add_child(LandscapeProps.glow_sprite(Vector3.ZERO, 1.6, Color(1, 1, 1), 6.0))
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = col
	l.omni_range = float(c.get("light_range", 120.0))
	l.omni_attenuation = 1.2
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.4
	n.add_child(l)
	n.add_child(_flare_smoke())
	_flares.append({"node": n, "light": l, "glow": glow, "t": 0.0, "burn": float(c.get("burn_seconds", 30.0)), "energy": float(c.get("light_energy", 2.6)),
		"drift": Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.4, 0.4)), "col": col})
	far_sound(str(c.get("sound", "war_flare_pop")), pos, -6.0)
	_count("star_shell")


# ================================================================== the low pass: Mosquitoes over the harbour, flak from the cliff

func _kinds_setup_low_pass() -> void:
	if not cfg.has("low_pass"):
		return
	var c: Dictionary = cfg["low_pass"]
	if round_base >= 0 and beat_round(round_now) > int(c.get("round", 6)):
		low_pass_done = true
	_round_fns.append(func(br: int) -> void:
		if beat_fires(br, c, low_pass_done):
			low_pass_done = true
			var d: Array = c.get("delay", [8, 14])
			_beat_after(_rng.randf_range(float(d[0]), float(d[1])), _low_pass))
	debug_kinds["low_pass"] = _low_pass
	_ticks.append(_tick_flak)


func _low_pass() -> void:
	var c: Dictionary = cfg["low_pass"]
	var a: Vector3 = _v3(c.get("from"), Vector3(-160, 70, -60))
	var m: Vector3 = _v3(c.get("mid"), Vector3(16, 34, -18))
	var b: Vector3 = _v3(c.get("to"), Vector3(190, 80, 10))
	var ctrl: Array[Vector3] = [a, a.lerp(m, 0.7), m.lerp(b, 0.3), b]
	var secs: float = (a.distance_to(m) + m.distance_to(b)) / maxf(1.0, float(c.get("speed", 70.0)))
	var f: SkyFlight = SkyFlight.new()
	f.name = "LowPass"
	f.sound = far_sound
	add_child(f)
	f.setup_fighters(c, ctrl, secs, _rng.randi())
	flights.append(f)
	_count("low_pass")
	var fk: Dictionary = c.get("flak", {})
	for v: Variant in fk.get("sites", []):
		var site: GPUParticles3D = _flak_site(_v3(v))
		var aim: Vector3 = (m - site.global_position).normalized()
		(site.process_material as ParticleProcessMaterial).direction = aim
		site.emitting = true
		_flak_off[_flak_sites.find(site)] = secs * 0.8
	var bursts: int = int(fk.get("bursts", 8))
	for k: int in bursts:
		var u: float = _rng.randf_range(0.2, 0.85)
		var p: Vector3 = SkyFlight.bezier(ctrl, u) + Vector3(_rng.randf_range(-14, 14), _rng.randf_range(-6, 12), _rng.randf_range(-14, 14))
		_after(u * secs, func() -> void:
			_glow(p, 7.0, Color(1.0, 0.65, 0.3), 2.0, 0.35)
			far_sound(str(fk.get("sound", "war_mg_distant")), p, -8.0)
			_count("flak"))
	if str(c.get("vo_category", "")) != "":
		_after(secs * 0.5, func() -> void: _squad_line(str(c["vo_category"])))


## A flak position's tracer emitter on the cliff (built once per site, reused by the low pass and the raid).
func _flak_site(at: Vector3) -> GPUParticles3D:
	for s: GPUParticles3D in _flak_sites:
		if s.global_position.distance_to(at) < 1.0:
			return s
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "CliffFlak"
	p.amount = 50
	p.lifetime = 3.0
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-200, -20, -200), Vector3(400, 260, 400))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 9.0
	pm.initial_velocity_min = 55.0
	pm.initial_velocity_max = 70.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.color_ramp = Props._ramp_tex([[0.0, Color(1.0, 0.75, 0.4, 1.0)], [0.6, Color(1.0, 0.4, 0.15, 1.0)], [1.0, Color(0.8, 0.2, 0.1, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var mat: StandardMaterial3D = Props._particle_mat(Color(1, 0.6, 0.3), Color(1, 0.4, 0.2), 4.0, true)
	mat.disable_fog = true
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = at
	_flak_sites.append(p)
	_flak_off.append(0.0)
	return p


func _tick_flak(delta: float) -> void:
	for i: int in _flak_sites.size():
		if _flak_off[i] > 0.0:
			_flak_off[i] -= delta
			if _flak_off[i] <= 0.0:
				_flak_sites[i].emitting = false


# ================================================================== the raid: round 12, a bomb walk across the pens

func _kinds_setup_raid() -> void:
	if not cfg.has("raid"):
		return
	var c: Dictionary = cfg["raid"]
	for n: Node in get_tree().get_nodes_in_group(StringName(str(c.get("dust_group", "m2_dust_points")))):
		_dust_points.append((n as Node3D).global_position)
	for n2: Node in get_tree().get_nodes_in_group(StringName(str(c.get("icicle_group", "m2_icicles")))):
		_icicles.append(n2 as Node3D)
	if round_base >= 0 and beat_round(round_now) > int(c.get("round", 12)):
		raid_done = true
	_round_fns.append(func(br: int) -> void:
		if beat_fires(br, c, raid_done):
			raid_done = true
			_beat_after(float(c.get("delay", 14.0)), _raid))
	debug_kinds["raid"] = _raid


func _raid() -> void:
	var c: Dictionary = cfg["raid"]
	_count("raid")
	var sr: Dictionary = c.get("siren", {})
	for v: Variant in sr.get("points", []):
		far_sound(str(sr.get("sound", "")), _v3(v), float(sr.get("db", -2.0)))
	var fk: Dictionary = c.get("flak", {})
	for v2: Variant in fk.get("sites", []):
		var site: GPUParticles3D = _flak_site(_v3(v2))
		(site.process_material as ParticleProcessMaterial).direction = Vector3(_rng.randf_range(-0.3, 0.3), 1.0, _rng.randf_range(0.1, 0.5)).normalized()
		site.emitting = true
		_flak_off[_flak_sites.find(site)] = float(fk.get("seconds", 20.0)) * maxf(0.2, delay_scale)
	var bm: Dictionary = c.get("bombs", {})
	var line: Array = bm.get("line", [[-14, 12, 40], [46, 12, 80]])
	var a: Vector3 = _v3(line[0])
	var b: Vector3 = _v3(line[1])
	var count: int = int(bm.get("count", 7))
	var at: float = float(bm.get("first_after", 8.0))
	var gap: Array = bm.get("gap", [1.1, 1.8])
	for i: int in count:
		var p: Vector3 = a.lerp(b, float(i) / maxf(1.0, float(count - 1))) + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
		_beat_after(at, func() -> void: _bomb(p))
		at += _rng.randf_range(float(gap[0]), float(gap[1]))
	if str(c.get("vo_line", "")) != "":
		_beat_after(at + float(c.get("vo_after", 5.0)), func() -> void:
			if GLVO.play_local(StringName(str(c["vo_line"]))):
				_count("raid_vo"))
	for nm: Variant in (c.get("collapse", {}) as Dictionary).get("show", []):
		var sn: Node3D = _named(str(nm))
		if sn != null:
			_beat_after(at, func() -> void: sn.visible = true)
	for nm2: Variant in (c.get("collapse", {}) as Dictionary).get("hide", []):
		var hn: Node3D = _named(str(nm2))
		if hn != null:
			_beat_after(at, func() -> void: hn.visible = false)


## One bomb on the pens' roof at `p`: the whistle and the hit, the hall shakes, dust from the ceiling points near it,
## the lamps and chains swing, icicles near it fall.
func _bomb(p: Vector3) -> void:
	var c: Dictionary = cfg["raid"]
	var bm: Dictionary = c.get("bombs", {})
	raid_bombs += 1
	_count("raid_bomb")
	_snd3(str(bm.get("sound", "war_artillery_near")), p, float(bm.get("db", 2.0)))
	_glow(p + Vector3(0, 2.0, 0), 34.0, Color(1.0, 0.62, 0.3), 2.6, 0.45)
	_shake_in(c.get("hall_box", []), float(bm.get("shake", 0.35)), float(bm.get("shake_outside", 0.12)))
	_count("hall_shake")
	var dir: Vector3 = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	if sway != null:
		sway.impulse(dir, float(bm.get("sway", 0.35)))
		if not sway.lamps.is_empty():
			_count("lamp_sway")
	if chain_sway != null:
		chain_sway.impulse(dir, float(bm.get("sway", 0.35)) * 1.5)
		if not chain_sway.lamps.is_empty():
			_count("chain_swing")
	var r: float = float(bm.get("dust_radius", 14.0))
	var n: int = 0
	for dp: Vector3 in _dust_points:
		if Vector2(dp.x - p.x, dp.z - p.z).length() < r and n < 3:
			_burst_pool(_dust_pool, _make_dust, dp, 6)
			_count("dust_burst")
			n += 1
	var ir: float = float(bm.get("icicle_radius", 18.0))
	for ic: Node3D in _icicles:
		if is_instance_valid(ic) and ic.visible and not ic.has_meta("fallen") and Vector2(ic.global_position.x - p.x, ic.global_position.z - p.z).length() < ir:
			_icicle_fall(ic)
	_drip_boost_left = float((cfg.get("drips", {}) as Dictionary).get("boost_seconds", 60.0))


func _icicle_fall(ic: Node3D) -> void:
	ic.set_meta("fallen", true)
	_count("icicle_fall")
	var floor_y: float = float(ic.get_meta("floor_y", ic.global_position.y - 4.0))
	var drop: float = ic.global_position.y - floor_y
	var t: float = sqrt(2.0 * maxf(0.1, drop) / 9.8)
	var tw: Tween = ic.create_tween()
	tw.tween_interval(_rng.randf_range(0.0, 0.5))
	tw.tween_property(ic, "global_position:y", floor_y, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		ic.visible = false
		_snd3(str((cfg["raid"] as Dictionary).get("icicle_sound", "")), ic.global_position, -4.0)
		_burst_pool(_mist_pool, _make_mist, ic.global_position, 4))


# ================================================================== chains and pulley blocks swing (wind, impacts)

func _kinds_setup_chains() -> void:
	if not cfg.has("chains"):
		return
	var c: Dictionary = cfg["chains"]
	chain_sway = LampSway.new()
	chain_sway.name = "ChainSway"
	add_child(chain_sway)
	chain_sway.setup(c, get_parent())
	_ticks.append(func(delta: float) -> void:
		_chain_tick -= delta
		if _chain_tick <= 0.0:
			_chain_tick = 0.5
			chain_sway.impulse(Vector3(0.4, 0, 1.0), float(c.get("wind_push", 0.04)) * _wind))
	_boom_fns.append(func(at: Vector3, radius: float) -> void:
		chain_sway.impulse_at(at, maxf(radius * 3.0, float(c.get("explosion_radius", 16.0))), Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)), float(c.get("impulse", 0.4)))
		var lp: Variant = _listener_pos()
		if lp != null and (lp as Vector3).distance_to(at) < 20.0:
			_snd3(str(c.get("sound", "")), at + Vector3(0, 3, 0), -8.0))


# ================================================================== drips (louder and more after the raid)

func _kinds_setup_drips() -> void:
	if not cfg.has("drips"):
		return
	_every("drips", cfg["drips"], _drip)


func _drip() -> void:
	var c: Dictionary = cfg["drips"]
	var lp: Variant = _listener_pos()
	if lp == null:
		return
	var reps: int = 1
	if _drip_boost_left > 0.0:
		reps = int(c.get("after_raid_mult", 3.0))
	for k: int in reps:
		var near: Array[Vector3] = []
		for v: Variant in c.get("points", []):
			var p: Vector3 = _v3(v)
			if p.distance_to(lp as Vector3) < float(c.get("radius", 16.0)):
				near.append(p)
		if near.is_empty():
			return
		var at: Vector3 = near[_rng.randi() % near.size()] + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
		_after(k * _rng.randf_range(0.2, 0.7), func() -> void: _snd3(str(c.get("sound", "cellar_drip")), at, float(c.get("db", -10.0))))
	_count("drip")


# ================================================================== the conveyor jolts when the power comes on

func _kinds_setup_conveyor_jolt() -> void:
	if not cfg.has("conveyor_jolt"):
		return
	var c: Dictionary = cfg["conveyor_jolt"]
	_cans = _named(str(c.get("node", "ConveyorCans")))
	if GameState.power_on:
		conveyor_running = true
	_power_fns.append(_conveyor_jolt)
	_ticks.append(_tick_conveyor)
	debug_kinds["conveyor_jolt"] = _conveyor_jolt


func _conveyor_jolt() -> void:
	var c: Dictionary = cfg["conveyor_jolt"]
	_count("conveyor_jolt")
	if _cans == null:
		conveyor_running = true
		return
	_snd3(str(c.get("sound", "")), _cans.global_position, float(c.get("db", 0.0)))
	var home: Vector3 = _cans.position
	var j: float = float(c.get("jolt_m", 0.06))
	var tw: Tween = _cans.create_tween()
	tw.tween_property(_cans, "position", home + _cans.transform.basis.z * j + Vector3(0, j * 0.6, 0), 0.07)
	tw.tween_property(_cans, "position", home - _cans.transform.basis.z * j * 0.5, 0.1)
	tw.tween_property(_cans, "position", home, 0.18)
	tw.tween_callback(func() -> void: conveyor_running = true)


func _tick_conveyor(delta: float) -> void:
	if not conveyor_running or _cans == null:
		return
	var c: Dictionary = cfg["conveyor_jolt"]
	# the cans are evenly spaced on one mesh: scrolling it by up to one spacing reads as the belt running
	var sp: float = float(c.get("spacing", 0.3))
	var v: float = float(c.get("run_speed", 0.35))
	for n: Node in _cans.get_children():
		var nd: Node3D = n as Node3D
		if nd != null:
			nd.position.z = wrapf(nd.position.z + v * delta, 0.0, sp)


# ================================================================== the radios: U-boat traffic in German, subtitled

func _kinds_setup_radio_chatter() -> void:
	if not cfg.has("radio_chatter"):
		return
	_every("radio", cfg["radio_chatter"], func() -> void: _radio_line(false))
	debug_kinds["radio"] = func() -> void: _radio_line(true)


func _radio_line(force: bool) -> void:
	var c: Dictionary = cfg["radio_chatter"]
	var lp: Variant = _listener_pos()
	var best: Variant = null
	var bd: float = float(c.get("radius", 9.0))
	for v: Variant in c.get("radios", []):
		var p: Vector3 = _v3(v)
		var d: float = p.distance_to(lp as Vector3) if lp != null else INF
		if d < bd:
			bd = d
			best = p
	if best == null:
		if not force or (c.get("radios", []) as Array).is_empty():
			return
		best = _v3((c["radios"] as Array)[0])
	if _radio_bag.is_empty():
		_radio_bag = (c.get("lines", []) as Array).duplicate()
		_radio_bag.shuffle()
	if _radio_bag.is_empty():
		return
	var line: String = str(_radio_bag.pop_back())
	_snd3(str(c.get("static_sound", "")), best as Vector3, float(c.get("static_db", -10.0)))
	_after(0.5, func() -> void: GLVO.play_local(StringName(line)))
	_count("radio_line")


# ================================================================== the cutter slips into the sea (round 15)

func _kinds_setup_cutter_slip() -> void:
	if not cfg.has("cutter_slip"):
		return
	var c: Dictionary = cfg["cutter_slip"]
	var rem: Node3D = _named(str(c.get("remnant", "CutterRemnantPieces")))
	if rem != null:
		rem.visible = false
	var late: bool = round_base >= 0 and beat_round(round_now) > int(c.get("round", 15))
	if late or GameState.has_flag(StringName(str(c.get("flag", "cutter_slipped")))):
		_cutter_slip(true)
	_round_fns.append(func(br: int) -> void:
		if beat_fires(br, c, cutter_slipped):
			cutter_slipped = true
			_beat_after(float(c.get("delay", 18.0)), func() -> void:
				cutter_slipped = false
				_cutter_slip(false)))
	debug_kinds["cutter_slip"] = func() -> void: _cutter_slip(false)


## The wreck slides off its cradle over the parapet into the sea with a groan and a wave; the cradle, the torn-off
## wheelhouse and the nets stay on the quay where it lay (over its collider). The host sets the flag the systems
## worker's sea-stair spawn (`Surf_Cutter`) and the hidden letter read.
func _cutter_slip(instant: bool) -> void:
	if cutter_slipped and not instant:
		return
	cutter_slipped = true
	var c: Dictionary = cfg["cutter_slip"]
	var hull: Node3D = _named(str(c.get("hull", "CutterHull")))
	var rem: Node3D = _named(str(c.get("remnant", "CutterRemnantPieces")))
	if rem != null:
		rem.visible = true
	var flag: StringName = StringName(str(c.get("flag", "cutter_slipped")))
	if Net.is_authority() and not GameState.has_flag(flag):
		GameState.set_flag(flag, true)
	var sp: Node = _named(str(c.get("spawn", "Surf_Cutter")))
	if sp != null and sp.get("enabled") != null:
		sp.set("enabled", true)
	_count("cutter_slip")
	if hull == null:
		return
	var p0: Vector3 = hull.position
	var via: Vector3 = p0 + _v3(c.get("via"), Vector3(0, 0.9, -3.5))   # up over the parapet, then down the shingle
	var to_pos: Vector3 = p0 + _v3(c.get("slide"), Vector3(0, -1.5, -21.0))
	var tilt: Vector3 = _v3(c.get("tilt"), Vector3(-15, 0, 8))
	var r0: Vector3 = hull.rotation
	var to_rot: Vector3 = r0 + Vector3(deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z))
	if instant:
		hull.position = to_pos
		hull.rotation = to_rot
		return
	var secs: float = float(c.get("seconds", 7.0))
	_snd3(str(c.get("groan_sound", "")), hull.global_position, float(c.get("groan_db", 0.0)))
	var tw: Tween = hull.create_tween()
	tw.tween_method(func(u: float) -> void:
		var e: float = u * u * (3.0 - 2.0 * u) * 0.4 + u * u * u * 0.6   # creeps, then goes
		hull.position = p0.lerp(via, e).lerp(via.lerp(to_pos, e), e)
		hull.rotation = r0.lerp(to_rot, e), 0.0, 1.0, secs)
	var splash: Vector3 = _v3(c.get("splash_at"), Vector3(25, -1.5, -5))
	_after(secs * 0.72, func() -> void:
		_snd3(str(c.get("splash_sound", "amb_m2_wave")), splash, 4.0)
		for k: int in 3:
			_burst_pool(_mist_pool, _make_mist, splash + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-1, 1)), 4)
		_shake_in([[0, -1, -2], [32, 6, 30]], 0.12, 0.0))


# ================================================================== wet footprints behind everyone on the wet concrete

func _kinds_setup_footprints() -> void:
	if not cfg.has("footprints"):
		return
	var c: Dictionary = cfg["footprints"]
	var mx: int = int(c.get("max", 64))
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var pm: PlaneMesh = PlaneMesh.new()
	var sz: Array = c.get("size", [0.13, 0.3])
	pm.size = Vector2(float(sz[0]), float(sz[1]))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.08
	mat.metallic_specular = 0.7
	mat.albedo_color = Color(1, 1, 1)
	pm.material = mat
	mm.mesh = pm
	mm.instance_count = mx
	for i: int in mx:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -100, 0)))
		mm.set_instance_color(i, Color(0, 0, 0, 0))
	_fp_mm = MultiMeshInstance3D.new()
	_fp_mm.name = "Footprints"
	_fp_mm.multimesh = mm
	_fp_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fp_mm)
	_fp_mm.global_transform = Transform3D.IDENTITY
	_fp_life.resize(mx)
	_fp_life.fill(-1.0)
	_ticks.append(_tick_footprints)


func _tick_footprints(delta: float) -> void:
	var c: Dictionary = cfg["footprints"]
	var mm: MultiMesh = _fp_mm.multimesh
	var life: float = float(c.get("life_s", 18.0))
	var col: Color = Color(str(c.get("color", "#0b0d0e")))
	var alpha: float = float(c.get("alpha", 0.5))
	for i: int in _fp_life.size():
		if _fp_life[i] < 0.0:
			continue
		_fp_life[i] += delta
		var k: float = 1.0 - _fp_life[i] / life
		if k <= 0.0:
			_fp_life[i] = -1.0
			mm.set_instance_color(i, Color(0, 0, 0, 0))
		else:
			mm.set_instance_color(i, Color(col.r, col.g, col.b, alpha * minf(1.0, k * 2.0)))
	var step: float = float(c.get("step_m", 0.75))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var body: CharacterBody3D = n as CharacterBody3D
		if body == null or not body.is_on_floor():
			continue
		var p: Vector3 = body.global_position
		var wet: bool = false
		for box: Variant in c.get("wet_boxes", []):
			if _inside(p, box):
				wet = true
				break
		if not wet:
			continue
		var id: int = body.get_instance_id()
		if not _fp_last.has(id):
			_fp_last[id] = [p, 1.0]
			continue
		var last: Array = _fp_last[id]
		var lp: Vector3 = last[0]
		var moved: Vector3 = Vector3(p.x - lp.x, 0, p.z - lp.z)
		if moved.length() < step:
			continue
		var side: float = -float(last[1])
		_fp_last[id] = [p, side]
		var fwd: Vector3 = moved.normalized()
		var right: Vector3 = fwd.cross(Vector3.UP)
		var at: Vector3 = p + right * side * 0.12 + Vector3(0, 0.012, 0)
		var basis: Basis = Basis.looking_at(fwd, Vector3.UP)
		mm.set_instance_transform(_fp_next, Transform3D(basis, at))
		mm.set_instance_color(_fp_next, Color(col.r, col.g, col.b, alpha))
		_fp_life[_fp_next] = 0.0
		_fp_next = (_fp_next + 1) % _fp_life.size()
		_count("footprint")


## How many footprints are showing (the smoke checks the trail).
func footprints_showing() -> int:
	var n: int = 0
	for v: float in _fp_life:
		if v >= 0.0:
			n += 1
	return n


# ================================================================== frozen spray: big waves burst over the parapet

func _kinds_setup_frozen_spray() -> void:
	if not cfg.has("frozen_spray"):
		return
	_every("big_wave", cfg["frozen_spray"], _big_wave)
	debug_kinds["big_wave"] = _big_wave


func _big_wave() -> void:
	var c: Dictionary = cfg["frozen_spray"]
	var pts: Array = c.get("points", [])
	if pts.is_empty():
		return
	var p: Vector3 = _v3(pts[_rng.randi() % pts.size()]) + Vector3(_rng.randf_range(-1.5, 1.5), 0, 0)
	_burst_pool(_mist_pool, _make_mist, p, 4)
	_snd3(str(c.get("sound", "amb_m2_wave")), p, float(c.get("db", -4.0)) + 4.0 * storm_k)
	_count("big_wave")


# ================================================================== fish crates spill when the dead run through

func _kinds_setup_fish_crates() -> void:
	if not cfg.has("fish_crates"):
		return
	for n: Node in get_tree().get_nodes_in_group(StringName(str((cfg["fish_crates"] as Dictionary).get("group", "m2_fish_crates")))):
		_crates.append({"node": n, "spilled": false})
	_ticks.append(_tick_crates)
	debug_kinds["spill"] = func() -> void:
		for cr: Dictionary in _crates:
			if not bool(cr["spilled"]):
				_spill(cr)
				return


func _tick_crates(delta: float) -> void:
	_crate_tick -= delta
	if _crate_tick > 0.0 or _crates.is_empty():
		return
	var c: Dictionary = cfg["fish_crates"]
	_crate_tick = float(c.get("check_s", 0.25))
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir == null or not dir.has_method("active_zombies"):
		return
	var zs: Array = dir.call("active_zombies")
	if zs.is_empty():
		return
	var r: float = float(c.get("radius", 1.1))
	for cr: Dictionary in _crates:
		if bool(cr["spilled"]):
			continue
		var cp: Vector3 = (cr["node"] as Node3D).global_position
		for z: Variant in zs:
			var zp: Vector3 = (z as Node3D).global_position
			if absf(zp.y - cp.y) < 1.5 and Vector2(zp.x - cp.x, zp.z - cp.z).length() < r:
				_spill(cr)
				break


## The crate tips over on its edge and the fish and ice slide out across the concrete (tweens, no physics).
func _spill(cr: Dictionary) -> void:
	cr["spilled"] = true
	var g: Node3D = cr["node"]
	_count("crate_spill")
	_snd3(str((cfg["fish_crates"] as Dictionary).get("sound", "")), g.global_position, -2.0)
	var box: Node3D = g.get_node_or_null("Box") as Node3D
	var away: float = _rng.randf_range(-PI, PI)
	if box != null:
		var tw: Tween = box.create_tween()
		tw.tween_property(box, "rotation", Vector3(deg_to_rad(_rng.randf_range(60, 80)), 0, 0), 0.35).set_trans(Tween.TRANS_BACK)
	for n: Node in g.get_children():
		var f: Node3D = n as Node3D
		if f == null or not String(f.name).begins_with("Fish"):
			continue
		var start: Vector3 = f.position
		var a: float = away + _rng.randf_range(-0.9, 0.9)
		var end: Vector3 = Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.5, 1.6)
		end.y = 0.02
		var spin: float = _rng.randf_range(-3.0, 3.0)
		var h: float = _rng.randf_range(0.2, 0.45)
		var tw2: Tween = f.create_tween()
		tw2.tween_interval(_rng.randf_range(0.05, 0.25))
		tw2.tween_method(func(u: float) -> void:
			f.position = start.lerp(end, u) + Vector3(0, h * 4.0 * u * (1.0 - u), 0)
			f.rotation.y = spin * u, 0.0, 1.0, _rng.randf_range(0.35, 0.6))


# ================================================================== the storm scales with the tide

func _kinds_setup_storm() -> void:
	if not cfg.has("storm"):
		return
	var c: Dictionary = cfg["storm"]
	var sea: MeshInstance3D = _named(str(c.get("sea_node", "SeaWater"))) as MeshInstance3D
	if sea != null and sea.material_override is ShaderMaterial:
		_sea_mat = sea.material_override as ShaderMaterial
	_dock_mat = _dock_material(str(c.get("dock_node", "TideWater")))
	for n: Node in get_parent().find_children("*", "OmniLight3D", true, false):
		if n is LightningFlash:
			var lf: LightningFlash = n as LightningFlash
			_lightnings.append([lf, lf.every_s, lf.peak_energy])
	for n2: Node in get_tree().get_nodes_in_group(StringName(str(c.get("rain_group", "m2_rain_glass")))):
		var mi: GeometryInstance3D = n2 as GeometryInstance3D
		if mi != null and mi.material_override is ShaderMaterial:
			_rain_mats.append(mi.material_override as ShaderMaterial)
	# the tide's signals (contract C2) when the systems worker's TideController emits them; else poll its level
	if GLBus.has_signal(&"tide_stage"):
		GLBus.connect(&"tide_stage", func(stage: StringName) -> void: _on_tide_stage(stage))
	if GLBus.has_signal(&"spring_tide"):
		GLBus.connect(&"spring_tide", func(_r: int) -> void: _on_tide_stage(&"spring"))
	if GLBus.has_signal(&"tide_flood_end"):
		GLBus.connect(&"tide_flood_end", func() -> void: _storm_target = minf(_storm_target, float(c.get("after_flood", 0.4))))
	_tide_node = get_parent().find_child(str(c.get("tide_node", "Tide")), true, false)
	_ticks.append(_tick_storm)
	_apply_storm()
	debug_kinds["storm_spring"] = func() -> void: _on_tide_stage(&"spring")
	debug_kinds["storm_calm"] = func() -> void: _on_tide_stage(&"low")


func _on_tide_stage(stage: StringName) -> void:
	tide_stage_name = stage
	_storm_target = storm_level_for(stage, cfg)
	_count("tide_stage")


## The pens' water material, made unique to this map the first time (the storm and the pumps' drain set it).
func _dock_material(node_name: String) -> ShaderMaterial:
	if _dock_mat != null:
		return _dock_mat
	var w: MeshInstance3D = _named(node_name) as MeshInstance3D
	if w == null or not (w.material_override is ShaderMaterial):
		return null
	w.material_override = (w.material_override as ShaderMaterial).duplicate()
	_dock_mat = w.material_override as ShaderMaterial
	return _dock_mat


func _tick_storm(delta: float) -> void:
	if tide_stage_name == &"" and _tide_node != null:
		_tide_poll -= delta
		if _tide_poll <= 0.0:
			_tide_poll = 1.0
			var lv: Variant = _tide_node.get("level")
			if lv != null:
				_storm_target = storm_level_for_y(float(lv), cfg)
	var before: float = storm_k
	storm_k = move_toward(storm_k, _storm_target, delta * float((cfg["storm"] as Dictionary).get("ease_per_s", 0.08)))
	if storm_k != before:
		_apply_storm()


func _apply_storm() -> void:
	var c: Dictionary = cfg["storm"]
	var k: float = storm_k
	if _sea_mat != null:
		var sa: Array = c.get("sea_amp", [0.45, 0.95])
		_sea_mat.set_shader_parameter("amp", lerpf(float(sa[0]), float(sa[1]), k))
	if _dock_mat != null:
		var da: Array = c.get("dock_amp", [0.18, 0.42])
		_dock_mat.set_shader_parameter("amp", lerpf(float(da[0]), float(da[1]), k))
	var le: Array = c.get("lightning_every", [[12, 28], [4, 10]])
	var lpk: Array = c.get("lightning_peak", [1.0, 1.6])
	for e: Array in _lightnings:
		var lf: LightningFlash = e[0]
		if not is_instance_valid(lf):
			continue
		var a: Array = le[0]
		var b: Array = le[1]
		lf.every_s = Vector2(lerpf(float(a[0]), float(b[0]), k), lerpf(float(a[1]), float(b[1]), k))
		lf.peak_energy = float(e[2]) * lerpf(float(lpk[0]), float(lpk[1]), k)
	var rn: Array = c.get("rain", [0.35, 1.0])
	for m: ShaderMaterial in _rain_mats:
		m.set_shader_parameter("intensity", lerpf(float(rn[0]), float(rn[1]), k))


# ================================================================== the power-on spectacle

func _kinds_setup_power_spectacle() -> void:
	if not cfg.has("power_spectacle"):
		return
	var c: Dictionary = cfg["power_spectacle"]
	var sweep: Dictionary = c.get("sweep", {})
	if not sweep.is_empty():
		for n: Node in get_tree().get_nodes_in_group(&"power_lights"):
			var l: Light3D = n as Light3D
			if l != null and str(l.get_meta("zone", "")) == str(sweep.get("zone", "D_PENHALL")):
				l.set_meta("sweep_delay", sweep_delay_for(l.global_position, sweep))
	_dock_material(str(c.get("drain_node", "TideWater")))
	if GameState.power_on:
		drain_now = float(c.get("drain_m", 0.4))
		_apply_drain()
	_power_fns.append(_power_spectacle)
	_ticks.append(_tick_drain)
	debug_kinds["power"] = _power_spectacle


func _power_spectacle() -> void:
	var c: Dictionary = cfg["power_spectacle"]
	_count("power_spectacle")
	# the pumps thunder
	for v: Variant in c.get("pumps", []):
		_snd3(str(c.get("pump_sound", "")), _v3(v) + Vector3(0, 1.2, 0), float(c.get("pump_db", 2.0)))
	var lp: Variant = _listener_pos()
	if lp != null:
		for v2: Variant in c.get("pumps", []):
			if (lp as Vector3).distance_to(_v3(v2)) < float(c.get("shake_radius", 30.0)):
				_shake(float(c.get("shake", 0.25)))
				break
	_count("pumps_thunder")
	_count("docks_drain")
	# the perks wake one after another with a sting of their jingle, in the sweep's order
	var from: Vector3 = _v3((c.get("sweep", {}) as Dictionary).get("from"), Vector3(48, 0, 70))
	var ps: Dictionary = c.get("perk_stings", {})
	var ms: Array = get_tree().get_nodes_in_group(&"perk_machines")
	ms.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node3D).global_position.distance_to(from) < (b as Node3D).global_position.distance_to(from))
	var t: float = float(ps.get("start_s", 3.0))
	for m: Node in ms:
		var mm: Node3D = m as Node3D
		_after(t, func() -> void: _perk_sting(mm))
		t += float(ps.get("gap_s", 0.6))
	# U-1047's interior: the red battle lanterns give way to the white lamps
	_after(float(c.get("uboat_delay", 3.2)), _uboat_white)


func _tick_drain(delta: float) -> void:
	var c: Dictionary = cfg["power_spectacle"]
	var target: float = float(c.get("drain_m", 0.4)) if GameState.power_on else 0.0
	if is_equal_approx(drain_now, target):
		return
	drain_now = move_toward(drain_now, target, delta * float(c.get("drain_m", 0.4)) / maxf(0.5, float(c.get("drain_s", 10.0))))
	_apply_drain()


func _apply_drain() -> void:
	if _dock_mat != null:
		_dock_mat.set_shader_parameter("level_offset", -drain_now)


func _perk_sting(m: Node3D) -> void:
	if not is_instance_valid(m):
		return
	var ps: Dictionary = (cfg["power_spectacle"] as Dictionary).get("perk_stings", {})
	var key: String = "jingle_" + str(m.get("perk_id"))
	_count("perk_sting")
	if not AudioDirector.has_sound(key):
		return
	var p: AudioStreamPlayer3D = AudioDirector.play_3d(key, m.global_position + Vector3.UP * 1.6, float(ps.get("db", -4.0)), 0.0)
	if p == null:
		return
	var stream: AudioStream = p.stream
	var secs: float = float(ps.get("seconds", 2.6))
	var tw: Tween = create_tween()
	tw.tween_interval(secs)
	tw.tween_method(func(db: float) -> void:
		if is_instance_valid(p) and p.stream == stream:
			p.volume_db = db, p.volume_db, -50.0, 0.6)
	tw.tween_callback(func() -> void:
		if is_instance_valid(p) and p.stream == stream:
			p.stop())


func _uboat_white() -> void:
	var c: Dictionary = cfg["power_spectacle"]
	var box: Variant = c.get("uboat_box", [])
	var to: float = float(c.get("uboat_red_to", 0.15))
	for n: Node in get_parent().find_children("*", "OmniLight3D", true, false):
		var l: OmniLight3D = n as OmniLight3D
		if l.light_color.r < 0.8 or l.light_color.g > 0.4 or not _inside(l.global_position, box):
			continue
		var e0: float = _light_e(l)
		var tw: Tween = l.create_tween()
		tw.tween_method(func(e: float) -> void: _set_light_e(l, e), e0, e0 * to, 1.6)
	_count("uboat_white")


# ---- U10 Kaltenbrunn ----------------------------------------------------------------------------------------------
# UPDATE 10 section 5 (DECISIONS T-161): the kinds Kaltenbrunn's file (data/gravelight/map01_ambience.json) adds on top
# of Map 0's schema. Each is a data block that defaults to off when its key is absent, so Map 0 is unchanged:
#   dogfight     two fighters circling over the mountains at a round, MG bursts, one trailing smoke
#   plane_down   (Map 0's block) + "ridge": true aims the crash at the Alpine wall and leaves the glow there
#   avalanche    a low rumble from a ridge every few minutes with a snow plume sliding down the face
#   cable_car    the gondola on KaltenLandscape's rope swings on the wind and creaks
#   siren        the minehead siren wails at a round (lamp pulsing on the headframe)
#   snow_harder  from a round the snowfall thickens and the wind leans on it (a second Snowfall layer fades in)
#   dust_fall    underground dust sifting from the ceilings when a shell lands near (the artillery block's impacts)
#   chains       hoist chains in the lift bay that swing and clank on a shell and when the lift moves
#   drips        water dripping in the galleries near the listener
#   salt_glint   a sparkle pass on the halite materials driven by the viewer's headlamp cone
#   no_spindrift true: skip Map 0's roof spindrift (its positions are the inn's)

var _k_cable_a: float = 0.0
var _k_cable_va: float = 0.0
var _k_cable_b: float = 0.0
var _k_cable_vb: float = 0.0
var _k_creak_cd: float = 0.0
var _k_siren_t: float = -1.0
var _k_siren_done: bool = false
var _k_dog_done: bool = false
var _k_dog: Node3D
var _k_dog_planes: Array[Node3D] = []
var _k_dog_t: float = 0.0
var _k_dog_burst: float = 2.0
var _k_dog_sound: float = 0.0
var _k_dog_tracers: Array = []
var _k_dog_center: Vector3 = Vector3.ZERO
var _k_blizzard: float = 0.0
var _k_blizzard_on: bool = false
var _k_snow_extra: Node3D
var _k_snow_orig: Node3D
var _k_plumes: Array = []             # {mi, t, life, from, to, size}
var _k_dust: Array[GPUParticles3D] = []
var _k_dust_cd: float = 0.0
var _k_chains: Array = []             # {node, a, v, b, w}
var _k_clank_cd: float = 0.0
var _k_lift: Node
var _k_lift_y: float = 1e9
var _k_lift_cd: float = 0.0
var _k_drip_cd: float = 3.0
var _k_glint: ShaderMaterial
var _k_glint_t: float = 0.0
var _k_drops: Array = []              # {mi, from, to, t, dur, snd, db}


func _c3(y: float) -> Vector3:
	return Vector3(LandscapeTerrain.CENTER.x, y, LandscapeTerrain.CENTER.y)


# ---- pure rules (unit-tested)

## Has the snow-harder round been reached? (The seconds-long ramp itself is runtime: blizzard_level().)
static func snow_harder_at(r: int, c: Dictionary) -> bool:
	var s: Dictionary = c.get("snow_harder", {})
	return not s.is_empty() and r >= int(s.get("round", 20))


static func siren_due_at(r: int, c: Dictionary) -> bool:
	var s: Dictionary = c.get("siren", {})
	return not s.is_empty() and r == int(s.get("round", 10))


static func dogfight_due_at(r: int, c: Dictionary) -> bool:
	var s: Dictionary = c.get("dogfight", {})
	return not s.is_empty() and r == int(s.get("round", 7))


## Does a shell `km` away shake dust down in the galleries (dust_fall.km) and move the lift chains?
static func dust_falls_for(km: float, c: Dictionary) -> bool:
	var d: Dictionary = c.get("dust_fall", {})
	return not d.is_empty() and km <= float(d.get("km", 3.6))


## Schema problems in an ambience file (empty = valid): every block a dictionary, every [min, max] pair ordered, the
## round numbers positive, the sound keys strings. Used by the unit tests over every data/gravelight/*_ambience.json.
static func validate(c: Dictionary) -> PackedStringArray:
	var errs: PackedStringArray = []
	if c.is_empty():
		errs.append("empty")
		return errs
	for key: String in c.keys():
		if key.begins_with("_"):
			continue
		var v: Variant = c[key]
		if not (v is Dictionary):
			errs.append("%s is not a dictionary" % key)
			continue
		var sec: Dictionary = v
		for k2: String in sec.keys():
			var x: Variant = sec[k2]
			if x is Array and (k2 in ["first_after", "interval", "interval_late", "km", "km_late", "altitude", "count", "bursts", "seconds", "volume_db", "every", "burst_every"]):
				var a: Array = x
				if a.size() != 2 or not (a[0] is float or a[0] is int) or not (a[1] is float or a[1] is int) or float(a[0]) > float(a[1]):
					errs.append("%s.%s is not an ordered [min, max]" % [key, k2])
			elif k2.ends_with("sound") and not (x is String):
				errs.append("%s.%s is not a sound key" % [key, k2])
			elif (k2 == "round" or k2 == "min_round") and (not (x is float or x is int) or int(x) < 1):
				errs.append("%s.%s is not a round number" % [key, k2])
	return errs


# ---- setup (the kinds registry runs this by name at setup; every part returns at once when its key is absent)

var _shell_fns: Array[Callable] = []     # called as fn(bearing, km) when a shell's boom arrives


func _kinds_setup_u10_kaltenbrunn() -> void:
	var mine: bool = false
	for k: String in ["dogfight", "avalanche", "cable_car", "siren", "snow_harder", "dust_fall", "lift_chains", "gallery_drips", "salt_glint"]:
		mine = mine or cfg.has(k)
	if not mine:
		return
	if cfg.has("avalanche"):
		_every("avalanche", cfg["avalanche"], _ev_avalanche)
	if cfg.has("dust_fall"):
		_u10_build_dust()
	if cfg.has("lift_chains"):
		_u10_build_chains()
	if cfg.has("salt_glint"):
		_u10_build_glint()
	_k_lift = get_parent().find_child("Lift", true, false)
	if snow_harder_at(round_now, cfg):
		_k_blizzard_on = true
	_round_fns.append(func(br: int) -> void: _u10_round(br))
	_ticks.append(func(delta: float) -> void: _u10_process(delta))
	_shell_fns.append(func(bearing: float, km: float) -> void: _u10_on_shell(bearing, km))
	debug_kinds["dogfight"] = _ev_dogfight
	debug_kinds["siren"] = _ev_siren
	debug_kinds["avalanche"] = func() -> void: _ev_avalanche()
	debug_kinds["snow_harder"] = _ev_snow_harder
	debug_kinds["dust_fall"] = func() -> void: _u10_on_shell(0.0, 0.5)
	debug_kinds["lift_chains"] = func() -> void: _ev_lift_chains(1.0)
	debug_kinds["gallery_drip"] = func() -> void: _ev_drip(true)


func _u10_round(r: int) -> void:
	if dogfight_due_at(r, cfg) and not _k_dog_done:
		_k_dog_done = true
		_after(float((cfg.get("dogfight", {}) as Dictionary).get("delay", 10.0)) * delay_scale, _ev_dogfight)
	if siren_due_at(r, cfg) and not _k_siren_done:
		_k_siren_done = true
		_after(float((cfg.get("siren", {}) as Dictionary).get("delay", 12.0)) * delay_scale, _ev_siren)
	if snow_harder_at(r, cfg) and not _k_blizzard_on:
		_ev_snow_harder()


## Dev / smoke hook: a plane shot down onto the ridge now (bearing = where the flight crosses).
func debug_plane_down_ridge(bearing: float) -> void:
	plane_down_done = false
	var f: SkyFlight = spawn_bombers(bearing + 90.0, 0.0, 9)
	f.position = Vector3(LandscapeTerrain.CENTER.x, f.position.y, LandscapeTerrain.CENTER.y) + LandscapeTerrain.dir_of(bearing) * 90.0 - f.heading * 130.0
	_after(3.0, func() -> void:
		if is_instance_valid(f):
			_shoot_down(f, 4))


func _u10_process(delta: float) -> void:
	_u10_cable(delta)
	_u10_siren(delta)
	_u10_dogfight(delta)
	_u10_plumes(delta)
	_u10_blizzard(delta)
	_u10_chains(delta)
	_u10_lift(delta)
	_u10_drips(delta)
	_u10_drops(delta)
	_k_dust_cd = maxf(0.0, _k_dust_cd - delta)
	_k_glint_t -= delta
	if _k_glint != null and _k_glint_t <= 0.0:
		_k_glint_t = 0.05
		_u10_glint_update()


# ---- the dogfight

func _ev_dogfight() -> void:
	if _k_dog != null and is_instance_valid(_k_dog):
		return
	var c: Dictionary = cfg.get("dogfight", {})
	var alt: Array = c.get("altitude", [95, 125])
	_k_dog_center = LandscapeTerrain.at_bearing(float(c.get("bearing", 24.0)), float(c.get("distance", 150.0))) + Vector3(0, _rng.randf_range(float(alt[0]), float(alt[1])), 0)
	_k_dog = Node3D.new()
	_k_dog.name = "Dogfight"
	add_child(_k_dog)
	_k_dog_planes.clear()
	for i: int in 2:
		var p: MeshInstance3D = MeshInstance3D.new()
		p.mesh = PlaneModels.fighter()
		p.scale = Vector3.ONE * float(c.get("wingspan", 3.4))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_k_dog.add_child(p)
		_k_dog_planes.append(p)
	var trail: GPUParticles3D = _flare_smoke()
	trail.name = "LeadSmoke"
	trail.amount = 70
	trail.lifetime = 7.0
	trail.local_coords = false
	(trail.draw_pass_1 as QuadMesh).size = Vector2(5.5, 5.5)
	var pm: ParticleProcessMaterial = trail.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.color_ramp = Props._ramp_tex([[0.0, Color(0.95, 0.5, 0.2, 0.7)], [0.08, Color(0.16, 0.14, 0.14, 0.6)], [1.0, Color(0.1, 0.1, 0.12, 0.0)]])
	trail.visibility_aabb = AABB(Vector3(-300, -200, -300), Vector3(600, 400, 600))
	_k_dog_planes[0].add_child(trail)
	_k_dog_t = 0.0
	_k_dog_burst = 2.0
	_k_dog_sound = 0.0
	_count("dogfight")


func _dog_path(t: float, lead: bool) -> Vector3:
	var c: Dictionary = cfg.get("dogfight", {})
	var rad: float = float(c.get("radius", 72.0))
	var w: float = float(c.get("speed", 36.0)) / rad
	var th: float = t * w
	var rr: float = rad * (1.0 + 0.12 * sin(t * 0.7)) * (1.0 if lead else 0.9)
	return _k_dog_center + Vector3(cos(th) * rr, sin(t * 0.45) * 14.0 + (0.0 if lead else -3.0), sin(th) * rr)


func _u10_dogfight(delta: float) -> void:
	if _k_dog == null or not is_instance_valid(_k_dog):
		return
	var c: Dictionary = cfg.get("dogfight", {})
	_k_dog_t += delta
	var secs: float = float(c.get("seconds", 46.0))
	var lag: float = float(c.get("chase_lag", 1.25))
	if _k_dog_t <= secs:
		for i: int in 2:
			var t: float = _k_dog_t - (0.0 if i == 0 else lag)
			var p: Vector3 = _dog_path(t, i == 0)
			var q: Vector3 = _dog_path(t + 0.1, i == 0)
			var fwd: Vector3 = (q - p).normalized()
			(_k_dog_planes[i] as Node3D).global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3(0, 0, 1), -0.9), p)
			(_k_dog_planes[i] as Node3D).scale = Vector3.ONE * float(c.get("wingspan", 3.4))
	else:
		# the pair breaks off along its last heading and is gone
		for i3: int in 2:
			var pl: Node3D = _k_dog_planes[i3]
			pl.global_position += -pl.global_transform.basis.z * float(c.get("speed", 36.0)) * delta
		if _k_dog_t > secs + 6.0:
			_k_dog.queue_free()
			_k_dog = null
			_k_dog_planes.clear()
			_k_dog_tracers.clear()
			return
	_k_dog_sound -= delta
	if _k_dog_sound <= 0.0:
		_k_dog_sound = 9.0
		far_sound(str(c.get("sound", "")), _k_dog_planes[0].global_position, float(c.get("volume_db", 0.0)))
	_k_dog_burst -= delta
	if _k_dog_burst <= 0.0 and _k_dog_t < secs - 2.0:
		var br: Array = c.get("burst_every", [1.6, 3.4])
		_k_dog_burst = _rng.randf_range(float(br[0]), float(br[1]))
		var chaser: Node3D = _k_dog_planes[1]
		var target: Node3D = _k_dog_planes[0]
		for k: int in _rng.randi_range(5, 9):
			var dir: Vector3 = (target.global_position - chaser.global_position).normalized()
			dir = (dir + Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.04, 0.05), _rng.randf_range(-0.05, 0.05))).normalized()
			var tr: MeshInstance3D = MeshInstance3D.new()
			tr.mesh = Props.unit_box()
			tr.material_override = PlaneModels.tracer_material()
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_k_dog.add_child(tr)
			tr.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3(0.18, 0.18, 6.0)), chaser.global_position + dir * (2.0 + k * 9.0))
			_k_dog_tracers.append([tr, dir * 300.0, 0.8])
		far_sound(str(c.get("mg_sound", "")), chaser.global_position, 0.0)
		_count("dogfight_burst")
	for i2: int in range(_k_dog_tracers.size() - 1, -1, -1):
		var e: Array = _k_dog_tracers[i2]
		e[2] = float(e[2]) - delta
		var tr2: MeshInstance3D = e[0]
		if float(e[2]) <= 0.0 or not is_instance_valid(tr2):
			if is_instance_valid(tr2):
				tr2.queue_free()
			_k_dog_tracers.remove_at(i2)
		else:
			tr2.global_position += (e[1] as Vector3) * delta


# ---- the avalanche

func _ev_avalanche(bearing: float = -1.0) -> void:
	var a: Dictionary = cfg.get("avalanche", {})
	var br: Array = a.get("bearings", [320, 420])
	if bearing < 0.0:
		bearing = fposmod(_rng.randf_range(float(br[0]), float(br[1])), 360.0)
	var top: Vector3 = LandscapeTerrain.at_bearing(bearing, 326.0)
	top.y = LandscapeTerrain.ridge_crest(1, bearing) * 0.8
	var bottom: Vector3 = LandscapeTerrain.at_bearing(bearing, 304.0)
	bottom.y = LandscapeTerrain.ridge_crest(1, bearing) * 0.12
	var life: float = float(a.get("plume_seconds", 11.0))
	for k: int in 3:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "AvalanchePlume"
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		mi.mesh = q
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.disable_fog = true
		m.albedo_texture = Snowfall.flake_texture()
		m.albedo_color = Color(0.74, 0.8, 0.92, 0.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = top
		_k_plumes.append({"mi": mi, "t": -float(k) * 0.9, "life": life, "from": top + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)),
			"to": bottom + Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-14, 14)), "size": _rng.randf_range(70.0, 130.0)})
	var km: float = float(a.get("km", 1.4))
	var where: Vector3 = top
	_after(boom_delay(km, cfg), func() -> void:
		far_sound(str(a.get("sound", "")), where, float(a.get("volume_db", -2.0)))
		_shake(float(a.get("shake", 0.1))))
	_count("avalanche")


func _u10_plumes(delta: float) -> void:
	for i: int in range(_k_plumes.size() - 1, -1, -1):
		var e: Dictionary = _k_plumes[i]
		e["t"] = float(e["t"]) + delta
		var u: float = clampf(float(e["t"]) / float(e["life"]), 0.0, 1.0)
		var mi: MeshInstance3D = e["mi"]
		if not is_instance_valid(mi):
			_k_plumes.remove_at(i)
			continue
		if float(e["t"]) < 0.0:
			continue
		mi.global_position = (e["from"] as Vector3).lerp(e["to"], u * u * (3.0 - 2.0 * u))
		var sz: float = float(e["size"]) * (0.25 + 1.1 * u)
		mi.scale = Vector3(sz, sz * 0.8, 1.0)
		var alpha: float = smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.55, 1.0, u)) * 0.5
		(mi.material_override as StandardMaterial3D).albedo_color = Color(0.74, 0.8, 0.92, alpha)
		if u >= 1.0:
			mi.queue_free()
			_k_plumes.remove_at(i)


# ---- the cable car, the siren

func _u10_cable(delta: float) -> void:
	if not (land is KaltenLandscape) or (land as KaltenLandscape).cable_pivot == null:
		return
	var cc: Dictionary = cfg.get("cable_car", {})
	var piv: Node3D = (land as KaltenLandscape).cable_pivot
	var k: float = float(cc.get("stiffness", 2.6))
	var damp: float = float(cc.get("damping", 0.1))
	var push: float = float(cc.get("wind_gain", 0.55)) * (_wind - 0.15)
	# across the rope (z) the wind pushes; along it (x) a slower coupled swing
	var tq: float = push * (0.6 + 0.4 * sin(_t * 0.93)) - k * _k_cable_a - damp * _k_cable_va
	var prev: float = _k_cable_va
	_k_cable_va += tq * delta
	_k_cable_a = clampf(_k_cable_a + _k_cable_va * delta, -0.35, 0.35)
	var tb: float = push * 0.3 * sin(_t * 0.61 + 1.0) - k * 1.4 * _k_cable_b - damp * 1.5 * _k_cable_vb
	_k_cable_vb += tb * delta
	_k_cable_b = clampf(_k_cable_b + _k_cable_vb * delta, -0.25, 0.25)
	piv.rotation = Vector3(_k_cable_b, 0.0, _k_cable_a)
	_k_creak_cd -= delta
	if signf(prev) != signf(_k_cable_va) and absf(_k_cable_a) > float(cc.get("creak_min_swing", 0.03)) and _k_creak_cd <= 0.0:
		_k_creak_cd = float(cc.get("creak_cooldown", 3.5))
		far_sound(str(cc.get("creak_sound", "")), piv.global_position, float(cc.get("volume_db", -8.0)))
		_count("cable_creak")


func _ev_siren() -> void:
	var s: Dictionary = cfg.get("siren", {})
	_k_siren_t = 0.0
	if land is KaltenLandscape and (land as KaltenLandscape).siren_node != null:
		AudioDirector.play_3d(str(s.get("sound", "")), (land as KaltenLandscape).siren_node.global_position, float(s.get("volume_db", 4.0)), 0.0)
	else:
		AudioDirector.play_2d(str(s.get("sound", "")), float(s.get("volume_db", 0.0)))
	var vo: String = str(s.get("vo_category", ""))
	if vo != "":
		_after(float(s.get("vo_delay", 6.0)), func() -> void: _squad_line(vo))
	_count("siren")


func _u10_siren(delta: float) -> void:
	if _k_siren_t < 0.0:
		return
	var s: Dictionary = cfg.get("siren", {})
	_k_siren_t += delta
	var secs: float = float(s.get("seconds", 20.0))
	var kl: KaltenLandscape = land as KaltenLandscape
	var lamp: OmniLight3D = kl.siren_lamp if kl != null else null
	if lamp != null:
		var on: float = 0.5 + 0.5 * sin(_k_siren_t * TAU / 3.2 - 1.2)
		lamp.visible = _k_siren_t < secs
		lamp.light_energy = float(s.get("lamp_energy", 7.0)) * on * (1.0 - smoothstep(secs - 2.0, secs, _k_siren_t))
		var horns: Node3D = kl.siren_node.get_node_or_null("Horns") as Node3D
		if horns != null:
			horns.rotation.y = _k_siren_t * 1.6
	if _k_siren_t >= secs:
		_k_siren_t = -1.0
		if lamp != null:
			lamp.visible = false
			lamp.light_energy = 0.0


# ---- the snow

func _ev_snow_harder() -> void:
	_k_blizzard_on = true
	if _k_snow_extra != null or _k_snow_orig == null:
		return
	var sh: Dictionary = cfg.get("snow_harder", {})
	var extra: Node3D = Node3D.new()
	extra.set_script(load("res://gravelight/world/snowfall.gd"))
	extra.name = "SnowHarder"
	extra.set("areas", _k_snow_orig.get("areas"))
	extra.set("density", float(_k_snow_orig.get("density")) * float(sh.get("density_mult", 1.4)))
	_k_snow_orig.get_parent().add_child(extra)
	for ch: Node in extra.get_children():
		if ch is GPUParticles3D:
			(ch as GPUParticles3D).amount_ratio = 0.05
	_k_snow_extra = extra
	_count("snow_harder")


func _u10_blizzard(delta: float) -> void:
	var sh: Dictionary = cfg.get("snow_harder", {})
	if sh.is_empty():
		return
	if _k_snow_orig == null:
		_k_snow_orig = get_parent().find_child("Snowfall", true, false) as Node3D
		if _k_snow_orig != null and _k_blizzard_on:
			_ev_snow_harder()
	var target: float = 1.0 if _k_blizzard_on else 0.0
	_k_blizzard = move_toward(_k_blizzard, target, delta / maxf(1.0, float(sh.get("ramp_seconds", 25.0))))
	if _k_blizzard <= 0.0:
		return
	var lean: float = _k_blizzard * float(sh.get("wind_lean", 1.6))
	for pm: ParticleProcessMaterial in _snow_pms:
		pm.gravity += Vector3(lean, 0.0, lean * 0.3)   # on top of the gust code's gravity, written just before
	if _k_snow_extra != null:
		for ch: Node in _k_snow_extra.get_children():
			var p: GPUParticles3D = ch as GPUParticles3D
			if p == null:
				continue
			p.amount_ratio = clampf(_k_blizzard, 0.05, 1.0)
			if p.process_material is ParticleProcessMaterial:
				(p.process_material as ParticleProcessMaterial).gravity = Vector3(0.25 + lean + _gust * 2.6, -0.6, 0.05 + lean * 0.3)


## 0..1: how far the snow has thickened (the smoke and the capture tool read it).
func blizzard_level() -> float:
	return _k_blizzard


# ---- underground: dust, chains, drips

func _u10_build_dust() -> void:
	for i: int in 4:
		var p: GPUParticles3D = GPUParticles3D.new()
		p.name = "CeilingDust"
		p.amount = 36
		p.lifetime = 2.6
		p.one_shot = true
		p.explosiveness = 0.9
		p.emitting = false
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-4, -14, -4), Vector3(8, 16, 8))
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(1.6, 0.1, 1.6)
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 25.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 1.1
		pm.gravity = Vector3(0, -1.4, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.5
		pm.scale_min = 0.6
		pm.scale_max = 1.8
		pm.color_ramp = Props._ramp_tex([[0.0, Color(0.78, 0.74, 0.68, 0.0)], [0.12, Color(0.78, 0.74, 0.68, 0.5)], [1.0, Color(0.7, 0.68, 0.64, 0.0)]])
		p.process_material = pm
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.22, 0.22)
		q.material = Props._particle_mat(Color(1, 1, 1), Color(1, 1, 1), 0.0, false)
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_k_dust.append(p)


func _u10_build_chains() -> void:
	var c: Dictionary = cfg.get("lift_chains", {})
	for pt: Variant in c.get("points", []):
		var v: Array = pt
		var len: float = float(c.get("length", 3.2))
		var n: Node3D = Node3D.new()
		n.name = "HoistChain"
		add_child(n)
		n.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		Props.block(n, Vector3(-0.025, -len, -0.025), Vector3(0.025, 0.0, 0.025), "iron", false)
		Props.block(n, Vector3(-0.07, -len, -0.01), Vector3(0.07, -len + 0.12, 0.01), "iron", false)
		Props.block(n, Vector3(-0.16, -len - 0.5, -0.16), Vector3(0.16, -len, 0.16), "iron", false)   # the hook block
		_k_chains.append({"node": n, "a": 0.0, "v": 0.0, "b": 0.0, "w": 0.0})


func _u10_chains(delta: float) -> void:
	for e: Dictionary in _k_chains:
		if absf(float(e["a"])) < 0.002 and absf(float(e["v"])) < 0.002 and absf(float(e["b"])) < 0.002 and absf(float(e["w"])) < 0.002:
			continue
		e["v"] = float(e["v"]) + (-7.0 * float(e["a"]) - 0.5 * float(e["v"])) * delta
		e["a"] = float(e["a"]) + float(e["v"]) * delta
		e["w"] = float(e["w"]) + (-6.0 * float(e["b"]) - 0.5 * float(e["w"])) * delta
		e["b"] = float(e["b"]) + float(e["w"]) * delta
		(e["node"] as Node3D).rotation = Vector3(float(e["b"]), 0.0, float(e["a"]))
	_k_clank_cd = maxf(0.0, _k_clank_cd - delta)


## The lift chains swing and clank (a shell landed, or the lift moved). `power` 0..1.
func _ev_lift_chains(power: float) -> void:
	var c: Dictionary = cfg.get("lift_chains", {})
	if c.is_empty():
		return
	for e: Dictionary in _k_chains:
		e["v"] = float(e["v"]) + _rng.randf_range(-1.0, 1.0) * 2.2 * power
		e["w"] = float(e["w"]) + _rng.randf_range(-1.0, 1.0) * 1.6 * power
	if _k_clank_cd <= 0.0 and not _k_chains.is_empty():
		_k_clank_cd = float(c.get("cooldown", 0.8))
		var at: Vector3 = ((_k_chains[0] as Dictionary)["node"] as Node3D).global_position
		AudioDirector.play_3d(str(c.get("sound", "")), at, lerpf(-8.0, 0.0, power), 0.0)
		_count("lift_chains")


func _u10_lift(delta: float) -> void:
	if _k_lift == null or not is_instance_valid(_k_lift) or not _k_lift.has_method("cage_y"):
		return
	_k_lift_cd -= delta
	var y: float = float(_k_lift.call("cage_y"))
	if _k_lift_y < 1e8 and absf(y - _k_lift_y) > 0.002 and _k_lift_cd <= 0.0:
		_k_lift_cd = 0.9
		_ev_lift_chains(0.5)
	_k_lift_y = y


## Called when a shell's boom arrives (shell()): dust sifts down in the galleries and the chains swing.
func _u10_on_shell(_bearing: float, km: float) -> void:
	if not dust_falls_for(km, cfg):
		return
	var d: Dictionary = cfg.get("dust_fall", {})
	var power: float = clampf((float(d.get("km", 3.6)) - km) / maxf(0.5, float(d.get("km", 3.6)) - 0.8), 0.25, 1.0)
	_ev_lift_chains(power)
	if _k_dust_cd > 0.0 or _k_dust.is_empty():
		return
	_k_dust_cd = float(d.get("cooldown", 1.2))
	var pts: Array = d.get("points", [])
	if pts.is_empty():
		return
	var cam: Camera3D = _listener()
	var order: Array = pts.duplicate()
	if cam != null:   # the ceilings nearest the listener first, so the dust is where you can see it
		order.sort_custom(func(a: Array, b: Array) -> bool:
			return Vector3(float(a[0]), float(a[1]), float(a[2])).distance_to(cam.global_position) < Vector3(float(b[0]), float(b[1]), float(b[2])).distance_to(cam.global_position))
	var n: int = mini(int(d.get("count", 3)), _k_dust.size())
	for i: int in n:
		var v: Array = order[i] if i < 2 or order.size() <= 2 else order[_rng.randi() % order.size()]
		var p: GPUParticles3D = _k_dust[i]
		p.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		(p.process_material as ParticleProcessMaterial).initial_velocity_max = lerpf(0.6, 1.4, power)
		p.restart()
		if i == 0:
			AudioDirector.play_3d(str(d.get("sound", "")), p.global_position, lerpf(-12.0, -2.0, power), 0.0)
	_count("dust_fall")


# ---- drips

func _u10_drips(delta: float) -> void:
	if not cfg.has("gallery_drips"):
		return
	_k_drip_cd -= delta
	if _k_drip_cd > 0.0:
		return
	var d: Dictionary = cfg.get("gallery_drips", {})
	var ev: Array = d.get("every", [2.5, 6.0])
	_k_drip_cd = _rng.randf_range(float(ev[0]), float(ev[1]))
	_ev_drip(false)


## One drop: found by a ray up from a spot near the listener (the gallery ceiling), falls to the floor and sounds.
func _ev_drip(force: bool) -> void:
	var cam: Camera3D = _listener()
	if cam == null or not is_inside_tree():
		return
	var d: Dictionary = cfg.get("gallery_drips", {})
	if cam.global_position.y > float(d.get("below_y", -3.0)) and not force:
		return
	var r: float = float(d.get("range", 11.0))
	var origin: Vector3 = cam.global_position + Vector3(_rng.randf_range(-r, r), -0.6, _rng.randf_range(-r, r))
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var up: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, 17, 0), 1))
	if up.is_empty():
		return
	var ceil_p: Vector3 = (up["position"] as Vector3) - Vector3(0, 0.05, 0)
	var dn: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(ceil_p - Vector3(0, 0.1, 0), ceil_p - Vector3(0, 19, 0), 1))
	if dn.is_empty():
		return
	var floor_p: Vector3 = dn["position"]
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.018
	sm.height = 0.05
	sm.radial_segments = 6
	sm.rings = 3
	mi.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.7, 0.82, 0.95)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = ceil_p
	var fall: float = sqrt(2.0 * maxf(0.3, ceil_p.y - floor_p.y) / 9.8)
	_k_drops.append({"mi": mi, "from": ceil_p, "to": floor_p, "t": 0.0, "dur": fall, "snd": str(d.get("sound", "")), "db": float(d.get("volume_db", -6.0))})


func _u10_drops(delta: float) -> void:
	for i: int in range(_k_drops.size() - 1, -1, -1):
		var e: Dictionary = _k_drops[i]
		e["t"] = float(e["t"]) + delta
		var u: float = clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		var mi: MeshInstance3D = e["mi"]
		mi.global_position = (e["from"] as Vector3).lerp(e["to"], u * u)
		if u >= 1.0:
			AudioDirector.play_3d(str(e["snd"]), e["to"], float(e["db"]), 0.0)
			mi.queue_free()
			_k_drops.remove_at(i)
			_count("drip")


# ---- salt glints

func _u10_build_glint() -> void:
	var g: Dictionary = cfg.get("salt_glint", {})
	var sh: Shader = load("res://gravelight/world/landscape/shaders/salt_glint.gdshader") as Shader
	if sh == null:
		return
	_k_glint = ShaderMaterial.new()
	_k_glint.shader = sh
	_k_glint.set_shader_parameter("strength", float(g.get("strength", 1.5)))
	_k_glint.set_shader_parameter("lamp_range", float(g.get("range", 16.0)))
	_k_glint.set_shader_parameter("cone_cos", cos(deg_to_rad(float(g.get("cone_deg", 38.0)))))
	var names: Array = g.get("materials", ["mats_halite", "mats_halite_floor", "mats_halite_carved"])
	var seen: Dictionary = {}
	var patched: int = 0
	for n: Node in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if mat != null and names.has(mat.resource_name) and not seen.has(mat):
				seen[mat] = true
				mat.next_pass = _k_glint
				patched += 1
	counts["glint_materials"] = patched


func _u10_glint_update() -> void:
	var cam: Camera3D = _listener()
	if cam == null:
		return
	var below: bool = cam.global_position.y < float((cfg.get("salt_glint", {}) as Dictionary).get("below_y", -2.0))
	_k_glint.set_shader_parameter("lamp_on", 1.0 if below else 0.0)
	_k_glint.set_shader_parameter("lamp_pos", cam.global_position)
	_k_glint.set_shader_parameter("lamp_dir", -cam.global_transform.basis.z)


# ---- U10 Act IV ----
# Mondlicht (data/gravelight/map04d_ambience.json, contract C1, DECISIONS T-158): the Act IV kinds dust_settle,
# crater_shadows, relay_mast, vacuum_muffle, earth_violet, field_units and meteors are handed to one MondlichtLiving
# node (gravelight/world/map04/mondlicht_living.gd). `_kinds_setup_u10_act4` makes it once, only when the file lists
# one of them (Map 0's file lists none: unchanged); the MondlichtController calls it, and a `_kinds_setup_*`
# dispatcher would too (it is guarded). `_ev_<kind>` fires one beat of a kind now (the console and the smokes).
# Every node lookup is guarded; the Moon has no Landscape.

const U10_ACT4_KINDS: PackedStringArray = ["dust_settle", "crater_shadows", "relay_mast", "vacuum_muffle", "earth_violet", "field_units", "meteors"]

var u10_act4: MondlichtLiving = null


func _kinds_setup_u10_act4() -> void:
	if u10_act4 != null or cfg.is_empty() or not is_inside_tree():
		return
	var c: Dictionary = {}
	for k: String in U10_ACT4_KINDS:
		if cfg.has(k):
			c[k] = cfg[k]
	if c.is_empty():
		return
	u10_act4 = MondlichtLiving.new()
	add_child(u10_act4)
	u10_act4.setup(c)


func _ev_dust_settle() -> void:
	if u10_act4 != null:
		u10_act4.puff(Vector3(0.0, 0.0, 80.0))


func _ev_crater_shadows() -> void:
	var t: Node = get_tree().get_first_node_in_group(&"terminator") if is_inside_tree() else null
	if t != null and t.has_method("debug_progress"):
		t.call("debug_progress", minf(1.0, float(t.call("progress")) + 0.1))


func _ev_relay_mast() -> void:
	if not is_inside_tree():
		return
	for m: Node in get_tree().get_nodes_in_group(&"relay_mast"):
		m.call("surge")


func _ev_vacuum_muffle() -> void:
	AudioDirector.call("_set_vacuum_muffle", not bool(AudioDirector.get("muffled")))


func _ev_earth_violet() -> void:
	var sky: Node = get_tree().get_first_node_in_group(&"earth_sky") if is_inside_tree() else null
	if sky != null and sky.has_method("flicker"):
		sky.call("flicker", 1.5)


func _ev_field_units() -> void:
	if u10_act4 != null:
		u10_act4.call("_place_units", 30.0)


func _ev_meteors() -> void:
	if u10_act4 != null:
		u10_act4.far_meteor()


# ---- U10 Act III ----
# Groom Lake's living world (UPDATE 10 section 3, DECISIONS T-157), from data/gravelight/map04c_ambience.json.
#
# Every block below returns at once when its key is not in the file (Map 0 and the other maps are unchanged).
# Presentation only: nothing here touches gameplay (each peer runs its own; the beats key off the round and the
# power, which every peer sees). Kinds: milky_way, heat_shimmer, wildlife (jackrabbits + coyotes), low_pass
# (B-29s on approach), tumbleweeds, searchlight_towers, sand_roofs, quonset (huts ticking in the heat).

var mw_now: float = -1.0                 # the Milky Way's strength now (the smoke)
var shimmer_now: float = 0.0
var rabbits: Array = []                  # {node, home, state, t}
var coyotes: Array = []                  # {node, spot, state, t}
var tumble: Array = []                   # {node, v, spin}
var towers_lit: int = 0
var _sky_sm: ShaderMaterial = null
var _shim_cards: Array[MeshInstance3D] = []
var _shim_mats: Array[ShaderMaterial] = []
var _b29: Array = []                     # {node, from, to, t, dur}
var _towers: Array = []                  # {pivot, beam, light, phase, speed}
var _a3_gust_seen: bool = false
var _sand_pool: Array[GPUParticles3D] = []


# ================================================================== Act III pure rules (unit-tested)

## The Milky Way's strength on beat round `r`: full until rounds[0], gone by rounds[1] (the dawn takes it).
static func milky_way_at(r: int, sec: Dictionary) -> float:
	var rr: Array = sec.get("rounds", [1, 6])
	var st: Array = sec.get("strength", [1.0, 0.0])
	var k: float = clampf(float(r - int(rr[0])) / maxf(1.0, float(int(rr[1]) - int(rr[0]))), 0.0, 1.0)
	return lerpf(float(st[0]), float(st[1]), k)


## The heat shimmer's strength on beat round `r`: none before from_round, full at full_round (the sun is up).
static func shimmer_at(r: int, sec: Dictionary) -> float:
	var a: int = int(sec.get("from_round", 6))
	var b: int = int(sec.get("full_round", a + 2))
	if r < a:
		return 0.0
	return clampf(float(r - a + 1) / maxf(1.0, float(b - a + 1)), 0.0, 1.0)


## True when a critter at `at` should bolt: a player within `near_m` or a shot within `shot_m`.
static func should_bolt(at: Vector3, players: Array, shot_at: Variant, near_m: float, shot_m: float) -> bool:
	for p: Variant in players:
		if Vector2((p as Vector3).x - at.x, (p as Vector3).z - at.z).length() <= near_m:
			return true
	return shot_at != null and Vector2((shot_at as Vector3).x - at.x, (shot_at as Vector3).z - at.z).length() <= shot_m


## The flee direction: straight away from `from`, flat (a random heading when on top of it).
static func flee_dir(at: Vector3, from: Vector3) -> Vector3:
	var d: Vector3 = at - from
	d.y = 0.0
	return d.normalized() if d.length() > 0.05 else Vector3.RIGHT


# ================================================================== setup

func _kinds_setup_u10_act3() -> void:
	if cfg.has("milky_way"):
		_a3_milky_way_setup()
	if cfg.has("heat_shimmer"):
		_a3_shimmer_setup()
	if cfg.has("wildlife"):
		_ev_wildlife_setup()
	if cfg.has("low_pass_b29"):
		_round_fns.append(func(_b: int) -> void: _ev_low_pass_round(_a3_ar()))
		debug_kinds["low_pass_b29"] = func() -> void: _ev_low_pass()
		_ticks.append(_a3_tick_b29)
	if cfg.has("tumbleweeds"):
		_every("tumbleweeds", cfg["tumbleweeds"], _ev_tumbleweeds)
		_ticks.append(_a3_tick_tumble)
		debug_kinds["tumbleweeds"] = func() -> void: _ev_tumbleweeds()
	if cfg.has("searchlight_towers"):
		_a3_towers_setup()
	if cfg.has("sand_roofs"):
		_ticks.append(_a3_tick_sand)
		debug_kinds["sand_roofs"] = func() -> void: _ev_sand_roofs()
	if cfg.has("quonset"):
		_a3_quonset_setup()


# ================================================================== the Milky Way and the dawn's heat

func _a3_milky_way_setup() -> void:
	for n: Node in get_parent().find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env != null and env.sky != null and env.sky.sky_material is ShaderMaterial:
			_sky_sm = env.sky.sky_material as ShaderMaterial
	_round_fns.append(func(_b: int) -> void: _ev_milky_way(_a3_ar()))
	_ev_milky_way(_a3_ar())
	debug_kinds["milky_way"] = func() -> void: _ev_milky_way(1)


func _ev_milky_way(r: int) -> void:
	mw_now = milky_way_at(maxi(1, r), cfg.get("milky_way", {}))
	if _sky_sm != null:
		_sky_sm.set_shader_parameter("milky_way", mw_now)
	_count("milky_way")


func _a3_shimmer_setup() -> void:
	var sec: Dictionary = cfg["heat_shimmer"]
	var sh: Shader = load("res://gravelight/world/map04/shaders/heat_shimmer.gdshader") as Shader
	for c: Variant in sec.get("cards", []):
		var a: Array = c
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "HeatShimmerCard"
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(float(a[3]), float(a[4]))
		mi.mesh = q
		var sm: ShaderMaterial = ShaderMaterial.new()
		sm.shader = sh
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		mi.rotation_degrees = Vector3(0, float(a[5]), 0)
		mi.visible = false
		add_child(mi)
		_shim_cards.append(mi)
		_shim_mats.append(sm)
	_round_fns.append(func(_b: int) -> void: _ev_heat_shimmer(_a3_ar()))
	debug_kinds["heat_shimmer"] = func() -> void: _ev_heat_shimmer(int(sec.get("full_round", 8)))


func _ev_heat_shimmer(r: int) -> void:
	shimmer_now = shimmer_at(r, cfg.get("heat_shimmer", {}))
	for i: int in _shim_cards.size():
		_shim_cards[i].visible = shimmer_now > 0.01
		if sh_has_param(_shim_mats[i], "strength"):
			_shim_mats[i].set_shader_parameter("strength", float((cfg.get("heat_shimmer", {}) as Dictionary).get("strength", 0.008)) * shimmer_now)
	if shimmer_now > 0.0:
		_count("heat_shimmer")


static func sh_has_param(sm: ShaderMaterial, p: String) -> bool:
	if sm == null or sm.shader == null:
		return false
	for u: Dictionary in sm.shader.get_shader_uniform_list():
		if str(u.get("name", "")) == p:
			return true
	return false


# ================================================================== wildlife: jackrabbits on the salt, coyotes on the berms

func _critter_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


## A jackrabbit: a low body, a head, two tall ears (cheap boxes; ~0.5 m long).
func _make_rabbit() -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "Jackrabbit"
	var m: StandardMaterial3D = _critter_mat(Color(0.58, 0.5, 0.4))
	for part: Array in [[Vector3(0.18, 0.2, 0.42), Vector3(0, 0.16, 0)], [Vector3(0.14, 0.14, 0.16), Vector3(0, 0.3, -0.22)],
			[Vector3(0.03, 0.2, 0.05), Vector3(-0.04, 0.45, -0.22)], [Vector3(0.03, 0.2, 0.05), Vector3(0.04, 0.45, -0.22)],
			[Vector3(0.06, 0.06, 0.06), Vector3(0, 0.2, 0.22)]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.position = part[1]
		mi.material_override = m if part[0] != Vector3(0.06, 0.06, 0.06) else _critter_mat(Color(0.92, 0.9, 0.86))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	return n


## A coyote: a lean body, legs, a head with a snout and ears, a low tail (~1.1 m).
func _make_coyote() -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "Coyote"
	var m: StandardMaterial3D = _critter_mat(Color(0.52, 0.44, 0.34))
	for part: Array in [[Vector3(0.26, 0.28, 0.8), Vector3(0, 0.55, 0)], [Vector3(0.2, 0.22, 0.26), Vector3(0, 0.72, -0.48)],
			[Vector3(0.1, 0.1, 0.18), Vector3(0, 0.66, -0.66)], [Vector3(0.05, 0.12, 0.04), Vector3(-0.06, 0.88, -0.44)],
			[Vector3(0.05, 0.12, 0.04), Vector3(0.06, 0.88, -0.44)], [Vector3(0.1, 0.1, 0.42), Vector3(0, 0.5, 0.56)],
			[Vector3(0.07, 0.42, 0.07), Vector3(-0.09, 0.21, -0.3)], [Vector3(0.07, 0.42, 0.07), Vector3(0.09, 0.21, -0.3)],
			[Vector3(0.07, 0.42, 0.07), Vector3(-0.09, 0.21, 0.3)], [Vector3(0.07, 0.42, 0.07), Vector3(0.09, 0.21, 0.3)]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.position = part[1]
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	return n


func _ev_wildlife_setup() -> void:
	var w: Dictionary = cfg["wildlife"]
	for i: int in int(w.get("rabbits", 4)):
		var r: Node3D = _make_rabbit()
		add_child(r, true)
		var home: Vector3 = _a3_rand_in(w.get("area", [[-50, 0, 2], [50, 0, 56]]))
		r.global_position = home
		r.rotation.y = _rng.randf_range(0, TAU)
		rabbits.append({"node": r, "rabbit": true, "home": home, "state": "idle", "t": _rng.randf_range(1.0, 4.0), "v": Vector3.ZERO})
	var spots: Array = w.get("coyote_spots", [])
	for i2: int in mini(int(w.get("coyotes", 2)), spots.size()):
		var c: Node3D = _make_coyote()
		add_child(c, true)
		var sp: Vector3 = _a3_v3(spots[i2])
		c.global_position = sp
		c.rotation.y = _rng.randf_range(0, TAU)
		coyotes.append({"node": c, "rabbit": false, "spot": sp, "state": "idle", "t": 0.0, "v": Vector3.ZERO})
	_ticks.append(_ev_wildlife_tick)
	_shot_fns.append(_ev_wildlife_shot)
	if w.has("yip"):
		_every("coyote_yip", w["yip"], _ev_coyote_yip)
	debug_kinds["wildlife"] = func() -> void:
		for r2: Dictionary in rabbits:
			_bolt(r2, (r2["node"] as Node3D).global_position + Vector3(0, 0, 1), 9.0)
		for c2: Dictionary in coyotes:
			_bolt(c2, (c2["node"] as Node3D).global_position + Vector3(1, 0, 0), 8.0)


func _a3_rand_in(box: Variant) -> Vector3:
	var b: Array = box
	var lo: Vector3 = _a3_v3(b[0])
	var hi: Vector3 = _a3_v3(b[1])
	return Vector3(_rng.randf_range(lo.x, hi.x), lo.y, _rng.randf_range(lo.z, hi.z))


func _bolt(c: Dictionary, from: Vector3, speed: float) -> void:
	if str(c["state"]) == "bolt":
		return
	var node: Node3D = c["node"]
	c["state"] = "bolt"
	c["t"] = 0.0
	c["v"] = flee_dir(node.global_position, from) * speed
	node.look_at(node.global_position - (c["v"] as Vector3), Vector3.UP)
	var key: String = "rabbit_bolt" if bool(c.get("rabbit", false)) else "coyote_yip"
	_a3_snd(key, node.global_position, -4.0)
	_count("wildlife_bolt")


func _ev_wildlife_shot(origin: Vector3) -> void:
	var w: Dictionary = cfg.get("wildlife", {})
	for c: Dictionary in rabbits + coyotes:
		if should_bolt((c["node"] as Node3D).global_position, [], origin, 0.0, float(w.get("shot_bolt_m", 25.0))):
			_bolt(c, origin, float(w.get("rabbit_mps", 9.0)) if bool(c.get("rabbit", false)) else float(w.get("coyote_mps", 8.0)))


func _ev_wildlife_tick(delta: float) -> void:
	var w: Dictionary = cfg.get("wildlife", {})
	var near_m: float = float(w.get("bolt_m", 9.0))
	var pp: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Node3D:
			pp.append((n as Node3D).global_position)
	for c: Dictionary in rabbits + coyotes:
		var node: Node3D = c["node"]
		var rabbit: bool = bool(c.get("rabbit", false))  # not the node name: a second sibling is renamed @Node3D@N
		c["t"] = float(c["t"]) + delta
		match str(c["state"]):
			"idle":
				if should_bolt(node.global_position, pp, null, near_m * (1.0 if rabbit else 2.0), 0.0):
					var from: Vector3 = node.global_position
					var best: float = INF
					for p: Variant in pp:
						var d: float = (p as Vector3).distance_to(node.global_position)
						if d < best:
							best = d
							from = p
					_bolt(c, from, float(w.get("rabbit_mps", 9.0)) if rabbit else float(w.get("coyote_mps", 8.0)))
				elif rabbit and float(c["t"]) > 3.0:
					# a nibble, a hop to a new spot nearby
					c["t"] = _rng.randf_range(-2.0, 0.0)
					node.rotation.y = _rng.randf_range(0, TAU)
			"bolt":
				var v: Vector3 = c["v"]
				node.global_position += v * delta
				# the hop: a bounce in the stride (the rabbit's high, the coyote's a lope)
				var hz2: float = 6.0 if rabbit else 3.2
				node.global_position.y = (c["home"] as Vector3).y if c.has("home") else (c["spot"] as Vector3).y
				node.global_position.y += absf(sin(float(c["t"]) * hz2 * PI)) * (0.35 if rabbit else 0.12)
				if float(c["t"]) > float(w.get("bolt_s", 3.5)):
					c["state"] = "gone"
					c["t"] = 0.0
					node.visible = false
			"gone":
				var rs: Array = w.get("respawn_s", [25.0, 45.0])
				if float(c["t"]) > float(rs[0]):
					c["state"] = "idle"
					c["t"] = 0.0
					node.visible = true
					if rabbit:
						c["home"] = _a3_rand_in(w.get("area", [[-50, 0, 2], [50, 0, 56]]))
						node.global_position = c["home"]
					elif c.has("spot"):
						node.global_position = c["spot"]


func _ev_coyote_yip() -> void:
	for c: Dictionary in coyotes:
		if str(c["state"]) == "idle" and _rng.randf() < 0.7:
			far_sound("coyote_yip", (c["node"] as Node3D).global_position, -2.0)
			_count("coyote_yip")
			return
	# none in view: a far one past the ridge
	far_sound("coyote_yip", Vector3(_rng.randf_range(-300, 300), 0, 260), -8.0)
	_count("coyote_yip")


# ================================================================== B-29s on approach to a distant strip (low_pass_b29)

## A B-29 at a glance: a long round fuselage, a glazed nose, the long wing, four nacelles, the tall fin; landing
## lights burning in the wing roots (emissive, plus one light on the lead ship).
func _make_b29(lead: bool) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "Superfortress"
	var skin: StandardMaterial3D = _critter_mat(Color(0.7, 0.72, 0.74))
	skin.metallic = 0.6
	skin.roughness = 0.4
	var fus: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.4
	cm.height = 30.0
	cm.radial_segments = 10
	fus.mesh = cm
	fus.rotation_degrees = Vector3(90, 0, 0)
	fus.material_override = skin
	n.add_child(fus)
	for part: Array in [[Vector3(43.0, 0.35, 4.6), Vector3(0, -0.2, -2.0)], [Vector3(0.4, 6.0, 4.5), Vector3(0, 3.0, 13.0)], [Vector3(14.0, 0.3, 3.0), Vector3(0, 0.5, 13.5)]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.position = part[1]
		mi.material_override = skin
		n.add_child(mi)
	for x: float in [-14.0, -7.0, 7.0, 14.0]:
		var na: MeshInstance3D = MeshInstance3D.new()
		var nc: CylinderMesh = CylinderMesh.new()
		nc.top_radius = 0.7
		nc.bottom_radius = 0.8
		nc.height = 5.0
		nc.radial_segments = 8
		na.mesh = nc
		na.rotation_degrees = Vector3(90, 0, 0)
		na.position = Vector3(x, -0.5, -3.8)
		na.material_override = skin
		n.add_child(na)
	var lamp: StandardMaterial3D = StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color(1.0, 0.95, 0.8)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.75)
	lamp.emission_energy_multiplier = 8.0
	for x2: float in [-4.0, 4.0]:
		var l: MeshInstance3D = MeshInstance3D.new()
		var sm2: SphereMesh = SphereMesh.new()
		sm2.radius = 0.45
		sm2.height = 0.9
		l.mesh = sm2
		l.position = Vector3(x2, -0.4, -4.4)
		l.material_override = lamp
		n.add_child(l)
	if lead:
		var ol: OmniLight3D = OmniLight3D.new()
		ol.light_color = Color(1.0, 0.92, 0.75)
		ol.light_energy = 3.0
		ol.omni_range = 60.0
		ol.shadow_enabled = false
		ol.position = Vector3(0, -2.0, -6.0)
		n.add_child(ol)
	for c in n.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


func _ev_low_pass_round(r: int) -> void:
	var sec: Dictionary = cfg.get("low_pass_b29", {})
	for x: Variant in sec.get("rounds", []):
		if int(x) == r:   # json numbers are floats
			_beat_after(float(sec.get("delay", 20.0)), _ev_low_pass)


## A formation of `count` B-29s on a long descending approach across the sky to a strip beyond the ridge.
func _ev_low_pass() -> void:
	var sec: Dictionary = cfg.get("low_pass_b29", {})
	var from: Vector3 = _a3_v3(sec.get("from", [-500, 140, 260]))
	var to: Vector3 = _a3_v3(sec.get("to", [700, 40, -220]))
	var offs: Array = sec.get("spacing", [[0, 0, 0], [-26, 4, -18], [-26, 4, 18], [-52, 8, 0]])
	var dir: Vector3 = (to - from).normalized()
	var basis: Basis = Basis.looking_at(dir, Vector3.UP)
	for i: int in mini(int(sec.get("count", 4)), offs.size()):
		var p: Node3D = _make_b29(i == 0)
		add_child(p, true)
		var o: Vector3 = basis * Vector3(float(offs[i][2]), float(offs[i][1]), -float(offs[i][0]))
		p.global_position = from + o
		p.global_basis = basis
		_b29.append({"node": p, "from": from + o, "to": to + o, "t": 0.0, "dur": float(sec.get("seconds", 30.0))})
	far_sound(str(sec.get("sound", "war_bomber_drone")), from.lerp(to, 0.5), 2.0)
	_count("low_pass_b29")


func _a3_tick_b29(delta: float) -> void:
	for i: int in range(_b29.size() - 1, -1, -1):
		var b: Dictionary = _b29[i]
		var node: Node3D = b["node"]
		b["t"] = float(b["t"]) + delta
		var k: float = float(b["t"]) / float(b["dur"])
		if k >= 1.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_b29.remove_at(i)
			continue
		node.global_position = (b["from"] as Vector3).lerp(b["to"], k)


# ================================================================== tumbleweeds across the lake bed

func _make_tumbleweed() -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "Tumbleweed"
	var m: StandardMaterial3D = _critter_mat(Color(0.55, 0.45, 0.3))
	for i: int in 5:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.34
		tm.outer_radius = 0.4
		tm.rings = 10
		tm.ring_segments = 4
		mi.mesh = tm
		mi.rotation = Vector3(_rng.randf_range(0, TAU), _rng.randf_range(0, TAU), 0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	return n


func _ev_tumbleweeds() -> void:
	var sec: Dictionary = cfg.get("tumbleweeds", {})
	if tumble.size() >= int(sec.get("count", 3)):
		return
	var lz: Array = sec.get("lane_z", [4, 56])
	var t: Node3D = _make_tumbleweed()
	add_child(t)
	t.global_position = Vector3(float(sec.get("from_x", -62.0)), 0.4, _rng.randf_range(float(lz[0]), float(lz[1])))
	var sp: Array = sec.get("speed", [3.0, 6.0])
	tumble.append({"node": t, "v": Vector3(_rng.randf_range(float(sp[0]), float(sp[1])), 0, _rng.randf_range(-0.6, 0.6)), "t": 0.0})
	_count("tumbleweeds")


func _a3_tick_tumble(delta: float) -> void:
	var to_x: float = float((cfg.get("tumbleweeds", {}) as Dictionary).get("to_x", 62.0))
	for i: int in range(tumble.size() - 1, -1, -1):
		var tw: Dictionary = tumble[i]
		var node: Node3D = tw["node"]
		tw["t"] = float(tw["t"]) + delta
		var v: Vector3 = tw["v"] as Vector3 * (0.7 + _wind * 0.6)
		node.global_position += v * delta
		node.global_position.y = 0.4 + absf(sin(float(tw["t"]) * 2.3)) * 0.5
		node.rotate_z(-v.x * delta / 0.4)
		if node.global_position.x > to_x:
			node.queue_free()
			tumble.remove_at(i)


# ================================================================== the searchlight towers (dark until the power)

func _a3_towers_setup() -> void:
	var sec: Dictionary = cfg["searchlight_towers"]
	var sh: Shader = load("res://gravelight/world/landscape/shaders/light_beam.gdshader") as Shader
	var iron: StandardMaterial3D = _critter_mat(Color(0.25, 0.25, 0.26))
	var h: float = float(sec.get("height", 12.0))
	for tp: Variant in sec.get("towers", []):
		var base: Vector3 = _a3_v3(tp)
		var tower: Node3D = Node3D.new()
		tower.name = "SearchlightTower"
		add_child(tower)
		tower.global_position = base
		for lx: float in [-1.0, 1.0]:
			for lz: float in [-1.0, 1.0]:
				var leg: MeshInstance3D = MeshInstance3D.new()
				var bm: BoxMesh = BoxMesh.new()
				bm.size = Vector3(0.18, h, 0.18)
				leg.mesh = bm
				leg.position = Vector3(lx * 0.9, h * 0.5, lz * 0.9)
				leg.rotation_degrees = Vector3(-lz * 2.5, 0, lx * 2.5)
				leg.material_override = iron
				tower.add_child(leg)
		var deck: MeshInstance3D = MeshInstance3D.new()
		var dm: BoxMesh = BoxMesh.new()
		dm.size = Vector3(2.6, 0.15, 2.6)
		deck.mesh = dm
		deck.position = Vector3(0, h, 0)
		deck.material_override = iron
		tower.add_child(deck)
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(0, h + 0.8, 0)
		tower.add_child(pivot)
		var head: MeshInstance3D = MeshInstance3D.new()
		var hc: CylinderMesh = CylinderMesh.new()
		hc.top_radius = 0.55
		hc.bottom_radius = 0.6
		hc.height = 0.8
		head.mesh = hc
		head.rotation_degrees = Vector3(90, 0, 0)
		head.material_override = iron
		pivot.add_child(head)
		var beam: MeshInstance3D = MeshInstance3D.new()
		var bc: CylinderMesh = CylinderMesh.new()
		var ln: float = float(sec.get("beam_len", 70.0))
		bc.top_radius = 4.5      # light_beam: the source at -Y (the lamp), the wide end at +Y
		bc.bottom_radius = 0.5
		bc.height = ln
		bc.radial_segments = 16
		bc.rings = 1
		bc.cap_top = false
		bc.cap_bottom = false
		beam.mesh = bc
		beam.rotation_degrees = Vector3(-90, 0, 0)
		beam.position = Vector3(0, 0, -ln * 0.5)
		var bmat: ShaderMaterial = ShaderMaterial.new()
		bmat.shader = sh
		bmat.set_shader_parameter("color", Vector3(0.78, 0.8, 0.88))
		bmat.set_shader_parameter("intensity", float(sec.get("intensity", 0.22)))
		bmat.set_shader_parameter("length_falloff", 1.3)
		bmat.set_shader_parameter("edge_power", 3.0)
		bmat.set_shader_parameter("near_fade", 6.0)
		beam.material_override = bmat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.extra_cull_margin = 20.0
		beam.visible = false
		pivot.add_child(beam)
		beam.set_instance_shader_parameter("beam_len", ln)   # without it the shaft collapses to a ring mid-beam
		var sl: SpotLight3D = SpotLight3D.new()
		sl.light_color = Color(0.95, 0.95, 1.0)
		sl.light_energy = 0.0
		sl.spot_range = ln
		sl.spot_angle = 4.0
		sl.shadow_enabled = false
		sl.set_meta("zone", "B_LAKEBED")
		pivot.add_child(sl)
		pivot.rotation_degrees = Vector3(-float(sec.get("tilt_deg", 14.0)), _rng.randf_range(0, 360), 0)
		_towers.append({"pivot": pivot, "beam": beam, "light": sl, "phase": _rng.randf_range(0, TAU),
			"speed": _rng.randf_range(float((sec.get("sweep", [25, 45]) as Array)[0]), float((sec.get("sweep", [25, 45]) as Array)[1])), "on": false})
	_ticks.append(_a3_tick_towers)
	_power_fns.append(_ev_searchlight_towers)
	if not bool(sec.get("on_power", true)) or GameState.power_on:
		_ev_searchlight_towers()
	debug_kinds["searchlight_towers"] = func() -> void: _ev_searchlight_towers()


## The power: the towers come up one by one (stagger_s apart), each with a clunk.
func _ev_searchlight_towers() -> void:
	var st: float = float((cfg.get("searchlight_towers", {}) as Dictionary).get("stagger_s", 0.8))
	for i: int in _towers.size():
		var tw: Dictionary = _towers[i]
		if bool(tw["on"]):
			continue
		_beat_after(st * float(i + 1), func() -> void:
			tw["on"] = true
			(tw["beam"] as MeshInstance3D).visible = true
			(tw["light"] as SpotLight3D).light_energy = 6.0
			towers_lit += 1
			_a3_snd("power_on", (tw["pivot"] as Node3D).global_position, -10.0)
			_count("searchlight_tower"))


func _a3_tick_towers(delta: float) -> void:
	for tw: Dictionary in _towers:
		if not bool(tw["on"]):
			continue
		var pv: Node3D = tw["pivot"]
		pv.rotation_degrees.y += float(tw["speed"]) * delta * (0.6 + 0.4 * sin(_t * 0.2 + float(tw["phase"])))


# ================================================================== sand blowing off the roofs on a gust

func _make_sand() -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "RoofSand"
	p.amount = 40
	p.lifetime = 2.4
	p.one_shot = true
	p.explosiveness = 0.3
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.1, 6.0)
	pm.direction = Vector3(1, -0.3, 0.2)
	pm.spread = 25.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(1.5, -1.2, 0)
	pm.scale_min = 1.0
	pm.scale_max = 3.0
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.82, 0.72, 0.56, 0.35)
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _a3_tick_sand(_delta: float) -> void:
	var gusting: bool = _gust > 0.85
	if gusting and not _a3_gust_seen:
		_ev_sand_roofs()
	_a3_gust_seen = gusting


func _ev_sand_roofs() -> void:
	for pt: Variant in (cfg.get("sand_roofs", {}) as Dictionary).get("points", []):
		if _rng.randf() < 0.75:
			_a3_burst(_sand_pool, _make_sand, _a3_v3(pt), 6)
	_count("sand_roofs")


# ================================================================== Quonset huts ticking in the heat

func _a3_quonset_setup() -> void:
	var sec: Dictionary = cfg["quonset"]
	var iron: StandardMaterial3D = _critter_mat(Color(0.48, 0.47, 0.44))
	iron.metallic = 0.5
	iron.roughness = 0.55
	for hp: Variant in sec.get("huts", []):
		var a: Array = hp
		var hut: MeshInstance3D = MeshInstance3D.new()
		hut.name = "Quonset"
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = float(a[3]) if a.size() > 3 else 3.2
		cm.bottom_radius = cm.top_radius
		cm.height = float(a[4]) if a.size() > 4 else 12.0
		cm.radial_segments = 14
		hut.mesh = cm
		hut.material_override = iron
		add_child(hut, true)
		hut.global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		hut.rotation_degrees = Vector3(90, float(a[5]) if a.size() > 5 else 0.0, 0)
	_every("quonset", sec, _ev_quonset)
	debug_kinds["quonset"] = func() -> void: _ev_quonset()


func _ev_quonset() -> void:
	var sec: Dictionary = cfg.get("quonset", {})
	var huts: Array = sec.get("huts", [])
	if huts.is_empty():
		return
	# they tick more once the sun is on them
	var hot: bool = _a3_ar() >= int(sec.get("heat_round", 4))
	if not hot and _rng.randf() < 0.5:
		return
	var a: Array = huts[_rng.randi() % huts.size()]
	_a3_snd(str(sec.get("sound", "quonset_tick")), Vector3(float(a[0]), 1.5, float(a[2])), 0.0 if hot else -6.0)
	_count("quonset")


# ================================================================== Act III helpers (own names: the Totenhafen block has its own)

func _a3_snd(key: String, at: Vector3, db: float = 0.0) -> void:
	if key != "" and AudioDirector.has_sound(key):
		AudioDirector.play_3d(key, at, db)


static func _a3_v3(v: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var a: Array = v if v is Array else []
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else fallback


## A one-shot particle burst from a small pool (`make` builds one).
func _a3_burst(pool: Array[GPUParticles3D], make: Callable, at: Vector3, size: int = 4) -> void:
	var p: GPUParticles3D = null
	for q: GPUParticles3D in pool:
		if not q.emitting:
			p = q
			break
	if p == null:
		if pool.size() < size:
			p = make.call() as GPUParticles3D
			add_child(p)
			pool.append(p)
		else:
			p = pool[_rng.randi() % pool.size()]
	p.global_position = at
	p.restart()


## The act round on an act map (RoundManager's own count, robust on a campaign arrival), else the beat round.
func _a3_ar() -> int:
	if RoundManager.has_act():
		return maxi(1, RoundManager.act_round())
	return maxi(1, beat_round())
# ---- U10 Act II ----
# UPDATE 10 §3 (contract C1, DECISIONS T-156): der Kranich's living world, data/gravelight/map04b_ambience.json. Each
# kind is its own block keyed by name and off when the key is absent (Map 0 and the other maps never see them); none
# needs a Landscape. Presentation only, every peer runs its own (the FlightController's tilt is mirrored, so the
# rivets pop on every peer). The file says "needs_landscape": false; `_kinds_setup_u10_act2` (the registry) starts
# the kinds present and puts `_act2_tick` on _ticks.
#   flight_sun     the night turning to dawn across the act: FlightSky.set_sunrise + the Moon light's colour/energy/angle
#   formation      other bombers holding station round the Kranich, bobbing; once per act one is hit by flak and goes
#                  down trailing fire (a squad line, M4B_FORMATION_DOWN)
#   flak_field     flak bursting far out round the formation (FlightSky.burst), from an act round
#   st_elmo        St Elmo's fire: violet-blue glows crawling on the wingtips and the flight-deck frame, brighter in a tilt
#   kranich_frost  condensation and frost on the inner skin (the skin shader's `frost`), rising with the altitude
#   rivets         loose rivets popping (a spark and a ping near the listener) in every tilt
#   engine_pitch   the engine bed's pitch sags and wobbles when the Triebwerk takes damage (blasts in the engine
#                  room, the Bordwart's health)
#   london_hush    the cabin goes quiet for the London window (the Ambience bus ducks while LondonWindow runs)
#   cables         extra cable bundles hung in the group FlightSky swings ("flight_swing") on a tilt

const ACT2_KINDS: PackedStringArray = ["flight_sun", "formation", "flak_field", "st_elmo", "kranich_frost", "rivets",
	"engine_pitch", "london_hush", "cables"]

var _a2_ready: bool = false
var _a2_ticks: Array[Callable] = []
var _a2_t: float = 0.0
var _a2_sky: Node = null
var _a2_fc: Node = null
var _a2_bombers: Array[Dictionary] = []
var _a2_down_round: int = -1
var _a2_down_at: float = -1.0
var _a2_round_t: float = 0.0
var _a2_flak_t: float = 0.0
var _a2_elmo: Array[Dictionary] = []
var _a2_frost: float = 0.0
var _a2_banking: bool = false
var _a2_strain: float = 0.0
var _a2_hush_on: bool = false
var _a2_hush_db: float = 0.0
var _a2_moon: DirectionalLight3D = null
var _a2_moon_base: Dictionary = {}


func _kinds_setup_u10_act2() -> void:
	if _a2_ready or cfg.is_empty():
		return
	_a2_ready = true
	for k: String in ACT2_KINDS:
		if cfg.has(k) and has_method("_ev_" + k):
			call("_ev_" + k, cfg[k] as Dictionary)
	if not _a2_ticks.is_empty():
		GLBus.round_started.connect(func(_r: int, _s: bool) -> void: _a2_round_t = 0.0)
		_ticks.append(_act2_tick)


func _act2_tick(delta: float) -> void:
	if _a2_ticks.is_empty():
		return
	_a2_t += delta
	_a2_round_t += delta
	if _a2_sky == null or not is_instance_valid(_a2_sky):
		_a2_sky = get_tree().get_first_node_in_group(&"flight_sky")
	if _a2_fc == null or not is_instance_valid(_a2_fc):
		_a2_fc = get_tree().get_first_node_in_group(&"flight_controller")
	for f: Callable in _a2_ticks:
		f.call(delta)


func _a2_act_round() -> int:
	return maxi(1, int(RoundManager.act_round())) if RoundManager.has_method("act_round") else maxi(1, RoundManager.current_round)


## The act's progress 0..1 between two act rounds (the round clock's fraction of `round_s` in between).
static func a2_progress(act_round: int, round_t: float, from_round: int, to_round: int, round_s: float = 150.0) -> float:
	var span: float = maxf(1.0, float(to_round - from_round))
	var x: float = float(act_round - from_round) + clampf(round_t / maxf(1.0, round_s), 0.0, 0.99)
	return clampf(x / span, 0.0, 1.0)


func _a2_cam() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3(0, 1.6, 37)


# ---------------------------------------------------------------- flight_sun

func _ev_flight_sun(c: Dictionary) -> void:
	var root: Node = get_parent() if get_parent() != null else get_tree().current_scene
	var lights: Array[Node] = root.find_children("*", "DirectionalLight3D", true, false) if root != null else ([] as Array[Node])
	for n: Node in lights:
		if n.name != "WarFlash":
			_a2_moon = n as DirectionalLight3D
			_a2_moon_base = {"energy": _a2_moon.light_energy, "color": _a2_moon.light_color, "rot": _a2_moon.rotation_degrees}
			break
	_a2_ticks.append(func(_d: float) -> void:
		var k: float = a2_progress(_a2_act_round(), _a2_round_t, int(c.get("from_act_round", 1)), int(c.get("to_act_round", 6)), float(c.get("round_s", 150.0)))
		var dawn: float = clampf(k, 0.0, 1.0) * float(c.get("dawn_max", 0.85))
		if _a2_sky != null and _a2_sky.has_method("set_sunrise"):
			_a2_sky.call("set_sunrise", dawn)
		if _a2_moon != null and not _a2_moon_base.is_empty():
			_a2_moon.light_color = (_a2_moon_base["color"] as Color).lerp(Color(str(c.get("dawn_color", "#ffb27a"))), dawn * 0.7)
			_a2_moon.light_energy = float(_a2_moon_base["energy"]) * lerpf(1.0, float(c.get("dawn_energy_mult", 1.6)), dawn)
		if int(counts.get("sunrise_pct", -1)) != int(dawn * 100.0) / 10 * 10:
			counts["sunrise_pct"] = int(dawn * 100.0) / 10 * 10)


# ---------------------------------------------------------------- formation

func _ev_formation(c: Dictionary) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(str(c.get("color", "#1a1d24")))
	mat.roughness = 0.9
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.albedo_color = Color(0.7, 0.45, 1.0, 0.9)
	var i: int = 0
	for o: Variant in c.get("offsets", []):
		var off: Array = o
		var node: Node3D = Node3D.new()
		node.name = "Formation%d" % i
		add_child(node)
		var base: Vector3 = Vector3(float(off[0]), float(off[1]), float(off[2]))
		node.global_position = base
		var s: float = float(c.get("scale", 1.0))
		var wing: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(150.0, 3.0, 26.0) * s
		wing.mesh = bm
		wing.material_override = mat
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(wing)
		var body: MeshInstance3D = MeshInstance3D.new()
		var bm2: BoxMesh = BoxMesh.new()
		bm2.size = Vector3(18.0, 5.0, 48.0) * s
		body.mesh = bm2
		body.material_override = mat
		body.position = Vector3(0, 1.0, 10.0) * s
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(body)
		for ex: float in [-45.0, -15.0, 15.0, 45.0]:
			var q: MeshInstance3D = MeshInstance3D.new()
			var qm: QuadMesh = QuadMesh.new()
			qm.size = Vector2(9.0, 9.0) * s
			q.mesh = qm
			q.material_override = glow
			q.position = Vector3(ex, 0.5, -14.0) * s
			node.add_child(q)
		_a2_bombers.append({"node": node, "base": base, "phase": float(i) * 1.7, "down": false, "t": 0.0, "trail": null})
		i += 1
	counts["formation"] = _a2_bombers.size()
	var dn: Dictionary = c.get("down", {})
	_a2_ticks.append(func(delta: float) -> void:
		for b: Dictionary in _a2_bombers:
			if not is_instance_valid(b["node"]):
				continue
			var n: Node3D = b["node"] as Node3D
			if bool(b["down"]):
				_a2_fall(b, delta, dn)
				continue
			var ph: float = float(b["phase"])
			n.global_position = (b["base"] as Vector3) + Vector3(sin(_a2_t * 0.13 + ph) * 4.0, sin(_a2_t * 0.31 + ph) * float(c.get("bob_m", 5.0)), 0.0)
			n.rotation = Vector3(sin(_a2_t * 0.23 + ph) * 0.02, 0.0, sin(_a2_t * 0.27 + ph) * 0.05)
		# once per act: one is hit by flak and goes down trailing fire
		if dn.is_empty() or counts.has("formation_down") or _a2_act_round() < int(dn.get("from_act_round", 2)):
			return
		if _a2_down_at < 0.0:
			var at: Array = dn.get("at_s", [60, 140])
			_a2_down_at = _rng.randf_range(float(at[0]), float(at[1]))
		if _a2_round_t >= _a2_down_at:
			formation_hit(int(dn.get("victim", 0))))


## One of the formation is hit (presentation; also the dev console / smoke's hook).
func formation_hit(index: int) -> void:
	if index < 0 or index >= _a2_bombers.size() or bool(_a2_bombers[index]["down"]):
		return
	var b: Dictionary = _a2_bombers[index]
	var n: Node3D = b["node"] as Node3D
	b["down"] = true
	b["t"] = 0.0
	counts["formation_down"] = int(counts.get("formation_down", 0)) + 1
	if _a2_sky != null and _a2_sky.has_method("burst"):
		for k: int in 3:
			_after(0.3 * k, func() -> void:
				if is_instance_valid(n):
					_a2_sky.call("burst", n.global_position + Vector3(_rng.randf_range(-20, 20), _rng.randf_range(-6, 10), _rng.randf_range(-12, 12)), false))
	var trail: CPUParticles3D = CPUParticles3D.new()
	trail.amount = 160
	trail.lifetime = 3.5
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	trail.emission_box_extents = Vector3(30, 1, 4)
	trail.direction = Vector3(0, 0.3, -1)
	trail.spread = 25.0
	trail.gravity = Vector3(0, 2.0, 0)
	trail.initial_velocity_min = 4.0
	trail.initial_velocity_max = 9.0
	trail.scale_amount_min = 3.0
	trail.scale_amount_max = 7.0
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(1, 1)
	trail.mesh = qm
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.vertex_color_use_as_albedo = true
	trail.material_override = fm
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.65, 0.2, 0.9))
	grad.set_color(1, Color(0.15, 0.1, 0.1, 0.0))
	trail.color_ramp = grad
	n.add_child(trail)
	trail.emitting = true
	b["trail"] = trail
	var fl: OmniLight3D = OmniLight3D.new()
	fl.light_color = Color(1.0, 0.55, 0.2)
	fl.light_energy = 6.0
	fl.omni_range = 60.0
	fl.shadow_enabled = false
	n.add_child(fl)
	_after(2.5, func() -> void: _squad_line("M4B_FORMATION_DOWN"))
	print("[ambience] formation bomber %d hit" % index)


func _a2_fall(b: Dictionary, delta: float, dn: Dictionary) -> void:
	var n: Node3D = b["node"] as Node3D
	b["t"] = float(b["t"]) + delta
	var t: float = float(b["t"])
	var fall_s: float = float(dn.get("fall_s", 26.0))
	n.global_position += Vector3(0.0, -lerpf(2.0, 22.0, clampf(t / fall_s, 0, 1)), -6.0) * delta
	n.rotation.x = lerpf(n.rotation.x, -0.5, delta * 0.15)
	n.rotation.z += delta * 0.08
	if t >= fall_s:
		if _a2_sky != null and _a2_sky.has_method("burst"):
			_a2_sky.call("burst", n.global_position, true)
		far_sound("war_crash_boom", n.global_position, -4.0)
		counts["formation_crash"] = 1
		n.queue_free()


# ---------------------------------------------------------------- flak_field

func _ev_flak_field(c: Dictionary) -> void:
	_a2_flak_t = 5.0
	_a2_ticks.append(func(delta: float) -> void:
		if _a2_act_round() < int(c.get("from_act_round", 2)) or _a2_sky == null or not _a2_sky.has_method("burst"):
			return
		_a2_flak_t -= delta
		if _a2_flak_t > 0.0:
			return
		var iv: Array = c.get("interval", [6, 14])
		_a2_flak_t = _rng.randf_range(float(iv[0]), float(iv[1]))
		var r: Array = c.get("radius", [140, 320])
		var dir: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.25, 0.45), _rng.randf_range(-1, 1)).normalized()
		_a2_sky.call("burst", Vector3(0, 0, 37) + dir * _rng.randf_range(float(r[0]), float(r[1])), true)
		counts["flak"] = int(counts.get("flak", 0)) + 1)


# ---------------------------------------------------------------- st_elmo

func _ev_st_elmo(c: Dictionary) -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(str(c.get("color", "#8a8cff")))
	for p: Variant in c.get("points", []):
		var a: Array = p
		var q: MeshInstance3D = MeshInstance3D.new()
		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(1.4, 1.4)
		q.mesh = qm
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		q.global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		q.visible = false
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = m.albedo_color
		l.light_energy = 0.0
		l.omni_range = 5.0
		l.shadow_enabled = false
		q.add_child(l)
		_a2_elmo.append({"q": q, "l": l, "ph": _rng.randf() * TAU})
	_a2_ticks.append(func(_d: float) -> void:
		var on: bool = _a2_act_round() >= int(c.get("from_act_round", 2))
		var tilt: bool = _a2_fc != null and bool(_a2_fc.get("banking"))
		for e: Dictionary in _a2_elmo:
			var q2: MeshInstance3D = e["q"] as MeshInstance3D
			q2.visible = on
			if not on:
				continue
			var fl: float = 0.55 + 0.45 * sin(_a2_t * 23.0 + float(e["ph"])) * sin(_a2_t * 7.3 + float(e["ph"]) * 2.0)
			var k: float = fl * (1.8 if tilt else 1.0)
			q2.scale = Vector3.ONE * (0.6 + 0.6 * k)
			(e["l"] as OmniLight3D).light_energy = 0.8 * k
		if on and not counts.has("st_elmo"):
			counts["st_elmo"] = _a2_elmo.size())


# ---------------------------------------------------------------- kranich_frost

## The frost for an act round (pure): the table's value (rounds past its end keep the last).
static func a2_frost_for(act_round: int, table: Array) -> float:
	if table.is_empty():
		return 0.0
	return clampf(float(table[clampi(act_round - 1, 0, table.size() - 1)]), 0.0, 1.0)


func _ev_kranich_frost(c: Dictionary) -> void:
	_a2_ticks.append(func(delta: float) -> void:
		var target: float = a2_frost_for(_a2_act_round(), c.get("by_act_round", []))
		var nf: float = move_toward(_a2_frost, target, delta * float(c.get("rate_per_s", 0.01)))
		if absf(nf - _a2_frost) < 0.0005 and counts.has("frost"):
			return
		_a2_frost = nf
		for k: Variant in KranichShell._mats.keys():
			var sm: ShaderMaterial = KranichShell._mats[k] as ShaderMaterial
			if sm != null:
				sm.set_shader_parameter("frost", _a2_frost)
		counts["frost"] = int(_a2_frost * 100.0))


# ---------------------------------------------------------------- rivets

func _ev_rivets(c: Dictionary) -> void:
	_a2_ticks.append(func(_d: float) -> void:
		var b: bool = _a2_fc != null and bool(_a2_fc.get("banking"))
		if b and not _a2_banking:
			var pb: Array = c.get("per_bank", [3, 6])
			var n: int = _rng.randi_range(int(pb[0]), int(pb[1]))
			for i: int in n:
				_after(_rng.randf_range(0.2, float(c.get("spread_s", 4.5))), _a2_pop_rivet.bind(float(c.get("radius", 5.0))))
		_a2_banking = b)


func _a2_pop_rivet(radius: float) -> void:
	var cam: Vector3 = _a2_cam()
	var ang: float = _rng.randf() * TAU
	var p: Vector3 = Vector3(cam.x + cos(ang) * _rng.randf_range(1.5, radius), _rng.randf_range(1.9, 3.2), cam.z + sin(ang) * _rng.randf_range(1.5, radius))
	var sp: CPUParticles3D = CPUParticles3D.new()
	sp.one_shot = true
	sp.amount = 10
	sp.lifetime = 0.35
	sp.explosiveness = 1.0
	sp.direction = Vector3(0, -1, 0)
	sp.spread = 70.0
	sp.initial_velocity_min = 2.0
	sp.initial_velocity_max = 5.0
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.015, 0.015, 0.06)
	sp.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.8, 0.45)
	sp.material_override = m
	add_child(sp)
	sp.global_position = p
	sp.emitting = true
	sp.finished.connect(sp.queue_free)
	AudioDirector.play_3d("kranich_rattle", p, -8.0, 0.25)
	counts["rivet"] = int(counts.get("rivet", 0)) + 1


# ---------------------------------------------------------------- engine_pitch

## The engine bed's pitch at a strain (pure): it sags and wobbles as the Triebwerk is hurt.
static func a2_engine_pitch(strain: float, t: float, sag: float = 0.18, wobble: float = 0.04) -> float:
	var s: float = clampf(strain, 0.0, 1.0)
	return 1.0 - sag * s + wobble * s * sin(t * 7.0)


func _ev_engine_pitch(c: Dictionary) -> void:
	var zone: StringName = StringName(str(c.get("zone", "D_TRIEBWERK")))
	GLBus.explosion.connect(func(at: Vector3, _r: float) -> void:
		if ZoneVolume.zone_at(get_tree(), at) == zone:
			_a2_strain = minf(1.0, _a2_strain + float(c.get("per_blast", 0.3))))
	_a2_ticks.append(func(delta: float) -> void:
		var boss: float = 0.0
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if z is HomageBoss and z.is_active() and z.max_hp > 0.0 and ZoneVolume.zone_at(get_tree(), z.global_position) == zone:
					boss = maxf(boss, 1.0 - z.hp / z.max_hp)
		_a2_strain = maxf(boss, _a2_strain - delta * float(c.get("decay_per_s", 0.05)))
		var amb: Variant = AudioDirector.get("_ambient")
		if amb is AudioStreamPlayer:
			(amb as AudioStreamPlayer).pitch_scale = a2_engine_pitch(_a2_strain, _a2_t, float(c.get("sag", 0.18)), float(c.get("wobble", 0.04)))
		if _a2_strain > 0.3:
			counts["engine_strain"] = int(_a2_strain * 100.0))


# ---------------------------------------------------------------- london_hush

func _ev_london_hush(c: Dictionary) -> void:
	var bus: int = AudioServer.get_bus_index(str(c.get("bus", "Ambience")))
	if bus < 0:
		return
	_a2_ticks.append(func(_d: float) -> void:
		var running: bool = false
		var root: Node = get_tree().current_scene
		if root != null:
			for ch: Node in root.get_children():
				if ch is LondonWindow:
					running = true
					break
		if running and not _a2_hush_on:
			_a2_hush_on = true
			_a2_hush_db = AudioServer.get_bus_volume_db(bus)
			var tw: Tween = create_tween()
			tw.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v), _a2_hush_db, _a2_hush_db - float(c.get("duck_db", 16.0)), float(c.get("fade_s", 2.5)))
			counts["london_hush"] = int(counts.get("london_hush", 0)) + 1
		elif not running and _a2_hush_on:
			_a2_hush_on = false
			var tw2: Tween = create_tween()
			tw2.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v), AudioServer.get_bus_volume_db(bus), _a2_hush_db, float(c.get("fade_s", 2.5))))


# ---------------------------------------------------------------- cables

func _ev_cables(c: Dictionary) -> void:
	var m: Material = Mats.get_mat("black_paint")
	var i: int = 0
	for p: Variant in c.get("points", []):
		var a: Array = p
		var pivot: Node3D = Node3D.new()
		pivot.name = "Cable%d" % i
		add_child(pivot)
		pivot.global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		var length: float = float(a[3]) if a.size() > 3 else 1.2
		pivot.set_meta("swing_len", length)
		pivot.add_to_group(&"flight_swing")
		for k: int in 3:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.012
			cm.bottom_radius = 0.012
			cm.height = length - 0.1 * float(k)
			mi.mesh = cm
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0.025 * float(k - 1), -cm.height * 0.5, 0.0)
			pivot.add_child(mi)
		i += 1
	counts["cables"] = i


# ---- U10 Act I ------------------------------------------------------------------------------------------------------
## Fernflug Act I, Werk Thalbach (UPDATE 10 §3, contract C1, DECISIONS T-155; data/gravelight/map04a_ambience.json,
## every kind under its "act1" object so the shared top-level kinds of other blocks never run twice here). The
## map has no Landscape: _setup() hands over to _kinds_setup_act1(), which builds what the file asks for and ticks it
## from a child node (A1Ticker). Presentation only, per peer, seeded the same everywhere; the one gameplay hook is the
## a1_train_arrived signal (the railwayman's favour drops its ammo crate on the host). Kinds (each off when absent):
##   windows_out   the Siedlung's lit windows get their blackout blinds drawn, a few per act round from `from_round`
##   bell          the church bell on the wind (a far toll every `interval` s)
##   low_pass      a test jet's low pass over the runway north of the hangar at act round `round`
##   searchlights  ThalbachSky.apply_cfg (the forest beams, intensity, sweep)
##   train         a locomotive and flatcars run in on the siding behind the goods shed at act round `round`
##                 (then every `every_rounds`): the whistle, steam, sparks on the rails as it brakes
##   kranich_glow  the Kranich's intakes breathing violet up through the hangar's skylight (seen from spawn)
##   rattle        sheet metal rattling on the roofs in the gusts
##   sway          wing sections hanging from the hall cranes swaying with the wind
##   weld          welding sparks and arc light at the jigs and in the hangar
##   posters       fictional-emblem posters (P·W·K's Sunburst-and-Split-Bell, the works' crane in a cog) flapping
##   power_on      the power-on spectacle's extras: the PA crackles hall by hall, the jig gantries jolt, every perk
##                 machine wakes with a sting as its zone lights (the sweep, the fan and the burst are the
##                 PowerSwitch's and the WindTunnel's own)
signal a1_train_arrived(times: int)

class A1Ticker extends Node:
	var cb: Callable
	func _process(d: float) -> void:
		cb.call(d)

var _a1_on: bool = false
var _a1: Dictionary = {}                 # the "act1" object
var _a1_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _a1_t: float = 0.0
var _a1_wind: float = 0.3
var _a1_timers: Dictionary = {}          # kind -> seconds to the next one
var _a1_lit: Array = []                  # LitWindows markers still lit (shuffled once, seeded)
var _a1_blinds: int = 0
var _a1_last_round: int = -1
var _a1_jet: Node3D
var _a1_jet_done: bool = false
var _a1_train: Node3D
var _a1_train_runs: int = 0
var _a1_hangs: Array = []                # {pivot, phase, amp, kick}
var _a1_posters: Array[MeshInstance3D] = []
var _a1_glow: MeshInstance3D
var _a1_power_done: bool = false
## Counters for the smoke (kind -> times).
var a1_counts: Dictionary = {}


func _kinds_setup_act1() -> void:
	if _a1_on:
		return
	_a1 = cfg.get("act1", {})
	if _a1.is_empty():
		return
	_a1_on = true
	_a1_rng.seed = int(_a1.get("seed", 1945))
	var tk: A1Ticker = A1Ticker.new()
	tk.name = "A1Ticker"
	tk.cb = _a1_tick
	add_child(tk)
	GLBus.round_started.connect(_a1_on_round)
	GLBus.power_activated.connect(_ev_a1_power_on)
	(func() -> void:
		_ev_a1_searchlights()
		_a1_build_lit()
		_a1_build_hangs()
		_ev_a1_posters()
		_ev_a1_kranich_glow()
		if GameState.power_on:
			_a1_power_done = true).call_deferred()
	for k: String in ["bell", "rattle", "weld"]:
		var sec: Dictionary = _a1.get(k, {})
		if not sec.is_empty():
			var f: Array = sec.get("first_after", [8, 20])
			_a1_timers[k] = _a1_rng.randf_range(float(f[0]), float(f[1]))


func _a1_count(kind: String) -> void:
	a1_counts[kind] = int(a1_counts.get(kind, 0)) + 1


func _a1_act_round() -> int:
	return RoundManager.act_round() if RoundManager.has_act() else maxi(1, RoundManager.current_round)


func _a1_root() -> Node:
	return get_parent()


func _a1_tick(delta: float) -> void:
	_a1_t += delta
	if not _setup_done:   # the core never set up (no Landscape): the timed calls (_after) are ours to run
		for i: int in range(_later.size() - 1, -1, -1):
			var e: Array = _later[i]
			e[0] = float(e[0]) - delta
			if float(e[0]) <= 0.0:
				_later.remove_at(i)
				(e[1] as Callable).call()
	# the wind: a slow wander with gusts (drives the posters, the rattles, the sways)
	_a1_wind = clampf(0.35 + 0.25 * sin(_a1_t * 0.13) + 0.2 * sin(_a1_t * 0.41 + 1.7) + 0.15 * sin(_a1_t * 1.3), 0.05, 1.0)
	for k: String in _a1_timers.keys():
		_a1_timers[k] = float(_a1_timers[k]) - delta
		if float(_a1_timers[k]) <= 0.0:
			var iv: Array = (_a1.get(k, {}) as Dictionary).get("interval", [10, 20])
			_a1_timers[k] = _a1_rng.randf_range(float(iv[0]), float(iv[1]))
			match k:
				"bell":
					_ev_a1_bell()
				"rattle":
					_ev_a1_rattle()
				"weld":
					_ev_a1_weld()
	for h: Dictionary in _a1_hangs:
		var pv: Node3D = h["pivot"]
		if not is_instance_valid(pv):
			continue
		h["kick"] = maxf(0.0, float(h["kick"]) - delta * 0.6)
		var amp: float = float(h["amp"]) * (_a1_wind + float(h["kick"]) * 2.5)
		pv.rotation.x = deg_to_rad(amp * sin(_a1_t * 0.9 + float(h["phase"])))
		pv.rotation.z = deg_to_rad(amp * 0.4 * sin(_a1_t * 0.7 + float(h["phase"]) * 1.3))
	for pm: MeshInstance3D in _a1_posters:
		if is_instance_valid(pm):
			(pm.material_override as ShaderMaterial).set_shader_parameter("wind", _a1_wind)
	if _a1_glow != null and is_instance_valid(_a1_glow):
		var m: ShaderMaterial = _a1_glow.material_override as ShaderMaterial
		if m != null:
			m.set_shader_parameter("intensity", float((_a1.get("kranich_glow", {}) as Dictionary).get("intensity", 0.22)) * (0.8 + 0.2 * sin(_a1_t * 0.8)))


func _a1_on_round(_r: int, _special: bool) -> void:
	var ar: int = _a1_act_round()
	if ar == _a1_last_round:
		return
	_a1_last_round = ar
	var wo: Dictionary = _a1.get("windows_out", {})
	if not wo.is_empty() and ar >= int(wo.get("from_round", 2)):
		for i: int in int(wo.get("per_round", 2)):
			_after(_a1_rng.randf_range(4.0, float(wo.get("spread_s", 60.0))), _ev_a1_windows_out)
	var lp: Dictionary = _a1.get("low_pass", {})
	if not lp.is_empty() and not _a1_jet_done and ar == int(lp.get("round", 4)):
		_a1_jet_done = true
		_after(float(lp.get("delay", 20.0)), _ev_a1_low_pass)
	var tr: Dictionary = _a1.get("train", {})
	if not tr.is_empty():
		var first: int = int(tr.get("round", 3))
		var every: int = int(tr.get("every_rounds", 4))
		if ar == first or (ar > first and every > 0 and (ar - first) % every == 0):
			_after(float(tr.get("delay", 15.0)), _ev_a1_train)


# ---- windows_out: the blackout

func _a1_build_lit() -> void:
	var holder: Node = _a1_root().get_node_or_null("Gameplay/LitWindows")
	if holder == null:
		return
	for c: Node in holder.get_children():
		if c is Node3D:
			_a1_lit.append(c)
	# the Siedlung's first (its windows face the spawn), then the rest; a seeded shuffle within each
	var sied: Array = _a1_lit.filter(func(n: Node3D) -> bool: return n.global_position.z < 30.0 and n.global_position.x > -1.0)
	var rest: Array = _a1_lit.filter(func(n: Node3D) -> bool: return not sied.has(n))
	_a1_shuffle(sied)
	_a1_shuffle(rest)
	_a1_lit = sied + rest


func _a1_shuffle(a: Array) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = _a1_rng.randi() % (i + 1)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


## One lit window goes dark: its blackout blind is drawn and the room's spill lamp goes out.
func _ev_a1_windows_out() -> void:
	if _a1_lit.is_empty():
		return
	var m: Node3D = _a1_lit.pop_front()
	if not is_instance_valid(m):
		return
	ThalbachLife.blind(self, m)
	var spill: Vector3 = m.global_position + (m.get_meta("out", Vector3.BACK) as Vector3) * 0.53
	for l: Node in _a1_root().find_children("*", "OmniLight3D", true, false):
		var ol: OmniLight3D = l as OmniLight3D
		if ol.global_position.distance_to(spill) < 0.6:
			var tw: Tween = ol.create_tween()
			tw.tween_property(ol, "light_energy", 0.0, 0.6)
	_a1_blinds += 1
	_a1_count("windows_out")


# ---- bell, rattle, weld

func _ev_a1_bell() -> void:
	var b: Dictionary = _a1.get("bell", {})
	var at: Vector3 = ThalbachRaid.v3(b.get("pos", [20.0, 16.0, 90.6]))
	AudioDirector.play_3d(str(b.get("key", "amb_church_bell_far")), at, float(b.get("volume_db", -2.0)) + 6.0 * (_a1_wind - 0.5), 0.02)
	_a1_count("bell")


func _ev_a1_rattle() -> void:
	var r: Dictionary = _a1.get("rattle", {})
	var pts: Array = r.get("points", [])
	if pts.is_empty() or _a1_wind < float(r.get("min_wind", 0.35)):
		return
	var at: Vector3 = ThalbachRaid.v3(pts[_a1_rng.randi() % pts.size()])
	AudioDirector.play_3d(str(r.get("key", "a1_sheet_rattle")), at, -4.0 + 8.0 * _a1_wind, 0.1)
	_a1_count("rattle")


func _ev_a1_weld() -> void:
	var w: Dictionary = _a1.get("weld", {})
	var pts: Array = w.get("points", [])
	if pts.is_empty():
		return
	var at: Vector3 = ThalbachRaid.v3(pts[_a1_rng.randi() % pts.size()])
	var p: GPUParticles3D = ThalbachLife.sparks(self, at, 36, 75.0)
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(0.75, 0.85, 1.0)
	l.light_energy = 0.0
	l.omni_range = 7.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = at + Vector3.UP * 0.3
	var tw: Tween = l.create_tween()
	for i: int in 6:
		tw.tween_property(l, "light_energy", _a1_rng.randf_range(1.5, 3.5), 0.05)
		tw.tween_property(l, "light_energy", 0.3, 0.08)
	tw.tween_property(l, "light_energy", 0.0, 0.2)
	tw.tween_callback(l.queue_free)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	AudioDirector.play_3d(str(w.get("key", "amb_m2_weld")), at, -2.0, 0.1)
	_a1_count("weld")


# ---- sway: the hanging wing sections

func _a1_build_hangs() -> void:
	var sw: Dictionary = _a1.get("sway", {})
	var i: int = 0
	for row: Variant in sw.get("points", []):
		var a: Array = row
		var pv: Node3D = ThalbachLife.hanging_section(self, Vector3(float(a[0]), float(a[1]), float(a[2])), float(a[3]) if a.size() > 3 else 4.0)
		pv.rotation.y = deg_to_rad(float(a[4]) if a.size() > 4 else 0.0)
		_a1_hangs.append({"pivot": pv, "phase": float(i) * 1.9, "amp": float(sw.get("amp_deg", 5.0)), "kick": 0.0})
		i += 1


func _a1_kick_hangs(k: float) -> void:
	for h: Dictionary in _a1_hangs:
		h["kick"] = maxf(float(h["kick"]), k)


# ---- posters, searchlights, the Kranich's glow

func _ev_a1_posters() -> void:
	for row: Variant in (_a1.get("posters", {}) as Dictionary).get("points", []):
		var d: Dictionary = row
		_a1_posters.append(ThalbachLife.poster(self, str(d.get("kind", "kranich")), ThalbachRaid.v3(d.get("pos", [0, 2, 0])), float(d.get("yaw", 0.0))))
	if not _a1_posters.is_empty():
		_a1_count("posters")


func _ev_a1_searchlights() -> void:
	var c: Dictionary = _a1.get("searchlights", {})
	if c.is_empty():
		return
	for s: Node in get_tree().get_nodes_in_group(&"thalbach_sky"):
		if s.has_method("apply_cfg"):
			s.call("apply_cfg", c)
			_a1_count("searchlights")


func _ev_a1_kranich_glow() -> void:
	var g: Dictionary = _a1.get("kranich_glow", {})
	if g.is_empty() or not ResourceLoader.exists("res://gravelight/world/landscape/shaders/light_beam.gdshader"):
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "KranichGlow"
	var len_: float = float(g.get("length", 140.0))
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = float(g.get("top_radius", 14.0))
	cm.bottom_radius = float(g.get("bottom_radius", 6.0))
	cm.height = len_
	cm.radial_segments = 14
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://gravelight/world/landscape/shaders/light_beam.gdshader") as Shader
	m.set_shader_parameter("color", Vector3(0.62, 0.3, 1.0))
	m.set_shader_parameter("intensity", float(g.get("intensity", 0.22)))
	m.set_shader_parameter("length_falloff", 1.6)
	m.set_shader_parameter("edge_power", 2.2)
	m.set_shader_parameter("near_fade", 4.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 40.0
	add_child(mi)
	mi.global_position = ThalbachRaid.v3(g.get("pos", [-20.0, 20.5, 185.0])) + Vector3.UP * len_ * 0.5
	mi.set_instance_shader_parameter("beam_len", len_)
	_a1_glow = mi
	_a1_count("kranich_glow")


# ---- low_pass: the test jet

func _ev_a1_low_pass() -> void:
	var lp: Dictionary = _a1.get("low_pass", {})
	var a: Vector3 = ThalbachRaid.v3(lp.get("from", [-320.0, 46.0, 238.0]))
	var b: Vector3 = ThalbachRaid.v3(lp.get("to", [320.0, 38.0, 238.0]))
	var secs: float = float(lp.get("seconds", 5.4))
	if _a1_jet != null and is_instance_valid(_a1_jet):
		_a1_jet.queue_free()
	_a1_jet = ThalbachLife.jet(self)
	_a1_jet.global_position = a
	_a1_jet.look_at(b, Vector3.UP)
	_a1_jet.rotate_object_local(Vector3.UP, PI * 0.5)   # the model's nose is +X
	var tw: Tween = _a1_jet.create_tween()
	tw.tween_property(_a1_jet, "global_position", b, secs)
	tw.parallel().tween_property(_a1_jet, "rotation:x", deg_to_rad(-18.0), secs).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_a1_jet.queue_free)
	# the roar peaks as it passes the works (the sound's peak sits 45 % into it)
	var mid: Vector3 = (a + b) * 0.5
	_after(maxf(0.0, secs * 0.5 - 8.0 * 0.45), func() -> void:
		AudioDirector.play_3d(str(lp.get("key", "a1_jet_pass")), mid, 8.0, 0.0))
	_after(secs * 0.5, func() -> void:
		_shake(float(lp.get("shake", 0.25)))
		_a1_kick_hangs(0.6))
	_a1_count("low_pass")
	print("[ambience] act1: the test jet's low pass")


# ---- train: the arrival behind the goods shed

func _ev_a1_train() -> void:
	var tr: Dictionary = _a1.get("train", {})
	var stop: Vector3 = ThalbachRaid.v3(tr.get("stop", [48.0, 0.0, 55.5]))
	var start_x: float = float(tr.get("from_x", 260.0))
	var secs: float = float(tr.get("seconds", 14.0))
	if get_node_or_null("Siding") == null:
		ThalbachLife.rails(self, Vector3(stop.x - 6.0, stop.y, stop.z), Vector3(start_x + 60.0, stop.y, stop.z))
	if _a1_train != null and is_instance_valid(_a1_train):
		_a1_train.queue_free()
	_a1_train = ThalbachLife.train(self, int(tr.get("cars", 3)))
	_a1_train.global_position = Vector3(start_x, stop.y, stop.z)
	Props.smoke(_a1_train, Vector3(-4.0, 4.8, 0.0), 0.3, 2.2, 22)
	AudioDirector.play_3d(str(tr.get("whistle", "a1_train_whistle")), Vector3(start_x * 0.5, 6.0, stop.z), 6.0, 0.0)
	var tw: Tween = _a1_train.create_tween()
	tw.tween_property(_a1_train, "global_position:x", stop.x, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# the brakes: sparks off the wheels for the last few seconds, then the steam let off
	var brake: float = float(tr.get("brake_seconds", 4.0))
	_after(maxf(0.0, secs - brake - 0.6), func() -> void:
		AudioDirector.play_3d(str(tr.get("brakes", "a1_train_steam")), stop + Vector3(6.0, 1.0, 0), 4.0, 0.0))
	for i: int in int(brake / 0.3):
		_after(secs - brake + float(i) * 0.3, func() -> void:
			if _a1_train != null and is_instance_valid(_a1_train):
				for wx: float in [-3.6, 0.0, 9.0, 15.0]:
					ThalbachLife.sparks(self, _a1_train.global_position + Vector3(wx, 0.15, 0.9), 10, 40.0)
					ThalbachLife.sparks(self, _a1_train.global_position + Vector3(wx, 0.15, -0.9), 10, 40.0))
	_after(secs, func() -> void:
		_a1_train_runs += 1
		_a1_count("train")
		a1_train_arrived.emit(_a1_train_runs)
		print("[ambience] act1: the train is in (%d)" % _a1_train_runs))


# ---- power_on: the spectacle's extras

func _ev_a1_power_on() -> void:
	if _a1_power_done:
		return
	_a1_power_done = true
	var po: Dictionary = _a1.get("power_on", {})
	if po.is_empty():
		return
	_a1_count("power_on")
	var pw: Dictionary = (GLData.load_json("res://data/gravelight/map04a.json") as Dictionary).get("power", {})
	var start: float = float(pw.get("light_sweep_start", 2.0))
	var gap: float = float(pw.get("light_zone_gap", 0.6))
	var order: PackedStringArray = PackedStringArray()
	for n: Node in get_tree().get_nodes_in_group(&"power_switch"):
		if n.get("zone_order") != null:
			order = n.get("zone_order")
	# the PA horns crackle into life, the Montage first
	var i: int = 0
	for pv: Variant in po.get("pa_points", []):
		var at: Vector3 = ThalbachRaid.v3(pv)
		_after(start + float(i) * 0.4, func() -> void: AudioDirector.play_3d("a1_pa_crackle", at, 4.0, 0.0))
		i += 1
	# the jig gantries jolt: a clank, dust off the girders, the hanging sections kick
	for gv: Variant in po.get("gantry_points", []):
		var g: Vector3 = ThalbachRaid.v3(gv)
		_after(start + 0.2, func() -> void:
			AudioDirector.play_3d("board_slam", g, 2.0, 0.1)
			Effects.dust_puff(g, "stone", 14))
	_after(start + 0.2, func() -> void: _a1_kick_hangs(1.0))
	# every perk machine wakes with a sting as its zone's lights come up
	for n2: Node in _a1_root().find_children("Perk_*", "", true, false):
		var p3: Node3D = n2 as Node3D
		if p3 == null:
			continue
		var z: StringName = ZoneVolume.zone_at(get_tree(), p3.global_position)
		var idx: int = order.find(String(z))
		var at2: Vector3 = p3.global_position + Vector3.UP * 1.2
		_after(start + float(maxi(0, idx)) * gap + 0.3, func() -> void:
			AudioDirector.play_3d(str(po.get("perk_sting", "perk_tier4_sting")), at2, -2.0, 0.05))
	print("[ambience] act1: the power-on spectacle")
