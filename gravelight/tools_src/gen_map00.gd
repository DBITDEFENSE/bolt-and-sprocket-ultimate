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
const WIN_SILL: float = 0.9
const WIN_TOP: float = 2.2
const DOOR_H: float = 2.4
const WAINSCOT_H: float = 1.1

## Old greybox keys -> material library keys (world/materials.gd).
const MAT_MAP: Dictionary = {
	"wall": "plaster", "wall_upper": "plaster_upper", "stable": "planks", "floor_wood": "floorboards",
	"floor_dirt": "dirt", "snow": "snow", "roof": "roof", "furniture": "furniture", "stone": "stone",
	"stairs": "furniture", "metal": "iron", "quest": "nachtglas", "fire": "fire", "hay": "hay", "wreck": "wreck",
}

var map_root: Node3D
var nav: NavigationRegion3D
var geo: Node3D
var dress: Node3D
var gameplay: Node3D
var _count: int = 0
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
	get_root().remove_child(map_root)
	build_dressing()
	var merged: int = merge_static_meshes()
	print("merged %d static meshes into batches" % merged)
	build_environment()
	build_gameplay()
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
## +Z/-Z face, 2 = both faces.
func wall_x(name_: String, z: float, x0: float, x1: float, y0: float, y1: float, openings: Array, mat_key: String, trim: int = 0) -> void:
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
				_wainscot(true, z + side * T * 0.5, float(side), float(s[0]), float(s[1]), y0, float(s[2]))


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
func ramp_z(name_: String, x0: float, x1: float, z_low: float, z_high: float, y_low: float, y_high: float) -> void:
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
	_stair_dressing.append([x0, x1, z_low, z_high, y_low, y_high])


var _stair_dressing: Array = []


func _own(n: Node, owner_node: Node) -> void:
	for c: Node in n.get_children():
		if c.owner == null:
			c.owner = owner_node
		if c.scene_file_path == "":
			_own(c, owner_node)


# ================================================================== collision shell (navmesh source)

