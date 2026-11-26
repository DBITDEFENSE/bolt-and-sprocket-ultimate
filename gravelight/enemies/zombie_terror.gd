class_name ZombieTerror
extends Node
## T-284 (the owner: "MAKE THE ZOMBIES MORE TERRIFYING"): the horde-level half of the scare, presentation only.
## Data: data/gravelight/zombie_terror.json. Zombie.t284_terror (CZ_T284_OFF=1) switches all of it off.
##
## The director owns one of these (host and co-op client alike: every peer scares its own player). Four times a second
## (horde.tick_s) it counts the bodies round the local player and finds the nearest one:
##   - the nearest body within voice.breath_m breathes at the player (a ragged wet breath, rate-limited);
##   - enter_count or more within horde.radius_m start a horde moment: a low swell of sound (once per gap_s), the fog
##     thickens (fog_mult, eased in and out, not while the special round's own fog holds) and the lamps near the
##     player flicker harder (FlickerLight's own wobble, deeper and faster, put back after).
## It also holds the horde-wide rate caps the zombies ask before they scream or crack a joint, and the random numbers
## for all of it (its own generator: the game's global one, which decides crawlers and the like, is never touched).
## Nothing here is read by gameplay; the per-zombie parts live in Zombie (_terror_*).

const PATH: String = "res://data/gravelight/zombie_terror.json"
static var _cfg: Dictionary = {}
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _next_scream_ms: int = 0
static var _next_crack_ms: int = 0
## Counters for the measuring tools and tests.
static var screams: int = 0
static var first_sights: int = 0
static var twitches: int = 0
static var breaths: int = 0
static var horde_moments: int = 0

var director: Node = null
var _t: float = 0.0
var _breath_t: float = 0.0
var _in_horde: bool = false
var _below_t: float = 0.0
var _next_swell_ms: int = 0
var _env: Environment = null
var _fog_base: float = -1.0
var _fog_tw: Tween = null
var _lamps: Array = []   # [FlickerLight, amount, speed] while a horde moment holds them
var nearest_d: float = INF
var near_count: int = 0


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(PATH)
	return _cfg


static func sec(name: String) -> Dictionary:
	return cfg().get(name, {}) as Dictionary


static func enabled() -> bool:
	return Zombie.t284_terror and not cfg().is_empty()


static func range_f(a: Variant) -> float:
	var arr: Array = a as Array
	return rng.randf_range(float(arr[0]), float(arr[1]))


## May a scream play now? (one at a time across the horde, first_sight.scream_gap_s apart)
static func scream_ok() -> bool:
	var now: int = Time.get_ticks_msec()
	if now < _next_scream_ms:
		return false
	_next_scream_ms = now + int(float(sec("first_sight").get("scream_gap_s", 2.2)) * 1000.0)
	screams += 1
	return true


static func crack_ok() -> bool:
	var now: int = Time.get_ticks_msec()
	if now < _next_crack_ms:
		return false
	_next_crack_ms = now + int(float(sec("twitch").get("crack_gap_s", 0.6)) * 1000.0)
	return true


## The per-instance look of one body (the skin shader's inst_terror), rolled from its look seed so every co-op peer
## sees the same eyes: x eye glow, y wet, z rot, w 0 violet eyes / 1 amber.
static func look_vec(look_seed: int) -> Vector4:
	var lk: Dictionary = sec("look")
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = look_seed * 7919 + 284
	var g: Array = lk.get("eye_glow", [1.6, 2.6])
	var w: Array = lk.get("wet", [0.45, 0.85])
	var ro: Array = lk.get("rot", [0.35, 0.8])
	return Vector4(r.randf_range(float(g[0]), float(g[1])), r.randf_range(float(w[0]), float(w[1])),
		r.randf_range(float(ro[0]), float(ro[1])), 1.0 if r.randf() < float(lk.get("amber_chance", 0.18)) else 0.0)


## The skin material's terror uniforms (the eye centres in the shared rig's rest space and the colours).
static func apply_material(m: ShaderMaterial) -> void:
	var lk: Dictionary = sec("look")
	if lk.is_empty():
		return
	m.set_shader_parameter("eye_centre", Vector3(float(lk.get("eye_centre_x", 0.0345)), float(lk.get("eye_centre_y", 1.7213)), float(lk.get("eye_centre_z", -0.0757))))
	m.set_shader_parameter("eye_radius", float(lk.get("eye_radius", 0.0175)))
	for pair: Array in [["eye_violet", "eye_violet"], ["eye_amber", "eye_amber"], ["rot_color", "rot_color"]]:
		var c: Color = Color.html(str(lk.get(pair[1], "#ffffff"))).srgb_to_linear()
		m.set_shader_parameter(str(pair[0]), Vector3(c.r, c.g, c.b))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT


func _exit_tree() -> void:
	_end_horde(true)


