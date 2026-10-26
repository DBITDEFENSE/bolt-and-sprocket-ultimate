extends GutTest
## UPDATE_05 section 5 (T-094): the world objects' art. Every object builds its visual headless from our own models
## (assets/ours/world/*, WorldArt), the visual carries no collision of its own, it stays inside the object's footprint,
## the gameplay colliders and interaction areas are the ones the scripts always made (UPDATE_05 section 0.4: art never
## moves gameplay), the nine tonic cabinets each have their own model and their own PerkCap glyph on the sign, and
## the cabinets are dark until the power is on.

const PERKS: Array[StringName] = [&"ironhide_stout", &"second_wind", &"trigger_tonic", &"twin_barrel", &"marathon_malt",
	&"hawkeye_brandy", &"packmule_porter", &"blastproof_bock", &"overclock_cordial"]
## How far a visual may reach past its collider footprint sideways (the old procedural art did the same: Ironhide's
## steam valve, Trigger Tonic's lever, Packmule's wheels and gallows) and above it (the signs).
const SIDE_SLACK: float = 0.26
const TOP_SLACK: float = 0.95
## Packmule's tin "Porter" sign swings from a gallows off its left end, where the procedural cabinet hung it too.
const SIDE_EXTRA: Dictionary = {&"packmule_porter": 0.18}

var _was_power: bool = false


func before_all() -> void:
	_was_power = GameState.power_on


func after_all() -> void:
	GameState.power_on = _was_power


## No collision of any kind under a visual node.
func _assert_no_collision(n: Node, what: String) -> void:
	var found: Array = []
	_find_collision(n, found)
	assert_eq(found.size(), 0, "%s: no collision under its visual (%s)" % [what, str(found)])


func _find_collision(n: Node, out: Array) -> void:
	if n is CollisionObject3D or n is CollisionShape3D:
		out.append(String(n.name))
	for c: Node in n.get_children():
		_find_collision(c, out)


func _box_of(owner: Node, body_type: String) -> BoxShape3D:
	for c: Node in owner.get_children():
		if c.get_class() == body_type or (body_type == "Area3D" and c is Area3D) or (body_type == "StaticBody3D" and c is StaticBody3D):
			for s: Node in c.get_children():
				if s is CollisionShape3D and (s as CollisionShape3D).shape is BoxShape3D:
					return (s as CollisionShape3D).shape as BoxShape3D
	return null


# ================================================================== the nine cabinets

func _machine(id: StringName) -> PerkMachine:
	var m: PerkMachine = PerkMachine.new()
	m.perk_id = id
	add_child_autofree(m)
	return m


func test_every_cabinet_model_exists() -> void:
	for id: StringName in PERKS:
		assert_true(WorldArt.has("perk_" + String(id)), "assets/ours/world/perk_%s/model.glb is imported" % id)


func test_cabinets_keep_their_colliders_and_areas() -> void:
	GameState.power_on = false
	for id: StringName in PERKS:
		var m: PerkMachine = _machine(id)
		var shape: String = str((GLData.table("perks")["perks"] as Dictionary)[String(id)].get("shape", "cabinet"))
		var fp: Vector3 = PerkMachine._shape_footprint(shape)
		var body: BoxShape3D = _box_of(m, "StaticBody3D")
		assert_not_null(body, "%s has its body" % id)
		if body != null:
			assert_eq(body.size, fp, "%s: the collider is the footprint" % id)
		var area: BoxShape3D = _box_of(m, "Area3D")
		assert_not_null(area, "%s has its interaction area" % id)
		if area != null:
			assert_eq(area.size, Vector3(fp.x + 0.3, 1.8, 0.25), "%s: the interaction area is unchanged" % id)
		var art: Node3D = m.get_node_or_null("Greybox") as Node3D
		assert_not_null(art, "%s has its visual" % id)
		if art == null:
			continue
		assert_not_null(WorldArt.part(art, "Body"), "%s: the cabinet model (not the procedural fallback)" % id)
		_assert_no_collision(art, String(id))
		var bb: AABB = WorldArt.local_aabb(art)
		assert_gt(bb.position.y, -0.02, "%s: nothing under the floor" % id)
		assert_lt(bb.end.y, fp.y + TOP_SLACK, "%s: no taller than the old sign (%.2f)" % [id, bb.end.y])
		assert_lt(maxf(-bb.position.x, bb.end.x), fp.x * 0.5 + SIDE_SLACK + float(SIDE_EXTRA.get(id, 0.0)), "%s: inside the footprint sideways (%s)" % [id, bb])
		assert_lt(maxf(-bb.position.z, bb.end.z), fp.z * 0.5 + SIDE_SLACK, "%s: inside the footprint front to back (%s)" % [id, bb])
		assert_lt(WorldArt.triangles(art), 9000, "%s: within the hero-cabinet budget" % id)


