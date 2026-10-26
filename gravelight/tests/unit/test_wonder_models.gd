extends GutTest
## The wonder weapons modelled by us (T-090, UPDATE_05 section 2): Ashlight, Totenglocke and Sankt-Elmsfeuer build
## through WeaponGLB from assets/ours/wonder/<id>/model.glb with the holder's contract and their animated parts, the
## Crucible version is the same meshes with a material and toggled parts, reload / draw timings are the data's (the
## same as with the greybox), the part drivers follow the holder's state, and the Siren Gramophone's world model has
## its moving parts while its gameplay body is unchanged.

const WONDER: Array[String] = ["ashlight", "totenglocke", "elmsfeuer"]
## Parts each model must carry (the holder's or WonderLook's drivers move them).
const PARTS: Dictionary = {"ashlight": ["Mag", "Needle", "Halo"], "totenglocke": ["Bell", "Crank", "Hammer", "Pawl", "Runes"],
	"elmsfeuer": ["Crank", "Dial", "Arc", "Orb"]}
## The Crucible-only parts (hidden on the base weapon).
const CRUCIBLE: Dictionary = {"ashlight": "Halo", "totenglocke": "Runes", "elmsfeuer": "Orb"}

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


func _root_pos(root: Node3D, n: Node3D) -> Vector3:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin


func test_wonder_weapons_are_ours_and_mapped() -> void:
	for id: String in WONDER:
		var e: Dictionary = WeaponGLB.entry(StringName(id))
		assert_eq(str(e.get("source", "")), "ours", id + " is our own model")
		assert_true(str(e.get("glb", "")).begins_with("res://assets/ours/wonder/"), id + " GLB under assets/ours/wonder")
		assert_true(WeaponGLB.wants(StringName(id)), id + " goes to the GLB path")
		assert_true(WeaponGLB.fit_for(StringName(id)).has("wonder"), id + " has its model_fit wonder block")
	var g: Dictionary = (WeaponGLB.models().get("extras", {}) as Dictionary).get("gramophone", {})
	assert_eq(str(g.get("source", "")), "ours", "the gramophone is registered under extras")


func test_every_wonder_builds_with_the_contract_and_its_parts() -> void:
	for id: String in WONDER:
		var m: Node3D = WeaponModels.build(StringName(id))
		for n: String in ["Muzzle", "SightPoint", "FrontSight", "LeftHand"]:
			assert_not_null(m.find_child(n, true, false), "%s has %s" % [id, n])
		for meta: String in ["reload", "length", "grip_r", "grip_r_radius", "lh_axis", "lh_radius"]:
			assert_true(m.has_meta(meta), "%s has meta %s" % [id, meta])
		for part: String in PARTS[id]:
			assert_not_null(m.get_node_or_null(part), "%s has its %s part" % [id, part])
		assert_eq(str(m.get_meta("wonder", "")), id, id + " is driven by WonderLook")
		var real: float = float(WeaponGLB.fit_for(StringName(id))["length"])
		var bb: AABB = WeaponModels.model_bounds(m)
		assert_almost_eq(bb.size.z, real, real * 0.1, "%s is %.3f m long (fit %.3f)" % [id, bb.size.z, real])
		var mz: Vector3 = _root_pos(m, m.find_child("Muzzle", true, false) as Node3D)
		var rear: Vector3 = _root_pos(m, m.find_child("SightPoint", true, false) as Node3D)
		var front: Vector3 = _root_pos(m, m.find_child("FrontSight", true, false) as Node3D)
		assert_lt(mz.z, -0.1, id + " muzzle ahead of the grip")
		assert_lt(front.z, rear.z, id + " front sight ahead of the rear")
		assert_almost_eq(front.y, rear.y, 0.003, id + " sight line level with the bore")
		# the special surfaces are in our shaders, the rest in the body shader
		var kinds: Dictionary = {}
		for c: Node in m.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c as MeshInstance3D
			if not mi.has_meta("glb"):
				continue
			for si: int in mi.mesh.get_surface_count():
				var mat: ShaderMaterial = mi.get_surface_override_material(si) as ShaderMaterial
				assert_not_null(mat, "%s %s surface %d has a shader" % [id, mi.get_parent().name, si])
				if mat != null:
					kinds[mat.shader.resource_path.get_file()] = true
		assert_true(kinds.has("wonder_body.gdshader"), id + " body in wonder_body")
		assert_true(kinds.has("wonder_glow.gdshader"), id + " has glowing surfaces")
		m.free()


## Gameplay doesn't move (section 0.4): the reload kind is the procedural model's, and reload / draw seconds are the
## data's with our model and with the greybox.
func test_timings_unchanged() -> void:
	var h: WeaponHolder = _p.weapons
	for id: String in WONDER:
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
		assert_eq(got[false], got[true], id + ": reload seconds, draw and reload kind identical with our model and the greybox")
		assert_almost_eq(float(got[false][0]), float(got[false][3]), 0.0001, id + ": the reload takes the data's empty-reload time")


