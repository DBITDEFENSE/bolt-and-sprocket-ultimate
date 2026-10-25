extends GutTest
## Attachments for every gun (UPDATE_04 section 6 generalised, DECISIONS T-074): a table per weapon class with
## per-weapon overrides, the in-character refusals, pricing, slot exclusivity, stats applied, the Crucible carry
## (upgraded blocks, derived numbers), transfer to Jakub, the campaign / co-op carry, the bench API for any gun,
## the models (scopes keep the sight line), and the M1911's T-068 table unchanged.

const FROZEN_M1911: String = "res://gravelight/tests/fixtures/m1911_attachments_t068.json"

var _free: Array = []


func after_each() -> void:
	for n: Variant in _free:
		if is_instance_valid(n):
			(n as Node).free()
	_free.clear()
	GameState.power_on = false


func _player(pid: int = 1, gun: StringName = &"") -> Player:
	var p: Player = Player.new()
	p.player_id = pid
	var h: WeaponHolder = WeaponHolder.new()
	h.mirror = true
	h.player = p
	p.weapons = h
	h.call("_set_start_loadout")
	if gun != &"":
		h.give_weapon(gun)   # second slot, in hand
	_free.append(h)
	_free.append(p)
	return p


func _gun(build: String) -> WeaponInstance:
	return WeaponKit.from_build(build)


static func _all_ids() -> Array:
	var t: Dictionary = GLData.table("weapons")
	return (t["weapons"] as Dictionary).keys() + (t["upgraded"] as Dictionary).keys()


# ---------------------------------------------------------------- the M1911 is exactly T-068's

func test_m1911_table_is_unchanged() -> void:
	var old: Dictionary = GLData.load_json(FROZEN_M1911)
	assert_false(old.is_empty(), "the frozen T-068 table loads")
	var cfg: Dictionary = M1911Kit.cfg()
	assert_eq(JSON.stringify(cfg["options"], "", true), JSON.stringify(old["options"], "", true), "every M1911 option, price and number as T-068 left them")
	for k: String in ["slot_order", "stat_bars", "finishes", "loadout_pick"]:
		assert_eq(JSON.stringify(cfg[k], "", true), JSON.stringify(old[k], "", true), k)
	assert_eq(WeaponKit.slot_order(&"m1911"), old["slot_order"])
	assert_eq(float(WeaponKit.table(&"m1911").get("boost", 0.0)), 0.0, "Last Rites' numbers are its own, never derived")
	# the compiled numbers, base and Last Rites, for every option
	for slot: String in M1911Kit.slot_order():
		for opt: Variant in M1911Kit.options(slot):
			for up: bool in [false, true]:
				var want: Dictionary = (old["options"][slot][opt] as Dictionary)
				if up:
					want = want["upgraded"]
				var got: Dictionary = WeaponKit.variant(&"m1911", slot, str(opt), up)
				for g: String in ["stats", "set", "limb", "recoil", "props"]:
					if want.has(g):
						assert_eq(JSON.stringify(got.get(g, {}), "", true), JSON.stringify(want[g], "", true), "%s/%s %s %s" % [slot, opt, up, g])


# ---------------------------------------------------------------- tables for every gun

func test_every_gun_has_a_table_or_a_refusal() -> void:
	for id: Variant in _all_ids():
		var wid: String = str(id)
		var cls: String = str(WeaponInstance.create(StringName(wid)).weapon_class())
		if cls == "wonder":
			assert_false(WeaponKit.accepts(wid), "%s: the bench refuses wonder weapons" % wid)
			assert_ne(WeaponKit.refusal(wid), "", "%s: in character" % wid)
			continue
		assert_true(WeaponKit.accepts(wid), "%s takes attachments" % wid)
		var slots: Array = WeaponKit.slot_order(wid)
		assert_between(slots.size(), 3, 5, "%s: 3-5 slots" % wid)
		for slot: Variant in slots:
			assert_gt(WeaponKit.options(wid, str(slot)).size(), 0, "%s/%s has options" % [wid, slot])
			for opt: Variant in WeaponKit.options(wid, str(slot)):
				var d: Dictionary = WeaponKit.option_def(wid, str(slot), str(opt))
				assert_gt(int(d.get("price", 0)), 0, "%s %s/%s priced" % [wid, slot, opt])
				assert_true(d.has("upgraded"), "%s %s/%s has a Crucible version" % [wid, slot, opt])
				assert_ne(WeaponKit.option_name(wid, str(slot), str(opt), true), WeaponKit.option_name(wid, str(slot), str(opt), false),
					"%s %s/%s: the upgraded part has its own name" % [wid, slot, opt])


