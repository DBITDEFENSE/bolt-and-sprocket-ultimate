extends GutTest
## UPDATE 10 Act I, Werk Thalbach (DECISIONS T-155): the air raid's route swap and fairness rules, the fires, the
## rivet line's timings, the wind tunnel's push maths, the two people's favour graph, the living world's data and the
## generated scene's new nodes.

const MAP: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"


func _raid() -> Dictionary:
	return ThalbachRaid.load_cfg()


# ---------------------------------------------------------------- the air raid

func test_raid_is_due_once_on_act_round_8() -> void:
	var c: Dictionary = _raid()
	assert_eq(int(c["round"]), 8, "the raid is act round 8 (contract C6)")
	assert_true(ThalbachRaid.due(8, 8, false))
	assert_false(ThalbachRaid.due(7, 8, false))
	assert_false(ThalbachRaid.due(8, 8, true), "never twice")
	assert_true(ThalbachRaid.starts_collapsed(9, 8), "a match that starts past it starts with the hall down")
	assert_false(ThalbachRaid.starts_collapsed(8, 8))


func test_route_swap_state() -> void:
	var route: Dictionary = _raid()["route"]
	assert_eq(str(route["blocked"]), "Door_E_south")
	assert_eq(str(route["new"]), "Breach_E_apron")
	var before: Dictionary = ThalbachRaid.route_state(route, false)
	var after: Dictionary = ThalbachRaid.route_state(route, true)
	assert_true(before["Navigation/Nav_E_MONTAGE_4"] and before["Navigation/Link_5_G_PRUEFSTAND"], "before: the hall as built and the old door")
	assert_false(before["Navigation/Nav_E_MONTAGE_raid"] or before["Navigation/Link_Breach_E_apron"], "before: no breach")
	assert_false(after["Navigation/Nav_E_MONTAGE_4"] or after["Navigation/Link_5_G_PRUEFSTAND"], "after: the old route is gone")
	assert_true(after["Navigation/Nav_E_MONTAGE_raid"] and after["Navigation/Link_Breach_E_apron"], "after: the breach")


func test_nobody_under_the_roof() -> void:
	var c: Dictionary = _raid()
	var lo: Vector3 = ThalbachRaid.v3(c["collapse_box"][0])
	var hi: Vector3 = ThalbachRaid.v3(c["collapse_box"][1])
	var rlo: Vector3 = ThalbachRaid.v3(c["rubble_box"][0])
	var rhi: Vector3 = ThalbachRaid.v3(c["rubble_box"][1])
	assert_true(rlo.x >= lo.x and rhi.x <= hi.x and rlo.z >= lo.z and rhi.z <= hi.z, "the rubble lies inside the cleared box")
	for p: Vector3 in [Vector3(-37.0, 0, 90), Vector3(-30.1, 0, 105), Vector3(-29.9, 2.5, 96), Vector3(-23.0, 0, 109)]:
		assert_true(ThalbachRaid.in_box(p, lo, hi))
		var s: Vector3 = ThalbachRaid.safe_point(p, lo, hi)
		assert_false(ThalbachRaid.in_box(s, lo, hi), "%s is moved out to %s" % [str(p), str(s)])
		var d: Vector3 = ThalbachRaid.push_dir(p, lo, hi)
		assert_almost_eq(absf(d.x), 1.0, 0.001, "the shove is across the bay, never into the north wall")
		assert_eq(d.z, 0.0)
	assert_gt(float(c["warning_seconds"]), 9.9, "a 10 s warning")
	assert_lt(float(c["push_lead"]), float(c["warning_seconds"]))
	assert_gt(float(c["push_mps"]) * float(c["push_seconds"]), (hi.x - lo.x) * 0.5, "the shove carries anyone across half the bay")


func test_bomb_walk_lands_before_the_fall() -> void:
	var c: Dictionary = _raid()
	var bw: Dictionary = c["bomb_walk"]
	var n: int = (bw["points"] as Array).size()
	var last: float = ThalbachRaid.bomb_time(n - 1, float(bw["start"]), float(bw["gap"]))
	assert_lt(last, float(c["warning_at"]) + float(c["warning_seconds"]), "every bomb is down before the roof")
	assert_gt(float(bw["telegraph"]), 1.0, "each is lit at least a second ahead")
	assert_lt(int(bw["player_damage"]), 100, "a bomb hurts, it does not kill from full health")


