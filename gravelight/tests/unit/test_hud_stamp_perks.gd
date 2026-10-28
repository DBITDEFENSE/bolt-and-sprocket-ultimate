extends GutTest
## T-122: the round stamp shows every digit of a high round (its digit box was one numeral wide and clipped), and a
## campaign / act transition never leaves the perk row hidden (the cutscene parked it 8000 px up and only put it back
## when stopped; the row lives under PerkManager, so it stayed hidden for the rest of the run).


func test_round_stamp_fits_high_rounds() -> void:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	var label: Label = hud.get("_stamp_label") as Label
	var holder: Control = label.get_parent() as Control
	var fs: int = MenuKit.size("hud_stamp")
	var font: Font = label.get_theme_font("font")
	for r: int in [3, 10, 47, 115]:
		hud.call("_on_round_started", r, false)
		var need: float = font.get_string_size(str(r), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		assert_gte(holder.custom_minimum_size.x, need, "round %d: the digit box is as wide as the number" % r)
		var panel: Control = hud.get("_stamp_panel") as Control
		assert_gte(panel.size.x, need, "round %d: and so is the stamp" % r)
	hud.call("_on_round_started", 4, false)
	assert_lt(holder.custom_minimum_size.x, font.get_string_size("44", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, "one digit again: the box shrinks back")


func test_perk_row_comes_back_after_a_transition() -> void:
	GLBus.match_started.emit(&"map00")
	var ph: CanvasLayer = PerkManager.get("_hud") as CanvasLayer
	assert_not_null(ph)
	var cs: Node = (load("res://gravelight/ui/exfil_cutscene.gd") as GDScript).new()
	ph.offset = Vector2(0, -8000)   # what _hide_hud does
	cs.set("_perk_hud_offset", Vector2.ZERO)
	cs.call("_exit_tree")   # the scene change tears the cutscene down without stop()
	cs.free()
	assert_eq(ph.offset, Vector2.ZERO, "the cutscene's exit puts the row back")
	ph.offset = Vector2(0, -8000)
	GLBus.match_started.emit(&"map00")
	assert_eq(ph.offset, Vector2.ZERO, "and a new match always starts with it showing")
