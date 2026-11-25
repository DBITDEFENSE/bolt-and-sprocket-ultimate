class_name MapRocketDetail
extends RefCounted
## T-279 (the owner, 2026-11-25: "the rocket area needs another pass for details and stuff too"): the second detail
## pass on Map 0's V2 site (MapRocketGen, T-276). The T-276 renders showed big empty snow between a few boxy props.
## This module adds what a camouflaged field firing site of the winter of 1944-45 had round it, all of it DRESSING:
## no collider is added or moved, so the navmesh, the zones, the spawns, the perk spot, the gate and every prompt
## are exactly T-276's (test: the navmesh fingerprint is unchanged). Where a piece stands it stands where nobody
## walks: inside an existing solid's footprint, in the 0.5 m band the bake keeps clear round a solid or along an edge
## wall, or beyond the edge walls (the wire, the telephone line, the slit trench, the guard post). `audit` checks the
## tall pieces' footprints against the baked navmesh and prints every one that stands on it.
## No insignia, no unit markings, no real-world names; the signs are the plain German notices of the period.

const EDGE_LAYER_NOTE: String = "the edge walls are invisible: the perimeter wire is drawn on their line"

## Footprints of the tall pieces this pass places ([Rect2, name]); `audit` reads them.
static var _tall: Array = []


static func _reg(r: Rect2, n: String) -> void:
	_tall.append([r, n])


## A low sphere (8 x 4: 56 triangles against Props.ball's 144) for the many small round things of this pass: the
## bags, the boughs, the snow lumps. Batched like any primitive by gen_map00.merge_static_meshes.
static var _low_sphere: SphereMesh = null


static func lowball(parent: Node3D, center: Vector3, size: Vector3, key: String, shadow: bool = false) -> MeshInstance3D:
	if _low_sphere == null:
		_low_sphere = SphereMesh.new()
		_low_sphere.radius = 0.5
		_low_sphere.height = 1.0
		_low_sphere.radial_segments = 8
		_low_sphere.rings = 4
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _low_sphere
	mi.material_override = Mats.get_mat(key)
	mi.position = center
	mi.scale = size
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A course of low bags from a to b (as Props.sandbags, rows high), shadows only on the top course.
static func bags(parent: Node3D, a: Vector3, b: Vector3, rows: int) -> void:
	var length: float = a.distance_to(b)
	var yaw: float = rad_to_deg(atan2((b - a).x, (b - a).z))
	var n: int = maxi(1, int(length / 0.6))
	for r: int in rows:
		for i: int in n:
			var t: float = (float(i) + 0.5 + (0.5 if r % 2 == 1 else 0.0)) / float(n)
			if t > 1.0:
				continue
			var mi: MeshInstance3D = lowball(parent, a.lerp(b, t) + Vector3(0, 0.12 + r * 0.22, 0), Vector3(0.42, 0.26, 0.62), "sandbag", r == rows - 1)
			mi.rotation.y = deg_to_rad(yaw + 90.0)


## Called from MapRocketGen.build_dressing (after T-276's pieces).
static func build(g: Object, d: Node3D) -> void:
	_tall.clear()
	var root: Node3D = Props.group(d, "RocketDetail", Vector3.ZERO)
	_perimeter_wire(root)
	_phone_line(root)
	_slit_trench(root)
	_guard_post(root)
	_revetments(root)
	_bowser_detail(root, MapRocketGen.FUEL_TRAILER, false)
	_bowser_detail(root, MapRocketGen.LOX_TRAILER, true)
	_erector_detail(root)
	_generator_detail(root)
	_extra_nets(root)
	_cables(root)
	_bunker_detail(root)
	_hut_detail(root)
	_clutter(root)
	_signs(root)
	_ground(root)
	_snow_banks(root)
	print("rocket detail: %d tall pieces registered, %d stand on the navmesh" % [_tall.size(), audit(g)])


## T-279: the whole site's dressing (T-276's and this pass's) merged into one mesh per material and shadow setting
## before gen_map00.merge_static_meshes runs. The site is one place: cut into 12 m cells by material it came to 345
## draw surfaces east of the old fence; merged it is a few dozen. Each merged mesh carries the "batch" meta, so
## merge_static_meshes still takes it into StaticBatches (the T-266 shadow proxies and occluders see it there).
## Skips what moves or must stay apart: meshes with "keep" (the lanterns), anything not a primitive with a material.
## Returns how many meshes it merged.
static func bake_site(root: Node3D) -> int:
	# (the merged meshes stand at the clearing's middle, so merge_static_meshes files them in a cell of their own and
	# never joins them to the inn's batches of the same material)
	var centre: Vector3 = Vector3(MapRocketGen.SITE.get_center().x - 1.0, 0.0, MapRocketGen.SITE.get_center().y)
	var to_centre: Transform3D = Transform3D(Basis.IDENTITY, -centre)
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or mi.has_meta("keep"):
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var key: String = "%d|%d" % [mi.material_override.get_instance_id(), int(mi.cast_shadow)]
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st}
		(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, to_centre * xf)
		victims.append(mi)
	for mi2: MeshInstance3D in victims:
		mi2.get_parent().remove_child(mi2)
		mi2.free()
	var i: int = 0
	for k: String in groups.keys():
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "SiteBake_%d" % i
		out.mesh = (groups[k]["st"] as SurfaceTool).commit()
		out.material_override = groups[k]["mat"]
		out.cast_shadow = groups[k]["shadow"]
		out.set_meta("batch", true)
		out.position = centre
		root.add_child(out)
		i += 1
	return victims.size()


