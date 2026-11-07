extends GutTest
## UPDATE 11 (T-192): the Soviet risen, the Returned. Three kits built in Blender on the shared rig (the GLBs carry
## Kit_soviet / Kit_soviet_tunic / Kit_soviet_burial, the coverage bits past 8 in the body's red channel), frost-white
## skin, milky eyes; never marked (no Marke, no glint): the weak point is the wound that killed them, the same box and
## numbers as the Marke in another place, picked from net_id so a co-op puppet matches; a kill on it pays the same
## bonus as "the wound" and is no Marke kill. They join the spawn mix on Map 0 (from round 2) and Kaltenbrunn's
## surface only, from data. RisenColumn is presentation only (no collision, no hitboxes, nothing targetable).

var _host: Node3D
var _spawn: ZombieSpawn
var _classic_before: bool
var _marke_kills: int = 0
var _bonus: Array = []


func before_each() -> void:
	GLSettings.values["gore"] = "full"
	_classic_before = bool(GLSettings.values.get("classic_rules", false))
	GLSettings.values["classic_rules"] = false
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"ground"
	_host.add_child(_spawn)
	_marke_kills = 0
	_bonus.clear()
	GLBus.marke_kill.connect(_on_marke_kill)
	GLBus.bonus_awarded.connect(_on_bonus)


func after_each() -> void:
	GLBus.marke_kill.disconnect(_on_marke_kill)
	GLBus.bonus_awarded.disconnect(_on_bonus)
	GLSettings.values["classic_rules"] = _classic_before


func _on_marke_kill(_p: int, _e: StringName) -> void:
	_marke_kills += 1


func _on_bonus(p: int, kind: StringName, amount: int, label: String) -> void:
	_bonus.append([p, kind, amount, label])


func _zombie(net_id: int, kit: String, hp: float = 5000.0) -> Zombie:
	var z: Zombie = Zombie.new()
	z.net_id = net_id
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": hp, "variant": kit}, _spawn, null)
	z.state = Zombie.State.CHASE
	z._set_emerge_hitboxes(true)
	return z


# ------------------------------------------------------------------ the kits

func test_the_kits_are_registered_and_dressed() -> void:
	var order: Array = ZombieBody.char_cfg().get("kit_order", [])
	for k: String in ZombieBody.SOVIET_KITS:
		assert_true(ZombieBody.KITS.has(k), k + " is a kit")
		assert_true(order.has(k), k + " is in characters.json kit_order")
		var kd: Dictionary = (GLData.table("anim")["kits"] as Dictionary).get(k, {})
		assert_eq(str(kd.get("faction", "")), "red_army")
		assert_false((kd.get("wound_sites", []) as Array).is_empty(), k + " has wound sites")
		for s: Variant in kd.get("wound_sites", []):
			assert_true(ZombieBody.WOUND_SITES.has(StringName(str(s))), "%s: %s is a wound site" % [k, s])
		assert_true(ZombieBody.KIT_CLOTH.has(k), k + " has its cloth colours")
		for b: String in ["thin", "medium", "heavy"]:
			for f: bool in [false, true]:
				var base: Dictionary = ZombieBody.base_parts(b, f)
				assert_true(base.has("Kit_" + k), "%s_%s GLB carries Kit_%s" % ["f" if f else "m", b, k])


