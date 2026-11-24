extends GutTest
## T-249: the Sherman on the Inn, rounds 30..40 (data/gravelight/sherman.json, map00.json "sherman_event",
## ShermanEvent, ShermanTank, FireZombie, FirePatch, AirRaid, StukaPlane, ShermanMesh) as pure logic and data:
## where it is on (the Inn only), the Fuhrmann resolution (round 30 has both the horse and the tank: the horse comes in
## behind the tank), the assault's size and its fire zombies spread through the wave, the tank's health and its
## attack points against the hull, a fire zombie's burst by distance, the assist's damage against the round's health,
## the raid's shelter rule (inside the inn zones or its box), its damage by distance (a full-health player survives
## one bomb that is not on top of them; nobody inside is touched), the route on the map (it parks outside the yard's
## gate, never in it), the dive bomber's pass (it releases on the dive's line above the target), the model's parts.
## T-261: the gunner's judgement (ShermanRules: what is worth a shell, what the machine gun takes, never at, near or
## across a player, the burning ones dropped far out and left alone close in, the watch, the reload), the driver's
## rules (the tracks' step, where the hull may stand on the Inn, who may climb in, the dead under the tracks, the
## dead on a driven hull), and the rig driven on a floor against a wall, its puppet and its host-side checks.


func _cfg() -> Dictionary:
	return ShermanEvent.table()


func _blk() -> Dictionary:
	return ShermanEvent.block_for(&"map00_crossroads")


func test_on_the_inn_only() -> void:
	var b: Dictionary = _blk()
	assert_false(b.is_empty(), "the Inn has the block")
	assert_eq(int(b["arrive_round"]), 30, "the Sherman comes on round 30")
	assert_eq(int(b["stuka_round"]), 40, "the dive bomber and the raid on round 40")
	for m: StringName in [&"map04a_thalbach", &"map04b_kranich", &"map04c_groomlake", &"map04d_mondlicht", &"test_range"]:
		assert_true(ShermanEvent.block_for(m).is_empty(), "%s: no Sherman" % m)
	for m2: StringName in [&"map02_totenhafen"]:   # T-271: the raid only (test_map_detail)
		assert_false(ShermanEvent.block_has_tank(ShermanEvent.block_for(m2)), "%s: no Sherman (the raid only)" % m2)
	# T-272: Kaltenbrunn has the whole event now (through the yard's north gate; test_map01_detail)
	var k1: Dictionary = ShermanEvent.block_for(&"map01_kaltenbrunn")
	assert_true(ShermanEvent.block_has_tank(k1) and int(k1["arrive_round"]) == 30 and int(k1["stuka_round"]) == 40, "Kaltenbrunn: the Sherman on 30, the dive bomber on 40")
	var c: Dictionary = _cfg()
	for k: String in ["tank", "arrival", "assault", "fire_zombie", "assist", "stuka", "raid"]:
		assert_true(c.has(k), "sherman.json has %s" % k)


func test_fuhrmann_resolution() -> void:
	# round 30 keeps der Fuhrmann (T-240) and gets the Sherman: the horse comes in behind the tank and leads the horde
	var rows: Array = HorseRound.rows_for(&"map00_crossroads")
	var r30: Dictionary = {}
	for r: Dictionary in rows:
		if int(r["round"]) == 30:
			r30 = r
	assert_eq(str(r30.get("boss", "")), "totenross_fuhrmann", "der Fuhrmann stays on round 30")
	var arr: Dictionary = r30.get("arrival", {})
	var a: Dictionary = _cfg()["arrival"]
	var route: PackedVector3Array = PackedVector3Array()
	for p: Variant in _blk()["route"]:
		route.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	var drive_s: float = ShermanEvent.route_length(route) / float(_cfg()["tank"]["drive_speed"])
	var parked_at: float = float(a["drive_at"]) + drive_s
	assert_gt(float(arr.get("spawn_at", 6.0)), parked_at - 3.0, "the horse comes in as the tank parks (%.1f s; parked by ~%.1f s)" % [float(arr.get("spawn_at", 6.0)), parked_at])
	assert_lt(float(arr.get("spawn_at", 6.0)), parked_at + float(a["assault_after_park"]) + 2.0, "and before the assault is well on")
	# T-272: on Kaltenbrunn too der Fuhrmann comes in as its tank parks (its route is longer: through the north gate)
	var k_route: PackedVector3Array = PackedVector3Array()
	for p2: Variant in ShermanEvent.block_for(&"map01_kaltenbrunn")["route"]:
		k_route.append(Vector3(float(p2[0]), float(p2[1]), float(p2[2])))
	var k_parked: float = float(a["drive_at"]) + ShermanEvent.route_length(k_route) / float(_cfg()["tank"]["drive_speed"])
	for r2: Dictionary in HorseRound.rows_for(&"map01_kaltenbrunn"):
		if int(r2["round"]) == 30:
			var k_spawn: float = float((r2.get("arrival", {}) as Dictionary).get("spawn_at", 6.0))
			assert_gt(k_spawn, k_parked - 3.0, "Kaltenbrunn: the horse comes in as the tank parks (%.1f s; parked by ~%.1f s)" % [k_spawn, k_parked])
			assert_lt(k_spawn, k_parked + float(a["assault_after_park"]) + 2.0, "Kaltenbrunn: and before the assault is well on")
		else:
			assert_false(r2.has("arrival"), "Kaltenbrunn's round-20 horse keeps the block's arrival")
	var blk: Dictionary = HorseBoss.block_of("totenross_fuhrmann")
	assert_eq(float((blk["arrival"] as Dictionary)["spawn_at"]), 6.0, "the boss block itself is unchanged")


