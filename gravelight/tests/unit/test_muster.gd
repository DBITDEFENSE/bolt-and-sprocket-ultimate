extends GutTest
## The Muster (T-079): sidearms and Field Habits unlocked by rank / stats / challenges / dossiers, the slot count,
## loadout cleaning and toggling, the profile v3 migration, the habit effects at spawn (pistol, reserve, grenades,
## gramophone, melee, Scrip, bleed-out, ammo price), bots keeping their default kit, and the co-op sanitizing.
## Never touches the real profile: ProfileSave.path points at a per-process temp file.

var _saved_path: String = ""
var _saved_profile: Dictionary = {}
var _free: Array = []


func before_all() -> void:
	_saved_path = ProfileSave.path
	_saved_profile = ProfileSave.profile.duplicate(true)
	ProfileSave.path = "user://_test_profile_muster_%d.json" % OS.get_process_id()


func before_each() -> void:
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.cur_match = {}
	Muster.match_kits = {}
	GLSettings.values["classic_rules"] = false


func after_each() -> void:
	for n: Variant in _free:
		if is_instance_valid(n):
			(n as Node).free()
	_free.clear()
	Muster.match_kits = {}


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.profile = _saved_profile
	ProfileSave.cur_match = {}


## A profile at `rank_n` (XP set to the rank's threshold).
func _at_rank(rank_n: int) -> Dictionary:
	var p: Dictionary = ProfileSave.new_profile()
	p["xp"] = ProfileSave.total_for_rank(rank_n, ProfileSave.curve())
	return p


func _player(pid: int = 1, bot: bool = false) -> Player:
	var p: Player = Player.new()
	p.player_id = pid
	p.is_bot = bot
	var h: WeaponHolder = WeaponHolder.new()
	h.mirror = true
	h.player = p
	p.weapons = h
	h.call("_set_start_loadout")
	_free.append(h)
	_free.append(p)
	return p


# ---------------------------------------------------------------- data

func test_data_is_complete() -> void:
	var w: Dictionary = GLData.table("weapons")
	assert_between(Muster.habit_rows().size(), 10, 15, "10-15 Field Habits")
	assert_gte(Muster.pistol_rows().size(), 4, "the M1911 and at least three more sidearms")
	for id: String in Muster.pistol_ids():
		assert_true((w["weapons"] as Dictionary).has(id), "sidearm %s is a weapon" % id)
		assert_eq(str(w["weapons"][id]["class"]), "pistol", id)
		assert_true(WeaponModels.known_ids().has(id), "%s has a model" % id)
		assert_true(WeaponKit.accepts(WeaponInstance.create(StringName(id))), "the Armorer's Bench works on the %s" % id)
	var perks: Dictionary = GLData.table("perks")["perks"]
	for h: Dictionary in Muster.habit_rows():
		assert_false(perks.has(str(h["id"])), "a habit is not a tonic: %s" % h["id"])
		assert_false((h.get("effects", {}) as Dictionary).is_empty(), "%s does something" % h["id"])
		assert_false(str(h["name"]).to_lower().contains("perk"), "never called a perk")


func test_sidearms_are_sidegrades_at_round_one() -> void:
	var w: Dictionary = GLData.table("weapons")["weapons"]
	var base: Dictionary = w["m1911"]
	var base_dps: float = float(base["damage"]) * float(base["rpm"])
	var hp1: float = float(RoundManager.zombie_health(1, GLData.table("rounds")))
	for id: String in Muster.pistol_ids():
		var d: Dictionary = w[id]
		var dps: float = float(d["damage"]) * float(d["rpm"])
		assert_between(dps / base_dps, 0.9, 1.1, "%s DPS within 10%% of the M1911" % id)
		assert_gte(WeaponInstance.create(StringName(id)).f("damage") * WeaponInstance.create(StringName(id)).limb_mult(&"head"), hp1, "%s still kills a round-1 zombie with one headshot" % id)
		var ammo: float = float(d["damage"]) * float(int(d["mag"]) + int(d["reserve"]))
		var base_ammo: float = float(base["damage"]) * float(int(base["mag"]) + int(base["reserve"]))
		assert_between(ammo / base_ammo, 0.85, 1.25, "%s carries about the same total damage" % id)
		var up: String = str(d.get("upgraded", ""))
		assert_true((GLData.table("weapons")["upgraded"] as Dictionary).has(up), "%s has a Crucible version" % id)


# ---------------------------------------------------------------- unlocks and slots

