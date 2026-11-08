extends GutTest
## T-210 (UPDATE 12 section 4): the Godot side of the phone-mocap pipeline and the lip sync.
##   - a clip JSON (the pipeline's output for the synthetic walk, tests/data/mocap/sample_walk.clip.json) becomes an
##     Animation with a Hips position track and a rotation track per driven bone;
##   - the lookup misses cleanly (no library, no clip: the stand-in animation stays) and walks the role chain;
##   - MocapModifier writes the clip's pose and keeps a root-motion body where the shot began when the node moves;
##   - in a real reel (GRAVELIGHT ONE) a C-47 passenger with a clip plays it and one without keeps its stand-in pose;
##   - shots.json matches the cutscene data (durations, keys), the endings carry their mocap keys;
##   - every in-engine cutscene line has mouth cues that end within 0.1 s of its take; FaceDriver follows them; a
##     head with no blend shapes opens its Jaw bone, the same way the jaw_open shape opens (a -X turn: the MZ
##     slack-jaw keys turn it +X).

const CLIP: String = "res://tests/data/mocap/sample_walk.clip.json"


func after_each() -> void:
	MocapLibrary.overrides.clear()
	MocapLibrary.reload()
	MocapLibrary.enabled = true
	LipSync.enabled = true
	Campaign.cutscene_speed = 1.0


func _clip() -> Dictionary:
	return GLData.load_json(CLIP)


func _lib(names: Array) -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	var a: Animation = MocapLibrary.animation_from_clip(_clip())
	for n: Variant in names:
		lib.add_animation(StringName(str(n)), a)
	return lib


func _skeleton() -> Skeleton3D:
	var sk: Skeleton3D = ZombieRig.build_skeleton()
	add_child_autofree(sk)
	return sk


# ---------------------------------------------------------------- the clip

func test_a_clip_becomes_an_animation() -> void:
	var d: Dictionary = _clip()
	var a: Animation = MocapLibrary.animation_from_clip(d)
	assert_almost_eq(a.length, 3.0, 0.05, "trimmed to the shot's 3 s")
	var tr: Dictionary = MocapLibrary.tracks_of(a)
	assert_eq(tr.size(), 18, "the Hips position + 17 bone rotations")
	assert_true(tr.values().has("LeftFoot") and tr.values().has("Head"), "the driven bones")
	assert_eq(a.track_get_type(0), Animation.TYPE_POSITION_3D)
	var p0: Vector3 = a.position_track_interpolate(0, 0.0)
	var p1: Vector3 = a.position_track_interpolate(0, a.length)
	assert_almost_eq(Vector2(p0.x, p0.z).length(), 0.0, 0.01, "the walk starts on the mark")
	assert_lt(p1.z, -2.5, "and walks forward (-Z) about 3.5 m in 3 s")
	assert_almost_eq(p0.y, 0.95, 0.08, "hips at the rig's height")
	var stats: Dictionary = a.get_meta(&"stats", {})
	assert_lt(float(stats.get("slide_after", 1.0)), float(stats.get("slide_before", 0.0)) * 0.3, "the foot lock took the slide out")


func test_the_lookup_misses_cleanly_and_walks_the_roles() -> void:
	assert_null(MocapLibrary.library("gravelight_one"), "no captures yet: no library (the stand-in animation plays)")
	assert_null(MocapLibrary.clip("gravelight_one", "shot_02", ["dutch", "seat1", "any"]))
	MocapLibrary.overrides["gravelight_one"] = _lib(["shot_02_seat1", "shot_02_any"])
	assert_not_null(MocapLibrary.clip("gravelight_one", "shot_02", ["dutch", "seat1"]), "the seat when the character has none")
	assert_not_null(MocapLibrary.clip("gravelight_one", "shot_02", ["dutch", "any"]), "any for everyone else")
	assert_null(MocapLibrary.clip("gravelight_one", "shot_03", ["dutch", "seat1", "any"]), "another shot has nothing")
	MocapLibrary.enabled = false
	assert_null(MocapLibrary.clip("gravelight_one", "shot_02", ["seat1"]), "switched off: every lookup misses")


# ---------------------------------------------------------------- the modifier

