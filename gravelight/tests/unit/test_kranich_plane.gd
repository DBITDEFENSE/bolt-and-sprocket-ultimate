extends GutTest
## T-220, the plane pass on Fernflug Act II: the comfort setting (CameraSway), the outer hull's clearances against the
## locked layout (KranichExterior's pure planform: the skin stays under the wing walk's grating and over every room roof,
## drops behind the starboard blisters, leaves the flight-deck glass clear), the exposure audio zones, the quiet-moment
## rule for the turbulence events, the world's bank and the dawn sun (KranichAir), the data, the sounds, the scene, and a
## headless build of the hull (no collider, a triangle budget).

const PLANE: String = "res://data/gravelight/map04b_plane.json"
const SCENE: String = "res://gravelight/maps/map04_fernflug/map04b.tscn"

var hull: Dictionary
var air: Dictionary
var walk: Dictionary
var bumps: Array


func before_all() -> void:
	var d: Dictionary = GLData.load_json(PLANE)
	hull = d.get("hull", {})
	air = d.get("air", {})
	walk = ((GLData.load_json("res://data/gravelight/map04b.json") as Dictionary).get("flight", {}) as Dictionary).get("wing_walk", {})
	bumps = KranichExterior.all_bumps(hull)


# ---------------------------------------------------------------- the comfort setting

func test_camera_sway_modes() -> void:
	assert_eq(CameraSway.normalize("Reduced"), "reduced")
	assert_eq(CameraSway.normalize("nonsense"), "full", "an unknown value reads as Full")
	assert_eq(CameraSway.normalize(true), "full")
	assert_eq(CameraSway.roll_deg(8.0, "full"), 8.0, "Full keeps the bank's roll")
	assert_almost_eq(CameraSway.roll_deg(8.0, "reduced"), 3.2, 0.001, "Reduced softens it")
	assert_eq(CameraSway.roll_deg(8.0, "off"), 0.0, "Off: no roll at all")
	assert_eq(CameraSway.shake_amount(0.2, "off"), 0.0, "Off: no flight shake")
	assert_lt(CameraSway.shake_amount(0.2, "reduced"), 0.2)
	assert_eq(CameraSway.shake_amount(0.2, "full"), 0.2)
	assert_eq(CameraSway.next("full"), "reduced")
	assert_eq(CameraSway.next("off"), "full")


func test_camera_sway_setting_default_and_shake() -> void:
	assert_true(GLSettings.values.has("camera_sway"), "GLSettings carries the camera_sway key")
	var keep: Variant = GLSettings.values["camera_sway"]
	# a stand-in with the Player's _shake property
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node3D\nvar _shake: float = 0.0\n"
	s.reload()
	var q: Node3D = s.new()
	GLSettings.values["camera_sway"] = "off"
	CameraSway.shake(q, 0.3)
	assert_eq(float(q.get("_shake")), 0.0, "Off: the flight's shake never reaches the camera")
	GLSettings.values["camera_sway"] = "full"
	CameraSway.shake(q, 0.3)
	assert_almost_eq(float(q.get("_shake")), 0.3, 0.001, "Full: the shake as authored")
	CameraSway.shake(q, 0.1)
	assert_almost_eq(float(q.get("_shake")), 0.3, 0.001, "never lowers a bigger running shake")
	GLSettings.values["camera_sway"] = keep
	q.free()


func test_every_flight_camera_source_reads_the_setting() -> void:
	var player: String = FileAccess.get_file_as_string("res://gravelight/player/player.gd")
	assert_true(player.contains("CameraSway.roll_deg(ext_roll_deg)"), "the bank / tilt roll goes through CameraSway")
	var fc: String = FileAccess.get_file_as_string("res://gravelight/world/map04/flight_controller.gd")
	assert_false(fc.contains("set(\"_shake\""), "FlightController sets no raw camera shake")
	var fs: String = FileAccess.get_file_as_string("res://gravelight/world/map04/flight_sky.gd")
	assert_false(fs.contains("set(\"_shake\""), "FlightSky sets no raw camera shake")
	var ka: String = FileAccess.get_file_as_string("res://gravelight/world/map04/kranich_air.gd")
	assert_false(ka.contains("set(\"_shake\""), "KranichAir shakes only through CameraSway")


# ---------------------------------------------------------------- the hull against the locked layout

func _walk_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for seg: Variant in walk.get("segments", []):
		var a: Array = (seg as Array)[0]
		var b: Array = (seg as Array)[1]
		for i: int in 7:
			for j: int in 5:
				out.append(Vector3(lerpf(float(a[0]), float(b[0]), float(i) / 6.0), 0.0, lerpf(float(a[1]), float(b[1]), float(j) / 4.0)))
	return out


