extends GutTest
## M1911 attachments and the Armorer's Bench (UPDATE_04 section 6, DECISIONS T-068): pricing, slot exclusivity,
## the power gate, carry-over through the Crucible, transfer with the weapon (wall-buy, Jakub), campaign carry,
## stats applied, the suppressor flag, the Loadout Pick and finishes, and the bench API.

var _free: Array = []


func after_each() -> void:
	for n: Variant in _free:
		if is_instance_valid(n):
			(n as Node).free()
	_free.clear()
	GameState.power_on = false


func _player(pid: int = 1) -> Player:
	var p: Player = Player.new()
	p.player_id = pid
	var h: WeaponHolder = WeaponHolder.new()
	h.mirror = true
	h.player = p
	p.weapons = h
	h.call("_set_start_loadout")
	_free.append(h)
	_free.append(p)
	return p


func _pistol(build: String = "m1911") -> WeaponInstance:
	return M1911Kit.from_build(build)


# ---------------------------------------------------------------- data and pricing

func test_prices_match_the_work_order() -> void:
	var want: Dictionary = {"mag/extended": 750, "mag/drum": 1500, "barrel/match": 1000, "barrel/compensator": 1000,
		"barrel/suppressor": 1000, "sights/radium": 600, "sights/raised_target": 600, "grip/stock": 900, "grip/checkered": 500,
		"ammo/hollow_points": 1200, "ammo/nachtglas": 2000}
	for k: String in want.keys():
		var p: PackedStringArray = k.split("/")
		assert_eq(M1911Kit.price(p[0], p[1]), int(want[k]), k)
	assert_eq(M1911Kit.slot_order(), ["mag", "barrel", "sights", "grip", "ammo"])


func test_every_option_has_an_upgraded_version_with_its_own_name() -> void:
	var n: int = 0
	for slot: String in M1911Kit.slot_order():
		for opt: Variant in M1911Kit.options(slot):
			var d: Dictionary = M1911Kit.option_def(slot, str(opt))
			assert_true(d.has("upgraded"), "%s/%s has an upgraded block" % [slot, opt])
			assert_ne(M1911Kit.option_name(slot, str(opt), true), M1911Kit.option_name(slot, str(opt), false))
			n += 1
	assert_eq(n, 11, "eleven options, eleven upgraded versions")
	assert_eq(M1911Kit.option_name("mag", "drum", true), "Rosary Drum")


func test_applies_to_the_m1911_and_last_rites_only() -> void:
	assert_true(M1911Kit.applies_to(WeaponInstance.create(&"m1911")))
	assert_true(M1911Kit.applies_to(WeaponInstance.create(&"m1911_up")))
	assert_eq(str(WeaponInstance.create(&"m1911_up").data.get("name")), "Last Rites")
	assert_false(M1911Kit.applies_to(WeaponInstance.create(&"kar98k")))
	assert_eq(M1911Kit.check(WeaponInstance.create(&"mp40"), "mag", "drum", true), "wrong_weapon")


# ---------------------------------------------------------------- rules

func test_one_choice_per_slot() -> void:
	var w: WeaponInstance = _pistol()
	M1911Kit.install(w, "mag", "extended")
	assert_eq(w.mag_size(), 12)
	assert_eq(M1911Kit.check(w, "mag", "extended", true), "installed")
	assert_eq(M1911Kit.check(w, "mag", "drum", true), "", "another option in the slot replaces it")
	M1911Kit.install(w, "mag", "drum")
	assert_eq(w.kit.get("mag"), "drum")
	assert_eq(w.kit.size(), 1)
	assert_eq(w.mag_size(), 30)
	assert_eq(w.mag, 30, "the bigger magazine is topped up from the reserve")
	M1911Kit.install(w, "mag", "extended")
	assert_eq(w.mag, 12, "a smaller one hands rounds back")
	assert_true(w.reserve <= w.reserve_max())


func test_nachtglas_rounds_wait_for_the_power() -> void:
	var w: WeaponInstance = _pistol()
	assert_eq(M1911Kit.check(w, "ammo", "nachtglas", false), "needs_power")
	assert_eq(M1911Kit.check(w, "ammo", "nachtglas", true), "")
	assert_eq(M1911Kit.check(w, "ammo", "hollow_points", false), "", "only the Nachtglas rounds are under the counter")