## How many registered tall pieces stand on the baked navmesh (their footprint, 0.12 m in from each side, at five
## points). Each is printed. The pass is laid out so this is 0.
static func audit(g: Object) -> int:
	var bad: int = 0
	for row: Array in _tall:
		var r: Rect2 = (row[0] as Rect2).grow(-0.12)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			r = Rect2(row[0].get_center(), Vector2.ZERO)
		var hit: bool = false
		for p: Vector2 in [r.get_center(), r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			if bool(g.call("_on_nav", Vector3(p.x, 0.0, p.y))):
				hit = true
				break
		if hit:
			bad += 1
			print("DETAIL_AUDIT on the navmesh: %s %s" % [str(row[1]), str(row[0])])
	return bad


# ================================================================== the perimeter wire

## A wire fence on the line of every new edge wall (the walls are invisible: this is what stops a body there). Posts
## every 3 m leaning out, three strands, a SPERRGEBIET plate every few posts; at each spawn pocket the wire is cut
## and lies in the snow, its end posts knocked askew (the dead come in there).
static func _perimeter_wire(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "PerimeterWire", Vector3.ZERO)
	var cw: Dictionary = MapRocketGen.cut_walls()
	var k: int = 0
	for w: Array in cw["walls"]:
		var a2: Vector2 = w[0]
		var b2: Vector2 = w[1]
		var out2: Vector2 = w[2]
		var a: Vector3 = Vector3(a2.x, 0, a2.y)
		var b: Vector3 = Vector3(b2.x, 0, b2.y)
		var out: Vector3 = Vector3(out2.x, 0, out2.y)
		var length: float = a.distance_to(b)
		var n: int = maxi(1, int(round(length / 3.0)))
		var lean: Vector3 = out * 0.12
		var prev_top: Array = []
		for i: int in n + 1:
			var p: Vector3 = a.lerp(b, float(i) / float(n)) + out * 0.2
			Props.strut(gr, p, p + Vector3(0, 1.35, 0) + lean, 0.07, "beam")
			var tops: Array = []
			for h: float in [0.35, 0.8, 1.25]:
				tops.append(p + Vector3(0, h, 0) + lean * (h / 1.35))
			if not prev_top.is_empty():
				for s: int in 3:
					var mi: MeshInstance3D = Props.strut(gr, prev_top[s], tops[s], 0.012, "rust")
					if mi != null:
						mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			prev_top = tops
			k += 1
			if k % 5 == 0 and i > 0 and i < n:
				var face: float = rad_to_deg(atan2(-out.x, -out.z))
				var pl: Node3D = Props.group(gr, "WirePlate", p + Vector3(0, 1.0, 0) - out * 0.05, face + 180.0)
				Props.block(pl, Vector3(-0.22, -0.1, -0.01), Vector3(0.22, 0.1, 0.01), "paint_cream", false)
				_label(pl, "SPERRGEBIET", Vector3(0, 0, -0.015), 0.0016, 26)
	# the cut wire at the pockets: the two end posts askew, strands hanging to the snow
	for gp: Array in cw["gaps"]:
		var ga: Vector2 = gp[0]
		var gb: Vector2 = gp[1]
		var go: Vector2 = gp[2]
		var oa: Vector3 = Vector3(ga.x, 0, ga.y) + Vector3(go.x, 0, go.y) * 0.2
		var ob: Vector3 = Vector3(gb.x, 0, gb.y) + Vector3(go.x, 0, go.y) * 0.2
		var dirv: Vector3 = (ob - oa).normalized()
		for e: Array in [[oa, dirv], [ob, -dirv]]:
			var ep: Vector3 = e[0]
			var into: Vector3 = e[1]
			Props.strut(gr, ep, ep + Vector3(0, 1.25, 0) + into * 0.35, 0.08, "beam")
			for h2: float in [0.35, 0.8, 1.25]:
				var mi2: MeshInstance3D = Props.strut(gr, ep + Vector3(0, h2, 0), ep + into * (0.6 + h2 * 0.4) + Vector3(0, 0.04, 0), 0.012, "rust")
				if mi2 != null:
					mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ================================================================== the field telephone line

## The telephone line on poles outside the walls: along the track's north side, up the clearing's west side, along
## its north side to the dugout, where the wire drops onto the dugout's roof. Two wires on porcelain insulators.
const PHONE_POLES: Array = [Vector2(62.5, 35.5), Vector2(68.5, 35.5), Vector2(76.5, 35.5), Vector2(83.2, 35.2), Vector2(83.2, 27.5),
	Vector2(83.2, 19.5), Vector2(91.5, 17.2), Vector2(100.5, 17.2), Vector2(108.5, 17.2), Vector2(119.5, 17.2)]


static func phone_keep() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p: Vector2 in PHONE_POLES:
		out.append(Rect2(p - Vector2(1.2, 1.2), Vector2(2.4, 2.4)))
	return out


static func _phone_line(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "PhoneLine", Vector3.ZERO)
	var h: float = 5.6
	var tops: Array = []
	for i: int in PHONE_POLES.size():
		var p: Vector2 = PHONE_POLES[i]
		var base: Vector3 = Vector3(p.x, 0, p.y)
		Props.cyl(gr, base + Vector3(0, h * 0.5, 0), 0.11, h, "beam")
		lowball(gr, base + Vector3(0, 0.05, 0), Vector3(0.7, 0.2, 0.7), "snow")
		var nxt: Vector2 = PHONE_POLES[mini(i + 1, PHONE_POLES.size() - 1)] if i < PHONE_POLES.size() - 1 else PHONE_POLES[i - 1]
		var along: Vector2 = (nxt - p).normalized()
		var across: Vector3 = Vector3(-along.y, 0, along.x)
		Props.strut(gr, base + Vector3(0, h - 0.35, 0) - across * 0.55, base + Vector3(0, h - 0.35, 0) + across * 0.55, 0.08, "beam")
		var ins: Array = []
		for s: float in [-0.45, 0.45]:
			var ip: Vector3 = base + Vector3(0, h - 0.22, 0) + across * s
			Props._noshadow(Props.cyl(gr, ip, 0.035, 0.12, "enamel_white"))
			ins.append(ip + Vector3(0, 0.06, 0))
		tops.append(ins)
		if i == 4:
			var pg: Node3D = Props.group(gr, "PoleSign", base + Vector3(0.14, 2.1, 0), 90.0)
			Props.block(pg, Vector3(-0.3, -0.09, -0.01), Vector3(0.3, 0.09, 0.01), "paint_cream", false)
			_label(pg, "FERNSPRECHLEITUNG", Vector3(0, 0, -0.015), 0.0013, 26)
	for i2: int in tops.size() - 1:
		for s2: int in 2:
			Props.cable(gr, tops[i2][s2], tops[i2 + 1][s2], 0.35, 0.008, 6, "iron")
	# the drop to the dugout's roof (its north-east corner) and down to the desk's window
	var last: Array = tops[tops.size() - 1]
	var o: Rect2 = MapRocketGen.BUNKER_OUT
	Props.cable(gr, last[0], Vector3(o.end.x - 0.3, MapRocketGen.BUNKER_H + 0.55, o.position.y + 0.3), 0.6, 0.01, 6, "rubber")


# ================================================================== the slit trench and the guard post (beyond the walls)

const TRENCH: Array = [Vector2(100.2, 15.2), Vector2(103.2, 16.3), Vector2(106.2, 15.0), Vector2(109.2, 16.2), Vector2(112.0, 15.3)]
const GUARD_POST: Vector3 = Vector3(80.2, 0.0, 32.4)


## Where the forest leaves room for the trench, the guard post and the telephone poles (MapRocketGen._forest).
static func forest_keep() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(99.0, 12.6, 14.2, 5.2), Rect2(GUARD_POST.x - 2.6, GUARD_POST.z - 2.6, 5.2, 5.2)]
	out.append_array(phone_keep())
	return out


