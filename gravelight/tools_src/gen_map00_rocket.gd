class_name MapRocketGen
extends RefCounted
## T-276 (the owner: "make the initial map larger add a v2 rocket base on the right side of the map past the trees,
## with a new perk rocket man"): Map 0 grows east. Through a bought gate in the grounds' east fence a forest track
## (zone FORSTWEG) runs 24 m through the trees into a clearing (zone STELLUNG, 42 x 44 m): a firing site of the
## winter of 1944 as the batteries set them up in woods, the rocket standing on its firing table with the erector
## trailer backed up to it, the fuel and oxidiser trailers under camouflage netting, a sandbagged firing-control
## dugout you walk into (the Rocket Man machine stands in it), a guard hut, crates, cable runs, work lamps.
##
## gen_map00.gd calls this module from one hook per pass (geometry, dressing, gameplay) and three one-line filters
## (the east fence's cut, the tree line's gap, the edge carve), so its own diff stays small; everything about the
## site is here. Own geometry from Props and the map's materials; no insignia, no unit markings, no real-world text.
## The rocket itself, the erector arm and the launch are runtime nodes (gravelight/world/rocket/), not baked: they
## move. Frame as gen_map00: +X east, +Z south, y up.

const EDGE_LAYER: int = 1 << 10
const NAV_SOLID_H: float = 1.6

## The bought gate in the grounds' east fence (x 60): the opening's centre on the snow, its width along z.
const GATE: Vector3 = Vector3(60.0, 0.0, 40.0)
const GATE_W: float = 4.0
const GATE_COST: int = 1500
## The forest track (zone FORSTWEG) and the clearing (zone STELLUNG) as the walkable rects inside their edge walls.
const TRACK: Rect2 = Rect2(60.0, 36.5, 24.0, 7.0)
const SITE: Rect2 = Rect2(84.0, 18.0, 42.0, 44.0)
## The flat ground the new play space stands on (a hole in the Landscape terrain, LandscapeTerrain.ANNEX, on the 5 m
## terrain lattice): the visible snow slab; the colliders only under the walkable rects and the spawn pockets.
const ANNEX: Rect2 = Rect2(70.0, 10.0, 65.0, 60.0)
const POCKET_W: float = 3.0
const POCKET_D: float = 7.0
## The dead come out of the woods (kind "edge", as the grounds' T-084 pockets): [zone, spawn point (4.5 m beyond the
## wall), side the pocket opens to (0 north / -z, 1 south / +z, 2 west / -x, 3 east / +x)].
const EDGE_SPAWNS: Array = [
	["FORSTWEG", Vector3(72.0, 0, 32.0), 0],
	["STELLUNG", Vector3(97.0, 0, 13.5), 0],
	["STELLUNG", Vector3(115.0, 0, 13.5), 0],
	["STELLUNG", Vector3(130.5, 0, 31.0), 3],
	["STELLUNG", Vector3(130.5, 0, 51.0), 3],
	["STELLUNG", Vector3(104.0, 0, 66.5), 1],
	["STELLUNG", Vector3(79.5, 0, 54.0), 2],
]
## Snow risers in the clearing (kind "ground", round 4+), away from the table and the dugout.
const GROUND_SPAWNS: Array = [Vector3(91.5, 0, 56.5), Vector3(121.5, 0, 37.5)]

## The firing table (Brennstand) the rocket stands on: centre on the snow; its ring's top is where the fins rest.
const TABLE: Vector3 = Vector3(108.0, 0.0, 40.0)
const TABLE_TOP: float = 1.45
const TABLE_HALF: float = 1.5
## The erector trailer (Meillerwagen), backed up to the table from the west: chassis x span, deck height, the arm's
## hinge (the arm is the runtime RocketErector, it swings about this line, z axis).
const TRAILER_X: Vector2 = Vector2(95.0, 105.9)
const TRAILER_DECK: float = 1.15
const ERECTOR_HINGE: Vector3 = Vector3(106.1, 1.75, 40.0)
## The two propellant trailers under nets (centre, yaw 0 = along x) and the generator trailer.
const FUEL_TRAILER: Vector3 = Vector3(97.5, 0.0, 51.5)
const LOX_TRAILER: Vector3 = Vector3(97.5, 0.0, 28.5)
const GEN_TRAILER: Vector3 = Vector3(116.5, 0.0, 54.0)
## The firing-control dugout (Feuerleitstand): outer and inner rects (x, z), roof height; its doorway in the west wall
## (z span), its viewing slit in the south wall toward the table.
const BUNKER_OUT: Rect2 = Rect2(114.4, 23.4, 6.2, 5.2)
const BUNKER_IN: Rect2 = Rect2(115.2, 24.2, 4.6, 3.6)
const BUNKER_H: float = 2.3
const BUNKER_DOOR: Vector2 = Vector2(25.1, 26.9)
## The guard hut (Wachhaus) by the clearing's mouth: footprint (x, z), wall height.
const HUT: Rect2 = Rect2(86.4, 26.6, 4.0, 3.4)
const HUT_H: float = 2.3
## The Rocket Man machine's spot: on the dugout's east wall facing the doorway (a PERK_SPOTS-style row; the deal
## pins Rocket Man here, perk_layout.json "fixed").
const PERK_SPOT: Array = ["launch_bunker", "STELLUNG", Vector3(119.05, 0.0, 26.0), 90.0, {"flush": 1}]
## Wall-buys: [weapon, position, yaw so local -Z faces the walk] (gen_map00 BUYS' format): the STG-44 on the guard
## hut's east wall, facing the clearing. One only: of the weapons with a wall price the Gewehr 43 is already in the Old
## Cellar and the rest are on Map 0's walls but the M1 Carbine, an American rifle a German firing site would not hold.
const BUYS: Array = [
	[&"stg44", Vector3(HUT.end.x + 0.06, 1.5, HUT.position.y + 1.7), -90.0],
]
const AMMO_BOX: Array = ["Rocket", Vector3(112.2, 0.0, 21.95), 180.0]
## Felled-tree stumps left in the clearing (cover a body can stand behind; low enough to mantle): [centre, radius].
const STUMPS: Array = [[Vector3(90.5, 0, 45.8), 0.42], [Vector3(119.8, 0, 46.5), 0.38], [Vector3(102.0, 0, 21.8), 0.4],
	[Vector3(124.0, 0, 20.6), 0.36], [Vector3(87.5, 0, 59.6), 0.4]]
## Crate stacks (solid, no mantle): [centre on the snow, size (x, y, z), yaw].
const CRATE_STACKS: Array = [
	[Vector3(112.2, 0, 21.0), Vector3(2.2, 1.0, 1.1), 0.0],
	[Vector3(122.6, 0, 42.5), Vector3(1.1, 2.0, 2.2), 0.0],
	[Vector3(88.6, 0, 50.8), Vector3(2.2, 1.0, 1.1), 15.0],
	[Vector3(108.5, 0, 59.6), Vector3(3.3, 1.0, 1.1), 0.0],
]

## Lamps: [name, position, colour, energy, range, flicker amount (0 = steady)]. "Out" names get the outdoor tuning
## in gen_map00._lamp (no indoor gain). Only the table's floodlight (built in build_gameplay) asks for a shadow.
const LAMPS: Array = [
	["OutRktTrackLamp", Vector3(68.0, 2.55, 42.65), Color(1.0, 0.66, 0.36), 3.2, 12.0, 0.18],
	["OutRktHutLamp", Vector3(88.4, 2.15, HUT.end.y + 0.32), Color(1.0, 0.66, 0.36), 3.0, 11.0, 0.15],
	["OutRktNetLampN", Vector3(97.5, 3.1, 28.5), Color(0.95, 0.78, 0.55), 2.6, 11.0, 0.0],
	["OutRktNetLampS", Vector3(97.5, 3.1, 51.5), Color(0.95, 0.78, 0.55), 2.6, 11.0, 0.0],
	["OutRktGenLamp", Vector3(116.5, 2.6, 52.6), Color(0.95, 0.85, 0.65), 2.2, 9.0, 0.0],
	["OutRktMoonFill", Vector3(105.0, 7.0, 40.0), Color(0.5, 0.6, 0.85), 0.3, 30.0, 0.0],
	["RktBunkerBulb", Vector3(117.5, 2.05, 26.0), Color(1.0, 0.84, 0.62), 1.2, 6.0, 0.0],
]
const FLOOD_POS: Vector3 = Vector3(100.2, 6.2, 33.6)
const FLOOD_AIM: Vector3 = Vector3(108.0, 5.5, 40.0)


# ================================================================== filters gen_map00 applies

