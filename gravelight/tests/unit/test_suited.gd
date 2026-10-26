extends GutTest
## The Suited (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.9, T-112): x1.4 health, the visor the weak point
## (head x3), vacuum-only, never leap or crawl; a visor hit cracks the visor and, in vacuum, the suit lets go two
## seconds later, credited to the cracker; the director puts only the Suited on a vacuum spawn.


func test_data() -> void:
	var e: Dictionary = GLData.table("enemies")["enemies"]
	assert_true(e.has("suited"), "enemies.json suited")
	var s: Dictionary = e["suited"]
	assert_almost_eq(float(s["health_mult"]), 1.4, 0.001)
	assert_almost_eq(float(s["head_mult"]), 3.0, 0.001, "the visor")
	assert_true(bool(s["visor"]) and bool(s["vacuum_only"]))
	assert_false(bool(s.get("can_crawl", true)), "the suit holds them up")
	assert_false(bool(s.get("leap_hop", true)), "the suits are stiff")
	assert_almost_eq(float(s["visor_death_seconds"]), 2.0, 0.001)
	assert_eq((s["maps"] as Array), ["map04d_mondlicht"])
	assert_eq(int((s["scrip"] as Dictionary)["body"]), 100)
	var cfg: Dictionary = Zombie.kind_config(&"suited")
	assert_true(cfg.has("attack_range") and cfg.has("visor"), "the kind merges over the Gänger")


func test_shield_cell_data() -> void:
	var e: Dictionary = GLData.table("enemies")["enemies"]
	assert_true(e.has("shield_cell"))
	assert_eq(int((e["shield_cell"] as Dictionary)["health"]), 2000)
	assert_false(bool((e["shield_cell"] as Dictionary).get("bullet_stagger", true)))


func test_visor_crack_kills_in_vacuum_only() -> void:
	var zone: ZoneVolume = ZoneVolume.new()
	zone.zone_id = &"C_YARD"
	zone.size = Vector3(20, 6, 20)
	zone.vacuum = true
	add_child_autofree(zone)
	zone.global_position = Vector3(300, 0, 300)
	var floor_body: StaticBody3D = StaticBody3D.new()   # the yard's regolith: a zombie with nothing under it falls off the world
	var fs: CollisionShape3D = CollisionShape3D.new()
	var fb: BoxShape3D = BoxShape3D.new()
	fb.size = Vector3(200, 1, 200)
	fs.shape = fb
	floor_body.add_child(fs)
	add_child_autofree(floor_body)
	floor_body.global_position = Vector3(300, -0.5, 320)
	var dir: ZombieDirector = ZombieDirector.new()
	add_child_autofree(dir)
	await wait_physics_frames(2)
	var sp: ZombieSpawn = ZombieSpawn.new()
	sp.kind = &"ground"
	add_child_autofree(sp)
	sp.global_position = Vector3(300, 0.5, 300)
	var z: Zombie = dir._free.pop_back()
	z.activate(dir._spec_for(&"suited", {"health": 150.0, "tier": &"walk", "variant": "soldier"}), sp, null)
	await wait_physics_frames(1)
	assert_eq(z.enemy_id, &"suited")
	assert_almost_eq(z.max_hp, 210.0, 0.5, "x1.4")
	z.take_damage(10.0, &"head", &"kar98k", 1, &"bullet")
	assert_true(z.visor_cracked, "a head hit cracks the visor")
	assert_true(z.hp < 210.0 - 29.0, "the visor took x3 (%.0f)" % z.hp)
	assert_gt(z._visor_t, 0.0, "in vacuum: the suit's clock runs")
	var killed: Array = []
	GLBus.enemy_killed.connect(func(id: StringName, _l: StringName, _w: StringName, by: int) -> void: killed.append([id, by]))
	await wait_seconds(2.4)
	assert_false(z.is_active(), "dead two seconds later")
	assert_true(killed.size() >= 1 and killed[0][0] == &"suited" and int(killed[0][1]) == 1, "credited to the cracker (%s; hp %.0f, state %d)" % [str(killed), z.hp, z.state])
	# in pressure: just the headshot
	var z2: Zombie = dir._free.pop_back()
	sp.global_position = Vector3(300, 0.5, 340)
	z2.activate(dir._spec_for(&"suited", {"health": 150.0, "tier": &"walk", "variant": "soldier"}), sp, null)
	await wait_physics_frames(1)
	z2.take_damage(10.0, &"head", &"kar98k", 1, &"bullet")
	assert_true(z2.visor_cracked)
	assert_lt(z2._visor_t, 0.0, "no clock in pressure")
	await wait_seconds(0.3)
	assert_true(z2.is_active())
	z2.kill_silently()
	dir.kill_all(true)
