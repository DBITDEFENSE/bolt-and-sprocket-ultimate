extends GutTest
## T-092 (UPDATE_05 section 4): the named people's modelled bodies (assets/ours/characters/people, built by
## tools/build_people.sh; PeopleBodies, PersonRig, FaceDriver). Every person in people.json builds into the
## two-surface skinned mesh with the face blend shapes and mesh LODs inside the hero budget, every bone influence names
## a rig bone, the shapes really move the face, the puppet's pose lands the hands on their targets and the feet on
## the floor, the face driver blinks / holds expressions / flaps the lips on the person's VO lines, and nothing about
## gameplay moved: RemoteBody and PatronBody still carry no collision, the Cousins keep the same skeleton, hitboxes
## (bone, limb, size, place) and pose layer whether they wear the modelled doll or the legacy primitives.

const HERO_TRIS: int = 15000


func after_each() -> void:
	PeopleBodies.legacy = false


func _tris(m: ArrayMesh) -> int:
	var n: int = 0
	for s: int in m.get_surface_count():
		n += (m.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


func test_every_person_has_a_glb_and_builds() -> void:
	var ids: PackedStringArray = PeopleBodies.ids()
	assert_eq(ids.size(), 16, "squad 4 + Jakub + 5 patrons + 3 survivors + 3 Cousins")
	for id: String in ids:
		assert_true(PeopleBodies.available(id), id + ": GLB built and imported")
		var m: ArrayMesh = PeopleBodies.mesh(id)
		assert_not_null(m, id + " merges")
		if m == null:
			continue
		assert_eq(m.get_surface_count(), 2, id + ": skin + kit (two draw calls)")
		assert_true(m.surface_get_material(0) is ShaderMaterial, id + ": the skin shader")
		assert_same(m.surface_get_material(1), ZombieBody.kit_material(), id + ": the shared kit material")
		assert_lte(_tris(m), HERO_TRIS, id + ": inside the hero budget (ART_BIBLE section 5)")
		var lods: Array = m.get_meta("lod_counts", [0, 0])
		assert_gt(int(lods[0]), 0, id + ": skin LODs")
		assert_gt(int(lods[1]), 0, id + ": kit LODs")


func test_blend_shapes_are_the_face_set() -> void:
	var want: PackedStringArray = PeopleBodies.shape_names()
	assert_eq(want, PackedStringArray(["blink", "jaw_open", "fear", "determined", "pain", "smile"]))
	for id: String in PeopleBodies.ids():
		var m: ArrayMesh = PeopleBodies.mesh(id)
		assert_eq(m.get_blend_shape_count(), want.size(), id + ": every shape")
		for i: int in want.size():
			assert_eq(String(m.get_blend_shape_name(i)), want[i], id + " shape %d" % i)


## Largest displacement a shape makes on a surface (metres).
func _moves(m: ArrayMesh, surf: int, shape: int) -> float:
	var base: PackedVector3Array = m.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX]
	var bs: Array = m.surface_get_blend_shape_arrays(surf)
	var tgt: PackedVector3Array = (bs[shape] as Array)[Mesh.ARRAY_VERTEX]
	var mx: float = 0.0
	for i: int in base.size():
		mx = maxf(mx, (tgt[i] - base[i]).length())
	return mx


func test_the_shapes_move_the_face_and_only_the_face() -> void:
	for id: String in ["dutch", "wren", "jakub", "cousin_alix"]:
		var m: ArrayMesh = PeopleBodies.mesh(id)
		var names: PackedStringArray = PeopleBodies.shape_names()
		assert_gt(_moves(m, 1, names.find("blink")), 0.008, id + ": the lids close")
		assert_gt(_moves(m, 0, names.find("jaw_open")), 0.012, id + ": the jaw drops")
		assert_gt(_moves(m, 1, names.find("fear")), 0.006, id + ": fear lifts the brows")
		assert_gt(_moves(m, 1, names.find("determined")), 0.004, id + ": determined knits them")
		assert_gt(_moves(m, 0, names.find("smile")), 0.003, id + ": the mouth corners rise")
		# nothing below the neck moves
		var base: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bs: Array = m.surface_get_blend_shape_arrays(0)
		var low: float = 0.0
		for si: int in bs.size():
			var tgt: PackedVector3Array = (bs[si] as Array)[Mesh.ARRAY_VERTEX]
			for i: int in base.size():
				if base[i].y < 1.45:
					low = maxf(low, (tgt[i] - base[i]).length())
		assert_lt(low, 0.0005, id + ": no shape moves the body")