func test_refusals_for_wonder_weapons_melee_and_tacticals() -> void:
	for id: String in ["ashlight", "totenglocke", "elmsfeuer", "ashlight_up", "trench_knife", "etool", "gramophone"]:
		assert_false(WeaponKit.accepts(id), id)
		assert_ne(WeaponKit.refusal(id), "", id)
	var p: Player = _player(1, &"ashlight")
	assert_eq(p.weapons.current().id, &"ashlight")
	# the M1911 in the other slot takes the order (a bot sent for a part); the bench UI shows the refusal
	assert_eq(WeaponKit.gun_of(p).id, &"m1911", "the gun the bench would work on: the pistol in the other slot")
	assert_false(WeaponKit.accepts(WeaponKit.held(p)), "the gun in hand is refused")
	assert_string_contains(WeaponKit.reason_text("wrong_weapon", WeaponKit.held(p)), "armorer")
	var only: Player = _player(2)
	only.weapons.slots = [WeaponInstance.create(&"totenglocke")]
	assert_eq(str(ArmorersBench.buy(only, "mag", "extended")["reason"]), "wrong_weapon")
	assert_true(ArmorersBench.options_for(only).is_empty())


func test_prices_per_class_and_overrides() -> void:
	var want: Dictionary = {
		"mp40/mag/extended": 1250, "mp40/barrel/suppressor": 1500, "ppsh41/mag/extended": 750, "thompson/mag/drum": 2250,
		"m1_garand/sights/scope": 1500, "kar98k/mag/trench": 1500, "kar98k/sights/scope": 1500, "springfield/sights/high_power": 1250,
		"trench_gun/barrel/choke": 900, "sawed_off/grip/recoil_pad": 700, "bar/grip/bipod": 1250, "mg42/grip/bipod": 1250,
		"m1919/barrel/heavy_barrel": 1250, "panzerschreck/ammo/heat": 2000, "flamethrower/barrel/long_nozzle": 1250,
		"stg44/sights/scope": 2000, "mp40/ammo/nachtglas": 2500,
	}
	for k: String in want.keys():
		var p: PackedStringArray = k.split("/")
		assert_eq(WeaponKit.price(p[0], p[1], p[2]), int(want[k]), k)
	assert_eq(WeaponKit.option_name(&"thompson", "mag", "drum"), "50-Round L Drum", "the Thompson's drum")
	assert_eq(WeaponKit.option_name(&"kar98k", "sights", "scope"), "ZF39 Scope", "a scope for the Kar98k")
	assert_eq(WeaponKit.option_name(&"mg42", "grip", "bipod"), "Heavy Zweibein", "a bipod for the MG42")
	assert_eq(WeaponKit.option_name(&"trench_gun", "barrel", "choke"), "Full Choke", "a choke for the shotgun")
	assert_false(WeaponKit.is_known(&"ppsh41", "mag", "drum"), "the PPSh already has a drum")
	assert_false(WeaponKit.is_known(&"springfield", "sights", "scope"), "the Springfield is already scoped")
	assert_true(WeaponKit.options(&"flamethrower", "sights").is_empty(), "the flamethrower has no sights slot")
	assert_eq(WeaponKit.price(&"thompson_up", "mag", "drum"), 2250, "the upgraded gun uses its base gun's table")
	assert_eq(WeaponKit.slot_name(&"mg42", "grip"), "Bipod / Sling")


# ---------------------------------------------------------------- rules and stats

func test_slot_exclusivity_on_any_gun() -> void:
	var w: WeaponInstance = _gun("thompson")
	WeaponKit.install(w, "mag", "drum")
	assert_eq(w.mag_size(), 50)
	assert_eq(w.mag, 50, "topped up from the reserve")
	assert_eq(WeaponKit.check(w, "mag", "drum", true), "installed")
	assert_eq(WeaponKit.check(w, "mag", "extended", true), "", "another option replaces it")
	WeaponKit.install(w, "mag", "extended")
	assert_eq(w.kit, {"mag": "extended"})
	assert_eq(w.mag_size(), 45, "half again the Thompson's 30")
	assert_eq(w.mag, 45, "the spare rounds go back")
	assert_true(w.reserve <= w.reserve_max())
	assert_eq(WeaponKit.check(w, "mag", "trench", true), "unknown", "a Kar98k part doesn't fit a Thompson")
	assert_eq(WeaponKit.check(w, "ammo", "nachtglas", false), "needs_power")
	assert_eq(WeaponKit.check(w, "ammo", "nachtglas", true, true), "refused", "Jakub won't load Nachtglas, on any gun")


