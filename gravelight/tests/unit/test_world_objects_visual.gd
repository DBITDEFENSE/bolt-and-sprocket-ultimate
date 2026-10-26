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