func test_bone_weights_only_name_rig_bones() -> void:
	var nb: int = ZombieRig.bone_names().size()
	for id: String in PeopleBodies.ids():
		var m: ArrayMesh = PeopleBodies.mesh(id)
		for s: int in m.get_surface_count():
			var a: Array = m.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var stride: int = bones.size() / maxi(1, v.size())
			var bad: int = 0
			var badsum: int = 0
			for i: int in v.size():
				var sum: float = 0.0
				for k: int in stride:
					sum += w[i * stride + k]
					if w[i * stride + k] > 0.0 and (bones[i * stride + k] < 0 or bones[i * stride + k] >= nb):
						bad += 1
				if absf(sum - 1.0) > 0.02:
					badsum += 1
			assert_eq(bad, 0, "%s surface %d: every influence names a rig bone" % [id, s])
			assert_eq(badsum, 0, "%s surface %d: weights sum to 1" % [id, s])


func test_risen_person_wears_the_infection_and_the_glow() -> void:
	var m: ArrayMesh = PeopleBodies.mesh("kubiak", true)
	var sm: ShaderMaterial = m.surface_get_material(0) as ShaderMaterial
	assert_same(sm.shader, ZombieBody.skin_shader(), "the infection shader on the skin")
	assert_gt(float(sm.get_shader_parameter("crack_energy")), 0.0, "with its cracks")
	assert_gt(float(sm.get_shader_parameter("vein_energy")), 0.0, "and veins")
	var c0: PackedFloat32Array = m.surface_get_arrays(1)[Mesh.ARRAY_CUSTOM0]
	var glow: int = 0
	for i: int in range(2, c0.size(), 4):
		if c0[i] > 1.0:
			glow += 1
	assert_gt(glow, 50, "the eyes glow violet")
	var living: PackedFloat32Array = PeopleBodies.mesh("kubiak").surface_get_arrays(1)[Mesh.ARRAY_CUSTOM0]
	var lg: int = 0
	for i2: int in range(2, living.size(), 4):
		if living[i2] > 1.0:
			lg += 1
	assert_eq(lg, 0, "the living don't glow")


func test_legacy_switch_keeps_the_primitives() -> void:
	PeopleBodies.legacy = true
	assert_false(PeopleBodies.available("dutch"))
	var b: RemoteBody = RemoteBody.new()
	add_child_autofree(b)
	b.setup(&"dutch", 41)
	assert_null(b.person, "legacy: the primitive soldier")


func test_person_rig_lands_hands_and_feet() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var r: PersonRig = PersonRig.new()
	host.add_child(r)
	assert_true(r.setup("peg"))
	var hand_r: Vector3 = Vector3(0.12, 1.42, -0.32)
	var hand_l: Vector3 = Vector3(0.05, 1.4, -0.5)
	r.drive({"hips": Vector3(0, 0.95, 0), "chest": Basis.IDENTITY, "head": Basis.IDENTITY,
		"legs": [[0.0, 0.0, 0.0], [0.3, -0.5, 0.0]], "hands": [hand_l, hand_r],
		"poles": [Vector3(-0.6, -1.0, 0.3), Vector3(0.6, -1.0, 0.3)], "plant": true})
	# the hand bone sits at the wrist: within a few cm of the target once the IK reached it
	assert_almost_eq(r.bone_world("RightHand").distance_to(hand_r), 0.0, 0.03, "right hand on the grip")
	assert_almost_eq(r.bone_world("LeftHand").distance_to(hand_l), 0.0, 0.03, "left hand on the fore-end")
	var foot_y: float = minf(r.bone_world("LeftFoot").y, r.bone_world("RightFoot").y)
	assert_almost_eq(foot_y, 0.07 * r.scale_k, 0.03, "the planted foot's ankle at its rest height: sole on the floor")


func test_face_driver_blinks_holds_and_talks() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var r: PersonRig = PersonRig.new()
	host.add_child(r)
	r.setup("deacon")
	var fd: FaceDriver = r.face
	assert_true(fd.has_shapes())
	assert_eq(fd.speakers, PackedStringArray(["DEA"]))
	fd.set_expression(&"fear")
	for i: int in 30:
		fd.step(0.05)
	assert_gt(fd.applied("fear"), 0.95, "fear held")
	fd.set_expression(&"pain")
	for i2: int in 30:
		fd.step(0.05)
	assert_lt(fd.applied("fear"), 0.05, "eased out")
	assert_gt(fd.applied("pain"), 0.95, "pain held")
	# a blink within the person's blink range
	fd.set_expression(&"neutral")
	var closed: bool = false
	for i3: int in 200:
		fd.step(0.05)
		if fd.applied("blink") > 0.5:
			closed = true
	assert_true(closed, "blinked within 10 s")
	# lip flap on his own line, not on someone else's
	GLBus.vo_line_started.emit(&"x", &"DUT", "Somebody else talking here.", 2.0)
	assert_false(fd.talking, "not his line")
	GLBus.vo_line_started.emit(&"y", &"DEA", "Steady now, brother, steady.", 2.0)
	assert_true(fd.talking)
	var open_max: float = 0.0
	for i4: int in 30:
		fd.step(0.05)
		open_max = maxf(open_max, fd.applied("jaw_open"))
	assert_gt(open_max, 0.2, "the jaw moves while he speaks")
	for i5: int in 60:
		fd.step(0.05)
	assert_false(fd.talking, "stops with the line")
	assert_eq(FaceDriver.syllables("Bolt-actions, please."), 5)