func test_assault_numbers() -> void:
	var a: Dictionary = _cfg()["assault"]
	assert_eq(ShermanEvent.assault_count(1, a), 24, "solo: 24 of the dead")
	assert_eq(ShermanEvent.assault_count(4, a), 48, "four: 48")
	assert_eq(ShermanEvent.fire_count(24, a), 6, "a quarter of them burning")
	for total: int in [24, 32, 40, 48]:
		var fires: int = ShermanEvent.fire_count(total, a)
		var n: int = 0
		var first: int = -1
		var last: int = -1
		for i: int in total:
			if ShermanEvent.is_fire_slot(i, total, fires):
				n += 1
				if first < 0:
					first = i
				last = i
		assert_eq(n, fires, "%d: exactly %d fire zombies in the wave" % [total, fires])
		assert_lt(first, total / 2, "%d: the first one early" % total)
		assert_gt(last, total / 2, "%d: and some late (spread through the wave)" % total)
	var tk: Dictionary = _cfg()["tank"]
	assert_eq(ShermanEvent.tank_hp(1, tk), 8000.0)
	assert_almost_eq(ShermanEvent.tank_hp(4, tk), 8000.0 * 2.05, 0.1, "x(1 + 0.35 per extra player)")
	# winnable but tense: twelve of the dead on it unopposed take it in under a minute; the team has that long
	var dps: float = float(a["max_at_once"]) * float(tk["swipe_damage"]) / 1.2
	var secs: float = ShermanEvent.tank_hp(1, tk) / dps
	assert_true(secs > 20.0 and secs < 60.0, "a full crowd on it unopposed: %.0f s" % secs)
	var fz: Dictionary = _cfg()["fire_zombie"]
	assert_lt(float(fz["tank_damage"]) * 6.0, ShermanEvent.tank_hp(1, tk), "six fire zombies bursting on it do not kill it alone")
	assert_gt(float(fz["tank_damage"]) * 6.0, ShermanEvent.tank_hp(1, tk) * 0.3, "but they take a third of it")


func test_fire_zombie_burst() -> void:
	var fz: Dictionary = _cfg()["fire_zombie"]
	assert_eq(FireZombie.burst_damage(0.0, fz), 60.0, "60 at the centre")
	assert_eq(FireZombie.burst_damage(float(fz["blast_radius"]), fz), 20.0, "20 at the ring")
	assert_lt(FireZombie.burst_damage(0.0, fz), 100.0, "one burst never downs a healthy player")
	assert_gt(FireZombie.burst_damage(0.5, fz) * 2.0, 100.0, "two close ones do")
	assert_gte(float(fz["fuse_seconds"]), 0.5, "the fuse is half a second or more (a telegraph)")
	assert_true(FirePatch.inside(Vector3.ZERO, Vector3(1.5, 0.2, 1.0), 2.2))
	assert_false(FirePatch.inside(Vector3.ZERO, Vector3(2.5, 0, 0), 2.2))
	var h30: float = float(RoundManager.zombie_health(30, GLData.table("rounds")))
	assert_almost_eq(h30 * float(fz["health_mult"]), 3163.5, 1.0, "a round-30 fire zombie has under half a zombie's health")


func test_assist_damage() -> void:
	var s: Dictionary = _cfg()["assist"]
	var rounds: Dictionary = GLData.table("rounds")
	var per_burst: float = float(s["mg_burst"]) * float(s["mg_hit_chance"]) * float(s["mg_damage_frac"])
	assert_true(per_burst > 0.1 and per_burst < 0.25, "a burst takes a sixth of one of the dead (%.2f)" % per_burst)
	var cycle: float = float(s["mg_gap"]) + float(s["mg_burst"]) / float(s["mg_rate"])
	var kills_per_min: float = 60.0 / cycle * per_burst + 60.0 / float(s["gun_reload_s"]) * 1.0
	# (T-261: the 75 mm every 6.5 s, not every 11 s: the bound went from 12 to 14 with it)
	assert_lt(kills_per_min, 14.0, "at most about a dozen a minute with targets everywhere (%.1f): it helps, it does not win the round" % kills_per_min)
	assert_eq(int(_cfg()["assist"]["rounds"]), 9, "rounds 31..39")
	assert_gt(float(s["gun_damage_frac"]), 0.5, "the 75 mm kills what is at its feet")
	assert_gte(float(s["gun_player_clear_m"]), 4.0, "never near a player")
	assert_eq(RoundManager.zombie_health(35, rounds), 11322)


