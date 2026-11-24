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


# ================================================================== 2. the catwalk ladders, the signal balcony's zip line

func _gen_const(nm: String) -> Variant:
	return (load("res://gravelight/tools_src/gen_map02.gd") as GDScript).get_script_constant_map().get(nm)


## True when `p` stands on one of the scene's baked navmesh regions (inside a polygon within 0.6 m of its height).
func _on_nav(p: Vector3) -> bool:
	for r: Node in _scene().find_children("Nav_*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = (r as NavigationRegion3D).navigation_mesh
		if nm == null:
			continue
		var verts: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var plan: PackedVector2Array = []
			var y: float = 0.0
			var idx: PackedInt32Array = nm.get_polygon(i)
			for j: int in idx:
				plan.append(Vector2(verts[j].x, verts[j].z))
				y += verts[j].y
			if absf(y / float(idx.size()) - p.y) < 0.6 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), plan):
				return true
	return false


func _zone(p: Vector3) -> String:
	for n: Node in _scene().find_children("Zone_*", "", true, false):
		var c: Vector3 = (n as Node3D).position
		var s: Vector3 = n.get("size")
		if absf(p.x - c.x) <= s.x * 0.5 and absf(p.z - c.z) <= s.z * 0.5 and p.y - c.y >= -0.5 and p.y - c.y <= s.y:
			return str(n.get("zone_id"))
	return ""


func test_the_three_catwalk_ladders_are_drawn_on_the_climb_links() -> void:
	var d: Dictionary = _json("map02")
	var ladders: Dictionary = {}
	for l: Dictionary in d["ladders"]:
		ladders[str(l["name"])] = l
	var links: Dictionary = {}
	for k: Dictionary in d["climb_links"]:
		links[str(k["name"])] = k
	var drawn: Array = _gen_const("CATWALK_LADDERS")
	assert_eq(drawn.size(), 3, "three drawn ladders")
	for row: Array in drawn:
		var side: String = str(row[0])
		var pos: Vector3 = row[1]
		var out: Vector3 = Basis(Vector3.UP, deg_to_rad(float(row[2]))) * Vector3(0, 0, -1)
		var line: Vector2 = Vector2(pos.x + out.x * 0.515, pos.z + out.z * 0.515)
		var up: Dictionary = ladders.get("Catwalk%s_Up" % side, {})
		var dn: Dictionary = ladders.get("Catwalk%s_Down" % side, {})
		var lk: Dictionary = links.get("Ladder_Catwalk" + side, {})
		assert_false(up.is_empty() or dn.is_empty() or lk.is_empty(), side + ": both LadderClimbs and the climb link")
		if up.is_empty() or dn.is_empty() or lk.is_empty():
			continue
		for r: Dictionary in [up, dn, lk]:
			assert_lt(Vector2(float(r["line"][0]), float(r["line"][1])).distance_to(line), 0.02, "%s: on the drawn ladder's line, 0.4 m off its rungs" % side)
		assert_true(bool(lk.get("drop", false)) and bool(lk.get("bidirectional", false)), side + ": the dead climb it one at a time and drop back down")
		assert_almost_eq(_v3(up["to"]).y, 4.0, 0.01, side + ": it ends on the catwalk")
		assert_lt(_v3(lk["from"]).distance_to(_v3(up["pos"])), 0.05, side + ": the zombies' foot is the players' foot")
		assert_lt(_v3(lk["to"]).distance_to(_v3(up["to"])), 0.05, side + ": the zombies' head is the players' head")
		for p: Vector3 in [_v3(up["pos"]), _v3(up["to"]), _v3(dn["pos"]), _v3(dn["to"])]:
			assert_true(_on_nav(p), "%s: %s is on the baked navmesh" % [side, str(p)])
			assert_eq(_zone(p + Vector3.UP * 0.6), "D_PENHALL", "%s: %s is in the Pen Hall" % [side, str(p)])
	# no catwalk spawn crowds a ladder's head
	for cp: Node in _scene().find_children("Catwalk_D_PENHALL_*", "", true, false):
		for side2: String in ["W", "N", "E"]:
			var head: Vector3 = _v3(ladders["Catwalk%s_Up" % side2]["to"])
			assert_gt((cp as Node3D).position.distance_to(head), 3.9, "%s's head is clear of the spawn %s" % [side2, cp.name])