func test_the_kit_covers_the_body_under_it() -> void:
	# the coverage bits 9-11 live in the body's red channel: a greatcoat body draws less skin than the base body
	var bit: int = ZombieBody.kit_bit("soviet")
	assert_gt(bit, 0x100, "past the old nine bits")
	var mesh: ArrayMesh = ZombieBody.build_skinned("soviet", "medium", false)
	var bare: Array = ZombieBody.base_parts("medium", false)["Body"]
	assert_lt((mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), (bare[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * 0.7,
		"the skin under the coat is dropped")
	assert_eq(ZombieBody.mask_of(Color(0, 0, 0, 1)), 0, "an older body vertex reads no Soviet bits")
	assert_eq(ZombieBody.mask_of(Color(1.0 / 255.0, 0, 0, 1)), 1 << 9)


func test_frost_skin_and_milky_eyes() -> void:
	var mesh: ArrayMesh = ZombieBody.build_skinned("soviet_tunic", "medium", false)
	var sm: ShaderMaterial = mesh.surface_get_material(0) as ShaderMaterial
	assert_not_null(sm)
	var vc: Color = sm.get_shader_parameter("vein_color")
	assert_lt(vc.r, vc.b, "cold blue-grey veins, not violet")
	assert_lt(float(sm.get_shader_parameter("vein_energy")), 0.5, "they barely glow")
	assert_true(ZombieBody.KIT_PALETTE.has("soviet_tunic"))
	var eye: Array = ZombieBody.KIT_PALETTE["soviet_tunic"]["eye"]
	assert_lt(float(eye[3]), 1.0, "no Nachtglas glow in the eyes")


func test_one_hat_at_most_with_the_cap_star_dull() -> void:
	for piece: String in ["pilotka", "ushanka", "ssh40"]:
		var g: Array = ZombieBody.gear_mesh(piece)
		assert_eq(str(g[0]), "Head")
		assert_not_null(g[1])
	for i: int in 30:
		var z: Zombie = _zombie(900 + i, "soviet")
		var hats: int = 0
		for gm: MeshInstance3D in z._gear:
			if gm.visible and gm.get_parent() is BoneAttachment3D and (gm.get_parent() as BoneAttachment3D).bone_name == "Head":
				hats += 1
		assert_lte(hats, 1, "one head, one hat")
		z.queue_free()
	assert_lt(float((ZombieBody.KEY_LOOK["accent"] as Array)[3]), 0.01, "the cap star never glows")


# ------------------------------------------------------------------ the wound

func test_never_marked_the_wound_instead() -> void:
	var z: Zombie = _zombie(5, "soviet")
	assert_true(z.is_wound(), "a Soviet risen's weak point is a wound")
	assert_true(ZombieBody.is_wound_site(z.marke_site))
	for site: StringName in z._marke_glint.keys():
		assert_false((z._marke_glint[site] as MeshInstance3D).visible, "no Marke glint at all")
	for ws: StringName in z._wound_nodes.keys():
		assert_eq((z._wound_nodes[ws] as MeshInstance3D).visible, ws == z.marke_site, "only its own wound shows")
	var hb: Hitbox = z.marke_hitbox()
	assert_not_null(hb)
	assert_eq(hb.limb, &"marke", "the same weak-point box the hit paths know")
	assert_eq(hb.collision_layer, Hitbox.LAYER_HITBOX)
	assert_eq(hb.bone, str(ZombieBody.WOUND_SITES[z.marke_site][0]))
	var kd: Dictionary = (GLData.table("anim")["kits"] as Dictionary)["soviet"]
	assert_true((kd["wound_sites"] as Array).has(String(z.marke_site)), "a site the kit allows")


func test_a_german_body_keeps_its_marke() -> void:
	var z: Zombie = _zombie(5, "soldier")
	assert_false(z.is_wound())
	assert_true(ZombieBody.MARKE_SITES.has(z.marke_site))
	for ws: StringName in z._wound_nodes.keys():
		assert_false((z._wound_nodes[ws] as MeshInstance3D).visible)
		assert_eq((z._wound_hb[ws] as Hitbox).collision_layer, 0)


func test_the_wound_is_deterministic_for_puppets() -> void:
	for id: int in [1, 2, 3, 17, 255]:
		assert_eq(ZombieBody.wound_site_for(id, "soviet_tunic"), ZombieBody.wound_site_for(id, "soviet_tunic"))
	var seen: Dictionary = {}
	for id2: int in 60:
		seen[ZombieBody.wound_site_for(id2, "soviet")] = true
	assert_gt(seen.size(), 1, "the sites vary across bodies")
	assert_eq(ZombieBody.wound_site_for(3, "soldier"), &"", "a kit without wound sites has none")


func test_the_wound_takes_the_marke_multiplier_and_pays_the_same() -> void:
	var mk: Dictionary = (GLData.table("enemies") as Dictionary)["marke"]
	var z: Zombie = _zombie(8, "soviet_burial", 10000.0)
	var host_limb: StringName = z.marke_host_limb()
	var hp0: float = z.hp
	z.take_damage(100.0, &"marke", &"m1911", 1, &"bullet", true)
	var dealt: float = hp0 - z.hp
	var z2: Zombie = _zombie(8, "soviet_burial", 10000.0)
	z2.take_damage(100.0, host_limb, &"m1911", 1, &"bullet", true)
	assert_almost_eq(dealt, (10000.0 - z2.hp) * float(mk["damage_mult"]), 0.5, "x damage_mult over the host limb")
	# a kill from it: the bonus, as the wound, and no Marke kill
	var z3: Zombie = _zombie(9, "soviet", 50.0)
	Economy.multiplier = 1
	z3.take_damage(9999.0, &"marke", &"m1911", 1, &"bullet")
	assert_eq(_marke_kills, 0, "no Marke kill (the stat, the Marke lines)")
	var found: bool = false
	for b: Array in _bonus:
		if b[1] == &"wound":
			found = true
			assert_eq(int(b[2]), int(mk["scrip_bonus"]), "the same bonus")
			assert_eq(str(b[3]), "THE WOUND")
	assert_true(found, "the wound bonus slip")


# ------------------------------------------------------------------ the spawns

func test_spawn_share_by_map_round_and_height() -> void:
	assert_eq(ZombieDirector.soviet_share("map00_crossroads", 1, 0.0), 0.0, "Map 0's scripted opening round stays as it was")
	assert_gt(ZombieDirector.soviet_share("map00_crossroads", 2, 0.0), 0.0, "Map 0 from round 2")
	assert_gt(ZombieDirector.soviet_share("map01_kaltenbrunn", 5, 0.0), 0.0, "Kaltenbrunn's surface")
	assert_eq(ZombieDirector.soviet_share("map01_kaltenbrunn", 5, -12.0), 0.0, "never in the depths")
	assert_eq(ZombieDirector.soviet_share("map01_kaltenbrunn", 5, -18.0), 0.0, "never in the Core")
	for m: String in ["map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]:
		assert_eq(ZombieDirector.soviet_share(m, 20, 0.0), 0.0, m + ": none")
	var c: Dictionary = (GLData.table("enemies") as Dictionary)["soviet_risen"]
	for k: Variant in (c["kits"] as Dictionary).keys():
		assert_true(ZombieBody.SOVIET_KITS.has(str(k)))


func test_pick_kit_follows_the_weights() -> void:
	var w: Dictionary = {"soviet": 0.5, "soviet_tunic": 0.3, "soviet_burial": 0.2}
	assert_eq(RisenColumn.pick_kit(w, 0.0), "soviet")
	assert_eq(RisenColumn.pick_kit(w, 0.6), "soviet_tunic")
	assert_eq(RisenColumn.pick_kit(w, 0.95), "soviet_burial")


func test_the_column_is_presentation_only() -> void:
	var col: RisenColumn = RisenColumn.make({"from": Vector3(20, 0, 0), "to": Vector3(-20, 0, 0), "count": 4, "seed": 3})
	_host.add_child(col)
	assert_eq(col.bodies.size(), 4)
	assert_eq(col.find_children("*", "CollisionObject3D", true, false).size(), 0, "nothing to collide with or shoot")
	assert_eq(col.find_children("*", "Hitbox", true, false).size(), 0)
	for b: Node3D in col.bodies:
		assert_false(b.is_in_group(&"zombies"))
		assert_true(ZombieBody.SOVIET_KITS.has(str(b.get_meta("kit", ""))), "a Soviet kit")
	var x0: float = col.bodies[0].position.x
	col._place_all(2.0)
	assert_lt(col.bodies[0].position.x, x0, "walking west along the line")
