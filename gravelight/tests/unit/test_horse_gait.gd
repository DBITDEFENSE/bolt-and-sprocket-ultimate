extends GutTest
## T-240: the horse's gaits (HorseGait) and the rideable horse's rules (HorseRules, data/gravelight/horse.json) as pure
## logic: the walk is four-beat with never fewer than two feet down, the trot two-beat on diagonal pairs with a
## suspension, the gallop four-beat with all four feet off the ground once a stride; a hoof on the ground travels back
## at the body's speed (no sliding); the pace answers forward / back / nothing; the turn is an animal's (it lags, a
## gallop turns wide and slows in a hard turn); the rider shoots at every gait (T-262: the gallop sways and spreads the most, the hands on the reins until the gun is
## wanted); the tack (T-262: three pieces, their prices and order, who may buy and when, what each changes); a crowd and a boss cap
## the pace; a trample needs speed and has a cooldown; the horse stands only in its zones; bots never mount; the map's
## "horses" rows are well formed; and the model builds with every bone weighted.

const G := HorseGait.Gait


func _ride() -> Dictionary:
	return HorseRules.block("ride")


func test_gait_for_speed_with_hysteresis() -> void:
	assert_eq(HorseGait.gait_for(0.0), G.STAND, "still: standing")
	assert_eq(HorseGait.gait_for(1.9), G.WALK, "1.9 m/s: a walk")
	assert_eq(HorseGait.gait_for(4.6, G.WALK), G.TROT, "4.6 m/s: a trot")
	assert_eq(HorseGait.gait_for(9.5, G.TROT), G.GALLOP, "9.5 m/s: a gallop")
	assert_eq(HorseGait.gait_for(2.7, G.WALK), G.WALK, "just over the border a walk is kept")
	assert_eq(HorseGait.gait_for(2.5, G.TROT), G.TROT, "just under it a trot is kept")
	assert_eq(HorseGait.gait_for(2.0, G.TROT), G.WALK, "well under it the trot falls to a walk")
	assert_eq(HorseGait.gait_for(0.02, G.WALK), G.STAND, "almost still: it stands")
	assert_eq(HorseGait.gait_for(-1.0), G.WALK, "backing up is a walk")


func test_walk_is_four_beat_with_feet_down() -> void:
	assert_eq(HorseGait.beats(G.WALK).size(), 4, "four footfalls a stride")
	for i: int in 100:
		assert_gte(HorseGait.feet_down(G.WALK, float(i) / 100.0), 2, "never fewer than two feet down at a walk (phase %.2f)" % (float(i) / 100.0))
	assert_false(HorseGait.has_suspension(G.WALK), "a walk has no suspension")
	# lateral sequence: left hind, left fore, right hind, right fore
	var o: Array = HorseGait.OFFSETS[G.WALK]
	assert_true(float(o[HorseGait.LH]) < float(o[HorseGait.LF]) and float(o[HorseGait.LF]) < float(o[HorseGait.RH]) and float(o[HorseGait.RH]) < float(o[HorseGait.RF]), "LH, LF, RH, RF")


func test_trot_is_two_beat_diagonal_with_suspension() -> void:
	assert_eq(HorseGait.beats(G.TROT).size(), 2, "two beats a stride")
	var o: Array = HorseGait.OFFSETS[G.TROT]
	assert_eq(float(o[HorseGait.LH]), float(o[HorseGait.RF]), "left hind lands with right fore")
	assert_eq(float(o[HorseGait.RH]), float(o[HorseGait.LF]), "right hind lands with left fore")
	assert_true(HorseGait.has_suspension(G.TROT), "a trot leaves the ground between its beats")
	for i: int in 100:
		var n: int = HorseGait.feet_down(G.TROT, float(i) / 100.0)
		assert_true(n == 0 or n == 2, "a trot has two feet down or none (phase %.2f: %d)" % [float(i) / 100.0, n])


func test_gallop_is_four_beat_with_suspension() -> void:
	assert_eq(HorseGait.beats(G.GALLOP).size(), 4, "four footfalls a stride")
	assert_true(HorseGait.has_suspension(G.GALLOP), "a gallop has its suspension")
	var air: int = 0
	for i: int in 100:
		if HorseGait.feet_down(G.GALLOP, float(i) / 100.0) == 0:
			air += 1
	assert_between(air, 15, 40, "about a fifth to a third of the stride in the air (%d%%)" % air)
	assert_false(HorseGait.has_suspension(G.STAND), "standing: four feet down")
	assert_eq(HorseGait.feet_down(G.STAND, 0.3), 4)