## Extra cuts in the grounds' edge wall and edge fences (gen_map00._cut_pockets): the gate's opening.
static func fence_cuts() -> Array[Rect2]:
	return [Rect2(GATE.x - 1.0, GATE.z - GATE_W * 0.5, 2.0, GATE_W)]


## The seed index a drawn fence segment had before the gate was cut into the east fence: the index of the uncut
## segment that holds it (so every other fence keeps its look); `fallback` when none does.
static func fence_seed(seg: Array, uncut: Array, fallback: int) -> int:
	var a: Vector2 = seg[0]
	var b: Vector2 = seg[1]
	for j: int in uncut.size():
		var u0: Vector2 = uncut[j][0]
		var u1: Vector2 = uncut[j][1]
		if Geometry2D.get_closest_point_to_segment(a, u0, u1).distance_to(a) < 0.01 and Geometry2D.get_closest_point_to_segment(b, u0, u1).distance_to(b) < 0.01:
			return j
	return fallback


## Where the grounds' tree line leaves a gap (gen_map00._tree_line): the track through it.
static func tree_gaps() -> Array[Rect2]:
	return [Rect2(TRACK.position.x - 1.0, TRACK.position.y - 0.6, TRACK.size.x + 2.0, TRACK.size.y + 1.2)]


## True when (x, z) is in the track's gap through the grounds' tree line (gen_map00._tree_line places nothing there;
## it still makes the same random draws, so the rest of the line stays where it was).
static func in_tree_gap(p: Vector2) -> bool:
	for r: Rect2 in tree_gaps():
		if r.has_point(p):
			return true
	return false


## The spawn pockets beyond the new edge walls: rects (x, z) from the wall line POCKET_D out, POCKET_W wide.
static func pockets() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for row: Array in EDGE_SPAWNS:
		out.append(_pocket(row[1], int(row[2])))
	return out


static func _pocket(p: Vector3, side: int) -> Rect2:
	match side:
		0: return Rect2(p.x - POCKET_W * 0.5, p.z + 4.5 - POCKET_D, POCKET_W, POCKET_D)
		1: return Rect2(p.x - POCKET_W * 0.5, p.z - 4.5, POCKET_W, POCKET_D)
		2: return Rect2(p.x + 4.5 - POCKET_D, p.z - POCKET_W * 0.5, POCKET_D, POCKET_W)
		_: return Rect2(p.x - 4.5, p.z - POCKET_W * 0.5, POCKET_D, POCKET_W)


## Everything the bake must keep walkable east of the old edge: the track, the clearing and their pockets.
static func keep_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [TRACK, SITE]
	out.append_array(pockets())
	return out


## The grounds' bake-only carve (gen_map00._carve_beyond_edge) with the new play space cut out of it.
static func trim_carve(rects: Array[Rect2]) -> Array[Rect2]:
	var cur: Array[Rect2] = rects
	for k: Rect2 in keep_rects():
		var nxt: Array[Rect2] = []
		for r: Rect2 in cur:
			nxt.append_array(subtract(r, k))
		cur = nxt
	return cur


## r minus k as up to four rects (none smaller than 5 cm).
static func subtract(r: Rect2, k: Rect2) -> Array[Rect2]:
	if not r.intersects(k):
		return [r]
	var out: Array[Rect2] = []
	var i: Rect2 = r.intersection(k)
	if i.position.y > r.position.y + 0.05:   # above (smaller z), full width
		out.append(Rect2(r.position.x, r.position.y, r.size.x, i.position.y - r.position.y))
	if r.end.y > i.end.y + 0.05:   # below, full width
		out.append(Rect2(r.position.x, i.end.y, r.size.x, r.end.y - i.end.y))
	if i.position.x > r.position.x + 0.05:   # left of the cut, its band only
		out.append(Rect2(r.position.x, i.position.y, i.position.x - r.position.x, i.size.y))
	if r.end.x > i.end.x + 0.05:
		out.append(Rect2(i.end.x, i.position.y, r.end.x - i.end.x, i.size.y))
	return out


## The new edge walls as [from (x, z), to (x, z), outward (x, z)] before the pocket cuts.
static func edge_walls() -> Array:
	var t: Rect2 = TRACK
	var s: Rect2 = SITE
	return [
		[Vector2(t.position.x, t.position.y), Vector2(t.end.x, t.position.y), Vector2(0, -1)],
		[Vector2(t.position.x, t.end.y), Vector2(t.end.x, t.end.y), Vector2(0, 1)],
		[Vector2(s.position.x, s.position.y), Vector2(s.position.x, t.position.y), Vector2(-1, 0)],
		[Vector2(s.position.x, t.end.y), Vector2(s.position.x, s.end.y), Vector2(-1, 0)],
		[Vector2(s.position.x, s.position.y), Vector2(s.end.x, s.position.y), Vector2(0, -1)],
		[Vector2(s.end.x, s.position.y), Vector2(s.end.x, s.end.y), Vector2(1, 0)],
		[Vector2(s.position.x, s.end.y), Vector2(s.end.x, s.end.y), Vector2(0, 1)],
	]


## The walls cut at the pockets: [[a, b, out], ...] and the gap fillers [[a, b, out], ...] (the wall's own run across
## each pocket; built outside the navigation region so the bake joins the pocket to the clearing).
static func cut_walls() -> Dictionary:
	var walls: Array = []
	var gaps: Array = []
	var pk: Array[Rect2] = pockets()
	for w: Array in edge_walls():
		var a: Vector2 = w[0]
		var b: Vector2 = w[1]
		var along_x: bool = is_equal_approx(a.y, b.y)
		var cuts: Array = []
		for r: Rect2 in pk:
			if along_x and absf(r.position.y - a.y) < 0.01 or along_x and absf(r.end.y - a.y) < 0.01:
				if r.end.x > minf(a.x, b.x) and r.position.x < maxf(a.x, b.x):
					cuts.append([r.position.x, r.end.x])
			elif not along_x and (absf(r.position.x - a.x) < 0.01 or absf(r.end.x - a.x) < 0.01):
				if r.end.y > minf(a.y, b.y) and r.position.y < maxf(a.y, b.y):
					cuts.append([r.position.y, r.end.y])
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var lo: float = minf(a.x, b.x) if along_x else minf(a.y, b.y)
		var hi: float = maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
		var cur: float = lo
		for c: Array in cuts:
			var c0: float = float(c[0])
			var c1: float = float(c[1])
			if c0 > cur + 0.05:
				walls.append([_on(a, along_x, cur), _on(a, along_x, c0), w[2]])
			gaps.append([_on(a, along_x, c0), _on(a, along_x, c1), w[2]])
			cur = maxf(cur, c1)
		if hi > cur + 0.05:
			walls.append([_on(a, along_x, cur), _on(a, along_x, hi), w[2]])
	return {"walls": walls, "gaps": gaps}


static func _on(a: Vector2, along_x: bool, v: float) -> Vector2:
	return Vector2(v, a.y) if along_x else Vector2(a.x, v)


## True when (x, z) is inside the new play space (the track, the clearing; not the pockets).
static func in_site(p: Vector3, margin: float = 0.0) -> bool:
	return TRACK.grow(-margin).has_point(Vector2(p.x, p.z)) or SITE.grow(-margin).has_point(Vector2(p.x, p.z))


# ================================================================== geometry (colliders: the navmesh's source)