## A zig-zag slit trench outside the clearing's north wire: a dark cut in the snow with duckboards in it, an earth
## parapet both sides, sandbags along the far side, revetment stakes, snow on the spoil. (The ground there is the
## visible slab: the trench is drawn, not dug; nobody can reach it.)
static func _slit_trench(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "SlitTrench", Vector3.ZERO)
	for i: int in TRENCH.size() - 1:
		var a: Vector2 = TRENCH[i]
		var b: Vector2 = TRENCH[i + 1]
		var c: Vector2 = (a + b) * 0.5
		var length: float = a.distance_to(b) + 0.5
		var yaw: float = rad_to_deg(atan2(-(b - a).y, (b - a).x))
		var seg: Node3D = Props.group(gr, "TrenchSeg", Vector3(c.x, 0, c.y), yaw)
		Props._noshadow(Props.block(seg, Vector3(-length * 0.5, -0.05, -0.45), Vector3(length * 0.5, 0.02, 0.45), "rock_dark"))
		Props._noshadow(Props.block(seg, Vector3(-length * 0.5 + 0.1, 0.02, -0.22), Vector3(length * 0.5 - 0.1, 0.035, 0.22), "planks"))
		for side: float in [-1.0, 1.0]:
			Props.obox(seg, Vector3(0, 0.18, side * 0.78), Vector3(length, 0.42, 0.62), "dirt", Vector3(side * 14.0, 0, 0))
			Props._noshadow(Props.obox(seg, Vector3(0, 0.38, side * 0.85), Vector3(length * 0.95, 0.12, 0.5), "snow", Vector3(side * 14.0, 0, 0)))
			for st: int in int(length / 1.1):
				var sx: float = -length * 0.5 + 0.4 + st * 1.1
				Props._noshadow(Props.block(seg, Vector3(sx - 0.03, 0.0, side * 0.46 - 0.03), Vector3(sx + 0.03, 0.42, side * 0.46 + 0.03), "beam"))
		bags(seg, Vector3(-length * 0.5, 0.38, -1.0), Vector3(length * 0.5, 0.38, -1.0), 1)


## A sandbagged sentry post outside the track's north wire, by the clearing's mouth: a ring of bags three high, four
## posts and a plank roof under snow, a field telephone box on a post, a lantern on a hook.
static func _guard_post(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "GuardPost", GUARD_POST, 25.0)
	var n: int = 12
	for row: int in 3:
		for i: int in n:
			var a: float = TAU * (float(i) + (0.5 if row % 2 == 1 else 0.0)) / float(n)
			if i == 7 and row < 3:
				continue   # the way in, on the side away from the track
			var p: Vector3 = Vector3(cos(a), 0.12 + row * 0.22, sin(a)) * Vector3(1.25, 1.0, 1.25)
			var bag: MeshInstance3D = lowball(gr, p, Vector3(0.42, 0.26, 0.62), "sandbag", row == 2)
			bag.rotation.y = -a
	for c: Vector2 in [Vector2(-0.95, -0.95), Vector2(0.95, -0.95), Vector2(-0.95, 0.95), Vector2(0.95, 0.95)]:
		Props.block(gr, Vector3(c.x - 0.06, 0, c.y - 0.06), Vector3(c.x + 0.06, 2.05, c.y + 0.06), "beam")
	Props.obox(gr, Vector3(0, 2.12, 0), Vector3(2.5, 0.08, 2.5), "planks", Vector3(-6, 0, 0))
	Props._noshadow(Props.obox(gr, Vector3(0, 2.2, 0), Vector3(2.4, 0.1, 2.4), "snow", Vector3(-6, 0, 0)))
	Props.block(gr, Vector3(0.62, 0, 0.62), Vector3(0.7, 1.1, 0.7), "beam")
	Props.block(gr, Vector3(0.52, 1.1, 0.55), Vector3(0.8, 1.32, 0.75), "olive_drab")
	Props.lantern(gr, Vector3(-0.8, 1.7, -0.8), 2.08)


# ================================================================== revetments

## Earth berms with a course of sandbags along the propellant trailers' long sides and the generator's, inside the
## band the bake keeps clear round them; a sandbag skirt round the guard hut's north and west walls.
static func _revetments(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "Revetments", Vector3.ZERO)
	for c: Vector3 in [MapRocketGen.FUEL_TRAILER, MapRocketGen.LOX_TRAILER]:
		for side: float in [-1.0, 1.0]:
			var z: float = c.z + side * 1.47
			_berm(gr, Vector3(c.x - 3.4, 0, z), Vector3(c.x + 3.0, 0, z), side, 0.55)
	var gc: Vector3 = MapRocketGen.GEN_TRAILER
	for side2: float in [-1.0, 1.0]:
		_berm(gr, Vector3(gc.x - 1.6, 0, gc.z + side2 * 1.2), Vector3(gc.x + 1.6, 0, gc.z + side2 * 1.2), side2, 0.45)
	var h: Rect2 = MapRocketGen.HUT
	bags(gr, Vector3(h.position.x, 0, h.position.y - 0.25), Vector3(h.end.x, 0, h.position.y - 0.25), 2)
	bags(gr, Vector3(h.position.x - 0.25, 0, h.position.y), Vector3(h.position.x - 0.25, 0, h.end.y), 2)
	_reg(Rect2(h.position.x, h.position.y - 0.5, h.size.x, 0.5), "hut skirt N")
	_reg(Rect2(h.position.x - 0.5, h.position.y, 0.5, h.size.y), "hut skirt W")


