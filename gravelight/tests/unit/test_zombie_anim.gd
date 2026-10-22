extends GutTest
## MZ zombie animation upgrade (T-041): anim.json shape, the shared rig and BoneMap, the baked clip library
## (root motion = tier speed), the skinned kits (no laborer), dismemberment on a live zombie, the gore setting.

var anim: Dictionary
var enemies: Dictionary


func before_all() -> void:
	anim = GLData.load_json("res://data/gravelight/anim.json")
	enemies = GLData.load_json("res://data/gravelight/enemies.json")


func test_anim_json_clip_counts() -> void:
	var loco: Dictionary = anim["clips"]["locomotion"]
	assert_eq((loco["shamble"] as Array).size(), 3)
	assert_eq((loco["walk"] as Array).size(), 3)
	assert_eq((loco["jog"] as Array).size(), 2)
	assert_eq((loco["run"] as Array).size(), 3)
	assert_eq((loco["sprint"] as Array).size(), 2)
	assert_eq((loco["crawl"] as Array).size(), 2)
	assert_gte((anim["clips"]["death"] as Array).size(), 8, "8+ authored deaths")
	assert_eq((anim["clips"]["attack"]["swipe"] as Array).size(), 4)
	assert_eq((anim["clips"]["tear"] as Array).size(), 3)
	assert_eq((anim["clips"]["vault"] as Array).size(), 2)
	assert_eq((anim["clips"]["emerge"]["ground"] as Array).size(), 2)
	assert_gte((anim["clips"]["postures"] as Array).size(), 6)
	for k: String in ["foot_ik", "look_at", "lod", "ragdoll", "gore", "kits", "builds", "footsteps", "knockdown"]:
		assert_true(anim.has(k), "anim.json has " + k)


func test_rig_is_humanoid_profile_with_bone_map() -> void:
	var names: PackedStringArray = ZombieRig.bone_names()
	for b: String in ["Root", "Hips", "Spine", "Chest", "Neck", "Head", "Jaw", "LeftUpperArm", "RightLowerArm", "LeftHand", "LeftUpperLeg", "RightLowerLeg", "LeftFoot", "RightFoot"]:
		assert_true(names.has(b), "rig has " + b)
	assert_gte(ZombieRig.mapped_profile_bones(), 15, "BoneMap covers the core humanoid profile bones")
	assert_eq(ZombieRig.legacy_name("sh_l"), "LeftUpperArm")
	assert_eq(ZombieRig.legacy_name("Head"), "Head")
	assert_eq(ZombieRig.parent_of("LeftFoot"), "LeftLowerLeg")
	var sk: Skeleton3D = ZombieRig.build_skeleton()
	assert_eq(sk.get_bone_count(), names.size())
	assert_eq(sk.get_bone_parent(sk.find_bone("Hips")), sk.find_bone("Root"))
	sk.free()


func test_clip_library_has_every_clip_and_root_motion_matches_tier_speed() -> void:
	var lib: AnimationLibrary = ZombieClips.library()
	for n: String in ZombieClips.all_clip_names():
		assert_true(lib.has_animation(n), "clip " + n)
	assert_true(lib.has_animation("walk_a_lean_l"))
	assert_true(lib.has_animation("posture_none"))
	var loco: Dictionary = anim["clips"]["locomotion"]
	for gait: String in ["shamble", "walk", "jog", "run", "sprint"]:
		var want: float = float(anim["gait"][gait]["speed"])
		for clip: String in loco[gait]:
			var a: Animation = lib.get_animation(clip)
			assert_eq(a.loop_mode, Animation.LOOP_LINEAR, clip + " loops")
			var ti: int = a.find_track(NodePath("Skel:Root"), Animation.TYPE_POSITION_3D)
			assert_gte(ti, 0, clip + " has a Root track")
			var end: Vector3 = a.position_track_interpolate(ti, a.length)
			var speed: float = end.length() / a.length
			assert_almost_eq(speed, want, want * 0.01, "%s root motion %.2f m/s vs tier %.2f" % [clip, speed, want])
			assert_lt(end.z, 0.0, clip + " moves forward (-Z)")
	var d: Animation = lib.get_animation("death_back")
	assert_eq(d.loop_mode, Animation.LOOP_NONE)
	assert_gt(d.length, 1.0)