## Called from gen_map00.build_grounds: the floors, the edge walls and their pocket gates, every solid.
static func build_geometry(g: Object) -> void:
	var geo: Node3D = g.get("geo")
	var root: Node3D = g.get("map_root")
	# the floors: under the track east of the old slab, the clearing and each pocket (0.5 m under the walls' line)
	g.call("box", geo, "GroundRktTrack", Vector3(70.0, -0.5, TRACK.position.y - 0.5), Vector3(TRACK.end.x + 0.5, 0.0, TRACK.end.y + 0.5), "snow", true, false)
	g.call("box", geo, "GroundRktSite", Vector3(SITE.position.x - 0.5, -0.5, SITE.position.y - 0.5), Vector3(SITE.end.x + 0.5, 0.0, SITE.end.y + 0.5), "snow", true, false)
	for r: Rect2 in pockets():
		var rr: Rect2 = r.grow(0.3)
		if rr.position.x < 70.0 and rr.end.x <= 70.0:
			continue   # on the old slab
		g.call("box", geo, "GroundRktPocket", Vector3(maxf(rr.position.x, 70.0), -0.5, rr.position.y), Vector3(rr.end.x, 0.0, rr.end.y), "snow", true, false)
	# the edge walls (bodies collide, shots pass; the bake reads them) and the pocket gates under the map root
	var gates: Node3D = root.get_node_or_null("EdgeGates") as Node3D
	if gates == null:
		gates = Node3D.new()
		gates.name = "EdgeGates"
		root.add_child(gates)
	var cw: Dictionary = cut_walls()
	for w: Array in cw["walls"]:
		_edge_box(g, geo, "RktEdge", w[0], w[1], w[2], 6.0)
	for w2: Array in cw["gaps"]:
		_edge_box(g, gates, "RktEdgeGate", w2[0], w2[1], w2[2], 6.0)
	# the firing table: a solid block (its legs and the deflector are drawn; nobody walks under a rocket)
	_solid(g, "RktTable", TABLE, Vector3(TABLE_HALF * 2.0 + 0.3, TABLE_TOP + 0.15, TABLE_HALF * 2.0 + 0.3), 0.0)
	# the erector trailer, the propellant trailers, the generator
	_solid(g, "RktTrailer", Vector3((TRAILER_X.x + TRAILER_X.y) * 0.5, 0, TABLE.z), Vector3(TRAILER_X.y - TRAILER_X.x, 1.55, 2.5), 0.0)
	_solid(g, "RktTowbar", Vector3(TRAILER_X.x - 1.2, 0, TABLE.z), Vector3(2.4, 0.7, 0.5), 0.0)
	for tp: Vector3 in [FUEL_TRAILER, LOX_TRAILER]:
		_solid(g, "RktTanker", tp, Vector3(7.4, 2.45, 2.4), 0.0)
	_solid(g, "RktGenerator", GEN_TRAILER, Vector3(3.4, 1.85, 1.9), 0.0)
	# the camouflage nets' poles (the nets hang over head height)
	for np: Vector3 in net_poles():
		g.call("box", geo, "RktNetPole", np + Vector3(-0.08, 0, -0.08), np + Vector3(0.08, NAV_SOLID_H, 0.08), "beam", true, false).set_meta("no_mantle", true)
	# the floodlight's mast and the track's lamp post
	for mp: Vector3 in [Vector3(FLOOD_POS.x, 0, FLOOD_POS.z), Vector3(68.0, 0, 43.0)]:
		g.call("box", geo, "RktPost", mp + Vector3(-0.1, 0, -0.1), mp + Vector3(0.1, NAV_SOLID_H, 0.1), "beam", true, false).set_meta("no_mantle", true)
	# the guard hut (solid: its door is drawn shut)
	_solid(g, "RktHut", Vector3(HUT.get_center().x, 0, HUT.get_center().y), Vector3(HUT.size.x, HUT_H + 0.6, HUT.size.y), 0.0)
	# crates, stumps, the barrier post
	for cs: Array in CRATE_STACKS:
		_solid(g, "RktCrates", cs[0], cs[1], float(cs[2]))
	for st: Array in STUMPS:
		var sp: Vector3 = st[0]
		var r: float = float(st[1])
		g.call("box", geo, "RktStump", sp + Vector3(-r, 0, -r), sp + Vector3(r, 0.55, r), "beam", true, false)
	g.call("box", geo, "RktBoomPost", Vector3(84.9, 0, 35.8), Vector3(85.3, 1.2, 36.2), "beam", true, false).set_meta("no_mantle", true)
	_bunker_shell(g, geo)


## The dugout's walls (sandbag revetments on a timber frame, 0.8 m thick), its roof of logs and earth.
static func _bunker_shell(g: Object, geo: Node3D) -> void:
	var o: Rect2 = BUNKER_OUT
	var i: Rect2 = BUNKER_IN
	var h: float = BUNKER_H
	# north and south walls (full length), west wall in two pieces round the doorway, east wall
	g.call("box", geo, "RktBunkerN", Vector3(o.position.x, 0, o.position.y), Vector3(o.end.x, h, i.position.y), "sandbag", true, false)
	g.call("box", geo, "RktBunkerS", Vector3(o.position.x, 0, i.end.y), Vector3(o.end.x, h, o.end.y), "sandbag", true, false)
	g.call("box", geo, "RktBunkerE", Vector3(i.end.x, 0, i.position.y), Vector3(o.end.x, h, i.end.y), "sandbag", true, false)
	g.call("box", geo, "RktBunkerW", Vector3(o.position.x, 0, i.position.y), Vector3(i.position.x, h, BUNKER_DOOR.x), "sandbag", true, false)
	g.call("box", geo, "RktBunkerW", Vector3(o.position.x, 0, BUNKER_DOOR.y), Vector3(i.position.x, h, i.end.y), "sandbag", true, false)
	g.call("box", geo, "RktBunkerLintel", Vector3(o.position.x, 2.05, BUNKER_DOOR.x), Vector3(i.position.x, h, BUNKER_DOOR.y), "beam", true, false)
	g.call("box", geo, "RktBunkerRoof", Vector3(o.position.x - 0.2, h, o.position.y - 0.2), Vector3(o.end.x + 0.2, h + 0.55, o.end.y + 0.2), "beam", true, false)
	# the desk under the slit
	g.call("box", geo, "RktBunkerDesk", Vector3(i.position.x + 0.5, 0, i.end.y - 0.62), Vector3(i.position.x + 2.6, 0.82, i.end.y), "furniture", true, false)


## The camouflage nets' poles: four round each propellant trailer.
static func net_poles() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for c: Vector3 in [FUEL_TRAILER, LOX_TRAILER]:
		for sx: float in [-4.6, 4.6]:
			for sz: float in [-2.7, 2.7]:
				out.append(c + Vector3(sx, 0, sz))
	return out


## An invisible collider along a..b (2D) on the edge layer, `h` high, 0.4 m thick outward of the line.
static func _edge_box(g: Object, parent: Node3D, name_: String, a: Vector2, b: Vector2, out: Vector2, h: float) -> void:
	var x0: float = minf(a.x, b.x)
	var x1: float = maxf(a.x, b.x)
	var z0: float = minf(a.y, b.y)
	var z1: float = maxf(a.y, b.y)
	if is_equal_approx(a.y, b.y):
		z0 = a.y + minf(0.0, out.y * 0.4)
		z1 = a.y + maxf(0.0, out.y * 0.4)
		x0 -= 0.4
		x1 += 0.4
	else:
		x0 = a.x + minf(0.0, out.x * 0.4)
		x1 = a.x + maxf(0.0, out.x * 0.4)
		z0 -= 0.4
		z1 += 0.4
	var bd: Node3D = g.call("box", parent, name_, Vector3(x0, -0.5, z0), Vector3(x1, h, z1), "snow", true, false)
	if bd == null:
		return
	bd.set_meta("no_mantle", true)
	(bd as StaticBody3D).collision_layer = EDGE_LAYER


## A hidden solid on the snow (gen_map00._solid: sliced to NAV_SOLID_H, no_mantle).
static func _solid(g: Object, name_: String, c: Vector3, sz: Vector3, yaw: float) -> void:
	g.call("_solid", name_, c, sz, yaw)


# ================================================================== dressing (no collision; batched by gen_map00)

## Called from gen_map00.build_dressing.
static func build_dressing(g: Object) -> void:
	var dress: Node3D = g.get("dress")
	var d: Node3D = Props.group(dress, "RocketSite", Vector3.ZERO)
	# the new flat ground (the Landscape terrain has a hole here)
	var slab: MeshInstance3D = Props.block(d, Vector3(ANNEX.position.x, -0.5, ANNEX.position.y), Vector3(ANNEX.end.x, 0.0, ANNEX.end.y), "snow")
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dress_track(d)
	_dress_table(d)
	_dress_trailer(d)
	_tanker(d, FUEL_TRAILER, false)
	_tanker(d, LOX_TRAILER, true)
	_generator(d)
	for c: Vector3 in [FUEL_TRAILER, LOX_TRAILER]:
		_net(d, c)
	_dress_bunker(d)
	_dress_hut(d)
	_dress_yard(d)
	_forest(d)


