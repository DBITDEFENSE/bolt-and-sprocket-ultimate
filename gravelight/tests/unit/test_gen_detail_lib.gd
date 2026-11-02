extends GutTest
## The shared generator detail library (gravelight/tools_src/gen_detail_lib.gd, UPDATE 09 §5, T-146): every piece
## builds headless, adds geometry with materials, never adds a collider, never scales anything to zero; the
## instancer keeps one BakedMultiMesh per id; the flying-wing shell is a closed mesh and its surface function
## answers inside / outside the planform.

var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)


func _check_piece(n: Node, what: String) -> void:
	assert_not_null(n, "%s returns its node" % what)
	var meshes: int = 0
	var mms: int = 0
	for c: Node in root.find_children("*", "", true, false):
		assert_false(c is CollisionShape3D or c is PhysicsBody3D or c is Area3D, "%s adds no collision (%s)" % [what, c.name])
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			meshes += 1
			assert_not_null(mi.mesh, "%s: %s has a mesh" % [what, mi.name])
			assert_true(mi.material_override != null or (mi.mesh != null and mi.mesh.get_surface_count() > 0 and mi.mesh.surface_get_material(0) != null),
				"%s: %s has a material" % [what, mi.name])
		elif c is BakedMultiMesh:
			mms += 1
			var b: BakedMultiMesh = c
			assert_gt(b.transforms.size(), 0, "%s: %s holds instances" % [what, b.name])
			assert_not_null(b.material_override, "%s: %s has a material" % [what, b.name])
			for xf: Transform3D in b.transforms:
				_assert_scale(xf.basis, "%s instance in %s" % [what, b.name])
		if c is Node3D:
			_assert_scale((c as Node3D).transform.basis, "%s: %s" % [what, c.name])
	assert_gt(meshes + mms, 0, "%s adds geometry" % what)


func _assert_scale(bs: Basis, what: String) -> void:
	var ok: bool = bs.x.length() > 0.0001 and bs.y.length() > 0.0001 and bs.z.length() > 0.0001
	assert_true(ok, "%s keeps a non-zero scale" % what)


func test_structure_pieces() -> void:
	_check_piece(GenDetail.corrugated_sheet(root, Vector3(0, 0, 0), Vector3(6, 3, 0.04)), "corrugated_sheet")
	_check_piece(GenDetail.i_beam(root, Vector3(0, 4, 0), Vector3(8, 4, 2)), "i_beam")
	_check_piece(GenDetail.truss(root, Vector3(0, 6, 0), Vector3(20, 6, 0), 1.6), "truss")
	_check_piece(GenDetail.sawtooth_roof(root, Vector3(0, 8, 0), Vector3(20, 8, 24), 4, 2.5), "sawtooth_roof")
	_check_piece(GenDetail.rivet_strip(root, Vector3(0, 1, 0), Vector3(2, 1, 0)), "rivet_strip")
	_check_piece(GenDetail.pipe_run(root, PackedVector3Array([Vector3(0, 2, 0), Vector3(4, 2, 0), Vector3(4, 2, 3), Vector3(4, 4, 3)]), 0.06, "iron", 2.0, 1), "pipe_run")
	_check_piece(GenDetail.cable_tray(root, Vector3(0, 3, 0), Vector3(10, 3, 0)), "cable_tray")
	_check_piece(GenDetail.crane_gantry(root, -10.0, 10.0, 0.0, 9.0, "crane_yellow", 3.0, 4.0, 1), "crane_gantry")


func test_rails_sleepers_are_instanced() -> void:
	var track: Node3D = GenDetail.rails(root, Vector3(0, 0, 0), Vector3(20, 0, 0))
	_check_piece(track, "rails")
	var mm: BakedMultiMesh = root.get_node_or_null("MM_sleeper_beam") as BakedMultiMesh
	assert_not_null(mm, "the sleepers are one BakedMultiMesh under the parent")
	assert_between(mm.transforms.size(), 25, 35, "a sleeper every ~0.65 m over 20 m")
	assert_eq(mm.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "sleepers cast shadows")


func test_fences_and_railings() -> void:
	_check_piece(GenDetail.chain_link(root, Vector3(0, 0, 0), Vector3(0, 0, 10), 2.2, "iron", true), "chain_link")
	assert_not_null(root.get_node_or_null("MM_chainlink"), "the wire panels are instanced")
	_check_piece(GenDetail.railing(root, Vector3(0, 12, 0), Vector3(15, 12, 0)), "railing")


func test_surfaces_and_trim() -> void:
	GenDetail.form_board(root, Vector3(0, 0, 0), Vector3(6, 4, 0), Vector3(0, 0, -1))
	_check_piece(root.get_child(0), "form_board")
	assert_not_null(root.get_node_or_null("MM_tiehole"), "tie holes are instanced")
	_check_piece(GenDetail.trim(root, Vector3(0, 0, 0), Vector3(6, 0, 0), Vector3(0, 0, -1)), "trim")


func test_window_door_stairs_grating() -> void:
	var w: Node3D = GenDetail.window(root, Vector3(0, 1, 0), 0.0, 1.4, 1.6, {"curtain": "cloth_red", "lit": Color(1, 0.7, 0.4), "silhouette": true,
		"broken": 0.5, "shutters": true, "snow": true, "frost": true, "seed": 3})
	_check_piece(w, "window")
	assert_not_null(w.find_child("Silhouette", true, false), "a lit window can carry a silhouette")
	_check_piece(GenDetail.door(root, Vector3(4, 0, 0), 0.0, 1.2, 2.2, {"open_deg": 30.0, "sign": "BÜRO"}), "door")
	_check_piece(GenDetail.door(root, Vector3(8, 0, 0), 90.0, 2.0, 2.4, {"steel": true}), "steel door")
	_check_piece(GenDetail.stairs(root, Vector3(0, 0, 4), Vector3(0, 3, 8)), "stairs")
	_check_piece(GenDetail.grating(root, Vector3(0, 6, 0), Vector3(20, 6.05, 1.2)), "grating")


