extends GutTest
## UPDATE 10 s6 item 6 (T-162): transitions as events. The exfil cutscene's preload (Campaign.preload_next) is
## idempotent for every campaign target and agrees with LoadingScreen.preload_scene; every transition path shows the
## card (campaign travel, online travel and online match start go through LoadingScreen.go); the exfil beacon starts the
## preload for every act it can lead to; every playable map has a card (art, lore line).

const CHAIN: PackedStringArray = ["map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]


func before_each() -> void:
	Campaign.preloading = ""
	LoadingScreen.preloaded = ""


func after_each() -> void:
	Campaign.preloading = ""
	LoadingScreen.preloaded = ""


## One map at a time, the way the game does it (the exfil cutscene asks, the thread loads, the card collects it).
func _drain(scene: String) -> void:
	if LoadingScreen.preloaded != scene:
		return
	ResourceLoader.load_threaded_get(scene)   # (blocks until the thread is done: the card does this when it swaps)
	LoadingScreen.preloaded = ""


func test_preload_next_is_idempotent_for_every_target() -> void:
	for id: String in CHAIN:
		var scene: String = Campaign.scene_for(StringName(id))
		assert_true(ResourceLoader.exists(scene), "%s has a scene" % id)
		Campaign.preloading = ""
		LoadingScreen.preloaded = ""
		assert_true(Campaign.preload_next(StringName(id)), "%s: asked once" % id)
		assert_eq(Campaign.preloading, scene, "%s: the scene being prepared" % id)
		assert_true(Campaign.preload_next(StringName(id)), "%s: asked twice is fine" % id)
		assert_eq(Campaign.preloading, scene, "%s: still the same request" % id)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(LoadingScreen.preloaded, scene, "%s: the threaded load is the one request" % id)
		await _drain(scene)


func test_an_unknown_target_clears_itself() -> void:
	Campaign.preload_next(&"map99_nowhere")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(Campaign.preloading, "", "no scene behind it: the request is dropped")
	assert_eq(LoadingScreen.preloaded, "")


func test_loading_screen_preload_scene_is_idempotent() -> void:
	var scene: String = Campaign.scene_for(&"map04b_kranich")
	assert_true(LoadingScreen.preload_scene(scene), "the first request starts a threaded load")
	assert_eq(LoadingScreen.preloaded, scene)
	assert_true(LoadingScreen.preload_scene(scene), "a second request for the same scene is a no-op that says yes")
	assert_false(LoadingScreen.preload_scene(""), "an empty path is refused")
	assert_false(LoadingScreen.preload_scene("res://nothing/here.tscn"), "a missing scene is refused")
	assert_eq(LoadingScreen.preloaded, scene, "and the refusals left the request alone")
	await _drain(scene)   # (collect the thread's result so the run ends clean)


func test_every_path_into_a_map_shows_the_card() -> void:
	var net: String = FileAccess.get_file_as_string("res://gravelight/autoload/net.gd")
	var i: int = net.find("func _begin_match(")
	var body: String = net.substr(i, net.find("\nfunc ", i + 10) - i)
	assert_true(body.contains("LoadingScreen.go("), "Net._begin_match (online start and travel) goes through the loading card")
	assert_false(body.contains("change_scene_to_file(scene)"), "and no longer swaps the scene bare")
	var camp: String = FileAccess.get_file_as_string("res://gravelight/world/campaign.gd")
	assert_true(camp.contains("LoadingScreen.go(tree, scene"), "Campaign.travel (solo) goes through the loading card")
	var menu: String = FileAccess.get_file_as_string("res://gravelight/ui/menu_character.gd")
	assert_true(menu.contains("LoadingScreen.go("), "the map select goes through the loading card")


func test_the_exfil_beacon_starts_the_preload_for_every_act() -> void:
	var src: String = FileAccess.get_file_as_string("res://gravelight/world/exfil_point.gd")
	var i: int = src.find("func _begin_cutscene(")
	var body: String = src.substr(i, src.find("\nfunc ", i + 10) - i)
	assert_true(body.contains("Campaign.preload_next(target_id())"), "the cutscene's start preloads the next map, whichever it is")
	for from_id: String in ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake"]:
		var ex: Dictionary = Campaign.exfil_cfg(StringName(from_id))
		assert_false(ex.is_empty(), "%s has an exfil block" % from_id)
		if not ex.is_empty():
			assert_true(Campaign.scene_exists(StringName(str(ex.get("target", "")))), "%s leads to a real scene (%s)" % [from_id, str(ex.get("target", ""))])


func test_every_map_has_a_card_with_art_and_a_lore_line() -> void:
	for id: String in ["map00_crossroads"] + Array(CHAIN):
		assert_ne(LoadingScreen.lore_line(id, 0), "", "%s has a lore line" % id)
		assert_ne(LoadingScreen.pick_tip(0), "")
	assert_ne(LoadingScreen.transition_line("map04b_kranich", "map04c_groomlake"), "", "the Kranich's crash has its own line")