static func _dress_track(d: Node3D) -> void:
	var g: Node3D = Props.group(d, "ForestTrack", Vector3.ZERO)
	# the trodden track and its two ruts, from inside the grounds through the gate into the clearing
	Props._noshadow(Props.block(g, Vector3(57.5, 0.0, 38.3), Vector3(89.0, 0.014, 41.7), "snow_trodden"))
	for rz: float in [38.9, 41.1]:
		Props._noshadow(Props.block(g, Vector3(57.5, 0.0, rz - 0.22), Vector3(89.0, 0.02, rz + 0.22), "dirt"))
	# the gateposts and a board on a post: SPERRGEBIET
	for gz: float in [GATE.z - GATE_W * 0.5 - 0.12, GATE.z + GATE_W * 0.5 + 0.12]:
		Props.block(g, Vector3(GATE.x - 0.12, 0, gz - 0.12), Vector3(GATE.x + 0.12, 2.5, gz + 0.12), "beam")
		Props._noshadow(Props.block(g, Vector3(GATE.x - 0.14, 2.5, gz - 0.14), Vector3(GATE.x + 0.14, 2.6, gz + 0.14), "snow"))
	var sg: Node3D = Props.group(g, "SperrSign", Vector3(61.4, 0, 36.95), -90.0)
	Props.block(sg, Vector3(-0.06, 0, -0.06), Vector3(0.06, 1.9, 0.06), "beam")
	Props.block(sg, Vector3(-0.75, 1.3, -0.04), Vector3(0.75, 1.85, 0.0), "paint_cream")
	var l: Label3D = Label3D.new()
	l.text = "SPERRGEBIET\nBETRETEN VERBOTEN"
	l.font_size = 38
	l.pixel_size = 0.0034
	l.modulate = Color(0.12, 0.09, 0.08)
	l.position = Vector3(0, 1.575, -0.05)
	l.rotation.y = PI
	SurfaceText.apply(l)
	sg.add_child(l)
	Props._noshadow(Props.block(sg, Vector3(-0.78, 1.85, -0.06), Vector3(0.78, 1.9, 0.02), "snow"))
	# the field telephone cable on stakes along the track's north side
	var prev: Vector3 = Vector3(60.6, 0.75, 36.85)
	var x: float = 64.0
	while x <= 86.0:
		var p: Vector3 = Vector3(x, 0.75, 36.85)
		Props.block(g, Vector3(x - 0.04, 0, 36.81), Vector3(x + 0.04, 0.8, 36.89), "beam", false)
		Props.cable(g, prev, p, 0.12, 0.012, 4, "rubber")
		prev = p
		x += 3.5
	# the track's lamp on the south side (the north side has the pocket the dead walk in by): a post, an arm, a lantern
	Props.cyl(g, Vector3(68.0, 1.6, 43.0), 0.09, 3.2, "beam")
	Props.block(g, Vector3(67.95, 3.0, 42.5), Vector3(68.05, 3.08, 43.05), "beam")
	Props.lantern(g, Vector3(68.0, 2.55, 42.65), 3.0)
	# a felled spruce outside the south wall, branches lopped, and drifts along both sides
	var fs: Node3D = Props.group(g, "FelledLog", Vector3(77.0, 0, 44.4), 8.0)
	Props.cyl(fs, Vector3(0, 0.3, 0), 0.3, 7.0, "beam", Vector3(0, 0, 90))
	Props._noshadow(Props.ball(fs, Vector3(0, 0.58, 0), Vector3(6.8, 0.18, 0.5), "snow"))
	for dr: Array in [[Vector3(68.0, 0, 36.9), Vector3(9.0, 0.55, 1.4)], [Vector3(80.0, 0, 43.1), Vector3(7.0, 0.5, 1.3)],
			[Vector3(64.0, 0, 43.1), Vector3(5.0, 0.45, 1.2)]]:
		Props.snow_drift(g, dr[0], dr[1])


## The firing table: four splayed legs, a square ring the fins rest on, the blast deflector under it (a pyramid that
## throws the jet sideways), the steel blast plate on the snow, scorched.
static func _dress_table(d: Node3D) -> void:
	var g: Node3D = Props.group(d, "FiringTable", TABLE)
	var h: float = TABLE_HALF
	Props._noshadow(Props.block(g, Vector3(-3.6, 0.0, -3.6), Vector3(3.6, 0.03, 3.6), "steel"))
	Props._noshadow(Props.cyl(g, Vector3(0, 0.035, 0), 4.6, 0.012, "char"))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Props.strut(g, Vector3(sx * (h + 0.55), 0.03, sz * (h + 0.55)), Vector3(sx * (h - 0.05), TABLE_TOP - 0.2, sz * (h - 0.05)), 0.2, "olive_steel")
			Props.block(g, Vector3(sx * (h + 0.75) - 0.3, 0.03, sz * (h + 0.75) - 0.3), Vector3(sx * (h + 0.75) + 0.3, 0.12, sz * (h + 0.75) + 0.3), "olive_steel")
			# the levelling jacks' screws
			Props.cyl(g, Vector3(sx * (h + 0.75), 0.3, sz * (h + 0.75)), 0.06, 0.4, "steel")
	# the ring: four box beams
	for s: float in [-1.0, 1.0]:
		Props.block(g, Vector3(-h, TABLE_TOP - 0.25, s * h - 0.12), Vector3(h, TABLE_TOP, s * h + 0.12), "olive_steel")
		Props.block(g, Vector3(s * h - 0.12, TABLE_TOP - 0.25, -h), Vector3(s * h + 0.12, TABLE_TOP, h), "olive_steel")
	# the deflector cone (a four-sided pyramid, point up) and its scorched top
	Props.cone(g, Vector3(0, 0.55, 0), 1.25, 1.0, "olive_steel")
	Props.cone(g, Vector3(0, 0.95, 0), 0.5, 0.3, "char")
	# the turning ring the rocket's fins sit on, and the cable mast's base
	Props.cyl(g, Vector3(0, TABLE_TOP + 0.02, 0), 1.05, 0.05, "steel")
	Props.block(g, Vector3(h - 0.1, 0.03, -h - 0.9), Vector3(h + 0.2, 2.6, -h - 0.6), "olive_steel")


## The erector trailer's chassis (the arm is the runtime RocketErector): two long side members on two axles of
## twin wheels, a deck, the hydraulic rams' cylinders laid along it, the towbar to the west, chocks.
static func _dress_trailer(d: Node3D) -> void:
	var g: Node3D = Props.group(d, "ErectorTrailer", Vector3(0, 0, TABLE.z))
	var x0: float = TRAILER_X.x
	var x1: float = TRAILER_X.y
	for sz: float in [-1.0, 1.0]:
		Props.block(g, Vector3(x0, 0.75, sz * 1.05 - 0.12), Vector3(x1, 1.0, sz * 1.05 + 0.12), "olive_steel")
	for k: int in 6:
		var cx: float = x0 + 0.4 + k * (x1 - x0 - 0.8) / 5.0
		Props.block(g, Vector3(cx - 0.08, 0.78, -1.05), Vector3(cx + 0.08, 0.96, 1.05), "olive_steel")
	Props.block(g, Vector3(x0 + 0.3, 1.0, -0.9), Vector3(x1 - 0.2, 1.08, 0.9), "olive_steel")
	# the rams (two long cylinders from the deck to the arm's hinge end)
	for sz2: float in [-0.55, 0.55]:
		Props.cyl(g, Vector3(x1 - 3.0, 1.32, sz2), 0.16, 4.6, "olive_steel", Vector3(0, 0, 90 - 8.0))
	# axles and twin wheels
	for ax: float in [x0 + 2.2, x0 + 3.4]:
		for sz3: float in [-1.0, 1.0]:
			for dz: float in [0.0, 0.32]:
				var wz: float = sz3 * (1.0 + dz)
				Props.cyl(g, Vector3(ax, 0.5, wz), 0.5, 0.28, "rubber", Vector3(90, 0, 0))
				Props.cyl(g, Vector3(ax, 0.5, wz), 0.28, 0.3, "olive_steel", Vector3(90, 0, 0))
		Props.block(g, Vector3(ax - 0.08, 0.42, -1.3), Vector3(ax + 0.08, 0.58, 1.3), "steel")
	for ax2: float in [x1 - 2.4, x1 - 1.2]:
		for sz4: float in [-1.0, 1.0]:
			Props.cyl(g, Vector3(ax2, 0.5, sz4 * 1.18), 0.5, 0.3, "rubber", Vector3(90, 0, 0))
			Props.cyl(g, Vector3(ax2, 0.5, sz4 * 1.18), 0.28, 0.32, "olive_steel", Vector3(90, 0, 0))
		Props.block(g, Vector3(ax2 - 0.08, 0.42, -1.3), Vector3(ax2 + 0.08, 0.58, 1.3), "steel")
	# the towbar and its eye
	Props.strut(g, Vector3(x0, 0.85, -0.7), Vector3(x0 - 2.3, 0.55, 0), 0.12, "olive_steel")
	Props.strut(g, Vector3(x0, 0.85, 0.7), Vector3(x0 - 2.3, 0.55, 0), 0.12, "olive_steel")
	Props.cyl(g, Vector3(x0 - 2.4, 0.55, 0), 0.12, 0.08, "steel")
	# the outriggers on jacks at the table end, and wooden chocks under the wheels
	for sz5: float in [-1.0, 1.0]:
		Props.strut(g, Vector3(x1 - 0.3, 0.9, sz5 * 1.05), Vector3(x1 - 0.3, 0.05, sz5 * 2.0), 0.14, "olive_steel")
		Props.block(g, Vector3(x1 - 0.55, 0.0, sz5 * 2.0 - 0.25), Vector3(x1 - 0.05, 0.1, sz5 * 2.0 + 0.25), "planks")
	for cx2: float in [x0 + 1.55, x0 + 4.05]:
		for sz6: float in [-1.15, 1.15]:
			Props.obox(g, Vector3(cx2, 0.12, sz6), Vector3(0.3, 0.22, 0.4), "planks", Vector3(0, 0, 30))
	Props._noshadow(Props.ball(g, Vector3((x0 + x1) * 0.5 - 1.0, 1.1, 0), Vector3(5.0, 0.12, 1.6), "snow"))


