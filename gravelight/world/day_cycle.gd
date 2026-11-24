class_name DayCycle
extends Node3D
## The day (T-259; the owner: "have the map slowly become daytime, one day is 24 rounds on all maps").
## Every round is one hour: round 1 is the map as it was authored (the night), the sky greys from round 6, the sun
## rises in round 7, stands at noon in round 13, sets in round 19, and round 25 is round 1's night again. The hour on
## screen follows the round's hour slowly (`seconds_per_hour`), so a new round never snaps the light.
## Presentation only: nothing here is read by gameplay, and every co-op peer runs its own from the shared round.
##
## What it drives, all from data/gravelight/day_cycle.json (`defaults`, then `maps.<map id>`):
##   the key light   the map's "Moon" DirectionalLight3D is the moon at night (its authored direction, colour and
##                   energy, untouched) and the sun by day (on an arc east -> south -> west, warm at the horizon);
##                   the swap happens in the dark between moonset and first light
##   the air         ambient colour and energy, fog colour and exposure of the map's Environment, blended OVER
##                   whatever the map's other lighting scripts write (DepthGrade, LookZones, LookGrade): each frame
##                   the value found is taken as the night value unless it is the one this node wrote last. Under a
##                   roof the camera gets `indoor_share` of the daylight, below `below_y` none (cellars, the mine)
##   the sky         the Environment's sky material and the cloud domes (Landscape.sky_mat, NightSkyDome): day
##                   colours, the moon's disc becoming the sun's, the stars, the searchlights and the town's glow
##                   fading (shader globals gl_daylight / gl_day_sky, declared in project.godot)
## The pure rules are static for the unit tests (test_day_cycle.gd).

const CONFIG: String = "res://data/gravelight/day_cycle.json"
const NODE_NAME: String = "DayCycle"
const G_DAY: StringName = &"gl_daylight"
const G_SKY: StringName = &"gl_day_sky"
## sky_dome.gdshader's defaults (a headless run cannot ask the server for them).
const DOME_DEFAULTS: Dictionary = {"moon_color": Vector3(0.55, 0.62, 0.85), "moon_gain": 1.9, "deck_light": 0.05,
	"moon_size": 0.021, "moon_dir": Vector3(0.36, 0.64, 0.68), "high_veil": 0.4}

static var _cfg_cache: Dictionary = {}

var cfg: Dictionary = {}
var map: Node
var env: Environment
var key: DirectionalLight3D
## The hour on screen, 0..24 (0 = midnight, 12 = noon).
var hour: float = 0.0
## Dev / captures: >= 0 holds the hour there (hold_hour).
var held_hour: float = -1.0
## What the last frame used (the dev overlay, the tests): day, sun, moon, twilight 0..1.
var now: Dictionary = {"day": 0.0, "sun": 0.0, "moon": 1.0, "twilight": 0.0}
var indoor: float = 0.0
var depth: float = 0.0

var _round_base: int = -1
var _key_basis: Basis
var _key_color: Color
var _key_energy: float = 0.0
var _key_fog: float = 1.0
var _key_wrote: float = -1.0
var _key_muted: bool = false
var _tracks: Dictionary = {}          # property -> {"base": Variant, "wrote": Variant}
var _amb_mult: float = 1.0
var _expo_mult: float = 1.0
var _skies: Array = []                # {mat, night: {name: value}, dome: bool, synced: bool}
var _applied_hour: float = -99.0
var _roof_t: float = 0.0
var _roofed: bool = false
var _snap: bool = true
## T-265: a frame whose inputs are last frame's writes nothing. The hour stands still for the whole of a round once
## it has reached the round's hour, and the camera's share of roof and depth settles within a second or two; until
## now every frame still built the factors, parsed the file's colours, wrote five Environment values, two global
## shader values and the key light's four, and read each one back. `_settled()` is true when the hour, the roof
## and depth shares are the ones last applied and every value this node wrote is still there (another script
## writing one of them, a zone's night value or a room switching the moon off, makes the next frame a full one).
## ENV_PROPS: the Environment values _apply_air drives. SETTLE_EPS: the roof / depth share lands on its target
## once it is this near (an exponential approach never arrives by itself). HOUR_STEP: while the hour walks to the
## round's hour (80 s of every round) the light and the air follow it in steps of this many hours (0.002 h: six
## steps a second, 0.03 degrees of sun each; the sky's own step, _apply_sky, was always this), and exactly once
## more when it arrives.
const ENV_PROPS: PackedStringArray = ["ambient_light_color", "ambient_light_energy", "tonemap_exposure", "fog_light_color", "background_color"]
const SETTLE_EPS: float = 0.001
const HOUR_STEP: float = 0.002
var _at_target: bool = true
var _in_hour: float = -99.0
var _in_indoor: float = -1.0
var _in_depth: float = -1.0
var _key_basis_wrote: Basis = Basis.IDENTITY
var _key_color_wrote: Color = Color.BLACK
var _key_fog_wrote: float = -1.0
## Frames that wrote everything / frames that found nothing to write (the measuring tools, the tests).
var full_frames: int = 0
var skipped_frames: int = 0