func test_slots_grow_with_rank() -> void:
	assert_eq(Muster.slots_for_rank(1), 1)
	assert_eq(Muster.slots_for_rank(9), 1)
	assert_eq(Muster.slots_for_rank(10), 2)
	assert_eq(Muster.slots_for_rank(24), 2)
	assert_eq(Muster.slots_for_rank(25), 3)
	assert_eq(Muster.slots_for_rank(60), 3)
	assert_eq(Muster.slots_for(_at_rank(10)), 2)
	assert_eq(Muster.next_slot_rank(3), 10)
	assert_eq(Muster.next_slot_rank(25), 0)


func test_unlocks_by_rank_stat_challenges_and_dossier() -> void:
	var r1: Dictionary = _at_rank(1)
	assert_true(Muster.pistol_unlocked("m1911", r1))
	assert_false(Muster.pistol_unlocked("walther_p38", r1))
	assert_true(Muster.pistol_unlocked("walther_p38", _at_rank(4)))
	assert_true(Muster.habit_unlocked("pay_packet", r1))
	assert_false(Muster.habit_unlocked("cool_head", _at_rank(9)))
	assert_true(Muster.habit_unlocked("cool_head", _at_rank(10)))
	# a career stat opens the Carpenter's Pencil before its rank
	var boards: Dictionary = _at_rank(1)
	boards["stats"]["boards"] = 150
	assert_true(Muster.habit_unlocked("carpenters_pencil", boards))
	# challenges completed open the Spare Record
	var ch: Dictionary = _at_rank(1)
	ch["challenges_done"] = ["a", "b", "c"]
	assert_true(Muster.habit_unlocked("spare_record", ch))
	# a survivor's dossier opens the Webley for that survivor only
	var dos: Dictionary = _at_rank(1)
	dos["dossiers"]["peg"] = 15000   # dossier level 4
	assert_true(Muster.pistol_unlocked("webley", dos, "peg"))
	assert_false(Muster.pistol_unlocked("webley", dos, "dutch"))


func test_a_commendation_keeps_every_unlock_and_slot() -> void:
	var p: Dictionary = _at_rank(1)
	p["prestige"] = 1
	assert_eq(Muster.slots_for(p), 3)
	assert_true(Muster.pistol_unlocked("luger_p08", p))
	assert_true(Muster.habit_unlocked("steady_hands", p))


func test_rank_ups_list_what_they_open() -> void:
	assert_true(Array(Muster.unlocks_at_rank(10)).has("Field Habit slot 2"))
	assert_true(Array(Muster.unlocks_at_rank(4)).has("Sidearm: Walther P38"))
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.cur_match = {"active": true, "unlocks": [], "xp": 0, "challenges": []}
	ProfileSave._apply_xp(ProfileSave.total_for_rank(5, ProfileSave.curve()))
	assert_true((ProfileSave.cur_match["unlocks"] as Array).has("Sidearm: Walther P38"), "shown on the game-over screen")
	assert_true((ProfileSave.cur_match["unlocks"] as Array).has("Field Habit: Grenade in the Boot"))
	ProfileSave.cur_match = {}


# ---------------------------------------------------------------- loadouts

func test_clean_and_loadout_for_drop_locked_and_extra() -> void:
	var p: Dictionary = _at_rank(1)
	p["muster"]["dutch"] = {"pistol": "luger_p08", "habits": ["pay_packet", "cool_head", "nonsense", "pay_packet"]}
	var k: Dictionary = Muster.loadout_for("dutch", p)
	assert_eq(str(k["pistol"]), "m1911", "a locked sidearm falls back to the M1911")
	assert_eq(k["habits"], ["pay_packet"], "locked, unknown and repeated habits are dropped; 1 slot at rank 1")
	var p2: Dictionary = _at_rank(30)
	p2["muster"]["wren"] = {"pistol": "luger_p08", "habits": ["pay_packet", "cool_head", "whetstone", "scrounger"]}
	var k2: Dictionary = Muster.loadout_for("wren", p2)
	assert_eq(str(k2["pistol"]), "luger_p08")
	assert_eq((k2["habits"] as Array).size(), 3, "three slots at rank 25+")
	assert_eq(Muster.clean({"pistol": "mg42"}, 3)["pistol"], "m1911", "only sidearms")


