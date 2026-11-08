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
	name = "LookZones"


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
	env.fog_density = v["fog_density"]
	env.volumetric_fog_density = v["vol_density"]
	env.fog_light_color = v["fog_color"]
	env.ambient_light_energy = v["ambient"]
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
