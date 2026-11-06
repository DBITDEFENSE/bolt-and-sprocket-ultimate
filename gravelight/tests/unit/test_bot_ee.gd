extends GutTest
## Bots on the easter egg (Update 04 section 5, T-067): the quest data's bot_task blocks, the mode gate (Off / When
## Asked / Full Partner), the discovered-info gate, Jakub's refusals, the pause rule, each task type's planner (with
## fake nodes), and the never-sequence-break rule (the planners against the real QuestManager: a bot never makes a
## wrong input, never the player's commit, never a risky trigger unless ordered).

const QUESTS: PackedStringArray = ["map00_radio", "map01_requiem", "map01_song", "map01_wren_tag", "map02_letzte_fahrt", "map04_kuendigung",
	"map04a_jette", "map04c_cage", "map04d_smile"]
const PLAYER_ONLY: PackedStringArray = ["map01_requiem/s10_ending", "map02_letzte_fahrt/s10_ending", "map01_song/s2_phonograph", "map01_wren_tag/s1_tag",
	"map04_kuendigung/s6_board", "map04_kuendigung/s8_london", "map04_kuendigung/s10_autopilot", "map04_kuendigung/s11b_choice",
	"map04_kuendigung/s14_rocket", "map04_kuendigung/s18_cancel", "map04d_smile/s1_rim"]


class FakeKey extends Node3D:
	var turned: bool = false
	var key_id: StringName = &"abort_b"

	func turn(_by: Variant) -> void:
		turned = true

	func is_turned() -> bool:
		return turned


func after_each() -> void:
	QuestManager.clear()


func _def(qid: String) -> Dictionary:
	return GLData.load_json("res://data/gravelight/quests/%s.json" % qid)


func _task(qid: String, sid: String) -> Dictionary:
	for st: Variant in _def(qid)["steps"]:
		if str((st as Dictionary)["id"]) == sid:
			return BotEECatalog.task_def(st)
	return {}


func _ctx(over: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"mode": "ask", "ordered": true, "active": true, "done": false, "companion": false, "known": {}, "labels": {}, "player_near": true}
	c.merge(over, true)
	return c


# ------------------------------------------------------------------ the quest data

func test_every_step_of_every_quest_has_a_valid_bot_task() -> void:
	for qid: String in QUESTS:
		var d: Dictionary = _def(qid)
		var keys: Dictionary = d.get("bot_knowledge", {})
		for st: Variant in d["steps"]:
			var sd: Dictionary = st
			var t: Dictionary = BotEECatalog.task_def(sd)
			var where: String = "%s/%s" % [qid, sd["id"]]
			assert_false(t.is_empty(), "%s has a bot_task" % where)
			assert_eq(BotEECatalog.validate(t), PackedStringArray(), "%s bot_task is valid" % where)
			assert_eq(BotEECatalog.is_player_only(t), PLAYER_ONLY.has(where), "%s player-only as designed" % where)
			for k: Variant in t.get("needs", []):
				assert_true(keys.has(str(k)), "%s needs '%s', defined in the quest's bot_knowledge" % [where, k])


## U08 section 4.4 (T-131): every step of every built egg has a bot task, or is player-only with a stated reason.
func test_every_player_only_step_says_why() -> void:
	for qid: String in QUESTS:
		for st: Variant in _def(qid)["steps"]:
			var t: Dictionary = BotEECatalog.task_def(st as Dictionary)
			if BotEECatalog.is_player_only(t):
				assert_true(["cutscene", "final", "choice", "handoff"].has(str(t["player_only"])), "%s/%s says why it's the player's" % [qid, (st as Dictionary)["id"]])
				assert_ne(BotEECatalog.player_only_why(t), "it's yours")


## U08 (T-131): the bot-mode agent is the player: it does a player-only step itself; in Full Partner a squad bot may
## take a story choice's default pick when the player is away or down, never another player step.
func test_the_agent_does_the_players_steps_and_bots_take_a_choices_default() -> void:
	var fin: Dictionary = {"type": "turn_key", "target": {"class": "ExfilPoint"}, "player_only": "final"}
	var choice: Dictionary = {"type": "carry", "target": {"class": "CarryObject"}, "player_only": "choice"}
	assert_eq(str(BotEECatalog.gate(fin, _ctx({"agent": true}))["as"]), "task", "the agent turns the key itself")
	assert_eq(str(BotEECatalog.gate(fin, _ctx({"mode": "full", "ordered": false, "player_near": true}))["as"]), "escort", "a squad bot covers the player")
	assert_false(bool(BotEECatalog.gate(fin, _ctx({"mode": "full", "ordered": false, "player_near": false, "player_absent": true}))["ok"]), "a last step stays the player's")
	assert_eq(str(BotEECatalog.gate(choice, _ctx({"mode": "full", "ordered": false, "player_near": false, "player_absent": true}))["as"]), "task", "Full Partner, the player away: the default pick")
	assert_false(bool(BotEECatalog.gate(choice, _ctx({"mode": "ask", "ordered": false, "player_near": false, "player_absent": true}))["ok"]), "When Asked: never")
	assert_eq(str(BotEECatalog.gate(choice, _ctx({"mode": "full", "ordered": false, "player_near": true, "player_absent": false}))["as"]), "escort", "the player here: their choice")
	assert_true(PegsChoice.default_due("full", true, false, 25.0), "Peg's choice: the decider down, Full Partner, 20 s: keep")
	assert_false(PegsChoice.default_due("ask", true, false, 25.0))
	assert_false(PegsChoice.default_due("full", false, false, 99.0), "a present human always decides")
	assert_false(PegsChoice.default_due("full", true, false, 5.0))


