extends GutTest
## T-240: the horse's gaits (HorseGait) and the rideable horse's rules (HorseRules, data/gravelight/horse.json) as pure
## logic: the walk is four-beat with never fewer than two feet down, the trot two-beat on diagonal pairs with a
## suspension, the gallop four-beat with all four feet off the ground once a stride; a hoof on the ground travels back
## at the body's speed (no sliding); the pace answers forward / back / nothing; the turn is an animal's (it lags, a
## gallop turns wide and slows in a hard turn); the rider shoots at a trot and not at a gallop; a crowd and a boss cap
## the pace; a trample needs speed and has a cooldown; the horse stands only in its zones; bots never mount; the map's
## "horses" rows are well formed; and the model builds with every bone weighted.

const G := HorseGait.Gait


func _ride() -> Dictionary:
	return HorseRules.block("ride")


func test_gait_for_speed_with_hysteresis() -> void:
	assert_eq(HorseGait.gait_for(0.0), G.STAND, "still: standing")
	assert_eq(HorseGait.gait_for(1.9), G.WALK, "1.9 m/s: a walk")
	assert_eq(HorseGait.gait_for(4.6, G.WALK), G.TROT, "4.6 m/s: a trot")
	assert_eq(HorseGait.gait_for(9.5, G.TROT), G.GALLOP, "9.5 m/s: a gallop")
	assert_eq(HorseGait.gait_for(2.7, G.WALK), G.WALK, "just over the border a walk is kept")
	assert_eq(HorseGait.gait_for(2.5, G.TROT), G.TROT, "just under it a trot is kept")
	assert_eq(HorseGait.gait_for(2.0, G.TROT), G.WALK, "well under it the trot falls to a walk")
	assert_eq(HorseGait.gait_for(0.02, G.WALK), G.STAND, "almost still: it stands")
	assert_eq(HorseGait.gait_for(-1.0), G.WALK, "backing up is a walk")


func test_walk_is_four_beat_with_feet_down() -> void:
	assert_eq(HorseGait.beats(G.WALK).size(), 4, "four footfalls a stride")
	for i: int in 100:
		assert_gte(HorseGait.feet_down(G.WALK, float(i) / 100.0), 2, "never fewer than two feet down at a walk (phase %.2f)" % (float(i) / 100.0))
	assert_false(HorseGait.has_suspension(G.WALK), "a walk has no suspension")
	# lateral sequence: left hind, left fore, right hind, right fore
	var o: Array = HorseGait.OFFSETS[G.WALK]
	assert_true(float(o[HorseGait.LH]) < float(o[HorseGait.LF]) and float(o[HorseGait.LF]) < float(o[HorseGait.RH]) and float(o[HorseGait.RH]) < float(o[HorseGait.RF]), "LH, LF, RH, RF")


func test_trot_is_two_beat_diagonal_with_suspension() -> void:
	assert_eq(HorseGait.beats(G.TROT).size(), 2, "two beats a stride")
	var o: Array = HorseGait.OFFSETS[G.TROT]
	assert_eq(float(o[HorseGait.LH]), float(o[HorseGait.RF]), "left hind lands with right fore")
	assert_eq(float(o[HorseGait.RH]), float(o[HorseGait.LF]), "right hind lands with left fore")
	assert_true(HorseGait.has_suspension(G.TROT), "a trot leaves the ground between its beats")
	for i: int in 100:
		var n: int = HorseGait.feet_down(G.TROT, float(i) / 100.0)
		assert_true(n == 0 or n == 2, "a trot has two feet down or none (phase %.2f: %d)" % [float(i) / 100.0, n])


func test_gallop_is_four_beat_with_suspension() -> void:
	assert_eq(HorseGait.beats(G.GALLOP).size(), 4, "four footfalls a stride")
	assert_true(HorseGait.has_suspension(G.GALLOP), "a gallop has its suspension")
	var air: int = 0
	for i: int in 100:
		if HorseGait.feet_down(G.GALLOP, float(i) / 100.0) == 0:
			air += 1
	assert_between(air, 15, 40, "about a fifth to a third of the stride in the air (%d%%)" % air)
	assert_false(HorseGait.has_suspension(G.STAND), "standing: four feet down")
	assert_eq(HorseGait.feet_down(G.STAND, 0.3), 4)