func test_a_planted_hoof_does_not_slide() -> void:
	for g: int in [G.WALK, G.TROT, G.GALLOP]:
		var speed: float = float((HorseGait.SPEEDS[g] as Array)[1])
		var hz: float = HorseGait.stride_hz(g, speed)
		var d: float = HorseGait.duty(g)
		# through the stance the hoof goes back (in +Z) by speed x time: the ground under it stands still
		var a: Vector3 = HorseGait.hoof_offset(g, HorseGait.LH, 0.1 * d, speed)
		var b: Vector3 = HorseGait.hoof_offset(g, HorseGait.LH, 0.9 * d, speed)
		assert_almost_eq(b.z - a.z, speed * (0.8 * d) / hz, 0.001, "%s: the planted hoof travels back at the body's speed" % HorseGait.gait_name(g))
		assert_eq(a.y, 0.0, "%s: a planted hoof is on the ground" % HorseGait.gait_name(g))
		var mid: Vector3 = HorseGait.hoof_offset(g, HorseGait.LF, fposmod(float((HorseGait.OFFSETS[g] as Array)[HorseGait.LF]) + d + (1.0 - d) * 0.5, 1.0), speed)
		assert_gt(mid.y, 0.05, "%s: a swinging hoof is lifted" % HorseGait.gait_name(g))
		assert_almost_eq(HorseGait.stride_length(g, speed), speed / hz, 0.001)
	assert_gt(HorseGait.stride_length(G.GALLOP, 9.5), HorseGait.stride_length(G.TROT, 4.6), "a gallop's stride is longer than a trot's")


func test_landings_between_phases() -> void:
	var l: PackedInt32Array = HorseGait.landings(G.WALK, 0.2, 0.3)
	assert_eq(Array(l), [HorseGait.LF], "the left fore lands at 0.25")
	l = HorseGait.landings(G.TROT, 0.95, 0.05)
	assert_eq(l.size(), 2, "across the wrap a trot lands a diagonal pair")
	assert_eq(HorseGait.landings(G.STAND, 0.0, 0.9).size(), 0, "standing: no footfalls")
	var total: int = 0
	var ph: float = 0.0
	for i: int in 50:
		var nx: float = fposmod(ph + 0.02, 1.0)
		total += HorseGait.landings(G.GALLOP, ph, nx).size()
		ph = nx
	assert_eq(total, 4, "one stride of gallop: four footfalls, none lost at the wrap")


func test_the_body_rides_the_gait() -> void:
	var lo: float = INF
	var hi: float = -INF
	for i: int in 100:
		lo = minf(lo, HorseGait.body_bob(G.TROT, float(i) / 100.0))
		hi = maxf(hi, HorseGait.body_bob(G.TROT, float(i) / 100.0))
	assert_gt(hi - lo, 0.05, "the trot bounces")
	assert_almost_eq(HorseGait.body_bob(G.TROT, 0.1), HorseGait.body_bob(G.TROT, 0.6), 0.0001, "twice a stride")
	assert_ne(HorseGait.body_pitch(G.GALLOP, 0.2), HorseGait.body_pitch(G.GALLOP, 0.7), "the gallop rocks")
	assert_ne(HorseGait.head_nod(G.WALK, 0.1), HorseGait.head_nod(G.WALK, 0.35), "the head nods at a walk")
	assert_eq(HorseGait.saddle_motion(G.STAND, 0.4), Vector3.ZERO, "standing: a still saddle")


func test_pace_answers_the_rider() -> void:
	var r: Dictionary = _ride()
	var p: float = 0.0
	for i: int in 60:
		p = HorseRules.pace_step(p, 1.0, false, 1.0 / 60.0, r)
	assert_almost_eq(p, float(r["urge_per_s"]), 0.01, "a second of forward: one urge")
	var t: float = 0.0
	while p < 3.0 and t < 20.0:
		p = HorseRules.pace_step(p, 1.0, false, 1.0 / 60.0, r)
		t += 1.0 / 60.0
	assert_between(t, 1.5, 4.0, "held forward it reaches a gallop in a few seconds (%.1f s more)" % t)
	assert_eq(HorseRules.pace_step(3.0, 1.0, true, 1.0, r), 3.0, "never past a gallop")
	var eased: float = 3.0
	for i: int in 60 * 20:
		eased = HorseRules.pace_step(eased, 0.0, false, 1.0 / 60.0, r)
	assert_almost_eq(eased, float(r["ease_floor"]), 0.001, "left alone it eases back to a walk, not to a stand")
	var reined: float = 3.0
	for i: int in 60 * 2:
		reined = HorseRules.pace_step(reined, -1.0, false, 1.0 / 60.0, r)
	assert_eq(reined, 0.0, "two seconds of back: stopped")
	assert_lte(HorseRules.pace_step(3.0, 1.0, false, 0.1, r, 1.5), 1.5, "a cap holds the pace down")
	assert_almost_eq(HorseRules.pace_speed(1.0, r), float(r["walk_speed"]), 0.001)
	assert_almost_eq(HorseRules.pace_speed(2.0, r), float(r["trot_speed"]), 0.001)
	assert_almost_eq(HorseRules.pace_speed(3.0, r), float(r["gallop_speed"]), 0.001)
	assert_gt(float(r["gallop_speed"]), float(GLData.table("player")["sprint_speed"]), "a gallop outruns a sprint")
	assert_lt(float(r["walk_speed"]), float(GLData.table("player")["walk_speed"]), "a horse's walk is slower than a man's")


