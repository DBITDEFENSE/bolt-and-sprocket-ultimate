extends GutTest
## The gore rework (docs/gore/gore_rework_2026-11.md): GoreFx's budgets hold under a burst (marks per kind, marks
## and rays per physics frame, no node added), the Gore setting off / low leaves nothing, the pooled instances are
## reused oldest first, the web profile and vfx_quality cut the budget, a horde cuts the chances, marks go only on
## plain static geometry and never over an edge, a match start wipes them, and none of it changes a damage number.

var _gore0: String
var _quality0: String
var _alive0: int
var _floor: StaticBody3D
var _wall: StaticBody3D
var _world: Node3D      # a plain parent: Effects.persists_on wants static bodies under an unscripted node


func before_each() -> void:
	_gore0 = str(GLSettings.values.get("gore", "full"))
	_quality0 = str(GLSettings.values.get("vfx_quality", "high"))
	_alive0 = RoundManager.alive
	GLSettings.values["gore"] = "full"
	GLSettings.values["vfx_quality"] = "high"
	GLSettings.compat_override = 0
	RoundManager.alive = 0
	Effects.clear_marks()
	for k: String in Effects.gore.stats.keys():
		Effects.gore.stats[k] = 0
	_world = Node3D.new()
	add_child_autofree(_world)
	# a 40 x 40 m floor whose top is y = 100 and a wall whose face is x = 4 (far from anything a test leaves around)
	_floor = _box(Vector3(0, 99.5, 0), Vector3(40, 1, 40))
	_wall = _box(Vector3(4.5, 102.0, 0), Vector3(1, 4, 40))
	await get_tree().physics_frame
	await get_tree().physics_frame
	Effects.gore.new_frame()


func after_each() -> void:
	GLSettings.values["gore"] = _gore0
	GLSettings.values["vfx_quality"] = _quality0
	GLSettings.compat_override = -1
	RoundManager.alive = _alive0
	Effects.clear_marks()


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	_world.add_child(body)
	body.global_position = at
	return body


static func _descendants(n: Node) -> int:
	var c: int = 0
	for k: Node in n.get_children():
		c += 1 + _descendants(k)
	return c


func test_the_data_is_dark_and_covers_every_weapon_class() -> void:
	var g: Dictionary = Effects.vfx["gore"]
	var classes: Dictionary = g["classes"]
	assert_true(classes.has("default"))
	for id: String in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		var cls: String = str((GLData.table("weapons")["weapons"] as Dictionary)[id].get("class", "rifle"))
		if cls in ["launcher", "special", "melee", "lethal", "tactical"]:
			continue   # blasts and flames do not report bullet hits
		assert_true(classes.has(cls), "a gore profile for class " + cls)
	for key: String in ["wet_color", "dry_color"]:
		var c: Array = g[key]
		assert_lt(float(c[0]), 0.5, key + " is a dark red, not a bright one")
		assert_lt(float(c[1]) + float(c[2]), 0.08, key + " has next to no green or blue")
	assert_lt(float((g["dry_color"] as Array)[0]), float((g["wet_color"] as Array)[0]) * 0.5, "it dries much darker")
	assert_lt(float((g["dry_color"] as Array)[0]), 0.2, "dried blood is close to black")
	assert_false(GoreFx.blood_material().emission_enabled, "blood never glows")
	assert_lt(GoreFx.blood_material().roughness, 0.3, "wet: it catches a lamp")
	assert_not_null(load(GoreFx.SHADER), "the mark shader loads")
	assert_true(float(classes["shotgun"]["chunks"]) > 0.0 and float(classes["pistol"]["chunks"]) == 0.0, "meat from a shotgun, not from a pistol")
	assert_gt(float(classes["bolt"]["reach"]), float(classes["pistol"]["reach"]), "a rifle round carries further through")


