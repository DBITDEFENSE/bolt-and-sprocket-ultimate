class_name TrainingRoute
extends RefCounted
## A training loop (Update 03 section 3, T-056): a closed loop of authored points on a map, smoothed (Chaikin
## corner cutting) and resampled every SAMPLE_M, plus the width of the open ring it runs in. A bot that trains
## runs along it a little ahead of the horde (BotLocomotion.train).
##
## The brief asks for TrainingRoute resources; this project keeps tuning in JSON tables, so the routes are data
## in data/gravelight/ai/routes_<map>.json (one file per map: {"routes": [{id, label, points: [[x, y, z]...],
## ring_width, requires_doors: [door_id...], requires_zones: [zone...], notes}]}). Validated on the navmesh by
## gravelight/tools_src/route_tool.tscn (-- --validate) and by smoke_bot_loco.
##
## Parameters are distances along the loop in metres, wrapping at length().

const SAMPLE_M: float = 0.5
const DATA_DIR: String = "res://data/gravelight/ai/"

var id: String = ""
var map: String = ""
var label: String = ""
var points: PackedVector3Array = PackedVector3Array()   # authored control points (closed: last joins first)
var samples: PackedVector3Array = PackedVector3Array()  # smoothed, resampled loop
var cum: PackedFloat32Array = PackedFloat32Array()      # loop distance at each sample
var ring_width: float = 4.0
var requires_doors: PackedStringArray = PackedStringArray()   # every one of these BuyDoor ids open
var requires_zones: PackedStringArray = PackedStringArray()   # every one of these zones open (GameState)
## A squad with no human leading it makes its home on the open route with the highest `home` (0 = never; T-058).
var home: float = 0.0
## Added to the player bot's loop score (BotTrainer.loop_score, T-071): + for a loop that trains well alone, - for one
## that doesn't (a lollipop walked both ways).
var agent_bonus: float = 0.0
## Only the player bot trains here (T-071): the squad's route pick and the bots' door rules leave it out.
var agent_only: bool = false
var _len: float = 0.0

static var _cache: Dictionary = {}   # map key -> Array[TrainingRoute]
static var _hg_cache: Dictionary = {}   # map key -> Array[Dictionary] (high_ground)


## A route from authored points (closed loop). `smooth` = Chaikin iterations.
static func make(route_id: String, pts: PackedVector3Array, width: float, smooth: int = 2) -> TrainingRoute:
	var r: TrainingRoute = TrainingRoute.new()
	r.id = route_id
	r.points = pts
	r.ring_width = width
	r._build(smooth)
	return r


static func from_dict(d: Dictionary, map_key: String) -> TrainingRoute:
	var pts: PackedVector3Array = PackedVector3Array()
	for p: Variant in d.get("points", []):
		var a: Array = p as Array
		pts.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	var r: TrainingRoute = make(str(d.get("id", "")), pts, float(d.get("ring_width", 4.0)), int(d.get("smooth", 2)))
	r.map = map_key
	r.label = str(d.get("label", r.id))
	r.home = float(d.get("home", 0.0))
	r.agent_bonus = float(d.get("agent_bonus", 0.0))
	r.agent_only = bool(d.get("agent_only", false))
	for door: Variant in d.get("requires_doors", []):
		r.requires_doors.append(str(door))
	for z: Variant in d.get("requires_zones", []):
		r.requires_zones.append(str(z))
	return r


## "map00_crossroads" / "map00" -> "map00".
static func map_key_of(map_id: String) -> String:
	var s: String = map_id.to_lower()
	if s.begins_with("map") and s.length() >= 5:
		# Map 4's acts are separate arenas with their own routes and plans: "map04a_thalbach" -> "map04a" (T-115).
		if s.length() >= 6 and s.unicode_at(5) >= 97 and s.unicode_at(5) <= 122:
			return s.substr(0, 6)
		return s.substr(0, 5)
	return s