func test_the_signal_balcony_zip_line() -> void:
	var rows: Array = _json("map02").get("ziplines", [])
	assert_eq(rows.size(), 1, "one zip line")
	if rows.is_empty():
		return
	var row: Dictionary = rows[0]
	var sz: Array = _gen_const("SIGNAL_ZIP")
	var a: Vector3 = _v3(row["pos"])
	var e: Vector3 = _v3(row["end"])
	var to: Vector3 = _v3(row["to"])
	assert_lt(a.distance_to(sz[1] as Vector3), 0.01, "the anchor is the generator's (SIGNAL_ZIP)")
	assert_lt(Vector2(e.x, e.z).distance_to(Vector2((sz[2] as Vector3).x, (sz[2] as Vector3).z)), 0.01, "the cable ends on the generator's post")
	assert_almost_eq(e.y, float(_gen_const("ZIP_POST_H")), 0.01, "...at the post's top")
	assert_almost_eq(a.y, 7.0 + 2.0, 0.05, "2 m over the balcony (a standing rider's hands reach the bar)")
	assert_between(a.x, float(_gen_const("BALC_X0")) + 0.5, float(_gen_const("BALC_X1")) - 0.5, "over the balcony's width")
	assert_between(a.z - float(_gen_const("BALC_Z1")), 0.05, 0.3, "a step outside its south rail")
	var run: float = Vector2(e.x - a.x, e.z - a.z).length()
	var slope: float = rad_to_deg(atan2(a.y - e.y, run))
	assert_between(slope, 15.0, 30.0, "a cable's slope (%.1f degrees over %.1f m)" % [slope, run])
	assert_lt(9.8 * sin(deg_to_rad(slope)), 5.0, "the trolley's brake holds the speed cap on this slope")
	var back: Vector3 = to - e
	assert_between(Vector2(back.x, back.z).length(), 0.5, 1.5, "set down a step short of the post")
	assert_gt(Vector2(back.x, back.z).normalized().dot(Vector2(a.x - e.x, a.z - e.z).normalized()), 0.95, "...on the line, the tower's side of the post")
	assert_almost_eq(e.y - to.y, float(row.get("hang", 2.7)), 0.3, "the feet come in just over the floor")
	assert_true(_on_nav(to), "the landing is on the baked navmesh")
	assert_true(_on_nav(Vector3(a.x, 7.0, a.z - 1.0)), "the balcony is on the baked navmesh (the dead reach a rider waiting there)")
	assert_eq(_zone(Vector3(a.x, 7.0, a.z - 1.0) + Vector3.UP * 0.6), "G_SIGNAL", "the balcony is the signal tower's zone")
	assert_eq(_zone(to + Vector3.UP * 0.6), "D_PENHALL", "it lands in the Pen Hall: the zone the tower is reached through, so no door is skipped")
	assert_eq(str(row.get("zone", "")), "", "so it needs no chain")
	for sp: Node in _scene().find_children("*", "Marker3D", true, false):
		if sp.get("zone_id") != null and sp.get("kind") != null:
			var sp_at: Vector3 = (sp as Node3D).position
			assert_gt(Vector2(sp_at.x - to.x, sp_at.z - to.z).length(), 3.5, "clear of the spawn %s" % sp.name)
	var post: Node3D = _scene().find_child("ZipPost_SignalZip", true, false) as Node3D
	assert_true(post != null and Vector2(post.position.x - e.x, post.position.z - e.z).length() < 0.05, "the generator built the post where the cable ends")
	var cables: Array = (_json("map02")["tide"] as Dictionary).get("cables", [])
	for c: Dictionary in cables:
		assert_gt(Vector2(float(c["pos"][0]) - to.x, float(c["pos"][2]) - to.z).length(), float(c["radius_m"]) + 1.0, "the landing is clear of the tide's live cable %s" % str(c["id"]))
