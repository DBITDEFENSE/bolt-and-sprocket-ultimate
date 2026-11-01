extends GutTest
## T-140 (UPDATE 09 section 6): the zombies mode is CLAUDE ZOMBIES; the constants, the data titles and the wordmark.

func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_constants() -> void:
	assert_eq(Game.GAME_MODE_NAME, "CLAUDE ZOMBIES")
	assert_eq(Game.GAME_MODE_NAME_TITLE, "Claude Zombies")
	assert_eq(Game.GAME_TITLE, "TERMS & CONDITIONS", "the umbrella title stays")


func test_hub_door_title() -> void:
	var hub: Dictionary = _json("res://data/hub.json")
	var found: bool = false
	for d: Dictionary in hub["doors"]:
		if d["id"] == "gl":
			found = true
			assert_eq(d["title"], Game.GAME_MODE_NAME)
	assert_true(found, "the gl door exists (id unchanged)")
	for d: Dictionary in hub["doors"]:
		assert_ne(str(d["title"]).to_upper(), "GRAVELIGHT")


func test_ui_json_titles() -> void:
	var s: String = FileAccess.get_file_as_string("res://data/gravelight/ui.json")
	assert_false(s.contains("\"title\": \"GRAVELIGHT\""))
	var credits: Array = _json("res://data/gravelight/cards_m4.json")["credits"]
	assert_eq(credits[0], Game.GAME_MODE_NAME)


func test_settings_labels() -> void:
	assert_false(FileAccess.get_file_as_string("res://data/settings_page.json").contains("(Gravelight)"))


func test_wordmark_files() -> void:
	for f: String in ["claude_zombies.svg", "claude_zombies.png", "claude_zombies_icon.png"]:
		assert_true(FileAccess.file_exists("res://gravelight/ui/wordmark/" + f), f)
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path("res://gravelight/ui/wordmark/claude_zombies.png"))
	assert_not_null(img)
	assert_eq(img.get_width(), 2048)
	assert_true(img.detect_alpha() != Image.ALPHA_NONE, "transparent")
	var icon: Image = Image.load_from_file(ProjectSettings.globalize_path("res://web/favicon.png"))
	assert_eq(icon.get_width(), 256)


func test_menu_kit_wordmark() -> void:
	var w: Control = MenuKit.wordmark(100.0)
	assert_true(w is TextureRect)
	assert_almost_eq(w.custom_minimum_size.y, 100.0, 0.01)
	assert_not_null((w as TextureRect).texture)
	w.free()