# ================================================================== pure rules (unit-tested)

## The settings for `map_id`: the file's `defaults` with `maps.<map_id>` over them ({} when the file is missing).
static func config_for(map_id: String) -> Dictionary:
	if _cfg_cache.is_empty():
		_cfg_cache = GLData.load_json(CONFIG)
	var out: Dictionary = (_cfg_cache.get("defaults", {}) as Dictionary).duplicate(true)
	var own: Dictionary = (_cfg_cache.get("maps", {}) as Dictionary).get(map_id, {})
	for k: Variant in own.keys():
		out[k] = own[k]
	return out


static func reset_cache() -> void:
	_cfg_cache = {}


## The hour of round `r` (1 = the first): `start_hour`, then one day every `rounds_per_day` rounds.
static func hour_for_round(r: int, c: Dictionary) -> float:
	var per: float = maxf(1.0, float(c.get("rounds_per_day", 24)))
	return fposmod(float(c.get("start_hour", 0.0)) + float(maxi(1, r) - 1) * 24.0 / per, 24.0)


## The sun's height in degrees at `h`: `noon_elevation` at noon, the same below the horizon at midnight, on the
## horizon at 6 and 18.
static func sun_elevation(h: float, c: Dictionary) -> float:
	return -cos(h / 24.0 * TAU) * float(c.get("noon_elevation", 38.0))


## The direction TO the sun at `h` (0 = +Z north, 90 = +X east: it rises in the east, stands in the south at noon).
## The height never drops under `min_light_elevation` (a light along the ground only makes shadow noise).
static func sun_dir(h: float, c: Dictionary) -> Vector3:
	var el: float = deg_to_rad(maxf(sun_elevation(h, c), float(c.get("min_light_elevation", 4.0))))
	var az: float = h / 24.0 * TAU
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)).normalized()


## How much of each there is at `h`: `day` (the sky and the air), `sun` (the key light as the sun), `moon` (the key
## light as the authored moon), `twilight` (the warm band while the sun is on the horizon).
static func factors(h: float, c: Dictionary) -> Dictionary:
	var el: float = sun_elevation(h, c)
	var d: Array = c.get("day_span", [-12.0, 20.0])
	var s: Array = c.get("sun_span", [-1.0, 12.0])
	var m: Array = c.get("moon_span", [-14.0, -4.0])
	var tw: float = float(c.get("twilight_width", 9.0))
	var day: float = smoothstep(float(d[0]), float(d[1]), el)
	return {
		"day": day,
		"sun": smoothstep(float(s[0]), float(s[1]), el),
		"moon": 1.0 - smoothstep(float(m[0]), float(m[1]), el),
		"twilight": exp(-(el * el) / maxf(0.01, tw * tw)) * smoothstep(0.02, 0.3, day),
	}


## The next hour on screen: `cur` moves forward toward `target` by `step` hours; a gap of more than `snap_hours`
## (a join in progress, a restart, a debug jump) lands on the target at once.
static func step_hour(cur: float, target: float, step: float, snap_hours: float = 2.5) -> float:
	var gap: float = fposmod(target - cur, 24.0)
	if gap > snap_hours:
		return target
	return fposmod(cur + minf(gap, maxf(0.0, step)), 24.0)


