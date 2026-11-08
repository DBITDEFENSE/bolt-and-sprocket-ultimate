extends WorldEnvironment
## Map 1 (Kaltenbrunn), presentation only. One Environment serves a moonlit snow yard, the salt depths 12 m down
## and the Nachtglas vault 18 m down, so the fill light (flat ambient), the far-fog colour, the fog glow, the
## exposure and the saturation follow the active camera's height: cold moon-blue on the surface, a dark neutral
## salt-grey in the depths, violet-black at the heart. The lift ride and the stairs blend one into the next.
## With SDFGI on (the High preset) bounce light does most of the filling, so the flat ambient drops to
## `gi_ambient_scale` of itself; without it (Medium/Low) the full ambient keeps the unpowered depths readable (D-063).
## Fog density is left alone (the Bellringer's fog tweens it in zombie_director.gd).

@export_group("Surface")
@export var surface_ambient: Color = Color(0.22, 0.27, 0.40)
@export var surface_ambient_energy: float = 0.3
@export var surface_fog: Color = Color(0.085, 0.095, 0.13)
@export var surface_fog_glow: Color = Color(0.008, 0.009, 0.014)
@export var surface_exposure: float = 1.4
@export var surface_saturation: float = 0.8
@export_group("Depths")
@export var depth_ambient: Color = Color(0.27, 0.28, 0.32)
@export var depth_ambient_energy: float = 0.62
@export var depth_fog: Color = Color(0.05, 0.045, 0.04)
@export var depth_fog_glow: Color = Color(0.004, 0.004, 0.004)
@export var depth_exposure: float = 1.5
@export var depth_saturation: float = 0.85
@export_group("Core")
@export var core_ambient: Color = Color(0.26, 0.2, 0.42)
@export var core_ambient_energy: float = 0.62
@export var core_fog: Color = Color(0.04, 0.02, 0.06)
@export var core_fog_glow: Color = Color(0.009, 0.003, 0.018)
@export var core_exposure: float = 1.45
## The heart is the one saturated colour in the game (GDD 17): the vault keeps its violet.
@export var core_saturation: float = 1.0
@export_group("Blend")
## Camera heights (m) between which the surface grade fades into the depths grade.
@export var depth_top: float = -2.5
@export var depth_full: float = -9.0
## Camera heights between which the depths grade fades into the core grade (the vault ramps run -12 → -18).
@export var core_top: float = -12.6
@export var core_full: float = -16.0
## Flat ambient multiplier while SDFGI is on.
@export var gi_ambient_scale: float = 0.7
## Extra Core fill when the preset has no volumetric fog (Low): the heart's halo in the haze is most of the vault's
## light, so without it the chamber would go black.
@export var core_no_fog_fill: float = 1.6
## ... and extra Core exposure in that case.
@export var core_no_fog_exposure: float = 0.6
## How fast the grade follows the camera (1/s); a jump of more than 8 m snaps.
@export var follow: float = 2.5

var _cur: Dictionary = {}
var _last_cam: Vector3 = Vector3.INF


## UPDATE 12 (T-207): the look file's zones (`surface`, `depths`, `core` in data/look/map01_kaltenbrunn.json) set the
## three levels' fill, far-fog colour, fog glow, exposure and saturation; a key a zone leaves out keeps the export.
func look_zones(zones: Dictionary) -> void:
	for pair: Array in [["surface", "surface_"], ["depths", "depth_"], ["core", "core_"]]:
		var z: Dictionary = zones.get(pair[0], {})
		if z.is_empty():
			continue
		var p: String = pair[1]
		var amb: Dictionary = z.get("ambient", {})
		if amb.has("color"):
			set(p + "ambient", LookGrade.color(amb["color"], get(p + "ambient")))
		if amb.has("energy"):
			set(p + "ambient_energy", float(amb["energy"]))
		var fog: Dictionary = z.get("fog", {})
		if fog.has("color"):
			set(p + "fog", LookGrade.color(fog["color"], get(p + "fog")))
		if fog.has("emission"):
			set(p + "fog_glow", LookGrade.color(fog["emission"], get(p + "fog_glow")))
		if z.has("exposure"):
			set(p + "exposure", float(z["exposure"]))
		if (z.get("adjust", {}) as Dictionary).has("saturation"):
			set(p + "saturation", float(z["adjust"]["saturation"]))
	_cur.clear()   # snap to the new values on the next frame


func _process(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or environment == null:
		return
	var p: Vector3 = cam.global_position
	var want: Dictionary = target_for(p.y, environment.sdfgi_enabled, environment.volumetric_fog_enabled)
	var k: float = 1.0 - exp(-delta * follow)
	if _cur.is_empty() or p.distance_to(_last_cam) > 8.0:
		k = 1.0
	_last_cam = p
	if _cur.is_empty():
		_cur = want.duplicate()
	for key: String in want.keys():
		_cur[key] = lerp(_cur[key], want[key], k)
	environment.ambient_light_color = _cur["ambient"]
	environment.ambient_light_energy = _cur["ambient_energy"]
	environment.fog_light_color = _cur["fog"]
	environment.volumetric_fog_emission = _cur["glow"]
	environment.tonemap_exposure = _cur["exposure"]
	environment.adjustment_saturation = _cur["saturation"]


## The grade wanted at camera height `y` (blends surface → depths → core).
func target_for(y: float, gi: bool, vol_fog: bool = true) -> Dictionary:
	var d: float = smoothstep(depth_top, depth_full, y)
	var c: float = smoothstep(core_top, core_full, y)
	var amb: Color = surface_ambient.lerp(depth_ambient, d).lerp(core_ambient, c)
	var amb_e: float = lerpf(lerpf(surface_ambient_energy, depth_ambient_energy, d), core_ambient_energy, c)
	if gi:
		amb_e *= gi_ambient_scale
	var expo: float = lerpf(lerpf(surface_exposure, depth_exposure, d), core_exposure, c)
	if not vol_fog:
		amb_e += c * core_no_fog_fill
		expo += c * core_no_fog_exposure
	return {
		"ambient": amb,
		"ambient_energy": amb_e,
		"fog": surface_fog.lerp(depth_fog, d).lerp(core_fog, c),
		"glow": surface_fog_glow.lerp(depth_fog_glow, d).lerp(core_fog_glow, c),
		"exposure": expo,
		"saturation": lerpf(lerpf(surface_saturation, depth_saturation, d), core_saturation, c),
	}
