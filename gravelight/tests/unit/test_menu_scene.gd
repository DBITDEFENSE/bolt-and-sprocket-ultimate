extends GutTest
## T-144 (UPDATE 09 section 7, contract C7): the main menu's live scene builds headless with its zombies, the squad
## and the inn; it keeps the light budget; the web variant halves the zombies and drops the volumetric fog; the
## progress hooks (Fernflug beaten: the violet point on the Moon; Map 0's egg: the radio) read the profile; the
## map cards' egg status and the menu's columns.

var _saved_profile: Dictionary = {}
var _saved_path: String = ""


func before_each() -> void:
	_saved_profile = ProfileSave.profile.duplicate(true)
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_menu_scene_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.profile = _saved_profile


func _scene(web: int) -> MenuScene:
	var s: MenuScene = MenuScene.new()
	s.force_web = web
	add_child_autofree(s)
	return s


func test_menu_inn_is_exported() -> void:
	assert_true(ResourceLoader.exists(MenuScene.INN_SCENE), "gen_menu_scene.gd exported %s" % MenuScene.INN_SCENE)
	var inn: Node = (load(MenuScene.INN_SCENE) as PackedScene).instantiate()
	assert_not_null(inn.get_node_or_null("Landscape"), "the landscape node (sky, terrain, forests) is in the set")
	assert_not_null(inn.get_node_or_null("Moon"), "the Moon is in the set")
	assert_not_null(inn.get_node_or_null("Dressing/Exterior"), "the inn's exterior dressing is in the set")
	assert_null(inn.get_node_or_null("Dressing/Taproom"), "no interiors")
	assert_null(inn.get_node_or_null("Gameplay"), "no gameplay nodes")
	assert_eq(inn.find_children("*", "CollisionShape3D", true, false).size(), 0, "no collision")
	var lights: Array = inn.find_children("*", "Light3D", true, false)
	assert_eq(lights.size(), 1, "only the Moon comes with the set (the scene lights itself)")
	assert_lt(inn.find_children("*", "MeshInstance3D", true, false).size(), 200, "the inn's batches are merged per material")
	inn.free()


func test_desktop_scene_builds_inside_the_budget() -> void:
	var s: MenuScene = _scene(0)
	await wait_frames(3)
	var c: Dictionary = s.census()
	assert_false(bool(c["web"]))
	assert_eq(int(c["walkers"]), MenuScene.WALKERS.size(), "six zombies walk the fence")
	assert_eq(int(c["tearers"]), MenuScene.TEARERS.size(), "two work the inn's boards")
	assert_eq(int(c["squad"]), 4, "Dutch, Peg, Wren and Deacon by the fire")
	assert_lte(int(c["shadowed_lights"]), MenuScene.SHADOWED_MAX_DESKTOP, "at most four shadowed lights")
	assert_gte(int(c["shadowed_lights"]), 1, "the Moon casts")
	assert_false(bool(c["sdfgi"]), "no SDFGI")
	assert_true(bool(c["volumetric_fog"]), "volumetric fog on desktop")
	assert_gt(s.load_ms, 0, "the first posed frame was timed")
	for z: Node3D in s.walkers:
		assert_not_null(z.get_node_or_null("Skel/Body"), "a skinned ZombieBody")
		var ap: AnimationPlayer = z.get_node("AP") as AnimationPlayer
		assert_true(ap.is_playing() and str(ap.current_animation).begins_with("shamble"), "%s shambles (%s)" % [z.name, ap.current_animation])
		assert_not_null(z.find_child("MarkeGlint", true, false), "%s carries its Marke glint" % z.name)
	for t: Node3D in s.tearers:
		assert_true(str((t.get_node("AP") as AnimationPlayer).current_animation).begins_with("tear_"), "a tearer works the boards")
	for id: String in ["dutch", "peg", "wren", "deacon"]:
		assert_true(s.squad.has(id), "%s is in the squad" % id)


func test_web_variant_halves_the_zombies() -> void:
	var s: MenuScene = _scene(1)
	await wait_frames(2)
	var c: Dictionary = s.census()
	assert_true(bool(c["web"]))
	assert_eq(int(c["walkers"]), MenuScene.WALKERS.size() / 2)
	assert_eq(int(c["zombies"]), (MenuScene.WALKERS.size() + MenuScene.TEARERS.size()) / 2, "half the zombies")
	assert_lte(int(c["shadowed_lights"]), MenuScene.SHADOWED_MAX_WEB, "one shadowed light")
	assert_false(bool(c["volumetric_fog"]), "depth fog only")
	assert_eq(MenuScene.walker_count(true) * 2, MenuScene.walker_count(false))


