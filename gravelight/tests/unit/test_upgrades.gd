extends GutTest
## Crucible upgrades (WEAPONS.md §5, §11).


func test_every_upgradable_base_has_an_upgraded_row() -> void:
	var t: Dictionary = GLData.table("weapons")
	for id: String in t["weapons"].keys():
		var up: String = str(t["weapons"][id].get("upgraded", ""))
		if up == "":
			continue
		assert_true(t["upgraded"].has(up), "%s -> %s missing" % [id, up])
		assert_eq(str(t["upgraded"][up]["base"]), id)


func test_upgraded_rows_have_properties() -> void:
	var up: Dictionary = GLData.table("weapons")["upgraded"]
	for id: String in up.keys():
		assert_true(up[id].has("properties"), id)
		assert_ne(str(up[id]["name"]), str(GLData.table("weapons")["weapons"][str(up[id]["base"])]["name"]), id + " renamed")


func test_crucible_actions_and_prices() -> void:
	var econ: Dictionary = GLData.table("economy")
	assert_eq(Crucible.action_for(null), &"none")
	var m1911: WeaponInstance = WeaponInstance.create(&"m1911")
	assert_eq(Crucible.action_for(m1911), &"upgrade")
	assert_eq(Crucible.price_for(&"upgrade", econ), 5000)
	assert_eq(m1911.upgrade_id(), &"m1911_up")
	var lr: WeaponInstance = WeaponInstance.create(&"m1911_up")
	assert_true(lr.upgraded)
	assert_eq(lr.display_name(), "Last Rites")
	assert_eq(Crucible.action_for(lr), &"upgrade", "a full taught weapon can be re-taught (tier 2)")
	assert_eq(Crucible.price_for(&"upgrade", econ, lr.tier), 7500)
	lr.mag = 0
	assert_eq(Crucible.action_for(lr), &"upgrade", "an unfilled taught weapon is still offered the next teaching (T-083: the Crucible sells no ammo)")
	assert_eq(Crucible.price_for(&"ammo", econ), 0, "no ammo price at the Crucible")
	assert_eq(lr.upgrade_id(), &"m1911_up", "re-teaching keeps the id; the tier climbs")
	lr.tier = WeaponInstance.max_tier()
	lr.refill()   # the top tier holds more, so fill it at its own size
	assert_eq(Crucible.action_for(lr), &"full", "the top tier is the end of it")
	assert_eq(lr.upgrade_id(), &"", "top-tier weapons can't be taught again")


func test_crucible_never_offers_ammo() -> void:
	# T-083: whatever the gun and however empty, the Crucible's answer is a teaching, "nothing" or "full".
	var t: Dictionary = GLData.table("weapons")
	for id: String in (t["weapons"] as Dictionary).keys() + (t["upgraded"] as Dictionary).keys():
		var w: WeaponInstance = WeaponInstance.create(StringName(id))
		for tier: int in range(0 if not w.upgraded else 1, WeaponInstance.max_tier() + 1):
			if w.upgraded:
				w.tier = tier
			w.mag = 0
			w.reserve = 0
			var a: StringName = Crucible.action_for(w)
			assert_ne(a, &"ammo", "%s tier %d" % [id, tier])
			assert_true([&"upgrade", &"nothing", &"full"].has(a), "%s tier %d: %s" % [id, tier, a])
			if not w.upgraded:
				break
	assert_false(GLData.table("economy").has("crucible_upgraded_ammo"), "the price left economy.json")


func test_ammo_box_refills_a_taught_weapon() -> void:
	# T-083: the boxes are where a taught gun's ammo comes from (mag and reserve, at the box's upgraded price).
	var holder: WeaponHolder = WeaponHolder.new()
	add_child_autofree(holder)
	var box: AmmoBox = AmmoBox.new()
	add_child_autofree(box)
	var w: WeaponInstance = WeaponInstance.create(&"thompson_up")
	w.tier = 2
	w.mag = 0
	w.reserve = 0
	holder.slots = [w]
	holder.current_index = 0
	holder.grenades = holder.grenade_max()
	var pid: int = 77
	Economy.reset([pid])
	Economy.grant(pid, 5000)
	var price: int = int(AmmoBox.quote(holder, AmmoBox.cfg())["price"])
	assert_eq(price, int(AmmoBox.cfg()["upgraded"]), "the Crucible-upgraded box price, whatever the tier")
	assert_eq(box.use_holder(holder, pid, pid), &"ok")
	assert_eq(w.mag, w.mag_size(), "magazine full (tier II size)")
	assert_eq(w.reserve, w.reserve_max(), "reserve full")
	assert_eq(Economy.get_scrip(pid), 5500 - price)