## A propellant trailer: a long tank on a two-axle chassis. The oxidiser's is lagged (white, frosted, with a vent
## stack); the fuel's is a plain olive tank with a filler dome. Hoses coil on the snow.
static func _tanker(d: Node3D, c: Vector3, lox: bool) -> void:
	var g: Node3D = Props.group(d, "LoxTrailer" if lox else "FuelTrailer", c)
	var tank_key: String = "enamel_white" if lox else "olive_drab"
	Props.block(g, Vector3(-3.4, 0.7, -0.9), Vector3(3.4, 0.92, 0.9), "olive_steel")
	Props.cyl(g, Vector3(0, 1.62, 0), 1.0, 6.4, tank_key, Vector3(0, 0, 90))
	for ex: float in [-3.2, 3.2]:
		Props.ball(g, Vector3(ex, 1.62, 0), Vector3(0.45, 1.96, 1.96), tank_key)
	for bx: float in [-2.2, 0.0, 2.2]:
		Props.cyl(g, Vector3(bx, 1.62, 0), 1.04, 0.1, "olive_steel", Vector3(0, 0, 90))
	if lox:
		Props.cyl(g, Vector3(2.6, 3.0, 0.45), 0.09, 1.0, "steel")
		Props._noshadow(Props.ball(g, Vector3(0, 2.62, 0), Vector3(5.6, 0.12, 1.4), "snow"))
		Props.valve_wheel(g, Vector3(-3.55, 1.25, 0.4), 90.0, 0.14, "steel")
	else:
		Props.cyl(g, Vector3(-0.8, 2.68, 0), 0.32, 0.22, "olive_steel")
		Props._noshadow(Props.ball(g, Vector3(0.6, 2.6, 0), Vector3(5.0, 0.12, 1.3), "snow"))
		Props.valve_wheel(g, Vector3(-3.55, 1.25, 0.4), 90.0, 0.14, "red_paint")
	for ax: float in [-1.9, 1.9]:
		for sz: float in [-1.0, 1.0]:
			Props.cyl(g, Vector3(ax, 0.48, sz * 0.98), 0.48, 0.28, "rubber", Vector3(90, 0, 0))
			Props.cyl(g, Vector3(ax, 0.48, sz * 0.98), 0.26, 0.3, "olive_steel", Vector3(90, 0, 0))
	Props.strut(g, Vector3(-3.4, 0.8, -0.5), Vector3(-4.6, 0.5, 0), 0.1, "olive_steel")
	Props.strut(g, Vector3(-3.4, 0.8, 0.5), Vector3(-4.6, 0.5, 0), 0.1, "olive_steel")
	# a hose from the tank's end valve, coiled on the snow toward the table
	var toward: Vector3 = (TABLE - c)
	toward.y = 0.0
	toward = toward.normalized()
	var start: Vector3 = Vector3(3.5, 1.0, 0.0)
	var end_p: Vector3 = start + Vector3(toward.x, 0, toward.z) * 3.2 + Vector3(0, -0.95, 0)
	Props.cable(g, start, end_p, -0.15, 0.06, 6, "rubber")
	Props.rope_coil(g, end_p + Vector3(0.0, 0.0, 0.0) + Vector3(toward.x, 0, toward.z) * 0.6, 0.45)


## The generator trailer: a box body with louvres, a stub exhaust, two wheels.
static func _generator(d: Node3D) -> void:
	var g: Node3D = Props.group(d, "GenTrailer", GEN_TRAILER)
	Props.block(g, Vector3(-1.55, 0.6, -0.8), Vector3(1.55, 1.75, 0.8), "olive_drab")
	for k: int in 5:
		Props.block(g, Vector3(-1.2 + k * 0.5, 0.85, 0.79), Vector3(-0.95 + k * 0.5, 1.5, 0.82), "olive_steel", false)
	Props.cyl(g, Vector3(1.2, 2.0, -0.4), 0.07, 0.6, "rust")
	Props._noshadow(Props.block(g, Vector3(-1.6, 1.75, -0.85), Vector3(1.6, 1.85, 0.85), "snow"))
	for sz: float in [-1.0, 1.0]:
		Props.cyl(g, Vector3(0.2, 0.42, sz * 0.92), 0.42, 0.24, "rubber", Vector3(90, 0, 0))
	Props.strut(g, Vector3(-1.55, 0.7, 0), Vector3(-2.5, 0.45, 0), 0.09, "olive_steel")
	Props.fuse_box(g, Vector3(1.56, 1.2, 0.2), -90.0)
	# the lamp's bracket over the side door
	Props.block(g, Vector3(-0.05, 1.75, -0.85), Vector3(0.05, 1.8, -1.35), "iron")
	Props.lantern(g, Vector3(0.0, 2.6 - 0.0, -1.4), 2.75)


## A camouflage net over a trailer: four poles, the net in sloping panels with garnish tufts, sagging between.
static func _net(d: Node3D, c: Vector3) -> void:
	var g: Node3D = Props.group(d, "CamoNet", c)
	for sx: float in [-4.6, 4.6]:
		for sz: float in [-2.7, 2.7]:
			Props.cyl(g, Vector3(sx, 1.85, sz), 0.07, 3.7, "beam")
	# the net: a ridge at 4.3 m, eaves at 3.6 m, three panels a side; a few tufts of garnish (scrim)
	for side: float in [-1.0, 1.0]:
		for k: int in 3:
			var cx: float = -3.1 + k * 3.1
			var pz: float = side * 1.45
			var mi: MeshInstance3D = Props.obox(g, Vector3(cx, 3.95, pz), Vector3(3.25, 0.03, 3.0), "net", Vector3(side * -13.5, 0, 0))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(c.z * 13.0)
	for i: int in 18:
		var p: Vector3 = Vector3(rng.randf_range(-4.4, 4.4), 0.0, rng.randf_range(-2.6, 2.6))
		p.y = 4.3 - absf(p.z) * 0.24 - 0.05
		Props._noshadow(Props.ball(g, p, Vector3(rng.randf_range(0.5, 0.9), 0.14, rng.randf_range(0.4, 0.8)), "tarp" if i % 3 != 0 else "pine"))
	for i2: int in 7:
		var p2: Vector3 = Vector3(rng.randf_range(-4.2, 4.2), 0.0, rng.randf_range(-2.4, 2.4))
		p2.y = 4.3 - absf(p2.z) * 0.24 + 0.04
		Props._noshadow(Props.ball(g, p2, Vector3(rng.randf_range(0.8, 1.4), 0.08, rng.randf_range(0.6, 1.0)), "snow"))
	# guy ropes to pegs
	for sx2: float in [-4.6, 4.6]:
		for sz2: float in [-2.7, 2.7]:
			Props.cable(g, Vector3(sx2, 3.65, sz2), Vector3(sx2 * 1.25, 0.05, sz2 * 1.5), 0.0, 0.01, 1, "rope")


