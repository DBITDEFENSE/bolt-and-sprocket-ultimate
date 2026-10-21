extends GutTest
## T&C M2 on Gravelight Map 0: the Helvetia cellar (8 machines, 1500 door, the cellar lever), machine lore
## (plan IDs, the human behind each formula, fine-print panels, Archive rows) and the Operator's corporate slips.

const MAP00: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const PERKS: PackedStringArray = ["ironhide_stout", "second_wind", "trigger_tonic", "twin_barrel",
	"marathon_malt", "hawkeye_brandy", "packmule_porter", "blastproof_bock"]

var _saved_path: String = ""


func before_all() -> void:
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_profile_m2_%d.json" % OS.get_process_id()


func before_each() -> void:
	ProfileSave.profile = ProfileSave.new_profile()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.load_profile()
	GLVO.always_pass_chance = false


func test_perk_lore_covers_the_eight_machines() -> void:
	for pid: String in PERKS:
		var lo: Dictionary = FinePrintReader.lore(StringName(pid))
		assert_false(lo.is_empty(), pid)
		assert_true(str(lo.get("plan_id", "")).begins_with("DMS-VP-"), pid + " plan id")
		assert_ne(str(lo.get("human", "")), "", pid + " human")
		assert_gt((lo.get("panel", []) as Array).size(), 5, pid + " panel")
	# the brief's sample lines appear verbatim (JINGLES.md section 0.3)
	var ih: String = "\n".join(PackedStringArray(FinePrintReader.lore(&"ironhide_stout")["panel"]))
	assert_string_contains(ih, "Durability is measured in hits, not years.")
	assert_eq(str(FinePrintReader.lore(&"hawkeye_brandy")["plan_id"]), "DMS-VP-FOC-05")


func test_archive_has_panel_and_stencil_rows() -> void:
	var ids: Array = ProfileSave.intel_rows().map(func(r: Dictionary) -> String: return str(r["id"]))
	for pid: String in PERKS:
		assert_has(ids, "panel." + pid)
		assert_has(ids, "plan." + pid)
	var row: Dictionary = {}
	for r: Dictionary in ProfileSave.intel_rows():
		if str(r["id"]) == "panel.hawkeye_brandy":
			row = r
	assert_string_contains(str(row.get("text", "")), "Kurek")
	assert_false(str(row.get("text", "")).contains("[b]"), "BBCode stripped for the Archive")


func test_slip_chance_curve() -> void:
	assert_eq(GLVO.slip_chance(14, "map00_crossroads"), 0.0, "never on Map 0 before round 15")
	assert_almost_eq(GLVO.slip_chance(15, "map00_crossroads"), (0.01 + 0.0022 * 15) * 0.5, 0.0001)
	assert_almost_eq(GLVO.slip_chance(10, "map01_kaltenbrunn"), 0.032, 0.0001)
	assert_almost_eq(GLVO.slip_chance(80, "map01_kaltenbrunn"), 0.12, 0.0001, "capped")
	assert_almost_eq(GLVO.slip_chance(80, "map03"), 0.20, 0.0001, "map cap")


func test_slip_lines_present_and_tiered() -> void:
	var n: int = 0
	for id: String in GLVO.lines.keys():
		if id.begins_with("op.slip."):
			n += 1
			var rec: Dictionary = GLVO.lines[id]
			assert_eq(str(rec["speaker"]), "OPR")
			assert_has([10, 20, 30], int(rec["min_round"]))
			assert_false(str(rec["text"]).to_lower().contains("subscription"), id)
	assert_eq(n, 32)


func test_play_slip_honors_tier_rounds_and_bag() -> void:
	GLVO.reset_match()
	var saved_phase: int = GameState.phase
	var saved_round: int = RoundManager.current_round
	GameState.phase = GameState.Phase.PLAYING
	ProfileSave.profile["stats"] = {"matches": 5}
	RoundManager.current_round = 12
	GLVO.set("_slip_last", -INF)
	GLVO.set("_last_down_at", -INF)
	assert_true(GLVO.play_slip(), "a tier-A slip can play at round 12")
	var bag: Array = ProfileSave.profile["slip_bag"]
	assert_eq(bag.size(), 31, "drawn from the profile-wide bag")
	assert_false(GLVO.play_slip(), "cooldown blocks a second slip")
	GLVO.set("_slip_last", -INF)
	assert_false(GLVO.play_slip(), "one per round before round 25")
	# only tier-C lines left -> nothing at round 12
	GLVO.set("_slip_round", -1)
	ProfileSave.profile["slip_bag"] = ["op.slip.31"]
	assert_false(GLVO.play_slip(), "tier C needs round 30")
	GameState.phase = saved_phase
	RoundManager.current_round = saved_round
	GLVO.reset_match()


func test_map00_has_the_cellar() -> void:
	var map: Node3D = (load(MAP00) as PackedScene).instantiate() as Node3D
	var perks: Array = []
	var door: Node = null
	var lever: Node = null
	for n: Node in map.find_children("*", "", true, false):
		var sc: Script = n.get_script() as Script
		if sc == null:
			continue
		match sc.get_global_name():
			&"PerkMachine":
				perks.append(str(n.get("perk_id")))
			&"BuyDoor":
				if str(n.get("door_id")) == "door_cellar":
					door = n
			&"PowerSwitch":
				lever = n
	perks.sort()
	var want: Array = Array(PERKS)
	want.sort()
	assert_eq(perks, want, "all 8 machines in the cellar")
	assert_not_null(door, "Door 3: the cellar")
	if door != null:
		assert_eq(int(door.get("cost")), 1500)
		assert_eq(str(door.get("opens_zone")), "CELLAR")
	assert_not_null(lever, "the cellar lever powers Map 0")
	if lever != null:
		assert_eq(str(lever.get("config_table")), "map00")
	map.free()


func test_door_crossing_is_a_plane_crossing() -> void:
	var d: BuyDoor = BuyDoor.new()
	d.size = Vector3(1.6, 2.4, 0.25)
	add_child_autofree(d)
	d.global_position = Vector3(3, 0, 15.1)
	d.rotation.y = deg_to_rad(90)   # Map 0's Upstairs door: spans z 14.3..15.9 on the x = 3 wall
	var through: PackedVector3Array = [Vector3(5, 0, 15), Vector3(1, 0, 15)]
	var beside: PackedVector3Array = [Vector3(3.5, 0, 15.5), Vector3(14, 0, 7)]   # standing at it, walking away
	var past_jamb: PackedVector3Array = [Vector3(5, 0, 11), Vector3(1, 0, 11)]   # crosses x = 3 well clear of the door
	assert_true(ZombieDirector.door_crossed(d, through))
	assert_false(ZombieDirector.door_crossed(d, beside))
	assert_false(ZombieDirector.door_crossed(d, past_jamb))


func test_door_crossing_with_a_corner_in_the_doorway() -> void:
	var d: BuyDoor = BuyDoor.new()
	d.size = Vector3(1.6, 2.4, 0.25)
	add_child_autofree(d)
	d.global_position = Vector3(3, 0, 15.1)
	d.rotation.y = deg_to_rad(90)
	var via_corner: PackedVector3Array = [Vector3(6, 0, 15), Vector3(3.0, 0, 15.2), Vector3(1, 0, 13)]
	assert_true(ZombieDirector.door_crossed(d, via_corner))