func test_raid_shelter_and_damage() -> void:
	var b: Dictionary = _blk()
	var zones: Array = b["shelter_zones"]
	var box: Array = b["inn_box"]
	assert_true(AirRaid.is_sheltered_at(&"TAPROOM", Vector3(12, 0, 8), zones, box), "the taproom")
	assert_true(AirRaid.is_sheltered_at(&"UPSTAIRS", Vector3(12, 3.8, 3), zones, box), "upstairs")
	assert_true(AirRaid.is_sheltered_at(&"OLD_CELLAR", Vector3(4, -3, 6), zones, box), "the cellar")
	assert_true(AirRaid.is_sheltered_at(&"", Vector3(3, 1.0, 12), zones, box), "an unzoned corner of the inn's box")
	assert_false(AirRaid.is_sheltered_at(&"YARD", Vector3(18, 0, 42), zones, box), "the yard")
	assert_false(AirRaid.is_sheltered_at(&"GROUNDS", Vector3(12, 0, 8), zones, box), "a zone that says outside wins over the box")
	assert_false(AirRaid.is_sheltered_at(&"STABLE", Vector3(15, 0, 28), zones, box), "the stable is not the house")
	assert_false(AirRaid.is_sheltered_at(&"", Vector3(5.4, 6.2, 45), zones, box), "the tower's deck")
	var r: Dictionary = _cfg()["raid"]
	assert_eq(AirRaid.bomb_damage(0.0, r), 110.0, "a bomb on top of you downs you")
	assert_eq(AirRaid.bomb_damage(float(r["radius"]), r), 30.0)
	assert_eq(AirRaid.bomb_damage(float(r["radius"]) + 0.1, r), 0.0)
	assert_lt(AirRaid.bomb_damage(1.5, r), 100.0, "a full-health player survives one that is not on top of them")
	assert_gt(AirRaid.bomb_damage(2.0, r) + AirRaid.bomb_damage(3.0, r), 100.0, "two down anyone outside")
	assert_gt(AirRaid.bomb_zombie_damage(0.0, r, 18234.0), 18234.0, "the dead under a bomb are blown apart (round 40)")
	assert_gte(float(r["countdown"]), 15.0, "time to get in before the first bomb")
	assert_gte(float(r["telegraph"]), 2.0, "each bomb shows where it lands")
	assert_true(AirRaid.in_box_grown(Vector3(24.8, 0, 8), box, 1.0), "never on the inn or a metre from it")
	assert_false(AirRaid.in_box_grown(Vector3(18, 0, 42), box, 1.0))
	assert_false((b["bomb_zones"] as Array).has("TAPROOM"))


func test_route_parks_outside_the_yard() -> void:
	var b: Dictionary = _blk()
	var r: Array = b["route"]
	assert_gte(r.size(), 3)
	var start: Array = r[0]
	assert_true(float(start[0]) > 60.0 or float(start[2]) > 64.0, "it comes from beyond the map's edge")
	var park: Array = r[r.size() - 1]
	var p: Vector3 = Vector3(float(park[0]), 0, float(park[2]))
	assert_true(p.z > 48.0 + 3.0, "it parks south of the yard's fence (z %.1f), on the road, not in the yard" % p.z)
	var yaw: float = ShermanEvent._leg_yaw(PackedVector3Array([Vector3(float(r[r.size() - 2][0]), 0, float(r[r.size() - 2][2])), p]), 0)
	var fwd: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	var to_gate: Vector3 = (Vector3(18, 0, 48) - p).normalized()
	assert_gt(fwd.dot(to_gate), 0.9, "facing the gate")
	# its hull clear of the signpost and the dead tree by the road
	for post: Vector3 in [Vector3(22.9, 0, 49.6), Vector3(31, 0, 52)]:
		var l: Vector3 = Transform3D(Basis(Vector3.UP, yaw), p).affine_inverse() * post
		assert_true(absf(l.x) > 1.31 + 0.3 or l.z < -2.97 - 0.3 or l.z > 3.05 + 0.3, "clear of %s" % str(post))
	var bar: Array = (b["barrier"] as Dictionary)["pos"]
	var bp: Vector3 = Vector3(float(bar[0]), 0, float(bar[2]))
	var best: float = INF
	for i: int in r.size() - 1:
		var a: Vector3 = Vector3(float(r[i][0]), 0, float(r[i][2]))
		var c: Vector3 = Vector3(float(r[i + 1][0]), 0, float(r[i + 1][2]))
		best = minf(best, Geometry3D.get_closest_point_to_segment(bp, a, c).distance_to(bp))
	assert_lt(best, 3.2, "it rolls over the barrier at the road's end (%.1f m)" % best)


func test_stuka_pass() -> void:
	var s: StukaPlane = StukaPlane.new()
	add_child_autofree(s)
	var tgt: Vector3 = Vector3(22.8, 1.2, 52.8)
	s.fly(tgt, Vector3(-1, 0, -1).normalized(), _cfg()["stuka"])
	var rt: float = s.release_time()
	assert_true(rt > 6.0 and rt < 20.0, "it releases %.1f s after it is first heard" % rt)
	var rel: Transform3D = s.pose_at(s.get("_release_d"))
	assert_almost_eq(rel.origin.y - tgt.y, float(_cfg()["stuka"]["release_alt"]), 2.0, "it lets go at the release altitude")
	var nose: Vector3 = -rel.basis.z
	assert_gt(rad_to_deg(asin(-nose.y)), 60.0, "diving steeply (%.0f deg)" % rad_to_deg(asin(-nose.y)))
	var aim: Vector3 = (tgt - rel.origin).normalized()
	assert_gt(nose.dot(aim), 0.98, "pointed at the target as it lets go")