func test_power_knowledge() -> void:
	var was: bool = GameState.power_on
	GameState.power_on = false
	assert_eq(BotEEHub.entry_due(&"x", {"on_power": true}), "")
	GameState.power_on = true
	assert_eq(BotEEHub.entry_due(&"x", {"on_power": true}), "power")
	GameState.power_on = was


func test_validate_catches_bad_tasks() -> void:
	assert_ne(BotEECatalog.validate({"type": "teleport"}), PackedStringArray(), "unknown type")
	assert_ne(BotEECatalog.validate({"type": "collect"}), PackedStringArray(), "collect without targets")
	assert_ne(BotEECatalog.validate({"type": "carry", "item": "x"}), PackedStringArray(), "carry without deliver")
	assert_ne(BotEECatalog.validate({"type": "collect", "targets": {"where": {}}}), PackedStringArray(), "a node spec needs a group or class")
	assert_eq(BotEECatalog.validate({"player_only": "cutscene"}), PackedStringArray())
	# Morgenrot's two-key abort (the map doesn't exist yet): the task type is ready for its data
	assert_eq(BotEECatalog.validate({"type": "turn_key", "key": {"group": "ee_keys", "where": {"key_id": "abort_b"}},
		"partner_key": {"group": "ee_keys", "where": {"key_id": "abort_a"}}, "final": true}), PackedStringArray())


func test_the_risky_and_commit_steps_are_marked() -> void:
	assert_eq(str(_task("map00_radio", "s2_tune").get("commit", "")), "last_input", "the radio's last lock is the player's commit")
	assert_true(bool(_task("map00_radio", "s2_tune").get("final", false)))
	assert_eq(str(_task("map01_requiem", "s4_key").get("risky", "")), "shoot", "lighting the bell brings the Foreman")
	assert_eq(str(_task("map01_requiem", "s7_drummer").get("risky", "")), "trigger", "a crate pull can let the drummer escape")
	assert_true((_task("map01_requiem", "s8a_place").get("touches", []) as Array).has("crucible"))
	assert_eq(str(_task("map01_requiem", "s9_heartstorm").get("start", "")), "player", "the Heartstorm's start is the player's")
	assert_eq(str(_task("map01_requiem", "s10_ending").get("player_only", "")), "cutscene")


# ------------------------------------------------------------------ modes

func test_mode_from_settings() -> void:
	assert_eq(BotEECatalog.mode_of({}), "full", "Full Partner by default (T-086)")
	assert_eq(BotEECatalog.mode_of({"bot_ee_help": "ask"}), "ask")
	assert_eq(BotEECatalog.mode_of({"bot_ee_help": "off"}), "off")
	assert_eq(BotEECatalog.mode_of({"bot_ee_help": "nonsense"}), "full")
	# the shipped default, not the player's saved settings (a fresh settings node holds only the defaults)
	var fresh: Node = (load("res://gravelight/autoload/settings.gd") as GDScript).new()
	assert_eq(fresh.get("values").get("bot_ee_help", ""), "full", "the setting's default")
	fresh.free()


func test_mode_gating_off_ask_full() -> void:
	var t: Dictionary = _task("map00_radio", "s1_notes")
	assert_eq(str(BotEECatalog.gate(t, _ctx({"mode": "off"}))["code"]), "off", "Off: never, even ordered")
	assert_eq(str(BotEECatalog.gate(t, _ctx({"mode": "ask", "ordered": false}))["code"]), "not_asked", "When Asked: not on its own")
	assert_true(bool(BotEECatalog.gate(t, _ctx({"mode": "ask", "ordered": true}))["ok"]), "When Asked: assigned is fine")
	assert_true(bool(BotEECatalog.gate(t, _ctx({"mode": "full", "ordered": false}))["ok"]), "Full Partner: on its own")
	assert_eq(str(BotEECatalog.gate(t, _ctx({"active": false}))["code"]), "locked")
	assert_eq(str(BotEECatalog.gate(t, _ctx({"done": true}))["code"]), "done")
	assert_eq(str(BotEECatalog.gate({}, _ctx())["code"]), "no_task")


func test_full_partner_final_steps_wait_for_the_player() -> void:
	var t: Dictionary = _task("map00_radio", "s2_tune")
	var known: Dictionary = {"frequencies": true}
	assert_eq(str(BotEECatalog.gate(t, _ctx({"mode": "full", "ordered": false, "known": known, "player_near": false}))["code"]), "needs_player")
	assert_true(bool(BotEECatalog.gate(t, _ctx({"mode": "full", "ordered": false, "known": known, "player_near": true}))["ok"]))
	assert_true(bool(BotEECatalog.gate(t, _ctx({"mode": "ask", "ordered": true, "known": known, "player_near": false}))["ok"]), "ordered: the player chose")