## The firing-control dugout: sandbag revetments on a timber frame, a log roof under earth and snow, the doorway
## framed in timber, the slit toward the table; inside a plank floor, the control desk with its switch panel and
## field telephone, a periscope through the roof, a bench, cable runs out under the sill.
static func _dress_bunker(d: Node3D) -> void:
	var g: Node3D = Props.group(d, "FiringBunker", Vector3.ZERO)
	var o: Rect2 = BUNKER_OUT
	var i: Rect2 = BUNKER_IN
	var h: float = BUNKER_H
	# the sandbag faces outside: a battered face of packed bags (the sandbag surface on boxes) and the top two
	# courses as single bags for the outline (all bags as spheres were 46 k shadow-casting triangles)
	for face: Array in [[Vector3(o.position.x - 0.12, 0, o.position.y - 0.12), Vector3(o.end.x + 0.12, h - 0.4, o.position.y + 0.3)],
			[Vector3(o.position.x - 0.12, 0, o.end.y - 0.3), Vector3(o.end.x + 0.12, h - 0.4, o.end.y + 0.12)],
			[Vector3(o.end.x - 0.3, 0, o.position.y), Vector3(o.end.x + 0.12, h - 0.4, o.end.y)],
			[Vector3(o.position.x - 0.12, 0, o.position.y), Vector3(o.position.x + 0.3, h - 0.4, BUNKER_DOOR.x - 0.14)],
			[Vector3(o.position.x - 0.12, 0, BUNKER_DOOR.y + 0.14), Vector3(o.position.x + 0.3, h - 0.4, o.end.y)]]:
		Props.block(g, face[0], face[1], "sandbag")
	for side: Array in [[Vector3(o.position.x, 0, o.position.y), Vector3(o.end.x, 0, o.position.y)], [Vector3(o.position.x, 0, o.end.y), Vector3(o.end.x, 0, o.end.y)],
			[Vector3(o.end.x, 0, o.position.y), Vector3(o.end.x, 0, o.end.y)],
			[Vector3(o.position.x, 0, o.position.y), Vector3(o.position.x, 0, BUNKER_DOOR.x - 0.1)], [Vector3(o.position.x, 0, BUNKER_DOOR.y + 0.1), Vector3(o.position.x, 0, o.end.y)]]:
		Props.sandbags(g, (side[0] as Vector3) + Vector3(0, h - 0.45, 0), (side[1] as Vector3) + Vector3(0, h - 0.45, 0), 2)
	# a slit in the south face: leave its bags out by drawing a dark board in the slit and a timber frame over it
	Props.block(g, Vector3(116.0, 1.35, o.end.y - 0.05), Vector3(118.4, 1.7, o.end.y + 0.06), "window_dark")
	Props.block(g, Vector3(115.9, 1.7, o.end.y - 0.1), Vector3(118.5, 1.82, o.end.y + 0.12), "beam")
	# the inner timber revetment (planks on posts) and the plank floor
	for wall: Array in [[Vector3(i.position.x, 0, i.position.y), Vector3(i.end.x, h, i.position.y + 0.06)], [Vector3(i.position.x, 0, i.end.y - 0.06), Vector3(i.end.x, h, i.end.y)],
			[Vector3(i.end.x - 0.06, 0, i.position.y), Vector3(i.end.x, h, i.end.y)],
			[Vector3(i.position.x, 0, i.position.y), Vector3(i.position.x + 0.06, h, BUNKER_DOOR.x)], [Vector3(i.position.x, 0, BUNKER_DOOR.y), Vector3(i.position.x + 0.06, h, i.end.y)]]:
		Props.block(g, wall[0], wall[1], "planks")
	for px: float in [i.position.x + 0.1, i.position.x + 1.6, i.position.x + 3.1, i.end.x - 0.1]:
		for pz: float in [i.position.y + 0.1, i.end.y - 0.1]:
			Props.block(g, Vector3(px - 0.08, 0, pz - 0.08), Vector3(px + 0.08, h, pz + 0.08), "beam")
	Props.block(g, Vector3(i.position.x, 0.0, i.position.y), Vector3(i.end.x, 0.03, i.end.y), "floorboards")
	# the roof: a timber ceiling inside, logs across outside, earth and snow over them
	Props.block(g, Vector3(i.position.x, h - 0.08, i.position.y), Vector3(i.end.x, h, i.end.y), "planks")
	for k: int in 8:
		var lx: float = o.position.x - 0.1 + (k + 0.5) * (o.size.x + 0.2) / 8.0
		Props.cyl(g, Vector3(lx, h + 0.17, o.get_center().y), 0.17, o.size.y + 0.4, "beam", Vector3(90, 0, 0))
	Props.block(g, Vector3(o.position.x - 0.2, h + 0.32, o.position.y - 0.2), Vector3(o.end.x + 0.2, h + 0.5, o.end.y + 0.2), "dirt")
	Props._noshadow(Props.ball(g, Vector3(o.get_center().x, h + 0.52, o.get_center().y), Vector3(o.size.x + 0.6, 0.35, o.size.y + 0.6), "snow"))
	# the doorway's frame and a blanket hung back on a nail
	Props.block(g, Vector3(o.position.x - 0.05, 0, BUNKER_DOOR.x - 0.14), Vector3(i.position.x + 0.05, 2.1, BUNKER_DOOR.x), "beam")
	Props.block(g, Vector3(o.position.x - 0.05, 0, BUNKER_DOOR.y), Vector3(i.position.x + 0.05, 2.1, BUNKER_DOOR.y + 0.14), "beam")
	Props.block(g, Vector3(o.position.x - 0.05, 2.05, BUNKER_DOOR.x - 0.14), Vector3(i.position.x + 0.05, 2.22, BUNKER_DOOR.y + 0.14), "beam")
	Props.block(g, Vector3(i.position.x + 0.08, 0.6, BUNKER_DOOR.y - 0.25), Vector3(i.position.x + 0.14, 2.0, BUNKER_DOOR.y), "feldgrau")
	# the desk under the slit: a plank top on trestles, the switch panel, the field telephone, a log book
	var dx0: float = i.position.x + 0.5
	var dx1: float = i.position.x + 2.6
	Props.block(g, Vector3(dx0, 0.76, i.end.y - 0.62), Vector3(dx1, 0.82, i.end.y - 0.06), "planks")
	for tx: float in [dx0 + 0.15, dx1 - 0.15]:
		Props.block(g, Vector3(tx - 0.04, 0, i.end.y - 0.55), Vector3(tx + 0.04, 0.76, i.end.y - 0.12), "beam")
	Props.block(g, Vector3(dx0 + 0.2, 0.82, i.end.y - 0.4), Vector3(dx0 + 1.2, 1.22, i.end.y - 0.12), "machine_grey")
	for k2: int in 6:
		Props.cyl(g, Vector3(dx0 + 0.3 + k2 * 0.15, 1.1, i.end.y - 0.405), 0.025, 0.04, "red_paint" if k2 == 5 else "bakelite", Vector3(90, 0, 0))
	Props.gauge(g, Vector3(dx0 + 0.55, 0.98, i.end.y - 0.41), 0.0, 0.07)
	Props.gauge(g, Vector3(dx0 + 0.95, 0.98, i.end.y - 0.41), 0.0, 0.07)
	Props.block(g, Vector3(dx0 + 1.45, 0.82, i.end.y - 0.42), Vector3(dx0 + 1.75, 1.0, i.end.y - 0.2), "bakelite")
	Props.block(g, Vector3(dx0 + 1.85, 0.82, i.end.y - 0.5), Vector3(dx0 + 2.05, 0.85, i.end.y - 0.22), "paper_old")
	# the periscope through the roof over the desk
	Props.cyl(g, Vector3(dx0 + 1.0, 1.75, i.end.y - 0.85), 0.06, 1.1, "olive_steel")
	Props.block(g, Vector3(dx0 + 0.92, 1.2, i.end.y - 0.95), Vector3(dx0 + 1.08, 1.32, i.end.y - 0.75), "olive_steel")
	Props.cyl(g, Vector3(dx0 + 1.0, h + 0.75, i.end.y - 0.85), 0.07, 0.5, "olive_steel")
	# the bench on the north wall (west of the rifle's chalk) and the bulb under a tin shade
	Props.bench(g, Vector3(i.position.x + 0.65, 0, i.position.y + 0.3), 90.0, 0.9)
	Props.cyl(g, Vector3(117.5, h - 0.15, 26.0), 0.16, 0.08, "tin")
	Props._noshadow(Props.ball(g, Vector3(117.5, h - 0.24, 26.0), Vector3(0.1, 0.12, 0.1), "bulb_warm"))
	# cables out under the slit to the table and the generator
	Props.cable(g, Vector3(117.2, 0.05, o.end.y + 0.1), Vector3(TABLE.x + TABLE_HALF, 0.05, TABLE.z - TABLE_HALF - 0.7), 0.0, 0.035, 10, "rubber")
	Props.cable(g, Vector3(118.0, 0.05, o.end.y + 0.1), Vector3(GEN_TRAILER.x, 0.05, GEN_TRAILER.z - 0.9), 0.0, 0.03, 12, "rubber")


