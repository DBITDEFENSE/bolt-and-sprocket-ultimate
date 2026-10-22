extends GutTest
## Jakub Ostrowski, the prisoner companion (Update 02 section 6.2, DECISIONS T-051): he is no player (no slot, no
## scaling, never keeps a match alive), no perks, his own 60 s bleed-out and no respawn, the profile flag, the
## campaign carry payload, half-price ammo from the party's Scrip, the gun rules, the data and lines his code
## needs, his body. The breakout and the rounds with him are smoke_jakub's.

const JAK: int = 9
const HUMAN: int = 1

var _profile: Dictionary
var _path: String


func before_each() -> void:
	_profile = ProfileSave.profile.duplicate(true)
	_path = ProfileSave.path


func after_each() -> void:
	ProfileSave.profile = _profile
	ProfileSave.path = _path


func test_data_and_brain_options() -> void:
	var c: Dictionary = JakubCompanion.cfg()
	assert_eq(float(c["bleedout_seconds"]), 60.0, "he bleeds out after 60 s")
	assert_eq(int(c["breakout"]["round"]), 5, "the breakout is round 5")
	assert_eq(JakubCompanion.pid(), JAK)
	var o: Dictionary = JakubCompanion.brain_options(HUMAN, false)
	for k: String in ["perks", "bonus_perk", "kit", "shopping"]:
		assert_false(bool(o[k]), "no %s" % k)
	assert_almost_eq(float(o["accuracy_mult"]), 1.4, 0.001, "about 70% of a player's accuracy")
	assert_eq(str(o["personality"]), "jakub")
	assert_eq(int(o["escort_pid"]), HUMAN, "he escorts the player who freed him")
	assert_eq(int(o["ammo_payer_pid"]), HUMAN, "who pays his ammo boxes")
	assert_almost_eq(float(o["ammo_price_mult"]), 0.5, 0.001, "at half price")
	assert_eq(int(o["revive_priority"]), 2, "revived after the humans and the bots")
	assert_false(bool(o["armed"]))
	assert_true(bool(JakubCompanion.brain_options(HUMAN, true)["armed"]))
	var bb: BotBrain = BotBrain.new()
	var keys: Dictionary = bb.options
	bb.free()
	for k2: String in o.keys():
		assert_true(keys.has(k2), "BotBrain knows the option %s" % k2)


func test_no_perks() -> void:
	var p: Dictionary = BotAIData.personality("jakub")
	assert_true(bool(p["economy"]["refuses_perks"]), "his personality refuses perks")
	assert_eq(float(p["actions"]["buy"]), 0.0, "and never shops")
	assert_false(bool(JakubCompanion.brain_options(HUMAN, true)["perks"]), "no spawn-kit perks, no bonus perk, no perk buys")
	assert_true(PerkManager.owned(JAK).is_empty(), "he owns none")


func test_bleeds_out_after_60_s_and_never_respawns() -> void:
	var co: CoopState = CoopState.new()
	co.add(HUMAN)
	co.add_companion(JAK)
	assert_true(co.down(JAK, float(JakubCompanion.cfg()["bleedout_seconds"])))
	assert_true(co.is_downed(JAK))
	assert_eq(co.tick(59.5).size(), 0, "still bleeding at 59.5 s")
	co.set_reviver(JAK, HUMAN, true)
	assert_eq(co.tick(5.0).size(), 0, "the clock pauses while someone revives him")
	co.set_reviver(JAK, HUMAN, false)
	var out: Array[int] = co.tick(0.6)
	assert_eq(out, [JAK] as Array[int], "bled out at 60 s")
	assert_true(co.is_dead(JAK))
	assert_eq(co.respawn_dead().size(), 0, "a new round: he does not respawn")
	assert_true(co.is_dead(JAK), "gone for the match")


func test_never_keeps_a_match_alive_and_takes_no_slot() -> void:
	var co: CoopState = CoopState.new()
	co.add(HUMAN)
	co.add(2)
	co.add_companion(JAK)
	assert_eq(co.alive_count(), 2, "he is not counted as a standing player")
	co.down(HUMAN, 45.0)
	co.down(2, 45.0)
	assert_true(co.everyone_down(), "every player down: game over, even with Jakub on his feet")
	co.revive(HUMAN)
	assert_false(co.everyone_down())
	var lonely: CoopState = CoopState.new()
	lonely.add_companion(JAK)
	assert_false(lonely.everyone_down(), "a session with only him is not a lost match")
	# the session keeps him out of the match's player table
	var nm: NetMatch = NetMatch.new()
	add_child_autofree(nm)
	var p: Player = _companion_body()
	nm.add_companion(p)
	assert_true(nm.players.is_empty(), "no player slot in the session")
	assert_eq(nm.player_of(JAK), p, "but the session can find him")
	assert_true(nm.coop.is_companion(JAK))
	nm.remove_companion(JAK)
	assert_null(nm.player_of(JAK))
	assert_false(GameState.player_ids.has(JAK) or GameState.bot_ids.has(JAK), "never in player_ids / bot_ids")