func test_walkers_loop_and_the_camera_cuts() -> void:
	var s: MenuScene = _scene(1)
	await wait_frames(2)
	var z: Node3D = s.walkers[0]
	var p0: Vector3 = z.position
	(s.get("_rig_state")[z] as Dictionary)["k"] = 0.999
	s._process(0.5)
	assert_gt(s.loops, 0, "a walker that reaches the end of the lane starts again")
	assert_ne(z.position, p0)
	var cam0: Vector3 = s.camera.global_position
	s._process(5.0)
	assert_ne(s.camera.global_position, cam0, "the camera drifts")
	s.set("_shot_t", MenuScene.SHOT_A_S + 0.1)
	s._process(0.01)
	assert_eq(s.shot, 1, "after shot A, the angle over the squad's shoulders")


func test_progress_hooks_read_the_profile() -> void:
	var s: MenuScene = _scene(1)
	await wait_frames(1)
	assert_false(s.mondlicht.visible, "no violet light on the Moon before Fernflug is beaten")
	assert_false(s.radio_on, "no radio before Map 0's egg")
	ProfileSave.profile["fernflug_beaten"] = true
	ProfileSave.profile["eggs_done"] = {"map00_radio": true}
	var s2: MenuScene = _scene(1)
	await wait_frames(1)
	assert_true(s2.mondlicht.visible, "MONDLICHT: the violet point of light on the Moon")
	assert_true(s2.radio_on, "the radio plays in the window")


func test_fernflug_flag_from_the_ending() -> void:
	assert_false(ProfileSave.fernflug_beaten())
	ProfileSave.note_ending("renewed")
	assert_false(ProfileSave.fernflug_beaten(), "the renewal is no win")
	ProfileSave.note_ending("kuendigung")
	assert_true(ProfileSave.fernflug_beaten())
	assert_true(bool(ProfileSave.profile.get("fernflug_beaten", false)), "the contract's flag is set")


func test_map_cards_egg_status() -> void:
	assert_eq(MapCards.egg_status("map02_totenhafen"), "no egg")
	assert_eq(MapCards.egg_status("map00_crossroads"), "not done")
	ProfileSave.profile["eggs_done"] = {"map00_radio": true}
	assert_eq(MapCards.egg_status("map00_crossroads"), "done")
	ProfileSave.profile["egg_rewards"] = {"map01_requiem": true}
	assert_eq(MapCards.egg_status("map01_kaltenbrunn"), "done", "the main eggs' reward record counts")
	ProfileSave.profile["fernflug_beaten"] = true
	assert_eq(MapCards.egg_status("map04c_groomlake"), "done", "Fernflug's egg is its kuendigung ending")
	for id: String in MapCards.ids():
		var r: Dictionary = MapCards.row(id)
		assert_true(ResourceLoader.exists(str(r["scene"])), "%s's scene exists" % id)
		assert_ne(str(r["date"]), "", "%s has a date line" % id)
		assert_eq(MapCards.id_for_scene(str(r["scene"])), id)


func test_map_card_shows_progress() -> void:
	ProfileSave.profile["best_round"] = {"map00_crossroads": 23}
	var c: Button = MapCards.map_card("map00_crossroads", Callable())
	add_child_autofree(c)
	assert_eq(int(c.get_meta("best")), 23)
	assert_false(c.disabled, "Map 0 is always open")
	var locked: Button = MapCards.map_card("map04d_mondlicht", Callable())
	add_child_autofree(locked)
	assert_true(locked.disabled, "a locked map's card can't be pressed")


func test_main_menu_columns() -> void:
	var mm: Control = (load("res://gravelight/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(mm)
	await wait_frames(3)
	var want: Dictionary = {"main": ["PLAY", "LOADOUT", "COLLECTION", "EXTRAS", "SETTINGS", "QUIT"],
		"play": ["SOLO", "CO-OP", "CAMPAIGN", "BACK"],
		"extras": ["CUTSCENES", "CHARACTERS", "STATS", "CHALLENGES", "CREDITS", "SHOOTING RANGE", "BACK"]}
	for col: String in want.keys():
		mm.call("show_column", col, false)
		await wait_frames(1)
		var links: Node = mm.get("_links")
		var got: Array = []
		for b: Node in links.get_children():
			got.append((b as Button).text)
		assert_eq(got, want[col], "the %s column" % col)
	assert_not_null(mm.find_child("Wordmark", true, false), "the wordmark")
	mm.call("show_column", "main", false)
	var lobby: MenuScreen = mm.call("open_screen", MenuLobby) as MenuScreen
	assert_true(lobby is MenuLobby, "PLAY > ONLINE opens the lobby screens")
	await wait_frames(2)
	lobby.close()
	await wait_frames(2)