func test_stats_apply_on_other_guns() -> void:
	var mp: WeaponInstance = _gun("mp40")
	var can: WeaponInstance = _gun("mp40:barrel=suppressor")
	assert_true(can.is_suppressed(), "a suppressor keeps the minimap no-reveal flag")
	assert_false(_gun("mp40:barrel=compensator").is_suppressed())
	assert_almost_eq(can.f("damage"), mp.f("damage") * 0.9, 0.01)
	assert_eq(_gun("mp40:mag=extended").mag_size(), 48)
	assert_eq(_gun("mp40:mag=drum").mag_size(), 64, "the MP40/II twin slide doubles it")
	assert_almost_eq(_gun("trench_gun:barrel=choke").f("spread_hip"), _gun("trench_gun").f("spread_hip") * 0.7, 0.001)
	assert_almost_eq(_gun("bar:grip=bipod").f("sway"), _gun("bar").f("sway") * 0.5, 0.001)
	var rc0: Dictionary = WeaponHolder.recoil_for(_gun("mg42"))
	var rc: Dictionary = WeaponHolder.recoil_for(_gun("mg42:grip=bipod"))
	assert_almost_eq(float(rc["v"]), float(rc0["v"]) * 0.75, 0.001, "the bipod: recoil -25%")
	assert_eq(float(_gun("flamethrower:barrel=long_nozzle").property("reach", 0.0)), 9.0, "the long nozzle reaches further")
	assert_eq(_gun("kar98k:mag=trench").mag_size(), 25)
	assert_almost_eq(float((_gun("kar98k:sights=scope").kit_mods()["feel"] as Dictionary)["ads_zoom"]), 0.32, 0.001, "a real scope's zoom")
	assert_eq(_gun("kar98k:ammo=ap").property("kit_penetration", 0), 1)
	assert_true(_gun("m1_garand:ammo=incendiary").property("kit_ignite") is Dictionary)
	assert_eq(_gun("panzerschreck:mag=ready_rack").reserve_max(), 15, "half again the spare rockets")
	assert_lt(_gun("bar:grip=bipod").draw_mult(), 1.2)
	assert_gt(_gun("bar:grip=bipod").draw_mult(), 1.0, "slower to raise")
	var now: Dictionary = WeaponKit.stats(_gun("mg42"))
	var bp: Dictionary = WeaponKit.stats(_gun("mg42"), "grip", "bipod")
	assert_lt(float(bp["recoil"]["value"]), float(now["recoil"]["value"]), "the bench's bars show the bipod's change")
	assert_gt(float(WeaponKit.stats(_gun("mp40"), "mag", "drum")["capacity"]["value"]), float(WeaponKit.stats(_gun("mp40"))["capacity"]["value"]))


# ---------------------------------------------------------------- the Crucible and carrying the kit

func _forge(p: Player, w: WeaponInstance) -> WeaponInstance:
	# what Crucible.interact / _take do: feed the gun in (its kit rides with the forge), hand the upgrade back
	var kit: Array = WeaponKit.encode(w.kit)
	var up: StringName = w.upgrade_id()
	p.weapons.current_index = p.weapons.slots.find(w)
	p.weapons.remove_current()
	p.weapons.give_weapon(up)
	p.weapons.set_kit(up, kit, "")
	return p.weapons.find_weapon(up)


