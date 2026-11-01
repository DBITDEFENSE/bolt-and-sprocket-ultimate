extends GutTest
## The Marke (UPDATE 09 section 1, T-137; docs/U09_CONTRACTS.md C1): every Gänger carries Darkmatter's chip under
## the skin of the right hand or the forehead, picked from its net_id so a co-op puppet shows the same site; it is a
## "marke" hitbox on a built body that does x damage_mult and continues as the host limb; a kill from a Marke hit
## emits GLBus.marke_kill, counts in GameState.stats, and pays scrip_bonus once through Economy.award, never in
## Classic Rules; bosses and the Backorder construct have none.

var _host: Node3D
var _spawn: ZombieSpawn
var _mk: Dictionary
var _classic_before: bool
var _phase_before: int
var _kills: Array = []


func before_each() -> void:
	GLSettings.values["gore"] = "full"
	_classic_before = bool(GLSettings.values.get("classic_rules", false))
	GLSettings.values["classic_rules"] = false
	_phase_before = GameState.phase
	_mk = (GLData.table("enemies") as Dictionary).get("marke", {})
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"ground"
	_host.add_child(_spawn)
	_kills.clear()
	GLBus.marke_kill.connect(_on_marke_kill)


func after_each() -> void:
	GLBus.marke_kill.disconnect(_on_marke_kill)
	GLSettings.values["classic_rules"] = _classic_before
	GameState.phase = _phase_before
	Economy.multiplier = 1


func _on_marke_kill(by_player: int, enemy_id: StringName) -> void:
	_kills.append([by_player, enemy_id])


func _zombie(net_id: int, hp: float = 5000.0, enemy: String = "ganger") -> Zombie:
	var z: Zombie = Zombie.new()
	z.net_id = net_id
	_host.add_child(z)
	z.activate({"enemy_id": enemy, "tier": "walk", "health": hp, "variant": "miner"}, _spawn, null)
	z.state = Zombie.State.CHASE
	z._set_emerge_hitboxes(true)   # the rise keeps every box off until the head is out; this body is up
	return z


# ------------------------------------------------------------------ the site

func test_the_data_table_exists() -> void:
	for key: String in ["damage_mult", "scrip_bonus", "hand_chance", "hitbox_m", "glow_min", "glow_max"]:
		assert_true(_mk.has(key), "enemies.json marke has " + key)
	assert_almost_eq(float(_mk["damage_mult"]), 1.5, 0.001, "x1.5 on the Marke")
	assert_eq(int(_mk["scrip_bonus"]), 25)
	for e: String in ["foreman", "screamer", "shield_cell", "backorder"]:
		assert_false(bool(Zombie.kind_config(StringName(e)).get("marke", true)), e + " carries no Marke")
	assert_true(bool(Zombie.kind_config(&"suited").get("marke", true)), "the Suited keep theirs")


func test_site_is_deterministic_from_net_id_and_splits_by_hand_chance() -> void:
	var hands: int = 0
	for i: int in 1000:
		var a: StringName = ZombieBody.marke_site_for(i, 0.6)
		assert_eq(a, ZombieBody.marke_site_for(i, 0.6), "the same net_id picks the same site")
		assert_true(a == &"hand" or a == &"forehead")
		if a == &"hand":
			hands += 1
	assert_between(hands, 540, 660, "about six in ten hands over 1000 ids (%d)" % hands)
	assert_eq(ZombieBody.marke_site_for(17, 1.0), &"hand")
	assert_eq(ZombieBody.marke_site_for(17, 0.0), &"forehead")
	assert_eq(ZombieBody.marke_host_limb(&"hand"), &"arms")
	assert_eq(ZombieBody.marke_host_limb(&"forehead"), &"head")


func test_a_built_body_picks_its_site_from_net_id_like_a_puppet_would() -> void:
	var seen: Dictionary = {}
	for i: int in 24:
		var z: Zombie = _zombie(i)
		assert_eq(z.marke_site, ZombieBody.marke_site_for(i, float(_mk["hand_chance"])), "zombie %d: the pure pick" % i)
		seen[z.marke_site] = true
		z.deactivate()
	assert_true(seen.has(&"hand") and seen.has(&"forehead"), "both sites turn up across the pool")
	var a: Zombie = _zombie(5)
	var b: Zombie = _zombie(5)
	assert_eq(a.marke_site, b.marke_site, "two bodies with one net_id (host and puppet) agree")