func test_each_cabinet_is_its_own_model_with_its_own_cap() -> void:
	var seen: Dictionary = {}   # Body mesh -> perk
	for id: StringName in PERKS:
		var m: PerkMachine = _machine(id)
		var art: Node3D = m.get_node_or_null("Greybox") as Node3D
		var body: MeshInstance3D = WorldArt.mesh_of(WorldArt.part(art, "Body"))
		assert_not_null(body, "%s: a Body mesh" % id)
		if body == null:
			continue
		assert_false(seen.has(body.mesh), "%s: its own shell (not %s's)" % [id, seen.get(body.mesh, "")])
		seen[body.mesh] = id
		assert_not_null(WorldArt.part(art, "Dispense"), "%s: the bottle the hatch dispenses" % id)
		assert_not_null(WorldArt.part(art, "Neon"), "%s: neon tubes" % id)
		var cap: Sprite3D = art.find_child("PerkCapSign", true, false) as Sprite3D
		assert_not_null(cap, "%s: the PerkCap medallion on the sign" % id)
		if cap != null:
			assert_eq(StringName(cap.get_meta("perk", &"")), id, "%s: the cap shows its own tonic" % id)
			assert_true(PerkCap.has_glyph(id) and bool(cap.get_meta("glyph", false)), "%s: a drawn glyph, not letters" % id)
			assert_lt(cap.global_position.y, m.global_position.y + 2.85, "%s: the cap is on the sign, under the vault" % id)
	assert_eq(seen.size(), PERKS.size(), "nine different shells")


func test_cabinets_are_dark_until_the_power() -> void:
	GameState.power_on = false
	var m: PerkMachine = _machine(&"trigger_tonic")
	var art: Node3D = m.get_node("Greybox")
	var neon: MeshInstance3D = WorldArt.mesh_of(WorldArt.part(art, "Neon"))
	var glow: OmniLight3D = art.find_child("PerkGlow", true, false) as OmniLight3D
	assert_eq(neon.material_override, Mats.get_mat("neon_off"), "unpowered: the tubes are dark glass")
	assert_false(glow.visible, "unpowered: no lamp light")
	GameState.power_on = true
	m.call("_refresh_power")
	assert_ne(neon.material_override, Mats.get_mat("neon_off"), "powered: the tubes are lit")
	assert_true(glow.visible, "powered: the lamp is on")
	GameState.power_on = false


func test_dispensed_bottle_is_hidden_until_a_drink() -> void:
	var m: PerkMachine = _machine(&"ironhide_stout")
	var bottle: Node3D = WorldArt.part(m.get_node("Greybox"), "Dispense")
	assert_false(bottle.visible, "no bottle in the hatch at rest")
	m.call("_cab_dispense")
	assert_true(bottle.visible, "a purchase drops the tonic's bottle into the hatch")


# ================================================================== everything else: art on, art off, same colliders

## How far the new art may outgrow the procedural art it replaces (the ammo crate's lid now stands open against the
## wall; the Crucible's flue is shorter, the bench's lamp the same).
const GROW_SLACK: float = 0.6


## Every collision shape under `o` (type, size, place relative to o), sorted: the gameplay footprint of an object.
func _shapes(o: Node3D) -> Array:
	var out: Array = []
	_collect_shapes(o, o, out)
	out.sort()
	return out


func _collect_shapes(n: Node, o: Node3D, out: Array) -> void:
	if n is CollisionShape3D:
		var cs: CollisionShape3D = n as CollisionShape3D
		var desc: String = cs.shape.get_class()
		if cs.shape is BoxShape3D:
			desc += " %s" % str((cs.shape as BoxShape3D).size.snapped(Vector3.ONE * 0.001))
		var xf: Transform3D = o.global_transform.affine_inverse() * cs.global_transform
		out.append("%s %s @%s" % [n.get_parent().get_class(), desc, str(xf.origin.snapped(Vector3.ONE * 0.001))])
	for c: Node in n.get_children():
		_collect_shapes(c, o, out)