func test_a_planted_hoof_does_not_slide() -> void:
	for g: int in [G.WALK, G.TROT, G.GALLOP]:
		var speed: float = float((HorseGait.SPEEDS[g] as Array)[1])
		var hz: float = HorseGait.stride_hz(g, speed)
		var d: float = HorseGait.duty(g)
		# through the stance the hoof goes back (in +Z) by speed x time: the ground under it stands still
		var a: Vector3 = HorseGait.hoof_offset(g, HorseGait.LH, 0.1 * d, speed)
		var b: Vector3 = HorseGait.hoof_offset(g, HorseGait.LH, 0.9 * d, speed)
		assert_almost_eq(b.z - a.z, speed * (0.8 * d) / hz, 0.001, "%s: the planted hoof travels back at the body's speed" % HorseGait.gait_name(g))
		assert_eq(a.y, 0.0, "%s: a planted hoof is on the ground" % HorseGait.gait_name(g))
		var mid: Vector3 = HorseGait.hoof_offset(g, HorseGait.LF, fposmod(float((HorseGait.OFFSETS[g] as Array)[HorseGait.LF]) + d + (1.0 - d) * 0.5, 1.0), speed)
		assert_gt(mid.y, 0.05, "%s: a swinging hoof is lifted" % HorseGait.gait_name(g))
		assert_almost_eq(HorseGait.stride_length(g, speed), speed / hz, 0.001)
	assert_gt(HorseGait.stride_length(G.GALLOP, 9.5), HorseGait.stride_length(G.TROT, 4.6), "a gallop's stride is longer than a trot's")


func test_landings_between_phases() -> void:
	var l: PackedInt32Array = HorseGait.landings(G.WALK, 0.2, 0.3)
	assert_eq(Array(l), [HorseGait.LF], "the left fore lands at 0.25")
	l = HorseGait.landings(G.TROT, 0.95, 0.05)
	assert_eq(l.size(), 2, "across the wrap a trot lands a diagonal pair")
	assert_eq(HorseGait.landings(G.STAND, 0.0, 0.9).size(), 0, "standing: no footfalls")
	var total: int = 0
	var ph: float = 0.0
	for i: int in 50:
		var nx: float = fposmod(ph + 0.02, 1.0)
		total += HorseGait.landings(G.GALLOP, ph, nx).size()
		ph = nx
	assert_eq(total, 4, "one stride of gallop: four footfalls, none lost at the wrap")


func test_the_body_rides_the_gait() -> void:
	var lo: float = INF
	var hi: float = -INF
	for i: int in 100:
		lo = minf(lo, HorseGait.body_bob(G.TROT, float(i) / 100.0))
		hi = maxf(hi, HorseGait.body_bob(G.TROT, float(i) / 100.0))
	assert_gt(hi - lo, 0.05, "the trot bounces")
	assert_almost_eq(HorseGait.body_bob(G.TROT, 0.1), HorseGait.body_bob(G.TROT, 0.6), 0.0001, "twice a stride")
	assert_ne(HorseGait.body_pitch(G.GALLOP, 0.2), HorseGait.body_pitch(G.GALLOP, 0.7), "the gallop rocks")
	assert_ne(HorseGait.head_nod(G.WALK, 0.1), HorseGait.head_nod(G.WALK, 0.35), "the head nods at a walk")
	assert_eq(HorseGait.saddle_motion(G.STAND, 0.4), Vector3.ZERO, "standing: a still saddle")


func test_pace_answers_the_rider() -> void:
	var r: Dictionary = _ride()
	var p: float = 0.0
	for i: int in 60:
		p = HorseRules.pace_step(p, 1.0, false, 1.0 / 60.0, r)
	assert_almost_eq(p, float(r["urge_per_s"]), 0.01, "a second of forward: one urge")
	var t: float = 0.0
	while p < 3.0 and t < 20.0:
		p = HorseRules.pace_step(p, 1.0, false, 1.0 / 60.0, r)
		t += 1.0 / 60.0
	assert_between(t, 1.5, 4.0, "held forward it reaches a gallop in a few seconds (%.1f s more)" % t)
	assert_eq(HorseRules.pace_step(3.0, 1.0, true, 1.0, r), 3.0, "never past a gallop")
	var eased: float = 3.0
	for i: int in 60 * 20:
		eased = HorseRules.pace_step(eased, 0.0, false, 1.0 / 60.0, r)
	assert_almost_eq(eased, float(r["ease_floor"]), 0.001, "left alone it eases back to a walk, not to a stand")
	var reined: float = 3.0
	for i: int in 60 * 2:
		reined = HorseRules.pace_step(reined, -1.0, false, 1.0 / 60.0, r)
	assert_eq(reined, 0.0, "two seconds of back: stopped")
	assert_lte(HorseRules.pace_step(3.0, 1.0, false, 0.1, r, 1.5), 1.5, "a cap holds the pace down")
	assert_almost_eq(HorseRules.pace_speed(1.0, r), float(r["walk_speed"]), 0.001)
	assert_almost_eq(HorseRules.pace_speed(2.0, r), float(r["trot_speed"]), 0.001)
	assert_almost_eq(HorseRules.pace_speed(3.0, r), float(r["gallop_speed"]), 0.001)
	assert_gt(float(r["gallop_speed"]), float(GLData.table("player")["sprint_speed"]), "a gallop outruns a sprint")
	assert_lt(float(r["walk_speed"]), float(GLData.table("player")["walk_speed"]), "a horse's walk is slower than a man's")


