extends GutTest
## Profile save versioning and unlock rules.


func test_migrate_from_unversioned() -> void:
	var old: Dictionary = {"xp": 1234}
	var m: Dictionary = ProfileSave.migrate(old)
	assert_eq(int(m["version"]), ProfileSave.CURRENT_VERSION)
	assert_eq(int(m["xp"]), 1234)
	assert_true((m["maps_unlocked"] as Array).has("map00_crossroads"))


func test_unlock_and_roundtrip() -> void:
	var saved_path: String = ProfileSave.path
	ProfileSave.path = "user://_test_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	assert_false(ProfileSave.is_map_unlocked(&"map01_kaltenbrunn"))
	ProfileSave.unlock_map(&"map01_kaltenbrunn")
	ProfileSave.profile = {}
	ProfileSave.load_profile()
	assert_true(ProfileSave.is_map_unlocked(&"map01_kaltenbrunn"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = saved_path
	ProfileSave.load_profile()
