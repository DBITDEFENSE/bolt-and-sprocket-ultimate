extends GutTest
## T-243 (the owner: "make the menu better and more scary"): the menu's Watcher only moves while the lights are out
## and comes closer step by step; the dread beats dim the inn's lights and the frame and give them back; the flicker
## follows the Camera Sway comfort setting (no strobe at off); the heartbeat vignette; the typed taglines; the blood
## highlight; no beats over an open page.

var _saved_profile: Dictionary = {}
var _saved_path: String = ""
var _saved_sway: Variant = null


func before_each() -> void:
	_saved_profile = ProfileSave.profile.duplicate(true)
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_menu_dread_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_saved_sway = GLSettings.values.get("camera_sway", "full")


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.profile = _saved_profile
	GLSettings.values["camera_sway"] = _saved_sway


func test_watcher_steps_closer_then_leaves_then_returns() -> void:
	var seq: Array = [0]
	for i: int in MenuScene.WATCHER_STEPS.size() + MenuScene.WATCHER_GONE_BEATS:
		seq.append(MenuScene.next_watcher_step(int(seq.back())))
	assert_eq(seq, [0, 1, 2, 3, 4, 5, 0], "four steps closer, gone for two beats, back at the far end")
	for i: int in MenuScene.WATCHER_STEPS.size() - 1:
		assert_lt((MenuScene.WATCHER_STEPS[i + 1] as Vector2).x, (MenuScene.WATCHER_STEPS[i] as Vector2).x, "each step is closer")
	assert_lt(float((MenuScene.WATCHER_STEPS.back() as Vector2).x), MenuScene.FENCE_DEPTH - 4.0, "the camera's side of the fence")


func test_flicker_follows_the_comfort_setting() -> void:
	var full: Array = MenuScene.flicker_profile(1.0)
	var reduced: Array = MenuScene.flicker_profile(0.5)
	var off: Array = MenuScene.flicker_profile(0.0)
	assert_eq(full.size(), 3, "full: three stutters")
	assert_eq(reduced.size(), 1, "reduced: one dip")
	assert_eq(off.size(), 1, "off: one slow dim")
	assert_gte(float(off[0][3]), 0.3, "off ramps in and out (no hard cut)")
	assert_lte(float(off[0][2]), 0.6, "off never goes black")
	for p: Array in [full, reduced, off]:
		assert_eq(MenuScene.profile_dark(p, -0.1), 0.0, "lit before")
		assert_eq(MenuScene.profile_dark(p, MenuScene.profile_end(p) + 0.01), 0.0, "lit after")
		var last: Array = p.back()
		assert_gt(MenuScene.profile_dark(p, (float(last[0]) + float(last[1])) * 0.5), 0.5, "dark in the middle of the last dip")


func test_heartbeat_double_thump() -> void:
	var period: float = 60.0 / MenuDread.BPM
	assert_almost_eq(MenuDread.heartbeat(0.0), 1.0, 0.001, "a thump")
	assert_lt(MenuDread.heartbeat(0.25), 0.2, "quiet between")
	assert_gt(MenuDread.heartbeat(0.31), 0.5, "the second, softer thump")
	assert_almost_eq(MenuDread.heartbeat(period * 3.0 + 0.1), MenuDread.heartbeat(0.1), 0.001, "periodic")


func test_taglines_type_in() -> void:
	assert_eq(MainMenu_script().TAGLINES[0], "Silesia, winter 1944. The dead are keeping count.", "the first line is the one it always had")
	assert_eq(MainMenu_script().tagline_text(0, 0.0), MainMenu_script().TAGLINES[0], "the first line is whole at once")
	assert_eq(MainMenu_script().tagline_text(1, 0.0), "", "a new line starts empty")
	assert_eq(MainMenu_script().tagline_text(1, 0.2), MainMenu_script().TAGLINES[1].substr(0, 6))
	assert_eq(MainMenu_script().tagline_text(1, 5.0), MainMenu_script().TAGLINES[1], "and types out")
	var seen: Dictionary = {}
	for l: String in MainMenu_script().TAGLINES:
		assert_false(seen.has(l), "no line twice")
		seen[l] = true


func MainMenu_script() -> GDScript:
	return load("res://gravelight/ui/main_menu.gd") as GDScript


func test_beat_dims_the_lights_and_moves_the_watcher_unseen() -> void:
	GLSettings.values["camera_sway"] = "full"
	var s: MenuScene = MenuScene.new()
	s.force_web = 1
	add_child_autofree(s)
	await wait_frames(2)
	assert_not_null(s.watcher, "the Watcher stands in the scene")
	assert_eq(int(s.census()["zombies"]), (MenuScene.WALKERS.size() + MenuScene.TEARERS.size()) / 2, "not counted with the horde")
	var to_cam: Vector3 = Vector3(MenuScene.CAM_A.x, 0, MenuScene.CAM_A.z) - Vector3(s.watcher.position.x, 0, s.watcher.position.z)
	var facing: Vector3 = -s.watcher.global_basis.z
	assert_gt(facing.normalized().dot(to_cam.normalized()), 0.99, "it faces the camera")
	var p0: Vector3 = s.watcher.position
	var spill: Array = (s.get("_spills") as Array)[0]
	s.dread_enabled = false
	s.dread_beat_now()
	assert_eq(s.beats, 1)
	var moved_dark: float = -1.0
	var t: float = 0.0
	while t < 1.2:
		s.call("_update_dread", 0.02)
		t += 0.02
		if moved_dark < 0.0 and s.watcher.position != p0:
			moved_dark = s.dread_dark
	assert_eq(s.watcher_step, 1, "one step closer")
	assert_gt(moved_dark, 0.9, "it moved while the lights were out (dark %.2f)" % moved_dark)
	assert_eq(s.dread_dark, 0.0, "the beat is over")
	assert_almost_eq((spill[0] as OmniLight3D).light_energy, float(spill[1]), 0.001, "the window spill is back")
	# no beats while a page is open, however long it stays open
	s.set("_beat_in", 0.01)
	for i: int in 50:
		s.call("_update_dread", 0.1)
	assert_eq(s.beats, 1, "dread_enabled false: no beat")


func test_main_menu_bleeds() -> void:
	var mm: Control = (load("res://gravelight/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(mm)
	await wait_frames(3)
	var dread: MenuDread = mm.get("dread") as MenuDread
	assert_not_null(dread, "the dread overlay")
	assert_lt(dread.get_index(), mm.get_node("Masthead").get_index(), "under the menu's text")
	var links: Node = mm.get("_links")
	var sb: StyleBoxFlat = (links.get_child(0) as Button).get_meta("link_box") as StyleBoxFlat
	assert_almost_eq(sb.bg_color.r, MainMenu_script().BLOOD.r, 0.01, "the plate is dried blood, not violet")
	assert_true(mm.find_child("Tagline", true, false) is Label)
	var scene: MenuScene = mm.get("scene") as MenuScene
	var screen: MenuScreen = mm.call("open_screen", MenuCredits) as MenuScreen
	assert_false(scene.dread_enabled, "no beats over a page")
	await wait_frames(2)
	screen.close()
	await wait_frames(20)
	assert_true(scene.dread_enabled, "back on the menu, the beats resume")
