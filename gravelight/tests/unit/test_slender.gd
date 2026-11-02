extends GutTest
## HB3, THE SLENDER at Totenhafen (docs/HOMAGE_BOSSES.md section 6; docs/U10_TOTENHAFEN_DESIGN.md section 9;
## DECISIONS T-160): the Watch system's state machine (every fill and drain source, the tiers, the bot cap, the
## room-busy cap, the release immunity, the shot cap, decoy hits), the lit rule's pools and phases, the door
## lock / unlock rule, the Watch Room's timing, the schedule (25 standalone / 45 campaign, the power, the flags,
## the Foreman / Bellringer +1), health, the rewards, and no placeholder on screen.

var file: Dictionary
var cfg: Dictionary
var w: Dictionary
var _settings: Dictionary


func before_all() -> void:
	file = GLData.table("bosses/map02")
	cfg = HomageEncounter.block(file, "the_slender")
	w = cfg.get("watch", {})


func before_each() -> void:
	_settings = GLSettings.values.duplicate(true)
	GLSettings.values["homage_bosses"] = true
	GLSettings.values["homage_names"] = "real"


func after_each() -> void:
	GLSettings.values = _settings
	RoundManager.stop()


# ---------------------------------------------------------------- data, schedule, health

func test_data_block() -> void:
	assert_false(cfg.is_empty(), "bosses/map02.json has the_slender")
	assert_eq(str(cfg["map"]), "map02_totenhafen", "moved from Morgenrot to Totenhafen (the Hafenwaechter)")
	assert_eq(int(cfg["round"]), 25)
	assert_eq(int(cfg["round_campaign"]), 45)
	assert_almost_eq(float(cfg["horde_fraction"]), 0.5, 0.0001)
	assert_almost_eq(float(cfg["failsafe_seconds"]), 480.0, 0.0001)
	assert_true(cfg.has("bots_alone"))
	assert_true(HomageEncounter.applies(&"map02_totenhafen", cfg))
	assert_false(HomageEncounter.applies(&"map01_kaltenbrunn", cfg))


func test_morgenrot_hook() -> void:
	var m3: Dictionary = HomageEncounter.block(GLData.table("bosses/map03"), "the_slender")
	assert_false(m3.is_empty(), "bosses/map03.json keeps a placeholder entry")
	assert_eq(str(m3.get("script", "")), "res://gravelight/enemies/homage/slender.gd", "pointing at the same script")
	assert_false(HomageEncounter.applies(&"map02_totenhafen", m3), "the hook never fires at Totenhafen")


func test_schedule() -> void:
	assert_eq(SlenderEncounter.round_for(cfg, false), 25, "standalone")
	assert_eq(SlenderEncounter.round_for(cfg, true), 45, "campaign")
	assert_true(SlenderEncounter.may_start(cfg, true, []))
	assert_false(SlenderEncounter.may_start(cfg, false, []), "he needs the power (the lamp pools)")
	assert_false(SlenderEncounter.may_start(cfg, true, ["sailing"]), "never while the boat sails")
	assert_false(SlenderEncounter.may_start(cfg, true, ["boss_fight"]), "never over another boss")
	assert_eq(HomageEncounter.pick_round(25, 25, 30), 26, "a Foreman round: +1")
	assert_eq(HomageEncounter.pick_round(25, 20, 25), 26, "a Bellringer round: +1")
	assert_eq(HomageEncounter.pick_round(25, 20, 30), 25)


func test_health() -> void:
	var want: Array = [35000.0, 61250.0, 87500.0, 113750.0]
	for p: int in 4:
		assert_almost_eq(HomageEncounter.visit_hp(cfg, p + 1, 0), want[p], 0.01, "%d players" % (p + 1))
	assert_almost_eq(HomageEncounter.visit_hp(cfg, 1, 1), 35000.0, 0.01, "a return comes back at full HP, not more")


# ---------------------------------------------------------------- the Watch system

func test_tiers() -> void:
	assert_eq(WatchMeter.tier_of(0.0), WatchMeter.Tier.NONE)
	assert_eq(WatchMeter.tier_of(9.9), WatchMeter.Tier.NONE)
	assert_eq(WatchMeter.tier_of(10.0), WatchMeter.Tier.LOW)
	assert_eq(WatchMeter.tier_of(40.0), WatchMeter.Tier.MEDIUM)
	assert_eq(WatchMeter.tier_of(70.0), WatchMeter.Tier.HIGH)
	assert_eq(WatchMeter.tier_of(95.0), WatchMeter.Tier.CRITICAL)
	assert_eq(WatchMeter.TIER_WORDS[WatchMeter.Tier.LOW], "Noted.")
	assert_eq(WatchMeter.TIER_WORDS[WatchMeter.Tier.CRITICAL], "Quarantined.")


