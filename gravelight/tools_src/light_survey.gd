extends Node
## T-222: a headless light survey of a map's walkable floor. Loads the map (bots off, no round), samples its baked
## navmesh on a grid, and for each sample (eye height 1.5 m) adds up the direct light it can see: every visible
## Omni / Spot light in range with a clear line (world colliders), using Godot's distance attenuation and the spot cone,
## plus the moon when the sky is open above it; then the same with the power on. The ambient term (environment
## ambient colour x energy) is printed once: it is the same everywhere. It also measures each sample's surroundings
## (eight horizontal rays and one up) and flags corridors (an enclosed run under 4.6 m wide and over 7 m long) with the
## yaw that looks down them. Nothing in the map is changed. The numbers rank spots inside a map ("too dark" is a
## number); the renders (capture.gd + tools/look/luma_stats.py) are the truth.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/light_survey.tscn -- \
##     --map=res://gravelight/maps/map04_fernflug/map04a.tscn --out=<file.json> [--step=2.5] [--no-power]

const EYE: float = 1.5

var _args: Dictionary = {}
var _space: PhysicsDirectSpaceState3D = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
		elif a.begins_with("--"):
			_args[a.substr(2)] = "1"
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	var map: Node = (load(str(_args["map"])) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(map)
	await get_tree().create_timer(4.0).timeout
	RoundManager.stop()
	_space = (map as Node3D).get_world_3d().direct_space_state
	var step: float = float(_args.get("step", "2.5"))
	var pts: Array = _samples(map, step)
	print("[survey] %d samples" % pts.size())
	var env: Environment = null
	for we: Node in map.find_children("*", "WorldEnvironment", true, false):
		env = (we as WorldEnvironment).environment
	var amb: float = 0.0
	if env != null:
		amb = _lum(env.ambient_light_color) * env.ambient_light_energy
	print("[survey] ambient term %.3f" % amb)
	var off: Array = []
	for s: Dictionary in pts:
		off.append(_light_at(map, s["p"] + Vector3.UP * EYE))
	var on: Array = []
	if not _args.has("no-power"):
		var sw: Node = get_tree().get_first_node_in_group(&"power_switch")
		GameState.power_on = true
		GameState.set_flag(&"power_on", true)
		if sw != null and sw.has_method("_sequence_visual"):
			sw.call("_sequence_visual")
		GLBus.power_activated.emit()
		await get_tree().create_timer(9.0).timeout
		for s2: Dictionary in pts:
			on.append(_light_at(map, s2["p"] + Vector3.UP * EYE))
	var rows: Array = []
	for i: int in pts.size():
		var s3: Dictionary = pts[i]
		var p: Vector3 = s3["p"]
		var r: Dictionary = {"p": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)], "zone": s3["zone"],
			"off": snappedf(float(off[i]["e"]), 0.001), "off_top": off[i]["top"]}
		if not on.is_empty():
			r["on"] = snappedf(float(on[i]["e"]), 0.001)
			r["on_top"] = on[i]["top"]
		r.merge(_shape_at(p + Vector3.UP * EYE))
		rows.append(r)
	var out: Dictionary = {"map": _args["map"], "ambient": amb, "eye": EYE, "step": step, "rows": rows}
	var f: FileAccess = FileAccess.open(str(_args.get("out", "user://light_survey.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "", false))
	f.close()
	print("[survey] wrote %s" % _args.get("out", "user://light_survey.json"))
	get_tree().quit()


func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Grid samples over every enabled navmesh region's polygons (one per cell, the region's zone from its name
## Nav_<ZONE>_<n>).
func _samples(map: Node, step: float) -> Array:
	var cells: Dictionary = {}
	for n: Node in map.find_children("*", "NavigationRegion3D", true, false):
		var reg: NavigationRegion3D = n as NavigationRegion3D
		if not reg.enabled or reg.navigation_mesh == null or not reg.is_inside_tree():
			continue
		var zone: String = str(reg.name).trim_prefix("Nav_")
		var cut: int = zone.rfind("_")
		if cut > 0 and zone.substr(cut + 1).is_valid_int():
			zone = zone.substr(0, cut)
		var nm: NavigationMesh = reg.navigation_mesh
		var xf: Transform3D = reg.global_transform
		var vs: PackedVector3Array = nm.get_vertices()
		for pi: int in nm.get_polygon_count():
			var poly: PackedInt32Array = nm.get_polygon(pi)
			for t: int in range(1, poly.size() - 1):
				var a: Vector3 = xf * vs[poly[0]]
				var b: Vector3 = xf * vs[poly[t]]
				var c: Vector3 = xf * vs[poly[t + 1]]
				var area: float = (b - a).cross(c - a).length() * 0.5
				var k: int = clampi(int(ceil(sqrt(area) / step)) + 1, 1, 40)
				for u: int in k + 1:
					for v: int in k + 1 - u:
						var w: float = float(k - u - v)
						var q: Vector3 = (a * (float(u) + 0.33) + b * (float(v) + 0.33) + c * (w + 0.33)) / (float(k) + 1.0)
						var key: Vector3i = Vector3i(floori(q.x / step), floori(q.y / 2.0), floori(q.z / step))
						if not cells.has(key):
							cells[key] = {"p": q, "zone": zone}
	return cells.values()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	q.collide_with_areas = false
	return _space.intersect_ray(q)


func _light_at(map: Node, p: Vector3) -> Dictionary:
	var e: float = 0.0
	var best: Array = []
	for n: Node in map.find_children("*", "Light3D", true, false):
		var l: Light3D = n as Light3D
		if not l.is_visible_in_tree() or l.light_energy <= 0.001:
			continue
		var c: float = 0.0
		if l is DirectionalLight3D:
			var dir: Vector3 = l.global_transform.basis.z.normalized()   # towards the light
			if dir.y <= 0.02:
				continue
			if _ray(p, p + dir * 120.0).is_empty():
				c = l.light_energy * _lum(l.light_color) * dir.y
		else:
			var lp: Vector3 = l.global_position
			var d: float = lp.distance_to(p)
			var rng: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
			if d >= rng:
				continue
			var decay: float = (l as OmniLight3D).omni_attenuation if l is OmniLight3D else (l as SpotLight3D).spot_attenuation
			var nd: float = pow(d / rng, 4.0)
			var att: float = pow(maxf(1.0 - nd, 0.0), 2.0) * pow(maxf(d, 0.5), -decay)
			if l is SpotLight3D:
				var sl: SpotLight3D = l as SpotLight3D
				var fwd: Vector3 = -sl.global_transform.basis.z.normalized()
				var cosa: float = cos(deg_to_rad(sl.spot_angle))
				var sc: float = fwd.dot((p - lp).normalized())
				if sc <= cosa:
					continue
				var rim: float = maxf((1.0 - sc) / maxf(1.0 - cosa, 0.0001), 0.0001)
				att *= 1.0 - pow(rim, sl.spot_angle_attenuation)
			if att <= 0.0:
				continue
			# a clear line: a hit nearer than the light (0.3 m slack for a lamp mounted on its wall) blocks it
			var hit: Dictionary = _ray(p, lp)
			if not hit.is_empty() and (hit["position"] as Vector3).distance_to(lp) > 0.3:
				continue
			c = l.light_energy * _lum(l.light_color) * att
		if c <= 0.0:
			continue
		e += c
		best.append([c, String(map.get_path_to(l))])
	best.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var top: Array = []
	for b: Array in best.slice(0, 3):
		top.append("%s:%.2f" % [b[1], b[0]])
	return {"e": e, "top": top}


## Eight horizontal rays (30 m) and one up: the free distances, the ceiling, and a corridor flag with its long axis.
func _shape_at(p: Vector3) -> Dictionary:
	var dist: Array = []
	for i: int in 8:
		var yaw: float = deg_to_rad(45.0 * i)
		var d: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
		var h: Dictionary = _ray(p, p + d * 30.0)
		dist.append(30.0 if h.is_empty() else snappedf(p.distance_to(h["position"]), 0.1))
	var up: Dictionary = _ray(p, p + Vector3.UP * 30.0)
	var ceil_h: float = -1.0 if up.is_empty() else snappedf((up["position"] as Vector3).y - p.y + EYE, 0.1)
	var corr: bool = false
	var best_yaw: float = 0.0
	var best_len: float = 0.0
	for i2: int in 4:
		var width: float = float(dist[(i2 + 2) % 8]) + float(dist[(i2 + 6) % 8])
		var length: float = float(dist[i2]) + float(dist[i2 + 4])
		if width < 4.6 and length > 7.0 and ceil_h > 0.0 and ceil_h < 9.0 and length > best_len:
			corr = true
			best_len = length
			best_yaw = 45.0 * i2 if float(dist[i2]) >= float(dist[i2 + 4]) else 45.0 * i2 + 180.0
	var far_i: int = 0
	for i3: int in 8:
		if float(dist[i3]) > float(dist[far_i]):
			far_i = i3
	var yaw_out: float = best_yaw if corr else 45.0 * far_i
	if yaw_out > 180.0:
		yaw_out -= 360.0
	return {"dist": dist, "ceil": ceil_h, "corridor": corr, "yaw": yaw_out}