func test_a_hit_in_front_of_a_wall_marks_the_wall_and_the_floor() -> void:
	var gore: GoreFx = Effects.gore
	seed(11)
	for i: int in 40:
		gore.new_frame()
		Effects.zombie_hit(Vector3(3.0, 101.2, float(i) * 0.3 - 6.0), Vector3(-1, 0, 0), &"kar98k", false)
	assert_gt(gore.live(GoreFx.SPLAT), 20, "most bolt-rifle hits a metre from a wall leave a spatter")
	assert_gt(gore.live(GoreFx.DRIP), 3, "some of them run down the wall")
	assert_gt(int(gore.stats["walls"]), 15)
	assert_eq(gore.live(GoreFx.POOL), 0, "no pool without a body")


func test_budgets_hold_under_a_burst() -> void:
	var gore: GoreFx = Effects.gore
	var before: int = _descendants(Effects)
	var count: int = gore._mm.instance_count
	var per: Dictionary = Effects.vfx["gore"]["per_frame"]
	seed(5)
	# one physics frame, a hundred hits: the frame's allowance is all that lands
	for i: int in 100:
		Effects.zombie_hit(Vector3(3.0, 101.2, float(i % 20) * 0.5 - 5.0), Vector3(-1, 0, 0), &"trench_gun", false)
	assert_lte(int(gore.stats["marks"]), int(per["marks"]), "at most per_frame.marks marks in a frame")
	assert_lte(int(gore.stats["rays"]), int(per["rays"]) + 6, "the ray allowance holds (one spatter may finish its corners)")
	# four thousand hits over as many frames, pools and tracks too
	var walker: Node3D = Node3D.new()
	add_child_autofree(walker)
	var guns: Array = [&"kar98k", &"trench_gun", &"mg42", &"m1911"]
	for i: int in 4000:
		gore.new_frame()
		var z: float = float(i % 60) * 0.3 - 9.0
		Effects.zombie_hit(Vector3(3.2, 101.0 + float(i % 5) * 0.2, z), Vector3(-1, 0, 0), guns[i % 4], false)
		Effects.blood(Vector3(float(i % 30) * 0.5 - 8.0, 101.0, z), Vector3.UP)
		if i % 4 == 0:
			gore.pool_under(Vector3(float(i % 37) * 0.4 - 8.0, 100.5, z))
		if i % 50 == 0:
			gore.track(walker, GoreFx.PRINT if i % 100 == 0 else GoreFx.SMEAR, 12)
		walker.global_position = Vector3(float(i % 200) * 0.09 - 9.0, 100.0, 2.0)
		gore._tick_walkers()
	for k: int in GoreFx.KINDS:
		assert_lte(gore.live(k), gore.cap(k), "kind %d stays inside its budget" % k)
	assert_eq(gore.live(GoreFx.SPLAT), gore.cap(GoreFx.SPLAT), "the spatter ring filled")
	assert_eq(gore.live(GoreFx.POOL), gore.cap(GoreFx.POOL), "the pool ring filled")
	assert_gt(gore.live(GoreFx.PRINT), 0)
	assert_gt(gore.live(GoreFx.SMEAR), 0)
	assert_gt(int(gore.stats["evicted"]), 500, "old marks were reused")
	assert_eq(gore._mm.instance_count, count, "the MultiMesh never grew")
	await get_tree().process_frame
	assert_eq(_descendants(Effects), before, "no node was added")


func test_oldest_pool_is_reused_first() -> void:
	var gore: GoreFx = Effects.gore
	var cap: int = gore.cap(GoreFx.POOL)
	for i: int in cap:
		gore.new_frame()
		assert_true(gore.pool_under(Vector3(float(i % 8) * 2.5 - 9.0, 100.5, float(i / 8) * 2.5 - 9.0)), "pool %d" % i)
	assert_eq(gore.live(GoreFx.POOL), cap)
	var first: Vector3 = gore._pool_pos[0]
	var second: Vector3 = gore._pool_pos[1]
	gore.new_frame()
	assert_true(gore.pool_under(Vector3(1.0, 100.5, 15.0)))
	assert_eq(gore.live(GoreFx.POOL), cap, "still the cap")
	assert_eq(int(gore.stats["evicted"]), 1)
	assert_ne(gore._pool_pos[0], first, "the oldest slot took the new pool")
	assert_eq(gore._pool_pos[1], second, "the next oldest is untouched")


