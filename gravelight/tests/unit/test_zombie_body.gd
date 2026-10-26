extends GutTest
## T-091: the modelled zombie bodies (assets/ours/characters/zombie_base, built by tools/build_characters.sh).
## Every kit x build x sex merges headless into the two-surface skinned mesh, weights only name rig bones, the
## mesh sits inside / around the gameplay hitboxes (ZombieBody.HITBOXES are the contract and never move), the gore
## split gives every LIMB_BONES piece, LODs exist with fewer triangles and the triangle budget (docs/ART_BIBLE.md
## section 5) holds.

const TOL_OUT: float = 0.06          # a vertex may sit this far outside its bone's hitbox (cloth, a heavy build)
const MIN_INSIDE: float = 0.85       # share of a bone's vertices inside its (grown) box
const MIN_FILL: float = 0.5         # the bone's vertices span at least this share of the box on its long axes


func _bodies() -> Array:
	var out: Array = []
	for f: bool in [false, true]:
		for b: String in ZombieBody.BUILDS:
			out.append([b, f])
	return out


func test_every_body_glb_is_present_and_weighted_to_rig_bones() -> void:
	var nb: int = ZombieRig.bone_names().size()
	for bf: Array in _bodies():
		var base: Dictionary = ZombieBody.base_parts(bf[0], bf[1])
		var tag: String = "%s/%s" % [bf[0], "f" if bf[1] else "m"]
		assert_true(base.has("Body"), tag + " has a Body")
		assert_true(base.has("Parts"), tag + " has the face parts")
		for kit: String in ZombieBody.KITS:
			assert_true(base.has("Kit_" + kit), "%s has Kit_%s" % [tag, kit])
		for name: String in base.keys():
			var a: Array = base[name]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var stride: int = bones.size() / maxi(1, v.size())
			var bad: int = 0
			var badsum: int = 0
			for i: int in v.size():
				var s: float = 0.0
				for k: int in stride:
					s += w[i * stride + k]
					if w[i * stride + k] > 0.0 and (bones[i * stride + k] < 0 or bones[i * stride + k] >= nb):
						bad += 1
				if absf(s - 1.0) > 0.02:
					badsum += 1
			assert_eq(bad, 0, "%s %s: every influence names a rig bone" % [tag, name])
			assert_eq(badsum, 0, "%s %s: weights sum to 1" % [tag, name])


