extends "res://gravelight/tools_src/m2_smoke_base.gd"
## The sailing finale smoke (UPDATE 10 contracts C2 "the boat" and C3 s8-s10, DECISIONS T-153): skip Letzte Fahrt to
## the curtain; the curtain floods the dock to spring height and makes the boat ready; cast off; sail_t runs (shortened
## to `SAIL_S` here), the searchlight tracks the boat, boarders come aboard, a player off the side is hauled back, the
## sea cell hides the pen hall; at the depth mark lf_sailed completes s9 and the dive cutscene (s10) plays: dived,
## the boat's art goes down and comes back, the hall comes back, the quest completes with its rewards. Also one of the
## diesel holds (the battery cell: the lights go out while it runs).

const QUEST: StringName = &"map02_letzte_fahrt"
const SAIL_S: float = 24.0


func _init() -> void:
	tag = "sail"
	_timeout_s = 600.0


func _body() -> void:
	GameState.power_on = true
	GLBus.power_activated.emit()
	await _frames(5)
	_check(QuestManager.is_active(QUEST, &"s0a_load") or QuestManager.is_step_done(QUEST, &"s0a_load"), "Letzte Fahrt is loaded on map02")
	# --- a diesel hold: the battery cell in the dark
	QuestManager.debug_skipto(QUEST, &"s5b_battery")
	await _frames(5)
	var bat: DieselHoldout = _g("Diesel_inj_battery") as DieselHoldout
	_check(bat != null and QuestManager.is_active(QUEST, &"s5b_battery"), "the battery hold is placed and its step is active")
	if bat != null:
		bat.seconds = 4.0
		await _tp(bat.global_position + Vector3(0, 0.2, 1.0))
		bat.start(1)
		await _frames(5)
		_check(GameState.has_flag(&"lights_out"), "lifting the cell puts the lower pens' lights out")
		await _secs(6.0)
		_check(bat.state == HoldoutStation.State.DONE and GameState.has_flag(&"inj_battery") and not GameState.has_flag(&"lights_out"), "the cell is up, the flag is set, the lights are back")
		_check(QuestManager.is_step_done(QUEST, &"s5b_battery"), "s5b_battery completes")
	# --- to the curtain
	QuestManager.debug_skipto(QUEST, &"s8_curtain")
	await _frames(5)
	GameState.set_flag(&"lf_key_turned", true)
	var lever: QuestInteract = _g("CurtainLever") as QuestInteract
	_check(lever != null and QuestManager.is_active(QUEST, &"s8_curtain"), "the curtain lever is placed and s8 is active")
	await _tp(lever.global_position + Vector3(0, 0.2, 1.0))
	await _use(lever)
	await _frames(5)
	_check(GameState.has_flag(&"curtain_open") and QuestManager.is_step_done(QUEST, &"s8_curtain"), "the curtain opened (s8 done)")
	_check(_tide.stage == &"spring", "the curtain floods the dock to spring height")
	var sail: UboatSail = _g("UboatSail") as UboatSail
	_check(sail != null and sail.state == UboatSail.State.READY, "the boat is ready to cast off")
	if sail == null:
		return
	sail._cfg["sail_seconds"] = SAIL_S
	sail._cfg["board_every_s"] = 2.0
	await _tp(sail.global_position + sail.global_basis * Vector3(0.8, 0.2, 0.6))
	await _use(sail)
	await _frames(5)
	_check(sail.state == UboatSail.State.SAILING and GameState.has_flag(&"sailing"), "cast off: she sails (flag sailing)")
	var sl: Searchlight = _g("Searchlight") as Searchlight
	_check(sl != null and sl.auto_track and sl.is_on(), "the tower searchlight tracks the boat")
	await _secs(SAIL_S * 0.4)
	_check(sail.sail_t > 0.25 and sail.sail_t < 0.7, "sail_t runs (%.2f)" % sail.sail_t)
	_check(sail.boarders_sent > 0, "boarders came aboard (%d)" % sail.boarders_sent)
	var vc: Node = _map.get_node_or_null("ViewCells")
	var has_cell: bool = false
	if vc != null:
		for c: Variant in vc.get("cells"):
			if str((c as Dictionary).get("name", "")) == "SAIL":
				has_cell = true
	_check(vc == null or has_cell, "the sea cell hides the pen hall around the deck")
	await _tp(Vector3(17.0, 0.2, 62.0))
	await _secs(1.2)
	_check(sail.overboard_saves > 0 and UboatSail.aboard(_p.global_position, sail._aboard_box()), "a player off the boat is hauled back aboard")
	_dir.kill_all(true)
	var done: bool = await _until(func() -> bool: return GameState.has_flag(&"lf_sailed"), SAIL_S + 5.0)
	_check(done and QuestManager.is_step_done(QUEST, &"s9_sail"), "at the depth mark: lf_sailed, s9 done")
	# --- the dive (s10 runs its runner)
	var scrip: int = Economy.get_scrip(1)
	var dived: bool = await _until(func() -> bool: return GameState.has_flag(&"dived"), 30.0)
	_check(dived, "she dives (flag dived)")
	var complete: bool = await _until(func() -> bool: return QuestManager.is_complete(QUEST), 30.0)
	_check(complete, "the dive cutscene ends and Letzte Fahrt completes")
	_check(Economy.get_scrip(1) >= scrip + 2500, "the egg paid 2500 Scrip (%d -> %d)" % [scrip, Economy.get_scrip(1)])
	_check(ProfileSave.has_intel(&"INT_M2_HALE_TELEGRAM"), "the Hale telegram is in the Archive")
	_check((ProfileSave.profile.get("calling_cards", []) as Array).has("CARD_LETZTE_FAHRT"), "the calling card CARD_LETZTE_FAHRT")
	var art: Node3D = _map.get_node_or_null("Dressing/U1047") as Node3D
	_check(art == null or absf(art.position.y - 1.0) < 1.5, "the boat's art is back in the pen after the cutscene")
	var cell_gone: bool = true
	if vc != null:
		for c2: Variant in vc.get("cells"):
			if str((c2 as Dictionary).get("name", "")) == "SAIL":
				cell_gone = false
	_check(cell_gone and not GameState.has_flag(&"sailing"), "the pen hall comes back; sailing is off")