func test_fires_fade_over_three_rounds() -> void:
	assert_almost_eq(ThalbachRaid.fire_heat(8, 8, 3), 1.0, 0.001)
	assert_almost_eq(ThalbachRaid.fire_heat(9, 8, 3), 2.0 / 3.0, 0.001)
	assert_almost_eq(ThalbachRaid.fire_heat(10, 8, 3), 1.0 / 3.0, 0.001)
	assert_eq(ThalbachRaid.fire_heat(11, 8, 3), 0.0, "out after three")
	assert_eq(ThalbachRaid.fire_heat(5, -1, 3), 0.0, "no raid, no fire")
	assert_eq(int((_raid()["fires"] as Dictionary)["fade_rounds"]), 3)


# ---------------------------------------------------------------- the rivet line

func test_rivet_line_timings() -> void:
	var c: Dictionary = TrapLever.cfg_for("rivet_line")
	assert_eq(float(c["duration"]), 25.0)
	assert_eq(float(c["cooldown"]), 60.0)
	assert_eq(int(c["cost"]), 1000)
	assert_almost_eq(RivetLineTrap.shuttle(0.0, 5.5), 0.0, 0.001)
	assert_almost_eq(RivetLineTrap.shuttle(5.5, 5.5), 1.0, 0.001, "end to end in a pass")
	assert_almost_eq(RivetLineTrap.shuttle(8.25, 5.5), 0.5, 0.001, "and back")
	assert_true(RivetLineTrap.can_run(true, true, false, 0.0))
	assert_false(RivetLineTrap.can_run(false, true, false, 0.0), "needs the power")
	assert_false(RivetLineTrap.can_run(true, true, true, 0.0), "already running")
	assert_false(RivetLineTrap.can_run(true, true, false, 12.0), "cooling down")
	assert_true(RivetLineTrap.under(Vector3(1.4, 0, 1.5), Vector3.ZERO, Vector3.RIGHT, 3.0, 3.2))
	assert_false(RivetLineTrap.under(Vector3(1.6, 0, 0), Vector3.ZERO, Vector3.RIGHT, 3.0, 3.2), "just ahead of the carriage")
	assert_false(RivetLineTrap.under(Vector3(0, 2.6, 0), Vector3.ZERO, Vector3.RIGHT, 3.0, 3.2), "on a jig deck, over the hammers")


# ---------------------------------------------------------------- the wind tunnel

func test_tunnel_push_maths() -> void:
	var c: Dictionary = TrapLever.cfg_for("wind_tunnel")
	assert_eq(float(c["zombie_push_mps"]), 6.0, "zombies 6 m/s (contract C6)")
	assert_eq(float(c["player_push_mps"]), 3.0, "players 3 m/s")
	assert_eq(float(c["duration"]), 20.0)
	assert_eq(WindTunnel.push_for(false, 6.0, 3.0), Vector3(6, 0, 0))
	assert_eq(WindTunnel.push_for(true, 6.0, 3.0), Vector3(3, 0, 0))
	var lo: Vector3 = Vector3(6, 0, 112)
	var hi: Vector3 = Vector3(38, 2.4, 118)
	assert_almost_eq(WindTunnel.seconds_to_screen(6.0, lo, hi, 1.4, 6.0), (38.0 - 1.4 - 6.0) / 6.0, 0.001, "the whole tunnel in about five seconds")
	assert_true(WindTunnel.at_screen(Vector3(37.0, 0.5, 115), lo, hi, 1.4))
	assert_false(WindTunnel.at_screen(Vector3(30.0, 0.5, 115), lo, hi, 1.4))
	assert_almost_eq(WindTunnel.part_round(Vector3(29.5, 0, 115.2), Vector3(31, 0, 115), 1.1, 6.0).z, 3.6, 0.001, "the wind parts round the sting")
	assert_eq(WindTunnel.part_round(Vector3(20.0, 0, 115.2), Vector3(31, 0, 115), 1.1, 6.0), Vector3.ZERO)
	assert_true(WindTunnel.hatch_allowed(true, true))
	assert_false(WindTunnel.hatch_allowed(true, false), "the draft never opens a room nobody bought")


# ---------------------------------------------------------------- the people (the side quest graph)