func test_fill_sources() -> void:
	var m: WatchMeter = WatchMeter.new(w)
	assert_almost_eq(m.rate({"pool": true, "seen": true}, 0.0, 0.0), 12.0, 0.001, "his lantern's pool +12")
	assert_almost_eq(m.rate({"sweep": true, "seen": true}, 0.0, 0.0), 35.0, 0.001, "a sweep cone +35")
	assert_almost_eq(m.rate({"looking": true, "seen": true}, 1.4, 0.0), 0.0, 0.001, "looking: nothing for 1.5 s")
	assert_almost_eq(m.rate({"looking": true, "seen": true}, 1.6, 0.0), 8.0, 0.001, "then +8")
	assert_almost_eq(m.rate({"dark": true, "seen": true}, 0.0, 2.0), 4.0, 0.001, "still in the dark 2 s: +4")
	assert_almost_eq(m.rate({"dark": true, "seen": true}, 0.0, 1.0), 0.0, 0.001)


func test_drain_sources() -> void:
	var m: WatchMeter = WatchMeter.new(w)
	assert_almost_eq(m.rate({"seen": false}, 0.0, 0.0), -6.0, 0.001, "out of his sight -6")
	assert_almost_eq(m.rate({"seen": true, "lit": true}, 0.0, 0.0), -15.0, 0.001, "real light -15")
	assert_almost_eq(m.rate({"seen": false, "lit": true, "teammate": true}, 0.0, 0.0), -25.0, 0.001, "they stack")
	m.value = 50.0
	m.tick(1.0, {"seen": false, "lit": true, "teammate": true})
	assert_almost_eq(m.value, 25.0, 0.001)
	m.tick(10.0, {"seen": false})
	assert_almost_eq(m.value, 0.0, 0.001, "never below 0")


func test_tier_climb_and_quarantine_due() -> void:
	var m: WatchMeter = WatchMeter.new(w)
	var due: bool = false
	for i: int in 30:
		due = m.tick(0.1, {"seen": true, "sweep": true, "pool": true, "moving": true})
	assert_true(m.value >= 100.0 and due, "a sweep plus the pool fills it in ~2 s and he wants you")
	assert_eq(m.tier_events, [1, 2, 3, 4] as Array[int], "every tier crossed in order (each one whispered once)")
	m.on_quarantined()
	m.on_released()
	assert_eq(m.value, 0.0)
	assert_almost_eq(m.immune, 10.0, 0.001, "10 s of immunity")
	m.tick(5.0, {"seen": true, "sweep": true})
	assert_eq(m.value, 0.0, "immune: nothing logs")
	m.tick(5.1, {"seen": true, "sweep": true})
	m.tick(0.5, {"seen": true, "sweep": true})
	assert_gt(m.value, 0.0, "after the immunity it logs again")


func test_bot_cap_and_room_busy_cap() -> void:
	var bot: WatchMeter = WatchMeter.new(w, true)
	for i: int in 50:
		bot.tick(0.1, {"seen": true, "sweep": true})
	assert_almost_eq(bot.value, 94.0, 0.001, "bots stop at HIGH (D8)")
	assert_false(bot.due(), "a bot is never quarantined")
	var p: WatchMeter = WatchMeter.new(w)
	for i: int in 50:
		p.tick(0.1, {"seen": true, "sweep": true}, true)
	assert_almost_eq(p.value, 99.0, 0.001, "a second player waits at CRITICAL while the room is busy")
	assert_false(p.due())


func test_shots_and_decoys() -> void:
	var m: WatchMeter = WatchMeter.new(w)
	for i: int in 20:
		m.on_shot()
	assert_almost_eq(m.value, 10.0, 0.001, "+2 a shot, at most +10 a second")
	m.tick(1.0, {"seen": true})
	m.on_shot()
	assert_almost_eq(m.value, 12.0, 0.001, "the budget refills over the second")
	m.on_decoy_hit()
	assert_almost_eq(m.value, 27.0, 0.001, "a decoy hit +15")


# ---------------------------------------------------------------- light, phases, doors, the room

