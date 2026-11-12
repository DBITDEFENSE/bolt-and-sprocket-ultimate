extends GutTest
## T-240: the undead horses' data and rules (data/gravelight/bosses/horse.json, HorseBoss, HorseRound) as pure logic:
## the maps' "round_bosses" rows (round, boss id, count) name known bosses on rounds 20 and 30 where they are on, and
## are absent elsewhere; the blocks inherit; every attack's telegraph is half a second or more and names its counter;
## the numbers sit where the design says (health between PAUL's and the Foreman's for the round, damage a healthy
## player survives once); the charge's lane, the kick's cone, the stomp's rings, the phases, the rider's fall, where
## it may chase, and which move it picks.


func _b(id: String) -> Dictionary:
	return HorseBoss.block_of(id)


func test_round_bosses_rows() -> void:
	for map: StringName in [&"map00_crossroads", &"map01_kaltenbrunn"]:
		var rows: Array = HorseRound.rows_for(map)
		assert_eq(rows.size(), 2, "%s: two boss rounds" % map)
		var rounds: Array = []
		for r: Dictionary in rows:
			assert_true(HorseRound.row_ok(r), "%s: row %s names a known horse" % [map, str(r.get("boss"))])
			assert_gte(int(r.get("count", 1)), 1)
			rounds.append(int(r["round"]))
		assert_eq(rounds, [20, 30], "%s: rounds 20 and 30" % map)
		assert_eq(str(rows[0]["boss"]), "totenross")
		assert_eq(str(rows[1]["boss"]), "totenross_fuhrmann", "%s: round 30 is the worse one" % map)
		var arena: Dictionary = HorseRound.arena_for(map)
		assert_false((arena.get("zones", []) as Array).is_empty(), "%s: the arena names the zones a horse may go" % map)
	for map2: StringName in [&"map02_totenhafen", &"map04a_thalbach", &"map04c_groomlake", &"test_range"]:
		assert_eq(HorseRound.rows_for(map2).size(), 0, "%s: off (one data line turns it on)" % map2)
	assert_false(HorseRound.row_ok({"round": 20, "boss": "no_such_horse"}), "an unknown boss id is refused")
	assert_false(HorseRound.row_ok({"round": 1, "boss": "totenross"}), "round 1 is no boss round")
	var inn: Array = HorseRound.arena_for(&"map00_crossroads")["zones"]
	assert_true(inn.has("YARD") and inn.has("GROUNDS") and not inn.has("TAPROOM") and not inn.has("UPSTAIRS") and not inn.has("OLD_CELLAR"), "the Inn: outdoors and the stable, never the taproom, the stairs or the cellar")
	var mine: Array = HorseRound.arena_for(&"map01_kaltenbrunn")["zones"]
	for z: Variant in mine:
		assert_true(str(z).begins_with("A_") or str(z).begins_with("B_"), "Kaltenbrunn: the surface yards only (%s)" % str(z))


func test_blocks_inherit() -> void:
	var a: Dictionary = _b("totenross")
	var f: Dictionary = _b("totenross_fuhrmann")
	assert_false(a.is_empty() or f.is_empty())
	assert_false(f.has("inherits"), "the inherits key is folded in")
	assert_eq(str(f["boss_id"]), "totenross_fuhrmann")
	assert_true((f["moves"] as Dictionary).has("charge") and (f["moves"] as Dictionary).has("trample"), "the Fuhrmann has the horse's moves")
	assert_true(f.has("rider") and not a.has("rider"), "only the Fuhrmann rides")
	assert_gt(float(f["hp_base"]), float(a["hp_base"]), "round 30's has more health")
	assert_gt(float(f["damage_mult"]), float(a["damage_mult"]), "and hits harder")
	assert_eq(float(f["dread"]["radius"]), float(a["dread"]["radius"]), "and the same dread block")
	assert_true(_b("nobody").is_empty())
	assert_eq(HorseBoss.merged({"a": {"x": 1, "y": 2}, "b": 1}, {"a": {"y": 3}, "c": 4}), {"a": {"x": 1, "y": 3}, "b": 1, "c": 4})


