extends GutTest
## Weapon data integrity and damage math (docs/WEAPONS.md).

const REQUIRED: PackedStringArray = ["name", "class", "damage", "rpm", "mode", "mag", "reserve",
	"reload_partial", "reload_empty", "ads_time", "falloff_start", "falloff_end", "falloff_min"]


func test_every_weapon_has_required_fields() -> void:
	var weapons: Dictionary = GLData.table("weapons")["weapons"]
	assert_gt(weapons.size(), 10)
	for id: String in weapons.keys():
		for key: String in REQUIRED:
			assert_true(weapons[id].has(key), "%s missing %s" % [id, key])


func test_wall_prices_match_docs() -> void:
	var w: Dictionary = GLData.table("weapons")["weapons"]
	var expected: Dictionary = {"kar98k": 200, "m1_garand": 600, "gewehr43": 900, "m1_carbine": 600, "mp40": 1000,
		"thompson": 1200, "stg44": 1200, "trench_gun": 1500, "bar": 1800}
	for id: String in expected.keys():
		assert_eq(int(w[id]["wall_price"]), int(expected[id]), id)


func test_falloff_curve() -> void:
	var m1911: WeaponInstance = WeaponInstance.create(&"m1911")
	assert_almost_eq(m1911.falloff(5.0), 1.0, 0.001)
	assert_almost_eq(m1911.falloff(20.0), 0.8, 0.001)   # halfway from 10 m (1.0) to 30 m (0.6)
	assert_almost_eq(m1911.falloff(100.0), 0.6, 0.001)


func test_limb_overrides() -> void:
	var tg: WeaponInstance = WeaponInstance.create(&"trench_gun")
	assert_almost_eq(tg.limb_mult(&"head"), 1.5, 0.001)
	assert_almost_eq(tg.limb_mult(&"torso"), 1.0, 0.001)
	var k: WeaponInstance = WeaponInstance.create(&"kar98k")
	assert_almost_eq(k.limb_mult(&"head"), 4.0, 0.001)


func test_round_one_balance() -> void:
	# A pistol headshot and a knife hit both kill a round-1 Ganger (150 HP).
	var rounds: Dictionary = GLData.table("rounds")
	var hp1: int = RoundManager.zombie_health(1, rounds)
	var m1911: WeaponInstance = WeaponInstance.create(&"m1911")
	assert_gte(m1911.f("damage") * m1911.limb_mult(&"head"), float(hp1))
	assert_gte(float(GLData.table("weapons")["melee"]["trench_knife"]["damage"]), float(hp1))


func test_input_actions_exist() -> void:
	for action: String in ["move_forward", "fire", "ads", "reload", "interact", "melee", "lethal", "sprint", "crouch", "pause", "dev_console"]:
		assert_true(InputMap.has_action(StringName(action)), action)