func test_toggle_and_set_pistol() -> void:
	var p: Dictionary = _at_rank(10)
	var k: Dictionary = {"pistol": "m1911", "habits": []}
	var r: Dictionary = Muster.toggle_habit(k, "pay_packet", p, "dutch")
	assert_eq(r["result"], "on")
	r = Muster.toggle_habit(r["kit"], "whetstone", p, "dutch")
	assert_eq(r["result"], "on")
	r = Muster.toggle_habit(r["kit"], "full_haversack", p, "dutch")
	assert_eq(r["result"], "full", "two slots at rank 10")
	r = Muster.toggle_habit(r["kit"], "steady_hands", p, "dutch")
	assert_eq(r["result"], "locked")
	r = Muster.toggle_habit(r["kit"], "pay_packet", p, "dutch")
	assert_eq(r["result"], "off")
	assert_eq(r["kit"]["habits"], ["whetstone"])
	assert_eq(Muster.set_pistol(k, "webley", p, "dutch")["pistol"], "webley")
	assert_eq(Muster.set_pistol(k, "luger_p08", p, "dutch")["pistol"], "m1911", "locked: unchanged")


func test_save_loadout_persists_per_survivor() -> void:
	ProfileSave.profile = _at_rank(12)
	Muster.save_loadout("deacon", {"pistol": "webley", "habits": ["carpenters_pencil", "cool_head"]})
	Muster.save_loadout("peg", {"pistol": "walther_p38", "habits": ["boot_grenade"]})
	ProfileSave.load_profile()
	assert_eq(Muster.loadout_for("deacon", ProfileSave.profile)["pistol"], "webley")
	assert_eq(Muster.loadout_for("deacon", ProfileSave.profile)["habits"], ["carpenters_pencil", "cool_head"])
	assert_eq(Muster.loadout_for("peg", ProfileSave.profile)["pistol"], "walther_p38")
	assert_eq(Muster.loadout_for("dutch", ProfileSave.profile)["pistol"], "m1911", "each survivor has their own")


func test_v2_profile_migrates_to_v3() -> void:
	var v2: Dictionary = {"version": 2, "xp": 9000, "xp_lifetime": 9000, "rank": 6, "prestige": 0,
		"dossiers": {"dutch": 100, "peg": 0, "deacon": 0, "wren": 0}, "weapon_kills": {"m1911": 80}, "stats": {"kills": 5},
		"unlocked": ["card_ledger_stamp"], "equipped": {"m1911_pick": "grip:checkered"}, "challenges": {}, "challenge_career": {},
		"challenges_done": [], "maps_unlocked": ["map00_crossroads"], "best_round": {}, "intel": [], "egg_rewards": {}}
	var m: Dictionary = ProfileSave.migrate(v2)
	assert_eq(int(m["version"]), 3)
	assert_eq(int(m["xp"]), 9000, "nothing else changes")
	assert_eq(str(m["equipped"]["m1911_pick"]), "grip:checkered")
	for c: String in ["dutch", "peg", "deacon", "wren"]:
		assert_eq(str(m["muster"][c]["pistol"]), "m1911", "%s starts with the M1911" % c)
		assert_eq((m["muster"][c]["habits"] as Array).size(), 0)
	var again: Dictionary = ProfileSave.migrate(m.duplicate(true))
	assert_eq(again, m, "migrating twice changes nothing")


# ---------------------------------------------------------------- effects at spawn

func test_spawn_kit_applies_the_pistol_and_habits() -> void:
	Muster.match_kits = {1: {"pistol": "walther_p38", "habits": ["full_haversack", "boot_grenade", "spare_record"]}}
	var p: Player = _player(1)
	var w: WeaponInstance = p.weapons.slots[0]
	assert_eq(w.id, &"walther_p38")
	assert_eq(w.reserve, int(round(88 * 1.5)), "Full Haversack: +50% reserve")
	var base: int = int(GLData.table("player")["start_loadout"]["lethal_count"])
	assert_eq(p.weapons.grenades, base + 1, "Grenade in the Boot")
	assert_eq(p.weapons.tactical_id, &"gramophone")
	assert_eq(p.weapons.tactical_count, 1, "Spare Record")
	p.weapons.reset_loadout.call()   # a co-op respawn gets the same kit
	assert_eq(p.weapons.slots[0].id, &"walther_p38")


func test_bots_and_kitless_players_keep_the_default_kit() -> void:
	Muster.match_kits = {1: {"pistol": "luger_p08", "habits": ["boot_grenade"]}}
	var bot: Player = _player(2, true)
	assert_eq(bot.weapons.slots[0].id, &"m1911", "a bot keeps its default")
	Muster.match_kits[2] = {"pistol": "luger_p08", "habits": ["boot_grenade"]}
	var bot2: Player = _player(2, true)
	assert_eq(bot2.weapons.slots[0].id, &"m1911", "even if a kit were registered under its id")
	var other: Player = _player(3)
	assert_eq(other.weapons.slots[0].id, &"m1911", "no kit, no change")
	assert_eq(other.weapons.grenades, int(GLData.table("player")["start_loadout"]["lethal_count"]))


