extends GutTest
## ADS alignment (Update 02 §2, T-047), checked as math without rendering: for every weapon (base + upgraded),
## fully aimed, its SightPoint (rear sight) and FrontSight (front post / bead) markers must project onto the
## screen center within 1.5 px at 720 p, through the real viewmodel rig transform (viewmodel-FOV scale and
## anti-clipping compression), for several FOV settings and compressions, while pressed against a wall, and
## under screen shake. Also: every gun model has both markers, eye relief / ADS zoom come from data, and the
## Thompson's sight line clears its own receiver.

const TOL_PX: float = 1.5
const H: float = 720.0

var _p: Player


func before_each() -> void:
	_p = Player.new()
	add_child_autofree(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(GLData.table("weapons")["feel"] as Dictionary).erase("viewmodel_compress")


func _ids() -> Array[String]:
	var out: Array[String] = []
	var t: Dictionary = GLData.table("weapons")
	for k: Variant in (t["weapons"] as Dictionary).keys():
		out.append(str(k))
	for k2: Variant in (t["upgraded"] as Dictionary).keys():
		out.append(str(k2))
	return out


func _aim(id: String) -> WeaponHolder:
	var h: WeaponHolder = _p.weapons
	h.slots.clear()
	h.give_weapon(StringName(id))
	h.current_index = h.slots.find(h.find_weapon(StringName(id)))
	h.call("_rebuild_gun")
	h.set("_swap_t", 0.0)
	h.steady = true
	h.ads_t = 1.0
	h.call("_animate", 1.0 / 60.0, false)
	return h


## Worst pixel distance from the (possibly shaken) screen center of both sight marks, camera fov `fov`.
func _worst_px(h: WeaponHolder, fov: float, live: bool) -> float:
	var worst: float = 0.0
	var eye: Vector3 = Vector3(_p.camera.h_offset, _p.camera.v_offset, 0.0)
	for p: Vector3 in h.sight_marks_camera(live):
		worst = maxf(worst, WeaponHolder.project_offset_px(p - eye, fov, H).length())
	return worst


func test_every_gun_model_has_sight_markers() -> void:
	for id: String in _ids():
		var m: Node3D = WeaponModels.build(StringName(id))
		assert_not_null(m.find_child("SightPoint", true, false), id + " has a SightPoint")
		assert_not_null(m.find_child("FrontSight", true, false), id + " has a FrontSight")
		var sp: Node3D = m.find_child("SightPoint", true, false) as Node3D
		var fs: Node3D = m.find_child("FrontSight", true, false) as Node3D
		if sp != null and fs != null:
			# the front sight is ahead of the rear one (the barrel runs along -Z)
			assert_lt(_model_pos(m, fs).z, _model_pos(m, sp).z, id + " front ahead of rear")
		m.free()


func _model_pos(root: Node3D, n: Node3D) -> Vector3:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin


func test_ads_data_is_per_weapon() -> void:
	for id: String in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		var row: Dictionary = GLData.table("weapons")["weapons"][id]
		var feel: Dictionary = row.get("feel", {})
		assert_true(feel.has("eye_relief"), id + " has a data eye relief")
		assert_true(feel.has("ads_zoom"), id + " has a data ADS zoom")
	var h: WeaponHolder = _aim("thompson")
	assert_almost_eq(h.ads_zoom(h.current()), 0.9, 0.031, "Thompson ADS is about a 10% zoom")
	_aim("thompson_up")
	assert_almost_eq(h.ads_zoom(h.current()), 0.9, 0.031, "the upgraded Thompson inherits it")


func test_sights_on_center_for_every_weapon() -> void:
	for id: String in _ids():
		var h: WeaponHolder = _aim(id)
		var fov: float = 80.0 * h.fov_mult()
		assert_lt(_worst_px(h, fov, false), TOL_PX, id + ": ADS pose math puts both sights on the center")
		assert_lt(_worst_px(h, fov, true), TOL_PX, id + ": the drawn viewmodel puts both sights on the center")


func test_fov_and_compression_keep_the_sight_line() -> void:
	var feel_root: Dictionary = GLData.table("weapons")["feel"]
	for comp: float in [1.0, 0.25, 0.1]:
		feel_root["viewmodel_compress"] = comp
		for base_fov: float in [65.0, 80.0, 110.0]:
			for id: String in ["thompson", "m1911", "kar98k", "panzerschreck", "trench_gun"]:
				var h: WeaponHolder = _aim(id)
				_p.camera.fov = base_fov * h.fov_mult()
				h.call("_animate", 1.0 / 60.0, false)
				var px: float = _worst_px(h, _p.camera.fov, true)
				assert_lt(px, TOL_PX, "%s at fov %d, compress %.2f: %.3f px" % [id, int(base_fov), comp, px])


func test_wall_pull_and_shake_keep_the_sight_line() -> void:
	for id: String in ["thompson", "mp40", "bar"]:
		var h: WeaponHolder = _aim(id)
		h.set("_wall_b", 1.0)
		h.call("_animate", 0.0, false)                 # delta 0: the wall pull stays fully on
		assert_lt(_worst_px(h, 80.0 * h.fov_mult(), true), TOL_PX, id + " pressed against a wall")
		_p.camera.h_offset = 0.012
		_p.camera.v_offset = -0.009
		h.call("_animate", 0.0, false)
		assert_lt(_worst_px(h, 80.0 * h.fov_mult(), true), TOL_PX, id + " under screen shake")
		_p.camera.h_offset = 0.0
		_p.camera.v_offset = 0.0


func test_thompson_sight_line_clears_the_receiver() -> void:
	# the old model's cocking knob stood on the sight line and hid the blade (the Update 02 report). T-089: the
	# downloaded 1928 keeps its knob on top, so the check is against the line itself: wherever the knob is, the line
	# from the rear sight to the front blade passes above it, and both sights stand above the receiver.
	var h: WeaponHolder = _aim("thompson")
	var marks: Array = h.sight_marks_model()
	var rear: Vector3 = marks[0]
	var front: Vector3 = marks[1]
	var model: Node3D = h.get("_model")
	var bolt: Node3D = model.find_child("Bolt", true, false) as Node3D
	var bb: AABB = WeaponKitModels._bounds(bolt)
	var top_z: float = bolt.position.z + bb.get_center().z
	var t: float = clampf((top_z - rear.z) / (front.z - rear.z), 0.0, 1.0)
	var line_y: float = lerpf(rear.y, front.y, t)
	var knob_top: float = bolt.position.y + bb.end.y
	if absf(bolt.position.x + bb.get_center().x) < 0.015:
		assert_gt(line_y, knob_top - 0.0005, "the sight line passes over the cocking knob (%.4f over %.4f)" % [line_y, knob_top])
	else:
		pass_test("the cocking knob rides on the side, off the sight line")
	var recv_top: float = -INF
	for row: Array in WeaponGLB.top_profile(model):
		if float(row[0]) > front.z + 0.05 and float(row[0]) < rear.z - 0.05 and not str(row[2]) in ["Bolt", "RearSight"]:
			recv_top = maxf(recv_top, float(row[1]))
	assert_gt(rear.y, recv_top, "the peep stands above the receiver top")
	assert_gt(front.y, recv_top, "the blade stands above the receiver top")


func test_idle_ads_sway_is_calm() -> void:
	var h: WeaponHolder = _aim("thompson")
	h.steady = false
	# idle, aimed: the drift stays within a few pixels of the center
	var worst: float = 0.0
	for i: int in 240:
		h.call("_animate", 1.0 / 60.0, false)
		worst = maxf(worst, _worst_px(h, 80.0 * h.fov_mult(), true))
	assert_lt(worst, 6.0, "idle ADS sway stays small (%.2f px)" % worst)
	assert_gt(worst, 0.05, "idle ADS sway is not frozen")
