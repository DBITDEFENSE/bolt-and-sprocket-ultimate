extends GutTest
## The Fliegeralarm special round's rules (UPDATE 07, docs/MAP4_FERNFLUG.md §3.8): circles come only from open zones
## the players are in or next to; the blast is a flat disc near the circle's height.

const CIRCLES: Dictionary = {
	"A_SIEDLUNG": [[28.0, 0.0, 20.0]],
	"B_BAHNHOF": [[10.0, 0.0, 38.0], [30.0, 0.0, 56.0]],
	"D_KIRCHPLATZ": [[10.0, 0.0, 70.0]],
}
const ADJ: Dictionary = {"A_SIEDLUNG": ["B_BAHNHOF"], "B_BAHNHOF": ["A_SIEDLUNG", "D_KIRCHPLATZ"], "D_KIRCHPLATZ": ["B_BAHNHOF"]}


func test_pick_circle_respects_open_and_near_zones() -> void:
	assert_eq(Fliegeralarm.pick_circle(CIRCLES, ["A_SIEDLUNG"], ["A_SIEDLUNG"], ADJ, 0.0), Vector3(28, 0, 20), "only the open spawn zone's circle")
	assert_eq(Fliegeralarm.pick_circle(CIRCLES, ["A_SIEDLUNG", "B_BAHNHOF"], ["A_SIEDLUNG"], ADJ, 0.99), Vector3(30, 0, 56), "an adjacent open zone's circle is in the pool")
	assert_eq(Fliegeralarm.pick_circle(CIRCLES, ["A_SIEDLUNG", "B_BAHNHOF", "D_KIRCHPLATZ"], ["A_SIEDLUNG"], ADJ, 0.99), Vector3(30, 0, 56), "two zones away is never picked")
	assert_eq(Fliegeralarm.pick_circle(CIRCLES, [], ["A_SIEDLUNG"], ADJ, 0.5), Vector3.INF, "nothing open: no circle")
	assert_eq(Fliegeralarm.pick_circle(CIRCLES, ["D_KIRCHPLATZ"], ["A_SIEDLUNG"], ADJ, 0.5), Vector3.INF, "an open zone nobody is near: no circle")


func test_blast_is_a_flat_disc() -> void:
	var c: Vector3 = Vector3(10, 0, 38)
	assert_true(Fliegeralarm.in_blast(c, Vector3(12, 0, 38), 3.0))
	assert_false(Fliegeralarm.in_blast(c, Vector3(13.5, 0, 38), 3.0), "outside the radius")
	assert_false(Fliegeralarm.in_blast(c, Vector3(10, 4, 38), 3.0), "a catwalk above is clear")


func test_act_data_runs_on_the_bellringer_scheduler() -> void:
	var sr: Dictionary = GLData.table("rounds")["special_round"]
	assert_true(int(sr["first_min"]) >= 5 and int(sr["interval_min"]) >= 5, "every 5-7 rounds")
	var f: Dictionary = GLData.load_json("res://data/gravelight/map04a.json")["fliegeralarm"]
	assert_gt(int(f["landers_per_circle"]), 0)
	assert_true((GLData.table("anim")["kits"] as Dictionary).has(str(f["lander_kit"])), "the landers' kit exists (aircrew = the soldier kit until the art pass)")