func test_the_skin_runs_under_the_whole_wing_walk() -> void:
	var dy: float = float(walk.get("deck_y", 3.4))
	var worst_hi: float = -1e9
	var worst_lo: float = 1e9
	for p: Vector3 in _walk_points():
		assert_true(KranichExterior.in_planform(hull, p.x, p.z), "the wing walk at %s stands over the wing" % str(p))
		var y: float = KranichExterior.top_y(hull, p.x, p.z, bumps)
		worst_hi = maxf(worst_hi, y)
		worst_lo = minf(worst_lo, y)
	assert_lt(worst_hi, dy - 0.12 - 0.04, "the skin stays under the grating (its underside at deck_y - 0.12): max %.2f" % worst_hi)
	assert_gt(worst_lo, 2.8, "and covers the stanchions' feet (2.85): min %.2f" % worst_lo)


func test_the_skin_clears_every_room_roof() -> void:
	# [x0, z0, x1, z1, roof] the generator's rooms (ceilings + their 0.3 m lids), gen_map04b.gd
	var rooms: Array = [[-9, 0, 9, 24, 4.9], [-9, 24, 9, 54, 3.9], [-52, 28, -9, 46, 2.5], [9, 28, 52, 46, 2.5],
		[-78, 24, -52, 58, 5.1], [52, 24, 78, 58, 5.1], [-52, 50, -22, 58, 2.5], [22, 50, 52, 58, 2.5], [-22, 54, 22, 74, 5.1]]
	for r: Array in rooms:
		for i: int in 9:
			for j: int in 9:
				var x: float = lerpf(float(r[0]), float(r[2]), float(i) / 8.0)
				var z: float = lerpf(float(r[1]), float(r[3]), float(j) / 8.0)
				var y: float = KranichExterior.top_y(hull, x, z, bumps)
				if y < float(r[4]) + 0.2:
					assert_true(false, "the skin at (%.1f, %.1f) is %.2f, under the room roof %.2f" % [x, z, y, float(r[4])])
					return
	assert_true(true, "every room roof is inside the outer skin")


func test_the_blisters_and_the_glass_see_out() -> void:
	for bx: float in [56.0, 62.0, 68.0, 74.0]:
		assert_lt(KranichExterior.top_y(hull, bx, 21.5, bumps), 0.5, "the skin drops behind the blister at x %.0f (the gunner's field of fire)" % bx)
	for gx: float in [-20.0, 0.0, 20.0]:
		var le: float = KranichExterior.le_z(hull, gx)
		assert_almost_eq(le, 74.4, 0.01, "the flight-deck glass is the nose")
		assert_lte(KranichExterior.bottom_y(hull, gx, le - 0.01), 0.0, "the chin stays under the glass")
		assert_gte(KranichExterior.top_y(hull, gx, le - 0.01, bumps), float(hull.get("glass_top", 4.85)), "the brow stays over it")


func test_planform_is_a_closed_wing() -> void:
	for x: float in [-134.0, -100.0, -50.0, 0.0, 50.0, 100.0, 134.0]:
		assert_gt(KranichExterior.le_z(hull, x), KranichExterior.te_z(hull, x), "a positive chord at x %.0f" % x)
		var mid: float = (KranichExterior.le_z(hull, x) + KranichExterior.te_z(hull, x)) * 0.5
		assert_gt(KranichExterior.top_y(hull, x, mid, bumps), KranichExterior.bottom_y(hull, x, mid), "thickness at x %.0f" % x)
	assert_eq(KranichExterior.knot_z([[0.0, 1.0], [10.0, 3.0]], -5.0), 2.0, "the knots read |x| and interpolate")
	var cols: PackedFloat32Array = KranichExterior.grid_columns(hull, 2.0)
	assert_almost_eq(cols[0], -134.0, 0.001)
	assert_almost_eq(cols[cols.size() - 1], 134.0, 0.001)
	for i: int in range(1, cols.size()):
		assert_gt(cols[i], cols[i - 1], "columns ascend")
	var rows: PackedFloat32Array = KranichExterior.grid_rows(20)
	assert_eq(rows[0], 0.0)
	assert_almost_eq(rows[20], 1.0, 0.0001)


func test_the_hull_builds_without_colliders_and_within_budget() -> void:
	var ext: KranichExterior = KranichExterior.new()
	ext.build_on_ready = false
	add_child_autofree(ext)
	ext.build()
	assert_true(ext.built, "the hull builds headless")
	assert_eq(ext.find_children("*", "CollisionObject3D", true, false).size(), 0, "nothing in the hull collides")
	assert_eq(ext.find_children("*", "NavigationRegion3D", true, false).size(), 0, "nothing in it is navmesh")
	assert_gt(ext.tris, 20000, "a real hull (%d triangles)" % ext.tris)
	assert_lt(ext.tris, 110000, "inside the budget (%d triangles)" % ext.tris)
	var lights: int = 0
	for n: Node in ext.find_children("*", "Light3D", true, false):
		lights += 1
		assert_false((n as Light3D).shadow_enabled, "%s casts no shadow" % n.name)
	assert_lte(lights, 16, "few lights (%d)" % lights)


# ---------------------------------------------------------------- KranichAir

