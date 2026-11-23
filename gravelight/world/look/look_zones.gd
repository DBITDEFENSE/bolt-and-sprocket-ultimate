class_name LookZones
extends Node
## UPDATE 12 (DECISIONS T-214): a map grade's `zones` that carry `boxes` follow the camera (contract C2's "zones": a
## sub-area's block merged over the map's). LookGrade.attach adds one to a map whose WorldEnvironment has no zone
## logic of its own (Kaltenbrunn's depth_grade.gd blends its own by height). Inside a box the zone's values blend in
## over ~0.4 s; leaving every box blends back to what the Environment had when the camera came in. Only while it
## blends does it write, so a script that tweens the fog in a room (the director's fog) keeps its say in between.
##   "zones": {"inn": {"boxes": [[x0, y0, z0, x1, y1, z1], ...], "fog": {"density": d, "volumetric": v, "color": c},
##                     "ambient": {"energy_scale": s}, "exposure": e}}
## Keys: fog.density, fog.volumetric, fog.color, ambient.energy_scale (times the outside fill), exposure.
## Presentation only (the Environment): no gameplay value is read or written.

const BLEND_RATE: float = 2.5   # 1/s: a 0.4 s blend
const SNAP_M: float = 8.0       # a camera jump farther than this snaps

var env: Environment
var zones: Dictionary = {}
var keys: PackedStringArray = ["fog_density", "vol_density", "fog_color", "ambient", "exposure"]   # setup() narrows it (T-222)
var map: Node3D
var current: String = ""
var _base: Dictionary = {}       # the Environment's own values when the camera entered a zone
var _from: Dictionary = {}
var _to: Dictionary = {}
var _k: float = 1.0               # blend progress 0..1 (1: done, nothing written)
var _last: Vector3 = Vector3.INF
var _tick: float = 0.0


static func has_boxes(z: Dictionary) -> bool:
	for v: Variant in z.values():
		if v is Dictionary and (v as Dictionary).get("boxes", []) is Array and not ((v as Dictionary).get("boxes", []) as Array).is_empty():
			return true
	return false


func setup(e: Environment, z: Dictionary, m: Node) -> void:
	env = e
	map = m as Node3D
	for k: Variant in z.keys():
		if z[k] is Dictionary and has_boxes({k: z[k]}):
			zones[str(k)] = z[k]
	keys = keys_of(zones)
	name = "LookZones"


## T-222: the Environment values the zones set at all (read_env's names). Only these are written: a value no zone
## touches stays whoever's it is (Groom Lake's dust storm and the director's special-round fog tween the fog while
## the camera may be inside an exposure-only zone; writing the fog back from the entry snapshot would undo them).
## Pure.
static func keys_of(zs: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for v: Variant in zs.values():
		if not (v is Dictionary):
			continue
		var z: Dictionary = v
		var fog: Dictionary = z.get("fog", {})
		for pair: Array in [[fog.has("density"), "fog_density"], [fog.has("volumetric"), "vol_density"], [fog.has("color"), "fog_color"],
				[(z.get("ambient", {}) as Dictionary).has("energy_scale"), "ambient"], [z.has("exposure"), "exposure"]]:
			if bool(pair[0]) and not out.has(str(pair[1])):
				out.append(str(pair[1]))
	return out


## Which zone holds `p` (map frame), "" for none. Pure.
func zone_at(p: Vector3) -> String:
	for id: String in zones.keys():
		for b: Variant in (zones[id] as Dictionary).get("boxes", []):
			var bx: Array = b
			if p.x >= float(bx[0]) and p.y >= float(bx[1]) and p.z >= float(bx[2]) and p.x <= float(bx[3]) and p.y <= float(bx[4]) and p.z <= float(bx[5]):
				return id
	return ""


## The Environment values the zone keys touch, as they are now.
func read_env() -> Dictionary:
	# T-259: with a DayCycle on the map these three hold the night's value plus the hour's daylight; the zones work
	# on the night's value and the day is blended over what they write.
	var dc: DayCycle = DayCycle.of(map)
	if dc != null and dc.env == env:
		return {"fog_density": env.fog_density, "vol_density": env.volumetric_fog_density, "fog_color": dc.night_value("fog_light_color"),
			"ambient": dc.night_value("ambient_light_energy"), "exposure": dc.night_value("tonemap_exposure")}
	return {"fog_density": env.fog_density, "vol_density": env.volumetric_fog_density, "fog_color": env.fog_light_color,
		"ambient": env.ambient_light_energy, "exposure": env.tonemap_exposure}


## The values zone `id` wants, over `base` (what the Environment had outside). Pure.
func target(id: String, base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	if id == "" or not zones.has(id):
		return out
	var z: Dictionary = zones[id]
	var fog: Dictionary = z.get("fog", {})
	if fog.has("density"):
		out["fog_density"] = float(fog["density"])
	if fog.has("volumetric"):
		out["vol_density"] = float(fog["volumetric"])
	if fog.has("color"):
		out["fog_color"] = LookGrade.color(fog["color"], base["fog_color"])
	var amb: Dictionary = z.get("ambient", {})
	if amb.has("energy_scale"):
		out["ambient"] = float(base["ambient"]) * float(amb["energy_scale"])
	if z.has("exposure"):
		out["exposure"] = float(z["exposure"])
	return out


func _write(v: Dictionary) -> void:
	if keys.has("fog_density"):
		env.fog_density = v["fog_density"]
	if keys.has("vol_density"):
		env.volumetric_fog_density = v["vol_density"]
	if keys.has("fog_color"):
		env.fog_light_color = v["fog_color"]
	if keys.has("ambient"):
		env.ambient_light_energy = v["ambient"]
	if keys.has("exposure"):
		env.tonemap_exposure = v["exposure"]


func _process(delta: float) -> void:
	if env == null or zones.is_empty():
		return
	if _k < 1.0:
		_k = minf(1.0, _k + delta * BLEND_RATE)
		var v: Dictionary = {}
		for key: String in _to.keys():
			v[key] = lerp(_from[key], _to[key], smoothstep(0.0, 1.0, _k))
		_write(v)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.1
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return
	var p: Vector3 = map.to_local(cam.global_position) if map != null and map.is_inside_tree() else cam.global_position
	var z: String = zone_at(p)
	var jump: bool = _last.distance_to(p) > SNAP_M
	_last = p
	if z == current:
		return
	if current == "":
		_base = read_env()   # what the outside had
	_from = read_env()
	_to = target(z, _base)
	current = z
	_k = 0.0
	if jump:
		_k = 1.0
		_write(_to)