## A low earth bank from a to b (along x) on the side `side` (+1 / -1 in z) of a trailer: banked earth, a course of
## bags on it, snow along the top. `w` its depth.
static func _berm(gr: Node3D, a: Vector3, b: Vector3, side: float, w: float) -> void:
	var c: Vector3 = (a + b) * 0.5
	var length: float = a.distance_to(b)
	Props.obox(gr, c + Vector3(0, 0.16, 0), Vector3(length, 0.38, w), "dirt", Vector3(side * 12.0, 0, 0))
	Props._noshadow(Props.obox(gr, c + Vector3(0, 0.33, side * 0.04), Vector3(length * 0.96, 0.08, w * 0.7), "snow", Vector3(side * 12.0, 0, 0)))
	var n: int = maxi(1, int(length / 0.62))
	for i: int in n:
		var p: Vector3 = a.lerp(b, (float(i) + 0.5) / float(n)) + Vector3(0, 0.45, -side * 0.05)
		lowball(gr, p, Vector3(0.42, 0.24, 0.6), "sandbag").rotation.y = deg_to_rad(90.0)
	_reg(Rect2(minf(a.x, b.x), c.z - w * 0.5, length, w), "berm %s" % str(c))


# ================================================================== the bowsers, the erector, the generator

## A propellant bowser's working parts, inside its own footprint: a ladder up its flank, a catwalk and handrail
## along the top, manhole domes, the delivery manifold at the rear with valves and gauges, a hose reel, mudguards,
## and on the oxidiser frost round the valves and lagging bands; drip stains under the valves.
static func _bowser_detail(root: Node3D, c: Vector3, lox: bool) -> void:
	var gr: Node3D = Props.group(root, "LoxDetail" if lox else "FuelDetail", c)
	var tank: String = "enamel_white" if lox else "olive_drab"
	# the ladder on the side facing the clearing's mouth (-x end) and the catwalk on top
	Props.ladder(gr, Vector3(-2.4, 0.92, 1.02), 0.0, 1.75, "olive_steel")
	Props.block(gr, Vector3(-2.9, 2.62, -0.28), Vector3(2.6, 2.66, 0.28), "steel_grate")
	for sz: float in [-0.3, 0.3]:
		for px: float in [-2.8, -1.0, 0.8, 2.5]:
			Props._noshadow(Props.block(gr, Vector3(px - 0.02, 2.66, sz - 0.02), Vector3(px + 0.02, 3.4, sz + 0.02), "olive_steel"))
		Props.block(gr, Vector3(-2.85, 3.36, sz - 0.025), Vector3(2.55, 3.41, sz + 0.025), "olive_steel")
	for dx: float in [-1.6, 0.9]:
		Props.cyl(gr, Vector3(dx, 2.66, 0), 0.26, 0.16, tank)
		Props.cyl(gr, Vector3(dx, 2.76, 0), 0.2, 0.05, "steel")
	# the manifold at the rear (+x, toward the table): a pipe header, three valve wheels, two gauges, a hose reel
	Props.pipe(gr, Vector3(3.3, 1.0, -0.7), Vector3(3.3, 1.0, 0.7), 0.06, "steel")
	for vz: float in [-0.5, 0.0, 0.5]:
		Props.valve_wheel(gr, Vector3(3.42, 1.0, vz), -90.0, 0.11, "red_paint" if not lox else "steel")
	Props.gauge(gr, Vector3(3.36, 1.42, -0.3), -90.0, 0.08)
	Props.gauge(gr, Vector3(3.36, 1.42, 0.3), -90.0, 0.08)
	Props.cyl(gr, Vector3(2.4, 0.95, -1.0), 0.32, 0.36, "rubber", Vector3(90, 0, 0))
	Props.cyl(gr, Vector3(2.4, 0.95, -1.0), 0.12, 0.4, "rust", Vector3(90, 0, 0))
	# mudguards over the wheels and the chassis' tool box
	for ax: float in [-1.9, 1.9]:
		for sz2: float in [-1.0, 1.0]:
			Props.obox(gr, Vector3(ax, 1.0, sz2 * 1.0), Vector3(1.1, 0.04, 0.34), "olive_steel", Vector3(0, 0, 0))
	Props.block(gr, Vector3(-0.6, 0.45, 0.88), Vector3(0.6, 0.72, 1.12), "olive_steel")
	if lox:
		for bx: float in [-2.7, -1.1, 0.5, 2.1]:
			Props.cyl(gr, Vector3(bx, 1.62, 0), 1.03, 0.22, "frosted", Vector3(0, 0, 90))
		for fp: Vector3 in [Vector3(3.3, 1.0, 0.0), Vector3(3.2, 1.25, -0.5), Vector3(2.6, 3.0, 0.45)]:
			lowball(gr, fp, Vector3(0.34, 0.26, 0.34), "frosted")
	else:
		Props._noshadow(Props.block(gr, Vector3(2.9, 0.012, -0.8), Vector3(3.8, 0.016, 0.8), "soot"))
	Props._noshadow(Props.block(gr, Vector3(3.1, 0.6, -0.75), Vector3(3.36, 1.6, 0.75), "grime"))