func test_exposure_zones() -> void:
	var ex: Dictionary = air["exposure"]
	var boxes: Array = ex["boxes"]
	var base: float = float(ex["base"])
	assert_almost_eq(KranichAir.exposure_at(Vector3(-80, 5.02, 21), boxes, [], base), 1.0, 0.001, "out on the wing walk: fully exposed")
	assert_lt(KranichAir.exposure_at(Vector3(-40, 1.62, 40), boxes, [], base), 0.1, "in the port crawlway under it: sheltered")
	assert_lt(KranichAir.exposure_at(Vector3(0, 1.62, 40), boxes, [], base), 0.1, "the centre body: sheltered")
	var bl: float = KranichAir.exposure_at(Vector3(65, 1.62, 26), boxes, [], base)
	assert_true(bl > 0.2 and bl < 0.6, "at the blisters: partly (%.2f)" % bl)
	var bay: float = KranichAir.exposure_at(Vector3(0, 1.62, 12), boxes, [[Vector3(0, 1, 12), 14.0, 0.72]], base)
	assert_gt(bay, 0.6, "the bay with its doors open")
	assert_eq(KranichAir.exposure_db(0.0, -48.0, -1.0), -48.0, "inside: the wind at its floor")
	assert_almost_eq(KranichAir.exposure_db(1.0, -48.0, -1.0), -1.0, 0.001, "outside: full")
	assert_lt(KranichAir.exposure_db(0.3, -48.0, -1.0, 1.4), KranichAir.exposure_db(0.6, -48.0, -1.0, 1.4), "louder the more exposed")


func test_turbulence_waits_for_a_quiet_moment() -> void:
	var q: Dictionary = (air["turbulence"] as Dictionary)["quiet"]
	assert_true(KranichAir.is_quiet({}, q), "nothing going on: quiet")
	for k: String in ["boss", "cutscene", "holdout", "banking", "decompression", "bomb_run", "london", "egg_step"]:
		assert_false(KranichAir.is_quiet({k: true}, q), "never during %s" % k)
	assert_false(KranichAir.is_quiet({"near_zombies": 5}, q), "not with the dead close")
	assert_false(KranichAir.is_quiet({"since_hurt_s": 1.0}, q), "not just after a hit")
	assert_false(KranichAir.is_quiet({"since_step_s": 3.0}, q), "not just after an egg step")
	assert_false(KranichAir.is_quiet({"tilt_soon_s": 4.0}, q), "not right before a tilt")
	var tu: Dictionary = air["turbulence"]
	assert_gte(float((tu["every_s"] as Array)[0]), 45.0, "rare: at least 45 s apart")


func test_bank_and_sun() -> void:
	var b: Dictionary = air["bank"]
	var mx: float = 0.0
	var mn: float = 0.0
	for i: int in 400:
		var v: float = KranichAir.bank_deg_at(float(i) * 0.5, b)
		mx = maxf(mx, v)
		mn = minf(mn, v)
	assert_lte(mx, float(b["deg"]) + 0.001, "a few degrees at most")
	assert_gt(mx, 0.5, "it banks one way")
	assert_lt(mn, -0.5, "and recovers past level the other")
	var s: Dictionary = air["sun"]
	assert_eq(KranichAir.sun_mix(0.0, s), 0.0, "night: the moon is the key light")
	assert_eq(KranichAir.sun_mix(0.85, s), 1.0, "the act's dawn: the sun")
	var dir: Vector3 = KranichAir.sun_dir(0.85, s)
	assert_lt(dir.z, -0.9, "the sun comes up behind the wing (aft)")
	assert_gt(dir.y, 0.0, "above the horizon")
	var lb: Basis = KranichAir.light_basis(dir)
	assert_almost_eq(lb.z.dot(dir), 1.0, 0.001, "the light comes from the sun")


# ---------------------------------------------------------------- data, sounds, scene

func test_sounds_exist() -> void:
	var a: Dictionary = (GLData.load_json("res://data/gravelight/audio.json") as Dictionary).get("sounds", {})
	for k: String in ["kranich_wind_roar", "kranich_engine_outside", "kranich_groan"]:
		assert_true(a.has(k), "audio.json has %s" % k)
		for f: Variant in (a[k] as Dictionary).get("files", []):
			assert_true(ResourceLoader.exists(str(f)), "%s exists" % f)
	assert_true(bool((a["kranich_wind_roar"] as Dictionary).get("loop", false)), "the wind roar loops")


func test_markings_are_stencils_on_the_wing() -> void:
	for mk: Variant in hull.get("markings", []):
		var a: Array = mk
		assert_true(int(a[4]) >= 0 and int(a[4]) < 8, "an atlas cell")
		assert_true(KranichExterior.in_planform(hull, float(a[0]), float(a[1])), "marking at (%s, %s) on the wing" % [a[0], a[1]])
	assert_true(ResourceLoader.exists(KranichExterior.MARKS_TEX), "the stencil atlas is imported")


func test_scene_carries_the_plane_pass() -> void:
	var t: String = FileAccess.get_file_as_string(SCENE)
	assert_true(t.contains("res://gravelight/world/map04/kranich_exterior.gd"), "map04b.tscn has KranichExterior")
	assert_true(t.contains("res://gravelight/world/map04/kranich_air.gd"), "map04b.tscn has KranichAir")
