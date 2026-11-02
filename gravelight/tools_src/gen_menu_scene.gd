extends SceneTree
## Exports the main menu's set (UPDATE 09 section 7, DECISIONS T-144): the Crossroads Inn seen from outside, cut
## once out of Map 0 (gravelight/maps/map00_crossroads/map00.tscn, which gen_map00.gd builds) and saved as
## gravelight/ui/menu_inn.tscn for MenuScene. Kept: the inn's outer shell and roofs, the chimney smoke, the sign, the
## windows' and doors' dressing, the yard and the grounds (fences, the well, the stable's end, the road), the outdoor
## library props, the Landscape node (sky, terrain, forests and the far world are built at load time by its script),
## the snowfall, the Moon and the environment. Dropped: every interior (taproom, rooms, cellars, the stable's
## inside), the gameplay nodes, the collision shell and the navmesh, the interior lights (MenuScene lights its own
## set inside the light budget) and the map's scripts other than the scenery ones.
## Run (headless, after gen_map00): godot --headless --path . --script res://gravelight/tools_src/gen_menu_scene.gd

const SRC: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const OUT: String = "res://gravelight/ui/menu_inn.tscn"
## Dressing groups that are interiors (or far away) and go.
const DROP_DRESSING: PackedStringArray = ["Staircase", "Hearth", "Bar", "Taproom", "Upstairs", "Stable", "Cellar", "OldCellar", "Polish"]
## Top-level map nodes kept as they are (lights other than the Moon are never kept).
const KEEP_TOP: PackedStringArray = ["Dressing", "StaticBatches", "LibraryProps", "Landscape", "Snowfall", "WorldEnvironment", "Moon"]
## Scripts allowed on kept nodes (scenery that builds itself; nothing reads match state).
const KEEP_SCRIPTS: PackedStringArray = ["res://gravelight/world/snowfall.gd", "res://gravelight/world/landscape/landscape.gd",
	"res://gravelight/world/landscape/prop_scatter.gd", "res://gravelight/world/baked_multimesh.gd",
	"res://gravelight/world/landscape/nature_rows.gd", "res://gravelight/world/reactive/draft_curtain.gd"]
## Interior volumes (Map 0 frame): a batch, prop or node wholly inside one is never seen from outside.
const INTERIORS: Array = [
	[Vector3(0.32, -0.1, 0.32), Vector3(23.68, 6.78, 15.68)],    # the inn: taproom, rooms, stair hall
	[Vector3(0.32, -0.1, 9.9), Vector3(23.68, 3.9, 16.6)],       # the stair tower / passage lean-to
	[Vector3(4.82, -0.1, 22.32), Vector3(25.18, 6.98, 33.68)],   # the stable's inside, the loft
]

var _dropped: Dictionary = {}


func _initialize() -> void:
	var t0: int = Time.get_ticks_msec()
	var src: Node3D = (load(SRC) as PackedScene).instantiate() as Node3D
	var root: Node3D = Node3D.new()
	root.name = "MenuInn"
	for n: String in KEEP_TOP:
		var c: Node = src.get_node_or_null(n)
		if c == null:
			push_warning("gen_menu_scene: %s missing in %s" % [n, SRC])
			continue
		src.remove_child(c)
		_unown(c)
		root.add_child(c)
	_trim_dressing(root.get_node_or_null("Dressing"))
	_trim_batches(root.get_node_or_null("StaticBatches"))
	_trim_props(root.get_node_or_null("LibraryProps"))
	_strip(root)
	_own(root, root)
	var meshes: int = root.find_children("*", "MeshInstance3D", true, false).size()
	var lights: int = root.find_children("*", "Light3D", true, false).size()
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("gen_menu_scene: saved %s (%d meshes, %d lights; dropped %s) err=%d in %d ms" % [OUT, meshes, lights, str(_dropped), err, Time.get_ticks_msec() - t0])
	root.free()
	src.free()
	quit(0 if err == OK else 1)


func _count(kind: String) -> void:
	_dropped[kind] = int(_dropped.get(kind, 0)) + 1