func test_the_modifier_writes_the_clip_pose() -> void:
	var sk: Skeleton3D = _skeleton()
	var a: Animation = MocapLibrary.animation_from_clip(_clip())
	var m: MocapModifier = MocapModifier.attach(sk, a, "test:shot_01", null, 0.0)
	m.at(1.2)
	m.apply(1.2)
	var tr: Dictionary = MocapLibrary.tracks_of(a)
	for t: Variant in tr.keys():
		if a.track_get_type(int(t)) != Animation.TYPE_ROTATION_3D or str(tr[t]) == "Hips":
			continue
		var want: Quaternion = a.rotation_track_interpolate(int(t), 1.2)
		var got: Quaternion = sk.get_bone_pose_rotation(sk.find_bone(str(tr[t])))
		assert_almost_eq(absf(want.dot(got)), 1.0, 1e-4, "%s follows the clip" % str(tr[t]))
	assert_almost_eq(sk.get_bone_pose_position(sk.find_bone("Hips")).y, a.position_track_interpolate(0, 1.2).y, 1e-4)


func test_root_motion_stays_where_the_shot_began() -> void:
	var holder: Node3D = Node3D.new()
	add_child_autofree(holder)
	var sk: Skeleton3D = ZombieRig.build_skeleton()
	holder.add_child(sk)
	var a: Animation = MocapLibrary.animation_from_clip(_clip())
	var m: MocapModifier = MocapModifier.attach(sk, a, "test:shot_01", null, 0.0)
	m.apply(1.0)
	var hb: int = sk.find_bone("Hips")
	var world_a: Vector3 = sk.global_transform * sk.get_bone_pose_position(hb)
	holder.global_position += Vector3(2.0, 0.0, -3.0)   # the cast walks the node on its own path
	holder.rotation.y = 0.7
	m.apply(1.0)
	var world_b: Vector3 = sk.global_transform * sk.get_bone_pose_position(hb)
	assert_almost_eq(world_a.distance_to(world_b), 0.0, 1e-3, "the take, not the node, places the body")
	m.face(PI * 0.5)   # turned to face +X... the walk then goes along -X
	m.apply(2.5)
	var w: Vector3 = sk.global_transform * sk.get_bone_pose_position(hb)
	assert_lt(w.x - m.start_xf.origin.x, -1.5, "a start facing turns the whole path")


func test_in_place_clips_loop_and_leave_the_path_to_the_cast() -> void:
	var sk: Skeleton3D = _skeleton()
	var d: Dictionary = _clip()
	d["root"] = "cast"
	var a: Animation = MocapLibrary.animation_from_clip(d)
	var m: MocapModifier = MocapModifier.attach(sk, a, "test:shot_01", null, 0.0)
	assert_true(m.in_place)
	m.apply(2.0)
	var p: Vector3 = sk.get_bone_pose_position(sk.find_bone("Hips"))
	assert_almost_eq(Vector2(p.x, p.z).length(), 0.0, 0.01, "no root travel: the node walks")
	m.apply(2.0 + a.length)
	var q1: Quaternion = sk.get_bone_pose_rotation(sk.find_bone("LeftUpperLeg"))
	m.apply(2.0)
	var q2: Quaternion = sk.get_bone_pose_rotation(sk.find_bone("LeftUpperLeg"))
	assert_almost_eq(absf(q1.dot(q2)), 1.0, 1e-3, "it loops")


# ---------------------------------------------------------------- the stage hook

func test_a_reel_prefers_the_clip_and_falls_back_without_one() -> void:
	MocapLibrary.overrides["gravelight_one"] = _lib(["shot_02_seat1"])
	var r: CinemaReel = CinemaReel.play(self, ["gravelight_one"], {"speed": 1.0, "roster": ["dutch", "peg", "deacon", "wren"]})
	await wait_frames(2)
	r.fast_forward(7.0)   # into shot 2 (6.0 - 16.0)
	var p0: CinemaPerson = r.stage.find_child("Passenger_0", true, false) as CinemaPerson
	var p1: CinemaPerson = r.stage.find_child("Passenger_1", true, false) as CinemaPerson
	assert_not_null(p0)
	assert_eq(MocapStage.scene_id(r.director), "gravelight_one", "the reel's cut is the scene")
	assert_eq(MocapStage.roles_of(p0), ["dutch", "seat1", "any"], "the window seat's roles")
	var m: MocapModifier = p0.person.skeleton.get_node_or_null("Mocap") as MocapModifier
	assert_not_null(m, "seat 1 has a take for shot 2: it plays")
	if m != null:
		assert_eq(m.key, "gravelight_one:shot_02")
		assert_almost_eq(m.clip_time(), 1.0, 0.15, "on the director's clock")
	assert_null(p1.person.skeleton.get_node_or_null("Mocap"), "seat 2 has none: the stand-in pose stays")
	r.fast_forward(17.0)   # shot 3: no take for anyone
	assert_null(p0.person.skeleton.get_node_or_null("Mocap"), "the next shot without a take: back to the stand-in")
	r.skip_current()
	await wait_seconds(1.4)


