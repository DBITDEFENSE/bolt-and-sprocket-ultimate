extends GutTest
## T-274 (the map detail pass on the Fernflug acts): the reactive dressing on all four acts (a "Reactive" node of
## Map 0's kit and LoosePapers / DecompReactive, every path it names resolves), LoosePapers' behaviour (lifted
## sheets fall and settle, a sink takes them for good, the Moon's gravity floats them), DecompReactive (a breach's
## pull throws the papers out and breaks the glass nearest it), Groom Lake's zip line (the data row and the drawn
## posts agree, it lands in the motor pool's lane by its post, chained until that zone opens), Thalbach's catwalk
## ladders (the drawn ladder, the players' rows and the dead's climb links on one line), and the desert horse's
## dressing (a coat of its own, a rail without snow or hay net; the snowy carter's rail stays the default).

const ACTS: Dictionary = {
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const GEN_A = preload("res://gravelight/tools_src/gen_map04a.gd")
const GEN_C = preload("res://gravelight/tools_src/gen_map04c.gd")

var maps: Dictionary = {}


func before_all() -> void:
	for k: String in ACTS.keys():
		maps[k] = (load(ACTS[k]) as PackedScene).instantiate()


func after_all() -> void:
	for k: String in maps.keys():
		(maps[k] as Node).free()
	maps.clear()


func _json(map: String) -> Dictionary:
	return GLData.load_json("res://data/gravelight/%s.json" % map)


func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _scripts_under(n: Node) -> Dictionary:
	var out: Dictionary = {}
	for c: Node in n.get_children():
		var s: Script = c.get_script() as Script
		if s != null:
			var f: String = s.resource_path.get_file()
			out[f] = int(out.get(f, 0)) + 1
	return out


func test_every_act_has_its_reactive_dressing() -> void:
	var want: Dictionary = {
		"map04a": {"swing_door.gd": 4, "draft_curtain.gd": 2, "shatter_set.gd": 3, "loose_papers.gd": 5, "drip_point.gd": 3},
		"map04b": {"loose_papers.gd": 2, "shatter_set.gd": 3, "decomp_reactive.gd": 2},
		"map04c": {"hay_puff_zone.gd": 3, "swing_door.gd": 3, "shatter_set.gd": 1, "loose_papers.gd": 3},
		"map04d": {"loose_papers.gd": 2, "hay_puff_zone.gd": 2},
	}
	for key: String in ACTS.keys():
		var r: Node = (maps[key] as Node).get_node_or_null("Reactive")
		assert_not_null(r, "%s has a Reactive node" % key)
		if r == null:
			continue
		var have: Dictionary = _scripts_under(r)
		for f: String in (want[key] as Dictionary).keys():
			assert_eq(int(have.get(f, 0)), int(want[key][f]), "%s: %d x %s (%s)" % [key, int(want[key][f]), f, str(have)])


func test_every_path_the_dressing_names_resolves() -> void:
	for key: String in ACTS.keys():
		var r: Node = (maps[key] as Node).get_node_or_null("Reactive")
		if r == null:
			continue
		for c: Node in r.get_children():
			if c is DraftCurtain and not (c.get("window") as NodePath).is_empty():
				assert_not_null(c.get_node_or_null(c.get("window")), "%s: %s's window" % [key, c.name])
			if c is DecompReactive:
				var b: Node = c.get_node_or_null(c.get("breach"))
				assert_not_null(b, "%s: %s's breach" % [key, c.name])
				assert_true(b != null and b.get_script() != null and (b.get_script() as Script).resource_path.ends_with("decompression.gd"), "%s: it is a decompression" % c.name)
				for p: NodePath in (c.get("papers") as Array) + (c.get("glass") as Array):
					assert_not_null(c.get_node_or_null(p), "%s: %s" % [c.name, p])


func test_loose_papers_lift_fall_and_settle() -> void:
	var lp: LoosePapers = LoosePapers.new()
	lp.count = 6
	lp.size = Vector3(1.5, 0, 1.0)
	add_child_autofree(lp)
	for i: int in lp.count:
		assert_almost_eq(lp.pos[i].y, 0.0, 0.02, "sheet %d lies on the surface" % i)
	lp.blow(lp.global_position + Vector3(2, 0, 0), 4.0, 10.0)
	assert_eq(lp.flying, 6, "a gust lifts them all")
	for f: int in 400:
		lp._process(1.0 / 60.0)
		if lp.flying == 0:
			break
	assert_eq(lp.flying, 0, "they come down again")
	for j: int in lp.count:
		assert_lt(lp.pos[j].y, 0.05, "sheet %d lies flat again" % j)
	assert_lt(lp.pos[0].x, 0.0, "blown away from the gust")


func test_the_moon_floats_them_and_a_sink_takes_them() -> void:
	var earth: LoosePapers = LoosePapers.new()
	var moon: LoosePapers = LoosePapers.new()
	moon.gravity = 1.62
	add_child_autofree(earth)
	add_child_autofree(moon)
	earth.lift(0, Vector3(0, 2.0, 0))
	moon.lift(0, Vector3(0, 2.0, 0))
	var t_e: int = 0
	var t_m: int = 0
	for f: int in 2000:
		if earth.flying > 0:
			earth._process(1.0 / 60.0)
			t_e = f
		if moon.flying > 0:
			moon._process(1.0 / 60.0)
			t_m = f
	assert_gt(t_m, t_e * 2, "a sheet takes far longer to come down on the Moon (%d vs %d frames)" % [t_m, t_e])
	var sunk: LoosePapers = LoosePapers.new()
	sunk.count = 5
	add_child_autofree(sunk)
	sunk.blow(sunk.global_position + Vector3(0, 0.5, -3.0), 9.0, 10.0, true)
	for f2: int in 600:
		sunk._process(1.0 / 60.0)
	var gone: int = 0
	for g: int in sunk.gone:
		gone += g
	assert_gt(gone, 2, "pulled out through the hole: %d of 5 gone" % gone)


class FakeBreach extends Node3D:
	var phase: int = 0
	func hole() -> Vector3:
		return global_position


func test_a_breach_pull_takes_the_papers_and_breaks_the_glass_near_it() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var br: FakeBreach = FakeBreach.new()
	br.name = "Breach"
	root.add_child(br)
	var lp: LoosePapers = LoosePapers.new()
	lp.name = "Papers"
	lp.position = Vector3(0, 0, 4)
	root.add_child(lp)
	var ss: ShatterSet = ShatterSet.new()
	ss.name = "Glass"
	ss.items = [[Vector3(0, 0, 2), "glass", 1.0], [Vector3(0, 0, 3), "bottle_green", 1.0], [Vector3(0, 0, 40), "jar", 1.0]]
	root.add_child(ss)
	var dr: DecompReactive = DecompReactive.new()
	dr.breach = NodePath("../Breach")
	dr.papers = [NodePath("../Papers")]
	dr.glass = [NodePath("../Glass")]
	dr.radius = 14.0
	root.add_child(dr)
	dr._process(0.2)
	assert_eq(dr.fired, 0, "nothing while the breach is shut")
	br.phase = 2
	dr._process(0.2)
	assert_eq(dr.fired, 1, "the pull fires it once")
	dr._process(0.2)
	assert_eq(dr.fired, 1, "and only once")
	assert_eq(lp.flying, lp.count, "every sheet is thrown")
	await get_tree().create_timer(0.6).timeout
	assert_eq(ss.broken_count(), 2, "the two pieces within reach broke, the far jar did not")


func test_groom_lakes_zip_line() -> void:
	var rows: Array = _json("map04c").get("ziplines", [])
	assert_eq(rows.size(), 1, "one zip line")
	if rows.is_empty():
		return
	var r: Dictionary = rows[0]
	var top: Vector3 = _v3(r["pos"])
	var end: Vector3 = _v3(r["end"])
	var to: Vector3 = _v3(r["to"])
	assert_almost_eq(top, GEN_C.ZIP_TOP, Vector3(0.01, 0.01, 0.01), "the row's top is the drawn arm's")
	assert_almost_eq(end, GEN_C.ZIP_POST + Vector3(0, GEN_C.ZIP_POST_H, 0), Vector3(0.01, 0.01, 0.01), "the row's end is the drawn post's top")
	assert_almost_eq(top.y, 16.0 + 2.0, 0.01, "2 m over the perch deck")
	var run: float = Vector2(end.x - top.x, end.z - top.z).length()
	var slope: float = rad_to_deg(atan2(top.y - end.y, run))
	assert_between(slope, 15.0, 30.0, "a cable's slope (%.1f degrees over %.1f m)" % [slope, run])
	assert_lt(Vector2(to.x - end.x, to.z - end.z).length(), 1.2, "the rider lands by the post")
	assert_eq(str(r.get("zone", "")), "D_MOTORPOOL", "chained until the lane's zone is open")
	var m: Node = maps["map04c"]
	assert_not_null(m.find_child("ZipPost_RadarZip", true, false), "the landing post is built")
	assert_not_null(m.find_child("ZipAnchorPost", true, false), "the anchor post is built")
	# the rider is set down in the lane (D_MOTORPOOL's box), not on the hangar or the radar yard
	var in_lane: bool = false
	for c: Node in m.get_node("Gameplay").get_children():
		var zv: ZoneVolume = c as ZoneVolume
		if zv != null and String(zv.zone_id) == "D_MOTORPOOL":
			var l: Vector3 = to + Vector3.UP * 0.3 - zv.position
			if absf(l.x) <= zv.size.x * 0.5 and absf(l.z) <= zv.size.z * 0.5 and l.y >= -0.5 and l.y <= zv.size.y:
				in_lane = true
	assert_true(in_lane, "the landing is in the motor pool's zone")


func test_thalbachs_catwalk_ladders() -> void:
	var j: Dictionary = _json("map04a")
	var ladders: Array = j.get("ladders", [])
	assert_eq(ladders.size(), 4, "a foot and a top row for each catwalk ladder")
	var links: Dictionary = {}
	for cl: Dictionary in j.get("climb_links", []):
		links[str(cl["name"])] = cl
	for side: String in ["W", "E"]:
		var cl2: Dictionary = links.get("Climb_CraneLadder" + side, {})
		assert_true(cl2.has("line") and bool(cl2.get("drop", false)), "%s: the dead climb one at a time and drop down" % side)
		for l: Dictionary in ladders:
			if str(l["name"]).begins_with("CraneLadder" + side):
				assert_eq(l["line"], cl2.get("line"), "%s: the players' rows and the dead's link share the line" % l["name"])
				assert_almost_eq(float((l["line"] as Array)[1]), GEN_A.CRANE_LADDER_Z, 0.01, "%s: on the drawn ladder" % l["name"])
	var m: Node = maps["map04a"]
	assert_not_null(m.find_child("Rail_CatwalkW2", true, false), "the west catwalk's rail has its gap")
	assert_not_null(m.find_child("Rail_CatwalkE2", true, false), "the east catwalk's rail has its gap")


func test_the_desert_horse_and_the_default_rail() -> void:
	var h: Dictionary = (_json("map04c").get("horses", []) as Array)[0]
	assert_true(HorseMesh.COATS.has(str(h.get("look", ""))), "Groom Lake's horse has a coat of its own (%s)" % h.get("look", ""))
	var dress: Dictionary = h.get("rail_dress", {})
	assert_false(bool(dress.get("snow", true)), "no snow on its rail")
	assert_false(bool(dress.get("hay_net", true)), "no hay net")
	for other: String in ["map01_kaltenbrunn", "map04a"]:
		var path: String = "res://data/gravelight/%s.json" % other
		if FileAccess.file_exists(path):
			for h2: Dictionary in GLData.load_json(path).get("horses", []):
				assert_false(h2.has("rail_dress"), "%s keeps the snowy rail" % other)
	var holder: Node3D = Node3D.new()
	add_child_autofree(holder)
	var snowy: Node3D = Horse.build_rail(holder, Vector3.ZERO, 0.0)
	var dry: Node3D = Horse.build_rail(holder, Vector3(5, 0, 0), 0.0, dress)
	assert_gt(_mats(snowy).count("snow"), 0, "the default rail wears snow")
	assert_gt(_mats(snowy).count("hay"), 0, "and its hay net")
	assert_eq(_mats(dry).count("snow"), 0, "the desert rail has none")
	assert_eq(_mats(dry).count("hay"), 0, "and no hay")
	var bay: ArrayMesh = HorseMesh.mesh("noriker")
	var buck: ArrayMesh = HorseMesh.mesh(str(h["look"]))
	assert_eq(bay.get_surface_count(), buck.get_surface_count(), "the same horse")


func _mats(n: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		for k: String in ["snow", "hay"]:
			if mi.material_override == Mats.get_mat(k):
				out.append(k)
	return out
