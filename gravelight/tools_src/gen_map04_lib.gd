extends SceneTree
## Shared generator base for the four Map 4 "Fernflug" acts (UPDATE 07, docs/MAP4_FERNFLUG.md §14): the greybox
## helpers, the per-zone navmesh bake, static batching, lighting and the generic gameplay placement, lifted from
## gen_map02.gd so every act generator is only its tables and its rooms. An act generator `extends` this script,
## fills the tables in `_initialize()` (zone_bits, adj, zone_boxes, links, windows, buys, doors, ammo_boxes,
## grounds, catwalks, perks, crates, ...), builds its rooms into `geo`, and the base does the rest in `_process`.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map04a.gd
## Frame: +X east, +Z north (the hangar end), y up. Layers as gen_map02: Geometry / Dressing / StaticBatches /
## lights / Gameplay.

const T: float = 0.3
const SILL: float = 0.9
const WTOP: float = 2.2
const DOOR_H: float = 2.4
const SODIUM: Color = Color(1.0, 0.66, 0.36)
const MERCURY: Color = Color(0.72, 0.84, 1.0)
const INCAND: Color = Color(1.0, 0.78, 0.55)
const RED: Color = Color(1.0, 0.22, 0.14)
const VIOLET: Color = Color(0.62, 0.28, 1.0)
const MOONLIGHT: Color = Color(0.55, 0.66, 0.95)
const FIRE: Color = Color(1.0, 0.55, 0.22)
const POWER_GAIN: float = 2.2
const LAMP_GAIN: float = 1.7

# ---- tables the act fills in _initialize (see gen_map02.gd for the row shapes)
var out_path: String = ""
var root_name: String = "Map04"
var map_id: String = ""
var display_name: String = ""
var start_zone: String = ""
var intro_text: String = ""
var json_table: String = ""          # "map04a": the act's data/gravelight/<json_table>.json
var zone_bits: Dictionary = {}
var adj: Dictionary = {}
var zone_boxes: Array = []            # [zone, min, max]
var links: Array = []                 # [from, to, zone]
var windows: Array = []               # [id, zone, pos, inward yaw]
var buys: Array = []                  # [weapon, pos, yaw]
var doors: Array = []                 # [name, door_id, zone, also, link_group, cost, label, pos, yaw, width, needs_power]
var ammo_boxes: Array = []            # [name, pos, yaw]
var grounds: Array = []               # [zone, pos, min_round]
var catwalks: Array = []              # [zone, pos, enabled]  (named Catwalk_<zone>_<i>, kind ground)
var perks: Array = []                 # [perk, pos, yaw]
## T-274 (opt-in; see "perk spots" at the end): the places the act's machines are dealt onto each match
## (perk_layout.json, PerkShuffle / PerkLayout as on Map 0). Rows: [spot id, zone, floor position, yaw, flags].
var perk_spots: Array = []
var crates: Array = []                # [name, pos, yaw, can_start, route]
var player_spawns: Array = []         # [pos, yaw]
var power_switch: Dictionary = {}     # {name, label, pos, yaw, zone_order, config_table}
var crucible: Dictionary = {}         # {pos, yaw, needs_power}
var armorers_bench: Array = []         # [pos, yaw]
var burst_points: Array = []
var traps: Array = []                 # [script, name, props, pos, yaw, lever_pos, lever_yaw, trap_id]
var mat_map: Dictionary = {}
var mat_rules: Array = []
var hide: Array = []
var visual_adjust: Array = []          # T-222: [name pattern, Vector3 lo offset, Vector3 hi offset]: the mesh only
var stage_windows: Array = []
var sky_top: Color = Color(0.006, 0.009, 0.02)
var sky_horizon: Color = Color(0.04, 0.05, 0.075)
var ambient: Color = Color(0.22, 0.27, 0.36)
var fog_color: Color = Color(0.11, 0.13, 0.17)
var moon_rot: Vector3 = Vector3(-42, -150, 0)
var extra_root_nodes: Array = []      # Node3Ds the act adds to the root after the bake (kept out of batching)

var map_root: Node3D
var geo: Node3D
var dress: Node3D
var gameplay: Node3D
var _count: int = 0
var _frames: int = 0
var _closets: Array = []
var _stairs: Array = []
var _glow: Dictionary = {}
var _power: Array = []
var _static_lights: Array = []
var _spots: Array = []
var _fogs: Array = []


func _initialize() -> void:
	setup_tables()
	map_root = Node3D.new()
	map_root.name = root_name
	get_root().add_child(map_root)
	geo = Node3D.new()
	geo.name = "Geometry"
	map_root.add_child(geo)
	dress = Node3D.new()
	dress.name = "Dressing"
	map_root.add_child(dress)
	build_geometry()
	build_closets()
	for ab: Array in ammo_boxes:
		var ah: Vector3 = Vector3(0.52, 0, 0.3) if absf(float(ab[2])) != 90.0 else Vector3(0.3, 0, 0.52)
		box(geo, "NavBlock_Ammo_" + str(ab[0]), (ab[1] as Vector3) - ah, (ab[1] as Vector3) + ah + Vector3(0, 0.62, 0), "metal")
	if perk_spots.is_empty():
		for p: Array in perks:
			var pp: Vector3 = p[1]
			box(geo, "NavBlock_Perk_" + str(p[0]), pp + Vector3(-0.7, 0, -0.5), pp + Vector3(0.7, 2.0, 0.5), "metal")
	else:
		_perk_spot_blocks()
	# T-141: the savings bank's counter, teller and safe (data/gravelight/bank.json "branches", nav_block): the navmesh goes round
	var bank_rows: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/bank.json")) as Dictionary).get("branches", {})
	for bk: Variant in bank_rows.keys():
		if map_id.begins_with(str(bk)) and (bank_rows[bk] as Dictionary).has("nav_block"):
			var nb: Array = bank_rows[bk]["nav_block"]
			box(geo, "NavBlock_Bank", Vector3(float(nb[0][0]), float(nb[0][1]), float(nb[0][2])), Vector3(float(nb[1][0]), float(nb[1][1]), float(nb[1][2])), "metal")
	if not armorers_bench.is_empty():
		var bp: Vector3 = armorers_bench[0]
		box(geo, "NavBlock_ArmorersBench", bp + Vector3(-0.75, 0, 0), bp + Vector3(0.75, 0.9, 0.72), "metal")
	# T-175: the Crucible's footprint (its runtime body, 2.0 x 1.6, which the bake never saw: bots planned through the
	# machine) and its bay (`crucible.bay`, a floor rectangle behind it that CrucibleRoom dresses) go round the navmesh.
	# 1.6 m high, under agent_height: Recast does not fill a closed box, so a taller one leaves a walkable island under
	# its lid (gen_map00's NAV_SOLID_H note, T-051)
	if not crucible.is_empty():
		var cp: Vector3 = crucible["pos"]
		var ch: Vector3 = Vector3(0.8, 0, 1.0) if absf(absf(float(crucible.get("yaw", 0.0))) - 90.0) < 1.0 else Vector3(1.0, 0, 0.8)
		box(geo, "NavBlock_Crucible", cp - ch, cp + ch + Vector3(0, 1.6, 0), "metal")
		if crucible.has("bay"):
			var b0: Vector3 = (crucible["bay"] as Array)[0]
			var b1: Vector3 = (crucible["bay"] as Array)[1]
			box(geo, "NavBlock_CrucibleBay", b0, Vector3(b1.x, b0.y + 1.6, b1.z), "metal")


## Override: fill the tables.
func setup_tables() -> void:
	pass


## Override: the rooms (colliders into `geo`, closets via closet()).
func build_geometry() -> void:
	pass


## Override: non-colliding art into `dress`, lights via power()/lamp()/shaft()/fog().
func build_dressing() -> void:
	pass