func test_lit_pools() -> void:
	var pools: Array = [[0.0, 0.0, 0.0, 5.0, true], [20.0, 4.0, 0.0, 3.0, false]]
	assert_true(Slender.lit_by_pools(Vector3(3, 0, 0), pools, [true, true], true))
	assert_false(Slender.lit_by_pools(Vector3(3, 0, 0), pools, [true, true], false), "a powered pool is dark without power")
	assert_false(Slender.lit_by_pools(Vector3(3, 0, 0), pools, [false, true], true), "a pool out for End of Shift")
	assert_true(Slender.lit_by_pools(Vector3(21, 4.5, 0), pools, [true, true], false), "a battery pool needs no power")
	assert_false(Slender.lit_by_pools(Vector3(21, 12, 0), pools, [true, true], false), "above its height")
	assert_false(Slender.lit_by_pools(Vector3(8, 0, 0), pools, [true, true], true), "outside the radius")


func test_phases() -> void:
	var mv: Dictionary = cfg["moves"]
	assert_eq(Slender.phase_for(1.0, mv), 1)
	assert_eq(Slender.phase_for(0.51, mv), 1)
	assert_eq(Slender.phase_for(0.49, mv), 2, "Shift Change below 50%")
	assert_eq(Slender.phase_for(0.19, mv), 3, "End of Shift below 20%")


func test_door_lock_unlock_rule() -> void:
	var boxes: Array = [[-20.0, -0.5, 30.0, 52.0, 7.0, 84.0]]
	var door: Vector3 = Vector3(-10, 0, 31.5)
	assert_false(Slender.door_should_unlock(Vector3(-10, 4, 50), door, boxes, 9.0), "still in the pen hall: stays locked")
	assert_false(Slender.door_should_unlock(Vector3(-10, 0, 25), door, boxes, 9.0), "out of the zone but close: stays")
	assert_true(Slender.door_should_unlock(Vector3(-10, 0, 15), door, boxes, 9.0), "out of the zone and away: opens free")
	var dl: Array = (cfg["doors"] as Dictionary)["list"]
	var names: Array = []
	for e: Variant in dl:
		names.append(str((e as Dictionary)["node"]))
	assert_true(names.has("Door_PenHall_W") and names.has("Door_PenHall_E") and names.has("Door_Pumps"), "the Pen Hall doors and the pump stair")


func test_watch_room_timing() -> void:
	var q: Dictionary = cfg["quarantine"]
	assert_almost_eq(WatchRoom.time_limit(q, false), 25.0, 0.001)
	assert_almost_eq(WatchRoom.time_limit(q, true), 35.0, 0.001, "solo: 35 s")
	assert_eq(WatchRoom.outcome(10.0, 25.0, 0.0), "")
	assert_eq(WatchRoom.outcome(25.0, 25.0, 0.0), "fail", "too late: returned downed")
	assert_eq(WatchRoom.outcome(5.0, 25.0, 1.0), "release", "five lantern hits release you")
	assert_almost_eq(float(q["release_per_lantern_hit"]) * 5.0, 1.0, 0.001)
	assert_almost_eq(WatchRoom.figure_progress(0.0, 25.0), 0.0, 0.001)
	assert_almost_eq(WatchRoom.figure_progress(24.0, 25.0), 1.0, 0.001, "he reaches the desk at 24 s")


# ---------------------------------------------------------------- rewards, names

func test_rewards() -> void:
	var plan: Dictionary = HomageEncounter.reward_plan(cfg, [1, 2, 3])
	assert_eq(int(plan["scrip"][3]), 2500)
	for u: String in ["card_night_shift", "charm_violet_lantern", "ARC_HB_SLENDER", "squad_overwatch"]:
		assert_true((plan["unlocks"] as Array).has(u), u)
	assert_true((plan["intel"] as Array).has("INT_HB_04"), "the Watch-Book")


func test_names_never_placeholders() -> void:
	var real: PackedStringArray = HomageEncounter.title_of("devin", true, "THE SLENDER")
	assert_eq(real[0], "DEVIN")
	assert_eq(real[1], "THE SLENDER")
	var world: PackedStringArray = HomageEncounter.title_of("devin", false, "THE SLENDER")
	assert_eq(world[0], "THE SLENDER", "In-World: no real name")
	var doc: String = HomageEncounter.fill_tokens(str((cfg["archive"] as Dictionary)["INT_HB_04"]["text"]))
	assert_false(doc.contains("%") or doc.contains("[DEVIN"), "the flyleaf never shows a token")
	for id: Variant in (cfg["lines"] as Dictionary).keys():
		if (cfg["lines"][id] is Dictionary):
			assert_false(HomageEncounter.fill_tokens(str(cfg["lines"][id]["text"])).contains("%"), str(id))