func test_people_favour_graph() -> void:
	var t: Dictionary = GLData.load_json("res://data/gravelight/people_extra.json")
	var people: Dictionary = t["people"]
	var ids: PackedStringArray = ExtraPeople.ids_for_map("map04a_thalbach", t)
	assert_true(ids.has("siedlung_father") and ids.has("railwayman"), "Act I has its two people (%s)" % str(ids))
	var f: Dictionary = people["siedlung_father"]["favour"]
	assert_eq(str(f["kind"]), "fetch")
	assert_eq(str(f["item"]), "coal")
	assert_eq(str(f["reward"]["kind"]), "open_passage")
	assert_eq(str(f["reward"]["node"]), "CellarSideDoor")
	var g: Dictionary = people["railwayman"]["favour"]
	assert_eq(str(g["item"]), "signal")
	assert_eq(str(g["item_verb"]), "Pull")
	assert_eq(str(g["reward"]["kind"]), "train_drop")
	assert_gt(int(g["reward"]["drops"]), 0)
	# the coal is in the rail yard, the lever by the goods shed (map space zone boxes)
	assert_true(ExtraPeople.vec(f["item_at"]).z > 30.0 and ExtraPeople.vec(f["item_at"]).z < 60.0, "the coal is in the Bahnhof")
	assert_true(ExtraPeople.vec(g["item_at"]).x > 28.0, "the lever is by the goods shed")
	for pid: String in ["siedlung_father", "railwayman"]:
		for kind: Variant in (people[pid]["lines"] as Dictionary).keys():
			for id: Variant in people[pid]["lines"][kind]:
				assert_true(GLVO.lines.has(str(id)), "%s is in lines.json" % str(id))


# ---------------------------------------------------------------- the living world's data

func test_ambience_file() -> void:
	var a: Dictionary = GLData.load_json("res://data/gravelight/map04a_ambience.json")
	assert_false(bool(a.get("needs_landscape", true)), "runs without a Landscape")
	var k: Dictionary = a["act1"]
	for key: String in ["windows_out", "bell", "low_pass", "searchlights", "train", "kranich_glow", "rattle", "sway", "weld", "posters", "power_on"]:
		assert_true(k.has(key), "act1.%s" % key)
	assert_eq(int(k["low_pass"]["round"]), 4, "the test jet at act round 4")
	assert_eq(int(k["train"]["round"]), 3, "the train at act round 3")
	assert_eq(int(k["windows_out"]["from_round"]), 2, "the windows go dark from act round 2")
	for p: Variant in k["posters"]["points"]:
		assert_true(["kranich", "wiederkehr"].has(str((p as Dictionary)["kind"])), "posters carry only the two fictional marks")
	for top: String in ["low_pass", "train", "raid", "bell_tower", "windows_out"]:
		assert_false(a.has(top), "no top-level %s (the shared kinds of other blocks must not run here)" % top)


func test_sight_note_view() -> void:
	assert_true(SightNote.in_view(Vector3.ZERO, Vector3(0, 0, -1), Vector3(0, 0, -5), 16.0, 0.8))
	assert_false(SightNote.in_view(Vector3.ZERO, Vector3(0, 0, -1), Vector3(5, 0, 0), 16.0, 0.8), "off to the side")
	assert_false(SightNote.in_view(Vector3.ZERO, Vector3(0, 0, -1), Vector3(0, 0, -20), 16.0, 0.8), "too far")


# ---------------------------------------------------------------- the generated scene

func test_scene_has_the_act_i_nodes() -> void:
	var root: Node = (load(MAP) as PackedScene).instantiate()
	for path: String in ["Gameplay/AirRaid", "Gameplay/Breach_E_apron", "Gameplay/TunnelHatch", "Gameplay/CellarSideDoor", "Gameplay/Trap_RivetLine",
			"Gameplay/Lever_RivetLine", "Gameplay/SightNote_Jette", "Gameplay/LitWindows", "Navigation/Nav_E_MONTAGE_4", "Navigation/Nav_E_MONTAGE_raid",
			"Navigation/Link_5_G_PRUEFSTAND", "Navigation/Link_Breach_E_apron", "Navigation/Link_TunnelHatch", "Navigation/Link_CellarSide"]:
		assert_not_null(root.get_node_or_null(path), path)
	assert_false((root.get_node("Navigation/Nav_E_MONTAGE_raid") as NavigationRegion3D).enabled, "the raid's Montage is off until the raid")
	for l: String in ["Link_Breach_E_apron", "Link_TunnelHatch", "Link_CellarSide"]:
		assert_false((root.get_node("Navigation/" + l) as NavigationLink3D).enabled, "%s starts closed" % l)
	var bd: Node = root.get_node("Gameplay/Breach_E_apron")
	assert_eq(StringName(bd.get("link_group")), &"pruefstand", "the breach is a Pruefstand door: no free zone")
	assert_eq(int(bd.get("cost")), 1500)
	assert_not_null(root.find_child("Hall2Roof", true, false), "the roof bay the raid drops")
	assert_not_null(root.find_child("BreachPlug", true, false))
	assert_not_null(root.find_child("FanRing", true, false), "the fan the tunnel spins")
	assert_gt(root.get_node("Gameplay/LitWindows").get_child_count(), 4, "lit windows for the blackout")
	root.free()