func _process(delta: float) -> void:
	if not enabled() or director == null:
		if _in_horde:
			_end_horde(false)
		return
	_t -= delta
	_breath_t -= delta
	if _t > 0.0:
		return
	var h: Dictionary = sec("horde")
	_t = float(h.get("tick_s", 0.25))
	var lp: Node3D = _local_player()
	if lp == null:
		return
	var at: Vector3 = lp.global_position
	var radius: float = float(h.get("radius_m", 10.0))
	var nearest: Zombie = null
	nearest_d = INF
	near_count = 0
	for z: Zombie in director.call("active_zombies"):
		if z.state == Zombie.State.DEAD or z.state == Zombie.State.INACTIVE:
			continue
		var d: float = z.global_position.distance_to(at)
		if d < radius:
			near_count += 1
		if d < nearest_d:
			nearest_d = d
			nearest = z
	_tick_breath(nearest)
	_tick_horde(lp, h)


func _local_player() -> Node3D:
	var map: Node = director.get_parent()
	var p: Variant = map.get("player") if map != null else null
	return p as Node3D


func _tick_breath(nearest: Zombie) -> void:
	var v: Dictionary = sec("voice")
	if nearest == null or nearest_d > float(v.get("breath_m", 3.6)) or _breath_t > 0.0:
		return
	if nearest.state not in [Zombie.State.CHASE, Zombie.State.ATTACK, Zombie.State.TEAR, Zombie.State.WAIT_WINDOW, Zombie.State.STAGGER]:
		return
	_breath_t = range_f(v.get("breath_every_s", [1.5, 2.6]))
	breaths += 1
	AudioDirector.play_3d("zombie_breath_close", nearest.global_position + Vector3.UP * 1.55, float(v.get("breath_db", -4.0)), 0.05)


func _tick_horde(lp: Node3D, h: Dictionary) -> void:
	if not _in_horde:
		if near_count >= int(h.get("enter_count", 8)):
			_start_horde(lp, h)
		return
	if near_count < int(h.get("exit_count", 5)):
		_below_t += float(h.get("tick_s", 0.25))
		if _below_t >= float(h.get("exit_s", 3.0)):
			_end_horde(false)
	else:
		_below_t = 0.0


func _start_horde(lp: Node3D, h: Dictionary) -> void:
	_in_horde = true
	_below_t = 0.0
	horde_moments += 1
	var now: int = Time.get_ticks_msec()
	if now >= _next_swell_ms:
		_next_swell_ms = now + int(float(h.get("gap_s", 25.0)) * 1000.0)
		AudioDirector.play_2d("horde_swell", float(h.get("swell_db", -3.0)), 0.02)
	# the fog: not over the special round's own (the director tweens the same value then)
	if not bool(director.get("_special_fx")):
		if _env == null:
			_env = director.call("_find_env") as Environment
		if _env != null:
			if _fog_base < 0.0:
				_fog_base = _env.fog_density
			_tween_fog(_fog_base * float(h.get("fog_mult", 1.5)), float(h.get("fog_in_s", 2.5)))
	# the lamps near the player flicker harder (their own wobble; put back when the moment ends)
	_lamps.clear()
	var lamp_m: float = float(h.get("lamp_m", 18.0))
	var found: Array = []
	for n: Variant in _find_lamps():
		var fl: FlickerLight = n as FlickerLight
		if fl == null or not fl.is_visible_in_tree():
			continue
		var d: float = fl.global_position.distance_to(lp.global_position)
		if d <= lamp_m:
			found.append([d, fl])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var depth: float = float(h.get("flicker_depth", 0.55))
	for e: Array in found.slice(0, int(h.get("max_lamps", 6))):
		var fl2: FlickerLight = e[1]
		_lamps.append([fl2, fl2.amount, fl2.speed])
		fl2.amount = fl2.amount + depth
		fl2.speed = fl2.speed * 1.8


var _lamp_cache: Array = []


## Every FlickerLight of the map, found once (a horde moment is rare; the walk is not done every tick).
func _find_lamps() -> Array:
	if _lamp_cache.is_empty():
		var map: Node = director.get_parent()
		if map != null:
			_lamp_cache = map.find_children("*", "FlickerLight", true, false)
	var out: Array = []
	for l: Variant in _lamp_cache:
		if is_instance_valid(l):
			out.append(l)
	return out


func _tween_fog(to: float, secs: float) -> void:
	if _env == null:
		return
	if _fog_tw != null and _fog_tw.is_valid():
		_fog_tw.kill()
	_fog_tw = create_tween()
	_fog_tw.tween_property(_env, "fog_density", to, secs)


func _end_horde(at_once: bool) -> void:
	_in_horde = false
	for e: Array in _lamps:
		if is_instance_valid(e[0]):
			(e[0] as FlickerLight).amount = float(e[1])
			(e[0] as FlickerLight).speed = float(e[2])
	_lamps.clear()
	if _env != null and _fog_base >= 0.0 and not bool(director.get("_special_fx") if director != null else false):
		if at_once or not is_inside_tree():
			if _fog_tw != null and _fog_tw.is_valid():
				_fog_tw.kill()
			_env.fog_density = _fog_base
		else:
			_tween_fog(_fog_base, float(sec("horde").get("fog_out_s", 3.5)))


## The special round is about to thicken the fog from what it finds: put ours back first, at once.
func release_fog() -> void:
	if _env != null and _fog_base >= 0.0:
		if _fog_tw != null and _fog_tw.is_valid():
			_fog_tw.kill()
		_env.fog_density = _fog_base


func in_horde() -> bool:
	return _in_horde
