extends GutTest
## Ammo boxes (Update 02 section 4, DECISIONS T-049): prices by what you hold, the per-player cooldown, no charge
## when full, and lethal grenades refilled but never tacticals.

const PID: int = 41

var cfg: Dictionary
var holder: WeaponHolder
var box: AmmoBox


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/economy.json")["ammo_box"]


func before_each() -> void:
	holder = WeaponHolder.new()
	add_child_autofree(holder)
	box = AmmoBox.new()
	add_child_autofree(box)
	Economy.reset([PID])
	Economy.grant(PID, 20000)


func _hold(weapon_id: StringName) -> WeaponInstance:
	var w: WeaponInstance = WeaponInstance.create(weapon_id)
	holder.slots = [w]
	holder.current_index = 0
	holder.grenades = holder.grenade_max()
	holder.tactical_id = &""
	holder.tactical_count = 0
	return w


func test_price_table() -> void:
	var t: Dictionary = GLData.table("weapons")
	assert_eq(AmmoBox.price_for(t["weapons"]["mp40"], false, cfg), 250, "normal")
	assert_eq(AmmoBox.price_for(t["upgraded"]["mp40_up"], true, cfg), 2500, "Crucible-upgraded")
	assert_eq(AmmoBox.price_for(t["weapons"]["ashlight"], false, cfg), 1000, "wonder weapon")
	assert_eq(AmmoBox.price_for(t["upgraded"]["totenglocke_up"], true, cfg), 4000, "upgraded wonder weapon")


func test_quote_follows_the_weapon_in_hand() -> void:
	var w: WeaponInstance = _hold(&"thompson")
	w.reserve = 0
	assert_eq(int(AmmoBox.quote(holder, cfg)["price"]), 250)
	w = _hold(&"thompson_up")
	w.mag = 0
	assert_eq(int(AmmoBox.quote(holder, cfg)["price"]), 2500)
	w = _hold(&"elmsfeuer")
	w.reserve = 1
	assert_eq(int(AmmoBox.quote(holder, cfg)["price"]), 1000)
	w = _hold(&"ashlight_up")
	w.reserve = 1
	assert_eq(int(AmmoBox.quote(holder, cfg)["price"]), 4000)
	assert_eq(int(AmmoBox.quote(holder, cfg, 0.5)["price"]), 2000, "companion half price")


func test_buy_refills_and_charges() -> void:
	var w: WeaponInstance = _hold(&"kar98k")
	w.mag = 1
	w.reserve = 3
	var before: int = Economy.get_scrip(PID)
	assert_eq(box.use_holder(holder, PID, PID), &"ok")
	assert_eq(w.mag, w.mag_size())
	assert_eq(w.reserve, w.reserve_max())
	assert_eq(Economy.get_scrip(PID), before - 250)


func test_upgraded_and_wonder_buys_charge_their_price() -> void:
	var w: WeaponInstance = _hold(&"mp40_up")
	w.reserve = 0
	var before: int = Economy.get_scrip(PID)
	assert_eq(box.use_holder(holder, PID, PID), &"ok")
	assert_eq(Economy.get_scrip(PID), before - 2500)
	box._used_at.clear()
	w = _hold(&"totenglocke")
	w.reserve = 0
	before = Economy.get_scrip(PID)
	assert_eq(box.use_holder(holder, PID, PID), &"ok")
	assert_eq(w.reserve, w.reserve_max())
	assert_eq(Economy.get_scrip(PID), before - 1000)


func test_full_ammo_costs_nothing() -> void:
	_hold(&"m1_garand")
	var before: int = Economy.get_scrip(PID)
	assert_eq(box.use_holder(holder, PID, PID), &"full")
	assert_eq(Economy.get_scrip(PID), before)


func test_cooldown_per_player() -> void:
	var w: WeaponInstance = _hold(&"mp40")
	w.reserve = 0
	assert_eq(box.use_holder(holder, PID, PID), &"ok")
	w.reserve = 0
	var before: int = Economy.get_scrip(PID)
	assert_eq(box.use_holder(holder, PID, PID), &"cooldown")
	assert_eq(Economy.get_scrip(PID), before, "no charge during the cooldown")
	assert_gt(box.cooldown_left(PID), 2.5)
	assert_eq(box.cooldown_left(PID + 1), 0.0, "another player is not on cooldown")
	box._used_at[PID] = box._now() - float(cfg["cooldown_s"]) - 0.1
	assert_eq(box.use_holder(holder, PID, PID), &"ok")


func test_not_enough_scrip() -> void:
	var w: WeaponInstance = _hold(&"thompson_up")
	w.reserve = 0
	Economy.reset([PID])   # 500 < 2500
	assert_eq(box.use_holder(holder, PID, PID), &"no_scrip")
	assert_eq(w.reserve, 0)
	assert_eq(Economy.get_scrip(PID), 500)


func test_grenades_refilled_tacticals_not() -> void:
	var w: WeaponInstance = _hold(&"mp40")
	w.reserve = 0
	holder.grenades = 0
	holder.tactical_id = &"gramophone"
	holder.tactical_count = 0
	assert_eq(box.use_holder(holder, PID, PID), &"ok")
	assert_eq(holder.grenades, holder.grenade_max(), "lethal grenades refilled")
	assert_eq(holder.tactical_count, 0, "tacticals untouched")


func test_grenades_only_when_the_gun_is_full() -> void:
	_hold(&"mp40")
	holder.grenades = 1
	var q: Dictionary = AmmoBox.quote(holder, cfg)
	assert_false(bool(q["refill_weapon"]))
	assert_true(bool(q["refill_grenades"]))
	assert_eq(int(q["price"]), int(cfg["grenades_only"]))
	var before: int = Economy.get_scrip(PID)
	assert_eq(box.use_holder(holder, PID, PID), &"ok")
	assert_eq(holder.grenades, holder.grenade_max())
	assert_eq(Economy.get_scrip(PID), before - int(cfg["grenades_only"]))


func test_payer_can_differ_from_user() -> void:
	var w: WeaponInstance = _hold(&"kar98k")
	w.reserve = 0
	Economy.reset([PID, PID + 1])
	assert_eq(box.use_holder(holder, PID + 1, PID, 0.5), &"ok")
	assert_eq(Economy.get_scrip(PID), 500 - 125, "the payer pays half")
	assert_eq(Economy.get_scrip(PID + 1), 500)
	assert_gt(box.cooldown_left(PID + 1), 0.0, "the cooldown is the user's")