## Builds the object twice, first with the procedural art (WorldArt off, as before UPDATE_05) and then with ours, and
## checks the colliders and areas are identical, that ours is really there (`art_node`), carries no collision and
## stays within the old art's bounds.
func _compare_art(what: String, make: Callable, art_node: String) -> void:
	WorldArt._off = 1
	var old: Node3D = make.call()
	add_child(old)
	var want: Array = _shapes(old)
	var old_box: AABB = WorldArt.local_aabb(old)
	var had_art: bool = art_node != "" and old.find_child(art_node, true, false) != null
	old.free()
	WorldArt._off = 0
	var o: Node3D = make.call()
	add_child_autofree(o)
	assert_false(had_art, "%s: the procedural build has no %s (the comparison is fair)" % [what, art_node])
	var art: Node = o.find_child(art_node, true, false) if art_node != "" else o
	assert_not_null(art, "%s: our model is used (%s)" % [what, art_node])
	assert_eq(_shapes(o), want, "%s: the same colliders and interaction areas as before" % what)
	if art != null and art != o:
		_assert_no_collision(art, what)
	var box: AABB = WorldArt.local_aabb(o)
	var grown: AABB = old_box.grow(GROW_SLACK)
	assert_true(grown.encloses(box), "%s: the art stays within the old bounds (old %s, new %s)" % [what, old_box, box])


func after_each() -> void:
	WorldArt._off = -1


func test_crate() -> void:
	var make: Callable = func() -> Node3D:
		var c: MysteryCrate = MysteryCrate.new()
		c.spot_index = 0
		return c
	_compare_art("Requisition Crate", make, "Lid")


func test_ammo_box() -> void:
	var make: Callable = func() -> Node3D: return AmmoBox.new()
	_compare_art("ammo box", make, "Model")


func test_barricade() -> void:
	var make: Callable = func() -> Node3D:
		var b: Barricade = Barricade.new()
		b.window_id = &"W_TEST"
		return b
	_compare_art("barricade", make, "")
	# the planks are our models (shared meshes), one variant per slot
	var b2: Barricade = Barricade.new()
	add_child_autofree(b2)
	var ours: Dictionary = {}
	for i: int in 6:
		ours[WorldArt.part_mesh("barricade_planks", "Plank%d" % i)] = true
	var seen: Dictionary = {}
	for c: Node in b2.get_children():
		if c is MeshInstance3D:
			assert_true(ours.has((c as MeshInstance3D).mesh), "a barricade board is one of our planks")
			seen[(c as MeshInstance3D).mesh] = true
	assert_eq(seen.size(), 6, "six different planks in a window")


func test_buy_door() -> void:
	var make: Callable = func() -> Node3D:
		var d: BuyDoor = BuyDoor.new()
		d.size = Vector3(1.6, 2.4, 0.25)
		d.label = "Upstairs"
		d.cost = 750
		return d
	_compare_art("bought door", make, "Plaque")


func test_gate() -> void:
	var make: Callable = func() -> Node3D:
		var g: GateDoor = GateDoor.new()
		g.size = Vector3(4.0, 2.3, 0.25)
		g.label = "The Gate"
		g.cost = 750
		return g
	_compare_art("the carters' gate", make, "Hinge")


func test_wall_buy() -> void:
	var make: Callable = func() -> Node3D:
		var w: WallBuy = WallBuy.new()
		w.weapon_id = &"kar98k"
		return w
	_compare_art("wall-buy", make, "MountedGun")


func test_bench() -> void:
	var make: Callable = func() -> Node3D: return ArmorersBench.new()
	_compare_art("Armorer's Bench", make, "Model")


func test_crucible() -> void:
	var make: Callable = func() -> Node3D:
		var c: Crucible = Crucible.new()
		c.needs_power = true
		return c
	_compare_art("Crucible", make, "Model")


func test_radio() -> void:
	var make: Callable = func() -> Node3D: return FieldRadio.new()
	_compare_art("field radio", make, "Model")


func test_power_lever() -> void:
	var make: Callable = func() -> Node3D:
		var s: PowerSwitch = PowerSwitch.new()
		s.config_table = "map00"
		return s
	_compare_art("power lever", make, "Lever")


func test_exfil_beacon() -> void:
	var make: Callable = func() -> Node3D: return ExfilPoint.new()
	_compare_art("exfil beacon", make, "Model")