func test_every_kit_build_sex_merges_into_two_surfaces() -> void:
	for bf: Array in _bodies():
		for kit: String in ZombieBody.KITS:
			var m: ArrayMesh = ZombieBody.build_skinned(kit, bf[0], bf[1])
			var tag: String = "%s %s/%s" % [kit, bf[0], "f" if bf[1] else "m"]
			assert_eq(m.get_surface_count(), 2, tag + ": skin + kit (two draw calls)")
			assert_true(m.surface_get_material(0) is ShaderMaterial, tag + ": infection shader on the skin")
			assert_same(m.surface_get_material(1), ZombieBody.kit_material(), tag + ": the one shared kit material")
			var skin: Array = m.surface_get_arrays(0)
			var body_tris: int = ((ZombieBody.base_parts(bf[0], bf[1])["Body"] as Array)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var tris: int = (skin[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			assert_lt(tris, body_tris, tag + ": the clothes hide the skin under them")
			assert_gt(tris, body_tris / 10, tag + ": ...but not all of it")
			assert_not_null(skin[Mesh.ARRAY_TEX_UV], tag + ": skin has UVs for the painted maps")
			assert_not_null(skin[Mesh.ARRAY_TANGENT], tag + ": and tangents for the normal map")


func test_meshes_sit_inside_the_hitboxes() -> void:
	for bf: Array in _bodies():
		var a: Array = ZombieBody.base_parts(bf[0], bf[1])["Body"]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var dom: PackedInt32Array = ZombieBody.dominant_bones(a)
		for h: Array in ZombieBody.HITBOXES:
			var bone: String = ZombieRig.legacy_name(str(h[0]))
			var bi: int = ZombieRig.bone_index(bone)
			var size: Vector3 = h[2]
			var centre: Vector3 = ZombieRig.rest_global(bone).origin + (h[3] as Vector3)
			var box: AABB = AABB(centre - size * 0.5, size)
			var grown: AABB = box.grow(TOL_OUT)
			var n: int = 0
			var inside: int = 0
			var span: AABB = AABB()
			for i: int in v.size():
				if dom[i] != bi:
					continue
				# the head's ears / hair and the chest's arm-pit fold may poke out; the rest sits in the box
				if n == 0:
					span = AABB(v[i], Vector3.ZERO)
				else:
					span = span.expand(v[i])
				n += 1
				if grown.has_point(v[i]):
					inside += 1
			var tag: String = "%s/%s %s" % [bf[0], "f" if bf[1] else "m", h[0]]
			assert_gt(n, 10, tag + ": the bone carries geometry")
			if n == 0:
				continue
			assert_gte(float(inside) / float(n), MIN_INSIDE, "%s: %d of %d vertices inside the hitbox (+%.2f m)" % [tag, inside, n, TOL_OUT])
			var long_axis: float = maxf(size.x, maxf(size.y, size.z))
			var long_span: float = span.size.y if size.y >= long_axis - 0.001 else maxf(span.size.x, span.size.z)
			assert_gte(long_span / long_axis, MIN_FILL, "%s: the mesh fills the box (%.2f of %.2f m)" % [tag, long_span, long_axis])


func test_gore_split_gives_every_limb_piece() -> void:
	for kit: String in ["soldier", "villager", "nurse"]:
		var female: bool = kit == "nurse"
		var build: String = "thin" if female else "medium"
		for bone: String in ZombieBody.LIMB_BONES:
			var p: ArrayMesh = ZombieBody.piece_mesh(kit, build, female, bone)
			assert_gt(p.get_surface_count(), 0, "%s %s piece has geometry" % [kit, bone])
			if p.get_surface_count() == 0:
				continue
			var bb: AABB = AABB((p.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array)[0], Vector3.ZERO)
			for si: int in p.get_surface_count():
				for q: Vector3 in p.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
					bb = bb.expand(q)
			# in the bone's own frame: the piece hangs from its joint (limbs down, head and jaw up)
			assert_lt(bb.size.length(), 1.2, "%s %s piece is limb sized" % [kit, bone])
			assert_true(bb.grow(0.12).has_point(Vector3.ZERO), "%s %s piece starts at its joint" % [kit, bone])
	for bone2: String in ["LeftUpperArm", "LeftLowerArm", "Head", "LeftUpperLeg"]:
		var pm: ArrayMesh = ZombieBody.piece_mesh("soldier", "medium", false, bone2)
		assert_eq(pm.surface_get_material(0), ZombieBody.build_skinned("soldier", "medium", false).surface_get_material(0), bone2 + " piece wears the body's own skin")


func test_lods_and_triangle_budget() -> void:
	var cfg: Dictionary = ZombieBody.char_cfg()
	var body_budget: int = int(cfg["budget"]["body_tris"])
	var kit_budget: int = int(cfg["budget"]["kit_tris"])
	for bf: Array in _bodies():
		var base: Dictionary = ZombieBody.base_parts(bf[0], bf[1])
		var tag: String = "%s/%s" % [bf[0], "f" if bf[1] else "m"]
		var t0: int = _tris(base["Body"])
		assert_lte(t0 + _tris(base["Parts"]), body_budget, tag + ": body + face parts within the budget")
		assert_lt(_tris(base["Body_LOD1"]), t0, tag + ": LOD1 has fewer triangles")
		assert_lt(_tris(base["Body_LOD2"]), _tris(base["Body_LOD1"]), tag + ": LOD2 fewer still")
		for kit: String in ZombieBody.KITS:
			assert_lte(_tris(base["Kit_" + kit]), kit_budget, "%s Kit_%s within %d" % [tag, kit, kit_budget])
	var m: ArrayMesh = ZombieBody.build_skinned("soldier", "heavy", false)
	if str(cfg["lod"]["mode"]) == "auto":
		var lc: Array = m.get_meta("lod_counts", [0, 0])
		assert_gt(int(lc[0]), 0, "Godot mesh LODs generated on the skin")
		assert_gt(int(lc[1]), 0, "...and on the kit")


func test_skin_material_has_painted_maps() -> void:
	var m: ShaderMaterial = ZombieBody.skin_material("base")
	assert_eq(float(m.get_shader_parameter("use_maps")), 1.0, "the zombie skin set is loaded")
	assert_not_null(m.get_shader_parameter("albedo_tex"))
	assert_not_null(m.get_shader_parameter("normal_tex"))
	assert_not_null(m.get_shader_parameter("orm_tex"))
	var keys: Array = ZombieBody.part_keys()
	for k: String in keys:
		assert_true(ZombieBody.KEY_LOOK.has(k) or k in ["skin", "cloth", "cloth2"], "part key %s has a look" % k)
	var order: Array = ZombieBody.char_cfg()["kit_order"]
	assert_eq(order, Array(ZombieBody.KITS), "the coverage bit order is the kit order")


func _tris(a: Array) -> int:
	return (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


func test_living_set_for_the_people_builder() -> void:
	var base: Dictionary = ZombieBody.base_parts("medium", true, true)
	if not base.has("Body"):
		pending("human_base GLBs not built (tools/build_characters.sh --living)")
		return
	var m: ArrayMesh = ZombieBody.build_living("villager", "medium", true)
	assert_eq(m.get_surface_count(), 2)
	var mat: ShaderMaterial = m.surface_get_material(0) as ShaderMaterial
	assert_eq(float(mat.get_shader_parameter("crack_energy")), 0.0, "no Nachtglas on the living")
	assert_eq(float(mat.get_shader_parameter("vein_energy")), 0.0)
	# plain eyes: no emissive part key on the living face
	var kit: Array = m.surface_get_arrays(1)
	var cus: PackedFloat32Array = kit[Mesh.ARRAY_CUSTOM0]
	var glow: int = 0
	for i: int in range(0, cus.size(), 4):
		if cus[i + 2] > 1.0:
			glow += 1
	assert_eq(glow, 0, "no glowing eyes")
	assert_same(ZombieBody.build_living("villager", "medium", true), m, "cached")
	assert_eq(ZombieBody.build_living("", "thin", false).get_surface_count(), 2, "an undressed body still has the face parts surface")


func test_crawl_pose_lies_on_the_floor() -> void:
	# T-091: the crawl pose pivoted at the feet and sank its hips 0.38 m under the floor (invisible crawlers)
	var p: Dictionary = ZombieClips._crawl_pose("drag", 0.0, false)
	var hips_y: float = ZombieRig.rest_offset("Hips").y + (p["hips_pos"] as Vector3).y
	assert_between(hips_y, 0.08, 0.3, "crawler hips just above the floor (%.2f m)" % hips_y)
	assert_lt(absf((p["hips_pos"] as Vector3).z), 0.5, "and over the body's own position")