func test_speed_and_turn_are_an_animals() -> void:
	var r: Dictionary = _ride()
	assert_almost_eq(HorseRules.speed_step(0.0, 9.5, false, 1.0, r), float(r["accel"]), 0.001, "it gathers speed at its own rate")
	assert_gt(4.0 - HorseRules.speed_step(4.0, 0.0, true, 0.1, r), 4.0 - HorseRules.speed_step(4.0, 0.0, false, 0.1, r), "reining in stops it harder than letting it slow")
	assert_gt(HorseRules.turn_rate(0.0, r), HorseRules.turn_rate(9.5, r), "it turns tighter standing than at a gallop")
	var radius: float = HorseRules.turn_speed_cap(1.0, r) / HorseRules.turn_rate(HorseRules.turn_speed_cap(1.0, r), r)
	assert_between(radius, 4.0, 7.0, "a gallop's tightest circle fits the yard's 14 m (radius %.1f m)" % radius)
	assert_lt(HorseRules.turn_speed_cap(1.0, r), float(r["gallop_speed"]), "a hard turn brings a gallop down")
	assert_almost_eq(HorseRules.turn_speed_cap(0.0, r), float(r["gallop_speed"]), 0.001, "straight on it does not")
	var s: float = HorseRules.steer_step(0.0, 1.0, 1.0 / 60.0, r)
	assert_between(s, 0.01, 0.2, "the turn lags the rein (%.2f after one frame)" % s)
	for i: int in 120:
		s = HorseRules.steer_step(s, 1.0, 1.0 / 60.0, r)
	assert_gt(s, 0.98, "and gets there")


func test_fire_from_the_saddle() -> void:
	var f: Dictionary = HorseRules.block("fire")
	assert_true(HorseRules.can_fire(G.STAND, true, f), "seated at a stand")
	assert_true(HorseRules.can_fire(G.WALK, true, f), "at a walk")
	assert_true(HorseRules.can_fire(G.TROT, true, f), "at a trot")
	assert_false(HorseRules.can_fire(G.GALLOP, true, f), "not at a gallop")
	assert_false(HorseRules.can_fire(G.WALK, false, f), "not while getting up or down")
	assert_gt(HorseRules.fire_sway(G.TROT, f), HorseRules.fire_sway(G.WALK, f), "a trot sways the aim more than a walk")


func test_crowd_boss_and_trample() -> void:
	var c: Dictionary = HorseRules.block("crowd")
	var bf: Dictionary = HorseRules.block("boss_fear")
	var t: Dictionary = HorseRules.block("trample")
	assert_eq(HorseRules.pace_cap(0, INF, c, bf), 3.0, "alone: any pace")
	assert_lt(HorseRules.pace_cap(3, INF, c, bf), 3.0, "crowded: no gallop")
	assert_gte(HorseRules.pace_cap(20, INF, c, bf), float(c["min_pace"]), "however many, it still goes")
	assert_lte(HorseRules.pace_cap(0, 5.0, c, bf), 1.0, "near a boss: a walk at most")
	assert_eq(HorseRules.shy_level(0, INF, c, bf), 0.0)
	assert_eq(HorseRules.shy_level(int(c["shy_at"]), INF, c, bf), 1.0, "it shies at a crowd")
	assert_gt(HorseRules.shy_level(0, 5.0, c, bf), 0.5, "and near a boss")
	assert_true(HorseRules.trample(4.6, 0.0, t).is_empty(), "a trot flings nobody")
	assert_true(HorseRules.trample(9.5, 0.3, t).is_empty(), "nor a gallop still cooling down")
	var hit: Dictionary = HorseRules.trample(9.5, 0.0, t)
	assert_true(hit.has("damage") and hit.has("push") and float(hit["slow"]) > 0.0, "a gallop does, and costs the horse speed")
	var z20: int = RoundManager.zombie_health(20, GLData.table("rounds"))
	assert_lt(float(hit["damage"]), float(z20) * 0.1, "not a win button: under a tenth of a round-20 zombie's health (%d of %d)" % [int(hit["damage"]), z20])
	assert_gt(float(t["cooldown"]), 0.3)