## Override: act-specific gameplay nodes (after the generic ones).
func build_gameplay_extra() -> void:
	pass


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	bake_regions()
	for n0: Node in _bake_only:   # T-274: colliders that only shape the navmesh (the perk spots' footprints)
		n0.get_parent().remove_child(n0)
		n0.free()
	_bake_only.clear()
	get_root().remove_child(map_root)
	build_dressing()
	var merged: int = merge_static_meshes()
	print("merged %d static meshes into batches" % merged)
	build_lights()
	build_gameplay()
	build_gameplay_extra()
	if not perk_spots.is_empty():
		_spot_keep_build()
		if OS.get_environment("GL_PERK_SURVEY") != "":
			_survey_perk_spots()
			map_root.free()
			return true
		if _audit_perk_spots() > 0 and OS.get_environment("GL_PERK_FORCE") == "":
			push_error("gen_map04: a perk spot is blocked; the scene was NOT saved")
			map_root.free()
			return true
	for n: Node in extra_root_nodes:
		map_root.add_child(n)
	_prune(dress)
	_prune(geo)
	_own(map_root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(map_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
		err = ResourceSaver.save(packed, out_path)
	print("Saved %s (%d boxes) err=%d" % [out_path, _count, err])
	map_root.free()
	return true


# ================================================================== helpers (gen_map02 idiom)

func _mk(n: String, key: String) -> String:
	for r: Array in mat_rules:
		if n.match(str(r[0])):
			return str(r[1])
	return str(mat_map.get(key, key))


## T-222 (opt-in table `visual_adjust`, empty by default: only the acts that fill it change): [lo offset, hi offset]
## for a box whose name matches a pattern (first match), or [] for none.
func _visual_adjust(n: String) -> Array:
	for r: Array in visual_adjust:
		if n.match(str(r[0])):
			return [r[1], r[2]]
	return []


func _hidden(n: String) -> bool:
	for p: String in hide:
		if n.match(p):
			return true
	return false


## Axis-aligned box from two corners. collide = a static collider on the "world" layer (navmesh source).
func box(parent: Node3D, n: String, a: Vector3, b: Vector3, mat_key: String, collide: bool = true) -> Node3D:
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var size: Vector3 = hi - lo
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return null
	_count += 1
	var mi: MeshInstance3D = null
	if not _hidden(n):
		mi = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = size
		mi.material_override = Mats.get_mat(_mk(n, mat_key))
		var va: Array = _visual_adjust(n)
		if not va.is_empty():
			# T-222: the visual box differs from the collider (two walls of different rooms built on the same line
			# z-fought on both faces): only the mesh moves; the collider and the navmesh keep the table's box
			var vlo: Vector3 = lo + (va[0] as Vector3)
			var vhi: Vector3 = hi + (va[1] as Vector3)
			mi.scale = (vhi - vlo).max(Vector3(0.002, 0.002, 0.002))
			mi.position = (vlo + vhi) * 0.5 - (lo + hi) * 0.5
	if not collide:
		if mi == null:
			return null
		mi.name = n
		mi.position += (lo + hi) * 0.5
		parent.add_child(mi)
		return mi
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.position = (lo + hi) * 0.5
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


## Wall along X at depth z from x0..x1, y0..y1. openings: [[xa, xb, ya, yb], ...] (absolute y).
func wall_x(n: String, z: float, x0: float, x1: float, y0: float, y1: float, openings: Array, mk: String) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = x0
	var i: int = 0
	for o: Array in openings:
		box(geo, "%s_%d" % [n, i], Vector3(cur, y0, z - T * 0.5), Vector3(float(o[0]), y1, z + T * 0.5), mk)
		box(geo, "%s_%db" % [n, i], Vector3(float(o[0]), y0, z - T * 0.5), Vector3(float(o[1]), float(o[2]), z + T * 0.5), mk)
		box(geo, "%s_%dt" % [n, i], Vector3(float(o[0]), float(o[3]), z - T * 0.5), Vector3(float(o[1]), y1, z + T * 0.5), mk)
		cur = float(o[1])
		i += 1
	box(geo, n + "_end", Vector3(cur, y0, z - T * 0.5), Vector3(x1, y1, z + T * 0.5), mk)


func wall_z(n: String, x: float, z0: float, z1: float, y0: float, y1: float, openings: Array, mk: String) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = z0
	var i: int = 0
	for o: Array in openings:
		box(geo, "%s_%d" % [n, i], Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, float(o[0])), mk)
		box(geo, "%s_%db" % [n, i], Vector3(x - T * 0.5, y0, float(o[0])), Vector3(x + T * 0.5, float(o[2]), float(o[1])), mk)
		box(geo, "%s_%dt" % [n, i], Vector3(x - T * 0.5, float(o[3]), float(o[0])), Vector3(x + T * 0.5, y1, float(o[1])), mk)
		cur = float(o[1])
		i += 1
	box(geo, n + "_end", Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, z1), mk)


func win(c: float, y: float) -> Array:
	return [c - 0.8, c + 0.8, y + SILL, y + WTOP]


func door(c: float, y: float, w: float = 2.0) -> Array:
	return [c - w * 0.5, c + w * 0.5, y, y + DOOR_H]


func gap(c: float, y: float, w: float, h: float) -> Array:
	return [c - w * 0.5, c + w * 0.5, y, y + h]


## Ramp along Z between two heights (top surface follows the line between the endpoints).
func ramp_z(n: String, x0: float, x1: float, z_low: float, z_high: float, y_low: float, y_high: float,
		treads: String = "", risers: String = "") -> void:
	var run: float = absf(z_high - z_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var dir: float = signf(z_high - z_low)
	var basis: Basis = Basis(Vector3.RIGHT, -atan2(rise, run) * dir)
	var mid: Vector3 = Vector3((x0 + x1) * 0.5, (y_low + y_high) * 0.5, (z_low + z_high) * 0.5)
	_ramp_body(n, basis, mid, Vector3(absf(x1 - x0), 0.2, length))
	if treads != "":
		_stairs.append(["z", x0, x1, z_low, z_high, y_low, y_high, treads, risers])


## Ramp along X between two heights.
func ramp_x(n: String, z0: float, z1: float, x_low: float, x_high: float, y_low: float, y_high: float,
		treads: String = "", risers: String = "") -> void:
	var run: float = absf(x_high - x_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var dir: float = signf(x_high - x_low)
	var basis: Basis = Basis(Vector3.BACK, atan2(rise, run) * dir)
	var mid: Vector3 = Vector3((x_low + x_high) * 0.5, (y_low + y_high) * 0.5, (z0 + z1) * 0.5)
	_ramp_body(n, basis, mid, Vector3(length, 0.2, absf(z1 - z0)))
	if treads != "":
		_stairs.append(["x", z0, z1, x_low, x_high, y_low, y_high, treads, risers])


func _ramp_body(n: String, basis: Basis, mid: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.collision_layer = 1
	body.transform = Transform3D(basis, mid - (basis * Vector3.UP) * 0.1)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if not _hidden(n):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = size
		mi.material_override = Mats.get_mat(_mk(n, "stairs"))
		body.add_child(mi)
	geo.add_child(body)
	_count += 1


## A closet behind a window so window zombies have floor to stand on (built last, in build_closets).
func closet(window_pos: Vector3, yaw_deg: float) -> void:
	_closets.append([window_pos, yaw_deg])


func build_closets() -> void:
	for c: Array in _closets:
		var p: Vector3 = c[0]
		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(c[1])))
		var out_dir: Vector3 = basis * Vector3(0, 0, -1)
		var side: Vector3 = basis * Vector3(1, 0, 0)
		var center: Vector3 = p + out_dir * 1.5
		var half_side: Vector3 = side.abs() * 1.4
		var half_out: Vector3 = out_dir.abs() * 1.4
		var lo: Vector3 = center - half_side - half_out
		var hi: Vector3 = center + half_side + half_out
		box(geo, "ClosetFloor", Vector3(lo.x, p.y - 0.5, lo.z), Vector3(hi.x, p.y, hi.z), "rock")
		box(geo, "ClosetRoof", Vector3(lo.x, p.y + 3.0, lo.z), Vector3(hi.x, p.y + 3.3, hi.z), "rock")
		var back: Vector3 = p + out_dir * 2.9
		box(geo, "ClosetBack", back - half_side - out_dir.abs() * 0.15 + Vector3(0, p.y - back.y, 0),
			back + half_side + out_dir.abs() * 0.15 + Vector3(0, 3.0, 0), "rock")
		for s: float in [-1.0, 1.0]:
			var sp: Vector3 = center + side * 1.4 * s
			box(geo, "ClosetSide", sp - half_out - side.abs() * 0.15 + Vector3(0, p.y - sp.y, 0),
				sp + half_out + side.abs() * 0.15 + Vector3(0, 3.0, 0), "rock")


## The window's closet as a zone box [zone, lo, hi] (an own nav island, gen_map02's pattern).
func closet_box(zone: String, window_pos: Vector3, yaw_deg: float) -> Array:
	var p: Vector3 = window_pos
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var out_dir: Vector3 = basis * Vector3(0, 0, -1)
	var side: Vector3 = basis * Vector3(1, 0, 0)
	var center: Vector3 = p + out_dir * 1.5
	var half_side: Vector3 = side.abs() * 1.3
	var half_out: Vector3 = out_dir.abs() * 1.3
	var lo: Vector3 = center - half_side - half_out
	var hi: Vector3 = center + half_side + half_out
	# the box stops 0.05 m short of the wall line so it never overlaps the room's box
	var wall_lo: Vector3 = p - out_dir * 0.05
	if out_dir.x > 0.5:
		lo.x = wall_lo.x + 0.1
	elif out_dir.x < -0.5:
		hi.x = wall_lo.x - 0.1
	elif out_dir.z > 0.5:
		lo.z = wall_lo.z + 0.1
	else:
		hi.z = wall_lo.z - 0.1
	return [zone, Vector3(lo.x, p.y - 0.5, lo.z), Vector3(hi.x, p.y + 3.3, hi.z)]


## A hidden railing collider from a to b, h high.
func rail(n: String, a: Vector3, b: Vector3, h: float = 1.05) -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x) - 0.05, a.y, minf(a.z, b.z) - 0.05)
	var hi: Vector3 = Vector3(maxf(a.x, b.x) + 0.05, a.y + h, maxf(a.z, b.z) + 0.05)
	box(geo, n, lo, hi, "rail")