func build_geometry() -> void:
	# ground slab, with a hole over the cellar annex (x 24..36, z 10..31; T&C M2, DECISIONS T-027)
	box(geo, "Ground", Vector3(-45, -0.5, -40), Vector3(24, 0.0, 75), "snow")
	box(geo, "GroundE", Vector3(36, -0.5, -40), Vector3(70, 0.0, 75), "snow")
	box(geo, "GroundN", Vector3(24, -0.5, -40), Vector3(36, 0.0, 10), "snow")
	box(geo, "GroundS", Vector3(24, -0.5, 31), Vector3(36, 0.0, 75), "snow")

	# ---------------- TAPROOM (ground floor)
	var win: Array = [WIN_SILL, WIN_TOP]
	wall_x("TapN", 0.0, -T * 0.5, 24 + T * 0.5, 0, TAP_H, [[6.2, 7.8] + win, [16.2, 17.8] + win], "wall", 1)
	wall_z("TapW", 0.0, 0, 10, 0, TAP_H, [[5.2, 6.8] + win], "wall", 1)
	wall_z("TapE", 24.0, 0, 16, 0, TAP_H, [[7.2, 8.8] + win, [10.7, 12.3, 0.0, DOOR_H]], "wall", -1)
	wall_x("TapS", 16.0, 3, 24 + T * 0.5, 0, TAP_H, [[19.0, 21.0, 0.0, DOOR_H]], "wall", -1)
	# stairwell enclosure (x 0..3, z 10..16), full height; Door 1 opening on its east wall
	wall_z("StairW", 0.0, 10, 16 + T * 0.5, 0, UP_TOP, [], "wall", 1)
	wall_x("StairS", 16.0, -T * 0.5, 3, 0, UP_TOP, [], "wall", -1)
	wall_z("StairE", 3.0, 10, 16, 0, UP_TOP, [[14.3, 15.9, 0.0, DOOR_H]], "wall", 2)
	box(geo, "StairRoof", Vector3(-T * 0.5, UP_TOP, 10), Vector3(3 + T * 0.5, UP_TOP + 0.2, 16 + T * 0.5), "roof")
	ramp_z("Stairs", 0.15, 2.85, 15.0, 10.0, 0.0, UP_Y)
	# ceiling slabs: A = upstairs floor (z 0..10), B = taproom roof south of it
	box(geo, "SlabA", Vector3(-T * 0.5, TAP_H, -T * 0.5), Vector3(24 + T * 0.5, UP_Y, 10), "floor_wood")
	box(geo, "SlabB", Vector3(3, TAP_H, 10), Vector3(24 + T * 0.5, UP_Y, 16 + T * 0.5), "floor_wood")
	# fireplace + chimney (north wall): collision only, drawn by the dressing pass
	box(geo, "Hearth", Vector3(10.9, 0, 0.15), Vector3(13.1, 1.5, 0.95), "stone", true, false)
	box(geo, "Chimney", Vector3(11.2, 1.5, 0.15), Vector3(12.8, TAP_H, 0.6), "stone")
	# bar (counter front + side) and back shelf: collision only
	box(geo, "BarFront", Vector3(5.0, 0, 8.0), Vector3(9.0, 1.1, 8.8), "furniture", true, false)
	box(geo, "BarSide", Vector3(8.2, 0, 3.0), Vector3(9.0, 1.1, 8.0), "furniture", true, false)
	box(geo, "BackShelf", Vector3(4.6, 0, 3.0), Vector3(5.0, 2.0, 8.0), "furniture", true, false)
	for p: Vector2 in [Vector2(12.5, 11.5), Vector2(16.5, 11.5), Vector2(20.0, 4.5)]:
		box(geo, "Table", Vector3(p.x - 0.6, 0, p.y - 0.6), Vector3(p.x + 0.6, 0.75, p.y + 0.6), "furniture", true, false)

	# ---------------- UPSTAIRS (y 3.8 .. 6.8, z 0..10)
	var up_win: Array = [UP_Y + WIN_SILL, UP_Y + WIN_TOP]
	wall_x("UpN", 0.0, -T * 0.5, 24 + T * 0.5, UP_Y, UP_TOP, [[3.2, 4.8] + up_win, [19.2, 20.8] + up_win], "wall_upper", 1)
	wall_z("UpW", 0.0, 0, 10, UP_Y, UP_TOP, [], "wall_upper", 1)
	wall_z("UpE", 24.0, 0, 10, UP_Y, UP_TOP, [], "wall_upper", -1)
	wall_x("UpS", 10.0, 3, 24 + T * 0.5, UP_Y, UP_TOP, [], "wall_upper", -1)
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

	# ---------------- STABLE (x 6..24, z 22..34, ceiling 7)
	wall_x("StbN", 22.0, 6 - T * 0.5, 24 + T * 0.5, 0, STABLE_H, [[8.2, 9.8] + win, [13.2, 14.8] + win, [18.5, 21.5, 0.0, 2.6]], "stable")
	wall_x("StbS", 34.0, 6 - T * 0.5, 24 + T * 0.5, 0, STABLE_H, [[11.2, 12.8] + win], "stable")
	wall_z("StbW", 6.0, 22, 34, 0, STABLE_H, [], "stable")
	wall_z("StbE", 24.0, 22, 34, 0, STABLE_H, [], "stable")
	box(geo, "StbRoof", Vector3(6 - T * 0.5, STABLE_H, 22 - T * 0.5), Vector3(24 + T * 0.5, STABLE_H + 0.2, 34 + T * 0.5), "planks")
	for x: float in [11.0, 16.0, 17.6]:
		box(geo, "Stall", Vector3(x - 0.08, 0, 22.2), Vector3(x + 0.08, 1.3, 25.2), "planks")
	box(geo, "Hayloft", Vector3(6, 3.2, 22), Vector3(15, 3.5, 34), "floor_wood")
	box(geo, "HayLanding", Vector3(15, 3.2, 25.5), Vector3(17.0, 3.5, 27.5), "floor_wood")
	ramp_z("HayStairs", 15.0, 17.0, 32.5, 27.5, 0.0, 3.5)
	box(geo, "HayBales", Vector3(6.3, 3.5, 30.5), Vector3(9.5, 4.4, 33.7), "hay", true, false)
	box(geo, "CartCol", Vector3(7.0, 0, 31.4), Vector3(9.8, 1.1, 33.4), "furniture", true, false)

	build_cellar()
	build_nav_blocks()

	# ---------------- crash site (east field): GRAVELIGHT ONE (collision for the hull only)
	var wreck: Node3D = Node3D.new()
	wreck.name = "Wreck"
	wreck.position = Vector3(46, 0, 6)
	wreck.rotation = Vector3(0, deg_to_rad(28), deg_to_rad(-8))
	geo.add_child(wreck)
	box(wreck, "Fuselage", Vector3(-1.4, 0, -7), Vector3(1.4, 2.6, 6), "wreck", true, false)
	box(wreck, "Wing", Vector3(-9, 0.4, -1.5), Vector3(7, 0.7, 1.5), "wreck", true, false)


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
]
## Same as PerkMachine._shape_footprint (that script needs the autoloads, which a --script run doesn't have).
## Keep the two in step.
const MACHINE_FOOTPRINTS: Dictionary = {
	"barrel": Vector3(1.2, 1.9, 1.2), "cabinet": Vector3(0.8, 2.3, 0.6), "crate": Vector3(1.0, 2.0, 0.65),
	"twin": Vector3(1.2, 2.1, 0.6), "teardrop": Vector3(1.0, 2.4, 0.9), "periscope": Vector3(0.9, 1.8, 0.65),
	"wagon": Vector3(1.7, 1.7, 0.85), "safe": Vector3(1.1, 1.9, 0.95),
}
## crate spots: [name, position, yaw, can_start]
const CRATES: Array = [["Hearth", Vector3(22.9, 0, 14.0), 90.0, true], ["GuestBed", Vector3(22.0, UP_Y, 0.8), 180.0, false],
	["TackRoom", Vector3(22.9, 0, 31.5), 90.0, true]]


## Perk machines and crates make their collision bodies at runtime, after the bake. Their footprints go into
## the navmesh here (invisible colliders) so zombies path round them instead of into them (T-027).
func build_nav_blocks() -> void:
	var pdata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perks.json"))["perks"]
	for pk: Array in CELLAR_PERKS:
		var fp: Vector3 = MACHINE_FOOTPRINTS.get(str((pdata[str(pk[0])] as Dictionary).get("shape", "cabinet")), Vector3(1.0, 2.0, 0.7))
		if absf(float(pk[2])) == 90.0:
			fp = Vector3(fp.z, fp.y, fp.x)
		var c: Vector3 = pk[1]
		box(geo, "NavBlock_" + str(pk[0]), c - Vector3(fp.x * 0.5, 0, fp.z * 0.5), c + Vector3(fp.x * 0.5, fp.y, fp.z * 0.5), "metal", true, false)
	for cr: Array in CRATES:
		var half: Vector3 = Vector3(0.7, 0, 0.35) if absf(float(cr[2])) != 90.0 else Vector3(0.35, 0, 0.7)
		var p: Vector3 = cr[1]
		box(geo, "NavBlock_Crate", p - half, p + half + Vector3(0, 0.75, 0), "metal", true, false)


