extends GutTest
## T-143: the extra people (data/gravelight/people_extra.json, ExtraPeople / ExtraPerson / PersonCard) and the
## quartermaster's trade (companions.json "trade"): the table is valid (kits in people.json, a voice, every named line
## exists with its audio, spots in the map's frame), the favour and timed-reward state machines, the trade rules.
## (That each spot sits on the navmesh is checked on the loaded maps: smoke_npc_walls and NpcWallProbe.)

const KINDS: PackedStringArray = ["scrip_mark", "revive_point", "intel_ping", "cover", "unbolt_door", "supply_drop", "open_passage", "train_drop"]   # (+ T-157, T-155)


func _people() -> Dictionary:
	return ExtraPeople.people()


func test_the_table_counts() -> void:
	assert_eq(ExtraPeople.ids_for_map("map01_kaltenbrunn", ExtraPeople.cfg()).size(), 3, "miners, a medic, a switchboard operator (the quartermaster is Ammer's trade card)")
	assert_eq(ExtraPeople.ids_for_map("map00_crossroads", ExtraPeople.cfg()).size(), 3, "a deserter, a widow, a courier")
	assert_eq(ExtraPeople.ids_for_map("map02_totenhafen", ExtraPeople.cfg()).size(), 2, "Jessen at the Marinekasse, Harms of the night shift (T-170)")
	assert_eq(ExtraPeople.ids_for_map("map04a_thalbach", ExtraPeople.cfg()).size(), 2, "Erich Wendel and Otto Brack (T-155)")
	assert_eq(ExtraPeople.ids_for_map("map04c_groomlake", ExtraPeople.cfg()).size(), 2, "Groom Lake: Dee in her cage, Hale in his office (U10 §3)")


func test_kits_voices_and_names() -> void:
	var cast: Dictionary = (GLData.load_json("res://data/gravelight/vo/voice_cast.json") as Dictionary).get("cast", {})
	# the story speakers (Dee, Hale...) are voiced by gen_vo.py's OneCore placeholder profiles until they are cast
	for spk: Variant in (GLData.load_json("res://data/gravelight/vo/rules.json") as Dictionary).get("story_speakers", []):
		cast[str(spk)] = true
	var kits: Dictionary = (GLData.load_json("res://data/gravelight/art/people.json") as Dictionary).get("people", {})
	for pid: Variant in _people().keys():
		var e: Dictionary = _people()[pid]
		assert_true(cast.has(str(e.get("speaker", ""))), "%s: a voice" % pid)
		assert_ne(str(e.get("name", "")), "", "%s: a name" % pid)
		assert_gt(str(e.get("bio", "")).length(), 80, "%s: a bio" % pid)
		assert_ne(str(e.get("poi", "")), "", "%s: a minimap point" % pid)
		assert_gt((e.get("bodies", []) as Array).size(), 0, "%s: a body" % pid)
		for b: Variant in e.get("bodies", []):
			assert_true(kits.has(str((b as Dictionary).get("person", ""))), "%s: a people.json kit" % pid)
			assert_eq(((b as Dictionary).get("at", []) as Array).size(), 3, "%s: a spot" % pid)
		assert_false(str(e.get("bio", "")).to_lower().contains("zombie"), "%s: people, never zombies" % pid)


func test_every_named_line_exists_with_its_audio() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var n: int = 0
	for pid: Variant in _people().keys():
		var e: Dictionary = _people()[pid]
		var spk: String = str(e["speaker"])
		var count: int = 0
		for kind: Variant in (e.get("lines", {}) as Dictionary).keys():
			for id: Variant in e["lines"][kind]:
				assert_true(lines.has(str(id)), "%s: line %s" % [pid, id])
				assert_eq(str((lines.get(str(id), {}) as Dictionary).get("speaker", "")), spk, "%s: %s is the speaker's" % [pid, id])
				assert_true(FileAccess.file_exists("res://gravelight/audio/vo/%s/%s.ogg" % [spk.to_lower(), str(id)]), "%s: audio for %s" % [pid, id])
				count += 1
		assert_between(count, 6, 10, "%s: 6 to 10 lines" % pid)
		n += count
		if e.has("jakub_line"):
			assert_true(lines.has(str(e["jakub_line"])), "%s: Jakub's reply" % pid)
	assert_gt(n, 40)


func test_the_quartermasters_lines() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for c: String in ["COMP_TALK", "COMP_TRADE", "COMP_TRADE_BROKE", "COMP_TRADE_ONCE"]:
		assert_true(lines.has("AMM_%s_01" % c), c)
		assert_true(FileAccess.file_exists("res://gravelight/audio/vo/amm/AMM_%s_01.ogg" % c), c + " audio")
	var tr: Dictionary = (MapCompanion.entry("ammer") as Dictionary).get("trade", {})
	assert_eq(int(tr.get("cost", 0)), 1500)
	assert_true(bool(tr.get("once_per_round", false)))
	assert_eq((tr.get("outcomes", []) as Array).size(), 2)


