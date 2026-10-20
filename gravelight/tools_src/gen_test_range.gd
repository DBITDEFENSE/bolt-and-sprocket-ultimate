extends SceneTree
## Generates the developer Test Range: one lit hall with all 8 perk machines (powered), a wall-buy for every
## gun, the crate, and ground spawns for console-spawned zombies. Not a real map; reachable from the menu.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_test_range.gd

const OUT: String = "res://gravelight/maps/test_range/test_range.tscn"
const W: float = 44.0
const D: float = 30.0
const H: float = 6.0

var map_root: Node3D
var nav: NavigationRegion3D
var geo: Node3D
var _mats: Dictionary = {}
var _frames: int = 0


func _initialize() -> void:
	map_root = Node3D.new()
	map_root.name = "TestRange"
	get_root().add_child(map_root)
	nav = NavigationRegion3D.new()
	nav.name = "Navigation"
	map_root.add_child(nav)
	geo = Node3D.new()
	geo.name = "Geometry"
	nav.add_child(geo)
	_box("Floor", Vector3(-2, -0.5, -2), Vector3(W + 2, 0, D + 2), Color(0.32, 0.31, 0.3))
	_box("WallN", Vector3(0, 0, -0.3), Vector3(W, H, 0), Color(0.55, 0.55, 0.52))
	_box("WallS", Vector3(0, 0, D), Vector3(W, H, D + 0.3), Color(0.55, 0.55, 0.52))
	_box("WallW", Vector3(-0.3, 0, 0), Vector3(0, H, D), Color(0.5, 0.5, 0.48))
	_box("WallE", Vector3(W, 0, 0), Vector3(W + 0.3, H, D), Color(0.5, 0.5, 0.48))
	_box("Roof", Vector3(-0.3, H, -0.3), Vector3(W + 0.3, H + 0.2, D + 0.3), Color(0.2, 0.2, 0.2))
	for i: int in 4:
		_box("Cover%d" % i, Vector3(10 + i * 8, 0, 17), Vector3(11.5 + i * 8, 1.1, 18), Color(0.4, 0.3, 0.2))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, nav)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav.navigation_mesh = nm
	get_root().remove_child(map_root)
	_gameplay()
	_own(map_root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(map_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://gravelight/maps/test_range"))
		err = ResourceSaver.save(packed, OUT)
	print("Saved %s err=%d navpolys=%d" % [OUT, err, nm.get_polygon_count()])
	map_root.free()
	return true


func _mat(c: Color) -> StandardMaterial3D:
	var key: String = c.to_html()
	if not _mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		_mats[key] = m
	return _mats[key]


func _box(n: String, a: Vector3, b: Vector3, c: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.position = (a + b) * 0.5
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = (b - a).abs()
	cs.shape = shape
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = (b - a).abs()
	mi.mesh = bm
	mi.material_override = _mat(c)
	body.add_child(mi)
	geo.add_child(body)


func _own(n: Node) -> void:
	for c: Node in n.get_children():
		if c.owner == null:
			c.owner = map_root
		_own(c)


func _node(script: String, n: String, props: Dictionary, pos: Vector3, yaw: float, parent: Node3D) -> Node3D:
	var node: Node3D = Marker3D.new() if script.ends_with("spawn.gd") else Node3D.new()
	node.set_script(load(script))
	node.name = n
	for k: String in props.keys():
		node.set(k, props[k])
	node.position = pos
	node.rotation.y = deg_to_rad(yaw)
	parent.add_child(node)
	return node


func _gameplay() -> void:
	map_root.set_script(load("res://gravelight/maps/map_root.gd"))
	map_root.set("map_id", &"test_range")
	map_root.set("display_name", "Test Range")
	map_root.set("start_zone", &"RANGE")
	map_root.set("intro_text", "TEST RANGE\nPower is on. Everything costs Scrip; try `give_scrip 50000`.")
	map_root.set("power_on_at_start", true)
	map_root.set("auto_rounds", false)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	map_root.add_child(env)
	for i: int in 4:
		var l: OmniLight3D = OmniLight3D.new()
		l.position = Vector3(6 + i * 11, H - 0.6, D * 0.5)
		l.omni_range = 16.0
		l.light_energy = 1.4
		l.light_color = Color(1.0, 0.9, 0.75)
		map_root.add_child(l)
	var g: Node3D = Node3D.new()
	g.name = "Gameplay"
	map_root.add_child(g)
	_node("res://gravelight/maps/player_spawn.gd", "PlayerSpawn1", {}, Vector3(W * 0.5, 0, 12), 0.0, g)
	var zone: Node3D = _node("res://gravelight/world/zone_volume.gd", "Zone_RANGE", {"zone_id": &"RANGE", "size": Vector3(W, H, D)}, Vector3(W * 0.5, 0, D * 0.5), 0.0, g)
	zone.name = "Zone_RANGE"
	# perk machines along the north wall (local -Z faces the room = +Z world -> yaw 180)
	var perks: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perks.json")) as Dictionary)["perks"].keys()
	for i: int in perks.size():
		_node("res://gravelight/world/perk_machine.gd", "Perk_" + str(perks[i]), {"perk_id": StringName(str(perks[i]))},
			Vector3(4.0 + i * 5.0, 0, 0.9), 180.0, g)
	# wall-buys for every gun: west + east walls and the south wall
	var weps: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/weapons.json")) as Dictionary)["weapons"].keys()
	for i: int in weps.size():
		var pos: Vector3
		var yaw: float
		if i < 6:
			pos = Vector3(0.02, 1.5, 4.0 + i * 4.0)
			yaw = -90.0
		elif i < 12:
			pos = Vector3(W - 0.02, 1.5, 4.0 + (i - 6) * 4.0)
			yaw = 90.0
		else:
			pos = Vector3(4.0 + (i - 12) * 4.5, 1.5, D - 0.02)
			yaw = 0.0
		_node("res://gravelight/world/wall_buy.gd", "WallBuy_" + str(weps[i]), {"weapon_id": StringName(str(weps[i]))}, pos, yaw, g)
	_node("res://gravelight/world/wall_buy.gd", "WallBuy_frag", {"weapon_id": &"frag"}, Vector3(W - 6.0, 1.5, D - 0.02), 0.0, g)
	_node("res://gravelight/world/wall_buy.gd", "WallBuy_etool", {"weapon_id": &"etool"}, Vector3(W - 2.5, 1.5, D - 0.02), 0.0, g)
	_node("res://gravelight/world/crucible.gd", "Crucible", {}, Vector3(W - 4.0, 0, 16.0), 90.0, g)
	_node("res://gravelight/world/mystery_crate.gd", "Crate_Range", {"spot_index": 0, "can_start": true, "spot_name": "Range"}, Vector3(W * 0.5, 0, 7.0), 180.0, g)
	for i: int in 4:
		_node("res://gravelight/enemies/zombie_spawn.gd", "Spawn%d" % i, {"zone_id": &"RANGE", "kind": &"ground"}, Vector3(8 + i * 9, 0, 24), 0.0, g)