func test_model_parts() -> void:
	for p: String in ["hull", "turret", "gun", "wheel", "sprocket", "idler", "roller", "link"]:
		var mk: Array = ShermanMesh.part(p)
		var m: ArrayMesh = mk[0]
		assert_gt(m.get_surface_count(), 0, "%s has surfaces" % p)
		var aabb: AABB = m.get_aabb()
		assert_gt(aabb.size.length(), 0.05, "%s has size" % p)
	var hull: AABB = (ShermanMesh.part("hull")[0] as ArrayMesh).get_aabb()
	assert_almost_eq(hull.size.x, 2.62, 0.1, "2.62 m wide")
	assert_true(hull.size.z > 5.8 and hull.size.z < 6.4, "about 6 m long (%.2f)" % hull.size.z)
	var path: PackedVector2Array = ShermanMesh.track_path()
	var l: float = ShermanMesh.path_length(path)
	assert_true(l > 11.0 and l < 14.0, "the track's loop: %.1f m" % l)
	var lo: float = INF
	for q: Vector2 in path:
		lo = minf(lo, q.y)
	assert_almost_eq(lo, ShermanMesh.LINK_T * 0.5, 0.01, "the bottom run on the ground")
	for p2: String in ["body", "prop", "bomb", "bomb_small"]:
		assert_gt((StukaPlane.part(p2)[0] as ArrayMesh).get_surface_count(), 0, "the aircraft's %s" % p2)
	var span: AABB = (StukaPlane.part("body")[0] as ArrayMesh).get_aabb()
	assert_true(span.size.x > 13.0 and span.size.x < 14.5, "a 13.9 m span (%.1f)" % span.size.x)


func test_tank_rig() -> void:
	var tk: ShermanTank = ShermanTank.new()
	tk.setup(_cfg()["tank"], _cfg()["assist"], 8000.0)
	add_child_autofree(tk)
	assert_eq(tk.points.size(), 10, "ten attack points")
	for ap: ShermanAttackPoint in tk.points:
		assert_true(tk.near_hull(ap.global_position, 0.0), "each one inside the hull's edge (a zombie at its reach stands against it)")
		assert_false(ap.is_catchable(), "not before the assault")
	tk.attackable = true
	assert_true(tk.points[0].is_catchable())
	tk.take_damage(500.0)
	assert_almost_eq(tk.hp_fraction(), 7500.0 / 8000.0, 0.001)
	tk.take_damage(9000.0)
	assert_true(tk.is_wreck(), "it brews up at 0")
	assert_false(tk.points[0].is_catchable(), "a wreck is not hit")
	var body: AnimatableBody3D = tk.get_node("HullBody")
	assert_eq(body.collision_layer, 1 << 10, "its collider is on the map-edge layer only (zombies and shots pass)")


# ================================================================== T-261: the gunner's judgement, the driver

func _e(x: float, z: float, more: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"pos": Vector3(x, 0, z), "ok": true, "lay": true, "under": false, "fire": false, "boss": false, "on_hull": false, "hp": 1.0}
	e.merge(more, true)
	return e