func test_player_only_steps_become_cover() -> void:
	var t: Dictionary = _task("map01_requiem", "s10_ending")
	var g: Dictionary = BotEECatalog.gate(t, _ctx({"ordered": true}))
	assert_true(bool(g["ok"]))
	assert_eq(str(g["as"]), "escort", "asked for a player-only step, the bot covers the player")
	assert_string_contains(str(g["reason"]), "yours")
	assert_false(bool(BotEECatalog.gate(t, _ctx({"mode": "full", "ordered": false, "player_near": false}))["ok"]))
	assert_eq(str(BotEECatalog.gate(t, _ctx({"mode": "full", "ordered": false, "player_near": true}))["as"]), "escort")


func test_risky_stages_need_an_order() -> void:
	assert_false(BotEECatalog.is_risky({"risky": "shoot"}, ""), "the rest of the task is safe")
	assert_true(BotEECatalog.is_risky({"risky": "shoot"}, "shoot"))
	assert_true(BotEECatalog.is_risky({"risky": true}, ""))
	var g: Dictionary = BotEECatalog.gate({"type": "collect", "targets": {"group": "x"}, "risky": true}, _ctx({"mode": "full", "ordered": false}))
	assert_eq(str(g["code"]), "risky")


# ------------------------------------------------------------------ puzzle knowledge

func test_the_discovered_info_gate() -> void:
	var t: Dictionary = _task("map01_requiem", "s6_bells")
	var k: BotEEKnowledge = BotEEKnowledge.new()
	k.labels = {"melody": "heard the music box's melody", "bells": "found where the four little bells hang"}
	var g: Dictionary = BotEECatalog.gate(t, _ctx({"known": k.known, "labels": k.labels}))
	assert_eq(str(g["code"]), "info", "no melody heard: can't ring the bells")
	assert_string_contains(str(g["reason"]), "music box", "the reason names what is missing")
	assert_true(k.learn("melody", 0, 1.0, "heard"))
	assert_false(k.learn("melody", 2, 2.0, "heard"), "learned once")
	assert_eq(k.missing(["melody", "bells"]), ["bells"])
	assert_eq(str(BotEECatalog.gate(t, _ctx({"known": k.known, "labels": k.labels}))["code"]), "info", "the bells not found yet")
	k.learn("bells", 0, 3.0, "seen")
	assert_true(bool(BotEECatalog.gate(t, _ctx({"known": k.known}))["ok"]))


func test_knowledge_comes_from_what_was_collected_not_from_skips() -> void:
	var qid: StringName = QuestManager.load_quest("res://data/gravelight/quests/map00_radio.json")
	var e: Dictionary = (QuestManager.definition(qid)["bot_knowledge"] as Dictionary)["frequencies"]
	assert_eq(BotEEHub.entry_due(qid, e), "", "nothing read yet")
	QuestManager.collect(&"radio_note", &"note_a")
	QuestManager.collect(&"radio_note", &"note_b")
	assert_eq(BotEEHub.entry_due(qid, e), "", "two of three notes: not the whole answer")
	QuestManager.collect(&"radio_note", &"note_c")
	assert_eq(BotEEHub.entry_due(qid, e), "collect", "all three notes read: the frequencies are known")
	QuestManager.clear()
	qid = QuestManager.load_quest("res://data/gravelight/quests/map00_radio.json")
	QuestManager.debug_complete(qid, &"s1_notes")
	assert_true(QuestManager.is_active(qid, &"s2_tune"))
	assert_eq(BotEEHub.entry_due(qid, e), "", "a debug-skipped step taught the squad nothing")
	var g: Dictionary = BotEECatalog.gate(BotEECatalog.task_def(QuestManager.step_def(qid, &"s2_tune")), _ctx({"known": {}, "labels": {"frequencies": "read the three notes' frequencies"}}))
	assert_eq(str(g["code"]), "info", "so a bot can't tune the radio: \"%s\"" % g["reason"])


# ------------------------------------------------------------------ Jakub

func test_jakub_does_collect_hold_carry_and_refuses_the_rest() -> void:
	var j: Dictionary = {"companion": true, "mode": "full", "ordered": true, "known": {"code": true, "melody": true, "bells": true, "frequencies": true}}
	assert_true(bool(BotEECatalog.gate(_task("map00_radio", "s1_notes"), _ctx(j))["ok"]), "Collect")
	assert_true(bool(BotEECatalog.gate(_task("map01_requiem", "s1_vault"), _ctx(j))["ok"]), "Hold")
	assert_true(bool(BotEECatalog.gate(_task("map01_requiem", "s5_reliquary"), _ctx(j))["ok"]), "Carry")
	assert_eq(str(BotEECatalog.gate(_task("map01_requiem", "s8a_place"), _ctx(j))["code"]), "jakub_crucible", "the shard into the Crucible: no")
	assert_eq(str(BotEECatalog.gate({"type": "carry", "item": "x", "deliver": {"group": "perk_machines"}, "touches": ["perk"]}, _ctx(j))["code"]), "jakub_perk")
	assert_eq(str(BotEECatalog.gate(_task("map01_requiem", "s6_bells"), _ctx(j))["code"]), "jakub_type", "shooting: not his")
	assert_eq(str(BotEECatalog.gate(_task("map00_radio", "s2_tune"), _ctx(j))["code"]), "jakub_type", "the radio dial: not his")
	assert_eq(BotEECatalog.cant_category("jakub_crucible"), "EE_REFUSE_CRUCIBLE")
	assert_eq(BotEECatalog.cant_category("jakub_perk"), "EE_REFUSE_PERK")
	assert_eq(BotEECatalog.cant_category("jakub_type"), "EE_REFUSE_TYPE")