func test_speed_and_turn_are_an_animals() -> void:
	var r: Dictionary = _ride()
	assert_almost_eq(HorseRules.speed_step(0.0, 9.5, false, 1.0, r), float(r["accel"]), 0.001, "it gathers speed at its own rate")
	assert_gt(4.0 - HorseRules.speed_step(4.0, 0.0, true, 0.1, r), 4.0 - HorseRules.speed_step(4.0, 0.0, false, 0.1, r), "reining in stops it harder than letting it slow")
	assert_gt(HorseRules.turn_rate(0.0, r), HorseRules.turn_rate(9.5, r), "it turns tighter standing than at a gallop")
	var radius: float = HorseRules.turn_speed_cap(1.0, r) / HorseRules.turn_rate(HorseRules.turn_speed_cap(1.0, r), r)
	assert_between(radius, 4.0, 7.0, "a gallop's tightest circle fits the yard's 14 m (radius %.1f m)" % radius)
	assert_lt(HorseRules.turn_speed_cap(1.0, r), float(r["gallop_speed"]), "a hard turn brings a gallop down")
	assert_almost_eq(HorseRules.turn_speed_cap(0.0, r), float(r["gallop_speed"]), 0.001, "straight on it does not")
	var s: float = HorseRules.steer_step(0.0, 1.0, 1.0 / 60.0, r)
	assert_between(s, 0.01, 0.2, "the turn lags the rein (%.2f after one frame)" % s)
	for i: int in 120:
		s = HorseRules.steer_step(s, 1.0, 1.0 / 60.0, r)
	assert_gt(s, 0.98, "and gets there")


func test_fire_from_the_saddle() -> void:
	var f: Dictionary = HorseRules.block("fire")
	assert_true(HorseRules.can_fire(G.STAND, true, f), "seated at a stand")
	assert_true(HorseRules.can_fire(G.WALK, true, f), "at a walk")
	assert_true(HorseRules.can_fire(G.TROT, true, f), "at a trot")
	assert_true(HorseRules.can_fire(G.GALLOP, true, f), "T-262: at a gallop too")
	assert_false(HorseRules.can_fire(G.GALLOP, true, {"max_gait": 2}), "a table may still keep the gallop for the reins")
	assert_false(HorseRules.can_fire(G.WALK, false, f), "not while getting up or down")
	assert_false(HorseRules.can_fire(G.GALLOP, false, f), "nor at a gallop")
	assert_gt(HorseRules.fire_sway(G.TROT, f), HorseRules.fire_sway(G.WALK, f), "a trot sways the aim more than a walk")
	# T-262: the gallop is the hardest gait to shoot from, not a free pass
	assert_gt(HorseRules.fire_sway(G.GALLOP, f), HorseRules.fire_sway(G.TROT, f) * 1.3, "a gallop sways it well over a trot (%.2f vs %.2f)" % [HorseRules.fire_sway(G.GALLOP, f), HorseRules.fire_sway(G.TROT, f)])
	assert_gt(HorseRules.fire_spread(G.GALLOP, 0.0, f), HorseRules.fire_spread(G.TROT, 0.0, f) + 1.0, "and opens the cone (%.1f deg from the hip)" % HorseRules.fire_spread(G.GALLOP, 0.0, f))
	assert_eq(HorseRules.fire_spread(G.STAND, 0.0, f), 0.0, "a standing horse adds nothing")
	assert_eq(HorseRules.fire_spread(G.TROT, 0.0, f), 0.0, "the trot's cone is as it was (T-240)")
	assert_between(HorseRules.fire_spread(G.GALLOP, 0.0, f), 1.5, 4.0, "the gallop's cone is a handicap, not a wall (a sprinting-fire penalty is 4)")
	assert_lt(HorseRules.fire_spread(G.GALLOP, 1.0, f), HorseRules.fire_spread(G.GALLOP, 0.0, f), "aiming down the sights takes some of it back")
	assert_gt(HorseRules.fire_spread(G.GALLOP, 1.0, f), 0.0, "not all of it")
	assert_almost_eq(HorseRules.fire_spread(G.GALLOP, 0.5, f), (HorseRules.fire_spread(G.GALLOP, 0.0, f) + HorseRules.fire_spread(G.GALLOP, 1.0, f)) * 0.5, 0.0001, "and comes in with the aim")
	assert_eq(HorseRules.view_rock(0.0, f), float(f["view_rock"]), "from the hip the saddle's rock reaches the view whole")
	assert_lt(HorseRules.view_rock(1.0, f), HorseRules.view_rock(0.0, f) * 0.8, "aiming, the rider takes some of the stride in the knees")
	assert_gt(HorseRules.view_rock(1.0, f), 0.2, "not all of it")
	# the reins: at a gallop the hands are on them until the weapon is wanted, and go back a moment after
	var after: float = float(f["reins_after_s"])
	assert_true(HorseRules.on_reins(G.GALLOP, false, 99.0, f), "galloping with the gun idle: hands on the reins")
	assert_false(HorseRules.on_reins(G.GALLOP, true, 99.0, f), "the trigger, the sights or a reload brings the gun up")
	assert_false(HorseRules.on_reins(G.GALLOP, false, after * 0.5, f), "it stays up between shots")
	assert_true(HorseRules.on_reins(G.GALLOP, false, after + 0.01, f), "and goes back after %.1f s" % after)
	assert_between(after, 0.8, 4.0, "long enough to keep shooting, short enough to see the reins again")
	for g: int in [G.STAND, G.WALK, G.TROT]:
		assert_false(HorseRules.on_reins(g, false, 99.0, f), "below a gallop the gun is always up (%s)" % HorseGait.gait_name(g))