## Every route authored for a map (cached).
static func all_for_map(map_id: String) -> Array[TrainingRoute]:
	var key: String = map_key_of(map_id)
	if _cache.has(key):
		return _cache[key]
	var out: Array[TrainingRoute] = []
	var path: String = DATA_DIR + "routes_%s.json" % key
	if FileAccess.file_exists(path):
		var data: Dictionary = GLData.load_json(path)
		for d: Variant in data.get("routes", []):
			var r: TrainingRoute = from_dict(d as Dictionary, key)
			if r.samples.size() >= 4:
				out.append(r)
	_cache[key] = out
	return out


## The routes usable right now: every door a route needs is open (BuyDoor.door_id in the "doors" group) and
## every zone it needs is open (GameState.open_zones). Agent-only routes (T-071) only with `include_agent`.
static func for_map(map_id: String, include_agent: bool = false) -> Array[TrainingRoute]:
	var out: Array[TrainingRoute] = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var open: Dictionary = {}
	if tree != null:
		for n: Node in tree.get_nodes_in_group(&"doors"):
			if n is BuyDoor and (n as BuyDoor).is_open:
				open[String((n as BuyDoor).door_id)] = true
	for r: TrainingRoute in all_for_map(map_id):
		if r.agent_only and not include_agent:
			continue
		if r.doors_ok(open) and r.zones_ok(GameState.open_zones):
			out.append(r)
	return out


## True when every door in requires_doors is in `open_doors` (door_id -> true).
func doors_ok(open_doors: Dictionary) -> bool:
	for d: String in requires_doors:
		if not open_doors.has(d):
			return false
	return true


## True when every zone in requires_zones is a key (or element) of `open_zones`.
func zones_ok(open_zones: Variant) -> bool:
	for z: String in requires_zones:
		if open_zones is Dictionary and not ((open_zones as Dictionary).has(StringName(z)) or (open_zones as Dictionary).has(z)):
			return false
		if open_zones is Array and not ((open_zones as Array).has(StringName(z)) or (open_zones as Array).has(z)):
			return false
	return true


## High-ground spots authored for a map (routes_<map>.json "high_ground", T-058): [{id, pos, watch_m,
## requires_doors}] whose doors are all open now. A precision shooter (Wren, personality combat.high_ground) fights
## from one when the fight is within its watch_m.
static func high_ground_for(map_id: String) -> Array[Dictionary]:
	var key: String = map_key_of(map_id)
	if not _hg_cache.has(key):
		var all: Array[Dictionary] = []
		var path: String = DATA_DIR + "routes_%s.json" % key
		if FileAccess.file_exists(path):
			for d: Variant in GLData.load_json(path).get("high_ground", []):
				var dd: Dictionary = d as Dictionary
				var a: Array = dd.get("pos", [0, 0, 0])
				all.append({"id": str(dd.get("id", "")), "pos": Vector3(float(a[0]), float(a[1]), float(a[2])),
					"watch_m": float(dd.get("watch_m", 12.0)), "requires_doors": dd.get("requires_doors", [])})
		_hg_cache[key] = all
	var open: Dictionary = {}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		for n: Node in tree.get_nodes_in_group(&"doors"):
			if n is BuyDoor and (n as BuyDoor).is_open:
				open[String((n as BuyDoor).door_id)] = true
	var out: Array[Dictionary] = []
	for h: Dictionary in _hg_cache[key]:
		var ok: bool = true
		for door: Variant in h["requires_doors"]:
			ok = ok and open.has(str(door))
		if ok:
			out.append(h)
	return out


func length() -> float:
	return _len


## Wraps a loop parameter into [0, length).
func wrap_param(param: float) -> float:
	return fposmod(param, _len) if _len > 0.0 else 0.0


## The point on the loop at `param` metres.
func point_at(param: float) -> Vector3:
	if samples.is_empty():
		return Vector3.ZERO
	var t: float = wrap_param(param)
	var i: int = _seg_index(t)
	var j: int = (i + 1) % samples.size()
	var seg_len: float = (_len if j == 0 else cum[j]) - cum[i]
	var k: float = 0.0 if seg_len <= 0.0001 else (t - cum[i]) / seg_len
	return samples[i].lerp(samples[j], k)