func test_gore_off_and_low_leave_nothing() -> void:
	var gore: GoreFx = Effects.gore
	var body: Node3D = Node3D.new()
	add_child_autofree(body)
	body.global_position = Vector3(0, 100.4, 0)
	for level: String in ["off", "low"]:
		GLSettings.values["gore"] = level
		for i: int in 50:
			gore.new_frame()
			Effects.zombie_hit(Vector3(3.0, 101.2, float(i) * 0.2), Vector3(-1, 0, 0), &"trench_gun", false)
			Effects.blood(Vector3(0, 101.0, float(i) * 0.2), Vector3.UP)
			Effects.gore_burst(Vector3(0, 101.0, float(i) * 0.2), Vector3.UP, true)
		assert_false(gore.pool_under(Vector3(0, 100.5, 0)), level + ": no pool")
		gore.death(body)
		gore.spurt(body)
		gore.crawler(body)
		gore.screen.add(1.0)
		gore.hands(1.0)
		assert_eq(gore.hands_amount(), 0.0, level + ": clean hands")
		assert_eq(gore.live_total(), 0, level + ": no mark")
		assert_eq(int(gore.stats["sprays"]), 0, level + ": no spray")
		assert_eq(gore._pend_n, 0, level + ": no body waits to pool")
		assert_eq(gore._spurt_n, 0, level + ": no spurt")
		assert_eq(gore.tracked(), 0, level + ": no track")
		assert_eq(gore.screen.amount(), 0.0, level + ": a clean lens")
	assert_gt(int(Effects.stats["hits"]), 0, "the hits were still counted")


func test_web_profile_and_quality_cut_the_budget() -> void:
	var gore: GoreFx = Effects.gore
	var full: int = gore.cap(GoreFx.SPLAT)
	var k_full: float = Effects.particles_k()
	GLSettings.compat_override = 1
	assert_almost_eq(float(gore.cap(GoreFx.SPLAT)), float(full) * float(Effects.vfx["gore"]["web_scale"]), 1.0, "half the marks on the web")
	assert_almost_eq(Effects.particles_k(), k_full * WebProfile.PARTICLE_RATIO, 0.001, "half the particles on the web")
	# the reduced ring really is the limit
	for i: int in 400:
		gore.new_frame()
		gore._mark(GoreFx.SPLAT, Vector3(float(i % 20) * 0.5 - 5.0, 100.0, float(i / 20) * 0.5 - 5.0), Vector3.UP, Vector3.RIGHT, 0.3, 0.3, 1.0, 1.0, false, false)
	assert_eq(gore.live(GoreFx.SPLAT), gore.cap(GoreFx.SPLAT))
	assert_lt(gore.live(GoreFx.SPLAT), full)
	GLSettings.compat_override = 0
	GLSettings.values["vfx_quality"] = "low"
	assert_lt(gore.cap(GoreFx.SPLAT), full, "fewer marks on Low")
	assert_lt(gore.cap(GoreFx.POOL), int(Effects.vfx["gore"]["budget"]["pools"]))


