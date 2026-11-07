extends GutTest
## T-183: the left-side squad panel shows each teammate's name, state and tonics, and no numbers; the scoreboard
## (hold ui_scoreboard) keeps the Scrip and kills; the HUD's own perk caps are smaller; every tonic's cap has its own
## enamel and draws at the squad panel's 16 px with every tier.

var _s: NetMatch


func before_all() -> void:
	GLSettings.apply_bindings()   # Gravelight's bindings exist only once applied (T-024)


func before_each() -> void:
	PerkManager.reset_match()
	GameState.player_ids = [1, 2, 3, 4]
	Economy.reset([1, 2, 3, 4])
	_s = NetMatch.new()
	for pid: int in [1, 2, 3, 4]:
		_s.players[pid] = null
		_s.coop.add(pid)
	_s.companions[90] = null
	_s.coop.add_companion(90)


func after_each() -> void:
	if is_instance_valid(_s):
		_s.free()
	PerkManager.reset_match()
	GameState.player_ids = [1]


func after_all() -> void:
	Economy.reset([1])


func test_rows_are_the_teammates_with_no_numbers() -> void:
	var me: int = Net.local_player_id()
	var rows: Array = CoopHud.squad_rows(_s, me)
	var pids: Array = []
	for r: Dictionary in rows:
		pids.append(int(r["pid"]))
		assert_false(r.has("scrip"), "no Scrip on the panel")
		assert_false(r.has("kills"), "no kills on the panel")
		assert_false(r.has("health"), "no health bar on the panel")
		assert_ne(str(r["name"]), "", "a name")
	assert_false(pids.has(me), "your own row is not on the panel")
	assert_eq(pids, [2, 3, 4, 90], "the squad by pid, then the companion")
	assert_true(bool(rows[3]["companion"]), "the companion's row is marked")


func test_states() -> void:
	_s.coop.down(2, 30.0)
	_s.coop.down(3, 30.0)
	_s.coop.set_reviver(3, 1, true)
	_s.coop.players[4] = {"life": CoopState.Life.DEAD, "bleed": 0.0, "reviver": 0}
	_s.coop.players[90] = {"life": CoopState.Life.DEAD, "bleed": 0.0, "reviver": 0}
	var by: Dictionary = {}
	for r: Dictionary in CoopHud.squad_rows(_s, 1):
		by[int(r["pid"])] = r
	assert_eq(str(by[2]["state"]), "down")
	assert_eq(CoopHud.state_text(by[2]), "DOWN 30", "the bleed-out clock")
	assert_eq(str(by[3]["state"]), "reviving")
	assert_eq(CoopHud.state_text(by[3]), "REVIVING")
	assert_eq(CoopHud.state_text(by[4]), "BLED OUT", "a squad member is back next round")
	assert_eq(CoopHud.state_text(by[90]), "OUT COLD", "a companion who bled out")
	_s.coop.revive(2)
	assert_eq(CoopHud.state_text(CoopHud.squad_rows(_s, 1)[0]), "", "standing: no word")


func test_caps_bonus_first_with_tiers() -> void:
	GameState.power_on = true
	PerkManager.grant(2, &"ironhide_stout")
	PerkManager.grant(2, &"second_wind")
	PerkManager.set_tier(2, &"second_wind", 3)
	PerkManager.grant_bonus(2, &"magpie_mead")
	var caps: Array = CoopHud.caps_of(2)
	assert_eq(caps.size(), 3)
	assert_eq(caps[0], [&"magpie_mead", 1, true], "the bonus perk first, ringed")
	assert_eq(caps[2], [&"second_wind", 3, false], "with its tier")
	GameState.power_on = false


func test_scoreboard_keeps_the_numbers() -> void:
	Economy.grant(3, 1234)
	var rows: Array = CoopHud.board_rows(_s, null)
	assert_eq(int(rows[0]["pid"]), Net.local_player_id(), "you first")
	assert_true(bool(rows[0]["you"]))
	for r: Dictionary in rows:
		assert_true(r.has("scrip") and r.has("kills"), "the scoreboard has the numbers")
		if int(r["pid"]) == 3:
			assert_eq(int(r["scrip"]), Economy.get_scrip(3))
		if bool(r["companion"]):
			assert_eq(int(r["scrip"]), -1, "a companion has no account")


func test_scoreboard_binding_exists() -> void:
	assert_true(InputMap.has_action(&"ui_scoreboard"), "the hold-to-show key is bound (input_defaults)")


func test_panel_and_board_draw() -> void:
	var hud: CoopHud = CoopHud.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	var panel: Control = hud.get("_panel") as Control
	assert_not_null(panel)
	_s.coop.down(2, 20.0)
	PerkManager.grant(3, &"hawkeye_brandy")
	panel.call("set_rows", CoopHud.squad_rows(_s, 1))
	assert_eq((panel.get("rows") as Array).size(), 4)
	var rh: float = float(MenuKit.hud("squad_row_h", 24.0))
	assert_almost_eq(panel.size.y, rh * 4.0, 0.01, "one compact row per teammate")
	assert_lt(panel.size.x, 420.0, "a narrow panel")
	hud.force_board = true
	var board: Control = hud.get("_board") as Control
	board.set("rows", CoopHud.board_rows(_s, null))
	board.visible = true
	board.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	pass_test("drew without a script error")


func test_hud_perk_caps_are_smaller() -> void:
	var cap: float = float(MenuKit.hud("perk_cap", 0.0))
	assert_lt(cap, 54.0, "smaller than the old 54 px (T-183)")
	assert_gte(cap, 30.0, "big enough for the tier band's numeral (r >= 15)")
	assert_lte(float(MenuKit.hud("squad_cap", 99.0)), 18.0, "the squad panel's caps are really small")


func test_every_tonic_has_its_own_enamel() -> void:
	var ids: Array = (GLData.table("perks")["perks"] as Dictionary).keys()
	for id: String in ids:
		assert_true(PerkCap.ENAMEL.has(id), id + " has a cap enamel")
		assert_true(["cream", "ink", "red"].has(PerkCap.tone(StringName(id))), id + " has a glyph tone")
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: Color = PerkCap.enamel(StringName(ids[i]))
			var b: Color = PerkCap.enamel(StringName(ids[j]))
			var d: float = Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			assert_gt(d, 0.2, "%s and %s are told apart by colour (%.2f)" % [ids[i], ids[j], d])


func test_small_caps_draw_every_tier() -> void:
	var host: Control = Control.new()
	add_child_autofree(host)
	var n: int = 0
	for id: String in (GLData.table("perks")["perks"] as Dictionary).keys():
		for r: float in [6.0, 8.0, 10.0, 20.0]:
			for tier: int in [1, 2, 3, 4]:
				var cap: PerkCap = PerkCap.new()
				cap.perk_id = StringName(id)
				cap.tier = tier
				cap.bonus = tier == 1
				cap.size = Vector2(r * 2.0, r * 2.0)
				cap.position = Vector2(float(n % 24) * 44.0, float(n / 24) * 44.0)
				host.add_child(cap)
				n += 1
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(n, (GLData.table("perks")["perks"] as Dictionary).size() * 16)
