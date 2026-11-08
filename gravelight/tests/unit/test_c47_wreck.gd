extends GutTest
## UPDATE 12 section 5 (DECISIONS T-211): GRAVELIGHT ONE, the C-47. The crash layout agrees with the map's hull, the
## model in use (the stand-in, or the owner's download once built) loads with its LODs, interior and impostor and
## every C-47 slot mapped; Map 0 draws it from C47Wreck at the wreck's site frame, the debris colliders are the build's
## boxes, the hull's own colliders and openings are untouched; the intact aircraft spins its props; the credits list a
## third-party model's artist exactly when one is in use.

const GEN: Script = preload("res://gravelight/tools_src/gen_map00.gd")
const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"


func test_layout_openings_are_the_hulls() -> void:
	var lay: Dictionary = C47Art.layout()
	var ops: Array = lay.get("openings", [])
	assert_eq(ops.size(), GEN.WRECK_OPENINGS.size(), "one opening per hull opening")
	for i: int in mini(ops.size(), GEN.WRECK_OPENINGS.size()):
		var a: Array = ops[i]
		var b: Array = GEN.WRECK_OPENINGS[i]
		for k: int in 5:
			assert_almost_eq(float(a[k]), float(b[k]), 0.001, "opening %d value %d matches gen_map00 WRECK_OPENINGS" % [i, k])
	var site: Dictionary = lay.get("site", {})
	var pos: Array = site.get("pos", [])
	assert_eq(Vector3(float(pos[0]), float(pos[1]), float(pos[2])), GEN.wreck_xf().origin, "the site is the wreck's position")
	assert_almost_eq(float(site.get("roll_deg", 0.0)), -8.0, 0.001, "the hull's roll")


func test_model_loads_with_lods_interior_and_impostor() -> void:
	assert_true(C47Art.has("crashed"), "a crashed C-47 is built (%s)" % C47Art.glb_path("crashed"))
	assert_true(C47Art.has("intact"), "an intact C-47 is built")
	var n: Node3D = C47Art.instance("crashed")
	assert_not_null(n)
	if n == null:
		return
	var names: Dictionary = {}
	for mi: MeshInstance3D in WorldArt.meshes(n):
		names[String(mi.name)] = mi
	for piece: String in ["fuselage", "tail", "wing_s", "engine_p", "stab_s", "wing_p_out"]:
		for lod: int in 3:
			assert_true(names.has("%s_LOD%d" % [piece, lod]), "%s_LOD%d" % [piece, lod])
	assert_true(names.has("Interior_INT"), "the cabin and cockpit")
	assert_true(names.has("ground_ALL"), "the drifts and the gouge")
	assert_true(names.has("Impostor"), "the far impostor")
	if names.has("fuselage_LOD1"):
		var l1: MeshInstance3D = names["fuselage_LOD1"]
		assert_gt(l1.visibility_range_begin, 0.0, "LOD1 starts past LOD0")
		assert_gt(l1.visibility_range_end, l1.visibility_range_begin)
	if names.has("Interior_INT"):
		assert_gt((names["Interior_INT"] as MeshInstance3D).visibility_range_end, 0.0, "the interior is culled far off")
	# every C-47 paint slot is the game's shader, nothing left as the GLB's plain material
	var left: PackedStringArray = []
	for mi2: MeshInstance3D in WorldArt.meshes(n):
		if mi2.mesh == null:
			continue
		for s: int in mi2.mesh.get_surface_count():
			var m: Material = mi2.mesh.surface_get_material(s)
			if m == null:
				continue
			if C47Art.PAINTS.has(m.resource_name) and not m is ShaderMaterial:
				left.append(m.resource_name)
	assert_eq(left.size(), 0, "C-47 slots mapped (%s)" % ", ".join(left))
	# the far view never draws more than the near one
	var lod: Dictionary = C47Art.layout().get("lod", {})
	assert_lt(float(lod.get("lod1_m", 0)), float(lod.get("lod2_m", 0)))
	assert_lt(float(lod.get("lod2_m", 0)), float(lod.get("impostor_m", 0)))
	n.free()


