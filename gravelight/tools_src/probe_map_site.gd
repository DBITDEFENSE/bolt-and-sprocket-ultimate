extends Node
## T-271: measures places on a RUNNING map (everything built at load is there), headless, for the data rows of the
## map detail pass: where a horse and its rail may stand, where a tank may roll and park, where a cable may hang.
## Nothing here can see: it measures colliders, the navmesh and the zone volumes.
##
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_map_site.tscn -- --map=map01
##       [--roofs=1]                     every zone: how much of its navmesh ground has a collider overhead
##       [--open=ZONE[,step][+ZONE...]]  the most open ground of a zone: navmesh points by the free radius round them
##       [--at=x,y,z[;x,y,z...]]         each point: the floor under it, the navmesh, the zone, the free radius, what is near
##       [--route=x,y,z;x,y,z;...]       a tank's hull swept along the legs (ShermanTank's own box), the ground under it
##       [--line=x,y,z;x,y,z[,hang]]     a zip line's cable: a rider's body swept under it from the anchor to the low end
##       [--doors=open]                  every buy door opened first (default: as the match starts)
##
## Prints "[site] ..." lines and "[site] RESULT: DONE".

const SCENES: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const WORLD: int = 1
const SOLID: int = 1 | (1 << 5) | (1 << 8) | (1 << 10)   # world, barricades, doors, the map's edge

var _map: Node3D
var _args: Dictionary = {}


func _ready() -> void:
	ProfileSave.path = "user://_qa_site_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_site_settings.cfg"
	GameState.bot_count = 0
	Campaign.reset()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_args[a.get_slice("=", 0).substr(2)] = a.substr(a.find("=") + 1)
	_run.call_deferred()


static func pts(s: String) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for part: String in s.split(";", false):
		var f: PackedStringArray = part.split(",", false)
		if f.size() >= 3:
			out.append(Vector3(float(f[0]), float(f[1]), float(f[2])))
	return out


static func v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


func _space() -> PhysicsDirectSpaceState3D:
	return _map.get_world_3d().direct_space_state


func _nav() -> RID:
	return _map.get_world_3d().navigation_map


## The floor under `p` (a ray from 0.6 m over it to 3 m under it); INF when there is none.
func floor_y(p: Vector3) -> float:
	var hit: Dictionary = _space().intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 3.0, WORLD))
	return (hit["position"] as Vector3).y if not hit.is_empty() else INF


## Metres from `p` (1 m up) to the nearest solid thing over 16 directions, `far` at most; and what it was.
func free_radius(p: Vector3, far: float = 12.0) -> Array:
	var best: float = far
	var what: String = ""
	for k: int in 16:
		var d: Vector3 = Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0))
		for h: float in [0.35, 1.0, 1.7]:
			var hit: Dictionary = _space().intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * h, p + Vector3.UP * h + d * far, SOLID))
			if not hit.is_empty():
				var dist: float = (hit["position"] as Vector3).distance_to(p + Vector3.UP * h)
				if dist < best:
					best = dist
					what = _name_of(hit["collider"])
	return [best, what]


func _name_of(o: Variant) -> String:
	if o == null or not (o is Node):
		return "?"
	var n: Node = o
	return str(_map.get_path_to(n)).right(48) if _map.is_ancestor_of(n) else str(n.name)


## Everything scripted within `r` of `p` (machines, spawns, doors, windows): [[distance, name]...], nearest first.
func near_things(p: Vector3, r: float) -> Array:
	var out: Array = []
	for g: StringName in [&"interactables", &"zombie_spawns", &"doors", &"barricades", &"perk_spots", &"player_spawns", &"crate_spots"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			var n3: Node3D = n as Node3D
			if n3 == null:
				continue
			var d: float = Vector2(n3.global_position.x - p.x, n3.global_position.z - p.z).length()
			if d <= r and absf(n3.global_position.y - p.y) < 3.0:
				var row: Array = [snappedf(d, 0.1), String(n3.name)]
				if not out.has(row):
					out.append(row)
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out


## Flat metres from `p` to the navmesh (which floats up to a cell over the floor it was baked from); INF when the
## nearest polygon is on another level.
func inside_solid(p: Vector3) -> bool:
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = SOLID
	return not _space().intersect_point(q, 1).is_empty()


func roofed(p: Vector3) -> bool:
	return not _space().intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.2, p + Vector3.UP * 60.0, WORLD)).is_empty()