# ------------------------------------------------------------------ the hitbox on a built body

func test_hitbox_and_glint_exist_on_a_built_body() -> void:
	var z: Zombie = _zombie(3)
	assert_true(z.has_marke())
	var hb: Hitbox = z.marke_hitbox()
	assert_not_null(hb, "a Marke hitbox")
	assert_eq(hb.name, "marke")
	assert_eq(hb.limb, &"marke")
	assert_eq(hb.collision_layer, Hitbox.LAYER_HITBOX, "live after activate")
	var want_bone: String = str((ZombieBody.MARKE_SITES[z.marke_site] as Array)[0])
	assert_eq(hb.bone, want_bone)
	assert_eq((hb.get_parent() as BoneAttachment3D).bone_name, want_bone, "rides the site's bone")
	assert_true(z.hitbox_rids().has(hb.get_rid()), "excluded with the limb boxes after a hit")
	var cs: CollisionShape3D = hb.get_child(0) as CollisionShape3D
	assert_almost_eq((cs.shape as BoxShape3D).size.x, float(_mk["hitbox_m"]), 0.001)
	# the other site stays dark and off
	for site: StringName in z._marke_hb.keys():
		var other: Hitbox = z._marke_hb[site]
		var glint: MeshInstance3D = z._marke_glint[site]
		if site == z.marke_site:
			assert_true(glint.visible, "the site's glint shows")
		else:
			assert_eq(other.collision_layer, 0, "the other site's box is off")
			assert_false(glint.visible, "the other site's glint is hidden")
	assert_true(z._hitboxes.size() == ZombieBody.HITBOXES.size(), "the limb layout is untouched")
	z.deactivate()
	assert_eq(hb.collision_layer, 0, "off once pooled")


func test_the_glint_material_pulses_on_the_shared_globals() -> void:
	var m: ShaderMaterial = ZombieBody.marke_material()
	assert_not_null(m)
	assert_true(m.shader.code.contains("gl_hum") and m.shader.code.contains("gl_round_k"), "driven by the infection globals")
	assert_almost_eq(float(m.get_shader_parameter("glow_min")), float(_mk["glow_min"]), 0.001)
	assert_almost_eq(float(m.get_shader_parameter("glow_max")), float(_mk["glow_max"]), 0.001)
	assert_eq(ZombieBody.marke_material(), m, "one shared material")


# ------------------------------------------------------------------ the hit

func test_a_marke_hit_does_x1_5_and_continues_as_the_host_limb() -> void:
	var z: Zombie = _zombie(3)
	var hp0: float = z.hp
	z.take_damage(100.0, &"marke", &"m1_garand", 1, &"bullet", true)
	assert_almost_eq(hp0 - z.hp, 100.0 * float(_mk["damage_mult"]), 0.01, "x damage_mult")
	assert_true(z._marke_hit, "remembered for the kill")
	z.take_damage(10.0, &"torso", &"m1_garand", 1, &"bullet", true)
	assert_false(z._marke_hit, "any other hit clears it")
	# the host limb: a hand mark wounds the arm, a forehead mark is a head hit (no mult beyond the Marke's own)
	assert_eq(z.marke_host_limb(), &"arms" if z.marke_site == &"hand" else &"head")