func _own(n: Node) -> void:
	for c: Node in n.get_children():
		if c.owner == null:
			c.owner = map_root
		_own(c)


func B(a: Vector3, b: Vector3, key: String, shadows: bool = true) -> MeshInstance3D:
	return Props.block(dress, a, b, key, shadows)


func OB(c: Vector3, size: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.obox(dress, c, size, key, rot)


func CYL(c: Vector3, r: float, h: float, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.cyl(dress, c, r, h, key, rot)


func _noshadow(mi: GeometryInstance3D) -> void:
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func label(text: String, pos: Vector3, yaw: float, size: int = 40, color: Color = Color(0.85, 0.82, 0.72, 0.85), parent: Node3D = null) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation.y = deg_to_rad(yaw)
	SurfaceText.apply(l)   # T-247: the surface look (period face, lit, toned down)
	(parent if parent != null else dress).add_child(l)


# ================================================================== navigation

func bake_regions() -> void:
	var nav_holder: Node3D = Node3D.new()
	nav_holder.name = "Navigation"
	map_root.add_child(nav_holder)
	var base: NavigationMesh = _navmesh()
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(base, src, geo)
	var i: int = 0
	for zb: Array in zone_boxes:
		var nm: NavigationMesh = _navmesh()
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		nm.filter_baking_aabb = AABB(lo, hi - lo)
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		var r: NavigationRegion3D = NavigationRegion3D.new()
		r.name = "Nav_%s_%d" % [zb[0], i]
		r.navigation_mesh = nm
		r.navigation_layers = 1 << (int(zone_bits[zb[0]]) - 1)
		nav_holder.add_child(r)
		print("  %-14s box %d: %d polys" % [zb[0], i, nm.get_polygon_count()])
		i += 1
	var li: int = 0
	for l: Array in links:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = "Link_%d_%s" % [li, l[2]]
		link.start_position = l[0]
		link.end_position = l[1]
		link.bidirectional = true
		link.navigation_layers = 1 << (int(zone_bits[l[2]]) - 1)
		nav_holder.add_child(link)
		li += 1


func _navmesh() -> NavigationMesh:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 42.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	return nm


# ================================================================== lighting fixtures

func G(zone: String) -> Node3D:
	if not _glow.has(zone):
		var h: Node3D = Node3D.new()
		h.name = "PowerGlow_" + zone
		h.set_meta("keep", true)
		dress.add_child(h)
		_glow[zone] = h
	return _glow[zone]


func power(zone: String, pos: Vector3, range_: float, energy: float, color: Color = SODIUM, shadow: bool = false,
		spot: Dictionary = {}) -> void:
	_power.append({"zone": zone, "pos": pos, "range": range_, "energy": energy, "color": color, "shadow": shadow, "spot": spot})


func lamp(pos: Vector3, color: Color, energy: float, range_: float, flicker: float = 0.0, fog: float = 0.0, shadow: bool = false,
		speed: float = 9.0) -> void:
	_static_lights.append({"pos": pos, "color": color, "energy": energy, "range": range_, "flicker": flicker, "fog": fog,
		"shadow": shadow, "speed": speed})


func shaft(n: String, pos: Vector3, aim: Vector3, color: Color, energy: float, range_: float, angle: float,
		fog: float = 1.5, shadow: bool = true) -> void:
	_spots.append({"name": n, "pos": pos, "aim": aim, "color": color, "energy": energy, "range": range_, "angle": angle,
		"fog": fog, "shadow": shadow})


func moon_window(id: String, energy: float = 1.0) -> void:
	for w: Array in windows:
		if str(w[0]) != id:
			continue
		var p: Vector3 = w[2]
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		shaft("MoonShaft_" + id, p - inward * 2.5 + Vector3(0, 2.75, 0), p + inward * 3.6, MOONLIGHT, 10.0 * energy, 14.0, 28.0, 3.0)


func fog(n: String, c: Vector3, size: Vector3, density: float, albedo: Color, emission: Color = Color(0, 0, 0)) -> void:
	_fogs.append({"name": n, "c": c, "size": size, "density": density, "albedo": albedo, "emission": emission})


func brazier(p: Vector3) -> void:
	Props.cyl(dress, p + Vector3(0, 0.42, 0), 0.3, 0.84, "rust")
	for h: float in [0.25, 0.6]:
		Props.cyl(dress, p + Vector3(0, h, 0), 0.31, 0.03, "iron")
	_noshadow(Props.cyl(dress, p + Vector3(0, 0.8, 0), 0.27, 0.06, "ember"))
	Props.flames(dress, p + Vector3(0, 0.84, 0), 0.45, 0.7, 26)
	Props.embers(dress, p + Vector3(0, 1.0, 0), 0.2, 8)
	lamp(p + Vector3(0, 1.3, 0), FIRE, 1.4, 9.0, 0.2, 0.6)


func pendant(zone: String, p: Vector3, ceil_y: float, shade: String = "enamel_green", s: float = 1.0, glow_key: String = "bulb_warm") -> void:
	var g: Node3D = G(zone)
	Props.cable(dress, Vector3(p.x, ceil_y, p.z), Vector3(p.x, p.y + 0.35 * s, p.z), 0.0, 0.015, 2, "iron")
	Props.cone(dress, p + Vector3(0, 0.22 * s, 0), 0.36 * s, 0.28 * s, shade)
	_noshadow(Props.ball(g, p, Vector3(0.1, 0.12, 0.1) * s, glow_key))
	power(zone, p + Vector3(0, -0.1, 0), 10.0 * s, 1.0, INCAND)


# ================================================================== batching

func merge_static_meshes() -> int:
	if not perk_spots.is_empty() and not _spot_grid_done:
		_spot_grid_build()   # T-274: what is built and drawn, before the batching folds the drawing away
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for holder: Node in [geo, dress]:
		for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or _kept(mi):
				continue
			var xf: Transform3D = _xform_to_root(mi)
			var c: Vector3 = xf.origin
			var cell: Vector3i = Vector3i(floori(c.x / 22.0), floori((c.y + 7.0) / 9.0), floori(c.z / 22.0))
			if absf(c.x) > 140.0 or absf(c.z - 100.0) > 160.0:
				cell = Vector3i(9999, 0, 0)
			var key: String = "%d|%d|%s" % [mi.material_override.get_instance_id(), mi.cast_shadow, cell]
			if not groups.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st}
			(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
			victims.append(mi)
	var batch_root: Node3D = Node3D.new()
	batch_root.name = "StaticBatches"
	map_root.add_child(batch_root)
	var i: int = 0
	for key: String in groups.keys():
		var g: Dictionary = groups[key]
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Batch_%d" % i
		out.mesh = _commit(g["st"])
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		batch_root.add_child(out)
		i += 1
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	print("  %d batches" % i)
	return victims.size()


func _commit(st: SurfaceTool) -> ArrayMesh:
	var arrays: Array = st.commit_to_arrays()
	arrays[Mesh.ARRAY_TEX_UV] = null
	var m: ArrayMesh = ArrayMesh.new()
	var flags: int = Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES if arrays[Mesh.ARRAY_TANGENT] != null else 0
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return m


func _kept(n: Node) -> bool:
	var p: Node = n
	while p != null and p != map_root:
		if p.has_meta("keep"):
			return true
		p = p.get_parent()
	return false


func _xform_to_root(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != map_root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _prune(n: Node) -> void:
	for c: Node in n.get_children():
		_prune(c)
		if c.get_class() == "Node3D" and c.get_script() == null and c.get_child_count() == 0 and not c.has_meta("keep"):
			n.remove_child(c)
			c.free()


# ================================================================== lighting

func build_lights() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var psm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	psm.sky_top_color = sky_top
	psm.sky_horizon_color = sky_horizon
	psm.ground_bottom_color = Color(0.008, 0.01, 0.015)
	psm.ground_horizon_color = sky_horizon
	psm.sun_angle_max = 4.0
	psm.sun_curve = 0.05
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 2.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_energy = 2.8
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.2
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = 0.009
	env.fog_sky_affect = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.88)
	env.volumetric_fog_emission = Color(0.015, 0.019, 0.028)
	env.volumetric_fog_length = 64.0
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_ambient_inject = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	env.adjustment_contrast = 1.1
	we.environment = env
	map_root.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.set_script(load("res://gravelight/maps/map01_kaltenbrunn/moon_switch.gd"))
	moon.name = "Moon"
	moon.set("below_y", -1.0)
	moon.light_color = Color(0.5, 0.6, 0.9)
	moon.light_energy = 0.75
	moon.light_volumetric_fog_energy = 1.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(moon_rot.x), deg_to_rad(moon_rot.y), deg_to_rad(moon_rot.z))
	map_root.add_child(moon)
	var first: Dictionary = {}
	var i: int = 0
	for e: Dictionary in _power:
		var l: OmniLight3D = OmniLight3D.new()
		var zone: String = str(e["zone"])
		l.name = "PowerLight_%s_%d" % [zone, i]
		l.position = e["pos"]
		l.omni_range = float(e["range"])
		l.omni_attenuation = 1.0
		l.light_color = e["color"]
		l.light_energy = 0.0
		l.light_volumetric_fog_energy = 0.0
		l.shadow_enabled = bool(e["shadow"])
		l.set_meta("zone", StringName(zone))
		l.set_meta("energy", float(e["energy"]) * POWER_GAIN)
		l.add_to_group(&"power_lights", true)
		map_root.add_child(l)
		var sp: Dictionary = e["spot"]
		if not sp.is_empty():
			var s: SpotLight3D = SpotLight3D.new()
			s.name = "Beam"
			var dir: Vector3 = sp["dir"]
			var up: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
			s.transform = Transform3D(Basis.looking_at(dir, up), Vector3.ZERO)
			s.light_color = sp.get("color", MERCURY)
			s.light_energy = float(sp["energy"]) * 1.8
			s.spot_range = float(sp["range"])
			s.spot_angle = float(sp["angle"])
			s.spot_attenuation = 0.6
			s.light_volumetric_fog_energy = 0.35
			s.shadow_enabled = false
			l.add_child(s)
		if not first.has(zone):
			first[zone] = l
		i += 1
	for zone2: String in _glow.keys():
		var holder: Node3D = _glow[zone2]
		var host: OmniLight3D = first.get(zone2) as OmniLight3D
		if host == null:
			push_warning("gen_map04: no power light for glow zone %s" % zone2)
			continue
		var groups: Dictionary = {}
		var victims: Array[MeshInstance3D] = []
		for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var k: String = "%d" % mi.material_override.get_instance_id()
			if not groups.has(k):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[k] = {"mat": mi.material_override, "st": st}
			(groups[k]["st"] as SurfaceTool).append_from(mi.mesh, 0, _xform_to_root(mi))
			victims.append(mi)
		var j: int = 0
		for k2: String in groups.keys():
			var out: MeshInstance3D = MeshInstance3D.new()
			out.name = "Glow_%d" % j
			out.mesh = _commit(groups[k2]["st"])
			out.material_override = groups[k2]["mat"]
			out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			out.transform = host.transform.affine_inverse()
			host.add_child(out)
			j += 1
		holder.get_parent().remove_child(holder)
		holder.free()
	var si: int = 0
	for e2: Dictionary in _static_lights:
		var l2: OmniLight3D = OmniLight3D.new()
		var en: float = float(e2["energy"]) * LAMP_GAIN
		if float(e2["flicker"]) > 0.0:
			l2.set_script(load("res://gravelight/world/flicker_light.gd"))
			l2.set("base_energy", en)
			l2.set("amount", float(e2["flicker"]))
			l2.set("speed", float(e2["speed"]))
		l2.name = "Lamp_%d" % si
		l2.position = e2["pos"]
		l2.light_color = e2["color"]
		l2.light_energy = en
		l2.omni_range = float(e2["range"]) * 1.25
		l2.omni_attenuation = 1.1
		l2.light_volumetric_fog_energy = float(e2["fog"])
		l2.shadow_enabled = bool(e2["shadow"])
		map_root.add_child(l2)
		si += 1
	var names: Dictionary = {}
	for e3: Dictionary in _spots:
		var s3: SpotLight3D = SpotLight3D.new()
		var n3: String = str(e3["name"])
		names[n3] = int(names.get(n3, -1)) + 1
		s3.name = n3 if int(names[n3]) == 0 else "%s_%d" % [n3, int(names[n3])]
		var dir3: Vector3 = ((e3["aim"] as Vector3) - (e3["pos"] as Vector3)).normalized()
		s3.transform = Transform3D(Basis.looking_at(dir3, Vector3.UP if absf(dir3.y) < 0.95 else Vector3.FORWARD), e3["pos"])
		s3.light_color = e3["color"]
		s3.light_energy = float(e3["energy"])
		s3.spot_range = float(e3["range"])
		s3.spot_angle = float(e3["angle"])
		s3.spot_attenuation = 0.8
		s3.spot_angle_attenuation = 1.6
		s3.light_volumetric_fog_energy = float(e3["fog"])
		s3.shadow_enabled = bool(e3["shadow"])
		s3.shadow_blur = 1.5
		map_root.add_child(s3)
	for f: Dictionary in _fogs:
		var fv: FogVolume = FogVolume.new()
		fv.name = str(f["name"])
		fv.position = f["c"]
		fv.size = f["size"]
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		var fm: FogMaterial = FogMaterial.new()
		fm.density = float(f["density"])
		fm.albedo = f["albedo"]
		fm.emission = f["emission"]
		fm.edge_fade = 0.3
		fv.material = fm
		map_root.add_child(fv)
	var post: CanvasLayer = CanvasLayer.new()
	post.set_script(load("res://gravelight/ui/postfx.gd"))
	post.name = "PostFx"
	map_root.add_child(post)


# ================================================================== gameplay

func _node(script: String, n: String, props: Dictionary, pos: Vector3, yaw: float = 0.0, marker: bool = false) -> Node3D:
	var node: Node3D = Marker3D.new() if marker else Node3D.new()
	if not ResourceLoader.exists(script):
		push_warning("gen_map04: %s not found; placing a plain marker for %s" % [script, n])
		node.name = n
		node.position = pos
		node.rotation.y = deg_to_rad(yaw)
		gameplay.add_child(node)
		return node
	node.set_script(load(script))
	node.name = n
	for k: String in props.keys():
		node.set(k, props[k])
	node.position = pos
	node.rotation.y = deg_to_rad(yaw)
	gameplay.add_child(node)
	return node


func build_gameplay() -> void:
	map_root.set_script(load("res://gravelight/maps/map_root.gd"))
	map_root.set("map_id", StringName(map_id))
	map_root.set("display_name", display_name)
	map_root.set("start_zone", StringName(start_zone))
	map_root.set("intro_text", intro_text)
	map_root.set("quest_files", PackedStringArray([]))
	var bits: Dictionary = {}
	for k: String in zone_bits.keys():
		bits[StringName(k)] = zone_bits[k]
	map_root.set("nav_zone_bits", bits)
	var adj2: Dictionary = {}
	for k: String in adj.keys():
		adj2[StringName(k)] = adj[k]
	map_root.set("zone_adjacency", adj2)
	gameplay = Node3D.new()
	gameplay.name = "Gameplay"
	map_root.add_child(gameplay)

	var i: int = 1
	for sp: Array in player_spawns:
		_node("res://gravelight/maps/player_spawn.gd", "PlayerSpawn%d" % i, {}, sp[0], float(sp[1]), true)
		i += 1
	var zi: int = 0
	for zb: Array in zone_boxes:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		_node("res://gravelight/world/zone_volume.gd", "Zone_%s_%d" % [zb[0], zi], {"zone_id": StringName(zb[0]), "size": hi - lo},
			Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5))
		zi += 1
	for w: Array in windows:
		var wp: Vector3 = w[2]
		var bar: Node3D = _node("res://gravelight/world/barricade.gd", str(w[0]), {"window_id": StringName(str(w[0])), "zone_id": StringName(str(w[1])),
			"width": 1.6, "sill_height": SILL, "top_height": WTOP}, wp, float(w[3]))
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		var spawn_pos: Vector3 = wp - inward * 1.7
		_node("res://gravelight/enemies/zombie_spawn.gd", "Spawn_" + str(w[0]), {"zone_id": StringName(str(w[1])),
			"window_path": NodePath("../" + str(w[0])), "kind": &"window"}, spawn_pos, 0.0, true)
		bar.name = str(w[0])
	var counts: Dictionary = {}
	for g: Array in grounds:
		var zn: String = str(g[0])
		var gi: int = int(counts.get(zn, 0))
		counts[zn] = gi + 1
		_node("res://gravelight/enemies/zombie_spawn.gd", "Ground_%s_%d" % [zn, gi], {"zone_id": StringName(zn), "kind": &"ground",
			"min_round": int(g[2])}, g[1], 0.0, true)
	var ccounts: Dictionary = {}
	for c: Array in catwalks:
		var zn2: String = str(c[0])
		var ci2: int = int(ccounts.get(zn2, 0))
		ccounts[zn2] = ci2 + 1
		_node("res://gravelight/enemies/zombie_spawn.gd", "Catwalk_%s_%d" % [zn2, ci2], {"zone_id": StringName(zn2), "kind": &"ground",
			"min_round": 1, "enabled": bool(c[2])}, c[1], 0.0, true)
	for d: Array in doors:
		_node("res://gravelight/world/door.gd", str(d[0]), {"door_id": StringName(d[1]), "opens_zone": StringName(d[2]),
			"also_opens": PackedStringArray(d[3]), "link_group": StringName(d[4]), "cost": int(d[5]), "label": d[6],
			"size": Vector3(float(d[9]), DOOR_H, 0.25), "requires_power": d[10]}, d[7], float(d[8]))
	for b: Array in buys:
		_node("res://gravelight/world/wall_buy.gd", "WallBuy_" + str(b[0]), {"weapon_id": StringName(b[0])}, b[1], float(b[2]))
	if perk_spots.is_empty():
		for p: Array in perks:
			_node("res://gravelight/world/perk_machine.gd", "Perk_" + str(p[0]), {"perk_id": StringName(p[0])}, p[1], float(p[2]))
	else:
		_build_perk_spots()
	var ci: int = 0
	for c2: Array in crates:
		_node("res://gravelight/world/mystery_crate.gd", "Crate_" + str(c2[0]), {"spot_index": ci, "can_start": c2[3], "spot_name": c2[0],
			"drummer_route": PackedVector3Array(c2[4])}, c2[1], float(c2[2]))
		ci += 1
	if not power_switch.is_empty():
		var ps: Dictionary = power_switch
		_node("res://gravelight/world/power_switch.gd", str(ps.get("name", "PowerSwitch")), {"config_table": str(ps.get("config_table", json_table)),
			"label": str(ps.get("label", "the power")), "zone_order": PackedStringArray(ps.get("zone_order", []))}, ps["pos"], float(ps.get("yaw", 0.0)))
	if not crucible.is_empty():
		_node("res://gravelight/world/crucible.gd", "Crucible", {"needs_power": bool(crucible.get("needs_power", true))}, crucible["pos"], float(crucible.get("yaw", 0.0)))
	for ab2: Array in ammo_boxes:
		_node("res://gravelight/world/ammo_box.gd", "AmmoBox_" + str(ab2[0]), {"box_name": str(ab2[0]).to_snake_case()}, ab2[1], float(ab2[2]))
	if not armorers_bench.is_empty():
		_node("res://gravelight/world/armorers_bench.gd", "ArmorersBench", {}, armorers_bench[0], float(armorers_bench[1]))
	for t: Array in traps:
		var trap: Node3D = _node(str(t[0]), str(t[1]), t[2], t[3], float(t[4]))
		_node("res://gravelight/world/trap_lever.gd", "Lever_" + str(t[1]).trim_prefix("Trap_"), {"trap_path": NodePath("../" + trap.name), "trap_id": StringName(str(t[7]))}, t[5], float(t[6]))
	for bp: Vector3 in burst_points:
		var m: Marker3D = Marker3D.new()
		m.name = "BurstPoint"
		m.position = bp
		m.add_to_group(&"power_burst_points", true)
		gameplay.add_child(m)