## The share of the daylight the air gets for a camera `under_roof` (0..1) and `below_ground` (0..1).
static func air_share(under_roof: float, below_ground: float, c: Dictionary) -> float:
	return lerpf(1.0, float(c.get("indoor_share", 0.3)), clampf(under_roof, 0.0, 1.0)) * (1.0 - clampf(below_ground, 0.0, 1.0))


## A colour value from the file: "#rrggbb" or [r, g, b].
static func col(v: Variant, fallback: Color = Color.WHITE) -> Color:
	if v is String:
		return Color(v as String)
	if v is Array and (v as Array).size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]), 1.0)
	return fallback


# ================================================================== attach

## Adds the map's DayCycle (MapRoot). Nothing when the file turns the map off or the map has no key light or
## Environment of its own.
static func attach(map_root: Node) -> DayCycle:
	if map_root == null:
		return null
	var old: Node = map_root.get_node_or_null(NODE_NAME)
	if old is DayCycle:
		return old as DayCycle
	var id: String = str(map_root.get("map_id")) if map_root.get("map_id") != null else ""
	var c: Dictionary = config_for(id)
	if c.is_empty() or not bool(c.get("enabled", false)):
		return null
	var we: WorldEnvironment = map_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	var light: DirectionalLight3D = map_root.find_child(str(c.get("key_light", "Moon")), true, false) as DirectionalLight3D
	if we == null or we.environment == null or light == null:
		return null
	var d: DayCycle = DayCycle.new()
	d.name = NODE_NAME
	d.cfg = c
	d.map = map_root
	d.env = we.environment
	d.key = light
	map_root.add_child(d)
	return d


## The map's DayCycle (null when it has none).
static func of(map_root: Node) -> DayCycle:
	return map_root.get_node_or_null(NODE_NAME) as DayCycle if map_root != null else null


func _ready() -> void:
	add_to_group(&"day_cycle")
	process_priority = 1000   # after the map's other lighting scripts: they write the night, this blends the day over it
	if env == null or key == null:
		set_process(false)
		set_physics_process(false)
		return
	_key_basis = key.global_basis.orthonormalized() if key.is_inside_tree() else key.basis.orthonormalized()
	_key_color = key.light_color
	_key_energy = key.light_energy
	_key_fog = key.light_volumetric_fog_energy
	_amb_mult = float(cfg.get("ambient_energy_day", 0.9)) / maxf(0.01, env.ambient_light_energy)
	_expo_mult = float(cfg.get("exposure_day", 1.0)) / maxf(0.01, env.tonemap_exposure)
	_find_skies.call_deferred()
	hour = hour_for_round(_round(), cfg)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(G_DAY, 0.0)


## Dev / captures ("callv:DayCycle:hold_hour:12"): holds the day at `h` (negative lets the rounds run it again).
func hold_hour(h: float) -> void:
	held_hour = h
	_snap = true


## The round the day counts: the match round, or the rounds on this map (`from`: "arrival", a campaign act).
func _round() -> int:
	var r: int = maxi(1, RoundManager.current_round)
	if str(cfg.get("from", "match")) != "arrival":
		return r
	if _round_base < 0:
		_round_base = r - 1
	return maxi(1, r - _round_base)


# ================================================================== the frame

func _physics_process(delta: float) -> void:
	_roof_t -= delta
	if _roof_t > 0.0:
		return
	_roof_t = 0.2
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null or get_world_3d() == null:
		return
	var from: Vector3 = cam.global_position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * float(cfg.get("roof_ray", 45.0)), 1)
	_roofed = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _process(delta: float) -> void:
	var target: float = held_hour if held_hour >= 0.0 else hour_for_round(_round(), cfg)
	var step: float = delta / maxf(1.0, float(cfg.get("seconds_per_hour", 80.0)))
	hour = target if _snap else step_hour(hour, target, step)
	_at_target = hour == target
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var below: float = 1.0 if cam != null and cam.global_position.y < float(cfg.get("below_y", -2.5)) else 0.0
	var k: float = 1.0 if _snap else 1.0 - exp(-delta * float(cfg.get("follow", 1.6)))
	var roof: float = 1.0 if _roofed else 0.0
	indoor = lerpf(indoor, roof, k)
	depth = lerpf(depth, below, k)
	if absf(indoor - roof) < SETTLE_EPS:
		indoor = roof
	if absf(depth - below) < SETTLE_EPS:
		depth = below
	_snap = false
	if _settled():
		skipped_frames += 1
	else:
		full_frames += 1
		now = factors(hour, cfg)
		_apply_key()
		_apply_air()
		_in_hour = hour
		_in_indoor = indoor
		_in_depth = depth
	if absf(hour - _applied_hour) > 0.002:
		_applied_hour = hour
		_apply_sky()


