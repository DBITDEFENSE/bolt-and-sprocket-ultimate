extends GutTest
## The downloaded guns as viewmodels (T-089, UPDATE_05 section 2): every weapon models.json maps to a GLB builds
## through WeaponModels.build with the contract the holder reads (Muzzle, SightPoint, FrontSight, LeftHand, the
## grip / reload metas, contract-named moving parts), at its real length, wrapped in the shared weapon shader; the
## greybox escape hatch and the six unmapped guns keep the procedural build; reload / draw timings are the data's
## whichever model is in hand; every survivor has an arms set.

const PARTS_FOR_RELOAD: Dictionary = {"mag": ["Mag"], "pistol": ["Mag"], "drum": ["Mag"], "belt": ["Mag", "Cover"],
	"bolt": ["Bolt"], "enbloc": ["Mag"], "shell": ["Pump"], "break": ["Barrels"]}

var _p: Player


func before_each() -> void:
	GLSettings.values["greybox_guns"] = false
	_p = Player.new()
	add_child_autofree(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func after_each() -> void:
	GLSettings.values["greybox_guns"] = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The conventional guns with a GLB (downloaded, plus the Type 100 we modelled, T-248); the wonder weapons are ours
## and have their own test (test_wonder_models, T-090).
func _glb_ids() -> Array[String]:
	var out: Array[String] = []
	var w: Dictionary = WeaponGLB.models().get("weapons", {})
	var rows: Dictionary = GLData.table("weapons")["weapons"]
	for id: String in w.keys():
		var wonder: bool = str((rows.get(id, {}) as Dictionary).get("class", "")) == "wonder"
		if WeaponGLB.glb_path(StringName(id)) != "" and not (str((w[id] as Dictionary).get("source", "")) == "ours" and wonder):
			out.append(id)
	return out


func _root_pos(root: Node3D, n: Node3D) -> Vector3:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin


func test_sixteen_guns_are_mapped() -> void:
	assert_eq(_glb_ids().size(), 21, "21 conventional guns have a model (16 downloaded, T-248: 4 more downloaded and the Type 100 of ours)")


func test_every_glb_gun_builds_with_the_contract() -> void:
	for id: String in _glb_ids():
		assert_true(WeaponGLB.wants(StringName(id)), id + " goes to the GLB path")
		var m: Node3D = WeaponModels.build(StringName(id))
		for n: String in ["Muzzle", "SightPoint", "FrontSight", "LeftHand"]:
			assert_not_null(m.find_child(n, true, false), "%s has %s" % [id, n])
		for meta: String in ["reload", "length", "grip_r", "grip_r_radius", "lh_axis", "lh_radius"]:
			assert_true(m.has_meta(meta), "%s has meta %s" % [id, meta])
		var kind: String = str(m.get_meta("reload"))
		for part: String in PARTS_FOR_RELOAD.get(kind, []):
			assert_not_null(m.get_node_or_null(part), "%s (%s reload) has its %s part" % [id, kind, part])
		# real length: the model's extent along the barrel within 10 % of models.json real_length_m (the Sawed-Off
		# is cut down on purpose: its own model_fit length)
		var real: float = float((WeaponGLB.entry(StringName(id))["native"] as Dictionary)["real_length_m"])
		if WeaponGLB.fit_for(StringName(id)).has("length"):
			real = float(WeaponGLB.fit_for(StringName(id))["length"])
		var bb: AABB = WeaponModels.model_bounds(m)
		assert_almost_eq(bb.size.z, real, real * 0.1, "%s is %.3f m long (real %.3f)" % [id, bb.size.z, real])
		# the frame: the muzzle is ahead (-Z) of the grip, the front sight ahead of the rear, the sights above the bore
		var mz: Vector3 = _root_pos(m, m.find_child("Muzzle", true, false) as Node3D)
		var rear: Vector3 = _root_pos(m, m.find_child("SightPoint", true, false) as Node3D)
		var front: Vector3 = _root_pos(m, m.find_child("FrontSight", true, false) as Node3D)
		assert_lt(mz.z, -0.1, id + " muzzle ahead of the grip")
		assert_lt(front.z, rear.z, id + " front sight ahead of the rear")
		assert_gt(front.y, mz.y - 0.01, id + " sights above the bore")
		# every downloaded surface is in the shared shader
		var shaded: int = 0
		for c: Node in m.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.has_meta("glb") and mi.mesh != null:
				var mat: Material = mi.get_surface_override_material(0)
				assert_true(mat is ShaderMaterial and (mat as ShaderMaterial).shader == WeaponShader.shader(), id + " surface in the weapon shader")
				shaded += 1
		assert_gt(shaded, 0, id + " has downloaded meshes")
		m.free()


func test_parts_are_renamed_to_the_contract() -> void:
	var w: Dictionary = WeaponGLB.models()["weapons"]
	for id: String in _glb_ids():
		var m: Node3D = WeaponModels.build(StringName(id))
		for key: String in (w[id]["parts"] as Dictionary).keys():
			var want: String = str(WeaponGLB.PART_NAMES.get(key, key))
			if key == "clip" and str(m.get_meta("reload")) == "enbloc":
				want = "Mag"
			if key == "cylinder":
				assert_not_null(m.find_child("Cylinder", true, false), id + " Cylinder (under its Barrels)")
				continue
			assert_not_null(m.get_node_or_null(want), "%s part %s -> %s" % [id, key, want])
		m.free()


func test_upgraded_is_the_same_mesh_in_nachtglas() -> void:
	var a: Node3D = WeaponModels.build(&"thompson")
	var b: Node3D = WeaponModels.build(&"thompson", true)
	var ma: MeshInstance3D = a.find_child("Mesh", true, false) as MeshInstance3D
	var mb: MeshInstance3D = b.find_child("Mesh", true, false) as MeshInstance3D
	assert_eq(ma.mesh, mb.mesh, "the Crucible version is the same mesh (a material, not a model)")
	assert_eq(float((mb.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("nachtglas")), 1.0, "veins on")
	assert_eq(float((ma.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("nachtglas")), 0.0, "veins off")
	assert_not_null(b.get_node_or_null("Nachtglow"), "the upgraded glow light")
	a.free()
	b.free()


func test_greybox_fallbacks() -> void:
	for id: String in ["luger_p08", "m1919", "ptrs41", "panzerschreck", "flamethrower"]:   # T-248: the Type 100 has a model now
		assert_false(WeaponGLB.wants(StringName(id)), id + " keeps the greybox")
		var m: Node3D = WeaponModels.build(StringName(id))
		assert_not_null(m.find_child("SightPoint", true, false), id + " procedural build still has its sights")
		m.free()
	GLSettings.values["greybox_guns"] = true
	assert_false(WeaponGLB.wants(&"thompson"), "the escape hatch sends every gun to the procedural build")
	var g: Node3D = WeaponModels.build(&"thompson")
	var glb: int = 0
	for c: Node in g.find_children("*", "MeshInstance3D", true, false):
		if c.has_meta("glb"):
			glb += 1
	assert_eq(glb, 0, "greybox Thompson has no downloaded meshes")
	g.free()


## Gameplay doesn't move (section 0.4): reload and draw seconds are the data's with the downloaded model and with
## the greybox one, and the reload animation kind is the procedural model's.
func test_timings_unchanged() -> void:
	var h: WeaponHolder = _p.weapons
	for id: String in _glb_ids():
		var got: Dictionary = {}
		for grey: bool in [false, true]:
			GLSettings.values["greybox_guns"] = grey
			h.slots.clear()
			h.give_weapon(StringName(id))
			h.current_index = 0
			h.call("_rebuild_gun")
			var w: WeaponInstance = h.current()
			w.mag = 0
			w.reserve = 999
			h.set("_swap_t", 0.0)
			h.start_reload()
			got[grey] = [float(h.get("_reload_t")), w.draw_mult(), str(h.get("_reload_kind")), w.f("reload_empty"), w.f("reload_partial")]
			h.call("_cancel_reload")
		assert_eq(got[false], got[true], id + ": reload seconds, draw and reload kind identical with the GLB and the greybox")
		assert_almost_eq(float(got[false][0]), float(got[false][3]) if not bool(GLData.table("weapons")["weapons"][id].get("per_round_reload", false)) else float(got[false][0]), 0.0001, id + ": the reload takes the data's empty-reload time")


func test_every_survivor_has_arms() -> void:
	for ch: StringName in [&"dutch", &"peg", &"deacon", &"wren", &"bolt", &"vendelin"]:
		assert_true(Arms.available(ch), String(ch) + " has an arms set")
		assert_not_null(Arms.hand(ch, false, 0.019, "fist"), String(ch) + " right fist")
		assert_not_null(Arms.hand(ch, true, 0.024, "open"), String(ch) + " left support hand")
		assert_not_null(Arms.forearm(ch), String(ch) + " forearm")
		assert_not_null(Arms.sleeve(ch), String(ch) + " sleeve")
	GameState.characters[77] = &"nobody"
	var fake: Player = Player.new()
	fake.player_id = 77
	assert_eq(Arms.character_for(fake), &"dutch", "a survivor without a set wears Dutch's")
	GameState.characters.erase(77)
	fake.free()


## T-098 fixes. The STG44: its stock's crimson palette cell is repainted walnut for that gun only (the shader read it
## as blued steel), and the stock is warped down below the sight line (its comb filled the ADS picture).
func test_stg44_stock_walnut_and_dropped() -> void:
	var fit: Dictionary = WeaponGLB.fit_for(&"stg44")
	var remap: Dictionary = (fit.get("shader", {}) as Dictionary).get("palette_remap", {})
	assert_true(remap.has("10"), "the stock's palette cell is remapped")
	var src: Texture2D = load("res://assets/third_party/opengameart/tt-stg44/textures/tt_stg44_ultimatelowpolyguns_albedo.png")
	var t: Texture2D = WeaponShader._palette_tex(src, remap)
	var c: Color = t.get_image().get_pixel(2 * 16 + 8, 1 * 16 + 8)
	assert_gt(c.r, c.g * 1.25, "walnut: red well above green")
	assert_gt(c.g, c.b * 0.85, "walnut: green at or above blue (the shader's wood test)")
	var other: Color = WeaponShader._palette_tex(src).get_image().get_pixel(2 * 16 + 8, 1 * 16 + 8)
	assert_gt(other.b, other.g, "other guns keep the pack's colour in that cell")
	# the stock's top behind the receiver sits at least 4 cm under the sight point
	var m: Node3D = WeaponModels.build(&"stg44")
	var sp: Vector3 = _root_pos(m, m.find_child("SightPoint", true, false) as Node3D)
	var top: float = -INF
	for row: Array in WeaponGLB.top_profile(m):
		if float(row[0]) >= 0.16:
			top = maxf(top, float(row[1]))
	assert_lt(top, sp.y - 0.04, "the comb is under the sight line (top %.3f, sight %.3f)" % [top, sp.y])
	m.free()


## The winter camo goes through the shader's whitewash path (a capped, chipped off-white), the other camos don't.
func test_winter_camo_is_a_whitewash() -> void:
	WeaponShader.reset()
	var m: Node3D = WeaponModels.build(&"thompson", false, &"winter")
	var ww: float = -1.0
	for c: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = (c as MeshInstance3D).get_surface_override_material(0)
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader == WeaponShader.shader():
			ww = maxf(ww, float((mat as ShaderMaterial).get_shader_parameter("whitewash")))
	assert_eq(ww, 1.0, "winter sets the whitewash flag")
	m.free()
	var o: Node3D = WeaponModels.build(&"thompson", false, &"olive_drab")
	for c: Node in o.find_children("*", "MeshInstance3D", true, false):
		var mat2: Material = (c as MeshInstance3D).get_surface_override_material(0)
		if mat2 is ShaderMaterial and (mat2 as ShaderMaterial).shader == WeaponShader.shader():
			assert_ne(float((mat2 as ShaderMaterial).get_shader_parameter("whitewash")), 1.0, "olive drab is a tint, not a whitewash")
	o.free()


## The raw Sketchfab GLBs load as opaque, non-emissive materials (the Kar98k's had emissiveFactor [1,1,1] and
## alphaMode BLEND: anything loading the raw GLB, a wall-buy mount for one, drew it glowing and see-through).
func test_raw_sketchfab_glbs_are_opaque_and_dark() -> void:
	for path: String in ["res://assets/third_party/sketchfab/kar98k-dsamuta/model.glb", "res://assets/third_party/sketchfab/m1-garand-sky-hunter/model.glb",
			"res://assets/third_party/sketchfab/thompson-artem-goyko/model.glb"]:
		var inst: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		for c: Node in inst.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c as MeshInstance3D
			for si: int in mi.mesh.get_surface_count():
				var sm: StandardMaterial3D = mi.mesh.surface_get_material(si) as StandardMaterial3D
				if sm == null:
					continue
				assert_eq(sm.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "%s %s is opaque" % [path.get_file(), sm.resource_name])
				assert_false(sm.emission_enabled and sm.emission_texture == null and sm.emission.get_luminance() > 0.01, "%s %s does not glow" % [path.get_base_dir().get_file(), sm.resource_name])
		inst.free()