static func inside_interior(lo: Vector3, hi: Vector3) -> bool:
	for box: Array in INTERIORS:
		var a: Vector3 = box[0]
		var b: Vector3 = box[1]
		if lo.x >= a.x and lo.y >= a.y and lo.z >= a.z and hi.x <= b.x and hi.y <= b.y and hi.z <= b.z:
			return true
	return false


func _trim_dressing(dress: Node) -> void:
	if dress == null:
		return
	for c: Node in dress.get_children():
		var keep: bool = not DROP_DRESSING.has(str(c.name))
		if keep and c is Node3D:
			var p: Vector3 = (c as Node3D).position
			# window / door dressing groups: keep the outer ones (on the walls), drop the inside doors
			if str(c.name).begins_with("DoorFrame") or (str(c.name).begins_with("@Node3D") and c.get_child_count() == 0):
				keep = false
			elif p.y < -0.2:
				keep = false
		if not keep:
			dress.remove_child(c)
			c.free()
			_count("dressing")


func _trim_batches(batches: Node) -> void:
	if batches == null:
		return
	for c: Node in batches.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var aabb: AABB = mi.transform * mi.mesh.get_aabb()
		var hi: Vector3 = aabb.end
		if hi.y < -0.15 or inside_interior(aabb.position, hi):
			batches.remove_child(mi)
			mi.free()
			_count("batch")
	_merge_by_material(batches)


## gen_map00 batches per 12 x 6 x 12 m cell so the game can cull them as the player walks through; the menu's camera
## sees the whole inn at once, so one batch per (material, shadow mode) is fewer draw calls for the same picture.
func _merge_by_material(batches: Node) -> void:
	var groups: Dictionary = {}
	var order: Array = []
	for c: Node in batches.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null or mi.mesh == null or mi.material_override == null:
			continue
		var key: String = "%d|%d" % [mi.material_override.get_instance_id(), mi.cast_shadow]
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st, "n": 0}
			order.append(key)
		for s: int in mi.mesh.get_surface_count():
			(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, s, mi.transform)
		groups[key]["n"] = int(groups[key]["n"]) + 1
		batches.remove_child(mi)
		mi.free()
	var i: int = 0
	for key: String in order:
		var g: Dictionary = groups[key]
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Merged_%d" % i
		out.mesh = (g["st"] as SurfaceTool).commit()
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		batches.add_child(out)
		i += 1
	print("gen_menu_scene: merged the inn's batches into %d (one per material and shadow mode)" % i)


func _trim_props(props: Node) -> void:
	if props == null:
		return
	var items: Array = props.get("items")
	var kept: Array = []
	for it: Array in items:
		var o: Vector3 = (it[1] as Transform3D).origin
		if o.y < -0.2 or inside_interior(o - Vector3(0.05, 0.0, 0.05), o + Vector3(0.05, 0.1, 0.05)):
			_count("prop")
			continue
		kept.append(it)
	props.set("items", kept)


## Physics, navigation, lights (the Moon stays) and every script that is not scenery go.
func _strip(n: Node) -> void:
	for c: Node in n.get_children():
		var gone: bool = false
		if c is CollisionObject3D or c is CollisionShape3D or c is NavigationRegion3D or c is Area3D:
			gone = true
		elif c is Light3D and str(c.name) != "Moon":
			gone = true
		elif c is AudioStreamPlayer3D or c is AudioStreamPlayer:
			gone = true
		if gone:
			n.remove_child(c)
			c.free()
			_count("node")
			continue
		var s: Script = c.get_script() as Script
		if s != null and not KEEP_SCRIPTS.has(s.resource_path):
			print("gen_menu_scene: stripped script %s on %s" % [s.resource_path, c.name])
			c.set_script(null)
			_count("script")
		_strip(c)


func _unown(n: Node) -> void:
	n.owner = null
	for c: Node in n.get_children():
		_unown(c)


func _own(n: Node, owner_node: Node) -> void:
	for c: Node in n.get_children():
		c.owner = owner_node
		c.scene_file_path = ""
		_own(c, owner_node)