func test_where_it_may_stand_and_who_may_mount() -> void:
	var b: Dictionary = HorseRules.block("bounds")
	var zones: Array = ["YARD", "GROUNDS"]
	assert_true(HorseRules.may_stand(&"YARD", true, 0.0, 0.0, zones, b), "its yard")
	assert_false(HorseRules.may_stand(&"GROUNDS", false, 0.0, 0.0, zones, b), "not a zone still shut")
	assert_false(HorseRules.may_stand(&"STABLE", true, 0.0, 0.0, zones, b), "not through the stable's door")
	assert_false(HorseRules.may_stand(&"TAPROOM", true, 0.0, 0.0, zones, b), "not the inn")
	assert_false(HorseRules.may_stand(&"", true, 0.0, 0.0, zones, b), "not off the map")
	assert_false(HorseRules.may_stand(&"YARD", true, 6.2, 0.0, zones, b), "not the tower's deck")
	assert_false(HorseRules.may_stand(&"GROUNDS", true, -3.2, 0.0, zones, b), "not down a well")
	assert_true(HorseRules.may_mount(false, true, false, false, false), "a live human on their feet")
	assert_false(HorseRules.may_mount(true, true, false, false, false), "one rider at a time")
	assert_false(HorseRules.may_mount(false, true, false, true, false), "never a bot")
	assert_false(HorseRules.may_mount(false, true, true, false, false), "not downed")
	assert_false(HorseRules.may_mount(false, false, false, false, false), "not dead")
	assert_false(HorseRules.may_mount(false, true, false, false, true), "not from a ladder or a zip line")
	var offs: Array[Vector3] = HorseRules.dismount_offsets()
	assert_gt(offs.size(), 4, "several places to get down")
	assert_lt(offs[0].x, 0.0, "the near (left) side first")
	for o: Vector3 in offs:
		assert_gt(Vector2(o.x, o.z).length(), 1.0, "clear of the horse's body")
	var h: Dictionary = HorseRules.block("home")
	assert_true(HorseRules.home_due(float(h["idle_s"]) + 1.0, 5.0, false, h), "left alone it goes home")
	assert_false(HorseRules.home_due(float(h["idle_s"]) + 1.0, 5.0, true, h), "not with a rider")
	assert_false(HorseRules.home_due(1.0, 5.0, false, h), "not at once")
	assert_false(HorseRules.home_due(999.0, 0.1, false, h), "not when it is there")
	assert_almost_eq(HorseRules.puppet_yaw(0.0, Vector3(0.1, 0, 0), 0.1), 0.0, 0.0001, "a puppet keeps its heading while the rider stands")
	assert_ne(HorseRules.puppet_yaw(0.0, Vector3(4, 0, 0), 0.1), 0.0, "and turns where the rider goes")


func test_map_rows() -> void:
	var rows: Array = GLData.load_json("res://data/gravelight/map00.json").get("horses", [])
	assert_eq(rows.size(), 1, "the Inn has one horse")
	var row: Dictionary = rows[0]
	for k: String in ["name", "pos", "yaw", "rail", "zones", "look"]:
		assert_true(row.has(k), "the row has %s" % k)
	var pos: Vector3 = ClimbLink._v3(row["pos"])
	assert_true(pos.x > 2.5 and pos.x < 33.5 and pos.z > 34.5 and pos.z < 47.5 and pos.y == 0.0, "it stands in the Carters' Yard (%s)" % str(pos))
	assert_true((row["zones"] as Array).has("YARD") and not (row["zones"] as Array).has("STABLE") and not (row["zones"] as Array).has("TAPROOM"), "its zones are outdoors")
	assert_gt(pos.distance_to(Vector3(18.6, 0, 36.2)), 4.0, "clear of the zip line's landing post")
	assert_gt(pos.distance_to(Vector3(5.4, 0, 42.6)), 8.0, "clear of the tower's ladder")
	assert_gt(absf(pos.x - 22.0), 1.6, "clear of the wall-buy chalked on the stable wall")
	assert_lt(ClimbLink._v3(row["rail"]).distance_to(pos), 2.0, "the rail is in front of it")
	for map: String in ["map01", "map02"]:
		assert_false(GLData.load_json("res://data/gravelight/%s.json" % map).has("horses"), "%s has no horse row" % map)