func test_tree_root_has_every_state() -> void:
	var root: AnimationNodeBlendTree = ZombieClips.build_tree_root()
	var sm: AnimationNodeStateMachine = root.get_node("SM") as AnimationNodeStateMachine
	for s: String in ZombieClips.STATES:
		assert_true(sm.has_node(s), "state " + s)
	assert_true(root.has_node("Posture") and root.has_node("Flinch"))
	assert_true(sm.has_transition("Attack", "Locomotion"))
	assert_true(sm.has_transition("Death", "Locomotion"))
	assert_eq(ZombieClips.attack_index("swipe_l"), 0.0)
	assert_gt(ZombieClips.attack_index("crawl_bite"), 4.0)


func test_kits_skinned_and_laborer_retired() -> void:
	assert_false(ZombieBody.KITS.has("laborer"), "forced laborers are never zombies")
	assert_false((anim["kits"] as Dictionary).has("laborer"))
	var v: Dictionary = enemies["enemies"]["ganger"]["variants"]
	assert_false(v.has("laborer"))
	assert_true(v.has("villager"), "Map 0 villager kit takes the slot")
	var by_map: Dictionary = enemies["enemies"]["ganger"]["variants_by_map"]
	assert_true((by_map["map01_kaltenbrunn"] as Dictionary).has("technician"), "Map 1 technician kit")
	for m: String in by_map.keys():
		if m == "_doc":
			continue
		for kit: String in (by_map[m] as Dictionary).keys():
			assert_true((anim["kits"] as Dictionary).has(kit), "%s kit %s exists" % [m, kit])
	for kit: String in v.keys():
		assert_true((anim["kits"] as Dictionary).has(kit), "kit " + kit)
	var mesh: ArrayMesh = ZombieBody.build_skinned("villager", "medium", true)
	assert_eq(mesh.get_surface_count(), 2, "skin + kit surfaces (two draw calls per body)")
	var arrays: Array = mesh.surface_get_arrays(0)
	assert_false((arrays[Mesh.ARRAY_BONES] as PackedInt32Array).is_empty(), "skin surface is weighted")
	assert_eq((arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size(), (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 4)
	assert_true(mesh.surface_get_material(0) is ShaderMaterial, "the infection shader on the skin")
	assert_same(ZombieBody.build_skinned("villager", "medium", true), mesh, "cached per kit/build/sex")
	var piece: ArrayMesh = ZombieBody.piece_mesh("soldier", "medium", false, "LeftLowerArm")
	assert_gt(piece.get_surface_count(), 0)
	assert_eq(str(ZombieBody.gear_mesh("helmet")[0]), "Head")


func test_live_zombie_rig_tree_and_dismemberment() -> void:
	GLSettings.values["gore"] = "full"
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var z: Zombie = Zombie.new()
	host.add_child(z)
	assert_not_null(z.skeleton())
	assert_gt(z.skeleton().get_bone_count(), 15)
	assert_not_null(z.bone_attachment("LeftLowerArm"))
	assert_eq(z.bone_attachment("el_l"), z.bone_attachment("LeftLowerArm"), "legacy names map to the same attachment")
	var sp: ZombieSpawn = ZombieSpawn.new()
	sp.kind = &"ground"
	host.add_child(sp)
	z.activate({"enemy_id": "ganger", "tier": "run", "health": 300, "variant": "miner"}, sp, null)
	assert_eq(z.state, Zombie.State.EMERGE)
	assert_eq(z.kit_name(), "miner")
	assert_eq(z.arms_lost(), 0)
	z.sever_limb("LeftLowerArm")
	assert_true(z.is_severed("LeftLowerArm"))
	assert_eq(z.arms_lost(), 1)
	var bi: int = z.skeleton().find_bone("LeftHand")
	assert_lt(z.skeleton().get_bone_pose_scale(bi).x, 0.01, "the chain under a severed bone collapses")
	z.sever_limb("RightUpperArm")
	assert_eq(z.arms_lost(), 2)
	assert_eq(z._pick_attack(), "headbutt", "armless zombies headbutt")
	# the pool reuses the body clean
	z.deactivate()
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 150, "variant": "villager"}, sp, null)
	assert_false(z.is_severed("LeftLowerArm"))
	assert_eq(z.skeleton().get_bone_pose_scale(bi), Vector3.ONE)
	assert_eq(z.arms_lost(), 0)
	# gore off: the limb stays on, the gameplay side still counts
	GLSettings.values["gore"] = "off"
	z.sever_limb("LeftLowerArm")
	assert_false(z.is_severed("LeftLowerArm"), "gore off keeps the limb")
	assert_eq(z.arms_lost(), 1, "...but the attack set changes")
	GLSettings.values["gore"] = "full"
	z.deactivate()


func test_gore_setting_default() -> void:
	assert_eq(str(GLSettings.values.get("gore", "")), "full")