func test_alix_never_blinks() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var r: PersonRig = PersonRig.new()
	host.add_child(r)
	r.setup("cousin_alix")
	for i: int in 400:
		r.face.step(0.05)
		assert_lt(r.face.applied("blink"), 0.01)
		if r.face.applied("blink") >= 0.01:
			break


func test_remote_body_draws_the_person_with_no_collision() -> void:
	for ch: StringName in [&"dutch", &"peg", &"deacon", &"wren", &"jakub"]:
		var b: RemoteBody = RemoteBody.new()
		add_child_autofree(b)
		b.setup(ch, 40)
		assert_not_null(b.person, String(ch) + ": modelled body")
		assert_eq(b.person.person_id, String(ch))
		assert_eq(b.find_children("*", "CollisionObject3D", true, false).size(), 0, String(ch) + ": still no collider (gameplay unchanged)")
		b.update_pose(1.0 / 60.0, 2.0, 0.1, NetMatch.PF_DOWNED)
		assert_eq(b.person.face.expression, &"pain", String(ch) + ": downed = pain")
	var j: RemoteBody = RemoteBody.new()
	add_child_autofree(j)
	j.setup(&"jakub", 9)
	j.set_wounded(true)
	var band: Node3D = j.find_child("Bandage", true, false) as Node3D
	assert_not_null(band)
	assert_true(band.visible, "the bandage shows")
	assert_true(band.get_parent() is BoneAttachment3D, "on the head bone")


func test_patron_and_survivor_bodies_are_modelled() -> void:
	for id: String in ["rother", "kubiak", "pohl", "trudi", "sobotta", "wiesner", "brandt", "kroll"]:
		var pb: PatronBody = PatronBody.new()
		add_child_autofree(pb)
		pb.setup({"id": id, "pose": "sit"})
		assert_not_null(pb.person, id + ": modelled body")
		assert_eq(pb.find_children("*", "CollisionObject3D", true, false).size(), 0, id + ": no collider")
		pb.set_pose(&"panic")
		pb._process(0.05)
		assert_eq(pb.person.face.expression, &"fear", id + ": panic = fear")


func _hitbox_sig(z: Zombie) -> Array:
	var out: Array = []
	for hb: Hitbox in z.get("_hitboxes"):
		var cs: CollisionShape3D = hb.get_child(0) as CollisionShape3D
		var size: Vector3 = (cs.shape as BoxShape3D).size if cs != null and cs.shape is BoxShape3D else Vector3.ZERO
		out.append([hb.bone, hb.limb, size, hb.position])
	return out


func test_cousins_keep_their_rig_hitboxes_and_pose_layer() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	for key: String in ["hammer", "reach", "alix"]:
		var sigs: Array = []
		for legacy: bool in [false, true]:
			PeopleBodies.legacy = legacy
			var hb: HomageBoss = CousinHammer.new() if key == "hammer" else (CousinReach.new() if key == "reach" else CousinAlix.new())
			host.add_child(hb)
			hb.spawn_homage(Vector3.ZERO, 1000.0)
			assert_eq(hb.modelled(), not legacy, key + " modelled when not legacy")
			var sk: Skeleton3D = hb.skeleton()
			assert_eq(sk.get_bone_count(), ZombieRig.bone_names().size(), key + ": the same skeleton")
			for b: String in ZombieRig.bone_names():
				assert_gt(sk.find_bone(b) + 1, 0, "%s keeps bone %s" % [key, b])
			assert_not_null(sk.get_node_or_null("HomagePose"), key + ": the pose layer is on the skeleton")
			var body: MeshInstance3D = hb.get("_body") as MeshInstance3D
			if not legacy:
				assert_eq(str(body.mesh.get_meta("person", "")), "cousin_" + key, key + ": wears her doll")
				assert_not_null(hb.face, key + ": a face driver")
			sigs.append(_hitbox_sig(hb))
			hb.cleanup()
			hb.queue_free()
		assert_eq(sigs[0], sigs[1], key + ": hitboxes identical with the modelled and the legacy body")
	PeopleBodies.legacy = false
