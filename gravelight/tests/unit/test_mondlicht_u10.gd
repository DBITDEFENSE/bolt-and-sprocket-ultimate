extends GutTest
## UPDATE 10 §3 Act IV (T-158): Mondlicht's set-pieces, the pure rules and the data. The terminator's maths (the
## line by act round, the night side, the Sun's swing, the cold drain, the glare and the visor), the Earth's
## reversal by completed cancel steps, the pad arc, the fling threshold for orbit, the leap rule, the meteor
## schedule and its damage, the vent, the mast's pulse, the field units' patrol, and the act's data rows.


func _m4d() -> Dictionary:
	return GLData.load_json("res://data/gravelight/map04d.json")


# ---------------------------------------------------------------- the terminator

func test_the_line_runs_over_the_act() -> void:
	assert_eq(Terminator.line_s_for(1, 16, -80.0, 66.0), -80.0, "act round 1: the far end (all day)")
	assert_eq(Terminator.line_s_for(16, 16, -80.0, 66.0), 66.0, "the act's last round: the other end (all night)")
	assert_eq(Terminator.line_s_for(40, 16, -80.0, 66.0), 66.0, "clamped past the act")
	var mid: float = Terminator.line_s_for(8, 16, -80.0, 66.0)
	assert_true(mid > -80.0 and mid < 66.0, "in between in the middle")
	assert_true(Terminator.line_s_for(9, 16, -80.0, 66.0) > mid, "it only moves one way")
	assert_almost_eq(Terminator.progress_of(mid, -80.0, 66.0), 7.0 / 15.0, 0.001)


func test_the_night_side() -> void:
	var h: Vector3 = Vector3(1, 0, 0)
	var c: Vector3 = Vector3.ZERO
	assert_true(Terminator.is_night(Vector3(-5, 0, 0), c, h, 0.0), "away from the Sun: night")
	assert_false(Terminator.is_night(Vector3(5, 0, 0), c, h, 0.0), "toward the Sun: day")
	assert_true(Terminator.is_night(Vector3(5, 0, 0), c, h, 10.0), "the line has passed it: night")
	assert_almost_eq(Terminator.side_of(Vector3(3, 7, 9), c, h, 1.0), 2.0, 0.001, "height and the line's run do not matter")


func test_the_sun_swings_and_sinks() -> void:
	var base: Vector3 = Vector3(0.88, 0.26, -0.31)
	var s0: Vector3 = Terminator.sun_dir_at(0.0, base, 24.0, 15.6, 6.0)
	var s1: Vector3 = Terminator.sun_dir_at(1.0, base, 24.0, 15.6, 6.0)
	assert_almost_eq(rad_to_deg(asin(s0.y)), 15.6, 0.1, "starts at its elevation")
	assert_almost_eq(rad_to_deg(asin(s1.y)), 6.0, 0.1, "sinks toward the horizon")
	var f0: Vector3 = Terminator.line_normal(s0)
	var f1: Vector3 = Terminator.line_normal(s1)
	assert_almost_eq(rad_to_deg(f0.angle_to(f1)), 24.0, 0.2, "the azimuth swings 24 degrees")


func test_the_cold_and_the_heaters() -> void:
	assert_eq(Terminator.cold_drain(false, true, 0.6, false, 0.4), 0.0, "day: no strain")
	assert_eq(Terminator.cold_drain(true, false, 0.6, false, 0.4), 0.0, "pressure: no strain")
	assert_almost_eq(Terminator.cold_drain(true, true, 0.6, false, 0.4), 0.6, 0.0001)
	assert_almost_eq(Terminator.cold_drain(true, true, 0.6, true, 0.4), 0.24, 0.0001, "the heaters ease it")
	assert_eq(MoonSuitHud.frost_for(true, true, false), 0.7)
	assert_eq(MoonSuitHud.frost_for(true, true, true), 0.3)
	assert_eq(MoonSuitHud.frost_for(false, true, false), 0.0)


func test_the_glare_and_the_visor() -> void:
	assert_eq(Terminator.glare_for(true, true, 1.0, false, 0.35), 1.0, "facing the low Sun in the open: blinded")
	assert_eq(Terminator.glare_for(true, true, 1.0, true, 0.35), 0.0, "the visor down")
	assert_eq(Terminator.glare_for(false, true, 1.0, false, 0.35), 0.0, "night")
	assert_eq(Terminator.glare_for(true, false, 1.0, false, 0.35), 0.0, "under a roof")
	assert_eq(Terminator.glare_for(true, true, 0.2, false, 0.35), 0.0, "looking away")
	var inp: Dictionary = GLData.load_json("res://data/gravelight/input_defaults.json")
	assert_eq(str((inp.get("visor", {}) as Dictionary).get("key", "")), "H", "the visor has a key")
	assert_true(MenuSettings.ACTION_NAMES.has("visor"), "rebindable in Settings > Controls")