func build_cellar() -> void:
	var cy: float = CELLAR_Y
	# stair hall: landing at ground level, then the ramp down (south)
	box(geo, "CellarLanding", Vector3(24.15, -0.5, 10.15), Vector3(28.0, 0.0, 13.0), "floor_wood")
	ramp_z("CellarStairs", 24.3, 27.85, 19.0, 13.0, cy, 0.0)
	wall_x("HallN", 10.0, 24.0, 28.0 + T * 0.5, cy, 3.0, [], "stone")
	wall_z("HallE", 28.0, 10.0, 19.0, cy, 3.0, [], "stone")
	wall_z("HallW", 24.0, 16.0, 19.0, cy, 3.0, [], "stone")
	box(geo, "HallWLow", Vector3(24.0 - T * 0.5, cy, 10.0), Vector3(24.0 + T * 0.5, 0.0, 16.0), "stone")
	box(geo, "HallS", Vector3(24.0 - T * 0.5, CELLAR_TOP, 19.0 - T * 0.5), Vector3(28.0 + T * 0.5, 3.0, 19.0 + T * 0.5), "stone")
	box(geo, "HallRoof", Vector3(24.0, 3.0, 10.0 - T * 0.5), Vector3(28.0 + T * 0.5, 3.2, 19.0), "roof")
	box(geo, "HallUnder", Vector3(24.15, cy - 0.5, 13.0), Vector3(28.0, cy, 19.0), "stone")
	# the cellar
	box(geo, "CellarFloor", Vector3(24.0, cy - 0.5, 19.0), Vector3(36.0, cy, 31.0), "stone")
	box(geo, "CellarRoof", Vector3(24.0 - T * 0.5, CELLAR_TOP, 19.0), Vector3(36.0 + T * 0.5, -0.04, 31.0 + T * 0.5), "floor_wood")
	box(geo, "CellarRoofSnow", Vector3(24.0 - T * 0.5, -0.04, 19.0), Vector3(36.0 + T * 0.5, 0.0, 31.0 + T * 0.5), "snow")
	for bz: float in [21.0, 25.0, 29.0]:   # joists under the boards
		box(geo, "CellarJoist", Vector3(24.0, CELLAR_TOP - 0.25, bz - 0.12), Vector3(36.0, CELLAR_TOP, bz + 0.12), "furniture", false)
	wall_z("CelW", 24.0, 19.0, 31.0, cy, CELLAR_TOP, [], "stone")
	wall_z("CelE", 36.0, 19.0, 31.0, cy, CELLAR_TOP, [], "stone")
	wall_x("CelS", 31.0, 24.0 - T * 0.5, 36.0 + T * 0.5, cy, CELLAR_TOP, [], "stone")
	wall_x("CelN", 19.0, 28.0, 36.0 + T * 0.5, cy, CELLAR_TOP, [], "stone")
	box(geo, "CelNLintel", Vector3(24.0, cy + 2.6, 19.0 - T * 0.5), Vector3(28.0, CELLAR_TOP, 19.0 + T * 0.5), "stone")
	# vault pillars (cover, and something to run a loop around)
	for p: Vector2 in [Vector2(30.0, 23.0), Vector2(30.0, 27.0)]:
		box(geo, "CellarPillar", Vector3(p.x - 0.35, cy, p.y - 0.35), Vector3(p.x + 0.35, CELLAR_TOP, p.y + 0.35), "stone")


func bake_navmesh() -> void:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 42.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
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
	_dress_hearth()
	_dress_bar()
	_dress_taproom()
	_dress_upstairs()
	_dress_stable()
	_dress_exterior()
	_dress_wreck()


func _dress_floors_and_ceilings() -> void:
	Props.block(dress, Vector3(0.15, 0.0, 0.15), Vector3(23.85, 0.012, 15.85), "floorboards")
	Props.block(dress, Vector3(0.15, 0.0, 10.0), Vector3(2.85, 0.012, 15.85), "floorboards")
	Props.block(dress, Vector3(6.15, 0.0, 22.15), Vector3(23.85, 0.012, 33.85), "dirt")
	Props.block(dress, Vector3(18.15, 0.0, 16.0), Vector3(21.85, 0.012, 22.0), "dirt")
	# taproom ceiling beams (north-south) and a summer beam
	for x: float in [5.0, 8.0, 11.0, 14.0, 17.0, 20.0, 23.0]:
		Props.block(dress, Vector3(x - 0.14, TAP_H - 0.28, 0.15), Vector3(x + 0.14, TAP_H, 15.85), "beam")
	Props.block(dress, Vector3(3.0, TAP_H - 0.36, 7.85), Vector3(23.85, TAP_H - 0.06, 8.15), "beam")
	for x: float in [8.0, 14.0, 20.0]:
		Props.block(dress, Vector3(x - 0.15, 0, 0.15), Vector3(x + 0.15, TAP_H, 0.42), "beam")
		Props.block(dress, Vector3(x - 0.15, 0, 15.58), Vector3(x + 0.15, TAP_H, 15.85), "beam")
	# upstairs beams + hall runner
	for x: float in [2.0, 6.0, 10.0, 14.0, 18.0, 22.0]:
		Props.block(dress, Vector3(x - 0.12, UP_TOP - 0.24, 0.15), Vector3(x + 0.12, UP_TOP, 9.85), "beam")
	Props.block(dress, Vector3(1.0, UP_Y, 7.4), Vector3(23.0, UP_Y + 0.012, 8.6), "rug")
	# stable trusses
	for z: float in [24.5, 28.0, 31.5]:
		Props.block(dress, Vector3(6.15, STABLE_H - 0.6, z - 0.15), Vector3(23.85, STABLE_H - 0.3, z + 0.15), "beam")
		for x: float in [6.4, 23.6]:
			Props.block(dress, Vector3(x - 0.15, 0, z - 0.15), Vector3(x + 0.15, STABLE_H - 0.3, z + 0.15), "beam")


