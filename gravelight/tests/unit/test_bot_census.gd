extends GutTest
## The bot census' rules (bot AI pass 2026-11, tools_src/bot_census.gd): what counts as a stuck episode from
## positions alone, and how episodes are clustered into hot spots.


func _hist(points: Array, goal: Vector3, step_s: float = 0.25) -> Array:
	var h: Array = []
	for i: int in points.size():
		var p: Vector3 = points[i]
		h.append({"t": float(i) * step_s, "p": p, "gd": Vector2(goal.x - p.x, goal.z - p.z).length(), "far": true, "path": true, "spd": 0.0})
	return h


func test_standing_at_a_fence_with_a_far_goal_is_no_progress() -> void:
	var pts: Array = []
	for i: int in 21:
		pts.append(Vector3(0.02 * float(i % 2), 0, 0))   # leaning on it: a few cm either way for 5 s
	var w: Dictionary = BotCensus._window(_hist(pts, Vector3(10, 0, 0)), BotCensus.NOPROG_S)
	assert_false(w.is_empty(), "five seconds of history")
	assert_true(BotCensus.is_noprog(float(w["net"]), float(w["gd0"]), 10.0), "no net movement, the goal no closer")


func test_walking_to_the_goal_is_progress() -> void:
	var pts: Array = []
	for i: int in 21:
		pts.append(Vector3(0.5 * float(i), 0, 0))
	var h: Array = _hist(pts, Vector3(20, 0, 0))
	var w: Dictionary = BotCensus._window(h, BotCensus.NOPROG_S)
	assert_false(BotCensus.is_noprog(float(w["net"]), float(w["gd0"]), float((h[h.size() - 1] as Dictionary)["gd"])), "10 m walked toward it")


func test_a_goal_that_walks_up_to_a_standing_bot_is_not_stuck() -> void:
	# the leader's slot comes closer while the bot waits: the goal got closer, so not "no progress"
	assert_false(BotCensus.is_noprog(0.1, 9.0, 6.0), "the goal came 3 m closer")
	assert_true(BotCensus.is_noprog(0.1, 9.0, 8.6), "0.4 m is not progress")


func test_a_short_history_judges_nothing() -> void:
	var pts: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	assert_true(BotCensus._window(_hist(pts, Vector3(10, 0, 0)), BotCensus.NOPROG_S).is_empty(), "0.5 s of samples is not a 5 s window")


func test_pacing_along_a_fence_is_oscillation() -> void:
	var pts: Array = []
	for i: int in 33:   # 8 s: back and forth over 2.5 m, 1.25 m a sample
		var ph: int = i % 4
		pts.append(Vector3([0.0, 1.25, 2.5, 1.25][ph], 0, 0))
	var h: Array = _hist(pts, Vector3(1.0, 0, 12.0))
	var w: Dictionary = BotCensus._window(h, BotCensus.OSC_S)
	assert_gt(float(w["walked"]), BotCensus.OSC_WALK_M, "it walked a long way")
	assert_lt(float(w["box"]), BotCensus.OSC_BOX_M, "inside a small box")
	assert_true(BotCensus.is_osc(float(w["walked"]), float(w["box"]), float(w["gd0"]), float((h[h.size() - 1] as Dictionary)["gd"])))
	assert_false(BotCensus.is_osc(float(w["walked"]), float(w["box"]), 12.0, 9.0), "3 m gained on the goal: a detour, not pacing")
	assert_false(BotCensus.is_osc(3.0, 2.0, 12.0, 12.0), "3 m walked in 8 s is standing about, the no-progress rule's case")


func test_the_window_notes_a_missing_path_and_a_near_goal() -> void:
	var h: Array = _hist([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO], Vector3(9, 0, 0), 1.0)
	for s: Variant in h:
		(s as Dictionary)["path"] = false
	var w: Dictionary = BotCensus._window(h, BotCensus.NOPATH_S)
	assert_false(bool(w["any_path"]), "never had a path")
	assert_true(bool(w["all_far"]))
	(h[2] as Dictionary)["far"] = false
	assert_false(bool(BotCensus._window(h, BotCensus.NOPATH_S)["all_far"]), "one sample at the goal breaks the stretch")


func test_cells_are_per_storey() -> void:
	assert_eq(BotCensus.cell_of(Vector3(1.0, 0.0, 1.0)), BotCensus.cell_of(Vector3(2.4, 0.3, 2.4)), "the same 2.5 m square")
	assert_ne(BotCensus.cell_of(Vector3(1.0, 0.0, 1.0)), BotCensus.cell_of(Vector3(2.6, 0.0, 1.0)), "the next square")
	assert_ne(BotCensus.cell_of(Vector3(1.0, 0.0, 1.0)), BotCensus.cell_of(Vector3(1.0, -3.2, 1.0)), "the cellar under it")
	assert_ne(BotCensus.cell_of(Vector3(1.0, 0.0, 1.0)), BotCensus.cell_of(Vector3(1.0, 3.4, 1.0)), "the attic over it")


func test_cluster_ranks_hot_spots_by_seconds() -> void:
	var eps: Array = [
		{"pos": Vector3(1, 0, 1), "dur": 5.0, "kind": "noprog", "zone": "YARD", "against": "Fence", "action": "follow", "task": "", "name": "Dutch"},
		{"pos": Vector3(1.5, 0, 1.2), "dur": 9.0, "kind": "noprog", "zone": "YARD", "against": "Fence", "action": "retreat", "task": "", "name": "Wren"},
		{"pos": Vector3(20, 0, 20), "dur": 30.0, "kind": "nopath", "zone": "FIELD", "against": "", "action": "buy", "task": "a tonic", "name": "Deacon"},
		{"pos": Vector3(1.2, -3.2, 1.0), "dur": 6.0, "kind": "osc", "zone": "CELLAR", "against": "", "action": "follow", "task": "", "name": "Dutch"}]
	var hot: Array[Dictionary] = BotCensus.cluster(eps)
	assert_eq(hot.size(), 3, "the two at the fence share a cell; the cellar under it is its own")
	assert_eq(str(hot[0]["zone"]), "FIELD", "30 s first")
	assert_eq(int(hot[1]["n"]), 2)
	assert_almost_eq(float(hot[1]["secs"]), 14.0, 0.001)
	assert_eq(int((hot[1]["against"] as Dictionary)["Fence"]), 2)
	assert_almost_eq((hot[1]["center"] as Vector3).x, 1.25, 0.001)
	assert_eq(str(hot[2]["zone"]), "CELLAR")
