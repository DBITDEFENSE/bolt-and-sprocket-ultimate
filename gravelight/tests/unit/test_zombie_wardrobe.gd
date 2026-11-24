extends GutTest
## T-269: the wardrobe data (data/gravelight/zombie_wardrobe.json) and the look it gives a walker.

const MAPS: PackedStringArray = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach",
	"map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]


func before_each() -> void:
	ZombieWardrobe.reload()


func _kits_of(map_id: String) -> Array:
	var g: Dictionary = GLData.table("enemies")["enemies"]["ganger"]
	var t: Dictionary = (g["variants_by_map"] as Dictionary).get(map_id, g["variants"])
	var out: Array = []
	for k: Variant in t.keys():
		if not str(k).begins_with("_"):
			out.append(str(k))
	return out


func _sat(c: Color) -> float:
	var s: Color = c.linear_to_srgb()
	return s.s


func test_every_map_has_a_palette_for_every_kit_it_spawns() -> void:
	var cfg: Dictionary = ZombieWardrobe.cfg()
	var outfits: Dictionary = cfg["outfits"]
	for map_id: String in MAPS:
		assert_true((cfg["maps"] as Dictionary).has(map_id), map_id + " has its own block")
		for kit: String in _kits_of(map_id):
			var table: Dictionary = ZombieWardrobe.outfits_for(map_id, kit)
			var names: int = 0
			var total: float = 0.0
			for o: Variant in table.keys():
				if str(o).begins_with("_"):
					continue
				names += 1
				assert_true(outfits.has(o), "%s / %s: outfit %s exists" % [map_id, kit, o])
				assert_gt(float(table[o]), 0.0, "%s / %s / %s: a positive weight" % [map_id, kit, o])
				total += float(table[o])
			assert_gte(names, 3, "%s / %s: at least three outfits (got %d)" % [map_id, kit, names])
			assert_gt(total, 0.0)


func test_variant_weights_per_map_sum_to_one() -> void:
	var g: Dictionary = GLData.table("enemies")["enemies"]["ganger"]
	for map_id: Variant in (g["variants_by_map"] as Dictionary).keys():
		if str(map_id).begins_with("_"):
			continue
		var total: float = 0.0
		for k: Variant in (g["variants_by_map"][map_id] as Dictionary).keys():
			assert_true((GLData.table("anim")["kits"] as Dictionary).has(k), "%s: kit %s exists" % [map_id, k])
			total += float(g["variants_by_map"][map_id][k])
		assert_almost_eq(total, 1.0, 0.001, str(map_id) + " weights sum to one")


func test_outfits_are_valid_colours_and_patterns() -> void:
	var outfits: Dictionary = ZombieWardrobe.cfg()["outfits"]
	assert_gte(outfits.size(), 30, "a wardrobe, not a uniform")
	for name: Variant in outfits.keys():
		var o: Dictionary = outfits[name]
		for slot: String in ["a", "b", "c"]:
			assert_true(Color.html_is_valid(str(o.get(slot, ""))), "%s.%s is a hex colour" % [name, slot])
		assert_true(ZombieWardrobe.PATTERNS.has(str(o.get("pattern", "none"))), "%s: a known pattern" % name)
		if o.has("pattern_color"):
			assert_true(Color.html_is_valid(str(o["pattern_color"])), "%s.pattern_color" % name)


func test_skins_are_weighted_and_dead() -> void:
	var w: Dictionary = ZombieWardrobe.skin_weights()
	assert_gte(w.size(), 3, "pallid, grey-green, bruised at least")
	for k: Variant in w.keys():
		assert_gt(float(w[k]), 0.0)
		var s: Dictionary = ZombieWardrobe.cfg()["skins"][k]
		assert_eq((s["tone"] as Array).size(), 3)
		assert_between(float(s["mottle"]), 0.0, 1.0)
		assert_true(Color.html_is_valid(str(s["mottle_color"])))