## The loop's direction of travel (+param) at `param`, flat and normalised.
func tangent_at(param: float) -> Vector3:
	var a: Vector3 = point_at(param - 0.4)
	var b: Vector3 = point_at(param + 0.4)
	var t: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	return t.normalized() if t.length_squared() > 0.000001 else Vector3.FORWARD


## `param` moved `dist` metres along the loop in direction `dir` (+1 / -1), wrapped.
func advance(param: float, dist: float, dir: int) -> float:
	return wrap_param(param + dist * (1.0 if dir >= 0 else -1.0))


## Signed loop distance from `from_param` to `to_param` going in `dir`: always in [0, length).
func distance_along(from_param: float, to_param: float, dir: int) -> float:
	var d: float = to_param - from_param if dir >= 0 else from_param - to_param
	return fposmod(d, _len) if _len > 0.0 else 0.0


## The loop parameter closest to `pos` (flat distance; samples on another floor, |dy| > 2 m, lose).
func closest_param(pos: Vector3) -> float:
	var best: float = INF
	var best_t: float = 0.0
	var n: int = samples.size()
	var p2: Vector2 = Vector2(pos.x, pos.z)
	for i: int in n:
		var a: Vector3 = samples[i]
		var b: Vector3 = samples[(i + 1) % n]
		var a2: Vector2 = Vector2(a.x, a.z)
		var b2: Vector2 = Vector2(b.x, b.z)
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(p2, a2, b2)
		var d: float = c.distance_to(p2)
		if absf(a.y - pos.y) > 2.0:
			d += 50.0
		if d < best:
			best = d
			var seg: float = a2.distance_to(b2)
			best_t = cum[i] + (0.0 if seg < 0.0001 else c.distance_to(a2))
	return wrap_param(best_t)


## Flat distance from `pos` to the loop line.
func distance_to_line(pos: Vector3) -> float:
	var p: Vector3 = point_at(closest_param(pos))
	return Vector2(p.x - pos.x, p.z - pos.z).length() + (50.0 if absf(p.y - pos.y) > 2.0 else 0.0)


## Inside the open ring the loop runs in: within ring_width / 2 of the line, on its floor.
func contains_ring(pos: Vector3) -> bool:
	return distance_to_line(pos) <= ring_width * 0.5


## The loop's middle (the mean of its samples).
func center() -> Vector3:
	var c: Vector3 = Vector3.ZERO
	for s: Vector3 in samples:
		c += s
	return c / maxf(1.0, float(samples.size()))