## The erector trailer's working parts on its chassis: the arm's rest cradle at the rear, the hydraulic pump set and
## its oil tank on the deck with pipes to the rams, the hand pump, side lockers, the tail lamps, chains and chocks on
## hooks; rust and grime on the frame.
static func _erector_detail(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "ErectorDetail", Vector3(0, 0, MapRocketGen.TABLE.z))
	var x0: float = MapRocketGen.TRAILER_X.x
	var x1: float = MapRocketGen.TRAILER_X.y
	# the rest cradle the arm lies in on the road (the arm is up now: the cradle stands empty)
	# (the lowered arm's rails lie 1.53..1.75 m up: the cradle's pad meets them, nothing of the deck rises into them)
	for sz: float in [-0.75, 0.75]:
		Props.strut(gr, Vector3(x0 + 1.0, 1.08, sz), Vector3(x0 + 1.0, 1.42, sz * 0.8), 0.12, "olive_steel")
	Props.block(gr, Vector3(x0 + 0.9, 1.38, -0.7), Vector3(x0 + 1.1, 1.48, 0.7), "olive_steel")
	Props.block(gr, Vector3(x0 + 0.88, 1.48, -0.55), Vector3(x0 + 1.12, 1.52, 0.55), "rubber")
	# the pump set: an engine box, the oil tank, the pump, pipes to the rams
	Props.block(gr, Vector3(x0 + 2.4, 1.08, -0.85), Vector3(x0 + 3.9, 1.46, -0.1), "machine_grey")
	for k: int in 5:
		Props._noshadow(Props.block(gr, Vector3(x0 + 2.55 + k * 0.28, 1.15, -0.86), Vector3(x0 + 2.7 + k * 0.28, 1.4, -0.84), "olive_steel"))
	Props.cyl(gr, Vector3(x0 + 3.2, 1.3, 0.45), 0.2, 0.9, "olive_drab", Vector3(0, 0, 90))
	Props.pipe(gr, Vector3(x0 + 3.9, 1.3, -0.5), Vector3(x1 - 4.2, 1.3, -0.55), 0.03, "steel")
	Props.pipe(gr, Vector3(x0 + 3.9, 1.4, -0.4), Vector3(x1 - 4.2, 1.4, 0.55), 0.03, "steel")
	Props.valve_wheel(gr, Vector3(x0 + 3.95, 1.32, -0.2), -90.0, 0.1, "red_paint")
	# side lockers along both side members, tail lamps, a chain and chocks on hooks
	for sz2: float in [-1.0, 1.0]:
		Props.block(gr, Vector3(x0 + 4.6, 0.5, sz2 * 1.17 - 0.06), Vector3(x0 + 6.4, 0.95, sz2 * 1.17 + 0.06), "olive_steel")
		Props._noshadow(Props.block(gr, Vector3(x0 + 4.65, 0.55, sz2 * 1.24 - 0.01), Vector3(x0 + 6.35, 0.9, sz2 * 1.24 + 0.01), "grime"))
		Props.block(gr, Vector3(x0 - 0.04, 0.78, sz2 * 0.95 - 0.08), Vector3(x0 + 0.02, 0.9, sz2 * 0.95 + 0.08), "lamp_red_off")
	for k2: int in 6:
		Props._noshadow(Props.cyl(gr, Vector3(x0 + 7.2 + k2 * 0.09, 0.62 - absf(k2 - 2.5) * 0.04, 1.2), 0.035, 0.02, "iron", Vector3(90, 0, 0)))
	Props._noshadow(Props.block(gr, Vector3(x0 + 0.3, 0.74, -1.18), Vector3(x1 - 0.3, 1.02, -1.16), "grime"))
	Props._noshadow(Props.block(gr, Vector3(x0 + 0.3, 0.74, 1.16), Vector3(x1 - 0.3, 1.02, 1.18), "rust"))


## The generator trailer's cables: three to the clearing (the table, the floodlight, the lamps), a cable drum and a
## fuel can beside it in its clear band, soot over the exhaust.
static func _generator_detail(root: Node3D) -> void:
	var gc: Vector3 = MapRocketGen.GEN_TRAILER
	var gr: Node3D = Props.group(root, "GenDetail", gc)
	Props.block(gr, Vector3(-1.5, 1.2, 0.81), Vector3(-0.8, 1.6, 0.86), "machine_grey")
	for k: int in 3:
		Props._noshadow(Props.cyl(gr, Vector3(-1.4 + k * 0.22, 1.3, 0.88), 0.035, 0.06, "bakelite", Vector3(90, 0, 0)))
	Props._noshadow(Props.block(gr, Vector3(1.0, 1.6, -0.86), Vector3(1.45, 2.35, -0.82), "soot"))
	Props.cyl(gr, Vector3(-1.85, 0.42, 0.35), 0.4, 0.34, "beam", Vector3(0, 0, 90))
	Props.cyl(gr, Vector3(-1.85, 0.42, 0.35), 0.2, 0.36, "rubber", Vector3(0, 0, 90))
	_reg(Rect2(gc.x - 2.05, gc.z + 0.15, 0.4, 0.4), "cable drum")
	var to: Array = [MapRocketGen.TABLE + Vector3(1.6, 0.04, 1.8), Vector3(MapRocketGen.FLOOD_POS.x, 0.04, MapRocketGen.FLOOD_POS.z), MapRocketGen.FUEL_TRAILER + Vector3(4.0, 0.04, 2.9)]
	for i: int in to.size():
		var start: Vector3 = gc + Vector3(-1.0 + i * 0.3, 0.04, -0.95)
		Props.cable(gr, start - gc, (to[i] as Vector3) - gc, 0.0, 0.025, 10, "rubber")   # (the group is not rotated: local = world - its origin)


# ================================================================== nets

## More camouflage: a net over the generator on poles at its corners, and the table's own frame with its nets rolled
## back onto the corner poles for the launch (the poles stand inside the table's footprint).
static func _extra_nets(root: Node3D) -> void:
	var gc: Vector3 = MapRocketGen.GEN_TRAILER
	var gn: Node3D = Props.group(root, "GenNet", gc)
	for sx: float in [-1.55, 1.55]:
		for sz: float in [-0.8, 0.8]:
			Props.cyl(gn, Vector3(sx, 1.6, sz), 0.06, 3.2, "beam")
	MapRocketGen.net_canopy(gn, Vector3.ZERO, Vector2(2.4, 1.6), 3.35, int(gc.x * 7.0))
	var t: Vector3 = MapRocketGen.TABLE
	var tf: Node3D = Props.group(root, "TableNetFrame", t)
	var hh: float = MapRocketGen.TABLE_HALF + 0.05
	var top: float = 6.0
	for sx2: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			var c: Vector3 = Vector3(sx2 * hh, 0, sz2 * hh)
			Props.cyl(tf, c + Vector3(0, top * 0.5, 0), 0.08, top, "beam")
			# the net rolled round the pole, lashed, a few boughs caught in it
			Props.cyl(tf, c + Vector3(0, 3.2, 0), 0.22, 2.6, "net")
			lowball(tf, c + Vector3(0.0, 4.2, 0.0), Vector3(0.6, 0.3, 0.6), "pine")
			Props._noshadow(Props.cyl(tf, c + Vector3(0, 2.2, 0), 0.24, 0.05, "rope"))
			Props._noshadow(Props.cyl(tf, c + Vector3(0, 4.3, 0), 0.24, 0.05, "rope"))
	# (no beams across the top: the fins span 3.56 m on the axes and pass between the corner poles at lift-off)


# ================================================================== cables

