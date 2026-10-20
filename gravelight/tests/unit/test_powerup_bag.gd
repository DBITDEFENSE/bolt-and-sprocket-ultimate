extends GutTest
## Power-up shuffled bag: every type appears once per cycle before any repeats.


func test_bag_cycles_every_type() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 1234
	var source: Array = ["resupply", "deaths_door", "double_scrip", "blackout", "fortify"]
	var bag: Array[StringName] = []
	var seen: Dictionary = {}
	for i: int in source.size():
		seen[PowerupManager.draw_from_bag(bag, source, [], r)] = true
	assert_eq(seen.size(), source.size())