func test_crucible_carries_the_kit_on_other_guns() -> void:
	var p: Player = _player(1, &"thompson")
	var w: WeaponInstance = p.weapons.current()
	WeaponKit.install(w, "mag", "drum")
	WeaponKit.install(w, "barrel", "compensator")
	var up: WeaponInstance = _forge(p, w)
	assert_not_null(up)
	assert_eq(up.id, &"thompson_up")
	assert_eq(up.kit, {"mag": "drum", "barrel": "compensator"})
	assert_eq(up.mag_size(), 100, "the L drum becomes the C drum")
	assert_eq(WeaponKit.option_name(up, "mag", "drum", true), "Chicago Lament: C Drum")
	var p2: Player = _player(2, &"kar98k")
	WeaponKit.install(p2.weapons.current(), "sights", "scope")
	var kar: WeaponInstance = _forge(p2, p2.weapons.current())
	assert_eq(kar.kit.get("sights"), "scope")
	assert_eq(WeaponKit.option_name(kar, "sights", "scope", true), "Watchman's Glass")
	var p3: Player = _player(3, &"mg42")
	WeaponKit.install(p3.weapons.current(), "grip", "bipod")
	var base_sway: float = _gun("mg42:grip=bipod").f("sway") / _gun("mg42").f("sway")
	var mg: WeaponInstance = _forge(p3, p3.weapons.current())
	assert_eq(WeaponKit.option_name(mg, "grip", "bipod", true), "Tripod of the Vigil")
	var up_sway: float = mg.f("sway") / WeaponInstance.create(&"mg42_up").f("sway")
	assert_lt(up_sway, base_sway, "the upgraded bipod steadies more (derived: benefits x upgrade_boost)")
	assert_almost_eq(up_sway, WeaponKit.boosted(0.5, true, float(WeaponKit.cfg()["upgrade_boost"])), 0.001)
	assert_true(WeaponKit.boosted(0.97, false, 1.35) > 0.97, "a drawback shrinks on the upgraded part")


func test_crucible_tier_ii_keeps_the_kit() -> void:
	var w: WeaponInstance = _gun("thompson_up:mag=drum")
	var m1: int = w.mag_size()
	w.tier = 2
	assert_gt(w.mag_size(), m1, "the re-taught gun scales the fitted drum")


func test_handing_any_gun_to_jakub_moves_its_kit() -> void:
	var a: Player = _player(1, &"mp40")
	var b: Player = _player(9)
	WeaponKit.install(a.weapons.current(), "barrel", "suppressor")
	var w: WeaponInstance = a.weapons.remove_current()   # JakubCompanion._take_gun
	b.weapons.slots.clear()
	b.weapons.give_instance(w)
	assert_eq(b.weapons.current().kit.get("barrel"), "suppressor")
	assert_true(b.weapons.current().is_suppressed())
	assert_true(WeaponKit.companion_accepts(b.weapons.current()))
	WeaponKit.install(b.weapons.current(), "ammo", "nachtglas")
	assert_false(WeaponKit.companion_accepts(b.weapons.current()), "he won't take an MP40 loaded with Nachtglas either")


func test_campaign_and_coop_carry_any_kit() -> void:
	var a: Player = _player(1, &"mg42")
	var w: WeaponInstance = a.weapons.current()
	WeaponKit.install(w, "grip", "bipod")
	WeaponKit.install(w, "ammo", "ap")
	WeaponKit.install(w, "mag", "extended")
	w.mag = 77
	w.reserve = 300
	var d: Dictionary = a.weapons.to_net()
	var b: Player = _player(2)
	b.weapons.apply_carry(d)
	var got: WeaponInstance = b.weapons.find_weapon(&"mg42")
	assert_not_null(got)
	assert_eq(got.kit, {"grip": "bipod", "ammo": "ap", "mag": "extended"})
	assert_eq(got.mag, 77)
	assert_eq(got.reserve, 300)
	assert_eq(got.mag_size(), 250)
	assert_eq(WeaponKit.decode(["mag:drum", "sights:scope", "grip:bipod"], &"mg42"), {"grip": "bipod"}, "parts a gun doesn't take are dropped")
	var c: Player = _player(3, &"mg42")
	assert_ne(a.weapons.net_signature()[0], c.weapons.net_signature()[0], "a fitted part is a structure change for co-op")


func test_wall_buy_or_crate_swap_loses_the_kit() -> void:
	var p: Player = _player(1, &"mp40")
	WeaponKit.install(p.weapons.current(), "mag", "drum")
	p.weapons.give_weapon(&"mp40")   # buying the same gun again: ammo only, the kit stays
	assert_eq(p.weapons.find_weapon(&"mp40").kit.get("mag"), "drum")
	p.weapons.give_weapon(&"stg44")  # full hands: the wall-buy / Mystery Crate result takes the MP40's slot
	assert_null(p.weapons.find_weapon(&"mp40"), "the MP40 is gone, and its drum with it")
	assert_true(p.weapons.find_weapon(&"stg44").kit.is_empty(), "the new gun comes plain")


