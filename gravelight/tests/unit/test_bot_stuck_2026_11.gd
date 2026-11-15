extends GutTest
## Bot AI pass 2026-11 (docs/bots/bot_ai_2026-11.md): the pure rules behind "the bots get stuck on the fence":
## what counts as a way to a goal, what counts as having arrived, the off-navmesh hop, the cut-off catch-up, the
## ladder's end for a bot in plain sight, and what makes a fair path to a spot to step to in a fight.

var loco_cfg: Dictionary = {}


func before_all() -> void:
	loco_cfg = GLData.load_json("res://data/gravelight/ai/locomotion.json")


func _path(pts: Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Variant in pts:
		out.append(p)
	return out


# ---------------------------------------------------------------- a path that ends short of the goal is no way

func test_a_path_that_ends_at_the_fence_does_not_reach_a_goal_beyond_it() -> void:
	# the yard's south fence is at z 48: the navmesh hands back the way to the nearest point it reaches (z 47.4)
	var to_fence: PackedVector3Array = _path([Vector3(10, 0.3, 40), Vector3(10, 0.3, 47.4)])
	assert_false(BotLocomotion.path_reaches(to_fence, Vector3(10, 0.3, 52)), "the goal is 4.6 m past the path's end, in the field")
	assert_true(BotLocomotion.path_reaches(to_fence, Vector3(10.3, 0.3, 47.9)), "a goal half a metre past the end is reached (a spot just off the mesh)")
	assert_false(BotLocomotion.path_reaches(PackedVector3Array(), Vector3(10, 0.3, 52)), "no path at all")


func test_a_path_that_ends_under_the_goal_does_not_reach_it() -> void:
	# a wall gun on the attic landing, the stairs door shut: the path ends in the taproom right under it
	var under: PackedVector3Array = _path([Vector3(8, 0.3, 10), Vector3(3.6, 0.3, 14.7)])
	assert_false(BotLocomotion.path_reaches(under, Vector3(3.6, 3.8, 14.7)), "0 m away on the flat, a storey up")
	assert_true(BotLocomotion.path_reaches(under, Vector3(3.6, 0.9, 14.7)), "half a metre up a ramp is the same place")


func test_arrival_needs_the_goals_storey() -> void:
	assert_true(BotLocomotion.at_goal(Vector3(3.6, 0.0, 14.7), Vector3(3.9, 0.3, 14.9), 1.0), "beside it on its floor")
	assert_false(BotLocomotion.at_goal(Vector3(3.6, 0.0, 14.7), Vector3(3.6, 3.8, 14.7), 1.0), "standing under a goal on the floor above is not arriving")
	assert_false(BotLocomotion.at_goal(Vector3(3.6, 0.0, 14.7), Vector3(3.6, -3.2, 14.7), 1.0), "nor over one in the cellar")
	assert_false(BotLocomotion.at_goal(Vector3(3.6, 0.0, 14.7), Vector3(6.0, 0.3, 14.7), 1.0), "2.4 m short")


# ---------------------------------------------------------------- beside the navmesh

func test_off_mesh_is_a_body_beside_the_navmesh() -> void:
	var st: Dictionary = loco_cfg["stuck"]
	var off: float = float(st["off_mesh_m"])
	assert_eq([off, float(st["off_mesh_snap_s"]), float(st["off_mesh_reach_m"])], [0.55, 3.0, 2.5])
	assert_false(BotLocomotion.off_mesh(Vector3(2.4, 0, 40), Vector3(2.5, 0.3, 40), off), "hugging the fence: the navmesh keeps half a metre off it, a body 0.4")
	assert_true(BotLocomotion.off_mesh(Vector3(1.2, 0, 40), Vector3(2.5, 0.3, 40), off), "1.3 m outside it: shoved into the strip behind the fence")
	assert_false(BotLocomotion.off_mesh(Vector3(16.5, 0.8, 11.5), Vector3(16.5, 0.3, 11.5), off), "on a step over the navmesh: not beside it")
	assert_false(BotLocomotion.off_mesh(Vector3(16.5, 3.5, 11.5), Vector3(18.0, 0.3, 11.5), off), "on the floor above with no navmesh there: the fall rescue's case, not a hop")


# ---------------------------------------------------------------- cut off from the leader

func test_cut_off_for_good_only_on_separate_pieces_of_the_navmesh() -> void:
	var st: Dictionary = loco_cfg["stuck"]
	var cs: float = float(st["cutoff_s"])
	var cm: float = float(st["cutoff_m"])
	assert_eq([cs, cm], [8.0, 10.0])
	assert_false(BotLocomotion.cut_off_for_good(3.0, 30.0, 0.0, false, cs, cm), "3 s without a way: the leader may be mid-jump")
	assert_true(BotLocomotion.cut_off_for_good(8.0, 30.0, 0.0, false, cs, cm), "8 s, 30 m away, nothing joins them")
	assert_false(BotLocomotion.cut_off_for_good(20.0, 6.0, 0.0, false, cs, cm), "6 m away across the fence: wait there, they are right here")
	assert_true(BotLocomotion.cut_off_for_good(20.0, 2.0, 3.5, false, cs, cm), "a storey apart with no way up")
	assert_false(BotLocomotion.cut_off_for_good(60.0, 12.0, 6.0, true, cs, cm), "the leader is up the tower's ladder: a bot waits under it, it doesn't appear on the deck")


# ---------------------------------------------------------------- the ladder's end

func test_the_ladder_ends_for_a_watched_bot_too() -> void:
	var st: Dictionary = loco_cfg["stuck"]
	assert_eq([float(st["repath_s"]), float(st["nudge_s"]), float(st["teleport_s"])], [2.0, 4.0, 8.0], "the old steps stand")
	var g: float = float(st["giveup_after_nudge_s"])
	var sn: float = float(st["teleport_seen_after_nudge_s"])
	var an: float = float(st["teleport_any_after_nudge_s"])
	assert_eq([g, sn, an], [6.0, 16.0, 36.0], "from the first nudge (4 s in): told at 10 s, moved in view at 20 s, moved whoever looks at 40 s")
	assert_gt(float(st["nudge_s"]) + g, float(st["teleport_s"]), "the brain is told after the unseen teleport had its chance")
	assert_eq(BotLocomotion.long_stuck_stage(5.9, g, sn, an), 0)
	assert_eq(BotLocomotion.long_stuck_stage(6.0, g, sn, an), 1, "tell the brain")
	assert_eq(BotLocomotion.long_stuck_stage(15.9, g, sn, an), 1, "no watched teleport before 16 s of it")
	assert_eq(BotLocomotion.long_stuck_stage(16.0, g, sn, an), 2, "the bot may be in view; the spot may not")
	assert_eq(BotLocomotion.long_stuck_stage(36.0, g, sn, an), 3, "whoever looks")
	assert_lt(float(st["giveup_no_way_s"]), float(st["nudge_s"]), "a goal with no way is given up before the body would start wriggling")
	# the count only ends on real headway: the nudges' own wandering (a few metres round the fence) doesn't end it
	var em: float = float(st["escape_m"])
	assert_false(BotLocomotion.ladder_escaped(3.5, -1.0, em), "3.5 m along the fence, the goal no nearer")
	assert_false(BotLocomotion.ladder_escaped(6.9, 1.0, em), "wandered 7 m off without gaining on the goal: still the same trouble")
	assert_true(BotLocomotion.ladder_escaped(2.0, 4.2, em), "4 m nearer the goal")
	assert_true(BotLocomotion.ladder_escaped(8.5, 0.0, em), "8 m from the spot: it is walking")


# ---------------------------------------------------------------- a fair path to a spot in a fight

func test_a_spot_behind_the_wall_is_not_five_metres_away() -> void:
	var spot: Vector3 = Vector3(28.7, 0.3, 5.8)   # east of the taproom's east wall: the retreat spot a bot stood facing
	var round_it: PackedVector3Array = _path([Vector3(22.1, 0.3, 7.9), Vector3(22.1, 0.3, 0.5), Vector3(30.0, 0.3, -2.0), Vector3(28.7, 0.3, 5.8)])
	assert_false(BotBrain.path_fair(round_it, spot, 6.9), "24 m of walking to a spot 6.9 m off")
	assert_false(BotBrain.path_fair(PackedVector3Array(), spot, 6.9), "no path (a shut door on the way)")
	assert_false(BotBrain.path_fair(_path([Vector3(22.1, 0.3, 7.9), Vector3(23.4, 0.3, 6.5)]), spot, 6.9), "the path stops at the wall")
	var dogleg: PackedVector3Array = _path([Vector3(22.1, 0.3, 7.9), Vector3(20.0, 0.3, 4.0), Vector3(16.0, 0.3, 3.0)])
	assert_true(BotBrain.path_fair(dogleg, Vector3(16.0, 0.3, 3.0), 7.8), "round a table: 8.6 m for 7.8 m")
	assert_false(BotBrain.path_fair(_path([Vector3(8, 0.3, 10), Vector3(3.6, 0.3, 14.7)]), Vector3(3.6, 3.8, 14.7), 6.4), "ends under the spot, a floor below")


# ---------------------------------------------------------------- the map's edge (Map 0's spawn pockets)

func test_a_path_stops_short_of_the_edge_gate() -> void:
	# the south edge gate at z 65.3: a path from z 60 toward a pocket point at z 69 is cut 0.7 m before the gate
	var stop: Vector3 = BotLocomotion.edge_stop(Vector3(2.7, 0.3, 60.0), Vector3(2.7, 0.3, 65.3), 0.7)
	assert_almost_eq(stop.z, 64.6, 0.001)
	assert_eq(BotLocomotion.edge_stop(Vector3(2.7, 0.3, 65.0), Vector3(2.7, 0.3, 65.3), 0.7), Vector3(2.7, 0.3, 65.0), "already nearer than that: it stays where it is")
	# the cut path does not reach a goal in the pocket, so the layer reports no way and nothing teleports along it
	var cut: PackedVector3Array = _path([Vector3(2.7, 0.3, 60.0), stop])
	assert_false(BotLocomotion.path_reaches(cut, Vector3(2.7, 0.3, 69.0)), "4.4 m short of the pocket point")
	assert_false(BotBrain.path_fair(cut, Vector3(2.7, 0.3, 69.0), 9.0), "not a spot to retreat to either")


func test_cut_at_edge_leaves_short_paths_alone() -> void:
	assert_eq(BotLocomotion.cut_at_edge(null, _path([Vector3.ZERO, Vector3(1, 0, 0)])).size(), 2, "no body to ask the world with: the path as it is")
	assert_eq(BotLocomotion.cut_at_edge(null, PackedVector3Array()).size(), 0)
