extends GutTest
## T-181: the Requiem made easier for bots and people (the owner: the bots "get stuck at the bell part"): the Four
## Bells ignore a repeat of a bell already rung, carry a bigger shot box, ring on a blast and glow once the music
## box is open; the calling radios carry farther; a bot's walk to a vantage has its own clock and its aim a tolerance
## from the target's size; the scout also looks for a collect step's unheard things.

var quest: Dictionary
var ee: Dictionary
var req: Dictionary


func before_all() -> void:
	quest = GLData.load_json("res://data/gravelight/quests/map01_requiem.json")
	ee = BotEECatalog.cfg()
	req = (GLData.table("map01") as Dictionary).get("requiem", {})


func _step(sid: String) -> Dictionary:
	for s: Variant in quest.get("steps", []):
		if str((s as Dictionary).get("id", "")) == sid:
			return s
	return {}


func test_repeat_of_a_rung_bell_is_ignored() -> void:
	var want: Array = ["n3", "n1", "n4", "n2"]
	var p: Dictionary = {"repeat_ok": true}
	assert_false(QuestManager.repeat_ignored(p, want, 0, "n3"), "nothing rung yet: the first bell counts")
	assert_true(QuestManager.repeat_ignored(p, want, 1, "n3"), "the bell just rung again (a burst): ignored")
	assert_true(QuestManager.repeat_ignored(p, want, 3, "n1"), "one rung earlier: ignored")
	assert_false(QuestManager.repeat_ignored(p, want, 1, "n4"), "an unrung bell out of order still resets")
	assert_false(QuestManager.repeat_ignored({}, want, 1, "n3"), "without repeat_ok (Map 0's radio tune) every input counts")


func test_requiem_data() -> void:
	assert_true(bool((_step("s6_bells").get("params", {}) as Dictionary).get("repeat_ok", false)), "s6 repeat_ok")
	assert_eq(float((_step("s2a_radios").get("bot_task", {}) as Dictionary).get("hear_m", 0.0)), QuestRadio.HEAR_M, "the bots hear a radio as far as a player does")
	assert_gt(QuestRadio.HEAR_M, 12.0, "the radios carry farther than the old 12 m")
	assert_gt(float(req.get("bell_hit_box_m", 0.0)), 0.4 * 1.6, "a small bell's shot box is bigger than its old 0.64 m")
	assert_gt(float(req.get("bell_splash_m", 0.0)), 0.0, "a blast rings a bell")
	assert_eq(str(req.get("bells_glow_after", "")), "s5_reliquary", "the bells glow once the music box is open")
	assert_false(_step(str(req.get("bells_glow_after", ""))).is_empty(), "bells_glow_after names a real step")
	assert_almost_eq(float((_step("s8a_place").get("bot_task", {}) as Dictionary).get("pause_pressure", 0.0)), 0.85, 0.001, "the shard errand pauses only under heavy threat")


func test_bell_marker_rule() -> void:
	assert_false(QuestBell.marker_due(false, false), "before the music box: no marker")
	assert_true(QuestBell.marker_due(true, false), "the music box open, the bells still to ring: marked")
	assert_false(QuestBell.marker_due(true, true), "the Four Bells done: no marker")


func test_shoot_walk_budget() -> void:
	for k: String in ["shoot_walk_s", "shoot_walk_per_m", "shoot_target_m", "aim_tol_max_deg", "shoot_stall_s"]:
		if k != "shoot_stall_s":
			assert_true(ee.has(k), "ee.json %s" % k)
	var near: float = BotEE.shoot_walk_budget(5.0, ee)
	var far: float = BotEE.shoot_walk_budget(100.0, ee)
	assert_gt(far, near, "a far vantage gets more walking time")
	assert_gt(far, float(ee.get("shoot_stall_s", 35.0)), "a 100 m walk outlasts the old 35 s stall clock")
	assert_eq(BotEE.shoot_walk_budget(-3.0, ee), float(ee["shoot_walk_s"]))


func test_aim_tolerance_from_size() -> void:
	var close: float = BotEE.aim_tol_deg(2.0, ee)
	var far: float = BotEE.aim_tol_deg(40.0, ee)
	assert_gt(close, far, "a close target allows a wider angle")
	assert_lte(close, float(ee["aim_tol_max_deg"]))
	assert_gte(far, 1.0, "never under the old 1 degree")