func test_jakub_refuses_the_nachtglas_rounds() -> void:
	var w: WeaponInstance = _pistol()
	assert_eq(M1911Kit.check(w, "ammo", "nachtglas", true, true), "refused")
	assert_eq(M1911Kit.check(w, "ammo", "hollow_points", true, true), "")
	assert_true(M1911Kit.companion_accepts(w))
	M1911Kit.install(w, "ammo", "nachtglas")
	assert_false(M1911Kit.companion_accepts(w), "he won't take a pistol loaded with them")


# ---------------------------------------------------------------- stats

func test_stats_apply() -> void:
	var base: WeaponInstance = _pistol()
	assert_almost_eq(_pistol("m1911:barrel=match").f("damage"), base.f("damage") * 1.15, 0.01)
	assert_almost_eq(_pistol("m1911:barrel=match").f("falloff_end"), base.f("falloff_end") * 1.5, 0.01)
	assert_almost_eq(_pistol("m1911:ammo=nachtglas").f("damage"), base.f("damage") * 1.2, 0.01)
	assert_almost_eq(_pistol("m1911:barrel=match,ammo=nachtglas").f("damage"), base.f("damage") * 1.15 * 1.2, 0.01, "multipliers stack")
	assert_almost_eq(_pistol("m1911:sights=radium").f("ads_time"), base.f("ads_time") * 0.75, 0.001)
	assert_almost_eq(_pistol("m1911:mag=drum").f("ads_time"), base.f("ads_time") * 1.35, 0.001)
	assert_almost_eq(_pistol("m1911:mag=drum").f("reload_empty"), base.f("reload_empty") * 1.45, 0.001)
	assert_almost_eq(_pistol("m1911:sights=raised_target").f("spread_ads"), base.f("spread_ads") * 0.5, 0.001)
	assert_almost_eq(_pistol("m1911:grip=stock").f("sway"), base.f("sway") * 0.4, 0.001, "ADS sway -60%")
	assert_almost_eq(_pistol("m1911:grip=checkered").f("spread_hip"), base.f("spread_hip") * 0.7, 0.001)
	assert_gt(_pistol("m1911:grip=stock").draw_mult(), 1.0, "slower draw")
	assert_lt(_pistol("m1911:grip=checkered").draw_mult(), 1.0, "faster draw")
	assert_almost_eq(_pistol("m1911:ammo=hollow_points").limb_mult(&"head"), base.limb_mult(&"head") * 1.35, 0.001)
	assert_eq(_pistol("m1911:mag=extended").mag_size(), 12)
	var rc0: Dictionary = WeaponHolder.recoil_for(base)
	var rc: Dictionary = WeaponHolder.recoil_for(_pistol("m1911:barrel=compensator"))
	assert_almost_eq(float(rc["v"]), float(rc0["v"]) * 0.6, 0.001, "compensator: -40% recoil")
	assert_gt(_pistol("m1911:barrel=compensator").f("rpm"), base.f("rpm"), "faster follow-up")


func test_suppressor_is_quiet_and_costs_ten_percent() -> void:
	var s: WeaponInstance = _pistol("m1911:barrel=suppressor")
	assert_true(s.is_suppressed())
	assert_false(_pistol().is_suppressed())
	assert_false(_pistol("m1911:barrel=compensator").is_suppressed())
	assert_almost_eq(s.f("damage"), _pistol().f("damage") * 0.9, 0.01)
	GLBus.mark_shot(3, true)
	assert_true(GLBus.shot_is_suppressed(3))
	GLBus.mark_shot(3, false)
	assert_false(GLBus.shot_is_suppressed(3))


func test_bench_stat_bars_preview_the_change() -> void:
	var w: WeaponInstance = _pistol()
	var now: Dictionary = M1911Kit.stats(w)
	var drum: Dictionary = M1911Kit.stats(w, "mag", "drum")
	for k: String in ["damage", "range", "recoil", "ads", "mobility", "capacity"]:
		assert_true(now.has(k) and drum.has(k), k)
	assert_gt(float(drum["capacity"]["value"]), float(now["capacity"]["value"]))
	assert_lt(float(drum["ads"]["value"]), float(now["ads"]["value"]), "the drum aims slower")
	assert_lt(float(M1911Kit.stats(w, "barrel", "compensator")["recoil"]["value"]), float(now["recoil"]["value"]))
	assert_true(w.kit.is_empty(), "a preview never touches the pistol")


# ---------------------------------------------------------------- carry-over