func test_crucible_tiers_scale_the_taught_row() -> void:
	assert_eq(WeaponInstance.max_tier(), 3, "double and triple teaching")
	var econ: Dictionary = GLData.table("economy")
	assert_eq(Crucible.price_for(&"upgrade", econ, 0), 5000)
	assert_eq(Crucible.price_for(&"upgrade", econ, 1), 7500)
	assert_eq(Crucible.price_for(&"upgrade", econ, 2), 10000)
	var lr: WeaponInstance = WeaponInstance.create(&"m1911_up")
	var d1: float = lr.f("damage")
	var m1: int = lr.mag_size()
	lr.tier = 2
	assert_eq(lr.display_name(), "Last Rites II")
	assert_almost_eq(lr.f("damage"), d1 * 1.5, 0.01)
	assert_eq(lr.mag_size(), ceili(m1 * 1.25))
	assert_almost_eq(lr.f("reload_partial"), 1.2 * 0.9, 0.001)
	lr.tier = 3
	assert_eq(lr.display_name(), "Last Rites III")
	assert_almost_eq(lr.f("damage"), d1 * 2.0, 0.01)
	assert_eq(lr.reserve_max(), ceili(120 * 1.5))
	var base: WeaponInstance = WeaponInstance.create(&"m1911")
	assert_eq(base.tier, 0)
	assert_eq(base.display_name(), "M1911", "base weapons carry no suffix")


func test_third_wonder_weapon_rows() -> void:
	var t: Dictionary = GLData.table("weapons")
	assert_true(t["weapons"].has("elmsfeuer") and t["upgraded"].has("elmsfeuer_up"))
	var w: WeaponInstance = WeaponInstance.create(&"elmsfeuer")
	assert_eq(w.weapon_class(), &"wonder")
	assert_eq(int(w.property("chain", 0)), 3, "the bolt chains")
	assert_true(w.data.has("projectile"))
	assert_eq(w.upgrade_id(), &"elmsfeuer_up")
	assert_true(CrateManager.is_wonder(&"elmsfeuer") and CrateManager.is_wonder(&"ashlight") and not CrateManager.is_wonder(&"mp40"))
	var in_pool: bool = false
	for e: Dictionary in GLData.table("crate")["pool"]:
		if str(e["id"]) == "elmsfeuer":
			in_pool = true
	assert_true(in_pool, "Sankt-Elmsfeuer is in the crate pool")
	assert_true(WeaponModels.known_ids().has("elmsfeuer"), "it has a model")


func test_fire_mode_toggle() -> void:
	var stg: WeaponInstance = WeaponInstance.create(&"stg44_up")
	assert_eq(stg.fire_mode, "auto")
	assert_eq(stg.toggle_alt(), &"mode")
	assert_eq(stg.fire_mode, "burst3")
	stg.toggle_alt()
	assert_eq(stg.fire_mode, "auto")
	var carbine: WeaponInstance = WeaponInstance.create(&"m1_carbine_up")
	assert_eq(carbine.fire_modes(), ["semi", "auto"])
	var garand: WeaponInstance = WeaponInstance.create(&"m1_garand_up")
	assert_eq(garand.toggle_alt(), &"underbarrel")
	assert_true(garand.underbarrel_active)
	assert_eq(garand.underbarrel_ammo, 6)
	var base: WeaponInstance = WeaponInstance.create(&"mp40")
	assert_eq(base.toggle_alt(), &"", "base weapons have no alt-fire")


func test_m1919_overheats_but_long_amen_does_not() -> void:
	var m: WeaponInstance = WeaponInstance.create(&"m1919")
	assert_true(m.can_overheat())
	for i: int in 79:
		m.tick_heat(0.1, true)
	assert_true(m.can_fire_heat(), "7.9 s is still fine")
	m.tick_heat(0.2, true)
	assert_false(m.can_fire_heat(), "8 s of fire locks it out")
	for i: int in 29:
		m.tick_heat(0.1, false)
	assert_false(m.can_fire_heat())
	m.tick_heat(0.2, false)
	assert_true(m.can_fire_heat(), "3 s cool-down")
	var amen: WeaponInstance = WeaponInstance.create(&"m1919_up")
	assert_false(amen.can_overheat())
	for i: int in 200:
		amen.tick_heat(0.1, true)
	assert_true(amen.can_fire_heat())


func test_head_mult_and_hollow_point() -> void:
	assert_almost_eq(WeaponInstance.create(&"gewehr43_up").limb_mult(&"head"), 8.0, 0.001)
	var hb: WeaponInstance = WeaponInstance.create(&"type100_up")
	assert_almost_eq(hb.limb_mult(&"legs"), 1.5, 0.001)
	assert_almost_eq(hb.limb_mult(&"torso"), 1.0, 0.001)


func test_frost_does_not_stack() -> void:
	var z: Zombie = Zombie.new()
	z.apply_frost(0.3, 2.0)
	z.apply_frost(0.3, 2.0)
	assert_almost_eq(z.frost_speed_mult(), 0.7, 0.001)
	z.free()