func test_round_scaling_ignores_him() -> void:
	var c: Dictionary = BotConfig.cfg()
	# the round size comes from player_ids / bot_ids only; he is in neither, so solo stays a 1-player round
	assert_eq(BotConfig.scaled_player_count(1, 0, c), 1)
	assert_eq(RoundManager.zombie_count(5, BotConfig.scaled_player_count(1, 0, c), GLData.table("rounds")),
		RoundManager.zombie_count(5, 1, GLData.table("rounds")))


func test_profile_flag_is_saved() -> void:
	ProfileSave.path = "user://_test_jakub_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	assert_false(JakubCompanion.joined_profile())
	JakubCompanion.mark_joined()
	assert_true(JakubCompanion.joined_profile())
	assert_eq(str(ProfileSave.profile["companion_jakub"]), "joined")
	assert_true(ProfileSave.has_intel(JakubCompanion.INTEL_ID), "his letter goes to the Archive")
	var text: String = FileAccess.get_file_as_string(ProfileSave.path)
	assert_string_contains(text, "\"companion_jakub\": \"joined\"")
	JakubCompanion.add_dossier_xp("joined")
	assert_eq(ProfileSave.dossier_xp(&"jakub"), int(JakubCompanion.cfg()["dossier_xp"]["joined"]), "his dossier XP")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))


func test_carry_serialization() -> void:
	var inv: Dictionary = {"s": [["kar98k", 5, 40, "semi", false, 0, 0]], "c": 0, "m": "coal_shovel", "g": 0, "t": "", "tc": 0}
	assert_true(JakubCompanion.serialize_state(JakubCompanion.State.CAGED, false, {}, 0, false).is_empty(), "caged: he stays behind")
	assert_true(JakubCompanion.serialize_state(JakubCompanion.State.WAITING, false, {}, 0, false).is_empty(), "waiting: not with you yet")
	var d: Dictionary = JakubCompanion.serialize_state(JakubCompanion.State.JOINED, true, inv, HUMAN, false)
	assert_eq(str(d["state"]), "joined")
	assert_true(bool(d["armed"]))
	var back: Dictionary = JSON.parse_string(JSON.stringify(d))   # the payload travels as data (Net.travel)
	var plan: Dictionary = JakubCompanion.restore_plan(back)
	assert_true(bool(plan["join"]))
	assert_false(bool(plan["wounded"]))
	assert_true(bool(plan["armed"]), "he keeps the gun you gave him")
	assert_eq(str(((plan["inv"] as Dictionary)["s"] as Array)[0][0]), "kar98k")
	assert_eq(int(plan["escort"]), HUMAN)
	var f: Dictionary = JakubCompanion.serialize_state(JakubCompanion.State.FALLEN, true, inv, HUMAN, false)
	var fp: Dictionary = JakubCompanion.restore_plan(f)
	assert_true(bool(fp["wounded"]), "bled out: wounded on the next map (\"Not yet. Not tonight.\")")
	assert_false(bool(fp["armed"]), "and his gun is gone")
	assert_true(JakubCompanion.restore_plan({}).is_empty())
	assert_eq(Campaign.validate_payload({"round": 10, "to": "map01_kaltenbrunn", "players": {}, "companion": d},
		GLData.table("weapons")).size(), 0, "a payload with him validates")


func test_half_price_ammo_from_the_party() -> void:
	var holder: WeaponHolder = WeaponHolder.new()
	add_child_autofree(holder)
	var w: WeaponInstance = WeaponInstance.create(&"kar98k")
	holder.slots = [w]
	holder.current_index = 0
	holder.grenades = holder.grenade_max()
	w.reserve = 0
	var box: AmmoBox = AmmoBox.new()
	add_child_autofree(box)
	Economy.reset([HUMAN])
	Economy.grant(HUMAN, 1000)
	var full: int = AmmoBox.price_for(w.data, false, AmmoBox.cfg())
	var before: int = Economy.get_scrip(HUMAN)
	assert_eq(box.use_holder(holder, JAK, HUMAN, float(JakubCompanion.cfg()["brain"]["ammo_price_mult"])), &"ok")
	assert_eq(before - Economy.get_scrip(HUMAN), int(ceil(full * 0.5)), "the party pays half of %d" % full)
	assert_eq(w.reserve, w.reserve_max())
	assert_gt(box.cooldown_left(JAK), 0.0, "his own cooldown")
	assert_eq(box.cooldown_left(HUMAN), 0.0, "not the payer's")


func test_gun_rules() -> void:
	var refused: Array = JakubCompanion.cfg()["refuses_classes"]
	assert_eq(JakubCompanion.offer_rule(2, &"bolt", false, refused), "")
	assert_eq(JakubCompanion.offer_rule(1, &"rifle", false, refused), "only_gun", "you keep your only gun")
	assert_eq(JakubCompanion.offer_rule(2, &"wonder", false, refused), "refused", "he won't touch a wonder weapon")
	assert_eq(JakubCompanion.offer_rule(2, &"smg", true, refused), "down")
	assert_eq(JakubCompanion.offer_rule(0, &"", false, refused), "empty")
	assert_eq(JakubCompanion.gun_category(&"bolt"), "GUN_BOLT")
	assert_eq(JakubCompanion.gun_category(&"smg"), "GUN_AUTO", "\"Bolt-actions, please...\"")
	assert_eq(JakubCompanion.gun_category(&"lmg"), "GUN_AUTO")
	var t: Dictionary = GLData.table("weapons")
	assert_lt(float(t["melee"]["coal_shovel"]["damage"]), float(t["melee"]["trench_knife"]["damage"]), "the coal shovel is a weak melee")
	assert_false((t["melee"]["coal_shovel"] as Dictionary).has("wall_price"), "never sold on a wall")