func test_shot_keys_and_scene_ids() -> void:
	var d: CinemaDirector = CinemaDirector.make(self, {"seconds": 10.0, "mocap_scene": "cancel_ending", "shots": []}, null, {"cast": false, "auto": false, "hide_hud": false})
	assert_eq(MocapStage.scene_id(d), "cancel_ending", "a script-driven ending names itself")
	var s: CinemaShot = d.play_shot({"from": [0, 1, 4], "look": [0, 1, 0], "mocap": "last"}, 2.0)
	assert_eq(MocapStage.shot_key(d, s), "last")
	var s2: CinemaShot = d.play_shot({"from": [0, 1, 4], "look": [0, 1, 0]}, 2.0)
	assert_eq(MocapStage.shot_key(d, s2), "shot_02", "else its place in the timeline")
	d.queue_free()
	var src: String = FileAccess.get_file_as_string("res://gravelight/world/endings/cancel_ending.gd")
	for k: String in ["\"mocap_scene\": \"cancel_ending\"", "\"mocap\": \"key\"", "\"mocap\": \"earth\"", "\"mocap\": \"last\"", "\"mocap\": \"credits\""]:
		assert_true(src.contains(k), "cancel_ending carries %s" % k)
	var src2: String = FileAccess.get_file_as_string("res://gravelight/world/requiem_ending.gd")
	for k2: String in ["\"mocap_scene\": \"requiem_ending\"", "\"mocap\": \"heart\"", "\"mocap\": \"faces\"", "\"mocap\": \"montage\"", "\"mocap\": \"peg\""]:
		assert_true(src2.contains(k2), "requiem_ending carries %s" % k2)


func test_shots_json_matches_the_cutscenes() -> void:
	var data: Dictionary = GLData.load_json("res://data/gravelight/mocap/shots.json")
	var defs: Dictionary = (Campaign.cfg().get("cutscenes", {}) as Dictionary).duplicate()
	defs.merge(CinemaLibrary.data().get("cutscenes", {}))
	for sc: Variant in data["scenes"]:
		var scene: Dictionary = sc
		if str(scene["kind"]) != "timeline":
			continue
		assert_true(defs.has(scene["id"]), "%s is a cutscene" % str(scene["id"]))
		var shots: Array = (defs.get(scene["id"], {}) as Dictionary).get("shots", [])
		var secs: float = float((defs.get(scene["id"], {}) as Dictionary).get("seconds", 0.0))
		for sh: Variant in scene["shots"]:
			var i: int = int(str(sh["id"]).trim_prefix("shot_")) - 1
			assert_true(i >= 0 and i < shots.size(), "%s %s exists" % [str(scene["id"]), str(sh["id"])])
			if i < 0 or i >= shots.size():
				continue
			var end_t: float = float(shots[i + 1]["t"]) if i + 1 < shots.size() else secs
			assert_almost_eq(float(sh["dur"]), end_t - float(shots[i]["t"]), 0.05, "%s %s lasts as long as the shot" % [str(scene["id"]), str(sh["id"])])


# ---------------------------------------------------------------- the lip sync

func test_every_cutscene_line_has_cues_ending_with_its_take() -> void:
	var man: Dictionary = (GLData.load_json("res://data/gravelight/vo/audio_manifest.json") as Dictionary).get("files", {})
	var ids: Array = []
	for id: String in CinemaLibrary.line_ids(CinemaLibrary.def("gravelight_one")):
		ids.append(id)
	for id2: String in ["SEL_GL1_04", "REI_END_02", "WRN_M4D_END_01", "DUT_M4D_LASTWORD_01", "DEA_M4B_AUTOPILOT_02"]:
		ids.append(id2)
	for id3: Variant in ids:
		var c: Array = LipSync.cues(str(id3))
		assert_false(c.is_empty(), "%s has mouth cues" % str(id3))
		if c.is_empty() or not man.has(str(id3)):
			continue
		var dur: float = float((man[str(id3)] as Dictionary).get("duration", 0.0))
		assert_almost_eq(LipSync.length_of(c), dur, 0.1, "%s: the cues end with the take (%.2f s)" % [str(id3), dur])