func test_tack_rows_prices_and_order() -> void:
	var rows: Array = HorseRules.upgrade_rows()
	assert_eq(rows.size(), 3, "three pieces of tack")
	var ids: Array = []
	var last: int = 0
	var total: int = 0
	for row: Dictionary in rows:
		for k: String in ["id", "name", "cost", "desc"]:
			assert_true(row.has(k) and str(row[k]) != "", "%s has %s" % [str(row.get("id", "?")), k])
		ids.append(str(row["id"]))
		assert_gt(int(row["cost"]), last, "each piece costs more than the one before (%s %d)" % [row["id"], int(row["cost"])])
		last = int(row["cost"])
		total += last
		assert_between(int(row["cost"]), 1000, 4000, "priced like a perk bottle (%s)" % row["id"])
		assert_eq(HorseRules.upgrade_cost(str(row["id"])), int(row["cost"]))
		assert_false((row.get("mul", {}) as Dictionary).is_empty() and (row.get("add", {}) as Dictionary).is_empty(), "%s changes something" % row["id"])
		# every key it changes exists in the table (a typo would change nothing)
		for op: String in ["mul", "add"]:
			for path: String in (row.get(op, {}) as Dictionary).keys():
				var parts: PackedStringArray = path.split(".")
				assert_true(parts.size() == 2 and HorseRules.block(parts[0]).has(parts[1]), "%s: %s is a key of the table" % [row["id"], path])
	assert_eq(ids, ["shoes", "saddle", "barding"], "sold in this order")
	assert_between(total, 4000, 8000, "the whole set costs about two perks (%d)" % total)
	assert_eq(HorseRules.upgrade_cost("no_such"), 0)
	assert_true(HorseRules.upgrade("no_such").is_empty())
	assert_true(HorseRules.block("tack").has("offset"), "the tack chest has its place at the rail")


func test_tack_who_may_buy_and_when() -> void:
	assert_eq(HorseRules.next_upgrade([]), "shoes", "the first piece on sale")
	assert_eq(HorseRules.next_upgrade(["shoes"]), "saddle")
	assert_eq(HorseRules.next_upgrade(["shoes", "saddle"]), "barding")
	assert_eq(HorseRules.next_upgrade(["shoes", "saddle", "barding"]), "", "then nothing is left")
	#                              owned  id       alive downed bot   carried tied
	assert_true(HorseRules.may_buy([], "shoes", true, false, false, false, true), "a live human on foot, the horse tied")
	assert_false(HorseRules.may_buy([], "shoes", true, false, true, false, true), "never a bot")
	assert_false(HorseRules.may_buy([], "shoes", true, true, false, false, true), "not downed")
	assert_false(HorseRules.may_buy([], "shoes", false, false, false, false, true), "not dead")
	assert_false(HorseRules.may_buy([], "shoes", true, false, false, true, true), "not from the saddle, a ladder or a line")
	assert_false(HorseRules.may_buy([], "shoes", true, false, false, false, false), "not while the horse is away from its rail")
	assert_false(HorseRules.may_buy([], "barding", true, false, false, false, true), "one piece at a time, in order")
	assert_false(HorseRules.may_buy(["shoes"], "shoes", true, false, false, false, true), "never the same piece twice")
	assert_true(HorseRules.may_buy(["shoes"], "saddle", true, false, false, false, true))
	assert_false(HorseRules.may_buy(["shoes", "saddle", "barding"], "", true, false, false, false, true), "nothing left to buy")
	assert_false(HorseRules.may_buy([], "no_such", true, false, false, false, true))
	# what a peer is sent is cleaned: known ids, once each, in the rows' order
	assert_eq(HorseRules.clean_owned(["barding", "junk", "shoes", "shoes", 7]), ["shoes", "barding"])
	assert_eq(HorseRules.clean_owned([]), [])
	assert_eq(HorseRules.tack_names([]), "")
	assert_eq(HorseRules.tack_names(["saddle", "shoes"]), "Studded Shoes, Trooper's Saddle")


