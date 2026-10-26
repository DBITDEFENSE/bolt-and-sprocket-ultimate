extends GutTest
## UPDATE 05 section 6 (T-095): the pooled VFX. Every weapon class has a flash look, every casing node the data
## names exists in the cartridge GLB and has a pool, every impact surface has a decal and debris, the pools never
## grow (500 shots' worth of flashes, casings, impacts, hits and shatters add no nodes), vfx_quality scales the
## counts, the surface table answers from names and metas, and the flicker stays in range.

const MODELS_PATH: String = "res://data/gravelight/weapons/models.json"

var _quality0: String


func before_each() -> void:
	_quality0 = str(GLSettings.values.get("vfx_quality", "high"))


func after_each() -> void:
	GLSettings.values["vfx_quality"] = _quality0


static func _descendants(n: Node) -> int:
	var c: int = 0
	for k: Node in n.get_children():
		c += 1 + _descendants(k)
	return c


func test_every_weapon_class_has_a_flash_config() -> void:
	var classes: Dictionary = {}
	for id: String in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		classes[str((GLData.table("weapons")["weapons"] as Dictionary)[id].get("class", "rifle"))] = true
	assert_gt(classes.size(), 5, "weapons.json has classes")
	for cls: String in classes.keys():
		assert_true(Effects.flash.has_class(cls), "flash config for class " + cls)
		var c: Dictionary = Effects.flash.class_cfg(cls)
		if not bool(c.get("skip", false)):
			assert_gt(float(c.get("life", 0.0)), 0.0, cls + " has a life")
			assert_true(Effects.flash._meshes.has(cls), cls + " has a petal mesh")
	assert_true(bool(Effects.flash.class_cfg("special").get("skip", false)), "the flamethrower keeps its flame")
	assert_eq(Effects.weapon_class_of(&"thompson_up"), "smg", "an upgraded id resolves through its base")
	assert_eq(Effects.weapon_class_of(&"totenglocke"), "wonder")


func test_every_casing_node_exists_in_the_glb_and_has_a_pool() -> void:
	var models: Dictionary = GLData.load_json(MODELS_PATH)
	var cart: Dictionary = (models.get("extras", {}) as Dictionary).get("cartridges", {})
	assert_false(cart.is_empty(), "models.json has the cartridge set")
	var glb: String = str(cart.get("glb", ""))
	assert_true(ResourceLoader.exists(glb), "the cartridge GLB imports: " + glb)
	var names: Dictionary = {}
	var ps: PackedScene = load(glb) as PackedScene
	assert_not_null(ps)
	if ps != null:
		var inst: Node = ps.instantiate()
		for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
			names[String(n.name)] = true
			if n.get_parent() != null:
				names[String(n.get_parent().name)] = true
		inst.free()
	var pools: Array = Effects.casings.kinds()
	for id: String in (cart.get("casing_for", {}) as Dictionary).keys():
		var node: String = str(cart["casing_for"][id])
		assert_true(names.has(node), id + ": GLB has node " + node)
		assert_true(pools.has(node), id + ": a casing pool for " + node)
	assert_true(Effects.casings.loaded_from_glb, "the pools use the GLB meshes, not the brass fallback")
	assert_eq(Effects.casings.node_for(&"thompson", "pistol"), "45_ACP")
	assert_eq(Effects.casings.node_for(&"thompson_up", "pistol"), "45_ACP", "an upgraded id through its base")
	assert_eq(Effects.casings.node_for(&"", "shell"), "12_Gauge", "the kind's default when the weapon is unknown")


func test_every_impact_surface_has_a_decal_and_debris() -> void:
	var impacts: Dictionary = Effects.vfx["impacts"]
	for surf: String in ["wood", "plaster", "stone", "snow", "metal", "glass", "hay", "cloth", "earth"]:
		assert_true(impacts.has(surf), "impact row for " + surf)
	for surf: String in impacts.keys():
		var decal: String = str((impacts[surf] as Dictionary).get("decal", surf))
		assert_true(decal == "" or Effects.DECALS.has(decal), surf + ": decal '" + decal + "' exists in Effects.DECALS")
		assert_true(Effects.impact_fx.covers(surf), surf + " has debris (a puff, chunks, sparks or the dirt pool)")
	# every surface the name table can answer with has a row
	for pair: Variant in (Effects.vfx["surfaces"]["name_hints"] as Array):
		assert_true(impacts.has(str((pair as Array)[1])), "hint '%s' -> '%s' has an impact row" % [(pair as Array)[0], (pair as Array)[1]])