func test_every_speaker_has_the_ee_lines() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var have: Dictionary = {}
	for id: String in lines.keys():
		have["%s:%s" % [lines[id]["speaker"], lines[id]["category"]]] = true
	for spk: String in ["DUT", "PEG", "DEA", "WRN"]:
		for cat: String in ["EE_ACK", "EE_ACK_COLLECT", "EE_ACK_SHOOT_TARGET", "EE_ACK_HOLD_ZONE", "EE_ACK_CARRY", "EE_ACK_INTERACT_SEQUENCE",
				"EE_ACK_KILL_WITH_WEAPON", "EE_ACK_TURN_KEY", "EE_PLAYER_ONLY", "EE_PROGRESS", "EE_DONE", "EE_HANDOFF", "EE_CANT", "EE_CANT_INFO",
				"EE_CANT_FIND", "EE_CANT_RISKY", "EE_WAIT_PLAYER", "EE_INTERRUPTED", "EE_RESUME"]:
			assert_true(have.has("%s:%s" % [spk, cat]), "%s has %s" % [spk, cat])
	for cat2: String in ["EE_ACK_COLLECT", "EE_ACK_HOLD_ZONE", "EE_ACK_CARRY", "EE_PLAYER_ONLY", "EE_PROGRESS", "EE_DONE", "EE_CANT", "EE_CANT_INFO",
			"EE_INTERRUPTED", "EE_RESUME", "EE_REFUSE_CRUCIBLE", "EE_REFUSE_PERK", "EE_REFUSE_TYPE"]:
		assert_true(have.has("JAK:%s" % cat2), "Jakub has %s" % cat2)
	assert_false(have.has("JAK:EE_ACK_SHOOT_TARGET"), "Jakub never takes a shooting task")


# ------------------------------------------------------------------ pausing

func test_pause_rule() -> void:
	var c: Dictionary = BotEECatalog.cfg()
	assert_eq(BotEECatalog.pause_reason({"type": "collect", "pressure": 0.2}, c), "")
	assert_eq(BotEECatalog.pause_reason({"type": "collect", "pressure": 0.9}, c), "threat")
	assert_eq(BotEECatalog.pause_reason({"type": "collect", "pressure": 0.55, "was": "threat"}, c), "threat", "hysteresis: stays paused until it calms")
	assert_eq(BotEECatalog.pause_reason({"type": "collect", "pressure": 0.3, "was": "threat"}, c), "")
	assert_eq(BotEECatalog.pause_reason({"type": "hold_zone", "pressure": 0.95}, c), "", "holding a zone is the fight")
	assert_eq(BotEECatalog.pause_reason({"type": "collect", "teammate_down": true}, c), "teammate_down")
	assert_eq(BotEECatalog.pause_reason({"type": "hold_zone", "teammate_down": true}, c), "", "the holders keep holding")
	assert_eq(BotEECatalog.pause_reason({"type": "carry", "round_left": 2}, c), "round_end")
	assert_eq(BotEECatalog.pause_reason({"type": "carry", "round_left": 8}, c), "")
	assert_eq(BotEECatalog.pause_reason({"type": "interact_sequence", "player_away": true}, c), "player_away")


# ------------------------------------------------------------------ each task type (planners with fakes)

func test_collect_plan() -> void:
	var a: Node3D = autofree(Node3D.new())
	var b: Node3D = autofree(Node3D.new())
	var c: Node3D = autofree(Node3D.new())
	var rows: Array = [{"node": a, "id": "note_a", "ok": true, "d": 9.0}, {"node": b, "id": "note_b", "ok": true, "d": 3.0}, {"node": c, "id": "note_c", "ok": false, "d": 1.0}]
	assert_eq(BotEE.plan_collect({}, {"nodes": rows, "got": []})["node"], b, "nearest eligible")
	assert_eq(BotEE.plan_collect({}, {"nodes": rows, "got": ["note_b"]})["node"], a, "not one already counted")
	assert_eq(BotEE.plan_collect({}, {"nodes": rows, "got": [], "focus": a})["node"], a, "the marked one first")
	assert_eq(str(BotEE.plan_collect({}, {"nodes": rows, "got": ["note_a", "note_b"], "picked": 1})["do"]), "done", "its part done (the rest is claimed)")
	assert_eq(str(BotEE.plan_collect({}, {"nodes": rows, "got": ["note_a", "note_b"]})["code"]), "not_found")
	var rows2: Array = [{"node": a, "id": "note_a", "ok": false, "retry": true, "d": 9.0}]
	assert_eq(str(BotEE.plan_collect({}, {"nodes": rows2, "got": [], "picked": 1})["do"]), "wait", "one it couldn't reach just now: try again, don't call it done")
	assert_eq(str(BotEE.plan("collect", {}, {"step_done": true})["do"]), "done")