func test_kaltenbrunn_shortcut() -> void:
	assert_eq(int(JakubCompanion.cfg()["discounts"]["map01_kaltenbrunn"]["door_stairs"]), 500, "the Maintenance Stairs open for 500 less")
	var d: BuyDoor = BuyDoor.new()
	d.cost = 1500
	d.label = "Maintenance Stairs"
	add_child_autofree(d)
	d.set_cost(d.cost - 500)
	assert_eq(d.cost, 1000)
	assert_string_contains(d.get_prompt(null), "1000")


func test_his_lines_exist() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var cats: Dictionary = {}
	for id: Variant in lines.keys():
		var r: Dictionary = lines[id]
		if str(r["speaker"]) == "JAK":
			cats[str(r["category"])] = true
	for c: String in ["CAGE_HELLO", "CAGE_TALK", "ALARM", "BREAKOUT", "BREAKOUT_SELF", "FIGHT_KILL", "FREED", "CALL", "TALK_ASK",
			"JOIN_UNARMED", "GUN_BOLT", "GUN_RIFLE", "GUN_AUTO", "GUN_PISTOL", "GUN_SHOTGUN", "GUN_OTHER", "GUN_SWAP", "PERK_REFUSE",
			"COUSINS", "COUSINS_AFTER", "MIDNIGHT", "RETURN_WOUNDED", "M1_ARRIVE", "M1_SHORTCUT", "M2_ARRIVE", "DOWN", "REVIVED",
			"REVIVE", "TEAM_DOWN", "SPRINTER_BEHIND", "CRATE_MOVED", "POWERUP_SEEN", "CHATTER", "CMD_FOLLOW", "CMD_HOLD"]:
		assert_true(cats.has(c), "JAK:%s has lines" % c)
	assert_eq(str(lines["JAK_PERK_REFUSE_01"]["text"]), "I've seen what they put in those.")
	assert_eq(str(lines["JAK_RETURN_WOUNDED_01"]["text"]), "Not yet. Not tonight.")
	assert_eq(str(lines["JAK_GUN_AUTO_01"]["text"]), "Bolt-actions, please. I don't trust things that fire by themselves.")
	assert_eq(str(lines["JAK_COUSINS_01"]["text"]), "I know that song. Everyone in this valley knows that song.")
	for id2: String in ["JAK_BREAKOUT_01", "JAK_CALL_01", "JAK_CAGE_HELLO_01"]:
		assert_string_contains(str(lines[id2]["text"]), "(", "%s: Polish with its translation" % id2)
		assert_true((lines[id2] as Dictionary).has("tts"), "%s: a respelling for the voice bake" % id2)
	var scene: Dictionary = lines[String(JakubCompanion.WREN_SCENE)]
	var spk: Dictionary = {}
	for part: Variant in scene["exchange"]:
		spk[str((part as Array)[0])] = true
	assert_true(spk.has("WRN") and spk.has("JAK"), "the Wren scene is the two of them")
	var rules: Dictionary = GLData.load_json("res://data/gravelight/vo/rules.json")
	assert_true((rules["player_speakers"] as Array).has("JAK"), "positional, like the squad")
	assert_eq(GLVO.CHARACTER_SPEAKERS.get(&"jakub"), &"JAK")


func test_his_body() -> void:
	assert_true(RemoteBody.OUTFITS.has(&"jakub") and str(RemoteBody.OUTFITS[&"jakub"][5]) == "cap", "a cloth cap")
	var b: RemoteBody = RemoteBody.new()
	add_child_autofree(b)
	b.setup(&"jakub", JAK)
	assert_eq(b.character, &"jakub")
	assert_not_null(b.find_child("LampHook", true, false), "the miner's lamp hook on his belt")
	var band: Node3D = b.find_child("Bandage", true, false) as Node3D
	assert_true(band != null and not band.visible, "the bandage only when wounded")
	b.set_wounded(true)
	assert_true(band.visible)
	b.set_weapon(&"coal_shovel")
	assert_not_null(b.find_child("CoalShovel", true, false), "the coal shovel in his hands")
	b.update_pose(0.016, 0.0, 0.0, NetMatch.PF_FLOOR)


## A companion's Player (as JakubCompanion makes it), standalone.
func _companion_body() -> Player:
	var p: Player = Player.new()
	p.player_id = JAK
	p.is_local = false
	p.is_bot = true
	p.is_companion = true
	GameState.characters[JAK] = &"jakub"
	add_child_autofree(p)
	GameState.characters.erase(JAK)
	return p