## Pure: may the hour `h` go unapplied, the light and air standing as they were written for `applied`? Yes within
## HOUR_STEP of it, unless the hour has arrived at its target (then only when it is the applied one exactly).
static func hour_settled(h: float, applied: float, at_target: bool, step: float = HOUR_STEP) -> bool:
	if at_target:
		return h == applied
	var gap: float = absf(h - applied)
	return minf(gap, 24.0 - gap) < step


## T-265: nothing this frame would write differs from what is there (see ENV_PROPS above).
func _settled() -> bool:
	if not hour_settled(hour, _in_hour, _at_target) or indoor != _in_indoor or depth != _in_depth:
		return false
	if is_instance_valid(key):
		if not is_equal_approx(key.light_energy, _key_wrote) or key.light_color != _key_color_wrote 				or key.light_volumetric_fog_energy != _key_fog_wrote or not key.global_basis.is_equal_approx(_key_basis_wrote):
			return false
	for prop: String in ENV_PROPS:
		var t: Variant = _tracks.get(prop)
		if t == null or env.get(prop) != (t as Dictionary)["wrote"]:
			return false
	return true


## The key light: the authored moon, nothing in the dark before first light, then the sun on its arc.
func _apply_key() -> void:
	if not is_instance_valid(key):
		return
	# another script switching the moon off for a room (ViewCells) writes 0; its own value coming back lifts that
	if _key_wrote < 0.0 or not is_equal_approx(key.light_energy, _key_wrote):
		_key_muted = _key_wrote >= 0.0 and key.light_energy <= 0.0001
	var sun: float = float(now["sun"])
	var moon: float = float(now["moon"])
	var tw: float = float(now["twilight"])
	var is_sun: bool = sun > 0.0 and moon <= 0.0
	var e: float = _key_energy * moon
	var c: Color = _key_color
	var fog: float = _key_fog
	if is_sun:
		e = float(cfg.get("sun_energy", 1.6)) * sun
		c = col(cfg.get("sun_color", "#fff1dc")).lerp(col(cfg.get("sun_low_color", "#ff9a52")), clampf(tw * 1.2, 0.0, 1.0))
		fog = _key_fog * float(cfg.get("sun_fog_mult", 0.5))
		key.global_basis = Basis.looking_at(-sun_dir(hour, cfg), Vector3.UP)
	else:
		key.global_basis = _key_basis
	key.light_color = c
	key.light_volumetric_fog_energy = fog
	key.light_energy = 0.0 if _key_muted else e
	_key_wrote = key.light_energy
	_key_color_wrote = key.light_color
	_key_fog_wrote = key.light_volumetric_fog_energy
	_key_basis_wrote = key.global_basis


## The value another script (or the scene) holds for `prop` now: what is there, unless it is what this node wrote.
func _base(prop: String) -> Variant:
	var cur: Variant = env.get(prop)
	var t: Dictionary = _tracks.get(prop, {})
	if t.is_empty() or cur != t["wrote"]:
		t = {"base": cur, "wrote": cur}
		_tracks[prop] = t
	return t["base"]


func _put(prop: String, v: Variant) -> void:
	env.set(prop, v)
	(_tracks[prop] as Dictionary)["wrote"] = env.get(prop)


## The night value of an Environment property this node drives (LookZones remembers "what the outside had": it must
## remember the night, not the hour it was read at).
func night_value(prop: String) -> Variant:
	if _tracks.has(prop):
		return (_tracks[prop] as Dictionary)["base"]
	return env.get(prop) if env != null else null