## Frames, sills (with snow outside), shutters and curtains for a window opening.
func _window(pos: Vector3, yaw: float, curtains: bool, sill: float = WIN_SILL, top: float = WIN_TOP) -> void:
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
		Props.curtain(g, Vector3(-hw - 0.25, top + 0.05, T * 0.5 + 0.08), 180.0, top - sill + 0.4, "cloth_red")
		Props.curtain(g, Vector3(hw + 0.25, top + 0.05, T * 0.5 + 0.08), 180.0, top - sill + 0.4, "cloth_red")
		Props.block(g, Vector3(-hw - 0.5, top + 0.15, T * 0.5 + 0.06), Vector3(hw + 0.5, top + 0.18, T * 0.5 + 0.1), "iron")


func _door_frame(pos: Vector3, yaw: float, width: float, height: float) -> void:
	var g: Node3D = Props.group(dress, "DoorFrame", pos, yaw)
	for side: float in [1.0, -1.0]:
		var face: float = side * T * 0.5
		Props.block(g, Vector3(-width * 0.5 - 0.14, 0, face), Vector3(-width * 0.5, height + 0.14, face + side * 0.07), "beam")
		Props.block(g, Vector3(width * 0.5, 0, face), Vector3(width * 0.5 + 0.14, height + 0.14, face + side * 0.07), "beam")
		Props.block(g, Vector3(-width * 0.5 - 0.14, height, face), Vector3(width * 0.5 + 0.14, height + 0.18, face + side * 0.08), "beam")


func _dress_windows_and_doors() -> void:
	_window(Vector3(7.0, 0, 0), 0.0, true)
	_window(Vector3(17.0, 0, 0), 0.0, true)
	_window(Vector3(0, 0, 6.0), 90.0, true)
	_window(Vector3(24.0, 0, 8.0), -90.0, true)
	_window(Vector3(4.0, UP_Y, 0), 0.0, true, UP_Y + WIN_SILL - UP_Y, UP_Y + WIN_TOP - UP_Y)
	_window(Vector3(20.0, UP_Y, 0), 0.0, true, WIN_SILL, WIN_TOP)
	_window(Vector3(9.0, 0, 22.0), 0.0, false)
	_window(Vector3(14.0, 0, 22.0), 0.0, false)
	_window(Vector3(12.0, 0, 34.0), 180.0, false)
	_door_frame(Vector3(3.0, 0, 15.1), 90.0, 1.6, DOOR_H)
	_door_frame(Vector3(20.0, 0, 16.0), 0.0, 2.0, DOOR_H)
	_door_frame(Vector3(24.0, 0, 11.5), -90.0, 1.6, DOOR_H)
	_door_frame(Vector3(20.0, 0, 22.0), 0.0, 3.0, 2.6)
	for dx: float in [5.75, 11.75, 20.25]:
		_door_frame(Vector3(dx, UP_Y, 6.0), 0.0, 1.5, 2.2)
	# the great doors at the stable's south end (barred)
	var gd: Node3D = Props.group(dress, "GreatDoors", Vector3(18, 0, 33.82))
	Props.block(gd, Vector3(-2.0, 0, -0.06), Vector3(2.0, 4.2, 0.0), "planks")
	Props.obox(gd, Vector3(0, 2.1, -0.12), Vector3(0.2, 4.6, 0.1), "beam", Vector3(0, 0, 60))
	Props.obox(gd, Vector3(0, 2.1, -0.12), Vector3(0.2, 4.6, 0.1), "beam", Vector3(0, 0, -60))
	Props.block(gd, Vector3(-2.2, 1.6, -0.24), Vector3(2.2, 1.8, -0.12), "iron")


func _dress_stairs() -> void:
	for s: Array in _stair_dressing:
		var x0: float = s[0]
		var x1: float = s[1]
		var z_low: float = s[2]
		var z_high: float = s[3]
		var y_low: float = s[4]
		var y_high: float = s[5]
		var rise: float = y_high - y_low
		var steps: int = int(ceil(rise / 0.22))
		for k: int in steps:
			var t0: float = float(k) / float(steps)
			var t1: float = float(k + 1) / float(steps)
			var za: float = lerpf(z_low, z_high, t0)
			var zb: float = lerpf(z_low, z_high, t1)
			var yb: float = lerpf(y_low, y_high, t1)
			Props.block(dress, Vector3(x0, y_low, minf(za, zb)), Vector3(x1, yb - 0.05, maxf(za, zb)), "beam")
			Props.block(dress, Vector3(x0, yb - 0.05, minf(za, zb) - 0.02), Vector3(x1, yb, maxf(za, zb) + 0.02), "furniture")
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
	Props.bottles(g, Vector3(4.8, 0.5, 3.1), Vector3(4.8, 0.5, 7.9), 22, 11)
	Props.bottles(g, Vector3(4.8, 1.0, 3.1), Vector3(4.8, 1.0, 7.9), 20, 12)
	Props.bottles(g, Vector3(4.8, 1.5, 3.1), Vector3(4.8, 1.5, 7.9), 18, 13)
	Props.bottles(g, Vector3(4.8, 2.0, 5.6), Vector3(4.8, 2.0, 7.9), 6, 14)   # left of the radio
	# a keg, glasses and a ledger on the counter
	Props.cyl(g, Vector3(6.0, 0.4, 3.6), 0.32, 0.8, "planks", Vector3(90, 90, 0))
	Props.cyl(g, Vector3(7.4, 0.35, 3.5), 0.3, 0.7, "planks")
	Props.block(g, Vector3(6.6, 1.1, 8.2), Vector3(7.0, 1.14, 8.5), "paper")
	for x: float in [5.4, 5.6, 7.8, 8.6]:
		Props.cyl(g, Vector3(x, 1.18, 8.35), 0.04, 0.16, "stein")
	Props.wall_lamp(g, Vector3(4.6, 2.5, 4.5), -90.0)