## Checks the route in a loaded map: every sample on the navmesh, room for a body on both sides (walls by
## physics rays at knee and chest height), the open width near ring_width along most of it, and the loop walkable
## from sample to sample on the navmesh (no detours through a wall). Returns {ok, problems: PackedStringArray,
## min_width, mean_width, length}.
func validate_on(world: World3D) -> Dictionary:
	var problems: PackedStringArray = PackedStringArray()
	var nav: RID = world.navigation_map
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var min_w: float = INF
	var sum_w: float = 0.0
	var narrow: int = 0
	var n: int = samples.size()
	if n < 8 or _len < 8.0:
		problems.append("too short (%.1f m, %d samples)" % [_len, n])
	for i: int in n:
		var s: Vector3 = samples[i]
		var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, s + Vector3.UP * 0.3)
		if Vector2(c.x - s.x, c.z - s.z).length() > 0.35 or absf(c.y - s.y) > 0.6:
			problems.append("sample %d (%.1f, %.1f, %.1f) is off the navmesh (closest %.1f, %.1f, %.1f)" % [i, s.x, s.y, s.z, c.x, c.y, c.z])
			continue
		var t: Vector3 = tangent_at(cum[i])
		var side: Vector3 = Vector3(-t.z, 0.0, t.x)
		var w: float = 0.0
		for sgn: float in [1.0, -1.0]:
			var reach: float = 6.0
			for h: float in [0.45, 1.1]:
				var from: Vector3 = c + Vector3.UP * h
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + side * sgn * 6.0, 1)
				var r: Dictionary = space.intersect_ray(q)
				if not r.is_empty():
					reach = minf(reach, from.distance_to(r["position"]))
			w += reach
		min_w = minf(min_w, w)
		sum_w += w
		if w < 1.3:
			problems.append("sample %d (%.1f, %.1f) has only %.2f m between walls" % [i, s.x, s.z, w])
		if w < ring_width * 0.85:
			narrow += 1
		var j: int = (i + 4) % n
		# all navigation layers: Map 4's acts bake one region per zone on its own layer (gen_map04_lib), and the
		# default layer mask would clamp both ends to the nearest zone-1 polygon (T-115)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, c, samples[j], true, 0xFFFFFFFF)
		var plen: float = 0.0
		for k: int in range(1, path.size()):
			plen += path[k - 1].distance_to(path[k])
		var straight: float = c.distance_to(samples[j])
		if path.is_empty() or plen > straight * 1.6 + 0.6:
			problems.append("samples %d -> %d (%.1f, %.1f) -> (%.1f, %.1f): navmesh path %.1f m for %.1f m straight %s" % [i, j, c.x, c.z, samples[j].x, samples[j].z, plen, straight, str(path) if problems.size() < 2 else ""])
	if n > 0 and float(narrow) / float(n) > 0.2:
		problems.append("%d of %d samples narrower than 85%% of ring_width %.1f" % [narrow, n, ring_width])
	return {"ok": problems.is_empty(), "problems": problems, "min_width": min_w, "mean_width": sum_w / maxf(1.0, float(n)), "length": _len}


func _seg_index(t: float) -> int:
	# binary search on cum (sorted ascending)
	var lo: int = 0
	var hi: int = cum.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if cum[mid] <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


func _build(smooth: int) -> void:
	var pts: PackedVector3Array = points.duplicate()
	if pts.size() >= 2 and pts[0].distance_to(pts[pts.size() - 1]) < 0.05:
		pts.remove_at(pts.size() - 1)   # a loop written with the first point repeated
	for _i: int in smooth:
		pts = chaikin_closed(pts)
	samples = resample_closed(pts, SAMPLE_M)
	cum = PackedFloat32Array()
	var acc: float = 0.0
	for i: int in samples.size():
		cum.append(acc)
		acc += samples[i].distance_to(samples[(i + 1) % samples.size()])
	_len = acc


## One Chaikin corner-cutting pass on a closed polygon (each edge -> its 1/4 and 3/4 points), the cut capped at
## `max_cut` metres from each corner so long straights keep their corners where they were authored.
static func chaikin_closed(pts: PackedVector3Array, max_cut: float = 1.2) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var n: int = pts.size()
	if n < 3:
		return pts
	for i: int in n:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % n]
		var l: float = a.distance_to(b)
		var f: float = 0.25 if l <= 0.0001 else minf(0.25, max_cut / l)
		out.append(a.lerp(b, f))
		out.append(a.lerp(b, 1.0 - f))
	return out


## Even spacing (about `step` m) round a closed polygon.
static func resample_closed(pts: PackedVector3Array, step: float) -> PackedVector3Array:
	var n: int = pts.size()
	var out: PackedVector3Array = PackedVector3Array()
	if n < 2:
		return pts
	var total: float = 0.0
	for i: int in n:
		total += pts[i].distance_to(pts[(i + 1) % n])
	var count: int = maxi(4, int(round(total / step)))
	var spacing: float = total / float(count)
	var seg: int = 0
	var seg_start: float = 0.0
	var seg_len: float = pts[0].distance_to(pts[1 % n])
	for k: int in count:
		var t: float = float(k) * spacing
		while t > seg_start + seg_len and seg < n - 1:
			seg_start += seg_len
			seg += 1
			seg_len = pts[seg].distance_to(pts[(seg + 1) % n])
		var f: float = 0.0 if seg_len < 0.0001 else clampf((t - seg_start) / seg_len, 0.0, 1.0)
		out.append(pts[seg].lerp(pts[(seg + 1) % n], f))
	return out
