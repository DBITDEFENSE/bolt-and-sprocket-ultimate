extends GutTest
## The retention columns and the sign (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.6, T-113): a read darkens a
## column and sets its flag, a Lodestone shot at the cap shortens the read, three dark columns open the Account,
## the sign loses letters per stage, and the controller's pure rules hold.

var _flags: Dictionary


func before_each() -> void:
	_flags = GameState.flags.duplicate()
	GameState.flags.clear()
	GameState.map_id = &"map04d_mondlicht"


func after_each() -> void:
	GameState.flags = _flags
	GameState.map_id = &""


func test_sign_stages() -> void:
	var stages: Array = ["NOBODY CANCELS", "NOBODY C NCELS", "NOBOD  C NC LS", "N B D  C N  LS"]
	assert_eq(CancelSign.stage_text(stages, 0), "NOBODY CANCELS")
	assert_eq(CancelSign.stage_text(stages, 1), "NOBODY C NCELS")
	assert_eq(CancelSign.stage_text(stages, 3), "N B D  C N  LS")
	assert_eq(CancelSign.stage_text(stages, 9), "N B D  C N  LS", "clamped")
	assert_eq(CancelSign.stage_text([], 2), "")
	var sign: CancelSign = CancelSign.new()
	sign.stages = stages
	add_child_autofree(sign)
	sign.global_position = Vector3(0, 6, 0)
	assert_eq(sign.lit_letters(), 13)
	sign.set_stage(1)
	await wait_seconds(1.3)
	assert_eq(sign.lit_letters(), 12, "one letter fell")
	sign.set_stage(3)
	await wait_seconds(1.3)
	assert_eq(sign.lit_letters(), 7, "seven left")
	sign.lights_out()


func test_controller_rules() -> void:
	assert_false(MondlichtController.account_opens(2, 3))
	assert_true(MondlichtController.account_opens(3, 3))
	assert_almost_eq(MondlichtController.clock_after(-1.0, 5.0), -1.0, 0.001, "an idle clock stays idle")
	assert_almost_eq(MondlichtController.clock_after(10.0, 4.0), 6.0, 0.001)
	assert_almost_eq(MondlichtController.clock_after(2.0, 4.0), 0.0, 0.001, "never below zero")
	assert_eq(MondlichtController.warning_due(200.0, [180.0, 60.0], []), -1, "not yet")
	assert_eq(MondlichtController.warning_due(170.0, [180.0, 60.0], []), 0, "three minutes")
	assert_eq(MondlichtController.warning_due(170.0, [180.0, 60.0], [0]), -1, "given")
	assert_eq(MondlichtController.warning_due(50.0, [180.0, 60.0], [0]), 1, "one minute")


func test_ray_near_the_cap() -> void:
	assert_true(RetentionColumn.ray_near(Vector3.ZERO, Vector3.FORWARD, Vector3(0.3, 0, -6), 1.4))
	assert_false(RetentionColumn.ray_near(Vector3.ZERO, Vector3.FORWARD, Vector3(3.0, 0, -6), 1.4), "wide")
	assert_false(RetentionColumn.ray_near(Vector3.ZERO, Vector3.BACK, Vector3(0, 0, -6), 1.4), "behind")
	assert_false(RetentionColumn.ray_near(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -30), 1.4), "too far")


func test_a_read_darkens_the_column_and_flags_it() -> void:
	GLVO.reset_match()
	var col: RetentionColumn = RetentionColumn.new()
	col.index = 2
	col.column_id = &"column_2"
	col.panel_key = "panel.magpie_mead"
	add_child_autofree(col)
	col.global_position = Vector3(50, 0, 50)
	await wait_physics_frames(1)
	assert_false(col.dark)
	assert_almost_eq(col.hold_time(null), 4.0, 0.001, "a 4 s read")
	col.lift_cap()
	assert_true(col.cap_lifted and GameState.has_flag(&"cap_lifted_2"))
	assert_almost_eq(col.hold_time(null), 1.0, 0.001, "the cap lifted: 1 s")
	col.read_terms(0)
	assert_true(col.dark)
	assert_true(GameState.has_flag(&"column_2_dark"))
	assert_false(col.can_interact(null), "read once")
	col.read_terms(0)
	assert_true(col.dark, "a second read is nothing")


func test_console_state_machine_and_vote() -> void:
	assert_eq(AccountConsole.state_for(false, false, false, false), AccountConsole.C.DARK)
	assert_eq(AccountConsole.state_for(true, false, false, false), AccountConsole.C.SHIELDED)
	assert_eq(AccountConsole.state_for(true, true, false, false), AccountConsole.C.COVER)
	assert_eq(AccountConsole.state_for(true, true, true, false), AccountConsole.C.VOTE)
	assert_eq(AccountConsole.state_for(true, true, true, true), AccountConsole.C.DONE)
	assert_true(AccountConsole.vote_complete([1], [1]), "solo: one vote")
	assert_false(AccountConsole.vote_complete([1], [1, 2]), "co-op: everyone")
	assert_true(AccountConsole.vote_complete([2, 1], [1, 2]))
	assert_false(AccountConsole.vote_complete([], []), "nobody alive: no vote")