func _dress_taproom() -> void:
	var g: Node3D = Props.group(dress, "Taproom", Vector3.ZERO)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1944
	for p: Vector2 in [Vector2(12.5, 11.5), Vector2(16.5, 11.5), Vector2(20.0, 4.5)]:
		Props.table_visual(g, Vector3(p.x, 0, p.y), 1.2, 1.2)
		for k: int in 4:
			var a: float = TAU * float(k) / 4.0 + 0.4
			var cp: Vector3 = Vector3(p.x + cos(a) * 0.95, 0, p.y + sin(a) * 0.95)
			Props.chair(g, cp, rad_to_deg(atan2(-(cp.x - p.x), -(cp.z - p.y))) + 180.0 + rng.randf_range(-20, 20), rng.randf() < 0.12)
		Props.cyl(g, Vector3(p.x - 0.2, 0.83, p.y + 0.1), 0.045, 0.16, "stein")
		Props.cyl(g, Vector3(p.x + 0.25, 0.8, p.y - 0.2), 0.03, 0.1, "candle")
		Props.block(g, Vector3(p.x + 0.05, 0.751, p.y - 0.05), Vector3(p.x + 0.25, 0.755, p.y + 0.2), "paper", false)
	# benches along the south wall, a rug in front of the hearth, coat rack by the stable door
	Props.bench(g, Vector3(9.0, 0, 15.45), 0.0, 3.0)
	Props.bench(g, Vector3(14.5, 0, 15.45), 0.0, 3.0)
	Props.block(g, Vector3(9.8, 0.012, 1.8), Vector3(14.2, 0.025, 4.8), "rug", false)
	Props.coat_rack(g, Vector3(22.6, 0, 15.3))
	Props.coat_rack(g, Vector3(3.6, 0, 10.6))
	# pictures and lamps
	Props.picture(g, Vector3(3.0, 2.2, 0.16), 180.0, 0.7, 0.5)
	Props.picture(g, Vector3(21.5, 2.3, 0.16), 180.0, 0.9, 0.6)
	Props.picture(g, Vector3(11.0, 2.2, 15.84), 0.0, 0.8, 0.55)
	Props.picture(g, Vector3(23.84, 2.3, 4.0), 90.0, 0.6, 0.8)
	Props.picture(g, Vector3(0.16, 2.4, 2.5), -90.0, 0.5, 0.7)
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


func _dress_upstairs() -> void:
	var g: Node3D = Props.group(dress, "Upstairs", Vector3.ZERO)
	Props.bed(g, Vector3(0.3, UP_Y, 0.4), Vector3(2.2, UP_Y + 0.5, 2.6), "cloth_red")
	Props.bed(g, Vector3(13.6, UP_Y, 0.4), Vector3(15.6, UP_Y + 0.5, 2.6), "cloth_green")
	Props.bed(g, Vector3(21.6, UP_Y, 3.2), Vector3(23.7, UP_Y + 0.5, 5.6), "cloth_red")
	Props.trunk(g, Vector3(10.4, UP_Y, 0.5), Vector3(11.6, UP_Y + 0.5, 1.2))
	Props.washstand(g, Vector3(6.9, UP_Y, 0.45), 180.0)
	Props.washstand(g, Vector3(8.6, UP_Y, 4.5), -90.0)
	Props.wardrobe(g, Vector3(15.5, UP_Y, 4.9), 90.0)
	Props.wardrobe(g, Vector3(1.0, UP_Y, 5.4), 0.0)
	Props.chair(g, Vector3(2.8, UP_Y, 1.2), 140.0, true)
	Props.chair(g, Vector3(18.0, UP_Y, 1.3), 200.0)
	Props.picture(g, Vector3(12.0, UP_Y + 1.7, 0.16), 180.0, 0.5, 0.65)
	Props.picture(g, Vector3(18.0, UP_Y + 1.6, 9.84), 0.0, 0.7, 0.5)
	for p: Vector3 in [Vector3(4.0, UP_Y + 2.2, 3.0), Vector3(12.0, UP_Y + 2.2, 3.0), Vector3(20.0, UP_Y + 2.2, 3.0), Vector3(12.0, UP_Y + 2.2, 8.0)]:
		Props.lantern(g, p, UP_TOP - 0.24)
	Props.lantern(g, Vector3(1.5, 5.7, 13.0), UP_TOP)


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
	Props.block(g, Vector3(21.4, 0, 22.4), Vector3(23.85, 0.7, 25.5), "hay")   # the hay pile (ground spawn)
	for i: int in 4:
		Props.hay_bale(g, Vector3(23.2, 0.45 * (i / 2), 28.0 + (i % 2) * 0.55), 90.0)
	Props.hay_bale(g, Vector3(22.8, 0, 26.6), 75.0)
	# bales stacked on the loft over the collision block
	for xi: int in 3:
		for zi: int in 5:
			Props.hay_bale(g, Vector3(6.9 + xi * 0.95, 3.5, 30.85 + zi * 0.55), 0.0 if (xi + zi) % 2 == 0 else 3.0)
	Props.hay_bale(g, Vector3(7.8, 3.95, 31.4), 8.0)
	Props.hay_bale(g, Vector3(8.6, 3.95, 32.4), -6.0)
	Props.cart(g, Vector3(8.4, 0, 32.4), 90.0)
	Props.block(g, Vector3(6.15, 1.2, 25.5), Vector3(6.25, 1.3, 27.5), "beam")   # tack rail
	Props.block(g, Vector3(6.25, 1.0, 25.9), Vector3(6.6, 1.35, 26.5), "cloth_red")   # saddle blanket
	Props.block(g, Vector3(6.25, 0.9, 26.8), Vector3(6.45, 1.3, 27.2), "furniture")    # bridle/strap
	Props.crate(g, Vector3(22.9, 0, 33.2), 0.6, 15.0)
	# loft edge rail near the stair head
	Props.block(g, Vector3(14.9, 3.5, 22.15), Vector3(15.0, 4.5, 25.5), "beam")
	Props.block(g, Vector3(14.85, 4.4, 22.15), Vector3(15.05, 4.5, 25.5), "beam")
	for lp: Array in [[Vector3(19.0, 4.0, 26.0), STABLE_H - 0.6], [Vector3(19.0, 4.0, 31.5), STABLE_H - 0.6], [Vector3(10.0, 2.3, 28.0), 3.2],
			[Vector3(10.0, 5.6, 28.0), STABLE_H - 0.6], [Vector3(20.0, 2.4, 19.0), 3.0]]:
		Props.lantern(g, lp[0], float(lp[1]))


