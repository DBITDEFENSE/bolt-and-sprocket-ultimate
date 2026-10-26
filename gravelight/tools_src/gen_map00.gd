extends SceneTree
## Generates Map 0 "Crossroads Inn" (Gasthaus Zum Kreuzweg): collision geometry with a baked navmesh,
## a full art-dressing pass (procedural materials, props, weather, lighting, post), and gameplay nodes.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map00.gd
## THIS FILE is the source of truth for the map (DECISIONS D-024): edit here and re-run.
##
## Two layers are kept apart on purpose:
##   - build_geometry(): the collision shell. Only these StaticBodies are baked into the navmesh.
##   - build_dressing(): everything decorative. Non-colliding, so dressing never changes navigation.
##
## Frame: +X east, +Z south, +Y up. The taproom's north wall is z = 0. 1 unit = 1 m.

const OUT: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const T: float = 0.3          # wall thickness
const TAP_H: float = 3.5      # taproom ceiling
const UP_Y: float = 3.8       # upstairs floor top
const UP_TOP: float = 6.8     # upstairs ceiling
const STABLE_H: float = 7.0
## The stable ("the barn", T-084: "about 10% bigger ... improve the staircase and the second level"): x 4.5..25.5
## by z 22..34 (21 x 12 m; it was 18 x 12, x 6..24). The hayloft (LOFT_Y..LOFT_TOP) is the west block x 4.5..LOFT_X1
## over the full depth and a gallery along the south wall from LOFT_X1 to the east wall, z GAL_Z0..34, over the great
## doors (3 m high now); the bay over the stalls, the hay pile and the north door is open to the roof. A straight
## flight up the east wall (HSTAIR_*: 2 m wide, foot z 25.5, head z 31.5, 30 deg) lands through a well in the gallery.
const STB_X0: float = 4.5
const STB_X1: float = 25.5
const STB_Z0: float = 22.0
const STB_Z1: float = 34.0
const LOFT_Y: float = 3.2
const LOFT_TOP: float = 3.5
const LOFT_X1: float = 15.5
const GAL_Z0: float = 29.0
const HSTAIR_X0: float = 23.35
const HSTAIR_X1: float = 25.35
const HSTAIR_Z0: float = 25.5
const HSTAIR_Z1: float = 31.5
const HSTAIR_STEPS: int = 16
const GREAT_DOOR_H: float = 3.0
const LOFT_DROP: Vector2 = Vector2(18.6, 20.0)   # the bale drop: the open bay in the gallery's rail (walk off; zombies don't path it)
## Physics layer 11 "edge" (T-084): the grounds' edge wall and the boundary fences on it. Bodies collide with it
## (Player.MASK_MOVE), shots, projectiles, blasts and the aim/interaction rays don't (they mask layer 1), so a
## zombie beyond the edge can be shot. The navmesh bake reads it (bake_navmesh's geometry_collision_mask).
const EDGE_LAYER: int = 1 << 10
const WIN_SILL: float = 0.9
const WIN_TOP: float = 2.2
const DOOR_H: float = 2.4
const WAINSCOT_H: float = 1.1
## The staircase to the guest rooms (playtest 2026-10-21: the old 2.7 m flight in a 3 m well was too cramped). The well is
## x 0..STAIR_X1, z 10..16, full height: the flight runs up the west wall, open on its east side over a 2.2 m
## vestibule that Door 1 opens into, and lands a metre inside the upstairs hall; the hall overlooks the well.
const STAIR_X1: float = 6.0        # the well's east wall (Door 1 is in it)
const FLIGHT_X1: float = 3.65      # the flight's open edge; the vestibule is x FLIGHT_X1..STAIR_X1
const STAIR_Z0: float = 14.3       # the foot of the flight (its first riser)
const STAIR_Z1: float = 9.0        # its head, in the hall
## The inn's front door in the taproom's north wall, under the east porch roof (T-072).
const FRONT_DOOR_X: float = 20.0
## The taproom's added tables (playtest: "the initial room needs more tables", T-072): [centre (x, z), width (x),
## depth (z), seating: "chairs" (one each side) / "pair" (west and east) / "benches" (along both long sides)]. They
## stand inside the clockwise training loop (1.4 m+ clear of its line, routes_map00.json) or west of it.
const TAP_TABLES_NEW: Array = [
	[Vector2(19.0, 9.0), 1.2, 1.2, "chairs"],    # the carters' table (Kubiak and Rother): cards and steins
	[Vector2(16.0, 4.8), 1.2, 1.2, "chairs"],    # a table cleared in a hurry
	[Vector2(12.3, 5.4), 0.9, 0.9, "pair"],      # by the hearth: Frau Pohl's coffee, her suitcase beside it
	[Vector2(8.0, 11.8), 0.9, 2.4, "benches"],   # the long trestle by the stair wall
]

## Old greybox keys -> material library keys (world/materials.gd).
const MAT_MAP: Dictionary = {
	"wall": "plaster", "wall_upper": "plaster_upper", "stable": "planks", "floor_wood": "floorboards",
	"floor_dirt": "dirt", "snow": "snow", "roof": "roof", "furniture": "furniture", "stone": "stone",
	"stairs": "furniture", "metal": "iron", "quest": "nachtglas", "fire": "fire", "hay": "hay", "wreck": "wreck",
}

## Invisible colliders whose dressing fills them closely enough for bullet holes to stay (Effects.persists_on;
## every other invisible collider is tagged "decal_persist" false: tables, rail panels, fences, the great doors).
const PERSIST_HIDDEN: Array = ["Hearth", "BarFront", "BarSide", "Bed1", "Bed2", "Bed3", "TechTrunk", "HayBales", "YardTrough", "Well"]

var map_root: Node3D
var nav: NavigationRegion3D
var geo: Node3D
var dress: Node3D
var gameplay: Node3D
var _count: int = 0
var _bake_only: Array[Node] = []
var _frames: int = 0


func _initialize() -> void:
	map_root = Node3D.new()
	map_root.name = "Map00Crossroads"
	get_root().add_child(map_root)
	nav = NavigationRegion3D.new()
	nav.name = "Navigation"
	map_root.add_child(nav)
	geo = Node3D.new()
	geo.name = "Geometry"
	nav.add_child(geo)
	dress = Node3D.new()   # outside the NavigationRegion3D, so the bake never parses dressing
	dress.name = "Dressing"
	map_root.add_child(dress)
	build_geometry()


## Baking needs the nodes inside the tree, which only holds once the main loop is running.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	bake_navmesh()
	for n: Node in _bake_only:   # colliders that only shape the navmesh (T-051)
		n.get_parent().remove_child(n)
		n.free()
	_bake_breach_open()
	get_root().remove_child(map_root)
	build_dressing()
	var merged: int = merge_static_meshes()
	print("merged %d static meshes into batches" % merged)
	build_environment()
	build_landscape()
	build_gameplay()
	build_reactive()
	_own(map_root, map_root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(map_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("Saved %s (%d collision boxes), err=%d" % [OUT, _count, err])
	map_root.free()
	return true


# ================================================================== helpers

func mat(key: String) -> Material:
	return Mats.get_mat(str(MAT_MAP.get(key, key)))


## Axis-aligned box from min/max corners. collide = a static collider on the "world" layer.
## visible = false makes a collider with no mesh (the dressing pass draws it instead).
func box(parent: Node3D, name_: String, a: Vector3, b: Vector3, mat_key: String, collide: bool = true, visible: bool = true) -> Node3D:
	var size: Vector3 = (b - a).abs()
	var center: Vector3 = (a + b) * 0.5
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return null
	var mi: MeshInstance3D = null
	if visible:
		mi = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = size
		mi.material_override = mat(mat_key)
	if not collide:
		mi.name = name_
		mi.position = center
		parent.add_child(mi)
		return mi
	_count += 1
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	if not visible and not PERSIST_HIDDEN.has(name_):
		body.set_meta("decal_persist", false)   # an invisible collider: a hole in it would float (T-053)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if mi != null:
		body.add_child(mi)
	parent.add_child(body)
	return body


## Wainscot + chair rail on one face of a wall segment. `face` = the coordinate of that face, `out` = +1/-1
## (direction into the room). Built along X when `along_x`, else along Z.
func _wainscot(along_x: bool, face: float, out: float, a: float, b: float, y0: float, top: float) -> void:
	if b - a < 0.05:
		return
	var h: float = minf(WAINSCOT_H, top - y0)
	if h <= 0.05:
		return
	var f0: float = face
	var f1: float = face + out * 0.03
	if along_x:
		Props.block(dress, Vector3(a, y0, f0), Vector3(b, y0 + h, f1), "wainscot")
		Props.block(dress, Vector3(a, y0, f0), Vector3(b, y0 + 0.14, face + out * 0.045), "beam")
		if h >= WAINSCOT_H - 0.01:
			Props.block(dress, Vector3(a, y0 + h - 0.04, f0), Vector3(b, y0 + h + 0.03, face + out * 0.06), "beam")
	else:
		Props.block(dress, Vector3(f0, y0, a), Vector3(f1, y0 + h, b), "wainscot")
		Props.block(dress, Vector3(f0, y0, a), Vector3(face + out * 0.045, y0 + 0.14, b), "beam")
		if h >= WAINSCOT_H - 0.01:
			Props.block(dress, Vector3(f0, y0 + h - 0.04, a), Vector3(face + out * 0.06, y0 + h + 0.03, b), "beam")


## Wall along X at depth z. openings: [[x_a, x_b, y_a, y_b], ...]. trim: 0 none, +1/-1 wainscot on the
## +Z/-Z face, 2 = both faces. trim_x0/trim_x1 stop the wainscot short of the wall's ends (where the wall runs on
## into a doorway's jamb, T-072).
func wall_x(name_: String, z: float, x0: float, x1: float, y0: float, y1: float, openings: Array, mat_key: String, trim: int = 0,
		trim_x0: float = -1e9, trim_x1: float = 1e9) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = x0
	var i: int = 0
	var spans: Array = []   # [a, b, top] segments touching the floor
	for o: Array in openings:
		var oa: float = float(o[0])
		var ob: float = float(o[1])
		box(geo, "%s_%d" % [name_, i], Vector3(cur, y0, z - T * 0.5), Vector3(oa, y1, z + T * 0.5), mat_key)
		box(geo, "%s_%db" % [name_, i], Vector3(oa, y0, z - T * 0.5), Vector3(ob, float(o[2]), z + T * 0.5), mat_key)
		box(geo, "%s_%dt" % [name_, i], Vector3(oa, float(o[3]), z - T * 0.5), Vector3(ob, y1, z + T * 0.5), mat_key)
		spans.append([cur, oa, y1])
		spans.append([oa, ob, float(o[2])])
		cur = ob
		i += 1
	box(geo, "%s_end" % name_, Vector3(cur, y0, z - T * 0.5), Vector3(x1, y1, z + T * 0.5), mat_key)
	spans.append([cur, x1, y1])
	for s: Array in spans:
		for side: int in [1, -1]:
			if trim == side or trim == 2:
				_wainscot(true, z + side * T * 0.5, float(side), maxf(float(s[0]), trim_x0), minf(float(s[1]), trim_x1), y0, float(s[2]))


## Wall along Z at x. Same conventions as wall_x (trim +1 = the +X face).
func wall_z(name_: String, x: float, z0: float, z1: float, y0: float, y1: float, openings: Array, mat_key: String, trim: int = 0) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = z0
	var i: int = 0
	var spans: Array = []
	for o: Array in openings:
		var oa: float = float(o[0])
		var ob: float = float(o[1])
		box(geo, "%s_%d" % [name_, i], Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, oa), mat_key)
		box(geo, "%s_%db" % [name_, i], Vector3(x - T * 0.5, y0, oa), Vector3(x + T * 0.5, float(o[2]), ob), mat_key)
		box(geo, "%s_%dt" % [name_, i], Vector3(x - T * 0.5, float(o[3]), oa), Vector3(x + T * 0.5, y1, ob), mat_key)
		spans.append([cur, oa, y1])
		spans.append([oa, ob, float(o[2])])
		cur = ob
		i += 1
	box(geo, "%s_end" % name_, Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, z1), mat_key)
	spans.append([cur, z1, y1])
	for s: Array in spans:
		for side: int in [1, -1]:
			if trim == side or trim == 2:
				_wainscot(false, x + side * T * 0.5, float(side), float(s[0]), float(s[1]), y0, float(s[2]))


## A straight ramp (stairs) along Z between two heights. Collision is one slab; treads/risers are dressing.
## hollow_z: steps past it (toward z_high, which must be the smaller z) are drawn as shells over a plaster soffit
## instead of solid blocks, for a flight that passes over another room. east_rail: the plain rail on the +X side.
func ramp_z(name_: String, x0: float, x1: float, z_low: float, z_high: float, y_low: float, y_high: float,
		hollow_z: float = -1e9, east_rail: bool = true) -> void:
	var run: float = absf(z_high - z_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var angle: float = atan2(rise, run)
	var dir: float = sign(z_high - z_low)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	body.collision_layer = 1
	var thick: float = 0.2
	var mid: Vector3 = Vector3((x0 + x1) * 0.5, (y_low + y_high) * 0.5, (z_low + z_high) * 0.5)
	var basis: Basis = Basis(Vector3.RIGHT, -angle * dir)
	var up: Vector3 = basis * Vector3.UP
	body.transform = Transform3D(basis, mid - up * thick * 0.5)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(absf(x1 - x0), thick, length)
	cs.shape = shape
	body.add_child(cs)
	geo.add_child(body)
	_count += 1
	_stair_dressing.append([x0, x1, z_low, z_high, y_low, y_high, hollow_z, east_rail])


var _stair_dressing: Array = []


## Height of the main staircase's tread line at z.
func _stair_y(z: float) -> float:
	return UP_Y * (STAIR_Z0 - z) / (STAIR_Z0 - STAIR_Z1)


## A collider bar from a to b (the rails and curbs of the balustrades): a box body along the segment, drawn in
## `mat_key` unless it is empty. Three thin bars stop the player and cut the navmesh at an edge while shots pass
## between them.
func bar(parent: Node3D, name_: String, a: Vector3, b: Vector3, w: float, h: float, mat_key: String = "") -> void:
	var d: Vector3 = b - a
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (a + b) * 0.5)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(w, h, d.length())
	cs.shape = shape
	body.add_child(cs)
	if mat_key != "":
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = shape.size
		mi.material_override = mat(mat_key)
		body.add_child(mi)
	parent.add_child(body)
	_count += 1


func _own(n: Node, owner_node: Node) -> void:
	for c: Node in n.get_children():
		if c.owner == null:
			c.owner = owner_node
		if c.scene_file_path == "":
			_own(c, owner_node)


# ================================================================== collision shell (navmesh source)

func build_geometry() -> void:
	# ground slab, with a hole over the cellar annex (x 24..36, z 10..31; T&C M2, DECISIONS T-027)
	# and holes over the Old Cellar under the taproom, its stair lean-to and its two light wells (T-051, OC_HOLES)
	_slab_with_holes("Ground", -45.0, 24.0, -40.0, 75.0, OC_HOLES)
	box(geo, "GroundE", Vector3(36, -0.5, -40), Vector3(70, 0.0, 75), "snow")
	_slab_with_holes("GroundN", 24.0, 36.0, -40.0, 10.0, OC_HOLES)
	box(geo, "GroundS", Vector3(24, -0.5, 31), Vector3(36, 0.0, 75), "snow")
	# T-080: the snow east of the cellar's stair hall (x 28..36, z 10..19) was a hole in the slab (nobody walked there);
	# the grounds' ring and the Wreck Loop cross it
	box(geo, "GroundAnnexN", Vector3(28.0, -0.5, 10.0), Vector3(36.0, 0.0, 19.0), "snow")

	# ---------------- TAPROOM (ground floor)
	var win: Array = [WIN_SILL, WIN_TOP]
	wall_x("TapN", 0.0, -T * 0.5, 24 + T * 0.5, 0, TAP_H, [[6.2, 7.8] + win, [16.2, 17.8] + win, [FRONT_DOOR_X - 0.8, FRONT_DOOR_X + 0.8, 0.0, DOOR_H]], "wall", 1)
	# the inn's front door under the porch (T-072): drawn and swinging (InnFrontDoor). Until T-080 its opening was
	# filled with an invisible collider; now it is a bought door (Door_Front, "Out Front", the way onto the GROUNDS):
	# like every BuyDoor it is not baked, so the navmesh runs through the doorway and the door's own collider shuts it
	wall_z("TapW", 0.0, 0, 10, 0, TAP_H, [[5.2, 6.8] + win, [8.25, 9.85, 0.0, DOOR_H]], "wall", 1)   # Door 5: the Old Cellar (T-051)
	wall_z("TapE", 24.0, 0, 16, 0, TAP_H, [[7.2, 8.8] + win, [10.7, 12.3, 0.0, DOOR_H]], "wall", -1)
	wall_x("TapS", 16.0, STAIR_X1, 24 + T * 0.5, 0, TAP_H, [[19.0, 21.0, 0.0, DOOR_H]], "wall", -1, STAIR_X1 + T * 0.5)   # trim clear of Door 1's jamb
	# stairwell (x 0..6, z 10..16), full height: the flight along the west wall (3.5 m wide, z 14.3 -> 9.0, so it
	# lands a metre inside the hall), the vestibule beside it with Door 1 in the east wall, the hall overlooking it
	wall_z("StairW", 0.0, 10, 16 + T * 0.5, 0, UP_TOP, [], "wall", 1)
	wall_x("StairS", 16.0, -T * 0.5, STAIR_X1, 0, UP_TOP, [], "wall", -1, -1e9, STAIR_X1 - T * 0.5)
	wall_z("StairE", STAIR_X1, 10, 16, 0, UP_TOP, [[14.3, 15.9, 0.0, DOOR_H]], "wall", 2)
	wall_x("StairN", 10.0, FLIGHT_X1, STAIR_X1 + T * 0.5, 0, UP_Y, [], "wall", 2)   # under the hall floor: closes the vestibule from the taproom
	wall_x("StairNu", 10.0, -T * 0.5, FLIGHT_X1, 0, _stair_y(10.15) - 0.42, [], "wall", -1)   # under the flight's soffit
	box(geo, "StairRoof", Vector3(-T * 0.5, UP_TOP, 10), Vector3(STAIR_X1 + T * 0.5, UP_TOP + 0.2, 16 + T * 0.5), "roof")
	ramp_z("Stairs", 0.15, FLIGHT_X1, STAIR_Z0, STAIR_Z1, 0.0, UP_Y, 10.0, false)
	# the under-stair is solid (the step blocks draw it): invisible boxes stepped under the soffit line keep the
	# navmesh out of it
	for seg: Array in [[10.15, 11.0], [11.0, 12.0], [12.0, 13.0]]:
		box(geo, "StairUnder", Vector3(0.15, 0, float(seg[0])), Vector3(FLIGHT_X1, _stair_y(float(seg[1])) - 0.42, float(seg[1])), "wall", true, false)
	# balustrades: a curb, a mid rail and a handrail up the flight's open side, round the stair head and along
	# the hall's edge over the well (the balusters are dressing)
	var bx: float = FLIGHT_X1 - 0.05
	var hz: float = 10.0 - 0.05
	for r: Array in [[0.06, 0.06, 0.12], [0.47, 0.035, 0.04], [0.92, 0.07, 0.07]]:   # [centre height, width, height]
		var hy: float = float(r[0])
		bar(geo, "StairRail", Vector3(bx, hy, STAIR_Z0), Vector3(bx, UP_Y + hy, STAIR_Z1), float(r[1]), float(r[2]), "furniture")
		bar(geo, "StairRail", Vector3(bx, UP_Y + hy, STAIR_Z1 - 0.03), Vector3(bx, UP_Y + hy, hz), float(r[1]), float(r[2]), "furniture")
		bar(geo, "HallRail", Vector3(bx - 0.03, UP_Y + hy, hz), Vector3(STAIR_X1 - T * 0.5, UP_Y + hy, hz), float(r[1]), float(r[2]), "furniture")
	# the balustrade for the navmesh bake: the rail bars are thinner than a navmesh cell, so the bake saw the
	# flight's open edge as walkable into the vestibule and zombies wedged on the mid rail at the foot and the
	# head (T-040 playtest). Two hidden panels along the rail lines cut it properly; the flight still meets the
	# landing at its foot and the hall at its head.
	box(geo, "StairRailPanel", Vector3(bx - 0.08, 0.0, STAIR_Z1 - 0.05), Vector3(bx + 0.08, UP_Y + 1.0, STAIR_Z0), "wall", true, false)
	box(geo, "HallRailPanel", Vector3(bx - 0.08, UP_Y, hz - 0.08), Vector3(STAIR_X1 - T * 0.5, UP_Y + 1.0, hz + 0.08), "wall", true, false)
	# ceiling slabs: A = upstairs floor (z 0..10; the flight lands in it west of the vestibule), B = taproom roof
	box(geo, "SlabA", Vector3(-T * 0.5, TAP_H, -T * 0.5), Vector3(FLIGHT_X1, UP_Y, STAIR_Z1), "floor_wood")
	box(geo, "SlabA2", Vector3(FLIGHT_X1, TAP_H, -T * 0.5), Vector3(24 + T * 0.5, UP_Y, 10), "floor_wood")
	box(geo, "SlabB", Vector3(STAIR_X1, TAP_H, 10), Vector3(24 + T * 0.5, UP_Y, 16 + T * 0.5), "floor_wood")
	# fireplace + chimney (north wall): collision only, drawn by the dressing pass
	box(geo, "Hearth", Vector3(10.9, 0, 0.15), Vector3(13.1, 1.5, 0.95), "stone", true, false)
	box(geo, "Chimney", Vector3(11.2, 1.5, 0.15), Vector3(12.8, TAP_H, 0.6), "stone")
	# bar (counter front + side) and back shelf: collision only
	box(geo, "BarFront", Vector3(5.0, 0, 8.0), Vector3(9.0, 1.1, 8.8), "furniture", true, false)
	box(geo, "BarSide", Vector3(8.2, 0, 3.0), Vector3(9.0, 1.1, 8.0), "furniture", true, false)
	box(geo, "BackShelf", Vector3(4.6, 0, 3.0), Vector3(5.0, 2.0, 8.0), "furniture", true, false).set_meta("shot_through", true)   # open shelving: shots reach the bottles (T-053)
	for p: Vector2 in [Vector2(12.5, 11.5), Vector2(16.5, 11.5), Vector2(20.0, 4.5)]:
		box(geo, "Table", Vector3(p.x - 0.6, 0, p.y - 0.6), Vector3(p.x + 0.6, 0.75, p.y + 0.6), "furniture", true, false)
	for t: Array in TAP_TABLES_NEW:   # the busier taproom (T-072)
		var c: Vector2 = t[0]
		var hs: Vector2 = Vector2(float(t[1]), float(t[2])) * 0.5
		box(geo, "Table", Vector3(c.x - hs.x, 0, c.y - hs.y), Vector3(c.x + hs.x, 0.75, c.y + hs.y), "furniture", true, false)

	# ---------------- UPSTAIRS (y 3.8 .. 6.8, z 0..10)
	var up_win: Array = [UP_Y + WIN_SILL, UP_Y + WIN_TOP]
	wall_x("UpN", 0.0, -T * 0.5, 24 + T * 0.5, UP_Y, UP_TOP, [[3.2, 4.8] + up_win, [19.2, 20.8] + up_win], "wall_upper", 1)
	wall_z("UpW", 0.0, 0, 10, UP_Y, UP_TOP, [], "wall_upper", 1)
	wall_z("UpE", 24.0, 0, 10, UP_Y, UP_TOP, [], "wall_upper", -1)
	wall_x("UpS", 10.0, STAIR_X1 - T * 0.5, 24 + T * 0.5, UP_Y, UP_TOP, [], "wall_upper", -1)
	var room_door: Array = [UP_Y, UP_Y + 2.2]
	wall_x("UpHall", 6.0, 0, 24, UP_Y, UP_TOP, [[5.0, 6.5] + room_door, [11.0, 12.5] + room_door, [19.5, 21.0] + room_door], "wall_upper", 2)
	wall_z("UpRoom12", 8.0, 0, 6, UP_Y, UP_TOP, [], "wall_upper", 2)
	wall_z("UpRoom23", 16.0, 0, 6, UP_Y, UP_TOP, [], "wall_upper", 2)
	box(geo, "UpRoof", Vector3(-T * 0.5, UP_TOP, -T * 0.5), Vector3(24 + T * 0.5, UP_TOP + 0.2, 10 + T * 0.5), "floor_wood")
	box(geo, "Bed1", Vector3(0.3, UP_Y, 0.4), Vector3(2.2, UP_Y + 0.5, 2.6), "furniture", true, false)
	box(geo, "Bed2", Vector3(13.6, UP_Y, 0.4), Vector3(15.6, UP_Y + 0.5, 2.6), "furniture", true, false)
	box(geo, "Bed3", Vector3(21.6, UP_Y, 3.2), Vector3(23.7, UP_Y + 0.5, 5.6), "furniture", true, false)
	box(geo, "TechTrunk", Vector3(10.4, UP_Y, 0.5), Vector3(11.6, UP_Y + 0.5, 1.2), "furniture", true, false)
	# porch-roof ledges outside the upstairs windows (zombies climb onto these)
	box(geo, "LedgeW", Vector3(1.5, TAP_H, -2.4), Vector3(6.5, UP_Y, -T * 0.5), "roof")
	box(geo, "LedgeE", Vector3(17.5, TAP_H, -2.4), Vector3(22.5, UP_Y, -T * 0.5), "roof")
	for x: float in [1.7, 6.3, 17.7, 22.3]:
		box(geo, "LedgePost", Vector3(x - 0.1, 0, -2.3), Vector3(x + 0.1, TAP_H, -2.1), "beam")

	# ---------------- YARD PASSAGE (x 18..22, z 16..22)
	wall_z("PassW", 18.0, 16, 22, 0, 3.0, [], "stable")
	wall_z("PassE", 22.0, 16, 22, 0, 3.0, [], "stable")
	box(geo, "PassRoof", Vector3(18 - T * 0.5, 3.0, 16), Vector3(22 + T * 0.5, 3.2, 22), "roof")

	# ---------------- STABLE (x STB_X0..STB_X1, z 22..34, ceiling 7; T-084: 21 x 12 m, the loft and its stair rebuilt)
	wall_x("StbN", STB_Z0, STB_X0 - T * 0.5, STB_X1 + T * 0.5, 0, STABLE_H, [[8.2, 9.8] + win, [13.2, 14.8] + win, [18.5, 21.5, 0.0, 2.6]], "stable")
	# the great doors' opening is drawn (the doors themselves are dressing, so the exfil cutscene can drop them)
	# but filled with an invisible collider: the navmesh and collision stay a solid wall, nobody walks out. 3 m high
	# since T-084 (the hayloft's gallery runs over them); the loft door above them is a barricaded window (W_STB_LOFT)
	var loft_win: Array = [LOFT_TOP + WIN_SILL, LOFT_TOP + WIN_TOP]
	wall_x("StbS", STB_Z1, STB_X0 - T * 0.5, STB_X1 + T * 0.5, 0, STABLE_H, [[7.0, 9.0, 0.0, DOOR_H], [11.2, 12.8] + win, [16.0, 20.0, 0.0, GREAT_DOOR_H],
		[21.2, 22.8] + loft_win], "stable")
	box(geo, "GreatDoorsBlock", Vector3(16.0, 0, STB_Z1 - T * 0.5), Vector3(20.0, GREAT_DOOR_H, STB_Z1 + T * 0.5), "stable", true, false)
	wall_z("StbW", STB_X0, STB_Z0, STB_Z1, 0, STABLE_H, [], "stable")
	wall_z("StbE", STB_X1, STB_Z0, STB_Z1, 0, STABLE_H, [], "stable")
	box(geo, "StbRoof", Vector3(STB_X0 - T * 0.5, STABLE_H, STB_Z0 - T * 0.5), Vector3(STB_X1 + T * 0.5, STABLE_H + 0.2, STB_Z1 + T * 0.5), "planks")
	for x: float in [11.0, 16.0, 17.6]:
		box(geo, "Stall", Vector3(x - 0.08, 0, 22.2), Vector3(x + 0.08, 1.3, 25.2), "planks")
	build_hayloft()

	build_yard()
	build_cellar()
	build_nav_blocks()

	# ---------------- crash site (east field): GRAVELIGHT ONE (collision for the hull only)
	var wreck: Node3D = Node3D.new()
	wreck.name = "Wreck"
	wreck.position = Vector3(46, 0, 6)
	wreck.rotation = Vector3(0, deg_to_rad(28), deg_to_rad(-8))
	geo.add_child(wreck)
	# T-080: the crash site is in the play space now (the GROUNDS): cover, never a perch (no_mantle), the engine
	# nacelles that hang out ahead of the wing are solid too, and the wing reaches the snow (no crawl space under it)
	# (the hull is rolled 8 deg: the port wing tip stands 1.25 m off the snow, so the boxes reach down into the ground)
	box(wreck, "Fuselage", Vector3(-1.4, -0.4, -7), Vector3(1.4, 2.6, 6), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "Wing", Vector3(-9, -1.4, -1.5), Vector3(7, 0.7, 1.5), "wreck", true, false).set_meta("no_mantle", true)
	for sx: float in [-3.2, 3.2]:
		box(wreck, "Nacelle", Vector3(sx - 0.65, -0.6, -2.35), Vector3(sx + 0.65, 1.55, -1.5), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "TailPlane", Vector3(-2.5, 1.5, 5.3), Vector3(2.5, 1.85, 6.7), "wreck", true, false).set_meta("no_mantle", true)
	build_grounds()


## The hayloft (T-084): the west block, the gallery along the south wall with the stair well in its east end, the
## straight flight up the east wall (a smooth invisible ramp on the nosing line, so the capsule never catches a
## tread; the treads are dressing), the boarded store under it, the rails round every open edge (three collider
## bars, shots pass between them; hidden panels cut the navmesh at the edges for the bake only), the bale drop (a
## bay in the gallery's rail you can walk off; zombies don't path it), the bales and crates that are cover, and
## the hoist ledge outside the loft door over the yard that the loft window's zombies stand on.
func build_hayloft() -> void:
	box(geo, "Hayloft", Vector3(STB_X0, LOFT_Y, STB_Z0), Vector3(LOFT_X1, LOFT_TOP, STB_Z1), "floor_wood")
	box(geo, "HayGallery", Vector3(LOFT_X1, LOFT_Y, GAL_Z0), Vector3(HSTAIR_X0, LOFT_TOP, STB_Z1), "floor_wood")
	box(geo, "HayLanding", Vector3(HSTAIR_X0, LOFT_Y, HSTAIR_Z1), Vector3(STB_X1, LOFT_TOP, STB_Z1), "floor_wood")
	# the flight: the collider runs on the nosing line from the floor one tread before the first riser to the landing
	ramp_z("HayStairs", HSTAIR_X0, HSTAIR_X1, HSTAIR_Z0, HSTAIR_Z1, 0.0, LOFT_TOP, -1e9, false)
	_stair_dressing.pop_back()   # drawn by _dress_hay_stairs, not the generic sawtooth
	# the boarded store under the flight: solid up to the soffit, so nothing walks or paths under it
	var run: float = HSTAIR_Z1 - HSTAIR_Z0
	var zc: float = HSTAIR_Z0 + 0.5
	while zc < HSTAIR_Z1 - 0.01:
		var zn: float = minf(zc + 0.5, HSTAIR_Z1)
		var soffit: float = LOFT_TOP * (zc - HSTAIR_Z0) / run - 0.32
		if soffit > 0.05:
			box(geo, "HayStairUnder", Vector3(HSTAIR_X0, 0, zc), Vector3(HSTAIR_X1, soffit, zn), "stable", true, false)
		zc = zn
	# rails: [from, to] along the loft's open edges at floor level (the bars sit on top of the slab); the flight's
	# own rail climbs with it. The bale drop is left open.
	var rails: Array = [
		[Vector3(LOFT_X1 - 0.05, LOFT_TOP, STB_Z0 + T * 0.5), Vector3(LOFT_X1 - 0.05, LOFT_TOP, GAL_Z0 - 0.05)],
		[Vector3(LOFT_X1 - 0.05, LOFT_TOP, GAL_Z0 + 0.05), Vector3(LOFT_DROP.x, LOFT_TOP, GAL_Z0 + 0.05)],
		[Vector3(LOFT_DROP.y, LOFT_TOP, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, GAL_Z0 + 0.05)],
		[Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, HSTAIR_Z1)],
		[Vector3(HSTAIR_X0 - 0.05, 0.0, HSTAIR_Z0), Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, HSTAIR_Z1)],
	]
	for r: Array in rails:
		for b: Array in [[0.06, 0.06, 0.12], [0.5, 0.035, 0.04], [1.0, 0.07, 0.07]]:   # [centre height, width, height]
			var hy: float = float(b[0])
			bar(geo, "LoftRail", (r[0] as Vector3) + Vector3(0, hy, 0), (r[1] as Vector3) + Vector3(0, hy, 0), float(b[1]), float(b[2]), "furniture")
	# the bake's view of the rails: hidden panels (freed after the bake) along the edges, the drop included, and
	# stepped along the flight's open side so the bake never joins the ramp to the floor beside it
	var panels: Array = [
		[Vector3(LOFT_X1 - 0.13, LOFT_TOP, STB_Z0), Vector3(LOFT_X1 + 0.03, LOFT_TOP + 1.2, GAL_Z0 + 0.08)],
		[Vector3(LOFT_X1 - 0.13, LOFT_TOP, GAL_Z0 - 0.08), Vector3(HSTAIR_X0 + 0.03, LOFT_TOP + 1.2, GAL_Z0 + 0.08)],
		[Vector3(HSTAIR_X0 - 0.13, LOFT_TOP, GAL_Z0 - 0.08), Vector3(HSTAIR_X0 + 0.03, LOFT_TOP + 1.2, HSTAIR_Z1 + 0.08)],
	]
	var zp: float = HSTAIR_Z0 - 0.4
	while zp < HSTAIR_Z1:
		var zq: float = minf(zp + 0.5, HSTAIR_Z1)
		var top: float = LOFT_TOP * (zq - HSTAIR_Z0) / run + 1.2
		panels.append([Vector3(HSTAIR_X0 - 0.13, 0.0, zp), Vector3(HSTAIR_X0 + 0.03, top, zq)])
		zp = zq
	for pn: Array in panels:
		var p: Node3D = box(geo, "LoftRailBake", pn[0], pn[1], "wall", true, false)
		if p != null:
			_bake_only.append(p)
	# cover up there: the bale stack in the south-west corner (PERSIST_HIDDEN: shots pit it), single bales along the
	# gallery's rail to crouch behind, two crates (one the carter's salt-lamp crate, MAPS.md)
	box(geo, "HayBales", Vector3(STB_X0 + 0.3, LOFT_TOP, 30.5), Vector3(STB_X0 + 3.5, LOFT_TOP + 0.9, 33.7), "hay", true, false)
	for hb: Array in LOFT_BALES:
		var c: Vector3 = hb[0]
		var yaw: float = float(hb[1])
		var hw: Vector3 = Vector3(0.5, 0, 0.3) if absf(fmod(yaw, 180.0)) < 45.0 else Vector3(0.3, 0, 0.5)
		box(geo, "LoftBale", c - hw, c + hw + Vector3(0, 0.47, 0), "hay", true, false).set_meta("decal_persist", true)
	for cr: Array in LOFT_CRATES:
		var cc: Vector3 = cr[0]
		var s: float = float(cr[1]) * 0.5
		box(geo, "LoftCrate", cc - Vector3(s, 0, s), cc + Vector3(s, 2.0 * s, s), "planks", true, false).set_meta("decal_persist", true)
	# the hoist ledge outside the loft door (the loft window's zombies stand on it, like the porch-roof ledges)
	box(geo, "LoftLedge", Vector3(20.0, LOFT_Y, STB_Z1 + T * 0.5), Vector3(25.2, LOFT_TOP, 36.6), "planks")


## Single bales on the loft that are cover (and drawn by _dress_stable): [floor position (y LOFT_TOP), yaw].
const LOFT_BALES: Array = [[Vector3(17.2, LOFT_TOP, 29.95), 0.0], [Vector3(18.1, LOFT_TOP, 29.95), 0.0], [Vector3(21.6, LOFT_TOP, 30.0), 0.0],
	[Vector3(LOFT_X1 - 0.65, LOFT_TOP, 24.4), 90.0], [Vector3(LOFT_X1 - 0.65, LOFT_TOP, 25.5), 90.0], [Vector3(LOFT_X1 - 1.1, LOFT_TOP, 27.4), 90.0]]
## Crates on the loft: [floor position, size, yaw, stencil] (the salt-lamp crate over the great doors, MAPS.md).
const LOFT_CRATES: Array = [[Vector3(16.9, LOFT_TOP, 33.1), 0.9, 12.0, "SALZ"], [Vector3(6.2, LOFT_TOP, 23.0), 0.75, -8.0, ""]]


## THE CARTERS' YARD (zone YARD, "go outside"): the fenced forecourt south of the stable, x 2..34, z 34..48, out of
## the stable's new south door (Door 4, 1250). Fences are invisible 2.3 m colliders (the player can jump; the
## drawn fence is 1.2 m) with four barricaded gaps zombies vault, a barred gate on the carters' road, the well,
## a woodpile and a snowed cart to run round. The field beyond stays navmesh for the window zombies.
func build_yard() -> void:
	var fh: float = 2.3
	var win: Array = [WIN_SILL, WIN_TOP]
	# west fence (x 2) with a gap at z 40.2..41.8; east fence (x 34) with a gap at z 40.2..41.8
	for fx: float in [2.0, 34.0]:
		box(geo, "YardFence", Vector3(fx - 0.1, 0, 34.0), Vector3(fx + 0.1, fh, 40.2), "snow", true, false)
		box(geo, "YardFence", Vector3(fx - 0.1, 0, 41.8), Vector3(fx + 0.1, fh, 48.1), "snow", true, false)
		box(geo, "YardSill", Vector3(fx - 0.1, 0, 40.2), Vector3(fx + 0.1, WIN_SILL, 41.8), "snow", true, false)
		box(geo, "YardTop", Vector3(fx - 0.1, WIN_TOP, 40.2), Vector3(fx + 0.1, fh, 41.8), "snow", true, false)
	# south fence (z 48) with gaps at x 8.2..9.8 and 26.2..27.8, and the barred gate at x 16..20
	for seg: Array in [[2.0, 8.2], [9.8, 16.0], [20.0, 26.2], [27.8, 34.0]]:
		box(geo, "YardFence", Vector3(float(seg[0]), 0, 47.9), Vector3(float(seg[1]), fh, 48.1), "snow", true, false)
	for gx: float in [8.2, 26.2]:
		box(geo, "YardSill", Vector3(gx, 0, 47.9), Vector3(gx + 1.6, WIN_SILL, 48.1), "snow", true, false)
		box(geo, "YardTop", Vector3(gx, WIN_TOP, 47.9), Vector3(gx + 1.6, fh, 48.1), "snow", true, false)
	# (the barred gate at x 16..20 is a bought door since T-080, Door_Gate: not baked, its own collider shuts it)
	# the plot's north edges beside the stable (keeps the yard off the cellar's roof and the inn's east side)
	box(geo, "YardFence", Vector3(STB_X1, 0, 33.9), Vector3(34.1, fh, 34.1), "snow", true, false)
	box(geo, "YardFence", Vector3(1.9, 0, 33.9), Vector3(STB_X0, fh, 34.1), "snow", true, false)
	# the well, the woodpile against the stable, the snowed cart
	box(geo, "Well", Vector3(9.0, 0, 41.0), Vector3(11.0, 1.0, 43.0), "stone", true, false)
	box(geo, "Woodpile", Vector3(13.3, 0, 34.15), Vector3(15.9, 1.3, 35.4), "furniture", true, false)   # east of the window W_STB_S (x 11.2..12.8), which the zombies need clear (T-040)
	box(geo, "YardCart", Vector3(27.0, 0, 37.0), Vector3(29.6, 1.1, 39.2), "furniture", true, false)
	box(geo, "YardTrough", Vector3(30.5, 0, 44.0), Vector3(33.5, 0.7, 45.0), "furniture", true, false)


## THE GROUNDS (T-080; the user: "the outside area on the first map needs some work, make it bigger and make it so
## you can go around the whole building"). The snow round the inn is play space now, zone GROUNDS: out of the front
## door (Door_Front, "Out Front", 1250) or the yard's gate (Door_Gate, 750, from the yard or the road), a walkable
## ring right round the inn, the stable and the yard, the crossroads in front, the west road, the carters' road
## behind and the crash field to the east with GRAVELIGHT ONE as cover. A hard edge all round (OUT_MIN..OUT_MAX): a
## 6 m invisible wall on the line of the boundary fences and the tree line, closing the four road exits too.
const OUT_MIN: Vector2 = Vector2(-20.0, -30.0)
const OUT_MAX: Vector2 = Vector2(60.0, 64.0)
## Fences with 2.3 m colliders like the yard's (the drawn rails are 1.2 m): [from (x, z), to (x, z)], axis-aligned.
## The roadside fence north of the crossroads road has gaps at the north road, a field gate (x 8..11.5) and a fallen
## bay (x 19..22), where the round 1 opening's two escapers run through (map00_opening.json); open past x 30.
const OUT_FENCES: Array = [
	[Vector2(-20, -13), Vector2(-13.5, -13)], [Vector2(-6.5, -13), Vector2(8, -13)], [Vector2(11.5, -13), Vector2(19, -13)], [Vector2(22, -13), Vector2(30, -13)],
	[Vector2(-20, -30), Vector2(-20, -10.2)], [Vector2(-20, -5.3), Vector2(-20, 64)],
	[Vector2(60, -30), Vector2(60, -10.2)], [Vector2(60, -5.3), Vector2(60, 64)],
	[Vector2(-20, 64), Vector2(-13.2, 64)], [Vector2(-8.3, 64), Vector2(33, 64)], [Vector2(41, 64), Vector2(60, 64)],
	[Vector2(-20, -30), Vector2(-13.2, -30)], [Vector2(-8.3, -30), Vector2(60, -30)],
]
## Dead trees on the map (drawn by _dress_exterior / _dress_carters_road with these seeds); the ones inside the edge
## get a trunk collider. [position, seed, height]
const OUT_DEAD_TREES: Array = [
	[Vector3(-16, 0, -22), 100, 6.0], [Vector3(-26, 0, 8), 101, 8.0], [Vector3(-15, 0, 30), 102, 10.0], [Vector3(30, 0, -20), 103, 6.0],
	[Vector3(55, 0, 30), 104, 8.0], [Vector3(5, 0, 48), 105, 10.0], [Vector3(-30, 0, -30), 106, 6.0], [Vector3(40, 0, -25), 107, 8.0],
	[Vector3(-24, 0, 50), 108, 10.0], [Vector3(60, 0, -10), 109, 6.0],
	[Vector3(31, 0, 52), 131, 7.0], [Vector3(12, 0, 55), 132, 8.5], [Vector3(38, 0, 52), 133, 6.5], [Vector3(22, 0, 66), 134, 9.0], [Vector3(52, 0, 60), 135, 7.5],
	# T-080: a few more in the bigger field
	[Vector3(-3, 0, -24), 140, 7.5], [Vector3(47, 0, -16), 141, 6.5], [Vector3(-14, 0, 47), 142, 8.0], [Vector3(50, 0, 50), 143, 7.0],
]
## Solid things out on the grounds (cover; nobody stands on them: no_mantle): [name, centre on the snow, size, yaw].
## Drawn by _dress_grounds.
const OUT_SOLIDS: Array = [
	["Woodshed", Vector3(-4.5, 0, 58.5), Vector3(5.0, 2.6, 3.5), 0.0],
	["HayRick", Vector3(22.0, 0, -23.5), Vector3(3.4, 2.8, 3.4), 0.0],
	["Shrine", Vector3(-15.4, 0, -11.4), Vector3(0.5, 2.4, 0.5), 0.0],
	["HayWagon", Vector3(-15.6, 0, 22.0), Vector3(1.9, 1.1, 3.0), 8.0],
	["RoadCart", Vector3(-17.0, 0, -3.0), Vector3(1.9, 1.1, 3.0), 20.0],
	["SandbagsW", Vector3(32.25, 0, -22.0), Vector3(4.5, 0.9, 0.7), 0.0],
	["SandbagsN", Vector3(34.5, 0, -20.25), Vector3(0.7, 0.9, 3.5), 0.0],
	["Engine", Vector3(34.5, 0, -13.2), Vector3(1.3, 1.2, 2.4), 30.0],
	["WingPanel", Vector3(56.0, 0, 25.0), Vector3(5.0, 1.4, 0.45), 70.0],
	["BurntCar", Vector3(49.0, 0, -14.5), Vector3(1.8, 1.5, 4.2), 100.0],
	["Drums", Vector3(47.0, 0, 44.0), Vector3(1.4, 0.95, 1.4), 0.0],
	# the road exits: a felled spruce across the north road, sawhorse barriers on the east road, the carters' road
	# and the west road south; a barrier boom on the crossroads road west (all just inside the edge)
	["FelledSpruce", Vector3(-10.75, 0, -29.0), Vector3(6.5, 0.8, 0.7), 4.0],
	["BarrierE", Vector3(59.0, 0, -7.75), Vector3(0.5, 1.0, 4.4), 0.0],
	["BarrierS", Vector3(37.0, 0, 63.0), Vector3(5.0, 1.0, 0.5), 0.0],
	["BarrierSW", Vector3(-10.75, 0, 63.0), Vector3(4.4, 1.0, 0.5), 0.0],
	["BarrierW", Vector3(-19.2, 0, -7.75), Vector3(0.5, 1.1, 4.6), 0.0],
]
## Posts that stand in the field: the telephone poles along the crossroads road, the two signposts, the parachute's
## tree, the two lamp posts. [position, half width]
const OUT_POSTS: Array = [
	[Vector3(-16, 0, -15.5), 0.16], [Vector3(-2, 0, -15.5), 0.16], [Vector3(12, 0, -15.5), 0.16], [Vector3(26, 0, -15.5), 0.16], [Vector3(40, 0, -15.5), 0.16],
	[Vector3(-8.2, 0, -10.6), 0.12], [Vector3(22.9, 0, 49.6), 0.12], [Vector3(39.5, 0, 24.5), 0.25],
	[Vector3(-7.6, 0, -4.6), 0.12], [Vector3(37.0, 0, -10.8), 0.12],
]
## Where the zombies come out of the dark at the edge (kind "edge": they walk in and chase; only while somebody is
## out on the grounds, never in sight of a player out there) and rise from the snow (kind "ground", round 4+).
## T-084: the edge spawns stand 4.5 m BEYOND the edge wall, in the tree line (a pocket of navmesh POCKET_W wide
## reaches POCKET_D m out through a gap in the baked wall and fences; the gap is filled by a collider on the edge
## layer that only bodies see, so the zombies walk in out of the trees and nobody walks out).
const OUT_EDGE_SPAWNS: Array = [
	Vector3(-15, 0, -34.5), Vector3(5, 0, -34.5), Vector3(25, 0, -34.5), Vector3(47, 0, -34.5),
	Vector3(64.5, 0, -1.0), Vector3(64.5, 0, 22.0), Vector3(64.5, 0, 46.0),
	Vector3(45, 0, 68.5), Vector3(24, 0, 68.5), Vector3(2, 0, 68.5),
	Vector3(-24.5, 0, 44.0), Vector3(-24.5, 0, 16.0), Vector3(-24.5, 0, -20.0),
]
const POCKET_W: float = 3.0
const POCKET_D: float = 7.0
const OUT_GROUND_SPAWNS: Array = [Vector3(16.5, 0, -19.0), Vector3(-14.0, 0, 36.0), Vector3(45.0, 0, 30.0), Vector3(27.0, 0, 57.0)]
## Zone GROUNDS (roam): boxes tiling the snow inside the edge round the inn, the stable, the stair hall and the yard
## [min (x, z), max (x, z)], y -0.5..3 (the porch roofs' ledges stay out); and the two light wells' pits, lower.
const OUT_ZONE_RECTS: Array = [
	[Vector2(-20, -30), Vector2(60, -0.15)], [Vector2(-20, -0.15), Vector2(-3.15, 64)], [Vector2(-3.15, -0.15), Vector2(-0.15, 7.85)],
	[Vector2(-3.15, 18.65), Vector2(STB_X0 - 0.15, 34)], [Vector2(-3.15, 34), Vector2(2, 64)], [Vector2(0, 16.15), Vector2(18, 22)],
	[Vector2(22, 16.15), Vector2(24.15, 22)], [Vector2(24.15, -0.15), Vector2(60, 9.85)], [Vector2(28.15, 9.85), Vector2(60, 34)],
	[Vector2(24.15, 19), Vector2(28.15, 22)], [Vector2(STB_X1 + 0.15, 22), Vector2(28.15, 34)], [Vector2(34, 34), Vector2(60, 64)], [Vector2(2, 48), Vector2(34, 64)],
]
const OUT_WELL_RECTS: Array = [[Vector2(1.85, -4.65), Vector2(5.05, -0.15)], [Vector2(24.0, -2.1), Vector2(26.35, 3.35)]]


## Which side of the edge an edge spawn is beyond: 0 north (z < OUT_MIN.y), 1 south, 2 west, 3 east.
static func _pocket_side(p: Vector3) -> int:
	if p.z < OUT_MIN.y:
		return 0
	if p.z > OUT_MAX.y:
		return 1
	return 2 if p.x < OUT_MIN.x else 3


## The spawn pockets beyond the edge (T-084), as rects on the snow (x, z): from the edge line POCKET_D m out, POCKET_W
## wide, one per edge spawn.
static func edge_pockets() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p: Vector3 in OUT_EDGE_SPAWNS:
		match _pocket_side(p):
			0: out.append(Rect2(p.x - POCKET_W * 0.5, OUT_MIN.y - POCKET_D, POCKET_W, POCKET_D))
			1: out.append(Rect2(p.x - POCKET_W * 0.5, OUT_MAX.y, POCKET_W, POCKET_D))
			2: out.append(Rect2(OUT_MIN.x - POCKET_D, p.z - POCKET_W * 0.5, POCKET_D, POCKET_W))
			3: out.append(Rect2(OUT_MAX.x, p.z - POCKET_W * 0.5, POCKET_D, POCKET_W))
	return out


## True when the segment a..b lies on the edge line (an edge fence; the roadside fence at z -13 is not one).
static func _on_edge(a: Vector2, b: Vector2) -> bool:
	return (a.x == b.x and (a.x == OUT_MIN.x or a.x == OUT_MAX.x)) or (a.y == b.y and (a.y == OUT_MIN.y or a.y == OUT_MAX.y))


## `segments` ([a, b] axis-aligned, 2D) with the spans across the spawn pockets cut out of those on the edge line.
static func _cut_pockets(segments: Array) -> Array:
	var out: Array = []
	var pockets: Array[Rect2] = edge_pockets()
	for s: Array in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		if not _on_edge(a, b):
			out.append([a, b])
			continue
		var along_x: bool = a.y == b.y
		var cuts: Array = []
		for r: Rect2 in pockets:
			if along_x:
				if a.y <= r.end.y + 0.01 and a.y >= r.position.y - 0.01:
					cuts.append([r.position.x, r.end.x])
			elif a.x <= r.end.x + 0.01 and a.x >= r.position.x - 0.01:
				cuts.append([r.position.y, r.end.y])
		var lo: float = minf(a.x, b.x) if along_x else minf(a.y, b.y)
		var hi: float = maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var cur: float = lo
		for c: Array in cuts:
			var c0: float = float(c[0])
			var c1: float = float(c[1])
			if c1 <= lo or c0 >= hi:
				continue
			if c0 > cur + 0.05:
				out.append([Vector2(cur, a.y) if along_x else Vector2(a.x, cur), Vector2(c0, a.y) if along_x else Vector2(a.x, c0)])
			cur = maxf(cur, c1)
		if hi > cur + 0.05:
			out.append([Vector2(cur, a.y) if along_x else Vector2(a.x, cur), Vector2(hi, a.y) if along_x else Vector2(a.x, hi)])
	return out


## The grounds' collision (navmesh source): the edge wall, the fences, tree trunks, posts and the solid props.
## T-084: the edge wall and the fences on the edge line are on EDGE_LAYER (bodies collide, shots pass) and are
## cut at the spawn pockets; the cuts are filled by colliders on the same layer kept OUT of the navigation region
## (EdgeGates under the map root), so the bake joins each pocket to the field while players stay inside. Beyond the
## edge everything but the pockets is carved out of the bake (NavigationObstacle3Ds that only live for the bake).
func build_grounds() -> void:
	var lo: Vector2 = OUT_MIN
	var hi: Vector2 = OUT_MAX
	var gates: Node3D = Node3D.new()
	gates.name = "EdgeGates"
	map_root.add_child(gates)
	var walls: Array = [[Vector2(lo.x - 0.4, lo.y), Vector2(hi.x + 0.4, lo.y)], [Vector2(lo.x - 0.4, hi.y), Vector2(hi.x + 0.4, hi.y)],
		[Vector2(lo.x, lo.y), Vector2(lo.x, hi.y)], [Vector2(hi.x, lo.y), Vector2(hi.x, hi.y)]]
	for w: Array in _cut_pockets(walls):
		_edge_box(geo, "GroundsEdge", w[0], w[1], 6.0)
	for r: Rect2 in edge_pockets():   # the gap fillers: the wall's own run across each pocket, not baked
		var side: int = _pocket_side(Vector3(r.get_center().x, 0, r.get_center().y))
		var a: Vector2 = Vector2(r.position.x, lo.y if side == 0 else hi.y) if side < 2 else Vector2(lo.x if side == 2 else hi.x, r.position.y)
		var b: Vector2 = Vector2(r.end.x, a.y) if side < 2 else Vector2(a.x, r.end.y)
		_edge_box(gates, "EdgeGate", a, b, 6.0)
	for f: Array in _cut_pockets(OUT_FENCES):
		var a2: Vector2 = f[0]
		var b2: Vector2 = f[1]
		if _on_edge(a2, b2):
			_edge_box(geo, "GroundsFence", a2, b2, 2.3)
		else:
			box(geo, "GroundsFence", Vector3(minf(a2.x, b2.x) - 0.1, 0, minf(a2.y, b2.y) - 0.1), Vector3(maxf(a2.x, b2.x) + 0.1, 2.3, maxf(a2.y, b2.y) + 0.1), "snow", true, false)
	_carve_beyond_edge()
	for t: Array in OUT_DEAD_TREES:
		var tp: Vector3 = t[0]
		if _in_grounds(tp, -0.5):
			box(geo, "TreeTrunk", tp + Vector3(-0.26, 0, -0.26), tp + Vector3(0.26, NAV_SOLID_H, 0.26), "beam", true, false).set_meta("no_mantle", true)
	for pt: Array in OUT_POSTS:
		var pp: Vector3 = pt[0]
		var hw: float = float(pt[1])
		box(geo, "Post", pp + Vector3(-hw, 0, -hw), pp + Vector3(hw, NAV_SOLID_H, hw), "beam", true, false).set_meta("no_mantle", true)
	for sd: Array in OUT_SOLIDS:
		_solid(str(sd[0]), sd[1], sd[2], float(sd[3]))
	# the crash site's cargo, thrown out of the hold (Landscape scattered_cargo, seed 77, round (37, 15)): the same
	# draws, so each crate's collider sits under its drawing
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var cc: Vector3 = Landscape.WRECK_POS + Vector3(-9.0, 0, 9.0)
	for i: int in 7:
		var cp: Vector3 = cc + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-5, 6))
		var csz: float = rng.randf_range(0.45, 0.8)
		var cyaw: float = rng.randf_range(0, 360)
		rng.randf()
		_solid("CargoCrate", cp, Vector3(csz, csz, csz), cyaw)


## An invisible collider along the edge line a..b (2D), `h` high, on the edge layer (T-084): 0.4 m thick outward of
## the line for the wall, 0.2 m centred for the fences. Bodies collide with it; shots and rays don't; the bake reads it.
func _edge_box(parent: Node3D, name_: String, a: Vector2, b: Vector2, h: float) -> void:
	var fence: bool = h < 3.0
	var x0: float = minf(a.x, b.x)
	var x1: float = maxf(a.x, b.x)
	var z0: float = minf(a.y, b.y)
	var z1: float = maxf(a.y, b.y)
	if a.y == b.y:   # along x
		var out: float = -1.0 if a.y <= OUT_MIN.y + 0.01 else 1.0
		z0 = a.y + (minf(0.0, out * 0.4) if not fence else -0.1)
		z1 = a.y + (maxf(0.0, out * 0.4) if not fence else 0.1)
		x0 -= 0.1
		x1 += 0.1
	else:
		var out2: float = -1.0 if a.x <= OUT_MIN.x + 0.01 else 1.0
		x0 = a.x + (minf(0.0, out2 * 0.4) if not fence else -0.1)
		x1 = a.x + (maxf(0.0, out2 * 0.4) if not fence else 0.1)
	var bd: Node3D = box(parent, name_, Vector3(x0, -0.5 if not fence else 0.0, z0), Vector3(x1, h, z1), "snow", true, false)
	if bd == null:
		return
	bd.set_meta("no_mantle", true)
	(bd as StaticBody3D).collision_layer = EDGE_LAYER


## Bake-only obstructions (T-084) over the snow beyond the edge, leaving only the spawn pockets: the navmesh outside
## the wall is the pockets and nothing else, so a zombie never walks the far side of the trees.
func _carve_beyond_edge() -> void:
	var far: float = 40.0
	var lo: Vector2 = OUT_MIN - Vector2(0.4, 0.4)
	var hi: Vector2 = OUT_MAX + Vector2(0.4, 0.4)
	var rects: Array[Rect2] = []
	var pockets: Array[Rect2] = edge_pockets()
	# four strips round the outside, each split at its pockets; past a pocket's far end the strip carries on
	for side: int in 4:
		var strip: Rect2
		match side:
			0: strip = Rect2(lo.x - far, lo.y - far, hi.x - lo.x + 2.0 * far, far)
			1: strip = Rect2(lo.x - far, hi.y, hi.x - lo.x + 2.0 * far, far)
			2: strip = Rect2(lo.x - far, lo.y, far, hi.y - lo.y)
			_: strip = Rect2(hi.x, lo.y, far, hi.y - lo.y)
		var along_x: bool = side < 2
		var cuts: Array = []
		for r: Rect2 in pockets:
			if _pocket_side(Vector3(r.get_center().x, 0, r.get_center().y)) != side:
				continue
			cuts.append(r)
		cuts.sort_custom(func(p: Rect2, q: Rect2) -> bool: return (p.position.x < q.position.x) if along_x else (p.position.y < q.position.y))
		var cur: float = strip.position.x if along_x else strip.position.y
		var endv: float = strip.end.x if along_x else strip.end.y
		for r2: Rect2 in cuts:
			var c0: float = r2.position.x if along_x else r2.position.y
			var c1: float = r2.end.x if along_x else r2.end.y
			if along_x:
				rects.append(Rect2(cur, strip.position.y, c0 - cur, strip.size.y))
				# the strip beyond the pocket's far end
				if side == 0:
					rects.append(Rect2(c0, strip.position.y, c1 - c0, r2.position.y - strip.position.y))
				else:
					rects.append(Rect2(c0, r2.end.y, c1 - c0, strip.end.y - r2.end.y))
			else:
				rects.append(Rect2(strip.position.x, cur, strip.size.x, c0 - cur))
				if side == 2:
					rects.append(Rect2(strip.position.x, c0, r2.position.x - strip.position.x, c1 - c0))
				else:
					rects.append(Rect2(r2.end.x, c0, strip.end.x - r2.end.x, c1 - c0))
			cur = c1
		if along_x:
			rects.append(Rect2(cur, strip.position.y, endv - cur, strip.size.y))
		else:
			rects.append(Rect2(strip.position.x, cur, strip.size.x, endv - cur))
	for r3: Rect2 in rects:
		if r3.size.x < 0.05 or r3.size.y < 0.05:
			continue
		var ob: NavigationObstacle3D = NavigationObstacle3D.new()
		ob.name = "EdgeCarve"
		ob.affect_navigation_mesh = true
		ob.carve_navigation_mesh = true
		ob.avoidance_enabled = false
		ob.height = 8.0
		ob.position = Vector3(r3.position.x, -1.0, r3.position.y)
		ob.vertices = PackedVector3Array([Vector3(0, 0, 0), Vector3(r3.size.x, 0, 0), Vector3(r3.size.x, 0, r3.size.y), Vector3(0, 0, r3.size.y)])
		geo.add_child(ob)
		_bake_only.append(ob)


## True when `p` is inside the grounds' edge by at least `margin` metres.
func _in_grounds(p: Vector3, margin: float) -> bool:
	return p.x > OUT_MIN.x + margin and p.x < OUT_MAX.x - margin and p.z > OUT_MIN.y + margin and p.z < OUT_MAX.y - margin


## A hidden solid standing on the snow (centre on the ground, size, yaw deg), no_mantle, cut into slices no taller
## than NAV_SOLID_H so the bake leaves no walkable island inside it (build_nav_blocks' note).
func _solid(name_: String, c: Vector3, sz: Vector3, yaw: float) -> void:
	var y0: float = 0.0
	while y0 < sz.y - 0.01:
		var h: float = minf(NAV_SOLID_H, sz.y - y0)
		var body: StaticBody3D = StaticBody3D.new()
		body.name = name_
		body.collision_layer = 1
		body.collision_mask = 0
		body.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c + Vector3(0, y0 + h * 0.5, 0))
		body.set_meta("no_mantle", true)
		body.set_meta("decal_persist", false)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(sz.x, h, sz.z)
		cs.shape = shape
		body.add_child(cs)
		geo.add_child(body)
		_count += 1
		y0 += h


## The Helvetia cellar (T&C M2; Appendix A asks for the 8 perk machines in a cellar behind a 1500 door for the
## vertical slice). Door 3 in the taproom's east wall -> stair hall (x 24..28, z 10..19) with a ramp down to the
## vaulted cellar (x 24..36, z 19..31, floor CELLAR_Y). Its roof is the yard's ground surface.
const CELLAR_Y: float = -3.2
const CELLAR_TOP: float = -0.2
## machines: [perk, pos, yaw]; front (local -Z) faces the middle of the vault
const CELLAR_PERKS: Array = [
	# west row starts 4 m from the foot of the stairs, so the ramp spills into open floor (playtest, T-028)
	["ironhide_stout", Vector3(25.9, CELLAR_Y, 23.0), -90.0], ["second_wind", Vector3(25.9, CELLAR_Y, 25.8), -90.0],
	["trigger_tonic", Vector3(25.9, CELLAR_Y, 28.6), -90.0],
	["twin_barrel", Vector3(34.1, CELLAR_Y, 21.6), 90.0], ["marathon_malt", Vector3(34.1, CELLAR_Y, 24.6), 90.0],
	["hawkeye_brandy", Vector3(34.1, CELLAR_Y, 27.6), 90.0],
	["packmule_porter", Vector3(28.6, CELLAR_Y, 29.4), 0.0], ["blastproof_bock", Vector3(31.4, CELLAR_Y, 29.4), 0.0],
	# the ninth (M3): between the south pair, on the vault's axis, under its own bulb
	["overclock_cordial", Vector3(30.15, CELLAR_Y, 29.4), 0.0],
]
## Same as PerkMachine._shape_footprint (that script needs the autoloads, which a --script run doesn't have).
## Keep the two in step.
const MACHINE_FOOTPRINTS: Dictionary = {
	"barrel": Vector3(1.2, 1.9, 1.2), "cabinet": Vector3(0.8, 2.3, 0.6), "crate": Vector3(1.0, 2.0, 0.65),
	"twin": Vector3(1.2, 2.1, 0.6), "teardrop": Vector3(1.0, 2.4, 0.9), "periscope": Vector3(0.9, 1.8, 0.65),
	"wagon": Vector3(1.7, 1.7, 0.85), "safe": Vector3(1.1, 1.9, 0.95),
	"coil": Vector3(0.8, 2.3, 0.6),   # Overclock Cordial: cabinet-sized (perks.json)
}
## crate spots: [name, position, yaw, can_start]
const CRATES: Array = [["Hearth", Vector3(22.9, 0, 14.0), 90.0, true], ["GuestBed", Vector3(22.0, UP_Y, 0.8), 180.0, false],
	["TackRoom", Vector3(22.9, 0, 31.5), 90.0, true], ["Well", Vector3(13.5, 0, 42.0), 90.0, false]]
## Ammo boxes (Update 02 section 4, T-049): [name, floor position, yaw so local -Z faces the room]. Behind the bar
## against the back shelf at the alcove's dead end (clear of Alix's trapdoor at 6.6, 5.6 and the alcove's mouth at
## the north end), and on the stable's west wall under the hayloft between the trench-gun chalk and the yard door.
const AMMO_BOXES: Array = [["Taproom", Vector3(5.34, 0, 7.3), -90.0], ["Stable", Vector3(STB_X0 + 0.48, 0, 32.0), -90.0],
	["Cellar", Vector3(14.6, -3.2, 15.5), 0.0],   # the Old Cellar's barrel vault, south wall (T-051)
	["Grounds", Vector3(38.4, 0, 26.0), 20.0]]   # T-080: the supply drop under the parachute's tree, facing the Wreck Loop
## The Armorer's Bench (UPDATE_04 section 6, T-068): [floor position against the wall, yaw so local -Z faces the room].
## The inn has no walled tack room: the bench stands in the stable's tack corner on the west wall, under the tack rail
## and saddle blanket (raised above its pegboard), between the hay-stair end and the trench-gun chalk.
const ARMORERS_BENCH: Array = [Vector3(STB_X0 + T * 0.5 + 0.01, 0, 26.5), -90.0]
## the cellar's hanging bulbs (bulb glass position; the power lights sit just under them): one pool per machine row
const CELLAR_BULBS: Array = [Vector3(27.0, CELLAR_Y + 2.55, 22.5), Vector3(33.0, CELLAR_Y + 2.55, 22.5),
	Vector3(26.5, CELLAR_Y + 2.55, 27.5), Vector3(33.5, CELLAR_Y + 2.55, 27.5), Vector3(30.35, CELLAR_Y + 2.55, 28.7)]
var _cellar_lit: Node3D   # holder for the lit bulb glass (shown with the first CellarBulb light)


## Hidden navmesh blocks stay under the agent height: the bake rasterises a box's faces, not its volume, so a block
## taller than agent_height (1.75) leaves a walkable island inside itself (T-051; one sat inside the Crucible's).
const NAV_SOLID_H: float = 1.6
## Perk machines and crates make their collision bodies at runtime, after the bake. Their footprints go into
## the navmesh here (invisible colliders) so zombies path round them instead of into them (T-027).
func build_nav_blocks() -> void:
	var pdata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perks.json"))["perks"]
	for pk: Array in CELLAR_PERKS:
		var fp: Vector3 = MACHINE_FOOTPRINTS.get(str((pdata[str(pk[0])] as Dictionary).get("shape", "cabinet")), Vector3(1.0, 2.0, 0.7))
		if absf(float(pk[2])) == 90.0:
			fp = Vector3(fp.z, fp.y, fp.x)
		var c: Vector3 = pk[1]
		box(geo, "NavBlock_" + str(pk[0]), c - Vector3(fp.x * 0.5, 0, fp.z * 0.5), c + Vector3(fp.x * 0.5, minf(fp.y, NAV_SOLID_H), fp.z * 0.5), "metal", true, false)
	for cr: Array in CRATES:
		var half: Vector3 = Vector3(0.7, 0, 0.35) if absf(float(cr[2])) != 90.0 else Vector3(0.35, 0, 0.7)
		var p: Vector3 = cr[1]
		box(geo, "NavBlock_Crate", p - half, p + half + Vector3(0, 0.75, 0), "metal", true, false)
	for ab: Array in AMMO_BOXES:
		var ah: Vector3 = Vector3(0.52, 0, 0.3) if absf(float(ab[2])) != 90.0 else Vector3(0.3, 0, 0.52)
		var ap: Vector3 = ab[1]
		box(geo, "NavBlock_AmmoBox", ap - ah, ap + ah + Vector3(0, 0.62, 0), "metal", true, false)
	var bp: Vector3 = ARMORERS_BENCH[0]   # the bench runs 0.72 m out from the west wall, 1.5 m along it
	box(geo, "NavBlock_ArmorersBench", bp + Vector3(0, 0, -0.75), bp + Vector3(0.72, 0.9, 0.75), "metal", true, false)


func build_cellar() -> void:
	var cy: float = CELLAR_Y
	# stair hall: landing at ground level, then the ramp down (south)
	# art pass: limewashed rubble in the stair hall, coursed stone and flagstones in the vault, a brick soffit
	box(geo, "CellarLanding", Vector3(24.15, -0.5, 10.15), Vector3(28.0, 0.0, 13.0), "floor_wood")
	ramp_z("CellarStairs", 24.3, 27.85, 19.0, 13.0, cy, 0.0)
	wall_x("HallN", 10.0, 24.0, 28.0 + T * 0.5, cy, 3.0, [], "limewash")
	wall_z("HallE", 28.0, 10.0, 19.0, cy, 3.0, [], "limewash")
	wall_z("HallW", 24.0, 16.0, 19.0, cy, 3.0, [], "limewash")
	box(geo, "HallWLow", Vector3(24.0 - T * 0.5, cy, 10.0), Vector3(24.0 + T * 0.5, 0.0, 16.0), "limewash")
	box(geo, "HallS", Vector3(24.0 - T * 0.5, CELLAR_TOP, 19.0 - T * 0.5), Vector3(28.0 + T * 0.5, 3.0, 19.0 + T * 0.5), "limewash")
	box(geo, "HallRoof", Vector3(24.0, 3.0, 10.0 - T * 0.5), Vector3(28.0 + T * 0.5, 3.2, 19.0), "roof")
	box(geo, "HallUnder", Vector3(24.15, cy - 0.5, 13.0), Vector3(28.0, cy, 19.0), "cellar_stone")
	# the cellar
	box(geo, "CellarFloor", Vector3(24.0, cy - 0.5, 19.0), Vector3(36.0, cy, 31.0), "cellar_floor")
	box(geo, "CellarRoof", Vector3(24.0 - T * 0.5, CELLAR_TOP, 19.0), Vector3(36.0 + T * 0.5, -0.04, 31.0 + T * 0.5), "brick_cellar")
	box(geo, "CellarRoofSnow", Vector3(24.0 - T * 0.5, -0.04, 19.0), Vector3(36.0 + T * 0.5, 0.0, 31.0 + T * 0.5), "snow")
	wall_z("CelW", 24.0, 19.0, 31.0, cy, CELLAR_TOP, [[19.45, 21.05, cy, cy + DOOR_H]], "cellar_stone")   # the breach to the Old Cellar (T-051)
	wall_z("CelE", 36.0, 19.0, 31.0, cy, CELLAR_TOP, [], "cellar_stone")
	wall_x("CelS", 31.0, 24.0 - T * 0.5, 36.0 + T * 0.5, cy, CELLAR_TOP, [], "cellar_stone")
	wall_x("CelN", 19.0, 28.0, 36.0 + T * 0.5, cy, CELLAR_TOP, [], "cellar_stone")
	box(geo, "CelNLintel", Vector3(24.0, cy + 2.6, 19.0 - T * 0.5), Vector3(28.0, CELLAR_TOP, 19.0 + T * 0.5), "cellar_stone")
	# vault pillars (cover, and something to run a loop around)
	for p: Vector2 in [Vector2(30.0, 23.0), Vector2(30.0, 27.0)]:
		box(geo, "CellarPillar", Vector3(p.x - 0.35, cy, p.y - 0.35), Vector3(p.x + 0.35, CELLAR_TOP, p.y + 0.35), "cellar_stone")
	# big dressing with collision (baked into the navmesh; all against walls, outside the loops and the stair spill):
	# the workbench + Helvetia crates on the north wall, the barrels in the NE corner, the kegs on the landing corner
	box(geo, "NavBlock_Crucible", Vector3(28.5, cy, 19.15), Vector3(30.5, cy + NAV_SOLID_H, 20.75), "metal", true, false)   # the Crucible's footprint (T-032)
	box(geo, "CellarCrateCol", Vector3(30.9, cy, 19.15), Vector3(31.5, cy + 1.1, 19.76), "metal", true, false)
	box(geo, "CellarBarrelCol", Vector3(33.3, cy, 19.15), Vector3(35.95, cy + 1.0, 20.8), "metal", true, false)   # (T-051: to x 33.3, no dead-end pocket behind the lever)
	box(geo, "LandingKegCol", Vector3(27.0, 0.0, 10.15), Vector3(28.0, 0.8, 11.1), "metal", true, false)
	build_old_cellar()


## THE OLD CELLAR (Update 02 section 6.1, DECISIONS T-051): the inn's own cellar under the taproom, older than the
## Helvetia vault. Door 5 (1250, zone OLD_CELLAR) in the taproom's west wall opens on the old cellar stairs in a
## stone lean-to (x -3..0, z 8..18.5), which come down to a landing and through the foundation into:
##   - the wine cellar (x 0..10.9, z 8..18.5): low brick arches on three piers, racks, casks, dripping water;
##   - the coal room (x 0..5, z 0..8): the coal chute window (a light well under the porch, W_CEL_COAL) and the
##     holding cell, an iron cage where the patrol locked Jakub (section 6.2: JakubCage, JakubSpawn, JakubWait);
##   - the root cellar (x 5..10.9, z 0..8): preserves, sacks, hams; the cousins' jam jars on the top shelf;
##   - the ice cellar (x 5..8.3, z 5..8), the cousins' hidden room under the bar (v3 section 4.6; Alix's trapdoor at
##     6.6, 5.6 is right overhead), bricked off from the coal room until the Cousins round is cleared (IceCellarSeal);
##   - the barrel vault (x 10.9..24, z 0..16): the training loop round the central barrel stack (corridors 4.8 m
##     each side, 3.2 m past the two pillars), the Gewehr 43, an ammo box, the vault window (a light well
##     outside the east wall, W_CEL_VAULT), and the breach the Helvetia installers knocked through to their own
##     cellar (x 20.85..24, z 16..21.3), bricked up until both Door 3 and Door 5 are bought (CellarBreach).
const OC_WELL_Y: float = -1.3          # the light wells' floor (the barricade origin); the room floor is 1.9 m below
const OC_SILL: float = 0.1             # window sill / top above the well floor: a half-height crawl-in window
const OC_WIN_H: float = 0.85
const OC_ANNEX_X: float = -3.0         # the stair lean-to's west wall
## Ground-slab holes [x, z, w, d]: under the taproom, the wine cellar's south bay, the lean-to, the Helvetia breach,
## the coal-chute light well (north) and the vault's light well (east).
const OC_HOLES: Array = [Rect2(-0.15, -0.15, 24.15, 16.15), Rect2(-0.15, 16.0, 11.2, 2.65), Rect2(-3.15, 7.85, 3.0, 10.8),
	Rect2(20.7, 16.0, 3.3, 5.45), Rect2(1.85, -4.65, 3.2, 4.5), Rect2(24.0, -2.1, 2.35, 5.45)]
## The holding cell: the cage's door gap (z) on its east face (x 2.55); 1.5 m so the navmesh runs through it.
const OC_CAGE: Rect2 = Rect2(0.15, 3.3, 2.4, 3.2)
const OC_CAGE_DOOR: Vector2 = Vector2(4.15, 5.65)
const OC_STACK: Rect2 = Rect2(15.9, 6.3, 3.1, 3.4)   # the barrel stack (training loop centre)
const OC_PILLARS: Array = [Vector2(17.45, 2.7), Vector2(17.45, 13.3)]
const OC_PIERS: Array = [Vector2(2.6, 13.2), Vector2(5.4, 13.2), Vector2(8.2, 13.2)]
## bare bulbs (glass position) that light with the cellar lever: two over the loop, one at each end of the wine cellar
const OC_BULBS: Array = [Vector3(17.45, CELLAR_Y + 2.45, 4.6), Vector3(17.45, CELLAR_Y + 2.45, 11.4),
	Vector3(2.6, CELLAR_Y + 2.2, 15.9), Vector3(8.2, CELLAR_Y + 2.2, 10.6)]
var _old_cellar_lit: Node3D   # the lit bulb glass, shown with the first OldCellarBulb light


## A ground slab over [x0, x1] x [z0, z1] (top at y 0) with rectangular holes, as a few boxes: the plane is cut
## on every hole edge and the cells outside all holes are merged into runs along X.
func _slab_with_holes(name_: String, x0: float, x1: float, z0: float, z1: float, holes: Array) -> void:
	var xs: Array[float] = [x0, x1]
	var zs: Array[float] = [z0, z1]
	for h: Rect2 in holes:
		for x: float in [h.position.x, h.end.x]:
			if x > x0 and x < x1 and not xs.has(x):
				xs.append(x)
		for z: float in [h.position.y, h.end.y]:
			if z > z0 and z < z1 and not zs.has(z):
				zs.append(z)
	xs.sort()
	zs.sort()
	for j: int in zs.size() - 1:
		var run0: float = INF
		var run1: float = INF
		for i: int in xs.size():
			var solid: bool = false
			if i < xs.size() - 1:
				solid = true
				var c: Vector2 = Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
				for h: Rect2 in holes:
					if h.has_point(c):
						solid = false
						break
			if solid:
				if run0 == INF:
					run0 = xs[i]
				run1 = xs[i + 1]
			elif run0 != INF:
				box(geo, name_, Vector3(run0, -0.5, zs[j]), Vector3(run1, 0.0, zs[j + 1]), "snow")
				run0 = INF


## The Old Cellar's collision shell (see the OC_ constants above). Floors and walls are stone, the taproom's floor
## is the vault's plank ceiling, the outdoor parts of the roof carry snow.
func build_old_cellar() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var wy: float = OC_WELL_Y
	var win: Array = [wy + OC_SILL, wy + OC_WIN_H]
	# ---- outer walls (up to the ground), the window openings at the light wells
	wall_x("OCN", 0.0, -T * 0.5, 24 + T * 0.5, cy, 0.0, [[2.65, 4.25] + win], "cellar_stone")
	wall_z("OCE", 24.0, 0.0, 10.0, cy, 0.0, [[1.0, 2.6] + win], "cellar_stone")
	wall_z("OCW", 0.0, 0.0, 18.5 + T * 0.5, cy, 0.0, [[15.8, 18.2, cy, cy + 2.4]], "cellar_stone")
	wall_x("OCWineS", 18.5, -T * 0.5, 10.9 + T * 0.5, cy, 0.0, [], "cellar_stone")
	wall_x("OCVaultS", 16.0, 10.9, 20.85 + T * 0.5, cy, 0.0, [], "cellar_stone")
	wall_z("OCTunW", 20.85, 16.0, 21.3 + T * 0.5, cy, 0.0, [], "limewash")
	# the breach is shut in the main navmesh (CellarBreach swaps in the open bake at runtime): a bake-only cut
	_bake_only.append(box(geo, "BreachNavCut", Vector3(23.85, cy, 19.45), Vector3(24.15, cy + DOOR_H, 21.05), "metal", true, false))
	wall_x("OCTunS", 21.3, 20.85, 24.0, cy, 0.0, [], "limewash")
	# ---- inner walls (up to the ceiling): the long middle wall with the root and wine arches, the coal / root / wine
	# partitions, the ice cellar's brick box (its west wall is the coal room's, with the bricked-up chute)
	wall_z("OCMid", 10.9, 0.0, 18.5, cy, top, [[1.6, 3.6, cy, cy + 2.4], [10.0, 13.2, cy, cy + 2.55]], "cellar_stone")
	wall_x("OCZ8", 8.0, 0.0, 10.9, cy, top, [[2.8, 4.6, cy, cy + 2.3], [8.7, 10.6, cy, cy + 2.3]], "cellar_stone")
	wall_z("OCX5", 5.0, 0.0, 8.0, cy, top, [[5.9, 7.5, cy, cy + 2.0]], "cellar_stone")
	wall_x("OCIceN", 5.0, 5.0, 8.3 + T * 0.5, cy, top, [], "brick_cellar")
	wall_z("OCIceE", 8.3, 5.0, 8.0, cy, top, [], "brick_cellar")
	# ---- floors and ceilings
	for f: Array in [[Vector3(-0.15, cy - 0.5, -0.15), Vector3(24.15, cy, 16.15)], [Vector3(-0.15, cy - 0.5, 16.0), Vector3(11.05, cy, 18.65)],
			[Vector3(20.7, cy - 0.5, 16.0), Vector3(24.0, cy, 21.45)]]:
		box(geo, "OCFloor", f[0], f[1], "cellar_floor").set_meta("surface", "stone")
	box(geo, "OCRoof", Vector3(-T * 0.5, top, -T * 0.5), Vector3(24 + T * 0.5, 0.0, 16.0), "planks").set_meta("surface", "wood")   # the taproom's floor
	for r: Array in [[Vector3(-0.15, top, 16.0), Vector3(11.05, 0.0, 18.65)], [Vector3(20.7, top, 16.0), Vector3(24.0, 0.0, 21.45)]]:
		box(geo, "OCRoofOut", r[0], Vector3((r[1] as Vector3).x, -0.04, (r[1] as Vector3).z), "brick_cellar")
		box(geo, "OCRoofSnow", Vector3((r[0] as Vector3).x, -0.04, (r[0] as Vector3).z), r[1], "snow").set_meta("surface", "snow")
	# ---- the stair lean-to: landing behind Door 5, the flight down the west wall of the inn, the foot landing
	var ax: float = OC_ANNEX_X
	wall_z("OCAnnW", ax, 7.85, 18.65, cy, 2.8, [], "cellar_stone")
	wall_x("OCAnnN", 8.0, ax - T * 0.5, 0.0, cy, 2.8, [], "cellar_stone")
	wall_x("OCAnnS", 18.5, ax - T * 0.5, 0.0, cy, 2.8, [], "cellar_stone")
	wall_z("OCAnnE", 0.0, 16.0 + T * 0.5, 18.65, 0.0, 2.8, [], "cellar_stone")
	box(geo, "OCAnnRoof", Vector3(ax - T * 0.5, 2.8, 7.85), Vector3(0.0, 3.0, 18.65), "roof")
	box(geo, "OCAnnLanding", Vector3(ax + T * 0.5, -0.5, 8.15), Vector3(-T * 0.5, 0.0, 9.95), "stone").set_meta("surface", "stone")
	ramp_z("OCStairs", ax + T * 0.5, -T * 0.5, 15.5, 9.95, cy, 0.0)
	box(geo, "OCAnnFloor", Vector3(ax, cy - 0.5, 15.5), Vector3(0.0, cy, 18.5), "cellar_floor").set_meta("surface", "stone")
	# ---- the light wells: a stone-lined pit at the window, steps up to the field (zombies come down them)
	box(geo, "WellPitN", Vector3(1.85, wy - 0.3, -2.15), Vector3(5.05, wy, -0.15), "stone").set_meta("surface", "stone")
	box(geo, "WellSideN", Vector3(1.85, wy - 0.3, -4.65), Vector3(2.0, 0.0, -0.15), "cellar_stone")
	box(geo, "WellSideN", Vector3(4.9, wy - 0.3, -4.65), Vector3(5.05, 0.0, -0.15), "cellar_stone")
	ramp_z("WellStepsN", 2.0, 4.9, -2.15, -4.65, wy, 0.0, -1e9, false)
	_stair_dressing.pop_back()   # stone steps instead (_dress_old_cellar)
	box(geo, "WellPitE", Vector3(24.0, wy - 0.3, 0.4), Vector3(26.35, wy, 3.35), "stone").set_meta("surface", "stone")
	box(geo, "WellSideE", Vector3(26.2, wy - 0.3, -2.1), Vector3(26.35, 0.0, 3.35), "cellar_stone")
	box(geo, "WellSideE", Vector3(24.0, wy - 0.3, 3.2), Vector3(26.2, 0.0, 3.35), "cellar_stone")
	box(geo, "WellSideE", Vector3(23.9, wy - 0.3, -2.1), Vector3(24.15, 0.0, 0.0), "cellar_stone")
	ramp_z("WellStepsE", 24.15, 26.2, 0.4, -2.1, wy, 0.0, -1e9, false)
	_stair_dressing.pop_back()
	# ---- solid things in the rooms (baked; all with a clear 2 m+ walk past them)
	box(geo, "OCChimneyFoot", Vector3(11.05, cy, 0.15), Vector3(13.15, top, 1.35), "brick_cellar")   # the hearth's footing
	for p: Vector2 in OC_PILLARS:
		box(geo, "OCPillar", Vector3(p.x - 0.35, cy, p.y - 0.35), Vector3(p.x + 0.35, top, p.y + 0.35), "cellar_stone")
	for p2: Vector2 in OC_PIERS:
		box(geo, "OCPier", Vector3(p2.x - 0.35, cy, p2.y - 0.35), Vector3(p2.x + 0.35, top, p2.y + 0.35), "cellar_stone")
	var st: Rect2 = OC_STACK
	box(geo, "OCBarrelStack", Vector3(st.position.x, cy, st.position.y), Vector3(st.end.x, cy + NAV_SOLID_H, st.end.y), "furniture", true, false)
	# racks, casks and shelves against the walls (drawn by _dress_old_cellar)
	for rk: Array in [[Vector3(0.15, cy, 8.15), Vector3(2.6, cy + 2.0, 8.6)], [Vector3(4.8, cy, 8.15), Vector3(8.5, cy + 2.0, 8.6)],
			[Vector3(3.0, cy, 17.95), Vector3(9.6, cy + 2.0, 18.35)], [Vector3(0.15, cy, 9.0), Vector3(0.6, cy + 2.0, 15.4)],
			[Vector3(9.85, cy, 13.9), Vector3(10.75, cy + 1.7, 17.9)],   # the big casks
			[Vector3(5.4, cy, 0.15), Vector3(10.5, cy + 2.1, 0.55)], [Vector3(5.15, cy, 0.8), Vector3(5.5, cy + 1.9, 4.5)],   # root shelves
			[Vector3(5.3, cy, 4.25), Vector3(8.1, cy + 0.8, 4.85)],   # sacks against the ice cellar's wall
			[Vector3(15.6, cy, 15.4), Vector3(19.3, cy + 2.0, 15.85)], [Vector3(23.4, cy, 4.4), Vector3(23.85, cy + 2.0, 9.6)]]:   # vault racks
		box(geo, "OCRackCol", rk[0], rk[1], "furniture", true, false).set_meta("no_mantle", true)   # (nobody camps on the sacks)
	# the holding cell: bars from floor to ceiling. Solid hidden panels along the bar lines cut the navmesh (the
	# bars are thinner than a cell); the door gap is left open, its door is a runtime collider (HoldingCage).
	var cg: Rect2 = OC_CAGE
	var ex: float = cg.end.x
	box(geo, "CagePanel", Vector3(cg.position.x, cy, cg.position.y - 0.06), Vector3(ex + 0.06, top, cg.position.y + 0.06), "metal", true, false)
	box(geo, "CagePanel", Vector3(cg.position.x, cy, cg.end.y - 0.06), Vector3(ex + 0.06, top, cg.end.y + 0.06), "metal", true, false)
	box(geo, "CagePanel", Vector3(ex - 0.06, cy, cg.position.y), Vector3(ex + 0.06, top, OC_CAGE_DOOR.x), "metal", true, false)
	box(geo, "CagePanel", Vector3(ex - 0.06, cy, OC_CAGE_DOOR.y), Vector3(ex + 0.06, top, cg.end.y), "metal", true, false)


## The second navmesh (T-051): the whole map baked again without the breach's bake-only cut, in a disabled region
## that CellarBreach swaps in for "Navigation" when it opens.
func _bake_breach_open() -> void:
	var nm: NavigationMesh = nav.navigation_mesh.duplicate() as NavigationMesh
	nm.clear_polygons()
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, nav)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var r: NavigationRegion3D = NavigationRegion3D.new()
	r.name = "NavigationBreachOpen"
	r.navigation_mesh = nm
	r.enabled = false
	map_root.add_child(r)
	print("navmesh (breach open) polygons: %d" % nm.get_polygon_count())


func bake_navmesh() -> void:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 42.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | EDGE_LAYER   # the edge wall shapes the navmesh though shots pass it (T-084)
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, nav)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav.navigation_mesh = nm
	print("navmesh polygons: %d" % nm.get_polygon_count())


# ================================================================== art dressing (no collision)

func build_dressing() -> void:
	_dress_floors_and_ceilings()
	_dress_windows_and_doors()
	_dress_stairs()
	_dress_staircase()
	_dress_hearth()
	_dress_bar()
	_dress_taproom()
	_dress_upstairs()
	_dress_stable()
	_dress_cellar()
	_dress_exterior()
	_dress_carters_road()
	_dress_yard()
	_dress_grounds()
	_dress_wreck()
	_dress_polish()
	_dress_lighting()
	_emit_library_props()


func _dress_floors_and_ceilings() -> void:
	Props.block(dress, Vector3(0.15, 0.0, 0.15), Vector3(23.85, 0.012, 15.85), "floorboards")
	Props.block(dress, Vector3(STB_X0 + 0.15, 0.0, STB_Z0 + 0.15), Vector3(STB_X1 - 0.15, 0.012, STB_Z1 - 0.15), "dirt")
	Props.block(dress, Vector3(18.15, 0.0, 16.0), Vector3(21.85, 0.012, 22.0), "dirt")
	# taproom ceiling beams (north-south) and a summer beam
	for x: float in [5.0, 8.0, 11.0, 14.0, 17.0, 20.0, 23.0]:
		Props.block(dress, Vector3(x - 0.14, TAP_H - 0.28, 0.15), Vector3(x + 0.14, TAP_H, 9.85 if x < STAIR_X1 else 15.85), "beam")
	# the stairwell's ceiling beams
	for z: float in [12.0, 14.0]:
		Props.block(dress, Vector3(0.15, UP_TOP - 0.24, z - 0.12), Vector3(STAIR_X1 - 0.15, UP_TOP, z + 0.12), "beam")
	Props.block(dress, Vector3(3.0, TAP_H - 0.36, 7.85), Vector3(23.85, TAP_H - 0.06, 8.15), "beam")
	for x: float in [8.0, 14.0, 20.0]:
		if x != FRONT_DOOR_X:   # the north wall's x 20 post would stand in the front door (T-072)
			Props.block(dress, Vector3(x - 0.15, 0, 0.15), Vector3(x + 0.15, TAP_H, 0.42), "beam")
		if x != 20.0:   # the south wall's x 20 post stood in the middle of the stable door (19..21): the beam lands on the lintel (T-072)
			Props.block(dress, Vector3(x - 0.15, 0, 15.58), Vector3(x + 0.15, TAP_H, 15.85), "beam")
	# upstairs beams + hall runner
	for x: float in [2.0, 6.0, 10.0, 14.0, 18.0, 22.0]:
		Props.block(dress, Vector3(x - 0.12, UP_TOP - 0.24, 0.15), Vector3(x + 0.12, UP_TOP, 9.85), "beam")
	Props.block(dress, Vector3(1.0, UP_Y, 7.4), Vector3(23.0, UP_Y + 0.012, 8.6), "rug")
	# stable trusses: tie beams, their wall posts (pilasters, flush enough that nobody clips them on the landing), a
	# purlin each side and collar beams under the ridge (T-084: the loft looks up into a real roof now)
	for z: float in [24.5, 28.0, 31.5]:
		Props.block(dress, Vector3(STB_X0 + 0.15, STABLE_H - 0.6, z - 0.15), Vector3(STB_X1 - 0.15, STABLE_H - 0.3, z + 0.15), "beam")
		for x: float in [STB_X0 + 0.15, STB_X1 - 0.31]:
			Props.block(dress, Vector3(x, 0, z - 0.17), Vector3(x + 0.16, STABLE_H - 0.3, z + 0.17), "beam")
		Props.block(dress, Vector3(9.0, STABLE_H - 0.3, z - 0.1), Vector3(21.0, STABLE_H - 0.02, z + 0.1), "beam")   # the collar, up in the roof
		for x2: float in [9.0, 21.0]:
			Props.block(dress, Vector3(x2 - 0.12, STABLE_H - 0.6, z - 0.1), Vector3(x2 + 0.12, STABLE_H - 0.02, z + 0.1), "beam")
	for x3: float in [9.0, 21.0]:
		Props.block(dress, Vector3(x3 - 0.1, STABLE_H - 0.9, STB_Z0 + 0.15), Vector3(x3 + 0.1, STABLE_H - 0.6, STB_Z1 - 0.15), "beam")   # purlins


## Frames, sills (with snow outside), shutters and curtains for a window opening. The curtains are DraftCurtains
## (T-053): they billow in the draught, harder as `win_id`'s barricade loses boards.
func _window(pos: Vector3, yaw: float, curtains: bool, sill: float = WIN_SILL, top: float = WIN_TOP, win_id: String = "") -> void:
	var g: Node3D = Props.group(dress, "WindowDress", pos, yaw)   # local +Z = inside
	var hw: float = 0.8
	for side: float in [1.0, -1.0]:
		var face: float = side * T * 0.5
		var out: float = side
		Props.block(g, Vector3(-hw - 0.12, sill - 0.04, face), Vector3(-hw, top + 0.12, face + out * 0.06), "beam")
		Props.block(g, Vector3(hw, sill - 0.04, face), Vector3(hw + 0.12, top + 0.12, face + out * 0.06), "beam")
		Props.block(g, Vector3(-hw - 0.12, top, face), Vector3(hw + 0.12, top + 0.14, face + out * 0.07), "beam")
	# inner sill board, outer sill with a snow cap
	Props.block(g, Vector3(-hw - 0.15, sill - 0.05, -T * 0.5), Vector3(hw + 0.15, sill, T * 0.5 + 0.18), "beam")
	Props.block(g, Vector3(-hw - 0.15, sill - 0.06, -T * 0.5 - 0.22), Vector3(hw + 0.15, sill, -T * 0.5), "beam")
	Props.block(g, Vector3(-hw - 0.1, sill, -T * 0.5 - 0.2), Vector3(hw + 0.1, sill + 0.07, -T * 0.5 - 0.02), "snow", false)
	# open shutters outside, hanging askew
	for side: float in [-1.0, 1.0]:
		var sh: Node3D = Props.group(g, "Shutter", Vector3(side * (hw + 0.14), sill, -T * 0.5 - 0.04), side * 100.0)
		Props.block(sh, Vector3(-0.03, 0, 0), Vector3(0.03, top - sill + 0.1, side * -0.75), "planks")
		sh.rotation.z = deg_to_rad(side * 3.0)
	if curtains:
		for cx: float in [-hw - 0.25, hw + 0.25]:
			var dc: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/draft_curtain.gd", "DraftCurtainL" if cx < 0.0 else "DraftCurtainR", {
				"height": top - sill + 0.4, "mat_key": "cloth_red",
				"window": NodePath("../../../Gameplay/" + win_id) if win_id != "" else NodePath("")})
			dc.position = Vector3(cx, top + 0.05, T * 0.5 + 0.08)
			dc.rotation.y = PI
			g.add_child(dc)
		Props.block(g, Vector3(-hw - 0.5, top + 0.15, T * 0.5 + 0.06), Vector3(hw + 0.5, top + 0.18, T * 0.5 + 0.1), "iron")


func _door_frame(pos: Vector3, yaw: float, width: float, height: float) -> void:
	var g: Node3D = Props.group(dress, "DoorFrame", pos, yaw)
	for side: float in [1.0, -1.0]:
		var face: float = side * T * 0.5
		Props.block(g, Vector3(-width * 0.5 - 0.14, 0, face), Vector3(-width * 0.5, height + 0.14, face + side * 0.07), "beam")
		Props.block(g, Vector3(width * 0.5, 0, face), Vector3(width * 0.5 + 0.14, height + 0.14, face + side * 0.07), "beam")
		Props.block(g, Vector3(-width * 0.5 - 0.14, height, face), Vector3(width * 0.5 + 0.14, height + 0.18, face + side * 0.08), "beam")


func _dress_windows_and_doors() -> void:
	_window(Vector3(7.0, 0, 0), 0.0, true, WIN_SILL, WIN_TOP, "W_TAP_N1")
	_window(Vector3(17.0, 0, 0), 0.0, true, WIN_SILL, WIN_TOP, "W_TAP_N2")
	_window(Vector3(0, 0, 6.0), 90.0, true, WIN_SILL, WIN_TOP, "W_TAP_W")
	_window(Vector3(24.0, 0, 8.0), -90.0, true, WIN_SILL, WIN_TOP, "W_TAP_E")
	_window(Vector3(4.0, UP_Y, 0), 0.0, true, UP_Y + WIN_SILL - UP_Y, UP_Y + WIN_TOP - UP_Y, "W_UP_R1")
	_window(Vector3(20.0, UP_Y, 0), 0.0, true, WIN_SILL, WIN_TOP, "W_UP_R3")
	_window(Vector3(9.0, 0, 22.0), 0.0, false)
	_window(Vector3(14.0, 0, 22.0), 0.0, false)
	_window(Vector3(12.0, 0, 34.0), 180.0, false)
	_window(Vector3(22.0, LOFT_TOP, STB_Z1), 180.0, false)   # the loft door over the yard, its lower half boarded (T-084)
	_door_frame(Vector3(STAIR_X1, 0, 15.1), 90.0, 1.6, DOOR_H)
	_door_frame(Vector3(FRONT_DOOR_X, 0, 0.0), 0.0, 1.6, DOOR_H)   # the front door (T-072)
	_door_frame(Vector3(20.0, 0, 16.0), 0.0, 2.0, DOOR_H)
	_door_frame(Vector3(24.0, 0, 11.5), -90.0, 1.6, DOOR_H)
	_door_frame(Vector3(20.0, 0, 22.0), 0.0, 3.0, 2.6)
	for dx: float in [5.75, 11.75, 20.25]:
		_door_frame(Vector3(dx, UP_Y, 6.0), 0.0, 1.5, 2.2)
	# the great doors at the stable's south end (barred)
	# (the campaign exfil cutscene tweens this group's rotation.x so the doors fall outward: its meshes stay
	# un-batched, hence the "keep" meta)
	for jx: float in [16.0, 20.0]:   # jambs and a lintel round the opening (3 m high since T-084: the gallery runs over them)
		Props.block(dress, Vector3(jx - 0.16, 0, 33.8), Vector3(jx + 0.16, GREAT_DOOR_H + 0.15, 34.2), "beam")
	Props.block(dress, Vector3(15.7, GREAT_DOOR_H - 0.05, 33.8), Vector3(20.3, GREAT_DOOR_H + 0.18, 34.2), "beam")
	var gd: Node3D = Props.group(dress, "GreatDoors", Vector3(18, 0, 33.82))
	Props.block(gd, Vector3(-2.0, 0, -0.06), Vector3(2.0, GREAT_DOOR_H, 0.0), "planks")
	Props.obox(gd, Vector3(0, GREAT_DOOR_H * 0.5, -0.12), Vector3(0.2, 3.5, 0.1), "beam", Vector3(0, 0, 54))
	Props.obox(gd, Vector3(0, GREAT_DOOR_H * 0.5, -0.12), Vector3(0.2, 3.5, 0.1), "beam", Vector3(0, 0, -54))
	Props.block(gd, Vector3(-2.2, 1.5, -0.24), Vector3(2.2, 1.7, -0.12), "iron")
	for m: Node in gd.get_children():
		m.set_meta("keep", true)


func _dress_stairs() -> void:
	for s: Array in _stair_dressing:
		var x0: float = s[0]
		var x1: float = s[1]
		var z_low: float = s[2]
		var z_high: float = s[3]
		var y_low: float = s[4]
		var y_high: float = s[5]
		var hollow_z: float = s[6]
		var rise: float = y_high - y_low
		var steps: int = int(ceil(rise / 0.22))
		var slope_ang: float = rad_to_deg(atan2(rise, absf(z_high - z_low))) * (1.0 if z_high < z_low else -1.0)
		for k: int in steps:
			var t0: float = float(k) / float(steps)
			var t1: float = float(k + 1) / float(steps)
			var za: float = lerpf(z_low, z_high, t0)
			var zb: float = lerpf(z_low, z_high, t1)
			var yb: float = lerpf(y_low, y_high, t1)
			var bottom: float = y_low
			if minf(za, zb) < hollow_z + 0.35:   # a shell over the soffit (the sawtooth hides behind it)
				bottom = lerpf(y_low, y_high, t1) - 0.3
			Props.block(dress, Vector3(x0, bottom, minf(za, zb)), Vector3(x1, yb - 0.05, maxf(za, zb)), "beam")
			Props.block(dress, Vector3(x0, yb - 0.05, minf(za, zb) - 0.02), Vector3(x1, yb, maxf(za, zb) + 0.02), "furniture")
		if hollow_z > -1e8:
			var zs: float = hollow_z + 0.4
			var mid_z: float = (z_high + zs) * 0.5
			var y_mid: float = lerpf(y_low, y_high, (z_low - mid_z) / (z_low - z_high)) - 0.35
			Props.obox(dress, Vector3((x0 + x1) * 0.5, y_mid, mid_z), Vector3(x1 - x0, 0.1, (zs - z_high) / cos(deg_to_rad(slope_ang)) + 0.1), "plaster", Vector3(slope_ang, 0, 0))
		if not bool(s[7]):
			continue
		# a handrail on the east side
		var rail_x: float = x1 - 0.05
		var mid: Vector3 = Vector3(rail_x, (y_low + y_high) * 0.5 + 0.95, (z_low + z_high) * 0.5)
		var rail_len: float = Vector2(z_high - z_low, rise).length()
		var ang: float = rad_to_deg(atan2(rise, absf(z_high - z_low))) * (1.0 if z_high < z_low else -1.0)
		Props.obox(dress, mid, Vector3(0.06, 0.06, rail_len), "furniture", Vector3(ang, 0, 0))
		var posts: int = int(rail_len / 0.6)
		for k2: int in posts + 1:
			var t: float = float(k2) / float(maxi(1, posts))
			var py: float = lerpf(y_low, y_high, t)
			var pz: float = lerpf(z_low, z_high, t)
			Props.block(dress, Vector3(rail_x - 0.02, py, pz - 0.02), Vector3(rail_x + 0.02, py + 0.95, pz + 0.02), "beam")


## The staircase to the guest rooms (see STAIR_*): a 1.5 m runner with brass stair rods, newel posts and turned
## balusters between the rail bars on the open side and round the hall's edge, a panelled string along the
## vestibule, a wall rail, wainscot following the flight, sconces, framed pictures stepping up the west wall and
## the well's tall east wall, a lantern in the well. The hall's north wall straight ahead at the top stays free.
func _dress_staircase() -> void:
	var g: Node3D = Props.group(dress, "Staircase", Vector3.ZERO)
	var x0: float = 0.15
	var x1: float = FLIGHT_X1
	var z_low: float = STAIR_Z0
	var z_high: float = STAIR_Z1
	var rise: float = UP_Y
	var steps: int = int(ceil(rise / 0.22))
	var ang: float = rad_to_deg(atan2(rise, z_low - z_high))
	var slope_len: float = Vector2(z_low - z_high, rise).length()
	var rc: float = (x0 + x1) * 0.5
	var rw: float = 0.75
	# runner over each tread and riser, with a brass rod at the back of every tread; it runs on to the hall runner
	for k: int in steps:
		var za: float = lerpf(z_low, z_high, float(k) / float(steps))
		var zb: float = lerpf(z_low, z_high, float(k + 1) / float(steps))
		var yb: float = lerpf(0.0, rise, float(k + 1) / float(steps))
		var yn: float = lerpf(0.0, rise, float(k + 2) / float(steps))
		Props.block(g, Vector3(rc - rw, yb, zb + 0.012), Vector3(rc + rw, yb + 0.012, za + 0.022), "runner", false)
		if k < steps - 1:
			Props.block(g, Vector3(rc - rw, yb, zb), Vector3(rc + rw, yn, zb + 0.012), "runner", false)
		Props.cyl(g, Vector3(rc, yb + 0.014, zb + 0.03), 0.011, rw * 2.0 + 0.04, "brass", Vector3(0, 0, 90))
	Props.block(g, Vector3(rc - rw, UP_Y + 0.012, 8.6), Vector3(rc + rw, UP_Y + 0.024, z_high), "runner", false)
	Props.block(g, Vector3(rc - rw, 0.012, z_low), Vector3(rc + rw, 0.024, 15.7), "runner", false)   # the foot
	Props.block(g, Vector3(x1 + 0.3, 0.012, 14.2), Vector3(STAIR_X1 - 0.3, 0.024, 15.7), "rug", false)   # the doormat
	# newel posts: foot, stair head, the corner of the hall rail and its end at the east wall
	var nx: float = x1 - 0.05
	Props.newel(g, Vector3(nx, 0.0, z_low + 0.02), 1.05)
	Props.newel(g, Vector3(nx, rise, z_high), 1.05)
	Props.newel(g, Vector3(nx, rise, 9.95), 1.05)
	Props.newel(g, Vector3(STAIR_X1 - 0.22, rise, 9.95), 1.05)
	# turned balusters between the curb and the handrail (the rail bars are collision geometry)
	var n: int = int(slope_len / 0.18)
	for k2: int in n:
		var t: float = (float(k2) + 0.5) / float(n)
		Props.cyl(g, Vector3(nx, lerpf(0.0, rise, t) + 0.46, lerpf(z_low, z_high, t)), 0.018, 0.9, "furniture")
	for zz: float in [9.2, 9.4, 9.6, 9.8]:
		Props.cyl(g, Vector3(nx, rise + 0.46, zz), 0.018, 0.9, "furniture")
	var hx: float = nx + 0.2
	while hx < STAIR_X1 - 0.35:
		Props.cyl(g, Vector3(hx, rise + 0.46, 9.95), 0.018, 0.9, "furniture")
		hx += 0.18
	# the string and the panelled under-stair along the vestibule (the panels' tops hide behind the string)
	var mid_z: float = (z_low + z_high) * 0.5
	var mid_y: float = rise * 0.5
	Props.obox(g, Vector3(x1 + 0.01, mid_y - 0.05, mid_z), Vector3(0.05, 0.34, slope_len + 0.2), "beam", Vector3(ang, 0, 0))
	for k3: int in steps:
		var za2: float = lerpf(z_low, z_high, float(k3) / float(steps))
		var zb2: float = lerpf(z_low, z_high, float(k3 + 1) / float(steps))
		if zb2 < 10.15:
			break
		Props.block(g, Vector3(x1, 0.0, zb2), Vector3(x1 + 0.03, _stair_y(zb2) - 0.2, za2), "wainscot")
	Props.block(g, Vector3(x1, 0.0, 10.15), Vector3(x1 + 0.045, 0.14, z_low), "beam")
	# casing over the hall floor's edge and the wall end exposed at the stair head (only the heights that show)
	Props.block(g, Vector3(nx, 3.45, z_high), Vector3(x1 + 0.03, UP_Y, 10.15), "beam")
	Props.block(g, Vector3(nx, 2.95, 9.85), Vector3(x1 + 0.03, 3.45, 10.15), "beam")
	# wall rail on the west wall with iron brackets
	Props.strut(g, Vector3(0.24, 0.98, z_low), Vector3(0.24, rise + 0.98, z_high), 0.045, "furniture", true)
	for t2: float in [0.1, 0.4, 0.7, 0.95]:
		Props.block(g, Vector3(0.15, lerpf(0.0, rise, t2) + 0.9, lerpf(z_low, z_high, t2) - 0.02), Vector3(0.24, lerpf(0.0, rise, t2) + 0.94, lerpf(z_low, z_high, t2) + 0.02), "iron")
	# wainscot following the flight up the west wall, with a chair rail and skirting
	Props.obox(g, Vector3(0.165, mid_y + 0.57, mid_z), Vector3(0.03, 0.9, slope_len - 0.1), "wainscot_matte", Vector3(ang, 0, 0))
	Props.obox(g, Vector3(0.18, mid_y + 1.14, mid_z), Vector3(0.06, 0.07, slope_len - 0.1), "beam", Vector3(ang, 0, 0))
	Props.obox(g, Vector3(0.17, mid_y + 0.09, mid_z), Vector3(0.045, 0.14, slope_len - 0.1), "beam", Vector3(ang, 0, 0))
	# sconces: mid-flight on the west wall, and over the vestibule on the east wall
	Props.wall_lamp(g, Vector3(0.16, _stair_y(12.1) + 1.75, 12.1), -90.0)
	Props.wall_lamp(g, Vector3(STAIR_X1 - 0.16, 2.3, 12.9), 90.0)
	# pictures stepping up the west wall (yaw -90) and the well's east wall (yaw 90), one over the door
	var ex: float = STAIR_X1 - 0.16
	Props.painting(g, Vector3(0.16, _stair_y(13.5) + 1.65, 13.5), -90.0, 0.42, 0.55, "portrait", 0, "frame_walnut")
	Props.painting(g, Vector3(0.16, _stair_y(12.7) + 1.65, 12.7), -90.0, 0.7, 0.5, "landscape", 1, "frame_gold")
	Props.painting(g, Vector3(0.16, _stair_y(11.5) + 1.6, 11.5), -90.0, 0.4, 0.32, "photo", 0, "frame_black", 2.0, true)
	Props.painting(g, Vector3(0.16, _stair_y(10.6) + 1.7, 10.6), -90.0, 0.6, 0.45, "hunting", 1, "frame_walnut")
	Props.painting(g, Vector3(0.16, _stair_y(9.7) + 1.65, 9.7), -90.0, 0.4, 0.5, "portrait", 1, "frame_gold", -1.5)
	Props.painting(g, Vector3(ex, 1.75, 11.3), 90.0, 0.55, 0.42, "licence", 0, "frame_black")
	Props.painting(g, Vector3(ex, 3.2, 12.0), 90.0, 0.7, 0.5, "landscape", 0, "frame_walnut")
	Props.painting(g, Vector3(ex, 4.45, 11.4), 90.0, 0.42, 0.55, "portrait", 2, "frame_gold", 1.0)
	Props.painting(g, Vector3(ex, 3.35, 13.4), 90.0, 0.4, 0.32, "photo", 1, "frame_black", 0.0, true)
	Props.painting(g, Vector3(ex, 3.3, 15.1), 90.0, 0.55, 0.4, "stilllife", 1, "frame_gold")   # over the door
	# the vestibule: a coat rack in its north-east corner, cobwebs high in the well
	Props.coat_rack(g, Vector3(STAIR_X1 - 0.45, 0, 10.5))
	Props.cobweb(g, Vector3(STAIR_X1 - 0.15, UP_TOP - 0.01, 15.85), 180.0, 0.9)
	Props.cobweb(g, Vector3(0.15, UP_TOP - 0.01, 15.85), 90.0, 0.7)


## The Helvetia cellar: stone ribs and corbels under the brick soffit, pillar plinths, puddles, a drain, the
## installers' workbench and crates with the fuse box and conduit to the lever and the bulbs, barrels, sacks,
## shelves of preserves between the machines, a wine rack, the coal chute and heap, pipes, cobwebs, lanterns.
## Nothing here blocks a machine front, the panels behind them, the stair spill or the pillar loops; the north
## face of the north pillar stays bare for a story item.
func _dress_cellar() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var g: Node3D = Props.group(dress, "Cellar", Vector3.ZERO)
	_cellar_lit = Node3D.new()
	_cellar_lit.name = "CellarLit"
	dress.add_child(_cellar_lit)
	# ---- the vault: segmental stone ribs between the walls and the pillars (two across, one along), corbels
	var spring: float = cy + 2.05
	var crown: float = top - 0.1
	for rz: float in [23.0, 27.0]:
		_arch(g, Vector3(24.15, spring, rz), Vector3(29.65, spring, rz), crown - spring)
		_arch(g, Vector3(30.35, spring, rz), Vector3(35.85, spring, rz), crown - spring)
	_arch(g, Vector3(30.0, spring, 23.35), Vector3(30.0, spring, 26.65), crown - spring)   # (none north of the pillar: the Crucible's alcove)
	_arch(g, Vector3(30.0, spring, 27.35), Vector3(30.0, spring, 30.85), crown - spring)
	for p: Vector2 in [Vector2(30.0, 23.0), Vector2(30.0, 27.0)]:
		Props.block(g, Vector3(p.x - 0.44, cy, p.y - 0.44), Vector3(p.x + 0.44, cy + 0.42, p.y + 0.44), "cellar_stone")
		Props.block(g, Vector3(p.x - 0.4, cy + 0.42, p.y - 0.4), Vector3(p.x + 0.4, cy + 0.5, p.y + 0.4), "cellar_stone")
		Props.block(g, Vector3(p.x - 0.46, spring - 0.3, p.y - 0.46), Vector3(p.x + 0.46, spring, p.y + 0.46), "cellar_stone")
	# ---- floor: puddles, a drain in the SW corner, flag edges
	Props.puddle(g, Vector3(25.9, cy, 20.7), 1.6, 1.0, 20.0)
	Props.puddle(g, Vector3(30.1, cy, 25.0), 1.2, 0.8, -15.0)
	Props.puddle(g, Vector3(27.4, cy, 30.0), 1.1, 0.7, 40.0)
	Props.puddle(g, Vector3(34.6, cy, 29.0), 0.9, 0.6, 0.0)
	Props.block(g, Vector3(25.3, cy + 0.002, 29.6), Vector3(25.9, cy + 0.012, 30.2), "iron")
	for i: int in 4:
		Props.block(g, Vector3(25.36 + i * 0.14, cy + 0.012, 29.66), Vector3(25.42 + i * 0.14, cy + 0.016, 30.14), "char")
	# ---- north wall: the Crucible's alcove (T-032) between the stair mouth and the lever, then the installers'
	# crates under the fuse box, conduit to the lever and up to the bulbs
	_crucible_setting(g)
	Props.crate(g, Vector3(31.2, cy, 19.46), 0.6, 180.0)
	Props.crate(g, Vector3(31.22, cy + 0.6, 19.48), 0.5, 172.0)
	Props.stencil(g, Vector3(31.2, cy + 0.36, 19.77), 180.0, "HELVETIA\nAUTOMATEN AG", 30, Color(0.85, 0.82, 0.7, 0.75), 0.0017)
	Props.stencil(g, Vector3(31.22, cy + 0.86, 19.74), 172.0, "ZERBRECHLICH", 30, Color(0.7, 0.2, 0.15, 0.8), 0.0016)
	Props.fuse_box(g, Vector3(31.2, cy + 1.95, 19.15), 180.0, 0.5, 0.7)
	Props.stencil(g, Vector3(31.2, cy + 2.62, 19.15), 180.0, "HELVETIA AUTOMATEN AG\nMONTAGE 7 · XI/44", 26, Color(0.8, 0.78, 0.68, 0.7), 0.0024)
	Props.pipe(g, Vector3(31.2, cy + 2.3, 19.25), Vector3(31.2, top - 0.08, 19.25), 0.02)
	Props.pipe(g, Vector3(31.45, cy + 1.95, 19.25), Vector3(32.5, cy + 1.95, 19.25), 0.02)
	Props.pipe(g, Vector3(32.5, cy + 1.95, 19.25), Vector3(32.5, cy + 2.15, 19.3), 0.02)
	var cl: float = top - 0.08
	Props.cable(g, Vector3(31.2, cl, 19.3), Vector3(31.0, cl, 22.5), 0.05, 0.015, 6)
	Props.cable(g, Vector3(31.0, cl, 22.5), Vector3(27.0, cl, 22.5), 0.06, 0.015, 8)
	Props.cable(g, Vector3(31.0, cl, 22.5), Vector3(33.0, cl, 22.5), 0.04, 0.015, 5)
	Props.cable(g, Vector3(27.0, cl, 22.5), Vector3(26.5, cl, 27.5), 0.06, 0.015, 8)
	Props.cable(g, Vector3(33.0, cl, 22.5), Vector3(33.5, cl, 27.5), 0.06, 0.015, 8)
	Props.cable(g, Vector3(33.5, cl, 27.5), Vector3(30.35, cl, 28.7), 0.05, 0.015, 7)   # to the ninth machine's bulb
	for bp: Vector3 in CELLAR_BULBS:
		Props.pendant(g, bp, top - 0.02, _cellar_lit, "tin")
	Props.bake(_cellar_lit)
	for lit: Node in _cellar_lit.get_children():
		lit.set_meta("keep", true)
	# ---- NE corner: the installers' workbench, a barrel and a sack; a tally chalked on the wall above
	Props.workbench(g, Vector3(35.15, cy, 19.5), 180.0, 1.5, 0.7)
	_lib_barrel(Vector3(35.5, cy, 20.4), -40.0, 0.3, 0.85)
	Props.sack(g, Vector3(34.65, cy, 20.45), -30.0, 0.8)
	_lib_barrel(Vector3(33.75, cy, 20.3), 15.0, 0.32, 0.9)   # over the corner's collider (T-051)
	Props.crate(g, Vector3(33.8, cy, 19.62), 0.6, 4.0, "HELVETIA")
	Props.stencil(g, Vector3(35.2, cy + 1.9, 19.15), 180.0, "|||| |||| ||| ", 30, Color(0.85, 0.85, 0.8, 0.55), 0.004)
	# ---- shelves of preserves and bottles between the machines (0.28 m deep, so the panel walk stays clear)
	Props.shelves(g, Vector3(24.15, cy, 24.5), -90.0, 1.4, 1.9, 0.28, 3, 11)
	Props.shelves(g, Vector3(24.15, cy, 27.15), -90.0, 1.5, 1.6, 0.28, 3, 12)
	Props.shelves(g, Vector3(35.85, cy, 23.15), 90.0, 1.4, 1.9, 0.28, 3, 13)
	Props.shelves(g, Vector3(35.85, cy, 26.1), 90.0, 1.5, 1.7, 0.28, 3, 14)
	# ---- south wall, west half: a wine rack (bottles lying with their necks out)
	var wr: Node3D = Props.group(g, "WineRack", Vector3(25.85, cy, 30.85), 0.0)
	Props.block(wr, Vector3(-1.45, 0, -0.34), Vector3(-1.4, 1.5, 0.0), "planks")
	Props.block(wr, Vector3(1.4, 0, -0.34), Vector3(1.45, 1.5, 0.0), "planks")
	var rrng: RandomNumberGenerator = RandomNumberGenerator.new()
	rrng.seed = 31
	for row: int in 5:
		var ry: float = 0.22 + row * 0.26
		Props.block(wr, Vector3(-1.45, ry - 0.02, -0.34), Vector3(1.45, ry, 0.0), "furniture")
		for col: int in 28:
			if rrng.randf() < 0.3:
				continue
			var bx: float = -1.35 + col * 0.1
			var key: String = "bottle_green" if rrng.randf() < 0.7 else "bottle_amber"
			Props.cyl(wr, Vector3(bx, ry + 0.045, -0.2), 0.035, 0.3, key, Vector3(90, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ---- SE corner: the coal chute, the heap and a shovel
	Props.ball(g, Vector3(35.2, cy, 30.15), Vector3(2.2, 0.8, 2.0), "coal")
	var crng: RandomNumberGenerator = RandomNumberGenerator.new()
	crng.seed = 44
	for i2: int in 9:
		Props.ball(g, Vector3(34.3 + crng.randf_range(0, 1.5), cy + 0.04, 29.1 + crng.randf_range(0, 1.7)), Vector3(0.16, 0.1, 0.14) * crng.randf_range(0.7, 1.4), "coal")
	Props.obox(g, Vector3(35.35, cy + 1.9, 30.1), Vector3(1.5, 0.06, 0.6), "iron", Vector3(0, 0, 52))
	for sz: float in [-0.3, 0.3]:
		Props.obox(g, Vector3(35.35, cy + 1.95, 30.1 + sz), Vector3(1.5, 0.16, 0.03), "iron", Vector3(0, 0, 52))
	Props.block(g, Vector3(35.78, cy + 2.2, 29.65), Vector3(35.86, cy + 2.95, 30.55), "beam")
	Props.block(g, Vector3(35.8, cy + 2.26, 29.72), Vector3(35.86, cy + 2.9, 30.48), "window_dark")
	Props.obox(g, Vector3(35.6, cy + 0.6, 28.75), Vector3(0.035, 1.3, 0.035), "beam", Vector3(0, 0, -14))
	Props.obox(g, Vector3(35.45, cy + 0.05, 28.75), Vector3(0.22, 0.02, 0.26), "iron", Vector3(0, 0, -14))
	# ---- pipes along the top of the long walls, and the lanterns that are always lit
	Props.pipe(g, Vector3(24.22, cy + 2.7, 19.3), Vector3(24.22, cy + 2.7, 30.8), 0.035, "iron")
	Props.pipe(g, Vector3(24.22, cy + 2.7, 25.0), Vector3(24.22, cy + 1.3, 25.0), 0.03, "iron")
	Props.cyl(g, Vector3(24.3, cy + 1.3, 25.0), 0.04, 0.1, "brass", Vector3(0, 0, 90))
	Props.pipe(g, Vector3(35.78, cy + 2.75, 19.3), Vector3(35.78, cy + 2.75, 28.6), 0.035, "rust")
	Props.lantern(g, Vector3(26.0, cy + 2.2, 19.6), top - 0.02)
	Props.wall_lamp(g, Vector3(26.0, 2.45, 10.15), 180.0)
	# ---- cobwebs in the corners
	Props.cobweb(g, Vector3(24.15, top - 0.02, 30.85), 90.0, 0.9)
	Props.cobweb(g, Vector3(35.85, top - 0.02, 30.85), 180.0, 0.8)
	Props.cobweb(g, Vector3(35.85, top - 0.02, 19.15), -90.0, 0.8)
	Props.cobweb(g, Vector3(24.15, 2.98, 10.15), 0.0, 0.7)
	# ---- the stair hall: kegs on the landing corner, a wall rail, "KELLER" over the steps
	_lib_barrel(Vector3(27.55, 0.0, 10.55), 30.0, 0.25, 0.62)
	_lib_barrel(Vector3(27.35, 0.0, 10.4), 90.0, 0.17, 0.5, true)
	Props.sack(g, Vector3(27.3, 0.0, 10.85), 10.0, 0.7)
	Props.strut(g, Vector3(24.24, 0.95, 13.0), Vector3(24.24, cy + 0.95, 19.0), 0.04, "iron", true)
	for t3: float in [0.05, 0.5, 0.95]:
		var hz: float = lerpf(13.0, 19.0, t3)
		var hy: float = lerpf(0.0, cy, t3) + 0.9
		Props.block(g, Vector3(24.15, hy - 0.02, hz - 0.02), Vector3(24.24, hy + 0.02, hz + 0.02), "iron")
	Props.stencil(g, Vector3(27.85, 2.2, 12.2), 90.0, "KELLER", 44, Color(0.2, 0.18, 0.15, 0.85), 0.004)
	_dress_old_cellar()


## A wine rack against a wall (local z 0 = the wall, the room at local -Z): uprights, slatted boards and bottles
## lying with their necks out; a gap left here and there.
func _wine_rack(parent: Node3D, pos: Vector3, yaw: float, w: float, rows: int, seed_v: int, depth: float = 0.4) -> void:
	var g: Node3D = Props.group(parent, "WineRack", pos, yaw)
	var n_up: int = maxi(2, int(w / 1.2) + 1)
	for k: int in n_up:
		var x: float = -w * 0.5 + w * float(k) / float(n_up - 1)
		Props.block(g, Vector3(x - 0.03, 0, -depth), Vector3(x + 0.03, 0.3 + rows * 0.26, 0.0), "beam")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for row: int in rows:
		var ry: float = 0.22 + row * 0.26
		Props.block(g, Vector3(-w * 0.5, ry - 0.02, -depth), Vector3(w * 0.5, ry, 0.0), "furniture")
		var cols: int = int(w / 0.1)
		for col: int in cols:
			if rng.randf() < 0.28:
				continue
			var bx: float = -w * 0.5 + 0.06 + col * 0.1
			var key: String = "bottle_green" if rng.randf() < 0.72 else "bottle_amber"
			Props.cyl(g, Vector3(bx, ry + 0.045, -depth * 0.55), 0.035, depth * 0.8, key, Vector3(90, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A child's chalk stick figure on a wall (local -Z = out of the wall): head ring, body, arms out to the sides
## (so neighbours hold hands), two legs. `h` is its height.
func _chalk_figure(parent: Node3D, base: Vector3, yaw: float, h: float) -> void:
	var g: Node3D = Props.group(parent, "Chalk", base, yaw)
	var wd: float = 0.012
	Props._noshadow(Props.cyl(g, Vector3(0, h * 0.86, -0.004), h * 0.11, 0.004, "paper", Vector3(90, 0, 0)))
	Props._noshadow(Props.cyl(g, Vector3(0, h * 0.86, -0.006), h * 0.085, 0.004, "brick_cellar", Vector3(90, 0, 0)))
	Props._noshadow(Props.obox(g, Vector3(0, h * 0.5, -0.004), Vector3(wd, h * 0.42, 0.004), "paper"))
	Props._noshadow(Props.obox(g, Vector3(0, h * 0.62, -0.004), Vector3(h * 0.62, wd, 0.004), "paper", Vector3(0, 0, -6)))
	for s: float in [-1.0, 1.0]:
		Props._noshadow(Props.obox(g, Vector3(s * h * 0.09, h * 0.15, -0.004), Vector3(wd, h * 0.32, 0.004), "paper", Vector3(0, 0, s * 18.0)))


## The Old Cellar's dressing (no collision; the colliders are in build_old_cellar): the lean-to stairs, the wine
## cellar's arches and racks, the coal room with the cage, the root cellar's stores, the cousins' ice cellar, the
## barrel vault and the breach, the light wells outside.
func _dress_old_cellar() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var wy: float = OC_WELL_Y
	var g: Node3D = Props.group(dress, "OldCellar", Vector3.ZERO)
	_old_cellar_lit = Node3D.new()
	_old_cellar_lit.name = "OldCellarLit"
	dress.add_child(_old_cellar_lit)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1251
	# ---------------- the lean-to: Door 5's frame, a snowed roof, a lantern over the flight, a lamp at the foot
	_door_frame(Vector3(0.0, 0, 9.05), 90.0, 1.6, DOOR_H)
	Props.block(g, Vector3(OC_ANNEX_X - 0.2, 3.0, 7.75), Vector3(0.05, 3.1, 18.75), "snow")
	Props.block(g, Vector3(OC_ANNEX_X - 0.25, 2.75, 7.7), Vector3(0.05, 2.82, 18.8), "beam")
	Props.snow_drift(g, Vector3(OC_ANNEX_X - 0.4, 0, 13.0), Vector3(1.2, 0.7, 9.0))
	# its outside above the ground: weatherboards over the stone, a sill beam, corner posts
	Props.block(g, Vector3(OC_ANNEX_X - 0.19, 0.0, 7.83), Vector3(OC_ANNEX_X - 0.15, 2.8, 18.67), "planks")
	for ez: Array in [[7.83, 7.85], [18.65, 18.67]]:
		Props.block(g, Vector3(OC_ANNEX_X - 0.19, 0.0, float(ez[0]) - (0.04 if ez[0] < 10.0 else 0.0)), Vector3(0.0, 2.8, float(ez[1]) + (0.04 if ez[0] > 10.0 else 0.0)), "planks")
	Props.block(g, Vector3(OC_ANNEX_X - 0.24, 0.0, 7.8), Vector3(OC_ANNEX_X - 0.15, 0.25, 18.7), "beam")
	for pz: float in [7.8, 13.25, 18.7]:
		Props.block(g, Vector3(OC_ANNEX_X - 0.26, 0.0, pz - 0.1), Vector3(OC_ANNEX_X - 0.12, 2.8, pz + 0.1), "beam")
	Props.lantern(g, Vector3(-1.5, 2.15, 12.6), 2.8)
	Props.wall_lamp(g, Vector3(OC_ANNEX_X + 0.15, cy + 2.2, 17.0), -90.0)
	Props.stencil(g, Vector3(OC_ANNEX_X + 0.16, 1.7, 9.0), -90.0, "VORSICHT\nSTUFEN", 34, Color(0.88, 0.85, 0.75, 0.7), 0.004)
	Props.crate(g, Vector3(-2.4, cy, 18.0), 0.55, 12.0)
	for i: int in 5:
		Props.cyl(g, Vector3(-2.55 + i * 0.09, cy + 0.6, 18.0), 0.035, 0.28, "bottle_green")
	Props.cobweb(g, Vector3(OC_ANNEX_X + 0.15, 2.78, 8.15), 0.0, 0.7)
	Props.cobweb(g, Vector3(-0.15, top - 0.02, 18.35), 180.0, 0.7)
	# ---------------- the wine cellar: low brick arches on three piers, racks on three walls, casks, puddles
	var spring: float = cy + 1.55
	var crown: float = top - 0.05
	for p: Vector2 in OC_PIERS:
		_arch(g, Vector3(p.x, spring, 8.15), Vector3(p.x, spring, p.y - 0.35), crown - spring)
		_arch(g, Vector3(p.x, spring, p.y + 0.35), Vector3(p.x, spring, 18.35), crown - spring)
		Props.block(g, Vector3(p.x - 0.43, cy, p.y - 0.43), Vector3(p.x + 0.43, cy + 0.38, p.y + 0.43), "cellar_stone")
		Props.block(g, Vector3(p.x - 0.45, spring - 0.28, p.y - 0.45), Vector3(p.x + 0.45, spring, p.y + 0.45), "cellar_stone")
		Props.cyl(g, Vector3(p.x + 0.38, spring + 0.04, p.y - 0.2), 0.03, 0.08, "candle")   # a stub on the capital
	for seg: Array in [[0.15, OC_PIERS[0].x - 0.35], [OC_PIERS[0].x + 0.35, OC_PIERS[1].x - 0.35], [OC_PIERS[1].x + 0.35, OC_PIERS[2].x - 0.35],
			[OC_PIERS[2].x + 0.35, 10.75]]:
		_arch(g, Vector3(float(seg[0]), spring, 13.2), Vector3(float(seg[1]), spring, 13.2), crown - spring, 6)
	Props.block(g, Vector3(0.15, top - 0.03, 8.15), Vector3(10.75, top, 18.35), "brick_cellar")   # a brick soffit
	_wine_rack(g, Vector3(1.375, cy, 8.15), 180.0, 2.4, 6, 51)
	_wine_rack(g, Vector3(6.65, cy, 8.15), 180.0, 3.6, 6, 52)
	_wine_rack(g, Vector3(6.3, cy, 18.35), 0.0, 6.5, 6, 53)
	_wine_rack(g, Vector3(0.15, cy, 10.6), -90.0, 3.1, 6, 54)
	_wine_rack(g, Vector3(0.15, cy, 13.95), -90.0, 2.8, 6, 55)
	for i: int in 3:   # the big casks on their cradles, heads to the room, vintages chalked on
		var cz: float = 14.6 + i * 1.3
		for sz: float in [-0.35, 0.35]:
			Props.block(g, Vector3(9.9, cy, cz + sz - 0.06), Vector3(10.72, cy + 0.32, cz + sz + 0.06), "beam")
		_lib_barrel(Vector3(10.3, cy + 0.12, cz), 90.0, 0.55, 0.82, true)
		Props.stencil(g, Vector3(9.87, cy + 0.67, cz), 90.0, ["1937", "1941", "1943"][i], 40, Color(0.92, 0.9, 0.85, 0.75), 0.004)
		Props.cyl(g, Vector3(9.84, cy + 0.32, cz), 0.03, 0.08, "brass", Vector3(0, 0, 90))   # the tap
	_lib_barrel(Vector3(9.6, cy, 17.85), 20.0, 0.25, 0.6)
	_lib_barrel(Vector3(0.55, cy, 17.9), -10.0, 0.25, 0.6)
	Props.crate(g, Vector3(1.0, cy, 9.05), 0.5, 8.0)
	Props.stencil(g, Vector3(10.73, cy + 1.9, 15.9), 90.0, "RIESLING 38  ·  40 FL.\nROTWEIN 41  ·  22 FL.\nSCHNAPS  ·  —", 28, Color(0.9, 0.9, 0.85, 0.55), 0.0035)
	Props.puddle(g, Vector3(6.9, cy, 15.3), 1.2, 0.8, 15.0)
	Props.puddle(g, Vector3(1.7, cy, 11.4), 0.9, 0.7, -20.0)
	Props.puddle(g, Vector3(4.4, cy, 17.0), 0.8, 0.5, 40.0)
	for c: Array in [[Vector3(0.15, top - 0.02, 8.15), 0.0], [Vector3(10.75, top - 0.02, 18.35), 180.0], [Vector3(0.15, top - 0.02, 18.35), 90.0]]:
		Props.cobweb(g, c[0], float(c[1]), 0.8)
	# ---------------- the coal room: the chute heap under the window, soot, the cage, the patrol's leftovers
	Props.ball(g, Vector3(3.55, cy, 0.95), Vector3(2.3, 0.75, 1.5), "coal")
	for i2: int in 12:
		Props.ball(g, Vector3(2.6 + rng.randf_range(0, 2.0), cy + 0.04, 1.6 + rng.randf_range(0, 1.3)), Vector3(0.15, 0.1, 0.13) * rng.randf_range(0.7, 1.4), "coal")
	Props.obox(g, Vector3(3.45, wy + OC_SILL - 0.63, 0.58), Vector3(1.3, 0.04, 1.55), "iron", Vector3(56, 0, 0))   # the chute plate
	Props.block(g, Vector3(0.15, cy + 0.6, 0.15), Vector3(4.85, top, 0.17), "char")   # soot up the chute wall
	Props.block(g, Vector3(4.83, cy, 0.15), Vector3(4.85, cy + 2.2, 3.2), "char")
	# the cage: round bars floor to ceiling on the three open sides, bands, corner posts (the door is HoldingCage)
	var cg: Rect2 = OC_CAGE
	var bars: Array = [[Vector2(cg.position.x + 0.05, cg.position.y), Vector2(cg.end.x, cg.position.y)],
		[Vector2(cg.position.x + 0.05, cg.end.y), Vector2(cg.end.x, cg.end.y)],
		[Vector2(cg.end.x, cg.position.y), Vector2(cg.end.x, OC_CAGE_DOOR.x)], [Vector2(cg.end.x, OC_CAGE_DOOR.y), Vector2(cg.end.x, cg.end.y)]]
	for b: Array in bars:
		var a2: Vector2 = b[0]
		var b2: Vector2 = b[1]
		var n: int = maxi(1, int(a2.distance_to(b2) / 0.13))
		for k: int in n + 1:
			var q: Vector2 = a2.lerp(b2, float(k) / float(n))
			Props.cyl(g, Vector3(q.x, (cy + top) * 0.5, q.y), 0.022, top - cy, "iron")
		for by: float in [cy + 0.12, cy + 1.05, top - 0.12]:
			Props.strut(g, Vector3(a2.x, by, a2.y), Vector3(b2.x, by, b2.y), 0.05, "iron")
	for cp: Vector2 in [Vector2(cg.end.x, cg.position.y), Vector2(cg.end.x, cg.end.y), Vector2(cg.end.x, OC_CAGE_DOOR.x), Vector2(cg.end.x, OC_CAGE_DOOR.y)]:
		Props.block(g, Vector3(cp.x - 0.04, cy, cp.y - 0.04), Vector3(cp.x + 0.04, top, cp.y + 0.04), "iron")
	# inside: straw, a folded blanket, a tin cup and a bucket, a miner's greeting and a tally chalked on the wall
	Props.obox(g, Vector3(1.0, cy + 0.015, 5.3), Vector3(1.3, 0.03, 1.6), "straw_floor", Vector3(0, 8, 0))
	Props.block(g, Vector3(0.3, cy, 5.6), Vector3(0.95, cy + 0.12, 6.3), "tarp")
	Props.cyl(g, Vector3(1.9, cy + 0.05, 6.1), 0.045, 0.1, "tin")
	Props.cyl(g, Vector3(0.45, cy + 0.17, 3.7), 0.15, 0.34, "iron")
	Props.stencil(g, Vector3(0.16, cy + 1.45, 4.6), -90.0, "SZCZESC BOZE", 30, Color(0.92, 0.92, 0.88, 0.6), 0.0035)
	Props.stencil(g, Vector3(0.16, cy + 1.1, 5.9), -90.0, "| |", 34, Color(0.92, 0.92, 0.88, 0.55), 0.0035)
	# outside: the guard's stool and crate with a mess tin and his cigarettes, the tag on the padlock, the lantern
	_lib("stool_workshop", Vector3(4.2, cy, 5.1), 15.0, Vector3.ONE, false)
	Props.crate(g, Vector3(4.3, cy, 7.25), 0.55, -8.0, "WH")
	Props.cyl(g, Vector3(4.25, cy + 0.6, 7.2), 0.09, 0.05, "steel")
	Props.block(g, Vector3(4.4, cy + 0.55, 7.05), Vector3(4.5, cy + 0.57, 7.12), "paper")
	Props.stencil(g, Vector3(2.62, cy + 0.82, 5.45), -90.0, "Häftling (Pole)\nFlucht aus K.\n22.XII.", 20, Color(0.22, 0.2, 0.18, 0.9), 0.0028)
	Props.block(g, Vector3(2.61, cy + 0.68, 5.32), Vector3(2.615, cy + 0.94, 5.6), "paper")
	Props.lantern(g, Vector3(3.9, cy + 2.25, 3.9), top)
	Props.cobweb(g, Vector3(0.15, top - 0.02, 0.15), 0.0, 0.8)
	Props.cobweb(g, Vector3(4.85, top - 0.02, 7.85), 180.0, 0.6)
	# ---------------- the root cellar: preserves and the top shelf, sacks and potatoes, hams and onions overhead
	Props.shelves(g, Vector3(7.95, cy, 0.15), 180.0, 5.1, 2.1, 0.4, 4, 61)
	Props.shelves(g, Vector3(5.15, cy, 2.65), -90.0, 3.7, 1.9, 0.35, 3, 62)
	Props.block(g, Vector3(5.5, cy + 2.45, 0.15), Vector3(7.2, cy + 2.48, 0.42), "furniture")   # the top shelf
	for bk: float in [5.55, 7.15]:
		Props.block(g, Vector3(bk - 0.02, cy + 2.3, 0.15), Vector3(bk + 0.02, cy + 2.45, 0.4), "iron")
	for j: int in 3:   # the cousins' jam jars (v3 section 4.1: the youngest was always stretching for them)
		var jx: float = 5.85 + j * 0.42
		Props.cyl(g, Vector3(jx, cy + 2.6, 0.29), 0.07, 0.22, "jar_red")
		Props.cyl(g, Vector3(jx, cy + 2.72, 0.29), 0.085, 0.02, ["cloth_red", "linen", "cloth_green"][j])
		Props.block(g, Vector3(jx - 0.05, cy + 2.55, 0.215), Vector3(jx + 0.05, cy + 2.63, 0.22), "paper")
	Props.crate(g, Vector3(6.4, cy, 0.95), 0.45, 4.0)   # ...and the crate to stand on
	for sk: Array in [[Vector3(5.6, cy, 4.55), 10.0], [Vector3(6.2, cy, 4.6), -20.0], [Vector3(6.8, cy, 4.5), 35.0], [Vector3(7.45, cy, 4.6), 0.0],
			[Vector3(5.9, cy + 0.5, 4.6), 70.0], [Vector3(7.0, cy + 0.5, 4.55), -40.0]]:
		Props.sack(g, sk[0], float(sk[1]), 0.95)
	for i3: int in 10:
		Props.ball(g, Vector3(6.3 + rng.randf_range(-0.8, 1.4), cy + 0.05, 4.05 + rng.randf_range(-0.3, 0.1)), Vector3(0.09, 0.07, 0.08), "dirt")
	Props.cyl(g, Vector3(8.2, top - 0.15, 2.4), 0.035, 4.6, "beam", Vector3(0, 0, 90))   # the meat pole
	for hx: float in [6.3, 7.0, 7.9, 8.8, 9.6]:
		Props._noshadow(Props.block(g, Vector3(hx - 0.006, cy + 2.15, 2.394), Vector3(hx + 0.006, top - 0.15, 2.406), "rope"))
		Props.ball(g, Vector3(hx, cy + 1.95, 2.4), Vector3(0.24, 0.44, 0.2), "wood_red")
		Props.ball(g, Vector3(hx, cy + 2.15, 2.4), Vector3(0.1, 0.1, 0.1), "linen")
	for oz: float in [5.3, 5.6]:   # onion strings on the east wall
		for oy: int in 6:
			Props.ball(g, Vector3(10.66, cy + 1.2 + oy * 0.1, oz), Vector3(0.08, 0.07, 0.08), "paper_old")
	Props.cobweb(g, Vector3(10.75, top - 0.02, 0.15), 270.0, 0.8)
	Props.puddle(g, Vector3(9.5, cy, 3.3), 0.7, 0.5, 10.0)
	# ---------------- the ice cellar: three straw pallets, the upturned crate with the letter and the lantern burnt
	# dry, a jam jar, red-grey mittens, the ladder to the trapdoor, three chalk girls holding hands and the aunt
	for px: float in [5.6, 6.32, 7.04]:
		Props.block(g, Vector3(px - 0.32, cy, 6.2), Vector3(px + 0.32, cy + 0.1, 7.8), "hay")
		Props.block(g, Vector3(px - 0.3, cy + 0.1, 6.9), Vector3(px + 0.3, cy + 0.14, 7.75), "linen")
	Props.block(g, Vector3(5.42, cy + 0.14, 6.95), Vector3(5.55, cy + 0.17, 7.15), "cloth_red")   # the mittens
	Props.block(g, Vector3(5.58, cy + 0.14, 7.0), Vector3(5.71, cy + 0.17, 7.2), "tarp")
	var ic: Node3D = Props.group(g, "UpturnedCrate", Vector3(7.75, cy, 7.4), 6.0)
	Props.block(ic, Vector3(-0.3, 0, -0.3), Vector3(0.3, 0.4, 0.3), "planks")
	Props.block(g, Vector3(7.5, cy + 0.4, 7.25), Vector3(7.68, cy + 0.405, 7.5), "paper")   # the letter
	Props.block(g, Vector3(7.82, cy + 0.4, 7.25), Vector3(7.98, cy + 0.42, 7.41), "iron")   # the lantern, burnt dry
	Props.block(g, Vector3(7.84, cy + 0.42, 7.27), Vector3(7.96, cy + 0.6, 7.39), "char")
	Props.cyl(g, Vector3(7.95, cy + 0.47, 7.6), 0.05, 0.12, "jar_red")
	Props.ladder(g, Vector3(6.6, cy, 5.15), 180.0, top - cy, "beam")
	var hz: Vector3 = Vector3(6.6, top - 0.005, 5.6)
	for e: Array in [[Vector3(-0.5, -0.06, -0.5), Vector3(0.5, 0, -0.42)], [Vector3(-0.5, -0.06, 0.42), Vector3(0.5, 0, 0.5)],
			[Vector3(-0.5, -0.06, -0.42), Vector3(-0.42, 0, 0.42)], [Vector3(0.42, -0.06, -0.42), Vector3(0.5, 0, 0.42)]]:
		Props.block(g, hz + (e[0] as Vector3), hz + (e[1] as Vector3), "beam")
	Props.block(g, hz + Vector3(-0.42, -0.03, -0.42), hz + Vector3(0.42, 0, 0.42), "window_dark")
	for k2: int in 3:
		_chalk_figure(g, Vector3(8.14, cy + 0.8, 6.0 + k2 * 0.3), 90.0, 0.5)
	_chalk_figure(g, Vector3(8.14, cy + 0.75, 7.6), 90.0, 0.75)
	Props.stencil(g, Vector3(6.6, cy + 2.55, 5.16), 180.0, "EIS", 40, Color(0.75, 0.75, 0.72, 0.4), 0.004)
	Props.puddle(g, Vector3(6.4, cy, 5.9), 0.6, 0.45, 0.0)
	Props.cobweb(g, Vector3(8.15, top - 0.02, 7.85), 180.0, 0.6)
	# ---------------- the barrel vault: joists and summer beams, the pillars, the barrel stack, racks, the breach
	for x: float in [11.6, 12.8, 14.0, 15.2, 16.4, 17.6, 18.8, 20.0, 21.2, 22.4, 23.6]:
		Props.block(g, Vector3(x - 0.07, top - 0.17, 0.15), Vector3(x + 0.07, top, 15.85), "beam")
	for bz: float in [2.7, 13.3]:
		Props.block(g, Vector3(11.05, top - 0.36, bz - 0.17), Vector3(23.85, top - 0.17, bz + 0.17), "beam")
	for x2: float in [1.2, 2.4, 3.6, 4.8, 6.0, 7.2, 8.4, 9.6]:   # the root and coal rooms' joists too
		Props.block(g, Vector3(x2 - 0.06, top - 0.14, 0.15), Vector3(x2 + 0.06, top, 4.85 if x2 > 5.0 and x2 < 8.3 else 7.85), "beam")
	for p3: Vector2 in OC_PILLARS:
		Props.block(g, Vector3(p3.x - 0.44, cy, p3.y - 0.44), Vector3(p3.x + 0.44, cy + 0.4, p3.y + 0.44), "cellar_stone")
		Props.block(g, Vector3(p3.x - 0.42, top - 0.5, p3.y - 0.42), Vector3(p3.x + 0.42, top - 0.36, p3.y + 0.42), "cellar_stone")
	var st: Rect2 = OC_STACK
	var sx: float = st.get_center().x
	for row: Array in [[0.0, [6.95, 8.0, 9.05], 0.52], [0.93, [7.47, 8.52], 0.52], [1.72, [8.0], 0.48]]:   # [lift, z centres, r]
		for zc: float in row[1]:
			for side: float in [-0.78, 0.78]:
				_lib_barrel(Vector3(sx + side, cy + float(row[0]), zc), 90.0, float(row[2]), 1.45, true)
	for cz2: float in [6.5, 9.5]:   # the cradles
		Props.block(g, Vector3(st.position.x + 0.1, cy, cz2 - 0.08), Vector3(st.end.x - 0.1, cy + 0.2, cz2 + 0.08), "beam")
	Props.stencil(g, Vector3(sx - 1.56, cy + 0.6, 8.0), 90.0, "KREUZWEG\nHAUSWEIN", 32, Color(0.92, 0.9, 0.85, 0.65), 0.004)
	Props.stencil(g, Vector3(sx + 1.56, cy + 0.6, 8.0), -90.0, "1942", 40, Color(0.92, 0.9, 0.85, 0.65), 0.004)
	for kb: Vector3 in [Vector3(15.55, cy, 6.1), Vector3(19.35, cy, 9.9), Vector3(19.4, cy, 6.15)]:
		_lib_barrel(kb, rng.randf_range(0, 90), 0.24, 0.55)
	Props.lantern(g, Vector3(13.4, cy + 2.35, 8.0), top - 0.17)
	Props.lantern(g, Vector3(21.6, cy + 2.35, 8.0), top - 0.17)
	for bp: Vector3 in OC_BULBS:
		Props.pendant(g, bp, top - 0.02, _old_cellar_lit, "tin")
	Props.bake(_old_cellar_lit)
	for lit: Node in _old_cellar_lit.get_children():
		lit.set_meta("keep", true)
	_wine_rack(g, Vector3(23.85, cy, 7.0), 90.0, 5.2, 6, 56)
	_wine_rack(g, Vector3(17.45, cy, 15.85), 0.0, 3.7, 6, 57)
	Props.block(g, Vector3(11.05, cy + 0.5, 0.15), Vector3(13.15, top, 0.17), "char")   # the hearth footing's soot
	Props.stencil(g, Vector3(13.16, cy + 1.6, 0.75), -90.0, "KAMIN", 32, Color(0.85, 0.82, 0.75, 0.45), 0.004)
	Props.puddle(g, Vector3(20.6, cy, 4.4), 1.0, 0.7, 25.0)
	Props.puddle(g, Vector3(13.0, cy, 12.2), 0.9, 0.6, -30.0)
	for c2: Array in [[Vector3(23.85, top - 0.02, 15.85), 180.0], [Vector3(11.05, top - 0.02, 15.85), 90.0], [Vector3(23.85, top - 0.02, 0.15), 270.0]]:
		Props.cobweb(g, c2[0], float(c2[1]), 0.9)
	# the breach the installers knocked through: rubble at the jambs, two pit props, the cable run, a chalk arrow
	for rb: Vector3 in [Vector3(21.25, cy, 16.3), Vector3(23.6, cy, 16.4), Vector3(23.7, cy, 18.9), Vector3(21.2, cy, 20.9)]:
		Props.ball(g, rb, Vector3(0.7, 0.35, 0.6), "brick_cellar")
	Props.pit_prop(g, Vector3(22.45, cy, 16.15), 0.0, 2.9, top - cy, "pine")
	Props.pit_prop(g, Vector3(22.43, cy, 18.2), 0.0, 2.85, top - cy, "pine")
	Props.cable(g, Vector3(23.8, top - 0.1, 20.3), Vector3(21.1, top - 0.1, 18.0), 0.08, 0.02, 8)
	Props.cable(g, Vector3(21.1, top - 0.1, 18.0), Vector3(21.1, top - 0.1, 15.0), 0.08, 0.02, 6)
	Props.stencil(g, Vector3(20.86 + 0.16, cy + 1.6, 18.6), -90.0, "→ HELVETIA\nKELLER II", 30, Color(0.92, 0.92, 0.88, 0.55), 0.004)
	Props.bulkhead_lamp(g, Vector3(23.83, cy + 2.1, 18.3), 90.0)
	# ---------------- the windows: timber frames in the openings, snow blown in under them, the light wells
	for wf: Array in [[Vector3(3.45, wy, 0.0), 0.0], [Vector3(24.0, wy, 1.8), -90.0]]:
		var fg: Node3D = Props.group(g, "WellWindow", wf[0], float(wf[1]))   # local +Z = into the room
		for side: float in [-1.0, 1.0]:
			Props.block(fg, Vector3(side * 0.8 - 0.07, OC_SILL - 0.03, -0.17), Vector3(side * 0.8 + 0.07, OC_WIN_H + 0.06, 0.17), "beam")
		Props.block(fg, Vector3(-0.87, OC_WIN_H, -0.17), Vector3(0.87, OC_WIN_H + 0.09, 0.17), "beam")
		Props.block(fg, Vector3(-0.87, OC_SILL - 0.05, -0.2), Vector3(0.87, OC_SILL, 0.22), "beam")
		Props.block(fg, Vector3(-0.75, OC_SILL, -0.6), Vector3(0.75, OC_SILL + 0.06, -0.17), "snow")
		Props.ball(fg, Vector3(0.1, cy - wy, 0.75), Vector3(1.2, 0.12, 0.8), "snow")   # blown in, on the room floor
	for ws: Array in [[2.0, 4.9, -2.15, -4.65], [24.15, 26.2, 0.4, -2.1]]:   # stone steps up out of each well
		var steps: int = int(ceil(-wy / 0.2))
		for k4: int in steps:
			var za: float = lerpf(float(ws[2]), float(ws[3]), float(k4) / float(steps))
			var zb: float = lerpf(float(ws[2]), float(ws[3]), float(k4 + 1) / float(steps))
			var yb: float = lerpf(wy, 0.0, float(k4 + 1) / float(steps))
			Props.block(g, Vector3(float(ws[0]), wy - 0.3, minf(za, zb)), Vector3(float(ws[1]), yb - 0.04, maxf(za, zb)), "stone")
			Props.block(g, Vector3(float(ws[0]) + 0.1, yb - 0.04, minf(za, zb)), Vector3(float(ws[1]) - 0.1, yb, maxf(za, zb)), "snow_trodden", false)
	for curb: Array in [[Vector3(1.8, 0, -4.65), Vector3(2.0, 0.18, -0.15)], [Vector3(4.9, 0, -4.65), Vector3(5.1, 0.18, -0.15)],
			[Vector3(26.2, 0, -2.1), Vector3(26.4, 0.18, 3.4)], [Vector3(24.0, 0, 3.2), Vector3(26.4, 0.18, 3.4)]]:
		Props.block(g, curb[0], curb[1], "cellar_stone")
	Props.snow_drift(g, Vector3(3.45, wy, -1.9), Vector3(2.6, 0.35, 0.6))
	Props.snow_drift(g, Vector3(25.9, wy, 2.6), Vector3(0.6, 0.35, 1.6))


## The Crucible's alcove on the cellar's north wall (the Crucible itself is a gameplay node, build_cellar_gameplay):
## brick facing between two iron columns under a riveted lintel, a soot halo on the soffit, the flue's chimney
## stack up in the yard (the flue passes through the roof), a grate and a faint Nachtglas ring where you stand to
## feed it, and the conduit from the fuse box.
func _crucible_setting(g: Node3D) -> void:
	var cy: float = CELLAR_Y
	var cx: float = 29.5
	Props.block(g, Vector3(cx - 1.25, cy, 19.15), Vector3(cx + 1.25, cy + 2.85, 19.2), "brick_cellar")
	for sx: float in [-1.0, 1.0]:
		Props.block(g, Vector3(cx + sx * 1.35 - 0.11, cy, 19.15), Vector3(cx + sx * 1.35 + 0.11, cy + 2.9, 19.42), "iron")
		Props.block(g, Vector3(cx + sx * 1.35 - 0.16, cy, 19.15), Vector3(cx + sx * 1.35 + 0.16, cy + 0.2, 19.47), "iron")
		Props.block(g, Vector3(cx + sx * 1.35 - 0.16, cy + 2.7, 19.15), Vector3(cx + sx * 1.35 + 0.16, cy + 2.9, 19.47), "iron")
	Props.block(g, Vector3(cx - 1.55, cy + 2.72, 19.15), Vector3(cx + 1.55, cy + 2.98, 19.5), "iron")
	for i: int in 7:
		Props._noshadow(Props.ball(g, Vector3(cx - 1.2 + i * 0.4, cy + 2.85, 19.5), Vector3(0.05, 0.05, 0.04), "steel"))
	Props._noshadow(Props.cyl(g, Vector3(cx, CELLAR_TOP - 0.008, 19.75), 0.75, 0.01, "char"))
	Props.block(g, Vector3(cx - 0.42, -0.25, 19.33), Vector3(cx + 0.42, 1.15, 20.17), "brick_cellar")
	Props.block(g, Vector3(cx - 0.48, 1.15, 19.27), Vector3(cx + 0.48, 1.27, 20.23), "cellar_stone")
	Props.block(g, Vector3(cx - 0.5, 1.27, 19.25), Vector3(cx + 0.5, 1.34, 20.25), "snow", false)
	Props._noshadow(Props.cyl(g, Vector3(cx, cy + 0.006, 21.35), 0.85, 0.012, "steel_grate"))
	Props._noshadow(Props.cyl(g, Vector3(cx, cy + 0.01, 21.35), 0.62, 0.012, "nachtglas_dim"))
	Props.pipe(g, Vector3(30.95, cy + 2.1, 19.25), Vector3(cx + 1.0, cy + 2.1, 19.25), 0.02)
	Props.pipe(g, Vector3(cx + 1.0, cy + 2.1, 19.25), Vector3(cx + 1.0, cy + 1.3, 19.25), 0.02)


## A segmental stone arch from a to b (same height), rising `rise` at the crown, as a run of boxes.
func _arch(parent: Node3D, a: Vector3, b: Vector3, rise: float, segs: int = 8, w: float = 0.42, d: float = 0.3) -> void:
	var prev: Vector3 = a
	var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
	for i: int in segs:
		var t: float = float(i + 1) / float(segs)
		var p: Vector3 = a.lerp(b, t) + Vector3(0, rise * sin(t * PI), 0)
		var mid: Vector3 = (prev + p) * 0.5
		var seg_len: float = prev.distance_to(p)
		if along_x:
			var ang: float = rad_to_deg(atan2(p.y - prev.y, p.x - prev.x))
			Props.obox(parent, mid, Vector3(seg_len + 0.04, d, w), "cellar_stone", Vector3(0, 0, ang))
		else:
			var ang2: float = rad_to_deg(atan2(p.y - prev.y, p.z - prev.z))
			Props.obox(parent, mid, Vector3(w, d, seg_len + 0.04), "cellar_stone", Vector3(-ang2, 0, 0))
		prev = p
	# corbels at the springing
	for e: Vector3 in [a, b]:
		if along_x:
			var out: float = 1.0 if e.x < (a.x + b.x) * 0.5 else -1.0
			Props.block(parent, e + Vector3(-0.05 * out, -0.42, -w * 0.5 - 0.03), e + Vector3(0.3 * out, 0.0, w * 0.5 + 0.03), "cellar_stone")
		else:
			var out2: float = 1.0 if e.z < (a.z + b.z) * 0.5 else -1.0
			Props.block(parent, e + Vector3(-w * 0.5 - 0.03, -0.42, -0.05 * out2), e + Vector3(w * 0.5 + 0.03, 0.0, 0.3 * out2), "cellar_stone")


# ================================================================== the CC0 prop library (UPDATE_05 section 5, T-093)

## Library props (PropLibrary keys) placed by the dressing passes: [key, Transform3D, casts_shadow]. They are built at
## load time by a PropScatter node ("LibraryProps", one MultiMesh per prop mesh), never collide, and sit over the
## invisible colliders the geometry pass already made (tables, beds, the barrel stack...), so the navmesh never moves.
var _lib_props: Array = []


func _lib(key: String, pos: Vector3, yaw: float, sc: Vector3 = Vector3.ONE, shadow: bool = true, extra_deg: Vector3 = Vector3.ZERO) -> void:
	_lib_props.append([key, PropScatter.place(pos, yaw, sc, extra_deg), shadow])


## A table over its collider: square ones are the round library table, long ones the plank table along their long
## side; the top lands at exactly 0.75 m, where the story props are placed.
func _lib_table(c: Vector3, w: float, d: float) -> void:
	if absf(w - d) < 0.05:
		var s: float = w / 1.007
		_lib("table_round", c, 0.0, Vector3(s, 0.75 / 0.723, s))
		return
	var length: float = maxf(w, d)
	var depth: float = minf(w, d)
	_lib("table_rect", c, 90.0 if d > w else 0.0, Vector3(length / 1.134, 0.75 / 0.8, depth / 0.706))


## A chair where Props.chair stood (its back at local +Z; the library chair's is at -Z, hence the half turn).
## Chairs cast no shadows (ART_BIBLE section 5: nothing new below chair size casts from the omni lamps).
func _lib_chair(pos: Vector3, yaw: float, tipped: bool = false) -> void:
	if tipped:
		_lib("chair_farmhouse", pos + Vector3(0, 0.27, 0), yaw + 180.0, Vector3(0.85, 0.85, 0.85), false, Vector3(-80, 0, 0))
	else:
		_lib("chair_farmhouse", pos, yaw + 180.0, Vector3(0.85, 0.85, 0.85), false)


## A cask where Props.barrel stood (same radius, height, and the same centre when tipped onto its side).
func _lib_barrel(pos: Vector3, yaw: float, r: float, h: float, tipped: bool = false) -> void:
	var sc: Vector3 = Vector3(2.0 * r / 0.742, h / 0.871, 2.0 * r / 0.756)
	if not tipped:
		_lib("barrel_wine", pos, yaw, sc)
		return
	var b: Basis = Basis.from_euler(Vector3(PI * 0.5, deg_to_rad(yaw), 0.0))
	var xf: Transform3D = Transform3D(b, pos + Vector3(0, r, 0)) * Transform3D(Basis.from_scale(sc), Vector3(0, -h * 0.5, 0))
	_lib_props.append(["barrel_wine", xf, true])


## A guest-room bed: the iron frame from the library round Props.bed_soft's mattress and blanket (head at the
## collider's -Z end, like Props.bed).
func _lib_bed(a: Vector3, b: Vector3, blanket: String, parent: Node3D) -> void:
	Props.bed_soft(parent, a, b, blanket)
	var c: Vector3 = Vector3((a.x + b.x) * 0.5, a.y, (a.z + b.z) * 0.5)
	_lib("bed_iron", c, 0.0, Vector3(absf(b.x - a.x) / 0.905, 1.0, absf(b.z - a.z) / 2.0))


func _emit_library_props() -> void:
	var ps: PropScatter = PropScatter.new()
	ps.name = "LibraryProps"
	ps.items = _lib_props
	map_root.add_child(ps)
	print("library props: %d placed" % _lib_props.size())


func _dress_hearth() -> void:
	var g: Node3D = Props.group(dress, "Hearth", Vector3.ZERO)
	Props.block(g, Vector3(10.9, 0, 0.15), Vector3(11.4, 1.42, 0.95), "stone")      # left jamb
	Props.block(g, Vector3(12.6, 0, 0.15), Vector3(13.1, 1.42, 0.95), "stone")      # right jamb
	Props.block(g, Vector3(11.4, 1.0, 0.15), Vector3(12.6, 1.42, 0.95), "stone")    # lintel
	Props.block(g, Vector3(11.4, 0, 0.15), Vector3(12.6, 1.0, 0.3), "char")         # sooty back
	Props.block(g, Vector3(10.7, 0, 0.95), Vector3(13.3, 0.12, 1.5), "stone")       # hearthstone
	Props.block(g, Vector3(10.75, 1.42, 0.15), Vector3(13.25, 1.5, 1.08), "beam")    # mantel
	Props.block(g, Vector3(11.2, 1.5, 0.15), Vector3(12.8, TAP_H, 0.6), "stone")     # chimney breast
	Props.hearth_fire(g, Vector3(12.0, 0.02, 0.6))
	# mantel clutter (keep the note's spot at x 12.5 clear)
	Props.cyl(g, Vector3(11.1, 1.62, 0.6), 0.05, 0.24, "brass")
	Props.cyl(g, Vector3(11.4, 1.58, 0.55), 0.06, 0.16, "stein")
	Props.block(g, Vector3(13.0, 1.5, 0.3), Vector3(13.2, 1.75, 0.5), "furniture")   # clock
	Props.antlers(g, Vector3(12.0, 2.75, 0.62), 180.0)
	Props.block(g, Vector3(13.4, 0, 0.6), Vector3(14.0, 0.5, 1.2), "planks")          # log box
	for i: int in 4:
		Props.cyl(g, Vector3(13.7, 0.55 + i * 0.09, 0.9), 0.06, 0.55, "beam", Vector3(90, 0, 10.0 * i))
	Props.block(g, Vector3(10.2, 0, 0.3), Vector3(10.3, 0.9, 0.4), "iron")            # poker


## Glassware that breaks when shot (T-053): collected per set here, built as ShatterSets by build_reactive().
## [base position, ShatterSet kind, height scale]
var _glass: Dictionary = {}


func _glassware(set_name: String, base: Vector3, kind: String, h: float = 1.0) -> void:
	(_glass.get_or_add(set_name, []) as Array).append([base, kind, h])


## A shelf line of bottles and steins from a to b (both on the board's top), like Props.bottles but shootable.
func _bottle_row(set_name: String, a: Vector3, b: Vector3, count: int, seed_v: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var kinds: Array = ["bottle_green", "bottle_amber", "stein"]
	for i: int in count:
		var k: String = kinds[rng.randi() % kinds.size()]
		var t: float = (float(i) + rng.randf_range(0.1, 0.9)) / float(count)
		var p: Vector3 = a.lerp(b, t) + Vector3(rng.randf_range(-0.06, 0.06), 0, 0)   # a little in and out on the board
		var h: float = rng.randf_range(0.83, 1.15) if k != "stein" else 1.0
		_glassware(set_name, p, k, h)


func _dress_bar() -> void:
	var g: Node3D = Props.group(dress, "Bar", Vector3.ZERO)
	# counter: panelled body, overhanging top, brass foot rail
	Props.block(g, Vector3(5.0, 0, 8.05), Vector3(9.0, 1.02, 8.8), "wainscot")
	Props.block(g, Vector3(8.25, 0, 3.0), Vector3(9.0, 1.02, 8.05), "wainscot")
	Props.block(g, Vector3(4.95, 1.02, 7.95), Vector3(9.12, 1.1, 8.92), "furniture")
	Props.block(g, Vector3(8.15, 1.02, 2.95), Vector3(9.12, 1.1, 8.0), "furniture")
	Props.cyl(g, Vector3(7.0, 0.18, 8.98), 0.025, 4.0, "brass", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(9.18, 0.18, 5.5), 0.025, 5.0, "brass", Vector3(90, 0, 0))
	for x: float in [5.6, 6.6, 7.6, 8.6]:
		Props.stool(g, Vector3(x, 0, 9.35))
	for z: float in [4.0, 5.2, 6.4]:
		Props.stool(g, Vector3(9.55, 0, z))
	# back shelving: uprights + boards (top board at 2.0 carries the radio)
	for z: float in [3.02, 5.5, 7.98]:
		Props.block(g, Vector3(4.6, 0, z - 0.03), Vector3(5.0, 2.0, z + 0.03), "beam")
	for y: float in [0.45, 0.95, 1.45, 1.95]:
		Props.block(g, Vector3(4.6, y, 3.0), Vector3(5.0, y + 0.05, 8.0), "furniture")
	Props.block(g, Vector3(4.55, 0, 3.0), Vector3(4.6, 2.0, 8.0), "wainscot")
	# the bottles break when shot (a ShatterSet, T-053; built by build_reactive). The 1.5 m board keeps a gap
	# under the radio for Käthe's frequency notes pinned to the back board.
	_bottle_row("Bar", Vector3(4.8, 0.5, 3.1), Vector3(4.8, 0.5, 7.9), 22, 11)
	_bottle_row("Bar", Vector3(4.8, 1.0, 3.1), Vector3(4.8, 1.0, 7.9), 20, 12)
	_bottle_row("Bar", Vector3(4.8, 1.5, 3.1), Vector3(4.8, 1.5, 3.9), 3, 13)
	_bottle_row("Bar", Vector3(4.8, 1.5, 4.95), Vector3(4.8, 1.5, 7.9), 11, 15)
	_bottle_row("Bar", Vector3(4.8, 2.0, 5.6), Vector3(4.8, 2.0, 7.9), 6, 14)   # left of the radio
	# a keg, glasses and a ledger on the counter
	Props.cyl(g, Vector3(6.0, 0.4, 3.6), 0.32, 0.8, "planks", Vector3(90, 90, 0))
	Props.cyl(g, Vector3(7.4, 0.35, 3.5), 0.3, 0.7, "planks")
	Props.block(g, Vector3(6.6, 1.1, 8.2), Vector3(7.0, 1.14, 8.5), "paper")
	for x: float in [5.4, 5.6, 7.8, 8.6]:
		_glassware("Bar", Vector3(x, 1.1, 8.35), "stein", 0.94)
	# the last round poured and not drunk: schnapps glasses and the bottle on the counter
	for gp: Vector3 in [Vector3(6.2, 1.1, 8.45), Vector3(6.36, 1.1, 8.3), Vector3(7.3, 1.1, 8.55)]:
		_glassware("Bar", gp, "glass", 0.8)
	_glassware("Bar", Vector3(6.05, 1.1, 8.22), "bottle_green", 1.0)
	Props.wall_lamp(g, Vector3(4.6, 2.5, 4.5), -90.0)


func _dress_taproom() -> void:
	var g: Node3D = Props.group(dress, "Taproom", Vector3.ZERO)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1944
	for p: Vector2 in [Vector2(12.5, 11.5), Vector2(16.5, 11.5), Vector2(20.0, 4.5)]:
		_lib_table(Vector3(p.x, 0, p.y), 1.2, 1.2)
		for k: int in 4:
			var a: float = TAU * float(k) / 4.0 + 0.4
			var cp: Vector3 = Vector3(p.x + cos(a) * 0.95, 0, p.y + sin(a) * 0.95)
			_lib_chair(cp, rad_to_deg(atan2(-(cp.x - p.x), -(cp.z - p.y))) + 180.0 + rng.randf_range(-20, 20), rng.randf() < 0.12)
		_glassware("Taproom", Vector3(p.x - 0.2, 0.75, p.y + 0.1), "stein", 0.94)
		Props.cyl(g, Vector3(p.x + 0.25, 0.8, p.y - 0.2), 0.03, 0.1, "candle")
		Props.block(g, Vector3(p.x + 0.05, 0.751, p.y - 0.05), Vector3(p.x + 0.25, 0.755, p.y + 0.2), "paper", false)
	_dress_new_tables(g)
	# benches along the south wall, a rug in front of the hearth, coat rack by the stable door
	Props.bench(g, Vector3(9.0, 0, 15.45), 0.0, 3.0)
	Props.bench(g, Vector3(14.5, 0, 15.45), 0.0, 3.0)
	Props.block(g, Vector3(9.8, 0.012, 1.8), Vector3(14.2, 0.025, 4.8), "rug", false)
	Props.coat_rack(g, Vector3(22.6, 0, 15.3))
	# pictures and lamps (the south wall east of the benches is kept for story items)
	Props.painting(g, Vector3(3.0, 2.2, 0.16), 180.0, 0.7, 0.5, "landscape", 0, "frame_gold")
	Props.painting(g, Vector3(21.5, 2.3, 0.16), 180.0, 0.9, 0.6, "hunting", 0, "frame_walnut")
	Props.painting(g, Vector3(11.0, 2.2, 15.84), 0.0, 0.8, 0.55, "stilllife", 0, "frame_gold")
	Props.painting(g, Vector3(23.84, 2.4, 2.0), 90.0, 0.55, 0.75, "portrait", 0, "frame_walnut")   # over the signals crates
	Props.painting(g, Vector3(0.16, 2.4, 2.5), -90.0, 0.5, 0.65, "photo", 0, "frame_black", 0.0, true)
	Props.painting(g, Vector3(9.4, 2.78, 0.16), 180.0, 0.5, 0.4, "landscape", 2, "frame_black", -2.0, true)
	Props.painting(g, Vector3(23.84, 2.2, 14.0), 90.0, 0.42, 0.55, "licence", 0, "frame_black")   # the inn licence by the cellar door
	# a wall clock and a shelf of steins on the north wall west of the hearth
	var clk: Node3D = Props.group(g, "WallClock", Vector3(0.16, 2.55, 3.6), -90.0)
	Props.block(clk, Vector3(-0.17, -0.3, -0.14), Vector3(0.17, 0.3, 0.0), "furniture")
	Props.block(clk, Vector3(-0.2, 0.3, -0.17), Vector3(0.2, 0.34, 0.0), "beam")
	Props.cyl(clk, Vector3(0, 0.1, -0.145), 0.13, 0.01, "gauge_face", Vector3(90, 0, 0))
	Props.obox(clk, Vector3(0, 0.1, -0.155), Vector3(0.01, 0.09, 0.004), "black_paint", Vector3(0, 0, 0))
	Props.obox(clk, Vector3(0.03, 0.12, -0.155), Vector3(0.01, 0.07, 0.004), "black_paint", Vector3(0, 0, -60))
	Props.block(clk, Vector3(-0.12, -0.26, -0.13), Vector3(0.12, -0.02, -0.12), "window_dark")
	Props.cyl(clk, Vector3(0, -0.18, -0.125), 0.04, 0.008, "brass", Vector3(90, 0, 0))
	Props.block(g, Vector3(8.2, 2.0, 0.15), Vector3(10.6, 2.04, 0.4), "furniture")
	for i: int in 6:
		_glassware("Taproom", Vector3(8.4 + i * 0.4, 2.04, 0.28), "stein", 0.94)
	Props.block(g, Vector3(8.2, 1.9, 0.15), Vector3(8.24, 2.0, 0.38), "furniture")
	Props.block(g, Vector3(10.56, 1.9, 0.15), Vector3(10.6, 2.0, 0.38), "furniture")
	Props.lantern(g, Vector3(6.5, 2.6, 11.5), TAP_H - 0.28)
	Props.lantern(g, Vector3(17.5, 2.6, 4.0), TAP_H - 0.28)
	Props.lantern(g, Vector3(19.5, 2.6, 13.0), TAP_H - 0.28)
	Props.lantern(g, Vector3(14.0, 2.6, 8.0), TAP_H - 0.36)
	# crates of the signals unit's kit by the east wall, a dropped rifle sling
	Props.crate(g, Vector3(22.8, 0, 2.0), 0.7, 10.0, "WH  Nachr.")
	Props.crate(g, Vector3(22.7, 0.7, 2.1), 0.55, -5.0)
	Props.crate(g, Vector3(21.9, 0, 2.2), 0.6, 30.0)
	# boarded-up feel: spare planks leaning by a window
	for i: int in 3:
		Props.obox(g, Vector3(1.0 + i * 0.12, 1.0, 4.3), Vector3(0.04, 2.0, 0.18), "planks", Vector3(0, 90, 12.0 + i * 3.0))


## The added tables (TAP_TABLES_NEW, T-072) and what the round 1 patrons leave on them as they run: steins half
## drunk (shootable), a game of skat dropped mid-hand, a pipe, Frau Pohl's coffee cup and her suitcase, the
## soldier's Christmas parcel on the bar. A candle on each table (the two big ones light, following their lamps).
func _dress_new_tables(g: Node3D) -> void:
	for t: Array in TAP_TABLES_NEW:
		var c: Vector2 = t[0]
		var w: float = float(t[1])
		var d: float = float(t[2])
		_lib_table(Vector3(c.x, 0, c.y), w, d)
		match str(t[3]):
			"chairs":
				for off: Vector2 in [Vector2(-0.85, 0), Vector2(0.85, 0), Vector2(0, -0.85), Vector2(0, 0.85)]:
					var cp: Vector3 = Vector3(c.x + off.x, 0, c.y + off.y)
					_lib_chair(cp, rad_to_deg(atan2(-off.x, -off.y)) + 180.0)
			"pair":
				for off2: Vector2 in [Vector2(-0.75, 0), Vector2(0.75, 0)]:
					_lib_chair(Vector3(c.x + off2.x, 0, c.y + off2.y), rad_to_deg(atan2(-off2.x, -off2.y)) + 180.0)
			"benches":
				for sx: float in [-1.0, 1.0]:
					Props.bench(g, Vector3(c.x + sx * 0.75, 0, c.y), 90.0, d - 0.1)
		Props.cyl(g, Vector3(c.x + w * 0.2, 0.8, c.y - d * 0.15), 0.03, 0.1, "candle")
		Props.cyl(g, Vector3(c.x + w * 0.2, 0.752, c.y - d * 0.15), 0.05, 0.006, "brass")
	# the carters' table (19, 9): steins, the skat hands face down and the pot, a pipe in the ashtray
	_glassware("Taproom", Vector3(18.7, 0.75, 9.15), "stein", 0.94)
	_glassware("Taproom", Vector3(19.15, 0.75, 8.55), "stein", 0.94)
	var cr: RandomNumberGenerator = RandomNumberGenerator.new()
	cr.seed = 1223
	for k: int in 9:
		Props.obox(g, Vector3(19.0 + cr.randf_range(-0.35, 0.3), 0.753 + k * 0.001, 9.0 + cr.randf_range(-0.3, 0.35)), Vector3(0.06, 0.002, 0.09),
			"paper", Vector3(0, cr.randf_range(0, 180), 0))
	Props.cyl(g, Vector3(19.3, 0.765, 9.3), 0.06, 0.015, "iron")             # the ashtray
	Props.obox(g, Vector3(19.33, 0.785, 9.3), Vector3(0.012, 0.012, 0.14), "furniture", Vector3(0, 30, 0))   # the pipe's stem
	Props.cyl(g, Vector3(19.38, 0.79, 9.36), 0.02, 0.04, "furniture")
	for k2: int in 4:   # the pot: a few coins
		Props.cyl(g, Vector3(18.95 + k2 * 0.03, 0.756, 9.05), 0.012, 0.004, "brass")
	# the table cleared in a hurry (16, 4.8): a stein, a mug knocked onto its side
	_glassware("Taproom", Vector3(15.8, 0.75, 4.6), "stein", 0.94)
	PropsStory.mug(g, Vector3(16.25, 0.75, 5.0))
	Props.obox(g, Vector3(16.1, 0.79, 4.45), Vector3(0.08, 0.16, 0.08), "enamel_plate", Vector3(90, 40, 0))
	# Frau Pohl's table (12.3, 5.4): her cup of real coffee, a handkerchief; the suitcase on the floor beside her
	PropsStory.mug(g, Vector3(12.45, 0.75, 5.35))
	Props.obox(g, Vector3(12.15, 0.753, 5.55), Vector3(0.18, 0.004, 0.18), "linen", Vector3(0, 25, 0))
	var sc: Node3D = Props.group(g, "PohlSuitcase", Vector3(11.35, 0, 6.15), 15.0)
	Props.block(sc, Vector3(-0.3, 0.0, -0.1), Vector3(0.3, 0.42, 0.1), "leather")
	for sx2: float in [-0.15, 0.15]:
		Props.block(sc, Vector3(sx2 - 0.02, 0.0, -0.105), Vector3(sx2 + 0.02, 0.42, 0.105), "furniture")   # straps
	Props.obox(sc, Vector3(0, 0.46, 0), Vector3(0.14, 0.03, 0.03), "leather")   # the handle
	# the long trestle (8, 11.8): steins left in a row, a loaf
	for k3: int in 3:
		_glassware("Taproom", Vector3(7.85 + 0.25 * float(k3 % 2), 0.75, 11.0 + 0.7 * k3), "stein", 0.94)
	PropsStory.loaf(g, Vector3(8.05, 0.75, 12.6), 80.0)
	# Gefreiter Sobotta's Christmas parcel on the bar, brown paper and string: he was nearly home (T-072)
	var pc: Node3D = Props.group(g, "ChristmasParcel", Vector3(7.9, 1.1, 8.45), 10.0)
	Props.block(pc, Vector3(-0.16, 0.0, -0.11), Vector3(0.16, 0.13, 0.11), "paper")
	Props.block(pc, Vector3(-0.162, 0.0, -0.01), Vector3(0.162, 0.132, 0.01), "rope")
	Props.block(pc, Vector3(-0.01, 0.0, -0.112), Vector3(0.01, 0.132, 0.112), "rope")
	_glassware("Taproom", Vector3(7.45, 1.1, 8.5), "stein", 0.94)


func _dress_upstairs() -> void:
	var g: Node3D = Props.group(dress, "Upstairs", Vector3.ZERO)
	_lib_bed(Vector3(0.3, UP_Y, 0.4), Vector3(2.2, UP_Y + 0.5, 2.6), "cloth_red", g)
	_lib_bed(Vector3(13.6, UP_Y, 0.4), Vector3(15.6, UP_Y + 0.5, 2.6), "cloth_green", g)
	_lib_bed(Vector3(21.6, UP_Y, 3.2), Vector3(23.7, UP_Y + 0.5, 5.6), "cloth_red", g)
	Props.trunk(g, Vector3(10.4, UP_Y, 0.5), Vector3(11.6, UP_Y + 0.5, 1.2))
	Props.washstand(g, Vector3(6.9, UP_Y, 0.45), 180.0)
	Props.washstand(g, Vector3(8.6, UP_Y, 4.5), -90.0)
	Props.wardrobe(g, Vector3(15.5, UP_Y, 4.9), 90.0)
	Props.wardrobe(g, Vector3(1.0, UP_Y, 5.4), 0.0)
	_lib_chair(Vector3(2.8, UP_Y, 1.2), 140.0, true)
	_lib_chair(Vector3(18.0, UP_Y, 1.3), 200.0)
	# pictures: one per room, two in the hall, and a mirror by the stair head (the hall's north wall straight ahead
	# at the top of the stairs, x < 4, stays free for a story item)
	Props.painting(g, Vector3(12.0, UP_Y + 1.7, 0.16), 180.0, 0.5, 0.65, "portrait", 1, "frame_gold")
	Props.painting(g, Vector3(18.0, UP_Y + 1.6, 9.84), 0.0, 0.7, 0.5, "landscape", 2, "frame_walnut")
	Props.painting(g, Vector3(7.85, UP_Y + 1.7, 3.0), 90.0, 0.6, 0.45, "landscape", 1, "frame_gold")
	Props.painting(g, Vector3(8.15, UP_Y + 1.7, 2.0), -90.0, 0.5, 0.4, "stilllife", 1, "frame_black", 1.5)
	Props.painting(g, Vector3(23.85, UP_Y + 1.8, 1.6), 90.0, 0.45, 0.36, "photo", 1, "frame_black", 0.0, true)
	Props.painting(g, Vector3(10.0, UP_Y + 1.75, 9.84), 0.0, 0.45, 0.55, "hunting", 1, "frame_walnut", -1.5)
	Props.mirror(g, Vector3(0.15, UP_Y + 1.7, 8.0), -90.0, 0.5, 0.7)
	# rugs and nightstands with candles
	Props.block(g, Vector3(2.4, UP_Y + 0.012, 0.9), Vector3(4.2, UP_Y + 0.024, 2.6), "rug", false)
	Props.block(g, Vector3(11.4, UP_Y + 0.012, 1.4), Vector3(13.3, UP_Y + 0.024, 3.4), "rug", false)
	Props.block(g, Vector3(18.6, UP_Y + 0.012, 2.6), Vector3(21.2, UP_Y + 0.024, 5.0), "rug", false)
	for ns: Vector3 in [Vector3(2.55, UP_Y, 0.55), Vector3(13.1, UP_Y, 0.55), Vector3(21.1, UP_Y, 5.3)]:
		_lib("nightstand", ns, 0.0, Vector3(0.8, 1.0, 0.8), false)
		Props.cyl(g, ns + Vector3(0.05, 0.64, 0.02), 0.04, 0.02, "brass")
		Props.cyl(g, ns + Vector3(0.05, 0.7, 0.02), 0.012, 0.1, "candle")
	for p: Vector3 in [Vector3(4.0, UP_Y + 2.2, 3.0), Vector3(12.0, UP_Y + 2.2, 3.0), Vector3(20.0, UP_Y + 2.2, 3.0), Vector3(12.0, UP_Y + 2.2, 8.0)]:
		Props.lantern(g, p, UP_TOP - 0.24)
	Props.lantern(g, Vector3(3.2, 4.6, 12.5), UP_TOP)   # in the stairwell


func _dress_stable() -> void:
	var g: Node3D = Props.group(dress, "Stable", Vector3.ZERO)
	# stall partitions: posts and boards over the collision slabs
	for x: float in [11.0, 16.0, 17.6]:
		Props.block(g, Vector3(x - 0.1, 0, 25.0), Vector3(x + 0.1, 2.0, 25.3), "beam")
		for y: float in [0.3, 0.75, 1.2]:
			Props.block(g, Vector3(x - 0.09, y - 0.12, 22.2), Vector3(x + 0.09, y + 0.12, 25.2), "planks")
	# straw on the floor, mangers, hay bales, tack
	var srng: RandomNumberGenerator = RandomNumberGenerator.new()
	srng.seed = 7
	for p: Vector3 in [Vector3(12.5, 0, 23.6), Vector3(14.0, 0, 24.0), Vector3(19.5, 0, 24.5), Vector3(9.0, 0, 27.0), Vector3(20.0, 0, 31.0)]:
		for k: int in 5:   # loose straw: scattered thin tufts
			Props.obox(g, p + Vector3(srng.randf_range(-0.9, 0.9), 0.012, srng.randf_range(-0.7, 0.7)),
				Vector3(srng.randf_range(0.3, 0.8), 0.02, srng.randf_range(0.2, 0.5)), "straw_floor", Vector3(0, srng.randf_range(0, 180), 0))
	for x: float in [12.0, 16.8]:
		Props.block(g, Vector3(x - 0.6, 0.5, 22.2), Vector3(x + 0.6, 0.85, 22.6), "planks")
	Props.block(g, Vector3(21.5, 0, 22.4), Vector3(23.5, 0.7, 25.0), "hay")   # the hay pile (ground spawn; west of the stair's foot since T-084)
	for i: int in 4:
		Props.hay_bale(g, Vector3(19.6, 0.45 * (i / 2), 25.6 + (i % 2) * 0.55), 90.0)   # (under the bay, clear of the stair)
	Props.hay_bale(g, Vector3(20.2, 0, 27.3), 75.0)
	# tack rail, saddle blanket, bridle: hung above the Armorer's Bench (T-068), which stands under them
	var wx: float = STB_X0 + 0.15   # the west wall's inner face
	Props.block(g, Vector3(wx, 2.0, 25.5), Vector3(wx + 0.1, 2.1, 27.5), "beam")   # tack rail
	Props.block(g, Vector3(wx + 0.1, 1.8, 25.9), Vector3(wx + 0.45, 2.15, 26.5), "cloth_red")   # saddle blanket
	Props.block(g, Vector3(wx + 0.1, 1.78, 26.8), Vector3(wx + 0.3, 2.1, 27.2), "furniture")    # bridle/strap
	Props.crate(g, Vector3(22.7, 0, 33.2), 0.6, 15.0)
	for lp: Array in [[Vector3(19.0, 4.0, 26.0), STABLE_H - 0.6], [Vector3(19.0, 2.5, 31.5), LOFT_Y], [Vector3(10.0, 2.3, 28.0), LOFT_Y],
			[Vector3(10.0, 5.6, 28.0), STABLE_H - 0.6], [Vector3(20.0, 2.4, 19.0), 3.0]]:
		Props.lantern(g, lp[0], float(lp[1]))
	_dress_hay_stairs(g)
	_dress_loft(g)


## The hayloft stair (T-084): fifteen solid treads with a worn nosing, drawn under the invisible ramp (the ramp runs
## on the nosing line, so a tread's top is never above it), a footboard where the ramp leaves the floor, a closed
## string and boarded planks down the open west side with the store's little door, newel posts and balusters
## between the rail bars, and a wall rail up the east wall.
func _dress_hay_stairs(g: Node3D) -> void:
	var run: float = HSTAIR_Z1 - HSTAIR_Z0
	var tread: float = run / float(HSTAIR_STEPS)
	var riser: float = LOFT_TOP / float(HSTAIR_STEPS)
	for k: int in HSTAIR_STEPS - 1:
		var za: float = HSTAIR_Z0 + tread * float(k + 1)
		var zb: float = za + tread
		var top: float = riser * float(k + 1)
		Props.block(g, Vector3(HSTAIR_X0, 0.0, za), Vector3(HSTAIR_X1, top - 0.045, zb), "beam")
		Props.block(g, Vector3(HSTAIR_X0, top - 0.045, za - 0.025), Vector3(HSTAIR_X1, top, zb + 0.01), "furniture")   # the tread board and its nosing
	Props.block(g, Vector3(HSTAIR_X0, 0.0, HSTAIR_Z0 - 0.02), Vector3(HSTAIR_X1, 0.11, HSTAIR_Z0 + tread), "furniture")   # the footboard
	# the closed string along the open side, the boarding under it, the store's door
	var ang: float = rad_to_deg(atan2(LOFT_TOP, run))
	var mid: Vector3 = Vector3(HSTAIR_X0 - 0.02, LOFT_TOP * 0.5 + 0.12, (HSTAIR_Z0 + HSTAIR_Z1) * 0.5)
	Props.obox(g, mid, Vector3(0.06, 0.34, Vector2(run, LOFT_TOP).length() + 0.3), "beam", Vector3(-ang, 0, 0))
	var zc: float = HSTAIR_Z0 + 0.4
	var pk: int = 0
	while zc < HSTAIR_Z1 - 0.05:
		var zn: float = minf(zc + 0.22, HSTAIR_Z1)
		var h: float = LOFT_TOP * (zc - HSTAIR_Z0) / run - 0.2
		if h > 0.1:
			Props.block(g, Vector3(HSTAIR_X0 - 0.045, 0.0, zc + 0.01), Vector3(HSTAIR_X0 + 0.0, h, zn - 0.01), "planks" if pk % 2 == 0 else "board_wood_v")
		zc = zn
		pk += 1
	Props.block(g, Vector3(HSTAIR_X0 - 0.07, 0.02, 29.6), Vector3(HSTAIR_X0 - 0.04, 1.75, 30.5), "board_wood_v")   # the store's door
	Props.block(g, Vector3(HSTAIR_X0 - 0.09, 0.95, 29.68), Vector3(HSTAIR_X0 - 0.06, 1.02, 29.78), "iron")
	# newels at the foot and the head, balusters between the bars, a wall rail up the east wall
	Props.newel(g, Vector3(HSTAIR_X0 - 0.05, 0.0, HSTAIR_Z0 - 0.02), 1.1)
	Props.newel(g, Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, HSTAIR_Z1 - 0.02), 1.1)
	var n: int = int(run / 0.45)
	for b: int in range(1, n):
		var t: float = float(b) / float(n)
		var bz: float = lerpf(HSTAIR_Z0, HSTAIR_Z1, t)
		var by: float = LOFT_TOP * t
		Props.block(g, Vector3(HSTAIR_X0 - 0.07, by + 0.1, bz - 0.02), Vector3(HSTAIR_X0 - 0.03, by + 0.98, bz + 0.02), "furniture")
	var rail_mid: Vector3 = Vector3(STB_X1 - 0.15 - 0.06, LOFT_TOP * 0.5 + 0.95, (HSTAIR_Z0 + HSTAIR_Z1) * 0.5)
	Props.obox(g, rail_mid, Vector3(0.05, 0.05, Vector2(run, LOFT_TOP).length()), "furniture", Vector3(-ang, 0, 0))
	for bk: int in 4:
		var tz: float = lerpf(HSTAIR_Z0 + 0.6, HSTAIR_Z1 - 0.6, float(bk) / 3.0)
		Props.block(g, Vector3(STB_X1 - 0.15 - 0.08, LOFT_TOP * (tz - HSTAIR_Z0) / run + 0.88, tz - 0.02), Vector3(STB_X1 - 0.15, LOFT_TOP * (tz - HSTAIR_Z0) / run + 0.95, tz + 0.02), "iron")


## The second level (T-084): balusters and newels along the rails (the bars are colliders, these are the turned
## sticks between them), the bale drop's worn boards and its hook, the bale stack and the single bales over their
## colliders, the two crates, the hay chute's trapdoor over the horse's stall with its rope and pulley, a pitchfork
## in the stack, a lantern on a hook by the stair head, tack hanging from the tie beams (a collar, harness, a
## bridle, a bucket), a coil of rope and a few sacks.
func _dress_loft(g: Node3D) -> void:
	var y: float = LOFT_TOP
	# balusters and newels along the edge rails (0.45 m apart, between the collider bars)
	var edges: Array = [[Vector3(LOFT_X1 - 0.05, y, STB_Z0 + 0.3), Vector3(LOFT_X1 - 0.05, y, GAL_Z0 - 0.05)],
		[Vector3(LOFT_X1 - 0.05, y, GAL_Z0 + 0.05), Vector3(LOFT_DROP.x, y, GAL_Z0 + 0.05)], [Vector3(LOFT_DROP.y, y, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, y, GAL_Z0 + 0.05)],
		[Vector3(HSTAIR_X0 - 0.05, y, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, y, HSTAIR_Z1 - 0.1)]]
	for e: Array in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var cnt: int = maxi(1, int(a.distance_to(b) / 0.45))
		for k: int in range(1, cnt):
			var p: Vector3 = a.lerp(b, float(k) / float(cnt))
			Props.block(g, p + Vector3(-0.02, 0.1, -0.02), p + Vector3(0.02, 0.98, 0.02), "furniture")
	for np: Vector3 in [Vector3(LOFT_X1 - 0.05, y, GAL_Z0), Vector3(LOFT_DROP.x, y, GAL_Z0 + 0.05), Vector3(LOFT_DROP.y, y, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, y, GAL_Z0)]:
		Props.newel(g, np, 1.1)
	# the bale drop: boards worn pale at the lip, the hook on the beam above it, a rope down to it
	Props.block(g, Vector3(LOFT_DROP.x, y + 0.004, GAL_Z0 - 1.4), Vector3(LOFT_DROP.y, y + 0.012, GAL_Z0 + 0.15), "planks", false)
	Props.block(g, Vector3((LOFT_DROP.x + LOFT_DROP.y) * 0.5 - 0.02, STABLE_H - 1.0, GAL_Z0 - 0.3), Vector3((LOFT_DROP.x + LOFT_DROP.y) * 0.5 + 0.02, STABLE_H - 0.6, GAL_Z0 - 0.26), "iron")
	Props.cable(g, Vector3((LOFT_DROP.x + LOFT_DROP.y) * 0.5, STABLE_H - 1.0, GAL_Z0 - 0.28), Vector3((LOFT_DROP.x + LOFT_DROP.y) * 0.5, y + 1.3, GAL_Z0 - 0.2), 0.0, 0.015, 2, "rope")
	# the bale stack in the south-west corner (over the HayBales collider), the single bales (over theirs)
	for xi: int in 3:
		for zi: int in 5:
			Props.hay_bale(g, Vector3(STB_X0 + 0.9 + xi * 0.95, y, 30.85 + zi * 0.55), 0.0 if (xi + zi) % 2 == 0 else 3.0)
	Props.hay_bale(g, Vector3(STB_X0 + 1.8, y + 0.45, 31.4), 8.0)
	Props.hay_bale(g, Vector3(STB_X0 + 2.6, y + 0.45, 32.4), -6.0)
	Props.hay_bale(g, Vector3(STB_X0 + 1.3, y + 0.45, 32.9), 4.0)
	for hb: Array in LOFT_BALES:
		Props.hay_bale(g, hb[0], float(hb[1]))
	for cr: Array in LOFT_CRATES:
		Props.crate(g, cr[0], float(cr[1]), float(cr[2]), str(cr[3]))
	# the hay chute: a trapdoor flush in the boards over the horse's stall, its frame, straps and ring, the rope from
	# the pulley on the tie beam, a coil beside it
	var hc: Vector3 = Vector3(13.0, y, 23.6)
	Props.block(g, hc + Vector3(-0.55, 0.0, -0.55), hc + Vector3(0.55, 0.07, 0.55), "beam")
	Props.block(g, hc + Vector3(-0.45, 0.07, -0.45), hc + Vector3(0.45, 0.1, 0.45), "board_wood_v")
	for sz: float in [-0.25, 0.25]:
		Props.block(g, hc + Vector3(-0.47, 0.1, sz - 0.03), hc + Vector3(0.47, 0.115, sz + 0.03), "iron")
	Props.cyl(g, hc + Vector3(0.3, 0.12, 0.0), 0.07, 0.02, "iron")
	Props.cyl(g, Vector3(13.0, STABLE_H - 0.72, 24.5), 0.14, 0.08, "iron", Vector3(0, 0, 90))
	Props.cable(g, Vector3(13.0, STABLE_H - 0.8, 24.5), Vector3(13.0, y + 0.3, 24.3), 0.0, 0.015, 2, "rope")
	Props.rope_coil(g, Vector3(13.9, y, 24.6), 0.3)
	# the pitchfork leaning in the stack, a bucket, sacks
	var pf: Node3D = Props.group(g, "Pitchfork", Vector3(STB_X0 + 3.6, y, 30.4), 20.0)
	Props.cyl(pf, Vector3(0, 0.8, 0.1), 0.018, 1.6, "beam", Vector3(-14, 0, 0))
	Props.block(pf, Vector3(-0.12, 1.55, 0.27), Vector3(0.12, 1.59, 0.31), "iron")
	for tx: float in [-0.1, 0.0, 0.1]:
		Props.obox(pf, Vector3(tx, 1.72, 0.33), Vector3(0.012, 0.3, 0.012), "iron", Vector3(-14, 0, 0))
	Props.cyl(g, Vector3(24.6, y + 0.15, 33.3), 0.15, 0.3, "tin")
	Props.sack(g, Vector3(8.6, y, 33.2), 15.0, 0.9)
	Props.sack(g, Vector3(9.3, y, 33.4), -30.0, 0.8)
	Props.sack(g, Vector3(8.9, y + 0.32, 33.3), 60.0, 0.8)
	# the lantern on its hook by the stair head (LoftHookLamp lights it), on a bracket off the tie beam's post line
	Props.block(g, Vector3(21.0, y + 1.9, 30.86), Vector3(21.3, y + 1.95, 30.94), "iron")
	Props.lantern(g, Vector3(21.2, y + 1.55, 30.9), y + 1.95)
	# tack from the tie beam at z 28 over the west block: a horse collar, harness straps, a bridle, a bucket on a rope
	var tb: Node3D = Props.group(g, "LoftTack", Vector3(0, STABLE_H - 0.6, 28.0))
	for cx: float in [7.6, 10.4]:
		Props.cable(tb, Vector3(cx, 0, 0), Vector3(cx, -0.9, 0), 0.0, 0.012, 2, "rope")
	var collar: Node3D = Props.group(tb, "Collar", Vector3(7.6, -1.25, 0))
	for k2: int in 10:
		var a0: float = TAU * float(k2) / 10.0
		var a1: float = TAU * float(k2 + 1) / 10.0
		Props.strut(collar, Vector3(cos(a0) * 0.3, sin(a0) * 0.36, 0), Vector3(cos(a1) * 0.3, sin(a1) * 0.36, 0), 0.09, "leather", true)
	Props.obox(tb, Vector3(10.4, -1.5, 0), Vector3(0.04, 1.2, 0.012), "leather", Vector3(0, 0, 6))
	Props.obox(tb, Vector3(10.55, -1.6, 0.02), Vector3(0.04, 1.0, 0.012), "leather", Vector3(0, 0, -9))
	Props.obox(tb, Vector3(10.47, -2.05, 0.01), Vector3(0.3, 0.03, 0.012), "leather")
	Props.cable(tb, Vector3(12.6, 0, 0), Vector3(12.6, -1.1, 0), 0.0, 0.012, 2, "rope")
	Props.cyl(tb, Vector3(12.6, -1.25, 0), 0.15, 0.3, "tin")
	Props.cable(tb, Vector3(9.0, 0, 0), Vector3(9.0, -0.7, 0), 0.0, 0.012, 2, "rope")
	Props.obox(tb, Vector3(9.0, -0.95, 0), Vector3(0.2, 0.5, 0.03), "leather", Vector3(0, 0, 12))


func _dress_exterior() -> void:
	var g: Node3D = Props.group(dress, "Exterior", Vector3.ZERO)
	# half-timbering on the inn's outer faces (north, west, east)
	for x: float in [0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0]:
		if absf(x - 7.0) < 1.0 or absf(x - 17.0) < 1.0:
			continue
		Props.block(g, Vector3(x - 0.13, 0, -0.27), Vector3(x + 0.13, UP_TOP, -0.15), "beam")
	for y: float in [0.25, TAP_H, UP_TOP - 0.1]:
		if y < 1.0:   # the front door (x 19.2..20.8) breaks the north sill beam (T-072)
			Props.block(g, Vector3(-0.27, y - 0.12, -0.27), Vector3(FRONT_DOOR_X - 0.8, y + 0.12, -0.15), "beam")
			Props.block(g, Vector3(FRONT_DOOR_X + 0.8, y - 0.12, -0.27), Vector3(24.27, y + 0.12, -0.15), "beam")
		else:
			Props.block(g, Vector3(-0.27, y - 0.12, -0.27), Vector3(24.27, y + 0.12, -0.15), "beam")
		Props.block(g, Vector3(-0.27, y - 0.12, -0.15), Vector3(-0.15, y + 0.12, 16.15 if y > 3.0 else 7.85), "beam")   # (the Old Cellar's lean-to covers z 7.85+)
		if y < 1.0:   # the cellar door (z 10.7..12.3) breaks the sill beam
			Props.block(g, Vector3(24.15, y - 0.12, -0.15), Vector3(24.27, y + 0.12, 10.6), "beam")
			Props.block(g, Vector3(24.15, y - 0.12, 12.4), Vector3(24.27, y + 0.12, 16.15), "beam")
		else:
			Props.block(g, Vector3(24.15, y - 0.12, -0.15), Vector3(24.27, y + 0.12, 16.15 if y < 4.0 else 10.15), "beam")
	for i: int in 6:
		var x0: float = 0.2 + i * 4.0
		Props.obox(g, Vector3(x0 + 1.5, UP_Y + 1.5, -0.22), Vector3(0.18, 3.6, 0.08), "beam", Vector3(0, 0, 40 if i % 2 == 0 else -40))
	_half_timber_sides(g)
	# pitched roofs with snow (inn, stair tower, stable) and the chimney stack
	_gable(g, Vector3(-0.6, UP_TOP + 0.2, -0.8), Vector3(24.6, UP_TOP + 0.2, 10.8), 3.4)
	_gable(g, Vector3(STAIR_X1 + 0.1, TAP_H + 0.3, 9.8), Vector3(24.6, TAP_H + 0.3, 16.6), 1.0)
	_gable(g, Vector3(STB_X0 - 0.4, STABLE_H + 0.2, STB_Z0 - 0.4), Vector3(STB_X1 + 0.6, STABLE_H + 0.2, STB_Z1 + 0.4), 3.2)
	Props.block(g, Vector3(11.3, UP_TOP, 0.0), Vector3(12.7, 11.4, 1.0), "stone")
	Props.block(g, Vector3(11.2, 11.3, -0.1), Vector3(12.8, 11.5, 1.1), "snow")
	Props.smoke(g, Vector3(12.0, 11.6, 0.5), 0.3, 1.2, 14)
	# porch posts' snow caps and drifts against the walls
	for d: Array in [[Vector3(-1.2, 0, 5.4), Vector3(2.4, 0.9, 4.4)], [Vector3(25.4, 0, 5.3), Vector3(2.0, 0.8, 3.0)], [Vector3(12, 0, -1.0), Vector3(6, 0.7, 1.8)],   # (clear of the lean-to and the light wells, T-051)
			[Vector3(4, 0, 17.5), Vector3(5, 1.0, 2.2)], [Vector3(STB_X1 + 1.3, 0.25, 27), Vector3(2.2, 0.8, 8)], [Vector3(12.2, 0, 35.4), Vector3(5.6, 1.0, 2.2)],   # kept above the cellar ceiling; clear of the yard door (T-072)
			[Vector3(STB_X0 - 1.4, 0, 28), Vector3(2.4, 1.0, 9)], [Vector3(-3, 0, -6), Vector3(5, 0.6, 4)], [Vector3(32, 0, 7), Vector3(6, 0.8, 5)]]:
		Props.snow_drift(g, d[0], d[1])
	Props.block(g, Vector3(1.5, UP_Y, -2.4), Vector3(6.5, UP_Y + 0.08, -0.15), "snow", false)
	Props.block(g, Vector3(17.5, UP_Y, -2.4), Vector3(22.5, UP_Y + 0.08, -0.15), "snow", false)
	# the crossroads: two trodden tracks, a signpost, fences, dead trees
	Props.block(g, Vector3(-45, 0.0, -9.5), Vector3(70, 0.015, -6.0), "snow_trodden", false)
	Props.block(g, Vector3(-12.5, 0.0, -40), Vector3(-9.0, 0.015, 75), "snow_trodden", false)
	Props.signpost(g, Vector3(-8.2, 0, -10.6), [["KALTENBRUNN  9 km", 90.0], ["WILCZA GÓRA  6 km", 160.0], ["BRESLAU  74 km", -90.0], ["GASTHAUS ZUM KREUZWEG", 20.0]])
	# (the field's fences are the grounds' since T-080: OUT_FENCES, real ones, drawn by _dress_grounds)
	for t: Array in OUT_DEAD_TREES:   # (the carters' road's five, seeds 131..135, are drawn with the road)
		if int(t[1]) < 131 or int(t[1]) > 135:
			Props.dead_tree(g, t[0], int(t[1]), float(t[2]))
	# a dead horse cart by the road and a field telephone pole line
	Props.cart(g, Vector3(-17, 0, -3), 20.0)
	for i: int in 6:
		var pp: Vector3 = Vector3(-30 + i * 14.0, 0, -15.5)
		Props.cyl(g, pp + Vector3(0, 3.5, 0), 0.12, 7.0, "beam", Vector3(0, 0, (i % 2) * 4.0 - 2.0))
		Props.block(g, pp + Vector3(-0.8, 6.4, -0.05), pp + Vector3(0.8, 6.5, 0.05), "beam")
	# weather: snow over the open ground, dust motes in the warm rooms
	var snow: Node3D = Node3D.new()
	snow.set_script(load("res://gravelight/world/snowfall.gd"))
	snow.name = "Snowfall"
	snow.set("areas", [AABB(Vector3(-40, 0, -40), Vector3(105, 22, 37)), AABB(Vector3(-40, 0, -3), Vector3(37, 22, 43)),
		AABB(Vector3(27, 0, -3), Vector3(38, 22, 43)), AABB(Vector3(-40, 0, 37), Vector3(105, 22, 33)),
		AABB(Vector3(0, 0, 16.6), Vector3(17.6, 14, 5.2)), AABB(Vector3(2, 0, 34), Vector3(32, 16, 14))] as Array[AABB])
	snow.set("density", 0.4)
	map_root.add_child(snow)
	var motes: Node3D = Node3D.new()
	motes.set_script(load("res://gravelight/world/snowfall.gd"))
	motes.name = "DustMotes"
	motes.set("areas", [AABB(Vector3(1, 0.3, 1), Vector3(22, 3.0, 14)), AABB(Vector3(STB_X0 + 0.5, 0.3, 23), Vector3(STB_X1 - STB_X0 - 1.0, 6, 10))] as Array[AABB])
	motes.set("motes", true)
	map_root.add_child(motes)


## T-093: the half-timbering on the inn's west and east faces (only the north had its posts and braces): studs between
## the sill, the storey rail and the wall plate, clear of the windows, the cellar door and the Old Cellar's lean-to,
## and K-braces in the upper storey, dark oak over the plaster (the east face south of z 10 is inside the cellar's
## stair hall, so it gets none). Dressing only (0.12 m proud of the wall, like the
## north face's).
func _half_timber_sides(g: Node3D) -> void:
	# [outer face x, outward sign, ground-floor stud z list, upper-storey stud z list, upper storey's z extent]
	for side: Array in [[-0.15, -1.0, [2.5, 4.8, 7.2], [0.0, 2.5, 5.0, 7.5, 10.0, 13.0, 16.0], 16.0],
			[24.15, 1.0, [2.5, 5.0, 6.95, 9.05], [0.0, 2.5, 5.0, 7.5, 10.0], 10.0]]:
		var fx: float = float(side[0])
		var o: float = float(side[1])
		var x0: float = fx if o > 0 else fx - 0.12
		var x1: float = fx + 0.12 if o > 0 else fx
		for z: float in side[2]:
			Props.block(g, Vector3(x0, 0.0, z - 0.12), Vector3(x1, TAP_H, z + 0.12), "beam")
		var studs: Array = side[3]
		for k: int in studs.size():
			var z2: float = float(studs[k])
			Props.block(g, Vector3(x0, TAP_H, z2 - 0.12), Vector3(x1, UP_TOP, z2 + 0.12), "beam")
			if k < studs.size() - 1 and float(studs[k + 1]) <= float(side[4]):
				var zc: float = (z2 + float(studs[k + 1])) * 0.5
				Props.obox(g, Vector3((x0 + x1) * 0.5, UP_Y + 1.4, zc), Vector3(0.08, 3.4, 0.18), "beam", Vector3(38.0 if k % 2 == 0 else -38.0, 0, 0))


## The grounds' drawing (T-080; colliders: build_grounds): the boundary fences and the spruce tree line beyond them
## (the four roads run on into the dark between the trees), the solid props, the lamp posts and lanterns, drifts.
func _dress_grounds() -> void:
	var g: Node3D = Props.group(dress, "Grounds", Vector3.ZERO)
	var segs: Array = _cut_pockets(OUT_FENCES)   # (the edge fences break at the spawn pockets, T-084)
	for i: int in segs.size():
		var f: Array = segs[i]
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		Props.fence(g, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), 30 + i)
	# a rail down in the snow at each broken bay of the edge fence
	var pr: RandomNumberGenerator = RandomNumberGenerator.new()
	pr.seed = 84
	for r: Rect2 in edge_pockets():
		var c: Vector2 = r.get_center()
		var side: int = _pocket_side(Vector3(c.x, 0, c.y))
		var on_line: Vector2 = Vector2(c.x, OUT_MIN.y if side == 0 else OUT_MAX.y) if side < 2 else Vector2(OUT_MIN.x if side == 2 else OUT_MAX.x, c.y)
		var inward: Vector2 = Vector2(0, 1) if side == 0 else (Vector2(0, -1) if side == 1 else (Vector2(1, 0) if side == 2 else Vector2(-1, 0)))
		var at: Vector2 = on_line + inward * 0.9
		Props.obox(g, Vector3(at.x, 0.12, at.y), Vector3(1.6, 0.06, 0.1) if side < 2 else Vector3(0.1, 0.06, 1.6), "beam", Vector3(0, pr.randf_range(-25, 25), pr.randf_range(-6, 6)))
	_tree_line(g)
	# the woodshed by the west road: plank walls, a lean-to roof falling to the south, a door, logs stacked on its
	# east side under the eave, snow on the roof and drifted against the north wall
	var sh: Node3D = Props.group(g, "Woodshed", Vector3(-4.5, 0, 58.5))
	Props.block(sh, Vector3(-2.5, 0, -1.75), Vector3(2.5, 2.35, 1.75), "planks")
	for bx: float in [-2.45, -0.8, 0.8, 2.45]:
		Props.block(sh, Vector3(bx - 0.08, 0, -1.8), Vector3(bx + 0.08, 2.4, -1.72), "beam")
	Props.obox(sh, Vector3(0, 2.55, 0.0), Vector3(5.5, 0.14, 4.3), "roof", Vector3(-9, 0, 0))
	Props.obox(sh, Vector3(0, 2.66, -0.05), Vector3(5.6, 0.1, 4.1), "snow", Vector3(-9, 0, 0))
	Props.block(sh, Vector3(-1.4, 0.02, -1.79), Vector3(-0.3, 1.95, -1.75), "board_wood_v")
	Props.block(sh, Vector3(-0.4, 0.95, -1.82), Vector3(-0.34, 1.05, -1.79), "iron")
	Props.block(sh, Vector3(0.9, 1.2, -1.78), Vector3(1.7, 1.75, -1.75), "window_dark")
	Props.snow_drift(sh, Vector3(1.2, 0, -2.2), Vector3(3.0, 0.6, 1.2))
	for row: int in 3:
		for k: int in 5:
			Props.cyl(sh, Vector3(2.75, 0.17 + row * 0.3, -1.2 + k * 0.6), 0.15, 0.9, "pine" if (row + k) % 2 == 0 else "beam", Vector3(0, 0, 90))
	Props.wall_lamp(sh, Vector3(1.5, 2.05, -1.75), 0.0)
	# the hay rick in the north field: a round stack, its thatched cap, snow on top
	Props.cyl(g, Vector3(22.0, 1.0, -23.5), 1.7, 2.0, "hay")
	Props.cone(g, Vector3(22.0, 2.55, -23.5), 1.85, 1.1, "hay")
	Props._noshadow(Props.ball(g, Vector3(22.0, 2.75, -23.5), Vector3(2.4, 0.7, 2.4), "snow"))
	Props.cyl(g, Vector3(22.0, 3.3, -23.5), 0.05, 1.0, "beam")
	# the wayside shrine at the crossroads: a crucifix under a little roof on a post, a wreath, snow on the roof
	var wr: Node3D = Props.group(g, "Shrine", Vector3(-15.4, 0, -11.4), 35.0)
	Props.block(wr, Vector3(-0.1, 0, -0.1), Vector3(0.1, 2.0, 0.1), "beam")
	Props.block(wr, Vector3(-0.32, 1.25, -0.22), Vector3(0.32, 2.0, 0.12), "furniture")
	Props.block(wr, Vector3(-0.025, 1.4, -0.25), Vector3(0.025, 1.85, -0.22), "beam")
	Props.block(wr, Vector3(-0.13, 1.68, -0.25), Vector3(0.13, 1.72, -0.22), "beam")
	for sx: float in [-1.0, 1.0]:
		Props.obox(wr, Vector3(sx * 0.2, 2.13, -0.05), Vector3(0.46, 0.05, 0.6), "roof", Vector3(0, 0, -32 * sx))
		Props.obox(wr, Vector3(sx * 0.2, 2.17, -0.05), Vector3(0.44, 0.04, 0.58), "snow", Vector3(0, 0, -32 * sx))
	Props.cyl(wr, Vector3(0, 1.2, -0.13), 0.13, 0.04, "pine", Vector3(90, 0, 0))
	# the hay wagon left on the west road's verge
	Props.cart(g, Vector3(-15.6, 0, 22.0), 8.0)
	Props._noshadow(Props.ball(g, Vector3(-15.6, 1.15, 22.0), Vector3(1.6, 0.4, 2.4), "snow"))
	# the abandoned machine-gun nest in the north field: an L of sandbags, an upturned helmet, ammunition tins
	Props.sandbags(g, Vector3(30.0, 0, -22.0), Vector3(34.5, 0, -22.0), 3)
	Props.sandbags(g, Vector3(34.5, 0, -22.0), Vector3(34.5, 0, -18.5), 3)
	PropsStory.helmet(g, Vector3(32.0, 0.0, -21.2), 40.0, true)
	for ap: Vector3 in [Vector3(33.4, 0.0, -21.1), Vector3(33.7, 0.0, -20.7)]:
		Props.block(g, ap + Vector3(-0.14, 0, -0.08), ap + Vector3(0.14, 0.18, 0.08), "olive_steel")
	Props._noshadow(Props.ball(g, Vector3(32.2, 0.85, -22.0), Vector3(4.0, 0.25, 0.8), "snow"))
	# GRAVELIGHT ONE's torn-off engine and a wing panel thrown clear, a burnt-out car on the east road's verge
	var en: Node3D = Props.group(g, "Engine", Vector3(34.5, 0, -13.2), 30.0)
	Props.cyl(en, Vector3(0, 0.6, 0), 0.6, 2.2, "wreck", Vector3(90, 0, 0))
	Props.cyl(en, Vector3(0, 0.6, -1.15), 0.5, 0.15, "char", Vector3(90, 0, 0))
	Props.obox(en, Vector3(0.3, 0.9, -1.3), Vector3(0.18, 1.4, 0.06), "iron", Vector3(0, 0, 35))
	Props.obox(en, Vector3(-0.3, 0.25, -1.3), Vector3(0.18, 1.0, 0.06), "iron", Vector3(0, 0, 70))
	Props._noshadow(Props.cyl(g, Vector3(34.5, 0.01, -13.2), 2.2, 0.02, "char"))
	Props.smoke(en, Vector3(0, 1.3, 0.2), 0.3, 1.2, 8)
	var wp: Node3D = Props.group(g, "WingPanel", Vector3(56.0, 0, 25.0), 70.0)
	Props.obox(wp, Vector3(0, 0.7, 0), Vector3(5.0, 1.4, 0.2), "wreck", Vector3(8, 0, 4))
	Props.obox(wp, Vector3(-1.2, 1.05, 0.12), Vector3(1.6, 0.06, 0.05), "char")
	Props._noshadow(Props.ball(wp, Vector3(0.4, 0.05, 0.4), Vector3(4.0, 0.4, 1.4), "snow"))
	LandscapeProps.burnt_car(g, Vector3(49.0, -0.1, -14.5), 100.0, -6.0)
	for dp: Vector3 in [Vector3(46.6, 0, 44.3), Vector3(47.4, 0, 44.25), Vector3(47.0, 0, 43.6)]:
		Props.oil_drum(g, dp, "rust")
	Props.oil_drum(g, Vector3(48.3, 0, 45.0), "rust", true)
	# the road exits: a spruce felled across the north road, striped barriers (STRASSE GESPERRT) east and south, a
	# barrier boom on the west road
	var fs: Node3D = Props.group(g, "FelledSpruce", Vector3(-10.75, 0, -29.0), 4.0)
	Props.cyl(fs, Vector3(0, 0.35, 0), 0.35, 6.5, "beam", Vector3(0, 0, 90))
	Props._noshadow(Props.ball(fs, Vector3(0, 0.7, 0), Vector3(6.4, 0.25, 0.6), "snow"))
	for k2: int in 7:
		Props.obox(fs, Vector3(-2.8 + k2 * 0.9, 0.5, 0.35 * (1.0 if k2 % 2 == 0 else -1.0)), Vector3(0.06, 0.06, 1.4), "pine", Vector3(20, 25 * (k2 % 3 - 1), 0))
	Props.cyl(fs, Vector3(3.4, 0.4, 0), 0.5, 0.3, "pine", Vector3(0, 0, 90))
	for br: Array in [[Vector3(59.0, 0, -7.75), 90.0, 4.4], [Vector3(37.0, 0, 63.0), 0.0, 5.0], [Vector3(-10.75, 0, 63.0), 0.0, 4.4]]:
		_sawhorse(g, br[0], float(br[1]), float(br[2]))
	var bw: Node3D = Props.group(g, "BarrierBoom", Vector3(-19.2, 0, -7.75), 90.0)
	for sx2: float in [-2.2, 2.2]:
		Props.block(bw, Vector3(sx2 - 0.1, 0, -0.1), Vector3(sx2 + 0.1, 1.1, 0.1), "beam")
	for k3: int in 6:
		Props.block(bw, Vector3(-2.3 + k3 * 0.766, 0.92, -0.06), Vector3(-2.3 + (k3 + 1) * 0.766, 1.04, 0.06), "red_paint" if k3 % 2 == 0 else "paint_cream")
	# lamp posts: an oil lantern at the crossroads by the inn's west corner, one on the east road past the crash field
	for lp: Vector3 in [Vector3(-7.6, 0, -4.6), Vector3(37.0, 0, -10.8)]:
		Props.cyl(g, lp + Vector3(0, 1.6, 0), 0.08, 3.2, "beam")
		Props.block(g, lp + Vector3(-0.05, 3.0, -0.05), lp + Vector3(0.75, 3.1, 0.05), "beam")
		Props.lantern(g, lp + Vector3(0.65, 2.55, 0), 3.0)
	# the porch lantern over the front door (under the east porch roof)
	Props.lantern(g, Vector3(21.2, 2.75, -1.9), TAP_H)
	# drifts along the outer fences and in the field
	for d: Array in [[Vector3(-18.5, 0, 6), Vector3(2.4, 0.8, 9)], [Vector3(-18.6, 0, 40), Vector3(2.2, 0.7, 12)], [Vector3(58.6, 0, 30), Vector3(2.4, 0.8, 14)],
			[Vector3(20, 0, 62.6), Vector3(14, 0.8, 2.4)], [Vector3(30, 0, -28.6), Vector3(16, 0.7, 2.2)], [Vector3(-4, 0, -28.6), Vector3(8, 0.6, 2.0)],
			[Vector3(46, 0, 58), Vector3(6, 0.6, 3.0)], [Vector3(-10.75, 0, 63.6), Vector3(5.0, 0.9, 1.6)]]:
		Props.snow_drift(g, d[0], d[1])


## Snow-laden spruces in two ragged rows just beyond the edge (Landscape's pine mesh with the near-forest shader),
## leaving the four roads open, and a few dead trees among them. Nothing collides: the edge wall is inside them.
func _tree_line(g: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1944
	var xf: Array[Transform3D] = []
	var gaps: Array = [Rect2(-15.0, -45.0, 8.5, 20.0), Rect2(-15.0, 60.0, 8.5, 20.0), Rect2(31.5, 60.0, 11.0, 20.0),
		Rect2(-40.0, -11.5, 25.0, 7.5), Rect2(55.0, -11.5, 25.0, 7.5)]
	for pk: Rect2 in edge_pockets():   # no trunk in a spawn pocket (T-084): the zombies walk in between the trees
		gaps.append(pk.grow(0.9))
	var edges: Array = [[Vector2(OUT_MIN.x, OUT_MIN.y), Vector2(OUT_MAX.x, OUT_MIN.y), Vector2(0, -1)], [Vector2(OUT_MIN.x, OUT_MAX.y), Vector2(OUT_MAX.x, OUT_MAX.y), Vector2(0, 1)],
		[Vector2(OUT_MIN.x, OUT_MIN.y), Vector2(OUT_MIN.x, OUT_MAX.y), Vector2(-1, 0)], [Vector2(OUT_MAX.x, OUT_MIN.y), Vector2(OUT_MAX.x, OUT_MAX.y), Vector2(1, 0)]]
	for e: Array in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var out: Vector2 = e[2]
		var length: float = a.distance_to(b)
		for row: int in 2:
			var t: float = rng.randf_range(0.0, 2.0)
			while t < length + 4.0:
				var p: Vector2 = a + (b - a).normalized() * (t - 2.0) + out * (rng.randf_range(2.2, 4.5) + row * 3.6)
				var skip: bool = false
				for r: Rect2 in gaps:
					if r.has_point(p):
						skip = true
				if not skip:
					if rng.randf() < 0.12:
						Props.dead_tree(g, Vector3(p.x, 0, p.y), 2000 + xf.size(), rng.randf_range(6.0, 9.0))
					else:
						var hgt: float = rng.randf_range(8.0, 14.0) * (1.0 if row == 0 else 1.15)
						var sc: Vector3 = Vector3(hgt * rng.randf_range(0.36, 0.46), hgt, hgt * rng.randf_range(0.36, 0.46))
						xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sc), Vector3(p.x, -0.3, p.y)))
				t += rng.randf_range(2.6, 4.2)
	# T-093: the scripted spruces (and a birch here and there) instead of the cone pines, built at load time by a
	# NatureRows node from these transforms; bare bushes and boulders between the rows (the same RNG draws as
	# before for the trees, so the line is where it was)
	var rows: NatureRows = NatureRows.new()
	rows.name = "EdgeTrees"
	var urng: RandomNumberGenerator = RandomNumberGenerator.new()
	urng.seed = 2084
	for x0: Transform3D in xf:
		var ux: Transform3D = Landscape.uniform_tree_xform(x0)
		if Landscape.is_birch(x0.origin):
			rows.birches.append(ux)
		else:
			rows.spruces.append(ux)
		if urng.randf() < 0.45:   # a bush or a rock beside it, on the field side
			var off: Vector3 = Vector3(urng.randf_range(-1.6, 1.6), 0.0, urng.randf_range(-1.6, 1.6))
			var bp: Vector3 = Vector3(x0.origin.x, 0.0, x0.origin.z) + off
			if _in_grounds(bp, -0.9):
				continue   # never inside the edge
			var s: float = urng.randf_range(0.8, 1.5)
			if urng.randf() < 0.7:
				rows.bushes.append(Transform3D(Basis(Vector3.UP, urng.randf() * TAU).scaled(Vector3(s, s, s)), bp - Vector3(0, 0.05, 0)))
			else:
				rows.rocks.append(Transform3D(Basis(Vector3.UP, urng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), bp - Vector3(0, 0.2, 0)))
	g.add_child(rows)
	print("grounds: %d edge spruces" % xf.size())


## A road-closed sawhorse: two splayed trestles and a striped board, "STRASSE GESPERRT" on it. yaw: the board's
## line (0 = along X).
func _sawhorse(parent: Node3D, pos: Vector3, yaw: float, width: float) -> void:
	var s: Node3D = Props.group(parent, "Sawhorse", pos, yaw)
	for sx: float in [-width * 0.5 + 0.2, width * 0.5 - 0.2]:
		for lz: float in [-1.0, 1.0]:
			Props.obox(s, Vector3(sx, 0.45, lz * 0.18), Vector3(0.07, 0.95, 0.07), "beam", Vector3(lz * 20.0, 0, 0))
	var n: int = 6
	for k: int in n:
		Props.block(s, Vector3(-width * 0.5 + k * width / n, 0.78, -0.03), Vector3(-width * 0.5 + (k + 1) * width / n, 0.98, 0.03), "red_paint" if k % 2 == 0 else "paint_cream")
	var l: Label3D = Label3D.new()
	l.text = "STRASSE GESPERRT"
	l.font_size = 40
	l.pixel_size = 0.004
	l.modulate = Color(0.1, 0.08, 0.07)
	l.outline_size = 0
	l.position = Vector3(0, 0.6, -0.05)
	l.rotation.y = PI
	s.add_child(l)
	Props._noshadow(Props.ball(s, Vector3(0, 0.98, 0), Vector3(width, 0.08, 0.12), "snow"))


## The carters' road behind the stable's great doors (the campaign exfil, T-033: the doors fall outward at
## round 10 and the squad walks out; the Map 0 -> Map 1 cutscene looks down this road). Cutscene-only, so all of
## it is dressing: a trodden track south through a gap in the yard fence, bending east toward Kaltenbrunn, with
## gateposts and a signpost at the gap, drifts and dead trees (the land past the slab's edge at z 75 / x 70 is the
## Landscape node's terrain, T-052). Cheap: ~40 primitives.
func _dress_carters_road() -> void:
	var g: Node3D = Props.group(dress, "CartersRoad", Vector3.ZERO)
	# the track: out of the doorway, through the fence gap, then a bend to the south-east
	Props.block(g, Vector3(16.0, 0.0, 34.2), Vector3(20.2, 0.018, 41.5), "snow_trodden", false)
	Props.block(g, Vector3(16.3, 0.0, 41.0), Vector3(20.5, 0.018, 50.0), "snow_trodden", false)
	Props.obox(g, Vector3(23.5, 0.009, 54.0), Vector3(4.4, 0.018, 12.0), "snow_trodden", Vector3(0, 40, 0))
	Props.obox(g, Vector3(32.0, 0.009, 60.5), Vector3(4.6, 0.018, 16.0), "snow_trodden", Vector3(0, 55, 0))
	Props.obox(g, Vector3(45.0, 0.009, 68.0), Vector3(5.0, 0.018, 22.0), "snow_trodden", Vector3(0, 68, 0))
	# ruts and a cart's furrow where the doors land
	for dx: float in [-0.9, 0.9]:
		Props.block(g, Vector3(18.0 + dx - 0.08, 0.012, 34.3), Vector3(18.0 + dx + 0.08, 0.026, 47.7), "dirt", false)
	# gateposts at the fence gap, a signpost beside them, a lantern post that has gone out
	for gx: float in [15.8, 20.2]:
		Props.block(g, Vector3(gx - 0.16, 0, 47.84), Vector3(gx + 0.16, 2.3, 48.16), "beam")
		Props.block(g, Vector3(gx - 0.22, 2.3, 47.78), Vector3(gx + 0.22, 2.45, 48.22), "snow", false)
	Props.signpost(g, Vector3(22.9, 0, 49.6), [["KALTENBRUNN  9 km", 120.0], ["WILCZA GÓRA  6 km", -150.0], ["GASTHAUS ZUM KREUZWEG", 0.0]])
	# drifts along the stable's south wall and the fence, a broken cart wheel in the snow
	Props.snow_drift(g, Vector3(23.5, 0, 35.3), Vector3(4.5, 0.9, 2.0))
	Props.snow_drift(g, Vector3(8, 0, 49.2), Vector3(10, 0.8, 2.4))
	Props.snow_drift(g, Vector3(29, 0, 49.0), Vector3(8, 0.9, 2.2))
	Props.snow_drift(g, Vector3(24.5, 0, 46.0), Vector3(5, 0.6, 3.0))
	Props.cyl(g, Vector3(13.0, 0.35, 37.2), 0.55, 0.08, "beam", Vector3(70, 20, 0))
	# dead trees along the road and the horizon's rises (half-buried domes of snow past the fog)
	Props.dead_tree(g, Vector3(31, 0, 52), 131, 7.0)
	Props.dead_tree(g, Vector3(12, 0, 55), 132, 8.5)
	Props.dead_tree(g, Vector3(38, 0, 52), 133, 6.5)
	Props.dead_tree(g, Vector3(22, 0, 66), 134, 9.0)
	Props.dead_tree(g, Vector3(52, 0, 60), 135, 7.5)
	# (the horizon's rises that used to hide the slab's edge here are now the Landscape's terrain, T-052)


## The Carters' Yard: the drawn fences over the colliders, the barred gate, the well with its windlass, the
## woodpile, the snowed cart and trough, a lit lantern on the gatepost, a lamp over the yard door, paths, drifts.
func _dress_yard() -> void:
	var g: Node3D = Props.group(dress, "Yard", Vector3.ZERO)
	Props.fence(g, Vector3(2, 0, 34), Vector3(2, 0, 40.2), 11)
	Props.fence(g, Vector3(2, 0, 41.8), Vector3(2, 0, 48), 12)
	Props.fence(g, Vector3(34, 0, 34), Vector3(34, 0, 40.2), 13)
	Props.fence(g, Vector3(34, 0, 41.8), Vector3(34, 0, 48), 14)
	Props.fence(g, Vector3(2, 0, 48), Vector3(8.2, 0, 48), 15)
	Props.fence(g, Vector3(9.8, 0, 48), Vector3(15.8, 0, 48), 16)
	Props.fence(g, Vector3(20.2, 0, 48), Vector3(26.2, 0, 48), 17)
	Props.fence(g, Vector3(27.8, 0, 48), Vector3(34, 0, 48), 18)
	Props.fence(g, Vector3(STB_X1 + 0.2, 0, 34), Vector3(34, 0, 34), 19)
	Props.fence(g, Vector3(2, 0, 34), Vector3(STB_X0 - 0.2, 0, 34), 20)
	# the fence gaps: a post either side and a snow-capped sill rail (the barricades hang in them)
	for gp: Array in [[Vector3(2, 0, 40.2), Vector3(2, 0, 41.8)], [Vector3(34, 0, 40.2), Vector3(34, 0, 41.8)],
			[Vector3(8.2, 0, 48), Vector3(9.8, 0, 48)], [Vector3(26.2, 0, 48), Vector3(27.8, 0, 48)]]:
		for e: Vector3 in [gp[0], gp[1]]:
			Props.block(g, e + Vector3(-0.1, 0, -0.1), e + Vector3(0.1, 2.4, 0.1), "beam")
		var lo: Vector3 = gp[0]
		var hi: Vector3 = gp[1]
		Props.block(g, Vector3(minf(lo.x, hi.x) - 0.08, WIN_SILL - 0.1, minf(lo.z, hi.z) - 0.08), Vector3(maxf(lo.x, hi.x) + 0.08, WIN_SILL, maxf(lo.z, hi.z) + 0.08), "beam")
	# (the gate's two leaves and their chain are Door_Gate's own since T-080: GateDoor draws and swings them)
	# the well: a stone ring, two posts, a windlass and a bucket; the crate spot's lantern stake stands beside it
	Props.cyl(g, Vector3(10.0, 0.5, 42.0), 1.05, 1.0, "stone")
	Props.cyl(g, Vector3(10.0, 1.02, 42.0), 1.1, 0.06, "snow")
	Props._noshadow(Props.cyl(g, Vector3(10.0, 0.6, 42.0), 0.78, 0.9, "char"))
	for px: float in [9.1, 10.9]:
		Props.block(g, Vector3(px - 0.08, 1.0, 41.92), Vector3(px + 0.08, 2.3, 42.08), "beam")
	Props.block(g, Vector3(8.9, 2.3, 41.6), Vector3(11.1, 2.42, 42.4), "planks")
	Props.cyl(g, Vector3(10.0, 2.0, 42.0), 0.09, 1.9, "beam", Vector3(0, 0, 90))
	Props.cable(g, Vector3(10.0, 2.0, 42.0), Vector3(10.0, 1.1, 42.0), 0.0, 0.015, 2, "rope")
	Props.cyl(g, Vector3(10.0, 1.2, 42.0), 0.16, 0.24, "tin")
	# the woodpile: stacked split logs against the stable wall, an axe in the block
	var wr: RandomNumberGenerator = RandomNumberGenerator.new()
	wr.seed = 44
	for row: int in 4:
		for k: int in 6:
			Props.cyl(g, Vector3(13.55 + k * 0.42, 0.18 + row * 0.3, 34.75), 0.15, 1.1, "pine" if (row + k) % 2 == 0 else "beam", Vector3(90, 0, wr.randf_range(-6, 6)))
	_lib("stump_chopping", Vector3(9.4, 0.0, 36.2), 30.0, Vector3(0.45, 1.0, 0.42))
	_lib("axe_wood", Vector3(9.42, 0.5, 36.2), 20.0, Vector3.ONE, false, Vector3(0, 0, -28))
	# the snowed cart and the trough
	Props.cart(g, Vector3(28.3, 0, 38.1), 100.0)
	Props._noshadow(Props.ball(g, Vector3(28.3, 1.2, 38.1), Vector3(2.4, 0.5, 1.6), "snow"))
	Props.block(g, Vector3(30.5, 0, 44.0), Vector3(33.5, 0.7, 45.0), "planks")
	Props.block(g, Vector3(30.6, 0.55, 44.1), Vector3(33.4, 0.62, 44.9), "snow")
	# paths, drifts, a dropped sledge
	Props.block(g, Vector3(7.2, 0.0, 34.2), Vector3(9.0, 0.015, 48.0), "snow_trodden", false)
	Props.block(g, Vector3(7.2, 0.0, 41.3), Vector3(16.0, 0.015, 42.7), "snow_trodden", false)
	Props.snow_drift(g, Vector3(3.2, 0, 36.5), Vector3(2.4, 0.9, 4.0))
	Props.snow_drift(g, Vector3(32.6, 0, 36.0), Vector3(2.6, 0.8, 3.0))
	Props.snow_drift(g, Vector3(4.6, 0, 46.2), Vector3(3.6, 0.7, 2.6))
	Props.block(g, Vector3(22.0, 0.05, 44.0), Vector3(23.0, 0.12, 46.2), "planks")
	Props.block(g, Vector3(21.95, 0.0, 44.0), Vector3(22.05, 0.08, 46.2), "iron")
	Props.block(g, Vector3(22.95, 0.0, 44.0), Vector3(23.05, 0.08, 46.2), "iron")
	# lights: a lantern on the gatepost, a lamp over the yard door, the stable's south-wall lamp by the Thompson
	Props.block(g, Vector3(20.36, 1.9, 47.9), Vector3(20.72, 2.3, 48.1), "lantern_glass")
	_lamp("GateLantern", Vector3(20.5, 2.1, 47.4), Color(1.0, 0.62, 0.3), 6.0, 15.0, false, true, 0.25)
	Props.wall_lamp(g, Vector3(8.0, 2.75, 34.2), 180.0)
	_lamp("YardDoorLamp", Vector3(8.0, 2.6, 34.9), Color(1.0, 0.62, 0.32), 7.5, 16.0, true, true, 0.15)
	Props.wall_lamp(g, Vector3(19.2, 2.75, 34.2), 180.0)   # (west of the hoist ledge over the Thompson since T-084)
	_lamp("YardWallLamp", Vector3(19.2, 2.6, 34.9), Color(1.0, 0.62, 0.32), 6.5, 15.0, false, true, 0.15)
	# the hoist over the loft door (T-084): the beam out of the gable, its pulley and rope down to the ledge, the
	# ledge's brackets, snow on its boards
	Props.block(g, Vector3(21.85, 5.9, 33.6), Vector3(22.15, 6.15, 36.3), "beam")
	Props.cyl(g, Vector3(22.0, 5.78, 36.0), 0.14, 0.08, "iron", Vector3(0, 0, 90))
	Props.cable(g, Vector3(22.0, 5.7, 36.0), Vector3(22.0, LOFT_TOP + 0.05, 36.0), 0.0, 0.015, 2, "rope")
	Props.cyl(g, Vector3(22.0, LOFT_TOP + 0.1, 36.0), 0.14, 0.1, "iron", Vector3(90, 0, 0))
	for bx2: float in [20.4, 22.6, 24.8]:
		Props.obox(g, Vector3(bx2, 2.4, 35.0), Vector3(0.14, 0.14, 2.3), "beam", Vector3(-48, 0, 0))
	Props.block(g, Vector3(20.0, LOFT_TOP, 34.3), Vector3(25.2, LOFT_TOP + 0.06, 36.6), "snow", false)
	_lamp("YardMoonFill", Vector3(18.0, 6.0, 41.0), Color(0.5, 0.6, 0.85), 0.25, 22.0, false, false)


## A gable roof (ridge along X) over the rectangle a..b (a.y = eave height), with a snow layer on top.
func _gable(parent: Node3D, a: Vector3, b: Vector3, rise: float) -> void:
	var half: float = (b.z - a.z) * 0.5
	var slope_len: float = Vector2(half, rise).length() + 0.2
	var ang: float = rad_to_deg(atan2(rise, half))
	var cx: float = (a.x + b.x) * 0.5
	var w: float = b.x - a.x
	for side: float in [-1.0, 1.0]:
		var cz: float = a.z + half + side * -half * 0.5
		Props.obox(parent, Vector3(cx, a.y + rise * 0.5, cz), Vector3(w, 0.2, slope_len), "roof", Vector3(-ang * side, 0, 0))
		Props.obox(parent, Vector3(cx, a.y + rise * 0.5 + 0.14, cz), Vector3(w + 0.1, 0.1, slope_len - 0.3), "snow", Vector3(-ang * side, 0, 0))
		# T-093: the snow load's soft edge, a rounded lip along the eave (and a little overhang of snow)
		var ez: float = a.z if side > 0.0 else b.z
		var lip: MeshInstance3D = Props.cyl(parent, Vector3(cx, a.y + 0.12, ez + (0.12 if side > 0.0 else -0.12)), 0.16, w + 0.12, "snow", Vector3(0, 0, 90))
		lip.scale.x *= 0.55
		lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# gable end walls
	for x: float in [a.x + 0.3, b.x - 0.3]:
		for k: int in 6:
			var t: float = float(k) / 6.0
			var hz: float = half * (1.0 - (t + 1.0 / 6.0)) + 0.05
			Props.block(parent, Vector3(x - 0.12, a.y + rise * t, a.z + half - hz), Vector3(x + 0.12, a.y + rise * (t + 1.0 / 6.0), a.z + half + hz), "planks")


func _dress_wreck() -> void:
	var w: Node3D = Props.group(dress, "WreckDress", Vector3(46, 0, 6), 28.0)
	w.rotation.z = deg_to_rad(-8)
	Props.cyl(w, Vector3(0, 1.3, -0.5), 1.35, 12.5, "wreck", Vector3(90, 0, 0))     # fuselage
	Props.ball(w, Vector3(0, 1.5, -6.6), Vector3(2.4, 2.2, 2.6), "wreck")             # nose
	Props.block(w, Vector3(-0.9, 2.2, -6.4), Vector3(0.9, 2.7, -5.5), "char")         # smashed cockpit
	Props.obox(w, Vector3(-4.5, 0.6, 0), Vector3(9.0, 0.28, 3.0), "wreck", Vector3(0, 0, 4))
	Props.obox(w, Vector3(3.8, 0.4, 0.4), Vector3(6.5, 0.28, 2.8), "wreck", Vector3(0, 12, -9))   # snapped wing
	for s: float in [-1.0, 1.0]:
		Props.cyl(w, Vector3(s * 3.2, 0.9, -1.0), 0.65, 2.6, "wreck", Vector3(90, 0, 0))   # engine nacelles
		Props.cyl(w, Vector3(s * 3.2, 0.9, -2.4), 0.25, 0.3, "char", Vector3(90, 0, 0))
	Props.obox(w, Vector3(0, 3.1, 5.9), Vector3(0.18, 2.6, 2.0), "wreck", Vector3(-12, 0, 0))   # tail fin
	Props.obox(w, Vector3(0, 1.7, 6.0), Vector3(5.0, 0.18, 1.4), "wreck", Vector3(0, 0, 6))
	var l: Label3D = Label3D.new()
	l.text = "GRAVELIGHT ONE"
	l.font_size = 64
	l.pixel_size = 0.006
	l.modulate = Color(0.75, 0.72, 0.62, 0.8)
	l.position = Vector3(1.38, 1.6, -2.5)
	l.rotation.y = PI * 0.5
	w.add_child(l)
	var serial: Label3D = Label3D.new()
	serial.text = "2-100479"
	serial.font_size = 48
	serial.pixel_size = 0.006
	serial.modulate = Color(0.85, 0.8, 0.6, 0.7)
	serial.position = Vector3(0.1, 3.2, 6.2)
	serial.rotation.y = PI * 0.5
	w.add_child(serial)
	# burning: flames on the hull and the wing root, embers, a smoke column
	Props.flames(w, Vector3(0, 2.6, -2.0), 2.4, 2.2, 60)
	Props.flames(w, Vector3(-3.2, 1.0, -0.5), 1.4, 1.6, 30)
	Props.embers(w, Vector3(0, 2.8, -1.0), 2.5, 50)
	Props.smoke(w, Vector3(0, 4.0, -1.0), 1.2, 2.5, 40)
	# debris scattered in the snow
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23121944
	for i: int in 14:
		var p: Vector3 = Vector3(rng.randf_range(-12, 12), 0.1, rng.randf_range(-14, 12))
		Props.obox(dress, Vector3(46, 0, 6) + p, Vector3(rng.randf_range(0.3, 1.6), 0.08, rng.randf_range(0.3, 1.2)), "wreck",
			Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 360), rng.randf_range(-20, 20)))
	# a scorched trail through the snow toward the impact
	Props.block(dress, Vector3(52, 0.0, -25), Vector3(55, 0.016, 2), "char", false)


# ================================================================== Update 02 section 8: the small-detail polish (T-053)

## Room by room (docs/MAP0_POLISH.md): story props, wear (worn boards, grime and soot, water stains, scuffs,
## cobwebs, snow blown in at the broken windows). Everything here is dressing (no collision, batched). The
## reactive pieces (glass, curtains, doors, hay, footprints, sound) are build_reactive()'s. Nothing goes in front of
## a buy, a door or a window, or in a walking line.
func _dress_polish() -> void:
	var g: Node3D = Props.group(dress, "Polish", Vector3.ZERO)
	_polish_taproom(g)
	_polish_upstairs(g)
	_polish_stable(g)
	_barn_dressing(g)
	_polish_cellars(g)


func _polish_taproom(g: Node3D) -> void:
	# ---- the meal the patrol left: their table (16.5, 11.5) with the map, a helmet, a mess tin, cold soup; a chair
	# knocked over as they got up; a greatcoat on the bench; a gas-mask canister and the map case under the table
	PropsStory.soup_bowl(g, Vector3(16.15, 0.75, 11.15), 20.0, 0.45)
	PropsStory.mess_tin(g, Vector3(15.95, 0.75, 11.95), -30.0)
	PropsStory.helmet(g, Vector3(17.05, 0.75, 11.05), 35.0)
	PropsStory.loaf(g, Vector3(16.95, 0.75, 11.95), 70.0)
	_lib_chair(Vector3(18.0, 0, 12.75), 110.0, true)
	PropsStory.coat_drape(g, Vector3(15.6, 0.5, 15.45), 0.0)
	PropsStory.gasmask_can(g, Vector3(17.35, 0, 12.25), 40.0)
	PropsStory.map_case(g, Vector3(15.75, 0, 12.55), -20.0)
	# the table by the hearth (12.5, 11.5): two suppers half eaten, the bread
	PropsStory.plate_meal(g, Vector3(12.2, 0.75, 11.15), 15.0, 0.6)
	PropsStory.soup_bowl(g, Vector3(12.85, 0.75, 11.9), -40.0, 0.3)
	PropsStory.plate_meal(g, Vector3(12.9, 0.75, 11.05), 120.0, 0.2)
	PropsStory.loaf(g, Vector3(12.15, 0.75, 11.85), -15.0)
	# the signals table (20, 4.5): a crust, a mug of ersatz coffee beside the logbook
	PropsStory.plate_meal(g, Vector3(19.8, 0.75, 4.05), -10.0, 0.95)
	PropsStory.mug(g, Vector3(20.3, 0.75, 4.9))
	# "Soup kept warm" (the guest book, 21.XII): the pot on the hearthstone, its ladle
	Props.cyl(g, Vector3(12.75, 0.24, 1.22), 0.17, 0.24, "iron")
	Props.cyl(g, Vector3(12.75, 0.37, 1.22), 0.175, 0.02, "iron")
	Props.obox(g, Vector3(12.85, 0.5, 1.2), Vector3(0.02, 0.35, 0.02), "steel", Vector3(0, 0, -25))
	# Lene's apron on its hook by the bar end of the north wall, and a cloth on the peg beside it
	PropsStory.apron_on_hook(g, Vector3(9.05, 1.78, 0.15), 180.0)
	Props.block(g, Vector3(8.62, 1.76, 0.15), Vector3(8.66, 1.8, 0.21), "iron")
	Props.obox(g, Vector3(8.64, 1.6, 0.21), Vector3(0.2, 0.32, 0.01), "linen", Vector3(4, 0, 2))
	# ---- wear: boards scrubbed pale where people walk (the bar, the spawn, every doorway)
	for wp: Array in [[Vector3(5.2, 0, 8.95), Vector3(9.4, 0, 10.1)], [Vector3(9.25, 0, 3.4), Vector3(10.7, 0, 9.8)],
			[Vector3(6.15, 0, 13.9), Vector3(8.2, 0, 15.85)], [Vector3(18.8, 0, 13.6), Vector3(21.2, 0, 15.85)],
			[Vector3(22.2, 0, 10.4), Vector3(23.85, 0, 12.6)], [Vector3(0.15, 0, 8.0), Vector3(1.8, 0, 10.1)],
			[Vector3(13.0, 0, 5.2), Vector3(17.0, 0, 9.7)], [Vector3(10.6, 0, 4.9), Vector3(13.4, 0, 6.3)]]:
		var a: Vector3 = wp[0]
		var b: Vector3 = wp[1]
		PropsStory.stain(g, Vector3(a.x, 0.0125, a.z), Vector3(b.x, 0.0135, b.z), "floor_worn")
	# soot: the chimney breast, the lintel and the ceiling over the hearth, and a smudge over each lantern
	PropsStory.stain(g, Vector3(11.2, 1.5, 0.603), Vector3(12.8, 3.45, 0.607), "soot")
	PropsStory.stain(g, Vector3(11.4, 1.0, 0.953), Vector3(12.6, 1.42, 0.957), "soot")
	PropsStory.stain(g, Vector3(10.4, 3.493, 0.15), Vector3(13.6, 3.497, 1.9), "soot")
	for lp: Vector2 in [Vector2(6.5, 11.5), Vector2(17.5, 4.0), Vector2(19.5, 13.0), Vector2(14.0, 8.0)]:
		PropsStory.stain(g, Vector3(lp.x - 0.4, 3.493, lp.y - 0.4), Vector3(lp.x + 0.4, 3.497, lp.y + 0.4), "soot")
	# water stains: the ceiling in the north-west corner and over the east window, streaks under the north windows
	PropsStory.stain(g, Vector3(0.3, 3.492, 0.3), Vector3(2.8, 3.496, 2.3), "water_stain")
	PropsStory.stain(g, Vector3(22.4, 3.492, 6.6), Vector3(23.85, 3.496, 9.6), "water_stain")
	for wx: float in [6.0, 7.9, 16.05, 17.9]:
		PropsStory.stain(g, Vector3(wx - 0.08, 1.1, 0.152), Vector3(wx + 0.12, 2.2, 0.156), "water_stain")
	# scuffs: the bar front and side at boot height, the wainscot beside the doors
	PropsStory.stain(g, Vector3(5.1, 0.04, 8.803), Vector3(8.95, 0.42, 8.807), "scuff")
	PropsStory.stain(g, Vector3(9.003, 0.04, 3.1), Vector3(9.007, 0.42, 7.95), "scuff")
	for sx: Array in [[18.4, 18.92], [21.08, 21.6]]:   # either side of the stable door, not across it (T-072)
		PropsStory.stain(g, Vector3(float(sx[0]), 0.05, 15.81), Vector3(float(sx[1]), 0.6, 15.814), "scuff")
	PropsStory.stain(g, Vector3(6.186, 0.05, 13.6), Vector3(6.19, 0.6, 14.22), "scuff")
	# grime round the door frames, at hand height
	for gz: Array in [[13.85, 14.25], [15.95, 16.0]]:
		PropsStory.stain(g, Vector3(6.152, 1.1, float(gz[0])), Vector3(6.156, 2.1, float(gz[1])), "grime")
	for gx: Array in [[18.55, 18.9], [21.1, 21.45]]:
		PropsStory.stain(g, Vector3(float(gx[0]), 1.1, 15.843), Vector3(float(gx[1]), 2.2, 15.847), "grime")
	PropsStory.stain(g, Vector3(23.843, 1.1, 10.2), Vector3(23.847, 2.3, 10.58), "grime")
	PropsStory.stain(g, Vector3(23.843, 1.1, 12.42), Vector3(23.847, 2.3, 12.8), "grime")
	# cobwebs in the taproom's high corners
	Props.cobweb(g, Vector3(0.15, TAP_H - 0.02, 0.15), 0.0, 0.8)
	Props.cobweb(g, Vector3(23.85, TAP_H - 0.02, 0.15), -90.0, 0.7)
	Props.cobweb(g, Vector3(23.85, TAP_H - 0.02, 15.85), 180.0, 0.8)
	# snow blown in at the four broken windows
	PropsStory.snow_blown_in(g, Vector3(7.0, 0, 0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(17.0, 0, 0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(0, 0, 6.0), Vector3(1, 0, 0), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(24.0, 0, 8.0), Vector3(-1, 0, 0), WIN_SILL)


func _polish_upstairs(g: Node3D) -> void:
	var y: float = UP_Y
	# ---- Room 1: the cousins' room. Modest period clothes (HOMAGE_BOSSES 1.2): a Sunday dress on the wardrobe, a
	# cardigan folded at the bed's foot, a suitcase open on the bed, three pairs of shoes, a winter coat and a scarf
	# on the pegs, the red ribbon and a brush on the blanket, a straw tick rolled in the corner (three girls, one
	# bed). Their childhood drawings are pinned on the south wall (PaperDecor, build_reactive).
	PropsStory.dress_on_hanger(g, Vector3(1.25, y + 1.98, 5.05), 0.0, "cloth_navy")
	PropsStory.cardigan_folded(g, Vector3(1.25, y + 0.476, 2.3), 0.0, "cloth_cream")
	PropsStory.suitcase_open(g, Vector3(1.25, y + 0.476, 1.6), 180.0)
	PropsStory.ribbon_and_brush(g, Vector3(0.75, y + 0.476, 0.95), 30.0)
	PropsStory.shoes(g, Vector3(2.45, y, 2.2), 95.0, "leather")
	PropsStory.shoes(g, Vector3(2.5, y, 1.62), 80.0, "black_paint")
	PropsStory.shoes(g, Vector3(2.05, y, 5.75), 180.0, "leather")
	Props.block(g, Vector3(7.8, y + 1.6, 4.3), Vector3(7.85, y + 1.68, 5.7), "beam")   # a peg rail on the east wall
	for pz: float in [4.6, 5.3]:
		Props.cyl(g, Vector3(7.78, y + 1.63, pz), 0.02, 0.1, "beam", Vector3(0, 0, 90))
	var coat: Node3D = Props.group(g, "Coat", Vector3(7.73, y + 1.63, 4.6), -90.0)
	Props.obox(coat, Vector3(0, -0.12, 0), Vector3(0.4, 0.2, 0.12), "cloth_navy")
	Props.obox(coat, Vector3(0, -0.62, 0.0), Vector3(0.46, 0.85, 0.11), "cloth_navy", Vector3(-3, 0, 0))
	Props.obox(coat, Vector3(0, -0.3, -0.06), Vector3(0.05, 0.4, 0.02), "cloth_cream")   # a lining showing
	var scarf: Node3D = Props.group(g, "Scarf", Vector3(7.75, y + 1.63, 5.3), -90.0)
	Props.obox(scarf, Vector3(0.04, -0.3, 0), Vector3(0.12, 0.6, 0.03), "plaster_upper")
	Props.obox(scarf, Vector3(-0.06, -0.24, 0.01), Vector3(0.12, 0.48, 0.03), "plaster_upper")
	PropsStory.rolled_mattress(g, Vector3(7.5, y, 0.6))
	Props.cobweb(g, Vector3(0.15, UP_TOP - 0.02, 0.15), 0.0, 0.7)
	PropsStory.stain(g, Vector3(5.6, UP_TOP - 0.008, 0.3), Vector3(7.7, UP_TOP - 0.004, 2.0), "water_stain")
	PropsStory.stain(g, Vector3(2.4, y + 0.0125, 3.0), Vector3(6.4, y + 0.0135, 5.8), "floor_worn")
	# ---- Room 2: the works' gentleman's things: a briefcase by the bed, a hat on the trunk's corner
	var bc: Node3D = Props.group(g, "Briefcase", Vector3(13.25, y, 2.95), 80.0)
	Props.block(bc, Vector3(-0.2, 0, -0.05), Vector3(0.2, 0.3, 0.05), "leather")
	Props.block(bc, Vector3(-0.06, 0.3, -0.01), Vector3(0.06, 0.34, 0.01), "leather")
	Props.cyl(g, Vector3(11.45, y + 0.53, 1.0), 0.17, 0.02, "black_paint")
	Props.cyl(g, Vector3(11.45, y + 0.58, 1.0), 0.1, 0.1, "black_paint")
	Props.cobweb(g, Vector3(15.85, UP_TOP - 0.02, 0.15), -90.0, 0.7)
	PropsStory.stain(g, Vector3(8.6, UP_TOP - 0.008, 3.6), Vector3(10.6, UP_TOP - 0.004, 5.6), "water_stain")
	PropsStory.stain(g, Vector3(10.6, y + 0.0125, 3.2), Vector3(13.0, y + 0.0135, 5.8), "floor_worn")
	# ---- Room 3: Josef's overcoat on the chair; the coffee he didn't finish
	PropsStory.coat_drape(g, Vector3(17.93, y + 0.93, 1.11), 200.0, "cloth_navy")
	PropsStory.mug(g, Vector3(21.0, y + 0.622, 5.15))
	Props.cobweb(g, Vector3(23.85, UP_TOP - 0.02, 0.15), -90.0, 0.8)
	PropsStory.stain(g, Vector3(18.6, y + 0.0125, 3.0), Vector3(21.2, y + 0.0135, 5.8), "floor_worn")
	# ---- the hall: cobwebs at its east end, a stain where the roof leaks, the runner worn to the threads
	Props.cobweb(g, Vector3(23.85, UP_TOP - 0.02, 6.15), -90.0, 0.7)
	Props.cobweb(g, Vector3(23.85, UP_TOP - 0.02, 9.85), 180.0, 0.8)
	PropsStory.stain(g, Vector3(20.6, UP_TOP - 0.008, 6.4), Vector3(23.6, UP_TOP - 0.004, 9.6), "water_stain")
	PropsStory.stain(g, Vector3(3.8, y + 0.026, 7.5), Vector3(13.0, y + 0.028, 8.5), "floor_worn")
	PropsStory.stain(g, Vector3(0.3, UP_TOP - 0.008, 11.0), Vector3(2.2, UP_TOP - 0.004, 13.2), "water_stain")   # over the stairwell
	# snow in at the two upstairs windows
	PropsStory.snow_blown_in(g, Vector3(4.0, y, 0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(20.0, y, 0), Vector3(0, 0, 1), WIN_SILL)


func _polish_stable(g: Node3D) -> void:
	# ---- the horse's stall: her name board over the manger, the halter on its peg, the water bucket, the blanket.
	# You hear her in the first rounds (AudioZone); after that the stall is just empty. Nothing shows why.
	Props.block(g, Vector3(11.55, 1.86, 22.15), Vector3(12.45, 2.1, 22.19), "planks")
	Props.stencil(g, Vector3(12.0, 1.98, 22.2), 180.0, "FANNY", 44, Color(0.62, 0.56, 0.44, 0.85), 0.0036).shaded = true   # paint, lit like the board
	var halter: Node3D = Props.group(g, "Halter", Vector3(11.0, 1.55, 25.33), 0.0)
	Props.cyl(halter, Vector3(0, 0, 0), 0.02, 0.08, "iron", Vector3(90, 0, 0))
	Props.obox(halter, Vector3(-0.06, -0.18, 0.04), Vector3(0.03, 0.36, 0.01), "leather", Vector3(0, 0, -12))
	Props.obox(halter, Vector3(0.06, -0.18, 0.04), Vector3(0.03, 0.36, 0.01), "leather", Vector3(0, 0, 12))
	Props.obox(halter, Vector3(0, -0.36, 0.04), Vector3(0.2, 0.03, 0.01), "leather")
	Props.cyl(halter, Vector3(0, -0.5, 0.04), 0.025, 0.25, "rope")
	_lib("bucket_wood", Vector3(11.6, 0.0, 22.75), 20.0, Vector3(0.8, 0.8, 0.8), false)
	Props.cyl(g, Vector3(11.6, 0.36, 22.75), 0.12, 0.01, "puddle")
	Props.block(g, Vector3(11.85, 0.85, 22.18), Vector3(12.95, 1.1, 22.24), "cloth_green")   # a horse blanket over the manger
	# hay pulled from the manger and trodden into the floor of the stall
	for hp: Vector3 in [Vector3(12.4, 0, 23.2), Vector3(11.8, 0, 24.3)]:
		Props.obox(g, hp + Vector3(0, 0.012, 0), Vector3(0.9, 0.02, 0.6), "straw_floor", Vector3(0, 25, 0))
	# the loft: loose straw over the boards
	var lr: RandomNumberGenerator = RandomNumberGenerator.new()
	lr.seed = 3401
	for k: int in 18:
		Props.obox(g, Vector3(lr.randf_range(STB_X0 + 0.6, LOFT_X1 - 0.6), LOFT_TOP + 0.012, lr.randf_range(22.6, 30.0)), Vector3(lr.randf_range(0.4, 1.0), 0.02, lr.randf_range(0.3, 0.6)),
			"straw_floor", Vector3(0, lr.randf_range(0, 180), 0))
	for k2: int in 8:   # and along the gallery (T-084)
		Props.obox(g, Vector3(lr.randf_range(LOFT_X1 + 0.5, HSTAIR_X0 - 0.6), LOFT_TOP + 0.012, lr.randf_range(GAL_Z0 + 0.6, 33.4)), Vector3(lr.randf_range(0.4, 1.0), 0.02, lr.randf_range(0.3, 0.6)),
			"straw_floor", Vector3(0, lr.randf_range(0, 180), 0))
	# cobwebs in the roof corners and on the trusses
	Props.cobweb(g, Vector3(STB_X0 + 0.15, STABLE_H - 0.02, 22.15), 0.0, 1.0)
	Props.cobweb(g, Vector3(STB_X1 - 0.15, STABLE_H - 0.02, 22.15), -90.0, 0.9)
	Props.cobweb(g, Vector3(STB_X1 - 0.15, STABLE_H - 0.02, 33.85), 180.0, 1.0)
	Props.cobweb(g, Vector3(STB_X0 + 0.15, STABLE_H - 0.02, 33.85), 90.0, 0.9)
	Props.cobweb(g, Vector3(STB_X0 + 0.55, STABLE_H - 0.62, 24.65), 0.0, 0.6)
	# snow in at the stable's windows
	PropsStory.snow_blown_in(g, Vector3(9.0, 0, 22.0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(14.0, 0, 22.0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(12.0, 0, 34.0), Vector3(0, 0, -1), WIN_SILL)


## T-100: the stable and hayloft dressed like a working barn (the art pass had left them nearly bare): proper stall
## partitions (posts to the beam, a capped top rail, iron bars over the boards, kick boards), slatted hay racks over
## the mangers with hay in them, the mangers on legs, a feed trough and a water trough, a tack wall with pegs (a
## collar, bridles, harness, a coiled lead rope) and a saddle on its rack, two lanterns on hooks at the stall posts
## (beside StableLamp1 / StableLamp3, which light them; no new lights), a spare ladder hung on the north wall, hay
## and straw scattered on the floor and the loft, sacks, crates, a spade and a bucket up on the loft. Visual only:
## no colliders, nothing on the walk lines (against walls, on stall planes, over existing colliders), the navmesh
## and gameplay geometry are untouched (test_map00_art fingerprints the bake).
func _barn_dressing(parent: Node3D) -> void:
	var g: Node3D = Props.group(parent, "BarnDressing", Vector3.ZERO)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1004
	var wn: float = STB_Z0 + 0.15   # the north wall's inner face
	var ww: float = STB_X0 + 0.15   # the west wall's inner face
	# ---- stall partitions: a post at the wall, a cap on the front post, a top rail, iron bars over the boards with
	# their head rail, a dark kick board at the foot
	for x: float in [11.0, 16.0, 17.6]:
		Props.block(g, Vector3(x - 0.11, 0.0, wn), Vector3(x + 0.11, 2.4, wn + 0.22), "beam")
		Props.block(g, Vector3(x - 0.12, 2.0, 24.98), Vector3(x + 0.12, 2.12, 25.32), "beam")
		Props.block(g, Vector3(x - 0.075, 1.36, wn + 0.2), Vector3(x + 0.075, 1.46, 25.0), "furniture")
		Props.block(g, Vector3(x - 0.1, 0.0, wn + 0.2), Vector3(x + 0.1, 0.16, 25.0), "beam")
		var zb: float = wn + 0.45
		while zb < 24.8:
			Props.cyl(g, Vector3(x, 1.74, zb), 0.012, 0.56, "iron")
			zb += 0.24
		Props.block(g, Vector3(x - 0.04, 2.0, wn + 0.2), Vector3(x + 0.04, 2.05, 25.0), "iron")
	# ---- hay racks over the mangers: slats leaning off the wall, hay behind them; the mangers get legs and a lip
	for rk: Array in [[12.0, 1.1, 1.78], [16.8, 1.2, 1.95]]:
		var rx: float = float(rk[0])
		var y0: float = float(rk[1])
		var y1: float = float(rk[2])
		Props.block(g, Vector3(rx - 0.6, y0 - 0.04, wn), Vector3(rx + 0.6, y0 + 0.02, wn + 0.06), "beam")
		Props.block(g, Vector3(rx - 0.6, y1 - 0.03, wn + 0.4), Vector3(rx + 0.6, y1 + 0.03, wn + 0.46), "beam")
		var sx: float = rx - 0.5
		while sx <= rx + 0.51:
			Props.strut(g, Vector3(sx, y0, wn + 0.04), Vector3(sx, y1, wn + 0.43), 0.025, "furniture", true)
			sx += 0.125
		Props.obox(g, Vector3(rx, (y0 + y1) * 0.5 - 0.02, wn + 0.17), Vector3(1.1, y1 - y0 - 0.05, 0.22), "hay", Vector3(-28, 0, 0))
		for lx: float in [-0.55, 0.55]:
			Props.block(g, Vector3(rx + lx - 0.04, 0.0, wn + 0.3), Vector3(rx + lx + 0.04, 0.5, wn + 0.38), "beam")
		Props.block(g, Vector3(rx - 0.6, 0.83, wn + 0.4), Vector3(rx + 0.6, 0.9, wn + 0.47), "furniture")
		Props.obox(g, Vector3(rx, 0.86, wn + 0.24), Vector3(1.05, 0.04, 0.3), "hay")
	# ---- a feed trough on trestles in the west stall and a water trough against the west wall
	var ft: Node3D = Props.group(g, "FeedTrough", Vector3(6.6, 0.0, wn + 0.25))
	Props.block(ft, Vector3(-0.9, 0.42, -0.2), Vector3(0.9, 0.46, 0.2), "planks")
	Props.block(ft, Vector3(-0.9, 0.46, -0.2), Vector3(0.9, 0.68, -0.16), "planks")
	Props.block(ft, Vector3(-0.9, 0.46, 0.16), Vector3(0.9, 0.68, 0.2), "planks")
	Props.block(ft, Vector3(-0.92, 0.42, -0.2), Vector3(-0.88, 0.68, 0.2), "beam")
	Props.block(ft, Vector3(0.88, 0.42, -0.2), Vector3(0.92, 0.68, 0.2), "beam")
	Props.obox(ft, Vector3(0, 0.5, 0), Vector3(1.7, 0.05, 0.3), "straw_floor")
	for tx: float in [-0.7, 0.7]:
		Props.strut(ft, Vector3(tx, 0.0, -0.18), Vector3(tx, 0.42, 0.0), 0.05, "beam")
		Props.strut(ft, Vector3(tx, 0.0, 0.18), Vector3(tx, 0.42, 0.0), 0.05, "beam")
	var wt: Node3D = Props.group(g, "WaterTrough", Vector3(ww + 0.3, 0.0, 23.9), 90.0)
	Props.block(wt, Vector3(-0.6, 0.0, -0.28), Vector3(0.6, 0.5, -0.22), "beam")
	Props.block(wt, Vector3(-0.6, 0.0, 0.22), Vector3(0.6, 0.5, 0.28), "beam")
	Props.block(wt, Vector3(-0.66, 0.0, -0.28), Vector3(-0.6, 0.5, 0.28), "beam")
	Props.block(wt, Vector3(0.6, 0.0, -0.28), Vector3(0.66, 0.5, 0.28), "beam")
	Props.block(wt, Vector3(-0.6, 0.38, -0.22), Vector3(0.6, 0.4, 0.22), "puddle")
	for bx: float in [-0.45, 0.45]:
		Props.block(wt, Vector3(bx - 0.03, 0.49, -0.29), Vector3(bx + 0.03, 0.52, 0.29), "iron")
	# ---- the tack wall on the west wall north of the bench: a peg board, a collar, two bridles, harness, a lead rope
	Props.block(g, Vector3(ww, 1.62, 22.55), Vector3(ww + 0.05, 1.78, 25.05), "beam")
	for pz: float in [22.85, 23.45, 24.05, 24.65]:
		Props.cyl(g, Vector3(ww + 0.12, 1.7, pz), 0.018, 0.16, "furniture", Vector3(0, 0, 90))
	var cl: Node3D = Props.group(g, "Collar", Vector3(ww + 0.17, 1.42, 22.85), 90.0)
	for k: int in 10:
		var a0: float = TAU * float(k) / 10.0
		var a1: float = TAU * float(k + 1) / 10.0
		Props.strut(cl, Vector3(cos(a0) * 0.22, sin(a0) * 0.28, 0), Vector3(cos(a1) * 0.22, sin(a1) * 0.28, 0), 0.07, "leather", true)
	Props.obox(cl, Vector3(-0.2, 0.0, 0.03), Vector3(0.04, 0.5, 0.05), "brass")
	Props.obox(cl, Vector3(0.2, 0.0, 0.03), Vector3(0.04, 0.5, 0.05), "brass")
	for bz: float in [23.45, 24.05]:   # bridles: cheek straps, a brow band, the bit rings, the reins
		var br: Node3D = Props.group(g, "Bridle", Vector3(ww + 0.16, 1.7, bz), 90.0)
		Props.obox(br, Vector3(-0.07, -0.25, 0), Vector3(0.025, 0.5, 0.008), "leather", Vector3(0, 0, -8))
		Props.obox(br, Vector3(0.07, -0.25, 0), Vector3(0.025, 0.5, 0.008), "leather", Vector3(0, 0, 8))
		Props.obox(br, Vector3(0, -0.14, 0.004), Vector3(0.18, 0.025, 0.008), "leather")
		Props.cyl(br, Vector3(-0.1, -0.52, 0), 0.035, 0.008, "iron", Vector3(90, 0, 0))
		Props.cyl(br, Vector3(0.1, -0.52, 0), 0.035, 0.008, "iron", Vector3(90, 0, 0))
		Props.obox(br, Vector3(0.0, -0.75, 0.01), Vector3(0.025, 0.55, 0.008), "leather", Vector3(0, 0, 3))
	var hn: Node3D = Props.group(g, "Harness", Vector3(ww + 0.16, 1.7, 24.65), 90.0)
	for hk: int in 5:
		Props.obox(hn, Vector3(-0.12 + hk * 0.06, -0.45 - 0.05 * absf(hk - 2.0), 0.01 * hk), Vector3(0.045, 0.9, 0.01), "leather", Vector3(0, 0, -10 + hk * 5))
	Props.cyl(hn, Vector3(0.0, -0.72, 0.03), 0.06, 0.012, "brass", Vector3(90, 0, 0))
	var rc: Node3D = Props.group(g, "LeadRope", Vector3(ww + 0.1, 1.45, 25.2), 90.0)
	for k2: int in 3:
		var r: float = 0.17 - k2 * 0.015
		for k3: int in 10:
			var b0: float = TAU * float(k3) / 10.0
			var b1: float = TAU * float(k3 + 1) / 10.0
			Props.strut(rc, Vector3(cos(b0) * r * 0.8, sin(b0) * r, 0.015 * k2), Vector3(cos(b1) * r * 0.8, sin(b1) * r, 0.015 * k2), 0.022, "rope", true)
	# the saddle on its rack below the peg board
	var sr: Node3D = Props.group(g, "SaddleRack", Vector3(ww, 1.0, 23.75), 0.0)
	Props.block(sr, Vector3(0.0, -0.05, -0.05), Vector3(0.62, 0.02, 0.05), "beam")
	Props.strut(sr, Vector3(0.02, -0.45, 0.0), Vector3(0.45, -0.03, 0.0), 0.05, "beam")
	Props.obox(sr, Vector3(0.33, 0.06, 0.0), Vector3(0.55, 0.05, 0.58), "cloth_green", Vector3(0, 0, -4))
	Props.obox(sr, Vector3(0.33, 0.12, 0.0), Vector3(0.48, 0.08, 0.36), "leather")
	Props.obox(sr, Vector3(0.1, 0.2, 0.0), Vector3(0.1, 0.12, 0.3), "leather", Vector3(0, 0, 18))
	Props.obox(sr, Vector3(0.55, 0.19, 0.0), Vector3(0.08, 0.1, 0.22), "leather", Vector3(0, 0, -20))
	for sz: float in [-0.25, 0.25]:
		Props.obox(sr, Vector3(0.33, -0.12, sz), Vector3(0.04, 0.42, 0.012), "leather")
		Props.cyl(sr, Vector3(0.33, -0.36, sz), 0.05, 0.012, "iron", Vector3(90, 0, 0))
	# ---- two lanterns on hooks at the stall posts (StableLamp3 and StableLamp1 light them; no lights of their own)
	for hl: Vector3 in [Vector3(11.0, 2.0, 25.36), Vector3(17.6, 2.0, 25.36)]:
		Props.block(g, hl + Vector3(-0.015, -0.02, -0.02), hl + Vector3(0.015, 0.02, 0.18), "iron")
		Props.block(g, hl + Vector3(-0.012, -0.12, 0.15), hl + Vector3(0.012, 0.0, 0.17), "iron")
		var lb: MeshInstance3D = MeshInstance3D.new()
		lb.name = "HookLantern"
		lb.mesh = Props.lantern_body()
		lb.position = hl + Vector3(0, -0.4, 0.16)
		lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lb.set_meta("keep", true)
		g.add_child(lb)
	# and one on a wall hook at the tack wall's south end (TackLamp, a small shadowless lamp, lights the tack)
	Props.block(g, Vector3(ww, 2.0, 25.28), Vector3(ww + 0.2, 2.04, 25.32), "iron")
	Props.block(g, Vector3(ww + 0.17, 1.88, 25.29), Vector3(ww + 0.19, 2.0, 25.31), "iron")
	var tl: MeshInstance3D = MeshInstance3D.new()
	tl.name = "HookLantern"
	tl.mesh = Props.lantern_body()
	tl.position = Vector3(ww + 0.18, 1.6, 25.3)
	tl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tl.set_meta("keep", true)
	g.add_child(tl)
	# ---- the spare ladder hung flat on the north wall over the hay pile, on two iron hooks
	var ld: Node3D = Props.group(g, "SpareLadder", Vector3(22.9, 2.6, wn + 0.08))
	Props.block(ld, Vector3(-1.6, 0.18, -0.03), Vector3(1.6, 0.24, 0.03), "beam")
	Props.block(ld, Vector3(-1.6, -0.24, -0.03), Vector3(1.6, -0.18, 0.03), "beam")
	var lr: float = -1.45
	while lr <= 1.46:
		Props.cyl(ld, Vector3(lr, 0.0, 0.0), 0.018, 0.4, "furniture")
		lr += 0.32
	for hx: float in [-1.0, 1.0]:
		Props.block(ld, Vector3(hx - 0.02, -0.3, -0.05), Vector3(hx + 0.02, -0.24, 0.07), "iron")
	# ---- hay and straw scattered: stalls, the aisle edges, under the chute and the bale drop, along the loft walls
	var floor_spots: Array = [Vector3(13.6, 0, 23.0), Vector3(16.8, 0, 23.4), Vector3(7.5, 0, 23.3), Vector3(9.8, 0, 24.4),
		Vector3(13.0, 0, 24.2), Vector3(19.3, 0, 29.6), Vector3(22.4, 0, 25.6), Vector3(18.0, 0, 33.2), Vector3(5.4, 0, 28.6)]
	for fs: Vector3 in floor_spots:
		for k4: int in 4:
			Props.obox(g, fs + Vector3(rng.randf_range(-0.6, 0.6), 0.014, rng.randf_range(-0.45, 0.45)),
				Vector3(rng.randf_range(0.25, 0.7), 0.02, rng.randf_range(0.15, 0.4)), "straw_floor", Vector3(0, rng.randf_range(0, 180), 0))
		for k5: int in 3:
			Props.obox(g, fs + Vector3(rng.randf_range(-0.5, 0.5), 0.03, rng.randf_range(-0.4, 0.4)),
				Vector3(rng.randf_range(0.18, 0.35), 0.05, 0.05), "hay", Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 180), rng.randf_range(-8, 8)))
	var loft_spots: Array = [Vector3(8.0, LOFT_TOP, 22.6), Vector3(11.0, LOFT_TOP, 22.5), Vector3(14.6, LOFT_TOP, 22.7), Vector3(5.0, LOFT_TOP, 26.0),
		Vector3(5.0, LOFT_TOP, 28.6), Vector3(9.0, LOFT_TOP, 33.4), Vector3(19.3, LOFT_TOP, 29.6), Vector3(16.4, LOFT_TOP, 32.4), Vector3(22.6, LOFT_TOP, 33.4)]
	for ls: Vector3 in loft_spots:
		for k6: int in 4:
			Props.obox(g, ls + Vector3(rng.randf_range(-0.5, 0.5), 0.014, rng.randf_range(-0.3, 0.3)),
				Vector3(rng.randf_range(0.3, 0.8), 0.022, rng.randf_range(0.2, 0.4)), "straw_floor", Vector3(0, rng.randf_range(0, 180), 0))
		Props.obox(g, ls + Vector3(rng.randf_range(-0.3, 0.3), 0.06, 0.0), Vector3(0.5, 0.12, 0.3), "hay", Vector3(0, rng.randf_range(0, 180), 0))
	# ---- grain sacks along the loft's north wall and by the salt crate, two feed sacks below by the north door
	for sk: Array in [[Vector3(9.6, LOFT_TOP, 22.5), 10.0, 0.95], [Vector3(10.25, LOFT_TOP, 22.5), -20.0, 0.9], [Vector3(10.9, LOFT_TOP, 22.55), 35.0, 0.95],
			[Vector3(9.95, LOFT_TOP + 0.36, 22.5), 80.0, 0.85], [Vector3(15.95, LOFT_TOP, 33.5), 15.0, 0.85], [Vector3(16.0, LOFT_TOP, 32.85), -40.0, 0.8],
			[Vector3(18.1, 0.0, 22.55), 20.0, 0.9], [Vector3(18.6, 0.0, 22.6), -15.0, 0.85]]:
		Props.sack(g, sk[0], float(sk[1]), float(sk[2]))
	# library props (PropScatter, no collision): crates by the loft's old crate, buckets, a spade against the wall
	_lib("crate_wood_a", Vector3(7.75, LOFT_TOP, wn + 0.25), 0.0, Vector3.ONE, false)
	_lib("crate_wood_b", Vector3(8.6, LOFT_TOP, wn + 0.65), 90.0, Vector3.ONE, false)
	_lib("crate_wood_a", Vector3(7.75, LOFT_TOP + 0.35, wn + 0.25), 6.0, Vector3.ONE, false)
	_lib("bucket_wood", Vector3(14.6, LOFT_TOP, 22.55), 40.0, Vector3(0.8, 0.8, 0.8), false)
	_lib("spade_rusted", Vector3(ww + 0.1, LOFT_TOP, 29.6), 90.0, Vector3.ONE, false, Vector3(0, 0, -12))
	_lib("bucket_wood", Vector3(STB_X1 - 0.5, 0.0, 22.6), -15.0, Vector3(0.85, 0.85, 0.85), false)


func _polish_cellars(g: Node3D) -> void:
	# the Helvetia cellar's stair hall: a stain where the yard's melt comes through, boots worn into the landing
	PropsStory.stain(g, Vector3(24.4, 2.993, 10.4), Vector3(26.6, 2.997, 12.6), "water_stain")
	PropsStory.stain(g, Vector3(24.3, 0.0125, 10.5), Vector3(27.6, 0.0135, 13.0), "floor_worn")


# ================================================================== the reactive pieces (T-053)

## The parts that react, as runtime nodes under "Reactive" (they build their art at load time, so the .tscn holds
## only their settings): the glassware ShatterSets, the swinging room doors, the hay zones, the snow footprints,
## the audio zones (hearth, wind at the windows, the stable, the horse), the paper dressing (the calendar, the
## patrol's map, Käthe's notes, the cousins' drawings), and two drips for the Helvetia cellar.
func build_reactive() -> void:
	var r: Node3D = Node3D.new()
	r.name = "Reactive"
	map_root.add_child(r)
	for set_name: String in _glass.keys():
		var ss: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/shatter_set.gd", "Glass_" + set_name, {"items": _glass[set_name]})
		r.add_child(ss)
	# the paper: [kind, position, yaw, flat, tilt]
	var pi_: int = 0
	for pd: Array in [["calendar", Vector3(5.45, 1.75, 0.16), 180.0, false, 1.5],
			["freq_notes", Vector3(4.605, 1.72, 4.25), -90.0, false, -4.0], ["freq_notes", Vector3(4.605, 1.69, 4.62), -90.0, false, 6.0],
			["map", Vector3(16.5, 0.752, 11.55), 168.0, true, 0.0],
			["drawing_inn", Vector3(2.35, UP_Y + 1.6, 5.85), 0.0, false, -3.0],
			["drawing_horse", Vector3(3.2, UP_Y + 1.5, 5.85), 0.0, false, 4.0],
			["drawing_jam", Vector3(4.05, UP_Y + 1.62, 5.85), 0.0, false, -2.0]]:
		pi_ += 1
		var paper: Node3D = _scripted(Node3D.new(), "res://gravelight/world/paper_decor.gd", "Paper%d_%s" % [pi_, str(pd[0])], {
			"kind": pd[0], "flat": pd[3], "tilt_deg": pd[4]})
		paper.position = pd[1]
		paper.rotation.y = deg_to_rad(float(pd[2]))
		r.add_child(paper)
	# the guest rooms' doors, left ajar, opening into the room: Room 1's hinged on its east jamb so the leaf never
	# hides the MP40 on the west wall from the doorway; Rooms 2 and 3 on their west jambs
	for dd: Array in [[6.5, true, 1], [11.0, false, 2], [19.5, false, 3]]:
		var sd: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/swing_door.gd", "RoomDoor%d" % int(dd[2]), {
			"width": 1.5, "height": 2.15, "rest_deg": 70.0, "open_deg": 100.0, "flip": dd[1]})
		sd.position = Vector3(float(dd[0]), UP_Y, 6.0 - T * 0.5)
		r.add_child(sd)
	# hay that puffs underfoot: the straw on the stable floor, the hay pile, the loft's boards
	var hi_: int = 0
	for hz: Array in [[Vector3(12.5, 0, 23.6), Vector3(2.2, 0.8, 1.8)], [Vector3(14.0, 0, 24.0), Vector3(2.2, 0.8, 1.8)],
			[Vector3(19.5, 0, 24.5), Vector3(2.2, 0.8, 1.8)], [Vector3(9.0, 0, 27.0), Vector3(2.2, 0.8, 1.8)],
			[Vector3(20.0, 0, 31.0), Vector3(2.2, 0.8, 1.8)], [Vector3(22.5, 0, 23.7), Vector3(2.4, 1.0, 2.8)],
			[Vector3(10.0, LOFT_TOP, 28.0), Vector3(10.6, 0.8, 11.6)], [Vector3(19.4, LOFT_TOP, 31.5), Vector3(7.6, 0.8, 4.6)]]:
		hi_ += 1
		var hp: Node3D = _scripted(Area3D.new(), "res://gravelight/world/reactive/hay_puff_zone.gd", "HayPuff%d" % hi_, {"size": hz[1]})
		hp.position = hz[0]
		r.add_child(hp)
	# footprints on the open snow (the snowfall's areas, the strip in front of the inn); not over the light wells
	var fp: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/snow_footprints.gd", "SnowFootprints", {
		"areas": [AABB(Vector3(-40, -1, -40), Vector3(105, 3, 37)), AABB(Vector3(-40, -1, -3), Vector3(37, 3, 43)),
			AABB(Vector3(27, -1, -3), Vector3(38, 3, 43)), AABB(Vector3(-40, -1, 37), Vector3(105, 3, 33)),
			AABB(Vector3(0, -1, 16.6), Vector3(17.6, 3, 5.2)), AABB(Vector3(2, -1, 34.2), Vector3(32, 3, 13.8)),
			AABB(Vector3(-3, -1, -3), Vector3(30, 3, 2.75)), AABB(Vector3(24.2, -1, -3), Vector3(2.8, 3, 13))] as Array[AABB],
		"holes": [AABB(Vector3(1.85, -2, -4.65), Vector3(3.2, 4, 4.5)), AABB(Vector3(24.0, -2, -2.1), Vector3(2.35, 4, 5.45)),
			AABB(Vector3(23.8, -2, 9.8), Vector3(4.5, 4, 9.4))] as Array[AABB]})   # the light wells, the cellar's stair hall
	map_root.add_child(fp)
	# sound: the hearth (dies with its light), wind through each broken window (louder in gusts and as the boards go),
	# the stable's old frame creaking, the horse in her stall in the first two rounds
	var hearth: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/audio_zone.gd", "HearthCrackle", {
		"sound": "fire_crackle", "mode": "loop", "volume_db": 0.0, "follow_light": NodePath("../../Hearthfire"), "max_distance": 20.0})
	hearth.position = Vector3(12.0, 0.6, 1.0)
	r.add_child(hearth)
	for w: Array in [["W_TAP_N1", Vector3(7.0, 1.5, 0.4)], ["W_TAP_N2", Vector3(17.0, 1.5, 0.4)], ["W_TAP_W", Vector3(0.4, 1.5, 6.0)],
			["W_TAP_E", Vector3(23.6, 1.5, 8.0)], ["W_UP_R1", Vector3(4.0, UP_Y + 1.5, 0.4)], ["W_UP_R3", Vector3(20.0, UP_Y + 1.5, 0.4)],
			["W_STB_N1", Vector3(9.0, 1.5, 22.4)], ["W_STB_N2", Vector3(14.0, 1.5, 22.4)], ["W_STB_S", Vector3(12.0, 1.5, 33.6)],
			["W_STB_LOFT", Vector3(22.0, LOFT_TOP + 1.5, 33.6)]]:
		var wz: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/audio_zone.gd", "WindHowl_" + str(w[0]), {
			"sound": "wind_howl", "mode": "loop", "volume_db": -14.0, "wind_db": 7.0, "broken_db": 8.0,
			"window": NodePath("../../Gameplay/" + str(w[0])), "max_distance": 11.0})
		wz.position = w[1]
		r.add_child(wz)
	var creak: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/audio_zone.gd", "StableCreaks", {
		"sound": "stable_creak", "mode": "random", "volume_db": -2.0, "interval": Vector2(12.0, 30.0), "spread": Vector3(8.0, 2.0, 5.0)})
	creak.position = Vector3(15.0, 4.5, 28.0)
	r.add_child(creak)
	var horse: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/audio_zone.gd", "HorseInTheStall", {
		"sound": "horse_whinny", "mode": "random", "volume_db": -4.0, "interval": Vector2(30.0, 65.0), "spread": Vector3(1.2, 0.2, 0.8),
		"max_round": 2, "max_plays": 3})
	horse.position = Vector3(12.6, 1.4, 23.4)
	r.add_child(horse)
	# the Helvetia cellar drips too, over its puddles
	for dp: Vector3 in [Vector3(30.1, CELLAR_TOP - 0.02, 25.0), Vector3(27.4, CELLAR_TOP - 0.02, 30.0)]:
		var drip: Node3D = _scripted(Node3D.new(), "res://gravelight/world/drip_point.gd", "Drip", {"height": CELLAR_TOP - 0.02 - CELLAR_Y})
		drip.position = dp
		gameplay.add_child(drip)


# ================================================================== batching

## Merges every static primitive mesh (collision visuals + dressing) into one ArrayMesh per
## (material, shadow mode, 12 m cell) so the inn draws in a few dozen calls instead of ~1000.
## Materials are world-triplanar, so baking transforms into vertices keeps texturing identical.
func merge_static_meshes() -> int:
	var groups: Dictionary = {}   # key -> {mat, shadow, st: SurfaceTool}
	var victims: Array[MeshInstance3D] = []
	for holder: Node in [geo, dress]:
		for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or mi.has_meta("keep"):
				continue
			var xf: Transform3D = _xform_to_root(mi)
			var c: Vector3 = xf.origin
			var cell: Vector3i = Vector3i(floori(c.x / 12.0), floori(c.y / 6.0), floori(c.z / 12.0))
			var shadow: int = mi.cast_shadow
			var key: String = "%d|%d|%s" % [mi.material_override.get_instance_id(), shadow, cell]
			if not groups.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"mat": mi.material_override, "shadow": shadow, "st": st}
			(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
			victims.append(mi)
	var batch_root: Node3D = Node3D.new()
	batch_root.name = "StaticBatches"
	map_root.add_child(batch_root)
	var i: int = 0
	for key: String in groups.keys():
		var g: Dictionary = groups[key]
		var mesh: ArrayMesh = (g["st"] as SurfaceTool).commit()
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Batch_%d" % i
		out.mesh = mesh
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		batch_root.add_child(out)
		i += 1
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	return victims.size()


func _xform_to_root(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != map_root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


# ================================================================== lighting & environment

# ================================================================== the lighting pass (T-061)

## The inn's electric bulbs (T-061): the cellar lever's sweep reaches the taproom, upstairs and the stable, so each
## gets a few bare bulbs under tin shades that light with it. [light name, zone, bulb position, ceiling y, energy,
## range]. The names are in cousins.json setup.lamp_groups, so the Cousins round gutters them with the oil lamps.
const INN_BULBS: Array = [
	["TapBulb1", "TAPROOM", Vector3(9.6, 2.8, 5.6), TAP_H, 1.5, 8.5], ["TapBulb2", "TAPROOM", Vector3(14.5, 2.85, 11.6), TAP_H, 1.6, 9.0],
	["TapBulb3", "TAPROOM", Vector3(21.2, 2.85, 8.2), TAP_H, 1.4, 8.5],
	["HallBulb1", "UPSTAIRS", Vector3(7.2, UP_Y + 2.35, 8.0), UP_TOP, 1.3, 8.0], ["HallBulb2", "UPSTAIRS", Vector3(17.0, UP_Y + 2.35, 8.0), UP_TOP, 1.3, 8.0],
	["Room1Bulb", "UPSTAIRS", Vector3(5.6, UP_Y + 2.35, 1.6), UP_TOP, 0.9, 6.0], ["Room2Bulb", "UPSTAIRS", Vector3(9.8, UP_Y + 2.35, 4.2), UP_TOP, 0.9, 6.0],
	["Room3Bulb", "UPSTAIRS", Vector3(21.8, UP_Y + 2.35, 2.6), UP_TOP, 0.8, 6.0],
	["PassBulb", "STABLE", Vector3(20.0, 2.55, 17.1), 3.0, 1.1, 6.5],
	["StableBulb1", "STABLE", Vector3(20.6, 4.6, 26.6), STABLE_H - 0.6, 1.9, 11.0], ["StableBulb2", "STABLE", Vector3(12.6, 2.75, 31.2), LOFT_Y, 1.3, 8.0],   # (bulb 1 mid-bay, clear of the gallery's rail, T-084)
]
const BULB_COLOR: Color = Color(1.0, 0.84, 0.62)
var _bulb_lit: Dictionary = {}   # light name -> holder of its lit glass (moved under the light in build_environment)


## Dressing for the lighting pass: the inn's bulb pendants (their lit glass in a holder per bulb) and the lantern
## the Helvetia installers left hanging in the perk vault (the vault is otherwise black until the lever is thrown).
func _dress_lighting() -> void:
	var g: Node3D = Props.group(dress, "Lighting", Vector3.ZERO)
	for b: Array in INN_BULBS:
		var holder: Node3D = Node3D.new()
		holder.name = str(b[0]) + "Lit"
		holder.set_script(load("res://gravelight/maps/map00_crossroads/lit_glass.gd"))
		dress.add_child(holder)
		Props.pendant(g, b[2], float(b[3]) - 0.02, holder, "tin")
		_bulb_lit[str(b[0])] = holder
	Props.lantern(g, Vector3(28.2, CELLAR_Y + 2.2, 25.0), CELLAR_TOP - 0.1)
	# the upstairs hall's two ends (the hall lamp alone left the stair head and the east end in the dark), and a
	# lamp over the Old Cellar's ammo box
	Props.wall_lamp(g, Vector3(0.16, UP_Y + 1.85, 6.7), -90.0)
	Props.wall_lamp(g, Vector3(23.84, UP_Y + 1.85, 8.0), 90.0)
	Props.wall_lamp(g, Vector3(8.6, UP_Y + 1.85, 6.16), 180.0)   # mid-hall, between the room doors (pass 2)
	Props.wall_lamp(g, Vector3(16.0, UP_Y + 1.85, 6.16), 180.0)
	Props.wall_lamp(g, Vector3(13.6, CELLAR_Y + 2.0, 15.84), 0.0)
	Props.wall_lamp(g, Vector3(STB_X0 + 0.16, 5.3, 32.4), -90.0)   # the hayloft's south end, over the bales


## The night (T-061 lighting pass): cold moonlight and snow outside, warm lamp pools inside, fog that catches both.
## High adds SDFGI bounce light (the lamps' warmth on ceilings and in corners, the moonlit snow's cold fill through
## the windows, the wreck's glow on the field) and SSIL; Medium keeps SSIL; Low falls back to the flat ambient below
## (GLSettings presets take effects away, never add them). The sky dome is a mesh (Landscape), so the background
## colour only feeds the dome's tint and the GI's sky light (background_energy_multiplier).
func build_environment() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.03)
	env.background_energy_multiplier = 1.5
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.4)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = 3.0
	env.sdfgi_bounce_feedback = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.15)
	env.fog_light_energy = 1.0
	env.fog_density = 0.016
	env.fog_sky_affect = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.9)
	env.volumetric_fog_emission = Color(0.01, 0.012, 0.02)
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_gi_inject = 0.3   # SDFGI's bounce would turn the field's ground fog milky
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78
	env.adjustment_contrast = 1.14
	env.adjustment_brightness = 1.0
	we.environment = env
	map_root.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.5, 0.6, 0.95)
	moon.light_energy = 0.42
	moon.light_volumetric_fog_energy = 0.35
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(28), 0)
	map_root.add_child(moon)
	var warm: Color = Color(1.0, 0.66, 0.36)
	_lamp("Hearthfire", Vector3(12, 0.8, 1.4), Color(1.0, 0.5, 0.2), 5.5, 13.0, true, true)
	_lamp("TapLamp1", Vector3(6.5, 2.45, 11.5), warm, 2.72, 11.0, true, true, 0.08)
	_lamp("TapLamp2", Vector3(17.5, 2.45, 4.0), warm, 2.38, 11.0, true, true, 0.08)
	_lamp("TapLamp3", Vector3(19.5, 2.45, 13.0), warm, 2.38, 10.0, true, true, 0.08)
	_lamp("TapLamp4", Vector3(14.0, 2.45, 8.0), warm, 2.21, 10.0, true, true, 0.08)
	_lamp("BarLamp", Vector3(5.0, 2.4, 4.5), warm, 1.70, 7.0, false, true, 0.1)
	_lamp("StairLamp", Vector3(3.2, 4.45, 12.5), warm, 1.70, 10.0, false, true, 0.08)
	_lamp("StairSconce", Vector3(0.55, _stair_y(12.1) + 1.8, 12.1), warm, 0.75, 5.0, false, true, 0.1)
	_lamp("StairSconce2", Vector3(STAIR_X1 - 0.55, 2.35, 12.9), warm, 0.75, 5.0, false, true, 0.1)
	_lamp("Room1Lamp", Vector3(4.0, UP_Y + 2.05, 3.0), warm, 1.70, 8.0, false, true, 0.08)
	_lamp("Room2Lamp", Vector3(12.0, UP_Y + 2.05, 3.0), warm, 1.53, 8.0, false, true, 0.08)
	_lamp("Room3Lamp", Vector3(20.0, UP_Y + 2.05, 3.0), warm, 1.70, 8.0, false, true, 0.08)
	_lamp("HallLamp", Vector3(12.0, UP_Y + 2.05, 8.0), warm, 1.87, 11.0, true, true, 0.08)
	_lamp("PassLamp", Vector3(20.0, 2.25, 19.0), warm, 2.21, 10.0, false, true)
	_lamp("StableLamp1", Vector3(19.0, 3.85, 26.0), warm, 3.82, 14.0, true, true)
	_lamp("StableLamp2", Vector3(19.0, 2.35, 31.5), warm, 3.26, 13.0, true, true)   # under the gallery since T-084
	_lamp("StableLamp3", Vector3(10.0, 2.15, 28.0), warm, 2.99, 12.0, false, true)
	_lamp("TackLamp", Vector3(STB_X0 + 0.33, 1.75, 25.3), warm, 0.9, 4.5, false, true, 0.12)   # T-100: the tack wall's hook lantern (no shadows)
	_lamp("LoftLamp", Vector3(10.0, 5.45, 28.0), warm, 2.29, 11.0, false, true)
	_lamp("LoftHookLamp", Vector3(21.2, LOFT_TOP + 1.55, 30.9), warm, 2.1, 10.0, false, true, 0.12)   # on its hook by the stair head (T-084)
	_lamp("WreckFire", Vector3(45, 3.5, 5), Color(1.0, 0.45, 0.15), 8.0, 34.0, true, true)
	_lamp("WreckFire2", Vector3(42.5, 1.6, 6.8), Color(1.0, 0.4, 0.1), 3.0, 14.0, false, true)
	_lamp("HallSconce", Vector3(0.55, UP_Y + 1.8, 6.7), warm, 0.9, 6.5, false, true, 0.1)
	_lamp("HallSconce2", Vector3(23.45, UP_Y + 1.8, 8.0), warm, 0.9, 6.5, false, true, 0.1)
	_lamp("HallSconce3", Vector3(8.6, UP_Y + 1.8, 6.55), warm, 1.0, 7.0, false, true, 0.1)
	_lamp("HallSconce4", Vector3(16.0, UP_Y + 1.8, 6.55), warm, 1.0, 7.0, false, true, 0.1)
	_lamp("LoftSconce", Vector3(6.55, 5.25, 32.4), warm, 1.1, 7.0, false, true, 0.1)
	_lamp("OCAmmoLamp", Vector3(13.6, CELLAR_Y + 1.9, 15.45), Color(1.0, 0.68, 0.4), 1.0, 7.0, false, true, 0.12)
	_lamp("CellarLantern", Vector3(28.2, CELLAR_Y + 2.05, 25.0), Color(1.0, 0.7, 0.4), 1.8, 9.5, false, true, 0.1)
	# cold moonlight spilling through the taproom windows (no shadows; aimed through the openings)
	for wp: Array in [[Vector3(7.0, 3.7, -3.2), Vector3(7.0, 0.0, 3.6)], [Vector3(17.0, 3.7, -3.2), Vector3(17.0, 0.0, 3.6)],
			[Vector3(-3.2, 3.7, 6.0), Vector3(3.6, 0.0, 6.0)], [Vector3(27.2, 3.7, 8.0), Vector3(20.4, 0.0, 8.0)]]:
		var sp: SpotLight3D = SpotLight3D.new()
		sp.name = "MoonSpill"
		sp.position = wp[0]
		sp.light_color = Color(0.55, 0.65, 1.0)
		sp.light_energy = 6.0
		sp.light_volumetric_fog_energy = 3.5
		sp.spot_range = 10.0
		sp.spot_angle = 22.0
		sp.spot_attenuation = 1.1
		sp.shadow_enabled = true   # the barricade boards stripe the floor (and change as they're torn off)
		map_root.add_child(sp)
		sp.look_at_from_position(wp[0], wp[1], Vector3.UP)
	# and through the two guest-room windows upstairs (their pools also give the hall a little cold bounce, so the
	# Cousins' blackout there is dark, not black)
	for wp2: Array in [[Vector3(4.0, UP_Y + 3.4, -3.0), Vector3(4.0, UP_Y, 3.4)], [Vector3(20.0, UP_Y + 3.4, -3.0), Vector3(20.0, UP_Y, 3.4)]]:
		var su: SpotLight3D = SpotLight3D.new()
		su.name = "MoonSpillUp"
		su.light_color = Color(0.55, 0.65, 1.0)
		su.light_energy = 4.0
		su.light_volumetric_fog_energy = 2.5
		su.spot_range = 9.0
		su.spot_angle = 22.0
		su.spot_attenuation = 1.1
		map_root.add_child(su)
		su.look_at_from_position(wp2[0], wp2[1], Vector3.UP)
	_inn_bulbs()
	_follow_lights()
	var post: CanvasLayer = CanvasLayer.new()
	post.set_script(load("res://gravelight/ui/postfx.gd"))
	post.name = "PostFx"
	map_root.add_child(post)


## The inn's electric bulbs (INN_BULBS): dark until the cellar lever's sweep reaches their zone, their lit glass
## under them (lit_glass.gd hides it whenever the bulb is out: the Cousins round, the sweep's flicker).
func _inn_bulbs() -> void:
	for b: Array in INN_BULBS:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = str(b[0])
		l.position = (b[2] as Vector3) - Vector3(0, 0.08, 0)
		l.light_color = BULB_COLOR
		l.light_energy = float(b[4])
		l.omni_range = float(b[5])
		l.omni_attenuation = 1.4
		l.visible = false
		l.set_meta("zone", StringName(str(b[1])))
		l.set_meta("energy", float(b[4]))
		l.add_to_group(&"power_lights", true)
		map_root.add_child(l)
		var holder: Node3D = _bulb_lit.get(str(b[0]))
		if holder != null:
			holder.get_parent().remove_child(holder)
			l.add_child(holder)
			holder.position = -l.position


## Lights that belong to a lamp and follow its level (follow_light.gd): lamplight spilling out of the windows onto
## the snow (the inn reads as a warm refuge from the yard and the field, and goes dark from outside when the Cousins
## put the lamps out), the burning wreck through the taproom's east window, the candles on the tables.
func _follow_lights() -> void:
	var spill: Color = Color(1.0, 0.6, 0.3)
	# [window centre on its outer face, outward normal, source lamp, energy]
	for w: Array in [[Vector3(7.0, 1.55, -0.35), Vector3(0, 0, -1), "Hearthfire", 1.3], [Vector3(17.0, 1.55, -0.35), Vector3(0, 0, -1), "TapLamp2", 1.4],
			[Vector3(-0.35, 1.55, 6.0), Vector3(-1, 0, 0), "BarLamp", 1.2], [Vector3(24.35, 1.55, 8.0), Vector3(1, 0, 0), "TapLamp4", 1.2],
			[Vector3(4.0, UP_Y + 1.55, -0.35), Vector3(0, 0, -1), "Room1Lamp", 1.0], [Vector3(20.0, UP_Y + 1.55, -0.35), Vector3(0, 0, -1), "Room3Lamp", 1.0],
			[Vector3(9.0, 1.55, 21.65), Vector3(0, 0, -1), "StableLamp3", 0.9], [Vector3(14.0, 1.55, 21.65), Vector3(0, 0, -1), "StableLamp1", 0.9],
			[Vector3(12.0, 1.55, 34.35), Vector3(0, 0, 1), "StableLamp2", 1.0]]:
		var at: Vector3 = w[0]
		var out: Vector3 = w[1]
		var sp: SpotLight3D = _follower(SpotLight3D.new(), "WindowSpill", at, str(w[2]), float(w[3]) * 5.0, 0.0) as SpotLight3D
		sp.light_color = spill
		sp.spot_range = 10.0 + at.y
		sp.spot_angle = 50.0
		sp.spot_attenuation = 1.1
		sp.light_volumetric_fog_energy = 0.6
		sp.look_at_from_position(at, at + out * 2.2 + Vector3(0, -at.y * 0.55 - 0.4, 0), Vector3.UP)
		# the lit window itself, seen from outside between the barricade boards (pass 2): a warm card on the wall's
		# inner face, facing out (culled from inside), out of the GI, dimming with its lamp (follow_light.gd "Glow")
		var card: MeshInstance3D = MeshInstance3D.new()
		card.name = "Glow"
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(1.6, 1.3)
		card.mesh = q
		var gm: StandardMaterial3D = StandardMaterial3D.new()
		gm.albedo_color = Color.BLACK
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.6, 0.3)
		gm.emission_energy_multiplier = 4.0
		card.material_override = gm
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		sp.add_child(card)
		card.transform = sp.transform.affine_inverse() * Transform3D(Basis.looking_at(-out, Vector3.UP), at - out * 0.48)
	# GRAVELIGHT ONE burning in the field, through the east window (the wreck's own light is too far off to reach in)
	var ws: SpotLight3D = _follower(SpotLight3D.new(), "WreckSpill", Vector3(26.5, 2.7, 7.4), "WreckFire", 2.6, 0.0) as SpotLight3D
	ws.light_color = Color(1.0, 0.55, 0.2)
	ws.spot_range = 12.0
	ws.spot_angle = 18.0
	ws.spot_attenuation = 1.0
	ws.light_volumetric_fog_energy = 1.2
	ws.look_at_from_position(ws.position, Vector3(19.0, 0.2, 8.6), Vector3.UP)
	# the wreck's glow on the field and in the ground fog round it
	var wg: OmniLight3D = _follower(OmniLight3D.new(), "WreckGlow", Vector3(45.0, 7.0, 6.0), "WreckFire", 3.5, 0.0) as OmniLight3D
	wg.light_color = Color(1.0, 0.58, 0.26)
	wg.omni_range = 22.0
	wg.omni_attenuation = 0.9
	wg.light_volumetric_fog_energy = 2.0
	# the candles on the taproom tables and the guest rooms' nightstands
	for c: Array in [[Vector3(12.75, 0.95, 11.3), "TapLamp1"], [Vector3(16.75, 0.95, 11.3), "TapLamp3"], [Vector3(20.25, 0.95, 4.3), "TapLamp2"],
			[Vector3(19.24, 0.95, 8.82), "TapLamp3"], [Vector3(8.18, 0.95, 11.44), "TapLamp1"],   # the added tables (T-072)
			[Vector3(2.6, UP_Y + 0.85, 0.57), "Room1Lamp"], [Vector3(13.15, UP_Y + 0.85, 0.57), "Room2Lamp"], [Vector3(21.15, UP_Y + 0.85, 5.32), "Room3Lamp"]]:
		var cl: OmniLight3D = _follower(OmniLight3D.new(), "CandleLight", c[0], str(c[1]), 0.7, 0.18) as OmniLight3D
		cl.light_color = Color(1.0, 0.6, 0.28)
		cl.omni_range = 3.2
		cl.omni_attenuation = 1.5


## A follow_light.gd light at `pos` under the map root, following the lamp `source` (by name, under the map root).
func _follower(l: Light3D, name_: String, pos: Vector3, source: String, energy: float, flicker: float) -> Light3D:
	l.set_script(load("res://gravelight/maps/map00_crossroads/follow_light.gd"))
	l.name = name_
	l.position = pos
	l.set("source", NodePath("../" + source))
	l.set("full_energy", energy)
	l.set("own_flicker", flicker)
	l.light_energy = energy
	l.shadow_enabled = false
	map_root.add_child(l)
	return l


## Update 02 section 7 (T-052): the living world beyond the play space. Two runtime nodes, so the .tscn stays small:
## Landscape builds the terrain layers, sky, forests, roadside story, crash-site extras and the inn's weather details
## at load time (world/landscape/landscape.gd); MapAmbience runs the sky events, the distant war and the ambient
## life from data/gravelight/map00_ambience.json (world/landscape/map_ambience.gd). Neither collides.
func build_landscape() -> void:
	var land: Node3D = Node3D.new()
	land.set_script(load("res://gravelight/world/landscape/landscape.gd"))
	land.name = "Landscape"
	map_root.add_child(land)
	var amb: Node3D = Node3D.new()
	amb.set_script(load("res://gravelight/world/landscape/map_ambience.gd"))
	amb.name = "MapAmbience"
	amb.set("config_path", "res://data/gravelight/map00_ambience.json")
	map_root.add_child(amb)


## The few lanterns whose light the volumetric fog catches (a soft halo in the room's haze), T-061. Kept to a
## handful: every fog-lit light costs in the froxel pass.
const INNER_GAIN: float = 1.5
const LAMP_HALOS: Dictionary = {"OutPorchLamp": 1.0, "OutCrossLamp": 1.0, "TapLamp1": 0.5, "TapLamp2": 0.5, "TapLamp3": 0.5, "TapLamp4": 0.5, "HallLamp": 0.5,
	"StableLamp1": 0.5, "StableLamp2": 0.5, "PassLamp": 0.4, "YardDoorLamp": 1.2, "YardWallLamp": 1.2, "GateLantern": 1.2,
	"OCVaultLamp": 0.5, "OCWineLamp": 0.5, "CellarLantern": 0.5}


func _lamp(name_: String, pos: Vector3, color: Color, energy: float, range_: float, shadows: bool, flicker: bool, amount: float = 0.35) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	if flicker:
		l.set_script(load("res://gravelight/world/flicker_light.gd"))
		l.set("base_energy", energy)
		l.set("amount", amount)
	l.name = name_
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.omni_attenuation = 1.6
	# T-061 pass 2: the inn's and the cellars' lamps throw wider, stronger pools and feed the GI bounce harder (the
	# flat ambient they used to sit in is gone under SDFGI); the yard's and the wreck's are tuned where they're built
	if not (name_.begins_with("Wreck") or name_.begins_with("Yard") or name_.begins_with("Gate") or name_.begins_with("Out")):
		energy *= INNER_GAIN
		l.light_energy = energy
		if flicker:
			l.set("base_energy", energy)
		l.omni_range = range_ * 1.25
		l.omni_attenuation = 1.25
		l.light_indirect_energy = 2.0
	# Only the big fires feed the volumetric fog; lanterns light surfaces (much cheaper).
	l.light_volumetric_fog_energy = 1.4 if (name_.begins_with("Hearth") or name_.begins_with("Wreck")) else float(LAMP_HALOS.get(name_, 0.0))
	l.shadow_enabled = shadows
	map_root.add_child(l)


# ================================================================== gameplay nodes

func _scripted(type_node: Node3D, script_path: String, name_: String, props: Dictionary) -> Node3D:
	type_node.set_script(load(script_path))
	type_node.name = name_
	for k: String in props.keys():
		type_node.set(k, props[k])
	return type_node


func build_gameplay() -> void:
	map_root.set_script(load("res://gravelight/maps/map_root.gd"))
	map_root.set("map_id", &"map00_crossroads")
	map_root.set("display_name", "Crossroads Inn")
	map_root.set("start_zone", &"TAPROOM")
	map_root.set("quest_files", PackedStringArray(["res://data/gravelight/quests/map00_radio.json"]))
	map_root.set("intro_text", "GASTHAUS ZUM KREUZWEG\n23 December 1944 · 9 km northwest of Kaltenbrunn")
	map_root.set("drop_bounds", Rect2(OUT_MIN, OUT_MAX - OUT_MIN))   # drops from a kill beyond the edge land inside it (T-084)
	gameplay = Node3D.new()
	gameplay.name = "Gameplay"
	map_root.add_child(gameplay)

	# player spawns: the taproom's south end, facing north up the room (T-076). From PlayerSpawn1 the whole round 1
	# opening is in front of you: the bar and Trudi behind it (left), Sobotta at the counter's end, Frau Pohl by the
	# hearth, the carters' table (right) and the front door they run for (22 deg right; the porch where Kubiak and
	# Rother are caught is in line with the doorway). The old spawns (14..16, 7..9) stood among the patrons with
	# four of the five beside or behind the camera. The bots' spawns are behind and to the sides of the player's.
	var i: int = 1
	for p: Vector3 in [Vector3(14.5, 0, 13.4), Vector3(16.6, 0, 14.3), Vector3(12.4, 0, 14.3), Vector3(14.5, 0, 15.1)]:
		var ps: Marker3D = _scripted(Marker3D.new(), "res://gravelight/maps/player_spawn.gd", "PlayerSpawn%d" % i, {}) as Marker3D
		ps.position = p
		gameplay.add_child(ps)
		i += 1

	# windows: [id, zone, floor position on the wall line, inward yaw (deg)]
	var windows: Array = [
		["W_TAP_N1", &"TAPROOM", Vector3(7.0, 0, 0), 0.0],
		["W_TAP_N2", &"TAPROOM", Vector3(17.0, 0, 0), 0.0],
		["W_TAP_W", &"TAPROOM", Vector3(0, 0, 6.0), 90.0],
		["W_TAP_E", &"TAPROOM", Vector3(24.0, 0, 8.0), -90.0],
		["W_UP_R1", &"UPSTAIRS", Vector3(4.0, UP_Y, 0), 0.0],
		["W_UP_R3", &"UPSTAIRS", Vector3(20.0, UP_Y, 0), 0.0],
		["W_STB_N1", &"STABLE", Vector3(9.0, 0, 22.0), 0.0],
		["W_STB_N2", &"STABLE", Vector3(14.0, 0, 22.0), 0.0],
		["W_STB_S", &"STABLE", Vector3(12.0, 0, 34.0), 180.0],
		["W_STB_LOFT", &"STABLE", Vector3(22.0, LOFT_TOP, STB_Z1), 180.0],   # the loft door over the yard (T-084): its zombies stand on the hoist ledge
		["W_YARD_W", &"YARD", Vector3(2.0, 0, 41.0), 90.0],
		["W_YARD_E", &"YARD", Vector3(34.0, 0, 41.0), -90.0],
		["W_YARD_S1", &"YARD", Vector3(9.0, 0, 48.0), 180.0],
		["W_YARD_S2", &"YARD", Vector3(27.0, 0, 48.0), 180.0],
	]
	for w: Array in windows:
		var bar: Node3D = _scripted(Node3D.new(), "res://gravelight/world/barricade.gd", str(w[0]), {
			"window_id": StringName(str(w[0])), "zone_id": w[1], "width": 1.6, "sill_height": WIN_SILL, "top_height": WIN_TOP})
		bar.position = w[2]
		bar.rotation.y = deg_to_rad(float(w[3]))
		gameplay.add_child(bar)
		# T-080: the field spawns stay hidden from a player out on the grounds (not the ledges' or the yard's)
		var hide_m: float = 0.0 if (float((w[2] as Vector3).y) > 1.0 or str(w[0]) == "W_STB_S") else OUT_WINDOW_HIDE_M
		var sp: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_" + str(w[0]), {
			"zone_id": w[1], "window_path": NodePath("../" + str(w[0])), "kind": &"window", "hide_from_m": hide_m}) as Marker3D
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		var out_dist: float = 1.6 if float((w[2] as Vector3).y) > 1.0 else 5.0
		var spawn_pos: Vector3 = (w[2] as Vector3) - inward * out_dist
		if float((w[2] as Vector3).y) > 1.0:
			spawn_pos.x += -1.6 if (w[2] as Vector3).x < 12.0 else 1.6   # ledge ends
		sp.position = spawn_pos
		gameplay.add_child(sp)
	# ground spawn: the hay pile behind the stalls (round 6+)
	var hay: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_HayPile", {
		"zone_id": &"STABLE", "kind": &"ground", "min_round": 6}) as Marker3D
	hay.position = Vector3(22.5, 0, 23.7)   # (the pile moved 0.4 m west for the stair's foot, T-084)
	gameplay.add_child(hay)
	# ground spawn: the drift in the yard's south-west corner (round 4+)
	var mound: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_YardMound", {
		"zone_id": &"YARD", "kind": &"ground", "min_round": 7}) as Marker3D
	mound.position = Vector3(5.0, 0, 44.5)
	gameplay.add_child(mound)

	# doors
	var d1: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Upstairs", {
		"door_id": &"door_upstairs", "opens_zone": &"UPSTAIRS", "cost": 750, "size": Vector3(1.6, DOOR_H, 0.25), "label": "Upstairs"})
	d1.position = Vector3(STAIR_X1, 0, 15.1)
	d1.rotation.y = deg_to_rad(90)
	gameplay.add_child(d1)
	var d2: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Stable", {
		"door_id": &"door_stable", "opens_zone": &"STABLE", "cost": 1000, "size": Vector3(2.0, DOOR_H, 0.25), "label": "Stable"})
	d2.position = Vector3(20.0, 0, 16.0)
	gameplay.add_child(d2)
	var d4: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Yard", {
		"door_id": &"door_yard", "opens_zone": &"YARD", "cost": 1250, "size": Vector3(2.0, DOOR_H, 0.25), "label": "The Yard",
		"also_opens": PackedStringArray(["STABLE"])})   # (bought from the yard side, T-080: you walk into the stable)
	d4.position = Vector3(8.0, 0, 34.0)
	gameplay.add_child(d4)
	# the front door, the round 1 opening's patrons and the gramophone they leave playing on the bar (T-072)
	var fd: Node3D = _scripted(Node3D.new(), "res://gravelight/world/inn_opening/inn_front_door.gd", "InnFrontDoor", {"width": 1.6, "height": DOOR_H, "wall": T})
	fd.position = Vector3(FRONT_DOOR_X, 0, 0)
	gameplay.add_child(fd)
	build_grounds_gameplay()
	gameplay.add_child(_scripted(Node3D.new(), "res://gravelight/world/inn_opening/inn_opening.gd", "InnOpening", {}))
	var gram: Node3D = _scripted(Node3D.new(), "res://gravelight/world/inn_opening/inn_gramophone.gd", "InnGramophone", {"stop_round": 3})
	gram.position = Vector3(5.75, 1.1, 8.4)
	gram.rotation.y = deg_to_rad(200.0)
	gameplay.add_child(gram)
	# the survivors hiding in the middle guest room until the stair door is opened (T-077, map00_survivors.json)
	gameplay.add_child(_scripted(Node3D.new(), "res://gravelight/world/inn_opening/inn_survivors.gd", "InnSurvivors", {}))

	build_cellar_gameplay()

	# wall-buys: [weapon, position, yaw so local -Z faces the room]. Nudged off the wall past the timber trim.
	var buys: Array = [
		[&"kar98k", Vector3(T * 0.5 + 0.04, 1.5, 3.1), -90.0],   # moved from z 8.6 for the Old Cellar door (T-051)
		[&"m1_garand", Vector3(24 - T * 0.5 - 0.04, 1.5, 4.0), 90.0],   # moved from z 12.5 for the cellar door (T-027)
		[&"mp40", Vector3(T * 0.5 + 0.04, UP_Y + 1.5, 3.4), -90.0],
		[&"trench_gun", Vector3(STB_X0 + T * 0.5 + 0.01, 1.5, 29.5), -90.0],
		[&"thompson", Vector3(22.0, 1.5, 34 + T * 0.5 + 0.04), 180.0],   # the yard: chalked on the stable's outside wall
	]
	for b: Array in buys:
		var wb: Node3D = _scripted(Node3D.new(), "res://gravelight/world/wall_buy.gd", "WallBuy_" + String(b[0]), {"weapon_id": b[0]})
		wb.position = b[1]
		wb.rotation.y = deg_to_rad(float(b[2]))
		gameplay.add_child(wb)
		# a small warm lamp over each chalk outline so buys read at a glance
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = "BuyLight"
		lamp.light_color = Color(1.0, 0.8, 0.55)
		lamp.light_energy = 0.6
		lamp.omni_range = 1.8
		lamp.position = (b[1] as Vector3) + Basis(Vector3.UP, deg_to_rad(float(b[2]))) * Vector3(0, 0.75, -0.5)
		gameplay.add_child(lamp)

	# zones (spawn weighting)
	var zones: Array = [
		[&"TAPROOM", Vector3(12, 0, 8), Vector3(24, 3.5, 16)],
		[&"UPSTAIRS", Vector3(12, UP_Y - 0.2, 5), Vector3(24, 3.2, 10)],
		[&"UPSTAIRS", Vector3(STAIR_X1 * 0.5, 0, 13), Vector3(STAIR_X1, 7, 6)],
		[&"STABLE", Vector3((STB_X0 + STB_X1) * 0.5, 0, 28), Vector3(STB_X1 - STB_X0, 7, 12)],
		[&"STABLE", Vector3(20, 0, 19), Vector3(4, 3, 6)],
		[&"YARD", Vector3(18, 0, 41), Vector3(32, 4, 14)],
	]
	for r: Array in OUT_ZONE_RECTS:   # T-080: the grounds, open ground (roam)
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		zones.append([&"GROUNDS", Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5), Vector3(b.x - a.x, 3.0, b.y - a.y), true])
	for r2: Array in OUT_WELL_RECTS:
		var a2: Vector2 = r2[0]
		var b2: Vector2 = r2[1]
		zones.append([&"GROUNDS", Vector3((a2.x + b2.x) * 0.5, OC_WELL_Y, (a2.y + b2.y) * 0.5), Vector3(b2.x - a2.x, 1.6, b2.y - a2.y), true])
	for pk: Rect2 in edge_pockets():   # the spawn pockets beyond the edge are open ground too (T-084)
		var pc: Vector2 = pk.get_center()
		zones.append([&"GROUNDS", Vector3(pc.x, 0, pc.y), Vector3(pk.size.x, 3.0, pk.size.y), true])
	var zi: int = 0
	for z: Array in zones:
		var zv: Node3D = _scripted(Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_%s_%d" % [z[0], zi], {"zone_id": z[0], "size": z[2], "roam": z.size() > 3})
		zv.position = z[1]
		gameplay.add_child(zv)
		zi += 1

	# crate spots: [name, position, yaw (local -Z faces the room), can_start]. MAPS.md: start = Taproom or Stable.
	var ci: int = 0
	for c: Array in CRATES:
		var cr: Node3D = _scripted(Node3D.new(), "res://gravelight/world/mystery_crate.gd", "Crate_" + str(c[0]), {
			"spot_index": ci, "can_start": c[3], "spot_name": c[0]})
		cr.position = c[1]
		cr.rotation.y = deg_to_rad(float(c[2]))
		gameplay.add_child(cr)
		ci += 1
	for ab2: Array in AMMO_BOXES:
		var ammo: Node3D = _scripted(Node3D.new(), "res://gravelight/world/ammo_box.gd", "AmmoBox_" + str(ab2[0]), {"box_name": str(ab2[0]).to_lower()})
		ammo.position = ab2[1]
		ammo.rotation.y = deg_to_rad(float(ab2[2]))
		gameplay.add_child(ammo)
	var bench: Node3D = _scripted(Node3D.new(), "res://gravelight/world/armorers_bench.gd", "ArmorersBench", {})
	bench.position = ARMORERS_BENCH[0]
	bench.rotation.y = deg_to_rad(float(ARMORERS_BENCH[1]))
	gameplay.add_child(bench)
	var radio: Node3D = _scripted(Node3D.new(), "res://gravelight/world/field_radio.gd", "FieldRadio", {})
	radio.position = Vector3(4.8, 2.0, 4.9)
	radio.rotation.y = deg_to_rad(-90)
	gameplay.add_child(radio)
	# radio notes (fixed spots, EASTER_EGGS.md section 4)
	for n: Array in [["NoteA", "note_a", "3.120", "I", Vector3(12.5, 1.51, 0.55)],
			["NoteB", "note_b", "5.785", "II", Vector3(11.0, UP_Y + 0.51, 0.85)],
			["NoteC", "note_c", "7.440", "III", Vector3(8.0, 3.51, 29.0)]]:
		var note: Node3D = _scripted(Node3D.new(), "res://gravelight/world/quest_note.gd", str(n[0]), {
			"tag": &"radio_note", "item_id": StringName(str(n[1])), "note_text": n[2], "numeral": n[3]})
		note.position = n[4]
		gameplay.add_child(note)


## T-080: a field spawn a player out on the grounds can see from within this far is not used (ZombieSpawn.hide_from_m;
## the edge's and the snow's are closer: they are farther from the loop).
const OUT_WINDOW_HIDE_M: float = 16.0


## The grounds' gameplay (T-080): the two ways out (the front door and the yard's gate, GateDoors that swing), the
## spawns at the edge and in the snow. The zone volumes are with the others in build_gameplay (OUT_ZONE_RECTS).
func build_grounds_gameplay() -> void:
	# Door_Front, "Out Front": the front door the round 1 opening's patrons run out of; once bought it is thrown open
	# for good (InnFrontDoor.held_open). The price is painted on the wall beside it.
	var df: Node3D = _scripted(Node3D.new(), "res://gravelight/world/gate_door.gd", "Door_Front", {
		"door_id": &"door_front", "opens_zone": &"GROUNDS", "cost": 1250, "size": Vector3(1.6, DOOR_H, T), "label": "Out Front",
		"swing_node": NodePath("../InnFrontDoor"), "swing_deg": 150.0, "label_offset": Vector3(1.45, 1.55, 0.0)})
	df.position = Vector3(FRONT_DOOR_X, 0, 0)
	gameplay.add_child(df)
	# Door_Gate: the carters' gate in the yard's south fence, 750, chained from the outside the night the plane came
	# down; it swings out onto the road and opens the yard as well when bought from the road
	var dg: Node3D = _scripted(Node3D.new(), "res://gravelight/world/gate_door.gd", "Door_Gate", {
		"door_id": &"door_gate", "opens_zone": &"GROUNDS", "also_opens": PackedStringArray(["YARD"]), "cost": 750,
		"size": Vector3(4.0, 2.3, 0.25), "label": "The Gate", "leaves": 2, "swing_deg": 100.0, "swing_out": 1.0})
	dg.position = Vector3(18.0, 0, 48.0)
	gameplay.add_child(dg)
	var i: int = 0
	for p: Vector3 in OUT_EDGE_SPAWNS:
		var sp: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_Edge%d" % i, {
			"zone_id": &"GROUNDS", "kind": &"edge", "player_zone_only": true, "hide_from_m": 12.0}) as Marker3D
		sp.position = p
		gameplay.add_child(sp)
		i += 1
	i = 0
	for p2: Vector3 in OUT_GROUND_SPAWNS:
		var gs: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_Snow%d" % i, {
			"zone_id": &"GROUNDS", "kind": &"ground", "min_round": 4, "player_zone_only": true, "hide_from_m": 10.0}) as Marker3D
		gs.position = p2
		gameplay.add_child(gs)
		i += 1
	# the lamps out here: the porch lantern over the front door, the two lamp posts, the woodshed's, and a cold moon
	# fill over each side of the field (like the yard's)
	var warm: Color = Color(1.0, 0.62, 0.32)
	_lamp("OutPorchLamp", Vector3(21.2, 2.55, -1.9), warm, 3.5, 12.0, false, true, 0.15)
	_lamp("OutCrossLamp", Vector3(-6.95, 2.4, -4.6), warm, 4.0, 13.0, false, true, 0.2)
	_lamp("OutRoadLamp", Vector3(37.65, 2.4, -10.8), warm, 3.5, 12.0, false, true, 0.2)
	_lamp("OutShedLamp", Vector3(-3.0, 1.95, 56.35), warm, 3.5, 11.0, false, true, 0.15)
	for mf: Vector3 in [Vector3(20, 6, -18), Vector3(-11, 6, 24), Vector3(18, 6, 57), Vector3(48, 6, 38)]:
		_lamp("OutMoonFill", mf, Color(0.5, 0.6, 0.85), 0.25, 24.0, false, false)


## Door 3 (1500) -> the Helvetia cellar: all 9 perk machines, the cellar lever (Map 0's power), a coal chute
## that starts spawning at round 6, and the power-on burst points. Machines stand 1.1 m+ off the walls so the
## fine-print panels on their backs can be read (JINGLES.md section 0.3). T&C M2, DECISIONS T-027.
func build_cellar_gameplay() -> void:
	var cy: float = CELLAR_Y
	var d3: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Cellar", {
		"door_id": &"door_cellar", "opens_zone": &"CELLAR", "cost": 1500, "size": Vector3(1.6, DOOR_H, 0.25), "label": "Cellar"})
	d3.position = Vector3(24.0, 0, 11.5)
	d3.rotation.y = deg_to_rad(90)
	gameplay.add_child(d3)
	for z: Array in [[Vector3(26, cy, 14.5), Vector3(4, 6.5, 9)], [Vector3(30, cy, 25), Vector3(12, 2.7, 12)]]:   # top stays under the ceiling, so the yard above is not "cellar"
		var zv: Node3D = _scripted(Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_CELLAR", {"zone_id": &"CELLAR", "size": z[1]})
		zv.position = z[0]
		gameplay.add_child(zv)
	for pk: Array in CELLAR_PERKS:
		var m: Node3D = _scripted(Node3D.new(), "res://gravelight/world/perk_machine.gd", "Perk_" + str(pk[0]), {"perk_id": StringName(str(pk[0]))})
		m.position = pk[1]
		m.rotation.y = deg_to_rad(float(pk[2]))
		gameplay.add_child(m)
	# THE CRUCIBLE (T-032, the user asked for weapon upgrades on Map 0): in the alcove on the north wall between the
	# stair mouth and the lever, facing south into the vault. It runs off the cellar lever like the machines.
	var cru: Node3D = _scripted(Node3D.new(), "res://gravelight/world/crucible.gd", "Crucible", {"needs_power": true})
	cru.position = Vector3(29.5, cy, 19.95)
	cru.rotation.y = deg_to_rad(180.0)
	gameplay.add_child(cru)
	var sw: Node3D = _scripted(Node3D.new(), "res://gravelight/world/power_switch.gd", "Kellerschalter", {
		"config_table": "map00", "label": "the cellar lever", "zone_order": PackedStringArray(["CELLAR", "OLD_CELLAR", "TAPROOM", "UPSTAIRS", "STABLE"])})
	sw.position = Vector3(32.5, cy + 0.3, 19.35)
	sw.rotation.y = deg_to_rad(180)
	gameplay.add_child(sw)
	# lights: one oil lamp at the foot of the stairs always lit; the bulbs over the machines wait for the lever
	_lamp("CellarHallLamp", Vector3(26.0, 2.5, 10.8), Color(1.0, 0.72, 0.45), 1.0, 7.0, false, true)
	_lamp("CellarStairLamp", Vector3(26.0, cy + 2.3, 19.6), Color(1.0, 0.7, 0.4), 1.0, 6.5, false, true)
	var first_bulb: OmniLight3D = null
	for lp: Vector3 in CELLAR_BULBS:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "CellarBulb"
		l.position = lp - Vector3(0, 0.05, 0)
		l.light_color = Color(1.0, 0.85, 0.6)
		l.light_energy = 1.5
		l.omni_range = 7.5
		l.omni_attenuation = 1.4
		l.visible = false
		l.set_meta("zone", &"CELLAR")
		l.set_meta("energy", 1.5)
		l.add_to_group(&"power_lights", true)
		map_root.add_child(l)
		if first_bulb == null:
			first_bulb = l
	# the lit bulb glass rides under the first bulb light, so it shows when the sweep turns the lights on
	if _cellar_lit != null and first_bulb != null:
		_cellar_lit.get_parent().remove_child(_cellar_lit)
		first_bulb.add_child(_cellar_lit)
		_cellar_lit.position = -first_bulb.position
	# the coal chute: a ground spawn in the far corner from round 6
	var chute: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_CoalChute", {
		"zone_id": &"CELLAR", "kind": &"ground", "min_round": 6}) as Marker3D
	chute.position = Vector3(34.2, cy, 29.6)
	gameplay.add_child(chute)
	for bp: Vector3 in [Vector3(34.2, cy, 29.6), Vector3(25.6, cy, 29.9)]:
		var mk: Marker3D = Marker3D.new()
		mk.name = "BurstPoint"
		mk.position = bp
		mk.add_to_group(&"power_burst_points", true)
		gameplay.add_child(mk)
	build_old_cellar_gameplay()


## The Old Cellar's gameplay (T-051): Door 5, the breach to the Helvetia cellar, the zone,
## the two light-well windows and their field spawns, the Gewehr 43, the holding cell's nodes
## for Jakub (section 6.2), the ice cellar's seal and markers for HB1, drips, lanterns and the power bulbs.
func build_old_cellar_gameplay() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var d5: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_OldCellar", {
		"door_id": &"door_old_cellar", "opens_zone": &"OLD_CELLAR", "cost": 1250, "size": Vector3(1.6, DOOR_H, 0.25), "label": "Old Cellar"})
	d5.position = Vector3(0.0, 0, 9.05)
	d5.rotation.y = deg_to_rad(90)
	gameplay.add_child(d5)
	# the installers' breach to the Helvetia cellar: bricked up again until both cellars are open (Door 3 and Door 5),
	# then it falls in by itself. The map's navmesh ("Navigation") is baked with the breach shut; when it opens it
	# swaps to "NavigationBreachOpen" (the same bake with the breach open), so no path ever runs through the breach
	# while a door on the taproom / cellar / old cellar ring is still shut. (A NavigationLink3D across it was tried:
	# zombies re-pathing inside the cut snapped back to the near side and dithered in the doorway.)
	var br: Node3D = _scripted(Node3D.new(), "res://gravelight/world/sealed_passage.gd", "CellarBreach", {
		"passage_id": &"cellar_breach", "size": Vector3(1.6, DOOR_H, 0.3),
		"open_when_zones": PackedStringArray(["CELLAR", "OLD_CELLAR"]),
		"nav_swap_off": NodePath("../../Navigation"), "nav_swap_on": NodePath("../../NavigationBreachOpen")})
	br.position = Vector3(24.0, cy, 20.25)
	br.rotation.y = deg_to_rad(90)
	gameplay.add_child(br)
	# zone volumes: under the taproom, the wine cellar's south bay, the breach, the stair lean-to (tops kept under
	# the taproom's floor, so the taproom above is not "old cellar")
	for z: Array in [[Vector3(12.0, cy, 8.0), Vector3(24.0, 2.7, 16.0)], [Vector3(5.45, cy, 17.25), Vector3(10.9, 2.7, 2.5)],
			[Vector3(22.43, cy, 18.7), Vector3(3.15, 2.7, 5.2)], [Vector3(-1.5, cy, 13.25), Vector3(3.0, 6.0, 10.5)]]:
		var zv: Node3D = _scripted(Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_OLD_CELLAR", {"zone_id": &"OLD_CELLAR", "size": z[1]})
		zv.position = z[0]
		gameplay.add_child(zv)
	# the light-well windows: half-height crawl-ins, the room floor 1.9 m below the sill (Barricade.inside_drop);
	# [id, origin on the well floor at the wall line, inward yaw, field spawn at the top of the well steps]
	for w: Array in [["W_CEL_COAL", Vector3(3.45, OC_WELL_Y, 0.0), 0.0, Vector3(3.45, 0, -7.5)],
			["W_CEL_VAULT", Vector3(24.0, OC_WELL_Y, 1.8), -90.0, Vector3(25.2, 0, -5.5)]]:
		var bar: Node3D = _scripted(Node3D.new(), "res://gravelight/world/barricade.gd", str(w[0]), {
			"window_id": StringName(str(w[0])), "zone_id": &"OLD_CELLAR", "width": 1.6, "sill_height": OC_SILL,
			"top_height": OC_WIN_H, "inside_drop": OC_WELL_Y - cy})
		bar.position = w[1]
		bar.rotation.y = deg_to_rad(float(w[2]))
		gameplay.add_child(bar)
		var sp: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_" + str(w[0]), {
			"zone_id": &"OLD_CELLAR", "window_path": NodePath("../" + str(w[0])), "kind": &"window"}) as Marker3D
		sp.position = w[3]
		gameplay.add_child(sp)
	# the wall-buy: the M1 Garand (taproom) and the Thompson (yard) are already on the map, so the patrol's Gewehr 43
	# hangs on the vault's west wall, facing the loop
	var wb: Node3D = _scripted(Node3D.new(), "res://gravelight/world/wall_buy.gd", "WallBuy_gewehr43", {"weapon_id": &"gewehr43"})
	wb.position = Vector3(10.9 + T * 0.5 + 0.04, cy + 1.5, 6.6)
	wb.rotation.y = deg_to_rad(-90)
	gameplay.add_child(wb)
	var bl: OmniLight3D = OmniLight3D.new()
	bl.name = "BuyLight"
	bl.light_color = Color(1.0, 0.8, 0.55)
	bl.light_energy = 0.6
	bl.omni_range = 1.8
	bl.position = wb.position + Vector3(0.5, 0.75, 0)
	gameplay.add_child(bl)
	# (the ammo box is AMMO_BOXES "Cellar", on the vault's south wall, 11 m+ from the machines and the Crucible)
	# the holding cell (section 6.2): the cage's hinged door is a HoldingCage (origin on the hinge, local +X along the
	# door, local -Z out of the cage); Jakub stands inside at JakubSpawn and waits by the cage at JakubWait
	var cage: Node3D = _scripted(Node3D.new(), "res://gravelight/world/holding_cage.gd", "JakubCage", {
		"door_width": OC_CAGE_DOOR.y - OC_CAGE_DOOR.x, "door_height": top - cy})
	cage.position = Vector3(OC_CAGE.end.x, cy, OC_CAGE_DOOR.x)
	cage.rotation.y = deg_to_rad(-90)
	gameplay.add_child(cage)
	_cage_door(cage)
	for m: Array in [["JakubSpawn", Vector3(1.25, cy, 4.9), 90.0], ["JakubWait", Vector3(3.95, cy, 6.3), -90.0]]:
		var mk: Marker3D = Marker3D.new()
		mk.name = str(m[0])
		mk.position = m[1]
		mk.rotation.y = deg_to_rad(float(m[2]))   # facing out of the cage / toward the cellar door
		gameplay.add_child(mk)
	var shovel: Node3D = Props.group(gameplay, "CoalShovel", Vector3(2.78, cy, 3.62), 0.0)
	Props.obox(shovel, Vector3(0, 0.62, 0.08), Vector3(0.035, 1.1, 0.035), "beam", Vector3(-14, 0, 0))
	Props.obox(shovel, Vector3(0, 0.08, -0.06), Vector3(0.26, 0.02, 0.3), "iron", Vector3(-14, 0, 0))
	Props.obox(shovel, Vector3(0, 1.16, 0.22), Vector3(0.14, 0.04, 0.04), "beam", Vector3(-14, 0, 0))
	# the ice cellar: bricked off from the coal room until the Cousins round is cleared (HB1 files the aunt's letter,
	# INT_HB_01, on the clear; the seal falls in on that cue). Markers for HB1's letter, chalk figures and hatch.
	var seal: Node3D = _scripted(Node3D.new(), "res://gravelight/world/sealed_passage.gd", "IceCellarSeal", {
		"passage_id": &"ice_cellar", "size": Vector3(1.6, 2.0, 0.3), "open_on_intel": &"INT_HB_01"})
	seal.position = Vector3(5.0, cy, 6.7)
	seal.rotation.y = deg_to_rad(90)
	gameplay.add_child(seal)
	for m2: Array in [["IceCellarLetter", Vector3(7.55, cy + 0.42, 7.35)], ["IceCellarChalk", Vector3(8.13, cy + 1.25, 6.3)],
			["IceCellarHatch", Vector3(6.6, top, 5.6)]]:
		var mk2: Marker3D = Marker3D.new()
		mk2.name = str(m2[0])
		mk2.position = m2[1]
		gameplay.add_child(mk2)
	# water dripping from the vault and the wine cellar's arches (sound + a falling drop)
	for dp: Vector3 in [Vector3(6.9, top - 0.02, 15.3), Vector3(1.7, top - 0.02, 11.4), Vector3(20.6, top - 0.02, 4.4), Vector3(9.5, top - 0.02, 3.3)]:
		var drip: Node3D = _scripted(Node3D.new(), "res://gravelight/world/drip_point.gd", "Drip", {"height": top - 0.02 - cy})
		drip.position = dp
		gameplay.add_child(drip)
	# lights: oil lanterns always lit (the stair, wine cellar, root cellar, the guard's lamp by the cage, the vault);
	# bare bulbs over the loop and the wine cellar wait for the cellar lever (zone OLD_CELLAR in the sweep)
	var warm: Color = Color(1.0, 0.68, 0.4)
	for l: Array in [["OCStairLamp", Vector3(-1.5, 1.85, 12.6), 1.0, 7.0], ["OCStairFootLamp", Vector3(-2.45, cy + 2.1, 17.0), 0.9, 6.5],
			["OCWineLamp", Vector3(5.4, cy + 1.95, 10.7), 1.5, 9.0], ["OCWineLamp2", Vector3(4.0, cy + 1.95, 16.0), 1.2, 8.0],
			["OCRootLamp", Vector3(7.6, cy + 1.95, 2.7), 1.2, 7.5], ["OCCageLamp", Vector3(3.9, cy + 2.0, 3.9), 1.5, 8.0],
			["OCVaultLamp", Vector3(13.4, cy + 2.05, 8.0), 1.6, 10.0], ["OCVaultLamp2", Vector3(21.6, cy + 2.05, 8.0), 1.6, 10.0],
			["OCBreachLamp", Vector3(22.4, cy + 2.1, 19.6), 0.8, 6.0]]:
		_lamp(str(l[0]), l[1], warm, float(l[2]), float(l[3]), false, true, 0.12)
	for bp: Vector3 in OC_BULBS:
		var b: OmniLight3D = OmniLight3D.new()
		b.name = "OldCellarBulb"
		b.position = bp - Vector3(0, 0.05, 0)
		b.light_color = Color(1.0, 0.85, 0.6)
		b.light_energy = 1.3
		b.omni_range = 7.0
		b.omni_attenuation = 1.4
		b.visible = false
		b.set_meta("zone", &"OLD_CELLAR")
		b.set_meta("energy", 1.3)
		b.add_to_group(&"power_lights", true)
		map_root.add_child(b)
		if _old_cellar_lit != null and _old_cellar_lit.get_parent() == dress:
			dress.remove_child(_old_cellar_lit)
			b.add_child(_old_cellar_lit)
			_old_cellar_lit.position = -b.position
	# cold moonlight down each light well, through the boards (the windows read from across the room)
	# (T-061: brighter, shadowed so the window's boards stripe it, the coal well's aimed into the cage)
	for wp: Array in [[Vector3(3.45, 0.9, -2.2), Vector3(2.3, cy, 3.9)], [Vector3(26.0, 0.9, 1.8), Vector3(21.4, cy, 1.8)]]:
		var sp2: SpotLight3D = SpotLight3D.new()
		sp2.name = "WellMoonSpill"
		sp2.light_color = Color(0.55, 0.65, 1.0)
		sp2.light_energy = 4.5
		sp2.light_volumetric_fog_energy = 2.5
		sp2.spot_range = 9.0
		sp2.spot_angle = 26.0
		sp2.spot_attenuation = 1.0
		sp2.shadow_enabled = true
		map_root.add_child(sp2)
		sp2.look_at_from_position(wp[0], wp[1], Vector3.UP)


## The holding cell's door leaf under the HoldingCage (local frame: +X from the hinge to the latch, -Z out of the
## cage): flat bars, two straps, the hinge knuckles, a hasp with a padlock. Kept off the static batch (meta "keep").
func _cage_door(cage: Node3D) -> void:
	var w: float = OC_CAGE_DOOR.y - OC_CAGE_DOOR.x
	var h: float = CELLAR_TOP - CELLAR_Y
	var hinge: Node3D = Props.group(cage, "Hinge", Vector3.ZERO)
	var n: int = int(w / 0.13)
	for k: int in n:
		var x: float = 0.08 + float(k) * (w - 0.16) / float(maxi(1, n - 1))
		Props.cyl(hinge, Vector3(x, h * 0.5, 0), 0.014, h - 0.06, "iron")
	for y: float in [0.12, 1.05, h - 0.12]:
		Props.block(hinge, Vector3(0.0, y - 0.03, -0.02), Vector3(w, y + 0.03, 0.02), "iron")
	for y2: float in [0.4, h - 0.5]:
		Props.cyl(hinge, Vector3(0.0, y2, 0), 0.03, 0.14, "iron")
	Props.block(hinge, Vector3(w - 0.12, 1.0, -0.05), Vector3(w - 0.02, 1.12, 0.0), "iron")   # the hasp
	Props.block(hinge, Vector3(w - 0.1, 0.86, -0.07), Vector3(w - 0.03, 0.98, -0.04), "brass")   # the padlock
	for m: Node in hinge.find_children("*", "MeshInstance3D", true, false):
		m.set_meta("keep", true)