func test_gunner_shell_choice() -> void:
	var a: Dictionary = _cfg()["assist"]
	var hull: Transform3D = Transform3D.IDENTITY   # the bow to -z
	var muzzle: Vector3 = Vector3(0, 2.3, -4.0)
	var none: Array = []
	# a pack before a single: three together at 20 m beat one alone at 25 m
	var dead: Array = [_e(0, -25), _e(12, -16), _e(13, -17), _e(12.5, -18)]
	var pick: Dictionary = ShermanRules.pick_shell(dead, none, hull, muzzle, a)
	assert_false(pick.is_empty(), "a pack is worth a shell")
	assert_lt((pick["at"] as Vector3).distance_to(Vector3(12.5, 0, -17)), 2.0, "the shell goes into the pack, not at the single")
	# one of the dead alone and close is the machine gun's: no shell
	assert_true(ShermanRules.pick_shell([_e(0, -10)], none, hull, muzzle, a).is_empty(), "one alone at 10 m: no shell wasted")
	assert_false(ShermanRules.pick_shell([_e(0, -20)], none, hull, muzzle, a).is_empty(), "one alone far off (past gun_lone_m): a shell")
	# a burning one still far from everyone is worth a shell alone; the boss too
	assert_false(ShermanRules.pick_shell([_e(0, -10, {"fire": true})], none, hull, muzzle, a).is_empty(), "a burning one at 10 m, nobody near: a shell")
	assert_false(ShermanRules.pick_shell([_e(0, -10, {"boss": true})], none, hull, muzzle, a).is_empty(), "the boss: a shell")
	assert_gt(ShermanRules.shell_weight(_e(0, 0, {"fire": true}), a), ShermanRules.shell_weight(_e(0, 0), a) * 2.0)
	# never near a player, never across one
	var pack: Array = [_e(10, -20), _e(11, -21), _e(10, -22)]
	assert_false(ShermanRules.pick_shell(pack, none, hull, muzzle, a).is_empty())
	assert_true(ShermanRules.pick_shell(pack, [Vector3(13, 0, -21)], hull, muzzle, a).is_empty(), "a player 3 m from the pack: hold fire")
	assert_false(ShermanRules.pick_shell(pack, [Vector3(10, 0, -32)], hull, muzzle, a).is_empty(), "a player 10 m beyond it: fire")
	assert_true(ShermanRules.pick_shell(pack, [Vector3(5, 0, -12)], hull, muzzle, a).is_empty(), "a player on the line of fire: hold fire")
	assert_gte(float(a["gun_player_clear_m"]), 4.0, "never near a player")
	# never on its own hull, never past its range
	assert_true(ShermanRules.pick_shell([_e(2, -3), _e(3, -3), _e(2, -4)], none, hull, muzzle, a).is_empty(), "the ones on the hull are under the guns")
	assert_true(ShermanRules.pick_shell([_e(0, -80), _e(1, -80)], none, hull, muzzle, a).is_empty(), "out of range")
	# a burning one that would burst on a player or on the hull is left alone, and so is a pack it stands in
	var with_fire: Array = [_e(10, -20), _e(11, -21), _e(14, -22, {"fire": true})]
	assert_true(ShermanRules.pick_shell(with_fire, [Vector3(17, 0, -25)], hull, muzzle, a).is_empty(), "a burning one in the blast 4 m from a player: hold fire")
	assert_false(ShermanRules.pick_shell(with_fire, [Vector3(30, 0, -40)], hull, muzzle, a).is_empty())
	# what it cannot see is no target; a pack still rising is laid on, and fired at once one is up
	var rising: Array = [_e(10, -20, {"ok": false}), _e(11, -21, {"ok": false})]
	var lay: Dictionary = ShermanRules.pick_shell(rising, none, hull, muzzle, a)
	assert_false(lay.is_empty(), "a pack coming up out of the ground is laid on")
	assert_false(ShermanRules.shell_has_target(lay["at"], rising, a), "but not fired at while none is up")
	rising[0]["ok"] = true
	assert_true(ShermanRules.shell_has_target(lay["at"], rising, a))
	assert_true(ShermanRules.pick_shell([_e(10, -20, {"ok": false, "lay": false}), _e(11, -21, {"ok": false, "lay": false})], none, hull, muzzle, a).is_empty(), "behind a wall: nothing")
	# a target taken is followed, not swapped for one across the field
	var two: Array = [_e(10, -20), _e(11, -21), _e(-20, -20), _e(-21, -21), _e(-20, -22)]
	var kept: Dictionary = ShermanRules.pick_shell(two, none, hull, muzzle, a, Vector3(10, 0, -20), float(a["gun_follow_m"]))
	assert_lt((kept["at"] as Vector3).x, 12.0)
	assert_gt((kept["at"] as Vector3).x, 9.0, "the pack already laid on is kept")


func test_gunner_machine_gun_choice() -> void:
	var a: Dictionary = _cfg()["assist"]
	var hull: Transform3D = Transform3D.IDENTITY
	var coax: Vector3 = Vector3(0.2, 2.3, -1.5)
	var none: Array = []
	assert_eq(ShermanRules.pick_mg([_e(0, -30), _e(0, -12)], none, hull, coax, a), 1, "the nearer one")
	assert_eq(ShermanRules.pick_mg([_e(0, -12), _e(0, -30, {"fire": true})], none, hull, coax, a), 1, "a burning one far off first: drop it out there")
	assert_eq(ShermanRules.pick_mg([_e(0, -12), _e(0, -14, {"hp": 0.2})], none, hull, coax, a), 1, "the one already hurt is finished")
	assert_eq(ShermanRules.pick_mg([_e(0, -12), _e(3, -13, {"on_hull": true})], none, hull, coax, a), 1, "the one going for the hull")
	assert_eq(ShermanRules.pick_mg([_e(0, -12), _e(0.5, -13)], none, hull, coax, a, 1), 1, "it stays on the one it is on")
	# never at or near a player, never across one
	assert_eq(ShermanRules.pick_mg([_e(0, -12)], [Vector3(0.8, 0, -12)], hull, coax, a), -1, "one of the dead at a player's elbow: not the tank's to shoot")
	assert_eq(ShermanRules.pick_mg([_e(0, -20)], [Vector3(0.1, 0, -10)], hull, coax, a), -1, "a player in the line of fire")
	assert_eq(ShermanRules.pick_mg([_e(0, -20)], [Vector3(6, 0, -10)], hull, coax, a), 0)
	# a burning one beside a player or against the hull is not shot (it would burst there)
	assert_eq(ShermanRules.pick_mg([_e(0, -12, {"fire": true})], [Vector3(3, 0, -12)], hull, coax, a), -1, "a burning one 3 m from a player: left alone")
	assert_eq(ShermanRules.mg_score(_e(3.0, 0, {"fire": true}), none, hull, a), -INF, "a burning one against the hull: left alone")
	assert_eq(ShermanRules.mg_score(_e(0, -12, {"ok": false}), none, hull, a), -INF, "what it cannot see")
	assert_eq(ShermanRules.mg_score(_e(0, -4, {"under": true}), none, hull, a), -INF, "what is under the guns")
	assert_gt(float(a["fire_clear_m"]), float(_cfg()["fire_zombie"]["blast_radius"]), "clear of a burst's whole radius")


