extends GutTest
## T-263: the arms locker (WeaponLocker, data/gravelight/weapon_locker.json). One compartment per player for the
## match: the gun in your hands goes in as it is (tier, attachments, ammunition, fire mode) for store_cost Scrip and
## comes back free; with the slots full the hold swaps; you never lock away your last gun or take a second copy;
## what is inside survives the down, the bleed-out and the respawn; each player has their own; bots never use it;
## nothing touches the profile (open in Classic Rules); a new match starts empty and a campaign hop carries it; the
## Map 0 row stands on free wall, off the navmesh, with room in front.

const Spot: GDScript = preload("res://gravelight/tools_src/locker_spot.gd")
const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const PID: int = 61
const PID2: int = 62

var _saved_profile: Dictionary
var _saved_settings: Dictionary
var cost: int


func before_each() -> void:
	_saved_profile = ProfileSave.profile.duplicate(true)
	_saved_settings = GLSettings.values.duplicate(true)
	GLSettings.values["classic_rules"] = false
	PerkManager.reset_match()
	Economy.reset([PID, PID2])
	Economy._scrip[PID] = 5000
	Economy._scrip[PID2] = 5000
	WeaponLocker.reset_match()
	cost = int(WeaponLocker.cfg().get("store_cost", 0))


func after_each() -> void:
	WeaponLocker.reset_match()
	ProfileSave.profile = _saved_profile
	GLSettings.values = _saved_settings


## A player outside the tree with a holder of their own carrying `ids` (the first in hand).
func _player(pid: int, ids: Array) -> Player:
	var p: Player = Player.new()
	p.player_id = pid
	p.is_local = false
	autofree(p)
	var h: WeaponHolder = WeaponHolder.new()
	h.mirror = true   # no viewmodel in a test
	h.player = p
	autofree(h)
	p.weapons = h
	for id: Variant in ids:
		h.slots.append(WeaponInstance.create(StringName(str(id))))
	h.current_index = 0
	return p


func _ids(p: Player) -> Array:
	var out: Array = []
	for w: WeaponInstance in p.weapons.slots:
		out.append(String(w.id))
	return out


# ---------------------------------------------------------------- store / take / swap

func test_store_keeps_the_gun_as_it_is_and_charges_the_rent() -> void:
	var p: Player = _player(PID, ["thompson_up", "m1911"])
	var w: WeaponInstance = p.weapons.current()
	w.tier = 2
	WeaponKit.install(w, "mag", "extended")
	w.mag = 7
	w.reserve = 33
	var modes: Array = w.fire_modes()
	w.fire_mode = str(modes[modes.size() - 1])
	var mag_size: int = w.mag_size()
	assert_eq(WeaponLocker.plan_for(p)["action"], &"store")
	assert_eq(WeaponLocker.use(p), &"store")
	assert_eq(Economy.get_scrip(PID), 5000 - cost, "store_cost paid")
	assert_eq(_ids(p), ["m1911"], "the Thompson left the hands")
	assert_true(WeaponLocker.has_stored(PID))
	var back: WeaponInstance = WeaponLocker.instance_of(WeaponLocker.stored(PID))
	assert_eq(back.id, &"thompson_up")
	assert_eq(back.tier, 2, "the Crucible tier")
	assert_eq(back.kit, {"mag": "extended"}, "the attachments")
	assert_eq(back.mag_size(), mag_size)
	assert_eq([back.mag, back.reserve], [7, 33], "the rounds as they were: no free refill")
	assert_eq(back.fire_mode, w.fire_mode)


func test_take_is_free_and_gives_the_very_gun_back() -> void:
	var p: Player = _player(PID, ["kar98k", "m1911"])
	p.weapons.current().mag = 2
	p.weapons.current().reserve = 11
	WeaponLocker.use(p)
	var after_store: int = Economy.get_scrip(PID)
	assert_eq(WeaponLocker.plan_for(p)["action"], &"take", "a free slot: it comes out")
	assert_eq(WeaponLocker.use(p), &"take")
	assert_eq(Economy.get_scrip(PID), after_store - int(WeaponLocker.cfg().get("withdraw_cost", 0)))
	assert_eq(_ids(p), ["m1911", "kar98k"])
	assert_eq(p.weapons.current().id, &"kar98k", "in the hands")
	assert_eq([p.weapons.current().mag, p.weapons.current().reserve], [2, 11])
	assert_false(WeaponLocker.has_stored(PID), "the compartment is empty again")
	assert_eq(WeaponLocker.plan_for(p)["action"], &"store")


