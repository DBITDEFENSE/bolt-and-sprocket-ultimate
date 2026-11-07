extends GutTest
## T-182: the sights the eye sees line up with the shot when fully aimed, for every gun, its Crucible-taught look and
## every Armorer's Bench sights x stock build, held by every survivor's arms. test_ads_alignment (T-047) proves the
## SightPoint / FrontSight markers sit on the screen centre; this measures the GEOMETRY round the aim point
## (SightPicture: a ray per pixel through the pure ADS pose): the front post's tip on the aim point, the post centred
## in the rear notch / aperture, and no rear sight, receiver or glove covering the aim point. Before T-182, 11 of the
## 27 guns (and 152 of the 258 iron-sighted builds) failed this while the marker check passed. Scoped builds look
## through the HUD scope picture and are left to test_ads_alignment. The game's idle sway may move the sight picture
## only a little off the aim point while aimed.

const TOL_PX: float = 2.0
const BASE_FOV: float = 80.0
const SURVIVORS: Array[StringName] = [&"bolt", &"deacon", &"dutch", &"peg", &"vendelin", &"wren"]

var _p: Player
var _char_was: StringName
var _chars_was: Dictionary


func before_all() -> void:
	_char_was = GameState.character_id
	_chars_was = GameState.characters.duplicate()


func after_all() -> void:
	GameState.character_id = _char_was
	GameState.characters = _chars_was


func before_each() -> void:
	GameState.characters = {}
	_p = Player.new()
	add_child_autofree(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.character_id = _char_was


static func _ids() -> Array[String]:
	var out: Array[String] = []
	var t: Dictionary = GLData.table("weapons")
	for k: Variant in (t["weapons"] as Dictionary).keys():
		out.append(str(k))
	for k2: Variant in (t["upgraded"] as Dictionary).keys():
		out.append(str(k2))
	return out


## Fully aimed, the bare pose (no sway), the camera at the ADS FOV as the game sets it.
func _aim(id: String) -> WeaponHolder:
	var h: WeaponHolder = _p.weapons
	h.slots.clear()
	if id.contains(":"):
		h.slots = [WeaponKit.from_build(id)]
		h.current_index = 0
	else:
		h.give_weapon(StringName(id))
		h.current_index = h.slots.find(h.find_weapon(StringName(id)))
	h.call("_rebuild_gun")
	h.set("_swap_t", 0.0)
	h.steady = true
	h.ads_t = 1.0
	_p.camera.fov = BASE_FOV * h.fov_mult()
	h.call("_animate", 1.0 / 60.0, false)
	return h


## The builds whose sight picture is off, as "id: what" strings.
func _off(ids: Array) -> PackedStringArray:
	var bad: PackedStringArray = []
	for id: String in ids:
		var h: WeaponHolder = _aim(id)
		var m: Dictionary = SightPicture.measure(h, _p.camera.fov)
		if bool(m["scoped"]):
			continue
		if float(m["err"]) > TOL_PX:
			bad.append("%s: %s" % [id, "no front sight shows at the aim point" if bool(m["blocked"]) or not bool(m["found_post"])
				else "post %+.1f,%+.1f rear %+.1f hole %+.1f px" % [float(m["post_x"]), float(m["post_tip"]), float(m["rear_x"]), float(m["hole_y"])]])
	return bad


func test_every_gun_and_its_crucible_look_line_up() -> void:
	var bad: PackedStringArray = _off(_ids())
	assert_eq(bad.size(), 0, "sight picture on the aim point within %.1f px: %s" % [TOL_PX, ", ".join(bad)])


func test_every_bench_sights_build_lines_up() -> void:
	var builds: Array = Array(WeaponKit.sight_stock_builds())
	assert_gt(builds.size(), 100, "the bench builds are all checked")
	var bad: PackedStringArray = _off(builds)
	assert_eq(bad.size(), 0, "bench sights x stock builds on the aim point within %.1f px: %s" % [TOL_PX, ", ".join(bad)])


func test_every_survivors_hands_keep_the_sights_clear() -> void:
	# the support glove sat on the Kar98k's front post and over the Sawed-Off's rib before T-182
	var base: Array = (GLData.table("weapons")["weapons"] as Dictionary).keys()
	for ch: StringName in SURVIVORS:
		GameState.character_id = ch
		_p.weapons.call("_apply_arms")
		var bad: PackedStringArray = _off(base)
		assert_eq(bad.size(), 0, "%s's arms: %s" % [ch, ", ".join(bad)])


func test_the_measure_catches_a_marker_off_the_sights() -> void:
	# a rear marker 2 mm under the notch (the MP40 before T-182) must fail: the rear sight then hides the post
	var h: WeaponHolder = _aim("mp40")
	assert_lt(float(SightPicture.measure(h, _p.camera.fov)["err"]), TOL_PX, "the MP40 lines up")
	var sp: Node3D = (h.get("_model") as Node3D).find_child("SightPoint", true, false) as Node3D
	sp.position.y -= 0.0025
	h.call("_compute_ads_pose")
	h.call("_animate", 1.0 / 60.0, false)
	assert_gt(float(SightPicture.measure(h, _p.camera.fov)["err"]), TOL_PX, "a rear marker under the notch is caught")


func test_idle_ads_sway_keeps_the_sights_near_the_aim_point() -> void:
	# the aimed figure-8 turns the gun about its grip, so the sights drift off the shot point a little; keep it small
	for id: String in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		var h: WeaponHolder = _aim(id)
		if h.scoped():
			continue
		h.steady = false
		var worst: float = 0.0
		for i: int in 240:
			h.call("_animate", 1.0 / 60.0, false)
			for p: Vector3 in h.sight_marks_camera(true):
				worst = maxf(worst, WeaponHolder.project_offset_px(p, _p.camera.fov, 720.0).length())
		assert_lt(worst, TOL_PX, "%s: idle ADS drift %.2f px" % [id, worst])
		h.steady = true