func test_pools_never_grow_after_500_shots() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	add_child_autofree(body)
	var before: int = _descendants(Effects)
	var classes: Array = ["pistol", "smg", "rifle", "bolt", "shotgun", "lmg", "launcher", "wonder"]
	var ids: Array = [&"m1911", &"mp40", &"m1_garand", &"kar98k", &"trench_gun", &"mg42", &"panzerschreck", &"ashlight"]
	var surfs: Array = ["wood", "plaster", "stone", "snow", "metal", "glass", "hay", "cloth"]
	for i: int in 500:
		var p: Vector3 = Vector3(i * 0.01, 1.0, 0.0)
		Effects.muzzle_flash(p, Vector3.FORWARD, ids[i % ids.size()], i % 3 == 0, 1.0, true)
		Effects.casing("rifle", p, Vector3(1, 2, 0), Basis.IDENTITY, ids[i % ids.size()])
		Effects.impact(p, Vector3.BACK, surfs[i % surfs.size()], body)
		Effects.blood(p, Vector3.UP)
		Effects.zombie_hit(p, Vector3.UP, &"thompson_up", true)
		if i % 50 == 0:
			Effects.shatter(p)
			Effects.toll_ring(p, 10.0)
			Effects.muzzle_smoke(p, Vector3.FORWARD, 1.0)
	await get_tree().process_frame
	assert_eq(_descendants(Effects), before, "no node was added by 500 shots")
	assert_lte(Effects.flash.live_lights(), 4, "the flash-light budget holds")
	assert_lte(Effects.flash.live_count(), int(Effects.vfx["flash"]["slots"]))
	assert_gt(int(Effects.stats["flashes"]), 499)
	assert_true(classes.size() == ids.size())
	Effects.clear_marks()


func test_vfx_quality_scales_counts() -> void:
	GLSettings.values["vfx_quality"] = "high"
	var hi: Dictionary = Effects.quality()
	GLSettings.values["vfx_quality"] = "low"
	var lo: Dictionary = Effects.quality()
	assert_lt(float(lo["particles"]), float(hi["particles"]), "fewer particles on Low")
	assert_lt(int(lo["flash_lights"]), int(hi["flash_lights"]), "fewer flash lights on Low")
	assert_lt(float(lo["near_snow"]), float(hi["near_snow"]))
	assert_almost_eq(Effects.particles_k(), float(lo["particles"]), 0.001)
	# the flash honours the light budget of the row it is given
	var q: Dictionary = lo.duplicate()
	q["flash_lights"] = 1
	for i: int in 6:
		Effects.flash.fire(Vector3(i, 1, 0), Vector3.FORWARD, "rifle", false, 1.0, q)
	assert_lte(Effects.flash.live_lights(), 1, "one light on a budget of one")
	GLSettings.values["vfx_quality"] = "nonsense"
	assert_eq(Effects.quality(), hi, "an unknown level is High")


func test_surface_table_answers_from_metas_and_names() -> void:
	var holder: Node3D = Node3D.new()
	add_child_autofree(holder)
	var saved: StringName = GameState.map_id
	GameState.map_id = &"map00_crossroads"
	var cases: Dictionary = {"Taproom": "plaster", "StbN": "wood", "CagePanel": "metal", "HayBales": "hay", "Hearth": "stone",
		"CellarRoofSnow": "snow", "WindowGlass": "glass", "DraftCurtain": "cloth", "NavBlock_Crate": "metal", "BarFront": "wood"}
	for nm: String in cases.keys():
		var b: StaticBody3D = StaticBody3D.new()
		b.name = nm
		holder.add_child(b)
		assert_eq(Effects.surface_of(b, Vector3.ZERO, Vector3.BACK, null), cases[nm], nm)
	var tagged: StaticBody3D = StaticBody3D.new()
	tagged.name = "Taproom"
	tagged.set_meta("surface", "stone")
	holder.add_child(tagged)
	assert_eq(Effects.surface_of(tagged, Vector3.ZERO, Vector3.BACK, null), "stone", "the surface meta wins")
	var plain: StaticBody3D = StaticBody3D.new()
	plain.name = "Thing"
	holder.add_child(plain)
	assert_eq(Effects.surface_of(plain, Vector3.ZERO, Vector3.UP, null), "wood", "an unnamed floor on Map 0 is boards")
	assert_eq(Effects.surface_of(plain, Vector3.ZERO, Vector3.BACK, null), "plaster", "an unnamed wall on Map 0 is plaster")
	GameState.map_id = &"map01_kaltenbrunn"
	assert_eq(Effects.surface_of(plain, Vector3.ZERO, Vector3.BACK, null), "stone", "Kaltenbrunn's walls are stone")
	GameState.map_id = saved


func test_impact_decal_follows_the_surface_row() -> void:
	Effects.clear_marks()
	var holder: Node3D = Node3D.new()   # plain world geometry: no script on the parent (persists_on)
	add_child_autofree(holder)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	holder.add_child(body)
	Effects.impact(Vector3(0, 1, 0), Vector3.BACK, "plaster", body)
	assert_eq(Effects.persistent_hole_count(), 1, "plaster leaves a persistent crater")
	Effects.impact(Vector3(1, 1, 0), Vector3.BACK, "cloth", body)
	assert_eq(Effects.persistent_hole_count(), 1, "cloth leaves no mark")
	assert_gte(int(Effects.impact_fx.counts.get("cloth", 0)), 1, "but it throws threads")
	Effects.clear_marks()


func test_flicker_wobble_stays_in_range() -> void:
	var lo: float = INF
	var hi: float = -INF
	for i: int in 2000:
		var w: float = FlickerLight.wobble(float(i) * 0.37, 0.35, 0.74, 0.55)
		lo = minf(lo, w)
		hi = maxf(hi, w)
	assert_gt(lo, 0.2, "never out")
	assert_lt(hi, 1.7, "never a flare")
	assert_lt(lo, 0.95, "it does dip")
	assert_gt(hi, 1.05, "it does rise")