func _dress_exterior() -> void:
	var g: Node3D = Props.group(dress, "Exterior", Vector3.ZERO)
	# half-timbering on the inn's outer faces (north, west, east)
	for x: float in [0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0]:
		if absf(x - 7.0) < 1.0 or absf(x - 17.0) < 1.0:
			continue
		Props.block(g, Vector3(x - 0.13, 0, -0.27), Vector3(x + 0.13, UP_TOP, -0.15), "beam")
	for y: float in [0.25, TAP_H, UP_TOP - 0.1]:
		Props.block(g, Vector3(-0.27, y - 0.12, -0.27), Vector3(24.27, y + 0.12, -0.15), "beam")
		Props.block(g, Vector3(-0.27, y - 0.12, -0.15), Vector3(-0.15, y + 0.12, 16.15), "beam")
		if y < 1.0:   # the cellar door (z 10.7..12.3) breaks the sill beam
			Props.block(g, Vector3(24.15, y - 0.12, -0.15), Vector3(24.27, y + 0.12, 10.6), "beam")
			Props.block(g, Vector3(24.15, y - 0.12, 12.4), Vector3(24.27, y + 0.12, 16.15), "beam")
		else:
			Props.block(g, Vector3(24.15, y - 0.12, -0.15), Vector3(24.27, y + 0.12, 16.15 if y < 4.0 else 10.15), "beam")
	for i: int in 6:
		var x0: float = 0.2 + i * 4.0
		Props.obox(g, Vector3(x0 + 1.5, UP_Y + 1.5, -0.22), Vector3(0.18, 3.6, 0.08), "beam", Vector3(0, 0, 40 if i % 2 == 0 else -40))
	# pitched roofs with snow (inn, stair tower, stable) and the chimney stack
	_gable(g, Vector3(-0.6, UP_TOP + 0.2, -0.8), Vector3(24.6, UP_TOP + 0.2, 10.8), 3.4)
	_gable(g, Vector3(2.6, TAP_H + 0.3, 9.8), Vector3(24.6, TAP_H + 0.3, 16.6), 1.0)
	_gable(g, Vector3(5.6, STABLE_H + 0.2, 21.6), Vector3(24.6, STABLE_H + 0.2, 34.4), 3.2)
	Props.block(g, Vector3(11.3, UP_TOP, 0.0), Vector3(12.7, 11.4, 1.0), "stone")
	Props.block(g, Vector3(11.2, 11.3, -0.1), Vector3(12.8, 11.5, 1.1), "snow")
	Props.smoke(g, Vector3(12.0, 11.6, 0.5), 0.3, 1.2, 14)
	# porch posts' snow caps and drifts against the walls
	for d: Array in [[Vector3(-1.2, 0, 6), Vector3(2.4, 0.9, 7)], [Vector3(25.4, 0, 3), Vector3(2.0, 0.8, 5)], [Vector3(12, 0, -1.0), Vector3(6, 0.7, 1.8)],
			[Vector3(4, 0, 17.5), Vector3(5, 1.0, 2.2)], [Vector3(25.3, 0, 27), Vector3(2.2, 1.1, 8)], [Vector3(14, 0, 35.4), Vector3(9, 1.0, 2.2)],
			[Vector3(4.6, 0, 28), Vector3(2.4, 1.0, 9)], [Vector3(-3, 0, -6), Vector3(5, 0.6, 4)], [Vector3(32, 0, 7), Vector3(6, 0.8, 5)]]:
		Props.snow_drift(g, d[0], d[1])
	Props.block(g, Vector3(1.5, UP_Y, -2.4), Vector3(6.5, UP_Y + 0.08, -0.15), "snow", false)
	Props.block(g, Vector3(17.5, UP_Y, -2.4), Vector3(22.5, UP_Y + 0.08, -0.15), "snow", false)
	# the crossroads: two trodden tracks, a signpost, fences, dead trees
	Props.block(g, Vector3(-45, 0.0, -9.5), Vector3(70, 0.015, -6.0), "snow_trodden", false)
	Props.block(g, Vector3(-12.5, 0.0, -40), Vector3(-9.0, 0.015, 75), "snow_trodden", false)
	Props.signpost(g, Vector3(-8.2, 0, -10.6), [["KALTENBRUNN  9 km", 90.0], ["WILCZA GÓRA  6 km", 160.0], ["BRESLAU  74 km", -90.0], ["GASTHAUS ZUM KREUZWEG", 20.0]])
	Props.fence(g, Vector3(-20, 0, -13), Vector3(-13.5, 0, -13), 3)
	Props.fence(g, Vector3(-8, 0, -13), Vector3(30, 0, -13), 4)
	Props.fence(g, Vector3(-20, 0, -4), Vector3(-20, 0, 40), 5)
	Props.fence(g, Vector3(-8, 0, 40), Vector3(34, 0, 40), 6)
	Props.fence(g, Vector3(34, 0, 40), Vector3(34, 0, 20), 7)
	var trees: Array = [Vector3(-16, 0, -22), Vector3(-26, 0, 8), Vector3(-15, 0, 30), Vector3(30, 0, -20), Vector3(55, 0, 30),
		Vector3(5, 0, 48), Vector3(-30, 0, -30), Vector3(40, 0, -25), Vector3(-24, 0, 50), Vector3(60, 0, -10)]
	for i: int in trees.size():
		Props.dead_tree(g, trees[i], 100 + i, 6.0 + float(i % 3) * 2.0)
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
		AABB(Vector3(0, 0, 16.6), Vector3(17.6, 14, 5.2))] as Array[AABB])
	snow.set("density", 0.4)
	map_root.add_child(snow)
	var motes: Node3D = Node3D.new()
	motes.set_script(load("res://gravelight/world/snowfall.gd"))
	motes.name = "DustMotes"
	motes.set("areas", [AABB(Vector3(1, 0.3, 1), Vector3(22, 3.0, 14)), AABB(Vector3(7, 0.3, 23), Vector3(16, 6, 10))] as Array[AABB])
	motes.set("motes", true)
	map_root.add_child(motes)


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
			if not (mi.mesh is PrimitiveMesh) or mi.material_override == null:
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

