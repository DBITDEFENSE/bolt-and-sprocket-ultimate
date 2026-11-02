class_name EarthSky
extends Node3D
## The Earth over the yard (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.2, T-112): a sky object far above the
## relay. Its night side carries violet points for the burned cities (GameState.flags: bomb_<city>_hit from the
## bomb run, London from the window), the retention signal's reach `spread` grows a little each act round from
## `spread_from_round` (data: map04d.json "earth"), `cut()` freezes the spread and fades every point out over
## `fade_seconds` (the relay is cut: the canon ending), `renew()` floods the night side violet over 10 s (the bad
## ending), `flicker()` blinks it for the Solar Flare. Pure rules are static for the tests.

const CITIES: Dictionary = {   # city key -> [lat, long] on the night side (degrees; presentation only)
	"london": [51.5, -0.1], "boston": [42.4, -71.1], "providence": [41.8, -71.4], "new_haven": [41.3, -72.9],
	"new_york": [40.7, -74.0], "philadelphia": [39.9, -75.2], "washington": [38.9, -77.0]}

@export var radius: float = 48.0
@export var cfg: Dictionary = {}

var spread: float = 0.0            # 0..1 of the night side under the signal (presentation + the tests)
var frozen: bool = false
var faded: bool = false
var renewed: bool = false
var points: Dictionary = {}        # city -> MeshInstance3D
var _spread_nodes: Array[MeshInstance3D] = []
var _night: MeshInstance3D
var _day: MeshInstance3D
var _light: DirectionalLight3D
var _flicker_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _point_mat: StandardMaterial3D = null


## The cities lit violet by the flags: London once the window has played, every bombed city (bomb_<city>_hit).
static func violet_cities(flags: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if bool(flags.get(&"london_seen", false)) or bool(flags.get(&"london_hit", false)):
		out.append("london")
	for c: String in CITIES.keys():
		if c == "london":
			continue
		if bool(flags.get(StringName("bomb_%s_hit" % c), false)):
			out.append(c)
	return out


## The signal's reach on an act round: 0 before `from_round`, `per_round` more each round after, never past `cap`.
static func spread_for(act_round: int, from_round: int, per_round: float, cap: float) -> float:
	if act_round < from_round:
		return 0.0
	return clampf(float(act_round - from_round + 1) * per_round, 0.0, cap)


func _ready() -> void:
	add_to_group(&"earth_sky")
	_rng.seed = 4041
	_build()
	refresh_from_flags()
	GLBus.flag_changed.connect(func(_f: StringName, _v: Variant) -> void: refresh_from_flags())
	GLBus.round_started.connect(_on_round_started)
	GLBus.quest_step_completed.connect(_on_step_completed)   # UPDATE 10 (T-158): the cancel steps reverse the spread


func _build() -> void:
	_day = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 48
	sm.rings = 24
	_day.mesh = sm
	# U09 s5 (T-149): oceans, continents, ice, clouds and a soft terminator from earth.gdshader, lit from the
	# act's sun_dir (map04d.json earth), and a thin additive halo of atmosphere at the limb
	var sun: Array = cfg.get("sun_dir", [0.88, 0.26, -0.31])
	var sun_dir: Vector3 = Vector3(float(sun[0]), float(sun[1]), float(sun[2])).normalized()
	var dm: ShaderMaterial = ShaderMaterial.new()
	dm.shader = load("res://gravelight/world/map04/earth.gdshader") as Shader
	dm.set_shader_parameter("sun_dir", sun_dir)
	_day.material_override = dm
	_day.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_day)
	var halo: MeshInstance3D = MeshInstance3D.new()
	halo.name = "Halo"
	var hm: SphereMesh = SphereMesh.new()
	hm.radius = radius * 1.045
	hm.height = radius * 2.09
	hm.radial_segments = 48
	hm.rings = 24
	halo.mesh = hm
	var hmat: ShaderMaterial = ShaderMaterial.new()
	hmat.shader = load("res://gravelight/world/map04/earth_halo.gdshader") as Shader
	hmat.set_shader_parameter("sun_dir", sun_dir)
	halo.material_override = hmat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	# the night side: a hemisphere a hair outside the globe turned toward the yard; transparent while the shader
	# draws the night (T-149), it is what renew() floods violet
	_night = MeshInstance3D.new()
	var nm: SphereMesh = SphereMesh.new()
	nm.radius = radius * 1.01
	nm.height = radius * 1.01
	nm.is_hemisphere = true
	nm.radial_segments = 48
	nm.rings = 12
	_night.mesh = nm
	var nmat: StandardMaterial3D = StandardMaterial3D.new()
	nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nmat.disable_fog = true
	nmat.albedo_color = Color(0.02, 0.025, 0.05, 0.0)
	_night.material_override = nmat
	_night.rotation_degrees = Vector3(-90, 0, 0)   # the hemisphere's dome faces -Z (toward the base, "down" the sky)
	_night.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_night)
	# the terminator's glow: a thin ring of cloud light
	_light = DirectionalLight3D.new()
	_light.name = "Earthlight"
	_light.light_color = Color(0.5, 0.65, 1.0)
	_light.light_energy = 0.35
	_light.shadow_enabled = false
	_light.rotation_degrees = Vector3(-80, 0, 0)
	add_child(_light)
	for c: String in CITIES.keys():
		var m: MeshInstance3D = _point(_city_pos(c), 1.1)
		m.visible = false
		points[c] = m