func test_favours_and_rewards_are_well_formed() -> void:
	for pid: Variant in _people().keys():
		var e: Dictionary = _people()[pid]
		if e.has("trade"):
			assert_eq(str((e["trade"] as Dictionary).get("kind", "")), "crate_tip")
			assert_gt(int(e["trade"].get("cost", 0)), 0)
			continue
		if not e.has("favour"):
			# a Talk card only (Hale, U10 §3): something to say, and reactions with their flags
			assert_ne(str(e.get("said", "")), "", "%s: a talk-only card says something" % pid)
			for r: Variant in e.get("reactions", []):
				assert_ne(str((r as Dictionary).get("flag", "")), "", "%s: a reaction's flag" % pid)
			continue
		var f: Dictionary = e.get("favour", {})
		assert_true(["fetch", "gun", "deliver"].has(str(f.get("kind", ""))), "%s: a favour kind" % pid)
		assert_ne(str(f.get("ask", "")), "", "%s: an ask" % pid)
		assert_true(KINDS.has(str((f.get("reward", {}) as Dictionary).get("kind", ""))), "%s: a reward kind" % pid)
		if f["kind"] == "fetch":
			assert_eq((f.get("item_at", []) as Array).size(), 3, "%s: an item spot" % pid)
			assert_ne(str(f.get("item_name", "")), "", "%s: an item name" % pid)
		var rk: String = str(f["reward"]["kind"])
		if rk in ["revive_point", "cover", "unbolt_door"]:
			assert_gt(int(f["reward"].get("rounds", 0)), 0, "%s: timed" % pid)


func test_the_kaltenbrunn_spec() -> void:
	assert_eq(str(_people()["miners"]["bodies"].size()), "3", "miners hiding: three bodies, one speaks")
	assert_eq(str(_people()["miners"]["favour"]["item"]), "lamp")
	assert_eq(str(_people()["medic"]["favour"]["reward"]["kind"]), "revive_point")
	assert_eq(int(_people()["medic"]["favour"]["reward"]["rounds"]), 2)
	assert_eq(str(_people()["radio"]["favour"]["reward"]["kind"]), "intel_ping")
	assert_true(_people()["radio"].has("relay"), "the Operator's slips")


func test_the_inn_spec() -> void:
	assert_eq(str(_people()["deserter"]["favour"]["kind"]), "gun")
	assert_eq(str(_people()["deserter"]["favour"]["reward"]["kind"]), "cover")
	assert_eq(int(_people()["deserter"]["favour"]["reward"]["rounds"]), 1)
	assert_eq(int(_people()["widow"]["favour"]["reward"]["rounds"]), 2)
	assert_eq(str(_people()["widow"]["favour"]["reward"]["door"]), "door_stable")
	assert_eq(str(_people()["courier"]["trade"]["kind"]), "crate_tip")