# ---------------------------------------------------------------- the bench API on any gun

func test_bench_buys_for_the_gun_in_hand() -> void:
	var p: Player = _player(1, &"trench_gun")
	var ids: Array[int] = [1]
	Economy.reset(ids)
	Economy.grant(1, 5000 - Economy.get_scrip(1))
	var rows: Array = ArmorersBench.options_for(p)
	assert_gt(rows.size(), 0)
	for r: Dictionary in rows:
		assert_eq(str(r["weapon"]), "trench_gun", "the rows are for the gun in hand")
	var r1: Dictionary = ArmorersBench.buy(p, "barrel", "choke")
	assert_true(bool(r1["ok"]), str(r1))
	assert_eq(Economy.get_scrip(1), 4100)
	assert_eq(p.weapons.current().kit.get("barrel"), "choke")
	assert_true(p.weapons.find_weapon(&"m1911").kit.is_empty(), "the pistol in the other slot is untouched")
	assert_eq(str(ArmorersBench.buy(p, "barrel", "choke")["reason"]), "installed")
	# an M1911 part asked for while holding the shotgun goes on the pistol (bots ordered to the bench for a part)
	var r2: Dictionary = ArmorersBench.buy(p, "grip", "checkered")
	assert_true(bool(r2["ok"]))
	assert_eq(p.weapons.find_weapon(&"m1911").kit.get("grip"), "checkered")
	var pick: Dictionary = BotMarkOrders.pick_bench_option(ArmorersBench.options_for(p), [], Economy.get_scrip(1))
	assert_eq(str(pick.get("weapon", "")), "trench_gun", "a bot's own pick is for its own gun")


func test_bench_sells_the_paratrooper_sling() -> void:
	# T-083: the grip slot's Paratrooper Sling lets a long gun reload at a run (pistols / SMGs have it by class).
	var p: Player = _player(1, &"m1_garand")
	var ids: Array[int] = [1]
	Economy.reset(ids)
	Economy.grant(1, 3000 - Economy.get_scrip(1))
	var row: Dictionary = {}
	for r: Dictionary in ArmorersBench.options_for(p):
		if str(r["slot"]) == "grip" and str(r["option"]) == "quick_sling":
			row = r
	assert_false(row.is_empty(), "the Garand's bench lists it")
	assert_eq(str(row["name"]), "Paratrooper Sling")
	assert_eq(int(row["price"]), 1000)
	assert_false(WeaponHolder.sprint_reload_allowed(p.weapons.current()))
	var r1: Dictionary = ArmorersBench.buy(p, "grip", "quick_sling")
	assert_true(bool(r1["ok"]), str(r1))
	assert_eq(Economy.get_scrip(1), 2000)
	assert_true(WeaponHolder.sprint_reload_allowed(p.weapons.current()), "fitted: it reloads on the run")
	assert_true(bool(p.weapons.current().property("sprint_reload", false)))
	assert_eq(str(ArmorersBench.buy(p, "grip", "sling")["reason"]), "", "another grip part replaces it...")
	assert_false(WeaponHolder.sprint_reload_allowed(p.weapons.current()), "...and the run reload goes with it")
	for cls_gun: StringName in [&"stg44", &"kar98k", &"springfield", &"trench_gun", &"bar", &"panzerschreck", &"flamethrower"]:
		assert_eq(WeaponKit.price(cls_gun, "grip", "quick_sling"), 1250 if cls_gun == &"bar" else 1000, String(cls_gun))
	for by_class: StringName in [&"mp40", &"thompson", &"m1911", &"webley"]:
		assert_false(WeaponKit.is_known(by_class, "grip", "quick_sling"), "%s reloads on the run by class" % by_class)


# ---------------------------------------------------------------- models