## The night value of `prop` on `e` whichever map it belongs to (the value itself when no DayCycle drives it).
static func night_of(tree: SceneTree, e: Environment, prop: String) -> Variant:
	if tree != null:
		for n: Node in tree.get_nodes_in_group(&"day_cycle"):
			var d: DayCycle = n as DayCycle
			if d != null and d.env == e:
				return d.night_value(prop)
	return e.get(prop) if e != null else null


## The fog colour out of doors at this hour (the Landscape's haze and sky follow it; the Environment's own copy is
## dimmed for a camera under a roof).
func outdoor_fog(night: Color) -> Color:
	return _fog_at(night, float(now["day"]))


func outdoor_background(night: Color) -> Color:
	return night.lerp(col(cfg.get("background_day", "#5273ad")), float(now["day"])).lerp(col(cfg.get("twilight_sky", "#b06a4a")), float(now["twilight"]) * 0.35)


func _fog_at(night: Color, k: float) -> Color:
	return night.lerp(col(cfg.get("fog_day", "#6b7887")), k).lerp(col(cfg.get("twilight_fog", "#80543f")), float(now["twilight"]) * k * 0.6)


func _apply_air() -> void:
	var day: float = float(now["day"])
	var k: float = day * air_share(indoor, depth, cfg)
	_put("ambient_light_color", (_base("ambient_light_color") as Color).lerp(col(cfg.get("ambient_day", "#9eb3d1")), k))
	_put("ambient_light_energy", float(_base("ambient_light_energy")) * lerpf(1.0, _amb_mult, k))
	_put("tonemap_exposure", float(_base("tonemap_exposure")) * lerpf(1.0, _expo_mult, k))
	_put("fog_light_color", _fog_at(_base("fog_light_color") as Color, k))
	_put("background_color", outdoor_background(_base("background_color") as Color))
	RenderingServer.global_shader_parameter_set(G_DAY, day)
	RenderingServer.global_shader_parameter_set(G_SKY, col(cfg.get("cloud_day", "#8c98a8")).lerp(col(cfg.get("twilight_sky", "#b06a4a")), float(now["twilight"]) * 0.5))


# ================================================================== the sky

func _find_skies() -> void:
	_skies.clear()
	if env != null and env.sky != null and env.sky.sky_material != null:
		_add_sky(env.sky.sky_material, false, false)
	if map == null:
		return
	var land: Landscape = map.find_child("Landscape", true, false) as Landscape
	if land == null:
		for n: Node in map.find_children("*", "Node3D", true, false):
			if n is Landscape:
				land = n as Landscape
				break
	if land != null and land.sky_mat != null:
		_add_sky(land.sky_mat, true, true)
	var dome: NightSkyDome = map.get_node_or_null(NightSkyDome.NODE_NAME) as NightSkyDome
	if dome != null and dome.material_override is ShaderMaterial:
		_add_sky(dome.material_override as ShaderMaterial, true, false)
	_applied_hour = -99.0


## `dome`: a sky_dome.gdshader material (it has the moon's disc); `synced`: the Landscape keeps its zenith, horizon and
## cloud tint in step with the Environment, so those three are left to it.
func _add_sky(mat: Material, dome: bool, synced: bool) -> void:
	var night: Dictionary = {}
	var names: Array = (cfg.get("sky_day", {}) as Dictionary).keys()
	if dome:
		names = names + DOME_DEFAULTS.keys()
	for n: Variant in names:
		var name_: String = str(n)
		if name_.begins_with("_") or night.has(name_):
			continue
		var v: Variant = _sky_get(mat, name_, dome)
		if v != null:
			night[name_] = v
	_skies.append({"mat": mat, "night": night, "dome": dome, "synced": synced})


func _sky_get(mat: Material, name_: String, dome: bool) -> Variant:
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat as ShaderMaterial
		var v: Variant = sm.get_shader_parameter(name_)
		if v == null and sm.shader != null:
			var has: bool = false
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				if str(u["name"]) == name_:
					has = true
					break
			if not has:
				return null
			v = RenderingServer.shader_get_parameter_default(sm.shader.get_rid(), name_)
			if v == null and dome:
				v = DOME_DEFAULTS.get(name_)
		return v
	return mat.get(name_) if name_ in mat else null


