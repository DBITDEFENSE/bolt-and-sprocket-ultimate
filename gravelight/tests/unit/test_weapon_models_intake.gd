extends GutTest
## The gun intake's GLBs load (T-087, UPDATE_05A section 3): every model in data/gravelight/weapons/models.json imports
## as a scene with at least one mesh, its named parts exist, its triangle count and bounding box match what the
## converter recorded (so the axes and scale notes phase 2 relies on are true of the imported file), and a rifle is
## rifle-sized once the recorded scale is applied. Needs the editor import pass (`--headless --import`) to have run.

const MODELS_PATH: String = "res://data/gravelight/weapons/models.json"
const LONG_GUNS: PackedStringArray = ["kar98k", "m1_garand", "gewehr43", "m1_carbine", "springfield", "stg44", "bar", "mg42", "trench_gun", "sawed_off", "fg42", "mosin_nagant", "bren"]

var models: Dictionary


func before_all() -> void:
	models = GLData.load_json(MODELS_PATH)


static func mesh_instances(root: Node, out: Array) -> void:
	if root is MeshInstance3D:
		out.append(root)
	for c: Node in root.get_children():
		mesh_instances(c, out)


static func tri_count(mi: MeshInstance3D) -> int:
	var n: int = 0
	var m: Mesh = mi.mesh
	if m == null:
		return 0
	for s: int in range(m.get_surface_count()):
		var arrays: Array = m.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.size() > 0:
			@warning_ignore("integer_division")
			n += idx.size() / 3
		else:
			@warning_ignore("integer_division")
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


static func scene_aabb(root: Node3D, mis: Array) -> AABB:
	var box: AABB
	var first: bool = true
	for mi: MeshInstance3D in mis:
		var local: AABB = mi.mesh.get_aabb()
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		var b: AABB = xf * local
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func test_models_json_covers_every_weapon() -> void:
	var weapons: Dictionary = GLData.table("weapons")["weapons"]
	var listed: Dictionary = models.get("weapons", {})
	for id: String in weapons.keys():
		assert_true(listed.has(id), "models.json lists " + id)
	for id: String in listed.keys():
		assert_true(weapons.has(id), "models.json id exists in weapons.json: " + id)
	var greybox: Array = models.get("greybox", [])
	for id: String in listed.keys():
		var w: Dictionary = listed[id]
		if w.get("source") == null:
			assert_true(greybox.has(id), id + " without a model is on the greybox list")
		elif w.get("source") != "ours":
			assert_true(String(w.get("glb", "")).begins_with("res://assets/third_party/"), id + " glb under assets/third_party")
			assert_true(models["assets"].has(w["asset"]), id + " asset has an entry")
	assert_eq(models["frame"]["rig_forward"], "-Z")


func test_every_glb_loads_with_its_parts() -> void:
	var assets: Dictionary = models.get("assets", {})
	assert_gt(assets.size(), 0, "assets converted")
	var table: PackedStringArray = []
	for key: String in assets.keys():
		var a: Dictionary = assets[key]
		var path: String = a["glb"]
		assert_true(ResourceLoader.exists(path), key + ": " + path + " exists (imported)")
		if not ResourceLoader.exists(path):
			continue
		var ps: PackedScene = load(path) as PackedScene
		assert_not_null(ps, key + " loads as a PackedScene")
		if ps == null:
			continue
		var root: Node3D = ps.instantiate() as Node3D
		add_child_autofree(root)
		var mis: Array = []
		mesh_instances(root, mis)
		assert_gt(mis.size(), 0, key + " has at least one mesh")
		if mis.is_empty():
			continue
		# every named node the mapping promises is there
		var parts: Dictionary = a.get("parts", {})
		for part: String in parts.keys():
			var node_name: String = parts[part]
			assert_not_null(root.find_child(node_name, true, false), "%s: part %s -> node '%s' exists" % [key, part, node_name])
		for node_name: String in a.get("nodes", []):
			assert_not_null(root.find_child(node_name, true, false), "%s: node '%s' exists" % [key, node_name])
		# triangles and bounds match the converter's report
		var tris: int = 0
		for mi: MeshInstance3D in mis:
			tris += tri_count(mi)
		var want_tris: int = int(a["native"]["tris"])
		assert_almost_eq(float(tris), float(want_tris), maxf(2.0, want_tris * 0.01), key + " triangle count as recorded")
		var box: AABB = scene_aabb(root, mis)
		var mn: Array = a["native"]["bbox_min"]
		var mx: Array = a["native"]["bbox_max"]
		for k: int in range(3):
			assert_almost_eq(box.position[k], float(mn[k]), 0.01, "%s bbox min %d (axes as recorded)" % [key, k])
			assert_almost_eq(box.end[k], float(mx[k]), 0.01, "%s bbox max %d" % [key, k])
		table.append("%-42s %6d tris  %d meshes  size %.3f x %.3f x %.3f  forward %s  scale %.3f" % [key, tris, mis.size(),
			box.size.x, box.size.y, box.size.z, a["native"]["forward"], a["native"]["scale"]])
	for line: String in table:
		gut.p(line)


func test_scale_sanity() -> void:
	var listed: Dictionary = models.get("weapons", {})
	for id: String in listed.keys():
		var w: Dictionary = listed[id]
		if w.get("source") == null or w.get("source") == "ours":
			continue
		var n: Dictionary = w["native"]
		var length: float = float(n["length_m"]) * float(n["scale"])
		assert_almost_eq(length, float(n["real_length_m"]), 0.001, id + ": scale brings the model to its real length")
		if id in LONG_GUNS:
			assert_between(length, 0.85, 1.3, id + " is rifle-sized after scaling (%.2f m)" % length)
		else:
			assert_between(length, 0.18, 0.95, id + " is pistol/SMG-sized after scaling (%.2f m)" % length)
		assert_true(String(n["forward"]) in ["+X", "-X", "+Z", "-Z"], id + " forward is a horizontal axis")
		assert_eq(String(n["up"]), "+Y")
		assert_true(String(w["glb"]).begins_with("res://assets/third_party/"))


func test_casings_cover_every_firearm() -> void:
	var ex: Dictionary = models.get("extras", {})
	if not ex.has("cartridges"):
		pass_test("no cartridge set")
		return
	var casing: Dictionary = ex["cartridges"]["casing_for"]
	var nodes: Array = ex["cartridges"]["nodes"]
	for id: String in casing.keys():
		assert_true(nodes.has(casing[id]), id + " casing node exists: " + String(casing[id]))
	var weapons: Dictionary = GLData.table("weapons")["weapons"]
	for id: String in weapons.keys():
		var cls: String = String(weapons[id].get("class", ""))
		if cls in ["wonder", "launcher", "special"]:
			continue
		assert_true(casing.has(id), id + " has a casing stand-in")