# ================================================================== UPDATE 09 additions (T-146; additive only)
# Nothing above calls these: an act generator opts in (gen_map04a overrides build_lights() to call
# tag_light_zones after the base). Acts II-IV regenerate unchanged unless they call them too.

## The zone whose box holds `p` (generous in height: a lamp under a roof or a flood on a wall top still counts),
## else the zone whose box is nearest in plan. "" only when the act has no zone boxes.
func zone_at(p: Vector3) -> String:
	var best: String = ""
	var best_d: float = INF
	for zb: Array in zone_boxes:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		var inside_xz: bool = p.x >= lo.x and p.x <= hi.x and p.z >= lo.z and p.z <= hi.z
		if inside_xz and p.y >= lo.y - 2.0 and p.y <= hi.y + 12.0:
			return str(zb[0])
		var q: Vector3 = Vector3(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y), clampf(p.z, lo.z, hi.z))
		var d: float = Vector2(p.x - q.x, p.z - q.z).length() + absf(p.y - q.y) * 0.1
		if d < best_d:
			best_d = d
			best = str(zb[0])
	return best


## T-222 (opt-in: Acts I, III and IV call it; Act II does not): every shadowless omni light with a range up to
## `max_range` fades out past `begin` metres from the camera (Godot's per-light distance fade), so the practicals the
## lighting pass added cost nothing on the far side of a hall or the map. Returns how many lights it touched.
func fade_small_lights(begin: float = 42.0, length: float = 12.0, max_range: float = 16.0) -> int:
	var n: int = 0
	for l: Node in map_root.find_children("*", "OmniLight3D", true, false):
		var o: OmniLight3D = l as OmniLight3D
		if o.shadow_enabled or o.omni_range > max_range:
			continue
		o.distance_fade_enabled = true
		o.distance_fade_begin = begin
		o.distance_fade_length = length
		n += 1
	return n