func test_tack_effects() -> void:
	var base: Dictionary = HorseRules.table()
	assert_true(is_same(HorseRules.upgraded([]), base), "no tack: the table itself")
	var r0: Dictionary = base["ride"]
	var f0: Dictionary = base["fire"]
	var t0: Dictionary = base["trample"]
	var c0: Dictionary = base["crowd"]
	var bf: Dictionary = base["boss_fear"]
	# ---- shoes: faster, tighter
	var shod: Dictionary = HorseRules.upgraded(["shoes"])
	var r1: Dictionary = shod["ride"]
	assert_between(float(r1["gallop_speed"]), float(r0["gallop_speed"]) * 1.05, float(r0["gallop_speed"]) * 1.25, "shod: a faster gallop (%.2f from %.2f m/s)" % [float(r1["gallop_speed"]), float(r0["gallop_speed"])])
	assert_eq(float(r1["trot_speed"]), float(r0["trot_speed"]), "the trot and the walk are as they were")
	assert_eq(float(r1["walk_speed"]), float(r0["walk_speed"]))
	for i: int in 4:
		assert_gt(float((r1["turn_rate"] as Array)[i]), float((r0["turn_rate"] as Array)[i]), "it turns faster at every gait (%d)" % i)
	assert_gt(HorseRules.turn_rate(float(r1["gallop_speed"]), r1), HorseRules.turn_rate(float(r0["gallop_speed"]), r0))
	var circle0: float = HorseRules.turn_speed_cap(1.0, r0) / HorseRules.turn_rate(HorseRules.turn_speed_cap(1.0, r0), r0)
	var circle1: float = HorseRules.turn_speed_cap(1.0, r1) / HorseRules.turn_rate(HorseRules.turn_speed_cap(1.0, r1), r1)
	assert_lte(circle1, circle0, "and its hard turn at a gallop is no wider, so it still fits the yard (radius %.2f from %.2f m)" % [circle1, circle0])
	assert_gt(HorseRules.pace_speed(3.0, r1), HorseRules.pace_speed(3.0, r0))
	assert_eq(HorseRules.pace_speed(2.0, r1), HorseRules.pace_speed(2.0, r0))
	assert_eq(float((shod["fire"] as Dictionary)["sway_gallop"]), float(f0["sway_gallop"]), "shoes do nothing for the aim")
	assert_eq(float((shod["trample"] as Dictionary)["damage"]), float(t0["damage"]), "nor for the trample")
	# the table itself is never written to
	assert_eq(float(HorseRules.block("ride")["gallop_speed"]), float(r0["gallop_speed"]))
	assert_eq(float(GLData.load_json(HorseRules.PATH)["ride"]["gallop_speed"]), float(r0["gallop_speed"]), "the base table is untouched")
	# ---- saddle: steadier
	var f1: Dictionary = HorseRules.upgraded(["shoes", "saddle"])["fire"]
	for g: int in [G.WALK, G.TROT, G.GALLOP]:
		assert_lt(HorseRules.fire_sway(g, f1), HorseRules.fire_sway(g, f0), "the saddle steadies the %s" % HorseGait.gait_name(g))
	assert_lt(HorseRules.fire_spread(G.GALLOP, 0.0, f1), HorseRules.fire_spread(G.GALLOP, 0.0, f0), "and closes the gallop's cone (%.1f from %.1f deg)" % [HorseRules.fire_spread(G.GALLOP, 0.0, f1), HorseRules.fire_spread(G.GALLOP, 0.0, f0)])
	assert_gt(HorseRules.fire_spread(G.GALLOP, 0.0, f1), 0.5, "a gallop is still a gallop")
	assert_gt(HorseRules.fire_sway(G.GALLOP, f1), HorseRules.fire_sway(G.TROT, f1), "and still sways more than a trot")
	assert_lt(float(f1["view_rock"]), float(f0["view_rock"]), "the view rocks less")
	assert_eq(int(f1["max_gait"]), int(f0["max_gait"]))
	assert_eq(int(f1["reins_gait"]), int(f0["reins_gait"]))
	# ---- barding: a harder trample, a steadier horse in a crowd
	var all: Dictionary = HorseRules.upgraded(["shoes", "saddle", "barding"])
	var t1: Dictionary = all["trample"]
	var c1: Dictionary = all["crowd"]
	var hit0: Dictionary = HorseRules.trample(9.5, 0.0, t0)
	var hit1: Dictionary = HorseRules.trample(9.5, 0.0, t1)
	assert_gt(float(hit1["damage"]), float(hit0["damage"]) * 1.5, "barded: a harder trample (%d from %d)" % [int(hit1["damage"]), int(hit0["damage"])])
	assert_lt(float(hit1["slow"]), float(hit0["slow"]), "that costs the horse less of its speed")
	assert_lt(float(t1["cooldown"]), float(t0["cooldown"]))
	assert_gt(float(t1["cooldown"]), 0.3, "still one at a time")
	assert_eq(float(t1["speed_min"]), float(t0["speed_min"]), "and still only at a gallop")
	var z20: int = RoundManager.zombie_health(20, GLData.table("rounds"))
	assert_lt(float(hit1["damage"]), float(z20) * 0.1, "still not a win button: under a tenth of a round-20 zombie's health (%d of %d)" % [int(hit1["damage"]), z20])
	assert_eq(HorseRules.pace_cap(3, INF, c1, bf), 3.0, "three of the dead no longer cost it its gallop")
	assert_lt(HorseRules.pace_cap(3, INF, c0, bf), 3.0)
	assert_lt(HorseRules.pace_cap(8, INF, c1, bf), 3.0, "a real crowd still does")
	assert_gt(HorseRules.pace_cap(20, INF, c1, bf), HorseRules.pace_cap(20, INF, c0, bf), "and it pushes through one faster")
	assert_lt(HorseRules.shy_level(3, INF, c1, bf), 1.0, "it no longer shies at three")
	assert_eq(HorseRules.shy_level(3, INF, c0, bf), 1.0)
	assert_eq(HorseRules.shy_level(int(c1["shy_at"]), INF, c1, bf), 1.0, "it still shies, later")
	assert_lte(HorseRules.pace_cap(0, 5.0, c1, bf), 1.0, "a boss still frightens it to a walk")
	assert_eq(float((all["boss_fear"] as Dictionary)["radius"]), float(bf["radius"]))
	# all three stack: each block has its own piece's change
	assert_eq(float((all["ride"] as Dictionary)["gallop_speed"]), float(r1["gallop_speed"]))
	assert_eq(float((all["fire"] as Dictionary)["sway_gallop"]), float(f1["sway_gallop"]))
	# an unknown id or key changes nothing
	assert_eq(float(HorseRules.upgraded(["no_such"])["ride"]["gallop_speed"]), float(r0["gallop_speed"]))
	var odd: Dictionary = {"ride": {"gallop_speed": 9.5}, "upgrades": [{"id": "x", "mul": {"ride.nope": 2.0, "nope.gallop_speed": 2.0, "ride": 2.0}, "add": {"ride.gallop_speed": 1.0}}]}
	var odd_out: Dictionary = HorseRules.upgraded(["x"], odd)
	assert_eq((odd_out["ride"] as Dictionary).size(), 1, "a key the table lacks is not made up")
	assert_eq(float(odd_out["ride"]["gallop_speed"]), 10.5, "add adds")
	assert_eq(float(odd["ride"]["gallop_speed"]), 9.5, "the table handed in is not written to")


