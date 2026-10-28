extends GutTest
## T-128 (the owner: "improve the gunplay, make sure all sights look good and tracers and hitmarkers feel
## satisfying"): tracers fly and drain into the hit, a Crucible gun's burn violet, close shots draw none; the hit
## marker builds a streak; a kill has its own confirm sound; the sight fits found by the sight-picture audit stay.


func _live_tracers() -> Array:
	var out: Array = []
	for i: int in Effects.TRACERS:
		if float(Effects._tracer_life[i]) > 0.0:
			out.append(i)
	return out


func _clear() -> void:
	for i: int in Effects.TRACERS:
		Effects._tracer_life[i] = 0.0
		Effects._tracers[i].hide()


func test_a_tracer_flies_out_and_drains_into_the_hit() -> void:
	_clear()
	var from: Vector3 = Vector3(0, 1.5, 0)
	var to: Vector3 = Vector3(0, 1.5, -40)
	Effects.tracer(from, to, false, &"rifle", true)
	var live: Array = _live_tracers()
	assert_eq(live.size(), 1, "one tracer in flight")
	var i: int = int(live[0])
	var node: Node3D = Effects._tracers[i]
	var cfg: Dictionary = GLData.table("vfx")["tracer"]
	var look: Dictionary = cfg["classes"]["rifle"]
	Effects._tick_tracers(0.02)
	assert_true(node.visible, "it shows once it has a length")
	var tail_z: float = node.global_position.z + node.get_child(0).scale.z * 0.5
	assert_lt(tail_z, from.z - float(cfg["first_person_skip_m"]) + 0.01, "nothing drawn in the first metres in front of your own eye")
	assert_lte(node.get_child(0).scale.z, float(look["length"]) + 0.01, "no longer than its class length")
	var flight: float = 40.0 / float(look["speed"])
	for k: int in 40:
		Effects._tick_tracers(flight / 20.0)
	assert_false(node.visible, "gone once its tail reaches the hit")
	assert_eq(_live_tracers().size(), 0)


func test_no_tracer_for_a_close_shot_and_violet_for_a_taught_gun() -> void:
	_clear()
	Effects.tracer(Vector3.ZERO, Vector3(0, 0, -1.0))
	assert_eq(_live_tracers().size(), 0, "a shot landing a metre away draws no tracer")
	Effects.tracer(Vector3.ZERO, Vector3(0, 0, -30.0), true, &"smg")
	var i: int = int(_live_tracers()[0])
	var core: MeshInstance3D = Effects._tracers[i].get_child(0)
	assert_eq(core.material_override, (Effects._tracer_mats[&"upgraded"] as Array)[0], "a Crucible gun's tracer burns violet")
	_clear()


func test_every_class_has_a_tracer_look() -> void:
	var classes: Dictionary = GLData.table("vfx")["tracer"]["classes"]
	assert_true(classes.has("default"))
	for id: String in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		var cls: String = str(GLData.table("weapons")["weapons"][id].get("class", ""))
		var look: Dictionary = classes.get(cls, classes["default"])
		assert_gt(float(look.get("speed", 0.0)), 100.0, "%s (%s): a visible but quick flight" % [id, cls])


func test_the_hit_marker_streak() -> void:
	assert_eq(Hud.HitMarker.streak_scale(0, 0.06), 1.0)
	assert_almost_eq(Hud.HitMarker.streak_scale(5, 0.06), 1.3, 0.001)
	var hm: Dictionary = MenuKit.cfg().get("hitmarker", {})
	assert_gt(float(hm["kill"]["pop"]), float(hm["hit"]["pop"]), "a kill pops harder than a hit")
	assert_true(hm.has("ring"), "a kill throws a ring")


func test_a_kill_has_its_own_confirm() -> void:
	assert_true(AudioDirector.has_sound("kill_confirm"))
	assert_true(AudioDirector.has_sound("hitmarker"))
	assert_true(AudioDirector.has_sound("headshot"))


## The fits from the sight-picture audit (tools/ads_check.sh --picture / --ascii / --fit): the Garand's rear
## aperture and front post, the Carbine's, and the trench gun's hammer under the sight line.
func test_the_sight_fits_hold() -> void:
	var fit: Dictionary = GLData.load_json("res://data/gravelight/weapons/model_fit.json")["weapons"]
	assert_true((fit["m1_garand"] as Dictionary).has("sight_front"), "the Garand's front post is fitted")
	assert_lt(float(fit["m1_garand"]["sight_rear"][0]), -0.005, "the Garand's aperture sits off the centre line")
	assert_true((fit["m1_carbine"] as Dictionary).has("sight_front"))
	assert_lt(float(fit["trench_gun"]["part_offset"]["Hammer"][1]), 0.0, "the trench gun's hammer is under the sight line")