## Every zone: how much of its navmesh ground (a 2 m grid) has a collider overhead.
func _roofs() -> void:
	var tally: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"zone_volumes"):
		var zv: ZoneVolume = n as ZoneVolume
		if zv == null or zv.size.x < 6.0:
			continue
		var x: float = zv.global_position.x - zv.size.x * 0.5 + 1.0
		while x < zv.global_position.x + zv.size.x * 0.5:
			var z: float = zv.global_position.z - zv.size.z * 0.5 + 1.0
			while z < zv.global_position.z + zv.size.z * 0.5:
				var y: float = zv.global_position.y + 1.0
				while y < zv.global_position.y + zv.size.y:
					var p: Vector3 = Vector3(x, y, z)
					var fy: float = floor_y(p)
					if is_finite(fy):
						p.y = fy
						if nav_gap(p) < 0.35 and not inside_solid(p + Vector3.UP) and String(ZoneVolume.zone_at(get_tree(), p + Vector3.UP * 0.6)) == String(zv.zone_id):
							var t: Array = tally.get(String(zv.zone_id), [0, 0])
							t[0] = int(t[0]) + 1
							if roofed(p):
								t[1] = int(t[1]) + 1
							tally[String(zv.zone_id)] = t
					y += 3.0
				z += 2.0
			x += 2.0
	for k: String in tally:
		print("[site] roof over %-16s %3d of %3d navmesh points (%d %%)" % [k, tally[k][1], tally[k][0], int(100.0 * tally[k][1] / maxf(1.0, tally[k][0]))])


func nav_gap(p: Vector3) -> float:
	var q: Vector3 = NavigationServer3D.map_get_closest_point(_nav(), p + Vector3.UP * 0.3)
	return Vector2(q.x - p.x, q.z - p.z).length() if absf(q.y - p.y) < 1.0 else INF


func _run() -> void:
	var key: String = str(_args.get("map", "map01"))
	GameState.character_id = &"dutch"
	GameState.god_mode = true
	_map = (load(SCENES[key]) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	for i: int in 150:
		await get_tree().physics_frame
	RoundManager.stop()
	if str(_args.get("doors", "")) == "open":
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			if n is BuyDoor and not (n as BuyDoor).is_open:
				(n as BuyDoor).open(1)
		for i2: int in 30:
			await get_tree().physics_frame
	var waited: int = 0
	while waited < 600 and NavigationServer3D.map_get_random_point(_nav(), 0x7FFFFFFF, true) == Vector3.ZERO:
		await get_tree().physics_frame
		waited += 1
	print("[site] %s running (navmesh after %d more frames)" % [key, waited])
	if _args.has("roofs"):
		_roofs()
	if _args.has("open"):
		for zn: String in str(_args["open"]).split("+", false):
			_open(zn)
	if _args.has("at"):
		for p: Vector3 in pts(str(_args["at"])):
			_at(p)
	if _args.has("route"):
		_route(pts(str(_args["route"])))
	if _args.has("line"):
		_line(str(_args["line"]))
	print("[site] RESULT: DONE")
	get_tree().quit(0)


func _at(p: Vector3) -> void:
	var fy: float = floor_y(p)
	var fr: Array = free_radius(Vector3(p.x, fy if is_finite(fy) else p.y, p.z))
	print("[site] at %s: floor %s, navmesh %.2f m away, zone '%s', %s, free radius %.1f m (to %s), near %s" % [v(p),
		("%.2f" % fy) if is_finite(fy) else "none", nav_gap(p), ZoneVolume.zone_at(get_tree(), p + Vector3.UP * 0.6), "under a roof" if roofed(p) else "open sky", fr[0], fr[1], str(near_things(p, 8.0).slice(0, 6))])


func _open(spec: String) -> void:
	var zone: String = spec.get_slice(",", 0)
	var step: float = float(spec.get_slice(",", 1)) if spec.contains(",") else 2.0
	var found: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"zone_volumes"):
		var zv: ZoneVolume = n as ZoneVolume
		if zv == null or String(zv.zone_id) != zone or zv.size.x < 6.0:
			continue
		var x: float = zv.global_position.x - zv.size.x * 0.5 + step * 0.5
		while x < zv.global_position.x + zv.size.x * 0.5:
			var z: float = zv.global_position.z - zv.size.z * 0.5 + step * 0.5
			while z < zv.global_position.z + zv.size.z * 0.5:
				var p: Vector3 = Vector3(x, zv.global_position.y, z)
				var fy: float = floor_y(p + Vector3.UP * 1.0)
				if is_finite(fy):
					p.y = fy
					if nav_gap(p) < 0.35 and String(ZoneVolume.zone_at(get_tree(), p + Vector3.UP * 0.6)) == zone and not inside_solid(p + Vector3.UP):
						found.append([free_radius(p)[0], p, roofed(p)])
				z += step
			x += step
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	print("[site] zone %s: %d navmesh points on a %.1f m grid; the most open:" % [zone, found.size(), step])
	for r: Array in found.slice(0, 24):
		print("[site]   %s free %.1f m%s, near %s" % [v(r[1]), r[0], " (under a roof)" if bool(r[2]) else "", str(near_things(r[1], 7.0).slice(0, 4))])