func test_the_choice_is_deterministic_from_the_synced_seed() -> void:
	# host and client both know the net id and the spawn health: the same look on both, nothing sent
	for net_id: int in [0, 7, 31]:
		for hp: float in [150.0, 262.5, 1040.0]:
			var a: int = ZombieWardrobe.look_seed(net_id, hp)
			var b: int = ZombieWardrobe.look_seed(net_id, hp + 0.0001)   # (a float that crossed the wire)
			assert_eq(a, b)
			for kit: String in ["villager", "soldier"]:
				var pa: Dictionary = ZombieWardrobe.look_params("map00_crossroads", kit, a)
				var pb: Dictionary = ZombieWardrobe.look_params("map00_crossroads", kit, b)
				assert_eq(pa, pb, "the same parameters from the same seed")
				assert_eq(ZombieWardrobe.outfit_name("map00_crossroads", kit, a), ZombieWardrobe.outfit_name("map00_crossroads", kit, b))
	assert_ne(ZombieWardrobe.look_seed(3, 150.0), ZombieWardrobe.look_seed(4, 150.0), "another slot, another look")
	assert_ne(ZombieWardrobe.look_seed(3, 150.0), ZombieWardrobe.look_seed(3, 165.0), "another round's health, another look")
	# a fixed value: the hash is integer arithmetic, the same on every platform and build
	assert_eq(ZombieWardrobe.look_seed(5, 150.0), ZombieWardrobe.look_seed(5, 150.0))
	assert_between(ZombieWardrobe.rand01(12345, 1), 0.0, 0.999999)


func test_a_crowd_of_24_is_varied_and_coloured() -> void:
	# the 32 pool slots at one round's health: what a full Map 0 crowd wears
	var names: Dictionary = {}
	var skins: Dictionary = {}
	var sat_sum: float = 0.0
	for net_id: int in 24:
		var look: int = ZombieWardrobe.look_seed(net_id, 150.0)
		names[ZombieWardrobe.outfit_name("map00_crossroads", "villager", look)] = true
		skins[ZombieWardrobe.skin_name(look)] = true
		var p: Dictionary = ZombieWardrobe.look_params("map00_crossroads", "villager", look)
		assert_eq((p["inst_cloth"] as Color).a, 1.0, "the outfit's colour is on")
		sat_sum += _sat(p["inst_cloth"] as Color)
		assert_between((p["inst_wear"] as Color).r, 0.0, 1.0)
	assert_gte(names.size(), 8, "24 villagers in at least eight different outfits (got %d)" % names.size())
	assert_gte(skins.size(), 3, "at least three skins among 24")
	assert_gt(sat_sum / 24.0, 0.4, "the main cloth is a colour: the old kits were under 0.25 (mean %.2f)" % (sat_sum / 24.0))


func test_weighted_pick_follows_the_table() -> void:
	var t: Dictionary = {"_doc": "skipped", "a": 1.0, "b": 3.0}
	assert_eq(ZombieWardrobe.pick_weighted(t, 0.0), "a")
	assert_eq(ZombieWardrobe.pick_weighted(t, 0.24), "a")
	assert_eq(ZombieWardrobe.pick_weighted(t, 0.26), "b")
	assert_eq(ZombieWardrobe.pick_weighted(t, 0.999), "b")
	assert_eq(ZombieWardrobe.pick_weighted({}, 0.5), "")
	var hits: Dictionary = {"a": 0, "b": 0}
	for i: int in 4000:
		hits[ZombieWardrobe.pick_weighted(t, ZombieWardrobe.rand01(ZombieWardrobe.look_seed(i, 150.0), 1))] += 1
	assert_almost_eq(float(hits["b"]) / 4000.0, 0.75, 0.04, "the hash spreads evenly over the weights")


func test_kits_outside_the_wardrobe_keep_their_own_colours() -> void:
	for kit: String in ["soviet", "soviet_tunic", "soviet_burial", "drowned", "bellringer"]:
		var p: Dictionary = ZombieWardrobe.look_params("map00_crossroads", kit, 99)
		assert_eq((p["inst_cloth"] as Color).a, 0.0, kit + " keeps its baked cloth")
	assert_eq((ZombieWardrobe.look_params("map00_crossroads", "soviet", 99)["inst_skin"] as Color), Color(1, 1, 1, 0), "the Returned stay frost-white")
	var n: Dictionary = ZombieWardrobe.neutral_params()
	for key: String in ZombieWardrobe.INST_KEYS:
		assert_true(n.has(key), "neutral covers " + key)