func test_every_attack_is_telegraphed_and_has_a_counter() -> void:
	for id: String in ["totenross", "totenross_fuhrmann"]:
		var b: Dictionary = _b(id)
		var moves: Dictionary = (b["moves"] as Dictionary).duplicate()
		moves.erase("_doc")
		if b.has("rider"):
			moves["whip"] = b["rider"]["whip"]
		assert_gte(moves.size(), 4, "%s: a charge, a stomp, a kick, a trample" % id)
		for k: Variant in moves.keys():
			var m: Dictionary = moves[k]
			assert_gte(float(m["telegraph"]), 0.5, "%s/%s: telegraphed for half a second or more (%.2f)" % [id, k, float(m["telegraph"])])
			assert_true(str(m.get("counter", "")).length() > 8, "%s/%s: names its counter" % [id, k])
			assert_gt(float(m["cooldown"]), 1.0, "%s/%s: a cooldown" % [id, k])
			assert_gte(HorseBoss.tele_seconds(float(m["telegraph"])), float(m["telegraph"]))
		assert_gte(float(moves["charge"]["telegraph"]), 1.0, "%s: the charge's wind-up is long" % id)
		assert_gte(float(moves["charge"].get("telegraph_again", 1.0)), 0.5, "%s: the second charge is still telegraphed" % id)
		assert_between(float(moves["charge"]["lock_at"]), 0.5, 0.9, "%s: the line is set before the run, late enough to read" % id)
	assert_eq(HorseBoss.tele_seconds(0.2), 0.5, "no telegraph under half a second, whatever the data says")


func test_numbers_sit_where_the_design_says() -> void:
	var rounds: Dictionary = GLData.table("rounds")
	var fm: Dictionary = GLData.table("enemies")["enemies"]["foreman"]
	var paul: float = float(GLData.table("bosses/map01")["bosses"]["paul"]["hp_base"])
	var a: Dictionary = _b("totenross")
	var f: Dictionary = _b("totenross_fuhrmann")
	assert_gt(float(a["hp_base"]), paul, "round 20's horse outlasts round 15's PAUL")
	assert_lte(float(a["hp_base"]), float(RoundManager.foreman_health(20, 1, fm)), "and is no tougher than the Foreman is at round 20")
	assert_lte(float(f["hp_base"]), float(RoundManager.foreman_health(30, 1, fm)), "round 30's likewise")
	var z20: float = float(RoundManager.zombie_health(20, rounds))
	var z30: float = float(RoundManager.zombie_health(30, rounds))
	assert_between(float(a["hp_base"]) / z20, 10.0, 25.0, "round 20: worth %d of that round's zombies" % int(float(a["hp_base"]) / z20))
	assert_between(float(f["hp_base"]) / z30, 6.0, 25.0, "round 30: worth %d of that round's zombies (and the carter)" % int(float(f["hp_base"]) / z30))
	assert_eq(HomageBoss.scaled_hp(float(a["hp_base"]), 4, float(a["hp_player_step"])), float(a["hp_base"]) * 3.25, "four players: x3.25")
	var hp: float = float(GLData.table("player")["max_health"])
	for id: String in ["totenross", "totenross_fuhrmann"]:
		var b: Dictionary = _b(id)
		var worst: float = 0.0
		for k: String in ["charge", "stomp", "kick", "trample"]:
			worst = maxf(worst, float(b["moves"][k]["damage"]) * float(b["damage_mult"]))
		assert_lt(worst, hp, "%s: no single hit downs a healthy player (worst %.0f of %d)" % [id, worst, int(hp)])
		assert_between(float(b["failsafe_seconds"]), 120.0, 600.0, "%s: a fail-safe" % id)
		assert_between(float(b["horde_fraction"]), 0.3, 1.0, "%s: the horde thinned" % id)
		assert_gt(int(b["rewards"]["scrip_per_player"]), 0, "%s: a kill pays" % id)
		assert_false((b["rewards"]["drops"] as Array).is_empty(), "%s: and drops" % id)
		for d: Variant in b["rewards"]["drops"]:
			assert_true((GLData.table("powerups")["names"] as Dictionary).has(str(d)), "%s: %s is a real power-up" % [id, str(d)])
		for snd: String in ["step_sound"]:
			assert_true(AudioDirector.bank["sounds"].has(str(b["dread"][snd])), "%s: its footfall is in the sound bank" % id)
	for key: String in ["horse_boss_hoof", "horse_boss_scream", "horse_boss_breath", "horse_boss_snort", "horse_boss_drag", "horse_boss_gallop_far",
			"horse_boss_crash", "horse_boss_whip", "horse_boss_death", "horse_hoof_snow", "horse_hoof_wood", "horse_hoof_stone", "horse_snort", "horse_blow", "horse_neigh", "horse_tack"]:
		assert_true(AudioDirector.bank["sounds"].has(key), "the sound bank has %s" % key)
	assert_true(bool(AudioDirector.bank["sounds"]["horse_boss_drag"].get("loop", false)), "the drag is a loop")
	assert_true(str(AudioDirector.bank["sounds"]["horse_whinny"]["files"][0]).contains("ambience"), "the stable's far whinny (the ambience's) is untouched")