func test_interact_sequence_plan() -> void:
	var radio: Node3D = autofree(Node3D.new())
	var t: Dictionary = {"type": "interact_sequence", "input": {"method": "lock_frequency"}, "commit": "last_input"}
	var w: Dictionary = {"node": radio, "has_input": true, "expected": ["3.120", "5.785", "7.440"], "progress": 0}
	var p: Dictionary = BotEE.plan_inputs(t, w)
	assert_eq(str(p["do"]), "input")
	assert_eq(str(p["value"]), "3.120", "the expected input, read from the quest, never a guess")
	w["progress"] = 1
	assert_eq(str(BotEE.plan_inputs(t, w)["value"]), "5.785")
	w["progress"] = 2
	assert_eq(str(BotEE.plan_inputs(t, w)["do"]), "handoff", "the last lock is the player's commit")
	t.erase("commit")
	assert_eq(str(BotEE.plan_inputs(t, w)["value"]), "7.440", "without a commit rule it finishes the sequence")
	assert_eq(str(BotEE.plan_inputs(t, {"node": radio, "has_input": true, "expected": [], "progress": 0})["code"]), "info", "no answer known: no input")
	var sw: Dictionary = {"type": "interact_sequence", "ready": "x"}
	assert_eq(str(BotEE.plan_inputs(sw, {"node": radio, "has_input": false, "ready": false})["do"]), "wait")
	assert_eq(str(BotEE.plan_inputs(sw, {"node": radio, "has_input": false, "ready": true, "usable": true})["do"]), "use", "one use: the power switch")
	assert_eq(str(BotEE.plan_inputs(sw, {"node": null})["code"]), "not_found")


func test_shoot_target_plan_sequence_single_and_moving() -> void:
	var n1: Node3D = autofree(Node3D.new())
	var n2: Node3D = autofree(Node3D.new())
	var n3: Node3D = autofree(Node3D.new())
	var seq: Dictionary = {"n1": n1, "n2": n2, "n3": n3}
	var t: Dictionary = {"type": "shoot_target", "sequence": {"group": "quest_bells"}}
	var w: Dictionary = {"expected": ["n3", "n1", "n2"], "progress": 0, "sequence": seq}
	assert_eq(BotEE.plan_shoot(t, w)["node"], n3, "the bell the melody wants first")
	w["progress"] = 1
	assert_eq(BotEE.plan_shoot(t, w)["node"], n1)
	w["sequence"] = {"n3": n3, "n2": n2}
	assert_eq(str(BotEE.plan_shoot(t, w)["code"]), "not_found", "the next bell not found: it stops, it doesn't shoot another")
	# a single target, the risky stage
	var bell: Node3D = autofree(Node3D.new())
	var ts: Dictionary = {"type": "shoot_target", "target": {"group": "quest_bells"}, "need_upgraded": true, "risky": "shoot", "then_hold": {"radius": 4.0}}
	assert_eq(str(BotEE.plan_shoot(ts, {"single": bell, "ordered": false})["code"]), "risky", "lighting the Chapel bell: only on the player's word")
	assert_eq(str(BotEE.plan_shoot(ts, {"single": bell, "ordered": true, "has_upgraded": false})["code"]), "no_upgraded")
	assert_eq(str(BotEE.plan_shoot(ts, {"single": bell, "ordered": true, "has_upgraded": true})["do"]), "shoot")
	assert_eq(str(BotEE.plan_shoot(ts, {"single": bell, "ordered": false, "lit": true})["do"]), "hold", "lit by the player: hold the Chapel (safe)")
	# a moving target (the drummer), then its drop; the crate trigger only when ordered
	var tm: Dictionary = {"type": "shoot_target", "target": {"group": "quest_drummers"}, "moving": true, "trigger": "crate", "risky": "trigger"}
	var dr: Node3D = autofree(Node3D.new())
	assert_eq(str(BotEE.plan_shoot(tm, {"moving": dr})["do"]), "shoot_moving")
	assert_eq(str(BotEE.plan_shoot(tm, {"pickup": dr})["do"]), "use", "the shard he drops")
	assert_eq(str(BotEE.plan_shoot(tm, {"ordered": false, "can_trigger": true})["do"]), "wait", "never pulls the crate on its own")
	assert_eq(str(BotEE.plan_shoot(tm, {"ordered": true, "can_trigger": true, "crate": dr})["do"]), "crate")


func test_hold_zone_plan() -> void:
	var p1: Node3D = autofree(Node3D.new())
	var p2: Node3D = autofree(Node3D.new())
	var t: Dictionary = {"type": "hold_zone", "anchors": {"group": "pylons"}, "start": "interact"}
	assert_eq(BotEE.plan_hold(t, {"anchors": [{"node": p1, "state": "start_ok", "d": 2.0}, {"node": p2, "state": "charging", "d": 9.0}]})["node"], p2, "a charging ring first")
	assert_eq(str(BotEE.plan_hold(t, {"anchors": [{"node": p1, "state": "start_ok", "d": 2.0}]})["do"]), "use", "start one (the player is close)")
	assert_eq(str(BotEE.plan_hold(t, {"anchors": [{"node": p1, "state": "idle", "d": 2.0}]})["do"]), "wait", "not without the player")
	var th: Dictionary = {"type": "hold_zone", "while": "holdout", "start": "player"}
	assert_eq(str(BotEE.plan_hold(th, {"holdout_running": false})["do"]), "escort", "the Heartstorm's start is the player's: cover them")
	assert_eq(str(BotEE.plan_hold(th, {"holdout_running": true, "center": Vector3(1, 0, 2)})["do"]), "hold")


