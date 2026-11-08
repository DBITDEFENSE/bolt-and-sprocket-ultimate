extends GutTest
## T-218 the menus / settings / HUD polish: slider readouts, controller names, subtitle breaks and styles, the main
## menu's footer keys, and the Settings screen's fixed tab bar.


func test_slider_text() -> void:
	assert_eq(MenuKit.slider_text(0.8, 0.0, 1.0, 0.05), "80%", "0..1 reads as a percent")
	assert_eq(MenuKit.slider_text(90.0, 65.0, 110.0, 1.0), "90", "whole steps: an integer")
	assert_eq(MenuKit.slider_text(1.234, 0.0, 2.0, 0.1), "1.23")
	assert_eq(MenuKit.slider_text(1.25, 0.1, 4.0, 0.05, "x"), "1.25x")
	assert_eq(MenuKit.slider_text(1.5, 0.0, 1.5, 0.05, "pct"), "150%")
	assert_eq(MenuKit.slider_text(80.0, 65.0, 110.0, 1.0, "deg"), "80°")
	assert_eq(MenuKit.slider_text(75.0, 50.0, 100.0, 5.0, "%d%%"), "75%")


func test_row_prints_a_slider_value_and_follows_it() -> void:
	var s: HSlider = MenuKit.slider(0.0, 1.0, 0.05, 0.5, func(_v: float) -> void: pass, "pct")
	var r: HBoxContainer = MenuKit.row("Volume", s)
	add_child_autofree(r)
	var v: Label = r.find_child("Value", true, false) as Label
	assert_not_null(v, "a value label next to the slider")
	assert_eq(v.text, "50%")
	s.value = 0.75
	assert_eq(v.text, "75%", "the label follows the slider")


func test_switch_icons_differ_on_and_off() -> void:
	var on: Texture2D = MenuKit.switch_icon(true, false)
	var off: Texture2D = MenuKit.switch_icon(false, false)
	assert_eq(on.get_size(), Vector2(52, 26))
	var a: Image = on.get_image()
	var b: Image = off.get_image()
	assert_gt(a.get_pixel(40, 13).r, b.get_pixel(40, 13).r + 0.3, "on: the knob is on the right")
	assert_gt(b.get_pixel(12, 13).a, 0.5, "off: a visible knob on the left, not a lone dot")
	assert_same(MenuKit.switch_icon(true, false), on, "drawn once")


func test_pad_names() -> void:
	assert_eq(MenuSettings.pad_name("LEFT SHOULDER"), "LB")
	assert_eq(MenuSettings.pad_name("TRIGGER RIGHT+"), "RT")
	assert_eq(MenuSettings.pad_name("LEFT Y-"), "Left stick up")
	assert_eq(MenuSettings.pad_name("A"), "A", "face buttons stay")
	assert_eq(MenuSettings.pad_name("SOMETHING"), "SOMETHING")


func test_subtitles_break_at_a_clause() -> void:
	var s: GDScript = load("res://gravelight/ui/subtitles.gd") as GDScript
	var line: String = "Crossroads, this is Fasbender. The Ledger's still counting. Keep the lamps lit and the doors shut until the relief column comes."
	var chunks: PackedStringArray = s.call("chunk", line, 84)
	assert_gt(chunks.size(), 1)
	assert_true(chunks[0].ends_with("."), "the first chunk ends on a full stop: %s" % chunks[0])
	for c: String in chunks:
		assert_lte(c.length(), 84)
	assert_eq(" ".join(chunks), line, "no word lost or doubled")
	var plain: PackedStringArray = s.call("chunk", "word ".repeat(40).strip_edges(), 84)
	assert_gt(plain.size(), 1, "no punctuation: the old word wrap")


func test_subtitle_styles() -> void:
	var s: GDScript = load("res://gravelight/ui/subtitles.gd") as GDScript
	assert_eq(s.call("size_scale", "normal"), 1.0)
	assert_gt(s.call("size_scale", "largest"), s.call("size_scale", "large"))
	assert_eq(s.call("back_alpha", "off"), 0.0)
	assert_gt(s.call("back_alpha", "dark"), s.call("back_alpha", "light"))
	assert_true(GLSettings.values.has("subtitle_size") and GLSettings.values.has("subtitle_back"))
	assert_eq(MenuSettings.SUBTITLE_SIZES.size(), 3)
	assert_eq(MenuSettings.SUBTITLE_BACKS[0], "off", "off by default: the look is unchanged until asked")


func test_footer_keys_follow_the_device() -> void:
	var mm: GDScript = load("res://gravelight/ui/main_menu.gd") as GDScript
	assert_string_contains(mm.call("hint_text", false), "ENTER")
	assert_string_contains(mm.call("hint_text", true), "A  select")


func test_settings_tabs_stay_above_the_scroll_and_mark_the_open_tab() -> void:
	var m: MenuSettings = MenuSettings.new()
	add_child_autofree(m)
	await wait_process_frames(2)
	assert_not_null(m.header.find_child("Tabs", true, false), "the tab bar is in the fixed header")
	assert_null(m.content.find_child("Tab_Gameplay", true, false), "not in the scrolling content")
	m.call("_set_tab", 2)
	await wait_process_frames(3)
	var audio: Button = m.header.find_child("Tab_Audio", true, false) as Button
	var game: Button = m.header.find_child("Tab_Gameplay", true, false) as Button
	assert_eq(audio.get_theme_color("font_color"), MenuKit.GOLD, "the open tab is gold")
	assert_ne(game.get_theme_color("font_color"), MenuKit.GOLD)
	assert_eq(m.get_viewport().gui_get_focus_owner(), audio, "the focus stays on the open tab")