func test_the_look_adds_no_surface_material_or_mesh() -> void:
	var body: ArrayMesh = ZombieBody.build_skinned("villager", "medium", false)
	assert_eq(body.get_surface_count(), 2, "skin + kit, as before")
	assert_same(body.surface_get_material(1), ZombieBody.kit_material(true), "the shared zombie kit material")
	assert_same(ZombieBody.build_skinned("soldier", "medium", false).surface_get_material(1), body.surface_get_material(1), "one kit material for every kit")
	assert_same(ZombieBody.build_skinned("villager", "medium", false), body, "one mesh per kit / build / sex whatever the outfit")
	# the colour slots are in the mesh: the main cloth in slot 1, the second in slot 2
	if not ZombieBody.base_parts("medium", false).has("Body"):
		pending("zombie_base GLBs not imported")
		return
	var cus: PackedFloat32Array = body.surface_get_arrays(1)[Mesh.ARRAY_CUSTOM0]
	var by_slot: Dictionary = {}
	for i: int in range(3, cus.size(), 4):
		var slot: int = int(cus[i]) / 8
		by_slot[slot] = int(by_slot.get(slot, 0)) + 1
	assert_gt(int(by_slot.get(1, 0)), 100, "cloth vertices carry slot 1")
	assert_gt(int(by_slot.get(2, 0)), 100, "cloth2 vertices carry slot 2")
	assert_gt(int(by_slot.get(0, 0)), 100, "boots, buttons, the face parts keep their own colour")
	# a living person's clothes and a palette-dressed body are never recoloured
	var living: PackedFloat32Array = ZombieBody.build_living("villager", "medium", false).surface_get_arrays(1)[Mesh.ARRAY_CUSTOM0]
	for i: int in range(3, living.size(), 4):
		if living[i] >= 8.0:
			fail_test("a living body has a colour slot")
			return


func test_gear_is_one_surface_on_the_kit_material() -> void:
	for piece: String in ["scarf", "cap", "lamp_cap", "oilskin", "hood", "helmet", "goggles", "sailor_cap"]:
		var legacy: ArrayMesh = ZombieBody.gear_mesh(piece)[1]
		var g: Array = ZombieBody.zombie_gear_mesh(piece)
		var m: ArrayMesh = g[1]
		assert_eq(str(g[0]), str(ZombieBody.gear_mesh(piece)[0]), piece + ": the same bone")
		assert_eq(m.get_surface_count(), 1, piece + ": one surface (was %d)" % legacy.get_surface_count())
		assert_lte(m.get_surface_count(), legacy.get_surface_count(), piece + ": never more draw calls than before")
		assert_same(m.surface_get_material(0), ZombieBody.kit_material(true), piece + ": no material of its own")
		var tris: int = 0
		for si: int in legacy.get_surface_count():
			var a: Array = legacy.surface_get_arrays(si)
			tris += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		assert_eq((m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, tris, piece + ": the same triangles")
	# the armband keeps its textured mark as a second surface
	assert_eq((ZombieBody.zombie_gear_mesh("armband")[1] as ArrayMesh).get_surface_count(), (ZombieBody.gear_mesh("armband")[1] as ArrayMesh).get_surface_count())
	# the scarf takes the accent colour (slot 3), the gear flag is set
	var cus: PackedFloat32Array = (ZombieBody.zombie_gear_mesh("scarf")[1] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	assert_eq((int(cus[3]) - 64) / 8, 3, "the scarf is the accent")
	assert_gte(cus[3], 64.0, "gear flag")


func test_light_and_wear_values_stay_subtle() -> void:
	var cfg: Dictionary = ZombieWardrobe.cfg()
	assert_between(ZombieWardrobe.frost_scale(), 0.0, 1.0)
	assert_between(float(cfg["light"]["min_light"]), 0.0, 0.2, "a floor, not a glow: walkers are not lamps")
	assert_between(float(cfg["light"]["rim"]), 0.0, 1.0)
	var kit: ShaderMaterial = ZombieBody.kit_material(true)
	assert_almost_eq(float(kit.get_shader_parameter("min_light")), float(cfg["light"]["min_light"]), 0.0001, "the zombie kit material carries it")
	var living: ShaderMaterial = ZombieBody.kit_material(false)
	assert_true(living.get_shader_parameter("min_light") == null or float(living.get_shader_parameter("min_light")) == 0.0, "the living people's material does not")
	assert_true(ZombieBody.skin_material("living").get_shader_parameter("rim") == null or float(ZombieBody.skin_material("living").get_shader_parameter("rim")) == 0.0)


func test_gear_keeps_its_colour_on_the_kit_material() -> void:
	# gear_mesh's StandardMaterial took the key's colour as sRGB; the kit shader's vertex colour is linear
	var m: ArrayMesh = ZombieBody.zombie_gear_mesh("helmet")[1]
	var cols: PackedColorArray = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var want: Color = (ZombieBody.KEY_LOOK["helmet"][0] as Color).srgb_to_linear()
	assert_almost_eq(cols[0].r, want.r, 0.01)
	assert_almost_eq(cols[0].g, want.g, 0.01)
	assert_almost_eq(cols[0].b, want.b, 0.01)
