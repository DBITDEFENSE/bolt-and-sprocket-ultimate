extends GutTest
## Update 02 section 8 (T-053): Map 0's small-detail polish. The reactive pieces' rules: what a bullet hole
## persists on, the decor hit layer and the shot mask, glass breaking once, footprints only on open snow and in a
## capped ring, audio zones' round gates, the paper art, and that every sound key the pieces use exists.


func test_decor_layer_is_in_the_shot_mask_and_nothing_walks_on_it() -> void:
	assert_eq(DecorHit.LAYER, 1 << 9, "physics layer 10")
	assert_ne(WeaponHolder.MASK_SHOT & DecorHit.LAYER, 0, "the player's shot ray sees decor")
	assert_eq(Player.LAYER_PLAYER & DecorHit.LAYER, 0)
	var a: Area3D = DecorHit.make_area(Node3D.new(), Vector3.ZERO, 0.1)
	assert_eq(a.collision_layer, DecorHit.LAYER)
	assert_eq(a.collision_mask, 0, "a hit volume detects nothing")
	assert_false(a.monitoring)
	a.get_parent().free()


func test_holes_persist_only_on_plain_static_world() -> void:
	var holder: Node3D = Node3D.new()
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	holder.add_child(wall)
	assert_true(Effects.persists_on(wall), "plain geometry keeps its holes")
	wall.set_meta("decal_persist", false)
	assert_false(Effects.persists_on(wall), "tagged off (an invisible collider)")
	var door_body: StaticBody3D = StaticBody3D.new()
	door_body.collision_layer = 1 << 8
	holder.add_child(door_body)
	assert_false(Effects.persists_on(door_body), "a door's body rises away: no persistent holes")
	var scripted: Node3D = Node3D.new()
	scripted.set_script(load("res://gravelight/world/reactive/swing_door.gd"))
	var child: StaticBody3D = StaticBody3D.new()
	child.collision_layer = 1
	scripted.add_child(child)
	assert_false(Effects.persists_on(child), "a scripted gameplay node's body may move or vanish")
	assert_false(Effects.persists_on(null))
	holder.free()
	scripted.free()


func test_persistent_holes_are_capped_and_cleared() -> void:
	Effects.clear_marks()
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	add_child_autofree(body)
	for i: int in Effects.HOLES_PER_SURFACE + 20:
		Effects.impact(Vector3(i * 0.1, 1, 0), Vector3.BACK, "wood", body)
	assert_eq(Effects.persistent_hole_count(), Effects.HOLES_PER_SURFACE, "a full kind reuses its oldest slot")
	Effects.clear_marks()
	assert_eq(Effects.persistent_hole_count(), 0)


func test_scorch_marks_pool() -> void:
	Effects.clear_marks()
	for i: int in Effects.SCORCHES + 3:
		Effects.scorch(Vector3(i, 0, 0), 3.0)
	assert_eq(Effects.scorch_count(), Effects.SCORCHES, "capped")
	Effects.clear_marks()
	assert_eq(Effects.scorch_count(), 0)


func test_glass_breaks_once() -> void:
	var ss: ShatterSet = ShatterSet.new()
	ss.items = [[Vector3(0, 1, 0), "bottle_green", 1.0], [Vector3(0.2, 1, 0), "stein", 0.94], [Vector3(0.4, 1, 0), "glass", 0.8]]
	add_child_autofree(ss)
	assert_eq(ss.broken_count(), 0)
	assert_true(ss.break_item(1, Vector3.FORWARD))
	assert_false(ss.break_item(1, Vector3.FORWARD), "already broken")
	assert_false(ss.break_item(9), "out of range")
	assert_eq(ss.broken_count(), 1)
	ss._on_explosion(ss.to_global(Vector3(0, 1.1, 0)), 1.0)
	assert_eq(ss.broken_count(), 2, "a blast breaks what is in reach and no more")


func test_footprints_only_on_open_snow() -> void:
	var fp: SnowFootprints = SnowFootprints.new()
	fp.areas = [AABB(Vector3(0, -1, 0), Vector3(10, 3, 10))] as Array[AABB]
	fp.holes = [AABB(Vector3(4, -2, 4), Vector3(2, 4, 2))] as Array[AABB]
	fp.max_prints = 8
	add_child_autofree(fp)
	assert_true(fp.on_snow(Vector3(1, 0, 1)))
	assert_false(fp.on_snow(Vector3(5, 0, 5)), "a hole (a light well)")
	assert_false(fp.on_snow(Vector3(20, 0, 1)), "outside every area")
	assert_false(fp.on_snow(Vector3(1, 3.8, 1)), "up on the porch roof")
	for k: int in 12:
		fp.step(7, Vector3(1 + k * 0.8, 0, 2), SnowFootprints.KIND_BOOT)
	assert_eq(fp.made, 11, "one print per stride after the first step")
	fp.step(7, Vector3(5, 0, 5), SnowFootprints.KIND_BOOT)
	var before: int = fp.made
	fp.step(7, Vector3(5.9, 0, 5), SnowFootprints.KIND_BOOT)
	assert_eq(fp.made, before, "no prints in a hole")


func test_audio_zone_round_gates() -> void:
	var z: AudioZone = AudioZone.new()
	z.max_round = 2
	assert_true(z.round_ok(1))
	assert_true(z.round_ok(2))
	assert_false(z.round_ok(3), "the horse is only heard early")
	z.min_round = 5
	z.max_round = 0
	assert_false(z.round_ok(4))
	assert_true(z.round_ok(40))
	z.free()


func test_sound_keys_exist() -> void:
	for k: String in ["fire_crackle", "wind_howl", "stable_creak", "horse_whinny", "glass_break", "door_creak", "lamp_knock"]:
		assert_true(AudioDirector.has_sound(k), "sound %s" % k)


func test_paper_art_builds() -> void:
	for k: String in PaperDecor.KINDS.keys():
		var t: ImageTexture = PaperDecor.texture(k)
		assert_not_null(t, k)
		assert_gt(t.get_width(), 16, k)


func test_calendar_starts_on_a_friday() -> void:
	# 1 December 1944 was a Friday; the calendar's grid puts day 1 in column 4 (Monday = 0)
	var d: Dictionary = Time.get_datetime_dict_from_datetime_string("1944-12-01T00:00:00", false)
	assert_eq(Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(d)).weekday, 5, "Friday")