func test_swap_when_the_slots_are_full() -> void:
	var p: Player = _player(PID, ["bar", "m1911"])
	WeaponLocker.use(p)   # the BAR goes in
	p.weapons.give_weapon(&"mp40")   # a wall buy fills the slot
	assert_eq(_ids(p), ["m1911", "mp40"])
	var before: int = Economy.get_scrip(PID)
	var pl: Dictionary = WeaponLocker.plan_for(p)
	assert_eq(pl["action"], &"swap")
	assert_eq(WeaponLocker.use(p), &"swap")
	assert_eq(_ids(p), ["m1911", "bar"], "the MP40 went in, the BAR came out")
	assert_eq(p.weapons.current().id, &"bar")
	assert_eq(WeaponLocker.instance_of(WeaponLocker.stored(PID)).id, &"mp40")
	assert_eq(Economy.get_scrip(PID), before - int(pl["cost"]))
	assert_eq(int(pl["cost"]), cost + int(WeaponLocker.cfg().get("withdraw_cost", 0)), "a swap is a store")


func test_empty_hands_and_the_last_gun() -> void:
	var p: Player = _player(PID, ["m1911"])
	var pl: Dictionary = WeaponLocker.plan_for(p)
	assert_eq([pl["action"], pl["why"]], [&"none", "last_gun"], "never the last gun")
	assert_eq(WeaponLocker.use(p), &"none")
	assert_eq(Economy.get_scrip(PID), 5000, "nothing charged")
	var bare: Player = _player(PID2, [])
	assert_eq(WeaponLocker.plan_for(bare)["why"], "empty", "nothing in the hands, nothing inside")
	# empty hands with a gun inside: it comes out
	WeaponLocker._put(PID2, WeaponHolder.net_entry(WeaponInstance.create(&"mp40")))
	assert_eq(WeaponLocker.plan_for(bare)["action"], &"take")
	assert_eq(WeaponLocker.use(bare), &"take")
	assert_eq(_ids(bare), ["mp40"])


func test_no_scrip_changes_nothing() -> void:
	var p: Player = _player(PID, ["mp40", "m1911"])
	Economy._scrip[PID] = maxi(0, cost - 1)
	if cost <= 0:
		pass_test("storing is free in this data")
		return
	assert_eq(WeaponLocker.use(p), &"no_scrip")
	assert_eq(_ids(p), ["mp40", "m1911"])
	assert_false(WeaponLocker.has_stored(PID))


func test_never_two_of_a_kind() -> void:
	var p: Player = _player(PID, ["mp40", "m1911"])
	WeaponLocker.use(p)   # the MP40 in
	p.weapons.give_weapon(&"mp40")   # bought again off the wall (the M1911 in hand becomes... the slot is free: appended)
	assert_eq(_ids(p), ["m1911", "mp40"])
	p.weapons.current_index = 0   # the pistol in hand, a second MP40 on the back
	var pl: Dictionary = WeaponLocker.plan_for(p)
	assert_eq([pl["action"], pl["why"]], [&"none", "duplicate"])
	p.weapons.current_index = 1   # holding the copy: it swaps with the stored one
	assert_eq(WeaponLocker.plan_for(p)["action"], &"swap")
	assert_eq(WeaponLocker.use(p), &"swap")
	assert_eq(_ids(p), ["m1911", "mp40"], "still one MP40 on you")


func test_no_store_list_and_busy_hands() -> void:
	var p: Player = _player(PID, ["mp40", "m1911"])
	var c: Dictionary = WeaponLocker.cfg().duplicate(true)
	c["no_store"] = ["smg"]
	assert_eq(WeaponLocker.plan(p.weapons, [], 2, c)["why"], "refused", "a class the data refuses")
	c["no_store"] = ["mp40"]
	assert_eq(WeaponLocker.plan(p.weapons, [], 2, c)["why"], "refused", "an id the data refuses")
	p.weapons.carry_limited = true
	assert_eq(WeaponLocker.plan_for(p)["why"], "busy", "carrying the ballast: hands full")
	p.weapons.carry_limited = false
	p.weapons.holstered = true
	assert_eq(WeaponLocker.plan_for(p)["why"], "busy")


# ---------------------------------------------------------------- downed, bled out, back again