func test_a_kill_from_a_marke_hit_pays_the_bonus_once_and_counts() -> void:
	Economy.reset([1])
	GameState.stats[&"marke_kills"] = 0
	GameState.phase = GameState.Phase.PLAYING
	var z: Zombie = _zombie(3, 10.0)
	var before: int = Economy.get_scrip(1)
	var killed: bool = z.take_damage(100.0, &"marke", &"m1_garand", 1, &"bullet", true)
	assert_true(killed)
	var host: StringName = z.marke_host_limb()
	var kill_value: int = Economy.kill_value(host, false, GLData.table("economy"))
	assert_eq(Economy.get_scrip(1) - before, kill_value + int(_mk["scrip_bonus"]), "the kill's Scrip plus the Marke bonus, once")
	assert_eq(_kills.size(), 1, "GLBus.marke_kill once")
	assert_eq(_kills[0][0], 1)
	assert_eq(_kills[0][1], &"ganger")
	assert_eq(int(GameState.stats[&"marke_kills"]), 1, "GameState.stats marke_kills")
	# a second kill from a plain hit pays nothing extra
	var z2: Zombie = _zombie(4, 10.0)
	before = Economy.get_scrip(1)
	z2.take_damage(100.0, &"torso", &"m1_garand", 1, &"bullet", true)
	assert_eq(Economy.get_scrip(1) - before, Economy.kill_value(&"torso", false, GLData.table("economy")), "no bonus on a body kill")
	assert_eq(_kills.size(), 1)
	assert_eq(int(GameState.stats[&"marke_kills"]), 1)


func test_double_scrip_applies_to_the_bonus() -> void:
	Economy.reset([1])
	Economy.multiplier = 2
	var z: Zombie = _zombie(3, 10.0)
	var before: int = Economy.get_scrip(1)
	z.take_damage(100.0, &"marke", &"m1_garand", 1, &"bullet", true)
	var kill_value: int = Economy.kill_value(z.marke_host_limb(), false, GLData.table("economy"))
	assert_eq(Economy.get_scrip(1) - before, (kill_value + int(_mk["scrip_bonus"])) * 2, "Economy.award: Double Scrip doubles it")


func test_classic_rules_keeps_the_weak_point_and_pays_no_bonus() -> void:
	GLSettings.values["classic_rules"] = true
	Economy.reset([1])
	assert_eq(Zombie.marke_bonus_for(1), 0, "no bonus in Classic Rules")
	var z: Zombie = _zombie(3, 10.0)
	assert_not_null(z.marke_hitbox(), "the weak point is part of the zombie")
	var hp0: float = z.hp
	z.hp = 5000.0
	z.take_damage(100.0, &"marke", &"m1_garand", 1, &"bullet", true)
	assert_almost_eq(5000.0 - z.hp, 150.0, 0.01, "still x1.5")
	z.hp = hp0
	var before: int = Economy.get_scrip(1)
	z.take_damage(100.0, &"marke", &"m1_garand", 1, &"bullet", true)
	assert_eq(Economy.get_scrip(1) - before, Economy.kill_value(z.marke_host_limb(), false, GLData.table("economy")), "the kill's Scrip only")
	assert_eq(_kills.size(), 1, "the signal still fires (stats count in every mode)")


func test_bosses_and_the_backorder_construct_have_none() -> void:
	var b: Zombie = _zombie(9, 500.0, "backorder")
	assert_eq(b.marke_site, &"", "the Backorder construct")
	assert_false(b.has_marke())
	assert_null(b.marke_hitbox())
	for glint: MeshInstance3D in b._marke_glint.values():
		assert_false(glint.visible)
	var hp0: float = b.hp
	b.take_damage(100.0, &"marke", &"m1_garand", 1, &"bullet", true)
	assert_true(b.hp < hp0, "a stray marke report still lands as a body hit")
	var f: Foreman = Foreman.new()
	_host.add_child(f)
	assert_false(f.has_marke(), "the Foreman builds his own body: no Marke")
	assert_false(f._marke_hit)


func test_a_lost_hand_takes_the_mark_with_it() -> void:
	var z: Zombie = null
	for i: int in 64:
		var c: Zombie = _zombie(i)
		if c.marke_site == &"hand":
			z = c
			break
		c.deactivate()
	assert_not_null(z, "a hand-marked zombie in the first 64 ids")
	var hb: Hitbox = z.marke_hitbox()
	z.sever_limb("RightLowerArm")
	assert_eq(hb.collision_layer, 0, "no weak point on a stump")
	assert_false((z._marke_glint[&"hand"] as MeshInstance3D).visible)
	z._apply_marke()
	assert_false(z._marke_lost, "a new spawn gets it back")


func test_the_hitmarker_latch() -> void:
	assert_true(Hud.HitMarker.marke_latched(1000, 990), "a flash right after the Marke report is violet")
	assert_false(Hud.HitMarker.marke_latched(1000, 900), "an older report is not")