func test_gunner_watch_and_reload() -> void:
	var a: Dictionary = _cfg()["assist"]
	var hull: Transform3D = Transform3D(Basis(Vector3.UP, 0.7), Vector3(22, 0, 52))
	assert_true(is_nan(ShermanRules.watch_yaw([], hull, a)), "nobody about: no bearing (it scans)")
	# three of the dead off the right side, one behind: it watches the right side
	var dead: Array = []
	for l: Vector3 in [Vector3(14, 0, 1), Vector3(15, 0, -1), Vector3(13, 0, 0), Vector3(0, 0, 30)]:
		dead.append({"pos": hull * l})
	var yaw: float = ShermanRules.watch_yaw(dead, hull, a)
	assert_almost_eq(wrapf(yaw, -PI, PI), -PI * 0.5, 0.2, "the turret onto the side they are thickest on (%.0f deg)" % rad_to_deg(yaw))
	# a burning one counts double; what is nearer counts more
	var d2: Array = [{"pos": hull * Vector3(0, 0, -20)}, {"pos": hull * Vector3(0, 0, 20), "fire": true}]
	assert_almost_eq(absf(wrapf(ShermanRules.watch_yaw(d2, hull, a), -PI, PI)), PI, 0.2, "the burning one's side")
	assert_eq(ShermanRules.scan_yaw(0.0, a), 0.0, "the scan starts over the bow")
	assert_almost_eq(ShermanRules.scan_yaw(float(a["watch_dwell_s"]) + 0.1, a), PI, 0.01, "then the road behind")
	# the reload: believable for a 75 mm with a crew, and no faster than the round can bear
	var reload: float = float(a["gun_reload_s"])
	assert_true(reload >= 4.0 and reload <= 9.0, "a shell every %.1f s at most" % reload)
	assert_eq(ShermanRules.reload_frac(reload, reload), 0.0)
	assert_eq(ShermanRules.reload_frac(0.0, reload), 1.0)
	assert_almost_eq(ShermanRules.reload_frac(reload * 0.5, reload), 0.5, 0.001)
	assert_lt(float(a["gun_lay_lead_s"]), reload, "the machine gun has the turret for part of every reload")
	assert_true(float(a["assault_damage_mult"]) > 0.3 and float(a["assault_damage_mult"]) <= 1.0, "in the assault it fights at part strength")
	assert_gte(float(a["assault_damage_mult"]) * float(a["gun_damage_frac"]), float(_cfg()["fire_zombie"]["health_mult"]), "a shell on a burning one in the assault kills it (out there, not on the hull)")


func test_drive_rules() -> void:
	var d: Dictionary = _cfg()["drive"]
	# the throttle: it gathers speed, tops out, brakes harder than it pulls
	var v: float = 0.0
	for i: int in 600:
		v = ShermanRules.drive_step(v, 1.0, 0.0, 1.0 / 60.0, d)["speed"]
	assert_almost_eq(v, float(d["speed"]), 0.01, "full ahead: its top speed")
	var one: float = ShermanRules.drive_step(0.0, 1.0, 0.0, 1.0, d)["speed"]
	assert_almost_eq(one, float(d["accel"]), 0.01, "a second from rest: accel")
	assert_lt(ShermanRules.drive_step(v, 0.0, 0.0, 0.5, d)["speed"], v - 1.0, "the keys let go: it brakes")
	var back: float = 0.0
	for i2: int in 600:
		back = ShermanRules.drive_step(back, -1.0, 0.0, 1.0 / 60.0, d)["speed"]
	assert_almost_eq(back, -float(d["reverse_speed"]), 0.01, "slower backwards")
	assert_lte(float(d["speed"]), float(_cfg()["tank"]["drive_speed"]), "no faster than it came up the road")
	# the steer: on the spot it pivots; right is clockwise (rotation.y falls); at speed it turns wider and slower
	var pivot: Dictionary = ShermanRules.drive_step(0.0, 0.0, 1.0, 0.1, d)
	assert_eq(float(pivot["speed"]), 0.0)
	assert_almost_eq(float(pivot["yaw_rate"]), -deg_to_rad(float(d["pivot_rate_deg"])), 0.001, "a pivot turn to the right")
	assert_gt(float(ShermanRules.drive_step(0.0, 0.0, -1.0, 0.1, d)["yaw_rate"]), 0.0, "left is the other way")
	var fast: Dictionary = ShermanRules.drive_step(v, 1.0, 1.0, 0.1, d)
	assert_lt(absf(float(fast["yaw_rate"])), absf(float(pivot["yaw_rate"])), "at speed it turns less sharply")
	assert_lt(float(fast["speed"]), v, "and a turn costs speed")
	# the tracks: only a moving hull runs the dead down, one per cooldown, the leading end only
	assert_true(ShermanRules.crush(0.5, 0.0, d).is_empty(), "creeping: nobody is run down")
	assert_true(ShermanRules.crush(3.0, 0.2, d).is_empty(), "not again within the cooldown")
	var c: Dictionary = ShermanRules.crush(3.0, 0.0, d)
	assert_gte(float(c["damage_frac"]), 1.0, "what goes under the tracks dies")
	assert_gt(float(c["slow"]), 0.1, "and costs the hull speed")
	assert_true(ShermanRules.crush(-1.5, 0.0, d).has("slow"), "backing over them too")
	assert_true(ShermanRules.under_tracks(Vector3(0.5, 0, -2.5), 3.0, d), "under the bow, going forward")
	assert_false(ShermanRules.under_tracks(Vector3(0.5, 0, 2.5), 3.0, d), "at the stern, going forward: not run down")
	assert_true(ShermanRules.under_tracks(Vector3(0.5, 0, 2.5), -1.5, d), "at the stern, backing")
	assert_false(ShermanRules.under_tracks(Vector3(2.0, 0, -1.0), 3.0, d), "beside the hull")
	# the dead on a driven hull: outside the assault they put the driver out, they do not wreck it
	assert_true(ShermanRules.driven_out(1.0, false))
	assert_false(ShermanRules.driven_out(2000.0, false))
	assert_false(ShermanRules.driven_out(0.0, true), "in the assault it burns (the boss bar's rule)")
	# a client driver's reports
	assert_true(ShermanRules.plausible_move(Vector3.ZERO, Vector3(0.6, 0, 0), 0.1, d), "a step the tracks could make")
	assert_false(ShermanRules.plausible_move(Vector3.ZERO, Vector3(12, 0, 0), 0.1, d), "not a jump across the field")


