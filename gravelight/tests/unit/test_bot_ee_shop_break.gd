extends GutTest
## T-153: a bot working an egg takes a shopping break when it is rich (ee.json shop_break), never mid-job, and not
## again before the cooldown; the break is a pause reason after the existing ones.

var sb: Dictionary


func before_all() -> void:
	sb = GLData.load_json("res://data/gravelight/ai/ee.json").get("shop_break", {})


func test_data() -> void:
	assert_false(sb.is_empty(), "ee.json has a shop_break block")
	assert_gt(int(sb.get("scrip", 0)), 0, "a Scrip threshold")
	assert_gt(float(sb.get("seconds", 0.0)), 0.0, "a break length")
	assert_gt(float(sb.get("every_s", 0.0)), float(sb.get("seconds", 0.0)), "the cooldown is longer than the break")


func test_due_rules() -> void:
	var rich: int = int(sb["scrip"]) + 500
	assert_true(BotEECatalog.shop_break_due(rich, "use", 100.0, 0.0, sb), "rich, walking to a pickup: a break")
	assert_false(BotEECatalog.shop_break_due(int(sb["scrip"]) - 1, "use", 100.0, 0.0, sb), "not rich enough: no break")
	for d: String in ["hold", "door", "input", "handoff", "turn"]:
		assert_false(BotEECatalog.shop_break_due(rich, d, 100.0, 0.0, sb), "never in the middle of '%s'" % d)
	assert_false(BotEECatalog.shop_break_due(rich, "use", 100.0, 150.0, sb), "not before the cooldown ends")
	assert_false(BotEECatalog.shop_break_due(rich, "use", 100.0, 0.0, {}), "no block: no breaks (the old behaviour)")


func test_pause_reason_order() -> void:
	var c: Dictionary = GLData.load_json("res://data/gravelight/ai/ee.json")
	assert_eq(BotEECatalog.pause_reason({"type": "carry", "pressure": 0.0, "shop": true}, c), "shopping", "a due break pauses the task")
	assert_eq(BotEECatalog.pause_reason({"type": "carry", "pressure": 0.9, "shop": true}, c), "threat", "a fight comes first")
	assert_eq(BotEECatalog.pause_reason({"type": "carry", "pressure": 0.0, "shop": false}, c), "", "no break: no pause")