## UPDATE 10 section 9 (T-170; THE_BAR rows 20 and 15): Totenhafen's people. Jessen is the bank's teller (body false, as
## Ruhland: the PatronBody is BankBranch's), talked to beside the Marinekasse's window on the crane office, with a favour
## (the harbour master's ledger page from the Hafenmeister's hut) and reactions at the bank to the egg's flags; Harms
## of the cannery's night shift hides by the clerk's desk with a favour (the infirmary's lantern) that makes her listen.
func test_the_totenhafen_spec() -> void:
	var j: Dictionary = _people()["jessen"]
	assert_eq(str(j["speaker"]), "JES", "the Marinekasse's own voice (bank.json tellers.map02)")
	assert_eq(str((BankAccount.teller_for("map02_totenhafen") as Dictionary).get("id", "")), str(j["bodies"][0]["person"]), "the same man as the bank's teller")
	assert_false(bool(j["bodies"][0].get("body", true)), "no second body: the teller behind the grille is BankBranch's")
	var bank: Dictionary = (GLData.load_json("res://data/gravelight/bank.json") as Dictionary)["branches"]["map02"]
	var at: Vector3 = ExtraPeople.vec(j["bodies"][0]["at"])
	assert_lt(at.distance_to(ExtraPeople.vec(bank["at"])), 3.0, "talked to at the pay window")
	var nb: Array = bank["nav_block"]
	assert_true(at.x > float(nb[1][0]) or at.z > float(nb[1][2]), "and outside the counter's navigation block")
	assert_eq(str(j["favour"]["item"]), "ledger")
	assert_eq(str(j["favour"]["reward"]["kind"]), "scrip_mark")
	var hut: Vector3 = ExtraPeople.vec(j["favour"]["item_at"])
	assert_true(hut.x > 10.0 and hut.x < 18.0 and hut.z > 10.0 and hut.z < 17.0, "the ledger page lies inside the Hafenmeister's hut (gen_map02 HutN/S/W/E)")
	var flags: PackedStringArray = []
	for r: Variant in j["reactions"]:
		flags.append(str((r as Dictionary).get("flag", "")))
		assert_ne(str((r as Dictionary).get("said", "")), "", "a reaction says something on the card")
		assert_true((j["lines"]["react"] as Array).has(str((r as Dictionary).get("line", ""))), "its line is in his react list")
	assert_true(flags.has("lf_ballast_done") and flags.has("boat_key"), "he reacts to the ballast dump and the boat's key")
	var h: Dictionary = _people()["harms"]
	assert_eq(str(h["speaker"]), "HRM")
	assert_eq(str(h["bodies"][0]["pose"]), "cower", "hidden under the clerk's desk")
	var desk: Vector3 = ExtraPeople.vec(h["bodies"][0]["at"])
	assert_lt(desk.distance_to(Vector3(-3.2, 0.0, 9.0)), 2.5, "by the cannery office's desk (the delivery book)")
	assert_eq(str(h["favour"]["item"]), "lamp")
	var inf: Vector3 = ExtraPeople.vec(h["favour"]["item_at"])
	assert_true(inf.x < -20.0 and inf.z < 10.0, "the lantern lies in the infirmary (NW corner)")
	assert_eq(str(h["favour"]["reward"]["kind"]), "intel_ping")
	assert_true((h["lines"] as Dictionary).has("ping"), "she listens for you")
	for pid: String in ["jessen", "harms"]:
		var bio: String = str(_people()[pid]["bio"]).to_lower()
		for bad: String in ["ss ", "swastika", "zombie", "joke"]:
			assert_false(bio.contains(bad), "%s: a person, no insignia, never a joke" % pid)


func test_spots_cover_every_body_and_item() -> void:
	var m1: Array[Vector3] = ExtraPeople.spots_for("map01_kaltenbrunn")
	assert_eq(m1.size(), 3 + 1 + 1 + 1 + 1 + 1 + 1 - 1, "3 miners, medic + its crate, radio + its valve, miners' lamp")
	var m0: Array[Vector3] = ExtraPeople.spots_for("map00_crossroads")
	assert_eq(m0.size(), 1 + 1 + 1 + 1, "deserter, widow + her lamp, courier")
	var m2: Array[Vector3] = ExtraPeople.spots_for("map02_totenhafen")
	assert_eq(m2.size(), 1 + 1 + 1 + 1, "Jessen's window + the ledger page, Harms + the lantern (T-170)")


func test_favour_state_machine() -> void:
	assert_eq(ExtraPeople.favour_next(0, "accept"), 1)
	assert_eq(ExtraPeople.favour_next(1, "item"), 2)
	assert_eq(ExtraPeople.favour_next(2, "give"), 3)
	assert_eq(ExtraPeople.favour_next(0, "give"), 0, "nothing to give before you accept")
	assert_eq(ExtraPeople.favour_next(1, "give"), 1, "the item first")
	assert_eq(ExtraPeople.favour_next(3, "accept"), 3, "done stays done")


func test_timed_rewards_count_rounds() -> void:
	assert_eq(ExtraPeople.rounds_after_grant(2, true), 2, "given mid-round: the rest of it is the first")
	assert_eq(ExtraPeople.rounds_after_grant(2, false), 3, "given in a break: the next round is the first")
	assert_eq(ExtraPeople.rounds_after_start(2), 1)
	assert_eq(ExtraPeople.rounds_after_start(0), 0)
	# a one-round cover given mid-round ends when the next round starts
	var left: int = ExtraPeople.rounds_after_grant(1, true)
	left = ExtraPeople.rounds_after_start(left)
	assert_eq(left, 0)


func test_trade_rules() -> void:
	assert_true(ExtraPeople.trade_open(-1, 3, true))
	assert_false(ExtraPeople.trade_open(3, 3, true), "once per round")
	assert_true(ExtraPeople.trade_open(3, 4, true))
	assert_true(ExtraPeople.trade_open(3, 3, false))
	assert_eq(ExtraPeople.trade_outcome(0.0, ["ammo", "grenades"]), "ammo")
	assert_eq(ExtraPeople.trade_outcome(0.49, ["ammo", "grenades"]), "ammo")
	assert_eq(ExtraPeople.trade_outcome(0.5, ["ammo", "grenades"]), "grenades")
	assert_eq(ExtraPeople.trade_outcome(1.0, ["ammo", "grenades"]), "grenades")
	assert_eq(ExtraPeople.trade_outcome(0.3, []), "")
