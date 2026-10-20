extends GutTest
## Map 1 machinery math: pylon charge/pause/drain/checkpoints, vault opening, lift cooldown,
## chandelier once-per-round, ore cart shuttle.

var c: Dictionary


func before_all() -> void:
	c = GLData.load_json("res://data/gravelight/map01.json")["pylon"]


func test_charge_takes_45_seconds_when_occupied() -> void:
	var p: float = 0.0
	var e: float = 0.0
	for i: int in 450:
		var r: Array = Pylon.step_charge(p, 0.1, true, e, c)
		p = float(r[0])
		e = float(r[1])
	assert_almost_eq(p, 1.0, 0.001)


func test_pause_then_drain_after_grace() -> void:
	var r: Array = Pylon.step_charge(0.6, 2.0, false, 0.0, c)
	assert_almost_eq(float(r[0]), 0.6, 0.0001, "paused during the 3 s grace")
	r = Pylon.step_charge(float(r[0]), 2.0, false, float(r[1]), c)
	assert_almost_eq(float(r[0]), 0.56, 0.0001, "drains 2 %/s after the grace")


func test_drain_never_below_checkpoint() -> void:
	var p: float = 0.6
	var e: float = 10.0
	for i: int in 100:
		var r: Array = Pylon.step_charge(p, 1.0, false, e, c)
		p = float(r[0])
		e = float(r[1])
	assert_almost_eq(p, 0.5, 0.0001)
	assert_almost_eq(Pylon.checkpoint(0.24, 0.25), 0.0, 0.0001)
	assert_almost_eq(Pylon.checkpoint(0.75, 0.25), 0.75, 0.0001)


func test_returning_resets_grace() -> void:
	var r: Array = Pylon.step_charge(0.3, 0.5, true, 2.9, c)
	assert_eq(float(r[1]), 0.0)


func test_three_pylons_open_vault() -> void:
	assert_false(Pylon.vault_opens(2, int(c["required"])))
	assert_true(Pylon.vault_opens(3, int(c["required"])))


func test_lift_cooldown() -> void:
	assert_almost_eq(Lift.cooldown_remaining(10.0, 60.0), 50.0, 0.001)
	assert_eq(Lift.cooldown_remaining(75.0, 60.0), 0.0)


func test_chandelier_once_per_round() -> void:
	assert_true(ChandelierTrap.can_fire(false, false))
	assert_false(ChandelierTrap.can_fire(true, false))
	assert_false(ChandelierTrap.can_fire(false, true))


func test_ore_cart_shuttles() -> void:
	assert_almost_eq(OreCartTrap.shuttle(0.0, 4.0), 0.0, 0.001)
	assert_almost_eq(OreCartTrap.shuttle(4.0, 4.0), 1.0, 0.001)
	assert_almost_eq(OreCartTrap.shuttle(6.0, 4.0), 0.5, 0.001)
	assert_almost_eq(OreCartTrap.shuttle(8.0, 4.0), 0.0, 0.001)