func test_phases_by_health() -> void:
	var ph: Array = _b("totenross")["phases"]
	assert_eq(ph.size(), 3)
	assert_eq(HorseBoss.phase_for(1.0, ph), 0)
	assert_eq(HorseBoss.phase_for(0.67, ph), 0)
	assert_eq(HorseBoss.phase_for(0.66, ph), 1, "the second phase at two thirds")
	assert_eq(HorseBoss.phase_for(0.4, ph), 1)
	assert_eq(HorseBoss.phase_for(0.33, ph), 2, "the third at one third")
	assert_eq(HorseBoss.phase_for(0.0, ph), 2)
	for i: int in range(1, ph.size()):
		assert_gt(float(ph[i]["speed"]), float(ph[i - 1]["speed"]), "each phase is faster")
		assert_lt(float(ph[i]["cd_mult"]), float(ph[i - 1]["cd_mult"]), "with shorter cooldowns")
		assert_lt(float(ph[i]["lights"]), float(ph[i - 1]["lights"]), "and darker")
	assert_lt(float(ph[2]["speed"]), float(GLData.table("player")["sprint_speed"]), "a sprint still outruns it between its attacks")
	assert_eq(HorseBoss.phase_for(0.5, []), 0)


func test_the_charge_lane() -> void:
	var o: Vector3 = Vector3(10, 0, 10)
	var d: Vector3 = Vector3(1, 0, 0)
	assert_true(HorseBoss.in_lane(o, d, 20.0, 1.5, Vector3(20, 0, 10)), "dead ahead: in the lane")
	assert_true(HorseBoss.in_lane(o, d, 20.0, 1.5, Vector3(20, 0, 11.4)), "a step aside: still in it")
	assert_false(HorseBoss.in_lane(o, d, 20.0, 1.5, Vector3(20, 0, 12.0)), "two metres aside: out (the side-step)")
	assert_false(HorseBoss.in_lane(o, d, 20.0, 1.5, Vector3(33, 0, 10)), "past its end")
	assert_false(HorseBoss.in_lane(o, d, 20.0, 1.5, Vector3(6, 0, 10)), "behind it")
	assert_false(HorseBoss.in_lane(o, Vector3.ZERO, 20.0, 1.5, o), "no direction, no lane")
	var m: Dictionary = _b("totenross")["moves"]["charge"]
	# a player who starts side-stepping at walking speed when the line is set is out of the lane before it arrives
	var after_lock: float = float(m["telegraph"]) * (1.0 - float(m["lock_at"]))
	var walk: float = float(GLData.table("player")["walk_speed"])
	assert_gt(after_lock * walk + float(m["min_range"]) / float(m["speed"]) * walk, float(m["width"]), "at the shortest range a walking side-step clears the lane (%.1f m in hand)" % (after_lock * walk + float(m["min_range"]) / float(m["speed"]) * walk))


func test_kick_cone_and_stomp_rings() -> void:
	var fwd: Vector3 = Vector3(0, 0, -1)
	var k: Dictionary = _b("totenross")["moves"]["kick"]
	assert_true(HorseBoss.is_behind(fwd, Vector3(0, 0, 2), float(k["behind_deg"])), "straight behind")
	assert_false(HorseBoss.is_behind(fwd, Vector3(2, 0, 0), float(k["behind_deg"])), "abeam is not behind")
	assert_false(HorseBoss.is_behind(fwd, Vector3(0, 0, -2), float(k["behind_deg"])), "nor in front")
	assert_true(HorseBoss.in_cone(-fwd, Vector3(0.5, 0, 2), float(k["cone_deg"]), float(k["range"])), "in the kick's cone")
	assert_false(HorseBoss.in_cone(-fwd, Vector3(3, 0, 1), float(k["cone_deg"]), float(k["range"])), "out to the side: missed")
	assert_false(HorseBoss.in_cone(-fwd, Vector3(0, 0, 5), float(k["cone_deg"]), float(k["range"])), "out of reach: missed")
	var s: Dictionary = _b("totenross")["moves"]["stomp"]
	assert_eq(HorseBoss.stomp_hit(1.0, true, s), [float(s["damage"]), true], "under the hooves: the full hit and the knockdown")
	assert_eq(HorseBoss.stomp_hit(3.0, true, s), [float(s["damage"]), false], "the inner ring: the hit")
	assert_eq(HorseBoss.stomp_hit(5.0, true, s), [float(s["damage_out"]), false], "the outer ring on the ground: the lesser hit")
	assert_eq(HorseBoss.stomp_hit(5.0, false, s), [0.0, false], "the outer ring in the air: nothing")
	assert_eq(HorseBoss.stomp_hit(7.0, true, s), [0.0, false], "outside: nothing")
	assert_eq(HorseBoss.stomp_hit(7.0, true, s, 1.5), [float(s["damage_out"]), false], "the last phase's ring is wider")