func _sky_set(mat: Material, name_: String, v: Variant) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(name_, v)
	else:
		mat.set(name_, v)


## A uniform's colour or direction as a Vector3 (a source_color uniform's default comes back as a Color).
static func _v3(v: Variant) -> Vector3:
	if v is Color:
		return Vector3((v as Color).r, (v as Color).g, (v as Color).b)
	return v as Vector3 if v is Vector3 else Vector3.ZERO


## The Landscape's dome colour `name_` ("zenith", "horizon", "cloud_tint") at this hour: its own night value (which it
## derives from the Environment) moved to the file's day sky.
func dome_color(name_: String, night: Vector3) -> Vector3:
	var day_vals: Dictionary = cfg.get("sky_day", {})
	if not day_vals.has(name_):
		return night
	var v: Vector3 = mix_value(night, day_vals[name_], float(now["day"]))
	var tw_vals: Dictionary = cfg.get("sky_twilight", {})
	if tw_vals.has(name_):
		v = mix_value(v, tw_vals[name_], float(now["twilight"]) * 0.6)
	return v


## A night value moved toward a day value by `k`, in the night value's own type (Color, Vector3 or number).
static func mix_value(night: Variant, day: Variant, k: float) -> Variant:
	if night is Color:
		return (night as Color).lerp(col(day, night), k)
	if night is Vector3:
		var dc: Color = col(day, Color((night as Vector3).x, (night as Vector3).y, (night as Vector3).z))
		return (night as Vector3).lerp(Vector3(dc.r, dc.g, dc.b), k)
	if night is float or night is int:
		return lerpf(float(night), float(day), k)
	return night


func _apply_sky() -> void:
	var day: float = float(now["day"])
	var tw: float = float(now["twilight"])
	var sun: float = float(now["sun"])
	var is_sun: bool = sun > 0.0 and float(now["moon"]) <= 0.0
	var day_vals: Dictionary = cfg.get("sky_day", {})
	var tw_vals: Dictionary = cfg.get("sky_twilight", {})
	for s: Dictionary in _skies:
		var mat: Material = s["mat"]
		var night: Dictionary = s["night"]
		for n: Variant in day_vals.keys():
			var name_: String = str(n)
			if not night.has(name_) or (bool(s["synced"]) and name_ in ["zenith", "horizon", "cloud_tint"]):
				continue
			var v: Variant = mix_value(night[name_], day_vals[n], day)
			if tw_vals.has(name_):
				v = mix_value(v, tw_vals[name_], tw * 0.6)
			_sky_set(mat, name_, v)
		if not bool(s["dome"]):
			continue
		# the disc: the authored moon, hidden in the dark before first light, then the sun where the key light is
		var mc: Vector3 = _v3(night.get("moon_color", DOME_DEFAULTS["moon_color"]))
		var gain: float = float(night.get("moon_gain", 1.9)) * float(now["moon"])
		var deck: float = float(night.get("deck_light", 0.05)) * float(now["moon"])
		var dir: Vector3 = _v3(night.get("moon_dir", DOME_DEFAULTS["moon_dir"]))
		if is_sun:
			var sc: Color = col(cfg.get("sun_color", "#fff1dc")).lerp(col(cfg.get("sun_low_color", "#ff9a52")), clampf(tw * 1.2, 0.0, 1.0))
			mc = Vector3(sc.r, sc.g, sc.b)
			gain = float(cfg.get("sun_disc_gain", 5.0)) * sun
			deck = float(cfg.get("deck_light_day", 0.3)) * maxf(sun, day * 0.5)
			dir = sun_dir(hour, cfg)
		else:
			deck = maxf(deck, float(cfg.get("deck_light_day", 0.3)) * day * 0.5)
		_sky_set(mat, "moon_color", mc)
		_sky_set(mat, "moon_gain", gain)
		_sky_set(mat, "deck_light", deck)
		_sky_set(mat, "moon_dir", dir)
		_sky_set(mat, "sun_k", 1.0 if is_sun else 0.0)