func test_every_zone_crosses_in_order() -> void:
	var t: Dictionary = _m4d()["terminator"]
	var ctr: Vector3 = Vector3(float(t["center"][0]), 0, float(t["center"][2]))
	var e: Dictionary = _m4d()["earth"]
	var base: Vector3 = Vector3(float(e["sun_dir"][0]), float(e["sun_dir"][1]), float(e["sun_dir"][2]))
	for zn: String in (t["zone_centres"] as Dictionary).keys():
		var a: Array = t["zone_centres"][zn]
		var p: Vector3 = Vector3(float(a[0]), 0, float(a[2]))
		var s0: float = Terminator.line_s_for(1, 16, float(t["from_s"]), float(t["to_s"]))
		var s1: float = Terminator.line_s_for(16, 16, float(t["from_s"]), float(t["to_s"]))
		var h0: Vector3 = Terminator.line_normal(Terminator.sun_dir_at(0.0, base, float(t["sun_azimuth_deg"]), float(t["sun_elev_from"]), float(t["sun_elev_to"])))
		var h1: Vector3 = Terminator.line_normal(Terminator.sun_dir_at(1.0, base, float(t["sun_azimuth_deg"]), float(t["sun_elev_from"]), float(t["sun_elev_to"])))
		assert_false(Terminator.is_night(p, ctr, h0, s0), "%s is in day at the act's start" % zn)
		assert_true(Terminator.is_night(p, ctr, h1, s1), "%s is in night by the act's end" % zn)


# ---------------------------------------------------------------- the Earth

func test_the_earth_reverses_by_cancel_steps() -> void:
	assert_eq(EarthSky.reversed_spread(0.4, 0, 4), 0.4)
	assert_almost_eq(EarthSky.reversed_spread(0.4, 1, 4), 0.3, 0.0001, "each step takes a share")
	assert_almost_eq(EarthSky.reversed_spread(0.4, 3, 4), 0.1, 0.0001)
	assert_eq(EarthSky.reversed_spread(0.4, 4, 4), 0.0, "CANCEL: none left")
	assert_eq(EarthSky.reversed_spread(0.4, 9, 4), 0.0, "clamped")
	var e: Dictionary = _m4d()["earth"]
	assert_eq(e.get("reverse_steps", []), ["s15_columns", "s16_account", "s17_manager", "s18_cancel"], "the Kündigung's steps 15-18")
	var q: Dictionary = GLData.load_json("res://data/gravelight/quests/map04_kuendigung.json")
	var ids: Array = []
	for s: Dictionary in q["steps"]:
		ids.append(str(s["id"]))
	for sid: Variant in e["reverse_steps"]:
		assert_true(ids.has(str(sid)), "%s is a step of the quest" % str(sid))


# ---------------------------------------------------------------- low gravity

func test_the_pad_arc_lands_on_target() -> void:
	var from: Vector3 = Vector3(-31, 0, 70)
	var to: Vector3 = Vector3(-31, 0, 89)
	var g: float = 14.0 * 0.38
	var v: Vector3 = JumpPad.launch_velocity(from, to, 3.0, g)
	assert_true(JumpPad.arc_point(from, v, g, 3.0).distance_to(to) < 0.01, "the arc ends on the target")
	assert_almost_eq(JumpPad.apex_height(v, g), 0.125 * g * 9.0, 0.01, "apex = g t² / 8")
	var up: Vector3 = JumpPad.launch_velocity(from, to + Vector3(0, 3, 0), 3.0, g)
	assert_true(JumpPad.arc_point(from, up, g, 3.0).distance_to(to + Vector3(0, 3, 0)) < 0.01, "and onto a higher landing")


func test_every_pad_clears_the_crater_rim() -> void:
	var lg: Dictionary = _m4d()["low_g"]
	var g: float = 14.0 * float(_m4d()["act"]["gravity_scale"])
	for pd: Dictionary in lg["pads"]:
		var a: Array = pd["at"]
		var b: Array = pd["to"]
		var v: Vector3 = JumpPad.launch_velocity(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3(float(b[0]), float(b[1]), float(b[2])), float(pd["flight_s"]), g)
		assert_gt(JumpPad.apex_height(v, g), float(lg["crater"]["rim_h"]) + 0.8, "%s clears the rim" % str(pd["name"]))
		if str(pd["zone"]) == "E_HALL":
			assert_lt(JumpPad.apex_height(v, g) + 1.8, 9.0, "%s stays under the hall's ceiling" % str(pd["name"]))