## Gives every Light3D under the map root (except directional lights) a `zone` meta from its position when it has
## none, then holds the shadow budget (contract C4: at most `cap` shadow-casting lights per zone; the first ones
## built keep theirs). Returns {zone: shadowed count} after the cap.
func tag_light_zones(cap: int = 6) -> Dictionary:
	var counts: Dictionary = {}
	for n: Node in map_root.find_children("*", "Light3D", true, false):
		if n is DirectionalLight3D:
			continue
		var l: Light3D = n as Light3D
		if not l.has_meta("zone"):
			l.set_meta("zone", StringName(zone_at(_xform_to_root(l).origin)))
		if not l.shadow_enabled:
			continue
		var z: String = str(l.get_meta("zone"))
		if int(counts.get(z, 0)) >= cap:
			l.shadow_enabled = false
			push_warning("gen_map04: %s loses its shadow (zone %s is at its %d shadowed lights)" % [l.name, z, cap])
			continue
		counts[z] = int(counts.get(z, 0)) + 1
	return counts


# ================================================================== T-274: reactive props (an act calls these from
# build_gameplay_extra). Map 0's reactive dressing (gravelight/world/reactive/, T-053) and LoosePapers: all built at
# load from a few exported values, nothing collides, nothing touches the navmesh. Under one "Reactive" node on the root.

var _reactive: Node3D = null


func reactive_root() -> Node3D:
	if _reactive == null:
		_reactive = Node3D.new()
		_reactive.name = "Reactive"
		map_root.add_child(_reactive)
	return _reactive


func _reactive_node(script: String, n: String, props: Dictionary, pos: Vector3, yaw: float = 0.0, base: Node = null) -> Node3D:
	var node: Node3D = (base if base != null else Node3D.new()) as Node3D
	node.set_script(load(script))
	node.name = n
	for k: String in props.keys():
		node.set(k, props[k])
	node.position = pos
	node.rotation.y = deg_to_rad(yaw)
	reactive_root().add_child(node)
	return node


## A door leaf left ajar in an open doorway (SwingDoor): hinged at `hinge` (floor, on the jamb), the shut leaf along
## local +X (yaw), opening toward local -Z; `width` the leaf.
func swing_door(n: String, hinge: Vector3, yaw: float, width: float, props: Dictionary = {}) -> Node3D:
	var p: Dictionary = {"width": width, "height": 2.15, "rest_deg": 55.0, "open_deg": 100.0, "zone_size": Vector3(width + 0.2, 2.0, 3.2),
		"zone_center": Vector3(width * 0.5, 1.0, 0.0)}
	p.merge(props, true)
	return _reactive_node("res://gravelight/world/reactive/swing_door.gd", n, p, hinge, yaw)


