extends GutTest
## T-125: no invisible walls outside Map 0's barn. The owner: "outside the barn on the first map there are some
## invisible boundaries and walls we can't run or shoot through". The yard's split-rail fences were drawn as
## MultiMeshes by a headless generator, which saved no instance transforms, so they drew nowhere over their 2.3 m
## colliders; the empty crate spot by the well kept a baked 1.4 m box. Now: every MultiMesh in the map keeps its
## transforms (BakedMultiMesh), the blocking fences are solid to shots only up to their rails, and the crate
## spots' bake footprints are switched off at runtime.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const GEN: Script = preload("res://gravelight/tools_src/gen_map00.gd")

var map: Node


func before_all() -> void:
	map = (load(MAP) as PackedScene).instantiate()


func after_all() -> void:
	if map != null:
		map.free()


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c: Node in n.get_children():
		_all(c, out)
	return out


func test_every_multimesh_keeps_its_transforms() -> void:
	var count: int = 0
	for n: Node in _all(map, []):
		if n is MultiMeshInstance3D:
			count += 1
			assert_true(n is BakedMultiMesh, "%s is a BakedMultiMesh (a plain one saves no transforms headless)" % n.name)
			if n is BakedMultiMesh:
				var b: BakedMultiMesh = n
				assert_gt(b.transforms.size(), 0, "%s has transforms" % n.name)
				assert_eq(b.multimesh.instance_count, b.transforms.size(), "%s instance count matches" % n.name)
	assert_gt(count, 20, "the yard and grounds fences are there")


## World-layer colliders (they stop shots) in the yard and on the roadside fence line stand no higher than the
## drawn rails; the rest of the 2.3 m is on the edge layer (players only).
func test_fences_stop_shots_only_where_drawn() -> void:
	var tops: int = 0
	for n: Node in _all(map, []):
		if not (n is StaticBody3D) or not (str(n.name).begins_with("YardFence") or str(n.name).begins_with("GroundsFence")):
			continue
		var body: StaticBody3D = n
		var cs: CollisionShape3D = body.get_child(0) as CollisionShape3D
		var top: float = body.position.y + (cs.shape as BoxShape3D).size.y * 0.5
		if body.collision_layer & 1:
			assert_lte(top, GEN.FENCE_SOLID_H + 0.01, "%s at %s: shot-blocking part ends at the rails" % [n.name, str(body.position)])
		if str(n.name).ends_with("Top"):
			tops += 1
			assert_eq(body.collision_layer, GEN.EDGE_LAYER, "%s is players-only" % n.name)
	assert_gte(tops, 14, "the yard's fences have their players-only tops")


func test_crate_spot_footprints_are_bake_only() -> void:
	var blocks: int = 0
	var spots: int = 0
	for n: Node in _all(map, []):
		if n.is_in_group(&"bake_only"):
			assert_true(n is StaticBody3D, "%s is a baked footprint" % n.name)
			if String(n.name).begins_with("NavBlock_PerkSpot_"):
				spots += 1   # T-251: a perk spot's footprint (the machine's or the filler crate's own body stops you)
			else:
				blocks += 1
	assert_eq(blocks, GEN.CRATES.size(), "one switched-off footprint per crate spot")
	assert_eq(spots, GEN.PERK_SPOTS.size(), "and one per perk spot")