func test_the_fling_threshold() -> void:
	var fs: float = float(_m4d()["low_g"]["fling_speed"])
	assert_true(MoonLowG.orbits(fs, true, fs), "at the threshold in vacuum: orbit")
	assert_false(MoonLowG.orbits(fs - 0.1, true, fs), "just under: a throw")
	assert_false(MoonLowG.orbits(fs * 3.0, false, fs), "under a roof never")
	var w: Dictionary = (GLData.table("weapons")["weapons"] as Dictionary).get("lodestone", {})
	var g: Dictionary = w.get("gravity", {})
	var v: Vector3 = Lodestone.fling_velocity(Vector3.FORWARD, Lodestone.fling_distance(g, 0.38), 0.38)
	assert_true(MoonLowG.orbits(v.length(), true, fs), "a plain Moon fling reaches orbit (%.1f m/s)" % v.length())
	var v1: Vector3 = Lodestone.fling_velocity(Vector3.FORWARD, Lodestone.fling_distance(g, 1.0), 1.0)
	assert_false(MoonLowG.orbits(v1.length(), true, fs), "at Earth gravity it would not (%.1f m/s)" % v1.length())


func test_the_leap_rule() -> void:
	assert_true(MoonLowG.may_leap(10.0, true, 0.0, 6.0, 24.0))
	assert_false(MoonLowG.may_leap(4.0, true, 0.0, 6.0, 24.0), "too close")
	assert_false(MoonLowG.may_leap(30.0, true, 0.0, 6.0, 24.0), "too far")
	assert_false(MoonLowG.may_leap(10.0, true, 1.0, 6.0, 24.0), "cooling down")
	assert_false(MoonLowG.may_leap(10.0, false, -2.0, 6.0, 24.0), "away from a leap point, not yet")
	assert_true(MoonLowG.may_leap(10.0, false, -9.0, 6.0, 24.0), "it gives up waiting")
	var v: Vector3 = MoonLowG.leap_velocity(Vector3.ZERO, Vector3(12, 0, 0), 2.4, 18.0 * 0.38)
	assert_almost_eq(v.x * 2.4, 12.0, 0.01, "lands on the target")
	assert_gt(v.y * v.y / (2.0 * 18.0 * 0.38), 2.0, "from above: a high arc")


# ---------------------------------------------------------------- the meteor shower and the vent

func test_the_meteor_schedule() -> void:
	var m: Dictionary = _m4d()["meteor_shower"]
	var due: Array = []
	for r: int in range(30, 46):
		if MeteorShower.is_shower_round(r, int(m["first_round"]), int(m["every"]), false):
			due.append(r)
	assert_eq(due, [33, 39, 45], "every 6th act round from 33")
	assert_false(MeteorShower.is_shower_round(33, 33, 6, true), "never on a special round")
	assert_false(MeteorShower.is_shower_round(27, 33, 6, false))
	assert_eq(MeteorShower.damage_at(0.0, 2.6, 90.0), 90.0)
	assert_almost_eq(MeteorShower.damage_at(1.3, 2.6, 90.0), 45.0, 0.01)
	assert_eq(MeteorShower.damage_at(3.0, 2.6, 90.0), 0.0)
	var box: Array = m["yard_box"]
	var p: Vector3 = MeteorShower.point_in(box, 0.5, 0.5)
	assert_true(p.x > float(box[0]) and p.x < float(box[2]) and p.z > float(box[1]) and p.z < float(box[3]), "inside the yard")
	assert_gt(float(box[1]), 60.0, "the yard box starts north of the domes (nothing lands under a roof)")
	assert_almost_eq(float(m["warn_seconds"]), 10.0, 0.001)
	assert_almost_eq(float(m["seconds"]), 40.0, 0.001)


func test_the_vent() -> void:
	var c: Vector3 = Vector3(28, 0, -21)
	assert_true(ShaftGrate.on_grate(Vector3(29, 0.1, -21.5), c, 2.4))
	assert_false(ShaftGrate.on_grate(Vector3(31, 0, -21), c, 2.4), "off the grate")
	assert_false(ShaftGrate.on_grate(Vector3(28, 3.0, -21), c, 2.4), "in the air over it")
	var sg: Dictionary = _m4d()["shaft_grate"]
	assert_eq(int(sg["cost"]), 1000)
	assert_almost_eq(float(sg["open_seconds"]), 8.0, 0.001)


