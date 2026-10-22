extends GutTest
## Update 02 section 5 (T-050): the bots' bonus perk (draw and perk rules), the squad command wheel's state, and the
## pure doorway / nudge / formation rules in BotConfig, against the real tuning in data/gravelight/bots.json.

const PID: int = 77
const KIT: Array = ["ironhide_stout", "second_wind"]
const MAP0_PERKS: Array = ["ironhide_stout", "second_wind", "trigger_tonic", "twin_barrel", "marathon_malt", "hawkeye_brandy",
	"packmule_porter", "blastproof_bock", "overclock_cordial"]

var cfg: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/bots.json")


func before_each() -> void:
	GameState.player_ids = [PID]
	GameState.power_on = true
	PerkManager.reset_match()
	Economy.reset([PID])
	Economy.grant(PID, 50000)


func after_all() -> void:
	GameState.player_ids = [1]
	GameState.power_on = false
	PerkManager.reset_match()


func _rng(seed_v: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_v
	return r


# ---------------------------------------------------------------- bonus perk: the draw

func test_bonus_tuning_shape() -> void:
	var b: Dictionary = cfg["bonus_perk"]
	assert_true(bool(b["enabled"]))
	var perks: Dictionary = GLData.table("perks")["perks"]
	for k: Variant in (b["triggers"] as Dictionary).keys():
		assert_true(perks.has(str(k)), "trigger for a real perk: %s" % str(k))


func test_bonus_draw_is_unique_and_never_a_kit_perk() -> void:
	for s: int in 40:
		var picks: Array[StringName] = BotConfig.pick_bonus_perks(cfg["bonus_perk"], MAP0_PERKS, KIT, 3, _rng(s))
		assert_eq(picks.size(), 3)
		var seen: Dictionary = {}
		for p: StringName in picks:
			assert_ne(p, &"", "seed %d: everyone gets one" % s)
			assert_false(KIT.has(String(p)), "seed %d: %s is a kit perk" % [s, p])
			assert_false(seen.has(p), "seed %d: %s twice" % [s, p])
			seen[p] = true


func test_bonus_draw_is_limited_to_the_map() -> void:
	var map_perks: Array = ["ironhide_stout", "trigger_tonic", "hawkeye_brandy"]
	for s: int in 20:
		var picks: Array[StringName] = BotConfig.pick_bonus_perks(cfg["bonus_perk"], map_perks, KIT, 3, _rng(s))
		for p: StringName in picks:
			assert_true(p == &"" or map_perks.has(String(p)), "%s is on the map" % p)
		assert_eq(picks.count(&""), 1, "two non-kit perks on the map: the third bot gets none")


func test_bonus_draw_varies_and_respects_exclude_and_off() -> void:
	var seen: Dictionary = {}
	for s: int in 30:
		for p: StringName in BotConfig.pick_bonus_perks(cfg["bonus_perk"], MAP0_PERKS, KIT, 1, _rng(s)):
			seen[p] = true
	assert_gt(seen.size(), 3, "the draw is random")
	var ex: Dictionary = {"enabled": true, "exclude": ["trigger_tonic", "twin_barrel", "marathon_malt", "hawkeye_brandy", "packmule_porter", "blastproof_bock"]}
	assert_eq(BotConfig.pick_bonus_perks(ex, MAP0_PERKS, KIT, 1, _rng(3)), [&"overclock_cordial"] as Array[StringName])
	assert_true(BotConfig.pick_bonus_perks({"enabled": false}, MAP0_PERKS, KIT, 3, _rng(1)).is_empty())


func test_bonus_toggle() -> void:
	assert_true(BotConfig.bonus_enabled({}, cfg["bonus_perk"]), "default on")
	assert_false(BotConfig.bonus_enabled({"bot_bonus_perk": false}, cfg["bonus_perk"]), "the setting turns it off")
	assert_false(BotConfig.bonus_enabled({"bot_bonus_perk": true}, {"enabled": false}), "the data turns it off")
	assert_true(GLSettings.values.has("bot_bonus_perk"), "the setting exists")


func test_bonus_trigger_lookup() -> void:
	assert_eq(BotConfig.bonus_trigger(cfg["bonus_perk"], &"trigger_tonic"), "reload")
	assert_eq(BotConfig.bonus_trigger(cfg["bonus_perk"], &"nonsense"), "")


# ---------------------------------------------------------------- bonus perk: the perk rules

func test_bonus_perk_is_outside_the_cap() -> void:
	PerkManager.grant_bonus(PID, &"overclock_cordial")
	assert_true(PerkManager.has_perk(PID, &"overclock_cordial"))
	assert_eq(PerkManager.bonus_perk(PID), &"overclock_cordial")
	assert_eq(PerkManager.capped_count(PID), 0)
	for id: StringName in [&"ironhide_stout", &"trigger_tonic", &"twin_barrel", &"marathon_malt"]:
		assert_eq(PerkManager.buy_for(PID, id), &"ok", String(id))
	assert_eq(PerkManager.owned(PID).size(), 5, "four bought + the bonus")
	assert_eq(PerkManager.buy_for(PID, &"hawkeye_brandy"), &"cap")


func test_bonus_perk_is_kept_on_a_down() -> void:
	PerkManager.grant_bonus(PID, &"marathon_malt")
	PerkManager.grant(PID, &"ironhide_stout")
	PerkManager.grant(PID, &"second_wind")
	PerkManager.on_player_downed(PID)
	assert_eq(PerkManager.owned(PID), [&"marathon_malt"], "the kit perks go, the bonus stays")
	assert_eq(PerkManager.stat(PID, "move_speed_mult", 1.0), 1.07)


func test_no_bonus_for_humans_and_reset() -> void:
	assert_eq(PerkManager.bonus_perk(PID), &"")
	PerkManager.grant(PID, &"ironhide_stout")
	PerkManager.on_player_downed(PID)
	assert_true(PerkManager.owned(PID).is_empty())
	PerkManager.grant_bonus(PID, &"twin_barrel")
	PerkManager.reset_match()
	assert_eq(PerkManager.bonus_perk(PID), &"")
	assert_true(PerkManager.owned(PID).is_empty())


# ---------------------------------------------------------------- the command wheel

func test_wheel_segments() -> void:
	assert_eq(BotConfig.COMMANDS, [&"follow", &"hold", &"repair", &"revive"] as Array[StringName])
	assert_eq(BotConfig.wheel_index(Vector2(0, -100), 4, 28.0), 0, "up: follow")
	assert_eq(BotConfig.wheel_index(Vector2(100, 0), 4, 28.0), 1, "right: hold")
	assert_eq(BotConfig.wheel_index(Vector2(0, 100), 4, 28.0), 2, "down: repair")
	assert_eq(BotConfig.wheel_index(Vector2(-100, 0), 4, 28.0), 3, "left: revive")
	assert_eq(BotConfig.wheel_index(Vector2(60, -70), 4, 28.0), 0, "up and a bit right is still up")
	assert_eq(BotConfig.wheel_index(Vector2(10, 5), 4, 28.0), -1, "dead zone")


func test_wheel_state_press_look_release() -> void:
	var st: BotCommandState = BotCommandState.new(120.0, 28.0)
	assert_false(st.is_open)
	st.look(Vector2(200, 0))
	assert_eq(st.pointer, Vector2.ZERO, "closed: look does nothing")
	st.press()
	assert_true(st.is_open)
	assert_eq(st.selected(), -1)
	st.look(Vector2(15, 0))
	assert_eq(st.selected(), -1, "still in the dead zone")
	st.look(Vector2(300, 0))
	assert_almost_eq(st.pointer.length(), 120.0, 0.01, "clamped to the radius")
	assert_eq(st.selected_command(), &"hold")
	st.look(Vector2(-300, 0))
	st.look(Vector2(-300, 0))
	assert_eq(st.selected_command(), &"revive")
	assert_eq(st.release(), &"revive")
	assert_false(st.is_open)
	assert_eq(st.pointer, Vector2.ZERO)


func test_wheel_release_in_the_middle_cancels() -> void:
	var st: BotCommandState = BotCommandState.new(120.0, 28.0)
	st.press()
	st.look(Vector2(5, -5))
	assert_eq(st.release(), &"")
	st.press()
	st.stick(Vector2(0, 0.9))
	assert_eq(st.selected_command(), &"repair", "the stick points straight at a segment")
	st.cancel()
	assert_false(st.is_open)
	assert_eq(st.selected(), -1)


func test_command_tuning() -> void:
	var c: Dictionary = cfg["commands"]
	for k: String in ["hold_point_range_m", "ring_radius_m", "hold_repair_radius_m", "repair_range_m", "revive_follow_m", "wheel_deadzone_px", "wheel_radius_px"]:
		assert_true(c.has(k), k)
	assert_lt(float(c["wheel_deadzone_px"]), float(c["wheel_radius_px"]))
	var input: Dictionary = GLData.load_json("res://data/gravelight/input_defaults.json")
	assert_true(input.has("bot_command"), "the input action is registered")


# ---------------------------------------------------------------- doorways, nudges, formation

func test_nudge_steps_aside_when_walked_into() -> void:
	var f: Dictionary = cfg["follow"]
	var me: Vector3 = Vector3(0, 0, -1.0)
	assert_true(BotConfig.should_step_aside(me, Vector3.ZERO, Vector3(0, 0, -3.0), false, f), "walking straight at it")
	assert_false(BotConfig.should_step_aside(me, Vector3.ZERO, Vector3(0, 0, 3.0), false, f), "walking away")
	assert_false(BotConfig.should_step_aside(me, Vector3.ZERO, Vector3(3.0, 0, 0), false, f), "walking past")
	assert_false(BotConfig.should_step_aside(me, Vector3.ZERO, Vector3.ZERO, false, f), "standing still")
	assert_false(BotConfig.should_step_aside(Vector3(0, 0, -5.0), Vector3.ZERO, Vector3(0, 0, -3.0), false, f), "too far for a nudge")


func test_choke_steps_aside_when_the_human_is_close() -> void:
	var f: Dictionary = cfg["follow"]
	assert_true(BotConfig.should_step_aside(Vector3(0, 0, -3.0), Vector3.ZERO, Vector3.ZERO, true, f), "parked in a doorway, human 3 m off")
	assert_false(BotConfig.should_step_aside(Vector3(0, 0, -9.0), Vector3.ZERO, Vector3.ZERO, true, f), "human far away")


func test_step_aside_direction_is_perpendicular_and_keeps_its_side() -> void:
	var d: Vector3 = BotConfig.step_aside_dir(Vector3(0.3, 0, -1.0), Vector3.ZERO, Vector3(0, 0, -3.0))
	assert_almost_eq(d.dot(Vector3(0, 0, -1)), 0.0, 0.001, "perpendicular to the human's heading")
	assert_gt(d.x, 0.0, "to the side it already leans to")
	var d2: Vector3 = BotConfig.step_aside_dir(Vector3(0, 0, -1.0), Vector3.ZERO, Vector3.ZERO)
	assert_almost_eq(d2.z, -1.0, 0.001, "a standing human: straight away")


func test_narrow_passage() -> void:
	assert_true(BotConfig.is_narrow(0.6, 0.7, 0.85))
	assert_false(BotConfig.is_narrow(0.6, 2.0, 0.85))


func test_moving_formation_is_beside_and_ahead_never_behind() -> void:
	var f: Dictionary = cfg["follow"]
	var heading: Vector3 = Vector3(0, 0, -4.0)
	var sides: Array[float] = []
	for i: int in 3:
		var off: Vector3 = BotConfig.moving_slot_offset(f, i, heading)
		assert_gte(off.dot(heading.normalized()), 0.0, "slot %d is not behind the leader" % i)
		assert_gt(absf(off.x), 1.0, "slot %d is beside the leader's path" % i)
		sides.append(signf(off.x))
	assert_true(sides.has(1.0) and sides.has(-1.0), "both sides covered")
	assert_eq(BotConfig.moving_slot_offset(f, 0, Vector3.ZERO), Vector3.ZERO)


func test_orders_are_data_driven() -> void:
	assert_eq(BotConfig.order_ids(cfg), BotConfig.COMMANDS, "the shipped wheel: the four built-in orders")
	assert_eq(BotConfig.order_label(cfg, &"hold"), "Hold here")
	var more: Dictionary = {"commands": {"orders": [{"id": "follow", "label": "Follow me"}, {"id": "train", "label": "Train with me"},
		{"id": "hold", "label": "Hold here"}, {"id": "buy_perks", "label": "Buy perks now"}, {"id": "repair"}, {"id": "revive"}]}}
	var ids: Array[StringName] = BotConfig.order_ids(more)
	assert_eq(ids.size(), 6)
	assert_eq(BotConfig.order_label(more, &"buy_perks"), "Buy perks now")
	assert_eq(BotConfig.order_label(more, &"repair"), "Repair", "no label: the id capitalised")
	var st: BotCommandState = BotCommandState.new(120.0, 28.0, ids)
	st.press()
	st.look(Vector2(110, -60))   # 60 degrees: the second of six segments
	assert_eq(st.release(), &"train", "a new order is picked like any other")
	assert_eq(BotConfig.order_ids({}), BotConfig.COMMANDS, "no table: the built-in orders")
