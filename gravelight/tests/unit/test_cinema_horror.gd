extends GutTest
## Replacement pictures must preserve the playable story and the existing hooks.
const CRAFT = preload("res://gravelight/world/cinema_sets/cinema_craft.gd")


func test_direction_preserves_every_story_event_and_duration() -> void:
	var originals: Dictionary = CinemaLibrary.data()["cutscenes"]
	var allowed: Array[String] = ["from", "to", "look", "look_to", "fov", "fov_to", "focus", "focus_to", "blur", "handheld", "lead", "hold", "move", "grade"]
	for id: String in originals:
		var source: Dictionary = originals[id]
		var revised: Dictionary = CinemaLibrary.def(id)
		assert_eq(revised["seconds"], source["seconds"], id + " duration")
		assert_eq(revised["shots"].size(), source["shots"].size(), id + " shot count")
		assert_eq(CinemaLibrary.line_ids(revised), CinemaLibrary.line_ids(source), id + " voices")
		for i: int in source["shots"].size():
			var old: Dictionary = source["shots"][i]
			var new: Dictionary = revised["shots"][i]
			for key: String in old:
				if not allowed.has(key):
					assert_eq(new.get(key), old[key], "%s shot %d preserves %s" % [id, i, key])
		assert_eq(CinemaDirector.validate(CinemaLibrary.resolved(id)).size(), 0, id + " valid")


func test_new_presentation_is_the_default_and_archive_is_replayable() -> void:
	assert_false(CinemaArchive.in_game(), "campaign uses the replacement 3D scenes")
	for id: String in CinemaLibrary.ids():
		assert_false(CinemaArchive.resolved(id).has("archive"), id + " has no damaged-film overlay")
	assert_true(CinemaArchive.resolved("reel:lazarus_saturday").has("archive"))


func test_shroud_is_continuous_and_has_a_downward_drape() -> void:
	var mesh: ArrayMesh = CRAFT.shroud()
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(points.size(), 2000)
	var low: float = 10.0
	var high: float = -10.0
	var up: float = 0.0
	for i: int in points.size():
		low = minf(low, points[i].y)
		high = maxf(high, points[i].y)
		up += normals[i].y
	assert_lt(low, 0.5, "cloth hangs below the board")
	assert_gt(high, 0.97, "cloth follows the covered torso")
	assert_gt(up, 0.0, "top surface faces the window light")


func test_vessel_lip_is_open_and_vault_does_not_cross_floor() -> void:
	var shell: Array = CRAFT.vessel_shell().surface_get_arrays(0)
	for p: Vector3 in shell[Mesh.ARRAY_VERTEX]:
		assert_gt(Vector2(p.x, p.z).length(), 0.049, "no cap obscures the liquid")
	var roof: Array = CRAFT.vault().surface_get_arrays(0)
	for p: Vector3 in roof[Mesh.ARRAY_VERTEX]:
		assert_gte(p.y, -0.301, "only the upper half of the barrel")