func test_carry_plan() -> void:
	var part: Node3D = autofree(Node3D.new())
	var bench: Node3D = autofree(Node3D.new())
	var tp: Dictionary = {"type": "carry", "pickups": {"group": "buildable_parts"}, "deliver": {"group": "workbenches"}}
	assert_eq(BotEE.plan_carry(tp, {"pickups": [{"node": part, "d": 4.0}], "deliver": bench, "deliver_ready": false})["node"], part, "the parts first")
	assert_eq(str(BotEE.plan_carry(tp, {"pickups": [], "deliver": bench, "deliver_ready": false})["do"]), "wait", "not all parts yet")
	assert_eq(BotEE.plan_carry(tp, {"pickups": [], "deliver": bench, "deliver_ready": true})["node"], bench, "then the bench")
	var ti: Dictionary = {"type": "carry", "item": "nachtglas_shard", "deliver": {"class": "Crucible"}, "deliver_ready": "crucible_shard"}
	assert_eq(BotEE.plan_carry(ti, {"has_item": false, "pickup": part})["node"], part, "fetch the item")
	assert_eq(str(BotEE.plan_carry(ti, {"has_item": false, "pickup": null})["code"]), "not_found")
	var p: Dictionary = BotEE.plan_carry(ti, {"has_item": true, "deliver": bench, "deliver_ready": true})
	assert_eq(p["node"], bench)
	assert_eq(str(p["guard_ready"]), "crucible_shard", "the Crucible is used only while the quest is ready for it (never a gun by mistake)")


func test_kill_with_weapon_plan() -> void:
	var bench: Node3D = autofree(Node3D.new())
	var t: Dictionary = {"type": "kill_with_weapon", "weapon": ["totenglocke", "totenglocke_up"]}
	assert_eq(BotEE.plan_kill(t, {"holding": false, "get_node": bench})["node"], bench, "take the weapon first")
	var p: Dictionary = BotEE.plan_kill(t, {"holding": true, "center": Vector3(34, -18, 116), "radius": 15.0})
	assert_eq(str(p["do"]), "hold")
	assert_eq(p["weapon"], ["totenglocke", "totenglocke_up"], "with that weapon in hand")
	assert_almost_eq(float(p["radius"]), 5.0, 0.01, "well inside the radius")
	assert_eq(str(BotEE.plan_kill(t, {"holding": false, "get_node": null})["code"]), "no_weapon")


func test_escort_plan() -> void:
	assert_eq(str(BotEE.plan_escort({}, {"step_active": true})["do"]), "escort")
	assert_eq(str(BotEE.plan_escort({}, {"step_active": false})["do"]), "done")


func test_turn_key_waits_for_the_partner() -> void:
	var key: FakeKey = autofree(FakeKey.new())
	var t: Dictionary = {"type": "turn_key", "key": {"group": "ee_keys"}}
	assert_eq(str(BotEE.plan_turn_key(t, {"key": key, "at_key": false})["do"]), "goto")
	assert_eq(str(BotEE.plan_turn_key(t, {"key": key, "at_key": true, "partner_ready": false})["do"]), "guard", "never turns first")
	var p: Dictionary = BotEE.plan_turn_key(t, {"key": key, "at_key": true, "partner_ready": true})
	assert_eq(str(p["do"]), "turn", "the player is at the other key: turn")
	(p["node"] as FakeKey).turn(null)
	assert_eq(str(BotEE.plan_turn_key(t, {"key": key, "key_turned": key.is_turned()})["do"]), "done")
	assert_eq(str(BotEE.plan_turn_key(t, {"key": null})["code"]), "not_found")


# ------------------------------------------------------------------ the never-sequence-break rule

func test_safe_input_and_commit() -> void:
	assert_true(BotEECatalog.safe_input(["a", "b"], 0, "a", false))
	assert_false(BotEECatalog.safe_input(["a", "b"], 0, "b", false), "the wrong one next: never")
	assert_false(BotEECatalog.safe_input(["a", "b"], 2, "a", false), "past the end")
	assert_true(BotEECatalog.safe_input(["a", "b"], 0, "b", true), "unless the player ordered exactly that")
	assert_true(BotEECatalog.commit_blocked({"commit": "last_input"}, 2, 3))
	assert_false(BotEECatalog.commit_blocked({"commit": "last_input"}, 1, 3))
	assert_false(BotEECatalog.commit_blocked({}, 2, 3))


func test_bells_never_break_the_real_sequence() -> void:
	QuestManager.match_seed = 4471
	var qid: StringName = QuestManager.load_quest("res://data/gravelight/quests/map01_requiem.json")
	QuestManager.debug_skipto(qid, &"s6_bells")
	assert_true(QuestManager.is_active(qid, &"s6_bells"))
	var fails: Array = []
	var on_fail: Callable = func(q: StringName, s: StringName, r: StringName) -> void: fails.append([q, s, r])
	GLBus.quest_step_failed.connect(on_fail)
	var seq: Dictionary = {}
	for note: String in ["n1", "n2", "n3", "n4"]:
		seq[note] = autofree(Node3D.new())
	var t: Dictionary = BotEECatalog.task_def(QuestManager.step_def(qid, &"s6_bells"))
	var shots: int = 0
	while not QuestManager.is_step_done(qid, &"s6_bells") and shots < 8:
		var prog: Variant = QuestManager.progress(qid, &"s6_bells")
		var w: Dictionary = {"expected": QuestManager.sequence_inputs(qid, &"s6_bells"), "progress": int(prog) if prog != null else 0, "sequence": seq}
		var p: Dictionary = BotEE.plan_shoot(t, w)
		assert_eq(str(p["do"]), "shoot")
		var note2: String = str(p["value"])
		assert_eq(p["node"], seq[note2], "it aims at the bell it means")
		var res: Dictionary = QuestManager.submit(&"four_bells", note2)
		assert_ne(str(res["result"]), "wrong", "never a wrong bell")
		shots += 1
	GLBus.quest_step_failed.disconnect(on_fail)
	assert_true(QuestManager.is_step_done(qid, &"s6_bells"), "the Four Bells rung in four shots")
	assert_eq(shots, 4)
	assert_eq(fails.size(), 0, "no failed-egg event")


