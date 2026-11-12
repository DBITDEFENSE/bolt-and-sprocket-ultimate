extends GutTest

func test_clothing_detail_is_zombie_only_and_survives_dismemberment() -> void:
	var zombie: ArrayMesh = ZombieBody.build_skinned("soldier", "medium", false)
	var living: ArrayMesh = ZombieBody.build_living("soldier", "medium", false)
	var zombie_kit: ShaderMaterial = zombie.surface_get_material(1)
	var living_kit: ShaderMaterial = living.surface_get_material(1)
	assert_eq(zombie.get_surface_count(), 2, "detail adds no draw surface")
	assert_ne(zombie_kit, living_kit, "people keep a separate existing material")
	assert_true(bool(zombie_kit.get_shader_parameter("zombie_pbr")))
	assert_false(bool(living_kit.get_shader_parameter("zombie_pbr")))
	for texture: String in ["fabric_normal", "fabric_orm", "leather_normal", "leather_orm"]:
		assert_true(zombie_kit.get_shader_parameter(texture) is Texture2D, texture + " loads the licensed map")
	var arm: ArrayMesh = ZombieBody.piece_mesh("soldier", "medium", false, "LeftUpperArm")
	var matched: bool = false
	for surface: int in arm.get_surface_count():
		if arm.surface_get_material(surface) == zombie_kit: matched = true
	assert_true(matched, "a severed sleeve keeps its body's material")