func test_a_horde_cuts_the_blood() -> void:
	var gore: GoreFx = Effects.gore
	var h: Dictionary = Effects.vfx["gore"]["horde"]
	RoundManager.alive = 4
	assert_almost_eq(gore.horde_k(), 1.0, 0.001, "a handful: everything")
	RoundManager.alive = int(h["to"]) + 10
	assert_almost_eq(gore.horde_k(), float(h["min"]), 0.001, "a horde: the floor")
	seed(3)
	for i: int in 300:
		gore.new_frame()
		Effects.zombie_hit(Vector3(3.0, 101.2, float(i % 40) * 0.3 - 6.0), Vector3(-1, 0, 0), &"m1_garand", false)
	var marks_horde: int = int(gore.stats["marks"])
	Effects.clear_marks()
	gore.stats["marks"] = 0
	RoundManager.alive = 4
	seed(3)
	for i: int in 300:
		gore.new_frame()
		Effects.zombie_hit(Vector3(3.0, 101.2, float(i % 40) * 0.3 - 6.0), Vector3(-1, 0, 0), &"m1_garand", false)
	assert_lt(float(marks_horde), float(int(gore.stats["marks"])) * 0.7, "fewer marks per hit in a horde")


func test_marks_only_on_plain_static_geometry_and_never_over_an_edge() -> void:
	var gore: GoreFx = Effects.gore
	# a door (an AnimatableBody3D) in front of the wall: nothing may stick to it
	var door: AnimatableBody3D = AnimatableBody3D.new()
	door.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(0.2, 4, 40)
	cs.shape = sh
	door.add_child(cs)
	_world.add_child(door)
	door.global_position = Vector3(3.7, 102.0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	seed(9)
	for i: int in 60:
		gore.new_frame()
		Effects.zombie_hit(Vector3(3.0, 102.5, float(i) * 0.2 - 6.0), Vector3(-1, 0, 0), &"kar98k", false)
	assert_eq(int(gore.stats["walls"]), 0, "no spatter on the door")
	assert_eq(gore.live(GoreFx.DRIP), 0, "no run on the door")
	# a 30 cm ledge: a metre-wide pool cannot lie on it
	_box(Vector3(0, 110.0, 0), Vector3(0.3, 0.2, 0.3))
	await get_tree().physics_frame
	await get_tree().physics_frame
	gore.new_frame()
	var pools: int = gore.live(GoreFx.POOL)
	assert_false(gore.pool_under(Vector3(0, 110.5, 0)), "refused: its corners would hang in the air")
	assert_eq(gore.live(GoreFx.POOL), pools)
	assert_gt(int(gore.stats["rejected"]), 0)


func test_a_body_pools_after_it_comes_to_rest_and_whoever_treads_in_it_leaves_prints() -> void:
	var gore: GoreFx = Effects.gore
	var body: Node3D = Node3D.new()
	add_child_autofree(body)
	body.global_position = Vector3(-5, 100.2, -5)
	gore.death(body)
	assert_eq(gore._pend_n, 1)
	assert_eq(gore.live(GoreFx.POOL), 0, "not at once")
	gore._clock += 2.0
	gore.new_frame()
	gore._tick_pending()
	assert_eq(gore.live(GoreFx.POOL), 1, "a pool under the body")
	assert_eq(gore._pend_n, 0)
	# a walker through the pool, then twenty metres on
	var walker: Node3D = Node3D.new()
	walker.add_to_group(&"players")
	add_child_autofree(walker)
	walker.global_position = Vector3(-5, 100.0, -5)
	gore._scan_pools()
	assert_eq(gore.tracked(), 1, "it trod in it")
	var steps: int = int(Effects.vfx["gore"]["tracks"]["print_steps"])
	walker.remove_from_group(&"players")
	for i: int in 200:
		gore.new_frame()
		walker.global_position += Vector3(0.1, 0, 0)
		gore._tick_walkers()
	assert_eq(gore.live(GoreFx.PRINT), steps, "a fixed number of prints, then clean boots")
	assert_eq(gore.tracked(), 0)
	# a dry pool marks nobody
	walker.add_to_group(&"players")
	gore._clock += float(Effects.vfx["gore"]["tracks"]["wet_seconds"]) + 1.0
	walker.global_position = Vector3(-5, 100.0, -5)
	gore._scan_pools()
	assert_eq(gore.tracked(), 0, "dried: no prints")


func test_a_match_start_wipes_the_blood() -> void:
	var gore: GoreFx = Effects.gore
	for i: int in 30:
		gore.new_frame()
		gore.pool_under(Vector3(float(i) * 0.5 - 7.0, 100.5, 3.0))
		Effects.zombie_hit(Vector3(3.0, 101.2, float(i) * 0.3), Vector3(-1, 0, 0), &"kar98k", false)
	gore.screen.add(0.5)
	gore.hands(0.8)
	assert_gt(gore.live_total(), 10)
	Effects.clear_marks()
	assert_eq(gore.live_total(), 0)
	assert_eq(gore.hands_amount(), 0.0, "clean hands in a new match")
	assert_eq(gore.screen.amount(), 0.0)
	assert_false(gore.is_processing(), "the clock rests until there is blood again")


func test_the_lens_spatter_is_small_and_fades() -> void:
	var gore: GoreFx = Effects.gore
	var s: Dictionary = Effects.vfx["gore"]["screen"]
	assert_gte(float(s["clear_radius"]), 0.5, "the middle of the view stays clean")
	assert_eq(gore.screen.layer, 5, "under the HUD")
	gore.screen.add(0.4)
	assert_almost_eq(gore.screen.amount(), 0.4, 0.001)
	gore.screen.add(5.0)
	assert_almost_eq(gore.screen.amount(), float(s["max"]), 0.001, "capped")
	gore.screen._process(float(s["fade_seconds"]) * 0.5)
	assert_almost_eq(gore.screen.amount(), float(s["max"]) - 0.5, 0.01)
	gore.screen._process(float(s["fade_seconds"]))
	assert_eq(gore.screen.amount(), 0.0, "gone")
	assert_false((gore.screen.get_node("Spatter") as CanvasItem).visible)
	# the hands: bloodied by what bloodies the lens, worn clean in hands.seconds
	gore.hands(0.6)
	assert_almost_eq(gore.hands_amount(), 0.6, 0.001)
	gore._process(float(Effects.vfx["gore"]["hands"]["seconds"]) * 0.5)
	assert_almost_eq(gore.hands_amount(), 0.1, 0.01)
	gore._process(float(Effects.vfx["gore"]["hands"]["seconds"]))
	assert_eq(gore.hands_amount(), 0.0)


func test_gore_changes_no_damage_number() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var sp: ZombieSpawn = ZombieSpawn.new()
	host.add_child(sp)
	var left: Dictionary = {}
	var killed: Dictionary = {}
	for level: String in ["off", "full"]:
		GLSettings.values["gore"] = level
		var z: Zombie = Zombie.new()
		host.add_child(z)
		z.activate({"enemy_id": "ganger", "tier": "walk", "health": 150, "variant": "soldier"}, sp, null)
		z.state = Zombie.State.CHASE
		var hp0: float = z.hp
		Effects.zombie_hit(z.global_position + Vector3.UP * 1.2, Vector3.BACK, &"m1_garand", false)
		assert_false(z.take_damage(40.0, &"torso", &"m1_garand", 0, &"bullet"))
		Effects.zombie_hit(z.global_position + Vector3.UP * 0.6, Vector3.BACK, &"trench_gun", false)
		z.take_damage(25.0, &"legs", &"trench_gun", 0, &"bullet")
		left[level] = hp0 - z.hp
		killed[level] = z.take_damage(1000.0, &"head", &"kar98k", 0, &"bullet")
		assert_eq(z.state, Zombie.State.DEAD)
	assert_almost_eq(float(left["off"]), float(left["full"]), 0.0001, "the same damage with gore off and full")
	assert_gt(float(left["full"]), 0.0)
	assert_true(bool(killed["off"]) and bool(killed["full"]))