func test_the_stored_gun_survives_the_down_the_bleed_out_and_the_respawn() -> void:
	var p: Player = _player(PID, ["stg44_up", "m1911"])
	p.weapons.current().tier = 3
	WeaponLocker.use(p)
	p.weapons.enter_last_stand()
	assert_eq(WeaponLocker.plan_for(p)["action"], &"none", "crawling: the locker waits")
	p.downed = true
	assert_eq(WeaponLocker.use(p), &"none")
	p.weapons.clear_for_spectate()   # bled out: everything on them is gone
	assert_eq(_ids(p), [])
	assert_true(WeaponLocker.has_stored(PID), "the locker still has it")
	p.downed = false
	p.weapons.slots = [WeaponInstance.create(&"m1911")]   # the respawn's starting pistol (reset_loadout)
	p.weapons.current_index = 0
	assert_eq(WeaponLocker.use(p), &"take")
	assert_eq(p.weapons.current().id, &"stg44_up")
	assert_eq(p.weapons.current().tier, 3, "tier III came back")


# ---------------------------------------------------------------- co-op, bots

func test_each_player_has_their_own_compartment() -> void:
	var a: Player = _player(PID, ["mp40", "m1911"])
	var b: Player = _player(PID2, ["kar98k", "m1911"])
	WeaponLocker.use(a)
	assert_eq(WeaponLocker.plan_for(b)["action"], &"store", "b sees an empty compartment")
	WeaponLocker.use(b)
	assert_eq(WeaponLocker.instance_of(WeaponLocker.stored(PID)).id, &"mp40")
	assert_eq(WeaponLocker.instance_of(WeaponLocker.stored(PID2)).id, &"kar98k")
	WeaponLocker.use(a)
	assert_eq(_ids(a), ["m1911", "mp40"])
	assert_true(WeaponLocker.has_stored(PID2), "a's take left b's alone")


func test_the_contents_travel_in_the_state_snapshot() -> void:
	var a: Player = _player(PID, ["thompson", "m1911"])
	a.weapons.current().reserve = 17
	WeaponLocker.use(a)
	var wire: Variant = JSON.parse_string(JSON.stringify(WeaponLocker.to_net()))   # (string keys, floats: the worst a relay does)
	WeaponLocker.reset_match()
	WeaponLocker.from_net(wire as Dictionary)
	var w: WeaponInstance = WeaponLocker.instance_of(WeaponLocker.stored(PID))
	assert_eq(w.id, &"thompson")
	assert_eq(w.reserve, 17)
	WeaponLocker.from_net({})
	assert_false(WeaponLocker.has_stored(PID), "the host emptied it")


func test_bots_and_companions_never_use_it() -> void:
	var bot: Player = _player(PID, ["mp40", "m1911"])
	bot.is_bot = true
	assert_eq(WeaponLocker.plan_for(bot)["action"], &"none")
	assert_eq(WeaponLocker.use(bot), &"none")
	var l: WeaponLocker = WeaponLocker.new()
	add_child_autofree(l)
	assert_eq(l.get_prompt(bot), "", "no prompt for a bot")
	assert_false(l.can_interact(bot))
	assert_false(l.is_in_group(&"perk_machines") or l.is_in_group(&"ammo_boxes") or l.is_in_group(&"wall_buys"), "in none of the bots' errand groups")
	bot.is_bot = false
	bot.is_companion = true
	assert_eq(WeaponLocker.use(bot), &"none")


# ---------------------------------------------------------------- the match, the profile, the campaign

func test_per_match_never_in_the_profile_open_in_classic_rules() -> void:
	GLSettings.values["classic_rules"] = true
	var p: Player = _player(PID, ["mp40", "m1911"])
	var before: String = JSON.stringify(ProfileSave.profile)
	assert_eq(WeaponLocker.use(p), &"store", "Classic Rules: open (nothing persists)")
	assert_eq(JSON.stringify(ProfileSave.profile), before, "the profile is untouched")
	WeaponLocker.reset_match()
	assert_false(WeaponLocker.has_stored(PID), "a new match starts empty")


func test_a_campaign_hop_carries_the_contents() -> void:
	var p: Player = _player(PID, ["bar_up", "m1911"])
	WeaponLocker.use(p)
	var carried: Dictionary = WeaponLocker.carry_snapshot()
	WeaponLocker.reset_match()
	WeaponLocker.restore_carry(carried)
	assert_eq(WeaponLocker.instance_of(WeaponLocker.stored(PID)).id, &"bar_up")
	WeaponLocker.restore_carry(null)
	assert_false(WeaponLocker.has_stored(PID), "a payload from before the locker: empty")


func test_a_stale_weapon_id_is_dropped_not_crashed_on() -> void:
	WeaponLocker._put(PID, ["no_such_gun", 1, 2, "semi", false, 0, 0, [], ""])
	var p: Player = _player(PID, ["mp40", "m1911"])
	assert_null(WeaponLocker.instance_of(WeaponLocker.stored(PID)))
	assert_eq(WeaponLocker.plan_for(p)["action"], &"store", "the compartment counts as empty")