## The firing cables from the dugout to the table in a bundle on stakes, a junction box at the table's foot, plank
## cable covers where the paths cross them.
static func _cables(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "FiringCables", Vector3.ZERO)
	var o: Rect2 = MapRocketGen.BUNKER_OUT
	var t: Vector3 = MapRocketGen.TABLE
	var a: Vector3 = Vector3(116.6, 0.03, o.end.y + 0.15)
	var b: Vector3 = Vector3(t.x + MapRocketGen.TABLE_HALF + 0.12, 0.03, t.z - MapRocketGen.TABLE_HALF + 0.3)
	for k: int in 3:
		var off: Vector3 = Vector3(0.09 * k, 0, 0.05 * k)
		Props.cable(gr, a + off, b + off, 0.0, 0.022, 12, "rubber")
	var n: int = 6
	for i: int in range(1, n):
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		Props._noshadow(Props.block(gr, p + Vector3(-0.03, 0, -0.03), p + Vector3(0.03, 0.22, 0.03), "beam"))
	# a plank cover where the path from the dugout to the table crosses the bundle
	var mid: Vector3 = a.lerp(b, 0.5)
	var yaw: float = rad_to_deg(atan2(-(b - a).z, (b - a).x))
	var cov: Node3D = Props.group(gr, "CableCover", mid, yaw)
	Props._noshadow(Props.block(cov, Vector3(-0.6, 0.0, -0.35), Vector3(0.6, 0.06, 0.35), "planks"))
	# the junction box on the table's ring leg
	Props.block(gr, Vector3(t.x + 1.25, 0.25, t.z - 1.6), Vector3(t.x + 1.6, 0.75, t.z - 1.4), "machine_grey")
	Props._noshadow(Props.block(gr, Vector3(t.x + 1.27, 0.3, t.z - 1.62), Vector3(t.x + 1.58, 0.7, t.z - 1.61), "grime"))


# ================================================================== the dugout, the hut

## The dugout's dressing outside: timber facing boards each side of the doorway, a stove pipe through the roof with
## soot round it, the FEUERLEITSTAND board over the door, a tool rack on the north face, firewood on the east face,
## grime round the doorway; snow banked on the faces is in _snow_banks.
static func _bunker_detail(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "BunkerDetail", Vector3.ZERO)
	var o: Rect2 = MapRocketGen.BUNKER_OUT
	var h: float = MapRocketGen.BUNKER_H
	var dz0: float = MapRocketGen.BUNKER_DOOR.x
	var dz1: float = MapRocketGen.BUNKER_DOOR.y
	for span: Vector2 in [Vector2(o.position.y + 0.2, dz0 - 0.15), Vector2(dz1 + 0.15, o.end.y - 0.2)]:
		var k: int = 0
		var z: float = span.x
		while z < span.y - 0.05:
			var z1: float = minf(z + 0.24, span.y)
			Props.block(gr, Vector3(o.position.x - 0.16, 0, z), Vector3(o.position.x - 0.12, h - 0.45 - (k % 3) * 0.04, z1 - 0.01), "planks")
			z = z1
			k += 1
	Props._noshadow(Props.block(gr, Vector3(o.position.x - 0.17, 0, dz0 - 0.5), Vector3(o.position.x - 0.165, 2.0, dz1 + 0.5), "grime"))
	Props.cyl(gr, Vector3(o.end.x - 1.1, h + 1.1, o.position.y + 1.2), 0.09, 1.2, "rust")
	Props.cyl(gr, Vector3(o.end.x - 1.1, h + 1.72, o.position.y + 1.2), 0.15, 0.06, "rust")
	Props._noshadow(Props.cyl(gr, Vector3(o.end.x - 1.1, h + 0.53, o.position.y + 1.2), 0.5, 0.012, "soot"))
	# the tool rack on the north face: two posts, a rail, shovels, a pick, an axe
	var tr: Node3D = Props.group(gr, "ToolRack", Vector3(116.4, 0, o.position.y - 0.3), 0.0)
	_tool_rack(tr, 1.6)
	_reg(Rect2(115.6, o.position.y - 0.5, 1.6, 0.4), "bunker tool rack")
	# firewood on the east face
	for row: int in 3:
		for k2: int in 5:
			Props.cyl(gr, Vector3(o.end.x + 0.25, 0.12 + row * 0.22, o.position.y + 1.5 + k2 * 0.24), 0.1, 0.42, "pine" if (row + k2) % 2 == 0 else "beam", Vector3(0, 0, 90))
	_reg(Rect2(o.end.x, o.position.y + 1.4, 0.48, 1.3), "bunker firewood")


static func _hut_detail(root: Node3D) -> void:
	var r: Rect2 = MapRocketGen.HUT
	var gr: Node3D = Props.group(root, "HutDetail", Vector3.ZERO)
	# a water butt at the west wall's south end, a fire bucket rack on the north wall
	Props.barrel(gr, Vector3(r.position.x - 0.32, 0, r.end.y - 0.45), 0.0, 0.28, 0.85)
	_reg(Rect2(r.position.x - 0.5, r.end.y - 0.75, 0.5, 0.6), "hut water butt")
	var fr: Node3D = Props.group(gr, "FireBuckets", Vector3(r.position.x + 2.6, 0, r.position.y - 0.15), 180.0)
	Props.block(fr, Vector3(-0.6, 1.3, -0.04), Vector3(0.6, 1.36, 0.04), "beam")
	for k: int in 3:
		Props.cyl(fr, Vector3(-0.4 + k * 0.4, 1.1, 0.05), 0.11, 0.24, "red_paint")
	Props._noshadow(Props.block(gr, Vector3(r.position.x, 0.18, r.end.y + 0.005), Vector3(r.end.x, 0.9, r.end.y + 0.01), "grime"))


static func _tool_rack(tr: Node3D, w: float) -> void:
	for sx: float in [-w * 0.5, w * 0.5]:
		Props.block(tr, Vector3(sx - 0.04, 0, -0.04), Vector3(sx + 0.04, 1.5, 0.04), "beam")
	Props.block(tr, Vector3(-w * 0.5, 1.3, -0.05), Vector3(w * 0.5, 1.36, 0.05), "beam")
	var tools: Array = [["shovel", -0.55], ["shovel", -0.3], ["pick", 0.0], ["shovel", 0.25], ["axe", 0.5]]
	for t: Array in tools:
		var x: float = float(t[1]) * w / 1.6
		Props.strut(tr, Vector3(x, 0.15, -0.1), Vector3(x, 1.42, -0.04), 0.035, "beam", true)
		match str(t[0]):
			"shovel": Props.block(tr, Vector3(x - 0.11, 0.02, -0.14), Vector3(x + 0.11, 0.32, -0.11), "iron")
			"pick": Props.obox(tr, Vector3(x, 1.42, -0.06), Vector3(0.55, 0.05, 0.05), "iron", Vector3(0, 0, 8))
			_: Props.block(tr, Vector3(x, 1.3, -0.08), Vector3(x + 0.14, 1.46, -0.05), "iron")