func test_radio_never_takes_the_players_commit() -> void:
	var qid: StringName = QuestManager.load_quest("res://data/gravelight/quests/map00_radio.json")
	for n: String in ["note_a", "note_b", "note_c"]:
		QuestManager.collect(&"radio_note", StringName(n))
	assert_true(QuestManager.is_active(qid, &"s2_tune"))
	var t: Dictionary = BotEECatalog.task_def(QuestManager.step_def(qid, &"s2_tune"))
	var radio: Node3D = autofree(Node3D.new())
	var made: int = 0
	for _i: int in 6:
		var prog: Variant = QuestManager.progress(qid, &"s2_tune")
		var p: Dictionary = BotEE.plan_inputs(t, {"node": radio, "has_input": true, "expected": QuestManager.sequence_inputs(qid, &"s2_tune"),
			"progress": int(prog) if prog != null else 0})
		if str(p["do"]) != "input":
			assert_eq(str(p["do"]), "handoff", "stops at the commit")
			break
		assert_eq(str(QuestManager.submit(&"radio_m0", str(p["value"]))["result"]), "ok")
		made += 1
	assert_eq(made, 2, "two of three locks")
	assert_false(QuestManager.is_complete(qid), "the egg's finish is the player's")
	assert_eq(str(QuestManager.submit(&"radio_m0", "7.440")["result"]), "done", "the player locks the last one")


func test_shot_allowed_only_for_the_planned_target_this_frame() -> void:
	var ee: BotEE = BotEE.new()
	var bell: Node3D = autofree(Node3D.new())
	var other: Node3D = autofree(Node3D.new())
	assert_false(ee.shot_allowed(bell), "no task: no quest shootable reacts")
	ee.task = {"qid": &"q", "sid": &"s", "type": "shoot_target"}
	ee._shoot_target = bell
	ee._shoot_frame = Engine.get_physics_frames()
	assert_true(ee.shot_allowed(bell))
	assert_false(ee.shot_allowed(other), "a stray hit on another bell doesn't count")
	ee._shoot_frame = Engine.get_physics_frames() - 1
	assert_false(ee.shot_allowed(bell), "only the frame it aimed")


# ------------------------------------------------------------------ node specs

func test_resolve_filters_by_property_and_class() -> void:
	var a: QuestNote = autofree(QuestNote.new())
	a.tag = &"radio_note"
	var b: QuestNote = autofree(QuestNote.new())
	b.tag = &"other"
	var pool: Array = [a, b, autofree(Node3D.new())]
	var got: Array[Node] = BotEECatalog.resolve({"class": "QuestNote", "where": {"tag": "radio_note"}}, get_tree(), pool)
	assert_eq(got.size(), 1)
	assert_eq(got[0], a)
	assert_true(BotEECatalog.script_is(a, "Interactable"), "subclasses count")
	assert_eq(BotEECatalog.target_id(a, {"id_prop": "item_id"}), String(a.item_id))


# ------------------------------------------------------------------ the utility action

func _uctx(over: Dictionary) -> Dictionary:
	var c: Dictionary = {"hp": 1.0, "mag": 1.0, "mag_reserve": 0.0, "ammo": 0.9, "any_ammo": 1.0, "armed": 1.0, "reloading": 0.0,
		"pressure": 0.0, "near": 1.0, "n5": 0.0, "n10": 0.0, "known": 0.0, "sprinter_close": 0.0, "has_target": 0.0,
		"revive_mine": 0.0, "revive_bleed": 1.0, "revive_blocked": 0.0, "revive_path": 0.2, "revive_speed": 1.0, "reviving": 0.0,
		"cover_need": 0.0, "leader_far": 0.3, "is_leader": 0.0, "squad_far": 0.1, "break": 0.0, "round": 0.3, "loop": 1.0,
		"hold_spot": 0.0, "repair_task": 0.0, "buy_task": 0.0, "crate_task": 0.0, "resupply_task": 0.0, "powerup_task": 0.0, "trap_task": 0.0,
		"chatter_ok": 0.0, "objective": 0.0, "order": 0.0, "escort": 0.0, "escort_far": 0.0, "stand_fast": 0.0, "ee_task": 0.0}
	c.merge(over, true)
	if not over.has("buy_pressure"):
		c["buy_pressure"] = c["pressure"]   # U10 T-172 (outside a shopping break)
	return c


