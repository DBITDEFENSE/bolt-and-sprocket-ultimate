extends GutTest
## A pooled AudioDirector player freed by a caller must not break later sounds (the Fernflug pass's KranichAir freed
## two pooled players on exit; every later play_2d that reached their slots failed with "previously freed instance").


func test_a_freed_pooled_player_is_replaced() -> void:
	var pool: Array = AudioDirector.get("_pool2d")
	assert_gt(pool.size(), 0)
	var victim: Node = pool[0]
	victim.free()   # what a careless caller did
	assert_false(is_instance_valid(pool[0]))
	AudioDirector.call("_heal_pools")
	var healed: Array = AudioDirector.get("_pool2d")
	assert_true(is_instance_valid(healed[0]), "the slot holds a fresh player")
	assert_eq((healed[0] as Node).get_parent(), AudioDirector, "owned by the director")
	for p: Variant in healed:
		assert_true(is_instance_valid(p), "every 2D slot is alive")


func test_kranich_air_owns_its_loops() -> void:
	var src: String = FileAccess.get_file_as_string("res://gravelight/world/map04/kranich_air.gd")
	assert_string_contains(src, "make_loop_2d", "the wind and engine beds are players of its own")
	assert_false(src.contains("AudioDirector.play_2d(key, -60.0"), "not borrowed from the shared pool")