func test_crowd_boss_and_trample() -> void:
	var c: Dictionary = HorseRules.block("crowd")
	var bf: Dictionary = HorseRules.block("boss_fear")
	var t: Dictionary = HorseRules.block("trample")
	assert_eq(HorseRules.pace_cap(0, INF, c, bf), 3.0, "alone: any pace")
	assert_lt(HorseRules.pace_cap(3, INF, c, bf), 3.0, "crowded: no gallop")
	assert_gte(HorseRules.pace_cap(20, INF, c, bf), float(c["min_pace"]), "however many, it still goes")
	assert_lte(HorseRules.pace_cap(0, 5.0, c, bf), 1.0, "near a boss: a walk at most")
	assert_eq(HorseRules.shy_level(0, INF, c, bf), 0.0)
	assert_eq(HorseRules.shy_level(int(c["shy_at"]), INF, c, bf), 1.0, "it shies at a crowd")
	assert_gt(HorseRules.shy_level(0, 5.0, c, bf), 0.5, "and near a boss")
	assert_true(HorseRules.trample(4.6, 0.0, t).is_empty(), "a trot flings nobody")
	assert_true(HorseRules.trample(9.5, 0.3, t).is_empty(), "nor a gallop still cooling down")
	var hit: Dictionary = HorseRules.trample(9.5, 0.0, t)
	assert_true(hit.has("damage") and hit.has("push") and float(hit["slow"]) > 0.0, "a gallop does, and costs the horse speed")
	var z20: int = RoundManager.zombie_health(20, GLData.table("rounds"))
	assert_lt(float(hit["damage"]), float(z20) * 0.1, "not a win button: under a tenth of a round-20 zombie's health (%d of %d)" % [int(hit["damage"]), z20])
	assert_gt(float(t["cooldown"]), 0.3)