# ---------------------------------------------------------------- the node: prompts, the card

func test_prompts_follow_what_you_carry() -> void:
	var l: WeaponLocker = WeaponLocker.new()
	add_child_autofree(l)
	var p: Player = _player(PID, ["mp40", "m1911"])
	var store: String = l.get_prompt(p)
	assert_string_contains(store, "lock away MP40")
	if cost > 0:
		assert_string_contains(store, "[%d]" % cost)
	assert_true(l.can_interact(p))
	assert_eq(l.use_by(p), &"store")
	assert_string_contains(l.get_prompt(p), "take MP40")
	p.weapons.give_weapon(&"kar98k")
	assert_string_contains(l.get_prompt(p), "lock away Kar98k and take MP40")
	var one: Player = _player(PID2, ["m1911"])
	assert_string_contains(l.get_prompt(one), "keep one gun")
	assert_false(l.can_interact(one))
	assert_true(l.is_in_group(&"weapon_lockers"))
	assert_not_null(l.get_node_or_null("Body"), "a collider: players walk round it")
	assert_not_null(l.get_node_or_null("Art"), "the locker's mesh")


func test_the_card_shows_the_local_players_gun() -> void:
	var l: WeaponLocker = WeaponLocker.new()
	add_child_autofree(l)
	var me: int = Net.local_player_id()
	assert_eq(l._card.text, str(WeaponLocker.cfg()["text"]["card_empty"]))
	WeaponLocker._put(me, WeaponHolder.net_entry(WeaponInstance.create(&"kar98k")))
	l._refresh_card()
	assert_eq(l._card.text, "KAR98K")
	WeaponLocker._put(me, [])
	l._refresh_card()
	assert_eq(l._card.text, str(WeaponLocker.cfg()["text"]["card_empty"]))


# ---------------------------------------------------------------- data and the spot

func test_data_rows() -> void:
	var c: Dictionary = WeaponLocker.cfg()
	assert_gte(int(c["store_cost"]), 0)
	assert_gte(int(c["withdraw_cost"]), 0)
	assert_gte(int(c["keep_on_you"]), 1, "never the last gun")
	for k: String in ["open", "store", "take"]:
		var snd: String = str((c["sounds"] as Dictionary)[k])
		assert_true(_audio_has(snd), "sound %s exists" % snd)
	assert_false(WeaponLocker.row_for("map00_crossroads").is_empty(), "Map 0 has a locker")
	assert_true(WeaponLocker.row_for("no_such_map").is_empty())
	for key: Variant in (c["lockers"] as Dictionary).keys():
		var row: Dictionary = c["lockers"][key]
		assert_eq((row["at"] as Array).size(), 3, "%s: at" % key)
		assert_true(row.has("yaw") and str(row.get("where", "")) != "", "%s: yaw and a note" % key)
	# the doors face `yaw` (0 = +z): the node's -Z
	var xf: Transform3D = WeaponLocker.row_transform({"at": [1, 2, 3], "yaw": 90.0})
	assert_almost_eq(-xf.basis.z, Vector3(1, 0, 0), Vector3.ONE * 0.001)
	assert_eq(xf.origin, Vector3(1, 2, 3))


func _audio_has(key: String) -> bool:
	return FileAccess.get_file_as_string("res://data/gravelight/audio.json").contains("\"%s\"" % key)


func test_map0_spot_is_free_wall_off_the_navmesh_with_room_in_front() -> void:
	var map: Node = (load(MAP0) as PackedScene).instantiate()
	var geo: Dictionary = Spot.index(map)
	var row: Dictionary = WeaponLocker.row_for("map00_crossroads")
	var at: Array = row["at"]
	var r: Dictionary = Spot.check(geo, Vector3(float(at[0]), float(at[1]), float(at[2])), float(row["yaw"]))
	# and a spot that is wrong is caught: the same wall inside the bale stack beside it
	var bad: Dictionary = Spot.check(geo, Vector3(22.5, 0.0, 22.15), 0.0)
	map.free()
	assert_eq(Array(r["problems"]), [], Spot.line(r))
	assert_eq(int(r["wall"]), 9, "the wall behind the whole back")
	assert_lt(float(r["nav_under"]), 0.12, "no navmesh under it: nothing to rebake")
	assert_gte(float(r["room"]), Spot.ROOM_MIN, "room in front")
	assert_gte(float(r["nearest"]), Spot.NEAR_MACHINE, "no machine crowds it")
	assert_gt((bad["problems"] as PackedStringArray).size(), 0, "the bale stack is in the way there")
