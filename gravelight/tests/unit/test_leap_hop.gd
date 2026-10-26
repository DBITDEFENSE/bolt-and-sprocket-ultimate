extends GutTest
## The low-g hop (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.2, T-112): below the gravity threshold every
## pressurized Gänger with a clear line to its target in range crouches and leaps a ballistic arc at it; never
## in vacuum, never the Suited, never crawlers, never on cooldown; the arc lands where it was aimed.

var hc: Dictionary


func before_each() -> void:
	hc = Zombie.hop_cfg()


func test_data() -> void:
	assert_false(hc.is_empty(), "enemies.json leap_hop")
	assert_almost_eq(float(hc["max_gravity_scale"]), 0.7, 0.001)
	assert_true(float(hc["range_min"]) < float(hc["range_max"]))
	assert_gt(float(hc["cooldown_seconds"]), 3.0)


func test_hop_due_rules() -> void:
	assert_true(Zombie.hop_due(0.38, true, true, 6.5, true, false, false, 0.0, hc), "the Moon, in range, clear")
	assert_false(Zombie.hop_due(1.0, true, true, 6.5, true, false, false, 0.0, hc), "Earth gravity: never")
	assert_false(Zombie.hop_due(0.38, false, true, 6.5, true, false, false, 0.0, hc), "a kind that doesn't hop (the Suited)")
	assert_false(Zombie.hop_due(0.38, true, false, 6.5, true, false, false, 0.0, hc), "in the air already")
	assert_false(Zombie.hop_due(0.38, true, true, 3.0, true, false, false, 0.0, hc), "too close")
	assert_false(Zombie.hop_due(0.38, true, true, 12.0, true, false, false, 0.0, hc), "too far")
	assert_false(Zombie.hop_due(0.38, true, true, 6.5, false, false, false, 0.0, hc), "a wall between")
	assert_false(Zombie.hop_due(0.38, true, true, 6.5, true, true, false, 0.0, hc), "in vacuum")
	assert_false(Zombie.hop_due(0.38, true, true, 6.5, true, false, true, 0.0, hc), "a crawler")
	assert_false(Zombie.hop_due(0.38, true, true, 6.5, true, false, false, 2.0, hc), "on cooldown")


func test_hop_velocity_lands_on_the_target() -> void:
	var g: float = 18.0 * 0.38
	var v: Vector3 = Zombie.hop_velocity(Vector3(6.0, 0.0, 0.0), 2.2, g)
	assert_gt(v.y, 0.0)
	var t: float = 2.0 * v.y / g
	assert_almost_eq(v.x * t, 6.0, 0.01, "lands 6 m away")
	assert_almost_eq(v.y * v.y / (2.0 * g), 2.2, 0.01, "the apex at 2.2 m")
	var v2: Vector3 = Zombie.hop_velocity(Vector3(0.0, 0.0, -8.0), 2.2, g)
	assert_almost_eq(v2.z * (2.0 * v2.y / g), -8.0, 0.01, "any direction")
	var v3: Vector3 = Zombie.hop_velocity(Vector3.ZERO, 2.2, g)
	assert_almost_eq(v3.x, 0.0, 0.001, "straight up when the target is underfoot")


func test_the_suited_never_hop() -> void:
	var cfg: Dictionary = Zombie.kind_config(&"suited")
	assert_false(bool(cfg.get("leap_hop", true)))
	assert_true(bool(Zombie.kind_config(&"ganger").get("leap_hop", true)), "a plain Gänger does")