# ================================================================== clutter in the clear bands

## What a battery leaves round its site, all in the bands along the wire or round the solids: drums of alcohol and
## empties, jerrycans, cable drums on their rims, stacked duckboards and timber, tarps over two crate stacks with
## their ropes, a tool rack by the hut. (T-276's drums and the extinguisher that stood out in the walk move here.)
static func _clutter(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "Clutter", Vector3.ZERO)
	var s: Rect2 = MapRocketGen.SITE
	# the west band: drums of alcohol in a row, two tipped; jerrycans
	for k: int in 6:
		var z: float = 49.0 + k * 0.62
		Props.oil_drum(gr, Vector3(s.position.x + 0.3, 0, z), "olive_drab")
	_reg(Rect2(s.position.x, 48.6, 0.6, 3.8), "drums W")
	for k2: int in 4:
		Props.block(gr, Vector3(s.position.x + 0.08, 0, 22.0 + k2 * 0.36), Vector3(s.position.x + 0.42, 0.46, 22.3 + k2 * 0.36), "olive_drab")
	_reg(Rect2(s.position.x, 21.9, 0.45, 1.5), "jerrycans W")
	# the north band: stacked duckboards leaning on the wire, a cable drum on its rim, empties tipped
	for k3: int in 3:
		Props.obox(gr, Vector3(87.5 + k3 * 1.4, 0.7, s.position.y + 0.32), Vector3(1.2, 1.4, 0.05), "planks", Vector3(-12, 0, 0))
	_reg(Rect2(86.8, s.position.y, 4.2, 0.45), "duckboards N")
	Props.cyl(gr, Vector3(121.5, 0.5, s.position.y + 0.24), 0.5, 0.36, "beam", Vector3(90, 0, 0))
	Props.cyl(gr, Vector3(121.5, 0.5, s.position.y + 0.24), 0.28, 0.4, "rubber", Vector3(90, 0, 0))
	_reg(Rect2(121.0, s.position.y, 1.0, 0.45), "cable drum N")
	for k4: int in 3:
		Props.oil_drum(gr, Vector3(103.0 + k4 * 0.62, 0, s.position.y + 0.3), "rust", k4 == 1)
	_reg(Rect2(102.7, s.position.y, 1.9, 0.6), "drums N")
	# the east band: a timber pile, a tool rack
	for row: int in 2:
		for k5: int in 4:
			Props.block(gr, Vector3(s.end.x - 0.42, row * 0.16, 33.0 + k5 * 0.02), Vector3(s.end.x - 0.08, row * 0.16 + 0.15, 36.5 - k5 * 0.02), "beam")
	_reg(Rect2(s.end.x - 0.45, 33.0, 0.45, 3.5), "timber E")
	var er: Node3D = Props.group(gr, "ToolRackE", Vector3(s.end.x - 0.22, 0, 45.5), 90.0)
	_tool_rack(er, 1.6)
	_reg(Rect2(s.end.x - 0.4, 44.7, 0.4, 1.6), "tool rack E")
	# the south band: stacked timber and empties
	for k6: int in 4:
		Props.oil_drum(gr, Vector3(112.0 + k6 * 0.7, 0, s.end.y - 0.3), "rust", true)
	_reg(Rect2(111.7, s.end.y - 0.6, 2.8, 0.6), "drums S")
	for row2: int in 3:
		Props.block(gr, Vector3(88.0, row2 * 0.12, s.end.y - 0.42), Vector3(95.0, row2 * 0.12 + 0.11, s.end.y - 0.1), "planks")
	_reg(Rect2(88.0, s.end.y - 0.45, 7.0, 0.45), "planks S")
	# the extinguisher at the table's foot (it stood in the walk)
	Props.cyl(gr, Vector3(105.95, 0.55, 37.95), 0.13, 1.1, "red_paint")
	# tarps over two crate stacks (inside their own footprints), lashed down
	for cs: Array in [MapRocketGen.CRATE_STACKS[0], MapRocketGen.CRATE_STACKS[3]]:
		var c: Vector3 = cs[0]
		var sz: Vector3 = cs[1]
		var tg: Node3D = Props.group(gr, "Tarp", c, float(cs[2]))
		Props.block(tg, Vector3(-sz.x * 0.5 - 0.02, sz.y - 0.02, -sz.z * 0.5 - 0.02), Vector3(sz.x * 0.5 + 0.02, sz.y + 0.04, sz.z * 0.5 + 0.02), "tarp")
		for side: float in [-1.0, 1.0]:
			Props.obox(tg, Vector3(0, sz.y * 0.72, side * (sz.z * 0.5 + 0.03)), Vector3(sz.x + 0.04, sz.y * 0.55, 0.03), "tarp", Vector3(side * 4.0, 0, 0))
		for k7: int in 2:
			var rx: float = -sz.x * 0.25 + k7 * sz.x * 0.5
			Props._noshadow(Props.block(tg, Vector3(rx - 0.015, 0, -sz.z * 0.5 - 0.05), Vector3(rx + 0.015, sz.y + 0.05, -sz.z * 0.5 - 0.04), "rope"))


# ================================================================== signs

static func _signs(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "Signs", Vector3.ZERO)
	var fuel: Vector3 = MapRocketGen.FUEL_TRAILER
	var lox: Vector3 = MapRocketGen.LOX_TRAILER
	var o: Rect2 = MapRocketGen.BUNKER_OUT
	# [position, yaw (the face looks along -Z after the yaw), text, width, colour]
	var rows: Array = [
		[fuel + Vector3(-4.6, 1.5, -2.8), 0.0, "FEUERGEFÄHRLICH!\nRAUCHEN VERBOTEN", 0.8, "paint_cream"],
		[lox + Vector3(-4.6, 1.5, 2.8), 180.0, "VORSICHT!\nFLÜSSIGER SAUERSTOFF", 0.8, "paint_cream"],
		[Vector3(MapRocketGen.FLOOD_POS.x - 0.12, 2.0, MapRocketGen.FLOOD_POS.z), 90.0, "LEBENSGEFAHR!\nABSTAND HALTEN", 0.8, "paint_cream"],
		[Vector3(o.position.x - 0.18, 2.3, (MapRocketGen.BUNKER_DOOR.x + MapRocketGen.BUNKER_DOOR.y) * 0.5), 90.0, "FEUERLEITSTAND", 1.1, "board_wood"],
		[Vector3(MapRocketGen.HUT.position.x + 2.0, 2.0, MapRocketGen.HUT.end.y + 0.02), 180.0, "WACHE", 0.6, "board_wood"],
		[MapRocketGen.GEN_TRAILER + Vector3(0.6, 1.25, -0.86), 0.0, "VORSICHT!\nSTARKSTROM", 0.55, "paint_cream"],
	]
	for r: Array in rows:
		var sg: Node3D = Props.group(gr, "Sign", r[0], float(r[1]))
		var w: float = float(r[3])
		var hgt: float = 0.36 if str(r[2]).contains("\n") else 0.24
		Props.block(sg, Vector3(-w * 0.5, -hgt * 0.5, -0.01), Vector3(w * 0.5, hgt * 0.5, 0.012), str(r[4]), false)
		_label(sg, str(r[2]), Vector3(0, 0, -0.016), 0.0026 if w > 0.7 else 0.0022, 34)