func test_the_mouth_shapes() -> void:
	var c: Array = [[0.0, "X"], [0.1, "D"], [0.3, "A"], [0.5, "B"], [0.8, "X"]]
	assert_eq(LipSync.shape_at(c, 0.05), "X")
	assert_eq(LipSync.shape_at(c, 0.2), "D")
	assert_eq(LipSync.shape_at(c, 0.79), "B")
	assert_eq(LipSync.shape_at(c, 0.9), "X", "past the end: rest")
	assert_gt(LipSync.mouth_at(c, 0.25).x, 0.7, "D is wide open")
	assert_almost_eq(LipSync.mouth_at(c, 0.4).x, 0.0, 0.001, "A is closed")
	var mid: float = LipSync.mouth_at(c, 0.13).x
	assert_true(mid > 0.0 and mid < 0.75, "eased in from the shape before")
	assert_gt(LipSync.mouth_at(c, 0.7).y, 0.2, "B pulls the corners out")


func test_the_face_follows_the_cues() -> void:
	if not PeopleBodies.available("dutch"):
		pending("no built people GLB")
		return
	var rig: PersonRig = PersonRig.new()
	add_child_autofree(rig)
	assert_true(rig.setup("dutch"))
	var fd: FaceDriver = rig.face
	assert_true(fd.has_shapes())
	var c: Array = LipSync.cues("DUT_GL1_01")
	assert_false(c.is_empty())
	GLBus.vo_line_started.emit(&"DUT_GL1_01", &"DUT", "That ain't a parade down there.", LipSync.length_of(c))
	var t: float = 0.0
	var open_seen: float = 0.0
	var closed_seen: float = 1.0
	while t < 4.0:
		fd.step(1.0 / 60.0)
		t += 1.0 / 60.0
		var j: float = fd.applied("jaw_open")
		open_seen = maxf(open_seen, j)
		if LipSync.shape_at(c, t - 0.06) == "A" and LipSync.shape_at(c, t) == "A":
			closed_seen = minf(closed_seen, j)
	assert_gt(open_seen, 0.3, "the jaw opens on the open shapes")
	assert_lt(closed_seen, 0.2, "and closes on M / B / P")
	LipSync.enabled = false
	LipSync.clear_cache()
	assert_true(LipSync.cues("DUT_GL1_01").is_empty(), "switched off: the old flap")
	LipSync.enabled = true


func test_a_head_without_shapes_speaks_with_the_jaw_bone() -> void:
	var sk: Skeleton3D = _skeleton()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	sk.add_child(mi)
	var fd: FaceDriver = FaceDriver.new()
	fd.mesh = mi
	fd.speakers.append("DUT")
	mi.add_child(fd)
	await wait_frames(1)
	assert_false(fd.has_shapes())
	GLBus.vo_line_started.emit(&"DUT_GL1_01", &"DUT", "That ain't a parade down there.", 5.68)
	for i: int in 30:
		fd._process(1.0 / 60.0)
	var b: LipSyncBones = sk.get_node_or_null("LipSyncBones") as LipSyncBones
	assert_not_null(b, "the bone fallback came on")
	if b != null:
		var seen: float = 0.0
		for j: int in 60:
			fd._process(1.0 / 60.0)
			seen = maxf(seen, b.jaw)
		assert_gt(seen, 0.2, "the jaw moves on the cues")


func test_the_jaw_bone_opens_the_way_the_jaw_open_shape_does() -> void:
	if not PeopleBodies.available("dutch"):
		pending("no built people GLB")
		return
	var m: ArrayMesh = PeopleBodies.mesh("dutch")
	var si: int = -1
	for i: int in m.get_blend_shape_count():
		if str(m.get_blend_shape_name(i)) == "jaw_open":
			si = i
	assert_gt(si, -1, "the people carry jaw_open")
	if si < 0:
		return
	var arr: Array = m.surface_get_arrays(0)
	var shp: PackedVector3Array = ((m.surface_get_blend_shape_arrays(0) as Array)[si] as Array)[Mesh.ARRAY_VERTEX]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per: int = bones.size() / maxi(1, verts.size())
	var jaw_i: int = ZombieRig.bone_index("Jaw")
	var hinge: Vector3 = ZombieRig.rest_global("Jaw").origin
	var agree: float = 0.0
	var n: int = 0
	for v: int in verts.size():
		var w: float = 0.0
		for k: int in per:
			if bones[v * per + k] == jaw_i:
				w += weights[v * per + k]
		if w < 0.6:
			continue
		var d_shape: Vector3 = shp[v] - verts[v]
		var rel: Vector3 = verts[v] - hinge
		var d_rot: Vector3 = Basis(Vector3.RIGHT, 0.2 * LipSyncBones.JAW_SIGN) * rel - rel
		agree += d_shape.dot(d_rot)
		n += 1
	assert_gt(n, 20, "jaw-weighted vertices")
	assert_gt(agree, 0.0, "LipSyncBones turns the Jaw bone the way jaw_open moves the jaw")