## A tank's hull along the legs, every 0.5 m: ShermanTank's own hull box (from 0.6 m up) against the world, the
## doors, the barricades and the map's edge; the ground under its five points; the zone under its middle.
func _route(r: PackedVector3Array) -> void:
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(2.62 + 0.16, 1.3, 5.9 + 0.16)
	var hits: Dictionary = {}
	var zones: Dictionary = {}
	var bad_ground: int = 0
	var steps: int = 0
	var last_y: float = r[0].y
	for i: int in r.size() - 1:
		var d: Vector3 = r[i + 1] - r[i]
		var yaw: float = atan2(-d.x, -d.z)
		var n: int = maxi(1, int(ceil(d.length() / 0.5)))
		for k: int in n + 1:
			var p: Vector3 = r[i].lerp(r[i + 1], float(k) / float(n))
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw), p)
			steps += 1
			var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			sq.shape = bx
			sq.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.6 + 0.65, -0.05))
			sq.collision_mask = SOLID
			for h: Dictionary in _space().intersect_shape(sq, 8):
				var nm: String = _name_of(h["collider"])
				if not hits.has(nm):
					hits[nm] = v(p)
			var z: String = String(ZoneVolume.zone_at(get_tree(), p + Vector3.UP * 0.6))
			zones[z] = int(zones.get(z, 0)) + 1
			for l: Vector3 in [Vector3(0, 0, 0), Vector3(1.1, 0, -2.6), Vector3(-1.1, 0, -2.6), Vector3(1.1, 0, 2.7), Vector3(-1.1, 0, 2.7)]:
				var fy: float = floor_y(xf * l)
				if not is_finite(fy) or absf(fy - p.y) > 0.45:
					bad_ground += 1
					if bad_ground <= 6:
						print("[site]   ground at %s (hull point %s): %s" % [v(p), str(l), ("%.2f" % fy) if is_finite(fy) else "none"])
				elif l == Vector3.ZERO:
					last_y = fy
	print("[site] route of %d legs, %d hull places: %d things in the hull's way %s; zones under it %s; %d ground points off (of %d)" % [r.size() - 1, steps, hits.size(), str(hits), str(zones), bad_ground, steps * 5])
	var park: Vector3 = r[r.size() - 1]
	var fr: Array = free_radius(park, 30.0)
	print("[site] parks at %s: free radius %.1f m (to %s), navmesh %.2f m away, near %s" % [v(park), fr[0], fr[1], nav_gap(park), str(near_things(park, 12.0).slice(0, 8))])
	# the ring the dead rise on (ShermanEvent._ring_points): navmesh points 10..16 m round the parked hull
	var ring: Dictionary = {}
	for k2: int in 24:
		for rr: float in [10.0, 13.0, 16.0]:
			var q0: Vector3 = park + Vector3(cos(TAU * k2 / 24.0), 0, sin(TAU * k2 / 24.0)) * rr
			var q: Vector3 = NavigationServer3D.map_get_closest_point(_nav(), q0)
			if q.distance_to(q0) <= 1.5 and absf(q.y - park.y) <= 1.0:
				var zn: String = String(ZoneVolume.zone_at(get_tree(), q + Vector3.UP * 0.6))
				ring[zn] = int(ring.get(zn, 0)) + 1
	print("[site] the assault ring (72 places): on the navmesh by zone %s" % str(ring))


## A rider under the cable (a capsule 0.35 x 1.8 hanging `hang` under it), every 0.5 m from the anchor to the end.
func _line(spec: String) -> void:
	var p: PackedVector3Array = pts(spec.get_slice("|", 0))
	if p.size() < 2:
		return
	var hang: float = float(spec.get_slice("|", 1)) if spec.contains("|") else 2.7
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	var hits: Dictionary = {}
	var n: int = int(ceil(p[0].distance_to(p[1]) / 0.5))
	for k: int in range(3, n + 1):
		var c: Vector3 = p[0].lerp(p[1], float(k) / float(n))
		var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		sq.shape = cap
		sq.transform = Transform3D(Basis.IDENTITY, c + Vector3.DOWN * (hang - 0.9))
		sq.collision_mask = SOLID
		for h: Dictionary in _space().intersect_shape(sq, 4):
			var nm: String = _name_of(h["collider"])
			if not hits.has(nm):
				hits[nm] = "%.1f m down the line" % (float(k) * 0.5)
	var slope: float = rad_to_deg(asin((p[0].y - p[1].y) / maxf(0.1, p[0].distance_to(p[1]))))
	print("[site] line %s -> %s: %.1f m, %.0f degrees, %d things in a rider's way %s" % [v(p[0]), v(p[1]), p[0].distance_to(p[1]), slope, hits.size(), str(hits)])
	if p.size() >= 3:
		_at(p[2])