static func _label(parent: Node3D, text: String, pos: Vector3, px: float, size: int) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = Color(0.12, 0.08, 0.06)
	l.position = pos
	l.rotation.y = PI
	SurfaceText.apply(l)
	parent.add_child(l)


# ================================================================== the ground

## Tyre ruts from the mouth to the trailers and the generator, a half-track's tread marks round the table, trodden
## footpaths between the hut, the table, the dugout and the generator. All flat (1-2 cm), so they lie in the walks.
static func _ground(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "Ground", Vector3.ZERO)
	var routes: Array = [
		[Vector2(86.0, 40.0), Vector2(92.4, 40.0)],
		[Vector2(86.5, 39.0), Vector2(90.0, 33.5), Vector2(93.2, 29.2)],
		[Vector2(86.5, 41.0), Vector2(90.0, 46.5), Vector2(93.2, 51.0)],
		[Vector2(104.0, 46.0), Vector2(110.0, 49.5), Vector2(114.2, 53.6)],
	]
	for rt: Array in routes:
		for i: int in rt.size() - 1:
			_ruts(gr, rt[i], rt[i + 1], 1.6, 0.26, "dirt", 0.019)
	# a half-track's loop from the mouth round the south of the table to the dugout
	var ht: Array = [Vector2(87.0, 43.0), Vector2(98.0, 46.8), Vector2(110.5, 46.0), Vector2(113.0, 37.0), Vector2(112.4, 30.5)]
	for j: int in ht.size() - 1:
		_ruts(gr, ht[j], ht[j + 1], 1.9, 0.42, "snow_trodden", 0.021, true)
	# footpaths
	var paths: Array = [[Vector2(87.5, 30.6), Vector2(97.0, 34.5)], [Vector2(97.0, 34.5), Vector2(104.5, 37.6)], [Vector2(110.0, 38.0), Vector2(113.6, 27.0)],
		[Vector2(110.0, 42.0), Vector2(114.6, 52.4)], [Vector2(90.4, 28.0), Vector2(84.8, 37.2)]]
	for pth: Array in paths:
		_strip(gr, pth[0], pth[1], 0.9, "snow_trodden", 0.017)


static func _strip(gr: Node3D, a: Vector2, b: Vector2, w: float, key: String, y: float) -> MeshInstance3D:
	var c: Vector2 = (a + b) * 0.5
	var length: float = a.distance_to(b)
	var yaw: float = rad_to_deg(atan2(-(b - a).y, (b - a).x))
	return Props._noshadow(Props.obox(gr, Vector3(c.x, y * 0.5, c.y), Vector3(length + w * 0.5, y, w), key, Vector3(0, yaw, 0)))


static func _ruts(gr: Node3D, a: Vector2, b: Vector2, gauge: float, w: float, key: String, y: float, treads: bool = false) -> void:
	var d: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(-d.y, d.x) * gauge * 0.5
	for s: float in [-1.0, 1.0]:
		_strip(gr, a + n * s, b + n * s, w, key, y)
		if treads:
			var length: float = a.distance_to(b)
			var k: int = int(length / 0.5)
			for i: int in k:
				var p: Vector2 = a.lerp(b, (float(i) + 0.5) / float(k)) + n * s
				_strip(gr, p - d * 0.05, p + d * 0.05, w * 0.95, "dirt", y + 0.003)


## Snow banked against the dugout's and the hut's walls and the trailers' berms, and drifted against the wire.
static func _snow_banks(root: Node3D) -> void:
	var gr: Node3D = Props.group(root, "SnowBanks", Vector3.ZERO)
	var o: Rect2 = MapRocketGen.BUNKER_OUT
	var h: Rect2 = MapRocketGen.HUT
	for dr: Array in [[Vector3(o.end.x - 1.6, 0, o.position.y - 0.15), Vector3(2.6, 0.55, 0.6)],
			[Vector3(o.end.x + 0.15, 0, o.get_center().y + 1.5), Vector3(0.6, 0.5, 1.6)],
			[Vector3(o.get_center().x + 1.3, 0, o.end.y + 0.15), Vector3(2.0, 0.45, 0.55)],
			[Vector3(h.end.x + 0.15, 0, h.position.y + 0.35), Vector3(0.55, 0.45, 0.5)],
			[Vector3(h.end.x + 0.15, 0, h.end.y - 0.35), Vector3(0.55, 0.4, 0.6)],
			[Vector3(MapRocketGen.SITE.end.x - 0.15, 0, 26.0), Vector3(0.6, 0.6, 5.0)],
			[Vector3(98.0, 0, MapRocketGen.SITE.end.y - 0.15), Vector3(6.0, 0.5, 0.6)],
			[Vector3(MapRocketGen.SITE.position.x + 0.15, 0, 58.5), Vector3(0.6, 0.55, 4.0)]]:
		Props.snow_drift(gr, dr[0], dr[1])
	# drifts against the wire, outside it
	var s: Rect2 = MapRocketGen.SITE
	for dw: Array in [[Vector3(106.0, 0, s.position.y - 0.7), Vector3(9.0, 0.6, 1.2)], [Vector3(s.end.x + 0.7, 0, 40.0), Vector3(1.2, 0.6, 12.0)],
			[Vector3(92.0, 0, s.end.y + 0.7), Vector3(10.0, 0.6, 1.2)], [Vector3(119.0, 0, s.end.y + 0.7), Vector3(8.0, 0.55, 1.1)]]:
		Props.snow_drift(gr, dw[0], dw[1])
