extends GutTest
## T-265 (the scripts' cost per tick): the pure rules behind the pass. What the local camera does not see is
## animated at a quarter of the rate with the skipped time handed on; looks that need not happen every tick happen
## at a named rate and count the time between them.


func after_each() -> void:
	Zombie.view_lod = true


# ------------------------------------------------------------------ the view cone

func test_the_view_cone_holds_the_screens_corner_and_a_margin() -> void:
	# 75 degrees of vertical field at 16:9: the corner is 57.4 degrees off the axis, the cone 10 degrees wider
	var c: float = Zombie.view_cone_cos(75.0, 16.0 / 9.0)
	assert_almost_eq(rad_to_deg(acos(c)), 57.4 + rad_to_deg(Zombie.VIEW_MARGIN_RAD), 0.3)
	assert_lt(Zombie.view_cone_cos(110.0, 21.0 / 9.0), Zombie.view_cone_cos(75.0, 16.0 / 9.0), "a wider picture, a wider cone")
	assert_gt(Zombie.view_cone_cos(170.0, 3.0), 0.0, "never as wide as the half space: what is behind is always out of view")


func test_out_of_view_is_outside_the_cone_and_not_near() -> void:
	var fwd: Vector3 = Vector3.FORWARD
	var cone: float = Zombie.view_cone_cos(75.0, 16.0 / 9.0)
	assert_false(Zombie.out_of_view(Vector3(0, 0, -10), fwd, cone), "straight ahead")
	assert_false(Zombie.out_of_view(Vector3(10, 0, -10), fwd, cone), "45 degrees off: on screen")
	assert_false(Zombie.out_of_view(Vector3(17.5, 0, -10), fwd, cone), "60 degrees off: past the edge, inside the margin")
	assert_true(Zombie.out_of_view(Vector3(40, 0, -10), fwd, cone), "76 degrees off: out")
	assert_true(Zombie.out_of_view(Vector3(0, 0, 10), fwd, cone), "behind")
	assert_false(Zombie.out_of_view(Vector3(0, 0, 2.5), fwd, cone), "behind but within VIEW_NEAR_M: its shadow, the screen's edge")
	assert_true(Zombie.out_of_view(Vector3(0, 0, 3.5), fwd, cone))


func test_the_animation_rate_by_distance_and_view() -> void:
	assert_eq(Zombie.anim_div(10.0 * 10.0, 15.0, 35.0, false), 1, "near and seen: every frame")
	assert_eq(Zombie.anim_div(20.0 * 20.0, 15.0, 35.0, false), 2)
	assert_eq(Zombie.anim_div(40.0 * 40.0, 15.0, 35.0, false), 4)
	assert_eq(Zombie.anim_div(10.0 * 10.0, 15.0, 35.0, true), Zombie.VIEW_OUT_DIV, "near and not seen: every 4th frame")
	assert_eq(Zombie.anim_div(40.0 * 40.0, 15.0, 35.0, true), 4)



# ------------------------------------------------------------------ rates

func test_the_named_rates() -> void:
	assert_eq(BotLocomotion.NAV_LOOK_S, 0.2, "a walking bot asks the navmesh under it five times a second")
	assert_eq(Zombie.VIEW_OUT_DIV, 4)