func test_where_it_may_stand_and_who_may_mount() -> void:
	var b: Dictionary = HorseRules.block("bounds")
	var zones: Array = ["YARD", "GROUNDS"]
	assert_true(HorseRules.may_stand(&"YARD", true, 0.0, 0.0, zones, b), "its yard")
	assert_false(HorseRules.may_stand(&"GROUNDS", false, 0.0, 0.0, zones, b), "not a zone still shut")
	assert_false(HorseRules.may_stand(&"STABLE", true, 0.0, 0.0, zones, b), "not through the stable's door")
	assert_false(HorseRules.may_stand(&"TAPROOM", true, 0.0, 0.0, zones, b), "not the inn")
	assert_false(HorseRules.may_stand(&"", true, 0.0, 0.0, zones, b), "not off the map")
	assert_false(HorseRules.may_stand(&"YARD", true, 6.2, 0.0, zones, b), "not the tower's deck")
	assert_false(HorseRules.may_stand(&"GROUNDS", true, -3.2, 0.0, zones, b), "not down a well")
	assert_true(HorseRules.may_mount(false, true, false, false, false), "a live human on their feet")
	assert_false(HorseRules.may_mount(true, true, false, false, false), "one rider at a time")
	assert_false(HorseRules.may_mount(false, true, false, true, false), "never a bot")
	assert_false(HorseRules.may_mount(false, true, true, false, false), "not downed")
	assert_false(HorseRules.may_mount(false, false, false, false, false), "not dead")
	assert_false(HorseRules.may_mount(false, true, false, false, true), "not from a ladder or a zip line")
	var offs: Array[Vector3] = HorseRules.dismount_offsets()
	assert_gt(offs.size(), 4, "several places to get down")
	assert_lt(offs[0].x, 0.0, "the near (left) side first")
	for o: Vector3 in offs:
		assert_gt(Vector2(o.x, o.z).length(), 1.0, "clear of the horse's body")
	var h: Dictionary = HorseRules.block("home")
	assert_true(HorseRules.home_due(float(h["idle_s"]) + 1.0, 5.0, false, h), "left alone it goes home")
	assert_false(HorseRules.home_due(float(h["idle_s"]) + 1.0, 5.0, true, h), "not with a rider")
	assert_false(HorseRules.home_due(1.0, 5.0, false, h), "not at once")
	assert_false(HorseRules.home_due(999.0, 0.1, false, h), "not when it is there")
	assert_almost_eq(HorseRules.puppet_yaw(0.0, Vector3(0.1, 0, 0), 0.1), 0.0, 0.0001, "a puppet keeps its heading while the rider stands")
	assert_ne(HorseRules.puppet_yaw(0.0, Vector3(4, 0, 0), 0.1), 0.0, "and turns where the rider goes")


func test_map_rows() -> void:
	var rows: Array = GLData.load_json("res://data/gravelight/map00.json").get("horses", [])
	assert_eq(rows.size(), 1, "the Inn has one horse")
	var row: Dictionary = rows[0]
	for k: String in ["name", "pos", "yaw", "rail", "zones", "look"]:
		assert_true(row.has(k), "the row has %s" % k)
	var pos: Vector3 = ClimbLink._v3(row["pos"])
	assert_true(pos.x > 2.5 and pos.x < 33.5 and pos.z > 34.5 and pos.z < 47.5 and pos.y == 0.0, "it stands in the Carters' Yard (%s)" % str(pos))
	assert_true((row["zones"] as Array).has("YARD") and not (row["zones"] as Array).has("STABLE") and not (row["zones"] as Array).has("TAPROOM"), "its zones are outdoors")
	assert_gt(pos.distance_to(Vector3(18.6, 0, 36.2)), 4.0, "clear of the zip line's landing post")
	assert_gt(pos.distance_to(Vector3(5.4, 0, 42.6)), 8.0, "clear of the tower's ladder")
	assert_gt(absf(pos.x - 22.0), 1.6, "clear of the wall-buy chalked on the stable wall")
	assert_lt(ClimbLink._v3(row["rail"]).distance_to(pos), 2.0, "the rail is in front of it")
	for map: String in ["map01", "map02"]:
		assert_false(GLData.load_json("res://data/gravelight/%s.json" % map).has("horses"), "%s has no horse row" % map)