func build_environment() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.4)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.15)
	env.fog_light_energy = 1.0
	env.fog_density = 0.022
	env.fog_sky_affect = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.9)
	env.volumetric_fog_emission = Color(0.01, 0.012, 0.02)
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_anisotropy = 0.45
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78
	env.adjustment_contrast = 1.1
	env.adjustment_brightness = 1.0
	we.environment = env
	map_root.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.5, 0.6, 0.95)
	moon.light_energy = 0.45
	moon.light_volumetric_fog_energy = 0.6
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(28), 0)
	map_root.add_child(moon)
	var warm: Color = Color(1.0, 0.66, 0.36)
	_lamp("Hearthfire", Vector3(12, 0.8, 1.4), Color(1.0, 0.5, 0.2), 4.5, 12.0, true, true)
	_lamp("TapLamp1", Vector3(6.5, 2.45, 11.5), warm, 2.72, 11.0, false, true, 0.08)
	_lamp("TapLamp2", Vector3(17.5, 2.45, 4.0), warm, 2.38, 11.0, false, true, 0.08)
	_lamp("TapLamp3", Vector3(19.5, 2.45, 13.0), warm, 2.38, 10.0, false, true, 0.08)
	_lamp("TapLamp4", Vector3(14.0, 2.45, 8.0), warm, 2.21, 10.0, false, true, 0.08)
	_lamp("BarLamp", Vector3(5.0, 2.4, 4.5), warm, 1.70, 7.0, false, true, 0.1)
	_lamp("StairLamp", Vector3(1.5, 5.55, 13.0), warm, 1.70, 9.0, false, true, 0.08)
	_lamp("Room1Lamp", Vector3(4.0, UP_Y + 2.05, 3.0), warm, 1.70, 8.0, false, true, 0.08)
	_lamp("Room2Lamp", Vector3(12.0, UP_Y + 2.05, 3.0), warm, 1.53, 8.0, false, true, 0.08)
	_lamp("Room3Lamp", Vector3(20.0, UP_Y + 2.05, 3.0), warm, 1.70, 8.0, false, true, 0.08)
	_lamp("HallLamp", Vector3(12.0, UP_Y + 2.05, 8.0), warm, 1.87, 11.0, false, true, 0.08)
	_lamp("PassLamp", Vector3(20.0, 2.25, 19.0), warm, 2.21, 10.0, false, true)
	_lamp("StableLamp1", Vector3(19.0, 3.85, 26.0), warm, 3.82, 14.0, true, true)
	_lamp("StableLamp2", Vector3(19.0, 3.85, 31.5), warm, 3.26, 13.0, false, true)
	_lamp("StableLamp3", Vector3(10.0, 2.15, 28.0), warm, 2.99, 12.0, false, true)
	_lamp("LoftLamp", Vector3(10.0, 5.45, 28.0), warm, 2.29, 11.0, false, true)
	_lamp("WreckFire", Vector3(45, 3.5, 5), Color(1.0, 0.45, 0.15), 8.0, 34.0, true, true)
	_lamp("WreckFire2", Vector3(42.5, 1.6, 6.8), Color(1.0, 0.4, 0.1), 3.0, 14.0, false, true)
	# cold moonlight spilling through the taproom windows (no shadows; aimed through the openings)
	for wp: Array in [[Vector3(7.0, 4.2, -3.5), Vector3(7.0, 0.0, 3.0)], [Vector3(17.0, 4.2, -3.5), Vector3(17.0, 0.0, 3.0)],
			[Vector3(-3.5, 4.2, 6.0), Vector3(3.0, 0.0, 6.0)], [Vector3(27.5, 4.2, 8.0), Vector3(21.0, 0.0, 8.0)]]:
		var sp: SpotLight3D = SpotLight3D.new()
		sp.name = "MoonSpill"
		sp.position = wp[0]
		sp.light_color = Color(0.55, 0.65, 1.0)
		sp.light_energy = 2.2
		sp.light_volumetric_fog_energy = 2.5
		sp.spot_range = 9.0
		sp.spot_angle = 16.0
		sp.spot_attenuation = 1.2
		map_root.add_child(sp)
		sp.look_at_from_position(wp[0], wp[1], Vector3.UP)
	var post: CanvasLayer = CanvasLayer.new()
	post.set_script(load("res://gravelight/ui/postfx.gd"))
	post.name = "PostFx"
	map_root.add_child(post)


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
	# Only the big fires feed the volumetric fog; lanterns light surfaces (much cheaper).
	l.light_volumetric_fog_energy = 1.4 if (name_.begins_with("Hearth") or name_.begins_with("Wreck")) else 0.0
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
	gameplay = Node3D.new()
	gameplay.name = "Gameplay"
	map_root.add_child(gameplay)

	# player spawns (taproom, facing north toward the hearth)
	var i: int = 1
	for p: Vector3 in [Vector3(14, 0, 7), Vector3(16, 0, 7), Vector3(14, 0, 9), Vector3(16, 0, 9)]:
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
	]
	for w: Array in windows:
		var bar: Node3D = _scripted(Node3D.new(), "res://gravelight/world/barricade.gd", str(w[0]), {
			"window_id": StringName(str(w[0])), "zone_id": w[1], "width": 1.6, "sill_height": WIN_SILL, "top_height": WIN_TOP})
		bar.position = w[2]
		bar.rotation.y = deg_to_rad(float(w[3]))
		gameplay.add_child(bar)
		var sp: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_" + str(w[0]), {
			"zone_id": w[1], "window_path": NodePath("../" + str(w[0])), "kind": &"window"}) as Marker3D
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
	hay.position = Vector3(22.6, 0, 24.0)
	gameplay.add_child(hay)

	# doors
	var d1: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Upstairs", {
		"door_id": &"door_upstairs", "opens_zone": &"UPSTAIRS", "cost": 750, "size": Vector3(1.6, DOOR_H, 0.25), "label": "Upstairs"})
	d1.position = Vector3(3.0, 0, 15.1)
	d1.rotation.y = deg_to_rad(90)
	gameplay.add_child(d1)
	var d2: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Stable", {
		"door_id": &"door_stable", "opens_zone": &"STABLE", "cost": 1000, "size": Vector3(2.0, DOOR_H, 0.25), "label": "Stable"})
	d2.position = Vector3(20.0, 0, 16.0)
	gameplay.add_child(d2)

	build_cellar_gameplay()

	# wall-buys: [weapon, position, yaw so local -Z faces the room]. Nudged off the wall past the timber trim.
	var buys: Array = [
		[&"kar98k", Vector3(T * 0.5 + 0.04, 1.5, 8.6), -90.0],
		[&"m1_garand", Vector3(24 - T * 0.5 - 0.04, 1.5, 4.0), 90.0],   # moved from z 12.5 for the cellar door (T-027)
		[&"mp40", Vector3(T * 0.5 + 0.04, UP_Y + 1.5, 3.4), -90.0],
		[&"trench_gun", Vector3(6 + T * 0.5 + 0.01, 1.5, 29.5), -90.0],
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
		[&"UPSTAIRS", Vector3(1.5, 0, 13), Vector3(3, 7, 6)],
		[&"STABLE", Vector3(15, 0, 28), Vector3(18, 7, 12)],
		[&"STABLE", Vector3(20, 0, 19), Vector3(4, 3, 6)],
	]
	var zi: int = 0
	for z: Array in zones:
		var zv: Node3D = _scripted(Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_%s_%d" % [z[0], zi], {"zone_id": z[0], "size": z[2]})
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


## Door 3 (1500) -> the Helvetia cellar: all 8 perk machines, the cellar lever (Map 0's power), a coal chute
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
	var sw: Node3D = _scripted(Node3D.new(), "res://gravelight/world/power_switch.gd", "Kellerschalter", {
		"config_table": "map00", "label": "the cellar lever", "zone_order": PackedStringArray(["CELLAR", "TAPROOM", "UPSTAIRS", "STABLE"])})
	sw.position = Vector3(32.5, cy + 0.3, 19.35)
	sw.rotation.y = deg_to_rad(180)
	gameplay.add_child(sw)
	# lights: one oil lamp at the foot of the stairs always lit; the bulbs over the machines wait for the lever
	_lamp("CellarHallLamp", Vector3(26.0, 2.5, 10.8), Color(1.0, 0.72, 0.45), 0.7, 5.0, false, true)
	_lamp("CellarStairLamp", Vector3(26.0, cy + 2.4, 19.6), Color(1.0, 0.7, 0.4), 0.9, 6.0, false, true)
	for lp: Vector3 in [Vector3(27.0, cy + 2.6, 23.0), Vector3(33.0, cy + 2.6, 23.0), Vector3(30.0, cy + 2.6, 28.5)]:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "CellarBulb"
		l.position = lp
		l.light_color = Color(1.0, 0.85, 0.6)
		l.light_energy = 1.4
		l.omni_range = 7.0
		l.omni_attenuation = 1.4
		l.visible = false
		l.set_meta("zone", &"CELLAR")
		l.set_meta("energy", 1.4)
		l.add_to_group(&"power_lights", true)
		map_root.add_child(l)
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