## The Crucible version is a material and toggled parts on the same meshes (section 2.6).
func test_crucible_is_material_and_parts_only() -> void:
	for id: String in WONDER:
		var a: Node3D = WeaponModels.build(StringName(id))
		var b: Node3D = WeaponModels.build(StringName(id + "_up"))
		for part: String in PARTS[id]:
			var ma: MeshInstance3D = WonderLook._first_mesh(a.get_node(part))
			var mb: MeshInstance3D = WonderLook._first_mesh(b.get_node(part))
			assert_eq(ma.mesh, mb.mesh, "%s %s: the same mesh in the Crucible version" % [id, part])
		var cp: String = CRUCIBLE[id]
		assert_false((a.get_node(cp) as Node3D).visible, "%s: %s hidden on the base weapon" % [id, cp])
		assert_true((b.get_node(cp) as Node3D).visible, "%s: %s shown on the Crucible version" % [id, cp])
		assert_not_null(b.get_node_or_null("Nachtglow"), id + " upgraded glow light")
		a.free()
		b.free()
	# Mitternacht: the body takes the midnight-blue patina
	var t: Node3D = WeaponModels.build(&"totenglocke_up")
	var bell: MeshInstance3D = WonderLook._first_mesh(t.get_node("Bell"))
	var bm: ShaderMaterial = bell.get_surface_override_material(0) as ShaderMaterial
	assert_gt((bm.get_shader_parameter("patina") as Color).a, 0.5, "Mitternacht's patina is on")
	var t0: Node3D = WeaponModels.build(&"totenglocke")
	var bm0: ShaderMaterial = WonderLook._first_mesh(t0.get_node("Bell")).get_surface_override_material(0) as ShaderMaterial
	var p0: Variant = bm0.get_shader_parameter("patina")
	assert_true(p0 == null or (p0 as Color).a < 0.001, "the base bell has no patina")
	t.free()
	t0.free()


## The drivers follow the holder: the Ashlight's fluid is the magazine fraction, the Elmsfeuer's crank reload turns
## the crank and puts the support hand on its knob, the Totenglocke's hammer cocks while winding.
func test_part_drivers_follow_the_holder() -> void:
	var h: WeaponHolder = _p.weapons
	h.slots.clear()
	h.give_weapon(&"ashlight")
	h.current_index = 0
	h.call("_rebuild_gun")
	var w: WeaponInstance = h.current()
	w.mag = w.mag_size() / 4
	var model: Node3D = h.get("_model")
	WonderLook.tick(h, model, 0.016)
	var fluid: MeshInstance3D = WonderLook._first_mesh(model.get_node("Mag"))
	assert_almost_eq(float(fluid.get_instance_shader_parameter("level")), 0.25, 0.01, "Ashlight fluid level = magazine fraction")
	var needle: Node3D = model.get_node("Needle")
	assert_lt(needle.rotation.x, deg_to_rad(110.0), "the gauge needle moved off empty")
	# Sankt-Elmsfeuer: the magneto crank reload
	h.slots.clear()
	h.give_weapon(&"elmsfeuer")
	h.current_index = 0
	h.call("_rebuild_gun")
	assert_eq(str(h.get("_reload_kind")), "crank", "Elmsfeuer reload kind")
	var lh: Variant = WonderLook.reload_crank(h, 0.5, Vector3.ZERO)
	var crank: Node3D = h.call("_part", "Crank")
	assert_true(lh is Vector3, "the support hand has a target during the crank")
	assert_ne(crank.rotation.x, 0.0, "the crank turned")
	assert_lt(((lh as Vector3) - crank.position).length(), 0.08, "the hand is on the crank")
	# Totenglocke: the hammer cocks while the bell winds
	h.slots.clear()
	h.give_weapon(&"totenglocke")
	h.current_index = 0
	h.call("_rebuild_gun")
	var tm: Node3D = h.get("_model")
	var bell: Totenglocke = h.bell_logic()
	bell._holding = true
	bell._hold_t = 1.2
	for i: int in 30:
		WonderLook.tick(h, tm, 0.033)
	assert_gt((tm.get_node("Hammer") as Node3D).rotation.y, 0.1, "the striker cocks back during the wind")
	bell._holding = false


func test_gramophone_model_and_body() -> void:
	var v: Node3D = WonderLook.gramophone_visual()
	assert_not_null(v, "gramophone model imported")
	if v == null:
		return
	for part: String in ["Record", "Crank", "Tonearm"]:
		assert_not_null(v.get_node_or_null(part), "gramophone has its " + part)
	v.free()
	var g: Gramophone = Gramophone.new()
	add_child_autofree(g)
	var box: BoxShape3D = null
	for c: Node in g.get_children():
		if c is CollisionShape3D:
			box = (c as CollisionShape3D).shape as BoxShape3D
	assert_not_null(box, "collision unchanged")
	assert_eq(box.size, Vector3(0.3, 0.18, 0.3), "the gameplay box is the same size")
	assert_not_null(g.get_node_or_null("Visual"), "the modelled gramophone is its visual")