## The guard hut: plank walls on a sill, a pent roof with snow, a shut door and a window, a stove pipe, a lantern.
static func _dress_hut(d: Node3D) -> void:
	var r: Rect2 = HUT
	var g: Node3D = Props.group(d, "GuardHut", Vector3(r.get_center().x, 0, r.get_center().y))
	var hx: float = r.size.x * 0.5
	var hz: float = r.size.y * 0.5
	Props.block(g, Vector3(-hx, 0, -hz), Vector3(hx, HUT_H, hz), "planks")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Props.block(g, Vector3(sx * hx - 0.08, 0, sz * hz - 0.08), Vector3(sx * hx + 0.08, HUT_H + 0.1, sz * hz + 0.08), "beam")
	Props.block(g, Vector3(-hx - 0.05, 0, -hz - 0.05), Vector3(hx + 0.05, 0.18, hz + 0.05), "beam")
	Props.obox(g, Vector3(0, HUT_H + 0.25, 0), Vector3(r.size.x + 0.7, 0.12, r.size.y + 0.7), "roof", Vector3(-8.0, 0, 0))
	Props._noshadow(Props.obox(g, Vector3(0, HUT_H + 0.34, 0), Vector3(r.size.x + 0.6, 0.12, r.size.y + 0.6), "snow", Vector3(-8.0, 0, 0)))
	# the door on the south face (toward the track) and the window on the east face
	Props.block(g, Vector3(-1.4, 0.0, hz), Vector3(-0.5, 2.0, hz + 0.05), "board_wood")
	Props.block(g, Vector3(-0.75, 0.95, hz + 0.05), Vector3(-0.65, 1.05, hz + 0.1), "iron")
	Props.block(g, Vector3(hx, 1.1, -1.3), Vector3(hx + 0.03, 1.7, -0.5), "bulb_warm")
	Props.block(g, Vector3(hx, 1.07, -1.33), Vector3(hx + 0.05, 1.1, -0.47), "beam")
	Props.block(g, Vector3(hx, 1.7, -1.33), Vector3(hx + 0.05, 1.73, -0.47), "beam")
	Props.cyl(g, Vector3(1.2, HUT_H + 0.7, -0.6), 0.08, 1.1, "rust")
	# the lantern on a bracket over the door, a bench and a rifle-less rack outside, a drift on the north wall
	Props.block(g, Vector3(0.0, 2.15, hz), Vector3(0.05, 2.2, hz + 0.45), "iron")
	Props.lantern(g, Vector3(0.0, 2.15 - 0.0, hz + 0.32), 2.4)
	Props.bench(g, Vector3(0.9, 0, hz + 0.4), 0.0, 1.2)
	Props.snow_drift(g, Vector3(0, 0, -hz - 0.6), Vector3(r.size.x + 0.4, 0.6, 1.2))


## The clearing's own pieces: the raised barrier at its mouth, crates, drums, stumps, the floodlight mast, the
## trodden apron round the table and the paths between the trailers, drifts along the edges.
static func _dress_yard(d: Node3D) -> void:
	var g: Node3D = Props.group(d, "SiteYard", Vector3.ZERO)
	# trodden snow: the apron round the table and the erector, the paths to the trailers, the dugout and the hut
	Props._noshadow(Props.block(g, Vector3(93.0, 0.0, 33.5), Vector3(114.0, 0.012, 46.5), "snow_trodden"))
	for p: Array in [[Vector3(95.0, 0.0, 26.0), Vector3(100.0, 0.011, 33.5)], [Vector3(95.0, 0.0, 46.5), Vector3(100.0, 0.011, 54.0)],
			[Vector3(110.0, 0.0, 24.5), Vector3(114.4, 0.011, 33.5)], [Vector3(85.0, 0.0, 30.5), Vector3(93.0, 0.011, 38.3)],
			[Vector3(112.0, 0.0, 46.5), Vector3(117.0, 0.011, 52.5)]]:
		Props._noshadow(Props.block(g, p[0], p[1], "snow_trodden"))
	# the barrier at the clearing's mouth, raised
	Props.block(g, Vector3(84.9, 0, 35.8), Vector3(85.3, 1.2, 36.2), "beam")
	var boom: Node3D = Props.group(g, "Boom", Vector3(85.1, 1.05, 36.0))
	for k: int in 7:
		var a: Vector3 = Vector3(0, k * 0.62, 0).rotated(Vector3.RIGHT, deg_to_rad(-12.0))
		var b: Vector3 = Vector3(0, (k + 1) * 0.62, 0).rotated(Vector3.RIGHT, deg_to_rad(-12.0))
		Props.strut(boom, a, b, 0.11, "red_paint" if k % 2 == 0 else "paint_cream")
	Props.block(boom, Vector3(-0.15, -0.35, -0.15), Vector3(0.15, -0.05, 0.6), "iron")
	# crate stacks on their colliders
	for cs: Array in CRATE_STACKS:
		var c: Vector3 = cs[0]
		var sz: Vector3 = cs[1]
		var cg: Node3D = Props.group(g, "CrateStack", c, float(cs[2]))
		var nx: int = maxi(1, int(round(sz.x / 1.1)))
		var ny: int = maxi(1, int(round(sz.y / 1.0)))
		var nz: int = maxi(1, int(round(sz.z / 1.1)))
		for ix: int in nx:
			for iy: int in ny:
				for iz: int in nz:
					Props.crate(cg, Vector3(-sz.x * 0.5 + 0.55 + ix * 1.1, iy * 1.0, -sz.z * 0.5 + 0.55 + iz * 1.1), 0.98, float((ix * 7 + iy * 3 + iz * 5) % 4) * 2.0)
		Props._noshadow(Props.ball(cg, Vector3(0, sz.y + 0.02, 0), Vector3(sz.x * 0.9, 0.1, sz.z * 0.9), "snow"))
	# drums of alcohol by the fuel trailer, a tipped one; a fire extinguisher cart's bottle by the table
	for dp: Vector3 in [Vector3(91.6, 0, 52.4), Vector3(92.3, 0, 52.6), Vector3(91.9, 0, 53.2), Vector3(92.7, 0, 53.4)]:
		Props.oil_drum(g, dp, "olive_drab")
	Props.oil_drum(g, Vector3(93.6, 0, 52.2), "olive_drab", true)
	Props.cyl(g, Vector3(103.5, 0.55, 36.2), 0.13, 1.1, "red_paint")
	# the stumps of the felled spruces
	for st: Array in STUMPS:
		var sp: Vector3 = st[0]
		var r: float = float(st[1])
		Props.cyl(g, sp + Vector3(0, 0.27, 0), r, 0.55, "beam")
		Props._noshadow(Props.cyl(g, sp + Vector3(0, 0.56, 0), r * 0.95, 0.04, "snow"))
	# the floodlight's mast: a pole, a cross arm, the lamp housing (the light itself is gameplay's RktFlood)
	var fp: Vector3 = Vector3(FLOOD_POS.x, 0, FLOOD_POS.z)
	Props.cyl(g, fp + Vector3(0, FLOOD_POS.y * 0.5, 0), 0.1, FLOOD_POS.y, "beam")
	Props.block(g, fp + Vector3(-0.6, FLOOD_POS.y - 0.1, -0.05), fp + Vector3(0.6, FLOOD_POS.y, 0.05), "beam")
	var aim: Vector3 = (FLOOD_AIM - FLOOD_POS).normalized()
	var lamp: Node3D = Props.group(g, "FloodHead", FLOOD_POS + Vector3(0, -0.25, 0), rad_to_deg(atan2(-aim.x, -aim.z)))
	Props.cyl(lamp, Vector3(0, 0, 0), 0.24, 0.42, "olive_steel", Vector3(90 + rad_to_deg(asin(aim.y)), 0, 0))
	Props._noshadow(Props.cyl(lamp, Vector3(0, aim.y * 0.22, -0.22), 0.2, 0.02, "flood_glass", Vector3(90 + rad_to_deg(asin(aim.y)), 0, 0)))
	Props.cable(g, fp + Vector3(0, 0.1, 0), Vector3(TABLE.x - TABLE_HALF - 0.4, 0.05, TABLE.z - TABLE_HALF - 0.4), 0.0, 0.03, 6, "rubber")
	# drifts along the walls of the clearing
	for dr: Array in [[Vector3(85.4, 0, 24.0), Vector3(1.6, 0.6, 10.0)], [Vector3(105.0, 0, 18.8), Vector3(16.0, 0.6, 1.6)],
			[Vector3(125.2, 0, 40.0), Vector3(1.6, 0.6, 12.0)], [Vector3(116.0, 0, 61.2), Vector3(14.0, 0.6, 1.6)], [Vector3(85.4, 0, 49.0), Vector3(1.5, 0.5, 6.0)]]:
		Props.snow_drift(g, dr[0], dr[1])