## Two curtain strips either side of a gameplay window (DraftCurtain, billowing harder as its boards go), hung from the
## lintel on the room side.
func window_curtains(window_id: String, mat_key: String = "cloth_navy") -> void:
	for w: Array in windows:
		if str(w[0]) != window_id:
			continue
		var b: Basis = Basis(Vector3.UP, deg_to_rad(float(w[3])))
		var inward: Vector3 = b * Vector3(0, 0, 1)
		var along: Vector3 = b * Vector3(1, 0, 0)
		for s: float in [-1.0, 1.0]:
			var p: Vector3 = (w[2] as Vector3) + along * s * 1.05 + inward * (T * 0.5 + 0.08) + Vector3(0, WTOP + 0.05, 0)
			_reactive_node("res://gravelight/world/reactive/draft_curtain.gd", "Curtain_%s_%s" % [window_id, "L" if s < 0.0 else "R"],
				{"height": WTOP - SILL + 0.4, "mat_key": mat_key, "window": NodePath("../../Gameplay/" + window_id)}, p, float(w[3]) + 180.0)
		return
	push_warning("gen_map04: no window %s for curtains" % window_id)


## Glassware that breaks when shot or blasted (ShatterSet): items [[local base, kind, height scale], ...].
func shatter_set(n: String, pos: Vector3, yaw: float, items: Array) -> Node3D:
	return _reactive_node("res://gravelight/world/reactive/shatter_set.gd", "Glass_" + n, {"items": items}, pos, yaw)


## Loose sheets on a floor or a desk top (LoosePapers).
func loose_papers(n: String, pos: Vector3, yaw: float, size: Vector3, count: int, props: Dictionary = {}) -> Node3D:
	var p: Dictionary = {"size": size, "count": count, "seed_value": hash(n) & 0xFFFF}
	p.merge(props, true)
	return _reactive_node("res://gravelight/world/map04/loose_papers.gd", "Papers_" + n, p, pos, yaw)


## Water dripping from a ceiling at `pos` to the floor `height` below (DripPoint).
func drip(n: String, pos: Vector3, height: float) -> Node3D:
	return _reactive_node("res://gravelight/world/drip_point.gd", "Drip_" + n, {"height": height}, pos)


## Dust (or chaff) that puffs up under feet (HayPuffZone with a tint): a box on the floor.
func dust_zone(n: String, pos: Vector3, size: Vector3, tint: Color) -> Node3D:
	return _reactive_node("res://gravelight/world/reactive/hay_puff_zone.gd", "Dust_" + n, {"size": size, "tint": tint}, pos, 0.0, Area3D.new())


# ================================================================== T-274: perk spots (opt-in: an act fills perk_spots)
# The perk deal of Map 0 (T-251, T-255) on the Map 4 acts: each act's machines are dealt onto its spots each match
# from the match seed (PerkShuffle / PerkLayout, perk_layout.json "maps"), the spots left over show their filler crate
# (PerkSpot). The scene is saved with the seed-0 deal. A spot keeps the widest machine's floor (the wagon) by the
# deepest (the barrel); every spot is flush: its back edge on the wall (PERK_FLUSH_GAP off it), a shallower machine
# and the crate stand back to that line (PerkSpot.stand_transform), the fine print hangs on the side with the walk.
# Rows: [spot id, zone ("" = the zone box it stands in), floor position (the spot's centre), yaw (local -Z = the
# front, into the room), flags]. Flags: "flush" (+1 / -1: the fine print's side; left out: the side with the walk),
# "start" / "near" (left out: the start zone / a zone one door from it, from `adj`), "outdoor" (false on every act:
# no snow on these four, and the acts stood their cabinets in the open before). The spots' footprints are cut out of
# the navmesh (bake only: the machine or the crate on the spot has its own body); _audit_perk_spots checks every spot
# against what is built and drawn and keeps the scene unsaved when one is blocked (GL_PERK_FORCE=1 saves anyway;
# GL_PERK_SURVEY=1 prints the clear places on the act's walls instead of saving; GL_PERK_PROBE="x,y,z,yaw;..." probes).

const PerkShuffleScript: GDScript = preload("res://gravelight/world/perk_shuffle.gd")
const PERK_SPOT_W: float = 1.7
const PERK_SPOT_D: float = 1.2
const PERK_FRONT: float = 1.2
const PERK_SIDE: float = 0.9
const PERK_FLUSH_GAP: float = 0.1
const NAV_SOLID_H: float = 1.6
## Same as PerkMachine._shape_footprint and gen_map00's table (a --script run has no autoloads). Keep them in step.
const MACHINE_FOOTPRINTS: Dictionary = {
	"barrel": Vector3(1.2, 1.9, 1.2), "cabinet": Vector3(0.8, 2.3, 0.6), "crate": Vector3(1.0, 2.0, 0.65),
	"twin": Vector3(1.2, 2.1, 0.6), "teardrop": Vector3(1.0, 2.4, 0.9), "periscope": Vector3(0.9, 1.8, 0.65),
	"wagon": Vector3(1.7, 1.7, 0.85), "safe": Vector3(1.1, 1.9, 0.95), "coil": Vector3(0.8, 2.3, 0.6),
	"register": Vector3(1.0, 2.2, 0.75), "glider": Vector3(0.8, 2.4, 0.7), "bandit": Vector3(0.9, 2.3, 0.65),
}

var _bake_only: Array[Node] = []
var _spot_grid: Dictionary = {}
var _spot_grid_done: bool = false
var _spot_keep: Array = []
var _spot_flush: Dictionary = {}   # spot id -> the resolved flush side
var _perks_json: Dictionary = {}


func _perk_shape(perk_id: String) -> String:
	if _perks_json.is_empty():
		_perks_json = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perks.json")) as Dictionary).get("perks", {})
	return str((_perks_json.get(perk_id, {}) as Dictionary).get("shape", "cabinet"))


func _perk_cost(perk_id: String) -> int:
	_perk_shape(perk_id)
	return int((_perks_json.get(perk_id, {}) as Dictionary).get("cost", 0))


## A spot row on the place where the act's machine `perk_id` stood before the deal (the `perks` table): the spot's back
## edge where that machine's back was, so whatever is dealt here stands back on the same line.
func spot_from_perk(id: String, perk_id: String, flags: Dictionary = {}) -> Array:
	for p: Array in perks:
		if str(p[0]) != perk_id:
			continue
		var fz: float = (MACHINE_FOOTPRINTS.get(_perk_shape(perk_id), Vector3(1.0, 2.0, 0.7)) as Vector3).z
		var yaw: float = float(p[2])
		var back: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
		var pos: Vector3 = (p[1] as Vector3) - back * (PERK_SPOT_D * 0.5 - fz * 0.5)
		var f2: Dictionary = flags.duplicate()
		if not f2.has("snap"):
			f2["snap"] = true   # most of the acts' machines stood half a metre off their wall: the spot goes back onto it
		return [id, "", Vector3(snappedf(pos.x, 0.001), pos.y, snappedf(pos.z, 0.001)), yaw, f2]
	push_error("gen_map04: no machine %s for spot %s" % [perk_id, id])
	return [id, "", Vector3.ZERO, 0.0, flags]


## A spot row on a wall: `face` is a point on the wall's face at floor height, `yaw` faces the room.
func spot_on_wall(id: String, face: Vector3, yaw: float, flags: Dictionary = {}) -> Array:
	var back: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	var pos: Vector3 = face - back * (PERK_SPOT_D * 0.5 + PERK_FLUSH_GAP)
	return [id, "", Vector3(snappedf(pos.x, 0.001), face.y, snappedf(pos.z, 0.001)), yaw, flags]


func _spot_zone(sp: Array) -> String:
	return str(sp[1]) if str(sp[1]) != "" else zone_at((sp[2] as Vector3) + Vector3.UP * 0.5)


func _spot_row(sp: Array) -> Dictionary:
	var flags: Dictionary = sp[4]
	var zone: String = _spot_zone(sp)
	return {"id": str(sp[0]), "zone": zone, "outdoor": bool(flags.get("outdoor", false)),
		"start": bool(flags.get("start", zone == start_zone)),
		"near": bool(flags.get("near", (adj.get(start_zone, []) as Array).has(zone)))}


func _spot_half(yaw: float) -> Vector3:
	var turned: bool = absf(absf(wrapf(yaw, -180.0, 180.0)) - 90.0) < 1.0
	return Vector3(PERK_SPOT_D * 0.5, 0, PERK_SPOT_W * 0.5) if turned else Vector3(PERK_SPOT_W * 0.5, 0, PERK_SPOT_D * 0.5)


