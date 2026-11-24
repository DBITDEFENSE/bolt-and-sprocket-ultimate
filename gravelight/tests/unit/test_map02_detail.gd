extends GutTest
## T-273: Totenhafen's map detail pass (docs/u21/t273_map02_detail.md). The data and the generated scene, headless:
## the round-30 raid opens with the dive bomber on the moored patrol boat (its own banner and lines, the burst of the
## quay's concrete); the rest of the pass adds its own tests below as it lands.

const SCENE: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const DIRT_KINDS: Array = ["snow", "earth", "stone"]   # Effects._build_dirt's looks

var _m: Node = null


func after_all() -> void:
	if _m != null:
		_m.free()
		_m = null


func _json(key: String) -> Dictionary:
	return GLData.load_json("res://data/gravelight/%s.json" % key)


func _scene() -> Node:
	if _m == null:
		_m = (load(SCENE) as PackedScene).instantiate()
	return _m


func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


# ================================================================== 1. the raid's landmark

func test_the_dive_bomber_comes_down_on_the_patrol_boat_off_the_quay() -> void:
	var b: Dictionary = _json("map02")["sherman_event"]
	assert_true(b.has("stuka_target") and b.has("stuka_from"), "a landmark and a bearing")
	var tgt: Vector3 = _v3(b["stuka_target"])
	var r: float = float(ShermanEvent.merged(ShermanEvent.table(), b, "raid")["radius"])
	assert_lt(tgt.z, -15.0, "out over the sea, well off the parapet (z 0): %.1f" % tgt.z)
	# no player stands within the bomb's reach: the quay (x 0..32, z 0..30) and the two landing stages (z -3.2..0, behind
	# the barricaded sea windows) are far outside it
	var nearest: float = Vector2(clampf(tgt.x, 0.0, 32.0) - tgt.x, clampf(tgt.z, -3.2, 30.0) - tgt.z).length()
	assert_gt(nearest, r + 8.0, "the bomb lands %.1f m from the nearest ground anyone stands on" % nearest)
	var from: Vector3 = _v3(b["stuka_from"])
	assert_lt(from.z, tgt.z - 200.0, "it comes in from the north, over the sea the quay looks out on")
	assert_true(ShermanEvent.block_has_tank(b) == false, "still no tank")
	var s: Dictionary = ShermanEvent.merged(ShermanEvent.table(), b, "stuka")
	assert_true(str(s["banner_small"]).contains("PATROL BOAT") and not str(s["banner_small"]).contains("SHERMAN"), str(s["banner_small"]))


func test_the_boat_is_in_the_scene_where_the_bomb_falls() -> void:
	var m: Node = _scene()
	var vg: Node = m.get_node_or_null("StaticBatches/VisGroup_A")
	assert_not_null(vg, "the quay's batch group")
	if vg == null:
		return
	var boat_meshes: int = 0
	var lo: Vector3 = Vector3.INF
	var hi: Vector3 = -Vector3.INF
	for c: Node in vg.get_children():
		if String(c.name).begins_with("Batch_Boat_"):
			boat_meshes += 1
			var mi: MeshInstance3D = c as MeshInstance3D
			var bb: AABB = mi.transform * mi.mesh.get_aabb()
			lo = lo.min(bb.position)
			hi = hi.max(bb.end)
	assert_between(boat_meshes, 4, 40, "the boat is folded into a few meshes in the quay's batch group (%d)" % boat_meshes)
	var tgt: Vector3 = _v3(_json("map02")["sherman_event"]["stuka_target"])
	assert_true(AABB(lo, hi - lo).grow(0.5).has_point(tgt), "the target %s is on the boat %s..%s" % [str(tgt), str(lo), str(hi)])
	assert_gt(hi.y, tgt.y + 4.0, "its masts stand over the wheelhouse")
	assert_lt(hi.z, -8.0, "nothing of it reaches the shingle under the parapet (%.1f)" % hi.z)
	for nm: Variant in _json("map02")["sherman_event"].get("stuka_hit_show", []):
		var n: Node3D = m.find_child(str(nm), true, false) as Node3D
		assert_not_null(n, "%s is in the scene" % str(nm))
		if n != null:
			assert_false(n.visible, "%s waits hidden for the bomb" % str(nm))
			assert_eq(str(n.get_meta("vis", "")), "ALL", "the view cells leave it alone (else they would show it)")
			assert_false(n.is_in_group(&"view_cell_member"))
			for l: Node in n.find_children("*", "Light3D", true, false):
				assert_false((l as Light3D).shadow_enabled, "its fire light casts no shadow")


func test_the_raid_has_its_own_lines_and_burst() -> void:
	var b: Dictionary = _json("map02")["sherman_event"]
	var raid: Dictionary = ShermanEvent.merged(ShermanEvent.table(), b, "raid")
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var missing: Dictionary = GLData.load_json("res://data/gravelight/vo/audio_manifest.json").get("missing", {})
	for k: String in ["vo_warn", "vo_during", "vo_clear"]:
		var id: String = str(raid[k])
		assert_true(id.contains("_M2_"), "%s is this map's (%s)" % [k, id])
		assert_true(lines.has(id), "%s is a line" % id)
		if lines.has(id):
			assert_false(str(lines[id]["text"]).to_lower().contains("cellar"), id + " does not send anyone to the cellars")
	for id2: String in ["OPR_RAID_M2_WARN_01", "OPR_RAID_M2_CLEAR_01"]:
		assert_true(missing.has(id2), id2 + ": listed as not baked (a subtitle with a timed silence)")
	var kinds: Array = raid.get("burst", [])
	assert_false(kinds.is_empty(), "the quay's own burst")
	for k2: Variant in kinds:
		assert_true(DIRT_KINDS.has(str((k2 as Array)[0])), "a dirt kind Effects draws: %s" % str(k2))
	assert_eq(str((kinds[0] as Array)[0]), "stone", "concrete throws stone first")


func test_map0_and_kaltenbrunn_keep_their_raid() -> void:
	for key: String in ["map00", "map01"]:
		var b: Dictionary = _json(key)["sherman_event"]
		assert_false(b.has("stuka_hit_show"), key + ": nothing shown at the hit")
		assert_false(ShermanEvent.merged(ShermanEvent.table(), b, "raid").has("burst"), key + ": the default burst (snow and earth)")
	assert_false((ShermanEvent.table()["raid"] as Dictionary).has("burst"), "sherman.json keeps no burst row")
