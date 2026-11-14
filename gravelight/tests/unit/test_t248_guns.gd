extends GutTest
## T-248 (2026-11-14, the owner: "TYPE 100 NEEDS SOME WORK, IT WOULD ALSO BE NICE TO ADD ANOTHER 3 OR 4 GUNS."):
## the Type 100 is modelled (no greybox), its side magazine comes out to the left, and four more guns (FG 42,
## Mosin-Nagant, Bren, Sten) are complete: data rows and Crucible rows, recoil, a crate slot, the bots' tiers, a fire
## sound, a downloaded model with the holder's contract, casings and a procedural twin.

const NEW: PackedStringArray = ["fg42", "mosin_nagant", "bren", "sten"]
const SIDE_OR_TOP_MAG: Dictionary = {"type100": Vector3.LEFT, "fg42": Vector3.LEFT, "sten": Vector3.LEFT, "bren": Vector3.UP}

var _w: Dictionary


func before_all() -> void:
	_w = GLData.table("weapons")
	GLSettings.values["greybox_guns"] = false


func _root_pos(root: Node3D, n: Node3D) -> Vector3:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin


func test_rows_and_crucible_rows() -> void:
	var rows: Dictionary = _w["weapons"]
	var up: Dictionary = _w["upgraded"]
	for id: String in NEW:
		assert_true(rows.has(id), id + " has a weapons.json row")
		var r: Dictionary = rows.get(id, {})
		var uid: String = str(r.get("upgraded", ""))
		assert_eq(uid, id + "_up", id + " names its Crucible row")
		assert_true(up.has(uid), uid + " exists")
		var u: Dictionary = up.get(uid, {})
		assert_eq(str(u.get("base", "")), id, uid + " points back at its base")
		assert_eq(str(u.get("class", "")), str(r.get("class", "")), uid + " keeps the class")
		assert_gt(float(u["damage"]), float(r["damage"]) * 2.0, uid + " hits much harder")
		assert_false((u.get("properties", {}) as Dictionary).is_empty(), uid + " has its bonus property")
		assert_true((_w["recoil"]["weapons"] as Dictionary).has(id), id + " has a recoil pattern")
		var wi: WeaponInstance = WeaponInstance.create(StringName(id))
		assert_not_null(wi, id + " instantiates")
		var wu: WeaponInstance = WeaponInstance.create(StringName(uid))
		assert_not_null(wu, uid + " instantiates")
	# no real-world maker's names in the display names
	for id: String in NEW:
		var nm: String = str(rows[id]["name"]).to_lower()
		for bad: String in ["mauser", "rheinmetall", "enfield", "browning", "colt", "walther", "beretta", "nambu"]:
			assert_false(nm.contains(bad), "%s's name has no maker's name (%s)" % [id, bad])


func test_type100_handling_change() -> void:
	var t: Dictionary = _w["weapons"]["type100"]
	assert_eq(int(t["damage"]), 52, "Type 100: 52 (8 mm, between the MP40's 50 and the Thompson's 55)")
	assert_eq(int(t["rpm"]), 800, "rate unchanged")
	assert_eq(int(t["mag"]), 30)
	assert_almost_eq(float(t["reload_partial"]), 2.1, 0.0001, "reload timings unchanged")
	assert_almost_eq(float(t["reload_empty"]), 2.7, 0.0001)
	var rc: Dictionary = _w["recoil"]["weapons"]["type100"]
	var smg_v: Array = []
	for id: String in ["mp40", "thompson", "ppsh41", "sten"]:
		smg_v.append(float((_w["recoil"]["weapons"][id] as Dictionary).get("v", 0.42)))
	assert_lt(float(rc["v"]), smg_v.min(), "the Type 100 climbs least of the SMGs (the heavy rifle stock)")


func test_crate_bots_sound_casings() -> void:
	var pool: Array = GLData.load_json("res://data/gravelight/crate.json")["pool"]
	var ids: Array = []
	for e: Dictionary in pool:
		ids.append(str(e["id"]))
	var tiers: Dictionary = GLData.load_json("res://data/gravelight/ai/economy.json")["weapon_tiers"]
	var casings: Dictionary = (WeaponGLB.models()["extras"]["cartridges"] as Dictionary)["casing_for"]
	for id: String in NEW:
		assert_true(ids.has(id), id + " can come out of the crate")
		assert_true(tiers.has(id), id + " has a bot weapon tier")
		assert_true(AudioDirector.has_sound("fire_" + id), id + " has its own fire sound")
		assert_true(casings.has(id), id + " ejects a casing")


