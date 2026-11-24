extends GutTest
## Magpie Mead (UPDATE 07, T-105; docs/MAP4_FERNFLUG.md section 7.2): the drop chance by limb, the kind weights,
## the Scrip curve, what a drop hands over, the holder-only rule and Pawn Shop's sharing / every-25th power-up,
## Scavenger's salvage multiplier.

const PID: int = 1


func before_each() -> void:
	GameState.player_ids = [PID]
	GameState.power_on = true
	RoundManager.current_round = 12
	PerkManager.reset_match()
	PerkManager.meta_gate_override = 0
	PerkManager.clear_tier_timers()
	Economy.reset([PID])
	Economy.grant(PID, 1000)


func after_each() -> void:
	PerkManager.meta_gate_override = -1
	PerkManager.reset_match()
	PerkManager.clear_tier_timers()


func test_data_row() -> void:
	var d: Dictionary = PerkManager.perk_data(&"magpie_mead")
	assert_eq(int(d["cost"]), 3000)
	assert_eq(str(d["shape"]), "bandit")
	assert_eq(int(PerkManager.tier_data(&"magpie_mead", 2)["cost"]), 4000)
	assert_eq(int(PerkManager.tier_data(&"magpie_mead", 3)["cost"]), 8000)
	assert_true(PerkCap.has_glyph(&"magpie_mead"))
	assert_eq(str(GLVO.PERK_TOKENS[&"magpie_mead"]), "MAGPIE")
	assert_true(ProfileSave.CABINET_PERKS.has("magpie_mead"), "the Archive files its panel")


func test_chance_by_limb_and_tier() -> void:
	var fx1: Dictionary = PerkManager.effects_for(&"magpie_mead", 1)
	assert_almost_eq(PerkManager.magpie_chance(fx1, &"torso", false), 0.12, 0.001)
	assert_almost_eq(PerkManager.magpie_chance(fx1, &"head", false), 0.18, 0.001)
	assert_almost_eq(PerkManager.magpie_chance(fx1, &"torso", true), 0.18, 0.001, "melee kills count like heads")
	var fx2: Dictionary = PerkManager.effects_for(&"magpie_mead", 2)
	assert_almost_eq(PerkManager.magpie_chance(fx2, &"torso", false), 0.18, 0.001, "Scavenger")
	assert_almost_eq(PerkManager.magpie_chance(fx2, &"head", false), 0.26, 0.001)
	assert_eq(int(fx2.get("magpie_mags", 0)), 2)


func test_kind_weights_and_scrip_curve() -> void:
	var fx: Dictionary = PerkManager.effects_for(&"magpie_mead", 1)
	assert_eq(PerkManager.magpie_kind(fx, 0.0), &"ammo")
	assert_eq(PerkManager.magpie_kind(fx, 0.49), &"ammo")
	assert_eq(PerkManager.magpie_kind(fx, 0.51), &"scrip")
	assert_eq(PerkManager.magpie_kind(fx, 0.84), &"scrip")
	assert_eq(PerkManager.magpie_kind(fx, 0.86), &"grenade")
	assert_eq(PerkManager.magpie_scrip(fx, 1), 70)
	assert_eq(PerkManager.magpie_scrip(fx, 12), 180)
	assert_eq(PerkManager.magpie_scrip(fx, 40), 250, "capped")


func test_drop_is_the_holders_until_pawn_shop() -> void:
	PerkManager.grant(PID, &"magpie_mead")
	var fx: Dictionary = PerkManager.effects_for(&"magpie_mead", 1)
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var d: MagpieDrop = PerkManager.spawn_magpie_drop(PID, Vector3(1, 0, 1), fx) as MagpieDrop
	assert_not_null(d)
	assert_eq(d.owner_pid, PID)
	assert_false(d.shared, "tier 1: the holder only")
	assert_almost_eq(d.life, 20.0, 0.001)
	assert_true([&"ammo", &"scrip", &"grenade"].has(d.kind))
	d.queue_free()
	PerkManager.clear_tier_timers()   # the drop counter restarts
	PerkManager.set_tier(PID, &"magpie_mead", 3)
	var fx3: Dictionary = PerkManager.effects_for(&"magpie_mead", 3)
	var kinds: Dictionary = {}
	for i: int in 25:
		var dd: MagpieDrop = PerkManager.spawn_magpie_drop(PID, Vector3(1, 0, 1), fx3) as MagpieDrop
		assert_true(dd.shared, "Pawn Shop: anyone may take it")
		kinds[dd.kind] = true
		if i == 24:
			assert_eq(dd.kind, &"powerup", "the 25th drop is a power-up")
		dd.queue_free()
	assert_true(kinds.has(&"powerup"))


func test_give_ammo_rules() -> void:
	var w: WeaponInstance = WeaponInstance.create(&"mp40")
	w.reserve = 0
	assert_true(MagpieDrop.give_ammo(w, 1, false))
	assert_eq(w.reserve, w.mag_size(), "one magazine of reserve")
	assert_true(MagpieDrop.give_ammo(w, 2, false))
	assert_eq(w.reserve, w.mag_size() * 3)
	w.reserve = w.reserve_max()
	assert_false(MagpieDrop.give_ammo(w, 1, false), "a full reserve leaves the drop lying")
	var b: WeaponInstance = WeaponInstance.create(&"totenglocke")
	b.mag = b.mag_size() - 1
	assert_true(MagpieDrop.give_ammo(b, 1, false))
	assert_eq(b.mag, b.mag_size(), "a wonder weapon gets one charge")


func test_salvage_mult() -> void:
	assert_almost_eq(PerkManager.salvage_mult(PID), 1.0, 0.001)
	PerkManager.grant(PID, &"magpie_mead")
	assert_almost_eq(PerkManager.salvage_mult(PID), 1.0, 0.001, "tier 1 leaves the dog tags alone")
	PerkManager.set_tier(PID, &"magpie_mead", 2)
	assert_almost_eq(PerkManager.salvage_mult(PID), 2.0, 0.001, "Scavenger doubles the salvage chance")


func test_cap_of_six_still_holds_with_twelve_tonics() -> void:
	var perks: Dictionary = GLData.table("perks")["perks"]
	assert_eq(perks.size(), 13)   # (T-276: Rocket Man the thirteenth)
	assert_eq(PerkManager.data_cap(false), 6)
	assert_eq(PerkCap.GLYPHS.size(), perks.size(), "every tonic draws a glyph")