func test_where_it_chases_and_the_rider() -> void:
	var zones: Array = ["YARD", "GROUNDS", "STABLE"]
	assert_true(HorseBoss.may_chase(&"YARD", true, 0.0, zones))
	assert_true(HorseBoss.may_chase(&"STABLE", true, 0.2, zones))
	assert_false(HorseBoss.may_chase(&"TAPROOM", true, 0.0, zones), "not into the taproom")
	assert_false(HorseBoss.may_chase(&"GROUNDS", false, 0.0, zones), "not a zone still shut")
	assert_false(HorseBoss.may_chase(&"YARD", true, 6.2, zones), "not up the tower")
	assert_false(HorseBoss.may_chase(&"", true, 0.0, zones), "not off the map")
	assert_true(HorseBoss.may_chase(&"", true, 0.5, []), "a test scene with no zones: anywhere on its level")
	var r: Dictionary = _b("totenross_fuhrmann")["rider"]
	assert_false(HorseBoss.rider_falls(true, 0.8, float(r["falls_at"])))
	assert_true(HorseBoss.rider_falls(true, 0.5, float(r["falls_at"])), "thrown at half")
	assert_false(HorseBoss.rider_falls(false, 0.2, float(r["falls_at"])), "only once")
	assert_eq(HorseBoss.rider_hp(1000.0, r), 4000.0, "on foot: four of the round's zombies")
	assert_gte(float(r["whip"]["telegraph"]), 0.5)
	assert_true((GLData.table("enemies")["status"] as Dictionary).has(str(r["whip"]["status"])), "the whip's slow is a known status")
	assert_true((GLData.table("enemies")["tiers"] as Dictionary).has(str(r["tier"])))


func test_which_move_it_picks() -> void:
	var b: Dictionary = _b("totenross_fuhrmann")
	var moves: Dictionary = b["moves"]
	var whip: Dictionary = b["rider"]["whip"]
	var all: Dictionary = {"kick": true, "trample": true, "stomp": true, "charge": true, "whip": true}
	assert_eq(HorseBoss.pick_move({"dist": 15.0, "clear": true, "ready": all}, moves, whip), "charge", "a clear run at range: the charge")
	assert_eq(HorseBoss.pick_move({"dist": 15.0, "clear": false, "ready": all}, moves, whip), "", "no clear run: it closes in")
	assert_eq(HorseBoss.pick_move({"dist": 3.0, "clear": true, "ready": all}, moves, whip), "stomp", "close in front: the stomp")
	assert_eq(HorseBoss.pick_move({"dist": 3.0, "clear": true, "behind_s": 0.5, "ready": all}, moves, whip), "kick", "someone lingering behind: the kick first")
	assert_eq(HorseBoss.pick_move({"dist": 3.0, "clear": true, "behind_s": 0.1, "ready": all}, moves, whip), "stomp", "a moment behind it is not enough")
	assert_eq(HorseBoss.pick_move({"dist": 5.0, "clear": true, "down_near": true, "ready": all}, moves, whip), "trample", "someone knocked down: the trample")
	assert_eq(HorseBoss.pick_move({"dist": 6.0, "clear": true, "rider": true, "ready": all}, moves, whip), "whip", "between the stomp and the charge the carter's whip")
	assert_eq(HorseBoss.pick_move({"dist": 6.0, "clear": true, "rider": false, "ready": all}, moves, whip), "", "no carter, no whip")
	assert_eq(HorseBoss.pick_move({"dist": 15.0, "clear": true, "ready": {"charge": false}}, moves, whip), "", "cooling down: it closes in")
	assert_eq(HorseBoss.pick_move({"dist": 40.0, "clear": true, "ready": all}, moves, whip), "", "too far for anything")