func _perk_spot_blocks() -> void:
	_snap_spots()
	for sp: Array in perk_spots:
		var c: Vector3 = sp[2]
		var half: Vector3 = _spot_half(float(sp[3]))
		var b: Node3D = box(geo, "NavBlock_PerkSpot_" + str(sp[0]), c - half, c + half + Vector3(0, NAV_SOLID_H, 0), "metal")
		if b != null:
			_bake_only.append(b)


## Spots flagged "snap" walk back (local +Z, 5 cm at a time, at most 1.2 m) until the deepest machine's back would
## touch a collider, and stop PERK_FLUSH_GAP short of it. Left where they are when nothing is behind them.
func _snap_spots() -> void:
	_spot_grid_build()
	_spot_grid_done = false   # (built again with the drawing before the batching)
	for sp: Array in perk_spots:
		if not bool((sp[4] as Dictionary).get("snap", false)):
			continue
		var yaw: float = float(sp[3])
		var back: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
		var p0: Vector3 = sp[2]
		var moved: float = -1.0
		var t: float = 0.0
		while t <= 1.2:
			var fp: AABB = _spot_boxes(p0 + back * t, yaw, 1)[0]
			fp = AABB(fp.position + Vector3(0, 0.4, 0), fp.size - Vector3(0, 0.8, 0))   # (not the floor, not a lintel)
			if not _spot_hits(fp, true).is_empty():
				moved = maxf(0.0, t - 0.05 - PERK_FLUSH_GAP)
				break
			t += 0.05
		if moved >= 0.0:
			var p1: Vector3 = p0 + back * moved
			sp[2] = Vector3(snappedf(p1.x, 0.001), p1.y, snappedf(p1.z, 0.001))
			print("  perk spot %s snapped %.2f m back onto its wall" % [str(sp[0]), moved])
		else:
			print("  perk spot %s: no wall within 1.2 m behind it" % str(sp[0]))


## The flush side of a spot: its flag, else the side whose walk is clear (+1 first).
func _resolve_flush(sp: Array) -> int:
	var flags: Dictionary = sp[4]
	if flags.has("flush"):
		return int(flags["flush"])
	for s: int in [1, -1]:
		if _spot_hits(_spot_boxes(sp[2], float(sp[3]), s)[2]).is_empty():
			return s
	return 1


## The spots, and the act's machines stood on the seed-0 deal (PerkShuffle.assign with perk_layout.json's rules, the
## same call PerkLayout makes each match).
func _build_perk_spots() -> void:
	var rows: Array = []
	for sp: Array in perk_spots:
		var r: Dictionary = _spot_row(sp)
		var fl: int = int(_spot_flush.get(str(sp[0]), _resolve_flush(sp)))
		_spot_flush[str(sp[0])] = fl
		_node("res://gravelight/world/perk_spot.gd", "PerkSpot_" + str(sp[0]), {"spot_id": StringName(r["id"]), "zone_id": StringName(r["zone"]),
			"outdoor": r["outdoor"], "start": r["start"], "near": r["near"], "flush": fl}, sp[2], float(sp[3]))
		rows.append(r)
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perk_layout.json"))
	var key: String = map_id.get_slice("_", 0)
	var want: Array = ((rules.get("maps", {}) as Dictionary).get(key, {}) as Dictionary).get("perks", [])
	var prow: Array = []
	for p: Array in perks:
		if not want.has(str(p[0])):
			push_error("gen_map04: %s is not in perk_layout.json maps.%s" % [str(p[0]), key])
		prow.append({"id": str(p[0]), "cost": _perk_cost(str(p[0])), "shape": _perk_shape(str(p[0]))})
	var deal: Dictionary = PerkShuffleScript.call("assign", 0, rows, prow, rules)
	for pk: Dictionary in prow:
		var sid: String = str(deal.get(pk["id"], ""))
		var at: Array = []
		for sp2: Array in perk_spots:
			if str(sp2[0]) == sid:
				at = sp2
		if at.is_empty():
			push_error("gen_map04: no spot dealt to %s" % pk["id"])
			continue
		var fpz: float = (MACHINE_FOOTPRINTS.get(str(pk["shape"]), Vector3(1.0, 2.0, 0.7)) as Vector3).z
		var off: Vector3 = Basis(Vector3.UP, deg_to_rad(float(at[3]))) * Vector3(0, 0, maxf(0.0, (PERK_SPOT_D - fpz) * 0.5))
		var mp: Vector3 = (at[2] as Vector3) + off
		_node("res://gravelight/world/perk_machine.gd", "Perk_" + str(pk["id"]), {"perk_id": StringName(str(pk["id"]))},
			Vector3(snappedf(mp.x, 0.001), mp.y, snappedf(mp.z, 0.001)), float(at[3]))
	print("perk spots: %d, machines: %d (seed-0 deal: %s)" % [perk_spots.size(), prow.size(), str(deal)])


# ---- the audit (gen_map00's, T-251 / T-255, on this base's tables)

func _spot_grid_add(ab: AABB, n: String) -> void:
	for gx: int in range(int(floor(ab.position.x / 2.0)), int(floor(ab.end.x / 2.0)) + 1):
		for gz: int in range(int(floor(ab.position.z / 2.0)), int(floor(ab.end.z / 2.0)) + 1):
			var k: Vector2i = Vector2i(gx, gz)
			if not _spot_grid.has(k):
				_spot_grid[k] = []
			(_spot_grid[k] as Array).append([ab, n])


func _spot_grid_build() -> void:
	_spot_grid.clear()
	_spot_grid_done = true
	for b: Node in geo.find_children("*", "StaticBody3D", true, false):
		if String(b.name).begins_with("NavBlock_PerkSpot_"):
			continue
		for c: Node in b.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			_spot_grid_add((_xform_to_root(b as Node3D) * cs.transform) * AABB(-sz * 0.5, sz), "col:" + String(b.name))
	for n: Node in dress.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var ab: AABB = _xform_to_root(mi) * mi.get_aabb()
		if ab.size.x > 60.0 or ab.size.z > 60.0 or ab.size.y > 30.0:
			continue   # a shell, a sky, a ground sheet
		if not (mi.mesh is PrimitiveMesh) and (ab.size.x > 6.0 or ab.size.z > 6.0):
			continue   # a batch an act baked already (Groom Lake's DressingBaked): its box says nothing about one piece
		_spot_grid_add(ab, "mesh:%s(%s)" % [mi.name, mi.get_parent().name])