func test_models_build_for_every_option_on_every_gun() -> void:
	var n: int = 0
	for id: Variant in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		var wid: String = str(id)
		if not WeaponKit.accepts(wid) or wid == "m1911":
			continue
		var plain: Node3D = WeaponModels.build(StringName(wid))
		var mz0: float = (plain.get_node("Muzzle") as Node3D).position.z
		plain.free()
		for slot: Variant in WeaponKit.slot_order(wid):
			for opt: Variant in WeaponKit.options(wid, str(slot)):
				for up: bool in [false, true]:
					var w: WeaponInstance = _gun(("%s_up" % wid if up else wid) + ":%s=%s" % [slot, opt])
					var m: Node3D = WeaponModels.build(w.base_id(), w.upgraded, &"", WeaponKitModels.look_of(w))
					assert_not_null(m.get_node_or_null("Muzzle"), "%s %s/%s" % [w.id, slot, opt])
					assert_eq(m.find_children("SightPoint", "", true, false).size(), 1, "%s %s/%s: one rear sight" % [w.id, slot, opt])
					assert_eq(m.find_children("FrontSight", "", true, false).size(), 1, "%s %s/%s: one front sight" % [w.id, slot, opt])
					var model: String = str(WeaponKit.variant(wid, str(slot), str(opt), up).get("model", ""))
					if model in ["can", "comp", "hider", "choke", "brake", "barrel_ext", "barrel_band", "nozzle"] and not up:
						assert_lt((m.get_node("Muzzle") as Node3D).position.z, mz0 - 0.005, "%s %s: the muzzle moves to the new crown" % [wid, opt])
					m.free()
					n += 1
	assert_gt(n, 200, "every option on every gun, base and upgraded")


## A scope's sight line is its tube axis: SightPoint (eyepiece) behind FrontSight (objective), both centred
## (x 0) and level, above the irons; the HUD scope picture turns on. (tools/ads_check.sh checks the aim itself.)
func test_scopes_keep_the_sight_line() -> void:
	for build: String in ["kar98k:sights=scope", "kar98k_up:sights=scope", "m1_garand:sights=scope", "gewehr43:sights=scope",
			"m1_carbine:sights=scope", "stg44:sights=scope", "ptrs41:sights=scope", "kar98k:sights=scope,grip=cheek_pad"]:
		var w: WeaponInstance = _gun(build)
		var m: Node3D = WeaponModels.build(w.base_id(), w.upgraded, &"", WeaponKitModels.look_of(w))
		var sp: Node3D = m.find_child("SightPoint", true, false) as Node3D
		var fs: Node3D = m.find_child("FrontSight", true, false) as Node3D
		assert_eq(sp.get_parent(), m, build)
		assert_almost_eq(sp.position.x, 0.0, 0.0001, build)
		assert_almost_eq(fs.position.x, 0.0, 0.0001, build)
		assert_almost_eq(sp.position.y, fs.position.y, 0.0001, "%s: level" % build)
		assert_gt(sp.position.z, fs.position.z + 0.15, "%s: eyepiece behind the objective" % build)
		assert_true(m.has_meta("scope"), "%s: the HUD scope picture" % build)
		var plain: Node3D = WeaponModels.build(w.base_id(), w.upgraded)
		var iron: Node3D = plain.find_child("SightPoint", true, false) as Node3D
		assert_gt(sp.position.y, iron.position.y, "%s: above the iron sights" % build)
		plain.free()
		m.free()
	# radium dots never move the sights
	for wid: String in ["mp40", "thompson", "bar", "panzerschreck"]:
		var a: Node3D = WeaponModels.build(StringName(wid))
		var w2: WeaponInstance = _gun(wid + ":sights=radium")
		var b: Node3D = WeaponModels.build(w2.base_id(), false, &"", WeaponKitModels.look_of(w2))
		for mk: String in ["SightPoint", "FrontSight"]:
			assert_eq((b.find_child(mk, true, false) as Node3D).position, (a.find_child(mk, true, false) as Node3D).position, "%s %s" % [wid, mk])
		a.free()
		b.free()


func test_ads_check_covers_the_new_sight_builds() -> void:
	var builds: PackedStringArray = WeaponKit.sight_stock_builds()
	for want: String in ["m1911:sights=radium", "kar98k:sights=scope", "kar98k_up:sights=scope,grip=cheek_pad", "thompson:sights=aperture",
			"mg42:sights=aa_sight,grip=bipod", "trench_gun:sights=bead,grip=recoil_pad"]:
		assert_true(builds.has(want), want)
	for b: String in builds:
		assert_false(b.begins_with("ashlight"), "no wonder weapons")