func test_the_mast_and_the_rim() -> void:
	for i: int in 40:
		var p: float = RelayMast.pulse_at(float(i) * 0.1, 3.2)
		assert_true(p >= 0.0 and p <= 1.0)
	assert_gt(RelayMast.pulse_at(0.12 * 3.2, 3.2), 0.95, "a sharp rise")
	var path: Array = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)]
	assert_true(MondlichtLiving.patrol_point(path, 5.0).distance_to(Vector3(5, 0, 0)) < 0.01)
	assert_true(MondlichtLiving.patrol_point(path, 15.0).distance_to(Vector3(10, 0, 5)) < 0.01)
	assert_true(MondlichtLiving.patrol_point(path, 25.0).distance_to(Vector3(10, 0, 5)) < 0.01, "it walks back")
	assert_true(MondlichtLiving.dusty_hit(0.0, true, 3.5))
	assert_false(MondlichtLiving.dusty_hit(0.0, false, 3.5), "indoors: no regolith")


# ---------------------------------------------------------------- the data

func test_the_living_world_file() -> void:
	var a: Dictionary = GLData.load_json("res://data/gravelight/map04d_ambience.json")
	for k: String in ["dust_settle", "crater_shadows", "relay_mast", "vacuum_muffle", "earth_violet", "field_units", "meteors"]:
		assert_true(a.has(k), "map04d_ambience.json has %s" % k)
	for k2: String in ["bombers", "fighters", "artillery", "crows", "bell"]:
		assert_false(a.has(k2), "no Map 0 kind %s on the Moon" % k2)
	assert_false(bool(a.get("needs_landscape", true)))
	assert_eq(int(a["field_units"]["count"]), 3)
	for pt: Variant in a["field_units"]["path"]:
		assert_gt(float((pt as Array)[2]), 112.0, "the field units stay beyond the north rim")
	var m00: Dictionary = GLData.load_json("res://data/gravelight/map00_ambience.json")
	for k3: String in MapAmbience.U10_ACT4_KINDS:
		assert_false(m00.has(k3), "Map 0's file has no Act IV kind (%s): unchanged" % k3)


func test_the_lines_exist() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var m: Dictionary = _m4d()
	var ids: Array = []
	ids.append_array(m["terminator"]["vo_cross"])
	ids.append(m["terminator"]["vo_glare"])
	ids.append(m["heaters"]["vo"])
	ids.append_array([m["low_g"]["vo_pad"], m["low_g"]["vo_orbit"]])
	ids.append_array(m["low_g"]["vo_orbit_more"])
	ids.append_array([m["meteor_shower"]["vo_warn"], m["meteor_shower"]["vo_start"], m["meteor_shower"]["vo_end"], m["shaft_grate"]["vo"]])
	for k: String in (m["earth"]["vo_dim"] as Dictionary).keys():
		ids.append_array(m["earth"]["vo_dim"][k])
	ids.append("JAK_M4D_CONSOLE_01")
	for id: Variant in ids:
		assert_true(lines.has(str(id)), "line %s" % str(id))
	var opr: int = 0
	var wrn: int = 0
	for k4: String in (m["earth"]["vo_dim"] as Dictionary).keys():
		for id2: Variant in m["earth"]["vo_dim"][k4]:
			if str(id2).begins_with("OPR_"):
				opr += 1
			elif str(id2).begins_with("WRN_"):
				wrn += 1
	assert_eq(opr, 2, "the Operator notices the Earth twice")
	assert_eq(wrn, 2, "Wren notices it twice")


func test_pohl_is_a_person_not_inventory() -> void:
	var p: Dictionary = ExtraPeople.people().get("pohl", {})
	assert_false(p.is_empty(), "Obergefreiter Pohl is in people_extra.json")
	assert_eq(ExtraPeople.ids_for_map("map04d_mondlicht", ExtraPeople.cfg()), PackedStringArray(["pohl"]))
	assert_eq(str(p["favour"]["kind"]), "deliver")
	assert_false(str(p["bio"]).to_lower().contains("darkmatter staff"), "not Darkmatter staff")
	assert_false(p.has("trade") or p.has("relay"), "he never fights, sells or relays: he asks")


func test_four_new_story_props() -> void:
	var intel: Array = GLData.load_json("res://data/gravelight/intel.json")["intel"]
	var have: Dictionary = {}
	for r: Dictionary in intel:
		have[str(r["id"])] = r
	var n: int = 0
	for sp: Dictionary in GLData.load_json("res://data/gravelight/story_props.json")["props"]:
		if str(sp["id"]).begins_with("INT_M4D_"):
			n += 1
			assert_true(have.has(str(sp["id"])) and str(have[str(sp["id"])].get("placement", "")) == "fixed", "%s: an intel row, fixed" % str(sp["id"]))
	assert_eq(n, 4, "four new real StoryProps on the Moon")