func test_drive_ground_on_the_inn() -> void:
	var b: Dictionary = _blk()
	assert_eq(b["drive_zones"], ["GROUNDS"], "the grounds only")
	var r: Array = b["route"]
	var park: Vector3 = Vector3(float(r[r.size() - 1][0]), 0, float(r[r.size() - 1][2]))
	var yaw: float = ShermanEvent._leg_yaw(PackedVector3Array([Vector3(float(r[r.size() - 2][0]), 0, float(r[r.size() - 2][2])), park]), 0)
	var at_park: Transform3D = Transform3D(Basis(Vector3.UP, yaw), park)
	assert_true(ShermanRules.may_stand(at_park, [], b), "where it parks is ground it may stand on")
	# (a zone list in footprint order: all GROUNDS passes, one YARD point fails)
	var zs: Array = []
	for i: int in 9:
		zs.append(&"GROUNDS")
	assert_true(ShermanRules.may_stand(at_park, zs, b))
	zs[4] = &"YARD"
	assert_false(ShermanRules.may_stand(at_park, zs, b), "a point of the hull in the yard: no")
	var ahead: Transform3D = Transform3D(Basis(Vector3.UP, yaw), park + Vector3(-sin(yaw), 0, -cos(yaw)) * 2.0)
	assert_false(ShermanRules.may_stand(ahead, [], b), "2 m on towards the gate: the gate's mouth is kept clear")
	for p: Vector3 in [Vector3(18, 0, 42), Vector3(15, 0, 28), Vector3(12, 0, 8), Vector3(18, 0, 49.5), Vector3(30, 0, 70), Vector3(64, 0, 55), Vector3(-14, 0, 55), Vector3(45, 0, 16)]:
		assert_false(ShermanRules.may_stand(Transform3D(Basis.IDENTITY, p), [], b), "never at %s (the yard, the stable, the inn, the gate, beyond the edge)" % str(p))
	for p2: Vector3 in [Vector3(30, 0, 57), Vector3(5, 0, 57), Vector3(48, 0, 40), Vector3(-5, 0, 40), Vector3(48, 0, 58)]:
		assert_true(ShermanRules.may_stand(Transform3D(Basis.IDENTITY, p2), [], b), "the road, the meadow, the fields: %s" % str(p2))
	# the horseshoe is wide enough that a hull (6 m) left across it closes nothing
	for bx: Variant in b["drive_boxes"]:
		var v: Array = bx
		assert_gte(minf(float(v[2]) - float(v[0]), float(v[3]) - float(v[1])), 11.0, "a driving box at least 11 m across")
	var inn: Array = b["inn_box"]
	for bx2: Variant in b["drive_boxes"]:
		var v2: Array = bx2
		assert_true(float(v2[1]) > float(inn[1][2]) + 3.0, "every driving box is clear of the inn")
	assert_true(ShermanRules.in_no_go(Vector3(18, 0, 48.6), b["drive_no_go"]))
	assert_eq(ShermanRules.footprint(Transform3D.IDENTITY).size(), 9)