func test_paper_chalk_signs() -> void:
	_check_piece(GenDetail.poster(root, Vector3(0, 1.6, 0), 0.0, "WERKSKONZERT", "fictional wording"), "poster")
	_check_piece(GenDetail.enamel_sign(root, Vector3(1, 2, 0), 0.0, "KANTINE"), "enamel_sign")
	for k: String in ["jakub", "jakub_backwards", "tally", "x", "arrow", "hopscotch"]:
		var c: Node3D = GenDetail.chalk_mark(root, Vector3(0, 0, 2), 0.0, k, 0.4, k == "hopscotch")
		assert_not_null(c, "chalk %s builds" % k)
		assert_gte(c.get_child_count(), 2, "chalk %s has strokes" % k)
	_check_piece(root, "chalk")


func test_weathering_and_ground() -> void:
	for k: String in GenDetail.CARD_KINDS.keys():
		GenDetail.card(root, k, Vector3(0, 1, 0), Vector3.BACK, Vector2(1, 1))
		assert_not_null(root.get_node_or_null("MM_card_" + k), "card %s instanced" % k)
	GenDetail.card(root, "soot", Vector3(0, 0, 0), Vector3.UP, Vector2(2, 2))
	GenDetail.rust_streak(root, Vector3(0, 3, 0), Vector3.BACK)
	GenDetail.frost_patch(root, Vector3(0, 1, 0), Vector3.FORWARD)
	GenDetail.puddle(root, Vector3(2, 0, 2), 1.2, 0.8)
	_check_piece(GenDetail.snow_drift(root, Vector3(0, 0, 4), Vector3(3, 0.6, 1)), "snow_drift")
	_check_piece(GenDetail.sand_drift(root, Vector3(0, 0, 6), Vector3(3, 0.6, 1)), "sand_drift")
	_check_piece(GenDetail.crater(root, Vector3(10, 0, 10), 3.0, 7), "crater")
	_check_piece(GenDetail.washing_line(root, Vector3(0, 2.2, 0), Vector3(8, 2.2, 0)), "washing_line")
	var net: MeshInstance3D = GenDetail.camo_net(root, Vector3(0, 0, 0), Vector3(40, 12, 30), 0.8, 8.0, 2.0, "ns")
	_check_piece(net, "camo_net")
	assert_true(net.has_meta("keep"), "the netting stays out of the static batching (its shader drapes it)")
	_check_piece(GenDetail.fog_sheets(root, Vector3(0, 0, 0), Vector2(30, 20), 1.6, 3), "fog_sheets")


func test_lamp_fixtures_return_bulbs() -> void:
	for k: String in ["hanging", "wall", "flood", "pole"]:
		var bulb: Vector3 = GenDetail.lamp_fixture(root, Vector3(0, 5, 0), k, 90.0, 8.0)
		assert_true(bulb.distance_to(Vector3(0, 5, 0)) < 5.0, "%s's bulb is near its fixture" % k)
	_check_piece(root, "lamp fixtures")


func test_instancer_one_multimesh_per_id() -> void:
	for i: int in 5:
		GenDetail.instance(root, "probe", Props.unit_box(), Mats.get_mat("iron"), Transform3D(Basis.IDENTITY, Vector3(i, 0, 0)))
	var found: Array[Node] = root.find_children("MM_probe*", "", false, false)
	assert_eq(found.size(), 1, "one BakedMultiMesh per id")
	var mm: BakedMultiMesh = found[0] as BakedMultiMesh
	assert_eq(mm.transforms.size(), 5)
	assert_true(mm.has_meta("keep"), "kept out of the static batching")
	assert_eq(GenDetail.fill_instances(root), 1)
	assert_eq(mm.multimesh.instance_count, 5, "fill() sizes the MultiMesh from the stored transforms")


func test_flying_wing_surface_and_mesh() -> void:
	var p: Dictionary = {"span": 86.0, "le_root": 26.0, "t_root": 7.0, "t_tip": 3.6}
	var mid: Vector2 = GenDetail.wing_surface(0.0, 0.0, p)
	assert_gt(mid.x, mid.y, "inside the planform the top is above the bottom")
	assert_eq(GenDetail.wing_surface(0.0, 40.0, p), Vector2(-1, -1), "ahead of the leading edge is outside")
	assert_eq(GenDetail.wing_surface(50.0, 0.0, p), Vector2(-1, -1), "beyond the tip is outside")
	var m: ArrayMesh = GenDetail.flying_wing_mesh(p, 20, 12)
	assert_eq(m.get_surface_count(), 1, "one surface")
	var verts: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 1000, "a real hull, not a box")
	var aabb: AABB = m.get_aabb()
	assert_almost_eq(aabb.size.x, 86.0, 0.5, "spans the given span")
	_check_piece(GenDetail.wing_skeleton(root, Vector3(0, 2, 0), 0.0, 12.0, 4.0, 1.6, 0.4), "wing_skeleton")
	assert_gt(GenDetail.rib_mesh(0.12).get_surface_count(), 0, "the unit rib mesh builds")


func test_silhouette_is_flat_and_dark() -> void:
	var s: Node3D = GenDetail.silhouette(root, Vector3.ZERO, 0.0, 1.7)
	_check_piece(s, "silhouette")
	for c: Node in s.get_children():
		if c is MeshInstance3D:
			var mat: Material = (c as MeshInstance3D).material_override
			assert_eq(mat, Mats.get_mat("black_paint"), "a silhouette is a shape, not a person")
