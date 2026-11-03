extends "res://gravelight/tools_src/m2_smoke_base.gd"
## Letzte Fahrt starts in a plain match and is findable (UPDATE 10 s10, DECISIONS T-173). map02.tscn loaded the way
## a menu match loads it (no launcher forcing, no campaign, rounds running from round 1, no bots), then: the quest is
## loaded and its first step (a coffin on the crane hook) is live in round 1 with the coffins and the hook usable;
## the hook's lamp is lit while it waits; the first-sight map notes cover the hook, the coffins, the sea stairs, the
## radios and the machine; the Operator's round-2 pointer names the crane; hooking a coffin finishes s0a, puts the lamp
## out and names the Pumpenschalter; after the power the pause OBJECTIVES' current line points at the radios and the
## next round's pointer names them.

const QUEST: StringName = &"map02_letzte_fahrt"

var _lines: PackedStringArray = []


func _init() -> void:
	tag = "lf_start"
	bots = 0
	stop_rounds = false


func _body() -> void:
	GLBus.vo_line_started.connect(func(id: StringName, _sp: StringName, _tx: String, _d: float) -> void:
		_lines.append(String(id)))
	# (a) a plain match
	_check(not Campaign.active, "a plain match (not the campaign)")
	_check(not GameState.power_on and not _map.power_on_at_start, "the power is off at the start")
	_check(Array(_map.quest_files).has("res://data/gravelight/quests/map02_letzte_fahrt.json"), "map02 lists Letzte Fahrt in its quest files")
	_check(QuestManager.has_quest(QUEST), "the quest is loaded")
	_check(RoundManager.current_round <= 1, "the match is at its start (round %d)" % RoundManager.current_round)
	_check(QuestManager.is_active(QUEST, &"s0a_load"), "its first step (a coffin on the crane) is live in round 1")
	_check(QuestManager.status(QUEST, &"s0_power") == "locked", "the power step waits for it")
	var coffins: int = 0
	for i: int in 3:
		var c: BallastCoffin = _g("Coffin_%d" % i) as BallastCoffin
		if c != null and c.can_interact(_p) and c.get_prompt(_p) != "":
			coffins += 1
	_check(coffins == 3, "three coffins on their pallets can be lifted (%d)" % coffins)
	var hook: BallastHook = _g("BallastHook") as BallastHook
	_check(hook != null and hook.get_prompt(_p) != "", "the crane hook is there and says it wants ballast")
	var sw: PowerSwitch = _g("Pumpenschalter") as PowerSwitch
	_check(sw != null and not sw.can_interact(_p), "the Pumpenschalter waits for the ballast")
	# (b) the guide
	var guide: LetzteFahrtGuide = get_tree().get_first_node_in_group(&"letzte_fahrt_guide") as LetzteFahrtGuide
	_check(guide != null, "the Letzte Fahrt guide is attached")
	if guide == null:
		return
	_check(guide.beacon != null and guide.beacon.is_visible_in_tree(), "the empty hook's lamp is lit")
	var sn: SightNote = guide.sight
	var resolved: int = 0
	if sn != null:
		for tp: Variant in sn.targets:
			if sn.get_node_or_null(NodePath(str(tp))) != null:
				resolved += 1
	_check(sn != null and sn.targets.size() >= 7 and resolved == sn.targets.size(),
		"first-sight notes on the hook, coffins, stairs, radios and machine (%d of %d resolve)" % [resolved, sn.targets.size() if sn != null else 0])
	if sn != null:
		_check(sn.note(0) >= 0 or MapState.current() == null, "a first-sight note goes on the map")
	_check(LetzteFahrtGuide.pick(1, {}, LetzteFahrtGuide.step_states()) == "", "no pointer in round 1")
	_check(LetzteFahrtGuide.pick(2, {}, LetzteFahrtGuide.step_states()) == "OPR_LF_HINT_HOOK_01", "round 2's pointer is the crane hook")
	guide._on_round_started(2, false)
	var heard: bool = await _until(func() -> bool: return _lines.has("OPR_LF_HINT_HOOK_01"), 12.0)
	_check(heard, "the Operator names the crane and the coffins at round 2")
	# the first step, by hand
	var c0: BallastCoffin = _g("Coffin_0") as BallastCoffin
	await _use(c0)
	_check(c0.carrier == _p.player_id, "the coffin is lifted")
	await _use(hook)
	await _frames(5)
	_check(QuestManager.is_step_done(QUEST, &"s0a_load"), "hooking it finishes s0a")
	_check(not guide.beacon.visible, "the hook's lamp goes out")
	_check(sw.can_interact(_p), "the Pumpenschalter takes the throw now")
	var next_banner: bool = false
	for w: Dictionary in QuestManager.pending_beats():
		if str((w["a"] as Dictionary).get("banner", "")).contains("Pumpenschalter"):
			next_banner = true
	_check(next_banner, "a banner names the next step (the Pumpenschalter)")
	sw.run_sequence(0)
	await _frames(10)
	_check(QuestManager.is_active(QUEST, &"s2a_radios"), "after the power the radios are live")
	var cur: Dictionary = ObjectiveLog.current_objective(ObjectiveSnapshot.gravelight(get_tree(), []),
		(ObjectiveLog.load_data()["maps"]["map02_totenhafen"] as Dictionary)["current"])
	_check(str(cur.get("title", "")).contains("radios"), "the pause OBJECTIVES' current line points at the radios: %s" % cur.get("title", ""))
	_check(LetzteFahrtGuide.pick(3, guide.said, LetzteFahrtGuide.step_states()) == "OPR_LF_HINT_RADIO_01", "the next round's pointer names the radios")
