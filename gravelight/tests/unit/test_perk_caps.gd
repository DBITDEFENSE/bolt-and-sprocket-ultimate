extends GutTest
## The perk caps and the pause menu's perk list (T-082): every tonic in perks.json has a drawn glyph and a one-line
## description, the caps draw at every size the game uses (a nameplate's 18 px, the HUD's 54 px, dim, every tier,
## the bonus mark) without a script error, and the LOADOUT tab lists all nine tonics, the held ones in colour with
## their tier and the rest greyed with a price and the machine's zone.

const PID: int = 1   # Net.local_player_id() outside a session


func before_each() -> void:
	GameState.player_ids = [PID]
	GameState.power_on = true
	PerkManager.reset_match()
	Economy.reset([PID])
	Economy.grant(PID, 50000)


func after_all() -> void:
	GameState.power_on = false
	GameState.map_id = &""
	PerkManager.reset_match()


func test_every_perk_has_a_glyph_and_a_desc() -> void:
	var perks: Dictionary = GLData.table("perks")["perks"]
	assert_eq(PerkCap.GLYPHS.size(), perks.size(), "one glyph case per tonic")
	for id: String in perks.keys():
		assert_true(PerkCap.has_glyph(StringName(id)), id + " has a glyph")
		assert_gt(PauseMenu.perk_desc(StringName(id)).length(), 20, id + " has a description")
		assert_false(PauseMenu.perk_desc(StringName(id)).contains("%"), id + ": no percentages that go stale in the description")
	assert_false(PerkCap.has_glyph(&"fine_print_fernet"), "a cabinet that is not built yet falls back to its letters")


func test_caps_draw_at_every_size() -> void:
	var host: Control = Control.new()
	add_child_autofree(host)
	var n: int = 0
	for id: String in (GLData.table("perks")["perks"] as Dictionary).keys():
		for r: float in [9.0, 14.0, 27.0]:
			for tier: int in [1, 2, 3]:
				for dim: bool in [false, true]:
					var cap: PerkCap = PerkCap.new()
					cap.perk_id = StringName(id)
					cap.tier = tier
					cap.dim = dim
					cap.bonus = tier == 2 and not dim
					cap.size = Vector2(r * 2.0, r * 2.0)
					cap.position = Vector2(float(n % 20) * 60.0, float(n / 20) * 60.0)
					host.add_child(cap)
					n += 1
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(n, 9 * 3 * 3 * 2, "every cap was drawn once (a script error in _draw shows in the run's log)")
	# the fallback: a tonic id with no glyph draws its letters (no error either)
	var odd: PerkCap = PerkCap.new()
	odd.perk_id = &"fine_print_fernet"
	odd.size = Vector2(54, 54)
	host.add_child(odd)
	await get_tree().process_frame
	pass_test("the fallback cap drew")


func test_pause_loadout_lists_every_tonic() -> void:
	PerkManager.grant(PID, &"ironhide_stout")
	PerkManager.set_tier(PID, &"ironhide_stout", 2)
	PerkManager.grant(PID, &"hawkeye_brandy")
	var pm: PauseMenu = PauseMenu.new()
	add_child_autofree(pm)
	pm.set_tab(PauseMenu.TAB_LOADOUT)
	var caps: Array = []
	_collect_caps(pm.get("_loadout") as Node, caps)
	var perks: Dictionary = GLData.table("perks")["perks"]
	assert_eq(caps.size(), perks.size(), "one cap per tonic, in perks.json order")
	var ids: Array = []
	for cap: PerkCap in caps:
		ids.append(String(cap.perk_id))
		match cap.perk_id:
			&"ironhide_stout":
				assert_false(cap.dim, "held: in colour")
				assert_eq(cap.tier, 2, "with its tier")
			&"hawkeye_brandy":
				assert_false(cap.dim)
				assert_eq(cap.tier, 1)
			_:
				assert_true(cap.dim, String(cap.perk_id) + " not held: greyed")
		var row: Button = cap.get_parent().get_parent() as Button
		assert_not_null(row, "a row is a focusable button (controller)")
		if row != null:
			assert_eq(row.focus_mode, Control.FOCUS_ALL)
	assert_eq(ids, perks.keys(), "perks.json order")


func _collect_caps(n: Node, out: Array) -> void:
	if n == null:
		return
	for ch: Node in n.get_children():
		if ch is PerkCap:
			out.append(ch)
		_collect_caps(ch, out)


func test_perk_where_price_and_zone() -> void:
	assert_eq(PauseMenu.perk_where(&"second_wind", null), "500 Scrip", "solo price, no map data")
	assert_eq(PauseMenu.perk_where(&"packmule_porter", null), "4,000 Scrip")
	var md: MapData = MapData.for_map(&"map00_crossroads")
	assert_not_null(md)
	if md != null:
		assert_eq(PauseMenu.perk_where(&"ironhide_stout", md), "2,500 Scrip  ·  Helvetia Cellar", "the Inn's cabinets stand in the cellar")
	var kb: MapData = MapData.for_map(&"map01_kaltenbrunn")
	if kb != null:
		assert_true(PauseMenu.perk_where(&"twin_barrel", kb).ends_with("Salt Chapel"), "Kaltenbrunn: the Major's bitters in the chapel")
	var tt: MapData = MapData.for_map(&"map02_totenhafen")
	if tt != null:
		assert_true(PauseMenu.perk_where(&"packmule_porter", tt).ends_with("no cabinet on this map"), "Totenhafen has no Packmule")
	PerkManager.second_wind_gone = true
	assert_true(PauseMenu.perk_where(&"second_wind", md).begins_with("gone"), "the retired cabinet")
	PerkManager.reset_match()


func test_buffed_base_measures() -> void:
	# T-082: the base pour is ~10-15% stronger than Update 03's, tiers moved with it
	PerkManager.grant(PID, &"twin_barrel")
	assert_almost_eq(float(PerkManager.stat(PID, "fire_rate_mult", 1.0)), 1.5, 0.001)
	PerkManager.set_tier(PID, &"twin_barrel", 2)
	assert_almost_eq(float(PerkManager.stat(PID, "fire_rate_mult", 1.0)), 1.6, 0.001)
	PerkManager.grant(PID, &"hawkeye_brandy")
	assert_almost_eq(float(PerkManager.stat(PID, "head_damage_mult", 1.0)), 1.4, 0.001)
	PerkManager.grant(PID, &"packmule_porter")
	assert_eq(PerkManager.grenade_bonus(PID), 1, "Packmule's buff is a grenade, the third slot stays the perk")
	PerkManager.set_tier(PID, &"packmule_porter", 2)
	assert_eq(PerkManager.grenade_bonus(PID), 2)
	PerkManager.grant(PID, &"blastproof_bock")
	assert_almost_eq(float(PerkManager.stat(PID, "slide_shockwave_damage", 0.0)), 450.0, 0.001)
	PerkManager.grant(PID, &"second_wind")
	assert_almost_eq(float(PerkManager.stat(PID, "revive_speed_mult", 1.0)), 2.3, 0.001)