func test_last_stand_crawls_with_your_own_sidearm() -> void:
	Muster.match_kits = {1: {"pistol": "webley", "habits": []}}
	var p: Player = _player(1)
	p.weapons.slots.clear()
	p.weapons.give_weapon(&"thompson")
	p.weapons.enter_last_stand()
	assert_eq(p.weapons.current().id, &"webley")


func test_values_combine() -> void:
	Muster.match_kits = {1: {"pistol": "m1911", "habits": ["whetstone", "pay_packet", "scrounger"]}}
	assert_almost_eq(Muster.mult(1, "melee_damage_mult"), 1.25, 0.001)
	assert_eq(int(Muster.value(1, "start_scrip", 0)), 250)
	assert_almost_eq(Muster.mult(1, "ammo_price_mult"), 0.85, 0.001)
	assert_almost_eq(Muster.mult(1, "regen_delay_mult"), 1.0, 0.001, "not equipped: no effect")
	assert_almost_eq(Muster.mult(2, "melee_damage_mult"), 1.0, 0.001, "other players unaffected")


func test_match_start_grants_scrip_and_bleedout() -> void:
	Muster.match_kits = {1: {"pistol": "m1911", "habits": ["pay_packet", "field_dressing"]}}
	var p: Player = _player(1)
	var q: Player = _player(2)
	Economy.reset([1, 2] as Array[int])
	var start: int = Economy.get_scrip(1)
	Muster.apply_match_start({1: p, 2: q}, true)
	assert_eq(Economy.get_scrip(1), start + 250)
	assert_eq(Economy.get_scrip(2), start, "no kit, no bonus")
	assert_almost_eq(p.bleedout_seconds, float(GLData.table("player")["bleedout_seconds"]) + 15.0, 0.01)
	assert_eq(q.bleedout_seconds, 0.0)
	Economy.reset([1] as Array[int])
	Muster.apply_match_start({1: p}, false)
	assert_eq(Economy.get_scrip(1), start, "a campaign arrival brings its own Scrip")


func test_ammo_box_price_and_classic_rules() -> void:
	Muster.match_kits = {1: {"pistol": "m1911", "habits": ["scrounger"]}}
	var p: Player = _player(1)
	p.weapons.slots[0].reserve = 0
	var full: int = AmmoBox.price_for(p.weapons.slots[0].data, false, AmmoBox.cfg())
	var q: Dictionary = AmmoBox.quote(p.weapons, AmmoBox.cfg())
	assert_eq(int(q["price"]), int(round(full * 0.85)))
	GameState.character_id = &"dutch"
	ProfileSave.profile = _at_rank(30)
	Muster.save_loadout("dutch", {"pistol": "luger_p08", "habits": ["scrounger"]})
	GLSettings.values["classic_rules"] = true
	Muster.begin_match(false)
	assert_true(Muster.match_kits.is_empty(), "Classic Rules: no Muster")
	GLSettings.values["classic_rules"] = false
	Muster.begin_match(false)
	assert_eq(str(Muster.kit_of(1)["pistol"]), "luger_p08", "solo: the local human is id 1, from the profile")


func test_coop_kits_are_sanitized() -> void:
	var s: Dictionary = Muster.sanitize_kits({"dutch": {"pistol": "panzerschreck", "habits": ["pay_packet", "a", "whetstone", "cool_head", "scrounger"]},
		"jakub": {"pistol": "m1911"}, "peg": "nonsense"})
	assert_eq(str(s["dutch"]["pistol"]), "m1911", "only sidearms")
	assert_eq((s["dutch"]["habits"] as Array).size(), 3, "capped at the slot maximum")
	assert_false(s.has("jakub"), "only the four survivors")
	assert_eq(str(s["peg"]["pistol"]), "m1911", "garbage becomes the default kit")
	assert_true(Muster.sanitize_kits("x").is_empty())


func test_nachtglas_ignores_the_optional_sidearms() -> void:
	var all: Dictionary = {}
	for w: Variant in GLData.table("weapons")["weapons"].keys():
		if not bool((GLData.table("weapons")["weapons"][w] as Dictionary).get("muster_sidearm", false)):
			all[str(w)] = 2000
	ProfileSave.profile["weapon_kills"] = all
	assert_true(ProfileSave.nachtglas_unlocked(), "Gold on every base weapon, without the Muster's extra sidearms")