func test_the_ee_action_wins_when_calm_and_yields_to_revives() -> void:
	BotAIData.reload()
	var acts: Dictionary = BotAIData.table("actions")
	var curves: Dictionary = BotAIData.table("curves")
	var best: Callable = func(c: Dictionary) -> String:
		return str(BotUtility.choose(BotUtility.score_all(acts, c, curves, {}), "follow", 0.1)[0])
	assert_eq(best.call(_uctx({"ee_task": 0.8})), "ee_task", "calm, a task: it goes")
	assert_ne(best.call(_uctx({"ee_task": 0.0})), "ee_task", "paused / no task: it doesn't")
	assert_eq(best.call(_uctx({"ee_task": 0.8, "revive_mine": 1.0, "revive_bleed": 0.5})), "revive", "a revive comes first")
	assert_eq(best.call(_uctx({"ee_task": 0.8, "buy_task": 0.6})), "ee_task", "the egg task over casual shopping")


# ------------------------------------------------------------------ T-086: the bots finish the egg on their own

func test_commit_open_rules() -> void:
	var c: Dictionary = {"full_commit_after_s": 45.0}
	assert_true(BotEECatalog.commit_open("agent", -1.0, true, c), "the bot-mode agent is the player: it commits")
	assert_false(BotEECatalog.commit_open("ask", 500.0, false, c), "an assigned bot never takes the commit")
	assert_false(BotEECatalog.commit_open("full", -1.0, false, c), "Full Partner before the hand-off: no")
	assert_false(BotEECatalog.commit_open("full", 20.0, false, c), "Full Partner, the player still has time")
	assert_true(BotEECatalog.commit_open("full", 45.0, false, c), "Full Partner after the wait: it turns the last one")
	assert_false(BotEECatalog.final_wait_over(30.0, {"full_final_wait_s": 60.0}))
	assert_true(BotEECatalog.final_wait_over(60.0, {"full_final_wait_s": 60.0}))
	assert_eq(BotEECatalog.cant_category("commit_self"), "EE_COMMIT_SELF")


func test_radio_full_partner_commits_once_the_wait_is_over() -> void:
	var qid: StringName = QuestManager.load_quest("res://data/gravelight/quests/map00_radio.json")
	for n: String in ["note_a", "note_b", "note_c"]:
		QuestManager.collect(&"radio_note", StringName(n))
	var t: Dictionary = BotEECatalog.task_def(QuestManager.step_def(qid, &"s2_tune"))
	var radio: Node3D = autofree(Node3D.new())
	var w: Dictionary = {"node": radio, "has_input": true, "expected": QuestManager.sequence_inputs(qid, &"s2_tune"), "progress": 2}
	assert_eq(str(BotEE.plan_inputs(t, w)["do"]), "handoff", "the third lock is the player's while the wait runs")
	w["commit_ok"] = true
	var p: Dictionary = BotEE.plan_inputs(t, w)
	assert_eq(str(p["do"]), "input", "the wait is over (or the agent): the bot makes the commit")
	assert_eq(str(p["value"]), "7.440")
	assert_eq(str(QuestManager.submit(&"radio_m0", "3.120")["result"]), "ok")
	assert_eq(str(QuestManager.submit(&"radio_m0", "5.785")["result"]), "ok")
	assert_eq(str(QuestManager.submit(&"radio_m0", str(p["value"]))["result"]), "done")
	assert_true(QuestManager.is_complete(qid))


func test_ee_help_default_is_full_partner_and_old_files_migrate() -> void:
	assert_eq(str(GLData.load_json("res://data/gravelight/ai/ee.json").get("default_mode", "")), "full")
	var path: String = "user://_test_settings_t086.cfg"
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("settings", "bot_ee_help", "ask")   # a file saved before T-086: "ask" was only the old default
	cfg.save(path)
	var fresh: Node = (load("res://gravelight/autoload/settings.gd") as GDScript).new()
	fresh.set("path", path)
	fresh.call("load_settings")
	assert_eq(str((fresh.get("values") as Dictionary).get("bot_ee_help", "")), "full", "an old file gets the new default once")
	assert_eq(int((fresh.get("values") as Dictionary).get("bot_ee_help_rev", 0)), 2)
	cfg.set_value("settings", "bot_ee_help", "ask")
	cfg.set_value("settings", "bot_ee_help_rev", 2)   # the player chose When Asked since: kept
	cfg.save(path)
	fresh.call("load_settings")
	assert_eq(str((fresh.get("values") as Dictionary).get("bot_ee_help", "")), "ask", "a choice made after the migration stays")
	fresh.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_repeated_log_line_waits_log_repeat_s() -> void:
	# perf (Map 1): the "can't reach" retry ran every physics tick and printed every time (60 lines a second)
	assert_true(BotEE.log_due("can't reach Hauptschalter", "", -INF, 10.0), "a new line logs")
	assert_false(BotEE.log_due("can't reach Hauptschalter", "can't reach Hauptschalter", 10.0, 10.0 + 1.0 / 60.0), "the same line a tick later doesn't")
	assert_false(BotEE.log_due("can't reach Hauptschalter", "can't reach Hauptschalter", 10.0, 10.0 + BotEE.LOG_REPEAT_S - 0.1))
	assert_true(BotEE.log_due("can't reach Hauptschalter", "can't reach Hauptschalter", 10.0, 10.0 + BotEE.LOG_REPEAT_S), "again after LOG_REPEAT_S")
	assert_true(BotEE.log_due("opened gen door for the power switch", "can't reach Hauptschalter", 10.0, 10.1), "another line logs at once")