func test_model_builds_and_is_skinned() -> void:
	var names: Dictionary = {}
	for b: Array in HorseMesh.bones():
		assert_false(names.has(b[0]), "bone %s is listed once" % str(b[0]))
		names[b[0]] = true
	for leg: int in 4:
		var j: Array = HorseMesh.leg_joints(leg)
		assert_eq(j.size(), 6)
		assert_almost_eq((j[5] as Vector3).y, 0.0, 0.0001, "a hoof stands on the ground")
		assert_gt((j[0] as Vector3).y, 1.0, "a leg hangs from the body")
	assert_between((HorseMesh.BARREL[3] as Array)[1], 1.55, 1.65, "about 1.6 m at the withers")
	var length: float = float((HorseMesh.BARREL[HorseMesh.BARREL.size() - 1] as Array)[0]) - HorseMesh.muzzle().z
	assert_between(length, 2.2, 2.8, "about 2.4 m from the nose to the quarters (%.2f)" % length)
	for look: String in ["noriker", "dead"]:
		var m: ArrayMesh = HorseMesh.mesh(look)
		assert_gte(m.get_surface_count(), 5, "%s: surfaces for coat, hair, hooves and its gear" % look)
		var tris: int = 0
		for s: int in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var bn: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			assert_eq(w.size(), verts.size() * 4, "%s/%s: four weights a vertex" % [look, m.surface_get_name(s)])
			var bad: int = 0
			for v: int in verts.size():
				if absf(w[v * 4] + w[v * 4 + 1] + w[v * 4 + 2] + w[v * 4 + 3] - 1.0) > 0.01 or bn[v * 4] >= names.size():
					bad += 1
			assert_eq(bad, 0, "%s/%s: every vertex is weighted to real bones" % [look, m.surface_get_name(s)])
			tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_between(tris, 3000, 40000, "%s: a game model's triangle count (%d)" % [look, tris])
		var box: AABB = m.get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.03, "%s: the hooves are at the ground" % look)
		assert_between(box.size.y, 1.9, 2.5, "%s: the ears stand about 2.2 m up (%.2f)" % [look, box.size.y])
	assert_true(HorseMesh.mesh("noriker") == HorseMesh.mesh("noriker"), "a look's mesh is built once")


func test_rig_poses_every_gait_finite() -> void:
	var rig: HorseRig = HorseRig.new("noriker")
	add_child_autofree(rig)
	var landed: Array = []
	rig.hoof.connect(func(leg: int, _at: Vector3, _g: int) -> void: landed.append(leg))
	for speed: float in [0.0, 1.9, 4.6, 9.5, -1.0]:
		rig.speed = speed
		rig.turn = 0.2
		for i: int in 90:
			rig.tick(1.0 / 60.0)
		assert_eq(rig.gait, HorseGait.gait_for(speed, rig.gait), "the rig's gait follows its speed (%.1f)" % speed)
		for b: int in rig.skel.get_bone_count():
			var p: Vector3 = rig.skel.get_bone_pose_position(b)
			assert_true(p.is_finite() and p.length() < 6.0, "bone %s sits in a sane place at %.1f m/s (%s)" % [rig.skel.get_bone_name(b), speed, str(p)])
		for leg: int in 4:
			var hoof_y: float = rig.skel.get_bone_pose_position(rig.skel.find_bone("%s_D" % HorseGait.LEG_NAMES[leg])).y
			assert_gt(hoof_y, -0.05, "no fetlock under the ground at %.1f m/s" % speed)
	assert_gt(landed.size(), 8, "hooves landing are announced (%d)" % landed.size())
	for pose: String in ["rear", "kick", "collapse", "head_low", "stagger", "shy"]:
		rig.speed = 0.0
		rig.set(pose, 1.0)
		for i: int in 30:
			rig.tick(1.0 / 60.0)
		for b: int in rig.skel.get_bone_count():
			assert_true(rig.skel.get_bone_pose_position(b).is_finite(), "pose %s keeps bone %s finite" % [pose, rig.skel.get_bone_name(b)])
		rig.set(pose, 0.0)
	var seat: Transform3D = rig.seat_global()
	assert_between(seat.origin.y, 1.4, 1.8, "the saddle's seat is at the horse's back (%.2f)" % seat.origin.y)
