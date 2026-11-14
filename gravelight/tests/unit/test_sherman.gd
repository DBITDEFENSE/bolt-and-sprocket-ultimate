extends GutTest
## T-249: the Sherman on the Inn, rounds 30..40 (data/gravelight/sherman.json, map00.json "sherman_event",
## ShermanEvent, ShermanTank, FireZombie, FirePatch, AirRaid, StukaPlane, ShermanMesh) as pure logic and data:
## where it is on (the Inn only), the Fuhrmann resolution (round 30 has both the horse and the tank: the horse comes in
## behind the tank), the assault's size and its fire zombies spread through the wave, the tank's health and its
## attack points against the hull, a fire zombie's burst by distance, the assist's damage against the round's health,
## the raid's shelter rule (inside the inn zones or its box), its damage by distance (a full-health player survives
## one bomb that is not on top of them; nobody inside is touched), the route on the map (it parks outside the yard's
## gate, never in it), the dive bomber's pass (it releases on the dive's line above the target), the model's parts.


func _cfg() -> Dictionary:
	return ShermanEvent.table()


func _blk() -> Dictionary:
	return ShermanEvent.block_for(&"map00_crossroads")


func test_on_the_inn_only() -> void:
	var b: Dictionary = _blk()
	assert_false(b.is_empty(), "the Inn has the block")
	assert_eq(int(b["arrive_round"]), 30, "the Sherman comes on round 30")
	assert_eq(int(b["stuka_round"]), 40, "the dive bomber and the raid on round 40")
	for m: StringName in [&"map01_kaltenbrunn", &"map02_totenhafen", &"map04a_thalbach", &"test_range"]:
		assert_true(ShermanEvent.block_for(m).is_empty(), "%s: no Sherman" % m)
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
	# Kaltenbrunn's round-30 horse keeps its own beats (no Sherman there)
	for r2: Dictionary in HorseRound.rows_for(&"map01_kaltenbrunn"):
		assert_false(r2.has("arrival"), "Kaltenbrunn's rows keep the block's arrival")
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
	var kills_per_min: float = 60.0 / cycle * per_burst + 60.0 / float(s["gun_interval"]) * 1.0
	assert_lt(kills_per_min, 12.0, "at most about ten a minute with targets everywhere (%.1f): it helps, it does not win the round" % kills_per_min)
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