func _point(pos: Vector3, size: float) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var pm: SphereMesh = SphereMesh.new()
	pm.radius = size
	pm.height = size * 2.0
	pm.radial_segments = 8
	pm.rings = 4
	m.mesh = pm
	if _point_mat == null:   # T-149: a fog-free violet glow, so the pinpricks read across the black
		_point_mat = StandardMaterial3D.new()
		_point_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_point_mat.albedo_color = Color(0.85, 0.55, 1.0)
		_point_mat.disable_fog = true
	m.material_override = _point_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	add_child(m)
	return m


## A city's place on the night hemisphere (lat/long folded onto the face the base sees).
func _city_pos(c: String) -> Vector3:
	var ll: Array = CITIES[c]
	var lat: float = deg_to_rad(float(ll[0]))
	var lon: float = deg_to_rad(float(ll[1]) + 40.0)   # the night side's centre at 40 W
	var r: float = radius * 1.02
	return Vector3(r * cos(lat) * sin(lon), r * sin(lat) * 0.9, -r * cos(lat) * cos(lon))


func refresh_from_flags() -> void:
	if faded:
		return
	for c: String in violet_cities(GameState.flags):
		var m: MeshInstance3D = points.get(c) as MeshInstance3D
		if m != null:
			m.visible = true


func _on_round_started(r: int, _special: bool) -> void:
	if frozen or faded or renewed or cfg.is_empty():
		return
	var ar: int = RoundManager.act_round(r) if RoundManager.has_act() else r
	base_spread = spread_for(ar, int(cfg.get("spread_from_round", 3)), float(cfg.get("spread_per_round", 0.04)), float(cfg.get("spread_cap", 0.6)))
	_apply_reversal()


## The signal's reach: `f` of the night side's points lit (seeded, so a value always draws the same picture).
func set_spread(f: float) -> void:
	spread = clampf(f, 0.0, 1.0)
	var want: int = int(round(spread * float(cfg.get("spread_points", 40))))
	while _spread_nodes.size() < want:
		var lat: float = deg_to_rad(_rng.randf_range(-55.0, 65.0))
		var lon: float = deg_to_rad(_rng.randf_range(-70.0, 70.0))
		var r: float = radius * 1.02
		_spread_nodes.append(_point(Vector3(r * cos(lat) * sin(lon), r * sin(lat) * 0.9, -r * cos(lat) * cos(lon)), 0.55))
	for i: int in _spread_nodes.size():
		_spread_nodes[i].visible = i < want


## The relay is cut: the spread stops where it is and every point fades out over `fade_seconds`.
func cut() -> void:
	frozen = true
	var secs: float = float(cfg.get("fade_seconds", 60.0)) / maxf(0.01, Campaign.cutscene_speed)
	var all: Array = points.values() + Array(_spread_nodes)
	for m: Variant in all:
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi == null or not mi.visible:
			continue
		var tw: Tween = create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, secs).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void: mi.visible = false)
	get_tree().create_timer(secs + 0.1).timeout.connect(func() -> void: faded = true)