## The forest round the clearing and along the track: spruces (a birch here and there) in ragged rows beyond the edge
## walls, thicker than the grounds' tree line; bushes and boulders between. Built at load by a NatureRows node.
static func _forest(d: Node3D) -> void:
	var rows: NatureRows = NatureRows.new()
	rows.name = "RocketForest"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 276
	var keep: Array[Rect2] = [TRACK.grow(0.6), SITE.grow(0.6)]
	for pk: Rect2 in pockets():
		keep.append(pk.grow(1.0))
	# the grounds' own edge (x 60) and its tree line stay as they are: start the new trees 8 m past it
	var lo: Vector2 = Vector2(68.0, ANNEX.position.y - 6.0)
	var hi: Vector2 = Vector2(ANNEX.end.x + 6.0, ANNEX.end.y + 2.0)
	var y: float = lo.y
	while y < hi.y:
		var x: float = lo.x
		while x < hi.x:
			var p: Vector2 = Vector2(x + rng.randf_range(-1.3, 1.3), y + rng.randf_range(-1.3, 1.3))
			x += rng.randf_range(3.0, 4.2)
			var skip: bool = false
			for k: Rect2 in keep:
				if k.has_point(p):
					skip = true
					break
			if skip or (p.y > 70.0 and p.x < 80.0):   # (the carters' road runs south of the annex: keep its verge open)
				continue
			if rng.randf() < 0.07:
				continue   # a gap
			var dist_in: float = _dist_to_rects(p, [TRACK, SITE])
			if dist_in > 14.0:
				continue   # three or four rows deep is a wood from inside; the Landscape's swell takes over past that
			var hgt: float = rng.randf_range(10.0, 16.0) * (0.85 + 0.25 * clampf(dist_in / 14.0, 0.0, 1.0))
			var sc: Vector3 = Vector3(hgt * rng.randf_range(0.36, 0.46), hgt, hgt * rng.randf_range(0.36, 0.46))
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sc), Vector3(p.x, -0.3, p.y))
			var ux: Transform3D = Landscape.uniform_tree_xform(xf)
			if Landscape.is_birch(xf.origin):
				rows.birches.append(ux)
			else:
				rows.spruces.append(ux)
			if rng.randf() < 0.35:
				var s: float = rng.randf_range(0.8, 1.5)
				var bp: Vector3 = Vector3(p.x + rng.randf_range(-1.5, 1.5), 0.0, p.y + rng.randf_range(-1.5, 1.5))
				if not in_site(bp, -1.0):
					if rng.randf() < 0.7:
						rows.bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), bp - Vector3(0, 0.05, 0)))
					else:
						rows.rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), bp - Vector3(0, 0.2, 0)))
		y += rng.randf_range(3.0, 4.2)
	d.add_child(rows)
	print("rocket site: %d spruces, %d birches, %d bushes, %d rocks" % [rows.spruces.size(), rows.birches.size(), rows.bushes.size(), rows.rocks.size()])


static func _dist_to_rects(p: Vector2, rects: Array) -> float:
	var best: float = 1e9
	for r: Rect2 in rects:
		var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
		var dz: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
		best = minf(best, sqrt(dx * dx + dz * dz))
	return best


# ================================================================== gameplay

## Called from gen_map00.build_gameplay (after the grounds' gameplay): the gate, the zones, the spawns, the wall-buys
## and their lamps, the ammo box, the lamps, the floodlight, the launch site's event node.
static func build_gameplay(g: Object) -> void:
	var gameplay: Node3D = g.get("gameplay")
	var root: Node3D = g.get("map_root")
	# the gate: a field gate of planks in the east fence, chained; it swings east onto the track
	var dg: Node3D = g.call("_scripted", Node3D.new(), "res://gravelight/world/gate_door.gd", "Door_Rocket", {
		"door_id": &"door_rocket", "opens_zone": &"FORSTWEG", "also_opens": PackedStringArray(["STELLUNG"]), "cost": GATE_COST,
		"size": Vector3(GATE_W, 2.3, 0.25), "label": "The Forest Track", "leaves": 2, "swing_deg": 100.0, "swing_out": 1.0})
	dg.position = GATE
	dg.rotation.y = deg_to_rad(90.0)
	gameplay.add_child(dg)
	# zones (roam: open ground, the dead go for a player standing on it)
	var zones: Array = [
		[&"FORSTWEG", Vector3(TRACK.get_center().x, 0, TRACK.get_center().y), Vector3(TRACK.size.x, 3.0, TRACK.size.y)],
		[&"STELLUNG", Vector3(SITE.get_center().x, 0, SITE.get_center().y), Vector3(SITE.size.x, 3.4, SITE.size.y)],
	]
	for row: Array in EDGE_SPAWNS:
		var pk: Rect2 = _pocket(row[1], int(row[2]))
		zones.append([StringName(str(row[0])), Vector3(pk.get_center().x, 0, pk.get_center().y), Vector3(pk.size.x, 3.0, pk.size.y)])
	var zi: int = 0
	for z: Array in zones:
		var zv: Node3D = g.call("_scripted", Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_%s_r%d" % [z[0], zi], {"zone_id": z[0], "size": z[2], "roam": true})
		zv.position = z[1]
		gameplay.add_child(zv)
		zi += 1
	# spawns: out of the woods (edge pockets) and from the snow (round 4+), only while a player stands in the zone
	var i: int = 0
	for row2: Array in EDGE_SPAWNS:
		var sp: Marker3D = g.call("_scripted", Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_RktEdge%d" % i, {
			"zone_id": StringName(str(row2[0])), "kind": &"edge", "player_zone_only": true, "hide_from_m": 12.0}) as Marker3D
		sp.position = row2[1]
		gameplay.add_child(sp)
		i += 1
	i = 0
	for p: Vector3 in GROUND_SPAWNS:
		var gs: Marker3D = g.call("_scripted", Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_RktSnow%d" % i, {
			"zone_id": &"STELLUNG", "kind": &"ground", "min_round": 4, "player_zone_only": true, "hide_from_m": 10.0}) as Marker3D
		gs.position = p
		gameplay.add_child(gs)
		i += 1
	# wall-buys with their small lamps (as gen_map00's BUYS)
	for b: Array in BUYS:
		var wb: Node3D = g.call("_scripted", Node3D.new(), "res://gravelight/world/wall_buy.gd", "WallBuy_" + String(b[0]), {"weapon_id": b[0]})
		wb.position = b[1]
		wb.rotation.y = deg_to_rad(float(b[2]))
		gameplay.add_child(wb)
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = "BuyLight"
		lamp.light_color = Color(1.0, 0.8, 0.55)
		lamp.light_energy = 0.6
		lamp.omni_range = 1.8
		lamp.position = (b[1] as Vector3) + Basis(Vector3.UP, deg_to_rad(float(b[2]))) * Vector3(0, 0.75, -0.5)
		gameplay.add_child(lamp)
	var ammo: Node3D = g.call("_scripted", Node3D.new(), "res://gravelight/world/ammo_box.gd", "AmmoBox_" + str(AMMO_BOX[0]), {"box_name": str(AMMO_BOX[0]).to_lower()})
	ammo.position = AMMO_BOX[1]
	ammo.rotation.y = deg_to_rad(float(AMMO_BOX[2]))
	gameplay.add_child(ammo)
	# the lamps (no shadows) and the floodlight on the rocket (the site's one shadowed light; electric: on the
	# generator, it burns from the start)
	for lr: Array in LAMPS:
		g.call("_lamp", str(lr[0]), lr[1], lr[2], float(lr[3]), float(lr[4]), false, float(lr[5]) > 0.0, float(lr[5]))
	var fl: SpotLight3D = SpotLight3D.new()
	fl.name = "OutRktFlood"
	fl.light_color = Color(0.95, 0.9, 0.8)
	fl.light_energy = 5.0
	fl.spot_range = 26.0
	fl.spot_angle = 24.0
	fl.spot_attenuation = 1.2
	fl.shadow_enabled = true
	fl.light_volumetric_fog_energy = 0.4
	root.add_child(fl)
	fl.position = FLOOD_POS
	fl.look_at_from_position(FLOOD_POS, FLOOD_AIM, Vector3.UP)
	# the launch: the rocket on its table, the erector arm, the sequence (RocketLaunch reads map00.json "rocket_launch")
	var rl: Node3D = g.call("_scripted", Node3D.new(), "res://gravelight/world/rocket/rocket_launch.gd", "RocketLaunch", {})
	rl.position = TABLE
	gameplay.add_child(rl)
