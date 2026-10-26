extends GutTest
## Skyhook Sekt (UPDATE 07, T-105; docs/MAP4_FERNFLUG.md section 7.1): the data, the effect keys the player
## reads, the air hop, safe landings, the push / pull resistance, the Stall Turn stomp and the cap glyph.

const PID: int = 1

var _p: Player


func before_each() -> void:
	GameState.player_ids = [PID]
	GameState.power_on = true
	RoundManager.current_round = 20
	PerkManager.reset_match()
	PerkManager.meta_gate_override = 0
	Economy.reset([PID])
	Economy.grant(PID, 100000)


func after_each() -> void:
	PerkManager.meta_gate_override = -1
	PerkManager.reset_match()
	PerkManager.clear_tier_timers()


func _player() -> Player:
	_p = Player.new()
	_p.player_id = PID
	add_child_autofree(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return _p


func test_data_row() -> void:
	var d: Dictionary = PerkManager.perk_data(&"skyhook_sekt")
	assert_false(d.is_empty())
	assert_eq(int(d["cost"]), 2500)
	assert_eq(str(d["shape"]), "glider")
	assert_true(bool(d["needs_power"]))
	assert_eq(PerkManager.tier_name(&"skyhook_sekt", 2), "Skyhook Sekt II")
	assert_eq(int(PerkManager.tier_data(&"skyhook_sekt", 2)["cost"]), 3500)
	assert_eq(int(PerkManager.tier_data(&"skyhook_sekt", 3)["cost"]), 7000)
	assert_true(PerkCap.has_glyph(&"skyhook_sekt"), "the cap draws a crane, not letters")
	assert_eq(str(GLVO.PERK_TOKENS[&"skyhook_sekt"]), "SKYHOOK")
	assert_eq(str(GLVO.PERK_TOKENS[&"fine_print_fernet"]), "FERNET", "Fernet's missing token (T-105)")
	assert_eq(PerkMachine._shape_footprint("glider"), Vector3(0.8, 2.4, 0.7))


func test_effect_keys_by_tier() -> void:
	assert_eq(int(PerkManager.stat(PID, "air_hops", 0)), 0, "no hop without the tonic")
	PerkManager.grant(PID, &"skyhook_sekt")
	assert_almost_eq(float(PerkManager.stat(PID, "air_accel_mult", 1.0)), 2.5, 0.001)
	assert_eq(int(PerkManager.stat(PID, "air_hops", 0)), 1)
	assert_true(bool(PerkManager.stat(PID, "safe_landing", false)))
	assert_almost_eq(float(PerkManager.stat(PID, "slide_speed_mult", 1.0)), 1.25, 0.001)
	assert_almost_eq(float(PerkManager.stat(PID, "slide_duration_mult", 1.0)), 1.2, 0.001)
	assert_almost_eq(float(PerkManager.stat(PID, "push_resist", 0.0)), 0.3, 0.001)
	assert_almost_eq(float(PerkManager.stat(PID, "pull_resist", 0.0)), 0.5, 0.001)
	assert_false(bool(PerkManager.stat(PID, "hop_reset_on_slide", false)))
	PerkManager.set_tier(PID, &"skyhook_sekt", 2)
	assert_true(bool(PerkManager.stat(PID, "hop_reset_on_slide", false)), "Thermal re-arms the hop on a slide")
	assert_almost_eq(float(PerkManager.stat(PID, "slide_jump_boost_mult", 1.0)), 1.5, 0.001)
	assert_false(bool(PerkManager.stat(PID, "hop_stomp", false)))
	PerkManager.set_tier(PID, &"skyhook_sekt", 3)
	assert_true(bool(PerkManager.stat(PID, "hop_stomp", false)), "Stall Turn stomps")
	assert_almost_eq(float(PerkManager.stat(PID, "hop_stomp_radius", 0.0)), 2.5, 0.001)


func test_stomp_damage_rule() -> void:
	var fx: Dictionary = PerkManager.effects_for(&"skyhook_sekt", 3)
	var hr: float = float(RoundManager.zombie_health(20, GLData.table("rounds")))
	assert_almost_eq(PerkManager.stomp_damage(hr, false, fx), 0.4 * hr, 0.01, "0.4 x health(r) on a Gänger")
	assert_almost_eq(PerkManager.stomp_damage(hr, true, fx), 400.0, 0.01, "bosses take the flat 400")
	assert_lt(PerkManager.stomp_damage(hr, false, fx), hr, "a stomp never one-shots a zombie of its round")


func test_external_push_and_resistance() -> void:
	var p: Player = _player()
	p.external_push(Vector3(2.0, 0.0, 0.0), 1.0)
	assert_eq(p.push_velocity(), Vector3(2.0, 0.0, 0.0), "no tonic: the whole push")
	PerkManager.grant(PID, &"skyhook_sekt")
	p.external_push(Vector3(2.0, 0.0, 0.0), 1.0)
	assert_almost_eq(p.push_velocity().x, 1.4, 0.001, "push_resist 0.3 keeps 70%")
	p.external_push(Vector3(0.0, 0.0, -4.0), 1.0, &"pull")
	assert_almost_eq(p.push_velocity().z, -2.0, 0.001, "pull_resist 0.5 keeps half")
	p._push_t = 0.0
	assert_eq(p.push_velocity(), Vector3.ZERO, "a push that ran out is nothing")
	assert_false(p.lodestone_ballast(), "no Lodestone in hand")


func test_landing_rearms_the_hop_and_safe_landing_keeps_speed() -> void:
	var p: Player = _player()
	PerkManager.grant(PID, &"skyhook_sekt")
	p._hops_left = 0
	p.velocity = Vector3(9.0, -6.0, 0.0)
	p.sprinting = false
	p._on_landed(6.0)
	assert_eq(p._hops_left, 1, "landing re-arms one hop")
	assert_almost_eq(p.velocity.x, 9.0, 0.001, "safe landing: no land_speed_loss")
	# without the tonic the same landing bleeds speed above the walk
	PerkManager.remove(PID, &"skyhook_sekt")
	p.velocity = Vector3(9.0, -6.0, 0.0)
	p._on_landed(6.0)
	assert_lt(p.velocity.x, 9.0, "no tonic: land_speed_loss applies")
	assert_eq(p._hops_left, 0)
