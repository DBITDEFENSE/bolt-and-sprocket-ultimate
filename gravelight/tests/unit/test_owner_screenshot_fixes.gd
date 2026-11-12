extends GutTest
## 2026-11-12, the owner's screenshots of the Inn: white smears down the extra people (the chalk X decal under their
## feet painted down their clothes), wall-buy guns hanging off their boards. The renders under WSL use the
## Compatibility renderer, which draws no decals, so the decal half is pinned here.


func test_the_chalk_x_decal_stays_on_the_floor_and_off_people() -> void:
	var wm: WorldMarks = WorldMarks.new()
	add_child_autofree(wm)
	var it: Dictionary = wm._make({"id": 1, "pos": Vector3.ZERO, "kind": "note"})
	var d: Decal = it.get("decal") as Decal
	assert_not_null(d, "GRAVELIGHT draws a chalk decal")
	if d == null:
		return
	assert_true(d.size.y <= 1.7, "the projector reaches a few treads, not a standing body (was 2.4 m)")
	assert_true(d.normal_fade >= 0.5, "it skips faces that are not floor-like")
	assert_eq(d.cull_mask & PersonRig.CHAR_LAYER, 0, "it leaves the people's render layer out")
	assert_eq(WorldMarks.CHAR_LAYER, PersonRig.CHAR_LAYER, "core's copy of the layer matches PersonRig's")


func test_a_person_body_draws_on_the_character_layer_only() -> void:
	var pb: PatronBody = PatronBody.new()
	add_child_autofree(pb)
	pb.setup({"id": "probe", "person": "pohl", "pose": "stand", "look": {}})
	if pb.person == null:
		pending("no built GLB for pohl in this checkout")
		return
	assert_eq(pb.person.body.layers, PersonRig.CHAR_LAYER)


func test_wall_buy_chalk_and_gun_sit_inside_the_board() -> void:
	var board: Mesh = WorldArt.part_mesh("wall_mount", "Board")
	if board == null:
		pending("the painted board is not built in this checkout")
		return
	var half: float = board.get_aabb().size.x * 0.5
	for wid: StringName in [&"kar98k", &"m1_garand", &"bar", &"gewehr43", &"mp40", &"thompson"]:
		var wb: WallBuy = WallBuy.new()
		wb.weapon_id = wid
		add_child_autofree(wb)
		var gun: Node3D = wb.get_node_or_null("MountedGun") as Node3D
		assert_not_null(gun, "%s has its gun mounted" % wid)
		if gun == null:
			continue
		var ga: AABB = gun.transform * WorldArt.local_aabb(gun)
		assert_true(ga.position.x >= -half and ga.end.x <= half, "%s: the gun (%.2f..%.2f) stays on the %.2f m board" % [wid, ga.position.x, ga.end.x, half * 2.0])
		assert_almost_eq(ga.get_center().x, 0.0, 0.05, "%s is centred on the board" % wid)