func test_map_draws_the_c47_and_keeps_the_hull() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var cw: Node3D = map.find_child("C47Wreck", true, false) as Node3D
	assert_not_null(cw, "C47Wreck on Map 0")
	if cw != null:
		assert_true(cw.transform.is_equal_approx(GEN.wreck_site_xf()), "at the wreck's site frame")
		assert_true(cw.get_script() != null and (cw.get_script() as Script).resource_path.ends_with("c47_wreck.gd"))
	# the hull's colliders T-126 built are all still there
	var wreck: Node = map.find_child("Wreck", true, false)
	assert_not_null(wreck)
	if wreck != null:
		var kinds: Dictionary = {}
		for c: Node in wreck.get_children():
			var k: String = String(c.name).rstrip("0123456789").trim_suffix("@")
			kinds[k] = true
		for need: String in ["HullFloor", "HullRoof", "HullWall", "HullSill", "HullLintel", "HullNose", "HullBulkhead", "CockpitChoke", "HullTail", "Wing", "Nacelle", "NoseCone"]:
			assert_true(kinds.has(need) or _has_prefix(wreck, need), "the hull keeps %s" % need)
		assert_false(_has_prefix(wreck, "TailPlane"), "the old tailplane box is gone (the tail broke away)")
	# the debris colliders are the build's boxes, no_mantle
	var site: Node = map.find_child("WreckSite", true, false)
	assert_not_null(site, "the debris colliders' frame")
	var boxes: Array = GLData.load_json(GEN.C47_COLLIDERS).get("boxes", [])
	if site != null:
		assert_eq(site.get_child_count(), boxes.size(), "one collider per box in c47_colliders.json")
		for b: Node in site.get_children():
			assert_true(b is StaticBody3D and b.get_meta("no_mantle", false), "%s is solid cover, never a perch" % b.name)
	# the old grounds debris it replaced is gone
	assert_null(map.find_child("WingPanel", true, false))
	map.free()


static func _has_prefix(n: Node, prefix: String) -> bool:
	for c: Node in n.get_children():
		if String(c.name).begins_with(prefix):
			return true
	return false


func test_intact_spins_and_lights() -> void:
	var ps: PackedScene = load("res://gravelight/world/c47/c47_intact.tscn") as PackedScene
	assert_not_null(ps)
	var p: C47Intact = ps.instantiate() as C47Intact
	add_child_autofree(p)
	assert_not_null(p.model, "the intact model")
	assert_gt(p.props.size(), 1, "both propellers are their own nodes")
	assert_eq(p.exhaust_lights.size(), 2, "two exhaust glows")
	assert_gte(p.nav_lights.size(), 3, "the navigation lights")
	if p.props.is_empty():
		return
	var r0: Basis = p.props[0].transform.basis
	p._process(0.1)
	assert_false(p.props[0].transform.basis.is_equal_approx(r0), "the prop turns")
	p.lights_on = false
	assert_eq(p.nav_lights[0].light_energy, 0.0, "a raid flies dark")


func test_credits_follow_the_source() -> void:
	var credits: String = FileAccess.get_file_as_string("res://data/credits_art.json")
	if C47Art.source_id() == "standin":
		assert_eq(C47Art.credit_line(), "", "our stand-in credits nobody")
		assert_false(credits.contains("manilov") or credits.contains("Spark_Customs") or credits.contains("mgg8"), "no C-47 artist without their model")
	else:
		var line: String = C47Art.credit_line()
		assert_ne(line, "")
		assert_true(credits.contains(line.substr(0, 20)), "the Credits screen lists the C-47's artist")


func test_creak_sound_registered() -> void:
	var a: Dictionary = GLData.load_json("res://data/gravelight/audio.json")
	var sounds: Dictionary = a.get("sounds", a)
	assert_true(sounds.has("wreck_c47_creak"), "the hull's creaks")
	if sounds.has("wreck_c47_creak"):
		for f: String in (sounds["wreck_c47_creak"] as Dictionary).get("files", []):
			assert_true(ResourceLoader.exists(f), f)