func test_models_have_the_contract() -> void:
	for id: String in Array(NEW) + ["type100"]:
		assert_true(WeaponGLB.wants(StringName(id)), id + " is built from its GLB")
		var m: Node3D = WeaponModels.build(StringName(id))
		for n: String in ["Muzzle", "SightPoint", "FrontSight", "LeftHand"]:
			assert_not_null(m.find_child(n, true, false), "%s has %s" % [id, n])
		var kind: String = str(m.get_meta("reload"))
		assert_not_null(m.get_node_or_null("Bolt" if kind == "bolt" else "Mag"), "%s has the part its %s reload moves" % [id, kind])
		var mz: Vector3 = _root_pos(m, m.find_child("Muzzle", true, false) as Node3D)
		var rear: Vector3 = _root_pos(m, m.find_child("SightPoint", true, false) as Node3D)
		var front: Vector3 = _root_pos(m, m.find_child("FrontSight", true, false) as Node3D)
		assert_lt(mz.z, -0.3, id + " muzzle well ahead of the grip")
		assert_lt(front.z, rear.z, id + " front sight ahead of the rear")
		m.free()
		var g: Node3D = WeaponModels.build_greybox(StringName(id))
		assert_not_null(g.find_child("SightPoint", true, false), id + " procedural twin has sights")
		g.free()


func test_type100_is_modelled_with_its_silhouette() -> void:
	var e: Dictionary = WeaponGLB.entry(&"type100")
	assert_eq(str(e.get("source", "")), "ours", "the Type 100 is our own model")
	assert_false((WeaponGLB.models()["greybox"] as Array).has("type100"), "off the greybox list")
	var m: Node3D = WeaponModels.build(&"type100")
	var bb: AABB = WeaponModels.model_bounds(m)
	assert_between(bb.size.z, 0.82, 0.92, "real length (%.3f m)" % bb.size.z)
	var mag: Node3D = m.get_node("Mag") as Node3D
	var mb: AABB = WeaponKitModels._bounds(mag)
	var left: float = (mag.transform * mb.position).x
	assert_lt(left, -0.15, "the magazine sticks out of the LEFT side (%.3f)" % left)
	assert_gt(int((e["native"] as Dictionary)["tris"]), 10000, "hero-model detail")
	m.free()


func test_side_and_top_magazines_pull_out_their_way() -> void:
	for id: String in SIDE_OR_TOP_MAG.keys():
		var m: Node3D = WeaponModels.build(StringName(id))
		assert_true(m.has_meta("mag_dir"), id + " has a mag_dir")
		var d: Vector3 = (m.get_meta("mag_dir", Vector3.DOWN) as Vector3).normalized()
		assert_gt(d.dot(SIDE_OR_TOP_MAG[id]), 0.9, "%s's magazine comes out %s" % [id, str(SIDE_OR_TOP_MAG[id])])
		m.free()
	var plain: Node3D = WeaponModels.build(&"mp40")
	assert_false(plain.has_meta("mag_dir"), "an under-gun magazine keeps the default (down)")
	plain.free()


## The extended-magazine attachment grows a side magazine sideways (it used to hang a box down out of its flank).
func test_extended_side_magazine_grows_sideways() -> void:
	var w: WeaponInstance = WeaponInstance.create(&"type100")
	var bare: Node3D = WeaponModels.build(&"type100")
	var bm: Node3D = bare.get_node("Mag") as Node3D
	var b0: AABB = WeaponKitModels._bounds(bm)
	w.kit["mag"] = "extended"
	var kitted: Node3D = WeaponModels.build(&"type100", false, &"", WeaponKitModels.look_of(w))
	var km: Node3D = kitted.get_node("Mag") as Node3D
	var b1: AABB = WeaponKitModels._bounds(km)
	assert_lt(b1.position.x, b0.position.x - 0.03, "the extension continues the magazine to the left")
	assert_almost_eq(b1.position.y, b0.position.y, 0.01, "and not downward")
	bare.free()
	kitted.free()