func test_crucible_keeps_the_attachments_and_upgrades_them() -> void:
	var p: Player = _player()
	var w: WeaponInstance = p.weapons.current()
	M1911Kit.install(w, "mag", "drum")
	M1911Kit.install(w, "barrel", "compensator")
	w.finish = &"nickel"
	# what Crucible.interact / _take do: feed the gun in (its kit rides with the forge), hand Last Rites back
	var kit: Array = M1911Kit.encode(w.kit)
	var fin: String = String(w.finish)
	p.weapons.remove_current()
	var up: StringName = &"m1911_up"
	p.weapons.give_weapon(up)
	p.weapons.set_kit(up, kit, fin)
	var lr: WeaponInstance = p.weapons.find_weapon(up)
	assert_not_null(lr)
	assert_eq(lr.kit, {"mag": "drum", "barrel": "compensator"})
	assert_eq(lr.finish, &"nickel")
	assert_eq(lr.mag_size(), 40, "the Drum becomes the Rosary Drum, 40 rounds")
	assert_eq(lr.mag, 40, "upgrading refills")
	assert_eq(M1911Kit.option_name("barrel", "compensator", lr.upgraded), "Censer Compensator")
	assert_true(lr.has_property("kit_flare"), "the Censer's flare ignites zombies")
	assert_true(lr.has_property("ricochet"), "Last Rites keeps its own property")
	# the Crucible's re-teaching (tier II) scales the upgraded drum
	lr.tier = 2
	assert_gt(lr.mag_size(), 40)


func test_crucible_forge_carries_the_kit() -> void:
	var c: Crucible = Crucible.new()
	_free.append(c)
	assert_true(c.has_method("_forge"))
	c.set("_result_kit", ["mag:drum"])
	c.call("_reset")
	assert_eq(c.get("_result_kit"), [], "a lost or taken weapon clears the stored kit")


func test_wall_buy_swap_takes_the_attachments_with_the_pistol() -> void:
	var p: Player = _player()
	M1911Kit.install(p.weapons.current(), "sights", "radium")
	p.weapons.give_weapon(&"kar98k")      # second slot
	p.weapons.current_index = 0
	p.weapons.give_weapon(&"mp40")        # full: replaces the pistol in hand
	assert_null(p.weapons.find_weapon(&"m1911"), "the pistol is gone")
	for w: WeaponInstance in p.weapons.slots:
		assert_true(w.kit.is_empty(), "%s got no attachments" % w.id)


func test_handing_the_pistol_over_moves_its_attachments() -> void:
	var a: Player = _player(1)
	var b: Player = _player(9)   # Jakub's pid
	M1911Kit.install(a.weapons.current(), "grip", "stock")
	a.weapons.give_weapon(&"kar98k")
	a.weapons.current_index = 0
	var w: WeaponInstance = a.weapons.remove_current()   # JakubCompanion._take_gun
	b.weapons.slots.clear()
	b.weapons.give_instance(w)                            # ... _receive, and give_instance for the hand-back
	assert_eq(b.weapons.current().kit.get("grip"), "stock")
	assert_null(M1911Kit.pistol_of(a), "the giver keeps nothing")
	var back: WeaponInstance = b.weapons.remove_current()
	a.weapons.give_instance(back)                         # "Take mine, then."
	assert_eq(M1911Kit.pistol_of(a).kit.get("grip"), "stock")


func test_campaign_and_coop_carry_the_kit() -> void:
	var a: Player = _player()
	var w: WeaponInstance = a.weapons.current()
	M1911Kit.install(w, "mag", "extended")
	M1911Kit.install(w, "ammo", "hollow_points")
	w.finish = &"blued"
	w.mag = 7
	w.reserve = 50
	var d: Dictionary = a.weapons.to_net()
	var b: Player = _player(2)
	b.weapons.apply_carry(d)
	var got: WeaponInstance = b.weapons.current()
	assert_eq(got.kit, {"mag": "extended", "ammo": "hollow_points"})
	assert_eq(got.finish, &"blued")
	assert_eq(got.mag, 7)
	assert_eq(got.reserve, 50)
	assert_eq(got.mag_size(), 12)
	assert_ne(a.weapons.net_signature()[0], _player(3).weapons.net_signature()[0], "a fitted part is a structure change for co-op")
	# a downed player's stash leaves with the kit too
	a.weapons.enter_last_stand()
	var stash: Dictionary = Campaign.stash_to_net(a.weapons)
	assert_eq(M1911Kit.decode((stash["s"][0] as Array)[7]), {"mag": "extended", "ammo": "hollow_points"})


# ---------------------------------------------------------------- the bench API