## What a machine must keep away from: [label, position, radius]. The gameplay nodes the base and the act placed, the
## act's arms locker and horse (built at load from their json rows).
func _spot_keep_build() -> void:
	_spot_keep.clear()
	var radii: Dictionary = {"door.gd": 2.3, "breach_door.gd": 2.3, "tunnel_hatch.gd": 2.3, "barricade.gd": 2.6, "zombie_spawn.gd": 1.4,
		"player_spawn.gd": 1.5, "wall_buy.gd": 1.6, "ammo_box.gd": 1.7, "mystery_crate.gd": 2.2, "trap_lever.gd": 1.5,
		"power_switch.gd": 1.8, "crucible.gd": 2.6, "armorers_bench.gd": 2.0}
	for n: Node in gameplay.get_children():
		var n3: Node3D = n as Node3D
		if n3 == null or n3.get_script() == null or n3.position == Vector3.ZERO:
			continue
		var f: String = str((n3.get_script() as Script).resource_path.get_file())
		if f in ["perk_machine.gd", "perk_spot.gd", "zone_volume.gd"]:
			continue
		_spot_keep.append([String(n3.name), n3.position, float(radii.get(f, 1.4))])
	var key: String = map_id.get_slice("_", 0)
	var lk: Dictionary = ((JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/weapon_locker.json")) as Dictionary).get("lockers", {}) as Dictionary).get(key, {})
	if lk.has("at"):
		_spot_keep.append(["the arms locker", _v3(lk["at"]), 2.2])
	if json_table != "":
		var mj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/%s.json" % json_table))
		for h: Variant in mj.get("horses", []):
			var hd: Dictionary = h
			for k: String in ["pos", "rail", "chest"]:
				if hd.has(k):
					_spot_keep.append(["the horse's " + k, _v3(hd[k]), 3.0])


func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


## The boxes a machine on a spot keeps (world AABBs; yaw a multiple of 90): [the footprint to the tallest cabinet's top,
## the walk in front, the walk beside it (the fine print's side), the wall right behind it].
func _spot_boxes(pos: Vector3, yaw: float, flush: int) -> Array:
	var b: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
	var s: float = float(flush if flush != 0 else 1)
	var rows: Array = [[Vector3(-PERK_SPOT_W * 0.5, 0.08, -PERK_SPOT_D * 0.5), Vector3(PERK_SPOT_W * 0.5, 2.45, PERK_SPOT_D * 0.5)],
		[Vector3(-PERK_SPOT_W * 0.5, 0.08, -PERK_SPOT_D * 0.5 - PERK_FRONT), Vector3(PERK_SPOT_W * 0.5, 2.0, -PERK_SPOT_D * 0.5)],
		[Vector3(s * PERK_SPOT_W * 0.5, 0.08, -PERK_SPOT_D * 0.5), Vector3(s * (PERK_SPOT_W * 0.5 + PERK_SIDE), 2.0, PERK_SPOT_D * 0.5 - 0.15)],
		[Vector3(-0.3, 0.5, PERK_SPOT_D * 0.5 + 0.02), Vector3(0.3, 1.5, PERK_SPOT_D * 0.5 + 0.3)]]
	var out: Array = []
	for r: Array in rows:
		var p0: Vector3 = pos + b * (r[0] as Vector3)
		var p1: Vector3 = pos + b * (r[1] as Vector3)
		out.append(AABB(p0.min(p1), (p1 - p0).abs()))
	return out


func _spot_hits(box_: AABB, colliders_only: bool = false) -> PackedStringArray:
	var out: PackedStringArray = []
	for gx: int in range(int(floor(box_.position.x / 2.0)), int(floor(box_.end.x / 2.0)) + 1):
		for gz: int in range(int(floor(box_.position.z / 2.0)), int(floor(box_.end.z / 2.0)) + 1):
			for e: Array in _spot_grid.get(Vector2i(gx, gz), []):
				var ab: AABB = e[0]
				if colliders_only and not str(e[1]).begins_with("col:"):
					continue
				if ab.intersects(box_) and ab.intersection(box_).get_volume() > 0.0005 and not out.has(str(e[1])):
					out.append(str(e[1]))
	return out


## True when `p` is over the baked navmesh (a polygon of an enabled region within 0.6 m of its height).
func _on_nav(p: Vector3) -> bool:
	var holder: Node = map_root.get_node_or_null("Navigation")
	if holder == null:
		return false
	for r: Node in holder.get_children():
		var reg: NavigationRegion3D = r as NavigationRegion3D
		if reg == null or reg.navigation_mesh == null or not reg.enabled:
			continue
		var nm: NavigationMesh = reg.navigation_mesh
		var vs: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var poly: PackedInt32Array = nm.get_polygon(i)
			if absf(vs[poly[0]].y - p.y) > 0.6:
				continue
			var inside: bool = true
			var sign_: float = 0.0
			for k: int in poly.size():
				var a: Vector3 = vs[poly[k]]
				var b: Vector3 = vs[poly[(k + 1) % poly.size()]]
				var cr: float = (b.x - a.x) * (p.z - a.z) - (b.z - a.z) * (p.x - a.x)
				if absf(cr) < 1e-6:
					continue
				if sign_ == 0.0:
					sign_ = signf(cr)
				elif signf(cr) != sign_:
					inside = false
					break
			if inside:
				return true
	return false


## What is wrong with a spot ([] = nothing). `ignore`: keep rows the spot's flags waive (a wall-buy on the far side of
## the spot's own wall: the keep radius is measured in plan).
func _spot_problems(pos: Vector3, yaw: float, flush: int, fast: bool = false, ignore: Array = []) -> PackedStringArray:
	var out: PackedStringArray = []
	var boxes: Array = _spot_boxes(pos, yaw, flush)
	var names: Array = ["the machine", "the walk in front", "the walk beside it"]
	for i: int in 3:
		var hits: PackedStringArray = _spot_hits(boxes[i])
		if not hits.is_empty():
			out.append("%s is in %s" % [names[i], ", ".join(hits)])
			if fast:
				return out
	if _spot_hits(boxes[3], true).is_empty():
		out.append("no wall behind it")
		if fast:
			return out
	for k: Array in _spot_keep:
		var kp: Vector3 = k[1]
		if absf(kp.y - pos.y) > 2.0 or ignore.has(str(k[0])):
			continue
		var d: float = Vector2(kp.x - pos.x, kp.z - pos.z).length()
		if d < float(k[2]):
			out.append("%.1f m from %s (wants %.1f)" % [d, str(k[0]), float(k[2])])
			if fast:
				return out
	var front: Vector3 = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -(PERK_SPOT_D * 0.5 + 0.7))
	if not _on_nav(front):
		out.append("the floor in front of it is not on the navmesh")
	return out


## Every spot against everything built and drawn, the other spots and the deal's own rules. One line per spot;
## returns how many problems there are.
func _audit_perk_spots() -> int:
	var bad: int = 0
	var ids: Dictionary = {}
	var per_zone: Dictionary = {}
	var near_n: int = 0
	for sp: Array in perk_spots:
		var id: String = str(sp[0])
		var p: Vector3 = sp[2]
		var fl: int = int(_spot_flush.get(id, _resolve_flush(sp)))
		var probs: PackedStringArray = _spot_problems(p, float(sp[3]), fl, false, (sp[4] as Dictionary).get("ignore", []))
		for sp2: Array in perk_spots:
			var q: Vector3 = sp2[2]
			var d2: float = Vector2(q.x - p.x, q.z - p.z).length()
			if str(sp2[0]) != id and absf(q.y - p.y) < 2.0 and d2 < 2.4:
				probs.append("%.1f m from spot %s" % [d2, str(sp2[0])])
		if ids.has(id):
			probs.append("its id is used twice")
		ids[id] = true
		var r: Dictionary = _spot_row(sp)
		per_zone[r["zone"]] = int(per_zone.get(r["zone"], 0)) + 1
		if bool(r["near"]):
			near_n += 1
		print("PERKSPOT_AUDIT %-16s %-15s flush %+d %s%s" % [id, str(r["zone"]), fl, "start " if r["start"] else ("near " if r["near"] else ""),
			"clear" if probs.is_empty() else "BLOCKED: " + "; ".join(probs)])
		if not probs.is_empty():
			bad += 1
	if near_n < 1:
		print("PERKSPOT_AUDIT no spot one door from the start (Second Wind needs one)")
		bad += 1
	if perk_spots.size() <= perks.size():
		print("PERKSPOT_AUDIT %d spots for %d machines (more spots than machines, or nothing is dealt)" % [perk_spots.size(), perks.size()])
		bad += 1
	print("PERKSPOT_AUDIT per zone: %s" % str(per_zone))
	return bad


## GL_PERK_SURVEY=1 (or a zone id): the clear places on the act's walls, per zone (at most 12 a zone, 3 m apart), as
## "SURVEY <zone> <x> <y> <z> <yaw> <flush>" lines; with GL_PERK_PROBE="x,y,z,yaw;...": what is wrong at exactly those.
func _survey_perk_spots() -> void:
	if OS.get_environment("GL_PERK_PROBE") != "":
		for row: String in OS.get_environment("GL_PERK_PROBE").split(";", false):
			var v: PackedFloat64Array = row.split_floats(",")
			if v.size() >= 4:
				for s: int in [1, -1]:
					var probs: PackedStringArray = _spot_problems(Vector3(v[0], v[1], v[2]), v[3], s)
					print("PROBE %s flush %+d: %s" % [row, s, "clear" if probs.is_empty() else "; ".join(probs)])
		return
	var only: String = OS.get_environment("GL_PERK_SURVEY")
	var seen: Dictionary = {}
	for zb: Array in zone_boxes:
		var zone: String = str(zb[0])
		if only != "1" and only != zone:
			continue
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		var y: float = lo.y + 1.0
		var found: Array = seen.get(zone, [])
		var x: float = lo.x + 0.75
		while x < hi.x - 0.75:
			var z: float = lo.z + 0.75
			while z < hi.z - 0.75:
				for yaw: float in [0.0, 90.0, 180.0, -90.0]:
					if found.size() >= 12:
						break
					var p2: Vector3 = Vector3(x, y, z)
					var far: bool = true
					for f: Vector3 in found:
						if f.distance_to(p2) < 3.0:
							far = false
					if not far:
						continue
					for s2: int in [1, -1]:
						if _spot_problems(p2, yaw, s2, true).is_empty():
							print("SURVEY %s %.2f %.2f %.2f %.0f %+d" % [zone, x, y, z, yaw, s2])
							found.append(p2)
							break
				z += 0.25
			x += 0.25
		seen[zone] = found