func test_mount_rules() -> void:
	# (drivable, wreck, has_driver, locked, alive, downed, is_bot, carried)
	assert_true(ShermanRules.may_mount(true, false, false, false, true, false, false, false), "parked, free: a living human climbs in")
	assert_false(ShermanRules.may_mount(false, false, false, false, true, false, false, false), "not while it is still coming up the road, nor once the bomber is on its way")
	assert_false(ShermanRules.may_mount(true, true, false, false, true, false, false, false), "not a wreck")
	assert_false(ShermanRules.may_mount(true, false, true, false, true, false, false, false), "one driver at a time")
	assert_false(ShermanRules.may_mount(true, false, false, true, true, false, false, false), "not while the crew repairs")
	assert_false(ShermanRules.may_mount(true, false, false, false, true, true, false, false), "not downed")
	assert_false(ShermanRules.may_mount(true, false, false, false, true, false, true, false), "not a bot")
	assert_false(ShermanRules.may_mount(true, false, false, false, true, false, false, true), "not from a ladder or a saddle")
	var d: Dictionary = _cfg()["drive"]
	assert_gt(float(d["lockout_s"]), 10.0)
	assert_gte(float(d["repair_s"]), float(d["lockout_s"]))
	for k: String in ["bail_banner", "bail_small", "stuka_banner"]:
		assert_ne(str(d[k]), "")


func test_tank_driver_rig() -> void:
	var tk: ShermanTank = ShermanTank.new()
	tk.setup(_cfg()["tank"], _cfg()["assist"], 8000.0, _cfg()["drive"], {})
	add_child_autofree(tk)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(60, 1, 60)
	cs.shape = bx
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor_body)
	var wall: StaticBody3D = StaticBody3D.new()
	var ws: CollisionShape3D = CollisionShape3D.new()
	var wb: BoxShape3D = BoxShape3D.new()
	wb.size = Vector3(20, 3, 1)
	ws.shape = wb
	wall.add_child(ws)
	wall.position = Vector3(0, 1.5, -12.0)
	add_child_autofree(wall)
	await wait_physics_frames(3)
	assert_not_null(tk.use, "the hull is a Use point")
	assert_eq(tk.prompt_for(null), "")
	assert_false(tk.drivable, "not drivable until the event says it is parked")
	assert_has(tk.net_callable(), "net_by_drive_state", "a client driver's calls are whitelisted")
	assert_true(tk.simulates(), "nobody driving: the host moves it")
	# it drives over open ground and stops at a wall
	assert_true(tk.may_be_at(Vector3(0, 0, -3), 0.0), "open ground ahead")
	assert_false(tk.may_be_at(Vector3(0, 0, -9.5), 0.0), "the bow in a wall")
	assert_false(tk.may_be_at(Vector3(40, 0, 0), 0.0), "no ground under it")
	for i: int in 240:
		tk._step_drive(1.0, 0.0, 1.0 / 60.0)
	assert_lt(tk.global_position.z, -4.0, "full ahead for 4 s: it has moved (z %.1f)" % tk.global_position.z)
	for i2: int in 600:
		tk._step_drive(1.0, 0.0, 1.0 / 60.0)
	assert_gt(tk.global_position.z, -12.0 + 0.5 + 2.97, "it stopped short of the wall (z %.1f)" % tk.global_position.z)
	assert_eq(tk.speed, 0.0)
	assert_gt(tk.refusals, 0, "a refusal was counted")
	for i5: int in 180:
		tk._step_drive(-1.0, 0.0, 1.0 / 60.0)
	assert_gt(tk.global_position.z, -7.0, "it backs off the wall (z %.1f)" % tk.global_position.z)
	for i6: int in 60:
		tk._step_drive(0.0, 0.0, 1.0 / 60.0)
	var yaw0: float = tk.rotation.y
	for i3: int in 60:
		tk._step_drive(0.0, 1.0, 1.0 / 60.0)
	assert_lt(tk.rotation.y, yaw0 - 0.3, "it pivots to the right on the spot")
	# the dead on a driven hull outside the assault cannot wreck it; in the assault it burns
	tk.take_damage(20000.0)
	assert_false(tk.is_wreck(), "outside the assault: not wrecked")
	assert_almost_eq(tk.hp, 1.0, 0.01, "its health stops at 1")
	tk._upkeep(30.0)
	assert_almost_eq(tk.hp, 4000.0, 20.0, "the crew repairs: half of it back in half of repair_s")
	tk.attackable = true
	tk.take_damage(20000.0)
	assert_true(tk.is_wreck(), "in the assault it brews up at 0")
	assert_false(tk.can_use(null))
	assert_eq(tk.prompt_for(null), "")
	# a puppet takes the host's place for the hull
	var pk: ShermanTank = ShermanTank.new()
	pk.setup(_cfg()["tank"], _cfg()["assist"], 8000.0, _cfg()["drive"], {})
	pk.puppet = true
	add_child_autofree(pk)
	pk.net_state(Vector3(5, 0, 5), 1.0, 0.3, 0.0, 0.5, int(ShermanTank.Mode.PARKED), 2.0)
	assert_false(pk.simulates())
	for i4: int in 20:
		pk._puppet_step(1.0 / 60.0)
	assert_almost_eq(pk.global_position.x, 5.0, 0.01, "the puppet follows the host")
	assert_almost_eq(pk.hp, 4000.0, 0.1)
	# the host does not take a drive report from somebody who is not the driver
	pk.puppet = false
	pk.net_by_drive_state(7, Vector3(9, 0, 9), 0.0, 0.0, 0.0, 1.0)
	pk.net_by_fire_main(7, Vector3(0, 0, -20))
	assert_almost_eq(pk.global_position.x, 5.0, 0.01, "nobody drives: a stranger's report moves nothing")
	assert_eq(pk.shots_main, 0, "and fires nothing")