func test_bench_buy_spends_and_fits() -> void:
	var p: Player = _player()
	var ids: Array[int] = [1]
	Economy.reset(ids)
	Economy.grant(1, 1500 - Economy.get_scrip(1) + 500)   # 2000 in all
	var r: Dictionary = ArmorersBench.buy(p, "mag", "drum")
	assert_true(bool(r["ok"]), str(r))
	assert_eq(int(r["price"]), 1500)
	assert_eq(Economy.get_scrip(1), 500)
	assert_eq(p.weapons.current().kit.get("mag"), "drum")
	var r2: Dictionary = ArmorersBench.buy(p, "barrel", "suppressor")
	assert_false(bool(r2["ok"]))
	assert_eq(r2["reason"], "no_scrip")
	assert_eq(ArmorersBench.buy(p, "mag", "drum")["reason"], "installed")
	assert_eq(ArmorersBench.buy(p, "ammo", "nachtglas")["reason"], "needs_power")
	var rows: Array = ArmorersBench.options_for(p)
	assert_eq(rows.size(), 11)
	var drum_row: Dictionary = rows.filter(func(x: Dictionary) -> bool: return x["option"] == "drum")[0]
	assert_true(bool(drum_row["installed"]))
	var none: Player = _player(4)
	none.weapons.slots = [WeaponInstance.create(&"kar98k")]
	assert_eq(ArmorersBench.buy(none, "mag", "drum")["reason"], "no_pistol")


func test_loadout_rows_list_the_pistol() -> void:
	var p: Player = _player()
	M1911Kit.install(p.weapons.current(), "sights", "raised_target")
	var rows: Array = M1911Kit.loadout_rows(p)
	assert_eq(rows.size(), 5)
	assert_eq(rows[2]["name"], "Raised Target Sight")
	assert_eq(rows[0]["name"], "Standard")


# ---------------------------------------------------------------- meta

func test_loadout_pick_is_extended_mag_or_checkered_grips_only() -> void:
	assert_eq(M1911Kit.pick_choices(), ["mag:extended", "grip:checkered"])
	var w: WeaponInstance = _pistol()
	M1911Kit.apply_start(w, "mag:extended", &"nickel")
	assert_eq(w.kit, {"mag": "extended"})
	assert_eq(w.mag, 12)
	assert_eq(w.reserve, w.reserve_max())
	assert_eq(w.finish, &"nickel")
	var w2: WeaponInstance = _pistol()
	M1911Kit.apply_start(w2, "barrel:compensator", &"")
	assert_true(w2.kit.is_empty(), "nothing else can be a Loadout Pick")
	assert_false(M1911Kit.pick_unlocked(0))
	assert_true(M1911Kit.pick_unlocked(M1911Kit.pick_kills()))


func test_finishes_unlock_with_m1911_kills() -> void:
	var rows: Array = M1911Kit.finish_rows(0)
	var ids: Array = rows.map(func(r: Dictionary) -> String: return str(r["id"]))
	for f: String in ["blued", "battle_worn", "nickel", "engraved", "nachtglas_inlay"]:
		assert_true(ids.has(f), f)
	assert_true(M1911Kit.finish_unlocked(&"", 0))
	assert_false(M1911Kit.finish_unlocked(&"nickel", 0))
	var top: int = 0
	for r: Dictionary in rows:
		top = maxi(top, int(r["kills"]))
	for r2: Dictionary in M1911Kit.finish_rows(top):
		assert_true(bool(r2["unlocked"]), str(r2["id"]))


func test_models_build_for_every_option() -> void:
	for slot: String in M1911Kit.slot_order():
		for opt: Variant in M1911Kit.options(slot):
			for up: bool in [false, true]:
				var w: WeaponInstance = _pistol(("m1911_up" if up else "m1911") + ":%s=%s" % [slot, opt])
				var m: Node3D = WeaponModels.build(w.base_id(), w.upgraded, &"", M1911KitModels.look_of(w))
				assert_not_null(m.get_node_or_null("Muzzle"))
				assert_not_null(m.find_child("SightPoint", true, false), "%s/%s keeps its sights" % [slot, opt])
				m.free()
	var comp: WeaponInstance = _pistol("m1911:barrel=suppressor")
	var mc: Node3D = WeaponModels.build(comp.base_id(), false, &"", M1911KitModels.look_of(comp))
	assert_lt((mc.get_node("Muzzle") as Node3D).position.z, -0.3, "the can moves the muzzle")
	mc.free()