## The plan renews: the whole night side goes violet over 10 s and stays.
func renew() -> void:
	renewed = true
	frozen = true
	var mat: StandardMaterial3D = _night.material_override as StandardMaterial3D
	if mat != null:
		var tw: Tween = create_tween()
		tw.tween_property(mat, "albedo_color", Color(0.42, 0.16, 0.7), 10.0 / maxf(0.01, Campaign.cutscene_speed))
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.1, 0.5)
		tw.parallel().tween_property(mat, "emission_energy_multiplier", 1.6, 10.0 / maxf(0.01, Campaign.cutscene_speed))
	set_spread(1.0)


## The Solar Flare: the Earth blinks for `seconds`.
func flicker(seconds: float = 3.0) -> void:
	_flicker_t = seconds


func _process(delta: float) -> void:
	if _flicker_t > 0.0:
		_flicker_t -= delta
		var on: bool = fmod(_flicker_t, 0.3) < 0.15
		_day.visible = on or _flicker_t <= 0.0
		if _flicker_t <= 0.0:
			_day.visible = true


# ---- U10 Act IV (T-158): the Earthrise beats ----
# The violet spread grows with the act's rounds (base_spread, above) and REVERSES as the Kündigung's cancel steps
# complete: each completed step of map04d.json earth.reverse_steps takes 1/n of it away (reversed_spread); the city
# points shrink with it; with all of them done (s18_cancel is CANCEL) the night side turns dark blue. The
# MondlichtController voices it (earth.vo_dim by steps done, earth.vo_spread by act round).

var base_spread: float = 0.0
var steps_done: int = -1
var dark_blue: bool = false


## The spread left after `done` of `total` cancel steps: each takes an equal share away.
static func reversed_spread(base: float, done: int, total: int) -> float:
	if total <= 0:
		return base
	return clampf(base * (1.0 - float(clampi(done, 0, total)) / float(total)), 0.0, 1.0)


## How many of the reverse steps are complete (QuestManager; 0 when the quest is not loaded).
func count_steps_done() -> int:
	var q: StringName = StringName(str(cfg.get("reverse_quest", "map04_kuendigung")))
	var n: int = 0
	for sid: Variant in cfg.get("reverse_steps", []):
		if QuestManager.is_step_done(q, StringName(str(sid))):
			n += 1
	return n


func _on_step_completed(qid: StringName, _sid: StringName) -> void:
	if String(qid) == str(cfg.get("reverse_quest", "map04_kuendigung")):
		_apply_reversal()


func _apply_reversal() -> void:
	if cfg.is_empty() or renewed:
		return
	var total: int = (cfg.get("reverse_steps", []) as Array).size()
	var done: int = count_steps_done()
	var changed: bool = done != steps_done
	steps_done = done
	if not frozen:
		set_spread(reversed_spread(base_spread, done, total))
	if changed and total > 0:
		var k: float = 1.0 - 0.6 * float(done) / float(total)
		for m: Variant in points.values():
			var mi: MeshInstance3D = m as MeshInstance3D
			if mi != null:
				mi.create_tween().tween_property(mi, "scale", Vector3.ONE * maxf(0.05, k), 6.0)
		if done >= total and not dark_blue:
			go_dark_blue()
		var c: Node = get_tree().get_first_node_in_group(&"mondlicht_controller") if is_inside_tree() else null
		if c != null and c.has_method("earth_dimmed"):
			c.call("earth_dimmed", done, total)


## CANCEL: the night side goes a deep, ordinary blue (no violet left on it).
func go_dark_blue() -> void:
	dark_blue = true
	var mat: StandardMaterial3D = _night.material_override as StandardMaterial3D if _night != null else null
	if mat == null:
		return
	var a: Array = cfg.get("dark_blue", [0.04, 0.08, 0.3])
	var tw: Tween = create_tween()
	tw.tween_property(mat, "albedo_color", Color(float(a[0]), float(a[1]), float(a[2]), 0.55), 8.0 / maxf(0.01, Campaign.cutscene_speed))
	print("[m4d] the Earth goes dark blue")