func test_model_builds_and_is_skinned() -> void:
	var names: Dictionary = {}
	for b: Array in HorseMesh.bones():
		assert_false(names.has(b[0]), "bone %s is listed once" % str(b[0]))
		names[b[0]] = true
	for leg: int in 4:
		var j: Array = HorseMesh.leg_joints(leg)
		assert_eq(j.size(), 6)
		assert_almost_eq((j[5] as Vector3).y, 0.0, 0.0001, "a hoof stands on the ground")
		assert_gt((j[0] as Vector3).y, 1.0, "a leg hangs from the body")
	assert_between((HorseMesh.BARREL[3] as Array)[1], 1.55, 1.65, "about 1.6 m at the withers")
	var length: float = float((HorseMesh.BARREL[HorseMesh.BARREL.size() - 1] as Array)[0]) - HorseMesh.muzzle().z
	assert_between(length, 2.2, 2.8, "about 2.4 m from the nose to the quarters (%.2f)" % length)
	for look: String in ["noriker", "dead"]:
		var m: ArrayMesh = HorseMesh.mesh(look)
		assert_gte(m.get_surface_count(), 5, "%s: surfaces for coat, hair, hooves and its gear" % look)
		var tris: int = 0
		for s: int in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var bn: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			assert_eq(w.size(), verts.size() * 4, "%s/%s: four weights a vertex" % [look, m.surface_get_name(s)])
			var bad: int = 0
			for v: int in verts.size():
				if absf(w[v * 4] + w[v * 4 + 1] + w[v * 4 + 2] + w[v * 4 + 3] - 1.0) > 0.01 or bn[v * 4] >= names.size():
					bad += 1
			assert_eq(bad, 0, "%s/%s: every vertex is weighted to real bones" % [look, m.surface_get_name(s)])
			tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_between(tris, 3000, 40000, "%s: a game model's triangle count (%d)" % [look, tris])
		var box: AABB = m.get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.03, "%s: the hooves are at the ground" % look)
		assert_between(box.size.y, 1.9, 2.5, "%s: the ears stand about 2.2 m up (%.2f)" % [look, box.size.y])
	assert_true(HorseMesh.mesh("noriker") == HorseMesh.mesh("noriker"), "a look's mesh is built once")


func test_rig_poses_every_gait_finite() -> void:
	var rig: HorseRig = HorseRig.new("noriker")
	add_child_autofree(rig)
	var landed: Array = []
	rig.hoof.connect(func(leg: int, _at: Vector3, _g: int) -> void: landed.append(leg))
	for speed: float in [0.0, 1.9, 4.6, 9.5, -1.0]:
		rig.speed = speed
		rig.turn = 0.2
		for i: int in 90:
			rig.tick(1.0 / 60.0)
		assert_eq(rig.gait, HorseGait.gait_for(speed, rig.gait), "the rig's gait follows its speed (%.1f)" % speed)
		for b: int in rig.skel.get_bone_count():
			var p: Vector3 = rig.skel.get_bone_pose_position(b)
			assert_true(p.is_finite() and p.length() < 6.0, "bone %s sits in a sane place at %.1f m/s (%s)" % [rig.skel.get_bone_name(b), speed, str(p)])
		for leg: int in 4:
			var hoof_y: float = rig.skel.get_bone_pose_position(rig.skel.find_bone("%s_D" % HorseGait.LEG_NAMES[leg])).y
			assert_gt(hoof_y, -0.05, "no fetlock under the ground at %.1f m/s" % speed)
	assert_gt(landed.size(), 8, "hooves landing are announced (%d)" % landed.size())
	for pose: String in ["rear", "kick", "collapse", "head_low", "stagger", "shy"]:
		rig.speed = 0.0
		rig.set(pose, 1.0)
		for i: int in 30:
			rig.tick(1.0 / 60.0)
		for b: int in rig.skel.get_bone_count():
			assert_true(rig.skel.get_bone_pose_position(b).is_finite(), "pose %s keeps bone %s finite" % [pose, rig.skel.get_bone_name(b)])
		rig.set(pose, 0.0)
	var seat: Transform3D = rig.seat_global()
	assert_between(seat.origin.y, 1.4, 1.8, "the saddle's seat is at the horse's back (%.2f)" % seat.origin.y)
